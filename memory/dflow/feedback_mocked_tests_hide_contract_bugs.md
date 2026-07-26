---
name: feedback-mocked-tests-hide-contract-bugs
description: Green unit tests with a mocked DB are NOT proof an API works — exercise new endpoints against the live schema before shipping
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ae9e5c93-d34e-41d4-82c1-068fe5840c43
  modified: 2026-07-26T23:07:07.677Z
---

**A fully-mocked Jest suite cannot catch a wrong database contract.** On 2026-07-23/24 the
Sample Tracking movement API shipped with 400+ green tests (`jest.mock('../../models/db')`)
and still hard-failed against the live schema. Bugs the mocks hid:

- lifecycle action sent as `correction`; the DB CHECK expects `correct`
- discrepancy codes not matching production's allowed set
- in-transit movements missing the required `box_id_fk` + `shipment_line_id`
- `sample_stop_closeout.movement_watermark` NOT NULL not honored
- **raw `sequelize.query` not schema-qualified** — Sequelize *models* inherit
  `process.env.SCHEMA`, but raw SQL does NOT. `FROM "Factory"` / `FROM "customers"`
  threw live 500s; correct form is `FROM "${process.env.SCHEMA}"."customers"`.
  (Now rule-documented in designflow-tracking `AGENTS.md`.)

These merged into `develop` before the fixes existed, briefly breaking the feature there.

**How to apply:** for any new endpoint touching the shared DB, before declaring done —
run it against the real schema (a read-only query, a rolled-back transaction, or a live
sandbox E2E). Verifying the *schema* and *file round-trips* directly (which did hold up)
is not a substitute for exercising the *API layer*. Treat "not exercised against a live
backend" as BLOCKING, not as a footnote in the handoff.

Also: delegated agents (GLM/Kimi/Codex) reliably produce green mocked tests — the diff
review must independently check the DB contract, and watch for unrequested app-wide
scope creep. See [[project_sample_tracking]].
