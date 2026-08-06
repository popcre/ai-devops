---
name: grok-cli
description: Locate and use xAI's installed Grok CLI (`grok`, branded Grok Build) as an independent coding agent, including read-only reviews, repository analysis, explicit implementation delegation, session continuation, and local documentation lookup. Use when the user says "use Grok", "ask Grok", "run this by Grok", "Grok CLI", "Grok Build", requests a Grok second opinion, asks where Grok is installed, or explicitly delegates coding work to Grok.
---

# Grok CLI

Drive Grok headlessly and keep the calling Claude or Codex session responsible for
scope, safety, and verification.

## Non-negotiables — read before composing a single flag

Every one of these was learned from a run that wasted real money. If you are about to
deviate, you are about to repeat a known failure.

1. **The command returning does NOT mean Grok finished.** Never read `$out` on the next
   line. Use the wait-and-verify loop below. Exit 0 with a zero-byte file is the normal
   appearance of this bug, not an anomaly.
2. **Always pass `--max-turns 20`** (or higher for big reviews). Without it a review dies
   as a bare `stopReason: "cancelled"` after burning ~250k tokens.
3. **One session per workstream.** First call captures `sessionId`; every follow-up uses
   `--resume <id>`. Never start a second session because the first "looks dead" — check
   whether it is still running first.
4. **Read-only work uses `--permission-mode default --allow Read --allow Grep --deny Edit
   --deny Bash` and nothing broader.** A denied tool does not cancel the run; Grok says so
   and continues with other tools. If a run ends without an answer, the cause is the turn
   limit, not permissions.
5. **Never change the flag set mid-workstream** — model, allow/deny, `--no-memory`,
   `--cwd`. Each change invalidates the cached prefix and costs more than it saves.
6. **Diagnose before you relaunch.** `stopReason`, `pgrep -af grok`, and
   `~/.grok/logs/unified.jsonl` tell you what happened. Guessing and re-running multiplies
   the bill; three concurrent reviews of the same repo is the observed failure.

## One session per workstream, not one per question

This is the single biggest thing to get right. Measured on Grok 0.2.118 / grok-4.5,
same repo, same question shape:

| | uncached `input_tokens` | `cache_read` | `total_tokens` | answer |
|---|---|---|---|---|
| fresh session | 16,362 | 26,496 | **43,204** | wrong, no prior context |
| `--resume <id>` | 1,440 | 21,248 | **22,720** | correct, immediate |

Uncached input fell **91%** and total tokens fell **47%**, and the fresh session also
got the answer *wrong* because it had no memory of the earlier turn. Starting fresh is
both more expensive and less accurate.

Those figures come from a one-question probe. **Do not quote them as the cost of a real
review.** Measured full-repository reviews on the same version ran 250,000–530,000 total
tokens and $0.12–$0.46 *per turn*; one plan review with two wasted attempts and three
follow-ups totalled ~1.9M tokens and ~$1.28. The ratio holds; the absolute scale is an
order of magnitude larger.

Capture the session id on the first call and reuse it (`grok_wait` is defined in the next
section — do not read `$out` without it):

```bash
grok --cwd "$repo" --model grok-4.5 --single "$prompt" --max-turns 20 \
     --permission-mode default --allow Read --allow Grep --deny Edit --deny Bash \
     --output-format json --no-memory > "$out"
grok_wait "$out" || exit 1
sid=$(jq -r .sessionId < "$out")
[ -n "$sid" ] && [ "$sid" != null ] || { echo "ERROR: no Grok sessionId" >&2; exit 1; }

# every follow-up
grok --cwd "$repo" --resume "$sid" --model grok-4.5 --single "$next" --max-turns 20 \
     --permission-mode default --allow Read --allow Grep --deny Edit --deny Bash \
     --output-format json --no-memory > "$out2"
grok_wait "$out2" || exit 1
```

```powershell
& grok --cwd $repo --model grok-4.5 --single $prompt --max-turns 20 `
  --permission-mode default --allow Read --allow Grep --deny Edit --deny Bash `
  --output-format json --no-memory > $out
$json = Grok-Wait $out          # see next section; do NOT pipe straight to ConvertFrom-Json
$sid = $json.sessionId
& grok --cwd $repo --resume $sid --model grok-4.5 --single $next --max-turns 20 `
  --permission-mode default --allow Read --allow Grep --deny Edit --deny Bash `
  --output-format json --no-memory > $out2
$json2 = Grok-Wait $out2
```

Prefer `--resume <id>` over `--continue`: `--continue` picks the newest session for the
directory, which is the wrong one whenever several AI sessions share a repo.

Never pass `--fork-session` unless you deliberately want to branch the conversation. It
mints a new session id and throws away the warm prefix.

`-s/--session-id` names a **new** session (or the fork target). It does not resume.

## Keep the prefix stable so caching can engage

- Keep the opening of the brief byte-identical across the workstream. Put the new
  instruction at the END.
- Do not paste file contents. Grok reads files itself; pasted text is churning prefix.
- Do not change `--model`, the `--allow`/`--deny` set, `--no-memory`, or `--cwd`
  mid-workstream. Each one changes the prefix. In particular, set `--no-memory`
  consistently rather than flipping it between calls.

## The command returns before Grok finishes — always wait and verify

Observed repeatedly on 0.2.118/Linux: the shell reports the process complete after ~25–30
seconds while the real inference continues for another 1–3 minutes. The exit status is 0
and the output file is zero bytes. On Linux the tree is `bash → bwrap →
grok-<version>-linux-x86_64`; the wrapper the caller launched exits before the sandboxed
binary is done. A completed run has also delivered zero bytes to the caller while its own
log recorded `handle_prompt.done ok:true`.

**Exit status is not evidence.** Valid JSON with a terminal `stopReason` is the evidence.

```bash
# Wait until the output file holds a complete Grok result. Usage: grok_wait "$out"
grok_wait() {
  local f=$1 waited=0 timeout=${GROK_WAIT_TIMEOUT:-600} sr
  while [ "$waited" -lt "$timeout" ]; do
    if [ -s "$f" ] && sr=$(jq -er .stopReason < "$f" 2>/dev/null); then
      case "$sr" in
        end_turn|stop|completed) return 0 ;;
        cancelled|max_turns*)
          echo "ERROR: Grok stopped early (stopReason=$sr). Resume with --max-turns raised:" >&2
          echo "  sid=$(jq -r .sessionId < "$f")" >&2
          return 1 ;;
        *) echo "ERROR: unknown Grok stopReason=$sr" >&2; return 1 ;;
      esac
    fi
    sleep 5; waited=$((waited + 5))
  done
  echo "ERROR: Grok produced no terminal JSON in ${timeout}s; still running:" >&2
  pgrep -af grok >&2
  return 1
}
```

```powershell
function Grok-Wait {
  param([string]$Path, [int]$TimeoutSec = 600)
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    if ((Test-Path $Path) -and (Get-Item $Path).Length -gt 0) {
      try { $j = Get-Content -Raw $Path | ConvertFrom-Json } catch { $j = $null }
      if ($j -and $j.stopReason) {
        if ($j.stopReason -in @('end_turn','stop','completed')) { return $j }
        throw "Grok stopped early (stopReason=$($j.stopReason), sessionId=$($j.sessionId))"
      }
    }
    Start-Sleep -Seconds 5
  }
  Get-Process -Name grok -ErrorAction SilentlyContinue | Format-Table Id,StartTime | Out-String | Write-Error
  throw "Grok produced no terminal JSON in ${TimeoutSec}s"
}
```

Never launch a replacement session because a run "looks dead". First check `pgrep -af
grok` and the tail of `~/.grok/logs/unified.jsonl`. Three concurrent reviews of the same
repository is what this mistake actually produces, at full price each.

## Bound the run with `--max-turns` and read `stopReason`

Without `--max-turns`, a repository review hits the default turn ceiling while still
reading files and terminates as a bare `stopReason: "cancelled"` with no verdict — two
observed attempts cost 247,740 and 297,652 tokens and returned only narration
("I'll read…", "Next I'll inspect…"). The same review completed at `--max-turns 20`.

- Pass `--max-turns 20` on every call, first and resumed alike. Raise it for large
  reviews; never omit it.
- `stopReason: "cancelled"` after progress narration means the turn budget ran out. It
  does **not** mean a tool was denied, the model refused, or the CLI crashed.
- Grok's own log can say `handle_prompt.done ok:true` for a run whose result is
  `cancelled`. Trust `stopReason` in the JSON, not the log line.
- To recover, resume that same `sessionId` with a higher `--max-turns` rather than
  starting fresh — but treat a resumed run that returns empty output as a failed resume
  (a known 0.2.118 behavior after a cancellation), and only then start a new session.

## Read the JSON — the actual field names

There is **no `result` field** and the top-level `model` field is absent or null. The
fields Grok actually returns for `--output-format json`:

| Field | Contents |
|---|---|
| `text` | The answer — **with progress narration prepended**, not separated |
| `thought` | Reasoning summary |
| `sessionId` | Reuse this with `--resume` |
| `stopReason` | Terminal state; gate on this, not on exit status |
| `usage` | `input_tokens`, `cache_read_input_tokens`, `total_tokens` |
| `modelUsage` | Keyed by real model id, e.g. `grok-4.5-build` — this is where the model is |
| `total_cost_usd` | Real cost for the turn |

Because `text` interleaves "I'll read…" narration with the verdict, ask for a delimiter in
the brief (e.g. "end your reply with a `## Verdict` section") and quote from that section
rather than trying to guess where the answer starts.

## Locate and verify the CLI

1. Resolve the executable instead of assuming an install method.

   ```bash
   command -v grok && grok --version                     # Ubuntu: ~/.local/bin/grok
   ```
   ```powershell
   Get-Command grok -All; grok --version                 # Windows: C:\Users\<user>\.grok\bin\grok.exe
   ```

   **Do not treat `grok doctor` as the authentication check.** Observed on 0.2.118:
   `grok doctor` reported "You are not authenticated" while `grok models` reported "You
   are logged in with grok.com" moments later, with no login in between — and the model
   calls worked. `doctor` is useful for install/config diagnostics only. The only
   trustworthy auth check is a real call: run `grok models`, and if that is ambiguous,
   a one-line headless probe. A `doctor` failure alone is never grounds for telling
   Albert to log in again.

2. Treat `~/.grok/` as Grok's home: config, version metadata, docs, sessions, logs, and
   credentials. Never read or print `~/.grok/auth.json`.
3. Run `grok inspect` in the target repository to confirm the project root, loaded
   `AGENTS.md`/`CLAUDE.md` instructions, permissions, skills, and config.
4. Run `grok models` before selecting a model and pin it explicitly with `--model`.
   Currently `grok-4.5` is the default and only listed model. Usage reports it as
   `grok-4.5-build`, so if you assert on the returned model, compare on the `grok-4.5`
   prefix rather than demanding an exact string.

## Read the installed documentation

Prefer the docs bundled with the installed binary; they match the local version:

- `~/.grok/README.md` — complete reference
- `~/.grok/docs/user-guide/14-headless-mode.md` — `-p/--single`, output formats, exit codes
- `17-sessions.md` — resume, continue, session storage
- `22-permissions-and-safety.md` — permission modes and rule matching
- `18-sandbox.md` — OS sandbox profiles and platform support
- `~/.grok/CHANGELOG.md` — version-specific changes

Also run `grok --help`; the CLI surface changes.

## Permissions in headless mode

The one thing that is genuinely true and easy to trip over: in headless mode a tool call
that *would* prompt is **cancelled and reported to the model — it never pauses for
input**.

What that means in practice, verified on 0.2.118:

- **Read-only work: `--permission-mode default` is enough.** A headless run with
  `--permission-mode default --allow Read --allow Grep --deny Edit --deny Bash`
  completed successfully and used both Read and Grep. Do not broaden it.
- **Runs that must execute other tools: use `--permission-mode auto`.** Verified: a
  headless run with `--permission-mode auto` executed a bash command and returned it.
- `--always-approve` is a last resort. It is **not** needed merely to let a headless run
  execute commands, and it should never be used for a review.
- `--allow` / `--deny` remain the way to narrow whatever mode you pick.

An earlier version of this skill claimed `--permission-mode` only honoured
`bypassPermissions` and `default`, and that `auto`/`dontAsk`/`acceptEdits`/`plan` were
silently ignored. That is **wrong for 0.2.118** — `grok --help` lists all six as valid
values and `auto` demonstrably works. Re-verify with `grok --help` before trusting any
statement in this section, including this one.

On Windows do not claim `--sandbox read-only` protects the run: the installed docs list
OS sandbox enforcement for Linux and macOS only. Permission rules are the control there.

**A denied tool does not cancel the run.** Verified: with Bash denied, Grok reported
"Shell is blocked, so I'll stick to file reads and greps" and completed the review using
`read_file`, `grep`, `list_dir`, and `web_fetch`. So when a run ends without an answer,
**do not broaden permissions** — that is the wrong lever, it costs the cached prefix, and
the real cause is almost always the turn limit. Prove permissions are at fault from the
JSON before touching them.

## Keep the environment and the file scope tight

`grok inspect` on a normal machine shows Grok loading global CLAUDE instructions, project
instructions, AGENTS, ~52 skills, ~10 MCP servers, hooks, and plugin agents — a successful
review session reported 26 prepared tools and used web fetch during a *local repository*
review. That inflates prompt size, latency, and the cache prefix, and lets unrelated
instructions influence a review. `--no-memory` disables memory only; it does **not** slim
any of the rest. Run `grok inspect` in the target repo before an expensive delegation and
say in the report what was loaded.

If the material spans more than one checkout, set `--cwd` to a common parent or pass the
extra trees as explicit read roots rather than asking Grok to wander outside its working
repository — a review pointed at a sibling temp directory silently fell back to reviewing
only what was inside the selected repo. Verify with `grok --help` which flag the installed
version exposes before relying on it.

## Prepare the delegation

Give Grok a self-contained brief: the task, repository and branch, relevant paths or
errors, constraints, and the evidence you require back. Tell it to read the repository's
own instructions. Never include secrets, credential files, `.env` contents, or unrelated
private data.

Default to a read-only call for questions, planning, debugging, audits, and second
opinions. Use implementation mode only when the user explicitly asks Grok to edit code.

## Run explicit implementation

Record `git status` first and preserve unrelated work. Use an isolated Grok worktree:

```bash
grok --cwd "$repo" --worktree=grok-task --model grok-4.5 --single "$prompt" \
     --permission-mode auto --output-format json --no-memory > "$out"
```

Use `--worktree=<name>` with `=`. Repeat every branch, database, production,
destructive-action, allowed-file, and test constraint inside the prompt.

**Cleanup is a gate, not a suggestion.** Nothing Grok creates may outlive the delegation
or land on the user's plate. In the same task, after extracting the diff:

```bash
grok worktree remove grok-task            # use Grok's own command, not `git worktree`
grok worktree list                        # MUST no longer list grok-task
```

If `grok worktree list` still shows it, say so loudly and stop; do not report the task as
finished. Do not assume `git worktree prune` clears Grok's own bookkeeping.

## Verify and report

Treat a nonzero exit, authentication error, missing response, permission violation, or
unexpected working-tree change as failure. **Also treat exit 0 with an empty or
non-terminal JSON file as failure** — that is the normal shape of the early-return bug,
not success.

Capture the `usage` block from **every** turn, not just the first — Grok is the only one
of the delegate CLIs that reports real cost. Record `input_tokens`,
`cache_read_input_tokens`, `total_tokens`, and `total_cost_usd` in your report.

Label Grok's conclusions separately from your own judgment. For implementation, report
the files actually changed and test results you verified yourself. Do not let Grok
commit, push, merge, deploy, alter shared databases, or touch production unless the user
separately authorized that exact action.
