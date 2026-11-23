---
issue: 2624
status: BLOCKED
owner: codex-01a2094c
---

# Prompt for the receiving AI session

## 0. Business decisions

None. Albert already asked in the Codex chat, “Finish the five blocked sandbox refreshes. Fix whatever is holding the release checks and verify all five are current.” Take ownership of the remaining technical work. Use your existing host access and perform the steps yourself. Albert has no command to run and no technical approval to supply.

## 1. Application and scope

DesignFlow is POP Creations’ product lifecycle application. Albert’s sandbox is [Alsand](https://alsand.designflow.app/). Its Frontend, Backend, BFF gateway, Item Master, and Tracking repositories each have a public-to-the-team `develop` source and a `sandbox-albert` release branch. A normal sandbox branch push triggers the corresponding Google Cloud Build and Cloud Run deployment in project `lithe-breaker-323913`, region `us-east4`. GitHub owns source, Cloud Build owns deployment, and the serving Cloud Run revision proves delivery. Start with the standing DesignFlow instructions and the [toolkit repository guide](https://github.com/popcre/ai-devops/blob/main/AGENTS.md).

## 2. Goal and stop condition

Complete the protected release-check installation on edge-dev3. Refresh the five named sandbox branches from published `develop`, preserving each sandbox’s own work. Check every latest sandbox build against its serving Cloud Run revision. If another session has already delivered a current refresh, verify and record it without pushing again. Keep this work on [ai-devops #2624](https://github.com/popcre/ai-devops/issues/2624). Data Syncing and the separate retained merchandise-table cleanup and its schedules are outside this handoff.

## 3. Verified state at handoff

- The release-check fix is merged. [PR #2770](https://github.com/popcre/ai-devops/pull/2770) landed at [2780c56bb373af644cd69bc4d2eba04ea9f33ae1](https://github.com/popcre/ai-devops/commit/2780c56bb373af644cd69bc4d2eba04ea9f33ae1). The isolated Linux tests passed 36 source proofs and 537 gate cases. Read-only validation matched the five real merge candidates, their exact existing sandbox triggers, and prior successful sandbox builds. No source changes to that fix are outstanding.
- At 2:16 PM EST on November 23, the installed checkout pointed at the merged fix while the protected installation manifest still identified [e9d04c89257236164b866fb4c1477c12840f165d](https://github.com/popcre/ai-devops/commit/e9d04c89257236164b866fb4c1477c12840f165d). The installer transaction is pending. Treat those two different values as an incomplete installation.
- Frontend, Backend, BFF, and Item Master were never pushed by the predecessor. The signed issue receipt records the earlier isolated candidates for reference. All five published develop heads advanced after that receipt. A fresh read at 2:16 PM EST found each sandbox missing the latest develop head. For all five, an ordinary conflict-free merge reproduced the published develop mirror exactly and left the application tree outside `shared-db/` unchanged.
- Tracking previously shipped source [05ecbac1](https://github.com/popcre/designflow-tracking/commit/05ecbac1e856f57894243d9dda842eeb4009d086) in [Cloud Build 5a70da91](https://console.cloud.google.com/cloud-build/builds;region=us-east4/5a70da91-95f3-4c73-89ac-282efdb2c9f7?project=677598988032). The matching revision `popcre-albert-tracking-sandbox-00673-pxf` was ready and served 100% of traffic. That is historical proof. Tracking’s published sandbox head subsequently moved again. Check its current branch and runtime before deciding what still needs shipping.
- The existing closeout evidence and installer failure are in the [signed issue receipt](https://github.com/popcre/ai-devops/issues/2624#issuecomment-7109397261).

## 4. Attempts and findings

The earlier generic deploy check could not admit these mirror refreshes. The old dedicated route covered only Frontend and Data Syncing, and its Frontend condition required the entire merged tree to equal develop, which would discard legitimate sandbox-only files when the branches diverged. The merged change verifies both canonical parents, confirms the mirror equals published develop, preserves files outside the mirror, and checks the exact sandbox trigger and passing build and tests. The exact release route still refuses unauthorized changes.

The protected Linux updater passed preflight, advanced its installed checkout, then failed before installation while trying to make its required privileged backup. The kernel reported that the command runtime had `NoNewPrivs` set, so `sudo` could not elevate. Do not treat the advanced checkout as proof of installation or try to bypass backup, manifest, launcher, or authorization checks. Invoke the supported updater only from a host session with its normal administrator access. If the same runtime restriction is present, leave the transaction intact and record the blocker on #2624.

## 5. Repositories and service map

- [Frontend](https://github.com/popcre/designflow-frontend) → `popcre-albert-frontend-sandbox`
- [Backend](https://github.com/popcre/designflow-backend) → `popcre-albert-core-sandbox`
- [BFF](https://github.com/popcre/designflow-bff) → `popcre-albert-bff-sandbox`
- [Item Master](https://github.com/popcre/designflow-item-master) → `popcre-albert-item-sandbox`
- [Tracking](https://github.com/popcre/designflow-tracking) → `popcre-albert-tracking-sandbox`

Use the fresh published references in each repository. The [release proof implementation](https://github.com/popcre/ai-devops/blob/2780c56bb373af644cd69bc4d2eba04ea9f33ae1/tools/application_source_release.py), [gate](https://github.com/popcre/ai-devops/blob/2780c56bb373af644cd69bc4d2eba04ea9f33ae1/bin/ai-task-gates), and [operating procedure](https://github.com/popcre/ai-devops/blob/2780c56bb373af644cd69bc4d2eba04ea9f33ae1/docs/context-spec.md) are available at the immutable merged source.

## 6. Execute and verify

1. **Reconcile ownership and drift.** Read #2624 and recent activity in all five apps. Confirm you are on edge-dev3 with working host administrator authority for the ordinary installer. Check the current installed source and its protected source receipt. If someone else completed the install, verify its completed receipt and that the installed source contains #2770. Skip a duplicate install. If a different installation is in progress, serialize and follow its documented recovery path.
2. **Resume the exact protected installation.** Follow the [Linux installation procedure](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md) and [updater](https://github.com/popcre/ai-devops/blob/2780c56bb373af644cd69bc4d2eba04ea9f33ae1/update.sh). Fetch canonical toolkit main and verify the merged SHA is in its history. Use a clean candidate worktree at the exact merge commit sharing the installed checkout’s Git common directory. Declare installation and resume the existing transaction using the exact merged source. From that candidate, the documented form is `./update.sh --installed-checkout "$installed_checkout" --expected-head 2780c56bb373af644cd69bc4d2eba04ea9f33ae1`, with `installed_checkout` set to the verified installed toolkit checkout. Let the updater own backup, resume and finalization. Success requires a completed installer, a matching protected receipt, and the genuine managed launchers and proof helper. A file update or a green source test alone is insufficient.
3. **Build fresh candidates.** Fetch canonical `sandbox-albert` and `develop` independently for each app. A branch already containing current develop only needs the live proof in step 5. For every remaining app, use an isolated worktree at its exact published sandbox head. Run `ai-task-gates start --class deployment --base HEAD` before merging. Merge only the exact published develop head, in that order, and verify the resulting tree preserves sandbox files outside `shared-db/` while its mirror matches develop. Confirm the expected Git identity before committing. Stop on a conflict or real app or pipeline change and use the owning repository’s normal release route for that change. Preserve existing work.
4. **Admit and ship.** From each clean candidate, run `ai-task-gates check --before deploy --published-sandbox-refresh --acknowledge` with the exact owner quote in section 0 as the argument. Run in a clean shell. If stale `GIT_CONFIG_*` variables are inherited from the calling tool, clear the overrides rather than changing the verifier or its custody checks. Confirm the installed gate admitted the exact source and sandbox target. Recheck the published parents before pushing the verified head to `sandbox-albert` by a normal non-forced push. Re-fetch and rebuild the candidate if either parent moves. The sandbox build must run its existing checks automatically. Keep any existing sandbox-to-develop PR workflow intact and preserve sandbox-only work owned by other sessions.
5. **Verify all five live.** For each repository, capture the latest published develop SHA, the sandbox SHA, and evidence that the latter contains the former. Find the sandbox Cloud Build for that exact sandbox SHA and expected service trigger. Require successful tests and build, match the published image digest to the ready Cloud Run revision and require 100% traffic on that revision. Check Alsand and normal service health with existing approved access. Use exact revision and artifact evidence for private services without direct unauthenticated access. Use the existing bounded waiters for builds or PRs rather than improvised polling. Record any failure on the same issue and resolve it within scope before calling the app current.
6. **Close out on #2624.** Post a signed dated receipt per app with its source, build link, serving revision, digest match and health result. Safely fast-forward clean landing checkouts as applicable and preserve other sessions’ local work. Close only after the protected install and live verification on all five are proved. If externally blocked, keep the existing live-proof item open and name the precise failure there.

## 7. Constraints

Use GitHub and the existing enabled sandbox Cloud Build routes. No production, database, direct Cloud Run configuration, scheduled-task, or unrelated repo changes. Use isolated worktrees and ordinary non-forced pushes. Preserve signing, test gates, and current sandbox ownership. Keep the managed installer’s protected backup and source proof requirements. No manual edits to the installed checkout, receipt, or pending authorization as a substitute for the supported install.

## 8. Access

Use a normal host agent session on edge-dev3 with existing noninteractive administrator capability for the protected installer. Verify the host and permissions before starting. Use the machine’s existing authenticated GitHub and Google Cloud tools. Use approved credential injection through 1Password vault `vibe_coding` only if required. Keep secrets out of arguments, output, and issue comments. The procedure and source references above locate all required code independently of any predecessor scratch files.

## 9. Risks and checks before you stop

The independent retained-copy work is tracked on [Item Master #205](https://github.com/popcre/designflow-item-master/issues/205) and [shared-db #6198](https://github.com/popcre/shared-db/issues/6198). Its [standalone schedule](https://github.com/popcre/shared-db/issues/6198#issuecomment-7109120047) already has its own execution owners. The shared test reads are November 26 at 11:55 PM EST and November 27 at 1:10 AM EST. Production reads are November 29 at 11:00 AM and 12:15 PM EST. The two later runs handle their own cleanup only if the checks pass. The signed issues contain separate recovery and usage proof requirements. Do not run either cleanup from the sandbox refresh session.

Published heads can move while installation or deployment runs. Recheck them at admission and live verification. The installed checkout and protected receipt may disagree until the updater finalizes. Existing successful builds establish prior runtime health but do not prove the latest develop changes have landed. If a qualified host session cannot access the approved privileged installer path, report the exact permission failure in #2624 and preserve the pending transaction and all release evidence.

Handoff self-audit passed. Sections 1–3 give a new session the what and why, sections 3–5 preserve the observed state and failed attempt, and sections 6–9 define each action and its evidence. A sweep of sections 1–9 found no business decision to raise in section 0.
