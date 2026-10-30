# Entire trial operating record — #2022

Closeout continuation: read the
[new handoff](../HANDOFF.d/2026-10-30T0345Z-edge-dev3-codex-entire-trial-wrap.md)
and [final independent recovery results](../tests/verification/entire-trial/report.md#final-independent-recovery-and-closeout)
first. Cost/billing work was dropped by Albert. Scoped support follow-up was
submitted at 7:19 PM EDT October 29; no reply/deletion proof established.
Original discovery November 2, 2026, 5:00 PM EST and stop November 12, 2026,
5:58 AM EST remain unchanged. Do not restore unrelated Codex settings drift.

Latest result: [independent free tests](#independent-free-feature-tests) finished
with negative memory/private-capture outcomes and limited manual Trails/export
passes. See that section before the historical continuation receipts below.

Historical online-execution owner: Codex chat
`01a18887-e521-7e50-8b25-cd87775c567f`, edge-dev3, branch
`codex/entire-trial-online-20261029`, source
`071bc68337b287f169afa3c0f79c41d612ff0f9f`. Authenticated access now works after
Albert's explicit terms-acceptance instruction. Captured research export and
offline restoration passed narrowly; captured-memory retrieval failed. Trails
and full hosted departure are not accepted. Read
[the continuation receipts](../tests/verification/entire-trial/report.md#online-qualification-and-departure)
and [case dispositions](../tests/verification/entire-trial/adversarial-results.md).
Earlier sections below retain the initial execution history.

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

## Initial qualification record — historical

Entire CLI release discovered: v0.12.2. Installation has not yet occurred.
This initial observation predates the execution receipts below; it is not the
current installation state. The trial binaries were later tested and removed.
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

## Fresh-session reconciliation

October 29, 2026, 10:28 AM EDT: PR #2034 is merged; verification-closure,
doc-safety and applicable Windows summary checks completed SUCCESS. Individual
Windows executable lanes were skipped for prose. Entire Gates completed NEUTRAL.
The earlier pending-check receipt is superseded on #2022. This completes the
limited local GitHub-only prose delivery proof, not hosted trial acceptance.
All 61 retained synthetic/public recovery files still match the manifest;
private raw-evidence custody remains unqualified. No trial process is running.

Continue with the [whole-plan handoff](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-29T1428Z-edge-dev3-codex-entire-trial-continuation.md).
Re-read all downstream phases through step 7 and report drift at every phase
end. New context or later hosted activation does not reset the original clock.

## Online continuation operating limits

The $0 limit permits no incremental charge. Personal/POP account UI showed no
card/no usage; billing API reported not started, and POP metered spend was zero
but non-final. The repository had no configured Agents. Only documented free,
manual Trail metadata was exercised. Do not infer a hard Agent cap from these
observations: billing permits in-flight overshoot. No hosted Agent, payment,
top-up or provider was enabled.

Existing mirrored GitHub work remains: Trail 103 identifies PR #2038 as merged.
GitHub main protections and existing integrations were preserved. The shared
App scope was not changed to satisfy a trial-only one-repository allowlist.
All writes named ai-devops explicitly; no other repository content was tested.

The pinned local versions remained CLI 0.12.2, brain v0.4.0 and graph v0.6.0.
Use the published directory overrides for isolated configuration/plugin/data
roots. The capture namespace must not expose original agent homes, installed
toolkit settings or online Entire credentials. Codex subscription authentication
was supplied only to its isolated runtime and its copy removed after testing;
it was never in the evidence export. No global daemon or capture was installed.

The normal Codex hook-review screen was needed to trust the seven official
project hooks. Do not bypass hook trust. Codex CLI 0.165.0-alpha.1.2 could not
execute nested file-tool sandboxes in this namespace; do not disable either
boundary to manufacture a successful coding capture. A public-only research
session completed, but required the documented explicit `session attach` route
to form a checkpoint. Preserve a Git bundle before any unpublished local
trailer rewrite; never rewrite a shared commit or push a raw session.

`brain distill` on that exact session used `--agent codex`, model
`gpt-6.1-sol`, effort `low`, concurrency 1 and a 90-second chunk bound. Its
receipt contained zero facts. Conversation-only queries remained empty even
after projection rebuild. Source-document hits cannot be credited as captured
memory retrieval. No manually authored replacement was added.

For captured sessions, use `brain bundle export --include-sessions`; default
exports omit them. The archive produced here was a POSIX tar despite its
chosen `.tar.gz` filename: use format autodetection rather than assuming gzip.
Import the bundle in a clean offline profile with its verified SHA256; check
the manifest's exact transcript member against the original bytes. Native
restore and manual readback worked; memory search did not. Keep those verdicts
separate. Session-inclusive bundle digest and restored transcript digest are
in the linked report.

Trail 113 is synthetic and trial-owned. Purpose-built `trail show --json` plus
supported `api` GETs preserved intent, timeline and empty inventories. The API
marks the result possibly partial; branch/check/finding/session fields have
not been roundtripped. Native Trail reimport is unproved. Closing via
`trail update --status closed` succeeded but the record remains retrievable.
The current project-Trail API has no qualified deletion action; legacy
repository-Trail numbers are a different identity space. Never delete by a
matching number without proving the exact target. Pending deletion/backup
retention stays on #2022 with the coordinator; no vendor request was sent.

Read logout semantics before removing trial access. In this version,
`entire logout` ends every CLI session on the login server, including other
machines; `--context` does not narrow it. Do not run it to remove one trial
session. The local trial credential/context files were removed, preserving
other sessions; remote revocation remains unproved. The exact trial-session
ID/expiry is retained privately under opaque recovery ID
`entire-trial-online-20261029`. Its expiry is not a trial-clock extension.

After preserving public/synthetic exports, disable owned capture, remove only
owned hooks/settings and use `plugin remove` for the three isolated profiles
(online, capture and clean restore). Remove their extracted executables after
release recovery. Compare original profile hashes, retain existing App and
all original integration settings, and publish only sanitized summaries.
Public/synthetic local recovery does not qualify private-business custody.

Original discovery: November 2, 2026, 5:00 PM EST. Original stop: November 12,
2026, 5:58 AM EST. No extension, new baseline, broader grant, hosted real
history, optional CI or background pilot was authorized by this continuation.
All downstream steps through step 7 were reconciled in the linked report;
unmet gates and full live proof remain open on #2022.
## October 29 repair continuation

Captured conversation retrieval now passes narrowly with an unchanged official
upstream candidate in the isolated Linux trial. A new coding session formed
an automatic local checkpoint; session-inclusive offline restoration preserved
conversation identity/text. Four fresh consumers across the original and new
captures retrieved before checking source; two reconciled stale departure
status correctly. This does not prove extraction, five natural histories,
utility savings, Windows candidate support or permanent adoption.

The old trial CLI login was individually revoked while every other login was
preserved at that boundary. Albert authorized a narrow support request to
delete only synthetic Trail 113 and confirm backup retention; submitted October
29 at 2:59 PM EDT, no durable ticket/reply established. Current project API has
no qualified delete for that branchless record. Closing it remains insufficient.
Metered Agents stay disabled because documented credit exhaustion can overrun
into an invoice. GitHub installation/rulesets and original profile hashes
compare unchanged. [Exact receipts and limits](../tests/verification/entire-trial/report.md#captured-memory-repair-and-scoped-departure).
Original discovery November 2, 2026, 5:00 PM EST and stop November 12, 2026,
5:58 AM EST remain unchanged. Historical failures above remain historical.

## Independent free-feature tests

The [new test report](../tests/verification/entire-trial/report.md#independent-zero-spend-tests)
supersedes earlier untested paired retrieval/two-branch rows. Twenty fresh
matched runs scored ordinary lookup 10/10 versus Entire-assisted 8/10, with no
speed/token benefit. Raw local capture retained synthetic tool/ignored-file
content, so private capture remains off. Free Trail133 tested two branches,
manual finding severity/source/resolution, newer failing checks and repaired
exact-head success. Hosted paid automated review stayed off; existing runner
setting stayed false. Both backing PRs2066/2068 closed unmerged; exact owned
branches removed after recovery. Native hosted sessions/discussions were not
recreated; a 22-file manual export passed fresh offline continuation with
explicit scope/semantics limits.

Trail133 is closed/retrievable; deletion/backup retention remains separate
from the authorized support request for113. No additional support message.
The new refresh session was removed with six original logins preserved, but
its already-issued bearer still accepted a data read; immediate invalidation
is not proved. Local credentials were destroyed, evidence excludes them.
Original settings, GitHub protections and shared integration compare unchanged.
Observed vendor spend remains zero, non-final; billing/trial unstarted.
This means Entire only: GitHub's existing publication review invoked provider
calls whose charges were not recorded. No all-in $0 claim is supported.
The label/cost erratum uses the existing fork-PR skip condition for optional
provider jobs, preserving the review integration and all required checks.
Independent free testing is finished with failures/limits, not full adoption
or hosted-departure acceptance. Original discovery November 2, 2026, 5:00 PM EST
and stop November 12, 2026, 5:58 AM EST remain unchanged.
