---
issue: 38
status: OPEN
owner: codex/gemini-qualification-closeout
---

# Gemini governed qualification and reviewer closeout — 2026-08-25

This is the authoritative continuation record for the remaining Gemini work in
`u2giants/ai-devops`. Read this file, then `AGENTS.md`, then
`plan_gemini_reviewer_safety_repair.md` end to end. Also read the predecessor
`HANDOFF.d/2026-08-24T1503Z-edge-dev-claude-gemini-qualification-record.md` for
the pre-implementation evidence and cross-platform canary history. Do not resume
the eight-hour verification loop described below.

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put this whole list to Albert in one message before starting. Do not raise items
one at a time.

### Blocking

**None.** Gemini is safely quarantined, the local work is recoverable, and all
remaining actions are authorized by Albert's instruction to proceed.

### A wrong guess is recoverable, but confirm before relying on it

**None.** Albert's 2026-08-24/25 instruction to proceed accepted the recommended
per-machine qualification design: a machine is available only after its own
exact wrapper and runtime bytes pass the live canary.

### Not part of this work, and nobody is on it

1. **Issue #62 remains broader than reviewers.** Its Windows restore proof,
   GitHub-managed `refs/pull/*` cleanup, and cross-machine release alignment are
   separate work. GitHub Support is still required for the pull refs. Recommendation:
   start that workstream only after Gemini issue #38 is closed.

### Already settled — do NOT re-ask

1. Qwen live testing remains waived while credits are exhausted; keep it
   quarantined (owner decision, 2026-08-23).
2. Preserve every reviewer capability. Do not remove, disable, bypass, replace,
   or stop using Gemini as a substitute for repair.
3. Work directly on `main`; no feature branch, force push, broad staging, or
   destructive reset.
4. Production installation runs as user `ai`, never root.
5. Per-machine Gemini qualification is the accepted fail-closed design
   (Albert said “proceed” after it was presented, 2026-08-24/25).

## 1. What this application is

`C:\repos\ai-devops` is the Windows checkout of the public
`u2giants/ai-devops` backup-and-restore toolkit for POP Creations' multi-model AI
workflow. It contains reviewer wrappers, safety/evidence helpers, installers,
skills, and offline verification. It is not a web application or database.

Production means GitHub `main`, a green exact-head `verify` workflow, and the
Ubuntu installation reached as SSH alias `vps`, login `ai`, repository
`/worksp/ai-devops`, with installed source and managed hashes matching GitHub.

## 2. What we set out to do this session, and why

The final fleet objective is to make Gemini the ninth safely operating reviewer
and prove it on real open issue #38. Gemini's hostile live canary already passed
on Windows and Ubuntu, but the wrapper had no durable governed release path.

This session implemented a machine-local qualification record that binds the
exact `bin/ai-gemini` bytes, Antigravity `agy` executable bytes and version, and
configured model. It also made qualification revoke old approval before retry,
detect replacement during qualification, revalidate immediately before every
provider call, and make generic `check gemini --live` perform a genuine live
probe rather than claim one falsely.

## 3. Current state — what is true right now

### Git and environments

- The task implementation is the **unpublished** commit
  `e07fbf937b742e71f92d160b28b6b845b193034f` (`e07fbf9 fix: govern Gemini live qualification`).
  This handoff is committed immediately on top of it, so use `e07fbf9` as the
  exact code-review target until a later source change supersedes it.
- `origin/main` is still `2d4cb75470063e613493cdb10b0d8276d1575f3d`.
- Ubuntu `/worksp/ai-devops` is installed and manifest-verified at `2d4cb75`.
- Exact-head CI run `32820452816` for `2d4cb75` succeeded. That commit is now
  superseded locally and its CI does not qualify `e07fbf9`.
- Gemini remains quarantined on Ubuntu. Windows qualification attempted once
  against `2d4cb75`, failed safely before provider contact because Windows
  `sha256sum` escaped a backslash-bearing executable path, and wrote no record.
- Issue #38 is OPEN: https://github.com/u2giants/ai-devops/issues/38.

### Local implementation

Task-owned files in commit `e07fbf9`:

- `bin/ai-gemini`
- `bin/ai-review-preflight`
- `tests/test-ai-gemini.sh`
- `tests/test-ai-review-preflight.sh`

Implemented behavior:

- strict version-2 JSON qualification record under
  `${AI_REVIEW_QUARANTINE_DIR:-$HOME/.local/state/ai-devops/review-quarantine}/gemini-live-qualified.json`;
- binding to wrapper SHA-256, `agy` SHA-256, `agy --version`, model, provider,
  record version, and qualification epoch;
- old qualification revoked before every new canary;
- wrapper/runtime/model checked before and after the canary;
- record written atomically by `ai-review-preflight`, never self-authored by
  `ai-gemini`;
- exact identity revalidated immediately before each real review and `/model`
  provider execution;
- `agy` hashing uses stdin so Windows native paths cannot add GNU filename
  escape prefixes;
- `doctor --live` performs the real hostile qualification probe, while unknown
  doctor options fail closed;
- Gemini preflight uses the longer governed qualification timeout for that live
  probe.

### Verification evidence

- Latest targeted tests: `tests/test-ai-gemini.sh` **60 passed, 0 failed**;
  `tests/test-ai-review-preflight.sh` **50 passed, 0 failed**.
- Several complete master gates passed earlier (53 Bash suites and 16
  PowerShell suites), but they predate the final genuine-live-preflight change.
- The final master gate for `e07fbf9` was restarted after the local monitor
  unexpectedly terminated the first attempt. Albert then stopped the second
  attempt after correctly observing the session had run for eight hours. It did
  not report a test failure, but it did not reach a terminal summary and must
  not be counted.
- The latest independent review applies to predecessor commit `e261e93` and
  returned REJECT because `check gemini --live` falsely claimed a live check.
  Report: `.ai/reviews/codex-final-check-20260825T100727-1470608-18965.md`.
  `e07fbf9` fixes that finding but has not received an independent review.

## 4. Everything we tried that did NOT work

1. **Repeating the full 40–60 minute repository gate after every reviewer
   rejection.** Each reviewer found real defects, but running the entire gate
   before the next review created an eight-hour loop. Correct sequence: targeted
   tests and independent-review iterations until APPROVE, then exactly one full
   master gate on the approved source.
2. **Hashing the wrapper only after qualification.** A concurrent replacement
   could authorize untested wrapper bytes. Fixed with before/after wrapper hash
   comparison and a deterministic replacement test.
3. **Leaving an old record during failed requalification.** A failed repeat
   could say quarantine remained while the previous record still authorized
   Gemini. Fixed by revoking the record before any new canary.
4. **Binding only `agy --version`.** Same-version runtime replacement remained
   possible. Fixed by recording and validating exact `agy` bytes.
5. **Accepting a `QUARANTINED` doctor line in preflight.** The first mock encoded
   this defect. Fixed by requiring doctor exit 0 and an exact `PASS` prefix for
   availability.
6. **Validating runtime only at wrapper startup.** Runtime bytes could change
   during snapshot preparation. Fixed by revalidating immediately before every
   actual provider execution; targeted race test passes without contact.
7. **Hashing `agy.exe` by filename on Windows.** GNU `sha256sum` emitted a leading
   backslash because the native filename contained backslashes, producing a
   65-character value. Fixed with `sha256sum < "$a"`; live doctor now emits the
   clean 64-character digest beginning `98ce5e...`.
8. **Letting `doctor --live` silently ignore `--live`.** Generic preflight then
   claimed `allowance=live-verified` after no model call. Fixed locally by a real
   live canary path and regression test.
9. **Counting partial or killed master gates.** Only a terminal summary counts.
   The interrupted run is not evidence.

## 5. Root causes and key findings

1. Qualification is a capability grant, so every identity in the execution
   chain must be bound: wrapper bytes, runtime bytes/version, and model.
2. Qualification must be rechecked at the last practical point before execution,
   not merely during shell startup.
3. Requalification is revocation followed by proof; failure must leave no old
   authorization behind.
4. Provider status must be truthful. An offline doctor cannot satisfy a command
   that reports live allowance verification.
5. Cross-platform path behavior matters even when the digest algorithm is the
   same. Hashing stdin avoids GNU filename escaping differences.
6. Independent review materially improved this code. Rejections found the
   wrapper-replacement race, stale-record behavior, runtime-byte gap, status
   parser defect, post-start runtime race, and false live-preflight claim.
7. The process failure was verification ordering, not a hung command. Full gates
   were individually completing; repeating them before design convergence was
   wasteful and degraded the session.

## 6. Exact next steps

1. **Re-establish live Git state.** Run `git fetch origin main`, `git status
   --short`, `git rev-parse HEAD`, `git rev-parse origin/main`, and
   `git var GIT_COMMITTER_IDENT`. If `origin/main` moved, inspect the new commits
   before reconciling. You'll know it worked when the checkout is clean, identity
   is Albert's noreply address, and ancestry is explicit.
2. **Inspect only the current four-file diff and latest rejected report.** Confirm
   the genuine-live-preflight fix directly answers the report. You'll know it
   worked when `doctor --live` cannot silently fall back to offline doctor and
   unknown options fail.
3. **Run targeted tests only:** Git Bash
   `bash tests/test-ai-gemini.sh` and
   `bash tests/test-ai-review-preflight.sh`. Expected current totals are 60 and
   50, zero failures. You'll know it worked from both terminal summaries.
4. **Run independent review now, before another full gate:**
   `AI_CODEX_REVIEW_CALLER=codex bin/ai-codex-review final-check --tests "bash tests/test-ai-gemini.sh && bash tests/test-ai-review-preflight.sh"`.
   Fix findings with targeted tests and repeat review only. Do **not** run
   `tests/test-all.ps1` between review iterations. You'll know design converged
   when the newest report has terminal `## Verdict` = `APPROVE`.
5. **After APPROVE, run one complete master gate:**
   `pwsh -NoProfile -File tests/test-all.ps1`. This includes the full Bash suite
   and 16 PowerShell suites. Run it once on the approved source. You'll know it
   worked when `OFFLINE COMPLETE SUMMARY ... failures=0` appears.
6. **Reconcile and push without force.** If `origin/main` moved after review,
   rebase/reconcile, rerun targeted tests and the exact-source independent review;
   do not automatically repeat the full gate until approval is current. Push
   only when reviewed source and current `main` match. You'll know it worked when
   `origin/main` equals the reviewed commit.
7. **Wait for exact-head CI.** Require all jobs in the `verify` run to report
   success. You'll know it worked when GitHub's run SHA equals `origin/main` and
   conclusion is `success`.
8. **Install on Ubuntu as `ai`, never root:** pull fast-forward and run
   `./install.sh --skip-secrets`, then `ai-devops doctor` and preflight status.
   You'll know it worked when source/manifest hashes equal GitHub and Gemini is
   still quarantined before qualification.
9. **Qualify Windows through the repo source first:** from Git Bash run
   `bin/ai-review-preflight qualify gemini`, then status. This is paid live work.
   You'll know it worked when one record is written and status is `available`.
10. **Qualify Ubuntu through installed commands:** over SSH as `ai`, export
    `PATH="$HOME/.local/bin:$PATH"`, run `ai-review-preflight qualify gemini`, and
    check status. You'll know it worked when Ubuntu independently reports
    `available`.
11. **Run the real issue #38 review.** Save `gh issue view 38` to a prompt file,
    use a short session name within the 64-character tag limit, and run Gemini.
    A truthful APPROVE, REJECT, or BLOCKED counts as reviewer success. You'll know
    it worked when `.ai/reviews/` has a durable report binding model, conversation,
    exact head, packet, and verdict.
12. **Close out documentation and issue.** Update Step 6 in
    `plan_gemini_reviewer_safety_repair.md`, finding 25 in `bugs.md`, and add a
    verification note under
    `tests/verification/reviewer-production-completion/`. Comment on and close
    issue #38, then delete both this handoff and the predecessor handoff only
    after every carried obligation is retained elsewhere. Commit/push and require
    green CI for this closeout commit. You'll know it worked when all nine reviewer
    rows cite direct artifacts and no stale Gemini handoff remains.
13. **Reciprocal whole-plan check.** At the end of each phase, re-read every
    downstream step in this section and the entire remaining
    `plan_gemini_reviewer_safety_repair.md` through plan-end. Report and record any
    assumption, interface, path, or evidence drift before handing off or moving
    on.

## 7. Constraints and gotchas in force

- Preserve Gemini capability; quarantine is a safety state, not completion.
- Never clear quarantine by editing source flags or state manually.
- Reviewer safety changes require one independent read-only exact-source review
  with critical tests bound into its packet.
- Do not repeat the full gate during reviewer design iteration. Targeted tests +
  review until APPROVE; one full gate afterward.
- Work directly on `main`; no branch, force push, broad staging, or destructive
  reset. Several sessions share the checkout.
- Production installs run as `ai`, never root; never live-edit the server.
- Never print raw process command lines, provider payloads, or credential values.
- Never use `--dangerously-skip-permissions` or mutate global Antigravity settings.
- `agy` was 1.1.20 on Windows at the last live doctor check; treat this as live
  state and rederive it before qualification. Ubuntu may differ until checked.
- A truthful negative reviewer verdict is success; availability is not the same
  as APPROVE.

## 8. Access and environment

### Windows

- Host `edge-dev`, checkout `C:\repos\ai-devops`, PowerShell 7.
- Git Bash: `C:\Program Files\Git\bin\bash.exe`.
- SSH: `C:\Program Files\Git\usr\bin\ssh.exe`.
- `gh` authenticated as `u2giants`; committer must be
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Antigravity is authenticated. Latest observed Windows version: 1.1.20.

### Ubuntu production

- SSH alias `vps`, login `ai`, repo `/worksp/ai-devops`.
- Runtime config `/etc/ai-devops/`; state
  `/home/ai/.local/state/ai-devops/`.
- `agy` installed under `~/.local/bin/`; export that path for direct calls.
- Current installed commit `2d4cb75`; Gemini quarantined.

### Credentials

- Approved vault: 1Password `vibe_coding`. Never expose values.
- No credential change is needed for this work.

## 9. Open questions and risks

1. **Independent reviewer convergence (2026-08-25).** The latest local live-path
   fix is unreviewed. A new reviewer may find another issue; fix it with targeted
   tests before the single final full gate.
2. **Runtime replacement gap (2026-08-25).** Revalidation occurs immediately
   before execution, which is the practical cross-platform boundary. If a review
   demands execution from an already-open immutable descriptor, assess Windows
   feasibility explicitly rather than inventing an unsafe workaround.
3. **Paid live checks (2026-08-25).** `check gemini --live` now runs the hostile
   two-turn canary and is not a cheap status call. Use it deliberately.
4. **Concurrent `main` movement (ongoing).** Any new upstream commit after exact
   review can stale that review. Reconcile and review current source before push.
5. **Process discipline (2026-08-25).** This session degraded because full gates
   were repeated during design iteration. The next session must follow §6 steps
   3–5 exactly.

## Mandatory handoff self-audit

1. **Yes, a brand-new developer can continue without missing a beat.** §§1–3
   define the repository, objective, exact local/GitHub/production split, files,
   commits, issue, and evidence.
2. **Yes, they can continue as effectively as this session.** §§4–5 preserve all
   failed approaches, every independent-review discovery, the Windows hashing
   trap, and the eight-hour process failure.
3. **Yes, every execution-critical detail is present.** §6 gives ordered commands
   and proof gates through review, full verification, push, CI, install,
   qualification, real issue review, documentation, issue closure, and handoff
   retirement; §§7–9 carry constraints, access, and risks.
4. **Yes, Section 0 contains every owner decision.** A line-by-line sweep of
   §§1–9 found no blocking owner action; the accepted per-machine design and
   standing decisions are listed as settled, while the separate issue #62 owner
   action is promoted under “not part of this work.”
