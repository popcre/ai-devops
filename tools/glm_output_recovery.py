"""Internal GLM v2 own-output recovery. Never grants an external permission.

Only newly issued wrapper protocols qualify. The wrapper retains its existing
subscription admission and absolute deadline; this is one mechanical recovery,
not a limit on reviewer steps. No network or provider access lives here.
"""
import hashlib
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import stat
import time
import sys
import subprocess

MAX_BYTES = 8 * 1024 * 1024
MAX_VIEW_BYTES = 64 * 1024 * 1024
ID = re.compile(r"^[A-Za-z0-9_-]{1,160}$")
SHA = re.compile(r"^[0-9a-f]{40}$")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def private_json(path):
    with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW), "rb") as stream:
        info = os.fstat(stream.fileno())
        require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid()
                and info.st_nlink == 1 and info.st_mode & 0o077 == 0
                and info.st_size <= MAX_BYTES, "untrusted registry file")
        return json.load(stream)


def exclusive_json(path, value):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as stream:
        json.dump(value, stream, sort_keys=True)
        stream.flush()
        os.fsync(stream.fileno())


def binding(meta, *, caller, session, boundary, head, packet, origin, now=None):
    turn = meta.get("remote_turn", {})
    protocol = turn.get("own_output_recovery", {})
    require(isinstance(turn, dict) and isinstance(protocol, dict), "invalid original protocol")
    require(meta.get("type") == "review" and meta.get("caller") == caller,
            "wrong review caller")
    require(meta.get("opencode_session_id") == session and ID.fullmatch(session),
            "wrong provider session")
    require(turn.get("state") == "pending" and type(protocol.get("version")) is int
            and protocol.get("version") == 1 and type(protocol.get("maximum")) is int
            and protocol.get("maximum") == 1 and protocol.get("origin") == origin,
            "original run did not admit recovery")
    require(origin.get("pin") == "1.18.12" and re.fullmatch(r"[0-9a-f]{64}", origin.get("sha256", "")),
            "unqualified builtin protocol")
    instruction = Path(protocol.get("instruction_asset", ""))
    require(instruction.is_absolute() and instruction.resolve() == instruction
            and instruction.is_relative_to(Path(boundary)) and instruction.is_file()
            and hashlib.sha256(instruction.read_bytes()).hexdigest() == protocol.get("instruction_sha256"),
            "scoped instructions changed")
    require(SHA.fullmatch(head) and turn.get("head") == head
            and turn.get("packet_sha256") == packet and re.fullmatch(r"[0-9a-f]{64}", packet),
            "source packet changed")
    require(Path(boundary).resolve() == Path(turn.get("boundary_root", "")).resolve()
            == Path(meta.get("boundary_root", "")).resolve(), "wrong review boundary")
    source = Path(meta.get("repository_root", "")).resolve()
    boundary_path = Path(boundary).resolve()
    git_directory = boundary_path / ".git"
    require(source != boundary_path and source.is_dir() and git_directory.is_dir()
            and git_directory.resolve() == git_directory and not (git_directory / "commondir").exists(),
            "mirror requires a separate disposable clone")
    require(subprocess.check_output(["git", "-C", str(boundary_path), "rev-parse", "--git-dir"],
                                    stderr=subprocess.DEVNULL).strip() == b".git"
            and subprocess.check_output(["git", "-C", str(boundary_path), "remote"],
                                        stderr=subprocess.DEVNULL).strip() == b"",
            "mirror clone is not private and remote-less")
    require(type(turn.get("deadline_epoch")) is int
            and (time.time() if now is None else now) < turn["deadline_epoch"],
            "original deadline expired")
    run = turn.get("original_invocation_id", "")
    require(re.fullmatch(r"[0-9a-f]{32}", run), "missing original invocation")
    return turn


def instant(value):
    require(isinstance(value, str), "unmeasured tool time")
    result = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
    require(result.tzinfo is not None, "tool time lacks zone")
    return result.timestamp()


def tool_instant(value):
    # Measured pinned v2 API time.{ran,completed}: integer Unix milliseconds.
    # Do not infer legacy string/seconds formats or accept JSON booleans.
    require(type(value) is int and 0 < value < 10**15, "unmeasured pinned tool time")
    return value / 1000


def qualify(meta, permissions, messages, *, caller, session, boundary, head, packet,
            managed_directory, origin, now=None):
    turn = binding(meta, caller=caller, session=session, boundary=boundary,
                   head=head, packet=packet, origin=origin, now=now)
    rows = permissions.get("data")
    require(isinstance(rows, list) and len(rows) == 1, "ambiguous permission")
    permission = rows[0]
    source = permission.get("source", {})
    require(permission.get("sessionID") == session
            and permission.get("action") == "external_directory"
            and source.get("type") == "tool", "not own external request")
    permission_id = permission.get("id", "")
    call = source.get("callID", "")
    message_id = source.get("messageID", "")
    require(all(isinstance(x, str) and ID.fullmatch(x)
                for x in [permission_id, call, message_id]), "invalid call identity")
    requested = []
    completed = {}
    started = instant(turn.get("started_at"))
    requested_at = None
    for message in messages.get("data", []):
        if (message.get("type") != "assistant" or message.get("agent") != "glm-review"
                or message.get("model", {}).get("id") != "glm-5.3"
                or message.get("model", {}).get("providerID") != "zai-coding-plan"):
            continue
        for tool in message.get("content", []):
            if tool.get("type") != "tool" or (tool.get("name") or tool.get("tool")) != "read":
                continue
            state = tool.get("state", {})
            require(tool.get("provider", {}).get("executed") is False,
                    "unqualified non-builtin execution")
            tool_id = tool.get("id") or tool.get("callID")
            if state.get("status") == "completed" and tool_id != call:
                ended = tool_instant(tool.get("time", {}).get("completed"))
                if ended >= started:
                    for value in state.get("outputPaths", []):
                        if isinstance(value, str):
                            require(value not in completed, "ambiguous output provenance")
                            original_path = state.get("input", {}).get("path")
                            require(isinstance(original_path, str) and Path(original_path).is_absolute()
                                    and Path(original_path).resolve().is_relative_to(Path(boundary)),
                                    "original read was outside its immutable boundary")
                            completed[value] = {"call_id": tool_id, "completed": ended, "original_path": original_path}
            if message.get("id") == message_id and tool_id == call and state.get("status") == "running":
                # Exact v2 API read schema; aliases are deliberately not guessed.
                requested.append(state.get("input", {}).get("path"))
                requested_at = tool_instant(tool.get("time", {}).get("ran"))
    require(len(requested) == 1 and isinstance(requested[0], str), "unbound running read")
    path = Path(requested[0])
    managed = Path(managed_directory)
    require(path.parent == managed and path.is_absolute()
            and re.fullmatch(r"tool_[A-Za-z0-9_-]{1,160}", path.name), "not managed exact output")
    require(str(path) in completed, "output belongs to no completed own read")
    require(started <= completed[str(path)]["completed"] <= requested_at
            < turn["deadline_epoch"], "output is outside original invocation")
    wildcard = str(managed / "*")
    require(permission.get("resources") == [wildcard]
            and permission.get("save") == [wildcard], "permission differs from exact output parent")
    return {"version": 1, "run": turn["original_invocation_id"], "session": session,
            "head": head, "packet": packet, "boundary": str(Path(boundary).resolve()),
            "source_path": str(path), "permission_id": permission_id,
            "message_id": message_id, "call_id": call,
            "originating_call_id": completed[str(path)]["call_id"],
            "original_read_path": completed[str(path)]["original_path"],
            "deadline_epoch": turn["deadline_epoch"]}


def render_read_output(data, record):
    """Lossless labelled projection of the pinned builtin TextPage schema.

    Text is JSON-escaped, UTF-8 offsets refer to original content, and inserted
    labels are explicitly wrapper metadata. Original page truncation is retained.
    """
    def reject_constant(_):
        raise ValueError("nonfinite captured JSON")
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "duplicate captured field")
            result[key] = value
        return result
    value = json.loads(data.decode("utf-8"), object_pairs_hook=unique, parse_constant=reject_constant)
    required = {"type", "content", "mime", "offset", "truncated"}
    require(isinstance(value, dict) and required <= set(value) <= required | {"next"}
            and value["type"] == "text-page" and isinstance(value["content"], str)
            and isinstance(value["mime"], str) and len(value["mime"]) <= 128
            and type(value["offset"]) is int and value["offset"] >= 1
            and type(value["truncated"]) is bool, "unknown pinned builtin-read schema")
    if "next" in value:
        require(type(value["next"]) is int and value["next"] > value["offset"]
                and value["truncated"] is True, "invalid original page continuation")
    require(not value["truncated"] or "next" in value, "original truncation lacks continuation")
    content = value["content"]
    content_bytes = content.encode("utf-8")
    rows = [{"kind": "wrapper-provenance-not-original-text", "version": 1,
             "raw_sha256": hashlib.sha256(data).hexdigest(), "raw_bytes": len(data),
             "content_sha256": hashlib.sha256(content_bytes).hexdigest(), "content_bytes": len(content_bytes),
             "originating_call_id": record["originating_call_id"]},
            {"kind": "original-page-metadata", "value": {key: value[key] for key in value if key != "content"}}]
    def segments(text):
        part = ""
        for character in text:
            proposed = part + character
            if part and len(json.dumps(proposed, ensure_ascii=True).encode()) > 800:
                yield part
                part = ""
            part += character
            if character == "\n":
                yield part
                part = ""
        if part:
            yield part
    for kind, text in [("original-read-path", record["original_read_path"]),
                       ("raw-capture-path", record["source_path"])]:
        offset = 0
        for part in segments(text):
            length = len(part.encode("utf-8"))
            rows.append({"kind": kind, "byte_start": offset, "byte_end": offset + length, "text": part})
            offset += length
    offset, line, line_offset = 0, value["offset"], 0
    for part in segments(content):
        length = len(part.encode("utf-8"))
        rows.append({"kind": "original-content-segment", "original_line": line,
                     "line_byte_offset": line_offset, "continuation": line_offset != 0,
                     "byte_start": offset, "byte_end": offset + length, "text": part})
        offset += length
        if part.endswith("\n"):
            line += 1; line_offset = 0
        else:
            line_offset += length
    rendered = b"".join((json.dumps(row, ensure_ascii=True, separators=(",", ":")) + "\n").encode() for row in rows)
    require(len(rendered) <= MAX_VIEW_BYTES and all(len(line) < 1600 for line in rendered.splitlines()),
            "safe presentation bounds exceeded")
    return rendered, {"content_sha256": hashlib.sha256(content_bytes).hexdigest(),
                      "view_rows": len(rows), "original_page_truncated": value["truncated"],
                      "original_offset": value["offset"], "original_next": value.get("next")}


def mirror(record, retained_capture=None):
    """Called only after the wrapper recorded a successful rejection response."""
    require(time.time() < record["deadline_epoch"], "original deadline expired")
    source = Path(record["source_path"])
    require(source.parent.resolve() == source.parent, "managed parent is not canonical")
    parent_fd = os.open(source.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        require(os.readlink(f"/proc/self/fd/{parent_fd}") == str(source.parent), "managed parent changed")
        require(os.fstat(parent_fd).st_uid == os.getuid(), "managed parent owner changed")
        fd = os.open(source.name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=parent_fd)
    finally:
        os.close(parent_fd)
    with os.fdopen(fd, "rb") as stream:
        before = os.fstat(stream.fileno())
        require(stat.S_ISREG(before.st_mode) and before.st_uid == os.getuid()
                and before.st_nlink == 1 and 0 < before.st_size <= MAX_BYTES,
                "unsafe own output file")
        data = stream.read(MAX_BYTES + 1)
        after = os.fstat(stream.fileno())
        identity = lambda x: (x.st_dev, x.st_ino, x.st_size, x.st_mtime_ns, x.st_ctime_ns)
        require(identity(before) == identity(after) and len(data) == before.st_size,
                "own output changed during capture")
        stream.seek(0)
        require(stream.read(MAX_BYTES + 1) == data and identity(after) == identity(os.fstat(stream.fileno())),
                "own output bytes changed")
        require(identity(os.stat(source, follow_symlinks=False)) == identity(after),
                "own output path changed")
    view, presentation = render_read_output(data, record)
    boundary = Path(record["boundary"])
    require(boundary.resolve() == boundary and boundary.is_dir(), "review boundary changed")
    git_directory = boundary / ".git"
    require(git_directory.resolve() == git_directory and git_directory.is_dir(), "private snapshot Git directory changed")
    directory_name = "ai-glm-own-output-" + record["run"]
    directory = git_directory / directory_name
    destination = directory / "full-output.txt"
    view_path = directory / "readable-page.jsonl"
    if retained_capture is not None:
        retained = os.open(retained_capture, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(retained, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
    git_fd = os.open(git_directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        require(os.readlink(f"/proc/self/fd/{git_fd}") == str(git_directory)
                and os.fstat(git_fd).st_uid == os.getuid(), "snapshot Git parent changed")
        os.mkdir(directory_name, 0o700, dir_fd=git_fd)  # existing path always refuses
        directory_fd = os.open(directory_name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=git_fd)
        try:
            target = os.open("full-output.txt", os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                             0o600, dir_fd=directory_fd)
            with os.fdopen(target, "wb") as stream:
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
            view_fd = os.open("readable-page.jsonl", os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                              0o600, dir_fd=directory_fd)
            with os.fdopen(view_fd, "wb") as stream:
                stream.write(view)
                stream.flush()
                os.fsync(stream.fileno())
            os.fsync(directory_fd)
            require(os.readlink(f"/proc/self/fd/{directory_fd}") == str(directory), "private destination changed")
        finally:
            os.close(directory_fd)
        os.fsync(git_fd)
    finally:
        os.close(git_fd)
    return {**record, **presentation, "destination": str(destination), "readable_view": str(view_path),
            "view_sha256": hashlib.sha256(view).hexdigest(),
            "retained_capture": str(retained_capture) if retained_capture else None,
            "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(), "state": "mirrored"}


def receipt_base(meta_path, record):
    return Path(meta_path).parent / (record["run"] + ".own-output")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["qualify", "mirror", "intermediate", "submission"])
    parser.add_argument("--meta", required=True)
    parser.add_argument("--caller", required=True)
    parser.add_argument("--session", required=True)
    parser.add_argument("--boundary", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--packet", required=True)
    args = parser.parse_args()
    meta = private_json(args.meta)
    # The sole caller is the wrapper. Protected live origin is resolved here,
    # never accepted from a caller's JSON payload or repository marker.
    from glm_formal_profile import origin, paths
    live = origin(Path.home())
    options = dict(caller=args.caller, session=args.session, boundary=args.boundary,
                   head=args.head, packet=args.packet, origin=live)
    turn = binding(meta, **options)
    base = Path(args.meta).parent / (turn["original_invocation_id"] + ".own-output")
    payload = sys.stdin.buffer.read(MAX_BYTES + 1)
    require(len(payload) <= MAX_BYTES, "diagnostic payload exceeds capture")
    body = json.loads(payload)
    if args.operation == "qualify":
        record = qualify(meta, body["permissions"], body["messages"],
                         managed_directory=live["managed_directory"], **options)
        exclusive_json(str(base) + ".claim.json", record)  # global one per run
        result = {"claim": str(base) + ".claim.json", "permission_id": record["permission_id"]}
    elif args.operation == "mirror":
        record = private_json(str(base) + ".claim.json")
        require(body == {"permission_id": record["permission_id"], "rejected": True},
                "original permission was not rejected")
        exclusive_json(str(base) + ".denied.json", body)
        result = mirror(record, str(base) + ".captured-output.txt")
        exclusive_json(str(base) + ".mirror.json", result)
    elif args.operation == "intermediate":
        require(body.get("finish") == "stop" and ID.fullmatch(body.get("id", "")), "not intermediate stop")
        record = private_json(str(base) + ".mirror.json")
        exclusive_json(str(base) + ".intermediate.json", body)
        prompt = ("Mechanical recovery of the SAME original review: the external-directory request was rejected. "
                  "The complete output of your earlier own read is securely preserved inside this review at "
                  + record["readable_view"] + ". Read EVERY page of that labelled lossless view using limit=20 "
                  "and successive line offsets until EOF. Wrapper labels are not original source text; "
                  "original content has exact byte offsets/hash and JSON-escaped control characters. "
                  "Original page truncation and its next source offset are preserved; do not invent missing source. Then "
                  "finish the original review using its unchanged task, packet, scoped instructions and decision rules. "
                  "No external directory access is granted. Do not reconstruct or regenerate the patch.\n")
        result = {"prompt": prompt, "sha256": hashlib.sha256(prompt.encode()).hexdigest(),
                  "intermediate_id": body["id"], "receipt": str(base) + ".intermediate.json"}
        exclusive_json(str(base) + ".correction.json", result)
    else:
        correction = private_json(str(base) + ".correction.json")
        require(body == {"prompt_sha256": correction["sha256"], "intermediate_id": correction["intermediate_id"]},
                "corrective submission changed")
        exclusive_json(str(base) + ".submission.json", body)
        result = {"state": "submission-reserved", "receipt": str(base) + ".submission.json"}
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError, json.JSONDecodeError) as error:
        print("GLM own-output recovery refused: " + str(error), file=sys.stderr)
        sys.exit(1)
