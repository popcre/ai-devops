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

Filtering a Property changes the Character facet to the characters found on matching assets. At least one Character appeared under more than one Property. Property facet counts and Collection facet counts exceeded the total asset count when summed, proving overlapping tags. Treat Property, Collection, Character, and asset links as many-to-many.

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
- a standalone Franchise ID;
- a direct Collection-to-Character source table independent of assets;
- stable Collection source IDs;
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

The normal asset result uses 25 assets per page. The full result is paged. Facet values for one filtered result can arrive in a single response.

## Identity formats

| Type | Observed source identity |
| --- | --- |
| Property | Positive numeric value, exposed in Property links and full metadata |
| Character | Positive numeric value stored as a string in full asset metadata |
| Asset | 40-character lowercase hexadecimal text |
| Collection | No stable source ID proven; slim search exposes a name and count |
| Franchise | No stable source ID proven in reconnaissance |

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
- Treating the initial five facet values as a cap is wrong; `Show more...` expands the panel and the response may already contain all values for the current filtered result.
- Assuming the account sees all Paramount content is unsupported.
- Printing complete Chrome network events is unsafe because request headers can include a live bearer token. Sanitize before output.
- Double-clicking an asset can open download configuration rather than a metadata detail page. Use it only as a deliberate metadata-load step and cancel without clicking Finish.

## Capture estimate

Property, Collection, Character, and relationship capture for a bounded rights list should take hours rather than days when the clean facet response and full metadata are used. Capturing every asset takes longer because asset results are paged. The largest design risks are business-name-to-source-name mapping, overlapping many-to-many relationships, name-only Collections, blank buckets, and ensuring every source ID comes from full metadata rather than a display label.
