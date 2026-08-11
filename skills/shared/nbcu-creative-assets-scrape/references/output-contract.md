# NBCU output contract

Store the capture only under `nbcu/` in the private source-data repository.

Required files:

- `properties.csv`: `property_source_id,property_label,source_kind,ip_family_source_key,ip_family_label,licensed_scope_label,captured_at,source_url`
- `characters.csv`: `character_source_id,character_label,id_fallback,captured_at,source_url`
- `style-guides.csv`: `style_guide_source_id,style_guide_natural_key,style_guide_label,folder_path,captured_at,source_url`
- `assets.csv`: `asset_source_key,asset_path,file_name,media_type,display_size,display_modified,studio_labels,ip_family_labels,property_labels,character_labels,restriction_labels,style_guide_natural_keys,scope_paths,captured_at,source_url,raw`
- `links-ip-family-property.csv`
- `links-property-character.csv`
- `links-asset-property.csv`
- `links-asset-character.csv`
- `links-asset-style-guide.csv`
- `links-style-guide-property.csv`
- `capture-summary.json`
- `failures.csv`

Each relationship file must include both endpoint keys or exact labels, `evidence_type`, `evidence_value`, `captured_at`, and `source_url`. Create only relationships actually supported by portal evidence. Document unsupported link types in `README.md`.

Use JSON arrays inside CSV cells for multi-value fields. Never collapse them to delimiter-joined text. Keep `raw` to recover useful source headings without adding unstable columns.

Completeness requires:

- every allowlisted business title resolved or listed as unresolved;
- every resolved scope fully paged until zero new asset paths;
- every unique asset has one parsed detail record or one failure row;
- every link endpoint exists in its matching entity file;
- counts reconcile after exact-path deduplication;
- no media content was downloaded.
