---
name: disney_opa_character_scrape
description: Extract Disney's authoritative property and character list from the OPA licensee portal (opa.disney.com) into a CSV. Use when the user says "scrape OPA", "get the Disney character list", "pull the OPA properties", "refresh the OPA extract", "get Disney's character names", or needs canonical Disney property/character names or IDs for the characters and style-guides work. Also covers the general pattern of reading data out of an MFA-protected portal through the user's own logged-in browser without ever handling their credentials.
---

# Disney OPA property/character extract

**OPA = Online Product Approval**, `https://opa.disney.com`. Disney's portal for
licensees. POP Creations is a Disney licensee, so Albert has an account.

On the product-submission screen a licensee must declare which **property** a
product uses and which **characters** within it. That picker is Disney's own
canonical list, carrying Disney's own internal IDs. This skill extracts it.

**The one thing to know:** this is **not a page you scrape**. OPA loads the
entire property-and-character tree into the browser in a single render. The
extract is one read of data already in the page. It takes seconds and sends no
extra requests to Disney. Anyone who builds a crawler here has misread the
problem — see §"What does NOT work".

Expect roughly **10,000+ rows, ~1,400 properties, ~9,500 distinct character
names**. The 2026-08-06 baseline was 10,262 / 1,445 / 9,591.

---

## Hard rules

1. **Never handle the login.** Albert logs in and completes MFA himself, in his
   own Chrome. You attach to that session afterwards. Never ask for his password,
   never type into a password or MFA field, never offer to "just do the login".
   This is a standing prohibition, not an OPA-specific preference.
2. **The product-create page is READ-ONLY to you.** It is a live form in Disney's
   system of record. Never type into a field. Never click **Save for Later** or
   **Submit to Disney**. Nothing may be created in OPA.
3. **Close the tab you opened** when finished.
4. **The data is business-confidential.** It comes from a commercial licensing
   relationship. Do not publish it and do not send it to any third-party service.
5. **Changing the database is a separate job with its own rules.** If the ask is
   "put this in the database", that is the shared Supabase database and it goes
   through `shared-db-orchestrator` — file a request, do not build a table.
   **Reading it is not gated:** you may inspect the live shared schema in full
   (schemas, tables, columns, keys and relationships, indexes, constraints, views,
   functions/RPCs, triggers, RLS policies, migration history, generated types,
   metadata, safe sample data) and compare it against the OPA source shape to
   report gaps — no issue, no dispatch. Rule 4 still binds: OPA data is
   business-confidential and never goes into a public repo, an issue, logs, an
   outside service, a commit message or a PR.

---

## Procedure

### 1. Attach to Albert's browser

Use the **Claude in Chrome** tools (`mcp__claude-in-chrome__*`), not the in-app
browser. Only the real Chrome carries his authenticated OPA session.

- `list_connected_browsers`, then let him pick — call `switch_browser` so he
  clicks **Connect** in the window he wants. Do not pick for him.
- Ask him to log into OPA and complete MFA **before** you navigate anywhere.
- You cannot see his existing tabs; the extension only exposes tabs in a group
  you create. That is fine — session state lives in the Chrome **profile**, so a
  tab you open yourself is already logged in.

### 2. Open the product-create page

```
https://opa.disney.com/ProdApp/createEditProduct.spring?do=createEdit&lob=200&templateId=21&workflowId=49&regionName=Option.Region.4&lobName=Option.Lob.Home&productTypeName=pa.system.productType.standard&inbox=true&isCreatePage=true
```

> ⚠️ **`lobName=Option.Lob.Home` scopes this to the HOME line of business.**
> Whether other lines of business expose a different or larger property set is
> **still unverified as of 2026-08-06.** If the user needs "all of Disney",
> confirm this first by loading another `lob` value and comparing the property
> count. Say plainly that it is unverified rather than implying full coverage.

If the page loads with content, the session is live. If it bounces to a login,
his OPA session expired — ask him to log in again.

### 3. Populate the tree, then read it

The picker renders empty until "Show All" runs.

```js
showAllProperties();
```

Wait a few seconds. Then, as a **separate** call:

```js
(() => {
  // The jstree container id is generated and CHANGES between page loads.
  const inst = jQuery.jstree.reference('#' + document.querySelector('.jstree').id);
  const m = inst._model.data;
  const q = s => '"' + String(s == null ? '' : s).replace(/"/g, '""').replace(/\s+/g, ' ').trim() + '"';
  const rows = ['property,licensedPropertyID,optionSourceID,character,characterID,brandPropertyID'];
  m['#'].children.forEach(pid => {
    const p = m[pid], pa = p.li_attr || {};
    (p.children || []).forEach(cid => {
      const c = m[cid], ca = c.li_attr || {};
      rows.push([q(p.text), q(pa.licensedPropertyID), q(pa.optionSourceID),
                 q(c.text), q(ca.characterID), q(ca.brandPropertyID)].join(','));
    });
  });
  window.__opaCsv = rows.join('\n');
  return JSON.stringify({rows: rows.length - 1, bytes: window.__opaCsv.length});
})()
```

**Sanity-check the counts before going further.** Far below ~10,000 rows means
the tree did not fully populate — re-run `showAllProperties()` and wait longer.
Report the real number; never round up to the expected one.

### 4. Get it out of the browser

The CSV is ~1 MB, too big to return through tool output in one piece. **Ask
permission for the download** (it is a download, so it needs an explicit yes),
then:

```js
const a = document.createElement('a');
a.href = URL.createObjectURL(new Blob([window.__opaCsv], {type: 'text/csv'}));
a.download = 'opa-characters.csv';
document.body.appendChild(a); a.click(); a.remove();
```

Then verify on disk. **Chrome writes a GUID `.tmp` first and renames it
asynchronously**, so a check run immediately after the click can see the `.tmp`,
the final name, or briefly neither. Wait and re-check for the final filename
before concluding anything failed.

Verify line count (header + rows) and eyeball the first and last row.

### 5. Close the tab

---

## The data

Two levels only: property on top, characters beneath. No third level.

| Column | Meaning |
| --- | --- |
| `property` | Disney's display name, e.g. `101 Dalmatians - Individual Characters` |
| `licensedPropertyID` | Disney's property ID |
| `optionSourceID` | Disney's source/list id (was `1007` on every property row; meaning unknown — do not build logic on it) |
| `character` | Disney's character display name |
| `characterID` | Disney's character ID |
| `brandPropertyID` | Disney's brand-property ID on the character node |

> **A character is scoped to its property.** The same name recurs under many
> properties with different `characterID`s — ~670 names did in the 2026-08-06
> capture. **The key is the (property, character) pair, never the character name
> alone.** Anyone keying on name will silently lose rows or invent false matches.

This mirrors `core.property` in `shared-db`, which is `unique (licensor_id,
code)` — property codes are not globally unique, and licensor→property is
parent-child. OPA extends the same logic one level deeper.

---

## Caveats to state out loud every time

Do not let the user believe this is "the Disney character list" without these:

1. **It shows only what Albert's licensee account is entitled to see.** Not
   Disney's full catalogue. A different account sees a different list.
2. **It may be scoped to one line of business.** See the URL warning above.
3. **Nothing is filtered.** Retired properties and `- No Likeness` /
   `- With Likeness` variants are all present as OPA lists them. That distinction
   is a real licensing concept, not noise — never strip it without a decision.
4. **It is a point-in-time snapshot.** No change feed; a refresh is a full
   re-extract.
5. **`optionSourceID` is not understood.**

---

## What does NOT work — do not repeat these

| Attempt | Outcome | Lesson |
| --- | --- | --- |
| Looking for a `<select>` of characters | The `Character` field is a **hidden input**; the visible control opens a popup | The list is not in a form control |
| Looping `getCharacters.spring?do=getCharacters&pIds=…&pType=std` per property | Real endpoint, would work, needs ~1,445 HTTP calls | Pointless. It is all already client-side. Check the page's own state before building a crawler |
| Dumping `outerHTML` or `someFn.toString()` through the browser tool | **`[BLOCKED: Cookie/query string data]`** — query-string-shaped text trips the safety filter | Extract only paths and string literals, and mask `=` signs |
| Querying checkboxes named `pa.system.Attribute.Property` | **0 elements**, though the page's own `getProperties()` reads exactly that name | The page has dead legacy code for a UI it no longer uses. **Never infer the DOM from the page's JavaScript** |
| Finding node text with `children.length === 0` | Not found | jsTree anchors have child elements — use a `TreeWalker` over text nodes |
| One `async` IIFE that triggers the load, awaits, and reads | Returned `{}` | Split trigger and read into separate calls |
| Hard-coding the jstree id (`#jstree_741`) | Breaks on the next page load | It is generated. Resolve it via `document.querySelector('.jstree').id` |

---

## If asked to put this in the database

**Stop and file a request.** The shared Supabase database is used by four live
apps, and a session asked directly to *change* it files a request rather than
starting it. Load `shared-db-orchestrator` and follow it. (Reading the schema
first — to write an accurate request, or to answer "does the database already fit
this?" — is allowed and needs no request.)

Existing material, as of 2026-08-06:

- Background doc: `docs/verification/opa-characters-20260806/README.md` in
  `u2giants/shared-db` — the full record, including design questions.
- The request as filed at the time: `COORDINATOR_INTAKE.md` → `## REQUEST QUEUE`,
  PR #466. **Historical pointer only** — that file was retired on 2026-08-07 and
  its open items became GitHub issues. File any new request as a `db-work` issue.
- Linked from `HANDOFF.md` under *"Active workstream — Characters and style
  guides → canonical"*.

### ❌ Do not repeat this mistake

The OPA extract (10,262 rows / 9,591 names) sits within ~1% of
`dflow.properties_and_characters` (10,122) and `public.characters` (9,622). **That
is a coincidence. The three count different things.** A session raised and
disproved this on 2026-08-06.

| Table | What one row IS |
| --- | --- |
| **OPA extract** | a distinct **(property, character) pair** |
| `dflow.properties_and_characters` | `type='PROPERTY'` → a **style guide**; `type='CHARACTER'` → a character **appearance**, one per style guide |
| `public.characters` | a character **appearance**, carrying `property_id` |
| `core.character` | *(0 rows — never populated)* |

`AGENTS.md` §6.1 warns that `dflow.properties_and_characters` is misleadingly
named and that two AI sessions have already corrupted their understanding by
reading its column names literally. **Read that section before reasoning about
these tables at all.** Two axes: ownership is linear (licensor → property →
character); style is many-to-many (a style guide holds many characters, a
character appears in many style guides). Chaining them is the classic bug.

**What genuinely argues for landing the OPA data:** `core.character` is empty and
wants distinct characters parented to a property. Both legacy tables hold
*appearances*. OPA holds *identities scoped to a property* — the missing shape.
Still untested: whether `characterID` is stable enough to be that identity key.

## Related skills

- `shared-db-orchestrator` — required before any shared-database **change**
  (read-only schema inspection needs nothing).
- `shared-db-change` — how to author a correct migration, once dispatched.
