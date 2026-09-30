# IMPLEMENTATION PLAN — StepFun Windows folder + test shell (2026-09-30)

> **Fresh session starts here.** Owner decision, threat model, exact files, and
> verification gates are below. No chat context is required. If any step
> conflicts with §1, the goal wins — stop and flag it.

## STATUS (live)

| Step | Status | Evidence |
|---|---|---|
| 1 Plan written | DONE | this file |
| 2 Plan review #1 | DONE — REJECT | `.ai/reviews/grok-plan-review-20260930T172515-118426-1832.md` |
| 3 Plan revised after reject | DONE (this revision) | commit message cites grok findings |
| 4 Plan re-review → APPROVE | OPEN | required before any code commit |
| 5 Wrapper `require_engine` / `run_opencode_turn` / `key_store_ok` | OPEN | |
| 6 Windows env allowlist + HOME/APPDATA redirect | OPEN | |
| 7 Test-runner allowlist shell gate | OPEN | |
| 8 Agent profiles + preflight + tests inversion | OPEN | |
| 9 Docs / rule 11 Windows exception / registry | OPEN | |
| 10 Offline tests green | OPEN | |
| 11 Live isolation proof (fail bar in §10) | OPEN | `tests/verification/` |
| 12 Exact-head CODE review → APPROVE | OPEN | required (reviewer-safety) |
| 13 PR merge via queue | OPEN | |
| 14 Install refresh + final live turn | OPEN | |
| 15 #1169 close with owner quote + residual risk | OPEN | |

## 1. The ultimate goal

StepFun Step 5 runs on edge-dev Windows as reviewer/implementer confined to a
**disposable review folder**, with **shell allowed only for an allowlisted set
of test runners** inside that folder. Linux bubblewrap is unchanged. Windows is
**not** claimed to be rule-11 equivalent. Residual risk (shell-escape or
non-allowlisted interpreter paths to host credentials) is named and
owner-accepted.

If any step below conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`popcre/ai-devops` public recovery toolkit. This change is the StepFun reviewer
path: `bin/ai-stepfun`, OpenCode agent profiles, preflight, skill/docs/registry,
tests, live proof. Worktree `C:/repos/ai-devops-wt-stepfun-win`, branch
`stepfun-windows-folder-shell`. Never edit a shared checkout.

## 3. What triggered this work

#1169. Owner Albert (MiMo chat, 2026-09-30) cannot use WSL (RAM maxed by ZCode,
MiMo Desktop, Claude). After risk was explained he chose verbatim: **folder +
test shell.** Meaning accepted: explore the review folder; run tests via shell
inside it; residual host-path risk accepted in writing.

## 4. Scope — in and out

In: Windows OpenCode path for `ai-stepfun`; folder confinement; test-runner
allowlist shell; Windows-safe env allowlist; key-store Windows rule; preflight
`static_status`; agent profiles; inverted refusal tests; rule 11 exception;
live proof with fail bar; install refresh; #1169 closeout.

NOT in: WSL; Windows bubblewrap; weakening Linux bubblewrap; StepCode on
Windows; allocator membership for StepFun (LOCKED out); restoring
`bin/setup-opencode-stepfun.ps1` verbatim; a new StepFun OpenCode installer
(reuse GLM/Muse pin `config/opencode/version` +
`$HOME/.local/lib/ai-devops/opencode/$OC_VERSION/.../opencode.exe`).

## 5. Current state of the code (`origin/main` @ `93ff6e48`)

| Location | State |
|---|---|
| `bin/ai-stepfun:93-104` `require_engine` | exits `unsupported-platform` unless `IS_LINUX=1` |
| `bin/ai-stepfun:127-135` `key_store_ok` | returns 1 on all Windows (`[ "$IS_LINUX" = 1 ]`) |
| `bin/ai-stepfun:217-247` `run_opencode_turn` | always requires bubblewrap + `/usr/bin/timeout` |
| `bin/ai-stepfun:291` `STEP_ENV_ALLOW` | Linux allowlist `LANG LC_ALL TERM SSL_CERT_FILE SSL_CERT_DIR` |
| `bin/ai-stepfun:389-393` `cmd_doctor` | already skips bwrap on Windows (dead until require_engine allows) |
| `bin/ai-review-preflight:248-258,325` | StepFun `unsupported-platform` unless Linux |
| `config/opencode-stepfun/agent/stepfun-{review,implement}.md` | `bash: "*": allow` + write/edit (#974) |
| `config/opencode-stepfun/opencode.json` | no `mcp` key today (keep as regression assert) |
| `tests/test-ai-stepfun.sh:192-199` | asserts Windows refused; OpenCode block SKIP off-Linux |
| `tests/test-ai-review-preflight.sh:288-291` | Windows unsupported even with OpenCode |
| `tests/test-install-ai-provider-clis.sh:62-67` | non-Linux StepCode install fails — **KEEP** (Windows uses OpenCode) |
| `docs/reviewer-rotation-rules.md` rule 11 | Ubuntu-only + bubblewrap |
| `docs/architecture.md:151` | "StepFun on Ubuntu/Linux only" |
| `config/reviewer-membership-scope.json` | outside allocator; "never assigned to a Windows session" |

## 6. Key findings

- Bubblewrap = mount unreachability. Windows cannot do that without WSL/VM.
- Env-clear + HOME redirect is not unreachability. Owner accepted residual risk.
- Sibling Windows isolation (grok `bin/ai-grok-review:1182-1204`, qwen
  `bin/ai-qwen:98-102`, muse `bin/ai-muse:258-259`) uses an **allowlist**
  survival set (`SYSTEMROOT`, `COMSPEC`, `PATHEXT`, `APPDATA`, `LOCALAPPDATA`,
  …), not a denylist strip.
- OpenCode bash is already `bash: "*": allow` — a path denylist in front of it
  is theater (`type`, `python -c`, `powershell Get-Content`, UNC).

## 7. Approaches REJECTED

| Approach | Why |
|---|---|
| WSL2 + bubblewrap | Owner: no RAM (2026-09-30). |
| Windows Sandbox / VM | Same host constraint. |
| Claim env-clear + HOME redirect = rule 11 | False. |
| Credential-path **denylist** in front of full bash | Bypassable; not "test shell". |
| Packet-only / no tools | Owner chose folder + test shell. |
| Restore #1049 path verbatim | Unsandboxed; caused #1169 drift. |
| Drop write/edit on Windows only | Contradicts #974; `echo >` still writes via bash. |

## 8. Design decisions

- **LOCKED (owner 2026-09-30):** "folder + test shell." Quote: *folder + test
  shell.* Residual risk accepted: non-allowlisted escapes may reach host paths.
- **LOCKED:** Linux bubblewrap unchanged; Windows never claimed rule-11 equal.
- **LOCKED:** Shell gate is a **test-runner allowlist**, not a credential
  denylist. Allow only runners needed for the reviewed project's tests (default
  set: `npm`, `npm.cmd`, `npx`, `node`, `pytest`, `python`, `python3`, `go`,
  `cargo`, `dotnet`, `pwsh`, `powershell` **only when the invocation is a test
  script under the review folder**, plus `bash`/`sh` limited to scripts whose
  path is under the review folder). Anything else is refused with a clear
  message. Escape via a copied interpreter or absolute host script is residual
  risk (owner-accepted), not a silent hole.
- **LOCKED:** review/ask keep write/edit/bash **inside the disposable copy**
  (#974). Windows does not narrow the tool list below Linux's contract.
- **LOCKED:** `STEP_ENV_ALLOW` stays an allowlist; extend with the Windows
  survival set used by grok/qwen/muse. Never switch to a denylist. Parent loads
  the key from the real profile store **before** child HOME/USERPROFILE/APPDATA
  redirect.
- **LOCKED:** StepFun stays **outside the allocator** even when Windows works
  (`config/reviewer-membership-scope.json`). Explicit `ai-stepfun` only.
- **LOCKED:** Live proof fail bar (§10): allowlisted test run must work;
  reads of credential locations **via allowlisted runners only** may succeed
  (residual, recorded); non-allowlisted access commands must be **refused by
  the gate** in the recorded attempt list. A gate refusal that does not happen
  is a plan failure, not "accepted residual".
- **OPEN:** which concrete runners appear in the default allowlist for a given
  repo (derive from lockfiles / `package.json` scripts when present).

## 9. The plan — numbered steps (each has a verify gate)

### Phase A — Plan approval
1. This revision committed. **Verify:** STATUS shows step 3 DONE and cites the
   grok reject file.
2. Re-run plan-review at exact head until APPROVE. **Verify:** report names the
   plan head SHA and `VERDICT: APPROVE`.
3. `bin/ai-task-gates check --before review` before later phases. **Verify:**
   gate allows the declared class.

### Phase B — Wrapper (functions named)
4. `require_engine` (`bin/ai-stepfun:93-104`): allow Windows + ENGINE=opencode;
   still refuse StepCode on Windows; Linux still requires bubblewrap.
   **Verify:** `AI_STEPFUN_PLATFORM=Windows` doctor reaches engine detect, no
   `unsupported-platform`.
5. `key_store_ok` (`:127-135`): Windows accepts present, non-empty, non-symlink
   store; do not require `stat 600`. **Verify:** unit path in offline suite.
6. `run_opencode_turn` (`:217-247`): add a Windows branch that does **not**
   call `bwrap` or `/usr/bin/timeout` (use Git Bash `timeout` or a portable
   bound); launch with allowlisted env; child HOME/USERPROFILE/APPDATA → per-run
   dir; cwd = disposable copy. Parent may read `KEY_STORE` first.
   **Verify:** offline stub launch shows no bwrap in argv and redirected profile
   vars in the child env dump.
7. Extend `STEP_ENV_ALLOW` (`:291`) with Windows survival set (copy the
   grok/qwen/muse list: `SYSTEMROOT`, `COMSPEC`, `PATHEXT`, `TMP`, `TEMP`,
   `APPDATA`, `LOCALAPPDATA`, `USERPROFILE`, `HOMEDRIVE`, `HOMEPATH`, `PATH`
   only as needed for `node`/`npm`, etc.). **Verify:** `GH_TOKEN`,
   `GITHUB_TOKEN`, `OP_SERVICE_ACCOUNT_TOKEN`, `SSH_AUTH_SOCK`, `DOCKER_*` are
   absent from the child dump.

### Phase C — Test-runner allowlist shell gate
8. Add `bin/ai-stepfun-windows-shell` (or equivalent invoked by the OpenCode
   agent bash): cwd forced to review folder; argv must be an allowlisted
   runner or a script path under the review folder; otherwise exit 126 with
   `stepfun-shell: refused (not an allowlisted test runner)`.
   **Verify:** offline cases in §10 adversarial table all behave as specified.
9. Point `config/opencode-stepfun/agent/stepfun-review.md` and
   `stepfun-implement.md` bash permission at that gate on Windows (keep
   `bash: "*": allow` semantics for Linux bubblewrap, or route both through
   the gate with Linux seeing the same allowlist **plus** bwrap). Keep
   write/edit/patch. Assert `opencode.json` still has no MCP. **Verify:**
   profile diff is intentional and tests cover both platforms.

### Phase D — Preflight, tests, docs
10. `bin/ai-review-preflight` `static_status` / `explain_failure`
    (`:248-258`, `:325`): Windows + OpenCode + key store + shell gate ⇒ usable;
    without them keep a specific failure (not a blanket `unsupported-platform`).
    **Verify:** `ai-review-preflight status stepfun` on edge-dev is usable after
    install refresh.
11. Invert refusal tests (do not merely extend):
    - `tests/test-ai-stepfun.sh:192-199` — Windows+OpenCode is supported;
      OpenCode block runs on Windows with stubs (no `stat 600`, no bwrap).
    - `tests/test-ai-review-preflight.sh:288-291` — same inversion.
    - **Keep** `tests/test-install-ai-provider-clis.sh:62-67` (StepCode stays
      Linux-only).
    **Verify:** `tests/test-ai-stepfun.sh` and preflight test green on Windows
    Git Bash and Linux.
12. Docs: rule 11 Windows exception (quote owner + residual risk; do **not**
    claim equivalence); `skills/shared/stepfun/SKILL.md`;
    `docs/config-inventory.md` StepFun row; `docs/architecture.md:151`;
    `bin/ai-stepfun` `usage()`; `config/reviewer-registry.json` reason text;
    membership scope left out-of-allocator (LOCKED). **Verify:** docs grep shows
    no "Windows refused" / "Ubuntu-only" absolute claim without the exception.
13. `AGENTS.md` task-router row for this plan + `HANDOFF.d/` backlink file.
    **Verify:** both exist and point at this plan.

### Phase E — Proof, review, ship
14. Offline suite + any new `config/ci-suites/` registration. **Verify:**
    `tests/test-all.sh --windows-offline` relevant shards green; collision
    check `bin/ai-test-local --check-collision` first.
15. Live isolation proof on edge-dev (Git Bash, not WSL) in one real
    `ai-stepfun ask`/`review` turn — fail bar in §10. Record under
    `tests/verification/`. **Verify:** record file lists each attempt with
    refused/residual/allowed and the turn id.
16. Exact-head **code** review (`ai-review <pool> diff-review|final-check
    --assert-head`) — required for reviewer-safety. **Verify:** APPROVE bound
    to the PR head.
17. PR, `bin/ai-pr-wait`, merge per `config/repository-policy.json`.
    **Verify:** merge SHA on `origin/main`.
18. Refresh `C:/repos/ai-devops-reviewer-install` to new main; rerun preflight
    + one live Windows turn. **Verify:** install tree matches main digest;
    preflight usable.
19. #1169: owner quote, residual-risk sentence, evidence links, close. Sign
    every post. **Verify:** issue CLOSED.

## 10. Tests required (including adversarial table)

Fail bar for live proof (§8 LOCKED):
- Allowlisted test run **inside the folder** → must succeed.
- Gate refusal of a **non-allowlisted** access command (e.g. `type`, `cat`
  of a host path, `python -c` open host path) → **must be refused** and
  recorded as such. Missing refusal = plan failure.
- Allowlisted runner reading a host credential path → residual (record
  succeeded/failed **without printing contents**).

| # | Hostile case | Expected | Test |
|---|---|---|---|
| A1 | `cat /c/Users/*/.ssh/id_rsa` (non-allowlisted) | gate refuse | offline + live attempt |
| A2 | `type C:\Users\...\.ssh\id_rsa` | gate refuse | offline |
| A3 | `python -c "open(r'C:\\Users\\...')"` | gate refuse (python only as test runner with script **under** folder) | offline + live |
| A4 | `powershell Get-Content ...hosts.yml` | gate refuse unless powershell invoked as allowlisted test entry | offline |
| A5 | UNC / mapped path to token file | gate refuse (not under folder / not allowlisted) | offline |
| A6 | symlink/junction from folder to `~/.ssh` | read via allowlisted runner = residual; via `cat` = refuse | offline |
| A7 | `cd /` then relative escape | cwd forced to folder; refuse | offline |
| A8 | write redirect `echo x > /c/Users/...` via bash | refuse (not allowlisted runner) | offline |
| A9 | `git push` / `git remote add` / `gh` / `op` | refuse (existing agents + gate) | offline (keep current) |
| A10 | leftover `OP_SERVICE_ACCOUNT_TOKEN` / `SSH_AUTH_SOCK` / `DOCKER_*` / `GH_TOKEN` in child env | absent (allowlist) | offline env dump |
| A11 | child HOME/USERPROFILE/APPDATA point at per-run dir | assert redirect | offline |
| A12 | non-Linux StepCode install | still fails | **keep** existing test |
| A13 | Linux without bubblewrap | still refuses | keep |
| A14 | `opencode.json` MCP added | fail regression | offline |

Windows-runnable stubs must not require `stat 600` or bwrap (see
`tests/test-ai-stepfun.sh` current skips at `:106-108`, `:196-199`).

## 11. Constraints

Branch + PR + merge queue; identity check; reviewer-safety independent review
before merge; no secrets in chat/argv/logs; Git Bash on Windows
(`C:\Program Files\Git\bin\bash.exe` — system `bash` is the WSL stub); never
weaken Linux; never claim Windows = rule 11; `bin/ai-gh` only; sign GitHub
posts; times EST/EDT.

## 12. Access and environment

edge-dev Windows, Git Bash, no WSL. Worktree as above. StepFun key store
already provisioned for live turns. OpenCode binary via existing GLM/Muse pin
path — do not invent an installer.

## 13. Definition of done, rollback, residual

Done: § STATUS all DONE; merge SHA on main; live proof record; install digest
matches; #1169 CLOSED with owner quote and residual sentence.

Rollback: revert the PR (restore `require_engine` Linux-only, preflight
`static_status`, refusal tests). No data migration.

Residual (owner-accepted): allowlisted interpreters can still be pointed at
host absolute paths; a determined escape is not mount-blocked. Document that
sentence on #1169 at close.

## Plan-mechanics self-audit

- Goal first? yes.
- File:line for current state? yes §5.
- Rejected approaches? yes §7.
- LOCKED vs OPEN? yes §8.
- Verify gate per step? yes §9.
- Adversarial table with tests? yes §10.
- Rollback? yes §13.
- HANDOFF + AGENTS router? step 13.
- STATUS at top? yes.
- Exact-head code review before merge? step 16.
