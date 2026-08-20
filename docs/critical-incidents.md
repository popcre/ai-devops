# Critical incidents

**Owner:** this file owns the full narrative of every costly incident this toolkit
has survived: impact, symptom, root cause, fix, prevention, and the lessons that
made the diagnosis slow. `AGENTS.md` carries only a one-line warning per incident
plus a link here.

**Open this file when** you are diagnosing a tool that reports success but does
nothing, a 1Password rate-limit or lockout, a Codex sandbox failure on Windows, or
whenever an `AGENTS.md` warning line points you here.

Related incident records with their own files:
[`cloud-build-prod-trigger-incident-2026-07-20.md`](cloud-build-prod-trigger-incident-2026-07-20.md),
[`security-incident-credential-rotation-2026-07.md`](security-incident-credential-rotation-2026-07.md),
[`transcript-leak-audit-2026-07-19.md`](transcript-leak-audit-2026-07-19.md).

Moved out of `AGENTS.md` on 2026-08-12 by step 5 of
[`plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md).
Nothing was reworded in the move, except that a paragraph duplicated twice in the
source was reduced to one copy.


## 2026-07-16 — Codex on Windows: healthy-looking, silently non-functional

**Impact:** every sandboxed `codex exec` on t16 wrote nothing while reporting
success. An AI session handed Codex an 8-item implementation task; Codex changed
zero files and the run still exited 0. Cost roughly a full session, most of it
spent misdiagnosing.

**Symptom:**
`windows sandbox: orchestrator_helper_launch_failed: setup refresh failed to
launch helper: helper=codex-windows-sandbox-setup.exe, error=program not found`
— while `codex --version` and `codex login status` both succeeded and exited 0.

**Root cause (upstream, not a bad install):** the standalone installer puts
`%LOCALAPPDATA%\Programs\OpenAI\Codex\bin` on PATH. That directory is a
**junction** to `%USERPROFILE%\.codex\packages\standalone\current\bin` — only
`bin` is linked, so the package's sibling `codex-resources\` (holding the sandbox
helper) is unreachable from it. Codex resolves the helper relative to the invoked
exe, so via that PATH entry it cannot launch it. The package itself is complete
and passes the installer's own `Test-PackageContentsAreComplete`. Proven A/B: same
binary, same version 0.144.5, same flags — fails via the junction, succeeds via
`…\.codex\packages\standalone\current\bin\codex.exe`. Filed upstream:
[openai/codex#32655](https://github.com/openai/codex/issues/32655) (we confirmed
0.144.5; see also #30829, #32359, #28457 — a regression tracked since 0.132/0.138).

**Fix:** `bin/setup-machine.ps1` step "Codex PATH" prepends the real package bin
to the user PATH (`current` is a junction the updater re-points, so it survives
upgrades) and then verifies with a real sandboxed write.

**Prevention:** `ai-devops doctor` now proves the sandbox with a real
`workspace-write` instead of asking `--version`. Run it on every machine after any
Codex install/upgrade.

**Lessons worth keeping (these are why it took so long):**
1. **Presence is not capability.** `--version`, `login status`, and exit 0 were all
   green while the tool was broken. Every one of our checks asked the wrong
   question. Health checks must exercise the capability.
2. **An empty result is not proof a tool is broken.** The same session first
   misdiagnosed the 1Password MCP `op_run` as "env injection is broken" — actually
   `argv:["bash",…]` on Windows resolves to **WSL** bash, whose isolated Linux env
   does not inherit the injected Windows env. One `pwd` (returning `/mnt/c/...`)
   would have ended it immediately. Establish platform, resolved executable, shell,
   cwd, and env boundary *before* blaming the tool.
3. **Know how your tools lie.** `find -type f` showed an "empty" dir because it does
   not traverse junctions; that was read as "helpers are missing" and sent the
   diagnosis down a wrong path. PowerShell
   `Get-Item <dir> | Select LinkType,Target` shows the truth.
4. **Verify the verifier.** Two "syntax errors" and one "broken probe" during the
   fix were false alarms from the wrong tool (PowerShell 5.1's legacy `PSParser`;
   a hand-rolled test harness). Confirm a failure is real before acting on it.
5. **Check for duplicates before filing.** The bug already had 8+ open upstream
   issues; a 9th would have been noise. Commenting with a new-version repro added
   signal instead.

_(One noteworthy setup detail, not an incident: the very first push to GitHub was
rejected by GitHub's email-privacy protection because the commit used a private
`@gmail.com` address. Resolved by setting the repo-local git email to the
`@users.noreply.github.com` form. Future commits should keep using the noreply
email.)_

## 2026-07-23 — 1Password service account locked out by a "parallel initialization storm"

**Impact:** the shared 1Password **service account** (one account across all 5
machines) hit its **per-hour request cap** and temporarily locked, cutting off
1Password secret access for every AI surface.

**Root cause:** the deployed MCP secret launcher (`~/.config/ai-devops/mcp-launch.cmd`,
2026-07-17 version) wrapped every server in `op run --env-file=mcp.env`, which
**re-resolved all ~11 `op://` references on every MCP-server start** — whether or
not that server needed them. Claude Code boots ~2 wrapped servers (~22 reads),
Claude Desktop ~3 (~33 reads), per window open/reload, ×5 machines sharing one
account, into a rolling 60-minute window. Parallel subagents from one session
compounded it. The limit is **total requests/hour, not concurrency** — so a mutex
alone is the wrong tool, and a shared HTTP broker was rejected (no new moving
parts across 5 machines).

**Fix (all in this repo):** `bin/mcp-secret-launch.ps1` resolves all secrets
**once** behind a machine-wide mutex (`Local\ai-devops-1password-refresh`) and
reuses a **15-minute DPAPI-encrypted cache** (`mcp-secrets.dpapi.json`), so
1Password is hit **≤1 refresh / 15 min / machine** no matter how many
windows/servers/subagents launch (~44 reads/hr/machine worst case). Also folded
**Codex** (`~/.codex/config.toml`) into the same launcher via
`bin/configure-codex-1password.ps1`, removing its inline plaintext token.
Deployed + verified on t16; **still to roll out on the other machines** and
**commit/push**. Full detail: [`mcp-1password-rate-limit-hardening.md`](mcp-1password-rate-limit-hardening.md).

**Trap fixed along the way:** the caching launcher had been committed but never
deployed, hiding a bug. `pwsh -File script -- %*` mis-parses `--` as an empty
parameter name, and even without `--` the child's leading `cmd /c` bound
positionally to `-Url`/`-SecretRef` and was silently dropped. Fixed by declaring
`$CommandArgs` as `[Parameter(Position = 0, ValueFromRemainingArguments = $true)]`
(makes it the only positional, forcing `-Url`/`-SecretRef` to name-only) and
removing `--` from both generated launchers. **Do not re-add `--` or remove
`Position = 0`.**

**Lessons worth keeping:**
1. **A committed fix that was never deployed is not a fix.** The caching launcher
   existed in the repo for days while every machine still ran the storming
   2026-07-17 launcher. Verify the artifact on disk, not just the repo.
2. **Rate limits are per-time-window totals.** Reach for "resolve once, reuse"
   (cache), not concurrency limits, when the cap is requests/hour.
3. **The config/launch layer, not the server, was the primary lever** — confirmed
   by an independent Codex review.

### 2026-08-16 Ubuntu follow-up: the lock covered the server lifetime

Hetz Codex startups began timing out on the 1Password MCP. The Ubuntu launcher
ran `flock ... op run ... -- <MCP server>`. Because the child inherited the open
lock, one long-running GLM process held the shared refresh lock for about 11
days. Every later 1Password startup queued behind it and missed Codex's 30-second
startup limit.

The permanent fix is in `bin/setup-secrets.sh`: hold the lock only while
resolving secrets, release it, then start the MCP server with the resolved values
already in memory. Do not extend the timeout. Do not wrap a long-running server
inside `flock` or `op run`.



## 2026-08-18 — `git reset --hard` destroyed another session's uncommitted work

**Impact:** an uncommitted working-tree edit to `bin/ai-glm`, made by a different
concurrent session in this same working copy, was permanently lost. Uncommitted
changes never enter Git's object store, so there is no reflog entry, no dangling
blob, and no recovery. `git fsck --lost-found` was run and found nothing relevant.
One file, unknown content, unrecoverable.

**Symptom:** none at the time. The reset reported nothing, the push succeeded, and
the loss was only noticed because ` M bin/ai-glm` had silently disappeared from a
later `git status` that was being read for an unrelated reason.

**Root cause:** the session needed to realign local `main` after pushing a commit
through a temporary worktree, and reached for a hard reset as a cleanup step:

```
git reset -q --hard origin/main -- 2>/dev/null || git merge -q --ff-only origin/main
```

The trailing `--` with no pathspec does not scope anything. This is a full hard
reset, and `--hard` overwrites the working tree, not just the index and HEAD. The
`2>/dev/null` hid any complaint, and `-q` hid the result.

**Why the session had already been warned.** The same session had, twenty minutes
earlier, deliberately used a temporary worktree *specifically* to avoid disturbing
this session's uncommitted files, and had explicitly committed with an explicit
pathspec for the same reason. It knew the repository was dirty with someone else's
work. The care was applied to the interesting steps and dropped on the boring
cleanup step at the end.

**Prevention — the rule this broke.** Global rule 16a: every destructive action
must be recoverable before you take it, and `git reset --hard` over unreviewed work
is named in it explicitly.

Concretely, in a repo that may be shared with a concurrent agent:

- **Never `git reset --hard` in a working copy you did not verify is clean.** Run
  `git status --short` first, and treat any ` M` line as a hard stop.
- To realign a local branch after pushing via a worktree, use
  `git merge --ff-only origin/main` alone, with no `--hard` fallback. It refuses
  rather than destroys, which is the entire point.
- Never chain a destructive command as the fallback of a non-destructive one. The
  `||` in the command above turned "try the safe thing" into "do the unsafe thing
  whenever the safe thing is unavailable".
- Do not silence a destructive command. `-q` and `2>/dev/null` on a `reset --hard`
  remove the only evidence you would have had.

**Lesson that made this slow to notice:** the loss produced no error and no output.
Concurrent-agent damage is silent by construction, so the guard has to be *before*
the command, not a check afterwards.


## 2026-08-19 — a force-push silently dropped four commits from `main`

**Impact:** in `u2giants/licensor-source-data`, four commits that had been pushed to
`main` were removed from both `main` and `origin/main` by a later force-push from a
different concurrent session. Two sessions' work vanished: a complete scraper with
its tests, a docs commit, a handoff, and an unrelated session's scraper. The working
tree reverted with it, so the files disappeared from disk too.

**Symptom:** none at the time. It surfaced only because a wrap-up step listed the
repo's tracked files and the count was implausibly small. `git status` looked
ordinary; `git log` looked ordinary; the branch reported neither ahead nor behind.
A deleted file had even reappeared, which is the tell — a revert, not a deletion.

**Root cause:** a force-push that rewrote `main` without merging what was already
there. This is the committed-work twin of the 2026-08-18 incident above, which
destroyed *uncommitted* work with `reset --hard`. Same class, opposite side.

**Recovery — this part matters, because it worked completely.** Unlike uncommitted
work, pushed commits are recoverable: the objects survive in every clone that ever
had them, even when no branch points at them any more.

```bash
git merge-base --is-ancestor <sha> HEAD || echo dropped   # confirm the loss
git merge --no-ff <tip-sha> -m "Restore commits dropped by a force-push"
```

Merging the **tip** of the dropped chain restores the whole chain, and it restored a
second session's commit for free because that commit was in the same ancestry. A
merge is the right tool here, not another force-push: it is additive, it keeps both
histories, and it cannot drop whatever arrived in the meantime.

Find the SHAs in `git reflog`, or in earlier session output if you have it. Do this
**before** running `git gc`, which is what eventually collects unreachable objects.

**Prevention:**

- **Never force-push a shared branch.** In these repos `main` is shared with
  concurrent agents by design.
- If a push is rejected, `git fetch` and rebase or merge onto what is there. A
  rejected push is the safety net working, not an obstacle to overpower with `-f`.
- Before any history rewrite on a shared branch, run `git log --oneline origin/main`
  and read whose commits you are about to discard.

**Lesson:** both of today's losses were silent, and both were noticed by accident
during an unrelated check. Concurrent-agent damage does not announce itself, so the
guard belongs before the destructive command. The difference is that committed work
came back in one command and uncommitted work was gone forever — which is the
strongest possible argument for committing early in a shared checkout.


## 2026-08-20 — MCP servers written to a file Claude Code never reads

**Impact:** every machine `bin/setup-machine.ps1` or `bin/setup-secrets.sh` had
ever "set up" in fact had **zero** Claude Code MCP servers registered, while the
config on disk looked complete and correct. Albert had been reporting MCP servers
"keep disappearing" across multiple sessions; each session reinstalled them into
the same ignored file and declared success, so the complaint kept returning.

**Symptom:** `~/.claude/settings.json` contained a full, valid `mcpServers` block
with all 11 servers. `claude mcp list` returned only the account-synced
`claude.ai` connectors and not one local server. No error anywhere.

**Root cause:** Claude Code reads local MCP servers from **`~/.claude.json`
only**. An `mcpServers` key in `~/.claude/settings.json` is silently ignored — it
parses, it persists, it is visible in the file, and it is never loaded. Both
setup scripts targeted settings.json. `~/.claude.json` had never held a single
server: every rolling backup of it, going back the full retention window, showed
an empty set.

**Fix:** both scripts now write `~/.claude.json` and strip the stale copy of
their own keys out of settings.json (with a backup), leaving permissions, hooks
and foreign servers untouched. `CLAUDE_SETTINGS` still works as an override under
the new name `CLAUDE_MCP_CONFIG`.

**A SECOND, SEPARATE fault found while verifying the first — do not conflate
them.** The Claude **desktop app** rewrites
`%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude_desktop_config.json`
and deletes the entire `mcpServers` key; every other key survives, the only log
line is `Config file written`, the org blocklist was empty and the dxt allowlist
disabled. **Settings → Developer** (not Settings → Connectors) is the screen that
reads that file. The block was restored by hand on 2026-08-20 as a deliberate
test and survived one app restart; if it vanishes again, restoring the file is a
band-aid and the app version has stopped honouring it.

**Prevention / lessons:**
- A config file that parses is not a config file that is *read*. Prove a setting
  took effect with the tool's own query (`claude mcp list`), never by cat-ing the
  file you just wrote. Every session that "fixed" this had read the file back.
- A recurring user complaint that keeps returning after a fix means the fix
  addressed the wrong layer. Treat the third report as evidence about the
  diagnosis, not about the user.
- `claude mcp add ... -- cmd /c npx ...` run from **Git Bash** silently rewrites
  the `/c` flag to `C:/` (MSYS path conversion), registering a server that can
  never launch. Use `MSYS_NO_PATHCONV=1` with `//c` and correct the stored value,
  or edit the JSON directly.


## 2026-08-20 — the doctor's Codex probe cried wolf (hung on stdin) and hid a revoked login

**Impact:** `install.sh` on hetz reported a REQUIRED failure —
`[FAIL] codex sandbox CANNOT write` with `last output: Reading additional input
from stdin...`. The sandbox was never actually tested, and the real problem (an
expired Codex login) was invisible. Every doctor run also stalled for the full
180-second timeout.

**Two separate faults, both real:**

1. **Probe bug.** `check_codex_sandbox` ran `codex exec` without redirecting
   stdin. `codex exec` also accepts a prompt on stdin, so whenever doctor ran
   under a shell whose stdin stays open — `install.sh`, an ssh session, CI —
   Codex sat at "Reading additional input from stdin..." until `timeout` killed
   it. No file was written, so the probe blamed the sandbox. Fixed with
   `</dev/null`.
2. **Real Codex fault on hetz.** With stdin closed, the run fails immediately
   with HTTP 401 `refresh_token_invalidated` — "Your session has ended. Please
   log in again." The fix is `codex login` on the box; it is not a sandbox
   problem at all.

**The trap worth remembering:** `codex login status` on hetz still printed
"Logged in using ChatGPT" while every request returned 401. This is the
2026-07-16 lesson again — presence is not capability. Only a real run tells the
truth.

**Fix:** the probe now closes stdin and classifies the outcome into four
verdicts — wrote the file (OK), auth failure (WARN, with `codex login` as the
fix; doctor policy is that not-logged-in never fails a run), sandbox-helper
failure (FAIL, the 2026-07-16 Windows junction case), and timeout (FAIL, named
as a timeout instead of blamed on the sandbox).

**Prevention:** `tests/test-ai-devops-doctor-codex-probe.sh` asserts the stdin
redirect is present and drives all four verdicts through a fake `codex`.
