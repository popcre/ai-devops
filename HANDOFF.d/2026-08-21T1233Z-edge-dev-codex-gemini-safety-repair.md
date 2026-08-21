---
issue: 38
status: BLOCKED
owner: codex/gemini-safety-repair
---

# HANDOFF — Gemini reviewer safety repair (2026-08-21 12:33 UTC, edge-dev/codex)

## 0. Decisions only the owner can make

None now. Already settled on 2026-08-21: Gemini stays quarantined and cannot
approve work until live hostile tests pass on both Windows and Ubuntu. Do not
ask Albert to weaken this gate.

## 1. What this application is

`u2giants/ai-devops` is the public repository that installs Albert's AI review
commands. `bin/ai-gemini` asks Google's Antigravity command (`agy`) for a
Gemini review in a disposable copy, not in the source checkout. Issue
https://github.com/u2giants/ai-devops/issues/38 tracks qualification.

## 2. What we set out to do this session, and why

Fix audit findings 3–6 and 25 in [`../bugs.md`](../bugs.md): changes could evade
the old file check, a missing report could still produce PASS, the wrong resumed
conversation could be accepted, calls had no durable running/recovery state,
and the plan/router/skill contradicted the code.

## 3. Current state — what is true right now

Steps 1–4 of [`../plan_gemini_reviewer_safety_repair.md`](../plan_gemini_reviewer_safety_repair.md)
are implemented locally. `bin/ai-gemini` now inventories the disposable copy,
protected checkout, and named outside sentinels around both the review call and
the separate model-confirmation call. It creates metadata before provider work,
locks each repository/session, records recovery-required failures, matches the
exact conversation/model, and refuses PASS unless an ignored, nonempty report
is saved atomically. `tests/test-ai-gemini.sh` supplies an offline fake provider
and hostile cases. The router, historical plan, current plan, and shared skill
all say the reviewer is quarantined.

The work is on local `main` in `C:\repos\ai-devops-gemini-repair-20260821`.
It is not yet committed or pushed. No installed command was changed. Step 5 is
blocked because no Windows or Ubuntu live hostile evidence exists. Step 6 must
not install, push from this subtask, unquarantine, or close issue #38.

## 4. Everything we tried that did not work

- Calling `bash` from PowerShell selected Windows Subsystem for Linux, which has
  no Linux installation on this machine. Use
  `C:\Program Files\Git\bin\bash.exe` for all Bash tests.
- The interrupted implementation checked file identity around the main Gemini
  turn but not around `/model`. That left a second provider call able to change
  files. The same inventory gates now surround `/model`, with a hostile test.
- Git status text is not an identity check: an already-modified or ignored file
  can change while status looks the same. The wrapper now hashes every file and
  link in the handed directory and explicitly hashes configured outside files.

## 5. Root causes and key findings

Antigravity plan mode is advice, not enforced read-only behavior. Provider
`SUCCESS` is also not proof of completion because earlier live work returned an
empty successful response. Therefore acceptance needs independent file identity,
exact conversation/model, verdict structure, exact code version, and a durable
report. The latest logic is in `bin/ai-gemini`; the attack coverage is in
`tests/test-ai-gemini.sh`. Live safety remains unknown, so quarantine is the
correct business state.

## 6. Exact next steps

1. Run `C:\Program Files\Git\bin\bash.exe -lc 'bash tests/test-ai-gemini.sh'` and
   every shared suite named in plan section 10. It worked when all commands exit
   zero and the Gemini suite reports every named case passed.
2. Inspect the scoped diff and verify `git var GIT_COMMITTER_IDENT` is exactly
   `Albert Hazan <u2giants@users.noreply.github.com>`. Commit only the paths in
   section 3. It worked when one local commit contains no unrelated path.
3. The parent integration session should merge/cherry-pick that commit with the
   other seven reviewer repairs and resolve shared documentation deliberately.
   It worked when the combined repository suites pass.
4. A later authorized full-access session must run bounded, redacted Windows
   and Ubuntu hostile live qualification and save it under
   `docs/verification/ai-gemini/<UTC>/`. It worked only when both platforms keep
   every protected target byte-identical and return the exact model,
   conversation, verdict, code version, and durable report.
5. Only after step 4 may a session unquarantine, install, push, and close issue
   #38. It worked when installed hashes match GitHub and the issue links the
   evidence. Otherwise leave quarantine and the issue open.

## 7. Constraints and gotchas in force

Never use `--dangerously-skip-permissions`, change Albert's global Antigravity
settings, call `agy` directly to evade the wrapper, accept provider success as
approval, or delete uncertain evidence. A linked worktree must first become a
self-contained copy. This repository uses `main`; no force-push or broad staging.
GPT-5.6 effort is low or medium only.

## 8. Access and environment

GitHub CLI and machine-local Antigravity login are available on edge-dev, but
this subtask intentionally made no paid call. Authentication remains in
Antigravity's local state and no secret was read or written. Git Bash is at
`C:\Program Files\Git\bin\bash.exe`. The remote is
https://github.com/u2giants/ai-devops.git.

## 9. Open questions and risks

The only material unknown is whether current Antigravity can satisfy the hostile
tests on both supported systems. Byte comparison detects damage after a call; it
does not prove the provider lacked write capability, and named outside sentinels
cannot represent every computer path. That is why the wrapper and skill remain
quarantined. Concurrent agents may also change shared plan/router files before
integration; resolve by intent and never overwrite their work.

## Self-audit

1. Yes. Sections 1–3 explain the repository, issue, goal, files, and exact state.
2. Yes. Sections 4–5 preserve the failed Bash path, missed model-call gate, and
   reason status text/provider success are insufficient.
3. Yes. Section 4 records every failed approach encountered in this resumed work.
4. Yes. Section 6 gives ordered commands/actions and a proof gate for each.
5. Yes. Sections 1, 7, and 8 define the provider, paths, issue, branch, and tools.
6. Yes. A line-by-line sweep of sections 1–9 found no new owner decision; the
   quarantine decision is already settled and recorded in section 0.

The four synthesis checks pass: a new developer can continue without this chat;
they have the same relevant knowledge; background, failures, decisions, limits,
risks, next actions, and evidence are present; and section 0 contains the entire
owner-decision set.
