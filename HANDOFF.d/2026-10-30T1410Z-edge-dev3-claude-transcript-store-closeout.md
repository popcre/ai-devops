---
issue: 2050
status: OPEN
owner: claude/transcript-store-closeout
---

# HANDOFF — transcript store closeout (2026-10-30 14:10 UTC, edge-dev3/claude)

## 0. ⚠️ Business decisions only the owner can make
None open. One coordinator call was made and is recorded on #2050: the label hand-check gate (≥40/50 correct first topic) was met only on "any of the 1–3 topics" (41/50; first topic 36/50, prompt v5). Labels can be redone later with `build.py --relabel`.

## 1. What this application is
`popcre/ai-devops` is Albert's public AI toolkit. The transcript store is a private, topic-cut SQLite file of every AI chat session, built on edge-dev3 and published to Albert's Dropbox (`~/Dropbox/ai/transcript-store/`). Spec: [plan_transcript-store.md](https://github.com/popcre/ai-devops/blob/main/plan_transcript-store.md) — its STATUS table and "Closeout" note are authoritative.

## 2. What this session set out to do
Implement #2050 and stages #2059–#2063 end to end. All five stages are merged and live; only the step-7 second-day proof remains.

## 3. Current state (2026-10-30 ~9 AM EDT)
- A uploads (PR #2082): daily on edge-dev3, hetz (pulled from edge-dev3), edge-dev, al8960ofc, 916-alien; #2059 fully ticked.
- B pipeline (PR #2083), D reader + skill (PR #2098, Windows proof on #2062), E mining (PRs #2121, #2135, six checks pass): their issues are fully ticked.
- C: backfill done (12,316 sessions, 0 failed chunks), store published 8:42 AM EDT 2026-10-30 (PRs #2097, #2100, #2146). Timer `ai-transcript-store.timer` (edge-dev3 user unit, daily 05:30) ran day 1 at 5:30 AM EDT 2026-10-30. #2061 "live proof" unticked.
- The 6,490 review-value labels were imported into the working DB at ~8:50 AM EDT; they reach the published copy with the next timer run. The real-question proof is posted on #2050 (comment 6523561417).

## 4. What did not work
- Prompt versions v2–v4 and v6–v8 scored worse on the label hand-check; v5 is kept (counts in [smoke-2026-10-29.txt](https://github.com/popcre/ai-devops/blob/main/tests/verification/transcript-store/smoke-2026-10-29.txt)).
- The first daily run had 24 failed chunks: ScaleDown sometimes returns a summary with no topic header. Fixed in PR #2146 (re-ask, then `other`).
- The initial backfill never imported `labels.db`; done by hand with `build.py --import-labels`.

## 5. Key findings
ScaleDown summarises well but does not rank the first topic reliably. edge-dev's newest .jsonl is 2026-10-20, so its STALE flag in `--stats` is real (work there is in sqlite tools, out of scope).

## 6. Exact next steps (after 5:30 AM EDT 2026-10-31)
1. On edge-dev3: `cat ~/Dropbox/ai/transcript-store/CURRENT.json` names a `db/store-20261031T*.db` file; check its size/sha256 match.
2. Newest `~/.local/state/ai-devops/transcript-store/run-*.json` shows `chunks_failed: 0`; its `.err` is empty.
3. `ai-transcript-query --stats` works, and the published copy holds 6,490 `question_labels` rows.
4. Tick #2061 "live proof"; mark plan STATUS row 7 ✅ via PR (`gh pr merge --squash --admin` after `bin/ai-doc-safety .`); tick #2050's live proof citing its comments; close #2059–#2063 and #2050.
5. Delete this file in the same PR (work is done). If the run failed: fix it and wait one more day.

## 7. Constraints
Public repo: no transcript text, segment text, or secrets counts anywhere. Never an LLM for transcript text (ScaleDown only). Reviews are advice only. Times in EDT. Sign GitHub posts with `$AI_GH_SIGNATURE`.

## 8. Access
edge-dev3 user `ahazan`; Windows hosts via `~/.ssh/ai-devops.conf` with key `916-alien`. ScaleDown key is in 1Password `vibe_coding` (see the scaledown-compress skill).

## 9. Open risks
Label first-topic precision is ~72%; if answers look mis-topiced, run step 5's gate on a new prompt and `--relabel`.
