---
issue: 133
status: OPEN
owner: claude/codex-statusline-handoff
---

# Codex status line — record it in the docs, and decide if every machine gets it

Written 2026-08-27T2023Z on `edge-dev` by a Claude Code session.

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put all of these to Albert in ONE message before starting work.

**A wrong guess is recoverable, but ask first**

1. **Should every machine get the Codex status line, or just `edge-dev`?**
   Today it is switched on by hand on `edge-dev` only. Making it universal means
   `bin/setup-machine.ps1` writes the `[tui]` block during setup.
   *Recommendation: yes, make it universal.* It is display-only, it cannot break
   a session, and the whole point of the 2026-08-27 audit was that Albert could
   not see how full a session was. Blocks step 2 of §6.

2. **Which fields should the bar show if it becomes universal?**
   `edge-dev` currently shows model, folder, branch, context remaining, tokens
   used, five-hour limit, weekly limit. *Recommendation: keep exactly that set.*
   The full list of accepted values is in §5. Blocks step 2 of §6.

3. **Should Claude's `autoCompactWindow` also go to every machine?**
   It was set to 200,000 on `edge-dev` only and lives in no repo, so the other
   machines still let a Claude session grow to a full 1M-token window — the exact
   behaviour the audit identified as 66% of the bill. This is outside issue #133
   and nobody has been asked. *Recommendation: yes, and in the same change as
   decision 1, since both are "make the edge-dev fix universal".* Blocks step 4 of §6, not step 3
   today, but every day it waits is spend on four other machines.

**Not part of this work, and nobody is on it**

4. **`codex doctor` reports 450 active rollout files using 1.73 GB on disk** on
   `edge-dev`, plus "rollout files are missing from the state DB; duplicate
   thread inventory entries found". Every one of those sessions is already backed
   up in `u2giants/ai-devops-transcripts` under `collection-2026-08-27/`, so the
   local copies are not the only copy. *Recommendation: let Albert decide whether
   to prune old Codex sessions; the thread-DB inventory complaint is worth its own
   issue if it persists.* Blocks nothing.

5. **Codex 0.150.1 is available; `edge-dev` runs 0.147.0.** All the field names in
   §5 were verified against 0.147.0. *Recommendation: update, then re-verify the
   field list before making it universal* — this handoff's evidence is version
   specific. Blocks nothing, but see the risk in §9.

**Already settled — do NOT re-ask**

- 2026-08-27: Albert authorised a Claude session to edit `~/.codex/config.toml`
  on `edge-dev`, as a one-off, despite the standing rule that Claude setup never
  changes Codex configuration. That permission covered `edge-dev` only. It is
  **not** blanket permission for a universal rollout — that is decision 1 above.
- 2026-08-27: fourteen rarely-used skills were made manual-only rather than
  deleted or moved (PR #127). Do not reopen that.
- 2026-08-27: ten OTHER unused skills — the shipping, deploy, closeout, handoff
  and Synology rituals — were deliberately left automatic, because automatic
  triggering is what enforces those procedures. Do not offer to shelve them too.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's cross-machine AI toolkit: the global
instruction templates, skills, wrapper scripts (`bin/ai-*`), installers, and the
context-engineering discipline that keeps startup context small. It is a **public**
repository — concrete machine names, addresses and paths live in the private
`u2giants/ai-devops-private-config` instead.

Albert is a business owner, not a programmer. He runs Claude Code and OpenAI Codex
CLI side by side on several Windows machines (`edge-dev`, `t16`, `916`, `4837`) and
a Linux VPS (`hetz`). Both clients read instruction files this repo installs.

There is no deployed service here. "Shipping" means: merge to `main` through the
merge queue, then machines pick it up via `sync-dotfiles` / `setup-machine.ps1`.

## 2. What we set out to do this session, and why

Albert asked where his tokens were going and whether anything should move into
skills. The trigger was cost, not a bug.

Ten days of transcripts from `edge-dev` — 338 Claude Code sessions and 441 Codex
sessions, 17–27 August 2026 — were archived to the private
`u2giants/ai-devops-transcripts` repo under `collection-2026-08-27/` and read end
to end, using the token-usage records inside the transcripts rather than estimates.

He then asked two follow-ups that created this workstream: "how do I know when I've
hit 150 turns, there's no counter" and "is there anything like these indicators in
Codex for Windows?"

## 3. Current state — what is true right now

**Done and merged/merging:**

- PR #127 (`claude/shelve-unused-skills`) — in the merge queue with all three
  checks green as of 2026-08-27T2022Z. It contains: 14 skills marked
  `disable-model-invocation: true`; `tools/context-audit/context-audit.py`
  excluding manual-only skills from both client manifests while still reporting
  their count; a new case in `tests/test-context-audit.ps1`; `bin/ai-claude-statusline`;
  and the "Skill index ratchet on 2026-08-27" section in
  `docs/context-engineering.md`.
- `u2giants/ai-devops-transcripts` — clean and pushed at `65f17a2`. Holds the
  transcript archive this analysis was built from.

**Done on `edge-dev` only, by hand, NOT in any repo:**

- `~/.claude/settings.json` — `autoCompactEnabled: true`, `autoCompactWindow: 200000`,
  and `statusLine` as an object (see the trap in §4).
- `~/.codex/config.toml` — the `[tui]` block quoted in issue #133. Backed up first
  to `~/.codex/config.toml.bak-20260827-125659-tui-statusline`.

**Not started — this is the work:**

- Nothing in `docs/context-engineering.md` mentions the Codex side at all.
- `bin/setup-machine.ps1` does not write a `[tui]` block, so `t16`, `916`, `4837`
  and `hetz` have no Codex status line.

## 4. Everything we tried that did NOT work

1. **`statusLine` as a plain string.** First attempt wrote
   `"statusLine": "bash \"$HOME/.claude/statusline.sh\""` into
   `~/.claude/settings.json`. Claude Code **accepted the file without any error and
   silently ignored the key**, so nothing rendered and there was no diagnostic to
   follow. `statusLine` must be an object:
   `{"type": "command", "command": "~/.claude/statusline.sh"}`. On Windows the
   command runs through Git Bash, so the path needs forward slashes or `~` —
   backslashes are eaten as escapes with no visible error. Cost about twenty
   minutes and a wrong "it's done" report to Albert.

2. **Seven `jq` calls in the status line script.** The first version called `jq`
   once per field. Measured 0.61s per render, and the bar redraws after every tool
   call. One `jq` call producing all fields: 0.18s.

3. **`@tsv` with `IFS=$'\t'` for those fields.** Tab is IFS whitespace, so bash
   collapses runs of it. A session with no git branch shifted every later value one
   position left and printed the context percentage where the model name belongs.
   Fixed by joining on the unit separator (`$'\037'`), which bash never collapses.
   The no-branch case is now an explicit test.

4. **Editing the installed skills under `~/.claude/skills/` directly.** They carry
   a `.ai-devops-managed` marker — "Rewritten on every install; do not edit". Any
   local edit is silently reverted by the next `sync-dotfiles`. The source of truth
   is `skills/claude/` and `skills/shared/` in this repo.

5. **A wrong measurement that nearly killed a working system.** The first analysis
   reported tool output as 0.07% of input and concluded the Headroom compression
   proxy was pointless. That compared unique tool-output bytes against total
   *re-read* tokens — the same content counted once on one side and once per turn
   on the other. Measured correctly, tool results are 46.9% of the conversation
   body and tool calls another 36.2%. **Do not repeat that comparison.** The
   corrected figure supports the Headroom trial and matches the 13.2% already
   recorded in `docs/headroom.md`.

6. **`gh pr merge --auto --delete-branch`.** Rejected: "Cannot use `-d` or
   `--delete-branch` when merge queue enabled." Drop the flag.

## 5. Root causes and key findings

- **Codex already solves the compaction half.** It auto-compacts at 80% of the
  context window by default and silently ignores any attempt to set
  `model_auto_compact_token_limit` above 90%. This is why the transcripts show 25
  compactions across 441 Codex sessions and effectively none across 338 Claude
  sessions — Claude had nothing forcing a reset inside a 1M window.
- **Codex's status line is real but off by default.** Config keys are
  `[tui] status_line` (an array) and `[tui] status_line_use_colors` (boolean).
- **The accepted `status_line` values, extracted from the `codex-cli 0.147.0`
  binary:** `project-name`, `app-name`, `current-dir`, `run-state`, `thread-title`,
  `git-branch`, `context-remaining`, `context-used`, `five-hour-limit`,
  `weekly-limit`, `codex-version`, `used-tokens`, `total-input-tokens`,
  `total-output-tokens`, `thread-id`, `fast-mode`, `model-with-reasoning`,
  `task-progress`. Note `model-name` is **not** valid — a web search suggested it
  and the binary does not contain it. Verify against the binary, not the web.
- **There is no Codex turn counter.** `context-remaining` is the nearest thing.
- **`bin/configure-codex-mcps.ps1` preserves unrelated sections.** Proven, not
  assumed: the script was run against a *copy* of the real config with
  `-ConfigPath`, and the `[tui]` block survived intact.
- **Codex's cost shape differs from Claude's.** Codex context stayed capped; its
  spend came from many model calls inside single long turns — one session used
  217M tokens across 29 turns. A status bar does not address that.

## 6. Exact next steps

1. **Confirm PR #127 landed on `main`.**
   `gh pr view 127 --repo popcre/ai-devops --json state,mergeCommit`
   *You'll know it worked when* `state` is `MERGED` and a merge commit SHA is
   present. If it is still `OPEN`, check the merge queue
   (`gh api repos/popcre/ai-devops/actions/runs --jq '[.workflow_runs[]|select(.event=="merge_group")]'`)
   before doing anything else — do not branch from a `main` that lacks it.

2. **Put §0 to Albert in one message and wait for answers 1 and 2.**
   *You'll know it worked when* you have a yes/no on universal rollout and a
   confirmed field list.

3. **Add the Codex paragraph to `docs/context-engineering.md`,** inside the
   "Skill index ratchet on 2026-08-27" section, right after the paragraph that
   ends "...restart Claude Code fully - the setting is only read at startup."
   Cover: Codex auto-compacts at 80% by default so no change was needed there; the
   status line is off by default; the `[tui]` block that was applied; the full
   accepted field list from §5; that field names must be verified against the
   installed binary rather than the web; and that `configure-codex-mcps.ps1` was
   proven to preserve the section.
   *You'll know it worked when* `python tools/context-audit/context-audit.py --root . --strict`
   exits 0 with no NEW budget warning. Two warnings are pre-existing and expected:
   always-loaded globals over by 6,664 bytes, and startup-routed entry files over
   by 1,818 bytes. `docs/` is task-triggered, so a paragraph there does not touch
   the always-loaded budget.

4. **If Albert said yes to decision 1,** add the `[tui]` block to
   `bin/setup-machine.ps1` near the existing Codex config work at line ~830, and
   extend `tests/test-ai-install-manifest.sh` or add a focused test proving an
   existing unrelated section survives.
   *You'll know it worked when* the new test fails with the writer removed and
   passes with it, and `pwsh -NoProfile -File tests/test-context-audit.ps1`
   still reports every PASS line.

5. **Ship it.** Branch from current `origin/main`, commit, push, open a PR, let
   the merge queue take it, then **delete this handoff file** in that same PR.
   *You'll know it worked when* `gh pr view <n> --json state` says `MERGED` and
   issue #133 is closed.

## 7. Constraints and gotchas in force

- **`popcre/ai-devops` is PUBLIC.** No machine names beyond the nicknames already
  used here, no addresses, no private paths, no credentials.
- **`main` is protected and uses a merge queue.** Never push to `main` directly.
  `--delete-branch` is rejected with a queue enabled. `gh pr merge` *enqueues*; the
  PR shows `OPEN` until the queue's own run finishes, which is not a failure.
- **`windows-offline` takes about an hour** and gates every merge (issue #98).
  Any push to a branch restarts it, so batch changes rather than pushing twice.
- **`test-ai-grok-review.sh` is known non-deterministic** (issue #89, fix in flight
  as PR #123). It failed once on PR #127 and passed on retry; both suites pass
  locally at 41 tests each. Do not chase it as a real failure without reproducing.
- **Never edit another session's `HANDOFF.d/` file, and never rewrite the root
  `HANDOFF.md`** — it is already the `handoff-pointer: v1` static pointer.
- **`C:\repos\ai-devops` had 10 uncommitted files from another session** at the
  time of writing. Work in your own worktree; do not stage there.
- **Claude setup must never change Codex configuration** is a standing rule.
  Albert waived it once, for `edge-dev` only, on 2026-08-27.
- Installed skills under `~/.claude/skills/` are managed artefacts — edit the repo
  source, never the installed copy (§4 item 4).

## 8. Access and environment

- `gh` CLI is authenticated for `popcre` and `u2giants`. Committer identity must
  read `Albert Hazan <u2giants@users.noreply.github.com>` — check with
  `git var GIT_COMMITTER_IDENT` before the first commit.
- Windows with Git Bash at `C:\Program Files\Git\bin\bash.exe`; `pwsh`, `python`,
  `jq`, `xz` all on PATH. Git long paths are enabled globally.
- Codex CLI is at `~/.codex/packages/standalone/current/bin/codex`, version
  0.147.0, authenticated. `codex doctor` is the read-only health check.
- The transcript archive is the private `u2giants/ai-devops-transcripts`, checked
  out at `C:\repos\ai-devops-transcripts`. `collection-2026-08-27/unpack.sh`
  expands it (~1.9 GB, gitignored).
- Secrets live in the 1Password vault `vibe_coding`. Nothing in this workstream
  needs one. No credential values appear anywhere in this file.

## 9. Open questions and risks

- **Version drift (medium).** The field list in §5 came from `codex-cli 0.147.0`;
  0.150.1 is out. If step 4 writes those names into an installer, a renamed field
  on a newer Codex could produce a broken bar on every machine at once. Re-verify
  against the installed binary before shipping the installer change. Decision 5
  in §0 covers this.
- **Unknown failure mode for a bad field name (low).** It was never tested what
  Codex does with an invalid `status_line` entry — it may ignore it or refuse the
  config. `codex doctor` reported `config.toml parse ok` for the known-good set
  only. Worth one deliberate test before a universal rollout.
- **Decision recorded 2026-08-27:** 14 skills were made manual-only rather than
  moved or deleted, specifically so nothing disappears from the slash-command
  menu. Ten other unused skills — the shipping, deploy, closeout, handoff and
  Synology rituals — were deliberately **left automatic**, because automatic
  triggering is what enforces those procedures. Do not "finish the job" by
  shelving those ten.
- **Decision recorded 2026-08-27:** Claude's `autoCompactWindow` was set to
  200,000 on `edge-dev` only. It is not in any repo and no other machine has it.
  Whether that should also become universal is decision 3 in §0.
- **Measurement caveat.** The 46.9%/36.2% split in §4 item 5 is character counts
  from transcript message bodies, converted at roughly 4 characters per token.
  JSON-heavy content tokenises worse than that, so treat the split as a ratio, not
  as exact token counts.
