---
name: kimi-code-delegation
description: Delegate scoped coding work to Kimi Code CLI (`kimi`) in non-interactive prompt mode from Windows PowerShell or Ubuntu bash. Use when an AI session should drive Kimi headlessly, split planning from execution, resume a prior Kimi session, constrain exploration, or verify Kimi-authored changes without relying on the interactive TUI.
---

# Kimi Code Delegation

Drive Kimi headlessly and treat the calling session as planner, reviewer, and quality gate.

## Copy this block. Do not hand-assemble a `kimi` command.

Kimi reports **neither the model nor token usage** in headless output. The only guarantee
it ran K3 is that you copied this block verbatim. A dropped `-m` silently falls back to
K2.7 and nothing in the output reveals it. Treat any hand-assembled `kimi` command as
unverified. This is why the block matters more here than for Grok or GLM, where the
returned model and usage are printed and can be asserted on.

```bash
# 1. First call. Captures the session id.
out=$(kimi -m kimi-code/k3 -p "$brief" --output-format stream-json)
sid=$(printf '%s\n' "$out" | jq -rs '[.[] | select(.type=="session.resume_hint")][-1].session_id')
[ -n "$sid" ] && [ "$sid" != "null" ] || { echo "ERROR: no Kimi session id captured" >&2; exit 1; }

# 2. Every follow-up. Same session, context already warm.
kimi -r "$sid" -p "$next_instruction"
```

```powershell
$out = & kimi -m kimi-code/k3 -p $brief --output-format stream-json
$sid = ($out | ForEach-Object { $_ | ConvertFrom-Json } |
        Where-Object { $_.type -eq 'session.resume_hint' } |
        Select-Object -Last 1).session_id
if (-not $sid) { throw 'ERROR: no Kimi session id captured' }
& kimi -r $sid -p $nextInstruction
```

Use `jq`, not a hand-rolled `grep`/`cut`. A stray space after a colon or a differently
ordered record silently yields the wrong id, which is the exact bug class this section
exists to prevent.

## Verify the local CLI

1. Run `kimi --version` and `kimi --help`; prefer the installed CLI over remembered
   flags. Ubuntu: `~/.kimi-code/bin/kimi`. Windows: invoke from PowerShell.
2. Run `kimi provider list` and confirm `kimi-code/k3` exists before pinning it.
   **The configured default is `kimi-code/kimi-for-coding` (K2.7), not K3.** That is why
   every call above pins `-m kimi-code/k3`. Use `kimi-code/k3-256k` only when the task
   genuinely needs the larger context; switching model mid-workstream discards the
   cached prefix, so pick once per workstream and stay there.
3. Verify authentication with `kimi -m kimi-code/k3 -p "reply with OK"`. If it fails,
   run `kimi login` once.
4. Read the target repository's `AGENTS.md` before delegating.
5. Record the working tree's starting `git status`.

Prompt mode rejects `-p/--prompt` combined with `--plan`, `--auto`, or `-y/--yolo`
(verified on 0.31.1; the same restriction existed on 0.27.0). Prompt mode already handles
regular approvals automatically while keeping static deny rules. Do not add interactive
permission flags to a `-p` command. Re-verify with `kimi --help` before trusting any flag.

## Never use `-c/--continue`

`-c` means "the newest session for this working directory", **not** "the session I was
just using". Measured failure: session A was told a codeword, an unrelated `-p` call then
created session B in the same directory, and `kimi -c -p "what is the codeword"` answered
from B and got it wrong. With 3-7 AI sessions running against one repo, the newest
session is routinely not yours.

Always capture `session_id` from the `session.resume_hint` record and resume with
`-r "$sid"`. This is not a style preference; it is the difference between resuming your
own work and silently resuming somebody else's.

## Plan, approve, then execute — in ONE session

`--plan` cannot be combined with `-p`, so planning and execution are two calls. They must
be two calls **in the same session**, or the execution call re-explores everything the
planning call already learned and you pay for the whole prefix twice.

```bash
# 1. Planning call. Capture $sid using the block above.
#    Brief: "Produce a read-only implementation plan for <task>. Read only <paths>.
#            Do not modify files. List steps, files, risks, and verification gates."

# 2. Review and amend the plan in the calling session.

# 3. Execution call — SAME session.
kimi -r "$sid" -p "Implement exactly this approved plan: <amended plan>. Do not expand scope. Run <tests> and report the actual results."
```

Do **not** pass `--agent` or `--agent-file` on the planning call. Neither can be combined
with `--session`/`--continue`, so the agent is fixed when the session is created; a
read-only agent chosen for planning would leave the resumed execution call unable to
edit anything.

The cost of that: the planning call's read-only status is **prompt-enforced only**, with
no structural guarantee. So run `git status` after the **planning** call too, not just
after execution.

## Keep the prefix stable so caching can engage

- Keep the opening of every prompt in a workstream identical. Put the varying instruction
  at the END. Caching matches on a stable prefix; rewriting the opening invalidates
  everything after it.
- Do not paste file contents. Kimi has `Read`. Pasted text becomes prefix that changes on
  every call, which is the worst case for caching.
- Do not change `-m`, `--agent`, `--skills-dir`, or `--add-dir` mid-workstream.
- Prefer one session with several bounded turns over several fresh sessions.

Honest limitation: Kimi exposes no usage or cache counters in headless output, so these
are prefix-stability best practices, not verified savings. Grok and GLM print the
numbers; Kimi does not. Do not claim a percentage you cannot show.

## Keep each call bounded

- One scoped change and one verification target per execution call.
- Name exact paths in prose: `Read only path/to/a and path/to/b`. `@path` injection is
  documented for the interactive input box, not guaranteed for headless prompt strings.
- State when editing should begin and forbid unrelated exploration.
- State the build or test command and the done condition.
- Decompose dependent multi-file work and inspect the diff after each call.

On Windows, invoke Kimi from PowerShell and account for `C:\...` versus Git-Bash `/c/...`
paths. If Kimi cannot find its internal shell, verify Git for Windows and
`KIMI_SHELL_PATH`. On Ubuntu, use normal bash quoting and protect `$`, backticks, and
embedded quotes.

## Verify every execution

1. Inspect the actual diff; never trust the summary alone.
2. Run the relevant tests independently when Kimi's result is incomplete or ambiguous.
3. Feed exact failures back into the SAME session with `-r "$sid"`.
4. Stop if Kimi expands scope, edits protected files, or cannot prove completion.

## Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| Answers as if it never saw the earlier turn | Used `-c` and got another session, or no resume at all | Capture `session_id` from the resume hint and use `-r "$sid"` |
| Output quality looks like a weaker model | `-m kimi-code/k3` was dropped; nothing in the output shows the model | Re-run with the copy-paste block above |
| Execution call cannot edit files | An `--agent` was set on the planning call | Start over without `--agent`; it is fixed at session creation |
| Long analysis, no edits | Prompt is too broad | Split planning from execution and name exact paths |
| Repeats repository exploration | Fresh session lacks context | Resume with `-r <id>` and narrow the instruction |
| Authentication error | Login is missing or expired | Run `kimi login`, then repeat the trivial prompt check |
| Windows shell/path error | Git Bash is missing or mislocated | Verify Git for Windows and `KIMI_SHELL_PATH` |
| Flag rejected | CLI surface changed | Run `kimi --help` and update the invocation |

Official references: [command options](https://www.kimi.com/code/docs/en/kimi-code-cli/reference/kimi-command.html)
and [interaction modes](https://www.kimi.com/code/docs/en/kimi-code-cli/guides/interaction.html).
