# IMPLEMENTATION PLAN: context-engineering consolidation (2026-08-12)

## STATUS

| Step | Status | Last updated | Evidence |
|---|---|---:|---|
| 1. Freeze a measured baseline | ⬜ open | 2026-08-12 | Audit measurements in section 6 |
| 2. Define the context ownership map | ⬜ open | 2026-08-12 | Proposed map in sections 8 and 9 |
| 3. Add context-audit tooling and tests | ⬜ open | 2026-08-12 | Test design in sections 9 and 10 |
| 4. Slim the always-loaded global files | ⬜ open | 2026-08-12 | Candidate material in section 6 |
| 5. Turn `AGENTS.md` into a tighter router | ⬜ open | 2026-08-12 | Current 11,731-token measurement |
| 6. Remove cross-client skill duplication safely | ⬜ open | 2026-08-12 | Fourteen duplicate paragraph groups found |
| 7. Repair installation drift without clobbering local facts | ⬜ open | 2026-08-12 | Four installed skill drifts found |
| 8. Pilot on one Windows machine and representative repos | ⬜ open | 2026-08-12 | Pilot gates in section 9 |
| 9. Roll out to all configured machines | ⬜ open | 2026-08-12 | Rollout gates in section 9 |
| 10. Measure results and close the workstream | ⬜ open | 2026-08-12 | Acceptance gates in sections 10 and 13 |

**Fresh-session start:** begin at step 1. No implementation has started. Before
each phase, re-read that phase and sections 1, 4, 8, 11, and 13 to catch drift.

**Handoff:**
[`HANDOFF.d/2026-08-12T1135Z-al8960ofc-codex-context-engineering-audit.md`](HANDOFF.d/2026-08-12T1135Z-al8960ofc-codex-context-engineering-audit.md)

## 1. The ultimate goal: what we are actually trying to achieve

Albert's Claude Code and Codex sessions should start with the smallest reliable
set of instructions, find detailed facts only when needed, retain important
decisions between sessions, and behave the same way on every configured Windows
and Ubuntu machine. The change must reduce repeated context without weakening
safety, losing hard-won incident knowledge, hiding failures, or making a new
session ask Albert questions that the documentation already answers.

This is not a race to the smallest file. The target is the smallest **high-signal**
context that preserves correct behavior. Safety and correctness are acceptance
requirements. Token reduction is a measured benefit, not the sole goal.

If any step below conflicts with this goal, the goal wins: stop and flag it.

## 2. What this application is

`u2giants/ai-devops` is Albert Hazan's public backup-and-restore toolkit for his
multi-model AI coding workflow. It contains Bash and PowerShell command-line
tools, global Claude/Codex instructions, repo documentation templates, skills,
machine setup, and cross-machine memory. It is not a hosted application and has
no database, container, or production service.

- Canonical repository: `https://github.com/u2giants/ai-devops`
- Local Windows checkout audited: `C:\repos\ai-devops`
- Branch policy: `main` only
- Audited commit: `c23303cb90dd7dd7ac8c71d103480deaff759776`
- Windows source-of-truth installer: `bin/setup-machine.ps1`
- Ubuntu/Git-Bash instruction/skill installer: `bin/ai-install-skills`
- Native Windows instruction/skill installer:
  `bin/install-ai-devops-windows.ps1`
- Claude global source: `templates/system/CLAUDE-global.md`
- Codex global source: `templates/system/AGENTS-global-codex.md`
- Repo router: `AGENTS.md`
- Claude repo adapter: `CLAUDE.md`
- Skills: `skills/shared/`, `skills/claude/`, and `skills/codex/`
- Windows machines in scope: `916-alien`, `albt16`, and `al8960ofc`
- Ubuntu machines in scope: only those already managed by ai-devops, including
  the `hetz` AI user setup. No production workload mutation is part of this plan.

Albert is a business owner, not a programmer. The toolkit is his engineering
department's durable memory. A shorter prompt that makes sessions less safe or
forces Albert to re-explain facts is a failure.

## 3. What triggered this work

Albert supplied this X post and asked whether its claims about context and graph
engineering would improve the Windows Claude Code and Codex configuration:

- Main post: `https://x.com/i/status/2087218720594706679`
- Referenced post/article card:
  `https://x.com/Sprytixl/status/2087066798608752671`
- Referenced X article:
  `https://x.com/i/article/2087066798608752671`

The main post recommends storing decisions, contracts, dead ends, current state,
sources, and open questions outside the conversation, then loading pointers
instead of replaying raw history. It claims six files cut tokens by 84%, raise
accuracy by 39%, and turn a $20 workflow into a $3 workflow. It describes the
material as an Anthropic leak and claims Google and Microsoft engineers use it.

### Evidence-based opinion about the post, limited to this setup

The central context-engineering principle is correct and directly relevant:
keep always-loaded instructions lean, retrieve detail just in time, compact long
work, and write durable state outside the chat. Anthropic's official article
describes that hybrid model, including `CLAUDE.md`, just-in-time file search,
compaction, structured notes, and focused subagents:
`https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents`.

OpenAI independently recommends leaner prompts, one statement per rule, and only
the tools relevant to the task. OpenAI reports directional internal coding-agent
results of roughly 10-15% higher scores, 41-66% fewer tokens, and 33-67% lower
cost, while warning that each workload must be evaluated:
`https://developers.openai.com/api/docs/guides/latest-model`.

The X post overstates what the evidence proves. The 84% and 39% figures are from
a particular Anthropic Developer Platform evaluation of context editing plus a
memory tool, including a 100-turn web-search workload. They are not evidence that
six Markdown files produce those gains in Claude Code or Codex. No primary
evidence found in this audit supports “leaked,” the Google/Microsoft attribution,
the one-million-to-40,000 calculation, or the $3-versus-$20 promise. Prompt cache
discounts are real, but provider-managed Claude Code and Codex subscriptions do
not expose a simple configuration that makes this arithmetic transferable.

“Graph engineering” is useful here only as a description of explicit workflow
steps and feedback edges: understand -> plan -> implement -> test -> review ->
ship, with failures routed back to a bounded correction step. The repo already
implements much of that in its staged prompts, delegation wrappers, verification
gates, plans, and handoffs. This plan does **not** propose a graph database,
GraphRAG, a code-indexing service, or six ritual files in every repository.

## 4. Scope: in and out

### In scope

1. Measure which global, repo, and skill text is always loaded, conditionally
   loaded, duplicated, stale, or installed differently from its source.
2. Define one owner for each rule or fact: global instruction, machine atlas,
   repo router, topic document, skill, memory, plan, or handoff.
3. Slim global and repo-start context while preserving hard safety gates.
4. Replace avoidable client-specific skill copies with shared sources when both
   clients require identical behavior.
5. Add automated checks for size budgets, duplicate rules, broken links, source
   collisions, stale installed copies, and required safety markers.
6. Pilot and measure the behavior on Windows before broad rollout.
7. Roll out only through existing ai-devops installers and verify every machine.

### Not in this plan

- No production, shared-cloud, Supabase, Coolify, NAS, or database mutation.
- No change to application code in other repositories.
- No wholesale rewrite of every application `AGENTS.md` in the first change.
- No third-party knowledge graph, vector database, GraphRAG service, or daemon.
- No new six-file convention copied from the X post.
- No secret, transcript, `.env`, credential, or private licensed-data loading.
- No removal of a safety rule merely because it is long.
- No assumption that approximate characters divided by four equals billed
  tokens. Exact model token measurements must use supported usage reports.
- No unbounded multi-agent workflow. Delegation remains task-specific and
  bounded.
- No model or reasoning-effort change. GPT-5.6 stays explicitly `low` or
  `medium` per Albert's standing rule.

## 5. Current state of the code and configuration

### What already works

- `AGENTS.md` is the canonical operating guide and documentation router.
- `CLAUDE.md:3-12` tells Claude to read `AGENTS.md` first and avoid bulk-reading
  Markdown.
- `templates/system/CLAUDE-global.md:257-280` and the Codex global template's
  session rules already require router-first, task-specific loading and open
  handoff reading.
- `skills/codex/codex-context-optimizer/SKILL.md` already defines the desired
  minimal loading order and the durable-rule ownership pattern.
- `HANDOFF.d/` already separates active workstreams instead of replaying chat.
- `memory/` and `bin/ai-memory-sync` already persist selected durable knowledge
  across machines.
- `skills/shared/` already provides one source for cross-client behavior.
- `bin/ai-install-skills:122-150` installs managed skills and
  `bin/ai-install-skills:208-224` seeds global files on its Bash path.
- `bin/install-ai-devops-windows.ps1` independently implements the native
  Windows skill copy, managed markers, orphan quarantine, and seed-if-absent
  globals. `bin/setup-machine.ps1:185-192` delegates to this PowerShell path,
  not to the Bash installer. Both implementations must remain aligned.

### Measured audit baseline on 2026-08-12

The measurements below are read-only approximations using file length divided
by four. They help compare files; they are not billing claims.

- Global Claude source: 17,053 bytes, 289 lines, about 4,239 tokens.
- Installed Claude global on `al8960ofc`: 18,038 bytes, 306 lines, about 4,484
  tokens. It is not byte-identical to the source because local machine context
  is appended.
- Global Codex source: 16,258 bytes, 282 lines, about 4,036 tokens.
- Installed Codex global on `al8960ofc`: 18,949 bytes, 325 lines, about 4,705
  tokens. It is not byte-identical to the source because machine facts are
  appended.
- This repo's `AGENTS.md`: 47,123 bytes, 707 lines, about 11,731 tokens.
- This repo's `CLAUDE.md`: 2,278 bytes, 47 lines, about 566 tokens.
- Managed set audited: 52 files and about 121,425 approximate tokens across two
  globals, repo instructions, and 48 skills. This total is **not** loaded on
  every turn. Skills are conditionally selected, so treating the full skill
  library as prompt overhead would be a serious analysis error.
- Skill source counts: 17 shared, 18 Claude-only, and 13 Codex-only.
- Skill bodies are task-triggered, but the per-client catalog of skill names and
  descriptions is startup context used for skill selection. The baseline must
  measure that manifest separately for Claude and Codex. The initial audit did
  not yet calculate this number.
- Four installed skill sources differ from the current repository on this
  machine: Claude `kimi-code-delegation`, Claude `shared-db-handover`, Claude
  `shared-db-orchestrator`, and Codex `kimi-code-delegation`.
- Fourteen exact duplicate paragraph groups of at least 180 characters exist
  across skills. Most are deliberate client pairs, especially Qwen; one large
  group is shared between Claude and Codex documentation-update skills.
- `templates/system/AGENTS-global-codex.md:44-47` still says Codex has no skills
  system. That statement is stale: the repo has `skills/codex/`, installs them
  into `~/.codex/skills/`, documents Codex skills, and the current Codex runtime
  receives their name/description catalog. The stale sentence is itself a
  context-ownership defect.
- Model-version text is inconsistent: the global safety rule names GPT-5.6,
  while `config/models.env.example`, older staged prompt filenames, the current
  repo `CLAUDE.md`, a cost-efficiency template, and the context-optimizer skill
  still mention GPT-5.4 or GPT-5.5. Some may be intentional historical or role
  names. The ownership audit must classify each before changing it; do not
  mechanically replace model strings.
- The two global templates duplicate material intentionally, including response
  style, production-cloud safety, 1Password serialization, and Synology long-read
  safety. Because the two clients load different global files, cross-file
  duplication does not itself double one client's prompt. It does create drift
  risk and maintenance cost.
- Representative application `AGENTS.md` sizes vary widely: about 4,150 tokens
  for `devops-mcp`, 11,566 for `poppim-web`, 13,181 for `popcrm-web`, 26,293 for
  `popdam3`, 34,670 for `oracle`, and 40,316 for `shared-db`.
- Representative `CLAUDE.md` files tell Claude to read `AGENTS.md` but use prose
  links rather than the `@AGENTS.md` import mechanism. They range from about 318
  to 1,445 tokens. Several repeat shared-database, deployment, branch, and commit
  rules already present globally or in `AGENTS.md`.

### Git and deployment state

- Branch: `main`
- Local/remote base at audit start: commit
  `c23303cb90dd7dd7ac8c71d103480deaff759776`
- Existing unrelated untracked work was present and must remain untouched:
  `.ai/` and `docs/claude-remote-control-hardening-v2.md`.
- No context implementation is committed, pushed, installed, or deployed.
- The only planned-session artifacts are this file and its linked handoff.

## 6. Key findings and root cause

### Finding 1: the architecture is already context-engineered

The repo already separates global rules, repo routing, skills, machine facts,
memory, plans, and handoffs. The correct project is consolidation, measurement,
and enforcement, not adopting the X post's six-file pattern.

### Finding 2: the largest immediate cost is always-loaded prose

On this repo, Claude can begin with about 4,484 tokens of user-level instruction,
566 tokens of repo-specific Claude notes, and then be told to read an 11,731-token
`AGENTS.md`. Codex receives a comparable global plus the same large repo router.
The application repos can be larger. The router contains valuable reference
material, but much of it is topic detail that could live behind links.

### Finding 3: “move everything into files” is not enough

Files save context only when the agent receives a pointer and reads the file on
demand. If every session is instructed to read every file, the tokens simply
move. This directly answers the skeptical reply under the X post. The design
must distinguish always-loaded, required-at-start, and task-triggered material.

### Finding 4: global duplication is partly required, skill duplication is not

Claude and Codex require separate global entry files, so identical non-negotiable
safety text may need generated or synchronized client outputs. In contrast,
identical skill behavior should normally live once under `skills/shared/`, as
`CLAUDE.md:24-33` already requires. Exact duplicate Qwen skill paragraphs show a
candidate consolidation, but client-specific invocation differences must be
proven before moving them.

### Finding 5: installer policy preserves local edits but permits drift

`bin/ai-install-skills:208-224` seeds globals only when absent on its Bash path.
The native Windows installer separately implements the same policy, and
`bin/setup-machine.ps1:185-192` calls that PowerShell implementation. Existing
globals are not overwritten. That prevents destructive loss of local facts but
also means repo source changes do not automatically reach established machines.
The same tension appears in skill installation state: four drifted installed
skills were found on this machine. A safe solution needs managed blocks or a
three-way reconciliation in both installer implementations, not blind overwrite.

### Finding 6: size alone cannot decide what to remove

The longest rules include production protection, shared-database discipline,
secret handling, wrong Git identity prevention, the Windows Codex junction bug,
and measured wrapper failure modes. Removing them because they are verbose could
repeat costly incidents. Each reduction needs a rule-level owner, trigger, and
verification test.

### Finding 7: the graph idea already exists at the workflow level

The seven-stage pipeline, plan status tables, review wrappers, tests, deployment
checks, and bounded debate loops are execution graphs in practical terms. A new
graph product would add moving parts without a demonstrated missing capability.

### Finding 8: Windows has a parallel installer that can invalidate a pilot

The initial draft incorrectly treated `bin/ai-install-skills` as the path used by
Windows setup. In fact, `bin/setup-machine.ps1:185-192` invokes
`bin/install-ai-devops-windows.ps1`, which independently implements managed
skills, quarantine, and global seeding. A change made only in the Bash installer
would never run in the proposed Windows pilot. Installer parity is therefore an
explicit implementation and test requirement.

### Finding 9: skill descriptions belong in the startup baseline

Skill bodies are progressively disclosed, but clients must receive enough skill
metadata to select them. The `name` and `description` catalog is therefore part
of startup context for both Claude and Codex. Descriptions should remain precise
enough to trigger correctly, but their length and overlap must be measured. This
is a safer first optimization than trimming procedure bodies blindly.

### Finding 10: Codex's stale global summary duplicates its live skill catalog

The Codex global template both claims that Codex has no skills and embeds long
ritual summaries, while the current runtime also receives installed Codex skill
names and descriptions. The audit must compare the always-loaded ritual-summary
block against the skill catalog. The likely fix is a short routing rule plus live
skills, but only runtime trigger tests may decide what summary can be removed.

### Root cause

The system grew by preserving every hard-won lesson near the place where it was
needed. That correctly reduced repeat incidents, but no automated ownership and
context-budget gate prevents the same rule from living in global instructions,
repo files, skills, and docs at once. Installers also protect local changes so
strongly that source and installed state can silently diverge, and the Bash and
native Windows implementations can diverge from each other. The permanent fix is
a tested ownership model plus cross-installer parity and safe reconciliation,
not a one-time edit.

## 7. Approaches considered and rejected

1. **Create six files named decisions, contracts, dead ends, state, sources, and
   open questions in every repo. Rejected.** Existing `AGENTS.md`, topic docs,
   plans, `HANDOFF.d/`, and memory already own those roles. Six more files would
   duplicate state and invite contradiction.
2. **Adopt a knowledge graph or GraphRAG service. Rejected.** No measured task in
   this audit requires semantic relationship search. File paths, `rg`, routers,
   and skills already provide just-in-time discovery with fewer moving parts.
3. **Delete long instructions until token counts look good. Rejected.** Length is
   not a proxy for low value. Safety and incident-derived constraints need tests
   before relocation or compression.
4. **Make every `CLAUDE.md` only `@AGENTS.md`. Rejected as a blanket rule.** This
   may remove valid Claude-only tool and ignore guidance, and importing a huge
   `AGENTS.md` can increase automatic startup context. It should be evaluated on
   representative repos, not assumed.
5. **Blindly overwrite installed global files from templates. Rejected.** This
   would erase machine-specific facts and local configuration. The current
   non-clobber behavior exists for a sound reason.
6. **Keep identical Claude/Codex skills forever. Rejected.** It preserves client
   drift and doubles maintenance. Shared behavior belongs under `skills/shared/`
   unless a measured client difference requires an adapter.
7. **Deduplicate the two global files through runtime imports without testing
   client behavior. Rejected.** Claude and Codex have different discovery and
   loading rules. The safe design is one canonical shared source rendered or
   validated into client entrypoints, unless both clients officially support the
   same import semantics.
8. **Assume prompt caching makes large stable globals free. Rejected.** Cache
   behavior, lifetime, and billing vary by product. Cached input is still context
   that can reduce attention quality.
9. **Run a broad rewrite across all repos at once. Rejected.** It would make
   regressions hard to attribute. A pilot and measured rollout are required.

## 8. Design decisions

### Locked decisions, 2026-08-12

1. **Safety outranks token reduction.** Production, shared-database, secrets,
   destructive-action, identity, and Windows sandbox rules cannot be dropped.
2. **One durable owner per fact or rule.** Other locations link or carry a short
   client adapter. Unexplained copies are defects.
3. **Use existing artifact roles.** Global = universal behavior; machine atlas =
   machine facts; repo `AGENTS.md` = router and repo invariants; topic docs =
   detail; skills = triggered procedures; memory = durable learned facts; plan =
   forward work; handoff = active session state.
4. **No six-file convention and no graph service without a measured need.**
5. **Skills stay progressively disclosed.** Do not preload the full skill body or
   count the whole library as startup context.
6. **The rollout uses ai-devops scripts only.** No hand-edited machine configs.
7. **The first rollout target is one Windows dev box.** Do not fan out an
   unproven prompt change.
8. **Every reduction has a behavioral test and rollback.** File-size improvement
   alone is not success.
9. **Preserve Albert's GPT-5.6 low/medium limit.** Context work does not authorize
   model-setting changes.

### Open decisions for the implementing session

1. Whether shared global text should be generated from fragments, validated by a
   parity test, or expressed through supported imports. Choose the simplest
   method that preserves exact client behavior and produces reviewable Markdown.
2. Initial context budgets. Establish baselines first; do not invent hard limits.
   A reasonable first target is a 25-40% reduction in always-loaded global plus
   repo-start text with zero safety-test failures, but measured quality decides.
3. Which application repo is the second pilot after `ai-devops`. Prefer one
   medium repo and one high-risk large repo, likely `poppim-web` and `shared-db`,
   after checking for concurrent work.
4. Whether installed-global reconciliation uses explicit managed markers or a
   separate generated base plus machine overlay. Choose based on safe preservation
   tests, not convenience.

## 9. The implementation plan

### Phase A: baseline and ownership

#### Step 1. Freeze a measured baseline

**Targets:** add a dependency-free read-only audit under `tools/context-audit/`
or `tests/`; do not install a new CLI unless the pilot proves a recurring
operational need. Add fixtures/tests under `tests/`; record the baseline in
`docs/context-engineering.md`; inspect both `bin/ai-install-skills` and
`bin/install-ai-devops-windows.ps1`.

The audit must classify files as always loaded, startup-routed, task-triggered,
or archive/ignored. It must measure the per-client skill `name` + `description`
manifest separately from task-triggered skill bodies. It must report bytes,
lines, a clearly labeled token estimate, exact duplicate paragraphs, broken doc
links, duplicate skill names, installed source drift, cross-installer behavior
drift, and required safety-marker presence. It must exclude `.git/`,
transcripts, chat archives, dependencies, generated output, worktrees, `.ai/`,
secrets, and network drives. It must never read secret values.

Count tracked source skills with a deterministic filesystem or Git-index method,
not one glob pass. During this audit GLM's glob silently omitted the real tracked
`skills/shared/secrets-to-1password/SKILL.md` and produced a false count.

**Dependencies:** none.

**Verification gate:** a clean checkout produces a stable machine-readable JSON
report and human summary; two consecutive runs match apart from timestamps; a
fixture containing a secret-like `.env` proves the audit skips it; the existing
test suites remain green.

**Natural context cut:** start a fresh session after the audit tool and fixtures
are committed and pushed. Re-read the remaining phases before continuing.

#### Step 2. Define the context ownership map

**Targets:** create `docs/context-engineering.md`; update the documentation maps
in `AGENTS.md`, `docs/skills-usage-guide.md`, and
`docs/codex-skills-usage-guide.md`.

For every class of information, name its canonical owner, who loads it, when it
loads, maximum useful detail, and how another artifact links to it. Include a
decision table for global vs machine vs repo vs topic doc vs skill vs memory vs
plan vs handoff. Define “pointer” as a path/link plus a clear trigger, not a vague
mention. Define stale-state rules and deletion/retention ownership.
Correct the Windows rows in `docs/skills-usage-guide.md` that still teach the
Bash-only installer path; name the native PowerShell installer and the exact
platform routing.

**Dependencies:** step 1 baseline.

**Verification gate:** reviewers can classify ten representative existing rules
without disagreement; every destination exists; link checking passes; no rule is
assigned to two canonical owners.

### Phase B: enforcement before reduction

#### Step 3. Add context-audit tooling and regression tests

**Targets:** the audit tool from step 1; `tests/test-ai-install-skills.sh`,
`tests/test-install-ai-devops-windows.ps1`, `tests/test-windows-scripts.sh`, and
new focused tests such as
`tests/test-context-audit.ps1` if PowerShell is required.

Add configurable warning budgets, not immediate hard failures, for global,
repo-start, and per-client skill-description context. Add exact safety-marker
tests for production mutation,
shared-db change routing, secret handling, destructive actions, Git identity,
and GPT-5.6 low/medium limits. Add cross-client parity tests for rules that must
match and divergence allowlists for client-only behavior. Add duplicate skill
body detection, global ritual-summary versus skill-description overlap, and
source/installed drift reporting. Reuse `tools/skill-trigger-eval/` for Claude
description quality. Add a separate Codex runner because the current harness is
Claude-specific. The context audit measures size and duplication; trigger evals
measure selection quality. Neither replaces the other.

**Dependencies:** steps 1-2.

**Verification gate:** each test fails when its marker is removed from a fixture,
passes with the real sources, and emits a plain reason. Budgets warn on current
state and can be ratcheted only after measured reductions.

### Phase C: reduce always-loaded context

#### Step 4. Slim the global files

**Targets:** `templates/system/CLAUDE-global.md`,
`templates/system/AGENTS-global-codex.md`, selected shared fragments or validation
data if chosen, `templates/system/machine-atlas.md`, installer tests, and relevant
usage docs. Include both `bin/ai-install-skills` and
`bin/install-ai-devops-windows.ps1` anywhere installation behavior changes.

Keep universal response style, authority boundaries, production/cloud safety,
secret rules, destructive-action rules, model-effort rule, Git identity gate,
and the short routing contract always loaded. Move detailed procedures, incident
histories, machine facts, long handoff templates, and provider-specific workflows
behind skills or topic-doc links. A link must say exactly when to load its target.
Do not shorten a rule until its behavioral test exists. Correct the stale
`AGENTS-global-codex.md:44-47` claim only after Codex skill-loading and trigger
tests capture current behavior.

**Dependencies:** step 3 enforcement.

**Verification gate:** required-marker tests pass; both installed-client fixtures
load the correct global and overlay; a representative Claude and Codex session
correctly answers safety and routing probes without opening unrelated docs;
always-loaded measured text falls materially from baseline with no quality loss.

#### Step 5. Tighten `AGENTS.md` as a router

**Targets:** `AGENTS.md`, affected topic docs, `CLAUDE.md`, and router-link tests.

Keep project summary, task-to-doc map, boundaries, identifiers needed for most
tasks, what to ignore, active plan links, and truly repo-wide invariants. Move
full incident narratives and specialist procedures to named docs or skills. Keep
one-sentence warnings and direct pointers in the router. Validate whether Claude
should use an `@AGENTS.md` import or explicit read instruction; do not enable both
if that duplicates the file in context.

**Dependencies:** step 4 and ownership map.

**Verification gate:** every current documentation-map task still resolves to
the correct source; a fresh Claude and Codex session can orient in under five
minutes; link tests pass; incident-specific probes find the detail only when
triggered; startup context is lower than baseline.

**Natural context cut:** start a fresh session after global/router changes are
committed, pushed, and proven on local fixtures. Do not install them broadly yet.

### Phase D: skill consolidation and safe installation

#### Step 6. Consolidate cross-client skill duplication

**Targets:** proven duplicate pairs under `skills/claude/` and `skills/codex/`,
new or existing canonical packages under `skills/shared/`, installer collision
tests, and both skills usage guides.

Start with exact-body candidates such as Qwen. Separate shared policy from a
small client adapter only when invocation differs. Do not merge skills merely
because paragraphs match. Preserve trigger descriptions and tool-specific safety
rules. Retire old managed copies through the existing quarantine mechanism.
Correct `docs/codex-skills-usage-guide.md:84`: `--migrate-obsolete` is now a
no-op, while managed orphan quarantine is automatic.

**Dependencies:** steps 2-3.

**Verification gate:** the installer fails closed on name collisions; both client
install fixtures receive the intended skill; trigger tests still fire on real
prompts; client-only commands remain correct; duplicate paragraph report falls
without new cross-file contradictions.

#### Step 7. Repair installation drift safely

**Targets:** `bin/ai-install-skills`, `bin/install-ai-devops-windows.ps1`,
`bin/setup-machine.ps1`, config templates or managed-block metadata chosen in
step 8, and installer tests.

Implement preview-first reconciliation. Preserve unowned local files and machine
overlays. Show the exact source/installed differences. Require an explicit
managed boundary before replacing a global. Keep recoverable backups or generated
base files and prove idempotence. Implement equivalent behavior in the Bash and
native PowerShell installers. Do not add a second sync system.

`bin/setup-machine.ps1:187,192` currently invokes the native installer through
Windows PowerShell 5.1 (`powershell`), even though setup itself requires
PowerShell 7. The implementation must either keep
`bin/install-ai-devops-windows.ps1` fully 5.1-compatible or deliberately change
those calls to `pwsh` and add a regression test for the new requirement. Decide
explicitly; do not introduce PowerShell 7-only syntax into a 5.1 child path.

**Dependencies:** stable source layout after steps 4-6.

**Verification gate:** fixtures cover absent, identical, locally extended,
locally conflicting, obsolete managed, and vendor-unmanaged files; dry-run makes
no writes; apply preserves overlays; second apply makes no changes; no duplicate
TOML keys; installed skill hashes match sources; Bash/PowerShell parity tests
prove both installers produce the same managed skill/global outcome.

### Phase E: controlled pilot and rollout

#### Step 8. Pilot on one Windows machine

**Targets:** `al8960ofc` first unless concurrent work makes another dev box safer;
the current repo plus one medium and one large/high-risk application repo.

Before install, save hashes and recoverable copies of the installed global files,
list managed skills, and record real usage from matched Claude and Codex tasks.
Run installer dry-run, inspect it, then install. Fully restart clients so startup
context reloads. Run routing, safety, task-quality, token/cache, and no-drift
probes. Use identical tasks and comparable fresh sessions for before/after data.
Capture the native PowerShell installer's output and assert that the new
reconciliation path actually executed; command success alone is insufficient.

**Dependencies:** steps 1-7 committed and all named local Bash/PowerShell suites
from `docs/development.md` passing. This repo has no GitHub Actions CI.

**Verification gate:** all safety probes pass, real tasks complete correctly,
no machine facts disappear, installed hashes/overlays match design, and measured
always-loaded global/router/manifest size falls without material extra tool calls
or latency. Task correctness and safety are hard gates. Total input, cached
input, billed cost, and dollar savings are report-only when the product exposes
official fields; lack of a subscription usage field or a billed-token drop does
not fail an otherwise correct pilot. Roll back immediately on any safety or
correctness regression.

#### Step 9. Roll out to all configured machines

**Targets:** `916-alien`, `albt16`, remaining managed Windows boxes, then Ubuntu
AI users. Use `bin/setup-machine.ps1`, `bin/install-ai-devops-windows.ps1`, and
`bin/ai-install-skills` only through their documented platform paths.

Check reachability and concurrent work first. Pull `main` fast-forward-only. Run
dry-run and diff review per machine. Install, restart the affected clients, and
run `ai-devops doctor`, source/install hash checks, memory task checks, and a
short behavior probe. Do not touch production workload state.

**Dependencies:** step 8 verification-gate evidence recorded in this plan's
STATUS table. No separate human approval is required by this plan.

**Verification gate:** every reachable machine reports the expected commit,
correct global base plus overlay, current managed skills, GPT-5.6 low/medium,
working Codex sandbox canary, and no secrets in committed or generated config.
Offline machines remain explicitly open in the plan and handoff.

### Phase F: evaluation and closeout

#### Step 10. Measure, ratchet budgets, and close

**Targets:** `docs/context-engineering.md`, this plan's STATUS table, tests,
relevant memory entry, and this session's/future implementer's own handoff.

Compare before/after startup context, total input, cached input where officially
reported, tool calls, latency, task success, safety probes, and user corrections.
Set warning or failure budgets only from the observed safe result. Record cases
where more context was necessary. Delete this plan's open handoff only when all
reachable rollouts and acceptance checks are proven; keep unavailable machines
as an explicit separate open workstream if necessary.

**Dependencies:** steps 8-9.

**Verification gate:** report includes reproducible commands and official usage
fields, not estimates; all STATUS rows are current; Git author identity is
correct; focused commits are pushed to `main`; all named local Bash/PowerShell
suites pass; there is no GitHub Actions CI and no deploy because this toolkit has
no hosted service; installed state matches the pushed commit on every completed
machine.

## 10. Tests required

1. **Context classification test:** fixtures prove always-loaded, routed,
   triggered, and ignored files are counted separately.
2. **Secret exclusion test:** `.env`, credential, transcript, chat, `.git`, `.ai`,
   dependency, generated, worktree, and network-root fixtures are never opened.
3. **Stable output test:** repeated audits produce identical content after
   timestamp normalization.
4. **Safety-marker test:** independently remove each locked safety category from
   a fixture and require a clear failure naming the missing category.
5. **Cross-client parity test:** shared global rules match semantically or through
   canonical fragment identity; allowed client differences are explicit.
6. **Skill-description manifest test:** measure name/description startup text per
   client; warn on descriptions that are long, duplicative, or too vague to
   trigger reliably. Reuse the existing Claude trigger-eval harness and add a
   separate Codex runner; do not pretend size measurement proves trigger quality.
7. **Duplicate-skill test:** shared/client name collisions fail; exact duplicate
   client skills and global ritual-summary versus skill-description overlap
   generate consolidation warnings.
8. **Broken-pointer test:** all router, skill, plan, and handoff links resolve.
9. **Installer dry-run test:** reports changes and writes nothing.
10. **Installer reconciliation matrix:** absent, same, local overlay, local
   conflict, managed obsolete, and unmanaged vendor files behave as designed.
11. **Bash/PowerShell installer parity test:** equivalent fixtures produce the
    same installed managed files, quarantine results, overlays, and diagnostics.
12. **Idempotence test:** a second installation changes nothing.
13. **Windows path test:** `%USERPROFILE%` wins over a misleading `HOME`; no file
    lands on `Z:`.
14. **Codex TOML test:** no duplicate keys and no Claude script touches Codex
    config outside its named managed block.
15. **Behavior probes:** Claude and Codex both route a shared-db change, a
    production request, a normal code fix, an old-session continuation, and a
    Windows Codex sandbox diagnosis correctly.
16. **Representative task evaluation:** at least five matched before/after tasks
    across simple, repo-navigation, implementation, high-risk, and long-horizon
    work. Record correctness, total/cached input where exposed, tool calls,
    elapsed time, and required human correction.
17. **Existing suites:** run the complete existing Bash and PowerShell test
    suites named by `docs/development.md`; no current test may be skipped silently.

## 11. Constraints, standing rules, and gotchas

- Work on `main`. Preserve unrelated `.ai/` and
  `docs/claude-remote-control-hardening-v2.md` work.
- Before every commit, `git var GIT_COMMITTER_IDENT` must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- GPT-5.6 reasoning must remain explicitly `low` or `medium`.
- No production/shared-cloud mutation. Never run Terraform apply/destroy or
  mutating production `gcloud` commands.
- No shared Supabase change is required. If that changes, stop and use the
  canonical `shared-db` branch/PR workflow first.
- Never read or expose secrets, transcript contents, auth files, `.env` values,
  or licensed private data.
- Serialize 1Password operations. This plan should not need any secret read.
- Use PowerShell 7 for `setup-machine.ps1`. Its current child invocation of
  `install-ai-devops-windows.ps1` uses Windows PowerShell 5.1 at lines 187 and
  192, so keep that child 5.1-safe or explicitly migrate the invocation to
  `pwsh` with tests. A bare `bash` may be WSL and not inherit Windows environment
  variables; use the correct native or Git Bash path.
- Do not hand-edit `C:\Users\ahazan2\.codex\config.toml` or Claude config. Use
  repo installers and managed blocks only.
- Do not trust `codex --version` as a functional check. Run the real sandbox
  write canary in `ai-devops doctor`.
- Installed globals currently contain local additions. Preserve them until the
  overlay design proves safe.
- The full skill library is not always-loaded context. Do not optimize the sum of
  all skill bodies as if it were a per-turn cost.
- Exact duplicate text can be intentional when clients need separate entry files.
  Optimize maintenance ownership and runtime context separately.
- Plans and handoffs serve different jobs. Do not combine them or rewrite root
  `HANDOFF.md`.
- Any unavoidable workaround must be labeled TEMPORARY in the implementing
  session's own handoff.

## 12. Access and environment

- GitHub CLI `gh`, Git, PowerShell 7, Claude Code, Codex, `ai-glm`, and
  `ai-grok-review` are expected on `al8960ofc`; verify with real doctor/status
  calls before relying on them.
- Repository: `C:\repos\ai-devops`, `main`, remote
  `https://github.com/u2giants/ai-devops`.
- Machine facts: `templates/system/machine-atlas.md`.
- Config ownership: `docs/config-inventory.md`.
- Skill installation: `bin/install-ai-devops-windows.ps1` on native Windows;
  `bin/ai-install-skills` on Ubuntu/Git Bash where documented.
- Windows setup: `bin/setup-machine.ps1`.
- Secrets, if an unrelated validation unexpectedly needs them, live only in the
  1Password vault `vibe_coding`; never place values in a prompt or plan.
- There is no local server to start and no URL to deploy for this toolkit.
- Delegate review artifacts belong under `.ai/reviews/`, which is untracked and
  must not be committed.

## 13. Definition of done, rollback, risks, and open questions

### Definition of done

- [ ] Baseline audit is reproducible and excludes sensitive/irrelevant paths.
- [ ] Ownership map assigns every rule class one canonical home.
- [ ] Locked safety rules have regression tests.
- [ ] Always-loaded global plus repo-start context is materially smaller.
- [ ] Representative task quality and safety are equal or better.
- [ ] Cross-client skill duplicates are consolidated only where behavior matches.
- [ ] Installed/source drift is visible and safely reconcilable.
- [ ] One Windows pilot passes before broad rollout.
- [ ] Every reachable managed machine is verified against the pushed SHA.
- [ ] Offline machines have a separate accurate open handoff.
- [ ] All named local Bash and PowerShell tests pass. This repo has no GitHub
      Actions CI and no CI gate may be invented.
- [ ] Documentation, memory, plan STATUS, and handoffs describe current reality.
- [ ] Focused commits are pushed to `main`; local and `origin/main` match.
- [ ] No hosted deployment is claimed because none exists.

### Rollback

Keep pre-install hashes and recoverable copies of installed globals and managed
skill manifests for each pilot machine. If a behavior or safety probe fails,
restore the prior generated base/overlay through the same installer mechanism,
restart the clients, rerun the failing probe and `ai-devops doctor`, and record
the failure in the plan and an open handoff. Never use `git reset --hard`, delete
unowned skill directories, or overwrite local overlays to roll back.

### Risks

1. Shortening prompts can remove a rare but critical safety condition.
2. Moving detail behind a link can fail if the trigger is vague or the target is
   not reachable.
3. Generated shared fragments can make Markdown harder to review if the build is
   opaque. Prefer transparent source and deterministic output.
4. Provider updates can change loading, compaction, caching, or skill behavior.
5. Before/after token comparisons can be invalid if models, tasks, sessions, or
   cache state differ.
6. Existing machine-local additions can be lost by an unsafe reconciliation.
7. Application repo routers may require separate plans because they contain
   business-critical detail and concurrent work.

### Open questions and decision criteria

1. **Managed base plus overlay, managed blocks, or generated client globals?**
   Decide after fixture tests. Choose the smallest design that preserves local
   facts, is deterministic, and is reviewable without a custom parser.
2. **What budget should become a gate?** Use pilot distributions. Warn first;
   fail only after safe stable baselines exist.
3. **Does `@AGENTS.md` improve Claude startup behavior?** Test actual loaded
   context and task quality. Do not infer from syntax alone.
4. **Which application repos need their own follow-up plan?** Use the audit to
   rank always-loaded size, duplication, risk, and task frequency. Do not bulk
   rewrite them under this plan.

## Review and debate record

This section must be updated after each independent review. Reviews occur in
this order: Claude, GLM 5.2, then Grok 4.5. Each reviewer must answer:

1. What material evidence or background is missing?
2. Which conclusions are wrong or unsupported?
3. What proposed work is unnecessary or too complex?
4. What safety, rollout, or measurement failure could invalidate the plan?

The planning agent must challenge unsupported reviewer claims, update this file
only for evidence-backed corrections, and run bounded follow-up turns until
there is evidence-backed consensus or the documented turn/cost limit is reached.
Agreement without re-reading the current plan and evidence is not consensus.

### Claude review

Claude completed a read-only review with Opus through Claude Code 2.1.217. It
re-read the plan and named source files. Its material objections were:

1. **Accepted:** the initial plan named the wrong Windows installer path. Claude
   proved `bin/setup-machine.ps1:185-192` calls
   `bin/install-ai-devops-windows.ps1`, not `bin/ai-install-skills`. The plan now
   requires changes and parity tests in both implementations.
2. **Accepted and broadened:** the plan omitted always-visible skill manifest
   metadata. Claude stated this for Claude Code; the correction applies to both
   Claude and Codex because both clients need the name/description catalog to
   select skills. Bodies remain task-triggered.
3. **Accepted:** code citations were corrected from header comments to the Bash
   install functions at `bin/ai-install-skills:122-150` and `:208-224`.
4. **Accepted:** step 6/7 must correct the stale
   `docs/codex-skills-usage-guide.md:84` statement that
   `--migrate-obsolete` performs quarantine; `bin/ai-install-skills:74` now treats
   it as a no-op while managed orphan quarantine is automatic.
5. **Accepted framing correction:** benefits must lead with attention quality and
   correctness, not promise marginal billed savings on stable cached prefixes.
6. **Rejected as a removal:** Claude questioned whether the audit/tests are too
   heavy before trimming prose. Because these files govern production safety,
   secrets, database discipline, destructive action, and multiple machines, the
   tests remain before broad reduction. The implementation may keep the audit
   tool small and dependency-free, but it may not trim locked controls before
   their regression gates exist.

After these corrections, Claude's two high-severity objections are addressed in
the current plan. The plan will be relayed to GLM and Grok for independent
challenge rather than treating Claude's answer as authority.

### GLM 5.2 review

GLM 5.2 completed an initial review and one rebuttal in the persistent read-only
session `context-engineering-consolidation-review`.

Initial GLM findings:

1. **Accepted:** reuse `tools/skill-trigger-eval/` for Claude description quality
   rather than building a competing trigger mechanism. A Codex runner is still
   needed because the current tool is Claude-specific.
2. **Accepted:** detect duplication between Codex's inline global ritual summaries
   and live skill descriptions, not only duplication among skill bodies.
3. **Accepted with caution:** record GPT-5.4/5.5/5.6 text drift as an ownership
   audit case. Do not mechanically replace strings because some names may be
   historical stage identifiers or intentional model roles.
4. **Accepted:** prefer a small dependency-free test script over a permanently
   installed `ai-context-audit` command unless an operational use proves the CLI
   is necessary.
5. **Rejected after debate:** GLM initially claimed Codex had no skill system,
   relying on stale `AGENTS-global-codex.md:44-47`. Current Codex runtime,
   official OpenAI material, `skills/codex/`, the installer, and the repo's Codex
   usage guide prove the statement is stale. GLM retracted the objection.
6. **Rejected after debate:** GLM's glob silently omitted the tracked
   `skills/shared/secrets-to-1password/SKILL.md`, leading it to claim 16 shared
   skills and a dangling reference. Direct filesystem and Git-index evidence
   proved 17 shared skills and a real installed source. GLM retracted both claims
   and recommended deterministic counting rather than a single glob.

Final GLM position: no material objection remains to the plan's structure, root
cause, scope, safety gates, installer parity, or pilot. The accepted additive
refinements are now in findings 9-10, steps 1, 3-4, and tests 6-7. GLM usage was
reported by the wrapper; no money figure is available for GLM.

### Grok 4.5 review

Grok 4.5 completed the initial read-only review through `ai-grok-review` using
the pinned `grok-4.5-build` model. It reported 594,170 tokens, 498,432 cached
tokens, nine turns, and cost `$0.3848336`.

All six material objections were accepted:

1. The repo has no GitHub Actions CI, so every “CI green” gate was replaced with
   the named local Bash and PowerShell suites from `docs/development.md`.
2. The pilot now treats safety, correctness, overlays, and reduced always-loaded
   text as hard gates. Provider input/cache/cost fields are report-only when
   officially exposed; billed-token reduction is not a required pass condition.
3. Step 3 now names `tests/test-install-ai-devops-windows.ps1`, and the access
   section names the native Windows installer explicitly.
4. The plan now records that `setup-machine.ps1:187,192` invokes the installer
   through Windows PowerShell 5.1. Implementation must preserve 5.1 compatibility
   or deliberately switch to `pwsh` with tests.
5. “Pilot approval” was replaced by an evidence gate recorded in STATUS so the
   implementer does not stop and ask Albert for an undefined approval.
6. The audit defaults to a dependency-free tool/test script. A permanently
   installed CLI requires a proven operational need.

Grok also noted that this handoff lagged the plan review state; it is corrected.
The corrected plan was sent back to the same Grok session for a bounded
consensus check. Grok re-read the plan and handoff, marked all six objections
resolved, found no new conflict, and reported no remaining material objection.
The follow-up used 300,046 tokens, 279,424 cached tokens, three turns, and cost
`$0.1340952`. Total Grok review cost was `$0.5189288`, below the `$1.50` ceiling.

### Final consensus ledger

#### Agreed decisions

1. Preserve safety and correctness before optimizing size or billed tokens.
2. Use one canonical owner per fact and existing artifact roles rather than the
   X post's six-file convention.
3. Do not add a graph/GraphRAG service without a measured missing capability.
4. Measure always-loaded globals, repo-start text, and skill metadata separately
   from task-triggered skill bodies.
5. Test locked safety rules before moving or shortening their text.
6. Keep Bash and native Windows installers behaviorally aligned and preserve
   machine overlays through preview-first reconciliation.
7. Reuse the Claude trigger-eval harness, add a Codex runner, and test selection
   quality separately from text size.
8. Pilot one Windows machine first. Hard gates are safety, correctness, overlay
   preservation, and reduced always-loaded text. Provider token/cache/cost fields
   are report-only where officially exposed.
9. Use named local Bash/PowerShell suites. This repo has no GitHub Actions CI.
10. Preserve PowerShell 5.1 compatibility for the current child installer path
    or deliberately migrate it to `pwsh` with tests.

#### Rejected alternatives

The nine alternatives in section 7 remain rejected. The reviews also reject
inventing CI, requiring billed-token savings as a hard pass, requiring undefined
human pilot approval, installing a permanent audit CLI without operational need,
trusting the stale “Codex has no skills” sentence, and treating one failed glob
as proof a tracked skill is absent.

#### Unresolved objections

None material. Claude's two high-severity findings, GLM's supported refinements,
and Grok's six practical gaps are resolved in the current plan.

#### Evidence still needed during implementation

1. Exact step-1 baseline and installed/source drift remeasurement.
2. Live Claude and Codex trigger evidence before deleting ritual summaries or
   merging client skills.
3. Pilot discovery of which official token/cache/cost fields each product exposes.

These are implementation gates already assigned to steps 1, 4, 6, and 8. They do
not require Albert to answer a planning question.

## Mandatory plan self-audit

### 1. Could a brand-new AI session execute this without asking Albert anything?

Yes. Sections 1-5 define the business goal, toolkit, repositories, machines,
trigger, scope, exact baseline, and current Git state. Sections 9-12 give ordered
file targets, dependencies, tests, verification gates, access, and platform
constraints. Section 13 defines completion and rollback.

### 2. Does the plan preserve all current background, nuance, and rejected work?

Yes. Sections 3 and 6 distinguish supported context-engineering evidence from
the X post's unsupported marketing. Section 7 records nine rejected approaches
and why. Section 8 separates locked rules from real implementation choices.
The review record will preserve material corrections from Claude, GLM, and Grok.

### 3. Is the goal clear enough to guide a judgment call if a step is wrong?

Yes. Section 1 defines the desired business outcome and explicitly says the goal
wins over a conflicting step. Sections 8 and 13 state the safety priority,
decision criteria, risks, and rollback needed to choose correctly.

### Checklist result

All 13 required sections are present. The plan includes an explicit out-of-scope
list, file-specific steps, verification gates, named tests, locked/open decisions,
secret-safe access notes, commit/push/local-test completion, and mutual
plan/handoff links. The final post-debate self-audit passed on 2026-08-12.
