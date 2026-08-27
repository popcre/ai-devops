---
name: peanuts-scrape
description: Capture, refresh, validate, or interpret Peanuts and Snoopy source data from the Tenovos Asset Library. Use for Peanuts art programs, style guides, characters, initiatives, asset metadata, Tenovos fields, AppSync IDs, or asserted relationships.
disable-model-invocation: true
---

# Peanuts Asset Library (Tenovos DAM) scrape

Portal: `https://peanuts.enterprise.app.tenovos.io`. Vendor platform is
**Tenovos** (v3.5.0), so most of this transfers to any other Tenovos DAM.
Licensor is Peanuts Worldwide (WildBrain-affiliated).

Extract lives in `u2giants/licensor-source-data` under `peanuts/`.


## Refreshing this capture (incremental runs)

Style guides change after a capture: guides get added, art is replaced in place under the
same file name, and assets are withdrawn. Any refresh, re-scrape, delta or "what's new
since last time" request on Peanuts runs under the shared
**`licensor-incremental-capture`** skill. Load it - it owns the bookmark format, the diff,
the safety gates and the withdrawn-asset ruling. This skill still owns the endpoints,
entitlement rules and field names below.

Two things specific to Peanuts:

- **Change signal:** the Tenovos record's own modified/updated field where present, else file size (medium)
- **Re-index in full** from the AppSync GraphQL listings on every run. Indexing is metadata-only and
  cheap; only the detail fetches are skipped for rows whose signal has not moved.

Never treat a run timestamp alone as the bookmark, and never let a short or failed index be
read as the licensor withdrawing assets. The gates in the shared skill exist because that
failure silently destroys data.

## Credentials

1Password (`vibe_coding`): **"peanuts snoopy licensor style guide website for scrape"**.
User `larevalo@edgeho.me`.

Two traps in that entry's history:
- It once carried the **Sesame Workshop** NetX URL by mistake. The correct
  Peanuts URL is the Tenovos one above. A separate item, "sesame street
  licensor style guide website for scrape", owns the NetX portal.
- On the login screen click **Sign In**, then **Show more options**. Do **not**
  use "Connect with WildBrain SSO" - that path does not work for this account.

## Run the scraper, do not hand-crawl

```bash
export PEANUTS_ID_TOKEN='<see below>'
node peanuts/scraper/peanuts-scrape.mjs --out peanuts/raw --derived peanuts/derived
```

| Flag | What it does |
|---|---|
| (none) | Vocabularies, field definitions, all assets, derived maps |
| `--vocab-only` | Just the master lists. Seconds, not minutes. |
| `--relationships` | Also crawl the explicit parent/child asset graph (slow, one call per asset) |

### Getting the token

The API is AWS AppSync behind Auth0. The scraper needs the **id_token**, not the
access_token - the access token passes AppSync's auth layer but the resolver then
answers `{"error":"User does not exist"}`, which looks like a permissions problem
and is not.

1. Log in to the portal.
2. DevTools > Application > Local Storage > the portal origin.
3. Open the key ending `::@@user@@` and copy `id_token`.
4. `export PEANUTS_ID_TOKEN='<paste>'`

Valid about 10 hours. Never commit it. Both headers must be sent:
`Authorization: <id_token>` **and** `x-tenovos-auth: <id_token>`.

## The API

- GraphQL: `https://xjgdrnbcb5e3hmxkpzfvreb534.appsync-api.us-east-1.amazonaws.com/graphql`
- Customer id: `1565158288582`
- Renditions: `https://enterprise.content.tenovos.io/1565158288582/<objectId>/<renditionId>-<rendition>.<ext>`

**Tenovos names every operation `query`, including its writes** (`softDelete`,
`purgeAssets`, `updateMasterObject`, `createRightsObject`, ...). The `query`
keyword is no safety guarantee. The scraper whitelists six read operations in
`READ_OPS` and refuses anything else - do not weaken that guard.

Useful reads: `getMetadataDefinitions`, `getControlledVocabularyByIds`,
`searchAssetsCSI`, `getAssetsByObjectIdCSI`, `getRelationshipByObjectId`,
`getAllCollections`.

## The data model, and its one nasty trap

The internal field name and the portal label disagree on the two most important
fields. Get this wrong and every downstream mapping is wrong:

| Internal field | Portal label | Cardinality |
|---|---|---|
| `property` | **Art Program** | multi |
| `program` | **Initiative** | single |
| `style_guide` | Style Guide | single |
| `character_names` | Character Name(s) | multi |
| `asset_type` | Asset Type | single |
| `holiday` | Holiday | multi |

"Property" in this portal does **not** mean what "property" means in our master
data. A Peanuts Art Program (`Classic`, `Vintage`, `TV Special Art`, `NASA`,
`Good Ol' Charlie Brown`) is an art style/era bucket, not a franchise. The whole
portal is one franchise: Peanuts.

## What the portal actually holds (2026-08-19)

| Thing | Count |
|---|---|
| Assets | 22,461 |
| Style Guides (vocabulary) | 528 |
| Style Guides actually used on assets | 255 |
| Characters (vocabulary) | 77 |
| Characters actually used | 64 |
| Art Programs (vocabulary) | 19 |
| Art Programs actually used | 5 |
| Initiatives | 24 |
| Asset Types | 28 |
| Holidays | 13 |

Two facts that shape any schema:
- **17,535 of 22,403 assets carry no style guide at all.** They are mostly comic
  strips (10,977 Comic Strip assets: 8,593 Daily, 2,384 Sunday). Style guide must
  be nullable on the asset.
- Vocabulary values exist with zero assets. Load the vocabularies as the master
  lists, not the distinct values found on assets, or you will silently drop 273
  style guides and 13 characters.

`Charles M. Schulz` is credited on 18,918 assets; other creators include Peanuts
Worldwide, Creative Associates, United Media, Bill Melendez.

## Licensor-asserted versus inferred - the important distinction

**Asserted** (the portal states it, load it as fact):
- Every controlled vocabulary (the master lists).
- Every value on an asset: this asset has this style guide, these characters,
  this art program, this asset type, this holiday.
- The **asset-to-asset relationship graph** via `getRelationshipByObjectId`.
  `primaryId` is the parent. The live graph has **15,770 edges over 5,220
  parents** in three link types: `child` (11,502), `derivative` (4,267) and
  `placed-graphic` (1). Store `link_type` verbatim; do not assume `child`.

  **Do not crawl only the style-guide documents.** It is a tempting 1%-cost
  shortcut (196 calls instead of 22,463) and it is wrong: a 400-asset
  verification sample found 366 of 435 edges unreachable that way, across 256
  parents outside the style-guide set. `scraper/peanuts-relationships.mjs --all`
  does the full crawl in about 8 minutes at concurrency 4 and writes its own
  `_coverage` block; the loader refuses any relationship file whose coverage is
  not `complete`.

**Inferred** (we computed it, label it as ours, never present as licensor-stated):
- Style guide to art program.
- Style guide to character.
- Art program to character.
- Anything else in `derived/relationships-inferred.json`.

The portal has **no** explicit style-guide entity, no character-to-style-guide
roster, and no property/franchise hierarchy. Everything above the asset is a
flat controlled vocabulary. The only real hierarchy is the asset parent/child graph.

A style guide can span more than one art program, so model it many-to-many.
Confirmed cases: `70th Anniversary: Peanuts Logo`, `Great Pumpkin`,
`Snoopy World Games`, `Beagle Scouts: Packaging`, `Beagle Scouts: Logos`,
`Peanuts Core Everyday Packaging`, `Core Christmas Packaging`.

## Three things the live capture corrected

1. **The portal's asset count is short by two.** It reports 22,461; a partition
   crawl reaches 22,463. The extras are metadata-only records (filename
   "Metadata Asset", their own metadata template) that carry no file and are not
   counted by the default search, but are real, available and current. The loader
   reconciles against what it can prove exists and keeps the portal's own number
   as `portal_default_search_total`.

2. **The graph references superseded asset versions.** A capture holds current
   versions only, so ~2,782 edges point at assets outside it (`currentVersion`
   is `N`), and the portal also publishes 53 self-referencing edges. Neither is a
   scrape bug and neither is fixable by re-scraping. The loader drops them,
   counts them, and writes them onto the capture as
   `raw_summary.excluded_by_design`. If you ever want those endpoints, the
   capture would have to include versions (`includeVersions: true`), which is a
   different and much larger capture.

3. **Keywords are a controlled vocabulary of 31**, not an open axis. 30 are used
   and nothing on an asset falls outside the list. The schema has no keyword
   vocabulary table, which costs exactly one unused value ("Spacecraft"). Known
   gap, deliberately not fixed -- a governed schema change is not worth one
   descriptive tag. Note the separate free-text `keywords_unvalidated` field,
   present on 17,831 assets, which stays in `raw`.

## Search gotchas

- **Deep paging dies at 10,000.** `from + size > 10000` returns zero hits, and
  `page` beyond that does too. The scraper works around it by crawling
  `createdEpoch` ASC then DESC (2 x 10k, no overlap) and then partitioning by
  vocabulary terms. Expect roughly 22,400 of 22,461; a handful stay unreachable.
- **The `filters` argument is silently ignored** if the label is wrong. It takes
  Lucene-ish strings built from the *portal label*, e.g. `(Art Program:"Classic")`,
  not the internal field name. A wrong label does not error - it returns the
  unfiltered total, which is how you get a scrape that looks complete and is not.
  Always sanity-check a filtered count against an unfiltered one.
- `searchTerm: []` with no operation returns everything; `searchTerm: ["x"]`
  needs `operation: "AND"`.
- Facet aggregations need facet names from a config call the scraper does not
  make. Do not rely on facets; read the vocabularies instead.

## Files produced

```
peanuts/raw/       metadata-definitions.json, controlled-vocabularies.json,
                   style-guides.json, assets.json, asset-relationships.json
peanuts/derived/   aggregates.json, character-counts.json,
                   art-program-x-style-guide.json, art-program-x-character.json,
                   relationships-inferred.json, style-guide-assets.json
```

`raw/` is verbatim licensor output. `derived/` is ours and every file says so.

## Database

The landing schema is **built and live in production**: 19 `plm.peanuts_*` tables
plus `plm.begin_peanuts_capture` / `plm.finalize_peanuts_capture`, authored and
applied through `u2giants/shared-db` issue #1217 on 2026-08-19. Do not propose it
again, and never write Peanuts *structure* from the extract repo — that is
shared-db's job (see the `shared-db-change` skill). The *rows* belong to this
application, so loading them needs no issue and no dispatch.

```bash
export PGPASSWORD="$(op read 'op://vibe_coding/Supabase DB Password - shared POP database/password')"
node peanuts/loader/peanuts-load.mjs --raw peanuts/raw --dry-run
node peanuts/loader/peanuts-load.mjs --raw peanuts/raw
```

| Command | What it does |
|---|---|
| `npm --prefix peanuts test` | 40 unit tests over the row builder |
| `node peanuts/loader/rehearse.mjs` | Whole DB path against the real schema in a transaction that always rolls back |
| `node peanuts/loader/rehearse.mjs --negative` | Proves the count gate rejects a misreported capture |

Things worth knowing before you touch the loader:

- It runs as `service_role`, which has `SELECT` + `INSERT` and **no** update or
  delete. The connection authenticates as the owner then `SET ROLE`s down. That
  line is the reason a loader bug cannot destroy data. Leave it.
- `finalize_peanuts_capture` compares three numbers per entity — declared,
  reported, and actually present. Any disagreement records the capture as
  `rejected` rather than complete. Rejected captures are immutable evidence and do
  not replace a previous good one.
- `plm.peanuts_asset` carries composite foreign keys to the style-guide,
  asset-type, initiative and licensing-status vocabularies. A value stamped on an
  asset but missing from its vocabulary would abort the load partway, so the
  transform catches it first and names it.
- The extract files must be in the shape the **scraper** emits
  (`definitionId` / `controlledVocabularyId` / `multiSelect`, vocabularies keyed by
  the portal's vocabulary display name). Vocabularies join to fields by
  `vocabularyId`, never by display name. A hand-edited file in a different shape
  produces zero vocabulary rows; the loader refuses rather than loading empty.

Licensed Peanuts rows stay in the approved private repo, and no licensed value
belongs in a shared-db issue, migration, test or commit message.
