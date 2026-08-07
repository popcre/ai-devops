---
name: paramount-creative-library-scrape
description: Safely inspect, reconcile, or capture licensed Paramount Creative Library metadata for Properties, Franchises, Collections/style guides, Characters, assets, and their source IDs and relationships. Use when asked to scrape, refresh, research, validate, map, or load Paramount portal data from stillsarchive.paramount.com, or when database design depends on Paramount's field names, numeric character/property IDs, asset IDs, pagination, or many-to-many links.
---

# Paramount Creative Library scrape

Capture Paramount source truth without downloading licensed media or changing the portal.

## Mandatory sources and vocabulary

- Home: `https://stillsarchive.paramount.com/otmm/ux-html/?view=cl&p=csCLHomePageView`
- Property directory: `https://stillsarchive.paramount.com/otmm/ux-html/?view=cl&p=cs_cl_property_page`
- Search endpoint observed through the authenticated UI: `POST /otmmapi/v6/search/text`
- Detailed portal field map and ID discovery: [references/portal-contract.md](references/portal-contract.md)

Preserve Paramount's terms in the source layer:

- Paramount `Property` maps to POP `Property`.
- Paramount `Collection` maps to POP `Style Guide`.
- Paramount also exposes `Brand` and `Franchise`. POP does not use Franchise as a canonical entity, but preserve it as source provenance. Do not silently flatten it.

## Non-negotiable safety rules

1. Use the user's already-authenticated Chrome session. The user performs login and MFA. Never ask for, type, inspect, or record passwords, MFA codes, cookies, browser storage, bearer tokens, or other authentication data.
2. Treat the portal as read-only. Never click Save, Save for Later, Submit, Approve, Add to collections, or any control that creates or changes a Paramount record.
3. Capture names and metadata only. Never download artwork, PDFs, style guides, previews, videos, or original files. Opening a custom-download dialog solely to make the UI load full metadata is permitted; cancel it without accepting terms or clicking Finish.
4. Work only from the user's current licensed-property allowlist. Do not scrape all Paramount properties. Keep the allowlist, extracts, and sample rows out of this public `ai-devops` repository.
5. Store licensed extracts only in the approved private source-data repository and path. Never put them in `shared-db`, this repo, a paste service, logs sent to outside AI services, commit messages, or PR text.
6. Do not perform database work from this skill. Route schema or load work through the active `shared-db` coordinator.

When using Chrome network inspection, never print raw request headers or whole request events. They can contain a live `Authorization` header. Emit only sanitized method, path, safe request fields, and the small response fields needed for the task.

## Portal shape

Treat Paramount as a digital asset library, not a product-submission form. It exposes Brands, Franchises, Properties, Collections, Characters, assets, content types, file types, art styles, colors, character-count categories, collection types, years, languages, seasonal periods, and regions.

Model the observed relationships as many-to-many source links, not a rigid tree:

- Franchise to Property
- Property to Collection
- Property to Character
- Property to asset
- Collection to asset
- Character to asset
- asset to Brand and other metadata facets

Do not infer Collection-to-Character or Property-to-Character links from names. Derive them from the filtered facet result or, preferably, each asset's full metadata. One character can appear under more than one Property, one asset can carry several Properties, and one asset can carry several Collections and Characters.

## Browser procedure

1. Attach to the user's open Paramount tab through the Chrome control skill.
2. Confirm the page is `stillsarchive.paramount.com` and the Creative Library content is visible. If authentication is required, stop and ask the user to sign in.
3. Start from the user's licensed-property allowlist. Resolve each business name to Paramount's exact Brand, Franchise, and Property labels before capturing data. Record aliases rather than guessing.
4. Open a Franchise or Property. The result page applies a facet filter. Remove that filter with its visible clear control to return to the broader list, then move to the next allowed item.
5. Expand `Show more...` inside the named facet panel when needed. Bind reads to that panel. Do not read a cross-panel run of checkboxes because adjacent panels can be mistaken for Character rows.
6. Verify every clicked facet is actually checked after the asynchronous refresh. A click can appear to succeed while the page rerenders.
7. Read the current result count, Property values, Collection values, Character values, and their asset counts. Treat blank buckets rendered as `undefined` as missing source data, not as a real identity.
8. Page assets in stable, resumable batches. The default is 25 assets per page. Fingerprint each page with its first and last asset IDs and stop if a page repeats.
9. Preserve exact labels, punctuation, capitalization, whitespace, file names, source IDs, counts, and observed relationships. Do not clean or merge names during extraction.
10. Restore the user's original useful view and leave the tab open unless the user asked for it to be closed.

## Use the clean search response

Prefer the portal's own authenticated search response over visual card scraping. Observe the normal UI request to `POST /otmmapi/v6/search/text`; do not copy or replay its credentials outside the browser.

The response provides:

- paged `asset_list` records with 40-character lowercase hexadecimal text asset IDs;
- `facet_field_response_list` entries for Property, Collection, Character, and other filters;
- each facet value's exact `value` and `asset_count`;
- `total_hit_count`, `offset`, and other page facts.

The search facet named `CHARACTER_ID` is misleading: its facet value and filter request use the display name, not the real numeric character ID. Do not treat the facet name as proof that an ID was captured.

## Find real Property and Character IDs

Property IDs are positive numeric values exposed in Property-page links such as `property=<id>` and again in full asset metadata.

To reveal a Character ID safely:

1. Filter to a known Property and Character using the visible UI.
2. Select one matching asset.
3. Open the asset's custom-download configuration only far enough for the UI to request full metadata. Do not accept terms and do not click Finish. Cancel the dialog after the metadata response arrives.
4. Inspect only the JSON response body from the authenticated `GET /otmmapi/v6/assets` request whose safe query facts include `level_of_detail=full` and `load_metadata=true`.
5. Locate metadata element `CHARACTER_ID`, whose domain is `CUSTOM.CP_CREATIVE_LIBRARY.CHARACTER` and table is `CP_ASSET_CHARACTERS_CHARACTER`.
6. Read `value.value.field_value.value` as the real Paramount Character ID. It is a numeric string. Read `display_value` as the exact Character name.
7. Locate `CUSTOM.CP_CREATIVE_LIBRARY.CASCADE_CHARACTER_ID` in table `CP_ASSET_CHARACTERS_DATA`. Its cascading entries carry both the Property numeric ID and Character numeric ID. Its combined `field_value.value` uses `<property_id>^<character_id>`.
8. Validate the same Character ID on another matching asset when practical. Preserve the Property-to-Character pair because the same display name can be scoped differently.

Do not log the full metadata response. Extract only the identity fields and relationship fields required by the private output contract.

## Completeness and quirks

- The portal pages assets in chunks; it does not return the entire asset catalogue in one page.
- All facet values for the current filtered result can arrive together in one search response. This does not mean the whole Paramount catalogue arrived.
- Facet panels initially show five values and `Show more...`; this is a display preview, not a five-row cap.
- Blank facet buckets appear as `undefined` or missing `value` fields.
- No negative or sentinel IDs were observed during reconnaissance. Do not assume they cannot exist.
- No duplicate-name or capitalization-only duplicate audit has been completed. Key on source IDs, never names, when IDs exist.
- Characters and Collections appeared name-only in the slim search response. Character IDs were later found in full asset metadata. Collection source IDs remain unproven; do not invent them or copy a Collection name into an ID field.
- Account access is broad across several Paramount brands, but the portal did not prove that the account sees all Paramount content. Describe every capture as the account-entitled, point-in-time view.

## Output and database boundary

Treat source relationships as the deliverable. Capture:

- Brand, Franchise, and Property exact labels;
- numeric Property ID;
- Collection exact label and source ID only if genuinely exposed;
- Character exact label and numeric Character ID from full metadata;
- asset ID, exact file name, size, source dates, and listed non-media metadata;
- explicit Property-to-Character, Property-to-Collection, asset-to-Property, asset-to-Collection, and asset-to-Character links;
- capture time, URL, filters, account entitlement caveat, page progress, and failures.

Keep raw source identities separate from canonical POP records. Reconciliation and promotion are later, idempotent database work. Never infer a missing relationship or manufacture an ID.

## Learning loop

After each authorized scrape, update this skill with durable portal behavior, safe endpoints, pagination, identity fields, failure modes, and recovery steps. Never add licensed rows, rights lists, credentials, tokens, account numbers, or downloadable media to this public skill.
