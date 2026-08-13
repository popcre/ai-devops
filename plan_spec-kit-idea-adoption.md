# IMPLEMENTATION PLAN — port five Spec Kit ideas into the toolkit (2026-08-13)

Companion handoff:
[`HANDOFF.d/2026-08-13T1941Z-al8960ofc-claude-spec-kit-verdict-reversed.md`](HANDOFF.d/2026-08-13T1941Z-al8960ofc-claude-spec-kit-verdict-reversed.md)
(the original `ccweb` handoff was retired on 2026-08-13 — its next steps told the
reader to execute this now-superseded plan).
Decision record this plan implements:
[`docs/github-spec-kit-evaluation.md`](docs/github-spec-kit-evaluation.md).

## STATUS — read this first

> ## ⛔ THIS PLAN IS SUPERSEDED (2026-08-13). DO NOT EXECUTE IT.
>
> Two independent reviews — Grok 4.6
> ([`docs/grok-4.6-spec-kit-second-opinion.md`](docs/grok-4.6-spec-kit-second-opinion.md))
> and Kimi K3 as tie-breaker
> ([`docs/kimi-k3-spec-kit-tiebreak.md`](docs/kimi-k3-spec-kit-tiebreak.md)) —
> independently rejected this plan's shape. Their load-bearing claims were
> spot-checked against the files and hold. The binding decision is
> **[`docs/github-spec-kit-evaluation.md`](docs/github-spec-kit-evaluation.md) §8**.
>
> Two steps survive, in reduced form; the rest are dropped or deferred. The text
> below is kept **as a record of the reasoning**, not as instructions. Do not
> restart at step 1.

| # | Step | Phase | Status |
|---|---|---|---|
| 1 | Derive the migration set from `HANDOFF.d/` | 1 | 🟥 deferred — see §8 of the decision record |
| 2 | `git mv` 11 plans to `specs/NNN-<slug>/plan.md` | 1 | 🟥 deferred — blocked on `plan_context-engineering-consolidation.md` steps 8–10 |
| 3 | Rewrite references to the migrated plans | 1 | 🟥 deferred with step 2 |
| 4 | Verify migration (audit + grep gates) | 1 | 🟥 deferred with step 2 |
| 5 | Split the standard into `spec.md` + `plan.md` | 2 | ⬛ dropped — prerequisite `specify init` research never done |
| 6 | Add the `tasks.md` contract with task IDs | 2 | ✅ done 2026-08-13 — reduced to new delegated/multi-phase plans only |
| 7 | Mirror steps 5–6 into `implementation-plan-writer` | 2 | ✅ done 2026-08-13 — `tasks.md` half only |
| 8 | Teach stage 02 to review the spec separately | 2 | ⬛ dropped with step 5 |
| 9 | Add `templates/prompts/00-clarify.md` | 3 | ⬛ dropped — `bin/ai-model-call:63-71` has no `clarify` stage, so no runner could invoke it |
| 10 | Wire the clarify gate into the pipeline skill | 3 | ⬛ dropped with step 9 |
| 11 | Add the converge check to `fresh-session` | 4 | ⬛ dropped — body-only edit behind a description that cannot trigger it |
| 12 | Add the converge gate to the delegate handoff contract | 4 | ⬛ dropped with step 11 |
| 13 | Final verification + docs/handoff update | 4 | ✅ done 2026-08-13 |
| 14 | Converge check in `close-old-session`, with a real description | — | ✅ done 2026-08-13 — replaces steps 11–12 |

**Do not start a fresh session at step 1.** Read the decision record §8 instead.

---

## 1. The ultimate goal — what we are actually trying to achieve

Today, when Albert hands a piece of work to a delegate model (Grok, GLM, Kimi,
Codex), he hands it an entire implementation plan — often 20–80 KB — and the
delegate sometimes does part of the job and reports success. There is no smaller
unit of work to hand over, and no mechanical way to ask "what in this plan is
actually still undone?"

When this work is finished, three things are true that are not true today:

1. A delegate can be given **one numbered task** instead of a whole plan.
2. Any session can ask "what is left?" and get an answer derived from the
   **repository**, not from the plan's prose.
3. The repository root is legible again — plans live in per-topic directories
   instead of 13 files totalling 424 KB dumped beside `README.md`.

**If any step below conflicts with this goal, the goal wins — stop and flag it.**

Explicitly *not* the goal: installing `github/spec-kit`. That was evaluated and
declined; see `docs/github-spec-kit-evaluation.md` §3 and §5. If a step here
starts to look like "just install spec-kit," that is drift — stop.

## 2. What this application is

`u2giants/ai-devops` is a **backup-and-restore toolkit for a multi-model AI
coding workflow**. It is Bash CLI scripts, prompt templates, docs, and
skill scaffolding — not an application. No database, no container, no CI/CD, no
`.github/workflows`.

- **Repo:** `u2giants/ai-devops` (public). Toolkit home on every host is
  `/worksp/ai-devops` — **never** `/opt/ai-devops`.
- **Branch for this work:** `claude/github-spec-kit-evaluation`.
- **Who uses it:** Albert (GitHub `u2giants`) plus AI sessions — Claude/Opus
  plans and reviews, Codex/GPT-5.5 implements and tests, with Grok/GLM/Kimi as
  delegate reviewers and implementers.
- **What it installs:** `bin/ai-*` scripts symlinked into `/usr/local/bin` by
  `install.sh`; real config seeded into `/etc/ai-devops/*.env` (never in git).
- **The staged workflow** it drives, mapped to models via
  `/etc/ai-devops/models.env`: plan → plan-review → implement → diff-review →
  test → security-review → final-review, with prompts in
  `templates/prompts/01..07`.

Read `AGENTS.md` first in any session here — it is the canonical operating guide
and documentation router.

## 3. What triggered this work

On 2026-08-13 Albert asked whether `github/spec-kit` would benefit this repo.
The evaluation (`docs/github-spec-kit-evaluation.md`) concluded: do not adopt the
tool, port five of its ideas. Albert then asked for the evaluation to be written
up plus an implementation plan covering **all** five items. This is that plan.

There is no bug and nothing is broken. This is a deliberate improvement to the
planning/delegation machinery, motivated by two recorded failure records:
`plan_kimi-incomplete-implementation-recovery.md` and
`plan_glm-incomplete-implementation-recovery.md` — both cases of a delegate
reporting success having completed only part of the work.

## 4. Scope — in and out

**In scope** (the five ported ideas, from `docs/github-spec-kit-evaluation.md` §4):

| Item | Ported idea | Phase |
|---|---|---|
| 4.4 | Per-topic `specs/NNN-<slug>/` directories | 1 |
| 4.3 | Spec (`what/why`) separated from plan (`how`) | 2 |
| 4.1 | Task-ID decomposition (`tasks.md`) | 2 |
| 4.5 | A clarify gate before the plan stage | 3 |
| 4.2 | A converge / drift check | 4 |

**NOT in this plan:**

- Installing `specify-cli`, `uv`, or Python tooling anywhere. Declined.
- Creating any **new** skill directory. See §7 R2 — it breaches a measured budget.
- `/speckit.taskstoissues` (GitHub issues from tasks). This repo has no
  issue-driven workflow; deliberately dropped.
- `/speckit.analyze` as a separate command. Its cross-artifact consistency check
  is absorbed into step 8 (stage 02 reviewing the spec separately).
- Migrating `plan_context-engineering-consolidation.md` or
  `plan_ai-glm-permission-failures.md`. See §8 LOCKED decision D2.
- Migrating **this** plan file. See §8 LOCKED decision D2.
- Retro-fitting `spec.md` / `tasks.md` onto the 11 already-written plans. They
  migrate as-is; the new structure applies to plans written from now on.
- Touching `bin/` scripts, `install.sh`, or anything under `/etc/ai-devops/`.
  This work is templates, skills, and docs only.
- Raising any number in `tools/context-audit/budgets.json`.

## 5. Current state of the code

Nothing in this plan has been implemented. On branch
`claude/github-spec-kit-evaluation`, two new files exist and are committed:

- `docs/github-spec-kit-evaluation.md` — the decision record.
- `plan_spec-kit-idea-adoption.md` — this file.

Everything else is untouched and matches `origin/main`. Specifically:

- **13 `plan_*.md` files sit in the repo root**, 424,656 bytes total
  (`du -cb plan_*.md`). None have been moved.
- `templates/system/implementation-plan-standard.md` is the single fused
  13-section standard. There is no `spec.md`/`tasks.md` concept anywhere.
- `templates/prompts/` holds `01-opus48-plan.md` … `07-opus48-final-review.md`.
  There is **no** `00-*.md`; the clarify gate does not exist.
- `skills/shared/fresh-session/SKILL.md` has Steps 1–4 and a `## Output`
  section. Its Step 3 is the closest existing thing to a converge check, but it
  only verifies that the *outgoing phase spec contains an instruction*; it never
  inspects the repository.
- `specs/` does not exist.

Measured baselines (from `python3 tools/context-audit/context-audit.py`, run
2026-08-13 on this branch — **re-run it before you start**):

| Budget | Current | Budget | Headroom |
|---|---|---|---|
| `alwaysLoadedBytes` | 24,491 | 24,713 | 222 |
| `startupRoutedBytes` | 35,836 | 35,972 | **136** |
| `claudeSkillManifestBytes` | 21,521 | 21,521 | **0** |
| `codexSkillManifestBytes` | 13,943 | 14,015 | 72 |

`startupRoutedBytes` = `AGENTS.md` + `CLAUDE.md` only
(`context-audit.py:478-479`). It was 35,523 on `origin/main`; the two `AGENTS.md`
rows added by this session (a documentation-map row and a §Pending work row) cost
313 bytes, leaving **136**. Those rows deliberately use plain backticks rather
than Markdown links — the link form cost 441 bytes and left only 8, which step 3
would have breached.

Both bolded numbers constrain the whole plan; see §11 and the step 3 warning.

## 6. Key findings and root cause

Everything here was measured on 2026-08-13. Each one changes what a step may do.

1. **The Claude skill manifest has zero headroom.**
   `claudeSkillManifestBytes` is 21,521 against a 21,521 budget.
   `tools/context-audit/budgets.json` line 8: *"Never raise a budget to silence a
   warning."* Therefore **no new skill directory may be created by this plan.**
2. **Skill manifest bytes count only front-matter `name` + `description`.**
   `tools/context-audit/context-audit.py:512-516` renders the manifest as
   `"\n".join(f"{name}: {description}")`. Editing a skill's **body** costs zero
   manifest bytes. This is what makes step 11 possible at all.
3. **`startupRoutedBytes` is nearly full.** `AGENTS.md` and `CLAUDE.md` are the
   only two files in that class (`context-audit.py:478-479`). `origin/main` had
   449 bytes of headroom; after this session's two `AGENTS.md` rows, **136**
   remain (§5). Router edits must be economical or the budget warns. Using plain
   backticks instead of Markdown links in a router row saves roughly 130 bytes
   per row — worth knowing, because it is the difference between step 3 fitting
   and breaching.
4. **Six files in `HANDOFF.d/` link to `plan_*.md` paths**, and
   `templates/system/handoff-standard.md` forbids editing another session's
   handoff file ("never open, edit, reformat, 'tidy', merge, or delete another
   session's file"). Moving a plan those files point at would break links that
   nobody is permitted to repair. Only **two distinct plans** are affected:
   `plan_context-engineering-consolidation.md` and
   `plan_ai-glm-permission-failures.md`.
5. **`context-audit.py:571` hard-codes `plan_context-engineering-consolidation.md`.**
   That plan is excluded from migration by finding 4, so **line 571 needs no
   change**. Do not "fix" it. When that workstream eventually closes and the plan
   migrates, line 571 must move with it — recorded in §13 as follow-on work.
6. **Git dates cannot order the migration.** All 11 migrating plans share a
   single add-commit (`2026-08-12T17:01:21-04:00`) in this clone, so
   `git log --diff-filter=A` gives no usable chronology. NNN must be assigned
   alphabetically by slug. Step 2 carries the resulting table so it is not
   re-derived.
7. **`plan_standardized-saved-views.md` does not exist in this repo.** It is
   referenced from `memory/dflow-plm/aggrid-group-id-survives-as-context-colid.md:31`
   and `memory/dflow-plm/plan-standardized-saved-views.md:11`, and it belongs to
   the **dflow** repo. Confirmed absent via `ls`. Those two references must be
   left exactly as they are — rewriting them would point dflow memory at a
   nonexistent `ai-devops` path.
8. **`memory/ai-devops/phase3-plan-location.md` hard-codes a Windows path**
   (`C:\repos\ai-devops\plan_phase3-config-consolidation.md`, lines 3 and 12).
   That plan does migrate, so this memory file goes stale unless step 3 updates
   it. It exists precisely because Albert asked not to have to memorise paths, so
   a stale value here defeats its whole purpose.

## 7. Approaches considered and REJECTED, and why

- **R1 — Adopt `github/spec-kit` outright.** Rejected in
  `docs/github-spec-kit-evaluation.md` §3: it breaks the documented pure-Bash
  constraint in `docs/architecture.md`, adds Python + `uv` to
  `docs/restore-from-zero.md`, collides with `bin/ai-install-skills` over the
  `.claude/` tree, contradicts the recorded "no supply chain" position in
  `AGENTS.md` §Intentional quirks, and adds a fifth artifact system while
  `plan_context-engineering-consolidation.md` is actively shrinking loaded
  context. Do not relitigate.
- **R2 — Create a new `skills/shared/plan-converge/` skill for the converge
  check.** This was the original suggestion in the evaluating chat and it is
  **wrong on measurement.** A `shared/` skill adds its `name: description` line
  to *both* client manifests (`context-audit.py:507-509`). A realistic entry is
  ~370 bytes; Claude has 0 bytes of headroom and Codex has 72. It would breach
  one budget immediately and nearly breach the other, against the standing
  "never raise a budget" rule. Step 11 extends the **body** of the existing
  `fresh-session` skill instead, which costs zero manifest bytes (finding 2).
- **R3 — Move all 13 root plans.** Rejected: breaks links inside other
  sessions' `HANDOFF.d/` files, which no session is allowed to repair
  (finding 4). Two plans stay put.
- **R4 — Order `specs/NNN-*` chronologically by git add-date.** Rejected: all 11
  share one squashed add-commit, so the ordering would be arbitrary and
  irreproducible (finding 6). Alphabetical is deterministic.
- **R5 — Port `/speckit.taskstoissues`.** Rejected as out of scope: this repo has
  no issue-driven workflow and no CI to consume issues.
- **R6 — Add `/speckit.analyze` as its own stage.** Rejected as redundant: an
  eighth stage costs a prompt file and router text for a check that stage 02
  already performs once the spec is a separate artifact (step 8).
- **R7 — Delete the migrated plans instead of moving them.** Rejected: several
  are explicitly retained as records (`AGENTS.md` line 63 calls the three GLM
  plans "records only"; line 394 retains
  `plan_phase3-config-consolidation.md` as the verification record). Deleting
  them destroys durable evidence.

## 8. Design decisions already made, and their reasoning

| ID | Decision | Status |
|---|---|---|
| D1 | Ported ideas are implemented as edits to existing templates, skills, and docs. No new tool, no new dependency, no new skill directory. | **LOCKED** 2026-08-13 (§7 R1, R2) |
| D2 | Do not move any plan referenced by a file **currently present** in `HANDOFF.d/`. Presence means the workstream is open and its links must keep resolving. Today that exempts `plan_context-engineering-consolidation.md`, `plan_ai-glm-permission-failures.md`, and — because the companion handoff for this plan references it — **this plan file itself**. | **LOCKED** 2026-08-13 (§6 finding 4) |
| D3 | Phase order is 1 → 2 → 3 → 4. Migration runs **first** so later phases write the new paths once instead of writing root paths and rewriting them. The converge work runs **last** because it consumes the task-ID table that step 6 creates. | **LOCKED** 2026-08-13 |
| D4 | Layout is `specs/NNN-<slug>/plan.md`, with `spec.md` and `tasks.md` as optional siblings added by new work. Migrated plans get only `plan.md`. | **LOCKED** 2026-08-13 |
| D5 | NNN is assigned alphabetically by slug, zero-padded to three digits. | **LOCKED** 2026-08-13 (§6 finding 6) |
| D6 | Task IDs are `T###`, unique and stable **within one `tasks.md`**, never renumbered once assigned. A completed task's row is marked, never deleted — a deleted row makes a delegate's report unverifiable. | **LOCKED** 2026-08-13 |
| D7 | The converge check reports and appends; it never edits code and never marks a task done on the delegate's word. Same reasoning as the existing read-only review gates in `AGENTS.md` §Intentional quirks ("Review stages never fix what they find"). | **LOCKED** 2026-08-13 |
| D8 | Whether `specs/` should be added to `.claudeignore`. Moving files does not change what the router loads, and plans must stay readable on demand, so the default is **do not ignore it**. | **OPEN** — implementer's judgment; if the context audit flags `specs/` growth, raise it with Albert rather than deciding alone. |
| D9 | Exact wording of the `tasks.md` column set beyond the required ID / task / files / depends-on / parallel / status columns. | **OPEN** — implementer's judgment. |

## 9. The plan — numbered, ordered steps

Work on branch `claude/github-spec-kit-evaluation`. Run
`python3 tools/context-audit/context-audit.py --json /tmp/audit-before.json`
before you start and keep the file — several gates diff against it.

### Phase 1 — Per-topic plan directories (item 4.4)

**Step 1 — Derive the migration set.**
Do not trust the list in this plan; re-derive it, because `HANDOFF.d/` may have
changed since 2026-08-13.

```bash
grep -rho 'plan_[a-z0-9-]*\.md' HANDOFF.d/ | sort -u        # the exclusion list
ls -1 plan_*.md | wc -l                                      # the full set
```

Migration set = every root `plan_*.md` **minus** the exclusion list **minus**
`plan_spec-kit-idea-adoption.md` (D2).
*Verification gate:* the exclusion list is non-empty, and
`|migration set| + |exclusions| + 1 == |ls -1 plan_*.md|`. On 2026-08-13 that was
`11 + 2 + 1 == 14`. If the exclusion list comes back empty, **stop** — that means
`HANDOFF.d/` is empty, which contradicts finding 4 and something else has changed.

**Step 2 — Move the files.**
Assign NNN alphabetically (D5). This was the mapping on 2026-08-13; re-derive it
if step 1 produced a different set:

| NNN | From | To |
|---|---|---|
| 001 | `plan_ai-glm-permission-deadlock.md` | `specs/001-ai-glm-permission-deadlock/plan.md` |
| 002 | `plan_ai-grok-review.md` | `specs/002-ai-grok-review/plan.md` |
| 003 | `plan_delegate-wrapper-hardening.md` | `specs/003-delegate-wrapper-hardening/plan.md` |
| 004 | `plan_glm-implementation-job-tracking.md` | `specs/004-glm-implementation-job-tracking/plan.md` |
| 005 | `plan_glm-incomplete-implementation-recovery.md` | `specs/005-glm-incomplete-implementation-recovery/plan.md` |
| 006 | `plan_glm-service-reliability.md` | `specs/006-glm-service-reliability/plan.md` |
| 007 | `plan_grok-debate-continuity.md` | `specs/007-grok-debate-continuity/plan.md` |
| 008 | `plan_kimi-debate-context-continuity.md` | `specs/008-kimi-debate-context-continuity/plan.md` |
| 009 | `plan_kimi-incomplete-implementation-recovery.md` | `specs/009-kimi-incomplete-implementation-recovery/plan.md` |
| 010 | `plan_kimi-persistent-implementation-sessions.md` | `specs/010-kimi-persistent-implementation-sessions/plan.md` |
| 011 | `plan_phase3-config-consolidation.md` | `specs/011-phase3-config-consolidation/plan.md` |

Use `git mv` (never `mv` + `git add`) so rename detection survives — the git
history of these files is the archive that makes R7's "don't delete" safe.
*Verification gate:* `git status --short` shows 11 lines starting `R`, and
`ls -1 plan_*.md` lists exactly three files: the two exclusions plus
`plan_spec-kit-idea-adoption.md`.

**Step 3 — Rewrite references to the migrated plans.**
These were the reference sites on 2026-08-13. **Only these** — do not
bulk-`sed` the repo.

| File | Lines | Note |
|---|---|---|
| `AGENTS.md` | 63, 65, 72, 395, 402 | 10 path rewrites across the documentation-map rows and §Pending work. **Byte warning below.** |
| `docs/config-consolidation-proposal.md` | 11, 189 | |
| `docs/config-inventory.md` | 7, 268 | |
| `docs/glm-opencode.md` | 325 | Line 471 points at an **excluded** plan — leave it. |
| `docs/github-spec-kit-evaluation.md` | 111, 112 | |
| `memory/ai-devops/kimi-persistent-implementation-plan.md` | 3 | |
| `memory/ai-devops/phase3-plan-location.md` | 3, 12 | Hard-codes a **Windows** path (finding 8). Update the path; keep it Windows-shaped as the surrounding text expects. |
| `skills/claude/session-docs-update/SKILL.md` | 51 | |
| `skills/claude/sync-dotfiles/SKILL.md` | 186 | |
| `skills/codex/codex-docs-update/SKILL.md` | 58 | |
| `skills/codex/codex-sync-dotfiles/SKILL.md` | 151 | |
| `skills/shared/implementation-plan-writer/SKILL.md` | 203 | Body text only — front matter must not change (finding 2). |

**⚠ Byte warning for the `AGENTS.md` rewrites.** Each `plan_<slug>.md` →
`specs/NNN-<slug>/plan.md` rewrite is ~10 bytes longer, and there are 10 of them
in `AGENTS.md` — a measured **+100 bytes** against the **136** of
`startupRoutedBytes` headroom recorded in §5. It fits with 36 bytes to spare, so
make no other prose additions to `AGENTS.md` or `CLAUDE.md` in this phase. If the
step 4 audit shows a `startupRoutedBytes` warning, shorten the Spec Kit
documentation-map row this session added (it is the newest and most compressible
text) — **never** raise the budget.

**Do not touch:** any file under `HANDOFF.d/` (finding 4);
`tools/context-audit/context-audit.py:571` and
`tools/context-audit/budgets.json:6` (finding 5 — they name an excluded plan);
`memory/dflow-plm/aggrid-group-id-survives-as-context-colid.md:31` and
`memory/dflow-plm/plan-standardized-saved-views.md:11` (finding 7 — cross-repo).

*Verification gate:*

```bash
grep -rn 'plan_[a-z0-9-]*\.md' --include='*.md' --include='*.py' --include='*.json' . \
  | grep -v '^\./\.git' | grep -v '^\./HANDOFF\.d/' | grep -v '^\./specs/'
```

Every surviving hit names one of: `plan_context-engineering-consolidation.md`,
`plan_ai-glm-permission-failures.md`, `plan_spec-kit-idea-adoption.md`, or
`plan_standardized-saved-views.md`. Any other name is a missed rewrite.

**Step 4 — Verify the migration.**
```bash
python3 tools/context-audit/context-audit.py --json /tmp/audit-after1.json
```
*Verification gate:* `brokenLinks` is empty (compare against
`/tmp/audit-before.json` — it was empty before, so it must still be), and no
budget entry moved from `ok` to a warning. `startupRoutedBytes` will have changed
because `AGENTS.md` changed; it must stay ≤ 35,972. If it exceeds that, shorten
your `AGENTS.md` wording — **do not** edit `budgets.json`.

Commit phase 1 on its own so the rename is reviewable in isolation.

### Phase 2 — Spec/plan split and task IDs (items 4.3 and 4.1)

Steps 5 and 6 both edit `templates/system/implementation-plan-standard.md`. Do
them in one editing pass over that file, then mirror both into the skill in step 7.

**Step 5 — Split the standard into `spec.md` + `plan.md`.**
In `templates/system/implementation-plan-standard.md`, restructure the required
13 sections into two artifacts, keeping all 13 — none are dropped:

- `specs/NNN-<slug>/spec.md` — sections 1–4 (ultimate goal, what this
  application is, what triggered this work, scope in/out). **Tech-free:** no file
  paths, no function names, no framework or CLI choices. A reader must be able to
  disagree with the *intent* without reading any implementation.
- `specs/NNN-<slug>/plan.md` — sections 5–13, plus a one-line link up to
  `spec.md`.

State explicitly that the goal-wins instruction (§1 of the standard) lives in
`spec.md`, and that `plan.md` must link to it, because that is the sentence an
implementer steers by when a step is wrong.
*Verification gate:* the standard names both artifacts, maps every one of the 13
sections to exactly one of them, and the comprehensiveness checklist has an item
requiring `spec.md` to contain no file paths.

**Step 6 — Add the `tasks.md` contract.**
Add a section to the same standard defining `specs/NNN-<slug>/tasks.md` as the
delegation surface. Required columns: ID (`T###`), task, target files,
depends-on, parallel-safe, status. Required rules:

- IDs are stable and never renumbered; completed rows are marked, not deleted (D6).
- Every task names concrete files and carries its own verification gate — the
  same bar §9 of the standard already sets for steps.
- **A delegate is handed a task ID plus `spec.md`, never the whole plan.** This
  is the sentence that makes the whole item worthwhile; say it plainly and say
  why (`specs/005-glm-incomplete-implementation-recovery/plan.md` and
  `specs/009-kimi-incomplete-implementation-recovery/plan.md` are the recorded
  failures — use the post-migration paths).
- `tasks.md` is required only for plans that will be delegated or that have more
  than one phase. A small single-session plan does not need one; say so, or the
  standard becomes busywork.

*Verification gate:* the standard defines the six columns, the never-renumber
rule, and the hand-over-one-task rule; and the STATUS-table guidance already in
the standard is reconciled with `tasks.md` so a reader cannot mistake them for
two competing trackers.

**Step 7 — Mirror steps 5–6 into the skill.**
`skills/shared/implementation-plan-writer/SKILL.md` is explicitly self-contained
— its closing line reads *"This SKILL.md is self-contained; keep it in sync when
either standard changes."* Apply the same structural changes to its §Required
structure, §Comprehensiveness checklist, and §Mechanics.
**Body only — do not change the `description:` front matter** (finding 1: zero
manifest headroom).
*Verification gate:* `python3 tools/context-audit/context-audit.py` reports
`claudeSkillManifestBytes` **unchanged at 21,521** and `codexSkillManifestBytes`
unchanged at 13,943. Any movement means front matter was touched — revert it.

**Step 8 — Teach stage 02 to review the spec separately.**
`templates/prompts/02-opus-plan-review.md` currently reviews one fused document.
Add an explicit first pass: review `spec.md` alone — is the goal coherent, is the
scope bounded, is anything technical leaking in — and only then review `plan.md`
against it. Include the cross-artifact consistency question absorbed from
`/speckit.analyze` (§7 R6): does every task in `tasks.md` trace to something in
`spec.md`, and does every scoped item have at least one task?
*Verification gate:* the prompt names all three artifacts and asks the
trace-both-ways question in both directions.

### Phase 3 — The clarify gate (item 4.5)

**Step 9 — Add `templates/prompts/00-clarify.md`.**
A new stage-zero prompt, read-only, run before stage 01. It must:

- Ask for the smallest set of questions that would change the plan — target
  three to five, not an interrogation.
- Rank each question by what it blocks, mirroring the BLOCKING / RECOVERABLE
  split that `templates/system/handoff-standard.md` §0 already uses, so Albert
  reads one familiar shape everywhere.
- State plainly that it must **not** write files or produce a plan.
- End by telling the caller that unanswered questions become explicit
  assumptions in `spec.md` §Scope — so an unanswered clarify never silently
  stalls the pipeline.

Numbering it `00-` keeps `01..07` stable; nothing else references stage numbers
positionally.
*Verification gate:* the file exists, is read-only in wording, and caps its own
question count.

**Step 10 — Wire the clarify gate into the pipeline.**
In `skills/claude/ai-development-pipeline/SKILL.md`, add a row to the stages
table for stage 00 (model: Opus 4.8 high reasoning, same as stage 01 — it is
planning work) and note that it is **optional for a well-specified task and
expected for a vague one**. Body only; leave the front matter alone.
Add the same stage-00 row to `docs/architecture.md` §The staged workflow so the
architecture doc and the skill do not disagree.
*Verification gate:* both files list stage 00; a `grep -c` for the seven original
stage names still returns the same counts in both (nothing was renumbered).

### Phase 4 — The converge check (item 4.2)

**Step 11 — Add the converge check to `fresh-session`.**
Extend `skills/shared/fresh-session/SKILL.md` with a new step between its
current Step 3 and Step 4, titled so it reads as a repository check rather than a
document check. It must:

- Read `tasks.md` and, for each row not marked done, look at the **repository**
  — the named files, `git log`, `git diff` — and classify it: done-but-unmarked,
  genuinely open, or contradicted by the current code.
- **Append** newly discovered work as new `T###` rows rather than editing
  existing ones (D6).
- Never edit code, and never mark a task done because a delegate said so (D7) —
  only because the named files show it.
- Report the three counts plainly, and state explicitly when a delegate's
  completion claim did not survive the check.

This is a **body-only** edit; the `description:` front matter must not change
(finding 1). The skill's existing Step 3 stays — it checks the outgoing spec's
wording, which is a different thing from checking the repo.
*Verification gate:* `context-audit.py` shows both manifest byte counts
unchanged (21,521 / 13,943), and the skill body contains the append-only and
never-trust-the-claim rules.

**Step 12 — Add the converge gate to the delegate handoff contract.**
`templates/delegation/debate-turn.md` is the provider-neutral contract the
Grok/GLM/Kimi wrappers use. Add the rule that a delegate's completion report is
**not** accepted on its own: the parent session runs the converge check from step
11 against the task IDs the delegate claimed, before marking anything done.
Cross-reference the two recovery plans by their post-migration paths.
*Verification gate:* the contract states that a completion claim is unverified
until the parent has checked the named files.

**Step 13 — Final verification and documentation.**
1. `python3 tools/context-audit/context-audit.py --json /tmp/audit-final.json` —
   `brokenLinks` empty; both manifest counts unchanged; no budget in warning.
2. `bash tests/test-ai-install-skills.sh` — the skill installer must still pass
   after the skill-body edits.
3. Update `docs/github-spec-kit-evaluation.md` §4 to record what actually
   shipped, and this plan's STATUS table to `✅ done` per step, dated.
4. Write your own new `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md`. If every
   step is done and verified, **delete**
   `HANDOFF.d/2026-08-13T1003Z-ccweb-claude-spec-kit-evaluation.md` in the same
   commit (the retention rule in `handoff-standard.md`), and only then may this
   plan file migrate into `specs/` per D2.

*Verification gate:* all three commands green, STATUS table has no `⬜ open`
rows, and `git status` is clean after the final commit.

## 10. Tests required

This repo has no application test suite — `tests/` holds dependency-free Bash
and PowerShell **installer-behaviour** tests. There is no CI, so every check is
run by hand.

| Check | Command | Must show |
|---|---|---|
| Context/link audit | `python3 tools/context-audit/context-audit.py --json <out>` | `brokenLinks` empty; no budget entry in warning |
| Manifest immobility | same run, `skillManifest` | Claude 21,521 and Codex 13,943, unchanged from baseline |
| Skill installer | `bash tests/test-ai-install-skills.sh` | pass |
| Installer parity | `bash tests/test-installer-parity.sh` | pass (regression guard; this plan should not affect it) |
| Rename integrity | `git status --short` after step 2 | 11 `R` lines, zero `D`+`A` pairs |

No new automated test is required: the audit tool already enforces the two
things this plan could plausibly break (broken links, manifest growth). If you
add a `tasks.md` schema check, add it to `tools/context-audit/` rather than
inventing a new tool — but that is optional and not part of the definition of done.

## 11. Constraints, standing rules, and gotchas in force

- **Branch:** work on `claude/github-spec-kit-evaluation`. Never commit to `main`.
  Push with `git push -u origin claude/github-spec-kit-evaluation`; on network
  failure retry up to four times with 2s/4s/8s/16s backoff.
- **Commits:** this repo pushes with a GitHub `@users.noreply.github.com` email
  (email-privacy protection blocks the private gmail address). End every commit
  message with the `Co-Authored-By: Claude Opus 4.8` trailer. Commit only what
  this plan covers.
- **Never raise a budget in `tools/context-audit/budgets.json`** to silence a
  warning. If you are over, shorten your prose.
- **Zero skill-manifest headroom.** Never edit a `SKILL.md` `description:` or
  `name:` in this plan. Bodies only.
- **136 bytes of `startupRoutedBytes` headroom** across `AGENTS.md` +
  `CLAUDE.md`, and step 3 already spends ~100 of them. Every router edit competes
  for what is left. Prefer backticks over Markdown links in router rows.
- **Never edit another session's `HANDOFF.d/` file** — not to fix a link, not to
  tidy. Write your own file and note the issue there.
- **Never rewrite root `HANDOFF.md`.** Line 1 carries `handoff-pointer: v1`; it
  is a static pointer.
- `HANDOFF.d/` currently holds **6 files**, over the standard's threshold of 5.
  The threshold warning is Albert's call, not yours — it is raised in §0 of the
  companion handoff. Do not delete anyone else's file to get under it.
- **Do not mention or use Fable.** Planning and final review use Opus 4.8 at high
  reasoning. There is deliberately no Fable slot.
- Toolkit home is `/worksp/ai-devops` — **never** `/opt/ai-devops`.
- Real config lives in `/etc/ai-devops/*.env` and is never committed; only
  `*.env.example` belongs in git. This plan touches neither.
- **Every new skill goes in `skills/shared/` by default** — but this plan creates
  no skills at all (§7 R2), so the rule only matters if you are tempted to.
- `git mv`, not `mv`. Rename detection is what preserves the plan archive.
- Do not open the `.jsonl` files under `codex_chats/` or `transcripts/`. They may
  contain live secrets and this repo is public.
- Reviews never fix what they find. The converge check reports; it does not edit.

## 12. Access and environment

- **Everything in this plan is local file editing plus two Python/Bash scripts.**
  No credential, model call, MCP server, or network access is required.
- `python3` must be on PATH for `tools/context-audit/context-audit.py`
  (Python 3.11+; the container used on 2026-08-13 had 3.11).
- `git` with push access to `u2giants/ai-devops`.
- No secrets are involved. If you nonetheless need one, it lives in 1Password
  account `popcreations.1password.com`, vault `vibe_coding`, referenced as
  `op://vibe_coding/<title>/<field>` — **by location only, never by value.**
- **Grok/GLM/Kimi are not needed to execute this plan.** If you want a
  second-opinion review of the finished work, `bin/ai-grok-review` is the only
  supported path to Grok and it only exists on a machine where the toolkit is
  installed (`hetz`, `t16`). Read the STEP 0 VERIFICATION header at the top of
  that script first; note it pins `grok-4.5` by default, so a 4.6 review needs
  `AI_GROK_MODEL` set **at session creation** (the model is fixed per session by
  design) and the id confirmed with `grok models` rather than assumed.
- Running the pipeline itself would need `/etc/ai-devops/models.env`, but this
  plan never invokes a stage — it only edits the prompts.

## 13. Definition of done + risks and open questions

**Done means all of:**

- [ ] Steps 1–13 complete, each verification gate passed.
- [ ] 11 plans live under `specs/NNN-<slug>/plan.md`; exactly three
      `plan_*.md` remain in the root (two exclusions + this plan).
- [ ] `implementation-plan-standard.md` and `implementation-plan-writer/SKILL.md`
      both describe `spec.md` / `plan.md` / `tasks.md` and agree with each other.
- [ ] `templates/prompts/00-clarify.md` exists and is listed in both
      `ai-development-pipeline/SKILL.md` and `docs/architecture.md`.
- [ ] `fresh-session/SKILL.md` carries the repo-level converge check;
      `templates/delegation/debate-turn.md` carries the completion-claim gate.
- [ ] Context audit: `brokenLinks` empty, both manifests unchanged, no budget
      warning.
- [ ] `tests/test-ai-install-skills.sh` and `tests/test-installer-parity.sh` pass.
- [ ] This plan's STATUS table updated; `docs/github-spec-kit-evaluation.md` §4
      records what shipped.
- [ ] Committed and pushed to `claude/github-spec-kit-evaluation`; a new
      `HANDOFF.d/` file written and the companion handoff deleted if truly done.

**Risks and rollback**

| Risk | Mitigation / rollback |
|---|---|
| A missed reference leaves a dead link to a moved plan | The step 3 grep gate catches it. Rollback: `git revert` the phase-1 commit — the renames are one isolated commit for exactly this reason. |
| The step 3 path rewrites push `startupRoutedBytes` over 35,972 | Measured: +100 bytes against 136 available, so it fits with 36 spare — but only if no other prose is added to `AGENTS.md`/`CLAUDE.md` in phase 1. If it warns, shorten the Spec Kit doc-map row. Never raise the budget. |
| A `SKILL.md` front-matter edit slips in and breaches the Claude manifest | The step 7 and 11 gates compare exact byte counts (21,521 / 13,943). Revert the front matter. |
| The standard becomes so heavy that `tasks.md` is written for trivial work | Step 6 requires an explicit "only when delegated or multi-phase" carve-out. |
| A future session migrates an excluded plan and breaks another session's handoff | D2 states the rule; step 1 re-derives the exclusion list from `HANDOFF.d/` rather than trusting this file. |
| Two trackers (STATUS table and `tasks.md`) drift apart | Step 6's gate requires the standard to reconcile them explicitly. |

**Open questions**

1. **D8** — should `specs/` be listed in `.claudeignore`? Default no. Raise it
   with Albert if the audit flags growth.
2. **D9** — extra `tasks.md` columns beyond the required six. Implementer's call.
3. **Not blocking, needs Albert:** no second model has reviewed this. Grok was
   requested on 2026-08-13 but is unreachable from a Claude-on-the-web container.
   Recommendation: run `ai-grok-review new spec-kit-eval` on `hetz` before
   starting phase 2, since phases 2–4 change standards that every future session
   follows. Phase 1 is mechanical and safe to run regardless.
4. **Follow-on, not in scope:** when
   `plan_context-engineering-consolidation.md` closes, it migrates too — and
   `tools/context-audit/context-audit.py:571` must be updated in the same commit
   (finding 5).

---

## Self-audit (run 2026-08-13, before this plan was shown)

Graded against the comprehensiveness checklist in
`templates/system/implementation-plan-standard.md`. All items pass.

- **All 13 sections present** — §1–§13 above, none omitted.
- **Ultimate goal in plain business English, up top, with goal-wins** — §1,
  including the explicit "the goal wins — stop and flag it" line and the
  anti-drift note that installing spec-kit is not the goal.
- **Rejected approaches with reasons** — §7, seven entries (R1–R7), each with the
  measurement or rule that killed it.
- **Every step names concrete files and has a verification gate** — §9; all 13
  steps carry an italicised gate, and steps 1–4 carry runnable commands.
- **Locked vs open decisions labelled** — §8, D1–D7 LOCKED, D8–D9 OPEN.
- **Explicit out-of-scope list** — §4, ten exclusions.
- **Tests specified by name** — §10, five named checks with commands and
  expected output; §12 explains why there is no CI to run them.
- **Terms/paths/identifiers defined** — §2 defines the repo, hosts, branch, and
  workflow; §5 gives the measured baselines; §6 cites `file:line` for every
  finding.
- **Secrets by location only** — §12 names account, vault, and reference form
  with no values.
- **Definition of done includes commit/push verification** — §13.
- **Plan ↔ handoff links both directions** — this file links to
  `HANDOFF.d/2026-08-13T1003Z-ccweb-claude-spec-kit-evaluation.md` at the top;
  that file links back.

**Q1 — Could a brand-new session with no project knowledge and no context from
this conversation execute this to perfection, without asking anything?**
Yes. §2 supplies the project from zero; §5 gives the exact starting state with
measured numbers; §9 gives ordered steps with runnable commands and gates; §11
front-loads the standing rules (branch, commit trailer, budgets, handoff
write-once, no Fable, `/worksp` not `/opt`) so none must be inferred. The two
genuinely open decisions are labelled OPEN in §8 with criteria, and the one item
needing Albert is flagged in §13 as non-blocking for phase 1.

**Q2 — Does it carry every piece of background, nuance and reasoning I hold,
including what was ruled out and why?**
Yes. §6 records all eight measurements, including the three that changed the
design: zero Claude-manifest headroom, manifest counting only front matter, and
the `HANDOFF.d/` write-once collision. §7 R2 explicitly records that this plan's
own originating suggestion — a new `plan-converge` skill — was wrong on
measurement, so the implementer cannot "helpfully" reinstate it. §6 findings 5
and 7 name two edits that look required and must **not** be made.

**Q3 — Is the ultimate goal clear enough that the implementer could make a
correct judgment call if a step turns out to be wrong?**
Yes. §1 states the three concrete post-conditions in business terms and names the
failure being fixed (a delegate handed 80 KB reporting partial success), so a
step that does not serve delegation-by-task-ID, repo-derived remaining work, or a
legible root can be recognised as wrong. §1 also names the specific drift to
watch for: sliding back toward installing spec-kit.
