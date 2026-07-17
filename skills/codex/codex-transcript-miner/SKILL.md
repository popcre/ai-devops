> **STOP — transcripts moved to a private repo (2026-07-17).** Live credentials
> (including the 1Password service-account token) were found in committed
> transcripts while `u2giants/ai-devops` was PUBLIC. Transcripts now live in the
> PRIVATE repo `u2giants/ai-devops-transcripts` (git submodule). Do NOT commit
> `claude_chats/` or `codex_chats/` into ai-devops — `.gitignore` blocks them.

---
name: codex-transcript-miner
description: Find, scrub, back up, and analyze Codex transcript archives for repeated prompts and reusable workflows. Use when the user asks to find local Codex chats, sync codex_chats, analyze repeated Codex tasks, mine prompts, create skills from chat history, or reduce token use from old sessions.
---

# Codex Transcript Miner

Use this for the repeated "find all local Codex session transcripts" and
"analyze my Codex chats" workflow.

## Safety

- Treat transcripts as sensitive private data.
- Never print secret values, embedded-token remotes, passwords, bearer tokens,
  private keys, or connection strings.
- If credential-shaped material is found, report the file/path category and
  recommend rotation or 1Password storage without exposing the value.

## Find Transcripts

Common locations:

- `~/.codex/session_index.jsonl`
- `~/.codex/sessions/**/rollout-*.jsonl`
- `~/.codex/archived_sessions/*.jsonl`
- restored homes under `codex_chats/<machine>/.../.codex/`

Use:

```bash
find "$HOME" -path '*/.codex/*' -name '*.jsonl' -print
find /home/ai/ai-devops/codex_chats -type f -name '*.jsonl' -print
```

## Analyze

1. Parse JSONL structurally.
2. Count sessions, user messages, top repos/cwds, repeated short prompts, and
   task categories.
3. Filter boilerplate before drawing conclusions: environment context,
   injected `AGENTS.md`, turn-aborted messages, and giant pasted global docs.
4. Spot-check representative transcripts before creating a skill.
5. Convert only high-repeat/high-friction workflows into skills or templates.

## Output

Write a concise report with:

- what Codex is used for most,
- repeated asks and prompts,
- manually rewritten instructions,
- recommended skills/templates,
- token-reduction opportunities,
- sensitive-data findings summarized without values.
