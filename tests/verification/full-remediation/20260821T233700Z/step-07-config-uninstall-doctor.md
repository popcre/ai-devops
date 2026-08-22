# Step 7 verification - config, uninstall, and doctor

- Config schema 1 merges only missing safe defaults, preserves user values,
  validates syntax and duplicates, keeps a restricted hash-verified backup, and
  records the schema/source SHA.
- Install manifest records exact source, schema, owned command links, config,
  skill markers, and hashes.
- Uninstall has exact dry-run, minimal, purge, and full modes. It refuses broad
  paths and dirty repositories, preserves foreign links/auth, and requires a
  verified config archive/Git bundle before deletion.
- Doctor compares repository and installed SHAs, schema, manifest hashes,
  machine-config drift, private memory origin, schedule state, node/npm/npx,
  and all eight reviewer providers.
- Focused config, manifest, uninstall, doctor-state, and Codex probe fixtures
  pass. A live protected archive/restore remains a Step 16 gate.
