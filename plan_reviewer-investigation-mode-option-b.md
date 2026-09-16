# IMPLEMENTATION PLAN — reviewer investigation mode, Option B (corrected 2026-09-16)

Plan owner: issue [#253](https://github.com/popcre/ai-devops/issues/253)

Plan handoff: [`HANDOFF.d/2026-09-16T2013Z-edge-dev-grok-253-grok-child.md`](HANDOFF.d/2026-09-16T2013Z-edge-dev-grok-253-grok-child.md)

Predecessor planning handoff (retired by this update): `HANDOFF.d/2026-09-16T1948Z-edge-dev-grok-reviewer-investigation-plan-fix.md`

Repository: `popcre/ai-devops`

Target branch: `main` through a feature branch and pull request (`config/repository-policy.json`: `feature-branch-pr`). Never push to `main`.

Correction baseline: `origin/main` `2719315e13fc6e3cb99511dced33915ea46f4d47` (2026-09-16). Step 0 must re-resolve; this SHA is not authority for implementation.

## STATUS — read this first

| Step | Owner issue | Status | Evidence |
|---|---:|---|---|
| 0. Re-resolve source truth, ownership, and current pins | #253 | ⬜ open | Record output under `tests/verification/reviewer-investigation-option-b/<UTC>-baseline/` |
| 1. GLM investigate on the current OpenCode pin | #254 | ⬜ open | Required artifacts are listed in Step 1 |
| 2. Kimi investigate on the current CLI | #255 | ⬜ open | Required artifacts are listed in Step 2 |
| 3. Qwen investigate on the current CLI; repair discovery only if still broken | #256 | ⬜ open | Required artifacts are listed in Step 3 |
| 4. Muse investigate on the current OpenCode pin | #257 | ⬜ open | Required artifacts are listed in Step 4 |
| 5. Grok investigate on the current pin | #513 | 🟡 landing | `ai-grok-implement investigate` on pin 1.0.13; formal review unchanged; #249 untouched |
| 6. Cross-provider integration, exact-head review, and merge | #253 | ⬜ open | Required artifacts are listed in Step 6 |

**2026-09-16 correction (locked):** the 2026-09-04 plan mixed a thin `investigate` command with OpenCode/Kimi/Qwen upgrades and made Muse wait on GLM's upgrade. That mix is withdrawn. Deliver investigation on the currently qualified pin. Upgrades are out of this plan. Provider children are independent after Step 0.

**2026-09-16 Muse Spark:** session `253-plan-opinion` returned `VERDICT: AGREE` with no material objections. Its two notes were already in this file: Qwen discovery repair stays conditional on a Step 0 mismatch; Step 6 (then Step 5) checks labels and banners only and must not factor shared code (#169). No further plan edit was required for Muse.

**2026-09-16 owner:** add Grok as a #253 child (#513). Same Option B rules. Do not implement the #249 broker here.

Fresh session starts at **Step 0**. Re-read the remaining downstream steps before each provider child. Do not start a child until Step 0 has a baseline artifact.

## 1. Ultimate goal

GLM 5.3, Kimi, Qwen, Muse, and Grok must be able to look into software thoroughly: run builds and tests, inspect live behavior, and reach the public internet when the work requires it. Advice from that look-into-this mode never counts as a pass. The strict read-only judge stays as it is. Do this with the fewest new parts. Do not hand a reviewer the operator's credentials. Do not let it change the checkout other sessions are using.

Option B: reuse each provider's existing wrapper. For GLM, Kimi, Qwen, and Grok, add a thin explicit `investigate` command on top of the capable path they already have. For Muse, add the missing capable path. Do not build a shared lifecycle framework. Do not upgrade a CLI or harness in this plan. Do not build Grok's separate brokered integration-review (#249) in this plan.

If a step conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`popcre/ai-devops` is Albert Hazan's public backup-and-restore toolkit for a multi-model coding workflow. It holds launchers, provider wrappers, prompt/profile configuration, installers, documentation, and offline tests. It is not a hosted application. Installation places commands and secret-free configuration on Windows and Ubuntu. GitHub `origin/main` is the code truth.

Affected reviewers:

- **GLM 5.3**, hosted by the repository-pinned OpenCode runtime through `bin/ai-glm`. Current pin: `config/opencode/version` = `1.18.12`. Model: `glm-5.3`.
- **Kimi Code**, driven headlessly through `bin/ai-kimi`. Not version-pinned in `config/provider-cli-versions.json`.
- **Qwen Code**, driven headlessly through `bin/ai-qwen`. Not version-pinned in `config/provider-cli-versions.json`.
- **Muse Spark 1.3 Contributor**, driven through repository-pinned OpenCode direct mode by `bin/ai-muse`. Same OpenCode pin `1.18.12`. Model: `meta-model-api/muse-spark-1.3-contributor`.
- **Grok Build 4.6**, driven through `bin/ai-grok-review` (read-only) and `bin/ai-grok-implement` (isolated write runs). Pin: `config/provider-cli-versions.json` `1.0.13`. Child issue #513.

“Formal review” means the existing read-only judge whose output may satisfy an independent review gate. “Investigation” means a capable advisory turn with shell and public internet. Investigation output never becomes formal approval merely because it reached a verdict.

This repository's workflow is feature-branch plus pull request to `main`, then the merge queue. Implementation of this plan is a reviewer-safety change: wrappers, evidence tools, safety tests, or installed routing rules need one read-only exact-head final review before merge.

Machine facts must be read from `templates/system/machine-atlas.md` only when an installation or live qualification step begins.

## 3. What triggered this work

On 2026-09-03 Albert decided that reviewers need shell and internet access so they can perform more thorough testing, with the least possible complexity. A GLM 5.3 consultation recommended keeping a formal read-only judge and adding a capable investigation tier in disposable copies. Extracting a new shared lifecycle core was rejected as too much initial machinery.

On 2026-09-16 Albert asked whether the 2026-09-04 Option B plan and GitHub children #254–#257 were an improvement, then whether any child was perfect as written, then to fix all of the plans. The independent reading was:

- Formal review still cannot run tests or use the public web, so reviewers guess. That gap is real.
- GLM, Kimi, and Qwen already have a capable **build** path (`implement`) in a throwaway copy. Muse does not.
- GLM's build profile forbids the network (`config/opencode/agent/glm-implement.md` has `webfetch: false` and tells the model not to reach the network). Kimi's build profile already allows network through Bash (`config/kimi/local-implement.md`). Qwen's build path already launches full tools under sandbox.
- Bundling CLI/harness upgrades with the new mode made every child bigger and riskier than the requested outcome.
- Making Muse wait for GLM's OpenCode upgrade coupled two jobs that do not need each other if today's pin already hosts Muse.
- Qwen child #256 stacked three jobs: discovery repair, CLI upgrade, and the new mode.
- The 2026-09-04 plan said to land directly on `main`. Current policy is feature-branch-PR.

On 2026-09-16 Muse Spark session `253-plan-opinion` re-read this plan and the wrapper files and returned `VERDICT: AGREE` with no material objections. The two notes it left were already in this file: keep Qwen discovery repair strictly conditional on a Step 0 mismatch, and keep the final cross-provider step to labels and banners so #169 is not pulled in. Albert then asked whether Grok already had this named look-into-this mode (it does not) and to create a #253 child for Grok. That child is #513.

Planning-time version observations from 2026-09-04 (OpenCode `1.18.12` vs then-current `1.18.27`, Kimi `0.36.1` vs `0.40.1`, Qwen `0.21.15` vs `0.23.0`, Muse Spark 1.2) are historical. They are not pins and not work in this plan. Step 0 re-checks what is installed and what the repository currently qualifies.

## 4. Scope — in and out

### In scope

- One explicit `investigate` command on each of GLM, Kimi, Qwen, Muse, and Grok.
- Shell, build/test, and outbound public-internet capability inside a disposable remote-less repository copy.
- Reuse of existing named sessions, clone/worktree lifecycle, remote removal, provider credential handoff, completion parsing, bounded execution, incomplete artifact recovery, and report publication.
- A dedicated GLM investigation profile, because `glm-implement` forbids the network and must keep doing so for real build jobs.
- A dedicated Muse investigation agent, because Muse has no capable path today.
- For Kimi and Qwen: a thin command over the existing implement lifecycle; a dedicated investigation profile only if that is smaller than conditional mutation of the implement profile.
- For Grok: a thin `investigate` command that reuses `ai-grok-implement`'s isolated worktree and `--allow-shell` path. Do not merge the review and implement wrappers. Do not change `ai-grok-review`.
- Qwen binary discovery repair **only if Step 0 still shows** that PowerShell and `ai-qwen doctor` disagree. That repair is a prerequisite of honest qualification, not an upgrade.
- Windows and Ubuntu doctor, documentation, skill, and live qualification updates for the new command.
- Exact-head independent final review because this is a reviewer safety-path change.

### Not in this plan

- Any OpenCode, Kimi Code, Qwen Code, or Grok Build upgrade, pin change, or “move to current stable.”
- Any Muse model upgrade. Current pin is Spark 1.3 Contributor; leave it unless Step 0 proves the authenticated inventory no longer serves that exact model, in which case stop and flag — do not quietly pick a newer one as part of investigation.
- A new shared lifecycle library or broad wrapper consolidation (issue #169).
- Unrestricted execution in the live shared checkout.
- Passing 1Password service tokens, GitHub write credentials, cloud credentials, SSH keys, `.env` contents, or the caller's general environment to reviewer shell children.
- An egress allowlist/broker, container platform, VM platform, daemon fleet, or new network service.
- Automatic application of complete or incomplete reviewer patches.
- Treating investigation output as formal read-only approval.
- Gemini, DeepSeek, Claude, or Codex reviewer changes.
- Grok issue #249 / `plan_grok_integration-review-access.md`: the brokered, deny-by-default integration-review tier. #513 is Option B on the current pin. It does not close, replace, or implement #249.
- Reviewer-assisted stuck-session routing (issue #198 / `plan_reviewer-assisted-problem-solving.md`). That plan must not grow shell/internet into formal review; this plan must not grow a stuck-session skill.
- Production infrastructure or shared-database writes.
- Direct pushes to `main`.

## 5. Current state of the code

No `investigate` command exists on GLM, Kimi, Qwen, Muse, or Grok as of `origin/main` `82216ba3` (2026-09-16). `rg investigate bin/ai-{glm,kimi,qwen,muse,grok-review,grok-implement}` has no command dispatch.

Existing reusable machinery on that SHA:

- `bin/ai-review-sandbox` header and `ensure-copy` / `remove-recorded` (lines 27–34, 398–431) already create, refresh, validate, and remove recorded disposable copies.
- `bin/ai-glm`: `cmd_implement` at 1617, clone path helper at 442, dispatch `implement` at 2543. `config/opencode/agent/glm-implement.md` grants Bash and forbids webfetch/network. `config/opencode/agent/glm-review.md` has `bash: false` and `webfetch: false`.
- `bin/ai-kimi`: `cmd_implement` at 2244, dispatch at 2317. `config/kimi/local-implement.md` grants Bash and states Bash can still use the network; web and subagent tools are absent. `config/kimi/readonly-review.md` has no Bash and no network.
- `bin/ai-qwen`: `cmd_implement` at 1932, dispatch at 1988. Implementation runs `--safe-mode --sandbox --approval-mode yolo` inside a wrapper-owned disposable worktree (header lines 33–40). `resolve_qwen` at 254–282 does **not** search `PATH`; it checks `AI_QWEN_BIN` then a short list of official standalone locations. `cmd_doctor` at 1102 uses `resolve_qwen`. Whether the 2026-09-04 “PowerShell finds it, doctor does not” fault still reproduces is unknown until Step 0.
- `bin/ai-muse`: commands are `new`, `ask`, `list`, `show`, `transcript`, `reconcile`, `delete`, `doctor`, and legacy `review` (dispatch 558–566). There is no `implement` and no `investigate`. `config/opencode-muse/agent/muse-review.md` has `bash: false` and `webfetch: false`. Named sessions, private snapshots, private credential handoff, terminal `step_finish` proof, and durable reports already exist.
- `bin/ai-grok-review` is read-only: `--deny Edit --deny Bash` and `--disable-web-search` (header ~104–106, 1453). There is no `investigate` command.
- `bin/ai-grok-implement`: `cmd_run` at 258, `--allow-shell` at 270, Bash allow/deny at 343, dispatch `run` at 490. Isolated real git worktree. Shell is optional and off by default. No `investigate` command.
- `config/opencode/version` pins `1.18.12` for both GLM and Muse.
- `config/provider-cli-versions.json` pins Grok `1.0.13` and leaves Kimi and Qwen unpinned.

The 2026-09-04 plan, parent #253, and children #254–#257 landed as planning-only. The 2026-09-16 correction rewrote those issue bodies (no upgrades, independent children). Muse agreed with that correction. Grok child #513 was added the same day. Implementation never started.

A concurrent worktree `C:/repos/ai-devops/.claude/worktrees/parent-issue-253-status-9293e4` on branch `claude/parent-issue-253-status-9293e4` exists at an older SHA. Do not edit it. Do not reuse that branch name.

Canonical checkout `C:\repos\ai-devops` is landing-only. Implement in a dedicated current-upstream worktree.

## 6. Key findings and root cause

1. The capability gap for GLM, Kimi, and Qwen is mostly naming and policy, not missing shell machinery. They already run builds and tests in a throwaway copy via `implement`. Duplicating that lifecycle would add complexity without capability.
2. GLM investigation cannot be a silent alias of `implement` as it exists today, because `glm-implement.md` forbids the network. Reuse the clone/lock/export/cleanup lifecycle; bind a **separate** investigation agent that allows Bash and public internet. Leave `glm-implement.md` unchanged for real build jobs.
3. Kimi investigation can reuse the implement worktree path. Bash already reaches the network. Do not add a Web tool or subagent unless a canary proves Bash cannot perform a harmless public HTTP GET.
4. Qwen investigation can reuse the sandboxed implement worktree path. Do not adopt `qwen serve`, Channels, or native multi-agent workflows.
5. Muse is the only provider among the original four that needs a new capable execution path. Its wrapper already has session, report, key-handoff, sandbox, and completion foundations, but only a no-shell agent.
5a. Grok is like GLM/Kimi/Qwen, not like Muse: `ai-grok-implement` already has an isolated worktree and optional Bash. `ai-grok-review` must stay deny-Bash / no web search. Investigation is a named advisory command over the implement path, not a widening of the approval reviewer.
6. A disposable remote-less copy is not an elaborate network sandbox. It is the existing helper that stops a shell-capable reviewer from modifying the checkout shared by concurrent sessions and keeps evidence tied to a stable source state.
7. Internet access turns every readable credential into an exfiltration risk. Launch with an allowlisted environment, inject only the provider credential required for the model call through the existing private mechanism, and remove/scrub it before reviewer shell children run.
8. Native provider completion differs. Kimi relies on recorded `session.resume_hint`; Qwen requires a terminal successful `result`; OpenCode/Muse uses structured stop/`step_finish`; GLM validates server/session/model state. Exit zero alone is never completion.
9. CLI upgrades can silently change flags, profiles, permissions, completion events, or credential inheritance. They are a different job with a different blast radius. Mixing them into investigation delayed the requested outcome and made every child imperfect.
10. Muse does not need a newer OpenCode to gain a Bash-enabled agent. It already runs on pin `1.18.12`. Waiting on GLM's upgrade was unnecessary coupling.
11. Direct-to-`main` landing is no longer this repository's policy.

## 7. Approaches considered and rejected

### Rejected: unrestricted live-checkout and live-machine access

Fewest controls on paper. It gives an internet-enabled model access to concurrent work and inherited credentials, and lets the reviewer change the evidence it is judging. A disposable copy already supports shell, builds, tests, and internet.

### Rejected: keep every reviewer entirely read-only

Conflicts with the requested outcome. Read-only reviewers cannot run tests or reproduce runtime failures.

### Rejected: replace all wrappers with one shared lifecycle core

GLM's clean long-term recommendation. Too much initial machinery. Issue #169 remains the consolidation track.

### Rejected: an egress broker or domain allowlist

Stronger control, but adds a service, policy language, and ongoing allowlist ownership. Reconsider only if investigation targets must contain licensed/private data or secrets that cannot be excluded from the disposable copy.

### Rejected: turn the formal review command into full-access mode

Removes the independent judge boundary. An explicit `investigate` command keeps the consequence visible.

### Rejected 2026-09-16: bundle CLI/harness upgrades with investigation

The 2026-09-04 children each mixed “add investigate” with “move to current stable.” Upgrades can change the very contracts investigation must preserve. Deliver investigate on the last qualified pin. If a later session wants an upgrade, that is a separate qualified pin change.

### Rejected 2026-09-16: Muse waits for GLM's OpenCode upgrade

Both consume pin `1.18.12` today. Muse can add a Bash-enabled agent on that pin. GLM's upgrade is not a prerequisite of Muse investigation.

### Rejected 2026-09-16: land directly on `main`

Superseded by `config/repository-policy.json` `feature-branch-pr` for `popcre/ai-devops`.

### Rejected 2026-09-16: implement Grok #249 inside this parent

#249 is a stronger brokered integration-review with a Linux execution boundary and deny-by-default network broker. That is extra machinery relative to Option B. Albert asked for a #253 child for Grok. #513 reuses `ai-grok-implement` on pin `1.0.13`. #249 stays open as its own workstream.

### Rejected 2026-09-16: use `implement` as the user-facing investigation command

Albert asked for reviewers that can look into software. `implement` means write a change. A separate `investigate` command is a small interface addition that keeps advice from being mistaken for a build job or a formal pass.

## 8. Design decisions already made

### Locked — do not relitigate

- **2026-09-03, owner:** reviewers must gain shell and internet capability for deeper testing.
- **2026-09-03, owner:** least-moving-parts Option B; no shared lifecycle-core rewrite.
- **2026-09-16, owner:** fix the plans after independent reading found bundled upgrades, Muse-after-GLM coupling, and stacked Qwen scope.
- **2026-09-16, Muse Spark:** `VERDICT: AGREE`; no material objections. Two notes already present in this file (conditional Qwen discovery repair; final step is labels/banners only).
- **2026-09-16, owner:** add Grok as a #253 child. Same Option B. Do not implement #249 here.
- Investigation uses existing capable machinery and a disposable remote-less repository copy.
- Investigation and formal review remain separate modes and evidence classes. Investigation reports must say `INVESTIGATION — ADVISORY, NOT FORMAL APPROVAL`.
- Reviewer shell children receive no operator credentials. Only the minimum provider credential may enter the model launcher, through existing private/self-deleting handoff, and must be absent from child environments and arguments.
- Execution stays bounded; exact session/model identity, source identity, terminal completion, durable evidence, and incomplete-work recovery remain.
- No auto-application of reviewer changes.
- No CLI/harness/model upgrade in this plan. Keep the currently qualified pin.
- Work on a feature branch and pull request. Never push to `main`.
- GLM, Kimi, Qwen, Muse, and Grok children are independent after Step 0.

### Open implementation judgment

- Whether the thin public command dispatches into the existing `implement` function with a mode flag, or a tiny provider-local helper. Choose the smaller tested change. Do not create cross-provider infrastructure.
- Whether investigation returns a patch when the reviewer changed files. Prefer the existing patch and incomplete-patch format.
- Whether Kimi/Qwen need a dedicated `investigate.md` profile or can reuse the implement profile with a different report banner. Choose the smaller change that still labels the turn advisory and does not weaken formal review.
- Whether Qwen discovery is still broken. Step 0 decides. If doctor and PowerShell resolve the same binary, do not “repair” anything.
- Whether Bash alone is enough public internet for a canary (harmless HTTP GET) or a provider-native web tool is required. Prefer Bash. Add a native web tool only if the canary cannot be done through Bash without new machinery.
- Whether Grok's public command is `ai-grok-implement investigate` or a thin extra dispatcher. Choose the smaller tested change. Do not merge `ai-grok-review` and `ai-grok-implement`. Do not enable Bash or web search on `ai-grok-review`.

## 9. Ordered implementation plan

### Step 0 — re-resolve source truth, ownership, and current pins (#253)

1. Read `AGENTS.md`, then `docs/architecture.md`, `docs/development.md`, `docs/design-decisions.md`, `docs/critical-incidents.md`, and the verification headers of `bin/ai-glm`, `bin/ai-kimi`, `bin/ai-qwen`, `bin/ai-muse`, `bin/ai-grok-review`, `bin/ai-grok-implement`, and `bin/ai-review-sandbox`.
2. From a dedicated worktree of current `origin/main`, run `git status --short`, `git fetch origin main`, `git rev-parse HEAD origin/main`, `git merge-base --is-ancestor` in both directions, and `git worktree list --porcelain`. Do not pull, reset, clean, or overwrite dirty files in the canonical checkout. Do not reuse branch `claude/parent-issue-253-status-9293e4`.
3. Record exact current native versions, binary paths, `--help`, doctors, configured models, and sanitized environment behavior on Windows and Ubuntu under `tests/verification/reviewer-investigation-option-b/<UTC>-baseline/`. Do not store credentials or raw transcripts.
4. On Windows, compare `ai-qwen doctor` binary identity with PowerShell `Get-Command qwen`. Record whether they match. That single fact decides whether #256 includes a discovery repair.
5. Confirm repository pins: OpenCode `config/opencode/version`, Muse model in `bin/ai-muse` and `config/opencode-muse/`, GLM model, Grok `config/provider-cli-versions.json`, Kimi/Qwen unpinned presence. Do not look up “latest stable” in order to upgrade. Latest is out of scope.
6. Before any local full suite, check `bin/ai-test-local --check-collision`. Only a busy job on this same physical host or a shared installed runtime blocks a local suite here.

**Verification gate:** the baseline artifact identifies current HEAD/origin ancestry, every overlapping dirty path and owner, installed versions, doctors, the Qwen discovery match/mismatch, and that no child will upgrade a pin. No implementation begins with ambiguous ownership.

**Natural context cut:** after Step 0, update this STATUS table and re-read Steps 1–6. Steps 1–5 may then proceed independently, each on its own feature branch from then-current `origin/main`.

### Step 1 — GLM investigate on the current OpenCode pin (#254)

Do **not** change `config/opencode/version`. Do **not** edit `config/opencode/agent/glm-implement.md` except if a shared helper must be called from both agents without changing implement's no-network rule.

Targets: `bin/ai-glm` (dispatch near 2539–2554 and implement lifecycle from 1617), new `config/opencode/agent/glm-investigate.md`, `tests/test-ai-glm.sh`, `docs/glm-opencode.md`, `docs/model-setup.md`, `docs/development.md`, `skills/shared/ask-glm/SKILL.md`. Touch Muse installers only if a shared OpenCode agent-directory copy would otherwise omit the new file; copying an extra agent file is not an OpenCode upgrade.

1. Add `ai-glm investigate <name> --prompt-file <file>` as a thin dispatch into the existing implementation job lifecycle (clone, lock, abort, terminal state, patch/report export, cleanup).
2. Bind a new agent with Bash enabled and public internet allowed (Bash and/or `webfetch: true`). User-facing report must say `INVESTIGATION — ADVISORY, NOT FORMAL APPROVAL`.
3. Keep the clone remote removed. Launch with an allowlisted environment. Provider key reaches only the OpenCode transport and is absent from Bash child environment, process arguments, reports, patches, and logs.
4. Preserve named-session locking, exact model verification, bounded wall time, abort, terminal state, complete/incomplete patch export, exact cleanup, and formal review's no-shell profile.
5. Update focused tests, doctor output, documentation, and the installed shared skill. Preserve all old formal review assertions; add explicit capable-mode assertions. Do not add upgrade/pin assertions.

**Verification gate:** issue #254 holds redacted artifacts proving GLM 5.3 identity on OpenCode `1.18.12` (or whatever pin Step 0 recorded as current), working shell and public internet in investigation, no credential in tool children/output, remote-less disposable copy, bounded completion/recovery, unchanged formal read-only behavior, and unchanged `glm-implement` no-network rule. Land through a feature-branch PR, not a direct push.

### Step 2 — Kimi investigate on the current CLI (#255)

Do **not** upgrade Kimi Code.

Targets: `bin/ai-kimi` (dispatch near 2317, `cmd_implement` at 2244), `config/kimi/local-implement.md` or a new `config/kimi/investigate.md`, `tests/test-ai-kimi.sh`, `docs/model-setup.md`, `docs/development.md`, `skills/shared/kimi-code-delegation/SKILL.md`.

1. Add `ai-kimi investigate <name> --prompt-file <file>` as a thin use of the current implementation-session/worktree path.
2. Grant Bash and public internet (Bash is enough if the HTTP canary works). Keep named-session continuation, immutable base plus cumulative patch, remote-less disposable tree, bounded execution, terminal proof, incomplete recovery, and artifact cleanup.
3. Keep provider/OAuth data in the protected Kimi home. Launch tool children without OAuth, 1Password, GitHub, SSH, cloud, or general operator credentials. Prompts remain secret-free because Kimi may expose them through local process arguments.
4. Preserve formal review's no-Bash/no-network/no-write profile and before/after mutation detection.
5. Explicitly disable default secondary-model/subagent behavior for investigation unless attribution, bounds, and completion can be proven without additional orchestration.
6. Update doctors, focused tests, docs, and shared skill with current-version facts only. Do not change installer pin files to a newer Kimi.

**Verification gate:** issue #255 holds redacted evidence for the installed Kimi version recorded in Step 0, successful shell/internet investigation, credential-free children, one accountable named reviewer, correct completion proof, safe recovery, and unchanged formal read-only review. Land through a feature-branch PR.

### Step 3 — Qwen investigate on the current CLI (#256)

Do **not** upgrade Qwen Code.

Targets: `bin/ai-qwen` (`resolve_qwen` 254–282, `cmd_implement` 1932, dispatch 1988, `cmd_doctor` 1102), `tests/test-ai-qwen.sh`, installation tests only if discovery repair is required, `docs/model-setup.md`, `docs/development.md`, `skills/shared/qwen-code/SKILL.md`.

1. If Step 0 recorded a discovery mismatch, repair binary discovery so Windows PowerShell and Git Bash resolve the same repository-qualified binary and `ai-qwen doctor` identifies it. If they already match, skip this bullet.
2. Add `ai-qwen investigate <name> --prompt-file <file>` as a thin alias/dispatch over the existing implementation worktree path with Qwen sandbox enabled. Do not adopt `qwen serve`, loopback unauthenticated operator APIs, Channels, or native multi-agent workflows.
3. Keep the private self-deleting provider-key handoff, child-process scrubber, remote-less disposable worktree, bounded turns/tools/time, exact model/session proof, terminal `result` requirement, and incomplete patch recovery.
4. Preserve formal review safe mode, excluded shell/write tools, full dirty-tree content hash, and no-network/no-write assertions.
5. Update doctor, focused tests, docs, and shared skill. Do not change the Qwen version pin (there isn't one) or force an upgrade.

**Verification gate:** issue #256 holds redacted evidence that both shells resolve one binary (after repair if needed), investigation shell/internet works inside the disposable sandbox, credentials do not reach tool children, missing terminal result fails, interrupted work is recoverable, and formal review remains read-only. Land through a feature-branch PR.

### Step 4 — Muse investigate on the current OpenCode pin (#257)

Do **not** wait for #254. Do **not** change `config/opencode/version`. Do **not** change the Muse model pin unless Step 0 proved the current model is unavailable — and then stop and flag rather than choosing a replacement inside this step.

Targets: `bin/ai-muse` (dispatch 558–566), new `config/opencode-muse/agent/muse-investigate.md`, `config/opencode-muse/opencode.json` only if required to register the agent, both Muse installers only to install the new agent file, `tests/test-ai-muse.sh`, `tests/test-muse-opencode-contract.sh`, `docs/muse-opencode.md`, `docs/development.md`, `skills/shared/ask-muse/SKILL.md`.

1. Add a separate Muse investigation agent with Bash enabled and public internet allowed, plus `ai-muse investigate <name> --prompt-file <file>`. Do not mutate `muse-review.md` into a capable profile.
2. Reuse `ai-review-sandbox` `ensure-copy` / `remove-recorded` and the existing Muse named-session/report path. The investigation copy must be self-contained and remote-less. Add only the minimal patch/report export needed to preserve reviewer changes or failed partial work, preferably by reusing an existing helper.
3. Reuse Muse's private key handoff, but prove the handoff file is consumed/deleted and the key removed before any model-controlled Bash child can inspect environment, arguments, filesystem, logs, or reports.
4. Preserve caller identity, session lock, exact returned session, bounded turn, terminal `step_finish`/stop proof, usage reporting, stale-source truth, reconciliation, and exact recorded-copy cleanup.
5. Update installers, fixtures, doctors, focused tests, docs, and shared skill. Preserve the formal `muse-review` profile's no-shell contract.

**Verification gate:** issue #257 holds redacted evidence for OpenCode `1.18.12` (or the pin Step 0 recorded) and Muse Spark 1.3 Contributor, working shell/public HTTP, credential-free tool children, remote-less disposable copy, truthful completion/reconciliation/recovery, and unchanged formal read-only review. Land through a feature-branch PR.

### Step 5 — Grok investigate on the current pin (#513)

Do **not** upgrade Grok. Do **not** change `config/provider-cli-versions.json`. Do **not** implement issue #249.

Targets: `bin/ai-grok-implement` (`cmd_run` 258, `--allow-shell` 270, Bash toggle 343, dispatch 490), `bin/ai-grok-review` only to prove it stays read-only, `tests/test-ai-grok-implement.sh`, `tests/test-ai-grok-review.sh`, `docs/model-setup.md`, `docs/development.md`, `skills/shared/grok-cli/SKILL.md`.

1. Add an explicit `investigate` command with shell and public internet by reusing the isolated implement worktree and `--allow-shell` path. Choose the smaller tested entrypoint. Do not merge the two Grok wrappers.
2. User-facing report must say `INVESTIGATION — ADVISORY, NOT FORMAL APPROVAL`.
3. Keep `ai-grok-review` deny-Bash and `--disable-web-search`. Do not add investigate by widening the approval reviewer.
4. Launch with an allowlisted environment. Provider/operator credentials are absent from shell children, arguments, reports, patches, and logs.
5. Preserve bounded turns, exact session identity, terminal completion proof, incomplete artifact recovery, and cleanup.
6. Update focused tests, doctor, docs, and shared skill. Do not add upgrade/pin-change assertions.

**Verification gate:** issue #513 holds redacted evidence for Grok `1.0.13` (or the pin Step 0 recorded), successful shell/internet investigation, credential-free children, unchanged formal read-only review, recoverable interruption, and no #249 broker. Land through a feature-branch PR.

### Step 6 — cross-provider integration, independent review, and merge (#253)

Depends on #254–#257 and #513 being merged to `origin/main` (or a stacked PR set whose merge order is proven). Do not factor shared code merely for textual uniformity. Muse required this “labels and banners only” limit.

Targets: `docs/task-router.md` investigation row (already present), `docs/architecture.md`, `docs/development.md`, `docs/design-decisions.md`, `docs/critical-incidents.md` only for durable new incidents, `docs/skills-map.md`, affected shared skills, installation inventory. `AGENTS.md` already routes reviewer work to `docs/task-router.md`; do not add a duplicate router row.

1. Re-fetch `origin/main` and confirm each child merge SHA. Verify all five child issues refer to current artifacts rather than superseded heads.
2. Record durable design decisions: formal review remains judge mode; investigation is capable advisory mode; Option B avoids shared-core work; upgrades were deliberately excluded.
3. Verify consistent command vocabulary and report labels across all five providers while retaining native completion semantics.
4. Run all focused provider suites, setup/restore checks, secret scans, shell-format checks, and the complete offline Bash plus PowerShell verification when the protected Windows host is free. Class is reviewer-safety. Run `ai-task-gates check --before review` before paid exact-head review and `--before ship` before merge.
5. Install the exact tree on Windows and Ubuntu, then run each doctor plus one live investigation canary per provider. Store only redacted aggregate evidence under `tests/verification/reviewer-investigation-option-b/`.
6. Run one read-only exact-head independent final review against the frozen tree. The reviewer may be any qualified independent provider that is not the implementing agent. Correct substantive findings and repeat on the new exact head.
7. Before the final commit, run `git var GIT_COMMITTER_IDENT` and require `Albert Hazan <u2giants@users.noreply.github.com>`. Stage only owned files. Open or update the pull request; merge through the queue. Do not `gh pr merge --admin` for this step: implementation is not prose. Confirm the intended SHA on `origin/main`.
8. Close child issues only when their evidence is current. Close parent #253 only after all children are closed, the exact-head gate passes, installed live canaries pass, and this STATUS table cites artifact paths. Delete this plan's open handoff in the completion commit.

**Verification gate:** all five reviewers have working `investigate` modes and unchanged formal review modes on both supported operating systems; the exact-head full suite and independent review pass; installed live canaries pass; no secret appears in repository, output, process arguments, or reviewer child environment; the final SHA is on `origin/main`; issues #254–#257, #513, and parent #253 are closed with evidence; no CLI pin changed; #249 is untouched.

## 10. Tests required

Every provider suite must add named behavior for:

- `investigate` appears in help and rejects unknown/arbitrary native flags.
- Investigation uses the exact existing capable lifecycle rather than a parallel unbounded path.
- A harmless shell write occurs only inside the recorded disposable copy.
- The disposable copy has no usable Git remote and cleanup targets only the exact recorded path.
- A public HTTP canary succeeds in investigation mode.
- Provider keys and representative operator-secret canaries are absent from tool-child environment, command arguments, report, patch, and logs.
- Formal review still cannot use shell, write, edit, or network tools.
- GLM `implement` still cannot use the network.
- Grok formal review still cannot use Bash or web search. Grok implement without `investigate` still defaults to deny-Bash.
- Exit zero without the provider-specific terminal event fails.
- Timeout, cancellation, provider failure, and interrupted changed work produce truthful terminal metadata and recoverable incomplete artifacts.
- Exact named-session continuation is preserved; another session cannot be selected accidentally.
- Source/head and returned model identity are recorded where the provider exposes them; unavailable fields are labeled unavailable, never invented.
- Windows path case/8.3/Git-Bash translation cannot redirect creation or cleanup outside the managed root.
- Current installed binary/version and profile bytes still match the pre-change repository pin. Investigation must not silently upgrade.

Focused suites (Git Bash on Windows):

- `tests/test-ai-glm.sh`
- `tests/test-ai-kimi.sh`
- `tests/test-ai-qwen.sh`
- `tests/test-ai-muse.sh`
- `tests/test-muse-opencode-contract.sh`
- `tests/test-ai-grok-review.sh`
- `tests/test-ai-grok-implement.sh`
- the existing sandbox, lifecycle, setup, version-pin, secret-scan, and skill-trigger tests named by each wrapper header and `docs/development.md`
- final complete Bash suite through Git Bash and complete PowerShell suite through the repository's documented Windows runner path, only when `bin/ai-test-local --check-collision` allows it

Live tests must use harmless content, a public non-authenticated HTTP endpoint, disposable records, and redacted output. They must never include secret values in prompts or commands.

## 11. Constraints, standing rules, and gotchas

- Feature-branch-PR. Never push to `main`. Never force-push. Stage only owned files. Canonical checkout is landing-only.
- Do not reset, clean, or overwrite existing dirty work in any shared checkout.
- This repository is public. Never commit raw transcripts, real `.env` files, licensed/private data, credentials, or sensitive live responses.
- Use 1Password vault `vibe_coding` through existing repository-owned secret references and serialized access. Never put secret values in prompts, command arguments, output, logs, reports, patches, or commits.
- A shell-capable reviewer may send anything it can read to the internet. Readable inputs must be the disposable repository copy plus deliberately supplied public/scrubbed evidence. Do not use investigation mode on licensed/private repositories until the caller confirms the included files are safe for that provider and internet-capable mode.
- Preserve capability: if adding investigate would require disabling formal review, implement, or credential scrubbing, stop. Do not “fix” a broken native contract by dropping investigation or by upgrading past the qualified pin inside this plan.
- Investigation is advisory and cannot satisfy formal exact-head approval.
- Provider-specific completion evidence is mandatory; process exit alone is never sufficient.
- Keep time, turn/tool, and cost bounds. Do not retry indefinitely or turn unavailable usage into zero.
- GPT-5.6 Codex work uses low or medium reasoning only.
- Do not run local reviewer suites while protected Windows CI is active on this same physical host. Confirm with `bin/ai-test-local --check-collision`.
- Any change to wrappers, evidence tools, safety tests, or installed routing rules needs an independent exact-head final review before merge.
- Do not collide with worktree `parent-issue-253-status-9293e4`.
- Declare `ai-task-gates start --class reviewer-safety` before editing wrappers. This planning correction is prose; implementation is not.

## 12. Access and environment

- GitHub: authenticated `ai-gh` (not raw `gh`) to `https://github.com/popcre/ai-devops`; parent #253 and children #254–#257 and #513 are the work ledger.
- Implementation worktree: dedicated clone of current `origin/main`, branch named for the child (for example `grok/254-glm-investigate`). Source of truth is freshly fetched `origin/main`.
- Windows shell: PowerShell for native setup/status; `C:\Program Files\Git\bin\bash.exe` for Bash scripts/tests.
- Ubuntu: configured ai-devops reviewer host and non-root `ai` user according to `templates/system/machine-atlas.md`. Do not guess host/user details.
- Provider authentication stays in existing locations: GLM and Muse API references, Qwen Coding Plan reference, and Kimi OAuth through existing setup and 1Password vault `vibe_coding`. Read the affected wrapper/setup documentation for item titles; never copy values into this plan or issue comments.
- There is no hosted application deployment. Delivery means merge to `origin/main`, installation on supported machines, and live provider qualification.

## 13. Definition of done, risks, rollback, and open questions

### Definition of done

- [ ] Parent issue #253 has exactly the five intended child issues #254–#257 and #513 and every child is closed with current evidence that matches this corrected plan (no upgrade claims).
- [ ] `ai-glm`, `ai-kimi`, `ai-qwen`, `ai-muse`, and Grok each expose a documented `investigate` mode with shell and public internet.
- [ ] Investigation runs only in a disposable remote-less copy and does not inherit operator credentials.
- [ ] Formal review remains structurally read-only and clearly distinct from advisory investigation.
- [ ] GLM `implement` still cannot use the network.
- [ ] No OpenCode/Kimi/Qwen/Muse/Grok pin or model changed unless Step 0 proved the current model unavailable — and that case was flagged, not silently replaced.
- [ ] Issue #249 is unchanged by this plan.
- [ ] Focused, full offline, installation, hostile, and authenticated live tests pass with redacted artifacts.
- [ ] Independent exact-head final review passes after the final content change.
- [ ] Documentation, skills, plan STATUS, and handoff state match the shipped implementation.
- [ ] Git identity is verified; owned files alone are committed; PRs merged through the queue; final SHA is on `origin/main`.
- [ ] No hosted deployment is claimed; installed live qualification is recorded.

### Principal risks and mitigations

- **Credential exfiltration:** minimize readable environment and inputs; keep provider-key handoff private/self-deleting; hostile-test tool-child environment and arguments.
- **Concurrent work damage:** use the existing disposable-copy helper; never run capable mode in the live checkout.
- **False completion:** retain provider-specific terminal events, timeouts, and uncertain states.
- **Scope expansion into upgrades or framework work:** this file forbids both. Keep upgrades out. Keep #169 separate.
- **Private repository leakage:** do not use internet-capable investigation on protected/licensed content without an explicit safe evidence packet.
- **GLM implement accidentally gaining network:** add tests that implement still cannot reach the network after investigate lands.
- **Muse key surviving into Bash children:** prove deletion before first model-controlled shell.
- **Grok approval reviewer accidentally gaining Bash or web search:** tests must keep `ai-grok-review` deny-Bash and `--disable-web-search` after investigate lands.
- **Pulling #249 into #513:** stop; this parent forbids the broker.

### Rollback

Each provider child must be independently revertible by reverting its merge commit and reinstalling from `origin/main`. Preserve reports and incident evidence. Do not disable the other providers or delete unrelated sessions. Because this plan does not change CLI pins, rollback does not require restoring an old binary pin.

### Open questions

No owner decision is currently required. Implementation judgment is limited to the provider-local smallest code shape and whether Qwen discovery still mismatches.

## Mandatory plan self-audit

1. **Could a brand-new AI session execute this plan without asking a question? Yes.** Sections 1–4 define the business outcome including Grok #513, Muse's AGREE, terminology, scope, and exclusions (upgrades out, #249 broker out); Sections 5–8 carry current machinery including `ai-grok-review` / `ai-grok-implement`, findings, rejected approaches, and locked/open decisions; Section 9 provides Steps 0–6 with verification gates; Sections 10–13 provide tests, rules, access, landing, rollback, and closure.
2. **Does the plan carry every relevant background, nuance, and rejected approach? Yes.** Sections 3, 5, 6, 7, and 8 record the 2026-09-03 owner request, the 2026-09-16 correction, Muse Spark AGREE with notes already present, why Grok is Option B not #249, why GLM cannot alias implement as-is, why Muse must not wait on GLM, why upgrades are out, and the #198/#249/#169 boundaries.
3. **Is the ultimate goal clear enough for correct judgment if a step is wrong? Yes.** Section 1 states the owner-visible outcome for five reviewers, fewest-moving-parts Option B, no upgrades, no #249 broker, the harm/credential boundary, and that the goal wins over a conflicting step.

Checklist result: **PASS**. All 13 sections are present; the plan is standalone; every step names targets, dependencies, and evidence gates; locked and open decisions are labeled; tests are behavioral; identifiers and environments are defined; secrets are location-only; completion includes PR, exact-head review, installation, live qualification, documentation, issue closure, and `origin/main` proof.
