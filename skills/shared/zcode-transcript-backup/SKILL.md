---
name: zcode-transcript-backup
disable-model-invocation: true
description: Back up local ZCode session exports to Dropbox (bin/ai-transcript-upload or transcript-to-dropbox) and mine a COPY of ZCode's SQLite + rollout store by direct SQL (queries.md). The private Git transcript repo is frozen since 2026-09-27. Use when explicitly asked to mine ZCode SQLite/rollout logs or check ZCode Dropbox backups.
---

# zcode-transcript-backup

> **Owner rule (Albert, 2026-09-27 / 2026-10-29):**
> - `u2giants/ai-devops-transcripts` is a **frozen historical archive** (last upload 2026-09-27). Never add transcripts to it.
> - Routine ZCode session exports go to **Dropbox** (`ai/chat_transcripts/<machine>/zcode/`): on active desktops via `bin/ai-transcript-upload` / `bin/ai-transcript-upload.ps1` (which exports filtered ZCode sessions only, never the raw SQLite database), and on `hetz` via [`transcript-to-dropbox`](../transcript-to-dropbox/SKILL.md).

Unlike Claude and Codex, ZCode keeps its session history in a **relational
SQLite store**, so this skill does NOT convert anything into a JSONL pile: it
copies the store locally and queries it by SQL. Mining recipes live in
[`queries.md`](queries.md) next to this file.

## Where the store lives (Windows / Linux)

- `~/.zcode/cli/db/db.sqlite` — the session database, **plus its `-wal` and
  `-shm` sidecars** (a copy without them can be missing recent commits).
- `~/.zcode/cli/rollout/model-io-session_*.jsonl` and
  `~/.zcode/cli/rollout/model-io-sess_*.jsonl` — per-session raw model I/O
  captures.
- `~/.zcode/cli/exec/sess_<uuid>/` — tool-call logs (not usually queried;
  include on request).
- `~/.zcode/cli/log/zcode-<date>.jsonl` — daily diagnostics (include on
  request only; they are large and rarely mined).

## Copy-and-inspect procedure

1. **Dry run first (default):** report the count of sessions, the newest
   session title, the DB size, and the rollout-file count — WITHOUT copying:
   ```bash
   python -c "import sqlite3; con=sqlite3.connect(r'<copy>')"
   ```
   For the listing, copy first (step 2) into a scratch directory and query the
   COPY; never open the live database.
2. **Copy — never live-open — the store** into a scratch directory:
   ```bash
   mkdir -p /tmp/zcode-backup-$USER && \
   cp ~/.zcode/cli/db/db.sqlite ~/.zcode/cli/db/db.sqlite-wal ~/.zcode/cli/db/db.sqlite-shm \
      /tmp/zcode-backup-$USER/ 2>/dev/null; \
   cp ~/.zcode/cli/rollout/model-io-session_*.jsonl ~/.zcode/cli/rollout/model-io-sess_*.jsonl /tmp/zcode-backup-$USER/ 2>/dev/null
   ```
   Copying while ZCode is running is safe for a WAL-mode SQLite database, but
   prefer copying with ZCode closed when convenient. Verify the copy parses
   before querying it.
3. **Dropbox session refresh (not raw DB):** to refresh filtered ZCode session
   exports into `ai/chat_transcripts/<machine>/`, run `ai-transcript-upload`
   (`ai-transcript-upload.ps1` on Windows), or follow
   [`transcript-to-dropbox`](../transcript-to-dropbox/SKILL.md) on `hetz`. Never
   push raw `db.sqlite` files to GitHub or upload dated DB snapshots to Dropbox.
4. **Public-repo discipline:** nothing from the store is ever committed to
   `popcre/ai-devops` or any public repository, issue, log, or prompt. After a
   run, `git status` in the public repo must be clean, and delete the temporary
   `/tmp/zcode-backup-$USER` copy when done.

## Mining the copy

Open [`queries.md`](queries.md) and run its recipes with Python's stdlib
`sqlite3` against the COPIED database (the toolkit installs `python`).
Timestamps are epoch milliseconds; tool status vocabulary is
`completed | error | running`. Per §4.3 of the ai-devops rulebook, no measured
count is ever pasted into a document — run the query and read today's number.
