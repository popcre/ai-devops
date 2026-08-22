# Step 6 verification - Windows fail-closed source and configuration

- Source gate rejects dirty, wrong-branch, wrong-remote, failed-fetch, ahead,
  and diverged checkout states before machine changes.
- Canonical source must be clean `main` exactly equal to fetched `origin/main`.
- The public restore entry point and documented path are
  `C:\repos\ai-devops\bin\bootstrap-windows-dev.ps1`.
- Token and private-key candidates are written under a restricted temporary
  directory, effective ACLs are read back, and publication is atomic.
- A forced `icacls` failure returns nonzero and leaves the previous private file
  byte-identical.
- Malformed live JSON remains byte-identical; valid changes create a unique,
  hash-verified backup and publish a validated candidate atomically.
- Windows source, private-file, JSON, skill-installer, schedule, and WinGet
  structural suites pass. Disposable-machine first/second-run proof remains a
  Step 16 rollout gate.
