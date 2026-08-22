# IMPLEMENTATION PLAN — complete strategy remediation (2026-08-21)

Handoff: [`HANDOFF.d/2026-08-21T2325Z-albt16-codex-full-strategy-remediation.md`](HANDOFF.d/2026-08-21T2325Z-albt16-codex-full-strategy-remediation.md)  
Tracker: [GitHub issue #62](https://github.com/u2giants/ai-devops/issues/62)

## STATUS

| Step | Work | Status | Date | Evidence / restart point |
|---|---|---|---|---|
| 0 | Publish this plan, the corrected audit record, and the linked handoff | ✅ complete | 2026-08-21 | Commit `0b495562453909bd6da6b64ee845e6d3e4987892` on `origin/main`; issue #62 comment links the immutable plan |
| 1 | Contain and preserve the live four-machine memory incident | ✅ complete | 2026-08-21 | two full former 30-minute intervals elapsed after `c972622` with no new public-memory commit |
| 2 | Move portable memory to a private hub and rebuild the authoritative indexes | ✅ complete | 2026-08-21 | private head `2765c34192a74a4a106998ef5f9d7f792bcf7263`; coverage health zero findings; DesignFlow aliases deduplicated |
| 3 | Repair memory synchronization, privacy gates, and failure behavior | ✅ complete | 2026-08-21 | behavioral fixtures pass; live private sync and public-target rejection proven; schedules remain disabled |
| 4 | Correct stale database/transcript/audit instructions | ✅ complete | 2026-08-21 | private stale facts tombstoned; canonical destination guard and hostile fixtures pass |
| 5 | Make Ubuntu install/update deterministic and truthful | 🟨 verifying | 2026-08-21 | stage/failure and Node fixtures pass; awaits config migrator hook and live Ubuntu restore |
| 6 | Make Windows source, secret, and configuration setup fail closed | 🟨 verifying | 2026-08-21 | source/ACL/JSON fixtures pass; awaits disposable-machine two-run proof |
| 7 | Add versioned config migration, recoverable uninstall, and capability-based doctor | 🟨 verifying | 2026-08-21 | config/manifest/uninstall/doctor fixtures pass; awaits live archive/restore proof |
| 8 | Add one test entry point, cross-platform CI, and GitHub enforcement | 🟨 verifying | 2026-08-21 | first workflow run exposed missing Linux execute bits; repaired; awaits green rerun and post-rewrite ruleset |
| 9 | Make shared reviewer snapshots and lifecycle fail closed | 🟦 in progress | 2026-08-21 | all-or-nothing digest-bound snapshot and lifecycle tests pass; provider wiring continues in Step 10 |
| 10 | Finish provider-specific reviewer repairs and qualification | 🟦 in progress | 2026-08-21 | Codex offline repair complete; Qwen and GLM startup remain; unavailable providers stay advisory/quarantined |
| 11 | Finish the seven-stage workflow with two supported approval paths | ⬜ open | — | end-to-end scratch-repository run and exact artifact chain |
| 12 | Pin restore inputs and prove clean-machine reproducibility | ⬜ open | — | Windows first/second-run reports and Ubuntu disposable restore report |
| 13 | Repair context measurement, routing, trigger coverage, and portable fact access | ⬜ open | — | strict context audit, trigger matrix, policy tests, `ai-facts` tests |
| 14 | Remove public topology and close every transcript-ingestion path | ⬜ open | — | public-tree scan and transcript destination hostile tests |
| 15 | Purge exposed Git history through a recoverable coordinated rewrite | ⬜ open | — | protected backup location, rewrite map, unauthenticated fresh-clone scan |
| 16 | Install and verify the exact release on every managed machine | ⬜ open | — | per-machine SHA, installer, doctor, and memory-status records |
| 17 | Obtain independent exact-head approval and close the workstream | ⬜ open | — | review report, final CI run, origin SHA, closed issue #62 |

**Fresh-session start:** Step 1. Always start at the first non-complete row. Before each phase, re-read
all downstream steps for drift and update this table in the same session.

## 1. The ultimate goal — what we are trying to achieve

Albert must be able to lose a computer, restore the complete AI workflow from
GitHub and protected configuration, and trust every reported success. Durable
memory must never delete safety instructions or publish private facts. Reviewers
must never approve code they did not see. The public repository must contain no
recoverable transcripts, secrets, or avoidable private infrastructure inventory.
Every important rule must have an automated enforcement point, and the installed
state on every managed machine must be traceable to one verified Git commit.

Completion means all 30 negotiated audit findings are either repaired and proven
or, for provider capabilities that cannot pass live qualification, preserved but
visibly advisory/quarantined so they cannot satisfy an approval gate. It does not
mean hiding failures, deleting a broken capability as a shortcut, or declaring a
plan complete because code was written.

**If any step below conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is

`u2giants/ai-devops` is Albert Hazan's public backup-and-restore toolkit for his
Claude, Codex, and delegated-review workflow. The canonical branch is `main` and
GitHub is the code source of truth. It consists of Bash and PowerShell commands,
machine installers, non-secret configuration examples, prompt templates, skills,
tests, documentation, and cross-machine memory tooling. It has no web service,
container image, application database, GHCR artifact, or Coolify deployment.

For this repository, “production” means all of the following:

1. the intended commit is on `origin/main` and required GitHub checks pass;
2. server-side rules prevent branch deletion and ordinary force-pushes;
3. the canonical installer deploys that exact commit to the real managed machines;
4. installed commands, skills, globals, configuration schema, scheduled jobs, and
   capability probes match the release;
5. recovery is proven on disposable Windows 11 and Ubuntu environments.

The active memory writers observed in Git history are `albt16`, `edge-dev`,
`al8960ofc`, and `hetz`. Windows development machines use PowerShell 7 and Git
Bash. `hetz` is an Ubuntu production host; any host/OS/task-scheduler change there
must be represented through `u2giants/ansible`, never a permanent SSH hand edit.

## 3. What triggered this work

Albert requested a repository-wide strategy audit on 2026-08-21. Codex recorded
the initial result in [`bugs.md`](bugs.md), then debated every CRITICAL and HIGH
finding with a live, verified `claude-opus-5` session. The final negotiated record
is 30 findings: **3 CRITICAL, 14 HIGH, and 13 MEDIUM**.

The highest-priority incident is reproducible from `origin/main`: four scheduled
jobs repeatedly replace the `memory/ai-devops/MEMORY.md` and
`memory/shared-db/MEMORY.md` indexes with different machine-local subsets. The
cycle periodically removes the index section containing 1Password and
secret-handling safety facts. A second coupled defect can destroy the only local
memory commit after push/rebase failure and still print “Sync complete.”

The public-repository boundary is also false: 1,464 transcript blobs, 630 tree
objects, and 870 `.jsonl` object lines remain reachable from `origin/main`, about
1.2 GB uncompressed. The public repo additionally accepts unattended AI-authored
memory commits. These are active/existing states, not hypothetical lint findings.

## 4. Scope — in and out

### In this plan

- Every finding in the “Finding-to-step coverage” table below.
- Source, tests, docs, skills, templates, configuration examples, and lifecycle
  scripts inside this repository.
- GitHub Actions verification and a GitHub ruleset appropriate to a main-only
  public toolkit.
- A new private `u2giants/ai-devops-memory` hub for portable memory, with no
  secret values and no unattended public pushes.
- Recoverable removal of transcript, memory, and private-topology objects from
  the public repository's reachable history.
- Installation and verification on every managed machine that currently runs
  this toolkit or its scheduled memory job.
- Existing provider repair plans. They remain the detailed engineering specs;
  this plan is their incident-first orchestration and production gate.

### NOT in this plan

- Application source changes in DesignFlow, shared-db, popdam, oracle, or other
  sibling repositories, except a narrowly required Ansible change for `hetz`
  machine management.
- Shared Supabase structure/data changes, production Terraform, mutating `gcloud`,
  or direct application deployment.
- Reading or quoting raw transcript contents. History repair works by paths and
  object identity only.
- Credential rotation without separate explicit evidence that a live credential
  is exposed. Existing exposed credentials remain treated as compromised.
- Weakening reviewer read-only, exact-head, model, cost, permission, or completion
  safeguards to make qualification pass.
- Synchronizing Codex's live SQLite memory databases.

## 5. Current state of the code

- Audit commit `e3330c08d48c0bb012a6eabfdc49ac0113c88fd7` is on `main`.
- The governing plan/audit/handoff were published on `origin/main` in commit
  `0b495562453909bd6da6b64ee845e6d3e4987892`; scheduled memory commits continue
  to advance `origin/main`, so every phase must fetch and reconcile again.
- The working tree was clean before plan work. Other sessions own the separate
  Gemini and Grok repair checkouts named in their handoffs; never overwrite them.
- Shared reviewer evidence, DeepSeek, and most Grok repairs are integrated in a
  combined local lineage and documented as complete locally, but exact-head
  review/push/live qualification status must be re-derived from current `main`.
- Codex, Kimi, Muse, Qwen, and GLM provider plans still have open source steps.
  Gemini requires live hostile qualification on Windows and Ubuntu.
- `bugs.md` still contains the pre-debate 4/14/10 counts, the incorrect 44,700
  installed-context figure, and a remedy to add secret scanning even though
  GitHub secret scanning and push protection are already enabled.
- The Windows canonical-route docs disagree. `install.sh` suppresses required
  failures. `uninstall.sh` lacks a recoverable manifest-driven path. Doctor
  checks presence more often than effective capability.
- There is no `.github/workflows/` verification workflow or single supported
  command that runs the whole offline suite.
- `docs/deployment.md` correctly says this toolkit has no application deployment;
  CI added here verifies the repository but does not build or deploy a container.

## 6. Key findings and root causes

1. **Rules without an enforcement owner drift.** The repository documents many
   excellent constraints, but no CI or server-side branch rule makes them true.
2. **The memory algorithm confuses absence with deletion.** Machine-local indexes
   are treated as whole authoritative replacements instead of union inputs; the
   unattended wrapper pushes before it reconciles.
3. **Failure paths lie.** Several installers, reviewer wrappers, and sync paths
   convert a missing artifact or nonzero child into warnings followed by success.
4. **One public repository owns both reusable code and private machine facts.**
   `.gitignore` cannot protect data already committed or an automated writer.
5. **Reviewer lifecycle logic is duplicated.** Provider wrappers implement
   identity, locks, evidence, freshness, quarantine, and publication differently,
   while the central governance commands are optional.
6. **The staged pipeline is documentation plus disconnected scaffolding.** Its
   artifacts do not line up, shipped model flags are stale, and review stages call
   the wrong implementation.
7. **Recovery protects existing config by never evolving it.** This prevents
   clobbering but also prevents required schema migrations and trustworthy restore.
8. **Tests often prove source text exists rather than behavior.** The clearest
   example is `tests/test-ai-memory-sync.sh`, which calls the destructive reset a
   guard and passes because the bug is present.

## 7. Approaches considered and REJECTED, and why

1. **Leave automatic memory publishing in the public repo and improve the regex.**
   Rejected: credentials are only one kind of private fact; customer names,
   topology, schema details, and novel secret formats bypass pattern lists.
2. **Disable cross-machine memory permanently.** Rejected: that deletes an
   intended working capability instead of repairing it. The hub moves private.
3. **Treat every machine's `MEMORY.md` as last-writer-wins.** Rejected: absence is
   not a deletion. Only an explicit tombstone may remove an index entry or fact.
4. **Back up the public history in another unencrypted public/private GitHub repo.**
   Rejected: the backup contains material already classified as credential-bearing.
   The recovery copy must be local, user-only, and excluded from all sync.
5. **Create a replacement public repository.** Rejected: it discards issues,
   settings, URLs, and continuity. Use a coordinated recoverable history rewrite.
6. **Retire broken reviewers or the seven-stage pipeline as the fix.** Rejected by
   the standing capability-preservation rule. Existing provider tools remain
   available; the pipeline is completed; unsupported providers are advisory until
   qualified rather than falsely approval-capable.
7. **Repair all eight reviewer wrappers as separate approval systems.** Rejected:
   it preserves the duplication root cause. Claude Opus 5 and Codex become the two
   supported approval adapters over one lifecycle; other providers remain useful
   advisory/debate adapters governed by the same evidence and quarantine core.
8. **Add container/GHCR/Coolify deployment.** Rejected: this repository produces
   scripts installed from Git. CI verifies source; installation is deployment.
9. **Require pull requests on `main`.** Rejected: the repository's locked workflow
   is main-only with concurrent direct pushes. Protect deletion/force-push and make
   CI visible without inventing a conflicting branch model.
10. **Use broad secret/content inspection on transcripts.** Rejected: raw archives
    are out of normal context. Purge by path/object and verify absence mechanically.

## 8. Design decisions already made (2026-08-21)

### LOCKED — do not relitigate

- **D1:** Treat memory oscillation as an active incident. Halt writers before
  repair; preserve evidence; rebuild; test; resume only after production proof.
- **D2:** Create private repository `u2giants/ai-devops-memory` as the portable
  Markdown memory source of truth. The public toolkit contains only scripts,
  schema/docs, and a pointer; no unattended AI-to-public commits remain.
- **D3:** Preserve the seven-stage capability and finish it end to end. Do not
  satisfy the fix by deleting the advertised workflow.
- **D4:** Supported approval paths are Claude Opus 5 and Codex through one shared
  lifecycle. Grok, GLM, Kimi, Qwen, Muse, Gemini, and DeepSeek remain installed
  advisory/debate capabilities and may become approval-capable only after the
  same hostile qualification contract passes.
- **D5:** Keep the existing public GitHub repository and perform a coordinated
  history rewrite. A protected local mirror/bundle makes the operation recoverable.
- **D6:** Secret scanning and push protection already exist. Do not waste work
  “adding” them; add the missing CI, ruleset, and local full-suite runner.
- **D7:** Use explicit, allowed model settings. The verified Claude model is
  `claude-opus-5`; GPT-5.6, wherever used, must specify `low` or `medium`.
- **D8:** The machine configuration owner remains outside the repo. Migrations
  are versioned, previewable, backed up, atomic, and validated; no real secret or
  `.env` value enters Git.
- **D9:** `hetz` host/OS/task changes route through `u2giants/ansible`. GitHub is
  source of truth; no permanent server hand edits.

### OPEN only for implementation judgment

- Exact internal function boundaries and file names may change when current
  source makes a smaller solution possible, provided the behavior and gates below
  remain intact.
- A provider that cannot complete a bounded live hostile test remains advisory;
  the implementation must not purchase extra allowance or weaken controls merely
  to change its label.

## 9. The plan — numbered, ordered, executable steps

### Phase A — freeze the incident and correct the controlling record

#### Step 0 — publish the governing plan and corrected audit

Targets: this plan, its linked handoff, `bugs.md`, `AGENTS.md`, issue #62.

- Add the negotiated 3/14/13 summary and two new findings to the top audit.
- Correct #3, #10, #16, and #18 severities; correct the 21,808-byte installed
  context measurement; remove the nonexistent “add secret scanning” task; narrow
  #9; record transcript object classes accurately.
- Add #29 (unattended AI-to-public memory publishing) and #30 (shipped model
  configuration removes the explicit Codex reasoning guardrail).
- Link this plan from the audit and repository router. Update issue #62 with the
  committed plan link.

**Gate:** `rg` shows every finding exactly once in the live summary; counts add to
30; Markdown links pass; the plan/handoff link to each other; the plan commit is
present on `origin/main`.

#### Step 1 — halt and preserve the live memory incident

Targets: the scheduled memory job on `albt16`, `edge-dev`, `al8960ofc`, and
`hetz`; `bin/install-memory-sync-task.ps1`, Linux scheduling owner, issue #62
evidence. No source fix is deployed yet.

- Enumerate exact scheduled task/timer names with read-only commands and record
  enabled state, last result, and last run without printing environment values.
- Disable only the identified automatic writer on each host. On `hetz`, make the
  durable change through Ansible; a temporary incident stop may use the existing
  service manager only if recorded and immediately represented in Ansible.
- Fetch `origin/main`, record the oscillating commit sequence and current indexes,
  and copy the machine-local memory trees into user-only incident directories.
- Do not run push, pull, reset, or cleanup while collecting evidence.

**Gate:** two former schedule intervals pass with no new `memory sync from …`
commit; each machine's backup path and task state are recorded in
`tests/verification/full-remediation/<UTC>/memory-containment.md`; no memory file
was deleted.

### Phase B — rebuild memory as private, lossless infrastructure

#### Step 2 — create the private hub and rebuild authoritative state

Targets: new private GitHub repo `u2giants/ai-devops-memory`, `memory/README.md`,
`docs/config-inventory.md`, `docs/configuration.md`, machine-local config schema.

- Create the repo as private and verify visibility with `gh repo view`.
- Build the union of all fact files and all index entries from the public tree,
  protected incident copies, and explicit tombstones. Create indexes for
  `directus`, `plane`, and `twenty`; index every orphan; never infer deletion from
  absence.
- Run a content detector that reports only filenames/counts. Any credential-like
  hit blocks publication and is remediated through 1Password without displaying
  values.
- Commit the safe union to the private hub. Replace the public `memory/` content
  with a short architecture/readme pointer and schemas/tests only.

**Gate:** private visibility is confirmed; `ai-memory-health` reports zero
missing indexes, zero dead index entries, and zero unresolved secret-pattern
hits; an unauthenticated clone of public `ai-devops` cannot obtain the new hub.

#### Step 3 — repair synchronization and its tests

Targets: `bin/ai-sync-memory`, `bin/ai-memory-sync`, scheduled-task installers,
`skills/claude/sync-dotfiles`, `skills/codex/codex-sync-dotfiles`,
`tests/test-ai-memory-sync.sh`, new private-hub fixtures.

- Make the hub location explicit and validate it is private before any automated
  push. Scheduled jobs use the private hub only.
- Union-merge `MEMORY.md`; only tombstones delete. Block index shrink and run
  health before commit.
- Preserve a failed/rejected commit and exit nonzero. Never reset/pull/copy older
  state after a failed push or rebase. Offline/fetch failure is nonzero and
  observable. “Sync complete” is emitted only after verified success.
- Scope content scanning to the outgoing diff while retaining a full private-hub
  health sweep. A block must be visible in job status and logs.
- Replace the 23-line source-text test with behavioral two-machine, concurrent,
  offline, rejection, rebase-conflict, tombstone, orphan, and rollback fixtures.

**Gate:** failure injection proves the only copy survives every failure; a
two-machine round trip converges to the union; no job can target the public repo;
the scheduler remains disabled until Step 16.

#### Step 4 — correct dangerous instructions and the audit record

Targets: stale `memory/dflow*` records in the private hub,
`skills/claude/claude-transcript-backup/SKILL.md`, `docs/transcripts.md`, audit
fixtures and reference scans.

- Remove the nonexistent preview database reference and every authorization for
  app-owned startup schema changes. Deduplicate `dflow-plm`/`dflow_plm` through
  an explicit alias/migration, not two live copies.
- Put transcript-skill frontmatter on line 1, target only the private transcript
  repository/submodule, and refuse the public repo by canonical remote identity.
- Keep volatile shared-database procedure in its governed skill; memory stores
  durable facts only.

**Gate:** stale project refs and forbidden migration wording are absent outside
dated incident evidence; hostile transcript destinations fail before copying;
the skill registers in both installer/trigger checks.

### Phase C — make restore, configuration, and removal honest

#### Step 5 — repair Ubuntu install/update and Node handling

Targets: `install.sh`, `update.sh`, `setup-secrets.sh` call boundary,
`docs/deployment.md`, `docs/restore-from-zero.md`, installer tests.

- Introduce an explicit stage runner with required/optional classification,
  per-stage result, final summary, and truthful exit code. Skills, Git identity,
  config, memory, secrets required by the chosen mode, and doctor may not be
  discarded.
- Detect/install/verify `node`, `npm`, and `npx` independently of unrelated
  dependency checks.
- Keep idempotent non-overwrite behavior for real config, but call the versioned
  migration/validation owner from Step 7.
- Make `update.sh` report the exact source SHA it installed.

**Gate:** each required stage is forced to fail in isolation and makes install
nonzero without corrupting prior state; optional failures are named warnings;
Node-present/Node-missing fixtures pass; a disposable Ubuntu restore passes.

#### Step 6 — repair Windows source, ACL, and configuration behavior

Targets: `bin/bootstrap-windows-dev.ps1`,
`bin/install-ai-devops-windows.ps1`, `bin/setup-machine.ps1`,
`docs/windows-winget-configuration.md`, Windows tests.

- Before machine changes require a clean checkout, canonical GitHub remote,
  branch `main`, successful fetch, and exact equality with `origin/main`; check
  `$LASTEXITCODE` immediately after every native command.
- Make `bootstrap-windows-dev.ps1` the single public restore entry point. Label
  component installers internal/advanced and use `C:\repos\ai-devops`
  consistently.
- For tokens and private keys: create a user-only temporary path, write, harden,
  read back the effective ACL, then publish atomically. Any ACL failure is fatal.
- Parse live JSON before backup/write. Never overwrite the last known-good backup;
  never replace malformed live JSON. Produce an exact recovery command.

**Gate:** wrong remote/branch, dirty tree, failed fetch/pull, failed `icacls`,
malformed JSON, second-run backup, and atomic-publication fixtures all fail closed;
the existing good state remains byte-identical.

#### Step 7 — version configuration, uninstall safely, and strengthen doctor

Targets: `config/*.env.example`, a new secret-free config schema/migrator,
`uninstall.sh`, install manifest, `bin/ai-devops`, configuration/inventory docs.

- Add a versioned, merge-based config schema. Preview migrations, back up with
  restrictive permissions, add required safe defaults without replacing user
  values, validate commands, and record applied schema/source SHA.
- Generate a managed-artifact manifest during install. `uninstall.sh --dry-run`
  reports exact owned targets; destructive modes archive config first, validate
  ownership and resolved paths, and distinguish minimal/full removal.
- Doctor reports repo SHA, installed SHA, config schema, managed artifact hashes,
  skill/global drift, scheduled-job state, every active provider, Node/npm/npx,
  and bounded command capability. It must distinguish optional, advisory, and
  required failures in one machine-compliance result.

**Gate:** old config migrates without losing custom values; invalid config is
untouched; uninstall preview writes nothing; archive-based rollback restores all
managed state; doctor detects a deliberately stale launcher and unsafe model
command.

### Phase D — create the enforcement layer and reproducible restore proof

#### Step 8 — add the full test runner, GitHub CI, and server-side rules

Targets: `tests/test-all.sh`, `tests/test-all.ps1`,
`.github/workflows/verify.yml`, `docs/development.md`, GitHub ruleset.

- Discover supported test files deterministically and run Bash tests with Git
  Bash on Windows. Run PowerShell tests with PowerShell 7. Keep provider-paid/live
  tests out of offline CI and list them as explicit release gates.
- Add Linux and Windows jobs for syntax, offline behavior, context audit, link/
  citation checks, secrets/path policy, and installer smoke fixtures. No workflow
  deploys or mutates machines.
- Add concurrency cancellation for superseded CI without hiding failures.
- After the history rewrite, create a GitHub ruleset that blocks force-push and
  branch deletion while retaining direct-to-main policy. Record the ruleset JSON.

**Gate:** one local command and one workflow run execute the same declared suites;
CI fails on a seeded known-bad fixture; force-push and branch deletion are denied
after Step 15.

#### Step 9 — harden the shared reviewer lifecycle

Targets: `bin/ai-review-sandbox`, `bin/ai-review-packet`,
`bin/ai-review-preflight`, `bin/ai-review-scoreboard`,
`bin/ai-reviewer-issue`, a new/reused provider-neutral lifecycle module, tests.

- Fail closed on diff generation and every untracked-file copy. Remove a partial
  snapshot on failure.
- Compute a NUL-safe whole-source digest before/after snapshot creation; retry
  once on change, otherwise stop. Bind report/evidence identity to that digest.
- Centralize normalized upstream identity, locks, preflight/quarantine, running
  and terminal state, verdict/report publication, scoreboard append, and exact
  incident join fields. Provider adapters only invoke and parse providers.
- Preserve completed packet, outside-link, incident-correlation, and fail-closed
  freshness repairs already documented in their plan; import rather than overwrite
  another session's work.

**Gate:** hostile unreadable, disappearing, long-path, outside-link, mid-copy
mutation, failed-diff, duplicate-lock, stale-evidence, and wrong-run fixtures pass;
no provider can bypass preflight or omit terminal accounting.

#### Step 10 — complete provider repairs without multiplying approval gates

Targets: the nine provider plans named in `bugs.md`, their wrappers/tests/skills,
and provider verification directories.

- Re-derive current status from `main`; merge already-complete shared evidence,
  DeepSeek, Gemini, and Grok source safely if not present.
- Complete Codex change capture, read-only sandboxing, exact verdict/failure, and
  collision-proof atomic reports.
- Complete Kimi normalized upstream lock and friendly missing-job behavior;
  preserve quarantine unless its exact completion record returns.
- Complete Muse exact destination, pre-call state/progress, caller identity;
  Qwen exact evidence generation; GLM start-readiness.
- Run bounded live hostile qualification only where access already exists. Never
  weaken controls or invent unavailable provider metadata.
- Mark all non-Claude/Codex providers advisory by default. Their commands and
  debates remain available, but they cannot satisfy a required approval gate.

**Gate:** every provider plan STATUS table cites reproducible artifacts; all
offline tests pass; live-qualified providers have exact model/session/head and
read-only evidence; unqualified providers fail visibly as advisory/quarantined.

#### Step 11 — complete the seven-stage workflow and safe model configuration

Targets: `bin/ai-run-task`, `bin/ai-model-call`, repaired shared review command,
`config/models.env.example`, `templates/prompts/01..07`,
`skills/claude/ai-development-pipeline/SKILL.md`, architecture/model docs/tests.

- Use one run manifest with immutable stage inputs/outputs, source SHA/digest,
  timestamps, model identity, status, and resume rules. Every stage consumes the
  prior named artifact rather than searching generic plan paths.
- Use role-based stage names. Claude Opus 5 owns independent plan/diff/security/
  final reviews; Codex owns implementation/testing and the second supported
  review adapter. Both use the shared lifecycle and exact verdict contract.
- Separate safe review commands from workspace-write implementation commands.
  Shipped/default config may not remove explicit sandbox or allowed reasoning.
- Update stale Opus/GPT labels only after live capability probes. Add a test that
  installs the example and asserts the effective run header/model/effort.
- Make resume/retry idempotent and refuse stale source without a new evidence
  generation.

**Gate:** a scratch repository completes all seven stages; every artifact points
to the exact previous artifact and source identity; a denied/failed stage blocks
later stages; the final report identifies Claude Opus 5 and the allowed Codex
effort/sandbox.

#### Step 12 — pin restore inputs and prove reproducibility

Targets: `.config/configuration.winget`, package/tool catalogs, model/provider
version files, installers, restore docs, verification artifacts.

- Pin security-sensitive runtimes and wrapper dependencies to tested versions or
  a governed version catalog. Keep upgrade cadence explicit and tested; eliminate
  uncontrolled `latest` from recovery-critical paths.
- Run the canonical Windows bootstrap on a clean disposable Windows 11 machine,
  reboot/rerun if requested, then run it a second time without changes. Capture
  non-secret reports.
- Run Ubuntu restore from a clean disposable host/container appropriate to the
  installer's system assumptions, then repeat for idempotency.

**Gate:** first run reaches compliant state; second run has no unintended change;
both doctor reports identify the same release SHA and configuration schema.

### Phase E — context, skill, policy, and privacy cleanup

#### Step 13 — repair context, triggers, repository policy, and portable facts

Targets: `tools/context-audit/*`, compact context spec/router,
`tools/skill-trigger-eval`, high-risk skill eval sets,
`bin/ai-workspace-status`, new repo-policy contract, new `bin/ai-facts` and Codex
skill, context/skills docs.

- Report/budget effective installed global bytes when homes are supplied; use the
  corrected baseline 21,808 bytes on the audit machine. Ratchet future growth
  without rewriting machine sections.
- Route context work to a compact current specification and the closed plan's
  STATUS only; generate measured tables from audit JSON rather than copied prose.
- Add committed trigger evals for every high-risk/long description and require an
  eval update on description changes. Measure multiple runs/platforms; never
  interpret one stochastic score as a verdict.
- Add a small repository-policy contract consumed by workspace/pipeline tools so
  main-only repos do not receive feature-branch advice. Fetch before calling
  remote state current.
- Add read-only client-neutral fact search/index access and a Codex trigger. The
  command reads the private Markdown hub but never syncs Codex SQLite.

**Gate:** strict audit reports correct installed bytes and no unapproved growth;
all high-risk skills have passing precision/sensitivity evidence; workspace
status gives correct main-only advice from fresh remote state; Codex retrieves a
known portable fact through the read-only command.

#### Step 14 — remove public topology and close transcript ingestion

Targets: `config/ssh-config.template`, `templates/system/machine-atlas.md`,
`README.md`, `docs/config-inventory.md`, `docs/headroom.md`, transcript skills,
private configuration source.

- Move hostnames, IPs, usernames, project identifiers, and recovery topology that
  are not required by the reusable public engine into protected machine/private
  inventory. Public templates use placeholders/schema only.
- Generate machine SSH/config from the protected source and verify canonical
  destinations before writing.
- Make public documentation say the repository is public and describe historical
  exposure accurately until Step 15 proves purge.
- Test every transcript tool/skill against public and lookalike remotes; only the
  private transcript destination is accepted.

**Gate:** a public-tree policy scan reports no concrete protected topology; setup
can regenerate required real configuration from protected sources; transcript
hostile tests cannot write to `ai-devops`.

### Phase F — history repair, production installation, and closeout

#### Step 15 — rewrite public history recoverably

Targets: a disposable mirror, protected local backup/bundle, GitHub `main`, every
clone/worktree, GitHub caches/support as needed.

- Freeze writers and require a clean, fully pushed source state. Record all refs,
  submodules, issues, releases, and current SHA.
- Create a full mirror and bundle under a new user-only local incident directory;
  verify it can restore the pre-rewrite refs. Never sync or publish this backup.
- In a second disposable mirror use `git filter-repo` to remove transcript paths,
  retired public memory content, and identified private-topology paths from all
  reachable refs. Do not inspect raw transcript contents.
- Verify path/object absence and repository integrity, then force-update the exact
  approved refs once. Immediately establish the no-force/no-delete ruleset.
- Reclone/repoint every managed checkout; do not merge unrelated old history into
  the rewritten line. Ask GitHub Support to clear cached objects where applicable.

**Gate:** the protected backup restores in an isolated test; an unauthenticated
fresh clone finds zero prohibited paths/objects; GitHub rules are active; all
managed checkouts share the rewritten `origin/main` ancestry.

#### Step 16 — install and verify production on every machine

Targets: `albt16`, `edge-dev`, `al8960ofc`, `hetz`, plus any additional active
managed host discovered by the scheduler/config inventory.

- Use the canonical Windows bootstrap on Windows, and the repo/Ansible-owned
  install route on Ubuntu. Back up machine config before migration.
- Verify source SHA, installed launcher hashes, config schema, skills/globals,
  provider status, Node, Git identity, memory hub visibility, and doctor result.
- Re-enable the repaired memory schedule one machine at a time. Observe two
  cycles before enabling the next; verify union state never shrinks and no public
  repo commit is created.
- Run a bounded seven-stage canary in a scratch repo from installed commands.

**Gate:** every machine has a PASS compliance record tied to one release SHA;
private memory converges over two cycles; `origin/main` receives no automated
memory commit; restore documentation reproduces the installed state.

#### Step 17 — exact-head review, final CI, and closeout

Targets: exact `origin/main` head, `.ai/reviews/`, issue #62, plan STATUS,
handoff retention, final documentation.

- Run the full local suite and final GitHub workflow on the exact candidate.
- Obtain an independent read-only Claude Opus 5 review of exact head, including
  security/history/install evidence. A review finding is fixed and re-reviewed;
  stale approval cannot be reused.
- Update all affected docs and plan rows with artifact-backed evidence. Delete
  this session's handoff only after all obligations are complete and pushed.
- Close issue #62 only after origin, GitHub rules, history, machine installs,
  memory cycles, and canary evidence all agree.

**Gate:** clean working tree; intended commit on `origin/main`; green final CI;
exact-head approval; issue #62 closed; no open obligation remains.

### Finding-to-step coverage

| Finding | Owning step(s) |
|---|---|
| 1 public transcript history | 14, 15 |
| 2 active index deletion loop | 1, 2, 3, 16 |
| 3 stale database/migration memory | 4 |
| 4 failed push destroys commit | 1, 3 |
| 5 Ubuntu false success | 5 |
| 6 Windows unverified source | 6 |
| 7 conflicting Windows restore routes | 6 |
| 8 no CI/server-side gate | 8, 15 |
| 9 reviewer snapshot omission | 9 |
| 10 mixed-state snapshot race | 9 |
| 11 Codex reviewer trust | 10, 11 |
| 12 provider identity divergence | 9, 10 |
| 13 unconsumed reviewer governance | 9, 10 |
| 14 disconnected seven-stage pipeline | 11 |
| 15 transcript skill public route | 4, 14 |
| 16 installed-context undercount/debt | 13 |
| 17 Windows ACL/config fail-open | 6 |
| 18 public topology | 14, 15 |
| 19 unpinned restore inputs | 12 |
| 20 config not migrated/backed up | 7 |
| 21 incomplete/destructive uninstall | 7 |
| 22 thin skill-trigger coverage | 13 |
| 23 stale oversized context route | 13 |
| 24 generic branch guidance conflict | 13 |
| 25 provider availability/evidence blind spots | 9, 10 |
| 26 Codex cannot consume portable facts | 13 |
| 27 presence-only doctor | 7, 16 |
| 28 Node/npm conditional defect | 5 |
| 29 unattended AI-to-public memory publishing | 1, 2, 3, 15, 16 |
| 30 shipped config removes reasoning guardrail | 7, 11 |

## 10. Tests required

The test names below are required behaviors, not optional suggestions:

- Replace `tests/test-ai-memory-sync.sh` with behavioral fixtures for union,
  tombstone, conflict, offline, failed push, preserved commit, no-public-remote,
  secret-block visibility, and two-machine convergence.
- Extend `tests/test-ai-review-sandbox.sh` for failed diff, failed copy,
  disappearing file, long path, outside link, partial cleanup, and source-digest
  mutation/retry.
- Add/complete `tests/test-ai-codex-review.sh` and the provider suites named in
  their plan STATUS tables.
- Add installer failure-injection tests for every required stage; Node/npm/npx;
  wrong branch/remote; native command exit; malformed JSON; ACL verification;
  config migration; managed uninstall; and exact-sha doctor.
- Add `tests/test-ai-run-task.sh` for the seven-stage artifact graph, resume,
  stale source, role/model mapping, denied stage, and final exact-head verdict.
- Add `tests/test-ai-facts.sh`, repository-policy fixtures, installed-context
  byte tests, and trigger-eval coverage-policy tests.
- Add transcript destination and public-topology policy tests that compare
  canonical remotes/paths rather than names alone.
- Add `tests/test-all.sh` and `tests/test-all.ps1`; both emit a machine-readable
  manifest/result and run zero paid provider calls.

Existing required suites in `docs/development.md` remain green. Bash tests on
Windows use `C:\Program Files\Git\bin\bash.exe`; PowerShell uses `pwsh
-NoProfile`. Run `bash -n` on every changed Bash script, PowerShell parser checks
on every changed `.ps1`, `git diff --check`, the citation/link checker, strict
context audit, and secret/path scans. Live provider and clean-machine tests are
release gates with artifacts, never hidden inside offline CI.

## 11. Constraints, standing rules, and gotchas in force

- Work directly on `main`; do not create a feature branch in this repo. Several
  sessions share it: fetch/reconcile before every commit and stage only owned
  paths/hunks.
- Before every commit, `git var GIT_COMMITTER_IDENT` must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Use `apply_patch` for hand-written edits. No destructive reset/checkout over
  unreviewed work. Every deletion/history rewrite has a verified recovery copy.
- This repository is public. Never open raw transcript JSONL or print secret
  values. 1Password vault is `vibe_coding`; access is serialized.
- GPT-5.6 uses explicit `low` or `medium` only. Prove live model/provider access
  before changing a model pin.
- Preserve intended capabilities. Quarantine/advisory status is honest safety,
  not permission to delete a tool.
- Reviewer safety-path changes require a read-only independent exact-head final
  review before merge/push completion.
- Production/shared database changes are out of scope. No `terraform apply`,
  mutating production `gcloud`, or app-owned shared schema migrations.
- `hetz` host state belongs to Ansible; applications belong to Coolify. This repo
  has no application CI/CD deployment.
- Do not normalize line endings or replace OS binaries incidentally. On Windows,
  use Git Bash for Bash suites and the supported project/client install paths.
- The history rewrite changes every descendant SHA. It is the last broad Git
  operation, uses an isolated mirror, and is followed by fresh clones—not merges
  from old ancestry.

## 12. Access and environment

- Current checkout: `C:\repos\ai-devops`, branch `main`, public GitHub repo
  `u2giants/ai-devops`, issue #62.
- GitHub CLI is authenticated as `u2giants` with repository/workflow access.
- Claude Code 2.1.211 is authenticated through `u2giants@gmail.com`; a live probe
  resolved `--model opus` to canonical `claude-opus-5`.
- Current host is `albt16` (`ahazan2`, Windows 11, PowerShell 7). Git Bash is at
  `C:\Program Files\Git\bin\bash.exe`.
- Other observed active memory hosts: `edge-dev`, `al8960ofc`, `hetz`. Use the
  managed SSH/Ansible inventory; do not paste keys or copy SSH binaries.
- 1Password vault: `vibe_coding`. Relevant items are referenced by documented
  titles only; values never enter plans, logs, command arguments, or Git.
- Machine config: Windows under `%USERPROFILE%`/managed app paths; Ubuntu under
  `/etc/ai-devops/`. Back up before changing in place.
- Verification artifacts belong under
  `tests/verification/full-remediation/<UTC>/` and must contain no secrets.

## 13. Definition of done + risks and open questions

### Definition of done

- All 17 implementation steps are complete with artifact-backed STATUS cells.
- All 30 findings map to a passing behavior test and/or live verification gate.
- `bugs.md` holds the negotiated counts and repair status; no stale operational
  instruction contradicts the repaired code.
- One offline full-suite command passes locally and in Linux/Windows GitHub CI.
- Force-push and branch deletion are blocked after the coordinated rewrite.
- Public history no longer contains transcript, retired public memory, or private
  topology objects; a clean unauthenticated clone proves it.
- Private memory converges without index shrink or public commits on every host.
- Windows and Ubuntu fresh/idempotent restore gates pass.
- Claude Opus 5 and Codex approval paths pass the shared lifecycle contract;
  every other provider is truthfully advisory/quarantined or separately proven.
- The seven-stage installed canary completes from one exact source revision.
- Final exact-head independent review passes, the commit is verified on
  `origin/main`, issue #62 is closed, and the open handoff is retired.

### Principal risks and rollback

- **Memory loss:** writers remain halted; protected per-machine copies plus the
  public snapshot remain until two private-hub cycles pass. Roll back by restoring
  the union and leaving schedules disabled.
- **History rewrite:** verify a user-only full mirror/bundle before any force
  update. Roll back by restoring refs from that backup before rules are finalized.
- **Concurrent main changes:** fetch before each commit; rebase only owned commits;
  never reset shared work. Stop a history cutover if any writer is active.
- **Provider cost/availability:** paid/live calls are bounded and recorded. A
  failure leaves the provider advisory; it does not block unrelated core repairs.
- **Machine lock/reboot:** Windows setup may require fully closing Codex/Claude or
  rebooting. Preserve reports and resume the same idempotent bootstrap.
- **Private-hub access on fresh restore:** GitHub authentication is an explicit
  restore boundary. A machine without access installs the public toolkit but
  reports portable memory unavailable rather than silently succeeding.

### Open questions

None require Albert before work starts. The user explicitly authorized rewriting
the plan, implementing every fix, shipping to production, and continuing until
the outcome is complete. Implementation judgments have deterministic gates in
§8–§9; any genuinely new irreversible external scope not listed here must be
raised rather than assumed.

## Mandatory plan self-audit — passed 2026-08-21

1. **Could a brand-new AI session execute this plan without asking anything? —
   Yes.** Sections 1–8 define the goal, system, incident, scope, state, evidence,
   rejected approaches, and locked choices. Section 9 gives exact files,
   dependencies, behavior, and a verification gate for every step. Sections
   10–13 define tests, constraints, access, rollback, and completion.
2. **Does the plan carry every material nuance and rejected path? — Yes.**
   Section 6 records the eight root causes; §7 preserves ten rejected shortcuts;
   §8 resolves the memory destination, pipeline, reviewer surface, history route,
   model, config, and machine-ownership decisions; the coverage table maps all 30
   findings with no orphan.
3. **Is the ultimate goal clear enough to guide a correct judgment when a step is
   wrong? — Yes.** Section 1 states the business outcome and makes truthful,
   recoverable, capability-preserving behavior outrank any literal step. Section
   13 supplies risk-specific rollback rules and the boundary for new authority.

Checklist result: all 13 required sections are present; the status table and
fresh-session start are at the top; plan/handoff links are reciprocal; out of
scope, locked/open decisions, named tests, access, secrets boundary, commit/push/
CI/install verification, risks, and rollback are explicit. No checklist gap
remains.
