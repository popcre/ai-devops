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

The qualification CLI accepts only builtin `api` GET/HEAD, `auth status`,
`issue list/view`, `pr list/view/checks`, `run list/view`, and
`workflow list/view`, excluding browser/watch options. It refuses other
families before binary access. This restriction belongs to the optional
qualification helper; the vendor CLI and installed routing are unchanged.
For admitted commands with no caller `GH_PATH`, the helper uses upstream's
supported override bound to its still-open verified sealed image. That keeps
detached telemetry self-execution working without leaking counter descriptors
or keys. Caller overrides retain their original semantics and remain outside
the qualified scope. Durable credential setup, long-lived codespaces, skills,
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

## Retirement

#660 owns the minimal pinned patch until upstream supplies an equivalent
private structured outgoing-write counter. Retire the patch/build helper when
native retry/privacy/parity evidence meets the same contract; preserve existing
unknown and measured-subset history. Requalify each upstream version change.

Primary sources: [GitHub CLI client constructors](https://github.com/cli/cli/blob/v2.101.0/api/http_client.go),
[CLI exit boundary](https://github.com/cli/cli/blob/v2.101.0/cmd/gh/main.go), and
[Go httptrace](https://pkg.go.dev/net/http/httptrace).
