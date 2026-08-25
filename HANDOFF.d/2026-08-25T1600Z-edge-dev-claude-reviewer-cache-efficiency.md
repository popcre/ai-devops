# HANDOFF — reviewer cache and snapshot efficiency

- **Status:** OPEN
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

## 2. State right now

**Nothing has been implemented.** The audit was read-only; no source file was
changed. The only artifacts are the plan and this handoff. A fresh session
starts at Phase 1, Step 1.1 of the plan (multi-reviewer review of the plan
itself, before any code).

## 3. What was decided, and what must not be relitigated

- **Muse stays in OpenCode direct mode.** Server mode failed Meta authorization
  and was separately rejected for fault isolation. `docs/muse-opencode.md:3-6`
  and `plan_muse-opencode-harness.md:19,160`. The per-turn Node cold start is
  the accepted price. **Locked.**
- **Fix the rebuild in the shared `ai-review-sandbox`, not in `ai-muse`.** The
  defect is universal to all reviewers; a Muse-local patch would leave the waste
  everywhere else.
- **The gate sandbox tag becomes per-provider** (`claude-review` /
  `codex-review`), not per-mode, so all stages share one warm snapshot. Accepted
  cost: concurrent same-repo gate reviews now serialise with a clear refusal.
- **Never report a token number the provider did not return** — absent prints
  `unavailable`, never `0`.
- Full reasoning, ten labelled decisions and nine rejected approaches are in the
  plan, § 7 and § 8.

## 4. Correction carried forward

An earlier draft of the audit claimed Grok and Kimi already skip the rebuild
when the source is unchanged. **That was wrong.** `create_or_refresh` rebuilds
unconditionally for everyone; Grok's `cmd_ask` and Kimi's ask path both call
`prepare_review` on every turn exactly as Muse does. The plan records this in
§ 6 Finding B so a later session does not inherit the error.

## 5. Next action

Read [`plan_reviewer-cache-efficiency.md`](../plan_reviewer-cache-efficiency.md)
STATUS table first, then execute Phase 1, Step 1.1 — send the plan to GLM, Grok
and Codex with the five adversarial questions written out in that step. Do not
start Phase 2 until their findings are resolved in writing.

## 6. Risks if this is picked up carelessly

The Phase 2 change touches shared evidence plumbing that both approval gates
depend on. A wrong reuse gate means a reviewer approving code that is not the
working tree — a silent, high-consequence failure. The plan's § 13 risk table
and the Step 2.2 test list exist specifically to prevent it. Do not compress
Phase 1 or Phase 2.3 to save time.
