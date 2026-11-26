# HANDOFF — GitHub off-site backup (edge-dev3)

Status: OPEN. Written 2026-11-26 10:18 AM EST by Claude on edge-dev3.

## 1. Goal
Albert asked (2026-11-25): back up every GitHub repository (u2giants + popcre, 49 repos) somewhere separate so a GitHub catastrophe loses nothing — code, issues, PRs.

## 2. Done (landed and verified)
- Tool [bin/ai-github-backup](https://github.com/popcre/ai-devops/blob/main/bin/ai-github-backup), doc [docs/github-backup.md](https://github.com/popcre/ai-devops/blob/main/docs/github-backup.md), tests [tests/test-ai-github-backup.sh](https://github.com/popcre/ai-devops/blob/main/tests/test-ai-github-backup.sh) (22 passing). PRs merged: https://github.com/popcre/ai-devops/pull/2865, https://github.com/popcre/ai-devops/pull/2904 (LFS fix).
- Copies: edge-dev3 /mnt/secondary-hdd/github-backup; NAS edgesynology1:/volume1/homes/ai/github-backup (tar over ssh — NAS refuses rsync for user 'ai'); Dropbox ~/Dropbox/backups/github.
- Nightly systemd user timer ai-github-backup.timer installed on edge-dev3 (~02:15-02:30 EST), ExecStart is the installed checkout, which is at cb0015bd (contains the LFS fix). OnFailure opens/comments issue "GitHub backup failed on edge-dev3".
- Proof: 2026-11-25 11:44 AM EST run 49/49 ok on all three copies; popcre/ai-devops cloned from the NAS bundle (164 branches). Failure alert proven live: https://github.com/popcre/ai-devops/issues/2903.
- Muse reviewed twice (REVISE both times); all round-1 and round-2 findings fixed except PR review verdicts (rate-limit cost; Muse agreed) and NAS path quoting (Muse agreed non-blocking). Muse has not re-reviewed the round-2 fixes.

## 3. Still open (Albert's list)
1. **Proof run with the LFS fix** — systemd user unit ai-github-backup-proof2 started 10:05 AM EST 2026-11-26. Check: `journalctl --user -u ai-github-backup-proof2 -o cat | grep -E "WARN|FAIL|local copy|NAS|Dropbox"`; then `cat /mnt/secondary-hdd/github-backup/last-run.json` must say status ok, 49 repos, 0 failed; and `du -sh` of lfs/ in all three copies (~2.5 GB for u2giants/licensor-source-data; NAS via ssh edgesynology1). If ok, close #2903 with a signed comment. If it fails, read the WARN line (now includes git-lfs's error).
2. **Tonight's nightly run** (Fri 2026-11-27 ~02:20 AM EST) — confirm `/home/ahazan/repos/ai-devops/bin/ai-github-backup --check` prints OK and #2903 got no new comment.
3. **Blocked — "Private memory seed" required stage failed** during the 10:13 AM EST update.sh on edge-dev3: "FAILED: private hub health rejected the outgoing union". Unrelated to backup; not investigated (scope freeze). Full log ~/ai-update-2026-11-26.log on edge-dev3. Installed checkout reached cb0015bd but authorization is "pending" until a clean update. Next: diagnose the hub-health rejection (see ai-memory-sync / sync-dotfiles skill), then re-run update.sh (needs Albert's sudo password typed in a shared terminal).

## 4. Known gaps (by design)
No Actions logs, secrets, project boards, PR review verdicts. Issues/PRs are JSON, not auto-reimportable. All three copies are driven from edge-dev3.

## 5. Failed attempts
rsync to NAS (permission denied for 'ai'); `git lfs fetch --quiet` (no such option, exit 127 — fixed in #2904); session-backgrounded runs were killed by session restarts — use systemd-run units.

## 6. Where to look
Logs: `journalctl --user -u ai-github-backup.service`. Status: last-run.json, last-success in the backup root.

## 7. Next action
Item 1, then 2, then 3.

## 8. Verify done
last-run.json ok 49/0 with lfs present in all three copies; nightly --check OK; #2903 closed; clean update.sh.

## 9. Retention
Delete this file once items 1–3 are proven done.
