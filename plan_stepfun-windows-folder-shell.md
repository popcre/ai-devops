# IMPLEMENTATION PLAN — StepFun Windows folder + test shell (2026-09-30)

## 1. The ultimate goal — what we are trying to achieve

StepFun Step 5 runs on edge-dev Windows again, as a reviewer/implementer whose
turn is confined to a disposable review folder, with shell allowed only to run
the project's tests inside that folder. Linux keeps today's bubblewrap guarantee
unchanged. Residual Windows risk (absolute host paths may still be reachable
through shell escapes) is named and owner-accepted — it is not claimed as
rule-11 equivalent. Issue: popcre/ai-devops#1169.

If any step below conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`popcre/ai-devops` — Albert's public recovery toolkit. This change touches the
StepFun reviewer wrapper (`bin/ai-stepfun`), its shared skill, reviewer
registry/membership config, rotation rules, offline tests, and a live isolation
proof under `tests/verification/`. Work happens on a branch cut from
`origin/main` in a dedicated worktree; never edit a shared checkout.

## 3. What triggered this work

- #1169: stale pre-#1086 install ran StepFun on Windows unsandboxed.
- Owner Albert (MiMo chat, 2026-09-30): this PC cannot run WSL (RAM maxed by
  ZCode, MiMo Desktop, Claude). After the risk was explained in plain language,
  he chose **"folder + test shell."** — explore the review folder freely and run
  tests inside it; accept the residual exposure in writing.

## 4. Scope — in and out

In: Windows path for `ai-stepfun` via pinned OpenCode; folder confinement;
test-only shell; cleared env + redirected HOME; docs/skill/registry/tests;
live proof on edge-dev; #1169 closeout.

NOT in: WSL or bubblewrap on Windows; weakening the Linux bubblewrap path;
StepCode on Windows; allocator membership changes beyond the existing
out-of-allocator listing; restoring `bin/setup-opencode-stepfun.ps1` verbatim
from backups (reference only).

## 5. Current state of the code

`origin/main` @ `93ff6e48` (worktree `C:/repos/ai-devops-wt-stepfun-win`,
branch `stepfun-windows-folder-shell`). `bin/ai-stepfun` refuses non-Linux with
`unsupported-platform` (#1086). Skill/docs/registry record Ubuntu-only +
bubblewrap. `config/opencode-stepfun/` remains for the Linux OpenCode fallback.
Backups of the old Windows setup live outside the repo
(`/c/repos/reviewer-install-untracked-backup-2026-09-30/`) — reference only.

## 6. Key findings and root cause

- Rule 11 isolation = bubblewrap mount namespace (paths unreachable). Windows
  has no bubblewrap. Cleared env + HOME redirect is **not** equivalent.
- Owner cannot use WSL (RAM). So Windows cannot meet rule 11 as written.
- Owner chose a **narrower** product guarantee: folder + test shell, residual
  risk accepted 2026-09-30 (quoted in §8). Rule 11 text must gain an explicit
  Windows exception so docs stop promising what Windows cannot deliver.

## 7. Approaches considered and REJECTED, and why

| Approach | Why rejected |
|---|---|
| WSL2 + bubblewrap | Owner: PC RAM maxed; WSL not viable (2026-09-30). |
| Windows Sandbox / VM | Too heavy on this host; same RAM constraint. |
| Claim env-clear + HOME redirect = rule 11 | False. Absolute paths and named pipes remain. |
| Packet-only (no tools) | Owner chose folder + test shell instead. |
| Full shell with no confinement | Too wide; not the owner's choice. |
| Restore #1049 Windows path verbatim | Unsanbox'd; caused the #1169 drift. |

## 8. Design decisions already made (dated)

- **LOCKED (owner 2026-09-30, Albert chat): "folder + test shell."** Quote for
  the decision trail: *folder + test shell.* Meaning as presented and accepted:
  StepFun may explore the review folder and run tests via shell inside that
  folder; it is not promised host-credential unreachability.
- **LOCKED:** Linux bubblewrap path unchanged; Windows never claims bubblewrap.
- **LOCKED:** One reviewed PR; design review before landing code; live proof
  from inside a real Windows turn before #1169 close.
- **OPEN:** Exact shell-guard strictness (denylist of credential paths vs
  allowlist of test runners) — implementer picks the stronger practical guard
  and proves it in the live turn.

## 9. The plan — numbered, ordered steps

### Phase A — Plan and design review
1. Land this plan on the worktree branch. Verify: file exists at repo root and
   STATUS table below is filled.
2. Independent exact-head design review (`ai-review` / assigned reviewer).
   Verify: APPROVE of the plan head before any code commit.
3. `bin/ai-task-gates check --before review` then before wait/merge later.

### Phase B — Wrapper and isolation
4. `bin/ai-stepfun`: on Windows allow OpenCode engine; refuse StepCode;
   implement per-run profile dir, cleared environment (strip SSH/gith credential
   agent, `GH_TOKEN`, `GITHUB_TOKEN`, `OP_SERVICE_ACCOUNT_TOKEN`, `DOCKER_*`,
   `GIT_*` auth), `HOME`/`USERPROFILE` redirected to a fresh per-run dir, cwd =
   disposable review copy, remote-less. Linux path unchanged (bubblewrap still
   required).
5. Windows shell gate: wrap `bash`/test execution so shell work is rooted at the
   review folder; deny known credential locations (SSH dir, gh/git credential
   files, 1Password token file, Docker pipe) with a clear refusal message. This
   is best-effort and must be labeled as such in code comments and docs.
6. Tool profile: `read,grep,find,ls,bash` for review/ask inside the folder;
   `implement` keeps write/edit in the disposable clone. No OpenCode MCP that
   can reach 1Password or Docker.

### Phase C — Docs and registry
7. `docs/reviewer-rotation-rules.md` rule 11: keep Ubuntu bubblewrap text;
   add Windows exception citing owner 2026-09-30 "folder + test shell" and the
   residual risk. Do not say Windows is rule-11 equivalent.
8. `skills/shared/stepfun/SKILL.md`, `docs/config-inventory.md` StepFun row,
   `config/reviewer-registry.json`, `config/reviewer-membership-scope.json`,
   `config/provider-cli-versions.json` as needed — Windows allowed with the
   named weaker guarantee.
9. Fix the wrong #1091 citation wherever this work records history: the
   Windows refusal / mandatory bubblewrap is **#1086**.

### Phase D — Tests and proof
10. Offline: extend `tests/test-ai-stepfun.sh` for Windows selection, env
    strip, HOME redirect, shell-guard refusal, and "Linux still requires
    bubblewrap" regression. Register any new suite in `config/ci-suites/`.
11. Live isolation proof on edge-dev (Git Bash, not WSL): from inside a real
    `ai-stepfun ask`/`review` turn, attempt reads of credential paths and the
    Docker pipe; record pass/fail of each attempt plus a normal review still
    working. Save under `tests/verification/` with run/turn evidence.
    If an attempt **succeeds**, record it as residual risk (owner-accepted) —
    do not hide it and do not silently weaken further.
12. PR with plan + code + proof pointer; `bin/ai-pr-wait`; merge per
    `config/repository-policy.json`.

### Phase E — Install and closeout
13. Refresh `C:/repos/ai-devops-reviewer-install` to new main so it cannot
    drift ahead of policy. Re-run `ai-review-preflight status stepfun` and one
    live Windows turn as final proof.
14. Comment the decision trail on #1169 (owner quote + date), evidence links,
    residual risk sentence, close it. Sign every GitHub post.

## 10. Tests required

- `tests/test-ai-stepfun.sh` (extended) must pass on Windows Git Bash and Linux.
- Existing `tests/test-all.sh --windows-offline` / reviewer-safety membership
  must stay green; new suites registered in `config/ci-suites/` if added.
- Live proof record under `tests/verification/` (phase D step 11) is required
  before close.

## 11. Constraints, standing rules, and gotchas in force

- Never push to `main`; branch + PR + merge queue.
- `git var GIT_COMMITTER_IDENT` must show Albert's identity before commit.
- Reviewer-safety class: independent review before merge (`ai-review`).
- No secrets in chat, argv, logs, commits. Never print credential contents —
  only "read succeeded/failed".
- PowerShell/Git Bash compatibility; run bash tests through Git Bash on
  Windows (`C:\Program Files\Git\bin\bash.exe` — system `bash` is WSL stub).
- Do not weaken Linux bubblewrap. Do not claim Windows equals rule 11.
- Sign GitHub: `Posted by MiMo chat <id> on edge-dev`. Times in EST/EDT.

## 12. Access and environment

- Host: edge-dev Windows. Git Bash. No WSL distro installed; do not use it.
- Worktree: `C:/repos/ai-devops-wt-stepfun-win` branch
  `stepfun-windows-folder-shell`.
- GitHub via `bin/ai-gh` only.
- StepFun key store already exists for live turns (`ai-stepfun store-key` path);
  live proof may use a real StepFun turn. 1Password titles only in docs.

## 13. Definition of done + risks and open questions

Done when: PR merged on `origin/main`; live proof recorded; install refreshed;
#1169 closed with owner quote and residual-risk sentence; Linux tests still
pass.

Risks: shell escapes can still reach host absolute paths (accepted); OpenCode
tool profile may need iteration on Windows path mapping; stale installs on
other machines if only edge-dev is refreshed.

Open: none that block start — residual-risk wording is fixed by §8.

## STATUS

| Step | Status | Evidence |
|---|---|---|
| 1 Plan written | DONE | this file, 2026-09-30 |
| 2 Design review | OPEN | |
| 3 Task gates | DONE (start) | class reviewer-safety, base 93ff6e48 |
| 4 Wrapper Windows isolation | OPEN | |
| 5 Shell guard | OPEN | |
| 6 Tool profile | OPEN | |
| 7 Rule 11 Windows exception | OPEN | |
| 8 Skill/docs/registry | OPEN | |
| 9 #1086 citation fix | OPEN | |
| 10 Offline tests | OPEN | |
| 11 Live isolation proof | OPEN | |
| 12 PR merge | OPEN | |
| 13 Install refresh | OPEN | |
| 14 #1169 close | OPEN | |
