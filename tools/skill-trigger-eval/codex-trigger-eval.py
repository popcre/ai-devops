#!/usr/bin/env python3
"""Measure whether a Codex skill actually triggers on realistic prompts.

The sibling `skill-trigger-eval.py` is Claude-specific: it watches for Claude
Code's `Skill` tool call in a `stream-json` transcript. Codex has no equivalent
tool event, so it needs its own runner rather than a shared one.

How a trigger is detected here, and why it is a weaker signal than Claude's:
Codex reaches a skill by READING its installed `SKILL.md`. So a run counts as a
trigger when the JSON event stream shows the installed skill path or the skill
directory name. That is evidence the skill was selected, not proof the model
followed it. Read a score as "did Codex go and look at the right skill", never
as "did Codex obey the skill".

Two hard rules this runner enforces and must keep enforcing:

  1. **Reasoning effort is always explicitly `low` or `medium`.** Albert's
     standing rule. An unset effort has been observed to start a Codex run at
     `none`, which the rule forbids exactly as much as `high`. The value is
     passed on every invocation and `--effort` refuses anything else.
  2. **The sandbox is read-only.** A trigger eval must never let a model write.
     `--sandbox read-only` is passed explicitly; a mistyped `-c` key silently
     falls back to the config default, so the flag form is used.

Usage:
    python codex-trigger-eval.py --skill codex-session-docs-update \
        --eval-set codex-session-docs-update.eval.json

    python codex-trigger-eval.py --skill any-skill --eval-set set.json \
        --print-command      # prints the exact argv and exits; calls no model

Eval set format is identical to the Claude runner, so one set can feed both:
    [{"query": "...", "should_trigger": true}, ...]
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import json
import os
import subprocess
import sys
from pathlib import Path

ALLOWED_EFFORTS = ("low", "medium")


def build_command(query: str, effort: str) -> list[str]:
    """Return the exact argv for one Codex eval run.

    Split out so a dry run and the offline regression test can assert the
    reasoning effort and the read-only sandbox without calling a model.
    """
    if effort not in ALLOWED_EFFORTS:
        raise ValueError(
            f"reasoning effort {effort!r} is not allowed; use one of {ALLOWED_EFFORTS}. "
            "Albert's standing rule caps GPT-5.6 at low or medium, and an unset "
            "effort can start a run at none."
        )
    return [
        "codex", "exec",
        "-c", f"model_reasoning_effort={effort}",
        "--sandbox", "read-only",
        "--json",
        query,
    ]


def run_query(query: str, skill: str, installed: Path, project: Path,
              effort: str, timeout: int) -> bool | None:
    """Return True if the skill was opened, False if not, None if the run failed."""
    env = {k: v for k, v in os.environ.items() if k != "CODEX_SANDBOX"}
    try:
        proc = subprocess.run(
            build_command(query, effort),
            cwd=str(project), env=env,
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            timeout=timeout,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None

    text = proc.stdout.decode("utf-8", errors="replace")
    needles = (str(installed), installed.as_posix(), f"skills/{skill}", f"skills\\{skill}")
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        if any(needle in line for needle in needles):
            return True
    return False


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--skill", required=True, help="Installed skill directory name")
    ap.add_argument("--eval-set", required=True, type=Path)
    ap.add_argument("--project", type=Path, default=None)
    ap.add_argument("--codex-home", type=Path, default=Path.home() / ".codex")
    ap.add_argument("--effort", default="low", choices=list(ALLOWED_EFFORTS),
                    help="GPT-5.6 reasoning effort. Only low or medium are allowed.")
    ap.add_argument("--runs", type=int, default=1)
    ap.add_argument("--workers", type=int, default=2)
    ap.add_argument("--timeout", type=int, default=240)
    ap.add_argument("--print-command", action="store_true",
                    help="print the exact argv for one run and exit without calling a model")
    args = ap.parse_args()

    if args.print_command:
        print(json.dumps(build_command("<query>", args.effort)))
        return 0

    installed = args.codex_home / "skills" / args.skill / "SKILL.md"
    if not installed.is_file():
        print(f"ERROR: {args.skill} is not installed at {installed}\n"
              f"This runner tests the REAL installed skill. Run the installer for this "
              f"platform first (bin/install-ai-devops-windows.ps1 on native Windows, "
              f"bin/ai-install-skills on Ubuntu or Git Bash).", file=sys.stderr)
        return 2

    evals = json.loads(args.eval_set.read_text(encoding="utf-8"))
    project = args.project or Path.cwd()

    jobs = [(item, r) for item in evals for r in range(args.runs)]
    with cf.ThreadPoolExecutor(max_workers=args.workers) as ex:
        futures = {
            ex.submit(run_query, item["query"], args.skill, installed, project,
                      args.effort, args.timeout): item
            for item, _ in jobs
        }
        fired: dict[str, list[bool | None]] = {}
        for fut in cf.as_completed(futures):
            item = futures[fut]
            fired.setdefault(item["query"], []).append(fut.result())

    results = []
    for item in evals:
        outcomes = fired.get(item["query"], [])
        ok = [o for o in outcomes if o is not None]
        results.append({
            **item,
            "trigger_rate": (sum(ok) / len(ok)) if ok else 0.0,
            "runs": len(ok),
            "errors": len(outcomes) - len(ok),
        })

    pos = [r for r in results if r["should_trigger"]]
    neg = [r for r in results if not r["should_trigger"]]
    tp = sum(1 for r in pos if r["trigger_rate"] > 0.5)
    fp = sum(1 for r in neg if r["trigger_rate"] > 0.5)
    total_err = sum(r["errors"] for r in results)

    for r in results:
        got = r["trigger_rate"] > 0.5
        flag = "PASS" if got == r["should_trigger"] else "FAIL"
        print(f"  [{flag}] rate={r['trigger_rate']:.2f} want={str(r['should_trigger']):5} {r['query'][:66]}")

    print(f"\nShould-trigger opened the skill:     {tp}/{len(pos)}   (higher is better)")
    print(f"Should-NOT-trigger opened the skill: {fp}/{len(neg)}   (lower is better)")
    print(f"Reasoning effort used: {args.effort} (low or medium only, by standing rule)")
    if total_err:
        print(f"WARNING: {total_err} run(s) errored or timed out and were excluded — "
              f"treat these numbers as incomplete.")

    out = args.eval_set.with_suffix(".codex-results.json")
    out.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(f"\nPer-query results: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
