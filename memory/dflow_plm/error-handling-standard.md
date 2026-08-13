---
name: error-handling-standard
description: "Albert's bar for error handling — no silent failures AND no cryptic/generic errors; every failure must pinpoint where and what"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d2890b7a-04ee-4cfa-a692-1291f940e2f6
---

Albert's standard for how code must fail (stated 2026-07-15, reviewing dflow data-syncing fixes). Two parts, both required:

1. **Nothing fails silently** — every catch/fallback must surface loudly (log + propagate), never swallow.
2. **No useless/cryptic/generic errors** — an error must let a developer *quickly pinpoint where and what*: name the specific record/id/field and the exact problem (e.g. "Item MEZH1DYPN02: unrecognized ColdLion divisionCode 'XX999' — cannot map to div_code_fk"), NOT a bare `null` that later triggers a generic downstream failure (e.g. a raw Postgres NOT-NULL violation with no context).

**Why:** Albert is not a programmer; when something breaks he needs the error itself to point a developer straight at the cause. A silent `null` or a generic stack trace costs a whole debugging session.

**How to apply:** When a value can't be mapped/validated, fail with a specific, contextual message identifying the offending record and the exact bad input — don't write a placeholder that defers the failure to a cryptic error elsewhere. Applies to all repos. See [[dflow-delivery-workflow]]. Extends the global "No silent failures" rule (CLAUDE.md §11).
