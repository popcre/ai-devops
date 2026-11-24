# Browser capture and authentication

## Browser role

Use the authenticated Chrome Default profile for login state and UI-only discovery. The principal page is `https://asgard.mvlhub.com/style-guides`. Do not close or rearrange unrelated user tabs. A `basket` to `style-guides` navigation can clear stale SPA state. Opening `/basket` can also trigger the same Okta renewal with less rendering load than the style-guide page.

Chrome may be closed while direct API capture continues if the existing bearer token is still accepted. Never claim that visible browser activity is required for every API request. Conversely, never claim a browser scrape is active when no browser session or valid API token exists.

## Authentication

The Chrome local-storage record is named `asgard_0oa1o8mkwgoR6WkNb697_auth` in the Default profile LevelDB under `%LOCALAPPDATA%\Google\Chrome\User Data\Default\Local Storage\leveldb`. The auth object contains `userInfo.token`.

Read the token into memory only and send it as `Authorization: Bearer <token>`. Never print it, pass it on a command line, write it to a checkpoint, or commit it. A locally stored expiry timestamp may be stale while the API still accepts the token; HTTP 401 or 403 is authoritative. Ask the user to renew login only after the API rejects authentication.

## Hierarchy capture

Capture category -> style guide -> guide node path -> leaf. At each non-empty leaf, enumerate all pages and preserve displayed totals, page numbers, row order, filenames, extensions, sizes, available UUIDs, and raw card evidence. Pre-register the entire visible guide set so missing guides cannot disappear from the denominator.

The verified structural pass on 2026-08-27 found 75 account-visible guides, 1,471 nodes, 1,088 leaves, 2,436 pages, and 44,760 browser file observations, with zero structural guide gaps. These are regression evidence for that capture, not permanent required counts. Of the leaves, 1,073 were non-empty and required facet coverage.

## UI reliability lessons

Thumbnail-heavy pages can freeze the renderer. Browser facet enrichment was too slow and unreliable for the full catalog; use the API once authenticated.

Observed failures included `Runtime.evaluate` timing out at 3 seconds and an outer browser-operation ceiling near 300 seconds. Reliable browser code used explicit evaluation/body reads with a 15-second timeout, avoided convenience calls such as default `count()`, `isVisible()`, and large DOM snapshots, and split navigation from extraction so an outer deadline did not consume the extraction budget.

The private browser scripts include `browser-crawler.mjs` for hierarchy and paged file observations and `browser-facet-enricher.mjs` for bounded UI fallback and diagnosis.

Do not restart a full UI facet crawl merely because an API request failed. Diagnose the exact leaf, retry the API conservatively, and use UI evidence only when the API cannot prove the surface.

## Checkpoint discipline

Write crawl and facet progress durably after every accepted unit. Work files marked `in_progress` are not complete. A browser page reaching an apparent end is insufficient if totals, page fingerprints, or filenames do not reconcile. Do not overwrite an older capture; create a new immutable capture key for a refresh.
