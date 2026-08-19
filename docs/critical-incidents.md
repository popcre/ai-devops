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
