#!/usr/bin/env python3
"""Events-joined full-archive value sweep.

Scan every session transcript for reviewer-event head SHAs, stitch one arc per
paid review interaction, and Score value with Jev. This is the plan's join
("work sent to a reviewer" = events spine), not prose mentions.
"""
from __future__ import annotations

import json
import os
import re
import sys
import time
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from jev_review_waste_http import MODEL, ask, value_question, resolve_key  # noqa: E402
from jev_review_waste_arc import load_events, classify_bucket  # noqa: E402

CFG = json.loads((ROOT / "config" / "jev-decisions.json").read_text(encoding="utf-8"))
VL = CFG["decisions"]["value_level"]
ARCHIVE = Path(r"C:\Users\ahazan\Dropbox\ai\chat_transcripts")
EVENTS = Path.home() / ".local/state/ai-devops/reviewer-events/events.jsonl"
WORK = Path(os.environ.get("TEMP", ".")) / "jev-full-sweep-work"
WORK.mkdir(parents=True, exist_ok=True)
HEAD_RE = re.compile(rb"\b[0-9a-f]{40}\b")
CONCURRENCY = int(os.environ.get("JEV_SWEEP_CONCURRENCY", "6"))
MAX_ARC = 80000
WINDOW = 6000
OVERLAP = 1000


def score_one(key, arc):
    if len(arc) > MAX_ARC:
        arc = arc[:MAX_ARC]
    last = None
    for attempt in range(5):
        try:
            r = ask(arc, value_question(VL["instructions"], VL["criteria"]), key)
            a = r["answers"]["value_level"]
            conf = a.get("confidence") or 0
            probs = a.get("probabilities") or {}
            top = max(probs, key=probs.get) if probs else "1"
            idx = int(top) if str(top).isdigit() else 1
            label = VL["level_index"].get(str(idx), "none")
            if conf < VL["threshold"]["min_confidence"]:
                return {"label": "abstain", "conf": conf, "usage": r.get("usage") or {}}
            return {"label": label, "conf": conf, "usage": r.get("usage") or {}}
        except Exception as e:  # noqa: BLE001
            last = type(e).__name__
            time.sleep(0.6 * (attempt + 1))
    return {"label": "error", "conf": None, "usage": {}, "error": last}


def main() -> int:
    ts = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    t0 = time.time()
    key = resolve_key()
    by_head, head_to_run = load_events(EVENTS)
    head_bytes = {h.encode() for h in by_head}
    print(f"event_heads={len(by_head)}", flush=True)

    # Pass 1: find which heads appear in the archive (binary scan).
    head_hits = Counter()
    files = []
    for p in ARCHIVE.rglob("*.jsonl"):
        try:
            if p.stat().st_size >= 2000:
                files.append(p)
        except OSError:
            pass
    print(f"session_files={len(files)}", flush=True)
    for fi, p in enumerate(files, 1):
        try:
            raw = p.read_bytes()
        except OSError:
            continue
        for h in HEAD_RE.findall(raw):
            if h in head_bytes:
                head_hits[h.decode()] += 1
        if fi % 1000 == 0:
            print(f"  scanned {fi}/{len(files)} heads_found={len(head_hits)} "
                  f"elapsed={time.time()-t0:.0f}s", flush=True)
    print(f"scan done heads_in_archive={len(head_hits)}", flush=True)
    (WORK / "head-hits.json").write_text(json.dumps(dict(head_hits)), encoding="utf-8")

    # Pass 2: for each hit head, collect nearby text windows from files that mention it.
    # Build one arc per head (concatenate windows, cap 80KB).
    arcs = {}
    for fi, p in enumerate(files, 1):
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        # extract 40-hex tokens and match against known event heads
        for m in re.finditer(r"\b[0-9a-f]{40}\b", text):
            h = m.group(0)
            if h not in head_hits:
                continue
            start = max(0, m.start() - 2500)
            end = min(len(text), m.end() + 2500)
            snippet = text[start:end]
            prev = arcs.get(h, "")
            if len(prev) < MAX_ARC:
                arcs[h] = (prev + "\n" + snippet)[:MAX_ARC]
        if fi % 1000 == 0:
            print(f"  extract {fi}/{len(files)} arcs={len(arcs)} elapsed={time.time()-t0:.0f}s", flush=True)

    print(f"extract done arcs={len(arcs)}", flush=True)
    items = []
    for head, arc in arcs.items():
        events = by_head[head]
        bucket = classify_bucket(arc, events)
        provider = next((e.get("provider") for e in events if e.get("provider")), "")
        items.append((head, arc, bucket, provider))
    print(f"to_score={len(items)}", flush=True)

    results = [None] * len(items)
    with ThreadPoolExecutor(max_workers=CONCURRENCY) as ex:
        futs = {ex.submit(score_one, key, items[i][1]): i for i in range(len(items))}
        done = 0
        for fut in as_completed(futs):
            i = futs[fut]
            results[i] = fut.result()
            done += 1
            if done % 50 == 0:
                print(f"  scored {done}/{len(items)} elapsed={time.time()-t0:.0f}s", flush=True)

    value_labels = Counter()
    buckets = Counter()
    by_provider = Counter()
    cross = Counter()
    interactions = []
    usage = Counter()
    for (head, arc, bucket, provider), res in zip(items, results):
        buckets[bucket] += 1
        usage["in"] += int((res.get("usage") or {}).get("input_tokens") or 0)
        usage["out"] += int((res.get("usage") or {}).get("output_tokens") or 0)
        value_labels[res["label"]] += 1
        value_labels[f"{bucket}:{res['label']}"] += 1
        if res["label"] != "abstain" and res["label"] != "error":
            by_provider[provider or "?"] += 1
            cross[f"{provider or '?'}:{res['label']}"] += 1
        interactions.append({
            "head_prefix": head[:8],
            "provider": provider,
            "bucket": bucket,
            "label": res["label"],
        })

    low = value_labels.get("low", 0) + value_labels.get("none", 0) + value_labels.get("negative", 0)
    high = value_labels.get("highest", 0) + value_labels.get("medium", 0)

    report = ROOT / "tests" / "verification" / "jev" / f"review-waste-report-{ts}.md"
    lines = [
        f"# Review-waste report — full archive, events-joined ({ts})",
        "",
        f"**Model pin:** `{MODEL}`  ",
        "**Host:** edge-dev (Windows)  ",
        f"**Scale:** every session transcript ({len(files):,} files) scanned for "
        f"**all {len(by_head):,} reviewer-event heads**; {len(items)} arcs with archive "
        f"presence scored  ",
        "**Method:** events-spine join (paid reviews only) -> Jev Score value level  ",
        "**Privacy:** aggregates only  ",
        "",
        "## What this is",
        "",
        "Every review that was actually sent to a reviewer (per the reviewer events",
        "log) and appears in the transcript archive is scored for value. No sampling.",
        "Safety-gate reviews are bucketed separately.",
        "",
        "## Results",
        "",
        f"- Event heads in log: **{len(by_head):,}**",
        f"- Heads found in archive: **{len(head_hits):,}**",
        f"- Arcs scored: **{len(items)}**",
        f"- Buckets: `{dict(buckets)}`",
        f"- Value face labels: `{dict(value_labels)}`",
        f"- Low/none/negative: **{low}**; highest/medium: **{high}**; "
        f"abstain: **{value_labels.get('abstain', 0)}**; error: **{value_labels.get('error', 0)}**",
        f"- Jev usage: input={usage['in']:,} output={usage['out']:,} "
        f"(~${usage['in'] * 0.042 / 1e6:.2f} @ $0.042/1M)",
        f"- Wall time: {int(time.time() - t0)}s",
        "",
        "## Slices (n>=5)",
        "",
        "| slice | n |",
        "|---|---|",
    ]
    any_slice = False
    for k, v in sorted(by_provider.items()):
        if v >= 5:
            lines.append(f"| provider:{k} | {v} |")
            any_slice = True
    for k, v in sorted(cross.items()):
        if v >= 5:
            lines.append(f"| {k} | {v} |")
            any_slice = True
    if not any_slice:
        lines.append("| (suppressed) | |")

    lines += [
        "",
        "## Decision brief (options only — no policy change)",
        "",
        f"- Face levels across paid reviews found in the archive: "
        f"low/none/negative **{low}**, highest/medium **{high}**.",
        "- Safety-gate reviews stay in their own bucket.",
        "- Options: (a) shrink discretionary review traffic that clusters in none/low; "
        "(b) leave high-value slices alone; (c) this report is the baseline.",
        "",
        "## Artifacts",
        "",
        f"- This report: `{report.name}`",
        "- Prior: `review-waste-report-20261013T112939Z.md` (250-file sample)",
        "- Inventory: `review-waste-inventory-20261012T162801Z.md`",
        "",
    ]
    report.write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({
        "report": report.name,
        "event_heads": len(by_head),
        "heads_in_archive": len(head_hits),
        "arcs_scored": len(items),
        "value_labels": dict(value_labels),
        "usage": dict(usage),
        "wall_s": int(time.time() - t0),
    }, indent=2), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
