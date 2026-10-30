issue: popcre/shared-db#5150
status: OPEN
owner: awaiting owner approval; then any implementing session (unassigned)

# Handoff — shared-db gate-trim plan (published, awaiting owner approval)

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

- **Approve or reject the gate-trim plan.** Albert asked for structural migrations to take minutes of gating, not ~2 hours. The plan targets median open→merge of ≤25 minutes (down from a measured 147) by cutting duplicate paperwork and duplicate check runs only. He must accept the target and the eight stage cuts before anything is implemented. The question, in his words: is a 25-minute median with these cuts (and nothing on the production path touched) what he wants?
- If he rejects a specific cut, that stage is dropped or re-scoped — the plan says which risk each cut reopens, so he can pick.

## 1. What this application is

`popcre/shared-db` is the canonical repo for the SHAPE of POP Creations' shared Supabase database (migrations, contract tests, CI workflows, coordination tooling, rulebook) used by CRM, DAM, PM/PIM and DesignFlow. The work here is a **plan to trim its migration gates** — repository maintenance (workflows/scripts/docs), not a schema change. The plan file lives in `popcre/ai-devops` (the AI-toolkit repo where `plan_*.md` files are published) per owner instruction. Tracker issue carries the plan as its body: https://github.com/popcre/shared-db/issues/5150

## 2. What we set out to do this session, and why

Albert asked (2026-10-30): pull the latest shared-db, deep-dive its change process, propose what to cut, pull real numbers from ~20 merged migration PRs, classify every gate (keep / merge / make automatic / delete) with the one real risk each cut reopens, write it as an implementation plan in popcre/ai-devops, and open one issue. Then he asked for the plan as a GitHub issue and a Muse second opinion. Nothing about the gates themselves was to change — the session ends at a plan he can approve.

## 3. Current state — what is true right now

- Plan published and revised: https://github.com/popcre/ai-devops/blob/main/plan_shared-db-gate-trim.md (merged `58f7b5a5`, 2026-10-30 12:35 PM EST; initial publication `cc16ccbe`). STATUS table at the top — every stage row is `⬜ open`.
- Tracker issue with the full plan as body and per-stage checklist: https://github.com/popcre/shared-db/issues/5150 (open; closeout comment posted 2026-10-30).
- Muse Spark 1.3 review (session `gate-trim-plan-review`, run via `ai-muse`): `VERDICT: REVISE`, all findings folded in; record in the plan's "Second opinion" section.
- Registration: the plan is linked from https://github.com/popcre/ai-devops/blob/main/AGENTS.md ("Specialized task router") and https://github.com/popcre/ai-devops/blob/main/docs/task-router.md (first row).
- Ownership: no claims, no lanes, no locks held. `ai-shared-db-closeout-check --session-id ses_ffe5e72b8ff9dffeF1gOLC8t7v` returned `ok: true`, 0 blocking claims, 0 blocking stages (receipt in session evidence `closeout-check-receipt.json`).
- Nothing applied to preview or production. No migration file created or edited anywhere.
- Facts checked 2026-10-30 1:10 PM EST: popcre/shared-db `main` = `a576e1e21`; newest migration `20261030125352_master_data_user_row_delete.sql`. The plan's measurements were taken at `af8bd6b8f` (planning baseline); unrelated work has since moved main.

## 4. Everything we tried that did NOT work

- `bash` on this Windows machine (edge-dev) resolves to WSL with **no installed distro** — "Windows Subsystem for Linux has no installed distributions". Any ai-devops bash tool (`bin/ai-doc-safety`, `bin/ai-pr-wait`) must run through Git Bash explicitly: `& "C:\Program Files\Git\bin\bash.exe" bin/...`. Do not call plain `bash`.
- A background PR waiter via PowerShell `Start-Process` (redirecting Git Bash) was killed by the tool layer. Replaced with bounded inline polling (`Start-Sleep` + `gh pr checks`) — acceptable for docs PRs; for long CI use `bin/ai-pr-wait` in a real terminal.
- First plan draft embedded the raw production Supabase project ref in prose; `bin/ai-doc-safety` refused it (public-boundary invariant). Fixed by referencing the `PRODUCTION_PROJECT_REF` constant's file instead of repeating the value. ai-devops is public — never write project-shaped identifiers in prose there.
- First plan draft marked `check-live-proof-probe.mjs` as "deterministic" (safe to skip re-runs) based on its name. It is not: it parses the work issue's `db-work-scope` block through the GitHub transport, so it is LIVE state. Muse caught this. Any guard classification must be justified from the script body.
- Failure-census arithmetic in the first draft (class rows summing to 36 of 40 claimed failed runs) did not add up. The plan now carries an explicit caveat and says how to re-derive exact counts from `gh run list` before citing numbers.
- A `gh pr create` with an inline `--body` string containing quotes broke PowerShell argument parsing. Use `--body-file` with a UTF-8 file.
- `git worktree add` + later squashed merge made the original branch `mimo/gate-trim-plan` an awkward base (three-dot diff would re-show the whole file). Revision work went on a fresh branch cut from `origin/main` (`mimo/gate-trim-plan-v2`) — same pattern for any future plan revision.

## 5. Root causes and key findings

- **95% of migration-PR wall clock is waiting, not checking** (28 merged PRs, 2026-10-18→30): median open→merge 147 min, median CI 8 min, median green→merged queue wait 34 min. The "~2 hours" Albert reported is real and is queue/lock/paperwork, not slow tests.
- **Paperwork causes most failures** (at least 28 of 40 failed runs): documents-only authorization (global mutex contention, 15 runs), author-lease setup (7), static SQL guards (6). Each failure costs a full re-push cycle.
- **The only real-defect catcher is the ephemeral replay + contract tests** (7 runs / 6 PRs). It stays required at full breadth.
- Deterministic static guards run up to 7× per PR across workflows; lease/live-proof guards run 3× inside one lock hold. The plan's stages 4–5 dedupe these (re-run only on drift / once per hold).
- Review is already advisory (owner ruling 2026-10-29); `check-exact-head-approval.mjs` no longer exists on shared-db main. Docs citing it are historical.

## 6. Exact next steps

1. Albert approves (or amends) the plan at https://github.com/popcre/shared-db/issues/5150 — that issue IS the plan.
2. On approval: implement **stage 1** (one-shot claim preflight) as ONE ordinary-maintenance PR in `popcre/shared-db` — plan §9 stage 1 names the files (`scripts/manage-migration-author-lanes.mjs`, `scripts/lib/lanes/claims.mjs`) and the two named tests. Update the plan's STATUS row with a real artifact (test name + run id), and tick the stage checkbox on the issue.
3. Then stages 2→9 in order (sequencing constraints in plan §9: 4/5 are a stacked pair — revert 5 before 4; 8 depends on 4's binding helper; 6 must land both refusal sides in one PR; stage 9 is last and verify-only).
4. Every stage gets `- [ ] live proof` on the SAME issue #5150; the final acceptance (≤25 min median on ≥5 PRs with the queue-wait split) is the issue's live-proof item.

## 7. Constraints and gotchas in force

- No gate, rule, or workflow changes until Albert approves. Then only what stage N says.
- Production apply path (preview rehearsal, business-risk gate, serial lane, freeze, catalog verification, live proof) is untouched — plan stage 9 audits this.
- Ephemeral replay + full `supabase/tests` stays required; exact-object claims and permanent version reservation stay; review stays advisory.
- One stage = one PR = one revert. Revert, don't patch forward.
- Coordinate with `plan_shared_release_hold_reduction.md` (#3779) steps 4–5 before landing stages 4/5 (same files).
- Rulebook files (AGENTS.md, docs/agents/**) are NOT documents-only — full engineering treatment if touched.
- Sign every GitHub post: `Posted by MiMo chat <id> on <machine>`. Windows (edge-dev) and Linux both run this tooling — no GNU-only assumptions.

## 8. Access and environment

- `gh` authenticated on edge-dev; repos popcre/shared-db, popcre/ai-devops. Bash only via `C:\Program Files\Git\bin\bash.exe`.
- `ai-muse` available (doctor OK; Muse Spark 1.3); named review session `gate-trim-plan-review` persists (`ai-muse show gate-trim-plan-review`).
- Secrets: none appeared this session. 1Password vault `vibe_coding` items referenced by name only ("Supabase CLI Personal Access Token", etc.). Preview identity = repo variable `PREVIEW_PROJECT_REF` only.
- ai-devops worktree `C:\repos\.worktrees\ai-devops-gate-trim` (branch `mimo/gate-trim-plan-v2`) — being retired at closeout; recreate a fresh worktree for any future edit.

## 9. Open questions and risks

- The plan's biggest systemic risk: misclassifying a live guard as deterministic (stage 4). Mitigations and fail-closed defaults are in the plan; roll back a stage if it shows up.
- Sample is 28 PRs over 12 days — a rarer defect class would only be caught by the replay, which is why it stays.
- "Minutes of gating" is interpreted as median open→merge ≤25 min. If Albert meant only active check time (~8 min today), the same stages apply but the headline number changes — stated in the plan §13.

---

## Self-audit

Could a stranger continue from this file alone? Yes — §0 carries the pending business decision, §6 the exact next steps with the issue URL and named files/tests per the plan, §4 the dead ends (Git Bash path, body-file quoting, live-proof misclassification), §7 the non-negotiables. Every file reference is a GitHub URL except tool-session names and the local worktree path being retired (named as such). The plan file (linked) is the build spec; this handoff is the entry point to it. Passes.
