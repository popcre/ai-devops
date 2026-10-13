# Housekeeping

One command shows what might need cleaning up in this repository. It never
deletes anything.

```bash
ai-housekeeping             # one-screen summary
ai-housekeeping --details   # every artifact, one labelled block per class
ai-housekeeping --log       # also append a dated block to the housekeeping log
ai-housekeeping --quiet     # print nothing when there is nothing to review
ai-housekeeping schedule    # register the daily timer
ai-housekeeping unschedule  # remove that timer
```

Albert can run this at any time without asking an AI session to do the
inventory. A session that is wrapping up should run it and include the summary
in the closing report.

## Log and daily schedule

`--log` appends a dated block to `$HOME/.cache/ai-housekeeping.log` (override
with `AI_HOUSEKEEPING_LOG`). The latest 30 dated daily blocks are kept; older
blocks are dropped by a recoverable rewrite through a temp file. A scheduled
`--quiet` run with no findings writes one line to the log and nothing else.

**Windows** — `bin/setup-machine.ps1` registers a daily Scheduled Task named
`AiDevOps-Housekeeping` (hidden VBS launcher, 15-minute cap, no wake). The
report is cheap and offline-tolerant: when GitHub is unreachable it logs
`UNKNOWN` and exits 0. It never blocks, never retries in a loop, and never
wakes a sleeping machine.

**Ubuntu / Linux (decision O2)** — a user-level crontab convention already
exists in this repo (`ai-blocker-watch`, `ai-reap-shared-db-worktrees`,
`ai-local-watch`), so `ai-housekeeping schedule` installs the same style of
marked, idempotent daily crontab entry. `install.sh` runs that stage. No
systemd user unit is added.

## What it looks at

Every line is labelled with the regime it belongs to. That matters because
cleaning a machine-local item is safe for this clone only, while cleaning a
git-shared item is a commit in a repository several sessions write to.

| Class | Regime | What it is |
|---|---|---|
| Worktrees | machine-local | Extra working folders registered with `git worktree list`. Found through Git's own records, so hidden ones under `.claude/` or `C:\tmp` are included. |
| Branches | machine-local (unless separately pushed) | Local branches other than `main`. Also flags branches that share an identical commit and branches with no worktree. |
| Handoff files | git-shared | Files under `HANDOFF.d/`. Each should open with the contract block (`issue:`, `status:`, `owner:`). |
| Plan files | git-shared | Root `plan_*.md` implementation plans. Classified only — never proposed for deletion. |
| Agent job records | machine-local | Provider job state under `~/.local/state/ai-devops/{glm,kimi,qwen}`. |
| Odd refs | clone-local | `refs/codex/turn-diffs/checkpoints/*` leftovers. Nobody currently owns them and no remedy is known. |

## What the labels mean

**LIVE** — dirty working tree, or a pull request is still open. Do not touch.

**MERGED CANDIDATE** — clean, the pull request is merged, and the local commit
is exactly the commit GitHub recorded as the PR head. This is only an invitation
to review. It is never "safe to delete". Use the `cleanup-worktree` skill, which
checks ignored files, running processes, and unique local state first. A human
or an informed session runs that review; `ai-housekeeping` never does.

**UNKNOWN** — anything the tool could not prove. When `gh` is missing or not
authenticated, every worktree and branch is `UNKNOWN` and the tool says so
loudly. It never falls back to `git branch --merged`, which is wrong for squash
merges.

**SUCCESSOR REVIEW** (handoffs) — the `issue:` is already closed. That is a
review trigger, not proof the handoff is finished. Apply the successor rule in
the `handoff-writer` skill before deleting. Ownership is printed from the
`owner:` line, or `OWNER UNKNOWN` when it is missing.

**OPEN** (handoffs) — the issue is still open.

**UNPROVABLE** (handoffs) — `issue: none`, so nothing can ever prove completion
from GitHub.

**UNATTRIBUTED** (handoffs) — no contract block at all. After the contract
block became mandatory in this repo, that is a rule violation; only the author
can retire such a file.

**active** (plans) — at least one STATUS row is not done.

**retained record — review by hand, do not delete** (plans) — every STATUS row
is done. These are deliberate history (see the plan's rejected approach R4).
They are not litter.

## Who may clean things up

| Class | Who | How |
|---|---|---|
| MERGED CANDIDATE worktrees / branches | a human or an informed session | `cleanup-worktree` skill (one at a time; prove no unique uncommitted work first) |
| SUCCESSOR REVIEW handoffs | the successor session | `handoff-writer` successor rule's three proof conditions |
| UNATTRIBUTED handoffs | the author only | add the contract block, then follow the successor rule |
| Agent job records | the owning wrapper | `ai-glm doctor` / `ai-kimi doctor` / `ai-qwen doctor` and their own `delete` subcommands. No age-based expiry. |
| Odd refs | nobody yet | no remedy is known; report and leave alone |
| Plan files | nobody | retained records stay |

`ai-housekeeping` itself has no `--apply`, `--fix`, or `--clean` flag, and never
will within this plan. Report-only is the whole design.

## Related

- Plan and locked decisions (including O2: Windows task + Ubuntu crontab):
  [`../plan_repo-housekeeping-visibility.md`](../plan_repo-housekeeping-visibility.md)
- Worktree removal procedure: `skills/shared/cleanup-worktree/SKILL.md`
- Handoff contract and successor rule: `skills/shared/handoff-writer/SKILL.md`
