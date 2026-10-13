#!/usr/bin/env python3
"""Re-score value labels from saved arcs (resume after rate-limit/size failures)."""
from __future__ import annotations

import json
import os
import sys
import time
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from jev_review_waste_http import MODEL, resolve_key, value_question, ask  # noqa: E402

CFG = json.loads((ROOT / "config" / "jev-decisions.json").read_text(encoding="utf-8"))
VL = CFG["decisions"]["value_level"]
WORK = Path(os.environ.get("TEMP", ".")) / "jev-full-sweep-work"
CONCURRENCY = int(os.environ.get("JEV_SWEEP_CONCURRENCY", "5"))


def score_arc(key, arc):
    if len(arc) > 80000:
        arc = arc[:80000]
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
            time.sleep(0.5 * (attempt + 1))
    return {"label": "error", "conf": None, "usage": {}, "error": last}


def main() -> int:
    arcs_path = WORK / "arcs.jsonl"
    if not arcs_path.is_file():
        print("no arcs.jsonl", file=sys.stderr)
        return 2
    rows = [json.loads(x) for x in arcs_path.read_text(encoding="utf-8").splitlines() if x]
    print(f"arcs={len(rows)} concurrency={CONCURRENCY}", flush=True)
    key = resolve_key()
    out = []
    usage = Counter()
    labels = Counter()
    buckets = Counter()
    results = [None] * len(rows)
    with ThreadPoolExecutor(max_workers=CONCURRENCY) as ex:
        futs = {ex.submit(score_arc, key, rows[i]["arc"]): i for i in range(len(rows))}
        done = 0
        for fut in as_completed(futs):
            i = futs[fut]
            results[i] = fut.result()
            done += 1
            if done % 100 == 0:
                print(f"  scored {done}/{len(rows)}", flush=True)
    for row, res in zip(rows, results):
        buckets[row["bucket"]] += 1
        labels[res["label"]] += 1
        labels[f"{row['bucket']}:{res['label']}"] += 1
        usage["in"] += int((res.get("usage") or {}).get("input_tokens") or 0)
        usage["out"] += int((res.get("usage") or {}).get("output_tokens") or 0)
        out.append({
            "head_prefix": row["head"][:8],
            "provider": row.get("provider") or "?",
            "bucket": row["bucket"],
            "label": res["label"],
        })
    summary = {
        "n": len(rows),
        "labels": dict(labels),
        "buckets": dict(buckets),
        "usage": dict(usage),
        "cost_usd": round(usage["in"] * 0.042 / 1e6, 2),
    }
    (WORK / "value-summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    (WORK / "value-rows.json").write_text(json.dumps(out), encoding="utf-8")
    print(json.dumps(summary, indent=2), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
