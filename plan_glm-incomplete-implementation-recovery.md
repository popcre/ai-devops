# Plan: preserve incomplete GLM implementation work safely

## STATUS

| Step | State | Date | Evidence |
|---|---|---|---|
| 1. Lock design and current evidence | done | 2026-08-10 | Session specification in Git history under `HANDOFF.d/`; all prior GLM safety controls retained. |
| 2. Add truthful outcomes and incomplete artifact export | done | 2026-08-10 | `bin/ai-glm` exports binary incomplete patch/report before cleanup, no empty failure patch, and preserves only an exact clone after export failure. |
| 3. Complete offline regressions | done | 2026-08-10 | Final full offline run: 190 passed, 0 failed. Later long-path cleanup branches were proved by Bash syntax, a canonical long-path clone/remove probe, and the bounded end-to-end live abort. |
| 4. Verify live, install skills, and land | done | 2026-08-10 | Windows 25/0; MCP secret launcher passed; `ai-glm doctor` passed; changed-work live abort ended `aborted-partial`, wrote a patch that applied to base `942cf90c...`, removed clone/session, and left the real repo clean; installed Claude/Codex skill SHA-256 matched source. Commit/push evidence is recorded in the final landing commit. |

## 1. Ultimate goal

When GLM changes its remote-less disposable clone but cannot prove completion because
of usage limit, provider/network/service failure, timeout, safe permission rejection,
or user abort, preserve a clearly marked `.incomplete.patch` and `.incomplete.md`
before cleanup. Return nonzero, never touch or auto-apply to the real repository, make
no empty patch after a no-change failure, and preserve the exact clone only when durable
artifact export itself fails.

The goal wins over any conflicting implementation detail. Never weaken remote-less
isolation, exact provider/model verification, fail-closed permissions, review safety,
strict completion, full-run locks, or exact-owner cleanup to satisfy a step.

## 2. Application and scope

`u2giants/ai-devops` is a public Bash, PowerShell, test, skill, and documentation
toolkit. `bin/ai-glm` is the supported wrapper for the local authenticated OpenCode
1.18.12 service and pinned Z.ai `glm-5.2` model. Reviews are persistent and read-only.
Implementations are one-shot jobs in a disposable Git clone with `origin` removed.

This plan changes only GLM lifecycle code, tests, canonical GLM docs, and the shared
ask-glm skill. Kimi, production, shared cloud, databases, credentials, and OpenCode's
pin are out of scope.

## 3. Root cause and design

The v3 job lifecycle made implementation jobs visible, exclusive, abortable, and
recoverable, but failure cleanup removed the clone before useful changed work became
durable. The repair keeps `status` as a small control state and adds bounded `outcome`
and `failure_kind` fields. Outcomes distinguish completed, failed, aborted, timed out,
usage limited, permission failed, partial, no-change, and artifact-export failure.

One idempotent owner finalizer validates the v3 record, canonical clone, and live lock
PID. It exports a binary patch and bounded secret-safe INCOMPLETE report, then removes
the clone and exact server session. No-change failure records truth and creates no
patch. Export failure records `artifact-export-failed`, preserves the exact clone, and
prints recovery instructions. The abort control process still never deletes a clone.

Provider usage is `pending` while active, `unavailable` after failure, and `final` only
when OpenCode officially returns a token object. Metadata stores no prompt, response,
credential, secret, or unbounded provider text.

## 4. Locked controls

- Remote-less clone, never a Git worktree.
- Exact provider/model pin and runtime verification.
- Review structural safety and exact measured TodoWrite permission shape.
- Completion only after `finish=stop` plus two consecutive idle polls.
- Full-run repository/caller/name lock and durable v3 job record.
- Complete and incomplete artifacts have different names and reports.
- Incomplete work remains nonzero and is never described as safe or tested.
- No auto-apply, no remote restoration, and no real-repo write.
- One owner finalizer; control-process abort targets only the exact server session.
- Ambiguous, forged, foreign, outside-root, or wrongly owned paths are preserved.
- Prior carried tracked changes continue to enter the disposable clone and patch.

## 5. Required verification

Offline tests cover every outcome pair, tracked/untracked/binary changes, no-change,
prompt/secret redaction, destination/move/metadata export failures, abort races, exact
ownership, idempotent finalization, dead-owner recovery, and completed-run
compatibility. Wider gates are Bash syntax, the full GLM suite, Windows scripts,
doctors, secret launch tests, a bounded live GLM abort after a harmless change, shared
skill reinstall, and Claude/Codex source hash equality.

Landing requires Albert's exact Git identity, owned files only, `main`, a successful
push, and proof that local `HEAD` equals `origin/main`. This repo has no CI workflow or
application deployment, so those gates are N/A.

## 6. Risks and rollback

A partial patch can be broken or unsafe. Filename, report, nonzero exit, manual
`git apply --stat` and `git apply --check`, full hunk review, and rerun tests are the
controls. Provider wording can change, so only narrow measured billing text maps to
usage-limit and all unknown failures remain generic. Artifact storage can fail, so the
exact remote-less clone is retained rather than destroying the only copy.

Rollback is a normal Git revert. It restores the old safe but lossy failure behavior.
Never roll back by weakening isolation or copying incomplete files into a real checkout.
