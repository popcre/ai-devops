#!/usr/bin/env python3
"""Extract arcs for known event heads (from head-hits.json) then value-score."""
from __future__ import annotations

import json
import os
import re
import sys
import time
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from jev_review_waste_arc import load_events, classify_bucket  # noqa: E402

ARCHIVE = Path(r"C:\Users\ahazan\Dropbox\ai\chat_transcripts")
EVENTS = Path.home() / ".local/state/ai-devops/reviewer-events/events.jsonl"
WORK = Path(os.environ.get("TEMP", ".")) / "jev-full-sweep-work"
MAX_ARC = 80000


def main() -> int:
    t0 = time.time()
    head_hits = json.loads((WORK / "head-hits.json").read_text(encoding="utf-8"))
    by_head, _ = load_events(EVENTS)
    heads = set(head_hits) & set(by_head)
    print(f"heads_to_extract={len(heads)}", flush=True)

    arcs = {}
    files = []
    for p in ARCHIVE.rglob("*.jsonl"):
        try:
            if p.stat().st_size >= 2000:
                files.append(p)
        except OSError:
            pass
    for fi, p in enumerate(files, 1):
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for m in re.finditer(r"\b[0-9a-f]{40}\b", text):
            h = m.group(0)
            if h not in heads:
                continue
            start = max(0, m.start() - 2500)
            end = min(len(text), m.end() + 2500)
            snippet = text[start:end]
            prev = arcs.get(h, "")
            if len(prev) < MAX_ARC:
                arcs[h] = (prev + "\n" + snippet)[:MAX_ARC]
        if fi % 1500 == 0:
            print(f"  extract {fi}/{len(files)} arcs={len(arcs)} elapsed={time.time()-t0:.0f}s", flush=True)

    print(f"extract done arcs={len(arcs)}", flush=True)
    out = WORK / "arcs.jsonl"
    with out.open("w", encoding="utf-8") as f:
        for head, arc in arcs.items():
            events = by_head[head]
            bucket = classify_bucket(arc, events)
            provider = next((e.get("provider") for e in events if e.get("provider")), "")
            f.write(json.dumps({"head": head, "bucket": bucket, "provider": provider, "arc": arc}) + "\n")
    print(f"wrote {out}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
