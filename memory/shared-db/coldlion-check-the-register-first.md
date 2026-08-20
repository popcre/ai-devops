---
name: coldlion-check-the-register-first
description: "Before asking ColdLion anything or calling a field broken/unknown, read docs/coldlion-open-questions.md — a dozen questions are already answered there"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 542c9c93-9e90-4a76-adc0-55abe2199ec7
  modified: 2026-08-20T13:25:38.556Z
---

`u2giants/shared-db` keeps **one register of every ColdLion question**:
`docs/coldlion-open-questions.md`. Section 4 holds a dozen answered questions. The front
door for everything ColdLion is `docs/coldlion.md`.

**Why:** on 2026-08-19 a session measured two always-zero quantity fields
(`lineInvoiceQty`, `lineOpenQty`) for an afternoon and drafted a question to ColdLion about
them. It had been answered the previous day and was sitting in §4. The session had read
four ColdLion documents and none of them linked the register.

ColdLion is a third party. Its goodwill is finite and we depend on it — they have added
fields for us on request (`prodLineSeq`, the 7-day cap). Re-asking an answered question
spends that goodwill for nothing.

**How to apply:**

- Read `docs/coldlion.md`, then `docs/coldlion-open-questions.md` §4, **before** drafting a
  question, concluding a field is broken, or telling Albert something is unknown.
- Questions go **from Albert**, never sent by an AI session: **JamieLynn** for API and data,
  **Uma** for division/company codes. Some register entries are owner decisions for Albert,
  not questions for ColdLion.
- When a measurement contradicts an existing answer, that is a legitimate **follow-up** —
  say so explicitly and cite both, rather than re-asking the original.
- Never ask Albert to rotate the ColdLion API key; he does not administer ColdLion.

Related: [[coldlion-field-decisions-are-owner-authority]],
[[shared-db-merge-gate-nine-checks]]
