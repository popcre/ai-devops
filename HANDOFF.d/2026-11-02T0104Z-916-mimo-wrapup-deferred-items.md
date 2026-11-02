---
issue: none
status: OPEN
owner: mimo/916-wrapup-deferred
---

<!--
issue: none — deferred items from a completed wrap-up; the scope freeze forbade
opening a tracker during close-out, so these carry no issue of their own.
status: OPEN until every step in §6 is done and proven.
-->

# Wrap-up deferred items — 2026-11-01 session (reaper fix, install finish, root-landing fix)

## 0. Business decisions only the owner can make

None — nothing in this workstream needs the owner. All three deferred items in §6
are technical: docs accuracy, machine housekeeping, and routine fleet pickup.

Already settled — do NOT re-ask:
- 2026-10-15 / 2026-10-29 (night): AI reviews are never required to merge,
  deploy, install, or touch shared-db/production/infrastructure
  (https://github.com/popcre/ai-devops/blob/main/docs/owner-rulings.md).
- 2026-10-30: only checks that stop production-data damage or secret leaks may
  block a merge; everything else is advisory.
- 2026-10-23: Albert never reviews or merges pull requests; the AI merges.

## 1. What this application is

`popcre/ai-devops` (https://github.com/popcre/ai-devops) is Albert Hazan's public
AI-workflow toolkit: installer, scheduled maintenance tools (worktree reaper,
watchdogs), reviewer/provider wrappers, and task gates. It is not an app or
service; its "deployment" is the per-machine install (Linux: `update.sh` /
`install.sh`; Windows: `bin/install-ai-devops-windows.ps1`). Key hosts: `hetz`
(Linux VPS, SSH alias `hetzner`, installed checkout `/worksp/ai-devops` owned by
user `ai`), and Windows machines `916` (this session, checkout on D:), `4837`,
`edge-dev`. Machine nicknames and SSH routes live in the protected machine atlas;
never put keys or atlas contents in the public repo.

## 2. What we set out to do this session, and why

Albert asked to pull the latest repo and land issue #2242 (the scheduled
shared-db worktree reaper crashed nightly on hetz), then later to clear the two
follow-up items that rollout produced: #2274 (the hetz install could not finish)
and #2264 (root-run landings leave root-owned files in `/worksp/ai-devops`).
All three are DONE and live-proven. This file carries only what the wrap-up
scope freeze deferred.

## 3. Current state — what is true right now

Done and proven (do not redo):
- #2242 fixed and landed: PR https://github.com/popcre/ai-devops/pull/2259,
  squash commit https://github.com/popcre/ai-devops/commit/eda34c5daa799e9b307bf398623a9b78115c665b.
  The reaper runs from inside the shared-db checkout, and a Node crash is no
  longer misreported as a safe sweep. Live proof on hetz and on 916 ("swept
  cleanly", 8:47 AM EST 2026-11-01); receipts on
  https://github.com/popcre/ai-devops/issues/2242.
- #2274 fixed and closed: the hetz install finished at 10:22 AM EST
  2026-11-01 with every required stage green and the pending authorization
  consumed; recipe recorded in
  https://github.com/popcre/ai-devops/blob/main/docs/deployment.md (the
  "Retry a half-done install" block) and in the issue receipt
  (https://github.com/popcre/ai-devops/issues/2274).
- #2264 fixed and closed: PR https://github.com/popcre/ai-devops/pull/2279,
  squash commit https://github.com/popcre/ai-devops/commit/d3c5aa3d9614117e655a45f4032df896ff2b593a,
  deployed on hetz the same day; a real landing left zero non-ai files and the
  root-read mechanism was demoed live (flagged read keeps the owner's index,
  bare read re-roots it). Receipt on
  https://github.com/popcre/ai-devops/issues/2264.
- Docs updated: PR https://github.com/popcre/ai-devops/pull/2300,
  commit https://github.com/popcre/ai-devops/commit/5a3339d832f162a493542b14f0f8d51545c6a75f.

Not started (the point of this file):
1. `docs/deployment.md` "Reviewer approval (no human approvals)" section still
   describes `--reviewer-approval` gates that owner rulings removed. The
   command examples were fixed by PR #2300; the policy prose was deliberately
   left untouched (see §6 step 1).
2. The hetz worktree graveyard under `/worksp/ai-devops` (see §6 step 2).
3. Windows hosts `4837` and `edge-dev` still run pre-fix copies until their
   next install (see §6 step 3).

## 4. Everything we tried that did NOT work

- `git merge --ff-only origin/main` in `/worksp/ai-devops` on hetz — refused by
  the installed-checkout main guard ("refusing to move refs/heads/main in the
  installed toolkit checkout"), and correctly so: only the protected installer
  advances that checkout. Do not retry this.
- `update.sh` as `ai` without bus env — every stage passed except required
  "OpenCode GLM server (pinned 1.18.12)": "Failed to connect to bus: No medium
  found" because `sudo -u ai -H` drops `XDG_RUNTIME_DIR`.
- Same-target `update.sh` retry as `ai` — refused at preflight: the manifest
  became root:root 0600 after the first run ("awk: ... Permission denied") and
  "ai-task-gates: STOP. Ordinary install transaction path already exists."
  `update.sh` preflight can never resume a pending transaction; only
  `install.sh`'s resume phase can (see §5).
- `update.sh` as root — passes the manifest read but fails required
  "Private memory seed" ("could not verify private hub visibility"; the hub is
  user-scoped) and leaves root-owned worktree files (chowned back same day).
  Root can never reach ai's systemd user bus even with XDG set.
- Root-run `update.sh` retry without `git config --global --add safe.directory`
  for the candidate — died instantly at `git rev-parse --show-toplevel`
  ("dubious ownership").
- The first version of the #2264 regression test asserted the index is
  byte-identical after a wrapped read. It fails on Linux because `git diff`
  inside the ownership wrapper rewrites the index even with
  `--no-optional-locks` (verified with a step-by-step probe). The wrapper's
  contract is owner-usable outputs (ownership restored), not byte-stability;
  the test now asserts ownership survives. Do not re-tighten it to bytes.
- Running `tests/test-ai-task-gates.sh` on Windows Git Bash — takes 10+ minutes
  and one test fails ("authorization cannot be issued twice for one target");
  the suite is Linux-only in CI (its manifest has no `windows` key) and passes
  467/467 on Linux. Do not chase the Windows-local failure.
- `bash <script>` from PowerShell on this Windows machine resolves to a broken
  WSL stub ("Windows Subsystem for Linux has no installed distributions").
  Always use `"C:\Program Files\Git\bin\bash.exe"`.
- Long-running bash-tool commands die with "Unknown: ChildProcess.kill" at the
  tool timeout; capture output to a file and use explicit long timeouts.

## 5. Root causes and key findings

- The reaper (`scripts/reap-merged-worktrees.mjs` in `popcre/shared-db`) lists
  worktrees with a bare `git worktree list` and treats its cwd as the checkout
  it must never reap — it must run from inside the shared-db checkout. A Node
  crash exits 1, the same code as the reaper's safe refusal; the wrapper now
  separates them by the "Node.js v" crash footer. See
  https://github.com/popcre/ai-devops/blob/main/bin/ai-reap-shared-db-worktrees
  and the receipts on issue #2242.
- A half-done install must be retried through `install.sh` directly (resume
  phase matches the pending ordinary transaction near
  `bin/ai-task-gates` lines ~2180/:2293); `update.sh` preflight always refuses
  an existing ordinary transaction. Run the retry as the target owner with
  `XDG_RUNTIME_DIR=/run/user/<uid>` and `DBUS_SESSION_BUS_ADDRESS` exported;
  one user per install (gate state is `$HOME`-scoped).
- Root-run git rewrites `.git/index` and worktree files as root: `git status`
  refreshes the index unless `--no-optional-locks`, and `git diff` rewrites it
  even with that flag. The ownership wrapper
  (https://github.com/popcre/ai-devops/blob/main/tools/lib/install-public-git.py)
  restores owner afterwards; the gate's status reads carry `--no-optional-locks`
  so they never write. Mechanism proof is in the #2264 receipt.
- `public_git`'s internal `git diff` check is the remaining writer inside the
  wrapper; it is covered by ownership restoration and pinned by
  https://github.com/popcre/ai-devops/blob/main/tests/test-install-public-git.py.

## 6. Exact next steps

1. Policy-docs accuracy pass on the "Reviewer approval (no human approvals)"
   section of https://github.com/popcre/ai-devops/blob/main/docs/deployment.md
   (roughly lines 449-462). It still says every gate takes
   `--reviewer-approval`, which owner rulings
   (https://github.com/popcre/ai-devops/blob/main/docs/owner-rulings.md,
   2026-10-15 and 2026-10-29 night) removed and which `update.sh` no longer
   accepts. Scope: restate the section to match the rulings and the code
   (reviews preferred, never required; `authorize-install` optional per
   https://github.com/popcre/ai-devops/blob/main/docs/reviewer-enforcement-inventory-2026-10-29.md).
   Do NOT change any gate code in this step. Verification: prose-only PR, `bin/ai-doc-safety` passes on the exact head, admin-merged; a reader can
   follow the Update section end-to-end without meeting a removed flag.
2. Hetz worktree graveyard under `/worksp/ai-devops` (host `hetz`, SSH alias
   `hetzner`). `git -C /worksp/ai-devops worktree list` shows ~30 leftovers:
   `/var/tmp/ai-658-hetz-*`, `/worksp/ai-devops-cand-*`, `/worksp/ai-devops-candidate`
   (root-owned, at old SHA 9170814b), `/tmp/ai-devops-1876*`, and more. Audit
   each with the `cleanup-worktree` skill (never treat age as proof; recover
   unique work first), then remove. Work as user `ai` for git operations;
   root-run git re-roots files (issue #2264). Verification: `git worktree list`
   shows only live worktrees, and `find /worksp/ai-devops ! -user ai | wc -l`
   is 0.
3. Windows fleet pickup: hosts `4837` and `edge-dev` still run pre-fix copies of
   `bin/ai-reap-shared-db-worktrees` and `update.sh` until their next install
   via `bin/install-ai-devops-windows.ps1`. No action needed until such an
   install; after it, verify the reaper dry-run sweeps cleanly on each
   (`bash bin/ai-reap-shared-db-worktrees run --dry-run` ends "swept cleanly")
   and no root/other-user-owned files appear in the checkout.

## 7. Constraints and gotchas in force

- Never push to `main`; branch + PR + merge queue (prose-only PRs merge with
  `gh pr merge --squash --admin` after `bin/ai-doc-safety` passes on the head).
  All GitHub calls go through `bin/ai-gh`; long waits through
  `bin/ai-pr-wait <pr> --fit-tool-call`.
- Declare the task class (`bin/ai-task-gates start --class <class>`) before
  work and `check --before <action>` before ship/install actions. Changes
  touching `update.sh` or `bin/ai-task-gates` get class `installation`.
- Never weaken protections to pass a gate (no chmod/chown of `/etc/ai-devops`,
  no hook disabling, no broad `safe.directory` adds).
- Sign GitHub posts `Posted by MiMo chat unknown on 916` (this session's
  `$MIMO_SESSION_ID` was empty).
- Quotes to humans are EST (America/New_York).
- The canonical checkout on each machine is landing-only; write-capable work
  uses its own worktree from `origin/main`.

## 8. Access and environment

- SSH alias `hetzner` (connects as root; `sudo -u ai -H` works; ai has
  passwordless sudo). Server paths above are on that host.
- On Windows use `"C:\Program Files\Git\bin\bash.exe"` for shell scripts; plain
  `bash` is a broken WSL stub.
- Secrets: none used this session. When needed they come from the 1Password
  vault `vibe_coding` via the 1Password MCP — never pasted anywhere.
- Python: `$env:MIMO_PYTHON` on Windows; `python3` on hetz. The test
  `tests/test-install-public-git.py` is POSIX-only (imports `pwd`) — run it on
  Linux.

## 9. Open questions and risks

- The `test-ai-task-gates.sh` Windows-local failure and 10-minute runtime
  (§4) are unexplained; harmless because CI runs the suite on Linux only, but
  a future Windows-porting session should know it exists (observed
  2026-11-01).
- The ownership wrapper's internal `git diff` still rewrites the primary index
  on every wrapped call (restored to the owner immediately). Acceptable by
  design (2026-11-01 decision); do not "fix" it by weakening `restore_outputs`.
- Hetz's `/etc/ai-devops/install-manifest.tsv` ownership follows the last
  installer run's user; a root run makes it root:root 0600 until the next ai
  run rewrites it (fact, 2026-11-01, #2274).

## Part (b) — sub-agent reports

### general-1 — "Finish hetz install authorization" (completed, success)
Asked to finish the half-done hetz install for #2274. It found the working
invocation shape (as ai with `XDG_RUNTIME_DIR` + `DBUS_SESSION_BUS_ADDRESS`),
completed all stages at 10:22 AM EST, and verified acceptance. Its findings are
in https://github.com/popcre/ai-devops/issues/2274 (receipt posted by the
coordinator) and §5 above. It changed no repo files. It deliberately posted
nothing to GitHub itself.

### general-2 — "Fix root-run landing path" (cancelled mid-run; coordinator finished)
Asked to find the root-cause of the root-owned landing and land a fix for #2264.
It identified the root cause correctly (old `update.sh` bare `git merge` as
root) and left uncommitted edits on its branch `fix/2264-root-run-git-writes`
(https://github.com/popcre/ai-devops/tree/fix/2264-root-run-git-writes), but wedged before committing or opening a PR. The coordinator took
over, corrected its over-strong test, and landed PR
https://github.com/popcre/ai-devops/pull/2279. Its worktree is finished; nothing
of its work is lost.

---

Self-audit (handoff-writer gate, 2026-11-02T0104Z):
1. Yes — a street-newcomer gets the app (§1), the finished state with proof
   (§3), every dead end (§4), the findings (§5), and three numbered steps with
   verification gates (§6).
2. Yes — the session's non-obvious knowledge (retry recipe, cwd contract, git
   write behavior, Windows traps) is in §4/§5/§7/§8, not in chat.
3. Yes — background (§1-2), state (§3), failures (§4), decisions (§5, §9),
   constraints (§7), access (§8), next actions with gates (§6) are all present;
   file and commit references are GitHub URLs.
4. Yes — §0 sweep run: the only owner-adjacent topics are already-settled
   rulings listed in §0; the three deferred items are technical and live in §6.
