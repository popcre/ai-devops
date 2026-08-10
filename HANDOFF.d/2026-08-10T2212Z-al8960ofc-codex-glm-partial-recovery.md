# GLM incomplete implementation recovery

## 0. Decisions only the owner can make

None. Albert already locked the safety and product choices in the task dated
2026-08-10. This work does not need a new approval unless a current plan conflicts
with those controls. If a conflict appears, stop and raise the whole conflict once.

Already settled on 2026-08-10: incomplete GLM work is preserved only as a clearly
marked patch and report; it stays nonzero, is never auto-applied, and the real repo is
never changed. GLM keeps its remote-less clone, exact provider/model pin, fail-closed
permissions, strict completion rule, full-run name lock, and exact-owner cleanup.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public backup-and-restore toolkit for his AI
coding workflow. It is Bash, PowerShell, tests, skills, and Markdown. It is not a
hosted app and has no database or deploy step. This work changes `bin/ai-glm`, the only
supported wrapper around the local authenticated OpenCode 1.18.12 service and pinned
Z.ai `glm-5.2` model.

GLM reviews are persistent and structurally read-only. GLM implementations are
one-shot jobs in a disposable Git clone whose `origin` remote is removed. The wrapper
exports an artifact into the real repository's ignored `.ai/reviews/` directory. It
never applies that artifact.

## 2. What this session set out to do and why

Preserve useful GLM implementation edits when strict completion cannot be proven due
to usage limits, provider/network/service failure, timeout, safe permission rejection,
or user abort. Changed failed work must become `.incomplete.patch` plus
`.incomplete.md`; unchanged failures must create no empty patch. Artifact export
failure alone preserves the exact owned clone with loud recovery instructions.

The trigger is a lifecycle gap. The v3 job work made jobs visible and abortable, but
failure cleanup still deletes the remote-less clone without first exporting useful
incomplete edits.

## 3. Current state

- Repo: `C:\repos\ai-devops`, branch `main`, base and `origin/main`
  `942cf90c69f7fefb1074ec9fe16e2c323c25f5ba` at specification time.
- Git identity is already correct: `Albert Hazan <u2giants@users.noreply.github.com>`.
- Unrelated untracked `.ai/` and `docs/claude-remote-control-hardening-v2.md` exist and
  must remain unstaged.
- Unrelated open handoff `HANDOFF.d/2026-08-10T1138Z-albt16-codex-916-rollout.md`
  belongs to another session and must not be edited or deleted.
- `bin/ai-glm:709` has one cleanup owner, but it removes the clone before recording
  terminal state and has no incomplete artifact export.
- `bin/ai-glm:758` owns the current v3 implementation lifecycle.
- `bin/ai-glm:410-421` records permission failure evidence but does not export changes.
- `bin/ai-glm:849-870` writes only a completed patch after proven completion; failed
  patch or report writes still lead to clone cleanup.
- `bin/ai-glm:922` exposes only the current small failure fields.
- No source edits beyond this specification have started.

## 4. Everything tried that did not work

No new code attempt has failed yet. Prior rejected designs remain binding:

1. A worktree is unsafe because it shares the real repository's remotes.
2. Treating idle or exit zero as completion is unsafe; only `finish=stop` plus two idle
   polls proves completion.
3. Keeping every failed clone creates stale live state. Preserve a clone only when
   durable artifact export itself fails.
4. Auto-applying partial work makes unfinished output look trusted.
5. Recording prompts, full provider responses, or environment data risks secrets.
6. Inventing zero usage during an active or failed turn is false. Provider tokens are
   final only when OpenCode officially returns them.
7. An abort control process cannot remove a clone while its owner may still be writing.

## 5. Root causes and key findings

1. The isolation boundary works. The defect is ordering: cleanup deletes the only copy
   of changed failed work before a recovery artifact becomes durable.
2. The Kimi recovery implementation proves a safe artifact pattern, but only as a
   design reference. GLM must keep its own v3 record, remote-less clone, server-session
   cleanup, and exact ownership checks.
3. `status` is a small control state. A separate bounded terminal `outcome` plus
   `failure_kind` can truthfully express completed, partial, no-change, abort, timeout,
   usage, permission, and export-failed outcomes without destabilizing lock logic.
4. Complete and incomplete artifacts must differ in both filename and report title.
5. Git's binary diff is required so untracked and binary edits survive.

## 6. Exact next steps

1. Extend the v3 schema with bounded `outcome`, `failure_kind`, usage availability,
   incomplete artifact paths, artifact state, and safe reason fields. Keep prompts and
   responses out. The gate is malformed or unbounded metadata failing validation.
2. Refactor implementation finalization so one idempotent owner classifies the exit,
   checks Git changes, writes a binary incomplete patch and bounded INCOMPLETE report,
   then cleans the clone only after both are durable. The gate is every changed failure
   returning nonzero with durable artifacts and no clone.
3. On no-change failure, record the exact no-change outcome and create no patch. The
   gate is no `.incomplete.patch` file and truthful terminal metadata.
4. On artifact export failure, set `artifact-export-failed`, retain the exact validated
   clone and lock/record evidence, and print manual recovery steps. The gate is no
   deletion of foreign or ambiguous paths and loud exact recovery output.
5. Add offline fixtures for every requested outcome, tracked/untracked/binary changes,
   redaction, atomic failures, abort race, cleanup ownership, repeated finalization,
   and complete compatibility. The gate is the full offline GLM suite passing.
6. Update canonical GLM docs, development guidance, the shared ask-glm skill, and the
   current durable plan/status record if needed. The gate is no stale claim that failed
   changes are discarded or never exported.
7. Run Bash syntax, GLM offline/live suites, Windows, doctor, secret, and skill install
   and hash gates. Use one bounded harmless live abort/failure only if safe. The gate is
   dated evidence with no billing exhaustion or leaked secret.
8. Remove this handoff only after all proof, verify identity, commit owned changes on
   `main`, push, fetch, and prove `HEAD == origin/main`. The gate is matching SHAs and a
   clean owned diff.

## 7. Constraints and gotchas

- Do not touch Kimi.
- Never weaken remote-less clone isolation, provider/model verification, review tool
  safety, exact TodoWrite permission shape, strict completion, or full-run name locks.
- The complete patch exists only after proven completion. Incomplete patches are never
  called safe, complete, or tested.
- Preserve carried tracked changes from the real repo exactly as current code does.
- Abort targets the exact server session; only the owner finalizer handles its clone.
- One idempotent cleanup/finalization path owns every exit.
- Preserve foreign, forged, malformed, outside-root, or ambiguously owned paths.
- Do not store prompts, responses, credentials, secrets, or guessed provider usage.
- Preserve concurrent files and stage only owned paths. Main-only repository.
- PowerShell files remain ASCII if unexpectedly touched. GPT-5.6 effort remains low or
  medium. No production/shared-cloud mutation applies.

## 8. Access and environment

- Windows 11 host `AL8960OFC`, PowerShell 7 orchestration, Git Bash for Bash suites.
- GitHub remote `u2giants/ai-devops`, branch `main`.
- Local GLM service is authenticated on loopback port 4096 through `ai-glm`; never call
  OpenCode or its HTTP API directly.
- Secrets live in 1Password vault `vibe_coding`, item `GLM z.ai API`. No secret read is
  expected. Never print the value.
- Required tools are Git, Bash, curl, jq, and `gh`. The repository has no CI workflow,
  app URL, database, or deploy target.

## 9. Open questions and risks

- Provider failure wording varies. Only narrow measured usage-limit text may receive
  `usage-limit`; unknown failures remain generic and sanitized.
- A signal can race a final write. The owner must stop/observe the turn, then let one
  finalizer classify Git's final proved state.
- Disk or permission failure can prevent durable export. The only safe response is to
  preserve the exact owned clone and record recovery instructions.
- A partial patch may be broken or unsafe. The nonzero exit, `.incomplete` names,
  INCOMPLETE report, and manual `git apply --stat` plus `git apply --check` steps are
  mandatory controls.

## Mandatory self-audit

1. Yes. Sections 1-3 define the toolkit, exact defect, base, branch, and file evidence;
   section 6 gives ordered executable work with a proof gate for every step.
2. Yes. Sections 4-5 preserve rejected paths, lifecycle ordering, schema choice, and
   the distinction between GLM and the Kimi reference.
3. Yes. Sections 6-9 include implementation, tests, docs, landing, safety controls,
   access, secrets, risks, and rollback-safe behavior.
4. Yes. A line-by-line sweep of sections 1-9 found no owner decision. Section 0 records
   that all product and safety choices are already settled and says when to stop.

Self-audit passed on 2026-08-10.
