---
name: item-description-taxonomy
description: Interpret product item descriptions, split them into item type, size, licensor, property, and artwork wording, and build or repair a consolidated item-type phrase dictionary. Use for item-master cleanup, historical merchandise-group recategorization, description parsing, product-type normalization, phrase-list deduplication, or any request to infer what products are from free-text descriptions.
---

# Item description taxonomy

Treat this as a semantic product-understanding task. Scripts may collect, count,
and display evidence. They may not decide the taxonomy.

## Required outcome

For each description, distinguish:

- **Item type:** what physical product this is, including material, construction,
  or treatment only when those facts distinguish real product families.
- **Item size:** all physical dimensions and units, including depth when stated.
- **Licensor:** license owner wording present in the description.
- **Property:** franchise, character, or property wording present in the description.
- **Artwork description:** the remaining design, slogan, color, scene, pose, or pattern.

When building a dictionary, produce one canonical item-type phrase per semantic
product concept plus its observed variants.

## Non-negotiable reasoning rules

1. Read the entire description set before finalizing types. A phrase's meaning
   depends on how the company describes related products elsewhere.
2. Ask: **Would a merchant say these are different physical products, or merely
   different ways of describing the same product?** Merge the latter.
3. Do not treat every repeated n-gram, prefix, suffix, or longer phrase as a new
   item type. Text frequency is evidence, not a business decision.
4. Merge spelling errors, abbreviations, punctuation, singular/plural, word-order
   changes, omitted words, and progressively longer fragments when they name the
   same product.
5. Prefer the shortest phrase that still identifies the complete physical
   product. Keep a modifier only when removing it would merge genuinely different
   products or treatments.
6. Exclude size, licensor, property, artwork, color, slogan, character pose,
   packaging instructions, manufacturing specifications, and incidental contents
   from the canonical item type unless they define the sold product itself.
7. When the business gives a reliable category-change date, build three independent
   association maps from rows on and after that date: MG01, MG01+MG02, and
   MG01+MG02+MG03. Each map associates its key with the accepted physical-product
   meanings observed under that key. Match older products deepest-first, then fall
   back one level at a time. Do not use earlier MG codes to define or choose results.
8. Never call an automated phrase list final. A model must review every proposed
   family semantically and consolidate it before user review.
9. Abstain when the physical product is genuinely ambiguous. Explain exactly what
   cannot be separated.

## Workflow

### 1. Preserve the source

- Keep the original description and source-row identifier unchanged.
- Work in a confidential location when descriptions contain licensed content.
- Never place licensed rows in a public repository.

### 2. Build the governed dictionary and three trusted MG maps

- Split rows at the business-provided change date and read the merchandise-group
  definition workbook before interpreting any code.
- Create one dictionary row for every distinct observed description wording.
  Record a stable family ID, canonical physical product, construction or shape,
  treatment, all observed variants, counts, status, and decision reason.
- Use explicit statuses: `accepted`, `alias`, `needs_review`, and `placeholder`.
  Only `accepted` and `alias` rows may teach or receive an MG assignment.
- Parse every old and new description into physical product, size, licensor,
  property, and artwork wording. Also retain construction/shape and treatment as
  separate product attributes. Never use licensor, property, artwork, slogan,
  color, character, or size orientation in an MG decision.
- From post-change rows only, independently list every MG01, every MG01+MG02, and
  every MG01+MG02+MG03 and all accepted product signatures observed under each.
  Require every component through that depth to be present.
- For each historical accepted product, try an exact reviewed
  product+construction+treatment association at MG01+MG02+MG03. If unsupported,
  try the reviewed product+construction association at MG01+MG02. If unsupported,
  try its approved broad physical format at MG01.
- Require at least two supporting later rows, a dominant winning share, and a
  clear lead over the runner-up before populating MG02 or MG03. Store support,
  total evidence, winning share, and the complete competing distribution.
- The approved MG01 definition workbook may supply the final broad physical-format
  fallback because MG01 is itself a broad product format. Do not invent, rewrite,
  or "repair" MG01 codes.
- Keep unsupported lower levels blank. Loose word overlap, fuzzy similarity, and
  artwork similarity may suggest review candidates but must never populate proposed
  MG fields.
- Count five outcomes separately: full match, MG01+MG02 match, MG01-only match,
  readable accepted product without MG01, and no usable accepted product type.
- Treat rotated dimensions such as `16x20` and `20x16` as the same size when
  orientation does not change the product, but do not use size to select MG.

### 3. Learn the company's language holistically

- Normalize case, punctuation, encoding damage, spelling variants, and common
  abbreviations for comparison without overwriting the original.
- Remove or mark dimensions, known licensor wording, and known property wording.
- Examine descriptions together, grouped provisionally by physical nouns,
  materials, construction, treatments, and existing MG families.
- Find both repeated wording and one-off variants that clearly belong to a common
  family.

### 4. Propose semantic item types per row

Interpret the description as a whole. Identify the noun phrase that answers
"what physical item is this?" Do not extract a text fragment merely because it
is frequent.

Examples:

- `Crumb Rubber Door Mat_Bows & Wildflower Pattern 30x18" x7mm`
  -> item type `Crumb Rubber Door Mat`; artwork `Bows & Wildflower Pattern`.
- `Disney Printed Glass Shadowbox Stitch wink Oh Yeah Whatever blue 12x12"`
  -> item type `Printed Glass Shadowbox`; size `12x12"`; licensor `Disney`;
  property `Stitch`; artwork `wink Oh Yeah Whatever blue`.

### 5. Consolidate product families and preserve MG attributes

For each proposed type, compare all near phrases by meaning, not character match.
Create one family record containing:

- canonical item-type phrase;
- all observed variants and misspellings;
- item count;
- representative descriptions;
- MG01-MG03 distribution;
- any reason a similar phrase must remain separate.

Within related post-change product descriptions, actively test whether extra material,
packaging, size, construction, quantity, `DIY`, `PBN`, `2pc`/`2pk`, or contents
wording is merely an attribute. Fold equivalent phrases into the simplest
complete merchant-facing name where appropriate, but preserve the full
MG01+MG02+MG03 meaning. Do not create a different wording merely because one
description is longer. Never merge or infer the actual row-level MG assignments.

Read [references/consolidation-cases.md](references/consolidation-cases.md) before
approving a phrase dictionary.

### 6. Run the common-sense gate

Before export, test every family:

- Is one phrase just another phrase plus an extra trailing word?
- Is the difference only spelling, abbreviation, punctuation, or word order?
- Is a material/construction modifier meaningful or incidental?
- Did artwork, license, property, size, packaging, or factory wording leak in?
- Are two phrases separate only because a script extracted different lengths?
- Would a buyer or merchant actually treat them as different products?
- Does the proposed interpretation follow the full MG01+MG02+MG03 hierarchy?
- Is every part of the three-part product meaning supported by the description
  or other reliable evidence?

Merge or correct every failure before showing the result.

### 7. Export for review

Provide two review surfaces:

1. **MG-keyed product descriptions:** MG01, MG02, MG03, combined key, interpreted
   product description, broad wording shared with other keys, distinguishing
   wording, count, examples, confidence, and reviewer decision.
2. **Row-level parsing:** original description and the five extracted chunks,
   linked to the proposed canonical family.
3. **Classification evidence:** physical product, construction/shape, treatment,
   later full-key distribution, chosen level, rework meaning, and a plain-English
   decision trace. State explicitly that artwork was excluded from the decision.

Flag ambiguity and MG disagreement. Do not hide it behind a numeric score.

## Completion gate

Do not report completion until:

- the mandatory consolidation cases pass;
- every interpretation follows the definition workbook's full MG01-MG03 hierarchy;
- no old item receives MG03 without description evidence or other reliable evidence;
- prefix-chain duplicates have been semantically reviewed;
- spelling and abbreviation variants are grouped;
- a sample from every major MG01 family has been checked;
- at least 25 random rows and all user-supplied examples have been inspected;
- every workbook sheet has been visually verified;
- the source and database remain unchanged unless the user separately authorizes
  changes.
