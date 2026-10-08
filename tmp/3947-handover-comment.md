HANDOVER — 2026-10-07 6:10 PM EDT — MiMo chat on edge-dev

Taking stock for a session close. Claim #3955 remains with `mimo/3947-scraped-dedupe` (version `20261007190954`).

## 1. What we were doing
Complete #3947 through production: Scraped Properties display dedupe (Warner / Sesame / Lucasfilm-Disney), live proof, close.

## 2. What we actually did
- PR #3957 merged earlier (`eac3e188`) — migration `20261007020907` is now HARD_BLOCKED (DeepSeek REVISE verdicts pin head `f8b8b321…`).
- Reviewer-lifecycle fix PR #4032 merged (`a456e842`).
- Docs PR #4035 merged (`7037db734`).
- Forward replacement migration `20261007190954` authored, claimed, tested.
- PR #4047 MERGED (`0d6520a611e641e30570edc2069473e12a0479e5`) at head `e35c1ecde901b55e7ed3a343da685d5f2c4c7a37` with two fence APPROVEs (Muse + Gemini).
- Live-proof queries written; preview dry-run zero FAIL (`C:/repos/ai-devops/tmp/3947-live-proof-queries.sql`).
- Apply dispatch script ready (`C:/repos/ai-devops/tmp/3947-fire-production-apply-fwd.sh`).

## 3. Preview / production
- Preview has `20261007020907` only (run 37572585770). `20261007190954` has NOT been applied to preview or production.
- Production ledger does not have `20261007190954`.

## 4. Half-finished
Promote + live proof of `20261007190954`. A last worker may still be running. Not applied, not proven, #3947 not closed.

## 5. What we own
- Claim #3955 → version `20261007190954`, exclusive object `function api.db_data_admin_scraped_source_inventory`.
- Worktrees: `C:\repos\shared-db\.claude\worktrees\3947-scraped-dedupe`, `C:\repos\shared-db-wt-3947-fwd-20261007`.
- Handoff file: `C:\repos\ai-devops\HANDOFF.d\2026-10-07T2206Z-edge-dev-mimo-3947-forward-replace-merged.md`.

## 6. About to do next
Muse fence APPROVE at live main → immediate `3947-fire-production-apply-fwd.sh` → ledger proof → live-proof queries on production → tick checklist → close only if fully delivered.

## 7. Blocked on
Main SHA race (fence `main_sha` goes stale in minutes). Not blocked on Albert.

## 8. What we tried that did NOT work
- Promoting `20261007020907` — DeepSeek REVISEs permanently pin that head; no disregard CLI.
- DeepSeek for this issue class — rewrites fence / REVISEs. Never use it here.
- Historical preview recovery cannot apply a new version; use `merged_preview_source_pr=4047`.
- GLM/Qwen quota out; StepFun Linux-only wrapper on Windows.

## 9. Facts that may be stale
origin/main SHA moves every few minutes. Re-read before any apply. Claim lease expires 3:09 PM EDT Oct 8 2026.

Posted by MiMo chat unknown on edge-dev
