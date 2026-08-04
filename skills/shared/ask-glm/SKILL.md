---
name: ask-glm
description: Delegate a repository analysis, code review, debate, second opinion, or scoped implementation to Z.ai GLM through the persistent `ai-glm` session harness. Use when the user says "ask GLM," "run this by GLM," "get GLM's opinion," requests GLM-5.2, wants an independent GLM review, or explicitly delegates repository work to GLM.
---

# Ask GLM

GLM runs in **named, persistent sessions** hosted by a local OpenCode server. A session
remembers everything said in it, survives a server restart, and keeps its context warm so
the provider can serve most of it from cache. The point of this skill is to use that
instead of starting a fresh conversation for every question.

## Use `ai-glm`. Never call OpenCode directly.

```bash
ai-glm new <name>   --prompt-file "$brief"    # start a review session
ai-glm ask <name>   --prompt-file "$next"     # continue that same session
ai-glm implement <name> --prompt-file "$task" # scoped write run, throwaway worktree
ai-glm list | show <name> | transcript <name> | diff <name>
ai-glm abort <name> | delete <name> | doctor | server status
```

Do **not** run `opencode`, `opencode run`, `opencode serve`, or curl the server's HTTP
API. `ai-glm` owns the server URL, credentials, API shapes, model pin, locking, and
read-only enforcement. Bypassing it bypasses all of that.

The command is identical on Windows and Ubuntu: type `ai-glm`. On Windows it resolves
to a shim that runs the same script, so use the same syntax from PowerShell that you
would use on Ubuntu. Prefer `--prompt-file` over `--prompt` there, so quoting can never
mangle a long brief.

Two Windows-only differences:
- Service control is `Start-ScheduledTask -TaskName AiDevOps-OpenCodeGlm` (and
  `Stop-ScheduledTask`), not `ai-glm server start`.
- If `ai-glm` is not found, the machine has not been set up yet. Run
  `bin\setup-opencode-glm.ps1` once (it installs its own prerequisites), or fall back to
  running `ai-glm` on the Ubuntu host over SSH. Do not tell the user to open Git Bash.

## Continue a session. Do not start a new one per question.

Before creating anything:

```bash
ai-glm list
```

If a session already covers this topic, continue it with `ai-glm ask`. A fresh session
re-reads the repository, loses every conclusion already reached, and pays full price for
context the old session already has cached.

Name sessions after the work: `auth-token-rotation-review`, `sample-status-migration`,
`pdf-extraction-model-routing`. Never `review`, `glm`, `task`, or `new-session`.

Claude and Codex keep **separate** sessions. The session key includes the calling agent,
so both can use the same short name in the same repo without colliding. Set
`AI_GLM_CALLER=codex` when running from Codex.

## Review is the default

Use a review session for opinions, plan reviews, code reviews, debugging, architecture
debate, security analysis, test analysis, and challenging another model's conclusion.

Review sessions are **structurally** read-only: the review agent has no write, edit,
patch, or bash tool at all. GLM cannot change files and cannot run tests or commands. If
a question needs a command run, run it yourself and paste the output into the next turn.
`ai-glm ask` also snapshots `git status` before and after and fails loudly if the tree
changed.

## Implementation is explicit and disposable

Use `ai-glm implement` only when the user explicitly asks GLM to write or change code.

It creates a throwaway git worktree, lets GLM edit inside it, writes the result out as a
patch under `.ai/reviews/`, and **deletes the worktree before it exits** — every time,
including on crash or interrupt. Nothing accumulates and nothing is ever left for the
user to merge or clean up.

The implement agent has no bash tool either, so GLM cannot run the tests. That is
deliberate: OpenCode 1.18.12 does not enforce bash allow/deny rules, so an enabled bash
tool would be unrestricted and could reach the real git remote. **You** run the tests.

Review the patch before applying it:

```bash
git apply --check "$patch" && git apply "$patch"
```

## Do not try to override the session's configuration

`--model`, `--agent`, `--system`, `--tools`, `--provider`, `--directory`,
`--temperature` and `--reasoning` are rejected on purpose. They are fixed when the
session is created. A stable request prefix is what lets the provider serve cached
context, and a stable agent is what keeps a review session read-only.

Keep your own prompts prefix-stable too: put the new instruction at the end of the
message, and let GLM read files with its own tools rather than pasting file contents into
the prompt. Pasted text changes the prefix on every turn and defeats caching.

## Relaying a debate

When you are carrying an argument from another model, send that model's actual reasoning
as ordinary message text, and ask GLM to re-inspect the repository rather than rely on
memory. For example:

> Codex objects that the existing Redis lock already serializes rotation. Re-read
> `src/auth/rotate.ts` and evaluate that specific claim. Say which parts are confirmed,
> unsupported, or wrong.

Do not rewrite the session's system prompt to indicate who is speaking.

## Verify before you believe it

GLM's answer is an independent opinion, not authority.

- Treat a nonzero exit, auth error, missing result, or model mismatch as failure. Report
  the failure; never quietly hide it or substitute your own answer as if it were GLM's.
- Every response carries a `tokens` block including `cache.read`. It is recorded in the
  report under `.ai/reviews/`. Use it rather than guessing at savings.
- For implementation, inspect every hunk of the patch and run the tests yourself before
  recommending it.
- Say plainly when you disagree with GLM and why.

If a session wedges or a turn times out, `ai-glm` exits nonzero and names the stuck tool.
Run `ai-glm abort <name>`, then retry. If the stuck tool is `glob` or `grep`, the usual
cause is a very large untracked directory in the repository; add it to `.gitignore`.
