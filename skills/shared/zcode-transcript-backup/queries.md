# ZCode transcript-mining cookbook — SQL against the COPIED database

Run every recipe with Python's stdlib `sqlite3` against a **copy** of
`db.sqlite` (with its `-wal`/`-shm` sidecars), never the live file:

```bash
python - <<'EOF'
import sqlite3
con = sqlite3.connect(r'C:\path\to\copy\db.sqlite')
for row in con.execute("<one of the queries below>"):
    print(row)
con.close()
EOF
```

Schema facts qualified 2026-09-17 against CLI 0.16.5 (evidence:
`tests/verification/zcode-windows-2026-09-17/` in `popcre/ai-devops`):
timestamps are **epoch milliseconds** (`datetime(ts/1000,'unixepoch')`);
`tool_usage.status` vocabulary is `completed | error | running`;
`model_usage.status` is `completed | error | cancelled`. Main tables:
`session`, `message`, `part` (message bodies are JSON in `data`), `turn_usage`,
`model_usage`, `tool_usage`, `input_history`, `todo`, `session_entry`.

## Sessions per project over time

```sql
select s.project_id,
       date(s.time_created/1000, 'unixepoch') as day,
       count(*) as sessions
from session s
group by 1, 2
order by 2 desc, 3 desc;
```

## Most-used and most-failing tools

```sql
select tool_name,
       count(*) as calls,
       sum(case when status != 'completed' then 1 else 0 end) as non_completed,
       round(avg(duration_ms)/1000.0, 1) as avg_seconds
from tool_usage
group by 1
order by calls desc;
```

## Model and token spend per session

```sql
select mu.session_id,
       mu.model_id,
       count(*) as requests,
       sum(mu.computed_total_tokens) as total_tokens,
       sum(mu.input_tokens) as input_tokens,
       sum(mu.output_tokens) as output_tokens,
       sum(mu.cache_read_input_tokens) as cache_read_tokens,
       round(sum(mu.duration_ms)/1000.0, 1) as model_seconds
from model_usage mu
group by 1, 2
order by total_tokens desc;
```

## Longest sessions and their prompts

```sql
select s.id,
       s.title,
       count(distinct t.turn_id) as turns,
       sum(t.computed_total_tokens) as tokens,
       datetime(min(t.started_at)/1000, 'unixepoch') as first_turn,
       datetime(max(t.completed_at)/1000, 'unixepoch') as last_turn
from session s
join turn_usage t on t.session_id = s.id
group by s.id, s.title
order by turns desc;
```

The opening prompt of a session:

```sql
select s.id, s.title, ih.text
from session s
join input_history ih on ih.session_id = s.id
where ih.kind = 'user'
order by s.time_created desc
limit 20;
```

## Failed model requests with their errors

```sql
select datetime(started_at/1000, 'unixepoch') as at,
       session_id, model_id, status, error_type, substr(error_message, 1, 160)
from model_usage
where status != 'completed'
order by started_at desc;
```

## Per-turn shape (how many model requests and tool calls each turn makes)

```sql
select turn_id,
       session_id,
       model_request_count,
       tool_call_count,
       tool_error_count,
       computed_total_tokens
from turn_usage
order by computed_total_tokens desc
limit 25;
```

## Prompt-shape analysis on the rollout JSONL (not SQL)

The raw model I/O lives beside the DB in `model-io-sess_<uuid>.jsonl` — one
JSON object per line. Count request sizes per session file:

```bash
for f in rollout/model-io-sess_*.jsonl; do
  printf '%s %s\n' "$(wc -l < "$f")" "$(basename "$f")"
done | sort -rn | head -20
```

Inspect one object's keys before writing any parser — the record shapes differ
between request and response capture lines.
