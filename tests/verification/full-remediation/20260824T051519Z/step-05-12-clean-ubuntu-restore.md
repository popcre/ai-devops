# Clean Ubuntu restore and idempotence proof

Date: 2026-08-24 UTC
Candidate: `961dc12e1f21016590821c8adde47d4c599a1d07`

## Scope

The disposable WSL distribution `AiDevOpsVerifyUbuntuFinal` was newly installed
from Ubuntu 24.04 LTS for this proof. It used a newly created normal,
sudo-capable user and a clean clone at `/worksp/ai-devops`; both `HEAD` and
`origin/main` were the candidate above and the checkout was clean.

The two runs intentionally selected `./install.sh --skip-secrets`. This proves
the public installer, protected GitHub inputs, private-memory seed, generated
configuration/manifest, and doctor behavior. It does not claim that a new
1Password service-account token, Claude login, Codex login, OpenCode service, or
provider account was restored.

WSL normally appends Windows executables to `PATH`. The installer was run from a
Linux-only `PATH` so the Ubuntu doctor evaluated the disposable Linux system,
not the host's Windows Store Codex binary.

## First run

- Exit: `0`.
- Every required stage passed: dependencies, independent Node/npm/npx,
  directories, configuration seed and migration, Unix entrypoints, skills,
  protected configuration, Git identity, Claude permissions, private-memory
  seed, managed manifest, and doctor.
- Secrets were a named selected skip. OpenCode GLM and Muse setup were named
  optional skips because no protected token was installed.
- The fresh Claude home had no project memory. The corrected seed cloned and
  validated the canonical private hub, uploaded nothing, and reported
  `fresh-machine seed complete`.
- Doctor reported source
  `961dc12e1f21016590821c8adde47d4c599a1d07`, configuration schema `2`, matching
  installed source and manifest, matching managed hashes, and all required
  checks passed.

## Unchanged second run

- Exit: `0`; every required stage passed again.
- Configuration migration reported `changed=0` at the same source and schema.
- The public checkout and private hub were clean before and after.
- Public `HEAD` and `origin/main` remained the candidate; the private hub
  remained `dc18be38006f11c8663b4cd7bd0a02f80cdc0dbd`.
- Real configuration hashes were unchanged:
  - `models.env`: `57f712342a4a15892d07ab3278dec4f475a3cbf840cc5f99ded6645f5636abd1`
  - `server.env`: `5c971f19570ea086b473c75f4b9106c1e6e9c4dc203574c6c45bb943e1148692`
- The only before/after content difference was the expected
  `config-state.json.applied_at` timestamp. The manifest changed only its hash
  entry for that timestamped state file; all source, config values, symlink,
  skill, and private-memory identities were stable.
- No private-memory lock remained and both user and root cron contained zero
  `ai-memory-sync` entries.

## Result

PASS for the plan's clean disposable Ubuntu and unchanged rerun gates. The
separate clean Windows 11 restore gate remains outstanding.
