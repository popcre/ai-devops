# Issue #165 verification — session conduct and repository growth

Date: 2026-08-29

Source baseline: `5f3f56438f5440a8d524e490e70513c62f2ee7af`

## Acceptance evidence

- `tests/test-session-conduct-policy.sh`: PASS, 0 failures. It checks immediate
  failure reporting, independent useful work, bounded waiting, reuse ownership,
  rejects negated reuse wording, and routes consolidation to issues #167, #169,
  and #168.
- `tests/test-context-audit.ps1`: PASS. Cross-client parity, all locked safety
  categories, context budgets, and enforcement tests remain intact.
- `git diff --check`: PASS.
- Complete Windows offline gate: PASS on 2026-08-29. All 61 Bash suites and all
  17 PowerShell suites completed with zero failures; the Bash phase took 3,688
  seconds. This includes Grok 196/196, Kimi 203/203, GLM 244/244, Muse 128/128,
  Codex 41/41, and the repaired PR waiter 11/11.
- Independent read-only review runs `20260830T010757-49510-22940` and
  `20260830T011111-71217-10994` rejected earlier drafts. The first found that
  keyword-only assertions could accept negated wording and this evidence record
  was missing. The second found that the global checks did not yet require
  immediate failure reporting or independent useful work, and that completion
  was recorded before approval. All findings were corrected before the step was
  allowed to proceed. Final-check run `20260830T012004-118428-4882` then found
  two stale direct-to-main instructions in the active throughput plan; those
  now require the repository's branch, pull-request, and merge-queue route and
  are guarded by the policy test. Run `20260830T012340-129037-13989` caught an
  over-broad `main` expression matching the word `remains`; the expression now
  requires a real word boundary and the focused suite passes. Run
  `20260830T012706-143152-9029` found the plan's incorrect documentation-only
  classification and an API-failure path that bypassed `ai-pr-wait`'s deadline.
  The plan now requires normal code checks, and the waiter validates its bounds,
  caps every sleep to the remaining time, and exits at the deadline even when
  every GitHub API call fails. `tests/test-ai-pr-wait.sh` reproduces that path
  with a deterministic clock. Run `20260830T023601-511690-32036` found that
  zero-prefixed `00` bypassed the original numeric guard; both timeout and
  interval now reject leading-zero values, with explicit regression cases.

## Independent review

Run `20260830T011433-94859-14746`: APPROVE. The sealed review packet ran the
focused policy test, context audit, and diff check itself; it reported no
findings or material test gap. The plan moved from `review gate` to `done` only
after this approval, then returned to `implemented; merge pending` because the
required `origin/main` commit cannot be recorded before GitHub merges the step.
The final merge commit will be added before issue #165 is closed.
