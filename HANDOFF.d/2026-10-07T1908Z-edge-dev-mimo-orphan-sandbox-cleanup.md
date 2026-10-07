---
issue: 1420
status: OPEN
owner: mimo/orphan-sandbox-cleanup-20261007
---

# HANDOFF — Orphan-sandbox cleanup after PR #1323 (receipt-closeout leftover B)

Machine: edge-dev · Agent: mimo · Written: 2026-10-07 3:08 PM EST
GitHub signature: `Posted by MiMo chat ses_ffe5eecd9bbb7ffeBoedPG5487 on edge-dev`
Parent issue: https://github.com/popcre/ai-devops/issues/1420

This is the coordinator record for leftover **B** named in
`HANDOFF.d/2026-10-07T1138Z-edge-dev-mimo-receipt-closeout-coordinator.md`
(orphan review sandboxes that still fail orphan-sweep reconciliation after
PR #1323 / evidence run `83741ca0e6b8403caeab08853e7a9abb`). Leftover **A**
(reviewer-issue `20261006T123753Z-edge-dev-codex-950377`) was already
`resolved` before this session — do not re-fix the durable-publish guard.

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

**None — nothing in this workstream needs the owner.** Orphan-sandbox cleanup
is technical evidence/reconcile work. It fails closed to an engineer or an
assigned AI reviewer; never to Albert.

**Already settled — do NOT re-ask:**

- Sandbox-evidence publication is fixed and retested (PR #1323, merge
  `b1bd3ad8`; evidence run `83741ca0e6b8403caeab08853e7a9abb`). Do not
  re-fix the guard. Owner: "don't stop working until this is 100% fixed and
  live everywhere" (2026-10-06) — that is done.
- Exact-head independent review is mandatory for reviewer-safety changes.
- No human technical approval. Wipe/security/qualification exceptions are
  AI-reviewer or security-gate decisions.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's public AI workflow recovery toolkit (not
an app/service). It hosts reviewer wrappers (`bin/ai-*`), task gates, installers,
and docs. GitHub: `https://github.com/popcre/ai-devops`. Local primary checkout:
`C:/repos/ai-devops` (landing-only).

This workstream is machine-local state cleanup under
`~/.local/state/ai-devops/` on the Windows host **edge-dev** — not a code
feature. The review-sandbox tool (`bin/ai-review-sandbox`) keeps disposable
review snapshots under `review-sandboxes/`, and the orphan sweep
(`sweep-orphans`, wired at the `bin/ai-review` front door) deletes managed
snapshots whose marker is older than 2 hours, at most 16 examinations per run,
but only when `tools/reviewer_events.py verify-sandbox` accepts the snapshot's
evidence. Snapshots whose evidence is unreconciled are retained forever and
stall the 16-orphan examination cap.

## 2. What we set out to do this session, and why

Goal: clear pre-fix orphaned review sandboxes that still fail orphan-sweep
reconciliation (16-orphan cap) after PR #1323 / evidence run `83741ca0` landed.

Why: the durable-publish guard is fixed and retested (issue record `resolved`),
but a residual pile of pre-fix sandboxes still fails `verify-sandbox`
("required report is not durably published" / "sandbox ownership marker is
unavailable" / packet-retain refusal). Every `ai-review` front-door start
examines up to 16 of them and retains the failures, so the sweep never drains
and slows every review. The resolution record for
`20261006T123753Z-edge-dev-codex-950377` named this as "separate cleanup
backlog, not the landed guard."

Trigger: coordinator handoff
`HANDOFF.d/2026-10-07T1138Z-edge-dev-mimo-receipt-closeout-coordinator.md`
§6 item B, plus the user request to resume the orphan-sandbox cleanup backlog.

## 3. Current state — what is true right now

| Outcome | State | Artifact |
|---|---|---|
| Orphan sweep clean | **Done this session** | `sweep-orphans` exit 0; examine=0 fail=0 (cap=16) after the 2026-10-07 3:06 PM EST pass |
| Unique evidence preserved | **Done this session** | `~/.local/state/ai-devops/review-sandboxes-quarantine-20261007/_preserved-packets-20261007/` |
| GLM finished runs reconciled | **Done this session** | `ai-reviewer-issue evidence reconcile-lost` for `glm-gov-pr4032-slot1-glm-0e27d821bcc8` and `glm-review-3947-fence-glm-845cc9a10ae5`; `verify-sandbox` now OK |
| 18 sandboxes quarantined | **Done this session** | moved byte-for-byte to `review-sandboxes-quarantine-20261007/` (5 sweep-examined + 11 no-marker debris + 2 GLM backups) |
| Live sandboxes | **12 remain, all healthy** | every one has a managed marker and `verify-sandbox` OK; all under the 2 h orphan age |
| Parent issue | **Open as the close-out card** | https://github.com/popcre/ai-devops/issues/1420 |
| Durable-publish guard (PR #1323) | **Done — do not re-fix** | merge `b1bd3ad8`; evidence run `83741ca0e6b8403caeab08853e7a9abb` verified |

### Inventory at session start (2026-10-07)

- 28 live sandboxes under `~/.local/state/ai-devops/review-sandboxes/`
- 247 quarantine entries from a 7:20 AM EDT pass
  (`review-sandboxes-quarantine-20261007/`, README records categories A–E)
- 3627 evidence runs under `reviewer-events/evidence/`
- Sweep-examined candidates (marker + age >2 h): **5**, all failing
  - 2 evidence failures (`required report is not durably published`):
    `codex-diff-review-20261007T111549-…` (7 h, codex `8ee24b12…`),
    `gemini-003cae61375c-…` (5 h, gemini `89a6f739…`)
  - 3 packet-retain failures (verify OK but unsealed / seal mismatch):
    `preflight-codex-107231-…`, `preflight-grok-154390-…`,
    `rlc-muse-e95fc8df0334-…`
- 11 no-marker debris (sweep skips these; they still clutter the root):
  `pool-gemini-*` (4), `pool-muse-*` (3), `pool-qwen-*.lock`, `rlc-muse-527657…`,
  `rlc-muse-5fdbf5…`, `rlc-muse-904af147…`
- 2 GLM sandboxes young but already failing evidence (would hit the cap within
  the hour): `glm-gov-pr4032-slot1-…`, `glm-review-3947-fence-…`

### What the cleanup delivered

1. **`reconcile-lost`** for the two finished GLM runs (exit_code=1,
   `evidence_state=publication-incomplete`, no report on disk, invocation not
   active). Both now return `verify-sandbox` OK. They stay live under the 2 h
   age rule and the normal sweep will delete them when aged — no forced delete.
2. **Packet + marker preservation** for every quarantined sandbox into
   `_preserved-packets-20261007/<name>/` (`.ai-review-*` packets, nested
   `.ai/reviews/packets/` manifests, `.ai-review-sandbox` markers, sidecars,
   any `*.incomplete.patch`).
3. **Byte-for-byte quarantine** of 18 sandboxes (the 5 sweep-examined failures,
   the 11 no-marker debris, plus the two GLM sandboxes kept as backup until
   their sweep delete proves out).
4. **Post-cleanup sweep**: `bin/ai-review-sandbox sweep-orphans` exit 0 with
   **examine=0 fail=0 (cap=16)**. 12 live sandboxes remain, all marker-bearing
   and `verify-sandbox` OK.

Commit / push status of this record: branch
`mimo/orphan-sandbox-cleanup-20261007` in worktree
`C:/repos/ai-devops-wt-orphan-cleanup`, prose-only PR to `main` (see §6).

## 4. Everything we tried that did NOT work

1. **`bash -lc` from the PowerShell host** resolves to WSL (`wsl.exe`), and
   this machine has no WSL distro. Every state-dir command must go through
   `"C:\Program Files\Git\bin\bash.exe"`. Inline `bash -lc '…'` also mangles
   quoting — use a `.sh` file and a one-line bash invocation of that file.
2. **`ai-task-gates start --class repository`** — `repository` is not a declared
   change class. Declared classes live in `config/task-gates.json`
   (`prose`, `code`, `installation`, `reviewer-safety`, `ui-live-workflow`,
   `shared-db`, `deployment`, `infrastructure`, `production`, `private-evidence`,
   `private-tooling`). Prose-only handoff work is `prose`.
3. **`ai-reviewer-issue` with no subcommand** throws `IndexError` inside
   `tools/reviewer_events.py` (it `exec`s the Python tool with no argv guard
   past `evidence`). Always pass a real subcommand, e.g.
   `ai-reviewer-issue evidence reconcile-lost …`.
4. **`reconcile-lost` is GLM-only.** Codex and Gemini runs are refused
   ("cannot prove a gemini report is gone; use reconcile-sandbox"). There is no
   report to feed `reconcile-sandbox` for those runs, so the only safe path is
   preserve-then-quarantine — matching the 7:20 AM EDT pass.
5. **Packet retain refuses unsealed / mismatched seals.** `preflight-*` packets
   have `MANIFEST.md` but no `MANIFEST.sha256`; `rlc-muse-e95fc8df`'s seal does
   not match contents. `remove_sandbox` correctly skips the delete so the only
   packet copy is not lost. Preserving the packet first, then quarantining the
   whole sandbox, is the recoverable path.
6. **`pool-*` / some `rlc-muse-*` have no `.ai-review-sandbox` marker.** The
   sweep only examines entries with a marker, so these never count toward the
   16-orphan cap — but they are still debris and were quarantined after
   preserving their nested packet manifests.

## 5. Root causes and key findings

1. **The 16-orphan cap is an examination cap, not a deletion cap.**
   `ORPHAN_SWEEP_MAX_REMOVALS=16` in `bin/ai-review-sandbox:95`. Each old
   managed entry is examined, including refused removals. A retained
   unreconciled orphan still consumes a slot; a private cursor rotates past it
   so one orphan cannot starve later recoverable snapshots — but a large pile
   still takes many review starts to drain.
2. **`verify-sandbox` fails for two distinct reasons on this pile.**
   - With owners: `required.json` exists, no report, no `evidence-lost.json` →
     "required report is not durably published" (`tools/reviewer_events.py`
     `verify_reports`).
   - Without a readable marker: "sandbox ownership marker is unavailable"
     (`sandbox_marker`, `reviewer_events.py:313`).
3. **Failed reviews that never published a report have no unique *output*.**
   Their packets hold `patch.diff` + `identity.json` (review *input*). That
   input is preserved in quarantine before removal. The `.ai/reviews/*.md` files
   inside those snapshots are source-tree content copied from the reviewed
   repository, not new verdicts. No unreviewed paid result was destroyed.
4. **`reconcile-lost` is the designed terminal state for a provably gone GLM
   report** (`docs/reviewer-issues.md` §Durable report publication). It writes
   `evidence-lost.json` beside `required.json` and makes `verify_sandbox`
   return the terminal reference `RUN_ID/evidence-lost`, which prune honours.
   It refuses while the invocation is still running, while a required patch or
   prepared artifact exists, and while a matching report still exists.
5. **Age alone is not deletion proof** (`cleanup-worktree`). Every removal in
   this pass was justified by: finished invocation + no report + reconciled
   evidence or preserved packet, or no ownership marker + preserved nested
   manifests. Young healthy snapshots were left alone for the normal sweep.

## 6. Exact next steps

1. **Land this handoff.** Branch `mimo/orphan-sandbox-cleanup-20261007`,
   worktree `C:/repos/ai-devops-wt-orphan-cleanup`, prose-only PR to
   `popcre/ai-devops` `main`. Documentation-only PRs merge immediately through
   the normal merge queue (never `--admin`). You'll know it worked when the
   PR shows `"merged": true` and the commit is reachable from `origin/main`.
2. **Leave the 12 live sandboxes alone.** They all verify OK and are under the
   2 h orphan age. When they age, `sweep-orphans` will delete them normally.
   Do not force-delete young snapshots.
3. **Optional later: dispose quarantine after two clean maintenance rounds.**
   `review-sandboxes-quarantine-20261007/README.txt` says "Safe to delete after
   two completed maintenance rounds with a clean sweep." This session is clean
   sweep round 1. A second clean sweep (for example after the current young set
   ages out) is the gate. You'll know it worked when a second sweep run reports
   examine=0 fail=0 and nothing new was quarantined; only then may the
   quarantine directory be deleted, with its README's recovery note kept in
   git history / this handoff.
4. **Do not reopen the durable-publish guard work.** PR #1323 is landed and
   retested. If a new sandbox-evidence publication failure appears, open a
   **new** issue — do not revive
   `20261006T123753Z-edge-dev-codex-950377`.
5. **Retire the predecessor coordinator handoff** only after its two leftovers
   are both proven closed on issue #1420 (A already `resolved`; B proven by
   this file's §3). Successor rule in `handoff-writer`: delete
   `HANDOFF.d/2026-10-07T1138Z-edge-dev-mimo-receipt-closeout-coordinator.md`
   in the same PR that lands this file, once (1) its work is on `main`, (2)
   every open obligation is carried here or on #1420, (3) nothing unique is
   lost. You'll know it worked when `HANDOFF.d/` no longer contains the
   predecessor and issue #1420 still holds the close-out card.

## 7. Constraints and gotchas in force

- Branch + PR + merge queue; never push protected `main`. `git var
  GIT_COMMITTER_IDENT` must show `Albert Hazan <u2giants@users.noreply.github.com>`.
- Canonical checkout is landing-only; write-capable work uses its own worktree.
- Never edit another session's `HANDOFF.d/` file. Root `HANDOFF.md` is a static
  pointer (`handoff-pointer: v1`).
- Independent exact-head review for reviewer-wrapper / evidence-tool changes.
  This pass touched only machine-local state and prose — no wrapper change.
- Times in human output: EST. Sign GitHub posts
  `Posted by MiMo chat ses_ffe5eecd9bbb7ffeBoedPG5487 on edge-dev`.
- Windows host: PowerShell mangles `bash -lc` quoting — use a `.sh` script
  invoked by `"C:\Program Files\Git\bin\bash.exe" script.sh`.
- `cleanup-worktree` / orphan-sweep age rules: never treat age alone as
  deletion proof; preserve unique unreviewed evidence before removal.
- `AI_KEEP_SANDBOX=1` retains any managed snapshot (belt-and-braces if a
  future pass is too aggressive).

## 8. Access and environment

- Host: edge-dev (Windows, this machine).
- Git Bash: `C:\Program Files\Git\bin\bash.exe`.
- Sandbox root: `~/.local/state/ai-devops/review-sandboxes/`
  (production root is a Windows junction to D: — `find -L` is required).
- Evidence store: `~/.local/state/ai-devops/reviewer-events/`
  (`events.jsonl` + `evidence/<run_id>/`).
- Quarantine: `~/.local/state/ai-devops/review-sandboxes-quarantine-20261007/`
  with `README.txt` and `_preserved-packets-20261007/`.
- Tools: `bin/ai-review-sandbox sweep-orphans`,
  `bin/ai-reviewer-issue evidence reconcile-lost`,
  `python tools/reviewer_events.py verify-sandbox`.
- `gh` as `u2giants` via `bin/ai-gh` (never raw `gh` for waits).
- Launcher: `C:/Users/ahazan/.local/bin/ai-task-gates`.

## 9. Open questions and risks

- **2026-10-07:** Quarantine is retained as a byte-for-byte backup. It is not
  deleted until a second clean maintenance sweep proves out (§6 step 3). Treat
  that as the only open disposal gate.
- **2026-10-07:** The two GLM sandboxes are reconciled but not yet deleted
  (they are young). If a later sweep still retains them, inspect
  `evidence-lost.json` under
  `~/.local/state/ai-devops/reviewer-events/evidence/<run_id>/` before
  assuming the reconcile failed.
- **2026-10-07:** Pool-runner sandboxes without a managed marker do not count
  toward the 16-orphan cap. If they reappear, they are wrapper debris, not
  evidence-orphan problems — quarantine them the same way after preserving
  nested packet manifests.
- Orphan sweep is a known class; a partial sweep is not completion. Name every
  failure left behind (none remain in the live root after this pass).

---

### Self-audit (handoff-writer Mode A)

1. **Comprehensive for a brand-new developer?** Yes — §1–2 define the app and
   goal; §3 has the before/after inventory and proof; §6 is executable without
   chat.
2. **As effective as this session?** Yes — §4 lists every dead end (WSL bash,
   task-gates class, reconcile-lost provider limit, unsealed packets, no-marker
   debris); §5 captures the examination-cap and evidence-reconcile findings.
3. **Every relevant detail?** Yes — background, goal, state, failures,
   constraints, risks, next actions, verification gates, secrets by location.
4. **Section 0 shows every owner decision and no technical approvals?** Yes —
   sweep found no business decisions; leftover B is technical and stays in §6.
