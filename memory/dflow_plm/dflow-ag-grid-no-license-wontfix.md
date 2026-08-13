---
name: dflow-ag-grid-no-license-wontfix
description: "dflow has no AG Grid Enterprise license and never will — the \"Invalid License Key\" console spam is expected, not a bug to report or fix"
metadata: 
  node_type: memory
  type: project
  originSessionId: 035f2a75-254e-4f50-a3eb-f5bd81e89532
  modified: 2026-07-22T18:45:23.512Z
---

DesignFlow PLM (dflow) does not have, and will never purchase, an AG Grid Enterprise
license. The "AG Grid Enterprise License / Invalid License Key" console error block
that appears on every grid page (RFQ, Standardized, Archive, Licensing Tracking,
Production Tracking, Item Library, etc.) is expected and permanent.

**Why:** Albert made an explicit business call not to license AG Grid Enterprise.
The grid still renders and functions correctly with the invalid-key state in the
AG Grid version this app uses (console-only enforcement, no watermark/blocking in
this version) — there is no functional impact today.

**How to apply:** Never list the AG Grid license warning as a bug, failure, or
finding in any future crawl, audit, code review, or QA pass of dflow
(designflow-frontend). Filter/suppress it from console-error triage before
reporting. If a future AG Grid version upgrade starts showing a watermark or
blocking behavior on an invalid key, that would be a new, different, legitimate
finding — but the invalid-key state itself is not actionable.

See [[dflow-fixes-register]] for how dflow bugs are actually tracked, and the
2026-07-22 sandbox crawl findings (`alsand-sandbox-crawl-findings.md` in
`C:\repos\dflow plm`) for the rest of that pass's real findings (points 2-7,
written into HANDOFF.md).
