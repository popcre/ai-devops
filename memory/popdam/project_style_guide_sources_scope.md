---
name: project_style_guide_sources_scope
description: Style Guide Sources (sku_files_used) scoped to licensing/tech-pack PDFs only; legacy rows pending cleanup
metadata: 
  node_type: memory
  type: project
  originSessionId: 7e817a71-7bb1-4074-b04a-1470f2e58c41
---

As of 2026-06-10, "Style Guide Sources" (`sku_files_used`) are populated ONLY from PDFs whose
filename contains `licensing sheet` / `license sheet` / `tech pack` / `techpack` (predicate
`is_style_guide_source_pdf(file_type, filename)`, migration `20260610070731`).

All three write paths are gated: `parse_pdf_files_used()` (DB trigger + admin RPC), the JS parse
in `agent-api/complete-pdf-backfill-batch`, and the `ai-tag` vision `files_used` upsert. The PDF
backfill claim/count (`claim_pdf_backfill_batch`/`count_pdf_backfill_remaining`) were also scoped
to these PDFs only, dropping ~39k `.ai` + non-licensing PDFs (remaining 52,862 → 13,819). This
also pauses the `.ai` sentinel-cleanup sampling via the backfill claim.

**Non-obvious:** today's existing rows did NOT come from the `.ai`/PDF text parser — they came
from the `ai-tag` vision model reading rendered artwork. The `.ai` OCR text is garbage (or the
"saved without PDF Content" sentinel); the AI read the actual tech-pack render.

**Pending obligation (delete the garbage eventually):** `sku_files_used.source` column tracks
provenance — `pdf_text`, `ai_tag`, or `legacy_ungated`. The 863 pre-gating rows are marked
`legacy_ungated` for the user to double-check. Once verified, purge them:
`DELETE FROM sku_files_used WHERE source = 'legacy_ungated';`

**Why:** the user wants Style Guide Sources sourced from the authoritative licensing PDF, not the
redundant-but-harder-to-extract `.ai`, and does not want stale/garbage rows kept forever.

**Resolver normalizer bug (FIXED 2026-06-10, migration 20260610100545):** `normalize_for_sg_match(p)`
stripped `[^a-z0-9]` BEFORE `lower()`, DELETING uppercase letters (`2994221_BG101` → `2994221101`).
Now lowercases first. This had silently broken exact resolution whenever case differed.

**Fuzzy + continuous resolution (2026-06-10):** `resolve_sku_files_used_fuzzy(threshold)` (migration
20260610100856, trigram-only for perf; gin index `idx_style_guide_files_filename_trgm`) matches
unresolved rows against active `style_guide_files` on `lower(filename)`, auto-links ≥0.6, records
`match_best_score`/`match_attempts`/`last_match_attempt_at` otherwise. Scheduled nightly via pg_cron
`resolve-sku-files-used-nightly` at `0 4 * * *` UTC (after the `0 2` SG crawl) so pending rows
self-link as PopSG heals. Quarantine model: never deletes/unlinks.

**Legacy cleanup outcome (2026-06-10):** of 863 legacy rows → 730 resolved (592 prior + 138 fuzzy),
88 pending (64 reviewable ≥0.4 best-guess, 24 low-info), 45 deleted (style-guide *titles* the ai-tag
vision misread as filenames + 1 self-SKU). Filename-shaped no-match codes were KEPT as pending — do
NOT delete them, because PopSG is NOT comprehensive (see below).

**PopSG NOT comprehensive (user-reported 2026-06-10):** SG crawl completes fine (~214k active, single
root `/mnt/nas/styleguides`) but a 2nd location `\\edgesynology2\styleguides` fails to mount and may
never be crawled, and an empty-crawl once flipped files inactive (`20260610180000_restore_popsg_active_files_after_empty_crawl`).
So "no PopSG match" ≠ garbage. OPEN: confirm whether the crawl root should include edgesynology2;
consider a crawl-regression guard + also matching files_used against PopDAM `assets`. OCR-typo
prevention: prefer PDF text-layer extraction over OCR/vision; normalizer fixed; fuzzy-resolve continuously.

Related: [[project_pdf_backfill_processor]]
