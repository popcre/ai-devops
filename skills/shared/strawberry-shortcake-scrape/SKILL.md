---
name: strawberry-shortcake-scrape
description: Capture, refresh, validate, or interpret Strawberry Shortcake licensed source data from the WildBrain DAM (dam.wildbrain.com, a Wedia portal). Use when asked to scrape, re-scrape, inspect, reconcile, or load WildBrain / Strawberry Shortcake properties, eras, characters, style guides, or asset metadata; when a question depends on WildBrain's field names, era hierarchy, character IDs, or keyword-based style guides; or when deciding which WildBrain relationships are licensor-asserted versus inferred.
---

# Strawberry Shortcake (WildBrain DAM) scrape

Portal: `https://dam.wildbrain.com/dam/wedia/`. Vendor platform is **Wedia**, so
everything here transfers to any other Wedia DAM.

Extract lives in `u2giants/licensor-source-data` under `wildbrain/`. Read
`wildbrain/README.md` before using or extending the data.

## Access

Credentials: 1Password vault `vibe_coding`, item
**"Strawberry Shortcake licensor style guide website for scrape"**
(`larevalo@popcre.com`).

On the sign-in page click **"Show more options"** to reveal the email/password
form. Do **not** use "Connect with WildBrain SSO" — that path is for WildBrain
staff and will fail for the licensee account.

The user performs the login. Claude does not type passwords into web forms.
Session cookies are `httpOnly`, so `document.cookie` is empty and the session
cannot be exported to curl or a shell script. **The whole crawl must run inside
the authenticated browser tab** via the browser MCP's `javascript_tool`.

Read-only. Never click Save, Upload, Submit, Delete, share, or cart controls,
and never change portal settings.

## Use the REST API, not the rendered pages

The Vue front end is backed by a clean REST API on the same origin. Hitting it
from the logged-in tab is faster, complete, and far less fragile than clicking.

```
/api/rest/dam/asset                 assets
/api/rest/dam/asset/headers         full field schema (start here)
/api/rest/dam/data/<dictionary>     controlled vocabularies
```

Always append `&lang=en&x-context=portal&headers=false`. Responses are
`{ resource, name, response: { data: [...], total, count } }`.

### The pagination trap — read this before writing any loop

**Every offset parameter is silently ignored.** `start`, `first`, `offset`,
`from`, `page` and `skip` are all accepted, all return HTTP 200, and all return
page one. `max` is capped at 200 regardless of what you ask for. A naive pager
therefore collects the same 200 rows forever, reports a healthy row count, and
looks like it worked. This burned an hour on 2026-08-18 and produced a file with
2,400 "rows" and 200 unique records.

Page by ID instead, and **verify unique IDs, never row count**:

```js
{"and":[{"activated":true},{"id":{"gt":<last id seen>}}]}   // with &orderby=id
```

Only `gt` works. `>` and `$gt` both return `400 JSON Query syntax error`.
This applies to dictionaries too — `wilcharactername` returns 200 per page but
actually holds 217 entries.

### Getting data out of the browser

`fetch` to `http://127.0.0.1:<port>` is blocked (mixed content from an HTTPS
page), so a local receiver does not work. Use a blob download:

```js
const a=document.createElement('a');
a.href=URL.createObjectURL(new Blob([text],{type:'text/plain'}));
a.download='ssc-assets.tsv'; document.body.appendChild(a); a.click(); a.remove();
```

Files land in the user's Downloads folder; move them into the repo from Bash.
Trigger **one download at a time and confirm it landed** — firing three in a row
produced `.tmp` files and one silent loss. Tell the user a download dialog is
coming, since it steals focus.

`scripts/crawl.js` is the whole capture, ready to paste into `javascript_tool`.

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

## Finishing

Re-run `wildbrain/analyze.py` to rebuild `derived/`; never hand-edit it. Record
capture date, account, and the scope limit as provenance. This is a
point-in-time snapshot, not a change feed.

Licensed rows stay in the private repo. Never copy them into `shared-db`, which
may hold only a pointer.
