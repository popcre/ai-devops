---
name: disney-dcpvault-asset-crawl
description: Crawl Disney's DCP Vault art library (dcpvault.disney.com) for style guide and asset file paths, and per-asset metadata, through the user's own logged-in Chrome. Use when asked to scrape, resume, refresh, or repair the Disney DCP Vault extract, when a DCP Vault crawl has stalled or reported sections as empty, or when the work involves Disney style guides, art files, collectionDmcId, or the disney-dcpvault folder. ALSO use for ANY long-running in-browser crawl driven from an AI session — the resilience rules here (page-depth ceilings, frozen background tabs, never starting a second loop, hung requests with no timeout, and sign-in pages misread as zero results) were each learned by losing hours to them.
---

# Disney DCP Vault asset crawl

**DCP Vault** = Disney Consumer Products Vault, `https://dcpvault.disney.com`.
Disney's art and style-guide library for licensees. It runs **Adobe Asset Share
Commons on AEM**, so every result card in the HTML carries
`data-asset-share-asset="<dam_path>"`. That attribute is the extract.

**Not to be confused with OPA** (`opa.disney.com`), the product-approval portal —
different site, different login, different data. Use `disney_opa_character_scrape`
for that one. A session has already wasted a login cycle confusing the two.

**All output goes to the PRIVATE repo `u2giants/licensor-source-data`, folder
`disney-dcpvault/`. Never to `u2giants/shared-db`.**

---

## 0. The five failures that cost hours. Read before writing any crawl code.

Every one of these was hit for real on 2026-08-07/09. None is theoretical.

### 0.1 🔴 A background Chrome tab gets FROZEN, and looks exactly like a hang

Chrome freezes background tabs after a few minutes. Timers stop, `fetch` never
resolves, and **your request-timeout code cannot fire because it is frozen too.**
The crawl looks alive (`running === true`) and does nothing for 40 minutes.

- **The crawl tab must be VISIBLE: its own Chrome window, not minimized, with the
  crawl tab selected.** It may sit behind other windows. This is the only reliable
  fix and it needs the owner to do it once.
- The silent-audio keepalive trick **does not work unprompted** —
  `AudioContext` starts `suspended` and needs a real user gesture. Do not rely on it.
- **Install a heartbeat** so a freeze is visible as a freeze:
  `setInterval(()=>{window.__beat++},10000)`. A stalled beat counter proves the tab
  froze; a moving one proves the problem is elsewhere.

### 0.2 🔴 NEVER start a second loop because the first "looks dead"

A frozen loop is asleep, not dead. When the tab thaws, **both loops run**, both
advance the queue index, and **a section gets stepped over and recorded as
finished while holding nothing.** This happened; `pixar|Style Guides` was skipped.

- Before starting a loop, always `C.running = false` **and confirm the old one
  actually exited** (watch the request counter stop moving) — do not assume.
- Audit afterwards: a job key appearing **twice** in the DONE log means the index
  advanced twice. Check what sat between them.
- Keep the audit cheap by logging one `DONE <section>|<label> end~<count>` line per
  finished job. Without those counts none of this is detectable.

### 0.3 🔴 Disney's search CANNOT page past ~80,000 results

Beyond roughly offset 80,000 the query fails with `503` **at any page size,
including `p.limit=1`.** It is a depth ceiling, not server strain, not the end of
the section. Patience does not help; smaller pages do not help.

**The fix: sweep the same result set in the opposite order** so the tail is reached
at shallow offsets. Add an explicit sort to the query
(`orderby=@jcr:content/metadata/releaseDate&orderby.sort=asc`) and crawl from
offset 0. Two sweeps from opposite ends cover the whole section.

**Prove they met.** Stop the reverse sweep after **3 consecutive pages with zero new
paths** and record that as the proof of coverage. Without the overlap check you have
two half-sweeps and an assumption.

### 0.4 🔴 A page containing the words "sign in" is NOT a sign-out page

A normal results page carries "Sign In" in its header furniture. A naive
`/sign-?in/i` test rejects perfectly good pages — it stopped a crawl that had just
received 600 records.

**Only a response with ZERO records can be a sign-out**, and then it must also be
tiny (<5 KB) or carry an actual `<form … password>` / `myid.disney` / `SAMLRequest`.

```js
window.__authFail = function(status, txt, foundCount){
  if(status===401||status===403) return 'HTTP'+status;
  if(foundCount>0) return null;                       // records = real page, always
  if(txt.length<5000) return 'tiny body, 0 records';
  if(/myid\.disney|SAMLRequest|<form[^>]+password/i.test(txt)) return 'login form, 0 records';
  return null;                                        // a genuinely empty section is allowed
};
```

**And the inverse, which is worse:** a real sign-out returns HTTP 200 with a 1,920
byte page and zero cards. A crawl without this guard reads that as "this section is
empty", marks 17 sections done, and reports success holding nothing. **Pixar is
never empty.** If a big-name section returns zero, suspect yourself first.

### 0.5 🔴 A request that HANGS is neither success nor failure

`fetch` has no default timeout. One request that never returns stalls the entire
crawl silently — no error, no retry, no log line.

Give every request a hard deadline and treat a timeout as a normal retry:

```js
window.__fetchT = async function(url, ms){
  const ac = new AbortController();
  const t = setTimeout(()=>ac.abort(), ms);
  try { return await fetch(url, {credentials:'include', signal: ac.signal}); }
  finally { clearTimeout(t); }
};
```

Shrink the page size after a timeout — it usually means the request was too big.

### 0.6 The original sin, still worth restating

**Never treat a failed request as "end of list".** That silently truncated a section
at offset 24,900 and reported a clean finish. If a request truly cannot be
completed, push an explicit entry to `C.gaps` and move on **loudly**. A crawl that
stops early records a gap; it never reports success.

---

## 1. Politeness — the owner's standing instruction

> *"don't get us locked out. if you think they are throttling us because they think
> we're scraping, then slow down"*

- Settled working values: **`p.limit=100`, 30s between requests, 3min rest every 15
  requests, 15 retries with backoff capped at 90s, 120s request deadline.**
- **Adaptive page size:** halve on `503` or timeout, floor 25; double back toward 100
  after 25 clean requests.
- **`503` is server strain — back off and retry. `403`, `429`, or a real login
  redirect is a block — STOP and tell the owner.**
- **One crawl at a time.** Never run the path crawl and the metadata crawl together.
- **Names and metadata only.** Never download artwork, PDFs, or style-guide
  documents. If you believe you cannot get names without downloading, stop and say so.

---

## 2. Two phases

### Phase 1 — asset paths (the search crawl)

Walk each section's search results and harvest `data-asset-share-asset`. Sections
are crawled twice, once for **Assets** and once for **Style Guides**.

The folder path itself encodes most of the useful data:

```
/content/dam/dcp-vault/merchandise/north-america/2026/
   2990862-mickey-and-friends-gen-z-...-style-guide/character-art/2990862_ca116.ai
   └── region ──┘ └yr┘ └─ guide id ─┘└──── guide name ────┘ └ category ┘ └ file ┘
```

**Style guide ids come in three shapes and a third do not exist at all:**

| Shape | Example | Note |
|---|---|---|
| Numeric | `2990862-` | 6–7 digits. Disney's own id — files inside repeat it |
| Regional code | `cseu712-`, `apac072-`, `aw15-` | 2–5 letters + 2–4 digits |
| **None** | `hercules-style-guide-01-aug-17` | **654 folders.** Nullable text; a name is NEVER an id |

Regex that matches the real ids and nothing else:
`/^(\d{6,7}|[a-z]{2,5}\d{2,4})-/` — a looser `\d+` wrongly captures `101-dalmatians`
and `90-…` as ids.

### Phase 2 — per-asset metadata (the links)

`GET <dam_path>/jcr:content/metadata.json` with `credentials:'include'` returns ~50
fields in **3 KB / ~125 ms**, against a search page's 1.5 MB / 25 s. It is ~500×
smaller and ~200× lighter on Disney's servers.

Fields worth capturing: `character[]`, `properties[]`, `collectionMainTitle`,
`collectionDmcId`, `UUID`, `dam:sha1`, `artStyle[]`, `keyword[]`, `designElement`,
`contentType`, `releaseDate`, `dam:size`, and `isExclusive` / `isEmbargoed` /
`status` / `isLocked` (these may restrict usage — ask the licensing contact).

**Done when every path has either a metadata record or an explicitly recorded
failure. A path with neither is a silent gap.**

---

## 3. 🔴 Two data rules that override the obvious reading

### 3.1 NEVER pair `properties[]` with `character[]`

They are **two independent arrays**. Nothing links a member of one to a member of
the other. Proven directly:

| Asset | Properties | Characters |
|---|---|---|
| `cseu089013.ai` | **9** properties | **1** character (`minnie-mouse`) |
| `apac144001.ai` | `chip-n-dale`, `mickey-mouse-standard-character` | `mickey-mouse`, `minnie-mouse` — **neither chipmunk** |

Pairing them fabricates relationships Disney never asserted. Record
`links-asset-property` and `links-asset-character` **separately, never joined**.
The property↔character relationship comes from **OPA only**, where every character
node carries its own `licensedPropertyID` (verified across all 10,263 pairs).

### 3.2 `collectionDmcId` is a PER-ASSET id, not the style guide id

Three files in the **same** folder returned `0901d63682adf0e6`, `0b01d63682adf0a1`,
`0901d63682adf152`; reproduced in a second folder. It is near-sequential within a
folder, which is exactly why it looks like a folder id. **It does not fill
`style_guide_source_id` and does not rescue the 654 id-less folders.**

Also: **never read a character out of a file name or folder name.** An asset in a
folder named `zazu` had no `character` field at all. Separately, 30 product records
were once mislabelled Disney because the letters `DS` appeared inside an unrelated
SKU.

---

## 4. Endpoints that are BLOCKED — do not spend requests on them

| Endpoint | Result |
|---|---|
| AEM QueryBuilder JSON `/bin/querybuilder.json?…` | **hangs forever**, no response, no error |
| DAM folder listing `….1.json` | **404** at every level |
| Tag vocabulary `/content/cq:tags/dcpvault/characters.1.json` | **404** |

Get characters from per-asset metadata instead (§2, Phase 2).

---

## 5. Surviving the session — state, saving, resuming

**Crawl state lives in page memory and dies with the tab.** Assume you will lose it.

- **Save to disk every 5 requests**, not at milestones. A previous session held
  45,738 paths in browser memory for three hours and only survived by luck.
- Serving large state through the JS bridge is impractical. **Run a tiny local
  HTTP server** with `Access-Control-Allow-Origin: *` on `127.0.0.1`, and have the
  page `fetch` its restore data and `POST` its saves. The browser must be on the
  same machine as the session.
- **When rebuilding the queue on resume, reproduce it EXACTLY** — same drops, same
  inserted reverse-sweep jobs, in the same positions — then assert the current index
  still names the job you expect before starting. A queue rebuilt one entry off will
  crawl the wrong section and look fine.

**Tooling traps:**
- The Chrome JS bridge refuses to return output containing URL query strings. Return
  only the fields you need; never return raw markup or a full URL.
- A long `fetch` exceeds the ~45s evaluate limit. Kick it off writing to a global,
  return immediately, then poll that global in a later call.
- `computer` `wait` maxes out at 10 seconds. For longer waits use a backgrounded
  `sleep` via Bash.

---

## 6. Credentials and confidentiality

- **The owner signs in himself, in his own Chrome, and completes MFA himself.** Never
  ask for a password, never type into a password or MFA field, never read or print
  cookies, tokens, storage, or raw network events.
- **The portal is read-only.** Never click Save, Submit, Approve, Accept or Finish;
  never accept terms; cancel dialogs you open.
- **Everything captured is Disney confidential** under a commercial licensing
  agreement. It goes to `u2giants/licensor-source-data` (private) and nowhere else —
  no pastebins, no third-party AI services, no file-sharing links, and **never
  `u2giants/shared-db`**, which is intended to become public.
- **Scope every extract:** this is *the point-in-time catalogue visible to this
  licensed account*, not Disney's complete catalogue. A name missing from the extract
  is an open question, never proof it does not exist.

---

## 7. Before reporting a crawl finished

Check all of these. Each one has been wrong at least once.

- [ ] `gaps` is **empty** (or every gap is explicitly listed and accepted by the owner)
- [ ] Every job in the queue has a `DONE … end~<n>` line **or** an `OVERLAP MET` line
- [ ] **No job key appears twice** in the DONE log — a duplicate means a skipped section
- [ ] **No section that should be large returned zero.** If one did, suspect a sign-out
- [ ] Any section that hit the depth ceiling has a **confirmed reverse-sweep overlap**
- [ ] Row count equals distinct `dam_path`; the last CSV line is a complete record
- [ ] The README states the capture date, filters, entitlement scope, and a
      **"what we tried that did NOT work"** table
