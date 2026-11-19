---
issue: 2685
status: OPEN
owner: claude/albert-github-quota-consumers-8d9dcf
---

# Handoff — personal GitHub allowance: find the remaining burst source

## 0. Business decisions only the owner can make

None. Nothing in this workstream needs the owner. Every remaining step is technical work the AI does itself.

Already settled (do NOT re-ask):
- Repair or redirect every consumer and never disable, bypass or delete one (Albert's job brief, 2026-11-18).
- Do not touch the edge-dev3 heartbeat timer, `plan_heartbeat-shared-note.md`, or popcre/ai-devops#2346 (job brief, 2026-11-18).
- Do not use Entire (owner ruling, 2026-11-04).

## 1. What this is

Albert's personal GitHub login `u2giants` has one hourly allowance of 5,000 core REST requests. Every machine that uses that login shares it: hetz (Linux server, user `ai`), edge-dev3 (Linux, user `ahazan`, hosts the self-hosted Actions runners), edge-dev (Windows), and any GitHub Actions secret that holds his personal token. When the allowance runs out, every AI session and watcher on every machine stops working. Target: steady use well under 1,000/hr, with no capability removed.

## 2. Goal of the session that wrote this

Measure what consumes the allowance and cut it by repairing or redirecting each consumer. The session started at about 6,400/hr (5:09 PM EST, 2026-11-18). That spike came from a transient edge-dev3 Claude session polling the actions jobs endpoint; it has since stopped. After it ended, the steady level was about 3,000–4,300/hr.

## 3. Current state (11:05 PM EST, 2026-11-18)

Fixed, merged and proven:
- popcre/shared-db#6767, fixed by PR https://github.com/popcre/shared-db/pull/6768. The runner heartbeat script https://github.com/popcre/shared-db/blob/main/scripts/ci/edge-runner-heartbeat.sh now reads runner state from local processes and writes the repository variable only when the state changes or every 110 s. Load fell from about 120/hr to about 33/hr. It is installed on edge-dev3 at `~/.local/libexec/shared-db-runner-heartbeat.sh`, copied from merged main.
- popcre/shared-db#6772, fixed by PRs https://github.com/popcre/shared-db/pull/6773, https://github.com/popcre/shared-db/pull/6779 and https://github.com/popcre/shared-db/pull/6789. The DesignFlow release observer now does its reads with a read-only App token (`DFLOW_GITHUB_READ_TOKEN`), routed in `runGitHubCommand` in https://github.com/popcre/shared-db/blob/main/scripts/lib/github-transport.mjs. PR 6789 added a counts-only receipt step, https://github.com/popcre/shared-db/blob/main/scripts/report-observer-allowance.mjs. Run 44447934753 printed `OPERATOR_TOKEN used=0`, `READ_TOKEN used=451`.

Measured but not fixed: a 31-minute window, 10:19–10:50 PM EST, used 832 requests, about 1,610/hr. The shape was a baseline of 1–10 per minute plus bursts: 10:28–10:33 PM (about 270) and 10:48–10:50 PM (about 200). In a further 6 minutes (10:50–10:57 PM) usage rose by about 270.

Nothing is uncommitted. This handoff file is the only change in this branch.

## 4. What did NOT work, or misled

- **Blaming the observer from timing alone.** Usage bursts lined up with the observer's run windows for three runs in a row. The receipt then showed the observer's operator token (`SYNC_TOKEN`) at used=0. So SYNC_TOKEN is not Albert's personal allowance, and the timing match was a coincidence, or a reaction to the same merge-queue activity. Do not re-blame the observer without a receipt.
- **PR 6773 alone** (routing inside `command()` in `designflow-db-release.mjs`) changed nothing, because most reads call the transport directly. PR 6779 fixed this at the transport.
- **Process tracers undercount requests.** They count `gh` processes, not HTTP requests. One `gh api --paginate` makes many requests. Direct HTTP (curl, node fetch) and other machines are invisible to them. In the 10:50–10:57 PM window, hetz showed about 60 `gh` processes while usage rose about 270.
- **A raw `gh api` step in a shared-db workflow** fails the "GitHub transport conformance" test. Workflow GitHub calls must go through a script that uses `scripts/lib/github-transport.mjs`.
- **`gh run watch` was denied** in this session, and it is known to burn the allowance. Use a slow status loop instead (Monitor, 90 s).
- The rate_limit window resets hourly, so a reset mid-window makes `used` drop. Always record the `reset` epoch next to `used`.

## 5. Findings

- Calling `rate_limit` is free. Take two `used` readings and use the difference. Compute times on hetz with `TZ=America/New_York date`, because the TZ setting in Windows Git Bash is broken.
- Visible repeat personal-login callers:
  - **hetz**: `bin/ai-local-watch claim/tick-all`, which edits and views popcre/ai-devops#1288 about 8 times per 5 minutes. Each run also makes a `rate_limit` call and a `gh auth token` call, both free.
  - **hetz**: `bin/ai-windows-queue-watch tick`.
  - **hetz**: interactive Claude and ZCode sessions (shell-snapshot parents). Examples are merge-queue `gh run list`, `git/trees` reads, and `issues?state=` pagination.
  - **edge-dev3**: `ai-local-watch tick-all`, `pr-status-complete`, the heartbeat, and a Codex desktop app.
- Runner jobs on edge-dev3 mostly use `ghs_` App or job tokens, not the personal login.
- edge-dev (Windows) has not been traced per process. Earlier it held about 9 GitHub connections a minute.

## 6. Exact next steps

1. Catch a burst at request level, not process level. On hetz and edge-dev3, sample `used` every 10 s. Alongside it, log every new `gh` process with its full argv and parent chain, flagging `--paginate`. Also log new TCP connections to `api.github.com` per process: on Linux, `ss -tnp` every second, recording pid and command. Run this for 15 minutes. You'll know it worked when a 10-second window with +30 or more requests can be tied to a named process or machine.
2. If no host process explains a burst, list the Actions secrets that hold the personal token: org and repo secrets in popcre with names like `*_PAT`, `SYNC_*`, `GH_*`. Match workflow runs in those repos against burst times. You'll know it worked when one workflow's run windows match the bursts and its token is confirmed personal, using a counts-only receipt step like PR 6789.
3. Repair the cause found. Use an App installation token for reads, cache conditional requests (ETag), or cut a polling interval. Do it by branch and PR on the owning repository, merged by the AI. Host changes come only from merged main. You'll know it worked when that source no longer appears in step 1's trace.
4. Final proof: a 30-minute or longer `used` series on hetz below 500 requests (under 1,000/hr), posted with counts only on #2685. Then delete this file in the PR that closes #2685.

## 7. Constraints and gotchas

- Never disable, bypass or delete a consumer. Repair or redirect it.
- Leave the edge-dev3 heartbeat timer and popcre/ai-devops#2346 alone.
- Sign GitHub posts. Post counts only, never transcript text.
- shared-db merges go through a merge queue (`gh pr merge --squash --auto`). Wait with `bin/ai-pr-wait --repo popcre/shared-db <pr>` in the background (`--repo`, not `-R`).
- Merge-queue "Database Contract Tests" can fail transiently. Check main's recent result before chasing it.

## 8. Access

- hetz: `ssh -i ~/.ssh/916-alien -o IdentitiesOnly=yes root@hetz`. The `gh` login there is the personal one.
- edge-dev3: `ssh edge-dev3`.
- The pop-ai-watchers App credentials are shared-db secrets `POP_AI_WATCHERS_APP_ID` and `POP_AI_WATCHERS_PRIVATE_KEY`. Other secrets are in 1Password vault `vibe_coding`.
- Tracer scripts are scratch copies only: `/tmp/ghtrace3.py` on hetz, and `/tmp/ghtrace2.py` and `/tmp/tr.py` on edge-dev3. They are not in any repository.

## 9. Open questions and risks (2026-11-18)

- Is the burst source on a machine or in a GitHub Actions secret? Unknown. Step 1 decides.
- Interactive AI sessions are real work and will always use some allowance. Before trying to cut them, decide whether they are small enough.

Self-audit (2026-11-18):
1. A newcomer could continue: §1–§3 give the context and state, and §6 gives the steps.
2. As effective as the writer: §4–§5 hold every finding and dead end.
3. All needed details are present: §3 has proof, §7 constraints, §8 access, §9 risks.
4. Owner decisions: a sweep of §1–§9 found none, and §0 says so.
