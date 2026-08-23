---
issue: 62
status: OPEN
owner: codex/reviewer-production-completion
---

# Reviewer production completion handoff — 2026-08-23

This is the authoritative continuation record for Albert Hazan's request to
repair every configured AI reviewer, install the repaired workflow, and prove
each reviewer by having it review a real open GitHub issue. Read this file before
the older reviewer handoffs. The older files and plans contain useful engineering
history, but several of their STATUS tables were not updated after their code
landed and therefore understate the current installed state.

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put this entire list to Albert in one message before attempting the blocked live
qualifications. Do not raise these one at a time over several days.

### Blocking completion of the reviewer goal

1. **Restore Z.ai/GLM allowance.** The GLM implementation, pinned OpenCode
   service, authentication, model discovery, and production health checks pass,
   but Z.ai returns HTTP 429/provider code 1113 for exhausted balance/resource
   package. Recommendation: Albert should renew the Z.ai Coding Plan and reply
   `GLM funded`. This blocks a current installed GLM review of a real open issue.

2. **Approve the Gemini Google OAuth flow.** Gemini is deliberately quarantined
   until the installed wrapper can be live-qualified; the available Google login
   requires opening Albert's signed-in browser and transferring the one-time OAuth
   result. Recommendation: Albert should explicitly reply `approve Gemini OAuth`
   while available to complete the browser flow. This blocks the Ubuntu/current
   production Gemini hostile-write qualification and its real open-issue review.

3. **Approve rotation of two exposed MCP tokens.** During an earlier Codex review,
   raw DesignFlow DevOps MCP and NAS MCP tokens appeared in reviewer output before
   the reviewer isolation was repaired. Treat both credentials as compromised even
   though they are not in source or this handoff. Recommendation: Albert should
   explicitly approve rotation of both tokens; use the `secrets-to-1password`
   skill and vault `vibe_coding`, never print values. This is a security obligation
   adjacent to the reviewer work and must not disappear merely because it is not a
   wrapper feature.

### Already settled — do NOT re-ask

1. **Qwen live testing is skipped while credits are exhausted** (owner decision,
   2026-08-23). Do the best possible implementation/offline verification, retain
   Qwen's fail-closed quarantine, and do not spend or request Qwen credits in this
   workstream unless Albert later reverses this decision.

2. **Do not remove, disable, replace, bypass, or stop using a broken reviewer**
   (standing owner decision). Repair must preserve the capability. A provider that
   cannot currently pass a paid qualification stays visibly quarantined; quarantine
   is a safety state, not a substitute for finishing its implementation.

3. **Work directly on `main` in `u2giants/ai-devops`** and use GitHub plus the
   canonical installer as production truth. Do not create a feature branch for
   this repository and do not live-edit production.

4. **Do not stop for recoverable command or CI failures.** Correct them and
   continue. Stop only for missing owner authority, credentials/account state, or
   risk of destructive loss.

## 1. What this application is

`C:\repos\ai-devops` is the Windows checkout of the public
`u2giants/ai-devops` repository. It is POP Creations' backup-and-restore toolkit
for a multi-model AI development workflow. It contains Bash and PowerShell
commands, reviewer wrappers, shared safety/evidence helpers, configuration
templates, skills, installers, documentation, and offline verification suites.
It is not a web application, container, database, or hosted deployment.

For this work, "production" means:

- source of truth on GitHub `main`;
- a successful exact-head GitHub Actions `verify` run on Linux and Windows;
- canonical installation on the Ubuntu host reached as SSH alias `vps`, login
  user `ai`, repository `/worksp/ai-devops`;
- installed-command/source SHA and manifest hashes matching GitHub;
- reviewer doctors, quarantines, lifecycle/evidence paths, and real provider
  calls behaving truthfully.

The complete configured reviewer inventory is defined by
`bin/ai-review-preflight:21` and `bin/ai-review-preflight:230`:

1. Claude Opus 5 (`ai-claude-review`)
2. Grok (`ai-grok-review`)
3. Kimi (`ai-kimi`)
4. GLM 5.3 (`ai-glm` through pinned OpenCode)
5. Muse Spark 1.2 Contributor (`ai-muse`)
6. Gemini 3.7 Flash (`ai-gemini` through Antigravity `agy`)
7. Qwen Code (`ai-qwen`)
8. Codex GPT-5.6 (`ai-codex-review`)
9. DeepSeek (`ai-deepseek-agent`)

The user is Albert Hazan, a business owner rather than a programmer. Report
results in plain business English and ask him to act only when the session truly
cannot do the action with its authenticated tools.

## 2. What we set out to do this session, and why

Albert's persistent objective is:

> Repair every configured reviewer so it operates safely and reliably in the
> installed production workflow, then prove each reviewer by invoking it to
> review a real open issue in an authorized repository; complete tests,
> independent exact-head review, commit, push, install, and verify the resulting
> production state without stopping for recoverable failures.

The work began as a review of logs and failures across all reviewers. Albert
explicitly rejected "running away" from broken providers: removal, disablement,
bypass, or replacement is not a repair. The effort ran for roughly two days and
uncovered shared evidence defects, provider-specific lifecycle defects, Windows
process cleanup races, installed-state drift, account limitations, and repeated
CI cancellations caused by concurrent pushes to `main`.

The immediate goal of the interrupted final turn was a requirement-by-requirement
completion audit. It determined that green CI and production doctor output are
necessary but not sufficient: every one of the nine configured reviewers needs
safe implementation evidence, exact installed state, and a real open-issue
provider result unless the owner explicitly waived the paid test (Qwen only).

Open GitHub issue #62, "Implement complete repository strategy audit
remediation," is this handoff's retirement contract:
https://github.com/u2giants/ai-devops/issues/62

## 3. Current state — what is true right now

### 3.1 Git, CI, independent review, and production installation

As captured at 2026-08-23T23:40Z:

- Local HEAD: `3e252bcae2b1890a8ca0d00dc11dc0d210e91e0f`
- `origin/main`: `3e252bcae2b1890a8ca0d00dc11dc0d210e91e0f`
- Ubuntu production `/worksp/ai-devops` HEAD:
  `3e252bcae2b1890a8ca0d00dc11dc0d210e91e0f`
- Local worktree was clean before this handoff file was created.
- Git committer identity was verified as
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Final GitHub Actions run `32670923983` passed all three jobs:
  - `windows-offline`: success (about one hour)
  - `windows-reviewer-safety`: success
  - `linux-offline`: success
  - URL: https://github.com/u2giants/ai-devops/actions/runs/32670923983
- Production `ai-devops doctor` reported all required checks passed and the
  managed command/skill hashes matched the install manifest.
- The exact combined head received an independent read-only Codex final check
  with 168/168 bound Windows reviewer tests passing and verdict `APPROVE`:
  `.ai/reviews/codex-final-check-20260823T223721-1094226-15710.md`.

The final combined commit `3e252bc` includes a concurrent session's Windows
process-tree fix, "Stop Windows reviewer trees without console signals." The
independent review specifically checked native supervisor-first shutdown,
validated `taskkill` fallback, preservation of paid-work uncertainty before
cleanup, and the 168 Windows runtime/timeout/fallback/cleanup cases.

### 3.2 Commits landed during the final repair wave

These are all ancestors of current `main`:

1. `37c0c7acf716b3f038063ed37e3ea3146cf987f4` — **fix dynamic reviewer
   quarantine status**. `ai-review-preflight status` now represents active
   quarantine as `status:"quarantined"`; doctor treats quarantine as a visible
   warning rather than an unknown/misleading state. Independent exact-head review:
   `.ai/reviews/codex-final-check-20260823T202158-897996-17245.md`.

2. `bfa4445f5002cc452ef9cf53e29e2a5b274b0979` — **stabilize Windows reviewer
   cleanup**. Added a bounded five-second retry to the Grok test cleanup for
   native Windows current-directory handle release; persistent leaks still fail
   visibly. Independent review:
   `.ai/reviews/codex-final-check-20260823T204236-948321-18758.md`.

3. `d0592a3d64a74e103fd375c9416c999a6140b283` — **isolate Kimi artifact worker
   fixture**. The Kimi artifact-finalization test now exercises the real worker
   directly under explicit test mode instead of depending on an unrelated
   Windows detached-process bootstrap. Normal production launch behavior remains
   unchanged and separately covered. Kimi passed 203/203 locally. Independent
   review: `.ai/reviews/codex-final-check-20260823T215910-1028762-28573.md`.

4. `3e252bcae2b1890a8ca0d00dc11dc0d210e91e0f` — **stop Windows reviewer trees
   without console signals**. This is the current GitHub/production head and
   contains the native supervisor/Job Object process-tree repair described above.

### 3.3 Current production preflight inventory

Captured on the installed Ubuntu production host at 2026-08-23T23:40Z:

| Reviewer | Production preflight | Real open-issue evidence | What remains |
|---|---|---|---|
| Claude | `available`; `doctor --live` passed canonical `claude-opus-5` with only Read/Grep/Glob and plan permission | Installed review of open issue #62 completed with terminal `APPROVE`; `/worksp/ai-devops/.ai/reviews/claude-final-check-20260823T233713-772814-16961.md` | Treat the provider proof as complete. Carry forward its three small Grok follow-ups described below; do not repeat the paid Claude call. |
| Grok | `available` | Open issue #61 returned terminal `APPROVE`; durable proof in `tests/verification/grok-review-issue-61/2026-08-23-live.md` and `.ai/reviews/grok-issue-61-production-f4def41-20260823T040626Z-1726399.md` | Reconfirm report/source identity if required by the final audit; no new paid run should be necessary. |
| Kimi | `available` | Issue #46 production qualification, installed matrix 218/218, deleted-clone retrieval; `tests/verification/kimi-review-issue-46/2026-08-23-live.md` | No provider repair known. Reconfirm installed hash and artifact identity. |
| GLM | `quarantined`, failure `allowance-exhausted` | Historical installed GLM reviews exist, including issue #56 artifacts under `.ai/reviews/glm-issue-56-production-proof-*.md`; the current exact wrapper cannot be re-proven while Z.ai rejects paid calls | Owner must fund Z.ai, then run one current installed open-issue review and clear quarantine only after it passes. |
| Muse | `available` | Open issue #51 returned `NO FINDINGS`; `.ai/reviews/muse-issue-51-production-proof-20260822T184546Z-3871140-29679.md`; production heartbeat/state behavior also proved | Reconfirm installed hash/report identity; no new paid run should be necessary. |
| Gemini | `quarantined`, failure `live-qualification-required` | Windows partial hostile live evidence exists, but the authoritative `plan_gemini_reviewer_safety_repair.md` says Ubuntu/current production qualification remains incomplete | Owner-approved OAuth, complete hostile live qualification, then a real open-issue review. Keep quarantine until both pass. |
| Qwen | `quarantined`, failure `live-qualification-required` | Offline repair is extensive: `tests/test-ai-qwen.sh` 90/90 and shared governance coverage. No live call by explicit owner instruction because credits are exhausted | Do not test live. Verify the exact offline repair is landed/installed and retain quarantine. Document this as an owner-waived live proof, not as provider-qualified. |
| Codex | `available` | A real review of open issue #13 returned truthful `REJECT`; `bugs.md:782-799`. Numerous exact-head read-only reports exist under `.ai/reviews/` | Reconfirm the issue proof's source/report identity if final audit requires it; current exact-head final review is independently approved. |
| DeepSeek | `available`; installed `doctor --live` passed | No durable current production open-issue proof was located during the final audit | Invoke installed DeepSeek with `--review` against a real open issue (recommended #62 with its plan file) and preserve the metadata sidecar. |

Do not mistake availability for full completion. The explicit objective requires
real open-issue review evidence. Claude's missing call is now complete; DeepSeek
is the remaining available provider without a located durable issue-review proof.

### 3.4 Interrupted installed Claude review — completed after interruption

At approximately 2026-08-23T23:37:13Z the installed production command began a
Claude Opus 5 `final-check` against open issue #62. The issue body was fetched by
the production `gh` CLI into a temporary brief and passed through
`AI_REVIEW_BRIEF_FILE`; the source snapshot was exact production head `3e252bc`.

The chat/tool wait was interrupted by the user, but the remote review survived.
At 23:40Z the production process inventory (PID/name only, no command-line secret
exposure) showed:

- Claude PID `773505`, parent `773503`, command name `claude`.
- OpenCode/GLM service PID `637177`, parent `637103`, command name
  `opencode.exe` (normal long-running local service; do not confuse it with the
  Claude review).
- Snapshot directory:
  `/home/ai/.local/state/ai-devops/review-sandboxes/claude-final-check-20260823T233713-772814-16961-6c2f5cdf00e6`
- Packet tag/run:
  `claude-final-check-20260823T233713-772814-16961`

While this handoff was drafted, the review completed normally. A second safe
process-name check showed no Claude process; the sandbox was removed; the durable
report existed at:

`/worksp/ai-devops/.ai/reviews/claude-final-check-20260823T233713-772814-16961.md`

The report proves model `claude-opus-5`, reviewed commit `3e252bc`, source
digest `592f303554538e875c1a592d1c525fb2a588d84c8a74433e12cf884be4a234de`,
caller `codex`, elapsed time 371 seconds, only Read/Grep/Glob tools, and terminal
`## Verdict` = `APPROVE`.

Claude correctly said the reviewer/process-tree commit is safe but issue #62 as
a whole must stay open. It also identified three nonblocking Grok follow-ups:

1. `bin/ai-grok-review:490-499` (`on_paid_signal`) still stops the process tree
   before writing `remote-uncertain`, unlike the new safer helper. The lock
   remains fail-closed because EXIT cleanup is disarmed first, but the ordering
   should be made consistent for a perfect implementation.
2. `tests/test-ai-grok-review.sh:565-566` records two Windows-only skips as
   passing checks on non-Windows, mildly inflating Linux counts.
3. `bin/ai-grok-review:771` can leave a temporary stop directory behind if both
   stop request and fallback termination fail. This is cosmetic but should be
   cleaned without weakening uncertainty preservation.

Do not display `Win32_Process.CommandLine` or Linux `/proc/*/cmdline`; reviewer
and MCP credentials have previously reached process arguments/logs.

Safe initial inspection commands from Windows PowerShell:

```powershell
$ssh = 'C:\Program Files\Git\usr\bin\ssh.exe'
& $ssh -l ai vps 'ps -eo pid=,ppid=,comm= | grep -E "(claude|ai-claude)" || true'
& $ssh -l ai vps 'find /worksp/ai-devops/.ai/reviews -maxdepth 1 -type f -name "claude-final-check-20260823T233713-*" -printf "%f\n" 2>/dev/null'
& $ssh -l ai vps 'find /home/ai/.local/state/ai-devops -maxdepth 5 -type f -newermt "2026-08-23 23:36:00 UTC" -printf "%p\n" 2>/dev/null | grep -E "(review-lifecycle|review-scoreboard|claude-final-check-20260823T233713)" | sed -n "1,160p"'
```

These commands are retained as the recovery pattern for future interrupted paid
calls. Do not repeat this Claude call; its exact-source provider proof is complete.

### 3.5 Documentation state is not uniformly current

Several provider plans still say "integrated locally," "remote SHA pending," or
"landing open" even though the combined source is now on GitHub, independently
approved, installed, and green in CI. Examples:

- `plan_codex_reviewer_trust_repair.md:13`
- `plan_deepseek_reviewer_safety_repair.md:13`
- `plan_reviewer_shared_evidence_integrity.md:15`
- `plan_grok_reviewer_runtime_repair.md:14`
- `plan_muse_reviewer_availability_repair.md:13`
- `plan_qwen_reviewer_evidence_repair.md:13` (correct about live skip, stale about
  remote landing)

`plan_gemini_reviewer_safety_repair.md` explicitly supersedes the older
`plan_ai-gemini-wrapper.md` current-state text and remains authoritative for
Gemini. Do not implement from the older plan's stale STATUS table.

The source/runtime/CI state is authoritative for operational truth. Update only
the affected durable Markdown after the provider proof audit is complete; use
the `codex-docs-update` skill if Albert requests documentation closeout. Do not
create another code/CI cycle solely to make an old historical sentence look
current while provider work remains.

### 3.6 This handoff's delivery status

This write-once file is the only task-owned repository change from the handoff
request. The creating session will stage only this path, commit it directly to
`main`, reconcile any concurrent push without force, push it, and verify the
remote commit. The closing chat response carries the resulting commit SHA because
a Git commit cannot truthfully contain its own final hash. No reviewer source
change is being claimed as part of the handoff commit.

## 4. Everything we tried that did NOT work

These dead ends consumed most of the two-day runtime. Do not repeat them.

1. **Treating structural doctors as live provider proof.** A wrapper can pass
   local dependency, configuration, service, and model-discovery checks while the
   provider account rejects the actual paid turn. GLM demonstrated this exactly:
   `ai-glm doctor` passes every required check, but Z.ai returns allowance
   exhausted. Resolution: keep structural health and live availability separate;
   quarantine dynamically on provider allowance failure.

2. **Counting green implementation tests as proof of every reviewer's objective.**
   The final audit initially found Claude and DeepSeek available but without a
   clearly current durable open-issue proof. Claude is now proven on issue #62;
   DeepSeek remains. Resolution: map each provider to a specific installed
   open-issue artifact; availability alone is insufficient.

3. **Starting broad CI repeatedly while concurrent sessions were still pushing.**
   Repository concurrency cancels older runs when a newer push lands. Runs
   `32664324671` and `32669664304` were among the canceled exact-head runs; the
   latter had already passed Linux and focused Windows safety before commit
   `3e252bc` superseded it. Resolution: fetch immediately before final proof,
   identify concurrent source changes, reconcile them, and follow only the newest
   head. Never count a canceled run as success.

4. **Rerunning the same failing Windows CI without diagnosing the exact case.**
   Run `32665574825` failed after about 59 minutes because Kimi's artifact-level
   failure fixture depended on detached-worker startup acknowledgement within
   60 seconds under heavy Windows load. Resolution: separate that fixture from
   unrelated process bootstrap while leaving production launch behavior covered
   by dedicated tests (`d0592a3`).

5. **Assuming native Windows directory cleanup is immediate.** Grok tests could
   finish successfully while Windows briefly retained a process current-directory
   handle. Resolution: bounded five-second cleanup retry; persistent leaks remain
   visible failures (`bfa4445`). Later `3e252bc` added the proper native
   supervisor/Job Object process-tree stop path.

6. **Running `install.sh` locally from Windows.** The Unix installer attempted
   Linux-only stages and failed because `sudo`/Unix service behavior is not the
   Windows installation route. It did not damage production. Resolution: use the
   Windows-managed setup for Windows and run `./install.sh --skip-secrets` only on
   Ubuntu production as user `ai`.

7. **Installing production as root.** A root-run installation made
   `/etc/ai-devops/install-manifest.tsv` root-owned mode 0600 and lacked the
   correct `ai` user's systemd bus. Resolution: connect directly as `ai` and run
   the canonical installer there. The subsequent `ai` install restored correct
   ownership and passed doctor. Do not "fix" code for an operator-route error.

8. **Running independent final review without binding relevant tests.** The first
   exact-head review of `3e252bc` returned `BLOCKED`, not because static inspection
   found a defect, but because its packet said no Windows tests ran. Evidence:
   `.ai/reviews/codex-final-check-20260823T223408-1086884-4603.md`.
   Resolution: rerun with
   `--tests "bash tests/test-ai-grok-review.sh"`; 168/168 passed and the reviewer
   issued `APPROVE` in the later report.

9. **Expecting the production scoreboard to reconstruct historical proofs.**
   `ai-review-scoreboard report` reported that
   `/home/ai/.local/state/ai-devops/review-scoreboard/reviews.jsonl` did not exist.
   Resolution: use provider reports, metadata sidecars, lifecycle state, committed
   verification artifacts, and GitHub issue evidence. Do not manufacture ledger
   history or treat a missing ledger as evidence that reviews never occurred.

10. **Treating old plan STATUS tables as current runtime truth.** Several plans
    were not de-staled after concurrent landing/install work. Resolution: use
    current Git HEAD, `git ls-tree`, installed manifest hashes, CI, provider
    metadata, and the newest explicitly superseding plan. Update docs only after
    re-deriving the truth.

11. **Interrupting a local wait and assuming the paid remote turn stopped.** The
    latest Claude review survived the tool interruption and later published a
    valid terminal report. Resolution: inspect PID/PPID/executable name plus
    durable state, wait or reconcile, and never launch a duplicate paid review
    while the first may still be active or remote completion is uncertain.

12. **Exposing process command lines during diagnosis.** Earlier reviewer output
    exposed two MCP tokens before safeguards were tightened. Resolution: inspect
    executable name, PID, and PPID only unless arguments are independently proven
    safe. Never print raw `Win32_Process.CommandLine`, `/proc/*/cmdline`, secret
    environment variables, or provider payloads.

## 5. Root causes and key findings

1. **Reviewer lifecycle logic had drifted provider by provider.** Shared helpers
   now enforce preflight/quarantine, exact source digest, evidence packet sealing,
   lifecycle accounting, scoreboard fields, and incident correlation. The active
   provider registry is in `bin/ai-review-preflight:21,125-133,230`.

2. **A truthful quarantine is part of the repair, but not completion.** Dynamic
   provider/account failures must prevent assignment and appear as
   `status:"quarantined"`. This protects the workflow while preserving the
   implementation for later qualification. It does not satisfy the requested
   live proof.

3. **Windows process ownership, not provider intelligence, caused several long
   failures.** Detached workers, inherited current-directory handles, console
   signals, and child process trees behave differently on Windows. The current
   supervisor-first/Job Object path and bounded fallback are deliberate safety
   controls, not test-only complexity.

4. **Paid-work uncertainty must be recorded before fallible cleanup.** A killed
   local process does not prove the remote provider stopped. Grok and other
   wrappers must retain recovery-required/uncertain state rather than announcing
   cancellation or releasing cost locks optimistically.

5. **Exact-source identity means more than HEAD.** Dirty and untracked files,
   file names/boundaries, source digest, packet digest, provider session/model,
   caller, and lifecycle run ID all matter. The shared repair plans and hostile
   tests intentionally reject inference when identity is missing.

6. **Gemini's disposable copy is containment, not inherently read-only.** The
   current Gemini plan requires hostile before/after checks and exact conversation,
   model, report, and protected-source evidence on the supported platforms. Keep
   Gemini quarantined until its current production path passes.

7. **Qwen's offline repair is real but its live state is intentionally unknown.**
   It binds wrapper, installed runtime, credential preloader, exact evidence
   generation, and stale-source behavior. Because the owner waived live testing
   while credits are exhausted, the only truthful production state is
   quarantined with complete offline proof.

8. **The exact current production commit is already strong.** CI, installation,
   manifest, doctor, and independent bound-test review all agree on `3e252bc`.
   Do not rewrite working code just because historical Markdown says "landing
   open." First prove whether any actual behavior is missing.

9. **Two credentials are compromised independent of current repository state.**
   Removing them from later output or preventing recurrence does not unexpose
   them. Rotation remains a separate owner-authorized security action.

## 6. Exact next steps

Execute in this order. Each step includes its proof gate.

1. **Start with authoritative state, not this file alone.** In
   `C:\repos\ai-devops`, read `AGENTS.md`, this handoff, the STATUS table in
   `plan_full-strategy-remediation.md`, `bugs.md` reviewer section, and only the
   provider plan needed for the next provider. Run:

   ```powershell
   git fetch origin main
   git status --short
   git rev-parse HEAD
   git rev-parse origin/main
   git var GIT_COMMITTER_IDENT
   ```

   If another session pushed after `3e252bc`, inspect and safely fast-forward or
   reconcile; never reset or overwrite shared work. **You'll know it worked when:**
   the active checkout is clean or every dirty path has an identified owner,
   local/remote relationship is explicit, and identity is Albert's noreply
   address.

2. **Record the completed Claude proof and triage its small Grok follow-ups.**
   Verify the production report named in §3.4 remains readable and exact-source.
   Add it to the final provider evidence table. Inspect the three follow-ups in
   `bin/ai-grok-review:490-499,771` and
   `tests/test-ai-grok-review.sh:565-566`. Repair them if current source confirms
   the behavior; preserve the pre-cleanup `remote-uncertain` rule and bind the
   Grok tests into the required independent final review. **You'll know it worked
   when:** Claude's issue #62 proof is recorded once, `on_paid_signal` preserves
   uncertainty before fallible cleanup, non-Windows skips are not counted as
   executed passes, and temporary stop state is removed without releasing an
   uncertain paid-work lock.

3. **Run the missing installed DeepSeek open-issue proof.** First verify
   `ai-deepseek-agent doctor --live` again. Recommended issue is #62 because the
   governing plan is committed and open. From production `/worksp/ai-devops`, use
   a review message that asks DeepSeek to evaluate whether the current repository
   satisfies issue #62 and attach `plan_full-strategy-remediation.md` with
   `--file`; include `--review` so the wrapper requires a literal verdict and
   publishes exact-HEAD metadata. Example shape (do not paste secrets):

   ```bash
   cd /worksp/ai-devops
   ai-deepseek-agent doctor --live
   ai-deepseek-agent send \
     "Review open GitHub issue #62 against the attached authoritative implementation plan. Identify requirements that are complete, incomplete, or unsupported by evidence. This is a formal read-only issue review." \
     --file plan_full-strategy-remediation.md \
     --review
   ```

   Capture the printed session ID, transcript location, metadata sidecar, verdict,
   exact HEAD, and caller. **You'll know it worked when:** an installed provider
   call returns a valid `APPROVE`, `REJECT`, or `BLOCKED` verdict and the durable
   metadata binds it to the real open issue context and exact production commit.

4. **Audit existing Grok, Kimi, Muse, and Codex issue proofs against the objective.**
   Open only the named artifacts in §3.3 and their metadata. Confirm provider,
   exact source identity, issue was open at review time, terminal verdict,
   installed wrapper/source hash, no stale marker, and read-only boundary. Do not
   rerun paid reviews merely because their results are findings/rejects; a truthful
   negative verdict proves the reviewer works. **You'll know it worked when:** a
   reviewer-by-reviewer evidence table cites one reproducible artifact for each
   provider and labels any missing field instead of inferring it.

5. **Re-prove production installation after any intervening push.** Use direct
   user `ai`, never root:

   ```powershell
   $ssh = 'C:\Program Files\Git\usr\bin\ssh.exe'
   & $ssh -l ai vps 'cd /worksp/ai-devops && git pull --ff-only && ./install.sh --skip-secrets'
   & $ssh -l ai vps 'cd /worksp/ai-devops && git rev-parse HEAD && ai-devops doctor && ai-review-preflight status'
   ```

   **You'll know it worked when:** install summary passes every required stage,
   installed source SHA equals `origin/main`, manifest hashes match, available
   reviewers remain available, and the three account-gated providers are visibly
   quarantined for the correct reasons.

6. **After Albert funds GLM, run current installed GLM proof.** Re-run
   `ai-glm doctor`, then the provider-contacting live check/open-issue review using
   the documented `ask-glm`/`ai-glm` workflow. Use an open issue such as #62 or
   #38, keep the read-only agent, and save the exact result. Clear dynamic
   quarantine only after the protected canary and issue review pass. **You'll know
   it worked when:** Z.ai accepts the installed `glm-5.3` turn, a terminal
   exact-source issue report exists, and `ai-review-preflight status glm` reports
   available without manual falsification.

7. **After Albert approves Gemini OAuth, complete Gemini's authoritative plan.**
   Read `plan_gemini_reviewer_safety_repair.md` (it supersedes the older Gemini
   wrapper plan) and the `gemini-code-delegation` skill. Use the appropriate
   browser/computer skill for the signed-in OAuth interaction. Complete the
   Ubuntu/current production hostile-write, exact-resume, model, outside-sentinel,
   and durable-report qualification before invoking a real open issue. Never
   change global Antigravity settings or copy OAuth state into an invented
   isolation layer. **You'll know it worked when:** all protected targets remain
   byte-identical, the exact conversation/model/verdict is proven, a real open
   issue report is durable, and quarantine clears through the governed path.

8. **Keep Qwen quarantined and finish the owner-waived evidence audit without a
   live call.** Run its focused offline suite and shared preflight/packet/lifecycle
   suites on the exact final head; confirm installed wrapper/runtime/preloader
   hashes match the release. Do not call `ai-review-preflight qualify qwen`
   without a real successful live proof. **You'll know it worked when:** the
   implementation/offline contract is fully green, production remains safely
   quarantined, and the final report states that live open-issue proof was skipped
   by explicit owner instruction—not falsely passed.

9. **If any code changes are required, use the full safety landing route.** Read
   the affected wrapper's verification header and tests, patch with `apply_patch`,
   run focused tests plus the relevant Windows/Linux suites, then run one
   independent exact-head read-only final review with the critical test command
   bound into its packet. Verify identity, stage only owned files, commit directly
   to `main`, fetch/reconcile concurrent work, push without force, wait for the
   newest exact-head CI run to finish, install that SHA as `ai`, and re-run doctor.
   **You'll know it worked when:** exact reviewed SHA = `origin/main` = CI SHA =
   production SHA, CI is terminal success, and the original reviewer capability
   plus repaired symptom both work.

10. **Rotate the two exposed MCP credentials only after owner approval.** Read
    `secrets-to-1password` completely. Resolve the DesignFlow DevOps MCP and NAS
    MCP items in vault `vibe_coding` without printing values; create replacements,
    update references through protected channels, verify consumers, then revoke
    old values. Do not put values in chat, command arguments, output, logs, or
    commits. **You'll know it worked when:** old tokens are revoked, new references
    work in their intended clients, and no raw value appeared in evidence.

11. **Update durable status only after the evidence audit is settled.** Correct
    stale STATUS rows in the directly affected reviewer plans and `bugs.md`, while
    preserving historical investigation text and explicit Qwen/Gemini caveats.
    Do not rewrite another session's handoff. If code is unchanged, make a scoped
    documentation commit; otherwise land docs with the repair commit. **You'll
    know it worked when:** a new session no longer mistakes landed code for local
    work or a quarantine for qualification, and every statement links to current
    evidence.

12. **Perform the objective-level completion audit; do not close by vibe.** For
    all nine reviewers, require: safe implementation, focused hostile tests,
    shared governance, independent exact-head review covering relevant changes,
    commit/push/current CI, installed hash/doctor, and real open-issue review—or
    the explicit Qwen owner waiver. Keep issue #62 and this handoff open while
    GLM/Gemini actions remain. **You'll know it worked when:** every row has direct
    authoritative evidence and no requirement is inferred. Only then delete this
    handoff under the successor rule and close/update issue #62 as appropriate.

## 7. Constraints and gotchas in force

- Preserve capability. Never remove, disable, bypass, replace, or quietly stop
  using a reviewer as a shortcut.
- Quarantine is mandatory for unqualified providers, but it is not proof that the
  provider works.
- Qwen live testing is explicitly skipped until Albert restores credits.
- GPT-5.6 uses only explicit `low` or `medium` reasoning; never high/none/minimal.
- Reviewer wrappers, evidence tools, safety tests, and routing rules require one
  independent read-only exact-head final review before landing.
- This repository works directly on `main`. No feature branch, no force push, no
  broad staging, no destructive reset. Check concurrent changes before pull,
  merge, commit, or install.
- Stage only files owned by the current task. Other sessions share this checkout.
- Production installation is run as user `ai`, not root. Do not live-edit the
  server. GitHub is source truth; canonical install is deployment.
- `install.sh --skip-secrets` intentionally preserves existing protected config;
  it does not authorize secret changes.
- Never print raw process command lines or secret-bearing environment variables.
- Do not inspect raw transcript archives. They may contain credentials.
- Do not treat nonterminal narration, process existence, or provider exit zero as
  approval. Require exact terminal verdict and durable evidence.
- Do not clear quarantine manually merely to run a proof. Use the governed
  qualification path after the actual blocker is resolved.
- Do not run duplicate paid calls while an earlier turn may be active or remote
  completion is uncertain.
- A truthful `REJECT`/`BLOCKED` on an open issue can prove reviewer operation; the
  issue itself need not be ready to close.
- Several old plan STATUS rows are stale. Prefer explicitly superseding plans,
  current Git/installed state, and direct evidence.
- GitHub's concurrency policy cancels older verify runs on new pushes. Follow the
  newest exact head and do not count canceled runs as passing.
- Full Windows CI is expected to take about one hour. Added process-safety tests
  can push it slightly beyond prior duration; inspect terminal state rather than
  killing it because it is slow.
- This handoff is write-once. The successor may delete it only after all carried
  obligations are proven and retained elsewhere.

## 8. Access and environment

### Local Windows workstation

- Machine nickname/hostname: `edge-dev`
- Checkout: `C:\repos\ai-devops`
- Shell: PowerShell 7; use Git Bash at
  `C:\Program Files\Git\bin\bash.exe` for Bash tests.
- SSH executable: `C:\Program Files\Git\usr\bin\ssh.exe`
- GitHub CLI `gh` is authenticated as the authorized `u2giants` identity for this
  repository.
- Git committer identity must remain
  `Albert Hazan <u2giants@users.noreply.github.com>`.

### Ubuntu production

- SSH alias: `vps`
- Login user: `ai`
- Repository: `/worksp/ai-devops`
- Runtime configuration: `/etc/ai-devops/`
- Installed commands: `/usr/local/bin/ai-*` linked/managed from the repository
- Private reviewer/lifecycle state:
  `/home/ai/.local/state/ai-devops/`
- Current installed head at handoff capture: `3e252bc...`
- `gh`, Claude, Codex, Grok, Kimi, Muse, DeepSeek, OpenCode/GLM service, and the
  core toolkit are installed. Availability is governed by preflight, not mere
  executable presence.

### Credentials and protected state

- Approved 1Password vault: `vibe_coding`.
- Never include credential values in commands, reports, chat, handoffs, or Git.
- GLM provider credential exists and the local service authenticates, but the
  provider account has no current allowance.
- Gemini needs owner-approved Google OAuth interaction.
- Qwen credentials/implementation exist, but credits are exhausted and live
  testing is waived.
- Two exposed MCP tokens require owner-approved rotation; see §0 and §6.10.

### Useful authoritative files

- Repository router: `AGENTS.md`
- Main audit/workstream status: `plan_full-strategy-remediation.md`, `bugs.md`
- Shared evidence contract: `plan_reviewer_shared_evidence_integrity.md`
- Gemini current plan: `plan_gemini_reviewer_safety_repair.md`
- Qwen current plan: `plan_qwen_reviewer_evidence_repair.md`
- Provider plans: `plan_*reviewer*.md`, selecting only the active provider
- Reviewer incident guidance: `docs/reviewer-issues.md`
- Production CI evidence: run `32670923983`
- Final exact-head independent approval:
  `.ai/reviews/codex-final-check-20260823T223721-1094226-15710.md`

## 9. Open questions and risks

1. **Claude issue #62 provider proof is complete, but it surfaced three Grok
   follow-ups** (2026-08-23). They are nonblocking according to Claude and the
   current lock path remains fail-closed, but Albert's objective is "working
   perfectly," so the successor should inspect and repair them rather than
   dismissing them as release-note trivia. Exact locations are in §3.4 and §6.2.

2. **DeepSeek lacks a located durable open-issue proof** (2026-08-23). Its live
   doctor passed, but a provider liveness probe is narrower than the objective.
   The next session should run the formal issue #62 review in §6.3.

3. **GLM's current exact implementation has no present paid proof because of
   allowance exhaustion** (2026-08-23). Historical live evidence proves older
   integrated revisions, but not current provider availability. This is an owner
   account action, not a reason to weaken or replace GLM.

4. **Gemini cross-platform qualification remains incomplete** (2026-08-23).
   Windows partial evidence does not automatically prove Ubuntu/current
   production containment. Do not unquarantine based on structural tests.

5. **Qwen cannot meet the literal live open-issue requirement under the owner's
   current credit decision** (2026-08-23). The final completion statement must
   explicitly identify the waiver and quarantine; do not claim live qualification.

6. **Historical plan/document status may misdirect a successor** (2026-08-23).
   Some files describe integrated code as local/unpushed. Re-derive rather than
   reimplement. Update the plans after provider evidence is settled.

7. **Another concurrent push could supersede the proven head** (ongoing). Fetch
   before every exact-head review, final CI assessment, and production install.
   If `origin/main` advances, inspect ownership and affected reviewer paths before
   deciding which evidence remains valid.

8. **Credential rotation can break active consumers if done incompletely**
   (2026-08-23). Rotate only with explicit authority and verify replacement
   references before revoking old values, while still treating old values as
   compromised immediately.

9. **Issue #62 is broader than reviewer completion** (2026-08-23). This handoff
   uses it because the reviewer repairs are a core step of the full remediation.
   Finishing all reviewer rows does not alone prove every unrelated issue #62
   step is complete. Update/comment on the issue rather than closing it unless the
   full plan's remaining steps are also proven.

## Mandatory handoff self-audit

1. **Could a brand-new developer continue without missing a beat? Yes.** Sections
   1–3 define the repository, production meaning, exact goal, current SHAs, CI,
   install state, reviewer inventory, evidence, and the interrupted Claude run's
   completed terminal outcome.

2. **Could the developer continue as effectively as this session? Yes.** Sections
   4–5 preserve the expensive dead ends and root causes; §6 gives ordered commands
   and explicit proof gates; §§7–8 preserve operational and security constraints.

3. **Is every execution-critical detail included? Yes.** Background and outcome
   are in §§1–2; state/evidence in §3; failures in §4; decisions/findings in §§0
   and 5; commands/gates in §6; constraints/access in §§7–8; risks in §9.

4. **Would Albert see every required decision by reading only §0? Yes.** The
   line-by-line owner sweep of §§1–9 found three unresolved owner actions: fund
   GLM, approve Gemini OAuth, and approve rotation of two compromised MCP tokens.
   All three are consolidated in §0 with recommendation and blocked outcome.
   Qwen's no-live-test decision, capability preservation, main-only delivery, and
   persistence through recoverable failures are listed as already settled so the
   successor will not re-ask them.
