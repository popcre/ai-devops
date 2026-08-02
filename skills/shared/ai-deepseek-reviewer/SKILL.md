---
name: ai-deepseek-reviewer
description: >-
  Run a read-only DeepSeek second-opinion review (diff, security, or
  final-check) on the current git repo's changes and save the result under
  .ai/reviews/. Use when the user wants an independent DeepSeek review of the
  current changes without changing any files -- "run this by deepseek",
  "get deepseek's opinion", "have deepseek review this diff", "deepseek code
  review". Works the same in Claude Code (Windows Desktop and Ubuntu CLI) and
  Codex (Windows and Ubuntu CLI) -- it is a shared skill, not an MCP tool, so
  no extra wiring is needed per app.
---

# AI Reviewer (DeepSeek)

Read-only second-opinion code reviews from DeepSeek, wrapping the toolkit's
`ai-deepseek-review` command. Reviews **never** edit, commit, push, merge, or
delete anything -- DeepSeek only ever sees the current git diff as plain text
and returns plain text back.

> Status: v0.1, modeled directly on the existing `ai-reviewer` (Codex) skill.

## When to use

- The user wants an independent DeepSeek opinion on the current diff, a
  security-only pass, or a final go/no-go check.
- The user explicitly wants a **read-only** pass (no code changes).
- Use this alongside, not instead of, a Codex or Claude review when the user
  wants a genuinely independent third opinion -- DeepSeek is a different model
  family, so it can catch things the others miss (and vice versa).

## Modes

Run from inside the target git repo:

```bash
ai-deepseek-review diff-review       # review the current git diff
ai-deepseek-review security-review   # security-only review of the diff
ai-deepseek-review final-check       # go/no-go readiness check
```

Each run:

- reads the current `git diff HEAD` (staged + unstaged changes),
- sends it to the DeepSeek API (`deepseek-chat` by default; override with
  `DEEPSEEK_MODEL=deepseek-reasoner` for the reasoning model),
- creates `.ai/reviews/` if missing,
- saves output to `.ai/reviews/YYYYMMDD-HHMMSS-deepseek-<mode>.md`,
- prints the saved file path.

If there are no changes vs `HEAD`, the command says so and exits without
calling the API.

## Secrets

`DEEPSEEK_API_KEY` is a managed 1Password reference
(`config/mcp.env.example` -> `~/.config/ai-devops/mcp.env`), the same pattern
used for every other API key in this toolkit. `ai-deepseek-review` resolves it
itself if it is not already in the environment -- nothing to configure by
hand, and the key is never written into any app's config file.

## Guardrails

- Must be inside a git repo.
- Read-only: no commits, pushes, merges, or deletions -- the diff is only
  ever read, never acted on.
- Does not read or send `.env` files or other secrets -- only the tracked
  code diff.
- If the DeepSeek API call fails (bad key, network, rate limit), the script
  exits non-zero with the API's error body on stderr rather than silently
  producing an empty review.

## Relationship to other reviewers

| Want | Use |
|---|---|
| Codex's independent read-only pass on the diff | `ai-reviewer` (`ai-codex-review`) |
| A genuine back-and-forth debate with Codex | `codex-second-opinion` |
| A third, differently-trained model's read-only pass | **this skill** |