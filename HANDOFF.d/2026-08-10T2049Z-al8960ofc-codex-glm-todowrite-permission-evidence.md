# Handoff: GLM TodoWrite safety and immediate permission evidence

## 0. Decisions only the owner can make

None. Nothing in this workstream needs Albert's approval or judgment. The remaining
steps are mechanical Git closeout. Already settled on 2026-08-10: TodoWrite may be
allowed only in the exact measured OpenCode 1.18.12 form; wildcard or unknown
permissions must never be generally allowed; incomplete GLM work must never become a
patch.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's Git-backed toolkit for running and restoring his
multi-model coding workflow. It is Bash, PowerShell, configuration, tests, and Markdown,
not a hosted application. The affected command is `bin/ai-glm`, the only supported
client for the local authenticated OpenCode 1.18.12 server and its pinned GLM-5.2 model.

Review sessions are structurally read-only through `config/opencode/agent/glm-review.md`.
Implementation sessions run in a disposable Git clone with its remote removed. A v3
job record makes every implementation visible, exclusive, abortable, and recoverable.
Work is on `main` in `C:\repos\ai-devops`; GitHub `u2giants/ai-devops` is the source of
truth. There is no app deployment or CI workflow.

## 2. What we set out to do this session, and why

This session implemented only repair phases 2 and 3:

1. Decide whether OpenCode's TodoWrite planning action is safe enough to approve. The
   gate required pinned-binary inspection plus a bounded live measurement of the exact
   permission action and resource shape. It also required proof that the action cannot
   read or write files, run shell commands, use the network, or reveal a harmless marker
   outside the repository.
2. Make unsupported permission requests fail on the first poll that exposes them. For
   implementation jobs, the durable record must immediately say why the turn failed,
   whether the clone contained unexported changes, and whether any patch exists.

The trigger was a safe-repair order that explicitly forbade general `*` approval,
unknown actions, incomplete-patch export, changes to Kimi, or changes to completed-turn
usage accounting.

## 3. Current state: what is true right now

Implementation and verification are complete in the working tree. Commit and push are
the only remaining steps at the time this handoff was finalized.

- `bin/ai-glm:376-404` accepts normalized `todowrite` only when the response has exactly
  `resources:["*"]` and `save:["*"]`. The star is action-local. Every changed or missing
  field and every unknown action still fails closed.
- `config/opencode/agent/glm-review.md:12` and
  `config/opencode/agent/glm-implement.md:12` explicitly enable TodoWrite. The review
  agent still has no write, edit, patch, Bash, web-fetch, or task tool.
- `bin/ai-glm:410-438` records a safe first-poll failure summary, timestamp,
  `changes_present`, and `patch_exists` before returning the permission error.
- `bin/ai-glm:456-512` sends review callers to abort, but tells implementation callers
  to inspect the already-failed durable job. No raw prompt, file content, or secret is
  stored in the record.
- `bin/ai-glm:975` refuses deletion while exact cleanup is pending.
  `bin/ai-glm:983-1034` lets doctor finish conservative cleanup if an owner dies after
  the first-poll failed record, while retaining the original permission failure cause.
- `tests/test-ai-glm.sh:199-229` covers the exact TodoWrite shape and fail-closed
  variants. Lines 316-359 cover first-poll durable evidence, the delete race, and
  dead-owner cleanup. Lines 388-446 contain the bounded live TodoWrite and unsupported
  permission canaries.
- `docs/glm-opencode.md:210-219,285-299,329-351`, `docs/development.md:77-84`, and
  `skills/shared/ask-glm/SKILL.md:167-175` carry the measured rule and operator guidance.
- Combined live/offline suite: **195 passed, 0 failed** before the final cleanup-race
  additions. Final offline suite after those additions: **169 passed, 0 failed**.
  Windows suite: **25 passed, 0 failed**.
- A final live unsupported `question` canary after every code change exited 1 and
  recorded `failed`, `permission-unsupported-action`, first-observable-poll summary,
  `changes_present:false`, `patch_exists:false`, `patch_path:null`, both cleanup fields
  `removed`, and a non-null finish time. Its job was then safely deleted.
- A live TodoWrite review returned exactly `PLANNED`. The tracked repo stayed clean, the
  planted outside marker hash stayed
  `4FAE6F1CC6D3E70A3B1958D2D4EA4B6BD3F35217F89DD5AEF0DA16287DBF336C`, and its marker
  text never appeared in output.
- The shared `ask-glm` skill was reinstalled. Repo, Claude, and Codex copies all hash to
  `D8AE34DB2593FCCB86C21D422D02E2103A7446D7A8865C7CF15B75827810456A`.
- Installed review and implement agent files hash-match the repo at
  `8E578B26D06E8EFC61F0243627B77175E92BF5F1ED7D450BDF0FCF512131F439` and
  `2813B8187AFF54B00847B50C09870CD5A2ADA4C348D7CB1BF23B79C8B8929D81`.
- Albert's author and committer identity both resolve to
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Unrelated untracked `.ai/` and `docs/claude-remote-control-hardening-v2.md` belong to
  other sessions. They remain untouched and must not be staged.

## 4. Everything we tried that did not work

1. The first bounded TodoWrite run was intentionally made before allowing the action.
   It failed on its first permission poll with HTTP 200 action `todowrite`,
   `resources:["*"]`, and `save:["*"]`. This was the expected evidence gate, not a
   provider fault. The session was aborted and deleted after its sanitized shape was
   captured.
2. A broad binary text search produced large minified output. Narrow matching around
   `todowrite` then exposed the exact pinned tool body: permission assertion followed by
   only the current session todo-store update.
3. The first offline first-poll assertion counted every mocked permission HTTP call, so
   exact cleanup's DELETE made the count exceed one. The product behavior was correct.
   The test was fixed to count only `GET /api/session/<id>/permission` and then passed.
4. The first live unsupported-permission command was observed before its Bash EXIT trap
   had finished. Its clone was already gone while the record still showed cleanup
   pending. Waiting for the exact owner process proved cleanup completed correctly. The
   final canary ran under direct Git Bash and verified the finished record before
   deletion.
5. `bin/setup-opencode-glm.ps1` was run to reinstall canonical agent files. Its smoke
   test starts the service, then line 356 tries to overwrite the running
   `opencode-glm-service` wrapper. Windows locked that file and `Set-Content` failed.
   Stopping the service first did not help because the setup script's own smoke test
   restarted it before the same write. The agent files had already copied correctly,
   their hashes match, the service is healthy, and `ai-glm doctor` passes. This is a
   separate pre-existing installer ordering bug; this session did not widen scope to fix
   it.

## 5. Root causes and key findings

1. The pinned OpenCode 1.18.12 binary defines TodoWrite as a session-state tool. Its
   exact body asserts permission `{action:"todowrite", resources:["*"], save:["*"]}`
   and calls the todo service's `update` with the current session ID and todo array. It
   contains no filesystem, shell, network, or outside-content operation.
2. The live API matches the binary exactly. Therefore `*` is safe only as data scoped to
   normalized action `todowrite` with both exact singleton arrays. Treating it as a path
   or a general allow rule would be unsafe.
3. Permission detection already runs before status and completion checks on every poll
   (`bin/ai-glm:538`). The missing piece was durable implementation evidence at that
   boundary, not another timer or polling loop.
4. Marking a job `failed` on that first poll creates a short cleanup window. The name
   lock still blocks duplicates, but delete and dead-owner recovery also need to respect
   pending cleanup. The new guards at `bin/ai-glm:975` and `:998` preserve the completed
   v3 lifecycle and its exact-resource ownership rules.
5. A failed permission turn can contain unexported clone changes, but there is no safe
   partial-patch contract in this phase. The durable boolean reports their existence;
   `patch_exists:false` and `patch_path:null` state truthfully that nothing was exported.
6. Completed-turn token/cache usage logic was not changed. Kimi files and behavior were
   not touched.

## 6. Exact next steps

1. Run final `ai-glm doctor`, `git diff --check`, and the bounded secret-pattern check on
   owned added lines. You will know this worked when doctor is green, diff check prints
   no error, and no credential-like value appears.
2. Recheck `git status`, stage only the seven implementation/doc/test files plus this
   handoff, and verify the staged path list. You will know this worked when `.ai/` and
   `docs/claude-remote-control-hardening-v2.md` are absent from the index.
3. Recheck author and committer identity, commit to `main`, and push `origin main`. You
   will know this worked when GitHub accepts the push and local `HEAD` equals
   `origin/main`.
4. Because this workstream will then be proven done, delete only this handoff file in a
   small closeout commit, push again, and verify local/remote equality. You will know it
   worked when the file is absent from the current tree but preserved in Git history.

## 7. Constraints and gotchas in force

- Never make wildcard `*` generally acceptable and never allow an unknown action.
- Keep read/list/glob/grep resources inside the canonical session directory.
- Preserve the OpenCode 1.18.12 pin, GLM-5.2 pin, strict stop-plus-two-idle completion
  rule, 1,800-second turn bound, remote-less clone, full-run name lock, exact abort, and
  conservative dead-owner reconciliation.
- Do not implement or export incomplete partial patches in this phase.
- Do not change completed-turn usage logic or touch Kimi.
- Work on `main`; stage only owned files and preserve concurrent work.
- Never expose a secret. Real values stay in 1Password vault `vibe_coding`.
- GPT-5.6 reasoning effort stays low or medium.
- No production, shared-cloud, database, or deployment mutation is in scope.

## 8. Access and environment

- Machine: `al8960ofc`, Windows 11, PowerShell 7, Git Bash.
- Repository: `C:\repos\ai-devops`, GitHub `u2giants/ai-devops`, branch `main`.
- Local OpenCode service: authenticated loopback port 4096, pinned version 1.18.12,
  Scheduled Task `AiDevOps-OpenCodeGlm`.
- `ai-glm doctor`, live provider access, Git, `gh`, `jq`, and the skill installer work.
- OpenCode/GLM credentials are resolved from 1Password vault `vibe_coding`; no value was
  read into chat, a repo file, or the handoff.
- There is no CI workflow or hosted deployment for this toolkit. Those gates are N/A.

## 9. Open questions and risks

- No question blocks closeout.
- A future OpenCode upgrade may change TodoWrite's action or resource shape. Unknown or
  changed shapes will fail closed until the new pinned binary and live API are measured.
- The Windows setup-script file-lock ordering defect described in section 4 is outside
  this workstream and still exists. It did not prevent canonical agent installation or
  live verification here, but a future setup-focused session should reproduce and fix
  its root ordering without weakening the smoke test.

## Mandatory self-audit

1. **Yes.** Sections 1-3 define the toolkit, safety model, exact task, code state, file
   references, tests, hashes, and remaining Git state so a newcomer can continue without
   asking a question.
2. **Yes.** Sections 4-5 preserve every failed attempt, the exact binary/live findings,
   the cleanup race reasoning, and the installer side finding. A new session has the
   same evidence and judgment this session has.
3. **Yes.** Sections 2-9 cover background, goals, outcome, current state, failures,
   decisions, constraints, access, risks, exact next actions, and verification gates.
   Commit/push and N/A CI/deploy state are explicit; secrets are referenced only by
   vault name.
4. **Yes.** A line-by-line sweep of sections 1-9 found no sentence needing Albert's
   approval or judgment. The only side finding is an engineering bug with a defined
   future repair, not an owner decision. Section 0 therefore truthfully says none and
   lists the settled safety decisions that must not be re-asked.

Self-audit passed on 2026-08-10. All ten required sections are present, every next step
has a verification gate, failed attempts are complete, and no owner decision is hidden
outside section 0.
