---
issue: 1114
status: OPEN
owner: mimo/reviewer-pipeline-phase-d-doors-fleet
---

# Handoff — shared review-runner doors: land, install fleet, hetz receipt

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

**None — nothing in this workstream needs the owner.** Every remaining item is a
technical gate, an issue checkbox, or a timed clean window. Do not ask Albert to
approve any of it (owner ruling 2026-09-28: never ask a human to approve).

Already settled — do NOT re-ask:
- 2026-09-29: fleet is Muse, Grok, Qwen, StepFun, DeepSeek, Gemini (Claude/Codex write/orchestrate).
- 2026-09-28: never ask a human to approve; assigned AI reviewers gate technical production actions.
- 2026-10-05: Phase E helper retirement stays blocked until the clean window is met.

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery/operating toolkit for a multi-model
AI workflow. Not an app or service. Installation from this repository is how
machines get reviewer wrappers, skills, and policy.

- GitHub: https://github.com/popcre/ai-devops — target `main` (merge queue).
- Canonical local checkout: `C:\repos\ai-devops` (landing-only).
- Windows host: `edge-dev`. Reviewer install tree: `C:\repos\ai-devops-reviewer-install`.
- Ubuntu desktop: `edge-dev3` (toolkit at `/home/ahazan/repos/ai-devops`).
- Ubuntu VPS: `hetz` (toolkit at `/worksp/ai-devops`; SSH alias `vps`).

## 2. What we set out to do this session, and why

Albert asked whether the old per-reviewer plumbing had been replaced by one
common review gateway. Plan `plan_reviewer-pipeline-core.md` (Phase D) is that
gateway: one runner owns identity/locks/packets/lifecycle; each provider is a
thin door. Phases A–C had landed earlier. Phase D was marked done but only
**2 of 6** doors (Grok, DeepSeek) were registered, so Muse/Qwen/Gemini/StepFun
still finished through the legacy pool path and never wrote `packet_sha256`.
Phase E (retire duplicated helpers) cannot advance without those packet reviews.

This session: finish the missing doors, land them, install on the fleet, and
keep Phase E honestly gated.

## 3. Current state — what is true right now

### Landed (verified)
- PR **#1322** merged to `origin/main` as **`85b5ff579ad9187cd0b7fd73020047768a0b325c`**
  (`feat(#1114): register Muse/Qwen/Gemini/StepFun as runner doors`).
- All six doors exist: `tools/lib/review-doors/{grok,deepseek,muse,qwen,gemini,stepfun}.sh`
  registered in `config/review-runner-doors.json`.
- Independent Muse final-check APPROVED the PR head `0e90180a12b9416f393c61fa38b8bda1386bb473`
  before merge (report in worktree `.ai/reviews/muse-final-check-20261006T142910-1818794-32612.md`).
- **edge-dev** install tree `C:\repos\ai-devops-reviewer-install` fast-forwarded to
  `85b5ff5`; `tools/lib/review-doors/` lists all six; preflight reports the
  rotation fleet usable.
- **edge-dev3** `/home/ahazan/repos/ai-devops` is at `cc564d51c77d6f2b268483eb0342537cddd518d9`
  (includes #1322 + a later grok-pin fix) with all six doors present.
- **hetz** `/worksp/ai-devops` is also at `cc564d51c77d6f2b268483eb0342537cddd518d9`
  with all six doors **in source**. Grok final-check with
  `--operation stale-linux-manifest-recovery` APPROVED on that host
  (report `/worksp/ai-devops-candidate/.ai/reviews/grok-final-check-20261006T182143-1179555-6156.md`).

### Half-done
- **hetz install receipt is still stale.** `/etc/ai-devops/install-manifest.tsv`
  records `source_sha cdd18b9b0b2d70f973b09e43cfbe8ec8d1bf35ae` (older).
  `ai-task-gates authorize-install --stale-manifest-recovery` refuses the Grok
  report because the parser treats **two** `| reviewed commit |` rows as a
  multi-line value that will not equal the target SHA. Launchers already symlink
  into `/worksp/ai-devops/bin/`, so runtime serves the new doors; only the
  receipt is wrong.
- Leftover live proofs on issue **#1114** (comment
  https://github.com/popcre/ai-devops/issues/1114#issuecomment-6020730520):
  - [ ] live review through the muse door leaves packet_sha256
  - [ ] live review through the qwen door leaves packet_sha256
  - [ ] live review through the gemini door leaves packet_sha256
  - [ ] live review through the stepfun door leaves packet_sha256
- Phase E (delete duplicated helpers + metrics proof) still **BLOCKED** on the
  clean window — see `plan_reviewer-pipeline-core.md` STATUS row 5 and
  `HANDOFF.d/2026-10-05T1913Z-edge-dev-mimo-phase-e-window.md`.

### Not started this session
- Gate fix for duplicate `reviewed commit` rows (see §6 step 1).
- Phase E retirement PR.

## 4. Everything we tried that did NOT work

1. **Wait-loop polling of a background subagent.** Twice the session sat in
   `actor wait` cycles (10-minute timeouts) instead of reporting. Albert called
   it out. Lesson: one bounded wait max, then report or take over; PR is the card.
2. **Running the stale-manifest review as root on hetz.** Preflight failed
   (`authentication-failed` for Grok; snapshot build failed). Cause: credentials
   and git ownership live under user `ai`. `sudo -u ai` is required.
3. **Root-owned linked worktree `/worksp/ai-devops-candidate`.** Snapshot build
   failed with `could not build a complete review snapshot`. Root cause was
   `git fetch file://<linked-worktree>` hitting
   `dubious ownership` at `/worksp/ai-devops/.git/worktrees/ai-devops-candidate`
   (directory owned by root). Fix: `chown -R ai:ai` on the worktree **and** its
   gitdir; also `safe.directory` for that path.
4. **Reviewing the install target from the primary checkout, then authorizing
   from the same tree.** Gate message: `Protected review and installation must
   use separate tasks.` It means separate **worktrees**: `reviewed_root` must
   differ from authorize `TOPLEVEL` (`bin/ai-task-gates` ~1535) while sharing
   git-common-dir and both being at the target SHA.
5. **Authorize-install after a review that only exists under the same task.**
   Same message. End the task, start a fresh `installation` class task for
   authorize.
6. **Candidate vs installed identical path.** `Candidate and installed checkouts
   must differ.` Need a second linked worktree for authorize
   (`/worksp/ai-devops-install-candidate` was created for this).
7. **`bash -lc` on this Windows host without an explicit Git Bash path.** That
   invoked WSL (no distro). Always use `"C:\Program Files\Git\bin\bash.exe" -lc`.
8. **Bare `gh` / `ai-gh pr merge --merge`.** Merge strategy is set by the merge
   queue; `ai-gh pr merge 1322` (no strategy) queues it.
9. **`ai-review-preflight doctor`.** Not a subcommand; use `status` / `usable` /
   `check <provider> <repo> --live`.
10. **Assuming the other hetz session was wrong about reviewers.** They were
    right. Preflight `usable` is true for grok/muse/qwen/gemini/deepseek/stepfun
    as user `ai`. Our failures were local setup.

## 5. Root causes and key findings

- **`config/review-runner-doors.json` is the packet-identity gate.** Only
  registered doors reach `tools/lib/review-lifecycle-core.sh` which writes
  `--packet-dir`/`--packet-sha256`. Legacy pool finish
  (`bin/ai-review-pool` around the finish call) does not.
- **New Bash suites need a `config/ci-suites/<suite>.json` entry.**
  `tests/test-workflow-policy.sh` "manifest exactly matches Bash discovery"
  fails closed otherwise (we hit this with `test-pool-dispatch-doors.sh`).
- **Grok door report body includes a second `| reviewed commit |` table** (the
  door's own metadata). `ai-task-gates` `cmd_authorize_install` uses
  `awk -F'|' '$2 ~ /reviewed commit/ {…; print $3}'` with **no head/tail**, so
  two matches make `reviewed_commit` multi-line and
  `[ "$reviewed_commit" = "$target_head" ]` fails (`bin/ai-task-gates:1541-1542`).
  This blocks `authorize-install` for any report shaped like the new doors.
- **Linked worktree snapshots need gitdir ownership + `safe.directory`.**
  `ai-review-sandbox` builds snapshots with `git fetch file://<worktree>`.
- **Muse is the default pipeline review provider on Windows; on hetz use Grok
  (or DeepSeek/StepFun) as `user ai`.** Never MiMo-as-reviewer.
- **Phase E window last measured NOT MET** (2026-10-05T21:35Z): Criterion A
  5.78/14 days from `a5bc30be` (target 2026-10-14T02:56Z); Criterion B 23/50
  packet reviews. See artifact
  `~/.local/state/ai-devops/review-lifecycle/phase-e-window-20261005T2135Z.txt`.

## 6. Exact next steps

1. **Fix `ai-task-gates` reviewed-commit parse** so a report with one or more
   identical `| reviewed commit |` rows still binds to the target (e.g. take
   the first match, or the last, and require they are equal).
   - Files: `bin/ai-task-gates` (~1541), tests under `tests/test-ai-task-gates.sh`.
   - This is **reviewer-safety path** — one read-only exact-head final review
     before merge (`ai-review <provider> final-check --implementer mimo`).
   - You'll know it worked when unit tests cover a two-row report and
     authorize-install accepts the existing Grok recovery report (or a fresh one).
2. **Re-run hetz install** after the fix (do not start from scratch — §3 has the
   SHA and report paths):
   - As user `ai`, from a **second** linked worktree at
     `cc564d51c77d6f2b268483eb0342537cddd518d9` (or newer main),
     `ai-task-gates start --class installation` then
     `authorize-install --stale-manifest-recovery …` with a report that lives in
     the **other** worktree (or `/worksp/ai-devops` if that is clean and at target).
   - Then `update.sh --expected-head <full-sha> --reviewer-approval <report>`.
   - Restore `/worksp/ai-devops/.worktrees` if still at
     `/worksp/ai-devops-worktrees-backup-20261006` (it was moved back).
   - You'll know it worked when `/etc/ai-devops/install-manifest.tsv` `source_sha`
     equals the installed HEAD and `ai-review-preflight status` stays healthy.
3. **Live proofs (one real review per new door)** — tick the four checkboxes on
   #1114. Fixture tests are not live proof. Prefer a normal governed review
   (e.g. `ai-review muse final-check` / `ai-review qwen final-check` on some
   real PR) so `packet_sha256` is non-null in lifecycle.
   - You'll know it worked when each door has a completed lifecycle row with
     non-null `packet_sha256` and a durable packet copy.
4. **Phase E** only after the clean window is MET (see the phase-e-window
   handoff). Then metrics subagent, then a **separate** reviewer-safety helper-retire PR.
   Do not delete helpers early.
5. **Cleanup (after steps 1–3):** delete local branch `mimo/phasee-metrics-prep`
   only after confirming #1322 is MERGED (it is). Remove worktree
   `C:\repos\ai-devops-wt-phasee-metrics` via `cleanup-worktree` when its tree is
   clean and merged. Leave hetz `/worksp/ai-devops-candidate` and
   `/worksp/ai-devops-install-candidate` until install is proven, then remove.

## 7. Constraints and gotchas in force

- Never push `main`; branch + PR + merge queue. Albert does not merge — the AI
  does, except DesignFlow and PRs he named for himself.
- Canonical `C:\repos\ai-devops` is landing-only; write work uses a dedicated
  current-upstream worktree.
- Reviewer-safety changes (wrappers, evidence tools, safety tests, installed
  routing) need one independent exact-head final review before merge.
- `bin/ai-gh` for every GitHub call; `bin/ai-pr-wait <pr> --timeout-minutes N`
  for waits. No bare `gh`, no `gh run watch`, no unbounded loops.
- Sign GitHub posts: `Posted by MiMo chat $MIMO_SESSION_ID on <machine>`.
- Git identity before commit: `Albert Hazan <u2giants@users.noreply.github.com>`.
- Secrets: 1Password vault `vibe_coding` via `op run` only; never log values.
- Windows tests via Git Bash (`C:\Program Files\Git\bin\bash.exe`).
- Do not treat fixture/unit success as live proof.
- Do not open a second ticket for leftover proofs — use the parent issue
  checkboxes (#1114 / #1110).

## 8. Access and environment

- Host `edge-dev` (Windows): Git Bash, `ai-gh`, `ai-review`, `ai-task-gates`.
- Host `edge-dev3`: `ssh -i ~/.ssh/916-alien ahazan@edge-dev3`.
- Host `hetz`: SSH alias `vps` (root). Run reviewer/install commands as `ai`:
  `sudo -u ai bash -lc '…'`.
- Keys: 1Password vault `vibe_coding` (item names only in docs).
- Review reports produced this session (do not rewrite; hash-bound):
  - Muse approve of PR head: worktree `.ai/reviews/muse-final-check-20261006T142910-1818794-32612.md`
  - Grok stale-manifest approve on hetz:
    `/worksp/ai-devops-candidate/.ai/reviews/grok-final-check-20261006T182143-1179555-6156.md`
    (and an earlier copy under `/worksp/ai-devops/.ai/reviews/…175805…`)

## 9. Open questions and risks

- **Gate vs door report shape (2026-10-06).** Duplicate `reviewed commit` rows
  may block any future authorize-install until step 6.1 lands. Do not "fix" by
  editing a hash-bound report.
- **Phase E Criterion B (2026-10-05).** Even with doors registered, only
  grok+deepseek had been producing packets. Muse/Qwen/Gemini/StepFun must run
  live reviews after install, or 50 zero-incident packet reviews will not arrive
  before the 14-day clock (2026-10-14).
- **hetz worktrees.** Two extra linked worktrees plus a backup of `.worktrees/`
  may still exist; do not delete until install is proven (§6.5).
- **`tests/test-ai-grok-review.sh` wall-clock interrupt section** is a known
  pre-existing flake (Phase A5 in the pipeline plan). Do not treat as a
  regression from door work; do not weaken the test.

---

### Self-audit (handoff-writer)

1. **Comprehensive for a brand-new developer?** Yes — §1 defines the app and
   hosts; §2 the goal; §3 exact SHAs/paths/checkboxes; §4 ten failed attempts
   with causes; §5 root causes with file:line; §6 ordered next steps with
   verification gates; §7–9 constraints, access, risks.
2. **Detailed enough to continue as well as this session?** Yes — §3 lists live
   report paths and install SHAs; §4 includes the ownership/safe.directory and
   two-worktree authorize requirements that cost the most time; §6 step 2
   restates the exact hetz commands' constraints.
3. **Every relevant detail?** Yes — background §2, current state §3, failures §4,
   findings §5, actions §6, constraints §7, env §8, risks §9. Secrets by vault
   name only (§8).
4. **Section 0 owner-only?** Yes — §0 says none required and lists already-settled
   rulings. Technical gates (reviewer-safety review, clean window, issue
   checkboxes) stay out of §0 and live in §3/§6/§9.
