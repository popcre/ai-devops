# Owner rulings (verbatim)

Albert Hazan's dated standing rulings, quoted exactly. The global rule files
keep only the current rule in one line plus a pointer here; the procedures
that apply each ruling live in `docs/standing-rules-details.md`. Add a new
ruling here with its date, exact words, and what it changed.

## 2026-09-28 — no human approval

Verbatim: "never ask a human to approve. as i have said at least 1000 times, i
am a solo vibe coder with no technical knowledge. ai has to do everything for
me without asking me to do manual things. institute that."

Current rule: no human approval is ever requested; assigned AI reviewers gate
technical actions through an explicit exact-input APPROVE; AI performs every
manual step itself; only business-meaning questions go to Albert.

## 2026-09-28 — no separate production reviewer identity (popcre/shared-db#3656)

Verbatim: "i don't need an independent production reviewer. remove that
requirement"

Current rule: shared-db manual production recovery needs no separately
registered reviewer identity; the allocator-assigned exact-head APPROVE and
every other evidence gate still apply.

## 2026-10-02 — AI may launch the shared-db promotion workflow

Verbatim: "let AI launch it and remove that rule permanently."

Current rule: an AI session may launch the merged-preview run of the activated
automatic migration promotion workflow for an approved, merged change after
`ai-task-gates check --before shared-db-promotion` passes. It authorizes no
manual production command, other repository, or bypass of the workflow's
checks.

## 2026-10-13 — discretionary review is shared-db-only (popcre/ai-devops#1714)

Current rule (recorded in `docs/standing-rules-details.md`): outside
`popcre/shared-db`, dispatch a review only when the task class's gate demands
one.

## 2026-10-14 — database writes skip the second AI

Verbatim: "Our own safety rules require a second AI to approve database writes.
Remove that rule."

Current rule: no assigned AI reviewer APPROVE is required for a database
write. Every other gate stays: task declaration, class escalation,
protected-class seals, target identity proof, claim rules, and live proof.
`ai-task-gates check --before database` opens without `--reviewer-approval`.
