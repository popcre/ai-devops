# Handoff: ai-glm permission plan written, context step 2 verified, step 3 open

## 0. ⚠️ DECISIONS ONLY ALBERT CAN MAKE

Put this whole list to Albert in ONE message before starting work. Do not raise
these one at a time.

### Blocking — work should not proceed past them

None. Both open plans can start their next step without Albert.

### A wrong guess is recoverable, but rework is wasteful

1. **Which plan comes first: context step 3, or the GLM permission fix?**
   Recommendation: the GLM fix. It is six small steps in one file, and until it
   lands nobody can safely delegate the remaining context steps (4 through 7) to
   GLM's writing mode, which is the cheapest way to do them.
2. **Should `ai-glm implement` be allowed to run shell commands at all?**
   Recommendation: decide it from measurement, not now. This is open decision 1
   in `plan_ai-glm-permission-failures.md` section 8, and step 2 of that plan
   produces the evidence.

### Not part of this work, and nobody is on it

3. **Four old handoff files are still open in `HANDOFF.d/` and at least three
   look finished.** Recommendation: let a session delete the three superseded
   ones. Detail in section 9. Nobody owns this today, and the folder is at the
   five-file warning line.
4. **Two GLM implementation job records are stuck in a failed state**
   (`context-ownership-map-step2`, `popcrm-codebase-audit-remediation`).
   Recommendation: leave them until the GLM plan's step 6, which re-runs them on
   purpose as the proof the fix worked. Deleting them early destroys that test.

### Already settled — do NOT re-ask

- 2026-08-12: safety outranks token reduction in the context plan. Locked.
- 2026-08-12: no six-file convention, no graph database. Rejected with reasons in
  `plan_context-engineering-consolidation.md` section 7.
- 2026-08-12: the manual count of 14 duplicate paragraph groups is superseded by
  the tool's measured 12. Do not reopen.
- 2026-08-12: the ai-glm wrapper failing closed is correct behavior. The bug is
  that it discards its own diagnosis, not that it refused.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public toolkit for restoring and running
his multi-model AI coding setup: Claude Code, Codex, GLM, Grok, Kimi, DeepSeek,
plus shared skills, global instructions, MCP wiring, cross-machine memory, and
machine setup scripts.

It is Bash, PowerShell, and Markdown only. There is no application, database,
container, hosted service, or CI. "Green" means the local test suites named in
`docs/development.md`.

- Repo: `https://github.com/u2giants/ai-devops`, checkout `C:\repos\ai-devops`
- Branch policy: `main` only
- Machine used this session: `al8960ofc` (Windows 11 Pro, PowerShell 7 primary,
  user `ahazan2`)
- Router / canonical operating guide: `AGENTS.md`
- Claude adapter: `CLAUDE.md`

Albert is a business owner, not a programmer. He runs many short AI sessions, so
handoffs and plans are the memory that carries work forward.

## 2. What we set out to do this session, and why

Albert asked for four things, in this order:

1. Read `plan_context-engineering-consolidation.md` and its audit handoff, and
   report where the work stands.
2. Start the step 1 correction (a bug in the context-audit tool's parser).
3. Give step 2 of that plan to GLM 5.2 to implement.
4. After GLM's job failed: sweep leftover scratch folders, write an
   implementation plan for the GLM wrapper bug, and do step 2 by hand.

The business goal behind all of it: Albert's AI sessions start with several
thousand tokens of standing instructions before any real work begins. The
context-engineering plan shrinks that safely, without dropping a safety rule.

## 3. Current state — what is true right now

### Pushed and verified

- `main` is at `4dda7ff`, in sync with `origin/main` at the time of writing.
- **Context plan step 1 (baseline) is done**, including the correction. Commit
  `f13e4af` fixed the audit tool's YAML block-scalar parsing. Verified this
  session by running `pwsh -NoProfile -File tests/test-context-audit.ps1`, which
  printed a single PASS line covering classification, stable output, manifests,
  parity, safety markers, and secret exclusions.
- **Context plan step 2 (ownership map) is done**, commits `c83d937` and merge
  `59798e6`, done by a different Claude session by hand after GLM failed. I
  verified it rather than redoing it: the map is in
  `docs/context-engineering.md:71-193`, the router row is `AGENTS.md:49`, and
  both skills usage guides gained pointers plus the corrected Windows installer
  routing. I checked that every path the map cites actually exists on disk
  (`bin/ai-memory-sync`, `docs/mcp-1password-rate-limit-hardening.md`,
  `docs/cloud-build-prod-trigger-incident-2026-07-20.md`, `docs/skills-map.md`,
  and the two named memory files). All present.
- **New plan written and pushed:** `plan_ai-glm-permission-failures.md`, commit
  `4dda7ff`. Six steps, not started.
- **Empty GLM scratch folders swept.** Sixteen directories under
  `C:\Users\ahazan2\.local\state\ai-devops\glm\wt` contained zero files
  (verified recursively, including hidden). Deleted. `ai-glm doctor` now passes
  with no WARN line.

### Edited this session, NOT yet committed

`plan_context-engineering-consolidation.md` has three uncommitted edits made
during the fresh-session cutover check:

1. A new **end-of-phase reciprocal instruction** after the "Fresh-session start"
   block: when you finish a phase, re-read all remaining phases and record any
   drift before cutting to a new session.
2. A new constraint in section 11: do not delegate a step of this plan to
   `ai-glm implement` until the permission bug is fixed, with a pointer to the
   new plan. GLM **review** mode is explicitly still fine.
3. Step 3's target list now says `tests/test-context-audit.ps1` already exists
   (step 1 created it) and must be extended, not recreated.

**These three edits must be committed.** They are the only uncommitted tracked
work from this session.

### Not started

- Context plan steps 3 through 10. Step 3 (enforcement tooling and regression
  tests) is the next open row.
- All six steps of `plan_ai-glm-permission-failures.md`.

### Untracked and must stay untouched

`.ai/` (delegate review artifacts, deliberately untracked) and
`docs/claude-remote-control-hardening-v2.md` (another session's work).

## 4. Everything we tried that did NOT work

1. **Delegating context step 2 to `ai-glm implement` failed.** Job
   `context-ownership-map-step2` ran about eight minutes, edited three files,
   then the wrapper's permission gate killed it with
   `failure: permission-invalid-response`. The partial work was preserved as
   `.ai/reviews/glm-context-ownership-map-step2-20260812T162057Z.incomplete.patch`
   in the worktree `C:\repos\ai-devops-worktrees\context-ownership-map-c0be98`.
   Step 2 had to be finished by hand. **Do not retry this delegation until the
   GLM plan lands** — each attempt costs a paid provider turn.
2. **Hunting for the exact permission error in logs failed, and that is itself
   the finding.** `~/.local/state/ai-devops/glm/logs/` is empty,
   `%LOCALAPPDATA%\Temp\opencode` is empty, and the only copy of the real reason
   went to the stderr of the session that launched the job, which is
   unrecoverable. This is why the root cause of that specific failure is a
   hypothesis, not a fact, in the new plan.
3. **I initially claimed two other jobs failed "the same way." That was wrong.**
   Checked against the records: `popcrm-codebase-audit-remediation` failed with a
   *different* code (`permission-unsupported-action`), and
   `automatic-gates-repo-neutral-compact` was not a permission failure at all
   (`turn-timeout`). Do not repeat the "implementation mode is uniformly broken"
   conclusion — four implementation jobs succeeded the same day.
4. **`ai-glm show` from the wrong checkout fails by design.** Running it from
   `C:\repos\ai-devops` for a job recorded in a worktree returns "belongs to a
   different checkout path." You must `Set-Location` to the recorded
   `repository_root` first. This is intentional ownership protection, not a bug.
5. **Reading the plan file at session start returned a stale copy.** I read it,
   reported "step 1 correction open," and it had in fact been closed minutes
   earlier by a concurrent session. Always re-check `git log --oneline -3`
   before trusting a plan's STATUS table in this repo — several agents work it
   at once.

## 5. Root causes and key findings

### The GLM wrapper (new plan)

Two defects proven from source, both in `bin/ai-glm`:

1. **The gate discards its own diagnosis.** `classify_permissions`
   (`bin/ai-glm:406`) has seven distinct rejection reasons, at lines 411, 413,
   417, 419, 439, 440, and 441. `handle_permissions` maps them onto only four
   durable codes, so **five of the seven collapse into one fallback**,
   `permission-invalid-response`. The real reason and the sanitized body go to
   `die`, which prints to the caller's stderr.
   `record_implementation_permission_failure` (`bin/ai-glm:452`) stores only the
   code and a generic summary. For an unattended job the diagnosis is destroyed
   at the moment of failure.
2. **Implement mode has no approval path for its own tools.**
   `config/opencode/agent/glm-implement.md:5-17` grants `write`, `edit`,
   `patch`, `bash`, `todowrite`, but pre-allows only `read`, `list`, `glob`,
   `grep`. `config/opencode/opencode.json` says nothing about the write-class
   actions. And `bin/ai-glm:440` accepts only `read|list|glob|grep|todowrite`.
   So any write-class permission ask is fatal. That is exactly what killed
   `popcrm-codebase-audit-remediation`.

Unproven but most likely for the step-2 failure: an entry whose paths arrive
under a key other than `.resources`, hitting "permission entry is missing
resources" at `bin/ai-glm:441`. Recorded as a hypothesis, not a fact.

Also proven: the failure is **intermittent**. `issue-729-safe-launch-v3`,
`issue-617-digest-pin-local`, `catalog-verifier-net-acl-v2`, and
`pr823-comment-accuracy-fix` all completed the same day. Any fix must explain
the intermittency.

Also proven, and important: **the safety design worked.** The partial diff was
exported, the INCOMPLETE report was written, the clone was cleaned, the primary
checkout was untouched, and the exit code was nonzero. Do not weaken the
fail-closed posture. Fix its blindness only.

### The context work

- Step 2's ownership map is the authority for where any rule lives. Read
  `docs/context-engineering.md:71-193` before moving or trimming anything in
  steps 4 through 6.
- The corrected manifest totals are Claude 21,521 bytes (about 5,381 tokens) and
  Codex 14,015 bytes (about 3,504 tokens). The earlier published values (18,448
  and 10,593) are superseded and must not be used as budget inputs.
- Drift detection is a raw-byte SHA-256 comparison, so it is line-ending
  sensitive. Always measure from `C:\repos\ai-devops`, never from a worktree, or
  you will see phantom drifted skills.

### Unrelated, already fixed, recorded so nobody re-investigates

The Grok 4.5 implementation runner bug is **already fixed** by another session.
Root cause: Grok 0.2.112 accepts `--worktree` in headless mode and silently
ignores it, so it was editing the primary checkout, which sat on a stale
detached HEAD. Fix is `bin/ai-grok-implement`, commit `506d180`. Also measured:
`--cwd` needs a native Windows path, `--permission-mode auto` auto-cancels tools
and yields `stopReason: "Cancelled"`, and the cleanup subcommand is
`grok worktree rm`, not `remove`. Full detail is in the memory file
`grok-worktree-silently-ignored.md`. **Do not re-run the "Repair the Grok 4.5
implementation runner" prompt.**

## 6. Exact next steps

1. **Commit the three uncommitted plan edits** described in section 3. Verify
   identity first with `git var GIT_COMMITTER_IDENT`; it must read
   `Albert Hazan <u2giants@users.noreply.github.com>`. You'll know it worked
   when `git status --porcelain` shows only the two untracked paths `.ai/` and
   `docs/claude-remote-control-hardening-v2.md`, and `git status -sb` shows main
   level with origin.
2. **Put section 0 to Albert in one message** and get his answer on which plan
   runs first. You'll know it worked when he has answered items 1 through 4 in a
   single reply.
3. **If he picks the GLM fix:** open `plan_ai-glm-permission-failures.md` and do
   its step 1 only — make every permission rejection produce a durable,
   sanitized diagnostic. You'll know it worked when a fixture drives all seven
   rejection reasons through the failure path and `ai-glm show` distinguishes
   all seven, no unsanitized body is ever written, and `tests/test-ai-glm.sh`
   passes.
4. **If he picks the context plan:** open
   `plan_context-engineering-consolidation.md` and do its step 3 only. Read the
   step, plus sections 1, 4, 8, 11, and 13, before touching anything. Extend
   `tests/test-context-audit.ps1`; do not create a second audit test. Add
   *warning* budgets, never hard failures, and add the safety-marker tests
   before any prose is trimmed. You'll know it worked when each new test fails
   with a plain reason after its marker is removed from a fixture, passes
   against the real sources, and every suite named in `docs/development.md`
   still passes.
5. **At the end of whichever phase you do,** re-read all remaining phases of
   that plan through its last step and record any drift you created in the plan
   itself. You'll know it worked when the plan's STATUS evidence column names
   your change and no later step still assumes something you altered.
6. **Do not delegate any of this to `ai-glm implement`** until the GLM plan
   reaches its step 6. GLM **review** sessions are fine and are the right tool
   for a second opinion. You'll know you got this right when `ai-glm list` shows
   no new implementation job for this repo.

## 7. Constraints and gotchas in force

- Work on `main` in `C:\repos\ai-devops`. This repo is main-only, no branches.
- Commit only when asked. End commit messages with the
  `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>` trailer.
- Verify `git var GIT_COMMITTER_IDENT` before the first commit in any checkout.
  Git silently invents an identity when none is configured; that already put 231
  wrong-identity commits into merged history in another repo.
- **Several AI sessions work this repo at once.** Re-check `git log` before
  trusting any plan STATUS table, and never `git add -A`.
- Never rewrite root `HANDOFF.md`, and never edit or delete another session's
  `HANDOFF.d/` file.
- Never call `opencode`, `opencode run`, `opencode serve`, or the OpenCode HTTP
  API directly. Everything goes through `bin/ai-glm`.
- Never read or print `~/.grok/auth.json`, the OpenCode server password, or any
  1Password value. Neither plan needs a secret.
- Do not hand-edit installed configs under `~/.claude`, `~/.codex`, or
  `~/.config/opencode`. Change the canonical repo files and reinstall through
  `bin/install-ai-devops-windows.ps1` or `bin/setup-opencode-glm.ps1`.
- No production, shared-cloud, Supabase, NAS, or database mutation. No
  `terraform apply` against prod, ever.
- If Codex is used: GPT-5.6 reasoning stays explicitly `low` or `medium`.
- `bin/setup-machine.ps1:187,192` invokes the Windows installer through
  PowerShell 5.1, not 7. Keep that child script 5.1-safe.
- Measurement runs against GLM cost real money. Use the smallest fixture that
  forces the behavior, and never loop retries.

## 8. Access and environment

- Repo `C:\repos\ai-devops`, branch `main`, remote
  `https://github.com/u2giants/ai-devops`.
- Authenticated CLIs on this machine: `gh`, `gcloud`, `az`, `supabase`,
  `vercel`, `op` (when toggled on). Verify with a real call before claiming one
  is missing.
- `ai-glm doctor` passed every required check on 2026-08-12 after the scratch
  sweep. The OpenCode server runs behind Windows Scheduled Task
  `AiDevOps-OpenCodeGlm`; control it only with `ai-glm server start|stop|
  restart|status`.
- GLM job records live at `~/.local/state/ai-devops/glm/sessions/<repo-id>/
  <caller>--<name>.json`. Run `ai-glm show` from the job's recorded
  `repository_root`, not from anywhere else.
- Grok: `C:\Users\ahazan2\.grok\bin\grok.exe`, version 0.2.112, model
  `grok-4.5`. Use `bin/ai-grok-implement` for writing work,
  `bin/ai-grok-review` for reviews.
- Machine facts: `templates/system/machine-atlas.md`, section `al8960ofc`.
- Secrets live only in the 1Password vault `vibe_coding`. Serialize all
  1Password reads; never fan them out in parallel. Neither open plan needs one.
- Delegate artifacts go under the untracked `.ai/reviews/`.
- There is no server to start and nothing to deploy for this toolkit.

## 9. Open questions and risks

- **The step-2 GLM failure's exact cause is unknown and may stay unknown.** The
  evidence was destroyed by the wrapper. Step 1 of the GLM plan exists so the
  next occurrence is diagnosable. Do not let anyone "fix" the wrapper by
  widening the allowlist first; that is rejected approach 1 in that plan's
  section 7, dated 2026-08-12.
- **Widening the permission allowlist is the one change that can weaken the
  sandbox.** It must stay last, smallest, and measured.
- **`HANDOFF.d/` is at five open files, the warning line.** Oldest first:
  `2026-08-10T1138Z-albt16-codex-916-rollout.md` (not mine, unknown state);
  `2026-08-12T1135Z-al8960ofc-codex-context-engineering-audit.md` (audit and
  planning, appears complete);
  `2026-08-12T1339Z-al8960ofc-codex-context-baseline-step1.md` (step 1, appears
  complete); `2026-08-12T1431Z-al8960ofc-codex-kimi-baseline-correction.md`
  (correction, closed by commit `f13e4af`);
  `2026-08-12T1552Z-al8960ofc-claude-context-audit-parser-fix.md` (the parser
  fix, appears complete). None are mine, so I did not delete any. Three of the
  four context ones look superseded. This is section 0 item 3.
- **Two failed GLM job records are deliberately being left in place** as the
  test material for the GLM plan's step 6. Deleting them early destroys the
  proof. Section 0 item 4.
- **Risk that a later context step trims a safety rule before its test exists.**
  The plan forbids it, and step 3 exists to prevent it. If any reviewer proposes
  removing safety text for size, require a behavioral test and a named canonical
  owner first. Decision dated 2026-08-12, locked.
- **Risk of concurrent-session clobber.** This repo had at least three AI
  sessions active on 2026-08-12. Always re-read ground truth from git before
  acting on a plan's stated status.

## Mandatory self-audit

**1. Could a brand-new developer with no project knowledge continue without
asking a question?** Yes. Section 1 defines the repo, stack, machine, and that
there is no CI. Section 2 gives the business reason. Section 3 gives exact
commit SHAs, the three uncommitted edits with their content, and what is
untracked. Section 6 gives numbered next steps with verification gates. Section
8 gives every path and command they need.

**2. Could they continue as effectively as I can right now?** Yes. Section 5
carries every non-obvious thing learned this session with `file:line` refs: the
seven-reasons-into-four-codes collapse at `bin/ai-glm:406-452`, the missing
write-class approval path at `config/opencode/agent/glm-implement.md:5-17` and
`bin/ai-glm:440`, the line-ending sensitivity of drift detection, and the
already-fixed Grok bug so nobody re-investigates it.

**3. Is every relevant detail present: background, goals, state, failures,
decisions, constraints, risks, next actions, verification?** Yes. Section 4
carries five real dead ends including two of my own errors (the wrong "same
failure" claim and the stale plan read). Section 7 carries the standing rules.
Section 9 carries the risks with dates. Every next step in section 6 ends in a
"you'll know it worked when" gate.

**4. If Albert read ONLY section 0, would he see every decision I need from
him?** Yes, checked the hard way by walking sections 1 through 9 line by line.
The sentences needing his judgement are: which plan runs first (section 6 step
2), whether GLM may run shell commands (section 5 and the GLM plan's open
decision 1), the five open handoff files (section 9), and the two stuck job
records (section 9). All four appear in section 0 with a recommendation. The
handoff-file cleanup and the stuck records are both outside this workstream and
were promoted from findings to asks, which is the failure mode section 0 exists
to catch.

Self-audit passed on 2026-08-12.
