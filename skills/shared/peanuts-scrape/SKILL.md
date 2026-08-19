---
name: peanuts-scrape
description: Capture, refresh, validate, or interpret Peanuts / Snoopy licensed source data from the Peanuts Asset Library (peanuts.enterprise.app.tenovos.io, a Tenovos DAM). Use when asked to scrape, re-scrape, inspect, reconcile, or load Peanuts art programs, style guides, characters, initiatives, or asset metadata; when a question depends on Tenovos field names, the Art Program / Style Guide / Character Name vocabularies, the AppSync GraphQL API, or asset IDs; or when deciding which Peanuts relationships are licensor-asserted versus inferred.
---

# Peanuts Asset Library (Tenovos DAM) scrape

Portal: `https://peanuts.enterprise.app.tenovos.io`. Vendor platform is
**Tenovos** (v3.5.0), so most of this transfers to any other Tenovos DAM.
Licensor is Peanuts Worldwide (WildBrain-affiliated).

Extract lives in `u2giants/licensor-source-data` under `peanuts/`.

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
- The **parent/child asset graph** via `getRelationshipByObjectId`. `linkType`
  is `child`; `primaryId` is the parent. In practice the parent is the style
  guide PDF (`asset_type = "Style Guide"`) and the children are the art files
  extracted from it. Verified example: `DecoDreams.pdf` (Style Guide) is parent
  of `DecoDreams_18rpt.eps` (Pattern), both tagged style guide "Deco Dreams".

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

Schema for the shared Supabase database is governed by `u2giants/shared-db`
(see the `shared-db-change` skill). Never write Peanuts structure from this repo.
Licensed Peanuts rows stay in the approved private repo.
