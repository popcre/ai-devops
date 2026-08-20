---
name: peanuts-portal-is-tenovos
description: The Peanuts licensor portal is a Tenovos DAM with a flat taxonomy and a field-label trap; the 1Password entry once pointed at the wrong portal.
metadata: 
  node_type: memory
  type: project
  originSessionId: 76637b40-caaf-4d0b-8f36-abbdc0a4d663
  modified: 2026-08-19T02:05:02.272Z
---

The Peanuts/Snoopy licensee portal is `peanuts.enterprise.app.tenovos.io`, a
**Tenovos** DAM — not a NetX or Wedia portal. Its 1Password entry ("peanuts
snoopy licensor style guide website for scrape", vault `vibe_coding`) carried the
**Sesame Workshop NetX URL by mistake** until 2026-08-19; Albert corrected it.
Sesame has its own separate entry. If a Peanuts URL ever looks like
sesameworkshop.netx.net again, it is the same mix-up.

The portal's internal metadata field `property` is labelled **"Art Program"** in
the UI, and `program` is labelled **"Initiative"**. A Peanuts "Art Program" is an
art-style/era bucket, not a franchise — the whole portal is one franchise. Any
mapping that reads `property` as our master-data "property" is wrong.

As of 2026-08-19 Peanuts is **captured and loaded**, not just tabled: capture
`peanuts-2026-08-19-...` is `complete` in `plm.peanuts_*` with 22,463 assets,
37,238 asset-character links and 12,935 relationship edges. So Peanuts is
genuinely queryable, unlike Paramount and Sesame
([[paramount-and-sesame-not-in-database]]).

Two portal quirks that will confuse anyone who checks the numbers: the portal's
own asset total is **short by two** (metadata-only records the default search does
not count), and ~2,835 relationship edges are deliberately not loaded because they
point at superseded asset versions or are self-referencing. Both counts are
recorded on the capture row itself in `raw_summary`.

Full operating detail is in the `peanuts-scrape` skill; the extract, scraper and
loader are in `licensor-source-data` under `peanuts/`. Schema:
u2giants/shared-db#1217 (built, applied, closed).
