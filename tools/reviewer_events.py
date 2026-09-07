#!/usr/bin/env python3
"""Allowlisted invocation evidence, with no provider secrets or raw output."""
import json
import contextlib
import os
import re
from pathlib import Path
import subprocess
import sys
import time
import uuid

from reviewer_maintenance import Blocked, encoded, now, physical, require, snapshot


def location():
    if os.environ.get("AI_REVIEW_EVENT_DIR"):
        return physical(os.environ["AI_REVIEW_EVENT_DIR"])
    base = os.environ.get("AI_REVIEWER_STATE_BASE") or (os.environ.get("HOME") or str(Path.home())) + "/.local/state/ai-devops"
    return physical(os.environ.get("AI_REVIEW_EVENT_DIR", str(Path(base) / "reviewer-events")))


def git_value(*args):
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else ""


@contextlib.contextmanager
def event_lock(directory):
    """Kernel-owned lock: a dead writer cannot strand all provider wrappers."""
    directory = physical(directory)
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    path = physical(directory / ".append.lock")
    fd = os.open(path, os.O_CREAT | os.O_RDWR, 0o600)
    deadline = time.monotonic() + 10
    acquired = False
    try:
        while not acquired:
            try:
                if os.name == "nt":
                    import msvcrt
                    msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
                else:
                    import fcntl
                    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                acquired = True
            except OSError:
                require(time.monotonic() < deadline, f"event ledger writer is busy: {directory}")
                time.sleep(0.05)
        current = physical(path).stat()
        held = os.fstat(fd)
        require((current.st_dev, current.st_ino) == (held.st_dev, held.st_ino), "event lock was replaced")
        yield
    finally:
        if acquired:
            if os.name == "nt":
                msvcrt.locking(fd, msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)


def append(directory, event):
    with event_lock(directory):
        path = physical(directory / "events.jsonl")
        _, data = snapshot(path, "jsonl")
        rows = [json.loads(line) for line in data.splitlines()]
        require(all(isinstance(row, dict) for row in rows), "invalid event ledger")
        value = event(rows) if callable(event) else event
        with path.open("ab") as output:
            output.write(encoded(value) + b"\n")
            output.flush()
            os.fsync(output.fileno())


def main():
    operation, provider = sys.argv[1:3]
    require(provider in {"claude", "codex", "deepseek", "gemini", "glm", "grok", "kimi", "muse", "qwen"},
            "unknown reviewer provider")
    directory = location()
    if operation == "begin":
        parent = os.environ.get("AI_REVIEW_EVENT_RUN_ID", "")
        kind = sys.argv[3] if len(sys.argv) > 3 else "invocation"
        require(kind in {"invocation", "async-submission"}, "invalid invocation kind")
        event = {"schema_version": 1, "event": "started", "provider": provider,
                 "operation": kind, "parent_run_id": parent if re.fullmatch(r"[0-9a-f]{32}", parent) else None,
                 "run_id": uuid.uuid4().hex, "timestamp": now(), "repo": git_value("rev-parse", "--show-toplevel"),
                 "head": git_value("rev-parse", "HEAD"),
                 "caller": os.environ.get("AI_" + provider.upper() + "_CALLER",
                           os.environ.get("AI_" + provider.upper() + "_REVIEW_CALLER",
                                          "codex" if provider in {"claude", "codex", "gemini"} else "unknown"))}
        append(directory, event)
        print(event["run_id"])
    else:
        require(operation == "finish" and len(sys.argv) == 5, "invalid event operation")
        run_id, result = sys.argv[3:]
        def finish(rows):
            matches = [r for r in rows if r.get("run_id") == run_id]
            require(len(matches) == 1 and matches[0].get("event") == "started" and
                    matches[0].get("provider") == provider, "event has no unique matching start")
            return {**matches[0], "event": "finished", "timestamp": now(), "exit_code": int(result)}
        append(directory, finish)


if __name__ == "__main__":
    os.umask(0o077)
    try:
        main()
    except (Blocked, OSError, ValueError) as error:
        print(f"reviewer event recording: {error}", file=sys.stderr)
        sys.exit(1)
