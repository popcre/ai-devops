# IMPLEMENTATION PLAN — StepFun Windows folder + test shell (2026-09-30 rev J)

> Fresh session starts here. If any step conflicts with §1, the goal wins —
> stop and flag it.

## STATUS (order is spike → plan code review → implement)

| Step | Status | Openable evidence |
|---|---|---|
| S2 spike (file-tool clamp on pin 1.18.12) | **DONE — no clamp** | `docs/glm-opencode.md:50-57,397-398` (permission maps no-ops; only `tools:` removes tools). Default arm locked: **omit** read/glob/grep/list/write/edit/patch on Windows. |
| S1 spike (bash shim exclusivity) | OPEN | must prove before merge |
| Rev J | DONE | this file |
| Plan code-ready review | OPEN | after S1; plan may be implemented in parallel with S1 as the only open gate |
| Implement → close #1169 | OPEN | §9 |

Reject artifacts (full names): `grok-plan-review-20260930T172515-118426-1832.md`;
`muse-plan-review-20260930T174430-270732-20790.md.stale`;
`muse-plan-review-20260930T203848-1684580-25417.md.stale`;
`muse-plan-review-20260930T223551-2339689-23231.md.stale`;
`grok-plan-review-20261001T005659-3484451-14512.md`;
`grok-plan-review-20261001T011633-3658106-22729.md`;
`grok-plan-review-20261001T013130-3751061-28347.md`;
`grok-plan-review-20261001T014359-3859181-25310.md.stale`;
`muse-plan-review-20261001T111640-23729-5771.md`.

## 1. Goal

Windows StepFun: disposable review folder + one gated test path.
Accident/casual-escape reduction only. Not rule-11. Linux bubblewrap unchanged.
**If any step below conflicts with this goal, the goal wins — stop and flag it.**

## 2–6. Context (summarized)

Owner 2026-09-30 *folder + test shell* (no WSL). #1169. Worktree
`C:/repos/ai-devops-wt-stepfun-win`. Pin `config/opencode/version` = 1.18.12.
Only `tools:` enforces. Out: WSL, weaken Linux, StepCode Windows, allocator
membership, StepFun installer (reuse `bin/setup-opencode-glm.ps1`).

## 7. REJECTED

Two-arm file tools (S2 closed the arm); approve-before-S1; host PATH copy;
`permission` clamps; shared Linux/Windows profiles; native+redirected mix;
instruction-only controls; `npx`/`git` runners; empty implement with no
message.

## 8. LOCKED decisions

### 8.1 Residual (exact #1169 sentence)
*folder + test shell.* Owner 2026-09-30.

*Windows StepFun is confined to a disposable review folder and a gated test
command path. It is not mount-isolated. OpenCode file tools are removed on
Windows (only enforcement on this pin). Exploration and tests run through the
gate (`ls`/`cat`/`head` in folder + allowlisted test runners). Anything those
runners execute — including `package.json` scripts and lifecycle hooks — is
arbitrary user-level code on this PC. Registry/network is shared. Owner
accepted 2026-09-30.*

### 8.2 Windows tools (S2 closed)
Per-OS profiles `stepfun-review-windows.md` / `stepfun-implement-windows.md`.
`tools:` map: **omit** `read,glob,grep,list,write,edit,patch,webfetch,task`.
**Bound bash only:** `bash: true` with PATH shim (S1). **cmd/powershell/pwsh
tools omitted** (no second story). Linux `stepfun-*.md` unchanged.
`implement` on Windows exits `unsupported-platform` (review/ask only).

### 8.3 Launch contract
No bwrap. Parent resolves `OC_BIN`/`KEY_STORE` via real profile
(`bin/ai-deepseek:33-42` `HOME_DIR` pattern). Child/OpenCode env: **fully
redirected** `HOME USERPROFILE APPDATA LOCALAPPDATA TEMP TMP TMPDIR HOMEDRIVE
HOMEPATH` under per-run dir + profile copy (`bin/ai-stepfun:196-201`).
Keep env: `SYSTEMROOT LANG LC_ALL TERM SSL_CERT_FILE SSL_CERT_DIR
PSModuleAnalysisCachePath`. **Do not keep** `COMSPEC` `PATHEXT` `USERPROFILE`
native. Deadline: absolute Git `usr\bin\timeout` (`bin/windows-git-bash-path.ps1`)
else `taskkill /T /F` (A22b notes detached-survive residual).

### 8.4 Frozen PATH (concrete)
Gate child PATH **only**:
1. `<git>\usr\bin`
2. `<git>\cmd`
3. `<git>\mingw64\bin` if present
4. Absolute paths from `~/.config/ai-devops/secrets/stepfun-windows-runners.json`

JSON written at install (`where.exe` **absolute** under sanitized PATH;
`bin/windows-json-file.ps1` + `Protect-AiDevOpsPrivatePath`). Each entry:
`{path, sha256}`. Runtime refuses if hash mismatch or missing (doctor rewrites
only via install). Refuse WindowsApps stubs / wsl / ambiguity. OpenCode process
PATH = shim dir first + this list. **Children do not get the shim dir.**

### 8.5 Shim + grammar
Layer0: `bash.exe` shim accepts OpenCode `-c|-lc|--noprofile --norc -c` only;
extract INNER. Layer1: INNER is one invocation (tokens split on spaces;
**paths may contain spaces only if single-quoted in INNER — quotes allowed
only around path tokens**; refuse other quotes/metachars `; & | ( ) { } [ ] < >
\ ` $ ~ * ? ! % ^ @ #`). `:` only in `npm run <name>`. CWD = review folder.

Every path operand (file/dir): `ai-stepfun-windows-pathclamp.ps1`
(`GetFinalPathNameByHandle` + backup semantics) must resolve under review
folder (case-insensitive). Refuse `..`, `/c/...`, UNC, ADS, 8.3-out,
`NUL`/`CON`/`COM1`, trailing-dot/space, `\\.\` `\\?\`.

Runners (absolute-path identity + sha256 pin): `npm`(`test`|`run name`),
`node`(`file`), `pytest`(`[path]`), `python`/`python3`(`file`),
`go`(`test`|`build`), `cargo`(`test`|`build`), `dotnet`(`test`|`build`),
`bash`/`sh`(`--noprofile --norc file` via **real** Git bash abs path),
`ls`/`cat`/`head` (folder-only). No `npx`, no `git`. Unknown flags refuse.

### 8.6 Files (complete + muse medium)
Rev G list **plus** `tests/fixtures/stepfun-windows-shell/pkg/package.json`;
`.doc-reachability.json` if needed; `.gitattributes` note for LF; explicit
`.cmd` for **every** new `bin/*` (no “if”); `config/ci-suites/
test-ai-stepfun.sh.json` membership edit; concrete
`HANDOFF.d/<generated-utc>-edge-dev-stepfun-windows-folder-shell.md` at write
time (not a fixed clock); `tests/verification/stepfun-windows-folder-shell/`
(dir name without hardcoded day if slips); install step that **writes**
`stepfun-windows-runners.json` (extend `bin/install-ai-provider-clis.sh` or
`bin/ai-stepfun doctor --write-runners` — one named owner in code).

Preflight invert **enumerated**:
- `tests/test-ai-review-preflight.sh:286-287` Linux asserts **keep**
- `:288` Windows-without-engine **keep refusal**
- `:289` Windows-even-with-OpenCode **invert** to usable when key+gate present
- `:290` explain string **replace** with Windows message + `shell-gate-missing`

`tests/test-ai-stepfun.sh:195` invert; PASS-count `:110,:202-203` update;
`:211-213` Linux bwrap keep.

Rule 11 / registry / membership-scope **string sites**:
`docs/reviewer-rotation-rules.md` rule 11; `bin/ai-stepfun` header + usage;
`bin/ai-review-preflight:252-256,325`; `config/reviewer-registry.json` reason;
`config/reviewer-membership-scope.json` reason (stay out of allocator);
`config/provider-cli-versions.json:30-35`; `docs/architecture.md:151`;
`docs/config-inventory.md`; `docs/task-router.md`; `skills/shared/stepfun/SKILL.md`.

### 8.7 Adversarial table (check names)
As rev G A1–A26 **plus**: A22b detached-survive note; A27 implement refused;
A28 gate PATH lacks System32/wsl; A29 runner sha256 mismatch refuse;
A30 `package.json` script exfil = residual recorded (paired with A18).
A1 = outside `cat` refuse **and** in-folder `cat` allow.

### 8.8 Owner evidence
Owner quote recorded on #1169 comment
`https://github.com/popcre/ai-devops/issues/1169#issuecomment-5916123210`
(2026-09-30). Cite that comment at close.

## 9. Steps
1. S1 shim nonce spike (open). 
2. Implement §8 (parallel with S1; merge blocked on S1+tests).
3. Offline suites (`ai-test-local --check-collision` first).
4. Canary proof `tests/verification/stepfun-windows-folder-shell/`.
5. Exact-head **code** review APPROVE.
6. PR + `ai-pr-wait` + merge. Install refresh + live turn. Close #1169.

## 10. Tests
Linux keep-green: `tests/test-ai-stepfun.sh:211-213` and StepCode paths.
Windows: every `check "…"` in `tests/test-ai-stepfun-windows-shell.sh`.
CI suite json with `windows: ["offline"]`.

## 11–13. Constraints / access / done
Git Bash not WSL; `bin/ai-gh`; no secrets in logs; sign GitHub; EST times.
1Password titles only (`vibe_coding` / `stepfun step5 ai api key`).
Done = S1 proven + suites green + canary record + code APPROVE + merge SHA +
install digest + #1169 closed with §8.1 + comment link.
