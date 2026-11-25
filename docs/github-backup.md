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
| Local drive | `/mnt/secondary-hdd/github-backup` | git mirrors (+ wikis, open-PR refs), bundles, wiki bundles, Git LFS objects, metadata JSON |
| Synology NAS | `edgesynology1:/volume1/homes/ai/github-backup` | bundles, wiki bundles, Git LFS objects, metadata JSON (sent with tar over ssh; the NAS refuses rsync for this account) |
| Dropbox | `~/Dropbox/backups/github` | bundles, wiki bundles, Git LFS objects, metadata JSON (Dropbox keeps version history) |

Metadata per repository (`meta/<owner>/<repo>/`): issues, issue comments,
pull requests, PR review comments, releases, labels, milestones, repo settings.
Mirrors fetch without pruning, so a branch deleted on GitHub stays in the backup.
Metadata files are replaced only after a complete download, so a failed API
call never wipes the last good copy. A repository with no commits gets a
`<repo>.bundle.empty` marker instead of a bundle.
Not covered: Actions logs/artifacts, secrets, project boards, PR review
verdicts (approve / changes requested; review *comments* are kept).

## Failure alerts

A failed nightly run opens (or comments on) the issue "GitHub backup failed on
edge-dev3" in `popcre/ai-devops`. The run also fails if the repository list
drops by more than 10% from the last run (lost access or token scope); to
accept a deliberate drop, run once with `GITHUB_BACKUP_ACCEPT_SHRINK=1`.

## Check and restore

- `ai-github-backup --check` - OK if the last full success is under 36 hours old.
  `last-run.json` in the backup root records the last run's result.
- Restore code: `git clone <root>/bundles/<owner>/<repo>.bundle <repo>`, then
  add a new remote and push all branches and tags. For a Git LFS repository,
  copy `<root>/lfs/<owner>/<repo>/objects` into the clone's `.git/lfs/` and
  run `git lfs checkout`.
- Issues and PRs are JSON for reading or re-import; they are not re-created
  automatically.
