# Evidence — the #89 flake failing a merge-queue batch on unrelated work

**Captured:** 2026-08-27 by Claude (Opus 5) on `edge-dev`
**Why this file exists:** issue #89's reviewer flake had been characterised as
intermittent test failures. This records it doing something worse — failing a
**merge-queue** run, on an unrelated pull request, where `windows-offline` is a
required status check. The claim had been inferred from configuration; this is
the observation.

`plan_repo-throughput-restructure.md` § 6.2 relies on this file. That plan is in
the merge queue as of writing; this evidence stands on its own either way.

## What happened

| Field | Value |
|---|---|
| Run | `33100525687` |
| Event | `merge_group` — a **merge-queue** run, not a pull-request run |
| Branch | `gh-readonly-queue/main/pr-127-b9734cac01fdfaae64ecd56455a280246586578a` |
| Conclusion | **failure** |
| Failing jobs | `windows-reviewer-safety`, `windows-offline` |
| Passing job | `linux-offline` |
| Reviewer job id | `98616693619` |

Reviewer job output, verbatim:

```
2026-08-27T18:02:07.7365036Z   FAIL different_named_sessions_can_ask_concurrently
2026-08-27T18:02:30.8472527Z   FAIL same_next_ask_turn_is_serialized
2026-08-27T18:03:06.9416329Z   FAIL uncertain_ask_blocks_its_exact_retry
2026-08-27T18:03:15.5465082Z   FAIL uncertain_ask_does_not_block_other_named_session
2026-08-27T18:04:25.8412809Z passed 187, failed 4, skipped 0
```

Reproduce:

```bash
gh api repos/popcre/ai-devops/actions/jobs/98616693619/logs --allow-escape-sequences | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'FAIL|passed [0-9]+, failed'
```

## What this establishes, and what it does not

**Established:**

1. **These are exactly the four checks issue #89 was opened about.** Not a
   related failure, not a new one — the same four, by name.
2. **It failed a merge-queue run, so it blocked merging, not just reporting.**
   `windows-offline` is a required status check (plan § 5.3), and this is the
   mechanism by which the flake gates every merge in the repository.
3. **It failed on work that has nothing to do with the reviewer wrappers.** The
   queue entry is headed by PR #127, a skills-index change.
4. **The fix was not in this run.** PR #123 had not merged, so this is a clean
   observation of the pre-fix behaviour on current `main`.

**Not established, and deliberately not claimed:** PR #128 acquired a second
queue entry (`pr-128-7708db9b…` then `pr-128-ac4f5845…`) shortly after this
failure, which is consistent with an `ALLGREEN` batch ejection taking unrelated
entries down with it. Batch membership was not read from the merge-queue payload,
so the requeue is **circumstantial**, not proof. If someone needs that proven,
read the `merge_group` event payload's `merge_group.head_sha` chain rather than
inferring from branch names.

## Why it matters to the plan

This is the best single justification for Phase 1 running before everything else.
The flake is not "tests are annoying." It is a required check failing on a third
of runs, inside a batching merge queue, on work whose authors have no connection
to the code involved and no way to attribute the red — because the run's logs
stay locked until its ~62-minute sibling finishes.

**Step 1.2 is what closes this out.** Ten consecutive green reviewer runs after
PR #123 lands. Until then the fix is plausible, not proven, and this file is the
baseline any later claim of "fixed" has to be measured against.
