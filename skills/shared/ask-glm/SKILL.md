---
name: ask-glm
description: Delegate a repository analysis, code review, debate, second opinion, or scoped implementation to Z.ai GLM through the persistent `ai-glm` session harness. Use when the user says "ask GLM," "run this by GLM," "get GLM's opinion," requests GLM-5.2, wants an independent GLM review, or explicitly delegates repository work to GLM.
---

# Ask GLM

GLM runs in **named, persistent sessions** hosted by a local OpenCode server. A session
remembers everything said in it, survives a server restart, and keeps its context warm so
the provider can serve most of it from cache. The point of this skill is to use that
instead of starting a fresh conversation for every question.

If `ai-glm doctor` says the Windows task is stopped or its bounded recovery attempts
were exhausted, do not create a replacement conversation or bypass the local service.
Fix any named error, run `ai-glm server start`, verify doctor passes, and continue the
same named session with `ai-glm ask`. Unexpected child crashes are retried three times
at one-minute intervals; an intentional service stop is not auto-restarted.

## Use `ai-glm`. Never call OpenCode directly.

```bash
ai-glm new <name>   --prompt-file "$brief"    # start a review session
ai-glm ask <name>   --prompt-file "$next"     # continue that same session
ai-glm implement <name> --prompt-file "$task" # write run in a throwaway sandbox clone
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

**This is mandatory, and the user must never have to ask for it.** Run `ai-glm list`
before creating anything:

```bash
ai-glm list
```

If any existing session covers this topic, this repository, and this workstream, you
MUST continue it with `ai-glm ask`. Only call `ai-glm new` when nothing existing fits.
When in doubt, continue rather than create.

A fresh session re-reads the repository, loses every conclusion already reached, and
pays full price for context the old session already has cached. It also costs the
calling agent more, because a continued session needs a short follow-up instead of a
full re-brief.

Do not wait to be told to reuse a session, and do not ask the user which session to use
when `ai-glm list` makes it obvious.

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

**Known active defect (2026-08-10):** implementation jobs are not yet shown by
`ai-glm list`, locked by name for the full run, or abortable by name. A missing list
entry or patch does not mean the wrapper process stopped. Never retry the same
implementation name until the original `ai-glm implement` command reaches a terminal
result. The permanent fix is tracked in `plan_glm-implementation-job-tracking.md` in the
ai-devops repo; read its STATUS table before modifying the harness.

It creates a throwaway clone with its git remote removed, lets GLM edit and run
builds/tests inside it, writes the result out as a patch under `.ai/reviews/`, and
**deletes the sandbox before it exits** - every time, including on crash or interrupt.
Nothing accumulates and nothing is ever left for the user to merge or clean up.

GLM has a shell there, so ask it to run the tests and report the real output. It cannot
push: the sandbox has no remote, which is the actual control. OpenCode 1.18.12 does not
enforce bash allow/deny rules, so never rely on those.

You still review the patch and re-run the tests yourself before applying anything.

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

Use the provider-neutral contract at `templates/delegation/debate-turn.md`. Keep its
headings stable. Faithfully relay the other model's actual reasoning as ordinary message
text, point to current plan or diff paths, add only the delta and new evidence, and ask
GLM to re-read those paths before marking claims confirmed, unsupported, or wrong. Keep
the consensus ledger current. Do not rewrite the session's system prompt to indicate who
is speaking.

Run `ai-glm list` first and reuse the exact named session with `ask`. Use the shared
bounded-convergence rule: initial review plus at most three rebuttal turns unless the user
explicitly asks otherwise. Stop on evidence-backed consensus or the turn bound, and
report unresolved objections rather than pretending agreement. GLM does not report money,
so the Grok dollar ceiling in the shared workflow does not apply to GLM.

## Verify before you believe it

GLM's answer is an independent opinion, not authority.

- Treat a nonzero exit, auth error, missing result, or model mismatch as failure. Report
  the failure; never quietly hide it or substitute your own answer as if it were GLM's.
- Every response carries a `tokens` block including `cache.read`. It is recorded in the
  report under `.ai/reviews/`. Use it rather than guessing at savings.
- For implementation, inspect every hunk of the patch and run the tests yourself before
  recommending it.
- Say plainly when you disagree with GLM and why.

If a permission cannot be safely classified or approved, `ai-glm` now fails immediately
with a sanitized diagnostic instead of waiting for the 30-minute turn limit. Run
`ai-glm abort <name>` before retrying. If the request tried to read outside the session
repository, deliberately put a safe copy inside the repository or provide a small safe
excerpt. Never approve every permission and never copy an arbitrary outside file
automatically. A `glob` or `grep` failure can also mean a very large untracked directory
is being walked; add that directory to `.gitignore` when appropriate.
