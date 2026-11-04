# Implementation plan — popcre/ai-devops#2340 (post-Blacksmith wording + manual Windows lane timeout)

## Verdict (read first)

**Still real on main** (checked 2026-11-04 at `f2b4f5bd56d2bb4c2ccd3d91d4e27d330c3bf339`).
All ten findings from the advisory review of PR #2339 (merged as `5f7e7c82`) are
still present on main. The automatic fixer (run 41764778452) said it corrected
most of the documentation, but it failed and **nothing landed**: no PR mentions
#2340, and the defective lines are still on main (exact lines in §5). Under the
skinny rulings this is still worth doing because it is a cheap prose fix plus
one real risk: a timeout tuned for Blacksmith's speed. It adds no new check,
no new tool and no wait. One PR closes it.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Docs wording | ⬜ open (2026-11-04) | — |
| 2 Manual Windows workflow text + timeout | ⬜ open | — |
| 3 Restore negative label guard in policy test | ⬜ open | — |
| 4 Verify, PR, merge, close #2340 | ⬜ open | — |

A fresh session starts at Step 1.

Handoff registration: the implementing session must create
`HANDOFF.d/<UTC>-<machine>-<agent>-2340-blacksmith-wording.md` linking this plan.
This planning session was read-only and could not create that file. The plan
currently lives in the planner's scratchpad, so copy it to
`plan_2340-blacksmith-wording.md` in the worktree, or put its contents in the
handoff.

---

## 1. Ultimate goal

On 2026-11-03, Albert asked us to stop using Blacksmith, a paid CI runner
provider. PR #2339 did that. While doing so, it replaced the word "Blacksmith"
with "GitHub-hosted" by find-and-replace across the documentation. Several
sentences now say the opposite of the truth, or nothing at all. Examples:
"never routes to GitHub-hosted" when GitHub-hosted is now the default, and
"$1000/2 weeks on GitHub-hosted" when that money was spent on Blacksmith.
AI agents read these docs and act on them. Wrong docs lead agents to the wrong
runner choices or the wrong cost reasoning. The goal is that every sentence
matches reality: GitHub-hosted is free on this public repo, Blacksmith is gone,
and paid runners stay off-limits. Also, the manual full Windows run must not
time out because its limit was sized for a faster provider.
**If a step conflicts with this goal, the goal wins — stop and flag it.**

## 2. What this application is

`popcre/ai-devops` is Albert's (POP Creations) public toolkit repository. It
holds AI tooling, skills, CI workflows and docs. The work happens on the `main`
branch, which is protected: changes go through a PR and the merge queue, and the
AI merges. CI runs on GitHub Actions, using free GitHub-hosted runners plus idle
self-hosted machines as extra capacity. The router is
`tools/ci/runner-router.cjs`, configured by `config/ci-runner-routing.json`.

## 3. Trigger

Issue #2340 is an automatic `review-finding` from the advisory Muse review of
PR #2339 ("ci: take Blacksmith out of the runner pool", head `aeb8d211`). It is
labelled `fixer-failed`. The fixer comment says three findings sit in "protected"
`.github/workflows/windows-offline-hosted.yml` and were not touched, and that
its doc edits were never landed. To reproduce, run the greps in §5.

## 4. Scope

In scope: the ten findings, as wording fixes, plus the timeout follow-on in
Step 2.
**NOT in this plan:** changing routing behaviour or `config/ci-runner-routing.json`;
renaming keys or lanes (for example `matrix.lane != 'github-hosted'`); touching
WarpBuild docs; rewriting history docs such as
`tests/verification/repo-throughput/issue-210-*` (historical record, leave it);
the "pre-existing Bash-suite inventory mismatch" the fixer mentioned (separate,
and not ours); and a broad sweep of every "GitHub-hosted" mention, most of
which are correct.

## 5. Current state on main (`f2b4f5bd`)

- `docs/development.md:272-274`: "stays on GitHub-hosted. It never routes to GitHub-hosted runners" (self-contradictory).
- `docs/development.md:378-379`: "GitHub-hosted job, or GitHub-hosted job" (duplicate).
- `docs/deployment.md:176`: "never paid GitHub-hosted", while line 180 says "GitHub Actions stay as a free weekly backup".
- `docs/task-router.md:18`: "never GitHub-hosted; free Actions backup only". Line 99, "never GitHub-hosted for alarms", has the same category error. Fix it too, because it comes from the same rename.
- `docs/watchdog-duty-pool.md:18`: "Paid runners (GitHub-hosted) were too expensive … $1000 / 2 weeks". That was Blacksmith. Lines 48 and 99 say "paid GitHub-hosted".
- `docs/self-hosted-windows-runner.md:242`: "GitHub-hosted or GitHub-hosted work".
- `.github/workflows/windows-offline-hosted.yml:22`: purpose prompt says "Why this paid run is needed right now".
- Same file, lines 45-48: the comment says GitHub-hosted is "roughly 2x faster", citing the baseline. The baseline (`tests/verification/repo-throughput/issue-210-blacksmith-baseline-20260910.md:80`) says **Blacksmith** was ~1.9-2x faster than windows-2025. `timeout-minutes: 20` was sized on that speed. The job now runs on `windows-2025` (line 42).
- Same file, lines 66-68: compares "GitHub-hosted's" TEMP to "GitHub-hosted's".
- `tests/test-workflow-policy.sh:296-297`: the check named "names only the GitHub-hosted fallback labels" lost its old negative guard (`! grep -Eq "(windows-20..|ubuntu-..)"` over the routing config). That guard is visible in `git show 5f7e7c82 -- tests/test-workflow-policy.sh`. Another check in that file asserts `timeout-minutes: 20` on the manual workflow; find it with `grep -n "timeout-minutes: 20" tests/test-workflow-policy.sh`.

## 6. Key findings

- `config/ci-runner-routing.json:2` states it outright: GitHub-hosted runners are free on this public repo, and Blacksmith was removed on 2026-11-03.
- The paid thing the old prohibitions meant was Blacksmith (and any paid runner). The correct replacement wording is "never a paid runner (Blacksmith was removed 2026-11-03)", not "never GitHub-hosted".
- In the routing config, `hosted_windows` = `windows-2025` and `hosted_linux` = `ubuntu-24.04` legitimately name GitHub-hosted labels. So the restored negative guard must exclude those two keys and fail only if a GitHub-hosted label appears anywhere else.

## 7. Rejected approaches

- Reverting PR #2339: rejected. The routing change is what the owner asked for.
- A new lint against duplicated phrases or "paid GitHub-hosted": rejected. It is a new moving part, and skinny rulings allow only data-safety and secret-leak checks to block.
- Leaving the workflow alone because the fixer called it "protected": rejected. That restriction applies to the automatic fixer only. A normal session PR may edit workflows.
- Rewriting the historical baseline file: rejected. It is evidence and stays as recorded.

## 8. Decisions

Locked:
- GitHub-hosted = free and allowed. Paid runners = never. Blacksmith = removed 2026-11-03.
- No new CI checks or tools.
- Step 3 only restores a guard that already existed (and it is advisory, like all non-safety checks).

Open (implementer judgment):
- Exact sentence wording.
- The manual-lane timeout value. Criterion: about 2x the old 20, so **40**, matching verify.yml's stated 40-minute hosted bound (comment at line 43). Use a different value only if you find a recent `windows-offline-hosted` run showing a section over 35 min. Check with `gh run list -R popcre/ai-devops --workflow windows-offline-hosted.yml -L 5`.

## 9. Steps

**Step 1 — Docs wording.** Edit the doc lines in §5:
- dev.md:272-274: "Any section it cannot place there stays on free GitHub-hosted runners; it never routes to paid runners (Blacksmith removed 2026-11-03)."
- dev.md:378 and self-hosted-windows-runner.md:242: reduce the duplicate to a single "GitHub-hosted job".
- deployment.md:176, task-router.md:18 and :99, watchdog-duty-pool.md:48 and :99: say "never a paid runner such as Blacksmith (removed 2026-11-03); local timers are primary, the free GitHub-hosted Actions run is a weekly backup only". For alarms, the meaning is "alarms are not hosted on Actions as primary". Keep that meaning.
- watchdog-duty-pool.md:18: "Paid runners (Blacksmith, removed 2026-11-03) were too expensive…".

Gate: `grep -rn "GitHub-hosted or GitHub-hosted\|GitHub-hosted job, or GitHub-hosted\|paid GitHub-hosted\|Paid runners (GitHub-hosted)\|never routes to GitHub-hosted" docs/` returns nothing.

**Step 2 — `.github/workflows/windows-offline-hosted.yml`.**
- Line 22: change the prompt to "Why this full manual run is needed right now".
- Lines 44-47: rewrite the comment to say Blacksmith measured ~2x faster than windows-2025 (cite the baseline) and that the limit was therefore raised to match the 40-minute hosted bound.
- Set `timeout-minutes: 40`.
- Lines 66-68: "The GitHub-hosted runneradmin TEMP (C:\Users\runneradmin\…\Temp) is far deeper than a short root like C:\t…". Keep the rest of the rationale.
- Update the policy-test assertion that pins `timeout-minutes: 20` for this workflow so it pins `40`.

Gate: `grep -n "timeout-minutes\|paid run\|2x faster\|deeper than" .github/workflows/windows-offline-hosted.yml` shows the new text, and `bash tests/test-workflow-policy.sh` passes the touched checks.

**Step 3 — Restore the guard** at `tests/test-workflow-policy.sh:296-297`. Append a condition that strips `hosted_windows`/`hosted_linux` and confirms no other GitHub-hosted label appears, for example:
`! jq 'del(.hosted_windows,.hosted_linux)' "$routing" | grep -Eq '"(windows-20[0-9][0-9]|ubuntu-[0-9][0-9]\.[0-9][0-9])"'`
Mind the quoting: the check body is a single-quoted string.

Gate: the check passes on the real config. Temporarily adding `"x":"windows-2022"` to a copy of the config makes it fail. Test this with the copy only, then discard the copy.

**Step 4 — Land it.** Use one branch and one PR. The title starts `docs/ci:`. The body says "Fixes #2340" and is signed with `$AI_GH_SIGNATURE`. Then run `bin/ai-pr-wait <pr>` in the background, merge via the queue, and confirm #2340 closes.

## 10. Tests

- Existing: `bash tests/test-workflow-policy.sh` must stay green on the touched checks. The fixer reported a pre-existing inventory-mismatch failure; confirm that same failure on unchanged main before treating it as yours.
- Changed: the timeout pin (20→40) and the restored negative label guard (Step 3), each proven by the Step 3 mutation test.
- Docs have no tests. The Step 1 grep is the gate.

## 11. Constraints and gotchas

- Use a worktree, never the canonical checkout. Commit as Albert's verified identity (`git var GIT_COMMITTER_IDENT`) and stage only owned files.
- Never push to `main`. The AI merges.
- Reviews are advice only. Do not wait on them.
- Quote all times in EST.
- Line numbers may drift. Match on the quoted text.
- Do not touch `matrix.lane != 'github-hosted'` guards or the `hosted_*` keys.

## 12. Access

You need `gh` authenticated for `popcre/ai-devops`. No secrets are needed. Run tests locally with bash on Linux.

## 13. Done, risks, open questions

Done means:
- The Step 1 grep is empty.
- The workflow text and timeout are fixed, and the tests are updated.
- The PR has merged, and #2340 closed via "Fixes".
- Optional live proof: dispatch `windows-offline-hosted.yml` once on main and see sections finish under 40 min. If skipped, leave `- [ ] live proof` on #2340 rather than a new issue.

Risk: a 40-minute limit costs nothing extra (the lane is free) and lowers false timeouts. Rollback is reverting the PR.
Open questions: none for the owner.

## Self-audit

1. Can a fresh session execute this without asking anything? Yes. §5 lists every defective line with its text, §9 gives the replacement wording and a gate for each step, and §11-12 give the rules and access.
2. Is all the background carried over? Yes. §3 has the fixer's failure, §6 the free-versus-paid fact and the baseline, §7 the rejected options.
3. Is the goal clear enough to steer by? Yes. §1 states the true runner and cost facts that every sentence must match.

Gap noted: the handoff file was not created, because this was a read-only planning session. The Step header asks the implementer to create it.
