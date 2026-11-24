---
issue: 2782                            # the Windows-only test failure; finished when that issue is closed and the installer gap in §6 step 2 has an issue of its own
status: OPEN
owner: zcode/wrapup-deepseek-rollout
---

# HANDOFF — DeepSeek rollout follow-ups (`2026-11-24T0236Z`, `hetz`/`zcode`)

## 0. Business Decisions Only the Owner Can Make

- **None.** Nothing in this file needs the owner; every remaining step is technical.
- **Already settled — do NOT re-ask:**
  - **2026-11-23:** DeepSeek stays on `deepseek-openrouter`, default reasoning, `AI_REVIEW_CACHE` off by default, with the four shipped fixes of [PR #2780](https://github.com/popcre/ai-devops/pull/2780) ([decision record](https://github.com/popcre/ai-devops/blob/main/docs/decisions/2026-11-23-deepseek-reviewer-optimization.md)).
  - **2026-10-29:** AI review is advisory only and never blocks merges ([docs/owner-rulings.md](https://github.com/popcre/ai-devops/blob/main/docs/owner-rulings.md)).
  - **2026-08-13:** No cap on `HANDOFF.d/` file count; a file's presence means open ([handoff standard](https://github.com/popcre/ai-devops/blob/main/templates/system/handoff-standard.md)).

## 1. What This Application Is

[popcre/ai-devops](https://github.com/popcre/ai-devops) is Albert Hazan's public toolkit for a multi-model AI coding and code-review workflow. It is installed on Windows development hosts (`edge-dev`, `4837`, `916`) and Ubuntu hosts (`hetz`, a server; `edge-dev3`, a desktop). GitHub `main` is the source of truth. An installed copy advances only through the protected updater, never by a plain pull ([docs/deployment.md, Update](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md#update)). The networking-only Windows machines (`edge-alien`, `edge-runn-envy`, `edge-runn-xps`) never receive it.

## 2. What We Set Out to Do This Session, and Why

Finish the rollout of PR #2780 (commit [`5817f83d`](https://github.com/popcre/ai-devops/commit/5817f83d97f79a153bffd1d3bb4ba2daf9cfd77e), the DeepSeek reviewer and second-opinion optimization): bring `edge-dev3` and `hetz` to a `main` that contains it, prove it live on each, then retire the handoff that described that work.

**That workstream is complete.** This file carries only what was left behind: one Windows-only test failure ([#2782](https://github.com/popcre/ai-devops/issues/2782)) and one installer gap found during wrap-up (§5).

## 3. Current State — What Is True Right Now

- **Rollout: done and live-verified on all three hosts.** `edge-dev` (Windows) was installed at `5817f83d` and checked on 2026-11-23 by the session that wrote PR #2780. `hetz` and `edge-dev3` were advanced by other sessions through the protected updater to `21369419`, which contains `5817f83d` (`edge-dev3` at 5:22 PM EST, `hetz` at 8:22 PM EST, both on 2026-11-23); every install stage passed on each.
- **Live proof on `hetz` and `edge-dev3`** (installed tools, throwaway two-commit repository, SQL injection seeded at `auth.py:5`), all passing at 8:29 PM to 8:34 PM EST on 2026-11-23:
  - `ai-review-simple --route deepseek-openrouter` with `AI_REVIEW_USAGE=1`, `AI_REVIEW_CACHE=1` and a `bill-` id: exit 0, verdict REJECT naming `auth.py:5`; steps started/finished 2/2 on `hetz` and 4/4 on `edge-dev3`.
  - OpenRouter analytics for each `bill-` id: `request_count` 2 and 4 (equal to the steps finished), only `deepseek/deepseek-v4.1-flash-20261017`, prompt tokens 12293 and 26553 (equal to uncached plus cached), completion tokens 584 and 1523, cached tokens 5632 and 19200.
  - `ai-deepseek-agent send` then `reply`: token `NOVA-925` (`hetz`) and `ORION-415` (`edge-dev3`) returned verbatim, the bug named at `auth.py:5` in both turns.
  - `ai-deepseek doctor --live`: `PASS live turn`, exit 0, on both.
  - Full numbers: [PR #2783](https://github.com/popcre/ai-devops/pull/2783).
- **Rollout handoff retired:** [PR #2783](https://github.com/popcre/ai-devops/pull/2783) merged at 8:45 PM EST on 2026-11-23 (commit `92986198`); the file is absent on `main`.
- **`main` at writing:** `32d46868`, four commits ahead of what `hetz` and `edge-dev3` have installed: `92986198` (handoff retirement), `da99ce44` and `9b5ddb42` (sync-dotfiles skill documentation), `32d46868` (signature fix). None changes reviewer behavior. Installing stays a deliberate act.
- **[#2784](https://github.com/popcre/ai-devops/issues/2784) (ZCode posts signed "Claude"): closed.** Fixed by [PR #2786](https://github.com/popcre/ai-devops/pull/2786), merged 9:15 PM EST on 2026-11-23.
- **[#2782](https://github.com/popcre/ai-devops/issues/2782) (Windows Git Bash test failure): open, nobody assigned.** See §5 and §6.
- **Installer gap (§5, second bullet): not tracked anywhere yet.** No issue exists.
- **Committed and pushed:** everything this session wrote is on `main`. Workspace clean; this session's branches deleted and its worktrees removed.

## 4. Everything We Tried That Did NOT Work

- **Two reviews ran where one was intended.** On `hetz` the review command was launched twice in the same minute by mistake. Both reconciled against OpenRouter's records (2 requests each, DeepSeek only); the PR #2783 evidence uses only the run whose receipts survived. Cost about $0.0006. Launch one paid call per step and read its receipts before the next.
- **Deleting the merged remote branch failed.** The push that deletes PR #2783's branch returned an error because GitHub had already removed the branch at merge time. Harmless: check `git ls-remote` before deleting.
- **The handoff's picture of the hosts was stale.** The retired handoff said `edge-dev3` and `hetz` were un-updated. Both had already been advanced by other sessions before this session started. Read each host's installed commit first; do not assume a handoff's host state is current.
- **No tracker existed for the Windows failure.** Searching the repository's issues for "symlinked session folder" and "symlinked deepseek-agent" returned only unrelated issues, which is why #2782 was opened.

## 5. Root Causes and Key Findings

- **Windows-only failure (#2782).** `tests/test-ai-deepseek-agent.sh` checks that a symlinked session folder is refused ([line 370](https://github.com/popcre/ai-devops/blob/main/tests/test-ai-deepseek-agent.sh#L370)). On the Windows host `edge-dev` under Git Bash the session that wrote PR #2780 saw `FAIL symlinked session folder is rejected` on 2026-11-23 (218 passing, 1 skipped). On Linux `hetz` at `21369419` this session ran the same suite: passed 223, failed 0, skipped 0. PR #2780 did not touch `bin/ai-deepseek-agent`, so the failure predates it. This session did not reproduce it: no Windows host was reached.
- **ZCode's skill home is a stale partial mirror.** On `hetz`, the directory ZCode loads skills from holds links to 39 of the 62 shared skills under the repository's `skills/shared`. The 23 missing include `session-docs-update`, `ask-deepseek`, `shared-db-change` and `sync-dotfiles`. `bin/ai-install-skills` reports `session-docs-update (shared) up to date` for the other client homes and, for ZCode, installs only the global instructions ([lines 920-926](https://github.com/popcre/ai-devops/blob/main/bin/ai-install-skills#L920-L926)). Effect: a ZCode session running [wrap-up](https://github.com/popcre/ai-devops/blob/main/skills/shared/wrap-up/SKILL.md) cannot call `session-docs-update` by name (read [its file](https://github.com/popcre/ai-devops/blob/main/skills/shared/session-docs-update/SKILL.md) instead), and cannot load `ask-deepseek`, whose documentation PR #2780 updated.
- **OpenRouter's analytics query has a strict shape.** The request body and the equalities that make a review reconciled are now recorded next to the billing-probe instructions in [the DeepSeek plan](https://github.com/popcre/ai-devops/blob/main/plan_deepseek-harness-openrouter.md); they had lived only in the retired handoff.

## 6. Exact Next Steps

1. **Reproduce and fix #2782 on a Windows host.** Run `tests/test-ai-deepseek-agent.sh` on `edge-dev` or `4837` under Git Bash; a session already on a Windows host is simplest, and an Ubuntu review host reaches `4837` with `ssh 4837` ([docs/deployment.md, Install](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md#install)). You'll know it is the same failure when it prints `FAIL symlinked session folder is rejected`. Then make `ai-deepseek-agent list` refuse a symlinked session folder on Windows, or make the test report that case as not runnable there. Ship through a branch, a pull request and the merge queue. You'll know it worked when the Windows run has no failure, the Linux run still passes 223/0/0, and #2782 is closed.
2. **Give the installer gap an issue.** Open a `bug` issue on the repository titled "ZCode skill home links only part of skills/shared; installer refreshes ZCode global instructions only", with the evidence in the second bullet of §5. You'll know it worked when its number is recorded in #2782 or in this file and a session has picked it up.
3. **Retire this file** once #2782 is closed and the gap has its own issue or fix. You'll know it worked when a docs-only pull request deleting it is merged and the file is absent on `main`.

## 7. Constraints and Gotchas in Force

- Never run `git pull` or merge in an installed checkout; use the candidate-worktree updater in [docs/deployment.md](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md#update).
- Never push to `main`: branch, pull request, merge queue. A docs-only change needs `bin/ai-doc-safety --changed origin/main` to pass on the exact head first.
- Never install on `edge-alien`, `edge-runn-envy`, `edge-runn-xps`.
- An update that needs `sudo` on a host where `sudo -n true` fails follows the route in the [sync-dotfiles skill](https://github.com/popcre/ai-devops/blob/main/skills/shared/sync-dotfiles/SKILL.md): a shared terminal tab where Albert types the password once. `hetz` needs no password. This session needed neither, because both hosts were already updated.
- Do not edit or delete another session's `HANDOFF.d/` file.
- Sign everything posted to GitHub. On a host still behind `32d46868`, pass `--app zcode` to `bin/ai-gh-signature`.
- A billing check needs `AI_REVIEW_USAGE=1` and a fresh id of `bill-` plus 32 lowercase hexadecimal characters; one review costs about a cent.

## 8. Access and Environment

- **GitHub:** `popcre/ai-devops`. The committer identity must resolve to Albert Hazan. Make GitHub calls through `bin/ai-gh`.
- **Hosts:** a session on `hetz` works locally. `edge-dev3` accepts non-interactive SSH as the desktop user, who has no passwordless `sudo`. The installed copy is two levels above the target of the `ai-task-gates` launcher.
- **Secrets:** the OpenRouter management key is in 1Password vault `vibe_coding`. Read it through a pipe only; its value never appears in chat, arguments or files.

## 9. Open Questions and Risks

- **Open technical question:** is the Windows failure a real refusal gap in `ai-deepseek-agent`, or a test that cannot run meaningfully on Git Bash? Step 1 of §6 answers it (decided 2026-11-23: fix whichever it turns out to be; no owner ruling needed).
- **Risk:** the stale ZCode skill home probably exists on other hosts too. Only `hetz` was checked (2026-11-23).
- **Risk:** a session that trusts `gh pr merge` to delete its branch sees a push error. Harmless.

---

## Mandatory Self-Audit Gate

1. **Zero prior context?** Yes — §1 names the repository, the hosts and the protected-update rule; §3 gives exact commits, times in EST and measurements; §6 gives three steps, each with a gate.
2. **Continue as effectively as this session?** Yes — §4 holds the double launch, the harmless branch-delete error and the stale host picture; §5 holds the failing test line, the Linux result and the skill-home evidence with line references.
3. **Failed attempts included?** Yes — §4 lists all four, each with why it failed and what to do instead.
4. **Concrete steps with gates?** Yes — §6 steps 1 to 3 each end with "You'll know it worked when".
5. **Every term and identifier explained?** Yes — the `bill-` id shape (§7), the three hosts and classes (§1), the issues and pull requests by link (§2, §3).
6. **Every file and commit reference a GitHub URL?** Yes — checked §0 to §9; no machine-local path appears.
7. **Section-0 sweep completed?** Yes — walked §1 to §9 line by line: no sentence needs the owner; the only mention of Albert is the documented password route in §7, which is a standing procedure, not a decision.

### Final Synthesis Answers

1. **Comprehensive for a brand-new developer?** Yes (§1 background, §2 goal, §3 exact state, §6 executable steps).
2. **Detailed enough to continue as well as this session?** Yes (§4 dead ends, §5 findings with file and line links, §7 constraints).
3. **Every relevant detail present?** Yes — background, goals, current state, failures, decisions, constraints, risks, next actions and verification evidence are each mapped to a section above.
4. **Owner reading only §0?** He sees "None" plus three settled rulings with dates, and no technical approval.
