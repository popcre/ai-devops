---
issue: 187
status: OPEN
owner: codex/ast-grep-management-187
---

# HANDOFF — managed ast-grep across Windows and Ubuntu (2026-08-30 14:03Z, edge-dev/Codex)

Primary implementation plan: [plan_ast-grep-multi-machine-management.md](../plan_ast-grep-multi-machine-management.md)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

### Blocking

- **Production Ubuntu installation:** when source changes and the read-only Ansible preview are ready, Albert must explicitly authorize installing official npm package `@ast-grep/cli` version `0.45.2` on production host `hetz` through the serialized Ansible pipeline. Recommendation: approve only after the implementing session presents exact source commits and a preview limited to that package. This blocks only production apply/final completion, not source work, tests, or Windows rollout.

The next session must present the whole decision above in one message when Step 7 is ready, not earlier or in fragments.

### Recoverable

None. Flexible implementation details have plan criteria and do not need Albert.

### Not part of this work, and nobody is on it

None found.

### Already settled — do not re-ask

- **2026-08-30:** Albert decided ast-grep should be centrally managed through `ai-devops`, not explained or manually installed in each conversation.
- **2026-08-30:** it is an occasional specialist; Albert need not know syntax or request it by name.
- **2026-08-30:** `u2giants/ansible` owns Ubuntu production-host package installation. Do not propose ad-hoc SSH install.

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery toolkit for Claude/Codex on three Windows computers and one Ubuntu server. It manages Windows setup, shared AI instructions, skills, tools, and recovery docs. Production Ubuntu host `hetz` has its packages declared/applied by private repo `u2giants/ansible`.

There is no web app, database, container, or URL here. The deliverable is a reproducible CLI installation plus safe AI guidance.

## 2. What we set out to do this session, and why

Albert requested a comprehensive implementation plan for managing ast-grep through `ai-devops`. Earlier transcript analysis established that repeated code-pattern changes, repository-wide work, and refactors make it useful occasionally, while ordinary search remains sufficient most of the time.

This session was planning only: research the supported route, map Windows/Ubuntu ownership, write a fresh-session build plan, register a handoff, and ship documentation.

## 3. Current state — what is true right now

- Issue [#187](https://github.com/popcre/ai-devops/issues/187) is the umbrella acceptance record.
- The plan is [plan_ast-grep-multi-machine-management.md](../plan_ast-grep-multi-machine-management.md); seven steps are open and Step 1 is the start.
- Draft baseline: `popcre/ai-devops` remote main `15991e63e53dbded3d52c218ff7f62430ef05bca`, inspected 2026-08-30. Refresh both repos before acting.
- Official npm package is `@ast-grep/cli`; npm reported `0.45.2`. The plan pins it and forbids implicit latest.
- ast-grep was absent on the planning Windows machine. No install, source implementation, global adoption, Ansible change/apply, or live proof occurred.
- Normal `C:\repos\ai-devops` had unrelated dirty work. Planning used a clean detached worktree; never absorb unrelated files.
- `C:\repos\ansible` was inspected read-only and appeared clean on `main`; it was not edited.
- Commit/push: this handoff/plan/router change must ship together as documentation-only. Record final commit in plan STATUS.
- Deployment: N/A for planning docs. Production package installation is unstarted and unauthorized.

## 4. Everything we tried that did NOT work

- Initial jargon such as “structural search” did not help a non-programmer decide. Transcript analysis and plain work categories fixed that; keep user guidance plain.
- Direct `ai-devops`/SSH Ubuntu mutation looked simple, but host packages explicitly belong to Ansible. The plan rejects drift.
- WinGet was considered by analogy, but official ast-grep guidance did not list it. The existing official-npm exception path is supported/tested.
- Short command `sg` collides with an existing Linux OS command. Use `ast-grep`.
- No implementation was attempted, so there is no failed patch/test/install to repeat.

## 5. Root causes and key findings

- Models already invoke terminal tools; what is missing is reproducible installation, PATH visibility, concise guidance, and proof—not a plugin.
- `config/tool-versions.json` owns the pin; `bin/reconcile-windows-package-exceptions.ps1` owns official npm exceptions.
- Full Windows bootstrap and direct setup must converge without duplicate installation.
- Both global templates own shared behavior; wording must be brief, aligned, advisory, and require preview/diff/tests.
- Ansible's existing `dev_tools_npm` loop is the Ubuntu owner.
- Package-list success is insufficient; each machine must prove full command, exact version, harmless use, and new-client availability.

## 6. Exact next steps

1. Read plan/STATUS/Phase 0, verify issue #187, and refresh both repositories/package metadata. **Worked when exact heads, issue, package, and collisions are recorded.**
2. Implement Phase 1 Windows catalog/reconciliation/setup/bootstrap/verifier/tests/docs. **Worked when named tests pass and wrong/missing version fails non-mutating verification.**
3. Implement Phase 2 aligned global rule. **Worked when parity/context tests pass and both clients require preview/diff/tests without prescribing `sg`.**
4. Implement Phase 3 in Ansible's existing npm loop and read-only preview. **Worked when lint/syntax/focused tests pass and preview is limited to ast-grep.**
5. Ship task-owned commits under both main-only policies and verify CI. **Worked when exact commits are on origin/main and checks pass.**
6. Roll out via supported bootstrap on all three Windows computers, reopen clients, and capture secret-free proof. **Worked when every machine proves `0.45.2` from new client contexts.**
7. Present Section 0's one production request. Only after authorization, run governed apply, verify `hetz`/zero drift, close #187, update plan, and retire handoff. **Worked when all four machines have exact evidence and nothing remains.**

## 7. Constraints and gotchas in force

- Implement from the complete plan, not this summary alone.
- Preserve `rg`, npm, Claude, Codex, Linux `sg`, and all capabilities.
- Never install/alias `sg`; never use mutable latest.
- No MCP/plugin/extension/wrapper/skill; do not force ast-grep into every task.
- `hetz` packages use Ansible only; production stays read-only until exact authorization.
- Preserve unrelated dirt; stage only owned files; verify committer identity.
- Keep STATUS/current state fresh; reopen Windows apps before PATH claims.
- Evidence stays secret-free and excludes transcripts/environment dumps.

## 8. Access and environment

- ai-devops: <https://github.com/popcre/ai-devops>, local `C:\repos\ai-devops`.
- Issue: <https://github.com/popcre/ai-devops/issues/187>.
- Ubuntu management: <https://github.com/u2giants/ansible>, local `C:\repos\ansible`.
- Target: production Ubuntu host `hetz`, via existing Ansible/GitHub Actions/SSH routes.
- Secrets: none new; existing values stay in 1Password vault `vibe_coding` and GitHub Actions storage.
- Use Git Bash for Bash tests and `pwsh -NoProfile` for PowerShell.
- Official reference: <https://ast-grep.github.io/guide/quick-start>.

## 9. Open questions and risks

- One owner gate: exact `hetz` install authorization, indexed in Section 0.
- Re-query `0.45.2`; stop rather than silently substitute if unavailable/unsafe.
- Old Windows apps may need reopening for PATH.
- Exact pin can drift across repos; test and record both commits.
- Broad edits require preview, Git diff, and normal tests.
- Recheck active concurrent work before edits/commits.
- Stop if Ansible preview shows any unrelated resource.

## Mandatory handoff self-audit

1. **Fresh developer can continue without questions: yes.** Sections 1–3 define repositories, goal, issue, exact plan/state; Section 6 gives ordered gates.
2. **They can continue as effectively as this session: yes.** Sections 4–5 preserve jargon failure, rejected routes, collision, exact package/version, and ownership; Sections 7–9 preserve constraints/access/risks.
3. **Every relevant detail is present: yes.** Goals/current truth/failures/findings/actions/evidence/constraints/access/risks are in Sections 1–9; the only decision is in Sections 0/9.
4. **Section 0 contains every Albert decision: yes.** A line-by-line sweep found only authorization of the exact production install. Real hostnames and implementation mechanics need no owner judgment. No outside-workstream decision was found.

**Handoff self-audit verdict: PASS.** All 10 sections are present; the owner gate, failures, facts, actions, evidence, status, and secret boundaries are complete.
