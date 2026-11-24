# Raw and production data contract

## Raw hierarchy and entities

Preserve these source concepts without premature canonicalization:

- capture: immutable account-visible snapshot and source URL/time;
- category;
- style guide;
- guide node: stable capture-local node with parent, depth, label, exact full path, and leaf status;
- asset group: stable API `originalFileId`;
- file observation: every exact filename observed in a leaf/page/order position;
- character;
- controlled term/facet option;
- gap/checkpoint and raw evidence hash.

Model many-to-many relationships separately:

- node <-> file observation;
- asset group <-> characters;
- asset group or observation <-> actor likeness;
- asset group or observation <-> character action, artwork type, image coloration, descriptive keyword, and iteration;
- optional contributor fields such as colorist, inker, penciler, and painter, preserved as source metadata until their identity semantics are proven.

Do not collapse duplicate filenames, multiple filenames under one source UUID, or the same asset observed in several guide nodes. Do not infer a character or property from a filename.

## Observation provenance

Each file observation must retain capture key, exact guide node, file observation key, API `originalFileId`, `styleGuideFileId`, `styleGuideAssetId`, browser-observed file ID, exact filename, extension, size, page, node order, display order, raw observation, cryptographic hash, source/repair method, and capture timestamps when those fields are available.

## Deployed production contract

The structural contract from shared-db issue #1640 is production-complete. Migration `20260827101135` merged in PR #1643 at commit `4f0b857fbbd30647ccc88e4ed602ff2db9620060`; production apply run `33065761735` succeeded.

- `plm.marvel_asgard_asset` remains the stable source-UUID group.
- `plm.marvel_asgard_node_asset_observation` stores each file observation and keys it by `(capture_key, guide_node_id, file_observation_key)`.
- One asset UUID can retain several filenames.
- Exact replay is idempotent.
- Reuse of an observation key with different page, asset, filename, metadata, order, raw hash, or raw evidence must fail closed.
- Both tables have row-level security enabled.

These identifiers are historical proof, not a substitute for re-reading the live catalog and function signatures before a new production load.

## Guarded load surface

Use only `plm.begin_marvel_asgard_capture`, `plm.load_marvel_asgard_chunk`, and `plm.finalize_marvel_asgard_capture`. The deployed chunk signature is `plm.load_marvel_asgard_chunk(uuid,text,text,jsonb)`. Execute permission was restricted to `service_role`. Never bypass these functions with direct table writes.

The private loader chunks categories, style guides, guide nodes, assets, characters, terms, checkpoints, gaps, node assets/file observations, asset-character links, asset-term links, and asset-likeness links. Preserve raw evidence in the landing model even when normalized relationships are also emitted.
