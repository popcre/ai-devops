---
issue: 1962
status: OPEN
owner: unclaimed — next session claims on the owner issue
---

# Seafile toolkit sync blocked on GLM REVISE (release 54840353)

## 1. Goal
Bring the Seafile machine (installed checkout at the machine's canonical
ai-devops path) up to the 2026-10-21 merged rules and finish every
`sync-dotfiles` step, ending with grep proof that the live Claude and Codex
global instruction files contain the new rules.

## 2. Current state
- Seafile is still on `94ef5b0d`. Nothing was installed.
- Target release `54840353952b11b72cf124ac452d7abc5b76575a` (origin/main at
  2026-10-22 ~10:10 PM EDT, 10/21) received **VERDICT: REVISE** from GLM, the
  only usable rotation reviewer on Seafile.
- Step 2 wiring (token file, both MCP launchers, `mcp.env` matching the
  example, shell rc sourced, zero plaintext `ops_` tokens in Claude/Codex
  configs) was checked and is current.
- Steps 1b, 1c, 2b, 3–9 were NOT run.

## 3. Blocking defects (from GLM's report)
- M1 — https://github.com/popcre/ai-devops/issues/1962 : the Claude
  permission `deny:Bash(sleep:*)` blocks every `sleep`, contradicting the
  guard-hook test that allows a lone `sleep`; installed entries are never
  removed automatically.
- M2 — https://github.com/popcre/ai-devops/issues/1965 : `ai-pr-wait` now
  defaults to 60 minutes, silently repealing the #1183 explicit-deadline rule
  still stated in AGENTS.md and the plan.

## 4. What was tried
- Installed `ai-review` failed: it calls `ai-review-pool`, which the old
  install does not provide (`/usr/local/bin/ai-review-pool: No such file`).
  Workaround used: the target candidate's own `bin/ai-review`.
- A short base SHA was refused by `ai-review-packet`; use the full SHA.
- Muse cannot run on Seafile: Muse Code pin not installed, no model catalog,
  no protected key store (`AI_MUSE_CALLER=claude ai-muse doctor`). DeepSeek
  and StepFun also report `local-doctor-failed`.
- The route in https://github.com/popcre/ai-devops/blob/main/docs/deployment.md
  has no provision for reusing another machine's APPROVE (Hetz installed the
  same head on a Muse APPROVE).

## 5. Next actions
1. Fix M1 and M2 in one PR per issue (or together), merge.
2. On Seafile: fetch, create a clean detached candidate worktree at the new
   merged SHA, `ai-task-gates start --class reviewer-safety`, run the
   candidate's `bin/ai-review glm final-check --base <full installed SHA>
   --assert-head <full target SHA> --implementer <engine>`.
3. On APPROVE: follow the pinned Linux route (`authorize-install`, then
   candidate `./update.sh --installed-checkout <installed> --expected-head
   <sha> --reviewer-approval <report>`).
4. Run the remaining `sync-dotfiles` steps; prove with
   `grep -c "<new rule phrase>"` on both live instruction files.

## 6. Verification
Both grep counts are 1; `ai-review doctor` no longer errors on the pool;
issues 1962 and 1965 closed with live proof ticked.

## 7. Workspace left behind
A detached candidate worktree at `54840353` on Seafile holds the GLM report
under `.ai/reviews/`; safe to remove once a new candidate exists.

## 8. Risks
Installing M1 as-is would add a sticky deny to every machine's Claude
settings; Hetz already has it and will need a manual removal path.

## 9. Owner
Unassigned. Posted by Claude chat 35f61f09-ec23-41a9-810d-d94afa55a5fb on Seafile.
