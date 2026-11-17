---
issue: 2558
status: OPEN
owner: zcode/sess_c241d794
---

# edge-dev/edge-dev3 audit 2026-11-16 — guard fix landed; two machine follow-ups remain

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

- **Blocking: none.** Both remaining items are technical and are done by AI sessions without Albert.
- **Recoverable-rework tier:**
  - **Reap the stale work-trees that slow the daily inventory** — the ai-devops checkout on edge-dev carries 133 linked work-trees and edge-dev3 carries 155 (old `ai-devops-wt-*`, `-rev-*`, `-cand-*` dirs from finished sessions). Deleting them would cut the ~15-minute inventory run substantially and free disk. Small risk: a work-tree another session still uses could be removed. **Recommendation: yes, as its own issue with the governed reap procedure (per-worktree check first).** It blocks nothing. (Recorded in https://github.com/popcre/ai-devops/issues/2535 — not started.)
- **Not part of this work and nobody is on it:** none beyond the above.
- **Already settled — do NOT re-ask:**
  - 2026-11-16, Albert: "Guard misfire (#2535): fix it on both machines" — DONE (PR #2555 merged, deployed, proven).
  - Standing: reviews are advisory; never push to `main`; the main guard must never be bypassed.

**Next session: put this list to the owner in ONE message before starting work.**

## 1. What this application is

`popcre/ai-devops` is the private AI-operations toolkit repo (guards, installers, launchers, reviewers) installed on POP Creations' dev machines. Two hosts matter here: **edge-dev** (Windows, installed checkout `C:/repos/ai-devops`, launchers in `~/.local/bin`, updated by `bin/install-ai-devops-windows.ps1`) and **edge-dev3** (Ubuntu, installed checkout `/home/ahazan/repos/ai-devops`, symlinks in `/usr/local/bin`, updated by `update.sh`). `hooks/reference-transaction` is the "installed-checkout main guard" (#1836): an accident guardrail that refuses unauthorized moves of `main` on installed checkouts, on both OSes.

## 2. What we set out to do this session, and why

Albert asked for an audit of edge-dev using popcre/ai-devops rules (PR #2523 context), investigating four findings: stale launcher release stamps; the guard refusing pack-refs maintenance after fetch; five-minute GitHub requests / a 134-work-tree housekeeping scan; an SSH post-quantum warning with a tool-update check. Then: "fix it on both machines" for the guard misfire.

## 3. Current state — what is true right now

**All landed and verified (evidence: https://github.com/popcre/ai-devops/issues/2535#issuecomment-6933927625):**
- Guard fix merged as https://github.com/popcre/ai-devops/pull/2555 (merge commit `aaa50f705a4079939888c8ea7551ba65f5a8199d`): `hooks/reference-transaction` now allows exactly the two value-preserving pack-refs transaction shapes (`pack_noop`); every real move of `main` still refuses. Tests in https://github.com/popcre/ai-devops/blob/main/tests/test-ai-review-preflight.sh (two new checks: "pack-refs passes the main guard; a later plain pull still refuses", "the guard allows only value-preserving pack transactions on main"); suite 259/0; docs updated in https://github.com/popcre/ai-devops/blob/main/docs/deployment.md ("Installed checkout main guard" paragraph).
- edge-dev: full installer run twice (final at release `aaa50f705a4079939888c8ea7551ba65f5a8199d`); launchers re-stamped (stamp == HEAD, which is the health check — the `source-sha=` stamp is the release COMMIT SHA, not a blob hash); `maintenance.auto=false` mitigation applied then REMOVED after the fix; `git fetch` + `git pack-refs --all` both exit 0 on the installed checkout; a real move (`update-ref refs/heads/main HEAD~1`) refuses with exit 128.
- edge-dev3: checkout advanced to `aaa50f705a4079939888c8ea7551ba65f5a8199d`; guard hook refreshed user-level via `bash bin/ai-install-post-merge-hook --repo .`; proven there on git 2.53: pack-refs exit 0, move refused exit 128.
- Tools: gh 2.104.0 and Python 3.13.17 updated on edge-dev via winget; jq 1.8.2 / PowerShell 5.1+7.6.9 current; SSH post-quantum verified end-to-end (Git's OpenSSH 10.3 ↔ GitHub negotiates `mlkem768x25519-sha256` on both machines; only Microsoft's Windows OpenSSH 9.5p2 lacks it — no supported update exists; not used by git/gh).
- GitHub slowness root-caused and measured (no fix owed): the machine-wide `ai-gh` shared throttle + hourly budget pauses (below ~1000/5000 remaining → pause until window reset). Measured: single `ai-gh` call 5m36s under contention; full housekeeping run on the ai-devops repo 15m01s wall (34.8s user + 1m57s sys — the rest is throttle waiting).

**Unfinished (this file exists for these):**
1. **edge-dev3 privileged update stage** — a non-interactive `bash update.sh` (2026-11-16 ~2:50 PM EST) advanced the checkout but stopped before installing: `sudo: A terminal is required to authenticate` → "[WARN] protected config backup failed; installation did not start" and "authorization remains pending" (its own words in the run tail; also quoted in https://github.com/popcre/ai-devops/issues/2535#issuecomment-6933927625). The transient run log on edge-dev3 was `/tmp/update2535.log` (may be gone; the GitHub comment preserves the tail). A ready-to-paste prompt for an on-machine session was handed to Albert on 2026-11-16.
2. **edge-dev Git 2.56 retry** — `winget upgrade --id Git.Git --silent` fails exit 2 ("You cancelled the installation") while any Git Bash window is open. Retry from PowerShell with zero Git Bash/terminal windows open. Cosmetic only.

## 4. Everything we tried that did NOT work

- **Debug observer hook, first version:** grepping `packed-refs` with the pattern `" $ref\$"` inside double quotes produced mangled/unreliable log lines (the `\$` anchor misbehaved). Fixed by suffix-matching with a `case` statement per line. Lesson: parse `packed-refs` with `case "$line" in *" $ref")` in POSIX sh, not grep anchors.
- **Synthetic delete test, first version:** assumed a same-value `git update-ref refs/heads/main <sha>` would (re)create the loose ref — it is a no-op that writes nothing, so the delete-shape case had no loose file and failed. Fixed by building the both-places state via two installer-route (`-c core.hooksPath=<empty>`) update-refs through a different value and back.
- **`bash bin/ai-gh-signature`** fails (it is a Python script with a bash-invoked path); run `python bin/ai-gh-signature`.
- **`ai-task-gates check --before installation`** → "unknown action: installation" — that repo's gate config has no such action; classes (not actions) carry installation. Declare `ai-task-gates start --class installation`.
- **winget Git.Git --silent while terminals open** → exit 2 "You cancelled" (Inno installer cannot close apps silently). Not retried — deferred as follow-up 2.
- **Non-interactive update.sh on edge-dev3** → sudo needs a tty. Not worked around (never bypass).
- **PPID inside hooks on Git Bash is 1** for every invocation — same-process pairing between the pack create/delete transactions would be unreliable on Windows; that is why the fix keys on ref VALUE + packed-refs content instead.

## 5. Root causes and key findings

- **Launcher stamps:** `~/.local/bin/ai-*` headers carry `source-sha=<40-hex>` = the installed release COMMIT SHA (all launchers share one value). Health check: stamp == `git -C <install> rev-parse HEAD`. They went stale because a session fast-forwarded the checkout (2026-11-16 12:54 PM EST) without the full installer; the Windows installer is the only launcher writer.
- **pack-refs mechanics (git 2.53/2.55):** packing a loose ref issues `0000→sha` (while the ref still resolves to `sha`, loose present, packed absent) then `sha→0000` (loose present, `packed-refs` already contains `<sha> refs/heads/main`). Manual deletes encode as `0000→0000` (skipped by the guard's same-value rule — never covered, before and after the fix; residual documented in PR #2555). A real move `0→<different sha>` never matches the current value → refused.
- **ai-gh throttle:** FIFO lock + 3s spacing + 300s call bound; budget pause below 20% of the 5000/hr quota until window reset; abandoned locks (90s) get reclaimed. All GitHub calls must go through it.
- **Ubuntu installed-checkout update route:** `update.sh` needs interactive sudo for its protected-config stages; the guard hook alone can be refreshed user-level with `bin/ai-install-post-merge-hook --repo .` (done).

## 6. Exact next steps

1. **edge-dev3 (a session running ON that machine):** from `/home/ahazan/repos/ai-devops`, `ai-task-gates start --class installation`, then re-run `bash update.sh` in a shell where sudo can authenticate. Verify: update.sh exit 0 with NO "authorization remains pending"; `bin/ai-machine-tools-doctor` reports launchers current; `grep -c pack_noop .git/hooks/reference-transaction` ≥ 1; scratch-repo proof (pack-refs exit 0 + move-refuse exit 128). You'll know it worked when update.sh's own tail shows a completed install and the four checks pass. If sudo cannot authenticate: report `Blocked —` with the exact error; do not bypass.
2. **edge-dev (any session, quiet moment):** close every Git Bash/terminal window, then from PowerShell: `winget upgrade --id Git.Git --silent --accept-source-agreements --accept-package-agreements`; verify `git --version` ≥ 2.56 in a NEW shell and that a fresh `git status` works. You'll know it worked when the version reports 2.56.x and existing repos still open cleanly.
3. When both are verified, comment the proofs on https://github.com/popcre/ai-devops/issues/2558, close it, and DELETE this handoff file in the same change (successor rule).

## 7. Constraints and gotchas in force

- Never push to `main` in popcre/ai-devops: branch + PR, plain `gh pr merge` (never `--admin`/`--squash`); route GitHub calls through `bin/ai-gh`; reviews are advisory only.
- Never bypass the installed-checkout main guard (`-c core.hooksPath=<empty>` is the INSTALLERS' route only). Installations/updates go only through `bin/install-ai-devops-windows.ps1` (Windows) / `update.sh` (Ubuntu).
- Every edited checkout gets its own git worktree; `ai-pr-wait` needs `--repo popcre/ai-devops` from worktrees.
- Quote times in EST. Windows Git Bash: author scripts with a file editor, not heredocs; `git show origin/main:path` needs `MSYS_NO_PATHCONV=1`.
- Self-test gotcha: the word "missing" in new comments in shared-db scripts/workflows fails that repo's Tools offline tests (not this repo).

## 8. Access and environment

- edge-dev3 reachable as `ssh edge-dev3` (BatchMode works; sudo does NOT work without a tty). gh authenticated on both machines (throttled through ai-gh). No secrets were read this session; when needed they live in 1Password vault `vibe_coding` (never in chat/logs).
- Installed releases: both checkouts at `aaa50f705a4079939888c8ea7551ba65f5a8199d` (main). Machines: edge-dev (Windows 11, git 2.55.0.3, gh 2.104.0), edge-dev3 (Ubuntu, git 2.53.0, gh 2.104.0).

## 9. Open questions and risks

- edge-dev3's update.sh is left in "authorization remains pending" state by design of its own failure handling — resolve ONLY through a successful update.sh run, never by hand-editing its state.
- A review-finding issue (#2556) was auto-opened against PR #2555 by the advisory review flow; the automatic review-fixer owns it — do not hand-fix during wrap-up (2026-11-16).
- Residual, accepted and documented in PR #2555: on current git, manual `update-ref -d refs/heads/main` encodes as `0→0` and was never guarded (unchanged behavior).
- The work-tree reap (§0) is the only measured lever left for housekeeping runtime; the GitHub-throttle pauses are quota protection working as designed.
