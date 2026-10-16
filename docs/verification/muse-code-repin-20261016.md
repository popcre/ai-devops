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

The reported `bin/ai-housekeeping: line 1: tmp: unbound variable` during Housekeeping schedule remains outside this repair. Investigate its erroneous PASS separately; no housekeeping files are changed here. Owner: ai-devops maintenance, tracked in this PR follow-up.

## Live Linux stage result

On edge-dev3, executed the unchanged `run_stage` and `install_muse_code_linux` definitions extracted from this candidate's `install.sh`, with `REPO_ROOT` pointing at the candidate. The existing binary was present, so this was the stage's idempotent verification path: no installer download, profile changes, or full toolkit update.

Result: `PASS optional Muse Code (Linux)` (exit 0). This proves the corrected stage against the real installed binary; it does not claim a full toolkit installation or reviewer workload qualification.
