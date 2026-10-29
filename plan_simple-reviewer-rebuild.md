# Plan — simple reviewer rebuild (4 reviewers, run in CI, stateless)

Issue: popcre/ai-devops#2041. Evidence: [docs/reviewer-observation-week-2026-10-22.md](docs/reviewer-observation-week-2026-10-22.md) (#1948).
Handoff: [HANDOFF.d/2026-10-29T1900Z-edge-dev3-claude-simple-reviewer-rebuild.md](HANDOFF.d/2026-10-29T1900Z-edge-dev3-claude-simple-reviewer-rebuild.md).

## STATUS (read first)

| Step | State | Evidence |
|---|---|---|
| 0 Owner ruling recorded | ✅ 2026-10-29 | `docs/owner-rulings.md` 2026-10-29 entry |
| 1 `ai-review-simple` script | 🟡 2026-10-29 in merge queue | PR #2044; live run of all 4 providers on edge-dev3 (actions run 40911611071 artifacts) |
| 2 Reusable CI workflow | 🟡 2026-10-29 in merge queue | PR #2044; four reviewer jobs + combine proven in run 40911611071 |
| 3 Pilot on ai-devops PRs | ⬜ open | — |
| 4 Lift freeze, switch gate | 🟡 superseded by REVISION phases A–E; window extended to 2026-11-12 on 5 hosts | `/etc/ai-devops/observation-week.json` |
| 5 Roll out to other repos | ⬜ open | — |
| 6 Delete the old machinery | ⬜ open (= REVISION phase F) | — |
| REVISION A advisory/skinny workflow | ⬜ open, after #2044 merges | — |
| REVISION B remove ai-task-gates review gates | 🟡 2026-10-29 subagent PR in progress | — |
| REVISION C shared-db merge gate off | 🟡 2026-10-29 subagent issue/PR in progress | — |
| REVISION D–F instructions, installers, delete old code | ⬜ open | inventory doc |

**A fresh session starts at the REVISION section.** Confirm #2044 is merged, then do phase A. Check the B and C PRs before redoing them.


## REVISION 2026-10-29 4:30 PM EDT — "skinny" review (overrides §8 and steps 2–6 where they differ)

**Albert's words (verbatim):** "this past week where i didn't have to deal with reviewer errors was the first time in 10 months where things actually got done ... you need to find a way to cut more reviewer 'fat'."

**Goal (wins over everything below):** review must never slow work down. A review is advice, never a gate.

**Locked rules:**

1. **Advisory only.** The `ai-review` check always ends success or neutral, never failure, and it is never a required check. Findings go in one PR comment. The author session reads the comment and fixes real problems in a follow-up commit or PR. Merging never waits for the review.
2. **One reviewer per PR, not four.** The reviewer is picked by rotation from Muse, GLM, DeepSeek and StepFun (`hash(pr) mod 4`). If it is unavailable, it falls through to the next one, up to 4 tries. Albert's "4 reviewers" ruling is kept: all four are in the pool.
3. **One look per PR.** The review runs on `opened` and `ready_for_review` only, not on every push.
4. **Skip docs-only PRs.** A PR is skipped when every changed path is `*.md` other than `plan_*.md` / `IMPLEMENTATION-PLAN.md`, or is under `HANDOFF.d/`, or is under `docs/`. A skipped PR shows "review not needed".
5. **No reviewer machinery anywhere else.** Delete or disable every gate, hook, instruction, installer stage and scheduled job in the inventory below. `ai-task-gates` keeps its non-review safety checks (secrets, production, owner authorization). Every `*reviewer-approval*` / `exact-head-independent-review` requirement is removed from them.
6. **Production (superseded the same evening; see owner-rulings 2026-10-29 evening).** Albert never authorizes production. An AI agent promotes a merged change automatically once the preview rehearsal and tests pass and every `review-finding` issue for that change is closed. This is the one place a review result is checked. Add it as **phase G:** connect the advisory review to popcre/shared-db, and change its production promotion workflow (`shared-supabase-migrations.yml`, the `OWNER-OVERRIDE` path) to this automatic rule.

**Stopgap in force:** the observation-week window file was extended to 2026-11-12 14:56Z on all 5 hosts at about 4:25 PM EDT on 2026-10-29. Code and prose PRs keep merging unreviewed until rule 5 lands. Delete the window file when rule 5 is done.

**Order of work** (each phase is one PR; review is advisory throughout):

- **A.** Make `ai-review.yml` advisory and skinny (rules 1–4). *Done when:* a code PR gets one reviewer comment and a green or neutral check; a docs PR shows "not needed".
- **B.** Remove the review requirements from `config/task-gates.json` and `bin/ai-task-gates` (inventory rows 22–36 and 41–42). Reclassify the `reviewer-safety` path maps as code (rows 21, 37, 38). *Done when:* `ai-task-gates check --before ship` for an installation-class change passes without `--reviewer-approval`, and `tests/test-ai-task-gates.sh` is green.
- **C.** shared-db: drop the review contexts from ruleset 25808522, and stop the approval step in `merge-queue-gate.yml`, `guarded-migration-merge.yml` and `shared-supabase-migrations.yml` (rows 1–7). Disable the reviewer cron workflows (rows 14–16). This needs the `shared-db-change` skill and its own issue under #2041. *Done when:* a shared-db PR merges through the queue with no verdict recorded.
- **D.** Rewrite the instructions and skills. Edit the globals templates (rows 51–52) and reinstall on 5 hosts. Edit `AGENTS.md` in each repo. Archive `docs/reviewer-rotation-rules.md`. Edit the skills (rows 53–59). *Done when:* `grep -ri "exact-head APPROVE\|assigned AI reviewer" ~/.claude/CLAUDE.md ~/.codex/AGENTS.md` is empty on every host.
- **E.** Remove the installer stages and scheduled jobs (rows 40, 43–46, 48–49). Delete the window file.
- **F.** Delete the old reviewer code (rows 8–13 and 47). This is the old step 6.

**Inventory:** see [docs/reviewer-enforcement-inventory-2026-10-29.md](docs/reviewer-enforcement-inventory-2026-10-29.md). It has 59 rows and is the checklist for phases B–F. Its "could not check" list must be resolved during phase C/E.

## Part 1 — Why

### 1. Ultimate goal

Albert wants every pull request reviewed by AI reviewers automatically and reliably. Nobody should babysit it, wait idle for it, or merge around it.

Success looks like this: a PR opens, and within about 15 minutes four reviewers have each posted APPROVE, REJECT or "unavailable" on the PR. Merge is allowed or blocked by one written rule. No chat session takes part.

**If a step conflicts with this goal, the goal wins.** Stop, and record the conflict on #2041.

### 2. What this application is

`popcre/ai-devops` is Albert's AI toolkit: the reviewer wrappers, the gates, and the installer, used on edge-dev3, hetz, 4837, edge-dev and 916.

- Today a chat session reviews by calling `bin/ai-review <provider>`. That goes through door scripts (`tools/lib/review-doors/<provider>.sh`) that run the reviewer through `opencode` in a sandbox.
- Results are written to `~/.local/state/ai-devops/review-scoreboard/reviews.jsonl` on that machine.
- In `popcre/shared-db`, a further lease, allowlist, budget and provenance ledger also applies (`scripts/run-governed-review.mjs`, `record-review-verdict`, and others).
- Self-hosted Linux CI runners `edge-dev3-linux` (1–4) carry the label `ai-devops-linux`.

### 3. What triggered this

The observation week (Oct 22–29) found:
- 18.5% of reviews BLOCKED, plus 72 runs with no recorded result.
- About 71 blocks caused by our tooling, about 44 by calling sessions, and only about 7 by vendors.
- Sessions idling for 48 minutes or more, lost results, and unreviewed merges.

The review code is about 60,000 lines for "send diff, record verdict", and its churn is accelerating.

Albert's ruling on 2026-10-29: "rebuild it simply, but with 4 reviewers, not 2."

### 4. Scope

**In:**
- One script that reviews a PR head with one reviewer.
- One reusable workflow that runs all four reviewers in parallel and posts results.
- A merge-rule check.
- A pilot run, then rollout to ai-devops, popcre/shared-db, u2giants/theoracle and u2giants/popdam3.
- Retiring the old path.

**NOT in this plan:**
- New reviewers. Grok, Qwen, Gemini, Kimi, Codex and Claude stay out.
- Prompt tuning beyond the one shared prompt.
- DesignFlow repos.
- Production-apply evidence in shared-db (`production_*` scripts). Keep those until a separate decision is made.
- Rewriting `opencode` or the vendor CLIs.

## Part 2 — What we know

### 5. Current state

Nothing has been built yet.

The old path lives in:
- `bin/ai-review`, `bin/ai-review-*` (engine, pool, lifecycle, packet, sandbox, preflight, scoreboard, posthoc, credit-watch)
- `bin/ai-muse`, `ai-glm`, `ai-deepseek*`, `ai-stepfun`
- `tools/lib/review-doors/*.sh`
- `tools/reviewer_events.py`
- `bin/ai-process-supervisor`
- the shared-db scripts listed in §2

The observation-week freeze is still ON. Its window file is on all 5 hosts (see the handoff at `HANDOFF.d/2026-10-29T1416Z-al8960ofc-claude-observation-week-diagnosis.md` §6 step 3 for paths).

### 6. Key findings

- **All four reviewers already run through `opencode`.** That is the shared invocation (see the `opencode)` case in `tools/lib/review-doors/muse.sh` and the same in `deepseek.sh` and `stepfun.sh`; GLM uses `bin/ai-glm`). A single script can drive all four with a model switch.
- **Reviewer quality, from finished verdicts in the week:**
  - Muse agreed with GLM 12/12 and with StepFun 12/13.
  - DeepSeek agreed with Muse 8/13 and had 5 lone REJECTs. Of the 4 shared-db lone REJECTs, 3 led to a changed head before merge, so they were likely real catches, and 1 (eaeb970f, #4648) merged unchanged.
  - GLM never says REJECT; it says REVISE.
- **Speed (p90):** Muse 528 s, StepFun 672 s, GLM 767 s, DeepSeek 1119 s.
- **Vendor limits:**
  - DeepSeek returned HTTP 402 "Insufficient Balance".
  - GLM returned HTTP 429 code 1113 "allowance-exhausted", with a 24-hour quarantine.
  - StepFun allows 10 requests per minute.
- **Our defects that a rebuild removes:**
  - StepFun's 300-second silence kill (31 runs).
  - DeepSeek's supervisor refusals with no reason given (28).
  - The risk-block format BLOCK (12).
  - Lease, allowlist and provenance refusals.
  - Lost durable-store results.
  - Stale-source and identity changes caused by sessions (44).

### 7. Rejected approaches

- **Keep patching the current system** (#1993, #2000, heartbeat, supervisor text). Albert chose a rebuild on 2026-10-29. Those fixes would also leave all the layers in place.
- **Two reviewers.** Albert overruled this. The evidence also shows no reviewer is clearly worse in quality; DeepSeek's lone REJECTs mostly look like real catches.
- **Calling vendor HTTP APIs directly with only the diff.** It loses the reviewers' ability to read the repo and run the tests, which is the main source of real catches. It is kept as a fallback idea only.
- **Reviews run from chat sessions.** Sessions caused about 44 blocks and the idle waiting.
- **Fail-closed when reviewers are unavailable.** In practice this led to owner-override merges anyway.

### 8. Decisions

**Locked (2026-10-29):**
- The reviewers are Muse, GLM, DeepSeek and StepFun.
- Reviews run in CI on the PR head SHA, never in a chat session.
- A verdict counts only if its SHA equals the PR head.
- No leases, budgets, allowlists or provenance ledgers in the review path.
- Each reviewer is retried once, then reported "unavailable".
- REVISE counts as REJECT.

**Default merge rule.** I chose this; it is reversible, and Albert may change it:
- The `ai-review` check passes when at least 2 reviewers APPROVE and no more than 1 rejects.
- A lone REJECT posts a PR comment for the author to read, but does not block.
- If fewer than 2 reviewers finish, the check is neutral ("reviewers unavailable") and the PR may merge with label `unreviewed`. The script queues one re-run 1 hour later.

**Open for the implementer:**
- Exact timeouts. Start at 20 minutes per reviewer, and 30 minutes for DeepSeek.
- Comment formatting.

**Decided 2026-10-29 from the review-value scan**
- Evidence: [docs/review-value-by-repo-vs-work-2026-10-29.md](docs/review-value-by-repo-vs-work-2026-10-29.md).
- Albert handed this decision to the AI.
- **Every repo uses the same rule, shared-db included.** Review is decided by the change, not the repository.
- **One review round per head.** Repeated final-check re-reviews are dropped.

## Part 3 — How to build it

### 9. Steps

**Step 0 — Record the ruling.**
- Add Albert's quote and the locked decisions to `docs/owner-rulings.md`.
- Mark `plan_reviewer-observation-week.md` STATUS as superseded by this plan.
- Done when: the PR is merged.

**Step 1 — `bin/ai-review-simple` (Python, under 400 lines, with tests).**
- Usage: `ai-review-simple --provider {muse,glm,deepseek,stepfun} --repo <dir> --base <sha> --head <sha> --out <json>`.
- What it does:
  - Verifies `git rev-parse HEAD == head`.
  - Builds one prompt from [the simple review prompt template](templates/review-prompt-simple.md), which you create. The prompt holds the diff `base...head` and asks for a final line `VERDICT: APPROVE|REJECT|REVISE` plus findings.
  - Runs `opencode run` with that provider's model or agent (copy the model IDs and env from the existing doors) in a fresh read-only clone, with a wall-clock timeout.
  - Parses the last `VERDICT:` line from the reviewer's own output.
  - Writes `{provider, head, verdict, findings, elapsed, error}` to `--out`.
- Exit code: 0 for a verdict, 3 for unavailable. A 402, 429 or quota error maps to `error:"out-of-credit"`.
- Retry once on a non-credit error.
- Do not import anything from the old `bin/ai-review*`.
- Done when: `tests/test_ai_review_simple.py` passes, and one live run per provider on a small ai-devops PR gives a verdict.

**Step 2 — Reusable workflow `.github/workflows/ai-review.yml`** (`on: pull_request` plus `workflow_call`).
- A matrix of the 4 providers on `runs-on: [self-hosted, ai-devops-linux]`.
- StepFun gets `max-parallel` 1 through a concurrency group.
- Each job runs step 1 and uploads its JSON as an artifact.
- A final `ai-review` job collects the four results, applies the §8 rule, posts one PR comment (a table of the 4 verdicts with findings), and sets its own pass, fail or neutral state.
- Secrets: the provider keys come from runner-local opencode config, as today. Never put keys in workflow YAML.
- Done when: a test PR shows four reviewer jobs and one `ai-review` result.

**Step 3 — Pilot.**
- Run on 5 or more real ai-devops PRs.
- Compare against the old path where it still runs.
- Measure finish rate (target 95% or more of reviewers return a verdict) and time (target 25 minutes or less).
- Done when: the measurements are posted on #2041 with run IDs.

**Step 4 — Lift the freeze and switch the gate.**
- Delete the window file on all 5 hosts (earlier handoff §6 step 3).
- Make `ai-review` a required check in the ai-devops ruleset.
- Change the globals and `AGENTS.md` review instructions to: "open the PR; CI reviews it; do not run reviewers yourself."
- Post freeze-end notes on #1948, #1783, #1822 and #1678.
- Done when: `ai-task-gates check --before ship` no longer prints `MERGE-UNREVIEWED`, and a PR merges on a green `ai-review` check.

**Step 5 — Roll out.**
- Call the reusable workflow from popcre/shared-db, u2giants/theoracle and u2giants/popdam3.
- These repos need the runners at org level, or their own runner registration on edge-dev3. Check `gh api orgs/popcre/actions/runners` first.
- In shared-db, change the merge path to use `ai-review` instead of the lease ledger. That is a `shared-db-change` (load that skill), on its own issue under #2041.
- Done when: each repo has one PR merged on `ai-review`.

**Step 6 — Delete the old path.**
- Remove the files in §5, their `.cmd` twins, tests, installer entries and skills (`ask-muse`, `ask-glm`, `stepfun`, `deepseek-second-opinion`). Keep only what is needed for ad-hoc second opinions, if Albert still wants that.
- Do this one PR per area, after 7 days of step 4 with no fallback to the old path.
- Done when: `git grep -l ai-review-engine` is empty and the suites are green.

### 10. Tests

`tests/test_ai_review_simple.py`:
- Parses the last VERDICT line.
- Ignores a VERDICT line that appears inside the diff text.
- Maps 402 or 429 to out-of-credit.
- Head mismatch gives a refusal.
- A timeout gives unavailable.
- Retry happens once.

`tests/test_ai_review_rule.py`:
- 2 APPROVE + 1 REJECT passes.
- 1 APPROVE + 2 REJECT fails.
- 1 finished gives neutral.
- REVISE counts as REJECT.

The existing `verify.yml` must stay green.

### 11. Constraints and gotchas

- The verdict must come from the reviewer's output, never be injected by a script. A scripted "STEPFUN-OK / APPROVE" happened before.
- Pin the base to the PR's merge-base, not the moving `origin/main`.
- Set `PYTHONDONTWRITEBYTECODE=1` on edge-dev3 for the tests.
- Sign GitHub posts with `$AI_GH_SIGNATURE`.
- Commit as Albert's verified identity.
- Use a branch and a PR; never push to `main`.
- Quote times in EDT.
- During the freeze (until step 4), changes to reviewer-safety or installer code need the freeze lifted. Steps 1–3 add new files only and do not touch installed code.

### 12. Access

- **edge-dev3:** this machine; its runners are `edge-dev3-linux*`.
- **opencode provider config:** already on edge-dev3, from the current doors.
- **Secrets:** 1Password `vibe_coding` only.
- **gh:** authenticated as u2giants.

## Part 4 — Landing

### 13. Done when, and risks

**Done when:**
- Steps 0–6 are merged.
- `ai-review` is required in 4 repos.
- The pilot numbers are posted.
- The freeze is lifted on 5/5 hosts.
- Old code is deleted.
- #2041's live-proof box is ticked with a PR link.

**Risks:**
- **Runner capacity:** 4 reviews per PR on 4 runners. Add runners or a queue limit if the wait exceeds 30 minutes.
- **Vendor credit runs out:** the check goes neutral and the PR is not blocked. Add a daily balance check later, as a separate issue.
- **Rollback:** remove the required check. The old path stays until step 6.

## Self-audit

1. **Could a fresh session execute this with no questions?** Yes.
   - §2 and §5 give the paths.
   - §9 gives the files and done-when for each step.
   - §8 fixes the rule.
   - Gap fixed: the runner reach for other repos is noted in step 5.
2. **Does it carry the background and what was ruled out?** Yes: §3, §6 and §7 cover the numbers, the quality evidence and the rejected options.
3. **Is the goal clear enough for judgment calls?** Yes: §1, with the "goal wins" instruction.
