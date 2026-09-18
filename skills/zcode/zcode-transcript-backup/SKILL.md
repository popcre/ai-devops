---
name: zcode-transcript-backup
description: Back up ZCode's SQLite + rollout-JSONL session store to the PRIVATE repo u2giants/ai-devops-transcripts under zcode_chats/<machine>, and mine it by direct SQL query against the copy. Use when the user says "back up my ZCode transcripts/sessions" or asks to analyze ZCode usage (tools, tokens, sessions, prompts).
---

# zcode-transcript-backup

> **STOP — transcripts belong only in the private transcript repository.**
> Before any copy, run `ai-transcript-destination-check <checkout>`. A missing
> validator or nonzero result stops the backup.

Unlike Claude and Codex, ZCode keeps its session history in a **relational
SQLite store**, so this skill does NOT convert anything into a JSONL pile: it
copies the store and queries it by SQL. Mining recipes live in
[`queries.md`](queries.md) next to this file.

## Where the store lives (Windows)

- `~/.zcode/cli/db/db.sqlite` — the session database, **plus its `-wal` and
  `-shm` sidecars** (a copy without them can be missing recent commits).
- `~/.zcode/cli/rollout/model-io-sess_<uuid>.jsonl` — per-session raw model
  I/O captures.
- `~/.zcode/cli/exec/sess_<uuid>/` — tool-call logs (not usually part of the
  backup; include on request).
- `~/.zcode/cli/log/zcode-<date>.jsonl` — daily diagnostics (include on
  request only; they are large and rarely mined).

## Backup procedure

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
   cp ~/.zcode/cli/rollout/model-io-sess_*.jsonl /tmp/zcode-backup-$USER/ 2>/dev/null
   ```
   Copying while ZCode is running is safe for a WAL-mode SQLite database, but
   prefer running the backup with ZCode closed when convenient. Verify the
   copy parses (`python -c "import sqlite3; con=sqlite3.connect(...)"` with a
   trivial query) before pushing it anywhere.
3. **Prove the destination:** clone/pull the PRIVATE
   `u2giants/ai-devops-transcripts`, then run
   `ai-transcript-destination-check <private-checkout>`. Only after PASS:
4. **Copy into** `zcode_chats/<machine>/` (machine = short hostname), e.g.
   `zcode_chats/<machine>/db/db.sqlite{,-wal,-shm}` and
   `zcode_chats/<machine>/rollout/model-io-sess_*.jsonl`. Keep per-backup
   snapshots in dated subfolders (`2026-09-17/`) rather than overwriting —
   the database is cumulative and a dated trail shows growth.
5. Commit and push to the private repo's `main`. Warn (don't block) on files
   over GitHub's 50 MB soft limit; the DB can exceed it — if so, split the
   push or suggest Git LFS to the owner.
6. **Public-repo discipline:** nothing from the store is ever committed to
   `popcre/ai-devops` or any public repository, issue, log, or prompt. After a
   run, `git status` in the public repo must be clean. This skill names the
   private destination only.

## Mining the copy

Open [`queries.md`](queries.md) and run its recipes with Python's stdlib
`sqlite3` against the COPIED database (the toolkit installs `python`).
Timestamps are epoch milliseconds; tool status vocabulary is
`completed | error | running`. Per §4.3 of the ai-devops rulebook, no measured
count is ever pasted into a document — run the query and read today's number.
