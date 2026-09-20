---
issue: 658
status: OPEN
owner: codex/github-request-reduction-plan
---

# HANDOFF — GitHub request reduction (2026-09-20, 916/Codex)

## 0. Decisions only the owner can make

None for the requested plan. Albert asked for a plan, not implementation or a new
infrastructure deployment. Planning is complete when its PR is merged and verified.
Implementation remains open under [#658](https://github.com/popcre/ai-devops/issues/658).

Already settled, 2026-09-20: reduce requests at source without sacrificing workflow;
preserve concurrent work, checks, notifications and recovery. Do not ask Albert to
choose a cache, write code, relay a handoff or merge the planning PR. Future remote
infrastructure changes are not authorized by this plan; section 9/P6 of the plan
routes an exact design/resource through the standing independent-review gate.

## 1. What this application is

`popcre/ai-devops` is Albert's public multi-model development toolkit, with Bash
tools, PowerShell installation, client skills and GitHub Actions verification.
GitHub is the source of truth; installation is deployment. Canonical local checkout
is `D:\repos\ai-devops` on 916, landing-only. No database structure is involved.
Full executable brief: [GitHub request reduction plan](../plan_github-request-reduction.md).

## 2. What this session set out to do and why

Albert asked why GitHub limits continue after the earlier reduction effort, then
said “make a plan to address all of this.” The session diagnosed concrete holes
and wrote a standalone phased plan, not a runtime repair. It must avoid calling
throttling success while duplicate callers keep spending the account's budget.

## 3. Current state

Plan base: upstream `eb92356e2ebbe2b05d353cbd9e9b26e1678ceb9e`.
Planning worktree:
`C:\Users\ahazan2\.codex\worktrees\github-request-reduction-plan\ai-devops`.
Branch: `codex/github-request-reduction-plan`.

This file and the plan are part of the same documentation-only publication.
The containing commit/PR is the publication evidence: a successor must verify it
on origin/main rather than assume publication from file presence. Tracking issue
#658 exists and remains OPEN for implementation; planning must not close it.
Plan STATUS P1–P8 are all open. No implementation, runtime installation, fleet
qualification or quota repair was performed. Router/topic links make it discoverable.

The installed 916 launcher points to the canonical ai-gh. A local failure at
2026-09-20T16:43:06Z was GraphQL rate exhaustion; its follow-up core probe reported
5000 remaining. The cached quota read 4999/5000. Plan sections 3/5/6 preserve the
safe exact excerpt, source anchors, known facts and unknown attribution.

## 4. What did not work and why

The current core-only guard did not protect GraphQL. Per-command decrement did not
measure actual HTTP/page/point use. Per-home locks did not coordinate all machines.
Rules telling agents to use ai-gh did not migrate existing bare callers. Historical
workflow acceptance did not measure account-wide request savings.

During read-only diagnosis, task class `analysis` was rejected; `prose` is valid
for planning. Avoid raw `.cmd` invocation for complex quoting; use Git Bash and
file-backed input. A broad initial docs read was unnecessarily large; successors
should use the plan's exact anchors instead of repeating a repository survey.
No failed runtime repair, token change or installation occurred.

## 5. Root causes and key findings

- `bin/ai-gh:238` reads only `.resources.core`; `:268` subtracts one per command.
- `bin/ai-pr-wait:243` uses GraphQL. Its exhausted bucket can be invisible to core.
- `bin/ai-gh:55` uses per-home local state. Cross-host demand remains outside that lock.
- Bare calls persist in `bin/ai-test-local:158`, `bin/ai-verify-run:43–84`,
  `bin/ai-workspace-status:94`, `bin/ai-memory-sync:90`.
- BlockerWatch `PARENTS_Q` and `LINKS_Q` scan OPEN issues separately. They are
  optimization candidates, not proven dominant consumers of today's exhausted quota.
- Failure diagnostic headers are from a later probe, not the failed request.
- Source inventory and actual request attribution must precede blame or savings claims.

Anchors refer to the plan base. Reconcile by symbol against current upstream.

## 6. Exact next steps

1. Read plan STATUS and sections 1–13; claim P1 in #658 and create a scoped child
   issue with a named owner. Verify no duplicate implementation owner exists.
2. Create a new current-upstream worktree, read that repo's AGENTS, declare the
   real task class. Gate: branch/base and clean task-owned scope are recorded.
3. Execute P1's bounded source/identity inventory and privacy-safe measurement.
   Gate: its report names measured top callers, unknown consumption and denominators.
4. Update P1 STATUS with artifacts. Continue P2 only in a correctly scoped session;
   reread downstream phases. Gate: every landing has live proof or one owned proof
   issue, never a bundle left to another session.
5. Execute remaining phases in their dependency order. Gate: P8 accepts the whole
   workflow under the numerical contract in section 13, not simply green tests.

Use `fresh-session` at phase boundaries. Retirement of this handoff requires the
successor rule: verified predecessor publication, all obligations carried forward,
and no unique decision lost. Do not edit another session's handoff or root pointer.

## 7. Constraints and gotchas

One unproven live outcome per session. No worker caps, disabled watcher, slower
polling-as-fix, stale safety evidence, hidden fallback or credential switching.
All GitHub calls through ai-gh; existing bounded waiters only. Tests use fake
transports; never exhaust real quota deliberately. Preserve privacy checks,
collision protection, exact-SHA dispatch and cancellation authority.

Implementation code follows normal tests/queue; reviewer safety/routing changes
require independent exact-head review. Planning is prose-only and uses the standing
documentation merge exception after changed-file verification. Sign all GitHub
bodies. Keep secrets/raw logs/transcripts out of this public repo. No memory update
was requested or made. New infrastructure requires the standing exact-action gate.

## 8. Access and environment

PowerShell 7 and `C:\Program Files\Git\bin\bash.exe` available on 916. Authenticated
ai-gh issue search and #658 creation succeeded during planning. Secret values were
not accessed. If later needed, follow the secrets skill and `vibe_coding` vault;
the plan requires no new token. Remote host reachability is not established.
Plan section 12 supplies exact paths and safe command conventions.

## 9. Open questions and risks

P1 must determine real consumers, active hosts, token/principal classes, point
costs and outside-tool demand. P6 chooses whether existing source ownership and
fresh bucket observations suffice or a strictly coordinated admission path is
necessary, with concrete selection criteria and authority boundaries in the plan.
These are bounded engineering investigations, not questions to hand back to Albert.

Risks: stale/private cached state, query cost growth, false budget attribution,
mutation replay, outages and partial installation. Plan sections 9–13 specify
adversarial tests, rollback and acceptance. Do not promise zero limits caused by
clients outside toolkit control. Preserve the original capability if rolling back.

## Delegated investigation record

`request_audit`: read-only source survey of guard bypasses and historical acceptance.
Returned file/line evidence incorporated into plan sections 5/6; no files, branch,
PR, issue or worktree created. Did not attribute live consumption.

`plan_gaps`: a read-only planning check was requested, but the agent remained
`pending_init` and was stopped at the bounded threshold. No report, edits or remote
actions occurred. The primary session performed the self-audit directly; do not
claim an independent review. No implementation outcome was delegated to either agent.

## Self-audit

1. Could a brand-new developer continue without this conversation? Yes: sections
   1–3 identify toolkit, purpose, publication state and full plan; 6/8 give exact start.
2. Could they continue as effectively as this session? Yes: sections 3–5 preserve
   incident, code anchors, failed approaches and attribution uncertainty.
3. Are all execution details included? Yes: sections 6–9 and the linked plan supply
   ordered gates, tests, access, constraints, risks, rollout and measurable completion.
4. Would Albert see every needed decision in section 0? Yes: a line-by-line sweep
   of sections 1–9 and delegated record found no present owner decision. Future
   infrastructure authority is explicitly bounded in section 0 and plan P6.

Checklist passed: all ten sections, reciprocal plan link, current-state and
publication verification instructions, failed approaches, exact next gates,
secret-free access, owner-decision sweep and delegated-work accounting.
