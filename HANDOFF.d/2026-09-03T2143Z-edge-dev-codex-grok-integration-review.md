---
issue: 249
status: OPEN
owner: codex/grok-integration-review-249
---

# Grok integration-review access planning handoff

Plan: [`../plan_grok_integration-review-access.md`](../plan_grok_integration-review-access.md)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

### Blocking before any safe live qualification

1. **Approve the exact public, non-production canary destinations, Linux
   controller host, and any recurring/hosted sandbox expense.** Recommendation:
   use a dedicated non-production Linux controller and synthetic fixture
   endpoints/registry with no customer or production data. This blocks live
   Windows dispatch and plan Phase 6; offline design/tests do not need it.
2. **Approve the Windows-to-Linux controller identity and secret provisioning
   route.** Recommendation: mutually authenticated HTTPS with narrow submit/
   status/cancel/evidence rights; create separate scoped Windows client, Linux
   server, and Linux-controller Grok-auth items in 1Password `vibe_coding`, using
   the existing secret procedure. No credential enters the workload. This blocks
   live cross-host qualification, not offline work.

### Already settled — do NOT re-ask (Albert Hazan, 2026-09-03)

- Keep the fail-closed approval reviewer unchanged and add a separately named
  integration-review tier.
- Use disposable isolation, read-only exact source, disposable writes, no ambient
  identity/secrets/configuration, deny-by-default domain-brokered egress, private/
  metadata/production denial, cited search preference, resource/evidence/cleanup
  bounds, exact-head lifecycle protections, and fail-closed uncertainty.
- Prompts/command allowlists are not containment; difficulty never permits
  weakening or removing the reviewer.

The implementing session must present the whole remaining owner-decision list in
one message before Phase 6, not rediscover it one item at a time.

## 1. What this application is

`popcre/ai-devops` is Albert's public cross-platform toolkit for safe multi-model
review and development workflows. `bin/ai-grok-review` is its existing fixed,
read-only, exact-head Grok approval reviewer. The linked plan specifies a new,
separate integration tier that can execute meaningful tests only inside an
external disposable Linux boundary. The repository has no app deployment or DB;
landing means GitHub `main`, green CI, and verified installation.

## 2. What we set out to do this session, and why

Write a comprehensive implementation plan and GitHub issue for giving Grok
controlled build/test/research/endpoint capability without access to the live
checkout, credentials, private networks, or production. This was planning only:
no reviewer behavior, configuration, installation, sandbox, proxy, or canary was
changed or run.

## 3. Current state — what is true right now

- Issue [#249](https://github.com/popcre/ai-devops/issues/249) is OPEN.
- The linked plan exists locally, all phases are open, and its final self-audit
  passes all implementation-plan requirements.
- A three-turn GLM 5.3 debate ended in **APPROVE** and consensus after the plan
  adopted a fully offline workload, structured dependency/endpoint broker,
  explicit Windows dispatch/auth, and aligned research/TLS controls.
- Baseline: `main` at planning start was
  `bffec57fb81ae02362b54bc48831044c5abec37a`; installed Grok was
  `1.0.5 (5115b46bc9) [stable]`.
- Existing approval review remains read-only at `bin/ai-grok-review:66-87`;
  private snapshot/exact packet controls are at `:162-231`; isolated execution
  and provider launch are at `:737-910`; new/ask exact-work lifecycle is at
  `:1197-1365`.
- No integration wrapper, policy, Linux execution boundary, egress broker,
  integration evidence format, tests, or installation exists.
- The shared checkout had unrelated concurrent modifications, including
  `AGENTS.md`, reviewer wrappers/helpers/tests/plans, and other handoffs. This
  session owns only the new plan and this handoff; it did not edit those files.
- Commit/push status must be updated here by the planning session after landing.
  No implementation or application deployment exists.

## 4. Everything we tried that did NOT work

No implementation or network canary was attempted. The plan explicitly rejects:
adding Bash to the approval wrapper; prompt/allowlist/hook containment; direct
Windows Grok sandbox claims; Grok strict sandbox alone; host container sockets;
proxy variables without network routing; arbitrary DNS/CDN wildcarding; writable
live source; copying auth/config homes; mounting Grok auth into the workload;
Git remotes/gh; WSL2 alone; persistent cross-repo caches; and using integration
evidence as approval. See plan §7 for the reason and failure mode of each.

## 5. Root causes and key findings

- Grok can request shell and cited web tools, but its native security controls do
  not meet the complete goal across platforms.
- Official Grok docs say Windows has no OS sandbox enforcement. Linux can block
  child networking, but not supply domain-aware allowlisting; in-process LLM/web
  traffic remains connected.
- Grok rules/hooks are defense in depth; hooks can fail open.
- Safe delivery therefore needs a trusted controller, disposable Linux workload,
  and enforcing DNS/HTTP egress broker. Grok credentials must stay outside the
  shell-visible workload.
- Builds need a digest-identical disposable writable copy of read-only mounted
  source; the live checkout is never mounted.
- The unresolved provider question is whether Grok 1.0.5 can use a narrow remote
  sandbox tool bridge while its reusable credential remains solely in the trusted
  controller. Failure requires an external controller/microVM/hosted broker, not
  weaker reviewer permissions.

## 6. Exact next steps

1. Re-read the linked plan STATUS and §§1-13; resolve `origin/main`, open issues
   #172/#177/#188/#218/#249, work claims, and relevant OPEN handoffs. **You'll
   know it worked when** a dated baseline artifact names exact SHAs and dirty
   exclusions.
2. Execute plan Phase 0 read-only provider and Linux-control qualification.
   **You'll know it worked when** every capability claim is pinned to exact Grok
   docs/source/version and the host either passes primitives or selects microVM.
3. Implement Phases 1-3 in order: strict policy/schema, disposable workload, then
   egress broker. **You'll know each worked when** its hostile offline gates pass
   without provider/network access.
4. Implement the separate integration wrapper and evidence/rollback controls in
   Phases 4-5; do not alter approval behavior. **You'll know it worked when** both
   state spaces are isolated and the entire approval suite remains green.
5. Put the single §0 ask to Albert, then run only the approved Phase 6 canaries.
   **You'll know it worked when** positive and negative evidence is exact-head,
   sanitized, bounded, and proves destruction without production contact.
6. Complete Phase 7 exact-head independent approval, full suites, CI, install,
   both-tier verification, safe reconciliation/push, and issue evidence. **You'll
   know it worked when** every plan definition-of-done checkbox has an artifact,
   the commit is on `origin/main`, CI/install are verified, and #249 can close.
7. Delete this handoff only in the finishing commit after every obligation is
   carried into durable evidence/plan status. **You'll know it worked when** issue
   #249 is closed for proven completion and Git history retains this record.

## 7. Constraints and gotchas in force

- Preserve capability; never weaken, bypass, or remove either reviewer.
- Planning is not implementation authority. Reconfirm live state before changes.
- Work on main, preserve concurrent work, stage only owned files, never force-
  push/reset/clean, and verify Git identity before commit.
- Reviewer safety changes require exact-head independent read-only final review.
- Protected Windows runner activity is a hard stop for local reviewer suites.
- No production/private/network canary without exact current-chat authorization.
- Public repo: no secrets, raw transcripts, private endpoints/data, or machine
  configuration. Configuration changes require backup and deployment docs.
- Prompts, Grok rules, hooks, proxy variables, and container naming are not
  containment. Enforce with kernel/network boundaries and fail closed.
- Exact-head approval becomes stale after source/evidence movement.

## 8. Access and environment

Planning machine is EDGE-DEV Windows, checkout `C:\repos\ai-devops`, Git Bash for
Bash tools, GitHub CLI authenticated, and Grok 1.0.5 installed. Never read/print
`~/.grok/auth.json`. Implementation needs a clean current-main worktree and a
dedicated non-production qualified Linux sandbox host. Any future hosted sandbox
secret belongs in 1Password vault `vibe_coding` under a documented item name,
never in source or evidence.

## 9. Open questions and risks

- Open technical decisions and objective gates are in plan §8: bridge mechanism,
  credential separation, container versus microVM, maintained proxy choice, and
  artifact retention. Implementers may choose only by those gates.
- The owner decisions are consolidated in §0: exact public fixtures/Linux host/
  cost and the mutually authenticated dispatch/Grok-auth provisioning route.
- Main risks are credential exposure, container escape, dependency scripts,
  DNS/HTTP bypass, evidence leakage, cleanup uncertainty, and provider-version
  drift. Plan §§10-13 specify defenses, canaries, rollback, and evidence.

## Handoff mandatory self-audit — final pass

1. **Can a newcomer continue without context? Yes.** §§1-3 define the repository,
   goal, baseline, exact paths, and non-implementation state; §6 links executable
   phases and gates.
2. **Can they continue as effectively as this session? Yes.** §§4-5 preserve every
   rejected shortcut, provider/platform gap, and recommended architecture; §§7-9
   preserve constraints, access, risks, and open choices.
3. **Is every execution-critical detail present? Yes.** The plan contains all 13
   detailed sections; this handoff's §§3, 6, 7, 8, and 9 state status, actions,
   proof, environment, and risks; no secret value appears.
4. **Does §0 contain every owner decision? Yes.** An end-to-end sweep of §§1-9
   found approval of exact public fixtures/Linux host/cost and the Windows-to-
   Linux identity plus controller-only Grok-auth provisioning route. Both are in
   §0 with recommendations and blocked phases. All locked choices are separately
   listed as settled and must not be re-asked.

All 10 sections and every handoff checklist item pass.
