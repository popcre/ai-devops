---
issue: 337
status: OPEN
owner: codex/reviewer-audit-20260908
---

# Reviewer reliability and efficiency implementation handoff

## 0. Decisions only the owner can make

None outstanding for the requested planning deliverable. Albert requested a comprehensive plan, not implementation deployment. Start implementation when requested; do not mistake this open handoff for authorization to change production infrastructure, buy quota, rotate credentials or reduce reviewer capability.

Already settled September 8, 2026: keep the audit/plan together; use an isolated worktree; preserve the original reviewer capabilities; use evidence-backed diagnosis for uncertain failures. Do not ask Albert to choose routine technical mechanics or repeat the incident reports. If a later proposed action requires one of the excluded owner decisions, present all actual decisions together before that action, with the concrete reviewed proposal and consequence.

## 1. What this toolkit is

`popcre/ai-devops` is the public recovery toolkit for Albert's multi-model development workflow. Bash/Python/PowerShell wrappers run nine independent reviewers and retain private machine-local evidence. Installing the toolkit is deployment; there is no application UI or database in this work. `u2giants/shared-db` owns consumer reviewer allocation/verdict code, not the wrappers. Tooling changes there must follow its current repository-maintenance routing and isolated-worktree rules; no database structure or row change is proposed.

The complete executable specification is [plan_reviewer-reliability-and-efficiency.md](../plan_reviewer-reliability-and-efficiency.md). This handoff is its discovery and continuation record, not a competing plan.

## 2. Session goal and reason

Albert asked for the latest reviewer problems and a cache/context/session audit of all reviewers, wrappers and OpenCode implementations. The audit found wrong default comparison-base selection, repeated quota/timeout/read failures, incomplete metrics and substantial unproven historical closure. Albert then requested the best comprehensive implementation plan using the planning skill.

The plan covers the confirmed source defects, precise diagnosis branches for unresolved failures, all nine provider contracts, both OpenCode paths, persistence/restart/compaction tests, measured optimization, and installed incident closure. No provider was retried or disabled during planning.

## 3. Exact current state

Planning baseline: ai-devops `d5522d9a8bcdef49db917d37002166aaaff5be73`. Branch/worktree: `codex/reviewer-audit-20260908` at `C:/repos/ai-devops-worktrees/reviewer-audit-20260908`. This delivery contains only the plan, this handoff and prose discovery links. Implementation has not started; no installed configuration or runtime source was changed. The planning PR's final merged identity is discoverable through issue #337 and Git history; verify it live before relying on this file, rather than expecting a commit to contain its own future SHA.

The canonical incident ledger is discoverable with `bin/ai-reviewer-issue path`. Its first real maintenance round is open and restored as `0c62f3dffce145c4b2768855b912b958`; always resume that exact round and retain its frozen boundaries. It contains 198 evidence candidates, not 198 distinct defects. The private 67-record root-cause map stays in the canonical checkout's ignored maintenance directory and must not be copied into public Git.

Completed prerequisites: #308 checkpoint implementation and #312 diagnostics/quota implementation. #312 merged as `a570069a95d06c271895a33565785c2784e32a8b`; its current plan says installed/live-qualified. The capacity adapters remain unknown for unsupported interfaces, so repeated observed exhaustion still needs end-to-end admission investigation.

Concurrent dependency: Qwen PR #330, head `f7cc2739ca3174508669dcb5b4f7ab69d65a7825`, was OPEN with Windows checks running during planning. It owns #322 fast identity work; do not duplicate, cancel, restart, or edit its branch. #333 still owns DeepSeek/Muse cache reporting. Current shared-db upstream inspected through GitHub was `0f22de12562b7250ebf70fb07502e0fbce429cb3`; its local canonical checkout was stale, so never treat that checkout as the live consumer baseline.

## 4. What did not work and must not be repeated

Earlier cache planning rejected digest-gated snapshot reuse and deterministic approval paths; preserve the reasons in the child cache plan. Muse shared server mode previously failed authorization; direct exact-session persistence already works. A larger process-only Qwen timeout was an accommodation, not proof that the post-write validation cause was fixed. Unknown counters must not become zero; usage sidecars must not pollute DeepSeek's message body. No paid provider run was attempted in this planning session, so there is no new live canary or performance proof to infer.

The audit's initial memory said #312 was unimplemented; current source/plan proved that note stale. The older cache plan also contains stale provider/branch facts. This plan records current prerequisites while preserving old rejected-approach history. Re-read STATUS, not historical prose, when those disagree.

## 5. Root causes and findings

`bin/ai-review-packet:179` prefers local main before origin/main; `bin/ai-review-sandbox:246` preserves the stale local branch first. Both layers need binding to the intended base. `bin/ai-deepseek-agent:303` drops usage, `bin/ai-muse:290` selects the last step token object, and `bin/ai-grok-review:1160` substitutes zero for absent cache counts. These are independently source-verifiable.

GLM timeout/endpoint loss, Qwen finalization failure and Codex read denials have observed symptoms but incomplete causal evidence. Do not invent one shared cache/host diagnosis. Both installed OpenCode configuration files matched source; that is file parity, not proof of all effective running settings. Named session records exist for the seven conversational reviewers; that is not a live resume or recall test.

## 6. Exact next steps

1. Read the linked plan STATUS, fetch current upstream into an independent worktree, and inspect active PR/runner ownership. Gate: exact current baseline and no duplicated implementation.
2. Select one #337 coding child: #393 source identity, #394 terminal diagnostics, #395 durable evidence, #396 availability/concurrency, #397 session recovery, #271 Codex sandbox, #333 usage/efficiency, or #169 shared primitives. Do not mix boundaries merely because one incident shows several symptoms.
3. Deliver that child with focused fixtures, required safety suites, exact-head review, merge, installation, live qualification, and incident reconciliation.
4. Run #398 last inside #337: account for all 198 frozen candidates and a bounded next interval, then prove the installed nine-reviewer matrix.
5. Close #337 only after every registered child is complete. #166 remains the final #159 required-check and throughput cutover.

## 7. Constraints and gotchas

Public toolkit/private evidence boundary; canonical landing-only checkouts; stage only owned files; correct Albert Git identity; no broad cleanup or forced Git operations. Reviewer safety-path changes require independent read-only exact-head review. No local full suites while Windows CI uses the host, and no shared GLM restart during another task's session. Use bounded event-aware waits. Preserve fresh Claude/Codex review isolation, exact advisory sessions, truthful unknown metrics, completed paid artifacts, strict verdict semantics and temporary versus permanent reviewer disposition.

The plan publication is prose-only and uses the standing immediate administrative squash rule once the actual changed-file list is verified. Implementation changes use normal tests/review/merge/install gates. Do not infer implementation acceptance from the planning merge.

## 8. Access and environment

GitHub CLI source/status access was verified for both repositories. Git Bash on this Windows host is `C:/Program Files/Git/bin/bash.exe`. Runtime/provider availability must be checked fresh. Secrets belong in 1Password vault `vibe_coding`, loaded through the `secrets-to-1password` skill and existing managed references, never output or committed. No secret lookup is required to read the plan or run offline fixtures. Plan §12 gives source configuration owners and safe discovery details.

## 9. Risks and open questions

The plan's open questions are technical diagnosis gates, not missing owner requirements: exact OpenCode usage semantics, GLM failure-window cause, supported Codex sandbox repair, Qwen residual finalization cause, safe exhaustion scope/expiry and justified compaction settings. Plan §§6, 8–10 and 13 specify how each is resolved and what blocks completion. Missing historical private evidence blocks full incident closure even if synthetic regression proof succeeds. Provider quota can block a live cell; never buy quota, retry repeatedly or fabricate a pass.

Rollback must preserve state schemas, ownership and paid artifacts; no blind downgrade/deletion. If a future repair cannot preserve the original capability, stop before changing it and raise that concrete decision as described in §0.

## Final self-audit

1. **Fresh-session continuation: yes.** §§1–3 identify the application, baseline, source/installation distinction and linked full specification; §6 supplies ordered gates.
2. **Relevant session knowledge retained: yes.** §§3–5 preserve active dependency ownership, stale-memory correction, private evidence limits and confirmed versus unproven causes.
3. **Required detail present: yes.** All ten sections, rejected approaches, access, constraints, next actions and plan test/delivery references are included. No implementation is presented as delivered.
4. **Owner-decision sweep passed.** §§1–9 contain no outstanding planning decision absent from §0. Conditional future quota purchase, infrastructure mutation, credential rotation, rollback/capability reduction and implementation authorization are consolidated there; the plan keeps them outside the requested planning delivery.
