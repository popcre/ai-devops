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
| GLM → your files (implement) | A throwaway git worktree, created and destroyed inside one command. |
| GLM → the network / your remote | No bash tool in either agent, `webfetch: false`. |
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

Consequence: **both** agents run with `bash: false`. GLM cannot run tests. The calling
agent runs them and feeds failures back as another turn. Enabling bash would mean
unrestricted shell in a worktree that shares the parent repo's remotes.

### Prompt caching

Every assistant message carries
`tokens: {input, output, reasoning, cache: {read, write}}`. `cache.read` is recorded in
each report under `.ai/reviews/`. Values in the low thousands are routine on a warm
session, and caching survived a server restart in testing. This is measured, not assumed;
there is deliberately no separate cache-measurement subsystem.

---

## 2. Operations

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

## 3. Migration record

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

**Windows**: there is no local GLM server. `bin/ai-glm-agent.ps1` is gone; Windows Claude
and Codex sessions run `ai-glm` on the Ubuntu host over the existing SSH workflow, inside
the repository they are working on.

### Known limitations

1. No bash in either agent, so GLM cannot run tests. The parent runs them.
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
