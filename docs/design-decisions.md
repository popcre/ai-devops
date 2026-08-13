# Design decisions: intentional quirks and non-obvious choices

**Owner:** this file owns the full "looks like / actually / why / do not change"
reasoning for every deliberate oddity in this toolkit. `AGENTS.md` carries only a
one-line warning per item plus a link here.

**Open this file when** you are about to change, "fix", simplify, or remove one of
the behaviors listed in the `AGENTS.md` "Intentional quirks" table, or when a
behavior looks like a bug and you want to know whether it is deliberate.

Moved out of `AGENTS.md` on 2026-08-12 by step 5 of
[`plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md).
Nothing was reworded in the move.


## Config lives in /etc, not in the repo

Looks like:
The scripts read `/etc/ai-devops/models.env` and `server.env`, but those files
are nowhere in the repo — only `*.env.example` are here.

Actually:
`install.sh` copies the examples into `/etc/ai-devops/` **only if the real file
does not already exist**, so machine-local edits are never clobbered by a repo
pull or re-install.

Why:
Keeps the repo safe to publish privately with zero secrets, and lets each server
tune model CLI flags without touching git.

Do not change because:
Committing real `.env` files would leak machine-specific config and risk secrets;
having scripts read from the repo would make `update.sh` overwrite local tuning.

## Model CLI flags are configurable, not hard-coded

Looks like:
`OPUS48_HIGH_REASONING_CMD='claude --model opus-4.8 --reasoning high'` — a very
specific command that may not match the installed `claude`/`codex` CLI.

Actually:
These are **defaults meant to be edited** per machine in
`/etc/ai-devops/models.env`. The exact model ids and flags differ across CLI
versions.

Why:
The `claude`/`codex` CLIs evolve; hard-coding flags would break on some machines.

Do not change because:
Removing the indirection (e.g. hard-coding `claude ...` inside the scripts) would
force a code edit on every machine whose CLI flags differ. See
[`model-setup.md`](model-setup.md).

## Fable is deliberately absent

Looks like:
A planning/final-review model slot with no "Fable" option, even though earlier
drafts of this workflow mentioned it.

Actually:
Fable is intentionally **not used**. Planning and final review use **Opus 4.8
with high reasoning** instead.

Why:
Fable is being removed from the subscription plan.

Do not change because:
Re-introducing Fable would reference a model that is going away. Use Opus 4.8
(high reasoning) for the planning and final-review stages.

## `codex-cli` MCP uses Codex's own `mcp-server`, not a third-party wrapper

Looks like:
A third-party npx package (`@cexll/codex-mcp-server`) would give more tools, so
using Codex's own server is a downgrade.

Actually:
`bin/setup-machine.ps1` (Windows) and `bin/setup-secrets.sh` (Ubuntu) wire
`codex-cli` to the **absolute** codex binary + `mcp-server`. That exposes exactly
two tools — `codex` (prompt, model, sandbox, approval-policy, cwd, config,
base/developer-instructions) and `codex-reply` (thread continuation, which the
wrapper does not appear to offer at all). Verified end-to-end 2026-07-16: a
`tools/call` with `sandbox=workspace-write` really writes files.

Why:
No third-party supply chain and no `npx` download in the hot path; version-locked
to the CLI it ships with; and — decisively — a wrapper *shells out to* `codex`
resolved from PATH, which re-introduces the junction bug below. Pinning the
absolute binary cannot resolve to the wrong codex.

Do not change because:
Swapping back to a wrapper reintroduces both the supply-chain surface and the
PATH-resolution failure. The trade-off was made knowingly: we gave up the
wrapper's `changeMode`/`fetch-chunk`, `batch-codex` and `brainstorm` tools, all of
which are reproducible by prompting the native `codex` tool.

## `ai-devops doctor` runs Codex for real instead of asking `--version`

Looks like:
`doctor` should just check that `codex` exists and answers `--version` — cheap and
fast, like every other liveness check.

Actually:
`check_codex_sandbox()` creates a temp dir, runs a real
`codex exec --sandbox workspace-write`, and asserts the file exists. It costs a
real (small) model call and a few seconds.

Why:
On 2026-07-16 a machine had codex passing `--version`, passing
`codex login status`, and exiting 0 — while **every** sandboxed write silently
failed and `codex exec` changed nothing. A `--version` probe is structurally
incapable of seeing that failure mode. Presence is not capability; only exercising
the capability proves it.

Do not change because:
Reverting to a `--version` check restores a green light over a broken tool, which
is worse than no check at all. If the cost matters, gate it behind a flag — do not
delete it.

## `ai-install-skills` installs but never prunes — orphans live forever

Looks like:
`bin/ai-install-skills` syncs `skills/claude/` to `~/.claude/skills`, so a machine's
skill set should mirror the repo.

Actually:
It only ever `rm -rf`s the specific skill names it is **about to copy**, then copies
them. A skill directory on the machine with **no counterpart in the repo is never
touched**. Verified 2026-07-16 on `hetz`: `/home/ai/.claude/skills` held 21 skills —
the repo's 18 plus 3 orphans (`codex-consult`, `codex-code-review`,
`codex-plan-review`, all dated 2026-07-04) that have **never existed in this repo**.
`codex-consult` is actively broken: it shells out to a `codex-consult` binary that
is not on PATH.

Why:
The one-way repo→machine copy is deliberate (a local edit must never be captured
back). Pruning was simply never implemented — nobody noticed, because an orphan
fails only when a session actually triggers it.

FIXED 2026-08-03 — orphans are now pruned automatically:
Both installers stamp every skill they lay down with a `.ai-devops-managed`
marker file, and on each run move any marked skill the repo no longer ships into
`<client>/skills-quarantine/`. So retiring a skill is just "delete it from
`skills/` and commit" — it leaves every machine on that machine's next sync,
with no per-name special case. Nothing is deleted, and re-running is safe.

The marker is what makes a blind prune safe, and it must stay: skill roots also
hold skills ai-devops does **not** own — Codex ships its own `playwright` skill
with its own LICENSE/NOTICE, and an earlier "prune anything not in the repo"
draft would have quarantined it. Unmarked directories are never touched.
`config/retired-skills.txt` is a one-time migration list for skills installed
before markers existed (only `synology-sharesync-stuck-triage`); nothing new
should ever be added to it. `--keep-orphans` (Bash) opts out. The old
`--migrate-obsolete` / `-MigrateObsolete` flags are accepted as no-ops.

Still true: treat "the skill is installed" as **no evidence** it came from the
repo — a hand-authored local skill has no marker and survives pruning, so when a
machine behaves oddly, still diff `ls ~/.claude/skills` against `ls
skills/claude/`. Repo-owned cross-client skills live under `skills/shared/` and
install into both Claude and Codex.

EXTENDED 2026-08-13 — the update itself no longer destroys local work:
Until this date the copy step was `rm -rf <installed skill>` followed by a fresh
copy, so **any file added inside a managed skill directory was deleted without a
word** on the next sync. Both installers now classify before writing (absent,
identical, update, local-edits, unmanaged), copy only the files that actually
changed, never delete a file the repo does not ship, and copy anything they are
about to overwrite that held hand edits into `<client>/skills-backup/<name>`.
The marker carries a SHA-256 per installed file, which is the only way to tell a
hand edit from an ordinary source update; markers written before this carry no
hashes, so a differing skill under a legacy marker is assumed edited and backed
up rather than silently replaced. Full behavior table: `docs/deployment.md`.

## `codex exec resume` takes different flags from `codex exec`

Looks like:
`resume` is `exec` plus a session id, so the flags carry over.

Actually:
`codex exec resume` **rejects** `-s/--sandbox`, `-C/--cd`, and `--color`
(`error: unexpected argument '-s' found`). Verified against codex-cli 0.144.5 on
2026-07-16. It does accept `-c`, `-m`, `-o`, `--json`, `--last`. To resume
read-only, pass `-c sandbox_mode="read-only"` and `cd` to the repo first.

Why:
Upstream CLI surface; nothing we control.

Future sessions should:
Copy `exec` flags onto `resume` and it fails immediately and loudly — which is the
good case. The dangerous case is the sandbox: a mistyped `-c` key does **not**
error, it silently falls back to the config default. Always confirm the run header
prints `sandbox: read-only`. Prefer the explicit session id (the header of the
first run prints `session id: <uuid>`) over `--last`, which silently picks the
newest session for the cwd and can grab the wrong one.

## Reviews are read-only by design

Looks like:
`ai-codex-review` gathers a full diff and prompt but never applies changes.

Actually:
Review stages (plan/diff/security/visual/final) are strictly read-only — they
save a Markdown report under `.ai/reviews/` and print the path. They never
commit, push, merge, or delete.

Why:
Separation of duties: implementation stages write code; review stages only judge
it. This keeps an independent check in the loop.

Do not change because:
Letting a review stage edit code would collapse the safety gate the workflow
exists to provide.

## The MCP secret launcher caches; it must not re-resolve per launch

Looks like:
`~/.config/ai-devops/mcp-launch.cmd` just runs an MCP server with secrets.

Actually:
It calls `bin/mcp-secret-launch.ps1`, which resolves all `mcp.env` `op://`
references **once** behind a machine-wide mutex and reuses a 15-minute
DPAPI-encrypted cache (`mcp-secrets.dpapi.json`). It does **not** run
`op run --env-file` on every launch. `$CommandArgs` is declared
`[Parameter(Position = 0, ValueFromRemainingArguments = $true)]`, and the
generated `.cmd` files pass `%*` with **no `--` separator**.

Why:
5 machines share one 1Password service account with a per-hour request cap. A
per-launch `op run` resolving ~11 refs × every window/server/subagent overran the
cap and locked the account (see the 2026-07-23 incident). The cache makes it
≤1 refresh / 15 min / machine. `Position = 0` forces `-Url`/`-SecretRef` to bind
by name only so a Stdio child's leading `cmd /c` is not swallowed; `--` is omitted
because `pwsh -File` mis-parses it as an empty parameter name.

Do not change because:
Re-introducing a per-launch `op run`, removing `Position = 0`, or re-adding `--`
each independently reproduces a real outage. Full detail:
[`mcp-1password-rate-limit-hardening.md`](mcp-1password-rate-limit-hardening.md).

## The isolated memory hub must enable Git long paths before checkout

Looks like:
The main `ai-devops` checkout has `core.longpaths=true`, so every Git operation
on Windows should support paths longer than 260 characters.

Actually:
`bin/ai-memory-sync` works in a separate clone at
`~/.cache/ai-devops-memory`. Git settings stored in the main checkout do not
apply there. Claude local-agent transcripts can produce paths over 400
characters. New hub clones therefore pass `-c core.longpaths=true` to
`git clone` before checkout, and existing hub clones set the same local config
before fetch/reset.

Why:
On 2026-07-27 the hidden clone failed to create a 409-character transcript path.
The old script did not check the reset result, continued against a partial
checkout, and printed misleading memory-copy messages.

Do not change because:
Setting long-path support after clone is too late for the first checkout.
Every destructive reset in this script must also fail closed; otherwise a
damaged hidden clone can look healthy. Regression coverage:
`tests/test-ai-memory-sync.sh`.

