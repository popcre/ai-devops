# Implementation plan: BlockerWatch parks waiting work as searchable issues and restarts it even after cleanup

Written 2026-09-18 on machine `edge-dev` by a Claude Opus 5 session, for a
cheaper implementing model (Sonnet-class). Repo `popcre/ai-devops`, based on
`main` at `3adfeee2`.

- Live owner issue: [popcre/ai-devops#617](https://github.com/popcre/ai-devops/issues/617)
- Companion handoff (links back here): [`HANDOFF.d/2026-09-18T1830Z-edge-dev-claude-blockerwatch-parked-work-plan.md`](HANDOFF.d/2026-09-18T1830Z-edge-dev-claude-blockerwatch-parked-work-plan.md)

---

## STATUS

Read this table first. Do not re-derive it, and do not re-plan from chat.

| # | Step | Status | Evidence (an artifact, never a bare number) |
|---|---|---|---|
| 1 | Config: `harness_fresh`, `transcript_glob`, `parked_label`, `resumed_label` | ⬜ open | — |
| 2 | `wait`: require a brief, create or mark the parked issue, record the main checkout | ⬜ open | — |
| 3 | `wake`: decide resume or fresh start; fresh start from the parked issue | ⬜ open | — |
| 4 | `wake`: report the outcome on the parked issue and swap its label | ⬜ open | — |
| 5 | `find` command: plain-language search of parked work | ⬜ open | — |
| 6 | `list` shows the parked issue | ⬜ open | — |
| 7 | Tests in `tests/test-ai-blocker-watch.sh` | ⬜ open | — |
| 8 | Globals, router, and help text teach the new `wait` | ⬜ open | — |
| 9 | PR, CI green, merge, pull the shared checkout on edge-dev | ⬜ open | — |
| 10 | Live proof: one real park and one fresh start | ⬜ open | — |

**A fresh session starts at step 1.** Steps 1–8 fit in one session and land as
one pull request. Step 10 is the single live proof, and it is owned by #617.

---

## Part 1 — Why

### 1. The ultimate goal

Albert Hazan owns POP Creations and is not a programmer. He runs 80–90 AI chat
sessions at once in Claude, Codex, and ZCode. When a session needs a
database-structure change, it opens a ticket for the shared-db **orchestrator**,
a separate long-running session that governs every database change. It then
waits. Those tickets take one to two weeks. By then:

1. Albert cannot find the waiting session in his list, and has forgotten that
   anything was waiting; or
2. a periodic cleanup of branches and worktrees has deleted the folder the
   session lived in, so the session cannot be resumed at all.

Either way the work is abandoned.

**What will be true when this is done:** waiting work lives in a GitHub issue,
not in a chat session or a folder. Each waiting session leaves a **parked
issue**. It has a plain-English title and summary, what was done, the exact next
steps, and what it waits on. When the blocker closes, BlockerWatch
continues the work by itself. It resumes the old session if it still exists,
and otherwise starts a **fresh session** that reads the parked issue and carries
on. Albert never has to remember anything. Two weeks later he can ask any
session something like *"show me the issues related to improving the extraction
of a product's specific description from the full description"*, and the
parked issue comes up in plain words.

**If a step in this plan conflicts with this goal, the goal wins. Stop and
flag the conflict on #617. Do not quietly follow the letter of the step.**

### 2. What this application is

`popcre/ai-devops` is Albert's machine-setup and AI-workflow repository:
installers, global instructions for Claude/Codex/ZCode, skills, and helper
commands in `bin/`. Nothing here is a deployed web app. "Installing" means
copying or linking onto each agent machine: `install.sh` on Linux and Git
Bash, and `bin/install-ai-devops-windows.ps1` on Windows.

**BlockerWatch** is `bin/ai-blocker-watch`, a ~555-line Bash script. It was built
in #546 and extended in #549/#550. The owner fixed the name "BlockerWatch" on
2026-09-18. Its settings are in `config/blocker-watch.json` and its offline
tests in `tests/test-ai-blocker-watch.sh`. It runs every 10 minutes on every
agent machine, via Task Scheduler (`ai-devops\blocker-watch`) on Windows or the
user crontab on Linux. Today it does three things:

1. **Propagation** — when an issue closes, it comments on every open issue it
   was blocking (GitHub's native "blocked by" dependency). This runs on one
   machine only, `propagate_on_host` = `edge-dev`.
2. **Wake** — a session that ran `ai-blocker-watch wait` is resumed headlessly
   with `claude -p --resume <id>`, `codex exec resume <id>`, or
   `zcode.cjs --resume <id>` once its blocker closes. The wait records live as
   JSON files in `~/.ai-devops/blocker-watch/waits/` on that machine.
3. **Unowned-blocker alarm** — a daily digest issue listing blockers nobody owns.

Machines: `edge-dev` (Windows, this machine, the propagating host), plus others
listed in `templates/system/machine-atlas.md`. Read only the current machine's
section.

### 3. What triggered this work

Albert, in chat on 2026-09-18, described exactly the two failures in §1.
He asked for each session to be tied to a ticket that stays open and updated
without depending on worktrees, branches, or his memory. He then asked for it
to be built into BlockerWatch, and asked for a natural-language description
so that the plain-English search in §1 works.

He also corrected the planner on one point: nothing *tells* a session it is
blocked. The session decides for itself that it needs something from the
orchestrator, opens that ticket, and then waits. So the hook point is the
session's own `ai-blocker-watch wait` call. Nothing on the orchestrator side
needs to change.

**Reproduce the failure today.** Register a wait from a worktree, delete the
worktree, and close the blocker. `wake()` does `cd "$cwd"`
(`bin/ai-blocker-watch:269`), which fails, so the wait is retried until
`max_wake_attempts` and then parks in state `failed`. Nothing records what the
session was doing.

### 4. Scope

**In this plan:**
- `wait` gains a required resume brief and creates (or marks) a parked issue.
- `wake` falls back to a fresh session when the old session or folder is gone.
- `wake` writes the outcome onto the parked issue.
- New `find` command, and `list` shows parked issues.
- Tests, help text, the three global instruction templates, and the router row.

**NOT in this plan (do not build):**
- Any change to the shared-db orchestrator, its skills, or `u2giants/shared-db`.
- Moving wait records off the local machine, or letting machine B wake a session
  registered on machine A. A wait still wakes only on the machine that
  registered it.
- Migrating existing waits. Old records with no `parked_issue` keep today's
  behaviour, plus the one "orphaned" rule in step 3.
- Claude desktop sidebar integration (renaming or pinning sessions).
- A dashboard web page. The GitHub label list *is* the dashboard.
- Changing the alarm, propagation, scheduling, or the harness resume commands.

---

## Part 2 — What we already know

### 5. Current state of the code

Everything below is on `main` at `3adfeee2`. Nothing for this plan is started.

- `cmd_wait` — `bin/ai-blocker-watch:102-134`. It parses `--for/--note/--harness/
  --session/--cwd`, detects the harness from `ZCODE_SESSION_ID`,
  `CODEX_THREAD_ID`, or `CLAUDE_CODE_SESSION_ID` (in that order, lines
  117-122), calls `link` when `--for` is given, and writes
  `waits/<id>.json` with the fields
  `{id, blocker, for, note, harness, session, cwd, registered_at, state:"waiting", attempts:0}`.
- `wake` — lines 209-280. It reads the blocker state (line 213) and returns
  if the blocker is not closed. It builds the prompt (217-220) and builds the command from
  `.harness[$h]` with `{session} {cwd} {prompt} {home} {zcode_builtin}`
  substitution (225-230). It checks the program exists (237-263), and if not
  marks the wait `unrunnable`. It then runs `(cd "$cwd" && timeout … "${cmd[@]}")`
  (269) and sets `woken`, `waiting` (retry), or `failed`.
- `cmd_tick` — lines 490-502. It calls `wake` for each wait in state `waiting`.
- `cmd_list` — lines 136-141. It prints `id state blocker harness for` as TSV.
- Help text is lines 2-59, printed by `--help` via `sed -n '2,59p'` (line 553).
  **If you add help lines, update that range.**
- Config `config/blocker-watch.json` — keys listed in §1 above. `harness.*` are
  argument arrays.
- Tests — `tests/test-ai-blocker-watch.sh`, 204 lines, a fully offline test
  file. `$TMP/gh` is a fake GitHub CLI that pattern-matches `$*` (lines
  11-35). It already answers `issue create` (it prints
  `https://github.com/o/r/issues/31`), `issue comment`, `issue edit`, and
  `search issues`. `$TMP/harness` is a fake harness that appends
  `$PWD|$*` to `$FAKE/resumed` (lines 37-40). The fixture config is built
  with `jq` at line 45. The file ends with the pass/fail summary on its last line.
  The suite is registered in `config/ci-suite-manifest.json:89`.
- Global instructions that teach `wait`:
  `templates/system/CLAUDE-global.md:346-350`,
  `templates/system/AGENTS-global-codex.md:228`,
  `templates/system/AGENTS-global-zcode.md:229`.
- Router row: `docs/task-router.md:44` (the **BlockerWatch** row).

### 6. Key findings and root cause

- **Why sessions die after cleanup.** Claude stores a session's transcript under
  `~/.claude/projects/<cwd with separators turned into '-'>/<session-id>.jsonl`.
  An example directory name on this machine is
  `C--repos-ai-devops--claude-worktrees-<name>`. Codex stores transcripts under
  `~/.codex/sessions/YYYY/MM/DD/*<thread-id>*.jsonl`. When the worktree is
  deleted, the `cd "$cwd"` at line 269 fails. For Claude, cleanup may also
  remove the project transcript folder, so `--resume` has nothing to load. The
  wait has only a one-line `--note`. **Nothing durable says what the work
  was**, so the work cannot be restarted even by hand. That is the root cause.
- **Why Albert loses track.** The only record is the local JSON file and the
  chat session itself. GitHub has the "blocked by" link, but on the *work*
  issue, if there is one. Many sessions never open one, so there is nothing
  searchable.
- `gh search issues` accepts `--owner` more than once and `--label`, and it
  searches title and body text. That is enough for plain-language lookup,
  because GitHub search matches words, not meaning. So the parked issue
  **must** repeat the key nouns in its title and its first paragraph (see step 2).
- The fake `gh` already returns issue URL `…/issues/31` for any `issue create`.
  Tests can assert on that number.

### 7. Approaches considered and REJECTED

- **Keep resuming the exact old session only (today's design).** This is
  exactly what breaks after cleanup. Rejected as the *only* path. It is kept
  as the first choice when the session still exists, because the old session
  holds the most context.
- **Store the resume brief only in the local wait JSON.** It is not searchable,
  not visible to Albert, and lost if the machine is rebuilt. Rejected: the brief
  lives on GitHub.
- **Put every parked issue in `popcre/ai-devops`.** It is easy to find, but it
  separates the work from its repository, and the fresh session would not know
  which checkout to use. Rejected: the parked issue lives in the repository the
  work belongs to. Search spans both owners (`u2giants`, `popcre`).
- **Have the fresh session run in the old worktree path, recreated.** It would
  recreate stale branches and fight the global rule that each task starts in its
  own worktree from current upstream. Rejected: the fresh session starts in the
  repository's **main checkout** and makes its own worktree, as the global rules
  already require.
- **Semantic or embedding search for `find`.** Overkill. Plain-English titles plus
  GitHub full-text search meet the need. Rejected for now. Revisit only if
  real searches miss.
- **Change the orchestrator to notify sessions.** Albert confirmed the session
  itself decides it is blocked, and BlockerWatch already propagates closes.
  Rejected as out of scope.

### 8. Design decisions

**Locked (do not relitigate):**
1. (2026-09-18) The parked issue is the unit of waiting work, not the session.
2. (2026-09-18) `wait` **refuses** to register without a resume brief, which is
   `--brief-file PATH`. A wait with no brief is exactly the failure we are fixing.
3. (2026-09-18) Parked-issue location:
   - If `--for owner/repo#M` is given, M **is** the parked issue. Post the brief
     as a comment and add the parked label.
   - Else `--park "<plain-English title>"` is required. Create a new issue in the
     repository of the current checkout (`gh repo view --json nameWithOwner` run
     in `--cwd`). Link it as blocked by the blocker.
   - Neither given → refuse with a clear message.
4. (2026-09-18) The label is `parked` while waiting and `resumed` after a wake.
   The names are configurable in the config, never hard-coded in the script.
5. (2026-09-18) Wake order: resume the old session if its folder **and** its
   transcript still exist, else start a fresh session in the recorded main
   checkout. If neither is possible, mark the wait `orphaned`, comment on the
   parked issue, and exit non-zero for that tick.
6. (2026-09-18) The fresh session's prompt points at the parked issue URL and
   tells it to read the whole issue, make its own worktree from current upstream,
   and write results back onto the issue.
7. (2026-09-18) Every wake writes one comment on the parked issue. It says what
   closed, which mode (resumed or fresh), the machine, and the log path. A
   hidden marker `<!-- ai-blocker-watch:woke:<wait-id> -->` stops it being
   posted twice.
8. The script stays Bash + `jq` + `ai-gh`, matching the existing file. No new
   language or dependency.

**Open (implementer's judgment, with criteria):**
- Exact wording of prompts and comments. Criteria: plain English, and the fresh
  prompt must be enough on its own for a session that knows nothing.
- Whether `find` also accepts `--all` to include closed issues. Criteria: add it
  if it costs under ~10 lines.
- Label colours.

---

## Part 3 — How to build it

Work in your own worktree from current `origin/main` on a new branch, for
example `claude/blockerwatch-parked-work`. Run `git var GIT_COMMITTER_IDENT`
before the first commit. It must print
`Albert Hazan <u2giants@users.noreply.github.com>`.

### 9. Steps

#### Step 1 — Config keys
File: `config/blocker-watch.json`.
- Add `"parked_label": "parked"`, `"resumed_label": "resumed"`.
- Add `"harness_fresh"`, an object with the same three keys as `harness`. It
  holds the argument arrays that start a **new** headless session with
  `{prompt}` (and `{cwd}` for ZCode):
  - claude: `["claude","-p","--permission-mode","bypassPermissions","{prompt}"]`
  - codex: `["codex","exec","--dangerously-bypass-approvals-and-sandbox","{prompt}"]`
  - zcode: copy the `harness.zcode` array, but **remove** the two elements
    `"--resume","{session}"`.
- Add `"transcript_glob"`, the path pattern proving a session still exists, with `{home}`
  and `{session}` substituted:
  - claude: `"{home}/.claude/projects/*/{session}.jsonl"`
  - codex: `"{home}/.codex/sessions/*/*/*/*{session}*.jsonl"`
  - zcode: `""`. Empty means only the folder is checked, because ZCode's
    transcript location is not established. Do not guess one.
- Extend `_comment` with one sentence for each new key.

Done when `jq -e '.harness_fresh|has("claude") and has("codex") and has("zcode")' config/blocker-watch.json` exits 0.

#### Step 2 — `wait` creates or marks the parked issue
File: `bin/ai-blocker-watch`, `cmd_wait` (lines 102-134).
1. Add the options `--brief-file PATH` (required) and `--park TITLE`.
2. Validation, before any GitHub call:
   - `--brief-file` missing or the file empty → `die "a wait needs --brief-file: what this work is, what is done, the exact next steps"`.
   - Neither `--for` nor `--park` → `die "name the parked issue: --for owner/repo#M, or --park \"plain-English title\""`.
3. Record the **main checkout**:
   `main="$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"`,
   then strip a trailing `/.git`, then `cygpath -m` when available (the same as line 125).
   If `cwd` is not in a Git repository, leave `main` empty. The fresh start will then be impossible, which step 3 handles.
4. Compose the parked text in a temp file under `$HOME_DIR`:
   ```
   <!-- ai-blocker-watch:parked -->
   ## What this is about
   <first paragraph of the brief file>

   ## Waiting on
   <blocker ref> — <blocker title, read with gh_api repos/R/issues/N --jq .title>

   ## Resume brief
   <the whole brief file>

   ## Record
   Machine <hostname>, <harness> session <session>, main checkout <main>, registered <now_iso>.
   owner: ai-blocker-watch — continues this automatically when the blocker closes.
   ```
   The `owner:` line matters: it keeps the unowned-blocker alarm from flagging
   the parked issue (see `alarm_scan` line 374).
5. If `--park`: `"$GH" issue create -R <repo> -t "$park" --body-file <tmp> --label <parked_label>`.
   Take the number from the returned URL's last path segment. Then run
   `link "<repo>#<num>" "$ref"`.
   The repo comes from `(cd "$cwd" && "$GH" repo view --json nameWithOwner --jq .nameWithOwner)`.
   If `--for`: run `"$GH" issue comment <M> -R <repo> --body-file <tmp>` and
   `"$GH" issue edit <M> -R <repo> --add-label <parked_label>`, keeping the
   existing `link` call.
   **Label missing on the repo:** before either path, run
   `"$GH" label create <parked_label> -R <repo> --color FBCA04 --description "Waiting on a blocker; BlockerWatch resumes it" 2>/dev/null || true`
   and the same for `resumed_label` (color 0E8A16). "Already exists" is fine.
6. Add `parked_issue` (`owner/repo#N`), `parked_url`, and `main_checkout` to the JSON record.
7. Print the wait id (unchanged), and also note `parked as <url>`.
8. Any GitHub failure in steps 5-6 → `die`, with **no** local wait file written.
   Never leave a half-registered wait.

Done when a test run shows `issue create … --label parked` in the fake call log
and the wait JSON has `parked_issue == "o/r#31"`.

#### Step 3 — `wake` picks resume, fresh, or orphaned
File: `bin/ai-blocker-watch`, `wake` (lines 209-280). Keep the existing blocker
check and the `unrunnable` check.
1. After confirming the blocker is closed, decide the mode:
   - `resumable` if `[ -d "$cwd" ]` **and** (the `transcript_glob[$h]` is empty
     **or** `compgen -G "<expanded glob>" >/dev/null`).
   - else `fresh` if `main_checkout` is non-empty, `[ -d main_checkout ]`,
     `parked_url` is non-empty, and `harness_fresh[$h]` exists.
   - else `orphaned`: set `.state="orphaned"`, and comment on `parked_issue` (or
     on `.for` for old records) saying the session and folder are gone and a
     person must restart it from the issue. Set `FAILED=1` and return. A later
     tick skips it, because only `waiting` records are woken.
2. `resumable` → today's path, unchanged.
3. `fresh` → build the command from `.harness_fresh[$h]` with the same
   substitution loop. Use `cwd=$main_checkout` and this prompt (adapt the wording, keep every element):
   > ai-blocker-watch: you are a NEW session picking up parked work. Blocker
   > <ref> ("<title>") has closed. The full brief is in <parked_url>. Read that
   > issue and all its comments first (`gh issue view <N> -R <repo> --comments`).
   > Follow the repository's AGENTS.md. Create your own worktree from current
   > upstream before editing. Continue the next steps from the brief. When you finish, or
   > are blocked again, comment on the issue with the result. If blocked
   > again, register a new wait with
   > `ai-blocker-watch wait <blocker> --for <this issue> --brief-file <file>`.
4. The prompt must be passed as one argument, exactly like `{prompt}` today.
5. Record `.mode="resumed"|"fresh"` in the JSON alongside `woken_at`.

Done when the tests in step 7 for all three modes pass.

#### Step 4 — Write the outcome onto the parked issue
Still inside `wake`, after the harness command returns (success **or** final failure):
- Skip this step when there is no `parked_issue`, for old records.
- Check first for the marker `<!-- ai-blocker-watch:woke:<wait-id> -->`, using
  `gh_api repos/R/issues/N/comments --jq '.[].body'` and `grep -qF`. If it is
  present, do not post.
- Comment: `Blocker <ref> closed. <Resumed the original|Started a fresh> <harness> session on <hostname> (exit <rc>). Log: <log path>.`
  On final failure, add: `It failed <attempts> times. A person must restart it from this issue.`
- On success, `issue edit N -R R --remove-label <parked> --add-label <resumed>`.
- A failure to comment sets `FAILED=1` but does not change the wait state.

Done when the fake call log shows exactly one `issue comment 31` and one
`issue edit 31 … --add-label resumed` per wake, and none on a second tick.

#### Step 5 — `find`
Add `find) shift; cmd_find "$@" ;;` to the dispatch `case` (line 544+).
`cmd_find <words…> [--all]` runs:
`"$GH" search issues "<words>" --owner u2giants --owner popcre --label <parked_label> [--state open] --json repository,number,title,state,updatedAt,url --limit 30`.
Without `--all`, search both the parked and resumed labels. Use two calls, because
`gh search` combines labels with AND. Merge and de-duplicate by url with `jq`.
Print `repo#N  state  updated  title` lines, newest first, and print
`no parked work matches "<words>"` when empty. The owners list comes from a new
config key `"find_owners": ["u2giants","popcre"]`. Do not hard-code it.

Done when `ai-blocker-watch find description extraction` against the fake gh
prints the fixture issue.

#### Step 6 — `list` shows the parked issue
In `cmd_list`, append `(.parked_issue // "")` as a sixth TSV column. Done when
the test asserts the column.

#### Step 7 — Tests (see §10 for the exact list)
File: `tests/test-ai-blocker-watch.sh`. Add a section **before** the final
summary line. Extend the fake `gh` `case` so these answer sensibly:
`label create*` (exit 0), `repo view*` (prints `o/r`), `*issues/31/comments*`
(prints `$FAKE/comments31.json` or `[]`), and `search issues*` for find (prints
`$FAKE/find.json`). The existing digest search also uses `search issues`, so
match the find call by `--label`. **Existing waits in the file were registered
without `--brief-file`.** Update those `BW wait` calls (lines ~47-52) to pass
`--brief-file "$TMP/brief.md"` and `--for`, or they will now fail.

#### Step 8 — Teach it
- Help text, lines 2-59: document `--brief-file`, `--park`, `find`, the three
  wake modes, and labels. Then **fix the `sed -n '2,59p'` range** at line 553 to
  the new last header line.
- `templates/system/CLAUDE-global.md:346-350`,
  `templates/system/AGENTS-global-codex.md:228`, and
  `templates/system/AGENTS-global-zcode.md:229`: replace the command with
  `ai-blocker-watch wait <owner/repo#N> --for <owner/repo#M> --brief-file <file>`
  (or `--park "<plain-English title>"` when there is no work issue). Add one
  sentence: the brief says, in plain English, what the work is, what is done,
  and the exact next steps, because a fresh session may continue it from the
  issue alone. Keep the three texts identical in meaning.
- `docs/task-router.md:44`: add the parked-issue, fresh-start, and `find` facts
  to the BlockerWatch row.

Done when `grep -c "brief-file" templates/system/*.md` shows all three files.

### 10. Tests required

Add to `tests/test-ai-blocker-watch.sh`, each as one `check '<name>' …`:
1. `wait refuses without a brief file`.
2. `wait refuses with neither --for nor --park`.
3. `wait --park creates a labelled parked issue and records it`. Assert
   `issue create` + `--label parked` in calls, and `.parked_issue=="o/r#31"`.
4. `the parked issue body carries the plain-English summary and an owner line`.
   Capture `--body-file` contents in the fake gh by copying the file to `$FAKE/body`.
5. `wait --for marks the existing issue parked and comments the brief`.
6. `a failed issue create leaves no wait file` (use `$FAKE/fail`).
7. `wake resumes the original session when folder and transcript exist`. Create a
   fake transcript that matches the fixture `transcript_glob` under `$TMP`.
8. `wake starts a fresh session in the main checkout when the folder is gone`.
   Assert `$FAKE/resumed` shows the main-checkout path, `fresh` args, and the parked URL in the prompt.
9. `wake marks a wait orphaned when nothing can restart it and the tick fails`.
10. `wake posts exactly one outcome comment and swaps the label`, and a second
    tick posts none.
11. `an old record without parked_issue still resumes as before`.
12. `find prints matching parked work` and `find reports no match plainly`.
13. `list shows the parked issue column`.

In the fixture config (line 45), point `transcript_glob.claude/codex` at a path
under `$TMP` and add `harness_fresh.claude/codex=[$h,"fresh-<name>","{prompt}"]`.

The whole existing suite must stay green:
```bash
bash tests/test-ai-blocker-watch.sh
```
Expect `N passed, 0 failed`. Also run `bash tests/test-all.sh` if it exists and
the full run fits, or at least every suite that mentions `blocker-watch`
(`tests/test-install-ai-devops-windows.ps1` via PowerShell,
`tests/test-ubuntu-install-stages.sh`).

### 11. Constraints, standing rules, gotchas

- **Never push to `main`.** Branch → PR → checks/merge queue. The session that
  opens the PR merges it (Albert never merges). `gh pr merge` from a worktree
  may print `'main' is already used by worktree` *after* success. Confirm with
  `gh pr view <n> --json state`.
- Sign every GitHub post you make by hand (PR body, comments):
  `Posted by Claude chat <$CLAUDE_CODE_SESSION_ID> on <hostname>`.
  Comments posted *by the script* are signed "(ai-blocker-watch)", as today.
- **Windows CRLF:** keep `bin/ai-blocker-watch` LF. Check with
  `git ls-files --eol bin/ai-blocker-watch`.
- Windows `jq`/`gh` can end lines with CR. Use the existing `jq()` and `gh_api`
  wrappers, which strip it. Never call `command jq` directly.
- Every `bin/` tool has a `.cmd` sibling. `ai-blocker-watch.cmd` already exists; no change needed.
- Running the suite locally on edge-dev can cancel a live self-hosted CI job
  (memory "local run cancels live CI"). Check the runner is idle, or accept the rerun.
- **The installed tool on Windows runs from `C:\repos\ai-devops`** (the shared
  checkout), not your worktree. A merged change is not live until that checkout
  pulls. Only a serialized landing operation may touch that checkout. Prove
  that no other session is mid-edit there (`git -C C:/repos/ai-devops status --short` is clean)
  before running `git -C C:/repos/ai-devops pull --ff-only`.
- A scheduled job that did not do its work must exit non-zero. Keep the `FAILED=1` discipline.
- No secrets are involved. Do not add any.
- No database change of any kind. Nothing here touches shared-db.
- Keep configurable values (labels, owners, globs, commands) in the config file.

### 12. Access and environment

- `gh` is authenticated on edge-dev. The script calls `bin/ai-gh` (a throttling
  wrapper) unless `AI_BLOCKER_WATCH_GH` overrides it, and tests override it.
- Shells: run Bash suites in Git Bash, and PowerShell suites in `pwsh`.
- `jq` is required and is on PATH.
- No test logins, URLs, or 1Password items are needed.

---

## Part 4 — Landing it

### 13. Definition of done, risks, open questions

**Done when:**
- [ ] Steps 1-8 committed on a branch. `bash tests/test-ai-blocker-watch.sh` is
      green locally, with the summary line pasted in the PR.
- [ ] PR opened, CI green, merged by the implementing session, merge SHA recorded here.
- [ ] Shared checkout `C:\repos\ai-devops` pulled on edge-dev (see §11).
- [ ] STATUS table updated with artifacts (commit SHA, CI run id, test command).
- [ ] Step 10 live proof. On edge-dev, create a throwaway blocker issue in
      `popcre/ai-devops`. From a scratch worktree, run
      `ai-blocker-watch wait <blocker> --park "BlockerWatch live proof: fresh start" --brief-file <file>`.
      Delete that worktree and close the blocker. Run `ai-blocker-watch tick`
      (or wait 10 min). Pass = the parked issue gets the "Started a fresh claude
      session" comment, its label becomes `resumed`, and the log shows the fresh
      session read the issue. Then
      `ai-blocker-watch find "fresh start"` lists it. Record the issue URL and log path as evidence.
      Close the throwaway issues.
      If step 10 cannot be done in the implementing session, #617 stays open as
      its single live-proof owner. Do not open another issue for it.
- [ ] Update `docs/implementation-plan-index.md` (move to done when proven) and the handoff.

**Risks and rollback:**
- A fresh headless session does real work unattended. It runs with the same
  permissions as today's resume, so it is no new capability. Rollback is a
  `git revert` of the merge. Existing waits keep working, because old records
  take the old path.
- Existing sessions that follow the *old* global text will call `wait` without
  `--brief-file` and now be refused. That is intended: the refusal message
  tells them what to add. Mention this in the PR body.
- `transcript_glob` could miss a live Claude session if Claude changes its
  storage layout. The result would be a fresh start instead of a resume, which
  is safe and not lost work. Note it in the router row.

**Open questions:**
- ZCode transcript location is unknown, so ZCode relies on the folder check
  only. Decide it when a ZCode wait is first proven. Criterion: find the file
  that `--resume <id>` reads.

---

## Self-audit (final answers)

1. *Could a brand-new session execute this without asking anything?* Yes. §2
   explains BlockerWatch, and §5 gives exact line ranges and the test harness shape.
   §9 names every option, field, and command string with a done-check, and
   §10 names every test. Gap found and fixed during drafting: the existing
   tests call `wait` without a brief and would break. Step 7 now says to update them.
2. *Does it carry all background and ruled-out options?* Yes. §3 (Albert's
   correction that sessions self-declare), §6 (root cause), and §7 (six rejected
   approaches with reasons).
3. *Is the goal clear enough to steer by?* Yes. §1 states the business outcome,
   the plain-English search example, and "the goal wins".
