---
summary: Plan to add three mechanical Claude Code checks: proof-of-done, repeat-failure stop, destructive-command guard (#2835)
kind: plan
status: open
read-when: Changing ai-completion-check-hook or ai-pr-poll-guard-hook, or work on false "done" claims, agent loops, or destructive git commands
---

# Implementation plan — harness sensors: proof-of-done, repeat-failure stop, destructive-command guard

Issue: [popcre/ai-devops#2835](https://github.com/popcre/ai-devops/issues/2835).
Handoff: [HANDOFF.d/2026-11-25T0358Z-edge-dev3-claude-harness-sensors.md](HANDOFF.d/2026-11-25T0358Z-edge-dev3-claude-harness-sensors.md).
Created 2026-11-24 10:58 PM EST by a Claude session on `edge-dev3`.

## STATUS

| Step | What | State | Evidence |
|---|---|---|---|
| 1 | Capture real hook payload fixtures | ⬜ open | — |
| 0 | Plan reviewed by Codex (gpt-6.2-astra, low), two rounds | ✅ 2026-11-24 | Both rounds' 8 defects applied to steps 2–4 and to sections 10–11; the round-2 fixes were not re-reviewed (two-round cap) |
| 2 | Proof-of-done in the completion hook | ⬜ open | — |
| 3 | Repeat-failure stop | ⬜ open | — |
| 4 | Destructive-command guard | ⬜ open | — |
| 5 | Docs, router, inventory | ⬜ open | — |
| 6 | Install and live proof on edge-dev3 | ⬜ open | — |

**A fresh session starts at step 1.**

---

## Part 1 — Why

### 1. The ultimate goal

Albert, the owner of POP Creations and not a programmer, runs many AI coding
sessions. Three failures keep costing him time and trust:

1. A session says a job is **done** when nothing proved it.
2. A session **gets stuck** running the same failing step again and again.
3. Rarely, a session runs a command that **destroys unsaved work**, sometimes
   another session's.

Rules against all three already exist, but only as written instructions, and
written instructions drift. When this plan is done, the machine itself catches
each failure as it happens, at no model (LLM) cost, and never jams a session.

**If a step conflicts with this goal, the goal wins. Stop and flag it on #2835.**
Two examples. A check that wedges a session or blocks legitimate work breaks the
goal. So does a check that a trivial spelling change gets around.

### 2. What this application is

`popcre/ai-devops` is Albert's AI toolkit: global instructions, skills, wrapper
commands (`bin/ai-*`) and Claude Code hooks. `install.sh` installs them on each
machine (edge-dev, edge-dev3, hetz, and others). Hooks are bash scripts that
Claude Code runs on events (`UserPromptSubmit`, `PreToolUse`, `PostToolUse`,
`Stop`). Each one is copied to `~/.config/ai-devops/<name>` by an installer in
`bin/ai-install-*-hook` and registered in `~/.claude/settings.json`. Branch from
`main`, and PRs merge through the repo's merge queue.

### 3. What triggered this work

On 2026-11-24 Albert shared the X article "Harness Engineering: How to Fix Your
Agent Without Changing the Model" by @0xTrackmind (2026-11-21). Its thesis is
that agent failures are mostly failures of the environment around the model,
and that prose rules should become mechanical checks. Claude, Muse and DeepSeek
debated it against this repo. They agreed the article is sound. They also agreed
on three gaps. A query of the transcript store (`ai-transcript-query`) then
tested each gap (counts only):

- **False "done":** strongly supported. 109 `ai-mistakes` segments match
  "claimed" and 51 match "false claim". Examples are invented test results and
  live sites "confirmed" when they were not.
- **Loops:** strongly supported. There are 1,209 `agent-loop` segments, and 144
  match "repeated". Most are polling or re-verification loops.
- **Destructive commands:** rare but costly. One example is "Git hard-reset
  destroyed another session's uncommitted work". A handful of force-push and
  data-loss segments also exist.
- **Lost state on long jobs:** NOT supported. Zero "lost track" matches, and the
  "compact" hits are unrelated. This was dropped from scope, as section 7 records.

### 4. Scope

**In:** steps 1–6 below, Claude Code only, built by extending the two existing,
installed and tested hooks.

**NOT in this plan:**
- Any LLM judge or second agent that grades "done". The owner closed
  `plan_selective-fresh-reader.md` as "not planned" on 2026-11-02, and reviews
  are advice only (owner ruling 2026-10-29).
- Behavioral evals that measure whether models obey. The owner said "stop
  measuring" on 2026-08-26 (`plan_completion-honesty-enforcement.md`, step 10).
- Codex, ZCode, MiMo or Antigravity parity. Codex had no Stop hook as of
  2026-08-26. Whether codex-cli 0.172 has one is an open question (section 13).
- Trimming the global rulebook. Rule text stays, because non-Claude clients
  still depend on it.
- Progress or checkpoint files for long jobs (no evidence, section 3).
- Changes to CI, merge queue, sweeper or server-side force-pushes. These hooks
  only see Claude's own Bash tool calls.

---

## Part 2 — What we already know

### 5. Current state of the code (main at `03b30efe`)

- `bin/ai-completion-check-hook` (230 lines) is a Stop hook plus per-turn
  tracking.
  - `UserPromptSubmit` prints the New York time and resets
    `~/.local/state/ai-devops/completion-check/actions/<session>` to `no-action`.
  - `PostToolUse` classifies each tool call as `action` or `inspection`. File
    writes count as action, and so do Bash commands matching a regex of git
    writes, test runners and `make` (around line 55). Everything else is
    inspection.
  - `Stop` reads `last_assistant_message`, looks at the closing paragraphs, and
    matches fixed completion phrases ("nothing is pending", "task is complete",
    and so on, around lines 98–110) and future-tense promises.
  - A completion claim gets one nudge per `prompt_id` (lines 123–145). The
    nudge asks the session to check its deliverables, and it fires whether or
    not anything was verified.
  - A promise with no action gets exit 2, a hard block.
  - Any internal error exits 0. It is fail-open by design.
- `tests/test-ai-completion-check-hook.sh` (172 lines, about 56 cases) tests it.
  The CI suite manifest is in `config/ci-suites/`.
- `bin/ai-pr-poll-guard-hook` (73 lines) is a PreToolUse hook for Bash. It
  normalizes Windows shell spellings, drops heredoc bodies and quoted strings,
  and unwraps `bash -c` / `eval`. Then it refuses sleep-plus-PR-read loops with
  exit 2 and a stderr message. `tests/test-ai-pr-poll-guard-hook.sh` (124 lines)
  includes a Windows-spelling parity replay.
- Installers: `bin/ai-install-completion-check-hook` (registers
  `UserPromptSubmit`, `PostToolUse`, `Stop`, and also an Antigravity hook) and
  `bin/ai-install-pr-poll-guard-hook`. Both are called from `install.sh`, line
  641 for the poll guard.
- `config/claude-permissions.allow` has exactly one deny line (line 47,
  `deny:Bash(gh run watch:*)`).
- `skills/shared/two-failed-attempts-diagnosis/SKILL.md` is a skill, not a
  check. It applies only when the session chooses to escalate.
- Nothing in this plan has been started. There is no branch and no code.

### 6. Key findings

- The completion hook is a reminder, not a sensor. It fires on wording, and it
  cannot tell a verified claim from an unverified one. By the article's test
  ("could the evidence have come back red?"), it never comes back red.
- The hook already records per-turn tool activity. A third class,
  `verification`, fits the existing state file with little new code.
- The poll-guard hook already holds the hardest part of a command guard, the
  normalization (Windows spellings, quotes, heredocs, `bash -c`). Destructive
  patterns should reuse it rather than duplicate it.
- The `PostToolUse` payload shape for a failed Bash command is not confirmed
  here. `plan_zcode-windows-support.md:324` lists a `PostToolUseFailure` event
  for ZCode's Claude-compatible hooks. Whether installed Claude Code emits it,
  and which fields carry the exit status and stderr, must be captured (step 1)
  before step 3 is built.

### 7. Approaches considered and REJECTED

- **LLM judge or "fresh reader" agent for done-ness.** Rejected because of the
  owner closure (2026-11-02) and LLM spend. Muse and DeepSeek both argued
  against it, and Claude conceded.
- **Deny lines in `config/claude-permissions.allow`** for `rm -rf`,
  `git push --force` and `git reset --hard`. Muse proposed it. It was rejected
  because permission rules match on command prefix.
  `git -C x reset --hard`, `cd x && git reset --hard` and `bash -c '…'` all get
  around it, and a broad `rm -rf` deny breaks worktree and temp cleanup. A
  tested hook with the poll guard's normalization handles all of these.
- **Trimming the rulebook first.** Muse first proposed it, then conceded. The
  #1881 trim alone drifted back. Convert to checks first, and trim separately.
- **PROGRESS.md / checkpoint log.** Dropped because the transcript store shows
  no evidence for this failure.
- **"Done" meaning `ai-task-gates check` passes on the change set.** DeepSeek
  proposed it. It was not adopted as the done-check, because `ai-task-gates`
  checks the declared task class, not whether the deliverable works. It is still
  listed as one verification command in step 2.
- **A new separate hook script plus installer for each check.** Rejected because
  of the fewest-moving-parts and reuse rules. Extend the two existing installed
  hooks instead.

### 8. Design decisions

**Locked:**
- Every check is deterministic bash, with no model calls. (2026-11-24)
- Every check stays fail-open on internal error (exit 0) and fires at most once
  per prompt where it nudges, so a broken hook never wedges a session.
  (Inherited, 2026-08-26.)
- Proof-of-done and repeat-failure live in `bin/ai-completion-check-hook`. The
  destructive guard and the pre-side of repeat-failure live in
  `bin/ai-pr-poll-guard-hook`. (2026-11-24)
- `--force-with-lease` is allowed. Plain `--force` / `-f` / `+ref` is refused.
- Repeat-failure memory expires after 30 minutes (consistent with the 30-minute
  rule), per session.

**Open (implementer's judgment, criteria given in the steps):**
- The exact verification-command list (step 2).
- How a failed Bash call is detected, whichever field step 1 shows (step 3).

---

## Part 3 — How to build it

### 9. The plan

Work in a fresh worktree branched from `origin/main`. Run
`ai-task-gates start --class code --reason "harness sensors #2835"`.

#### Step 1 — Capture real hook payloads (`lead-only`: it decides what step 3 trusts)

- Add a temporary logging hook in a scratch `CLAUDE_CONFIG_DIR`. Never use the
  live settings. The hook writes stdin to files.
- Run `claude -p` there with prompts that run one succeeding Bash command
  (`true`), one failing one (`false; echo boom >&2; exit 3`), and one Write.
- Save scrubbed payloads (session ids replaced with `FIXTURE`, paths
  generalized) to `tests/fixtures/hooks/claude-posttooluse-bash-ok.json`,
  `…-bash-fail.json`, and `…-failure-event.json` if a `PostToolUseFailure`
  event fires.
- Record in this plan which field carries the exit status and stderr.

**Behaves when done:** the fixtures show exactly how a failed Bash call looks.
**It worked when:** the fixture files exist, and `jq` on the fail fixture
prints a non-zero exit indicator or the failure event name.

#### Step 2 — Proof-of-done (`lead-only`: it changes a hook every session runs)

In `bin/ai-completion-check-hook`:
- **PostToolUse:** add a third state, `verification`. A Bash command is
  verification when it matches a curated regex. Proposed list:
  - test runners that are already action-class (pytest, `bash tests/…`,
    `npm test`, `go test`, `cargo test`, `dotnet test`)
  - any command with ` --check`
  - `ai-task-gates check`
  - `ai-pr-wait`
  - `gh pr checks`
  - `curl` with `-f` / `--fail` or `-w '%{http_code}'`
  - `git diff --exit-code`
  - `ai-adopt-globals --check`

  Judgment rule: include a command only if it exits non-zero or prints a failure
  verdict when the thing is wrong. Exclude bare reads such as `gh pr view`, `cat`
  and `ls`. Match only in **command position**, after normalization: at the
  start of the command or after `;`, `&&`, `||` or `|`. Matching never happens
  inside quoted text or arguments, so `echo --check` and `grep -- --check f` are
  not verification. Reuse the poll guard's normalization function (step 4
  extracts it).
- A verification counts only if its exit status is **its own**. It must be the
  last simple command of the Bash call, or be joined only by `&&` to further
  verifications. It must not be followed by `||`, `;` or `&`, must not be
  inside `if` / `while`, and must not be piped (a pipe masks the exit code
  without `pipefail`). So `pytest || true`, `pytest; echo done` and
  `pytest | tail` never count. (Codex round 2.)
- It also counts only if it **succeeded**, judged by step 1's
  success/failure signal, and **came after the last action** in this prompt.
  Record per-prompt ordinals: `last_action_seq` on every action-class call, and
  `last_ok_verify_seq` on every successful verification. Verified means
  `last_ok_verify_seq > last_action_seq`. A passing test followed by a further
  edit is therefore unverified. Use the existing monotonic-marker technique so
  parallel calls cannot lose an update.
- Known limit, to state in the hook header: a passing check that is unrelated
  to the deliverable still counts. Deterministic code cannot judge relevance.
  That stays the session's duty under the written rule.
- **Stop:** on a completion claim:
  - If verified (as defined above), allow silently. This removes today's noisy
    nudge.
  - If an action ran but no verification, block once with a new reason: "This
    turn changed things and claims completion, but no command that could fail
    checked the result. Run a check (test, --check, HTTP status, CI wait) or say
    plainly what is unverified."
  - If inspection only, keep today's nudge unchanged.
- The future-promise hard block stays unchanged.

**It worked when:** the new test cases in section 10 pass and all existing
cases stay green, run with `bash tests/test-ai-completion-check-hook.sh`.

#### Step 3 — Repeat-failure stop (`lead-only`: depends on step 1's evidence)

Depends on step 1.
- **Post-side, in `bin/ai-completion-check-hook`, on the Bash failure signal
  from step 1:** compute two separate hashes:
  - `cmd_hash = sha256(normalized command)`, with whitespace collapsed
  - `err_hash = sha256(last 3 non-empty stderr lines)`

  Append `epoch cmd_hash err_hash` to
  `~/.local/state/ai-devops/repeat-failure/<session>`.
- **Clearing:** a *successful* run of the same `cmd_hash` deletes that
  command's entries. Any action-class call (a file Write/Edit, or a git write)
  also clears the whole session file, because the session changed something and
  a retry after a repair is legitimate.
- If step 1 shows failures arrive as a separate `PostToolUseFailure` event,
  register it for the **Claude client only**. That is the `~/.claude/settings.json`
  branch of `bin/ai-install-completion-check-hook`, from line 224 onward. **Do
  not touch the ZCode branch (lines 153–220) or the Antigravity branch.** Keep
  `--check` support, matching the existing three events.
- **Pre-side, in `bin/ai-pr-poll-guard-hook`:** before the existing checks,
  compute `cmd_hash` of the incoming normalized command, the same way. If the
  session file holds at least 2 entries for that `cmd_hash` within the last 30
  minutes **with the same `err_hash`**, refuse with exit 2 and this message:
  "This exact command already failed twice with the same error in the last 30
  minutes. Change the approach; if two real attempts failed, use the
  two-failed-attempts-diagnosis skill." Prune entries older than 30 minutes on
  every read.
- A different command, or the same command whose earlier failures had different
  errors, is allowed.

**It worked when:** the step 3 test cases pass in both suites.

#### Step 4 — Destructive-command guard (`lead-only`: a trust-boundary parser)

In `bin/ai-pr-poll-guard-hook`, refuse with exit 2 and a message that names the
safe alternative.

**Parsing order matters.** The existing pipeline drops quoted strings, which
would erase `"$HOME"`, `"$TMPDIR/x"` and quoted `-C` directories, so the guard
cannot run on its output.

1. Extract the shared normalization, shell-name rewriting, heredoc-body drop and
   `bash -c` / `eval` unwrap, into a function used by both the poll rules and
   this guard.
2. Run the destructive guard on that output **before** quote-dropping. Split it
   into simple commands on `;`, `&&`, `||` and `|`, and then into words with
   quotes **preserved**. Strip only the outer quote characters from each word,
   and keep the word.
3. Drop the argument of `-m`, `--message` and `-F` for git commit/tag, and drop
   `echo` / `printf` arguments, so a message that only mentions a command passes.
4. Walk simple commands in order, keeping a current directory. It starts as the
   payload `.cwd`, and `cd <word>` updates it (relative to the current one). A
   `-C <word>` on a git command overrides it for that command only. A
   directory containing `$(`, a backtick or an unexpanded variable other than
   `$HOME` / `$TMPDIR` cannot be determined, which means refuse.
5. Expand `~`, `$HOME` and `$TMPDIR` in `rm` targets before matching, so
   `"$HOME"` is seen as the home directory and `"$TMPDIR/x"` as a temp path.
   Track each word's quote type. Expand only unquoted or double-quoted words,
   never single-quoted ones (`rm -rf '$HOME'` names a literal file, so it
   passes).

Refuse:

- **`git … reset --hard`** when the target tree has uncommitted changes. Find
  the target from `-C <dir>`, a preceding `cd <dir> &&`, or the payload `.cwd`,
  then run `git -C <dir> status --porcelain`. An empty result means it is
  allowed. Fail-safe: if the directory cannot be determined, refuse.
  Alternative to name: a temporary WIP commit.
- **`git checkout -- .`, `git checkout .`, `git restore .`** without
  `--staged`, under the same dirty-tree rule.
- **`git clean -f…`**: `status --porcelain` hides ignored files, so it is not
  enough here. Run `git -C <dir> clean -n` with the same `-d` / `-x` / `-X`
  flags and paths. A non-empty dry-run list means refuse. (Codex round 2.)
- **`git push`** with `--force`, `-f`, or a `+refspec`. `--force-with-lease`
  passes.
- **`git push`** whose explicit refspec targets `main` or `master`. The
  alternative to name is to branch and open a PR.
- **`rm`** with recursive and force flags in any spelling (`-rf`, `-fr`,
  `-r -f`, `--recursive --force`) when a target is `/`, `~`, `$HOME`, `*`, `.`,
  `..`, or a path ending in `/.git`. Other `rm -rf` targets pass, including
  worktree and temp cleanup.
- Bare `git stash` / `git stash pop` (the shared-stash rule from the
  environment) is **not** included. It is a prose rule, the rule is rarely
  broken, and it is out of scope.

**It worked when:** every row of the adversarial table in section 10 has a
passing named test.

#### Step 5 — Docs (`helper-ok`: file edits named exactly)

- Update the header comments of both hooks.
- Add one line per check to `docs/config-inventory.md` (the Claude hooks
  entry).
- (Router row in `AGENTS.md` already added with the plan.)
- Add a memory entry `harness-sensors.md` that says "read the plan STATUS
  first".
- **Stop-and-ask trigger:** any wording change to `templates/system/*-global*.md`
  goes back to the lead. Those files have a parity audit
  (`tools/context-audit/context-audit.py`).

**It worked when:** `bash tests/test-doc-health.sh`, or the repo's docs check
named in `config/ci-suites/`, passes.

#### Step 6 — Install and live proof (`lead-only`: live-proof judgment)

- After merge, run `bash install.sh` on edge-dev3 from the installed checkout.
  This follows the "worktree agents cannot install" memory, so the coordinator
  installs. Confirm with `ai-install-completion-check-hook --check` and
  `ai-install-pr-poll-guard-hook --check`.
- Live: in a scratch git repo with an uncommitted change, run `claude -p` asking
  it to run `git reset --hard`. The command must be refused, and the file must
  still be modified.
- Then ask it to run `false` with the same error three times. The third attempt
  must be refused.
- Then ask it to edit a file and end with "task is complete" without testing.
  Stop must block once with the new reason.
- Record the outputs in `tests/verification/harness-sensors/2026-11-XX-live.md`.

**It worked when:** that file exists, showing all three refusals, and the
`- [ ] Live proof` box on #2835 is ticked, citing it.

Phases: one session should finish steps 1–5. Step 6 needs the merge. A natural
cut point is after the merge.

### 10. Tests required

In `tests/test-ai-completion-check-hook.sh`:
- `verification command then claim → silent`
- `write action, no verification, claim → blocks once with the "no command that could fail" reason`
- `inspection only, claim → old nudge text`
- `verification marker survives a later parallel inspection call`
- `gh pr view is not verification`
- `failed Bash call appends a repeat-failure entry (step 1 fixture)`
- `successful Bash call appends nothing`

In `tests/test-ai-pr-poll-guard-hook.sh`:
- `third identical failing command within 30 min → exit 2`
- `same command, different stderr → allowed`
- `entries older than 30 min are pruned → allowed`
- all of the adversarial rows below
- the existing Windows-spelling parity replay, extended automatically to the new
  `bash -c` cases
- `echo --check then claim → not verified` and `grep -- --check then claim → not verified`
- `passing test, then an Edit, then claim → blocks (verification older than last action)`
- `failing test then claim → blocks (only a successful verification counts)`
- `two failures, then an Edit, then the same command → allowed (repair clears)`
- `two failures, then a success of the same command, then a failure → allowed`
- installer: `--client zcode` output and config are byte-identical before and after the change
- `pytest || true`, `pytest; echo ok` and `pytest | tail` then claim → not verified
- hook without `--sensors` (the ZCode path) → today's outputs on every existing case
- installer upgrades an old Claude registration to `--sensors`, and `--check` shows DRIFT before and OK after

**Adversarial cases (step 4; external input = the command string the model
writes):**

| Input | Hostile or edge case | Expected | Test name |
|---|---|---|---|
| `git reset --hard` | dirty tree | refuse | `reset-hard dirty refused` |
| `git reset --hard` | clean tree | allow | `reset-hard clean allowed` |
| `git -C /x reset --hard` | dirty `/x`, cwd clean | refuse | `reset-hard -C dirty refused` |
| `cd /x && git reset --hard` | dirty `/x` | refuse | `reset-hard after cd refused` |
| `bash -c 'git reset --hard'` | dirty | refuse | `reset-hard in bash -c refused` |
| `git commit -m "undo git reset --hard"` | text only | allow | `reset-hard in message allowed` |
| heredoc body mentions `git push --force` | text only | allow | `force in heredoc allowed` |
| `git push -f origin b` | force | refuse | `push -f refused` |
| `git push origin +b` | plus refspec | refuse | `push plus refspec refused` |
| `git push --force-with-lease origin b` | lease | allow | `push lease allowed` |
| `git push origin HEAD:main` | main target | refuse | `push to main refused` |
| `git push origin feature/main-fix` | name contains main | allow | `push main-substring allowed` |
| `rm -rf /`, `rm -fr ~`, `rm -r -f "$HOME"` | root/home | refuse | `rm root/home spellings refused` |
| `rm -rf "$TMPDIR/x"`, `rm -rf .claude/worktrees/old` | cleanup | allow | `rm cleanup allowed` |
| `rm -rf repo/.git` | git dir | refuse | `rm .git refused` |
| `rm -rf "$HOME"` | quoted home | refuse | `rm quoted home refused` |
| `git -C "/x y" reset --hard` | quoted dir with space, dirty | refuse | `reset-hard quoted -C refused` |
| `cd /x && cd sub && git reset --hard` | chained cd, dirty `/x/sub` | refuse | `reset-hard chained cd refused` |
| `cd /dirty && git -C /clean reset --hard` | `-C` overrides cd | allow | `reset-hard -C overrides cd` |
| `GIT.EXE reset --hard` (Windows spelling) | dirty | refuse | `parity replay` |
| `git clean -fdx` | dirty | refuse | `clean -f dirty refused` |
| `git clean -fdx` | only ignored files present (status clean) | refuse | `clean -x ignored-only refused` |
| `git clean -fd` | only ignored files present | allow | `clean -d ignored-only allowed` |
| `rm -rf '$HOME'` | single-quoted literal | allow | `rm single-quoted literal allowed` |
| `git restore --staged .` | unstage only | allow | `restore staged allowed` |
| target dir not determinable (`cd "$(…)" && git reset --hard`) | unknown | refuse | `reset-hard unknown dir refused` |

Tests must use real temporary git repos for dirty or clean trees, under
`$TMPDIR`, never the repo itself. Full suites that must stay green:
`bash tests/test-ai-completion-check-hook.sh`,
`bash tests/test-ai-pr-poll-guard-hook.sh`, and
`bash tests/test-ai-claude-permissions.sh`.

### 11. Constraints, standing rules, gotchas

- Never push to `main` directly. Branch, open a PR, and the AI merges it.
  Albert never merges.
- Commit as `git var GIT_COMMITTER_IDENT`, staging only your own files.
- Sign GitHub posts with `$AI_GH_SIGNATURE`.
- Keep the hooks fail-open (exit 0) on every internal error, including a
  missing `jq`. This is the opposite of the destructive guard's "unknown dir →
  refuse". That refusal is a deliberate verdict, not an internal error.
- Each hook runs on every tool call, so keep it fast: no network, and at most
  one `git status` per call, only when a reset/checkout/clean pattern matched.
- CRLF breaks bash scripts on Windows (memory
  `windows-crlf-breaks-bash-scripts`). Keep LF line endings.
- On Windows the payload may carry `C:\…` paths. The `-C` / `cd` extraction must
  accept them. Add a test if you touch path parsing.
- Never weaken the existing poll rules or their tests.
- No automated wait longer than 30 minutes, anywhere.
- `bin/ai-completion-check-hook` is also installed for ZCode (`--client zcode`).
  ZCode sends Claude-compatible fields, so shared code would silently change
  ZCode's behavior. **The new behaviors of steps 2 and 3 are enabled only by an
  explicit flag.** The Claude registration's command gains `--sensors`. The
  installer's Claude branch upgrades an existing registration in place, matched
  by its marker, and `--check` reports `DRIFT` until it has. The ZCode and
  Antigravity registrations stay unchanged. Without the flag, the hook behaves
  exactly as today. Test this by running the ZCode fixtures without `--sensors`
  and asserting today's outputs. (Codex second opinion, both rounds.)

### 12. Access and environment

- Machine: `edge-dev3` (Ubuntu). `gh` is authenticated as `u2giants`, and
  `claude` and `jq` are on PATH.
- Installed checkout is at `/home/ahazan/repos/ai-devops`. Work in a worktree
  under `.claude/worktrees/`.
- No secrets are needed.

### 13. Definition of done, risks, open questions

**Done:** steps 1–6 ✅, with every STATUS row citing an artifact. The PR is
merged with CI green (`bin/ai-pr-wait <pr>` in the background), the hooks are
installed on edge-dev3 with `--check` clean, the live-proof file exists, and
#2835's boxes are ticked and closed.

**Risks and rollback:**
- A false refusal that blocks legitimate work. The rollback is to revert the PR
  and rerun `install.sh`, which recopies the hook.
- The proof-of-done block annoying pure-answer turns. That is mitigated because
  inspection-only turns keep the old behavior.

**Open questions:**
- Does codex-cli 0.172 support Stop or PreToolUse hooks? If yes, propose
  parity on #2835 as a later checklist item. Do not build it here.
- Should other machines (edge-dev, hetz) be installed in the same pass? The
  default is no: they pick it up on their next `sync-dotfiles`.

---

## Self-audit (2026-11-24)

1. *Could a brand-new session execute this without asking?* Yes. Section 5
   gives exact files and lines, section 9 gives the behavior and gate for each
   step, and section 10 names every test. The one unknown, the failure payload,
   is turned into step 1 with a concrete capture method rather than left as a
   guess.
2. *Does it carry the background and what was ruled out?* Yes. Section 3 gives
   the transcript evidence, section 7 lists six rejected approaches with
   reasons, and section 4 states the owner closures (fresh reader, "stop
   measuring").
3. *Is the goal clear enough for judgment calls?* Yes. Section 1 states the
   three failures in plain words, plus the two concrete ways a step can violate
   the goal (wedging a session, being trivially bypassed).

## Lead launch prompt

```text
You are the lead session for popcre/ai-devops issue #2835. Read plan_harness-sensors.md
in full, starting with its STATUS table; it is the whole brief. Do not re-plan or
reopen the locked decisions in section 8.

Do steps 1, 2, 3, 4 and 6 yourself (all lead-only), in that order; step 3 needs
step 1's fixtures. Step 5 (docs) may go to your helper after step 4 lands in your
branch. Your helper is your own tool's smaller model: Haiku (high effort) for
Claude Opus, Luna (high) for Sol, GLM Flash for GLM MAX, Mimo Flash for Mimo Pro.
Never a full-strength model. Rules:
https://github.com/popcre/ai-devops/blob/main/templates/system/model-tier-delegation.md

Helper rules: return finished work or an evidenced blocker; make no design
decisions; no merges, pushes or GitHub posts; stop and bring it back to you if any
global template (templates/system/*-global*.md) would change; you take it back
after 30 minutes stuck.

You yourself: run both hook suites and tests/test-ai-claude-permissions.sh, open
the PR, wait with bin/ai-pr-wait in the background, merge, install on edge-dev3,
do the step 6 live proof, record it under tests/verification/harness-sensors/,
update every STATUS row with an artifact, tick and close #2835.
```
