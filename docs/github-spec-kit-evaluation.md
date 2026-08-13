# Evaluation — GitHub Spec Kit (`github/spec-kit`)

Decision record for whether this repo should adopt
[`github/spec-kit`](https://github.com/github/spec-kit). Evaluated 2026-08-13
against the toolkit as it stands on `main`.

**Verdict: do not adopt the tool. Port five of its ideas.** Roughly 80% of
spec-kit duplicates the staged pipeline this repo already runs, and the
overlapping parts here are stricter. The remaining 20% is genuinely useful and
is portable as prompt/standard/skill edits with no new runtime dependency.

Adoption work is specified in
[`plan_spec-kit-idea-adoption.md`](../plan_spec-kit-idea-adoption.md) — read its
STATUS table first.

## 1. What spec-kit is

A spec-driven-development toolkit: write the specification before the code, and
have the agent work from it. Distribution is a Python CLI:

```bash
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@vX.Y.Z
specify init my-project --integration <agent>
```

It then exposes slash commands inside whichever single agent you initialised:

| Command | Purpose |
|---|---|
| `/speckit.constitution` | Create/update project governing principles |
| `/speckit.specify` | Requirements and user stories (the *what*, tech-free) |
| `/speckit.plan` | Technical implementation strategy (the *how*) |
| `/speckit.tasks` | Generate an actionable, ordered task list |
| `/speckit.implement` | Execute the tasks |
| `/speckit.clarify` | Interrogate ambiguity before planning |
| `/speckit.analyze` | Cross-artifact consistency check (spec vs plan vs tasks) |
| `/speckit.checklist` | Generate requirement checklists |
| `/speckit.taskstoissues` | Turn tasks into GitHub issues |
| `/speckit.converge` | Assess the codebase against spec/plan/tasks and append remaining work as new tasks |

It writes `.specify/` (`templates/`, `templates/overrides/`, `presets/`,
`extensions/`, `memory/`) plus agent command files into e.g. `.claude/commands/`.
Prerequisites: Python 3.11+, `uv` (or `pipx`), git, a supported agent. It claims
30+ agent integrations; Codex CLI uses `$speckit-*` rather than `/speckit.*`.

It distinguishes greenfield ("0-to-1") from brownfield ("iterative
enhancement") use and advises keeping tooling updates separate from feature
artifact evolution on existing projects.

## 2. Where it duplicates what we already have

| spec-kit | Existing equivalent here |
|---|---|
| `/speckit.constitution` → `.specify/memory/constitution.md` | `templates/system/CLAUDE-global.md`, `templates/system/AGENTS-global-codex.md`, `templates/system/machine-atlas.md`, per-repo `AGENTS.md` |
| `/speckit.plan` | `templates/system/implementation-plan-standard.md` — 13 sections, comprehensiveness checklist, mandatory self-audit gate. Strictly stronger than spec-kit's plan template |
| `/speckit.specify` | `templates/prompts/01-opus48-plan.md` §1–2 (goal + business intent) |
| `/speckit.implement` | Stage 03 (`templates/prompts/03-gpt55-implement.md`) plus the Codex/GLM/Grok/Kimi delegate wrappers in `bin/` |
| `/speckit.checklist` | The comprehensiveness checklists already embedded in both standards |
| project scaffolding | `skills/claude/new-app-setup/`, `skills/codex/codex-new-application/` |

Three things spec-kit has **no concept of**, and they are the toolkit's actual
value:

1. **Stage→model routing.** `bin/ai-model-call` maps a stage name to a
   `*_CMD` from `/etc/ai-devops/models.env`. spec-kit runs inside one agent.
2. **Independent read-only review gates.** Stages 02, 04 and 06 are separate
   model invocations that cannot mutate the repo. `/speckit.implement` just
   implements; nothing independently reviews it.
3. **Concurrent-agent handoff.** The write-once `HANDOFF.d/` protocol
   (`templates/system/handoff-standard.md`) exists because six agents work these
   repos at once. spec-kit has no equivalent.

So spec-kit cannot replace the pipeline. At best it feeds it.

## 3. Costs specific to this repo

- **Breaks a documented constraint.** `docs/architecture.md` §Constraints: "Pure
  Bash + coreutils + `git`, `jq`, `rg`, `gh`, and the `claude`/`codex` CLIs."
  spec-kit adds Python 3.11 + `uv` + a fast-moving upstream to
  `docs/restore-from-zero.md`.
- **Collides with `bin/ai-install-skills`.** That tool owns the `.claude/` tree
  with `.ai-devops-managed` quarantine and preview-first sync. spec-kit writes
  `.claude/commands/*` on its own schedule. Different subdirectories, so not
  fatal — but two installers in one tree is the drift trap `AGENTS.md` repeatedly
  warns about.
- **Against the standing supply-chain position.** Recorded in `AGENTS.md`
  §Intentional quirks for the `codex-cli` MCP: "no supply chain, no `npx` in the
  hot path."
- **Adds a fifth artifact system** (`.specify/` + `specs/NNN-*/`) on top of
  `HANDOFF.d/`, `plan_*.md`, `memory/`, and `.ai/runs/` — while
  `plan_context-engineering-consolidation.md` and `tools/context-audit/` are
  actively trying to shrink what gets loaded.
- **No measured headroom for it.** `tools/context-audit/context-audit.py` reports
  `claudeSkillManifestBytes` at 21521 of a 21521-byte budget (zero headroom) and
  `startupRoutedBytes` at 35523 of 35972 (449 bytes). `budgets.json` states:
  "Never raise a budget to silence a warning." Any adoption that adds skills or
  router text has to pay for itself first.

## 4. The five ideas worth porting

Ordered by value, not by effort.

### 4.1 Task-ID decomposition (from `/speckit.tasks`)

spec-kit decomposes a plan into individually addressable tasks with IDs,
dependency ordering, and parallel markers. Our plan standard has a STATUS table
(one row per step) but the steps are prose.

**Why it matters here:** with stable task IDs a delegate can be handed *one task*
instead of an 80 KB plan. That is the exact failure recorded in
`plan_kimi-incomplete-implementation-recovery.md` and
`plan_glm-incomplete-implementation-recovery.md` — a delegate reports success
having done part of the work. Highest-value item in this list.

### 4.2 A convergence / drift check (from `/speckit.converge`)

"Assess the codebase against spec/plan/tasks and append remaining work as new
tasks." This is a canned version of the `fresh-session` skill's Step 3 drift
check and the phased-plan re-read guardrail in
`skills/claude/ai-development-pipeline/SKILL.md`.

**Why it matters here:** "the delegate said done and it wasn't" is a recurring
incident class, currently handled by hand.

### 4.3 Spec/plan separation (from `/speckit.specify` vs `/speckit.plan`)

spec-kit keeps the tech-free *what/why* in `spec.md` and the *how* in `plan.md`.
Our 13-section standard fuses them, so the plan-review gate (stage 02) reviews
intent and implementation as one document.

**Why it matters here:** stage 02 gets something to disagree with that is not
already an implementation.

### 4.4 Per-feature directories (from `specs/NNN-feature-name/`)

There are **13 `plan_*.md` files totalling 424 KB in the repo root**. spec-kit's
`specs/NNN-slug/` convention is the obvious fix and costs nothing but a `git mv`
plus link updates.

**Constraint discovered while scoping this:** six files in `HANDOFF.d/` link to
`plan_*.md` paths, and `handoff-standard.md` forbids editing another session's
handoff file. Those links would break. Only two distinct plans are affected
(`plan_context-engineering-consolidation.md`,
`plan_ai-glm-permission-failures.md`), so the migration excludes any plan
referenced by a file currently present in `HANDOFF.d/`. Also note
`tools/context-audit/context-audit.py:571` hard-codes
`plan_context-engineering-consolidation.md`.

Moving the files does not by itself reduce loaded context — the router controls
that, not the location. The gain is a legible root and a home for the split
spec/plan/tasks artifacts from 4.1 and 4.3.

### 4.5 A clarify gate (from `/speckit.clarify`)

`templates/prompts/01-opus48-plan.md` says "state your assumptions explicitly."
spec-kit actively interrogates ambiguity *before* planning.

**Why it matters here:** a planning model asking three questions up front is
cheaper than a wrong plan surviving to stage 03.

## 5. Recommendation

Port the five ideas per
[`plan_spec-kit-idea-adoption.md`](../plan_spec-kit-idea-adoption.md). Do not
install `specify-cli` into the toolkit or into `/worksp/ai-devops`.

If a closer look at spec-kit's generated templates is wanted, run
`specify init` once in a **throwaway repo outside `/worksp`**, read the emitted
`tasks.md` / `analyze` / `converge` templates, port the useful prompt language,
and delete the sandbox. That is a read-only research action with no dependency
committed.

## 6. When to revisit

Reopen this decision if any of these become true:

- Frequent greenfield builds **with other people**, where a shared `/speckit.*`
  vocabulary is worth more than stage→model routing.
- The Python/`uv` dependency stops being new — e.g. `restore-from-zero` already
  requires it for another reason.
- spec-kit grows per-stage model routing and read-only review gates, at which
  point the overlap becomes replacement rather than duplication.

## 7. How this was evaluated

- spec-kit: its README and repository documentation, fetched 2026-08-13.
- This repo: `AGENTS.md`, `docs/architecture.md`, `templates/prompts/01..07`,
  `templates/system/implementation-plan-standard.md`,
  `templates/system/handoff-standard.md`,
  `skills/claude/ai-development-pipeline/SKILL.md`,
  `skills/shared/implementation-plan-writer/SKILL.md`,
  `skills/shared/fresh-session/SKILL.md`, `bin/ai-grok-review`,
  `tools/context-audit/` (run for the budget figures quoted in §3).
- **Not yet done:** an independent second-opinion review by another model. It was
  requested on 2026-08-13 but Grok is not reachable from a Claude-on-the-web
  container (no `grok` binary, no `ai-grok-review`, no xAI credentials, no
  `/worksp`). Run `ai-grok-review new spec-kit-eval` on `hetz` or `t16` to get
  it. The verdict above is one model's judgement until then.
