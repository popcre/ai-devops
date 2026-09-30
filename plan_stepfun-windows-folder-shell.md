# IMPLEMENTATION PLAN — StepFun Windows folder + test shell (2026-09-30 rev E)

> **Fresh session starts here.** If any step conflicts with §1, the goal wins.

## STATUS (live)

| Step | Status | Evidence |
|---|---|---|
| History | DONE | rev A–D; rejects: grok `…172515…`, muse `…174430…stale`, muse `…203848…stale`, muse `…223551…stale` |
| Rev E (this file) | DONE | closes muse rev-D highs (npx, CWD, fetch, flags, spike order, key name, pin/HOME, grammar) |
| Plan re-review → APPROVE | OPEN | required before code |
| Spikes (shell exclusivity + file clamp + key name) | OPEN | before or with APPROVE; see §8.2/§8.5/§8.4 |
| Implement / tests / canary proof / code review / merge / install / close #1169 | OPEN | §9 |

## 1. The ultimate goal

StepFun on Windows explores a **disposable review folder** and runs tests via
**one exclusively routed gated command path**. Accident / casual-escape
reduction only — **not** determined-agent containment and **not** rule-11
equivalent. Linux bubblewrap unchanged.

## 2. Application / trigger / scope

`popcre/ai-devops` StepFun path. Worktree `C:/repos/ai-devops-wt-stepfun-win`,
branch `stepfun-windows-folder-shell`. #1169. Owner (MiMo chat 2026-09-30):
no WSL (RAM maxed); chose **folder + test shell.**

Out: WSL/VM; weakening Linux; StepCode on Windows; allocator membership;
`setup-opencode-stepfun.ps1` restore; new OpenCode installer.

## 5. Current state (evidence)

| Location | State |
|---|---|
| `bin/ai-stepfun:93-104` | `require_engine` Linux-only |
| `bin/ai-stepfun:127-135` | `key_store_ok` rejects Windows |
| `bin/ai-stepfun:199` | copies `opencode.json` into redirected `$xdg` |
| `bin/ai-stepfun:217-247` | `run_opencode_turn` requires bwrap + `/usr/bin/timeout`; child `HOME=$home` + `STEPFUN_API_KEY=$STEP_KEY` (`:243`) |
| `bin/ai-stepfun:291` | `STEP_ENV_ALLOW` Linux-only names |
| `bin/ai-stepfun:313` | StepCode path uses `STEP_API_KEY` (Linux only — leave) |
| `bin/ai-stepfun:389-393` | `cmd_doctor` Windows bwrap skip |
| `config/opencode-stepfun/agent/stepfun-*.md` | `bash: "*": allow` + write/edit |
| `config/opencode-stepfun/opencode.json` | provider `stepfun-api` reads `{env:STEPFUN_API_KEY}` |
| `bin/ai-review-preflight:232-258,325` | preflight status strings |
| `tests/test-ai-stepfun.sh:104-110,192-203` | refusal / SKIP / PASS-count |
| `tests/test-ai-review-preflight.sh:286-291` | Windows unsupported |
| `tests/test-install-ai-provider-clis.sh:62-67` | StepCode Linux-only (**KEEP**) |
| `docs/architecture.md:151`, `config/reviewer-membership-scope.json` | Ubuntu-only wording |
| `bin/ai-qwen` (credential boundary) | Windows env model to copy |

**Locked fact from code (closes muse D6/D7):** OpenCode auth env name is
`STEPFUN_API_KEY` (profile `opencode.json`). Config is discovered under the
redirected HOME because the wrapper **copies** `opencode.json` + `agent/` into
the per-run tree (`:199`, `:385`) — no `--config` flag needed if that copy is
kept. `STEP_API_KEY` stays Linux StepCode-only.

## 7. REJECTED

Prior rejects plus (muse rev D): `npx` on the runner list; bare runners
without CWD=folder; registry fetch without naming residual; approve-before-
exclusive-routing-spike; disjunction on key name; instruction-only controls.

## 8. Design decisions

### 8.1 Owner + residual (exact close sentence)
**LOCKED (2026-09-30):** *folder + test shell.*

**Residual sentence for #1169:** *Windows StepFun is confined to a disposable
review folder and a gated test command path. It is not mount-isolated.
Anything the allowlisted runners execute — in-folder scripts, `package.json`
scripts and lifecycle hooks, `conftest.py`/plugins, `build.rs`, go:generate,
MSBuild targets — is arbitrary user-level code on this PC (same class as
Claude Desktop with tools). Registry/network fetches during tests are shared
network, not isolated. Owner accepted that residual on 2026-09-30.*

Eval flags and non-allowlisted commands are **refused**, not residual.

### 8.2 Shell gate — exclusive routing (muse D1/D5)
**LOCKED:** exactly one mechanism, proven before APPROVE of code (plan
APPROVE may proceed with spike outcomes recorded as OPEN→DONE in STATUS):

- Spike S1: prove **exclusivity** — from inside an OpenCode Windows turn, an
  agent `bash`/tool call can only reach `bin/ai-stepfun-windows-shell`
  (nonce log), and a direct `cmd.exe`/`powershell`/real bash is not offered.
  Mechanism: PATH shim directory first containing `bash`/`sh`/`bash.exe`
  wrappers → gate; profile `permission.bash` `"*": deny` except commands that
  the shim accepts; if OpenCode cannot deny raw bash, disable the bash tool
  and expose only a custom runner command if schema allows (spike S1b).
  **No “or tell the agent” branch.** If neither proves exclusivity → stop and
  report gap on #1169.

### 8.3 Command grammar (muse D2/D4/D8/D10/D11)
**CWD:** child cwd **is** the review folder; refuse any command that is a bare
runner without a folder-local target when the runner would resolve outside
(`pytest`, `npm test`, `go test`, `cargo test`, `dotnet test` are allowed
**only** with cwd=folder — the gate sets cwd and does not accept `cd`).

**Parser (closed):** after Unicode NFC + trim + strip `\r`, the command must
match a single invocation with **no** shell metacharacters of any kind:
`; & | ( ) { } [ ] < > \n \r \t ` $ ~ * ? ! % ^ @ # =` and no quotes that
contain them; no `VAR=val` prefixes; no `:` (blocks ADS/drive-relative).
Length cap (e.g. 2000). **No path expansion.** Tokenize on spaces only.

**argv[0]:** basename, case-insensitive, optional `.exe`/`.cmd`/`.bat` via
PATHEXT, resolved on **frozen PATH** = `SYSTEMROOT\System32`, `SYSTEMROOT`,
`SYSTEMROOT\System32\Wbem`, `SYSTEMROOT\System32\WindowsPowerShell\v1.0`,
Git’s `cmd`/`bin` if present, and **explicit allowlist file** of runner
absolute paths recorded at install (not “whatever is on PATH”). Missing
runner ⇒ refuse (documented DoS, not silent skip). `command -v` /
`where.exe` used only at install/probe time to write that file.

**Runner set (npx DELETED):** `npm`, `node`, `pytest`, `python`, `python3`,
`go`, `cargo`, `dotnet`, `pwsh`, `powershell`, `bash`, `sh`.
Absolute interpreter paths **refused**. `~` refused (also blocks 8.3 `~`).

**Subcommands / flags (deny-by-default for unknown flags):**
| Runner | Allowed | Explicit refuse (non-exhaustive; unknown flags refuse) |
|---|---|---|
| `npm` | `test`, `run <script-name>` | `publish exec install ci i update link audit --prefix -C` |
| `node` | `node <file-in-folder>` | `-e -p --eval --require -r --loader --import --inspect* --cpu-prof* --redirect-warnings` |
| `pytest` | `pytest [path-in-folder]` | `-c -p -o --confcutdir --rootdir` outside, `-x` ok |
| `python` | `python <file-in-folder>` | `-c -m -` |
| `go` | `go test`, `go build` | `go run -exec -toolexec -overlay -modfile -gcflags -ldflags` |
| `cargo` | `cargo test`, `cargo build` | `publish run --config --target-dir` |
| `dotnet` | `dotnet test`, `dotnet build` | `nuget push run -p: /p: --project` outside folder |
| `pwsh`/`powershell` | `-File <file-in-folder>` (also `-f`) | `-Command -EncodedCommand -c -ExecutionPolicy -WorkingDirectory` |
| `bash`/`sh` | `<file-in-folder>` | `-c -i` |

`--` separator: refuse (unspecified parsing). Flags-before-subcommand
(`npm --prefix X test`): refused (metachar/`=`/unknown flag rules).
`Set-Location`/`Push-Location`/`chdir`/`sl`/`cd`/`pushd`/`popd` as tokens:
refuse.

**Path operands:** must canonicalize under review folder: Windows
`GetFinalPathNameByHandle` (small helper **required**, fail-closed if helper
missing) + reject `\\?\` `\\.` `//?/` `file:stream`, trailing-dot/space,
8.3 names (resolved form must match). Check-then-exec: open/run immediately
after check (best-effort TOCTOU; residual).

**Registry fetch residual (muse D3):** `npm test` may still fetch unless
lockfile present; **LOCKED:** prefer `npm test` with existing `node_modules`
or `--offline` when supported; document registry fetch as residual in §8.1
(already named “network fetches during tests”).

### 8.4 Env + key (muse D6/D7)
`env -i` + qwen model. Redirect `HOME USERPROFILE APPDATA LOCALAPPDATA TEMP
TMP TMPDIR HOMEDRIVE HOMEPATH` all under per-run dir. Keep `SYSTEMROOT
COMSPEC PATHEXT USER USERNAME LOGNAME LANG LC_ALL TERM SSL_CERT_FILE
SSL_CERT_DIR PSModuleAnalysisCachePath`. `USER`/`USERNAME` kept **on purpose**
(tooling needs them; noted).

**Key:** parent reads `KEY_STORE`; child gets **only** `STEPFUN_API_KEY`
(exact name from `opencode.json`). Never `STEP_API_KEY` on Windows. No disk
copy of the key. Profile tree copied into per-run HOME (existing `:199`
pattern) so pin/config resolve without `--config`.

### 8.5 File tools
Spike S2: path-scoped permissions in pinned OpenCode. If yes → clamp to
folder. If no → **disable `write`/`edit`/`patch`** on Windows profiles
(read/glob/grep/list only). Named Windows exception to #974 in rule 11.
Never unclamped write + “confined” claim.

### 8.6 Key store Windows
Present, non-empty, not `ReparsePoint`. No NTFS `stat 600` claim.

### 8.7 Deadline
Git Bash `timeout` if present; else `taskkill /T /F` via a recorded killer
pid-tree (Win32 job objects optional; name `taskkill /T` in code). Test
asserts kill-after-N.

### 8.8 Allocator
LOCKED out. Update `config/reviewer-membership-scope.json` reason text only.

### 8.9 Live proof — canary only
Unique canary files (random 32-hex names + payload nonce). Fail bar:
1. A18 allowlisted test **must succeed**.
2. Every refused class **must refuse** (nonce logs; missing refusal = plan fail).
3. In-folder script reading canary → **residual-exfil recorded** (success bit
   only; assert recorded output has **no** canary payload).
4. Report pairs A1-with-A6 so “refused counts” cannot be misread as containment.

### 8.10 Files this change will touch (complete list)
`bin/ai-stepfun`, `bin/ai-stepfun-windows-shell` (new),
`bin/ai-review-preflight`, `config/opencode-stepfun/agent/stepfun-review.md`,
`config/opencode-stepfun/agent/stepfun-implement.md`,
`config/reviewer-registry.json`, `config/reviewer-membership-scope.json`,
`docs/reviewer-rotation-rules.md`, `skills/shared/stepfun/SKILL.md`,
`docs/config-inventory.md`, `docs/architecture.md`, `AGENTS.md`,
`tests/test-ai-stepfun.sh`, `tests/test-ai-review-preflight.sh`,
`config/ci-suites/test-ai-stepfun.sh.json` (extend) +
`config/ci-suites/test-ai-stepfun-windows-shell.sh.json` (new if suite split),
install file-list used by reviewer-install refresh (search
`install-ai-provider` / `machine-tools.tsv` / symlink list — name the exact
file in the implement commit), `tests/verification/…` (canary record),
`HANDOFF.d/<utc>-….md`, this plan.

## 9. Steps

A1 commit rev E. A2 plan-review → APPROVE. A3 gates check.
B1 Spike S1 exclusivity. B2 Spike S2 file clamp. B3 key-name assertion test
(`STEPFUN_API_KEY` only). B4 wrapper/env/deadline code.
C1 gate script (LF+exec). C2 wire profiles per spikes.
D1 preflight + `shell-gate-missing`. D2 invert tests (PASS-count/skips).
D3 docs + rule 11 residual. D4 AGENTS + HANDOFF.
E1 offline suites + ci-suites + `ai-test-local --check-collision`.
E2 canary live proof. E3 exact-head code review APPROVE. E4 PR + `ai-pr-wait`
+ merge. E5 install refresh + live turn. E6 close #1169.

## 10. Adversarial table (canary paths)

A1 `cat`/`type` canary → refuse · A2 `python -c` → refuse · A3 `powershell
-Command` → refuse · A4 `-File folder.ps1` → allow · A5 UNC/`\\?\`/8.3/ADS
canary → refuse · A6 in-folder script reads canary → residual-exfil (paired
with A1) · A7 metachars/cd/pushd/Set-Location → refuse · A8 `echo > host` →
refuse · A9 git push/gh/op → refuse · A10 secret env absent · A11 profile
redirect + HOMEDRIVE/HOMEPATH cannot recombine · A12 StepCode non-Linux fails
(keep) · A13 Linux without bwrap refuses · A14 MCP in opencode.json fails ·
A15 PATH plant not used · A16 `npx`/`npm publish`/`node -e`/`bash -c`/`cmd
/c`/`wsl` → refuse · A17 write outside folder → refuse or tools off · A18
`npm test` in folder **must succeed** · A19 abs interpreter path → refuse ·
A20 `--prefix`/`--manifest-path` outside → refuse · A21 unknown flag → refuse
· A22 killer ends over-deadline run.

## 11–13. Constraints / access / done

Git Bash not WSL; `bin/ai-gh`; sign posts; never weaken Linux; never claim
rule-11 equality. Rollback: revert PR + delete canary/per-run dirs + prior
install digest. Done: STATUS all DONE, merge SHA, canary proof, install
digest match, #1169 CLOSED with §8.1 sentence + owner quote.

## Self-audit

muse D1 npx → §8.3 deleted · D2 CWD → §8.3 · D3 fetch → §8.3 residual ·
D4 flags → §8.3 table · D5 spike/exclusivity → §8.2 · D6 key name → §8.4 ·
D7 pin/HOME → §5+§8.4 · D8 grammar → §8.3 · D9 PATH → §8.3 frozen+install
file · D10 canonicalize → §8.3 · D11 cd siblings → §8.3 · D12 refuse
semantics → exit 126 + nonce log, no side effects · D13 killer → §8.7 ·
D14 canary → §8.9 · D15 file list → §8.10 · D16 residual bodies → §8.1.
