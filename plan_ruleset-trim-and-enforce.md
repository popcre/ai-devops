# Plan — trim and enforce the always-loaded AI ruleset

Issue: [popcre/ai-devops#1881](https://github.com/popcre/ai-devops/issues/1881) ·
Handoff: [HANDOFF.d/2026-10-20T1400Z-edge-dev3-claude-ruleset-trim-plan.md](HANDOFF.d/2026-10-20T1400Z-edge-dev3-claude-ruleset-trim-plan.md) ·
Evidence (private, not in Git): `~/Dropbox/ai/chat_transcripts/_audit/ruleset-audit-2026-10-20.md`

## STATUS (read first — do not re-derive or re-plan)

| Step | State | Date | Evidence |
|---|---|---|---|
| 1.1 List valid task-gate classes in every global | ⬜ open | — | — |
| 1.2 Retire `shared-db-orchestrator` global mention and skill | ⬜ open | — | — |
| 1.3 Installed-global drift check | ⬜ open | — | — |
| 2.1 PR-wait polling hook (Claude PreToolUse) | ✅ done | 2026-10-20 | `6303e108`; `tests/test-ai-pr-poll-guard-hook.sh` 28/28 |
| 2.2 `ai-pr-wait` single run fits a 10-minute tool call | ⬜ open | — | — |
| 3.1 One source for the Codex/ZCode/MiMo globals | ⬜ open | — | — |
| 3.2 Trim the Claude + Codex global rules to ~1,200 words | ⬜ open | — | — |
| 3.3 Move dated owner rulings to `docs/owner-rulings.md` | ⬜ open | — | — |
| 4.1 AGENTS.md down to a router under 2,000 words | ⬜ open | — | — |
| 5.1 Minimal instruction profile for reviewer runs | ⬜ open | — | — |
| 6.1 Live proof: re-run the transcript audit | ⬜ open | — | — |

**Start here:** Phase 1, step 1.1. Each phase is one PR. Phases 1, 2 and 5 are
independent and can run in parallel sessions. Phase 3 must precede phase 4 (both
edit routing text), and phase 6 runs last, at least 7 days after phases 1–3 are
installed on edge-dev3, edge-dev and al8960ofc.

---

## Part 1 — Why

### 1. The ultimate goal

Albert runs POP Creations with AI agents (Claude Code, Codex, ZCode, MiMo, and
reviewer engines) doing nearly all engineering. Every one of those sessions starts
by loading a block of standing rules. Today that block is about **8,000 words**.
It is long enough that agents skip the short rules, partly stale, and in places
contradictory between machines. The goal is simple: **agents actually obey the
rules that matter, and spend less money and attention on the ones that don't.**
When this is done:

- A session loads roughly half the standing text it loads today.
- The rules that cause real damage when broken are enforced by tooling (a hook or
  a script refusal), not by hope.
- Rare-task rules live in skills/docs that are loaded only when that task happens.
- Every machine runs the same, current rules.

**If a step conflicts with this goal, the goal wins — stop and flag it on #1881.**
In particular: never delete a safety rule to save words. Move it behind a pointer,
or enforce it with a tool. Only remove a rule when it is superseded or provably
unused, and name it in the PR body.

### 2. What this application is

`popcre/ai-devops` (this repo) is Albert's AI toolkit: the global instruction
templates, skills, reviewer wrappers, gates (`bin/ai-task-gates`), hooks, and the
installer that pushes all of it onto every machine. It is not a web app; "deploy"
means the protected install (`update.sh`, see `docs/deployment.md`) running on each
machine. Machines in use: edge-dev3 (Ubuntu, main dev box), edge-dev and al8960ofc
(Windows), hetz (Ubuntu VPS, user `ai`). Machine facts:
`templates/system/machine-atlas.md`.

Files in scope ("instruction files"):

| File | Loaded by | Words (2026-10-20) |
|---|---|---|
| `templates/system/CLAUDE-global.md` → `~/.claude/CLAUDE.md` | every Claude Code session | 2,648 |
| `templates/system/AGENTS-global-codex.md` → `~/.codex/AGENTS.md` | every Codex session | 3,084 |
| `templates/system/AGENTS-global-zcode.md` | ZCode | 3,084 |
| `templates/system/AGENTS-global-mimo.md` | MiMo | 3,217 |
| `AGENTS.md` (repo root) | every session in this repo | 4,762 |
| `CLAUDE.md` (repo root) | Claude in this repo | 155 |
| `templates/repo-docs/*.addon.md` | appended into other repos' AGENTS/CLAUDE | ~420 |
| `docs/standing-rules-details.md` | on demand (already the "details" doc) | 1,212 |

Installation: `bin/ai-install-skills --adopt-globals` and `bin/ai-adopt-globals`
copy the templates, then **interleave a machine section** (machine atlas plus a
local standing block) into the installed copy (`bin/ai-adopt-globals` ~line 121).
So the installed copies are *expected* to differ from the templates by that
machine section, and only by it.

### 3. What triggered this work

On 2026-10-20 Albert asked whether sessions obey our rules. Evidence came in two
passes:

1. `headroom learn` on hetz found agents repeating mistakes our rules already
   forbid. 3 of the 4 most recent hetz sessions in `/worksp/ai-devops` polled PRs
   with `sleep N; gh pr view` loops instead of `bin/ai-pr-wait`.
2. A 103-transcript audit followed (ScaleDown Compress + Summarize, then direct
   counts): 44 interactive sessions and 59 automated reviewer runs, from
   2026-09-25 to 2026-10-20. The full report is the private evidence file linked
   above. It must stay out of Git because it quotes private transcripts.

Albert's question was "do we have too many rules?". The answer was yes.

### 4. Scope

In scope: the instruction files listed in §2, one new Claude hook, a small
`ai-pr-wait` change, the drift check, and the reviewer instruction profile.

**NOT in this plan:**

- Changing what any safety rule *requires*. This plan moves, shortens, or enforces
  rules. It never weakens one. Production, secrets, shared-db, and destructive-action
  rules keep their meaning exactly.
- Other repos' AGENTS.md files (shared-db, popdam3, designflow-*). Only the shared
  addon templates in `templates/repo-docs/` are in scope.
- Skill bodies (`skills/**/SKILL.md`), except retiring `shared-db-orchestrator` and
  pointer fixes.
- Memory files and the private memory hub.
- Headroom, ScaleDown, and the `headroom learn` workflow.
- Codex/ZCode hooks. Phase 2 is Claude-only, because Codex has no equivalent hook.
  Record that gap. Do not build a workaround.
- `CHATGPT-codex-cost-efficient.md`, `handoff-standard.md`, and
  `implementation-plan-standard.md`, which are loaded on demand.

---

## Part 2 — What we already know

### 5. Current state

Nothing in this plan has been started. The repo was at origin/main `9b24e2b5` when
this plan was written. Relevant existing pieces:

- Hooks installed into `~/.claude/settings.json`:
  - completion check (`bin/ai-completion-check-hook`, installer
    `bin/ai-install-completion-check-hook`);
  - memory index (`bin/ai-memory-index-hook`, installer `bin/ai-install-memory-hook`);
  - session tmp (`bin/ai-session-tmp-hook`).

  All are installed by `install.sh` stage "Claude closeout hook" (~line 650) and are
  idempotent and additive. Tests: `tests/test-ai-completion-check-hook.sh`,
  `tests/test-ai-memory-index-hook.sh`. The new hook follows exactly this pattern.
- `bin/ai-pr-wait` (line 18 usage) requires `--timeout-minutes N` with no default
  (#1183 child 3). Claude's Bash tool call is capped at 10 minutes, so sessions wrap
  it as `timeout 580 bin/ai-pr-wait N --timeout-minutes 9` in a loop. That loop is
  itself the failure.
- Task-gate classes live in `config/task-gates.json` → `change_classes`. They are:
  code, deployment, infrastructure, installation, private-evidence,
  private-tooling, production, prose, reviewer-safety, shared-db,
  ui-live-workflow. The global rules say `--class <class>` and never list them.
- `skills/shared/shared-db-orchestrator/` still exists. The global rules still
  say "`shared-db-orchestrator` is optional reference only".
- Codex reviewer runs: `bin/ai-codex-review` already uses `--ignore-user-config`
  (line 288). But sampled Codex final-check/plan-review sessions under
  `~/.local/state/ai-devops/review-sandboxes/codex-*` still loaded the full global
  rules and a 13–14 entry connector-plugin list (Dropbox, Box, Figma, Gmail, Slack,
  Teams…). So those runs launch through another path, likely `bin/ai-review-engine`
  or `bin/ai-model-call`. Locating it is step 5.1's first task.

### 6. Key findings (from the audit; counts are over the 44 interactive sessions)

| # | Finding | Evidence |
|---|---|---|
| F1 | Hook-enforced rules hold; prose-only rules drift | completion hook corrected premature "done" in sessions 040 and 112; PR-wait polling loops in 11/44 (036, 039, 101, 109, 111–113, 116, 120–122) |
| F2 | Job-plan restatement rule followed in 7/44 | 040, 057, 059, 065, 069, 100, 107 |
| F3 | Task-gate class guessed and rejected in 6 sessions | 011, 061, 069, 119, 124, 125; guesses: analysis, review, medium, read-only |
| F4 | Installed globals stale vs template | edge-dev3 `~/.claude/CLAUDE.md` dated 2026-10-14 vs template commit `c9d7456c` 2026-10-16; doc-only-PR rule now says "never `--admin`" installed vs "merge with `--admin`" in the template |
| F5 | Superseded rules mislead | session 119 kept using the orchestrator after Albert said there is none; session 117 applied the old reviewer-per-DB-write rule |
| F6 | Reviewer runs carry the full owner ruleset + plugin list | ~40% of the sample; plugin list flagged irrelevant in 20+ summaries |
| F7 | AGENTS.md is router + reference mixed | largest sections: Specialized task router 1,102 words, Repository contract 930, Documentation map 355, Intentional quirks 345, Pending work 235, Data model 193 |
| F8 | Long task-specific global sections | Production infrastructure safety 183 words, Shared database 114, GPT-5.6 reasoning 84, installed-checkout `git pull` 55, Synology |
| F9 | Reply-style section mostly obeyed | "Still open" in 34/44, EST in 25/44 (UTC leaked in 2); overlength corrected in 115, 123 |
| F10 | Signature compliance unmeasurable | 18/20 inline posts truncated in the digest; leave the rule as is |

The counts come from the regex measurements described in the evidence file. Treat
them as sample estimates, not exact figures.

### 7. Approaches considered and rejected

- **Let `headroom learn --apply` maintain rules.** Rejected. Its preview rewrote and
  garbled `MEMORY.md` and wrote unreviewed text to `CLAUDE.local.md`.
- **Headroom shared memory.** Rejected 2026-10-20. It would create a second,
  unreviewed memory store next to the curated one.
- **Use ScaleDown's own synthesis as the recommendation list.** Rejected. It was
  shallow and partly garbled; it served only as a pointer.
- **Add more rules telling agents to obey rules.** Rejected. That is the failure
  mode this plan removes.
- **Hook-block every rule.** Rejected. Hooks are Claude-only and each one adds
  maintenance. Enforce only rules whose violation costs real time or money
  (PR polling). The rest are fixed by being short and findable.
- **Delete the job-plan rule outright.** Open (see §8). Albert wrote it on purpose.
- **Make `ai-pr-wait` default to unbounded.** Rejected. #1183 deliberately requires
  an explicit deadline.

### 8. Decisions

Locked (2026-10-20):

- Safety meaning is preserved verbatim in substance. Owner rulings keep Albert's
  exact quoted words, but in `docs/owner-rulings.md`; the global keeps a one-line
  current rule plus a pointer.
- One source of truth for the Codex/ZCode/MiMo globals. The per-engine differences
  (title line, signature env var such as `$CODEX_THREAD_ID`, engine-specific lines)
  are small overrides.
- Phase 2 is a Claude PreToolUse hook that blocks (exit 2 with a message), not a
  warning.
- The evidence file stays private, outside Git.

Open (implementer judgment, with criteria):

- **Job-plan rule (F2):** shorten it to 2 lines and keep it, *or* drop it. Keep it
  if Albert's corrections in the sample show he relied on it. In the sample, none
  of the 23 correction sessions complained about a missing plan, which favors a
  2-line version. Do not drop it without stating that on #1881.
- **Exact word targets:** ~1,200 for the globals and <2,000 for AGENTS.md are
  targets. Stop trimming before any safety meaning is lost.

---

## Part 3 — How to build it

Each phase is its own branch and PR from a fresh worktree off `origin/main`. Before
starting a phase, re-read the later phases (drift check). Mark STATUS rows as you go,
citing a commit SHA or test file. Never cite a bare number.

### Phase 1 — quick fixes (one PR)

**1.1 List task-gate classes.**
- Edit: the "Declare the task class" bullet in `templates/system/CLAUDE-global.md`,
  `AGENTS-global-codex.md`, `AGENTS-global-zcode.md`, and `AGENTS-global-mimo.md`.
- Add one line: `Classes: code, prose, private-evidence (read-only analysis),
  private-tooling, reviewer-safety, installation, deployment, infrastructure,
  production, shared-db, ui-live-workflow.`
- Generate the list from `config/task-gates.json` `change_classes` and add a test
  so the line can't go stale. Add the assertion to the existing template test
  (`grep -rl "CLAUDE-global" tests/` finds it); if none fits, create
  `tests/test-global-task-classes.sh` and register it in
  `config/ci-suite-manifest.json`.
- Also make `bin/ai-task-gates start` print the valid class list when it rejects a
  class, if it doesn't already.
- Done when: the test passes and an unknown class prints the list.

**1.2 Retire the orchestrator mention.**
- Remove the "`shared-db-orchestrator` is optional reference only" bullet from all
  four globals.
- Add `shared-db-orchestrator` to `config/retired-skills.txt` and delete
  `skills/shared/shared-db-orchestrator/`. The installer already handles retired
  skills recoverably; read `bin/ai-install-skills` for the retired list.
- Move any still-binding safety content from that skill into the `shared-db-change`
  skill. Diff the two first.
- Done when: `grep -rn shared-db-orchestrator templates skills AGENTS.md` returns only
  the retired-list entry and history docs, and the skills install test passes.

**1.3 Drift check.**
- Add a check to `bin/ai-adopt-globals --dry-run` (or a new `--check` flag). It
  compares the installed global to its template *with the interleaved machine
  section stripped* and exits non-zero on a difference.
- Wire it into the existing machine health report. Find that report with
  `grep -rn "ai-memory-health" bin`; it is the weekly report the memory hook header
  mentions.
- Done when: on edge-dev3 the check reports a difference before reinstall and is
  clean after. Test with a fixture home under `$TMPDIR`.

### Phase 2 — enforce PR waiting (one PR, independent of phase 1)

**2.1 Hook.**
- New `bin/ai-pr-poll-guard-hook` plus `.cmd` shim, matching the sibling hooks.
- New installer `bin/ai-install-pr-poll-guard-hook`, modeled on
  `bin/ai-install-memory-hook`: additive and idempotent, a PreToolUse hook with
  matcher `Bash`. Call it from `install.sh` beside the "Claude closeout hook" stage.
- Behavior: read the tool input JSON on stdin. Block (exit 2, with a stderr message
  naming `bin/ai-pr-wait <pr> --timeout-minutes N`) when the command matches any of:
  - `sleep` followed within the same command by `gh pr (view|checks|merge)` or
    `ai-gh pr`;
  - `until|while … gh pr (view|checks)`;
  - `seq … gh pr view`;
  - `timeout <N> …ai-pr-wait` inside a loop.
- Allow everything else, including a single `gh pr view` and `ai-pr-wait` itself.
- Done when: `tests/test-ai-pr-poll-guard-hook.sh` passes. It feeds JSON fixtures for
  every pattern above (block), plus single `gh pr view`, `ai-pr-wait 12
  --timeout-minutes 9`, and `sleep 5` alone (allow). Register it in
  `config/ci-suite-manifest.json`.

**2.2 One run fits one tool call.**
- Add `--fit-tool-call` to `bin/ai-pr-wait`. It caps the deadline at 9 minutes and,
  on timeout, prints one line: `STILL-WAITING pr=<n> state=<…> rerun: <same command>`.
- The explicit `--timeout-minutes` stays required (#1183).
- Update the global wait bullet to name exactly this form.
- Done when: a test with a stubbed `gh` (pattern in the existing ai-pr-wait test;
  `ls tests | grep pr-wait`) shows the cap and the rerun line.

### Phase 3 — trim the globals (one PR; after phase 1 merges)

**3.1 One source.**
- Make `templates/system/AGENTS-global-codex.md` the single body.
- Generate the ZCode and MiMo files by a small script, `bin/ai-render-globals`,
  from the body plus `templates/system/global-overrides/{zcode,mimo}.sed` or an
  equivalent tiny override file.
- Commit the rendered outputs (installers read them) and add a test that re-renders
  and diffs, so hand edits fail CI.
- Done when: the render test passes and rendered files differ from the body only in
  the override lines.

**3.2 Trim the Claude + Codex globals to ~1,200 words each.** For each section, in
this order:

1. **Move behind a pointer** (keep a 1-line "before X, load skill/doc Y"):
   - production infrastructure safety → `docs/standing-rules-details.md`;
   - shared database → `shared-db-change` skill;
   - Synology → `synology-long-running-operations` skill;
   - installed-checkout `git pull` rule → `docs/deployment.md`;
   - reviewer rotation → details doc;
   - GPT-5.6 reasoning → Codex/ZCode/MiMo only (drop from Claude).
2. **Shorten**: compress the reply-style block (~400 words → ~150) without dropping
   any rule. The 120-word limit, the Still-open format, the bullet prefixes, and no
   jargon stay.
3. **Job-plan rule**: apply the §8 decision.
4. **Dedupe**: merge "Wait on CI", "One status probe", and "A long wait leaves the
   card" into one wait bullet that names the phase 2 form.
5. **Owner rulings** → step 3.3.

Done when:
- `wc -w` meets the target;
- every removed sentence is listed in the PR body with its new home (pointer target)
  or the reason it was superseded;
- an assigned reviewer checks the PR body table for meaning loss.

**3.3 Owner rulings doc.**
- Create `docs/owner-rulings.md` holding each dated ruling verbatim: 2026-09-28
  "never ask a human to approve", 2026-10-02 shared-db promotion, 2026-10-14
  database writes, and any others found in the globals.
- Each global keeps the current rule in one line plus "(rulings:
  docs/owner-rulings.md)".
- Done when: a grep for each verbatim quote finds it in the rulings doc.

### Phase 4 — AGENTS.md router (one PR; after phase 3)

**4.1**
- Keep in AGENTS.md: project summary, documentation map, repository contract
  (shortened), task router, and the editing/delivery rules.
- Move to docs, linked from the documentation map:
  - "Intentional quirks" → `docs/design-decisions.md`, which already exists;
  - "Pending work" → a `docs/pending-work.md` index of plan links;
  - "Data model and external identifiers", "Credentials and environment", and
    "Critical incidents" (already summarized in `docs/incident-log.md`) to their
    topic docs.
- Done when: `wc -w AGENTS.md` < 2,000, every moved heading is still reachable
  from the documentation map, and the repo's docs-reachability check passes (find it
  with `grep -rn reachab tests bin | head`).

### Phase 5 — reviewer instruction profile (one PR, independent)

**5.1**
- First find the launch path for Codex final-check/plan-review and Grok reviews:
  `grep -rn "final-check\|plan-review" bin/ai-review-engine bin/ai-model-call
  bin/ai-review-lifecycle`. Confirm whether `~/.codex/AGENTS.md` and the plugin list
  are loaded. A one-word final-check run with `codex debug` or a saved transcript
  shows the developer messages.
- Then make those runs use a minimal instructions file,
  `templates/system/REVIEWER-global.md` (~200 words: read-only, quote the head SHA,
  verdict format, no remote actions, no secrets), with plugins/connectors disabled.
  Use Codex's own config switches for this, never by deleting the user's config.
- Done when: a fresh final-check transcript shows no owner reply-style rules and no
  plugin list, and the reviewer test suite for that path still passes.

### Phase 6 — live proof

**6.1**
- At least 7 days after phases 1–3 are installed on edge-dev3, edge-dev, and
  al8960ofc, re-run the audit. Use the same method: a random sample of ≥40
  interactive sessions from `~/Dropbox/ai/chat_transcripts/`, redaction, then counts.
- Success criteria:
  - PR polling loops ≤ 2/40;
  - task-gate class rejections 0;
  - no session acting on a superseded rule;
  - user corrections not higher than the baseline (23/44).
- Write the result to the private `_audit/` folder and post the counts (not quotes)
  on #1881.

### 10. Tests required

- New: `tests/test-ai-pr-poll-guard-hook.sh` (2.1), the ai-pr-wait fit test (2.2),
  the task-class list test (1.1), the drift-check test (1.3), and the
  global-render diff test (3.1).
- Must stay green: the full CI suite (`config/ci-suite-manifest.json`),
  `tests/test-ai-completion-check-hook.sh`, `tests/test-ai-memory-index-hook.sh`,
  the skills installer tests, and the docs safety/reachability checks.

### 11. Constraints and gotchas

- Work in your own worktree off fresh `origin/main`. Never edit `/worksp/ai-devops`
  or any installed checkout. Never `git pull` there (protected install,
  `docs/deployment.md`).
- Start with `ai-task-gates start --class prose` for phases 3–4, and `--class code`
  for phases 1, 2, and 5. Re-check before PR wait and installation
  (`ai-task-gates check --before <action>`).
- PRs go through the merge queue. A docs-only PR (phase 4 may qualify) follows the
  current doc-only rule *in the template*. Note the installed copy may be stale
  (F4); trust `templates/system/CLAUDE-global.md` on main.
- Code PRs need an assigned AI reviewer's APPROVE on the exact head (`ai-review`).
  Pick an in-rotation reviewer whose engine differs from yours.
- Windows: hooks need `.cmd` shims and must work under Git Bash. CRLF breaks bash
  scripts, so keep `.gitattributes` behavior. Test the hook's JSON parsing on
  Windows paths.
- `bin/ai-adopt-globals` interleaves a machine section. The drift check and render
  test must strip or ignore it, or they will always fail.
- Never quote transcript content in Git, PRs, or issues. Counts only.
- Time stamps for humans are in EST/EDT.
- Sign GitHub posts `Posted by <engine> chat <id> on <machine>`.

### 12. Access and environment

- `gh` is authenticated as the repo identity (`popcre`/`u2giants` per
  `config/repo-identities.tsv`). Use `bin/ai-gh` where the repo docs say so.
- Transcripts live in `~/Dropbox/ai/chat_transcripts/<machine>/` (on edge-dev3) and
  are private.
- The ScaleDown key (only if re-using the audit method) is in 1Password
  `vibe_coding` → "scaledown.ai API key for testing". Read it via the service-account
  token file `~/.config/ai-devops/op-service-account` when `op` has no signed-in
  account. Never print it.
- Install to a machine only through the protected install (`docs/deployment.md`)
  after merge.

---

## Part 4 — Landing it

### 13. Definition of done, risks, open questions

Done when:
- every STATUS row is ✅ with a SHA or test file;
- each phase PR is merged via the queue with green CI;
- the protected install has run on edge-dev3, edge-dev, al8960ofc, and hetz, and the
  drift check is clean on each;
- phase 6 meets its criteria and the #1881 checklist is ticked, including
  `live proof`;
- this plan and its handoff are updated or retired.

Risks and rollback:
- *A trimmed rule loses a safety meaning.* Mitigation: the PR body table maps every
  removed sentence to its new home, and a reviewer checks it. Rollback: revert the
  phase 3 PR; the installers restore from `~/.ai-globals-backup/`.
- *The hook blocks a legitimate command.* Mitigation: allow-list tests. Rollback:
  remove the hook entry (the installer is additive, so remove it by hand from
  settings) and revert.
- *Render script drift.* The CI diff test catches it.

Open questions:
- the job-plan rule (§8 criteria);
- whether Grok reviewer runs can take a minimal instructions file (5.1 finds out).
  If not, record it on #1881 as a known gap.

---

## Self-audit (2026-10-20)

1. *Could a brand-new session execute this without asking?* Yes. §1–4 give the goal,
   the application, the trigger, and the scope. §5 names the exact existing files and
   lines. §9 gives files, behavior, and a "done when" gate per step. §11–12 cover the
   rules and access. One gap found and fixed: the reviewer launch path is unknown, so
   5.1 now starts with the exact grep to find it.
2. *Does it carry all background, including what was ruled out?* Yes. §6 has the
   findings with session evidence, §7 the five rejected approaches, and §8 the locked
   and open decisions with criteria.
3. *Is the goal clear enough for judgment calls?* Yes. §1 states the outcome in
   business terms, the "goal wins" rule, and the specific guard (never delete a
   safety rule to save words).
