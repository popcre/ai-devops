#!/usr/bin/env python3
"""Offline P1 aggregation and explicit live waiter qualification.

Usage: python tools/github-requests/report.py MEASUREMENTS_DIRECTORY
The directory-summary mode makes no network calls and emits a scrubbed aggregate.
The explicit --qualify-wait mode executes the authorized waiter, which can make
normal paced GitHub calls; its separate live-parent receipt preserves unknowns.
Neither mode alone grants programme acceptance or authenticates edited artifacts.
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
import ctypes
import math
import selectors
import shutil
import subprocess
import time
import signal
import threading
from contextlib import contextmanager
from collections.abc import Mapping
from types import MappingProxyType
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
    read_observations = []
    write_observations = []
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
                            or row.get("acceptance") not in LOCAL_ACCEPTANCES
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
                        if row["acceptance"] == "qualified":
                            qualified_latency.append(end - start)
                            qualified_groups[("useful_work", row["boundary"], row["outcome"])].append(end - start)
                    elif row["acceptance"] == "qualified":
                        raise ValueError("qualified local observation without measured interval")
                    elif any(value is not None for value in numeric):
                        raise ValueError("invalid unknown local observation")
                    local_observations[row["workflow_id"]] = row
                    local_counts[row["outcome"]] += 1
                    local_reasons[reason] += 1
                    continue
                if row.get("schema") == 6:
                    row = json.loads(line, object_pairs_hook=unique_object)
                    measurement = row.get("measurement")
                    if measurement == "read_observation":
                        if (type(row.get("schema")) is not int or set(row) not in (READ_OBSERVATION_KEYS, READ_OBSERVATION_KEYS | READ_INTERVAL_KEYS)
                                or row.get("caller") not in CALLERS
                                or row.get("workflow") not in OBSERVATION_WORKFLOWS
                                or not valid_target_ordinal(row.get("target_ordinal"))
                                or row.get("source") not in ("cache", "upstream")
                                or type(row.get("cache_hit")) is not bool
                                or type(row.get("saved_upstream_read")) is not bool
                                or row["cache_hit"] != (row["source"] == "cache")
                                or row["saved_upstream_read"] != (row["source"] == "cache")):
                            raise ValueError("invalid read observation")
                        if "interval_version" in row and not valid_read_interval(row):
                            raise ValueError("invalid read interval")
                        read_observations.append(row)
                        continue
                    if measurement == "write_observation":
                        if (type(row.get("schema")) is not int or set(row) != WRITE_OBSERVATION_KEYS
                                or row.get("caller") not in CALLERS
                                or row.get("workflow") not in OBSERVATION_WORKFLOWS
                                or not valid_target_ordinal(row.get("target_ordinal"))
                                or row.get("action") not in ("written", "skipped")
                                or row.get("content_relation") not in ("new", "unchanged", "unknown")
                                or type(row.get("duplicate_unchanged_write")) is not bool
                                or row["duplicate_unchanged_write"] != (row["action"] == "written"
                                                                        and row["content_relation"] == "unchanged")):
                            raise ValueError("invalid write observation")
                        write_observations.append(row)
                        continue
                    raise ValueError("unsupported measurement schema")
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
    # A dispatch/cancel command does not prove remote verification finished.
    useful_completed_labels = {
        ("ai-pr-wait", "pr_wait", outcome) for outcome in ("merged", "closed", "checks_failed", "ejected")
    } | {("ai-blocker-watch", "blocker_watch_tick", "completed"),
         ("ai-transcript-destination-check", "transcript_privacy", "verified")}
    completed = sum(count for labels, count in outcome_counts.items() if labels in useful_completed_labels)
    context_ordinals = {context: i + 1 for i, context in enumerate(sorted({key[0] for key in cost_windows}))}
    # Same-target replay denominators for #658 section 13 item 2. A replay is
    # a later read of a correlated target already seen in this measurement set.
    prior_reads = {}
    read_total = read_uncorrelated = 0
    first_touch = replay_total = 0
    replay_cache = replay_upstream = 0
    cache_hits = upstream_reads = 0
    for row in read_observations:
        read_total += 1
        cache_hits += row["source"] == "cache"
        upstream_reads += row["source"] == "upstream"
        ordinal = row["target_ordinal"]
        if ordinal is None:
            read_uncorrelated += 1
            continue
        prior = prior_reads.get(ordinal, 0)
        prior_reads[ordinal] = prior + 1
        if prior == 0:
            first_touch += 1
        else:
            replay_total += 1
            if row["source"] == "cache":
                replay_cache += 1
            else:
                replay_upstream += 1
    replay_denominator = replay_total
    if replay_denominator > 0:
        replay_reduction = replay_cache / replay_denominator
    else:
        replay_reduction = None
    write_total = written_new = written_unchanged = written_unknown = skipped_unchanged = 0
    duplicate_unchanged_writes = 0
    for row in write_observations:
        write_total += 1
        if row["duplicate_unchanged_write"]:
            duplicate_unchanged_writes += 1
        if row["action"] == "skipped" and row["content_relation"] == "unchanged":
            skipped_unchanged += 1
        elif row["action"] == "written" and row["content_relation"] == "new":
            written_new += 1
        elif row["action"] == "written" and row["content_relation"] == "unchanged":
            written_unchanged += 1
        else:
            written_unknown += 1
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
        "section13_item2_redundant_reads": {
            "read_observations": read_total,
            "uncorrelated_reads": read_uncorrelated,
            "unique_correlated_targets": len(prior_reads),
            "first_touch_reads": first_touch,
            "same_target_replay_reads": replay_total,
            "replay_served_from_cache": replay_cache,
            "replay_served_upstream": replay_upstream,
            "cache_hits": cache_hits,
            "upstream_reads": upstream_reads,
            "replay_upstream_reduction_rate": replay_reduction,
            "note": ("denominator is same_target_replay_reads; unknown is never zero"
                     if replay_total else "no same-target replay denominator in this sample"),
        },
        "prospective_read_intervals": summarize_read_intervals(read_observations, receipts),
        "section13_item2_duplicate_writes": {
            "write_observations": write_total,
            "written_new": written_new,
            "written_unchanged": written_unchanged,
            "written_unknown_relation": written_unknown,
            "skipped_unchanged": skipped_unchanged,
            "duplicate_unchanged_writes": duplicate_unchanged_writes,
            "note": ("target is zero duplicate_unchanged_writes; unknown relation is not zero"
                     if write_total else "no write observations in this sample"),
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
                          "dispatch/cancel receipts measure commands, not remote verification completion",
                          "probe requests", "transformed GraphQL output hides HTTP-200 errors",
                          "telemetry warnings or interrupted processes may omit records",
                          "target-correlation adapter is local-only and not independently reviewed for acceptance"],
    }


OPERATIONS = {"unknown", "api.graphql", "api.quota", "api.identity", "api.unknown", "auth.status", "repo.view", "workflow.run"}
OPERATIONS.update("bw." + value for value in ("snapshot", "dependents", "wake_miss", "alarm_issue", "link_issue"))
OPERATIONS.update("pr." + value for value in ("view", "checks", "list", "merge", "create", "comment", "edit", "diff"))
OPERATIONS.update("issue." + value for value in ("view", "list", "create", "comment", "edit", "close", "reopen"))
OPERATIONS.update("run." + value for value in ("view", "list", "cancel"))
CALLERS = {"unknown", "interactive", "ai-pr-wait", "ai-gh-wait", "ai-blocker-watch", "ai-verify-run",
           "ai-memory-sync", "ai-test-local", "ai-merge-group-evidence",
           "ai-transcript-destination-check", "ai-workspace-status", "ai-reviewer-membership-drift",
           "ai-devops-doctor", "ai-devops-installer", "ai-task-gates", "review-fixer"}
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
RECEIPT_LABELS |= {
    ("ai-verify-run", workflow, outcome)
    for workflow, outcomes in (("verify_dispatch", ("dispatched", "duplicate_refused", "failed")),
                              ("verify_status", ("completed", "failed")),
                              ("verify_cancel", ("cancel_requested", "refused", "failed")))
    for outcome in outcomes
} | {("ai-transcript-destination-check", "transcript_privacy", outcome)
     for outcome in ("verified", "refused", "failed", "skipped")}
EVIDENCE_KEYS = {"schema", "utc", "measurement", "caller", "workflow", "workflow_id", "cohort_id", "target_ordinal",
                 "source_verified", "source_fingerprint_start", "source_fingerprint_end", "install_generation_binding",
                 "event_kind", "eligible_utc_ms", "observed_utc_ms", "delivered_utc_ms", "delivery_boundary",
                 "clock_quality", "clock_error_bound_ms", "latency_ms", "unknown_reason"}
LOCAL_KEYS = {"schema", "utc", "measurement", "caller", "workflow", "workflow_id", "outcome", "boundary", "clock_basis",
              "start_monotonic_ms", "end_monotonic_ms", "duration_lower_ms", "duration_upper_ms", "clock_error_bound_ms",
              "source_verified", "acceptance", "unknown_reason"}
READ_OBSERVATION_KEYS = {"schema", "utc", "measurement", "caller", "workflow", "target_ordinal", "source",
                         "cache_hit", "saved_upstream_read"}
READ_INTERVAL_KEYS = {"interval_version", "workflow_id", "workflow_correlation", "generation_ordinal",
                      "head_known", "head_matches", "arrival_utc_ms", "finish_utc_ms", "elapsed_monotonic_ms",
                      "clock_basis", "clock_state", "ttl_seconds", "force_refresh", "cache_age_ms", "cache_policy",
                      "ttl_cacheable", "clock_resolution_ms"}
WRITE_OBSERVATION_KEYS = {"schema", "utc", "measurement", "caller", "workflow", "target_ordinal", "action",
                          "content_relation", "duplicate_unchanged_write"}
# Keep in lockstep with telemetry.sh gh_measure_read_observation /
# gh_measure_write_observation; a wider emitter must never crash the report.
OBSERVATION_WORKFLOWS = {"pr_wait", "blocker_watch_tick", "blocker_watch_alarm",
                         "blocker_watch_links", "merge_group_evidence"}
LOCAL_OUTCOMES = {"merged", "closed", "checks_failed", "ejected", "deadline"}
LOCAL_CLOCK_BASES = {"linux_boottime_centiseconds", "unknown"}
LOCAL_REASONS = {"source_unknown", "clock_unknown", "clock_negative", "delivery_unknown"}
LOCAL_ACCEPTANCES = {"unknown", "qualified"}
SOURCE_STATES = {"verified", "changed", "unknown"}
EVENT_KINDS = {"pr_merged", "pr_closed", "check_completed", "unknown"}
DELIVERY_BOUNDARIES = {"terminal_report", "unknown"}
CLOCK_QUALITIES = {"verified_bound", "unverified", "jump", "negative", "unknown"}
UNKNOWN_REASONS = {"none", "metadata_absent", "metadata_untrusted", "source_unknown", "source_changed",
                   "event_unknown", "event_invalid", "clock_unknown", "clock_jump", "clock_negative", "delivery_unknown"}


def valid_workflow_id(value):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{32}", value) is not None


def valid_read_interval(row):
    elapsed = row["elapsed_monotonic_ms"]
    if (type(row["interval_version"]) is not int or row["interval_version"] != 1
            or not valid_workflow_id(row["workflow_id"])
            or row["workflow_correlation"] not in ("workflow", "unknown")
            or not valid_target_ordinal(row["generation_ordinal"])
            or type(row["head_known"]) is not bool or row["head_matches"] is not None and type(row["head_matches"]) is not bool
            or not row["head_known"] and (row["head_matches"] is not None or row["generation_ordinal"] is not None)
            or not valid_timestamp_ms(row["arrival_utc_ms"]) or not valid_timestamp_ms(row["finish_utc_ms"])
            or row["clock_basis"] != "python_monotonic" or row["clock_state"] not in ("local_unqualified", "jump", "unavailable")
            or row["clock_resolution_ms"] is not None and (type(row["clock_resolution_ms"]) is not int or not 1 <= row["clock_resolution_ms"] <= 1000)
            or row["ttl_seconds"] is not None and (type(row["ttl_seconds"]) is not int or not 1 <= row["ttl_seconds"] <= 1000000000)
            or type(row["force_refresh"]) is not bool or type(row["ttl_cacheable"]) is not bool
            or row["cache_age_ms"] is not None and not valid_latency(row["cache_age_ms"])
            or row["cache_policy"] not in ("upstream", "in_flight", "ttl")
            or row["source"] == "upstream" and (row["cache_policy"] != "upstream" or row["cache_age_ms"] is not None)
            or row["source"] == "cache" and (row["cache_policy"] == "upstream" or row["cache_age_ms"] is None)):
        return False
    if elapsed is not None and (type(elapsed) is not list or len(elapsed) != 2
            or not all(type(value) is int and 0 <= value <= 604800000 for value in elapsed)
            or elapsed[0] > elapsed[1]):
        return False
    if row["clock_state"] == "local_unqualified":
        if elapsed is None or row["arrival_utc_ms"] is None or row["finish_utc_ms"] is None or row["clock_resolution_ms"] is None:
            return False
        margin = 2 * row["clock_resolution_ms"]
        return elapsed[0] - margin <= row["finish_utc_ms"] - row["arrival_utc_ms"] <= elapsed[1] + margin
    if row["clock_state"] == "unavailable":
        return elapsed is None and (row["arrival_utc_ms"] is None or row["finish_utc_ms"] is None or row["clock_resolution_ms"] is None)
    return True


def summarize_read_intervals(rows, receipts):
    intervals = [row for row in rows if "interval_version" in row]
    states = collections.Counter(row["clock_state"] for row in intervals)
    known, overlaps, ttl_candidates, linked, unlinked = {}, 0, 0, 0, 0
    continuous = all(row["clock_state"] == "local_unqualified" for row in intervals)
    for row in sorted(intervals, key=lambda item: item["arrival_utc_ms"] if item["arrival_utc_ms"] is not None else -1):
        receipt = receipts.get(row["workflow_id"])
        if row["workflow_correlation"] == "workflow" and receipt is not None:
            if receipt[:2] != (row["caller"], row["workflow"]):
                raise ValueError("read interval and workflow labels disagree")
            linked += 1
        else:
            unlinked += 1
        generation = row["generation_ordinal"]
        if generation is not None and (row["head_matches"] is not True or row["force_refresh"]):
            known.pop(generation, None)
        if (not continuous or row["clock_state"] != "local_unqualified" or generation is None
                or not row["head_known"] or row["head_matches"] is not True or row["force_refresh"]
                or row["workflow_correlation"] != "workflow"):
            continue
        prior = known.get(row["generation_ordinal"])
        if prior is not None and prior["workflow_id"] != row["workflow_id"]:
            margin = row["clock_resolution_ms"] + prior["clock_resolution_ms"]
            if row["arrival_utc_ms"] + margin < prior["finish_utc_ms"]:
                overlaps += 1
            elif (prior["ttl_cacheable"] and row["ttl_seconds"] is not None
                    and 0 <= row["arrival_utc_ms"] - prior["finish_utc_ms"] < row["ttl_seconds"] * 1000 - margin):
                ttl_candidates += 1
        # A cache consumer does not refresh the underlying snapshot. Using its
        # finish as a new TTL origin would invent eligibility after a slow
        # consumer or a chain of reads of an aging response.
        if row["source"] == "upstream":
            known[row["generation_ordinal"]] = row
    return {"records": len(intervals), "legacy_records": len(rows) - len(intervals),
            "clock_states": dict(sorted(states.items())), "linked_workflow_records": linked,
            "unlinked_workflow_records": unlinked, "conditional_overlap_candidates": overlaps,
            "conditional_ttl_candidates": ttl_candidates,
            "clock_continuity": "local_only" if continuous and intervals else "unknown",
            "qualification": "unknown: local intervals do not certify source, UTC bounds or safety latency"}


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


def qualification_clock():
    """Read the Linux kernel's current UTC error bound; never change its clock.

    Unsupported ABIs and unsynchronized clocks remain unknown. The wall and
    monotonic readings bracket adjtimex, including the sampling interval in
    the returned bound. No environment or cohort file supplies a bound.
    """
    if not sys.platform.startswith("linux") or ctypes.sizeof(ctypes.c_long) != 8:
        return None
    class Timeval(ctypes.Structure):
        _fields_ = [("sec", ctypes.c_long), ("usec", ctypes.c_long)]
    class Timex(ctypes.Structure):
        _fields_ = [("modes", ctypes.c_uint), ("offset", ctypes.c_long), ("freq", ctypes.c_long),
                    ("maxerror", ctypes.c_long), ("esterror", ctypes.c_long), ("status", ctypes.c_int),
                    ("constant", ctypes.c_long), ("precision", ctypes.c_long), ("tolerance", ctypes.c_long),
                    ("time", Timeval), ("tick", ctypes.c_long), ("ppsfreq", ctypes.c_long),
                    ("jitter", ctypes.c_long), ("shift", ctypes.c_int), ("stabil", ctypes.c_long),
                    ("jitcnt", ctypes.c_long), ("calcnt", ctypes.c_long), ("errcnt", ctypes.c_long),
                    ("stbcnt", ctypes.c_long), ("tai", ctypes.c_int), ("reserved", ctypes.c_int * 11)]
    try:
        before = time.monotonic_ns()
        value = Timex()  # modes=0 is a read, never a synchronization request.
        library = ctypes.CDLL(None, use_errno=True)
        library.adjtimex.argtypes = [ctypes.POINTER(Timex)]
        library.adjtimex.restype = ctypes.c_int
        status = library.adjtimex(ctypes.byref(value))
        wall = time.time_ns()
        after = time.monotonic_ns()
        # TIME_OK only: leap transitions, TIME_ERROR, UNSYNC and CLOCKERR do
        # not qualify an interval. maxerror is microseconds, not milliseconds.
        if (status != 0 or value.status & (0x0040 | 0x1000)
                or not 0 <= value.maxerror <= 59_000_000 or after < before):
            return None
        bound = math.ceil(value.maxerror / 1000 + (after - before) / 1_000_000)
        return {"wall_ms": wall // 1_000_000, "monotonic_ms": after // 1_000_000,
                "error_bound_ms": bound, "basis": "linux_adjtimex_maxerror"}
    except (OSError, ValueError, AttributeError, OverflowError):
        return None


def qualify_event(event, start, end, source_verified):
    """Qualify a live parent observation, keeping uncertainty as an interval.

    GitHub's eligible event is only second-resolution. Its 1000ms uncertainty
    is included rather than pretending it is a millisecond clock reading.
    Kernel UTC synchronization is a host bound, not a GitHub clock audit;
    the resulting interval is explicitly conditional on GitHub event UTC.
    """
    result = {"clock_quality": "unknown", "unknown_reason": "clock_unknown",
              "latency_lower_ms": None, "latency_upper_ms": None,
              "clock_error_bound_ms": None, "event_kind": "unknown"}
    if not source_verified:
        result["unknown_reason"] = "source_unknown"
        return result
    if not unqualified_event(event):
        result["unknown_reason"] = "event_unknown"
        return result
    result["event_kind"] = event["event_kind"]
    if (event["event_kind"] == "unknown" or event["eligible_utc_ms"] is None
            or event["delivery_boundary"] != "terminal_report"):
        result["unknown_reason"] = "event_unknown"
        return result
    if start is None or end is None:
        return result
    elapsed_wall = end["wall_ms"] - start["wall_ms"]
    elapsed_mono = end["monotonic_ms"] - start["monotonic_ms"]
    bound = start["error_bound_ms"] + end["error_bound_ms"] + 2
    if elapsed_wall < 0 or elapsed_mono < 0 or abs(elapsed_wall - elapsed_mono) > bound:
        result["unknown_reason"] = "clock_jump"
        return result
    eligible, observed, delivered = (event[name] for name in
                                    ("eligible_utc_ms", "observed_utc_ms", "delivered_utc_ms"))
    if (observed is None or delivered is None or not eligible <= observed <= delivered
            or observed < start["wall_ms"] - bound or delivered > end["wall_ms"] + bound):
        result["unknown_reason"] = "event_invalid"
        return result
    # Parent receives the event only after the known waiter reported terminal
    # output. Its clock read bounds when that delivery was actually observed.
    error = bound + 1000
    elapsed = delivered - eligible
    if elapsed > 604_800_000 or error > 60_000:
        result["unknown_reason"] = "clock_unknown"
        return result
    result.update(clock_quality="host_bound_github_utc_assumed", unknown_reason="none",
                  latency_lower_ms=max(0, elapsed - error), latency_upper_ms=elapsed + error,
                  clock_error_bound_ms=error)
    return result


def unqualified_event(row):
    """The child supplies only the existing scrubbed, unqualified schema."""
    return (isinstance(row, dict) and set(row) == EVIDENCE_KEYS
            and type(row.get("schema")) is int and row["schema"] == 4
            and row["measurement"] == "workflow_evidence"
            and row["caller"] == "ai-pr-wait" and row["workflow"] == "pr_wait"
            and isinstance(row["utc"], str)
            and re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", row["utc"]) is not None
            and valid_workflow_id(row["workflow_id"]) and valid_nullable_id(row["cohort_id"])
            and valid_target_ordinal(row["target_ordinal"])
            and row["source_verified"] == "unknown" and row["clock_quality"] == "unknown"
            and row["source_fingerprint_start"] is None and row["source_fingerprint_end"] is None
            and row["install_generation_binding"] is None and row["clock_error_bound_ms"] is None
            and row["latency_ms"] is None and isinstance(row["event_kind"], str) and row["event_kind"] in EVENT_KINDS
            and all(valid_timestamp_ms(row[name]) for name in
                    ("eligible_utc_ms", "observed_utc_ms", "delivered_utc_ms"))
            and isinstance(row["delivery_boundary"], str) and row["delivery_boundary"] in DELIVERY_BOUNDARIES
            and isinstance(row["unknown_reason"], str) and row["unknown_reason"] in UNKNOWN_REASONS
            and evidence_consistent(row))


def trusted_boundary_executable(path):
    """Same root-owned native Bubblewrap boundary used by the supervisor."""
    path = pathlib.Path(path).resolve(strict=True)
    for parent in path.parents:
        info = parent.stat()
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o022:
            raise ValueError("boundary executable ancestor is untrusted")
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        info = os.fstat(descriptor)
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o022
                or not info.st_mode & 0o111 or os.read(descriptor, 4) != b"\x7fELF"):
            raise ValueError("boundary executable is untrusted")
    finally:
        os.close(descriptor)
    return str(path)


def sealed_source(data):
    import fcntl
    descriptor = os.memfd_create("github-qualified-source", os.MFD_CLOEXEC | os.MFD_ALLOW_SEALING)
    try:
        remaining = memoryview(data)
        while remaining:
            count = os.write(descriptor, remaining)
            if count <= 0:
                raise OSError("source snapshot write stopped")
            remaining = remaining[count:]
        os.fchmod(descriptor, 0o500)
        seals = fcntl.F_SEAL_WRITE | fcntl.F_SEAL_GROW | fcntl.F_SEAL_SHRINK | fcntl.F_SEAL_SEAL
        fcntl.fcntl(descriptor, fcntl.F_ADD_SEALS, seals)
        if fcntl.fcntl(descriptor, fcntl.F_GET_SEALS) & seals != seals:
            raise OSError("source snapshot seals differ")
        os.lseek(descriptor, 0, os.SEEK_SET)
        return descriptor
    except BaseException:
        os.close(descriptor)
        raise


def protected_directory(path):
    """Open a fixed system directory through root-owned, non-writable ancestors."""
    path = pathlib.Path(path)
    descriptor = os.open(path.anchor, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        for part in path.parts[1:]:
            next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
                              dir_fd=descriptor)
            os.close(descriptor)
            descriptor = next_fd
            info = os.fstat(descriptor)
            if info.st_uid != 0 or info.st_mode & 0o022:
                raise ValueError("canonical installation ancestor is untrusted")
        return descriptor
    except BaseException:
        os.close(descriptor)
        raise


def canonical_installation(root, manifest, manifest_fd=None):
    """Only the actual protected installation can certify current source.

    The public CLI has no fixture-manifest or generation-override mode. Tests
    substitute this internal I/O boundary, never a runtime environment switch.
    The supported installer owns its 0600 manifest as the installing account;
    its system directory and public launcher ancestors remain root-owned.
    """
    directory = protected_directory("/etc/ai-devops")
    descriptor = None
    try:
        if manifest_fd is None:
            descriptor = os.open("install-manifest.tsv", os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK,
                                 dir_fd=directory)
        else:
            import fcntl
            if fcntl.fcntl(manifest_fd, fcntl.F_GETFL) & os.O_ACCMODE != os.O_RDONLY:
                raise ValueError("manifest descriptor is not readonly")
            descriptor = os.dup(manifest_fd)
        info = os.fstat(descriptor)
        canonical = os.stat("install-manifest.tsv", dir_fd=directory, follow_symlinks=False)
        supplied = os.stat(manifest, follow_symlinks=False)
        if (not stat.S_ISREG(info.st_mode) or info.st_uid not in (0, os.geteuid())
                or info.st_mode & 0o077 or info.st_nlink != 1 or info.st_size > 4 * 1024 * 1024
                or not stat.S_ISREG(canonical.st_mode)
                or (info.st_dev, info.st_ino) != (canonical.st_dev, canonical.st_ino)
                or not stat.S_ISREG(supplied.st_mode) or (info.st_dev, info.st_ino) != (supplied.st_dev, supplied.st_ino)):
            raise ValueError("canonical manifest custody differs")
        data = os.pread(descriptor, 4 * 1024 * 1024 + 1, 0)
    finally:
        if descriptor is not None:
            os.close(descriptor)
        os.close(directory)
    directory = protected_directory("/usr/local/bin")
    try:
        info = os.stat("ai-pr-wait", dir_fd=directory, follow_symlinks=False)
        if not stat.S_ISLNK(info.st_mode) or info.st_uid != 0:
            raise ValueError("canonical launcher custody differs")
        launcher = pathlib.Path("/usr/local/bin/ai-pr-wait")
        target = launcher.resolve(strict=True)
        if not root.samefile(target.parent.parent) or not (root / "bin/ai-pr-wait").samefile(target):
            raise ValueError("canonical source root differs")
    finally:
        os.close(directory)
    return data, launcher


class SourceFiles(dict):
    """Exact public file bytes plus Git's executable-bit metadata."""
    def __init__(self):
        super().__init__()
        self.modes = {}
        self.loaded = {}


class VerifiedGitObjects:
    """One finite local cat-file stream, with bounded frames and object hashes."""
    def __init__(self, command, environment):
        self.process = subprocess.Popen([*command, "cat-file", "--batch"], env=environment,
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        self.selector = selectors.DefaultSelector()
        self.selector.register(self.process.stdout, selectors.EVENT_READ)
        self.buffer = bytearray()
        self.total = 0
    def _fill(self, deadline):
        remaining = deadline - time.monotonic()
        if remaining <= 0 or not self.selector.select(timeout=remaining):
            raise ValueError("Git object read deadline exceeded")
        chunk = os.read(self.process.stdout.fileno(), 65536)
        if not chunk:
            raise ValueError("Git object stream ended")
        self.buffer.extend(chunk)
    def read(self, kind, oid):
        if kind not in ("commit", "tree", "blob") or re.fullmatch(r"[0-9a-f]{40}", oid) is None:
            raise ValueError("invalid Git object request")
        deadline = time.monotonic() + 10
        self.process.stdin.write(oid.encode("ascii") + b"\n")
        self.process.stdin.flush()
        while b"\n" not in self.buffer:
            if len(self.buffer) > 128:
                raise ValueError("Git object header exceeds bound")
            self._fill(deadline)
        end = self.buffer.index(b"\n")
        header = bytes(self.buffer[:end]).split(b" ")
        del self.buffer[:end + 1]
        if (len(header) != 3 or header[:2] != [oid.encode("ascii"), kind.encode("ascii")]
                or re.fullmatch(b"[0-9]{1,8}", header[2]) is None):
            raise ValueError("Git object header differs")
        length = int(header[2]); self.total += length
        if length > 4 * 1024 * 1024 or self.total > 64 * 1024 * 1024:
            raise ValueError("Git source exceeds bound")
        while len(self.buffer) < length + 1:
            self._fill(deadline)
        value = bytes(self.buffer[:length])
        if self.buffer[length] != 10:
            raise ValueError("Git object framing differs")
        del self.buffer[:length + 1]
        if hashlib.sha1(kind.encode("ascii") + b" " + str(length).encode("ascii") + b"\0" + value).hexdigest() != oid:
            raise ValueError("Git object identity differs")
        return value
    def close(self):
        try:
            self.process.stdin.close()
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill(); self.process.wait()
        finally:
            self.selector.close()
            self.process.stdout.close()


def installed_source(root, manifest, manifest_fd=None):
    """Verify canonical installed identity and immutable raw Git objects."""
    root = pathlib.Path(root).resolve(strict=True)
    data, launcher = (canonical_installation(root, manifest) if manifest_fd is None
                      else canonical_installation(root, manifest, manifest_fd))
    rows = [row.split("\t") for row in data.decode("utf-8").splitlines()]
    sha_rows = [row for row in rows if len(row) == 4 and row[:2] == ["meta", "source_sha"]]
    if len(sha_rows) != 1 or re.fullmatch(r"[0-9a-f]{40}", sha_rows[0][2]) is None:
        raise ValueError("manifest source is untrusted")
    sha = sha_rows[0][2]
    entries = [row for row in rows if len(row) == 4 and row[0] == "symlink"
               and pathlib.Path(row[1]).name == "ai-pr-wait"]
    if len(entries) != 1 or not pathlib.Path(entries[0][2]).samefile(root / "bin/ai-pr-wait"):
        raise ValueError("installed waiter differs")
    if not pathlib.Path(entries[0][1]).samefile(launcher):
        raise ValueError("installed launcher differs")
    git = trusted_boundary_executable(shutil.which("git") or "")
    git_environment = {name: value for name, value in os.environ.items() if not name.startswith("GIT_")}
    git_environment["GIT_NO_REPLACE_OBJECTS"] = "1"
    git_environment.update(GIT_NO_LAZY_FETCH="1", GIT_ATTR_NOSYSTEM="1")
    git_command = [git, "--no-replace-objects", "-c", "core.attributesFile=/dev/null", "-C", str(root)]
    def git_read(*arguments, input_data=None):
        return subprocess.run([*git_command, *arguments], input=input_data,
                              env=git_environment, capture_output=True, check=True, timeout=20).stdout
    if git_read("rev-parse", "--verify", "HEAD^{commit}").strip().decode("ascii") != sha:
        raise ValueError("installed HEAD differs from completed manifest")
    # Read-only source inspection is isolated from the command's GIT_* values;
    # the actual command below inherits every ordinary runtime setting intact.
    git_read("diff", "--quiet", "--ignore-submodules=all", sha, "--")
    attributes_path = pathlib.Path(git_read("rev-parse", "--git-path", "info/attributes").decode("utf-8").strip())
    if not attributes_path.is_absolute():
        attributes_path = root / attributes_path
    if attributes_path.exists() and any(line.strip() and not line.lstrip().startswith(b"#")
                                        for line in attributes_path.read_bytes().splitlines()):
        raise ValueError("local source attributes are unqualified")
    reader = VerifiedGitObjects(git_command, git_environment)
    try:
        files = generation_files(reader, sha)
    finally:
        reader.close()
    if hashlib.sha256(files["bin/ai-pr-wait"]).hexdigest() != entries[0][3]:
        raise ValueError("manifest waiter hash differs")
    raw_attributes = git_read("check-attr", f"--source={sha}", "-z", "--stdin", "eol", "filter", "working-tree-encoding",
                              input_data=b"\0".join(path.encode("utf-8") for path in sorted(files)) + b"\0").split(b"\0")
    if raw_attributes[-1:] != [b""] or (len(raw_attributes) - 1) % 3:
        raise ValueError("source attributes framing differs")
    attributes = {}
    for offset in range(0, len(raw_attributes) - 1, 3):
        path, name, value = (item.decode("utf-8") for item in raw_attributes[offset:offset + 3])
        if path not in files or name not in ("eol", "filter", "working-tree-encoding") or (path, name) in attributes:
            raise ValueError("source attributes differ")
        attributes[path, name] = value
    fingerprint, loaded_fingerprint = hashlib.sha256(), hashlib.sha256()
    for path, content in sorted(files.items()):
        if (attributes.get((path, "filter")) not in ("unspecified", "unset")
                or attributes.get((path, "working-tree-encoding")) not in ("unspecified", "unset")
                or attributes.get((path, "eol")) not in ("unspecified", "lf", "crlf")):
            raise ValueError("custom source materialization is unqualified")
        materialized = content
        if attributes[path, "eol"] == "crlf" and b"\0" not in content:
            materialized = content.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
        files.loaded[path] = materialized
        fingerprint.update(path.encode("utf-8") + b"\0" + hashlib.sha256(content).hexdigest().encode("ascii") + b"\n")
        loaded_fingerprint.update(path.encode("utf-8") + b"\0" + hashlib.sha256(materialized).hexdigest().encode("ascii") + b"\n")
    return {"source_sha": sha, "source_fingerprint": fingerprint.hexdigest(),
            "loaded_source_fingerprint": loaded_fingerprint.hexdigest(), "materialization": "committed_git_eol_only",
            "source_scope": "git_eol_bin_tools_config_attributes_v1",
            "install_generation_binding": hashlib.sha256(data).hexdigest()}, files


def generation_files(reader, sha):
    """Verify the complete selected commit/tree/blob closure via one batch."""
    commit = reader.read("commit", sha)
    first_line = commit.split(b"\n", 1)[0]
    if re.fullmatch(b"tree [0-9a-f]{40}", first_line) is None:
        raise ValueError("commit source tree differs")
    def tree_entries(oid):
        raw, offset, names = reader.read("tree", oid), 0, set()
        while offset < len(raw):
            space = raw.index(b" ", offset)
            zero = raw.index(b"\0", space + 1)
            mode, name = raw[offset:space], raw[space + 1:zero].decode("utf-8")
            end = zero + 21
            if end > len(raw) or name in ("", ".", "..") or "/" in name or name in names:
                raise ValueError("tree source entry differs")
            names.add(name)
            yield mode, name, raw[zero + 1:end].hex()
            offset = end
    def source_entries(oid, prefix=""):
        for mode, name, child in tree_entries(oid):
            path = f"{prefix}/{name}" if prefix else name
            if not prefix and name not in ("bin", "tools", "config", ".gitattributes"):
                continue
            if mode == b"40000":
                yield from source_entries(child, path)
            elif mode in (b"100644", b"100755") and (prefix or name == ".gitattributes"):
                yield path, child, mode
            else:
                raise ValueError("unsupported source tree entry")
    files, total_bytes = SourceFiles(), 0
    for path, blob, mode in source_entries(first_line[5:].decode("ascii")):
        content = reader.read("blob", blob)
        total_bytes += len(content)
        if len(content) > 4 * 1024 * 1024 or total_bytes > 64 * 1024 * 1024 or len(files) >= 4096:
            raise ValueError("source file exceeds bound")
        files[path] = content
        files.modes[path] = 0o500 if mode == b"100755" else 0o400
    if not files or len(files) > 4096 or "bin/ai-pr-wait" not in files:
        raise ValueError("source generation is incomplete")
    return files


_GENERATION_AUTHORITY = object()
_ACTIVE_GENERATIONS = {}


class RetainedGenerationMapping(Mapping):
    """Opaque live custody, deliberately not constructible from serialized data."""
    def __init__(self, authority, values, descriptors):
        if authority is not _GENERATION_AUTHORITY:
            raise ValueError("generation custody requires its live factory")
        self._values = MappingProxyType(dict(values, identity=MappingProxyType(dict(values["identity"]))))
        self._descriptors = tuple((fd, os.fstat(fd).st_dev, os.fstat(fd).st_ino) for fd in descriptors)
        self._authority = authority
        self._active = True
        _ACTIVE_GENERATIONS[id(self)] = self
    def __getitem__(self, key): return self._values[key]
    def __iter__(self): return iter(self._values)
    def __len__(self): return len(self._values)


def retained_generation_valid(value):
    """Only a live factory result with still-held immutable source can attest."""
    if (type(value) is not RetainedGenerationMapping or not value._active
            or value._authority is not _GENERATION_AUTHORITY or _ACTIVE_GENERATIONS.get(id(value)) is not value):
        return False
    import fcntl
    required = fcntl.F_SEAL_WRITE | fcntl.F_SEAL_GROW | fcntl.F_SEAL_SHRINK | fcntl.F_SEAL_SEAL
    try:
        for descriptor, device, inode in value._descriptors:
            info = os.fstat(descriptor)
            if ((info.st_dev, info.st_ino) != (device, inode) or not stat.S_ISREG(info.st_mode)
                    or fcntl.fcntl(descriptor, fcntl.F_GET_SEALS) & required != required):
                return False
    except OSError:
        return False
    return True


@contextmanager
def retained_generation_launch(boundary):
    """Give each invocation independent offsets; concurrent reads stay parallel."""
    import fcntl
    if not retained_generation_valid(boundary):
        raise ValueError("generation custody is not live")
    if _FD_LEASE is not None and _FD_LEASE[0] != _FD_LEASE[1] and threading.active_count() != 1:
        raise ValueError("raised descriptor custody requires a single-threaded parent")
    opened, replacements = [], {}
    try:
        for descriptor, _, _ in boundary._descriptors:
            raw = os.open(f"/proc/self/fd/{descriptor}", os.O_RDONLY | os.O_CLOEXEC)
            try:
                borrowed = fcntl.fcntl(raw, fcntl.F_DUPFD_CLOEXEC, 2048)
            finally:
                os.close(raw)
            opened.append(borrowed)
            replacements[str(descriptor)] = str(borrowed)
        command = list(boundary["argv_prefix"])
        for index in range(1, len(command)):
            if command[index - 1] == "--ro-bind-data":
                command[index] = replacements[command[index]]
        yield {"argv_prefix": command, "pass_fds": tuple(opened)}
        if not retained_generation_valid(boundary):
            raise ValueError("generation custody changed during execution")
    finally:
        for descriptor in opened:
            os.close(descriptor)


_FD_LEASE = None


@contextmanager
def source_descriptor_lease(required):
    """Only a single-threaded parent may temporarily raise its soft ceiling."""
    import resource
    global _FD_LEASE
    current = resource.getrlimit(resource.RLIMIT_NOFILE)
    original = _FD_LEASE[0] if _FD_LEASE is not None else current
    expected = _FD_LEASE[1] if _FD_LEASE is not None else current
    if current != expected or (_FD_LEASE is not None and original != expected and threading.active_count() != 1):
        raise ValueError("descriptor limit changed outside custody")
    raised = required > current[0]
    if raised and (threading.active_count() != 1 or required > current[1]):
        raise ValueError("descriptor ceiling cannot safely be raised")
    previous = _FD_LEASE
    active = (max(current[0], required), current[1])
    if raised:
        resource.setrlimit(resource.RLIMIT_NOFILE, active)
    _FD_LEASE = (original, active)
    try:
        yield original if active != original else None
    finally:
        observed = resource.getrlimit(resource.RLIMIT_NOFILE)
        _FD_LEASE = previous
        if observed != active:
            raise ValueError("descriptor limit changed outside custody")
        if raised:
            resource.setrlimit(resource.RLIMIT_NOFILE, current)


@contextmanager
def retained_generation(root, manifest, manifest_fd=None):
    """Retain one immutable loaded-source boundary for waiters or ai-gh reads.

    Consumers prepend argv_prefix to their real command and include pass_fds
    in that subprocess only. Identity alone is preparation, never execution
    proof; only an actual observed child result can qualify loaded source.
    """
    bootstrap_started = time.perf_counter_ns()
    root = pathlib.Path(root).resolve(strict=True)
    # Preserve ambient behavior on the ordinary path. An explicit qualifier
    # cannot attribute code injected by shell/Python startup or native-loader
    # overrides to the tracked toolkit generation, so it declines qualification.
    injection_keys = {"BASH_ENV", "ENV", "PYTHONPATH", "PYTHONHOME", "PYTHONSTARTUP", "PYTHONINSPECT",
                      "PYTHONUSERBASE", "LD_PRELOAD", "LD_LIBRARY_PATH"}
    if any(value and (name in injection_keys or name.startswith("BASH_FUNC_"))
           for name, value in os.environ.items()):
        raise ValueError("ambient source injection is unqualified")
    if not sys.platform.startswith("linux") or not hasattr(os, "memfd_create"):
        raise ValueError("boundary unavailable")
    boundary = trusted_boundary_executable(shutil.which("bwrap") or "")
    probe = subprocess.run([boundary, "--unshare-user", "--bind", "/", "/", "--dev-bind", "/dev", "/dev", "--cap-drop", "ALL",
                            "--", "/usr/bin/true"], capture_output=True, timeout=10)
    if probe.returncode:
        raise ValueError("boundary unavailable")
    identity, files = (installed_source(root, manifest) if manifest_fd is None
                       else installed_source(root, manifest, manifest_fd))
    command = [boundary, "--unshare-user", "--die-with-parent", "--bind", "/", "/",
               "--dev-bind", "/dev", "/dev", "--cap-drop", "ALL"]
    descriptors, custody = [], None
    lease = source_descriptor_lease(2048 + 2 * len(files) + 64)
    child_limits = lease.__enter__()
    try:
        for directory in ("bin", "tools", "config"):
            command += ["--tmpfs", str(root / directory)]
        directories = sorted({str(pathlib.PurePosixPath(name).parent) for name in files},
                             key=lambda value: (value.count("/"), value))
        made = {"bin", "tools", "config"}
        for directory in directories:
            parts = pathlib.PurePosixPath(directory).parts
            for depth in range(1, len(parts) + 1):
                parent = "/".join(parts[:depth])
                if parent not in made:
                    command += ["--dir", str(root / parent)]
                    made.add(parent)
        for name, content in files.loaded.items():
            import fcntl
            raw_fd = sealed_source(content)
            try:
                fd = fcntl.fcntl(raw_fd, fcntl.F_DUPFD_CLOEXEC, 2048)
            finally:
                os.close(raw_fd)
            descriptors.append(fd)
            command += ["--perms", f"{files.modes[name]:04o}", "--ro-bind-data", str(fd), str(root / name)]
        for directory in ("bin", "tools", "config"):
            command += ["--remount-ro", str(root / directory)]
        identity["source_boundary"] = "linux_sealed_generation"
        bash = trusted_boundary_executable(shutil.which("bash") or "")
        payload_prefix = []
        if child_limits is not None:
            limiter = trusted_boundary_executable(shutil.which("prlimit") or "")
            payload_prefix = [limiter, "--nofile=" + ":".join(map(str, child_limits)), "--"]
        custody = RetainedGenerationMapping(_GENERATION_AUTHORITY,
                    {"identity": identity, "mount_prefix": tuple([*command, "--"]),
                     "execution_prefix": tuple(payload_prefix),
                     "argv_prefix": tuple([*command, "--", *payload_prefix]), "pass_fds": tuple(descriptors),
                     "root": str(root), "transport_path": str(root / "bin/ai-gh"), "bash_path": bash,
                     "bootstrap_ns": time.perf_counter_ns() - bootstrap_started}, descriptors)
        yield custody
    finally:
        if custody is not None:
            custody._active = False
            _ACTIVE_GENERATIONS.pop(id(custody), None)
        for fd in descriptors:
            os.close(fd)
        lease.__exit__(None, None, None)


def qualify_wait(root, manifest, arguments, receipt_path, manifest_fd=None):
    """Explicit live parent; offline JSON and child environment grant no trust.

    Qualification failure runs the original command normally and records an
    unknown receipt. No automatic fallback runs after a child has started.
    Network, cwd, authentication, stdio and command status remain inherited.
    Only the pinned public source directories are replaced inside the child.
    """
    qualification_started = time.perf_counter_ns()
    root = pathlib.Path(root).resolve(strict=True)
    receipt = {"schema": 1, "measurement": "live_parent_wait_qualification",
               "receipt_origin": "live_parent", "source_verified": "unknown",
               "execution_profile": ("root" if os.geteuid() == 0 else "installed_owner"
                                     if os.geteuid() == root.stat().st_uid else "other_user"),
               "workload_kind": "fixture" if os.environ.get("AI_DEVOPS_TEST_MODE") == "1" else "caller_command",
               "source_boundary": "unknown", "unknown_reason": "boundary_unavailable",
               "source_sha": None, "source_fingerprint": None, "install_generation_binding": None,
               "child_exit": None, "clock_start": None, "clock_end": None, "event": None,
               "event_qualification": None, "source_bootstrap_ns": None, "qualification_elapsed_ns": None}
    descriptors, command, generation_context, launch_context = [], None, None, None
    read_fd = write_fd = None
    environment = os.environ.copy()
    environment.pop("AI_GH_QUALIFICATION_EVENT_FD", None)
    try:
        receipt["unknown_reason"] = "manifest_untrusted"
        generation_context = (retained_generation(root, manifest) if manifest_fd is None
                              else retained_generation(root, manifest, manifest_fd))
        generation = generation_context.__enter__()
        launch_context = retained_generation_launch(generation)
        launch = launch_context.__enter__()
        command = list(launch["argv_prefix"])
        read_fd, write_fd = os.pipe()
        descriptors += [read_fd, write_fd]
        environment["AI_GH_QUALIFICATION_EVENT_FD"] = str(write_fd)
        command += [generation["bash_path"],
                    str(root / "bin/ai-pr-wait"), *arguments]
        receipt.update(generation["identity"], source_verified="verified",
                       unknown_reason="none", source_bootstrap_ns=generation["bootstrap_ns"])
    except (OSError, ValueError, subprocess.SubprocessError, UnicodeError):
        command = [shutil.which("bash") or "/bin/bash", str(root / "bin/ai-pr-wait"), *arguments]
        environment.pop("AI_GH_QUALIFICATION_EVENT_FD", None)
        for fd in descriptors:
            os.close(fd)
        descriptors = []
        read_fd = write_fd = None
        if generation_context is not None:
            if launch_context is not None:
                launch_context.__exit__(None, None, None)
                launch_context = None
            generation_context.__exit__(None, None, None)
            generation_context = None
    start = qualification_clock()
    events, event_bytes = [], bytearray()
    child, selector = None, None
    previous_term = None
    class QualificationCancelled(BaseException):
        def __init__(self, signum): self.signum = signum
    def cancelled(signum, frame):
        raise QualificationCancelled(signum)
    if threading.current_thread() is threading.main_thread():
        previous_term = signal.signal(signal.SIGTERM, cancelled)
    try:
        inherited = tuple(descriptors) + (launch["pass_fds"] if generation_context is not None else ())
        # Own only this command's group. The normal waiter already supervises
        # native calls; this outer group also covers cancellation during setup
        # or before that inner supervisor has started.
        child = subprocess.Popen(command, env=environment, pass_fds=inherited, start_new_session=True)
        if write_fd is not None:
            os.close(write_fd)
            descriptors.remove(write_fd)
        if read_fd is not None:
            os.set_blocking(read_fd, False)
            selector = selectors.DefaultSelector()
            selector.register(read_fd, selectors.EVENT_READ)
            while child.poll() is None:
                for key, _ in selector.select(timeout=0.1):
                    chunk = os.read(key.fd, 65537)
                    if not chunk:
                        selector.unregister(key.fd)
                        continue
                    # Keep draining an oversized pipe so optional evidence
                    # cannot deadlock the original command. Retain only one
                    # overflow byte, which makes the event unqualified.
                    if len(event_bytes) <= 65536:
                        event_bytes.extend(chunk[:65537 - len(event_bytes)])
                # No report-controlled wait deadline replaces the waiter's own.
            while True:
                try:
                    chunk = os.read(read_fd, 65537)
                except BlockingIOError:
                    break
                if not chunk:
                    break
                if len(event_bytes) <= 65536:
                    event_bytes.extend(chunk[:65537 - len(event_bytes)])
            selector.close()
        status = child.wait()
        end = qualification_clock()
        if len(event_bytes) <= 65536:
            try:
                events = [json.loads(line, object_pairs_hook=unique_object)
                          for line in event_bytes.splitlines() if line]
            except (ValueError, UnicodeError):
                events = []
        event = events[0] if len(events) == 1 else None
        if (not unqualified_event(event)
                or {"pr_merged": 0, "pr_closed": 1, "check_completed": 1}.get(event["event_kind"], status) != status):
            event = None
        if (event is None or (generation_context is not None and not retained_generation_valid(generation))) and receipt["source_verified"] == "verified":
            # No bound waiter observation proves that execution crossed the
            # prepared boundary. Retain identity as preparation, not proof.
            receipt["source_verified"] = "unknown"
            receipt["unknown_reason"] = "child_observation_missing"
        receipt.update(child_exit=status, clock_start=start, clock_end=end, event=event,
                       event_qualification=qualify_event(event, start, end, receipt["source_verified"] == "verified"),
                       qualification_elapsed_ns=time.perf_counter_ns() - qualification_started)
        # The qualification parent consumes and assembles evidence under live
        # sealed-FD custody. This saved artifact is a historical receipt, never
        # an offline input that upgrades ordinary report/schema-4 evidence.
        try:
            destination = pathlib.Path(receipt_path)
            if not destination.parent.is_dir() or destination.exists() or destination.is_symlink():
                raise ValueError("qualification receipt destination is unavailable")
            fd = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
            with os.fdopen(fd, "w") as stream:
                json.dump(receipt, stream, separators=(",", ":"))
                stream.write("\n")
        except (OSError, ValueError):
            print("request qualification: receipt unavailable; original command status preserved", file=sys.stderr)
        return status if status >= 0 else 128 - status
    except (KeyboardInterrupt, QualificationCancelled) as interruption:
        signum = interruption.signum if isinstance(interruption, QualificationCancelled) else signal.SIGINT
        if child is not None:
            try:
                os.killpg(child.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(child.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                child.wait()
        return 128 + signum
    finally:
        if selector is not None:
            selector.close()
        if previous_term is not None:
            signal.signal(signal.SIGTERM, previous_term)
        for fd in descriptors:
            try:
                os.close(fd)
            except OSError:
                pass
        if generation_context is not None:
            if launch_context is not None:
                launch_context.__exit__(None, None, None)
            generation_context.__exit__(None, None, None)

if __name__ == "__main__":
    try:
        if len(sys.argv) > 1 and sys.argv[1] == "--qualify-wait":
            import argparse
            parser = argparse.ArgumentParser(description="Run an explicitly qualified live PR waiter")
            parser.add_argument("--source-root", required=True)
            parser.add_argument("--manifest", default="/etc/ai-devops/install-manifest.tsv")
            parser.add_argument("--manifest-fd", type=int)
            parser.add_argument("--receipt", required=True)
            parser.add_argument("arguments", nargs=argparse.REMAINDER)
            options = parser.parse_args(sys.argv[2:])
            arguments = options.arguments
            if arguments[:1] == ["--"]:
                arguments = arguments[1:]
            if not arguments:
                parser.error("waiter arguments are required")
            sys.exit(qualify_wait(options.source_root, options.manifest, arguments, options.receipt, options.manifest_fd))
        if len(sys.argv) == 3 and sys.argv[1] == "--cohort":
            print(json.dumps(read_cohort(sys.argv[2]), separators=(",", ":")))
            sys.exit(0)
        if len(sys.argv) != 2 or not pathlib.Path(sys.argv[1]).is_dir():
            raise ValueError("a measurements directory is required")
        print(json.dumps(summarize(sys.argv[1]), indent=2))
    except (ValueError, OSError, TypeError, KeyError, RecursionError):
        print("request report: invalid or unavailable measurement input; no report produced", file=sys.stderr)
        sys.exit(1)
