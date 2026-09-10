---
issue: 335
status: OPEN
owner: codex/issue-335-phase4-fresh-session
---

# HANDOFF — Issue #335 Phase 4 continuation after Ansible production acceptance

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**Blocking before the next irreversible actions:** Albert must separately and
explicitly authorize merging each remaining exact PR head and its automatic
production release: POP CRM #8, POP PIM #6, PopDAM #122, and Backrest Wiz #7.
Recommendation: grant a single message naming all four repositories, pull
requests, and automatic releases only after the session refreshes their heads,
bases, checks, and release behavior. This blocks each corresponding merge, not
the read-only preparation or Backrest review repair.

The next session must put this whole remaining authorization list to Albert in
one message before its first merge; do not ask one release at a time.

**Already settled — do not re-ask:**

- Albert authorized Ansible #14 and its automatic serialized Phase 1 apply to
  the `hetzner` production target on 2026-09-10. It is complete; do not seek
  a second authorization or rerun it.
- Issue #335 was prematurely closed and is now OPEN. Keep it open through Phase
  5 completion.
- Do not bypass or weaken Backrest's qualified exact-head independent-review
  gate. Do not repeat its unchanged failed reviewer launches.
- Do not repeat completed Item Master, tracking, private-repository,
  infrastructure, earlier DesignFlow, or Ansible work.
- Phase 5 cannot begin until all 17 coverage rows are landed and the
  mixed/missing guard passes.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public engineering-governance and recovery
toolkit. Issue #335 makes task scope enforceable across 17 canonical
repositories, preventing a small change from silently invoking stronger review,
deployment, database, infrastructure, production, UI, or private-data work.

Phase 4 distributes the central version-1 task-gate policy to those repositories
without reducing their existing safeguards. Phase 5 is a later supported-machine
installation, controlled acceptance, measurement, and retirement phase; it is
not authorized to run yet.

## 2. What we set out to do this session, and why

Albert asked to continue Phase 4 from a new isolated worktree, recover the
incorrectly closed Issue #335, resolve five production-triggering pull requests,
and close the phase only after each real release was verified. He then authorized
rotation of accidentally exposed MCP credentials and explicitly authorized only
Ansible #14's merge and serialized real Phase 1 apply to the `hetzner`
production target.

This session reopened #335, refreshed all five candidates, preserved the
Backrest reviewer gate, completed the authorized Ansible release, and made this
fresh-session cut. It deliberately did not merge the other four PRs, update the
17-row coverage evidence, run the mixed/missing guard, or execute Phase 5.

## 3. Current state — what is true right now

The plan at `plan_cross_repo_routing_and_gate_enforcement.md` is now updated to
**PARTIAL 13/17**. This handoff and that plan change are uncommitted in the
isolated worktree `C:\repos\ai-devops-worktrees\issue-335-phase4-fresh-session`
on branch `codex/issue-335-phase4-fresh-session`, created from current
`origin/main` commit `c3b1e387abaf354eaf4a3ab7fd5abd6024f18a6c`. Commit identity
was verified as Albert Hazan's GitHub noreply identity.

Live state refreshed on 2026-09-10:

- Issue [#335](https://github.com/popcre/ai-devops/issues/335) is **OPEN**.
- `u2giants/ansible#14` is **MERGED** at `5e66e72c1f7f7e724b8f20af8b986de195f8a8ae`.
  Its exact landing run `34502571521` executed the real serialized Phase 1
  apply against `hetzner` and succeeded: `ok=59`, `changed=1`,
  `unreachable=0`, `failed=0`.
- POP CRM [#8](https://github.com/u2giants/popcrm-web/pull/8) remains OPEN,
  CLEAN, head `ee319d447f5311d723a830a4cd42ca5050ba9773`, base
  `49e7ccaffc388b394239aa20c0094eb036eea597`, with all reported checks green.
- POP PIM [#6](https://github.com/u2giants/poppim-web/pull/6) remains OPEN,
  CLEAN, head `d5ab6897f0893aafd91ad7973cc34814e648e2f2`, base
  `022176bc662803205af3d2ba8bf4dd8740a8dd5a`, with all reported checks green.
- PopDAM [#122](https://github.com/u2giants/popdam3/pull/122) remains OPEN,
  head `e41c9f5635b8f0efb712896db778b35386b4bfaf`, base
  `6316bae8439155e621b3fe84cf78bd7fbfb08ba6`; required checks are green and
  Supabase Preview is explicitly skipped. GitHub presently reports its merge
  state as UNKNOWN, so refresh it immediately before authorization/merge.
- Backrest Wiz [#7](https://github.com/u2giants/backrest-wiz/pull/7) remains
  OPEN, CLEAN, head `27f4c72f50961ba14b15976eb253c6186567b650`, base
  `11fc88365100764aa777807fe9408c5e7fdf7c84`, with Task Gates green. Its exact
  qualified independent-review report is still missing.

The exposed DesignFlow MCP credentials were replaced through the approved
1Password/Coolify procedure. Replacement credentials authenticate to both
services and the local protected cache matches the new vault values. No secret
value appears in this handoff. Direct old-token rejection was not re-run because
the old value must not be retained or reused; record this as an incident-proof
limitation, not a reason to weaken any delivery gate.

## 4. Everything we tried that did NOT work

- Backrest's formal exact-head final-review launches through both qualified
  providers did not produce a report within bounded waits. The provider doctors
  initially qualified, but the final-check processes stalled. They were stopped
  only after their bounded evidence windows, leaving no verdict. Repeating those
  unchanged launches would not create proof; diagnose a changed cause or wait
  for requalification instead.
- A credential-rotation attempt used a Coolify update shape that was accepted
  but did not bind the replacement value, and a restart route using GET failed
  safely. It was corrected with the documented minimal update payload and POST
  restart routes; both services then authenticated with the replacements.
- The first AI DevOps worktree had fallen behind `origin/main`. A new isolated
  worktree from `c3b1e387` was created before these documentation changes, so no
  concurrent documentation work was overwritten.

## 5. Root causes and key findings

- Green source checks and a clean merge state are not authority for a merge that
  starts production automation. Every remaining PR needs exact current-chat
  authorization and a last-moment head/base/check/release recheck.
- Ansible's authorization was sufficiently specific because it named PR #14,
  automatic serialized Phase 1, and the `hetzner` production target. Its merged
  commit and real apply result are direct production evidence, making that row
  complete without any coverage-ledger update yet.
- Backrest's remaining defect is evidence availability, not source correctness:
  its qualifying exact-head reviewer proof never materialized. Preserve its
  read-only exact-head requirement and do not convert a doctor result into a
  review verdict.
- The plan's Phase 4 reciprocal instruction is still valid: after the final four
  rows land and the mixed/missing guard passes, reread **every** Phase 5 step
  through plan completion, record drift, write a Phase 5 handoff, and stop.

## 6. Exact next steps

1. Create a fresh current-`origin/main` AI DevOps worktree. Read `AGENTS.md`,
   the STATUS and Phase 4–5 sections of the plan, and this newest handoff.
   Verify this handoff's merge is on `origin/main`; you will know this worked
   when the worktree is clean and based on the documented handoff commit.
2. Refresh #335 and the four remaining PRs' state, exact head, base, checks,
   required reviews, and automatic release behavior. You will know this worked
   when each result is recorded from live GitHub and any drift is treated as a
   new candidate rather than assumed covered by this handoff.
3. Repair Backrest's qualified exact-head review proof without changing its
   policy or bypassing the gate. First inspect the local reviewer-issue evidence
   and provider qualification state; only launch a review after a meaningful
   diagnostic or requalification change. You will know this worked when a valid
   read-only final report names `27f4c72f` or the newly refreshed exact head.
4. Before the first merge, send Albert the one consolidated authorization ask in
   §0 for POP CRM #8, POP PIM #6, PopDAM #122, and Backrest #7. You will know
   authority is sufficient only when it explicitly names each merge and its
   automatic production release.
5. For each authorized PR, immediately recheck its head/base/checks/release
   behavior, merge only that verified head, and directly verify the resulting
   production release. You will know each row is ready when its PR is merged,
   `origin/main` contains the merge, and the repository-specific live release
   result is successful. If one authorization or proof is absent, leave only
   that PR open and continue safe independent work.
6. After all four rows have direct release evidence, update all 17 central
   coverage rows with policy version, landed commit/PR, routing before/after,
   trigger evaluation, local verification, and remaining exception. Run the
   mixed/missing guard. You will know Phase 4 is complete only when it reports
   no mixed or missing row.
7. Only after step 6 passes, reread Phase 5 Steps 5.1–5.4, the acceptance table,
   and the plan completion definition. Record every Phase-4-caused drift, write
   a Phase 5 handoff, and stop without executing any Phase 5 action. You will
   know this worked when the handoff names the current policy version,
   installation paths, nine-scenario gate, measurements, and closure sequence.

## 7. Constraints and gotchas in force

- Use isolated, current-upstream worktrees and stage only owned files. Do not
  reset, clean, stash, force-push, or overwrite concurrent work.
- The plan does not authorize any production mutation. Each remaining release
  still needs Albert's explicit exact current-chat authorization.
- Do not open raw transcript archives, licensed source rows, or secret values.
  1Password vault `vibe_coding` is the only secret location reference needed.
- Do not repeat completed Item Master, tracking, private-repository,
  infrastructure, earlier DesignFlow, or Ansible evidence unless a live head or
  result changed.
- Keep Issue #335 OPEN; do not close #159, unblock #166, run cross-machine
  installation, or execute Phase 5 before the 17-row gate passes.
- Do not use a provider doctor as Backrest final-review proof, and do not rerun
  a stalled final-check unchanged. Preserve the reviewer safety path.

## 8. Access and environment

The host is EDGE-DEV on Windows. GitHub CLI and Git are authenticated; Bash is
available at `C:\Program Files\Git\bin\bash.exe`. The AI DevOps reviewer tools
and local protected reviewer-issue directory are available, but their current
Backrest final-check behavior is stalled as described in §4.

Git identity is `Albert Hazan <u2giants@users.noreply.github.com>`. Production
release evidence must be retrieved through the relevant repositories' GitHub
and read-only service evidence. Credential rotation, if incident follow-up is
needed, uses the `vibe_coding` vault and the established protected procedure;
never pass values in commands, logs, commits, or chat.

## 9. Open questions and risks

- The only open owner decision is the consolidated four-release authorization
  in §0. Backrest also carries a technical blocker—the missing qualified
  exact-head report—but that is not an invitation to weaken the gate.
- PR heads, bases, checks, and release behavior are live state. Any change
  invalidates the recorded candidate evidence and requires re-resolution before
  merge.
- Phase 5 drift review has been performed against the whole plan for this
  fresh-session cut. No Phase 4 change invalidates its design: it still requires
  normal Windows/Linux lifecycle installation (not copied binaries/policies),
  nine controlled scenarios using fixtures/dry runs for protected actions,
  measurement against Phase 0 with zero expensive documentation launches, and
  closure only after #335 evidence, #159 update, #166 unblocking, and removal of
  the OPEN handoff in the completion commit. The only drift is timing: Phase 5
  remains deferred until four releases, all 17 rows, and the mixed/missing guard
  are complete.
- The credential incident has successful replacement-authentication evidence but
  no direct old-token rejection evidence, by deliberate non-reuse of a known
  exposed value. Treat that narrow proof gap as a security-record limitation;
  it does not alter Phase 5 acceptance or authorize an unsafe retest.

## Self-audit

1. **Yes.** §§1–3 identify the product, business goal, current worktree,
   issue, exact PR heads, merged Ansible commit, and direct production result;
   §§6–8 make a cold continuation executable.
2. **Yes.** §§4–5 retain the non-obvious failed reviewer and credential paths,
   the distinction between qualification and a verdict, and the reasoning for
   the remaining production boundary.
3. **Yes.** §§0–9 cover background, goal, current state, failed attempts,
   findings, constraints, access, risks, exact ordered next actions, and their
   verification gates. Secrets are location-only.
4. **Yes.** A line-by-line §1–9 sweep found one outstanding owner judgement:
   authorization of the four named automatic production releases. It appears in
   §0 with a recommendation and the instruction to ask once. Ansible authority,
   #335 reopening, the reviewer gate, and Phase 5 deferral are settled and
   explicitly marked do-not-re-ask.
