#!/usr/bin/env python3
"""Offline P1 summary. No network access; never echo unvalidated input values.

Usage: python tools/github-requests/report.py MEASUREMENTS_DIRECTORY
Output is a scrubbed JSON aggregate, NOT acceptance evidence for busy windows.
Owned by #658; later measured transports extend this schema rather than making
another collector. Raw daily records stay in the private machine state directory.
"""
import collections
import hashlib
import json
import pathlib
import re
import sys


def summarize(directory):
    counts = collections.Counter()
    failures = deferred = executions = records = unknown_callers = 0
    latency = []
    digest = hashlib.sha256()
    stamps = []
    directory = pathlib.Path(directory)
    # MSYS represents FIFOs as .lnk files on NTFS. Native Python must not
    # silently omit those and present a seemingly valid empty measurement set.
    if next(directory.glob("????-??-??.jsonl.lnk"), None) is not None:
        raise ValueError("non-regular measurement input")
    for path in sorted(directory.glob("????-??-??.jsonl")):
        if path.is_symlink() or not path.is_file() or path.stat().st_size > 4194304:
            raise ValueError("invalid measurement file")
        with path.open("rb") as stream:
            for line in stream:
                digest.update(line)
                row = json.loads(line)
                operation = row.get("operation")
                if operation not in OPERATIONS or row.get("caller") not in CALLERS:
                    raise ValueError("invalid measurement label")
                if (row.get("schema") != 1 or row.get("measurement") != "opaque_cli_estimate"
                        or row.get("http_requests") is not None or row.get("graphql_points") is not None):
                    raise ValueError("unsupported measurement schema")
                stamp = row.get("utc", "")
                if not isinstance(stamp, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", stamp):
                    raise ValueError("invalid time")
                duration = row.get("latency_ms")
                status = row.get("exit_status")
                calls = row.get("cli_executions")
                if (type(duration) is not int or not 0 <= duration <= 604800000
                        or type(status) is not int or not 0 <= status <= 255
                        or type(calls) is not int or calls not in (0, 1)):
                    raise ValueError("invalid measurement number")
                stamps.append(stamp)
                latency.append(duration)
                records += 1
                executions += calls
                deferred += status == 75
                failures += status not in (0, 75)
                unknown_callers += row["caller"] == "unknown"
                counts[(row["caller"], operation)] += 1
    return {
        "schema": 1,
        "acceptance": "incomplete: busy windows, workflow outcomes, identities and quota observations required",
        "records": records, "opaque_cli_executions": executions,
        "http_requests": None, "graphql_points": None,
        "failed": failures, "deferred": deferred,
        "unknown_caller_records": unknown_callers,
        "first_utc": min(stamps) if stamps else None,
        "last_utc": max(stamps) if stamps else None,
        "observed_wrapper_latency_ms": {"count": len(latency), "max": max(latency) if latency else None},
        "sources": [{"caller": caller, "operation": operation, "records": count}
                    for (caller, operation), count in sorted(counts.items(), key=lambda pair: (-pair[1], pair[0]))],
        "raw_artifact_sha256": digest.hexdigest(),
        "coverage_gaps": ["unwrapped managed callers", "external clients and other hosts",
                          "HTTP pagination and GraphQL point costs", "authenticated principal and API host",
                          "probe requests", "telemetry warnings or interrupted processes may omit records"],
    }


OPERATIONS = {"unknown", "api.graphql", "api.quota", "api.unknown", "repo.view", "workflow.run"}
OPERATIONS.update("pr." + value for value in ("view", "checks", "list", "merge", "create", "comment", "edit", "diff"))
OPERATIONS.update("issue." + value for value in ("view", "list", "create", "comment", "edit", "close", "reopen"))
OPERATIONS.update("run." + value for value in ("view", "list", "cancel"))
CALLERS = {"unknown", "interactive", "ai-pr-wait", "ai-gh-wait", "ai-blocker-watch", "ai-verify-run", "ai-memory-sync", "ai-test-local"}

if __name__ == "__main__":
    try:
        if len(sys.argv) != 2 or not pathlib.Path(sys.argv[1]).is_dir():
            raise ValueError("a measurements directory is required")
        print(json.dumps(summarize(sys.argv[1]), indent=2))
    except (ValueError, OSError, TypeError, KeyError):
        print("request report: invalid or unavailable measurement input; no report produced", file=sys.stderr)
        sys.exit(1)
