---
name: sesame-workshop-scrape
description: Capture, refresh, validate, or interpret Sesame Workshop source data from the NetX TheLetterA portal. Use for Sesame brands, characters, style guides, art styles, asset metadata, NetX fields, category or asset IDs, and asserted relationships.
disable-model-invocation: true
---

# Sesame Workshop "TheLetterA" portal


## Refreshing this capture (incremental runs)

Style guides change after a capture: guides get added, art is replaced in place under the
same file name, and assets are withdrawn. Any refresh, re-scrape, delta or "what's new
since last time" request on Sesame Workshop runs under the shared
**`licensor-incremental-capture`** skill. Load it - it owns the bookmark format, the diff,
the safety gates and the withdrawn-asset ruling. This skill still owns the endpoints,
entitlement rules and field names below.

Two things specific to Sesame Workshop:

- **Change signal:** the NetX record's own modified/updated field where present, else file
  size (medium - an in-place art replacement may be missed if NetX does not restamp it).
- **Re-index in full** from the authorized NetX category listings on every run. Indexing is
  metadata-only and cheap; only the detail fetches are skipped for rows whose signal has
  not moved.

Never treat a run timestamp alone as the bookmark, and never let a short or failed index be
read as the licensor withdrawing assets. The gates in the shared skill exist because that
failure silently destroys data.

## Where everything lives

| Thing | Where |
|---|---|
| Extract, scraper, analysis | `C:\repos\licensor-source-data\sesame\` |
| Credentials | 1Password, vault `vibe_coding`, item **"sesame street licensor style guide website for scrape"** |
| Portal | https://sesameworkshop.netx.net/portals/thelettera/ |
| Extract rules | `C:\repos\licensor-source-data\README.md` — read before writing anything |

This is licensor-confidential material under a commercial licence. Never make
the repo public, never copy the data into `shared-db`, never send it to a
third-party service.

## Logging in

The login page defaults to SSO. **Click "Show more options" and use the
username/password form. Do NOT use "Connect with WildBrain SSO"** — the same
credentials do not work there.

## The API (this is how to scrape it, not by clicking)

The portal is a **NetX DAM**. Its browser app talks JSON-RPC to
`https://sesameworkshop.netx.net/x7/v1.2/json/<method>`, and **the first
parameter of every call is the logged-in session key**:

```json
{"id":1,"dataContext":"json","jsonrpc":"2.0",
 "method":"facetedSearch","params":["<SESSION>", ...]}
```

That session key is all the authentication needed — no cookie, no header. It
works from curl or Python once you have it.

**Getting the session key:** log in in a browser, then read `params[0]` from any
`/x7/v1.2/json/` request the page makes. In the Claude browser tools, hook
`fetch`/`XMLHttpRequest` before navigating and read a recorded request body.

Methods that matter:

| Method | Params after session | Returns |
|---|---|---|
| `getCategories` | `"", parentId` | Immediate children. Root is `1` |
| `getAttributeTemplates` | none | All 117 field definitions |
| `facetedSearch` | `"file",0,0,[23],[2],[0],[catId],[""],[""],page,pageSize,[],"hybrid",1` | Assets in one category, plus facet counts |
| `getSelf` | none | The logged-in account |

**`facetedSearch` is NOT recursive.** A parent category returns `size: 0` even
when its children hold thousands of assets. You must walk every node of the
tree. `getChoiceList` returns empty here — the controlled vocabularies come from
facets and from the values on assets, not from that call.

## Running it

```bash
cd C:\repos\licensor-source-data\sesame
SESAME_SESSION=<session key> python scrape.py    # ~25 min, resumable
python analyze.py                                 # rebuilds derived/
```

`scrape.py` checkpoints each finished category in `raw/.progress.json` and skips
assets already in `raw/assets.jsonl`, so an interrupted run resumes. An expired
session raises loudly rather than writing empty files.

Never commit the session key or the password.

## What the portal contains (capture of 2026-08-18)

10,220 assets across 427 categories, one licensee account.

Two parallel structures describe the same assets:

1. **Folders** — a real 427-node tree. Six sections: What's New, Illustrations
   and Art Style Guides, Photography, Consumer Goods Guides & Resources, Visual
   Identity Guides & Resources, Marketing Campaigns. Individual style guides are
   folders inside them (47 at that level).
2. **Fields on the asset** — where the licensing meaning actually lives.

| Portal field | Meaning | Distinct values | Filled |
|---|---|---|---|
| `Brand NEW` | **The property** | 25 | 9,176 |
| `SubBrand NEW` | Sub-property | 2 | 29 |
| `Character` | Character | 104 | 6,621 |
| `Style Guide` | **Style guide** | 130 | 9,382 |
| `Art Style NEW` | Visual family a guide belongs to | 20+ | 8,484 |
| `Asset Type NEW` | What the file is, colon-nested | 36 | 9,572 |
| `Usage Rights` / `Restriction Types` / `Usage Terms` | Licensing restrictions | — | 8,777 / 1,374 / 1,552 |

The 25 brands are Sesame Street plus every international co-production
(Ahlan Simsim, Galli Galli Sim Sim, Plaza Sesamo, Takalani Sesame, Zhima Jie…).

### Three traps that will bite

1. **Old and new fields sit side by side.** `Brand` vs `Brand NEW`,
   `Character OLD` vs `Character`, `Theme` vs `Theme NEW`, `SubBrand` vs
   `SubBrand NEW`. The `NEW` ones are curated and proper-cased; the old ones are
   lowercase free text with different value sets. **Use the NEW fields.**
   Exception: `Style Guide` has no NEW twin and is lowercase.
2. **Multi-valued fields come back CSV-quoted inside one string:**
   `"Bert","Ernie","Groups"`. A single value comes back bare with no quotes.
   Parse with a CSV reader, and never write that raw string into a TSV cell —
   the quoting collides and silently mangles the data.
3. **Not every asset has a property.** 1,044 assets carry no brand, 838 no style
   guide. Do not assume the field is always there.

## Asserted versus inferred — the rule for this portal

- **Asset → brand / character / style guide / art style / asset type: ASSERTED.**
  These are fields on the asset record.
- **Style guide → character: ASSERTED, with an exclusion.** Only from assets
  carrying exactly one style guide (5,680 of them). Assets carrying two or more
  guides cannot be split; 1,165 character rows behind them are excluded, not
  guessed. See `derived/style-guide-character.tsv`.
- **Brand → character: INFERRED.** The portal never states which characters
  belong to which brand. `derived/INFERRED-brand-character.tsv` only counts
  values that happen to share an asset. Never load it as fact. The filename
  carries the warning on purpose.
- **There is no property→character list anywhere in this portal.** Unlike Disney
  OPA, which asserts it directly, here the only route is through assets. If
  someone asks for Sesame's character roster per brand, say that it is derived.

## Database landing

The schema for landing this extract is requested through the shared-db
orchestrator, never authored from this repo. Structure changes to the shared
database go through `u2giants/shared-db` first (branch + PR), per the
`shared-db-change` skill. Row data produced by a scrape is the scraping
session's own to write, but the tables it lands in are not.
