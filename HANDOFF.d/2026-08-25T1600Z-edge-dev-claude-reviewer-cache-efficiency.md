# HANDOFF — reviewer cache and snapshot efficiency

- **Status:** OPEN (scope cut on 2026-08-25 after adversarial review)
- **Written:** 2026-08-25 (UTC) on `edge-dev` by Claude (Opus 5)
- **Repository:** `u2giants/ai-devops`, branch `main` (authored from worktree
  branch `claude/reviewer-setup-audit-23cef2`)
- **Base commit:** `4915adac90f7867b4475a3d146920f5e3480b0a4`
- **The plan:** [`plan_reviewer-cache-efficiency.md`](../plan_reviewer-cache-efficiency.md)

## 1. What this workstream is

Three efficiency defects found by a read-only audit of all nine reviewer
wrappers on 2026-08-25. Albert asked for the audit, then asked for an
implementation plan covering the three fixes.

1. The two **gate reviewers** (`bin/ai-claude-review`, `bin/ai-codex-review`)
   build their review snapshot under a path containing `$$` and `$RANDOM`, and
   put `$MODE` in the first line of the prompt. Both make the provider's prompt
   cache useless, so all four pipeline review stages pay full price for
   identical repository context.
2. `bin/ai-review-sandbox`'s `create_or_refresh` **always rebuilds** the review
   clone, even when the source is byte-identical to the last build — it writes a
   `source_digest=` into the snapshot marker and never reads it back. This costs
   wall-clock time on every follow-up turn for **every** reviewer.
3. **DeepSeek and Muse discard cache-hit token data** the provider returns, so
   nobody can confirm caching is working.

## 2. State right now — SCOPE CUT

**Two of the three items are WITHDRAWN.** Grok 4.6 audited the first draft over
two turns ($0.246) and rejected items 1 and 2 on evidence; Claude verified every
load-bearing claim against the source and agreed. The plan was rewritten. Only
the cache-hit reporting for DeepSeek and Muse remains.

- **Item 1 (deterministic gate snapshot paths) — won't do.** The premise was
  wrong: the gate prompt is 326 bytes and the repository arrives as tool
  results, not prompt prefix, so a stable path cannot make it cacheable. The
  gates also pass `--no-session-persistence`.
- **Item 2 (digest-gated snapshot reuse) — won't do.** `source_digest` cannot
  see ignored files, evidence packets, `.git`, exec bits, empty directories or
  submodule interiors, and the unconditional wipe it would remove is an
  integrity boundary.
- **Item 3 (cache-hit reporting) — proceeds.** Observability only; it changes
  what is printed, never what a reviewer reads.

**Nothing has been implemented.** The audit was read-only; no source file was
changed. The only artifacts are the plan and this handoff. A fresh session
starts at Step 2.1 of the plan (DeepSeek usage capture).

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
