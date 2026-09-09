# Phase 0 routing census and no-loss ledger — 2026-09-08

Owner issue: [popcre/ai-devops#335](https://github.com/popcre/ai-devops/issues/335).
Plan: [`plan_cross_repo_routing_and_gate_enforcement.md`](../../../plan_cross_repo_routing_and_gate_enforcement.md).

Machine-readable evidence lives in
[`routing-baseline.json`](routing-baseline.json) and
[`config/repository-coverage.json`](../../../config/repository-coverage.json).
Re-run the audit with:

```bash
python tools/context-audit/audit-repository-routing.py
```

## What was measured

Every canonical remote's root routing surface — `AGENTS.md`, `CLAUDE.md`,
`HANDOFF.md` — measured on its default branch from GitHub repository *contents
metadata*: file name and byte size only. No file body was fetched from
`u2giants/licensor-source-data` or `u2giants/ai-devops-transcripts`, and no
transcript archive was opened. `README.md` is recorded for context but is not
counted as startup routing, because it is documentation a session reads on
demand rather than instruction text loaded at task start.

## Result

All 17 canonical remotes are classified exactly once. 14 expose a root
`AGENTS.md`. Three do not, and each absence is intentional rather than an
oversight:

| Repository | Routing surface today | Phase 4 decision |
|---|---|---|
| `u2giants/licensor-source-data` | `HANDOFF.md` plus a 12.9 KB `README.md` | Thin policy only; add a root router only if Phase 4 proves a real discoverability gap |
| `u2giants/ai-devops-transcripts` | `README.md` only | Thin policy only; the repository is an archive, and its one non-negotiable rule is that raw `.jsonl` archives are never opened |
| `popcre/infrastructure` | none | Thin policy only; production mutation stays denied without exact current-chat resource and action authority |

Startup routing across the 17 repositories totals **771,588 bytes**, median
26,595, maximum 143,774 (`u2giants/theoracle`). Six repositories carry a root
router above 45 KB: `theoracle`, `shared-db`, `popdam3`, `popcrm-web`,
`designflow-frontend`, and `ansible` (whose 30 KB `HANDOFF.md` is itself
always-loaded).

Size is a **diagnostic, never a blocking rule**. A large router that carries
unique safety instructions is correct. The defect this program repairs is a
router that embeds a full procedure already owned by a skill or document, so a
documentation-only task pays for a deployment procedure it will never run.

## No-loss ledger contract

Phases 3 and 4 trim consumer routers. Before any router is edited, every one of
its sections is assigned exactly one disposition, and no section may be left
unassigned:

| Disposition | Meaning | Required proof |
|---|---|---|
| `keep` | Repository purpose, an invariant safety or ownership boundary, or a high-frequency task route | Section stays in the root router |
| `move` | A full procedure, machine fact, or history that belongs in an owned home | Destination document or skill exists, and a task trigger reaches it |
| `consolidate` | Duplicate of text already owned elsewhere | The surviving copy is named, and it is at least as strong |
| `remove` | Stale live fact or superseded instruction | Evidence that it is stale, recorded in the repository's ledger |

An independent reviewer compares each trimmed router to its ledger in Step 3.2.
A section that cannot be assigned stops that repository and is raised with
Albert rather than deleted.

## Baseline for Phase 5 comparison

Phase 5 compares against these Phase 0 figures:

- startup routing bytes per repository (table above),
- unnecessary reviewer starts on documentation-only work,
- long PR waits started for documentation-only changes,
- task-trigger precision for a documentation task versus its highest-risk class.

The acceptance measure is **zero expensive gate launches in the controlled
documentation scenarios**, not merely a smaller router.
