---
name: marvel-asgard-scrape
description: Capture, resume, repair, verify, normalize, or load authorized Marvel ASGARD style-guide and creative-asset metadata. Use for ASGARD guides, hierarchy nodes, files, characters, likeness, keywords, facets, provenance, completeness, or guarded Supabase landing.
---

# Marvel ASGARD scrape

Capture the signed-in account's point-in-time view of Marvel Creative Assets without changing ASGARD or downloading licensed media.

## Source authority

- Marvel submissions moved to Disney OPA in December 2025.
- Marvel Creative Assets remain authoritative in ASGARD.
- Do not classify Marvel Creative from DCP Vault tags. The observed Marvel-tagged DCP slice came from a mixed Back-to-School guide where Disney, Lucasfilm/Star Wars, and Marvel tags were applied to every asset.
- Preserve conflicting DCP evidence privately, but use ASGARD for Marvel guide, asset, character, likeness, and keyword relationships.

## Private working source

Use `C:\repos\licensor-source-data\marvel-asgard`. Read its scripts and current raw checkpoint before capture work. Keep all licensed rows, filenames, source UUIDs, portal responses, and snapshots in that private repository or the approved private database. Never include them in public repositories, issues, PR text, logs, outside-AI prompts, or user-facing summaries.

## Hard rules

1. Treat ASGARD as read-only. Do not alter baskets, upload, submit, approve, share, or download artwork.
2. Metadata capture is authorized; media download is not implied.
3. Preserve exact source values and raw evidence. Do not clean malformed values or infer identities during capture.
4. A source UUID groups an asset, but each observed file is separate. One UUID can legitimately retain multiple exact filenames.
5. Record category, guide, full node path, page, row order, and raw observation hash for every file observation.
6. Checkpoint every leaf. Authentication loss, changed totals, unreconciled filenames, reused observation keys with changed evidence, or missing facets fail closed.
7. Never print or persist bearer tokens. A user performs login and MFA.
8. Describe completeness as the account-visible catalog at capture time, never Marvel's global catalog.

## Route the work

- For browser discovery, hierarchy capture, authentication recovery, or UI failure diagnosis, read [references/capture.md](references/capture.md).
- For direct API enrichment, identity reconciliation, retries, and facet semantics, read [references/api.md](references/api.md).
- For entities, relationships, raw evidence, and production table contract, read [references/data-contract.md](references/data-contract.md).
- For verification, normalization, guarded loading, Git, and final audit, read [references/verification-and-load.md](references/verification-and-load.md).
- For the state of an earlier or paused capture, read the progress files in the private repository's raw capture folder. Re-derive live counts before acting.

## Preferred workflow

1. Inspect the durable checkpoint and confirm no prior crawler is still running.
2. Use the browser only to establish or renew the authenticated session and to capture surfaces not exposed by the API.
3. Use the authenticated ASGARD API for bulk leaf assets and facets. Save atomically after every completed leaf.
4. Reconcile every API leaf against the browser capture by exact path and exact filename multiset. Repair only the affected leaf from exact-path API evidence.
5. Run the raw verifier. Resolve every structural, identity, facet, and unfinished-work gap.
6. Run tests, normalize, and verify normalized counts against raw evidence.
7. Commit only owned private Marvel files after verifying the committer identity.
8. Prove the production Supabase target immediately before writing, then use only the guarded Marvel functions.
9. Audit exact end-to-end counts and idempotent replay. Do not call the scrape complete until every account-visible guide and non-empty leaf is covered and production counts reconcile.

## Incremental refreshes

For a later re-scrape or delta, also load `licensor-incremental-capture`. Re-index the full account-visible hierarchy before interpreting absence. Never convert a short, failed, or unauthorized crawl into a withdrawal. Keep each capture immutable and preserve change evidence.

## Learning loop

After a real capture or load, update this skill with durable endpoint behavior, fields, identity evidence, paging limits, failure modes, recovery, and database guards. Never add licensed rows, filenames, account data, credentials, tokens, or media.
