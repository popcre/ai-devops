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

## Next steps (follow-up issue; superseded by the revision below)

1. Move the prototype into `tools/transcript_index.py`, with tests and a CI suite entry.
2. Add the daily backup-then-index timer on edge-dev3.
3. Add a `transcript-query` skill. It tells sessions to query the store before touching raw transcripts or ScaleDown, and to write new labels back.
4. Cover all machines. Today the archive is only as fresh as the last manual backup; hetz, 4837 and 916 were stale on Oct 22.

## Risks

- **Disk:** the index is several GB, against about 1 TB free on edge-dev3.
- **Privacy:** the store must never be committed. It lives outside every repo. (Superseded by the revision below: the published copy is shared through Albert's private Dropbox, and nowhere else.)
- **Stale labels:** ScaleDown labels are approximate and tied to the prompt that made them. Store the prompt text with each label set, so a better prompt can relabel later.

## Revision (Albert, 2026-10-29): shared across machines, topic-cut, no raw dumps

Albert asked for three things:
- **Shared:** the store must be usable from every machine.
- **Clean:** ScaleDown strips the fluff.
- **Topic-cut:** ScaleDown labels every portion of every conversation with a topic, so a reviewer question reads only the reviewer parts.

### Where it lives

A live SQLite file opened by several machines at once over Dropbox or an SMB share corrupts. Neither Dropbox nor SMB over Tailscale gives SQLite the locking it needs. The design below is safe:

1. **One writer.** edge-dev3 builds and updates the database.
2. **Published copy.** After each update it writes a finished read-only copy under a new dated file name in `Dropbox/ai/transcript-store/db/`, then updates a small pointer file last. Readers copy the named file to local temp and check it before opening, so no reader opens a half-synced file. The exact protocol is in the plan, step 4.
3. **Readers.** Every machine reads its local Dropbox copy read-only, through a local temp copy. That works offline, and nothing new is installed.
4. **Writes from elsewhere.** A machine that produces new labels drops a small file into `Dropbox/ai/transcript-store/inbox/`. The writer merges it on its next run.
5. **Privacy.** The same as the transcripts today: Albert's private Dropbox only. Never a repo, and never shared-db.

A Postgres server on edge-dev3 reached over Tailscale was considered. It allows live multi-writer access, but it adds a server to run and a client on every Windows machine. Revisit it only if the inbox delay (one run, at most daily) becomes a real problem.

### What it holds

- **`segments`**, the main table: one row per topic section. Columns: conversation, machine, repo, time, topic, subject, and the ScaleDown-cleaned text.
- **`questions`:** stored answers from earlier studies, such as the review labels.
- **Raw text:** kept only as a pointer to the Dropbox transcript file. Drill-down reads that raw file from the reader's own Dropbox copy of the archive; the raw text is never copied into the database.

### Topic extraction prototype (2026-10-29)

**Input.** One 3.4 MB hetz session from the PopDAM umbrella work: 496 K characters of text in 13 segments of 40 K characters.

**Output.** ScaleDown Summarize turned it into 20 topic sections totalling 17.6 K characters. That is **28× smaller**, in 60 s.

**Topics found:**
- database/shared-db 4
- business-rules 4
- app-feature 2
- reviewer-quality 1
- git/pr-workflow 1
- other 3
- 5 free-text topics. The build must map these back to the fixed topic list, re-asking once if needed.

**What a question now reads.** A reviewer question reads 1 section instead of the whole 496 K characters.

### Full build estimate

- **Volume.** The text in the about 25 GB archive is roughly 15% of the file size. After de-duplicating forked conversations, that is roughly 3–4 G characters, or about 90,000 ScaleDown calls.
- **Time.** About 15 hours at 8 in parallel, run once in the background. After that, daily runs process only new conversations.
- **Cost.** Not a criterion: Albert ruled ScaleDown cost irrelevant (2026-10-29). The first 1,000 calls are a quality and failure-rate check only (plan step 5).

## Topic list and mining checks (Albert, 2026-10-29)

**Topics.** Each ScaleDown section gets one to three of these. The plan (§8) adds decision rules for the overlapping ones. Every section also carries its app or repository as a separate field.
- CI issues
- reviewer model quality
- reviewer tooling
- ai-devops process and tooling
- database and shared-db
- machines, setup and installs
- vendor credit and quota
- secrets and credential incidents
- AI mistakes, rework and unverified claims, including hallucinations and a false "done"
- agent loops: repeating the same action without progress
- agent stuck waiting without realizing it
- waiting and idle time
- token waste in the working process
- token waste in tools
- repeated work that should be a skill
- owner decisions and rulings
- business rules
- other ideas for working better with AI
- other

**Mining checks.** These run after labeling, across many sessions, together with the skill and instruction files. They are not per-section topics.
- **Skill bypassing:** sections doing by hand what an existing skill covers.
- **Unused or redundant instructions:** instruction text that never shows up in behaviour, or is duplicated.
- **Overlapping trigger phrasing:** skill descriptions that compete for the same request.
- **Tool-sequence anti-patterns:** repeated or wasteful tool-call chains.
  - These need the sequence of tool calls, which ScaleDown's cleanup removes.
  - The store therefore also keeps per-section tool-call names and counts, without their output.
- **Orphaned resources and stale references:** paths, issues, branches or skills that are referenced but no longer exist.
- **Hallucination and verification checks:** claims in sections tagged "AI mistakes" are cross-checked against Git and GitHub.
