# IMPLEMENTATION PLAN — StepFun Windows folder + test shell (2026-09-30 rev F)

> **Fresh session starts here.** Goal wins on any conflict.

## STATUS

| Step | Status | Evidence |
|---|---|---|
| Revs A–E + rejects | DONE | grok `…172515…`, muse `…174430…stale`, muse `…203848…stale`, muse `…223551…stale`, grok `…005659…` (rev E) |
| Rev F (this file) | DONE | closes grok rev-E highs 1–8 + med file list |
| Plan re-review → APPROVE | OPEN | before code |
| Spikes S1/S2 + implement → #1169 close | OPEN | §9 |

## 1. Goal

Windows StepFun explores a **disposable review folder** and runs tests via
**one exclusively gated command path**. Accident/casual-escape reduction only
— not determined-agent containment, not rule-11 equivalent. Linux bubblewrap
unchanged.

## 2. Context

`popcre/ai-devops`, worktree `C:/repos/ai-devops-wt-stepfun-win`, branch
`stepfun-windows-folder-shell`. #1169. Owner 2026-09-30: no WSL (RAM);
**folder + test shell.**

Out: WSL/VM; weaken Linux; StepCode on Windows; allocator membership;
`setup-opencode-stepfun.ps1`; new OpenCode installer.

## 5. Current state (verified)

| Location | Fact |
|---|---|
| `bin/ai-stepfun:49` | default `KEY_STORE=$HOME/.config/ai-devops/secrets/stepfun-api-key` |
| `bin/ai-stepfun:93-98` | `require_engine` Linux-only |
| `bin/ai-stepfun:127-135` | `key_store_ok` rejects Windows |
| `bin/ai-stepfun:196-201` | copies profile into redirected `$xdg` |
| `bin/ai-stepfun:232-249` | bwrap required; Linux empty home; child `STEPFUN_API_KEY` |
| `bin/ai-stepfun:313` | StepCode `STEP_API_KEY` (Linux only) |
| `config/opencode-stepfun/opencode.json` | `{env:STEPFUN_API_KEY}`; **no** `permission` block |
| `config/opencode-stepfun/agent/stepfun-*.md` | permissions live here (`bash:"*":allow`) |
| `bin/ai-qwen:98` | `PATH=${PATH:-}` host PATH — **do not copy blindly** |
| `config/machine-tools.tsv` / `docs/deployment.md:20-21` | install lists |
| `config/provider-cli-versions.json:30-35` | Ubuntu-only wording |
| `docs/implementation-plan-index.md:95-96` | active-plan registry |
| `.doc-reachability.json:9-18` | new `plan_*.md` needs a link or gate fails |
| `tests/test-bin-cmd-launchers.sh:14-22` | every `bin/*` needs `.cmd` sibling |

## 7. REJECTED (this rev)

Unclamped `read`/`glob`/`grep` (grok E1); shim that refuses `bash -c` while
OpenCode sends `bash -c` (E2); copying qwen host `PATH` (E3); unnamed
canonicalize helper (E4); allowlist file with no path (E5); Windows
`timeout.exe` sleep (E6); `powershell -File` without injected
`-NoProfile -NonInteractive` (E7); slogan tests without `check` names (E8).

## 8. Design decisions

### 8.1 Owner residual (exact sentence for #1169)
**LOCKED 2026-09-30:** *folder + test shell.*

*Windows StepFun is confined to a disposable review folder and a gated test
command path. It is not mount-isolated. File tools are clamped to that folder
or disabled. Anything allowlisted runners execute (scripts, package.json
hooks, conftest/plugins, build.rs, MSBuild targets) is arbitrary user-level
code on this PC. Registry/network is shared. Owner accepted 2026-09-30.*

### 8.2 Shell exclusivity (grok E2) — two-layer argv contract
**Layer 0 (shim entry).** OpenCode bash tool invokes the **shim** as
`bash|sh|bash.exe` with OpenCode’s usual wrapper form
(`-c '<inner>'`, `-lc '<inner>'`, `--noprofile --norc -c '<inner>'`).
Shim **accepts only** those prefixes, strips to `INNER`, and does **not**
treat `-c` as a refused runner flag. Then:

**Layer 1 (INNER).** `INNER` is parsed by §8.3 as a single gated invocation
(runner set). `bash`/`sh` as a **runner** (agent asking a script runner) is
`bash --noprofile --norc <file-in-folder>` with **no** `-c`. A16 still refuses
agent `bash -c '…evil…'` at Layer 1 (INNER contains `-c`).

Also shim `cmd.exe`/`powershell.exe`/`pwsh.exe` **or disable those OpenCode
tools** on Windows (spike S1). `COMSPEC` kept for OS children only.

**S2 file tools (grok E1):** clamp **all** of read/glob/grep/list/write/edit
to the review folder via path-scoped permissions **or fail closed** —
if clamp unavailable, **disable every file tool** on Windows and expose only
gated shell (read-only exploration then requires `ls`/`cat`-class runners,
which are **not** allowlisted → document: exploration uses OpenCode `read`
only when clamped). **Never** leave `read` unclamped. Reconstructing
`KEY_STORE` under `USERPROFILE` must not work (A23).

### 8.3 Command grammar (Layer 1)
Closed grammar after NFC + strip `\r`: no metachars
`; & | ( ) { } [ ] < > \ ` $ ~ * ? ! % ^ @ # = "` `'` tab; no `VAR=`;
no `:` (ADS/drive-relative); length ≤ 2000. CWD forced to review folder.

**argv[0] identity:** the allowlist stores **absolute runner paths** only
(never “search PATH then basename”). Resolution primitive at install:
`where.exe` run under a **sanitized PATH** (System32 + Git + pinned dirs),
output recorded to
`~/.config/ai-devops/secrets/stepfun-windows-runners.json` (owner-only) and
mirrored in doctor output. Missing file ⇒ refuse (fail-closed). `wsl.exe`
and Windows Store `python.exe` stubs **never** enter the file (probe for
`WindowsApps`).

**Frozen PATH for children:** explicit constant (System32, WindowsPowerShell
v1.0, Git `cmd`/`bin`/`usr/bin` **GNU** tools only) — **not** `PATH=${PATH:-}`.
Shim dir is **not** on the child PATH (no gate deadlock); exclusivity is at
OpenCode tool layer.

**Runner set:** `npm`, `node`, `pytest`, `python`, `python3`, `go`, `cargo`,
`dotnet`, `pwsh`, `powershell`, `bash`, `sh`. **No** `npx`. **No** `git`
(grok E10: `git diff/log` not available on Windows StepFun; packet + clamped
read only). Abs interpreter refused. Unknown flags refuse.

| Runner | Allowed | Notes |
|---|---|---|
| `npm` | `test`, `run <name>` | not empty |
| `node` | `node <file-in-folder>` | not empty; no eval flags |
| `pytest` | `pytest [path-in-folder]` | dirs OK; helper uses `FILE_FLAG_BACKUP_SEMANTICS` |
| `python` | `python <file-in-folder>` | not empty / REPL |
| `go`/`cargo`/`dotnet` | `test`/`build` | no `-exec`,`--config`,`-p:`/`/p:` |
| `pwsh`/`powershell` | gate injects `-NoProfile -NonInteractive -ExecutionPolicy Bypass -File <file>` | agent cannot pass those flags |
| `bash`/`sh` | gate invokes real Git bash `--noprofile --norc <file-in-folder>` | not the shim |

### 8.4 Env + key
`env -i` + qwen **names** but **PATH = frozen constant** (§8.3), not host.
Redirect `HOME USERPROFILE APPDATA LOCALAPPDATA TEMP TMP TMPDIR HOMEDRIVE
HOMEPATH`. Keep `SYSTEMROOT COMSPEC PATHEXT USER USERNAME LOGNAME LANG
LC_ALL TERM SSL_* PSModuleAnalysisCachePath`. Key: only `STEPFUN_API_KEY`
into child env from parent `KEY_STORE`; no disk copy; `STEP_API_KEY` absent.
Profile copied under per-run HOME (existing `:196-201`).

### 8.5 Deadline (grok E6)
Never use PATHEXT `timeout`. Use Git Bash `timeout` from Git `usr\bin`
**absolute path**, else `taskkill /T /F` on the child pid tree. A22 proves
kill.

### 8.6 Helpers and install file-list (grok E4/E5)
New/changed files (complete):
1. `bin/ai-stepfun`
2. `bin/ai-stepfun-windows-shell` + **`bin/ai-stepfun-windows-shell.cmd`**
3. `bin/ai-stepfun-windows-pathclamp.ps1` (GetFinalPathNameByHandle + dir
   backup-semantics) + `.cmd` if placed in `bin/`
4. `bin/ai-review-preflight`
5. `config/opencode-stepfun/opencode.json` (permission block / bash deny)
6. `config/opencode-stepfun/agent/stepfun-review.md` + `stepfun-implement.md`
7. `config/reviewer-registry.json`, `config/reviewer-membership-scope.json`
8. `config/provider-cli-versions.json` (drop Ubuntu-only absolute)
9. `config/machine-tools.tsv` (gate row)
10. `config/ci-suites/test-ai-stepfun.sh.json` +
    `config/ci-suites/test-ai-stepfun-windows-shell.sh.json`
11. `docs/reviewer-rotation-rules.md`, `docs/config-inventory.md`,
    `docs/architecture.md`, `docs/deployment.md` (if list changes),
    `docs/implementation-plan-index.md` (active plan row)
12. `skills/shared/stepfun/SKILL.md`, `AGENTS.md` (router row + plan link)
13. `tests/test-ai-stepfun.sh`, `tests/test-ai-review-preflight.sh`,
    `tests/test-ai-stepfun-windows-shell.sh` (new),
    `tests/test-bin-cmd-launchers.sh` (keep green)
14. `tests/verification/…` canary record
15. `HANDOFF.d/<utc>-…md` (current, not future)
16. This plan (link from AGENTS/HANDOFF so `ai-doc-reachability` passes)

### 8.7 Tests (named `check`s in `tests/test-ai-stepfun-windows-shell.sh`)
Parser/reject/metachar · Layer0 shim `-c` strip · Layer1 runner table ·
allowlist path identity · PATH plant A15 · abs interp A19 ·
env absent A10 · redirect A11 · key name STEPFUN_API_KEY ·
kill A22 · file-tool clamp or disabled A17/A23 · A18 fixture
(`tests/fixtures/stepfun-windows-shell/pkg/package.json` `test` script
writes `ok` file) · reserved names `NUL`/`CON`/`COM1` in A5 ·
qwen host-PATH regression (child PATH ≠ host PATH).

### 8.8 Allocator
LOCKED out. Reason text update only.

### 8.9 Live proof
Canary-only (unique 32-hex names). Fail bar: A18 must succeed; every refuse
class must refuse (nonce log); in-folder canary read = residual-exfil
(record success bit, assert no payload in output). Pair A1+A6 in the report.

## 9. Steps

1. Commit rev F + AGENTS/HANDOFF/index links (doc reachability).
2. Plan-review → APPROVE at exact head.
3. Spikes S1 (exclusive shim incl. cmd/powershell) and S2 (file clamp or
   disable-all); record nonce format + OpenCode pin in STATUS.
4. Implement §8 file list; offline suites green (`ai-test-local
   --check-collision` first).
5. Canary live proof on edge-dev.
6. Exact-head **code** review → APPROVE.
7. PR + `ai-pr-wait` + merge. Install refresh (machine-tools + reviewer-install
   file-list) + one live turn. Close #1169 with §8.1 sentence + owner quote.

## 13. Rollback

Revert PR; delete canary/per-run dirs; restore prior install digest.

## Self-audit vs grok rev E
E1 file tools → §8.2 S2 fail-closed · E2 shim `-c` → §8.2 layers ·
E3 PATH → §8.3/§8.4 · E4 helper → §8.6 · E5 install list → §8.6 ·
E6 timeout → §8.5 · E7 pwsh/bash invoke → §8.3 · E8 named tests → §8.7 ·
E10 no git → §8.3 · E11 structure → §9 short · E12 permission file →
§8.6 item 5.
