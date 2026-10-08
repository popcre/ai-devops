# Linux outgoing-write counter prototype

Owner: [#660](https://github.com/popcre/ai-devops/issues/660), under #658.
This extends the existing measurement namespace. It does not install, alter
`ai-gh` routing, replace vendor `gh`, or establish programme acceptance.

`pins.json` binds upstream CLI 2.101.0 to an immutable commit/archive and the
official Go 1.27.1 Linux toolchain archive/hash. `build.py` accepts those two
verified archives (`gh.tar.gz`, `go.tar.gz`) from a private directory and builds
unmodified/instrumented binaries in a new private output directory. It changes
only the two upstream API client constructors, the CLI finalization point and
the new internal counter package. Modules retain upstream `go.mod`/`go.sum`.
No binary or upstream source archive belongs in this repository.
Archives are copied into Linux memfd snapshots, sealed against write/grow/shrink
before hashing, and extracted from those same verified immutable bytes.
Qualification execution likewise uses a verified sealed ELF snapshot held by
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
qualification work. Windows is unsupported until true inherited HANDLE
isolation has been proved; compiling a Windows binary is not that proof.

## Verification

```bash
bash tests/test-gh-http-counter-prototype.sh
python3 tools/github-requests/instrumented-gh/build.py --archives /PRIVATE/archives --output /PRIVATE/new-build
python3 tools/github-requests/instrumented-gh/test_prototype.py /PRIVATE/new-build/build.json
python3 tools/github-requests/instrumented-gh/measure_overhead.py /PRIVATE/new-build/build.json
```

Create the private output directory first. The ordinary development build
disables the update notifier using upstream's default build tags. A separate
paired local variant uses `build.py --qualify-updater` and the supported
upstream `updateable` tag; its manifest records that distinction. The same
fixture command against that manifest exercises TTY update success and
concurrent command failure. Original-build results explicitly skip this
case and cannot qualify updater behavior or installed release feature parity.
All proxy destinations are mapped to the local trusted server; no updater or
telemetry request reaches GitHub. Enabled telemetry still sends one detached
local request, excluded from the primary process observation. Global HTTP
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

## Isolated native Windows qualification

This is fixture-only code owned by #660. No Windows execution receipt exists
until the reviewed fixture runs; compilation and offline tests are separate
evidence. Neither success qualifies installation, production routing, MSYS
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
windows_cli_fixture_test.go and native_fixture.ps1, in that order.
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
console cancellation, detached telemetry, and numeric receipt shape. Absence
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

## Retirement

#660 owns the minimal pinned patch until upstream supplies an equivalent
private structured outgoing-write counter. Retire the patch/build helper when
native retry/privacy/parity evidence meets the same contract; preserve existing
unknown and measured-subset history. Requalify each upstream version change.

Primary sources: [GitHub CLI client constructors](https://github.com/cli/cli/blob/v2.101.0/api/http_client.go),
[CLI exit boundary](https://github.com/cli/cli/blob/v2.101.0/cmd/gh/main.go), and
[Go httptrace](https://pkg.go.dev/net/http/httptrace).
