---
issue: 829
status: OPEN
owner: zcode/session-sess_34dd43fa (edge-dev) — branch feat/mimo-cli-qualification-829, PR #861
---

# Handoff — finish landing PR #861 (MiMo headless dispatch), then #782 Steps 4–6

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**Blocking (blocks the final live proof and closing #829):**

1. **One-time Xiaomi sign-in.** After PR #861 merges, MiMo headless dispatch needs a
   one-time browser login: run `mimo providers login -p xiaomi` and sign in with your
   Xiaomi subscription account (OAuth in the browser). **Recommendation: do it when the
   next session gives you the exact steps.** If that login screen ever asks for an
   API key instead of account sign-in, STOP — that is pay-per-token billing, which you
   banned (2026-09-25); the manual Desktop path remains and #829 records that verdict.

**Already settled — do NOT re-ask:**

- Subscription-only rule (owner, 2026-09-25): ChatGPT/Codex, Claude, Z.ai GLM, Xiaomi
  MiMo, Kimi, Qwen never via pay-per-token API.
- Luna naming (owner, 2026-09-25): GPT-6 Luna is the target; `gpt-5.6-luna` is the old
  model and the only one the ChatGPT plan accepts today.
- Plans are implementer-agnostic; frontier keeps the verification duty (owner, 2026-09-24).

**Nothing else in this workstream needs the owner.** Steps 4–6 of plan
`plan_model_tier_delegation.md` proceed without him.

## 1. What this application is

`popcre/ai-devops` is Albert's AI DevOps toolkit repo (not an app): it installs and
configures his four AI coding clients (Codex, ZCode, MiMo, Claude) and owns the shared
instruction files they load. The workstream here is **model-tier delegation**
(parent issue #782): frontier sessions (expensive tiers) write plans and hand
mechanical implementation to each harness's cheaper subscription tier, then verify.

## 2. What we set out to do this session, and why

Albert asked (2026-09-25): execute Step 2 of the model-tier plan (write the canonical
delegation sheet), verify the Luna model name, spin up subagents for Step 3 and gap
issues #828 (ZCode) / #829 (MiMo), all so planned work gets done on cheaper tiers.
This wrap-up (2026-09-28) finishes the one item still in flight: landing PR #861.

## 3. Current state — what is true right now

- **Steps 1–3 of the plan are DONE and merged**: Step 1 dispatch-path verification
  (PR #830), Step 2 the sheet `templates/system/model-tier-delegation.md` (PR #844;
  slug corrections #850, #858; ZCode-verdict row update #864), Step 3 the
  byte-identical routing block in all three `AGENTS-global-*.md` (PR #859).
- **#828 (ZCode selector) is CLOSED — impossible today.** No headless model selector
  exists on CLI core 0.16.9 (evidence: ai-devops #828 comment 5837096435). Manual app
  path stands. Retest when a newer core ships a selector.
- **#829 (MiMo) — PR #861 OPEN, code complete, blocked on CI.** Head `03278e22`,
  branch `feat/mimo-cli-qualification-829`, worktree
  `/c/repos/ai-devops/.claude/worktrees/mimo-829` (live, clean tree). Contents: MiMo
  CLI qualified (`mimo 0.1.15` installed via npm), model selector verified
  (`-m xiaomi/mimo-v2.6-flash` parses; probe header `> plan · mimo-v2.6-flash`),
  `--dir` replaces the `--cwd` guess, failed runs exit 0 with error on stderr (the
  wrapper's empty-answer check covers it), bin/ai-mimo STEP 0 updated, D10 → LOCKED,
  20/20 local tests, evidence file, sheet MiMo row updated, subscription-only rule
  with abort condition baked into the wrapper guidance.
- **PR #861 CI state (checked 2026-09-28 ~11:45 AM EDT):** run `36169222840`
  in_progress after a `--failed` rerun. `linux-offline-shard (3)` and `(4)` failed
  **twice** (first run + rerun); `verification-closure` fails only as an aggregator
  (`classifier=failure … linux=failure`); Windows sections passed on the first run.
  The #829 subagent's diagnosis: flaky assertion "unrelated code skips reviewer lane",
  a broken-pipe race, passes locally.
- **Park issue #865 is OPEN and stale** — its wake-by window (2026-09-25 2:45 PM EDT)
  passed over the weekend without the finish landing. Close it when #861 merges.
- Steps 4–6 of the plan are open; the plan STATUS table is current on `main`.

## 4. Everything we tried that did NOT work

1. **`gpt-6-luna` dispatch** — rejected live: "not supported when using Codex with a
   ChatGPT account" (#782 comment 5835941637). Working slug is `gpt-5.6-luna`.
2. **Three ZCode selector routes** — all dead (see #828): no `--model` in the parser;
   config `defaultModelSelection` ignored by `-p` runs; app-server registry has no
   subscription provider. Do not re-walk these before retesting on a newer core.
3. **First #861 CI run** — 4 jobs failed (flake). **`gh run rerun --failed`** — shards
   3/4 failed AGAIN. So "just rerun" is now half-disproven: a second rerun without
   reading the logs is not justified.
4. **Park #865's wake** — never landed the finish (3-day gap, session went idle).
   This handoff + a fresh registered wait is the replacement.
5. **Log fetch mid-run** — `gh run view --job … --log` and the jobs/logs API return
   nothing while the run is `in_progress`. Wait for run completion first.

## 5. Root causes and key findings

- The delegation sheet, plan STATUS, and issues #782/#828 carry the durable
  knowledge; this file only adds the PR #861 finish procedure.
- MiMo trap: **failed runs exit 0** with the error on stderr — scripts checking exit
  codes alone will read failures as success.
- `verification-closure` is an aggregator, not an independent test — it goes green
  when the underlying failures clear.
- Windows lanes on this repo take 7–20 minutes; Linux shards ~5–7.

## 6. Exact next steps

1. Wait for run `36169222840` to complete (a blocker-watch on PR #861 is registered
   by the closing session). **Gate:** `gh run view 36169222840 --repo popcre/ai-devops
   --json status` says `completed`.
2. Read the shard 3/4 failure logs (jobs `109006253844`, `109006253700`). If the
   failure is the known broken-pipe/"unrelated code skips reviewer lane" assertion
   AND the subagent's local-pass claim holds, rerun failed jobs ONCE more:
   `gh run rerun 36169222840 --repo popcre/ai-devops --failed`. If it fails a THIRD
   time, stop rerunning — fix the flake (test or wrapper) in worktree
   `/c/repos/ai-devops/.claude/worktrees/mimo-829`, push. **Gate:** `gh pr checks 861`
   shows no failures.
3. Merge: `gh pr merge 861 --repo popcre/ai-devops --squash`. **Gate:** `gh pr view
   861 --json state` shows MERGED; record the SHA.
4. Comment on #829: result, PR #861 + SHA, and Albert's one-time login step
   (`mimo providers login -p xiaomi`, browser OAuth, abort-if-API-key). Keep #829
   OPEN until the login + a final live flash-dispatch proof. Sign the comment
   `Posted by ZCode chat <id> on edge-dev`.
5. Close #865 with a one-line comment naming PR #861.
6. Remove worktree `mimo-829` and branch `feat/mimo-cli-qualification-829` (PR
   merged ⇒ safe). Use the cleanup-worktree skill.
7. Continue the plan: next open row is Step 4 (pointer updates in
   `CHATGPT-codex-cost-efficient.md` + `implementation-plan-standard.md`), then
   Step 5 (re-adopt globals on edge-dev), then Step 6 (router row, retire the
   2026-09-24 handoff file). Follow `plan_model_tier_delegation.md` STATUS on
   `main`; one step per session; comment each result on #782.

## 7. Constraints and gotchas in force

- Subscription-only rule (see §0) — no API keys for the six providers, anywhere.
- Never guess model slugs or CLI flags; qualify live, quote verbatim.
- Canonical checkout `C:/repos/ai-devops` is landing-only; work in worktrees.
- Docs-only PRs merge immediately `--squash --admin`; code PRs wait on CI via
  `bin/ai-pr-wait` run from a worktree.
- Sheet dispatch-row updates land in the SAME PR as the fix they reflect.
- Human-facing times in EDT with the zone named; sign every GitHub post.
- Do not edit other sessions' `HANDOFF.d/` files (several landed today, e.g. a
  separate MiMo ssh/ACL handoff at 1513Z — unrelated to this work).

## 8. Access and environment

- Machine `edge-dev`, Windows, Git Bash. `gh` authenticated as `u2giants`.
- PR #861 / branch / worktree as in §3. Park issue #865.
- No secrets involved anywhere in this workstream; nothing in 1Password to touch.

## 9. Open questions and risks

- Shards 3/4 may be a real failure masked as flake (twice failed). The logs decide —
  do not merge on hope.
- The Xiaomi login might demand an API key → abort path is documented (§0).
- `main` moves fast today (several merges per hour): rebase PR #861 if GitHub
  reports conflicts before merge.

## (b) Sub-agent record — this session dispatched three

### Agent: Step 3 executor (general-purpose, finished)
- **Asked to do:** plan Step 3 only — byte-identical routing block in the three globals.
- **Actually did:** PR #859 merged (squash 08cba1b4), proofs posted on #782
  (comment 5836229049), STATUS row 3 done, fresh-session pointer → Step 4.
- **Worktree:** finished — removed by the agent.
- **Deliberately did NOT do:** Steps 4–6 (plan discipline), sheet edits.

### Agent: #828 ZCode selector (general-purpose, finished)
- **Asked to do:** implement a headless model selector for ai-zcode or prove impossibility.
- **Actually did:** impossibility verdict with verbatim evidence (#828 comment
  5837096435), closed #828, no code change. Sheet row updated afterward by the parent
  session (PR #864).
- **Worktree:** finished — removed by the agent.
- **Deliberately did NOT do:** wrapper changes, API-key routes (forbidden by the
  subscription-only rule, relayed mid-run).

### Agent: #829 MiMo CLI (general-purpose, finished; landing incomplete)
- **Asked to do:** install the MiMo CLI via the sanctioned route, qualify the model
  selector, land with tests or report impossibility.
- **Actually did:** installed `mimo 0.1.15` (npm), qualified flags, updated
  bin/ai-mimo + D10 + sheet row + evidence, PR #861 (head `03278e22`), 20/20 local
  tests; registered park #865 for the CI finish.
- **Found:** selector exists (`-m xiaomi/mimo-v2.6-flash`); `--dir` not `--cwd`;
  exit-0-on-error trap; auth is the only missing piece (Albert's one-time login).
- **Worktree:** LIVE — `/c/repos/ai-devops/.claude/worktrees/mimo-829` (resumable;
  use it for any fix in step 6.2 above).
- **Deliberately did NOT do:** Albert's login (owner-only), any API key, merge.
