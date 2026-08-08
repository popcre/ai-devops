# Paramount Creative Library portal contract

Use this reference when designing a capture, investigating source IDs, or handing findings to database design. It records the portal behavior observed on 2026-08-07 without storing the licensed allowlist or a source extract.

## System and pages

The site calls itself `Creative Library`. It is one OpenText digital asset management system with Home, Assets, Properties, News, Current Library, Switch Library, Folders, Jobs, and Collections areas.

Observed pages:

- Home: `https://stillsarchive.paramount.com/otmm/ux-html/?view=cl&p=csCLHomePageView`
- Property directory: `https://stillsarchive.paramount.com/otmm/ux-html/?view=cl&p=cs_cl_property_page`
- Property detail/search routes: `https://stillsarchive.paramount.com/otmm/ux-html/index.html?view=cl&p=cs_cl_property_page&property=<numeric-id>` and encoded `searchResults/...` routes
- Search API used by the page: `POST https://stillsarchive.paramount.com/otmmapi/v6/search/text`
- Full asset metadata used by the page: `GET https://stillsarchive.paramount.com/otmmapi/v6/assets` with a selected asset context, `level_of_detail=full`, and metadata loading enabled

The authenticated account showed content across several Paramount brands and divisions. No account-scope statement proved that it sees the company's complete catalogue.

## Paramount labels

Observed first-class labels include:

- `BRANDS` / `Brand Names`
- `FRANCHISES`
- `Priority Properties` / `Property`
- `Collection`
- `Characters`
- `Assets`
- `Content Type`
- `Sub Content Type`
- `File Type (Extension)`
- `Art Style`
- `Colors`
- `Character Count`
- `Collection Type`
- `Year`
- `Language`
- `Seasonal Period`
- `Region`
- `Date: Imported`
- `Date: Properties Last Modified`

The navigation area named `Collections` and the asset metadata facet named `Collection` are different interface surfaces. Do not assume they are identical without source evidence.

## Relationship evidence

Filtering a Property changes the Character facet to the characters found on matching assets, but it does not prove a direct Property-to-Character link. Reconnaissance found Characters in several Property-filtered result sets while their explicit cascading relationship consistently pointed to a different Property carried by the same asset. Property facet counts and Collection facet counts also exceeded the total asset count when summed, proving overlapping tags. Treat Property, Collection, Character, and asset links as many-to-many, and use cascading metadata pairs as the direct relationship source.

Relationships directly visible or returned by metadata:

- Franchise to Property
- Property to Collection
- Property to Character
- Property to asset
- Collection to asset
- Character to asset
- asset to Brand and classification facets

Not established:

- a standalone Character record page;
- Character biography, species, role, or similar descriptive fields;
- a direct Collection-to-Character source table independent of assets;
- a series, season, episode, or title hierarchy in this view.

## Search response shape

The page posts form data to `/otmmapi/v6/search/text`. Safe response fields include:

```text
search_result_resource
  search_result
    asset_group_count
    asset_id_list
    contains_invalid_conditions
    facet_field_response_list
    hit_count
    offset
    total_hit_count
  asset_list
    asset_id
    name
    date_imported
    date_last_updated
    content_size
    content_type
    mime_type
    asset_state
    content_state
    version
    metadata
    master_content_info
    rendition_content
```

Facet records include `field_name`, `_facet_field_request`, `_facet_value_list`, and value objects with `value` and `asset_count`.

The normal search response commonly uses 25 assets per page. The results UI can be changed to 200 per page. The full result is paged in either case. Facet values for one filtered result can arrive in a single response.

The 200-item UI uses lazy-loaded `ot-resource` cards. Each card's `resourceid` is the real asset ID, `ot-resource-index` is its position on the current page, and a child `ot-metadata` `title` carries the displayed file name. Repeatedly scroll the results wrapper to its full height before reading the page. Numbered page controls are grouped; use the visible `Next Page` control to reveal the next group. After selecting a new page, wait for its first `resourceid` to change before collecting it.

Free-text search is not a rights boundary. A business title can return zero text matches while its Property exists, and text matches can span multiple Properties. Resolve the licensed allowlist to exact Property and Franchise facets, capture those scoped results, and deduplicate their asset IDs.

## Identity formats

| Type | Observed source identity |
| --- | --- |
| Property | Positive numeric value, exposed in Property links and full metadata |
| Character | Positive numeric value stored as a string in full asset metadata |
| Asset | 40-character lowercase hexadecimal text |
| Collection | Positive numeric value stored in full asset metadata; slim search can expose only a name and count |
| Franchise | Positive numeric value exposed in full asset metadata |

Store source IDs as text at the ingestion boundary unless the database design has a strong reason to cast the numeric types. Text preserves the source byte-for-byte and leaves room for future nonnumeric values. If database design chooses numeric columns, keep the raw text value too.

## Character ID discovery

The sidebar facet field is named `CHARACTER_ID`, but its filter `value_list` contains the display name. The rendered checkbox ID also embeds the name and list position. Neither is the character's source ID.

The real ID was found by allowing the normal UI to load one selected asset's full metadata. Opening custom-download configuration caused the UI to request `/otmmapi/v6/assets` with full detail and inherited metadata. No media download occurs until the user accepts terms and clicks Finish; the inspection stopped and canceled before those actions.

Two metadata structures revealed identity:

```text
id: CHARACTER_ID
domain_id: CUSTOM.CP_CREATIVE_LIBRARY.CHARACTER
table_name: CP_ASSET_CHARACTERS_CHARACTER
value.value.display_value: <exact character name>
value.value.field_value.value: <numeric character ID as text>
```

The source relationship is also present as a cascading value:

```text
id: CUSTOM.CP_CREATIVE_LIBRARY.CASCADE_CHARACTER_ID
cascading_group_id: CUSTOM.CP_CREATIVE_LIBRARY.CHARACTERS
table_name: CP_ASSET_CHARACTERS_DATA
element key 1: Property display name and numeric Property ID
element key 2: Character display name and numeric Character ID
field_value.value: <property_id>^<character_id>
```

This proves that Paramount assigns a true Character identity and stores an explicit Property-to-Character pair. Do not generate local Character IDs merely because the slim facet response hides the source ID.

The active Property filter is discovery context only. It is not relationship evidence. Create a direct Property-to-Character link only from `CUSTOM.CP_CREATIVE_LIBRARY.CASCADE_CHARACTER_ID`.

Each populated combined value contains one Property and one Character. A multi-character asset carries separate combined values rather than one value with several Character IDs. Require exactly one `^`, split into two non-empty source IDs, and reject malformed values. Do not infer a missing Character relationship from the file name or a Character Count classification.

## Property, Collection, and Franchise metadata

Full asset metadata exposes these identity descriptors:

```text
Property:
  id: PROGRAM_ID
  domain_id: CUSTOM.VIACOM_INT_GCC_PROGRAM_DATA
  table_name: CL_ASSET_PROGRAM
  ID: value.value.field_value.value
  label: value.value.display_value

Collection:
  id: COLLECTION_ID
  domain_id: CUSTOM.CP_CREATIVE_LIBRARY.COLLECTION
  table_name: CP_ASSET_COLLECTION_COLLECTION
  ID: value.value.field_value.value
  label: value.value.display_value

Franchise:
  id: FRANCHISE_ID
  domain_id: CUSTOM.VIACOM_INT_GCC_FRANCHISE
  table_name: VIACOM_INT_ASSET_FRANCHISES
  ID: value.value.field_value.value
  label: value.value.display_value
```

The direct Property-to-Collection relationship is present as:

```text
id: CUSTOM.CP_CREATIVE_LIBRARY.COLLECTION_DATA_ID
cascading_group_id: CUSTOM.CP_CREATIVE_LIBRARY.COLLECTION_CASCADE
table_name: CP_ASSET_COLLECTION_DATA
field_value.value: <property_id>^<collection_id>
```

Treat the pair as authoritative. The visible Collection filter uses the display name and does not expose the numeric ID.

## Field quality and gaps

- Asset ID, name, imported date, updated date, size, content type, and MIME type were filled in the small reconnaissance sample.
- Blank facet buckets were common and appeared as `undefined` or a missing `value`.
- UI date input uses `MM/DD/YYYY`. API dates use ISO 8601 with a timezone.
- Assets expose state flags such as checked-out, locked, deleted, expired, latest-version, subscribed, and editable.
- No negative/sentinel IDs, backtick apostrophe defect, surname-first Character names, or obvious test rows were found in the small sample.
- Duplicate names and case-only duplicates were not tested across the full entitled catalogue.

## Failed or misleading approaches

- Reading only the visible Character facet finds names and counts, not source IDs.
- Trusting the field label `CHARACTER_ID` is wrong because the slim request sends a name as its value.
- Treating a Character found under an active Property filter as directly linked to that Property creates false relationships. Use the cascading pair.
- Reading only the visible Collection or Franchise label misses its numeric source ID; inspect full metadata.
- Treating the initial five facet values as a cap is wrong; `Show more...` expands the panel and the response may already contain all values for the current filtered result.
- Assuming the account sees all Paramount content is unsupported.
- Printing complete Chrome network events is unsafe because request headers can include a live bearer token. Sanitize before output.
- Double-clicking an asset can open download configuration rather than a metadata detail page. Use it only as a deliberate metadata-load step and cancel without clicking Finish.
- Trusting free-text title totals as the licensed asset total is wrong. Use exact Property and Franchise scope, then deduplicate IDs across source labels.
- Treating zero free-text matches as a missing Property is wrong. Check the Property directory and named facet panels.
- Reading one 200-item page before forcing lazy loading silently misses cards.
- Clicking a later page and reading immediately can duplicate the prior page because cards refresh asynchronously. Wait for the first asset ID to change.
- Holding a large run only in browser memory loses progress when a control call times out. Persist every completed page and metadata batch.
- Reusing a full-metadata request copied from another view can retain a hidden `LAYOUT` filter. Remove unrelated inherited filters and verify the safe request fields before trusting its scope.
- A complete card index is not a complete scrape. Every authorized asset still needs full metadata before IDs and relationships can be reconciled.

## Capture estimate

Do not estimate a full capture from a small reconnaissance sample. One licensed title can contain tens of thousands of search results. Indexing is only the first pass; full metadata must then be fetched for every deduplicated authorized asset. Use page and metadata checkpoints so a timeout resumes from durable progress instead of restarting.

The largest design risks are business-name-to-source-name mapping, false confidence from free-text searches, overlapping many-to-many relationships, lazy-loaded pages, grouped pagination, inherited hidden filters, name-only Collections, blank buckets, and ensuring every source ID comes from full metadata rather than a display label.
