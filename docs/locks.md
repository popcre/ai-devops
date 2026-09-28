# Lock inventory

Every lock used by `bin/`, written for issue
[#1002](https://github.com/popcre/ai-devops/issues/1002) step 1. The table is
the complete answer to `grep -rnE 'flock|lock\.d|\.lock' bin` (62 hits,
verified 2026-09-28); every hit line is cited in the Grep hits column, so a
new lock site added without a row here makes this file wrong, not optional.

Recovery policy for the Linux `flock` sites lives in `bin/ai-lock-doctor`
(issue #1002 step 2): on a lock wait timeout the call site runs the doctor,
which finds every process holding the lock's inode, classifies each holder as
`our-tool` or `foreign`, and — only under `--recover`, and only for
`our-tool` holders at least as old as the wait budget — terminates them. A
foreign holder is reported with full evidence and never touched.

## A. The Linux 1Password refresh lock (`flock`)

One file, `$CFG_DIR/op-refresh.lock` (Linux:
`~/.config/ai-devops/op-refresh.lock`), serializes every `op` read/run on a
machine. `flock --close` (added by #939) keeps the descriptor out of `op`'s
children; the kernel releases the lock when the last holder's descriptor
closes, so a "stuck" flock is always a live holder, never a dead one.

| Where | Acquire / wait | Release | Staleness handling before #1002 |
|---|---|---|---|
| `bin/setup-secrets.sh:283` (generated MCP launcher) | `flock --close -w 90` | kernel, on command exit | none: after 90 s the launcher prints "serialized MCP secret refresh failed" and exits 1 |
| `bin/setup-secrets.sh:317` (generated remote launcher) | `flock --close -w 90` | kernel | none: "serialized fallback FAILED" and exit 1 |
| `bin/ai-qwen:428` (`cmd_store_key`; path resolved at `ai-qwen:372-390`) | `flock --close -w 120` | kernel | none: "could not refresh Qwen key from 1Password" (die) |
| `bin/ai-muse:476` (`read_key_from_op`; path at `ai-muse:474`) | `flock --close -w "$budget"` (default 120, `ai-muse:472`) | kernel | none: "Muse key refresh failed or the shared 1Password lock is busy" |
| `bin/ai-deepseek-agent:377` (re-exec boundary; `flock` check at `:376`) | `flock --close -w 120` | kernel | none: re-exec exits nonzero |

Grep hits covered: `setup-secrets.sh:283,317`; `ai-qwen:372,374,388,390,414,
427,428`; `ai-muse:472,474,476`; `ai-deepseek-agent:376,377,319` (the comment
naming the Git Bash limitation of the same boundary).

## B. The shared Windows credential lock (`credential.lock.d`, mkdir)

Muse owns `~/.local/state/ai-devops/muse/credential.lock.d` and publishes an
owner record (`pid winpid token`). Qwen and DeepSeek reuse it because Git Bash
has no `flock`.

| Where | Acquire / wait | Release | Staleness handling before #1002 |
|---|---|---|---|
| `bin/ai-muse:481` (`muse_credential_acquire`, publish `muse_credential_publish`) | poll until `budget` (120 s default) | `release_credential_lock` (`ai-muse:161`) removes only its own token | owner record: liveness ×3 with winpid (`ps -W`); legacy pid-only: never reclaimed on Windows; no pid at all: reclaimed after 60 s |
| `bin/ai-qwen:527+` `lock_acquire` (call at `ai-qwen:418` inside `cmd_store_key`, path via `qwen_shared_credential_lock_path`) | poll until 120 s deadline | `lock_release` (`ai-qwen:574`) removes only its own token | owner record: liveness ×3 with winpid; legacy pid-only (Muse's old format): never reclaimed on Windows — `ai-qwen:545` refuses; no pid: reclaimed after 7200 s |
| `bin/ai-deepseek-agent:322` (inline `acquire_lock`/`publish_lock`) | poll until 120 s deadline | inline `release_lock`, token-checked | owner record only: liveness ×3 with winpid; refuses every legacy lock without a winpid ("Wait or fail closed") |

Grep hits covered: `ai-muse:481`; `ai-qwen:414` (comment), `ai-qwen:372,388`
(Windows path branch of `qwen_shared_credential_lock_path`);
`ai-deepseek-agent:322`.

## C. Portable per-session mutexes (`*.lock.d`, mkdir + owner pid)

Used by the reviewer wrappers for implementation/review/repository scopes
because `flock` does not exist in Git Bash.

| Tool | Path builders (grep hits) | Acquire / release | Staleness handling |
|---|---|---|---|
| `bin/ai-qwen` | `lock_path`/`repolock_path`/`reviewlock_path` (`492,493,498`; comment `501`) | `lock_acquire` (`527`) / `lock_release` (`574`) | liveness ×3 (winpid fallback); tombstoned reclaim keyed by owner token; dead-lock tombs older than 1440 min swept |
| `bin/ai-kimi` | `lock_path`/`repolock_path`/`reviewlock_path` (`529,530,535`; comment `538`) | `lock_acquire` / `lock_release` (rm -rf) | pid dead → `rm -rf` and re-mkdir immediately |
| `bin/ai-grok-review` | `lock_path`/`repolock_path`/session+work lock builders (`505,507,513,523`; comment `549`) | `lock_acquire` (`551`) / per-scope release | pid alive → busy; dead owner: repo locks retained for manual reconciliation (unconfirmed remote completion), pre-provider work locks reclaimed (`591`); scans over lock sets at `1963,2014` |
| `bin/ai-glm` | session locks `$rid--$caller--$name.lock.d` (`350`, comment `352`, acquire `2114`, pid read `2284`); meta update lock `.update.lock.d` (`563`); collision guards (`2055,2056,2072,2073`); orphan sweep guards (`2189,2247,2255`) | lock dir with pid file; released by the owning session | pid-file record; collision and orphan logic treats an existing lock as authoritative (fail closed) |
| `bin/ai-muse` | session lock `lock_session` (`219`) | token + pid publish; `unlock_session` | pid dead or unparsable owner older than 1 min → quarantine and retry (3 attempts) |

## D. One-shot mkdir locks (tick, run, and build serialization)

| Tool | Lock (grep hits) | Acquire / release | Staleness handling |
|---|---|---|---|
| `bin/ai-blocker-watch` | tick lock (`1073`, release `1080`) | `mkdir` / `rmdir` on EXIT | age > wake timeout + 5 min → `rmdir` + re-`mkdir` |
| `bin/ai-reviewer-start-watch` | tick lock (`46`, stale config read `66`) | `mkdir` / `rm -rf` on EXIT | age > `lock_stale_minutes` → break with a note |
| `bin/ai-gh` | throttle lock `lock.d` (`61`) | `mkdir` + owner record; serialized reclaim gate | stale after `AI_GH_LOCK_STALE_SECONDS` (90 s); reclaim itself gated, gate self-heals after 30 s |
| `bin/ai-memory-sync` | hub lock (`95`) | `mkdir` / `rmdir` on EXIT | none: concurrent sync fails loudly |
| `bin/ai-review-scoreboard` | ledger lock (`22`) | `mkdir`, waits `LOCK_WAIT` s / `rmdir` on EXIT | none: busy after the wait → die |
| `bin/ai-run-task` | run lock (`44`) | `mkdir` / `rmdir` on EXIT INT TERM | none: an active run refuses a second runner |
| `bin/ai-review-lifecycle` | assignment lock (`235` create, `201` read for release) | `mkdir` + token/state files; release is token-checked `rm` + `rmdir` | none: duplicate active assignment dies; token mismatch refuses release |
| `bin/ai-review-sandbox` | snapshot build lock (`572`) | `mkdir` / `rmdir` in cleanup | none: concurrent build of one tag dies |
| `bin/ai-glm` sandbox build claim | stage lock (comment `2084`, `2085,2086`) | `mkdir`, never waits | none: a claimed stage refuses |
| `bin/ai-deepseek-agent` | transcript store lock (`525`) | `mkdir` + owner token, waits `LOCK_WAIT` s / token-checked release | none: "session is busy" after the wait |

## What step 2 changed

- `bin/ai-lock-doctor` exists; every Section A timeout branch now runs it
  once (`--recover`, holders at least as old as the wait) and retries the
  `flock` once before failing.
- `bin/ai-qwen`'s Windows `lock_acquire` now also reclaims a legacy pid-only
  `credential.lock.d` under the pid+age rule (pid not observable AND lock
  older than 15 minutes), instead of waiting forever. Muse and DeepSeek keep
  their fail-closed refusal; only Qwen, the incident's blocked caller, gains
  the bounded reclaim.
