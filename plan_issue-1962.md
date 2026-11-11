---
summary: Plan for issue 1962 Claude permissions denying sleep - already fixed on main by PR 1963; live proof and closing remain.
kind: plan
status: open
read-when: Closing out issue 1962 sleep permission fix
---

# Plan — popcre/ai-devops#1962: Claude permissions deny every `sleep`

## VERDICT (read first): ALREADY FIXED ON MAIN — close the issue after one live-proof check

Evidence (checked 2026-11-04 against main `f2b4f5bd`):
- PR #1963 (MERGED, main `de54e5c2`) is the fix. It touched `config/claude-permissions.allow`, `bin/ai-claude-permissions`, `tests/test-ai-claude-permissions.sh`, `docs/owner-rulings.md`, `AGENTS.md`, `docs/ai-tools-cheat-sheet.md`.
- `config/claude-permissions.allow:43-48` now says a lone `sleep` is legitimate and carries `retire:deny:Bash(sleep:*)`; there is no `deny:Bash(sleep:*)` line left.
- `bin/ai-claude-permissions:18-24` adds the `retire:` mechanism, so already-installed machines lose the bad deny on the next install (fixing the issue's "sticky design" point).
- `tests/test-ai-claude-permissions.sh:20,39,82-91` prove: retired entry never added on fresh install; only the named deny is removed; an *allow* `Bash(sleep:*)` and unrelated denies are kept.
- `docs/owner-rulings.md:61,74-75` records the ruling: lone `sleep` is fine; loop shapes are refused by the pr-poll-guard hook (`tests/test-ai-pr-poll-guard-hook.sh:59` `allows "sleep alone"`).
- Live on edge-dev3 today: `~/.claude/settings.json` contains zero `Bash(sleep` entries; `bin/ai-claude-permissions --check` → "OK all 33 required permission(s) already present".
- Why it is still open: the issue's last comment ties it to a blocked Seafile (`seafile-br`) install that needed a GLM final-check. Under owner rulings 2026-10-29/30 reviews are advisory and never gate, so that review is no longer a reason to keep the issue open. The M2 half was split to #1965 (out of scope).

STATUS
| Step | State | Evidence |
|---|---|---|
| 1 Code fix | done | PR #1963, commit de54e5c2; `config/claude-permissions.allow:48` |
| 2 Tests | done | `tests/test-ai-claude-permissions.sh:82-91` |
| 3 Live proof on one installed machine | done (edge-dev3) | `grep -c 'Bash(sleep' ~/.claude/settings.json` → 0 |
| 4 Live proof on Seafile | open | rerun step below |
| 5 Close issue | open | — |

Fresh session starts at step 4.

## 1. Ultimate goal
AI sessions run by Albert must be able to use a plain `sleep` (e.g. a short pause) without Claude Code hard-refusing it, while hand-written polling loops stay blocked. If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is
`popcre/ai-devops` (public): Albert's toolkit installed on every dev machine by `install.sh`/`update.sh`. Stage "Claude tool permissions" runs `bin/ai-claude-permissions`, merging `config/claude-permissions.allow` into each user's `~/.claude/settings.json`.

## 3. Trigger
GLM final-check of release `54840353` (REVISE, M1): PR #1932 shipped `deny:Bash(sleep:*)`, which blocked every `sleep`, contradicting the guard-hook test, and the installer could never remove it.

## 4. Scope
In: confirm Seafile's installed settings no longer deny `sleep`; close #1962.
NOT in: #1965 (ai-pr-wait default); any reviewer/GLM final-check rerun (advisory only); new hooks, checks, or waiting tools; changing the pr-poll-guard hook.

## 5. Current state of code
All fixed on main (see Verdict). Nothing uncommitted. No code change needed.

## 6. Root cause
A prefix deny rule (`Bash(sleep:*)`) matches any command starting with `sleep`; Claude permission rules cannot express "only in a loop". The installer was add-only, so the deny persisted. Both fixed by #1963.

## 7. Rejected approaches
- Narrower deny patterns for loop shapes: permission globs cannot match loop structure; the hook already does that.
- Hand-editing each machine's settings: not durable; the `retire:` line does it on every install.
- Keeping the issue open for a GLM final-check on Seafile: reviews never gate (owner rulings 2026-10-29/30).

## 8. Decisions
Locked: lone `sleep` allowed; loops refused by hook only (`docs/owner-rulings.md:61-75`); `retire:` mechanism. Open: none.

## 9. Steps
1. On Seafile (`seafile-br`), after its normal toolkit update to any main at/after `de54e5c2`, run `grep -c 'Bash(sleep' ~/.claude/settings.json` and `bin/ai-claude-permissions --check` from the installed checkout. Gate: count 0 for a deny entry (an allow entry is fine), and `--check` prints OK with no `RETIRE` line. If Seafile is unreachable or its install is still blocked for unrelated reasons, record that on #1962 and close anyway with the edge-dev3 proof — the defect is code-level and proven by tests plus one live machine; Seafile's install blocker belongs to its own issue.
2. Post one signed comment (`$AI_GH_SIGNATURE`) on #1962 citing #1963/de54e5c2, the test lines, and the live-proof output; tick the checklist item; close as completed. Gate: `gh issue view 1962 --json state` → CLOSED.

## 10. Tests
No new tests. Must stay green: `tests/test-ai-claude-permissions.sh`, `tests/test-ai-pr-poll-guard-hook.sh`.

## 11. Constraints
Skinny rulings: no new checks, no review gating, no new wait tools. Sign GitHub posts. Times in EST. Do not touch the canonical checkout; read-only verification only.

## 12. Access
`gh` authenticated as the toolkit identity; Seafile reached via its usual SSH alias (`seafile-br`). No secrets needed.

## 13. Done / risks
Done: live check recorded, issue closed. Risk: none to code; if Seafile still shows a deny entry, its install is behind main — run its normal update, do not edit settings by hand.

Handoff link: none created (task was read-only; caller owns registration).

## Self-audit
1. Fresh session could execute without questions? Yes — Verdict, §9 give exact commands and fallback.
2. All background incl. rejected paths? Yes — §6, §7, Verdict "why still open".
3. Goal clear for judgment calls? Yes — §1, and §9 step 1 fallback steers by it.
