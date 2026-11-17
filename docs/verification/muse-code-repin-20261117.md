---
summary: Verification of the Muse Code 1.4.23 Windows binary hash and pin on edge-dev after Meta's auto-update, 2026-11-17.
kind: proof
status: done
read-when: Re-pinning or auditing the Muse Code release version and hashes
---

# Muse Code release verification — November 17, 2026

Owner: ZCode (edge-dev session), follow-up to PR #1923 (Windows re-pin after Meta's auto-update). Meta's auto-update replaced the pinned `muse-bin-1.4.11-R6667.1.exe` with `1.4.23-R8977.1`, so the 2026-11-17 Windows install failed its optional Muse Code stage with "Meta installed a different Muse Code than the pinned 1.4.11-R6667.1".

## Official release provenance

Retrieved through HTTPS from Meta's public stable channel:
https://api.meta.ai/muse-code/channels/muse-stable

The channel reports public release `1.4.23-R8977.1` (state `public`) and points to:
https://lookaside.facebook.com/lookaside/muse/download/?channel=muse&version=1.4.23-R8977.1&file=manifest.json

The manifest specifies SHA-256 and, for Windows x86_64 (`x86_windows`):

- `9ff96e49e2c623f35ea002a4aab08c29b08878636cbe218be388f8e0d5f33de1`, 602107128 bytes.

This now equals `config/muse-code/sha256`; `config/muse-code/version` is `1.4.23-R8977.1`.

## Installed binary

`%LOCALAPPDATA%\Programs\muse\muse-bin-1.4.23-R8977.1.exe` on edge-dev matches the manifest hash (recomputed locally) and size.
Its `--version` returns `Muse Code 1.4.23 (1.4.23-R8977.1)`.

## Installer

Meta's current Windows installer (https://dev.meta.ai/install.ps1) SHA-256 is still
`45be8be39acf500982e816a09eb55b886ef65a986895741b10498c50bbb93776`, identical to `config/muse-code/windows-installer-sha256` (unchanged by this re-pin).

## Reviewer impact

None. `ai-muse` runs the muse reviewer through the OpenCode `muse-meta`/`muse-openrouter` API routes (`bin/ai-second-opinion`), never the desktop `muse-bin` binary, so the drift did not affect review capability. The desktop app pin only guards the optional install stage.

## Linux

Not re-pinned. `config/muse-code/linux-x86_64/` stays at its previous record; the 1.4.23 manifest lists a new `x86_linux` artifact (`7ca9e16659f759eab3ae6c4b61c6f1e70f5f3fea1ca961ebd49044a1146956f4`, 466999640 bytes), which needs its own re-pin and live stage proof on a Linux host.
