# Handoff: context step 2 landed; GLM transport-failure fix specified as step 7

Written 2026-08-12T1659Z on machine `al8960ofc` by a Claude Opus session.
Repo: `C:\repos\ai-devops` (`u2giants/ai-devops`), branch `main`.

> Read this whole file before touching anything. There is a sibling handoff,
> `2026-08-12T1656Z-al8960ofc-claude-glm-permission-plan-and-step2-verify.md`,
> written by a different session three minutes before this one. **Where the two
> disagree, this file is newer and wins**, specifically about (a) whether context
> step 2 is committed, and (b) whether the cause of the failed GLM job is
> unknown. Do not edit or delete that sibling file; it is not yours.

## 0. DECISIONS ONLY ALBERT CAN MAKE

### Blocking

None. Both open plans can proceed without him.

### Recoverable, but ask before doing the work twice

1. **Which plan runs next: `plan_context-engineering-consolidation.md` step 3, or
   `plan_ai-glm-permission-failures.md` steps 1 and 7?** Albert was told both are
   available and that they share no files, so they can run in parallel in two
   sessions. He has not chosen. Recommendation: the GLM fix first if only one
   session is available, because every long delegation to GLM is currently at
   risk of being killed by the bug in step 7.
2. **Whether `ai-glm implement` may run shell commands at all.** Open decision 1
   in `plan_ai-glm-permission-failures.md` section 8. Decide from the step-2
   measurement, not from opinion.

### Already settled, do not re-ask

- Context step 2 is DONE and pushed. Its STATUS row is `✅ done`.
- No global or repo instruction file may be trimmed until steps 4 and 5 of the
  context plan. Step 2 deliberately added only.
- `plan_ai-glm-permission-deadlock.md` is finished and shipped. It is the
  historical record of the original fail-closed design. Do not reopen it. The
  new work belongs in `plan_ai-glm-permission-failures.md`.
- The missing-`resources` hypothesis for job `context-ownership-map-step2` is
  disproven. See section 5.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public toolkit for his multi-model AI
coding workflow: Bash and PowerShell CLIs, global Claude/Codex instruction
templates, repo doc templates, skills, machine setup, and cross-machine memory.
No app, no database, no container, no CI, no deployment. Branch policy is `main`
only. Albert is a business owner, not a programmer.

Relevant pieces for this session:

- `plan_context-engineering-consolidation.md` — the ten-step plan to shrink
  always-loaded AI context safely.
- `plan_ai-glm-permission-failures.md` — the open plan for the `ai-glm`
  permission gate.
- `plan_ai-glm-permission-deadlock.md` — the completed predecessor. Read-only.
- `docs/context-engineering.md` — the measured baseline AND, as of this session,
  the context ownership map.
- `bin/ai-glm` — the Bash wrapper around a locally hosted OpenCode server running
  Z.ai GLM 5.2. It owns the permission gate discussed below.

## 2. What we set out to do, and why

Albert asked for two things, in order:

1. Have GLM 5.2 read `AGENTS.md`, the parser-fix handoff, and the full
   consolidation plan (re-reading sections 1, 4, 8, 11, 13), then implement
   **step 2, the context ownership map**, with an explicit instruction NOT to
   trim any global or repo instruction file (that is steps 4 and 5).
2. After the GLM run failed partway, decide whether the failure was a defect in
   our own wrapper, and if so get the fix written into the right plan so it can
   be implemented alongside the context work without collisions.

Both are done.

## 3. Current state — what is true right now

### Pushed to `origin/main`

| SHA | What |
|---|---|
| `c83d937` | The ownership map itself (authored in worktree `context-ownership-map-c0be98`) |
| `59798e6` | Merge of that worktree branch into `main` |
| `69f4d2a` | Context plan STATUS: step 2 `✅ done`, fresh-session start moved to step 3 |
| `92a23c5` | `plan_ai-glm-permission-failures.md`: finding 3 corrected, step 7 added |

`git status` on `C:\repos\ai-devops` is clean apart from two pre-existing
untracked paths that are NOT this session's and must be left alone: `.ai/` (git-
ignored review artifacts) and `docs/claude-remote-control-hardening-v2.md`.

### What step 2 delivered

In `docs/context-engineering.md`, under "Context ownership map (step 2)":

- A per-class ownership table: canonical owner, who loads it, when it loads,
  maximum useful detail, and how other artifacts link to it, for nine classes
  (universal rules, machine facts, repo router, repo Claude adapter, topic docs,
  skills, memory, config templates, plans, handoffs).
- An eight-row decision table: global / machine / repo / topic doc / skill /
  memory / plan / handoff, walked top to bottom, first yes wins, so no rule can
  land under two owners.
- A definition of "pointer" as **path plus trigger**, with worked non-examples.
- Stale-state, deletion, and retention ownership rules.
- Ten real existing rules classified through the table, as the plan's
  verification gate demanded.

Also: a router row in `AGENTS.md`, a pointer at the top of both
`docs/skills-usage-guide.md` and `docs/codex-skills-usage-guide.md`, and the
Windows installer rows corrected in both guides to name
`bin/install-ai-devops-windows.ps1` as the native path with `bin/ai-install-skills`
labeled Ubuntu / Git Bash.

**Nothing was trimmed.** The full diff is 161 lines added, 10 removed, and the
removals are only rewritten sentences inside those same three docs.

### The GLM job

Job `context-ownership-map-step2` (caller `claude`) is in the durable record as
`failed` / `permission-invalid-response`. **Leave it there.** Step 6 of
`plan_ai-glm-permission-failures.md` re-runs it deliberately as the proof the fix
worked. Deleting the record early destroys that test. Same for
`popcrm-codebase-audit-remediation`.

## 4. Everything we tried that did NOT work

1. **Delegating step 2 to GLM as an implementation job (`ai-glm implement`) did
   not run to completion.** It failed after about eight minutes. It was NOT
   wasted: the wrapper exported an incomplete patch and that patch contained
   essentially the whole ownership map. Do not conclude implement mode is
   useless. Four other implementation jobs succeeded the same day.
2. **Do not assume the failure reason is lost.** The sibling handoff and the
   plan's original finding 3 both say the exact stderr was unrecoverable, because
   `~/.local/state/ai-devops/glm/logs/` is empty and no OpenCode server log
   directory exists. That is true of those locations, but the dispatching Claude
   session ran the job as a **background task**, and the harness had written the
   stderr to its own task output file. That is where the answer was. If this
   happens again, look for the background-task output file first.
3. **Do not fix this by widening the implement allowlist.** That was the obvious
   guess and it is wrong for this job; see section 5. It would have shipped a
   reduction in sandbox guarantees while leaving the real bug in place.
4. **`git merge --ff-only` from the worktree branch into `main` failed** because
   `main` had moved ahead with an unrelated memory-sync commit from another
   machine. A normal merge commit is correct here; do not rebase shared history.
5. **`ai-glm` is not on the Bash tool's PATH on this machine.** `bash -lc
   "ai-glm ..."` returns `command not found`. Run it from PowerShell, which
   resolves the shim. This cost one wasted call.

## 5. Root causes and key findings

### Finding A (proven): the GLM job died of a transport failure, not a permission

Recovered stderr, verbatim:

```text
ai-glm: error: GLM permission failed: permission endpoint returned HTTP 000.
       status=000 mode=implement path=missing sanitized_response=
```

- `000` is not a status any server can send. `permission_http` in `bin/ai-glm`
  (around line 360) assigns `HTTP_STATUS="000"` when the `curl` call itself
  exits nonzero: connection refused, connection reset, or the `-m 20` timeout.
- The body was empty and the path category was `missing`, both consistent with
  "no reply was ever received". No permission payload was ever seen, so no
  action, allowlist, or key shape was involved.
- `classify_permissions` treats `000` like any other non-2xx status and fails
  closed with a message that blames permissions. **A dropped local HTTP poll is
  being reported to the user as an unsafe permission state.**
- `ai-glm doctor` passed every check minutes later, scheduled task `Running`,
  health endpoint answering. The service did not go down. This fits a transient
  loopback stall, which hard-won constraint 24 in `docs/glm-opencode.md` already
  documents for this endpoint while a `glob`/`grep` permission is pending.

The fix is `plan_ai-glm-permission-failures.md` **step 7**: carry the transport
failure through as its own state, retry the dropped poll a bounded three times
(free — the poll is local, nothing is re-sent to Z.ai), give it its own durable
code, and say plainly that the local endpoint did not answer. A genuine non-2xx
from a server that did answer keeps failing closed exactly as today.

### Finding B (unchanged, from the sibling session): implement mode has no
write-class permission path

`config/opencode/agent/glm-implement.md` grants `write`, `edit`, `patch`, `bash`,
but the wrapper's allowlist accepts only `read`, `list`, `glob`, `grep`,
`todowrite`. That is the real cause of `popcrm-codebase-audit-remediation`
(`permission-unsupported-action`). Still needs steps 1 through 4 of that plan.

### Finding C: the safety design behaved correctly in both failures

Partial diff exported as `.incomplete.patch` with an INCOMPLETE report, clone
cleaned, primary checkout untouched, job record durable, exit nonzero. Nothing
about fail-closed should be weakened. Only its blindness and its mislabeling.

### Finding D: GLM's authored content was good

Every path it cited was verified to exist (17 checked). Its Windows installer
correction matched the real scripts. It did not trim anything it was told not to
touch. It did not reach `docs/codex-skills-usage-guide.md` before it died; that
one file was written by hand in this session.

## 6. Exact next steps

1. **`plan_ai-glm-permission-failures.md`, step 1 then step 7.** Step 1 makes the
   seven rejection branches individually diagnosable in the durable record; step 7
   is the transport fix above. Steps 2 through 4 (measure and widen the allowlist)
   are separate and can go to a different session. Step 6 stays last.
2. **`plan_context-engineering-consolidation.md`, step 3.** Context-audit tooling
   and regression tests, with warning budgets rather than hard failures. The plan
   is explicit that enforcement comes BEFORE any reduction in steps 4 through 6.
3. These two are safe to run at the same time in separate sessions. Ownership is
   recorded in the failures plan's STATUS preamble: the GLM plan touches only
   `bin/ai-glm`, `config/opencode/*`, `tests/test-ai-glm.sh`,
   `docs/glm-opencode.md`, `skills/shared/ask-glm/SKILL.md`; the context plan owns
   the instruction files, `AGENTS.md`, `docs/context-engineering.md`, and the
   skills usage guides. Pull `main` immediately before committing either.

## 7. Constraints and gotchas in force

- Do not trim any global or repo instruction file outside context-plan steps 4
  and 5. Step 2 was additive on purpose.
- The context plan now carries an end-of-phase reciprocal instruction: after
  finishing a phase, re-read all remaining phases and record any drift your work
  created before cutting to a fresh session.
- Commit identity must be `Albert Hazan <u2giants@users.noreply.github.com>`.
  Verify with `git var GIT_COMMITTER_IDENT` before the first commit.
- Commit messages end with the `Co-Authored-By: Claude Opus 4.8` trailer in this
  repo.
- `main` only. This session used a pre-existing worktree branch and merged it in;
  that is fine, but do not create new long-lived branches.
- Run `ai-glm` from PowerShell on this machine, not from the Bash tool.
- Never approve every GLM permission and never auto-copy files from outside the
  session repository to make a permission error disappear.
- `.ai/` is gitignored. Do not commit review artifacts or incomplete patches.

## 8. Access and environment

- Machine `al8960ofc`, Windows 11, PowerShell 7 primary, user `ahazan2`.
- Repo `C:\repos\ai-devops`. A worktree from this session still exists at
  `C:\repos\ai-devops-worktrees\context-ownership-map-c0be98` on branch
  `claude/context-ownership-map-c0be98`. Its commit is merged into `main`; it can
  be removed with the `cleanup-worktree` skill when convenient.
- `ai-glm` is installed and healthy. `ai-glm doctor` passed every check at the
  end of this session. OpenCode is pinned at 1.18.12; the Windows service is
  Scheduled Task `AiDevOps-OpenCodeGlm`.
- No secrets were used, seen, created, or needed in this session. Nothing to
  sweep to 1Password.

## 9. Open questions and risks

1. **Why did the loopback poll drop?** Step 7 makes it survivable but does not
   explain it. If the retries start firing often, that is a signal to investigate
   the OpenCode server itself, not to raise the retry count.
2. **`HANDOFF.d/` now holds six open files, over the five-file warning line.**
   Oldest first: `2026-08-10T1138Z-albt16-codex-916-rollout.md`,
   `2026-08-12T1135Z-...-context-engineering-audit.md`,
   `2026-08-12T1339Z-...-context-baseline-step1.md`,
   `2026-08-12T1431Z-...-kimi-baseline-correction.md`,
   `2026-08-12T1552Z-...-context-audit-parser-fix.md`, and this one. The three
   middle context ones look superseded now that steps 1 and 2 are both done and
   recorded in the plan, but each belongs to another session and only its owner
   or Albert should delete it. Someone should confirm and clear them.
3. **Risk that a future session re-guesses the cause of the failed job.** The
   plan's finding 3 has been rewritten with the evidence, but the sibling handoff
   still carries the old "unrecoverable" wording. This file is the correction.

## Mandatory self-audit

Could a developer who walked in this morning with zero knowledge continue with no
questions?

- Do they know what the app is and which files matter? Yes, section 1.
- Do they know what is already committed and where? Yes, section 3, with SHAs.
- Do they know what was tried and failed, including the two dead ends that cost
  this session time? Yes, section 4.
- Do they know the actual root cause and the evidence for it, rather than a
  hypothesis? Yes, section 5, with the verbatim error and the code path.
- Do they know exactly what to do next, in what order, and what may run in
  parallel? Yes, section 6.
- Do they know what they must not do? Yes, sections 0 and 7.
- Do they know the environment quirks that would otherwise waste a call? Yes,
  sections 4 and 8.

Judged sufficient.
