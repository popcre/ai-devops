# Kimi persistent implementation plan

`plan_kimi-persistent-implementation-sessions.md` owns the open redesign of
`ai-kimi` implementation sessions. Read its STATUS table first and do not re-plan it.

The approved architecture keeps the exact Kimi session ID and one cumulative binary
patch anchored to an immutable base commit. Every turn reconstructs that state in a new
disposable worktree, resumes the exact conversation, exports durable state, and removes
the worktree. Cross-directory and failed-turn resume behavior must be measured against
the pinned Kimi CLI before implementation behavior changes.
