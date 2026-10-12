---
issue: 1562
status: OPEN
owner: claude/1562-door-diagnostics-leak
---

# #1562 door-diagnostics leak: fix merged (PR #1599); live proof and one pre-existing test failure remain

Written 2026-10-12T1310Z (9:10 AM EDT) on machine `edge-dev3` by a Claude Code session.
Repo `popcre/ai-devops`; fix landed on `main` as merge commit `fb5cbd10414846469a6d5fc0cd258335baff81b7` ([PR #1599](https://github.com/popcre/ai-devops/pull/1599)).

## 0. Business decisions only the owner can make

**Nothing blocks the next session.** Owner rulings made this session (Albert, chat, 2026-10-12):

- Verbatim: "edge-alien is not a dev machine. it shouldn't have this bulky toolkit installed. it needs to run as lean as possible." → never run reviews or live proofs on EDGE-ALIEN.
- He chose to **keep** the GitHub Actions runner on EDGE-ALIEN.
- Verbatim: "i don't want the networking parts of the ai-devops toolkit removed from edge-alien. ssh key, ssh config, hostnames, etc. should all stay." and "don't end the sessions that were open or delete their transcripts."

## 1. What this application is

Public recovery toolkit for Albert's multi-model AI workflow; this work is in the reviewer lifecycle (runner core, provider doors, private failure diagnostics). Router: [AGENTS.md](https://github.com/popcre/ai-devops/blob/main/AGENTS.md).

## 2. What we set out to do, and why

DeepSeek review run `20261012T090026-2925715-17164` on EDGE-ALIEN (`--tests "bash tests/test-review-door-diagnostics.sh"`, `AI_DEEPSEEK_TIMEOUT=7200`) failed after 7318 s with no verdict. ~30 min in, its private diagnostics directory was created early holding test-stub output (`STUB dir=[...] PWD!=DIR`) and an empty event stream; at the real failure [tools/review_door_diagnostics.py](https://github.com/popcre/ai-devops/blob/main/tools/review_door_diagnostics.py) raised `FileExistsError` (WinError 183) and the real evidence was lost. Reviewer issue `20261012T110316Z-edge-alien-deepseek-3154565`. Goal: find the leak, scrub it, never lose evidence, add offline regressions.

## 3. Current state — what is true right now

- **Merged (PR #1599):**
  - [tools/reviewer_event_guard.sh](https://github.com/popcre/ai-devops/blob/main/tools/reviewer_event_guard.sh) `reviewer_credit_run` launches the native reviewer with every `DOOR_*`, `RLC_*`, `AI_REVIEW_RUNNER_CORE`, `AI_REVIEW_VIA_RUNNER`, `AI_REVIEW_RUNNER_NAME` unset (all providers).
  - [tools/lib/review-lifecycle-core.sh](https://github.com/popcre/ai-devops/blob/main/tools/lib/review-lifecycle-core.sh) runs the `--tests` command with the same scrub.
  - [tools/review_door_diagnostics.py](https://github.com/popcre/ai-devops/blob/main/tools/review_door_diagnostics.py): a pre-existing destination is left untouched; this run's evidence goes to a `<dest>.collision-<pid>-<n>` sibling; it exits non-zero ("both retained") **before** writing the caller report.
  - Regressions: [tests/test-review-door-diagnostics.sh](https://github.com/popcre/ai-devops/blob/main/tests/test-review-door-diagnostics.sh), [tests/test-reviewer-events-isolation.sh](https://github.com/popcre/ai-devops/blob/main/tests/test-reviewer-events-isolation.sh) (custody probe; proven to fail without the fix), updated capacity-refusal expectations in [tests/test-ai-review-engine.sh](https://github.com/popcre/ai-devops/blob/main/tests/test-ai-review-engine.sh).
  - Independent review: Grok final-check **APPROVE** on exact head `369483229771af124122d294827dd430baa8598f` (comment on PR #1599). Codex is not installed on edge-dev3.
- **Not done:** live proof on a Windows dev host (#1562 live-proof item stays unticked).
- **Pre-existing failure:** `deepseek_real_unittest_keeps_immutable_snapshot_digest` in tests/test-ai-review-engine.sh fails on edge-dev3 on unmodified `c5df4dfa` too. Not caused or touched by this work.
- **EDGE-ALIEN cleanup (done 2026-10-12):** scheduled tasks `blocker-watch` and `worktree-reap` unregistered. `C:\repos\ai-devops` and six review copies (`ai-devops-sync-{2131,544d,8e1b,9b53,c984}-review`, `coordinator-first-review-20261008`) were **moved** (not deleted) to `C:\retired\ai-devops-20261012\` on that host. Kept: Actions runner service `actions.runner.popcre-ai-devops.EDGE-ALIEN` (running), `WindowsRunnerMaintenance` task (installed under Program Files, independent of the checkout), all of `~/.ssh` (916-alien key, `ai-devops.conf`, `config`, `ai-lan-probe`, known_hosts), 16 Claude transcripts, `C:\repos\popdam`.

## 4. Everything we tried that did NOT work

- `bin/ai-review codex ...` on edge-dev3: "Codex command not found"; used Grok instead.
- `reviewer_credit_run test-provider` in a regression: the supervisor rejects unknown providers; the probe uses `deepseek`.
- First move of `C:\repos\ai-devops` on EDGE-ALIEN failed (open Claude desktop sessions held a worktree); succeeded after Albert closed Claude.

## 5. Root causes and key findings

- The door exported `DOOR_DIAGNOSTICS_DIR` etc. into its own environment; the native OpenCode process and every command the model ran in its copy inherited them. tests/test-review-door-diagnostics.sh does not source `tests/lib-test-harness.sh`, so nothing scrubbed them, and a `${DOOR_DIAGNOSTICS_DIR:-...}` default wrote into the live path.
- Earlier env-isolation fix (2026-10-11, attempt #3) only scrubbed suites that source the harness; the native launch boundary is the right single place.
- The `STUB dir=... PWD!=DIR` string is not in the repo; the reviewer model generated it inside its copy.
- EDGE-ALIEN's Tailscale IP is now **100.112.207.98** (was 100.65.60.70); host key had to be accepted anew.

## 6. Exact next steps

1. Live proof on **4837** (never EDGE-ALIEN): update its installed toolkit to current main through the reviewed install path, run a real DeepSeek `final-check` with `--tests "bash tests/test-review-door-diagnostics.sh"`; prove a verdict, no custody variables in the reviewer/tests children, and collision retention. Post evidence on [#1562](https://github.com/popcre/ai-devops/issues/1562) and tick its live-proof item.
2. Separately, root-cause `deepseek_real_unittest_keeps_immutable_snapshot_digest` (pre-existing) under reviewer-safety class with independent review.

## 7. Constraints and gotchas in force

Reviewer-safety class: independent non-Claude exact-head review, merge queue. EDGE-ALIEN is not a dev machine. Use `bin/ai-gh`/`bin/ai-pr-wait --repo popcre/ai-devops`. `test-ai-glm.sh` "a poll that recovers stops retrying" flaked once in CI (passed 3/3 locally).

## 8. Access and environment

EDGE-ALIEN: `ssh -i ~/.ssh/916-alien 100.112.207.98` (Tailscale only). 4837: see memory/atlas. No secrets appeared this session.

## 9. Open questions and risks

Old Claude chats on EDGE-ALIEN pointed at `C:\repos\ai-devops`; they may not reopen their project (transcripts intact).
