---
issue: 1562
status: OPEN
owner: mimo/1562-deepseek-windows-cygpath-v2
---

# DeepSeek final-check follow-ups after the Windows ACL and cygpath fixes

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs the owner.

**Already settled — do NOT re-ask:**
- 2026-10-12: Keep the redacted reviewer-issue notes on main and relax the public-boundary gate (owner words: "keep the notes on main and relax the gate"). Done and shipped.

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery toolkit for a multi-model AI
review workflow. It is not an app or service. Reviewer wrappers, door
diagnostics, CI suite manifests, and safety gates live here. The repository is
https://github.com/popcre/ai-devops.

## 2. What we set out to do this session, and why

DeepSeek's final-check on commit
[e8584976](https://github.com/popcre/ai-devops/commit/e858497680b8a44f1473f3ebe932fb68cc254478)
returned BLOCKED with two findings under issue
[#1562](https://github.com/popcre/ai-devops/issues/1562):

1. Medium — the Windows gemini door-response suite could blow the section
   budget because private-ACL work spawned PowerShell four times per failure
   case.
2. Low — an unguarded `cygpath` call could abort the approval-report lookup.

Both were fixed, reviewed, proven on a Windows host, and merged. A third
owner decision (keep reviewer-issue notes on main) landed as gate work in the
same stretch.

## 3. Current state — what is true right now

**Done and on `main`:**
- https://github.com/popcre/ai-devops/pull/1644 merged as
  [af45365b](https://github.com/popcre/ai-devops/commit/af45365b56a68a30916570064868f49d1f6dd27e)
  — batched private-ACL (directory first, then all files in one child),
  ACL-refusal cleanup, cygpath bounded to 5s with fall-through.
- https://github.com/popcre/ai-devops/pull/1641 merged as
  [22bc08d7](https://github.com/popcre/ai-devops/commit/22bc08d7eabc8704e16bc7f55a92a756627741a3)
  — secret-bearing file types stay banned even under `.ai/reviewer-issues/`.
- Codex exact-head final-check APPROVE on
  [f01e1828](https://github.com/popcre/ai-devops/commit/f01e18282c78486470689c30a14fbe1f7d23fc35)
  (the PR 1644 head before landing).
- Windows host 916 proof: door-diagnostics ~4.8s, gemini-door-response 21
  checks in ~32s (was >600s timeout), cygpath unit tests 4/4.

**Not started / deferred (this handoff's reason to exist):**
- Codex Low (non-blocking) on the same review: the cygpath fall-through
  regression test is weak. It rewrites both synthetic candidates to POSIX
  paths and accepts `None`, so an early `return None` would still pass.
  Evidence line from that report: "The regression test claims to verify
  fall-through, but rewrites both candidates and accepts `None`, so it would
  not detect an early return." Production code correctly continues; only the
  test is weak.

## 4. Everything we tried that did NOT work

- **One PowerShell call for directory + files together, files created first.**
  Codex REJECTED
  [ba6133b8](https://github.com/popcre/ai-devops/commit/ba6133b8)
  (High): creating files before ACL hardening left an inherit-window race.
  Fixed by securing the empty directory first, then batch-verifying files.
- **Exception list naming only `FileNotFoundError`/`TimeoutExpired`.**
  Main had already landed a looser `OSError`/`SubprocessError` guard. Cherry-pick
  conflict. Resolved by keeping main's broader handler and our tighter
  `timeout=5`.
- **`*.env` as a full-path case pattern.** Codex REJECTED the first gate PR:
  `.env.local` under reviewer-issues still matched the generated-artifact
  exemption and skipped the secret rule. Fixed by matching secret names by
  basename, like `.gitignore`.
- **Duplicate gate PR.** PR 1636 was closed as superseded by
  [#1635](https://github.com/popcre/ai-devops/pull/1635) which had already
  landed the reviewer-issues allowance. We then shipped only the secret-type
  hardening as PR 1641.

## 5. Root causes and key findings

- Windows ACL cost is per PowerShell *process*. Four spawns per failure case
  (~22s) times ~17 cases blew a 600s suite. Two calls (dir, then batched
  files) keeps the security order and cuts the cost ~50%; the test's
  per-case ACL proof was also reduced to once.
- A `case` pattern that matches an exemption first skips later rules in the
  same `case`. Secret-type checks must run even under allowed subtrees.
- Bash `case` globs match the whole path; `.env.*` does not match
  `.ai/reviewer-issues/.env.local`. Match basenames.
- `--assert-head` on `ai-review` needs the **full** 40-char SHA.

## 6. Exact next steps

1. Tighten
   [tests/test_reviewer_events_cygpath.py](https://github.com/popcre/ai-devops/blob/main/tests/test_reviewer_events_cygpath.py)
   so fall-through is observable: give two candidates where the first would
   be a winner if cygpath succeeded, force cygpath failure on the first only,
   and assert the **second** candidate is returned (not `None`).
   You'll know it worked when the test fails if `find_passing_report` returns
   early instead of continuing.
2. Run `python tests/test_reviewer_events_cygpath.py` and the pool dispatch
   suite on a Windows host.
3. Open a small PR against `popcre/ai-devops`, get a non-implementer
   exact-head review if the change touches reviewer safety paths, merge via
   the queue.

## 7. Constraints and gotchas in force

- Never push to `main`; feature branch + PR + merge queue.
- Reviewer-safety class: independent non-Claude exact-head review before
  merge for evidence tools and safety tests.
- `ai-review --assert-head` requires a full 40-char SHA.
- Do not rewrite root `HANDOFF.md` (it is `handoff-pointer: v1`).
- Public boundary: `.ai/reviewer-issues/**` is allowed; every other `.ai/*`
  and secret-bearing basenames are not.

## 8. Access and environment

- Machine: `edge-dev` (this session). Windows proof host: `ssh 916`
  (916-alien).
- GitHub via `bin/ai-gh` wrapper on `popcre/ai-devops`.
- Secrets: 1Password vault `vibe_coding` if any appear later; none used here.

## 9. Open questions and risks

- 2026-10-13: The cygpath test weakness is non-blocking and ships as-is on
  main. Do not treat green CI as proof the fall-through path is covered.
- 2026-10-13: Main moves quickly on this repo. Rebase before editing; the
  cygpath guard already changed once under us today.
