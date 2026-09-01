# ai-devops: one CI job runs but cannot block a merge

**Written 2026-09-01.** Repository: `popcre/ai-devops`.

## What has to be done

Add `windows-reviewer-safety` to the required status checks of the `main`
ruleset (`main: pull request + merge queue`, ruleset id `21564317`). Today that
list contains only `linux-offline` and `windows-offline`.

This is a repository-settings change and needs the owner's word before it is
made.

## Why

`.github/workflows/verify.yml` defines **three** jobs:

| Job | Required? | What it proves |
| --- | --- | --- |
| `linux-offline` | yes | the Linux test suite |
| `windows-offline` | yes | the Windows test suite |
| `windows-reviewer-safety` | **no** | the reviewer wrappers behave safely on Windows |

The third job runs `tests/test-ai-codex-review.sh` and
`tests/test-ai-grok-review.sh` under Git Bash on `windows-2025`, counts the
failures, and exits 1 if there are any. It does everything a blocking check
does — except block. Because it is not in the ruleset's required list, a pull
request whose reviewer-safety suite is **red** still satisfies every required
check and merges.

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

There is nothing to port.

## What is already protected

For the record, `ai-devops` is **not** unprotected. Ruleset `21564317` requires
a pull request, allows squash merges only, and runs a merge queue; ruleset
`21183703` blocks force-pushes and branch deletion on `main`. The gap described
above is the single missing piece, not a missing foundation.

## How to verify after the change

```
gh api repos/popcre/ai-devops/rulesets/21564317 --jq '.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context'
```

It should list three contexts, including `windows-reviewer-safety`.
