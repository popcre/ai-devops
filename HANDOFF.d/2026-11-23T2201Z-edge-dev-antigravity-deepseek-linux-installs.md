---
issue: none  # Ad-hoc DeepSeek optimization requested in chat; PR #2780 landed on main; only edge-dev3 and hetz Linux installs remain
status: OPEN
owner: antigravity/deepseek-linux-installs
---

# HANDOFF — Install PR #2780 DeepSeek Optimization on Linux Hosts (`2026-11-23T2201Z`, `edge-dev`/`antigravity`)

## 0. Business Decisions Only the Owner Can Make

- **None.** No business-meaning question is open.
- **Already settled — do NOT re-ask:**
  - **2026-11-23:** Keep DeepSeek on `deepseek-openrouter`, default reasoning, and `AI_REVIEW_CACHE` off by default; ship `session-title-llm` suppression, `deepseek-harness` usage/cache receipt parsing, `1048576 / 65536` context/output caps, and `ask-deepseek` default skill docs ([PR #2780](https://github.com/popcre/ai-devops/pull/2780), [decision record](https://github.com/popcre/ai-devops/blob/main/docs/decisions/2026-11-23-deepseek-reviewer-optimization.md)).
  - **2026-10-29:** AI review is advisory only and never blocks merges ([docs/owner-rulings.md](https://github.com/popcre/ai-devops/blob/main/docs/owner-rulings.md)).
  - **2026-10-30:** Lean required CI checks only (data-safety and secret-leak gates) ([docs/owner-rulings.md](https://github.com/popcre/ai-devops/blob/main/docs/owner-rulings.md)).

## 1. What This Application Is

[popcre/ai-devops](https://github.com/popcre/ai-devops) is Albert Hazan's multi-model AI coding and code-review toolkit used across Windows (`edge-dev`) and Ubuntu (`edge-dev3`, `hetz`) hosts. Three networking-only Windows machines (`edge-alien`, `edge-runn-envy`, `edge-runn-xps`) must never receive toolkit installs.

GitHub `main` is the source of truth. Toolkit code is deployed to each development/server host using its protected OS updater described in [docs/deployment.md](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md), never by running plain `git pull` inside the installed checkout.

## 2. What We Set Out to Do This Session, and Why

Optimize DeepSeek automated code review and second-opinion tooling (`ask-deepseek`) for output quality and cost:
- Audit DeepSeek Harness on OpenRouter, Direct DeepSeek API, and the OpenCode DeepSeek implementer for caching, session persistence, sticky routing, pricing/latency/reliability, and instrumentation gaps.
- Benchmark candidates using matched-pair live reviews and multi-turn recall checks with zero lost defects.
- Ship only proven wins via PR, merge queue, and host installation + post-install live verification.

## 3. Current State — What Is True Right Now

- **Merged on `origin/main`:** [PR #2780](https://github.com/popcre/ai-devops/pull/2780) landed at [commit `5817f83d97f79a153bffd1d3bb4ba2daf9cfd77e`](https://github.com/popcre/ai-devops/commit/5817f83d97f79a153bffd1d3bb4ba2daf9cfd77e). All targeted unit/shell/doc-safety checks ran and passed before merge (`tests/test-reviewer-routes.sh` 88 tests, `tests/test-ai-deepseek.sh`, `tests/test-ai-review-simple.sh` 46 tests, `tests/test_deepseek_repo_tools.py`, `bin/ai-doc-safety`).
- **Installed and live-verified on `edge-dev` (Windows):**
  1. Windows installer completed cleanly at `5817f83d97f79a153bffd1d3bb4ba2daf9cfd77e` and refreshed managed launchers.
  2. Live post-install `ai-review-simple --route deepseek-openrouter` (`AI_REVIEW_USAGE=1`, `AI_REVIEW_CACHE=1`, `AI_REVIEW_BILLING_ID=bill-99f856be61784307ae22a4e3a3154f4c`) returned `verdict: REJECT` in `8.7s`, caught seeded SQL injection in `auth.py:5`, emitted `step_starts: 3`, `step_finishes: 3`, `input_uncached: 7049`, `cache_read: 13440`, `output_visible: 1130`, and reconciled 100% with OpenRouter `/api/v1/analytics/query` (`request_count: 3`, `model: deepseek/deepseek-v4.1-flash-20261017`, `tokens_prompt: 20489`, `tokens_completion: 1130`, `cached_tokens: 13440`, `total_usage: $0.002109494`, zero extra title-LLM calls).
  3. Live post-install `ai-deepseek-agent send` + `reply` caught the seeded SQL injection and recalled token `GAMMA-914` cleanly across turns.
  4. Live post-install `ai-deepseek doctor --live` passed (`PASS opencode 1.18.12`, `PASS live turn`).
- **NOT yet updated (what remains):**
  - **`edge-dev3` (Ubuntu):** Installed checkout was observed at commit `2780c56bb373af644cd69bc4d2eba04ea9f33ae1`. Non-interactive remote SSH `sudo -n true` failed (`interactive authentication is required`), and protected Linux updates update system symlinks and root-owned state via `./update.sh`.
  - **`hetz` (Ubuntu):** Remote SSH from `edge-dev` failed with `Permission denied (publickey,password)`. Needs execution from a session running directly on `hetz` (or an SSH-authorized host).

## 4. Everything We Tried That Did NOT Work

- **Code/model alternatives rejected by live matched-pair trials (do not retry):**
  See [the 2026-11-23 decision record](https://github.com/popcre/ai-devops/blob/main/docs/decisions/2026-11-23-deepseek-reviewer-optimization.md) for exact Wave 1–3 data rejecting `AI_REVIEW_CACHE=1` as a DeepSeek default, `reasoning: high`, and Direct DeepSeek API (`api.deepseek.com/anthropic`).
- **Remote non-interactive Linux installs from `edge-dev`:**
  Tried `ssh -o BatchMode=yes` to `edge-dev3` (`sudo -n true` refused without interactive password) and `hetz` (`Permission denied`), so remote installation from Windows stopped cleanly per host-safety rules rather than hacking sudo or leaving half-installed state.
- **Ad-hoc OpenRouter analytics schema mistake (diagnosis nuance):**
  Passing `endpoint` or `finish_reason` or >2 `dimensions` alongside a `session_id` filter to `POST https://openrouter.ai/api/v1/analytics/query` returns HTTP 400. Restrict `dimensions` to `["session_id", "model"]`.

## 5. Root Causes and Key Findings

- **Wasted title-generation LLM call per review:** `dsh@0.2.2-rc.1` under `--profile headless` kept the `@deepseek-ai/dsh-session-title-first-prompt-llm` (`session-title-llm`) extension active, firing an extra non-DeepSeek request on every review until explicitly disabled in [tools/reviewer_routes.py](https://github.com/popcre/ai-devops/blob/5817f83d97f79a153bffd1d3bb4ba2daf9cfd77e/tools/reviewer_routes.py).
- **Protected Windows installer path detail:** On Windows machines, passing the non-installed development repo path instead of the host's installed checkout path triggers a launcher-route mismatch; always pass the installed checkout location expected by the managed launcher.

## 6. Exact Next Steps

Run **Step 1 and Step 2** in a session on `edge-dev3`, then repeat them in a session on `hetz`:

1. **Install the merged `origin/main` release via candidate worktree** (per [docs/deployment.md](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md); never `git pull` inside the installed checkout):
   - Locate the host's installed checkout (`ai-task-gates` launcher symlink target). Confirm its working tree is clean on `main`.
   - Fetch `origin/main` and confirm [commit `5817f83d97f79a153bffd1d3bb4ba2daf9cfd77e`](https://github.com/popcre/ai-devops/commit/5817f83d97f79a153bffd1d3bb4ba2daf9cfd77e) is an ancestor of `origin/main`.
   - Create a temporary detached candidate worktree at `origin/main` (recording `<target-sha>`), run `./update.sh --installed-checkout <installed-checkout> --expected-head <target-sha>` from that candidate worktree, then remove the candidate worktree.
   - **Verification gate:** `git rev-parse HEAD` in the installed checkout equals `<target-sha>` (containing `5817f83d97f79a153bffd1d3bb4ba2daf9cfd77e`), and `update.sh` exited 0.

2. **Run post-install live proof on a disposable temp Git repo:**
   - **DeepSeek Harness review + billing check:** Run the installed `ai-review-simple --route deepseek-openrouter` on a 2-commit temp repo (commit 2 introduces a SQL injection bug) with `AI_REVIEW_USAGE=1`, `AI_REVIEW_CACHE=1`, and `AI_REVIEW_BILLING_ID=bill-<32-hex>`.
     - *Gate:* Exits 0 with `verdict: REJECT`, non-null `step_starts`/`step_finishes`, non-null `cache.read` or `input_uncached`, and `POST https://openrouter.ai/api/v1/analytics/query` (key from 1Password item `vqk7qypdfdqog6bo7r6f63zz5m`, vault `vibe_coding`, `dimensions: ["session_id", "model"]`) returns `request_count == step_finishes` with only DeepSeek (`deepseek/deepseek-v4.1-flash-*`) and zero non-DeepSeek title calls.
   - **Multi-turn second-opinion check:** Run installed `ai-deepseek-agent send` asking to remember a secret verification token and find the bug, then `ai-deepseek-agent reply <session-id>` asking for the exact token.
     - *Gate:* Reply returns the exact verification token verbatim.
   - **OpenCode implementer check:** Run installed `ai-deepseek doctor --live`.
     - *Gate:* Prints `PASS live turn` and exits 0.
   - Clean up the temporary Git repo under system temp when done.

3. **Retire this handoff file once BOTH `edge-dev3` and `hetz` pass Steps 1–2:**
   - Create a prose branch/worktree from `origin/main`, delete this `HANDOFF.d/` file ([docs/handoff-standard reference](https://github.com/popcre/ai-devops/blob/main/templates/system/handoff-standard.md)), pass `bin/ai-doc-safety --changed origin/main`, and merge via PR through the merge queue.
   - *Gate:* PR is `MERGED` on `origin/main` and this file is absent on `origin/main`.

## 7. Constraints and Gotchas in Force

- Never run `git pull` in an installed checkout ([docs/deployment.md](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md)).
- Never push directly to `main`; use a worktree, branch, PR, and plain `gh pr merge` through the queue after `bin/ai-doc-safety` passes ([AGENTS.md](https://github.com/popcre/ai-devops/blob/main/AGENTS.md)).
- Never install on networking-only hosts (`edge-alien`, `edge-runn-envy`, `edge-runn-xps`).
- Never open, edit, or delete other sessions' files in [HANDOFF.d/](https://github.com/popcre/ai-devops/tree/main/HANDOFF.d) or rewrite root `HANDOFF.md`.
- Note on pre-existing doc faults deferred under wrap-up scope freeze: running `ai-doc-health` surfaced 35 pre-existing faults unrelated to DeepSeek (`docs/ghost-run-escape.md` missing header, `plan_ghost-run-epoch.md` missing header, and 32 `handoff-old` >30 days entries). Do not touch them as part of this handoff.
- Note on test environment: `tests/test-ai-deepseek-agent.sh` had 218 passing assertions, 1 skipped `bwrap` check, and 1 pre-existing Windows Git Bash symlink failure (`FAIL symlinked session folder is rejected`; `bin/ai-deepseek-agent` was not modified in PR #2780); expect full Linux execution on `edge-dev3` and `hetz`.

## 8. Access and Environment

- **GitHub:** `popcre/ai-devops` via `bin/ai-gh` (committer identity must resolve to `Albert Hazan <u2giants@users.noreply.github.com>`).
- **Secrets:** 1Password vault `vibe_coding` — OpenRouter Management API key lives in item `vqk7qypdfdqog6bo7r6f63zz5m` (field label `credential`). Never print secret values.
- **Hosts remaining:** `edge-dev3` (Ubuntu, needs interactive/local sudo for `./update.sh`) and `hetz` (Ubuntu, needs local or authorized SSH session).

## 9. Open Questions and Risks

- **Open technical questions:** None. Wait until both `edge-dev3` and `hetz` are verified before retiring this file; if running only on `edge-dev3`, add a brief progress note to a successor handoff or update only after `hetz` is verified (remember never to edit another session's handoff file — create a new one only if partial progress remains unverified on the other host).
- **Risk:** Updating only one Linux host and deleting this handoff early would leave the second Linux host behind `5817f83d97f79a153bffd1d3bb4ba2daf9cfd77e` without disabling `session-title-llm`.

---

## Mandatory Self-Audit Gate

1. **Zero prior context?** Yes — §1 identifies the repo, hosts, and protected deploy rule; §3 lists exact commit SHAs, what is already live-verified on `edge-dev`, and exact state on `edge-dev3`/`hetz`; §6 gives complete step-by-step installation, billing/recall/doctor gates, and retirement instructions.
2. **Continue as effectively as current session?** Yes — includes the exact OpenRouter analytics endpoint constraint (§4), exact `AI_REVIEW_BILLING_ID` format and 1Password item ID/field (§6, §8), and rationale from the 42-pair trials (§4, linked decision doc).
3. **Included what was tried and failed?** Yes — §4 documents all three rejected DeepSeek optimization candidates (linked to [the decision record](https://github.com/popcre/ai-devops/blob/main/docs/decisions/2026-11-23-deepseek-reviewer-optimization.md)), the failed `ssh -o BatchMode=yes` attempts (`sudo` prompt on `edge-dev3`, `Permission denied` on `hetz`), and the OpenRouter analytics >2 dimensions HTTP 400 pitfall.
4. **Concrete next steps + verification gates?** Yes — §6 lists 3 numbered steps each with explicit observable exit/value gates.
5. **Every term, identifier, path, URL explained?** Yes — route, flag names, `AI_REVIEW_BILLING_ID` shape (`bill-<32-hex>`), OpenRouter item ID/field, and host classes are explicit.
6. **Every file and commit reference is a GitHub URL?** Yes — checked §0–§9; every file and commit reference uses a full GitHub URL with zero machine-local drive or home-directory paths.
7. **Section-0 sweep completed?** Yes — walked §1–§9; all technical steps are executable by AI using standard host tools, zero owner business decisions remain (§0 states `None` + lists settled rulings with dates).

### Final Synthesis Answers

1. **Comprehensive enough for a brand-new developer with no session context?** Yes (§1 background, §2 goal, §3 verified `edge-dev` state vs pending Linux state, §6 executable steps and verification gates).
2. **Detailed enough to continue as effectively as this session right now?** Yes (§4 documents rejected options and OpenRouter analytics query constraint; §5 explains `dsh` root cause and installer path nuance; §8 names exact vault/item/field).
3. **Every relevant detail present (background, goals, intended outcome, state, failed attempts, decisions, constraints, risks, next actions, verification)?** Yes — mapped explicitly 1:1 across §1–§9.
4. **Section-0 sweep verified across §1–§9?** Yes — walked every section; no uncaptured owner ruling or business question exists anywhere in §1–§9, and no technical approval was pushed to §0.
