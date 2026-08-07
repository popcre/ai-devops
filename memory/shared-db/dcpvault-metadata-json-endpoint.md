---
name: dcpvault-metadata-json-endpoint
description: "DCP Vault per-asset metadata.json gives Disney's own character/property ids in 3KB/125ms; querybuilder, folder listing and tag endpoints are all blocked"
metadata: 
  node_type: memory
  type: reference
  originSessionId: de76a67a-4798-4743-a242-1318157de631
  modified: 2026-08-07T16:24:46.409Z
---

Disney DCP Vault (`dcpvault.disney.com`) runs **Adobe Asset Share Commons** on
AEM. Result cards carry `data-asset-share-asset` holding the full DAM path.

**The endpoint that matters:**
`GET <dam_path>/jcr:content/metadata.json` with `credentials:'include'` —
**3 KB, ~125 ms**, versus 1.5 MB / 25 s for a search-results page.

Returns Disney's **own stable ids**, not display names:
`character[]` (`dcpvault:characters/da/dale`), `properties[]`
(`dcpvault:properties/mi/mickey-in-real-life`), `collectionMainTitle` (style
guide name), `collectionDmcId`, `artStyle[]`, `keyword[]`, `designElement`,
`dam:size`, `releaseDate`, `dam:sha1`, and `isExclusive`/`isEmbargoed`/`status`
(may carry usage restrictions — unverified).

**Blocked, do not retry:** `/bin/querybuilder.json` (hangs forever, no error),
DAM folder listing `….1.json` (404), tag vocabulary
`/content/cq:tags/dcpvault/….json` (404). Only the exact per-asset path works,
so enumerating assets still requires crawling the search pages.

**Politeness that survived without a block:** `p.limit=150`, 9 s gap, 45 s rest
every 25 requests, retries with 20/40/60 s backoff. `p.limit=300` at a 1.2 s gap
drew **HTTP 503**. A 503 is server strain; a 403/429/login-redirect is a block —
stop and tell Albert. See [[licensor-data-never-in-shared-db]].
