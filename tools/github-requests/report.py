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
import os
import pathlib
import re
import stat
import sys
from pr_status_singleflight import unix_private


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def read_cohort(directory):
    """Read only this fixed optional metadata inode; never wait on a FIFO."""
    if os.name != "posix" or not hasattr(os, "O_NOFOLLOW"):
        try:
            # MSYS stores a FIFO as a .lnk object that native Python does not
            # resolve through the requested name. Presence is untrusted;
            # never open either representation on an unsupported platform.
            try:
                os.lstat(pathlib.Path(directory) / "cohort.json.lnk")
                return {"cohort_id": None, "unknown_reason": "metadata_untrusted"}
            except FileNotFoundError:
                pass
            os.lstat(pathlib.Path(directory) / "cohort.json")
        except FileNotFoundError:
            return {"cohort_id": None, "unknown_reason": "metadata_absent"}
        except OSError:
            pass
        return {"cohort_id": None, "unknown_reason": "metadata_untrusted"}
    descriptor = None
    try:
        # Walk through directory descriptors so ancestor substitution cannot
        # redirect the metadata read. This operation never creates a directory.
        path = pathlib.Path(directory).absolute()
        descriptor = os.open(path.anchor, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        for part in path.parts[1:]:
            if part == "..":
                raise ValueError("invalid metadata path")
            next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=descriptor)
            os.close(descriptor)
            descriptor = next_fd
        if not unix_private(path, "directory", owner=descriptor) or stat.S_IMODE(os.fstat(descriptor).st_mode) != 0o700:
            raise ValueError("invalid metadata directory")
        file_fd = os.open("cohort.json", os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=descriptor)
        with os.fdopen(file_fd, "rb") as stream:
            info = os.fstat(stream.fileno())
            if (not unix_private(path / "cohort.json", "file", owner=stream.fileno())
                    or stat.S_IMODE(info.st_mode) != 0o600 or info.st_size > 16384):
                raise ValueError("invalid metadata inode")
            data = stream.read(16385)
        if len(data) > 16384:
            raise ValueError("invalid metadata size")
        row = json.loads(data, object_pairs_hook=unique_object)
        if (not isinstance(row, dict) or set(row) != {"schema", "cohort_id", "phase", "clock_status", "source_generation", "target_map"}
                or type(row["schema"]) is not int or row["schema"] != 1
                or not valid_workflow_id(row["cohort_id"]) or row["phase"] not in {"baseline", "candidate"}
                or any(row[key] is not None for key in ("clock_status", "source_generation", "target_map"))):
            raise ValueError("invalid metadata object")
        return {"cohort_id": row["cohort_id"], "unknown_reason": "source_unknown"}
    except FileNotFoundError:
        return {"cohort_id": None, "unknown_reason": "metadata_absent"}
    except (OSError, ValueError, TypeError, KeyError, RecursionError):
        return {"cohort_id": None, "unknown_reason": "metadata_untrusted"}
    finally:
        if descriptor is not None:
            os.close(descriptor)


def summarize(directory):
    counts = collections.Counter()
    cost_counts = collections.Counter()
    outcome_counts = collections.Counter()
    receipts = {}
    evidence = {}
    local_observations = {}
    local_counts = collections.Counter()
    local_reasons = collections.Counter()
    local_lower = []
    local_upper = []
    evidence_counts = collections.Counter()
    evidence_gaps = collections.Counter()
    qualified_groups = collections.defaultdict(list)
    qualified_latency = []
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
                stamps.append(stamp)
                if row.get("schema") == 4:
                    row = json.loads(line, object_pairs_hook=unique_object)
                    if (type(row.get("schema")) is not int or set(row) != EVIDENCE_KEYS or row.get("measurement") != "workflow_evidence"
                            or row.get("caller") != "ai-pr-wait" or row.get("workflow") != "pr_wait"
                            or not valid_workflow_id(row.get("workflow_id")) or row["workflow_id"] in evidence
                            or not valid_nullable_id(row.get("cohort_id"))
                            or not valid_target_ordinal(row.get("target_ordinal"))
                            or row.get("source_verified") not in SOURCE_STATES
                            or not valid_digest(row.get("source_fingerprint_start"))
                            or not valid_digest(row.get("source_fingerprint_end"))
                            or not valid_digest(row.get("install_generation_binding"))
                            or row.get("event_kind") not in EVENT_KINDS
                            or not valid_timestamp_ms(row.get("eligible_utc_ms"))
                            or not valid_timestamp_ms(row.get("observed_utc_ms"))
                            or not valid_timestamp_ms(row.get("delivered_utc_ms"))
                            or row.get("delivery_boundary") not in DELIVERY_BOUNDARIES
                            or row.get("clock_quality") not in CLOCK_QUALITIES
                            or not valid_error_bound(row.get("clock_error_bound_ms"))
                            or not valid_latency(row.get("latency_ms"))
                            or row.get("unknown_reason") not in UNKNOWN_REASONS
                            or not evidence_consistent(row)):
                        raise ValueError("invalid workflow evidence")
                    evidence[row["workflow_id"]] = row
                    evidence_counts[(row["event_kind"], row["unknown_reason"])] += 1
                    for field in ("cohort_id", "target_ordinal", "eligible_utc_ms", "observed_utc_ms", "delivered_utc_ms", "clock_error_bound_ms", "latency_ms"):
                        evidence_gaps[field] += row[field] is None
                    evidence_gaps["source_verified"] += row["source_verified"] != "verified"
                    if (row["source_verified"] == "verified" and row["cohort_id"] is not None
                            and row["event_kind"] != "unknown" and row["delivery_boundary"] == "terminal_report"
                            and row["clock_quality"] == "verified_bound" and row["latency_ms"] is not None):
                        qualified_latency.append(row["latency_ms"])
                    continue
                if row.get("schema") == 5:
                    row = json.loads(line, object_pairs_hook=unique_object)
                    if (type(row.get("schema")) is not int or set(row) != LOCAL_KEYS
                            or row.get("measurement") != "local_workflow_observation"
                            or row.get("caller") != "ai-pr-wait" or row.get("workflow") != "pr_wait"
                            or not valid_workflow_id(row.get("workflow_id"))
                            or row["workflow_id"] in local_observations
                            or row.get("outcome") not in LOCAL_OUTCOMES
                            or row.get("boundary") != "receipt_init_to_terminal_output"
                            or row.get("clock_basis") not in LOCAL_CLOCK_BASES
                            or row.get("source_verified") != "unknown"
                            or row.get("acceptance") != "unknown"
                            or row.get("unknown_reason") not in LOCAL_REASONS):
                        raise ValueError("invalid local workflow observation")
                    for field, upper in (("start_monotonic_ms", 9999999999999), ("end_monotonic_ms", 9999999999999),
                                         ("duration_lower_ms", 604800020), ("duration_upper_ms", 604800020),
                                         ("clock_error_bound_ms", 20)):
                        value = row.get(field)
                        if value is not None and (type(value) is not int or not 0 <= value <= upper):
                            raise ValueError("invalid local observation number")
                    reason = row["unknown_reason"]
                    numeric = tuple(row[field] for field in ("start_monotonic_ms", "end_monotonic_ms", "duration_lower_ms", "duration_upper_ms", "clock_error_bound_ms"))
                    if reason == "source_unknown":
                        start, end, lower, upper, error = numeric
                        if (row["clock_basis"] != "linux_boottime_centiseconds" or None in numeric
                                or end < start or end - start > 604800000
                                or error != 20 or lower != max(0, end - start - 20)
                                or upper != end - start + 20):
                            raise ValueError("invalid local observation interval")
                        local_lower.append(lower); local_upper.append(upper)
                    elif any(value is not None for value in numeric):
                        raise ValueError("invalid unknown local observation")
                    local_observations[row["workflow_id"]] = row
                    local_counts[row["outcome"]] += 1
                    local_reasons[reason] += 1
                    continue
                if row.get("schema") == 2:
                    if (frozenset(row) not in COST_SHAPES
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
                        or (request_class == "graphql_transformed_unobservable"
                            and operation != "api.graphql"
                            and not (caller == "ai-blocker-watch" and operation in
                                     {"bw.snapshot", "bw.dependents", "bw.wake_miss", "bw.alarm_issue", "bw.link_issue"}
                                     and row.get("bucket") == "graphql"))
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
    for workflow_id, row in evidence.items():
        receipt = receipts.get(workflow_id)
        if receipt is None:
            raise ValueError("workflow evidence has no outcome receipt")
        if receipt[:2] != (row["caller"], row["workflow"]):
            raise ValueError("evidence and outcome labels disagree")
        expected = {"pr_merged": "merged", "pr_closed": "closed", "check_completed": "checks_failed"}.get(row["event_kind"])
        if expected is not None and receipt[2] != expected:
            raise ValueError("workflow evidence and outcome disagree")
        if row["latency_ms"] is not None:
            qualified_groups[(row["event_kind"], row["delivery_boundary"], receipt[2])].append(row["latency_ms"])
    for workflow_id, row in local_observations.items():
        receipt = receipts.get(workflow_id)
        if receipt is None:
            raise ValueError("local observation has no outcome receipt")
        if receipt[:2] != (row["caller"], row["workflow"]) or receipt[2] != row["outcome"]:
            raise ValueError("local observation and outcome disagree")
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
        "workflow_evidence_records": len(evidence),
        "local_workflow_observations": {
            "count": len(local_observations),
            "by_outcome": [{"outcome": outcome, "count": count} for outcome, count in sorted(local_counts.items())],
            "reason_counts": [{"unknown_reason": reason, "count": count} for reason, count in sorted(local_reasons.items())],
            "duration_interval_ms": {"min": min(local_lower) if local_lower else None,
                                      "max": max(local_upper) if local_upper else None},
        },
        "workflow_evidence": [{"event_kind": event, "unknown_reason": reason, "count": count}
                              for (event, reason), count in sorted(evidence_counts.items())],
        "workflow_evidence_gaps": dict(sorted(evidence_gaps.items())),
        "qualified_latency_ms": {"count": len(qualified_latency), "max": max(qualified_latency) if qualified_latency else None},
        "qualified_latency_by_outcome": [{"event_kind": event, "delivery_boundary": boundary, "outcome": outcome,
                                           "count": len(values), "p95_ms": sorted(values)[(95 * len(values) + 99) // 100 - 1]}
                                          for (event, boundary, outcome), values in sorted(qualified_groups.items())],
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


OPERATIONS = {"unknown", "api.graphql", "api.quota", "api.identity", "api.unknown", "auth.status", "repo.view", "workflow.run"}
OPERATIONS.update("bw." + value for value in ("snapshot", "dependents", "wake_miss", "alarm_issue", "link_issue"))
OPERATIONS.update("pr." + value for value in ("view", "checks", "list", "merge", "create", "comment", "edit", "diff"))
OPERATIONS.update("issue." + value for value in ("view", "list", "create", "comment", "edit", "close", "reopen"))
OPERATIONS.update("run." + value for value in ("view", "list", "cancel"))
CALLERS = {"unknown", "interactive", "ai-pr-wait", "ai-gh-wait", "ai-blocker-watch", "ai-verify-run",
           "ai-memory-sync", "ai-test-local", "ai-merge-group-evidence",
           "ai-transcript-destination-check", "ai-workspace-status", "ai-reviewer-membership-drift",
           "ai-devops-doctor", "ai-devops-installer"}
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
    ("ai-blocker-watch", "graphql.open_issue_snapshot", "blocker_watch_alarm"),
    ("ai-blocker-watch", "graphql.issue_detail", "blocker_watch_alarm"),
    ("ai-blocker-watch", "graphql.open_issue_snapshot", "blocker_watch_links"),
}
RECEIPT_LABELS = {
    ("ai-pr-wait", "pr_wait", outcome)
    for outcome in ("merged", "closed", "checks_failed", "ejected", "deadline")
} | {("ai-blocker-watch", "blocker_watch_tick", "completed")}
EVIDENCE_KEYS = {"schema", "utc", "measurement", "caller", "workflow", "workflow_id", "cohort_id", "target_ordinal",
                 "source_verified", "source_fingerprint_start", "source_fingerprint_end", "install_generation_binding",
                 "event_kind", "eligible_utc_ms", "observed_utc_ms", "delivered_utc_ms", "delivery_boundary",
                 "clock_quality", "clock_error_bound_ms", "latency_ms", "unknown_reason"}
LOCAL_KEYS = {"schema", "utc", "measurement", "caller", "workflow", "workflow_id", "outcome", "boundary", "clock_basis",
              "start_monotonic_ms", "end_monotonic_ms", "duration_lower_ms", "duration_upper_ms", "clock_error_bound_ms",
              "source_verified", "acceptance", "unknown_reason"}
LOCAL_OUTCOMES = {"merged", "closed", "checks_failed", "ejected", "deadline"}
LOCAL_CLOCK_BASES = {"linux_boottime_centiseconds", "unknown"}
LOCAL_REASONS = {"source_unknown", "clock_unknown", "clock_negative", "delivery_unknown"}
SOURCE_STATES = {"verified", "changed", "unknown"}
EVENT_KINDS = {"pr_merged", "pr_closed", "check_completed", "unknown"}
DELIVERY_BOUNDARIES = {"terminal_report", "unknown"}
CLOCK_QUALITIES = {"verified_bound", "unverified", "jump", "negative", "unknown"}
UNKNOWN_REASONS = {"none", "metadata_absent", "metadata_untrusted", "source_unknown", "source_changed",
                   "event_unknown", "event_invalid", "clock_unknown", "clock_jump", "clock_negative", "delivery_unknown"}


def valid_workflow_id(value):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{32}", value) is not None


def valid_nullable_id(value):
    return value is None or valid_workflow_id(value)


def valid_target_ordinal(value):
    return value is None or (type(value) is int and 1 <= value <= 1000000000)


def valid_digest(value):
    return value is None or (isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None)


def valid_timestamp_ms(value):
    return value is None or (type(value) is int and 0 <= value <= 9999999999999)


def valid_error_bound(value):
    return value is None or (type(value) is int and 0 <= value <= 60000)


def valid_latency(value):
    return value is None or (type(value) is int and 0 <= value <= 604800000)


def evidence_consistent(row):
    # Initial collection has no reviewed source-generation or clock adapter.
    # Future states are reserved labels, never accepted qualification today.
    if row["source_verified"] != "unknown" or row["clock_quality"] != "unknown" or row["latency_ms"] is not None:
        return False
    source_fields = (row["source_fingerprint_start"], row["source_fingerprint_end"], row["install_generation_binding"])
    if row["source_verified"] == "verified" and (any(value is None for value in source_fields)
                                                   or source_fields[0] != source_fields[1]):
        return False
    if row["source_verified"] == "unknown" and any(value is not None for value in source_fields):
        return False
    if row["source_verified"] == "changed" and (any(value is None for value in source_fields)
            or row["source_fingerprint_start"] == row["source_fingerprint_end"]):
        return False
    if (row["event_kind"] == "unknown") != (row["eligible_utc_ms"] is None):
        return False
    if row["clock_quality"] != "verified_bound" and (row["clock_error_bound_ms"] is not None or row["latency_ms"] is not None):
        return False
    if row["clock_quality"] == "verified_bound" and row["clock_error_bound_ms"] is None:
        return False
    if row["delivery_boundary"] == "terminal_report" and (row["observed_utc_ms"] is None or row["delivered_utc_ms"] is None):
        return False
    if row["eligible_utc_ms"] is not None and (row["observed_utc_ms"] is None or row["eligible_utc_ms"] > row["observed_utc_ms"]):
        return False
    if row["delivery_boundary"] == "terminal_report" and row["delivered_utc_ms"] < row["observed_utc_ms"]:
        return False
    if row["unknown_reason"] == "none" and (row["source_verified"] != "verified" or row["clock_quality"] != "verified_bound" or row["latency_ms"] is None):
        return False
    if row["latency_ms"] is not None:
        if (row["source_verified"] != "verified" or row["cohort_id"] is None
                or row["clock_quality"] != "verified_bound" or row["clock_error_bound_ms"] is None
                or row["event_kind"] == "unknown" or row["delivery_boundary"] != "terminal_report"
                or row["observed_utc_ms"] is None or row["delivered_utc_ms"] is None):
            return False
        elapsed = row["delivered_utc_ms"] - row["eligible_utc_ms"]
        if elapsed < 0 or elapsed != row["latency_ms"]:
            return False
    return True


def valid_access_context(value):
    return isinstance(value, str) and re.fullmatch(r"v1:[0-9a-f]{64}", value) is not None


def valid_principal(value):
    return isinstance(value, str) and (value == "unknown" or
                                       re.fullmatch(r"local-sha256:[0-9a-f]{64}", value) is not None)

if __name__ == "__main__":
    try:
        if len(sys.argv) == 3 and sys.argv[1] == "--cohort":
            print(json.dumps(read_cohort(sys.argv[2]), separators=(",", ":")))
            sys.exit(0)
        if len(sys.argv) != 2 or not pathlib.Path(sys.argv[1]).is_dir():
            raise ValueError("a measurements directory is required")
        print(json.dumps(summarize(sys.argv[1]), indent=2))
    except (ValueError, OSError, TypeError, KeyError, RecursionError):
        print("request report: invalid or unavailable measurement input; no report produced", file=sys.stderr)
        sys.exit(1)
