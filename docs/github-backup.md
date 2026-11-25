---
summary: Nightly off-GitHub backup of every u2giants and popcre repository (code, wiki, issues, PRs) to edge-dev3's drive, the Synology NAS and Dropbox, and how to restore.
kind: ops
status: current
read-when: Restoring a repository after a GitHub outage, or checking or changing the GitHub backup
---

# GitHub backup

`bin/ai-github-backup` runs nightly at 02:15 local on edge-dev3 (systemd user
timer `ai-github-backup.timer`, installed by `install.sh`; other hosts SKIP).
It backs up every repository the `u2giants` login can reach, which includes
the `popcre` organization.

## What is kept, and where

| Copy | Location | Contents |
|---|---|---|
| Local drive | `/mnt/secondary-hdd/github-backup` | git mirrors (+ wikis), bundles, metadata JSON |
| Synology NAS | `edgesynology1:/volume1/homes/ai/github-backup` | same as local |
| Dropbox | `~/Dropbox/backups/github` | bundles + metadata JSON (Dropbox keeps version history) |

Metadata per repository (`meta/<owner>/<repo>/`): issues, issue comments,
pull requests, PR review comments, releases, labels, milestones, repo settings.
Mirrors fetch without pruning, so a branch deleted on GitHub stays in the backup.
Not covered: Actions logs/artifacts, secrets, project boards, Git LFS objects.

## Check and restore

- `ai-github-backup --check` - OK if the last full success is under 36 hours old.
  `last-run.json` in the backup root records the last run's result.
- Restore code: `git clone <root>/bundles/<owner>/<repo>.bundle <repo>`, then
  add a new remote and push all branches and tags.
- Issues and PRs are JSON for reading or re-import; they are not re-created
  automatically.
