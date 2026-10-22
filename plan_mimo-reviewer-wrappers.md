# IMPLEMENTATION PLAN — Xiaomi MiMo as a formal AI reviewer (Windows + Ubuntu wrappers) (2026-10-13)

Paired handoff: `HANDOFF.d/2026-10-13T1723Z-edge-dev3-claude-mimo-reviewer-plan.md` (retired; recoverable from git history)
Tracking issue: [popcre/ai-devops#1696](https://github.com/popcre/ai-devops/issues/1696)

## STATUS

| Step | State | Date | Evidence |
|---|---|---|---|
| 0. Install `mimo` CLI on one Ubuntu host and one Windows host; qualify `mimo run` flags (closes D10 of the old plan) | ⬜ open | — | — |
| 1. Reverse the "no MiMo reviewer" ruling in code, config and docs | ⬜ open | — | — |
| 2. Credential store (`ai-mimo store-key`, rule 6) | ⬜ open | — | — |
| 3. Ubuntu door: `tools/lib/review-doors/mimo.sh` Linux engine under bubblewrap | ⬜ open | — | — |
| 4. Windows door path: folder + test shell (`bin/ai-mimo-windows-shell`) | ⬜ open | — | — |
| 5. Register the door and extend every hardcoded provider list | ⬜ open | — | — |
| 6. Tests + CI suite manifest entries | ⬜ open | — | — |
| 7. Docs + skill `skills/shared/mimo-review/` | ⬜ open | — | — |
| 8. Land in ai-devops (PR, merge queue, install on both hosts) | ⬜ open | — | — |
| 9. Live proof: one well-formed review on Ubuntu, one on Windows | ⬜ open | — | — |
| 10. Join allocator rotation (`popcre/shared-db` reviewer-roster row) | ⬜ open | — | — |

**Fresh-session starting point:** Step 0. Nothing is built yet. Re-read §§6–8 before writing code, and re-read the next phase heading before starting each phase.

Phases (natural context cut points): **A** = Steps 0–2 (qualification + ruling + key), **B** = Steps 3–6 (doors + registration + tests), **C** = Steps 7–9 (docs, land, live proof), **D** = Step 10 (rotation, other repository).

---

## 1. The ultimate goal

Albert wants Xiaomi MiMo to work as one more independent AI code reviewer, the same way StepFun, DeepSeek, Gemini, Qwen, Muse and Grok already do. Any session on a Windows machine or an Ubuntu server must be able to run `ai-review mimo <mode>` and get back an honest, head-bound review ending in `APPROVE`, `REJECT` or `BLOCKED`. The review must run read-only in a throw-away copy, never touch 1Password while it runs, and fail clearly when MiMo is missing, has no credit, or has no key. More reviewers mean fewer stalls when others are out of credit or unreachable.

**If a step conflicts with this goal, the goal wins: stop and flag it.**

## 2. What this application is

**ai-devops** ([`popcre/ai-devops`](https://github.com/popcre/ai-devops)) is Albert's restore-from-zero toolkit for a multi-model AI coding workflow. It holds Bash and PowerShell commands (`bin/`), shared libraries (`tools/lib/`), tests (`tests/`), config (`config/`), skills (`skills/`) and docs. It is not hosted anywhere; **installation is its deployment** (`docs/deployment.md`). Canonical checkouts: `C:\repos\ai-devops` on Windows machines (edge-dev, 4837), `~/repos/ai-devops` on Ubuntu (edge-dev3, hetz). Default branch `main`, protected, merge queue; work goes through a feature branch and PR (`config/repository-policy.json`, policy `feature-branch-pr`).

**Xiaomi MiMo**: Albert's daily assistant. Desktop app "Xiaomi MiMo AI" (Windows), engine "MiMoCode", standalone headless CLI `mimo`. Config home `~/.config/mimocode/` (`mimocode.jsonc`, `AGENTS.md`, `skills/`); session data `~/.local/share/mimocode/`. Existing governed driver: `bin/ai-mimo` (+ `bin/ai-mimo.cmd`), commands `ask`, `doctor`, `version`.

**The review system** (read `plan_reviewer-pipeline-core.md` §9 Phase D and `docs/reviewer-harness-consolidation.md` for depth):
- `bin/ai-review <provider> <mode>` is the front door. Non-hardcoded providers fall to its `*)` branch (line ~74), gated by `config/reviewer-registry.json` `registry_state`.
- `bin/ai-review-engine` runs every formal review. The shared core `tools/lib/review-lifecycle-core.sh` owns task gate, sandbox (disposable remote-less copy), packet seal, lifecycle, report floor and verdict parsing.
- A **door** `tools/lib/review-doors/<provider>.sh` owns only provider bits: engine binary, credentials, model pin, tool set, parsing into the report shape. `tests/test-ai-review-engine.sh` enforces that "source purity".
- `bin/ai-review-preflight` decides per machine whether a provider is usable.
- Membership in rotation is owned by the allocator in `popcre/shared-db` (`scripts/lib/lanes/reviewer-roster.mjs`). `config/reviewer-registry.json` only mirrors it, and `bin/ai-reviewer-membership-drift` fails on any difference.

## 3. What triggered this work

Albert's request in this chat, 2026-10-13 (verbatim): *"write a plan to create a windows wrapper for mimocode CLI windows and an ubuntu wrapper for mimocode CLI ubuntu to have mimo act as a reviewer"*.

This **reverses** the earlier locked decision D1 in `plan_mimo-windows-support.md` (2026-09-23): "No MiMo-based formal reviewer is built". Albert is the owner, and this request is his ruling. Also related: `HANDOFF.d/2026-10-07T1140Z-edge-dev-mimo-evidence-lost-reviewer-safety.md:70` records that `--implementer mimo` is refused today because MiMo has no registry row. Step 5 fixes that too.

## 4. Scope

**In:** the MiMo door (Ubuntu + Windows engine paths), the key store, registration in every provider list, tests, docs, skill, landing, live proof on both platforms, and a rotation row in shared-db.

**NOT in this plan:**
- MiMo `implement` mode on Windows (refused, StepFun precedent). Linux `implement` is also out of scope for v1: the door's contract lists `["review"]` only.
- Persistent named MiMo debate sessions (no session manager; `ai-mimo` stays stateless).
- Changing the MiMo Desktop GUI, its MCP wiring, skills or globals (done under `plan_mimo-windows-support.md`).
- Any change to other reviewers, the shared core, or the allocator algorithm.
- A completion-check hook for MiMo (MiMoCode has no hook surface).
- BlockerWatch resume for MiMo (old plan D11).

## 5. Current state of the code (2026-10-13, `main` at `bf88e64f`)

- `bin/ai-mimo` (253 lines) exists and works offline: `ask` runs `mimo run --agent plan|build [--cwd DIR] <prompt>` (lines ~100–108). Defaults to the read-only `plan` agent, refuses `--yolo`/`--dangerously-skip-permissions`/`--never-ask` (~line 90), applies the `AI_MIMO_ASK_TIMEOUT` ceiling (default 900 s), and fails closed with `local_dependency_unavailable` when `mimo` is missing. Header lines 15–16 say "No MiMo REVIEWER exists or will be added".
- `tests/test-ai-mimo.sh`: 14 offline fixture tests, green.
- `config/machine-tools.tsv:36` already installs `ai-mimo` (bash+cmd).
- **The `mimo` CLI is not installed** on edge-dev3 (`command -v mimo` empty, 2026-10-13), and it was absent on edge-dev on 2026-09-23. `~/.config/mimocode/AGENTS.md` exists on edge-dev3, but no `mimocode.jsonc` or session data.
- No door, no registry row, no `review-runner-doors.json` entry, no preflight support, no key store.
- Statements that must be reversed (Step 1): `bin/ai-mimo:15–16`; `docs/reviewer-rotation-rules.md:275`; `docs/model-setup.md:115–116,128`; `AGENTS.md:98`; `plan_mimo-windows-support.md:19` (step 9 "out of scope") and `:145` (D1 LOCKED). Leave the historical handoff `HANDOFF.d/2026-09-23T1856Z-edge-dev-mimo-client-integration.md:81` untouched. Also leave `docs/reviewer-failure-full-writeup.md:17`, which is context only.

## 6. Key findings

- **StepFun is the template.** It is the newest reviewer that already has the exact Windows/Ubuntu split this plan needs. First reviewer commit `f1758c21` (#849), 29 files. Windows support came in `578a6c7a` (#1049) and `89a98c81` (#1229). It joined rotation in `d2982e72` (#1320), backed by shared-db PR #3657. Run `git show --stat f1758c21` to get the full touch-list, and mirror it.
- **Door contract** (`tools/lib/review-lifecycle-core.sh`):
  - The door must refuse unless `AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1` (see `stepfun.sh:24`).
  - Inputs are `DOOR_WORKDIR`, `DOOR_PACKET_DIR`, `DOOR_PROMPT_FILE`, `DOOR_REPORT_OUT`, `DOOR_HEAD`, `DOOR_MODE`, `DOOR_MAX_TURNS`, `DOOR_ALLOW_WRITE`, `DOOR_REVIEW_MODE`, `DOOR_OPERATION` and `DOOR_DIAGNOSTICS_DIR` (core ~398–408).
  - The verdict is the last `## Verdict` heading, followed on the next line by `APPROVE|REJECT|BLOCKED` (`rlc_parse_verdict`, ~366). The body must name HEAD (`rlc_verdict_bound_to_head`, ~378).
  - Exit codes: 2 = refusal or unsupported platform (never quarantine), 127 = no credentials, 92 = out of credit (shared classifier).
- **Platform split precedent** (`stepfun.sh:60–66`, `select_engine` ~136): detect the platform with `uname`.
  - Linux runs the engine under bubblewrap (`tools/lib/stepfun-sandbox.sh`).
  - Windows (Git Bash / MSYS) runs in the sandbox folder with a restricted test shell (`bin/ai-stepfun-windows-shell`). That is documented as *not* rule-12 equivalent.
- **Rule 6** (`docs/reviewer-rotation-rules.md:33`): no `op` call during a review. StepFun pattern: `bin/ai-stepfun` `cmd_store_key` (~184) writes `~/.config/ai-devops/secrets/stepfun-api-key` (owner-only). `key_store_ok` (~149) and `stepfun_store_path_safe` (~154) check it, and the door's `require_credentials` (`stepfun.sh:178`) reads only that file.
- **Hardcoded provider lists** that must gain `mimo`:
  - `bin/ai-review-preflight` lines ~51, 402, 458, 525–530, 628, 650 and 1028–1059.
  - `tools/reviewer_admission.py` ~154, 209 and 555.
  - `tools/reviewer_events.py`, `tools/reviewer_maintenance.py`, `tools/reviewer_credit_watch.py` and `tools/reviewer_credit_stream.py`.
  - `bin/ai-review-pool`, `bin/ai-review-lifecycle` and `bin/ai-review-scoreboard`.
  - `config/task-gates.json:366` (`bin/ai-stepfun*` glob pattern).
  - `config/reviewer-ci-paths.txt`.
  - Run `grep -rn stepfun bin tools config` to catch any list this plan missed. That grep is the authority.
- **MiMo-specific unknowns** that Step 0 must settle before any door code:
  1. Exact `mimo run` flags: non-interactive, read-only agent, output format, model selection, max turns.
  2. How MiMo authenticates: API key env var, or a login token in its own store.
  3. Which model id it reports.
  4. How out-of-credit errors look.
  5. Whether `--help` advertises flags the parser rejects (the ZCode lesson).

## 7. Approaches considered and REJECTED

- **Two separate standalone wrappers (`ai-mimo-review.ps1` + `ai-mimo-review` bash) outside the engine.** Rejected because `config/review-runner-doors.json` and the pool/preflight refuse any formal review that bypasses `bin/ai-review-engine`. The "Windows wrapper" and "Ubuntu wrapper" Albert asked for are delivered as **one door with two engine paths**, plus a Windows test shell. Every `bin/ai-*` is bash with an 8-line `.cmd` shim, so it runs on both platforms (checked by `test-bin-cmd-launchers.sh`).
- **Adding a `review` subcommand to `bin/ai-mimo`.** Rejected because the shared core owns sandbox, packet, verdict and lifecycle, and duplicating them is the failure `plan_reviewer-pipeline-core.md` removed. `ai-mimo` gains only `store-key` and `doctor --live` support.
- **Driving the Desktop GUI (`Xiaomi MiMo AI.exe`) headlessly.** Rejected and forbidden by `bin/ai-mimo` header: if the CLI is absent, fail closed.
- **Reading the key from 1Password at review time.** Rejected by rule 6.
- **Running Windows MiMo reviews on the Ubuntu host over SSH (the GLM pattern).** Rejected because Albert explicitly asked for a Windows wrapper using the Windows MiMo CLI.
- **Pinning an exact CLI version.** Rejected by rule 5 (a floor, not a pin).

## 8. Design decisions

| ID | Decision | Status |
|---|---|---|
| M1 | MiMo becomes a formal reviewer; reverses D1 of `plan_mimo-windows-support.md` (owner request 2026-10-13, quoted §3). | **LOCKED** |
| M2 | Single door `tools/lib/review-doors/mimo.sh`, platform-selected engine (StepFun pattern). | **LOCKED** |
| M3 | Contract `["review"]` only; `implement` refused with exit 2 on every platform in v1. | **LOCKED** |
| M4 | Read-only: always `--agent plan` (or the qualified read-only equivalent); never yolo; runs inside the core's disposable remote-less copy. | **LOCKED** |
| M5 | Ubuntu engine runs under bubblewrap; reuse/generalize `tools/lib/stepfun-sandbox.sh` rather than copying it. If generalizing would change StepFun behaviour, copy to `tools/lib/mimo-sandbox.sh` and note the consolidation path in the file header. | LOCKED (approach); helper reuse is **OPEN** — judge by whether StepFun tests stay green unchanged |
| M6 | Windows engine: run `mimo run` in the sandbox folder; tool/test execution restricted via `bin/ai-mimo-windows-shell` modelled on `bin/ai-stepfun-windows-shell`. Documented as not rule-12 equivalent. If MiMo cannot be pointed at a custom shell, the door runs MiMo with no shell tool on Windows and says so in the report header. | LOCKED (approach); shell mechanism **OPEN** pending Step 0 |
| M7 | Credentials via owner-only file `~/.config/ai-devops/secrets/mimo-api-key` (override `AI_MIMO_KEY_STORE`), written only by `ai-mimo store-key` from 1Password vault `vibe_coding`. If Step 0 shows MiMo authenticates by its own login store instead, the door checks that store's presence and never copies tokens. | LOCKED (rule 6); form **OPEN** pending Step 0 |
| M8 | CLI version floor = the version qualified in Step 0, recorded in `config/provider-cli-versions.json`. | LOCKED |
| M9 | Rotation entry happens only after live proof on both platforms; until then registry state is `registered` only if the drift check is satisfied (see Step 10 ordering). | **LOCKED** |
| M10 | Model id: whatever default MiMo model Step 0 records; the door refuses any other model id before credential use (DeepSeek precedent). | OPEN until Step 0 |

## 9. The plan

### Phase A

**Step 0 — Install and qualify the `mimo` CLI (both platforms).**
- Install the standalone MiMoCode CLI on edge-dev3 (Ubuntu) and edge-dev (Windows) through the supported package route. Look in `mimocode-docs` (reference/commands.md) for the official route, and add it to `bin/install-ai-provider-clis.sh` (Linux) plus the Windows installer path the CLI requires. Never replace OS binaries.
- Capture `mimo --version`, `mimo --help` and `mimo run --help` on both hosts. Then run one trivial `mimo run --agent plan "say OK"` and one deliberately bad flag, to prove which flags the parser really accepts.
- Record the answers to the five unknowns in §6 in a new `tests/verification/mimo-reviewer-2026-10/README.md`, including the raw help output and out-of-credit text if it can be observed. Also update `tests/verification/mimo-windows-2026-09-23/README.md` "Headless CLI" to point there.
- Resolve the open items of M6, M7 and M10 in this plan's §8 table, with dates.
- **Gate:** both hosts print a version; `ai-mimo ask "say OK"` returns `OK` on both; the README exists with real captured output. If the CLI cannot be installed on a platform, mark that platform `Blocked —` in STATUS with the exact error, and continue with the other.

**Step 1 — Reverse the ruling.** Edit each location in §5. The new MiMo row in `docs/reviewer-rotation-rules.md` follows the StepFun row at line ~273. Add a superseding note at the top of `plan_mimo-windows-support.md` that links here; keep its history intact. **Gate:** `grep -rn -i "no mimo review\|not a reviewer" bin docs AGENTS.md` returns only historical/handoff hits.

**Step 2 — Credential store.** Add `store-key` to `bin/ai-mimo` (mirror `bin/ai-stepfun` `cmd_store_key`/`key_store_ok`/`stepfun_store_path_safe`), reading from 1Password item in vault `vibe_coding` (title decided in Step 0 — e.g. "MiMo API key"; create it with the `secrets-to-1password` skill if absent), piping the value, never echoing it. Add an install stage in `install.sh` next to the StepFun stage (~792–806) and the Windows installer equivalent. Extend `ai-mimo doctor` to report key-store presence (never value). **Gate:** `ai-mimo doctor` shows `key store: present (0600)` on both hosts; `tests/test-ai-mimo.sh` new store tests pass.

### Phase B (cut point: start a fresh session here if context is heavy; re-read §§6–8)

**Step 3 — Ubuntu door.**
- Create `tools/lib/review-doors/mimo.sh` by copying the structure of `stepfun.sh`: runner-token refusal, `DOOR_*` checks, `uname` platform detection, `select_engine`, `require_credentials` (file-only, exit 127), model-pin refusal and `extract_report`.
- `extract_report` writes the header table (model, harness `mimocode`, reviewed commit), the findings, and the verdict, and forces `BLOCKED` when no verdict is found.
- Linux runs `mimo run` in read-only mode with cwd = `DOOR_WORKDIR`, prompt from `DOOR_PROMPT_FILE`, under bubblewrap (M5), with a wall-clock ceiling.
- Out-of-credit output goes to the shared classifier (exit 92). Add a fixture `tests/fixtures/reviewer-credit/mimo-<code>.txt` from the real text captured in Step 0.
- `implement` exits 2 (M3).
- **Gate:** `bash tests/test-ai-review-engine.sh` (source purity) and the new `tests/test-ai-mimo-door.sh` pass on Ubuntu.

**Step 4 — Windows engine path.** In the same door, the MSYS/MINGW branch runs `mimo` (`.exe`/`.cmd` resolved like `bin/ai-mimo` `resolve_cli`) in the sandbox folder. Add `bin/ai-mimo-windows-shell` + `.cmd`, modelled on `bin/ai-stepfun-windows-shell` (allow-listed read and test commands only), and wire it per the M6 outcome. Platforms with no engine report `unsupported-platform` and exit 2. **Gate:** `tests/test-ai-mimo-windows-shell.sh` passes; on edge-dev, `ai-review-engine` runs a fixture review via the Windows branch with a stub `mimo` (`AI_MIMO_CLI=<stub>`).

**Step 5 — Register MiMo everywhere.**
- Add a `mimo` entry to `config/review-runner-doors.json` with door, `contract ["review"]`, `migrated_in` = branch name, `harness "mimocode"` and notes.
- Add `.providers.mimo` to `config/reviewer-registry.json`. Ordering with the drift check is described in Step 10.
- Extend every list named in §6. Set the `mimo` platform support in preflight and its live qualification through `ai-mimo doctor --live`.
- Add the floor to `config/provider-cli-versions.json` and a `bin/ai-mimo*` glob to `config/task-gates.json`.
- Make sure `ai-review --implementer mimo` is accepted, which also fixes the 2026-10-07 handoff item.
- **Gate:** `grep -rln stepfun bin tools config | xargs grep -L mimo` lists only files that are StepFun-specific by design; `ai-review-preflight status` lists mimo.

**Step 6 — Tests + CI manifest.**
- Add a `config/ci-suites/<test>.json` file for each new test, e.g. `{"kind":"bash","linux_seconds":5}`.
- Map the new sources to their tests in `config/ci-suite-manifest.json`.
- Add the new paths to `config/reviewer-ci-paths.txt`.
- **Gate:** every suite in §10 is green locally on Ubuntu, and `test-bin-cmd-launchers.sh` passes.

### Phase C

**Step 7 — Docs and skill.**
- Update `docs/model-setup.md`, `docs/reviewer-rotation-rules.md`, `AGENTS.md` router row, `docs/config-inventory.md` (key-store row) and `docs/implementation-plan-index.md` (add this plan).
- Add `skills/shared/mimo-review/SKILL.md`, modelled on `skills/shared/stepfun/SKILL.md`, with triggers such as "ask MiMo to review", "MiMo review" and "run this by MiMo".
- **Gate:** `tests/test-markdown-links.sh` and the skill-collision checks pass.

**Step 8 — Land.** Branch from current `origin/main` in a worktree. Before the first commit, run `git var GIT_COMMITTER_IDENT`; it must show Albert's identity. Open the PR and get an AI review from an in-rotation reviewer of a different engine (`ai-review`). Run `ai-task-gates check` before the PR wait, then wait with `bin/ai-pr-wait <pr> --timeout-minutes 60` and merge through the queue. Then update the installed toolkit on edge-dev3 and edge-dev (`update.sh` / Windows installer from the canonical checkout). **Gate:** the merged SHA is in the installed checkouts on both hosts, and `ai-mimo doctor --live` passes on both.

**Step 9 — Live proof.** On each host, run `ai-review mimo <mode> --implementer claude` against a small real PR head in ai-devops. **Gate:** each produces a report with model/harness header, findings, and a head-bound `## Verdict` line, and the lifecycle records it as well-formed. Save the report paths under `tests/verification/mimo-reviewer-2026-10/`. If proof is not done in the landing session, leave `- [ ] live proof (Ubuntu)` / `- [ ] live proof (Windows)` on the same tracking issue; never open a new issue.

### Phase D

**Step 10 — Rotation.**
- Open a PR in `popcre/shared-db` that adds a MiMo row to `scripts/lib/lanes/reviewer-roster.mjs`, following the StepFun row from shared-db PR #3657. Load the `shared-db-change` skill first, and treat this as tooling, not a database structure change.
- Then make `config/reviewer-registry.json` match, so `bin/ai-reviewer-membership-drift` is green.
- If the registry row from Step 5 would make drift fail before the shared-db row merges, list MiMo temporarily in `config/reviewer-membership-scope.json` `.outside_allocator` with the reason "pending shared-db roster row", and remove that entry in this step.
- **Gate:** the drift workflow is green and the allocator can draw `mimo`.

## 10. Tests required

New:
- `tests/test-ai-mimo-door.sh`, using a stub `mimo` with `AI_MIMO_CLI`:
  - refuses when the runner token is missing (exit 2);
  - refuses `implement` (exit 2);
  - missing key exits 127 without calling `op`; assert this with an `op` stub that fails the test if it is invoked;
  - wrong model id is refused before credential use;
  - stub output with a verdict gives a parsed `APPROVE`/`REJECT`;
  - stub output with no verdict gives `BLOCKED`;
  - a verdict without HEAD is rejected by the core;
  - out-of-credit text maps to exit 92;
  - on Linux, the command line includes the bubblewrap wrapper and the read-only agent;
  - `--yolo` never appears in argv.
- `tests/test-ai-mimo-windows-shell.sh`: allow-listed commands run; network, `git push` and file writes outside the sandbox are refused.
- Extend `tests/test-ai-mimo.sh` with `store-key` cases: refuses an unsafe path, sets mode 0600, never prints the value, and is idempotent.
- Fixture `tests/fixtures/reviewer-credit/mimo-*.txt`, plus a case in `tests/test-reviewer-credit.sh`.

Existing suites that must stay green:
- `test-ai-review-engine.sh`, `test-review-door-diagnostics.sh`, `test-pool-dispatch-doors.sh`
- `test-ai-review-preflight.sh`, `test-reviewer-credit.sh`, `test-ai-reviewer-membership-drift.sh`
- `test-install-ai-provider-clis.sh`, `test-reviewer-ci-paths.sh`, `test-bin-cmd-launchers.sh`
- `test-ai-stepfun.sh`, `test-ai-stepfun-windows-shell.sh` (they prove M5 reuse did not break StepFun)
- `test-ai-mimo.sh`, `test-markdown-links.sh`

## 11. Constraints, standing rules, gotchas

- Reviewer rules 1–12 in `docs/reviewer-rotation-rules.md` all apply. Rule 3 says a policy change lands in code, config and docs together. Rule 4: no per-reviewer concurrency limit. Rule 5: a version floor, not a pin. Rule 6: no `op` during a review. Rule 7: state stays on the home drive.
- Doors own provider bits only. The source-purity test fails if the door touches sandbox, packet, lifecycle or cleanup.
- An unsupported platform exits 2 and is **never quarantined**.
- Never launch the MiMo Desktop GUI as a fallback.
- `--help` may advertise flags the parser rejects (ZCode lesson): pin only flags proven in Step 0.
- Windows traps:
  - CRLF breaks bash scripts (`.gitattributes` handles `bin/*`; verify).
  - PowerShell 5.1 strips quotes from native arguments, so test under both powershell and pwsh.
  - Windows reviewers run from the main installed checkout, not a worktree (memory `windows-reviewers-run-from-main-checkout`).
  - `PYTHONDONTWRITEBYTECODE=1` on edge-dev3 breaks `__pycache__` fixtures locally.
- Secrets live only in vault `vibe_coding`. Move them through pipes, never through arguments, logs or chat.
- Start with `ai-task-gates start --class <class>`, and run `ai-task-gates check --before <action>` before the PR wait.
- Sign GitHub posts with `Posted by Claude chat <id> on <machine>`.
- Quote all human-facing times in EST/EDT.
- Never push to `main`; always merge through the queue.
- Use a worktree for all edits. Canonical checkouts are landing-only.
- Do not use Envy or EDGE-ALIEN; they are not dev or review machines.

## 12. Access and environment

- Ubuntu host: **edge-dev3** (this planning machine). Windows host: **edge-dev**, reachable from edge-dev3 via Tailscale SSH (see memories `edge-dev-*`); 4837 is the second Windows option.
- `gh` is authenticated as `u2giants` with access to `popcre/ai-devops` and `popcre/shared-db`.
- MiMo API key / login: to be stored in 1Password vault `vibe_coding`, item title fixed in Step 0. Never record its value anywhere.
- Run tests: `bash tests/<name>.sh` from the worktree root (Git Bash on Windows).

## 13. Definition of done, risks, open questions

**Done when:**
- [ ] every STATUS row is ✅ with an artifact citation;
- [ ] all §10 suites are green in CI;
- [ ] the PR is merged through the queue, and the merged SHA is installed on edge-dev3 and edge-dev;
- [ ] live well-formed reviews exist on both platforms;
- [ ] the shared-db roster row is merged and drift is green;
- [ ] docs and skill are updated;
- [ ] this plan's STATUS is current, and the paired handoff is closed.

**Risks and rollback:**
- A broken MiMo door could make pool reviews fail. Preflight marks MiMo unusable and the pool moves to the next reviewer (rule 2).
- Rollback is reverting the PR, or setting MiMo's `registry_state` to retired.
- Generalizing the StepFun sandbox could regress StepFun; the M5 fallback is to copy instead.

**Open questions (criteria):**
1. Does a headless `mimo` CLI exist for Linux at all? If not, the Ubuntu path is `Blocked —` (report to Albert; never fake it with the Windows host).
2. Auth form (M7).
3. Whether Windows MiMo accepts a restricted shell (M6).
4. Model id and credit-error text (M10).

All four are settled by Step 0's real output, not by guesswork.

---

## Self-audit (2026-10-13)

1. *Could a brand-new session execute this without asking?* Yes. §2 defines the toolkit, the review engine, and how doors work. §5 gives the exact current state, §6 the file:line integration points with StepFun as the template, §9 per-step files and gates, and §12 the hosts. The genuine unknowns are MiMo CLI facts that only installing it can reveal; Step 0 settles them and §8 says which decisions it updates.
2. *Does it carry the reasoning, including what was ruled out?* Yes. §3 records the reversal of D1 with Albert's verbatim words, §7 lists six rejected approaches with reasons, and §8 labels locked and open decisions.
3. *Is the goal clear enough for judgment calls?* Yes. §1 states the business outcome (one more honest, read-only, head-bound reviewer on both platforms) and the goal-wins rule; §13 gives the criteria for each open question.
