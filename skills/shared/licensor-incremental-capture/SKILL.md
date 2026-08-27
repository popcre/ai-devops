---
name: licensor-incremental-capture
description: Re-scrape a licensor portal and capture only new, changed, or withdrawn records. Use for refresh, re-scrape, delta, incremental, "what changed", or bookmark, manifest, and run-state design across any licensed-content portal.
disable-model-invocation: true
---

# Licensor incremental capture

Style guides are living. Licensors add guides, replace art in place under the same file
name, and withdraw assets. A capture is therefore never "done" - it has a date, and the
next run has to work out what moved.

This skill owns the refresh discipline shared by every licensor. The per-licensor skill
still owns that portal's endpoints, entitlement rules and field names. Load both.

Per-licensor skills: `nbcu-creative-assets-scrape`, `disney-source-data-scrape`,
`paramount-creative-library-scrape`, `peanuts-scrape`, `sesame-workshop-scrape`,
`strawberry-shortcake-scrape`, `wb-starlabs-scrape`.

## The one rule that matters most

**A date is not a bookmark.** "Fetch everything modified since 2026-08-11" finds new files
and silently misses the two changes that hurt:

- art replaced in place under the same name and same path
- an asset withdrawn from the portal

It also cannot work at all on a portal that exposes no modified date. Disney DCP Vault
exposes none. NBCU exposes only a rendered display string.

So the bookmark is a **manifest**: every entity key the last run saw, with a change signal
next to it. The next run rebuilds the index, diffs against the manifest, and only pays for
detail fetches on rows that are new or whose signal moved. The run timestamp is recorded,
but nothing depends on it alone.

## Two different kinds of state - do not confuse them

| | Purpose | Lifetime | Example |
|---|---|---|---|
| **Resume checkpoint** | Survive a crash *inside* one run | Deleted when the run completes | `disney-dcpvault/crawl-resume-state.json` |
| **Capture bookmark** | Tell the *next* run what changed | Committed, permanent, grows over time | `<licensor>/capture-state.json` + `manifest/` |

A resume checkpoint must never be read as a bookmark. Half a crawl looks exactly like
"the licensor withdrew half their library".

## Files every licensor keeps

Under `<licensor>/` in the private `u2giants/licensor-source-data` repo:

```text
capture-state.json          the bookmark header - last run, scopes, counts, health
manifest/assets.csv         one row per asset ever seen
manifest/properties.csv     one row per property ever seen
manifest/style-guides.csv   one row per style guide ever seen
manifest/characters.csv     one row per character ever seen
deltas/<UTC>/added.csv      what this run gained
deltas/<UTC>/changed.csv    what this run saw move
deltas/<UTC>/withdrawn.csv  what this run stopped seeing
deltas/<UTC>/summary.json   counts, scopes, gate results, failures
```

### capture-state.json

```json
{
  "licensor": "nbcu",
  "last_run_started_at": "2026-08-19T20:14:02Z",
  "last_run_completed_at": "2026-08-19T21:40:55Z",
  "last_run_status": "complete",
  "scopes": [
    { "scope": "<exact query scope>", "indexed": 8783, "detail_fetched": 41 }
  ],
  "totals": { "assets": 113331, "properties": 125, "style_guides": 461, "characters": 190 },
  "change_signal": "display_modified+display_size",
  "manifest_sha256": "<hash of manifest/assets.csv>",
  "notes": "free text - portal quirks seen this run"
}
```

`last_run_status` is `complete`, `partial` or `failed`. **A run that is not `complete`
must never be used as the diff baseline.** Fall back to the last complete run.

### manifest rows

Every manifest carries the same five bookkeeping columns alongside the entity's own key:

| Column | Meaning |
|---|---|
| `source_key` | the licensor's own identifier, exactly as published |
| `change_signal` | the value compared between runs (see table below) |
| `first_seen_at` | UTC of the run that first indexed it |
| `last_seen_at` | UTC of the most recent run that still saw it |
| `status` | `active` or `withdrawn` |

## Change signal per portal

Use the strongest signal the portal actually publishes. Never invent one.

| Licensor | Change signal | Strength |
|---|---|---|
| Paramount | `date_last_updated` + `version` | strong - a real update stamp |
| Warner STARLABS | `modified_date` + `file_size_bytes` | strong |
| NBCU | `display_modified` + `display_size` | medium - rendered strings, coarse |
| WildBrain, Peanuts, Sesame | portal's own modified/updated field where present, else size | medium |
| Disney DCP Vault | presence + file name + extension only | weak - no date published |

Where the signal is **weak**, presence-diffing still catches added and withdrawn assets,
but an in-place art replacement is invisible. Say so plainly in the run summary rather
than implying full coverage, and schedule a periodic full re-fetch (see below).

## The incremental run

1. **Load the baseline.** Read `capture-state.json`. Refuse to continue if
   `last_run_status` is not `complete`; use the last complete run's manifest instead and
   note it.
2. **Re-index every authorized scope, in full.** Indexing is metadata-only and cheap.
   Never try to shortcut the index itself - that is what makes the diff trustworthy.
3. **Diff against the manifest.**
   - key absent from manifest -> **added**
   - key present, `change_signal` differs -> **changed**
   - key in manifest as `active`, absent from this index -> **withdrawn candidate**
4. **Run the safety gates below.** Stop before any write if a gate fails.
5. **Fetch detail only for added and changed rows.** This is the whole saving. A refresh
   that touches 40 files should cost 40 detail fetches, not 113,000.
6. **Write the delta files**, then update the manifests (`last_seen_at` on everything
   still present, new rows for added, `status` on withdrawn) and `capture-state.json`.
7. **Load the delta only.** See below.

Apply the same four steps to properties, style guides and characters, not just assets. A
new style guide with no new assets, or a character quietly renamed, matters as much as a
new file.

## Safety gates - the failure that destroys data

The dangerous failure is not missing a new file. It is a broken session, an expired login
or a changed URL producing an empty or short index, which the diff then reads as **the
licensor withdrew everything**.

Before writing any delta, all of these must hold:

- **Authentication proof.** The index pages are real results, not a login or error page.
  Per-portal login-page fingerprints live in the per-licensor skill; NBCU's returns HTTP
  200 with the title `CAF Login Options`.
- **Scope coverage.** Every scope in the baseline was re-indexed this run. A scope that
  errored makes the run `partial`, and **assets under a scope that was not re-indexed are
  never marked withdrawn**.
- **Shrink gate.** If withdrawn candidates exceed **2% of the baseline or 100 rows,
  whichever is smaller**, stop and report. Do not write. Real withdrawals are a trickle;
  a cliff means a broken run.
- **Zero gate.** An index returning zero rows for a scope that previously had rows is a
  failure, never a withdrawal.

A gate that trips is reported to Albert with the numbers, and the run ends `partial`.
Never widen a gate to make a run pass.

## Withdrawn assets - owner ruling 2026-08-19

**Mark withdrawn, never delete.** Set `status = withdrawn` and record the date it stopped
appearing. Keep the row, in the manifest and in the database.

The reason is commercial, not technical: product may already have been made from that art,
and the record of what was once licensed and available has to survive the licensor tidying
their portal. A withdrawal is also frequently temporary - a guide gets pulled and reposted.
If a withdrawn key reappears on a later run, set it back to `active`, keep the original
`first_seen_at`, and note the gap.

## Periodic full re-verify

Incremental runs trust the change signal. Where the signal is weak or coarse, drift
accumulates. Do a **full detail re-fetch every 90 days, or whenever the portal changes its
markup**, and record it in `capture-state.json` as `"full_reverify_at"`. A full re-verify
uses the identical diff machinery; it simply refetches detail for every row instead of only
the moved ones.

## Loading the delta

Ordinary application row writes belong to this session and need no orchestrator issue.
**But outside-sourced content landing in curated Master Data (`core.licensor`,
`core.property`, `core.character`, `core.customer`, `core.factory` and their `*_ext`
tables) stays orchestrator work under the shared-db carve-out.** A bulk portal dump can
silently supersede hand-curated owner rulings. Route those through
`gh issue create --repo u2giants/shared-db --label db-work`.

For the licensor scrape tables themselves:

- Upsert **only** the rows in `added.csv` and `changed.csv`, keyed on the licensor's own
  source key. Never truncate and reload - that destroys `first_seen_at` and any local
  curation.
- Apply `withdrawn.csv` as a status update. Never a `DELETE`.
- Write one load receipt per run under `<licensor>/load-receipts/`, naming the delta
  directory it loaded and the resulting row counts.
- Prove which database you are pointed at before any write and quote the proof.

**Structure changes go through `shared-db` first.** Incremental capture needs columns many
licensor tables do not have yet - `first_seen_at`, `last_seen_at`, `status`,
`withdrawn_at`, and the source-key uniqueness the upsert depends on. Do not `ALTER`
anything from an application repo. Open a shared-db issue naming those columns, and until
they exist, keep the manifest in the repo and load nothing that needs them.

## Reporting a refresh

Tell Albert, in this order: what changed, what it cost, and what you could not see.

```text
NBCU refresh - 19 Aug 2026, baseline 11 Aug 2026
  new          41 assets, 2 style guides, 0 properties, 0 characters
  changed       6 assets (art replaced in place)
  withdrawn     1 asset
  unchanged   113,284
  cost         47 detail fetches, not 113,331
  blind spot   none this run
```

State the blind spot honestly. On a weak-signal portal it reads: `in-place art
replacements are not detectable here; last full re-verify 12 Jun 2026`.

## Confidentiality

Unchanged from the per-licensor skills. Licensed rows, rights lists and examples stay in
the private repo and never appear in a public repo, a GitHub issue, a commit message, a PR
body, logs, or a prompt sent to an outside service. Describe shapes and counts, never paste
the data.
