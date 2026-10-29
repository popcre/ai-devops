# Entire reversible trial execution report — #2022

Coordinator: Codex chat `01a18710-9230-7801-95f9-aebc53f9c409`, edge-dev3.
Execution authorized October 29, 2026; started from public source
`534493c047cd7dd9ebde38b25071918744901cf3` on
`codex/entire-trial-20261029`.

## Decision

Local authored-memory persistence and native offline restoration work in the
tested isolated profile. Search benefit is unproved; hosted memory, Trails,
mirror and optional CI are not tested. **No adoption recommendation.** The
requested full outcome remains open on [#2022](https://github.com/popcre/ai-devops/issues/2022).
This is an executed local qualification with explicit failures and blockers,
not completion of the whole published experiment.

## Step 1 receipts

The protocol and ten questions/key were frozen before measurements and indexing:
[receipt](https://github.com/popcre/ai-devops/issues/2022#issuecomment-6493557964).
Initial operating-record digest:
`5bca45d10fb6eed05e708e1a398be017c95f985152a1150fccbe207851848f8c`.
Question/key digests remain in that receipt. Later operating-record updates are
execution receipts, not changes to frozen thresholds.

[Baseline](baseline.md): newest 100 merged PRs inspected, 20 prose and 20
non-prose selected separately. Creation-to-merge median: 0.44 and 70.315 minutes,
respectively. Ranges: 0.08–2,169.88 and 23.13–547.6 minutes. This measures total
PR lifetime, not CI performance; execution, queue, failures, cost and runner OS
per sample are unknown. Missing data does not become a saving.

GitHub authenticated identity `u2giants` has repository admin rights and active
organization admin membership. The organization already has an Entire GitHub
App installation (`175665854`, selected repositories), which is **pre-existing**
and must be preserved. Exact selected-repository enumeration returned HTTP 403:
current credential lacks `read:user` for that endpoint. No scope was expanded.
No existing Entire credential/config was present locally; no Entire, Depot or
Buildkite item title matched among 199 1Password metadata entries. No secret
values were read. Both available browsers reached Entire's sign-in page.

Hosted owner/account settings, terms-acceptance authority, exact mirror scope
and effective zero-spend boundary remain unqualified. The coordinator owns
this blocker; no other active authorized Entire session was found. Existing
GitHub installation is not proof of an authenticated Entire workspace.

Private raw-evidence custody remains unqualified. No genuine session archive,
historical transcript, private submodule or real business content was captured
or uploaded. Only public committed source and explicit synthetic records were
used. Local synthetic exports are recovery fixtures, not a qualified private
repository or authority for future private capture.

Vendor documentation refreshed October 29, 2026: billing permits in-flight
usage beyond zero, so a free credit balance alone does not establish $0 spend.
The privacy policy says revocation stops future import but does not delete
imported content; repository retention depends on repository deletion. Terms
restrict general external model training without separate opt-in. Feature-level
backup deletion deadline, processors, actual region and visibility were not
qualified. Real sharing remains blocked.

## Local qualification

Verified release checksum before running CLI 0.12.2. Official plugin installer
verified and installed brain v0.4.0 and graph v0.6.0; `plugin doctor` passed.
Binaries and profiles were confined to a task-owned isolated directory. No
global installation, live toolkit update or reviewer repair occurred.

Setup: `brain setup --no-backfill --no-daemon --no-agent-hooks --agent none`.
The report showed no session extraction, watcher or session-end hook and zero
captured sessions. The local index built in approximately 7.82 seconds; this is
setup time, not an efficiency comparison. A separate network namespace returned
`ENETUNREACH` for an outbound socket; real Codex/Claude homes were inaccessible.

`enable --agent codex --local --skip-push-sessions --telemetry=false` then
qualified repository-only hook installation. An initial missing Git-config
identity refusal was resolved by setting identity only in the disposable clone.
Enable and disable both then returned success. Seven Codex hooks were installed;
automatic checkpoint pushing stayed disabled. The pre-existing synthetic
pre-push hook was preserved and still executed after disable.

## Feature scorecard

| Feature/case | Disposition | Evidence or limit |
|---|---|---|
| Local authored memories | pass, limited | Persistence and two corrected fresh-context source checks |
| Captured-session continuous memory | not tested | Zero genuine captured sessions; no extraction |
| Local graph/search | functional, utility inconclusive | Partial Bash parsing; no PowerShell semantics; heavy fallback |
| Ten matched retrieval pairs | inconclusive | 10/10 combined answers in both arms; deviations and no timing |
| Hosted brain sharing | not tested | Authenticated workspace/cost/data gates unqualified |
| Mirror and divergence | not tested | No trial remote or hosted ref created |
| Trails/latest-head/stale-green | not tested | No authenticated Trail or free Agent boundary qualified |
| Optional shadow Linux CI | omitted, not tested | Hosted prerequisites unavailable; no provider configured |
| Local export/reimport | pass for authored records | Native bundle restored in clean isolated profile |
| Capture channels/redaction | not tested | No env/argv/stdout/clipboard/browser/sibling capture exercised |
| Network/profile isolation | pass | Kernel network boundary and inaccessible host agent homes |
| Unknown/stale/injection | limited pass | Exact cases and limits in memory-results.md |
| Hosted deletion/backup retention | not tested | Zero trial-created hosted records; pre-existing App preserved |

Full receipts and failed attempts: [memory-results.md](memory-results.md).

## trail-latest-head

Not tested. No Trail, two-branch Trail association, automated finding, CI gate,
latest-head update or hosted screenshot exists. Local records are not a Trail
substitute. GitHub administrator is `u2giants`; coordinator retains access
qualification ownership. No hosted adoption or fabricated live proof.

## export-reimport

Native `brain bundle export` produced a docs/facts/seed bundle; code index,
sessions, privacy policy and operational state were excluded by the supported
default. No captured sessions existed. First bundle SHA256:
`c114d044e08b5ebb7c9999391de2bee64dfae7aab5875999fd54e275b2046da2`.
A fresh plugin-data/config profile imported 139 entries and recalled the same
decision IDs offline. The first restored set contained three active records.

Final bundle, including subsequent synthetic adversarial evidence:
`c518f287c1be07ad59d0ac3360262d2b12c85bff951b63abbbe3d4095d6e9df6`.
Import into the separately owned restoration profile succeeded with checksum
verification and recovered GitHub authority. `memories files --all` also wrote
five readable Markdown files, including retracted v1. Manual offline reading
preserves goal, decision, source, unresolved hosted blocker and supersession.
Native import is proved for memory only; no Trail import or vendor scoring
semantics are claimed.

A verified Git bundle preserves both isolated and original public source
commits plus the trial-owned checkpoint ref. Git reported complete history.
This bundle does not claim to export hosted Trail metadata.

## restore-preservation

The synthetic pre-push hook's SHA256 before enable and in Entire's preserved
backup both matched:
`cfa4b76811287a73ae334907de022ce641f66920420c876703e68b8689e401b7`.
It still ran after disable and again after owned hooks were archived and the
original hook restored byte-for-byte. Trial-created hook/settings directories
were archived, modified instruction files restored and local identity entries
removed. The isolated clone was clean. The owned checkpoint ref was removed
only after Git-bundle verification. Both profiles' brain plugin entries and the
trial graph plugin were removed by the supported plugin command; the two
extracted CLI executables were then removed with their release archive retained.

Initial original-profile inventory digest:
`e6d5e9d58a1336b5a21b11c35cce0fbf80e5aa0f21e862c5fd5c1e693e100230`.
After comparison, the digest was identical: no changes to global Git config,
original Codex/Claude settings, existing Entire config/plugin paths or installed
toolkit launcher. `ai-task-gates status` still worked after departure. This
snapshot excludes shared checkout Git metadata that other sessions legitimately
change and is narrower than a byte-for-byte whole-machine assertion.

Recovery ID `entire-trial-20261029` contains 61 hash-verified public/synthetic
evidence files plus the verified official release archive in owner-only local
state. Manifest digest:
`451363395dd0537a2a70d37eb728df1fdfa6f55ec0b68125087b45380825eff9`.
A harmless write/read canary passed. This is bounded local recovery custody for
public/synthetic fixtures, not qualification for private raw capture. No
background service or cleanup process is promised.

## github-only-completion

This report is the existing authorized normal documentation task used for
GitHub-only delivery after local capture disable and trial removal. Exact-head
doc-safety, PR/landing commit, original-state comparison and post-merge source
verification receipts belong on #2022. Do not count preparation as landing.
No original workflow, required check, Windows route, remote, protection or
installed toolkit was changed. A prose-only landing does not prove a fresh
Windows executable run; broader Windows runtime parity remains untested.

## Costs, stop and ownership

No paid API or hosted Agent call, subscription, top-up or CI provider was
enabled. Observed incremental trial spend is $0. Local qualification passed
containment October 29, 2026, 5:58 AM EDT; no multi-day pilot or background
capture is running. Discovery remains bounded by November 2, 2026, 5:00 PM EST.
The hosted blocker does not justify an empty running trial.

The coordinator keeps #2022 open for authenticated hosted qualification,
Trails/live proof and any later valid captured-history pilot. Existing private
custody and vendor data qualification are required before real capture. Reuse
this report; no new shared harness or separate proof ticket was introduced.

## Official sources

- [Installation](https://docs.entire.com/installation)
- [Memory](https://docs.entire.com/guides/brain/overview)
- [Plugin management](https://docs.entire.com/cli-reference/plugin)
- [Billing](https://docs.entire.com/billing)
- [Privacy](https://entire.com/privacy) and [terms](https://entire.com/terms)
