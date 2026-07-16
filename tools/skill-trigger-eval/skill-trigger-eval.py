#!/usr/bin/env python3
"""Measure whether a Claude Code skill actually triggers on realistic prompts.

Answers one question: given a query a real user would type, does Claude invoke
the skill? It runs each query through `claude -p` against the skill as actually
installed in ~/.claude/skills, and counts a trigger when the model calls the
Skill tool with that name.

Why this exists rather than skill-creator's bundled scripts/run_loop.py — that
harness scored every query 0 on this machine, for two independent reasons:

  1. It called select.select() on a subprocess pipe. On Windows select() accepts
     only sockets, so every query died with WinError 10038 while the run still
     reported exit 0 — a silent failure that "optimises" a description against
     pure noise. (Fix, if you ever revive it: replace the select()/os.read()
     loop with a reader thread pushing stream.read1() chunks onto a Queue.)
  2. More fundamentally, it fabricates a file in .claude/commands/ and assumes
     that makes the skill model-invocable. It does not: commands surface as
     user-typed slash_commands, while the model invokes skills from
     .claude/skills/ via the Skill tool. Verified 2026-07-16 — a fabricated
     command never fired once in 40 attempts, while the real installed skill
     fired normally in the same environment.

So this runner tests the real mechanism instead of a simulation of it.

Usage:
    python skill-trigger-eval.py --skill secrets-to-1password \
        --eval-set trigger-eval.json

Eval set format — realistic prompts, including near-misses that must NOT fire:
    [{"query": "...", "should_trigger": true}, ...]

Reading the output: a should-trigger query only counts as a real miss if the
model *could* have acted. If the prompt asks to store a secret but never
includes the value, Claude asks for the value first — correct behaviour, not a
triggering failure. Keep those out of the eval set or you will chase a phantom.
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import json
import os
import subprocess
import sys
from pathlib import Path


def run_query(query: str, skill: str, project: Path, timeout: int) -> bool | None:
    """Return True if the skill fired, False if not, None if the run failed."""
    # CLAUDECODE is a guard against interactive nesting; a programmatic
    # subprocess is safe, and leaving it set makes `claude -p` refuse to run.
    env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
    cmd = [
        "claude", "-p", query,
        "--output-format", "stream-json",
        "--verbose",
        "--include-partial-messages",
    ]
    try:
        proc = subprocess.run(
            cmd,
            cwd=str(project),
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=timeout,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None

    for line in proc.stdout.decode("utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        # Completed assistant message.
        if event.get("type") == "assistant":
            for block in event.get("message", {}).get("content", []):
                if block.get("type") == "tool_use" and block.get("name") == "Skill":
                    if skill in str(block.get("input", {}).get("skill", "")):
                        return True

        # Streaming tool-input deltas catch the call before the tool executes,
        # which keeps runs short for skills that would do real work.
        if event.get("type") == "stream_event":
            se = event.get("event", {})
            if se.get("type") == "content_block_delta":
                delta = se.get("delta", {})
                if delta.get("type") == "input_json_delta":
                    if skill in delta.get("partial_json", ""):
                        return True
    return False


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--skill", required=True, help="Installed skill name, e.g. secrets-to-1password")
    ap.add_argument("--eval-set", required=True, type=Path)
    ap.add_argument("--project", type=Path, default=None,
                    help="Directory to run claude -p in (default: a temp-free cwd)")
    ap.add_argument("--runs", type=int, default=1, help="Runs per query (>1 gives a trigger rate)")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--timeout", type=int, default=240)
    args = ap.parse_args()

    installed = Path.home() / ".claude" / "skills" / args.skill / "SKILL.md"
    if not installed.is_file():
        print(f"ERROR: {args.skill} is not installed at {installed}\n"
              f"This runner tests the REAL installed skill. Run bin/ai-install-skills first.",
              file=sys.stderr)
        return 2

    evals = json.loads(args.eval_set.read_text(encoding="utf-8"))
    project = args.project or Path.cwd()

    jobs = [(item, r) for item in evals for r in range(args.runs)]
    with cf.ThreadPoolExecutor(max_workers=args.workers) as ex:
        futures = {
            ex.submit(run_query, item["query"], args.skill, project, args.timeout): (item, r)
            for item, r in jobs
        }
        fired: dict[str, list[bool | None]] = {}
        for fut in cf.as_completed(futures):
            item, _ = futures[fut]
            fired.setdefault(item["query"], []).append(fut.result())

    results = []
    for item in evals:
        outcomes = fired.get(item["query"], [])
        ok = [o for o in outcomes if o is not None]
        errors = len(outcomes) - len(ok)
        rate = (sum(ok) / len(ok)) if ok else 0.0
        results.append({**item, "trigger_rate": rate, "runs": len(ok), "errors": errors})

    pos = [r for r in results if r["should_trigger"]]
    neg = [r for r in results if not r["should_trigger"]]
    # Majority of runs decides; with --runs 1 this is just "did it fire".
    tp = sum(1 for r in pos if r["trigger_rate"] > 0.5)
    fp = sum(1 for r in neg if r["trigger_rate"] > 0.5)
    total_err = sum(r["errors"] for r in results)

    for r in results:
        want = r["should_trigger"]
        got = r["trigger_rate"] > 0.5
        flag = "PASS" if got == want else "FAIL"
        print(f"  [{flag}] rate={r['trigger_rate']:.2f} want={str(want):5} {r['query'][:66]}")

    print(f"\nShould-trigger fired:     {tp}/{len(pos)}   (higher is better)")
    print(f"Should-NOT-trigger fired: {fp}/{len(neg)}   (lower is better)")
    if total_err:
        print(f"WARNING: {total_err} run(s) errored or timed out and were excluded — "
              f"treat these numbers as incomplete.")

    out = args.eval_set.with_suffix(".results.json")
    out.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(f"\nPer-query results: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
