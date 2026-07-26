---
name: plm-is-master-data-authority
description: Designflow PLM is the authoritative (not exhaustive) source for customers/licensors/properties; how it links into Directus and the API auth gotcha
metadata: 
  node_type: memory
  type: reference
  originSessionId: d9b54b7a-0bcf-4b93-bd6b-2c0342ab7201
---

Designflow PLM (ERP-synced) is the authoritative-but-not-exhaustive source for customers, licensors, properties, characters. One-way sync into Directus via `pm-system/sync-plm-masters.mjs` (in the `directus` repo).

**API** (gateway): `https://api.designflow.app/api/item_master/lib/getLicensorsWithProperties` and `.../api/core/customers/getCustomers`. Auth header is **`x-api-key`** with a long-lived `df_live_…` key — NOT `x-apy-key` (the owner pasted that typo once; it 403s) and no longer the old 30-day `X-User-Authorization` JWT.

**Linking:** licensors/properties/characters cross-ref by `plm_mg_code` (unique within parent). Customers map through table `retailer_plm_customer` (PK = PLM `customers_id`) → curated `retailer`, **many-to-one** (banners like TJX corp + HomeGoods → one retailer). PLM `customers_code` is NOT unique (e.g. `OS`).

**Status authority:** first-time customer link promotes a POTENTIAL retailer to ACTIVE; re-runs never change status. Owner overrides are pinned in the script's `CUST_LINK/CUST_CREATE/CUST_SKIP` maps (some PLM ACTIVE customers are kept POTENTIAL or skipped entirely as out-of-business/dup/placeholder). See [[retailer-is-not-a-customer-list]].

**Running the sync:** a `plm-sync.timer` systemd unit runs it **daily at 03:30 local** (host-side, `User=ai`, like the `popcrm-*` timers). Wrapper `pm-system/run-plm-sync.sh` resolves the DB container IP at runtime and runs `sync-plm-masters.mjs` with host node; `pg` is a host dep of the `directus` repo. Secrets are in `/home/ai/.plm-sync.env` (`PLM_API_KEY`, `DB_PASSWORD`; mode 600, not committed). Idempotent. Manual ad-hoc run: `sudo systemctl start plm-sync.service` (watch `journalctl -u plm-sync.service`).
