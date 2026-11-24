# Authenticated ASGARD API

## Endpoints and query shape

The public application bundle exposed base API `https://api.asgard.mvlhub.com` and style-guide base `/style-guides`.

- Assets: `GET /style-guides/search-assets`
- Facets: `GET /style-guides/search-filters`

Select a leaf with exact hierarchy query parameters `mrlc_attr_tier_1`, `mrlc_attr_tier_2`, and further numbered tiers as needed. Page with `page` and `limit`. Never use a title-only fuzzy query when an exact hierarchy path is available.

The outer response is `{message,data}`. Asset search data contains `{data,pageCount,totalCount,facets}`.

Observed asset fields include `styleGuideFileId`, `styleGuideAssetId`, `originalFileId`, `name`, `fileSize`, `displayOrder`, `canDownload`, `thumbnailUrl`, `fileDownloadUrl`, `asgardMasterBaseUrl`, `renditions`, `wmFlag`, `styleGuideTitle`, `iteration`, `artworkType`, `imageColoration`, `actorLikness` (the source API misspelling), `characterName`, `characterAction`, `mrlc_attr_descr_keywords`, `colorists`, `inkers`, `pencilers`, and `painters`.

Observed facet names include Actor Likeness, Character Action, Character Name, Image Coloration, Iteration, Artwork Type, Style Guide Title, and sometimes Descriptive Keyword. Style Guide Title is context, not an asset relationship term.

Filter discovery can use `/search-filters?filter=character-names&styleGuideName=<exact title>`. Asset membership uses the singular parameter form, for example `characterName=<exact value>`.

## Private implementation

Use `marvel-asgard/scripts/api-facet-enricher.mjs`. It reads the Chrome token into memory, fetches exact leaf paths, preserves raw responses, reconciles identities, writes leaf facet evidence, and saves progress atomically with a temporary file and rename.

Default to a page limit of 500 for ordinary leaves. If the server returns HTTP 500 at that size, retry the same leaf at 100 and then 25. Retry transient 429 and 5xx responses with bounded exponential backoff. HTTP 401/403 is an authentication stop, not a transient retry. Never mark a failed request as an empty leaf.

An exact empty result may contain only `data.data: []` and omit both `pageCount` and `totalCount`. Treat that specific shape as a proven empty result and stop paging. Do not compare an absent page count numerically: an earlier client looped forever, generated repeated empty requests, and eventually surfaced a misleading HTTP 500. Missing pagination on a non-empty response remains a shape error.

## Identity reconciliation

Treat API `originalFileId` as the stable source asset UUID. Preserve browser-observed ID, `styleGuideFileId`, and `styleGuideAssetId` separately. Some DOM UUIDs proved to be unrelated or stale card-image identifiers.

Resolve each observation only with evidence: browser ID equals `originalFileId`; browser ID equals `styleGuideFileId`; exact filename is unique within the exact leaf; duplicate filename is resolved by exact duplicate occurrence and leaf order; or rebuild that leaf from exact-path API evidence.

Reconcile the whole leaf by exact filename multiset, not only row order; API ordering can shift. If browser total or filename multiset differs, create a recoverable pre-API backup, replace only that exact leaf with API observations, and update its guide summary. Do not silently patch individual rows until the complete leaf reconciles.

A proven repair involved a Branding leaf that showed 23 browser assets copied from other paths while its exact API path contained 3. Exact-path replacement was correct; title similarity or nearby nodes would not have been.

## Facet semantics

Raw multi-value fields often use ` | `. Do not trim-split them into canonical relationships. Intersect raw candidate segments with the API's authoritative facet option values and preserve the original malformed text.

One observed raw value contained an extra trailing space around a character name. Naive trim-splitting produced 71 apparent relationships while the backend facet and an exact filtered request proved 70. When exact membership matters, query the filter parameter for that exact value and retain the backend result as evidence. Never invent the 71st relationship.

## Large leaves

Do not assume ordinary scale. One Publishing archive leaf contained 13,262 assets and 1,051 facet options. Stream or page it, checkpoint it, and verify totals. Avoid loading the entire catalog into browser memory or relying on UI rendering.
