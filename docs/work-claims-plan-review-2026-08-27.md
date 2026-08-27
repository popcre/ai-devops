# Work-claims plan review record — 2026-08-27

This is the durable review record for `plan_ai-devops-work-claims.md`. It records conclusions without copying private transcript content.

## Current contract after execution evidence — read this first

Parts A, B, and C in `plan_must_address.md` superseded the earlier “ready to land” conclusion below. Two sessions with extensive live ai-devops execution showed that queue unreliability is the dominant tax and that the earlier plan's units, required claim check, network-dependent commit fencing, shared hooks, takeover, fixed paths, and issue-close blocking would harm throughput.

The current plan therefore sequences behind `plan_repo-throughput-restructure.md` and defines a smaller advisory v1: one task ref; explicit owner-appendable paths; no units, component refs, takeover command, hooks, push wrapper, exact-head enforcement, or required check; network-independent Git commit/push; a separate fast advisory workflow; exact manual stale reconciliation; and reproducible 30-day keep/change/remove measurement. Implementation begins at the queue-reliability prerequisite, not Git-ref qualification.

Grok 4.6 reviewed this evidence-based revision in session `work-claims-evidence-revision` and initially returned `REJECT`. It agreed with the direction but found seven contract gaps: router/review-record contradictions, advisory workflow placement, unwritten stale reconciliation, non-reproducible measurement, unenforceable push-wrapper binding, under-specified path extension, and missing command inventory. After those fixes, it found nine stale sentences that still implied the removed push/bind machinery. Those were corrected, and its final exact-tree verdict was `APPROVE` with no blocking findings. Across the three review turns, reported cost was $0.26315558 on `grok-4.6-build` ($0.12531278 + $0.0758948 + $0.061948).

## Background supplied to reviewers

Transcript analysis found that ordinary file overlap was mild, while duplicate intent was costly: separate sessions independently repaired the same flaky tests, copied provider implementations multiplied the same repair across tools, and `AGENTS.md` was edited 72 times in 30 days. The repository also uses multiple machines, clones, linked worktrees, shared GitHub credentials, and occasionally unrelated dirty files in a shared checkout. Prompt-only ownership and stale branch-policy assumptions had already failed in practice.

The rejected starting idea was a committed claims file or a full shared-db-style orchestrator. A first lightweight design then used GitHub issues plus a visibility delay; that was rejected because issue creation and search do not provide atomic one-winner admission.

## Grok 4.6 critique

Grok returned `REVISE`. It supported lightweight coordination but found the first design non-atomic, unsafe under stale-owner resumption, too dependent on prompt compliance, and inconsistent with the repository's live branch policy. Live evidence reconciled the policy: feature branch, pull request, required Linux/Windows checks, and squash merge queue are mandatory under ruleset `21564317`; the earlier direct push had used an administrator bypass and was not valid precedent.

The plan was revised to use atomic create-only Git refs, protective stale ownership, declared-path fencing, local and CI enforcement, and the required branch/PR/merge-queue route. Grok model: `grok-4.6-build`; reported usage: 350,495 tokens and $0.08112162.

## GLM 5.3 first critique

The protected session `ai-devops-work-claims-plan` ran as caller `codex` on `zai-coding-plan/glm-5.3` and returned `REVISE`. It identified four material gaps:

1. GitHub REST ref updates have no compare-and-swap parameter; later ownership mutations therefore need Git `push --force-with-lease` from the exact expected object.
2. Stale takeover needed a longer threshold and exact, per-incident Albert authorization because cross-machine process death cannot be inferred.
3. Lost create responses needed a unique per-acquisition candidate token/object persisted locally before the remote create, followed by exact readback and re-adoption.
4. PR enforcement needed an exact branch/head binding rule.

It also recommended removing component refs from v1. The revision incorporated all five points: REST is create-only, later mutations are lease-protected, takeover is at least 24 hours plus exact current-chat authorization and audit evidence, `bind-head` binds the exact PR SHA, and v1 has only task/unit refs. Reported usage: input 1,280; output 3,358; reasoning 2,264; cache read 55,040.

## GLM 5.3 closing critique and reconciliation

The same protected session reviewed the complete revision and again returned `REVISE`, narrowly. It confirmed that all first-round material findings were resolved and found no new major defect. Its final required correction was that task-wide and work-unit keys could coexist unless issue modes were mutually exclusive. Its should-fix correction was that local fencing must examine the staged index at commit and exact outgoing range at push, never unrelated dirty-worktree files.

The final plan now locks mutually exclusive bare/unit modes, records and rechecks the issue scope digest, fails closed when scope changes while claims exist, uses publication-specific file sets, clarifies stale PR acceptance, makes `doctor` read-only except for explicit local-only exact recovery, consistently calls the mechanism claims rather than leases, and stores this durable review record. GLM stated that no further review round was needed after these bounded corrections. Reported usage: input 11,087; output 2,464; reasoning 3,391; cache read 80,448.

## Historical result before Parts A–C

At that point the plan was considered ready, but Parts A–C later disproved that conclusion. This paragraph is retained as history, not current instruction. The current contract is the first section of this record plus the live STATUS table in `plan_ai-devops-work-claims.md`.
