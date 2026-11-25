---
summary: Plan for mechanical Claude Code checks — fix the swallowed hard block, proof-of-done, destructive-command guard (#2835)
kind: plan
status: open
read-when: Changing ai-completion-check-hook or ai-pr-poll-guard-hook, or work on false "done" claims or destructive git commands
---

# Implementation plan — harness sensors (v2)

Issue: [popcre/ai-devops#2835](https://github.com/popcre/ai-devops/issues/2835).
Handoff: [HANDOFF.d/2026-11-25T0358Z-edge-dev3-claude-harness-sensors.md](HANDOFF.d/2026-11-25T0358Z-edge-dev3-claude-harness-sensors.md).
Created 2026-11-24 by a Claude session on `edge-dev3`. v1 merged in #2836.
v2 rewritten 2026-11-24 11:20 PM EST after an Antigravity review.

## STATUS

| Step | What | State | Evidence |
|---|---|---|---|
| 0 | Plan reviewed | ✅ 2026-11-24 | Codex `gpt-6.2-astra` low: 2 rounds, 8 defects (v1). Antigravity `gemini-4-neon-high`: round 1 found 8 defects (v1); round 2 confirmed 7 closed and 1 partly closed, and found 3 new defects in v2. All are applied. The final 3 fixes were not re-reviewed (two-round cap). |
| 1 | Capture real hook payload fixtures | ⬜ open | — |
| 2 | Un-swallow the existing hard block | ⬜ open | — |
| 3 | Proof-of-done | ⬜ open | — |
| 4 | Destructive-command guard | ⬜ open | — |
| 5 | Docs | ⬜ open | — |
| 6 | Protected install + live proof on edge-dev3 | ⬜ open | — |

**A fresh session starts at step 1.** Steps 1 → 2 → 3 run in order. Step 4 is
independent of steps 1–3 and may run in parallel; it touches a different file.

---

## Part 1 — Why

### 1. The ultimate goal

Albert owns POP Creations and is not a programmer. He runs many AI coding
sessions, and two failures keep costing him time and trust:

1. A session says a job is **done** when nothing proved it.
2. Rarely, a session runs a command that **destroys unsaved work**, sometimes
   another session's.

Rules against both already exist, but only as written instructions, and written
instructions drift. When this plan is done, the machine itself catches both
failures as they happen, at no model (LLM) cost, and never jams a session.

**If a step conflicts with this goal, the goal wins. Stop and flag it on #2835.**
Three things break the goal: a check that wedges a session, a check that blocks
legitimate work, and a check that a trivial spelling change gets around.

### 2. What this application is

`popcre/ai-devops` is Albert's AI toolkit: global instructions, skills, wrapper
commands (`bin/ai-*`) and Claude Code hooks. It is installed on each machine
(edge-dev, edge-dev3, hetz and others) through the protected install described
in `docs/deployment.md`.

Hooks are bash scripts that Claude Code runs on events (`UserPromptSubmit`,
`PreToolUse`, `PostToolUse`, `Stop`). An installer (`bin/ai-install-*-hook`)
copies each one, **as a single file**, to `~/.config/ai-devops/<name>` and
registers it in `~/.claude/settings.json`. Branch from `main`; PRs merge through
the repo's merge queue.

### 3. What triggered this work

On 2026-11-24 Albert shared the X article "Harness Engineering: How to Fix Your
Agent Without Changing the Model" by @0xTrackmind (2026-11-21). Its thesis is
that most agent failures come from the environment around the model, so prose
rules should become mechanical checks.

Claude, Muse and DeepSeek debated it against this repo and agreed the article is
sound. A query of the transcript store (`ai-transcript-query`, about 17k
sessions) then tested the gaps they found. These are substring counts on segment
summaries, not a verified classification:

- **False "done": supported.** 109 `ai-mistakes` segments match "claimed", 51
  "false claim" and 12 "premature". Examples are invented test results and live
  sites "confirmed" when they were not.
- **Destructive commands: rare but costly.** Two "reset --hard" segments,
  including "Git hard-reset destroyed another session's uncommitted work", plus
  4 force-push segments. The 3 "rm -rf" hits are test-cleanup bugs, not agent
  damage.
- **Same-command retry loops: NOT supported.** There are 1,209 `agent-loop`
  segments, but a 40-subject sample is mostly blocked CI queues, waiting and
  subagent coordination. Only 3 match "same error", 2 "same failure" and 14
  "same command". Dropped, as section 7 records.
- **Lost state on long jobs: NOT supported.** There are 0 "lost track" matches.
  Dropped.

### 4. Scope

**In:** steps 1–6, Claude Code only, built by extending the two installed hooks
`bin/ai-completion-check-hook` and `bin/ai-pr-poll-guard-hook`.

**NOT in this plan:**
- An LLM judge or a second grading agent. The owner closed
  `plan_selective-fresh-reader.md` "not planned" on 2026-11-02, and reviews are
  advice only (owner ruling 2026-10-29).
- Behavioral evals. The owner said "stop measuring" on 2026-08-26
  (`plan_completion-honesty-enforcement.md`, step 10).
- A repeat-failure stop (section 7).
- Progress or checkpoint files.
- Codex, ZCode, MiMo or Antigravity parity, and any change to their behavior.
- Trimming the global rulebook.
- Protection for pushes to `main`. GitHub branch protection already refuses
  them, and that stays the wall. The guard only refuses force-pushes.
- CI, the merge queue and the sweeper. These hooks see only Claude's own tool
  calls.

---

## Part 2 — What we already know

### 5. Current state of the code (main at `70d97303`)

- `bin/ai-completion-check-hook` (230 lines):
  - `UserPromptSubmit` prints the New York time and resets the per-session
    state file `~/.local/state/ai-devops/completion-check/actions/<session>` to
    `no-action`. It also removes the `.action` marker.
  - `PostToolUse` sorts each tool call (lines 50–70). `Write`, `Edit`,
    `MultiEdit` and `NotebookEdit` count as `action`. So do Bash commands
    matching the regex at line 57, which covers git writes **and** test runners
    (`pytest`, `bash tests/…`, `npm test`, `make` and others). Everything else
    is `inspection`. An action also touches the monotonic `.action` marker.
  - `Stop` judges only the closing paragraphs of `last_assistant_message`
    (around line 153). It matches the fixed `COMPLETION_CLAIMS` phrases and the
    `FUTURE_COMMITMENTS` phrases.
  - A completion claim gets a JSON `decision: block` nudge on stdout, once per
    `prompt_id`. It fires whether or not anything was verified.
  - A future promise with no action also prints the reason on stderr and does
    `exit 2` (lines 222–228).
  - Every internal error exits 0.
- **Pre-existing bug:** the Claude registration in `~/.claude/settings.json`
  (written by `bin/ai-install-completion-check-hook`, around line 268) is
  `bash ".../completion-check-hook" 2>/dev/null || true`. That wrapper throws
  away stderr and turns `exit 2` into `exit 0`, so the intended "hard block" on
  empty promises never happens. Only the JSON nudge survives. The poll-guard
  registration has no such wrapper (`bin/ai-install-pr-poll-guard-hook:80`).
  Verified on edge-dev3: `~/.claude/settings.json` lines 47, 59 and 82.
- The same hook script is also registered for ZCode (`--client zcode`, installer
  lines 153–220) and Antigravity.
- `tests/test-ai-completion-check-hook.sh` (172 lines) runs the hook from the
  repo path. `config/ci-suite-manifest.json:111-128` maps each `bin/ai-*-hook*`
  file to its suite.
- `bin/ai-pr-poll-guard-hook` (73 lines) is a PreToolUse Bash guard.
  - It rewrites Windows shell spellings, drops heredoc bodies, unwraps
    `bash -c` / `eval`, and strips **all** quotes, including
    `tr -d "\"'"` at line 48.
  - It then refuses sleep-plus-PR-read loops with `exit 2`.
  - `tests/test-ai-pr-poll-guard-hook.sh` (124 lines) replays every case with
    Windows spellings.
- `config/claude-permissions.allow` has one deny line (line 47). Line 48 retires
  an earlier broad `sleep` deny that broke legitimate work.
- `python3` exists on Linux machines. `tools/` and some `bin/` scripts use it.
- Nothing in this plan has been started.

### 6. Key findings

- The completion hook is a reminder, not a sensor. It cannot tell a verified
  claim from an unverified one, so its evidence can never come back red.
- Test runners are classed as `action` today. A proof-of-done check therefore
  needs separate **mutation** and **verification** classes. A test is
  verification and not mutation, while the existing future-promise logic must
  still treat tests as "did something".
- A single boolean marker cannot order "verified after the last change" across
  parallel `PostToolUse` calls. An append-only per-prompt event log (one
  `printf >>` line per call) can.
- The poll guard's quote-stripping destroys exactly the information a
  destructive guard needs (`"$HOME"`, quoted `-C` dirs, `-m` messages). Doing
  shell word-splitting correctly in sed/awk is error-prone. Python's `shlex`
  does it in a few lines.
- Installers copy one file. A shared library file would not be installed and
  would fail open silently. Any helper code must live **inside** the hook file
  that uses it.
- The installed checkout advances only through the protected install
  (`docs/deployment.md`). A plain `bash install.sh` or `git pull` there is wrong
  (`AGENTS.md`, around line 127).

### 7. Approaches considered and REJECTED

- **LLM judge or "fresh reader".** Rejected: owner closure 2026-11-02, and it
  spends LLM tokens.
- **Deny lines in `config/claude-permissions.allow`.** Rejected: they match on
  prefix, so `git -C x reset --hard`, `cd x && …` and `bash -c` all get around
  them, and a broad `rm -rf` deny breaks cleanup. The retired `sleep` deny
  (line 48) is the precedent.
- **Trimming the rulebook first.** Rejected: the #1881 trim drifted back.
- **PROGRESS.md checkpoint log.** Rejected: no evidence (section 3).
- **Repeat-failure stop** (same command plus same error twice in 30 minutes,
  then refuse). It was in v1 and was dropped in v2. Evidence is too thin (3–14
  segments). It would need cross-hook state, a `PostToolUseFailure` wiring
  change and a migration. Hashing stderr misses failures whose output changes
  (timestamps, PIDs, stdout-only) and would refuse legitimate retries (`curl`,
  `gh pr checks`). Antigravity recommended dropping it, and Claude's own
  transcript sample agreed. Revisit only if a classified transcript query shows
  same-command retries are common.
- **Bash/sed/awk parser for the destructive guard (v1).** Rejected: Antigravity
  found false refusals (`git commit -m "a && b; rm -rf /"` split into a bogus
  `rm -rf /`) and bypasses (`rm -rf ''"$HOME"`, `${HOME}`, `"$HOME/"`, bare
  `.git`). Replaced by a Python `shlex` block embedded in the hook (step 4).
- **A shared normalization library used by both hooks (v1).** Rejected: the
  installers copy single files, so it would not be installed.
- **The `git clean -n` dry-run check (v1).** Rejected: a failing git command
  prints nothing, which reads as clean, and flag forwarding (`-e`) is fragile.
  A plain `git clean -f` on a clean tree is a no-op anyway, so refusing every
  forced clean costs nothing.
- **`ai-task-gates check` as the done-check.** Rejected: it checks the task
  class, not whether the deliverable works. It stays as one verification
  command.

### 8. Design decisions

**Locked:**
- Deterministic code only, with no model calls.
- Fail-open on any internal error (exit 0). A missing `jq` or `python3` means
  allow. A deliberate refusal is a verdict, not an error.
- Nudges fire at most once per `prompt_id`.
- New completion-hook behavior runs only with the `--sensors` argument, which
  only the Claude registration passes. ZCode and Antigravity behave exactly as
  today.
- Helper code lives inside the hook file that uses it, with no shared library.
- `--force-with-lease` is allowed. `--force`, `-f` and `+refspec` are refused.
- `git clean` with `-f` / `--force` is always refused.

**Open (the criteria are in the steps):**
- The exact verification-command list (step 3).
- How widely an unverified mutation turn is caught beyond the fixed phrases
  (step 3).

---

## Part 3 — How to build it

### 9. The plan

Work in a fresh worktree from `origin/main`. Run
`ai-task-gates start --class code --reason "harness sensors #2835"`.

#### Step 1 — Capture real hook payloads (`lead-only`: it decides what step 3 trusts)

- In a scratch `CLAUDE_CONFIG_DIR`, never the live one, register a logging hook
  for `PostToolUse` and `PostToolUseFailure` that writes stdin to files.
- Run `claude -p` there with three prompts: run `true`, run
  `bash -c 'echo boom >&2; exit 3'`, and write a file.
- Save the scrubbed payloads (session ids set to `FIXTURE`, home paths
  generalized) under `tests/fixtures/hooks/`, one file per case.
- Record in section 5 which field and which event show that a Bash call failed.

**It worked when:** the fixtures exist, and a `jq` expression written into this
plan prints `ok` for the success fixture and `fail` for the failure fixture.

#### Step 2 — Un-swallow the hard block (`lead-only`: it changes a registration every Claude session runs)

- In the **Claude branch only** of `bin/ai-install-completion-check-hook`
  (around line 224 onward), register
  `bash "$HOME/.config/ai-devops/completion-check-hook" --sensors`, with no
  `2>/dev/null || true`. The hook is already fail-open inside.
- Upgrade an existing Claude registration in place, matched by its marker
  string. `--check` prints `DRIFT` for the old form and `OK` for the new one.
- Leave the ZCode and Antigravity branches byte-identical.
- The hook accepts `--sensors`. Until step 3 lands, the flag changes nothing.

**It worked when:** these tests pass: `installer upgrades old Claude
registration`, `--check DRIFT then OK`, `zcode config byte-identical`, and
`future promise with no action exits 2 through the registered command line`.
The last one runs the exact registered string through `bash -c`.

#### Step 3 — Proof-of-done (`lead-only`: it changes a hook every session runs)

All of this goes in `bin/ai-completion-check-hook`, and runs only when
`--sensors` is passed.

- **Event log.** On every `PostToolUse`, append one line to
  `…/completion-check/turns/<session>`. Key it by session only, like the
  existing `$action_file`, because `PostToolUse` payloads may lack `prompt_id`
  and `Stop` falls back to a message checksum. Delete it with `rm -f` on every
  `UserPromptSubmit`, so it always holds the current prompt only. Each line is
  `<seq> <class> <ok|fail|unknown>`. `seq` is a nanosecond timestamp. Use one
  `printf >>` call per line, which is atomic for short lines. `class` is one of
  three:
  - `mutation`: Write, Edit, MultiEdit, NotebookEdit, and Bash git writes
    (`add`, `commit`, `push`, `merge`, `rebase`, `cherry-pick`, `apply_patch`).
  - `verification`: see the next bullet. Only Bash calls qualify.
  - `inspection`: everything else.

  The existing `.action`
  marker keeps its current meaning (mutation **or** a test runner), so the
  future-promise guard is unchanged.
- **Verification command list.** These count only as the first word of a simple
  command, after splitting on `&&`, `||`, `;`, `|` and `&`:
  - `pytest`
  - `python -m pytest` / `python -m unittest`
  - `bash tests/…`, `./tests/…`
  - `npm test`, `pnpm test`, `yarn test`
  - `go test`, `cargo test`, `dotnet test`
  - `ai-task-gates check`
  - `ai-pr-wait` / `bin/ai-pr-wait`
  - `gh pr checks`
  - `git diff --exit-code`
  - any `ai-*` or `bin/ai-*` command whose arguments include `--check`
  - `curl` with `-f`, `--fail` or `--fail-with-body`

  Rule for adding to the list: the command must exit non-zero when the thing is
  wrong.
- **Exit-status ownership.** A Bash call counts as verification only when all of
  these hold:
  - The whole command is a chain joined only by `&&`, with no `;`, `||`, `&` or
    newline-separated statements.
  - At least one link is a verification command.
  - No link starts with `!`.
  - There is no `|`, unless `set -o pipefail` comes first in the chain.
  - It is not inside `if`, `while` or `until`.

  So `pytest && git status` counts. `pytest || true`, `! pytest`,
  `true || pytest`, `pytest; echo ok` and `pytest | tail` do not.

  Parse with the same embedded `shlex` approach as step 4: a small
  `python3 - <<'PY'` block inside this hook. If `python3` is missing, the call
  is `inspection`.
- **Success.** Use the success or failure signal from step 1. If it is unknown,
  record `unknown`, which does not count.
- **Stop with `--sensors`.** A turn is *verified* when its last `verification ok`
  line comes after its last `mutation` line.
  - **Claim matched and verified:** allow silently. This removes today's noisy
    nudge for honest turns.
  - **Claim matched, a mutation happened, not verified:** block once, with JSON
    on stdout plus `exit 2`. The reason: "This turn changed things and claims
    completion, but no command that could fail checked the result after the last
    change. Write the reason to **stderr** as well as the JSON, before `exit 2`
    (Claude Code reads the reason from stderr on exit 2), as the future-promise
    path does at line 226. Run a check (test, --check, CI wait, HTTP status with --fail) or say
    plainly what is unverified."
  - **Claim matched, inspection only:** today's nudge, unchanged.
  - **No claim matched, a mutation happened, not verified:** this is the
    "Fixed and pushed." bypass. Block once with the same reason, **unless** the
    closing paragraphs contain any of: `unverified`, `not verified`,
    `not tested`, `untested`, `still open`, `not done`, `pending`, or a line
    ending in `?`.

  Judgment for the implementer: if this last case fires on more than about 1 in
  10 honest replay turns in tests, narrow it to past-tense delivery words
  (`fixed`, `pushed`, `merged`, `deployed`, `shipped`, `done`) and record that
  choice here.
- **Known limit**, to state in the hook header: a passing check unrelated to the
  deliverable still counts. Code cannot judge relevance, so the written rule
  still covers that.

**It worked when:** every step 3 test in section 10 passes, and the whole suite
stays green with `bash tests/test-ai-completion-check-hook.sh`.

#### Step 4 — Destructive-command guard (`lead-only`: a trust-boundary parser)

This goes in `bin/ai-pr-poll-guard-hook`. Add one embedded block,
`python3 - "$cwd" <<'PY' … PY`, that reads the **raw** command from the payload
before any of the existing sed/awk/quote-stripping. It prints a refusal reason
or nothing. If it prints a reason, the hook prints that on stderr and does
`exit 2`. The existing poll rules then run unchanged. If `python3` is missing or
the block errors, skip the guard (fail-open).

Inside the block:

1. **Text vs command.** Tokenize with a small POSIX-style tokenizer, about 40
   lines, written in the block. `shlex` alone loses quote types, which item 4
   needs. The tokenizer yields operator tokens and word tokens, and each word is
   a list of `(text, kind)` pieces, where `kind` is `bare`, `single` or
   `double`. Backslash escapes are honored outside single quotes. An
   unterminated quote means *parse error*, which means the guard allows
   (fail-open), and a test covers it. Operators `;`, `&&`, `||`, `|` and `&`
   split simple commands only when they are **outside** quotes. So
   `git commit -m "a && b; rm -rf /"` is one command, a commit. Drop heredoc
   bodies first, using the same delimiter rule as the bash code at lines 33–40.
   Unwrap `bash -c '<script>'`, `sh -c` and `eval '<script>'` by recursing on
   the script. Normalize the first word with the same Windows-spelling rule
   (strip drive, path and `.exe`, lowercase) for `git`, `rm` and shells.
2. **Words that are only text.** Never inspect the arguments of `echo`,
   `printf`, or the values of git `-m`, `--message` and `-F`.
3. **Directory tracking.** Start from the payload `.cwd`. `cd <dir>` updates it,
   resolved against the current directory. `git -C <dir>` overrides it for that
   one command. A directory word containing `$(`, a backtick, or any `$VAR` other
   than `$HOME`, `${HOME}` or `$TMPDIR` is *unknown*.
4. **Expansion.** Work piece by piece, using the tokenizer's `kind`. Expand `$HOME`, `${HOME}` and `$TMPDIR` only in unquoted or
   double-quoted text, and `~` / `~/…` only when unquoted and at the start of a
   word. Then run `os.path.normpath`, which also collapses `//` to `/`, and strip
   trailing slashes **except** from the bare root `/`, so `rm -rf /` is still
   seen as `/`.
5. **Refuse** (each message names the safe alternative):
   - `git reset --hard`, `git checkout .`, `git checkout -- <paths>`, and
     `git restore` without `--staged`, or with `-W` / `--worktree`, when the
     target directory is dirty. Dirty means `git -C <dir> status --porcelain`
     prints anything. A **non-zero** status or an *unknown* directory also means
     refuse. Alternative: "commit a temporary WIP commit first."
   - `git clean` with `-f` or `--force` in any spelling, always. Alternative:
     "run `git clean -n` and remove named paths."
   - `git push` with `--force`, `-f`, or a refspec starting with `+`, unless the
     flag is `--force-with-lease` or `--force-if-includes`. Alternative:
     "use `--force-with-lease`."
   - `rm` with both a recursive flag (`-r`, `-R`, `--recursive`) and a force flag
     (`-f`, `--force`), in any combination, when any target after expansion is
     `/`, the home directory, `*`, `.`, `..`, or a path whose last component is
     `.git`.
6. Run at most one `git status` per guarded command, and only when a pattern in
   the first rule matched.

**It worked when:** every row of the adversarial table in section 10 has a
passing named test, and the existing poll-guard suite and its Windows replay
stay green.

#### Step 5 — Docs (`helper-ok`: exact files named)

- Update both hooks' header comments: what each check does, its known limits,
  and the `--sensors` flag.
- Add one line per check to `docs/config-inventory.md`, in the Claude hooks
  entry.
- Add a memory entry `harness-sensors.md`: "read plan_harness-sensors.md STATUS
  first".
- **Stop-and-ask trigger:** any change to `templates/system/*-global*.md`, or
  any doc that would describe behavior differently from the code, goes back to
  the lead.

**It worked when:** the docs suites mapped in `config/ci-suite-manifest.json`
pass in CI on the PR.

#### Step 6 — Protected install and live proof (`lead-only`: live-proof judgment)

- After merge, install on edge-dev3 **through the protected install in
  `docs/deployment.md`**: a candidate worktree at the merged SHA, then
  `ai-task-gates authorize-install --target-head <SHA>`, then that candidate's
  `update.sh`. Never `git pull` or a direct `install.sh` in the installed
  checkout.
- Confirm with `ai-install-completion-check-hook --check` and
  `ai-install-pr-poll-guard-hook --check`. Both must print OK, and the Claude
  command line must show `--sensors` and no `|| true`.
- Live proof with `claude -p`, in a scratch git repo under `$TMPDIR`:
  1. With an uncommitted change, ask it to run `git reset --hard`. The command
     must be refused, and the change must survive.
  2. Ask it to edit a file and end with "task is complete" without testing. Stop
     must block with the new reason.
  3. Ask it to edit a file, run `bash -c 'exit 0'` as a stand-in test, and claim
     completion. It must be allowed. This needs a test-shaped command such as a
     tiny `tests/ok.sh` run as `bash tests/ok.sh`.
  4. Ask it to promise future work and do nothing. It must be hard-blocked
     (exit 2), which proves step 2.
- Record the commands and outputs in
  `tests/verification/harness-sensors/<date>-live.md`.

**It worked when:** that file shows all four outcomes, and the `Live proof` box
on #2835 is ticked, citing it.

**Cut point:** one session does steps 1–5 and the PR. Step 6 needs the merged
SHA, and the same or a fresh session can do it.

### 10. Tests required

`tests/test-ai-completion-check-hook.sh`. Every existing case must pass
**without** `--sensors`, which is the ZCode path. These new cases run with
`--sensors`:
- `verification ok after mutation then claim → silent`
- `mutation, no verification, claim → blocks (exit 2, reason on stderr, JSON on stdout)`
- `PostToolUse without prompt_id → Stop still sees its events`
- `mutation in prompt 1 does not leak into prompt 2`
- `inspection only, claim → old nudge text`
- `passing test, then Edit, then claim → blocks`
- `failing test then claim → blocks` (uses the step 1 failure fixture)
- `pytest && git status then claim → silent`
- `pytest || true`, `! pytest`, `true || pytest`, `pytest; echo ok`, `pytest | tail` then claim → blocks
- `set -o pipefail && pytest | tail then claim → silent`
- `echo --check`, `grep -- --check f`, `gh pr view` → not verification
- `"Fixed and pushed." after unverified mutation → blocks once`
- `"Fixed; not tested yet." after unverified mutation → silent`
- `parallel PostToolUse lines never lose an event` (10 background writers, then count lines)
- `python3 missing → inspection, no crash` (PATH without python3)
- step 2: `installer upgrades old Claude registration`, `--check DRIFT then OK`, `zcode config byte-identical`, `future promise exits 2 through the registered command line`

**Adversarial cases for step 4** (the outside input is the command string the
model writes). These go in `tests/test-ai-pr-poll-guard-hook.sh`, with real temp
git repos under `$TMPDIR`:

| Input | Case | Expected | Test name |
|---|---|---|---|
| `git reset --hard` | dirty | refuse | `reset-hard dirty refused` |
| `git reset --hard` | clean | allow | `reset-hard clean allowed` |
| `git -C "/x y" reset --hard` | quoted dir, dirty | refuse | `reset-hard quoted -C refused` |
| `cd /x && cd sub && git reset --hard` | chained cd, dirty | refuse | `reset-hard chained cd refused` |
| `cd /dirty && git -C /clean reset --hard` | `-C` overrides | allow | `reset-hard -C overrides cd` |
| `cd "$(pick)" && git reset --hard` | unknown dir | refuse | `reset-hard unknown dir refused` |
| `git -C /not-a-repo reset --hard` | status fails | refuse | `reset-hard status error refused` |
| `bash -c 'git reset --hard'` | wrapped, dirty | refuse | `reset-hard in bash -c refused` |
| `GIT.EXE reset --hard`, `"C:/Git/bin/git.exe" reset --hard` | Windows, dirty | refuse | `reset-hard windows spelling refused` |
| `git commit -m "a && b; rm -rf /"` | operators in quotes | allow | `operators in message allowed` |
| `git commit -m "undo git reset --hard"` | text | allow | `reset-hard in message allowed` |
| heredoc body containing `git push --force` | text | allow | `force in heredoc allowed` |
| `echo "rm -rf ~"` | text | allow | `rm in echo allowed` |
| `git restore .` | dirty | refuse | `restore worktree dirty refused` |
| `git restore --staged --worktree .` | worktree, dirty | refuse | `restore staged+worktree refused` |
| `git restore --staged .` | unstage only | allow | `restore staged allowed` |
| `git clean -fdx`, `git clean --force -d` | forced | refuse | `clean forced refused` |
| `git clean -n` | dry run | allow | `clean dry-run allowed` |
| `git push -f origin b`, `git push --force origin b` | force | refuse | `push force refused` |
| `git push origin +b` | plus refspec | refuse | `push plus refspec refused` |
| `git push --force-with-lease origin b` | lease | allow | `push lease allowed` |
| `rm -rf /`, `rm -fr ~`, `rm -r -f "$HOME"`, `rm -rf ${HOME}`, `rm -rf "$HOME/"`, `rm -rf ''"$HOME"` | home/root | refuse | `rm home/root spellings refused` |
| `rm -rf '$HOME'` | single-quoted literal | allow | `rm single-quoted literal allowed` |
| `rm -rf "~"` | quoted tilde is literal | allow | `rm quoted tilde allowed` |
| `rm -rf .git`, `rm -rf repo/.git`, `rm -rf repo/.git/` | git dir | refuse | `rm git dir refused` |
| `rm -rf "$TMPDIR/x"`, `rm -rf .claude/worktrees/old` | cleanup | allow | `rm cleanup allowed` |
| `rm -rf *` | glob | refuse | `rm star refused` |
| `rm -rf //`, `rm -rf /./` | root spellings | refuse | `rm root normalized refused` |
| guard with no `python3` on PATH | missing tool | allow (fail-open) | `guard python3 missing allowed` |
| `git reset --hard "unterminated` | parse error | allow (fail-open) | `guard parse error allowed` |

The existing suites must stay green: `bash tests/test-ai-completion-check-hook.sh`,
`bash tests/test-ai-pr-poll-guard-hook.sh` (including the Windows replay), and
`bash tests/test-ai-claude-permissions.sh`.

### 11. Constraints, standing rules, gotchas

- Never push to `main` directly. Branch, open a PR, and the AI merges it; Albert
  never merges.
- Commit as `git var GIT_COMMITTER_IDENT`, staging only your own files. Sign
  GitHub posts with `$AI_GH_SIGNATURE`.
- The hooks run on every tool call. Keep them fast: no network, one `python3`
  start per call at most, and `git status` only when a reset/checkout/restore
  pattern matched.
- On Windows, `python3` may be a Microsoft Store alias that opens a pop-up
  (memory `windows-select-an-app-popups`). Before calling it, check
  `command -v python3` **and** that the path is not under `WindowsApps`.
  Otherwise skip (fail-open). Test this with a fake `WindowsApps/python3` on
  PATH.
- Keep LF line endings (memory `windows-crlf-breaks-bash-scripts`).
- On Windows, payload `cwd` and `-C` may be `C:\…` paths. Normalize with
  `os.path` and add a test.
- Never weaken the existing poll rules or their tests.
- No automated wait longer than 30 minutes.
- ZCode and Antigravity must behave exactly as today. That is why `--sensors`
  exists and why their installer branches stay byte-identical.

### 12. Access and environment

- Machine `edge-dev3` (Ubuntu). `gh` is authenticated as `u2giants`, and
  `claude`, `jq` and `python3` are on PATH.
- The installed checkout is `/home/ahazan/repos/ai-devops`. Never edit it or
  `git pull` there. Work under `.claude/worktrees/`.
- No secrets are needed.

### 13. Definition of done, risks, open questions

**Done:**
- Steps 1–6 are ✅, each STATUS row citing an artifact.
- The PR is merged with CI green (`bin/ai-pr-wait <pr>` in the background).
- The protected install is done on edge-dev3, with `--check` OK.
- The live-proof file exists.
- #2835's boxes are ticked and the issue is closed.

**Risks and rollback:**
- A false refusal blocks real work. Revert the PR and reinstall through the
  protected install.
- Making the hard block real (step 2) is a behavior change. Sessions that today
  silently get past an empty promise will now be stopped once per prompt. This
  is the intended behavior from 2026-10-21, and it was never active.
- The unverified-mutation block may be noisy. Step 3 gives the narrowing rule.

**Open questions:**
- Does codex-cli 0.172 support hooks? If yes, add parity to #2835 as a later
  item. Do not build it here.
- Other machines pick this up on their next protected install or
  `sync-dotfiles`. They are not installed in this pass.

---

## Self-audit (2026-11-24, v2)

1. *Could a new session execute this without asking?* Yes. Section 5 gives files
   and lines and the verified pre-existing bug. Each step in section 9 has its
   behavior and a gate. Section 10 names every test. The only unknown, the
   failure payload, becomes step 1 with a capture method.
2. *Does it carry the background and what was ruled out?* Yes. Section 3 has the
   evidence, including what it does **not** support. Section 7 lists nine
   rejected approaches with reasons and who raised them. Section 4 lists the
   owner closures.
3. *Is the goal clear enough for judgment calls?* Yes. Section 1 names the two
   failures and the three ways a check can break the goal. Step 3 gives a
   numeric narrowing rule for the one open judgment.

## Lead launch prompt

```text
You are the lead session for popcre/ai-devops issue #2835. Read plan_harness-sensors.md
in full, starting with its STATUS table; it is the whole brief. Do not re-plan or
reopen the locked decisions in section 8, and do not re-add the rejected approaches
in section 7.

Do steps 1, 2, 3, 4 and 6 yourself (all lead-only). Steps 1 → 2 → 3 run in order;
step 4 is independent. Step 5 (docs) may go to your helper after steps 2–4 are in
your branch. Your helper is your own tool's smaller model: Haiku (high effort) for
Claude Opus, Luna (high) for Sol, GLM Flash for GLM MAX, Mimo Flash for Mimo Pro.
Never a full-strength model. Rules:
https://github.com/popcre/ai-devops/blob/main/templates/system/model-tier-delegation.md

Helper rules: return finished work or an evidenced blocker; make no design
decisions; no merges, pushes or GitHub posts; bring it back to you if any
templates/system/*-global*.md file would change or a doc would contradict the code;
you take it back after 30 minutes stuck.

You yourself: run all three suites, open the PR, wait with bin/ai-pr-wait in the
background, merge, do the protected install from docs/deployment.md on edge-dev3,
do the step 6 live proof, record it under tests/verification/harness-sensors/,
update every STATUS row with an artifact, then tick and close #2835.
```
