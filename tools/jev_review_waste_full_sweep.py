#!/usr/bin/env python3
"""Full-archive Jev review-waste sweep: every session transcript.

Sends all review-structural chunks from the local archive to Jev (Choice
filter + Score value). Aggregates only in the repo. Private work under TEMP.
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

CONCURRENCY = int(os.environ.get("JEV_SWEEP_CONCURRENCY", "8"))
# Full archive: no file cap, no per-file chunk cap.
WINDOW = 6000
OVERLAP = 1000
MAX_INTERACTIONS = int(os.environ.get("JEV_SWEEP_MAX_INTERACTIONS", "8000"))
PROGRESS_EVERY = 500


def filter_chunk(key, chunk):
    last_err = None
    for attempt in range(3):
        try:
            r = ask(chunk, chunk_question(CH["instructions"], CH["criteria"]), key)
            a = r["answers"]["chunk_filter"]
            usage = r.get("usage") or {}
            conf = a.get("confidence") or 0
            if conf < CH["threshold"]["min_confidence"]:
                return {"label": "abstain", "conf": conf, "usage": usage}
            return {"label": a.get("choice") or "unknown", "conf": conf, "usage": usage}
        except Exception as e:  # noqa: BLE001
            last_err = type(e).__name__
            time.sleep(0.3 * (attempt + 1))
    return {"label": "error", "conf": None, "usage": {}, "error": last_err}


def score_arc(key, arc):
    # Keep request well under max_request_bytes (256KB) including questions.
    if len(arc) > 80000:
        arc = arc[:80000]
    last_err = None
    for attempt in range(4):
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
            last_err = type(e).__name__
            time.sleep(0.4 * (attempt + 1))
    return {"label": "error", "conf": None, "usage": {}, "error": last_err}


def main() -> int:
    ts = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    t0 = time.time()
    key = resolve_key()
    by_head, head_to_run = load_events(EVENTS)
    heads_set = set(by_head.keys())

    # Enumerate every session jsonl
    files = []
    for p in ARCHIVE.rglob("*.jsonl"):
        try:
            sz = p.stat().st_size
        except OSError:
            continue
        if sz >= 2000:  # skip tiny junk
            files.append(p)
    print(f"session_files={len(files)} concurrency={CONCURRENCY}", flush=True)

    # Chunk everything; keep structural review-signal chunks as filter jobs.
    jobs = []
    n_chunks = 0
    skipped = 0
    files_read = 0
    for fi, fp in enumerate(files, 1):
        try:
            text = fp.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        files_read += 1
        for start, end, chunk in chunk_text(text, WINDOW, OVERLAP):
            n_chunks += 1
            if not has_review_signal(chunk):
                skipped += 1
                continue
            hs = set(HEAD_RE.findall(chunk)) & heads_set
            jobs.append((chunk, hs))
        if fi % 500 == 0:
            print(f"  chunked {fi}/{len(files)} chunks={n_chunks} jobs={len(jobs)} "
                  f"elapsed={time.time()-t0:.0f}s", flush=True)
    print(f"chunking done files_read={files_read} chunks={n_chunks} "
          f"filter_jobs={len(jobs)} skipped={skipped}", flush=True)

    # Filter all jobs
    results = [None] * len(jobs)
    usage = Counter()
    with ThreadPoolExecutor(max_workers=CONCURRENCY) as ex:
        futs = {ex.submit(filter_chunk, key, jobs[i][0]): i for i in range(len(jobs))}
        done = 0
        for fut in as_completed(futs):
            i = futs[fut]
            results[i] = fut.result()
            done += 1
            if done % PROGRESS_EVERY == 0:
                print(f"  filtered {done}/{len(jobs)} elapsed={time.time()-t0:.0f}s", flush=True)

    chunk_labels = Counter()
    marked = []
    for (chunk, hs), res in zip(jobs, results):
        chunk_labels[res["label"]] += 1
        usage["in"] += int((res.get("usage") or {}).get("input_tokens") or 0)
        usage["out"] += int((res.get("usage") or {}).get("output_tokens") or 0)
        if res["label"] == "review_interaction" or (hs and res["label"] not in ("error", "unrelated")):
            marked.append((chunk, hs))
    print(f"filter done labels={dict(chunk_labels)} marked={len(marked)}", flush=True)

    # Stitch
    groups = defaultdict(list)
    unjoined = 0
    for chunk, hs in marked:
        if not hs:
            unjoined += 1
            continue
        groups[sorted(hs)[0]].append(chunk)
    print(f"interactions_candidate={len(groups)} marked_unjoined={unjoined}", flush=True)

    # Persist stitched arcs privately so a failed value pass can resume.
    work = Path(os.environ.get("TEMP", ".")) / "jev-full-sweep-work"
    work.mkdir(parents=True, exist_ok=True)
    arcs_path = work / "arcs.jsonl"
    with arcs_path.open("w", encoding="utf-8") as f:
        for head, chunks in list(groups.items())[:MAX_INTERACTIONS]:
            arc = "\n".join(chunks)
            if len(arc) > 80000:
                arc = arc[:80000]
            events = by_head[head]
            bucket = classify_bucket(arc, events)
            provider = next((e.get("provider") for e in events if e.get("provider")), "")
            f.write(json.dumps({"head": head, "bucket": bucket, "provider": provider, "arc": arc}) + "\n")
    print(f"arcs_saved={arcs_path} n={min(len(groups), MAX_INTERACTIONS)}", flush=True)

    items = []
    for head, chunks in list(groups.items())[:MAX_INTERACTIONS]:
        arc = "\n".join(chunks)
        if len(arc) > 80000:
            arc = arc[:80000]
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
        done = 0
        for fut in as_completed(futs):
            i = futs[fut]
            vresults[i] = fut.result()
            done += 1
            if done % 200 == 0:
                print(f"  scored {done}/{len(items)} elapsed={time.time()-t0:.0f}s", flush=True)
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
        f"# Review-waste report — full archive ({ts})",
        "",
        f"**Model pin:** `{MODEL}`  ",
        "**Host:** edge-dev (Windows)  ",
        f"**Scale:** ALL session transcripts ({files_read} files read, {n_chunks:,} chunks); "
        f"filter jobs {len(jobs):,}; interactions scored {len(interactions)}  ",
        "**Method:** Jev Choice chunk filter -> event-head arc stitch -> Jev Score value level  ",
        "**Privacy:** aggregates only; no transcript text, no private identifiers, no archive paths  ",
        "",
        "## What this is",
        "",
        "A complete pass of the local AI session transcript archive through Jev.",
        "No sampling. Jev labels; no frontier LLM reads the archive for this report.",
        "Safety-gate reviews are bucketed separately and are not discretionary waste.",
        "",
        "## Results",
        "",
        f"- Session files read: **{files_read:,}**",
        f"- Chunks seen: **{n_chunks:,}** (no structural review signal skipped: {skipped:,})",
        f"- Chunk filter labels: `{dict(chunk_labels)}`",
        f"- Marked chunks: **{len(marked):,}**; stitched interactions scored: **{len(interactions)}**",
        f"- Buckets: `{dict(buckets)}`",
        f"- Value face labels: `{dict(value_labels)}`",
        f"- Low/none/negative: **{low}**; highest/medium: **{high}**; "
        f"abstain: **{value_labels.get('abstain', 0)}**; error: **{value_labels.get('error', 0)}**",
        f"- Jev usage: input={usage['in']:,} output={usage['out']:,} "
        f"(~${usage['in'] * 0.042 / 1e6:.2f} @ $0.042/1M)",
        f"- Wall time: {int(time.time() - t0)}s",
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

    # provider x face-label crosstab n>=5
    cross = Counter()
    for i in interactions:
        if i["label"] != "abstain":
            cross[f"{i['provider'] or '?'}:{i['label']}"] += 1
    lines += ["", "### Provider x value (n>=5)", "", "| slice | n |", "|---|---|"]
    any_cross = False
    for k, v in sorted(cross.items()):
        if v >= 5:
            lines.append(f"| {k} | {v} |")
            any_cross = True
    if not any_cross:
        lines.append("| (suppressed) | |")

    lines += [
        "",
        "## Decision brief (options only — no policy change)",
        "",
        f"- Full-archive face levels: low/none/negative **{low}**; highest/medium **{high}**.",
        "- Mandatory safety-gate traffic is separate and stays.",
        "- Options: (a) cut discretionary sends in slices dominated by none/low; "
        "(b) keep high-value slices unchanged; (c) treat this as the durable baseline; "
        "(d) sample a frontier LLM only on a small marked subset if deeper reading is wanted.",
        "",
        "## Contested / abstain",
        "",
        f"- Chunk-filter abstains: {chunk_labels.get('abstain', 0):,}",
        f"- Value abstains: {value_labels.get('abstain', 0)}",
        "- Negative requires arc evidence of pushback+withdraw or later-revert; else face level kept.",
        "",
        "## Artifacts",
        "",
        f"- This report: `{report.name}`",
        "- Pilot: `review-waste-report-20261012T180833Z.md`",
        "- Large sample: `review-waste-report-20261013T112939Z.md`",
        "- Inventory: `review-waste-inventory-20261012T162801Z.md`",
        "",
    ]
    report.write_text("\n".join(lines), encoding="utf-8")
    summary = {
        "report": report.name,
        "files_read": files_read,
        "chunks": n_chunks,
        "filter_jobs": len(jobs),
        "interactions": len(interactions),
        "chunk_labels": dict(chunk_labels),
        "value_labels": dict(value_labels),
        "usage": dict(usage),
        "wall_s": int(time.time() - t0),
    }
    print(json.dumps(summary, indent=2), flush=True)
    (Path(os.environ.get("TEMP", ".")) / "jev-full-sweep-summary.json").write_text(
        json.dumps(summary, indent=2), encoding="utf-8"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
