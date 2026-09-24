---
issue: 767
status: OPEN
owner: mimo/quieter-harnesses-followups
---

# Handoff — quieter harness rules shipped; MiMo adopt gap and fleet sync left

Machine: `edge-dev`. Agent: `mimo` (MiMo Desktop chat `ses_ffe5f2f6abc93ffeSA5M6xIWoU`).
Written: 2026-09-24T1209Z.

## 0. DECISIONS ONLY THE OWNER CAN MAKE

**Put this whole list to the owner in ONE message before starting work.**

### Blocking

None.

### Wrong guess is recoverable

1. **Other computers still run the old long rules.** Recommendation: Albert says
   "sync my dotfiles" on each machine he cares about (or this toolkit session
   does it remotely where SSH is available). Blocks: token savings on those
   machines. Success: each machine's Claude/Codex/MiMo/ZCode global files are
   about 15KB and contain `120 words maximum`.
2. **Pick up issue #767 (MiMo missing from adopt-globals) in this next session
   or later?** Recommendation: do it in the next toolkit session — it is a
   small, safe code change. Blocks: nothing today (edge-dev was fixed by hand);
   blocks correct installs on every future machine.

### Not part of this work and nobody is on it

3. **Fully quit and reopen Claude, Codex, and MiMo on edge-dev** so new chats
   load the short rules. Recommendation: Albert does this when convenient.
   This chat cannot force a running app to reload. Success: a new chat answers
   in short plain English.

### Already settled — do NOT re-ask

- 2026-09-24: cut always-loaded harness instruction text; keep every safety
  phrase (owner request this session: "make the harnesses less verbose…
  save tokens").
- 2026-09-24: replies are 120 words maximum, plain English, no jargon.
- 2026-09-24: PR #739 merged; slim globals live on `origin/main` and installed
  on edge-dev.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's public AI development-operations toolkit
on his Windows workstation `edge-dev`. It holds the always-loaded instruction
templates for Claude, Codex, MiMo, and ZCode, plus installer/skill tooling.
Albert is a business owner, not a programmer. GitHub: `popcre/ai-devops`.
Local canonical checkout: `C:\repos\ai-devops` (landing-only).

## 2. What we set out to do this session, and why

Albert asked to make the harnesses less verbose for a non-technical vibe coder
and save tokens. Trigger: always-loaded global instruction files had grown to
about 51KB (Claude + Codex), roughly 12,700 estimated tokens re-sent every
turn. Goal: cut bulk and technical noise without losing any safety rule.

## 3. Current state — what is true right now

**Done and verified:**

- Slimmed all four client globals (`templates/system/CLAUDE-global.md`,
  `AGENTS-global-codex.md`, `AGENTS-global-mimo.md`, `AGENTS-global-zcode.md`).
  Always-loaded (Claude+Codex) measured **29,809 bytes** after merge (from
  51,037), about **42% smaller**, roughly **5,400 fewer tokens per turn**.
- Long procedures moved to `docs/standing-rules-details.md` (loaded only when
  needed). Accounting table updated in `docs/context-engineering.md`.
- All required phrases kept unwrapped. Evidence:
  - `tests/test-client-globals-required-phrases.sh` PASS
  - `tests/test-session-conduct-policy.sh` PASS (0 failures)
  - `tests/test-shared-db-routing-rules.sh` PASS (26/26)
  - `tools/context-audit/context-audit.py --strict`: 0 missing safety markers,
    0 parity mismatches, 0 overlaps
  - `tests/test-context-audit.ps1` all PASS
- Shipped: PR https://github.com/popcre/ai-devops/pull/739 MERGED as
  `5952962f56dcc833641041864de47de649ff12fa` at 2026-09-23T23:55:47Z.
- Installed on edge-dev: `~/.claude/CLAUDE.md` (14899), `~/.codex/AGENTS.md`
  (14910), `~/.config/mimocode/AGENTS.md` (14915), `~/.zcode/AGENTS.md`
  (14911). Backups under `~/.ai-globals-backup/20260924T010124Z/` and the
  installer's own `globals-backup/`.

**Half-done / not started:**

- Issue **#767** open: `bin/ai-adopt-globals` does not install the MiMo global.
  No code change made (scope freeze at wrap-up). edge-dev was fixed by hand.
- Other machines (at least `albt16`, `hetz`, possibly `916-alien` if powered
  on) still have the old long globals until someone runs sync there.
- Running apps on edge-dev still hold the old rules until fully restarted.

**Commit/push status:** main work merged to `origin/main` as `5952962f`.
This handoff ships on branch `docs/handoff-767-mimo-gap`.

## 4. Everything we tried that did NOT work

1. **`bash` via the default WindowsApps stub / nested PowerShell quoting.**
   Several `python -c` and heredoc attempts failed (`ParserError`, WSL "no
   distributions", `zcode` CLI accidentally invoked). Reasonable because Git
   Bash + PowerShell fight over quotes. Fix that worked: write a short `.py`
   file and run it with `"C:\Program Files\Git\bin\bash.exe"`.
2. **`bin/ai-task-gates` / `bin/ai-adopt-globals` through `bash -lc`.** Hung or
   `ChildProcess.kill`. Worked with `bash -c` and a `timeout` wrapper writing
   to `/c/tmp/*.txt`, then reading the file.
3. **Full `ai-adopt-globals` run timed out mid-Codex-skills** (skill scan is
   slow). Claude global was already replaced; Codex/MiMo/ZCode were finished
   by direct template copy after the dry-run proved **no machine sections**
   to preserve. Never skip that dry-run check on a machine that has one.
4. **Dropped the EST time-quoting rule** in the first slim draft. Caught by
   comparing against `origin/main` before merge. Restored
   (`3:45 PM EST` / `America/New_York`). Do not slim safety/time rules away.
5. **First push of the feature branch accidentally targeted `main`** (`git
   push -u origin HEAD` while upstream was `origin/main`). Rejected. Correct:
   `git push -u origin prose/quieter-harnesses:prose/quieter-harnesses`.
   Never push to protected `main`.
6. **Line-wrapped required phrases** broke `test-client-globals-required-phrases.sh`
   (`quote Albert's exact words`, retirement path sentence, `Ending the turn
   is the error`). Phrases must stay on one unwrapped line. Fixed and retested.

## 5. Root causes and key findings

- **Always-loaded instruction bulk is the biggest controllable per-turn token
  cost** after tool traffic. Measured 51,037 → 29,809 bytes on Claude+Codex
  templates (`tools/context-audit/context-audit.py`).
- **Safety/conduct phrases are load-bearing and test-locked** in
  `tests/test-client-globals-required-phrases.sh`,
  `tests/test-session-conduct-policy.sh`, `tests/test-shared-db-routing-rules.sh`,
  and `PARITY_RULES` / `SAFETY_MARKERS` in `tools/context-audit/context-audit.py`.
  Slimming must compress around those phrases, never through them.
- **`bin/ai-adopt-globals` TARGETS** (see `bin/ai-adopt-globals` around the
  `TARGETS=(...)` array) lists Claude, Codex, ZCode only — **not MiMo**. That
  is issue #767. Template `templates/system/AGENTS-global-mimo.md` already
  exists.
- **Docs-only PRs** in this repo merge with `gh pr merge --squash --admin`
  immediately (standing rule). Conflicts still need a merge from `origin/main`
  first (happened when EST landed on main mid-flight).
- **Budget warning remains** (`alwaysLoadedBytes` budget 12,449). Deliberately
  not raised: required phrases make 12KB unreachable; raising a budget to hide
  a warning breaks the ratchet rule (`tools/context-audit/README.md`).

## 6. Exact next steps

1. **Fix #767** — add MiMo to `TARGETS` in `bin/ai-adopt-globals` so
   `~/.config/mimocode/AGENTS.md` is backed up, replaced from
   `templates/system/AGENTS-global-mimo.md`, and verified like the others.
   Extend `tests/test-ai-adopt-globals.sh` for a MiMo target.
   You'll know it worked when: dry-run lists MiMo, install updates it, and the
   adopt test suite passes.
2. **Sync remaining machines** (owner or remote session): run "sync my dotfiles"
   / `bin/ai-adopt-globals` on `albt16` and `hetz` (and `916-alien` if on).
   You'll know it worked when each machine's globals are ~15KB and contain
   `120 words maximum`.
3. **Owner restarts apps on edge-dev** (Claude, Codex, MiMo). You'll know it
   worked when a new chat uses short plain replies.

## 7. Constraints and gotchas in force

- Canonical checkout `C:\repos\ai-devops` is landing-only. Write-capable work
  uses its own worktree from current upstream.
- Never push to protected `main`. Branch + PR + merge queue (docs-only may
  `gh pr merge --squash --admin`).
- Stage only files this session owns. Do not touch other sessions' `HANDOFF.d/`
  files or the untracked `Microsoft/` folder at repo root (not ours).
- Required phrases in client globals must remain **unwrapped** (single-line
  substrings).
- Safety rules outrank token reduction.
- Sign GitHub posts: `Posted by MiMo chat <id> on edge-dev`.
- Quote times in EST (New York City).

## 8. Access and environment

- Machine: `edge-dev` (Windows). Git identity already correct
  (`Albert Hazan <u2giants@users.noreply.github.com>`).
- Repo: `https://github.com/popcre/ai-devops.git` (`popcre/ai-devops`).
- GitHub via `bin/ai-gh` only.
- 1Password vault `vibe_coding` (no secrets appeared this session).
- Worktree used for the slim work: `C:\tmp\wt-quieter-harnesses` (branch
  `prose/quieter-harnesses`, merged). Handoff worktree: `C:\tmp\wt-handoff-767`.
- Backups of pre-slim globals: `C:\Users\ahazan\.ai-globals-backup\` (notably
  `20260924T010124Z` and the adopt-globals stamp dir).

## 9. Open questions and risks

- **Budget floor (2026-09-24):** `alwaysLoadedBytes` warning budget 12,449 is
  below the honest phrase-locked floor (~30KB). Leave the warning; do not raise
  the budget to silence it. If a future session ratchets, record the reason
  like the one sanctioned raise in `docs/context-engineering.md`.
- **Fleet drift (2026-09-24):** until every machine is synced, mixed old/new
  globals will coexist. Harmless but costs tokens on old machines.
- **#767 unfixed:** any future `ai-adopt-globals` run will again skip MiMo
  unless the script is updated first. On machines with a MiMo global, copy
  `templates/system/AGENTS-global-mimo.md` by hand after adopt, or fix #767
  first.
- **Untracked at `C:\repos\ai-devops` root (not this session's):**
  `HANDOFF.d/2026-09-20T0029Z-edge-dev-kimi-grok-trap-exit-status.md` and
  `Microsoft/`. Left alone on purpose.
