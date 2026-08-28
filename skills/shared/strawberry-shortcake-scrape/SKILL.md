---
name: strawberry-shortcake-scrape
description: Capture, refresh, validate, or interpret Strawberry Shortcake source data from the WildBrain Wedia DAM. Use for properties, eras, characters, style guides, asset metadata, WildBrain fields, era hierarchy, character IDs, keywords, or asserted relationships.
disable-model-invocation: true
---

# Strawberry Shortcake (WildBrain DAM) scrape

Portal: `https://dam.wildbrain.com/dam/wedia/`. Vendor platform is **Wedia**, so
everything here transfers to any other Wedia DAM.

Extract lives in `u2giants/licensor-source-data` under `wildbrain/`. Read
`wildbrain/README.md` before using or extending the data.


## Refreshing this capture (incremental runs)

Style guides change after a capture: guides get added, art is replaced in place under the
same file name, and assets are withdrawn. Any refresh, re-scrape, delta or "what's new
since last time" request on Strawberry Shortcake / WildBrain runs under the shared
**`licensor-incremental-capture`** skill. Load it - it owns the bookmark format, the diff,
the safety gates and the withdrawn-asset ruling. This skill still owns the endpoints,
entitlement rules and field names below.

Two things specific to Strawberry Shortcake / WildBrain:

- **Change signal:** the Wedia record's own modified/updated field where present, else file size (medium)
- **Re-index in full** from the authorized era and keyword listings on every run. Indexing is metadata-only and
  cheap; only the detail fetches are skipped for rows whose signal has not moved.

Never treat a run timestamp alone as the bookmark, and never let a short or failed index be
read as the licensor withdrawing assets. The gates in the shared skill exist because that
failure silently destroys data.

## Run the scraper, do not hand-crawl

The capture is already built and tested. Use it.

```bash
op run --env-file wildbrain/.env.op -- npm --prefix wildbrain run scrape
```

| Command | What it does |
|---|---|
| `npm --prefix wildbrain run scrape` | Full capture (needs the `op run` wrapper) |
| `npm --prefix wildbrain run derive` | Rebuild `derived/` from `raw/`; no portal, no browser |
| `npm --prefix wildbrain test` | 21 unit tests over the parsing and the guards |

Code: `wildbrain/scripts/lib.mjs` (pure, tested) and `wildbrain/scripts/scrape.mjs`
(Playwright login plus REST capture). `scripts/crawl.js` in this skill is the raw
browser-console equivalent, kept only for probing a Wedia portal that has no scraper yet.

The run **fails loudly** instead of writing a partial file: `verifyCapture` rejects
duplicate asset IDs, a count short of the portal's own total, and truncated character
lists.

## Access

Credentials: 1Password vault `vibe_coding`, item
**"Strawberry Shortcake licensor style guide website for scrape"**
(`larevalo@popcre.com`). The scraper reads them through `op run`; they are never stored
in the repo.

On the sign-in page the email/password form is hidden until **"Show more options"** is
clicked, and the page is a Vue app that renders nothing at `domcontentloaded` — wait for
the control, never probe-and-skip. Do **not** use "Connect with WildBrain SSO"; that path
is for WildBrain staff and fails for the licensee account.

Session cookies are `httpOnly`, so `document.cookie` is empty and the session cannot be
exported to curl or a shell script. Capture must run inside a browser context.

Read-only. Never click Save, Upload, Submit, Delete, share, or cart controls, and never
change portal settings.

## The REST API

The Vue front end is backed by a clean REST API on the same origin:

```
/api/rest/dam/asset                 assets
/api/rest/dam/asset/headers         full field schema
/api/rest/dam/data/<dictionary>     controlled vocabularies
```

Always append `&lang=en&x-context=portal&headers=false`. Responses are
`{ resource, name, response: { data: [...], total, count } }`.

### The pagination trap

**Every offset parameter is silently ignored.** `start`, `first`, `offset`, `from`,
`page` and `skip` are all accepted, all return HTTP 200, and all return page one. `max`
is capped at 200 whatever you ask for. A naive pager collects the same 200 rows forever,
reports a healthy count, and looks like it worked. This cost an hour on 2026-08-18 and
produced a file with 2,400 "rows" and 200 unique records.

Page by ID, and **verify unique IDs, never row count**:

```
{"and":[{"activated":true},{"id":{"gt":<last id seen>}}]}   with &orderby=id
```

Only `gt` works; `>` and `$gt` both return `400 JSON Query syntax error`. This applies to
dictionaries too — the character dictionary returns 200 per page but holds 217 entries.

## The data model

Fields are prefixed `wil` (WildBrain).

| Field | UI label | Meaning |
|---|---|---|
| `wiluniverse` | Universe | `Content Sales` vs `Franchise Creative` |
| `wilera` | Franchise / Era | **The property.** A tree, via `parentobject` |
| `wilcreative` | Guides | Guide *kind*: Style / Seasonal / Trend / Packaging |
| `wilassetcatfranchise` | Franchise Asset Category | What the file is |
| `wilcharactername` | Character Name | Multi-valued character list |
| `wilkeywords` | Keywords | Free text; **holds the style guide name** |
| `wilbrand`, `wilfranchise` | Brand, Franchise | Content Sales only; **always empty** on licensee assets |

Two traps worth stating plainly:

- **`wilbrand` is not the property.** It is empty on all 2,287 licensee assets.
  Filtering on it returns zero and looks like an access problem. Use `wilera`.
- **There is no style guide object.** No ID, no record, no parent link. A
  guide's identity is a comma-separated string in `wilkeywords` that also
  contains a status token (`Active`, `Live`). Strip the status tokens and group
  on the remainder. Everything guide-shaped is reconstructed, not read.

## Scope reality

The licensee account sees **one property**: all assets are
`Strawberry Shortcake: Classic`. The dictionaries expose 116 brands, 6
franchises and 217 characters spanning Peanuts, Teletubbies, Degrassi and
others — **none of it licensed to us and none of it backed by reachable
assets.** Keep dictionaries for ID resolution and scope proof. Never present
non-SSC dictionary rows as an extract, and never load them as Master Data.

Eras `Strawberry Shortcake: 2003`, `: Berry in the Big City` and `: Bitty` exist
in the dictionary with zero assets behind them.

## Asserted vs inferred

State this every time the data is used, the same way the Disney extract does.

**Asserted by WildBrain — loadable as fact:** era → parent era; asset → era
(single-valued); asset → characters; asset → guide kind / category / file type;
and therefore **property → character**.

Property → character is safe **here** and was not safe on Disney DCP Vault. DCP
Vault carried independent property and character arrays on one asset, so pairing
them fabricated links. WildBrain gives each asset exactly one era plus a
character list, so the pairing is unambiguous.

**Inferred by us — needs a human ruling before Master Data:** style guide →
character; style guide → asset category; character → character. Also, for the
178 characters with no SSC assets, we have **no** evidence of what property they
belong to — the character dictionary is flat and carries only a name.

## Known defects in WildBrain's own data

Normalise these in any loader; do not silently "fix" them in the raw capture.

- Case-variant duplicate guides (`World of...` vs `world of...`).
- `Painted Characters Graphic Supplement` vs
  `Painted Character Graphics Supplement` — probably one guide, 291 assets.
- Typos: `Straberry Shortcake`; `Galentines Day` vs `Galentine's Day`.
- Junk keywords in production: `test`, `Activecus`.
- **9 character IDs on assets are absent from the dictionary** (216–222, 225,
  226). Several are lowercase or misspelled twins of dictionary entries that do
  exist. **Resolve by ID, never by name** — the names collide.
- 208 assets carry no guide keyword and cannot be attributed to any guide.

## Files and database are both kept, and differ on purpose

The capture was copied into Supabase, not moved. Query the database for working
answers; keep `raw/` because it is the only thing that rebuilds the database without
re-scraping the portal.

The database holds LESS than the files: it excludes every dictionary entry belonging
to WildBrain's other, unlicensed IP (116 brands, 6 franchises, and most of the 217
characters and 28 eras). That is a scope rule, not an omission. Everything about the
licensed property is loaded. Do not "fix" the gap by loading the rest.

`derived/guide-character.tsv` has no table: guide-to-character is derived through the
assets, so it is a join, not a stored fact.

## Owner rulings — read before touching the guide layer

Guide identity is reconstructed from free text, so where that text is wrong only the
owner can rule. The rulings live in `wildbrain/guide-rulings.json` as DATA, with who
ruled and when. To change one, edit that file and re-load — never edit the loader.

Ruled 2026-08-19 (Albert Hazan): two guide spellings the licensor used for the same
guide are merged (291 assets), and two junk keywords are dropped. Counts moved
34 → 31 guides, 37 → 35 spellings, 2,168 → 2,166 asset links.

The rulings file gates the load and feeds `source_commit_sha`, so a re-load after a
new ruling is a NEW capture rather than a key collision with the old reading.

`derived/` is deliberately NOT ruled — it stays faithful to what the portal literally
says. `derived/guides.tsv` showing more guides than the database is expected, not drift.

## Landing it in Supabase

**Done.** Schema shipped as shared-db #1197 (migrations `20260819014639` +
`20260819112524`) and is applied to preview and production. The extract was loaded
2026-08-19 into both; receipts are in `wildbrain/load-receipts/`.

```bash
op run --env-file wildbrain/.env.op -- npm --prefix wildbrain run load:preview
op run --env-file wildbrain/.env.op -- npm --prefix wildbrain run load:production
```

The loader (`wildbrain/scripts/load-supabase.mjs`) writes ROWS only, through
`plm.begin_wildbrain_capture` / `plm.finalize_wildbrain_capture`. It refuses to load an
uncommitted capture, refuses to write without naming the database first, and the
database rejects any capture whose counts or endpoints disagree. Tables are append-only
and capture-scoped: a re-load adds a snapshot, it never overwrites one.

Never write shared-DB structure from this repo, and never copy licensed rows into
`shared-db`, its migrations, its tests, or an issue body.

## Finishing

Rebuild `derived/` with `npm --prefix wildbrain run derive`; never hand-edit it. Record
capture date, account, and the scope limit as provenance. This is a
point-in-time snapshot, not a change feed.

Licensed rows stay in the private repo. Never copy them into `shared-db`, which
may hold only a pointer.
