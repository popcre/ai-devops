---
name: deepseek-code-delegation
description: Hand real implementation work to DeepSeek (V4.1 Flash or V4 Pro) through the ai-deepseek OpenCode harness — DeepSeek edits files, runs builds and tests, and commits on its own branch in a dedicated worktree; the calling agent reviews and opens the pull request. Use for "have DeepSeek build/implement/fix X", "delegate this to DeepSeek", "let DeepSeek write the code". For a DeepSeek opinion or formal rotation review, use deepseek-second-opinion instead.
---

# deepseek-code-delegation

`ai-deepseek` runs DeepSeek inside the pinned OpenCode agent harness with
write, edit, and shell tools. It is the only supported way to let DeepSeek
change code. Formal rotation reviews stay on the read-only `ai-deepseek-agent`
(skill `deepseek-second-opinion`); never use this harness for a review verdict.

## Run it

1. Write a self-contained brief to a file: goal, files in scope, how to test,
   and what "done" means. DeepSeek sees only this brief and the repository.
2. Start the task (the worktree branches from the repository's default branch):

       ai-deepseek implement <task-name> --repo <repo-path> --prompt-file <brief>

   Add `--model deepseek-v4-pro` for harder work; `deepseek-flash` is default.
3. Continue the same conversation, with its full memory, as often as needed:

       ai-deepseek ask <task-name> --prompt "..."

4. Verify: `ai-deepseek diff <task-name>` shows its commits and changes. Read
   the diff yourself and rerun the tests yourself; DeepSeek's own report is a
   claim, not proof. The last output line names the full event log.
5. Ship from the task worktree under the repository's normal rules (Git
   identity check, push the `deepseek/<task-name>` branch, pull request,
   checks). DeepSeek cannot push, change remotes, or run `gh`/`op`.
6. `ai-deepseek cleanup <task-name>` removes the worktree once the branch is
   pushed or merged (`--force` also deletes the local branch).

`ai-deepseek doctor --live` proves OpenCode, the profile, the 1Password key
reference, and one real DeepSeek turn.
