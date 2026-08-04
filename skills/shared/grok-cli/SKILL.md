---
name: grok-cli
description: Locate and use xAI's installed Grok CLI (`grok`, branded Grok Build) as an independent coding agent, including read-only reviews, repository analysis, explicit implementation delegation, session continuation, and local documentation lookup. Use when the user says "use Grok", "ask Grok", "run this by Grok", "Grok CLI", "Grok Build", requests a Grok second opinion, asks where Grok is installed, or explicitly delegates coding work to Grok.
---

# Grok CLI

Drive Grok headlessly and keep the calling Claude or Codex session responsible for
scope, safety, and verification.

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

Capture the session id on the first call and reuse it:

```bash
grok --cwd "$repo" --model grok-4.5 --single "$prompt" \
     --permission-mode default --allow Read --allow Grep --deny Edit --deny Bash \
     --output-format json --no-memory > "$out"
sid=$(jq -r .sessionId < "$out")
[ -n "$sid" ] && [ "$sid" != null ] || { echo "ERROR: no Grok sessionId" >&2; exit 1; }

# every follow-up
grok --cwd "$repo" --resume "$sid" --model grok-4.5 --single "$next" \
     --permission-mode default --allow Read --allow Grep --deny Edit --deny Bash \
     --output-format json --no-memory > "$out2"
```

```powershell
$json = & grok --cwd $repo --model grok-4.5 --single $prompt `
  --permission-mode default --allow Read --allow Grep --deny Edit --deny Bash `
  --output-format json --no-memory | ConvertFrom-Json
$sid = $json.sessionId
& grok --cwd $repo --resume $sid --model grok-4.5 --single $next `
  --permission-mode default --allow Read --allow Grep --deny Edit --deny Bash `
  --output-format json --no-memory
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

## Locate and verify the CLI

1. Resolve the executable instead of assuming an install method.

   ```bash
   command -v grok && grok --version && grok doctor      # Ubuntu: ~/.local/bin/grok
   ```
   ```powershell
   Get-Command grok -All; grok --version; grok doctor    # Windows: C:\Users\<user>\.grok\bin\grok.exe
   ```

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
unexpected working-tree change as failure.

Capture the `usage` block from **every** turn, not just the first — Grok is the only one
of the delegate CLIs that reports real cost. Record `input_tokens`,
`cache_read_input_tokens`, `total_tokens`, and `total_cost_usd` in your report.

Label Grok's conclusions separately from your own judgment. For implementation, report
the files actually changed and test results you verified yourself. Do not let Grok
commit, push, merge, deploy, alter shared databases, or touch production unless the user
separately authorized that exact action.
