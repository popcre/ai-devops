# Lock inventory

Every lock used by `bin/`, written for issue
[#1002](https://github.com/popcre/ai-devops/issues/1002) step 1. The table is
the complete answer to `grep -rnE 'flock|lock\.d|\.lock' bin` (87 hits after
step 2, verified 2026-09-28); every hit line is cited in the Grep hits
column, so a new lock site added without a row here makes this file wrong,
not optional.

Recovery policy for the Linux `flock` sites lives in `bin/ai-lock-doctor`
(issue #1002 step 2). Every call site acquires with `flock --close -E 87`:
exit 87 is the kernel's lock-conflict code and ONLY that outcome triggers
the doctor and one retry — a failure of the `op` command itself (auth, vault,
network) keeps its own status and is never swept. Under `--recover` the
doctor signals only `our-tool` holders at least `--older-than` seconds old
(TERM then KILL), and only when `/proc/locks` proves an advisory lock
actually sits on the inode. `our-tool` ancestry stops at a session-id
change: a reparented process's foster-parent chain is not a true parent
chain, and on a CI runner that chain can climb through the job supervisor
into processes carrying this repository's paths, which would make every
orphan look like ours. Foreign holders, young holders, holders whose
age cannot be proven, and every process `/proc/locks` names as BLOCKED
waiting on the lock (an `flock -w` waiter opens the lock file, so the fd
scan alone cannot tell it from the holder) are reported with full evidence
and never touched. "Free" is proven by the kernel (a non-blocking
acquisition succeeds), never by the fd scan's mere emptiness.

## A. The Linux 1Password refresh lock (`flock`)

One file, `$CFG_DIR/op-refresh.lock` (Linux:
`~/.config/ai-devops/op-refresh.lock`), serializes every `op` read/run on a
machine. `flock --close` (added by #939) keeps the descriptor out of `op`'s
children; the kernel releases the lock when the last holder's descriptor
closes, so a "stuck" flock is always a live holder, never a dead one.

Every wired site acquires with `-E 87`: exit 87 means the wait timed out on
contention, and ONLY that outcome triggers the doctor and one retry — a
failure of the op command itself (auth, vault, network) is never swept and
never retried. A child that happens to exit 87 on its own is contained the
same way: the doctor signals nothing without `/proc/locks` proving an
advisory lock on the exact inode, so the whole cost is one harmless retry.

| Where | Acquire / wait | Release | Staleness handling |
|---|---|---|---|
| `bin/setup-secrets.sh:287-299` (generated MCP launcher `_aidev_flock`) | `flock --close -E 87 -w 90` (`:292`), retry (`:296`) | kernel | conflict code 87, then `ai-lock-doctor --recover --older-than 90` (`:295`), then one retry; op's own errors keep their status |
| `bin/setup-secrets.sh:332-348` (generated remote launcher `_aidev_flock`) | `flock --close -E 87 -w 90` (`:337`), retry (`:341`) | kernel | same shape; call site `:348` |
| `bin/ai-qwen:439` (`cmd_store_key`; path resolved at `ai-qwen:372-390`; `lock_doctor` at `:411`) | `flock --close -E 87 -w 120`, retry (`:442`) | kernel | conflict code 87, doctor (`--recover --older-than 120`), one retry (#1002) |
| `bin/ai-muse:487` (`muse_locked_read` in `read_key_from_op`; path at `ai-muse:474`; `need flock` at `:472`) | `flock --close -E 87 -w "$budget"` (default 120) | kernel | conflict code 87, `muse_doctor` with the CONSTANT floor `--older-than 120` (never the caller-settable budget), one retry |
| `bin/ai-deepseek-agent:385` (`ds_locked_reexec`; `flock` check at `:376`) | `flock --close -E 87 -w 120` | kernel | conflict code 87 keeps the original status otherwise, `ds_lock_doctor` (`:377`), one retry |

Grep hits covered: `setup-secrets.sh:287,292,295,296,299,332,337,340,341,348`;
`ai-qwen:374,390,421,438,439,442`; `ai-muse:472,474,487`;
`ai-deepseek-agent:376,382,385,319` (the comment naming the Git Bash
limitation of the same boundary).

The generated launchers live outside the repository, so the doctor's
repo-path rule cannot see them; their own `flock` process is recognized
instead by naming THIS exact lock file in its command line, and only an
`flock` process counts (a foreign reader that merely opens the lock file
does not).

## B. The shared Windows credential lock (`credential.lock.d`, mkdir)

Muse owns `~/.local/state/ai-devops/muse/credential.lock.d` and publishes an
owner record (`pid winpid token`). Qwen and DeepSeek reuse it because Git Bash
has no `flock`.

| Where | Acquire / wait | Release | Staleness handling |
|---|---|---|---|
| `bin/ai-muse:500` (`muse_credential_acquire`, publish `muse_credential_publish` at `:398`) | poll until `budget` (120 s default) | `release_credential_lock` (`ai-muse:161`) removes only its own token | owner record: liveness x3 with winpid (`ps -W`); legacy pid-only: never reclaimed on Windows; no pid at all: reclaimed after 60 s |
| `bin/ai-qwen:541+` `lock_acquire` (call at `ai-qwen:428` inside `cmd_store_key`, path via `qwen_shared_credential_lock_path` `:372-390`) | poll until 120 s deadline | `lock_release` removes only its own token | owner record: liveness x3 with winpid; legacy pid-only (Muse's old format): reclaimed on Windows only under the pid+age rule — pid not observable AND lock older than 15 minutes (`ai-qwen:558-571`); no pid: reclaimed after 7200 s |
| `bin/ai-deepseek-agent:322` (inline `acquire_lock`/`publish_lock`) | poll until 120 s deadline | inline `release_lock`, token-checked | owner record only: liveness x3 with winpid; refuses every legacy lock without a winpid ("Wait or fail closed") |

Grep hits covered: `ai-muse:500`; `ai-qwen:372,388` (Windows path branch of
`qwen_shared_credential_lock_path`); `ai-deepseek-agent:322`.

## C. Portable per-session mutexes (`*.lock.d`, mkdir + owner pid)

Used by the reviewer wrappers for implementation/review/repository scopes
because `flock` does not exist in Git Bash.

| Tool | Path builders (grep hits) | Acquire / release | Staleness handling |
|---|---|---|---|
| `bin/ai-qwen` | `lock_path`/`repolock_path`/`reviewlock_path` (`506,507,512`; comment `515`) | `lock_acquire` (`544`) / `lock_release` | liveness x3 (winpid fallback); tombstoned reclaim keyed by owner token; dead-lock tombs older than 1440 min swept |
| `bin/ai-kimi` | `lock_path`/`repolock_path`/`reviewlock_path` (`529,530,535`; comment `538`) | `lock_acquire` / `lock_release` (rm -rf) | pid dead → `rm -rf` and re-mkdir immediately |
| `bin/ai-grok-review` | `lock_path`/`repolock_path`/session+work lock builders (`505,507,513,523`; comment `549`) | `lock_acquire` (`551`) / per-scope release | pid alive → busy; dead owner: repo locks retained for manual reconciliation (unconfirmed remote completion), pre-provider work locks reclaimed (`591`); scans over lock sets at `1963,2014` |
| `bin/ai-glm` | session locks `$rid--$caller--$name.lock.d` (`350`, comment `352`, acquire `2114`, pid read `2284`); meta update lock `.update.lock.d` (`563`); collision guards (`2055,2056,2072,2073`); orphan sweep guards (`2189,2247,2255`) | lock dir with pid file; released by the owning session | pid-file record; collision and orphan logic treats an existing lock as authoritative (fail closed) |
| `bin/ai-muse` | session lock `lock_session` (`219`) | token + pid publish; `unlock_session` | pid dead or unparsable owner older than 1 min → quarantine and retry (3 attempts) |
| `bin/ai-lock-doctor` | the doctor itself: header `8` (live-holder rule), `17-21` (same-session our-tool rule), `22-26` (waiter class), `37-40` (age floor), `41-46` (known transient), `47-50` (reparented-holder rule), `101` (flock guard), `146-189` (/proc/locks match and blocked-waiter collection), `247-292` (classification incl. the session-boundary stop at `281-286`), `265` (flock-on-this-lock rule), `336` (bounded evidence), `348` (kernel-proven waiter classification), `374-375,445-446` (kernel-proven freedom probes), `391-394` (lock-existence gate), `423` (waiters never signalled), `450` (recovered confirmation) | reads the lock's inode, `/proc/locks`, and `/proc/*/fd` | our-tool holders at least `--older-than` old are TERM/KILLed under `--recover`; foreign, young, unknown-age holders and kernel-proven blocked waiters are never signalled |

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
| `bin/ai-deepseek-agent` | transcript store lock (`545`) | `mkdir` + owner token, waits `LOCK_WAIT` s / token-checked release | none: "session is busy" after the wait |

## What step 2 changed

- `bin/ai-lock-doctor` exists (executable, with a `.cmd` launcher); every
  Section A site now proves real contention with `flock --close -E 87`
  (the kernel's lock-conflict exit code) before any sweep, then runs the
  doctor once and retries the read once.
- `bin/ai-qwen`'s Windows `lock_acquire` also reclaims a legacy pid-only
  `credential.lock.d` under the pid+age rule (pid not observable AND lock
  older than 15 minutes), instead of waiting forever. Muse and DeepSeek keep
  their fail-closed refusal; only Qwen, the incident's blocked caller, gains
  the bounded reclaim.
