---
issue: 209
status: OPEN
owner: claude/issue-209-handoff-wrapup
---

# 0. DECISIONS ONLY ALBERT CAN MAKE

Put this whole list to Albert in ONE message before starting work. Do not meet
these one at a time.

## Blocking — the workstream cannot advance past them

1. **OK to remotely reboot `edge-dev-win` and `EDGE-RUNN-ENVY`, one at a time,
   to prove the runner service auto-starts and the pool survives a host going
   down?** Both are physical machines reachable only over Tailscale/SSH — if a
   reboot hangs on a Windows Update prompt, BitLocker recovery, or anything
   else that needs a hand on the keyboard, no AI session can fix that
   remotely. Both runners were confirmed idle (`busy=false`) at 2026-09-03
   ~14:15Z, but that can change by the time this is read — re-check before
   acting (recipe in section 6 step 1).
   **Recommendation:** yes, reboot `edge-dev-win` first (it is the newer,
   better-known host), confirm it re-registers and comes back online and
   `Running`/`Auto` on its own, THEN do `EDGE-RUNN-ENVY` the same way. Do not
   reboot both at once — that would make the whole qualified pool
   simultaneously unavailable with no fallback.
   **Blocks:** step C from the predecessor handoff (failover/reboot proof),
   which is the only remaining engineering gate before #209 can move toward
   closeout.

2. **SentinelOne exclusions on EDGE-ALIEN — still unanswered.** Carried
   forward unresolved from the previous handoff (retired by this one; see
   section 4 for the preserved diagnosis). EDGE-ALIEN is the only one of the
   three Windows machines running SentinelOne EDR, and per-process CPU
   attribution showed the agent consuming more CPU than the entire test
   workload — see section 5 for the full finding, preserved verbatim from the
   retired file. A ready-to-forward email was drafted and delivered to Albert
   on 2026-09-02 (technical content reproduced in issue #209 comment
   5513464456; the original scratchpad file is gone — this session's session
   ID differs from the one that wrote it).
   **Recommendation:** ask again — has IT replied, and did they grant
   *child-process inheritance*? Without inheritance the exclusions help very
   little.
   **Ask him:** same question as before; still unanswered as of this
   session's start.
   **Blocks:** EDGE-ALIEN's admission as a third host. Does NOT block
   anything else — with edge-dev-win now admitted, the pool is two hosts
   deep, not one, so this is no longer the single point of failure it was.

## A wrong guess is recoverable, but the rework is wasteful

3. **Nothing currently in this class.** All remaining engineering choices in
   #209 are settled below or objectively determined by the runbook.

## Not part of this work, and nobody is on it

4. **Two handoff files describe work whose issue is already closed**, and
   this session was not permitted to touch them (not this workstream, not
   this session's files):
   - `HANDOFF.d/2026-08-26T1810Z-al8960ofc-claude-windows-offline-suite-parallelism.md`
     — issue #98, confirmed CLOSED 2026-09-03. Owner branch
     `claude/windows-offline-handoff-1810`.
   - `HANDOFF.d/2026-09-01T1120Z-edge-dev-claude-runner-interruptions-and-context7.md`
     — issue #204, confirmed CLOSED 2026-09-03. Owner branch
     `claude/runner-interruption-evidence`.
   **Recommendation:** unchanged from the predecessor — authorise any session
   to delete both. The target for stale files is zero and these are pure
   clutter; git history keeps the text. This is the second handoff in a row
   flagging the same two files; nobody has acted on it yet.
   **Blocks:** nothing, but it grows every week nobody rules on it.

5. **Two handoff files still carry no contract block**, down from six in the
   predecessor's count — four were fixed by other sessions between
   2026-09-02 and 2026-09-03, confirmed by re-scanning all of `HANDOFF.d/`
   this session. The two still missing one:
   - `HANDOFF.d/2026-08-25T1600Z-edge-dev-claude-reviewer-cache-efficiency.md`
   - `HANDOFF.d/2026-08-25T1700Z-edge-dev-claude-muse-wrapper-reject.md`
   **Recommendation:** authorise a one-off sweep that adds an
   `issue:/status:/owner:` block to each, or deletes them if already done.
   **Blocks:** nothing, but it is why the folder cannot be fully audited.

6. **PR #213 is still open, now reporting `mergeable: CONFLICTING`** (checked
   2026-09-03; the predecessor handoff described it as behind main with
   checks unable to run — it has since drifted further, not less). Branch
   `codex/issue-161-fast-ci` into `main`. Belongs to issue #161, not #209.
   **Recommendation:** unchanged — tell whoever owns #161 to rebase or close
   it.
   **Blocks:** nothing in #209.

## Already settled — do NOT re-ask

- 2026-09-01: use three independent physical Windows computers, one runner
  service and one concurrent job each. Do not multiply registrations on one
  machine to manufacture apparent capacity.
- 2026-09-01: do not give a candidate the daily-use `edge-dev` label, and do
  not send ordinary CI to a machine before exact qualification and admission
  finish.
- 2026-09-01: keep this rare setup as cold repository documentation, not a
  Skill loaded into ordinary sessions.
- 2026-09-02: a documentation-only follow-up may ship separately after a
  qualification code merge; it must not rewrite an already-proven code commit
  merely to update prose.
- 2026-09-02: the next session must NOT pause to ask permission to continue
  #209 or to merge its own eligible changes. Only the items above need
  Albert.
- 2026-09-02: the 90-minute qualification ceiling is CORRECT and must not be
  raised. EDGE-ALIEN is taxed by its EDR agent, not hung.
- 2026-09-02/03: "the whole idea of adding ENVY was to have more, not to take
  off of github" — GitHub-hosted runners stay in use for real work; the
  self-hosted pool is ADDITIVE, never a replacement. This governed the entire
  edge-dev onboarding in this session and must keep governing EDGE-ALIEN and
  any future host.
- 2026-09-03: edge-dev is now qualified and admitted — do NOT re-litigate
  whether it should be onboarded; that question is closed. See section 3.

# 1. What this application is

`popcre/ai-devops` (https://github.com/popcre/ai-devops, public) is POP
Creations' backup-and-restore toolkit for a multi-model AI development
workflow. It provides command wrappers (`bin/ai-grok-review`, `bin/ai-glm`,
`bin/ai-gemini` and siblings), safety checks, machine setup scripts, and an
offline test suite. There is no deployed application: committed source on
`origin/main` plus passing verification IS the delivered product. Albert
Hazan owns it; he is a business owner, not a programmer.

Its automated tests run on GitHub Actions in three lanes (defined in
`.github/workflows/verify.yml`):
- `linux-offline` — `ubuntu-24.04`, bash-only suite, the ONE required check
  on `main`, ~10 minutes.
- `windows-offline` — GitHub-hosted `windows-2025`, runs the full suite
  (bash + PowerShell) via `tests/test-all.ps1`, 100-minute ceiling, NOT
  required.
- `windows-reviewer-safety` — self-hosted `ai-devops-windows-qualified` pool,
  also the full suite, 30-minute ceiling, NOT required.

Parent issue #159 restructures repository throughput. Child issue **#209** —
this workstream — exists because the two heavy Windows jobs used to run on
**EDGE-DEV**, Albert's daily-use desktop, which made them queue or cancel
constantly and made his machine unusable for roughly 90 minutes per code
change. PR #229 (merged before this session) split the lanes so
`windows-offline` runs on GitHub's own hardware and only
`windows-reviewer-safety` needs the self-hosted pool — the self-hosted pool
is additive capacity, not a replacement for GitHub's runners, per Albert's
explicit, repeated instruction (quoted in section 0).

The three Windows machines, current state (verified live 2026-09-03 ~14:15Z
via `gh api repos/popcre/ai-devops/actions/runners`):

| name | role | CPU | AV/EDR | runner label(s) | status |
|---|---|---|---|---|---|
| `edge-dev-win` (host `EDGE-DEV`) | daily desktop + qualified CI host | i7-12700, 12c/20t | Defender only | `self-hosted, Windows, X64, edge-dev, ai-devops-windows, ai-devops-windows-qualified` | online, idle |
| `EDGE-RUNN-ENVY` | qualified CI host | i7-10700, 8c/16t | Defender only | `self-hosted, Windows, X64, ai-devops-windows, ai-devops-windows-qualified` | online, idle |
| `EDGE-ALIEN` | candidate, paused, NOT qualified | i7-6700, 4c/8t | **SentinelOne 25.2.6.442** | `self-hosted, Windows, X64, ai-devops-windows-paused` | online, **busy=true** — unexplained, see section 9 |

Label meanings: `ai-devops-windows` = candidate, eligible for the `qualify`
workflow only. `ai-devops-windows-qualified` = admitted, receives ordinary
CI. `ai-devops-windows-paused` = deliberately parked candidate, introduced
this session so EDGE-ALIEN stays off the candidate pool without deleting its
registration. `edge-dev` = legacy/daily-use marker label; **never put it in
any `runs-on` list** — `runs-on` label lists are ANDed, so combining it with
`ai-devops-windows-qualified` would create a job no machine can run. This
trap is documented in `docs/independent-windows-runner-setup.md`.

# 2. What we set out to do this session, and why

This session picked up the predecessor handoff's Step A/B: get `edge-dev-win`
re-registered as an automatic-start Windows service, fully tooled for the
service account (not just the interactive user), passing the host-security
preflight, passing the full qualification workflow, and admitted to
`ai-devops-windows-qualified` — restoring the second physical host that PR
#220 had taken offline when EDGE-DEV's runner registration was deliberately
destroyed earlier in the #209 workstream.

Midway through, two consecutive ~90-minute qualification runs failed on
trivial documentation regressions in `templates/system/CLAUDE-global.md`
(one dropped sentence, one broken line-wrap), both traced to a single prior
commit. Albert pushed back hard on the cost of that failure mode ("that
sounds like a really stupid reason for something to fail... each failure
costs us 90 minutes. how do we prevent this for all sessions?") and the
session's scope expanded to include a structural fix, not just a one-off
patch.

# 3. Current state — what is true right now

## Done, merged, and verified

- **`edge-dev-win` is qualified and admitted.** Confirmed live via
  `gh api repos/popcre/ai-devops/actions/runners`: online, labels
  `self-hosted, Windows, X64, edge-dev, ai-devops-windows,
  ai-devops-windows-qualified`. Qualification run succeeded (task poll showed
  `FINAL completed success`; dispatched against merge commit `ce8483ca`).
  Host-tooling gaps that blocked it are fixed on the host itself: Python is
  now a machine-wide install (was per-user, invisible to the
  `NT AUTHORITY\NETWORK SERVICE` account the runner service runs as); a
  `python3.exe` copy was placed next to `python.exe` (machine-wide installs
  only create the latter); the stale `C:\actions-runner\_work\ai-devops`
  tree (owned by the old interactive account) was deleted so the service
  account could rebuild it cleanly, resolving a "detected dubious ownership"
  git failure that broke three test suites.
- **`EDGE-RUNN-ENVY`'s candidate label restored.** It had been dropped
  earlier this session to deliberately steer qualification dispatches away
  from it while `edge-dev-win` was being fixed. Now carries
  `self-hosted, Windows, X64, ai-devops-windows, ai-devops-windows-qualified`
  again — full parity with `edge-dev-win`.
- **The pool is now two hosts deep**, confirmed live, both `online` and
  `busy=false` at last check. Issue #222 (watchdog for a fully-dead pool) is
  now less urgent than the predecessor handoff framed it — one host going
  down no longer means zero coverage — but is still open and still worth
  building (section 6 step 4, unchanged from predecessor).
- **PR popcre/ai-devops#239 MERGED** as `694a496c` — restored a sentence
  ("Otherwise recover first and finish the requested work.") dropped from
  `templates/system/CLAUDE-global.md` by commit `5e5bd088`.
- **PR popcre/ai-devops#241 MERGED** as `ce8483ca` — rewrapped a paragraph in
  the same file so "original capability still works" stays on one line,
  undoing a second regression from the same root commit.
- **PR popcre/ai-devops#242 MERGED** as `e1c9f0d6` — this is the systemic
  fix Albert asked for. Added `tests/test-client-globals-required-phrases.sh`,
  a bash duplicate of the 8-required/6-forbidden phrase check that
  `tests/test-context-audit.ps1` already runs, checked directly against the
  real `templates/system/CLAUDE-global.md` and
  `templates/system/AGENTS-global-codex.md` files. Because it lives under
  `tests/` it is auto-discovered by `tests/test-all.sh`'s glob (no
  registration needed) and now runs in `linux-offline`, the one required
  check on `main`. Verified two ways before merging: (a) ran clean against
  the current files; (b) injected the exact regression that broke #241
  (splitting "original capability still works" mid-sentence) and confirmed
  the new test fails with a specific, correct message, then restored the
  file and confirmed the diff was clean before committing. `linux-offline`
  passed on the PR itself before merge.
- All of `ff94beba`, `c4304ada`, `7e9210d1`, `36bd7a5f` (the predecessor
  handoff's "done" list) are confirmed on `origin/main` via
  `git merge-base --is-ancestor`, along with `694a496c`, `ce8483ca`, and
  `e1c9f0d6` from this session.
- Working tree in this worktree is clean on branch
  `claude/issue-209-handoff-wrapup`, checked out from `origin/main` at
  `e1c9f0d6` — this file is the only uncommitted content.

## Half-done / in flight

- **Nothing mid-flight in the code.** All engineering changes this session
  landed and merged.

## Not started

- **Failover/reboot proof (predecessor Step C).** Now unblocked — a second
  qualified host exists — but not yet performed. Blocked only on Albert's
  go-ahead (section 0 item 1), not on any repository work. Exact recipe in
  section 6 step 1.
- **Third host (EDGE-ALIEN).** Blocked on the still-unanswered SentinelOne
  exclusion question (section 0 item 2).
- **Issue #222 watchdog.** Not started. Recipe unchanged from predecessor,
  reproduced in section 6 step 4.
- **#209 closeout**: re-reading downstream plan phases B3 through the #166
  cutover for drift, and retiring this handoff under the successor rule once
  its own obligations are done. Not started — those steps come after
  failover proof.

## Other sessions — check before touching anything

Not verified this session which branches are currently live beyond what
`git log` and `gh pr list` show at write time. Re-check
`gh pr list --state open` and the runner busy status before starting new
work — the predecessor handoff listed six concurrently-active branches on
2026-09-02 and this session did not re-audit that list.

# 4. Everything we tried that did NOT work

**This session's dead ends:**

- **Elevated `winget uninstall`/reinstall of Python failed with exit 1603**
  ("The package installed for user scope cannot be uninstalled when running
  with administrator privileges"). **Fix:** run the uninstall from a
  non-elevated (same-user) PowerShell session instead — succeeded
  immediately. Elevation is not always the right privilege level for a
  per-user package operation; it can be the opposite of what's needed.
- **`test-completion-eval.sh` failed with `python3: command not found`** even
  though the exact same suite passed on `EDGE-RUNN-ENVY`. Root cause: a
  machine-wide Python install only creates `python.exe`, never
  `python3.exe` — ENVY apparently has both from an earlier separate step.
  **Fix:** copy `python.exe` to `python3.exe` next to it
  (`C:\Program Files\Python313\`), elevated.
- **"detected dubious ownership in repository at
  'C:/actions-runner/_work/ai-devops/ai-devops'"** broke three suites. The
  runner's persistent `_work` folder was still owned by the old interactive
  account from before the service reconfigure; the service account
  (`NT AUTHORITY\NETWORK SERVICE`) could not touch it. **Did NOT fix with a
  `safe.directory` exception** — that would weaken a real security check
  per the standing rule against bypassing ACL/security checks. **Fixed by
  deleting the entire stale `_work` tree** (and sibling `_actions`,
  `_PipelineMapping`, `_temp`, `_tool` caches) so the service rebuilt it
  fresh under its own ownership. Deleting stale state the service will
  regenerate is not the same as bypassing the check that caught the problem.
- **My own stale-branch checkout mistake, caught before it reached git.**
  `git checkout -q main 2>/dev/null || git checkout -q --detach origin/main`
  silently landed on a long-stale local `main` branch (dozens of commits
  behind `origin/main`) because this worktree already had a local `main`
  branch from session start, and the first half of the `||` "succeeded" by
  switching to it. I made an edit on top of that stale state before noticing
  — caught it via a standalone phrase-verification script reporting a phrase
  MISSING that I had just fixed, traced via `git log`/`git rev-parse`, then
  discarded the stray uncommitted edit and re-branched correctly from
  `origin/main`. **Lesson carried forward: in a worktree that might have a
  stale local `main`, branch explicitly from `origin/main` by name — never
  rely on a bare `git checkout main` succeeding meaning what you think it
  means.**
- **`gh api repos/popcre/ai-devops/actions/runs --jq ... -f branch=main -f
  status=completed`** returned 404 — wrong endpoint/flag combination.
  **Fix:** the workflow-scoped endpoint works:
  `gh api "repos/popcre/ai-devops/actions/workflows/verify.yml/runs?branch=main&status=completed&per_page=30"`.
- **`gh pr merge <n> --squash` on a PR gated by a merge queue prints
  `! The merge strategy for main is set by the merge queue` and looks like a
  no-op or failure.** It is neither — it silently arms auto-merge via the
  queue (confirmed by re-querying `autoMergeRequest`, which showed
  `enabledAt` matching the original call time). **Do not retry the merge
  command repeatedly when you see this message** — check
  `gh pr view <n> --json autoMergeRequest,state` instead and wait for the
  queue.

**Inherited dead ends from the now-retired predecessor handoff, preserved
here so nothing is lost:**

- A remote PowerShell one-liner over SSH is destroyed by the local shell
  (`ssh host "powershell -Command \"$c=...\""` — local Bash eats every `$`).
  **Fix:** write a `.ps1` locally, `scp` it, run with
  `powershell -NoProfile -ExecutionPolicy Bypass -File <path>`.
- A benchmark run on EDGE-ALIEN was contaminated by another session's
  concurrent `qualify` run — it carries the candidate label, so it can run
  qualification jobs even while excluded from ordinary CI. **Always check
  `busy` on the runner API before measuring anything.**
- Waiting for an idle window to re-measure EDGE-ALIEN never paid off — 40
  minutes of polling with a continuously deep merge queue, abandoned.
- Disabling or excluding SentinelOne from the host itself is impossible —
  `SentinelCtl status` reports `Self-Protection: On`, running as a
  Windows-protected process. Exclusions can only come from the vendor's
  management console (IT).
- Windows Defender was a red herring on EDGE-ALIEN — it had stood down
  (`RealTimeProtectionEnabled: False`) because SentinelOne registered as the
  AV. Checking Defender exclusions there tells you nothing.
- `bash.exe` on PATH is not the shell the tests use — on EDGE-ALIEN,
  `Get-Command bash` resolves to WSL's `C:\WINDOWS\system32\bash.exe`, not
  Git Bash at `C:\Program Files\Git`.
- `Get-ComputerInfo` and the registry can report "Windows 10 Pro" / version
  "2009" even on a clean Windows 11 install — legacy product-name strings
  are not the real eligibility test; build number, Secure Boot, and TPM are.
- `winget --force` machine-scope reinstall of PowerShell can claim "the
  system configuration does not support the package" when the supported
  binary already exists at `C:\Program Files\PowerShell\7\pwsh.exe" — verify
  the path before assuming the install failed.
- Tool checks reporting git/gh/jq absent can be stale PATH in an
  already-open shell, not a failed install.
- Installing jq for the interactive user creates a link Network Service
  cannot execute — the resolved target executable needs read/execute for
  SID `S-1-5-20`, then the runner service must be restarted.
- Installing a tool interactively and checking it in the same shell does not
  prove *service* visibility — restart the runner service and let the
  `qualify` workflow test the service environment.
- Grant Windows ACLs by resolved SID, never by `$USERNAME` — under Network
  Service that resolves to the computer identity (e.g. `EDGE-RUNN-ENVY$`),
  not a usable service principal.
- Git Bash `/tmp/...` and a native Windows child process can produce two
  different spellings of one physical temp directory. Canonicalize with
  `TMP="$(cd "$TMP" && pwd -P)"` before exporting any state/sandbox/progress
  path. Raising timeouts only hides this.
- Pushing prose commits to a PR whose exact head already passed
  qualification/review makes both stale and restarts an hour-long run —
  merge the code first, ship prose separately.
- `gh pr merge --squash --admin --delete-branch` is rejected outright when a
  merge queue is enabled — re-run without `--delete-branch`.
- `gh pr merge` from a linked git worktree can print `'main' is already used
  by worktree` AFTER the merge has already succeeded — that is local branch
  cleanup failing, not a failed merge. Confirm with
  `gh pr view <n> --json state`.

# 5. Root causes and key findings

## This session's main finding: the required-check gap that let prose regressions hide for a day

`tests/test-context-audit.ps1` (PowerShell) is the only place that checked
phrase parity between `templates/system/CLAUDE-global.md` and
`templates/system/AGENTS-global-codex.md`. PowerShell suites only run in
`windows-offline` and `windows-reviewer-safety` — neither is a required
check on `main` (confirmed by reading the live rulesets: only
`linux-offline` is required). Querying
`gh api "repos/popcre/ai-devops/actions/workflows/verify.yml/runs?branch=main&status=completed"`
showed `main`'s `verify` workflow had been failing or cancelling on
essentially every completed run for roughly 24 hours after commit
`5e5bd088` landed (2026-09-02T13:05:26-04:00) — the one apparent success in
that window (run `33640539778`) tested an older commit that predates
`5e5bd088`, not a later one, ruling out a false-positive read. Nobody was
specifically watching the non-required Windows lanes, so the regression sat
invisible until a qualification run happened to hit it.

**Fix:** `tests/test-client-globals-required-phrases.sh` (merged, PR #242,
`e1c9f0d6`) duplicates the same 8-phrase check against the real files, in
bash, auto-discovered into the required `linux-offline` lane. It is
deliberately narrow — it does not replace the full PowerShell audit, which
still covers safety-category deletion, budget/handoff reporting, cross-client
overlap detection, and Codex trigger-eval; those remain Windows-lane-only.

## EDGE-ALIEN's SentinelOne finding (preserved verbatim from the retired predecessor handoff — still the operative diagnosis, nothing has superseded it)

**EDGE-ALIEN is the only one of the three Windows machines running
SentinelOne EDR.** EDGE-DEV and EDGE-RUNN-ENVY run Windows Defender only.
Per-process CPU attribution, measured on EDGE-ALIEN across 200
`cmd /c exit` spawns plus 40 `git --version` calls, 11.33 seconds of wall
clock:

```
SentinelAgent   12.55 CPU-seconds
powershell       1.62
svchost          1.25
System           1.05
csrss            0.89
conhost          0.31
```

`SentinelAgent` consumed more CPU than the entire workload's wall-clock
duration, and 7.7x more than the shell actually doing the work.
Independently, it had accumulated 4,221 CPU-seconds over 4.2 hours of
mostly-idle uptime. The observed slowdown is a flat 3.38x across 14 suites
ranging from 2 seconds to 17 minutes — a flat ratio across that range rules
out a single slow test or a hang, and points to a per-operation tax exactly
like an EDR hook. Secondary cause: the hardware itself (2015 4-core i7-6700
vs ENVY's 2020 8-core i7-10700) is worth roughly 1.3–1.8x on its own — real,
but nowhere near 3.4x. **The 90-minute qualification ceiling is correct and
must not be raised** — two runs died at it with `ok` assertions landing
seconds before cancellation, i.e. taxed, not hung.

## Other preserved findings

- A `runs-on` heartbeat cannot detect a dead runner pool, because the
  heartbeat job would queue on the same dead pool. Any pool-health check
  must run from `ubuntu-24.04` against the runner API — this is the design
  point behind issue #222 (section 6 step 4).
- The live rulesets require `linux-offline` ONLY, and both Windows jobs are
  skipped on `merge_group` — so a fully dead Windows pool does not freeze
  merging, it silently removes Windows coverage, with no red signal
  anywhere. Now less urgent with a two-host pool, but the underlying gap
  (#222) is still real and still unaddressed.
- A GitHub 404 from `branches/main/protection` does NOT mean unprotected —
  rulesets are invisible at that endpoint.

# 6. Exact next steps

**Step 1 — put section 0 to Albert in one message, then act on the answers.**
Specifically: is it OK to reboot `edge-dev-win` and `EDGE-RUNN-ENVY` (one at a
time) to prove failover, and has IT replied on the EDGE-ALIEN SentinelOne
exclusions? *You'll know it worked when* you have a yes/no on both.

**Step 2 — failover/reboot proof (only after Albert's yes on item 1).**
a. Re-confirm both runners report `busy=false`:
   `gh api repos/popcre/ai-devops/actions/runners --jq '.runners[]|select(.name=="edge-dev-win" or .name=="EDGE-RUNN-ENVY")|{name,status,busy}'`
b. Reboot `edge-dev-win` only (SSH or however you reach it — see section 8).
c. Confirm it comes back `online` on its own within a few minutes with no
   one signed in:
   `gh api repos/popcre/ai-devops/actions/runners --jq '.runners[]|select(.name=="edge-dev-win")'`
   and confirm the Windows service is `Running`/`StartMode Auto` via
   `Get-CimInstance Win32_Service` (needs remote access to the host).
d. While `edge-dev-win` is down, dispatch a job that targets the qualified
   pool and confirm it lands on `EDGE-RUNN-ENVY` and completes — proves the
   pool survives one host being offline.
e. Repeat b–d for `EDGE-RUNN-ENVY`, with `edge-dev-win` as the survivor.
*You'll know it worked when* both hosts have independently proven
auto-restart and the other host has independently proven it can carry all
CI alone for at least one full job.

**Step 3 — third host (EDGE-ALIEN), only if Albert confirms IT granted
exclusions with child-process inheritance.** Re-measure per the recipe below,
and only proceed to qualify if the EDR tax has genuinely dropped.
a. Confirm `EDGE-ALIEN` reports `busy=false` first — it showed `busy=true`
   at last check for an unexplained reason (see section 9); resolve that
   before measuring anything on it.
b. Re-run the per-process attribution probe (write a `.ps1`, `scp` it, run
   via `powershell -NoProfile -ExecutionPolicy Bypass -File`): snapshot every
   process's `.CPU` into a hashtable, run 200 `cmd /c exit` plus 40
   `git --version`, snapshot again, print per-process deltas above 0.2s
   sorted descending alongside wall-clock seconds.
c. If `SentinelAgent`'s delta has dropped to a small fraction of wall clock,
   change its label from `ai-devops-windows-paused` to `ai-devops-windows`
   and dispatch `qualify Windows runner`.
   *You'll know it worked when* the run completes inside 90 minutes with
   success across security, dependencies, the full matrix, and cleanup.
d. On green, admit it:
   `gh api --method POST repos/popcre/ai-devops/actions/runners/<id>/labels -f "labels[]=ai-devops-windows-qualified"`
   *You'll know it worked when* the runner shows exactly
   `self-hosted, Windows, X64, ai-devops-windows, ai-devops-windows-qualified`
   (drop `-paused`).
e. If exclusions were refused, or granted without inheritance: report the
   re-measured number to Albert and record EDGE-ALIEN as not viable on issue
   #209; ask him which machine to use for a third host instead.

**Step 4 — build the #222 watchdog** (independent of the above, can be done
any time). A scheduled workflow on `ubuntu-24.04` that fails when this
returns `0`:
`gh api repos/popcre/ai-devops/actions/runners --jq '[.runners[]|select(.status=="online" and (.labels|map(.name)|index("ai-devops-windows-qualified")))]|length'`
Hourly is ample. *You'll know it worked when* stopping the runner service on
one qualified host does not turn the watchdog red (two hosts online still
satisfies `length >= 1`) but stopping BOTH does. Do not implement this as a
`runs-on` heartbeat — see section 5.

**Step 5 — capacity and cleanup proof per host**, once failover is done:
record capacity as one concurrent job per online physical host; prove each
qualified host tolerates being taken offline deliberately while jobs
complete on the other.

**Step 6 — at #209 closeout,** re-read every downstream phase from B3
through the final #166 cutover in `plan_repo-throughput-restructure.md` and
update anything #209 changed (the pool is now two hosts, not one or three —
adjust any phase that assumed a specific count). Then retire this handoff
file under the successor rule, and separately raise the two still-unresolved
housekeeping items in section 0 (items 4 and 5) if nobody has acted on them
by then. *You'll know it worked when* the plan's STATUS table has terminal
#209 evidence and every later phase is executable without chat context.

# 7. Constraints and gotchas in force

- **Never start a local test sweep while any GitHub run is active** — a
  local run on a self-hosted host cancels the live CI job on it (reports as
  `cancelled`, not failed). Check first:
  `gh api repos/popcre/ai-devops/actions/runs --jq '.workflow_runs[]|select(.status!="completed")|"\(.id) \(.head_branch) \(.status)"'`.
- **Check the merge queue before merging** — a merge restarts what is
  running.
- **`runs-on` label lists are ANDed.** Never add `edge-dev` alongside
  `ai-devops-windows-qualified` — that produces a job no machine can run,
  not a fallback.
- **Do not raise timeouts, delete assertions, bypass ACL/security checks,
  add an early `edge-dev` label, or install multiple runner services on one
  machine** as a repair for anything.
- **The repository is CRLF in the working tree.** Exact multi-line string
  replacement (Python, sed) must account for `\r\n`, not bare `\n`.
- **Docs-only commits merge immediately without waiting on checks** — but
  check the changed-file list first; if even one file is code/test/
  script/workflow/config, normal required-check gating applies. (This
  session's PR #242 added a new `.sh` test file, so it correctly went
  through the normal required-check gate, not the docs-only shortcut, even
  though its purpose was about documentation regressions.)
- **You merge your own PR** — never hand one back to Albert for review or
  merge, except DesignFlow (not this repo) or a PR he's explicitly said he
  wants to review first.
- Before the first commit, `git var GIT_COMMITTER_IDENT` must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- **This session ran in a git worktree** at
  `C:\repos\ai-devops\.claude\worktrees\issue-209-runner-pool-50fe5f`. The
  stash stack is shared with every other worktree — never use bare
  `git stash` / `git stash pop`.
- **A worktree can carry a stale local `main` branch from session start** —
  branch explicitly from `origin/main` by name rather than trusting a bare
  `git checkout main` to mean what you think (see section 4's stale-checkout
  dead end).
- **Never edit another session's `HANDOFF.d/` file**, and never rewrite the
  root `HANDOFF.md` (it is a static pointer).
- The repository is public. Never commit runner tokens, device/product IDs,
  private LAN details, Tailscale addresses, raw transcripts, or secrets.
- Fork approval is `all_external_contributors`. Preserve that boundary.
- Plan order remains #161, #162, #163, #210, #164, #167, #169, #168, then
  #166 last. #209 must not absorb those.
- **Nothing was changed on EDGE-ALIEN this session.** It was left in its
  paused state. Keep it that way until Albert rules on section 0 item 2.
- Attribution for commits/PRs in this session: `Claude Sonnet 5
  <noreply@anthropic.com>` co-author trailer, PR footer
  "🤖 Generated with [Claude Code]" — confirm current model/attribution at
  the start of any new session rather than assuming this carries forward.

# 8. Access and environment

- **GitHub CLI** is authenticated for `popcre/ai-devops`; issues, PRs, runs,
  runners and rulesets were all queried and modified through it this
  session. Re-check `gh auth status` in a fresh session.
- **Runner hosts are reachable by SSH over Tailscale only** — neither
  answers on the LAN by name or ping. Exact addresses are private topology
  and must not be written into this public repository; they are recorded in
  the private machine atlas (`popcre/ai-devops/templates/system/machine-atlas.md`
  is the pointer — the actual addresses live in machine-local memory, not in
  the repo). See the `$`-eating SSH trap in section 4.
- **This session ran on EDGE-DEV**, which hosts the `edge-dev-win` runner
  (now online and qualified). Working directory is the worktree named in
  section 7.
- Runner service on `edge-dev-win`: registered under
  `NT AUTHORITY\NETWORK SERVICE`, automatic start, confirmed via
  `Get-CimInstance Win32_Service`.
- **No secret is required** for any step in section 6. If a runner
  registration token is ever needed, generate it through authenticated
  GitHub at use time and never paste or commit it. Other secrets live in the
  1Password vault `vibe_coding`; no values belong in this document or any
  other.

# 9. Open questions and risks

- **2026-09-03: EDGE-ALIEN shows `busy=true` with no session-visible cause.**
  Checked live at the time this handoff was written
  (`gh api repos/popcre/ai-devops/actions/runners`). It carries only the
  `ai-devops-windows-paused` label, which is not in any `runs-on` list in
  `verify.yml`, so it should not be receiving ordinary CI — but it could
  still pick up a manually-dispatched `qualify` workflow run from another
  session, since that workflow targets the `ai-devops-windows` candidate
  label and EDGE-ALIEN no longer carries that label either (it carries
  `-paused` instead) — so the cause is genuinely unclear. **Before touching
  EDGE-ALIEN for anything (including the measurement in step 3), check what
  job is actually running on it**
  (`gh api repos/popcre/ai-devops/actions/runs --jq '.workflow_runs[]|select(.status!="completed")'`)
  rather than assuming it's idle-but-misreported.
- **2026-09-03: the failover/reboot proof is the only remaining engineering
  gate before #209 can move toward closeout**, and it requires physical
  access risk (a hung reboot needs a hand on the keyboard) that no AI
  session can absorb — hence section 0 item 1 rather than proceeding
  unilaterally.
- **2026-09-02 (preserved): EDGE-ALIEN's viability is entirely outside this
  repository's control.** If IT refuses the exclusions or refuses
  child-process inheritance, the machine is probably not usable and the
  third-host effort must move to whatever machine Albert names.
- **2026-09-02 (preserved): even with exclusions, EDGE-ALIEN will remain the
  slower host** — its 2015 4-core CPU is worth roughly 1.3–1.8x against
  ENVY regardless. Plan capacity accordingly if it is ever admitted.
- **2026-09-03: two handoff files reference issues that are now confirmed
  CLOSED** (section 0 item 4) and **two more still lack a contract block**
  (section 0 item 5) — both flagged in the retired predecessor handoff too
  and still unresolved a session later. If a third handoff in a row flags
  the same items, that is itself worth a note to Albert that housekeeping
  recommendations are not getting picked up.
- Every risk above either has an objective next step in section 6 or appears
  in section 0 as an Albert decision. Nothing is filed only here.

## Predecessor handoff retired

`HANDOFF.d/2026-09-02T1756Z-edge-dev-claude-issue-209-edge-alien-edr.md` is
deleted by this commit under the successor rule: its committed work
(`ff94beba`, `c4304ada`, `7e9210d1`, `36bd7a5f`) is verified on `origin/main`;
its Step A and Step B (edge-dev re-registration and qualification) are done,
verified live via the runner API; its Step C (failover proof), the #222
watchdog, the third-host contingency, and every section-0 decision it
carried (SentinelOne exclusions, the two stale handoff files, the
contract-less files, PR #213) are all carried forward into this file's
sections 0, 5, and 6, with nothing dropped. Its full dead-ends list (section
4) and its full EDR root-cause writeup (section 5) are preserved verbatim
above so no diagnostic work is lost.

## Handoff self-audit

1. **Yes.** Section 1 defines the product, the three machines, and current
   label state for someone with zero context, verified live rather than
   assumed; section 3 states exactly what is merged and admitted, with
   commit SHAs and a live runner-API check; sections 6 and 8 give executable
   next actions and the exact access route.
2. **Yes.** Section 4 preserves both this session's dead ends (six new ones,
   including a mistake I personally made and caught) and every dead end
   inherited from the now-deleted predecessor file, so nothing from that
   file is lost. Section 5 preserves the full EDR reasoning and adds this
   session's CI-gate-gap finding with the evidence that grounds it (the
   24-hour red-run query).
3. **Yes.** Sections 2 and 5 cover goal, intended outcome, and findings;
   section 3 covers current state with commit/push/admission status
   explicit and independently verified per item, not assumed; section 4
   covers failures; sections 6 and 7 cover exact gated next actions and
   constraints; section 9 covers dated risks including a live anomaly
   (EDGE-ALIEN's unexplained busy state) discovered while writing this
   handoff; section 8 covers access with secrets referenced by vault name
   only. Every SHA, run ID, issue number, label, and path a newcomer would
   not know is defined at first use.
4. **Yes, checked the hard way.** Walked sections 1–9 line by line for any
   sentence needing Albert's judgement. Found two live items (the reboot
   authorization — new this session — and the still-unanswered SentinelOne
   question, carried forward) plus three carried-forward housekeeping items
   (two stale-issue handoff files, two contract-less handoff files, PR
   #213's staleness) — all five appear in section 0 with a recommendation
   and a statement of what each blocks. No sub-agents were used this
   session, so there is no part (b).
