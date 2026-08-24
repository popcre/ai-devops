# IMPLEMENTATION PLAN — shared reviewer evidence integrity (2026-08-21)

Handoff: [`HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md`](HANDOFF.d/2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md)

## STATUS

| Step | Work | Status | Evidence |
|---|---|---|---|
| 1 | Freeze hostile fixtures and baseline | ✅ complete | `tests/verification/reviewer-shared-integrity/20260821T120657Z/summary.txt` |
| 2 | Bind packet seal to names and boundaries | ✅ complete | 87 packet tests pass |
| 3 | Refuse outside-target links in snapshots | ✅ complete | snapshot hostile-link guard and suite |
| 4 | Correlate incident evidence exactly | ✅ complete | 28 incident tests pass; duplicate exact matches and non-owned paths are refused |
| 5 | Make freshness fail closed | ✅ complete | 15 scoreboard tests pass; run/session/caller identity is preserved |
| 6 | Govern every active provider | ✅ complete | 35 preflight tests pass; explicit doctor/caller contracts are enforced, Gemini stays quarantined, and Qwen qualification is bound to both the exact wrapper revision and installed runtime hash |
| 7 | Land and install | ✅ complete | landed on GitHub `main`, exact-head independently approved, CI green, and installed on Ubuntu production; shared suites re-verified 2026-08-24 (packet 90, sandbox 71, preflight 36, scoreboard 15, all 0 failures) |

All steps are complete; this plan is retained as a decision record.

## 1. The ultimate goal — what we are trying to achieve

Every review must be traceable to the exact code, files, reviewer run, and result
it claims. Missing identity must fail visibly, never be guessed. If any step below
conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`u2giants/ai-devops` is a public Bash/PowerShell toolkit on `main`. These helpers
prepare private review copies and evidence for Grok, Kimi, GLM, Gemini, Muse,
Qwen, Codex, and DeepSeek. It has no hosted service or deployment.

## 3. What triggered this work

The 2026-08-20 audit found four shared failures: incident capture can select an
unrelated newest run; packet hashes omit names/boundaries; snapshot copying can
follow an untracked link outside the repository; and the scoreboard defaults
unknown identity to current. Reproduce from `bugs.md` findings 2, 14, 15, 17,
and 24.

## 4. Scope — in and out

In: `ai-review-packet`, `ai-review-sandbox`, `ai-reviewer-issue`,
`ai-review-scoreboard`, `ai-review-preflight`, their tests/docs, and provider
registration. Out: provider-specific completion rules, model choice, permission
profiles, application repos, databases, and production systems.

## 5. Current state of the code

The source now seals packet names, lengths, and contents; rejects snapshot links
that escape; refuses missing or ambiguous incident identity; treats unknown
freshness as unusable; and reports unsupported provider health as unknown.
The status table above is authoritative. GitHub landing and installed-command
identity are verified by the landing session rather than frozen in this plan.

## 6. Key findings and root cause

All four helpers treat absence as permission to infer: concatenation implies file
identity, ordinary copy implies containment, recency implies correlation, and no
proved mismatch implies freshness. Trustworthy evidence requires explicit,
canonical identity at every boundary.

## 7. Approaches considered and REJECTED

- Keep “newest” as fallback: rejected because it already attached the wrong run.
- Hash a manifest only: rejected unless every file name, length, and digest is
  represented and the manifest itself is sealed.
- Follow links but warn: rejected because secrets may already be copied.
- Treat unknown freshness as current: rejected; unknown is not approval.
- Add provider names without contract tests: rejected because a green dashboard
  could still misrepresent unsupported metadata.

## 8. Design decisions already made (2026-08-21)

LOCKED: fail closed; never substitute nearby evidence; preserve additive packet
access; never expose outside files; keep provider selection manual. OPEN: exact
manifest encoding and whether unsupported providers report `unknown` or are
rejected, provided neither appears healthy/current.

## 9. The plan — numbered, ordered steps

1. Add hostile baseline fixtures to the five named test files before changing
   code: renamed files, empty files, outside symlink, two repositories/two runs,
   missing head, dirty-tree drift, and every provider. Save command output under
   `tests/verification/reviewer-shared-integrity/<UTC>/`. You'll know it worked
   when each new test fails for the intended reason on the baseline.
2. Replace `hash_packet()` with a deterministic inventory containing relative
   path, byte length, and per-file digest; reject added, removed, renamed, empty,
   or changed files. You'll know it worked when all packet hostile fixtures pass
   and a rebuilt packet verifies on Windows and Ubuntu path forms.
3. Change `copy_untracked()` to preserve safe links without dereferencing, or
   fail before copying any link whose resolved target leaves the source root.
   You'll know it worked when the outside sentinel never appears in the snapshot.
4. Extend `ai-reviewer-issue record` with explicit run/session/repository/caller
   join fields; copy only exact matches and label missing evidence. You'll know it
   worked when an unrelated newer run is ignored.
5. Make scoreboard state `current|stale|unknown`; bind it to head plus packet/tree
   identity, and never count `unknown` as usable. You'll know it worked when
   missing repo/head and later dirty edits report unknown/stale.
6. Define one provider metadata contract and register all active reviewers in
   preflight/scoreboard, explicitly marking unsupported fields null/unknown.
   You'll know it worked when each provider has a valid and invalid fixture.
7. Update `docs/reviewer-issues.md`, `docs/architecture.md`, `AGENTS.md`, affected
   skills, and `bugs.md`; run installer and compare installed/source hashes.
   You'll know it worked when docs name no unsupported guarantee.

Natural cut point: after Step 4, use `fresh-session` and re-read Steps 5–7.

## 10. Tests required

Extend `tests/test-ai-review-packet.sh`, `test-ai-review-sandbox.sh`,
`test-ai-reviewer-issue.sh`, `test-ai-review-scoreboard.sh`, and
`test-ai-review-preflight.sh` with the exact hostile cases above. Rerun all five
plus `test-ai-grok-review.sh`, `test-ai-kimi.sh`, `test-ai-glm.sh`,
`test-ai-muse.sh`, `test-ai-gemini.sh`, and `test-ai-qwen.sh`.

## 11. Constraints, standing rules, and gotchas in force

Work on `main`; preserve unrelated dirty files; use `apply_patch`; no broad
staging or force-push. Review packets remain additive, not sealed rooms. Never
follow outside links or publish private evidence. GPT-5.6 stays low/medium.

## 12. Access and environment

Primary checkout: `C:\repos\ai-devops`; Git Bash runs Bash tests; PowerShell is
the host shell; `gh` is authenticated. No secrets, provider spending, database,
or production access is required for offline work.

## 13. Definition of done + risks and open questions

Done means hostile tests and all affected suites pass, exact-head independent
review has no unresolved Critical/High/Medium finding, identity is verified,
only owned files are committed, `main` is pushed and remote SHA proven, installed
helpers match source, docs/plans/handoff are current, and tracked issues are
closed with artifacts. There is no deployment. Roll back with the landed commit.
Risk: manifest format changes can strand old packets; version it and reject old
formats explicitly. Open: choose the smallest cross-provider metadata schema
that never invents unavailable facts.

## Mandatory self-audit

1. Yes. Sections 2–6 define the system and exact defects; Section 9 gives files,
   order, dependencies, and proof gates.
2. Yes. Sections 7–8 preserve rejected shortcuts and locked safety decisions;
   Sections 10–12 preserve tests and environment constraints.
3. Yes. Section 1 makes exact, non-inferred evidence the deciding goal if an
   implementation detail proves wrong. All checklist items pass.

