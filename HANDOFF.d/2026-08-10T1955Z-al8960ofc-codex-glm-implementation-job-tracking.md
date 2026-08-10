# Handoff: GLM implementation job tracking

## 0. Decisions only the owner can make

None. Albert approved Phase 1 in full, and every design question was resolved by the
plan's safety rules and tests.

Already settled on 2026-08-10: implementation remains one-shot; uses an exact
remote-less clone; never writes to the real checkout; preserves the model/provider pins,
fail-closed permissions, read-only review tools, and strict completion rule; retains
terminal records until explicit safe deletion.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's Git-backed toolkit for installing and restoring
his multi-model AI coding workflow. It is Bash, PowerShell, tests, skills, and Markdown,
not a hosted application. `bin/ai-glm` manages GLM-5.2 review sessions and one-shot
implementation jobs through a local authenticated OpenCode 1.18.12 service. This work
uses `C:\repos\ai-devops`, branch `main`, on Windows host `AL8960OFC`.

## 2. What we set out to do, and why

Implement every open row in `plan_glm-implementation-job-tracking.md`. The old wrapper
kept implementation identity only in local Bash variables. `ai-glm list` could show
nothing while a paid implementation still ran, so a caller could start the same name a
second time. The required result was durable visibility, full-run name exclusion, exact
abort, safe explicit deletion, truthful terminal evidence, and conservative dead-owner
recovery.

## 3. Current state

- Work began at `a0786a8a94c06a4612056a6c3878e3f6da64c6a1`, synchronized with
  `origin/main`.
- `bin/ai-glm:204-267` now validates and serializes v3 implementation-record updates.
  `bin/ai-glm:647-694` has the one lifecycle cleanup path. `bin/ai-glm:696-806` owns
  record-before-clone creation and the full-run lock.
- `bin/ai-glm:808-915` makes list/show/abort/delete type-aware. `ask`, transcript, and
  server diff reject one-shot jobs. `bin/ai-glm:917-971` reconciles dead owners only
  with complete ownership evidence.
- `tests/test-ai-glm.sh:227-337` contains controlled offline lifecycle fixtures.
  `tests/test-ai-glm.sh:388` starts the bounded real-service visibility/abort canary.
- Canonical behavior is documented at `docs/glm-opencode.md:189` and its load-bearing
  constraint 28 at line 435. Developer test rules are at `docs/development.md:68`.
  Shared agent guidance begins at `skills/shared/ask-glm/SKILL.md:89`.
- Verification passed: Bash syntax; 155/155 offline GLM checks; 25/25 Windows checks;
  full live suite 176/176; final no-provider real-service canary; doctor; diff check;
  installed Claude/Codex skill SHA-256 equality.
- No production, cloud, database, credential, Kimi, todowrite, or partial-patch feature
  changed. CI and app deployment are N/A because this repo has neither.
- This handoff is intentionally still present while commit/push is pending. Delete this
  file only after the implementation commit is pushed and remote SHA is verified.
- Unrelated untracked `.ai/` and
  `docs/claude-remote-control-hardening-v2.md` predated this session and remain untouched.

## 4. Everything tried that did not work

1. The first large patch replacing `cmd_implement` failed its context check around the
   Markdown patch report. No file changed. The implementation was reapplied in smaller
   exact patches.
2. The first offline fixture derived its record ID with Git's Windows path while the
   wrapper hashes Bash's physical path. It looked for the correct record under the wrong
   ID. The fixture now calls the wrapper's own `repo_id`, matching production.
3. The first cleanup comparison used raw `/tmp/...` versus `C:/...` strings. Git Bash
   converts native `jq` path arguments, so the same Windows path had two spellings and
   was preserved as ambiguous. Cleanup and validation now compare canonical paths.
4. The first final-canary shell command was rejected by the command safety layer because
   it included recursive temp deletion. The canary was rerun without deletion in that
   command, completed successfully, and its exact temp path was separately inspected.
5. Initial review found two unsafe edge cases before shipping: the ordinary lock helper
   would reclaim the stale lock needed for dead-owner proof, and HTTP DELETE treated any
   HTTP response as success. Implementation now never reclaims its full-run lock during
   a retry and accepts only 2xx/404 exact-session deletion.

## 5. Root causes and key findings

- Reviews had durable metadata and locks. Implementations had only process-local names,
  clone paths, and session IDs. That mismatch was the duplicate-job root cause.
- Visibility alone is not enough. The repository/caller/name lock must begin before any
  clone or server session and remain until terminal metadata and cleanup are durable.
- Abort has two actors. The control process records `abort-requested` and targets the
  exact server session. The owner process removes its exact live clone and records the
  observed terminal truth. A completed patch wins a completion/abort race.
- Record updates need a separate short atomic lock. Otherwise abort and owner updates can
  overwrite one another even though each individual file write uses temp-plus-rename.
- PID alone never authorizes cleanup. Recovery also requires schema, record location,
  repository ID, canonical clone, matching stale full-run lock, and exact server state.
- A terminal record is evidence, not clutter. Explicit `delete` clears it for safe name
  reuse; no timer silently erases the only explanation of a failure.

## 6. Exact next steps

1. Recheck `git status` and fetch `origin/main` without touching the two unrelated
   untracked paths. It worked when tracked changes are only this work and the remote has
   not advanced unexpectedly.
2. Verify `git var GIT_COMMITTER_IDENT` is
   `Albert Hazan <u2giants@users.noreply.github.com>`. It worked when the exact identity
   prints before the first commit.
3. Stage only AGENTS, `bin/ai-glm`, the two GLM docs, the plan, shared skill, GLM tests,
   and this handoff. Commit and push `main`. It worked when GitHub accepts the commit.
4. Fetch and compare local `HEAD` with `origin/main`. It worked when both full SHAs are
   equal.
5. Mark plan STATUS row 5 complete with the verified evidence, delete this now-finished
   handoff, commit that closeout, push, fetch, and compare again. It worked when no plan
   row is open, this handoff is absent, and final `HEAD == origin/main`.

## 7. Constraints and gotchas

- Never edit `bin/ai-glm` while a copy is running. The installed command points into
  this checkout.
- Never reclaim or remove an implementation lock merely because its PID is dead. Doctor
  needs the matching stale lock as independent ownership proof.
- Preserve the remote-less clone, model/provider pins, permission classification,
  finish-stop plus two-idle-poll completion, and review tool map.
- Never store prompts, responses, tokens, secrets, or credentials in job metadata.
- Never sweep legacy or ambiguous scratch paths. Warn and preserve them.
- Use `main`; stage only owned paths. Do not stage `.ai/`, the unrelated remote-control
  doc, or another session's handoff.
- Git author and committer must remain Albert's noreply identity.

## 8. Access and environment

- GitHub: `https://github.com/u2giants/ai-devops`, branch `main`.
- Local service: authenticated loopback port 4096; OpenCode 1.18.12;
  `zai-coding-plan/glm-5.2`; caller `codex`; Windows Scheduled Task
  `AiDevOps-OpenCodeGlm`.
- `ai-glm doctor` is fully green. The real live suite and final bounded canary both used
  only `ai-glm`, never direct OpenCode or curl calls.
- GLM credentials remain in 1Password vault `vibe_coding`, item `GLM z.ai API`. No
  secret value was read, printed, or committed.
- Repo, Claude, and Codex copies of `ask-glm/SKILL.md` all hash to
  `D6ED8DD6D188263F552ACBD757D35F4F012E002B33D98FD84043683485307CC1`.

## 9. Open questions and risks

- No owner decision is open. The plan's evidence questions were resolved: terminal
  records use explicit delete; wrapper state distinguishes requested abort; failed exact
  session deletion remains visible for retry; legacy scratch ownership is never guessed.
- The only remaining risk is ordinary commit concurrency on `main`. Fetch and compare
  immediately before push, preserve concurrent work, and use no force push.
- A bounded final canary temp directory was left under the Windows user temp area because
  the command safety layer refused recursive deletion. It contains only a scratch Git
  repo and secret-free canary output, not an active GLM job or server session.

## Mandatory self-audit

1. Yes. Sections 1-3 define the toolkit, defect, exact files/lines, current code, and
   verification. Section 6 gives the only remaining steps with a gate for each.
2. Yes. Sections 4-5 preserve every failed attempt and all non-obvious path, locking,
   abort-race, HTTP, and recovery findings.
3. Yes. Sections 2-9 cover goal, outcome, state, failures, decisions, constraints,
   access, risks, tests, install evidence, commit state, and exact next actions.
4. Yes. A line-by-line sweep of sections 1-9 found no owner approval or judgment still
   needed. Section 0 states that explicitly and lists the settled choices so they are not
   reopened.

Self-audit passed on 2026-08-10. A street-new developer can finish commit/push without
this chat and with the same knowledge available to this session.
