# Entire trial operating record — #2022

Execution authorized October 29, 2026. Coordinator: Codex chat
`01a18710-9230-7801-95f9-aebc53f9c409`, edge-dev3 (Ubuntu).
GitHub remains authoritative. Source snapshot:
`534493c047cd7dd9ebde38b25071918744901cf3`.
Execution branch: `codex/entire-trial-20261029`.

## Frozen protocol

Freeze before collecting baseline or indexing. Preserve the published plan's
thresholds: five natural task histories, two fresh contexts, ten matched
questions, at least 9/10 correct without baseline regression. Timing is from
query submission to source-supported answer; setup and indexing are separate.
Alternate arm order by question number. Both arms use the same model, snapshot,
prompt and limits; opaque retrieval models invalidate a utility comparison.
No missing token counts become savings. No invented task histories.
Question IDs and expected sources are frozen in the linked fixtures.

Discovery ends November 2, 2026, 5:00 PM EST (two working days after start).
The ten-business-day trial starts only after qualification of an actual
candidate. No candidate means stop after discovery; never start an empty clock.
Any protocol change after measurements invalidates the utility signal.

## Scope and isolation

Only this repository's public committed files and explicitly synthetic markers
are eligible. Never initialize its private submodule or import existing chats.
An isolated clone and profile must exclude real agent homes, credentials and
private content. No global hooks, installed toolkit changes, subscriptions,
automatic extraction, daemon or hosted synchronization are authorized implicitly.
Incremental spending limit is $0.

## Qualification record

Entire CLI release discovered: v0.12.2. Installation has not yet occurred.
The official installation reference supports direct Linux archive extraction;
config and managed plugins have documented directory overrides.

Existing 1Password metadata: 199 items, no title matching Entire, Depot or
Buildkite. Values were not retrieved. Existing Entire sign-in is not established:
the browser shows login and agreement to terms. No authorized workspace creator
or existing workspace owner has been identified.

Private raw-evidence custody is unqualified. Existing private repositories have
specific machine-configuration, memory or transcript purposes; their existence
does not authorize storing trial evidence. Until qualification, generate only
public/synthetic evidence and no real session capture or hosted uploads.

Current official billing documentation says other features are free, Agent
usage is prepaid and automatic top-up defaults off. It also permits in-flight
usage past zero to be invoiced. An effective $0 account boundary is unverified;
do not run hosted Agents without account-level proof.

The coordinator checks every public payload before publication. Allowed fields:
public source identifiers, synthetic labels, supported command descriptions,
versions, digests and sanitized outcomes. No credentials or private inventories.

## Sources

- [Installation and isolation directories](https://docs.entire.com/installation)
- [Plugin management](https://docs.entire.com/cli-reference/plugin)
- [Local memory setup](https://docs.entire.com/guides/brain/overview)
- [Billing and overshoot limitation](https://docs.entire.com/billing)
- [Privacy](https://entire.com/privacy) and [terms](https://entire.com/terms)
- [Owning issue](https://github.com/popcre/ai-devops/issues/2022)

## Recovery contract

Before execution, inventory and hash existing Git/agent configuration and the
installed toolkit launchers. Never print credential-helper values. Keep GitHub
origin unchanged. Trial artifacts belong only to an explicitly owned isolated
directory. Preserve public/synthetic evidence before removing trial binaries.
Compare original configuration afterwards, then complete this authorized report
through GitHub alone. Hosted export/deletion cannot be claimed without records.

The attempted toolkit `deploy` gate refused because no installed-checkout and
launcher receipt was supplied. No toolkit deployment will occur. The unrelated
`application-workflow` gate also refused its unsupported context. Neither refusal
is authorization for an alternative deployment or application action.

## Execution receipts — October 29, 2026

CLI 0.12.2, brain v0.4.0 and graph v0.6.0 were extracted/installed only in an
isolated disposable profile. The toolkit was never deployed or updated.
Local network and filesystem isolation passed; setup disabled backfill, daemon
and agent hooks. Later repository-only Codex hook enable/disable passed with
automatic checkpoint pushing off and a preserved synthetic pre-push hook.

GitHub `u2giants` is a verified organization/repository administrator. An Entire
App installation already exists with selected-repository scope, ID 175665854.
It is shared pre-existing state, not trial-owned. Repository enumeration failed
with HTTP 403 (`read:user` missing); no token scope or App setting was changed.
No authenticated hosted workspace was reached in either browser. No hosted
records, mirror remote, Agent run or subscription was created.

[Report](../tests/verification/entire-trial/report.md) and
[memory results](../tests/verification/entire-trial/memory-results.md) preserve
actual passes, failed initial attempts and protocol deviations. Two corrected
fresh contexts recalled authored memories with valid source commits; automatic
captured-session continuity is not proved. Both ten-question arms answered
correctly, with nine candidate direct-source fallbacks and no timing/utility
claim. Native synthetic bundle import into a clean profile passed offline.

### Exact bounded local actions

All commands ran with an empty environment in a private PID/network namespace,
only system runtime mounts and the trial directory visible. Entire config,
plugin and XDG roots were explicitly task-owned. Supported actions:

```text
entire version
entire plugin install brain --yes
entire brain setup --no-backfill --no-daemon --no-agent-hooks --agent none --json
entire graph capabilities --json
entire brain remember <synthetic-text> --path <known-taxonomy> --agent none --json
entire brain recall <query> --no-global --json
entire brain memories retract <owned-synthetic-id> --json
entire brain bundle export --output <owned-export>
entire plugin install <verified-local-brain-binary> --no-deps
entire brain bundle import <owned-export> --sha256 <verified-digest>
entire brain memories files --all --dir <owned-readable-export> --json
entire enable --agent codex --local --skip-push-sessions --telemetry=false
entire disable
```

The clean restore profile used a separate plugin/data/config root and the same
source repository identity. Final bundle was imported with `--overwrite` only
over that owned synthetic restore profile; earlier export remained recoverable.
No unsupported command or secret value was supplied. `decisions.*` taxonomy
was refused; the supported `workflow.*` category succeeded. `graph capabilities`
requires `--json`; the rejected invocation is not counted as a successful test.

### Departure procedure

Export all authored records (including retracted ones), create/verify the Git
bundle, and preserve those public/synthetic fixtures before removal. After
`entire disable`, archive owned generated hooks/settings, restore the synthetic
original pre-push hook byte-for-byte, and restore only the two instruction files
modified in the disposable clone. Remove only the owned brain/graph plugins via
`plugin remove`, followed by the two extracted CLI executables. Their verified
release archive remains recoverable. Rebuildable indexes/caches carry no unique
evidence; classify them as rebuildable, never as a substitute for exported facts.
Compare original-profile hashes and complete the report through GitHub alone.
No real user credential, App installation or other session's capability is
removed. Final restore/landing receipts remain on #2022.
