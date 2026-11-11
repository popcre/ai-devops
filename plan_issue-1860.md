---
summary: Plan for issue 1860 ZCode headless runs failing after auto-update; fixed through PR 2370, proven live and issue closed 2026-11-04.
kind: plan
status: done
read-when: Checking the ZCode headless auto-update fix (issue 1860)
---

# Implementation plan — popcre/ai-devops#1860: ZCode headless runs fail after auto-update

## VERDICT (checked 2026-11-04 3:54 PM EST): STILL REAL — not fixed, not obsolete

Live re-test on edge-dev (Windows 11), 2026-11-04 3:54 PM EST:

- ZCode desktop is now **3.17.2.9661**, CLI core **0.17.1** (`ai-zcode version` → `ai-zcode 1.0.0; cli core: 0.17.1`).
  Runtime provider dirs exist for 3.12.3, 3.14.3, 3.14.4, 3.15.3, 3.16.2, 3.16.3, 3.17.1, 3.17.2 under
  `%USERPROFILE%\.zcode\v2\runtime\provider\windows-x86_64\`.
- `ai-zcode ask "Reply with the word OK only."` still fails, exit 1, before any model answer:
  `[project-access-token] { family: 'zai', stage: 'resolve', code: 'project_token_login_failed' }`
  then `Error: Turn execution failed (traceId: d946fbc2-…)`.
- `~/.zcode/v2/credentials.json` was last written 2026-10-19 2:41 PM EDT (two hours after the 12:39 PM update) —
  so a re-login was attempted after the break and it did not fix headless runs.
- Five ZCode updates since the issue was filed did not self-heal it. No later issue covers it
  (searched `zcode` across all popcre/ai-devops issues; #1859, #817, #828, #884 are closed and unrelated).
- The issue has no comments; the body is the only prior evidence.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Owner decision (keep vs retire headless ZCode) | ✅ keep | Albert on #1860, 2026-11-04 |
| 2 Diagnose fresh-process token path | ✅ fresh `login zai` | [evidence](tests/verification/zcode-windows-2026-11-04/README.md) |
| 3 Fix in `bin/ai-zcode` | ✅ error + `doctor` | PR #2370 |
| 4 Re-qualify STEP 0 + evidence folder | ✅ | same evidence |
| 5 Tests | ✅ | `tests/test-ai-zcode.sh` |
| 6 PR, merge, live proof, close #1860 | ✅ | #2370 merged, installed on edge-dev, proof on #1860 (closed) 2026-11-04 |

Handoff link: none; the work finished in one session.

---

## Part 1 — Why

### 1. Ultimate goal
Other AI sessions on Albert's machines must be able to hand a question or a small task to ZCode (the GLM-5.3 desktop
coding app) **without a person at the keyboard**, and get a real answer back. Today every such hand-off dies at login,
so anything that relies on it (blocker-watch wakes of ZCode sessions, ZCode-lane proofs such as the headroom proxy
check) silently can't run. Done = a fresh, unattended `ai-zcode ask` returns a GLM answer on edge-dev on the current
ZCode version, and the wrapper tells the caller clearly what to do if a future update breaks login again.

**If a step conflicts with this goal, the goal wins — stop and flag it on #1860.**

### 2. What this application is
- Repo `popcre/ai-devops` (public): Albert's AI toolkit — wrappers, skills, global instructions installed on every
  machine. Default branch `main` (protected; branch + PR, AI merges).
- `bin/ai-zcode` (329 lines, bash, runs under Git Bash on Windows): the only supported headless driver for ZCode's
  CLI core `C:\Program Files\ZCode\resources\glm\zcode.cjs`, launched through `ZCode.exe` with
  `ELECTRON_RUN_AS_NODE=1`. Commands: `ask`, `doctor [--live]`, `version`.
- ZCode is installed only on **edge-dev** (Windows 11; reachable as `ssh edge-dev`, default shell cmd — run bash via
  `"C:\Program Files\Git\bin\bash.exe" -l` reading a script on stdin). ZCode auto-updates itself.
- Related consumers: `bin/ai-blocker-watch` (~line 854 resolves the newest `zcode-builtin.json`; ~913 substitutes
  `{zcode_builtin}` for `zcode --resume` wakes), `bin/ai-zcode-headroom`.

### 3. Trigger
Issue #1860 (opened 2026-10-19): since the auto-update to desktop 3.15.3.8237 / CLI 0.16.9 at 12:39 PM EDT that day,
every fresh headless process fails with `project_token_login_failed`. The desktop app's own log at that moment showed
`project_token_scope_invalidated`, then recovered by itself; only fresh non-GUI processes stay broken. Control-tested
with the original provider config: same failure, so headroom/provider edits are not the cause.
Reproduce: on edge-dev, `ai-zcode ask "Reply with the word OK only."` (see verdict).

### 4. Scope
In: make fresh headless ZCode runs authenticate on the current version; update `bin/ai-zcode` STEP 0 block, `doctor`
login check, and error message; new verification evidence folder; tests.
NOT in this plan: ZCode reviewers (owner ruling 2026-09-17: never); blocker-watch redesign; headroom lane proof
(#1859 closed — re-run only as a bonus check); other machines; any ZCode MCP/skills work; pinning or disabling
ZCode auto-update (rejected, §7).

## Part 2 — What we know

### 5. Current state of the code
- `bin/ai-zcode` lines ~20–40: STEP 0 block qualified 2026-09-17 against desktop 3.12.3.7463 / CLI 0.16.5. Says env
  assembly of three `ZCODE_*_PROVIDER_CONFIG_FILE` vars is mandatory; auth is Z.AI OAuth in
  `~/.zcode/v2/credentials.json`. Stale since 0.16.9.
- `resolve_runtime_provider_config` (~line 104) picks the newest `runtime/provider/*/*/*/zcode-builtin.json` — still
  works (3.17.2 dir present).
- `provider_env` (~119) exports the three vars + `ELECTRON_RUN_AS_NODE=1`.
- `cmd_ask` (~185–232) runs the CLI with `--mode`, `--json -p`; on non-zero exit dumps stderr and dies generically.
- `doctor` (~235+) reports login as "credentials.json exists" — that is now a false-green: the file exists and login
  still fails.
- Evidence of the original qualification: `tests/verification/zcode-windows-2026-09-17/README.md`.
- Tests: `tests/test-ai-zcode.sh`, `tests/test-ai-zcode-headroom.sh` (stub-based, no live ZCode).
- Nothing for #1860 is committed anywhere.

### 6. Key findings
- Failure is in the CLI's project-access-token resolve for the `zai` family, before any model call.
- The update invalidated the token scope; the GUI re-resolves (it holds an in-process session/refresh path), a fresh
  process cannot with only `credentials.json`.
- Re-login on 10-19 2:41 PM did not help, and 5 later updates did not help → it is not transient.
- CLI 0.17.1 `--help` exposes: `login [zai|bigmodel]` (browser authorization only), `logout`, `doctor`,
  `app-server` (ZCode Protocol stdio server), `--surface terminal|desktop`, `--mode … guarded`. `--surface desktop`
  and `app-server` are untested leads for borrowing the desktop app's auth. `doctor` (the CLI's own) is untested.
- Second lead: `bigmodel` family login (`login bigmodel`) may avoid the `zai` project-token path entirely.

### 7. Rejected approaches
- Pinning ZCode / disabling auto-update: fights the vendor, needs a system-setting change, and only delays the next
  break. Rejected (fewest moving parts, owner skinny rulings).
- Copying tokens out of the desktop app's store into env vars / files: secret handling outside 1Password and fragile.
- Calling `zcode.cjs` directly without the wrapper: the wrapper header forbids it.
- Treating a fresh `credentials.json` as proof of login (current `doctor`): proven false-green.
- Re-running `login` and stopping: already tried 2026-10-19, failed.

### 8. Decisions
- LOCKED: `bin/ai-zcode` stays the single driver; no ZCode reviewer; `--mode yolo` refused; wall-clock ceiling kept.
- LOCKED: secrets never in files/args/chat; if a token must be stored, it goes to 1Password `vibe_coding`.
- LOCKED: Albert is never asked to click/type. A browser login, if truly required, is a `Blocked —` item to report,
  unless the AI can complete it itself via the browser tools on edge-dev.
- OPEN (implementer judgment): which auth route (Step 2 criteria).
- OPEN for owner (Step 1): keep vs retire headless ZCode.

## Part 3 — Build

### 9. Steps

**Step 1 — Owner decision.** Check #1860 for an answer to: "Is unattended ZCode still needed, or can headless GLM
work go through `ai-glm` only and headless ZCode be retired?" If retire: replace Steps 2–5 with: make `ai-zcode ask`
and blocker-watch ZCode wakes fail fast with a clear "retired, use ai-glm" message, remove nothing else, close #1860
with that evidence. If keep (or unanswered after asking — default **keep**, preserve-capability rule): continue.
Gate: decision recorded on #1860.

**Step 2 — Diagnose (edge-dev, read-only experiments, one at a time, each with
`"Reply with the word OK only."`, same env as `provider_env`).** Try in order, stop at first success:
 a. CLI's own `doctor` output — note what it says about auth/project token.
 b. Same `-p` run plus `--surface desktop` while the desktop app is running.
 c. Drive `app-server` over stdio (one request) — only if a/b fail; costlier.
 d. `login bigmodel` path, if the account supports it (check `doctor`/settings; never create accounts).
 e. Fresh `logout` + `login zai` completed by the AI via browser tools on edge-dev, then retry — only if a–d fail.
Record each command, exit code, first stderr lines in the new evidence folder (Step 4). Criteria for choosing: works
from a fresh process with the desktop app closed > works only with app open > needs periodic re-login.
Gate: one route returns `OK` with `projection.status == "idle"`. If none works: post evidence on #1860, report
`Blocked — vendor (Z.AI/ZCode) project-token resolve for fresh CLI processes`, and still do Step 3b + 5 (honest
error), not 3a.

**Step 3 — Fix `bin/ai-zcode`.** a) Add the winning route (e.g. append `--surface desktop` to `argv` in `cmd_ask`
~line 195, or the env/login change) — smallest change. b) In `cmd_ask`'s non-zero-exit branch, detect
`project_token_login_failed|project_token_scope_invalidated` in stderr and die with a specific message:
"ZCode login for headless runs is invalid (often after a ZCode update). Fix: <route from Step 2>." c) Make
`doctor --live` run the one-line ask and report login FAIL on that error, instead of trusting `credentials.json`.
Mirror any wake-argv change in `bin/ai-blocker-watch` (~913) only if the route is an argv flag.
Gate: `ai-zcode ask` OK on edge-dev; `ai-zcode doctor --live` green.

**Step 4 — Re-qualify STEP 0.** Rewrite the header block (~lines 20–40) for desktop 3.17.x / CLI 0.17.x with the
date, and add `tests/verification/zcode-windows-2026-11-<dd>/README.md` (commands, versions, outputs, redacted).
Gate: README exists and the header cites it.

**Step 5 — Tests** (see §10). Gate: suites green locally.

**Step 6 — Land.** Branch, PR (signed with `$AI_GH_SIGNATURE`), `bin/ai-pr-wait <pr>` in background, merge, install
on edge-dev via the normal toolkit sync, re-run the live ask from the installed copy, post proof on #1860, close.

### 10. Tests
- `tests/test-ai-zcode.sh`: add case "stub CLI prints project_token_login_failed and exits 1 → ask exits non-zero
  and stderr contains the new login-invalid message"; add case for the new argv flag if Step 3a adds one (stub
  records argv; assert flag present and `yolo` still absent).
- `doctor --live` stub case: login error → doctor reports FAIL.
- Keep green: `tests/test-ai-zcode.sh`, `tests/test-ai-zcode-headroom.sh`, and the blocker-watch suite if touched.
- Live: Step 3 gate on edge-dev (not CI).

### 11. Constraints / gotchas
- Windows paths must be mixed (`C:/…`) for the Node bundle; `to_mixed` handles it.
- ssh to edge-dev lands in cmd.exe; use Git Bash with a script on stdin.
- `--max-turns/--settings/--allowed-tools` are rejected by the parser — never add them.
- Never print token/credential contents in evidence; file mtimes only.
- Worktree per task; never edit the canonical checkout; commit as Albert's verified identity.
- Times in EST/EDT.

### 12. Access
`gh` authenticated for popcre/ai-devops; `ssh edge-dev` works (BatchMode). Z.AI account login is the one in
`~/.zcode/v2/credentials.json` on edge-dev; any stored credentials belong in 1Password `vibe_coding` (item to be
named "ZCode Z.AI login" if one is created) — never values in the plan.

## Part 4 — Landing
### 13. Done, risks, open questions
Done: route found; `bin/ai-zcode` changed; tests added and green; evidence README; PR merged; installed on edge-dev;
live `ai-zcode ask` OK from installed copy, proof posted; #1860 closed; plan STATUS updated; handoff written.
Risks: next ZCode update re-breaks it — mitigated by the specific error + `doctor --live`. Rollback: revert the PR.
Open owner question: **keep unattended ZCode, or retire it in favour of `ai-glm`?** (default keep).

### Self-audit
1. Fresh session can execute without questions? Yes — §2 hosts/paths, §5 line refs, §9 ordered steps with gates and
   ordered diagnostic tries, §12 access. Gap: exact winning route is unknown by nature; §9 Step 2 gives criteria and
   a blocked path.
2. All background incl. rejected? Yes — verdict, §6, §7 (re-login already failed, pinning rejected).
3. Goal clear enough for judgment? Yes — §1 plus the keep/retire branch in Step 1.
Known deviation: no HANDOFF.d file (planner was write-restricted); Step 0 of implementation is to create it.
