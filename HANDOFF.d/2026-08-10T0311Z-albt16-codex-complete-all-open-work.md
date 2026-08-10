# Master handoff: complete every open ai-devops workstream

## STATUS update: 2026-08-10T0405Z

### Recheck: 2026-08-10T1129Z

- Pulled `origin/main` cleanly to `134a78aa361b9b5cceb8205319b0b9c006ae250e`.
- Reconciled both remaining handoffs against current Git, plans, code, and the
  master completion evidence. No completed phase needs to be repeated.
- `916` (`100.110.219.31:22`) still timed out using Git for Windows SSH with an
  eight-second connection timeout. Its machine-local rollout remains blocked
  until that computer is online.
- The legacy credential-incident work remains approval-gated. The current work
  order forbids credential rotation without explicit approval, so no credential
  was read, changed, or rotated.
- All plan STATUS tables named by this work order remain complete. No source,
  test, or runtime change was needed in this recheck.

Completed and pushed:

- Config consolidation Phase 3, the live hidden memory task, GLM reliability,
  Grok debate continuity, Kimi debate continuity, DeepSeek Phase 1 repair and
  Phase 2 cancellation, and the production-trigger root-cause investigation.
- Implementation commit `f738db79d8ace9a6aef8eac7657275789ea2ddc8` and
  completion-record commit `04bbfc02a6cbcf132cf3c1085e898932ad24ecb1`
  were pushed and verified on `origin/main`.
- The production-trigger, DeepSeek, hidden-memory, and delegate-integration
  handoffs were deleted only after their evidence was preserved in plans/docs.
- `4837` resolves to this same physical machine (`al8960ofc`). Repo setup ran
  successfully through PowerShell 7, the four delegate skill hashes match
  source, and `ai-memory-sync` uses hidden `wscript.exe`, `PT15M`, `IgnoreNew`.

Still open, with exact reason:

- The legacy handoff remains because its credential-incident section requires
  explicit approval for each rotation wave. This work order explicitly forbids
  credential rotation without that approval. No credentials were changed.
- SSH to `916` (`100.110.219.31:22`) timed out on 2026-08-10. Its machine-local
  rollout cannot be verified until that computer is online and reachable.
- Unrelated concurrent local files under `.ai/`, `.ai-kimi-test-debug.txt`, and
  `docs/claude-remote-control-hardening-v2.md` were preserved and not committed.

Resume at the legacy handoff's section S5 only after Albert approves a named
credential wave. Recheck `916` reachability before its rollout. Do not repeat
the completed phases above.

## 0. Owner request and authority

Albert Hazan, the repository owner, asked for one fresh AI session to **investigate and complete every currently open workstream**, not merely summarize them. Work autonomously. Do not ask Albert to run commands or make routine technical choices that you can handle with the available CLI, filesystem, SSH, or browser tools.

This request authorizes normal repo changes, local-machine setup and verification, commits, pushes to this repo's `main`, and read-only investigation across Albert's named development machines. It does **not** authorize destructive actions, credential rotation, direct production/shared-cloud mutation, `terraform apply`, changing production Cloud Build triggers, weakening security controls, or changing shared databases outside the `shared-db` procedure. When a production fix would require one of those actions, prepare the safest reviewed code/plan and ask Albert for the exact final authorization only at that boundary.

## 1. What this application is

Repository: `u2giants/ai-devops`, normally checked out as `C:\repos\ai-devops` on Windows and `/worksp/ai-devops` on Ubuntu. Branch policy: `main` only.

This is Albert's backup-and-restore toolkit for a multi-model AI coding workflow. It installs and verifies Bash/PowerShell commands, Claude/Codex shared skills, machine configuration, secrets launchers, and persistent second-opinion integrations. It is not a hosted app and has no normal CI/deployment pipeline. GitHub is the source of truth. The important delegate commands are:

- `ai-glm`: GLM-5.2 through a local OpenCode server.
- `ai-grok-review`: named read-only Grok sessions.
- `ai-kimi`: named Kimi K3 sessions and isolated implementation runs.
- `ai-deepseek-agent`: text-based DeepSeek debates.

Secrets live only in 1Password account `popcreations.1password.com`, vault `vibe_coding`. Never print, paste, commit, or store resolved values.

## 2. What this master workstream must accomplish

Close all five handoffs that were proven genuinely open on 2026-08-09:

1. `HANDOFF.d/2026-07-30T1451Z-t16-claude-legacy-migrated-handoff.md`
2. `HANDOFF.d/2026-07-30T1451Z-t16-claude-prod-trigger-disable-investigation.md`
3. `HANDOFF.d/2026-08-02T1917Z-albt16-claude-deepseek-codex-provider.md`
4. `HANDOFF.d/2026-08-06T0052Z-comp-codex-hidden-memory-sync-task.md`
5. `HANDOFF.d/2026-08-10T0000Z-albt16-codex-delegate-integration-plans.md`

The outcome is not “files deleted.” The outcome is that each underlying task is completed, verified, committed, pushed, and then its handoff is deleted because Git history preserves it. If investigation proves an item was deliberately cancelled or superseded, document the proof before deletion.

## 3. Current state

As of commit `35510ae603fdfa1df4d215d01adab6f18479735f` on `main`:

- The repo is clean and synced.
- The five handoffs above are the complete open set before this master handoff was added.
- `plan_phase3-config-consolidation.md` still has steps 5-9 open. This is the main surviving work inside the large legacy handoff.
- Production Cloud Build project `lithe-breaker-323913`, region `us-east4`, has all six `*-prod` triggers enabled. The July 20 Terraform source and t16 AI session that caused the old disablement remain unidentified.
- DeepSeek Phase 1 works. Phase 2, a structurally read-only Codex provider/profile allowing DeepSeek to inspect a repo, was never built or cancelled.
- The hidden memory-sync source change is committed and its static PowerShell test passes, but this albt16 machine still had the old live task action (`bash.exe` directly) and a 72-hour execution limit. The live rollout is unfinished.
- The GLM, Grok, and Kimi plans below are fully written and Kimi-reviewed, but every implementation row is open:
  - `plan_glm-service-reliability.md`
  - `plan_grok-debate-continuity.md`
  - `plan_kimi-debate-context-continuity.md`
- The Grok plan owns `templates/delegation/debate-turn.md` and must land before the Kimi plan. GLM may proceed independently, but both GLM and Grok plans touch different sections of `skills/shared/ask-glm/SKILL.md`.

## 4. What was tried and did not work

Read the five source handoffs for the full failure history. The most important traps are:

- Do not trust old handoff claims without checking current Git/code/machine state. Later sessions already superseded two handoffs that were deleted in commit `35510ae`.
- GLM already has a three-retry Task Scheduler policy. The real question is why it did not recover after exit `0xC000013A`; do not “fix” it by adding the same retry again.
- Do not put delegate debate templates under `templates/prompts/`; that folder is only for the seven staged workflow prompts. Use `templates/delegation/` as specified.
- Do not add a Grok wrapper feature unless the Grok plan's measured-failure gate is met. Skill/template guidance is the locked default.
- Kimi 0.32.0 must be re-qualified before relying on the older 0.31.1 STEP 0 evidence. Never use `--continue`; use the exact session ID. Tool names in its read-only profile are case-sensitive.
- Do not claim Kimi cache, cost, token, or returned-model figures; headless output does not provide them.
- The hidden memory task's static test passing does not prove the registered Windows task was updated. Inspect the live task.
- Do not resurrect the rejected diff-only DeepSeek reviewer. Albert wants back-and-forth debate with repository inspection, read-only only.
- Do not run `terraform apply` or directly change production Cloud Build triggers. The July 20 incident was caused by exactly that unsafe behavior under Albert's personal credentials.
- Do not scan or open raw transcript `.jsonl` files casually. Use the repo's transcript backup/mining procedures and avoid exposing secrets.

## 5. Root causes and key findings

- Open handoffs had accumulated because pushed code was mistaken for complete rollout. Machine-local verification matters.
- Conversation transport continuity and semantic debate continuity are different. Exact session IDs preserve the thread; the shared debate contract must also relay claims, evidence, changed files, and unresolved objections.
- GLM availability currently depends on one loopback OpenCode service. A stopped service makes the otherwise-correct named sessions unavailable.
- Kimi can safely review only because its agent profile removes write/Bash/network tools. A plain headless Kimi prompt can write files.
- Grok is the only delegate here with measurable cache and monetary cost; obey the plans' $1.50 normal and $0.75 acceptance-test ceilings.
- The legacy configuration plan exists because repo setup and old Dropbox scripts still conflict as sources of truth.
- The production-trigger incident is currently contained, not root-caused. Enabled triggers do not prove the Terraform source is safe.

## 6. Exact execution plan

### Phase A: establish ground truth and ownership

1. Pull latest `origin/main`, confirm a clean worktree, verify author and committer are `Albert Hazan <u2giants@users.noreply.github.com>`, list every current `HANDOFF.d` file, and read all open files newest-first. Also read `AGENTS.md`, `docs/architecture.md`, `docs/development.md`, and every plan/topic document named below. **Gate:** write a short internal checklist mapping every handoff to its current owner file and first open step; no unclassified handoff remains.
2. Use this master handoff as the coordinator record. Do not edit another session's handoff content. Update the owning plan STATUS tables as implementation lands. **Gate:** Git status shows only changes owned by this workstream before each commit.

### Phase B: complete configuration consolidation and the hidden memory task

3. Execute open steps 5-9 of `plan_phase3-config-consolidation.md`. Re-read `docs/config-consolidation-proposal.md`, `docs/config-inventory.md`, the relevant `templates/system/machine-atlas.md` section, and current setup scripts first. This request authorizes retiring the old Dropbox setup scripts only by replacing them with safe pointer stubs after backing up their current text and proving the repo setup is canonical. Do not expose secrets from those scripts. **Gate:** the plan's STATUS table is fully complete; Dropbox scripts cannot configure machines; restore docs and portable Codex preferences are current; the atlas names machines correctly; repo tests pass.
4. Apply the repo-owned setup to the affected Windows machine and replace the old `ai-memory-sync` task. Run `tests/test-memory-sync-scheduled-task.ps1`, inspect the registered task action/settings, run it manually, and inspect the log timestamp/result. **Gate:** action uses hidden `wscript.exe`, execution limit is 15 minutes, `IgnoreNew` is set, no terminal appears, LastTaskResult is 0, and the log receives a new successful entry.
5. Roll out and verify the same repo state on each reachable named development machine where the relevant plan requires it. Do not run the unproven minimum-touch bootstrap on an established machine merely as a test; use a disposable Windows 11 machine for its first full proof and second-run idempotence check. **Gate:** each target has an explicit recorded pass/absence, and no machine is claimed current without a real check.
6. When all legacy/config and memory gates pass, delete their source handoffs in the same completion commit: the large legacy handoff only if every embedded open workstream is proven complete or superseded, and the hidden-memory handoff after live rollout proof. **Gate:** plan status/docs retain durable facts; deleted handoffs are recoverable in Git history.

### Phase C: implement the delegate integrations in the required order

7. Execute `plan_glm-service-reliability.md` exactly. Read section 5 of `docs/glm-opencode.md` first. Diagnose why the existing retry policy did not recover, implement the fewest-moving-parts permanent fix, bound logs/retries, extend the named tests, and prove exact-session memory/cache across a controlled service restart. **Gate:** every GLM STATUS row is complete, offline/live tests pass, one loopback listener exists, review remains read-only, and the same session resumes after restart.
8. Execute `plan_grok-debate-continuity.md` exactly. It owns `templates/delegation/debate-turn.md` and alignment of Grok plus GLM skill guidance. Do not exceed $0.75 during its live acceptance debate or $1.50 for a normal full debate. **Gate:** all STATUS rows complete, same Grok session resumes with measured cache reads, cost stays inside the bound, and final verdict lists zero material objections or explicit bounded unresolved items.
9. Only after step 8 lands, execute `plan_kimi-debate-context-continuity.md`. First re-run all STEP 0 probes against installed Kimi 0.32.0, including read and write canaries. Then add context-health/recovery guidance and tests and run the required same-session K3 debate. **Gate:** all STATUS rows complete, exact session ID is preserved, changed artifacts are re-read, read works, write fails, no unavailable metric is claimed, and Kimi records no material objection or explicit bounded unresolved items.
10. Delete `HANDOFF.d/2026-08-10T0000Z-albt16-codex-delegate-integration-plans.md` only after all three plans pass and are pushed. **Gate:** no open row remains in any of the three plans and installed Claude/Codex skill hashes match repo source.

### Phase D: finish DeepSeek safely

11. Reconcile `HANDOFF.d/2026-08-02T1917Z-albt16-claude-deepseek-codex-provider.md` against current Codex and DeepSeek official documentation. Use current local Codex help/config schemas, not the handoff's old assumptions. Decide whether the existing provider path remains supported and is the fewest-moving-parts way to give DeepSeek read-only repo tools. **Gate:** record a current, primary-source-supported design decision before editing config.
12. If supported, implement Phase 2 as a repo-owned, additive, structurally read-only provider/profile. Preserve the normal OpenAI provider and ChatGPT login. Never hand-edit `~/.codex/config.toml`; use the repo's append-only, duplicate-safe setup path. Explicitly pass Codex reasoning effort `low` or `medium`, never omit it and never use high. Prove the launched Codex header reports low/medium and a harmless DeepSeek review can read but cannot write. If current Codex no longer supports this safely, formally cancel Phase 2, document why, and keep the working text-based debate path. **Gate:** either a tested safe provider/profile is installed everywhere required, or a documented evidence-backed cancellation removes the stale expectation.
13. Update the DeepSeek skill/docs/tests and delete its handoff only when Phase 2 is implemented or formally cancelled with proof. **Gate:** Phase 1 remains working, no diff-only reviewer returns, no secret enters Git, and source/installed skills match.

### Phase E: close the production-trigger investigation without mutating production

14. Re-read the production-trigger handoff and current global production-safety rule. Verify all six prod triggers remain enabled with read-only `gcloud` calls. Search reachable local source repositories and GitHub metadata for the Terraform definition that managed those triggers. Use official audit logs to confirm actor/time. Do not run Terraform or change a trigger. **Gate:** current enabled state and the best available Terraform-source conclusion are recorded with evidence.
15. On t16, use the approved transcript backup/mining workflow to locate the July 20, 2026 session without dumping raw transcript contents or secrets into chat. If the transcript no longer exists, document the exact locations/date ranges checked and close that evidence path as unavailable. **Gate:** identify the responsible session/tool or produce an evidence-backed “not recoverable” conclusion.
16. If unsafe Terraform declaring `disabled=true` is found, prepare a focused code fix/PR in the owning repo and a reviewed plan. Do not apply Terraform or mutate production. Ask Albert only for exact final authorization if the last step would change a named production resource. **Gate:** source-of-truth code is safe or the precise owner/blocker is documented; live triggers remain enabled.
17. Delete the production-trigger handoff when the transcript/config paths are resolved or conclusively unavailable and durable incident rules/docs contain the final finding. **Gate:** no investigation question remains that another session could answer with available evidence.

### Phase F: close out safely

18. Run all relevant named Bash and PowerShell tests, syntax checks, `git diff --check`, secret-pattern scan, installed-skill hash checks, and live checks required above. Do not weaken a test to get green. **Gate:** every applicable check passes; failures are fixed or clearly blocked.
19. Update only durable Markdown that changed: plan STATUS/current-state sections, canonical topic docs, and this master handoff. Delete completed source handoffs only with proof. **Gate:** `HANDOFF.d` contains only genuinely unfinished work.
20. Pull/reconcile concurrent changes, stage only owned files, verify Albert's author/committer identity, commit focused changes, push `main`, fetch, and compare local/remote SHAs. This repo has no normal deploy; record CI/deploy as N/A rather than claiming them. **Gate:** clean worktree, `HEAD == origin/main`, correct identity, and all completed handoffs removed.

Natural context cut points are after phases B, C, D, and E. If the session must continue in a new context window, update this handoff and every active plan first so a fresh session starts at an exact step. Do not abandon work with stale STATUS tables.

## 7. Constraints and gotchas

- Plain business English in reports. Albert is not a programmer.
- Do the technical work yourself. Ask Albert only for a decision or permission that cannot safely be inferred.
- Main-only repo. Preserve concurrent work and pull before pushing.
- Never edit root `HANDOFF.md`; never rewrite another session's handoff.
- Git author and committer must be Albert's noreply identity.
- Never expose or rotate secrets without explicit approval. Serialize 1Password reads.
- Never mutate production/shared infrastructure by default. No `terraform apply`, trigger mutation, broad gcloud mutation, or privilege expansion.
- Host/OS changes on Hetz go through `u2giants/ansible`, not live SSH edits. App containers remain Coolify-owned.
- Do not touch Claude config. Codex config edits are append-only and duplicate-safe through repo scripts.
- GPT-5.6 Codex effort is always explicit `low` or `medium`.
- Do not replace system binaries.
- No silent fallbacks, no hard-coded model choices that should be configurable, and tests for all code changes.
- Review delegates stay structurally read-only. Never broaden Grok/Kimi/GLM permissions to cure a timeout.

## 8. Access and environment

- GitHub repo: `https://github.com/u2giants/ai-devops`, branch `main`.
- Windows machines: `t16`/`albt16`, `916`/`916-alien`, and `4837`/`al8960ofc`, user `ahazan2`.
- Hetz VPS SSH alias: `vps` or `coolify`; use Git's SSH binary on Windows when normal PowerShell capture fails.
- Authenticated CLIs are normally available: `gh`, `gcloud`, `op`, Codex, Claude, Kimi, Grok. Verify with a real safe call before declaring one missing.
- 1Password vault: `vibe_coding`. Relevant item titles include `GLM z.ai API` and `deepseek API key`; never record values.
- Cloud Build read-only target: project `lithe-breaker-323913`, region `us-east4`.
- Local GLM endpoint: `http://127.0.0.1:4096`, authenticated and loopback-only.
- Do not traverse network drives `P:` or `Z:` unless a named step requires a specific path.

## 9. Open questions and risks

- Which machine the new session starts on determines which live checks can run locally. Use SSH or move at a documented phase cut; do not claim fleet-wide proof from one machine.
- The legacy handoff contains several historical workstreams. Delete it only after checking every embedded open marker, not merely Phase 3.
- The production Terraform source may live in a repository not available locally. Read-only GitHub/cloud evidence is allowed; production mutation is not.
- DeepSeek's current compatibility with Codex tool calling may have changed. A safe cancellation is better than an unsafe provider hack.
- Kimi automatic compaction may lose nuance; the shared consensus ledger is the durable source.
- Grok paid turns can be expensive; obey the hard cost ceilings.
- GLM service supervision can create restart storms or duplicate listeners if implemented poorly; follow its plan's bounded tests.

## Mandatory self-audit

1. **Can a fresh AI with no chat context continue without questions? Yes.** Sections 1-3 define the repository, machines, tools, five source handoffs, current commit, and exact open state. Section 6 gives ordered phases, named files, commands/controls, and a verification gate for every step.
2. **Can it continue as effectively as this session? Yes.** Sections 4-5 preserve the failed approaches and non-obvious findings: existing GLM retry, Kimi safety/version traps, Grok cost controls, live-vs-static memory verification, DeepSeek rejected design, and production Terraform boundary.
3. **Does it include every detail needed for flawless execution? Yes.** Section 6 covers implementation and landing; section 7 captures standing and task-specific constraints; section 8 defines access, machines, URLs, projects, and secret locations; section 9 records all remaining risks and evidence-dependent decisions. Commit/push/deploy expectations are explicit and secrets are location-only.

Self-audit passed on 2026-08-10. This file is intentionally comprehensive enough to serve as the exact prompt for a new Claude or Codex session.
