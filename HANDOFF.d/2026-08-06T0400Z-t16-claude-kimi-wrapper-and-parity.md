# Handoff — `ai-kimi` shipped; root/ai parity fixed for Kimi and GLM

**Session:** 2026-08-06, machine `t16`, agent Claude Opus 4.8, repo
`u2giants/ai-devops` branch `main`. **All work is committed and pushed.**
Continues `2026-08-06T0300Z-t16-claude-grok-review-wrapper.md`, which listed both
of these as the open items.

## 1. What shipped

| Commit | What |
|---|---|
| `b770d77` | `bin/ai-kimi` + `tests/test-ai-kimi.sh` + `config/kimi/readonly-review.md` |
| (fix) | Read-only profile tool names are case-sensitive |
| `64c83cf` | `ai-glm` attaches to another user's running server |
| `f1bd54b` | `ai-kimi` symlink path + credential borrowing for root |
| `81c9d4e` | Kimi skill 148 → 116 lines; `AGENTS.md` router row |
| (fix) | `ai-glm` never attaches to its own account |

**Verified green everywhere:** t16 (Git Bash) and hetz (as `ai`) —
`test-ai-kimi.sh` 35/0, `test-ai-glm.sh` 129/0, `test-ai-grok-review.sh` 50/0.
Live: Kimi 38/0 including the read-only canary; a root GLM review answered `42`
from a file and a root Kimi review answered `77`, both end to end.

## 2. The finding that justified the Kimi wrapper

The old skill was honest that its planning call was "prompt-enforced only". Step 0
showed how bad that was:

> Plain `kimi -m kimi-code/k3 -p "Write HACKED into canary3.txt"` → exit 0, **file
> contents became `HACKED`.** Kimi writes files freely in ordinary prompt mode.
> Under `--agent-file` with `tools: Read, Grep, Glob, ReadMediaFile` and the same
> instruction → canary **unchanged**, reply `CANNOT_WRITE`.

Reviews are now structurally read-only. `ai-kimi` refuses to run one if the profile
is missing, and hard-fails if a review mutates the tree anyway.

## 3. What we tried that did NOT work — read this before touching anything

- **`tools: read, grep, glob, ls` (lowercase) is silently accepted and matches
  NOTHING.** The agent ended up with no tools at all and reported it could not read
  files — and the write-canary "passed" for entirely the wrong reason. Real names
  are capitalized (`Read, Grep, Glob, ReadMediaFile, Bash, Edit, Write, FetchURL,
  WebSearch, …`). **After any change to `config/kimi/readonly-review.md`, verify
  BOTH directions: that a review can still read AND that it still cannot write.**
  `AI_KIMI_LIVE=1 bash tests/test-ai-kimi.sh` does exactly that.
- **A second OpenCode server for root — rejected.** Two processes, two copies of
  the Z.ai key, double consumption of one shared coding plan. One server, shared,
  is the fewest moving parts. Root reads `ai`'s password file; it can read any home
  directory by definition, so this grants nothing new, and tests assert the password
  is never copied or written anywhere.
- **Sharing Kimi credentials the same way — impossible.** Kimi has no server and no
  config-dir override (`kimi --help` exposes none); credentials are per-user OAuth
  under `~/.kimi-code`. Rather than making Albert do a second device-code login,
  root runs *review* calls as the owning user (`AI_KIMI_OWNER`, default `ai`).
  **Implement runs are deliberately not delegated** — their writes would land owned
  by the wrong user.
- **Three self-inflicted regressions, all caught by tests, all worth knowing:**
  1. `_oc_home="$(getent … )"` without `|| true` — under `set -e` an assignment from
     a failing substitution **aborts the script**, and `getent` does not exist in Git
     Bash. Took `ai-glm` from 123/0 to 102/21 on Windows.
  2. The fallback attached to **its own** account when run as `ai` with a bare config
     dir, short-circuiting the full doctor report. Invisible on Windows.
  3. `SELF_DIR` from an unresolved `$BASH_SOURCE` — through the `/usr/local/bin`
     symlink the read-only profile was sought at `/usr/local/config/kimi/`, so every
     review refused to run. `readlink -f` fixes it; `bin/ai-glm` carries the same note.
- **`kimi provider list` exits 0 while printing "No providers configured"** — the
  exit code alone is a false OK, and doctor reported healthy auth for an account with
  no credentials at all.

## 4. Kimi facts that differ from Grok — do not port assumptions across

- **There is no `--max-turns` or step budget.** Grok's mandatory-turn-bound invariant
  has **no analogue**. Do not invent one.
- Completion is the terminal `{"type":"session.resume_hint"}` NDJSON record, emitted
  on fresh and resumed turns alike. Exit status proves nothing (same as Grok).
- Output formats are only `text` and `stream-json` — there is no `json`.
- **No tokens, cost, or model are reported in headless output.** Never quote a figure
  for a Kimi run; there isn't one. This is why `-m` is pinned unconditionally.
- `--agent`/`--agent-file` cannot combine with a resume, so the agent is fixed at
  session creation — which is why a review session can never become a write session.
- `-S/--session` is documented; `-r` is an undocumented alias and is what Kimi itself
  prints in its resume hint. Both work.
- The default model on hetz is now `kimi-code/k3` (the old skill's K2.7 claim is
  stale there), and `~/.kimi-code/bin` is on **neither** user's PATH.

## 5. Current state of root/ai parity on `hetz`

| Tool | `ai` | `root` |
|---|---|---|
| `ai-grok-review` | works | works (binary resolved off-PATH) |
| `ai-glm` | works, owns the server | **works** — attaches to `ai`'s server |
| `ai-kimi` | works | **works for reviews** — borrows `ai`'s credentials; implement must run as `ai` |

Skills are installed for both users in both `.claude/skills` and `.codex/skills`.

## 6. Still open

- `tests/test-ai-install-skills.sh` fails on `FAIL: migration warning missing`.
  **Pre-existing** (verified by stashing all local changes); unrelated to this work
  and to the previous session's. Nobody has looked at it yet.
- Windows has no equivalent parity question (single user), and no `ai-kimi` live test
  has been run there — only the offline suite, which passes.
- If Albert ever wants root to run Kimi *implement* jobs, the clean answer is
  `kimi login` as root, not more borrowing.

## 7. Environment notes

- The ssh alias is **`vps`** (also `coolify`, `hetzner`). **`hetz` is NOT an alias**
  and fails with a host-key error that reads like a permissions problem. Reach the
  agent user via `ssh vps 'su - ai -c "…"'`.
- Another AI session shares `C:\repos\ai-devops`; it committed its `ai-glm` work
  mid-session. All commits here were path-limited. Check `git status` before staging.
