# Output contract

## Private repository layout

Create only these Warner-owned paths under `warner-bros/` in the private `u2giants/licensor-source-data` repository:

```text
warner-bros/
  franchises.csv or properties.csv
  style-guides.csv
  characters.csv
  assets.csv
  links-asset-style-guide.csv
  links-style-guide-franchise-property.csv
  links-asset-character.csv
  links-property-character.csv
  README.md
```

Use Warner's own word for the top-level file. Create only relationship files the portal supports, and document absent link types in `README.md`. Keep `disney-opa/` untouched.

## Property-character CSV

Required columns:

```text
property_source_id,property_label,character_source_id,character_label,id_fallback,captured_at,source_url
```

- IDs are text and remain blank when Warner exposes none.
- `id_fallback` is `true` only when exact labels are the only available identity.
- Preserve labels byte-for-byte after normal CSV decoding. Do not trim meaningful punctuation or normalize case.
- One row represents Warner exposing that character option for that selected property.

This relationship CSV is intentionally one property per row. That does not conflict with the asset-source contract, where `property_labels` and `franchise_labels` are arrays because one asset may carry several values.

## Asset-source fields

- `property_labels text[]`, never scalar `property_label`
- `franchise_labels text[]`, never scalar `franchise_label`
- `character_labels text[]`, with royalty placeholders preserved
- nullable `style_guide_source_id text`
- non-null `style_guide_natural_key text`, populated from `public:styleGuideName`
- byte-exact asset file name and any exposed full path/folder structure
- asset source ID, size, and source dates
- explicit source IDs and relationship provenance for every available asset/style-guide/Franchise/Property/character link

Do not infer a style-guide ID from its name. If the source ID is absent, null is correct.

Do not derive classifications from file-name substrings. Do not download the underlying asset files.

Optional provenance columns may include `crawl_id`, `contract_scope`, and `notes`. Never place credentials or browser tokens in output.

## Hierarchy and linkage fields

Keep Warner's vocabulary and IDs without normalising them. Add source fields as exposed for:

- franchise label and ID
- property label and ID
- parent label, ID, and source level for sub-brands or deeper hierarchy
- style-guide label, natural key, and source ID
- character label and source ID
- explicit relationship type and provenance

Do not assume Franchise equals Property. Do not flatten hierarchy. Do not infer that a style guide sits between a property and character.

## README scope statement

Record the account entitlement scope, line of business, capture date, exact source URLs, whether each relationship type was present or absent, and that the extract is a point-in-time view of the licensee's allowed catalogue rather than Warner's complete catalogue.
