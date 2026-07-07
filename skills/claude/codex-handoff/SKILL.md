---
name: codex-handoff
description: Hand a substantial implementation, ops, or verification task off to Codex (GPT-5.x) and drive it to completion, then verify its work. Use whenever the user says "use codex", "have codex do X", "hand this off to codex", "use the codex-cli MCP", "delegate this to gpt-5", or wants a second engine to build/run/prove something autonomously — especially long tasks worth running in the background. Also use when the codex-cli MCP errors with "Codex CLI Not Found": this skill is the working path.
---

# codex-handoff

Codex (GPT-5.x, OpenAI's coding CLI) is a strong second engine on Albert's
machines. Claude is best at planning, review, and verification; Codex is fast and
reliable at implementation and at grinding through multi-step ops. The high-value
pattern is a **handoff loop**: Claude writes a tight brief → Codex executes
autonomously → Claude verifies the result. This skill captures how to run that
loop so the handoff is self-contained and the result is never trusted blind.

## Trigger phrases

- "use codex to…", "have codex do…", "hand this off to codex", "let codex build it"
- "use the codex-cli MCP to…" (see the transport note — the MCP is usually broken here)
- "delegate this to gpt-5 / the other model"
- any long implementation or prod-ops task the user wants run in the background

## Transport: use `codex exec` directly, not the MCP

The `codex-cli` MCP wrapper on Albert's Windows machines usually fails with
**"Codex CLI Not Found — install with npm install -g @openai/codex"**. That is a
false negative: it only looks for the npm-global package, but Codex is installed
via the standalone installer. The repo's own `bin/ai-codex-review` already drives
Codex with `codex exec` for the same reason. So:

1. **Try the `mcp__codex-cli__ask-codex` MCP tool first only if the user named it.**
   If it returns "Codex CLI Not Found", do NOT retry it — fall back to the CLI.
2. **Find the binary** (don't hardcode — Albert has several machines):
   `where codex` / `command -v codex`. The standalone install is typically
   `C:\Users\<user>\AppData\Local\Programs\OpenAI\Codex\bin\codex.exe`. Add that
   `bin` dir to `PATH` for the call if `codex` isn't already resolvable.
3. Confirm it runs: `codex --version` (expect `codex-cli <ver>`).

## Write a self-contained brief (this is the whole game)

Codex starts with a **clean context window** — it knows nothing about this chat.
The brief IS the handoff, so hold it to the `handoff-writer` standard: a stranger
who walked in this morning must be able to execute it with zero questions. Write
the brief to a file in the scratchpad (never inline a giant prompt on the command
line). Include, in this order:

- **The goal** — what to build/run/prove, stated as an outcome, not a vibe.
- **Exact anchors** — file paths, function names, commit SHAs, table/column names,
  Trigger task names, setting keys. Never "the relevant file"; name it.
- **Safety rules** — the load-bearing constraints. For this repo family that
  usually means: prod DB access ONLY via the 1Password session pooler (never the
  repo's local `.env.local`, which points at an OLD project); settings are
  single-encoded jsonb; **restore any prod state you mutate** and re-verify the
  restore; don't commit/push unless the user asked; **never paste secret values**
  into files or the report — tell Codex to fetch them from 1Password (`op`,
  vault `vibe_coding`) itself.
- **The plan** — the steps, in order, with the exact verification query/command at
  each gate and the expected result. Give Codex room to adapt, but pin the
  contract and the safety rails.
- **The required report** — tell Codex its final message must be a structured
  report: commands run, observed results/evidence, any diff, a clear PASS/FAIL
  verdict, and anything it could NOT complete and why.

## Run it (background for anything non-trivial)

Long tasks (prod runs, multi-file builds, test loops) should run in the
background so partial work survives and the chat stays light — this mirrors
Albert's standing "long operations as background tasks" rule. Capture Codex's
final report to a file with `-o`.

```bash
export PATH="$PATH:/c/Users/<user>/AppData/Local/Programs/OpenAI/Codex/bin"
SP="<scratchpad-dir>"
codex exec \
  --dangerously-bypass-approvals-and-sandbox \  # non-interactive: no one can answer prompts
  -C "C:\\path\\to\\repo" \                       # working root
  -o "$SP/codex-report.md" \                      # final message → file
  --color never \
  - < "$SP/codex-brief.md" \                      # brief via stdin
  > "$SP/codex-stdout.log" 2>&1
```

Notes on the flags:
- `--dangerously-bypass-approvals-and-sandbox` runs fully autonomous with machine
  access. It IS powerful — that is exactly why the brief must scope the task,
  forbid commit/push unless asked, and hand Codex a **restore checklist** for any
  prod state it touches. Prefer `-s workspace-write` when the task is purely local
  and needs no network/prod/1Password access.
- `- < brief.md` feeds the brief on stdin; `-C` sets the repo root.
- After launching in the background, peek at `codex-stdout.log` once to confirm it
  started clean (model line, no auth/config error) — then let it run.

## Verify Codex's work — non-negotiable

Albert's standing rule: **verify a sub-agent's / Codex's work.** Every session
that has done this caught real bugs in otherwise-good Codex output by reading the
diff and running the gates. When Codex reports done:

1. **Read the report** (`codex-report.md`) and the diff (`git diff`) yourself —
   don't take the verdict at face value.
2. **Re-run the gates** the task should satisfy: typecheck / the repo's `verify:*`
   scripts / `git diff --check`.
3. **Independently confirm outcomes** with your own tools where you can — e.g.
   read prod state via the Trigger/Supabase MCPs rather than trusting Codex's
   quoted query output; **and confirm any mutated prod setting was actually
   restored.**
4. Only then report to Albert with evidence (SHAs, run ids, query results), and
   flag anything Codex skipped or couldn't finish.

## Anti-patterns

- Inlining a huge prompt on the command line instead of a brief file.
- Retrying the `codex-cli` MCP after "Codex CLI Not Found" — fall back to the CLI.
- Letting Codex commit/push, or run prod mutations, without a restore checklist.
- Reporting Codex's PASS to Albert without independently re-verifying it.
- Pasting a connection string, token, or key into the brief — point Codex at
  1Password instead.
