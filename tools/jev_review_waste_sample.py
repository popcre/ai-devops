#!/usr/bin/env python3
"""Phase 3.4 / 4.4 bounded real-archive sample, then Phase 5 aggregates.

Private working dir under TEMP. Repo tree gets only the verification summary.
"""
from __future__ import annotations

import json
import os
import random
import re
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from jev_review_waste_http import MODEL, ask, chunk_question, value_question, resolve_key  # noqa: E402
from jev_review_waste_chunker import chunk_text, digest_of, has_review_signal  # noqa: E402
from jev_review_waste_arc import load_events, chunk_heads, classify_bucket  # noqa: E402

CFG = json.loads((ROOT / "config" / "jev-decisions.json").read_text(encoding="utf-8"))
CH = CFG["decisions"]["chunk_filter"]
VL = CFG["decisions"]["value_level"]
ARCHIVE = Path(r"C:\Users\ahazan\Dropbox\ai\chat_transcripts")
EVENTS = Path.home() / ".local/state/ai-devops/reviewer-events/events.jsonl"
WORK = Path(os.environ.get("TEMP", ".")) / "jev-review-waste-work"
HEAD_RE = re.compile(r"\b[0-9a-f]{40}\b")


def sample_files(n=12, seed=7, heads: set[str] | None = None):
    random.seed(seed)
    cands = []
    for p in ARCHIVE.rglob("*.jsonl"):
        try:
            sz = p.stat().st_size
        except OSError:
            continue
        if 20_000 <= sz <= 2_000_000:
            cands.append(p)
    # Prefer files that contain an events-log head SHA (paid-review join).
    marked = []
    for p in random.sample(cands, min(120, len(cands))):
        try:
            raw = p.read_bytes()[:400_000]
        except OSError:
            continue
        text = raw.decode("utf-8", "replace")
        hit_head = bool(heads) and bool(set(HEAD_RE.findall(text)) & heads)
        hit_review = b"ai-review" in raw or b"bin/ai-review" in raw
        if hit_head or hit_review:
            marked.append((0 if hit_head else 1, p))
        if len(marked) >= n * 3:
            break
    marked.sort(key=lambda x: x[0])
    return [p for _, p in marked[:n]] or random.sample(cands, min(n, len(cands)))


def main() -> int:
    ts = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    WORK.mkdir(parents=True, exist_ok=True)
    key = resolve_key()
    by_head, head_to_run = load_events(EVENTS)
    files = sample_files(12, heads=set(by_head.keys()))
    chunk_labels = Counter()
    value_labels = Counter()
    buckets = Counter()
    abstain = 0
    usage = Counter()
    n_chunks = 0
    interactions = []

    # chunk + filter (head-join is the authoritative "sent to a reviewer" signal)
    marked_texts = []
    for fp in files:
        text = fp.read_text(encoding="utf-8", errors="replace")
        file_chunks = 0
        for start, end, chunk in chunk_text(text, 6000, 1000):
            if file_chunks >= 10:
                break
            n_chunks += 1
            file_chunks += 1
            if not has_review_signal(chunk):
                chunk_labels["no_signal_skipped"] += 1
                continue
            heads_in_chunk = set(HEAD_RE.findall(chunk)) & set(by_head.keys())
            try:
                r = ask(chunk, chunk_question(CH["instructions"], CH["criteria"]), key)
                a = r["answers"]["chunk_filter"]
                usage["in"] += int((r.get("usage") or {}).get("input_tokens") or 0)
                usage["out"] += int((r.get("usage") or {}).get("output_tokens") or 0)
                conf = a.get("confidence") or 0
                choice = a.get("choice") or "unknown"
                if conf < CH["threshold"]["min_confidence"]:
                    chunk_labels["abstain"] += 1
                    abstain += 1
                    # still allow stitch when the events spine already proves a dispatch
                    if heads_in_chunk:
                        marked_texts.append((chunk, fp.name))
                else:
                    chunk_labels[choice] += 1
                    if choice == "review_interaction" or heads_in_chunk:
                        marked_texts.append((chunk, fp.name))
            except Exception:  # noqa: BLE001
                chunk_labels["error"] += 1
            time.sleep(0.12)

    # stitch arcs by event head
    groups = defaultdict(list)
    for chunk, src in marked_texts:
        heads = set(HEAD_RE.findall(chunk)) & set(by_head.keys())
        if not heads:
            continue
        groups[sorted(heads)[0]].append(chunk)

    for head, chunks in list(groups.items())[:20]:
        arc = "\n".join(chunks)
        events = by_head[head]
        bucket = classify_bucket(arc, events)
        buckets[bucket] += 1
        provider = next((e.get("provider") for e in events if e.get("provider")), "")
        try:
            r = ask(arc, value_question(VL["instructions"], VL["criteria"]), key)
            a = r["answers"]["value_level"]
            usage["in"] += int((r.get("usage") or {}).get("input_tokens") or 0)
            usage["out"] += int((r.get("usage") or {}).get("output_tokens") or 0)
            conf = a.get("confidence") or 0
            probs = a.get("probabilities") or {}
            top = max(probs, key=probs.get) if probs else "1"
            idx = int(top) if str(top).isdigit() else 1
            label = VL["level_index"].get(str(idx), "none")
            if conf < VL["threshold"]["min_confidence"]:
                value_labels["abstain"] += 1
            else:
                value_labels[f"{bucket}:{label}"] += 1
                value_labels[label] += 1
            interactions.append({
                "head_prefix": head[:8],
                "provider": provider,
                "bucket": bucket,
                "label": label if conf >= VL["threshold"]["min_confidence"] else "abstain",
            })
        except Exception:  # noqa: BLE001
            value_labels["error"] += 1
        time.sleep(0.12)

    # Phase 5 slices (small-cell suppression n>=5)
    by_provider = Counter(i["provider"] for i in interactions if i["label"] != "abstain")
    by_bucket_label = Counter(f"{i['bucket']}:{i['label']}" for i in interactions if i["label"] != "abstain")

    report = ROOT / "tests" / "verification" / "jev" / f"review-waste-report-{ts}.md"
    lines = [
        f"# Review-waste report ({ts})",
        "",
        f"**Model pin:** `{MODEL}`  ",
        "**Host:** edge-dev (Windows)  ",
        "**Corpus:** local Dropbox transcript archive, bounded 12-file review-marked sample  ",
        "**Method:** Jev `Choice` chunk filter → event-head arc stitch → Jev `Score` value level  ",
        "**Privacy:** aggregates only; no transcript text, no private identifiers, no archive paths  ",
        "",
        "## Inventory recap (Phase 1)",
        "",
        "- Session transcripts: 9,235 files / ~13.0 GB; review-marked ~72% of files, ~11.7 GB candidates",
        "- Events spine: 13,055 rows / 2,839 unique heads / 6,662 run_ids (2026-09-07 → 2026-10-12)",
        "- Head-join rate: ~32.5% of session files contain ≥1 event head SHA (lower bound)",
        "- Frontier-read-all (review-marked): ~$2.3k–$8.8k vs Jev filter ~$34–$123 (see inventory artifact)",
        "",
        "## Calibration (Phase 3/4, synthetic fixtures)",
        "",
        "- Chunk filter holdout accuracy (decided): see chunk-shadow artifact (target 1.0 on decided)",
        "- Value Score holdout accuracy (decided): see value-shadow artifact",
        f"- Frozen thresholds: chunk conf≥{CH['threshold']['min_confidence']}, value conf≥{VL['threshold']['min_confidence']}",
        "- Negative-value rule: only when the arc shows pushback-with-evidence + withdraw, or fix later reverted; else face level (plan §8)",
        "",
        "## Bounded real-archive shadow (this run)",
        "",
        f"- Files sampled: {len(files)} (review-marked, 20KB–2MB)",
        f"- Chunks seen: {n_chunks}",
        f"- Chunk filter labels: {dict(chunk_labels)}",
        f"- Stitched interactions (capped 20): {len(interactions)}",
        f"- Buckets: {dict(buckets)}",
        f"- Value labels (face): {dict(value_labels)}",
        f"- Jev usage this run: input={usage['in']} output={usage['out']} (~${usage['in']*0.042/1e6:.4f} @ $0.042/1M)",
        "",
        "## Slices (n≥5 only)",
        "",
        "| slice | n |",
        "|---|---|",
    ]
    for k, v in sorted(by_provider.items()):
        if v >= 5:
            lines.append(f"| provider:{k} | {v} |")
    for k, v in sorted(by_bucket_label.items()):
        if v >= 5:
            lines.append(f"| {k} | {v} |")
    if not any(v >= 5 for v in list(by_provider.values()) + list(by_bucket_label.values())):
        lines.append("| (no slice reached n≥5 — suppressed) | |")

    low_value = value_labels.get("low", 0) + value_labels.get("none", 0) + value_labels.get("negative", 0)
    high_value = value_labels.get("highest", 0) + value_labels.get("medium", 0)
    lines += [
        "",
        "## Decision brief (options only — no policy change)",
        "",
        f"- In this bounded sample, low/none/negative face levels: **{low_value}**; highest/medium: **{high_value}**; abstain: **{value_labels.get('abstain', 0)}**.",
        "- Mandatory safety-gate interactions are bucketed separately and are **not** discretionary waste (plan §6.7).",
        "- Options for the owner (do not implement here): (a) date-slice a larger archive pass; (b) shrink discretionary sends that cluster in `low`/`none`; (c) keep safety-gate traffic unchanged; (d) expand holdout before any policy change.",
        "",
        "## Contested / abstain cases",
        "",
        f"- Chunk-filter abstains: {chunk_labels.get('abstain', 0)} (below threshold — not forced to a label)",
        f"- Value abstains: {value_labels.get('abstain', 0)}",
        "- Negative-value cases in the real sample: see interactions table below; if the arc does not show pushback+withdraw or later-revert, the face level is kept (not forced to negative).",
        "",
        "## Interactions (public ids only)",
        "",
        "| head_prefix | provider | bucket | label |",
        "|---|---|---|---|",
    ]
    for i in interactions:
        lines.append(f"| {i['head_prefix']} | {i['provider'] or '?'} | {i['bucket']} | {i['label']} |")

    lines += [
        "",
        "## Artifacts",
        "",
        f"- Inventory: `tests/verification/jev/review-waste-inventory-20261012T162801Z.md`",
        f"- Chunk shadow: `review-waste-chunk-shadow-20261012T180611Z.md`",
        f"- Value shadow: `review-waste-value-shadow-20261012T180611Z.md`",
        f"- This report: `{report.name}`",
        f"- Private work dir (delete or keep at owner decision): `{WORK}`",
        "",
    ]
    report.write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({
        "report": report.name,
        "chunk_labels": dict(chunk_labels),
        "value_labels": dict(value_labels),
        "interactions": len(interactions),
        "usage": dict(usage),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
