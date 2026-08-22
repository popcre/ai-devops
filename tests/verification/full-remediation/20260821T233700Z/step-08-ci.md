# Step 8 verification - aggregate test and CI source

- `tests/test-all.sh` discovers every offline Bash `test-*.sh` deterministically.
- `tests/test-all.ps1` runs that same Bash suite through Git Bash, then every
  offline PowerShell `test-*.ps1` deterministically.
- Live or paid qualifications remain under `tests/probes/` and are excluded.
- Linux and Windows GitHub jobs use concurrency cancellation, read-only
  permissions, pinned checkout action SHA, syntax checks, and the aggregate
  suites. Neither job deploys or mutates a machine.
- Public-boundary negative controls prove seeded transcript and credential
  violations fail. Markdown-link negative control proves a missing target fails.
- The first aggregate local run found two stale integration assumptions; the
  focused installer-parity and Windows path groups pass after correction.
- A green GitHub run remains required. The no-force/no-delete ruleset is
  intentionally deferred until immediately after the coordinated Step 15 rewrite.
