# AI Visual Testing (placeholder / future)

How UI changes get visually verified in the workflow. This is a **placeholder**
to be fleshed out when visual testing is wired up (see the toolkit's
`docs/future-visual-testing.md`).

## When visual testing is required

The Stage 01 plan answers **"Visual testing needed? yes/no."** Answer **yes**
when the change:

- alters any user-visible UI (layout, styling, copy, components),
- changes a user flow (navigation, forms, modals), or
- could affect responsive/mobile rendering or accessibility.

## Intended approach (future)

- Use **Playwright** to drive the app and capture screenshots.
- Compare against a known-good baseline (visual regression) where practical.
- Verify the key states: default, loading, empty, error, and success.
- Check at least one narrow (mobile) and one wide (desktop) viewport.

## For now (manual)

Until automated visual regression is set up:

1. Run the app locally.
2. Exercise the changed screens in the states above.
3. Capture before/after screenshots and attach them to the PR / completion
   report.
4. Optionally ask for a second opinion on what to verify:
   `ai-glm ask "Which screens and states does this diff change?"`.

> This document will be replaced with concrete setup steps once the Playwright
> harness is added to the toolkit.
