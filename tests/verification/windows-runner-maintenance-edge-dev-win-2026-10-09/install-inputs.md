# edge-dev-win (EDGE-DEV) step 6 — live recovery and install inputs

Date: 2026-10-09. Scope: `plan_windows-runner-maintenance-elevation.md` step 6,
issue #962 / parent #262. This document is the exact live-install authorization
packet for an independent security reviewer. It is not an install by itself.

## Host and identity

- Host: `edge-dev-win` (Windows hostname `EDGE-DEV`; SSH alias `edge-dev`).
- Operator: local `EDGE-DEV\ahazan`, SID `S-1-5-21-3782134917-2737737491-2203520143-1001`.
- Task: `\AiDevOps\WindowsRunnerMaintenance`.
- Payload root: `C:\Program Files\ai-devops\windows-runner-maintenance`.
- Runtime root: `C:\ProgramData\ai-devops\windows-runner-maintenance`.
- Evidence: `C:\ProgramData\ai-devops\windows-runner-security.json` (content never printed).

## Exact reviewed head and payload hashes (origin/main 698554f6)

- `bin/install-windows-runner-maintenance.ps1` `c2d2719570f05c82a9defbf9556263a167efc2a5d30f559240a3af985d824830`
- `bin/windows-runner-maintenance-worker.ps1` `c763a9aff60f92ecca16be07ae7e1d43fc57bb608490eec0a74b59fa912f10f4`
- `bin/launch-worker.bat` `02cccf7873d2b01b27665434600b89e5aae3fa27d106215e3cc09e2bbac32d92`
- `config/windows-runner-maintenance-policy.json` `255f91de23c6585ce9ac60444685fa1aa1ba777d99bb794a7c9c7d0b727453e7`
- `bin/qualify-windows-runner.ps1` `172e1dac1d6de2407acef170b5f63332fb0bfa1e8db73e27b16d6ad2168ccaf7`
- `bin/invoke-windows-runner-maintenance.ps1` `c1ec759e3d9e7ae6c46c3325be41362715eb563a2da833e2c8781b791e6aeff4`

## Current live state (re-derived 2026-10-09)

- Install verifies against its own Oct 8 manifest; runtime records preserved
  (audit.jsonl, processed-requests.jsonl, five result files spanning 2026-09-28
  and 2026-10-08). Installed policy hash `939e8f58…` differs from current source
  `255f91de…` — payload drift is why a recovery+install from this head is required.
- Task Ready, S4U Highest, fixed action `cmd.exe /d /c launch-worker.bat`, last result 0.
- Secure Boot `Confirm-SecureBootUEFI=False` (firmware). TPM present/ready.
- Runner service `actions.runner.popcre-ai-devops.edge-dev-win` is Stopped / Auto /
  NETWORK SERVICE. **Not modified by this work.** Runner stays unqualified.
- Uncommitted draft in the `edge-dev-runner-qualification` worktree is diagnostic
  only and is not installed.

## Authorized commands (exact)

Elevated (SSH session on this host yields High IL / Administrators):

1. `pwsh -NoProfile -File .\bin\install-windows-runner-maintenance.ps1 -RecoverPartial -Install -OperatorUser "$env:COMPUTERNAME\ahazan"`
   - Must preserve runtime request/result/audit/replay records.
   - Must seal (drop operator ACE) and disable the task before unregister.
   - Must export a verified per-entry backup bundle first.
2. `pwsh -NoProfile -File .\bin\install-windows-runner-maintenance.ps1 -Verify -OperatorUser "$env:COMPUTERNAME\ahazan"`
3. Rollback if needed: `pwsh -NoProfile -File .\bin\install-windows-runner-maintenance.ps1 -Remove -RequireManifestMatch -BackupPath C:\ProgramData\ai-devops\reviewed-maintenance-recovery-edge-dev-win`

Non-elevated operator context (required for invoke and privilege negatives):
the operator UAC-limited token (Medium IL, Administrators deny-only), proven
before use. Elevated SSH is never used to simulate a negative test.

4. `pwsh -NoProfile -File .\bin\invoke-windows-runner-maintenance.ps1 -Operation refresh-qualification`
   (and the §10 / ENVY-matrix negatives, concurrency, wrong-owner, rollback and
   idempotency cases).

## Hard refusals

- Do not touch EDGE-RUNN-ENVY.
- Do not install the uncommitted draft worktree.
- Do not stop/start/reconfigure/relabel the GitHub runner service.
- Do not qualify the runner (labels stay candidate/unqualified until its own
  full GitHub qualification passes).
- Do not print evidence content.
- If payload hash, hostname, task path, or operator SID differs — refuse.

## Acceptance evidence to capture

Host-specific record under `tests/verification/` with: merged/reviewed SHA,
payload hashes, task/payload ACLs, runtime-record preservation proof across
recovery, seal+disable-before-unregister proof, -Verify PASS, invoke result
shape, audit fields (no content leak), negatives, concurrency, runner service
unchanged, rollback proof. Refresh-qualification SUCCESS with fresh evidence
also requires Secure Boot enabled and exactly one running runner service;
those host preconditions are reported as-is and never faked.
