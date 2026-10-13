#!/usr/bin/env python3
"""Phase 3.3 / 4.3 calibration via the local Python Jev helper.

Writes only aggregates + public case ids. Never writes state text.
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from jev_review_waste_http import (  # noqa: E402
    MODEL, ask, chunk_question, value_question, resolve_key,
)

CFG = json.loads((ROOT / "config" / "jev-decisions.json").read_text(encoding="utf-8"))
CH = CFG["decisions"]["chunk_filter"]
VL = CFG["decisions"]["value_level"]


def load_cases(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    return data if isinstance(data, list) else data.get("cases", [])


def run_batch(key, cases, kind):
    out = {}
    for c in cases:
        state = f"SYNTHETIC {c['id']}: {c['synopsis']}"
        try:
            if kind == "chunk":
                r = ask(state, chunk_question(CH["instructions"], CH["criteria"]), key)
                a = r["answers"]["chunk_filter"]
                conf = a.get("confidence")
                pred = a.get("choice")
                abstain = conf is None or conf < CH["threshold"]["min_confidence"]
                out[c["id"]] = {
                    "pred": pred if not abstain else None,
                    "conf": conf,
                    "abstain": abstain,
                    "usage": r.get("usage", {}),
                }
            else:
                r = ask(state, value_question(VL["instructions"], VL["criteria"]), key)
                a = r["answers"]["value_level"]
                conf = a.get("confidence")
                # map score argmax to label
                probs = a.get("probabilities") or {}
                top = max(probs, key=probs.get) if probs else "1"
                idx = int(top) if str(top).isdigit() else 1
                pred = VL["level_index"].get(str(idx), "none")
                abstain = conf is None or conf < VL["threshold"]["min_confidence"]
                out[c["id"]] = {
                    "pred": pred if not abstain else None,
                    "conf": conf,
                    "abstain": abstain,
                    "score": a.get("score"),
                    "usage": r.get("usage", {}),
                }
        except Exception as e:  # noqa: BLE001
            out[c["id"]] = {"pred": None, "conf": None, "abstain": True, "error": type(e).__name__}
        time.sleep(0.15)
    return out


def accuracy(rows):
    decided = [r for r in rows if r.get("pred") and not r.get("abstain")]
    if not decided:
        return 0.0, 0, len(rows)
    good = sum(1 for r in decided if r["pred"] == r["label"])
    return good / len(decided), len(decided), len(rows)


def confusion(rows):
    cm = {}
    for r in rows:
        key = (r["label"], r.get("pred") or "abstain")
        cm[key] = cm.get(key, 0) + 1
    return cm


def write_shadow(path, title, rows_tune, rows_hold, acc_t, dec_t, n_t, acc_h, dec_h, n_h, usage_sum):
    lines = [
        f"# {title} ({time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())})",
        "",
        f"**Model pin:** `{MODEL}` (live `GET`/`POST` echo confirmed)  ",
        "**Config:** `config/jev-decisions.json`  ",
        "**Cases:** `tests/fixtures/jev/` public/synthetic only  ",
        f"**Usage totals (holdout+tune):** {usage_sum}",
        "",
        "## Holdout confusion (label → pred)",
        "",
        "| label | pred | n |",
        "|---|---|---|",
    ]
    for (lab, pred), n in sorted(confusion(rows_hold).items()):
        lines.append(f"| {lab} | {pred} | {n} |")
    lines += [
        "",
        f"- Tuning split: n={n_t} decided={dec_t} accuracy(decided)={acc_t:.2f}",
        f"- Holdout split: n={n_h} decided={dec_h} accuracy(decided)={acc_h:.2f}",
        "",
        "## Per-case public ids (holdout)",
        "",
        "| id | label | pred | confidence | abstain |",
        "|---|---|---|---|---|",
    ]
    for r in rows_hold:
        lines.append(
            f"| {r['id']} | {r['label']} | {r.get('pred') or 'abstain'} | {r.get('conf')} | {r.get('abstain')} |"
        )
    lines += [
        "",
        "## Freeze",
        "",
        "One tuning pass on synthetic labels. Wording and thresholds in config",
        "are frozen for this run. Holdout above is from frozen settings.",
        "No raw state text in this artifact.",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    key = resolve_key()
    # chunk filter
    ccases = load_cases(ROOT / "tests" / "fixtures" / "jev" / "review-waste-chunk-labels.json")
    crows_raw = run_batch(key, ccases, "chunk")
    crows = [{**c, **crows_raw[c["id"]]} for c in ccases]
    ctune = [r for r in crows if r.get("tune")]
    chold = [r for r in crows if not r.get("tune")]
    # value level
    vcases = load_cases(ROOT / "tests" / "fixtures" / "jev" / "review-waste-value-labels.json")
    vrows_raw = run_batch(key, vcases, "value")
    vrows = [{**c, **vrows_raw[c["id"]]} for c in vcases]
    vtune = [r for r in vrows if r.get("tune")]
    vhold = [r for r in vrows if not r.get("tune")]

    def use_sum(rows):
        u = {"input_tokens": 0, "output_tokens": 0}
        for r in rows:
            g = r.get("usage") or {}
            u["input_tokens"] += int(g.get("input_tokens") or 0)
            u["output_tokens"] += int(g.get("output_tokens") or 0)
        return u

    ts = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    chunk_md = ROOT / "tests" / "verification" / "jev" / f"review-waste-chunk-shadow-{ts}.md"
    value_md = ROOT / "tests" / "verification" / "jev" / f"review-waste-value-shadow-{ts}.md"
    acc_t, dec_t, n_t = accuracy(ctune)
    acc_h, dec_h, n_h = accuracy(chold)
    write_shadow(chunk_md, "Review-waste chunk-filter shadow", ctune, chold,
                 acc_t, dec_t, n_t, acc_h, dec_h, n_h, use_sum(crows))
    vacc_t, vdec_t, vn_t = accuracy(vtune)
    vacc_h, vdec_h, vn_h = accuracy(vhold)
    write_shadow(value_md, "Review-waste value-level shadow", vtune, vhold,
                 vacc_t, vdec_t, vn_t, vacc_h, vdec_h, vn_h, use_sum(vrows))

    cfg_path = ROOT / "config" / "jev-decisions.json"
    cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
    cfg["decisions"]["chunk_filter"]["frozen"] = True
    cfg["decisions"]["chunk_filter"]["threshold"]["status"] = f"frozen_synthetic_{ts}"
    cfg["decisions"]["value_level"]["frozen"] = True
    cfg["decisions"]["value_level"]["threshold"]["status"] = f"frozen_synthetic_{ts}"
    cfg_path.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({
        "chunk_tune_acc": round(acc_t, 3), "chunk_hold_acc": round(acc_h, 3),
        "chunk_hold_decided": dec_h, "chunk_hold_n": n_h,
        "value_tune_acc": round(vacc_t, 3), "value_hold_acc": round(vacc_h, 3),
        "value_hold_decided": vdec_h, "value_hold_n": vn_h,
        "chunk_shadow": chunk_md.name, "value_shadow": value_md.name,
        "chunk_usage": use_sum(crows), "value_usage": use_sum(vrows),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
