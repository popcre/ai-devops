# Maintenance — orphan-sweep cleanup of pre-fix review sandboxes

Machine: edge-dev · Agent: MiMo · Written: 2026-10-07 7:35 AM EDT (America/New_York)
GitHub signature: `Posted by MiMo chat unknown on edge-dev`

Residual of incident `20261006T123753Z-edge-dev-codex-950377` (resolved) and
`HANDOFF.d/2026-10-06T2027Z-edge-dev-mimo-reviewer-durable-publish-and-incidents.md` §6.
The incident's retest-success-evidence.txt left this backlog explicitly:
pre-fix orphaned sandboxes still failed orphan-sweep reconciliation and hit the
16-orphan examination cap. This note closes that residual.

## Outcome

**SWEPT-HEALTHY.** No tooling code changed. The landed PR #1323 guard
(`tools/reviewer_event_guard.sh` open-run inherit / `sandbox_source_chain`) was
**not** touched.

## Before / after

| | before (11:05 UTC) | after (11:35 UTC) |
|---|---|---|
| marked sandboxes in root | 62 | 3 (all <2h, live) |
| verify-sandbox OK | 21 | all remaining pass or are young |
| verify-sandbox FAIL | 41 | 0 stuck |
| `16 orphan examination cap` | hit every front-door pass | **absent** on two consecutive sweeps |

Decisive after lines (`after-sweep-output.txt`):

```
sweep-pass2 stderr:   (empty)
sweep-pass3 stderr:   (empty)
examination-cap lines in pass2/pass3: 0 / 0
  0h  codex-diff-review-20261007T111549-3385216-5817-96ae9a73b6e9
  0h  codex-final-check-20261007T110630-3294625-4882-7cec4f3f0d01
  0h  rlc-gemini-8b3fb4d81c91-96ae9a73b6e9
```

## What was done

1. **Read-only inventory** (`before-verify-inventory.txt`): every marked sandbox
   classified by `tools/reviewer_events.py verify-sandbox` outcome and, for each
   `evidence_owner=provider:run_id`, by its `events.jsonl` rows.
2. **Reconciled (proper path) then swept — 6 finished GLM runs**
   (`glm-rev3947risk3c/e/g`, `glm-rev3957s1glm2`, `glm-rev3957s4g` sibling
   `glm-testglm-quick`) via
   `bin/ai-reviewer-issue evidence reconcile-lost glm <sandbox> "<reason>"`.
   Each recorded `evidence-lost.json` under
   `~/.local/state/ai-devops/reviewer-events/evidence/<run_id>/`, then
   `verify-sandbox` returned 0 and `sweep-orphans` deleted the snapshot
   (`sweep-pass1.err`: `deleted review snapshot ...`).
   (5 of the 6 were deleted in pass 1; `glm-rev3957s4g` was removed by a
   concurrent front-door sweep after this session's `evidence-lost` record was
   in place.)
3. **Swept without intervention — reconciled OK sandboxes** older than the 2h
   orphan age (codex/muse/grok/qwen/preflight snapshots whose evidence was
   already `verified`). The front-door sweep running in parallel removed most of
   these during the session; pass 1 removed the rest.
4. **Quarantined (not deleted) — 41 stuck sandboxes + 204 sidecars**
   to `~/.local/state/ai-devops/review-sandboxes-quarantine-20261007/`
   with `README.txt` classifying every entry (A test debris, B ordinary failed
   reviews, C vanished code-only sources, D unsealed packets, E sidecar leaks).
   This directory **is** the backup; nothing was deleted.
5. **Re-ran `sweep-orphans` twice** — both exits 0, empty stderr, no cap line.

## Classification evidence (why none of this is a NEW guard defect)

The 15 real runs that failed `verify-sandbox` with
`required report is not durably published` all started **after** `b1bd3ad8`
(2026-10-07T00:19:06Z). Checked each one:

- none has a `*.report.json` under its `evidence/<run_id>/` (only `required.json`);
- none shows the nested-second-invocation signature the PR #1323 fix addresses
  (`parent_run_id` is null on all but one pool child, and that parent also failed
  with exit 3 — not a successful review that failed to publish);
- on-disk `.ai/reviews` for the shared-db worktree has reports only for the runs
  that **succeeded** (e.g. `grok-rev3947risk-grok1-*.md`, and the OK-listed
  qwen/gemini/muse snapshots).

So these are ordinary failed/killed reviews leaving unreconciled sandboxes —
the pre-existing fail-closed behaviour working as designed — not a regression of
the landed inherit/chain guard.

## Named residual (tooling gap, NOT fixed in this pass)

`tools/reviewer_events.py` cannot retire two legitimate pre-fix shapes:

1. **Loss already recorded, no ledger row.** `verify_reports` calls
   `invocation()` (`reviewer_events.py:240`) which demands a unique `started`
   row. The 2026-10-07T00:34:24Z local-recovery batch wrote
   `required.json` + `evidence-lost.json` (caller=`local-recovery`, head=0) for
   ~85 test-fixture run_ids that never entered `events.jsonl`. `verify-sandbox`
   still returns `evidence has no unique matching invocation` even though the
   loss is already on disk. Quarantined here as class A.
2. **`reconcile-lost` scope.** `LOST_REPORT_PROVIDERS = {"glm"}` (`reviewer_events.py:940`)
   — gemini/grok/qwen cannot record a provable loss. And `record_lost`
   (`reviewer_events.py:962`) refuses any invocation without a `finished` row
   ("reviewer invocation is still active"), so a wrapper that was killed mid-run
   can never record loss. Quarantined here as class B.

A future PR could let `verify_sandbox` accept an existing `evidence-lost.json`
whose identity matches `required.json` even with no ledger row (this does **not**
weaken the gate for new runs: `record_lost` still requires a ledger row), and
could widen `LOST_REPORT_PROVIDERS` / allow loss after a proven-dead owner.
That change is evidence-tool code = **reviewer-safety class** and needs an
independent exact-head review via a registered provider before merge. Not done
here on purpose: quarantine already restores sweep health, and the task forbids
weakening fail-closed gates for new runs to make old garbage disappear.

Also unaddressed (separate, small): `ai-review-packet retain` requires
`MANIFEST.sha256` + `identity.json`; six old packets were never sealed
(class D). Sealing them would mean completing an interrupted packet
finalization — left for whoever owns the packet tool.

## One process correction recorded honestly

During the first quarantine pass, one **live** sandbox
(`codex-diff-review-20261007T111549-3385216-5817-96ae9a73b6e9`, marker age ~2
minutes, an in-flight codex diff-review on `coldlion-cron-3853`) was moved to
quarantine because the script keyed only on `verify-sandbox` failure (which is
also true for a live run that has not published yet). It was **restored to the
sandbox root within a minute** of detection. The follow-up pass added an explicit
2h age gate and skipped every young sandbox. No live review was lost or
interrupted by this cleanup.

## Backups / recovery

- Quarantine (the backup): `~/.local/state/ai-devops/review-sandboxes-quarantine-20261007/`
  — 41 directories + 204 sidecars + `README.txt`.
- Reconciled GLM loss records (durable, kept):
  `~/.local/state/ai-devops/reviewer-events/evidence/<run_id>/evidence-lost.json`.
- Raw before-list and sweep stderr in this directory.

Safe to delete the quarantine after two completed maintenance rounds that show a
clean sweep.

Posted by MiMo chat unknown on edge-dev
