# Output contract

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

Do not infer a style-guide ID from its name. If the source ID is absent, null is correct.

Optional provenance columns may include `crawl_id`, `contract_scope`, and `notes`. Never place credentials or browser tokens in output.

## Known direct-list behavior

Verified 2026-08-07 on the Product submission page: selecting `Batman (1989)`, opening `+Add Product`, and opening Characters returned 27 property-specific options. The list included people, vehicles, locations, logos, a combined-character entry, `No Character Likeness`, and `No Reportable Elements`. The dialog was cancelled without adding or submitting a product.
