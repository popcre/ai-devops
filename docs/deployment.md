# Deployment

For this repo, "deployment" means **installing the toolkit onto a host** — there
is no cloud release, container, or CI/CD. Canonical guide:
[`../AGENTS.md`](../AGENTS.md). First-time / disaster restore:
[`restore-from-zero.md`](restore-from-zero.md).

## What "deploy" means here

- **No** GitHub Actions / CI/CD (`.github/workflows` does not exist).
- **No** container image, registry, or tag pattern — nothing is built or
  published.
- **No** hosting platform, Coolify/Supabase app, or project ID.
- The toolkit is git-cloned to `/worksp/ai-devops` and installed locally with
  `install.sh`. Access to the host is via ordinary SSH; there is no deploy
  automation over SSH.

## Install

```bash
cd /worksp/ai-devops
./install.sh
```

`install.sh`:
1. Verifies/installs base deps (`git`, `curl`, `jq`, `ripgrep`, `unzip`,
   `python3`, `pip3`; `node`/`npm` best-effort via apt).
2. Creates `/etc/ai-devops/` and `/var/log/ai-devops/`.
3. Seeds `/etc/ai-devops/models.env` and `server.env` from the examples **only if
   absent** (never overwrites real config).
4. Symlinks every file in `bin/` into `/usr/local/bin/`.
5. Runs `ai-devops doctor`.

Idempotent — safe to re-run.

Skill-only maintenance supports preview and a recoverable legacy migration:

```bash
ai-install-skills --dry-run
ai-install-skills --migrate-obsolete
```

On Windows, `bin/install-ai-devops-windows.ps1 -SkillsDryRun` previews only skill
operations and skips repository, tool, global-file, and login work. Add
`-MigrateObsolete` to preview moving the retired ShareSync skill into quarantine;
a normal run with `-MigrateObsolete` performs that move. Neither installer prunes
other machine-local skills.

## Update

```bash
cd /worksp/ai-devops
./update.sh          # git pull --ff-only, then re-run install.sh
```

`update.sh` never overwrites `/etc/ai-devops/*.env`.

## Rollback

- **Code:** `git -C /worksp/ai-devops checkout <previous-sha>` then
  `./install.sh`.
- **Symlinks only:** `./uninstall.sh` removes the `/usr/local/bin/ai-*` symlinks.
- Config in `/etc/ai-devops/` is preserved by both paths.

## Uninstall

```bash
./uninstall.sh                # remove symlinks only (keeps config + checkout)
./uninstall.sh --purge        # also remove /etc/ai-devops config
./uninstall.sh --remove-repo  # also remove the /worksp/ai-devops checkout
```

`uninstall.sh` never touches Claude/Codex/gh login state.

## Runtime environment variables

Live in `/etc/ai-devops/models.env` and `server.env` on each host — not in the
repo, not in any CI system. See [`configuration.md`](configuration.md).

## Restore on a fresh server

The full disaster-recovery procedure (create server → install git → clone → run
`install.sh` → log in to gh/claude/codex → `ai-devops doctor`) is in
[`restore-from-zero.md`](restore-from-zero.md).
