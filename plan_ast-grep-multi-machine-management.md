# Implementation plan — managed ast-grep across Windows and Ubuntu

Plan owner: Codex planning session, 2026-08-30
Tracking issue: [popcre/ai-devops#187](https://github.com/popcre/ai-devops/issues/187)
Companion handoff: [HANDOFF.d/2026-08-30T1403Z-edge-dev-codex-ast-grep-management.md](HANDOFF.d/2026-08-30T1403Z-edge-dev-codex-ast-grep-management.md)

## STATUS — read this first

| Step | Status | Date | Evidence |
|---|---|---|---|
| 1. Refresh live facts and reserve the work | ✅ complete | 2026-08-30 | Claimed in issue comment 5472420747. ai-devops `a66586dc`; Ansible `1e5fe45b`; npm `0.45.2` still publishes `ast-grep` and `sg`; Windows has neither command; hetz `/usr/bin/sg` resolves to login-owned `/usr/bin/newgrp` SHA-256 `572ab15948df3969e929b902641c3a42e76dce7d71a22fbc58011ca89d8d965e`; auto-apply is true; no competing #187 claim. This bounded dependency follows #187 and does not duplicate the broader #159/#168 throughput mechanism. |
| 2. Add the pinned Windows installation and repair path | ✅ complete | 2026-08-30 | Exact `0.45.2` catalog/reconciler pin, `sg` ownership refusal, direct/bootstrap convergence, and non-mutating fixture implemented; Windows structural test and 26 pin checks pass. |
| 3. Add Windows verification, documentation, and restore coverage | ✅ complete | 2026-08-30 | Verifier reads the catalog and requires exact ast-grep version; Windows and Ubuntu recovery routes documented; focused Windows test passes. |
| 4. Add concise shared Claude/Codex usage guidance | ✅ complete | 2026-08-30 | Both globals carry aligned advisory wording; strict context audit and its enforcement suite pass with zero parity mismatches. |
| 5. Add the same pinned package to the Ubuntu Ansible role | 🟨 source ready; preview running | 2026-08-30 | Ansible commit `a98ec32` and PR #13 isolate the package, expose only `ast-grep`, preserve OS `sg`, and pass the focused source test; official lint/syntax/read-only preview is pending. |
| 6. Land source changes and roll out the three Windows computers | ⬜ open | — | Required GitHub and per-machine evidence is named in Phase 4. |
| 7. Apply and verify the Ubuntu production-host change | ⬜ open; owner authorization required before apply | — | Required Ansible check/apply/live evidence is named in Phase 5. |

Fresh-session start: begin at Step 1. Nothing has been implemented or installed by this planning session.

---

## 1. The ultimate goal

Albert should be able to describe an application change in ordinary business language. Claude or Codex should automatically have one additional specialist tool available when the same code pattern must be found or changed safely across many files. Albert must not learn ast-grep syntax, remember installation commands, or tell each conversation that the tool exists.

Completion means:

- the approved ast-grep version is reproducibly installed on all three Windows AI computers;
- the same approved version is installed through Ansible on the managed Ubuntu server (`hetz`);
- both Claude and Codex receive one short standing instruction explaining when the tool helps and the safety checks required before rewriting code;
- ordinary text search remains the default for ordinary text, documentation, configuration, SQL text, and unsupported languages;
- rebuilding or repairing any machine restores the tool without a separate manual procedure; and
- every machine proves the full `ast-grep` command resolves and reports the approved version.

**If a step conflicts with this goal, the goal wins — stop and flag it.** Do not force ast-grep into work where it is unsupported or less clear than existing tools.

## 2. What this application is

`popcre/ai-devops` is Albert Hazan's public backup-and-restore toolkit for a multi-model AI coding workflow. It manages Windows setup, shared Claude/Codex instructions, reusable skills, command-line tools, and Ubuntu toolkit installation. It is not a hosted application and has no application deployment or database.

Relevant environments:

- Three Windows computers run Codex for Windows, Claude for Windows, Codex CLI, and Claude CLI.
- The Windows recovery entry point is `bin/bootstrap-windows-dev.ps1`; machine verification is `bin/verify-windows-dev.ps1`.
- The Ubuntu host is the production Hetzner VPS called `hetz`. Albert reaches its Claude/Codex CLIs through SSH from the Windows applications.
- Host packages on `hetz` are owned by the private `u2giants/ansible` repository, not by ad-hoc SSH commands and not solely by `ai-devops/install.sh`.
- GitHub is the source of truth. `ai-devops` uses a feature branch, pull request, merge queue, and `bin/ai-pr-wait`. The `ansible` repository's policy must be re-derived independently; its 2026-08-30 `AGENTS.md` said main-only and a host-affecting push can start the serialized production pipeline. If repository-local instructions and a central policy tool disagree, stop and reconcile the routing before mutation.

The current live GitHub canonical repository resolves as `popcre/ai-devops` even when an older `u2giants/ai-devops` URL is used. Do not treat the redirect as a second repository.

## 3. What triggered this work

Albert asked whether ast-grep would help his non-programmer, AI-driven workflow. A privacy-safe review of local Claude and Codex transcripts found recurring whole-repository searches, repeated-pattern changes, refactors, and audits where a syntax-aware search tool could reduce missed matches and unsafe text replacement. The conclusion was that ast-grep is an occasional specialist complement, not an everyday replacement for Codex, Claude, or `rg`.

Albert then decided the tool should be installed and managed through `ai-devops`, so all machines remain recoverable and he does not have to announce the tool in every chat. Issue [#187](https://github.com/popcre/ai-devops/issues/187) records that outcome and its acceptance criteria.

This is a setup/recovery feature, not a response to a currently broken application. Reproduction is therefore: on the planning computer, `Get-Command ast-grep` and `Get-Command sg` return nothing; the repository's setup and verification files contain no ast-grep entry.

## 4. Scope

### In scope

- Pin the reviewed official npm CLI package `@ast-grep/cli` at version `0.45.2` in `ai-devops`.
- Install/repair it on Windows using the repository's existing non-WinGet npm reconciliation path.
- Ensure both the full bootstrap and direct machine-setup routes converge on exactly one pinned installation.
- Verify command presence and exact version without changing machine state in test-only mode.
- Add minimal, aligned Claude/Codex standing guidance that tells the agents when to consider ast-grep and how to use it safely.
- Update restore/setup documentation so a fresh Windows computer receives it automatically.
- Add an Ansible-owned isolated npm installation under `/opt/ast-grep` for `hetz`, then expose only the full `ast-grep` executable through `/usr/local/bin/ast-grep`.
- Add offline tests in both repositories and capture real rollout evidence on three Windows computers and `hetz`.
- Close issue #187 and retire this handoff only after all source, rollout, and live verification gates pass.

### NOT in this plan

- Teaching Albert ast-grep syntax or requiring him to request the tool by name.
- Creating an MCP server, Codex plugin, Claude extension, VS Code extension, wrapper command, or dedicated skill for ast-grep.
- Vendoring ast-grep binaries or source code into either repository.
- Making ast-grep mandatory for every search, edit, refactor, audit, or migration.
- Replacing `rg`, Git, compiler/linter checks, tests, or model reasoning.
- Adding repository-specific `sgconfig.yml` files or ast-grep lint rules to application repositories. Those require a separate demonstrated need.
- Replacing, shadowing, or relinking the short `sg` command. The npm package publishes both `ast-grep` and `sg`, while Linux already uses `/usr/bin/sg`; all shared guidance and checks must use `ast-grep`.
- Changing any application, database, Coolify resource, Docker container, firewall, secret, or production service.
- Applying the Ansible change to `hetz` without Albert explicitly authorizing that exact production action in the implementation chat.

## 5. Current state of the code

Snapshot date: 2026-08-30. Re-derive every fact before implementation because both repositories are active.

### `popcre/ai-devops`

- Branch policy is feature branch → pull request → merge queue (`AGENTS.md`), with completion tracked by `bin/ai-pr-wait`. The GLM-reviewed plan was published at `c5d6d1248b1bf6eaa17e70672b7a8f4865e0d981`.
- `config/tool-versions.json:21` is the canonical npm version inventory. It has no `@ast-grep/cli` entry.
- `.config/configuration.winget` manages ordinary Windows packages. ast-grep is not declared, and the official ast-grep quick start does not document WinGet as an installation channel.
- `bin/reconcile-windows-package-exceptions.ps1` owns global npm CLIs that are not WinGet packages. Its package loop currently handles Vercel, Trigger.dev, and Railway.
- `bin/bootstrap-windows-dev.ps1:142-199` runs the package-exception reconciler, then runs `setup-machine.ps1` with a skip switch so Railway is not installed twice.
- `bin/setup-machine.ps1:58-72` declares `-SkipRailwayCliReconcile`; `bin/setup-machine.ps1:210-216` separately repairs Railway when that script is run directly.
- `bin/verify-windows-dev.ps1:9-13` checks required commands but does not include ast-grep and does not compare command versions to the catalog.
- `tests/test-tool-version-pins.sh:27-29` maps pinned npm packages to owning files, but currently allows an unmapped catalog key to pass because an empty mapping produces no assertion. This work must require a non-empty mapping for every npm key.
- `tests/windows-winget-config.tests.ps1:48-53` proves the bootstrap/direct-setup package reconciliation contract for Railway and is the closest model for ast-grep.
- `templates/system/CLAUDE-global.md` and `templates/system/AGENTS-global-codex.md` are the canonical shared standing instructions installed by `bin/ai-adopt-globals`.
- `docs/windows-winget-configuration.md:71-80` explains the non-WinGet package exception path and canonical version catalog.
- `docs/restore-from-zero.md:93-94` requires recovery-critical tools to use reviewed pins and forbids substituting mutable `latest`.
- No ast-grep source change is currently committed, pushed, installed, or deployed by this workstream.

### `u2giants/ansible`

- The local inspected checkout was clean on `main` on 2026-08-30; recheck before work.
- `roles/dev_tools/defaults/main.yml:28-33` defines the pinned global npm CLI list, but ast-grep cannot safely join that loop because the package also publishes `sg`.
- `roles/dev_tools/tasks/main.yml:52-61` is the nearest npm-management pattern. ast-grep needs a separate non-global, Ansible-owned prefix so the OS `sg` remains untouched.
- `roles/dev_tools/README.md:7-16` documents the managed non-apt tools and must name ast-grep after implementation.
- `playbooks/site.yml:49-50` runs `dev_tools` as a normal Phase 1 role. Pushing a host-affecting change to `main` can therefore trigger a serialized production apply.
- No ast-grep Ansible change or production apply has occurred.

### External product facts

- The official ast-grep quick start documents the global npm command `npm i @ast-grep/cli -g` and says the binary is `ast-grep` or `sg`: <https://ast-grep.github.io/guide/quick-start>.
- The same official page warns that Linux already has a different `sg`; use the full `ast-grep` command.
- The npm registry returned `0.45.2` as both the current package version and `latest` on 2026-08-30. The plan pins the exact version; the implementation must not install `latest` implicitly.
- `npm view @ast-grep/cli@0.45.2 bin --json` returned both `{"sg":"sg","ast-grep":"ast-grep"}`. The Linux x64 GNU dependency contains both executables. A global Ubuntu npm install is therefore unsafe even if documentation only mentions the full command.
- GLM 5.3 reviewed the published plan at commit `c5d6d1248b1bf6eaa17e70672b7a8f4865e0d981` in session `ast-grep-management-plan-review` and returned **REVISE**. This corrected plan incorporates its two blockers and five hardening suggestions.

## 6. Key findings and root cause

1. **The missing capability is distribution, not model intelligence.** Claude and Codex can already invoke terminal commands and reason about code. They need ast-grep available on `PATH` plus a short instruction describing when it is useful.
2. **Windows already has the correct ownership path.** Because Node/npm is a managed prerequisite and the vendor documents npm installation, `bin/reconcile-windows-package-exceptions.ps1` is the fewest-moving-parts route. Adding an undocumented WinGet source would weaken provenance and recovery.
3. **Ubuntu package ownership is separate.** `ai-devops` owns toolkit behavior and Windows developer setup; `u2giants/ansible` owns packages on `hetz`. Installing with SSH or adding host-package mutation to `ai-devops/install.sh` would create drift.
4. **The full command is the portable contract, but words alone do not prevent a collision.** The npm package installs both names. Ubuntu must isolate the package and expose only `ast-grep`; Windows must preflight any existing `sg` and refuse to overwrite an unrelated command.
5. **A global rule must stay narrow.** ast-grep helps with syntax-aware repeated code patterns. It is inappropriate for ordinary prose, raw configuration, many SQL/text tasks, and unsupported languages. A rule saying “always use ast-grep” would make the workflow worse.
6. **Rewrites need layered proof.** ast-grep can perform broad mechanical edits quickly. Safety comes from previewing matches, reviewing `git diff`, and running the repository's normal tests—not from trusting a successful tool exit alone.
7. **Desktop sessions inherit environment state.** After a global npm install, already-running Claude/Codex windows may retain an old `PATH`. Rollout proof must come from newly opened application/terminal sessions, not only the installer process.

## 7. Approaches considered and rejected

### Rejected: do nothing because Codex already searches code

Codex and Claude can search with existing tools, but that does not provide deterministic syntax-aware matching for repeated code shapes. Transcript evidence showed enough occasional high-risk work to justify a small managed dependency.

### Rejected: require Albert to ask for ast-grep

Albert is not a programmer and should not decide which code-search engine fits a task. A shared standing rule lets the agent choose while Albert continues describing business outcomes.

### Rejected: install manually on each machine

Four independent manual installs drift, disappear during rebuilds, and require Albert to remember a maintenance procedure. This conflicts with both repositories' disaster-recovery mission.

### Rejected: vendor the executable

Vendoring would increase public-repository size, create platform-specific binary ownership, complicate security updates, and duplicate the vendor's distribution mechanism.

### Rejected: use an MCP server, plugin, extension, wrapper, or new skill

ast-grep is already a composable CLI. Extra integration layers add failure modes without adding capability. A PATH-visible executable and concise standing guidance are sufficient.

### Rejected: add ast-grep to `.config/configuration.winget`

The official installation documentation reviewed on 2026-08-30 lists npm, Cargo, Homebrew, MacPorts, Nix, and pip—not WinGet. The repository already has a tested exception path for official npm CLIs.

### Rejected: let `npm` install an unpinned latest version

Recovery must be reproducible. `@ast-grep/cli@0.45.2` is locked for this work; a future upgrade is a separate reviewed version bump.

### Rejected: install `sg` or create an `sg` alias

Linux uses `sg` for another operating-system command. Aliasing it would shadow an OS capability and violate the rule against replacing system commands.

### Rejected: globally install the npm meta-package on Ubuntu

`@ast-grep/cli@0.45.2` publishes both `ast-grep` and `sg`. A global npm install can therefore replace or shadow Linux's existing `sg`. Install into an isolated Ansible-owned prefix and link only the full executable.

### Rejected: make `ai-devops/install.sh` mutate the production host package directly

The Ansible repository explicitly owns host packages and production apply serialization. Bypassing it would create unmanaged drift and weaken rebuild proof.

### Rejected: force ast-grep for every code search or rewrite

That would add ceremony to simple work and produce false confidence in unsupported languages or non-code files. The agent should consider it only when syntax-aware repeated matching materially helps.

## 8. Design decisions

### Locked decisions — do not relitigate during implementation

- **2026-08-30:** `ai-devops` is the management layer for the approved version, Windows setup, shared instructions, restore documentation, and verification.
- **2026-08-30:** `u2giants/ansible` owns the `hetz` package installation and live production rollout.
- **2026-08-30:** use the official npm CLI package `@ast-grep/cli`, pinned to `0.45.2`; never use an implicit `latest` specifier.
- **2026-08-30:** the portable executable name is `ast-grep`; do not install or document `sg` as the contract.
- **2026-08-30:** Ubuntu uses an isolated `/opt/ast-grep` npm prefix and exposes only `/usr/local/bin/ast-grep`; `/usr/bin/sg` must remain owned by the operating system and unchanged.
- **2026-08-30:** Windows installation may use the existing global npm exception path only after preflighting `sg`; refuse to replace an unrelated existing command and prove any installed npm `sg` shim belongs to the same pinned package.
- **2026-08-30:** `ai-devops` ships through its current PR/merge-queue workflow. Ansible routing is independently re-derived because landing a host-affecting change may itself authorize/trigger production behavior.
- **2026-08-30:** do not add a plugin, MCP server, extension, wrapper, or skill.
- **2026-08-30:** the standing instruction is advisory (“consider ast-grep when...”), not mandatory, and requires preview/diff/tests before rewrites.
- **2026-08-30:** a missing ast-grep command is a setup verification failure on managed machines, but an individual application task may fall back visibly to existing tools until machine repair is complete; do not disable or bypass machine repair.

### Open implementation judgment

- The implementer may generalize `-SkipRailwayCliReconcile` into a clearly named package-reconciliation skip switch, or add a parallel ast-grep skip switch. Choose the smaller change that makes both bootstrap and direct `setup-machine.ps1` idempotent and prevents duplicate npm runs. Update every caller and structural test together.
- The implementer may add a focused Ansible test file or extend the nearest existing dependency-light source test. It must prove the exact package/version, isolated prefix, full-command-only link, preservation of OS `sg`, documentation coverage, and absence of mutable `latest`.
- The exact wording location inside the two global templates may follow their current organization, but the Claude and Codex meaning must remain aligned and brief.

No other owner decision is required for source implementation. Production rollout has a separate explicit authorization gate in Sections 9, 12, and 13.

## 9. Executable implementation plan

### Phase 0 — refresh facts and claim the work

#### Step 1. Re-derive repository, package, and concurrency facts

1. In `C:\repos\ai-devops`, read `AGENTS.md` and this plan's STATUS table. Confirm issue #187 is open and not already claimed by another session.
2. Run `git status --short`, `git branch --show-current`, `git fetch origin main`, and compare `HEAD` with `origin/main`. Preserve all unrelated dirty files.
3. Run `gh repo view --json nameWithOwner,url,defaultBranchRef` because old `u2giants/ai-devops` URLs currently redirect to `popcre/ai-devops`.
4. Re-query `npm view @ast-grep/cli version dist-tags --json`. If `0.45.2` is unavailable, withdrawn, or has a known security issue, stop and record the evidence; do not silently choose a different version.
5. Query `npm view @ast-grep/cli@0.45.2 bin optionalDependencies --json` and inspect the selected platform package file list. Require evidence that both executable names still publish; if packaging changed, reassess this design rather than assuming safety.
6. On Windows, record `Get-Command ast-grep -All` and `Get-Command sg -All`. On `hetz`, record `command -v`, resolved path, package ownership, and checksum for the existing `sg`; these are preservation baselines, not permission to install.
7. Inspect `C:\repos\ansible` independently: read its `AGENTS.md`, status, current branch, `ai-repo-policy` output if available, and auto-apply behavior. If policy sources conflict, resolve the repository routing before editing or landing.
8. Check that the `edge-dev` self-hosted Windows runner is idle; do not overlap local rollout/tests with `windows-offline` or `windows-reviewer-safety`, and do not repeat the identical merge-queue verification commit.
9. Record why this plan is not served by an existing active plan, and link future consolidation through #168 under #159 rather than growing a parallel permanent mechanism.
10. Update this STATUS row with exact heads and evidence before editing.

Dependencies: none. This phase must finish before either repository is edited.
Parallelism: the two repository read-only checks may run in parallel after the issue check.
**Verification gate:** issue #187 is open; exact heads/policies/runner state are recorded; npm package/bin facts and both `sg` baselines are captured; no overlapping owner or unresolved policy conflict exists.

**Natural context cut:** if the session is already context-heavy after discovery, use the `fresh-session` skill, then re-read this entire plan before Phase 1.

### Phase 1 — implement the Windows installation and verification contract

#### Step 2. Add the canonical version and Windows reconciliation

1. Add `"@ast-grep/cli": "0.45.2"` under `npm` in `config/tool-versions.json`; update `reviewed_at` to the real review date.
2. Extend `bin/reconcile-windows-package-exceptions.ps1`'s existing npm package table with human name `ast-grep`, npm spec `@ast-grep/cli@0.45.2`, and command `ast-grep`.
3. Before installation, resolve every existing Windows `sg`. If any is unrelated to the pinned ast-grep npm package, stop without mutation. After installation, prove `ast-grep` is pinned and any npm-created `sg` shim resolves to that same package; do not make `sg` the supported contract.
4. Strengthen this script's `-TestOnly` behavior for version-pinned tools so ast-grep is not merely present: run `ast-grep --version`, require exit code zero, and require output containing `0.45.2`. The test-only path must not install or update anything.
5. Ensure direct `bin/setup-machine.ps1` execution also reconciles the pin, while bootstrap does not install it twice. A duplicate idempotent npm run is an efficiency issue, not a correctness blocker; prefer the smallest safe caller change.
6. Refresh the current process PATH using existing supported logic; do not add a user-specific npm directory.
7. Strengthen `tests/test-tool-version-pins.sh` so every npm catalog key must have a non-empty owner-file mapping, then assert the exact ast-grep pin in every owner.
8. Extend `tests/windows-winget-config.tests.ps1` to prove exact pin, non-mutating test-only mode, direct/setup parity, unrelated-`sg` refusal, package-owned shim acceptance, and bootstrap result labeling that names ast-grep.

Target files: `config/tool-versions.json`, `bin/reconcile-windows-package-exceptions.ps1`, `bin/setup-machine.ps1`, `bin/bootstrap-windows-dev.ps1`, `tests/test-tool-version-pins.sh`, `tests/windows-winget-config.tests.ps1`.
Dependencies: Step 1.
**Verification gate:** changed PowerShell parses; the two named test files pass in their required shells; a fixture proves `-TestOnly` reports version drift without running npm.

#### Step 3. Add machine verification and restore documentation

1. Extend `bin/verify-windows-dev.ps1` to include `ast-grep` and compare its reported version with `config/tool-versions.json`. A different version is drift.
2. Keep verification secret-free and machine-readable in the existing JSON report.
3. Extend structural Windows tests to prove the full command and catalog version are checked.
4. Update `docs/windows-winget-configuration.md` to name ast-grep as an official npm exception pinned in the catalog.
5. Update `docs/restore-from-zero.md` so Windows and Ubuntu recovery acceptance include `ast-grep --version` matching the pin; Ubuntu installation is through Ansible, not SSH.
6. Update `docs/deployment.md` or `docs/config-inventory.md` only if final ownership statements require it; do not duplicate procedures.

Target files: `bin/verify-windows-dev.ps1`, `tests/windows-winget-config.tests.ps1`, `docs/windows-winget-configuration.md`, `docs/restore-from-zero.md`, and only demonstrably affected inventory/deployment prose.
Dependencies: Step 2.
**Verification gate:** controlled missing/wrong versions fail, a `0.45.2` fixture passes, docs name both routes, and no recovery instruction uses `latest` or manual install.

### Phase 2 — teach Claude and Codex when to use it

#### Step 4. Add aligned, concise standing guidance

1. Add equivalent behavior to `templates/system/CLAUDE-global.md` and `templates/system/AGENTS-global-codex.md`: use `rg` for ordinary text; consider `ast-grep` for syntax-aware/repeated multi-file code patterns; use the full command; preview before applying; inspect Git diff and run normal tests; repair a missing managed installation.
2. Keep it to one compact bullet or paragraph per global; examples and procedures do not belong in always-loaded context.
3. Add the parity rule to `tools/context-audit/context-audit.py`: extend `PARITY_RULES` (near line 101), exercise `cross_client_parity` (near line 490), and require the `--strict` path (near line 798) to fail when either client drifts.
4. Verify `bin/ai-adopt-globals --dry-run` carries the templates without overwriting preserved machine sections. Do not adopt everywhere before the source commit is on `origin/main`.

Target files: both global templates and the narrowest existing parity/context test.
Dependencies: Step 2. May run alongside Step 3.
**Verification gate:** parity/context tests pass; wording says “consider,” requires preview/diff/tests, and never presents `sg` as the command.

**Natural context cut:** after `ai-devops` source and offline tests pass, update STATUS and use `fresh-session` before switching repositories if context is crowded. Re-read Phases 3–5.

### Phase 3 — add Ubuntu host management in `u2giants/ansible`

#### Step 5. Add the same pinned package to an isolated Ansible-owned prefix

1. In a clean current `C:\repos\ansible`, add role defaults `ast_grep_version: "0.45.2"` and `ast_grep_install_prefix: /opt/ast-grep`; do not add ast-grep to the global `dev_tools_npm` loop.
2. In `roles/dev_tools/tasks/main.yml`, assert the supported target is Ubuntu x86_64 with glibc, preserve the recorded OS `sg`, and use `community.general.npm` non-globally with `path: /opt/ast-grep` and exact `@ast-grep/cli@0.45.2`. Do not use a shell installer.
3. Link only `/opt/ast-grep/node_modules/@ast-grep/cli-linux-x64-gnu/ast-grep` to `/usr/local/bin/ast-grep`. Never link the bundled `sg`; fail if the expected platform binary is absent rather than guessing a path or architecture.
4. Add non-mutating verification for exact version, harmless invocation, link target, and unchanged OS `sg` path/ownership. Keep check mode useful before a pending install.
5. Update `roles/dev_tools/README.md` with package, pin, isolated prefix, full command, supported architecture, and collision rationale.
6. Add/extend a dependency-light test for the exact package/version, non-global prefix, full-command-only link, `sg` preservation, architecture guard, and absence of `latest`.
7. Run `ansible-lint`, syntax check, focused tests, and the relevant suite.
8. Run supported read-only `--check --diff` against `hetz`; do not land a main-triggering change or apply yet.

Target files: `roles/dev_tools/defaults/main.yml`, `roles/dev_tools/tasks/main.yml`, `roles/dev_tools/README.md`, and one focused test.
Dependencies: Steps 1–4.
**Verification gate:** offline checks pass; preview shows only the isolated package/full-command link; `/usr/bin/sg` remains unchanged; no unrelated resource appears.

### Phase 4 — land source and roll out Windows safely

#### Step 6. Commit, push, verify CI, then repair all three Windows machines

1. Before each repository's first commit, run `git var GIT_COMMITTER_IDENT`; require `Albert Hazan <u2giants@users.noreply.github.com>`.
2. In `ai-devops`, stage only owned files and run the relevant suite from `docs/development.md`, including the pin, Windows, global/context, installer, and PowerShell parse tests.
3. In `ai-devops`, create a `codex/` feature branch, push it, open a pull request, enter the merge queue, and use `bin/ai-pr-wait <pr>` until the exact merge commit is verified on `origin/main`.
4. In `ansible`, stage/test only owned files and prepare the exact commit locally. Do not push/merge a host-affecting main change before the production gate if that action can trigger apply. If live policy permits a non-triggering feature branch, it may be pushed for review; otherwise preserve the tested local commit until Step 7.
5. On each Windows computer, update from clean current `ai-devops` and run the supported bootstrap; never use a one-off npm command.
6. Reopen Codex for Windows, Claude for Windows, and old terminals.
7. In new local Codex and Claude contexts on each computer verify command path, version `0.45.2`, repository verifier success, a harmless read-only fixture match, and installed shared globals.
8. Store secret-free evidence with hostname, source commit, command path, version, verifier result, and timestamp under existing verification results or issue #187.

Dependencies: Steps 2–5 and offline tests. Landing `ai-devops` does not authorize landing/applying Ansible.
Parallelism: the three Windows rollouts may proceed concurrently only after the same source commit reaches `origin/main`.
**Verification gate:** the `ai-devops` PR merge is verified, Ansible's exact tested change is ready but not prematurely applied, and all three Windows machines prove the approved command/version from new Claude/Codex contexts.

### Phase 5 — production Ubuntu authorization, apply, and final proof

#### Step 7. Apply the Ansible change to `hetz` only after explicit authorization

1. Present Albert one plain request naming the exact action and consequence: land the identified Ansible source commit and install isolated `@ast-grep/cli` version `0.45.2` on `hetz` through the serialized Phase 1 `dev_tools` apply.
2. Do not dispatch/allow the apply without explicit current-chat authorization. Planning, commits, and checks are not authorization.
3. Immediately before dispatch re-derive the exact source commit, workflow inputs/tags and auto-apply state, limited check-mode diff, live absence/version, and concurrency state.
4. Only after authorization, land/push the Ansible change using its freshly confirmed repository policy, then dispatch or observe the governed serialized GitHub Actions apply; never install manually over SSH.
5. Wait for completion; preserve failures and repair source rather than suppressing verification.
6. Verify directly: exact version, usability by the unprivileged Claude/Codex account, harmless read-only search, zero-drift rerun, and no unrelated service/app effects.
7. From a new SSH-driven Claude/Codex context, verify the remote command and installed shared instruction.
8. Record run/live evidence in issue #187 and STATUS, close the issue only after all four machines pass, and retire the handoff in the finishing commit.

Dependencies: Step 6 and explicit owner authorization.
**Verification gate:** governed apply, live exact-version/unprivileged proof, zero drift, all evidence, issue closure, and handoff retirement are complete.

## 10. Tests required

### `popcre/ai-devops` offline

- `tests/test-tool-version-pins.sh`: every npm key has a non-empty owner mapping, exact catalog/owner pin, and no mutable latest.
- `tests/windows-winget-config.tests.ps1`: parsing, ownership, direct/bootstrap parity, non-mutating test-only behavior, full command/version drift, result label, and safe `sg` preflight.
- `tools/context-audit/context-audit.py --strict`: equivalent advisory rules, preview/diff/tests, and never “always.”
- Existing installer/bootstrap and `ai-adopt-globals` tests named by `docs/development.md`.

### Each Windows computer

- New PowerShell: `ast-grep --version` reports `0.45.2`.
- Repository verifier passes.
- Newly opened Codex and Claude can execute it.
- Read-only fixture search finds the intended syntax match without edits.
- Re-run is idempotent.

### `u2giants/ansible`

- Exact source assertions for package/pin/isolated prefix/full-command-only link/OS `sg` preservation/no latest.
- `ansible-lint` and playbook syntax check with documented environment.
- Relevant dependency-light tests.
- Read-only `--check --diff` before apply.
- Post-apply exact version, unprivileged harmless invocation, and zero-drift rerun.

No UI, browser, database, container, or application E2E test is required.

## 11. Constraints, standing rules, and gotchas

- Preserve `rg`, Linux `sg`, npm, Claude, Codex, and all existing capabilities.
- Never create an `sg` alias or globally install the dual-bin package on Ubuntu; never use mutable `latest` in recovery.
- Use supported package management; never replace OS binaries.
- Keep the public repo secret-free; no transcripts, PATH dumps, tokens, or credentials in evidence.
- `hetz` host packages belong to Ansible; no manual SSH mutation.
- Production is read-only until exact current-chat authorization; do not bypass serialized apply.
- Stage only owned files in active repositories; re-read live `AGENTS.md` before shipping.
- `ai-devops` uses PR/merge queue and `bin/ai-pr-wait`; do not direct-push main. Reconcile any Ansible policy conflict before mutation.
- Keep `edge-dev` runner work clear of `windows-offline` and `windows-reviewer-safety`; do not duplicate verification of the identical queued commit.
- Verify the required committer identity before each first commit.
- Source merge is not installation; require direct proof from every machine.
- Reopen desktop apps before claiming PATH availability.
- Keep global wording short; do not add application `sgconfig.yml` files without a separate need.

## 12. Access and environment

- Git/GitHub CLI and npm registry read access are available on Windows.
- Canonical live repository: `popcre/ai-devops`; issue #187.
- Ubuntu management repo: `C:\repos\ansible` / `u2giants/ansible`; target `hetz`.
- No new secret. Existing production credentials remain in 1Password vault `vibe_coding` and documented GitHub Actions storage.
- Use `C:\Program Files\Git\bin\bash.exe` for Bash tests and `pwsh -NoProfile` for PowerShell.
- Use `npm view @ast-grep/cli version dist-tags --json` only for metadata; installation uses the pin.
- Record real Windows hostnames during rollout rather than guessing.
- There is no app URL/deploy SHA; authority is source commits, CI/apply run IDs, and direct command/version evidence.

## 13. Definition of done, risks, rollback, and open questions

### Definition of done

- [ ] Seven STATUS rows cite dated, reproducible evidence; issue #187 closes only at the end.
- [ ] `ai-devops` owns exact pin, Windows routes, verifier, concise globals, tests, and restore docs.
- [ ] `ansible` owns the same pin in an isolated prefix, exposes only `ast-grep`, preserves OS `sg`, and includes live-safe verification/tests/docs.
- [ ] Both relevant suites/checks pass; `ai-devops` reaches main through its PR queue, and Ansible reaches main only after the production authorization gate under its live policy.
- [ ] Three Windows computers prove command path/version/verifier/read-only use/new-client availability.
- [ ] Albert explicitly authorizes the exact `hetz` install before apply.
- [ ] Governed apply, direct `hetz` unprivileged proof, and zero-drift rerun pass.
- [ ] No existing capability or unrelated production resource is disturbed.
- [ ] Current-state/STATUS are kept fresh and the handoff retires at completion.

### Risks and mitigations

- npm platform failure: require version plus harmless invocation; diagnose instead of suppressing.
- stale PATH: reopen apps and verify from real contexts.
- command collision: isolate Ubuntu installation, link only `ast-grep`, baseline/preserve OS `sg`, and refuse unrelated Windows `sg` replacement.
- cross-repo drift: exact same pin and independent tests/evidence.
- overuse/broad rewrite damage: advisory wording, preview, Git diff, normal tests.
- production scope expansion: stop if check mode shows anything unrelated.
- concurrent edits: refresh and stage only owned files.
- artifact availability/security change: re-query; stop rather than silently substitute.

### Rollback

- Revert task-owned source commits and rerun tests.
- Any Windows removal/replacement must first be source-controlled and use the supported reconciler; never delete npm directories manually.
- Any Ubuntu rollback must be encoded in Ansible and use the serialized pipeline; no SSH uninstall.
- Preserve Claude, Codex, npm, `rg`, and Linux `sg`; stop before removal if uncertain.

### Open questions

1. **Production authorization:** Albert must explicitly authorize the exact `hetz` install when Step 7 is ready. Recommendation: approve only after exact source commits and limited preview are shown. This is the only blocking owner decision.
2. **Windows hostnames:** record during rollout; this is evidence, not a decision.
3. **Ansible policy reconciliation:** as of 2026-08-30 repository-local instructions said main-only, while centralized policy may evolve. Resolve any live conflict before mutation; this is a safety fact, not an owner preference.

---

## Mandatory plan self-audit

### 1. Could a brand-new AI session execute this plan without the chat?

**Yes.** It now contains the exact dual-command package evidence, Windows collision preflight, isolated Ubuntu design, repository-specific shipping policies, auto-apply ordering, runner coordination, parity implementation points, and production gate needed to execute without this chat.

### 2. Does it carry all background, nuance, and ruled-out approaches?

**Yes.** It preserves the occasional-use conclusion and rejected integration layers, and adds GLM's confirmed blocker evidence: the package publishes both commands, Ubuntu global npm is unsafe, `ai-devops` uses PR/merge queue, and Ansible landing must stay behind the apply gate.

### 3. Is the goal clear enough to guide judgment?

**Yes.** Section 1 says Albert continues in plain language, agents choose the tool, every machine remains recoverable, ordinary search stays available, and direct proof is required. It explicitly says the goal wins. Sections 4 and 11 reinforce preservation/non-overuse.

### Checklist result

- [x] All 13 sections, plain goal, and goal-wins rule.
- [x] Fresh-session execution without chat, with one explicit production gate.
- [x] Rejected approaches, locked/open decisions, and explicit exclusions.
- [x] Concrete files/roles and verification gate for every step.
- [x] Named tests and defined repositories/hosts/commands/issue.
- [x] Secrets referenced only by location.
- [x] Done includes commits, CI, four-machine rollout, authorization, live proof, closure, and handoff retirement.
- [x] Plan and handoff link directly.
- [x] GLM 5.3 REVISE findings are resolved with executable collision, policy, test, parity, runner, and consolidation controls.

**Self-audit verdict: PASS.**
