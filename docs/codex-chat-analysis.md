# Codex chat analysis

Built from `codex_chats/` after syncing `main` from GitHub on 2026-07-08.

## Corpus

- 342 JSONL transcript files, about 398 MB.
- 324 sessions with non-boilerplate user turns after filtering environment
  context, injected `AGENTS.md`, turn-aborted messages, and giant pasted global
  docs.
- 2,219 filtered user messages, 1,811 of them short task prompts.

## What Albert uses Codex for most

1. **Implementation and fixing in app repos.** Most active repos/cwds were
   `popcrm-web`, `theoracle`, `poppim-web`, `popdam3`, and the retired backend,
   `shared-db`, `compshop`, and `synology-monitor`.
2. **GitHub shipping.** "push and commit" alone appeared 40 times; variants like
   "commit and push", "is everything pushed and committed?", and PR creation
   appeared repeatedly.
3. **Docs and handoffs.** The long AI session documentation prompt was pasted
   more than 20 times, plus shorter "update the .md files" variants.
4. **Infrastructure/NAS/sync work.** Synology, Seafile/ShareSync, SSH, Docker,
   service health, backup/restore, and server triage are recurring.
5. **Database/Supabase/data migration work.** `shared-db`, Supabase migrations,
   table/schema questions, backend migrations, and data verification recur.
6. **UI/product changes with verification.** Tooltips, buttons, admin pages,
   visual checks, and "why does the live site still look old?" recur.
7. **AI workflow design.** Codex is used to improve Codex/Claude handoffs,
   model roles, MCP usage, prompt templates, and token-cost strategy.

## Repeated tasks

| Repeated ask | Replacement |
|---|---|
| "push and commit" / "commit and push" / "is everything pushed and committed?" | `codex-github-ship` |
| "pull latest develop into sandbox-albert, then pull local" | `codex-github-ship` |
| "update the .md files" plus the long session docs prompt | `codex-session-closeout` |
| "is HANDOFF.md comprehensive enough for a fresh developer?" | `codex-session-closeout` |
| "find all local Codex session transcripts" | `codex-transcript-miner` |
| "read all docs / read handoff / remove irrelevant context" | `codex-context-optimizer` |
| "why is the live site still running the old commit?" | `codex-github-ship` plus repo deploy docs |

## Instructions that were being rewritten manually

- Read `AGENTS.md` first and load only the docs relevant to the task.
- Before dflow work, sync `develop` into Albert's sandbox branch, then pull it
  locally; PR back to `develop`, never self-merge.
- End-session docs should capture only durable knowledge from this session.
- Handoffs must be complete enough for a fresh developer with no chat context.
- Commit/push must be verified on GitHub, not inferred from local state.
- Live deploys must be verified by CI/image/live SHA or an equivalent app check.
- Secrets belong in 1Password, not transcripts, prompts, remotes, or files.

## Sensitive-data finding

The archive includes credential-shaped material in historical prompts and some
remote URLs with embedded tokens. Keep `codex_chats/` private, do not quote
secret values in reports, and route future access through 1Password references.

## What to automate next

- Install Codex skills automatically with `bin/ai-install-skills`.
- Keep `templates/system/AGENTS-global-codex.md` short and delegate procedures
  to skills/docs.
- Add/keep repo-local `AGENTS.md` documentation maps so sessions read less.
- Prefer `HANDOFF.md` for cross-session state instead of long chat history.
- Use transcript mining periodically to promote repeated prompts into skills.
