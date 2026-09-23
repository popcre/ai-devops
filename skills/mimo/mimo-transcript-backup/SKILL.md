---
name: mimo-transcript-backup
description: Back up MiMoCode's SQLite session store (mimocode.db) and memory dirs to the PRIVATE repo u2giants/ai-devops-transcripts under mimo_chats/<machine>, and mine a COPY by direct SQL. Use when the user says "back up my MiMo/MiMoCode transcripts/sessions" or asks to analyze MiMo usage (tools, tokens, sessions, prompts).
---

# mimo-transcript-backup

> **STOP — transcripts belong only in the private transcript repository.**
> Before any copy, run `ai-transcript-destination-check <checkout>`. A missing
> validator or nonzero result stops the backup.

Like ZCode, MiMoCode keeps session history in a **relational SQLite store**,
so this skill does NOT convert anything into a JSONL pile: it copies the store
and queries it by SQL. Mining recipes live in [`queries.md`](queries.md) next
to this file.

## Where the store lives (Windows)

- `~/.local/share/mimocode/mimocode.db` — the session database, **plus its
  `-wal` and `-shm` sidecars** (a copy without them can be missing recent
  commits).
- `~/.local/share/mimocode/memory/sessions/<id>/` — per-session checkpoints,
  notes, and task progress (include on request; useful for session recovery).
- `~/.local/share/mimocode/log/` — diagnostics (include on request only).

Config (not transcripts): `~/.config/mimocode/mimocode.jsonc`. Never copy
credential material. Account tokens stay in MiMo's own auth store — check by
existence only and never read.

## Backup procedure

1. **Dry run first (default):** report the DB size and memory-session count —
   WITHOUT copying.
2. **Copy — never live-open — the store** into a scratch directory:
   ```bash
   mkdir -p /tmp/mimo-backup-$USER && \
   cp ~/.local/share/mimocode/mimocode.db \
      ~/.local/share/mimocode/mimocode.db-wal \
      ~/.local/share/mimocode/mimocode.db-shm \
      /tmp/mimo-backup-$USER/ 2>/dev/null
   ```
   Prefer running the backup with MiMo Desktop closed when convenient.
   Verify the copy parses before pushing it anywhere.
3. **Prove the destination:** clone/pull the PRIVATE
   `u2giants/ai-devops-transcripts`, then run
   `ai-transcript-destination-check <private-checkout>`. Only after PASS:
4. **Copy into** `mimo_chats/<machine>/` (machine = short hostname), e.g.
   `mimo_chats/<machine>/db/mimocode.db{,-wal,-shm}`. Keep per-backup
   snapshots in dated subfolders (`2026-09-23/`) rather than overwriting.
5. Commit and push to the private repo's `main`. Warn (don't block) on files
   over GitHub's 50 MB soft limit — the DB can exceed it.
6. **Public-repo discipline:** nothing from the store is ever committed to
   `popcre/ai-devops` or any public repository, issue, log, or prompt.

## Mining

Run every query against the **copy** with Python stdlib `sqlite3` (see
[`queries.md`](queries.md)). Schema is unqualified as of 2026-09-23 — the
first mining session must record table/column names it actually observes
before relying on the sample queries.
