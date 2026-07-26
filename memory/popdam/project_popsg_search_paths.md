---
name: project_popsg_search_paths
description: "PopSG library search uses a DIFFERENT code path than PopDAM (style_guide_file_groups raw ILIKE, not the dam_search_documents RPCs)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 19eecc5d-4fd8-4df8-b1da-1513b95eb129
  modified: 2026-07-23T00:50:44.678Z
---

PopDAM and PopSG have TWO separate, unrelated library-search implementations. Don't assume a search bug lives in the full-text pipeline.

- **PopDAM library** (assets / style groups): `src/hooks/useAssets.ts` + `src/hooks/useStyleGroups.ts` → RPCs `search_assets_full_text` / `search_style_groups_full_text` over `dam_search_documents` (synonym-aware, `dam_search_synonyms`), with an ILIKE fallback on timeout.
- **PopSG library** (`sg.designflow.app/library`, the "Style Guides" and "Files" tabs): `src/pages/popsg/PopSGLibraryPage.tsx` queries `style_guide_file_groups` / `style_guide_files` with a **raw `.ilike` substring** on `style_guide_name` / `directory_path` / `filename`. It does NOT touch dam_search_documents, the RPCs, or the hooks at all.

Confirm which path a view uses via the browser network tab before editing — a PopSG "0 results" bug is in PopSGLibraryPage, not the RPC layer. (2026-07-22: "spiderman" returned 0 because `%spiderman%` can't match the stored "Marvel Style Guide/Spider-Man/…" path; fixed by reusing `expandFallbackTerms` from `src/lib/dam-search.ts` — synonyms + hyphen/space variants — to OR expanded terms across the columns. `%spiderman%`=0 rows, `%spider-man%`=113.)

**Files-tab search + trigram/ILIKE gotcha (2026-07-22):** the Files tab searches `style_guide_files` (~215k rows). Franchise search must match `relative_path` (contains directory path AND filename) — searching `filename` alone misses everything because files are named with SKU codes, not franchise names. CRITICAL: a trigram GIN index for PostgREST `col.ilike.%x%` MUST be on the **raw column** `gin (col gin_trgm_ops)` — a `gin (lower(col) gin_trgm_ops)` index is NOT used by the planner for `col ILIKE` (only for `lower(col) LIKE`, which PostgREST can't emit) and it silently seq-scans → 8s statement timeout → 500. Prod indexes `idx_sgf_relative_path_trgm` / `idx_sgf_directory_path_trgm` (raw gin_trgm_ops) added via shared-db migration `20260722220000` (built CONCURRENTLY over psql session-pooler port 5432 with `set statement_timeout=0`, since CONCURRENTLY can't run in `supabase db push`'s txn). Count went 5.7s → ~45ms.

Related: [[project_helper_storage_regions]] (style guide files are Seafile/SMB-synced), [[project_secret_access_paths]].
