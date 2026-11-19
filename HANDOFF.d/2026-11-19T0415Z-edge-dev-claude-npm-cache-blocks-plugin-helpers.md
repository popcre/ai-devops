---
issue: 2687
status: OPEN
owner: claude/slm-agent-npm-cache-handoff-2687
---

# edge-dev: npm cache fault stops the ScaleDown plugin helper (and context7) from starting

## 0. BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream needs the owner.

Already settled — do NOT re-ask:

- 2026-11-18, Albert: "yes install it and make it part of the toolkit" — the
  ScaleDown `slm-agent` plugin is wanted on every toolkit machine. Done and merged.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's toolkit that sets up AI coding tools (Claude
Code, Codex and others) the same way on each of his development computers. It is
installed on a machine by
[`install.sh`](https://github.com/popcre/ai-devops/blob/main/install.sh) and kept
current by the "sync my dotfiles" skills. Entry point for any session:
[`AGENTS.md`](https://github.com/popcre/ai-devops/blob/main/AGENTS.md).

"edge-dev" is one of those computers: Windows 11, node v24.19.0, npm 11.17.0.

## 2. What we set out to do this session, and why

Albert asked why the `/slm-agent:evaluate` skill was missing on edge-dev, then
asked to install it and make it part of the toolkit. The skill comes from a
third-party Claude Code plugin, `slm-agent` from the `scaledown` marketplace
(source repository `scaledown-team/SLM_Agent`). It scans a codebase for AI calls
that could move to ScaleDown's small models. Nothing in the toolkit installed
plugins, so it existed on one machine and not the next.

## 3. Current state — what is true right now

Done, merged and verified:

- Issue [#2660](https://github.com/popcre/ai-devops/issues/2660) is CLOSED.
- [PR #2654](https://github.com/popcre/ai-devops/pull/2654) (merged) added
  [`config/claude-plugins.tsv`](https://github.com/popcre/ai-devops/blob/main/config/claude-plugins.tsv)
  (the list), [`bin/ai-claude-plugins`](https://github.com/popcre/ai-devops/blob/main/bin/ai-claude-plugins)
  (installs whatever on the list is missing; `--check` reports only),
  [`tests/test-ai-claude-plugins.sh`](https://github.com/popcre/ai-devops/blob/main/tests/test-ai-claude-plugins.sh),
  an optional install stage "4.8b Claude plugins" in `install.sh`, and steps in
  both sync-dotfiles skills.
- [PR #2673](https://github.com/popcre/ai-devops/pull/2673) (merged, commit
  [88a20f5a](https://github.com/popcre/ai-devops/commit/88a20f5a240a26901266287e8a9de9795ecfca7f))
  added the Windows launcher `bin/ai-claude-plugins.cmd` that PR #2654 forgot
  (`tests/test-bin-cmd-launchers.sh` failed on main without it).
- On edge-dev the plugin is installed: `claude plugin list` shows
  `slm-agent@scaledown`, version 0.1.9, scope user, enabled;
  `bin/ai-claude-plugins --check` prints
  `OK all 1 required Claude plugin(s) already present`. A Claude session started
  after the install lists the skills `slm-agent:evaluate` and `slm-agent:optimize`.

NOT working (this handoff's open item, issue
[#2687](https://github.com/popcre/ai-devops/issues/2687)):

- The plugin ships a small local helper program (an "MCP server") that Claude
  starts with `npx -y @scaledown/migration-agent`. On edge-dev it never connects
  ("Connection closed"). The `context7` helper, also started through `npx`, fails
  the same way. Cause: every npm registry fetch through the default npm cache
  fails on this machine. This is a machine fault, not a toolkit or plugin fault.
- The skill itself has therefore never been run end to end on edge-dev.

Not started: no other machine has been synced since the merge, so none has the
plugin yet; each gets it on its next toolkit install or "sync my dotfiles".

Nothing is uncommitted or unpushed apart from this handoff file's own PR.

## 4. Everything we tried that did NOT work

All on edge-dev, 2026-11-18 about 11:00 PM EST, default cache at
`%LOCALAPPDATA%\npm-cache`:

1. `npx -y @scaledown/migration-agent` (twice) — fails with
   `EEXIST: file already exists, open '...\npm-cache\_cacache\tmp\<random name>'`.
   The `tmp` folder held six old leftover files (August to November), none with a
   colliding name.
2. `npm view is-odd version` — same EEXIST. So it is every package, not this one.
3. `npm cache verify` — ran 134 s, garbage-collected about 6.8 GB, and removed
   the `tmp` folder. Did not help: the error became
   `ENOENT: no such file or directory, mkdir '...\_cacache\tmp'`.
4. Recreating `_cacache\tmp` by hand — error went back to EEXIST on a random
   name inside an empty folder.
5. Moving the whole `_cacache` folder aside so npm starts empty — still
   `ENOENT mkdir ...\_cacache\tmp`. So the cache CONTENTS are not the cause. The
   folder was moved back unchanged afterwards.
6. Running with the Claude Bash sandbox disabled — same EEXIST. So the sandbox is
   not the cause.
7. Running npm from Windows PowerShell 5.1 — not a valid test: `npm.ps1` is
   blocked by the script execution policy there. Use `npm.cmd` if retrying.

The one thing that DID work: `npm view @scaledown/migration-agent version
--cache <a brand-new folder elsewhere>` succeeded. Registry, network and package
are fine; only writes under the default cache folder fail.

## 5. Root causes and key findings

- Root cause of the missing skill (solved): Claude plugins are per-machine state
  under the Claude profile's `plugins` folder and the toolkit did not manage them.
- Root cause of the helper failure: NOT yet known. What is established: node/npm
  cannot create or open files under `%LOCALAPPDATA%\npm-cache\_cacache\tmp`,
  while Git Bash `mkdir`/`mv` in the same folder succeed and npm with a different
  cache folder succeeds. That pattern points at something that treats node.exe
  writes to that folder specially — candidates: antivirus or Windows "Controlled
  folder access", folder permissions (ACL) or an odd attribute on `npm-cache`,
  or a reparse point. None of these has been checked.
- `context7` was already failing before any cache command was run in this
  session, so the fault predates this session's work.
- A new repository rule learned the hard way: every extensionless script added
  to `bin/` needs a matching `bin/<name>.cmd` launcher (copy any existing one);
  [`tests/test-bin-cmd-launchers.sh`](https://github.com/popcre/ai-devops/blob/main/tests/test-bin-cmd-launchers.sh)
  enforces it. Checks are advisory, so a PR can merge red — read them anyway.

## 6. Exact next steps

1. On edge-dev run `npm view is-odd version`. If it now succeeds the fault was
   transient: skip to step 5. You'll know it worked when it prints a version.
2. Inspect the folder, read-only: `icacls "%LOCALAPPDATA%\npm-cache"` and
   `fsutil reparsepoint query "%LOCALAPPDATA%\npm-cache"`, and check Windows
   Security "Controlled folder access" and recent protection-history blocks for
   node.exe. You'll know it worked when one of them shows a deny entry, a
   reparse point, or a block event naming node.exe.
3. Repair the cause found in step 2 (fix the permission or add the allowance).
   Do not "fix" it by pointing npm at a different cache folder unless step 2
   finds nothing — that hides the fault. If nothing is found, set the cache to a
   new folder with `npm config set cache <folder>` as the documented fallback and
   say so on issue #2687. You'll know it worked when `npm view is-odd version`
   succeeds with no `--cache` flag.
4. Run `npx -y @scaledown/migration-agent` with an initialize request on its
   input. You'll know it worked when it answers with JSON instead of an npm error.
5. Start a NEW Claude session on edge-dev. You'll know it worked when neither
   `plugin:slm-agent:scaledown-migration-agent` nor `context7` is reported as
   failed to connect, and `/slm-agent:evaluate` runs in a small test folder and
   writes `scaledown-report.md` there.
6. Post the evidence on issue #2687, close it, and delete this handoff file in
   the same pull request. You'll know it worked when the issue is CLOSED and
   this file is gone from `main`.

## 7. Constraints and gotchas in force

- Preserve the capability: repair, never remove or disable the plugin or the cache.
- Never ask Albert to approve, click or type; replies to him are short and plain.
- Never push to `main`; branch, PR, merge queue (plain merge, no admin override).
- All GitHub calls go through `bin/ai-gh`; each call can take minutes. Sign posts
  with the line printed by `bin/ai-gh-signature` (it takes no arguments).
- The plugin's helper starts once per Claude session on every machine; that
  per-session cost is the known concern tracked in issue
  [#707](https://github.com/popcre/ai-devops/issues/707).
- Networking-only machines (edge-alien, edge-runn-envy, edge-runn-xps) never get
  the toolkit, so never the plugin.
- `%LOCALAPPDATA%\npm-cache\_cacache` is shared by every session on the machine;
  other sessions' helpers use it. Move it aside only as a recoverable rename.

## 8. Access and environment

- Machine: edge-dev, Windows 11, Git Bash for the toolkit's Bash scripts.
- GitHub: `bin/ai-gh` is authenticated as Albert's personal identity for
  `popcre/ai-devops`. No secret is needed for this work; ScaleDown's API key is
  only needed by `/slm-agent:optimize`, and lives in the 1Password vault
  `vibe_coding` (never paste the value).
- Plugin source was reviewed at commit `ec2df3cfe1bf` of `scaledown-team/SLM_Agent`:
  no network calls in the helper, it only writes `scaledown-report.md`.

## 9. Open questions and risks

- 2026-11-18: whether other Windows machines have the same npm fault is unknown.
- 2026-11-18: `npm cache verify` garbage-collected about 6.8 GB of cached
  packages on edge-dev. They re-download on demand once the cache works; until
  then offline `npx` starts that previously relied on the cache may also fail.
- 2026-11-18: decision — the plugin is installed at user scope (all projects),
  because the request was "make it part of the toolkit"; narrowing it to chosen
  projects would be a change to `bin/ai-claude-plugins`.

## Self-audit (passed)

1. Fresh developer can continue: §1–§3 give app, goal and exact state; §6 gives
   ordered steps with gates. Yes.
2. As well as the author: §4 lists all seven attempts and the one success; §5 the
   candidate causes. Yes.
3. Every detail: constraints §7, access §8, risks and dated decisions §9. Yes.
4. Owner decisions: walked §1–§9; none needs Albert's judgement; §0 says None. Yes.
