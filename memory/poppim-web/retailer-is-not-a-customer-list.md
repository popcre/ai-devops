---
name: retailer-is-not-a-customer-list
description: "The Directus `retailer` collection is a raw CRM dump, not customers; only active/potential customers are valid in app pickers"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d9b54b7a-0bcf-4b93-bd6b-2c0342ab7201
---

The shared Directus `retailer` collection is a raw import of EVERY Twenty-CRM company (~3,740 rows; ~97% are `customer_status='OTHER'` = "Not a Customer"). It is NOT a curated list. The user has stated "many many many times" that the only companies applicable to these apps are **customers: active or potential** (`customer_status IN ('ACTIVE_CUSTOMER','POTENTIAL_CUSTOMER')`, ~102 rows).

**Why:** Offering the raw `retailer` collection as a dropdown shows thousands of non-customers (e.g. "1kms" = OTHER). This was a recurring frustration.

**How to apply (today):** Never offer `retailer` raw as a picker. Filter on `customer_status` (active/potential). Use `fetchCustomers()` in `src/features/board/collab.ts`. Buyers hang off a retailer — scope buyer pickers to a chosen customer via `fetchBuyers(retailerId)`. See AGENTS.md §11.

**Structure (APPLIED to prod 2026-06-18):** physically split, not just filter. Rename `retailer` → `ingested_domains` (all ~3,740 rows; ingestion dedup + crm_* relations stay); create a new editable `retailer` = the ~102 active/potential customers **copied** with same IDs; same split for `buyer` → `ingested_contact` + new `buyer` (743 contacts-at-customers). Copy (not move) so the email worker still sees a domain was already ingested. PIM relations repoint to the curated tables; crm_* relations need no change. PIM reads curated `retailer`/`buyer` directly (no filter). The CRM app (`popcrm-web`) is the triage surface and reads/writes the FULL `ingested_*` tables; setting `customer_status` to active/potential fires a `promote_customer` DB trigger that copies the company into `retailer`. crm-worker + twenty-import write to `ingested_*`. Full details + migration in **`/worksp/directus/HANDOFF.md`** + `pm-system/migration/split-customers-from-ingested.sql`. The owner chose physical-split over read-only views (retailer/buyer must stay editable) and over flag-only filtering. NOTE: the `directus`/`popcrm-web` repos had some root-owned files/dirs (`dist/`, a few CRM pages) — `sudo chown ai:ai` was needed to build.

Backing data + worker live in the `directus` repo (`pm-system/migration/twenty-import.mjs`, `pm-system/crm-schema.mjs` customerStatus choices, `pm-system/crm-worker.mjs` ingestion/contact-sync).
