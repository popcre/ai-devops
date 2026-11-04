# Implementation plan — popcre/ai-devops#2314 (vendored Supabase skills vs. shared-db rules)

## Verdict (checked on main `f2b4f5bd`, 2026-11-04 3:51 PM EST)

PARTLY FIXED, ONE PART STILL REAL. Issue #2314 is an advisory review finding (reviewer GLM) on
merged PR #2313 (merge commit `84fa7b3f`), which vendored `supabase/agent-skills` into
`skills/shared/supabase/` and `skills/shared/supabase-postgres-best-practices/`. It raised three points:

| Finding | State on main | Evidence |
|---|---|---|
| 1. 39 docs unreachable (doc-reachability fails) | FIXED | `docs/skills-map.md:59-64` links both SKILL.md files; `skills/shared/supabase-postgres-best-practices/SKILL.md:42-55` now uses real links, not a code fence; `python3 bin/ai-doc-reachability --repo . --base 84fa7b3f~1` reports zero `supabase` paths (only an unrelated tokeneconomizer file). |
| 2. Not in skills index; no owner/retirement path | HALF FIXED | Listed in `docs/skills-map.md:63-64` ("Vendored from supabase/agent-skills"). No owner, upstream-sync, or retirement line exists. |
| 3. Globally installed upstream guidance contradicts POP shared-db workflow | STILL REAL | Not in `config/skill-scope.json` → installs globally. `skills/shared/supabase/SKILL.md:~137-146` still says change schema with `execute_sql` / `supabase db query` "directly on the database" and `supabase db pull --local --yes`. `grep shared-db skills/shared/supabase*` → no hits: nothing tells an agent POP's shared database follows `shared-db-change` instead. |

The issue carries `fixer-deferred` (automatic fixer deferred to `u2giants` because of overlap with
unrelated open PR #671 "Require lower-cost implementation delegation"; that overlap is not real for this
work — #671 does not touch these files). Worth doing under skinny: yes, it is two short prose edits, no
new tools or checks.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Precedence note in both vendored skills | ⬜ open | — |
| 2 Owner/sync/retire line in skills map | ⬜ open | — |
| 3 Verify, PR, merge, close #2314 | ⬜ open | — |

Fresh session starts at Step 1. Handoff: none created (planning-only, read-only run; the implementer
should add `HANDOFF.d/<UTC>-<machine>-<agent>-2314-supabase-precedence.md` linking here if work is left unfinished).

## 1. Ultimate goal

When any AI session on any of Albert's machines picks up the generic Supabase skill, it must not be
talked into editing POP's one shared production database directly. POP's own rule — structure changes
go through `popcre/shared-db` by branch and PR, production read-only — must visibly win. The generic
skill stays useful for everything else. **If a step conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is

`popcre/ai-devops` (public) is Albert's AI toolkit: skills, global instructions and helper scripts
installed onto every machine by `bin/ai-install-skills`. Skills in `skills/shared/` install for Claude
and Codex everywhere unless scoped in `config/skill-scope.json`. POP runs one shared Supabase project for
all apps; its structure is owned by `popcre/shared-db` and the `shared-db-change` skill
(`skills/claude/shared-db-change/SKILL.md`, `skills/codex/codex-shared-db-change/`).

## 3. Trigger

GLM advisory review on PR #2313 (run 41530874809), filed automatically as #2314 with label `review-finding`.

## 4. Scope

In: a short local-precedence note at the top of both vendored SKILL.md files; one owner/sync/retire
sentence in `docs/skills-map.md`; closing #2314.
NOT in: scoping the skills to particular repos (rejected below); rewriting upstream content; any new
check, test, waiter, or CI job; touching PR #671; changing `shared-db-change`.

## 5. Current state of the code

Findings 1 and partially 2 were fixed after #2313 merged (see Verdict table). Nothing for finding 3 exists.
`skills/shared/supabase/SKILL.md` frontmatter ends line 7; body starts `# Supabase` / `## Core Principles` (line 11).

## 6. Key findings

- Vendored text at `skills/shared/supabase/SKILL.md` "Option B: Imperative migrations" is correct for a
  *local* Supabase stack but dangerous if an agent applies it to POP's shared project.
- `supabase-postgres-best-practices` is design/performance guidance; it is safe but its description says
  "before writing or changing anything that lives in a Postgres database", so it needs the same one-line pointer.

## 7. Rejected approaches

- **Scope the skills via `config/skill-scope.json`** — rejected: the skills are useful in every app repo
  (auth, RLS, client code), and scoping would hide them where they help. Protected-skill policy also keeps
  scope edits a heavier change.
- **Delete or rewrite the upstream Option B text** — rejected: diverges the vendored copy and is lost on resync; a precedence note is enough.
- **Add a CI check that the note exists** — rejected by owner ruling 2026-10-30 (only data-damage/secret-leak checks may block; no new moving parts).

## 8. Decisions

Locked: prose-only fix; note placed above upstream content so it survives a reader skimming; `shared-db-change` is authoritative for POP's shared database.
Open: exact wording (keep each note under ~6 lines).

## 9. Steps

**Step 1 — precedence notes.** In a fresh worktree off `origin/main`:
- `skills/shared/supabase/SKILL.md`: immediately after the frontmatter (before `# Supabase`), insert a block like:
  > **POP local rule (overrides this skill).** POP's shared Supabase project (every app's database) is
  > changed only through `popcre/shared-db` by branch and PR — load `shared-db-change` (Codex:
  > `codex-shared-db-change`) first. Never run `execute_sql`, `apply_migration`, `supabase db query`, or
  > `supabase db push/pull` against it; production is read-only. The local-iteration advice below applies only to a local stack.
- `skills/shared/supabase-postgres-best-practices/SKILL.md`: same place, a two-line version pointing schema changes on POP's shared database to `shared-db-change`.
Do not alter the `description:` frontmatter (trigger tests depend on it).
Gate: `grep -n "shared-db-change" skills/shared/supabase*/SKILL.md` shows both; frontmatter still parses (`bash tests/test-ai-install-skills.sh` green).

**Step 2 — owner line.** In `docs/skills-map.md` under `## Supabase & Postgres` (line 59), add one sentence:
owner ai-devops maintainers; resync from upstream `supabase/agent-skills` by re-copying and re-applying the
POP local-rule block; retire if Supabase stops being POP's database or upstream adds an equivalent override hook.
Gate: `python3 bin/ai-doc-reachability --repo . --base origin/main` passes.

**Step 3 — land.** Commit as Albert (`git var GIT_COMMITTER_IDENT`), message referencing `Fixes #2314`, push branch, open PR, run `bin/ai-pr-wait <pr>` in background, merge when required checks pass (reviews advisory). Gate: PR merged, #2314 closed automatically; live proof = `bin/ai-install-skills` on this machine then `grep -n "POP local rule" ~/.claude/skills/supabase/SKILL.md` hits. Add a signed (`$AI_GH_SIGNATURE`) closing comment on #2314 citing the merge SHA.

## 10. Tests

No new tests (prose). Must stay green: `tests/test-ai-install-skills.sh`, `tests/test-skill-trigger-policy.sh`, CI `doc-safety`.

## 11. Constraints / gotchas

Never push to `main`; worktree per task; public repo — no project refs (use the wording above, no IDs);
reviews never gate; drop no checks. Task class: `prose`.

## 12. Access

`gh` authenticated as needed for `popcre/ai-devops`; no secrets required.

## 13. Done + risks

Done: both notes merged, skills-map line merged, CI required checks green, installed copy shows note, #2314 closed with SHA.
Risk: a future upstream resync overwrites the note — mitigated by the skills-map resync instruction. Rollback: revert the PR.
Open question for Albert: none.

## Self-audit

1. Fresh session can execute without asking? Yes — Verdict, §5, §9 give files, lines, wording, gates.
2. All background incl. rejected paths? Yes — §6, §7, and the #671 deferral explanation in Verdict.
3. Goal clear enough to steer? Yes — §1 states the single outcome and goal-wins rule.
Gap noted: no HANDOFF.d link (run was read-only by instruction); §STATUS tells the implementer to add one.
