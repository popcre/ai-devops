# Repository-wide strategy audit — 2026-08-21

> **Implementation route:** the Codex/Claude Opus 5 debate corrected and expanded
> this audit to 30 findings. Execute only through
> [`plan_full-strategy-remediation.md`](plan_full-strategy-remediation.md); its
> STATUS table is authoritative while remediation is active. Step 0 updates the
> detailed severities, counts, measurements, and remedies below before behavioral
> changes begin.

Scope: the complete tracked `ai-devops` toolkit—recovery and machine setup,
memory, global instructions, skills and trigger quality, the staged AI workflow,
delegated reviewers, evidence handling, secrets, tests, documentation, and GitHub
controls. Raw transcript contents and third-party dependency internals were not
opened.

This is a read-only audit record. No behavior was changed. The older reviewer-only
audit remains below as historical evidence.

## Overall verdict

The repository has excellent instincts: recoverable installs, 1Password references
instead of plaintext credentials, private reviewer copies, explicit safety rules,
incident-driven tests, a clear context ownership model, and unusually careful
documentation. The problem is execution consistency. Several of the most important
controls are warnings or instructions rather than enforced gates, and the project has
invested far more in eight reviewer wrappers than in the core install, memory, test,
and seven-stage workflow paths.

Current findings after the independent Claude Opus 5 challenge and three-round
debate: **3 CRITICAL, 14 HIGH, and 13 MEDIUM** (30 total). The two new HIGH
findings are unattended AI-to-public memory publishing and shipped model config
that removes an explicit Codex reasoning safeguard.

| Strategy | Verdict | Main reason |
|---|---|---|
| Public/private boundary | Critical repair needed | Secret-bearing transcripts are still reachable in public Git history |
| Cross-machine memory | Active critical incident | Four machines are deleting/restoring safety-index entries about every 30 minutes; failed-push commits can also be destroyed |
| Database safety memory | Remediated 2026-08-21 | Stale procedure facts were tombstoned in the private hub, duplicate namespaces were merged, and governed skills remain authoritative |
| Ubuntu/Windows recovery | High-risk gaps | Multiple required failures can still end in a successful-looking install |
| Reviewer isolation/evidence | Strong design, incomplete enforcement | Private copies can omit or mix source states; providers implement lifecycle rules differently |
| Context ownership/routing | Strong foundation, medium measurement debt | Live context is undercounted and installed copies can drift; the corrected installed total is 21,808 bytes on the audit machine |
| Skills and trigger quality | Good measurement method, thin coverage | Only 8 of 58 skills have committed trigger evaluations |
| Secrets handling | Strong 1Password design | Windows ACL and malformed-config failures do not always fail closed |
| Test strategy | Many useful tests, no delivery gate | Tests exist, but no CI, no single full-suite command, and no protected main branch |
| Seven-stage AI workflow | Not production-ready | The advertised core is still disconnected v0.1 scaffolding |
| Automatic memory publishing | High-risk active path | Scheduled jobs publish AI-authored facts to this public repository without human review |

Severity meanings:

- **CRITICAL:** current exposure, destructive data loss, or instructions capable of
  sending work to the wrong production/shared system.
- **HIGH:** a restore, review, or safety gate can report success without trustworthy
  evidence, or the documented core strategy does not work end to end.
- **MEDIUM:** material maintainability, observability, reproducibility, or efficiency
  weakness that is not presently destructive by itself.

## Detailed findings

The following dividers preserve the original audit grouping for traceability.
The explicit **Current severity** line in each finding is authoritative after the
Claude Opus 5 debate.

## Originally rated CRITICAL

### 1. Secret-bearing transcripts are still reachable in the public repository history

- **Current severity: CRITICAL**

- Files: `docs/transcripts.md:3-5`, `AGENTS.md:32`, `.gitignore:78-82`
- Confidence: certain
- Evidence: `git rev-list --objects --all` finds **1,464** historical
  `claude_chats/` / `codex_chats/` blobs totaling about **1.25 GB uncompressed**;
  `git branch -a --contains 67866c8` includes `main` and `origin/main`. The local pack
  remains about 424 MB. The docs claim the files were “removed from all history,”
  but they remain in the ancestry a public clone receives.
- User-visible impact: old conversations that the incident record says contained live
  credentials remain downloadable. Rotation reduces credential risk, but does not
  remove business data, infrastructure details, licensed material, or personal data
  that may also be present. Fresh restores also download hundreds of megabytes of
  obsolete history.
- Required correction: plan a coordinated history rewrite or clean-repository cutover,
  remove the objects from GitHub caches with GitHub Support where needed, re-point all
  machines, and verify from a fresh unauthenticated clone before changing the claim in
  `docs/transcripts.md`. Do not inspect or republish transcript contents during repair.

### 2. Cross-machine memory sync knowingly drops index entries and auto-commits the loss

- **Current severity: CRITICAL — active incident and operational priority #1**

- Files: `bin/ai-sync-memory:129-146`, `bin/ai-memory-sync:65-105`,
  `memory/README.md:114-156`
- Confidence: certain; Git history shows the same index lines being removed and restored
  by four alternating machines (`albt16`, `edge-dev`, `al8960ofc`, and `hetz`) at
  roughly 30-minute cadence through 2026-08-21
- What happens: `ai-sync-memory` detects hub index entries missing on the current
  machine and prints “Pushing will drop them,” then copies the smaller local
  `MEMORY.md` over the hub anyway. `ai-memory-sync` runs that push before its pull,
  commits it automatically, and sends it to `main`.
- User-visible impact: fact files survive but become unreachable to recall. The loop
  periodically removes the index section containing 1Password and secret-handling
  safety facts, so this is a periodically disarmed safety control, not ordinary cleanup.
  The orphan count changed from **13** to **14** during the audit, further proving the
  state is actively drifting.
- Required correction: merge indexes as a union, permit removal only through a durable
  tombstone, block index shrink before commit, run `ai-memory-health` before every
  automatic push, and add a real two-machine round-trip test.

### 3. Indexed memory teaches the wrong database and a forbidden migration route

- **Current severity: REMEDIATED 2026-08-21** — the instruction was dangerous, but no
  wrong production write was proven to have occurred

- Former private-hub files: `memory/dflow/feedback_all_db_work_via_shared_db.md`,
  `memory/dflow-plm/shared-db-canonical-repo.md`, and the duplicate `dflow_plm`
  namespace. The governed shared-database skill remains the live authority.
- Confidence: certain
- What happens: indexed memory names preview project `<protected-retired-preview-ref>`; the
  current governed skill explicitly says that project does not exist and names
  `<protected-shared-preview-ref>`. Two duplicated memories also authorize app-owned startup
  schema changes, contradicting the current rule that every structural change starts
  in `shared-db`.
- User-visible impact: a future AI session can target the wrong environment or create
  schema drift while believing it is following durable company memory.
- Correction completed: tombstone the stale procedure memories,
  deduplicate the two project folders, keep volatile procedures in the governed skill
  rather than memory, and validate high-risk project references against one canonical
  source.

### 4. A failed memory push destroys the local commit it claims to preserve

- **Current severity: CRITICAL** — the active index oscillation continuously creates
  the push/rebase-conflict precondition, and the failure path is automatic,
  irreversible, and falsely reports success

- Files: `bin/ai-memory-sync:88-105`, `tests/test-ai-memory-sync.sh:1-23`
- Confidence: certain from the control flow
- What happens: after three failed pushes or a failed rebase, the script says the commit
  is kept locally. It then immediately hard-resets the isolated clone to `origin/main`
  and copies the older hub state back to the live machine. Child push/pull failures are
  also not consistently checked.
- User-visible impact: the newest learned facts can be lost precisely when the network
  or GitHub is unavailable, while the job ends with “Sync complete.”
- Required correction: never reset or pull unless the push succeeded; preserve the
  commit, exit nonzero with a visible alert, and add failure-injection tests rather than
  source-text-only assertions.

## Originally rated HIGH

### 5. Ubuntu install and update can finish successfully after required stages fail

- **Current severity: HIGH**

- Files: `install.sh:17`, `install.sh:70-86`, `install.sh:128-149`,
  `install.sh:159-178`, `install.sh:203-212`, `update.sh:27-28`
- Confidence: certain
- What happens: the installer does not stop on ordinary command failures. Required
  directory, config, skill, identity, memory, and doctor failures are either unchecked,
  downgraded to warnings, hidden, or forced to success. `update.sh` trusts that result.
- User-visible impact: a disaster restore can say “install.sh complete” while the
  machine is missing configuration, identity protection, skills, memory, secrets, or
  required health checks.
- Required correction: use an explicit stage runner; required stages fail the run,
  optional stages produce named warnings, and the final exit code reflects the summary.
  Never discard the doctor result.

### 6. Windows setup can continue from stale, dirty, wrong-branch, or failed Git state

- **Current severity: HIGH**

- Files: `bin/install-ai-devops-windows.ps1:426-436`,
  `bin/bootstrap-windows-dev.ps1:56-72`, `docs/windows-winget-configuration.md:59-62`
- Confidence: certain
- What happens: one installer does not check native Git exit codes. The main bootstrap
  preserves a dirty checkout and continues, never validates `origin` or `main`, and can
  pull whatever upstream the current branch uses.
- User-visible impact: a machine can be configured from obsolete or unreviewed local
  code while setup looks successful.
- Required correction: before any machine change, require a clean checkout, expected
  origin, `main`, fetched `origin/main`, and exact-head equality—or install from a
  separately verified snapshot. Check every native command immediately.

### 7. Windows has three conflicting “restore from zero” routes

- **Current severity: HIGH**

- Files: `README.md:30-56`, `README.md:195-205`,
  `docs/restore-from-zero.md:7-23`, `bin/bootstrap-windows-dev.ps1:75-141`
- Confidence: certain
- What happens: the top README uses the full bootstrap; a later README section uses the
  narrower Windows installer; the canonical restore guide uses only `setup-machine.ps1`.
  Only the bootstrap owns the full WinGet, provider, remote-access, and WSL/Ansible setup.
- User-visible impact: following two of the three official paths after a dead PC leaves
  required tools and remote administration incomplete.
- Required correction: publish one canonical entry point everywhere and label internal
  component scripts as non-restore commands.

### 8. Critical source-of-truth safeguards have no automatic or server-side gate

- **Current severity: HIGH**

- Files: `docs/deployment.md:8-16`, `docs/development.md:86-153`,
  `docs/critical-incidents.md:193-230`
- Confidence: certain; GitHub reports no branch protection/rules for `main`
- What happens: the repo has 44 test files but no GitHub Actions workflow and no single
  full-suite command. `main` also permits force pushes despite the recorded incident in
  which a force push silently dropped four commits.
- User-visible impact: broken recovery/safety code can become source of truth without a
  repeatable gate, and the exact destructive incident documented here is still allowed
  by GitHub.
- Required correction: add an offline Windows/Linux test matrix, one local `test-all`
  entry point, and a GitHub rule that blocks force-push and branch deletion while
  retaining the chosen main-only workflow. GitHub secret scanning and push protection
  are already enabled; do not duplicate them.

### 9. Shared reviewer copies can silently omit part or all of a change

- **Current severity: HIGH**

- Files: `bin/ai-review-sandbox:81-102`, `bin/ai-review-sandbox:114-145`,
  `tests/test-ai-review-sandbox.sh:1-170`
- Confidence: certain
- What happens: failed diff generation becomes an empty patch and failed untracked-file
  copies are warnings. The reviewer can receive a clean or incomplete copy. Stale
  cleanup alone is not fail-open because the following clone into a nonempty directory
  fails; that part of the original wording was withdrawn.
- User-visible impact: a reviewer can approve work it never saw.
- Required correction: fail closed on diff generation and every copy, remove every
  partial snapshot on failure, and add hostile unreadable, vanishing-file, and
  path-length tests.

### 10. Reviewer snapshots can combine two source states that never existed together

- **Current severity: MEDIUM** — the mechanism is real, but `git apply` stops the
  largest race variant and no occurrence was proven

- Files: `bin/ai-review-sandbox:114-145`, `bin/ai-kimi:1030-1039`,
  `bin/ai-grok-review:137-170`
- Confidence: high; changing bytes in an already-modified file leaves short Git status
  unchanged
- What happens: HEAD, tracked edits, and untracked files are read separately while other
  sessions may edit the shared checkout. Existing guards compare status labels, not
  path/type/content identity.
- User-visible impact: evidence and verdict can be attributed to a tree that was never
  a real version of the work.
- Required correction: compute a NUL-safe whole-source digest before and after snapshot
  creation, retry once, and otherwise stop. Store that digest in every review record.

### 11. Codex review lacked enforced read-only and truthful failure handling (fixed)

- **Current severity: RESOLVED**

- Files: `bin/ai-codex-review:26-30`, `bin/ai-codex-review:61-85`,
  `bin/ai-codex-review:138-159`, `plan_codex_reviewer_trust_repair.md:7-12`
- Confidence: certain from exact-head production reviews and hostile offline tests.
- Historical failure: it ran in the live repo without an enforced read-only sandbox,
  omitted untracked files, and could turn provider failures into misleading reports.
- Current outcome: Codex reviews use a complete private snapshot, sealed evidence,
  enforced read-only execution, exact terminal verdicts, unique atomic reports, and
  source/lifecycle verification. User-configured MCP launchers are excluded from the
  sealed review invocation so secret-bearing commands cannot enter terminal titles.

### 12. Qwen identity and freshness rules remain unresolved; Kimi is fixed

- **Current severity: HIGH**

- Files: `bin/ai-qwen:901-979`,
  `plan_qwen_reviewer_evidence_repair.md:7-12`
- Confidence: high
- What happens: Qwen can resume old reasoning after refreshing to new code without
  binding head/tree/packet identity. Qwen live qualification is skipped while account
  credits are exhausted.
- Kimi outcome: normalized upstream locking, durable session identity, installed live
  completion, and clone-deletion recovery are production-qualified; see
  `tests/verification/kimi-review-issue-46/2026-08-23-live.md`.
- User-visible impact: Qwen conclusions can cross code versions until its separate
  repair and later live qualification finish.
- Required correction: finish Qwen's source repair and keep it quarantined until live
  credits permit qualification; do not regress Kimi's proven identity schema.

### 13. Central reviewer governance exists but wrappers do not use it automatically

- **Current severity: HIGH**

- Files: `bin/ai-review-preflight:121-150`, `bin/ai-review-scoreboard:75-103`,
  `bin/ai-reviewer-issue:71-85`, `bin/ai-reviewer-issue:116-150`
- Confidence: certain
- What happens: provider wrappers do not consult the shared quarantine before contact or
  automatically append terminal outcomes. The scoreboard cannot represent normal dirty
  reviews reliably, and incident matching ignores provider-specific session fields.
- User-visible impact: quarantined providers can be retried, the performance ledger is
  partial, and failure packages can omit the exact run they were meant to preserve.
- Required correction: a shared lifecycle core must own preflight, normalized upstream
  identity, source digest, locks, in-progress/terminal state, report publication,
  scoreboard append, and incident join fields. Provider adapters should only contact the
  provider and parse its completion.

### 14. The advertised seven-stage pipeline is disconnected and uses unsafe defaults

- **Current severity: HIGH**

- Files: `skills/claude/ai-development-pipeline/SKILL.md:12-17`,
  `skills/claude/ai-development-pipeline/SKILL.md:32-50`, `bin/ai-run-task:39-68`,
  `bin/ai-codex-review:78-85`, `config/models.env.example:25-39`
- Confidence: certain
- What happens: Opus review stages call the Codex reviewer; `ai-run-task` writes a
  run-specific plan location that `ai-codex-review` never searches; orchestration and
  tests do not exist; and fresh Codex command examples omit the required explicit
  low/medium reasoning setting.
- User-visible impact: the repository’s headline workflow can review “no plan,” use the
  wrong reviewer, or start Codex with an unsafe unset effort.
- Required correction: either finish and test an artifact-linked end-to-end pipeline or
  demote it from the core strategy. Use role-based command names and keep model/version
  mapping in one config file with enforced safe effort/sandbox defaults.

### 15. The Claude transcript backup skill can route transcripts back into the public repo

- **Current severity: HIGH**

- Files: `skills/claude/claude-transcript-backup/SKILL.md:1-10`,
  `skills/claude/claude-transcript-backup/SKILL.md:34-49`, `docs/transcripts.md:15-19`
- Confidence: certain
- What happens: text before YAML frontmatter can prevent skill registration. The body
  says the private transcript repo is mandatory, then step 2 instructs cloning public
  `ai-devops` and copying into its retired `claude_chats/` path.
- User-visible impact: the exact credential exposure this repo previously suffered can
  recur.
- Required correction: put valid frontmatter first, target only the private submodule/
  repository, test the destination guard, and refuse every public repo target.

### 16. Context reporting understates what sessions actually load and allows measured debt to grow

- **Current severity: MEDIUM**

- Files: `tools/context-audit/context-audit.py:304-340`,
  `tools/context-audit/context-audit.py:584-592`, `tools/context-audit/budgets.json:19-22`,
  `docs/development.md:138-144`
- Confidence: certain from a live strict audit; the original installed-byte total was
  incorrect and has been withdrawn
- Evidence: templates total 13,813 bytes, while the two installed globals total
  **21,808 bytes** on the audit machine (`~/.claude/CLAUDE.md` 11,709 plus
  `~/.codex/AGENTS.md` 10,099).
  The audit reports drift but does not count installed bytes. It also currently warns on
  three budgets: startup router +474 bytes, Claude manifest +932, Codex manifest +7,679.
- User-visible impact: the headline savings describe source templates rather than the
  real startup payload, and Codex spends roughly 5,600 estimated tokens just learning
  which skills exist.
- Required correction: report and budget installed effective context when homes are
  supplied; introduce a ratchet that blocks new growth while grandfathering current
  debt; and shorten long descriptions only after trigger tests prove no regression.

### 17. Windows credential/config failures do not consistently fail closed

- **Current severity: HIGH**

- Files: `bin/setup-machine.ps1:256-262`, `bin/setup-machine.ps1:474-483`,
  `bin/setup-machine.ps1:557-568`
- Confidence: high
- What happens: token/private-key ACL failures are warnings and setup can still claim
  user-only access. Unreadable Claude Desktop JSON is backed up, replaced with `{}`, and
  rewritten, removing unrelated live settings.
- User-visible impact: sensitive files can retain broad inherited access and a malformed
  config can silently erase preferences/extensions.
- Required correction: write to a temporary file, harden and verify access, publish
  atomically only on success, and leave malformed live JSON untouched with an exact
  recovery path.

### 18. Public-repo documentation still exposes avoidable operational topology

- **Current severity: MEDIUM** — the values aid reconnaissance but do not grant access;
  the false statement about removed transcript history remains CRITICAL under finding 1

- Files: `README.md:99-111`, `docs/config-inventory.md:180-197`,
  `docs/headroom.md:41-73`, `config/ssh-config.template:1-190`
- Confidence: certain; GitHub reports the repo is PUBLIC while README line 101 says it
  is safe to keep private
- What happens: the public toolkit also stores company hostnames, public/Tailscale IPs,
  ports, user names, project identifiers, and recovery topology. These are not passwords,
  but they provide reconnaissance and make accidental confidential additions more likely.
- User-visible impact: unnecessary business/infrastructure detail is permanently public.
- Required correction: split the reusable public engine from a private machine inventory
  or generate the inventory at install from protected 1Password/private-repo data. Keep
  the public repository safe even when a future contributor misunderstands `.gitignore`.

## Originally rated MEDIUM

### 19. Restore output is not reproducible across time

- **Current severity: MEDIUM**

- Files: `.config/configuration.winget:4-64`, `bin/setup-machine.ps1:335-390`,
  `README.md:39-42`, `docs/windows-winget-configuration.md:11-16`
- Confidence: high
- What happens: Windows packages have no versions, several tools/MCPs resolve `latest`,
  and the complete Windows process has not passed the documented two clean-machine/
  idempotency runs.
- Improvement: pin security-sensitive runtimes, schedule deliberate upgrade tests, and
  keep disposable Windows plus Ubuntu restore smoke-test evidence.

### 20. Machine-local configuration is preserved but neither migrated nor backed up

- **Current severity: MEDIUM**

- Files: `docs/configuration.md:14-16`, `docs/configuration.md:86-90`,
  `docs/config-inventory.md:63`, `docs/restore-from-zero.md:89-92`
- Confidence: high
- What happens: existing config never receives new required keys, and a dead machine’s
  last working command settings are reconstructed manually. Doctor proves file presence,
  not schema or command capability.
- Improvement: use a versioned, secret-free merge format and protected per-machine
  overlays; doctor should validate schema, safe Codex effort, and real command ability.

### 21. Uninstall is incomplete and its destructive options have no recovery gate

- **Current severity: MEDIUM**

- Files: `uninstall.sh:40-76`, compared with installed state at `install.sh:118-198`
- Confidence: high
- What happens: uninstall removes only current symlinks, leaving managed skills, globals,
  launchers, memory automation, permissions, and services. `--purge` and `--remove-repo`
  recursively delete without a preview, archive, or confirmation.
- Improvement: drive uninstall from a managed-artifact manifest; add `--dry-run`, a
  timestamped config archive, exact ownership checks, and complete/minimal modes.

### 22. Trigger-quality tests cover too little of the skill catalog

- **Current severity: MEDIUM**

- Files: `tools/skill-trigger-eval/README.md:44-49`,
  `docs/skill-trigger-eval.md:149-182`, `skills/shared/shared-db-handover/SKILL.md:1-4`
- Confidence: certain
- Evidence: 8 committed eval sets for 58 tracked skill bodies (13.8%). High-risk and
  very long descriptions—including transcript, sync, closeout, pipeline, and many
  reviewer/scraper skills—have no committed trigger set.
- Improvement: require evals for high-risk or long descriptions and every description
  edit; measure more than one day and on both Windows/Linux where tools differ.

### 23. Context work routes through a closed 104 KB plan and stale copied measurements

- **Current severity: MEDIUM**

- Files: `AGENTS.md:48`, `docs/context-engineering.md:218-244`,
  `docs/context-engineering.md:479-490`, `plan_context-engineering-consolidation.md:3-25`
- Confidence: high
- What happens: a context-placement task is told to read both a 40 KB topic doc and a
  closed 104 KB implementation plan. Current measured numbers differ from copied prose,
  and one canonical path is visibly corrupted.
- Improvement: route to a compact current specification, archive the closed narrative,
  and generate measurement tables from the audit’s JSON instead of copying them into
  JSON, Python defaults, plans, and prose.

### 24. Generic branch guidance contradicts this repository’s main-only policy

- **Current severity: MEDIUM**

- Files: `AGENTS.md:17-23`, `bin/ai-workspace-status:92-107`,
  `skills/claude/ai-development-pipeline/SKILL.md:52-62`
- Confidence: certain
- What happens: the workspace tool and pipeline tell the user to create a feature branch
  whenever on main, while this repository explicitly requires direct work on main.
  Workspace “sync” also uses cached upstream refs without fetching.
- Improvement: read a small repository policy contract, report the correct branch rule,
  and distinguish “local tracking data” from a freshly fetched remote comparison.

### 25. Reviewer availability and incident capture still have provider-specific blind spots

- **Current severity: MEDIUM**

- Files: `bin/ai-review-preflight:137-150`,
  `bin/ai-muse:93-99`, `bin/ai-muse:136-177`, `bin/ai-glm:1568-1604`,
  `bin/ai-reviewer-issue:116-205`
- Confidence: high
- What happens: Muse’s “live” doctor does not contact the provider, Muse rejects valid
  repos with tracked historic reviews and writes no state until after a long call, GLM
  start can report before health, and Kimi’s canonical out-of-repo failure artifact is
  excluded from incident capture.
- Improvement: keep these adapters advisory until the shared lifecycle exposes honest
  health, in-progress state, and exact bounded evidence roots.

### 26. Codex cannot consume the repository’s portable memory strategy automatically

- **Current severity: MEDIUM**

- Files: `memory/README.md:158-176`, `docs/context-engineering.md:112-122`
- Confidence: certain
- What happens: Markdown facts are the cross-machine owner for Claude, while Codex’s
  memory is separate machine-local SQLite and must not be synced. No Codex trigger routes
  normal work through the portable Markdown facts.
- Improvement: add a client-neutral read-only fact search/index command and a Codex skill
  trigger; do not sync or rewrite Codex’s live SQLite store.

### 27. The doctor checks presence more often than real capability

- **Current severity: MEDIUM**

- Files: `bin/ai-devops:14-23`, `bin/ai-devops:218-245`,
  `docs/restore-from-zero.md:81-92`
- Confidence: high
- What happens: doctor checks that config files and a short, outdated companion-script
  list exist, but not their schema, source commit, installed-skill/global drift, most
  provider tools, or whether configured stage commands work. Its fixed version remains
  `0.1.0` despite major evolution.
- Improvement: report exact Git SHA, validate every managed artifact against that SHA,
  run bounded capability probes, and give one machine-compliance result.

### 28. Node/npm installation depends on an unrelated package being missing

- **Current severity: MEDIUM**

- Files: `install.sh:41-59`, `docs/deployment.md:32-47`
- Confidence: certain
- What happens: Node/npm installation sits inside the block that runs only when another
  base dependency is missing, while the missing list never checks Node/npm.
- User-visible impact: setup can skip Node entirely and later fail when Node-based MCPs
  launch.
- Improvement: test/install Node independently and verify `node`, `npm`, and `npx` before
  wiring Node-based tools.

### 29. Unattended jobs publish AI-authored memory to a public repository

- **Current severity: HIGH — active path requiring immediate containment**
- Files: `bin/ai-memory-sync`, `install.sh`, the Windows memory task installer,
  `memory/README.md`
- Confidence: certain from Git history and current scheduled-job design
- What happens: four machines automatically commit AI-authored Markdown facts to this
  public repository. The only content gate is a narrow credential-pattern scan; it
  cannot recognize customer names, internal URLs, schema details, or new secret formats.
  Metadata proves scheduled sync commits introduced 131 fact files without human review.
- User-visible impact: private business or infrastructure facts can become permanently
  public even when they do not resemble a token. No credential has been proven to have
  leaked through this specific route, so the finding is HIGH rather than CRITICAL.
- Required correction: halt the jobs, move portable memory to a private authenticated
  hub, keep content scanning as defense in depth, make every blocked/failed publication
  visible, and prove the public repo can no longer be an automatic destination.

### 30. Shipped model configuration removes the Codex reviewer’s explicit reasoning safeguard

- **Current severity: HIGH**
- Files: `bin/ai-codex-review:25-33`, `config/models.env.example:35`,
  `install.sh:82-86`
- Confidence: certain from default/config precedence
- What happens: the wrapper deliberately supplies an explicit safe Codex reasoning
  effort, then sources `models.env`; the shipped example overrides `CODEX_CMD` with a
  command that omits the effort setting. Installing the example therefore strips the
  guardrail even if the seven-stage pipeline is later demoted or replaced.
- User-visible impact: installed review runs can start with an unset/forbidden effort
  while appearing to use the wrapper's safe default.
- Required correction: preserve explicit allowed reasoning and sandbox settings through
  install/config migration, validate the effective command, and add a live/header test
  so a shipped example cannot silently weaken the in-script default.

## Recommended repair sequence

1. **Treat memory as a live incident:** halt all automatic writers, preserve every
   machine's state, move the hub private, rebuild the union, and repair failed-push
   preservation before resuming one machine at a time.
2. **Correct immediate dangerous instructions:** stale database memories, transcript
   routing, and shipped unsafe model defaults.
3. **Make restore honest:** Ubuntu required-stage exits, Windows verified source, one
   restore entry point, ACL/config fail-closed behavior, migrations, uninstall recovery,
   and capability-based doctor checks.
4. **Add enforcement:** one offline test command, Windows/Linux CI, a no-force/no-delete
   GitHub rule after the coordinated rewrite, and clean-machine restore smoke tests.
5. **Consolidate reviewer infrastructure:** one shared lifecycle; Claude Opus 5 and Codex
   are the supported approval adapters; preserve other providers as advisory/quarantined
   until the same hostile qualification passes.
6. **Finish the core workflow:** complete and test the seven-stage artifact pipeline end
   to end; do not delete the intended capability as a substitute for repair.
7. **Repair privacy and history:** split private topology, close every transcript/public
   memory path, and perform a recoverable coordinated history rewrite.
8. **Pay down context and portability debt:** measure installed context correctly,
   compact routing, expand trigger tests, and expose private portable facts read-only to
   Codex.

## Strategies worth preserving

- The one-rule/one-owner context map and task-triggered routing model.
- Recoverable skill install, backup, quarantine, and global-adoption behavior.
- 1Password references and token-free committed configuration.
- Real capability probes, especially the Codex write probe, rather than version checks.
- Review snapshots, sealed evidence packets, and fail-closed verdict intent—after the
  copy/freshness gaps above are fixed.
- Memory deletion tombstones and read-only health/index-hook philosophy.
- Incident narratives that explain why guardrails exist.

---

# Reviewer system audit — 2026-08-20

Scope: every current reviewer wrapper and the shared packet, snapshot, preflight,
scoreboard, and incident-recording helpers. This is a read-only audit report; no
reviewer behavior was changed.

## Status of this dated audit

The finding bodies below preserve what the 2026-08-20 audit observed. They are
historical evidence, not current operating instructions. A bold **Repair status**
notice directly under a finding overrides its original text. Current source and
the linked repair plan's STATUS table are authoritative.

Severity meanings:

- **CRITICAL:** can expose or overwrite files outside the intended boundary, or
  can attach evidence from the wrong repository/run.
- **HIGH:** can approve without a trustworthy review, violate read-only claims,
  duplicate paid work, lose a paid run, or make a reviewer unusable.
- **MEDIUM:** materially weakens visibility, recovery, or evidence freshness.
- **LOW:** poor failure guidance without evidence corruption.

## CRITICAL

### 1. DeepSeek session names can escape their storage folder

**Repair status (2026-08-21): fixed; names and resolved paths are contained,
linked storage is refused, and hostile path/link tests pass.**

- Files: `bin/ai-deepseek-agent:177-180`, `bin/ai-deepseek-agent:217-233`
- Confidence: high
- What happens: the caller-provided session name is placed directly into a file
  path without proving that the result stays inside DeepSeek's private session
  folder.
- User-visible failure: a crafted name such as `../../target` can make `show`
  disclose, or `reply` rewrite, a reachable JSON file outside DeepSeek's session
  storage.
- Required correction: restrict names to a safe character set, resolve the final
  path, prove it remains inside the session folder, and add hostile path tests.

### 2. Reviewer incident reports can attach another run's evidence

**Repair status (2026-08-21): fixed in the shared evidence repair; exact
provider/repository/head/run-or-session/caller matching now fails visibly when
evidence is absent.**

- Files: `bin/ai-reviewer-issue:54-60`, `bin/ai-reviewer-issue:119-155`
- Confidence: certain; reproduced in both Grok issue-56 evidence packages
- What happens: the recorder selects the newest provider record instead of the
  named run, repository, commit, and caller.
- User-visible failure: a failure in repository B can be documented with a
  successful or unrelated review from repository A. The packet looks official
  while describing the wrong event.
- Existing tracker: issue #56, plan step 6.

## HIGH

### 3. Gemini's read-only proof can miss real writes

**Repair status (2026-08-21): source repaired with whole-copy, protected-source,
and outside-sentinel identity checks. Gemini remains quarantined until live
hostile qualification passes on Windows and Ubuntu.**

- Files: `bin/ai-gemini:21-26`
- Confidence: high
- What happens: it compares only the short Git status text before and after a
  run. A file that was already shown as modified can be changed again without
  changing that text. Ignored files and paths outside the repository are not
  covered.
- User-visible failure: Gemini can alter code or review evidence and still be
  reported as read-only.
- Existing tracker: issue #38. The required hostile-write qualification remains
  open in `plan_ai-gemini-wrapper.md`.

### 4. Gemini can report success when no report was saved

**Repair status (2026-08-21): source repaired; report publication is atomic and
failure leaves recovery-required evidence. Gemini remains quarantined.**

- Files: `bin/ai-gemini:35-37`
- Confidence: high; matches the bare-PASS/empty-report trial evidence
- What happens: an unsafe or unwritable report destination returns success, and
  the caller then prints `PASS` with a report path.
- User-visible failure: a change appears independently approved, but there is no
  durable review to inspect.
- Existing tracker: issue #38.

### 5. Gemini can accept the wrong resumed conversation

**Repair status (2026-08-21): source repaired; conversation, frozen model, and
between-turn private-copy identity must all match. Gemini remains quarantined.**

- Files: `bin/ai-gemini:24`, `bin/ai-gemini:37`
- Confidence: high
- What happens: any non-empty returned conversation identifier is accepted; it
  is not compared with the stored identifier requested by the caller.
- User-visible failure: a verdict from another conversation can be attributed to
  the current review.
- Existing tracker: issue #38.

### 6. Gemini has no in-progress record, lock, or failed-run recovery

**Repair status (2026-08-21): source repaired with pre-call state, repository and
session locks, and preserved recovery evidence. Gemini remains quarantined.**

- Files: `bin/ai-gemini:36-39`
- Confidence: high
- What happens: state is written only after the paid provider call. Concurrent
  replies, deletion during a call, timeout, or interruption are not governed.
- User-visible failure: paid work can vanish, two calls can advance one
  conversation at once, and there is no trustworthy way to recover or explain
  the result.
- Existing tracker: issue #38.

### 7. Grok's one-paid-review rule fails across clones

**Repair status (2026-08-23): fixed and exact-source live-qualified; normalized
upstream locking spans clones, legacy checkout-keyed locks block mixed-version
rollout calls, and Grok returned terminal APPROVE on open issue #61. Landing and
Ubuntu installed-hash verification remain.**

- Files: `bin/ai-grok-review:202-206`, `bin/ai-grok-review:597-604`,
  `bin/ai-grok-review:658-665`
- Confidence: certain; observed with concurrent shared-db reviews
- What happens: the lock identity includes the physical checkout path. Two
  clones of the same GitHub repository therefore receive different locks.
- User-visible failure: duplicate billed reviews can run against the same
  repository at the same time.
- Existing tracker: issue #56; repair and qualification steps are complete,
  while landing, Ubuntu installation, CI, and issue closure remain.

### 8. Kimi had the same clone-based duplicate-run weakness (fixed)

**Repair status (2026-08-23): fixed, independently approved, pushed, installed,
and live-qualified. Normalized upstream locking is covered by equivalent-remote
and cross-clone fixtures; the installed matrix passed 218/218 and the
deleted-caller-clone result remained retrievable.**

- Files: `bin/ai-kimi:386-403`, `bin/ai-kimi:1071-1076`
- Confidence: certain from equivalent-remote, cross-clone, and installed live
  evidence.
- Historical failure: Kimi included the physical checkout path in its claimed
  repository-wide lock, so separate clones could start duplicate paid jobs.
- Current outcome: the paid-run lock is derived from normalized shared-upstream
  identity, while persistent session records remain safely bound to their exact
  upstream and recorded workspace.
- Existing tracker: issue #46; production proof is recorded under
  `tests/verification/kimi-review-issue-46/2026-08-23-live.md` and only GitHub
  closure remains.

### 9. Kimi lacked a trusted live completion record (fixed)

**Repair status (2026-08-23): fixed, installed, and production-qualified. The
wrapper returned terminal `session.resume_hint` records, preserved complete and
typed incomplete artifacts, and passed the authenticated production matrix.**

- Files: `plan_kimi-review-failure-recovery.md:11-18`
- Confidence: certain from exact-head independent review, installed hash proof,
  `doctor --live`, the 218/218 matrix, and deleted-clone canonical retrieval.
- Historical failure: authentication and safety checks passed, but the provider
  did not return the required completion record.
- Current outcome: Kimi can deliver qualified production reviews and remains
  fail-closed for missing, incomplete, timed-out, quota, or interrupted results.
- Existing tracker: issue #46, ready for evidence-backed closure.

### 10. Muse rejects valid repositories containing historic review reports

**Repair status (2026-08-22): fixed in source; Muse accepts deliberate tracked
history while still proving the exact new destination, and a Windows review of
open issue #51 completed. Ubuntu installed verification remains.**

- Files: `bin/ai-muse:96-97`
- Confidence: high; reproduced in shared-db
- What happens: Muse rejects the repository when any file under `.ai/reviews/`
  is tracked, even when those historic reports are deliberate, cited records.
- User-visible failure: Muse cannot start in shared-db.
- Existing tracker: issues #45 and #51.

### 11. Muse leaves no visible state during a long provider call

**Repair status (2026-08-22): fixed in source; durable pre-call state, factual
heartbeats, interruption recovery, and exact publication are covered by the
105-case hostile suite. Windows live review passed; Ubuntu remains.**

- Files: `bin/ai-muse:139-146`
- Confidence: high; reproduced in two 17-minute stalls
- What happens: session metadata and output are created only after the provider
  turn finishes.
- User-visible failure: a caller cannot tell whether Muse never started, is
  healthy, is stuck, or has vanished; repeated attempts can waste more time and
  paid usage.
- Existing tracker: issue #51.

### 12. Codex reports success even when the review command failed

**Repair status (2026-08-22): fixed and live-proven; provider failure, timeout,
empty output, missing verdict, stale source, and publication failures are
nonzero, while a real review of open issue #13 returned a truthful REJECT.**

- Files: `bin/ai-codex-review:138-159`
- Confidence: high
- What happens: command failure or a missing output artifact adds a warning but
  the wrapper still exits successfully and does not require a verdict.
- User-visible failure: automation can treat “no review happened” as successful
  independent review.

### 13. Codex omits all brand-new files from its review

**Repair status (2026-08-22): fixed and live-proven; the digest-bound private
snapshot includes text and binary untracked files, with hostile fixtures in the
Codex reviewer suite.**

- Files: `bin/ai-codex-review:69-73`
- Confidence: high
- What happens: it uses a comparison that sees tracked edits but not new,
  untracked files.
- User-visible failure: a newly added file—the main substance of many changes—
  can receive no review while the wrapper reports completion.

### 14. Evidence packet verification does not bind file names or empty files

**Repair status (2026-08-21): fixed in the shared evidence repair; the seal now
binds every relative name, byte length, and per-file digest.**

- Files: `bin/ai-review-packet:452-475`
- Confidence: high
- What happens: the seal hashes concatenated file contents, not each file name
  and boundary. Empty files contribute nothing.
- User-visible failure: files can be renamed, regrouped, or empty files added or
  removed while verification still says the packet is intact.

### 15. Review snapshots can copy content from outside the repository

**Repair status (2026-08-21): fixed in the shared evidence repair; outside
untracked links are refused before link content is copied.**

- Files: `bin/ai-review-sandbox:85-94`
- Confidence: high
- What happens: an untracked link is copied by following its target.
- User-visible failure: a link to an outside file can pull that file into the
  supposedly self-contained review copy, exposing content and making the
  snapshot claim false.

### 16. Qwen can silently continue a review against a different code version

**Repair status (2026-08-22): fixed in source and proven offline; exact
head/tree/packet/model identity blocks committed, dirty, untracked, and packet
drift before provider contact. Live qualification is intentionally skipped
under the owner's exhausted-credit exception, so Qwen remains quarantined.**

- Files: `bin/ai-qwen:894-899`, `bin/ai-qwen:949`
- Confidence: high
- What happens: stored session metadata does not bind the conversation to the
  original base, commit, working-tree state, or evidence packet. Continuation
  refreshes the review copy to current code and resumes old reasoning.
- User-visible failure: Qwen can combine conclusions from two different versions
  without warning and no freshness check can detect it.

### 17. The scoreboard can call unknown evidence current

**Repair status (2026-08-21): fixed in the shared evidence repair; freshness is
now current, stale, or unknown, and unknown verdicts are unusable.**

- Files: `bin/ai-review-scoreboard:39-45`
- Confidence: high
- What happens: evidence defaults to current and is marked stale only when both
  the repository and commit are available and a mismatch is proven. Missing or
  unreadable identity stays “current”; later uncommitted changes are ignored.
- User-visible failure: a dashboard can present unverifiable or changed evidence
  as safe to use.

## MEDIUM

### 18. Grok interruption and deletion do not tell the truth about remote work

**Repair status (2026-08-23): fixed and exact-source live-qualified; unconfirmed
remote work retains a paid-work block, including dead-owner,
uncertainty-marker, timeout, and signal-window paths.**

- Files: `bin/ai-grok-review:604`, `bin/ai-grok-review:665`,
  `bin/ai-grok-review:762-767`
- Confidence: high
- What happens: the local lock can disappear, or records can be deleted, without
  proof that the remote paid turn stopped.
- User-visible failure: another review may be started while the first provider
  call is still running.
- Existing tracker: issue #56.

### 19. Grok has no useful live progress or cross-clone activity view

**Repair status (2026-08-23): fixed and exact-source live-qualified; factual
heartbeats and cross-clone activity include elapsed time without claiming
provider health. The issue #61 canary emitted bounded progress through its
terminal APPROVE.**

- Files: `bin/ai-grok-review:303-330`, `bin/ai-grok-review:730-743`
- Confidence: certain
- What happens: the caller stays silent until final output, and `list` sees only
  completed records for the current checkout.
- User-visible failure: a healthy long review, a stuck review, and an abandoned
  review look the same.
- Existing tracker: issue #56.

### 20. GLM says the service started before it is ready

**Repair status (2026-08-22): fixed in source; start and restart share a bounded
readiness gate, with already-healthy and deadline fixtures in the 244-case GLM
suite. Final installed open-issue proof remains.**

- Files: `bin/ai-glm:1551`, `bin/ai-glm:1582`
- Confidence: high
- What happens: `start` reports success immediately; only `restart` waits for a
  health check.
- User-visible failure: the next automated review can fail for roughly 20
  seconds even though the start command reported success.

### 21. Muse assigns omitted callers to Codex

**Repair status (2026-08-22): fixed in source; caller identity is mandatory and
the shared skill supplies the real client explicitly. Omitted and mismatched
caller fixtures fail closed.**

- Files: `bin/ai-muse:11`, `skills/shared/ask-muse/SKILL.md:31-33`
- Confidence: high; reproduced in a Claude-launched run
- What happens: caller identity defaults to Codex and relies on every other
  caller remembering an environment setting.
- User-visible failure: Claude-started sessions can become invisible to Claude
  for later continuation.

### 22. DeepSeek can corrupt conversation history on failure or concurrency

**Repair status (2026-08-21): fixed; turns are locked and published atomically,
failed or interrupted replies do not advance durable history.**

- Files: `bin/ai-deepseek-agent:146-157`, `bin/ai-deepseek-agent:231-232`
- Confidence: high
- What happens: history is rewritten without a lock or atomic replacement, and
  the user message is permanently added before the provider succeeds.
- User-visible failure: concurrent replies can lose turns; a failed request
  leaves a dangling turn that is sent again later.

### 23. Codex review files can collide within the same second

**Repair status (2026-08-22): fixed; collision-resistant names and exclusive
atomic publication are covered by concurrent-report fixtures.**

- Files: `bin/ai-codex-review:66-67`
- Confidence: high
- What happens: the output name uses only mode plus a timestamp rounded to one
  second.
- User-visible failure: concurrent reviews can overwrite or mix their reports.

### 24. Central health and evidence tools cover only three providers

**Repair status (2026-08-21): fixed in the shared evidence repair; all eight
active providers are registered and unsupported facts remain unknown.**

- Files: `bin/ai-review-preflight:21`, `bin/ai-review-preflight:140`,
  `bin/ai-review-preflight:165`, `bin/ai-review-scoreboard:18`,
  `bin/ai-review-scoreboard:65`
- Confidence: high
- What happens: Grok, Kimi, and GLM are integrated; Muse, Gemini, Qwen, Codex,
  and DeepSeek are not consistently represented.
- User-visible failure: “reviewer health” and performance reports describe only
  part of the reviewer fleet, while ungoverned reviewers are still available.

### 25. Gemini's plan, standing instruction, and actual code contradict each other

**Repair status (2026-08-21): reconciled; the wrapper exists but is explicitly
quarantined, and `plan_gemini_reviewer_safety_repair.md` owns current status.**

- Files: `plan_ai-gemini-wrapper.md:13-26`,
  `plan_ai-gemini-wrapper.md:116-128`, `AGENTS.md:69`, `bin/ai-gemini`
- Confidence: high
- What happens: one status section says initial work is complete, another says
  no wrapper exists and implementation is blocked, the standing rule says not
  to implement, yet a wrapper and skill are present.
- User-visible failure: one session may use an unsafe unfinished reviewer while
  another refuses to work on it, depending on which source it reads.

## LOW

### 26. Kimi missing-job commands return raw file errors

**Repair status (2026-08-22): fixed; status, logs, result, and wait all return
the same friendly missing-job guidance, with regression fixtures.**

- Files: `bin/ai-kimi:1059-1070`, `bin/ai-kimi:1111-1112`
- Confidence: high
- What happens: `status` and `logs` do not perform the friendly existence check
  used by `wait`.
- User-visible failure: a mistyped job name produces a raw parser/file error
  instead of saying that the job does not exist and how to list valid jobs.

## What the passing tests did and did not prove at audit time

The audit-time paragraph below is historical. As of 2026-08-22 the repository-wide
offline run passes all 51 Bash groups and all 16 PowerShell groups with zero
failures, including the hostile cases that were missing during the audit. Live
provider and installed-host evidence is tracked by each repair plan. Qwen's live
gate is deliberately excluded under the owner's exhausted-credit exception and
therefore remains quarantined.

## Historical recommended repair order

This was the 2026-08-20 repair order. Use each finding's Repair status and its
current plan before acting; do not treat this list as the present work queue.

1. Stop offering Gemini, Codex review, DeepSeek, and Qwen as approval-capable
   reviewers until their HIGH findings are fixed and tested.
2. Fix incident correlation and packet/snapshot integrity because every provider
   relies on trustworthy evidence.
3. Implement issue #56 and extend the same normalized repository lock to Kimi.
4. Repair Muse startup/state visibility and complete Kimi live qualification.
5. Bring every active reviewer under one health, quarantine, evidence-freshness,
   and performance contract.

## Implementation plans

- Shared evidence: [`plan_reviewer_shared_evidence_integrity.md`](plan_reviewer_shared_evidence_integrity.md)
- Codex: [`plan_codex_reviewer_trust_repair.md`](plan_codex_reviewer_trust_repair.md)
- DeepSeek: [`plan_deepseek_reviewer_safety_repair.md`](plan_deepseek_reviewer_safety_repair.md)
- Gemini: [`plan_gemini_reviewer_safety_repair.md`](plan_gemini_reviewer_safety_repair.md)
- Grok: [`plan_grok_reviewer_runtime_repair.md`](plan_grok_reviewer_runtime_repair.md)
- Kimi: [`plan_kimi_reviewer_completion_repair.md`](plan_kimi_reviewer_completion_repair.md)
- Muse: [`plan_muse_reviewer_availability_repair.md`](plan_muse_reviewer_availability_repair.md)
- Qwen: [`plan_qwen_reviewer_evidence_repair.md`](plan_qwen_reviewer_evidence_repair.md)
- GLM: [`plan_glm_reviewer_startup_repair.md`](plan_glm_reviewer_startup_repair.md)
