#!/usr/bin/env python3
"""Allowlisted invocation evidence, with no provider secrets or raw output."""
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import time
import uuid

from reviewer_maintenance import Blocked, digest, encoded, locked, now, physical, require, snapshot


def location():
    base = os.environ.get("AI_REVIEWER_STATE_BASE", os.environ.get("HOME", str(Path.home())) + "/.local/state/ai-devops")
    return physical(os.environ.get("AI_REVIEW_EVENT_DIR", str(Path(base) / "reviewer-events")))


def git_value(*args):
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else ""


def append(directory, event):
    # Short bounded contention wait. A crashed owner is not reclaimed on age.
    deadline = time.monotonic() + 10
    while True:
        try:
            with locked(directory):
                path = physical(directory / "events.jsonl")
                _, data = snapshot(path, "jsonl")
                rows = [json.loads(line) for line in data.splitlines()]
                require(all(isinstance(row, dict) for row in rows), "invalid event ledger")
                value = event(rows) if callable(event) else event
                with path.open("ab") as output:
                    output.write(encoded(value) + b"\n")
                    output.flush()
                    os.fsync(output.fileno())
                return
        except Blocked as error:
            if "writer is busy" not in str(error) or time.monotonic() >= deadline:
                raise
            time.sleep(0.05)


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
