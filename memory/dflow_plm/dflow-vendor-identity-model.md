---
name: dflow-vendor-identity-model
description: dflow has TWO unreconciled vendor-identity mechanisms — the root cause of the tracking authorization holes (Group A)
metadata: 
  node_type: memory
  type: project
  originSessionId: b57441dd-c8bf-4a8d-b4e1-adcd2aa896e9
  modified: 2026-07-20T23:53:10.690Z
---

dflow scopes "which factory/vendor is this user" **two different ways that nothing
reconciles**, which is why the tracking service has cross-tenant holes:

1. **Samples** scope by `user.factory_id` → `sample.factory_id_fk`
   (`designflow-tracking/models/sample.model.js`).
2. **Production orders & licensing** scope by looking up `externalVendor` by
   lowercased email → `externalVendor.vendorCode` (the PK), then matching
   `ProdOrderHeader.vendorCode` / `itemHeader.vendor_code_fk`. The correct,
   purpose-built scoped paths are `getFactoryProdOrderList` /
   `updateFactoryProdOrderDates` in `models/lib.model.js` (email→vendorCode +
   7-field whitelist).

**Group A** (tracking authorization boundary) fixes the routes that trust a
client-supplied id or an unbound token instead of using mechanism #2. Verified holes:
- `getProdOrderHeader` / `getLic` reads allow `vendor` with NO scoping — any factory
  reads every competitor's orders/licensing. The scoped read path is 200 lines away
  in the same file.
- `updateProdOrderHeader` / `updateLic` writes: same, vendor writes by bare id.
- Sample photo "send to phone" 48h HS256 mobile link (`MOBILE_LINK_SECRET`) +
  client-supplied S3 `Key` + trusted `attachment_link` = unauthenticated arbitrary
  bucket write AND a confused-deputy delete via `deletePhoto`. Fix requires
  server-owned keys AND distrusting `attachment_link` — key derivation alone is theater.

Vendor-scope predicate for licensing reads: `itemHeader.vendor_code_fk = ev.vendorCode`
(plain column, NOT the `$externalVendor.vendorCode$` association — that's built
dynamically from `UDFTable` metadata and is fragile). The full plan is
`designflow-tracking/docs/group-a-authorization-boundary-plan.md`. See [[dflow-fixes-register]].
