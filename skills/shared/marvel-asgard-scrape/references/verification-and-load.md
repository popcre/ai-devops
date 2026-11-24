# Verification, normalization, and guarded load

## Raw verifier

Run `marvel-asgard/scripts/verify-capture.mjs` before normalization or loading. It must prove:

- planned guide count equals completed guide count and every pre-registered guide is present;
- zero crawler failures and structural gaps;
- manifest, leaf, page, displayed-total, and observation counts reconcile;
- no duplicate observation key carries conflicting evidence;
- every non-empty leaf has complete facet evidence;
- zero facet failures;
- evidence files match their leaf identity and page markers;
- no `facet-work-*.json` remains `in_progress`.

Counts from an older run are regression signals, not a reason to force a changed catalog to match. Explain legitimate drift with a new immutable capture.

Run `browser-crawler.test.mjs`, `verify-capture.test.mjs`, `normalize-capture.test.mjs`, and `load-to-supabase.test.mjs`. The API enricher must also have tests for authentication rejection, retry downgrade, exact filename multiset reconciliation, duplicate filenames, atomic resume, and exact-path leaf repair before relying on it for a final production snapshot.

## Normalization

Run `normalize-capture.mjs` only after raw verification passes. Preserve source text alongside normalized entities and relationships. Reconcile every normalized table or chunk to raw source counts, and retain unresolved or malformed values as evidence rather than dropping them.

Guide manifests are the sole index of authoritative page evidence. Do not glob every `page-*.json`: exact-path repairs deliberately leave superseded pages as historical evidence, and loading those orphan files duplicates observations.

The guarded chunk function rejects media-access and account-identity keys anywhere in the JSON payload. Recursively remove source fields matching preview/download/signed/thumbnail URLs, generic URL or href, tokens, account/user IDs, email, renditions, download capability, and ASGARD media base URLs. Preserve the exact names of omitted fields as provenance, but never load their values. Verify the normalized payload contains zero forbidden keys before writing.

## Git gate

Licensed output belongs only in the private `u2giants/licensor-source-data` repository. Preserve unrelated dirty work and stage only owned `marvel-asgard` files. Before the first commit, run `git var GIT_COMMITTER_IDENT`; it must identify `Albert Hazan <u2giants@users.noreply.github.com>`. Never commit tokens, cookies, account data, temporary backups, or downloaded media.

The source commit recorded for a load must be the exact full commit containing the verified raw snapshot and loader code.

## Production target proof

Database rows are application-owned work; database structure remains governed by `u2giants/shared-db`. Load `codex-shared-db-change` before any structure question or production data write.

Immediately before every write, independently resolve and prove the expected Supabase project ref and project name. The known target is project `popdam`, ref `qsllyeztdwjgirsysgai`, but re-derive it live; do not trust a handoff, environment variable name, or previous connection as proof.

Read the live guarded-function signatures and privileges. Use the approved secret path without printing or persisting credentials. Abort on any target, signature, privilege, or source-commit mismatch.

## Load and final audit

Use `marvel-asgard/scripts/load-to-supabase.mjs` through begin, bounded repeat-safe chunks, and finalize. The loader itself must require a successful raw-verifier result; do not rely on operator memory. If that invariant is absent, fix and test it before loading.

Finalize only when all 75 account-visible guides and every non-empty leaf for that capture are verified, with no unresolved gaps. After loading, audit exact raw, normalized, chunk-ledger, entity, observation, relationship, gap, and rejected-row counts. Expected counts must equal observed counts and the capture must be current/complete.

Replay at least one exact chunk to prove idempotency. Prove a reused observation key with changed evidence fails closed. Completion requires both the private committed snapshot and exact production reconciliation; successful migrations or a partial load are not completion.

Use manifest-reconciled byte-bounded chunks. Find the largest slice by binary search; shrinking one row at a time caused quadratic serialization on the 204 MB normalized snapshot. A no-write validation mode must prove target, capture key, counts, and chunk bounds before `begin`.
