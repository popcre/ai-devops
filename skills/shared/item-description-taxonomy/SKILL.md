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
7. When the business gives a reliable category-change date, treat the combined
   MG01-MG03 on and after that date as the classification key. MG01 and MG02 can
   define the physical product family while MG03 distinguishes treatment,
   embellishment, construction, or another lower-level attribute. The same broad
   product wording may legitimately occur under several sibling MG03 keys. Do
   not call that a conflict. Do not use earlier MG codes to define the new rules.
8. Never call an automated phrase list final. A model must review every proposed
   family semantically and consolidate it before user review.
9. Abstain when the physical product is genuinely ambiguous. Explain exactly what
   cannot be separated.

## Workflow

### 1. Preserve the source

- Keep the original description and source-row identifier unchanged.
- Work in a confidential location when descriptions contain licensed content.
- Never place licensed rows in a public repository.

### 2. Establish the trusted MG groups

- Split rows at the business-provided change date.
- For rows on or after that date, create the primary key
  `MG01|MG02|MG03`. Treat blank or incomplete keys as unresolved.
- Read the merchandise-group definition workbook before interpreting the key.
- Build the physical-product dictionary at the level defined by MG01 and MG02,
  then learn the MG03 treatment or embellishment wording from sibling keys.
- Keep each row's full MG key, but allow one physical product family to span
  sibling MG03 keys when the hierarchy defines MG03 as an attribute.
- Treat identical broad wording across sibling MG03 keys as expected ambiguity,
  not evidence that a key is wrong.
- Use pre-change descriptions only as candidates to match into a trusted keyed
  group. Do not let their old MG values influence the new grouping.

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

Within one post-change product family, actively test whether extra material,
packaging, size, construction, quantity, `DIY`, `PBN`, `2pc`/`2pk`, or contents
wording is merely an attribute. Fold equivalent phrases into the simplest
complete merchant-facing name. Preserve the MG03 treatment separately. Do not
create a different physical product family merely because MG03 differs or one
description is longer. Never merge the actual row-level MG assignments.

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
- Does the proposed physical family follow the MG01/MG02 hierarchy?
- Is the MG03-specific treatment or embellishment preserved separately?

Merge or correct every failure before showing the result.

### 7. Export for review

Provide two review surfaces:

1. **Product families with MG variants:** MG01, MG02, physical product phrase,
   every associated MG03 definition and description variant, count, examples,
   confidence, and reviewer decision. Preserve each row's full MG key.
2. **Row-level parsing:** original description and the five extracted chunks,
   linked to the proposed canonical family.

Flag ambiguity and MG disagreement. Do not hide it behind a numeric score.

## Completion gate

Do not report completion until:

- the mandatory consolidation cases pass;
- every physical family follows the definition workbook's MG01/MG02 hierarchy;
- every MG03 treatment remains traceable to its full row-level MG key;
- prefix-chain duplicates have been semantically reviewed;
- spelling and abbreviation variants are grouped;
- a sample from every major MG01 family has been checked;
- at least 25 random rows and all user-supplied examples have been inspected;
- every workbook sheet has been visually verified;
- the source and database remain unchanged unless the user separately authorizes
  changes.
