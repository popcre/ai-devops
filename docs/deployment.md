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

Dotfiles sync uses commands-only repair tools for repo-owned Grok, Kimi,
DeepSeek, and GLM launchers. The shared list is `config/machine-tools.tsv`.
Use `bin/ai-machine-tools-doctor` to check it, then the matching narrow installer
in `bin/`. These tools do not change secrets, MCP, SSH, packages, or services.
The generic executable loop in `install.sh` remains the Ubuntu fresh-install
owner and is intentionally unchanged.

## Install

```bash
cd /worksp/ai-devops
./install.sh
```

`install.sh`:
1. Verifies/installs base dependencies (`git`, `curl`, `jq`, `ripgrep`,
   `unzip`, `python3`, `pip3`, and `gh`). It detects, installs, and verifies
   `node`, `npm`, and `npx` independently.
2. Creates `/etc/ai-devops/` and `/var/log/ai-devops/`.
3. Seeds `/etc/ai-devops/models.env` and `server.env` from the examples **only if
   absent**, then runs the versioned merge-based config migrator (never
   overwrites user values).
4. Symlinks executable Unix entrypoints in `bin/` into `/usr/local/bin/`.
   Windows-only `.ps1`/`.bat` files are not chmodded or linked, so an update
   leaves the Git checkout clean.
5. Runs the canonical `ai-install-skills` installer so client-specific and shared
   skills use the same collision-safe behavior on Ubuntu and Windows. The shared
   `ask-glm` skill reaches both Claude and Codex. Secret setup injects
   the Z.ai Coding Plan key from 1Password and proves a real GLM-5.3 OpenCode
   agent call; non-interactive updates reuse the existing protected bootstrap
   file automatically and never change normal Claude/Codex authentication.
6. Runs `ai-devops doctor`.
7. Records exact source, config schema, owned symlinks, config files, managed
   skill markers, and hashes in `/etc/ai-devops/install-manifest.tsv`.

Every operation is an explicit required, optional, or skipped stage. The final
summary names every result, and any required failure makes the installer
nonzero after preserving the successful earlier stages. Secrets are required
when an interactive/token-backed install selects them; `--require-secrets`
forces that mode and `--skip-secrets` records an intentional skip.

Idempotent — safe to re-run.

Skill-only maintenance supports preview and a recoverable legacy migration:

```bash
ai-install-skills --dry-run
ai-install-skills --keep-orphans
ai-install-skills --adopt-globals
```

On Windows, `bin/install-ai-devops-windows.ps1 -SkillsDryRun` previews skill and
global operations and skips repository, tool, and login work. Both installers
retire skills automatically: any skill they previously installed (marked with a
`.ai-devops-managed` file) that the repo no longer ships is moved into
`<client>/skills-quarantine/`. Skills ai-devops did not install — vendor skills
shipped with the client, or hand-authored local ones — carry no marker and are
never touched. Pass `--keep-orphans` (Bash) to opt out.

### Preview-first reconciliation

Every install classifies each skill before touching it and prints one line per
skill. The same lines appear in a dry run and in a real run, so the preview is
the plan:

| Line | State | What happens |
|---|---|---|
| `+ name` | absent | installed |
| `= name` | identical | nothing is written |
| `~ name` | update | only the changed files are copied |
| `! name … LOCAL EDITS` | an installed file was edited by hand | copied to `<client>/skills-backup/<name>`, then updated |
| `! name … never installed it` | a directory we do not own is in the way | copied to `<client>/skills-backup/<name>`, then adopted |
| `- name retired` | the repo no longer ships it | moved to `<client>/skills-quarantine/<name>` |

Two rules make this safe. **Files inside a managed skill that the repo does not
ship are never deleted**, so a local extension survives every update; only files
the installer itself wrote and the repo has since dropped are removed. And
**anything replaced that held local edits is copied somewhere recoverable
first** — nothing is ever deleted outright.

The `.ai-devops-managed` marker records a SHA-256 for every file the installer
wrote. That record is what tells a hand edit apart from an ordinary source
update. Markers written before this existed carry no hashes; a skill under one
that differs is treated as locally edited, so the first run after upgrading may
report edits that are really just old installs. That is deliberate — it backs
the copy up rather than assuming.

**Globals are never replaced without being asked.** `~/.claude/CLAUDE.md` and
`~/.codex/AGENTS.md` carry per-machine sections, so a differing global is
reported and left alone. `--adopt-globals` (Bash) or `-AdoptGlobals`
(PowerShell) is the explicit managed boundary: it copies the installed file to
`<client>/globals-backup/` and prints the one-line restore command before
replacing it.

Both installers implement the same engine, and `tests/test-installer-parity.sh`
proves it: same file set, byte-identical markers, and a refresh with one after
an install by the other reports "up to date" rather than inventing local edits.

## Update

```bash
cd /worksp/ai-devops
./update.sh          # git pull --ff-only, re-run install.sh, report installed SHA
```

`update.sh` never overwrites `/etc/ai-devops/*.env`. It returns nonzero if the
installer has any required failure and reports the exact source SHA attempted.

## Rollback

- **Code:** `git -C /worksp/ai-devops checkout <previous-sha>` then
  `./install.sh`.
- **Symlinks only:** `./uninstall.sh` removes the `/usr/local/bin/ai-*` symlinks.
- Config in `/etc/ai-devops/` is preserved by both paths.

## Uninstall

```bash
./uninstall.sh --dry-run      # exact read-only ownership/removal preview
./uninstall.sh                # minimal: owned symlinks only
./uninstall.sh --purge        # minimal + archive/remove config
./uninstall.sh --full         # archive/remove config and clean checkout
```

`uninstall.sh` removes only manifest-owned symlinks whose target and hash still
match. Destructive modes first create and verify a protected config archive and
Git bundle, refuse broad paths or a dirty checkout, and never touch
Claude/Codex/gh login state.

## Runtime environment variables

Live in `/etc/ai-devops/models.env` and `server.env` on each host — not in the
repo, not in any CI system. See [`configuration.md`](configuration.md).

## Restore on a fresh server

The full disaster-recovery procedure (create server → install git → clone → run
`install.sh` → log in to gh/claude/codex → `ai-devops doctor`) is in
[`restore-from-zero.md`](restore-from-zero.md).
