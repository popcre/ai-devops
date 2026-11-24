# Sega capture output contract

## Files

- `properties-canonical.csv`: submission-side IP choices for the selected active contract; this is the canonical Property vocabulary.
- `submissions-page.json` and `product-start.png`: compact evidence that the form was opened read-only, the contract was selected, and no submission was created.
- `manifest.json`: run identity, timestamps, options, counts, completeness, warnings.
- `properties.csv`: IP registry records.
- `catalogs.csv`: catalog nodes with source IDs, parent IDs, exact labels, and paths.
- `style-guides.csv`: derived guide candidates tied to catalog IDs with evidence.
- `characters-inferred.csv`: inferred character candidates with evidence and confidence.
- `assets.csv`: source asset metadata without licensed file contents.
- `links-catalog-parent.csv`: direct hierarchy edges.
- `links-asset-catalog.csv`: direct asset-to-catalog edges.
- `links-asset-tag.csv`: direct asset-to-tag edges.
- `links-asset-property.csv`: direct asset-to-IP edges.
- `checkpoints/`: resumable paging and association progress.

The submission-only run uses `--inspect-submissions` and has its own audited capture table.
Its canonical Property file also constrains the asset-side inference transform; it is never
loaded as though it were the 110-record registry. Emit a child/link file only when the
source selector actually returns children.

## Stable keys

- IP: `(source_system, property_source_id)`.
- Catalog: `(source_system, catalog_id)`.
- Asset: `(source_system, asset_source_id)`.
- Tag: portal tag ID when present; otherwise a deterministic source-scoped normalized-label key.
- Guide candidate: catalog ID.
- Character candidate: deterministic key from normalized label and inference method. This is not a portal Character ID.

Within a capture, each direct source ID is unique. Relationship rows are unique by all endpoints. Preserve exact source text separately from normalized comparison values.

## Provenance

Every row is traceable to a capture. Derived rows also require evidence type, evidence value or path, inference rule version, confidence, and relationship truth level.

Never put inferred character relationships in the same table or truth flag as direct portal associations.

## Completeness

A capture is complete only when IP pagination ends normally, every catalog element is recorded once, asset paging reaches fewer than 100 records, explicit asset-to-IP checks finish, every endpoint resolves, validation passes, and the manifest says `complete`.

A run stopped by `--max-assets` is `limited`, not complete.

## Database landing

Use capture-scoped `plm.sega_*` tables. Foreign keys include `capture_id` so snapshots cannot cross-link. Use composite uniqueness for source IDs and relationship endpoints. Store raw payloads as evidence, not as the only queryable form. Publish only the latest validated complete capture through adapter views.

## Capture file to table map (implemented 2026-08-19)

`sega/loader/transform.mjs` is the single place this mapping lives; `sega/loader/sega-load.mjs`
only moves the rows.

| Capture file | Table |
|---|---|
| `properties.csv` | `plm.sega_property` + `plm.sega_property_licensor` (one comma-separated cell splits into ordered rows) |
| `catalogs.csv` + `links-catalog-parent.csv` | `plm.sega_catalog` |
| `style-guides.csv` | `plm.sega_style_guide_candidate` |
| `characters-inferred.csv` | `plm.sega_character_candidate` + `plm.sega_character_evidence` |
| `checkpoints/assets.json` | `plm.sega_asset`, `plm.sega_tag`, `plm.sega_asset_catalog`, `plm.sega_asset_tag` |
| `links-asset-property.csv` | `plm.sega_asset_property` |
| `properties-canonical.csv` + catalog evidence | `plm.sega_asset_property_inferred`, `plm.sega_style_guide_property_inferred`, `plm.sega_character_property_inferred` |
| `properties-canonical.csv` + `submissions-page.json` | `plm.sega_submission_capture`, `plm.sega_submission_property` |

Assets are read from the CHECKPOINT, not from `assets.csv`. The checkpoint holds the
portal objects including their `Catalogs` and `Tags` arrays; the flattened CSV drops both,
so loading from the CSV would silently lose every asset-to-folder and asset-to-tag link.

The candidate/evidence tables carry `confidence = 0.5`. Canonical six-Property relationship
rows carry the reviewed rule's confidence and always `relationship_truth = inferred`. That
number is deliberate: a folder name under a Character branch is evidence for a human to
rule on, not a Sega assertion. Do not raise it without a portal change that justifies it.

## Completeness, decided before the write

The loader refuses to open a capture row at all when the crawl was `limited`, when asset
paging never hit a terminal short page, when the IP registry produced nothing, or when any
captured asset was never asked for its IP associations. Deciding this up front means a bad
crawl leaves no rejected record behind. The database gate re-checks all of it anyway.
