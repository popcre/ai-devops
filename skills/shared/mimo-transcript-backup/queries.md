# MiMoCode transcript-mining cookbook — SQL against the COPIED database

Run every recipe with Python's stdlib `sqlite3` against a **copy** of
`mimocode.db` (with its `-wal`/`-shm` sidecars), never the live file:

```bash
python - <<'EOF'
import sqlite3
con = sqlite3.connect(r'C:\path\to\copy\mimocode.db')
for row in con.execute("<one of the queries below>"):
    print(row)
con.close()
EOF
```

**Schema status (2026-09-23):** table and column names below are
**provisional** — inferred from MiMoCode's documented memory/session layout.
Before relying on them, open the copy and record what is actually there:

```sql
SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;
```

Update this file after the first real mining session (ZCode's
`queries.md` was live-qualified the same way).

## Discover schema

```sql
SELECT name, sql FROM sqlite_master WHERE type='table' ORDER BY name;
```

## Sessions (adapt to real table names)

```sql
-- placeholder: replace session_table / ts_column after discovery
SELECT count(*) FROM session;
```

## Token / usage totals (adapt after discovery)

```sql
-- placeholder: replace usage table/columns after discovery
SELECT date(ts/1000, 'unixepoch') AS day, count(*)
FROM model_usage
GROUP BY 1 ORDER BY 1 DESC;
```

## Public-repo discipline

Query results may contain prompt text and tool output. Keep raw rows in the
private transcripts checkout only. Summaries that leave that checkout must be
aggregates (counts, dates, tool names) — never verbatim transcript bytes.
