Paste this into a fresh session working on `popcre/ai-devops` (local `C:\repos\ai-devops`).

---

Stop AI review sandboxes from copying full Git history. Albert owns POP Creations and is not a programmer — report in plain English.

## Problem

Every review copies a **full repository including `.git` history** into
`C:\Users\ahazan\.local\state\ai-devops\review-sandboxes\<name>`
(junction to `D:\ai-data\local\state\ai-devops\review-sandboxes`).

On 2026-09-23 that held **3,950 copies / ~192 GB** and nearly filled the C drive. Each copy is ~50–80 MB mostly because of history a reviewer never reads. The copy's own `AI-REVIEW-SANDBOX.md` already says it is disposable and should be deleted when the review ends — deletion was never enforced either.

**Albert's ruling:** a review does **not** need full Git history. It needs the files at the review revision + the patch under review.

## Your job (this prompt is ONLY the full-history waste fix)

Change sandbox creation so a review snapshot is small and has no full history.

1. Find the real copy site(s). Start with `bin/ai-review-sandbox`, `bin/ai-review-packet`, `bin/ai-review`, and grep for `review-sandboxes`, `git clone`, `AI-REVIEW-SANDBOX`.
2. Replace full clone/copy with a **small snapshot**:
   - Export tracked files at the review revision (e.g. `git archive`). **No `.git` directory.**
   - Write `patch.diff` (the diff under review) into the snapshot root.
   - Keep `AI-REVIEW-SANDBOX.md` and `.ai-review-sandbox`, and say in the banner that the run must delete this directory before returning.
   - Copy untracked files only if the caller passes an explicit allowlist. Never blind-copy the worktree.
3. If a wrapper truly needs `git` inside the snapshot, use `--depth 1` for that wrapper only — not full history. Grep `bin/` for `git log|rev-list|cat-file` and explain every hit in the PR.
4. Target: typical snapshot **under 50 MB**, creation **under 10 seconds** on EDGE-DEV.

## Do NOT do in this task

- Self-delete traps / orphan sweeps / daily-task changes — that is `plan_agent-self-cleanup.md` Phases 2–4. Only Phase 1 (shrink the copy) here unless you finish early and Albert says continue.
- Do not delete the six dirty leftover work folders (`C:\Users\ahazan\.codex\worktrees\...`). Separate session.
- Do not move more folders to D:.
- Do not touch `u2giants/shared-db` structure.
- Do not rewrite root `HANDOFF.md`.

## Full plan

Read `plan_agent-self-cleanup.md` in this repo (Phases 1 is this task). Keep its STATUS table updated.

## Rules in force

- Work in a **new worktree** from current upstream. Do not edit `C:\repos\ai-devops` landing checkout for this work. Verify `git status --short --branch` before every commit. `git var GIT_COMMITTER_IDENT` must show `Albert Hazan <u2giants@users.noreply.github.com>`.
- Never push to protected `main`. Branch → PR → **you merge it** (Albert does not merge). Documentation-only PRs (every changed file is prose) merge immediately with `gh pr merge --squash --admin` — do not wait for checks. If any file is code/script/workflow, normal checks apply.
- Every GitHub body ends with: `Posted by <Claude|Codex> chat <id> on <machine>` (`unknown` if id empty).
- Load `cleanup-worktree` before deleting any folder. Never `reset --hard` / `clean -fd` over unreviewed work.
- Secrets stay in 1Password vault `vibe_coding`. Never put values in chat, args, logs, or commits.
- Waiting is not reporting: hold waits inside the turn. Come back only with a finished result or a real blocker with its verbatim evidence line.
- Only the agent that opened an issue closes it.

## Tests to add (names)

- `tests/test-ai-review-snapshot-has-no-git.sh` — snapshot has `patch.diff` + marker, and no `.git`.
- Size/time smoke check in that test or a sibling: snapshot well under 100 MB for a real worktree.

Run the repo's existing test entrypoint too (see `tests/`, e.g. `test-ai-review-lifecycle.sh`). Keep it green.

## Definition of done

- PR merged to mainline with the snapshot helper + wrapper update + named tests green in CI.
- One dry-run proof in the PR: `test ! -e "$SNAP/.git"` and `du -sh "$SNAP"` result pasted in.
- STATUS table in `plan_agent-self-cleanup.md` updated (done rows cite commit SHA or test path — never a bare count).
- Short plain-English report for Albert: what changed, proof, what is still open.

## Owner decisions to put to Albert in ONE message before you start

- If you find a wrapper that cannot work without real Git history: say which, recommend `--depth 1` vs keeping that one full, and ask him to pick. Do not silently keep full history.
- Already settled: no full history; self-cleanup is a separate task; daily sweep stays as backup; do not touch the six dirty work folders. Do not re-ask those.
