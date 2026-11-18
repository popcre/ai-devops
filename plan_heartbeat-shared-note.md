---
summary: Plan to rebuild the edge-dev3 runner heartbeat as one shared note published by a git push (no GitHub API calls) and turn it back on; nothing built yet.
kind: plan
status: open
read-when: Rebuilding or re-enabling the edge-dev3 runner heartbeat, or fixing issue 2346
---

# Implementation plan — edge-dev3 heartbeat as one quiet shared note (popcre/ai-devops#2346)

## STATUS (2026-11-18 3:05 PM EST)

| Step | State | Evidence |
|---|---|---|
| 0. Prove the shared-note transport on the real host | ⬜ open | |
| 1. Router reads the shared note | ⬜ open | |
| 2. Heartbeat publishes one note by git push, with back-off | ⬜ open | |
| 3. Unit files in the repository | ⬜ open | |
| 4. Land the pull request | ⬜ open | |
| 5. Install on edge-dev3 and turn the timer back on | ⬜ open | |
| 6. Live proof, close #2346, retire the old plan | ⬜ open | |

**A fresh session starts at step 0.** The heartbeat timer on edge-dev3 is
**currently switched off** (owner instruction, 2026-11-18 2:42 PM EST); see §5.
Until step 5 every routed job in 28 repositories runs on GitHub's machines.

Handoff: [HANDOFF.d/2026-11-18T1957Z-edge-dev-claude-heartbeat-shared-note-plan.md](HANDOFF.d/2026-11-18T1957Z-edge-dev-claude-heartbeat-shared-note-plan.md).
This plan supersedes [plan_issue-2346.md](plan_issue-2346.md) (same issue,
smaller fix that this design makes unnecessary).

---

## 1. Ultimate goal

Albert runs a one-person company. His desktop "edge-dev3" does the build and
test work for 28 code projects for free; when it is busy or off, GitHub's own
machines do the work instead (free for public projects, paid minutes for the
private DesignFlow projects). For that to work, edge-dev3 must keep telling
GitHub "I am here and free" or "I am busy".

Today that message costs so much GitHub traffic that it helped exhaust
Albert's hourly GitHub allowance, which stops every AI session he runs. When
this plan is done:

- edge-dev3 again takes the work first, with GitHub's machines as the fallback;
- the message is **one** shared note for all 28 projects, not 28 notes;
- publishing it uses **none** of Albert's GitHub request allowance;
- when publishing fails it waits longer and longer instead of hammering.

**If a step conflicts with this goal, the goal wins — stop and flag it.**
The safety property that must never be lost: if the note is missing, old,
unreadable, or says anything other than "online and idle", the job goes to a
GitHub machine. A broken heartbeat may cost money; it must never strand a job.

## 2. What this application is

`popcre/ai-devops` (public GitHub repository, default branch `main`, protected,
merge by pull request) holds Albert's AI and CI tooling. Relevant parts, all
added by PR #2345 (commit `87a2f89a`, merged 2026-11-04) after the owner request
of 2026-11-03 "every repository's CI runs on edge-dev3 first and free
GitHub-hosted runners as fallback":

- **Host `edge-dev3`** — Ubuntu desktop, user `ahazan`, reachable as
  `ssh edge-dev3`. Runs one GitHub Actions runner service per repository
  (28 of them, about 24 workers alive at once).
- **`config/edge-dev3-runners.tsv`** — the list: `repo<TAB>runner folder<TAB>systemd
  user unit`. 28 rows: 8 under the organization `popcre`, 20 under the personal
  account `u2giants`. Installed copy on the host: `~/.config/edge-dev3/runners.tsv`.
- **`tools/ci/edge-dev3-heartbeat.sh`** — the reporter. Installed by hand as a
  copy at `~/.local/libexec/edge-dev3-heartbeat.sh`, run every minute by the
  systemd user timer `edge-dev3-heartbeat.timer` / service
  `edge-dev3-heartbeat.service` (unit files live only on the host, in
  `~/.config/systemd/user/`; they are not in the repository yet).
- **`.github/workflows/edge-dev3-route.yml`** — reusable workflow every one of
  the 28 repositories calls as `popcre/ai-devops/.github/workflows/edge-dev3-route.yml@main`,
  passing `heartbeat: ${{ vars.EDGE_DEV3_RUNNER_HEARTBEAT }}`. Its one job
  ("Pick runner", on `ubuntu-24.04`) sparse-checks-out
  `tools/ci/edge-dev3-route.sh` from `main` into `.edge-dev3-route` and runs it.
- **`tools/ci/edge-dev3-route.sh`** — prints the `runs-on` value. Self-hosted
  only when the heartbeat matches `^(online|offline),(idle|busy),([0-9]{9,11})$`,
  is at most `MAX_AGE=330` seconds old, and says `online,idle`. Fork pull
  requests and `pull_request_target` always get the hosted fallback
  (`ubuntu-24.04`) before the heartbeat is even looked at.
- **`tests/test-ci-edge-dev3-route.sh`** — router regression test; suite
  manifest `config/ci-suites/test-ci-edge-dev3-route.sh.json`
  (`{"kind":"bash","linux_seconds":1}`).

Terms: "allowance" = GitHub's REST limit of 5,000 requests per hour for the
login `u2giants`, shared by every machine and tool that uses Albert's personal
login. "Hosted" = GitHub's own machines.

## 3. What triggered this work

2026-11-18: Albert reported being rate limited by GitHub again. Measurement on
that day found about 4,700 requests per hour on the personal login, and the
allowance fully used (5,000 of 5,000) several times. A four-minute process
trace on edge-dev3 showed the heartbeat was 65 of the 79 processes using the
personal login: about 900 note-writes per hour in normal running, and — because
of the retry defect in §6 — 469 failed writes in 70 minutes once the allowance
was gone. Albert's instruction: "first, stop that heartbeat now", then "make a
plan to rebuild the heartbeat as one quiet shared note and turn it back on."

To see the defect: read `tools/ci/edge-dev3-heartbeat.sh:23-36` on `main`
`329c345f` — one `gh variable set` per repository per run.

## 4. Scope

In:
- The heartbeat publishes one shared note for all 28 repositories, with no
  GitHub API call, and backs off on failure.
- The router reads that note (old per-repository variable kept as a fallback
  input so no calling repository has to change).
- Heartbeat unit files added to the repository; reinstall on edge-dev3;
  timer re-enabled; live proof; #2346 closed; `plan_issue-2346.md` retired.

NOT in this plan:
- Any change in the 28 calling repositories (their workflows stay as they are).
- Changing `MAX_AGE` (330 s), `REFRESH` (120 s) or `MAX_WORKERS` (3): routing
  behaviour stays identical.
- Deleting the 28 old `EDGE_DEV3_RUNNER_HEARTBEAT` repository variables. They
  go stale and are ignored; deleting them is 28 API calls for no benefit.
- The separate `shared-db-runner-heartbeat.timer` on edge-dev3 (one repository,
  about 120 requests per hour; still running, untouched).
- The other heavy users of the allowance found the same day (AI sessions on the
  server `hetz`; a CI review job using the personal login). Separate work.
- `tools/ci/install-edge-dev3-runner.sh`, `bin/ai-gh`, any required check.

## 5. Current state

- `main` is `329c345f`. No code for this plan exists. Nothing is half-done.
- **Timer is off.** On 2026-11-18 2:42 PM EST this was run on edge-dev3:
  `systemctl --user disable --now edge-dev3-heartbeat.timer` and
  `systemctl --user stop edge-dev3-heartbeat.service`. Verified afterwards:
  `inactive`, `disabled`. Unit files and the installed script were left in place.
- Host unit files today (from `systemctl --user cat`):
  timer `OnBootSec=1min`, `OnUnitActiveSec=1min`, `AccuracySec=5s`,
  `WantedBy=timers.target`; service `Type=oneshot`,
  `Environment=PATH=/usr/local/bin:/usr/bin:/bin`,
  `Environment=EDGE_DEV3_RUNNERS=%h/.config/edge-dev3/runners.tsv`,
  `ExecStart=%h/.local/libexec/edge-dev3-heartbeat.sh`, `TimeoutStartSec=55`.
- Host facts: toolkit checkout at `~/repos/ai-devops`; global git name
  "Albert Hazan"; git over HTTPS to github.com authenticates through
  `credential.https://github.com.helper = !/usr/bin/gh auth git-credential`
  (the same stored login the old heartbeat used successfully from this service).
- The 28 old repository variables still hold their last value from before
  2:42 PM EST; all are now older than 330 s, so every router answers "hosted".

## 6. Key findings and root cause

1. **28 writes where one would do.** `tools/ci/edge-dev3-heartbeat.sh:31`
   writes a repository variable in each listed repository. It was built that
   way because a workflow can read its own repository's variable for free
   (`vars.X`), and each repository has its own runner whose state differs.
2. **No back-off.** `:31-35` saves the "last written" state file only on
   success. After a failure the state file is unchanged, so the very next
   one-minute run tries again, for every repository, forever. When the
   allowance is exhausted every write fails, so the script retries 28 writes a
   minute against a limit that will not lift for up to an hour.
3. **Bypasses the shared throttle.** It calls bare `gh`, not `bin/ai-gh`
   (this is issue #2346, open since 2026-11-04, only its step 0 was done).
4. **Why the personal projects cannot share an organization setting.** GitHub
   offers "one value shared by many repositories" (organization variables) only
   to organizations. `u2giants` is a personal account (20 of the 28
   repositories), and personal accounts have no shared variables. An
   organization variable would therefore cover at most the 8 `popcre`
   repositories. (Not verified on 2026-11-18 because the allowance was
   exhausted: whether the `popcre` organization's plan even exposes
   organization variables to its private repositories. It does not matter for
   this design.)
5. **A place all 28 can read already exists.** Every router run already
   fetches from the public repository `popcre/ai-devops` (the sparse checkout
   in `.github/workflows/edge-dev3-route.yml:55-62`). A public repository can
   be fetched by git from any repository, organization or personal, without a
   login. So one note stored in `popcre/ai-devops` is readable by all 28.
6. **Git transfers are not API requests.** `git push` and `git fetch` to
   github.com do not count against the 5,000-per-hour REST allowance. One push
   therefore replaces up to 28 API writes at zero allowance cost. Step 0
   proves this on the real host before anything is built on it.

## 7. Approaches considered and rejected

- **Route the 28 writes through `bin/ai-gh`** (the old `plan_issue-2346.md`).
  Still 28 writes every two minutes from the personal allowance; and when the
  throttle refuses, notes go stale and private-repository jobs silently move
  to paid minutes. Treats the symptom.
- **One organization variable.** Covers 8 of 28 (finding 4).
- **Same 28 writes under a different identity** (a GitHub App with its own
  allowance). Moves the cost instead of removing it; adds a key to guard.
- **One GraphQL request carrying 28 mutations.** Repository variables have no
  GraphQL mutation; rejected in the old plan too.
- **Write only on change and stretch the refresh to many minutes.** Requires a
  larger `MAX_AGE`, so a dead desktop would hold jobs for that long before
  they fall back. Changes routing behaviour for a partial saving.
- **A committed file on `main` or a normal branch.** `main` is protected and
  would need a pull request per heartbeat; a normal branch fires push events
  and is subject to branch rules. A ref outside `refs/heads/` has neither
  problem (kept as the documented fallback in step 0 if the custom ref fails).
- **Reading the note through the GitHub API from the router.** Needs a token
  with access to another repository's settings; the git fetch needs none.
- **Leaving the heartbeat off.** Loses the capability the owner asked for on
  2026-11-03 and sends private-repository work to paid minutes.

## 8. Design decisions

Locked (do not relitigate):

- **L1 (2026-11-18, owner):** one shared note, quiet, timer back on.
- **L2:** the note is a single text file `edge-dev3.tsv` in a parentless
  commit, force-pushed to the ref **`refs/runner-status/edge-dev3`** of
  `popcre/ai-devops`. Each line: `owner/repo<TAB><online|offline>,<idle|busy>,<unix-seconds>`
  — the same value format as today, one line per repository, same timestamp on
  every line. Per-repository state is kept; nothing about routing changes.
- **L3:** the heartbeat makes **no** `gh` call and no GitHub API request.
- **L4:** cadence unchanged — timer every minute, publish on any state change
  or when the last publish is `REFRESH` (120 s) old. At most one push per run.
- **L5:** back-off — after a failed push do not try again for
  `min(60 × 2^(failures−1), 900)` seconds; reset on success.
- **L6:** the router prefers the shared note's line for its own repository;
  if the fetch fails or there is no usable line it uses the old `HEARTBEAT`
  input exactly as today. Every doubtful case stays "hosted".
- **L7:** the router fetches the note anonymously with git, with a 20-second
  limit, and never fails the job because of it.
- **L8:** no calling repository changes; the workflow's inputs stay the same.

Open (implementer's judgment, with criteria):

- **O1 — ref location.** If step 0 shows the custom ref cannot be pushed or
  cannot be fetched anonymously, use the branch `refs/heads/runner-status`
  instead, and confirm no workflow runs on pushes to it. Record which was used
  in STATUS. Anything else: stop and flag.
- **O2 — names of helper functions and test labels.**

## 9. The plan

Work in a fresh worktree on a new branch from `main`. Steps 1–3 go in one pull
request. Constants used below: `REF=refs/runner-status/edge-dev3`,
`FILE=edge-dev3.tsv`, `URL=https://github.com/popcre/ai-devops.git`.

### Step 0 — prove the transport on the real host — `lead-only`

Reason: live-proof judgment; decides O1.

On edge-dev3, run the following **inside a transient systemd user unit** (so it
has the same environment as the real service — an SSH shell is not proof,
because SSH sessions on this fleet cannot read the stored login):
`systemd-run --user --wait --collect --pipe -p Environment=PATH=/usr/local/bin:/usr/bin:/bin bash <script>`.
The script: record `gh api rate_limit --jq .resources.core.used`; in a new bare
repository under `$(mktemp -d)` create a blob from a one-line test file, a tree
(`git mktree`), a parentless commit (`git commit-tree`), and
`git push --force $URL <commit>:$REF` five times with new content; record the
allowance again.

Then from a different machine with no credentials
(`GIT_TERMINAL_PROMPT=0 git -c credential.helper= fetch --depth 1 $URL $REF` in
an empty repository, then `git show FETCH_HEAD:$FILE`).

Gate — you'll know it worked when: all five pushes succeed; the allowance
counter moved by no more than the two reads you made yourself (run when no other
traffic is expected, or repeat to be sure); the anonymous fetch prints the last
content; and `gh run list -R popcre/ai-devops --limit 5` shows no run triggered
by the pushes. If the push or anonymous fetch of the custom ref fails, apply O1
and repeat. If git pushes turn out to consume the allowance, **stop**: the
design's premise is false; report to the owner.

### Step 1 — router reads the shared note — `lead-only`

Reason: reshapes the logic that decides where every job runs.

- `tools/ci/edge-dev3-route.sh`: add optional input `HEARTBEAT_FILE` (path).
  After the fork / `pull_request_target` checks (`:23-26`) and before the
  format check (`:27`): if `HEARTBEAT_FILE` is a readable regular file no
  larger than 65,536 bytes, take the lines whose first tab-separated field
  equals `$REPOSITORY` exactly (case-sensitive, after stripping a trailing
  carriage return). If there is **exactly one** such line, use its second
  field as the heartbeat value in place of `$HEARTBEAT`. In every other case
  (no file, too big, no line, more than one line) keep `$HEARTBEAT`. The
  existing strict format, age (`MAX_AGE`, `-60` future tolerance), state and
  label checks then run unchanged on whichever value was chosen. Append the
  source (`shared note` / `repository variable`) to the `reason:` line on
  stderr. Update the header comment.
- `.github/workflows/edge-dev3-route.yml`, step `route` (`:63-75`): before
  running the script, fetch the note inside the existing checkout:
  `timeout 20 git -C .edge-dev3-route -c credential.helper= fetch --quiet --depth 1 https://github.com/popcre/ai-devops.git refs/runner-status/edge-dev3 && git -C .edge-dev3-route show FETCH_HEAD:edge-dev3.tsv > "$RUNNER_TEMP/edge-dev3.tsv" || rm -f "$RUNNER_TEMP/edge-dev3.tsv"`,
  with `GIT_TERMINAL_PROMPT=0`; pass `HEARTBEAT_FILE: ${{ runner.temp }}/edge-dev3.tsv`
  in `env`. The fetch must not be able to fail the step (`|| true` semantics).
  Update the header comment to describe the shared note; keep the caller
  pattern text unchanged (L8).

Gate: `bash tests/test-ci-edge-dev3-route.sh` prints
`PASS test-ci-edge-dev3-route` with the new cases of §10; all 14 old cases
still pass unmodified.

Adversarial cases (the note is fetched from outside the job; the router decides
whether a job may run on Albert's own machine):

| External input | Hostile or broken case | Required result | Test (in `tests/test-ci-edge-dev3-route.sh`) |
|---|---|---|---|
| note file | absent | falls back to `HEARTBEAT` input | `no shared note uses repository variable` |
| note file | larger than 65,536 bytes | ignored, falls back | `oversized shared note is ignored` |
| note file | no line for this repository | falls back | `shared note without this repository falls back` |
| note file | two lines for this repository | ignored, falls back | `duplicate repository lines are ignored` |
| note file | repository differs only by letter case | not matched | `repository match is case-sensitive` |
| note file | prefix repository (`o/r` vs `o/r2`) | not matched | `repository prefix does not match` |
| note line | value malformed (`online,idle,abc`, extra fields, spaces) | hosted | `malformed shared note line stays hosted` |
| note line | stale (older than 330 s) | hosted, even if `HEARTBEAT` input is fresh | `stale shared note stays hosted` |
| note line | timestamp more than 60 s in the future | hosted | `future shared note stays hosted` |
| note line | trailing carriage return | parsed correctly | `CRLF shared note is accepted` |
| note line | `offline` or `busy` | hosted | `busy shared note stays hosted` |
| event | fork pull request with a perfect note | hosted | `fork pull request ignores shared note` |
| event | `pull_request_target` with a perfect note | hosted | `pull_request_target ignores shared note` |

Note the deliberate rule in the "stale" row: once a usable line for the
repository exists, it is authoritative — the router does not fall back to the
old variable to rescue a stale or bad line.

### Step 2 — heartbeat publishes one note — `lead-only`

Reason: on the do-not-hand-off list (talks to GitHub with the owner's login;
a mistake is not caught by its own gate until live).

Rewrite `tools/ci/edge-dev3-heartbeat.sh`:

- Keep `:13-27` behaviour: same `LIST`, `STATE_DIR`, `REFRESH`, `MAX_WORKERS`,
  same per-repository `state` / `work` computation. Drop `ROOT` use for
  anything but the default `LIST`.
- New settings: `EDGE_DEV3_STATUS_REMOTE` (default `$URL`),
  `EDGE_DEV3_STATUS_REF` (default `$REF`), `EDGE_DEV3_GIT` (default `git`,
  for tests).
- Build the note in memory: one line per listed repository, `repo<TAB>state,work,now`.
  Build a "signature": the same lines without the timestamp.
- Decide: read `$STATE_DIR/published` (`<unix-seconds> <signature hash>`) and
  `$STATE_DIR/backoff` (`<failures> <not-before unix-seconds>`). Exit 0
  without publishing when `now < not-before`; or when the signature hash is
  unchanged and the last publish is less than `REFRESH` old.
- Publish: in the bare repository `$STATE_DIR/repo.git` (create with
  `git init --bare` if absent) write the blob, tree (`edge-dev3.tsv`) and a
  parentless commit (message `edge-dev3 runner status`), then
  `timeout 40 git push --force --quiet "$REMOTE" "<commit>:$REF"` with
  `GIT_TERMINAL_PROMPT=0`. Commit author/committer come from the host's global
  git identity; do not set them in the script.
- On success: write `published`, remove `backoff`, and prune the local
  repository when it holds more than 500 loose objects
  (`git -C repo.git gc --prune=now --quiet`). On failure: write `backoff` with
  failures+1 and `now + min(60·2^(failures−1), 900)`, print one line to stderr,
  exit 1.
- No `gh` anywhere in the file. Rewrite the header comment (`:1-12`) to match.

Gate: `bash tests/test-ci-edge-dev3-heartbeat.sh` prints
`PASS test-ci-edge-dev3-heartbeat`; `grep -nw gh tools/ci/edge-dev3-heartbeat.sh`
finds nothing outside comments; `bash -n` passes.

### Step 3 — unit files in the repository — `helper-ok`

Reason: copying known text into two new files; gate is exact.

Add `tools/ci/edge-dev3-heartbeat.service` and `tools/ci/edge-dev3-heartbeat.timer`
with exactly the contents quoted in §5, following the layout of the existing
`tools/ci/edge-dev3-runner-housekeeping.service` / `.timer`. Add
`config/ci-suites/test-ci-edge-dev3-heartbeat.sh.json` containing
`{"kind":"bash","linux_seconds":3}`.

Gate: `systemd-analyze verify` on both files reports no error on a Linux
machine (or, on Windows, a line-by-line match with §5); the JSON parses.
Stop-and-ask trigger: any difference between §5 and what
`systemctl --user cat edge-dev3-heartbeat.timer edge-dev3-heartbeat.service`
shows on the host — bring the difference to the lead, do not choose.

### Step 4 — land — `lead-only`

Commit as Albert (`git var GIT_COMMITTER_IDENT`) with the Claude co-author
trailer; pull request body says `Fixes #2346`, is signed with
`$AI_GH_SIGNATURE`, and contains no transcript text. Run
`bin/ai-pr-wait <pr>` in the background; reviews are advisory; merge it
yourself. Also in this pull request: update STATUS here, and set
`plan_issue-2346.md` front matter to `status: superseded` with one line
pointing to this plan.

Gate: pull request merged; `git log origin/main -1` shows the merge.
Merging is safe before step 5: with no note published the router behaves
exactly as today (falls back to the stale variable → hosted).

### Step 5 — install and turn it back on — `lead-only`

Reason: changes a live host; class `infrastructure` (declare with
`ai-task-gates`).

On edge-dev3: `git -C ~/repos/ai-devops pull` to the merge commit (never edit
the host copy by hand); copy `tools/ci/edge-dev3-heartbeat.sh` to
`~/.local/libexec/` (keep the old file as `edge-dev3-heartbeat.sh.pre-shared-note`
until step 6 passes); copy the two unit files to `~/.config/systemd/user/`;
copy `config/edge-dev3-runners.tsv` to `~/.config/edge-dev3/runners.tsv`;
`systemctl --user daemon-reload`; run the service once
(`systemctl --user start edge-dev3-heartbeat.service`) and read
`journalctl --user -u edge-dev3-heartbeat.service -n 20`; then
`systemctl --user enable --now edge-dev3-heartbeat.timer`.

Gate: `systemctl --user is-active edge-dev3-heartbeat.timer` says `active`;
an anonymous fetch of the ref from another machine shows 28 lines whose
timestamp is under 180 s old, twice, five minutes apart.

### Step 6 — live proof and closing — `lead-only`

1. Start one workflow run in a `popcre` repository and one in a `u2giants`
   repository from the list (re-run an existing recent run; do not push
   changes to do it). In each "Pick runner" log the reason line must read
   `runner online and idle … shared note` and the routed job must run on the
   edge-dev3 runner.
2. Stop the timer for seven minutes, start another run: reason must be
   `heartbeat is stale`, job on `ubuntu-24.04`. Re-enable the timer and
   confirm step 5's gate again.
3. Trace `gh` processes on edge-dev3 for ten minutes: zero belong to the
   heartbeat. Record the hourly allowance use before and after.
4. Post the evidence (counts and conclusions only) on #2346, signed; confirm
   it closed with the merge. Delete the `.pre-shared-note` file. Update STATUS,
   mark this plan `status: done`, and update the handoff file's successor note.

If live proof cannot be finished in the same session, leave a
`- [ ] live proof` item on #2346 itself and name it in the closing note; do not
open a second issue.

## 10. Tests required

- **Extend `tests/test-ci-edge-dev3-route.sh`** with the 13 named cases in the
  step 1 table plus `fresh shared note routes to edge-dev3` and
  `shared note wins over a stale repository variable`. Use temp files for
  `HEARTBEAT_FILE` and the existing fixed `NOW=1800000000`.
- **New `tests/test-ci-edge-dev3-heartbeat.sh`** — no network: the remote is a
  local bare repository passed as `EDGE_DEV3_STATUS_REMOTE`; `systemctl` and
  `pgrep` are stub scripts first on `PATH`. Cases:
  `first run publishes one note with a line per repository`;
  `exactly one push for three repositories` (count through an `EDGE_DEV3_GIT`
  wrapper that logs `push` invocations);
  `unchanged state inside REFRESH does not push`;
  `unchanged state after REFRESH pushes`;
  `state change pushes immediately`;
  `failed push records back-off and exits 1` (remote path that does not exist);
  `no attempt during back-off`;
  `back-off doubles and caps at 900 seconds`;
  `success clears back-off`;
  `published commit has no parent`;
  `script contains no gh call` (static).
- Must stay green: the repository's Verify workflow as a whole.

## 11. Constraints, standing rules, gotchas

- Never push to protected `main`; branch and pull request; the session merges
  (Albert does not). Do not create a branch inside a live shared worktree —
  use a new worktree.
- Nothing new becomes a required check (lean-required-checks ruling 2026-10-30).
- Preserve the capability: do not "fix" by leaving the timer off, raising
  `MAX_AGE`, or removing the per-repository state.
- No secrets in the script, logs, commits or chat. The push uses the host's
  existing stored login through git's credential helper; nothing is copied.
- The note is public. It contains only repository names (already public in
  `config/edge-dev3-runners.tsv`), `online/offline`, `idle/busy` and a time.
  Never add anything else to it.
- Host changes come from merged `main`, never live edits.
- The allowance may be exhausted while you work. Check
  `gh api rate_limit` (it is free) before bursts of `gh` calls; never loop on
  failures; wait for CI with `bin/ai-pr-wait` in the background, never
  `gh run watch`.
- On Windows, bash scripts must keep LF line endings.
- The systemd service `PATH` is `/usr/local/bin:/usr/bin:/bin` — the script
  must not rely on anything else. `TimeoutStartSec=55`, so the push limit (40 s)
  must stay under it.
- Times shown to Albert are in EST, computed from the clock.
- Everything posted to GitHub is signed with `$AI_GH_SIGNATURE`; no transcript
  text is posted (the repository is public).
- Do not use Entire for anything.

## 12. Access and environment

- GitHub CLI is logged in as `u2giants` on the working machines and on
  edge-dev3; that login can push to `popcre/ai-devops`. No new credential is
  needed and none may be created.
- edge-dev3: `ssh edge-dev3` (user `ahazan`). User units are managed with
  `systemctl --user`. An SSH shell cannot read the stored GitHub login — that
  is expected; test through `systemd-run --user` (step 0).
- Local test run: `bash tests/test-ci-edge-dev3-route.sh` and
  `bash tests/test-ci-edge-dev3-heartbeat.sh` (Git Bash on Windows).
- No 1Password item is involved.

## 13. Definition of done, risks, open questions

Done when all are true:
- Steps 0–6 complete; STATUS rows cite the proof (commit SHA, run ids, the
  re-runnable commands).
- Pull request merged with CI green; edge-dev3 checkout on the merge commit.
- Timer `active` and `enabled`; the ref shows a fresh 28-line note.
- One job in a `popcre` repository and one in a `u2giants` repository ran on
  edge-dev3 by way of the shared note; the stale test fell back to hosted.
- The heartbeat makes zero `gh` calls (ten-minute trace).
- #2346 closed with evidence; `plan_issue-2346.md` marked superseded; this plan
  marked done; handoff updated.

Risks and rollback:
- *GitHub rejects or throttles frequent force-pushes to one ref.* Back-off
  limits it to one attempt per 15 minutes; jobs go hosted. Rollback: none
  needed for safety; redesign cadence with the owner.
- *The custom ref cannot be fetched anonymously.* Caught in step 0 → O1.
- *The stored login is unreadable from the service.* Caught in step 0; the old
  heartbeat used the same login from the same service, so unlikely.
- *Router change breaks routing.* It can only produce "hosted" on any error;
  rollback is reverting the pull request (the router is read from `main` at run
  time, so the revert takes effect on the next job).
- *Someone with write access pushes a false note.* They could already edit the
  router itself; the note can only claim "idle" (a job queues on edge-dev3) or
  cause hosted fallback. Accepted.

Open question for the owner: none. Uncertain facts and how they get settled:
whether git pushes are free of the allowance and whether the custom ref works —
both decided by step 0's gate.

---

## Lead launch prompt

```
You are the lead for one job in the repository popcre/ai-devops: rebuild the
edge-dev3 runner heartbeat as one shared note and turn it back on.

Read first, in this order: AGENTS.md, then plan_heartbeat-shared-note.md
(STATUS table first, then all of it). Do not re-plan; the locked decisions in
section 8 are final. Work on issue popcre/ai-devops#2346.

Start at the first open STATUS row. Create your own worktree and branch from
main before editing. You do steps 0, 1, 2, 4, 5 and 6 yourself. Step 3 may go
to your helper after step 2 is written, while you run the tests.

Your helper is your own tool's smaller model — Haiku (high effort) for
Claude Opus, Luna (high) for Sol, GLM Flash for GLM MAX, Mimo Flash for
Mimo Pro. Never a full-strength model. Rules:
https://github.com/popcre/ai-devops/blob/main/templates/system/model-tier-delegation.md

Helper rules: it returns finished work or an evidenced blocker; it makes no
design decisions; it does not merge, push or post anything; when its
stop-and-ask trigger fires it comes back to you; if it is stuck for 30 minutes
you take the step back.

Checks you run yourself: both test files in section 10, the step 0 transport
proof on the real host, the anonymous fetch after step 5, and all of step 6.
Before step 5 declare the task class "infrastructure" with ai-task-gates.
The heartbeat timer on edge-dev3 is currently off on purpose; turn it on only
in step 5. Wait for CI with bin/ai-pr-wait in the background. Merge the pull
request yourself. Update the STATUS table as each step passes, citing proof.
If any step conflicts with section 1, the goal wins: stop and flag it.
```

## Self-audit (2026-11-18)

1. *Could a brand-new session execute this without asking anything?* Yes.
   §2 defines every file, host, unit and term; §5 gives the exact present
   state including the switched-off timer and the unit file contents; §9 names
   files, line ranges, behaviour, commands and a gate for every step; §12 gives
   access. The two facts not yet proven are isolated in step 0 with a decision
   rule (O1) and a stop condition.
2. *Does it carry all background and what was ruled out?* Yes. §3 has the
   measurements; §6 the root cause (28 writes, no back-off, throttle bypass)
   and why personal-account projects cannot share an organization setting;
   §7 lists eight rejected approaches with reasons, including the superseded
   plan. Gap found and fixed during audit: the rule that a stale shared line
   does not fall back to the old variable was implicit; it is now stated under
   the step 1 table and tested.
3. *Is the goal clear enough for a judgment call?* Yes. §1 states the outcome
   in business terms, the "goal wins" instruction, and the one safety property
   (any doubt → GitHub machine) that every step's failure mode is measured
   against.

Checklist: 13 sections present; goal first in plain English; rejected
approaches recorded; every step has files, gate and `lead-only`/`helper-ok`
mark with reason, no model named in steps, the one `helper-ok` step has a
stop-and-ask trigger; adversarial table present with a named test per row;
locked and open decisions labelled; out-of-scope list present; tests named;
terms defined; no secret values; done-list includes commit, push, CI, host
verification; handoff linked both ways.
