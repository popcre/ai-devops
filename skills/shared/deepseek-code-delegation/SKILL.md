---
name: deepseek-code-delegation
description: Hand real implementation work to DeepSeek (V4.1 Flash or V4 Pro) through the ai-deepseek OpenCode harness — DeepSeek edits files, runs builds and tests, and commits on its own branch in a private remote-less clone; the calling agent lands, reviews, and opens the pull request. Use for "have DeepSeek build/implement/fix X", "delegate this to DeepSeek", "let DeepSeek write the code". For a DeepSeek opinion or formal rotation review, use deepseek-second-opinion instead.
---

# deepseek-code-delegation

`ai-deepseek` runs DeepSeek inside the pinned OpenCode agent harness with
write, edit, and shell tools. It is the only supported way to let DeepSeek
change code. Formal rotation reviews stay on the read-only `ai-deepseek-agent`
(skill `deepseek-second-opinion`); never use this harness for a review verdict.

## Run it

1. Write a self-contained brief to a file: goal, files in scope, how to test,
   and what "done" means. DeepSeek sees only this brief and the repository.
2. Start the task (a private clone of the default branch, with no remote):

       ai-deepseek implement <task-name> --repo <repo-path> --prompt-file <brief>

   Add `--model deepseek-v4-pro` for harder work; `deepseek-flash` is default.
3. Continue the same conversation, with its full memory, as often as needed:

       ai-deepseek ask <task-name> --prompt "..."

4. Verify: `ai-deepseek diff <task-name>` shows its commits and changes. Read
   the diff yourself and rerun the tests yourself; DeepSeek's own report is a
   claim, not proof. The last output line names the full event log.
5. `ai-deepseek land <task-name>` fetches the committed branch into the real
   repository as `deepseek/<task-name>`. Ship it from your own worktree under
   the repository's normal rules (Git identity check, push, pull request,
   checks). The clone has no remote, so DeepSeek cannot reach GitHub itself.
6. `ai-deepseek cleanup <task-name>` deletes the clone; it refuses while commits
   are not landed unless you pass `--force`.

`ai-deepseek doctor --live` proves OpenCode, the profile, the 1Password key
reference, and one real DeepSeek turn.
