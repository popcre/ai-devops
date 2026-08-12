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

