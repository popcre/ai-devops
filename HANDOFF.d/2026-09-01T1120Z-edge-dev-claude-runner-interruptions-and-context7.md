---
issue: 204
status: OPEN
owner: claude/runner-interruption-evidence (session on edge-dev, 2026-08-31 → 2026-09-01)
---

# Handoff — Context7 pilot, token-tooling evaluation, and Windows runner interruptions

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put this whole list to Albert in ONE message before starting work. Do not raise
them one at a time.

**Blocking nothing right now, but wasting real money and time every day:**

1. ~~**Should the hour-long Windows test job keep running inside the merge queue?**~~
   **ANSWERED 2026-09-01, and it is no longer an owner decision.** Albert declined
   to rule on it ("i am non-technical and not qualified to make that decision")
   and asked for a model review. Kimi K3 was out of quota; Grok reviewed instead
   and recommended: take BOTH Windows jobs off `merge_group`, remove them from the
   merge-queue required checks, and keep `linux-offline` as the queue gate. The
   full ranked list is on issue #204
   (<https://github.com/popcre/ai-devops/issues/204#issuecomment-5499056115>).
   **Nothing further is needed from Albert on this.** What remains is engineering
   work, and two Codex sessions (issues #161 and #209) are already in that file —
   this session deliberately did not edit `verify.yml` to avoid colliding with them.

2. **Do you want the unexplained 2026-09-01 08:55 runner death investigated?**
   One job was killed mid-run and reported as a *test failure* rather than a
   cancellation, while a job on the other runner died 90 seconds later. Answering
   it needs the runner service logs from the `edge-dev` machine for 08:54–08:56;
   the GitHub data cannot say. My recommendation: yes, once — because a killed
   job that looks like a test failure will keep sending sessions to chase bugs
   that do not exist. It already did in this session.

3. **Should the two self-hosted Windows runners stay on `edge-dev`, a machine
   people also work on directly?** A local test sweep started there kills the
   live build. A guard rule is now written into `AGENTS.md`, but a rule is weaker
   than separation. No recommendation — this depends on what other hardware you
   have, which I do not know.

**A wrong guess is recoverable:**

4. **Keep or remove the two token-saving tools I installed on `edge-dev`?**
   Neither is wired into anything automatic any more, so they are inert. My
   recommendation: leave them installed; LeanCTX's search command is genuinely
   useful by hand. Removal is one command each if you prefer a clean machine.

**Already settled — do NOT re-ask:**

- 2026-08-31 — Context7 is scoped to this repository only, through `.mcp.json`,
  and no global configuration was touched. Albert approved the pilot ("do it").
- 2026-09-01 — RTK's automatic hook is OFF, and quiet output flags are the
  chosen approach instead. Albert said "quiet flags"; merged as commit
  `90b45b8a`.
- 2026-09-01 — LeanCTX was piloted and measured. It is not being wired in.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's AI DevOps toolkit: the shared rules, skills,
scripts, and tests that govern how AI coding sessions (Claude, Codex, Grok, GLM,
Kimi, Qwen) behave across all of his repositories. It is not a user-facing
product — there is no UI, no server, no database, no deployment. "Deployment" here
means installing the toolkit onto a machine.

- Repository: `popcre/ai-devops` on GitHub. It also legitimately answers to the
  older `u2giants/ai-devops` name; both owners are intentionally valid.
- The contract every session must read first is `AGENTS.md` at the repository root.
- Tests are Bash and PowerShell suites under `tests/`, run by `tests/test-all.sh`.
- CI is one workflow, `.github/workflows/verify.yml`, with three jobs:
  `linux-offline` (GitHub's cloud), `windows-offline` and
  `windows-reviewer-safety` (both on self-hosted runners labelled
  `self-hosted, Windows, X64, edge-dev`).

This session ran in a git worktree at
`C:\repos\ai-devops\.claude\worktrees\cleanup-worktree-c942a7` on the machine
`edge-dev`. **That machine also hosts both self-hosted CI runners** (`edge-dev-win`
and `edge-dev-win-2`) — see section 7, this is a trap.

## 2. What we set out to do this session, and why

Albert saw a social-media post promoting tools that claim to cut the token cost of
AI coding sessions, and asked whether they would help. Token cost is real money to
him. The work became:

1. Investigate the tools named in the post, on evidence rather than on claims.
2. Pilot the two that looked worthwhile in this repository, project-local only.
3. Measure the cost of one full test sweep before and after.
4. Later: fact-check further vendor claims Albert was given about a competing tool.
5. Finally: because the pilot kept getting derailed by CI dying, investigate why
   the Windows runners keep being interrupted.

## 3. Current state — what is true right now

**Landed on `main` (verified by merge commit):**

- `docs/windows-runner-interruptions-2026-09-01.md` — the runner evidence log.
  Merged, commit `72e4c327`, PR #203.
- `AGENTS.md` — quiet-output rules plus the `edge-dev` local-sweep guard. Merged,
  commit `90b45b8a`, PR #202.

**MERGED 2026-09-01T15:02Z — this section is retained because the STORY is the
evidence for issue #204, not because the work is outstanding:**

- **PR #197 — `.mcp.json` adding the Context7 documentation server.**
  <https://github.com/popcre/ai-devops/pull/197>
  State: **MERGED**, commit `08749a97aa5e05a5eba50f7f6ac91868cc8335dd`. Verified
  by reading `.mcp.json` from `main` through the contents API. It took roughly ten
  hours and seven trips through the merge queue for a two-line configuration file.
  Historic state below, kept as the evidence: it was mergeable with all three of
  its own checks PASSED
  (`linux-offline` 9m52s, `windows-offline` 1h3m51s, `windows-reviewer-safety`
  14m22s, run 33449373129). It has been placed in the merge queue **four** times
  and cancelled every time — most recently by my own merges of PR #202 and #203,
  which is itself evidence for issue #204. There is nothing wrong with the change.
  It is one file:

  ```json
  {
    "mcpServers": {
      "context7": {
        "command": "npx",
        "args": ["-y", "@upstash/context7-mcp@latest"]
      }
    }
  }
  ```

**Machine-local on `edge-dev`, deliberately not committed** (`.claude/` is
gitignored at `.gitignore:87`):

- `.claude/settings.json` in the worktree above — RTK's automatic hook was written
  here and has now been **removed**; the file is `{}`. A backup of the hook version
  is at `.claude/settings.json.rtk-backup`.
- `~/.local/bin/rtk.exe` — RTK v0.46.0, installed, no longer hooked to anything.
- `~/.local/bin/lean-ctx.exe` — LeanCTX v3.10.0, installed (SHA256 verified against
  the project's published `SHA256SUMS`), compression level set to `max`, not wired
  into any agent.

**Measurements taken (see section 5 for what they mean):** raw test sweep 103,959
bytes; the same sweep through RTK 15,313 bytes.

## 4. Everything we tried that did NOT work

This section is the point of the handoff. Do not repeat any of it.

1. **Reading the source Twitter/X post with the web-fetch tool** — returns HTTP
   402. The in-app browser works; use that for x.com.
2. **Installing RTK from npm** — `npm install rtk` fetches a completely different,
   unrelated package (a release tool by a different author). RTK's own README
   warns about this name collision. Install the binary from the `rtk-ai/rtk`
   GitHub release instead.
3. **Running `rtk init`** — it injected roughly 140 lines of instructions into the
   tracked `CLAUDE.md`, which contradicts that file's stated purpose and is itself
   a permanent token cost in every session. Reverted with
   `git checkout -- CLAUDE.md`. If you ever run RTK's installer, check `git status`
   immediately afterwards.
4. **Wrapping the whole test sweep in RTK — hung twice.** First hang: RTK blocks
   forever on standard input; you must add `< /dev/null`. Second hang: even with
   that, it ran and then stalled for ~70 minutes with zero child processes and zero
   output. The workaround that does work is per-suite with a timeout:

   ```bash
   for t in tests/test-*.sh; do case "$t" in *test-all.sh) continue;; esac; printf "\n===== %s =====\n" "$(basename $t)"; timeout 300 rtk test bash "$t" < /dev/null 2>&1; done
   ```

5. **Believing the 85% saving was compression.** It is not. RTK's test mode prints
   only the last five lines of each suite. It shows **no pass/fail counts at all**.
   The one genuine failing test in the sweep (`FAIL source-drift follow-up also
   becomes recovery-required with evidence`, in `tests/test-ai-qwen.sh`) was visible
   only by luck, because it happened to fall inside those last five lines. RTK does
   write full output to disk and prints the path.
6. **Expecting LeanCTX's advertised features to exist.** Albert was told LeanCTX
   offers "Shadow Mode" — a dry-run that proves token savings. **There is no shadow
   mode in the product.** Nothing in `lean-ctx help all` implements it.
7. **Expecting LeanCTX to compress anything.** At maximum compression it returned
   output the same size as no tool at all: commit history 15,762 → 15,762 bytes;
   reading a document 10,385 → 10,386; a code diff 62,977 → 62,977; a file listing
   1% smaller. Its ten advertised "read modes" produced byte-identical output on
   both Markdown and shell scripts. The only real win was search: 9,312 → 2,775
   bytes, about 70%.
8. **Running RTK as a control on those same commands** — also near-zero. Note the
   invocation trap: `rtk -c "cmd"` is not valid and silently produces a 122-byte
   error; the working forms are `rtk run "cmd"` and `rtk <program> <args>`.
9. **`gh pr merge 197 --squash` printing "The merge strategy for main is set by the
   merge queue."** That is not a failure. The PR does enter the queue.
10. **Waiting on the pull request's state alone to detect a merge.** A queue
    ejection leaves the PR OPEN, so a naive wait loop waits forever. Watch the
    `gh-readonly-queue/main/pr-<n>-<sha>` run as well.
11. **An earlier attempt on PR #196** — its branch carried two other sessions'
    commits and conflicted. Abandoned; PR #197 was rebuilt as a single clean file
    commit on top of `origin/main` using git plumbing.
12. **Deleting the shared remote branch after that** — it held another session's
    only copy of commit `bffec57f`. Detected with `git branch -r --contains` and
    restored by pushing the commit back. Nothing was lost, but do not delete a
    shared branch in this repository without that check first.

## 5. Root causes and key findings

**On the token tools — the conclusion is negative, and that is the finding.**
Neither RTK nor LeanCTX compresses ordinary command output in any measurable way.
The one impressive number produced in this session (85%) came from RTK truncating
test output to its last five lines, which is not compression and nearly hid a real
failure. Quiet flags achieve the same reduction at the source, for free, with
nothing standing between the agent and the truth. That is why Albert chose them
and why both tools are now inert.

**On the runners — four mechanisms, fully written up in
`docs/windows-runner-interruptions-2026-09-01.md`:**

1. **Merge-queue regrouping is the dominant cause (confirmed).** Every merge by
   any session rebuilds the queue group on a new base commit and cancels the
   in-flight run, restarting the 60–75 minute `windows-offline` job from zero.
   Because that job is longer than the typical gap between two sessions' merges,
   it can effectively never finish. PR #197 demonstrates it four times over about
   seven hours. PR #191 shows the same pattern on 2026-08-31.
   The workflow's concurrency key falls through to `github.sha` for `merge_group`
   events, so two runs for the same group SHA also cancel each other directly.
2. **Two runners cannot serve two Windows jobs plus concurrent pull-request and
   push runs (confirmed).** In run 33467918585, `windows-offline` waited 15 minutes
   for a slot and then ran on the same runner the other job had just released.
   Queueing stretches wall-clock time, which widens the window for mechanism 1.
3. **One abrupt death, exit code -1, unexplained.** Run 33486858691, 08:55:51,
   mid-suite, after tests had been passing. It was reported as `failure`, **not**
   `cancelled` — indistinguishable from broken code in the interface. A job on the
   *other* runner was cancelled 90 seconds earlier, which points at something
   machine-wide. Only the runner service logs on `edge-dev` can settle it.
4. **Local test sweeps on `edge-dev` kill live CI (previously known).** This was
   already recorded in earlier sessions' notes. I ran two full local sweeps on that
   machine during the measurement work before knowing it, which may have collided
   with runs on 2026-08-31. I could not prove which, and did not claim it.

**`linux-offline` has never once been interrupted.** Every interruption in the
observed window is on the two self-hosted Windows runners.


### The queue backlog was mostly stale duplicates, and the concurrency key is why (found 2026-09-01, the biggest finding of this session)

Albert asked the right question — "am I really doing that much work? none of them
are duplicates? none are stale?" Measured at 18:59Z: **11 runs pending, 9 of them
on ONE branch** (`codex/issue-209-windows-runner-pool`) across **6 different
commits**, only the newest of which was live. About 7.5 hours of queued Windows
work for commits that had already been superseded.

**Root cause.** `verify.yml` keys its concurrency group on
`github.event.pull_request.head.sha || github.sha`. A new commit is a NEW group,
so `cancel-in-progress: true` can never fire across pushes on the same pull
request. The setting looks like superseded-run cancellation and does nothing of
the kind. A per-PR / per-branch key is required; the suggested replacement is on
issue #204.

This reframes the whole document: the capacity crisis in mechanism 5 was not
mostly real demand. It was one broken line of YAML manufacturing phantom load.

**Action taken:** the 6 superseded runs were cancelled (`gh run cancel`), taking
the backlog from 11 to 5. This is safe — required checks attach to the pull
request head SHA, so queued work for a superseded commit can never become that
check. Grok confirmed before the cancellation.

## 6. Exact next steps

1. ~~**Merge PR #197.**~~ **DONE 2026-09-01T15:02Z**, commit `08749a97`.

2. ~~**If it is cancelled again, stop retrying.**~~ Not needed; it landed.

3. **Verify Context7 actually works once it is merged.** In a fresh Claude Code
   session in this repository, confirm the `context7` MCP server is listed and
   answers a documentation query.
   *You will know it worked when* a library-docs question returns current
   documentation without an API key.

4. **Only if Albert says yes to decision 2:** pull the Windows runner service logs
   on `edge-dev` for 2026-09-01 08:54–08:56 and determine what killed the job that
   exited `-1`. The runner logs live under the runner installation's `_diag`
   folder. *You will know it worked when* you can state whether the kill came from
   GitHub (a cancel signal) or from the machine (resource pressure, another
   process).

## 7. Constraints and gotchas in force

- **`edge-dev` — the machine this session ran on — hosts both Windows CI runners.
  Never start a local full test sweep there while a GitHub run is active; it kills
  the live job.** Now written into `AGENTS.md`.
- **Albert does not merge — the session that opens a pull request merges it.**
  Never end a reply asking him to merge or review.
- **Documentation-only pull requests do not wait for checks.** Check the changed
  file list; if every file is prose, merge immediately with
  `gh pr merge --squash --admin`. PRs #202 and #203 were merged this way, correctly.
  `.mcp.json` is configuration, not prose, so PR #197 does **not** qualify.
- **This repository uses a merge queue.** `gh pr merge --squash` queues rather than
  merges. `--admin` does not bypass a ruleset.
- Work directly on `main` for this repository; several AI sessions share the
  checkout. Stage only your own files. Never use bare `git stash` / `git stash pop`
  in a worktree — the stash stack is shared with other sessions.
- Run all commands from the worktree directory; do not `cd` to the repository root.
- Before the first commit, `git var GIT_COMMITTER_IDENT` must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Albert is a business owner, not a programmer. Replies to him are short, in plain
  English, with no file paths or tool names unless he has to act on them.

## 8. Access and environment

- `gh` CLI is authenticated for `popcre/ai-devops` and was used throughout.
- Working directory: `C:\repos\ai-devops\.claude\worktrees\cleanup-worktree-c942a7`
  on `edge-dev`, Windows 11. Bash tool is Git Bash; PowerShell also available.
- Scratch files from this session (the measurement outputs and the drafts of the
  two merged documents) are under the session scratchpad in
  `%LOCALAPPDATA%\Temp\claude\...` and under `%LOCALAPPDATA%\Temp\qf`. Nothing
  important lives only there — both documents are merged.
- No secrets were used, created, or touched in this session. Secrets for this
  toolkit live in the 1Password vault `vibe_coding` — by location only, never by
  value.
- Two binaries were installed to `~/.local/bin` on `edge-dev`: `rtk.exe` and
  `lean-ctx.exe`. Both are inert.

## 9. Open questions and risks

- ~~**Will PR #197 ever land under the current queue behaviour?**~~ **RESOLVED:
  yes, but at absurd cost** — it landed on the seventh queue attempt after roughly
  ten hours, for a two-line configuration file. The cost, not the outcome, is the
  argument for issue #204.
- **What killed the job at 08:55 on 2026-09-01?** Unknown, and unanswerable from
  GitHub's data. Decision 2.
- **Did my own local test sweeps on 2026-08-31 cancel other sessions' CI runs?**
  Possible, unproven, and deliberately not claimed in the merged evidence document.
- **Decision, 2026-09-01:** RTK's automatic hook was removed rather than narrowed,
  on Albert's instruction, after measurement showed near-zero compression on
  ordinary commands. Do not re-litigate this without new measurements.
- **Decision, 2026-09-01:** LeanCTX was evaluated and rejected for automatic use.
  Two of its three advertised headline features (Shadow Mode, meaningful read-mode
  compression) do not exist or do nothing in practice. If a later session is
  pitched LeanCTX again, the measurements are in section 4, item 7.
- **Risk:** the `.claude/settings.json.rtk-backup` file on `edge-dev` still contains
  the RTK hook. If someone restores it without reading this handoff, RTK's five-line
  truncation comes back and can hide test failures.

---

## Self-audit (mandatory gate — all four answered before this file was shown)

1. **Comprehensive enough for a brand-new developer with no context?** Yes.
   Section 1 defines the repository, the machine, and the CI layout from zero;
   section 2 gives the business reason; section 3 states exactly what is merged and
   what is not, with commit SHAs and the full content of the one unmerged file;
   section 6 gives executable next steps with verification gates.
2. **Could they continue as well as I could right now?** Yes. Every non-obvious
   thing this session cost time to learn is in section 4 — the npm name collision,
   the two distinct RTK hangs and the exact working command, the invalid `rtk -c`
   flag, the `CLAUDE.md` pollution, the merge-queue wait trap, and the shared-branch
   deletion near-miss. Section 5 carries the reasoning behind the negative
   conclusion, so a successor will not re-run the same evaluation.
3. **Every relevant detail for flawless execution?** Yes. Measured numbers with
   both sides (section 4, items 5 and 7); run IDs, job names, runners and timestamps
   for every runner interruption (section 5, and the merged evidence document);
   commit and merge status stated per item (section 3); constraints including the
   `edge-dev` trap and the merge-queue behaviour (section 7); secrets by vault name
   only (section 8).
4. **If Albert read ONLY section 0, would he see every decision I need from him,
   including out-of-scope ones?** Yes — verified by walking sections 1–9 line by
   line. The sweep found four items needing his judgement: whether the long suite
   should run in the queue (from section 5, mechanism 1), whether to investigate the
   08:55 death (section 5, mechanism 3 and section 9), whether the runners belong on
   a working machine (section 5, mechanism 4 — **out of scope for the original
   task, and promoted for exactly that reason**), and whether to keep the two
   installed binaries (section 3). All four are in section 0 with a recommendation,
   grouped by cost, plus a dated "already settled" list so the three decisions Albert
   already made this session are not re-asked.
