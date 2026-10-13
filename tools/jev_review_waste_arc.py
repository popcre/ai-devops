#!/usr/bin/env python3
"""Stitch review arcs: dispatch/PR head → reviewer verdict → author reaction.

One interaction is the unit that receives one value_level Score. Chunks with no
events-log join stay unscored.

Usage:
  python tools/jev_review_waste_arc.py \
      --events events.jsonl --chunks chunks.jsonl --out interactions.jsonl

Each interaction row:
  {"id", "head", "run_ids", "provider", "repo", "chunk_ids", "bucket"}
bucket is "mandatory_safety_gate" or "discretionary".
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import defaultdict
from pathlib import Path

HEAD_RE = re.compile(r"\b[0-9a-f]{40}\b")
SAFETY_MARKERS = ("reviewer-safety", "reviewer_safety", "mandatory safety", "safety-gate")


def load_events(path: Path) -> tuple[dict[str, list[dict]], dict[str, set[str]]]:
    by_head: dict[str, list[dict]] = defaultdict(list)
    head_to_run: dict[str, set[str]] = defaultdict(set)
    with path.open(encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            head = o.get("head") or ""
            if not head:
                continue
            by_head[head].append(o)
            if o.get("run_id"):
                head_to_run[head].add(o["run_id"])
    return by_head, head_to_run


def chunk_heads(chunk_text: str) -> set[str]:
    return set(HEAD_RE.findall(chunk_text))


def classify_bucket(text: str, events: list[dict]) -> str:
    blob = " ".join(
        str(e.get(k, "")) for e in events for k in ("caller", "operation", "repo")
    ).lower()
    hay = (text[:2000] + " " + blob).lower()
    if any(m in hay for m in SAFETY_MARKERS):
        return "mandatory_safety_gate"
    return "discretionary"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--events", required=True)
    ap.add_argument("--chunks", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    by_head, head_to_run = load_events(Path(args.events))
    # group chunks by any event head they contain
    groups: dict[str, list[dict]] = defaultdict(list)
    unscored = 0
    total = 0
    with Path(args.chunks).open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            meta = json.loads(line)
            total += 1
            text = ""
            tp = meta.get("text_path")
            if tp and Path(tp).is_file():
                text = Path(tp).read_text(encoding="utf-8", errors="replace")
            heads = chunk_heads(text)
            hit = heads & set(by_head.keys())
            if not hit:
                unscored += 1
                continue
            # attach to the first matching head (stable by sorted head)
            head = sorted(hit)[0]
            groups[head].append({**meta, "text": text})

    out_path = Path(args.out)
    n = 0
    with out_path.open("w", encoding="utf-8") as out:
        for head in sorted(groups.keys()):
            chunks = groups[head]
            # one interaction per head: concatenate adjacent chunk texts for the arc
            texts = "\n".join(c["text"] for c in chunks)
            events = by_head[head]
            bucket = classify_bucket(texts, events)
            providers = sorted({e.get("provider") for e in events if e.get("provider")})
            repos = sorted({e.get("repo") for e in events if e.get("repo")})
            iid = hashlib.sha256(f"{head}|{len(chunks)}".encode()).hexdigest()[:16]
            out.write(
                json.dumps(
                    {
                        "id": iid,
                        "head": head,
                        "run_ids": sorted(head_to_run.get(head, [])),
                        "provider": providers[0] if providers else "",
                        "providers": providers,
                        "repo": repos[0] if repos else "",
                        "chunk_ids": [c["id"] for c in chunks],
                        "bucket": bucket,
                        "chunk_count": len(chunks),
                    },
                    ensure_ascii=False,
                )
                + "\n"
            )
            n += 1
    print(
        json.dumps(
            {
                "chunks_total": total,
                "chunks_unscored_no_event": unscored,
                "interactions": n,
            }
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
