# Phase 3 pilot — popcre/ai-devops

## Scope and routing measurement

Measured from `origin/main` immediately before the pilot on 2026-09-09. The
router was already lean enough to keep intact, so before and after are equal:

| Surface | Before | After |
|---|---:|---:|
| `AGENTS.md` | 6,953 bytes / 91 lines | 6,953 bytes / 91 lines |
| `CLAUDE.md` | 1,159 bytes / 20 lines | 1,159 bytes / 20 lines |
| `HANDOFF.md` | 678 bytes / 13 lines | 678 bytes / 13 lines |
| `README.md` | 13,148 bytes / 287 lines | 13,148 bytes / 287 lines |

Size is diagnostic only. No router text was removed for this pilot.

## No-loss ledger

Every section is assigned once. All are `keep` because this pilot adds an
enforced local declaration without migrating an already-lean routing surface.

| Surface and section | Disposition | Reason |
|---|---|---|
| `AGENTS.md` title and introduction | keep | Repository identity and routing entry point |
| `AGENTS.md` Repository contract | keep | Invariant safety, ownership, privacy, branch, and installation boundaries |
| `AGENTS.md` Task router | keep | High-frequency route map to specialized owners |
| `AGENTS.md` Editing and delivery | keep | Repository-wide delivery contract |
| `CLAUDE.md` Claude Code adapter | keep | Thin client adapter to the canonical repository router |
| `HANDOFF.md` handoff pointer | keep | Concurrency-safe route to active handoffs |
| `README.md` title and introduction | keep | Public product purpose and supported environments |
| `README.md` Set up a new machine, Windows, and Ubuntu | keep | Primary public recovery entry points |
| `README.md` Where this lives and What this repo does NOT store | keep | Repository identity and privacy boundary |
| `README.md` The model workflow, GLM, and reviewer health | keep | Public operating overview and health route |
| `README.md` Fresh server install and Windows computer install | keep | Supported installation entry points |
| `README.md` Update process and Restore process | keep | Recovery-critical public routes |
| `README.md` Basic commands, Repo layout, and Safety notes | keep | High-frequency command map, ownership map, and invariant safety summary |

Unassigned sections: **0**.

## Policy and trigger evidence

- Ordinary Markdown remains `prose` and retains the no-review/no-long-wait fast path.
- Ordinary unmatched source remains `code`.
- `bin/ai-review` resolves to protected `reviewer-safety`; a deliberately weaker
  local rule cannot downgrade it.
- Declared installation entrypoints on Ubuntu and Windows, the canonical
  machine-setup entrypoint, and the launcher catalog resolve to protected
  `deployment` without losing the pre-existing deploy refusal.
- The required focused tests validate the declaration, strongest-class
  resolution, machine-tool ownership, and installed command behavior.

## Installation and rollback rehearsal

The Windows machine-tool catalog now owns `ai-task-gates`, matching the existing
Ubuntu `install.sh` ownership. On 2026-09-09 the canonical-checkout installer
created the managed system-path launcher; `ai-task-gates version` returned
`1.0.0`, and `ai-task-gates explain` from the linked pilot worktree resolved
`popcre/ai-devops` plus the local `installed-routing-proof` requirement.

Focused verification: task gates 78 passed / 0 failed; repository coverage and
routing identity audit PASS; machine-tool catalog
PASS; Windows installer 8/8 PASS; workflow policy PASS; schema validation and
`git diff --check` PASS. Rollback uses the normal supported path: restore the
prior Git revision and rerun the same installer; no application, database,
cloud, or production state is involved.
