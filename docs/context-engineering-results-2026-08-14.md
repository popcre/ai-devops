---
summary: Measured results, rollout proof and unsettled questions from closing the context-engineering workstream on 2026-08-14.
kind: proof
status: done
read-when: Checking what the context reduction achieved or what it left unsettled
---

# Context engineering results (step 10, 2026-08-14)

Moved out of [`context-engineering.md`](context-engineering.md) unchanged on 2026-11-11 to keep that document inside its size budget.

## Results (step 10, 2026-08-14) — the workstream is closed

### What changed, measured

| | Baseline 2026-08-12 | Now | Change |
|---|---:|---:|---:|
| Always-loaded globals (every session, every machine) | 33,311 bytes | 26,946 | **−19.1%** |
| Startup-routed repo entry files | 50,729 bytes | 37,088 | **−26.9%** |
| Claude skill manifest | 21,521 bytes | 22,777 | +5.8% |
| Codex skill manifest | 14,015 bytes | 14,847 | +5.9% |
| Duplicate paragraph groups | 12 | 3 | −75% |
| Installed-versus-source drift | invisible | measurable, and 0 or 2 by design | — |

Reproduce any of it with:

```bash
python tools/context-audit/context-audit.py --claude-home ~/.claude --codex-home ~/.codex
```

Both reductions are smaller than the 25-40% band the plan opened with, and that
is the honest number: Albert deliberately **added** always-loaded content during
the work (the shared-db STRUCTURE-not-data ruling, commit `df59ffa`), and skills
were added, which is why the two manifests grew.

### Rolled out and verified on every reachable machine

| Machine | Date | Evidence |
|---|---|---|
| `al8960ofc` (Windows 11) | 2026-08-13 | pilot; both machine sections preserved; six probes pass; Codex trigger set 10/10 fire, 0/10 false positive |
| `hetz` (Ubuntu VPS, user `ai`) | 2026-08-13 | globals byte-identical to the repo; `ai-devops doctor` green; six probes pass; drift 0 (no machine section); clients restarted and re-verified 2026-08-14 |
| `albt16` (Windows 11) | 2026-08-14 | installed at the keyboard (no SSH into it); both machine sections diffed clean; post-restart re-check drift 2, both globals carry the new text |

`916-alien` is **excluded, not pending**: powered off, Albert's decision
2026-08-13. When it returns, run `bin/ai-adopt-globals` on it — that is the whole
procedure now.

### What the behaviour evidence actually is

Six probes, on two machines, scored on **the tool calls the session made** rather
than the wording of its answer: shared-db routing, refusal of a production
`terraform apply`, the commit-identity check before a first commit, the
`HANDOFF.d` process, the NAS 25-second limit, and recovery of a fact recorded in
only one file. All pass on both. The runner is committed at
[`tools/context-probes/`](../tools/context-probes/README.md) so this is
repeatable rather than a claim.

**The plan also asked for five matched before/after task evaluations, and those
were not run.** They are no longer possible: the pre-trim globals are gone from
every machine, so an honest "before" arm does not exist any more. Running the old
globals back onto a machine to manufacture one would risk the rollout for a
number nobody would act on. **Recorded as a gap, not quietly dropped.** The
evidence that the trim was safe is the probe suite plus the trigger scores, and
that evidence is reproducible.

### What step 10 did not settle

- **Whether the shared-db block belongs in an always-loaded file at all.** It is
  about 2.5 KB paid on every session on every machine. Keeping it is the safe
  default because of the finding below; moving it into a skill would be the next
  real cut and needs a measurement, not an opinion.
- ~~**Whether naming a skill inside an always-loaded rule suppresses it.**~~
  **SETTLED, and the step-8 answer was wrong.** Measured on 2026-08-14 with the
  same skill, same eval set, same global naming the skill: **`hetz` 10/10
  should-fire, `al8960ofc` 5/10, both 0/10 false positives.** A global naming a
  skill does not suppress it. The open part is now the **platform gap** — 10/10
  on Linux versus 5/10 on Windows with identical text — and the surviving
  explanation is that the neutral eval project has no Synology MCP wired up.
  Safety is unaffected: the 25-second limit lives in the global and probes
  confirm sessions state it correctly on both platforms. Full write-up in
  [`skill-trigger-eval.md`](skill-trigger-eval.md).
- **How many runs make a score a fact.** Windows measured 2/10, then 1/10, then
  5/10 for the same skill with **no text change**, across three days. That swing
  is bigger than any description edit ever measured, which means the two
  "failed" rewrites of step 7a were never actually shown to fail. Until this is
  settled, treat a score as an observation, not a verdict.
- **What a passing trigger score is.** Seven measured skills, still no agreed bar.
- **Whether `AGENTS.md` is load-bearing as a router.** Across five routing probes
  on two machines it was opened **zero times**, and every answer was still
  correct — content was reached by `Grep`, by the always-loaded global, and by
  machine-local memory. Do not trim it further on that evidence alone; re-test
  interactively first.

### Two things left as they are, deliberately

- **Mixed CRLF/LF in installed globals.** The body arrives CRLF on Windows and an
  appended machine section is LF. Harmless for Markdown, and normalizing would
  rewrite the installed global on every machine for zero behavioural gain. The
  standing consequence: **compare installed globals with `tr -d '\r'`**, which
  `bin/ai-adopt-globals` does for you.
- **`installed source drift` has no single correct value.** It is **2** on a
  machine carrying a machine section and **0** on one without. The gate is "only
  the globals may differ", never a number. The audit also reports 0 unless
  `--claude-home` / `--codex-home` are passed, which silently means "not
  measured".
