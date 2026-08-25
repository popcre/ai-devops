# HANDOFF — reviewer cache and snapshot efficiency

- **Status:** OPEN (scope cut on 2026-08-25 after adversarial review)
- **Written:** 2026-08-25 (UTC) on `edge-dev` by Claude (Opus 5)
- **Review:** Grok 4.6, 3 turns, $0.439 — REJECT, REJECT, then APPROVE. GLM 5.3,
  3 turns — APPROVE, with seven defects found and fixed. Both models
  independently tried to argue the withdrawals back and could not.
- **Measurement:** [`docs/reviewer-prompt-cache-measurement-2026-08-25.md`](../docs/reviewer-prompt-cache-measurement-2026-08-25.md)
- **Repository:** `u2giants/ai-devops`, branch `main` (authored from worktree
  branch `claude/reviewer-setup-audit-23cef2`)
- **Base commit:** `722c2a4e577ccd9f0cfd99094f81c84f360b5744`
- **The plan:** [`plan_reviewer-cache-efficiency.md`](../plan_reviewer-cache-efficiency.md)

## 1. What this workstream is — SCOPE CUT TO ONE ITEM

**Read this before anything else: two of the three items this workstream started
with are withdrawn.** Only cache-hit token reporting for DeepSeek and Muse
remains, and it is observability only.

An audit on 2026-08-25 of all nine reviewer wrappers raised three candidate
defects. Grok 4.6 then audited the resulting plan over three turns and rejected
two of them on evidence; Claude verified every load-bearing claim against the
source before accepting it. What survived:

- **Cache-hit reporting for DeepSeek and Muse — proceeds.** Both providers
  return the number and both wrappers discard it. Changing what is printed can
  never change what a reviewer reads.

What did not, and why (the full mechanisms are in the plan, § 6 and § 7):

- **Deterministic gate snapshot paths — won't do.** The premise was wrong. The
  gate prompt is 326 bytes (`bin/ai-claude-review:90-99`) and the repository
  arrives as Read/Grep/Glob tool results, not as prompt prefix, so a stable path
  cannot make it cacheable. The gates also pass `--no-session-persistence`, and
  sharing a snapshot or packet tag would break `concurrent_reviews_both_complete`
  and re-open the shared-db#1296 evidence swap on an approval gate.
- **Digest-gated snapshot reuse — won't do.** `source_digest` cannot see ignored
  files, evidence packets, `.git` state, untracked exec bits, empty directories
  or submodule interiors, and `ai-review-packet` runs `--tests` inside the
  snapshot. The unconditional wipe it would have removed is the integrity
  boundary that keeps those leftovers out of the next review.

## 2. State right now

**No source file has been changed.** Everything so far is documentation: the
plan, this handoff, and the measurement. A fresh session starts at **Step 2.1**
of the plan (DeepSeek usage capture).

The measurement spike (Step 3.1) is **done** and does not need re-running unless
the Claude or Codex CLI changes its prefix behaviour. It closed item 1 on
evidence: `cache_read_input_tokens` was 2,800 in all six Claude probes across
three working directories, the 7.8k–11.9k-token prefix is created and never read
back, and the counts drift 1–3 tokens between byte-identical runs.

## 3. What was decided, and what must not be relitigated

- **Muse stays in OpenCode direct mode.** Server mode failed Meta authorization
  and was separately rejected for fault isolation. `docs/muse-opencode.md:3-6`
  and `plan_muse-opencode-harness.md:19,160`. The per-turn Node cold start is
  the accepted price. **Locked.**
- **The gate reviewers keep per-run snapshot directories and per-run evidence
  packets.** Sharing either breaks `concurrent_reviews_both_complete`
  (`tests/test-ai-claude-review.sh:70-73`) and re-opens the shared-db#1296
  evidence swap on an approval gate (`bin/ai-review-packet:243-257`).
- **The unconditional snapshot wipe stays.** It is the integrity boundary that
  keeps digest-invisible leftovers — ignored files, evidence packets, `.git`
  state — out of the next review.
- **Never report a token number the provider did not return.** Absent prints
  `unavailable`, never `0`.
- Eleven rejected approaches with their evidence are in § 7 of the plan.

## 4. Corrections carried forward

Two errors were made and corrected during this workstream. Both are recorded so
a later session does not inherit them:

1. An early draft of the audit claimed Grok and Kimi already skip the snapshot
   rebuild when the source is unchanged. **Wrong** — `create_or_refresh`
   rebuilds unconditionally for every reviewer.
2. The first draft of the plan claimed a randomized snapshot path caused the
   whole repository context to be re-billed on every gate stage. **Wrong** — the
   gate prompt is 326 bytes and the repository arrives as tool results, not
   prompt prefix. Verified directly; this is what withdrew item 1.

## 5. Next action

Read [`plan_reviewer-cache-efficiency.md`](../plan_reviewer-cache-efficiency.md)
STATUS table first, then execute Step 2.1. Muse's token field names must come
from a real OpenCode `step_finish` event, never a guess — that is the one open
unknown.

## 6. Risks if this is picked up carelessly

The main risk is now historical rather than technical: a future session finding
the withdrawn items attractive and reviving them. Section 7 of the plan records
eleven rejected approaches with the evidence that killed each one. Do not
re-derive them. Reopening the caching idea requires a traced provider request
showing a cacheable prefix exists, not an argument from first principles.

The remaining work is observability only and cannot approve stale code.
