---
issue: 1061
status: OPEN
owner: mimo/1061-residuals-hetz-tools
---

# HANDOFF — coord-del residuals after Hetz adopt and machine-tools dedup

Machine: edge-dev · Agent: mimo · Written: 2026-09-30T14:31Z
Session signature used on GitHub: `Posted by MiMo chat ses_ffe5f11088f5cffeSHgdXquBqY on edge-dev`
This session id: `ses_ffe5f0db3618dffeU2OnrB976M` (MiMo)

Predecessor handoff (do not edit): `HANDOFF.d/2026-09-30T1226Z-edge-dev-mimo-coord-del-residuals.md`
(owner `mimo/coord-del-parent-1061`). This file supersedes its open next-steps
after steps 1–2 below landed. Keep the predecessor until a later session
proves t16 + the 14d/30d measures and retires both.

## 0. DECISIONS ONLY THE OWNER CAN MAKE

- **Whether mid-work sessions must be manually poked with the claim-first blurb,
  or only new/restarted sessions matter.** Recommendation: only new/restarted —
  mid-work sessions pick up claim-first after restart. Blocks nothing; fleet
  mixed-rule window only.
- **Whether to chase t16 adopt as soon as Tailscale is up, or wait for the 14d
  measure window.** Recommendation: adopt as soon as reachable (install, not
  deploy). Blocks fleet consistency claim.
- **Whether a dedicated residual issue should be opened for t16 + 14d/30d
  measures** (parent #1061 is closed; plan STATUS is the live record).
  Recommendation: open one small issue titled “coord-del residuals: t16 adopt +
  14d/30d measure” if the next session wants a card; otherwise keep using plan
  STATUS. Blocks clean handoff retirement.

Already settled — do NOT re-ask:
- Never reopen #401. Never rebuild an orchestrator / leftover-proof mill / chat
  merge conductor / BlockerWatch registration / path-filtered required checks
  (owner + plan, 2026-09-29/30).
- Parent #1061 CLOSED 2026-09-30T05:43Z; all children #1062–#1077 closed.
- machine-tools.tsv duplicate rows are fixed on `origin/main` (#1168).
- Hetz globals re-adopt is done and proven (#1177).

Put this whole §0 list to Albert in ONE message before starting the next residual
work. Do not drip decisions.

## 1. What this application is

`popcre/ai-devops` is Albert's public AI workflow toolkit (rules, skills, task
gates, plans, installers). It is not an app/service/DB. Workstream: finish the
shared-db **coordination deletion** (C by deletion) leftovers while keeping the
claim/lease/review/live-proof **safety engine** in `popcre/shared-db`.
Plan: `plan_shared-db-coordination-deletion.md`.
Background: `docs/shared-db-delivery-failure-background-2026-09-29.md`.

Hosts: edge-dev (this machine), edge-dev3, al8960ofc/4837, Hetz (`ssh vps2-direct`,
user `ai`, checkout `/worksp/ai-devops`), t16 (often unreachable).

## 2. What we set out to do this session, and why

Albert's request (verbatim scope):

1. Fix `config/machine-tools.tsv` duplicate `ai-blocker-watch` and
   `ai-reap-shared-db-worktrees` rows; tests green; PR to main.
2. `ssh vps2-direct`, update `/worksp/ai-devops` to `origin/main`, run
   `bin/ai-adopt-globals`, write adopt proof. Parent #1061 is closed.

Why: the duplicate rows made `bin/install-machine-tools.ps1` throw
“Machine-tools catalog has an unsafe or duplicate command name” → every
`ai-adopt-globals` ended `SYNC INCOMPLETE`. Hetz was still on stale `c5f1c39`
with pre-claim-first globals.

## 3. Current state — what is true right now

**Done this session (verified on `origin/main`):**

| Outcome | Evidence |
|---|---|
| machine-tools.tsv dedup | PR **#1168** merged `45cd6b5e` (also fixed the broken plan link that blocked every PR) |
| Hetz checkout at merged tip | `/worksp/ai-devops` detached `45cd6b5` (was `c5f1c39`; tree clean before update) |
| Hetz Claude + Codex globals | claim-first wording present (`/home/ai/.claude/CLAUDE.md` L155/167; `/home/ai/.codex/AGENTS.md` L188/202) |
| Hetz launchers | four missing Ubuntu links created (`ai-stepfun`, `ai-reviewer-start-watch`, `ai-reap-shared-db-worktrees`, `ai-install-post-merge-hook`); `ai-machine-tools-doctor --platform ubuntu` → `OK local AI command launchers are current` |
| Adopt proof | PR **#1177** merged `6c0683fa` → `tests/verification/shared-db-coordination-deletion/adopt-hetz-20260930T134934Z.md` |
| ZCode / MiMo on Hetz | **not installed** (same as al8960ofc) — not a gap to force |

**Fleet adopt after this session:** edge-dev ✅ · edge-dev3 ✅ · al8960ofc/4837 ✅
(Claude+Codex) · **Hetz ✅** · **t16 unreachable**.

**Not started (carried forward):**
- t16 re-adopt when online (atlas: no SSH alias from edge-dev; Tailscale was down).
- 14d open/close ratio measure due **2026-10-14** (query documented in
  `tests/verification/shared-db-coordination-deletion/2026-09-30T045654Z.md`).
- 30d collisions + duplicate-need measure due **2026-10-30**. Stop rule: named
  assignee on that issue — never rebuild an orchestrator.

Plan STATUS on `origin/main`: steps 0–8 done, 9 proven edge-dev/edge-dev3/
al8960ofc/Hetz with t16 residual, 10 started.

## 4. Everything we tried that did NOT work

- Declaring `ai-task-gates start --class code` (or `documentation`) on this TSV
  change: `config/machine-tools.tsv` escalates to **`installation`**. Correct
  class is `installation`. Also: `bin/ai-task-gates` from the canonical checkout
  `C:\repos\ai-devops` sees **other sessions' dirty reviewer-safety files** and
  wrongly escalates to protected `reviewer-safety`. Always run task-gates and
  `ai-pr-wait` from a **clean worktree** of the PR branch with `--base origin/main`.
- First CI on #1168: `test-markdown-links.sh` failed on
  `tests/verification/shared-db-coordination-deletion/2026-09-30T045654Z.md`
  (`link escapes repository` — one too many `..` segments). Fixed on the PR as
  `04473b7f`. Pre-existing on main; not caused by the TSV edit.
- Same PR run: `test-public-boundary.sh` failed with
  `BOUNDARY FAIL: protected private-network topology found` — private IPs in
  coord-del records. **Already fixed on main** by #1171 (`87306bbf`) redacting
  those addresses. Do not reintroduce concrete `192.168.*` / `10.*` / Tailscale
  `100.64–100.127.*` host IPs into public files.
- Merge-group for #1168 ejected once:
  `ai-merge-group-evidence: run 36717544169 reports no jobs; its coverage cannot
  be confirmed` even though that PR run later showed 28 successful jobs. Transient
  evidence-tool/API race. **Re-enqueue** (`gh pr merge --squash --auto`); the next
  merge-group (run `36722928233`) passed and landed `45cd6b5e`.
- `bin/ai-adopt-globals` on Hetz ended `SYNC INCOMPLETE` after globals landed:
  four Ubuntu launcher links missing under `/usr/local/bin` (root-owned). Not the
  old duplicate-row bug. Fixed with `sudo -n ln -sfn /worksp/ai-devops/bin/<tool>
  /usr/local/bin/<tool>` for those four names, then doctor went OK.
- Direct `ssh -i ~/.ssh/916-alien ai@178.156.180.212` (from predecessor handoff):
  connection timeout. **Use `ssh vps2-direct`.**

## 5. Root causes and key findings

- Duplicate catalog rows were a real install-time hard error at
  `bin/install-machine-tools.ps1:74` (`unsafe or duplicate command name`). Keeping
  the first row only is enough; no other catalog change is required.
- `config/machine-tools.tsv` is task-class **`installation`**, not `code`.
- Merge-queue evidence can flake on “run reports no jobs” while the PR run is
  healthy — treat as eject-and-requeue, not a product defect (unless it repeats
  on the same head).
- Hetz globals and launchers can drift independently: globals adopt can succeed
  while Ubuntu links are stale. Always run `bash bin/ai-machine-tools-doctor
  --platform ubuntu` after adopt on Linux hosts.
- Hetz git remote in that checkout reported `u2giants/ai-devops` while
  `origin/main` content matched `popcre` tip `45cd6b5` — same commit; do not
  “fix” remotes during adopt.
- Do not tidy the canonical checkout `C:\repos/ai-devops`: other sessions have
  untracked handoffs/docs there. Work in a dedicated worktree.

## 6. Exact next steps

1. **t16 re-adopt when online.** Reachability check from edge-dev (atlas: no SSH
   alias; Tailscale). If reachable: inspect `/worksp` or equivalent checkout for
   local changes, advance to `origin/main` tip, `bash bin/ai-adopt-globals`, then
   `bash bin/ai-machine-tools-doctor --platform ubuntu`. Write proof under
   `tests/verification/shared-db-coordination-deletion/adopt-t16-*.md` (a stub
   already exists from the unreachable attempt — replace with a real proof).
   **You'll know it worked when** doctor says `OK local AI command launchers are
   current` and the installed global contains the claim-first sentence.
2. **14d measure (due 2026-10-14, America/New_York).** Run the open/close ratio
   query recorded in `tests/verification/shared-db-coordination-deletion/
   2026-09-30T045654Z.md`. Append results to that record or a sibling dated file.
   **You'll know it worked when** the ratio is written with date and source query.
3. **30d measure (due 2026-10-30).** Collisions + applied duplicate-need
   migrations (claim overlap + `db-claim` close reasons in `popcre/shared-db`).
   **Stop rule:** ≥1 applied duplicate-need migration or production break from
   that class → put a **named assignee on that issue**. Do **not** rebuild an
   orchestrator. Do not reopen #401.
4. Optional: open the small residual issue from §0 if Albert wants a card; then
   retire this handoff and the predecessor when t16 + measures are proven.

## 7. Constraints and gotchas in force

- Do **not** reopen #401. Do **not** add orchestrator role, leftover-proof ticket
  mill, chat merge conductor, BlockerWatch registration, or path-filtered required
  checks.
- Do **not** drop shared-db freshness until #2530.
- Route string `shared-db-orchestrator` stays; only required-ness is gone.
- Stage only named files; worktrees from `origin/main`; `git var GIT_COMMITTER_IDENT`
  = Albert before commit; never push `main`; merge through the queue. Docs-only
  PRs (prose only) may `gh pr merge --squash --admin` immediately.
- Production hosts are read-only by default; **install of toolkit rules is not a
  deploy** — still inspect for local changes before any checkout move (Hetz was
  clean; do the same on t16).
- Public repo: no transcripts, no concrete private host IPs, no secrets.
- Signature on GitHub this residual stream:
  `Posted by MiMo chat ses_ffe5f11088f5cffeSHgdXquBqY on edge-dev`
  (this closer session used the same signature per Albert's instruction).
- Canonical checkout is landing-only and has other sessions' untracked files —
  leave them.

## 8. Access and environment

- GitHub: `bin/ai-gh` via Git Bash (`"C:\Program Files\Git\bin\bash.exe"`).
  Plain `bash` on this host is WSL and fails. All GitHub calls through `bin/ai-gh`.
- Hetz: `ssh vps2-direct` (user `ai`, `/worksp/ai-devops`). Do **not** use
  `ssh -i ~/.ssh/916-alien ai@178.156.180.212` (times out).
- edge-dev3: `ssh -i ~/.ssh/916-alien ahazan@edge-dev3`.
- al8960ofc/4837: Tailscale often down; LAN `192.168.2.131` as `ahazan2` with
  916-alien; remote default shell is cmd.exe. (Do not put that LAN IP in public
  proof files.)
- Machine atlas (private): `bin/ai-private-config path machine_atlas`.
- Secrets: 1Password vault `vibe_coding` only. None appeared this session.

## 9. Open questions and risks

- t16 may still be offline indefinitely; fleet mixed-rule window stays until it
  adopts (a session there might still wait on an orchestrator or mint leftover-proof
  tickets).
- Merge-group evidence “reports no jobs” flake may recur; requeue first before
  treating it as a product bug.
- Predecessor `HANDOFF.d/2026-09-30T1226Z-edge-dev-mimo-coord-del-residuals.md`
  has `issue: 1061` while #1061 is CLOSED → **SUCCESSOR REVIEW candidate**
  (owner `mimo/coord-del-parent-1061`). Do not delete until t16 + measures are
  proven and obligations are fully carried here.
- Residual duplicate-need tickets at 3×4 harnesses accepted; measured in step 10.

---

## Self-audit

1. **Could a brand-new developer continue cold?** Yes — §3 table of landed SHAs,
   §6 numbered steps with gates, §8 SSH paths, §4 dead ends.
2. **Tried-and-failed included?** Yes — §4 (task-gates class, markdown link,
   public-boundary IPs, merge-group evidence flake, Hetz missing launchers, wrong SSH).
3. **Business-only decisions separated?** Yes — §0 with recommendations and
   do-not-re-ask list.
4. **Issue named?** #1061 (closed parent); completion evidence is plan STATUS +
   #1168 + #1177; optional new issue listed in §0.
5. **Secrets:** none appeared (SSH keys pre-existed). Secrets sweep: none to store.
6. **Docs:** plan STATUS and the two verification PRs are the durable record;
   this file is the residual handoff for t16 + 14d/30d.

**Self-audit passed.**
