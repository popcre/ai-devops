# Headroom for Claude Code CLI on hetz — what was done, 2026-10-20

**Scope.** Make every Claude Code CLI process on the hetz VPS (especially the
remote workers under `~/.claude/remote/ccd-cli/`) route through the Headroom
token-compression proxy on `$HEADROOM_HOST:8787`. Companion to
[`headroom.md`](headroom.md) (how Headroom works) and
[`zcode-headroom-runbook.md`](zcode-headroom-runbook.md) (ZCode lane — **not**
in scope here).

**Session.** MiMo Desktop `ses_ffe5ea6727732ffetESkBk8L8f` on edge-dev.
**Owner ask.** "implement headroom for the Claude Code CLI running on Hetz",
then "read our own documentation about what hurdles we encountered … on
edge-dev … and edge-dev3 and the best way to do it on ubuntu" (skip
Windows-specific and ZCode-specific guidance).

---

## 1. What was already true

| Path on hetz | Routed through Headroom before this work? | Evidence |
|---|---|---|
| Shell `claude` / `claude -p` via `.bashrc` export above the non-interactive guard | Yes (Workflow A) | `export ANTHROPIC_BASE_URL=…:8787` at `/home/ai/.bashrc` line 18; a fresh `claude -p` produced a `client=claude-code` PERF line in `/home/ai/.headroom/logs/proxy.log` |
| Claude Remote / `claude-ssh` workers `~/.claude/remote/ccd-cli/<version>` | **No** | Every live `ccd-cli` process had `ANTHROPIC_BASE_URL=https://api.anthropic.com` in its environ and held TLS to `api.anthropic.com` (160.79.104.10 / 2607:6bc0::10) |

There were **17 live remote worker processes** at investigation time (2026-10-20
morning EDT). Shell CLI was proxied; the workers that actually run Albert's
remote Claude sessions were not.

## 2. Root cause

The `claude-ssh` remote launcher (`…/.claude/remote/srv/<hash>/server`) spawns
each worker with **`ANTHROPIC_BASE_URL=https://api.anthropic.com` baked into the
exec environment**, overriding whatever the parent shell or `.bashrc` had. The
parent daemon *did* have the Headroom URL in its own environ; the children did
not inherit it.

That is the same product behaviour edge-dev3 hit as **Workflow B′ trap 4** (see
[`headroom.md`](headroom.md) Workflow B′): a parent Claude process forces
`api.anthropic.com` on its Claude Code children. On a KDE desktop the parent is
Claude Desktop; on hetz the parent is the `claude-ssh` daemon. The lever is the
same: **wrap the executable path the parent execs.**

`~/.claude/settings.json` `env.ANTHROPIC_BASE_URL` is **not** a fix (Workflow B
measurement on 2.1.234: accepted, displayed, ignored for routing). On
2.1.299 a fresh CLI happened to hit the proxy even with `api.anthropic.com` in
its environ, but the long-lived remote workers did not — do not rely on
settings.json. The inert entry was cleared on hetz so status displays stop
lying.

## 3. What was implemented (PR #1886, merged `5fde85fe`)

### 3.1 Toolkit — `bin/ai-headroom`

New subcommands (also invoked automatically from `on` / `off`):

| Command | Effect |
|---|---|
| `ai-headroom wrap-remote` | For each executable under `~/.claude/remote/ccd-cli/` (override: `AI_HEADROOM_CCD_DIR`): if it is a raw ELF, `mv` it to `<name>.headroom-real` and install a bash wrapper as `<name>` that `export ANTHROPIC_BASE_URL='<proxy url>'` then `exec`s the real binary. Re-wrap rewrites the baked URL in place. |
| `ai-headroom unwrap-remote` | Restores each `<name>.headroom-real` over its wrapper. Used by `ai-headroom off`. |
| `ai-headroom status` | Reports `N wrapped -> Headroom` or `N UNWRAPPED -> DIRECT` / mixed (new Claude version). |
| `ai-headroom on` | Existing Linux/Windows switch **plus** `ccd_wrap_all`. |
| `ai-headroom off` | Existing escape hatch **plus** `ccd_unwrap_all`. |

Proxy URL is taken from `AI_HEADROOM_PROXY_URL` or `ai-private-config value
headroom_proxy_url`. On hetz, `ai-private-config` was not resolvable from
`/tmp`; the run used `AI_HEADROOM_PROXY_URL` taken from the `.bashrc` export.
That is a known operational detail: `wrap-remote` refuses to run with no URL
(same posture as `on`).

**Why a wrapper and not a config change.** The forced value is applied at
`execve` by the vendor launcher. Only code that runs *at the same exec boundary*
can override it. Running workers keep their old inode after `mv`, so nothing
live is killed — new spawns pick up the wrapper.

### 3.2 Tests

`tests/test-ai-headroom-remote-wrap.sh` (18 checks, offline, Windows Git Bash +
Linux): wrap moves binaries aside, wrapper bakes the URL, wrapper execs the real
binary with the forced URL even when the caller passes
`ANTHROPIC_BASE_URL=https://api.anthropic.com`, re-wrap covers a newly dropped
version and updates the URL without duplicating the real binary, status flags a
new raw binary, unwrap restores the ELF and removes the sidecar. Registered in
`config/ci-suites/test-ai-headroom-remote-wrap.sh.json`.

Focused evidence used for review gates: the new suite (18/18) and
`tests/test-action-taxonomy.sh` (29/29).

### 3.3 Docs (this file + `headroom.md`)

- Workflow A′ section in `headroom.md`: the gap, the wrapper, re-wrap after
  Claude updates, settings.json warning, edge-dev3 proof method, which
  edge-dev3 Ubuntu traps do **not** apply on this VPS and why.
- Cross-link to Workflow B′ trap 4 (same lever) and trap 5 (how to prove
  routing).
- Quick-reference rows for `wrap-remote` / `unwrap-remote`.

## 4. edge-dev3 / Ubuntu lessons applied (from our own docs)

From `headroom.md` Workflow B′ and issue
[#1869](https://github.com/popcre/ai-devops/issues/1869) — applied where they
matter on Ubuntu/hetz; Windows and ZCode paths deliberately ignored:

| Lesson | Applied on hetz? |
|---|---|
| Trap 4: parent forces `api.anthropic.com` → wrap the child binary | **Yes** — that is this entire change. |
| Trap 5: do not trust `/proc/<pid>/environ` (Electron clears it); prove with `proxy.log` `path=/v1/messages` | **Yes** — live proof is the proxy log / PERF lines, not environ alone. |
| settings.json env is inert and misleading | **Yes** — cleared on hetz. |
| `.bashrc` export must stay above the non-interactive `case $-` guard | Already correct (Workflow A); left untouched. |
| DietCode/Scaledown `claude` wrapper stomps `ANTHROPIC_BASE_URL` → chain `SCALEDOWN_PROXY_UPSTREAM` | **N/A on hetz** — no `~/.scaledown/config.json`; `~/.local/bin/claude` is a real ELF symlink to `versions/2.1.292`. |
| KDE `~/.config/environment.d/50-headroom.conf` + `systemctl --user set-environment` for GUI apps | **N/A on hetz** — no KDE desktop; workers are `claude-ssh`, not a GUI session. |
| Windows USER env var / tray Quit | **Not used** (Windows-specific). |
| ZCode HTTPS front / private CA / `ai-zcode-headroom` | **Not used** (ZCode-specific). |

## 5. Live proof (hetz, user `ai`, 2026-10-20)

Applied wrap to **3** versioned binaries under
`/home/ai/.claude/remote/ccd-cli/` (`2.1.289`, `2.1.295-8b2928c330c4`,
`2.1.299-686c67ec1014`).

1. `ai-headroom status` → `3 wrapped -> Headroom (new spawns only)`.
2. Spawned the wrapped `2.1.299-…` with the launcher's env
   (`ANTHROPIC_BASE_URL=https://api.anthropic.com`). Child environ showed
   `ANTHROPIC_BASE_URL=http://…:8787` (wrapper won).
3. Decisive check (Workflow B′): `/home/ai/.headroom/logs/proxy.log` lines
   `path=/v1/messages status=200` with `client=claude-code`, plus PERF rows
   (e.g. `msgs=2 … client=claude-code` at 10:55 AM EDT and a one-turn proof at
   11:00 AM EDT) and matching `savings_events.jsonl` rows.
4. `settings.json` `env` cleared; status no longer shows a lying entry.

**Residual (by design).** The 17 already-running remote workers keep their old
inode and stay on the direct path until that session restarts. New spawns are
proxied. After any Claude Code update that drops a **new** versioned binary,
run `ai-headroom on` (or `wrap-remote`) again — `status` flags the gap.

**Escape hatch.** `ai-headroom unwrap-remote` or `ai-headroom off` restores raw
binaries. Does not touch `headroom.service`, `headroom-zcode`, or
`zcode-headroom-tls`.

## 6. Change set (PR #1886)

| File | What |
|---|---|
| `bin/ai-headroom` | `wrap-remote` / `unwrap-remote`, `on`/`off`/`status` integration |
| `tests/test-ai-headroom-remote-wrap.sh` | Offline wrap/unwrap/status suite |
| `config/ci-suites/test-ai-headroom-remote-wrap.sh.json` | CI discovery |
| `docs/headroom.md` | Workflow A′ + quick reference |

Commits: `6b4211de` (feature), `d8c48df4` (live-proof row), `680771ed`
(edge-dev3 lesson alignment). Squash-merged to `main` as `5fde85fe` on
2026-10-20. PR: https://github.com/popcre/ai-devops/pull/1886

Class: `code` (toolkit + docs). The host action (wrapping user binaries under
`/home/ai/.claude/remote/ccd-cli/`) is client wiring on the ai user's home —
the same category as `ai-headroom on`, **not** production infrastructure
(`headroom.service`, Coolify, terraform, gcloud). A `production` class was
declared first and then corrected to `code` after `ai-task-gates check --before
production` demanded a reviewer APPROVE for a host user-home wrap; the change
set never touched production services.

## 7. Operator checklist (Ubuntu / hetz)

```bash
# after any Claude Code update on the box:
ai-headroom on          # or: ai-headroom wrap-remote
ai-headroom status      # must say "wrapped -> Headroom"

# prove a worker is actually proxied (do not trust environ alone):
ssh vps2 'grep path=/v1/messages /home/ai/.headroom/logs/proxy.log | tail'

# escape hatch:
ai-headroom unwrap-remote   # or: ai-headroom off
```

Do not wrap `headroom.service` or copy the ZCode HTTPS/CA stack onto this lane.

## 8. Related records

- [`headroom.md`](headroom.md) — proxy architecture, Workflows A / A′ / B / B′ / C
- [`zcode-headroom-runbook.md`](zcode-headroom-runbook.md) — ZCode only
- Issue [#1869](https://github.com/popcre/ai-devops/issues/1869) — edge-dev3
  Ubuntu wiring (source of Workflow B′ lessons)
- Issue [#1859](https://github.com/popcre/ai-devops/issues/1859) — ZCode →
  hetz Headroom (separate lane)

Posted by MiMo chat ses_ffe5ea6727732ffetESkBk8L8f on edge-dev
