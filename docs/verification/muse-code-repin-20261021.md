# Muse Code release verification — October 21, 2026

Owner: Claude, follow-up to PR #1923 (Windows re-pin after Meta's auto-update). Re-verified 2026-10-21 on al8960ofc.

## Official release provenance

Retrieved through HTTPS from Meta's public stable channel:
https://api.meta.ai/muse-code/channels/muse-stable

The channel reports public release `1.4.11-R6667.1` (state `public`) and points to:
https://lookaside.facebook.com/lookaside/muse/download/?channel=muse&version=1.4.11-R6667.1&file=manifest.json

The manifest specifies SHA-256 and, for Windows x86_64 (`x86_windows`):

- `8844783f7e02b2f6b21ad0d60eefb1ddda392576f11fa811ae95e1448bcfa1f8`, 493931256 bytes.

This equals `config/muse-code/sha256`; `config/muse-code/version` is `1.4.11-R6667.1`.

## Installed binary

`%LOCALAPPDATA%\Programs\muse\muse-bin-1.4.11-R6667.1.exe` on al8960ofc matches the manifest hash and size.
Its `--version` returns `Muse Code 1.4.11 (1.4.11-R6667.1)`.

## Installer

Meta's current Windows installer (https://dev.meta.ai/install.ps1) SHA-256 is still
`45be8be39acf500982e816a09eb55b886ef65a986895741b10498c50bbb93776`, identical to `config/muse-code/windows-installer-sha256`.

## Linux

Not re-pinned. `config/muse-code/linux-x86_64/` stays at `1.4.9-R6297.1`
([October 16 record](muse-code-repin-20261016.md)); the 1.4.11 manifest lists a different Linux artifact,
which needs its own re-pin and live stage proof.
