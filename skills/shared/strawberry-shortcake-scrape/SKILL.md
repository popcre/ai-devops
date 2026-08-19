---
name: strawberry-shortcake-scrape
description: Capture, refresh, validate, or interpret Strawberry Shortcake licensed source data from the WildBrain DAM (dam.wildbrain.com, a Wedia portal). Use when asked to scrape, re-scrape, inspect, reconcile, or load WildBrain / Strawberry Shortcake properties, eras, characters, style guides, or asset metadata; when a question depends on WildBrain's field names, era hierarchy, character IDs, or keyword-based style guides; or when deciding which WildBrain relationships are licensor-asserted versus inferred.
---

# Strawberry Shortcake (WildBrain DAM) scrape

Portal: `https://dam.wildbrain.com/dam/wedia/`. Vendor platform is **Wedia**, so
everything here transfers to any other Wedia DAM.

Extract lives in `u2giants/licensor-source-data` under `wildbrain/`. Read
`wildbrain/README.md` before using or extending the data.

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

## Landing it in Supabase

Schema request: **u2giants/shared-db#1197** — 11 `plm.wildbrain_*` tables plus 2
functions, append-only and capture-scoped. The `shared-db` orchestrator owns it. Never
write shared-DB structure from this repo, and never copy licensed rows into `shared-db`,
its migrations, its tests, or an issue body.

## Finishing

Rebuild `derived/` with `npm --prefix wildbrain run derive`; never hand-edit it. Record
capture date, account, and the scope limit as provenance. This is a
point-in-time snapshot, not a change feed.

Licensed rows stay in the private repo. Never copy them into `shared-db`, which
may hold only a pointer.
