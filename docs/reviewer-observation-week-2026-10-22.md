# Reviewer observation week — findings (2026-10-22 13:56Z to 2026-10-29)

Plan step 8 report for #1948 ([plan](../plan_reviewer-observation-week.md)).

**Sources**
- Reviewer event and scoreboard logs from edge-dev3, edge-dev, hetz (user `ai`) and 4837. The 916 log had no rows in the window.
- Full chat transcripts from the Dropbox `ai/chat_transcripts/` archive for edge-dev, edge-dev3 and hetz: about 1,460 files and 3 GB.
  - A local keyword prefilter required a reviewer term near a failure term and dropped duplicates. That cut the input to 7.7 MB.
  - ScaleDown Summarize then reduced it to 560 KB of incident extracts. Transcript counts below are approximate.
- Incident packages from edge-dev3 and git history.
- This report extends the earlier log-only diagnosis in #1948 comment 6497102610.

## 1. Per-reviewer numbers (logs, all hosts)

- **Volume:** about 730 scored verdicts from 806 started runs.
- **Spread:** 282 calling sessions and 477 distinct heads. 139 heads were reviewed more than once, one of them 19 times.
- **Repos:** shared-db 77%, theoracle 94, popdam3 33, others 45.
- **Cost:** `cost_usd` is 0 on every row, so no run records what it cost.

| Reviewer | Rows | APPROVE | REJECT | REVISE | BLOCKED | Blocked % | Median / p90 seconds |
|---|---|---|---|---|---|---|---|
| Muse | 331 | 219 | 94 | 0 | 18 | 5% | 273 / 538 |
| DeepSeek | 162 | 59 | 53 | 0 | 50 | 31% | 448 / 1167 |
| GLM | 127 | 89 | 0 | 18 | 20 | 16% | 403 / 760 |
| StepFun | 112 | 41 | 25 | 0 | 46 | 41% | 323 / 728 |
| Codex | 2 | 0 | 0 | 0 | 2 | 100% | 98 |

The four main reviewers account for 732 rows and 134 blocks.

Main BLOCKED classes:
- **StepFun:** fast-fail-silent-start 31.
- **DeepSeek:** native-execution-failed 28, stale-source 9, source-identity-changed 8.
- **GLM:** risk-block-missing 9, stale-source 8.
- **Muse:** snapshot-drifted 4, stale-source 3.

Who caused the blocks:
- **Our own tooling, about 71:** silent-start kills, native-boundary refusals, the risk-block format check, and snapshot errors.
- **Calling sessions, about 44:** stale-source, source-identity-changed, and failed tests commands.
- **Vendors, about 7.**

Not in the earlier diagnosis:
- **72 runs started but never produced a scoreboard row.** The worst were Muse on edge-dev (27) and DeepSeek on edge-dev (12).
- **9 runs never finished.**
- **Frozen reviewers still ran:** Grok 4 times, Claude 3, Codex 2.
- **GLM never REJECTs;** it uses REVISE instead.

## 2. Failures only the transcripts show

Counts are matching passages in-week, approximate.

1. **A finished verdict was refused for lease or assignment** (about 12): "reviewer deepseek-v4.1-flash holds no active lease at all".
2. **The replacement-reviewer route refused or picked the wrong reviewer** (about 25): "reviewer allowlist does not match the durable unrestricted assignment".
3. **Results were lost** (about 27): "durable store did not succeed; retaining sandbox … for reconciliation".
4. **PRs merged unreviewed or by owner override** (about 8). This includes the Oct 26 hetz production merge.
5. **Sessions idled or stalled waiting for a review** (about 33), some for 48 minutes or more. One draw was stalled for over an hour.
6. **Provenance, budget or gate checks refused before any reviewer ran** (about 8): "review budget complete first-parent ancestry unavailable".
7. **Quota or credit ran out** (about 5 in-week; about 49 hits earlier on hetz). DeepSeek returned HTTP 402 "Insufficient Balance". The logs record only 1 out-of-credit row.
8. **Version pins drifted:** "installed 1.0.41, policy requires 1.0.13".
9. **Sessions worked around the gate** (about 14): bare `gh` bypasses and "Merged unreviewed (supervisor bypass)".

## 3. Root causes

**(a) Our own tooling (largest share)**
- The StepFun 300-second silence watcher kills healthy runs.
- The DeepSeek supervisor swallows the reason for its refusal.
- The risk-block check BLOCKs instead of retrying.
- The shared-db lease, replacement, budget and provenance layer refuses valid work.
- Results are lost after durable-store failures.
- No cost or credit tracking exists.
- The freeze list is not enforced.
- The PR waiter is broken on Windows, and sessions get no wake-up when a review finishes.

**(b) Vendors**
- Prepaid credit runs out unannounced.
- Vendor CLI upgrades change behavior.
- DeepSeek is slow at the p90.
- Only about 7 blocks are vendor-caused.

**(c) Calling sessions**
- Source or tests change mid-review.
- Sessions re-draw the same head.
- Sessions idle-wait.
- Sessions bypass the gate and call frozen reviewers.

**(d) Design and policy (the root)**
- Eleven providers have been integrated.
- Review is gated by a distributed ledger.
- The design fails closed with no automatic fallback, so owner rulings end up authorizing unreviewed merges.
- Rules churn faster than code settles.
- Five hosts, two operating systems and five calling engines multiply every combination.
- Fixes to the gate wait behind the broken gate (#1993, #2000).

## 4. Why there is still no simple reviewer system after ~10 months

It stopped being simple. Every failure added a safeguard, a provider or a rule, and nothing was removed. Counts since the 2026-07-05 repository move are a floor:

- **Size:** about 60,000 lines for "send diff, record verdict": about 33,000 in reviewer wrappers, about 3,900 in review doors and events, and about 24,600 in shared-db review scripts.
- **Churn:** 510 commits on core review paths, accelerating (August 120, September 166, October 222).
- **Rules:** 237 rule-file commits.
- **Rewrites:** at least four front-door rewrites (#624, #1258, #1322, #1725).
- **Providers:** 11 integrated; 5 were built, hardened, then frozen or retired.

Structural reasons:
1. **The design defends the wrong threat.** It guards against rare dishonest or stale reviewers, while the real failures are availability problems.
2. **Breadth over depth.** No single path was ever made reliable.
3. **State is distributed** across repositories and five machines, and any mismatch causes a refusal.
4. **The agents fix the gate that blocks them,** so they add rules or bypasses instead of deleting code.
5. **Nothing was measured** (cost, lost runs, a reliability target) until this week.

## 5. What would make it work (ranked)

1. **Use two reviewers:** Muse first and GLM as fallback. Delete retired wrappers rather than freezing them.
2. **Make each review one stateless call.** A verdict is valid only if its SHA equals the PR head at merge, with no leases, budgets, allowlists or provenance in the path.
3. **Fall back automatically:** retry once, then use the fallback reviewer, then mark the review "unavailable" under one written rule. Sessions make no judgment calls.
4. **Run reviews in CI on the PR head,** not in chat sessions.
5. **Post the verdict before any bookkeeping,** and track started-without-verdict as a metric.
6. **Record cost per run** and check balances daily.
7. **If DeepSeek and StepFun stay in use,** land the StepFun heartbeat, the supervisor error text and the risk-block retry.

**Stop:**
- Adding providers or safeguard layers after a failure.
- Using owner rulings to authorize exceptions.
- Gating review-tool fixes on the review system.
- Re-drawing the same head more than twice.
- Treating "frozen" as only a label.
