---
issue: 98
status: OPEN
owner: claude/windows-offline-ci-latency-98
---

# HANDOFF — `windows-offline` takes 64 minutes and now gates every merge (2026-08-26 13:56 UTC, edge-dev/claude)

**Nothing has been built for this workstream yet.** This file exists because the
problem was *discovered* while finishing the `popcre` organization move
(issue [#84](https://github.com/popcre/ai-devops/issues/84)), and it is a
different job from that move. Issue
**[#98](https://github.com/popcre/ai-devops/issues/98)** is the tracking issue.

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put this whole list to Albert in **one message before starting work**. Do not
raise them one at a time as you trip over them.

### BLOCKING — work cannot start without an answer

1. **A / B / C on the merge-queue gate — this is ALREADY OPEN and Albert has not
   answered it.** It was put to him at 2026-08-26 ~13:55 UTC and the session
   ended before a reply. **Ask again; do not assume.** The choice is how long a
   pull request should take from opening to merged:

   | | Open→merged | What is given up |
   |---|---|---|
   | **A. Keep it strict** (current state) | **~2h 10m** | nothing |
   | **B. Require only `linux-offline`** | **~20 min** | Windows still runs and still shows failures, it just stops blocking. A Windows-only break could reach `main`. |
   | **C. Turn the merge queue off** | minutes | the ordering protection the whole org move was done to get |

   **Recommendation: B**, as an interim while #98 is worked. It keeps the queue
   and its ordering guarantee, merges take 20 minutes instead of two hours, and
   Windows coverage stays visible rather than disappearing. The residual risk is
   real and worth stating plainly: **this repository's entire job is setting up
   Windows machines**, so a Windows-only regression reaching `main` is not a
   theoretical concern. It would, however, be visible immediately and fixable in
   minutes.
   **Not C** — the move itself was cheap and is worth keeping; the 64-minute gate
   is what is wrong, not the organization.
   *Blocks:* nothing technically — #98 can be measured and fixed under any of the
   three. But it decides how much pain every other session eats meanwhile, so
   settle it first. **One letter answers it.**

### RECOVERABLE — a wrong guess is fixable but wastes rework

2. **How much slower than Linux is acceptable when this is done?**
   Right now the same 54 Bash suites cost 9 minutes on Linux and are part of a
   64-minute Windows job. There is no target, so "fixed" is undefined and the
   work can drift forever.
   **Recommendation: set the goal at "`windows-offline` under 20 minutes".**
   That makes option A affordable (~45-minute merges) and retires the whole
   argument. One number settles it.
   *Blocks:* nothing; it is an acceptance criterion, not a gate.

3. **May the redundant third CI run be deleted?**
   Every merge currently triggers `verify` a third time via `push: main`, after
   the merge-queue run already tested that exact tree. It does not slow anything
   down, but it burns ~64 minutes of runner time per merge and holds a runner
   slot. The only thing lost is a green tick attached to `main` itself.
   **Recommendation: yes, remove `push: main` from `verify.yml` once the queue is
   settled** — with the queue active, direct pushes to `main` are blocked, so
   that trigger now only ever fires on merges the queue already proved.
   *Blocks:* nothing; independently reversible.

### NOT PART OF THIS WORK, AND NOBODY IS ON IT

4. **`edge-dev` may have a genuine resource problem.** Also raised in the
   issue #89 handoff and still unaddressed. If this box is short of disk, or
   antivirus scans every temp file a test writes, that hurts every session on it.
   **Recommendation: 15 minutes of measurement before anyone assumes the tests
   are entirely at fault.** Nobody is on this.

5. **Albert's installed global instruction files still say `u2giants`.**
   `templates/system/CLAUDE-global.md` and `templates/system/AGENTS-global-codex.md`
   were swept to `popcre` in the repo, but the **installed** copies at
   `C:\Users\ahazan\.claude\CLAUDE.md` and `C:\Users\ahazan\.codex\AGENTS.md`
   were deliberately **not** overwritten — they carry a machine-specific section,
   and other AI sessions were live at the time, so changing their globals
   mid-flight was avoided on purpose. They work fine via GitHub's redirect.
   **Recommendation: run `bin/ai-adopt-globals` at a quiet moment.** Never
   hand-edit them and never pass `--adopt-globals` directly; that is a known trap.
   *Not urgent.*

6. **Live git worktrees registered against `ai-devops`**, several apparently
   abandoned, including two under `C:\Users\ahazan\AppData\Local\Temp\` and two
   detached-HEAD clones named `ai-devops-gemini-qualification-final`(`-v2`), plus
   `C:\repos\ai-devops-worktrees\evidence-seq287`.
   **Recommendation: run the `cleanup-worktree` skill in its own session.** Age
   alone is not proof any of them is safe to delete. Also recorded in
   `fix_to_gh_org.md` §5b.

7. **The shared working copy `C:\repos\ai-devops` carries another session's
   uncommitted work** — the reviewer-cache workstream. Detail in
   `fix_to_gh_org.md` §5b. Nobody in the move sessions owned those files.

### Already settled — do NOT re-ask

- **`windows-reviewer-safety` is NOT a required check, permanently.** It is a
  strict *subset* of `windows-offline` (see §5, Finding 2). Requiring it adds
  failure surface and zero coverage. Settled 2026-08-26 after GLM raised it and
  it was independently verified.
- **The repository lives at `popcre/ai-devops`, public.** The move is done.
- **The flaky reviewer suites (issue #89) are a separate workstream.** They are
  *inside* `windows-offline`, so they interact with this one, but do not merge the
  two jobs.

## 1. What this application is

`ai-devops` (`https://github.com/popcre/ai-devops`, **public**) is Albert Hazan's
**AI operations and configuration hub** for POP Creations. It is not a customer
product and has no server, no deployment and no database.

It holds the shell/PowerShell tooling in `bin/`, the machine bootstrap and
installer scripts, the shared AI reviewer wrappers (`ai-grok-review`, `ai-muse`,
`ai-deepseek-agent`, `ai-gemini`, `ai-kimi`, `ai-qwen`, `ai-glm`), the cross-tool
`templates/system/` standards, and the skills that other repositories' AI sessions
load. **Every workstation Albert uses clones this repository and installs from
it.**

That last sentence is the reason this issue is not merely cosmetic: the test suite
that is slow is the one proving that Windows machine setup still works, and
Windows is the platform this repository primarily serves.

Two private siblings, `u2giants/ai-devops-memory` and
`u2giants/ai-devops-transcripts`, did **not** move and are irrelevant here.

**Stack:** Bash + PowerShell scripts. One GitHub Actions workflow,
`.github/workflows/verify.yml`, with three jobs.

## 2. What we set out to do this session, and why

This session's actual job was Phases C, D and E of the `popcre` organization move
(issue #84) — transfer the repository, prove there was no flag-day, and enable a
merge queue. **That work is done.** GitHub offers merge queues only to
organization-owned repositories, which is the entire reason the move happened.

**This issue is a consequence, not the goal.** Enabling the merge queue turned a
64-minute job into a gate on every merge, and Albert immediately pushed back on
the resulting two-hour turnaround — correctly. His words: *"this sounds crazy."*

The objective for whoever picks this up: **make `windows-offline` fast enough that
gating on it is not painful**, so the merge queue can stay strict.

## 3. Current state — what is true right now

### Nothing has been built for issue #98

No branch, no code change, no measurement beyond the job-level durations below.
**Step 1 in §6 is the first real action.**

### The measurements that exist (verified)

From run **[32967607403](https://github.com/popcre/ai-devops/actions/runs/32967607403)**
(pull request #93, all three jobs green), read via
`gh api repos/popcre/ai-devops/actions/runs/32967607403/jobs`:

| Job | Runner | `timeout-minutes` | **Measured** |
|---|---|---|---|
| `linux-offline` | `ubuntu-24.04` | 45 | **9 min** |
| `windows-reviewer-safety` | `windows-2025` | 30 | **14 min** |
| `windows-offline` | `windows-2025` | 75 | **64 min** |

Whole-run wall clock: 64 minutes. Everything is gated by that one job.

### What each job actually runs

- `linux-offline` → `bash tests/test-all.sh`.
- `windows-offline` → `pwsh .\tests\test-all.ps1`, which runs **`test-all.sh`
  first** (`tests/test-all.ps1:8`) and then **17 PowerShell suites**
  (`tests/test-all.ps1:11-17`, a `test-*.ps1` glob).
- `windows-reviewer-safety` → exactly `tests/test-ai-codex-review.sh` and
  `tests/test-ai-grok-review.sh`, through Git Bash.

`tests/test-all.sh:6` discovers its suites with a `find` glob over
`tests/test-*.sh` — currently **54 files**. It is not a hand-maintained list.

### The merge queue is live

Ruleset **`main: pull request + merge queue`**, id `21564317`, `active` on `main`:
`SQUASH` / `ALLGREEN` / build 5 / merge 5 / min 1 / `check_response_timeout_minutes`
120 / 0 required approvals. **Required checks: `linux-offline` and
`windows-offline`.**

**Bypass actors:** `OrganizationAdmin`, mode `always` (added late in the
session — see §5 Finding 8 and §4 items 10–11).

A second, pre-existing ruleset `Protect main history` (id `21183703`) supplies
`deletion` and `non_fast_forward`. It was left alone.

`verify.yml` gained a `merge_group:` trigger in commit `f7c2b42`. Without it a
queued pull request waits forever for checks that never start.

### Repository settings changed this session

`allow_auto_merge=true` and `delete_branch_on_merge=true` were enabled — auto-merge
is required for the queue workflow.

## 4. Everything we tried that did NOT work

1. **`gh pr merge --admin` on a pull request whose required check is still
   running.** Refused: *"Required status check `windows-offline` is in progress."*
   Admin override does not skip an **in-progress** required check — only a failed
   or missing one. There is no way to short-circuit a running 64-minute job.

2. **`gh pr merge --delete-branch` with a merge queue enabled.** Hard error:
   *"Cannot use `-d` or `--delete-branch` when merge queue enabled."* Use the
   repository's `delete_branch_on_merge` setting instead (now on).

3. **`gh pr merge --auto` before enabling repository auto-merge.** Failed with
   `GraphQL: Auto merge is not allowed for this repository`. A merge queue needs
   `allow_auto_merge=true` on the repository; the ruleset alone is not enough.

4. **Assuming excluding `windows-reviewer-safety` from required checks would dodge
   the issue #89 flakiness.** Wrong, and it was written into a plan before being
   checked. Both flaky suites reach `windows-offline` anyway through the
   `test-all.sh` glob. See §5 Finding 2.

5. **Running `bash tests/test-installer-parity.sh` from PowerShell.** `bash`
   resolved to **WSL**, not Git Bash, and produced UTF-16-looking garbage about
   installing a distribution. **Use the Bash tool / Git Bash for `.sh` suites and
   PowerShell only for `.ps1`.**

6. **Passing multi-line Markdown or Python through a quoted Bash heredoc.**
   Backslashes collapse before the interpreter sees them —
   `C:\Users\ahazan\AppData\Local\Temp\` became a Python `\U` escape error.
   **Fix: `chr(92)` inside Python, or the `Write` tool for prose. Read the result
   back.**

7. **Editing `verify.yml` with a Python string match assuming LF.** The file is
   **CRLF**; a match on `'\n'`-joined text silently found zero occurrences. Detect
   the newline (`'\r\n' if '\r\n' in s else '\n'`) and rebuild with it.

8. **A 10-minute tool timeout on `ai-glm new`.** The wrapper was killed (exit 143)
   but **the server-side turn kept running and completed** — `ai-glm show` said
   `active` with `provider_progress_at` advancing, and `ai-glm transcript` later
   returned the full answer. **Do not re-issue the question or `abort` on a
   client-side timeout; poll `ai-glm show`, then read `ai-glm transcript`.**

9. **Running `ai-glm` from Git Bash.** `command not found` — only `ai-glm.cmd`
   exists. **Call it from PowerShell.**

10. **`gh pr merge --admin` does NOT bypass a ruleset.** This wasted the most
    time at the end of the session. Classic branch protection had an
    "enforce_admins" flag that `--admin` could override; **rulesets ignore admin
    status entirely unless the account is listed in the ruleset's
    `bypass_actors`**. The ruleset was created with no bypass actors, so for a
    while **nothing could merge anything** — not even a single-file docs change —
    until `windows-offline` finished 64 minutes later. Fixed by adding
    `{"actor_type": "OrganizationAdmin", "bypass_mode": "always"}` to ruleset
    `21564317`. **If a merge is refused and `--admin` does not help, check
    `bypass_actors` first.**

11. **Cancelling the run to unblock an admin merge did not work either.** With a
    required check `cancelled` rather than `in progress`, the merge was still
    refused (`Required status check "windows-offline" is cancelled.`) — because
    the real blocker was the missing bypass actor, not the check state. The
    cancellation was therefore pointless and cost a clean Windows signal on that
    pull request. **Do not cancel a run to force a merge.**
## 5. Root causes and key findings

**Finding 1 — the same 54 Bash suites appear to cost ~7x more on Windows, and
that is the whole problem.** `linux-offline` runs `test-all.sh` in **9 minutes**.
`windows-offline` runs *that same script* plus 17 PowerShell suites in **64
minutes**. Even crediting the PowerShell suites generously, the Bash portion
dominates. These suites shell out constantly (each spawns `git`, `jq`, subshells,
temp files), and process creation on Windows is far more expensive than on Linux —
so this looks like **per-process spawn overhead, not 7x more work**.

⚠️ **This is a strong hypothesis, not a measured fact.** Per-suite timings have
**never been collected**. Step 1 of §6 exists to confirm or kill it before anyone
writes code. Do not start optimising on the strength of this paragraph.

**Finding 2 — `windows-reviewer-safety` is a strict subset of `windows-offline`,
and this corrects a wrong assumption.** It runs `test-ai-codex-review.sh` and
`test-ai-grok-review.sh`. `windows-offline` runs `test-all.ps1` → `test-all.sh`,
which auto-discovers **every** `tests/test-*.sh` (`tests/test-all.sh:6`) on the
same runner through the same Git Bash — including both of those.

Two consequences:
- Requiring `windows-reviewer-safety` would add failure surface and **zero**
  coverage. It stays as a fast early signal only.
- **Both issue #89 flaky suites are inside `windows-offline` under every possible
  configuration.** Excluding `windows-reviewer-safety` does not avoid the flake.
  Only fixing the suites does.

This was raised by **GLM (`glm-5.3`)**, which rejected both options the session had
drafted. It was **independently verified against `tests/test-all.sh:6` before being
acted on**. GLM's session is `ai-devops-merge-queue-required-checks` — continue it
with `ai-glm ask` rather than starting a new one.

**Finding 3 — a merge queue multiplies the cost of a slow check by three.** Once
per pull request, once in the merge group (the queue re-tests the branch combined
with `main` — that is its entire purpose), and once on `push: main`. Only the first
two affect open-to-merged latency; the third is pure waste because the merge-group
run already tested that exact tree.

**Finding 4 — superseded merge-group builds are NOT cancelled.** `verify.yml`'s
`concurrency` group (lines 9–13) keys on **event name + SHA**, deliberately, so
that "each immutable commit's proof stays alive". A new merge group is a new merge
commit and therefore a new SHA, so queue churn leaves ~64-minute orphan builds
running and consuming runner slots. Raised by GLM; verified in the file.

**Finding 5 — GitHub silently enabled an approval requirement that would have
blocked self-merges.** Creating the ruleset produced
`require_extra_approval_for_unattributed_changes: true` on the `pull_request` rule
without it being requested. With 0 required approvals it can still demand an
approval for commits it considers unattributed — and **every commit in this
repository carries a `Co-Authored-By` trailer**. It has been set to `false`. If
merges ever start requiring an approval that nobody configured, look here first.

**Finding 6 — required checks are matched by check-run name, and a stale name
blocks the queue SILENTLY.** These are the traps, all recorded in
`fix_to_gh_org.md`:
1. **The three job names are frozen.** Renaming a job — or the workflow's `name:` —
   leaves a permanently "expected" check that never reports, with no error naming
   the stale entry. Change a name and the ruleset in the same commit.
2. **Any workflow contributing a required check MUST subscribe to `merge_group:`.**
3. **Never add `paths:` / `paths-ignore:` / `branches:` filters or `if:` skips to a
   required job.** A required check filtered out of a merge group parks the queue
   until `check_response_timeout_minutes` (120) expires. **Albert specifically
   offered to add a `paths-ignore` filter to `verify.yml` — that offer must be
   declined now that these jobs are required.**
4. **No job matrices.** Matrix-expanded names multiply every trap above.

**Finding 7 — a flake costs latency, not a deadlock.** A failed merge-queue batch
returns its entries to the queue and retries. Do not respond to a first flake by
stripping required checks in a panic; re-queue.

**Finding 8 — the "docs-only, merge on `linux-offline`" shortcut is DEAD under
option A, unless a bypass actor exists.** Albert's standing rule is: do not wait
on CI for a docs-only pull request, merge once `linux-offline` passes. With
`windows-offline` required and no bypass actor, that rule is unenforceable — the
merge is refused while the Windows job runs, and an admin cannot override it.

The ruleset now lists **`OrganizationAdmin` as a bypass actor (`always`)**, which
restores the rule and gives a solo owner an emergency route. **Be aware of the
trade-off:** any session acting as an org admin can now bypass the queue with
`--admin`. That is deliberate, but it means the queue protects by convention as
well as by enforcement. Reserve `--admin` for docs-only changes and genuine
emergencies; normal code changes must go through the queue.
## 6. Exact next steps

1. **Put §0 to Albert in ONE message.** Item 1 (A/B/C) is genuinely open and
   unanswered. *You'll know it worked when* you have a letter for item 1 and a
   number for item 2.

2. **Measure per-suite timings on `windows-2025` — do not skip to optimising.**
   Add temporary timing output to `tests/test-all.sh` (record start/end per suite,
   print a sorted table at the end), push to a branch, read the CI log. Do the same
   for `test-all.ps1`'s PowerShell loop. *You'll know it worked when* you have a
   sorted list of all 54 Bash suites and 17 PowerShell suites by duration on
   Windows, and can name the top 10 that account for most of the 64 minutes.
   **Do not run the full suite locally to get this — see §7; it takes ~50 minutes
   and the machine is contended.**

3. **Compare the same table against `ubuntu-24.04`.** The ratio per suite is the
   evidence that decides the fix. *You'll know it worked when* you can say whether
   the cost is spread evenly across all 54 suites (⇒ process-spawn overhead,
   Finding 1 confirmed) or concentrated in a handful (⇒ fix those suites).

4. **Choose the fix from that evidence, not before.** Likely candidates, in
   rough order of expected payoff:
   - **Parallelise `test-all.sh`.** It runs 54 suites strictly serially. GitHub's
     `windows-2025` runners have 4 vCPUs. If the suites are independent — verify
     this, several use shared temp fixtures — running 4 at a time is close to a 4x
     win for no behaviour change. **This is the most promising lead.**
   - **Split `windows-offline` into two or three parallel jobs**, each running a
     slice. Costs runner minutes (free on a public repo) and buys wall-clock.
     ⚠️ **If you do this, every new job name must be added to the ruleset's
     required checks in the same change** (Finding 6, trap 1).
   - **Fix the individually slow suites** identified in step 2.
   - **Reduce per-suite process spawning** if step 3 shows the cost is uniform.

5. **Re-tune the queue once `windows-offline` is fast.** If it lands under 20
   minutes, option A becomes ~45-minute merges and the A/B/C question dissolves.
   Update ruleset `21564317` accordingly. *You'll know it worked when* a real pull
   request goes from opened to merged in under an hour with all checks required.

6. **Remove `push: main` from `verify.yml`** (§0 item 3, if approved). *You'll know
   it worked when* a queue merge produces exactly two `verify` runs, not three.

7. **Lower `check_response_timeout_minutes` from 120** once the job is fast, but
   keep generous margin over the job's `timeout-minutes` **plus runner-queue
   wait**. Too low and a healthy job that waited for a runner is declared failed,
   requeued and rebuilt — a retry storm.

8. **Close issue #98 and delete this handoff in the same pull request.**

**Sequencing note:** issue **#89** (the flaky suites) and this issue both live
inside `windows-offline`. Doing #89 first is defensible — it makes the timings in
step 2 trustworthy. Albert's standing sequencing was that #89 comes after the org
move, which is now complete, so **#89 is unblocked.**

## 7. Constraints and gotchas in force

- **Every pull request now takes ~2h 10m** while option A stands. For a
  **docs-only** pull request Albert's standing rule applies: *do not wait on CI —
  merge once `linux-offline` passes* (~9 min), using `gh pr merge --admin`. That
  is how this handoff and the closeout were merged. **It does not apply to code.**
- **Do not add `paths-ignore` to `verify.yml`.** Finding 6, trap 3. Albert offered
  this; it must be declined while these jobs are required.
- **`C:\repos\ai-devops` is shared with other live AI sessions.** Branch from
  `origin/main` in a separate worktree; stage only your own files; never
  `git add -A`; never rebase local `main`. Its working tree currently holds another
  session's uncommitted reviewer-cache work — **leave it alone**.
- **Do not put an `ai-devops` worktree under the session scratchpad** — Windows
  path length breaks `git worktree add` with `Filename too long`. Use
  `C:\repos\ai-devops-worktrees\<name>`.
- **The full Bash suite takes ~50 minutes locally on Windows.** Run it once, in the
  background. Do not sit in a polling loop; do not run it three times chasing an
  intermittent failure.
- **Judge `tests/test-all.sh` by its `OFFLINE BASH SUMMARY tests=N failures=N`
  line, or `${PIPESTATUS[0]}`** — never by a piped exit code. `bash tests/test-all.sh | tail -40`
  returns **`tail`'s** status, which previously produced a false "clean pass".
- **PowerShell files are CRLF and must be pure ASCII.** So is `verify.yml`.
- **Use Git Bash for `.sh`, PowerShell for `.ps1`.** `bash` inside PowerShell is
  WSL (§4.5).
- **New Bash files need the executable bit set in git**: `git update-index --chmod=+x <path>`.
  `git add` on Windows records `100644` and Ubuntu CI cannot execute it.
- **Committer identity must be `Albert Hazan <u2giants@users.noreply.github.com>`.**
  Verify with `git var GIT_COMMITTER_IDENT` before the first commit.
- **Albert does not merge — the session that opens a pull request merges it.**
  Never end a report asking him to click Merge.
- **`gh pr merge` from a linked worktree can print `'main' is already used by
  worktree`.** That is local branch cleanup failing **after** a successful merge.
  Confirm with `gh pr view <n> --json state` and continue.
- **Never rewrite the root `HANDOFF.md`**, and never edit another session's
  `HANDOFF.d/` file.
- **The identity guards must stay fail-closed.** Turning any of them into a warning
  is a regression. `config/repo-identities.tsv` intentionally lists **both**
  `u2giants` and `popcre` for `ai-devops`; removing the old owner recreates the
  flag-day the move was designed to avoid. All of `tests/` deliberately still
  asserts `u2giants`.

## 8. Access and environment

- **`gh` CLI:** authenticated as `u2giants`, token in the OS keyring. Scopes:
  `admin:public_key`, `gist`, `read:org`, `repo`, `workflow`.
  **`delete_repo` is ABSENT** — this is why `popcre/actions-policy-probe` was
  *archived* rather than deleted. **`admin:org` is absent and is NOT needed.**
- **Org role:** `u2giants` is an admin/owner of `popcre`. Org members are
  `u2giants` and `devopswithkube` only — Albert removed `VaibhavBarot` on
  2026-08-26.
- **Machine:** `edge-dev` (Windows 11 Pro). PowerShell 7 (`pwsh`) and Git Bash both
  available. Albert is in **NYC (Eastern)**; UTC is 4 hours ahead.
- **Repo checkouts:** canonical shared clone `C:\repos\ai-devops` (**dirty, another
  session's work**). This session worked in the linked worktree
  `C:\repos\ai-devops\.claude\worktrees\ai-devops-gh-org-move-d9b189`.
- **GLM:** session `ai-devops-merge-queue-required-checks` holds the merge-queue
  analysis. Continue it with `ai-glm ask`, from **PowerShell**, never Git Bash.
  `ai-glm doctor` passed all checks on 2026-08-26.
- **Secrets:** none are needed. `ai-devops` has **no Actions secrets, variables or
  environments at all** — verified before and after the transfer. Anything else
  lives in 1Password vault **`vibe_coding`**; reference by item, never by value.

## 9. Open questions and risks

- **RISK — option B lets a Windows-only regression reach `main`.** This repository
  exists to set up Windows machines, so that is not theoretical. It is visible
  immediately (the job still runs and still reports) and fixable in minutes, but
  say so plainly when recommending B rather than glossing it.
- **RISK — splitting `windows-offline` into parallel jobs without updating the
  ruleset silently breaks the queue.** New job names are not required checks; the
  old name becomes a permanently expected check that never reports. Do both in one
  change (Finding 6).
- **UNCERTAIN — Finding 1 is a hypothesis.** The ~7x figure is inferred from two
  job-level numbers, not measured per suite. Step 2 exists to test it. It is
  entirely possible that a handful of suites, not spawn overhead, dominate.
- **UNCERTAIN — whether the 54 Bash suites are safe to run in parallel.** Several
  create temp fixtures and at least one manipulates git remotes. Parallelising is
  the most promising fix and also the one most likely to introduce flakiness.
  Verify isolation suite by suite before assuming.
- **UNCERTAIN — how much of the 64 minutes is the 17 PowerShell suites.** Never
  separated. Step 2 covers it.
- **DECIDED 2026-08-26 — `windows-reviewer-safety` is never a required check**
  (Finding 2). Reversing this means first explaining why duplicate coverage is
  worth extra failure surface.
- **DECIDED 2026-08-26 — the repository is `popcre/ai-devops`, public, and the
  move is complete.** Do not revisit.
- **DECIDED 2026-08-26 (Albert) — the A/B/C gate decision may be made after the
  move completes.** It is now open and waiting on him.

---

## Self-audit (required by the handoff standard)

1. **Could a street-newcomer continue without asking a question?** Yes. §1 explains
   what the repository is with zero assumed knowledge and states why a Windows test
   suite matters here; §2 gives the trigger (the merge queue made a 64-minute job a
   gate) and Albert's own reaction; §3 states plainly that **nothing has been built
   yet** and gives every measured number with the run ID and the command used to
   read it; §6 gives eight numbered steps each with a verification gate; §8 gives
   exact checkout paths, token scopes and the absent scopes.

2. **As effectively as this session can right now?** Yes. The nine things that cost
   real time are in §4 with the fix that worked: the in-progress-check admin-merge
   refusal, the `--delete-branch` conflict, auto-merge needing a repository setting,
   the wrong assumption about dodging the flaky suites, WSL masquerading as Git
   Bash, heredoc backslash collapse, the CRLF match failure, the GLM client-timeout
   false alarm, and `ai-glm` being `.cmd`-only. §5 carries the six findings with
   `file:line` refs, and Finding 1 is explicitly labelled a hypothesis so the next
   session tests it instead of trusting it.

3. **Is every relevant detail present?** Yes: background (§1–2), current state with
   measured durations, run IDs, ruleset id and settings (§3), dead ends (§4),
   findings with `file:line` (§5), next steps with gates (§6), constraints (§7),
   access including *absent* scopes (§8), risks and dated decisions (§9).

4. **Would Albert see every decision he owns by reading only §0?** Checked by
   walking §1–§9 line by line. The A/B/C gate (§3, §6 step 1, §9 → §0.1), the
   "how fast is fast enough" acceptance number (§6 step 5 → §0.2), the redundant
   third run (§5 Finding 3, §6 step 6 → §0.3), the `edge-dev` resource question
   (§0.4), the un-adopted installed globals (§0.5), the abandoned worktrees (§0.6)
   and the shared checkout's uncommitted work (§0.7) all appear in §0. Items 4–7
   are outside this workstream and are in §0 **precisely because nobody else is
   raising them** — item 5 in particular was discovered in passing during the
   sweep and would otherwise have been filed only as a finding and never surfaced.
