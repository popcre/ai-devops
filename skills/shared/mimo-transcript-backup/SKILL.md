---
name: mimo-transcript-backup
disable-model-invocation: true
description: Mine a COPY of MiMoCode's SQLite session store (mimocode.db) by direct SQL (queries.md). Daily MiMo uploads stopped 2026-11-24; the private Git transcript repo is frozen since 2026-09-27. Use when explicitly asked to inspect or mine local MiMoCode sessions.
---

# mimo-transcript-backup

> **Frozen archives — read before running:**
> - `u2giants/ai-devops-transcripts` is a **frozen historical archive** (last upload 2026-09-27). Never add transcripts to it, and never commit transcript content to `popcre/ai-devops` or any public repository.
> - Daily MiMo uploads to Dropbox stopped on **2026-11-24** (`plan_transcript-store.md`); existing `ai/chat_transcripts/<machine>/mimo/` copies and store rows stay untouched. There is no automated Dropbox uploader for MiMo.

Like ZCode, MiMoCode keeps session history in a **relational SQLite store**,
so this skill does NOT convert anything into a JSONL pile: it copies the store
locally and queries it by SQL. Mining recipes live in [`queries.md`](queries.md)
next to this file.

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

## Local copy-and-inspect procedure

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
   Prefer copying with MiMo Desktop closed when convenient.
   Verify the copy parses before querying it.
3. **Public-repo discipline:** nothing from the store is ever committed to
   `popcre/ai-devops` or any public repository, issue, log, or prompt. Remove
   the temporary `/tmp/mimo-backup-$USER` copy when finished.

## Mining

Run every query against the **copy** with Python stdlib `sqlite3` (see
[`queries.md`](queries.md)). Schema is unqualified as of 2026-09-23 — the
first mining session must record table/column names it actually observes
before relying on the sample queries.
