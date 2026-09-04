---
issue: 251
status: OPEN
owner: codex/grok-build-1-0-13-251
---

# Grok Build 1.0.13 wrapper-upgrade planning handoff

Plan: [`../plan_grok-build-1.0.13-wrapper-integration.md`](../plan_grok-build-1.0.13-wrapper-integration.md)

## 0. Decisions only the owner can make

None — nothing in this workstream currently needs Albert. The plan resolves
version mechanics and provider behavior through official evidence and bounded tests.
If 1.0.13 cannot preserve a locked capability without weaker safety, stop and put
that single owner decision to Albert before changing the boundary.

Already settled — do not re-ask:

- 2026-09-04: target exactly Grok Build 1.0.13 and integrate all useful additions
  since 1.0.5.
- Existing: preserve the approval reviewer's read-only/exact-head contract and the
  implementation wrapper's isolated patch-recovery contract.
- Existing: issue #249's controlled-shell integration reviewer remains separate and
  unimplemented until its containment gates pass.

## 1. What this application is

`popcre/ai-devops` is Albert's public backup-and-restore toolkit for multi-model
development. It ships provider wrappers, installers, shared skills, documentation,
and offline verification. Work lands directly on GitHub `main`; there is no hosted
application, database, or deployment beyond supported installation.

## 2. What we set out to do and why

Write an execution-ready plan to upgrade the supported Grok Build runtime from the
installed 1.0.5 to exactly 1.0.13 and deliberately integrate every useful wrapper-
facing addition from releases 1.0.6 through 1.0.13. The plan must preserve safety
controls and classify UI-only additions instead of adopting them blindly.

## 3. Current state

- Planning is complete in the linked plan; implementation has not started.
- Tracking issue #251 is open.
- EDGE-DEV reports `grok 1.0.5 (5115b46bc9) [stable]`.
- Planning began from local `main` commit
  `a4cc336f15b7a01bf5842b221c10a65efc738a75`.
- The checkout was already dirty, including concurrent edits to `AGENTS.md`,
  `bin/ai-grok-review`, reviewer tools/tests, plans, skills, and handoffs. Preserve
  all of them and re-resolve ownership before implementation.
- The official xAI changelog identifies 1.0.13 as the 2026-08-28 latest release.
- No Grok update, wrapper change, provider call, configuration change, or installer
  execution was performed in this planning session.
- These plan/router/handoff additions are the only artifacts owned by this planning
  session; implementation remains open after they land on `origin/main`.

## 4. What did not work / rejected paths

No implementation attempt failed because implementation did not begin. The plan
rejects upgrading before evidence capture, tracking latest stable, changing only an
installer hash, removing wrapper guards because of vendor fixes, broad headless
approval, enabling MCPs in the approval reviewer, adopting provider clone/worktree
ownership, and implementing on top of unreconciled concurrent edits.

## 5. Root causes and key findings

- Both provider installers are presence-based: a runnable 1.0.5 is skipped, so
  bootstrap does not guarantee the qualified version.
- `bin/ai-grok-review` has provider-shape assumptions last verified against 1.0.5:
  flags, `inspect --json`, one terminal JSON object, stop reasons, session identity,
  usage/model/cost keys, and child-process completion.
- Wrapper-relevant 1.0.6–1.0.13 changes include headless permission/session handling,
  transient retry, truncation continuation, durable session saves, corrected context
  accounting, MCP startup/retry, Windows paths/worktrees, and background completion.
- Vendor reliability fixes do not prove read-only scope, exact-head identity, remote
  cancellation, owned descendant exit, or cost correctness. Existing guards remain.
- Most visual, prompt, dashboard, voice, menu, and clone conveniences are not headless
  wrapper features. The plan's Appendix A classifies each release family.

## 6. Exact next steps

1. Re-read the linked plan's STATUS table, current `AGENTS.md`, issues #251 and #249,
   and current dirty tree. Reconcile ownership. **You'll know it worked when** a dated
   verification baseline names source/remote SHAs and owned files.
2. Capture privacy-safe 1.0.5 version/help/inspect and focused-test evidence without
   reading auth, sessions, or raw logs. **You'll know it worked when** the before-state
   is reproducible and any pre-existing failure is separated.
3. Implement the exact-version policy and recoverable Windows/Unix install path, then
   install exactly 1.0.13. **You'll know it worked when** version, rollback, and
   credential-preservation tests pass.
4. Qualify all CLI/JSON/permission/session/usage/process contracts against 1.0.13
   before adapting wrappers. **You'll know it worked when** redacted offline and
   bounded live artifacts establish every parsed field and emitted flag.
5. Execute Phases 3–5 of the plan, keeping #249 separate. **You'll know it worked
   when** focused suites prove useful integrations without broadened authority.
6. Run exact-head independent review, full Windows/Linux tests, supported install,
   live acceptance, commit/push/CI verification, update STATUS, close #251, and retire
   this handoff. **You'll know it worked when** `origin/main`, green CI, installed
   hashes, exact 1.0.13, and live behavior all point to the same reviewed commit.

## 7. Constraints and gotchas

- Work directly on `main`; preserve concurrent edits and stage only owned files.
- Never read/print/copy `~/.grok/auth.json`, raw provider sessions, or raw logs.
- Verify a downloaded installer before execution and keep exact-target rollback.
- No raw review command, broad permission mode, MCP enablement, or safety-control
  removal is allowed as an upgrade shortcut.
- Provider retry does not authorize wrapper retry after interruption; uncertain paid
  work remains blocked.
- No local reviewer suite may collide with protected active Windows CI/reviewer work.
- Safety-path changes require one independent exact-head final review.
- The integration-review workstream is issue #249 and remains separately governed.

## 8. Access and environment

The checkout is `C:\repos\ai-devops` on EDGE-DEV. PowerShell, Git Bash, GitHub CLI,
and authenticated Grok 1.0.5 are available. GitHub CLI targets
`popcre/ai-devops`. Grok credentials remain machine-local under `~/.grok` and must
not be inspected. No new secret or 1Password item is needed for this upgrade.

## 9. Open questions and risks

Evidence must determine the exact 1.0.13 install selector, whether the narrow
headless permission hint is useful, whether JSON/stop/cost semantics changed, whether
the early-return symptom is gone under load, and which #249 assumptions changed.
None needs owner judgment unless 1.0.13 cannot retain a locked capability. Main risks
are installer drift, schema drift, duplicate billing through misunderstood retries,
concurrent-file collision, and a vendor change that weakens a safety boundary. The
rollback is the verified prior executable plus an unlanded repository change—never a
weaker wrapper.

## Handoff self-audit

1. **Can a newcomer continue without context? Yes.** §§1–3 give the repository,
   goal, issue, exact baseline, installed version, and uncommitted state; §6 links the
   full executable sequence and gates.
2. **Can they continue as effectively as this session? Yes.** §§4–5 preserve every
   rejected shortcut and non-obvious version/installer/wrapper finding; the linked
   plan contains the full release classification.
3. **Is every execution detail present? Yes.** §§6–9 cover ordered action, proof,
   safety, access, uncertainty, rollback, landing, and retirement.
4. **Does §0 contain every owner decision? Yes.** A line-by-line sweep of §§1–9 found
   only one conditional decision: inability to preserve a locked capability. It is in
   §0 with the recommendation to stop before weakening anything. All current decisions
   are already settled and listed there.
