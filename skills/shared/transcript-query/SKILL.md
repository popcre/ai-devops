---
name: transcript-query
description: Answer questions about past AI sessions from the shared topic-cut transcript store with ai-transcript-query. Use for "look through transcripts", "what have we learned about X", "how often does Y happen", "search past sessions", or any question whose evidence is in Albert's chat transcripts. Never bulk-reads raw transcripts or pastes transcript text into GitHub.
---

# transcript-query

The transcript store is a read-only SQLite copy of every session, cut into
topic-labelled segments, published to Dropbox `ai/transcript-store/`. Plan:
[`plan_transcript-store.md`](../../../plan_transcript-store.md) (#2050).

## Steps

1. **Query the store first** with `ai-transcript-query`:
   - `--topic <slug> --repo <repo> --since YYYY-MM-DD --text "<words>"` prints
     matching segment subjects and capped text (`--limit N`, default 20).
   - `--stats` prints counts by topic and repo, and each machine's last session
     time in New York time; `STALE` marks a machine silent for over 2 days.
2. **Raw transcripts only for drill-down, only through the pointer:**
   `--raw <segment id>` prints the raw file path in your own Dropbox archive
   and the turn range. Run `ai-task-gates start --class private-evidence`
   before opening it, and read only that range.
3. **ScaleDown only for what segments can't answer.** Use ScaleDown (never an
   LLM) on the few raw ranges you need; see `scaledown-compress`.
4. **Write new question labels back** through the inbox:
   `--add-labels <file.jsonl>` validates the file (one JSON object per line with
   exactly `question`, `src`, `prompt_version`, `fields`) and queues it; the
   daily writer applies it once.
5. **Never paste raw transcript or segment text into GitHub** (the repo is
   public). Post counts and conclusions only.

## When it fails

- "store not available locally": Dropbox has not synced `ai/transcript-store`;
  make that folder available offline in Dropbox, then re-run.
- `FALLBACK` in `--stats`: the newest version was still syncing; an older
  verified version answered. Re-run later for current data.
