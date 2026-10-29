# Should transcript data live in an organized store? (2026-10-29)

**Question (Albert, 2026-10-29).** Should we set up an organized store, such as a database, for transcript data? Today every question means the AI has to find the transcripts, feed them to ScaleDown, and process the output again from scratch.

## What we do today, and what it cost

Today's three studies used the same steps each time:
1. Walk the about 25 GB Dropbox `ai/chat_transcripts/` archive.
2. Keyword-prefilter it.
3. Send the chunks to ScaleDown.
4. Throw the results away.

The cost of the 2026-10-29 studies:

| Study | Prefilter time | ScaleDown chunks | ScaleDown wall time |
|---|---|---|---|
| Reviewer failures | about 10 min | 392 | about 30 min |
| Reviewer quality | about 5 min | 273 | about 20 min |
| Review value, full archive | about 40 min | 3,842 | about 2 h |

Every new question pays the full cost again, and so does every re-cut of an old question. The tools also got in the way: one run hit the 10-minute tool limit, which needed a relaunch.

## Options

**(a) Keep it ad hoc.**
- Pays the full cost again for every question.
- Results are lost when the session's temp folder is cleaned.
- Rejected.

**(b) A local SQLite full-text index of normalized transcript turns.**
- Updated incrementally from the archive: only new or changed files are re-read.
- A keyword or phrase search takes seconds instead of a 40-minute walk.
- It stays on the machine, so it never enters a repo or a cloud database.

**(c) The index from (b), plus stored ScaleDown labels.**
- Each label is stored per session and per question.
- Re-cutting an old question (by repo, work type or reviewer) becomes one query, with no ScaleDown spend.
- A new question pays ScaleDown only for the sessions not yet labelled for it.

**(d) The shared Supabase database.**
- Rejected.
- Transcripts are private and hold redacted-but-sensitive material. Shared-db is a business database with its own change process, and the data has no business purpose there.
- It would also widen who can read the transcripts.

## Recommendation: (c), local on edge-dev3

**What it needs:**
- A store under `~/.local/share/ai-devops/transcript-index/` holding two files: `index.db` for full-text turns and `labels.db` for ScaleDown labels.
- Secret-shaped strings redacted on the way in.
- A daily job that does two things: runs the existing `claude-transcript-backup` skill, so the archive is fresh, and then updates the index incrementally.

**What Albert does:**
- Nothing new: he keeps asking questions in plain words.
- The AI queries the store first. It goes back to raw transcripts and ScaleDown only for sessions the store hasn't labelled yet.

## Prototype evidence (2026-10-29)

**The labels store.**
- The 3,842 ScaleDown outputs from the review-value study were loaded into `labels.db`: 6,490 review labels.
- The shared-db "value by type of work" query that took about 2 hours of extraction now answers in **0.001 s**.

**The full-text index.**
- One full build over the whole archive took more than 10 minutes and passed 4.5 GB while still running. Exact final figures go on the issue.
- This is a one-time cost. Later runs re-read only changed files.

**The prototype script.** It lives at the session-local path below, not in the repo:

```
/tmp/claude-1000/-home-ahazan-repos-ai-devops--claude-worktrees-xenodochial-lewin-ee7c21/62241d40-0c7e-48d5-a829-831ed1701ce3/scratchpad/tidx.py
```

## Next steps (follow-up issue)

1. Move the prototype into `tools/transcript_index.py`, with tests and a CI suite entry.
2. Add the daily backup-then-index timer on edge-dev3.
3. Add a `transcript-query` skill. It tells sessions to query the store before touching raw transcripts or ScaleDown, and to write new labels back.
4. Cover all machines. Today the archive is only as fresh as the last manual backup; hetz, 4837 and 916 were stale on Oct 22.

## Risks

- **Disk:** the index is several GB, against about 1 TB free on edge-dev3.
- **Privacy:** the store must never be committed. It lives outside every repo and is not synced.
- **Stale labels:** ScaleDown labels are approximate and tied to the prompt that made them. Store the prompt text with each label set, so a better prompt can relabel later.
