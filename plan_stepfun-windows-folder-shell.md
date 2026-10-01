# IMPLEMENTATION PLAN — StepFun Windows folder + test shell (2026-09-30 rev G)

> Fresh session starts here. Goal wins on conflict.

## STATUS

| Item | Status | Openable evidence |
|---|---|---|
| Rejects consumed | DONE | `.ai/reviews/grok-plan-review-20260930T172515-118426-1832.md`, `muse-plan-review-20260930T174430-270732-20790.md.stale`, `muse-plan-review-20260930T203848-1684580-25417.md.stale`, `muse-plan-review-20260930T223551-2339689-23231.md.stale`, `grok-plan-review-20261001T005659-3484451-14512.md`, `grok-plan-review-20261001T011633-3658106-22729.md` |
| Rev G | DONE | this file (full A-table, tools: lock, launch contract) |
| Plan APPROVE | OPEN | required before code |
| Implement → close #1169 | OPEN | §9 |

## 1. Goal

Windows StepFun explores a **disposable review folder** and runs tests via one
gated command path. Accident/casual-escape reduction only — not
determined-agent containment, not rule-11 equivalent. Linux bubblewrap
unchanged (keep-green §10.1).

## 2. Application

`popcre/ai-devops`. Worktree `C:/repos/ai-devops-wt-stepfun-win`, branch
`stepfun-windows-folder-shell`. #1169. Owner 2026-09-30 (MiMo chat): no WSL
(RAM maxed); **folder + test shell.**

## 3. Trigger

#1169 drift (stale install ran unsandboxed Windows StepFun). #1086 made
bubblewrap mandatory and refused Windows.

## 4. Scope

In: §8.6 file list, offline+canary tests, rule 11 Windows exception, install
refresh, #1169 close.

Out: WSL/VM; weaken Linux; StepCode on Windows; allocator membership;
`setup-opencode-stepfun.ps1` / StepFun OpenCode installer (reuse
`bin/setup-opencode-glm.ps1` / `config/opencode/version` pin).

## 5. Current state (file:line)

| Location | Fact |
|---|---|
| `bin/ai-stepfun:49` | `KEY_STORE=$HOME/.config/ai-devops/secrets/stepfun-api-key` |
| `bin/ai-stepfun:93-98` | `require_engine` Linux-only |
| `bin/ai-stepfun:127-134` | `key_store_ok` non-Linux false |
| `bin/ai-stepfun:196-201,254` | profile copy; launches `--auto` |
| `bin/ai-stepfun:232-249` | bwrap + GNU `timeout`; child `STEPFUN_API_KEY` |
| `bin/ai-stepfun:313` | StepCode `STEP_API_KEY` (Linux) |
| `bin/ai-stepfun:389-393` | doctor already skips bwrap on Windows |
| `config/opencode/version` | pin **1.18.12** |
| `docs/glm-opencode.md:50-57` | **`permission` maps are no-ops; only `tools:` removes tools** |
| `config/opencode-stepfun/agent/stepfun-*.md` | `tools: write/edit/patch/bash`; `permission.bash:"*"` (no-op) |
| `bin/ai-deepseek:33-42` | Windows `HOME_DIR` from `USERPROFILE` pattern |
| `bin/windows-private-file.ps1`, `bin/windows-json-file.ps1`, `bin/windows-git-bash-path.ps1` | reuse for ACLs / JSON / Git bash path |
| `config/machine-tools.tsv:10`, `docs/deployment.md:20-30` | install lists |
| `config/provider-cli-versions.json:30-35` | Ubuntu-only text |
| `docs/implementation-plan-index.md:95-96` | active plans |
| `docs/task-router.md` | needs StepFun Windows row |
| `config/ci-suites/test-ai-qwen.sh.json` | windows membership pattern |
| `tests/test-ai-stepfun.sh:195`, `tests/test-ai-review-preflight.sh:288-291`, `bin/ai-review-preflight:252-256` | Windows refusal asserts |
| `tests/test-bin-cmd-launchers.sh:14-22` | every `bin/*` needs `.cmd` |
| `tests/test-windows-scripts.sh` | `.ps1` ASCII parse |

## 6. Root cause

Windows has no bubblewrap. OpenCode `permission` does not enforce. A shell
tool + file tools as user can reach the profile. Owner accepted weaker
product guarantee.

## 7. REJECTED

Permission-map clamps (no-op on pin 1.18.12); `--auto` + path claims;
instruction-only controls; `npx`/`git` runners; host `PATH` copy;
`timeout.exe` sleep; unclamped `read`; grammar that still allows `../` or
`/c/Users/...`; `no :` while `npm run test:unit` needs `:`.

## 8. Design decisions

### 8.1 Owner residual (exact #1169 sentence)
**LOCKED 2026-09-30:** *folder + test shell.*

*Windows StepFun is confined to a disposable review folder and a gated test
command path. It is not mount-isolated. OpenCode file tools are removed on
Windows (the only enforcement this OpenCode pin provides) except a
folder-scoped read tool if S2 proves one; otherwise reading uses the gate’s
`ls`/`cat`/`head` limited to the folder. Anything allowlisted runners execute
is arbitrary user-level code on this PC. Registry/network is shared. Owner
accepted 2026-09-30.*

### 8.2 Tool surface LOCKED (grok F2) — `tools:` map only
**Do not rely on `permission:` / `opencode.json` deny.** On Windows agent
profiles set `tools:` **false/omitted** for `write`, `edit`, `patch`,
`webfetch`, `task`. 

- **Default arm (locked unless S2 proves otherwise):** also omit `read`,
  `glob`, `grep`, `list` as OpenCode tools. Folder exploration uses gate
  runners `ls`, `cat`, `head` (path-checked, folder-only) added to §8.3.
- **S2 spike arm (must prove or drop):** a real path-scoped read (or
  equivalent) on pin 1.18.12 + test. If proof fails, default arm stands.

`bash` is not an OpenCode tool on Windows; execution is only the shim
(§8.3). Profile files and `opencode.json` both updated consistently
(`bin/ai-stepfun:196-201` copy).

### 8.3 Windows `run_opencode_turn` contract (grok F3) + shim
**Launch:** no bwrap. Env block A (OpenCode process): §8.4 allowlist +
`XDG_*` under per-run dir + `USERPROFILE`/`APPDATA` native **or** redirected
consistently with profile copy (keep existing `$xdg` copy). `OC_BIN` resolved
from **real** profile home before redirect (`bin/ai-deepseek:33-42` pattern;
`HOME_DIR` helper).

**Deadline:** `bin/windows-git-bash-path.ps1` → Git `usr\bin\timeout`
absolute; else `taskkill /T /F` on OpenCode pid tree. Never PATHEXT
`timeout.exe`.

**Binding:** Windows PATH for the OpenCode process = shim dir **first** +
frozen system list (not host PATH). Shim names: `bash.exe`, `sh.cmd`,
`cmd.exe` shim, `powershell.exe` shim, `pwsh.exe` shim (or those OpenCode
tools omitted via `tools:`). Spike S1 records nonce log proving agent tool
calls hit the shim; if cmd/pwsh cannot be bound, omit those `tools:`.

**Shim layers:** Layer0 accepts only OpenCode’s `-c|-lc|--noprofile --norc -c`
prefixes and extracts `INNER`. Layer1 parses `INNER` (§8.4 grammar) as a
single runner invocation. Agent-level `bash -c` is refused at Layer1 (INNER
starts with runner `bash` and contains `-c`).

### 8.4 Grammar + path identity (grok F4)
After NFC: tokenize on spaces only; refuse shell metachars and quoting.
**`:` allowed only as `npm run <name>` script name** (letters/digits/`._-`).
CWD = review folder.

**Every** path-bearing argument (files **and** directories):
canonicalize via `bin/ai-stepfun-windows-pathclamp.ps1`
(`GetFinalPathNameByHandle` + `FILE_FLAG_BACKUP_SEMANTICS` for dirs) and
require prefix = review folder (long-path form). Refuse `..`, `/c/...`,
`C:\`, UNC `//host/...`, `\\?\`, ADS `:stream` (except npm name rule),
8.3 resolved-outside, trailing-dot/space, reserved `NUL`/`CON`/`COM1`.

**argv[0]:** absolute path **is** the identity; allowlist file
`~/.config/ai-devops/secrets/stepfun-windows-runners.json` written at install
via `where.exe` under sanitized PATH + `Protect-AiDevOpsPrivatePath`
(`bin/windows-private-file.ps1` / `bin/windows-json-file.ps1`). First-match
**refuse if ambiguous**. Doctor rewrites or refuses if binary missing.
Never include `WindowsApps` stubs or `wsl.exe`.

**Runners (one row):** `npm`(`test`|`run name`), `node`(`file`),
`pytest`(`[path]`), `python`/`python3`(`file`), `go`(`test`|`build`),
`cargo`(`test`|`build`), `dotnet`(`test`|`build`),
`pwsh`/`powershell` (gate injects `-NoProfile -NonInteractive
-ExecutionPolicy Bypass -File file`), `bash`/`sh` (real Git bash
`--noprofile --norc file`), `ls`/`cat`/`head` (folder-only paths). 
**No** `npx`, **no** `git`. Unknown flags refuse. No empty runner.

### 8.5 Env + key
Names from `bin/ai-qwen:98-102` but **PATH = §8.3 frozen**, not `${PATH:-}`.
Redirect `HOME USERPROFILE APPDATA LOCALAPPDATA TEMP TMP TMPDIR HOMEDRIVE
HOMEPATH`. Keep `SYSTEMROOT COMSPEC PATHEXT USER USERNAME LOGNAME LANG
LC_ALL TERM SSL_* PSModuleAnalysisCachePath`. Child API key **only**
`STEPFUN_API_KEY` from parent `KEY_STORE` (no disk copy). Windows
`key_store_ok`: present, non-empty, not `ReparsePoint` (use
`windows-private-file.ps1` / attributes), no `stat 600` claim.

### 8.6 Files to touch (complete; includes grok F6)
`bin/ai-stepfun`; `bin/ai-stepfun-windows-shell` + `.cmd`;
`bin/ai-stepfun-windows-pathclamp.ps1` + `.cmd` if in `bin/`;
`bin/ai-review-preflight`; `config/opencode-stepfun/opencode.json`;
`config/opencode-stepfun/agent/stepfun-review.md`;
`config/opencode-stepfun/agent/stepfun-implement.md`;
`config/reviewer-registry.json`; `config/reviewer-membership-scope.json`;
`config/provider-cli-versions.json`; `config/machine-tools.tsv` (new gate row
**and** pathclamp row); `config/ci-suites/test-ai-stepfun.sh.json`;
`config/ci-suites/test-ai-stepfun-windows-shell.sh.json` (windows:offline);
`docs/reviewer-rotation-rules.md`; `docs/config-inventory.md`;
`docs/architecture.md`; `docs/deployment.md`; `docs/implementation-plan-index.md`;
`docs/task-router.md` (StepFun Windows row); `skills/shared/stepfun/SKILL.md`;
`AGENTS.md` (router + plan link); `tests/test-ai-stepfun.sh` (**invert** :195
and PASS-counts/SKIPs); `tests/test-ai-review-preflight.sh` (**invert**
:288-291 + explain string); `tests/test-ai-stepfun-windows-shell.sh` (new);
`tests/test-windows-scripts.sh` (cover new `.ps1`); `tests/test-bin-cmd-launchers.sh`
(keep green); `tests/verification/…`; `HANDOFF.d/<utc>-….md`; this plan.

### 8.7 Adversarial table (every row → `check "…"` in
`tests/test-ai-stepfun-windows-shell.sh`)

| ID | External input | Hostile case | Expected | check name |
|---|---|---|---|---|
| A1 | INNER `cat <canary>` | non-allowlisted runner | refuse | `refuses cat canary` |
| A2 | INNER `python -c …` | eval | refuse | `refuses python -c` |
| A3 | INNER `powershell -Command …` | eval | refuse | `refuses powershell -Command` |
| A4 | `powershell -File <folder.ps1>` | legit | allow (injected flags) | `allows powershell -File folder` |
| A5 | path `\\?\` `\\.` `//h/s` `NUL` `CON` `file:stream` | reserved/UNC | refuse | `refuses reserved and UNC paths` |
| A6 | in-folder script reads canary | residual | residual-exfil recorded | `records in-folder canary read residual` |
| A7 | `;` `\|` `$()` `cd` `pushd` `Set-Location` | metachar/retarget | refuse | `refuses metacharacters and retarget` |
| A8 | `echo x > host` | write out | refuse | `refuses host write` |
| A9 | `git push` / `gh` / `op` | creds | refuse | `refuses git gh op` |
| A10 | child env | secret-like vars | absent | `child env omits secrets` |
| A11 | profile vars | recombine HOMEDRIVE/HOMEPATH | redirected | `redirects profile dirs` |
| A12 | StepCode non-Linux install | | still fail | (existing keep) |
| A13 | Linux no bwrap | | refuse | (existing keep) |
| A14 | `opencode.json` MCP added | | fail | `opencode profile has no mcp` |
| A15 | planted `npm` in folder | PATH plant | not used | `ignores planted runners` |
| A16 | `npx` `npm publish` `node -e` `bash -c` `cmd /c` `wsl` | | refuse | `refuses npx publish eval bash-c cmd wsl` |
| A17 | file tools outside folder | tools omitted | tool absent | `file tools omitted on windows` |
| A18 | fixture `npm test` | must work | allow + ok file | `allows npm test fixture` |
| A19 | abs interpreter path | | refuse | `refuses absolute interpreter` |
| A20 | `npm --prefix` outside | | refuse | `refuses prefix retarget` |
| A21 | unknown flag | | refuse | `refuses unknown flags` |
| A22 | over-deadline run | | killed | `kills over deadline` |
| A23 | read of `KEY_STORE` via gate | | refuse / residual named | `refuses key-store path` |
| A24 | `python ../../x.py` `/c/Users/...` | `..` / unix-host path | refuse | `refuses parent and unix host paths` |
| A25 | `npm run test:unit` | colon in name | allow | `allows npm colon script names` |
| A26 | runner json ambiguous `where` | | refuse | `refuses ambiguous runner allowlist` |

A1+A6 always reported as a pair.

### 8.8 Allocator
LOCKED out. Reason text only (`config/reviewer-membership-scope.json`).

## 9. Steps (you’ll know it worked when)

1. Rev G + AGENTS/HANDOFF/index/task-router links committed.
   **Know:** `ai-doc-reachability` clean on the PR.
2. Plan-review exact head → `VERDICT: APPROVE` naming head.
3. S1 nonce proof + S2 proof-or-default-arm recorded in STATUS.
   **Know:** nonce file exists; S2 arm chosen in writing.
4. Implement §8.6; offline suites green (`bin/ai-test-local
   --check-collision` first). **Know:** `tests/test-ai-stepfun.sh`,
   `tests/test-ai-stepfun-windows-shell.sh`, preflight tests, launcher tests
   pass on Windows Git Bash **and** Linux (§10.1).
5. Canary live proof (unique 32-hex names; no real secrets). **Know:**
   `tests/verification/` record with per-check outcome + turn id + no payload
   leak.
6. Exact-head **code** review → APPROVE.
7. PR + `bin/ai-pr-wait` + merge per `config/repository-policy.json`.
   **Know:** merge SHA on `origin/main`.
8. Refresh `C:/repos/ai-devops-reviewer-install` (machine-tools + new bin
   files). **Know:** install digest matches main; preflight usable; one live
   Windows turn.
9. Close #1169 (§8.1 sentence + owner quote + evidence links).

## 10. Tests

### 10.1 Linux keep-green (must stay)
`tests/test-ai-stepfun.sh` Linux bwrap cases (unshare, empty home, no `/`
bind, bwrap required), StepCode `STEP_API_KEY` path, refusal without bwrap.

### 10.2 Windows suite
`tests/test-ai-stepfun-windows-shell.sh` implements every `check` name in
§8.7. CI: `config/ci-suites/test-ai-stepfun-windows-shell.sh.json` with
`windows: ["offline"]`. Fixture: `tests/fixtures/stepfun-windows-shell/pkg/`
with `package.json` script `test`.

## 11. Constraints

Branch+PR+queue; identity; reviewer-safety code review; no secrets in
chat/argv/logs; Git Bash (`C:\Program Files\Git\bin\bash.exe`); `bin/ai-gh`;
sign GitHub posts; EST times; new scripts LF + exec + `.cmd` sibling.

## 12. Access

edge-dev Windows, Git Bash, no WSL. Reuse `windows-*.ps1` helpers. OpenCode
via `setup-opencode-glm.ps1` pin.

## 13. Done / rollback / open

Done: §9 all known-passed; #1169 closed with §8.1. Rollback: revert PR,
delete canary/per-run dirs, restore prior install digest. Open: none that
block start — S1/S2 outcomes land in STATUS before code.

## Self-audit

F1 A-table → §8.7 · F2 tools: lock → §8.2 · F3 launch contract → §8.3 ·
F4 `..`/`/c/` + npm colon → §8.4 · F5 sections + installer reuse → §2/§4 ·
F6 files → §8.6 · F7 runner rows + allowlist helpers → §8.4 · F8 evidence
paths → STATUS · F9 Linux keep-green → §10.1.
