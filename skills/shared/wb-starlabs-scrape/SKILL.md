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

Use the user's authenticated Chrome session. The user performs every login and MFA step. Never inspect or enter cookies, passwords, MFA codes, browser storage, or authentication tokens. Treat both portal pages as read-only: never click Save, Submit, approval controls, or anything that creates or changes a Warner record.

## Property-character scrape

1. Prove the Product page is loaded and note the selected contract/account scope.
2. Record Warner's exact hierarchy and vocabulary. Keep `Franchise` and `Property` as separate source fields until evidence proves how they relate. Preserve sub-brands and Warner IDs without flattening them.
3. First inspect the page's already-loaded client state. Prefer one local read over a per-item crawl that repeats server requests.
4. It is permitted to populate the required submission fields with valid existing choices solely to enable `+Add Product` and expose the read-only catalogue. Use the least specific valid choices available, record the chosen scope as crawl provenance, and do not upload a line sheet.
5. Open `+Add Product`, read the Product catalogue and Characters, then close the dialog without adding a product. Never click a final Add/Save action inside the dialog.
6. Preserve the exact label and source ID when one is exposed. Keep `No Reportable Elements`, `No Character Likeness`, `Logo`, and similar royalty placeholders verbatim.
7. Emit one row per exact source relationship, falling back to exact labels only when the portal exposes no IDs. Mark the fallback explicitly.
8. Save capture timestamp, source URL, account/contract scope, line of business, entitlement scope, and any failure or incomplete page as crawl provenance. State that this is a point-in-time snapshot, not Warner's full catalogue or a change feed.

Run UI automation in resumable batches of at most three properties. A 10-property browser batch exceeded the one-minute control limit on 2026-08-07 and returned no durable output. Persist each completed batch before starting the next one.

The Product page is backed by Nuxeo at `https://dam.starlabs.warnerbros.com`. Its application bundle showed two useful read operations without exposing credentials:

- Property choices call `javascript.SearchField` with `field: "contract:property"` and the contract document ID.
- Character choices call `javascript.SearchField` with `field: "property_schema:character"` and the selected property document ID.

Both results carry `label` and `id`. Capture those source IDs when the authenticated page exposes them through its normal data flow. Do not inspect or record cookies, access tokens, local storage, or the page's Nuxeo-key endpoint. If a safe first pass can capture only labels, set `id_fallback=true` and schedule an ID-enrichment pass instead of inventing IDs.

The refreshed Product form proved that `+Add Product` stays disabled until the required submission scope is populated. The owner explicitly authorized temporary field population for catalogue exposure on 2026-08-07. This authorization is narrow: select valid existing values, open the catalogue, capture metadata, and leave without adding a product or submitting the job. Never click Submit, even if it becomes enabled.

The successful 2026-08-07 Product crawl refined the guard behavior: selecting a valid Contract, its Territories, and one Property enabled `+Add Product`; Tier of Distribution, Retailer, and Consumer Target were not required in that page state. The Property select loaded the full entitled contract list at once with `id`, `label`, and `value`. Capture that loaded array once instead of scraping visible menu text.

Inside Add Design, the Character menu visibly renders 20 rows, but its React component receives the complete array returned by `fetchCharacters(propertyID)`. Some properties returned more than 100 rows. Read the loaded `data` array with each row's Warner `id` and exact `label`; do not mistake the visible 20-row menu for a server limit. Changing `propertyID` through the form's normal state update triggers `fetchCharacters` again. Run and persist batches of no more than three properties. Use `scripts/append_property_character_batch.mjs` to append `links-property-character.csv` plus new supporting Property and Character identities without duplicates.

After the last batch, close the Add Design dialog without pressing OK, then reload the Product page to clear the temporary form state. Verify Submit is disabled. This proves the crawl did not add a product or submit a job.

Use the Product page as direct relationship evidence when its list is safely available. Warner's Character list is broader than people: it can include vehicles, locations, logos, groups, combined elements, and royalty placeholders. Preserve first; classify later. Treat any `WW` code as ambiguous because internal systems have used it for both WWE and Wonder Woman.

## Site-wide direct style-guide relationship audit

A 2026-08-07 audit covered every reachable STARLABS page: Home, Product, Packaging, Marketing, Jobs, Art Assets, and Licensee Help. It also checked the loaded STARLABS page components and submission application code. No page or read operation exposed a direct style-guide-to-property or style-guide-to-character relationship.

Keep these evidence types separate:

- Product and Packaging expose direct Property-to-Character choices through `javascript.SearchField` using `contract:property` and `property_schema:character`.
- Art Assets exposes independent Franchise/Property, Style Guide, and Character aggregations plus asset metadata. These are parallel asset fields, not a style-guide hierarchy.
- The Product/Packaging asset picker can display `public:styleGuideName` on an asset while filtering the available assets by `public:property`. That is asset metadata, not a direct guide-to-property link. The picker also excludes style-guide-package, printable-style-guide, and brand-guideline themes.
- Marketing, Jobs, Home, and Help expose no direct style-guide relationship control or data operation.

Therefore, do not create direct style-guide-to-property or style-guide-to-character rows from asset co-occurrence. Such rows are inferred through an asset and must be stored separately and labeled as inferred if the downstream model needs them. Create a direct link only if Warner later exposes a dedicated field, endpoint, or catalogue that explicitly returns both source identities as one relationship.

## Warner Franchise hierarchy

STARLABS does have a distinct Franchise concept in addition to Property. Art Asset documents expose separate `public:franchise` and `public:property` fields, even though the visible filter is labeled `Franchise / Property`. Preserve both source fields. Do not flatten Franchise into Licensor or Property.

Treat Franchise as a candidate brand level between Warner Bros. and Property, similar to other licensors' franchise level, but do not create a direct Franchise-to-Property parent link from asset co-occurrence. One asset can carry many properties, and the same property label can appear on assets carrying different franchise labels. That evidence supports asset-to-franchise and asset-to-property links only.

Create a direct Franchise-to-Property link only when STARLABS exposes the relationship on a Property record, in a dedicated catalogue, or through an operation returning both source identities as one parent-child record. Until then, keep any Franchise-to-Property association derived through assets separate and mark it as inferred.

## Art Assets scrape

Use Art Assets for franchises/properties, style guides, characters, files, and their source relationships. The Nuxeo provider is `WBCPAssetSearchPublic`. Its visible page size can vary, and the provider safely accepted a read-only page size of 1,000 on 2026-08-07. Observed fields include `public:property`, `public:styleGuideName`, and `public:character`; property and character can be multi-value.

The Art Assets page does not return results for an empty search. Use a narrow filter batch. Its Polymer `paper-checkbox` controls may ignore automation while their group is collapsed; open the group, interact with the visible checkbox, then run Search. Switch results from Thumbnails to Details to expose the asset UUID and relationship columns without opening or downloading the asset.

Initial filter panes displayed round limits rather than proven complete lists: 100 Franchise/Property values, 100 Style Guide values, and 100 Character values. Treat these as partial until client state, pagination, or another supported control proves completeness. A first Details record exposed one asset UUID, an exact file name and source path, dates, one style guide, many Franchise/Property values, and a blank Character field. This proves multi-property asset links can occur; it does not prove the general style-guide hierarchy.

A fresh authenticated load on 2026-08-07 exposed exactly 100 `buckets` and 100 `extendedBuckets` in each of the Polymer `property`, `styleGuide`, and `character` aggregations. No aggregation exposed a total bucket count or a supported filter-value paging control. The asset result provider is separate and its page size is mutable. Therefore the already-loaded aggregation state is a capped window, not a hidden complete catalogue. Use narrow supported searches and result pagination for completeness; do not rely on the round filter counts. A prior 120-row Character capture was incorrect: its last 20 rows came from the next Language panel. Bind extraction to the named aggregation component, never to a cross-panel sequence of checkboxes.

The result provider is backed by Elasticsearch with a hard 10,000-result window. Requests whose offset plus size exceed 10,000 can return the first page again or surface `Result window is too large`; a changing Polymer `page` value alone does not prove progress. Fingerprint each page by its first and last asset UUID and stop a pass when those fingerprints repeat. For a brand with more than 10,000 results, capture both `dc:modified desc` and `dc:modified asc`, dedupe by asset UUID, and use additional supported stable sort fields such as `dc:created`, `ecm:path`, `file:content/name`, `file:content/length`, `ecm:uuid`, and `public:wbcpAssetId` when the total exceeds 20,000. Use exact aggregation partitions (`Public_property_agg`, `Public_character_agg`, `Public_theme_agg`, `Public_season_agg`, or `Public_styleGuideName_agg`) to close any remaining gap. Each partition must remain read-only and under the same 10,000-result limit. Confirm completeness from unique asset UUIDs plus known cross-brand overlap, not from page-number movement.

On the Product submission page, `+Add Product` was disabled on 2026-08-07 while required submission fields were blank. The franchise/property/character catalogue was not present in the visible DOM or obvious page memory before the dialog opened. Populate only the required dropdowns with valid existing choices to unlock it, capture the catalogue, then leave the draft unsubmitted. Never click Upload Line Sheet, a final Add/Save control inside the product dialog, or Submit.

Each aggregation bucket's `key` is a Warner/Nuxeo UUID. Its already-loaded `fetchedKey` document exposes the exact display title and the same UUID. This is the preferred safe metadata-only ID enrichment path. Read only those identity fields and the fields required by the output contract; do not retain permissions, thumbnails, contributors, or other unrelated document metadata that may also be present in `fetchedKey`.

Exact labels are not identities. One duplicated loaded Character label appeared under two different Warner UUIDs, and separate one-result searches linked those UUIDs to different assets, properties, and style guides. Preserve both rows. Compare source IDs, never names, when testing whether one Character identity belongs to multiple Properties.

After using the Art Assets `Clear` control, wait for its asynchronous reset to finish; the open filter group collapses when the reset completes. Reopen the intended group before clicking the next visible checkbox. A semantic checkbox click can report success while leaving `checked=false` if the group is collapsed. Always verify `checked=true` before Search.

Treat the links as the deliverable. Separate name lists are supporting data. For every asset record, capture every relationship Warner exposes:

- asset to style guide
- style guide to Franchise/Property
- asset to depicted characters
- any direct asset-to-Franchise/Property link

Use Warner's IDs wherever available. Record absent relationships explicitly in the private README. Never infer or guess a missing link.

- `style_guide_source_id` is text. Leave it null unless a real Warner guide ID is exposed. Never copy the guide name into the ID column.
- Put `public:styleGuideName` in non-null `style_guide_natural_key`. Promotion may fall back to this natural key when the real source ID is null.
- Use common `property_labels text[]` and `franchise_labels text[]`; never create scalar `property_label` or `franchise_label` fields. Preserve every value even when an asset has several.
- Capture character names per file when exposed.
- Capture explicit Franchise/Property-to-style-guide, Franchise/Property-to-character, and style-guide-to-character links when Warner exposes them. A style guide is a separate many-to-many style axis, not an assumed level between property and character.
- Record every hierarchy level and sub-brand verbatim with Warner's IDs. Do not decide during extraction which level maps to the internal property model.
- Capture each asset file name byte-for-byte, including its extension, capitalization, whitespace, full path, and folder structure when exposed. Do not trim, clean, expand, normalize, or collapse near-duplicates. Never infer a licensor, property, or character from substrings in a file name.
- Capture asset source ID, size, source dates, and listed metadata without downloading the asset itself.
- During a metadata scrape, do not download artwork, PDFs, style-guide documents, previews, or other asset content. If names cannot be captured without a download, stop and report the limitation. Deliberate file retrieval to the NAS is a separate, separately authorized task; see [Asset retrieval to the NAS](#asset-retrieval-to-the-nas).
- Store only the schema's required columns as normal columns. Put useful, recoverable source fields into `raw`; do not store thumbnails, previews, permissions, analytics, or unrelated display filters merely because Nuxeo returned them.

## Asset retrieval to the NAS

This is a different job from the metadata scrape and never runs as a side effect of one. The owner authorized it on 2026-08-18 because the portal's bulk download repeatedly crashes and staff were downloading files one at a time by hand. Retrieval is allowed only for style guides the licensing team has explicitly named. Never download "everything reachable", and never start a retrieval pass without a named list.

Retrieve files one at a time. The bulk/zip download is a separate server-side job and is the thing that fails; single-asset retrieval bypasses it entirely. Pace the requests, and treat a failure as a retry of that one file, never a restart of the batch.

### Destination and naming, as the business already stores it

The Warner library lives at `\\192.168.3.100\styleguides\WB`. Observed structure on 2026-08-18, which new downloads must match rather than invent:

- Level 1 is a Property or brand folder in the licensing team's own wording, not a Warner ID. Some names carry a year or a qualifier, and some carry a leading `_` to sort administrative folders to the end.
- Level 2 is optional and varies per property: a release-year folder, a numbered ordering prefix, or a category grouping. It exists where a property has many guides and is absent where it has few. Do not add a level that a property does not already use.
- The deepest folder is one style guide, named after the portal's Style Guide value, usually with the licensing team's season prefix in front of it. Windows-illegal characters in the portal name are substituted, not stripped.
- Some properties also hold loose files directly at the property level, outside any guide folder. Leave that alone; do not tidy or reorganize existing folders during a retrieval pass.
- Asset file names are stored byte-for-byte as the portal serves them, including capitalization and extension case. Never rename, normalize, deduplicate, or re-case a downloaded file.

Confirm the exact folder path and any season prefix with the licensing team before creating a new folder. The folder layer is a human convention that this skill records but does not own.

### Building the checklist

The Art Assets Style Guide filter exposes each guide's exact name together with its asset count. That count is the completeness target for a retrieval pass: a guide's folder is done when its file count matches, and the mismatch tells you what to retry. Record the count at capture time, since it can move.

Write a per-guide checklist file listing each asset's file name, UUID, and result, and update it as each file lands. The pass must resume from that file after a crash instead of starting over.

### Reading the filter panels

The filter aggregations are Polymer `wbcp-checkbox-aggregation` elements nested several levels deep in shadow DOM; a plain `document.querySelector` will not reach them. Walk `children` and `shadowRoot` recursively with a visited set and a depth limit of about 40. Select a panel by its `label` property (`Brand`, `Season`, `Franchise / Property`, `Style Guide`, `Category/Theme`, `Subcategory`, `Character`, `Language`); the `field` property does not survive JSON serialization and reads as null. Each bucket carries `key`, `docCount`, and a `fetchedKey` whose `properties.label` is the display name. Some labels begin with a leading space, so trim before matching against a folder name. A panel must be expanded in the UI before its buckets populate; a collapsed panel reads as zero buckets.

Brand and Style Guide are separate axes. Brand is `public:franchise` and returned a small closed list backed by a Nuxeo `franchise` directory whose entry `id` is the brand name itself, not a UUID. The Style Guide panel remains capped at 100 buckets, so it is a window, not the full catalogue; the 10,000-result and partition rules in the Art Assets section still apply.

### Session gate

Warner SSO renders as a blank solid-colour page when the session is not authenticated, with the URL sitting on `ssobiz.wbd.com/app/.../sso/saml`. That is a sign-in prompt that never painted, not a portal outage. Stop and ask the user to sign in; never attempt the login, MFA, or any credential step.

## Output and validation

Write UTF-8 CSV with the columns and private-repo layout in [references/output-contract.md](references/output-contract.md). Keep all licensed rows and examples out of public repositories, Markdown, commit messages, PR text, logs sent to outside services, and the shared-db Git history. Store and commit extracts only in the private `u2giants/licensor-source-data` repository under `warner-bros/`. Never make that repository public or add collaborators.

Clone the private repository fresh, work on a dedicated Warner branch, and open a pull request. Never commit directly to its `main`. Never read, modify, rename, or delete `disney-opa/`; another session owns it.

Document the extract beside the private data using `shared-db/docs/verification/opa-characters-20260806/README.md` as the structural template. Include the portal in plain language, exact URLs and parameter meanings, a reproducible local extraction snippet, row and distinct counts, columns, entitlement and line-of-business scope, hierarchy findings, failed attempts, and confirmation that the user alone handled login/MFA.

Run:

```text
python scripts/validate_relationship_csv.py <csv>
```

Do not load rows unless validation passes and every crawl gap is explained.

## Shared database gate

**Reading is allowed; changing is not.** You may inspect the live shared Supabase structure in full — schemas, tables, columns, keys and relationships, indexes, constraints, views, functions/RPCs, triggers, RLS policies, migration history, generated types, metadata, and safe sample data — and compare it against the Warner source shape to decide whether the database fits. That review needs **no** GitHub issue and no dispatch. Never place scraped Warner rows or examples in anything you write outside the approved private source-data repo.

Do not start a database **change**. If the extract implies a schema change, **open a GitHub issue** and stop — `gh issue create --repo u2giants/shared-db --label db-work --title "<the outcome you need>" --body-file <file>`. The active orchestrator owns migrations and database writes. Never place scraped rows or examples in that request. *(Corrected 2026-08-09: this said to copy a request template into `COORDINATOR_INTAKE.md` under `## REQUEST QUEUE`; that file was retired on 2026-08-07 and a required check now fails any PR that writes into it.)*

The source layer must preserve Warner values. Promotion into `core.property`, `core.character`, and the many-to-many property-character bridge is a later, idempotent reconciliation step. Unresolved labels are reported, never invented.

## Learning loop

After each real scrape, update this skill with durable portal behavior: endpoints, pagination, IDs, failure modes, sentinels, and exact recovery steps. Never add licensed scrape rows, credentials, account numbers, contract numbers, or other confidential values to the skill. Explicitly report whether the entitled catalogue contains Adventure Time, Over the Garden Wall, Regular Show, and Smiling Friends, but keep their extracted records only in the private data repository.
