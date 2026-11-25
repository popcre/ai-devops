---
summary: What the harness sensors (#2835) do, how to tell if they are slowing work down, and how to turn each one off or remove them entirely.
kind: ops
status: current
read-when: A Claude session is stopped by "no command that could fail checked the result", "Blocked: git reset --hard", "Blocked: rm -rf", "Blocked: a force-push", or "Blocked: git clean"; or work feels bogged down by hooks
---

# Harness sensors — what they do and how to undo them

Issue: [popcre/ai-devops#2835](https://github.com/popcre/ai-devops/issues/2835).
Plan and reasoning: [`../plan_harness-sensors.md`](../plan_harness-sensors.md).

## In plain words

Three small checks run inside Claude Code sessions on each machine. They cost no
AI tokens, run in a few hundredths of a second, never run in GitHub, never
block a merge, and never wait on anything.

1. **The empty-promise block now works.** Since 2026-10-21 a session that ends
   with "I'm running it now" while having done nothing was meant to be stopped.
   The way it was installed silently cancelled the stop, so it never happened.
   It now happens, once per request.
2. **Proof-of-done.** When a session changed files or pushed code in this
   request and then closes as if finished, it must have run a check that could
   fail (a test, a `--check`, `ai-pr-wait`, `curl --fail` on the live page)
   after its last change. If not, it is stopped **once per request** and told
   to run a check or say plainly what is unverified. A closing that already
   says "not tested", "pending", "still open", or ends in a question is left
   alone. A session that did check is never nudged, which is quieter than
   before.
3. **Dangerous-command guard.** Before a shell command runs, it refuses:
   - `git reset --hard`, `git checkout .`, `git checkout -- <files>`,
     `git checkout -f`, and `git restore <files>` when the folder has unsaved
     changes (or when it cannot tell which folder, or cannot check);
   - `git clean -f` in any spelling;
   - `git push --force`, `-f`, or `+branch` (`--force-with-lease` is allowed);
   - `rm -rf` on `/`, the home folder, `*`, `.`, `..`, or a `.git` folder.

   Each refusal names the safe way to do the same thing. Text such as commit
   messages, `echo`, and here-document bodies is never judged.

Everything fails open: if `python3` or `jq` is missing, or anything inside a
check breaks, the action is allowed.

## Where it lives

| Piece | File | Installed copy |
|---|---|---|
| Empty-promise fix and proof-of-done | `bin/ai-completion-check-hook` (`--sensors`) | `~/.config/ai-devops/completion-check-hook` |
| Registration (no `|| true`, adds `PostToolUseFailure`) | `bin/ai-install-completion-check-hook` | `~/.claude/settings.json` |
| Dangerous-command guard | `bin/ai-pr-poll-guard-hook` | `~/.config/ai-devops/pr-poll-guard-hook` |
| Tests | `tests/test-ai-completion-check-hook.sh`, `tests/test-ai-pr-poll-guard-hook.sh` | — |
| Real hook payload samples | `tests/fixtures/hooks/` | — |

Only Claude Code gets proof-of-done. ZCode and Antigravity use the same hook
file without `--sensors` and behave exactly as before.

## Signs it is bogging work down

Treat any of these as the trigger to turn a piece off (next section), then
record what happened on #2835:

- Sessions are stopped by "no command that could fail checked the result" on
  replies that were honest, more than about 1 in 10 times.
- A "Blocked:" message refuses a command that was safe, and the named safe
  alternative does not fit the job.
- A session loops or wedges at the end of a turn. (It should be impossible:
  each stop fires at most once per request. If it happens, it is a bug.)

## Turning a piece off (seconds, no code change, survives reinstall)

Each switch is an empty file in `~/.config/ai-devops/` on the machine where the
problem happens. Creating the file turns that piece off for every new session
there; deleting it turns the piece back on. No restart is needed.

| To turn off | Create this file | What still works |
|---|---|---|
| Proof-of-done | `~/.config/ai-devops/proof-of-done.off` | Everything else, including the old completion reminder |
| The empty-promise hard stop | `~/.config/ai-devops/promise-block.off` | The promise still gets the old soft reminder |
| The dangerous-command guard | `~/.config/ai-devops/destructive-guard.off` | The PR-polling-loop guard |

An AI session does this itself with, for example:

```bash
touch ~/.config/ai-devops/proof-of-done.off
```

and undoes it with `rm -f ~/.config/ai-devops/proof-of-done.off`. On Windows the
folder is `%USERPROFILE%\.config\ai-devops\`. Record each switch you create on
#2835, with the reason and the machine, so it does not stay off by accident.

## Removing it entirely

1. Revert the pull request that added this (find it from #2835) with a new
   pull request; do not push to `main`.
2. Install the result on each machine through the protected install in
   [`deployment.md`](deployment.md). Never `git pull` or run `install.sh`
   directly in the installed checkout.
3. Important: the old installer only **adds** a registration that is missing.
   It does not downgrade one that exists. After a revert, the registration in
   `~/.claude/settings.json` still says `completion-check-hook" --sensors`,
   which the reverted hook simply ignores (it reads no `--sensors` flag), so it
   is harmless, and the empty-promise stop stays active because nothing
   swallows exit 2. To restore the exact old behavior, also create
   `promise-block.off` (above).

## Checking the install

```bash
ai-install-completion-check-hook --check
ai-install-pr-poll-guard-hook --check
```

`OK` means current. `DRIFT` means the machine still has the old registration
(the one that swallowed the stop); rerun the installer through the protected
install to upgrade it in place.

## Known limits

- A passing check that has nothing to do with the deliverable still counts.
  Code cannot judge relevance; the written rule still covers that.
- Shell commands that change files without the usual verbs (`sed -i`, `mv`,
  `cp`) are not seen as changes, so they do not trigger proof-of-done.
- Text piped into a shell (`echo 'git reset --hard' | bash`) is not judged by
  the guard.
