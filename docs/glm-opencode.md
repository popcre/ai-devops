# GLM on OpenCode — architecture, operations, migration

`ai-glm` gives Claude and Codex **named, persistent GLM sessions**. A session remembers
everything said in it, survives a server restart, and keeps its prefix warm so Z.ai can
serve most of the context from cache.

It replaces `ai-glm-agent`, which ran GLM inside a Claude Code child process with
`--no-session-persistence` — every call was a brand-new conversation.

- Qualified OpenCode version: **1.18.12**, qualified 2026-08-03 on Hetz.
- Qualified provider/model: **`zai-coding-plan` / `glm-5.2`** (Z.ai Coding Plan).
- Last commit containing the old harness: recorded in the migration PR.

---

## 1. Architecture

```
Claude or Codex
  → ask-glm skill
  → ai-glm                        (the only supported interface)
  → 127.0.0.1:4096                (OpenCode server, systemd USER service, HTTP Basic)
  → named OpenCode session        (agent glm-review or glm-implement, model pinned)
  → Z.ai Coding Plan
  → GLM-5.2
```

### Why OpenCode, and why Claude Code was removed

The requirement was a conversation that lives across calls. Claude Code was being used as
a headless host with session persistence explicitly disabled, so it could never satisfy
that. OpenCode has a documented session API (create, prompt, message, fork, diff, revert,
abort, delete), runs headless on loopback, and already tracks a git snapshot per message.

### Trust boundaries

| Boundary | Control |
|---|---|
| Network | Server binds `127.0.0.1` only. `ai-glm doctor` fails if anything else is listening on the port. |
| Local users | HTTP Basic from `~/.config/ai-devops/opencode/server-password` (0600). Unauthenticated requests get 401. |
| GLM → your files (review) | The `glm-review` agent has **no** write, edit, patch, or bash tool. |
| GLM → your files (implement) | A throwaway CLONE with its git remote removed, created and destroyed inside one command. |
| GLM → the network / your remote | Review agent has no bash tool. Implement has one, but its sandbox has no remote to push to. `webfetch: false` on both. |
| Secrets | Key resolved from 1Password at exec time; never in a unit file, argv, log, report, or git. |

### What actually enforces read-only

Measured on 1.18.12, and this is the single most important implementation fact:

- The **session-creation `permission` array does nothing.** A session created with
  `edit`/`write`/`bash` denied still let GLM edit a file.
- The **agent-file `permission:` map for bash does nothing either.** An agent with
  `permission.bash: {"git push*": deny, "curl*": deny, "*": allow}` executed
  `git push origin HEAD` and `curl https://example.com` without a prompt or a refusal.
- The **agent-file `tools:` map is the only thing that works.** Setting
  `bash: false, write: false, edit: false, patch: false` genuinely removes those tools;
  GLM reports it does not have them and refuses.

Consequence, and this is the design's load-bearing decision:

- `glm-review` runs with `bash: false`. It genuinely cannot run anything. If a review
  needs a command run, the calling agent runs it and pastes the output.
- `glm-implement` runs with `bash: true` so GLM can actually build and test its own work.
  That is only safe because its sandbox is a **clone with the remote removed**, not a
  `git worktree`. A worktree shares the parent's `.git`, and therefore its remotes, so
  `git push` from inside one reaches the real GitHub. Measured: an agent denying
  `git push*` and `curl*` ran both without a prompt. **The deny map is not a control.
  The absence of a remote is the control.**

### Prompt caching

Every assistant message carries
`tokens: {input, output, reasoning, cache: {read, write}}`. `cache.read` is recorded in
each report under `.ai/reviews/`. Values in the low thousands are routine on a warm
session, and caching survived a server restart in testing. This is measured, not assumed;
there is deliberately no separate cache-measurement subsystem.

---

## 2. Windows

GLM runs locally on Windows too. There is one implementation, not two: the
security-critical launcher and the `ai-glm` client are the same bash scripts used on
Ubuntu. Only the service manager differs (Scheduled Task instead of systemd), and
`ai-glm doctor` / `ai-glm server` detect the platform and check the right things.

Albert never opens Git Bash. `ai-glm` is on the PATH and the syntax is identical to
Ubuntu.

`bin/setup-machine.ps1` runs this automatically, so a normal machine setup needs no
extra step. To install or repair GLM on its own:

```powershell
cd C:\repos\ai-devops
git pull
.\bin\setup-opencode-glm.ps1
```

It installs its own prerequisites via winget (Git for Windows, Node.js LTS, the
1Password CLI, jq) rather than asking anyone to install them by hand. Do **not** run it
elevated; everything lands in the user profile.

It then installs the pinned OpenCode build, copies the canonical config and agents,
generates a loopback-only server password restricted to that user account, writes the
launcher, installs an `ai-glm` command on the user PATH, and registers the
`AiDevOps-OpenCodeGlm` scheduled task that starts the server at logon.

After that the command is the same as on Ubuntu, from a new PowerShell window inside
any repository:

```powershell
ai-glm doctor
ai-glm new my-review --prompt-file brief.md
```

`ai-glm` on Windows is a `.cmd` shim that runs the same bash script through Git Bash.
It passes arguments straight through rather than re-parsing them as one string, so
prompts containing spaces or quotes survive. Nobody needs to open Git Bash.

Service control on Windows (`ai-glm server ...` is systemd-only):

```powershell
Start-ScheduledTask   -TaskName AiDevOps-OpenCodeGlm
Stop-ScheduledTask    -TaskName AiDevOps-OpenCodeGlm
Get-ScheduledTaskInfo -TaskName AiDevOps-OpenCodeGlm
```

Windows notes:
- `HOME` must be the local profile. A roaming `Z:` home would send the install to a
  network drive nothing reads back; the installer uses `%USERPROFILE%` for that reason.
- The password file is locked to your user account with an explicit ACL, which is the
  NTFS equivalent of `chmod 600`.
- SSH to the Ubuntu host still works and is unchanged. Use whichever is closer to the
  repository you are actually editing.

---

## 3. Operations

Start a debate:
```bash
cd /worksp/shared-db
ai-glm new sample-status-review --prompt-file /tmp/brief.md
```

Continue it (this is the point — do not start a new session per question):
```bash
ai-glm ask sample-status-review --prompt-file /tmp/next.md
```

From Codex, set the caller so the two agents keep separate sessions:
```bash
AI_GLM_CALLER=codex ai-glm new sample-status-review --prompt-file /tmp/brief.md
```

Everything else:
```bash
ai-glm list                     # every session, all repos
ai-glm show <name>              # session metadata
ai-glm transcript <name>        # full ordered conversation
ai-glm diff <name>              # OpenCode's own diff for the session
ai-glm abort <name>             # stop a stuck turn
ai-glm delete <name>            # remove it locally and on the server
ai-glm doctor                   # full PASS/WARN/FAIL check, nonzero on failure
ai-glm server status|start|stop|restart
```

Scoped implementation:
```bash
ai-glm implement fix-token-rotation --prompt-file /tmp/task.md
# writes .ai/reviews/glm-fix-token-rotation-<ts>.patch, then:
git apply --check "$patch" && git apply "$patch"
```

### Diagnosing

| Symptom | Cause | Fix |
|---|---|---|
| `server is not answering` | Service down or failed | `ai-glm server start`; `journalctl --user -u opencode-glm -n 50` |
| `wedged on an un-approvable permission request` | OpenCode 1.18.12 returns HTTP 400 from `/api/session/<id>/permission` while a `glob`/`grep` request is pending, so it can never be approved | `ai-glm abort <name>`. If the stuck tool is glob or grep, a very large untracked directory is being walked — add it to `.gitignore` |
| Turn times out, tool still running | Same underlying class | `ai-glm abort <name>`, then retry |
| `session is orphaned` | Local metadata exists, server session does not | `ai-glm delete <name>` then `ai-glm new <name>`. A silent replacement would falsely imply continuity |
| `session is busy` | Another `ai-glm` call holds the lock | Wait, or raise `--lock-timeout` |
| `review session CHANGED the working tree` | A review wrote something (should be impossible) | Session is marked failed; inspect `git status` before anything else |
| `ZAI_API_KEY resolved EMPTY` | The `op://` reference points at a blank field | Fix `ZAI_API_KEY` in `config/mcp.env.example` and re-run `setup-secrets.sh` |
| Unit sits in `failed` | `StartLimitBurst` tripped after repeated crashes | Fix the cause, then `ai-glm server start` |

### Upgrading OpenCode

1. Branch. Change `config/opencode/version`.
2. `bin/setup-opencode-glm.sh` (installs to a new versioned prefix).
3. `bash tests/test-ai-glm.sh`, then `AI_GLM_LIVE=1 bash tests/test-ai-glm.sh`.
4. Re-verify the three enforcement facts above; if a future version makes the
   `permission` maps work, bash could be re-enabled for `glm-implement`, but only with a
   test proving a deny is honoured.
5. `ai-glm doctor`. Close or delete active sessions rather than silently resuming them
   under a new version.

### Rollback

```bash
systemctl --user disable --now opencode-glm.service
git revert <migration commits>
bin/ai-install-skills
```
Export anything you need first (`ai-glm transcript`, the files under `.ai/reviews/`).
OpenCode sessions cannot be resumed by the old harness; there is no cross-harness
continuity and pretending otherwise would be a lie. Do not delete `~/.local/state/ai-devops/glm`
during rollback — keep it for diagnosis.

---

## 4. Migration record

**Removed**
- `bin/ai-glm-agent` → replaced by a stub that fails and points at `ai-glm`. Delete the
  stub once every caller and doc is migrated.
- `bin/ai-glm-agent.ps1`, `tests/test-ai-glm-agent.sh`, `tests/test-ai-glm-agent.ps1`.
- `ZAI_ANTHROPIC_BASE_URL` and `ZAI_GLM_MODEL` from `config/mcp.env.example`
  (the model is pinned in the agent files now).
- `~/.config/ai-devops/glm-claude/` — the isolated Claude config the old harness used.

**Added**
- `bin/ai-glm`, `bin/setup-opencode-glm.sh`
- `config/opencode/{version,opencode.json,agent/glm-review.md,agent/glm-implement.md}`
- `config/systemd/opencode-glm.service`
- `tests/test-ai-glm.sh`, this document, rewritten `skills/shared/ask-glm/SKILL.md`

**Kept**: `ZAI_API_KEY` and its 1Password reference, unchanged.

**Also changed**: `.claude/` is now gitignored. It had grown to 1.1 GB of untracked
session transcripts and AI worktrees, and because AI worktrees live inside it, a `glob`
from inside one walked its own parent and hung the session. Ignoring it is what made
`glob`/`grep` usable again.

**Windows**: GLM runs locally through the same `ai-glm` Bash client and OpenCode server
used on Ubuntu. Git Bash hosts the process and Task Scheduler manages the loopback-only
server; users invoke the installed `ai-glm` command from PowerShell or Codex/Claude.

### Known limitations

1. Review sessions have no Bash tool, so the parent must run any diagnostic command a
   review needs and provide its output in the next turn. Implementation sessions have
   Bash only inside their disposable remote-less clone; GLM can run tests there, but the
   parent must still independently verify the resulting patch and tests before applying it.
2. `POST /api/session/<id>/wait` returns `ServiceUnavailableError` in 1.18.12, so
   completion is polled.
3. `/api/session/<id>/permission` returns HTTP 400 while a `glob`/`grep` permission is
   pending. `ai-glm` treats that 400 as a hard error rather than waiting forever.
4. The Z.ai key is visible in `/proc/<pid>/environ` to the same user and to root. That is
   inherent to putting it in the process environment and is stated here rather than
   glossed over.
5. `config/opencode/*` is force-copied on every `install.sh` run, deliberately unlike
   `models.env`/`server.env`. The agent files carry the only working read-only
   enforcement, so the repo copy must always win. Machine-local tuning goes in
   `AI_GLM_PORT`, not in an edited `opencode.json`.


---

## 5. Hard-won constraints - do not "fix" these

> Active implementation plan: [`../plan_ai-glm-permission-deadlock.md`](../plan_ai-glm-permission-deadlock.md).
> Read its STATUS table before changing permission polling; do not re-derive or re-plan
> work that it records as complete.

Every item here was established by something breaking. Each says what to keep and what
happens if you change it. If you are about to simplify one of these, read the reason
first and then re-measure before touching it.

### GLM / OpenCode

1. **Only the agent-file `tools:` map enforces anything.** The session-creation
   `permission` array and the agent-file `permission.bash` map are both no-ops in
   1.18.12 - separately measured, both let GLM edit files and run `git push`. Never
   present either as a safety control.
2. **`glm-implement` gets a clone with `git remote remove origin`, never a worktree.**
   A worktree shares the parent's remotes and would let an enabled bash tool push to the
   real GitHub. If you ever swap this back to `git worktree add`, you must also set
   `bash: false` in the same change.
3. **A turn is complete only when `finish == "stop"` AND the server has been idle for
   two consecutive polls.** "Session id absent from `/session/status`" alone is NOT
   completion: a wedged turn looks identical to a finished one, and treating it as
   success silently reports an empty review as a real one.
4. **`POST /api/session/<id>/wait` does not work in 1.18.12** (`ServiceUnavailableError`).
   Do not "simplify" the poller to use it without checking the pinned version first.
5. **HTTP 400 from `/api/session/<id>/permission` is the stuck-permission sentinel.**
   While a `glob`/`grep` permission is pending the endpoint cannot even list it, so it
   can never be approved. Treat that 400 as a hard error naming the stuck tool; do not
   retry or wait it out.
6. **Keep `.claude/` and `claude_chats/` gitignored.** They reached 1.1 GB and 664 MB.
   AI worktrees live inside `.claude/`, so a `glob` from inside one walked its own parent
   and hung the session forever. Ignoring them is what made `glob`/`grep` usable.
7. **The model is pinned in `config/opencode/agent/*.md`.** The provider's own default
   resolves to `glm-5.2-highspeed`, which is not what we qualified. `ai-glm` also rejects
   a substituted model at runtime; keep both.
8. **`config/opencode/*` is force-copied on every install.** This is a deliberate
   exception to the repo's copy-only-if-absent convention, because the agent files carry
   the only working read-only enforcement. Machine-local tuning belongs in `AI_GLM_PORT`.
9. **No per-call overrides** (`--model`, `--agent`, `--directory`, ...). A stable request
   prefix is what makes provider caching work and a stable agent is what keeps a review
   read-only. Adding one override quietly costs both.

### Windows - every one of these cost a failed setup run in front of Albert

10. **Repo-owned `.ps1` files must be pure ASCII.** Windows PowerShell 5.1 reads a
    BOM-less `.ps1` as Windows-1252, so a UTF-8 em dash (`E2 80 94`) decodes to
    U+201D RIGHT DOUBLE QUOTATION MARK, which PowerShell accepts as a string delimiter.
    Two em dashes corrupted quote state for a whole file and produced "The string is
    missing the terminator" hundreds of lines later, aborting setup on all three
    machines and silently preventing skills from ever installing.
    `tests/test-windows-scripts.sh` enforces this.
11. **Never hardcode a drive letter or user path.** `C:\repos\ai-devops` defaults made
    setup clone a second copy of the repo, and made the GLM installer refuse to run from
    `D:\repos\ai-devops`. Derive the repo from `$PSCommandPath`.
12. **Use `%USERPROFILE%`, never `$HOME`, and never Git Bash's `$HOME`.** With a roaming
    profile `$HOME` can be a network drive that nothing reads back. The generated
    launcher and the `ai-glm.cmd` shim both pin `HOME` from `%USERPROFILE%` for exactly
    this reason.
13. **`op run -- "$0"` does not work on Windows.** `op.exe` is a native Windows process
    and cannot exec an extension-less shell script. The launcher re-execs as
    `-- "C:/Program Files/Git/bin/bash.exe" "$0"`, naming bash by absolute path because
    Git's `bin` is not reliably on the Windows PATH.
14. **`\$` is not an escape inside a PowerShell here-string.** PowerShell expands the
    variable anyway and leaves a stray backslash. Use a backtick. This shipped twice.
15. **Wait for the port to be free between the smoke test and the scheduled task.**
    Killing bash does not reliably kill the opencode child, and the socket lingers, so
    the real server could not bind. This is what made 916 fail while the other two
    machines won the same race.
16. **The scheduled task must log to a file.** Task Scheduler discards a task's output,
    so without `opencode-glm-service` writing `server.log` a failure there is completely
    invisible.
17. **`stat -c %a` is meaningless on NTFS.** It returns a synthesised mode whatever the
    ACL says, so the 0600 check failed on all three machines while the files were
    correctly locked. Windows permissions are checked with `icacls`.
18. **A check that cannot fail is worse than no check.** `no secret in the systemd unit`
    passed on Windows because it grepped a file that does not exist there. Every check
    must target something that actually exists on the platform it runs on.
19. **`ai-glm doctor` must never abort part-way.** A failing command substitution under
    `set -e` ended the report after three lines on Windows. Doctor must print every check
    and exit non-zero. Tested against a machine with nothing installed.
20. **Every failure message must name the next command.** A bare
    "FAIL health endpoint answers" cost a full round trip. Doctor now distinguishes
    "setup never ran" from "service is down" and prints the service log inline.

### Process lessons

21. **Do not edit a script while a copy of it is running.** Bash re-reads the file as it
    executes; a mid-run edit killed a GLM implement run and left an orphaned sandbox.
22. **The installed command is a symlink into the main checkout, not your worktree.**
    Testing `/usr/local/bin/ai-glm` after editing a worktree copy tests the old code.
23. **Fix a bug class, not one instance.** The hardcoded-path bug was fixed in
    `setup-machine.ps1` and left in `setup-opencode-glm.ps1`, which cost another round
    trip. When you fix something in one script, grep for it in all of them.
