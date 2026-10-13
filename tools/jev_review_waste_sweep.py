#!/usr/bin/env python3
"""Large review-waste sweep: Jev chunk filter + event-head arc stitch + value Score.

Much larger than the 12-file pilot. Private work under TEMP. Repo tree gets
only the aggregate verification summary. No transcript text in the repo.
"""
from __future__ import annotations

import json
import os
import random
import re
import sys
import time
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from jev_review_waste_http import (  # noqa: E402
    MODEL, ask, chunk_question, value_question, resolve_key,
)
from jev_review_waste_chunker import chunk_text, has_review_signal  # noqa: E402
from jev_review_waste_arc import load_events, classify_bucket  # noqa: E402

CFG = json.loads((ROOT / "config" / "jev-decisions.json").read_text(encoding="utf-8"))
CH = CFG["decisions"]["chunk_filter"]
VL = CFG["decisions"]["value_level"]
ARCHIVE = Path(r"C:\Users\ahazan\Dropbox\ai\chat_transcripts")
EVENTS = Path.home() / ".local/state/ai-devops/reviewer-events/events.jsonl"
HEAD_RE = re.compile(r"\b[0-9a-f]{40}\b")

# Scale: 250 files x up to 12 chunks each, concurrency 6.
N_FILES = 250
MAX_CHUNKS_PER_FILE = 12
CONCURRENCY = 6
MAX_INTERACTIONS = 400


def sample_files(n: int, heads: set[str], seed: int = 21):
    random.seed(seed)
    cands = []
    for p in ARCHIVE.rglob("*.jsonl"):
        try:
            sz = p.stat().st_size
        except OSError:
            continue
        if 15_000 <= sz <= 3_000_000:
            cands.append(p)
    random.shuffle(cands)
    head_hits, review_hits = [], []
    for p in cands[:800]:
        try:
            raw = p.read_bytes()[:500_000]
        except OSError:
            continue
        text = raw.decode("utf-8", "replace")
        if heads and set(HEAD_RE.findall(text)) & heads:
            head_hits.append(p)
        elif b"ai-review" in raw or b"bin/ai-review" in raw:
            review_hits.append(p)
        if len(head_hits) >= n // 2 and len(head_hits) + len(review_hits) >= n:
            break
    picked = (head_hits + review_hits)[:n]
    return picked, len(head_hits), len(review_hits)


def filter_chunk(key, chunk):
    try:
        r = ask(chunk, chunk_question(CH["instructions"], CH["criteria"]), key)
        a = r["answers"]["chunk_filter"]
        usage = r.get("usage") or {}
        conf = a.get("confidence") or 0
        if conf < CH["threshold"]["min_confidence"]:
            return {"label": "abstain", "conf": conf, "usage": usage}
        return {"label": a.get("choice") or "unknown", "conf": conf, "usage": usage}
    except Exception as e:  # noqa: BLE001
        return {"label": "error", "conf": None, "usage": {}, "error": type(e).__name__}


def score_arc(key, arc):
    try:
        r = ask(arc, value_question(VL["instructions"], VL["criteria"]), key)
        a = r["answers"]["value_level"]
        usage = r.get("usage") or {}
        conf = a.get("confidence") or 0
        probs = a.get("probabilities") or {}
        top = max(probs, key=probs.get) if probs else "1"
        idx = int(top) if str(top).isdigit() else 1
        label = VL["level_index"].get(str(idx), "none")
        if conf < VL["threshold"]["min_confidence"]:
            return {"label": "abstain", "conf": conf, "usage": usage, "score": a.get("score")}
        return {"label": label, "conf": conf, "usage": usage, "score": a.get("score")}
    except Exception as e:  # noqa: BLE001
        return {"label": "error", "conf": None, "usage": {}, "error": type(e).__name__}


def main() -> int:
    ts = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    t0 = time.time()
    key = resolve_key()
    by_head, head_to_run = load_events(EVENTS)
    files, n_head_files, n_review_files = sample_files(N_FILES, set(by_head.keys()))
    print(f"sampled files={len(files)} head_join={n_head_files} review_only={n_review_files}", flush=True)

    # Build chunk jobs
    jobs = []  # (file, chunk, heads_in_chunk)
    n_chunks = 0
    skipped = 0
    for fp in files:
        try:
            text = fp.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        file_n = 0
        for start, end, chunk in chunk_text(text, 6000, 1000):
            if file_n >= MAX_CHUNKS_PER_FILE:
                break
            file_n += 1
            n_chunks += 1
            if not has_review_signal(chunk):
                skipped += 1
                continue
            heads = set(HEAD_RE.findall(chunk)) & set(by_head.keys())
            jobs.append((chunk, heads))
    print(f"chunks={n_chunks} review_marked_jobs={len(jobs)} no_signal_skipped={skipped}", flush=True)

    # Concurrent chunk filter (single pass, submit-order pairing)
    results = [None] * len(jobs)
    with ThreadPoolExecutor(max_workers=CONCURRENCY) as ex:
        futs = {ex.submit(filter_chunk, key, jobs[i][0]): i for i in range(len(jobs))}
        done = 0
        for fut in as_completed(futs):
            i = futs[fut]
            results[i] = fut.result()
            done += 1
            if done % 200 == 0:
                print(f"  filtered {done}/{len(jobs)} elapsed={time.time()-t0:.0f}s", flush=True)
    chunk_labels = Counter()
    usage = Counter()
    marked = []
    for (chunk, heads), res in zip(jobs, results):
        chunk_labels[res["label"]] += 1
        usage["in"] += int((res.get("usage") or {}).get("input_tokens") or 0)
        usage["out"] += int((res.get("usage") or {}).get("output_tokens") or 0)
        if res["label"] == "review_interaction" or (heads and res["label"] != "error"):
            marked.append((chunk, heads))

    print(f"filter done labels={dict(chunk_labels)} marked={len(marked)}", flush=True)

    # Stitch arcs by event head
    groups = defaultdict(list)
    unjoined = 0
    for chunk, heads in marked:
        if not heads:
            unjoined += 1
            continue
        groups[sorted(heads)[0]].append(chunk)
    print(f"interactions_candidate={len(groups)} marked_unjoined={unjoined}", flush=True)

    # Value Score on stitched arcs (capped)
    items = []
    for head, chunks in list(groups.items())[:MAX_INTERACTIONS]:
        arc = "\n".join(chunks)
        events = by_head[head]
        bucket = classify_bucket(arc, events)
        provider = next((e.get("provider") for e in events if e.get("provider")), "")
        items.append((head, arc, bucket, provider))

    value_labels = Counter()
    buckets = Counter()
    interactions = []
    vresults = [None] * len(items)
    with ThreadPoolExecutor(max_workers=CONCURRENCY) as ex:
        futs = {ex.submit(score_arc, key, items[i][1]): i for i in range(len(items))}
        for fut in as_completed(futs):
            i = futs[fut]
            vresults[i] = fut.result()
    for (head, arc, bucket, provider), res in zip(items, vresults):
        buckets[bucket] += 1
        usage["in"] += int((res.get("usage") or {}).get("input_tokens") or 0)
        usage["out"] += int((res.get("usage") or {}).get("output_tokens") or 0)
        value_labels[res["label"]] += 1
        value_labels[f"{bucket}:{res['label']}"] += 1
        interactions.append({
            "head_prefix": head[:8],
            "provider": provider,
            "bucket": bucket,
            "label": res["label"],
        })

    by_provider = Counter(i["provider"] or "?" for i in interactions if i["label"] != "abstain")
    by_bucket_label = Counter(f"{i['bucket']}:{i['label']}" for i in interactions if i["label"] != "abstain")
    low = value_labels.get("low", 0) + value_labels.get("none", 0) + value_labels.get("negative", 0)
    high = value_labels.get("highest", 0) + value_labels.get("medium", 0)

    report = ROOT / "tests" / "verification" / "jev" / f"review-waste-report-{ts}.md"
    lines = [
        f"# Review-waste report — large sweep ({ts})",
        "",
        f"**Model pin:** `{MODEL}`  ",
        "**Host:** edge-dev (Windows)  ",
        f"**Scale:** {len(files)} files, {n_chunks} chunks, filter jobs {len(jobs)}, "
        f"interactions scored {len(interactions)} (cap {MAX_INTERACTIONS})  ",
        "**Method:** Jev Choice chunk filter -> event-head arc stitch -> Jev Score value level  ",
        "**Privacy:** aggregates only; no transcript text, no private identifiers, no archive paths  ",
        "",
        "## What this is",
        "",
        "A much larger pass over the local AI session archive than the 12-file pilot.",
        "Jev (cheap decision model) labels chunks and review interactions. A frontier",
        "LLM is not used for this sweep. Safety-gate reviews are bucketed separately",
        "and are not counted as discretionary waste.",
        "",
        "## Results",
        "",
        f"- Files sampled: **{len(files)}** (event-head joined first, then review-marked)",
        f"- Chunks seen: **{n_chunks}** (no structural review signal skipped: {skipped})",
        f"- Chunk filter labels: `{dict(chunk_labels)}`",
        f"- Marked chunks: **{len(marked)}**; stitched interactions (capped): **{len(interactions)}**",
        f"- Buckets: `{dict(buckets)}`",
        f"- Value face labels: `{dict(value_labels)}`",
        f"- Low/none/negative: **{low}**; highest/medium: **{high}**; "
        f"abstain: **{value_labels.get('abstain', 0)}**; error: **{value_labels.get('error', 0)}**",
        f"- Jev usage this run: input={usage['in']:,} output={usage['out']:,} "
        f"(~${usage['in'] * 0.042 / 1e6:.2f} @ $0.042/1M)",
        f"- Wall time: {time.time() - t0:.0f}s",
        "",
        "## Slices (n>=5 only)",
        "",
        "| slice | n |",
        "|---|---|",
    ]
    any_slice = False
    for k, v in sorted(by_provider.items()):
        if v >= 5:
            lines.append(f"| provider:{k} | {v} |")
            any_slice = True
    for k, v in sorted(by_bucket_label.items()):
        if v >= 5:
            lines.append(f"| {k} | {v} |")
            any_slice = True
    if not any_slice:
        lines.append("| (no slice reached n>=5 — suppressed) | |")

    lines += [
        "",
        "## Decision brief (options only — no policy change)",
        "",
        f"- In this sweep, low/none/negative face levels: **{low}**; highest/medium: **{high}**.",
        "- Mandatory safety-gate interactions stay in their own bucket (not discretionary waste).",
        "- Options: (a) act on slices that cluster in low/none; (b) keep safety-gate traffic unchanged;",
        "  (c) expand holdout before any policy change; (d) stop here and treat this as the baseline.",
        "",
        "## Contested / abstain",
        "",
        f"- Chunk-filter abstains: {chunk_labels.get('abstain', 0)}",
        f"- Value abstains: {value_labels.get('abstain', 0)}",
        "- Negative-value rule: only when the arc shows pushback-with-evidence + withdraw, or a fix later reverted.",
        "  Face level is kept otherwise (not forced to negative).",
        "",
        "## Artifacts",
        "",
        "- Pilot report: `review-waste-report-20261012T180833Z.md`",
        f"- This report: `{report.name}`",
        f"- Inventory: `review-waste-inventory-20261012T162801Z.md`",
        f"- Calibration: `review-waste-chunk-shadow-20261012T180611Z.md`, "
        f"`review-waste-value-shadow-20261012T180611Z.md`",
        "",
    ]
    report.write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({
        "report": report.name,
        "files": len(files),
        "chunks": n_chunks,
        "filter_jobs": len(jobs),
        "interactions": len(interactions),
        "chunk_labels": dict(chunk_labels),
        "value_labels": dict(value_labels),
        "usage": dict(usage),
        "wall_s": int(time.time() - t0),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
