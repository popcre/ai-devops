---
issue: 209
status: OPEN
owner: codex/issue-209-windows-runner-pool
---

# 0. DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs Albert now. The next session must not
pause to ask permission to continue issue #209 or to merge its own eligible
changes.

Already settled — do not re-ask:

- 2026-09-01: use three independent physical Windows computers, with one runner
  service and one concurrent job per computer. Do not multiply registrations on
  one 16 GB machine to manufacture apparent capacity.
- 2026-09-01: do not give a candidate the daily-development `edge-dev` label and
  do not send ordinary CI to it until exact qualification and admission finish.
- 2026-09-01: keep this rare setup as cold repository documentation, not a Skill
  loaded into normal sessions.
- 2026-09-02: a documentation-only follow-up may ship separately after the
  qualification code merge; it must not rewrite the already-proven code commit
  merely to update prose.

# 1. What this application is

`popcre/ai-devops` is the public backup-and-restore toolkit for POP Creations'
multi-model development workflow. It supplies command wrappers, safety checks,
machine setup, and offline verification. GitHub Actions currently depends on a
daily-use Windows computer named EDGE-DEV, which has made Windows work queue or
cancel repeatedly. Parent issue #159 restructures repository throughput; child
issue #209 creates three dedicated physical Windows runners so ordinary work can
continue when one computer is busy or offline.

The repository is https://github.com/popcre/ai-devops. There is no application
deployment; committed source on `origin/main` plus passing verification is the
delivered product.

# 2. What we set out to do this session, and why

Set up and qualify the first of two additional LAN computers as a secure,
independent GitHub Actions runner, preserve every reviewer safety assertion, and
write a repeatable runbook so the next two hosts are right the first time. This
was urgent because five sessions had waited roughly two days while Windows runs
were repeatedly cancelled.

The immediate technical objective was to make the complete canonical Windows
matrix pass under the actual GitHub runner service account, not merely in an
Administrator's interactive shell. The broader #209 objective remains three
qualified hosts, ordinary routing away from EDGE-DEV, and failover proof.

# 3. Current state — what is true right now

- PR #214 merged to `main` as commit
  `36bd7a5fb2868916dfe12aac19e6e8c2db1a1d38`. It contains the service-account
  SID repair, physical-temp-path normalization, qualification workflow and
  supporting tests.
- The first candidate, `EDGE-RUNN-ENVY`, is Windows 11 Pro 25H2 build 26200 on
  an i7-10700 with 16 GB RAM. TPM is present and ready; Secure Boot is enabled.
  Its service `actions.runner.popcre-ai-devops.EDGE-RUNN-ENVY` was running.
- The host still has candidate labels only: `self-hosted`, `Windows`, `X64`, and
  `ai-devops-windows`. It has not been admitted to ordinary CI and must not be
  described as general capacity yet.
- Exact commit `fa46a1f336f8c34182ff7201742a141cde9c6a54` passed the canonical
  qualification in 1h00m14s: run
  https://github.com/popcre/ai-devops/actions/runs/33571202823, job
  https://github.com/popcre/ai-devops/actions/runs/33571202823/job/100065323527.
  Host security, service-visible dependencies, the complete Windows/Bash matrix,
  and reusable-workspace cleanup all passed.
- Independent exact-head review approved `fa46a1f`; the local report is ignored
  at `.ai/reviews/codex-final-check-20260901T230835-300279-14996.md`. Focused
  local proof was `ai-gemini` 62/62, `ai-grok-review` 199/199, qualification
  workflow test PASS, and PowerShell ACL tests PASS.
- The accompanying `verify` run `33571202865` had Linux pass. Its Windows jobs
  were cancelled exactly at their fixed job limits: `windows-offline` after
  about 75 minutes and `windows-reviewer-safety` after about 30 minutes. Logs
  show continuing passing assertions followed by `The operation was canceled`,
  not a failed assertion. The successful qualification is the stronger same-head
  complete-matrix proof; do not call qualification failed.
- `docs/independent-windows-runner-setup.md` now records the newest traps and the
  passing run. `plan_repo-throughput-restructure.md` now records the merge/pass
  and adds the required end-of-phase downstream drift check. This handoff and
  those two prose changes are the only documentation closeout changes.
- Second and third physical hosts, admission/routing, failover, restart/update
  proof, capacity reporting and EDGE-DEV retirement remain unfinished.

# 4. Everything we tried that did NOT work

- `Get-ComputerInfo` and the registry said `Windows 10 Pro` / version `2009`
  even after a clean Windows 11 installation. Build `26200`, Settings, Secure
  Boot and TPM proved Windows 11; legacy product-name compatibility strings are
  not an OS eligibility test.
- Reinstalling PowerShell with machine-scope `winget --force` said the system
  configuration did not support the package. The supported executable already
  existed at `C:\Program Files\PowerShell\7\pwsh.exe`; verify that path instead
  of repeatedly reinstalling the Store/MSIX package.
- Initial tool checks reported Git/GitHub CLI/jq absent because the open shell
  had stale PATH state. Direct version checks after installation were correct.
- Installing jq for the interactive user created a link the Network Service
  runner could not execute. A machine link alone was insufficient until the
  resolved target executable received read/execute for SID `S-1-5-20`; then the
  runner service was restarted.
- Generic `winget install python3` installed Python 3.14 while the Windows Store
  execution alias still captured `python`. The stable machine installation used
  by the shell is `C:\Program Files\Python313\python.exe` (3.13.14). Do not use a
  Store alias as runner proof.
- Installing Node and Python interactively and immediately checking the same
  shell did not prove service visibility. Restart the runner service, then let
  the qualification workflow test the service environment.
- Run `33559660147` passed preflight/dependencies/cleanup but failed later because
  the Gemini fixture granted ACLs to `$USERNAME`. Under Network Service that was
  the computer identity `EDGE-RUNN-ENVY$`, which Windows could not resolve as the
  service principal.
- Granting ACLs by username/name was therefore wrong. The durable repair resolves
  the current Windows security SID and grants by SID.
- Git Bash `/tmp/...` and a native Windows child process produced two spellings
  for the same Network Service temp directory. Comparing those raw strings caused
  false Grok boundary/concurrency stalls. Increasing timeouts would only hide the
  defect; canonicalizing the physical temp path fixed it.
- Repeatedly pushing prose to PR #214 would have made the exact-head qualification
  and review stale and started another hour-long run. The code was merged first;
  the prose closeout is separate.
- `gh pr merge --squash --admin --delete-branch` was rejected because merge queue
  is enabled. Re-running without `--delete-branch` merged successfully.

# 5. Root causes and key findings

- A Windows runner must be qualified as its service identity. Interactive-admin
  success is necessary for setup but not evidence that the runner can execute a
  dependency or manipulate the same paths.
- The service identity must be represented by its SID, not `$env:USERNAME`.
  The reusable warning and fix are in
  `docs/independent-windows-runner-setup.md` under “Lessons from the first host.”
- Git Bash and native Windows can expose different textual names for one physical
  temp directory. New fixtures must immediately normalize with
  `TMP="$(cd "$TMP" && pwd -P)"` before exporting state, sandbox or progress paths.
- One runner registration equals one concurrent job. Multiple registrations on
  the same 16 GB computer create resource contention and do not provide physical
  failover. Issue #210 owns bounded parallelism after three independent hosts exist.
- `ai-devops-windows` is the candidate/qualification label.
  `ai-devops-windows-qualified` is the intended admission label only after
  current-main admission proof. `edge-dev` belongs to the daily-use host and must
  not be copied to candidates.
- Job cancellation at a declared timeout is distinct from a failed assertion.
  Run `33571202865` demonstrates the ordinary workflow is too long for its current
  limits; #161/#162 own making ordinary CI fast. Do not weaken or delete tests in
  #209 to turn those cancellations green.

# 6. Exact next steps

1. From a fresh isolated current-main checkout, read `AGENTS.md`, the STATUS table
   and B2a section of `plan_repo-throughput-restructure.md`, issue #209, and
   `docs/independent-windows-runner-setup.md`. Verify merge
   `36bd7a5fb2868916dfe12aac19e6e8c2db1a1d38` is on `origin/main` and run
   `33571202823` still concludes success. It worked when local and GitHub state
   agree on both identifiers.
2. Confirm this documentation closeout commit is on `origin/main`; if it is not,
   reconcile and ship only the two docs plus this handoff. It worked when the
   runbook names the SID/temp fixes and passing run, and the plan names the merge
   plus downstream drift check.
3. Admit `EDGE-RUNN-ENVY` only through the #209 design: add the
   `ai-devops-windows-qualified` label after verifying the installed runner still
   reports online/idle and its checked-out qualification code is on current main.
   Keep `ai-devops-windows`. It worked when GitHub shows the physical runner
   online/idle with both labels and no `edge-dev` label.
4. Route one representative ordinary Windows job to the qualified pool without
   changing required checks (that remains #166-last). Record the physical runner
   name in evidence. It worked when the job succeeds on `EDGE-RUNN-ENVY` and the
   log identifies that host rather than EDGE-DEV.
5. Set up physical hosts two and three by following the runbook exactly: supported
   Windows 11, TPM/Secure Boot, machine-scope Git/GitHub CLI/jq/PowerShell/Python/
   Node, jq target ACL for Network Service if needed, one runner service, candidate
   label only, Administrator evidence, then service-context qualification. It
   worked for each host only when its own exact-head canonical qualification run
   passes security, dependencies, complete matrix and cleanup.
6. Prove recovery and failover: reboot each runner, verify service auto-start and
   tool visibility, exercise cleanup, then intentionally take one qualified host
   offline while jobs complete on the other two. It worked when GitHub visibly
   reports reduced capacity, queued/running jobs use distinct physical names, and
   restoring the host returns it online without re-registration.
7. Record capacity as one concurrent job per online physical host, update issue
   #209 evidence, and retire ordinary Windows work from EDGE-DEV only after the
   three-host and failover gates pass. It worked when issue #209 contains all
   three qualification runs plus failover/routing evidence and no ordinary job
   depends on the daily-use machine.
8. At #209 closeout, reread every downstream phase B3 through final #166 in
   `plan_repo-throughput-restructure.md`. Update any assumption, interface,
   identifier or sequencing rule changed by the runner work, and delete this
   handoff only under the successor rule. It worked when the STATUS table has
   terminal #209 evidence and every downstream phase remains executable without
   relying on chat context.

# 7. Constraints and gotchas in force

- Work directly on `main` in this repository, but use an isolated checkout when
  the shared checkout contains another session's work. Never reset, clean, stage
  or overwrite unrelated changes.
- Before committing, `git var GIT_COMMITTER_IDENT` must show
  `Albert Hazan <u2giants@users.noreply.github.com>`. Stage only owned paths and
  push without force.
- Do not modify `.github/workflows/verify.yml` or
  `docs/self-hosted-windows-runner.md` as part of #209 without reconciling issue
  #161 / PR #213; another session owns fast ordinary CI.
- Do not raise timeouts, remove assertions, bypass ACL/security checks, add early
  `edge-dev`, or install multiple runner services on one computer as a repair.
- Exact-head qualification and independent review become stale when code changes.
  Pure prose after the proven merge does not retroactively invalidate the merged
  exact-head code evidence.
- The repository is public. Never commit runner tokens, device IDs, product IDs,
  private LAN details, raw transcripts, or secrets.
- Fork approval remained `all_external_contributors` during setup. Preserve that
  safety boundary.
- The full plan sequence remains #161, #162, #163, #210, #164, #167, #169, #168,
  then #166 last after #209. #209 must not absorb those later deliverables.

# 8. Access and environment

- GitHub CLI is authenticated for `popcre/ai-devops`; PR #214 and Actions runs
  were queried and merged through it. Recheck authentication in a fresh session.
- Current closeout checkout was
  `C:\Users\ahazan\AppData\Local\Temp\ai-devops-runner-f3e5a19892c5487ab88bc05c4b2842fb`.
  It is disposable after all closeout commits are proven on `origin/main`; do not
  treat that path as durable machine configuration.
- The runner itself is `EDGE-RUNN-ENVY`. The installed service and machine tools
  live outside the repository. The runbook contains the commands; no secret is
  required for offline qualification after registration.
- If a future step needs a registration token, generate it through authenticated
  GitHub at use time and never paste or commit it. Other secrets, if ever needed,
  live in the 1Password vault `vibe_coding`; no secret values belong here.
- The ignored exact-head review report is local evidence only. Durable evidence
  is the merge SHA and GitHub run URLs in section 3.

# 9. Open questions and risks

- 2026-09-02: two additional physical PCs have not been inventoried. Their exact
  CPU/RAM/Windows/tool state is unknown; the runbook's preflight must decide
  eligibility rather than assumptions from the first machine.
- 2026-09-02: ordinary workflow jobs still exceed their present timeout limits.
  This is a throughput risk owned by #161/#162, not a reason to weaken #209's
  qualification or inflate limits.
- 2026-09-02: admission/routing has not yet been proven on current main. A green
  qualification makes the first host eligible for the admission step, not proof
  that ordinary jobs already use it.
- 2026-09-02: three-host failover and aggregate capacity remain unproven. Until
  then, issue #209 is OPEN and EDGE-DEV retirement is unsafe.
- No item in this section needs Albert's judgment now; each has an authorized,
  objective next step in section 6.

## Handoff self-audit

1. **Yes.** Sections 1–3 establish the product, purpose and exact live state;
   sections 6 and 8 give a newcomer executable next actions and access context.
2. **Yes.** Sections 4–5 preserve every costly dead end and non-obvious service
   identity/path finding, while section 7 preserves the operating boundaries.
3. **Yes.** Sections 2–9 cover the goal, intended outcome, evidence, failures,
   findings, exact gated actions, constraints, environment and dated risks; every
   code/doc/merge state and identifier needed to resume is explicit.
4. **Yes.** A line-by-line sweep of sections 1–9 found no unresolved owner
   judgment: the dated risks each have objective authorized steps, and all settled
   owner choices found in sections 3–7 are consolidated in section 0 as “do not
   re-ask.” No sub-agents were used, so no part (b) exists.
