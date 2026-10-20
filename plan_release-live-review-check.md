# Plan — release live review check (Ubuntu + Windows, before fleet install)

Issue: [popcre/ai-devops#1783](https://github.com/popcre/ai-devops/issues/1783) (section 12a of [plan_review-output-contract.md](plan_review-output-contract.md)).
Handoff: [HANDOFF.d/2026-10-20T0010Z-hetz-claude-release-live-check.md](HANDOFF.d/2026-10-20T0010Z-hetz-claude-release-live-check.md).
Written 2026-10-19 (8:10 PM EDT) on hetz by Claude Code. Base: `main` at `39073d5b`.

## STATUS (read first — do not re-derive or re-plan)

| Step | State | Evidence |
|---|---|---|
| 0. Plan written and merged | ✅ done 2026-10-19 | this file on `main` |
| 1. Shared-path detector in `tools/lib/review-capabilities.sh` | ⬜ open | — |
| 2. `bin/ai-release-live-check` (run / fleet / verify) | ⬜ open | — |
| 3. Install gate in `ai-task-gates authorize-install` | ⬜ open | — |
| 4. Tests | ⬜ open | — |
| 5. Docs (`docs/deployment.md`, router) | ⬜ open | — |
| 6. Live proof: hetz + 4837 statuses on a real merged SHA | ⬜ open | `- [ ] live proof` on #1783 |

A fresh session starts at **Step 1**.

---

## Part 1 — Why

### 1. Ultimate goal

A change to the shared review code must never reach every machine before it has
done one real review on Ubuntu **and** on Windows. Today a fix that works on one
OS can silently break reviews on the other, and we only find out when a real
review fails on a working machine. When this is done, the installer on every
machine refuses a release that changes shared review code until a real review
of a tiny fixed change has passed on both OSes for that exact commit.

**If a step conflicts with this goal, the goal wins — stop and flag it.**

### 2. What this application is

`popcre/ai-devops` is the toolkit that installs and runs the multi-model AI
review workflow on Albert's machines. One codebase runs two ways:

- **Ubuntu** (Bash): hetz, 916-alien, edge-dev3, edge-dev. Desktop and server
  are the same path.
- **Windows** (Git Bash under PowerShell/cmd launchers): **4837** (Tailscale
  name; Windows hostname `al8960ofc`, user `ahazan2`). The live installed
  checkout there is `C:\repos\ai-devops`. Reachable from hetz with
  `ssh 4837` (default shell is cmd; Git Bash is
  `"C:\Program Files\Git\bin\bash.exe"`).
- EDGE-ALIEN and Envy are **not** review hosts. Never run this check there.

Installs only advance through the protected routes: `ai-task-gates
authorize-install` (needs an assigned AI reviewer's exact-head APPROVE) then
`update.sh` (Linux) or `bin/install-ai-devops-windows.ps1` (Windows). Both run
`bin/ai-task-gates` in Bash, so one gate covers both OSes.

### 3. What triggered this work

PR 1807 added a Windows StepFun shim. It passed CI (the simulated
`linux-offline` and `windows-offline-section` shards aggregated by the required
`verification-closure` check), was installed, and then broke every real Windows
StepFun review with `spawnSync bash UNKNOWN`. PR 1848 reverted it, tested only
on Linux. Since February there have been 72 Windows-specific reviewer fixes.
Nothing runs a real review on both OSes after a merge.

### 4. Scope

In:
- A command that runs one real, cheap review of a fixed tiny fixture from an
  exact candidate commit, on the local OS, and on 4837 from an Ubuntu host.
- Recording the per-OS result on the commit as GitHub commit statuses.
- A refusal in `authorize-install` when the release range touches shared review
  code and either OS lacks a passing status for the target commit.

NOT in this plan:
- A new runner pool or GitHub Actions workflow (owner constraint).
- Covering every provider on every run (one cheap provider by default; others
  on demand with `--provider`).
- Changing `update.sh` or the Windows installer flow, or the offline CI shards.
- Running anything on EDGE-ALIEN or Envy.
- The review output contract work (steps 1–8 of plan_review-output-contract.md).

## Part 2 — What we already know

### 5. Current state of the code

- Shared review paths are named once, in the regex inside
  `review_shared_code_rule` (`tools/lib/review-capabilities.sh:15-18`):
  `bin/ai-review{,-pool,-engine,-preflight,-packet,-sandbox,-lifecycle}`,
  `tools/lib/review-{lifecycle-core,capabilities}.sh`,
  `config/review-runner-doors.json`. It only emits a brief; no detector exists.
- `cmd_authorize_install` (`bin/ai-task-gates`, starts ~line 2266) already
  computes the release range `start_head..target_head` and runs in the
  candidate checkout on both OSes.
- `ai-review <provider> diff-review --base HEAD~1` works in any local git repo
  with no remote. Proven 2026-10-19 on hetz from a worktree's `bin/`: DeepSeek,
  29 s, exit 0, last stdout line = the report path, report ends with a
  `## Verdict` word.
- `ai-review doctor` on both hetz and 4837 (2026-10-19) shows glm, muse,
  deepseek, stepfun `installed-healthy`.

### 6. Key findings

- Running the candidate's own `bin/ai-review` with candidate `bin/` first on
  `PATH` exercises the candidate's shared review code without installing it.
- `gh` on 4837 over SSH cannot read the Windows keyring (memory
  `windows-ssh-cannot-read-gh-keyring`), so the Windows run must not post to
  GitHub itself; the Ubuntu driver posts both statuses.
- `popcre/ai-devops` is public, so the statuses can be read without a token
  (needed on any host whose `gh` is not signed in).
- Gemini fails over SSH on 4837 (Credential Manager), so it is never the
  default provider here.

### 7. Rejected approaches

- **New GitHub Actions workflow on a self-hosted Windows runner** — owner said
  no new runner pool; Windows runner hosts are not review hosts.
- **Running the check inside `install.sh`/requalification** — that runs after
  the code is already installed on that machine; the goal is before.
- **Local receipt files per machine** — each machine would have to run both
  OSes itself; a shared record on the commit is checked once per release.
- **Trusting any status author** — statuses are writable by any collaborator;
  the gate only accepts statuses created by `u2giants`.
- **Every provider every release** — cost and time; one cheap real review
  catches the shared-path breakage class this targets.

### 8. Design decisions

Locked (2026-10-19):
- Status contexts: `ai-devops/live-review/linux` and
  `ai-devops/live-review/windows`, state `success`/`failure`, on the exact
  target SHA, creator `u2giants`.
- Default provider `deepseek` (cheapest, API-only, healthy on both OSes).
- Gate applies only when `start_head..target_head` changes a shared review
  path. Other releases are unaffected.
- Driver runs on an Ubuntu review host; Windows leg via `ssh 4837`.

Open (implementer judgment):
- Timeout per leg (start at 900 s).
- Exact fixture content (must be tiny and deterministic).

## Part 3 — How to build it

### 9. Steps

**Step 1 — detector.** In `tools/lib/review-capabilities.sh` add
`review_shared_code_paths_regex` (echo the existing regex) and
`review_shared_code_changed CHANGED_FILES` (0 when any line matches); make
`review_shared_code_rule` use them. Gate: existing review-capabilities tests
pass; new test proves a doors-file change matches and a docs change does not.

**Step 2 — `bin/ai-release-live-check`** (Bash, plus `.cmd` launcher like
`bin/ai-review.cmd`). Subcommands:
- `run --target-head SHA [--provider P] [--json]`: in a `mktemp -d`, create a
  detached worktree of SHA from the current repo (`git worktree add --detach`,
  hooks disabled like `update.sh:163`), build a two-commit fixture repo
  (one-line docstring change), run `PATH=<cand>/bin:$PATH <cand>/bin/ai-review
  P diff-review --base HEAD~1` with a timeout. Pass = exit 0 and the last line
  is an existing report containing a `## Verdict` line with
  APPROVE/REVISE/REJECT. Print one JSON line
  `{os,host,target,provider,ok,verdict,elapsed,detail}`. Always remove the
  worktree.
- `fleet --target-head SHA [--provider P]`: Ubuntu only. Runs `run` locally,
  then on 4837: `git -C C:/repos/ai-devops fetch origin main` and runs the
  **candidate's** script from a detached worktree there (script sent over
  ssh stdin to Git Bash). Posts both statuses with `gh api
  repos/popcre/ai-devops/statuses/SHA`, description = host, provider, verdict,
  EST time. Exit non-zero if either leg failed.
- `verify --target-head SHA`: read statuses (`gh api`, else unauthenticated
  `curl`), newest per context, require both `success` by `u2giants`.
Gate: `ai-release-live-check fleet --target-head <merged SHA>` posts two green
statuses visible at `https://github.com/popcre/ai-devops/commit/<SHA>`.

**Step 3 — install gate.** In `cmd_authorize_install`, after
`refuse_raw_archives`, when `review_shared_code_changed "$(git diff
--name-only start..target)"`, run `"$ROOT/bin/ai-release-live-check" verify
--target-head "$target_head"` and `blocked` with a message naming the fleet
command when it fails. Gate: authorize-install refuses a shared-path release
without statuses, accepts with them.

**Step 4 — tests** (section 10). **Step 5 — docs**: add the gate and command
to `docs/deployment.md` near the `authorize-install` section, and a router row
in `AGENTS.md`. **Step 6 — live proof** on the merged implementation SHA (it
changes `bin/ai-task-gates`, not a shared path, but run `fleet` anyway), link
the commit statuses on #1783.

### 10. Tests

New `tests/test-release-live-check.sh` (offline, fake `ai-review`, fake
`gh`/`curl` on `PATH`):
- `run` passes on a fake report with `## Verdict` APPROVE; fails on exit 0
  with no verdict; fails on non-zero exit; worktree removed in all cases.
- `verify`: both success by u2giants → 0; one missing → 1; success by another
  login → 1; newer failure after older success → 1.
- detector: doors file matches, `docs/x.md` does not.
Must stay green: `tests/test-bin-cmd-launchers.sh`, the existing
`ai-task-gates` suites, and CI `verification-closure`.

### 11. Constraints and gotchas

- Never run the check on EDGE-ALIEN or Envy. `ssh 4837` from al8960ofc loops
  back to itself (memory `4837-is-this-machine`).
- No secrets in arguments or logs; the fixture contains no private code.
- No test override env var may bypass the gate; stub only through `PATH`.
- Windows: CRLF breaks bash scripts — keep LF (`.gitattributes`).
- Branch + PR; merge queue; never push to `main`.

### 12. Access

- `gh` signed in as `u2giants` on hetz. `ssh 4837` works from hetz with
  BatchMode. Provider keys already installed on both hosts (1Password vault
  `vibe_coding`, never by value).

## Part 4 — Landing it

### 13. Definition of done, risks

Done: steps 1–5 merged with CI green; `fleet` posted green linux + windows
statuses for a merged SHA; link on #1783; STATUS table updated; handoff closed.

Risks: 4837 offline blocks shared-path installs (intended — that is the gate;
recovery is bringing 4837 back, not bypassing). Provider outage: rerun with
`--provider muse`. Rollback: revert the gate hunk in `bin/ai-task-gates`.

### Self-audit

1. A fresh session can execute it: goal (§1), hosts and routes (§2), exact
   files and functions (§5, §9), tests by behavior (§10). Yes.
2. Background and dead ends: trigger (§3), rejected options (§7), findings
   (§6). Yes.
3. Goal clear enough to steer: §1 plus locked/open labels (§8). Yes.
