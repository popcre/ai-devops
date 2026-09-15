# Issue #166 — final required-check cutover and throughput proof

Verified on 2026-09-15 against `popcre/ai-devops` `origin/main`.

## Live ruleset

Ruleset `21564317` remained active on the default branch. Its required context
is the stable `verification-closure` aggregate, which reports on pull requests
and merge groups and fails closed unless `linux-offline`, `windows-offline`, and
`windows-reviewer-safety` have acceptable results. No stale job name was found,
so no ruleset write was needed.

Deletion and non-fast-forward protection remain active. The recovery bypass is
`OrganizationAdmin`, mode `always`. Merge queue settings remain `ALLGREEN`,
`max_entries_to_build: 5`, `max_entries_to_merge: 5`, and
`min_entries_to_merge: 1`. Issue #164's run `34440507656` remains the injected
failure/recovery proof; #166 introduced no new deliberate failure.

## Exact canary and waiter repair

PR #475 used exact reviewed head `d31f20f31554df990a491c0da50f816a03e3c236`.
Its first bounded wait exposed the known deadline wording defect without a CI
failure: the waiter attempted a zero-time read after its deadline and mislabeled
an ordinary pending PR as an API read error. The landed repair gives a distinct
pre-call deadline result while preserving genuine request timeout diagnostics.

`tests/test-ai-pr-wait.sh` passed 27/27 on the exact head. GLM 5.3 independently
returned APPROVE against sealed base `c95ecc72838de98f493327df3be52eff3f033e2a`
and head `d31f20f3`. The repaired waiter then proved both live paths: it reported
the pending PR truthfully at its 20-minute deadline, and separately retained a
real transient GitHub read diagnostic before recovering.

Pull-request run `35006915232` passed every required dependency. Observed job
wall times included Linux 18m33s and Windows sections 14m21s, 22m49s, and
26m48s; these include staggered runner pickup and are not suite-only runtime.
The PR entered the queue, synthetic commit
`d49100a26ff622c9015b73fca67d881c9fe1b92c` ran as merge-group run
`35011737325`, and that run succeeded from 19:07:39Z to 19:28:30Z. PR #475
merged as the same `d49100a2`, which was then verified as both canonical HEAD
and fetched `origin/main`.

## Final measurements

Existing successful pull-request runs were measured without a new sampling
campaign. Among the most recent 15 classified successes available at capture:

- prose-only, n=9: total p50 31s, p90 32s; classifier p50/p90 11s/11s;
- code, n=6: total p50 44m22s, p90 47m43s; classifier p50 11s, p90 12s.

The always-on classifier therefore remains well below three minutes and
prose-only required CI remains below five minutes. Code wall time includes
independent runner pickup plus the complete safety matrix; coverage was not
reduced to improve it. The accepted #210 suite-only measurement remains about
18.6 minutes with a named 18.3-minute Kimi floor.

Issue #164 measured queue-only median 13.1m, p90 13.4m, and p95 17.0m across 12
recent entries, below the 60-minute target. In its 25-merge window only two PRs
had more than one merge-group run and none was overtaken indefinitely. #475 had
one successful merge-group run, so its rebuild count was zero.

The historical baseline did not record a numeric landed-versus-handoff ratio,
so a numeric improvement cannot be fabricated. The final programme outcome is
instead directly auditable: all 14 registered delivery rows are complete, the
final continuation handoff is retired in the closeout commit, and no unfinished
#159 delivery obligation is transferred to another handoff.

## Result

The live rules already expressed the intended final aggregate, so the safest
cutover was no ruleset mutation. Required reporting, administrator recovery,
history protection, exact-head review, bounded diagnostics, queue admission,
merge-group success, and origin/main identity are all directly proven.
