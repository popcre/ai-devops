---
name: disney-source-data-scrape
description: Safely capture, resume, validate, reconcile, or load authorized Disney source data from OPA (opa.disney.com) and DCP Vault (dcpvault.disney.com), including OPA Properties and Characters, DCP portal tiles, style guides, assets, paths, source IDs, relationships, checkpoint recovery, and guarded Supabase landing. Use for Disney scrape, refresh, database-load, output-shape, identifier, completeness, or relationship questions involving either portal.
---

# Disney source-data scrape

Capture Disney source truth without changing either portal or downloading licensed media.

## Route the request

- **OPA** is Disney Online Product Approval. Use it for the account-visible Property-to-Character picker and Disney's source IDs.
- **DCP Vault** is Disney Consumer Products Vault. Use it for portal browsing tiles, style-guide folders, assets, DAM paths, file names, and later detail metadata.
- Use both only when the request needs both shapes. Keep their identities and capture status separate.

## Mandatory private sources

The public skill contains procedure only. Read the current private contract before acting:

- Repository: `C:\repos\licensor-source-data-disney`
- OPA: `disney-opa/README.md` and `disney-opa/opa-characters.csv`
- DCP: `disney-dcpvault/README.md`, `disney-dcpvault/PLAN.md`, and open files under `disney-dcpvault/HANDOFF.d/`, newest first
- DCP loader: `disney-dcpvault/scripts/load-collected-to-supabase.mjs`
- DCP loader tests: `disney-dcpvault/scripts/load-collected-to-supabase.test.mjs`

Pull the private repository safely before a new capture or load. Preserve other sessions' local changes. Never copy licensed rows, rights lists, file paths, names, or portal responses into this public `ai-devops` repository.

## Hard safety rules

1. Use the user's authenticated Chrome profile. The user performs login and MFA. Never ask for, type, inspect, or record passwords, MFA codes, cookies, browser storage, request headers, bearer tokens, or account details.
2. Treat both portals as read-only. Never save, submit, approve, upload, share, add to a collection or cart, accept download terms, or change a portal record.
3. Capture metadata only. Never download artwork, style guides, PDFs, previews, renditions, videos, or original files.
4. Store licensed output only in the private `u2giants/licensor-source-data` repository and the shared private Supabase database. Never place licensed rows in this public repo, `shared-db`, an issue, logs, commit messages, pull-request text, paste services, or outside-AI prompts.
5. Describe every capture as the signed-in account's point-in-time entitled view. Never claim it is Disney's full catalogue.
6. Preserve source values exactly. Keep IDs as text unless the guarded database function requires a number. Never clean, merge, or infer identities during capture.
7. Checkpoint every bounded page or batch. Stop loudly on authentication loss, repeated pages, changed totals, unexpected scope, malformed output, or an unresolved gap.

## OPA workflow

OPA loads the complete Property-to-Character tree into the product-create page. Do not build a per-Property crawler.

### Capture

1. Ask the user to sign in to `https://opa.disney.com` and complete MFA in Chrome.
2. Open the Home-line-of-business product-create URL recorded in `disney-opa/README.md`. Do not fill any field or click Save or Submit.
3. Run `showAllProperties()` in the authenticated page, wait for the tree, then read the current jsTree model. The jsTree element ID changes on every page load; resolve it from `document.querySelector('.jstree').id`.
4. Extract exactly these fields:
   - `property`
   - `licensedPropertyID`
   - `optionSourceID`
   - `character`
   - `characterID`
   - `brandPropertyID`
5. Build UTF-8 CSV in the browser, then ask permission before triggering a browser download. Wait for Chrome's temporary file rename before declaring the download missing.
6. Validate the whole file. The natural row key is `(licensedPropertyID, characterID)`, not either display name. Reject duplicate ID pairs. Keep `optionSourceID` as observed source data; the guarded loader currently requires numeric value `1007`.
7. Record explicit capture date, source URL, line of business, row count, distinct Property IDs, distinct Character IDs, duplicate-pair count, and failures. Do not estimate.

### OPA facts and limits

- The verified 2026-08-06 Home snapshot contains 10,262 unique ID pairs. Use that only as a regression baseline, never as a required future count.
- Character identity is scoped by Property in the landing table. Never deduplicate on Character name.
- The capture proves the Home line of business only. Other lines of business remain unverified unless separately captured.
- OPA is a full re-capture, not a change feed. Absence alone does not authorize deletion.

## DCP Vault workflow

DCP Vault is a paged Adobe Experience Manager asset library. The current private extract is an aggregated path checkpoint, not a completed catalogue.

### Studio boundary

DCP Vault being one website does not make its content one database source. Keep
**Disney, Lucasfilm, Marvel, and 20th Century** in separate capture outputs,
separate table families, separate crawl histories, and separate guarded loaders.
A portal tile or discriminator inside shared tables is not enough separation.
Never send one studio's rows through another studio's loader. If a studio-specific
landing family is not live, checkpoint locally and stop before the database write.

Do not assume Avatar's destination from portal placement. Record it as an open
ownership decision until the private contract names its target.

### Plan before fetching

1. Ask the user to sign in to `https://dcpvault.disney.com` and complete MFA in Chrome.
2. Read the newest DCP handoff and current plan from the private repository. Use their exact planned tile and listing queue. Do not rebuild the plan from rows that happened to arrive.
3. Treat each portal tile as a browsing category, not a Property. One asset may appear under several tiles, and a tile may yield no matching Property.
4. For each planned tile, keep `Assets` and `Style Guides` as separate listing kinds. A retry or repair closes a gap in that section; it does not create a second logical section.

### Page and checkpoint

1. Use the normal same-origin results request observed through the authenticated page. Keep credentials inside the browser session.
2. Page in conservative bounded batches. Record tile key, listing kind, offset, requested limit, returned count, displayed total when present, and any gap.
3. A network error, HTTP 429/503, login page returned as HTTP 200, repeated page, or changed page fingerprint is not end-of-list. Retry with backoff or record an explicit unresolved gap and stop.
4. Save durable state after every accepted batch. A browser-only in-memory map is not a checkpoint.
5. Deduplicate the aggregated output on exact full DAM path. Preserve every tile that returned the asset and the observed listing-kind flags.
6. Keep full source paths verbatim. Derive no Property, Character, or stable file identity from a file name.

### Current phase-one output

Map the private `assets.csv` columns without changing their meaning:

- `dam_path` is the current asset identity.
- `file_name` and `file_ext` are exact source file metadata.
- `style_guide_natural_key`, `region`, and `year_segment` form guide context; the loader derives the full guide source path and validates the asset is beneath it.
- `style_guide_source_id` is optional and is not the guide identity.
- `folder_category` is a relative folder path, not a controlled category.
- `franchise_tiles` is a pipe-separated set of portal tile keys, despite its legacy column name.
- `listed_in_assets` and `listed_in_style_guides` preserve the listing evidence. Do not guess a missing flag.

The verified checkpoint loaded on 2026-08-13 contains 156,644 unique paths at planned job 23 of 34 with zero recorded gaps. It is partial. Use these numbers only to identify that exact checkpoint.

### Phase-two metadata

Capture detail metadata only when the portal exposes it safely. Preserve source fields such as UUID and `collectionDmcId` separately from the DAM path. Do not add uniqueness rules until a complete output proves them unique. As of 2026-08-13, no complete phase-two output exists, so phase-two uniqueness and stability remain `NOT KNOWN`.

## Completeness and re-capture rules

- OPA can be a full snapshot when the entire client-side tree is captured and reconciled.
- DCP can be complete only when every pre-registered tile/listing section is complete, every gap is resolved or explicitly waived, and input, distinct-path, chunk-ledger, and membership counts reconcile.
- A partial DCP checkpoint remains `planned` or `running`. Never call the finalizer merely because every collected row loaded.
- Presence is evidence. Absence is not proof of deletion and never removes a held row automatically.
- A future capture is a new crawl. Never overwrite or relabel earlier capture evidence.
- Source path is the current DCP asset identity. A rename or move cannot be proven as the same file without a stable source ID; report that limitation instead of merging paths.

## Supabase landing

Scrape-data rows belong to the application session. They do not require a shared-db issue, branch, migration, or handoff. Database **structure** changes still go through `u2giants/shared-db` first.

Never load Disney scrape rows into `core.*`. Use the dedicated source-landing tables:

- OPA rows: `plm.opa_property_character`
- DCP crawl history: `plm.dcp_crawl`, `plm.dcp_crawl_section`, and `plm.dcp_crawl_gap`
- DCP identities: `plm.dcp_asset`, `plm.dcp_style_guide`, and `plm.dcp_portal_tile`
- DCP evidence: `plm.dcp_asset_crawl` and `plm.dcp_asset_tile_observation`
- Load proof: `plm.dcp_chunk_ledger` and `plm.dcp_load_exception`
- Phase-two metadata, when collected: the existing `plm.dcp_*metadata*` landing tables and guarded metadata functions

The `plm.dcp_*` names above describe the existing Disney landing path. They are
not permission to load Lucasfilm, Marvel, or 20th Century rows there. Read the
current private plan and newest handoff for the live studio-specific table and
function names; never invent those names from this public skill.

Before every data write:

1. Prove the target is production project ref `<removed-protected-project-ref>`, project name `popdam`.
2. Read the relevant live function signatures. Do not bypass guarded begin/load/finalize functions with direct table writes.
3. Get the Supabase access token from 1Password vault `vibe_coding`, item `Supabase CLI Personal Access Token`, field `SUPABASE_ACCESS_TOKEN`. Never print or persist it.
4. Set `DISNEY_SOURCE_COMMIT` to the full 40-character commit SHA holding the private source output.
5. Run the private loader. Its Management API transport chunks are 1,000 rows even though the database function accepts more; larger requests previously failed with HTTP 413.
6. Reconcile exact input rows, distinct identities, memberships, ledger rows, relationship rows, and exceptions. Stop if any row is unaccounted for.
7. Finalize only a genuinely complete capture. Leave a partial DCP capture open.

The loader is repeat-safe for the same OPA snapshot and identical DCP chunks. A changed payload under an existing DCP chunk number must fail rather than overwrite evidence.

## Shape questions

When asked about IDs, uniqueness, relationships, path stability, deletions, or snapshot meaning:

- Inspect the complete actual output, not samples, docs, expected counts, or business rules.
- Answer OPA and DCP separately where they differ.
- Say `NOT KNOWN` when capture coverage cannot prove the answer.
- Never expose licensed row values. Report field names, yes/no results, counts, and structural facts only.

## What does not work

- OPA `<select>` or hidden-field scraping: the real hierarchy is in jsTree.
- OPA per-Property character requests: unnecessary because the full tree is already client-side.
- Hard-coded jsTree IDs: generated per page load.
- DCP treating HTTP errors as end-of-list: this previously created silent truncation.
- DCP deriving planned sections from arrived rows: makes an incomplete crawl look complete.
- Treating tiles as Properties or `folder_category` as a controlled category.
- Loading a DCP chunk of 20,000 rows through the Management API: database-valid but transport-invalid; it returned HTTP 413. Use 1,000.
- Sending scrape-data loads to the shared-db coordinator: obsolete. Data belongs to the licensor session; only structure goes through shared-db.

## Learning loop

After each real capture or load, update this skill with durable portal behavior, field names, source identity evidence, paging limits, failure modes, recovery steps, and database guards. Never add licensed rows, rights lists, credentials, account data, or downloadable media.
