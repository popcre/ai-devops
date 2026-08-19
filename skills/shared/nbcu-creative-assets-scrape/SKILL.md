---
name: nbcu-creative-assets-scrape
description: Capture NBCU Creative Asset Factory metadata, and download NBCU style-guide assets to Albert's server, for authorized Properties, IP Families, Characters, style guides, assets, file names, source IDs, and explicit relationships. Use when asked to scrape, refresh, inspect, validate, reconcile, or map NBCU, Universal, DreamWorks, Illumination, or NBCUniversal licensed source data from creativeassets.nbcuni.com, including Product Submissions and asset-search work, and when asked to download or pull an NBCU style guide, trend guide, design guide, or its art files to a local folder, the NAS, or an SMB share.
---

# NBCU Creative Asset Factory scrape

Capture NBCU source truth without submitting a project.

Scope note: the read-only rules below govern METADATA SCRAPING only. Downloading style-guide assets to Albert's own server is separate, allowed work when he asks for it by name (owner ruling 2026-08-19).

## Mandatory sources

- Home and entitlement directory: `https://creativeassets.nbcuni.com/content/asset-share-commons/en.html`
- Product property picker: `https://creativeassets.nbcuni.com/content/asset-share-commons/en/pd-submissions.html`
- Asset search: `https://creativeassets.nbcuni.com/content/asset-share-commons/en/search.html`
- Private allowlist and outputs: `C:\repos\licensor-source-data-nbcu\nbcu\`
- Read [references/output-contract.md](references/output-contract.md) before writing capture files.

Use the user's authenticated Chrome session. The user handles login and MFA. Never inspect or record passwords, cookies, browser storage, request headers, access tokens, account numbers, contact fields, or contract text.

During a metadata scrape, treat the portal as read-only. Never accept terms, create or clone a submission, click Next in the creation wizard, upload, submit, or share. Metadata-only same-origin reads inside the authenticated browser are allowed.

Downloading assets is NOT banned. When Albert explicitly asks for a named style guide or asset set to be pulled down to his server, downloading (including add-to-collection or add-to-cart steps the portal requires to produce a download) is permitted. Do not download during a routine metadata scrape.

## Licensed scope

Read `nbcu/LICENSED_SCOPE.md` in the private repository before every capture. Scrape only resolved authorized titles.

- `Franchise` means every NBCU child title and related property under that franchise.
- How to Train Your Dragon means every related animated and live-action property.
- Preserve restrictions exactly. Do not widen a restricted title.
- Resolve each business title to NBCU's exact labels and paths. Record aliases and unresolved titles. Never use free-text file-name matches as entitlement proof.
- Do not maintain a hard-coded Property denylist. Per the 2026-08-10 owner ruling, metadata the signed-in account makes available is licensed unless the current task supplies a narrower work, character, channel, territory, or use restriction. Preserve those explicit restrictions exactly.

## Product Submissions

The page includes the full creation wizard in the DOM even while the Start step is shown. Read the existing `select#property` options without filling any field or advancing the wizard.

- Each option exposes an exact uppercase label and a numeric property source ID.
- The 2026-08-09 account view exposed more than 100 options, including film entries and `FRANCHISE ASSET` entries.
- Capture every option, then reconcile it against the private allowlist.
- Keep franchise-asset rows separate from films. Do not flatten them into one property.
- Do not read or store contact, company, phone, address, contract, reviewer, or other submission data that happens to be present in the DOM.
- The read-only `/conf/caf/services/workfront/pd/get-choices` response contains global Workfront choice lists. On 2026-08-09 it exposed 3,174 global `property` rows but the account-filtered page exposed only 129 options. Use the account-filtered picker for entitlement. Do not confuse the global list with licensed scope.
- `property_ip_franchise` is a flat 42-label choice list, not a relationship table. It does not prove which property belongs to which IP Family.
- No Character choice was present in the submission picker or `get-choices` response. Capture Characters from asset metadata.

## Asset search

NBCU uses Adobe Experience Manager Asset Share Commons. The search facets include Studio, Parks IP, IP Family, Property, Asset Category, Asset Type, File Type, Character, Talent, Season Type, Event Type, Region, Year, and Restriction.

Search results are server-rendered in batches of 100. The partial endpoint observed through the normal page is:

```text
/content/asset-share-commons/en/search.results.html
```

Use the normal query fields `paths`, `p.offset`, and `p.limit`. Run reads only inside the authenticated browser session. Do not copy credentials into a terminal. A successful batch contains exact asset paths in `data-asset-share-asset`; stop paging when a batch contains zero new asset paths.

For an exact Property rather than a directory scope, resolve the current Property facet row from the signed-in search page and use its normal query fields:

```text
3_group.propertyvalues.property=./jcr:content/metadata/caf:property
3_group.propertyvalues.operation=equals
3_group.propertyvalues.<current-slot>_values=caf-tags:property/<source-key>
```

The numeric slot is page-order state and can change. Resolve it from the current DOM by exact label and tag value every run; never hard-code a previously observed slot. Save these searches in the same `raw/index-parts/<scope>-000000.json` shape as path scopes, including a terminal zero-result page instead of omitting a zero-asset Property.

For every authorized NBCU path:

1. Fetch offset 0 with limit 100 and record the displayed total text.
2. Page by 100, checkpointing after every batch.
3. Require unique exact asset paths and stable page fingerprints.
4. Stop on a repeated page, duplicate-only page, unexpected scope path, HTTP error, or changed total.
5. Union overlapping franchise and film searches by exact asset path. Preserve every source scope that returned the asset.

The default blank search can retain prior state and is not a completeness source. Always use an explicit authorized `paths` scope.

When adding a narrow scope to an existing capture, union by exact `detail_href`. Reuse an already-valid detail record and add the new scope evidence rather than fetching the same detail page again. Fetch only hrefs missing valid metadata.

The result counter displays `100 out of 100+ files` rather than an exact total. Continue paging to a short or empty page. The 2026-08-09 entitled directory produced 108,133 unique asset detail paths across 43 authorized scopes; large examples included Jurassic, Woody Woodpecker, Gabby's movie, Trolls, Minions/Despicable Me, and Fast & Furious. Use durable 2,000-row chunks with four concurrent 100-row reads. A single long sequential franchise request exceeded the browser control limit.

## Asset detail metadata

Build the detail URL from the exact asset path:

```text
/content/asset-share-commons/en/details.html<asset-path>
/content/asset-share-commons/en/details/document.html<asset-path>
```

Use the document variant when the result link does. During a metadata scrape, parse the returned HTML without downloading the asset or rendition.

Capture:

- exact asset path and file name
- media type, displayed size, and displayed modified date
- Studio, IP Family, Property, Character, Restriction, and every other metadata heading exposed
- every breadcrumb label and path
- style-guide or guide folder label when the portal exposes it
- the exact search scopes that returned the asset

Do not infer a Character, Property, or style guide from a file-name substring. A folder name is path provenance, not automatically a style-guide identity. Keep `style_guide_source_id` null unless NBCU exposes a real ID.

Direct AEM JSON probes for `.json`, `.1.json`, and `.infinity.json` returned 404, while `jcr:content` metadata JSON returned 403 on 2026-08-09. Use the supported HTML views rather than trying to bypass those controls.

After a long index run, asset-detail requests redirected to the `CAF Login Options` page even while returning HTTP 200. Treat page title `CAF Login Options`, missing metadata headings, or an 11 KB login document as authentication failure. Stop and ask the user to sign in again. Do not count HTTP 200 alone as success.

Valid asset detail pages do not all use the title `Details`. The 2026-08-09 full capture also observed titles such as `Audio` and `3D Asset`. Accept a response when it is HTTP 200, has real `.caf-metadata-parent` fields, and is not a login or error page. Requiring the literal title `Details` creates false failures.

Keep detail concurrency conservative. A jump to roughly 250 simultaneous reads caused HTTP 429 responses. Thirty-two workers completed the full pass reliably. Checkpoint every few thousand rows and retry only HTTP/network failures after a cool-down.

When normal Chrome detail navigation is too slow because it renders previews, keep one authenticated NBCU detail tab and use its permitted CDP `Runtime.evaluate` command to run a same-origin `fetch` batch inside the page. Parse each returned HTML document with `DOMParser` in that page context and return only the metadata record. Use one `Promise.all` containing at most 32 URLs per command, then append every valid record before starting the next batch. Do not inspect cookies or request headers. Playwright's read-only evaluate scope does not expose `fetch`, and multiple concurrent CDP commands on one tab serialize; one page-native `Promise.all` is the fast, reliable form.

Browser resets do not necessarily close controlled in-app-browser tabs. Before restarting a stalled detail pass, inspect `browser.tabs.list()` and finalize stale capture tabs. A 2026-08-10 recovery found 129 leftover tabs; they made normal detail navigation appear hung. Keep the user's signed-in handoff tab, close only agent-owned search/detail tabs, then resume from durable href checkpoints.

## Relationships

Treat relationships as many-to-many and preserve their evidence:

- IP Family to Property from explicit facets, paths, or submission hierarchy
- Property to Character only when Product Submissions or asset metadata explicitly exposes the pair
- asset to Property, Character, and IP Family from asset metadata
- asset to style guide from explicit metadata or a clearly labelled guide folder, with evidence type recorded
- style guide to Property from the guide asset's explicit Property metadata

The Character facet is a global list. On 2026-08-09 it exposed 311 stable tag IDs shaped like `caf-tags:character/<namespace>/<character>`. Search result facet counts did not provide Character counts scoped to the selected `paths`. Do not treat the whole global list as licensed. A character-to-franchise or character-to-property link is supported only when the tag namespace itself is an authorized NBCU family, such as `shrek-franchise`, `trolls-2016`, `minions`, `dragons`, `how-to-train-your-dragon`, or `gabby-s-dollhouse-2021`. Record the tag ID as evidence. Do not infer an asset-to-character link when asset detail metadata lacks `CHARACTER`.

Search pages can retain broader state and return unrelated assets even when a `paths` parameter is supplied. The 2026-08-09 capture found and excluded 107 such records by checking each detail page's explicit Property metadata against the private rights list. Never trust the search scope alone as final entitlement proof.

Never convert a search filter into a direct relationship. Never infer a missing link from proximity, naming, or a shared asset unless the output contract explicitly records it as observed asset co-tagging.

## Output and validation

Store all rights lists, captured rows, examples, and counts only under `nbcu/` in the private `u2giants/licensor-source-data` repository. Work on a dedicated branch and open a pull request. Keep confidential values out of commit messages and PR text.

Write UTF-8 CSV with exact source values. Use source IDs as text. Preserve punctuation, capitalization, whitespace, file extensions, and full paths. Record capture time, source URL, query scope, page offset, and failures.

Never silently discard a detail record. Maintain one `dropped.csv` with `href,stage,reason`, append at every filter or invalid-record exit, and make cleanup/build exit non-zero whenever it contains a data row. Delete stale ratcheting summaries before verification; a previous exclusion counter must not mask whether a current run recovered all indexed hrefs.

For a recovery of known missing details, use `asset-index.csv` as the authoritative href list and preserve the exact detail form already stored there (`details.html`, `details/image.html`, `details/video.html`, or `details/document.html`). Preserve percent encoding such as `%20`; do not decode and rebuild URLs.

## Shared-database landing contract

Treat `plm.nbcu_property_character` as a link table, not an entity table. A loader writes:

- `property_key` and `character_key`
- `evidence_type` and `evidence_value`
- the capture and source-provenance columns required by the current schema

Do not write `property_label` or `character_label` on the link row. Those columns duplicate
`plm.nbcu_property.property_label` and `plm.nbcu_character.character_label`. Migration
`20260814050000_nbcu_link_labels_deprecated.sql` made both link-label columns nullable on
2026-08-14 so loaders can stop writing them; they remain temporarily only for compatibility
and will be dropped after every writer confirms the new contract. Read labels by joining the
two entity tables. Never use a display label as identity.

When reviewing or changing an NBCU loader, fail verification if its insert, update, merge, or
upsert path still names either deprecated link-label column. Do not request their database
removal until the live loader has stopped writing both columns and its next capture has been
verified.

Do not load a database, and do not change one. Database design changes and promotion are separate `shared-db` work: open a GitHub issue — `gh issue create --repo u2giants/shared-db --label db-work --title "<the outcome you need>" --body-file <file>` — and stop.

**Reading the shared database is allowed and needs no issue.** You may inspect the live shared Supabase structure in full (schemas, tables, columns, keys and relationships, indexes, constraints, views, functions/RPCs, triggers, RLS policies, migration history, generated types, metadata, safe sample data) and compare it against the NBCU source shape to report gaps. That is a review, not a load. The confidentiality rules above are unchanged while you do it: licensed NBCU rows, rights lists and examples stay under `nbcu/` in the private `u2giants/licensor-source-data` repo and never appear in a public repo, a GitHub issue, logs, prompts sent to outside services, commit messages or PR text — describe the shape, never paste the data.

## Learning loop

After every real capture, update this skill with durable endpoints, field names, paging behavior, relationship evidence, failures, and recovery steps. Never add rights lists, licensed rows, account data, credentials, or asset content to the skill.

## Downloading a style guide to Albert's server

Owner-requested downloads are allowed (ruling 2026-08-19). Do not download during a routine
metadata scrape.

### 1. Resolve the guide to an exact DAM folder

Do not trust a full-text search: `?fulltext=Dream Touch` on 2026-08-19 returned 11 files
mixing Shrek, Illumination and Kung Fu Panda assets. Use full text only to discover the
folder, then re-run the search scoped to that path and work from the scoped list:

```text
/content/asset-share-commons/en/search.html?paths=<dam-folder>
```

Guides live under `/content/dam/caf/en/<studio>/<property>/franchise/design-guides/<type>/<guide>_<season>/`
with `_reference-pdf/`, `character-art/` and `composed-graphics/` subfolders. The scoped search
returns the authoritative file list; confirm the displayed `N out of N files` count matches it.

### 2. Queue each asset with the portal

Direct DAM URLs work for PDFs but return HTTP 403 for high-res source art (TIF). Art must go
through the portal's asynchronous packaging queue, one detail page at a time:

1. Open the asset detail page and click `Download`. The header counter increments and the portal
   answers `DOWNLOAD REQUESTED. REVIEW THE DOWNLOADS PAGE FOR STATUS.`
2. Poll `/content/asset-share-commons/en/downloads.html` until the row reads `Successful`.
   A ~600 MB TIF took roughly 2-4 minutes on 2026-08-19.
3. Click that row's `Download` to stream the file to the browser.

The bulk `Select all` + `Download` on the search page is unreliable: a 5-asset request on
2026-08-19 packaged only the PDF. Queue assets individually.

### 3. Know the failure that looks like a server problem

**A native Chrome "Save as" dialog silently breaks everything.** It is modal, so no further
download starts, and the portal's `Download` and `Add to Cart` buttons appear to do nothing:
no network request fires, no error is shown, and the symptoms mimic NBCU throttling. If clicks
stop registering, check for an open save dialog first. Ask the user to cancel it and to turn off
`chrome://settings/downloads` -> "Ask where to save each file before downloading" for the run.

### 4. File the results

With the save prompt off, files land in the Downloads folder as `<asset>.original.tif`, and the
browser extension may write a duplicate `(1)` copy. Strip `.original`, keep the portal's exact
file name, and delete the duplicate.

Verify every file by magic bytes before filing it: `49 49 2a 00` for TIFF, `%PDF` for PDF. A login
or error page can otherwise be filed as if it were art.

Destination convention on the style-guide NAS (`\\<removed-protected-address>\styleguides`):

```text
NBC UNIVERSAL/<Property>/<Year>/<Guide type>/<Guide name>/
```

Files sit flat in the guide folder; do not mirror the portal's `character-art/` and
`composed-graphics/` subfolders. Sibling guides are usually named `<DD MMM> <Guide name>`;
follow whatever name the user gives.
