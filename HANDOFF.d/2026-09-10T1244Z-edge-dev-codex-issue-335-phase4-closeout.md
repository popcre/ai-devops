---
issue: 335
status: OPEN
owner: codex/issue-335-phase4-closeout-20260910
---

# HANDOFF — Issue #335 Phase 4 closeout after 12 of 17 repository landings (updated 2026-09-10, edge-dev/codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

One exact authority decision is open. Five green candidates cannot be
merged under the current instruction because each merge starts existing
production automation. Albert must explicitly authorize the five merges and
their automatic production releases. For Ansible that authorization must name
the real serialized Phase 1 apply against the `hetzner` production target.

Already settled — do not re-ask:

- All 17 canonical repositories remain in scope; central enforcement stays in `popcre/ai-devops`, and consumer declarations may strengthen but never weaken it (2026-09-08).
- Raw transcript archives and licensed source rows must never be opened (2026-09-08).
- Issue #335 DesignFlow acceptance lands directly on current `sandbox-albert`; automatic sandbox builds caused by the authorized push are observed read-only. Codex does not operate deployment controls (2026-09-09/10).
- DesignFlow PRs to `develop` remain Uma-owned and must not be self-merged. Issue #335 acceptance does not wait for those merges (2026-09-09/10).
- Phase 5 cannot start until all 17 coverage rows are landed and Phase 5 is re-read for drift (2026-09-09).
- Issue #335 must remain open through Phase 5. It was incorrectly closed as
  completed at `2026-09-10T12:49:50Z` while five Phase 4 rows remained unlanded;
  reopen it before continuing closeout.
- PR #330 is unrelated Qwen work and must not be cancelled, rerun, or diagnosed here (2026-09-09).

## 1. What this application is

`popcre/ai-devops` is POP Creations' public engineering-governance and recovery toolkit. Issue #335 makes AI task scope machine-checkable across 17 repositories so a small task cannot silently trigger a riskier review, deployment, database, infrastructure, production, UI, or private-data workflow.

The central version-1 engine is `bin/ai-task-gates`. Consumer repositories receive only a thin `.ai-devops/task-gates.json`, a focused refusal/rollback fixture, a read-only GitHub verification workflow, a routing pointer, and evidence. DesignFlow services run on Google Cloud Run in project `lithe-breaker-323913`, region `us-east4`; their existing `sandbox-albert` pushes automatically invoke Cloud Build.

## 2. What we set out to do this session, and why

This continuation resumed Phase 4 at `designflow-data-syncing`, after backend and BFF were already complete. The objective was to preserve each service's stronger local boundaries while landing the smallest repository-specific policy and proving refusal, rollback, unchanged tests, exact-head review, GitHub gates, build identity, and ready sandbox revision.

The session completed data-syncing. A concurrently finishing predecessor also
landed Item Master during closeout. A later continuation reconciled Item Master,
completed tracking, prepared all Step 4.2 repositories, and completed Step 4.3
source work. Twelve policies are now landed. Five green candidates remain held
because their merges start production automation. No database, application-data,
deployment-control, infrastructure, or production mutation occurred during the
rollout work recorded here.

## 3. Current state — what is true right now

Phase 4 remains PARTIAL at 12/17; Issue
[#335](https://github.com/popcre/ai-devops/issues/335) is incorrectly CLOSED as
completed. Phases 0–3 remain complete. The authoritative status table is in
`plan_cross_repo_routing_and_gate_enforcement.md`; the preceding detailed
handoff is `HANDOFF.d/2026-09-10T0400Z-edge-dev-codex-issue-335-phase4-continuation.md`.

### Later continuation — current authoritative state

- `designflow-item-master` independent review was reconciled and approved at
  `987bb145`; do not repeat it. `designflow-tracking` landed on
  `sandbox-albert` at `c3531b11`, with its local suite, exact-head review,
  GitHub verification, automatic Cloud Build, and ready sandbox revision
  verified. PR #38 to `develop` remains Uma-owned and is not a Phase 4 blocker.
- `u2giants/licensor-source-data#70` merged as `1413b0c1`; privacy/refusal
  verification passed and no licensed rows were opened or transmitted.
- `u2giants/ai-devops-transcripts#1` merged as `a36b4777`; privacy/refusal
  verification passed and no raw transcripts were opened or transmitted.
- `popcre/infrastructure#28` merged as `222c7a6d`; verification passed and no
  apply or resource mutation occurred.
- Five exact-head candidates remain unmerged solely because their merges start
  production automation: POP CRM #8 (`ee319d44`), POP PIM #6 (`d5ab6897`),
  PopDAM #122 (`e41c9f56`), Backrest Wiz #7 (`27f4c72f`), and Ansible #14
  (`7c2bebec`). All GitHub checks are green. POP CRM's exact-head review
  approved subject to the production-release boundary; POP PIM and PopDAM
  reviews found their policies sound but rejected shipping without production
  authority. Do not rerun those reviews unless a head changes. Backrest's
  independent reviewer could not qualify after three bounded attempts and is
  the only unresolved reviewer proof. Ansible's task-gate, Linux lint/syntax,
  and read-only host-diff checks passed; exact-head review found the source
  internally sound but correctly rejected shipping because merging runs the
  real production Phase 1 apply.

### DesignFlow data-syncing — complete

- Landed directly on `sandbox-albert` at `7d961fe5fa3a12059de7cd1080ab98636d232eb9`; open PR [#33](https://github.com/popcre/designflow-data-syncing/pull/33) targets `develop` and remains Uma-owned.
- Local evidence recorded in `docs/verification/phase-4-task-gates-rollout.md`: 24/24 focused checks, central schema validation, 18/18 Jest suites, 151/151 tests, zero snapshots.
- Exact-landed-head Claude Opus 5 review approved `7d961fe` against direct parent `ce1e3d807f46d28198af632f453eb01d377a1f51` (run `20260910T044419-201250-29522`).
- GitHub runs passed at the exact head: Task Gates push `34438207691`, Task Gates PR `34438223357`, and Forbid Shared DB Bypass PR `34438223363`.
- Automatic Cloud Build `b2be4099-829c-4af1-9c3a-359548bfc4dc` succeeded with digest `sha256:ee589bf18906e707ca3d35c40f9d5f0898f65887f5ab17e3b1c2890dba04b607`.
- Ready revision `popcre-albert-sync-sandbox-00101-54z` serves 100% of traffic and uses the image tagged with exact commit `7d961fe`.

### DesignFlow Item Master — complete (original closeout snapshot retained)

- Remote `sandbox-albert` is `987bb1453f1dd91e7e0a77926228adfeb3b0e288`; open PR [#55](https://github.com/popcre/designflow-item-master/pull/55) targets `develop` and remains Uma-owned.
- The committed evidence file reports 27/27 focused checks, central schema validation, 38/38 Jest suites, and 230/230 tests with no skips or snapshots.
- Exact-head GitHub runs passed: Task Gates push `34439328669`, Task Gates PR `34439354866`, and Forbid Shared DB Bypass PR `34439354982`.
- Automatic Cloud Build `b01a6d8d-4779-43d1-8e53-1a2c86761dfd` succeeded. Ready revision `popcre-albert-item-sandbox-00124-772` serves 100% of traffic using the image tagged with exact commit `987bb14`.
- The isolated Item Master worktree disappeared during the original closeout,
  but the later continuation completed a new exact-landed-head review for
  `987bb145` and received approval. That former evidence gap is closed; do not
  repeat implementation, tests, review, GitHub runs, or build verification
  unless the landed head changes.

### Remaining Phase 4 work

- Reopen Issue #335; its completed closure conflicts with the plan and five open
  rollout PRs.
- Obtain Albert's explicit authorization for the five production-triggering
  merges. For Ansible, name the serialized Phase 1 apply to `hetzner`.
- Immediately re-resolve each PR head, base, checks, main movement, and automatic
  release behavior; merge only the authorized exact head, then verify the live
  production result. Do not infer authorization from an old message.
- Resolve Backrest's missing qualified independent review before its merge if
  reviewer qualification is available; do not weaken or bypass the reviewer
  gate merely to finish the row.
- Update central `config/repository-coverage.json` only after all five land,
  record all 17 evidence rows, and run the final mixed/missing guard. Do not
  start Phase 5 before this passes.

The original closeout was documentation-only. This later documentation audit
updates this handoff and the authoritative plan together so their status and
restart point match live GitHub evidence.

## 4. Everything we tried that did NOT work

- The prepared data-syncing worktree was shared with a predecessor task. That task committed and amended while this session was testing/reviewing, causing review-SHA drift (`dc41e0c`, `b05c83f`, `bd645bc`) and a pre-push collision. The exact-parent guard prevented overwrite. Always inspect running processes and remote heads before amend/push; use a new detached worktree for exact-landed-head review.
- The first data-syncing review rejected two real gaps: protected runtime classes omitted `local-tests`, and `index.js` was protected while the real API-key comparison in `helpers/api-key-auth.js` was not. Both were fixed. The final landed policy also protects `config/http.js` and requires local tests for shared-db-class changes.
- A focused fixture run exceeded the 30-second output window because identity resolution traversed the mirrored `shared-db/` tree. It was not a test failure. Preserve the returned session id and continue it with bounded polling; the completed result was 24/24.
- The data-syncing remote advanced from `ce1e3d8` to `7d961fe` immediately before this session's push. The guard stopped the push. Inspection proved the concurrent commit was the intended rollout, so the session reviewed the landed SHA instead of force-pushing or replaying it.
- During closeout, the prepared Item Master worktree vanished and remote `sandbox-albert` advanced from `69ec6c4` to `987bb14`. This was another intended rollout landing, not data loss; live GitHub and Cloud Run evidence were re-resolved read-only.

## 5. Root causes and key findings

- The correct high-risk paths come from the service's actual enforcement code, not from generic copied globs. Data-syncing required `helpers/api-key-auth.js`, `config/http.js`, database connection/pool files, `config/table-schema-map.js`, model shape, and its mirrored `shared-db/` tree.
- Long-running exact-head reviews and shared worktrees make SHA drift likely. A verdict is valid only for the commit named in the report; the reliable recovery is a fresh detached worktree at the landed remote head and a direct-parent review brief.
- Automatic sandbox deployment is an accepted consequence of the authorized branch push, but a green build alone is insufficient. Acceptance records exact commit, GitHub jobs, build id/digest, ready revision, and 100% traffic through read-only queries.
- Item Master is landed, live, and independently approved at exact head
  `987bb145`; its former missing-artifact gap was reconciled and must not be
  repeated.
- The open shared-db orchestrator marker `u2giants/shared-db#2669` belongs to another active orchestrator, not this session. Do not modify or close it.

## 6. Exact next steps

1. Start from a fresh current `origin/main` ai-devops worktree; read `AGENTS.md`,
   the plan STATUS table, this handoff, and the earlier 0400Z handoff. Re-resolve
   Issue #335 and the five open PRs. Reopen #335 because its current completed
   closure is contradicted by the plan and unlanded rows.
2. Obtain the exact current-chat production authority described in §0. Without
   it, keep all five PRs open and do not trigger their releases or Ansible apply.
3. Re-resolve and merge POP CRM #8, POP PIM #6, PopDAM #122, Backrest Wiz #7,
   and Ansible #14 only within that authority. Preserve every repository's
   existing gate; for Backrest, resolve the unavailable qualified-review proof
   rather than bypassing it. Verify each automatic production release or apply
   through the repository's real acceptance evidence.
4. Update all 17 central coverage rows with policy version, landed commit/PR,
   routing before/after, trigger result, local verification, and remaining
   exception. Re-run the four-pilot suite only if the central schema changes.
   Phase 4 is complete only when the mixed/missing guard passes with no
   incomplete row.
5. Only then re-read every Phase 5 step through plan completion, record drift,
   write the next handoff, and stop. Do not start Phase 5 in this session.

## 7. Constraints and gotchas in force

- Fresh isolated current-upstream worktree per repository. Preserve dirty canonical checkouts and concurrent branches; never reset, clean, stash, force-push, broad-stage, or self-merge DesignFlow.
- Declare task class before edits and recheck before review, push, wait, merge, deployment, database, infrastructure, or production actions. Consumer declarations only strengthen central version 1.
- No raw transcripts, licensed rows, secrets, private evidence, database writes, application-data writes, deployment-control changes, infrastructure mutation, or production mutation.
- Use `C:\Program Files\Git\bin\bash.exe` on Windows. Preserve session ids for commands exceeding the 30-second output window.
- Exact-head DesignFlow review briefs must name the candidate commit, direct parent, and owned file list; do not review the whole divergent sandbox-to-develop history.
- Reopen and keep Issue #335 open. Do not start Phase 5, close #159/#166, or change shared installed commands before the 17-row Phase 4 gate passes.

## 8. Access and environment

- Host: EDGE-DEV, Windows 11. GitHub CLI, Git, Google Cloud CLI, Node/Corepack, and reviewer wrappers were authenticated during this session.
- Git identity must be `Albert Hazan <u2giants@users.noreply.github.com>`.
- Google Cloud project `lithe-breaker-323913`, region `us-east4`; cloud queries in this rollout are read-only.
- Data-syncing service: `popcre-albert-sync-sandbox`. Item Master service: `popcre-albert-item-sandbox`.
- Formal review entry: `ai-review claude final-check` from Git Bash with a private ignored `AI_REVIEW_BRIEF_FILE` under `.ai/reviews/`.
- Secrets, if ever needed outside this rollout, live in 1Password vault `vibe_coding`; no secret is needed for Phase 4 and none was printed or committed.

## 9. Open questions and risks

- The owner decision in §0 is open. Do not merge the five production-triggering
  PRs until Albert explicitly authorizes their automatic releases and the
  Ansible Phase 1 apply to `hetzner`.
- Issue #335 is closed as completed even though Phase 4 is 12/17 and five rollout
  PRs remain open. Reopen it before continuing closeout.
- Remote branches may advance between testing and push. Treat every SHA outside the completed evidence above as historical until fetched immediately before action.
- A future repository may reveal a genuine conflict between local rules and central policy. Stop only that repository, continue safe independent rows, and ask Albert only if avoiding a weakening requires a materially different outcome.
- Central coverage evidence has not yet been updated with the completed DesignFlow rows. Avoid changing the shared schema unless a common gap is proven; any schema change requires rerunning all four pilots.

## Self-audit

1. Yes. Sections 1–3 explain the system, purpose, exact commits, PRs, tests, jobs, builds, revisions, traffic, and unfinished scope for a newcomer.
2. Yes. Sections 4–5 preserve collision history, rejected review findings,
   bounded-wait behavior, exact-head drift, and Item Master's completed
   review-proof reconciliation.
3. Yes. Sections 0–9 cover background, goal, intended result, current Git/deploy state, failures, findings, constraints, access, risks, and ordered verification gates.
4. Yes. Each step in §6 ends with an observable success condition and identifies repository, branch route, or evidence required.
5. Yes. Sections 1, 3, 7, and 8 define the repositories, engine, branches, services, host, project, region, review entry, and evidence identifiers.
6. Yes. A line-by-line sweep of §§1–9 found exactly one current owner decision:
   §0's production authority for five merges, including the named Ansible apply.
   All other owner references are settled decisions or bounded future conflicts.

Final synthesis after the later audit: a brand-new developer can continue from
§6 without chat; §§3–5 preserve the operational evidence and dead ends; §§0–9
cover every required execution dimension; and §0 now exposes the one real owner
decision instead of incorrectly claiming there are none.
