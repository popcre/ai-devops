# IMPLEMENTATION PLAN — StepFun Windows folder + test shell (2026-09-30 rev H)

> Fresh session starts here. If any step conflicts with §1, the goal wins —
> stop and flag it.

## STATUS (one row per §9 step)

| §9 step | Status | Openable evidence |
|---|---|---|
| 1 Rev H + links | DONE this commit | this file |
| 2 Plan APPROVE | OPEN | — |
| 3 S1/S2 spikes | OPEN | — |
| 4 Implement + offline | OPEN | — |
| 5 Canary live proof | OPEN | `tests/verification/stepfun-windows-folder-shell-2026-09-30/README.md` |
| 6 Code review APPROVE | OPEN | — |
| 7 Merge | OPEN | — |
| 8 Install refresh | OPEN | — |
| 9 Close #1169 | OPEN | — |

Prior rejects (full filenames): `.ai/reviews/grok-plan-review-20260930T172515-118426-1832.md`,
`muse-plan-review-20260930T174430-270732-20790.md.stale`,
`muse-plan-review-20260930T203848-1684580-25417.md.stale`,
`muse-plan-review-20260930T223551-2339689-23231.md.stale`,
`grok-plan-review-20261001T005659-3484451-14512.md`,
`grok-plan-review-20261001T011633-3658106-22729.md`,
`grok-plan-review-20261001T013130-3751061-28347.md` (rev G).

## 1. Goal

Windows StepFun explores a disposable review folder and runs tests via one
gated command path. Accident/casual-escape reduction only — not
determined-agent containment, not rule-11 equivalent. Linux bubblewrap
unchanged. **If any step below conflicts with this goal, the goal wins — stop
and flag it.**

## 2–6. Context / trigger / scope / state / cause

As rev G §2–§6 (worktree `C:/repos/ai-devops-wt-stepfun-win`, branch
`stepfun-windows-folder-shell`; owner 2026-09-30 *folder + test shell*;
#1169; OpenCode pin 1.18.12 where `permission` is a no-op and only `tools:`
removes tools — `docs/glm-opencode.md:50-57`). Out of scope unchanged
(incl. no StepFun installer; reuse `bin/setup-opencode-glm.ps1` pin).

## 7. REJECTED (rev H locks)

Shared Linux/Windows agent profile files (grok G P1-1); both `tools.bash`
off **and** PATH shim (P1-2); flipping preflight no-engine cases (P1-3);
A1 forbidding `cat` while exploration needs `cat` (P1-4); children inheriting
shim PATH (P1-5); native vs redirected profile mix (P1-6); empty implement
role (P2-8); open System32 PATH including `wsl.exe` (P2-10).

## 8. Design decisions (contradictions resolved)

### 8.1 Owner residual
**LOCKED 2026-09-30:** *folder + test shell.*

#1169 sentence: *Windows StepFun is confined to a disposable review folder and
a gated test command path. It is not mount-isolated. Windows OpenCode file
tools are removed (only enforcement this pin provides). Exploration and tests
run through the gate. Anything allowlisted runners execute is arbitrary
user-level code on this PC. Registry/network is shared. Owner accepted
2026-09-30.*

### 8.2 Per-OS profiles (P1-1) + one bash story (P1-2)
**LOCKED:** do **not** strip tools on the shared `stepfun-*.md` used by Linux.
Add **Windows-only** profile files:
`config/opencode-stepfun/agent/stepfun-review-windows.md` and
`stepfun-implement-windows.md` (or a `tools:` override chosen by
`run_opencode_turn` on `IS_WINDOWS`). Linux copies stay as today.

**Windows tools map (the only control):**
- Review/ask: **no** `bash`, **no** `write`/`edit`/`patch`/`webfetch`/`task`.
  Read-class: **either** keep `read`/`glob`/`grep`/`list` **only if S2 proves
  path clamp**, else **omit them too** and set `bash: true` **but bound**
  (below). Choose **one** of these two arms in S2; record it. Default if S2
  fails: omit file tools **and** use bound bash as the sole interface.
- **Bound bash (when used):** OpenCode PATH for the turn = shim dir first +
  frozen allowlist dirs (§8.4). Shim is `bash.exe`/`bash`/`sh` only (not
  cmd/pwsh). cmd/pwsh **tools omitted**. Exclusive: S1 nonce proves calls
  land in shim; child runners get PATH **without** shim dir (P1-5).

### 8.3 Launch env (P1-6) — one rule
**LOCKED:** OpenCode process **and** gated children both use the **redirected**
per-run `HOME`/`USERPROFILE`/`APPDATA`/`LOCALAPPDATA`/`TEMP`/`TMP`/`TMPDIR`/
`HOMEDRIVE`/`HOMEPATH` (qwen-style). Real profile is used **only** in the
parent to resolve `OC_BIN`, `KEY_STORE`, and to copy `config/opencode-stepfun`
into the per-run tree (existing `bin/ai-stepfun:196-201`). `bin/ai-deepseek
:33-42` `HOME_DIR` pattern for resolving those paths on Windows.

### 8.4 Frozen PATH (P2-10) — closed list
Child/gate PATH **constant** (no System32 dump):
1. Git `usr\bin` (GNU `timeout`, `bash` for file-runners),
2. Git `cmd`,
3. `%SystemRoot%\System32\WindowsPowerShell\v1.0` (pwsh/powershell only),
4. install-time `where.exe` **hits** for the runner set stored in
   `~/.config/ai-devops/secrets/stepfun-windows-runners.json`
   (`bin/windows-json-file.ps1` + `bin/windows-private-file.ps1` /
   `Protect-AiDevOpsPrivatePath`).

**Never** add `%SystemRoot%\System32` or `WindowsApps` to the gate PATH.
`wsl.exe`/`curl.exe`/`certutil.exe` are not on gate PATH. A16 still refuses
those names if spelled in INNER.

### 8.5 Grammar / paths / runners
As rev G §8.4/§8.7 **with these fixes (P1-4, G P2-4):**
- `ls`, `cat`, `head` are **allowlisted folder-only readers** (not “refuse
  cat”). A1 becomes: `cat <host-or-canary path outside folder>` → refuse;
  `cat <file in folder>` → allow.
- Every path operand (file **and** directory) canonicalized
  (`ai-stepfun-windows-pathclamp.ps1`, backup semantics) and must be under
  the review folder; refuse `..`, `/c/...`, UNC, ADS, 8.3-out, reserved
  devices, trailing-dot/space.
- `:` only inside `npm run <safe-name>` (A25).
- No `npx`, no `git` (Windows reviews use packet + folder readers).

### 8.6 implement on Windows (P2-8)
**LOCKED:** `ai-stepfun implement` on Windows uses the same gate and
**omits** OpenCode write/edit/patch. Code changes are produced by allowlisted
build/test runners and/or by the implementer model emitting a patch file
**inside** the disposable clone via a single new runner `patchfile` that only
writes under the clone (path-checked). If that is too thin, Windows
`implement` exits `unsupported-platform` with a clear message — **choose in
S2 and record**; do not leave the role empty.

### 8.7 Preflight inversion (P1-3)
Invert **only** the Windows+OpenCode+key-store+gate case to usable. Keep
refusal when engine missing (`unsupported-platform: no StepCode CLI and no
OpenCode install`). `explain_failure` gains `shell-gate-missing` and a
Windows-specific key-store message. Tests assert both branches
(`tests/test-ai-review-preflight.sh`).

### 8.8 Files (complete; includes G P2-9)
Rev G §8.6 **plus:**
- `config/opencode-stepfun/agent/stepfun-review-windows.md` (new)
- `config/opencode-stepfun/agent/stepfun-implement-windows.md` (new)
- `bin/ai-stepfun-windows-pathclamp.ps1` (+ `.cmd` sibling)
- concrete `HANDOFF.d/2026-09-30T2200Z-edge-dev-stepfun-windows-folder-shell.md`
  with reciprocal links to this plan
- `tests/verification/stepfun-windows-folder-shell-2026-09-30/README.md`
  (canary record home — no ellipsis)
- `tests/fixtures/stepfun-windows-shell/pkg/` (A18 fixture)
- `docs/task-router.md` StepFun Windows row
- `config/provider-cli-versions.json` drop Ubuntu-only absolute

### 8.9 Adversarial table
Rev G §8.7 (A1–A26) **as amended:** A1 split (folder `cat` allow vs outside
refuse); A27 `implement` mode matches §8.6 choice; A28 gate PATH has no
`System32`/`wsl`. Each row still has a named `check "…"` in
`tests/test-ai-stepfun-windows-shell.sh`.

### 8.10 Access
1Password vault `vibe_coding`, item `stepfun step5 ai api key` (`OP_REF` at
`bin/ai-stepfun:50`) — titles only. Live key store as today.

## 9. Steps (you’ll know it worked when)

1. Rev H committed with AGENTS + task-router + HANDOFF + index links.
   **Know:** `bin/ai-doc-reachability` passes on the PR.
2. Plan-review exact head → APPROVE naming head SHA.
3. S1 exclusive-shim nonce + S2 arm choice (file tools / implement) in STATUS.
   **Know:** nonce log + written arm.
4. Implement §8.8; `bin/ai-test-local --check-collision` then offline suites.
   **Know:** Windows shell suite + inverted stepfun/preflight tests green on
   Git Bash; Linux keep-green (§10.1) still green.
5. Canary proof at `tests/verification/stepfun-windows-folder-shell-2026-09-30/`.
   **Know:** per-check outcomes + turn id + no canary payload in output.
6. Exact-head code review APPROVE.
7. PR + `bin/ai-pr-wait` + merge. **Know:** merge SHA on `origin/main`.
8. Refresh `C:/repos/ai-devops-reviewer-install`. **Know:** digest matches;
   preflight usable; one live Windows turn.
9. Close #1169 with §8.1 sentence + owner quote + evidence links.

## 10. Tests
§10.1 Linux keep-green (rev G). §10.2 Windows `check` names from §8.9.
CI suite `config/ci-suites/test-ai-stepfun-windows-shell.sh.json` with
`windows: ["offline"]`.

## 11–13. Constraints / access / done
As rev G §11–§13. Done = §9 all known-passed + #1169 closed with §8.1.

## Self-audit vs grok rev G
P1-1 profiles → §8.2 · P1-2 bash/shim → §8.2 · P1-3 preflight → §8.7 ·
P1-4 cat → §8.5 · P1-5 child PATH → §8.2/§8.4 · P1-6 env → §8.3 ·
P2-4 paths → §8.5 · P2-8 implement → §8.6 · P2-9 files → §8.8 ·
P2-10 PATH → §8.4 · P3 mechanics → STATUS + §8.8 + §8.10 + §1 sentence.
