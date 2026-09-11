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

from reviewer_maintenance import Blocked, digest, encoded, now, physical, publish, read_json, require, snapshot


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


def invocation(directory, provider, run_id, active=False):
    require(re.fullmatch(r"[0-9a-f]{32}", run_id), "invalid invocation identity")
    _, data = snapshot(directory / "events.jsonl", "jsonl")
    rows = [json.loads(line) for line in data.splitlines()]
    require(all(isinstance(row, dict) for row in rows), "invalid event ledger")
    starts = [row for row in rows if row.get("run_id") == run_id and row.get("event") == "started"]
    require(len(starts) == 1 and starts[0].get("provider") == provider,
            "evidence has no unique matching invocation")
    if active:
        require(not any(row.get("run_id") == run_id and row.get("event") == "finished" for row in rows),
                "completed invocation evidence cannot be rewritten")
    return starts[0]


def provenance(value=None):
    result = {"source": "unknown", "actor_class": "unknown", "phase": "unknown",
              "last_proven_provider_state": "unknown", "paid_work_may_exist": None, "signal": None}
    value = value or {}
    require(isinstance(value, dict) and not set(value) - set(result), "unsupported interruption fields")
    result.update(value)
    require(result["source"] in {"unknown", "os-signal", "user-cancellation", "scheduler-interruption",
                                 "timeout", "process-death", "none"}, "invalid interruption source")
    require(result["actor_class"] in {"unknown", "user", "scheduler", "wrapper", "provider", "none"},
            "invalid interruption actor")
    require(result["phase"] in {"unknown", "preflight", "provider-running", "wrapper-running",
                                "wrapper-exit", "report-publication", "cleanup"}, "invalid interruption phase")
    require(result["last_proven_provider_state"] in {"unknown", "not-started", "running", "completed",
                                                     "failed", "cancelled"}, "invalid provider state")
    require(result["paid_work_may_exist"] is None or type(result["paid_work_may_exist"]) is bool,
            "paid-work uncertainty must be explicit")
    require(result["signal"] in {None, "INT", "TERM", "HUP"}, "invalid observed signal")
    return result


def evidence_root(directory, run_id):
    # Keep evidence in the existing private event store, outside disposable repos.
    return physical(directory / "evidence" / run_id)


def require_report(directory, provider, run_id):
    with event_lock(directory):
        start = invocation(directory, provider, run_id, active=True)
        root = evidence_root(directory, run_id)
        value = {"schema_version": 1, "run_id": run_id, "provider": provider,
                 "head": start["head"], "caller": start["caller"]}
        path = root / "required.json"
        if path.exists():
            require(read_json(path) == value, "evidence requirement identity changed")
        else:
            publish(path, value)


def publish_report(directory, provider, run_id, report, facts=None):
    # Only a wrapper's prepared UTF-8 report is accepted, never a stream/session
    # directory. The private report is immutable; no response enters the ledger.
    report = physical(report)
    boundary, data = snapshot(report, "log")
    require(boundary["exists"] and data, "report is missing or empty; source evidence retained")
    current = report.stat()
    require(current.st_size == boundary["offset"] and current.st_mtime_ns == boundary["mtime_ns"],
            "report changed during publication; source evidence retained")
    text = data.decode("utf-8")
    facts = provenance(facts)
    with event_lock(directory):
        start = invocation(directory, provider, run_id, active=True)
        current = report.stat()
        require(current.st_size == boundary["offset"] and current.st_mtime_ns == boundary["mtime_ns"],
                "report changed during publication; source evidence retained")
        root = evidence_root(directory, run_id)
        require((root / "required.json").is_file(), "report publication was not reserved")
        sha = digest(data)
        value = {"schema_version": 1, "run_id": run_id, "provider": provider,
                 "head": start["head"], "caller": start["caller"], "report_sha256": sha,
                 "report_text": text, "provenance": facts}
        path = root / (sha + ".report.json")
        if path.exists():
            require(read_json(path) == value, "published evidence conflicts with this invocation")
        else:
            publish(path, value)
        # Return an opaque recovery reference, not a source-worktree path.
        return {"reference": run_id + "/" + sha, "report_sha256": sha}


def verify_reports(directory, provider, run_id):
    start = invocation(directory, provider, run_id)
    root = evidence_root(directory, run_id)
    if not (root / "required.json").exists():
        return []
    required = read_json(root / "required.json")
    require(required == {"schema_version": 1, "run_id": run_id, "provider": provider,
                         "head": start["head"], "caller": start["caller"]}, "evidence requirement changed")
    paths = sorted(root.glob("*.report.json"))
    require(paths, "required report is not durably published; cleanup and replay refused")
    references = []
    for path in paths:
        row = read_json(path)
        require(row.get("schema_version") == 1 and row.get("run_id") == run_id and
                row.get("provider") == provider and row.get("head") == start["head"] and
                row.get("caller") == start["caller"], "published report identity changed")
        require(isinstance(row.get("report_text"), str) and row["report_text"], "published report is empty")
        sha = digest(row["report_text"].encode("utf-8"))
        require(row.get("report_sha256") == sha and path.name == sha + ".report.json",
                "published report content changed")
        provenance(row.get("provenance"))
        references.append(run_id + "/" + sha)
    return references


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
    elif operation in {"require-report", "publish-report", "verify-reports"}:
        require(len(sys.argv) >= 4, "missing evidence invocation")
        run_id = sys.argv[3]
        if operation == "require-report":
            require(len(sys.argv) == 4, "invalid evidence requirement")
            require_report(directory, provider, run_id)
        elif operation == "publish-report":
            require(len(sys.argv) in {5, 6}, "invalid report publication")
            facts = json.loads(sys.argv[5]) if len(sys.argv) == 6 else None
            print(json.dumps(publish_report(directory, provider, run_id, sys.argv[4], facts)))
        else:
            require(len(sys.argv) == 4, "invalid evidence verification")
            with event_lock(directory):
                print(json.dumps({"references": verify_reports(directory, provider, run_id)}))
    else:
        require(operation == "finish" and len(sys.argv) in {5, 6}, "invalid event operation")
        run_id, result = sys.argv[3:5]
        facts = provenance(json.loads(sys.argv[5]) if len(sys.argv) == 6 else None)
        def finish(rows):
            matches = [r for r in rows if r.get("run_id") == run_id]
            require(len(matches) == 1 and matches[0].get("event") == "started" and
                    matches[0].get("provider") == provider, "event has no unique matching start")
            references = verify_reports(directory, provider, run_id)
            return {**matches[0], "event": "finished", "timestamp": now(), "exit_code": int(result),
                    "provenance": facts, "evidence_references": references}
        append(directory, finish)


if __name__ == "__main__":
    os.umask(0o077)
    try:
        main()
    except (Blocked, OSError, ValueError) as error:
        print(f"reviewer event recording: {error}", file=sys.stderr)
        sys.exit(1)
