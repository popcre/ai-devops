# HANDOFF — Spec Kit evaluation + adoption plan (2026-08-13 10:03 UTC, claude-code-web/claude)

Workstream: decide whether `github/spec-kit` benefits this repo, and specify the
adoption work. **Evaluation is finished; implementation has not started.**

- Decision record: [`../docs/github-spec-kit-evaluation.md`](../docs/github-spec-kit-evaluation.md)
- Implementation plan: [`../plan_spec-kit-idea-adoption.md`](../plan_spec-kit-idea-adoption.md) — read its STATUS table first

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put all of these to Albert in **one message** before starting work.

### BLOCKING

None. Phase 1 of the plan (moving 13 → 11 plan files into `specs/`) is mechanical
and can proceed on the strength of the plan alone.

### RECOVERABLE (a wrong guess is fixable but wastes rework)

1. **Do we actually want the five ported ideas?** The plan is written but nothing
   is executed. It changes the planning standard every future session follows.
   *Recommendation: yes — but run phase 1 (file moves) first and review the
   phase-2 standard edits before phases 3–4.*
2. **Should another model review this before phases 2–4?** Albert asked for a
   Grok 4.6 second opinion on 2026-08-13 and it could not be produced (see §4).
   Phases 2–4 rewrite standards, so a bad call there propagates.
   *Recommendation: yes — `ai-grok-review new spec-kit-eval` on `hetz` before
   phase 2. Phase 1 needs no review.*
3. **Should `specs/` be added to `.claudeignore`?** (plan D8.)
   *Recommendation: no — plans must stay readable on demand; moving files does not
   change what the router auto-loads.*

### NOT PART OF THIS WORK, AND NOBODY IS ON IT

4. **`HANDOFF.d/` holds 6 files — over the standard's threshold of 5.** The
   standard requires this be raised loudly and asks which are actually finished.
   Oldest first:

   | File | Date |
   |---|---|
   | `2026-08-12T1135Z-al8960ofc-codex-context-engineering-audit.md` | 2026-08-12 |
   | `2026-08-12T1959Z-al8960ofc-claude-glm-plan-closed-two-loose-ends.md` | 2026-08-12 |
   | `2026-08-12T2010Z-al8960ofc-claude-context-step4-globals-slimmed.md` | 2026-08-12 |
   | `2026-08-12T2101Z-al8960ofc-claude-context-step5-router-tightened.md` | 2026-08-12 |
   | `2026-08-12T2330Z-al8960ofc-claude-context-step6-codex-eval-sets.md` | 2026-08-12 |
   | `2026-08-13T0130Z-al8960ofc-claude-context-step7-installer-reconcile.md` | 2026-08-13 |

   Four of them (`step4`…`step7`) look like sequential steps of the single
   `plan_context-engineering-consolidation.md` workstream. *Recommendation: if
   that workstream is at step 7, the step4–step6 files are finished and should be
   deleted (git history keeps them). I did not delete them — the standard forbids
   touching another session's file.* Which are done?

5. **The Claude skill manifest is at 100% of its budget** — 21,521 of 21,521
   bytes (`tools/context-audit/context-audit.py`). This means **the next skill
   anyone adds anywhere breaches it**, and `budgets.json` forbids raising a budget
   to silence a warning. Codex has 72 bytes left. Nobody is on this.
   *Recommendation: schedule a `description:` trimming pass — `budgets.json`
   already targets 15,065 for Claude, roughly a 30% cut.*

6. **`memory/ai-devops/phase3-plan-location.md` hard-codes a Windows-only
   absolute path** (`C:\repos\ai-devops\plan_phase3-config-consolidation.md`,
   lines 3 and 12). It is a cross-machine memory file, so the path is wrong on
   every Ubuntu host. *Recommendation: make it repo-relative when plan step 3
   rewrites it anyway.*

7. **`bin/ai-grok-review` pins `grok-4.5`, but Albert asked for Grok 4.6.** The
   default may be stale. The model is fixed at session creation by design, so a
   4.6 review needs `AI_GROK_MODEL=grok-4.6` set on `ai-grok-review new`.
   *Recommendation: run `grok models` on `hetz` to confirm the real id, then
   decide whether to bump the default in the script.*

### Already settled — do NOT re-ask

- **Do not adopt `github/spec-kit` as a tool** (2026-08-13). Reasons in
  `docs/github-spec-kit-evaluation.md` §3.
- **Create no new skill directory for this work** (2026-08-13). Measured: zero
  Claude manifest headroom.
- **Do not move `plan_context-engineering-consolidation.md` or
  `plan_ai-glm-permission-failures.md`** (2026-08-13). Open `HANDOFF.d/` files
  link to them and no session may edit another's handoff.

## 1. What this application is

`u2giants/ai-devops` (public GitHub repo) is a **backup-and-restore toolkit for a
multi-model AI coding workflow** — Bash CLI scripts, prompt templates, docs, and
skill scaffolding. Not an application: no database, container, CI/CD, or
`.github/workflows`.

It installs `bin/ai-*` commands as symlinks in `/usr/local/bin` and drives a
seven-stage workflow (plan → plan-review → implement → diff-review → test →
security-review → final-review) where each stage maps to a different model
command from `/etc/ai-devops/models.env`. Claude/Opus plans and reviews;
Codex/GPT-5.5 implements and tests; Grok, GLM and Kimi act as delegates.

Toolkit home on every host is `/worksp/ai-devops` — never `/opt/ai-devops`. Real
config lives in `/etc/ai-devops/*.env` and is never committed. Users: Albert
(GitHub `u2giants`) and AI sessions. Read `AGENTS.md` first in any session.

## 2. What we set out to do this session, and why

Albert asked, in his words, "Would this benefit us: https://github.com/github/spec-kit?"
— then asked for it written up as `docs/github-spec-kit-evaluation.md` plus an
implementation plan covering **all** the recommended items, on branch
`claude/github-spec-kit-evaluation`.

Business goal: stop handing delegate models entire 20–80 KB plans and getting
back partial work reported as complete. Spec Kit's task decomposition and
convergence checking address exactly that.

Nothing was broken and no incident triggered this. It is an evaluation of an
external tool plus a specification for improving the planning machinery.

## 3. Current state — what is true right now

**Done and verified:**

- `docs/github-spec-kit-evaluation.md` — evaluation and decision record. Verdict:
  do not adopt the tool, port five ideas.
- `plan_spec-kit-idea-adoption.md` — 13-section implementation plan for all five
  items across four phases, with a STATUS table (every row `⬜ open`) and its
  self-audit answers preserved at the end.
- This handoff file.

All three are committed and pushed on branch `claude/github-spec-kit-evaluation`
(branched from `origin/main`). **No pull request was opened** — none was asked for.

**Not started:** every step in the plan. Steps 1–13 are all `⬜ open`. No file has
been moved, no template or skill edited.

**Measured baselines** captured this session with
`python3 tools/context-audit/context-audit.py` (re-run before starting work):

| Budget | Current | Limit | Headroom |
|---|---|---|---|
| `alwaysLoadedBytes` | 24,491 | 24,713 | 222 |
| `startupRoutedBytes` | 35,836 | 35,972 | 136 |
| `claudeSkillManifestBytes` | 21,521 | 21,521 | **0** |
| `codexSkillManifestBytes` | 13,943 | 14,015 | 72 |

`startupRoutedBytes` was 35,523 on `origin/main`; the two `AGENTS.md` rows added
this session cost 313 bytes. They were first written with Markdown links, which
cost 441 and left only 8 bytes — enough to make plan step 3 breach the budget — so
they were rewritten with plain backticks. Audit after the change: `brokenLinks` 0,
`safetyMarkerIssues` 0, both skill manifests unchanged, every budget `ok`.

Also measured: 13 root `plan_*.md` files, 434,656 bytes (`du -cb plan_*.md`), and
the step-3 path rewrites will cost `AGENTS.md` a further ~100 bytes of the 136 left.

## 4. Everything we tried that did NOT work

1. **Running a Grok 4.6 second opinion — failed, environment.** Albert asked to
   "run this by grok 4.6". This session is a Claude-Code-on-the-web ephemeral
   container, not one of his machines. Verified absent: `grok` (not on PATH, no
   `~/.grok`, not in npm globals), `ai-grok-review`, `op`, `codex`, `kimi`, and
   `/worksp` itself. No xAI credentials in the environment. There is no way to
   reach Grok from here — it must be run on `hetz` or `t16`, where the toolkit is
   installed. **This is still owed** (§0 item 2).
2. **Ordering `specs/NNN-*` chronologically by git add-date — abandoned.** All 11
   migrating plans share one add-commit (`2026-08-12T17:01:21-04:00`) in this
   clone, so `git log --diff-filter=A` produces no usable ordering. Switched to
   alphabetical-by-slug, which is deterministic. The exact mapping is baked into
   plan step 2 so nobody re-derives it.
3. **Creating a `skills/shared/plan-converge/` skill — designed, then killed on
   measurement.** This was the natural design and the one first suggested to
   Albert in chat. Then `context-audit.py` showed `claudeSkillManifestBytes` at
   21,521/21,521 — zero headroom — and `budgets.json` says never raise a budget.
   A `shared/` skill adds its `name: description` to *both* manifests
   (`context-audit.py:507-509`), roughly 370 bytes. Replaced with a body-only
   extension of the existing `fresh-session` skill, which costs zero manifest
   bytes because the manifest renders only front matter
   (`context-audit.py:512-516`). Recorded as R2 in the plan so a future session
   cannot helpfully reinstate it.
4. **Planning to move all 13 root plans — narrowed to 11.** Six `HANDOFF.d/`
   files link to `plan_*.md` paths, and `handoff-standard.md` forbids editing
   another session's handoff file, so those links could never be repaired. Only
   two distinct plans are affected, so those two stay at root.
5. **Writing the two new `AGENTS.md` rows as Markdown links — reverted.** The
   link form (`[\`path\`](path)` duplicates every path) cost 441 of the 449
   available `startupRoutedBytes`, leaving 8 bytes. Plan step 3 then rewrites 10
   `plan_*.md` paths in `AGENTS.md` to longer `specs/NNN-*/plan.md` ones, a
   measured +100 bytes — so the link form would have breached the budget during
   phase 1, and `budgets.json` forbids raising it. Rewritten with plain backticks
   (the style `AGENTS.md` already uses on most rows) for 313 bytes, leaving 136.
6. **Assuming `context-audit.py:571` needed updating — it does not.** It
   hard-codes `plan_context-engineering-consolidation.md`, which is one of the two
   excluded plans. Written into the plan as an explicit "do not touch" so an
   implementer does not make a well-meaning wrong edit.

## 5. Root causes and key findings

- **Spec Kit overlaps this repo by roughly 80%, and loses on the overlap.**
  `templates/system/implementation-plan-standard.md` (13 sections, self-audit
  gate) is stricter than `/speckit.plan`. Spec Kit has no concept of stage→model
  routing (`bin/ai-model-call`), independent read-only review gates (stages 02,
  04, 06), or concurrent-agent handoff (`HANDOFF.d/`). It therefore cannot
  replace the pipeline — at best it feeds it. Detail in the evaluation doc §2.
- **The five genuinely portable ideas** are task-ID decomposition, a convergence
  check, spec/plan separation, per-topic directories, and a clarify gate.
  Evaluation doc §4.
- **`claudeSkillManifestBytes` = 21,521 / 21,521.** Zero headroom. This is the
  single most consequential finding in the session — it reshaped the converge
  design and it will block the *next* skill anyone adds, anywhere.
- **Manifest bytes count only front-matter `name` + `description`**
  (`context-audit.py:512-516`, `"\n".join(f"{name}: {description}")`). Skill body
  edits are free. This is the loophole the whole of phase 4 relies on.
- **`startupRoutedBytes` covers only `AGENTS.md` + `CLAUDE.md`**
  (`context-audit.py:478-479`), with 449 bytes spare. Router edits compete for it.
- **`plan_standardized-saved-views.md` does not exist in this repo.** Referenced
  from two `memory/dflow-plm/` files; it belongs to the **dflow** repo. Confirmed
  absent with `ls`. Those references must be left alone — rewriting them would
  point dflow memory at a nonexistent `ai-devops` path.
- **13 root plan files, 424 KB.** The clutter is real and measurable, which is
  what makes the per-topic-directory idea worth porting even though moving files
  does not by itself reduce loaded context.

## 6. Exact next steps

1. Put the whole of §0 to Albert in one message. *You'll know it worked when he
   has answered items 1–7, especially whether to run the Grok review first.*
2. Execute `plan_spec-kit-idea-adoption.md` starting at **step 1**, phase by
   phase. Do not start phase 2 before phase 1's gates pass. *You'll know phase 1
   worked when `git status --short` shows 11 `R` lines, `ls -1 plan_*.md` lists
   exactly three files, and the step-3 grep returns only the four permitted plan
   names.*
3. Commit phase 1 on its own so the renames are reviewable in isolation. *You'll
   know it worked when `git log --stat` shows the renames as one commit.*
4. Re-run `python3 tools/context-audit/context-audit.py` after every phase.
   *You'll know it worked when `brokenLinks` is empty, both manifest counts are
   unchanged (21,521 / 13,943), and no budget entry is in warning.*
5. Update this plan's STATUS table in the same session that executes any step —
   a partially-executed plan lies to the next reader.
6. When all 13 steps are done and verified, write your own `HANDOFF.d/` file,
   delete **this** file in the same commit, and only then migrate
   `plan_spec-kit-idea-adoption.md` into `specs/`.

## 7. Constraints and gotchas in force

- Branch `claude/github-spec-kit-evaluation`. Never `main`. Push with
  `git push -u origin claude/github-spec-kit-evaluation`; retry network failures
  four times with 2s/4s/8s/16s backoff.
- Commits push with a GitHub `@users.noreply.github.com` email (email-privacy
  protection blocks the private gmail address). End messages with the
  `Co-Authored-By: Claude Opus 4.8` trailer. Commit only when asked.
- **Never raise a number in `tools/context-audit/budgets.json`.** Shorten prose
  instead.
- **Never edit a `SKILL.md` `name:` or `description:`** during this work — zero
  manifest headroom. Bodies only.
- **Never edit another session's `HANDOFF.d/` file**, not even to fix a link.
- **Never rewrite root `HANDOFF.md`** — line 1 carries `handoff-pointer: v1`.
- `git mv`, not `mv` — rename detection is the plan archive.
- **Do not mention or use Fable.** Planning and final review use Opus 4.8 high
  reasoning; the absence of a Fable slot is deliberate.
- Do not open `.jsonl` files under `codex_chats/` or `transcripts/` — may contain
  live secrets, and this repo is public.
- Reviews never fix what they find; the converge check reports only.
- No PR unless Albert asks.

## 8. Access and environment

- **This work needs no credentials.** It is local file editing plus
  `python3 tools/context-audit/context-audit.py` and two Bash tests under
  `tests/`. Python 3.11+ and `git` push access to `u2giants/ai-devops` are the
  only requirements.
- **Grok/GLM/Kimi are not needed to execute the plan.** For the outstanding
  second opinion, `bin/ai-grok-review` is the **only** supported path to Grok
  (never call `grok --single` / `-p` / `--resume` directly). Read the STEP 0
  VERIFICATION header at the top of that script first. It exists only where the
  toolkit is installed — `hetz` or `t16`.
- Secrets, if ever needed: 1Password account `popcreations.1password.com`, vault
  `vibe_coding`, references of the form `op://vibe_coding/<title>/<field>`.
  **Location only — never values.** Not required for this work.
- This session ran in an ephemeral Claude-Code-on-the-web container (hostname
  `vm`, no `/worksp`, no toolkit installed), which is why the machine field in
  this filename is `ccweb`.

## 9. Open questions and risks

- **Unreviewed by a second model.** The verdict is one model's judgement. §0
  item 2 recommends fixing that before phase 2.
- **Standards changes propagate.** Phases 2–4 edit
  `implementation-plan-standard.md`, `implementation-plan-writer/SKILL.md`,
  `fresh-session/SKILL.md`, `02-opus-plan-review.md`, and
  `templates/delegation/debate-turn.md` — every future session follows these. A
  wrong call is cheap to revert in git but expensive in habit.
- **Budget pressure is the main technical risk.** Two of four budgets are
  effectively full. Any step that adds prose to `AGENTS.md` or front matter to a
  skill can breach one. Every affected step in the plan carries a byte-count gate.
- **Two trackers could drift.** The plan standard's STATUS table and the new
  `tasks.md` both track progress; plan step 6 requires the standard to reconcile
  them explicitly.
- **Decisions made this session, dated 2026-08-13**, so a later session does not
  contradict them: do not adopt spec-kit (evaluation doc §3, §5); no new skill
  directory (plan §7 R2); exclude handoff-referenced plans from migration (plan
  §8 D2); alphabetical NNN (plan §8 D5); converge appends and never trusts a
  delegate's claim (plan §8 D6, D7).

---

## Self-audit (run 2026-08-13, before this handoff was shown)

Graded against the comprehensiveness checklist in
`templates/system/handoff-standard.md`. All items pass.

1. **Could a street-newcomer continue without asking a single question?** Yes.
   §1 explains the repo from zero knowledge; §3 states exactly what exists and
   what does not; §6 gives ordered next steps each with a verification gate; §7
   front-loads every standing rule (branch, commit trailer, budgets, handoff
   write-once, no Fable, `git mv`) so none must be inferred; §8 confirms no
   credentials are needed.
2. **Could they continue as effectively as I can right now?** Yes. Every
   measurement taken this session is written down in §3 and §5, including the two
   that are not obvious from reading the code (zero manifest headroom; the
   manifest counting only front matter). The `file:line` references
   (`context-audit.py:478-479`, `:507-509`, `:512-516`, `:571`) let a newcomer
   re-verify each one directly.
3. **Are the failed attempts included, with why?** Yes — §4, five entries. The
   most important is item 3: the converge-as-new-skill design was killed by a
   measurement, and the plan records it as R2 so it cannot be reinstated by a
   future session acting on the same instinct.
4. **Is every next step concrete with a way to verify it worked?** Yes — §6, six
   numbered steps, each ending in an explicit "you'll know it worked when" gate.
5. **Is every term, path, identifier and URL explained?** Yes — §1 defines the
   repo, hosts, and workflow; §8 defines the environment and why the machine
   field is `ccweb`; §3 spells out every budget name with its number.
6. **Was the §0 sweep actually run?** Yes, walked §1–§9 line by line. Items
   promoted into §0 that live elsewhere: the Grok gap (§4 item 1 → §0 item 2),
   the `.claudeignore` question (plan D8 → §0 item 3), the six-file `HANDOFF.d/`
   threshold (§7 constraint → §0 item 4), zero manifest headroom (§3, §5 → §0
   item 5), the Windows-only memory path (§5 → §0 item 6), and the `grok-4.5`
   pin versus the 4.6 request (§4 item 1, §8 → §0 item 7). Items 5, 6 and 7 are
   outside this workstream and nobody is on them — exactly the category the
   standard warns goes missing.

**Final synthesis answers.** (1) Comprehensive enough for a brand-new developer:
yes — §1–§3 supply the project, the goal, and the exact current state. (2)
Detailed enough to continue as well as I could now: yes — §4 and §5 carry every
non-obvious finding with `file:line` evidence. (3) Every relevant detail present:
yes — background §1–§2, state §3, dead ends §4, findings §5, next actions §6,
constraints §7, access §8, risks and dated decisions §9. (4) If Albert read only
§0, would he see every decision needed from him, including those outside this
workstream? Yes — verified by the line-by-line sweep in audit answer 6, which
promoted three out-of-scope items (5, 6, 7) that no other section would have
escalated.
