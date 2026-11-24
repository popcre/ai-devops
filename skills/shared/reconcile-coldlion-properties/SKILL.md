---
name: reconcile-coldlion-properties
description: Reconcile ColdLion Property values to authorized licensor-scrape Properties. Use when matching, counting, auditing, or exporting ColdLion/DesignFlow licensor-property mappings, especially for a ColdLion-to-scrape workbook. Enforces the exact live Item Library parent list, division separation, media-aware Core/Movie/TV ranking, and private-data handling.
---

# Reconcile ColdLion Properties

## Required sources

1. Read `shared-db/docs/coldlion.md`, `coldlion-open-questions.md`, and `business-rules/licensing-master-data.md`.
2. Read `getLicensorsWithProperties` in item-master and `getPropertyByLicense` in the frontend.
3. Use the same live environment the owner is comparing against. Never substitute the shared Supabase copy for the live Item Library without proving they agree.

## Parent-list contract

- Keep POP Lic / CW001 and Spruce Lic / SP001 separate.
- Include only active Properties returned to the Item Library.
- Reproduce the screen's final rule: selected Licensor numeric ID equals Property `parent_id`.
- Never collapse divisions by Property code before resolving the parent.
- Never infer a parent from Property code alone or a stale copy.
- Verify against the live Item Library screen or its authenticated live response.
- Spot-check Disney/Astronaut, Disney/Miraculous, Friends TV/Frida Kahlo, DC/Batman, and DC/Superman.
- The live Item Library currently carries known wrong parent rows: Astronaut and Miraculous under Disney, and Frida Kahlo under Friends TV. Apply the owner's corrections for reconciliation: exclude Astronaut from Disney, assign Miraculous to ZAG, and assign Frida Kahlo to the Frida Kahlo licensor. Preserve the recorded value as audit evidence.
- If an unrecorded database/screen disagreement appears, stop. Do not publish until the difference is explained.

## Shared-portal licensor split

- A portal is not a licensor. Never give every portal Property to every licensor served by that portal.
- Disney OPA serves Disney, Marvel, and Star Wars but sends no licensor field. Classify every OPA Property exactly once. Use the maintained franchise classifier and verify the three output sets have zero overlap. Never duplicate the OPA list and filter it separately per licensor.
- Keep Disney DCP, Marvel DCP, and Lucasfilm DCP rows in their named studio families.
- Paramount Creative Library serves Viacom Multi and Paw Patrol. `is_licensed_selection` is not a licensor relationship and must not filter the reviewer list. Put `PAW Patrol` under Paw Patrol; put every other captured Paramount Property, including `SpongeBob SquarePants`, under Viacom Multi.
- Warner STARLABS serves Warner Bros., DC, and Harry Potter. Use the captured Franchise evidence plus exact-title recovery for known properties; never copy the whole Warner list into each licensor.
- When a source cannot prove a licensor assignment, do not silently place it under the portal owner. Flag it for review.

## Workbook contract

- `Reviewer Property Selection` is a dropdown on every reconciliation row.
- Its choices are clean Property display names belonging only to that row's licensor.
- Keep source IDs in adjacent source-ID columns. Never display `Property | ID`, append a numeric ID to a Property name, or make reviewers choose an identifier-decorated label.
- The supporting `Valid Choices` sheet must show separate Property and Source ID columns for every licensor.
- Deduplicate dropdown display names. Retain all distinct source IDs in the supporting evidence and flag duplicate-name identities if a choice cannot resolve to one ID automatically.

## Title rules

- Compare only within the verified owning Licensor.
- A plain ColdLion title means the general property. Prefer `<Title> Core` at 100% over every dated movie, television series, or other presentation.
- A title ending in `MOVIE` or `THEATRICAL` means a movie. Remove that category word, then prefer a dated or explicit Movie property.
- A scrape title ending in `(YYYY)` is a Movie property.
- `TV`, `TV SERIES`, `TELEVISION SERIES`, `ANIMATED SERIES`, `LIVE ACTION`, `GENERAL ART`, `ASSORTED STYLES`, `GROUP`, and `FRANCHISE` are type words, not title evidence.
- Preserve a meaningful leading `The`. Treat scrape `Title, The` as `The Title`.
- Exact base-title agreement does not make different presentations identical.
- For a one-word title, reject every non-exact base title.
- Business-approved official-title exception: ColdLion `SPONGEBOB` equals scrape Property `SpongeBob SquarePants` at 100%. Do not let the one-word rejection rule block it.
- Treat harmless title variants as exact when the licensor and presentation agree: leading `A`/`An`/`The`, possessive punctuation, singular/plural wording, and a repeated licensor name. Required examples: `BUGS LIFE` = `A Bug's Life`, `DISNEY PRINCESSES` = `Disney Princess`, and `DISNEY VILLAINS` = `Villains`.
- Do not let harmless-title normalization erase presentation differences. A plain title still prefers Core/general over a dated Movie.
- Never auto-approve fuzzy similarity. Record the reason for every candidate.
- Reserve `Needs judgment` for genuinely close or ambiguous choices. If one candidate clearly leads and the difference is only non-identity wording, label it a clear/strong candidate instead.

## Validation gate

Before delivery:

1. Confirm Batman and Superman plain titles both rank Core first at 100%.
2. Confirm `UP MOVIE` ranks `Up` first at 100% and excludes `Goofy Movie`.
3. Confirm `SPONGEBOB` ranks `SpongeBob SquarePants` first at 100%; `90210` must never rank above it.
4. Confirm Paw Patrol's dropdown contains only `PAW Patrol`, while Viacom Multi contains `SpongeBob SquarePants` and excludes `PAW Patrol`.
5. Confirm Marvel has more than five choices, Star Wars is non-empty, and Disney/Marvel/Star Wars have zero duplicated source identities.
6. Open or structurally inspect the exported Excel validation itself. A populated supporting list is not enough: confirm at least one Disney, Marvel, and Star Wars row has a working dropdown that points to the correct non-empty list. Use an Excel-valid cross-sheet method such as a named range or `INDIRECT`; reject direct cross-sheet list references that Excel ignores.
7. Confirm `BUGS LIFE`, `DISNEY PRINCESSES`, and `DISNEY VILLAINS` are exact matches to their approved variants.
8. Review the full `Needs judgment` population; do not validate only named spot checks.
9. Confirm no dropdown value contains an appended source ID.
10. Confirm no workbook pair is absent from the accepted Item Library list after documented owner corrections.
11. Confirm every scrape candidate and dropdown value belongs to the verified Licensor.
12. Scan for formula errors and visually inspect all sheets.
13. Keep licensed rows and the workbook only in the private `u2giants/licensor-source-data` repository.
14. Do not write curated Master Data during reconciliation.

Reject the workbook if any check fails.
