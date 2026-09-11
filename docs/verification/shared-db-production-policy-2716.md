# Shared-db automatic production policy authority — issue #2716

Recorded: 2026-09-11

## Current owner ruling

The current programme chat explicitly instructs the implementing sessions to complete
popcre/ai-devops #401 and shared-db #2716 straight through, including commit, merge,
deployment, and verification, without pausing for routine production-policy approval.
It also explicitly forbids treating migration application alone as acceptance and
requires every verification gate in the plan. This is the current-chat ruling allowed
by the owner-only clause in `plan_shared-db-complete-throughput-repair.md`; it is not an
inference from an old handoff.

The authority is narrow: activate only the automatic `u2giants/shared-db` workflow
described by #2716. It does not authorize a manual production command, a session-made
workflow dispatch, a database write outside that workflow, another repository's
production action, or a bypass of any evidence gate.

## Prior activation re-proved

- popcre/ai-devops PR #24 is merged as
  `7c3e25454561748cd29e24bcfe1f3b4c0d3bdeb6`.
- u2giants/shared-db PR #1021 is merged as
  `6e4ea801798dae3ae30648a5e4682bbb3aa06e66`.
- `u2giants/shared-db/config/production-risk-policy-activation.json` on current main
  is schema `shared-db-production-risk-activation/v2`, has `active: true`, pins those
  two merge commits, pins forward-proof digest
  `8fe5889eba4e31f7683db77fdfc7cf766243c55104ff5e5c7a5bc8fdf12e9c9b`, and records
  matching canonical and installed skill hashes for that activation.

That v2 record activated the existing business-risk evidence gate; it cannot authorize
the #2716 code change itself. The #2716 workflow and global-rule changes still require
their own branch, tests, exact-head independent reviews, pull requests, merges, and
installed-file proof. Until the shared-db workflow is merged and those canonical rules
are installed, no session may claim the new exception is live.

## Preserved gates

The automatic path must independently prove the current main SHA, durable exact-head
verdict, latest guarded merge authorization, exactly one open linked structural issue
admitted from its current scope and the PR's actual migration files, exact preview run
and digest, bounded ordered allowlist, exact production target, fresh dry-run, global
production lock, and post-apply ledger/catalog result. Any absent, stale, ambiguous,
multi-source, non-structural, or failed evidence stops for an engineer before dispatch.
