# IMPLEMENTATION PLAN — StepFun Windows folder + test shell (2026-09-30 rev D)

> **Fresh session starts here.** If any step conflicts with §1, the goal wins —
> stop and flag it.

## STATUS (live)

| Step | Status | Evidence |
|---|---|---|
| 1–5 Plan history | DONE | rev A/B/C; grok reject `…172515…`; muse reject `…174430…stale`; muse reject rev C `…203848…stale` |
| 6 Rev D (this file) | DONE | locks one shell mechanism; tightens runners; honest residual |
| 7 Plan re-review → APPROVE | OPEN | required before code |
| 8–16 Implement / prove / ship | OPEN | see §9 |

## 1. The ultimate goal

StepFun on edge-dev Windows explores a **disposable review folder** and runs
tests through **one gated command path**. This is **accident and casual-escape
reduction**, not determined-agent containment. Linux bubblewrap is unchanged
and remains the only mount-level isolation. Windows is **never** called
rule-11 equivalent.

If any step below conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`popcre/ai-devops` StepFun reviewer path. Worktree
`C:/repos/ai-devops-wt-stepfun-win`, branch `stepfun-windows-folder-shell`.

## 3. Trigger

#1169. Owner Albert (MiMo chat, 2026-09-30): no WSL (RAM maxed). Chose
verbatim: **folder + test shell.** Informed residual (restated for consent in
§8.1): an in-folder test script is full user-level code on this PC.

## 4. Scope

In: Windows OpenCode path; **one** shell gate; runner/subcommand allowlist;
Windows env + profile redirect; key delivery without disk copy if possible;
key-store Windows rule; preflight; inverted tests; rule 11 exception with
honest residual; canary-only live proof; install refresh; #1169.

NOT in: WSL/VM; weakening Linux; StepCode on Windows; allocator membership
(LOCKED out); restoring `setup-opencode-stepfun.ps1`; new OpenCode installer.

## 5. Current state (`origin/main` @ `93ff6e48`)

Same file:line table as rev C §5 (require_engine:93-104, key_store_ok:127-135,
run_opencode_turn:217-247, STEP_ENV_ALLOW:291, cmd_doctor:389-393, preflight
232-258/325, agent profiles bash `"*": allow`, tests 104-110/192-203 and
286-291, architecture.md:151, membership-scope.json).

Sibling env model: `bin/ai-qwen` credential boundary (`env -i`, redirected
HOME/USERPROFILE/APPDATA/LOCALAPPDATA/TEMP/TMP/TMPDIR, safe names
SYSTEMROOT COMSPEC PATHEXT USER USERNAME LOGNAME LANG LC_ALL TERM).
`bin/ai-muse:258-259` sets `PSModuleAnalysisCachePath` to private temp.
StepFun child key today: `STEPFUN_API_KEY` (`bin/ai-stepfun:243`) and
`STEP_API_KEY` (`:313`) — both must be classified in §8.4.

## 6. Key finding (this revision)

Allowlisting general interpreters (`python`, `pwsh`, `bash`, `node`) plus
in-folder write = **universal bypass by design**. That cannot be “mitigated”
into rule-11. The honest product is: stop accidents, raise the bar for casual
escape, document determined-agent escape as residual owner-accepted risk.

## 7. REJECTED (additional)

| Approach | Why |
|---|---|
| “Route through wrapper **or** tell the agent to use it” | Instruction is not enforcement (muse C1). |
| Allow `npm publish` / `npx --yes` / `npm exec` | Remote code + exfil via allowlisted argv (muse C2). |
| Allow `python -c` / `pwsh -Command` / `bash -c` | Eval bypass (rev C already refused; keep). |
| Claim file clamp via chdir | False on Windows (muse C4). |
| Live proof against real `~/.ssh` | Existence/contents leak. |

## 8. Design decisions

### 8.1 Owner product decision + honest residual
**LOCKED (owner 2026-09-30):** "folder + test shell."

**LOCKED residual sentence for #1169:** *Windows StepFun is confined to a
disposable review folder and a gated test command path. It is not
mount-isolated. An in-folder test script is arbitrary user-level code on this
PC (same class as Claude Desktop with tools). Owner accepted that residual on
2026-09-30 ("folder + test shell"). Linux remains bubblewrap-isolated.*

Eval flags are **refused** by the gate (not residual). Residual is in-folder
script bodies and runner abuse.

### 8.2 Shell gate — ONE enforceable mechanism (muse C1)
**LOCKED:** The Windows OpenCode turn does **not** get a general bash.

Mechanism (pick after a recorded spike; default is A):
- **A (preferred):** launch OpenCode with the bash tool’s shell overridden to
  `bin/ai-stepfun-windows-shell` (or a wrapper directory first on a frozen
  PATH that provides only that `bash`/`sh`). Spike must prove a command from
  the agent lands in the wrapper (log a nonce).
- **B (fallback):** OpenCode `bash: false` and the only execution tool is an
  explicit `ai-stepfun-windows-shell` invocation the profile exposes if the
  schema allows a custom command tool. If neither A nor B is enforceable,
  **stop and report the gap on #1169** — do not ship instruction-only.

There is no “or tell the agent” branch.

### 8.3 Allowed commands (whole-string) (muse C2, C5, H5, H6, H10)
Parser rejects **any** of: `;` `&&` `||` `|` `&` `` ` `` `$()` `${` `$VAR`
`(` `)` `{` `}` `\` newline `>` `<` `>>` `*` `?` `~` `!` `%` (metavariables),
then requires a single command.

`argv[0]` must resolve on the **frozen PATH** (system dirs only; exclude
review folder, `%USERPROFILE%` writable bins, `WindowsApps`, npm/python/cargo
user bins) to one of:
`npm`, `npm.cmd`, `npx`, `node`, `pytest`, `python`, `python3`, `go`, `cargo`,
`dotnet`, `pwsh`, `powershell`, `bash`, `sh` — **absolute paths to interpreters
are refused**; case-insensitive basename match only; extension via PATHEXT
only.

**Subcommand allowlist** (second token when present; else file script):
| Runner | Allowed | Refused |
|---|---|---|
| `npm` | `test`, `run <name from package.json scripts>` | `publish`, `exec`, `install`, `ci`, `i`, `update`, `link`, `audit`, unknown |
| `npx` | *(not allowlisted as runner — remove from set)* | everything |
| `node` | `node <file under folder>` only | `-e/-p/--eval/--require/-r` |
| `pytest` | `pytest` / `pytest <path under folder>` | `--rootdir` outside, `-c` code |
| `python`/`python3` | `python <file under folder>` only | `-c/-m` (except none), `-` stdin |
| `go` | `go test` / `go build` (module under folder) | `go run` host, `go env -w` |
| `cargo` | `cargo test` / `cargo build` | `cargo publish`, `run` host |
| `dotnet` | `dotnet test` / `dotnet build` | `nuget push`, `run` host |
| `pwsh`/`powershell` | `-File <file under folder>` only | `-Command`, `-EncodedCommand`, `-c` |
| `bash`/`sh` | `<file under folder>` only (no `-c`) | `-c`, stdin, `-i` |

Any file operand must canonicalize under the review folder (realpath +
`cygpath -w`; reject junction/symlink escape **fail-closed**; reject `\\?\`
`\\.` 8.3 ADS forms). `cd`/`pushd`/`popd` in the string ⇒ refuse. Runner
flags that retarget root (`--prefix`, `--manifest-path`, `--rootdir`) ⇒
refuse unless the path argument is under the folder.

### 8.4 Environment + key delivery (muse H8, H9)
**LOCKED:** `env -i` + qwen-style allowlist. Redirect under per-run dir:
`HOME`, `USERPROFILE`, `APPDATA`, `LOCALAPPDATA`, `TEMP`, `TMP`, `TMPDIR`,
`HOMEDRIVE`+`HOMEPATH` (point at per-run home so they cannot recombine to the
real profile). Keep: `SYSTEMROOT`, `COMSPEC`, `PATHEXT`, `USER`, `USERNAME`,
`LOGNAME`, `LANG`, `LC_ALL`, `TERM`, `SSL_CERT_FILE`, `SSL_CERT_DIR`,
`PSModuleAnalysisCachePath` (per-run temp). `PATH` = frozen system list
(written down in code as a constant, tested).

**API key:** parent reads `KEY_STORE` (real profile) and passes **only**
`STEPFUN_API_KEY` (or the exact name OpenCode profile uses) into the child
env. **No disk copy** of the key into the per-run dir. `STEP_API_KEY` and all
other `*TOKEN*`/`*SECRET*`/`*KEY*`/`AWS_*`/`AZURE_*`/`GITHUB_*`/`GIT_*`/
`OP_*`/`DOCKER_*`/`SSH_AUTH_SOCK`/`NODE_PATH`/`PYTHONPATH`/`PSModulePath`
absent (test asserts). OpenCode pin resolved **before** HOME redirect.

### 8.5 File tools (muse C4)
**LOCKED order:** spike first (step 8). If pinned OpenCode supports path-scoped
read/write/edit permissions, use them to the review folder. **If not: Windows
review/ask profiles disable `write`/`edit`/`patch`** (read/glob/grep/list
only, plus gated shell). That is a **named Windows exception to #974** for
file tools; `implement` on Windows then writes only via the gated shell’s
allowlisted runners (tests/builds) and any `write` tool is likewise disabled
unless clamped. Document in rule 11. Never ship unclamped write tools and
call the folder “confined”.

### 8.6 Key store Windows rule (muse M11)
Present, non-empty, not a reparse point (PowerShell `Get-Item -Force |
Attributes` includes `ReparsePoint` ⇒ refuse). No `stat 600` claim on NTFS.
Residual: profile ACLs remain as previously installed.

### 8.7 Deadline (muse M12)
Portable deadline: prefer Git Bash `timeout`; if missing, a background killer
with a recorded deadline (no hang). Test asserts kill-after-N.

### 8.8 Allocator
**LOCKED** out of allocator. Update membership-scope **reason** text only.

### 8.9 Live proof — canary only (muse M13)
Never probe real credentials. Create canary files under a temp “host” tree.
Fail bar:
1. Allowlisted `npm test` / `pytest` **inside folder** → must succeed (A18).
2. Every refused class in §8.3 **must refuse** in the recorded attempt list
   (missing refusal = plan failure, not residual).
3. In-folder script reading a **canary** absolute path via allowlisted runner
   → **record as residual-exfil**: the run may succeed; the record must show
   the canary was read (proves the residual honestly) **without** printing
   canary payload beyond a redacted success bit. If the gate is advertised as
   blocking that path, failure to block is a plan bug — the gate is **not**
   advertised as blocking it.

### 8.10 Install
Reuse OpenCode pin path. New gate script must join the install file-list used
by `C:/repos/ai-devops-reviewer-install` refresh (name the list in code
change).

## 9. Steps (verify each)

Phase A: 1) commit rev D. 2) plan-review → APPROVE at exact head.
3) `ai-task-gates check --before review`.

Phase B: 4) Spike §8.2 mechanism A/B (record result in STATUS). 5) Spike
§8.5 file-tool clamp (record). 6) `require_engine` / `key_store_ok` /
`run_opencode_turn` / env builder per §8.4/§8.7. **Verify:** offline env dump
+ no bwrap on Windows + key only as `STEPFUN_API_KEY`.

Phase C: 7) `bin/ai-stepfun-windows-shell` (LF+exec) per §8.3. 8) Wire
profiles per spike result; `opencode.json` still no MCP. **Verify:** A1–A18.

Phase D: 9) Preflight `static_status`/`reconciled_status`/`explain_failure` +
new class `shell-gate-missing`. 10) Invert tests including PASS-count/skips;
keep StepCode Linux-only test. 11) Docs: rule 11 (honest residual §8.1),
skill, config-inventory, architecture.md:151, usage(), headers `:6-7,132`,
registry + membership-scope reason. 12) AGENTS router + HANDOFF.d backlink.

Phase E: 13) Offline suites + ci-suites registration (name target file).
14) Canary live proof. 15) Exact-head **code** review → APPROVE. 16) PR,
`ai-pr-wait`, merge. 17) Install refresh (incl. gate in file-list) + live
turn. 18) Close #1169 with §8.1 residual sentence + owner quote.

## 10. Adversarial table (canary paths only)

| # | Case | Expected |
|---|---|---|
| A1 | `cat`/`type` canary | refuse (not allowlisted runner) |
| A2 | `python -c` | refuse (eval) |
| A3 | `powershell -Command` | refuse (eval) |
| A4 | `powershell -File <folder.ps1>` | allow |
| A5 | UNC/`\\?\`/8.3 canary path | refuse |
| A6 | in-folder script reads canary | residual-exfil recorded (§8.9) |
| A7 | metachars / `cd` / `pushd` | refuse |
| A8 | `echo > host` | refuse |
| A9 | `git push`/`gh`/`op` | refuse |
| A10 | secret-like env vars absent | assert |
| A11 | profile vars redirected; HOMEDRIVE/HOMEPATH cannot recombine | assert |
| A12 | non-Linux StepCode install fails | keep |
| A13 | Linux without bwrap refuses | keep |
| A14 | MCP on in opencode.json | fail |
| A15 | PATH-planted `npm` | not used (frozen PATH) |
| A16 | `npx --yes`, `npm publish`, `node -e`, `bash -c`, `cmd /c`, `wsl` | refuse |
| A17 | write/edit outside folder | refuse or tools disabled (§8.5) |
| A18 | `npm test` inside folder | must succeed |
| A19 | absolute `C:\...\python.exe canary.py` | refuse (abs interpreter) |
| A20 | `npm --prefix <host>` | refuse |

## 11. Constraints

As rev C, plus: new gate in install file-list; no instruction-only controls;
rollback also deletes canary trees and per-run dirs; residual sentence is
exactly §8.1 (eval flags are **not** residual).

## 12. Access

edge-dev Windows, Git Bash (`C:\Program Files\Git\bin\bash.exe`), no WSL.

## 13. Done / rollback / residual

Done: STATUS DONE; merge SHA; canary proof; install digest; #1169 CLOSED
with §8.1 sentence.

Rollback: revert PR; remove canary/per-run dirs; reinstall previous tree.

Residual: §8.1 sentence only (in-folder scripts / runner abuse). Not
network isolation. Not mount isolation.

## Self-audit

Goal first; file:line §5; rejects §7; LOCKED §8; gates §9; table §10;
rollback §13; STATUS top; code review step 15; muse C1–C4 mapped to
§8.2/§8.3/§8.1+§8.9/§8.5.
