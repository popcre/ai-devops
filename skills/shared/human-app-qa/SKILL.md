---
name: human-app-qa
description: Explore a web frontend like a real customer and report evidence-backed behavior or usability problems without reviewing code. Use for human QA, exploratory or journey testing, visual checks, "use the app", "click everywhere", or "poke and prod".
disable-model-invocation: true
---

# Human App QA

Test the running application as a person, not as a code reviewer. Prefer Chrome
DevTools MCP for browser control, screenshots, console evidence, network
evidence, and performance evidence. Use another available visible browser tool
only when Chrome DevTools MCP cannot complete an interaction.

Do not default to Playwright. Use Playwright only when the user explicitly asks
to turn a confirmed journey or regression into a permanent repeatable test.

## Establish the safe test boundary

Before interacting, establish the target URL, permitted environment, available
test accounts, and prohibited actions from the request and repository guidance.
Default to preview, sandbox, staging, or localhost. Treat production as
read-only unless the user explicitly authorizes specific mutations.

Never place a real order, send a real message, invite a real person, charge a
payment method, publish content, delete durable data, or change production
settings merely to test a control. Stop before the final irreversible action
when its effect is uncertain.

Use dedicated test accounts and test data. Do not inspect unrelated tabs,
cookies, saved passwords, browser history, or personal sessions.

## Explore like a customer

Start from the landing or signed-in home page without reading the source code.
Build a lightweight coverage map from visible navigation and discovered paths.
Then explore rather than following only the happy path:

1. Complete the obvious primary journeys as a first-time user.
2. Open every reachable menu, tab, modal, drawer, dropdown, and help surface.
3. Try empty, invalid, duplicate, very long, boundary, and interrupted input.
4. Click quickly, click twice, navigate back, refresh mid-flow, cancel, and
   resume where safe.
5. Check desktop and narrow-window layouts. Check zoom when supported.
6. Complete a keyboard-only pass through important journeys.
7. Repeat role-sensitive journeys with each available permission level.
8. Look for unclear wording, missing feedback, dead ends, lost work, stale
   state, inconsistent controls, clipped content, and surprising outcomes.

Do not mechanically click destructive controls. Verify their presence,
labeling, confirmation design, and cancel path without committing the action.

## Diagnose without becoming a code review

For each suspected problem, reproduce it once when safe. Use Chrome DevTools MCP
to collect the minimum useful evidence:

- screenshot of the visible result;
- console error or warning connected to the action;
- failed, incorrect, duplicated, or unexpectedly slow network request;
- relevant performance trace for a responsiveness complaint;
- exact page, account role, input, and interaction sequence.

Judge the user's experience first. Technical evidence explains the behavior but
does not replace the human finding. Do not inspect or modify application source
unless the user separately asks for diagnosis or a fix.

## Maintain coverage and avoid loops

Track visited areas, completed journeys, blocked areas, and remaining surfaces.
Do not repeat the same interaction after two identical outcomes unless changing
one input or condition. Re-scan navigation after actions that reveal new areas.

End when the agreed scope is covered, a safety boundary blocks further testing,
or access is missing. Never claim complete coverage when authentication,
permissions, unavailable data, or unsafe actions left gaps.

## Report findings

Lead with the most serious customer-impacting problems. For each finding give:

1. Severity: blocker, serious, annoying, or cosmetic.
2. Page and account role.
3. Exact reproduction steps.
4. Expected customer-visible result.
5. Actual customer-visible result.
6. Screenshot or recording path when captured.
7. Console, network, or performance evidence when relevant.
8. Reproduction confidence.

Then list tested journeys, coverage gaps, and areas that passed without a
material problem. Keep observations separate from suggested fixes.
