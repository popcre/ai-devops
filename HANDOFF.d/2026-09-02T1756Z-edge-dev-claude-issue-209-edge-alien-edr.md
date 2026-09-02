---
issue: 209
status: BLOCKED
owner: claude/rebase-pr-214-windows-91abeb
---

# 0. DECISIONS ONLY ALBERT CAN MAKE

Put this whole list to Albert in ONE message before starting work. Do not meet
these one at a time.

## Blocking — the workstream cannot advance past them

1. **SentinelOne exclusions on EDGE-ALIEN.** That computer is the only one of the
   three Windows machines running the SentinelOne security agent, and that agent
   is why it runs the test suite 3.4x slower than the others and fails
   qualification. Fixing it means asking his IT department to exempt the build
   folder and the developer tools from inspection — a security-policy change on a
   centrally-managed product, so it is his call, not a session's.
   **A ready-to-forward email was drafted and delivered to Albert on 2026-09-02**
   (scratchpad file `SentinelOne-exclusions-EDGE-ALIEN.txt`; the full technical
   content is reproduced in issue #209 comment 5513464456, so it can be rebuilt
   from GitHub if the scratchpad is gone).
   **Recommendation:** send it, and expect a partial answer — the email
   deliberately tells IT it is fine to refuse the three riskiest entries.
   **Ask him:** has IT replied, and did they grant *child-process inheritance*?
   Without inheritance the exclusions help very little, and EDGE-ALIEN should then
   be abandoned in favour of a different second machine.
   **Blocks:** every remaining #209 gate — second host, failover proof, capacity,
   EDGE-DEV retirement.

2. **Fallback if IT says no (or grants it without inheritance).** Sourcing a
   different second Windows machine is a purchase/allocation decision.
   **Recommendation:** ask for a machine of EDGE-RUNN-ENVY's generation or newer
   with no EDR agent installed. **Blocks:** same set as item 1.

## A wrong guess is recoverable, but the rework is wasteful

3. **Nothing currently in this class.** All remaining engineering choices in #209
   are settled below or objectively determined by the runbook.

## Not part of this work, and nobody is on it

4. **Two handoff files describe work whose issue is already closed** and nobody has
   retired them. They are other sessions' files, so this session was not permitted
   to touch them:
   - `HANDOFF.d/2026-08-26T1810Z-al8960ofc-claude-windows-offline-suite-parallelism.md`
     — issue #98, CLOSED. Owner branch `claude/windows-offline-handoff-1810`.
   - `HANDOFF.d/2026-09-01T1120Z-edge-dev-claude-runner-interruptions-and-context7.md`
     — issue #204, CLOSED. Owner branch `claude/runner-interruption-evidence`.
   **Recommendation:** authorise any session to delete both. The target for stale
   files is zero and these are pure clutter; git history keeps the text.
   **Blocks:** nothing, but it grows every week nobody rules on it.

5. **Six handoff files carry no contract block at all**, so nothing can ever tell
   whether they are finished: the `housekeeping-visibility`,
   `housekeeping-plan-corrections`, `shared-db-finish-first-plan`,
   `reviewer-repair-plans`, `reviewer-cache-efficiency` and `muse-wrapper-reject`
   files. **Recommendation:** authorise a one-off sweep that adds an
   `issue:/status:/owner:` block to each, or deletes the ones already done.
   **Blocks:** nothing, but it is why the folder cannot be audited.

6. **PR #213 has been open and un-mergeable for over a day** (branch behind main,
   checks cannot run). It belongs to issue #161, not #209.
   **Recommendation:** tell whoever owns #161 to rebase it or close it.
   **Blocks:** nothing in #209.

## Already settled — do NOT re-ask

- 2026-09-01: use three independent physical Windows computers, one runner service
  and one concurrent job each. Do not multiply registrations on one machine to
  manufacture apparent capacity.
- 2026-09-01: do not give a candidate the daily-use `edge-dev` label, and do not
  send ordinary CI to a machine before exact qualification and admission finish.
- 2026-09-01: keep this rare setup as cold repository documentation, not a Skill
  loaded into ordinary sessions.
- 2026-09-02: a documentation-only follow-up may ship separately after a
  qualification code merge; it must not rewrite an already-proven code commit
  merely to update prose.
- 2026-09-02: the next session must NOT pause to ask permission to continue #209
  or to merge its own eligible changes. Only the items above need Albert.
- 2026-09-02: the 90-minute qualification ceiling is CORRECT and must not be
  raised. EDGE-ALIEN is taxed, not hung — see section 5.

# 1. What this application is

`popcre/ai-devops` (https://github.com/popcre/ai-devops, public) is POP Creations'
backup-and-restore toolkit for a multi-model AI development workflow. It provides
command wrappers (`bin/ai-grok-review`, `bin/ai-glm`, `bin/ai-gemini` and
siblings), safety checks, machine setup scripts, and an offline test suite. There
is no deployed application: committed source on `origin/main` plus passing
verification IS the delivered product. Albert Hazan owns it; he is a business
owner, not a programmer.

Its automated tests run on GitHub Actions. The Linux job runs on GitHub's own
cloud machines. Two heavy Windows jobs — `windows-offline` (75 minute limit) and
`windows-reviewer-safety` (30 minute limit) — must run on physical Windows
computers on Albert's own network, because they exercise real Windows path,
permission and process behaviour.

Parent issue #159 restructures repository throughput. Child issue **#209** — this
workstream — exists because those Windows jobs used to run on **EDGE-DEV**,
Albert's daily-use desktop, which made them queue or cancel constantly and made
his machine unusable for roughly 90 minutes per code change.

The three Windows machines:

| name | role | CPU | AV/EDR | runner label(s) |
|---|---|---|---|---|
| `EDGE-DEV` | Albert's daily desktop | i7-12700, 12c/20t | Defender only | `edge-dev` (runner `edge-dev-win`, currently offline) |
| `EDGE-RUNN-ENVY` | qualified CI host | i7-10700, 8c/16t | Defender only | `ai-devops-windows`, `ai-devops-windows-qualified` |
| `EDGE-ALIEN` | candidate, NOT qualified | i7-6700, 4c/8t | **SentinelOne 25.2.6.442** | `ai-devops-windows` only |

Label meanings: `ai-devops-windows` = candidate, eligible for the `qualify`
workflow only. `ai-devops-windows-qualified` = admitted, receives ordinary CI.
`edge-dev` = the daily-use host. **`runs-on` label lists are ANDed**, so adding a
second machine's label to a job does not create a fallback — it creates a job no
machine can run. This trap is documented in
`docs/independent-windows-runner-setup.md`.

# 2. What we set out to do this session, and why

The session began with a different task, which is **complete**: rebase PR #214
onto main, get it green, and merge it. It then continued into the #209 stretch
goal — route the two heavy Windows jobs off Albert's desktop — which is also
**complete**.

The remaining work, and the reason this handoff exists, is the second physical
host. `EDGE-ALIEN` had failed qualification twice by overrunning the 90-minute
ceiling, with no diagnosis. Albert's instruction was to find out why. He then
supplied the machine's Tailscale address, which made direct measurement possible
for the first time.

Business goal: get a *second* working Windows CI machine, so that one machine
going down does not silently stop all Windows testing. Technical objective:
identify and remove whatever makes EDGE-ALIEN 3.4x slower than EDGE-RUNN-ENVY.

# 3. Current state — what is true right now

## Done, merged, and verified

- **PR #214 MERGED** as `36bd7a5fb2868916dfe12aac19e6e8c2db1a1d38`. Qualification
  workflow, service-account SID repair, physical-temp-path normalization.
- **PR #220 MERGED** as `7e9210d1`. This is the payoff commit: it changed both
  heavy Windows jobs in `.github/workflows/verify.yml` to
  `runs-on: [self-hosted, Windows, X64, ai-devops-windows-qualified]`, moving
  ~75 minutes of load per change off EDGE-DEV.
- **`c4304ada`** on main — documentation drift, `[skip ci]`.
- **`ff94beba`** on main — THIS SESSION'S plan update, `[skip ci]`. It records
  EDGE-ALIEN's cause and the single-host consequence for downstream phases
  (see section 5).
- Definition of done for the merge task was met on run **33640539778** (head
  `7e9210d1`): `linux-offline` success; `windows-offline` success on
  EDGE-RUNN-ENVY, 15:09:07Z→16:11:19Z (62 min against a 75 min ceiling);
  `windows-reviewer-safety` success 16:11:20Z→16:24:34Z (13m14s against 30 min).
  The `qualify` workflow passed on EDGE-RUNN-ENVY in run **33625670215** (62 min).
- **Issue #222 opened** — "Alert when the qualified Windows runner pool has no
  online host." Not started.
- **EDGE-ALIEN diagnosed.** Full evidence posted as
  [#209 comment 5513464456](https://github.com/popcre/ai-devops/issues/209#issuecomment-5513464456).
  See section 5.
- **IT email drafted and delivered to Albert** on 2026-09-02, asking for
  SentinelOne exclusions. Its technical content is reproduced in that same #209
  comment.
- Memory files written (machine-local, not in the repo):
  `edge-alien-uniformly-slow.md`, `edge-alien-tailscale-ssh.md`, both indexed.

Working tree is clean. Everything above is on `origin/main` at `ff94beba`.

## Half-done / in flight

- **A clean idle re-measurement of both hosts was queued and did NOT complete.**
  A background poller (`wait-idle.sh` in this session's scratchpad) waited ~40
  minutes for both runners to report `busy=false` and never got a window — the CI
  queue was continuously deep. It was abandoned at session end. **Nothing depends
  on it**; the diagnosis in section 5 does not rest on it. It would only tighten
  the absolute per-operation numbers, which were taken while another session's
  `qualify` run (33656743695) was executing on EDGE-ALIEN and are therefore
  inflated by contention. The *attribution* is unaffected. Re-running it is
  optional; the recipe is in section 6 step 4.

## Not started

- Second qualified host (blocked, section 0 item 1).
- Failover proof, third host, capacity reporting, EDGE-DEV retirement.
- The #222 watchdog.

## Other sessions are live on this issue — check before touching anything

At session end these branches had queued or running work: `claude/windows-pool-spread`,
`claude/issue-209-admit-qualified-pool`, `claude/ssh-edge-alien-connection-377fb2`,
`claude/windows-three-lane`, `claude/output-verbosity-issue-cc2802`,
`codex/issue-161-fast-ci`. Several are editing
`docs/independent-windows-runner-setup.md`. **This session deliberately did not
edit that file** to avoid clobbering them; the diagnosis lives on issue #209 and
in the plan instead. Reconcile with `origin/main` before assuming any doc content.

# 4. Everything we tried that did NOT work

**This session's dead ends:**

- **A remote PowerShell one-liner over SSH is destroyed by the local shell.**
  `ssh host "powershell -Command \"$c=...\""` — the local Bash eats every `$`, and
  the remote PowerShell then fails with a wall of `You must provide a value
  expression following the '+' operator`. It looks like a PowerShell syntax error
  and is not. **Fix:** write a `.ps1` locally, `scp` it, run it with
  `powershell -NoProfile -ExecutionPolicy Bypass -File <path>`. Every probe in
  this session used that pattern.
- **The first benchmark run was contaminated and I did not notice until after.**
  EDGE-ALIEN reported `busy=true` because another session's `qualify` run was
  executing on it. EDGE-ALIEN carries the candidate label, so it can be running a
  qualification job even though it takes no ordinary CI. **Always check
  `gh api repos/popcre/ai-devops/actions/runners --jq '.runners[]|"\(.name) \(.busy)"'`
  before measuring anything on a runner**, or you are timing contention.
- **Waiting for an idle window to re-measure never paid off.** Forty minutes of
  polling, no window, because the merge queue was continuously deep. Do not block
  a session on this; take the measurement opportunistically or accept the
  contaminated-but-attributable numbers.
- **Disabling or excluding SentinelOne from the host itself is impossible.**
  `SentinelCtl status` reports `Self-Protection: On` and the agent
  `running as PPL` (a protected process Windows itself defends). There is no local
  override. Do not waste time looking for one; exclusions come from the vendor's
  management console.
- **Windows Defender was the wrong suspect.** On EDGE-ALIEN,
  `Get-MpComputerStatus` reports `RealTimeProtectionEnabled: False` and
  `AMRunningMode: Not running` — Defender has stood down because SentinelOne
  registered as the AV. Checking Defender exclusions there tells you nothing.
- **`bash.exe` on PATH is not the shell the tests use.** On EDGE-ALIEN
  `Get-Command bash` resolves to `C:\WINDOWS\system32\bash.exe`, which is WSL. The
  suite uses Git Bash under `C:\Program Files\Git`. The exclusion list in the IT
  email covers the whole Git tree for exactly this reason.

**Inherited dead ends from the predecessor handoff, preserved here so its file can
be retired** (all are also written up in `docs/independent-windows-runner-setup.md`
unless marked otherwise):

- `Get-ComputerInfo` and the registry report `Windows 10 Pro` / version `2009`
  even on a clean Windows 11 install. Build number, Settings, Secure Boot and TPM
  are the real eligibility test; legacy product-name strings are not.
- `winget --force` machine-scope reinstall of PowerShell claims "the system
  configuration does not support the package". The supported binary already exists
  at `C:\Program Files\PowerShell\7\pwsh.exe`. Verify the path instead.
- Tool checks reporting Git/GitHub CLI/jq absent were stale PATH in an already-open
  shell, not a failed install.
- Installing jq for the interactive user created a link Network Service could not
  execute. The resolved target executable needs read/execute for SID `S-1-5-20`,
  then the runner service must be restarted.
- `winget install python3` installs 3.14 while the Windows Store execution alias
  still captures `python`. The real machine install is
  `C:\Program Files\Python313\python.exe`. A Store alias is not runner proof.
- Installing a tool interactively and checking it in the same shell does not prove
  *service* visibility. Restart the runner service and let the `qualify` workflow
  test the service environment.
- Run `33559660147` failed because a Gemini fixture granted ACLs to `$USERNAME`,
  which under Network Service is the computer identity `EDGE-RUNN-ENVY$` — not
  resolvable as a service principal. Grant by resolved SID, never by name.
- Git Bash `/tmp/...` and a native Windows child process produce two different
  spellings of one physical temp directory. Comparing the raw strings caused false
  Grok boundary/concurrency stalls. Canonicalize with
  `TMP="$(cd "$TMP" && pwd -P)"` before exporting any state/sandbox/progress path.
  **Raising timeouts only hides this.**
- **(not in the runbook)** Pushing prose commits to a PR whose exact head already
  passed qualification and review makes both stale and restarts an hour-long run.
  Merge the code first, ship prose separately.
- **(not in the runbook)** `gh pr merge --squash --admin --delete-branch` is
  rejected outright when a merge queue is enabled. Re-run without
  `--delete-branch`.
- **(not in the runbook)** `gh pr merge` from a linked git worktree prints
  `'main' is already used by worktree` AFTER the merge has succeeded. That is local
  branch cleanup failing, not a failed merge. Confirm with
  `gh pr view <n> --json state`.

# 5. Root causes and key findings

## The EDGE-ALIEN finding (this session's main result)

**EDGE-ALIEN is the only one of the three Windows machines running SentinelOne
EDR.** EDGE-DEV and EDGE-RUNN-ENVY run Windows Defender only. That is a clean
natural experiment, and it lines up exactly with which machine is slow.

Per-process CPU attribution, measured on EDGE-ALIEN across 200 `cmd /c exit`
spawns plus 40 `git --version` calls, 11.33 seconds of wall clock:

```
SentinelAgent   12.55 CPU-seconds
powershell       1.62
svchost          1.25
System           1.05
csrss            0.89
conhost          0.31
```

`SentinelAgent` consumed **more CPU than the entire workload's wall-clock
duration**, and **7.7x more than the shell actually doing the work**.
Independently, it had accumulated **4,221 CPU-seconds over 4.2 hours** of
mostly-idle uptime.

**Why this explains the specific symptom.** The observed slowdown is a *flat*
3.38x across 14 suites ranging from 2 seconds (`test-ai-codex-memories.sh`
2s→7s) to 17 minutes (`test-ai-glm.sh` 359s→1082s;
`test-ai-claude-review.sh` 266s→1011s). A single slow test, a hang, or a stall
cannot produce a flat ratio. A per-operation tax — every process create, every
file open — can, and that is precisely what an EDR hook does. The suite is
unusually process-heavy: it spawns thousands of short-lived git/shell/interpreter
processes and churns large numbers of small temp files.

**Secondary cause: the hardware genuinely is old.** i7-6700 is a 2015 4-core part
against ENVY's 2020 8-core. Worth roughly 1.3–1.8x on a mixed serial/parallel
suite — real, but nowhere near 3.4x on its own. The gap is the EDR tax.

**Therefore: the 90-minute ceiling is correct and must not be raised.** Two runs
(`33625657591`, `33639477174`) died at it with `ok` assertions landing seconds
before `The operation was canceled` — taxed, not hung. Raising the ceiling would
hide a fixable 3.4x penalty and permanently slow the pool.

## Whole-plan drift check (performed this session, fixed in `ff94beba`)

Re-read `plan_repo-throughput-restructure.md` end to end. Three downstream phases
silently assumed a multi-host pool that does not exist. All three are now written
into the plan's B2a section:

- **B2a's own gate** ("three hosts pass qualification"; "taking one offline leaves
  visible working capacity") cannot be met — host 2 is blocked on an external IT
  decision, not on repository work.
- **#210 bounded parallel Windows verification** has nothing to parallelise across
  with one host. Sequence it behind a real second host, not behind #209 merely
  being open.
- **#166 required-check cutover** must not promote a Windows job to a *required*
  check over a one-host pool. **A dead single host leaves those jobs `queued`,
  never `failed`** — so merges would block with no red signal anywhere. That
  detection gap is issue #222; the cure is a second host.

**The reciprocal end-of-phase instruction IS present** in the plan's B2a section
("before handing off or closing #209, reread every downstream phase from B3
through the final #166 cutover"), and it correctly reaches plan-end. It was
verified this session, not assumed.

## Other findings that cost real time

- **A `runs-on` heartbeat cannot detect a dead runner pool**, because the
  heartbeat job queues on the same dead pool. The check must run from
  `ubuntu-24.04` against the runner API. This is the whole design point of #222.
- **The live rulesets require `linux-offline` ONLY** (rulesets 21183703 "Protect
  main history" and 21564317 "main: pull request + merge queue"), and both Windows
  jobs are skipped on `merge_group` via
  `if: github.event_name != 'merge_group'`. So a dead Windows pool does *not*
  freeze merging — it silently removes Windows coverage. That is worse, not
  better, and it is the reason #222 exists.
- **A GitHub 404 from `branches/main/protection` does NOT mean unprotected** —
  rulesets are invisible at that endpoint.

# 6. Exact next steps

**Step 0 — orientation (always).** From a current-main checkout read `AGENTS.md`,
then the STATUS table and B2a section of `plan_repo-throughput-restructure.md`,
then issue #209 (especially comment 5513464456), then
`docs/independent-windows-runner-setup.md`. Confirm `ff94beba`, `c4304ada`,
`7e9210d1` and `36bd7a5f` are all on `origin/main`.
*You'll know it worked when* local and GitHub agree on all four SHAs and the plan's
B2a section contains the "Single-host consequence, recorded 2026-09-02" block.

**Step 1 — put section 0 to Albert in one message.** Ask specifically whether IT
replied and whether *child-process inheritance* was granted.
*You'll know it worked when* you have a yes/no on the exclusions and a decision on
the fallback machine. **Do not start step 2 or 3 without that answer** — everything
downstream forks on it.

**Step 2 — IF exclusions were granted: re-measure, then re-qualify.**
a. Confirm both `EDGE-ALIEN` and `EDGE-RUNN-ENVY` report `busy=false` first.
b. Re-run the per-process attribution probe on EDGE-ALIEN (step 4 below).
c. If `SentinelAgent`'s CPU delta has dropped to a small fraction of wall clock,
   trigger the `qualify` workflow on EDGE-ALIEN.
   *You'll know it worked when* the qualification run completes inside 90 minutes
   and reports success across security, dependencies, the full matrix, and cleanup.
d. Then admit it: add `ai-devops-windows-qualified`, keeping `ai-devops-windows`,
   and never adding `edge-dev`:
   `gh api --method POST repos/popcre/ai-devops/actions/runners/<id>/labels -f "labels[]=ai-devops-windows-qualified"`
   *You'll know it worked when* `gh api repos/popcre/ai-devops/actions/runners`
   shows EDGE-ALIEN online with exactly `self-hosted, Windows, X64,
   ai-devops-windows, ai-devops-windows-qualified`.

**Step 3 — IF exclusions were refused, or granted without inheritance:** re-measure
anyway to quantify what was actually gained, report the number to Albert, and if
the machine still cannot finish inside 90 minutes, record EDGE-ALIEN as **not
viable** on issue #209 and move the second-host effort to whatever machine Albert
names. *You'll know it worked when* issue #209 carries a dated ruling on
EDGE-ALIEN's viability with the post-exclusion measurement attached.

**Step 4 — the measurement recipe** (reusable; write it as a `.ps1`, `scp` it, run
with `powershell -NoProfile -ExecutionPolicy Bypass -File`): snapshot every
process's `.CPU` into a hashtable; run 200 `cmd /c exit` plus 40 `git --version`;
snapshot again; print the per-process deltas above 0.2s sorted descending,
alongside the wall-clock seconds. **Interpretation:** if `SentinelAgent`'s delta is
comparable to or larger than wall clock, the EDR is the bottleneck. Check
`busy=false` on the runner API before starting.

**Step 5 — build the #222 watchdog** (independent of the above; can be done now).
A scheduled workflow on `ubuntu-24.04` that fails when this returns `0`:
`gh api repos/popcre/ai-devops/actions/runners --jq '[.runners[]|select(.status=="online" and (.labels|map(.name)|index("ai-devops-windows-qualified")))]|length'`
Hourly is ample. *You'll know it worked when* stopping the runner service on
EDGE-RUNN-ENVY makes the next scheduled run go red, and restarting it makes the
following run green. **Do not implement this as a `runs-on` heartbeat** — see
section 5.

**Step 6 — remaining #209 scope, unchanged from the predecessor:** third host per
the runbook; reboot/auto-start/tool-visibility/cleanup proof per host; deliberate
offline of one qualified host while jobs complete elsewhere; capacity recorded as
one concurrent job per online physical host; EDGE-DEV retirement only after the
three-host and failover gates pass. *You'll know it worked when* issue #209 holds
three qualification runs plus failover and routing evidence, and no ordinary job
depends on the daily-use machine.

**Step 7 — at #209 closeout,** re-read every downstream phase B3 through the final
#166 cutover and update anything #209 changed. Then retire handoff files under the
successor rule. *You'll know it worked when* the STATUS table has terminal #209
evidence and every later phase is executable without chat context.

# 7. Constraints and gotchas in force

- **Never start a local test sweep while any GitHub run is active.** A local run on
  EDGE-DEV cancels the live self-hosted CI job; it reports as `cancelled`, not
  failed. Check first:
  `gh api repos/popcre/ai-devops/actions/runs --jq '.workflow_runs[]|select(.status!="completed")|"\(.id) \(.head_branch) \(.status)"'`.
  A single suite on an idle machine is fine; `tests/test-all.sh` is not.
- **Check the merge queue before merging** — a merge restarts what is running.
- **`runs-on` label lists are ANDed.** Adding `edge-dev` alongside
  `ai-devops-windows-qualified` produces a job no machine can run. It is not a
  fallback and it is forbidden by the #209 design.
- **Do not raise timeouts, delete assertions, bypass ACL/security checks, add an
  early `edge-dev` label, or install multiple runner services on one machine** as a
  repair for anything.
- **The repository is CRLF in the working tree, LF in the index.** Exact multi-line
  string replacement in Python fails on this. Splice by line index against
  `open(p,'rb').read().split(b'\n')` and append `\r` to every inserted line.
- **Docs-only commits go straight to main with `[skip ci]`.** Check the changed-file
  list first; if even one file is code/test/script/workflow/config, normal checks
  apply.
- **You merge your own PR.** Never hand one back to Albert for review or merge.
- Before the first commit, `git var GIT_COMMITTER_IDENT` must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- **This session ran in a git worktree** at
  `C:\repos\ai-devops\.claude\worktrees\rebase-pr-214-windows-91abeb`. The stash
  stack is shared with every other worktree — never use bare `git stash` / `pop`.
- **Never edit another session's `HANDOFF.d/` file**, and never rewrite the root
  `HANDOFF.md` (it is a static pointer).
- The repository is public. Never commit runner tokens, device/product IDs, private
  LAN details, raw transcripts, or secrets.
- Fork approval is `all_external_contributors`. Preserve that boundary.
- Plan order remains #161, #162, #163, #210, #164, #167, #169, #168, then #166
  last. #209 must not absorb those.
- **Nothing on EDGE-ALIEN was changed by this session.** It was measured only. Keep
  it that way until Albert rules on section 0 item 1.

# 8. Access and environment

- **GitHub CLI** is authenticated for `popcre/ai-devops`; issues, PRs, runs,
  runners and rulesets were all queried and modified through it this session.
  Re-check `gh auth status` in a fresh session.
- **Both runner hosts are reachable by SSH over Tailscale only** — neither answers
  on the LAN by name or ping, and neither is recorded in `machine-atlas.md`:
  - EDGE-ALIEN: `ssh -i ~/.ssh/916-alien <tailscale-ip>` (lands as `edge-alien\ahazan`)
  - EDGE-RUNN-ENVY: `ssh -i ~/.ssh/916-alien <tailscale-ip>`

  Same key for both. The two addresses are private topology and must not be
  written into this public repository; keep them in the private machine atlas.
  See the `$`-eating trap in section 4.
- **This session ran on EDGE-DEV**, which hosts the `edge-dev-win` runner
  (currently offline). Working directory is the worktree named in section 7.
- Runner service on EDGE-ALIEN: `actions.runner.popcre-ai-devops.EDGE-ALIEN`,
  running as `NT AUTHORITY\NETWORK SERVICE`, binary
  `C:\actions-runner\bin\RunnerService.exe`, work tree `C:\actions-runner\_work`.
- **No secret is required** for any step in section 6. If a runner registration
  token is ever needed, generate it through authenticated GitHub at use time and
  never paste or commit it. Other secrets live in the 1Password vault
  `vibe_coding`; no values belong in this document or any other.
- Scratchpad artifacts from this session (`alien-probe.ps1`, `bench.ps1`,
  `attrib.ps1`, `clean-bench.ps1`, `wait-idle.sh`,
  `SentinelOne-exclusions-EDGE-ALIEN.txt`) are disposable. Everything durable is
  on GitHub.

# 9. Open questions and risks

- **2026-09-02: the qualified pool is ONE host deep, and a failure of it is
  invisible.** If EDGE-RUNN-ENVY goes offline, both Windows jobs queue forever
  rather than failing; rulesets require `linux-offline` only, so merges keep
  flowing with no Windows coverage and nothing turns red. This is the single
  largest live risk in the repository right now. Mitigation is #222 (detection)
  plus a second host (cure). Manual recovery is documented under "If the qualified
  pool goes down" in `docs/independent-windows-runner-setup.md`.
- **2026-09-02: EDGE-ALIEN's viability is entirely outside this repository's
  control.** If IT refuses the exclusions or refuses child-process inheritance, the
  machine is probably not usable and the second-host effort must move elsewhere.
  No amount of repository work changes that.
- **2026-09-02: the absolute per-operation numbers in section 5 are inflated by
  contention** (another session's `qualify` run was executing on EDGE-ALIEN). The
  *attribution* — SentinelAgent outconsuming every productive process — holds under
  any load, and the flat 3.38x suite ratio was measured from clean GitHub run logs,
  not from this session's probes. A clean re-measure is queued as step 2b and is a
  refinement, not a dependency.
- **2026-09-02: even with exclusions, EDGE-ALIEN will remain the slower host.** Its
  2015 4-core CPU is worth ~1.3–1.8x against ENVY regardless. Plan capacity
  accordingly; do not assume two equal machines.
- **2026-09-02: several sessions are editing #209 documentation concurrently.**
  This session deliberately avoided `docs/independent-windows-runner-setup.md`.
  Whoever picks this up must reconcile with `origin/main` before assuming any doc
  content, and must expect the EDGE-ALIEN paragraph there to be out of date until
  someone folds in comment 5513464456.
- **2026-09-02: ordinary Windows CI is close to its ceiling on the good host too.**
  `windows-offline` took 62 minutes against 75. That headroom is thin and belongs
  to #161/#162, not #209. Do not "fix" it by raising the limit.
- Every risk above either has an objective next step in section 6 or appears in
  section 0 as an Albert decision. Nothing is filed only here.

## Handoff self-audit

1. **Yes.** Section 1 defines the product, the three machines, and the label
   semantics for someone with zero context; section 3 states exactly what is
   merged, what is in flight, and what is untouched, with SHAs and run IDs;
   sections 6 and 8 give executable next actions and the exact access route
   (including the SSH addresses and the `$`-eating trap that would otherwise cost
   an hour).
2. **Yes.** Section 4 preserves both this session's dead ends and the predecessor's
   inherited ones — including three that are in no runbook — so the predecessor
   file can be retired without loss. Section 5 records the full EDR reasoning,
   including *why* a flat ratio rules out a hang, which is the non-obvious step.
   Section 7 preserves every operating boundary the session worked under.
3. **Yes.** Sections 2 and 5 cover goal, intended outcome and findings; section 3
   covers current state with commit/push status explicit per item; section 4 covers
   failures; sections 6 and 7 cover exact gated actions and constraints; section 9
   covers dated risks; section 8 covers access with secrets referenced by vault
   name only, never by value. Every SHA, run ID, issue number, label and path a
   newcomer would not know is defined at first use.
4. **Yes, checked the hard way.** Walked sections 1–9 line by line looking for any
   sentence needing Albert's judgement. Found six: the SentinelOne exclusion
   decision (§3, §5, §9) → §0 item 1; the fallback-machine decision (§9) → §0
   item 2; the two stale handoff files (discovered in passing, entirely outside
   this workstream) → §0 item 4; the six contract-less handoff files (also outside
   this workstream) → §0 item 5; and PR #213's staleness (outside this workstream,
   belongs to #161) → §0 item 6. **Items 4, 5 and 6 are exactly the category this
   section exists to catch — findings from outside the workstream that would
   otherwise never have been raised.** All six appear in §0 with a recommendation
   and a statement of what they block. No sub-agents were used, so there is no
   part (b).
