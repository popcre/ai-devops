# Repository-wide strategy audit — 2026-08-21

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

Current findings: **4 CRITICAL, 14 HIGH, and 10 MEDIUM**.

| Strategy | Verdict | Main reason |
|---|---|---|
| Public/private boundary | Critical repair needed | Secret-bearing transcripts are still reachable in public Git history |
| Cross-machine memory | Critical repair needed | Index entries and failed-push commits can be destroyed automatically |
| Database safety memory | Critical repair needed | Indexed memory teaches a nonexistent preview database and forbidden migration path |
| Ubuntu/Windows recovery | High-risk gaps | Multiple required failures can still end in a successful-looking install |
| Reviewer isolation/evidence | Strong design, incomplete enforcement | Private copies can omit or mix source states; providers implement lifecycle rules differently |
| Context ownership/routing | Strong foundation | Live context is undercounted, over budget, and installed copies have drifted |
| Skills and trigger quality | Good measurement method, thin coverage | Only 8 of 58 skills have committed trigger evaluations |
| Secrets handling | Strong 1Password design | Windows ACL and malformed-config failures do not always fail closed |
| Test strategy | Many useful tests, no delivery gate | 44 tests exist, but no CI, no single full-suite command, and no protected main branch |
| Seven-stage AI workflow | Not production-ready | The advertised core is still disconnected v0.1 scaffolding |

Severity meanings:

- **CRITICAL:** current exposure, destructive data loss, or instructions capable of
  sending work to the wrong production/shared system.
- **HIGH:** a restore, review, or safety gate can report success without trustworthy
  evidence, or the documented core strategy does not work end to end.
- **MEDIUM:** material maintainability, observability, reproducibility, or efficiency
  weakness that is not presently destructive by itself.

## CRITICAL

### 1. Secret-bearing transcripts are still reachable in the public repository history

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

- Files: `bin/ai-sync-memory:129-146`, `bin/ai-memory-sync:65-105`,
  `memory/README.md:114-156`
- Confidence: certain; Git history shows the same index lines being removed and restored
  by alternating machines
- What happens: `ai-sync-memory` detects hub index entries missing on the current
  machine and prints “Pushing will drop them,” then copies the smaller local
  `MEMORY.md` over the hub anyway. `ai-memory-sync` runs that push before its pull,
  commits it automatically, and sends it to `main`.
- User-visible impact: fact files survive but become unreachable to recall. The current
  tree has **13** fact files not named by their project index, contradicting the rule
  that an unindexed fact is no memory.
- Required correction: merge indexes as a union, permit removal only through a durable
  tombstone, block index shrink before commit, run `ai-memory-health` before every
  automatic push, and add a real two-machine round-trip test.

### 3. Indexed memory teaches the wrong database and a forbidden migration route

- Files: `memory/dflow/feedback_all_db_work_via_shared_db.md:14-18`,
  `memory/dflow/MEMORY.md:8`, `memory/dflow-plm/shared-db-canonical-repo.md:10-14`,
  `memory/dflow_plm/shared-db-canonical-repo.md:10-14`,
  `skills/codex/codex-shared-db-change/SKILL.md:30-46`
- Confidence: certain
- What happens: indexed memory names preview project `<removed-protected-project-ref>`; the
  current governed skill explicitly says that project does not exist and names
  `<removed-protected-project-ref>`. Two duplicated memories also authorize app-owned startup
  schema changes, contradicting the current rule that every structural change starts
  in `shared-db`.
- User-visible impact: a future AI session can target the wrong environment or create
  schema drift while believing it is following durable company memory.
- Required correction: remove or correct the stale procedure memories immediately,
  deduplicate the two project folders, keep volatile procedures in the governed skill
  rather than memory, and validate high-risk project references against one canonical
  source.

### 4. A failed memory push destroys the local commit it claims to preserve

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

## HIGH

### 5. Ubuntu install and update can finish successfully after required stages fail

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
  entry point, secret scanning, and a GitHub rule that blocks force-push and branch
  deletion while retaining the chosen main-only workflow.

### 9. Shared reviewer copies can silently omit part or all of a change

- Files: `bin/ai-review-sandbox:81-102`, `bin/ai-review-sandbox:114-145`,
  `tests/test-ai-review-sandbox.sh:1-170`
- Confidence: certain
- What happens: failed cleanup is tolerated, failed diff generation becomes an empty
  patch, and failed untracked-file copies are warnings. The reviewer can receive a
  clean or incomplete copy.
- User-visible impact: a reviewer can approve work it never saw.
- Required correction: fail closed on cleanup, diff, and every copy; remove the partial
  snapshot; and add hostile unreadable, vanishing-file, and path-length tests.

### 10. Reviewer snapshots can combine two source states that never existed together

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

### 11. Codex review is neither enforced read-only nor trustworthy on failure

- Files: `bin/ai-codex-review:26-30`, `bin/ai-codex-review:61-85`,
  `bin/ai-codex-review:138-159`, `plan_codex_reviewer_trust_repair.md:7-12`
- Confidence: certain
- What happens: it runs in the live repo without an enforced read-only sandbox, omits
  untracked files, and turns missing CLI/nonzero provider results into an exit-zero
  report. Same-second runs share a filename.
- User-visible impact: it can change the work or certify a review that failed or skipped
  the main new files.
- Required correction: route Codex through the same private-copy, sealed-packet,
  enforced read-only, exact-verdict, unique atomic-report lifecycle as trusted reviewers.

### 12. Reviewer identity, freshness, and paid-run rules still diverge by provider

- Files: `bin/ai-qwen:901-979`, `bin/ai-kimi:354-360`,
  `bin/ai-kimi:1014-1019`, `plan_qwen_reviewer_evidence_repair.md:7-12`,
  `plan_kimi_reviewer_completion_repair.md:7-12`
- Confidence: high
- What happens: Qwen resumes old reasoning after refreshing to new code without binding
  head/tree/packet identity. Kimi’s repository-wide paid-run lock includes physical
  checkout path, so two clones of one upstream can run twice. Kimi also remains correctly
  quarantined because live completion is not proven.
- User-visible impact: conclusions cross code versions and duplicate paid work can run.
- Required correction: one upstream identity, one evidence-generation identity, and one
  lock/state schema for every provider.

### 13. Central reviewer governance exists but wrappers do not use it automatically

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

- Files: `tools/context-audit/context-audit.py:304-340`,
  `tools/context-audit/context-audit.py:584-592`, `tools/context-audit/budgets.json:19-22`,
  `docs/development.md:138-144`
- Confidence: certain from a live strict audit
- Evidence: templates total 13,813 bytes, while installed globals total 44,700 bytes.
  The audit reports drift but does not count installed bytes. It also currently warns on
  three budgets: startup router +474 bytes, Claude manifest +932, Codex manifest +7,679.
- User-visible impact: the headline savings describe source templates rather than the
  real startup payload, and Codex spends roughly 5,600 estimated tokens just learning
  which skills exist.
- Required correction: report and budget installed effective context when homes are
  supplied; introduce a ratchet that blocks new growth while grandfathering current
  debt; and shorten long descriptions only after trigger tests prove no regression.

### 17. Windows credential/config failures do not consistently fail closed

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

## MEDIUM

### 19. Restore output is not reproducible across time

- Files: `.config/configuration.winget:4-64`, `bin/setup-machine.ps1:335-390`,
  `README.md:39-42`, `docs/windows-winget-configuration.md:11-16`
- Confidence: high
- What happens: Windows packages have no versions, several tools/MCPs resolve `latest`,
  and the complete Windows process has not passed the documented two clean-machine/
  idempotency runs.
- Improvement: pin security-sensitive runtimes, schedule deliberate upgrade tests, and
  keep disposable Windows plus Ubuntu restore smoke-test evidence.

### 20. Machine-local configuration is preserved but neither migrated nor backed up

- Files: `docs/configuration.md:14-16`, `docs/configuration.md:86-90`,
  `docs/config-inventory.md:63`, `docs/restore-from-zero.md:89-92`
- Confidence: high
- What happens: existing config never receives new required keys, and a dead machine’s
  last working command settings are reconstructed manually. Doctor proves file presence,
  not schema or command capability.
- Improvement: use a versioned, secret-free merge format and protected per-machine
  overlays; doctor should validate schema, safe Codex effort, and real command ability.

### 21. Uninstall is incomplete and its destructive options have no recovery gate

- Files: `uninstall.sh:40-76`, compared with installed state at `install.sh:118-198`
- Confidence: high
- What happens: uninstall removes only current symlinks, leaving managed skills, globals,
  launchers, memory automation, permissions, and services. `--purge` and `--remove-repo`
  recursively delete without a preview, archive, or confirmation.
- Improvement: drive uninstall from a managed-artifact manifest; add `--dry-run`, a
  timestamped config archive, exact ownership checks, and complete/minimal modes.

### 22. Trigger-quality tests cover too little of the skill catalog

- Files: `tools/skill-trigger-eval/README.md:44-49`,
  `docs/skill-trigger-eval.md:149-182`, `skills/shared/shared-db-handover/SKILL.md:1-4`
- Confidence: certain
- Evidence: 8 committed eval sets for 58 tracked skill bodies (13.8%). High-risk and
  very long descriptions—including transcript, sync, closeout, pipeline, and many
  reviewer/scraper skills—have no committed trigger set.
- Improvement: require evals for high-risk or long descriptions and every description
  edit; measure more than one day and on both Windows/Linux where tools differ.

### 23. Context work routes through a closed 104 KB plan and stale copied measurements

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

- Files: `AGENTS.md:17-23`, `bin/ai-workspace-status:92-107`,
  `skills/claude/ai-development-pipeline/SKILL.md:52-62`
- Confidence: certain
- What happens: the workspace tool and pipeline tell the user to create a feature branch
  whenever on main, while this repository explicitly requires direct work on main.
  Workspace “sync” also uses cached upstream refs without fetching.
- Improvement: read a small repository policy contract, report the correct branch rule,
  and distinguish “local tracking data” from a freshly fetched remote comparison.

### 25. Reviewer availability and incident capture still have provider-specific blind spots

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

- Files: `memory/README.md:158-176`, `docs/context-engineering.md:112-122`
- Confidence: certain
- What happens: Markdown facts are the cross-machine owner for Claude, while Codex’s
  memory is separate machine-local SQLite and must not be synced. No Codex trigger routes
  normal work through the portable Markdown facts.
- Improvement: add a client-neutral read-only fact search/index command and a Codex skill
  trigger; do not sync or rewrite Codex’s live SQLite store.

### 27. The doctor checks presence more often than real capability

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

- Files: `install.sh:41-59`, `docs/deployment.md:32-47`
- Confidence: certain
- What happens: Node/npm installation sits inside the block that runs only when another
  base dependency is missing, while the missing list never checks Node/npm.
- User-visible impact: setup can skip Node entirely and later fail when Node-based MCPs
  launch.
- Improvement: test/install Node independently and verify `node`, `npm`, and `npx` before
  wiring Node-based tools.

## Recommended repair sequence

1. **Contain exposure and destructive memory behavior:** public history, stale database
   memories, index union, and failed-push preservation.
2. **Make restore honest:** Ubuntu required-stage exits, Windows verified source, one
   restore entry point, ACL/config fail-closed behavior, and stronger doctor checks.
3. **Add enforcement:** one offline test command, Windows/Linux CI, no-force-push GitHub
   rule, and restore smoke tests.
4. **Consolidate reviewer infrastructure:** one shared lifecycle core; keep only fully
   qualified reviewers as approval gates and label the rest advisory/quarantined.
5. **Choose the core workflow:** finish the seven-stage artifact pipeline or retire its
   headline status. Stop adding reviewer variants until this decision is complete.
6. **Pay down context and portability debt:** measure installed context, reconcile globals,
   expand trigger tests, shrink descriptions, and expose portable facts to Codex.

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

**Repair status (2026-08-21): fixed; normalized upstream locking spans clones,
and legacy checkout-keyed locks block mixed-version rollout calls.**

- Files: `bin/ai-grok-review:202-206`, `bin/ai-grok-review:597-604`,
  `bin/ai-grok-review:658-665`
- Confidence: certain; observed with concurrent shared-db reviews
- What happens: the lock identity includes the physical checkout path. Two
  clones of the same GitHub repository therefore receive different locks.
- User-visible failure: duplicate billed reviews can run against the same
  repository at the same time.
- Existing tracker: issue #56; all repair-plan steps remain open.

### 8. Kimi has the same clone-based duplicate-run weakness

- Files: `bin/ai-kimi:349-353`, `bin/ai-kimi:1012-1014`
- Confidence: high
- What happens: Kimi also includes the physical checkout path in the identity
  used for its claimed repository-wide lock.
- User-visible failure: separate clones can start concurrent Kimi jobs for the
  same upstream repository.
- Tracker gap: this is not covered by the current issue-46 closeout plan.

### 9. Kimi is still unavailable as a trusted live reviewer

- Files: `plan_kimi-review-failure-recovery.md:11-18`
- Confidence: certain from repeated installed live probes
- What happens: authentication and safety checks pass, but the provider does not
  return the required completion record.
- User-visible failure: Kimi cannot currently deliver a qualified review. Its
  repaired failure handling is correctly keeping it quarantined.
- Existing tracker: issue #46.

### 10. Muse rejects valid repositories containing historic review reports

- Files: `bin/ai-muse:96-97`
- Confidence: high; reproduced in shared-db
- What happens: Muse rejects the repository when any file under `.ai/reviews/`
  is tracked, even when those historic reports are deliberate, cited records.
- User-visible failure: Muse cannot start in shared-db.
- Existing tracker: issues #45 and #51.

### 11. Muse leaves no visible state during a long provider call

- Files: `bin/ai-muse:139-146`
- Confidence: high; reproduced in two 17-minute stalls
- What happens: session metadata and output are created only after the provider
  turn finishes.
- User-visible failure: a caller cannot tell whether Muse never started, is
  healthy, is stuck, or has vanished; repeated attempts can waste more time and
  paid usage.
- Existing tracker: issue #51.

### 12. Codex reports success even when the review command failed

- Files: `bin/ai-codex-review:138-159`
- Confidence: high
- What happens: command failure or a missing output artifact adds a warning but
  the wrapper still exits successfully and does not require a verdict.
- User-visible failure: automation can treat “no review happened” as successful
  independent review.

### 13. Codex omits all brand-new files from its review

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

**Repair status (2026-08-21): fixed; unconfirmed remote work retains a paid-work
block, including dead-owner and uncertainty-marker failure paths.**

- Files: `bin/ai-grok-review:604`, `bin/ai-grok-review:665`,
  `bin/ai-grok-review:762-767`
- Confidence: high
- What happens: the local lock can disappear, or records can be deleted, without
  proof that the remote paid turn stopped.
- User-visible failure: another review may be started while the first provider
  call is still running.
- Existing tracker: issue #56.

### 19. Grok has no useful live progress or cross-clone activity view

**Repair status (2026-08-21): fixed; factual heartbeats and cross-clone activity
include elapsed time without claiming provider health.**

- Files: `bin/ai-grok-review:303-330`, `bin/ai-grok-review:730-743`
- Confidence: certain
- What happens: the caller stays silent until final output, and `list` sees only
  completed records for the current checkout.
- User-visible failure: a healthy long review, a stuck review, and an abandoned
  review look the same.
- Existing tracker: issue #56.

### 20. GLM says the service started before it is ready

- Files: `bin/ai-glm:1551`, `bin/ai-glm:1582`
- Confidence: high
- What happens: `start` reports success immediately; only `restart` waits for a
  health check.
- User-visible failure: the next automated review can fail for roughly 20
  seconds even though the start command reported success.

### 21. Muse assigns omitted callers to Codex

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

- Files: `bin/ai-kimi:1059-1070`, `bin/ai-kimi:1111-1112`
- Confidence: high
- What happens: `status` and `logs` do not perform the friendly existence check
  used by `wait`.
- User-visible failure: a mistyped job name produces a raw parser/file error
  instead of saying that the job does not exist and how to list valid jobs.

## What the passing tests did and did not prove at audit time

The audit-time offline tests verified many important safety rules and the corrected
Windows run passed the shared packet, snapshot, preflight, scoreboard, incident,
and Grok suites encountered during this audit. However, the findings above are
mostly missing-test cases: clone equivalence, hostile links, filename-bound
packet seals, already-dirty Gemini files, wrong conversation identifiers,
DeepSeek path traversal, Codex command failure, and cross-version Qwen resume.
Passing the existing suite therefore does not contradict these findings.

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
