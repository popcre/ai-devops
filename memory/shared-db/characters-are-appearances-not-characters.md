---
name: characters-are-appearances-not-characters
description: "core.character is EMPTY; the 9,622 CHARACTER rows are style-guide appearances, not characters"
metadata: 
  node_type: memory
  type: project
  originSessionId: fa3b1b0e-98dc-49ab-8530-06c09a727d77
  modified: 2026-08-06T17:59:14.027Z
---

Before touching characters / style guides in `u2giants/shared-db`, read
`docs/style-guides-characters-and-royalties.md` **first**. It is accurate and
more precise than re-derivation; its §4 counts were re-verified live against
production on 2026-08-06 and still hold exactly.

Live production (`qsllyeztdwjgirsysgai`), 2026-08-06:

- `core.licensor` 26, `core.property` 256, **`core.character` = 0 rows**. The
  canonical ownership chain stops one level short of characters. §5A of that doc
  says axis 1 is "already correct in the canonical schema today" — true for
  licensor/property, **false for character**.
- `core.properties_and_characters`: 9,622 typed `CHARACTER`, 500 typed
  `PROPERTY`, 8,370 distinct names.

**The trap that costs a session:** those 9,622 `CHARACTER` rows are character
**appearances** — one per style guide — not characters. So
`Avengers Logo ( Marvel Games )` and `Mickey & Pluto - Back To School` are
legitimate rows, not junk to be deleted. They are meant to become the M:N bridge
`core.style_guide_character`. Do NOT "de-junk" them. Equally, `type='PROPERTY'`
holds **style guides**, not properties.

Two practical consequences:

- Only **4,519 of 9,622** appearance rows carry a `( style guide )` suffix in the
  name; for the other **5,103** the style guide cannot be recovered by parsing
  the name — use `source_licensed_property_id` or the association table.
- When checking whether a character exists, probe the **full name**, never a
  tokenised fragment. `Mickey` returns 0 exact matches; `Mickey Mouse` exists.
  Expect apostrophe-variant duplicates (curly vs straight).

Related: [[merch-group-taxonomy]], [[shared-db-apply-mechanics]].
