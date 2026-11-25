#!/usr/bin/env python3
"""Deterministic timing report for GitHub Actions run data.

Library and CLI. Standard library only. No network.

Usage: python3 timing.py INPUT.json   (prints a JSON report to stdout)
"""

import json
import sys
from collections import defaultdict
from datetime import datetime, timezone
from fractions import Fraction

CATEGORIES = ("cancelled", "rerun", "merge_group", "pr", "other")
EXCLUSION_REASONS = ("null_time", "negative_time", "duplicate")
EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)


def parse_ts(value):
    """ISO 8601 UTC string (e.g. 2026-11-23T14:05:09Z) -> integer epoch seconds."""
    if value is None:
        return None
    text = value[:-1] + "+00:00" if value.endswith("Z") else value
    dt = datetime.fromisoformat(text)
    if dt.tzinfo is None:
        raise ValueError("timestamp without timezone: %s" % value)
    return int((dt - EPOCH).total_seconds())


def nearest_rank(values, pct):
    """Nearest-rank percentile: value at 1-based rank ceil(pct/100 * n). None if empty."""
    if not values:
        return None
    ordered = sorted(values)
    rank = -((-(pct * len(ordered))) // 100)  # integer ceil(pct * n / 100)
    return ordered[rank - 1]


def _stats(values):
    return {
        "n": len(values),
        "median": nearest_rank(values, 50),
        "p95": nearest_rank(values, 95),
    }


def _categorize(run, job):
    if job.get("conclusion") == "cancelled" or run.get("conclusion") == "cancelled":
        return "cancelled"
    if run["attempt"] > 1:
        return "rerun"
    if run["event"] == "merge_group":
        return "merge_group"
    if run["event"] == "pull_request":
        return "pr"
    return "other"


def _ready(created, settle, needs, by_name):
    """Return (ready_at, readiness) for a job. readiness is 'known' or 'unknown'."""
    if not needs:
        return created + settle, "known"
    latest = None
    for name in needs:
        prereqs = by_name.get(name)
        if not prereqs:
            return None, "unknown"
        for prereq in prereqs:
            if prereq.get("completed_at") is None:
                return None, "unknown"
            done = parse_ts(prereq["completed_at"])
            if latest is None or done > latest:
                latest = done
    return max(created + settle, latest), "known"


def _latest(records, predicate):
    values = [r["completed"] for r in records if predicate(r)]
    return max(values) if values else None


def _elapsed(value, first):
    return None if value is None else value - first


def _pr_critical_path(number, required, included):
    considered = [
        r for r in included if r["pr"] == number and r["category"] != "cancelled"
    ]
    if not considered:
        return {
            "pr": number,
            "considered_jobs": 0,
            "first_created": None,
            "pr_checks_done_s": None,
            "required_done_s": None,
            "advisory_done_s": None,
            "merge_group_done_s": None,
            "critical_path_s": None,
        }
    first = min(r["created"] for r in considered)
    required = set(required)
    pr_jobs = lambda r: r["event"] == "pull_request"
    return {
        "pr": number,
        "considered_jobs": len(considered),
        "first_created": first,
        "pr_checks_done_s": _elapsed(_latest(considered, pr_jobs), first),
        "required_done_s": _elapsed(
            _latest(considered, lambda r: pr_jobs(r) and r["name"] in required), first
        ),
        "advisory_done_s": _elapsed(
            _latest(considered, lambda r: pr_jobs(r) and r["name"] not in required), first
        ),
        "merge_group_done_s": _elapsed(
            _latest(considered, lambda r: r["event"] == "merge_group"), first
        ),
        "critical_path_s": _elapsed(_latest(considered, lambda r: True), first),
    }


def analyze(data):
    """Build the full timing report from parsed INPUT.json data."""
    seen = set()
    excluded_jobs = []
    included = []

    for run in data.get("runs", []):
        created = parse_ts(run["created_at"])
        settle = run.get("settle_seconds", 0) or 0
        kept = []  # non-duplicate jobs, valid or not; used for prerequisite lookup
        valid = []
        for job in run.get("jobs", []):
            key = (run["run_id"], run["attempt"], job["job_id"])
            if key in seen:
                reason = "duplicate"
            else:
                seen.add(key)
                kept.append(job)
                reason = None
                if job.get("started_at") is None or job.get("completed_at") is None:
                    reason = "null_time"
                else:
                    started = parse_ts(job["started_at"])
                    completed = parse_ts(job["completed_at"])
                    if completed - started < 0 or started < created:
                        reason = "negative_time"
            if reason is None:
                valid.append(job)
            else:
                excluded_jobs.append({
                    "pr": run.get("pr"),
                    "run_id": run["run_id"],
                    "attempt": run["attempt"],
                    "job_id": job["job_id"],
                    "name": job.get("name"),
                    "reason": reason,
                })
        by_name = defaultdict(list)
        for job in kept:
            by_name[job["name"]].append(job)
        for job in valid:
            started = parse_ts(job["started_at"])
            completed = parse_ts(job["completed_at"])
            ready_at, readiness = _ready(created, settle, job.get("needs") or [], by_name)
            included.append({
                "run_id": run["run_id"],
                "attempt": run["attempt"],
                "job_id": job["job_id"],
                "name": job["name"],
                "workflow": run["workflow"],
                "event": run["event"],
                "pr": run.get("pr"),
                "category": _categorize(run, job),
                "runner_label": job["runner_label"],
                "created": created,
                "started": started,
                "completed": completed,
                "settle_seconds": settle,
                "start_minus_created": started - created,
                "duration": completed - started,
                "readiness": readiness,
                "ready_wait": started - ready_at if readiness == "known" else None,
            })

    groups = defaultdict(list)
    for rec in included:
        groups[(rec["category"], rec["workflow"], rec["runner_label"])].append(rec)
    group_out = []
    for key in sorted(groups):
        members = groups[key]
        known = [m["ready_wait"] for m in members if m["readiness"] == "known"]
        group_out.append({
            "category": key[0],
            "workflow": key[1],
            "runner_label": key[2],
            "n": len(members),
            "start_minus_created": _stats([m["start_minus_created"] for m in members]),
            "duration": _stats([m["duration"] for m in members]),
            "ready_wait": _stats(known),
            "unknown_readiness": len(members) - len(known),
        })

    totals = {}
    for cat in CATEGORIES:
        members = [m for m in included if m["category"] == cat]
        totals[cat] = {
            "jobs": len(members),
            "settle_seconds": sum(m["settle_seconds"] for m in members),
            "ready_wait_seconds": sum(
                m["ready_wait"] for m in members if m["readiness"] == "known"
            ),
            "unknown_readiness": sum(1 for m in members if m["readiness"] == "unknown"),
        }

    excluded_counts = {reason: 0 for reason in EXCLUSION_REASONS}
    for entry in excluded_jobs:
        excluded_counts[entry["reason"]] += 1

    prs = [
        _pr_critical_path(pr["number"], pr.get("required_checks") or [], included)
        for pr in data.get("prs", [])
    ]
    for pr, out in zip(data.get("prs", []), prs):
        enqueued, merged = pr.get("enqueued_at"), pr.get("merged_at")
        out["enqueued_to_merged_s"] = (
            parse_ts(merged) - parse_ts(enqueued)
            if enqueued is not None and merged is not None
            else None
        )

    return {
        "jobs": included,
        "groups": group_out,
        "totals": totals,
        "excluded": excluded_counts,
        "excluded_jobs": excluded_jobs,
        "prs": prs,
    }


def paired_gate(pairs):
    """Decide whether a candidate beats a baseline on paired (baseline, candidate) seconds."""
    pairs = list(pairs)
    n = len(pairs)
    median_baseline = nearest_rank([b for b, _ in pairs], 50)
    median_candidate = nearest_rank([c for _, c in pairs], 50)
    p90_diff = nearest_rank([c - b for b, c in pairs], 90)
    improvement = None
    if median_baseline is not None and median_baseline > 0:
        improvement = Fraction(1) - Fraction(median_candidate) / Fraction(median_baseline)
    result = {
        "n": n,
        "median_baseline": median_baseline,
        "median_candidate": median_candidate,
        "improvement": None if improvement is None else float(improvement),
        "p90_diff": p90_diff,
        "passed": False,
        "reason": None,
    }
    if n < 20:
        result["reason"] = "fewer_than_20_pairs"
    elif median_baseline <= 0:
        result["reason"] = "non_positive_baseline"
    elif improvement < Fraction(1, 5):
        result["reason"] = "improvement_below_20_percent"
    elif p90_diff > 0:
        result["reason"] = "p90_diff_positive"
    else:
        result["passed"] = True
    return result


def main(argv):
    if len(argv) != 2:
        sys.stderr.write("usage: python3 timing.py INPUT.json\n")
        return 2
    with open(argv[1], encoding="utf-8") as handle:
        data = json.load(handle)
    print(json.dumps(analyze(data), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
