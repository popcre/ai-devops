# memory/ — cross-machine Claude auto-memory

This tree is the synced home for **Claude Code's auto-memory** so a fact written
on one machine reaches all the others. Populated and read by
[`../bin/ai-sync-memory`](../bin/ai-sync-memory); driven by the `sync-dotfiles`
skill. Part of config-consolidation Phase 1
([`../docs/config-consolidation-proposal.md`](../docs/config-consolidation-proposal.md)).

## Background: what "auto-memory" is

Claude Code keeps a per-project memory folder at
`~/.claude/projects/<slug>/memory/` containing a `MEMORY.md` index plus one `.md`
file per fact. It's loaded into context each session so Claude recalls durable
project knowledge. Until this tree existed, that memory lived only on the machine
where it was written — a fact saved on t16 never reached 916.

## Layout

```
memory/
  <project>/            # canonical project key: dflow, oracle, ansible, 1password-mcp, ...
    MEMORY.md           # the per-project index (one line per fact file)
    *.md                # individual fact files (user/feedback/project/reference)
  project-map.tsv       # optional slug -> project overrides
  README.md             # this file
```

## Why canonical project keys (not raw slugs)

On each machine memory lives at `~/.claude/projects/<slug>/memory/`, where
`<slug>` encodes the **working-copy path** — e.g. `C--repos-dflow` on a box where
the repo is on `C:`, `D--repos-dflow` where it's on `D:`. Those are the **same
project**, so `ai-sync-memory` **canonicalizes** the slug to a single key.

**Default heuristic:** drop everything up to and including the last `repos-`.
- `C--repos-dflow` → `dflow`
- `D--repos-dflow` → `dflow`  (unifies with the above)
- `C--repos-oracle` → `oracle`
- `C--repos-ansible` → `ansible`

**Overrides** for cases the heuristic gets wrong go in `project-map.tsv`
(`slug<TAB>project`, `#` comments allowed). Current override:
```
C--repos-temp-1Password-MCP	1password-mcp
```
(without it the key would be `temp-1Password-MCP`, which wouldn't unify with a
`C--repos-1Password-MCP` checkout on another machine.)

## Usage

```bash
# preview (no writes):
bin/ai-sync-memory push --dry-run
bin/ai-sync-memory pull --dry-run

# real:
bin/ai-sync-memory push      # machine memory  -> this repo working tree
#   then review, git add memory/, commit, push
bin/ai-sync-memory pull      # repo memory     -> machine (only projects that already exist locally)
```

Or just say **"sync my dotfiles"** and the skill runs pull → install → push →
commit for you.

### push (machine → repo)
Copies every `~/.claude/projects/<slug>/memory/` into `memory/<canonical>/`. Then
YOU review and commit (the script never commits, so you can inspect first).

### pull (repo → machine)
For each `memory/<project>/`, finds local project dir(s) whose slug canonicalizes
to `<project>` and copies the files in. **Projects that don't exist locally yet
are skipped** — there's no local path to write into until you've opened that repo
on this machine once (Claude creates the `projects/<slug>/` dir then). Re-run
pull after that.

## Onboarding scenarios

- **New machine:** clone ai-devops, run the installer, then `ai-sync-memory pull`.
  Only projects you've already opened locally receive memory; open the others once
  and pull again.
- **New project:** just use it — the next `push` picks up its memory folder and
  creates `memory/<project>/` automatically. Add a `project-map.tsv` line only if
  the canonical key comes out wrong.
- **Same project on a different drive:** the canonicalization handles `C:` vs `D:`
  automatically; no action needed.

## Conflict resolution

Two machines editing the same fact file, both pushing, is an **ordinary git merge
conflict** in a `.md` file — resolve it like any doc (keep both facts, or the
newer one). Because memory is plain Markdown, conflicts are human-readable. To
minimize them, `pull` before a work session and `push`+commit at the end (the
`sync-dotfiles` skill does both).

## Rules

- **Secret-free — hard rule.** Memory holds facts, not credentials. This tree is
  committed to git. If a memory file ever contains a token/key/password, STOP:
  remove it, and put the secret in 1Password (`vibe_coding` vault) instead. Never
  commit it here.
- Don't hand-edit another machine's memory blindly; prefer pulling, editing on the
  owning project, and pushing.
- `MEMORY.md` inside each project is an index only — keep it one line per fact
  file (this mirrors how Claude Code maintains it locally).
- **`pull` overwrites `MEMORY.md` wholesale — write new memories AFTER the pull,
  or re-add the index line.** Fact files are additive (a local file the hub has
  never seen survives a pull), but `MEMORY.md` is copied over, so an index line
  added locally minutes earlier is silently deleted while the sync still reports
  success. The fact file remains on disk and is therefore invisible to recall,
  which is the worst of both outcomes. Observed on hetz 2026-07-29. If you write
  a memory mid-session and then sync, re-check that its line is still in
  `MEMORY.md` before pushing.

## See also
[`../docs/config-inventory.md`](../docs/config-inventory.md) ·
[`../docs/config-consolidation-proposal.md`](../docs/config-consolidation-proposal.md) ·
[`../HANDOFF.md`](../HANDOFF.md)
