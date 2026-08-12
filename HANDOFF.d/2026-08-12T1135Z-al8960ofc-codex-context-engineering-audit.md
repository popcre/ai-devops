# Handoff: context-engineering audit and implementation plan

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public toolkit for restoring and managing
Claude Code, Codex, shared skills, machine instructions, MCP wiring, memory, and
multi-model development workflows. It is Bash, PowerShell, and Markdown, not a
hosted service. The repository is `C:\repos\ai-devops` on Windows and uses
`main` only.

## 2. What we set out to do and why

Albert asked for a read-only audit of global instructions, repo instructions,
and skills after reviewing an X post about context and graph engineering. He
also asked for a comprehensive implementation plan reviewed and debated in
order with Claude, GLM 5.2, and Grok 4.5.

The plan is:
[`../plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md).

## 3. Current state

- The read-only audit is complete at commit
  `c23303cb90dd7dd7ac8c71d103480deaff759776` on `main`.
- No global, repo instruction, skill, installer, machine config, production
  system, or application code has been changed.
- The plan and this handoff are the only intended tracked additions.
- Existing unrelated untracked paths `.ai/` and
  `docs/claude-remote-control-hardening-v2.md` must remain untouched.
- The plan's final self-audit passed. Claude, GLM 5.2, and Grok 4.5 reviews are
  complete with evidence-backed consensus and no material objection remaining.
  Grok's total reported cost was `$0.5189288`, below its `$1.50` ceiling.

## 4. Everything tried that did not work

1. X exposed the main post and embedded article card, but the full X article
   required sign-in. The plan therefore separates the visible claims from
   verified primary Anthropic and OpenAI guidance and does not treat the X
   article as authoritative evidence.
2. Adding all skill sizes together initially yields about 121,425 approximate
   tokens, but that is not per-turn context because skills are conditionally
   loaded. The plan explicitly rejects that misleading total as an optimization
   target.
3. Exact-line comparison alone undercounts semantic duplication. The audit also
   checked exact normalized paragraphs and found fourteen repeated groups, which
   are candidates for review rather than automatic deletion.

## 5. Root causes and key findings

- The repo already implements most sound context-engineering ideas through
  routers, skills, plans, handoffs, memory, and staged workflows.
- The immediate issue is always-loaded global/repo prose plus missing automated
  ownership and size gates, not the absence of six special files.
- Global source files are roughly 4,000-4,200 estimated tokens each; installed
  copies on this machine are larger because they contain local additions.
- This repo's `AGENTS.md` is roughly 11,731 estimated tokens. Representative app
  routers range up to roughly 40,316 estimated tokens.
- Four installed skill copies differ from current repo source on this machine.
- Fourteen exact duplicate paragraph groups exist across skills.
- Blind overwrite, blind deletion, a graph database, and a universal six-file
  convention were rejected.

## 6. Exact next steps

1. Open `plan_context-engineering-consolidation.md` and read its STATUS table,
   sections 1, 4, 8, 11, and 13 before acting. Success means the new session can
   state the goal, scope, locked decisions, risks, and current first open step.
2. Begin plan step 1 only: build the dependency-free read-only baseline audit and
   fixtures. Do not trim instructions yet. Success means the stable report,
   secret-exclusion fixture, and named local tests pass exactly as step 1 states.
3. Update the plan STATUS and current-state sections in the same session before
   any context cut. Success means no future session can mistake completed work
   for open work.
4. Use the plan's natural context cuts. Before each later phase, re-read all
   downstream phases and verify the prior phase's gate. Success means no phase
   starts from stale assumptions.
5. Keep this handoff open until the full implementation, pilot, and reachable
   machine rollout are proven. Delete it only with the completing commit.

## 7. Constraints and gotchas

- Planning is complete. Implementation must follow the reviewed plan phase by
  phase; do not skip directly to prose trimming.
- Preserve all unrelated files and concurrent work.
- Claude, GLM, and Grok reviews are opinions, not authority. Challenge them with
  evidence and do not force fake agreement.
- Keep GLM and Grok sessions persistent and bounded. Do not bypass their wrappers.
- Never expose secrets or transcript contents.
- No production/shared-cloud/database mutation.
- GPT-5.6 reasoning remains `low` or `medium`.
- Never rewrite root `HANDOFF.md` or another session's handoff.

## 8. Access and environment

- Repo: `C:\repos\ai-devops`, branch `main`.
- GitHub: `https://github.com/u2giants/ai-devops`.
- Claude, GLM, and Grok reviews are complete. Reuse their named sessions only if
  new implementation evidence creates a real disputed claim.
- Review artifacts stay under the untracked `.ai/reviews/` path.
- No secret is needed.

## 9. Open questions and risks

- The safe installed-global reconciliation design remains intentionally open
  until fixture tests compare managed blocks, generated bases, and overlays.
- Real before/after task usage is required before setting context budgets.
- Other application repos may need separate follow-up plans; this plan forbids a
  bulk rewrite.
- A reviewer may suggest removing safety text for size. Require a behavioral
  test and canonical owner before accepting any such change.

## Mandatory self-audit

1. Yes. A new developer can continue without chat context because sections 1-3
   define the repo, goal, artifact, commit, and completed review state.
2. Yes. Sections 4-5 preserve failed paths, measurement caveats, findings, and
   rejected directions.
3. Yes. Section 6 has ordered actions with success gates, and sections 7-9 give
   limits, access, and decision risks.

Self-audit passed on 2026-08-12.
