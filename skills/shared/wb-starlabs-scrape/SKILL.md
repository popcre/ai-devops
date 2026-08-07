---
name: wb-starlabs-scrape
description: Safely capture Warner Bros. STARLABS portal source data, especially the direct Franchise/Property-to-Character lists on the Product submission page and style-guide/file metadata from Art Assets. Use when asked to scrape, refresh, inspect, validate, or load Warner STARLABS properties, characters, style guides, or licensed asset records, or when investigating the portal fields and IDs that feed shared-db.
---

# WB STARLABS scrape

Capture Warner source truth without submitting a job or turning raw labels into canonical data prematurely.

## Mandatory sources

- Direct property-character relationship: `https://portal.starlabs.warnerbros.com/submit/product/`.
- Style-guide and file metadata: `https://portal.starlabs.warnerbros.com/#!/search`.
- Database contract: `shared-db/docs/licensor-portal-scrape-source-schema-20260807.md`, especially sections 3 and 4.

Use the user's authenticated Chrome session. Never inspect cookies, passwords, browser storage, or authentication tokens. Never click the page's final `Submit` button. Opening `+Add Product` is safe; close the blank dialog with `Cancel` after reading it.

## Property-character scrape

1. Prove the Product page is loaded and note the selected contract/account scope.
2. Enumerate every Property option available to that account. Preserve each label and source ID verbatim.
3. Select one property at a time.
4. Click `+Add Product`, open Characters, and capture every option returned for that property.
5. Preserve the exact label and source ID when one is exposed. Keep `No Reportable Elements`, `No Character Likeness`, `Logo`, and similar royalty placeholders verbatim.
6. Emit one row per exact `(property_source_id, character_source_id)` pair, falling back to exact labels only when the portal exposes no IDs. Mark the fallback explicitly.
7. Save capture timestamp, source URL, account/contract scope, and any failure or incomplete page as crawl provenance.
8. Cancel the blank Add Design dialog. Do not add a product and do not submit the job.

Run UI automation in resumable batches of at most three properties. A 10-property browser batch exceeded the one-minute control limit on 2026-08-07 and returned no durable output. Persist each completed batch before starting the next one.

The Product page is backed by Nuxeo at `https://dam.starlabs.warnerbros.com`. Its application bundle showed two useful read operations without exposing credentials:

- Property choices call `javascript.SearchField` with `field: "contract:property"` and the contract document ID.
- Character choices call `javascript.SearchField` with `field: "property_schema:character"` and the selected property document ID.

Both results carry `label` and `id`. Capture those source IDs when the authenticated page exposes them through its normal data flow. Do not inspect or record cookies, access tokens, local storage, or the page's Nuxeo-key endpoint. If a safe first pass can capture only labels, set `id_fallback=true` and schedule an ID-enrichment pass instead of inventing IDs.

This Product page is the authoritative source for the relationship. Do not infer the relationship from Art Assets when this list is available. Warner's Character list is broader than people: it can include vehicles, locations, logos, groups, combined elements, and royalty placeholders. Preserve first; classify later.

## Art Assets scrape

Use Art Assets only for style guides and files. The Nuxeo provider is `WBCPAssetSearchPublic`, page size 96. Observed fields include `public:property`, `public:styleGuideName`, and `public:character`; property and character can be multi-value.

- `style_guide_source_id` is text. Leave it null unless a real Warner guide ID is exposed. Never copy the guide name into the ID column.
- Put `public:styleGuideName` in non-null `style_guide_natural_key`. Promotion may fall back to this natural key when the real source ID is null.
- Use common `property_labels text[]` and `franchise_labels text[]`; never create scalar `property_label` or `franchise_label` fields. Preserve every value even when an asset has several.
- Capture character names per file when exposed.
- Store only the schema's required columns as normal columns. Put useful, recoverable source fields into `raw`; do not store thumbnails, previews, permissions, analytics, or unrelated display filters merely because Nuxeo returned them.

## Output and validation

Write UTF-8 CSV with the columns in [references/output-contract.md](references/output-contract.md). Keep confidential scrape data out of this public ai-devops repo. Store it only in the private task workspace or the approved private shared-db artifact location.

Run:

```text
python scripts/validate_relationship_csv.py <csv>
```

Do not load rows unless validation passes and every crawl gap is explained.

## Shared database gate

Before any database work, use the shared-db coordinator workflow. Verify live schema read-only. If required tables or columns are absent, file the request in `COORDINATOR_INTAKE.md`; do not run DDL directly. Every migration is additive, preview-first, and separately verified.

The source layer must preserve Warner values. Promotion into `core.property`, `core.character`, and the many-to-many property-character bridge is a later, idempotent reconciliation step. Unresolved labels are reported, never invented.

## Learning loop

After each real scrape, update this skill with durable portal behavior: endpoints, pagination, IDs, failure modes, sentinels, and exact recovery steps. Never add licensed scrape rows, credentials, account numbers, or other confidential values to the skill.
