# Context engineering

This document records the measured baseline and the context ownership map for
reducing repeated Claude and Codex context safely. The active implementation and
decisions remain in
[`../plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md).

## Baseline frozen on 2026-08-12

The dependency-free audit at
[`../tools/context-audit/context-audit.py`](../tools/context-audit/context-audit.py)
measures four context classes:

| Class | Meaning | Current measured source |
|---|---|---:|
| Always loaded | User-level Claude and Codex global templates | 2 files, 33,311 bytes, about 8,329 estimated tokens (step 4 cut this to 25,764 bytes / about 6,442 tokens on 2026-08-12) |
| Startup routed | This repo's `AGENTS.md` and `CLAUDE.md` entry files | 2 files, 49,401 bytes, about 12,351 estimated tokens (this grew to 50,729 before step 5, which cut it to 35,972 bytes / about 8,994 tokens on 2026-08-12) |
| Task triggered | Skill bodies read only when selected | 48 files, 405,271 bytes, about 101,333 estimated tokens |
| Archive or ignored | Transcripts, chats, `.ai`, dependencies, generated output, worktrees, secrets, and network roots | excluded and never opened |

The estimate is bytes divided by four, rounded up per file. It is useful for
comparison only. It is not an exact model-token count and is not a billing
claim. The 48 skill bodies are not startup context.

Skill selection metadata is measured separately because clients need names and
descriptions before they can choose a skill:

| Client | Available skills | Name and description bytes | Estimated tokens |
|---|---:|---:|---:|
| Claude | 35 | 21,521 | about 5,381 |
| Codex | 30 | 14,015 | about 3,504 |

These manifest totals were corrected on 2026-08-12. The first published values
(Claude 18,448 bytes, Codex 10,593 bytes) were understated because the audit's
frontmatter parser read only single-line values and recorded the bare marker
`>-` for the seven skills that use folded YAML descriptions. The parser now
handles YAML block scalars, a regression test covers folded and CRLF
frontmatter, and the numbers above come from a rerun of the corrected tool.
Do not reuse the superseded values.

The first real-machine report found:

- no duplicate skill names;
- 12 exact normalized paragraph groups shared by two or more skill files,
  spanning 6 skill files and 3 distinct file pairs. An earlier manual estimate
  of 14 groups is superseded: it is not reproducible at any tested minimum
  paragraph length (100, 120, or 180 normalized characters), all of which
  return 12 over skill files. The tool's 12 is the measured number;
- no broken relative Markdown links in the audited router, plan, handoff
  pointer, global files, or skill files;
- no static capability difference between the current Bash and PowerShell
  installers for managed markers, collision refusal, orphan quarantine,
  non-clobbering global installation, and dry-run support. This is text pattern
  matching over both installers, not proof of full behavioral parity;
- all six required safety categories present;
- four installed skill files different from tracked source on `al8960ofc`;
- both installed global files different from source, as expected because local
  machine facts were appended under the current non-clobber policy.

The four drifted installed skills are Claude `shared-db-handover`, Claude
`shared-db-orchestrator`, Claude `kimi-code-delegation`, and Codex
`kimi-code-delegation`. This baseline only reports drift. It does not overwrite
or reconcile anything.

Drift is a SHA-256 comparison of raw bytes, so it is sensitive to line endings.
Running the audit from a different working copy of the same commit, such as a
Git worktree checked out with different CRLF normalization, can report extra
drifted skills that have identical content. Always measure drift from
`C:\repos\ai-devops` for comparability with this baseline.

## Context ownership map (step 2)

One rule, one home. Every class of information below has exactly one canonical
owner in this repo. Anywhere else the same information appears, it is either a
pointer (path plus trigger) or a short client adapter — never a second owner. Two
canonical owners for the same rule is the drift defect this map exists to
prevent. Trimming or moving any rule is a later plan step; this map only names
owners. The plan, phases, and gates live in
[`../plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md).

The map uses the four loading classes measured by the baseline above:

- **Always loaded** — read into every session at startup (the user-level
  globals). The most expensive context; keep only universal, high-frequency,
  safety-critical rules here.
- **Startup routed** — read at startup for this repo (the repo router and the
  Claude adapter).
- **Task triggered** — read only when a task needs it, reached through a pointer
  with a trigger.
- **Archive / ignored** — never loaded (transcripts, chats, `.ai`, deps,
  generated output, secrets).

### Per-class ownership

| Class of information | Canonical owner | Who loads it | When it loads | Maximum useful detail | How other artifacts link to it |
|---|---|---|---|---|---|
| Universal standing rules (every project, every session) | `templates/system/CLAUDE-global.md` (Claude) and `templates/system/AGENTS-global-codex.md` (Codex) | Claude reads `~/.claude/CLAUDE.md`; Codex reads `~/.codex/AGENTS.md` | Always loaded | The rule, a one-line reason, and a pointer to the full procedure. Incident narratives and long procedures live elsewhere. | `[full: skill-name]` or a path with a trigger ("for the full procedure, load skills/shared/<name>"). |
| Per-machine facts (paths, hosts, quirks, install state) | `templates/system/machine-atlas.md` | The machine's atlas section, appended to that machine's global | Startup, but only the section for the machine you are on | The fact plus which machine plus a one-line consequence | "see machine-atlas §<machine>" from any rule that depends on it. |
| Repo router plus repo-wide invariants (this toolkit) | `AGENTS.md` | Claude (told by `CLAUDE.md` to read it first) and Codex | Startup routed | One-screen orientation, the task-to-doc map, and the invariants that hold across this whole repo. Deep incident narratives and specialist procedures live behind pointers. | Doc-map rows are pointers (path plus trigger). |
| Repo-specific Claude adapter | `CLAUDE.md` | Claude Code | Startup routed | Only what Claude needs that `AGENTS.md` does not already cover (client-specific ignore/tool notes). Must not duplicate `AGENTS.md`. | Points to `AGENTS.md`; never restates it. |
| Topic detail (deep procedures, incident histories, how-to) | A `docs/<topic>.md` file | Nobody automatically | Task triggered | As much as needed — length is cheap here because it is not startup context. | A pointer in a global/repo/skill file: relative path plus the exact trigger condition. |
| Triggered procedures (skills) | `skills/shared/<name>/SKILL.md` (both clients) by default; `skills/claude/<name>/` or `skills/codex/<name>/` only when genuinely client-specific | The client skill loader | The per-client `name` plus `description` manifest is startup context (selection); the skill body is task triggered | Manifest: precise enough to trigger, not longer. Body: full procedure plus tool-specific safety. | `[full: skill-name]` or `/skill-name` with the trigger phrase. |
| Durable learned facts (cross-session, cross-machine) | `memory/` (per-project `MEMORY.md` plus fact files), synced by `bin/ai-sync-memory` | Claude memory recall; manually when needed | Project-scoped recall; not always loaded globally | Concise facts, not procedures. Memory is "what we learned", not "how to do X". | Referenced by path when a session needs it; never copied into a global. |
| Non-secret config templates (model commands, server settings) | `config/*.env.example` | `install.sh` and `bin/install-ai-devops-windows.ps1` | Install/update only (seeded to `/etc/ai-devops/*.env` if absent) | Default command strings plus comments | `AGENTS.md` credentials table and `docs/configuration.md`. |
| Forward work (phases, targets, gates, status) | A `plan_<slug>.md` at repo root | Nobody automatically | Task triggered | Goal, scope, per-step targets, verification gates, status table | `AGENTS.md` doc map or a handoff points to the active plan with a trigger. |
| Active session state (what this session did, what is next) | `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md` (one write-once file per session); root `HANDOFF.md` is a static pointer | The next session | Session start reads the OPEN files newest-first | The full nine-section handoff per `templates/system/handoff-standard.md` | Root `HANDOFF.md` pointer plus the "How handoffs work" section of `AGENTS.md`. |

### Decision table: where a new rule or fact goes

Walk the questions top to bottom; the first yes wins. Each row is a different
owner, so no rule can be assigned to two.

| # | If the information is… | Canonical owner | Belongs here (example) | Does NOT belong here |
|---|---|---|---|---|
| 1 | A universal safety or behavior rule every project needs, every session | Global (`CLAUDE-global.md` / `AGENTS-global-codex.md`) | "GPT-5.6 runs at low/medium reasoning only" | Procedures, machine-specific paths, one-off incident detail |
| 2 | True only on a specific machine (path, host, quirk, install state) | Machine atlas (`machine-atlas.md`) | "On 4837 the interactive logon maps home to `Z:`" | Rules that hold on every machine |
| 3 | About THIS repo's layout, install, or a repo-wide invariant | Repo router (`AGENTS.md`) | "Toolkit home is `/worksp/ai-devops`, never `/opt/ai-devops`" | Deep procedures, incident narratives, per-machine facts |
| 4 | A deep procedure, incident history, or how-to too long for startup | Topic doc (`docs/<topic>.md`) | The 2026-07-23 1Password rate-limit storm and the caching fix | One-line invariants that belong in the router |
| 5 | A repeatable procedure triggered by a task ("when X, do Y") | Skill (`skills/shared/...` by default) | "How to make a shared-db change: preview to branch to PR to regenerate types" | Universal rules, machine facts, one-off session state |
| 6 | A learned fact to recall later, not a procedure | Memory (`memory/...`) | "Git silently invents a committer identity when none is configured" | Procedures, rules of conduct, forward work |
| 7 | Forward work to implement (phases, gates, status) | Plan (`plan_<slug>.md`) | This consolidation plan's phases and verification gates | Rules of conduct, completed history |
| 8 | State from the current or just-finished session | Handoff (`HANDOFF.d/<...>.md`) | "Step 1 is done; step 2 is the open row; here is what was tried" | Standing rules, procedures, machine facts |

`CLAUDE.md` (this repo's adapter) is not a destination for new rules: it only
carries Claude-specific notes that point at `AGENTS.md`. A new cross-client
authoring rule belongs in `AGENTS.md`, not in `CLAUDE.md`.

### What counts as a pointer

A pointer is a **path or link plus a clear trigger** that says when to follow
it. The trigger is the load-bearing part.

- "See `docs/foo.md`" is **not** a pointer — no trigger.
- "If you are changing skill installation, read `docs/skills-usage-guide.md`" is
  a pointer.
- `[full: shared-db-change]` is a pointer — it names the skill and implies the
  trigger ("the full procedure for a shared-db change").

Every topic doc, skill, plan, and machine section is reached only through a
pointer with a trigger. Nothing is "just read every .md." A pointer whose target
no longer matches its trigger is a defect.

### Stale state, deletion, and retention ownership

- **One owner moves, the old copy must not linger.** When a rule moves to a new
  owner, the old location either deletes it or replaces it with a pointer to the
  new owner. Two live copies is the duplication defect this map exists to
  prevent.
- **A claim that contradicts reality is itself a defect.** A sentence in a
  canonical owner that is no longer true is an ownership bug; fix it in its
  owner. The standing example, "Codex has no skills system" in
  `AGENTS-global-codex.md`, was **corrected on 2026-08-12** once a real eval
  showed Codex opening the installed `SKILL.md` on 10 of 10 fitting prompts.
- **Skills are retired by deletion, not hand-editing.** Delete the skill from
  `skills/` and commit; `bin/ai-install-skills` and
  `bin/install-ai-devops-windows.ps1` quarantine the installed copy on the next
  sync via the `.ai-devops-managed` marker. Never hand-delete installed skill
  directories; vendor skills without the marker are never touched.
- **Handoffs are write-once and self-deleting.** Delete only your own
  `HANDOFF.d/` file when its work is proven done; never edit or delete another
  session's file. Root `HANDOFF.md` is a static pointer and is never rewritten.
- **Plans are retained as the completed record.** A `plan_*.md` stays after its
  STATUS rows are all done — it documents the decisions. Its open handoff is
  deleted only when every reachable rollout is proven.
- **Memory is corrected in place.** Update an outdated fact where it stands; do
  not append a corrected copy beside it.
- **Installed globals are intentionally not auto-overwritten.** Source changes
  do not clobber installed `~/.claude/CLAUDE.md` or `~/.codex/AGENTS.md`
  (non-clobber policy). Installed/source drift is therefore expected and only
  reported, not force-fixed. Safe reconciliation (managed markers or overlays)
  is a later plan step.
- **The full skill library is not startup context.** Skill bodies are
  task-triggered; only the name/description manifest loads at startup. Do not
  treat the sum of all skill bodies as a per-turn cost.

### Worked examples (ten real rules, classified)

These exist in the repo today. Each has exactly one canonical owner; anything in
the last column is a pointer or adapter, not a second owner. A second reviewer
applying the decision table above reaches the same owner for each row.

| # | Rule or fact (real) | Canonical owner | Pointer or adapter elsewhere |
|---|---|---|---|
| 1 | GPT-5.6 reasoning must stay `low`/`medium`, never `high`/`none`, every machine and session | Global (`CLAUDE-global.md` "AI model settings"; matched in `AGENTS-global-codex.md`) | Restated as a standing constraint in the plan, section 11 |
| 2 | Never run `terraform apply` or mutating `gcloud` against prod (`lithe-breaker-323913`) with personal credentials | Global ("Production infrastructure safety") | Incident detail in `docs/cloud-build-prod-trigger-incident-2026-07-20.md` |
| 3 | `codex exec` can look healthy and silently write nothing on Windows; fix is `…\.codex\packages\standalone\current\bin` first on PATH | Machine atlas ("Codex on Windows — the junction trap") | Summarized in `AGENTS.md` "Critical incidents" (a pointer, not a second owner) |
| 4 | Toolkit home is `/worksp/ai-devops`; never `/opt/ai-devops` | Repo router (`AGENTS.md`, Data model) | Restated in `CLAUDE.md` and `machine-atlas.md` as adapters |
| 5 | How to make a shared-db change: preview, then branch plus PR in `u2giants/shared-db` first, then regenerate types; never an inline migration from an app repo | Skill (`shared-db-change` / `codex-shared-db-change`) | The split principle (reading open, changing gated) is a Global rule; the skill is the procedure |
| 6 | The MCP launcher resolves 1Password secrets once and reuses a 15-minute DPAPI cache (2026-07-23 rate-limit storm) | Topic doc (`docs/mcp-1password-rate-limit-hardening.md`) | One-line quirk in `AGENTS.md`; learned fact in `memory/ai-devops/mcp-1password-launcher-storm.md` |
| 7 | The context-engineering consolidation: phases, per-step targets, verification gates, STATUS | Plan (`plan_context-engineering-consolidation.md`) | This doc and the open `HANDOFF.d/` files point to it |
| 8 | "Step 1 is done and corrected; step 2 is the open row; the parser fix was implemented and verified" | Handoff (`HANDOFF.d/2026-08-12T1552Z-al8960ofc-claude-context-audit-parser-fix.md`) | Root `HANDOFF.md` is the static pointer |
| 9 | Git silently invents a committer identity from the OS/AD account when none is configured (this put 231 wrong-identity commits in merged history) | Memory (`memory/ai-devops/git-identity-silent-guess.md`) | The standing rule "verify identity before first commit" is a Global rule |
| 10 | New skills are authored in `skills/shared/` by default; a name may live in `shared/` or a client tree, never both | Repo router (`AGENTS.md`, docs map plus skills-map note) | `CLAUDE.md` restates it for Claude; `docs/skills-map.md` and `docs/skills-usage-guide.md` carry pointers |

## Enforcement (step 3)

Enforcement lands before any reduction, so steps 4-6 cannot quietly remove a
safety rule or trade one duplication for another. Everything here reports;
nothing here rewrites a file.

### Warning budgets, never hard failures

`tools/context-audit/budgets.json` sets one warning budget per always-loaded or
startup class. Budgets **only warn** — they never change the audit's exit
status, including under `--strict`.

| Budget | Measured 2026-08-12 | `budget` (warns above) | `target` (steps 4-6 aim) |
|---|---:|---:|---:|
| Always-loaded globals | 24,713 bytes | 24,713 | 23,318 |
| Startup-routed repo entry files | 35,972 bytes | 35,972 | 35,340 |
| Claude skill manifest | 21,521 bytes | 21,521 | 15,065 |
| Codex skill manifest | 14,015 bytes | 14,015 | 9,811 |

`budget` is the size at the last accepted baseline, so any growth warns from the
next run. `target` is roughly a 30% cut, the middle of the plan's 25-40% band.
Ratchet `budget` down toward `target` only after a measured reduction has landed
and its behavior tests still pass. Never raise a budget to silence a warning.

Note that startup-routed grew from the 49,401 bytes recorded in the step-1
baseline above to 50,486 bytes, because `AGENTS.md` gained rows after step 1.
That growth is exactly what the budget now catches.

**Ratchet on 2026-08-12 (step 4).** The always-loaded budget moved from 33,311
to 25,764 bytes after the two global templates were slimmed: 22.7% smaller, with
zero missing safety markers, zero parity mismatches, and zero
global-versus-skill-description overlaps. What moved and where it went is
recorded under "Where the removed global detail now lives" below. The remaining
gap to the 23,318-byte target is deliberate: the next candidates are the shared
response-style contract and the Codex ritual summaries, and the ritual summaries
cannot be cut until Codex trigger evidence exists (plan step 4/6).

**Ratchet on 2026-08-12 (step 5).** Two budgets moved again.

- **Startup-routed: 50,729 → 35,972 bytes, a 29.1% cut**, 632 bytes above the
  35,340 target. `AGENTS.md` alone went 48,451 → 33,694 bytes. All figures are
  CRLF measurements taken from `C:eposi-devops`, per the drift note above. Nothing was deleted: the ten "intentional quirks"
  narratives moved verbatim to [`design-decisions.md`](design-decisions.md), the
  two incident narratives moved verbatim to
  [`critical-incidents.md`](critical-incidents.md) (one paragraph that appeared
  twice in the source is now single), and the router keeps a one-line rule plus a
  pointer for each. The three oversized delegate-wrapper rows (GLM, Grok, Kimi)
  now point at the STEP 0 VERIFICATION headers and `glm-opencode.md` section 5
  that already hold the same constraints in full.
- **Always-loaded: 25,764 → 24,713 bytes**, now 25.8% below the original 33,311
  baseline. Albert replaced the long response-style contract with a short one on
  2026-08-12 (his own decision, superseding the step-4 note that it should not be
  touched). The same commit **added** a new always-loaded rule to both globals:
  destructive actions must be recoverable before they are taken.

That rule closed a real gap the step-4 handoff had already flagged. The
"destructive actions" safety marker had only ever been satisfied incidentally, by
prose inside the `AGENTS.md` quirks section, and it failed the moment that prose
moved to its own doc. No global had ever carried the rule. It is now in both, and
covered by the parity check.

### Locked safety markers

Six categories must be present in the always-loaded and startup-routed text:
production mutation, shared database routing, secret handling, destructive
actions, Git identity, and the GPT-5.6 low/medium limit. Removing any one of
them from a fixture produces a plain-English failure naming that category and
what protection was lost. `tests/test-context-audit.ps1` proves all six
independently, and proves that removing one does not disturb the other five.

### Cross-client parity and its divergence allowlist

Claude and Codex load different global files, so identical behavior has to be
asserted rather than assumed. Eleven rules must appear in both globals: the
response-style contract, GPT-5.6 low/medium, production infrastructure safety,
no `terraform apply` against prod, verifying the Git committer identity, secrets
in 1Password, serialized 1Password access, the shared-database change gate,
Synology long-read safety, the handoff quality standard, and (added in step 5)
destructive actions being recoverable.

Text that genuinely belongs to one client only lives in a small divergence
allowlist (each client's own install line, and the Codex edition framing). If an
allowlisted, supposedly client-only string later appears in both globals, the
allowlist entry itself is reported as stale. A rule that merely *mentions* the
other client — the Claude global names `~/.codex/config.toml` inside the GPT-5.6
rule — is not a divergence, so the allowlist patterns anchor on text each client
actually owns.

### Duplicate startup text

Skill bodies are compared with each other (the 12 duplicate paragraph groups
above). Separately, always-loaded global text is compared against the per-client
skill **descriptions**, because both are startup context: a sentence in both is
paid for twice. Shared ten-word phrases are reported with an example. The
current real sources report zero such overlaps.

### Selection quality is measured separately

The audit measures size and duplication. It does not measure whether a skill
fires. Trigger quality uses `tools/skill-trigger-eval/skill-trigger-eval.py`
for Claude and the new `tools/skill-trigger-eval/codex-trigger-eval.py` for
Codex, which watches for Codex opening the installed `SKILL.md` because Codex
emits no `Skill` tool event. The Codex runner always passes an explicit
`low`/`medium` reasoning effort and a read-only sandbox. Neither tool replaces
the other.

The first Codex sets landed on 2026-08-12: `codex-qwen-code.eval.json` (the
exact-body Claude/Codex merge candidate, one set scoring both clients) and
`codex-shared-db-change.eval.json` (load-bearing — both globals name it).
`codex-qwen-code` scores **10/10 should-fire, 0/10 should-not-fire**. Getting
there required fixing two detection bugs that first understated and then
overstated the score; both are described in `tools/skill-trigger-eval/README.md`
and locked by `tests/test-codex-trigger-eval.sh`. **A trigger score is evidence
only when its `evidence` field names a command the model chose to run.**

### Run the enforcement checks

```powershell
python tools/context-audit/context-audit.py --root . --strict
pwsh -NoProfile -File tests/test-context-audit.ps1
```

## Reproduce the baseline

From `C:\repos\ai-devops` on Windows:

```powershell
python tools/context-audit/context-audit.py `
  --root . `
  --json .ai/context-audit/baseline.json `
  --summary .ai/context-audit/baseline.txt `
  --claude-home "$env:USERPROFILE\.claude" `
  --codex-home "$env:USERPROFILE\.codex"

pwsh -NoProfile -File tests/test-context-audit.ps1
```

Two runs with the same `--generated-at` value must produce byte-identical JSON.
The fixture test proves that `.env`, `.ai`, transcript, and dependency content
does not enter the report.

## Where the removed global and router detail now lives

Step 4 slimmed the two always-loaded globals and step 5 slimmed the repo router,
both on 2026-08-12. Nothing was deleted outright: every removed passage already
had a canonical owner under the ownership map, or was given one, and the global
or router now carries the rule plus a pointer that says when to open that owner.
The table is the audit trail for anyone who misses text.

| Removed from | What moved | Canonical owner now | Trigger written into the global |
|---|---|---|---|
| Both globals | The 25-second NAS read procedure (managed SSH, PID/status, durable output) | `skills/shared/synology-long-running-operations/SKILL.md` | Before any NAS read that will exceed 25 seconds |
| Claude global | The standalone "No `terraform apply` against prod" section, merged into production safety | Same file, one section; the 2026-07-20 narrative is in `docs/cloud-build-prod-trigger-incident-2026-07-20.md` | Before touching any prod trigger or Terraform state |
| Both globals | The 2026-07-20 incident narrative | `docs/cloud-build-prod-trigger-incident-2026-07-20.md` | Same as above |
| Both globals | The itemized shared-database procedure | `skills/claude/shared-db-change/` and `skills/codex/codex-shared-db-change/` | Before making any shared-database change |
| Claude global | The dev-server-proxy visual-testing recipe | `docs/future-visual-testing.md` | When a UI screen needs a backend to reach it |
| Claude global | The Git-identity mechanics beyond the check itself | `bin/ai-git-identity` | Before the first commit in an unfamiliar repo |
| Both globals | The 9 handoff sections, the self-audit gate, legacy `HANDOFF.md` migration, and the `merge=union` ban | `templates/system/handoff-standard.md` and `skills/shared/handoff-writer/` | Before writing any handoff |
| Both globals (step 5) | The long response-style contract, replaced by a six-bullet version | Nothing: Albert shortened it by decision on 2026-08-12. The full former text is in git history at commit `24f709e` | Not applicable |
| `AGENTS.md` (step 5) | The ten "looks like / actually / why / do not change" narratives | [`design-decisions.md`](design-decisions.md) | Before changing, simplifying, or "fixing" any listed behavior |
| `AGENTS.md` (step 5) | The two incident narratives with their root causes and lessons | [`critical-incidents.md`](critical-incidents.md) | When a tool reports success but changes nothing, on any Codex Windows sandbox failure, or on any 1Password rate limit |
| `AGENTS.md` (step 5) | The GLM, Grok, and Kimi constraint paragraphs in the documentation map | `docs/glm-opencode.md` section 5, and the STEP 0 VERIFICATION headers in `bin/ai-grok-review`, `bin/ai-grok-implement`, `bin/ai-kimi` | Before touching that wrapper, its permissions, or its completion check |

One rule moved the other way. Step 5 **added** "every destructive action must be
recoverable before you take it" to both globals. The audit's destructive-action
safety marker had only ever been satisfied by incidental prose inside the
`AGENTS.md` quirks section, so it failed the moment that prose moved to its own
doc. No global had ever carried the rule. It is now in both and is a parity rule.

What deliberately stayed always-loaded: the response-style contract, who Albert
is, the access-first and manual-action rules, secret and 1Password-serialization
rules, the GPT-5.6 low/medium limit, production and shared-cloud read-only
safety, the shared-database read-open/change-gated split, branch and commit-
identity gates, the engineering standards, and the session-start routing
contract. Each of those either governs behavior on every turn or is the gate
that stops an unsafe action before any pointer could be followed.

## Current boundary

Phase A (steps 1 and 2) and phase B (step 3) are done: the baseline is frozen,
the ownership map is defined, and the enforcement checks and warning budgets are
in place. Step 4 is done for the two global templates and step 5 is done for `AGENTS.md`.
No skill, installer, or machine file has been changed yet, and nothing has been
installed on any machine: that is step 7 and step 8 work.
