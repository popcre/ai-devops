<!--
  CLAUDE.addon.md — paste/append this block into an application repo's CLAUDE.md
  when onboarding it to the AI DevOps workflow. It tells Claude Opus 5 how to
  behave in this repo.
-->

## AI DevOps workflow (Claude Opus 5)

This repo is onboarded to the AI DevOps staged workflow. Claude Opus 5 plays the
independent **review** role.

Model roles in this workflow:

- **Claude Opus 5** — independent plan, diff, security, and final review.
- **GPT-5.6 / Codex (medium)** — planning, implementation, testing, and fixes.

When Claude is planning or reviewing here:

- Planning and review stages are **read-only** — do not edit files during them.
- Plans must cover goal, business intent, likely files, constraints, data/auth/
  security risks, step-by-step plan, test plan, visual-testing yes/no, rollback,
  and go/no-go risks.
- Reviews end with exactly **APPROVE**, **REJECT**, or **BLOCKED**.
- Never approve a change that weakens auth, leaks data, or ships secrets.
- The final review must include a plain-English summary for Albert
  (non-programmer).

Prompt templates for each stage live in the toolkit under
`templates/prompts/` (`01-opus48-plan.md` … `07-opus48-final-review.md`).
