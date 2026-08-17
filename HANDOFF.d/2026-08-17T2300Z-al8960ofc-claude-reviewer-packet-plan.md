---
issue: 34
status: OPEN
owner: claude/reviewer-packet-plan
---

# HANDOFF — reviewer system repair: implementation plan written (2026-08-17 23:00Z, al8960ofc/claude)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None outstanding. Albert asked for an implementation plan and asked specifically
how much of the reviewers' hand-feeding is caused by the restrictions we place
on them. Both are answered. Settled already: Qwen stays out of rotation; #1113 is
application-owned; speed must not weaken exact-head or fail-closed safeguards.

## 1. What this application is

`u2giants/ai-devops` — Albert's toolkit repo, 100% Bash and Markdown, no app, no
database, no CI/CD. It installs and operates the delegated AI reviewer wrappers:
`bin/ai-grok-review`, `bin/ai-glm`, `bin/ai-kimi`, `bin/ai-qwen`, plus the
worktree snapshot helper `bin/ai-review-sandbox`.

## 2. What we set out to do and why

A 24-hour shared-db orchestrator session on 2026-08-16/17 had small reviews
taking 15+ minutes and often returning no verdict at all. The analysis is
[`fix_reviewer_system.md`](../fix_reviewer_system.md), tracked as
[issue #34](https://github.com/u2giants/ai-devops/issues/34). This session
converted that analysis into an executable plan a fresh session can build from.

## 3. Current state

- **The plan is written:**
  [`plan_reviewer-system-repair.md`](../plan_reviewer-system-repair.md). It has a
  STATUS table at the top; every row is `⬜ open`. A fresh session starts at
  Step 1.
- No code was written. No wrapper, config, credential, or binary changed.
- Authored in the worktree
  `C:\repos\ai-devops-worktrees\github-spec-kit-evaluation-35279d` on branch
  `claude/reviewer-system-repair-0dd3c6`. **This branch must be merged to `main`**
  — repo policy is main-only, so the plan should not live on a branch.
- Pre-existing untracked `.ai/` and `docs/claude-remote-control-hardening-v2.md`
  were not touched.
- Root `HANDOFF.md` untouched; it remains the static pointer.

## 4. What failed

Nothing failed this session. The failures being fixed are in
`fix_reviewer_system.md`: Grok burning ~3M tokens across 20 turns with no
verdict; Kimi waiting the full 900s before reporting an exhausted allowance;
GLM dying on worktree boundaries, returning empty turns, and attempting web
search; hand-typed SHAs invalidating evidence.

Do NOT fix any of these by broadening filesystem, shell, or web permissions, by
accepting partial output, or by weakening exact-head binding.

## 5. Root causes

The important finding, and the one that shapes the whole design:

**The reviewers' hand-feeding is caused by `--deny Bash`, not by the
single-folder boundary.** Every reviewer already has full `Read`/`Grep` over the
entire repository directory
([`bin/ai-grok-review:67`](../bin/ai-grok-review#L67),
[`bin/ai-kimi:58`](../bin/ai-kimi#L58)), and the worktree limitation was a real
bug that `bin/ai-review-sandbox` already fixed. What a reviewer cannot do
without a shell is run `git diff` — so it cannot determine *what changed*, which
is the only question a review is about. It has the haystack and no way to find
the needle, so it reads and greps for twenty turns and dies.

**Consequence, and it must not be undone:** the evidence packet is **additive**,
not a replacement. Keep full repository read access. Add a small `.ai-review/`
directory carrying only the shell-derived facts. The plan encodes this in §6a,
in Step 1 item 9, and in test 4 (`reviewer retains read access to files outside
the packet`), specifically so a future session cannot quietly turn the packet
into a sealed room.

Secondary causes: verdict requested last (exhaustion yields nothing); provider
health discovered after assignment; exceptional ceilings became routine budgets;
identity typed by hand; final reviews started before the head was stable.

## 6. Exact next steps

Follow the STATUS table in the plan. In order:

1. Build `bin/ai-review-packet` (hashed sealed packet, additive to repo access).
2. Move base/head SHA derivation into the wrappers.
3. Wire the packet into `ai-grok-review`, `ai-kimi`, `ai-glm` — **and record the
   before/after turn count.** That measurement is the gate on the whole premise.
4. Build `bin/ai-review-preflight` plus quarantine.
5. Cut default budgets to 6 turns / 5 minutes; add the early provisional verdict.
6. Replace generic rotation with failure-specific responses.
7. Build the `ai-review` front door and the performance ledger.
8. Run the 30-review trial and commit the report.
9. shared-db scope enforcement plus the #1097→#1113 regression (independent;
   may run in parallel with 1–8).

Each step in the plan has its own verification gate; do not mark a STATUS row
done without citing an artifact.

## 7. Constraints and gotchas

Preserve read-only tools, exact-head binding, per-repo locks, and fail-closed
behaviour. Do not change `GROK_PERMS` (it is a provider cache key). Kimi tool
names are case-sensitive and fail silently. `grok doctor` is a terminal
diagnostic, not an auth check. No `flock` in Git Bash. Qwen stays excluded. Do
not edit root `HANDOFF.md` or the unrelated untracked files. Full list in §11 of
the plan.

## 8. Access and environment

Repo `C:\repos\ai-devops` on `al8960ofc`. Target branch `main`. `gh` is
authenticated as `u2giants`. Verify `git var GIT_COMMITTER_IDENT` reads
`Albert Hazan <u2giants@users.noreply.github.com>` before the first commit. No
new secrets needed; provider keys are in 1Password vault `vibe_coding` and
1Password reads must be serialised.

## 9. Open questions and risks

Budget numbers (6 turns / 5 min) are provisional until the 30-review trial
validates them. The right set of "pointer" files per packet will vary by repo.
Packets must not grow into repository dumps — the inclusion rule and the 400 KB
split rule are what hold that line. Provider metrics must tolerate absent
token/cost data. #1113's private artifact goes only to the private DesignFlow
Item Master workflow.

## Mandatory self-audit

1. Yes: §§1–3 define the repo, the goal, the deliverable, the tracking issue,
   and the unchanged runtime; §6 gives executable next steps pointing at the
   plan's own gates.
2. Yes: §5 preserves the central finding (shell, not boundary) with `file:line`
   evidence and names the tests that protect it; §4 preserves the measured
   failures and the forbidden fixes.
3. Yes: §§6–9 carry verification gates, constraints, environment, and risks.
4. Yes: the §0 sweep found no unresolved owner decision; settled rulings are
   listed so they are not re-asked.
