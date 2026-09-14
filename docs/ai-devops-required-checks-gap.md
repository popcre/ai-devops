# ai-devops required-check closure

**Written 2026-09-01; resolved 2026-09-14.** Repository: `popcre/ai-devops`.

## Required contract

The `main` ruleset (`main: pull request + merge queue`, ruleset id `21564317`)
requires the single stable context `verification-closure`.

On a pull request, that context succeeds only after exact-head Linux, Windows,
and reviewer-safety proof has finished successfully. On a merge group, it
succeeds only after the queued head's evidence gate and the fresh Linux suite
both succeed. The long Windows suites remain on independent pull-request
runners and are not repeated in the queue.

## Why

Requiring leaf jobs independently is unsafe when their event topology differs.
On 2026-09-14, PR #452 entered the queue while its exact-head run was unfinished.
The merge-group evidence job correctly refused that state, but the ruleset
required only `linux-offline`; GitHub therefore landed merge commit
`22a7f22b88198e1bcc26ec99ebc135819b8f06f4` despite the failed evidence job.

That is the exact failure shape this repository already knows: a check that
runs when someone remembers to look is not a mechanical check. These particular
tests guard the reviewer wrappers — the tools that produce the approval evidence
other repositories merge on — so a silent regression there degrades review
quality everywhere those wrappers are used, with no signal at the point of
merge.

## Why the recent shared-db change does not apply here

The shared-db work (`#2047`) narrowed a gate that refused a run whenever
`main` moved at all, so that a documentation-only commit no longer voids
in-flight database work. `ai-devops` has no equivalent gate:

- Its ruleset already sets `strict_required_status_checks_policy: false`, so it
  never demands a branch be up to date with `main` before merging.
- Its only `rev-parse origin/main` (`bin/ai-memory-sync`) is memory-sync
  reconciliation, not a merge gate.

The stable closure context is the mechanical boundary: it reports on both pull
requests and merge groups and converts any missing, unfinished, skipped outside
the declared prose path, or failed proof into a blocking failure.

## What is already protected

For the record, `ai-devops` is **not** unprotected. Ruleset `21564317` requires
a pull request, allows squash merges only, and runs a merge queue; ruleset
`21183703` blocks force-pushes and branch deletion on `main`. The gap described
above is the single missing piece, not a missing foundation.

## How to verify after the change

```
gh api repos/popcre/ai-devops/rulesets/21564317 --jq '.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context'
```

It must list exactly `verification-closure`.
