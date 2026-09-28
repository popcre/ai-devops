---
issue: 643
status: OPEN
owner: codex/jevgrep-wrap-handoff
---

# HANDOFF — Jevgrep token evaluation (2026-09-28, 7:23 AM EDT, edge-dev3/Codex)

## 0. Decisions only Albert can make

None. Albert requested an evaluation of whether Jevgrep or jev-semgrep can reduce paid AI tokens in POP Creations' own coding workflow, explicitly asked for a Luna High subagent to diagnose Jevgrep, and then invoked wrap-up. Those instructions authorize the bounded research described below. No production, database, installation, or private-source upload is proposed.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public AI workflow and recovery toolkit, not an application server. It contains CLI wrappers, reviewer controls, task gates, skills, and operating plans. Its protected `main` branch is the source of truth. TypeSafe Jev answers closed questions cheaply; `dzhng/jevgrep` is a third-party CLI that uses Jev to select relevant code and return source excerpts to a coding agent. `uehaj/jev-semgrep` (published as `sys1grep`) scores lines by meaning. Searches can send selected source to the provider, so the first live trial used only a public snapshot of this local repository. The larger Jev spend-reduction program is tracked in `plan_typesafe-jev-spend-reduction.md` under issue [#643](https://github.com/popcre/ai-devops/issues/643).

## 2. What this session set out to do and why

Albert asked whether either Jev search tool could reduce tokens and corrected an overly narrow suggestion to use unfamiliar public code only. He asked for transcript evidence of search frequency in his own codebases, a StepFun review of the private transcript archive, then a Luna Max and finally Luna High subagent to compare matched searches and diagnose a timeout. The intended outcome was evidence of real net paid-token displacement, not a cheap extra Jev call. The private archive was `/home/ahazan/Dropbox/ai/chat_transcripts/` on edge-dev3. Raw contents must stay out of this public repository and outside unapproved reviewers.

## 3. Current state and evidence

- A local structural scan covered 4,229 deduplicated JSONL filenames from 4,274 raw filenames. It counted 80,415 search-shaped shell/search-tool calls across 3,526 sessions. Eight clearly identified owned-repository labels contributed a lower bound of 19,900 such calls across 993 sessions. This proves frequent searching in our own codebases, but is an upper bound on searches useful to a semantic tool. The parser counted actual shell/search tool calls, not mentions in prompts, and could not distinguish conceptual from exact searches reliably. No raw transcript text was copied to this public repository.
- Temporary `@dzhng/jevgrep` 0.4.1 was installed under `/tmp/jevgrep-eval.tMv2tJ/cli/`, with a public `origin/main` source snapshot under `source/` (934 files, about 12 MB). These are disposable trial artifacts, not an installed toolkit capability. The TypeSafe credential came from 1Password vault `vibe_coding`, item `typesafe.ai API`, through a pipe into a mode-600 temporary Jevgrep config. It was removed and absence verified. No key value was printed or committed.
- Three full-snapshot searches at concurrency 1 and one retry at concurrency 4 each hit our 60-second command cap with no completed result. An additional 184-file `bin/` run hit our 35-second cap after returning a partial 34,338-byte response identifying 19 relevant files; Jevgrep reported 19 interrupted and 10 cancelled calls. A trace observed a TypeSafe HTTPS connection, but did not prove a provider response or billing amount. The limits were ours, not a confirmed TypeSafe timeout.
- Luna High completed three matched searches over a curated five-file, 77,832-byte public-source scope. Jevgrep took 1.15–2.29 seconds and returned 2–3 relevant files, with 6,925–22,321 stdout bytes. Matching literal `rg` searches took under 0.01 seconds and returned 2–4 files with 103–212 bytes. This does not prove Jevgrep is worse in real use: the scope was tiny and preselected, the questions contained searchable terms, the baseline measured file-location output rather than the model's later source reads, and `tools/lib/task-gates.sh` was accidentally omitted from the scratch scope. It also does not prove savings; no paid coding-agent call was replaced. The Jevgrep CLI does not report Jev request usage or charges.
- StepFun did **not** review the archive. Declaring `private-evidence` and running `ai-task-gates check --before review` produced `STOP: review is forbidden for the protected class private-evidence`. The prior session response was too broad when it said even a sanitized aggregate could not be reviewed. `docs/development.md` documents a permitted route: inspect an aggregate for private content, write it into a public worktree, declare that public artifact's actual class, and request ordinary review there. Never give a reviewer raw transcripts or private source. No aggregate was prepared or sent in this session.
- No source code was edited, no Jev tool was installed machine-wide, no application was deployed, and no pull request existed before this wrap-up. This handoff and the plan note are the only intended repository changes. A new docs-only branch and pull request must carry them to `origin/main` before closure.

## 4. Attempts that did not work

1. Counting all grep-shaped commands as replaceable work failed because many searches use exact paths or symbols. The transcript scan is frequency evidence, not a billable-token baseline.
2. Four whole-repository Jevgrep runs were stopped at 60 seconds and gave no completed answer. Empty stdout is not proof of a provider outage; Jevgrep may buffer output while evaluating many files.
3. Narrowing to 184 files returned partial results, but still did not complete within 35 seconds. It did at least show the CLI had advanced past purely local startup.
4. The five-file trial completed quickly but deliberately removed discovery difficulty and omitted one relevant library file. It cannot support a fleet decision or a token-savings claim.
5. Applying the private-evidence review gate to a proposed StepFun review rejected the action. The safe public-aggregate route exists in `docs/development.md`; that correction must be preserved. This session never submitted a StepFun review.

## 5. Root causes and key findings

- Search volume exists in Albert's own codebases, so the earlier unfamiliar-public-code framing was wrong. Only conceptual, initially unknown-location searches are plausible Jevgrep candidates; direct `rg` remains suitable for exact terms and paths.
- The Jevgrep trial measured retrieval behavior and wall time, not the coding agent's billed input, cache, output, success rate, or Jev's complete charge. `plan_typesafe-jev-spend-reduction.md` requires net paid-token displacement, so its first status row remains OPEN.
- The larger-scope latency is unresolved. More concurrency did not yield a complete whole-repo answer within 60 seconds; a small scope finished in about two seconds. Isolate how many API evaluations each stage sends and where time accumulates before attributing latency to TypeSafe or making a performance fix. The temporary package's README says Jevgrep searches send eligible source to the selected provider and save evaluation answers locally; direct code search can be enough for exact terms.
- The privacy correction is already documented in `docs/development.md`: a sanitized aggregate in a public worktree can be reviewed through the ordinary gate after inspection. A raw transcript review remains forbidden. This is a routing correction, not a request to weaken the private-evidence policy.

## 6. Exact next steps

1. Start from current `origin/main` in a fresh task worktree. Read `AGENTS.md`, the top STATUS of `plan_typesafe-jev-spend-reduction.md`, this handoff, and the relevant `docs/task-router.md` row. Verify issue #643 is still open and determine whether its first status row already has a successor; do not redo proven work. **Success:** one clearly owned first open outcome with current upstream state.
2. For any StepFun opinion on transcript findings, structurally compute a public aggregate with no raw text or private identifiers, inspect the exact artifact, then use the public-worktree review route documented in `docs/development.md`. Keep the source archive private. **Success:** the review sees only the sanitized aggregate, or a precise gate refusal is recorded without sending content.
3. Diagnose Jevgrep on a representative own public repository task with bounded stage timing and provider request/usage accounting. Begin with a scope between the five-file toy and the 184-file timed-out trial; do not hide slow results by shrinking until only obvious files remain. Report source count, bytes, stage durations, completed versus interrupted calls, and provider usage. **Success:** a full result completes and its elapsed time and Jev charge are known, or a reproducible specific bottleneck is identified for upstream repair.
4. Select representative real code-discovery tasks from the archive without publishing private prompts. Compare paired coding-agent runs on the same frozen public repository snapshot, model, task, and success checks; include actual model billing and Jev charges, and record whether the relevant files were found. Follow the plan's public-only and privacy gates. **Success:** a checked-in, reproducible net-cost and quality report that demonstrates saving or records a no-go; character-count estimates alone do not pass.
5. If the trial succeeds, update the existing Jev plan and issue #643 before considering permanent installation. If it fails, record retirement evidence rather than adding a routine extra tool call. **Success:** the plan STATUS accurately names the verified keep or no-go outcome.

## 7. Constraints and gotchas

- Work on a dedicated current-upstream worktree; canonical checkout is landing-only. Commit through a branch and PR, run task gates before stronger actions, and keep GitHub calls through `bin/ai-gh`. Docs-only PRs may follow the repository's documented immediate squash-merge route. Verify the intended commit on `origin/main`.
- Never send raw transcript JSONL, secrets, licensed data, or private repository source to Jevgrep, StepFun, GitHub, or this public repository. Jevgrep's default file filtering is not a privacy guarantee. Use 1Password vault `vibe_coding` for the TypeSafe key; pipe values or write protected files only, never command arguments or output.
- A protected `private-evidence` gate cannot be overridden by owner assent. Review of sanitized aggregate is a separate public-artifact route; exact code-only review of selected private repository files is yet another sealed route and is not a transcript-review shortcut.
- Do not infer savings from Jev's low unit price, raw grep output size, or high command frequency. A new Jev call is only useful if it prevents a measured model context load or displaces a paid decision without degrading task success.
- No work in this session changed database structure or curated master data. The open shared-db orchestrator marker #3570 belongs to another session and must not be touched. Our subagents were used only for read-only transcript and search analysis.

## 8. Access and environment

- Machine: `edge-dev3`, Linux; repository `/home/ahazan/repos/ai-devops`, remote `https://github.com/popcre/ai-devops`; public source snapshot was local. The canonical checkout was clean but behind `origin/main` by two commits at wrap-up start. The wrap-up worktree was created from `origin/main` at `b2fb99794d11d6dda8937200ff0b59f7634a7c00` on `codex/jevgrep-wrap-handoff`.
- TypeSafe service: `https://api.typesafe.ai/v1/systemone`; credential is existing 1Password item `typesafe.ai API` in vault `vibe_coding`. The temporary Jevgrep auth file was removed. A future trial must authenticate again safely. The disposable CLI and public snapshot may still be under `/tmp/jevgrep-eval.tMv2tJ/`; verify contents and ownership before cleanup or reuse. They are not canonical state.
- The raw transcript archive path above is local private evidence. The earlier parser was temporary and not committed, so counts require an independent reproducible method before pricing or publication. Its method: stream JSONL, deduplicate filenames by basename retaining the largest copy, classify only executed shell/search tool inputs with search command-word patterns, and link Codex tool call IDs to output lengths. This cannot measure semantic-search intent or billed model tokens by itself.

## 9. Open questions and risks

- The proportion of the 19,900 owned-repository searches that are conceptual and replaceable is unknown. Deduplication by basename might collapse distinct files from different machines; treat all counts as exploratory bounds.
- Jevgrep's full-repository cost and time are unknown; interrupted requests may have incurred unreported TypeSafe charges. No provider usage telemetry was captured. A five-file demonstration cannot establish benefit for a 934-file repository.
- A paired task-level trial may find that Jevgrep returns more source than the agent otherwise reads, loses relevant files, or adds latency. Measure net cost and task quality rather than search-tool output alone.
- The previous statement that every sanitized StepFun review is barred was erroneous. The documented public-aggregate route may permit it after content inspection and ordinary task-gate checks. Raw archive access remains barred.

## Self-audit

1. **Street-newcomer continuity: yes.** Sections 1–3 explain the toolkit, goal, locations, issue, and exact verified state; section 6 gives an ordered restart with success checks.
2. **Equal working knowledge: yes.** Sections 3–5 preserve counts, methods, four failed larger searches, the partial run, the small completed comparison, and the corrected review route.
3. **All execution detail: yes.** Sections 6–9 contain next actions, constraints, access, risks, and verification. No raw secret or transcript is needed to proceed.
4. **Owner-decision sweep: yes.** Re-reading sections 1–9 found no new owner approval or ruling required. Section 0 records already settled instructions and no pending decision.
