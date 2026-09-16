---
issue: 511
status: OPEN
owner: grok/live-proof-session-sizing
---

# Handoff — one unproven live-proof outcome per session

Paired plan: [`../plan_live-proof-session-sizing.md`](../plan_live-proof-session-sizing.md)

## 0. DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs the owner.

The implementing session must put this whole list to Albert in one message only if something new appears. Right now there is nothing to ask.

**Already settled — do NOT re-ask**

- 2026-09-16: Albert is not technical; production approvals go to an independent reviewer, not to him.
- 2026-09-16: proofs, reports, and tooling never go to the shared-db orchestrator.
- 2026-09-16: do not weaken merge-safety; do not drop live proof.
- 2026-09-16: do not steal remaining 3027 work from a live session.
- 2026-09-16: this work is process packaging in `popcre/ai-devops`, not finishing shared-db Steps 6 and 7.

## 1. What this application is

`popcre/ai-devops` is Albert’s public recovery toolkit for a multi-model AI workflow. Canonical checkout `C:\repos\ai-devops` is landing-only. Installed Claude/Codex rules live in `templates/system/CLAUDE-global.md` and `templates/system/AGENTS-global-codex.md`. `u2giants/shared-db` is the database repo where the eight-hour chat ran; this workstream does not change its product code.

## 2. What we set out to do this session, and why

Albert asked for a plan to implement the proposed fixes after an eight-hour chat failed to take tickets 3027, 3028, and 3029 (all non-orchestrator) to production.

This session’s job was to write that plan, register it, and leave an implementer able to execute without the chat. It did not implement the global sentence.

## 3. Current state — what is true right now

- Issue [#511](https://github.com/popcre/ai-devops/issues/511) is OPEN.
- Plan file exists: `plan_live-proof-session-sizing.md` (all 13 sections, STATUS all ⬜ except this planning commit).
- Worktree: `C:\repos\ai-devops-worktrees\live-proof-session-sizing` on branch `grok/live-proof-session-sizing`, created from `origin/main` `9b205e22`.
- Identity verified: `Albert Hazan <u2giants@users.noreply.github.com>`.
- Implementation of Steps 1–5 is **not started**.
- 3027 still OPEN; 3028 CLOSED; 3029 OPEN (checked 2026-09-16).
- Do not use `C:\Users\ahazan\.grok\worktrees\repos-ai-devops\claude-trancsript` — it is on `main` with unrelated deletes.

## 4. Everything we tried that did NOT work

- Treating merged #401 child tickets as programme acceptance. The 2026-09-15 audit already knew that; leftover proofs were still bundled. That is the failure this plan prevents.
- Asking one chat to take three leftover-proof tickets to production. Eight hours, 3027 and 3029 still open.
- Folding this into #401 as “keep 3027 as the single owner.” That packaging caused the pile-up.
- Letting this plan finish shared-db Step 6/7. That collides with the live 3027 session.
- Weakening merge-safety or dropping live proof. Live proof is how the batch feature was shown to be fake-done.
- Adding a new tool or memory file. Rejected: one sentence plus scoreboard packaging.

## 5. Root causes and key findings

Split definition of done: merged code counted as finished; live proof was saved for later; leftover proofs were bundled into one chat. Symptoms (idle helpers, asking Albert to approve production, colliding merges) already have 2026-09-16 rules in #500/#508/#509. The remaining gap is job-sizing: nothing refuses a bundle, and #401 STATUS still points several unproven steps at 3027 (`plan_shared-db-complete-throughput-repair.md:12-19`).

## 6. Exact next steps

Follow the plan STATUS table starting at Step 0. In short:

1. Confirm `origin/main` still lacks `one unproven live-behavior outcome`. You'll know it worked when that grep is empty.
2. Insert the locked bullet from plan §9 Step 1 into both globals, unwrapped. You'll know it worked when each file has one hit.
3. Add the phrase to `tests/test-client-globals-required-phrases.sh` and `PARITY_RULES`. You'll know it worked when `bash tests/test-client-globals-required-phrases.sh` PASSes.
4. Add the handover-skill sentence. You'll know it worked when grep hits `one issue per unproven step`.
5. #401 STATUS legend + liveness rule for 3027. You'll know it worked when no cell assigns two different *new* unproven steps to one issue.
6. PR, `bin/ai-pr-wait`, merge, `bin/ai-adopt-globals`, comment #511 with the SHA, close #511, delete this handoff. You'll know it worked when installed `CLAUDE.md` and `AGENTS.md` contain the phrase and this file is gone from `HANDOFF.d/` on `origin/main`.

## 7. Constraints and gotchas in force

- Feature branch and PR; never push to `main`.
- Stage only owned files.
- Do not wrap the required phrase (#209).
- Do not start a second 3027 chat. If unsure whether it is live, treat it as live.
- Change set of globals+test+skill+Python is **not** documentation-only; do not `--admin` skip checks.
- Public repo: never commit the transcript or `C:\Users\ahazan\.grok\tmp\what-went-wrong-3027.md`.
- GitHub through `bin/ai-gh`. Wait with `bin/ai-pr-wait`.

## 8. Access and environment

- Machine: `edge-dev`. Agent that wrote this: Grok.
- GitHub: `popcre/ai-devops` and `u2giants/shared-db` as `u2giants`.
- No secrets. Vault `vibe_coding` unused.
- Transcript (private, read-only): `C:\Users\ahazan\.claude\projects\C--repos-shared-db--claude-worktrees-issues-3027-3028-3029-prod-f35ee9\8acb349f-c36a-4c69-b7af-e806e7906714.jsonl`.

## 9. Open questions and risks

- Idle vs live for 3027 is a judgment call; fail-safe is “live.”
- Always-loaded global byte budget may warn; do not delete other safety rules to fit.
- Risk of colliding with 3027 if Step 4 splits too early.

No owner question is open.

---

## Self-audit

1. **Street-newcomer can continue?** Yes. §3 names the worktree, issue, and dirty checkout to avoid. §6 is the ordered gate list. The plan has the exact sentence.
2. **As effective as this session?** Yes. §4–§5 carry the dead ends and root cause. Locked decisions are in §0 and the plan §8.
3. **Every detail for execution?** Yes. Files, tests, merge class, install, and what not to commit are in §6–§8 and the plan §9–§12.
4. **Owner-only decisions in §0?** Sweep of §1–§9: no new Albert ask. Production approval, orchestrator routing, merge-safety, and 3027 non-theft are in the already-settled list. §0 says None.
