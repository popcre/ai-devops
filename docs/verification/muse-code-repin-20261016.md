# Muse Code release verification — October 16, 2026

Owner: Codex, scoped Muse installation repair. This record accompanies the pin correction.

## Official release provenance

Retrieved through verified HTTPS from Meta's public stable channel:
https://api.meta.ai/muse-code/channels/muse-stable

The channel reports public release `1.4.9-R6297.1` and points to:
https://lookaside.facebook.com/lookaside/muse/download/?channel=muse&version=1.4.9-R6297.1&file=manifest.json

The manifest specifies SHA-256 and these exact artifacts:

- Linux x86_64: `a228010021276e112aa8422eb56ae82c0375405701950f6529bed4c9fe8abe05`, 372586712 bytes.
- Windows x86_64: `c877fc5f852b8030a015e24ead5959d79771d4f6f78d28b748a83c711c59abc6`, 475627256 bytes.

The existing edge-dev3 Linux binary matches both published hash and size. Its `--version` returns `Muse Code 1.4.9 (1.4.9-R6297.1)`.
The edge-dev Windows binary was inspected through read-only SSH and matches the Windows hash and size.
Meta's current Windows installer SHA-256 remains `45be8be39acf500982e816a09eb55b886ef65a986895741b10498c50bbb93776`, identical to the repository pin.

## Check semantics

The Linux stage is an inline function in `install.sh`, not a separate helper. It invokes https://dev.meta.ai/install.sh only when the version-named binary is absent, then requires that filename and its SHA-256 to match the Linux architecture pins. It does not execute `--version`; the reviewer wrapper additionally verifies the reported version.
Windows calls `bin/windows-muse-code-install.ps1`, uses the top-level version/hash pins, and additionally verifies the installer hash before executing a download.

## Windows local work

Read-only diffs of the top-level version/hash files across edge-dev's registered worktrees showed no uncommitted pin edits at inspection time. No Windows checkout files were changed, stashed, or committed. The correction here was independently derived from Meta's manifest.

## Separate follow-up

The reported `bin/ai-housekeeping: line 1: tmp: unbound variable` was tracked separately in [#1813](https://github.com/popcre/ai-devops/issues/1813), repaired by [#1810](https://github.com/popcre/ai-devops/pull/1810), and live-verified before #1813 closed. Duplicate [#1815](https://github.com/popcre/ai-devops/pull/1815) was closed as superseded; its alternative implementation was not landed. The Muse pin PR changed no housekeeping code.

## Live Linux stage result

On edge-dev3, executed the unchanged `run_stage` and `install_muse_code_linux` definitions extracted from this candidate's `install.sh`, with `REPO_ROOT` pointing at the candidate. The existing binary was present, so this was the stage's idempotent verification path: no installer download, profile changes, or full toolkit update.

Result: `PASS optional Muse Code (Linux)` (exit 0). This proves the corrected stage against the real installed binary; it does not claim a full toolkit installation or reviewer workload qualification.


## Final installed acceptance — October 16, 2026, 1:03 PM EDT

[PR #1814](https://github.com/popcre/ai-devops/pull/1814) merged as `f720f7e88ebc6cab2d6598b4aed10f59f28fa9b8`. The protected candidate-worktree update installed this exact commit on edge-dev3; the clean installed checkout and protected manifest matched it. This full installation supersedes the earlier extracted-function check above as delivery proof.

The assigned DeepSeek exact-target final review approved the actual release range with recorded passing tests: 66 Muse checks, 18 housekeeping checks, and 37 version-pin checks. All 33 installation stages passed or were intentionally skipped, with zero failures. The protected stage report contained both real rows:

- `PASS optional Housekeeping schedule`
- `PASS optional Muse Code (Linux)`

Live verification invoked the installed housekeeping scheduler twice. Both invocations and the installed read-only inventory report exited successfully with zero-byte stderr. Exactly one daily housekeeping entry remained; repeated scheduling produced identical crontabs, preserved unrelated entries, and left no temporary files. Parent verification independently checked the source/manifest identities, stage rows, report checksum, repeated-crontab equality, and empty stderr. Completion evidence is recorded on [#1813](https://github.com/popcre/ai-devops/issues/1813#issuecomment-6220614234).

The first protected update attempt stopped before installation because its first child sudo command requested authentication again. Its native pending transaction remained resumable; the corrected prompt-bound credential driver resumed that same authorization. The successful retry consumed/finalized it natively, leaving no pending authorization. No credential was exposed or retained in an input file.

These two scoped outcomes are complete. This record does not claim completion of the broader reviewer-recurrence programme, a live Windows installation, native Muse workload qualification, or elapsed reliability acceptance.

Documentation-only publication and final workspace disposition continue in [the closeout handoff](../../HANDOFF.d/2026-10-16T1718Z-edge-dev3-codex-muse-closeout.md).
