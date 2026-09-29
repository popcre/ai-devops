---
issue: 1060
status: OPEN
owner: mimo/sandbox-digest-full-index
---

# HANDOFF — digest fix PR, Jev skill, process-mining plan (2026-09-29)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put this WHOLE list to Albert in ONE message before starting work.

**Blocking**
- None blocks the digest-fix PR itself. Independent exact-head review is required before merge (reviewer-safety path) — that is a process gate, not an owner decision.

**Wrong guess is recoverable**
1. **Re-cut the process-improvement plan or drop it?** GLM verdict was REVISE: keep three items (bounded preflights, pin-only qualification, CI queue/cost visibility); fold the rest into existing plans (#658, #650, #131, live-proof-session-sizing, BlockerWatch). **Recommendation: accept GLM's cut; do not add a 40th plan file.** Blocks: whether any new `plan_process-improvements.md` is written. Owner has not ruled yet.
2. **Land PR #1060 after independent review?** **Recommendation: yes.** Blocks: every future Muse/Grok/GLM packet build on machines with shallow snapshots.

**Not in this workstream, nobody on it**
3. **Muse/Grok packet failures on edge-dev** (incidents `20260929T125838Z-edge-dev-muse-1961321`, `20260929T130211Z-edge-dev-grok-1989270`) should be closed only after #1060 is installed and a live packet build is proven. **Recommendation: keep open until then.**

**Already settled — do NOT re-ask**
- Jev is advisory only; never opens gates (plan_typesafe-jev-decision-layer.md).
- Albert explicitly asked for GLM critique (2026-09-29) despite GLM being out of rotation — that one-off is done.
- TypeSafe key stays in 1Password `vibe_coding` / `typesafe.ai API` / field `credential`; never print.

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery and operating toolkit for a multi-model AI workflow: wrappers (`ai-glm`, `ai-grok-review`, `ai-gemini`, `ai-muse`, …), reviewer evidence tools (`bin/ai-review-sandbox`, `bin/ai-review-packet`), task gates, skills, and install scripts. Not an app or database. GitHub `main` is protected; work lands via branch + PR + merge queue. Installation from this repo is deployment. This session ran on Windows host `edge-dev` from `C:\repos\ai-devops` (canonical, landing-only; task work in worktrees).

## 2. What we set out to do this session, and why

1. **Classify private chat transcripts** (last 3 weeks under `C:\Users\ahazan\Dropbox\ai\chat_transcripts`) with TypeSafe Jev, drop those clearly unrelated to AI DevOps failures/slowness, and mine the remainder for process improvements in this repo.
2. **Critique that improvement plan** with Muse, then (after Muse failed) Grok, then (after packet failures) GLM; update the `jev-transcript-classify` skill with what worked.
3. **Land the snapshot-digest fix** as a PR and get Gemini to review the plan + GLM cut from a clean worktree.

## 3. Current state — what is true right now

**Done and verified**
- Jev classified 1,346 unique session digests (from ~2,079 files). 40 discarded at confidence >90% not-related; 1,306 remainder. Scratch: `%TEMP%\jev_digests.jsonl`, `jev_classified.jsonl`, `jev_remainder.jsonl`.
- Subagent deep-read 22 transcripts and wrote 9 ranked process improvements: `%TEMP%\jev_process_improvements.md` (also presented in chat).
- Skill `C:\Users\ahazan\.config\mimocode\skills\jev-transcript-classify\SKILL.md` rewritten with archive layout, batching, polarity, privacy, and what not to do. Locales already present.
- GLM critique completed (session `jev-plan-critique-20260929`, model glm-5.3). Verdict **REVISE**. Report: `C:/repos/ai-devops/.ai/reviews/glm-jev-plan-critique-20260929-b33a60737869a5b249f9e0c80ad81ab56a39d68e1c56f29c44b70dcb4701730b.md`.
- Root cause of `snapshot-digest-mismatch`: `source_inventory` hashed `git diff HEAD` text; shallow snapshots abbreviate the index line to a different width than the full ODB. Fix: `--full-index` in `bin/ai-review-sandbox`.
- **PR #1060** https://github.com/popcre/ai-devops/pull/1060 — commit `a8cc7964` on `mimo/sandbox-digest-full-index` (worktree `C:\repos\ai-devops-wt-sandbox-full-index`). Files: `bin/ai-review-sandbox`, `tests/test-ai-review-sandbox.sh` (new case `shallow_and_full_odb_agree_on_source_digest`).
- `bash tests/test-ai-review-sandbox.sh` in that worktree: **109 passed, 0 failed**.
- Reviewer incidents recorded on edge-dev (see §8).

**In progress / not done**
- `tests/test-ai-review-packet.sh` was still running (120 `ok` lines, no final summary) at wrap-up; log `/tmp/packet-tests.log` (Git Bash temp on edge-dev). Not a failure — incomplete run.
- **Independent exact-head review of #1060 not started** (required before merge).
- **Gemini review of the process plan + GLM cut NOT started.** Gemini is eligible (`ai-review-preflight usable gemini` true; doctor PASS `gemini-3.8-flash-high`; usage 47% weekly / 96% 5h at 13:30 UTC). Must run from a **clean worktree** (packet builder rejects dirty trees). Clean worktree already exists: `C:\repos\ai-devops-wt-sandbox-full-index` after the commit (or a fresh one from `origin/main` for a plan-only review).
- PR #1060 not merged. Branch kept.
- Plan re-cut (GLM's shape) not written.

**Committed / pushed**
- `a8cc7964` pushed to `origin/mimo/sandbox-digest-full-index`. Not on `main`.

## 4. Everything we tried that did NOT work

1. **Muse `ai-muse new jev-plan-critique-2026-09-29`** — process killed (`ChildProcess.kill`); session left unreconcilable (`reconcile` said no successful retained process). Lesson: do not reuse that name; a replacement session was started.
2. **Muse `jev-plan-critique-20260929-b`** — printed session start then `ai-review-packet: error: snapshot-digest-mismatch`.
3. **Grok `ai-grok-review new jev-plan-critique-grok-20260929`** — same `snapshot-digest-mismatch`. Not a Grok defect.
4. **GLM first attempt** — same packet error until the `--full-index` fix was applied **in the live checkout** (uncommitted). After the local fix, GLM completed.
5. **`bash -lc` from PowerShell** — resolves to WSL (no distro). Use `C:\Program Files\Git\bin\bash.exe -lc` for wrapper scripts.
6. **Packet test suite hang** — `tests/test-ai-review-packet.sh` exceeded 3–5 minute tool timeouts while still printing `ok`; do not treat timeout as failure without reading the log tail.
7. **Sending full transcript JSONL to Jev** — never done (privacy). Digests only. The 2026-09-15 ~19:00–19:45 canned burst is evaluation fixtures (~122 sessions); exclude from evidence.

## 5. Root causes and key findings

- **`snapshot-digest-mismatch` root cause** (`bin/ai-review-sandbox` `source_inventory`): `git diff --binary HEAD` embeds an `index 001754a1..404441ad` line whose abbreviation width depends on ODB size. Shallow review snapshot vs full source → different bytes → different sha256 → packet validation dies. `--full-index` forces 40-hex SHAs. Verified: source digest == snapshot digest after the change (live diag on edge-dev).
- **Second contributor:** untracked files that change during snapshot build (e.g. another session writing `plan_shared-db-coordination-deletion.md`) also break equality. `create_or_refresh` retries twice; continuous writers still fail. Keep the tree quiet during packet builds.
- **Claude transcript shape:** `type=="user"` / `message.role=="user"`, title in `<uuid>/custom-title.json` (`customTitle`). **Codex:** `session_meta.payload.cwd`; user text under `payload.role=="user"` or `UserMessage`; strip READ-ONLY boilerplate. **Grok:** often session-id stubs.
- **Jev API:** `POST https://api.typesafe.ai/v1/systemone`, `answers.<id>.noul` is P(yes). Batch ~12. Polarity of the question decides the discard threshold. `jev-latest` is a moving alias.
- **GLM** (and every other reviewer) shares `bin/ai-review-packet` / `ai-review-sandbox`; the digest bug blocked all of them the same way.

## 6. Exact next steps

1. **Finish packet tests** on the #1060 worktree if still running: `tail /tmp/packet-tests.log` or re-run `bash tests/test-ai-review-packet.sh` from `C:\repos\ai-devops-wt-sandbox-full-index`. **Success:** `N passed, 0 failed` (or an explained failure).
2. **Independent exact-head review of PR #1060** (reviewer-safety). Use a governed reviewer (Gemini is usable) from a **clean** worktree at `a8cc7964`. **Success:** a durable APPROVE report naming that SHA, stored under `.ai/reviews/`.
3. **Gemini review of the process plan + GLM cut** (authorized, not done). Brief content: `%TEMP%\jev_process_improvements.md` + GLM's REVISE recommendation (fold into #658/#650/#131; keep preflight/pin/CI-visibility). Prompt-file; clean worktree; `AI_GEMINI_CALLER=mimo ai-gemini new …`. **Success:** Gemini verdict on "is GLM's cut right?" with a durable report.
4. **Merge #1060** through the queue after review + green checks (`bin/ai-pr-wait 1060`). **Success:** commit on `origin/main`; then prove one live packet build (Muse or Grok) and resolve the two reviewer-issue records with that evidence.
5. **Ask Albert §0 item 1** (plan re-cut). If he accepts GLM's cut, fold deltas into the named existing plans — do not create a 40th plan file.
6. Delete this handoff only after #1060 is merged and the two incidents are resolved (successor rule).

## 7. Constraints and gotchas in force

- Never push to `main`. Feature branch + PR + merge queue. `git var GIT_COMMITTER_IDENT` must be Albert Hazan.
- Stage only task-owned files. Canonical `C:\repos\ai-devops` is landing-only; task edits belong in worktrees (this session briefly edited canonical `bin/ai-review-sandbox` to unblock GLM — do not repeat).
- Reviewer-safety changes need independent exact-head review before merge.
- All GitHub calls through `bin/ai-gh`. Waits via `bin/ai-pr-wait` / `ai-blocker-watch` — no open-ended polling.
- Private transcripts never enter this public repo or reviewer packets. Jev gets digests only.
- TypeSafe / Z.ai keys via `op://` + `op run` only.
- Gemini reviews: clean worktree only; check `ai-gemini-usage --min-percent 15` before a long review.
- On Windows, wrappers need Git Bash (`C:\Program Files\Git\bin\bash.exe`), not WSL `bash`.
- One unproven live outcome per session (live-proof-session-sizing).

## 8. Access and environment

- Host: `edge-dev` (Windows). Repo: `C:\repos\ai-devops` (origin `https://github.com/popcre/ai-devops.git`).
- Task worktree: `C:\repos\ai-devops-wt-sandbox-full-index` branch `mimo/sandbox-digest-full-index` @ `a8cc7964`.
- Reviewer incidents: `C:\repos\ai-devops-reviewer-install\.ai\reviewer-issues\20260929T125838Z-edge-dev-muse-1961321` and `…\20260929T130211Z-edge-dev-grok-1989270`.
- GLM report: `C:/repos/ai-devops/.ai/reviews/glm-jev-plan-critique-20260929-….md`. GLM session name `jev-plan-critique-20260929` (caller `mimo`).
- Secrets: 1Password vault `vibe_coding`, item `typesafe.ai API`, field `credential` (TypeSafe). `op-service-account` under `~/.config/ai-devops/`. Never print values.
- MiMo session id: `ses_ffe5f13530d23ffe3EeiH2Gm04`.
- Scratch (may vanish): `%TEMP%\jev_*.jsonl`, `jev_classify.py`, `jev_process_improvements.md`, `/tmp/sandbox-tests.log`, `/tmp/packet-tests.log`.

## 9. Open questions and risks

- (2026-09-29) Packet test suite duration is unknown; a timeout may be a hang (fork resource errors appeared: `Resource temporarily unavailable`). If hung, kill and re-run focused cases only.
- (2026-09-29) Whether the bare-PASS / empty-report reviewer incident is already fixed by `empty-report` handling (GLM) is unverified — do not rebuild a registry until that is checked.
- (2026-09-29) `plan_shared-db-coordination-deletion.md` in the canonical checkout is another session's untracked work — do not delete or commit it here.
- (2026-09-29) Canonical `C:\repos\ai-devops` still has this session's uncommitted `bin/ai-review-sandbox` one-hunk mirror of the fix plus unrelated dirty files (AGENTS.md, move-bulk script, HANDOFF.d/*). Leave other sessions' files alone; after #1060 merges, `git checkout -- bin/ai-review-sandbox` only if identical to the landed commit.
- (2026-09-29) Jev `not_related_p` distribution was conservative (only 40/1346 discarded). If a tighter remainder is needed, re-ask with positive-topic polarity ("is about failures…") and discard at `noul < 0.10`.
