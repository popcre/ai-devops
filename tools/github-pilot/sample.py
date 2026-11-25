#!/usr/bin/env python3
"""Step 1 of plan_github-continuity-pilot.md: freeze the quota-hour and timing-day samples.

Usage: python3 tools/github-pilot/sample.py --raw DIR [--repo GIT_DIR] [--ref origin/main]
                [--start YYYY-MM-DD --end YYYY-MM-DD]

DIR holds one sub-directory per machine, each a private copy of that machine's
gh-throttle ``measurements/``, ``quota-measurements/`` and ``refusals.log``. The
script makes no network calls and prints a redacted aggregate (no principal hashes,
repository names, tokens or bodies). New York calendar days are the unit; the
window is [start, end] inclusive.

Quota windows are GitHub's own rolling hours: every snapshot carries the bucket's
reset epoch, and snapshots from different machines that share (bucket, reset) see
the same server window. T = limit - lowest remaining seen in that window. A window
is complete only when snapshots begin within 10 minutes of its start, end within 5
minutes of its reset, never leave a gap over 10 minutes, and remaining never rises
inside the window. Attribution follows the plan's T/S/O/U rule; opaque CLI counts
are reported as invocations, never converted into verified cost.
"""
import argparse
import collections
import datetime as dt
import json
import pathlib
import re
import subprocess
import sys

try:
    from zoneinfo import ZoneInfo
    NY = ZoneInfo("America/New_York")
except Exception:  # pragma: no cover - Windows Python without tzdata
    NY = None

FIRST_GAP = 600
LAST_GAP = 300
MAX_GAP = 600
STATUS_OPERATIONS = {"pr.view", "pr.checks", "pr.status", "run.view", "run.list", "graphql.pr_status"}
STATUS_CALLERS = {"ai-pr-wait", "ai-gh-wait"}


def ny_offset_hours(when):
    """US Eastern offset for a UTC datetime (falls back to the 2007 DST rule)."""
    if NY is not None:
        return int(when.astimezone(NY).utcoffset().total_seconds() // 3600)
    year = when.year
    march = dt.datetime(year, 3, 8, 7, tzinfo=dt.timezone.utc)
    march += dt.timedelta(days=(6 - march.weekday()) % 7)
    nov = dt.datetime(year, 11, 1, 6, tzinfo=dt.timezone.utc)
    nov += dt.timedelta(days=(6 - nov.weekday()) % 7)
    return -4 if march <= when < nov else -5


def ny_date(epoch):
    when = dt.datetime.fromtimestamp(epoch, dt.timezone.utc)
    return (when + dt.timedelta(hours=ny_offset_hours(when))).date()


def ny_day_bounds(day):
    noon = dt.datetime(day.year, day.month, day.day, 17, tzinfo=dt.timezone.utc)
    off = ny_offset_hours(noon)
    start = dt.datetime(day.year, day.month, day.day, tzinfo=dt.timezone.utc) - dt.timedelta(hours=off)
    return start.timestamp(), (start + dt.timedelta(days=1)).timestamp()


def epoch(utc):
    return dt.datetime.strptime(utc, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc).timestamp()


def iso(ts):
    return dt.datetime.fromtimestamp(ts, dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def read_jsonl(path, problems):
    out = []
    for number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        if not line.strip():
            continue
        try:
            out.append(json.loads(line))
        except ValueError:
            problems[f"{path.parent.parent.name}/{path.parent.name}"] += 1
    return out


def load(raw):
    problems = collections.Counter()
    snapshots, records, refusals = [], [], []
    for machine_dir in sorted(p for p in raw.iterdir() if p.is_dir()):
        machine = machine_dir.name
        for f in sorted((machine_dir / "quota-measurements").glob("*.jsonl")):
            for r in read_jsonl(f, problems):
                if r.get("measurement") != "server_bucket_snapshot" or not r.get("utc"):
                    continue
                for bucket, b in (r.get("buckets") or {}).items():
                    if not isinstance(b, dict) or None in (b.get("remaining"), b.get("limit"), b.get("reset")):
                        problems["snapshot_missing_field"] += 1
                        continue
                    snapshots.append({"machine": machine, "principal": r.get("principal") or "unknown",
                                      "t": epoch(r["utc"]), "bucket": bucket, "remaining": int(b["remaining"]),
                                      "limit": int(b["limit"]), "reset": int(b["reset"])})
        for f in sorted((machine_dir / "measurements").glob("*.jsonl")):
            for r in read_jsonl(f, problems):
                if r.get("utc"):
                    r["machine"] = machine
                    r["t"] = epoch(r["utc"])
                    records.append(r)
        log = machine_dir / "refusals.log"
        if log.exists():
            for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
                m = re.match(r"(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ) (\S+)(.*)", line)
                if not m:
                    continue
                res = re.search(r"resource=(\w+)", line)
                reset = re.search(r"reset=(\d+)", line)
                kind = re.search(r"kind=(\w+)", line)
                refusals.append({"machine": machine, "t": epoch(m.group(1)),
                                 "kind": kind.group(1) if kind else m.group(2),
                                 "bucket": res.group(1) if res else None,
                                 "reset": int(reset.group(1)) if reset else None})
    return snapshots, records, refusals, problems


def windows(snapshots):
    grouped = collections.defaultdict(list)
    for s in snapshots:
        grouped[(s["bucket"], s["reset"])].append(s)
    out = []
    for (bucket, reset), snaps in grouped.items():
        snaps.sort(key=lambda s: s["t"])
        start = reset - 3600
        inside = [s for s in snaps if start <= s["t"] < reset]
        if not inside:
            continue
        limit = max(s["limit"] for s in inside)
        times = [start] + [s["t"] for s in inside] + [reset]
        gaps = [b - a for a, b in zip(times, times[1:])]
        rises = sum(1 for a, b in zip(inside, inside[1:]) if b["remaining"] > a["remaining"])
        low = min(s["remaining"] for s in inside)
        complete = gaps[0] <= FIRST_GAP and gaps[-1] <= LAST_GAP and max(gaps) <= MAX_GAP and rises == 0
        reason = []
        if gaps[0] > FIRST_GAP:
            reason.append("late_first_snapshot")
        if gaps[-1] > LAST_GAP:
            reason.append("early_last_snapshot")
        if max(gaps) > MAX_GAP:
            reason.append("gap_over_10m")
        if rises:
            reason.append("remaining_rose")
        out.append({"bucket": bucket, "reset": reset, "start": start, "limit": limit,
                    "consumed": limit - low, "fraction": (limit - low) / limit if limit else 0,
                    "snapshots": len(inside), "machines": sorted({s["machine"] for s in inside}),
                    "principals": sorted({(s["machine"], s["principal"]) for s in inside}),
                    "max_gap_s": max(gaps), "complete": complete, "incomplete_reasons": reason})
    return sorted(out, key=lambda w: (w["start"], w["bucket"]))


ALLOCATIONS = {"discovery": 10, "drafts": 12, "status": 8, "timing": 20}
REQUEST_LINE = re.compile(r"^\* Request to (\S+)", re.M)


def count_exchanges(debug_text):
    """HTTP exchanges in GH_DEBUG=api output: one per request line, so redirects,
    retries and pages each count. Only the method-free URL path is kept."""
    return [re.sub(r"^https://[^/]+/|\?.*$", "", url) for url in REQUEST_LINE.findall(debug_text)]


def check_budget(rows, allocations=ALLOCATIONS):
    """Sum a live-request ledger per allocation; report any allocation overrun."""
    spent = collections.Counter()
    for row in rows:
        spent[row["alloc"]] += int(row["cost"])
    unknown = sorted(set(spent) - set(allocations))
    over = {k: spent[k] - v for k, v in allocations.items() if spent[k] > v}
    return {"spent": dict(spent), "total": sum(spent.values()),
            "limit": sum(allocations.values()), "over": over, "unknown_allocations": unknown,
            "ok": not over and not unknown and sum(spent.values()) <= sum(allocations.values())}


def is_status(r):
    op = r.get("operation") or ""
    return op in STATUS_OPERATIONS or (r.get("caller") in STATUS_CALLERS and op in {"api.graphql", "repo.view"})


def attribute(win, records, refusals):
    """Apply the plan's T/S/O/U rule to one window, in that bucket's units."""
    principals = {p for _, p in win["principals"] if p != "unknown"}
    in_win = [r for r in records if win["start"] <= r["t"] < win["reset"]]
    mine = [r for r in in_win if r.get("principal") in principals]
    s_cost = o_cost = 0
    if win["bucket"] == "graphql":
        # Only server-reported points for a reset matching this window are verified cost.
        for r in in_win:
            if r.get("measurement") != "observed_graphql_cost" or r.get("graphql_points") is None:
                continue
            reset_at = r.get("graphql_reset_at")
            if not reset_at or abs(epoch(reset_at) - win["reset"]) > 2:
                continue
            if r.get("operation") == "graphql.pr_status":
                s_cost += int(r["graphql_points"])
            else:
                o_cost += int(r["graphql_points"])
    t_total = win["consumed"]
    unknown = t_total - s_cost - o_cost
    invocations = collections.Counter()
    status_invocations = 0
    unknown_principal_invocations = 0
    for r in in_win:
        if r.get("measurement") not in ("opaque_cli_estimate", "direct_api_invocation_estimate"):
            continue
        if r.get("principal") not in principals:
            unknown_principal_invocations += r.get("cli_executions") or 1
            continue
        bucket = r.get("bucket") or "unknown"
        if bucket not in (win["bucket"], "unknown"):
            continue
        n = r.get("cli_executions") or 1
        invocations[(r.get("caller") or "unknown", r.get("operation") or "unknown", bucket)] += n
        if is_status(r):
            status_invocations += n
    if t_total <= 0 or unknown < 0:
        verdict = "inconclusive: inconsistent or empty total"
    elif s_cost / t_total >= 0.20:
        verdict = "run listener trial: verified status reads >= 20%"
    elif (s_cost + unknown) / t_total < 0.20:
        verdict = "rule out listener for this hour: (S+U)/T < 20%"
    else:
        verdict = "inconclusive: unattributed spend could change the decision"
    window_refusals = [x for x in refusals if win["start"] <= x["t"] < win["reset"]
                       and x["bucket"] in (win["bucket"], None)]
    largest = invocations.most_common(5)
    return {"T": t_total, "S_verified": s_cost, "O_verified": o_cost, "U_unattributed": unknown,
            "S_over_T": round(s_cost / t_total, 4) if t_total else None,
            "S_plus_U_over_T": round((s_cost + unknown) / t_total, 4) if t_total else None,
            "verdict": verdict,
            "local_invocations_same_identity": sum(invocations.values()),
            "status_read_invocations": status_invocations,
            "invocations_other_or_unknown_identity": unknown_principal_invocations,
            "largest_callers": [{"caller": c, "operation": o, "bucket": b, "invocations": n}
                                for (c, o, b), n in largest],
            "refusals_in_window": len(window_refusals),
            "refusal_kinds": dict(collections.Counter(x["kind"] for x in window_refusals))}


def coverage(days, snapshots, records):
    rows = []
    for day in days:
        lo, hi = ny_day_bounds(day)
        row = {"ny_date": day.isoformat()}
        for machine in sorted({s["machine"] for s in snapshots} | {r["machine"] for r in records}):
            snap_t = sorted(s["t"] for s in snapshots if s["machine"] == machine and lo <= s["t"] < hi)
            rec_n = sum(1 for r in records if r["machine"] == machine and lo <= r["t"] < hi)
            hours = {int((t - lo) // 3600) for t in snap_t}
            gaps = [b - a for a, b in zip([lo] + snap_t, snap_t + [hi])]
            row[machine] = {"request_records": rec_n, "snapshot_hours": len(hours),
                            "max_snapshot_gap_min": round(max(gaps) / 60, 1) if gaps else None}
        row["complete"] = all(isinstance(v, dict) and v["snapshot_hours"] == 24 and v["max_snapshot_gap_min"] <= 30
                              for k, v in row.items() if k not in ("ny_date",))
        rows.append(row)
    return rows


def busiest_day(repo, ref, days):
    """Distinct non-prose PRs landed on the first-parent history per New York day."""
    lo, _ = ny_day_bounds(days[0])
    _, hi = ny_day_bounds(days[-1])
    out = subprocess.run(["git", "-C", str(repo), "log", ref, "--first-parent", f"--since=@{int(lo) - 1}",
                          "--format=%H%x09%ct%x09%s"], capture_output=True, text=True, check=True).stdout
    per_day = collections.defaultdict(lambda: {"non_prose": [], "prose": [], "unnumbered": 0})
    for line in out.splitlines():
        sha, ct, subject = line.split("\t", 2)
        ct = int(ct)
        if not lo <= ct < hi:
            continue
        day = ny_date(ct).isoformat()
        m = re.search(r"\(#(\d+)\)\s*$", subject)
        if not m:
            per_day[day]["unnumbered"] += 1
            continue
        files = subprocess.run(["git", "-C", str(repo), "diff-tree", "--no-commit-id", "--name-only", "-r", sha],
                               capture_output=True, text=True, check=True).stdout.split()
        kind = "prose" if files and all(f.endswith(".md") for f in files) else "non_prose"
        per_day[day][kind].append(int(m.group(1)))
    table = [{"ny_date": d.isoformat(), "non_prose_prs": len(set(per_day[d.isoformat()]["non_prose"])),
              "prose_prs": len(set(per_day[d.isoformat()]["prose"])),
              "unnumbered_commits": per_day[d.isoformat()]["unnumbered"],
              "non_prose_pr_numbers": sorted(set(per_day[d.isoformat()]["non_prose"]))} for d in days]
    best = max(table, key=lambda r: (r["non_prose_prs"], -days.index(dt.date.fromisoformat(r["ny_date"]))))
    return table, best


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", required=True, type=pathlib.Path)
    ap.add_argument("--repo", type=pathlib.Path, default=pathlib.Path("."))
    ap.add_argument("--ref", default="origin/main")
    ap.add_argument("--start", required=True)
    ap.add_argument("--end", required=True)
    args = ap.parse_args(argv)
    first, last = dt.date.fromisoformat(args.start), dt.date.fromisoformat(args.end)
    days = [first + dt.timedelta(days=i) for i in range((last - first).days + 1)]
    snapshots, records, refusals, problems = load(args.raw)
    cov = coverage(days, snapshots, records)
    complete_days = [dt.date.fromisoformat(r["ny_date"]) for r in cov if r["complete"]]
    allw = windows(snapshots)
    lo, _ = ny_day_bounds(days[0])
    _, hi = ny_day_bounds(days[-1])
    eligible = [w for w in allw if w["complete"] and lo <= w["start"] and w["reset"] <= hi]
    peak = max(eligible, key=lambda w: (w["fraction"], -w["start"])) if eligible else None
    per_bucket = {}
    for bucket in sorted({w["bucket"] for w in eligible}):
        best = max((w for w in eligible if w["bucket"] == bucket), key=lambda w: (w["fraction"], -w["start"]))
        per_bucket[bucket] = best

    def show(w):
        return {"bucket": w["bucket"], "start": iso(w["start"]), "reset": iso(w["reset"]),
                "limit": w["limit"], "consumed": w["consumed"], "fraction": round(w["fraction"], 4),
                "snapshots": w["snapshots"], "machines": w["machines"],
                "machine_principals": len(w["principals"]), "max_gap_s": w["max_gap_s"]}

    report = {
        "schema": 1,
        "requested_ny_days": [d.isoformat() for d in days],
        "coverage": cov,
        "complete_ny_days": [d.isoformat() for d in complete_days],
        "parse_problems": dict(problems),
        "windows_total": len(allw),
        "windows_complete_in_range": len(eligible),
        "incomplete_reasons": dict(collections.Counter(r for w in allw if not w["complete"]
                                                       for r in w["incomplete_reasons"])),
        "refusals_in_range": dict(collections.Counter(f'{x["machine"]}:{x["kind"]}:{x["bucket"]}'
                                                      for x in refusals if lo <= x["t"] < hi)),
        "peak_window": show(peak) if peak else None,
        "peak_attribution": attribute(peak, records, refusals) if peak else None,
        "peak_by_bucket": {b: {"window": show(w), "attribution": attribute(w, records, refusals)}
                           for b, w in per_bucket.items()},
    }
    table, best = busiest_day(args.repo, args.ref, complete_days or days)
    report["timing_day_table"] = table
    report["timing_day"] = best
    json.dump(report, sys.stdout, indent=2, sort_keys=False)
    print()


if __name__ == "__main__":
    main()
