# Implementation plan — AI sessions clean up their own temporary files (Linux, edge-dev3 first)

Related handoff: [HANDOFF.d/2026-10-07T2230Z-edge-dev3-claude-session-temp-cleanup.md](HANDOFF.d/2026-10-07T2230Z-edge-dev3-claude-session-temp-cleanup.md). Do not rewrite root `HANDOFF.md`.
Companion (already done, Windows review sandboxes only): [plan_agent-self-cleanup.md](plan_agent-self-cleanup.md).

## STATUS

| Step | Status | Evidence |
|------|--------|----------|
| 1. Move `/tmp` off RAM onto the SSD | ✅ 2026-10-07 | `/etc/fstab` tmpfs line commented (backup `/etc/fstab.bak-20261007`); `systemctl mask tmp.mount` (Ubuntu ships `tmp.mount` in `local-fs.target.wants`); after reboot `findmnt /tmp` prints nothing, memory used 12 G |
| 2. One session-owned temp root, exported to every engine | ✅ code | base is per-user `/var/tmp/ai-sessions-<uid>` (0700), not shared `/var/tmp/ai-sessions`: a user-owned world-writable parent fails the repo's private-directory checks (`sealed.py`) and lets other accounts rename roots; `tools/lib/session-tmp.sh`, `tests/test-session-tmp.sh` |
| 3. Session wrappers delete their own temp root on exit | ✅ code | 18 `bin/ai-*` wrappers + test runners via `ai_session_tmp_wrap` (detached watcher deletes the root when the wrapper PID exits, incl. kill -9; a wrapper whose caller already set TMPDIR reuses it, so failure evidence a wrapper retains there survives; a re-exec design was rejected because reviewer event records key on the wrapper PID); Claude Code via SessionStart/SessionEnd hook (`bin/ai-session-tmp-hook`, `bin/ai-install-session-tmp`). Interactive Codex sessions not covered (no session hook) |
| 4. Fix the named offenders (issue-prefixed `/tmp/<issue>-*` dirs, bare `mktemp`) | ✅ code | issue-prefixed names were hand-typed by agents: global templates now say use `$TMPDIR`; bare `mktemp` now lands in the session root; 13 legacy files baselined in `config/temp-hygiene-baseline.txt` |
| 5. Orphan sweep as backup only | ✅ code | `bin/ai-session-tmp-sweep` + user timer, `tests/test-ai-session-tmp-sweep.sh` |
| 6. Guard against regression (lint + test) | ✅ code | `tools/ci/check-temp-hygiene.sh`, `tests/test-temp-hygiene.sh` |
| 7. Clear the current pile safely | ✅ 2026-10-07 | 26,839 stale entries removed, 6 GB freed; recent/busy entries kept |
| 8. Live proof on edge-dev3 | 🟡 partial 2026-10-08 | #1472 merged (b6adb3cb), installed 3:03 AM EDT; wrapper run left 0 roots; kill -9'd wrapper root removed in 2 s; timer active. Left: a fresh interactive Claude session's root appears and is removed at session end (issue #1471) |

**Where a fresh session starts:** step 8 (live proof) after the PR merges and the installer runs. Read every section first. Re-read Part 3 before each phase (drift check).

---

## Part 1 — Why

### 1. Ultimate goal

Albert's Linux machine (edge-dev3) must never again lose half its memory to leftover AI temporary files. Every AI session (Claude Code, Codex, reviewers, MiMo, GLM, DeepSeek, StepFun, Qwen, Gemini, Grok, Muse, Kimi) puts its temporary files in **one folder it owns**, and **the session that made the folder deletes it when it ends**. A timed sweeper exists only as a crash backup. It must be automatic; Albert is not a programmer and will not run anything.

**If a step conflicts with this goal, the goal wins — stop and flag it.**

### 2. What this application is

`popcre/ai-devops` (https://github.com/popcre/ai-devops) is Albert Hazan's AI workflow toolkit: reviewer/agent wrappers in `bin/ai-*`, shared helpers in `lib/`, tools in `tools/`, policy in `config/`, installers that put skills and global instructions on each machine (`skills/shared/`, `templates/system/*-global*.md`). Repository contract and router: `AGENTS.md`. Machine facts: `templates/system/machine-atlas.md`.

Target machine for this plan: **edge-dev3**, Ubuntu (kernel 7.0), 24 cores, 62 GiB RAM, 16 GiB swap. Disks: `nvme0n1p2` 1.8 TB SSD mounted at `/` (1.6 TB free on 2026-10-07); `sda` 3.6 TB HDD (`sda5`), **not mounted**.

### 3. What triggered this work

2026-10-07, while investigating GitHub Actions minutes, Albert showed System Monitor: memory 52.0/62.1 GiB used, swap 16.5/16.5 GiB full, CPU 9.9%. Investigation found:

- `/etc/fstab` line `tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0` — `/tmp` lives in RAM (32 GiB cap). `df` showed it **100% full (32 G)**. `free` showed 25 G "shared" = that tmpfs.
- `/tmp` held **22,637 entries**, all dated 2026-10-06/07. Biggest: `/tmp/658-*` (356 dirs, 14.8 G), `/tmp/3536-*` (675 dirs, 8.4 G; one, `3536-redaction-private-checkout-20261007`, is 8.0 G), bare `mktemp` `tmp.*` (11,444 entries, 1.2 G), plus thousands of small `check-sql*`, `audit*`, `governed-review*`, `ai-muse*`, `queue-stage*`, `promotion-source*`, `oxlint-*` entries.
- Ubuntu's own cleaner (`/usr/lib/tmpfiles.d/tmp.conf`: `q /tmp 1777 root root 10d`) only removes files older than 10 days, so it never touches a pile built in two days.

Owner words (Albert, chat, 2026-10-07): "there's no clean-up process? Why not?" and "write a plan to make AI sessions clean up after themselves". He also asked whether temp can live on the secondary HDD (answer in §8).

### 4. Scope

In: edge-dev3 `/tmp` placement; a session-owned temp root for every engine launched through ai-devops wrappers or Claude Code on Linux; exit cleanup; backup sweep; regression guard; clearing today's pile.

NOT in this plan:
- Windows review sandboxes (done by `plan_agent-self-cleanup.md`; extension in issue #1018).
- Git worktree cleanup (skill `cleanup-worktree`).
- Orphan review sandbox reconciliation (issue #1420, owner MiMo, `HANDOFF.d/2026-10-07T1908Z-edge-dev-mimo-orphan-sandbox-cleanup.md`) — do not touch its paths.
- Using edge-dev3 as a CI runner (separate follow-up once memory is freed).
- Other Linux hosts (hetz etc.) — roll out after edge-dev3 is proven, as a follow-up child.

---

## Part 2 — What we already know

### 5. Current state

- Nothing for general `/tmp` exists. Claude Code already gives each session a scratchpad (`/tmp/claude-<uid>/<project>/<session>/scratchpad`) — but it is under the RAM `/tmp` and is not removed at session end; `/tmp/claude-1000` was 528 M.
- 51 files under `bin/ tools/ lib/` call `mktemp` (grep `mktemp`); most use bare `mktemp -d` → `/tmp/tmp.XXXXXXXXXX`, honoring `$TMPDIR` if set.
- Windows already has the review-sandbox self-delete (`bin/ai-review-sandbox with-copy`, `sweep-orphans`) and a daily `AI-Debris-Housekeeping` task. No Linux equivalent for general temp.
- Nothing from this plan is committed except this file.

### 6. Key findings / root cause

1. RAM-backed `/tmp` turns disk litter into memory pressure; with swap full the whole desktop slows.
2. Sessions write to shared `/tmp` with hand-made names (`/tmp/<issue>-<topic>`), so nothing knows who owns what and nothing deletes it.
3. Bare `mktemp` in scripts without an EXIT trap leaks one dir per run; test suites run hundreds of times a day.
4. The OS cleaner's 10-day age floor is far too slow for this rate (~11 GB/day).

### 7. Rejected approaches

- **Just enlarge tmpfs / add swap** — symptom suppression; the pile keeps growing.
- **Shorten the OS cleaner to hours** — would delete files of live sessions (some run for many hours); age is not ownership proof (same rule as `cleanup-worktree`).
- **Put `/tmp` on the HDD** — works (needs mounting `sda5` first) but HDD is far slower; tests and builds that use temp would slow down noticeably, and an unmounted/failed HDD at boot would break login. Rejected as default; SSD has 1.6 TB free.
- **Telling sessions in instructions to "clean up"** — already the rule; sessions ignore it. Enforcement must be in wrappers, not prose.
- **Deleting everything in `/tmp` now** — other live sessions own some of it (a live `bash` was in `/tmp` during investigation).

### 8. Decisions

Locked (2026-10-07, this planning session, on Albert's goal):
- `/tmp` moves to the SSD (plain directory on `/`), not RAM, not HDD.
- Ownership = one temp root per session: `/var/tmp/ai-sessions/<engine>-<session-id>/`, exported as `TMPDIR`, `TMP`, `TEMP` to the session and all children. (`/var/tmp` is on SSD and survives reboot so crash orphans can be swept with evidence.)
- The creator deletes; the sweeper is backup only, and deletes only roots whose owner PID is dead **and** older than 2 h.

Open (implementer judgment): exact helper name; whether Claude Code's own scratchpad can be redirected (check `CLAUDE_CODE_TMPDIR` or equivalent in Claude Code docs via context7 — if unsupported, include `/tmp/claude-<uid>` in the sweeper with the dead-PID rule using its session id).

---

## Part 3 — How to build it

### 9. Steps

**Phase A (machine, edge-dev3)**

1. **Move `/tmp` to SSD.** Remove the tmpfs line from `/etc/fstab` (back up to `/etc/fstab.bak-20261007` first) AND `sudo systemctl mask tmp.mount` — Ubuntu ships `tmp.mount` enabled via `local-fs.target.wants`, so the fstab edit alone is not enough. Takes effect at next reboot; schedule the reboot when no session is live (check `find-live-sessions-by-transcript-mtime` memory). Record in `templates/system/machine-atlas.md` (edge-dev3 row).
   Done when: after reboot `findmnt /tmp` prints nothing (plain dir on `/`) and `free -g` "shared" < 3 G.

**Phase B (repo code)** — cut point: fresh session OK here.

2. **Session temp root helper.** Add `lib/session-tmp.sh` with `ai_session_tmp_begin <engine> <session-id>`: creates `/var/tmp/ai-sessions/<engine>-<id>/` (mode 700), writes `owner.json` (pid, engine, session id, start time UTC, cwd), exports `TMPDIR/TMP/TEMP`. And `ai_session_tmp_end`: path-guarded `rm -rf` of that root only (refuse anything not matching `^/var/tmp/ai-sessions/[a-z0-9-]+$`, refuse symlinks — reuse the guard pattern in `bin/ai-review-sandbox`).
   Done when: `tests/test-session-tmp.sh` passes (cases in §10).
3. **Wire every Linux launcher.** Call begin at start and end in an `EXIT INT TERM` trap in each `bin/ai-*` session entry point (list via `grep -l "lib/ai-review-lifecycle\|exec .*opencode\|exec .*codex" bin/ai-*`), and in the Claude Code / Codex shell profile wrapper installed by the dotfiles installer. Honor `AI_KEEP_SANDBOX=1` (keep root, print path).
   Done when: running any wrapper with a trivial task leaves no new entry in `/tmp` and no root in `/var/tmp/ai-sessions`.
4. **Fix named offenders.** Find what writes `/tmp/<number>-*` (grep `"/tmp/\$\|/tmp/[0-9]"` in `bin tools lib skills templates`; also global instruction templates that tell agents to use `/tmp/<issue>-...`) and switch to `$TMPDIR`. Add `trap 'rm -rf "$d"' EXIT` to each bare `mktemp -d` in the 51 files that lacks one; shared-db's `check-sql` suites belong to `popcre/shared-db` — open a child issue there instead of editing.
   Done when: `grep -rn "mktemp" bin tools lib | <lint from step 6>` reports zero unguarded uses.
5. **Backup sweeper.** `bin/ai-session-tmp-sweep`: for each root in `/var/tmp/ai-sessions`, delete only if `owner.json` pid is dead AND start > 2 h ago; also `/tmp/claude-<uid>/*/<session>` whose session root's `owner.json` names a dead owner process AND whose transcript has not changed for 2 h (inactivity alone never deletes; the SessionEnd hook removes the scratch folder of a session that ends normally). Max 50 deletions per run; log to `~/.local/state/ai-devops/logs/session-tmp-sweep.log`. Install as a systemd user timer every 30 min via the installer.
   Done when: timer listed by `systemctl --user list-timers`, and test cases pass.
6. **Regression guard.** Add a check to the repo's offline lint (`tools/ci/` existing lint lane) failing on new `/tmp/` literals or `mktemp` without trap in `bin/ lib/ tools/`.
   Done when: a deliberately bad fixture fails the lint test.

**Phase C (cleanup + proof)** — cut point.

7. **Clear today's pile.** For each top-level `/tmp` entry: skip if any live process has it as cwd or open file (`lsof +D` bounded, or `/proc/*/cwd`), skip if modified < 2 h ago; otherwise delete. Record count and GB freed in the issue. (Moot if reboot in step 1 already happened — a disk `/tmp` starts empty after reboot of tmpfs.)
8. **Live proof.** Run one real review and one Claude Code session; show before/after `du -sh /tmp /var/tmp/ai-sessions` unchanged after they exit; kill one wrapper with `kill -9` and show the sweeper removes its root after 2 h.

### 10. Tests required

`tests/test-session-tmp.sh`: creates root with owner.json; exports TMPDIR/TMP/TEMP; end deletes on normal exit, on error exit, on SIGINT, SIGTERM; `AI_KEEP_SANDBOX=1` keeps; guard refuses `/`, `/var/tmp`, a symlink root, path with `..`.
`tests/test-session-tmp-sweep.sh`: dead-PID + old → deleted; live PID → kept; dead but < 2 h → kept; missing owner.json → kept and reported; cap of 50 honoured.
Lint test with a bad fixture. Existing suites that must stay green: the full offline suite in `config/ci-suite-manifest.json` (run as CI's `verify` does).

Adversarial cases (deletion is a trust boundary):

| Input | Hostile case | Test |
|---|---|---|
| root path | `/`, empty, `..`, symlink to `$HOME` | test-session-tmp.sh guard cases |
| owner.json | missing / malformed / PID reused by unrelated process | sweep test (missing → keep; PID reuse: compare process start time to owner start) |
| TMPDIR inherited | nested wrapper calls begin twice | test: inner session gets own root, outer root survives inner end |

### 11. Constraints and gotchas

- Never delete another session's files; age alone is not ownership proof.
- Never push to `main`; branch + PR + merge queue; Albert does not merge — the implementer does. Sign GitHub posts `Posted by <engine> chat <id> on <machine>`.
- Times in EST/EDT for humans.
- `/etc/fstab` change needs sudo on edge-dev3; a wrong fstab can block boot — keep the backup and validate with `sudo findmnt --verify` before reboot.
- Do not touch issue #1420's sandbox paths.
- Long reviewer sessions (hours) are normal; never shorten the 2 h dead-PID floor without evidence.

### 12. Access and environment

edge-dev3 local shell (user `ahazan`, sudo available). GitHub CLI authenticated as `u2giants` for `popcre/ai-devops`. No secrets needed. Work in a fresh worktree from `origin/main` (never the canonical checkout).

---

## Part 4 — Landing

### 13. Definition of done, risks, open questions

Done: steps 1–8 ticked with evidence (commit SHA / CI run / command output path); PR(s) merged with green CI; edge-dev3 shows `/tmp` on disk, no growth after sessions; sweeper timer active; machine-atlas updated; this STATUS table and the handoff updated; live-proof checklist item ticked on the parent issue.
Risks: fstab error → boot problems (backup + verify); a wrapper missing the trap → still leaks (lint + sweeper catch it); sweeper bug deletes live work (guard + tests; dry-run mode `--dry-run` first run).
Open: whether Claude Code supports redirecting its scratchpad (decide by its docs); rollout to other Linux hosts (follow-up child after proof).

### Self-audit (2026-10-07)

1. Fresh session could execute without asking? Yes — machine facts §2, evidence §3, files and gates §9, tests §10; the only judgment calls are labeled open in §8.
2. Carries all background incl. rejected? Yes — §6 root causes, §7 five rejected options including HDD and shorter OS cleaner.
3. Goal clear enough for judgment calls? Yes — §1 states owner-deletes, sweeper-as-backup, automatic, with goal-wins rule.
