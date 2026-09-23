#!/usr/bin/env python3
"""Read-only repository tool loop for ai-deepseek-agent.

DeepSeek's chat API cannot open files on its own. This helper runs an
OpenAI-compatible tool-calling loop that exposes three read-only tools
(list_dir, read_file, grep) confined to one root directory.

The wrapper owns every HTTP request (curl, key on curl's stdin); this helper
never sees the key. It only builds the first request (init) and, after each
response, runs the requested tools and writes the next request (step).
  deepseek_repo_tools.py init MESSAGES_JSON MODEL REQUEST_OUT
  deepseek_repo_tools.py step ROOT REQUEST RESPONSE LOG ROUND
      exit 10: next request written; exit 0: RESPONSE is the final answer
  deepseek_repo_tools.py usage-sum OUT FINAL_RESPONSE [ROUND_RESPONSE...]
      one usage record summed over every paid round of a tool turn
  deepseek_repo_tools.py --run-tool ROOT NAME ARGS_JSON   (offline test hook)

Guards: relative paths only, no '..' escape, no symlink or reparse point
anywhere on the path, no .git/.ai/node_modules internals, secret-looking files
refused, per-file size cap, binary refusal, output truncation, and a bounded
tool-call, round, per-grep time, and wall budget. The wrapper also runs each
step under a hard timeout, which bounds a pathological regular expression.
"""
import fnmatch
import json
import os
import re
import stat
import sys
import time

MAX_TOOL_CALLS = int(os.environ.get("DEEPSEEK_TOOLS_MAX_CALLS", "40"))
MAX_ROUNDS = int(os.environ.get("DEEPSEEK_TOOLS_MAX_ROUNDS", "16"))
MAX_FILE_BYTES = 256 * 1024          # whole-file read without a range
MAX_SCAN_BYTES = 16 * 1024 * 1024    # ranged read or grep of one file
GREP_SECONDS = float(os.environ.get("DEEPSEEK_TOOLS_GREP_SECONDS", "30"))
MAX_OUTPUT_CHARS = 60000
MAX_GREP_MATCHES = 200
MAX_LIST_ENTRIES = 500

DENY_DIRS = {".git", "node_modules", ".ai"}
SECRET_GLOBS = [
    ".env", ".env.*", "*.env", "*.pem", "*.key", "*.p12", "*.pfx", "*.jks",
    "*.kdbx", "id_rsa*", "id_ed25519*", "id_ecdsa*", "*.ppk", ".npmrc",
    ".pypirc", ".netrc", "_netrc", ".git-credentials", "credentials",
    "credentials.*", "*.token", "auth.json",
    # Name-based catch-alls: anything that looks like it holds a secret.
    "*secret*", "*password*", "*passwd*", "*credential*", "*private*key*",
    "*.tfstate", "*.tfstate.*", "*.tfvars", "*.keystore", "*.gpg", "*.asc",
    "service-account*.json", "*serviceaccount*.json",
]

TOOLS = [
    {"type": "function", "function": {
        "name": "list_dir",
        "description": "List entries of a directory in the repository (read-only). Path is relative to the repository root; use '.' for the root.",
        "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}}},
    {"type": "function", "function": {
        "name": "read_file",
        "description": "Read a text file from the repository (read-only). Optional 1-based start_line and end_line select a range. Output lines are prefixed with their line numbers.",
        "parameters": {"type": "object", "properties": {
            "path": {"type": "string"}, "start_line": {"type": "integer"}, "end_line": {"type": "integer"}},
            "required": ["path"]}}},
    {"type": "function", "function": {
        "name": "grep",
        "description": "Search repository text files for a Python regular expression. Optional path limits the search to a file or directory. Returns path:line:text matches.",
        "parameters": {"type": "object", "properties": {
            "pattern": {"type": "string"}, "path": {"type": "string"}}, "required": ["pattern"]}}},
]


class Refused(Exception):
    pass


def norm(name):
    # Windows resolves names case-insensitively and ignores trailing dots and
    # spaces, so '.GIT' and '.git.' must be treated exactly like '.git'.
    return name.rstrip(" .").lower()


def is_denied(name):
    return norm(name) in DENY_DIRS


def is_secret(name):
    low = norm(name)
    return any(fnmatch.fnmatch(low, g) for g in SECRET_GLOBS)


def is_link(st):
    return stat.S_ISLNK(st.st_mode) or bool(getattr(st, "st_file_attributes", 0) & 0x400)


def resolve(root, rel):
    if rel is None or rel == "":
        rel = "."
    if not isinstance(rel, str):
        raise Refused("path must be a string")
    rel = rel.replace("\\", "/")
    if rel.startswith("/") or re.match(r"^[A-Za-z]:", rel) or "\0" in rel:
        raise Refused("absolute paths are not allowed; use a path relative to the repository root")
    parts = [p for p in rel.split("/") if p not in ("", ".")]
    if any(p == ".." for p in parts):
        raise Refused("'..' is not allowed")
    cur = root
    for p in parts:
        if ":" in p or norm(p) == "":
            raise Refused("path component is not allowed")
        if is_denied(p):
            raise Refused(f"'{p}' is not readable")
        cur = os.path.join(cur, p)
        try:
            st = os.lstat(cur)
        except OSError:
            raise Refused("path does not exist")
        if is_link(st):
            raise Refused("symbolic links and reparse points are not followed")
    real_root = os.path.realpath(root)
    real = os.path.realpath(cur)
    if real != real_root and not real.startswith(real_root.rstrip(os.sep) + os.sep):
        raise Refused("path escapes the repository root")
    # Check the resolved spelling too (real case, long names), not only the
    # spelling the model sent.
    real_parts = [] if real == real_root else os.path.relpath(real, real_root).replace(os.sep, "/").split("/")
    if any(is_denied(p) for p in real_parts):
        raise Refused("path is not readable")
    if any(is_secret(p) for p in parts) or any(is_secret(p) for p in real_parts):
        raise Refused("secret-looking files are not readable")
    return cur, "/".join(parts) or "."


def text_lines(path):
    """Return (line iterator, size) for a regular text file of at most MAX_SCAN_BYTES."""
    st = os.lstat(path)
    if not stat.S_ISREG(st.st_mode) or is_link(st):
        raise Refused("not a regular file")
    if st.st_size > MAX_SCAN_BYTES:
        raise Refused(f"file is larger than {MAX_SCAN_BYTES} bytes")
    fh = open(path, "rb")
    # Scan the whole file (bounded by MAX_SCAN_BYTES), not only its head.
    for chunk in iter(lambda: fh.read(1 << 20), b""):
        if b"\0" in chunk:
            fh.close()
            raise Refused("binary file")
    fh.seek(0)

    def gen():
        with fh:
            for raw in fh:
                if b"\0" in raw:
                    raise Refused("binary file")
                yield raw.decode("utf-8", errors="replace").rstrip("\r\n")
    return gen(), st.st_size


def tool_list_dir(root, args):
    path, rel = resolve(root, args.get("path", "."))
    if not stat.S_ISDIR(os.lstat(path).st_mode):
        raise Refused("not a directory")
    out = []
    for e in sorted(os.scandir(path), key=lambda e: e.name):
        if is_denied(e.name):
            continue
        if is_link(e.stat(follow_symlinks=False)):
            out.append(e.name + "@ (link, not followed)")
        elif e.is_dir(follow_symlinks=False):
            out.append(e.name + "/")
        else:
            out.append(e.name + (" (secret, unreadable)" if is_secret(e.name) else ""))
        if len(out) >= MAX_LIST_ENTRIES:
            out.append("... truncated")
            break
    return f"{rel}:\n" + "\n".join(out)


def tool_read_file(root, args):
    path, rel = resolve(root, args.get("path"))
    try:
        start = max(1, int(args.get("start_line") or 1))
        end = int(args["end_line"]) if args.get("end_line") else None
    except (TypeError, ValueError):
        raise Refused("start_line and end_line must be integers")
    lines, size = text_lines(path)
    if end is None and start == 1 and size > MAX_FILE_BYTES:
        raise Refused(f"file is larger than {MAX_FILE_BYTES} bytes; pass start_line and end_line, or use grep")
    body, total, chars = [], 0, 0
    for total, line in enumerate(lines, 1):
        if total >= start and (end is None or total <= end) and chars <= MAX_OUTPUT_CHARS:
            body.append(f"{total}: {line}")
            chars += len(line) + 8
    shown_end = total if end is None else min(total, end)
    return f"{rel} (lines {start}-{shown_end} of {total})\n" + "\n".join(body)


def tool_grep(root, args):
    if not isinstance(args.get("pattern"), str):
        raise Refused("pattern must be a string")
    try:
        rx = re.compile(args["pattern"])
    except re.error as exc:
        raise Refused(f"invalid regular expression: {exc}")
    base, _ = resolve(root, args.get("path", "."))
    matches = []
    deadline = time.monotonic() + GREP_SECONDS

    def scan(fp):
        try:
            lines, _ = text_lines(fp)
        except (Refused, OSError):
            return
        relp = os.path.relpath(fp, root).replace(os.sep, "/")
        found = []
        try:
            for n, line in enumerate(lines, 1):
                if n % 1000 == 0 and time.monotonic() > deadline:
                    break
                if rx.search(line):
                    found.append(f"{relp}:{n}:{line[:300]}")
                    if len(matches) + len(found) >= MAX_GREP_MATCHES:
                        break
        except (Refused, OSError):
            return  # binary part found mid-file: report nothing from it
        matches.extend(found)

    if stat.S_ISREG(os.lstat(base).st_mode):
        scan(base)
    else:
        for dirpath, dirnames, filenames in os.walk(base, followlinks=False):
            dirnames[:] = sorted(d for d in dirnames
                                 if not is_denied(d) and not is_secret(d) and not is_link(os.lstat(os.path.join(dirpath, d))))
            for f in sorted(filenames):
                fp = os.path.join(dirpath, f)
                if is_secret(f) or is_link(os.lstat(fp)):
                    continue
                scan(fp)
                if len(matches) >= MAX_GREP_MATCHES or time.monotonic() > deadline:
                    break
            if len(matches) >= MAX_GREP_MATCHES:
                matches.append("... match limit reached")
                break
            if time.monotonic() > deadline:
                matches.append(f"... search stopped after {GREP_SECONDS:g}s; narrow the path")
                break
    return "\n".join(matches) if matches else "no matches"


HANDLERS = {"list_dir": tool_list_dir, "read_file": tool_read_file, "grep": tool_grep}


def run_tool(root, name, raw_args):
    try:
        args = json.loads(raw_args or "{}")
        if not isinstance(args, dict):
            raise ValueError
    except ValueError:
        return "Error: tool arguments must be a JSON object"
    handler = HANDLERS.get(name)
    if handler is None:
        return f"Error: unknown tool {name}"
    try:
        out = handler(os.path.abspath(root), args)
    except Refused as exc:
        return f"Error: {exc}"
    except OSError as exc:
        return f"Error: {exc.strerror or 'unreadable'}"
    except Exception as exc:  # a malformed request must never end the paid turn
        return f"Error: tool failed ({type(exc).__name__})"
    if len(out) > MAX_OUTPUT_CHARS:
        out = out[:MAX_OUTPUT_CHARS] + "\n... output truncated"
    return out


NOTICE = ("You have read-only access to the repository through the list_dir, read_file, and grep tools. "
          "Paths are relative to the repository root. Open the files you need to verify claims before "
          "concluding and cite path:line for evidence. Your tool budget is {n} calls.")


def cmd_init(msgs_file, model, req_file):
    with open(msgs_file, encoding="utf-8") as fh:
        messages = json.load(fh)
    notice = NOTICE.format(n=MAX_TOOL_CALLS)
    if messages and messages[0].get("role") == "system":
        messages = [{"role": "system", "content": messages[0]["content"] + "\n\n" + notice}] + messages[1:]
    else:
        messages = [{"role": "system", "content": notice}] + messages
    body = {"model": model, "messages": messages, "stream": False, "tools": TOOLS}
    with open(req_file, "w", encoding="utf-8") as fh:
        json.dump(body, fh)
    return 0


def cmd_step(root, req_file, resp_file, log_file, rnd):
    """Exit 10 with the next request written to req_file when the model asked
    for tools; exit 0 when resp_file holds the final answer."""
    rnd = int(rnd)
    with open(req_file, encoding="utf-8") as fh:
        body = json.load(fh)
    try:
        with open(resp_file, encoding="utf-8") as fh:
            msg = json.load(fh)["choices"][0]["message"]
    except (ValueError, KeyError, IndexError, TypeError, OSError):
        return 0
    if not isinstance(msg, dict):
        return 0
    tcs = msg.get("tool_calls") or []
    if not isinstance(tcs, list):
        tcs = []
    # A malformed call becomes a tool error, never a helper crash.
    tcs = [tc if isinstance(tc, dict) else {} for tc in tcs]
    if not tcs or "tools" not in body:
        return 0
    calls = 0
    if os.path.exists(log_file):
        with open(log_file, encoding="utf-8") as fh:
            calls = sum(1 for line in fh if '"counted": true' in line)
    messages = body["messages"]
    messages.append({k: v for k, v in msg.items() if k in ("role", "content", "tool_calls", "reasoning_content")})
    with open(log_file, "a", encoding="utf-8") as log:
        for tc in tcs:
            fn = tc.get("function") if isinstance(tc.get("function"), dict) else {}
            if not isinstance(fn.get("arguments"), (str, type(None))):
                fn = dict(fn, arguments=json.dumps(fn.get("arguments")))
            counted = calls < MAX_TOOL_CALLS
            if counted:
                calls += 1
                result = run_tool(root, fn.get("name"), fn.get("arguments"))
            else:
                result = "Error: tool budget exhausted; answer from what you have"
            log.write(json.dumps({"round": rnd, "tool": fn.get("name"), "arguments": fn.get("arguments"),
                                  "result_chars": len(result), "refused": result.startswith("Error:"),
                                  "counted": counted}) + "\n")
            messages.append({"role": "tool", "tool_call_id": tc.get("id"), "content": result})
    if calls >= MAX_TOOL_CALLS or rnd + 1 >= MAX_ROUNDS:
        # Last round: no tools offered, so the model must answer.
        body.pop("tools", None)
        messages.append({"role": "user", "content": "Tool budget exhausted. Give your final answer now."})
    with open(req_file + ".next", "w", encoding="utf-8") as fh:
        json.dump(body, fh)
    os.replace(req_file + ".next", req_file)
    return 10


USAGE_FIELDS = ("prompt_tokens", "completion_tokens", "total_tokens",
                "prompt_cache_hit_tokens", "prompt_cache_miss_tokens")


def cmd_usage_sum(out_file, final_file, *round_files):
    """Write final_file with its usage replaced by the sum over every paid
    round. A counter missing from any round is dropped, never guessed."""
    with open(final_file, encoding="utf-8") as fh:
        final = json.load(fh)
    usages = []
    for path in list(round_files) + [final_file]:
        with open(path, encoding="utf-8") as fh:
            u = json.load(fh).get("usage")
        usages.append(u if isinstance(u, dict) else {})
    total = {}
    for key in USAGE_FIELDS:
        vals = [u.get(key) for u in usages]
        if all(isinstance(v, int) and not isinstance(v, bool) for v in vals):
            total[key] = sum(vals)
    reasoning = [(u.get("completion_tokens_details") or {}).get("reasoning_tokens") for u in usages]
    if all(isinstance(v, int) and not isinstance(v, bool) for v in reasoning):
        total["completion_tokens_details"] = {"reasoning_tokens": sum(reasoning)}
    final["usage"] = total
    final["tool_rounds_summed"] = len(usages)
    with open(out_file, "w", encoding="utf-8") as fh:
        json.dump(final, fh)
    return 0


def main():
    a = sys.argv[1:]
    if len(a) >= 3 and a[0] == "usage-sum":
        return cmd_usage_sum(*a[1:])
    if len(a) == 4 and a[0] == "--run-tool":
        print(run_tool(a[1], a[2], a[3]))
        return 0
    if len(a) == 4 and a[0] == "init":
        return cmd_init(a[1], a[2], a[3])
    if len(a) == 6 and a[0] == "step":
        return cmd_step(*a[1:])
    print("usage: deepseek_repo_tools.py init MSGS MODEL REQ | step ROOT REQ RESP LOG ROUND | "
          "usage-sum OUT FINAL [ROUND...] | --run-tool ROOT NAME ARGS",
          file=sys.stderr)
    return 3


if __name__ == "__main__":
    sys.exit(main())
