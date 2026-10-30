# Plan — skinny advisory AI review (replaces the old reviewer system)

- **Parent issue:** popcre/ai-devops#2041. Each stage has its own child issue, listed in STATUS.
- **Handoff:** [HANDOFF.d/2026-10-29T2330Z-edge-dev3-claude-skinny-review-plan.md](HANDOFF.d/2026-10-29T2330Z-edge-dev3-claude-skinny-review-plan.md).
- **Supersedes** [plan_simple-reviewer-rebuild.md](plan_simple-reviewer-rebuild.md). That plan's history and REVISION section are kept for background only; **this file is the one to execute**.

## STATUS (read first; do not re-derive)

| Stage | Child issue | State (2026-10-30) | Evidence |
|---|---|---|---|
| 0 Rulings and evidence | — | ✅ done | `docs/owner-rulings.md` (three 2026-10-29 entries); `docs/reviewer-observation-week-2026-10-22.md`; `docs/review-value-by-repo-vs-work-2026-10-29.md`; `docs/reviewer-enforcement-inventory-2026-10-29.md` |
| 1 Base review script and workflow | — | ✅ merged | PR #2044 merge commit on main; live run 40911611071 |
| A Advisory, one rotating reviewer, docs skip, findings issue, auto-fixer | #2070 | ✅ done (2026-10-30) | PR #2058 (ec3432d2), #2089 (e421e28b); live proof https://github.com/popcre/ai-devops/issues/2070#issuecomment-6515908853 |
| B Remove APPROVE requirements from `ai-task-gates` and installers | #2071 | ✅ done (2026-10-29) | PR #2057 (87cd2905); 5-host proof https://github.com/popcre/ai-devops/issues/2071#issuecomment-6510582588 |
| C shared-db merge gate off | — | ✅ done | popcre/shared-db PR #5055 merged (06220e0); proof PR shared-db#5057 merged with no verdict |
| D Instructions, globals and skills rewritten | #2072 | ✅ done (2026-10-30) | PR #2085 (9170814b), ruling #2104 (5bf5ec01); 5-host proof https://github.com/popcre/ai-devops/issues/2072#issuecomment-6513481440 |
| E Installer stages, scheduled jobs, freeze window removed | #2073 | ✅ done (2026-10-30) | PR #2091 (5fc8a414), #2117 (ea60d99b); 5-host proof https://github.com/popcre/ai-devops/issues/2073#issuecomment-6515744637 |
| F Delete old reviewer code and data | #2074 | ✅ done | #2112 d55ba665, #2113 e9239b09, #2131 dd691629, #2139 1f4fb596, shared-db#5118 92133262, #5121 562ad02b; proof issues/2074#issuecomment-6520525203 |
| G Advisory review in other repos + automatic production promotion in shared-db | #2075 | 🟡 merged; real-migration promotion + hold proofs wait for the next shared-db migration PR | ai-devops #2090, #2108; shared-db #5069, #5078; theoracle #276; popdam3 #592; https://github.com/popcre/ai-devops/issues/2075#issuecomment-6514359329 |

**A fresh session starts at stage A,** then B. Re-read each later stage before starting it, because earlier stages can change it.

## Part 1 — Why

### 1. Ultimate goal

Albert (owner, non-technical) wants AI review to **add value without ever slowing work down**.

For ten months, review gates held work for days or weeks. The freeze week, when gates were off, was "the first time in 10 months where things actually got done".

**Done looks like this:**
- Every code or plan change gets one AI reviewer's advice automatically.
- Real problems the reviewer finds get fixed automatically.
- Nothing ever waits on a reviewer, and nothing ever asks Albert to approve.
- Production database changes are promoted by an AI agent automatically, after rehearsal, tests and any review findings are resolved.

**If a step conflicts with this goal, the goal wins.** Stop and record the conflict on #2041.

### 2. What this application is

`popcre/ai-devops` is Albert's AI toolkit: CLI wrappers, safety gates (`bin/ai-task-gates`), installers (`install.sh`, `update.sh`, `bin/install-ai-devops-windows.ps1`), skills and global instructions. It is installed on five machines:
- edge-dev3 (Ubuntu)
- hetz (Ubuntu server)
- edge-dev, 4837 and 916 (Windows)

`popcre/shared-db` holds the shared Supabase database's migrations and workflows. Other repos that use the toolkit include u2giants/theoracle and u2giants/popdam3; DesignFlow repos are out of scope.

CI uses the self-hosted runners `edge-dev3-linux` (1–4), label `ai-devops-linux`. They are GitHub's runner agent installed on Albert's own machine; GitHub bills no Actions minutes for self-hosted runners. The reviewers run there through `opencode`, using provider keys held in runner-local config.

### 3. What triggered this

1. **The observation week** (Oct 22–29; report in `docs/reviewer-observation-week-2026-10-22.md`):
   - 18.5% of reviews were BLOCKED, and 72 runs were lost.
   - Most failures came from our own tooling.
   - The old system is about 60,000 lines.
2. **The full-archive scan** (`docs/review-value-by-repo-vs-work-2026-10-29.md`, 6,128 reviews):
   - The first look catches real problems 25–34% of the time.
   - Repeated final-checks catch only about 11%.
   - Wrong findings are about 1%.
   - Repository is a poor predictor; shared-db is no better than the others.
3. **Albert's rulings on 2026-10-29**, quoted in `docs/owner-rulings.md`:
   - rebuild simply with four reviewers;
   - cut more reviewer fat;
   - review never blocks;
   - he never authorizes production.

### 4. Scope

**In:**
- Stages A–G as listed in STATUS.

**NOT in this plan:**
- New reviewer providers.
- Prompt tuning beyond `templates/review-prompt-simple.md`.
- DesignFlow repos.
- The transcript-store project, which Albert handles in another session.
- Rewriting `opencode` or the vendor CLIs.
- Credit-balance monitoring, beyond recording out-of-credit as "unavailable".

## Part 2 — What we know

### 5. Current state

**On main (merged in #2044):**
- `bin/ai-review-simple` (stdlib Python, under 400 lines). One provider reviews `base...head` through `opencode` in a read-only clone and writes `{provider, head, verdict, findings, elapsed, error}` JSON. It exits 0 on a verdict and 3 when the reviewer is unavailable. The out-of-credit classifier matches 402, 429 and 1113, insufficient balance, rate limit, payment required and "exceeded your current quota" (`bin/ai-review-simple` ~93-97). It returns exit 2 for a refusal such as a head mismatch (`review()` ~327-329). Exit 2 must **not** fall through to the next provider.
- `--combine` mode.
- `.github/workflows/ai-review.yml`, currently the *old* 4-reviewer blocking rule. It refuses to run if `bin/ai-review-simple` is missing on the toolkit ref, so PR code never runs next to the keys.
- Tests `tests/test_ai_review_simple.py`, `tests/test_ai_review_rule.py`, wrapper `tests/test-ai-review-simple.sh`.

**PR #2058** (branch `review-phase-a`, open, CI green):
- rewrites `ai-review.yml` to the advisory, one-reviewer form;
- adds the docs-only skip and the `review-finding` issue;
- adds `.github/workflows/review-fixer.yml` and `tools/ci/review-fixer.sh`;
- updates `bin/ai-review-simple` and its tests.

The fixer runs **Codex** (`codex exec`) on edge-dev3, because Claude's CLI login on edge-dev3 was found revoked on 2026-10-29. Not merged and not live-proven.

**PR #2057** (branch `reviewer-gate-removal-phase-b`, open):
- changes `config/task-gates.json`, its schema, `bin/ai-task-gates`, `.ai-devops/task-gates.json`, `install.sh`, `update.sh`, the Windows installer, and the gate tests;
- CI fails on `windows-offline-section (3, section-self-hosted)`, cause not yet read. The `ai-review` and `Entire Gates` failures were not required checks on 2026-10-29. Re-confirm that against `config/merge-queue-expected.json` before ignoring them.

**shared-db (done):**
- `scripts/check-exact-head-approval.mjs` is no longer called by `merge-queue-gate.yml`, `guarded-migration-merge.yml`, `shared-supabase-migrations.yml`, `designflow-sandbox-migrations.yml` or `shared-db-4060-observation.yml`.
- Workflows `reviewer-start-watch` and `review-verdict-auto-archive` are disabled.
- AGENTS.md, `docs/agents/merge-protocol.md` and the owner-rulings are rewritten.
- Ruleset 25808522 is unchanged: 14 contexts, none review-only. A snapshot is on shared-db#5054.

**Freeze window:**
- `/etc/ai-devops/observation-week.json` (Linux) and `C:\ProgramData\ai-devops\observation-week.json` (Windows) were extended on all 5 hosts to `end: 2026-11-12T14:56:18Z`.
- While it is live, `ai-task-gates` admits code and prose merges unreviewed and prints `MERGE-UNREVIEWED`.
- If stage B is not merged by then, gating returns. Extend the window again rather than let gates return.

**Everything else** in `docs/reviewer-enforcement-inventory-2026-10-29.md` (59 rows) is still live unless STATUS says otherwise.

### 6. Key findings

- **All four reviewers run through `opencode`.** Model and env settings live in `bin/ai-review-simple` (copied from `tools/lib/review-doors/*.sh` and `bin/ai-glm`).
- **Agreement:** Muse agreed with GLM 12/12 and with StepFun 12/13. That is why one reviewer per PR loses little.
- **DeepSeek is slowest** (p90 about 19 minutes) and had lone REJECTs. 3 of its 4 shared-db lone REJECTs were followed by code changes, so they were real catches.
- **GLM emits REVISE, never REJECT.** Treat REVISE the same as REJECT.
- **StepFun** limit is 10 requests per minute. It ran out of credit on 2026-10-29 (402 "exceeded your current quota"), and Albert topped it up that day.
- **The first live review of #2044 by all four reviewers found real bugs:**
  - a crash path skipping the result file;
  - key leaks in findings;
  - PR code able to run beside keys;
  - a slash-branch URL bug.
  This shows review value on new code.
- **The PR-polling hook blocks hand-written `sleep`/loop PR polling.** Use `bin/ai-pr-wait <pr> --timeout-minutes N` in the background.
- **Flaky suites seen:**
  - `test-ai-shared-db-closeout-check.sh` fails when caller env leaks in (`env -i` makes it pass);
  - `test-ai-install-skills.sh` failed once in the merge queue and passes locally.
  Re-run once before debugging.

### 7. Rejected approaches

- **Patching the old system** (#1993, #2000, StepFun heartbeat). Rejected on 2026-10-29: the old layers are the problem.
- **Four reviewers per PR, blocking merge** (the first rebuild design). Albert: "cut more reviewer fat". Too slow.
- **Deciding review by repository** (the 2026-10-13 "shared-db only" rule). The data doesn't support it.
- **Sessions picking their own work type and choosing to send for review.** Unreliable. CI decides from the changed files instead.
- **Owner-authorized production.** Albert is not qualified and must never be asked.
- **Fail-closed when reviewers are unavailable.** It produced owner-override merges anyway. Unavailable now means "no advice this time".
- **Running PR-supplied review code with secrets** (a bootstrap fallback). Removed as a security hole.

### 8. Decisions

**Locked, all 2026-10-29:**
1. Review is advice only and never blocks a merge. The `ai-review` check is success or neutral only, and is never a required check.
2. **One reviewer per PR.** The reviewer is picked by `PR number mod 4` over [muse, glm, deepseek, stepfun]. If it is unavailable, fall through to the next, up to 4 tries.
3. **Runs once,** on `opened`, `reopened` and `ready_for_review`. No re-review on every push.
4. **Docs-only PRs are skipped.** A PR is docs-only only when **every** changed file passes this test: it is `*.md`, or it is under `HANDOFF.d/` or `docs/`, AND it is not named `plan_*.md` or `IMPLEMENTATION-PLAN.md` in any directory. A single non-doc file or plan file means the PR is reviewed. A skipped PR gets a success check titled "review not needed (docs only)".
4a. **What still gates merge:** the required `verification-closure` check (`config/merge-queue-expected.json` ~39) and CI tests on the merged commit. Stage A must confirm that `verify.yml` still runs the test suite on every PR and in the merge queue.
5. **On REJECT or REVISE,** the workflow opens a `review-finding` issue. An automatic fixer agent decides whether each finding is real. Real ones get a fix PR on branch `review-fix/<issue>` that closes the issue. Invalid ones get the agent's reasoning and the issue is closed as not planned. Fix PRs are never reviewed, to prevent loops.
   - **Fixer safety:** findings text is untrusted input.
     - The fixer job runs with no reviewer provider keys: a separate job, with the opencode secrets directory and key env vars unset or unmounted.
     - It may not edit `.github/workflows/**`, `install.sh`, `update.sh`, `bin/install-ai-devops-windows.ps1`, `config/task-gates.json` or `bin/ai-task-gates`, enforced by a step in `review-fixer.yml` that runs after the agent and outside it: `git diff --name-only origin/main...HEAD` against the denylist, refusing to push or open the PR on any match. Run `codex exec` in its workspace-write sandbox with no secrets in its environment; only the workflow step that opens the PR holds `GH_TOKEN`.
     - Its PRs go through normal CI and the merge queue.
     - Closing a finding as "not planned" requires a comment quoting evidence. Such an issue still blocks production promotion for 24 hours after closing.
6. **Production is promoted automatically by an AI agent** when all of these hold:
   - the change is merged;
   - the preview rehearsal passed and cannot be skipped;
   - the tests passed;
   - no blocking `review-finding` issue references the change.

   "References" means an issue labelled `review-finding` whose body contains the PR URL; the workflow writes this. Blocking means open, or closed as not planned within the last 24 hours. The apply job runs this query live, immediately before the apply step, not at merge time.

   **Trigger:** the promotion workflow runs on `push` to main touching migration paths, and hourly on a schedule as a backstop. No session or person starts it.

   **Manual production commands outside that workflow stay refused.** In `config/task-gates.json`, the `production` class's `required` list becomes `automated-promotion-workflow-only`, replacing the reviewer-approval gate. It is never left empty.
   Nothing ever asks Albert.
7. All other reviewer gates, hooks, instructions, installer stages, jobs and code are removed. Safety checks unrelated to review stay: secrets, privacy, worktree guard, install target-identity proof, migration ordering, leases and tests. Stages B and G must list in their PR descriptions which non-review checks they kept.

**Open for the implementer:**
- Fixer engine choice if Codex fails. Claude needs a re-login on edge-dev3; Albert can't type credentials, so prefer Codex.
- Comment formatting.
- The exact timeout per reviewer. Defaults: 20 minutes, 30 for DeepSeek.

## Part 3 — How to build it

### 9. Stages (one PR per stage; one child issue per stage)

**A — Finish and prove PR #2058.**
- Enter the merge queue using the repo's documented command (`gh pr merge 2058 --squash` worked for #2044 on 2026-10-29; check `config/merge-queue-expected.json` first). Wait with `bin/ai-pr-wait 2058 --timeout-minutes 60` in the background.
- Live proof, then delete the throwaway branches and PRs:
  1. A throwaway PR with a planted off-by-one bug in a new test helper gets exactly one reviewer comment and a non-failure check, then a `review-finding` issue, then a fixer PR that passes CI.
  2. A docs-only PR shows "review not needed".
- Delete the `requeue` job (the `sleep 3600` delayed re-run in current `ai-review.yml`) and the `workflow_dispatch` re-run input.
- **Done when:** both proofs are posted on #2070 with run IDs, the requeue job is gone, and a link shows `verify.yml` running the test suite on a PR and in the merge queue.

**B — Finish PR #2057.**
- Read the `windows-offline-section (3)` failure log (`gh run view <id> --log-failed`; strip ANSI). Fix it, or re-run once if it is flaky. Before ignoring any failing check, re-confirm it is not required: today only `verification-closure` is required (`config/merge-queue-expected.json`).
- Merge.
- **Done when:**
  - `ai-task-gates check --before ship` for an installation-class change passes without `--reviewer-approval`;
  - `bash tests/test-ai-task-gates.sh` is green;
  - the change is installed on all 5 hosts, using the normal `update.sh`, or the Windows installer on Windows hosts.

*(Stage C, the shared-db merge gate, is done; see STATUS.)*

**B deadline:** the freeze window ends 2026-11-12 14:56Z. If #2071 is not merged and installed by 2026-11-10, extend the window file's `end` by 14 days on all 5 hosts. The file is `/etc/ai-devops/observation-week.json` on Linux and `C:\ProgramData\ai-devops\observation-week.json` on Windows; the JSON shape is in `tools/lib/observation-week.sh`. Write it with the same privileged mechanism the installer uses for `/etc/ai-devops`. The first step of stage B is to post this dated action and procedure as a comment on #2071, so it does not depend on any one session. Do not let gating return.

**D — Instructions and skills** (inventory rows 17–20 done in shared-db; rows 51–59 here).
- Rewrite `templates/system/CLAUDE-global.md` and `AGENTS-global-codex.md`, plus the mimo and zcode variants: remove "assigned AI reviewers gate technical actions", the `ai-review` / rotation / observation-week paragraphs, and "exact-head APPROVE".
- Rewrite `AGENTS.md` lines about APPROVE.
- Archive `docs/reviewer-rotation-rules.md` and `templates/system/REVIEWER-global.md`.
- Edit the skills in inventory rows 57–59. Keep second-opinion uses, and drop the gate and rotation wording.
- Reinstall the globals on 5 hosts.
- Edit theoracle and popdam3 docs if they mention the gate. Close #1948 and #1996 as superseded, and archive `plan_simple-reviewer-rebuild.md` and `plan_reviewer-observation-week.md`.
- **Done when:** `git grep -iE "exact-head APPROVE|assigned AI reviewer|reviewer-rotation" templates/ AGENTS.md skills/` is empty, and the normal reinstall reports success on 5 hosts.

**E — Installer stages and scheduled jobs** (inventory rows 39–46 and 48).
- Remove the post-merge requalification hook stage.
- Remove the `ai-reviewer-logs-sync` cron.
- Remove the `local-watch` entries.
- Remove the Windows `machine-tools.tsv` rows and the `reviewer-start-watch` config.
- Disable `reviewer-membership-drift.yml`.
- Remove the observation-week block in `bin/ai-task-gates` (~58-92) and `tools/lib/observation-week.sh`.
- Make the normal installer (`install.sh` / `update.sh` and the Windows installer) delete the window file during the normal installer run, so no hand-run privileged command or credential extraction is needed.
- **Done when:**
  - `crontab -l`, the scheduled tasks and the timers on each host show no reviewer jobs;
  - the window file is absent on all 5 hosts;
  - a code PR still merges.

**F — Delete old code and data** (inventory rows 8–13, 47 and 50; leftovers from shared-db stage C).
- In ai-devops, remove `bin/ai-review*` (except `ai-review-simple`), `ai-reviewer-*`, `ai-*-review`, `ai-review-posthoc`, `ai-release-live-check`, `tools/lib/review-doors/`, `tools/reviewer_events.py`, their tests, `.cmd` twins, installer entries, and `verify.yml` `windows-reviewer-safety`.
- In shared-db, remove:
  - `scripts/lib/lanes/review-*`
  - `review-verdict*`
  - the allocator and governed-review scripts
  - `check-exact-head-approval.mjs`
  - `config/owner-no-reviewer-policy.json`
  - `config/review-carry-forward-stored-hashes-v1.json`
- Delete the about 8,900 `refs/db-review-*` refs, after saving their list as a workflow artifact or private gist linked from #2074.
- Fix the production catalog recovery path that still reads a stored verdict, as part of stage G.
- Use one PR per area.
- **Done when:** `git grep -lE "ai-review-engine|review-doors|check-exact-head-approval"` is empty in both repos, and all suites are green.

**G — Roll out the advisory review and automatic production promotion.**
1. Call the reusable `ai-review.yml` and `review-fixer.yml` from popcre/shared-db, u2giants/theoracle and u2giants/popdam3. Runner access for repos outside popcre: check `gh api orgs/popcre/actions/runners`, and register an edge-dev3 runner for the u2giants repos if needed.
2. In shared-db, change production promotion (`shared-supabase-migrations.yml` promotion/apply jobs; `production_apply_review_evidence.py`; `production_review_allowlist.py`; the `OWNER-OVERRIDE` path; workflow `production-apply-review-evidence.yml`) so that an agent-run workflow promotes automatically when rule 8.6 holds. Remove every step that waits for owner authorization or a stored verdict, and the catalog-recovery verdict read.
3. Load the `shared-db-change` skill first, and work on a shared-db issue linked to the G child issue.
- **Done when:**
  - a test proves the preview rehearsal job runs for every promoted change and cannot be skipped;
  - a real shared-db migration PR merges, gets one advisory review, and is promoted to production by the workflow with no human step, with the run ID posted;
  - a planted review finding on a shared-db PR holds that change out of production until its fix merges.

### 10. Tests

- **A:** `tests/test_ai_review_rule.py` covers rotation (PR n mod 4), fall-through on exit 3, NO fall-through on exit 2 (a refusal), never-failure conclusion, and the docs-only classifier: `plan_x.md` is reviewed, `docs/a.md` is skipped, `HANDOFF.d/x.md` is skipped, and `.md` mixed with `.py` is reviewed. `tests/test_ai_review_simple.py` stays green.
- **B:** `tests/test-ai-task-gates.sh`, `test-ai-task-gates-bulk.sh`, `test-ai-task-gates-linux-install.sh`, `test-linux-install-authorization.sh`, `test-task-gates-phase5-acceptance.sh`, `test-windows-source-gate.ps1` assert that no review approval is required, and that the secrets, privacy and worktree gates are still enforced.
- **E/F:** `bash tests/test-all.sh --changed-since origin/main`, plus `tests/test-installer-parity.sh` and `test-workflow-policy.sh`.
- **G:** a shared-db workflow test that promotion is refused while an open `review-finding` issue references the change, refused for 24 hours after a close-as-not-planned, and allowed after a fixed close.
- **Always:** `verify.yml` green; `bin/ai-doc-safety .` for prose.

### 11. Constraints and gotchas

- Use a branch and a PR; never push to `main`.
- Code PRs merge through the merge queue (`gh pr merge N --squash`; `--delete-branch` is refused). Prose PRs may use `--squash --admin` after `bin/ai-doc-safety .`.
- Never use hand-written PR polling loops; a hook blocks them. Use `bin/ai-pr-wait`.
- Commit only as Albert's verified identity (`git var GIT_COMMITTER_IDENT`). Add the co-author trailer.
- Sign GitHub posts with `$AI_GH_SIGNATURE`.
- Quote times in New York time (EDT until 2026-11-01, then EST).
- Secrets stay in 1Password `vibe_coding` only. Never put keys in workflow YAML.
- Never run PR-supplied code on a runner that holds provider keys.
- Set `PYTHONDONTWRITEBYTECODE=1` for tests on edge-dev3.
- shared-db structural work loads `shared-db-change` and is claim-first on its issue.
- Never ask Albert to approve, type, click, or create a credential. If something needs his business judgment, ask in plain words.
- Review-tool changes must never be gated on the review system working.

### 12. Access

- **edge-dev3:** user `ahazan`; runners `edge-dev3-linux*`; checkout `/home/ahazan/repos/ai-devops`.
- **hetz:** `ssh -i ~/.ssh/916-alien root@hetz`; checkout `/worksp/ai-devops`; use `python3`.
- **Windows hosts** edge-dev, 4837 and 916: ssh aliases in `~/.ssh/ai-devops.conf`, PowerShell. On 916 the toolkit is on `D:`.
- **1Password service-account token:** `~/.config/ai-devops/op-service-account`.
- **gh:** authenticated as u2giants.
- **Codex:** on edge-dev3, used by the fixer.

## Part 4 — Landing

### 13. Done when, and risks

**Done when:**
- Stages A–G are ✅ with evidence in STATUS.
- The inventory doc has every row resolved.
- The window file is gone from 5 hosts.
- #2041 and the child issues are closed, each with the `- [ ] live proof` box ticked with a link.

**Risks:**
- **The fixer makes a bad change.** Fix PRs go through normal CI; a bad fix is reverted like any change.
- **Runner capacity.** One review per PR keeps the load low.
- **Credit runs out.** The reviewer falls through to the next, and if all four are out, there is "no advice this time".
- **Automatic production promotion applies a broken migration.** Preview rehearsal and tests still gate it; rollback is a forward-fix migration.
- **Stage B not merged by 2026-11-12.** Extend the window file.

**Uncertain:**
- Whether u2giants repos can use popcre runners. Check in stage G.
- Whether Claude can be re-logged on edge-dev3. Not needed if Codex works.

## Muse critique (2026-10-29)

Muse session `skinny-plan-critique`: REVISE, REVISE, then **APPROVE** in round 3 (2026-10-29). Fixes applied:
- the docs-only rule is now precise;
- the production promotion reference and its live query are defined;
- the fixer has a safety block;
- what still gates merge is stated;
- the B deadline step is added;
- `ai-process-supervisor` is no longer deleted (`ai-pr-wait` uses it);
- the exit-2 no-fall-through rule is added;
- round 2 added: the fixer enforcement step, the promotion trigger, the production gate content, the requeue deletion, the B-deadline procedure, the window removal through the installer, the refs list storage and the exit-2 test;
- the runner, credit and time-zone facts are corrected;
- stage A has two proofs, and D greps the repo.

## Self-audit

1. **Could a brand-new session execute this without asking?**
   - Yes: §5 gives exact state (PR numbers, branches, failing check, window file date).
   - §9 gives files, order and done-when per stage.
   - §11 and §12 give the rules and access.
   - Gap found and fixed: the flaky suites are now named in §6.
2. **Does it carry the background and what was ruled out?** Yes:
   - §3 gives the numbers and their sources;
   - §6 gives findings;
   - §7 gives the rejected approaches;
   - §8 gives the locked rulings with dates.
3. **Is the goal clear enough for judgment calls?** Yes: §1 says "never slows work down; never asks Albert", with the "goal wins" instruction.
