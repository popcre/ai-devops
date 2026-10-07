#!/usr/bin/env python3
"""Isolated Linux prototype runner. Metadata never shares command output."""
import argparse
import hashlib
import json
import os
import pathlib
import re
import select
import signal
import subprocess
import time

UNKNOWN = {"measurement": "outgoing_write_observation", "http_requests": None,
           "observed_completed_writes": None, "failed_write_attempts": None,
           "observed_external_writes": None, "complete": False}
FINAL_KEYS = {"schema", "finished", "observed_completed_writes", "failed_write_attempts",
              "observed_external_writes", "incomplete", "http_requests"}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate metadata key")
        result[key] = value
    return result


def validate(raw):
    try:
        if len(raw) > 4096:
            return UNKNOWN.copy()
        records = [json.loads(line, object_pairs_hook=unique_object) for line in raw.splitlines()]
        if (len(records) != 2 or records[0] != {"schema": 1, "started": True}
                or type(records[0]["schema"]) is not int or records[0]["started"] is not True):
            return UNKNOWN.copy()
        final = records[1]
        if (type(final) is not dict or set(final) != FINAL_KEYS
                or type(final["schema"]) is not int or final["schema"] != 1
                or final["finished"] is not True or type(final["incomplete"]) is not bool
                or final["http_requests"] is not None):
            return UNKNOWN.copy()
        for key in ("observed_completed_writes", "failed_write_attempts", "observed_external_writes"):
            if type(final[key]) is not int or not 0 <= final[key] <= 1000000000:
                return UNKNOWN.copy()
        result = UNKNOWN.copy()
        for key in ("observed_completed_writes", "failed_write_attempts", "observed_external_writes"):
            result[key] = final[key]
        result["complete"] = not final["incomplete"] and final["failed_write_attempts"] == 0
        # Remain an observed subset until command/client census is qualified.
        return result
    except (ValueError, KeyError, TypeError):
        return UNKNOWN.copy()


def run_counted(binary, arguments, host, digest):
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ValueError("invalid binary pin")
    binary = pathlib.Path(binary)
    if binary.is_symlink() or not binary.is_file():
        raise ValueError("invalid binary")
    with binary.open("rb") as stream:
        if hashlib.file_digest(stream, "sha256").hexdigest() != digest:
            raise ValueError("binary pin mismatch")
    if os.name != "posix" or os.uname().sysname != "Linux":
        raise ValueError("Linux prototype only")
    read_fd, write_fd = os.pipe()
    env = os.environ.copy()
    env["AI_GH_HTTP_COUNTER_FD"] = str(write_fd)
    env["AI_GH_HTTP_COUNTER_HOST"] = host
    child = None
    saved_handlers = {}
    raw = bytearray()
    overflow = eof = False
    try:
        child = subprocess.Popen([str(binary), *arguments], env=env, pass_fds=(write_fd,), start_new_session=True)
        os.close(write_fd)
        write_fd = -1

        def forward(signum, _frame):
            if child.poll() is None:
                try:
                    os.killpg(child.pid, signum)
                except ProcessLookupError:
                    pass

        for signum in (signal.SIGINT, signal.SIGTERM):
            saved_handlers[signum] = signal.signal(signum, forward)
        deadline = None
        while not eof:
            if child.poll() is not None and deadline is None:
                deadline = time.monotonic() + 0.5
            if deadline is not None and time.monotonic() >= deadline:
                break
            if not select.select([read_fd], [], [], 0.05)[0]:
                continue
            chunk = os.read(read_fd, 4096)
            if not chunk:
                eof = True
            elif len(raw) + len(chunk) > 4096:
                overflow = True
                raw.clear()
            elif not overflow:
                raw.extend(chunk)
        status = child.wait()
        result = validate(raw) if eof and not overflow else UNKNOWN.copy()
        return (status if status >= 0 else 128 - status), result
    finally:
        for signum, handler in saved_handlers.items():
            signal.signal(signum, handler)
        os.close(read_fd)
        if write_fd >= 0:
            os.close(write_fd)
        if child is not None and child.poll() is None:
            # Exceptional runner cleanup must never leave or replay a command.
            try:
                os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            child.wait()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--api-host", required=True)
    parser.add_argument("--metadata-fd", type=int, required=True)
    parser.add_argument("arguments", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    arguments = args.arguments[1:] if args.arguments[:1] == ["--"] else args.arguments
    if args.metadata_fd < 3:
        raise ValueError("separate metadata channel required")
    status, record = run_counted(args.binary, arguments, args.api_host, args.sha256)
    os.write(args.metadata_fd, (json.dumps(record, separators=(",", ":")) + "\n").encode())
    raise SystemExit(status)


if __name__ == "__main__":
    main()
