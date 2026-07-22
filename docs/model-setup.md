# Model Setup

How to adapt the model **commands** to your machine. For the full list of
`models.env` variables and where config lives, see
[`configuration.md`](configuration.md) — that is the canonical config reference
and is not duplicated here. This doc focuses on the model-specific concerns:
roles, adapting CLI flags, and how the scripts use the commands.

## The model workflow (roles)

- **Opus 4.8 (high reasoning)** — implementation plans, architecture review,
  final product/architecture review.
- **GPT-5.5 / Codex** — coding, implementation, testing, fixing.
- **Opus** — independent review throughout (plan, diff, security, final).
- **GLM-5.2** — optional independent full coding agent invoked by either Claude
  or Codex through `ai-glm-agent`; defaults to read-only review.

## GLM configuration

GLM is deliberately separate from the staged `models.env` commands because the
same launcher runs on Windows and Ubuntu. Its non-secret defaults live in the
managed `~/.config/ai-devops/mcp.env` copied from `config/mcp.env.example`:

- `ZAI_GLM_MODEL=glm-5.2`
- `ZAI_ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic`
- `ZAI_API_KEY=op://vibe_coding/GLM z.ai API/credential`

The last line is a 1Password reference, not a key. Do not put the resolved value
in this repo or in Claude/Codex settings. The launcher refuses silent fallback
when Z.ai returns a different model.

## Important: the exact flags may differ on your machine

The Claude/Codex CLIs evolve, and the exact model identifiers and flags
(`--model`, `--reasoning`, etc.) may not match your installed versions. **You may
need to edit `/etc/ai-devops/models.env` after install.**

To find the right flags:

```bash
claude --help
codex --help
```

Then update the `*_CMD` variables to whatever actually works, e.g. swapping the
model id or the reasoning flag. The scripts always read the real file at
`/etc/ai-devops/models.env`, so your edits take effect immediately.

## How the scripts use these

- `ai-model-call <stage> <prompt> <out>` maps a stage name to the matching
  `*_CMD` and pipes the prompt in on stdin.
- `ai-codex-review <mode>` uses `CODEX_CMD` for read-only reviews.

## A note on Fable

Earlier drafts of this workflow referenced "Fable." **Fable is not used.**
Wherever planning/final-review would have used it, this workflow uses
**Opus 4.8 with high reasoning** instead.
