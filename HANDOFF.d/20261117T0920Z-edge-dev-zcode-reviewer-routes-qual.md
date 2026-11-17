---
issue: "2531, 2549, 2550, 2551"
status: OPEN
owner: successor session (switch decision taken 2026-11-17; Albert will run the switch in a new session)
---
# Reviewer routes: Phase A+B landed, Phase C started — activation hold intact

## 0. Business decisions

None taken. Albert's "don't switch any defaults yet" hold is still in force:
no default changed. The activation/cutover (plan §13, step 5) is outside the
completed authorization.

## 1. Application

[POP Creations AI DevOps Toolkit](https://github.com/popcre/ai-devops). Work
landed on protected `main` through the merge queue; live proofs ran on
GitHub Actions (edge-dev3 runners), edge-dev3 (Ubuntu desktop) and edge-dev
(Windows).

## 2. Goal and trigger

Continue #2531 from the 2026-11-16 handoff: implement the four candidate
reviewer routes (#2549, #2550), prove GitHub verdict publication and
read-only resumable second opinions on Ubuntu and Windows, and start the
separate caching qualification (#2551).

## 3. Current state

Landed on `main` (heads): #2560 `5dbb6b1` (registry + wiring + 29-test
suite), #2569 `41f2272` (harness read-only preset, failover profile rewrite,
route-shaped provider selection), #2570 `883e552` (copy-failure message),
#2571 `4b7bc698` (Phase C cache wiring, off by default, + 48-test suite) and
the STATUS docs commit. Plan: `plan_deepseek-harness-openrouter.md` STATUS is
current. GitHub receipts: #2563–#2568 (closed, branches preserved) — four
attributable route verdicts plus both forced-fallback scenarios; run ids in
the comments on #2549/#2550. Second-opinion matrices ran on both OSes
(five fresh requests per route, marker file reads, clean write probes,
per-session locks, live atomic Muse failover). Live cache measurements on
PR #2571: 3.3–3.5k cached tokens per review, cross-head reuse confirmed.

## 4. Attempts and dead ends

Six parallel fixture reviews hit an upstream OpenRouter 429 shared-pool rate
limit once (published as unavailable, succeeded on rerun) — the deepseek
model's upstream pool rate-limits under concurrency; serialize live route
runs or accept reruns. Restart-recall phrasing ("print the line-1 content
you printed before") was answered inconsistently by the models even though
sessions, transcripts and session ids verified intact — needs a phrasing
pass before the activation matrix. The Muse cache benchmark's ~9% figure
aligns with the new measurements; account-level prefix reuse makes a strict
cold run hard, scope keys per experiment namespace.

## 5. Evidence and limits

- #2549 comment 6942972534, #2550 comment 6942978334, PR #2571 comment
  6942959217 (cache table), plan STATUS table.
- Ubuntu privileged install: `update.sh` advanced the checkout and passed
  task gates, but `install.sh`'s protected-config backup needs an
  interactive sudo password — unavailable headless. Everything the candidate
  needs on that machine (pinned dsh at
  `~/.local/lib/ai-devops/deepseek-harness/0.2.2-rc.1`, OpenRouter reviewer
  key store) is staged by its own idempotent stages; finishing the full
  install takes one interactive `./update.sh` from a terminal on edge-dev3.
- Windows installer ran at `4b7bc698` (log:
  `%TEMP%\win-install.log`); verify `ai-hy4` resolves from the installed
  launchers afterwards.

## 6. Exact next steps

0. **The switch (decided 2026-11-17, runs in a NEW session on Albert's go).**
   Stage activation as ONE separate revertible default change per plan §13:
   the normal GitHub rotation uses the candidate expansion (muse ->
   muse-meta with same-model OpenRouter failover, deepseek -> the OpenRouter
   route, Hy4 final fallback) and new Muse second opinions default to the
   candidate route; everything else stays opt-in. Flip ON = merge that PR;
   flip OFF = revert it (one queue run, ~20-30 min). Before merging: run the
   §10 activation matrix rows that remain (restart-recall phrasing pass),
   rehearse the rollback (revert on a fixture PR, verify a live LEGACY
   review completes and candidate session state stays readable), and keep
   the no-switch env defaults intact inside the same commit so the revert is
   a pure default flip. Albert's go is the trigger; he has been told both
   directions are one pipeline run each.
1. **Per-model re-check (caching + session persistence), before or with the
   switch.** For each of muse-meta, muse-openrouter, hy4-openrouter and
   deepseek-openrouter, re-verify and record receipts: (a) caching — with
   AI_REVIEW_CACHE=1, cache receipts present and stable across two restarts
   of one named session and across an idle interval (>=15 min), a cold/warm
   pair per route, and a distinct-head run per route (namespaced so
   account-level prefix reuse cannot mask a cold run); (b) session
   persistence — a named conversation recalls a file-read marker after two
   fresh-process restarts (phrase the ask neutrally: models refused the
   earlier "repeat what you printed" phrasing), the harness conversation
   resumes via --session-id, and the Muse failover continuation keeps the
   prior visible turns. Post receipts on #2551 and #2531.
2. Finish Phase C (#2551): Hy4 and DeepSeek cache baselines,
   Chat-Completions vs Responses API comparison (24h retention on Responses
   only), growing second-opinion thread across restart, idle-interval probe;
   publish paired hit-rate/time/cost tables; keep the experiment off by
   default and separately revertible.
3. Close out the Ubuntu interactive install step and record the receipt (see
   §5; one on-machine terminal session, prompt file
   `Install-reviewer-routes-edge-dev3.md` on the Desktop of edge-dev).

## 7. Constraints

All defaults unchanged; advisory-only review; protected credentials in the
runner-local stores; no prompt or credential content in public receipts;
legacy sessions and the direct DeepSeek engine untouched.

## 8. Access

Same as the plan §12. The openrouter reviewer key is
`op://vibe_coding/sssotzy4jpmp4hux7x2vajhana/credential` (scoped to the
three pinned models) and is now stored on edge-dev, edge-dev3 and in
install.sh's store-key stage.

## 9. Risks

Upstream 429 shared-pool rate limits on the deepseek model; model-phrasing
sensitivity of the restart-recall check; OpenRouter account-level prefix
reuse can mask a cold cache run — namespace experiments.

## Self-audit

1. §§3–6 name every landed head, receipt link, blocker and next action.
2. §§4–5 keep the rate-limit, phrasing and sudo limits with their evidence.
3. §0 keeps the activation hold; §7 repeats the safety constraints.
4. No new business decision was found or taken.
