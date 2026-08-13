---
name: sandbox-test-images
description: "How test images were bulk-loaded into sandbox-albert, and how to roll them back"
metadata: 
  node_type: memory
  type: project
  originSessionId: 623979a5-8cd7-43c0-87de-eaed361d813f
---

On 2026-06-29, all 19,202 Item Library items in **sandbox-albert** were given 4 images each (gallery + primary) to make the image feature testable. Images were **recycled** from existing objects already in the DigitalOcean Spaces bucket `dflowbucket` (sfo3) — no new uploads. The original ask referenced `P:\Images` (22,975 real product photos, codes embedded in filenames), but only ~20% matched items, so recycling existing bucket images was chosen for full coverage.

**Mechanism (all via the app's own sandbox API, never direct DB):** for each item, `POST /api/core/saveTechLink/:id` with `flag:'image-thumbnail-create'` creates an `itemAttachment` row whose link is `PUBLIC_URL/<fileName>`; pass an existing bucket key as `fileName` to recycle. `POST /api/item_master/detail/setPrimaryImage` sets the primary. Auth = raw JWT from the logged-in browser `localStorage.token` (header `Authorization: <token>`, NOT Bearer). Item list comes from `GET /api/item_master/lib/getApiAllItems/` (field `itemNum` = style code).

**RFQ rows** (`/api/core/getAllItem`, POST) derive their picture from the linked item's `itemAttachment` (lib.model.js:78-82), so filling items auto-populated RFQ pictures — no separate RFQ run needed.

**Rollback:** every bulk row's uuid has prefix `e1e10000-`. One statement: `DELETE FROM "itemAttachment" WHERE uuid LIKE 'e1e10000-%';`. Do NOT delete bucket objects (they're shared real images). See also [[aggrid-v36-legacy-theming]], [[dflow-delivery-workflow]].

Note: `getAllitems` (item library grid endpoint) throws `LIMIT NaN` if called without `startRow`/`endRow` query params — latent robustness gap, harmless in normal UI use since the grid always sends them.
