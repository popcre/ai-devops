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
    cost_counts = collections.Counter()
    outcome_counts = collections.Counter()
    receipts = {}
    costs_with_ids = []
    observed_points = cost_records = cost_window_records = unattributed_window_records = 0
    cost_windows = {}
    verified_principal_records = 0
    failures = deferred = executions = records = unknown_callers = identity_probes = transformed_graphql = 0
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
                if not isinstance(row, dict):
                    raise ValueError("invalid measurement object")
                stamp = row.get("utc", "")
                if not isinstance(stamp, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", stamp):
                    raise ValueError("invalid time")
                if row.get("schema") == 2:
                    if (set(row) not in COST_SHAPES
                            or row.get("measurement") != "observed_graphql_cost"
                            or (row.get("caller"), row.get("operation"), row.get("workflow")) not in COST_LABELS
                            or type(row.get("graphql_points")) is not int
                            or not 0 <= row["graphql_points"] <= 1000000000
                            or row.get("http_requests") is not None):
                        raise ValueError("invalid GraphQL cost observation")
                    context = row.get("access_context")
                    if context is not None and not valid_access_context(context):
                        raise ValueError("invalid GraphQL access context")
                    if "graphql_remaining" in row:
                        remaining, reset_at = row["graphql_remaining"], row["graphql_reset_at"]
                        if ((remaining is None) != (reset_at is None)
                                or (remaining is not None and
                                    (type(remaining) is not int or not 0 <= remaining <= 1000000000
                                     or not isinstance(reset_at, str)
                                     or re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", reset_at) is None))):
                            raise ValueError("invalid GraphQL quota window")
                        if remaining is not None:
                            if context is None:
                                unattributed_window_records += 1
                            else:
                                cost_window_records += 1
                                window = cost_windows.setdefault((context, reset_at), {"records": 0, "min_remaining": remaining,
                                                                                       "max_remaining": remaining, "observed_points": 0})
                                window["records"] += 1
                                window["min_remaining"] = min(window["min_remaining"], remaining)
                                window["max_remaining"] = max(window["max_remaining"], remaining)
                                window["observed_points"] += row["graphql_points"]
                    workflow_id = row.get("workflow_id")
                    if workflow_id is not None and not valid_workflow_id(workflow_id):
                        raise ValueError("invalid GraphQL workflow ID")
                    if workflow_id is not None:
                        costs_with_ids.append((workflow_id, row["caller"], row["workflow"], row["graphql_points"]))
                    cost_records += 1
                    observed_points += row["graphql_points"]
                    cost_counts[(row["caller"], row["operation"], row["workflow"])] += row["graphql_points"]
                    continue
                if row.get("schema") == 3:
                    if (set(row) != RECEIPT_KEYS or row.get("measurement") != "workflow_outcome"
                            or (row.get("caller"), row.get("workflow"), row.get("outcome")) not in RECEIPT_LABELS
                            or not valid_workflow_id(row.get("workflow_id"))
                            or type(row.get("elapsed_ms")) is not int
                            or not 0 <= row["elapsed_ms"] <= 604800000
                            or row["workflow_id"] in receipts):
                        raise ValueError("invalid workflow receipt")
                    receipts[row["workflow_id"]] = (row["caller"], row["workflow"], row["outcome"], row["elapsed_ms"])
                    outcome_counts[(row["caller"], row["workflow"], row["outcome"])] += 1
                    continue
                operation = row.get("operation")
                caller = row.get("caller")
                if (not isinstance(operation, str) or operation not in OPERATIONS
                        or not isinstance(caller, str) or caller not in CALLERS):
                    raise ValueError("invalid measurement label")
                direct = row.get("measurement") == "direct_api_invocation_estimate"
                request_class = row.get("request_class")
                if (type(row.get("schema")) is not int or row["schema"] != 1
                        or row.get("measurement") not in ("opaque_cli_estimate", "direct_api_invocation_estimate")
                        or request_class not in ("unknown", "identity_probe", "graphql_transformed_unobservable")
                        or (request_class == "graphql_transformed_unobservable" and operation != "api.graphql")
                        or "http_requests" not in row
                        or (direct and (operation != "api.identity" or request_class != "identity_probe"))
                        or (not direct and (operation == "api.identity" or request_class == "identity_probe"))
                        or not valid_principal(row.get("principal"))
                        or row["http_requests"] is not None
                        or "graphql_points" not in row or row["graphql_points"] is not None):
                    raise ValueError("unsupported measurement schema")
                duration = row.get("latency_ms")
                status = row.get("exit_status")
                calls = row.get("cli_executions")
                if ((direct and (duration is not None or calls != 1))
                        or (not direct and (type(duration) is not int or not 0 <= duration <= 604800000))
                        or type(status) is not int or not 0 <= status <= 255
                        or type(calls) is not int or calls not in (0, 1)):
                    raise ValueError("invalid measurement number")
                stamps.append(stamp)
                if duration is not None:
                    latency.append(duration)
                records += 1
                verified_principal_records += row.get("principal") != "unknown"
                executions += calls if not direct else 0
                identity_probes += calls if direct else 0
                transformed_graphql += calls if request_class == "graphql_transformed_unobservable" else 0
                deferred += status == 75
                failures += status not in (0, 75)
                unknown_callers += row["caller"] == "unknown"
                counts[(row["caller"], operation)] += 1
    linked_cost_records = linked_points = 0
    for workflow_id, caller, workflow, points in costs_with_ids:
        receipt = receipts.get(workflow_id)
        if receipt is None:
            continue
        if receipt[:2] != (caller, workflow):
            raise ValueError("cost and outcome labels disagree")
        linked_cost_records += 1
        linked_points += points
    completed = sum(count for (_, _, outcome), count in outcome_counts.items() if outcome != "deadline")
    context_ordinals = {context: i + 1 for i, context in enumerate(sorted({key[0] for key in cost_windows}))}
    return {
        "schema": 1,
        "acceptance": "incomplete: busy windows, workflow outcomes, identities and quota observations required",
        "records": records, "opaque_cli_executions": executions,
        "http_requests": None, "identity_probe_invocations": identity_probes,
        "graphql_transformed_unobservable": transformed_graphql, "graphql_points": None,
        "verified_principal_cli_records": verified_principal_records,
        "observed_graphql_cost_records": cost_records,
        "observed_graphql_points": observed_points,
        "observed_graphql_window_records": cost_window_records,
        "unattributed_graphql_window_records": unattributed_window_records,
        "observed_graphql_windows_local_only": [
            {"context_ordinal": context_ordinals[context], "reset_at": reset_at, **window}
            for (context, reset_at), window in sorted(cost_windows.items())],
        "completed_workflow_receipts": completed,
        "workflow_outcomes": [
            {"caller": caller, "workflow": workflow, "outcome": outcome, "count": count}
            for (caller, workflow, outcome), count in sorted(outcome_counts.items())],
        "linked_graphql_cost_records": linked_cost_records,
        "linked_graphql_points": linked_points,
        "observed_graphql_cost_sources": [
            {"caller": caller, "operation": operation, "workflow": workflow, "points": points}
            for (caller, operation, workflow), points in sorted(cost_counts.items())],
        "failed": failures, "deferred": deferred,
        "unknown_caller_records": unknown_callers,
        "first_utc": min(stamps) if stamps else None,
        "last_utc": max(stamps) if stamps else None,
        "observed_wrapper_latency_ms": {"count": len(latency), "max": max(latency) if latency else None},
        "sources": [{"caller": caller, "operation": operation, "records": count}
                    for (caller, operation), count in sorted(counts.items(), key=lambda pair: (-pair[1], pair[0]))],
        "raw_artifact_sha256": digest.hexdigest(),
        "coverage_gaps": ["unwrapped managed callers", "external clients and other hosts",
                          "HTTP pagination and GraphQL queries without a cost observation", "unknown access context and cross-host quota correlation",
                          "GraphQL cost without a matching workflow receipt cannot be assigned to a completed outcome",
                          "idle BlockerWatch ticks are not comparable to active workflow outcomes",
                          "dispatch and privacy outcomes are not yet instrumented",
                          "probe requests", "transformed GraphQL output hides HTTP-200 errors",
                          "telemetry warnings or interrupted processes may omit records"],
    }


OPERATIONS = {"unknown", "api.graphql", "api.quota", "api.identity", "api.unknown", "repo.view", "workflow.run"}
OPERATIONS.update("bw." + value for value in ("snapshot", "dependents", "wake_miss", "alarm_issue", "link_issue"))
OPERATIONS.update("pr." + value for value in ("view", "checks", "list", "merge", "create", "comment", "edit", "diff"))
OPERATIONS.update("issue." + value for value in ("view", "list", "create", "comment", "edit", "close", "reopen"))
OPERATIONS.update("run." + value for value in ("view", "list", "cancel"))
CALLERS = {"unknown", "interactive", "ai-pr-wait", "ai-gh-wait", "ai-blocker-watch", "ai-verify-run", "ai-memory-sync", "ai-test-local", "ai-merge-group-evidence"}
COST_KEYS = {"schema", "utc", "measurement", "caller", "operation", "workflow", "graphql_points", "http_requests"}
COST_KEYS_WITH_ID = COST_KEYS | {"workflow_id"}
COST_SHAPES = {frozenset(keys | extra) for keys in (COST_KEYS, COST_KEYS_WITH_ID)
               for extra in (set(), {"graphql_remaining", "graphql_reset_at"},
                             {"access_context"}, {"graphql_remaining", "graphql_reset_at", "access_context"})}
RECEIPT_KEYS = {"schema", "utc", "measurement", "caller", "workflow", "workflow_id", "outcome", "elapsed_ms"}
COST_LABELS = {
    ("ai-pr-wait", "graphql.pr_status", "pr_wait"),
    ("ai-blocker-watch", "graphql.open_issue_snapshot", "blocker_watch_tick"),
    ("ai-blocker-watch", "graphql.issue_detail", "blocker_watch_tick"),
}
RECEIPT_LABELS = {
    ("ai-pr-wait", "pr_wait", outcome)
    for outcome in ("merged", "closed", "checks_failed", "ejected", "deadline")
} | {("ai-blocker-watch", "blocker_watch_tick", "completed")}


def valid_workflow_id(value):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{32}", value) is not None


def valid_access_context(value):
    return isinstance(value, str) and re.fullmatch(r"v1:[0-9a-f]{64}", value) is not None


def valid_principal(value):
    return isinstance(value, str) and (value == "unknown" or
                                       re.fullmatch(r"local-sha256:[0-9a-f]{64}", value) is not None)

if __name__ == "__main__":
    try:
        if len(sys.argv) != 2 or not pathlib.Path(sys.argv[1]).is_dir():
            raise ValueError("a measurements directory is required")
        print(json.dumps(summarize(sys.argv[1]), indent=2))
    except (ValueError, OSError, TypeError, KeyError, RecursionError):
        print("request report: invalid or unavailable measurement input; no report produced", file=sys.stderr)
        sys.exit(1)
