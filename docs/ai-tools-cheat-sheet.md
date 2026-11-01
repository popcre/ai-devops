# In-house tool cheat sheet

Exact usage lines, copied from each tool's own usage text on 2026-10-21. Read
this instead of running `--help`. If a line here fails, the tool changed: rerun
its help and update this page in the same pull request.

## ai-review (`bin/ai-review`)

```text
ai-review <provider> <plan-review|diff-review|security-review|visual-review|final-check> [--tests CMD] [--base REF] [--assert-head SHA] [--force] [--additional-reviewer]
ai-review <provider> <mode> --reviewer-approval <assigned AI reviewer exact-head APPROVE report> [review options]
ai-review deepseek <diff-review|security-review|final-check> --code-only --paths-file JSON [--base REF] [--assert-head SHA]
ai-review doctor
```

`--implementer ENGINE` records the implementing engine; `final-check` needs a
real `--tests` command. Pick the reviewer per `docs/reviewer-rotation-rules.md`.

## ai-task-gates (`bin/ai-task-gates`)

```text
ai-task-gates start --class CLASS [--reason TEXT] [--base REF]
ai-task-gates check --before ACTION [--acknowledge TEXT] [--reviewer-approval REPORT] [--target-head SHA]
ai-task-gates explain [--json] [--base REF]
ai-task-gates status | end
```

ACTION: `review code-only-review pr-wait ship deploy database infrastructure
production shared-db-promotion application-workflow`. Classes are listed in the
global rules.

## ai-muse (`bin/ai-muse`; needs `AI_MUSE_CALLER=claude` or `codex`)

```text
ai-muse new <name> [--base REF] [--assert-head SHA] --prompt TEXT|--prompt-file FILE|stdin
ai-muse ask <name> [--base REF] [--assert-head SHA] --prompt TEXT|--prompt-file FILE|stdin
ai-muse implement <name> [--base REF] --prompt TEXT|--prompt-file FILE|stdin
ai-muse list | show <name> | transcript <name> | reconcile <name> | delete <name> | doctor
```

## ai-pr-wait (`bin/ai-pr-wait`)

```text
ai-pr-wait <pr-number> --timeout-minutes N [--fit-tool-call] [--repo OWNER/NAME] [--reviewer-approval REPORT]
```

`--timeout-minutes` defaults to 60 (owner ruling 2026-10-21, #1962); run the wait
in the background rather than a `sleep` loop.
On `STILL-WAITING` rerun the printed command. Prose-only PRs do not wait for
checks unless `--reviewer-approval` is given.

## ai-doc-safety (`bin/ai-doc-safety`)

```text
ai-doc-safety [tree]
```

Exit 0 = both doc invariants hold; required before a prose-only admin merge.

## ai-blocker-watch (`bin/ai-blocker-watch`)

```text
ai-blocker-watch find <words...> [--all]
ai-blocker-watch link <blocked owner/repo#M> <blocker owner/repo#N>
ai-blocker-watch list | cancel <wait-id> | reap [--dry-run] | alarm [--dry-run]
```

`wait` and `has-wait` are inert: use `ai-pr-wait` or leave the issue as the card.

## GitHub measurement qualification (#660 under #658)

These are explicit, bounded observation/analysis tools, not normal routing.
Owner: the #658 coordinator; consolidate interfaces into the existing reporter
after qualification rather than creating a second telemetry service. Keep raw
artifacts in protected local state; publish only scrubbed aggregates.

```text
python3 tools/github-requests/report.py MEASUREMENTS_DIRECTORY
python3 tools/github-requests/report.py --qualify-wait --source-root INSTALLED_CHECKOUT --manifest /etc/ai-devops/install-manifest.tsv --receipt PRIVATE_NEW_RECEIPT -- PR --repo popcre/ai-devops --timeout-minutes N
python3 tools/github-requests/replay.py --repository CHECKOUT --measurements PRIVATE_FROZEN_INPUT --output PRIVATE_NEW_DIRECTORY
python3 tools/github-requests/compare.py PRIVATE_BASELINE_JSON PRIVATE_CANDIDATE_JSON
```

The ordinary reporter is offline. `--qualify-wait` explicitly launches one live
waiter, preserving its output and exit status. On Linux its live parent retains
the clean installed Git generation, sealed loaded bytes and bounded kernel
clock. An unavailable source boundary preserves the original waiter with an
unknown receipt; it never upgrades ordinary/historical events. Remote timestamp
qualification explicitly assumes GitHub's published UTC reference and includes
timestamp resolution. Bootstrap and total observation time remain in receipts.
Cancellation reaps only the owned child group. Use this for necessary real PR
work; never manufacture activity to reach sample thresholds.

Replay is Linux-only offline analysis of the frozen historical helper pair,
using a local upstream stub and virtual clock. It does not make HTTP requests
or recreate missing historical arrivals, heads or live detection times. The
comparison validates paired operation/outcome cases, minimum twenty outcomes
per operation and conservative latency bounds. It cannot authenticate edited
JSON or grant programme acceptance; unknown costs stay null.

The finite version-matched counter build and live managed-read API are documented
in [the existing counter guide](../tools/github-requests/instrumented-gh/README.md).
The full observer route failed local timing overhead and must remain explicit
qualification machinery; passing direct counter timing is a separate result.

For a native Windows waiter observed by a Linux parent with existing verified
SSH access:

```text
python3 -I tools/github-requests/remote_wait.py --host WINDOWS_HOST --source-root WINDOWS_INSTALLED_CHECKOUT --receipt PRIVATE_NEW_RECEIPT --read-only-no-stdin --timeout-seconds 3600 -- PR --repo popcre/ai-devops --timeout-minutes 55
```

Create the receipt's owned mode-700 parent first. `--read-only-no-stdin`
explicitly reserves input for controller acknowledgments; it is not a general
interactive-command wrapper. Binary output and original exit status are
preserved. Windows snapshots use only verified existing standard temporary or
Program Files parents, pinned before fresh private creation, without changing
existing permissions. Source scope is raw Git `bin/tools/config`; Linux EOL
attribute materialization is a distinct scope. Dangerous privileges present in
the original context leave immutability unknown. The explicit finite read
profile removes privileges only from its owned child, preserving the parent.
The Linux parent's bounded clock brackets `process_resumed` through event
arrival; startup and SSH delay are included. GitHub UTC and one-second timestamp
resolution are explicit assumptions; this grants no Windows clock bound.
Connection loss, timeout and cancellation stop only owned work and clean up its
snapshot. Internal Windows controller handles are not operator-supplied source
or clock authority.

## shared-db scripts (in a `popcre/shared-db` checkout, run with `node`)

These have no `--help`; an unknown flag prints the supported list. The lane
lines are the most-used ones in shared-db's own docs; recovery flags are in
that repository's runbooks.

```text
node scripts/run-governed-review.mjs --issue N --pr N --head-sha SHA --reviewer NAME [--wrapper W] [--worktree PATH] [--review-slot S] [--tests CMD] [--skip-doctor]
node scripts/manage-migration-author-lanes.mjs --queue-audit
node scripts/manage-migration-author-lanes.mjs --audit | --abandonment-audit | --reviewer-capacity
node scripts/manage-migration-author-lanes.mjs --prepare-preview-dispatch <issue> [--admit-issue <issue> --pr <pr>]
node scripts/manage-migration-author-lanes.mjs --return-issue <n>
node scripts/manage-migration-author-lanes.mjs --release-duplicate-claim <claim> --owner <exact-owner> --confirm-finished
```
