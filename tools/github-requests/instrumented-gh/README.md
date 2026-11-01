# Outgoing-write counter qualification

Owner: [#660](https://github.com/popcre/ai-devops/issues/660), under #658.
This extends the existing measurement namespace. It does not install, alter
`ai-gh` routing, replace vendor `gh`, or establish programme acceptance.

`pins.json` is the single finite version-profile registry owned by #660. Its
default is the actual Linux vendor CLI 2.103.3; the separate Linux 2.103.0
profile preserves Hetz's existing vendor version. Windows source profiles 2.97.0,
2.95.0 and 2.88.1 preserve those hosts' existing versions. The old 2.101.0 prototype
profile and its evidence remain explicitly historical. Each profile binds an
immutable official commit/archive and shares the official Go 1.27.1 Linux
toolchain archive/hash. `build.py --upstream-version VERSION` selects a recorded
profile using the same code path; profile presence is not native qualification.
Retire redundant profiles when the actual fleet versions converge through their
normal maintenance routes, without changing a host merely for measurement.
`build.py` accepts those two
verified archives (`gh.tar.gz`, `go.tar.gz`) from a private directory and builds
unmodified/instrumented binaries in a new private output directory. It changes
only the profile's declared upstream API client constructors, the CLI finalization point and
the new internal counter package. Modules retain upstream `go.mod`/`go.sum`.
The 2.88.1 profile has one constructor and no detached telemetry; 2.95.0, 2.97.0,
2.103.0, 2.103.3 and historical 2.101.0 have two constructors and detached telemetry.
No binary or upstream source archive belongs in this repository.
Archives are copied into Linux memfd snapshots, sealed against write/grow/shrink
before hashing, and extracted from those same verified immutable bytes.
Linux qualification execution likewise uses a verified sealed ELF snapshot held by
the parent; replacing the original pathname cannot select a different program.
Every fixture and measurement artifact invocation uses that boundary. Builds
require an already-created owner-only output directory beneath trusted ancestors;
symlinks and nonsticky group/world-writable parents are refused. A retained
directory descriptor anchors extraction and execution through publication.
Go uses a private HOME, fixed system PATH, GOENV=off and local toolchain;
user flags and checksum-bypass configuration are not inherited.

The qualification CLI accepts only one literal relative `api` endpoint with
GET or HEAD (default GET) and the finite parser's read-only flags. It rejects
all other command families, payload sources, placeholders, executor-expanding
endpoints, browser/watch options, and ambiguous arguments before binary access.
The positive profile is a controlled fixture contract with an empty private
config, explicit private directories, a token, empty PATH and no pager or
runtime-selection variables. Ordinary inherited environments return unknown;
this is not fleet or installed qualification.
The observer CLI and every observer execution entry refuse a nonempty caller
`GH_PATH` before executable access, returning status 2 and unknown metadata.
Absent or empty `GH_PATH` uses upstream's
supported override bound to its still-open verified sealed image. That keeps
detached telemetry self-execution working without leaking counter descriptors
or keys. Raw immutable baseline/instrumented CLI parity retains explicit caller
override semantics without the observer. Durable credential setup, long-lived codespaces, skills,
aliases and extensions are not admitted; internal synthetic child fixtures
exercise preservation and explicitly show their HTTP requests are unobserved.
No ephemeral image path may be persisted as a Git credential helper.

The counter composes `httptrace.WroteRequest` with existing hooks. It observes
successful completed writes, including hidden retries; failed writes are
partial/unknown. An anonymous inherited Linux pipe carries bounded fixed
numeric metadata. The counter clears reserved environment keys and closes the
descriptor across child exec. It never inspects headers, bodies, tokens or
diagnostics; host comparison stays in memory. `GH_DEBUG` is never enabled.

`http_requests` remains null even after a clean finish: the prototype covers
these client constructors, not every command, transport, external client or
host. Completed writes are not proof of server acceptance or quota cost.
Missing finish, malformed/oversized metadata or interrupted commands yield
unknown. Late hooks/custom transports and full constructor coverage remain
qualification work. Windows has a separate native fixture and HANDLE-isolation
path below; source presence and cross-compilation do not establish its native
proof. Current runtime-version native proof, installed useful-work acceptance
and global HTTP totals are not claimed by this document or the profile registry.

## Verification

```bash
bash tests/test-gh-http-counter-prototype.sh
python3 tools/github-requests/instrumented-gh/build.py --archives /PRIVATE/archives --output /PRIVATE/new-build
python3 tools/github-requests/instrumented-gh/test_prototype.py /PRIVATE/new-build/build.json
python3 tools/github-requests/instrumented-gh/measure_overhead.py /PRIVATE/new-build/build.json
python3 tools/github-requests/instrumented-gh/measure_overhead.py /PRIVATE/new-build/build.json --managed-commands
python3 tools/github-requests/instrumented-gh/measure_overhead.py /PRIVATE/new-build/build.json --full-observer
```

Create the private output directory first. The ordinary development build
disables the update notifier using upstream's default build tags. A separate
paired local variant uses `build.py --qualify-updater` and the supported
upstream `updateable` tag; its manifest records that distinction. The same
fixture command against that manifest exercises TTY update success and
concurrent command failure. Original-build results explicitly skip this
case and cannot qualify updater behavior or installed release feature parity.
All proxy destinations are mapped to the local trusted server; no updater or
telemetry request reaches GitHub. Profiles declaring detached telemetry exercise
one separate local request, excluded from the primary process observation.
The 2.88.1 profile instead verifies its declared absence. Global HTTP
total remains unknown. Source-bound coverage receipts are in
`tests/verification/github-requests/http-counter-coverage-linux-2026-10-07.json`.

The offline suite runs without Go or network and proves metadata validation
plus Linux replacement/sealing boundaries. Its Linux sealing tests refuse
unsupported kernels; Windows runs metadata-only and explicitly does not qualify
sealed execution. A real build requires the verified archives, Linux/amd64, a C
compiler for `go test -race`, network access for checksum-verified upstream Go
modules, and OpenSSL for the disposable local TLS fixture. Missing real
qualification prerequisites fail; they are not skipped or counted as passes.
The build's concurrent twenty-request race fixture checks original-hook
composition and a trusted server ledger. The full CLI fixture checks pagination,
real hidden retry, cache hits, stdout/stderr/status parity, missing finish,
cancellation without replay, secret exclusion and descendant environment
isolation. Fixture tokens, query and body sentinels are synthetic; no GitHub
mutation is performed.

The [sanitized October 7 Linux proof](../../../tests/verification/github-requests/http-counter-linux-2026-10-07.json)
binds source/build hashes, fixture results and both twenty-pair timing
distributions. It preserves the rejected Python helper measurement separately
from direct counter timing; neither is installed workflow acceptance.

`run.py` is a qualification-only runner with per-call binary hashing. Its extra
process/hash cost failed the 5% budget and must not become production routing.
Direct binary/private-pipe measurements isolate counter cost. Neither local
fixture timing nor offline validation proves installed workflow latency.
Future integration reuses the existing Bash caller's protected channel after
independent exact-head security review, checks and each host's guarded install.
Source/stat digest validation and invalidation need their own security proof.

The finite managed-command fixture census additionally exercises auth status,
issue/PR lists and views (including comment pagination), PR checks, run and
workflow reads, repository view and raw GraphQL. Every case now requires an
actual complete counter receipt matching the local server ledger. Identical
command output without counter metadata fails qualification. This test-only
execution preserves the narrower qualification CLI restrictions; it does not
enable an ordinary-environment runner or installed routing. The separate
`--managed-commands` timing mode runs twenty alternating pairs in each of
cold-config and warm-config groups with independent baseline/candidate state.
It includes sealed-image verification, private pipe and metadata validation,
requires both p95 and total elapsed ratios at most 1.05, and exits unsuccessfully
when either group misses. It qualifies the measured finite local workload only;
subprocess traffic, whole-account totals and installed performance stay separate.

## Bounded supervised task reads

`managed_read.ManagedReadObservation` is an explicit Linux observation API,
separate from the isolated `run.py` CLI. It requires the exact build-manifest
digest, an exact `ai-gh` path/hash, and the existing protected authentication
configuration. It does not install anything, replace the vendor CLI, enable
global routing, copy authentication files, or print configuration values.
Only explicit public `popcre/ai-devops` issue/PR/run/repository reads with JSON
fields are admitted. Mutations, aliases/extensions, implicit repository context,
executor flags, interactive terminals, source-injection variables and explicit
caller `GH_PATH` decline qualification. The ordinary command remains available.
An ambient `AI_GH_REAL_GH` also declines qualification. A local version read
of the original protected vendor ELF must match the bound source release;
historical profiles require explicit `historical_profile=True` and cannot
establish current runtime acceptance. No system CLI is changed.
Literal `cat` pager settings remain unchanged in this noninteractive JSON
profile. Configuration-directory group access is accepted only when NSS
explicit members plus primary-group users resolve exclusively to its owner;
foreign/world-write access is refused. Existing fixed configuration files are
inspected through anchored no-follow metadata handles only, never read: each
must be a singly linked owner file with mode 0600. Symlinks, hard links and
public file permissions decline qualification without changing configuration.

The controller holds `report.retained_generation(root, install_manifest)` and
passes its live mapping as `transport_boundary`.
The boundary is an opaque active capsule produced by canonical `import report`,
not a serializable dictionary. Closed or forged capsules decline qualification.
The bounded Linux cohort implementation borrows independent sealed source/image
descriptors once, mounts the readonly source and both verified native images in
one owned Bubblewrap namespace, and closes the borrowed descriptions after
bootstrap. Its frozen source is the capsule's exact generation; no later mutable
controller import replaces it. The original `ai-gh` executes inside that boundary
with the selected readonly image in a namespace-only private tmpfs.
`AI_GH_REAL_GH` selects that image only inside the owned child. Existing shared
pacing, credentials, quotas, probes and backoff remain in force; no alternate
real GitHub throttle state is created.

The candidate setup copies captured files only into the three fresh private
`bin`, `tools` and `config` tmpfs trees with explicit captured modes, closes setup
writers, then remounts each whole tree readonly before execution. This avoids
hundreds of individual source bind mounts without a writable host alias. The
top-level `.gitattributes` capture remains an individual readonly bind, since it
is outside those fresh trees. Each launch borrows independent readonly source
descriptions for both `--file` and `--ro-bind-data`; no consumed offset is reused.
Qualification checks cover file/tree mutation, mode changes, hardlinks, remounts,
inherited writer descriptors, repeat launches and canonical-file immutability.

This is Linux-only, private cohort custody, not a global service, persistent
daemon or production route. A literal `python -I -S` bootstrap loads only the
sealed worker and excludes user-site/source-injection startup. The frozen original
environment and working directory are preserved for the actual command. An
inherited noninheritable `AF_UNIX/SOCK_SEQPACKET` capability carries bounded
unique-key JSON, strict monotonically increasing command ordinals and exactly
four transferred descriptors: caller stdin/stdout/stderr and the numeric writer.
Packets, ancillary truncation, unexpected handles, unsupported arguments and
nonfinite values are refused without command replay. No socket name or listener
is published on the host.

`run(arguments, opaque_workflow_id, ...)` streams caller-owned standard
descriptors unchanged and returns `(original_status, observation)`. Up to forty
commands are allowed; each has a supervised timeout of 1–300 seconds (120 by
default). A cohort has a fixed 12,030-second maximum lifetime (40 times the
300-second command budget plus 30 seconds of bootstrap/cleanup allowance), not
a renewable background lifetime. Cold and warm qualification groups use separate
cohorts. Twenty pairs consume forty worker slots only when both members execute
inside the worker; an ordinary outside-capsule baseline is counted separately,
never relabeled as a worker command or dropped from the paired denominator.
Worker-only subreaper custody
reaps actual direct/adopted descendants on close, timeout or cancellation;
unrelated parent/host processes are not adopted. The ready worker is bound by a
retained pidfd before signals are forwarded, avoiding numeric-PID reuse; cleanup
signals only owned pidfd-bound or still-unreaped descendants. Signals reach the
owned workload; timeout/cancellation never replays a command and yields unknown
metadata. The inherited controller socket is never passed to ordinary children.
`cohort_cleanup_complete` is explicit; unsuccessful cleanup cannot qualify a
timing cohort. Source/image descriptors are also excluded from the ordinary child.
A complete observation sums strictly
sequential numeric start/finish pairs once, including observed admission
identity/quota probes. Empty, truncated, interleaved, oversized or incomplete
pairs remain unknown. The uninstrumented image produces unknown, never zero.
Real before/after toolkit cohorts must both use the instrumented image;
counter-off/on pairs measure instrumentation overhead only.

Source identity is attached only to an actual complete wrapped observation
while the retained generation is held. An ordinary transport hash bookend
alone leaves loaded source unknown. The summary includes the source boundary's
bootstrap time, image verification and whole cohort elapsed time after teardown;
missing source bootstrap timing is explicit. Performance qualification must
include source/image verification, worker/namespace/socket startup, all command
work, numeric validation and final worker/descendant teardown over the same
outcomes. No setup, cleanup, shared pacing or external CI latency is hidden to
obtain a timing pass. The bounded cohort implementation remains qualification
machinery until actual complete measured receipts establish its result; earlier
per-command namespace/hash failures stay preserved. The finite counter-only timing result does not establish
the supervised route's overhead. Counts remain completed writes in the covered
primary API constructors; subprocess traffic and whole-account HTTP totals stay
unknown. No production or fleet acceptance follows from local fixtures.

The exact-source `--full-observer` qualification compares the ordinary
outside-capsule baseline against the complete observer using two independent
twenty-pair cold/warm groups. The approved matching `updateable` CLI build and
source `53107ea9` passed once: cold bootstrap-amortized p95 +4.66224% and total
+0.74847%; warm p95 +1.14350% and total -0.62509%. All bootstrap, matched warm
setup, command work and teardown were charged; both groups cleaned up and their
actual fixture request ledgers matched (84/84 cold, 60/60 warm). The protected
receipt digest is
`7257394fc50b4fd8c92e4c75518e8251a1da1c6c3780d94088df5a91ef80e615`.
The earlier strict cold failure and non-updateable development variant remain
preserved; neither was retroactively relabeled. This qualifies that finite
Linux fixture workload only, not installed useful-work, natural savings,
Windows cold performance or whole-account traffic.

## Explicit native Windows managed reads

The existing Linux SSH controller `../remote_wait.py` can compose its restricted
read-only Windows source supervisor with a matching counter build using
`--counter-manifest` and `--expected-counter-manifest-sha256`. See the
[operator guide](../../../docs/ai-tools-cheat-sheet.md#github-measurement-qualification-660-under-658)
for the bounded invocation. This is separate from the synthetic fixture below.
Only finite public `issue view` and `pr view` commands qualify. Arguments are
bound before execution through bounded inline transport. The parent retains
the matching image, complete source closure and separate bounded numeric pipe;
the original shared admission, authentication, output and status remain intact.

The pinned upstream configuration-directory precedence is preserved. Native
metadata-only handles check its original ancestors and credential files before
any command; foreign readers or writers decline qualification. The controller
does not read credential bytes, create substitute authentication, change ACLs,
or relax a refusal to obtain a measurement. Ordinary vendor routing remains
available. A passing source/controller fixture is not a useful counted read,
and a complete numeric receipt is not whole-program HTTP or GraphQL accounting.
The measured Windows native cold overhead remains failed; earlier full Linux
observer failures remain preserved separately from the later repaired finite
Linux qualification. This Windows mode stays explicit qualification machinery.

## Isolated native Windows qualification

This is fixture-only code owned by #660. Current runtime-profile native
execution requires its actual reviewed fixture receipt; historical receipts,
compilation and offline tests are separate evidence. None alone qualifies
installation, production routing, MSYS
result transport, Windows TLS/auth/context coverage or a global HTTP total.
Native commands and the OS-installed gh remain untouched. The pinned build
does not supply vendor signing, Windows resources or official release parity.

`build.py --target windows-amd64 --compile-native-fixture` cross-builds the
paired images and the existing counter package's native test executable from
the same pinned official Linux Go archive. It keeps the sealed archive and
private anchored-directory build boundary. Windows uses identical version,
date, `-s -w` and trimpath flags for both images; the default upstream build
tags disable the updater. Windows race execution is not claimed.

The versioned `counter_source_binding` binds the complete finite input closure:
httpcounter.go, httpcounter_test.go, channel.go, channel_linux.go,
channel_windows.go, channel_unsupported.go, channel_windows_test.go,
windows_cli_fixture_test.go, native_fixture.ps1 and pins.json, in that order.
The locked registry is the same single version map used by the builder and
native guard; the guard contains no duplicate commit/archive pin table.
The finite capabilities declare one constructor and no detached CLI telemetry
for 2.88.1, and two constructors with telemetry for 2.95.0/2.97.0/2.103.0/2.103.3 (and the
historical 2.101.0 profile). The common patch checks the exact declared return,
import, source-directory and finalization hooks before any edit. The older
profile's native child test exercises both actual images with telemetry
requested, asserts its declared absence and verifies actual API counter output;
it does not skip or remove an implemented feature. Authentication-login and
other out-of-profile clients remain outside this finite coverage.
`compiled_counter_source_binding` binds the post-gofmt copied closure. The
existing `patch_sha256` still means only httpcounter.go's input bytes; it is
insufficient alone. Missing, altered and extra source files are rejected.
The tracing suffix has a fixed reviewed digest; constructor/final hooks remain
unchanged. Captured input bytes are the bytes copied into the private build.

The root coordinator must review the exact source/build head BEFORE copying
or executing anything on the sole permitted Windows fixture host. Recheck
physical runner/runtime collision first. Stage only reviewed images, build.json
and the complete input closure under a fresh owner-only local application-data
Temp directory, or a fresh DIRECT child of the existing protected system
ProgramFiles directory, named ai-devops-gh-counter- followed by 16–32 hex digits;
images and manifest are at its root, input sources under source/.
The second fixed parent is temporary native qualification only: no installation,
routing or base-directory creation. Root must independently review the exact
finite staging action and existing parent protection; foreign write/delete/ACL
modification or unknown protection means refusal. Create the new root and source
child atomically with owner/SYSTEM/Administrators protected ACLs. Never change
an existing ACL, use an arbitrary root override or select a fallback location.
Trusted staging must also atomically create a protected fixed `temp` child.
Before Add-Type, the guard rejects unknown/link/unsafe root or temp directories,
saves and clears all ambient fixture/counter prefixes and config/self-path/
telemetry controls, exercises hostile process-local sentinel values, and sets
TEMP/TMP only to that private child. Native locks retain it through the suite;
compiler and Go temporary writes stay there. Original caller values are restored
in finally, including failure. No ambient role, test, config or telemetry URL
may select fixture behavior; the existing native telemetry case supplies its
own local endpoint. Native environment outcomes remain mandatory qualification,
never inferred from offline source checks.
Invoke the staged source/native_fixture.ps1 with that fixture directory and
the independently reviewed build.json SHA-256 as ExpectedManifestSha256.
The script opens every ancestor and staged file with native no-follow handles
before reading; ownership, type, reparse status, link count and identity come
from those handles. A private DACL must be present, protected and non-null;
only explicit allow entries for the owner, SYSTEM and Administrators with
exact full-control/read/read-execute masks are accepted. Deny, inherited,
callback and other entries are refused. Hashes use the same retained handles;
execution paths come from those handles and are re-bound to their identities.
Volume-to-leaf ancestor locks deny deletion; image locks deny writes/deletion
until native tests finish. No staged ACL, service, task, PATH, trust store or
credential changes. Hostile ACL/link fixtures affect fresh private test objects
only. Nine actual native boundary cases must pass before the Go fixture runs:
null/world/unprotected/deny DACLs, verified-byte write/rename replacement,
hard links, symbolic links, repeatedly redirected junctions and held ancestor
rename/reparse replacement. Missing native capabilities mean unknown, never
skip-success. Offline assertions do not establish these native outcomes.

The native parent creates anonymous owner/SYSTEM pipes only, checks actual
input-direction capacity above the 1024-byte total record bound, whitelists
only standard handles plus the metadata writer, and drains concurrently.
Windows uses the distinct HANDLE key, never an MSYS fd. Child initialization
clears all three reserved keys and writer inheritance before descendants.
Exactly the existing two numeric records are allowed; absent final records,
crashes, malformed channels and concurrent incomplete work mean unknown.

Native cases cover invalid/standard/file/MSYS handles, reserved keys,
inheritance sentinel and grandchildren, separate concurrent channels, capacity,
paused/closed readers, strict two-record parsing, record sizing, verify/use image
and ancestor replacement, pagination/hidden retry/redirect server ledgers,
Unicode/header/stdio/status parity, forced cancellation without replay, actual
console cancellation, the profile's detached-telemetry capability or declared
absence, and numeric receipt shape. Absence
of a console is a genuine unknown failure, never a successful skip. The
offline source-binding and numeric-schema cases additionally reject missing,
mismatched/extra source and receipt fields, text, forged digests and NaN.

Both cold-process and warm-private-config groups contain 20 alternating pairs.
Fresh processes are always used; no OS page-cache flush is claimed. Timing
includes channel construction, primary lifecycle, drain and validation; held
image verification occurs once outside the timed region. Each group must meet
both p95 and total elapsed <=5% gates. Historical failed Python overhead and
prior Linux distributions remain separate evidence.

After the complete native test selection, numeric-result.json is emitted in
the locked private fixture directory even for failures. Its values are only
numbers, booleans, null and numeric arrays. Digest arrays follow the source
order above; binary arrays are baseline, instrumented, native fixture. Raw
timing arrays identify cold/warm baseline/candidate. No routes, command text,
headers, tokens, bodies or diagnostics enter this file. Numeric receipt
validation re-binds every digest and independently checks performance gates;
the whole HTTP total remains null and installed acceptance remains false.
No public Windows receipt is fabricated before actual execution.

The [retained native evidence](../../../tests/verification/github-requests/p1-baseline.md#first-windows-297-native-qualification)
includes the 2.88.1 cold failure and the first actual 2.97.0 attempt's warm-gate
failure and unknown baseline detached-telemetry parity. That older compiled 2.97 fixture could
not decode boolean capability pins and emitted no numeric receipt; cold p95,
warm p95 and total ratios therefore remain unknown. No performance pass follows
from source presence, completed pair count or missing reported cold failure.
One authorized receipt-only fixture rebuild reused the exact frozen 2.97 CLI
images and yielded a retained failed qualification: twenty cold pairs p95
+128.40061% and total +40.88737%; twenty warm pairs p95 -42.67821% and total
-12.57680%, passing only the warm group. Detached-telemetry parity was unknown
in that timing attempt. The corrected numeric result is separate from the
first missing
receipt, not a reclassification or repeat-until-pass; it does not qualify the
full supervised route.
The telemetry unknown was subsequently traced to the fixture's bare-path
classifier: the pinned vendor appends its Twirp method path. The focused
six-line fixture repair passed both unchanged CLI images' child parity plus
the seven environment and nine boundary cases, with zero timing pairs.
That functional proof does not change either retained performance failure.
A separate cause-only capture aligned its first pair with Defender OnOpen
waits; the historical long launch stall was not reproduced and remains
unattributed. That diagnostic neither clears a cold gate nor transfers 916's
different kernel-cleanup attribution to the 2.97 host. No security setting or
vendor capability was changed.

## Active-operation scope

Finite source-isolated read profiles preserve environment, cwd, authentication,
streams and original descriptor limits; they do not assert identical OS
privileges or arbitrary privileged-provider compatibility. Existing immutable
read receipts and constructor counts retain that narrower scope.

The separate common BlockerWatch completion adapter merged through PR #2283 is not a counter
performance qualification. Its default original-context/provider path declines
qualification before executing the original command once outside the namespace.
The explicit `sdk_only_no_provider` alarm/links profile records actual privilege
restrictions and measures `parent_acknowledged_active_begin_to_end`, including
control transport. Full caller-through-cleanup elapsed/setup costs remain
separate, and external caller startup/final storage are not silently excluded
from a whole-observer verdict: that verdict stays unknown. Native integration
and installed proof remain required. Durable producer event facts grant neither
source nor clock authority. Consumer #2286 (`221cb504`, tested `f2a90c12`) can join only actual
live-channel facts after matching acknowledged END, with a separate receive
clock, default-off explicit SDK scope and one fact per ID. Only successful
standalone SDK alarms can receive conservative batch-ack detection; links,
wakes, ticks and original/provider context remain unknown. Native integration
landed through #2289; #2290 repaired suite registration and actual changed-head
CI passed all twelve Windows sections with the new fixture executed. Final
normal full installations/source verification at final successor #2291
(`10ae0b93`) are complete on the five originally reachable toolkit hosts, with local CI
capacity restored. Older read/counter receipts keep their actual generations.
No completion envelope is
event-detection latency.

The native remote counterpart must use Linux parent BEGIN/facts-receive clocks
and genuine eligible GitHub UTC, never subtract Windows wall clocks. Its named
boundary is parent-received alarm batch acknowledgement over SSH and includes
transport; it does not claim an exact native SDK-ack interval or full-budget pass.

The finite dry-run parity successor merged through #2291. Its actual caller-argument
flag, rather than producer frames, excludes simulated work from both qualified
completion/event intervals and active-success classification. Raw diagnostics
and original execution remain available; simulation cannot establish acceptance.

T16 accepts its documented existing SSH identity and returns fresh output, but
owned SSH termination/EOF remains unknown at the twenty-second bound even with
no stdin/PTY. Its installed source/ownership and process cleanup remain unproved;
no T16 install/count is safe yet. Existing local session repair is required.
Actual vendor output reports 2.95. Its finite profile merged through #2293
(`34170e89`), with two constructors/detached telemetry, paired updateable builds
and verified go-gh v2.13 configuration-directory precedence. The first native
functional run on existing host 916 passed 26 top-level functions/four subcases
and the environment/boundary, ledger, child, stream/status and cancellation
checks; fourteen frozen artifacts were unchanged and owned processes zero.
No real GitHub demand, timing pair or vendor change was introduced. This
`6233`/V3/916 fixture does not prove T16 vendor-image hash, installed source,
custody, original privileges or timing, and does not retarget the five installed
`10ae` toolkits or their older measurement receipts. Actual runtime admission
must still satisfy the unchanged source/version/configuration guards.

The one actual installed `links --dry-run` live proof at `10ae` verified
source/protocol/cleanup and exited zero, with one skipped operation/24 skipped
items and zero attempted actions. Both interval types remained null and active
success false. This proves the live component path, not active business work,
request reduction, detection, privileged-provider authority or a budget verdict.

## Retirement

#660 owns the minimal pinned patch until upstream supplies an equivalent
private structured outgoing-write counter. Retire the patch/build helper when
native retry/privacy/parity evidence meets the same contract; preserve existing
unknown and measured-subset history. Requalify each upstream version change.

Primary sources: [GitHub CLI client constructors](https://github.com/cli/cli/blob/v2.103.3/api/http_client.go),
[CLI exit boundary](https://github.com/cli/cli/blob/v2.103.3/cmd/gh/main.go), and
[Go httptrace](https://pkg.go.dev/net/http/httptrace).
