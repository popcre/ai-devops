---
name: sega-source-data-scrape
description: Safely inspect, capture, resume, validate, reconcile, or load authorized Sega DSI licensing metadata, including the canonical Product Approval IP picker, the secondary IP registry, catalog folders, guide and character candidates, assets, tags, source IDs, and explicit or inferred relationships. Use for Sega portal scrapes, new Product Approval vocabulary captures, Sega property or character reconciliation, and Sega capture loads in the private licensor-source-data repository.
---

# Sega Source Data Scrape

Use this skill for Sega's DSI licensing portal or Sega captures in the private `u2giants/licensor-source-data` repository.

## Required references

Read [references/portal-map.md](references/portal-map.md) before portal access. Read [references/output-contract.md](references/output-contract.md) before changing the scraper, validating a capture, or designing a database load.

## Access and safety

- Enter at `https://sega.dsidrm.com/signin`; DSI SSO redirects to id4 login.
- Read credentials only from 1Password vault `vibe_coding`, item `Sega licensor style guide website for scrape`.
- Pass credentials through `op run`. Never print, persist, or commit them.
- Treat the portal as read-only. Never change records, associations, rights, or settings.
- Capture metadata only unless Albert explicitly authorizes file downloads in the current conversation.
- Never download thumbnails, images, PDFs, archives, media, or original artwork during routine capture.
- Keep licensed rows and examples only in the approved private repository. Public database issues may contain schema, field names, counts, and validation rules, but no licensed values.

## Standard workflow

1. Work in the private repository on a branch.
2. Use `sega/scripts/scrape.mjs`; do not replace it with one-off browser copying.
3. Inject `SEGA_USERNAME` and `SEGA_PASSWORD` from 1Password.
4. Capture the IP registry, catalog hierarchy, assets in pages of 100, catalog links, tags, and explicit asset-to-IP links.
5. Resume from checkpoints after interruptions. Do not discard valid partial captures.
6. Classify guide folders from names and paths as derived candidates, not portal-declared entities.
7. Infer characters only from Character-labelled branches and filenames. Preserve evidence and label them `inferred`; never promote them to direct relationships.
8. Join the active Product Approval vocabulary to folder evidence with
   `sega/loader/canonical-relationships.mjs`. Keep the reviewed six-Property rule separate
   from the historical registry-wide experiment in `infer-property.mjs`.
9. Run tests, validate counts and relationship coverage, inspect the manifest, then commit and push the branch.
10. Load the committed capture with `sega/loader/sega-load.mjs`. Always run `--dry-run`
   first and read the row counts; the loader refuses a limited or non-terminal capture
   BEFORE opening a capture row, so a bad crawl never leaves a rejected record behind.
11. Load the committed submission evidence separately with
    `sega/loader/sega-load-submission.mjs`, after its own dry run.
12. Read back both `plm.sega_capture.status` and `plm.sega_submission_capture.status`.
    The finalize functions return void by contract,
    so the status column IS the return value; a `rejected` status carries its reasons in
    `error_summary` and does not replace a previous complete capture.

For the canonical submission vocabulary, run the separate read-only mode:

```powershell
$env:SEGA_USERNAME='op://vibe_coding/Sega licensor style guide website for scrape/username'
$env:SEGA_PASSWORD='op://vibe_coding/Sega licensor style guide website for scrape/password'
op run -- npm --prefix sega run scrape -- --inspect-submissions --output "C:/repos/licensor-source-data/sega/raw/submissions-<date>"
```

This opens New Submission -> Product Approval, selects the active Contract only far enough
to populate the required IP selector, checks each IP for child options, takes evidence, and
reloads the list to prove no submission was created. Never click Save. Its
`properties-canonical.csv` is the authoritative vocabulary for new Product Approvals. It is
an input to the inference transform, but it is loaded through the separate audited
submission-capture path rather than as a registry table.

```powershell
# capture (resumes from checkpoints if re-run against the same directory)
$env:SEGA_USERNAME='op://vibe_coding/Sega licensor style guide website for scrape/username'
$env:SEGA_PASSWORD='op://vibe_coding/Sega licensor style guide website for scrape/password'
op run -- npm --prefix sega run scrape -- --output "C:/repos/licensor-source-data/sega/raw/capture-<date>"

# validate, then load into plm.sega_*
$env:PGPASSWORD=$(op read 'op://vibe_coding/Supabase DB Password - shared POP database/password')
npm --prefix sega run load -- --capture raw/capture-<date> --dry-run
npm --prefix sega run load -- --capture raw/capture-<date>
npm --prefix sega run load:submission -- --source raw/submissions-<date> --dry-run
npm --prefix sega run load:submission -- --source raw/submissions-<date>
```

`npm --prefix sega run scrape` executes with `sega/` as the working directory, so a
relative `--output` lands under `sega/sega/`. Pass an ABSOLUTE output path.

## Relationship truth levels

1. **Canonical submission entity:** numeric IP IDs and exact labels offered by the active Contract's new Product Approval picker. This vocabulary wins over the registry for what POP can submit.
2. **Direct entity:** numeric portal IDs for registry IPs, catalog nodes, and assets.
3. **Direct relationship:** catalog parentage, asset-to-catalog, asset-to-tag, asset-to-IP, and IP-to-licensor labels exposed by the portal.
4. **Source containment:** a descendant folder or asset lies under a property-oriented branch. Useful evidence, but not automatically a direct IP relationship.
5. **Inference:** character or guide classification derived from folder names, paths, or filenames. Store evidence, method, and confidence.

Never use a folder label as identity. The same leaf label occurs under multiple paths; use numeric catalog ID and full hierarchy path.

## Validation gates

- For a submission-vocabulary capture, require the active Contract, a non-empty IP picker,
  exact source IDs and labels, `save_clicked: false`, and an unchanged visible submission
  list after reload. The 2026-08-21 baseline is **6 canonical submission IPs**, all matching
  IDs and labels in the **110-record secondary registry**, with **0 child/Character options**.
  Treat these as drift checks, not permanent limits.
- The baseline from the first COMPLETE capture (2026-08-19) is **110 IP records, 2,827
  catalog nodes, 7,000 assets, 7,216 asset-to-catalog links**. Treat them as drift checks,
  not permanent limits.
- **The old 1,488 catalog figure was wrong.** It measured the DOM tree walk, which only
  sees branches the page has expanded, and it silently dropped half the library and both
  top-level roots. Never reinstate a DOM walk as the catalog source.
- Every catalog parent resolves or is a root.
- Every relationship endpoint exists in the same capture.
- Asset paging reaches a terminal short page unless the run is explicitly `limited`.
- Unique source ID counts equal emitted direct-entity row counts.
- Explicit and inferred relationship counts remain separate.
- The reviewed 2026 baselines are 7,113 inferred asset assignments covering all 7,000
  assets, 19 guide links, and 250 Character evidence links representing 78 unique
  candidates. A mismatch stops the loader before any write.
- A smoke test never qualifies as a complete capture.

## Database boundary

Land evidence first in capture-scoped `plm.sega_*` tables. **All 17 tables are live in
production** through shared-db #1196, #1276, and #1451. The original 12 tables remain,
plus `sega_asset_property_inferred`, `sega_style_guide_property_inferred`,
`sega_character_property_inferred`, `sega_submission_capture`, and
`sega_submission_property`. The asset-side finalize gate now requires 14 entity counts;
an older 11-count loader is deliberately rejected. Submission captures use
`begin_sega_submission_capture` / `finalize_sega_submission_capture` and their own latest-
complete clock. Keep inferred evidence in the `_inferred` tables and promote nothing into
canonical licensing tables without governed resolution rules.

## Field shapes that have already bitten (verified 2026-08-19)

- `FileSize` is a **float in KB** (e.g. `1638.197`), not an integer and not bytes. The
  `file_size_kb` column is `bigint`, so it must be rounded. An unrounded float, a
  non-numeric value, or one past the bigint maximum wedges a capture in `loading` with a
  raw cast error -- the defect filed as shared-db #1222. Refuse such a value by name
  before it reaches the database.
- Dates arrive as **`M/d/yyyy` strings with no time and no zone** (the row declares its
  own format in `DateForm`). Anchor them at UTC midnight and say so; do not let a locale
  parser guess. `DateExpires` is `null` for most assets and that is absence, not an error.
- `Artist` is frequently the literal string `-NA-`, which is a placeholder, not a name.
- All licensors for one Property render into **one comma-separated grid cell**. Comma is
  the only separator the portal offers, so a licensor whose legal name contains a comma
  cannot be distinguished from two licensors. Split on comma but keep the undivided
  source cell on every row so a reviewer can always reconstruct what Sega said.
- Most tags carry a numeric `TagId`; some do not. Identify those by normalized label and
  record WHICH method was used, so nobody mistakes a label match for a source identity.

## Windows: the checkpoint rename fails intermittently

`atomicJson` writes a `.tmp` file then renames it over the checkpoint. On Windows that
rename intermittently fails with `EPERM` when an antivirus or search indexer briefly holds
the destination handle, and it killed a full capture mid-run on 2026-08-19. The scraper now
retries the rename ten times with backoff and still fails loudly if the lock never clears.
Do not remove that retry, and do not respond to an `EPERM` here by disabling the atomic
write -- a checkpoint that cannot be written is not a checkpoint.

## The whole portal was searched for an asset-to-property link. There is none.

Do not repeat this search. Every area of the site was walked on 2026-08-19:

- **`LoadImages` cannot filter by property.** The page's OWN script shows the complete
  parameter list: `currentPage`, `catalogId`, `searchText`, `recordsPerPage`, `orderBy`,
  `ignoreExpired`, `purgeCache`. Adding `ipId`, `ipIds`, `ipID`, `ip` or `propertyId` changes
  nothing: the result count is identical to unfiltered. The server ignores them.
- **The 111-option IP dropdown on the Content Library is not a filter.** It is hidden from
  the user (`offsetParent` null) and sits in a container with id **`associationInput`**. It
  is the control for AUTHORING an asset-to-IP association, which is a licensor-side action.
  The feature exists in the product; Sega has not populated it for this account. That is why
  `LoadAssetIpAssociation` answers for all 7,000 assets and returns nothing.
- **`GetAllIps`, `LoadIps`, `GetIpList`, `GetAllCatalogsForIp`, `LoadCatalogIpAssociation`,
  `GetCatalogIps` all return HTTP 401.** Not available to a licensee.
- **`GetCatalogAccessRights` works** and returns 1,488 records with `CanView`, `CanModify`,
  `CanDownload`, `CanUpload`, `CanDelete` per catalog. Useful for permissions; carries no IP.
- **The Product Approval LIST has no property column, but the NEW form has a required IP
  picker.** The grid is Submission #, Submission Code, Samples, Licensor, Contract, Stage,
  Revision #, Stage Status, Date Submitted, Submitted By, SKU, Response Date, Type. Its
  search vocabulary also omits Property. However, New Submission -> Product Approval opens
  `ProductApprovalSubmissionWnd.aspx?ApprovalID=0`; selecting active Contract `2478`
  populates `ddlIPs` with 6 exact IP choices. These are the canonical submission vocabulary.
  All 6 match registry IDs and labels; the other 104 registry records are secondary for this
  contract. `ddlChildIPs` stays empty for every choice, so no Character/link vocabulary is
  offered. The rendered controls are readable even though page methods return 401.
- **`IPPage.aspx` rows are not clickable.** No per-property detail view, no folder list.
- The only other pages are `ExternalHelpDocs.aspx` and `ExternalUserPreferences.aspx`.

## Folder containment is the only usable inference, and both scopes are implemented

The current production rule lives in `sega/loader/canonical-relationships.mjs` and targets
only the six active Product Approval Properties. It produces 7,113 asset assignments,
19 guide links, and 250 Character-evidence links. The registry-wide
`infer-property.mjs` result below is retained as historical analysis and is not the load
rule.

Every asset sits in at least one folder, so containment always applies. Coverage depends
entirely on the normalization, and the difference is dramatic:

| Rule | Assets attributed |
|---|---|
| Raw label match | 2% |
| Family word taken from ONE end of the family name | 12% |
| Family word tried from BOTH ends | **77%** (5,377 of 7,000, 37 of 110 properties) |

The rules, all written generically so no licensed name is hard-coded:

- **Registry side.** A `"<Family>: <Title>"` label also matches the folder `"<Title>"`,
  because the tree expresses the family as a branch instead. A `"<Family>: <Variant>"`
  label also matches `"<Variant> <FamilyWord>"`.
- **Which family word?** Not predictable. Folders reuse the BRAND word, which may sit at
  either end of the registry name. **Try both ends.** This single detail is the difference
  between 12% and 77%, and getting it wrong looks like a working rule with poor coverage,
  not like a bug.
- **Folder side.** Strip release years `(2022)`, regions and platforms (`EU`, `US`, `JP`,
  `UK`, `PC`, `Wii U`, `3DS`, `PS2`-`PS5`, `Xbox`), a trailing `- Something`, and
  housekeeping words (`CONFIDENTIAL`, `DO NOT DISTRIBUTE`, `Style Guide`, `Trend Guide`,
  `Core Assets`, `Final Files`, `Assets`).
- **Convert underscores to spaces FIRST.** `_` is a word character, so a `\b` boundary
  never fires inside `Title_Final Files` and every housekeeping word survives the strip.
- **Keys shorter than 4 characters are dropped.** They match nearly everything.
- **Attribute the whole SUBTREE** beneath a matched folder, at lower confidence than the
  folder that matched by name.

Confidence is three honest tiers, not a tuned score: `exact_label` 0.8, `normalized_label`
0.6, `subtree_of_match` 0.5. On the real capture almost all rows are `subtree_of_match`,
which is exactly what it should be -- most files are several levels below the folder that
carries the property name.

**The 130 assets with two properties are not errors.** They are a platform-level entry and
a title-level entry that are both true of the same file. This registry mixes the two, so
do not add a uniqueness constraint per asset and do not resolve them to one winner.

### Where these rows may and may not go

`plm.sega_asset_property` is constrained to `source_asset_ip_association` and that is
CORRECT -- it holds what the licensor declares. A folder guess written there would be
indistinguishable from a portal fact.

The destinations are `plm.sega_asset_property_inferred`,
`plm.sega_style_guide_property_inferred`, and
`plm.sega_character_property_inferred`. They are live in production and every row is pinned
to `relationship_truth = inferred` with evidence, method, rule version, and confidence.
## Assets are concentrated in two branches

16 top-level branches exist, but the files are not spread evenly. The largest branch holds
4,562 assets and the second holds 2,438; every other branch holds 53 or fewer. The
110-record IP registry is CONTRACT scope. The library covers far less, so a property with no
files is normal and is not a failed capture.
## Asset-to-IP associations may legitimately be EMPTY

`LoadAssetIpAssociation` returned zero rows for every asset checked in the first complete
capture. That is a real answer for this account, not a bug and not a reason to retry, but it
means **the Content Library carries no direct Property link for its files**. Consequences:

- Do not treat an empty `links-asset-property.csv` as a failed capture. The loader accepts
  zero links while still requiring that every asset was ASKED.
- The distinction that matters is *asked and got nothing* versus *never asked*. Track the
  per-asset checkpoint, not just the relationship count.
- With no direct link, folder-path containment is the only Property signal available, and it
  stays inferred evidence. Never promote it to a direct relationship to fill the gap.

The association pass costs one request per asset (7,000 requests) and dominates the runtime
of a full capture. `--skip-ip-associations` makes a capture unloadable, so use it only for
reconnaissance.

## GetAllCatalogs is the catalog source, not the DOM

`POST ContentLibrary.aspx/GetAllCatalogs` with an empty body returns EVERY catalog the
account can see. Fields: `CatalogId`, `Parent` (a nested catalog; `CatalogId: 0` means no
parent), `Name`, `Description`, `ExpirationDate`, `ExpirationDateString`, `StyleGuide`.

Three things follow, all of which cost a rewrite to learn:

1. **Parentage is a source fact.** Walk `Parent.CatalogId` to build the path. The earlier
   code reconstructed parentage by matching joined path STRINGS, which cannot tell apart
   two identically named folders under different branches.
2. **The DOM undercounts by roughly half.** `[data-hierarchypath]` only exists on expanded
   branches. Keep reading the DOM only for the `data-permission-edit`/`-delete` attributes,
   which the API does not return.
3. **`StyleGuide` is a real boolean the portal declares.** In the 2026-08-19 capture it was
   **false on all 2,827 catalogs**, so the name-rule guess is still the only guide signal
   available and style guides remain INFERRED. If a future capture returns any true value,
   that is a direct fact -- and `plm.sega_style_guide_candidate.evidence_type` is currently
   constrained to `catalog_name_rule` alone, so recording it needs a shared-db change
   first. Do not misfile a declared flag as a name rule to avoid that.

`LoadImages` also returns an `allCatalogs` array of the same length, but as bare NAME
strings with no IDs. Use it only as a count cross-check, never as an identity source.

## The schema vocabularies are narrower than they look

`plm.sega_*` pins these with CHECK constraints. Three wrong spellings were caught only
when a real load hit the database, so they are now asserted in
`sega/loader/transform.test.mjs`. Change them there in the same session the schema changes.

| Column | Allowed values |
|---|---|
| `sega_tag.identity_method` | `source_id` (needs `tag_source_id`), `normalized_label_fallback` (needs it NULL) |
| `sega_character_evidence.evidence_type` | `character_branch`, `catalog_path`, `filename` |
| `sega_character_evidence.relationship_truth` | `inferred` only |
| `sega_style_guide_candidate.evidence_type` | `catalog_name_rule` only |
| `sega_style_guide_candidate.classification_type` | `style_guide`, `trend_guide`, `text_guide`, `packaging_guide`, `other_guide` |
| `sega_asset_property.evidence_type` | `source_asset_ip_association` only |

Also enforced: every `confidence` in 0..1; `sega_character_evidence` must name EXACTLY one
of a catalog or an asset; `file_size_kb` and `width` cannot be negative; a catalog cannot
be its own parent; `hierarchy_depth` must exceed 0.

**`sega_catalog.parent_catalog_source_id` is a SELF-REFERENCING foreign key.** Insert
catalogs ordered by depth or a child arrives before its parent and the load dies part-way.

## A capture key is pinned to its code

`begin_sega_capture` refuses an existing key whose `source_commit_sha` or manifest hash
differs. That is deliberate. If you fix loader code and reload the same files, you need a
NEW `--capture-key`; the old attempt is a different thing and must not be overwritten.
Finalize an abandoned attempt so it records as `rejected` with its reasons rather than
sitting in `loading`, which reads like a load still in flight.

## Learning loop

When the portal changes or a new field is verified, update the portal map, output contract, scraper tests, and collector together. Record failed approaches so future sessions do not repeat them.
