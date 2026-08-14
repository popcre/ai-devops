# Mandatory consolidation cases

Use these as regression tests. Equivalent variants must resolve to one canonical
item-type concept unless new source evidence proves a real physical distinction.

## Prefix-chain fragments

These are one item type, not separate types:

- `27Cm Froomies Foam Wall`
- `27Cm Froomies Foam Wall Dcor`

Canonicalize to a complete product phrase such as `Froomies Foam Wall Decor`.
Treat `27 cm` as size, not item type.

These are one item type:

- `2Pc Canvas Set Paint`
- `2Pc Canvas Set Paint Pots`
- `2Pc Canvas Set Paint Pots Brush`

The longer strings describe included contents. Choose one complete commercial
product concept, such as `2-Piece Paint-Your-Own Canvas Set`, after checking the
full descriptions. Do not make each longer fragment a new type.

When all occur under post-change key `A|A2|D2`, also consolidate:

- `DIY 2-Piece Canvas Set`
- `DIY 2Pk Canvas`
- `DIY 2Pk Canvas Set`
- `DIY Canvas`
- `DIY Canvas Set`
- `DIY Pbn Canvas`
- `DIY Pbn Canvas Panel 2-Piece Set`

Treat `DIY`, `PBN`, `2-piece`/`2pk`, `panel`, paint pots, and brushes as observed
description details inside that MG key, not separate keyed product families.

## Spelling and word-omission variants

These are one item type:

- `Anti Fatigue Pvc Kitchen`
- `Anti Fatigue Pvc Kitchen Mat`
- `Anti Fatique Kitchen Mat`
- `Anti Fatique Pvc Kitchen`
- `Anti Fatique Pvc Kitchen Mat`

Canonicalize to `Anti-Fatigue PVC Kitchen Mat`. `Fatique` is a misspelling;
omitting `PVC` or `Mat` does not create a different physical product when the
surrounding descriptions establish the same family.

## Similar wording that remains meaningfully separate

These can remain separate because the history and MG03 values identify different
product constructions:

- `Crumb Rubber Outdoor Mat`
- `Crumb Rubber Door Mat`

Do not merge solely because phrases are similar. Preserve distinctions supported
by the physical description and consistent catalog behavior.

## Same post-change MG family with incidental material wording

These are one item type when items created on or after May 14, 2025 consistently
share `M|W1|B1`:

- `Molded Wall Clock`
- `Polypropylene Molded Wall Clock`

Canonicalize to `Molded Wall Clock`. Store `Polypropylene` as material wording,
not as a separate product family. Apply the same test to other material,
packaging, size, and included-contents modifiers. Do not apply this mechanically
when the modifier indicates a genuinely different construction or the trusted
post-change MG01-MG03 values disagree.

This merge applies only to the `M|W1|B1` rows. A molded-wall-clock description
under `M|W1|P1` is a separate keyed group because different post-change MG keys
can never be combined.

## Hard MG-key boundary

For rows created on or after May 14, 2025, `MG01|MG02|MG03` is the primary key.
One description group may have many wording variants, but exactly one key. If the
same canonical phrase occurs under two keys, output two separate groups and flag
the duplication for business review. Never solve the disagreement by combining
the keys.

## Review principle

Neither longest-string wins nor shortest-string wins. Choose the phrase that a
merchant would use to identify the complete sold product, and store the other
wordings as variants or attributes.
