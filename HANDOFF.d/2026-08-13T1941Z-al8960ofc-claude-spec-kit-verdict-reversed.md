# HANDOFF — Spec Kit verdict reversed after two second opinions (2026-08-13 19:41 UTC, al8960ofc/claude)

Workstream: finish the `github/spec-kit` question. **This workstream is COMPLETE
and shipped.** This file exists to record two things a reader cannot get from the
diff: why a written, self-audited plan was thrown away, and what is deliberately
left undone.

- Binding decision: [`../docs/github-spec-kit-evaluation.md`](../docs/github-spec-kit-evaluation.md) **§8**
- The dropped plan, kept as a record only: [`../plan_spec-kit-idea-adoption.md`](../plan_spec-kit-idea-adoption.md)
- Reviews: [`../docs/grok-4.6-spec-kit-second-opinion.md`](../docs/grok-4.6-spec-kit-second-opinion.md),
  [`../docs/kimi-k3-spec-kit-tiebreak.md`](../docs/kimi-k3-spec-kit-tiebreak.md)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

### BLOCKING

None. Nothing is half-finished and nothing waits on an answer.

### RECOVERABLE

1. **No pull request was opened.** Branch `claude/github-spec-kit-evaluation` is
   three commits ahead of `main` and pushed. This repo's rule is main-only, so
   the branch exists because the *previous* session was told to use it, not
   because a review gate demands one. *Recommendation: merge it to `main`
   yourself — it is docs, templates, and skill text, with no runtime code.*

### NOT PART OF THIS WORK, AND NOBODY IS ON IT

2. **`HANDOFF.d/` holds 8 files including this one — well over the standard's
   threshold of 5.** This is the second consecutive session to raise it, which
   is itself the finding. Oldest first:

   | File | Date |
   |---|---|
   | `2026-08-12T1135Z-al8960ofc-codex-context-engineering-audit.md` | 2026-08-12 |
   | `2026-08-12T1959Z-al8960ofc-claude-glm-plan-closed-two-loose-ends.md` | 2026-08-12 |
   | `2026-08-12T2010Z-al8960ofc-claude-context-step4-globals-slimmed.md` | 2026-08-12 |
   | `2026-08-12T2101Z-al8960ofc-claude-context-step5-router-tightened.md` | 2026-08-12 |
   | `2026-08-12T2330Z-al8960ofc-claude-context-step6-codex-eval-sets.md` | 2026-08-12 |
   | `2026-08-13T0130Z-al8960ofc-claude-context-step7-installer-reconcile.md` | 2026-08-13 |
   | `2026-08-13T1003Z-ccweb-claude-spec-kit-evaluation.md` | 2026-08-13 |
   | *(this file)* | 2026-08-13 |

   **The `ccweb` file is now obsolete** — its §6 tells the next session to execute
   the plan this session dropped. I did not delete it: `handoff-standard.md:346`
   permits only the authoring session to delete, and that session is gone. That
   rule is the root cause of the pile-up; see §5.

   *Recommendation: delete the `ccweb` file and the `step4`–`step6` files.*

3. **A proposed fix for the pile-up was designed and NOT implemented.** See §5.
   It changes `handoff-standard.md`, which every session follows, so it wants
   Albert's yes first.

### Already settled — do NOT re-ask

- **Do not install `github/spec-kit`** (2026-08-13, unchanged from the first
  session and endorsed by both reviewers).
- **Do not execute `plan_spec-kit-idea-adoption.md`.** Superseded 2026-08-13.
  Its STATUS table carries a stop banner. Do not "helpfully" restart it at step 1.
- **Do not put the convergence check in `fresh-session`.** Rejected on measurement
  and on routing; see §4 item 2.

## 1. What this application is

`u2giants/ai-devops` (public GitHub repo) is a **backup-and-restore toolkit for a
multi-model AI coding workflow** — Bash CLI scripts, prompt templates, docs, and
skill scaffolding. It is not an application: no database, container, CI/CD, or
`.github/workflows`.

It installs `bin/ai-*` commands as symlinks in `/usr/local/bin` and drives a
seven-stage workflow (plan → plan-review → implement → diff-review → test →
security-review → final-review), each stage mapped to a different model command
from `/etc/ai-devops/models.env` by `bin/ai-model-call`. Claude/Opus plans and
reviews; Codex/GPT-5.5 implements and tests; Grok, GLM and Kimi are delegates
reached only through their `bin/ai-*` wrappers.

Toolkit home on every host is `/worksp/ai-devops` — never `/opt/ai-devops`. Real
config lives in `/etc/ai-devops/*.env` and is never committed. Users: Albert
(GitHub `u2giants`) and AI sessions. Read `AGENTS.md` first in any session.

## 2. What we set out to do this session, and why

The previous session (`ccweb`) evaluated Spec Kit and wrote a four-phase plan to
port five of its ideas. It could not run the second opinion Albert had asked for,
because a Claude-on-the-web container has no delegate CLI installed.

Albert reopened it here with four asks: run the Grok 4.6 review, pin the wrapper
to 4.6, propose a skill-manifest reduction, and fix two smaller defects. When Grok
came back against the plan, Albert said — in his words — *"i'm not a programmer and
not qualified to decide. ask Kimi K3 and follow the general consensus."*

So the deciding rule for this session was **consensus, not my own judgement.** That
matters for anyone reading the diff and wondering why a self-audited plan was
scrapped: it was not scrapped on one model's opinion.

Business goal behind all of it, unchanged: stop handing a delegate a 20–80 KB plan
and getting partial work back reported as complete.

## 3. Current state — what is true right now

**Everything below is committed and pushed** on `claude/github-spec-kit-evaluation`.

| Commit | What |
|---|---|
| `846cc37` | Verdict reversal + the two surviving changes + manifest trim |
| `622ebff` | CLAUDE.md trailer rule; `.ai/reviews/` git-ignored |
| *(this session's docs commit)* | `AGENTS.md` rows corrected; this handoff |

**Shipped and verified:**

1. **`plan_spec-kit-idea-adoption.md` is superseded.** Stop banner at the top; the
   STATUS table now marks each step deferred / dropped / done with the reason.
2. **`docs/github-spec-kit-evaluation.md` §8** is the binding decision. §5 is
   marked SUPERSEDED but kept.
3. **`templates/system/implementation-plan-standard.md` §9a** — the `tasks.md`
   contract. Required only for **new** plans that are multi-phase or delegated.
   Mirrored into `skills/shared/implementation-plan-writer/SKILL.md` (§9a block).
4. **`skills/shared/close-old-session/SKILL.md`** — new **Step 3a**, the
   convergence check, plus a `description:` extension so it actually triggers on
   "what is still left?" / "did the delegate finish?".
5. **Manifest trim** paid for that description. Long trigger lists moved from
   `description:` into skill bodies (nothing deleted, only relocated) in
   `shared-db-orchestrator`, `shared-db-handover`, `secrets-to-1password`,
   `codex-shared-db-change`, `handoff-writer`, `qwen-code`.
6. **`bin/ai-grok-review` pinned to `grok-4.6`**, confirmed via `grok models` on
   `al8960ofc` (grok 1.0.3, `1a29d5bc12`). 4.6 is the provider default; 4.5 still
   exists. The pin comment says to re-run `grok models` before ever changing it.
7. **`memory/ai-devops/phase3-plan-location.md`** is no longer Windows-only.
   Copied to the live `~/.claude/projects/C--repos-ai-devops/memory/` too.
8. **`CLAUDE.md`** trailer rule names the model that did the work instead of a
   hard-coded `Opus 4.8`. **`.gitignore`** gained `.ai/reviews/`.

**Measured, after everything:**

| Budget | Before | After | Limit |
|---|---|---|---|
| `claudeSkillManifestBytes` | 21,521 | **18,692** | 21,521 |
| `codexSkillManifestBytes` | 13,943 | 13,989 | 14,015 |
| `startupRoutedBytes` (LF-normalized) | 35,886 | **35,921** | 35,972 |

`brokenLinks` 0, `installedSourceDrift` 0, `installerParityDifferences` 0,
`safetyMarkerIssues` 0, `crossClientParityMismatches` 0. **No number in
`budgets.json` was raised.**

**Read this before you trust the audit output.** On Windows the audit reports
`startupRoutedBytes` ≈ 36,414 and prints a budget warning. That is a **checkout
artifact, not growth**: `core.autocrlf` adds one byte per line. `AGENTS.md` is
33,604 bytes in git and 34,008 on disk — a 404-byte delta across ~404 lines.
Verify with `tr -d '\r' < AGENTS.md | wc -c`. The real figure is in the table
above and it is under budget. Do not "fix" this warning by trimming further, and
do not raise the budget.

## 4. Everything we tried that did NOT work

1. **The original four-phase plan — written, self-audited, then rejected by two
   independent reviewers.** This is the single most important thing in this file.
   The plan passed its own comprehensiveness gate. Both reviewers still found its
   foundation wrong. A self-audit proves a plan is *complete*, not that it is
   *correct*. Do not treat a passed self-audit as a verdict.
2. **Putting the convergence check in `fresh-session`'s body — rejected as
   budget-gaming.** The manifest counts only `name` + `description`
   (`tools/context-audit/context-audit.py:512-516`), so a body edit is free. The
   first session used that to dodge a full manifest. Grok named it: skills are
   *selected* on the description and the body loads only after selection
   (`docs/context-engineering.md:102`); `fresh-session`'s description fires on
   "fresh session?" and "new context window?", never on "did the delegate
   finish?". The feature would have existed and never run. This repo had already
   paid for that exact lesson (`docs/context-engineering.md:312-326`). The honest
   fix was to free real bytes and add a real description — which is what shipped.
3. **Phase 1 (moving 11 root plans into `specs/`) — deferred, not done.** Its
   stated reason was to save later rewrites, but phases 2–4 never touch the moved
   files, so it saved nothing. It would have spent the last `AGENTS.md` router
   headroom while `plan_context-engineering-consolidation.md` (steps 8–10 open) is
   actively shrinking that same file, and it missed the ownership map at
   `docs/context-engineering.md:105`.
4. **The task-ID rationale did not survive its own citations.** The evaluation
   said `plan_kimi-incomplete-implementation-recovery.md` and
   `plan_glm-incomplete-implementation-recovery.md` proved delegates report success
   on partial work. Both describe runs that **correctly fail closed** and export a
   marked-incomplete patch, and both are closed. I verified this directly. The
   `tasks.md` contract still shipped because both reviewers endorsed it on its
   merits — but **the incident class used to justify it is undocumented in this
   repo.** If someone later asks for evidence, there is none yet.
5. **The stage-00 clarify gate — dropped as unrunnable.** `bin/ai-model-call:63-71`
   has no `clarify` stage and the plan explicitly refused to touch `bin/`. It
   would have added a prompt file no runner could invoke.
6. **`python3` does not exist on `al8960ofc`.** Use `py`. `python3` hits the
   Windows Store alias stub and fails with a message that reads like a missing
   install. The previous session's handoff says `python3` throughout.
7. **Trimming the manifest broke the *Codex* budget first.** `close-old-session`
   lives in `skills/shared/`, so its new description counted **twice**
   (`context-audit.py:507-509`). Codex had 72 bytes of headroom and went 319 over
   instantly. Fixed by trimming `secrets-to-1password`, `codex-shared-db-change`,
   `handoff-writer` and `qwen-code`. **Before touching any `shared/` description,
   check the Codex budget, not just the Claude one.**

## 5. Root causes and key findings

- **The pile-up in `HANDOFF.d/` is caused by a rule, not by sloppiness.**
  `handoff-standard.md:346` says only the authoring session may delete a file.
  Authoring sessions never come back. So nothing is ever deleted and every file
  reads as an open workstream forever. The `ccweb` file proves it: its next-steps
  section now actively misdirects, and no living session is allowed to remove it.

  **The proposed fix, designed this session and NOT implemented** (§0 item 3):
  1. **Deleting is not editing.** Allow any session to delete another's file once
     every gate in that file's own next-steps section verifiably passes. The
     write-once rule protects the *text* from being rewritten; git history remains
     the archive, so nothing is lost.
  2. **Require a machine-checkable "Done when" block** in every handoff, so a
     later session can *prove* completion rather than guess at it.
  3. **Make the 5-file threshold a real check in `context-audit.py`.** Today it is
     prose that nothing enforces — `grep -i handoff` over that script returns only
     `:76` and `:571`, neither of which counts files.
- **Manifest bytes count only front matter**
  (`context-audit.py:512-516`, `"\n".join(f"{name}: {description}")`). Bodies are
  free. This is a real property, and the honest use of it is relocating trigger
  lists — not hiding new behavior behind a description that cannot summon it.
- **Two skills held 22% of the Claude manifest.** `shared-db-orchestrator` (2,547
  bytes) and `shared-db-handover` (2,120), almost entirely trigger synonyms.
  Trimming the top few descriptions freed 2,829 bytes — far more than the "zero
  headroom" framing suggested was available. **Zero headroom was a prose problem,
  not a capacity problem.**
- **`startupRoutedBytes` covers only `AGENTS.md` + `CLAUDE.md`**
  (`context-audit.py:478-479`). Any router edit competes for ~50 spare bytes.
  Every edit in this session was paid back by shortening other prose there.
- **`plan_ai-glm-permission-failures.md` says CLOSED on line 14**, yet the first
  session used a handoff link to it as a reason to freeze its filename. A finished
  note was acting as a permanent lock on a record file.

## 6. Exact next steps

This workstream needs nothing. These are the leftovers, in priority order.

1. **Answer §0 items 1–3.** *You'll know it worked when the branch is merged or
   explicitly left open, and the `HANDOFF.d/` question has an answer.*
2. **Delete the obsolete `ccweb` handoff and the `step4`–`step6` files**, if Albert
   confirms. *You'll know it worked when `ls -1 HANDOFF.d/ | wc -l` returns 3 or
   fewer and no remaining file's next-steps section names a superseded plan.*
3. **If Albert approves §5's fix, implement it**: edit `handoff-standard.md`
   (delete-vs-edit rule + the "Done when" block) and add a file-count check to
   `context-audit.py`. *You'll know it worked when the audit prints a handoff
   count and warns above 5.*
4. **Do not restart the Spec Kit plan.** If phase 1 is ever revisited, it is
   blocked on `plan_context-engineering-consolidation.md` steps 8–10, and
   `docs/context-engineering.md:105` must be in the rewrite list.
5. **Re-run `py tools/context-audit/context-audit.py` after any doc edit**, and
   read §3's CRLF warning before believing the `startupRoutedBytes` line.

## 7. Constraints and gotchas in force

- Branch `claude/github-spec-kit-evaluation`, pushed. Never commit to `main`
  directly here without saying so first.
- Commit identity must be `Albert Hazan <u2giants@users.noreply.github.com>`.
  Confirm with `git var GIT_COMMITTER_IDENT` **before** the first commit — fixing
  it afterwards means rewriting history.
- Commit-message trailer names the model that actually did the work. `CLAUDE.md`
  used to hard-code `Opus 4.8`; that was corrected this session.
- **Never raise a number in `tools/context-audit/budgets.json`.** Shorten prose.
- **Before editing any `skills/shared/**` description, check the Codex budget too**
  — shared descriptions count in both manifests. See §4 item 7.
- **Never edit another session's `HANDOFF.d/` file**; **never rewrite root
  `HANDOFF.md`** (line 1 carries `handoff-pointer: v1`).
- Delegates are reachable **only** through their `bin/ai-*` wrappers. Never call
  `grok --single` / `-p` / `--resume` or `kimi -p` directly. Judge completion from
  the JSON `stopReason` (`end_turn` / `EndTurn`), never from exit status — that
  rule cost ~$1.28 in wasted runs on 2026-08-05.
- Use `py`, not `python3`, on this machine.
- **Do not mention or use Fable.** The absence of that slot is deliberate.
- Do not open `.jsonl` files under `codex_chats/` or `transcripts/` — may contain
  live secrets, and this repo is public.
- Reviews and the new convergence check report only; they never fix what they find.
- Commit only when asked. No PR unless Albert asks.

## 8. Access and environment

- **This work needs no credentials.** Local file editing, `py
  tools/context-audit/context-audit.py`, and git push access to `u2giants/ai-devops`.
- Ran on `al8960ofc` (Windows 11, user `ahazan2`, PowerShell 7 primary; Git Bash
  also available), in the git worktree
  `C:\repos\ai-devops-worktrees\github-spec-kit-evaluation-35279d`. The primary
  clone is `C:\repos\ai-devops`. There is no `/worksp` on this machine.
- Delegate CLIs confirmed present here: `grok` at
  `C:\Users\ahazan2\.grok\bin\grok`, `kimi` at
  `C:\Users\ahazan2\.kimi-code\bin\kimi`, wrapper `ai-kimi` at
  `~/.local/bin/ai-kimi`. Both wrappers needed `AI_GROK_BIN` / `AI_KIMI_BIN` set
  explicitly, because neither binary is on the default PATH here.
- Secrets, if ever needed: 1Password account `popcreations.1password.com`, vault
  `vibe_coding`, references `op://vibe_coding/<title>/<field>`. **Location only,
  never values.** None were needed or encountered this session.

## 9. Open questions and risks

- **The `tasks.md` contract has no evidence behind it yet** (§4 item 4). Both
  reviewers endorsed it on merit, but the failure it was sold as fixing is
  undocumented here. If it proves to be ceremony, delete it — that is not a defeat.
- **The convergence check is untested in anger.** It has a triggering description
  and a written procedure; nobody has yet run it against a real delegate handoff.
- **`HANDOFF.d/` will keep growing** until §5's rule change lands. This is the
  second session in a row to flag it.
- **Both manifests are near their limits again** after the trim: Codex has 26
  bytes spare, Claude has real room (2,829 freed). The next `shared/` skill will
  breach Codex first.
- **Decisions made this session, dated 2026-08-13**, so a later session does not
  contradict them: do not execute the spec-kit plan (evaluation §8); converge
  lives in `close-old-session`, not `fresh-session`; phase 1 deferred, not
  cancelled; `grok-4.6` is the wrapper default; the commit trailer names the real
  model.

---

## Self-audit (run 2026-08-13, before this handoff was shown)

Graded against `templates/system/handoff-standard.md`. All items pass.

1. **Could a street-newcomer continue without asking a question?** Yes. §1 explains
   the repo from zero; §3 states exactly what shipped, with commit SHAs and
   measured numbers; §6 gives ordered steps each with a verification gate; §7
   front-loads every standing rule; §8 gives the machine, the paths, and the two
   env vars the delegate wrappers need here.
2. **Could they continue as effectively as I can now?** Yes. The three findings
   that are invisible in the diff are written down with `file:line`: the manifest
   counts only front matter (`context-audit.py:512-516`), shared descriptions
   count twice (`:507-509`), and the CRLF artifact that makes the audit's own
   warning misleading (§3, with the command to verify it).
3. **Are the failed attempts included, with why?** Yes — §4, seven entries. Item 1
   is the one that matters: a plan passed its own self-audit and was still wrong.
   Item 7 is the trap that will bite the next person who trims a skill.
4. **Is every next step concrete and verifiable?** Yes — §6, five steps, each with
   a "you'll know it worked when" gate.
5. **Is every term, path, identifier and URL explained?** Yes — §1 the repo and
   workflow, §3 every budget name with its number, §8 the machine, worktree,
   binary paths and env vars.
6. **Was the §0 sweep actually run?** Yes, §1–§9 walked line by line. Promoted into
   §0: the unopened PR (§3 → item 1), the 8-file `HANDOFF.d/` with the obsolete
   `ccweb` file (§5 → item 2), and the designed-but-unimplemented rule fix (§5 →
   item 3). Items 2 and 3 are outside this workstream and nobody is on them —
   exactly the category the standard warns goes missing.

**Final synthesis.** (1) Comprehensive for a brand-new developer: yes. (2) Detailed
enough to continue as well as I could now: yes — §4 and §5 carry every non-obvious
finding with evidence. (3) Every relevant detail present: background §1–§2, state
§3, dead ends §4, findings §5, next actions §6, constraints §7, access §8, risks
and dated decisions §9. (4) If Albert read only §0, would he see every decision
needed from him, including out-of-scope ones? Yes — three items, one in-scope and
two that no other section would have escalated.
