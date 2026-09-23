Paste this into a fresh Codex session.

---

Investigate six leftover Codex work folders that still hold uncommitted changes, then either ship the valuable work or discard it with proof. Albert owns POP Creations; he is not a programmer — report in plain English.

## What these are

Path pattern: `C:\Users\ahazan\.codex\worktrees\<name>\<repo>`

These are Codex working copies (Codex owns them — they live under `.codex\worktrees`; one has a `.codex-worktree-name` marker). They were left behind after earlier sessions ended. A disk cleanup on 2026-09-23 removed 154 clean/empty worktree folders and kept only these six because they still have uncommitted edits.

Source of truth is GitHub. These folders are not. Do not treat them as live until you prove the work is unique and worth keeping.

## The six folders

1. `ai-devops-pr666-resume\ai-devops` — branch `codex/pr666-resume` (ahead 1 of `origin/codex/readonly-private-review-20260920`)
   Dirty: `tests/test-ai-review-lifecycle.sh` (+36 lines)
   Also has a local commit: `9fcc861c` "Route private code reviews through sealed attachment-only exports"

2. `issue-2371-owner-decision-evidence\shared-db` — branch `codex/issue-2371-owner-decision-evidence`
   Dirty: `.agent/contract.json`, untracked `.ai/issue-2371-full-tests.log`

3. `issue-2662-six-views-01a0bc14\shared-db` — branch `codex/2662-six-views-01a0bc14` (behind main)
   Dirty: `.agent/contract.json` only

4. `issue-2876-catalog-row-order-refresh-01a0bc4c\shared-db` — branch `codex/issue-2876-catalog-row-order-refresh-01a0bc4c` (behind main)
   Dirty: `.agent/contract.json`, `docs/verification/throughput-guard-truth-baseline-20260828.json`, `scripts/production_catalog_verification.py`, `scripts/test_production_catalog_verification.py`

5. `issue-3273-resume-01a0bc4c\shared-db` — branch `codex/issue-3273-resume-01a0bc4c` (ahead 1, behind 106)
   Dirty: `.agent/contract.json` only

6. `issue-634-shared-db-rename\ai-devops` — branch `codex/issue-634-shared-db-rename`
   Dirty: 52 files (AGENTS.md, bin/*, config/*, docs/*, tools/*, tests/*, plans) — largest and most likely to be real unfinished work

Canonical checkouts (landing-only, do not edit these for this job): `C:\repos\ai-devops`, `C:\repos\shared-db`, `C:\repos\licensor-source-data`, `C:\repos\poppim-web`, `C:\repos\popdam3`.

## Rules in force

- Start in a uniquely named worktree from current upstream. Verify the branch before every commit.
- Only the agent that opened an issue closes it.
- Never push directly to protected `main`. Work on a branch, open a PR, merge it yourself unless it is DesignFlow (`develop`, never self-merge) or Albert said he wants to review first.
- Documentation-only PRs (every changed file is prose) merge immediately with owner override — do not wait for checks.
- Every GitHub body you post ends with: `Posted by <Claude|Codex> chat <id> on <machine>` (use `unknown` if id empty).
- Do not use `reset --hard` or `clean -fd` over unreviewed work.
- Never delete a dirty copy until every changed file and local commit is proven duplicated, superseded, intentionally disposable, or safely preserved.
- Load `cleanup-worktree` before removing anything. Load `codex-github-ship` / repo AGENTS.md before shipping.
- Shared-db structure changes go through `u2giants/shared-db` branch+PR only. Label every shared-db issue number as orchestrator work or non-orchestrator work.
- Secrets stay in 1Password vault `vibe_coding`. Never put values in chat, args, logs, or commits.
- Waiting is not reporting: hold waits inside the turn. Come back only with a finished result or a real blocker with its verbatim evidence line.

## For each of the six

1. Read `git status`, full `git diff`, and `git log` in that folder. Compare against the same repo on GitHub (open PRs, branch tip, current main).
2. Classify:
   - clean and already on GitHub → safe to remove
   - dirty but the same change is already on GitHub (use `git cherry` / patch compare) → safe to remove, record the proof
   - dirty with unique value → recover: commit on a proper branch, push, open PR, merge per repo rules, verify remote SHA
   - unclear → keep it and say what is unclear
3. Prefer a permanent fix. Do not bundle unrelated abandoned changes just because they share a folder.
4. After a folder is proven empty of unique work, remove that exact folder only (parent must be `C:\Users\ahazan\.codex\worktrees`). Then `git worktree prune` in the related repo.

`.agent/contract.json` changes may be generated evidence rather than source. Do not assume either way — diff them and check whether the same content is already on the branch or main.

## Deliverable

A short plain-English report for Albert:
- what was shipped (with PR/merge links)
- what was discarded and the proof it was already on GitHub or worthless
- what remains and why
- free space recovered

Then delete this workstream's leftover folder(s). Do not leave a folder that still holds unique work without saying so in the report.

## Owner decisions to put to Albert in ONE message before you start

- For any change that is unique but looks abandoned/low value: recommend discard or ship, and ask him to pick. Do not silently drop it.
- If two folders hold competing versions of the same work: show which you recommend and why.
- Already settled: he asked for this investigation; he wants the disk cleaned; he is fine discarding truly disposable leftovers. Do not re-ask those.
