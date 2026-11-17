---
issue: "2531, 2549, 2550, 2551"
status: OPEN
owner: zcode/sess_cf627505
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

1. Finish Phase C (#2551): Hy4 and DeepSeek cache baselines,
   Chat-Completions vs Responses API comparison (24h retention on Responses
   only), growing second-opinion thread across restart, idle-interval probe;
   publish paired hit-rate/time/cost tables; keep the experiment off by
   default and separately revertible.
2. Restart-recall phrasing pass, then the activation matrix (§10) when the
   no-switch hold is lifted; activation is a separate revertible default
   change per §13.
3. Close out the Ubuntu interactive install step and record the receipt.

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
