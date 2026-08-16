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

When all occur under the post-change stretched-canvas family with MG03 `DIY`,
also consolidate:

- `DIY 2-Piece Canvas Set`
- `DIY 2Pk Canvas`
- `DIY 2Pk Canvas Set`
- `DIY Canvas`
- `DIY Canvas Set`
- `DIY Pbn Canvas`
- `DIY Pbn Canvas Panel 2-Piece Set`

Treat `PBN`, `2-piece`/`2pk`, `panel`, paint pots, and brushes as observed
description details, not separate physical product families. Preserve `DIY` as
the MG03 treatment.

## Stretched canvas hierarchy

In `MerchGroup_Rework.xlsx`, MG01 `A` plus MG02 `A` plus MG03 together roughly
describe the canvas product. The first two levels establish `Stretched/Box >
Canvas`, and the third contributes treatment or embellishment:

- `0` none stated
- `1` foil
- `2` shaped
- `8` other embellishment
- `9` other
- `B` embroidery
- `D` DIY
- `E` LED
- `G` staggered
- `H` high-gloss
- `Q` glitter, sequins, or rhinestones
- `P` handpaint
- `Y` physical attachment
- `W` gel or other coating

Therefore `Canvas`, `Printed Canvas`, or another broad canvas phrase appearing
under several of these MG03 keys is not inherently a conflict. The description
may omit the detail that distinguishes the full keys. Use treatment words when
present. For an old item without enough evidence, infer the supported MG01/MG02
portion and leave MG03 unresolved. Never assume MG03 `0` as a default.

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

Keep every wall-clock row's MG03 treatment assignment. A common physical product
phrase may span sibling MG03 values when the definition workbook makes MG03 an
attribute rather than a different physical product.

## MG hierarchy rule

For rows created on or after May 14, 2025, preserve `MG01|MG02|MG03` as the
row-level classification key. Interpret each level using the definition workbook.
The three values together roughly describe the product. Broad wording can span
several keys because it expresses only part of that meaning. Identical broad
wording across keys is expected and should be reviewed for missing distinguishing
detail, not presented as a categorization conflict. For old items, leave MG03
unresolved whenever reliable evidence does not identify it.

## Historical-to-later analogs

An explicit treatment is reliable MG03 evidence when a closely corresponding
post-change item has the same physical product and treatment. For example,
`Printed Canvas w Holofoil_[artwork]_20x16 x1.5` and a later
`Printed Canvas w Holofoil_[related artwork]_16x20 x1.5` are strong analogs.
Treat `20x16` and `16x20` as the same dimensions, ignore artwork-wording changes,
and propose the later item's complete stored MG01+MG02+MG03 key. Do not reduce
that key to its first characters.

This is different from assuming MG03 from the broad word `Canvas`. The explicit
`Holofoil` treatment plus the corresponding later item supplies the evidence.
If comparable later analogs disagree and no clearly closer row resolves the
disagreement, abstain.

The comparison must not depend on `Mamba Mentality`, `Kobe`, or any other artwork,
property, or character words. Reduce both rows to `Canvas | standard | Foil`,
count the post-change keys for that semantic signature, confirm the dominant key
means canvas with foil in the rework hierarchy, and then classify. A similar
artwork phrase may select which evidence row to display, but may never change the
classification.

## Review principle

Neither longest-string wins nor shortest-string wins. Choose the phrase that a
merchant would use to identify the complete sold product, and store the other
wordings as variants or attributes.
