# Plan — shared, topic-cut transcript store

**Issue:** popcre/ai-devops#2050.
**Design record:** [docs/transcript-store-decision-2026-10-29.md](docs/transcript-store-decision-2026-10-29.md).
**Handoff:** [HANDOFF.d/2026-10-29T2015Z-edge-dev3-claude-transcript-store-plan.md](HANDOFF.d/2026-10-29T2015Z-edge-dev3-claude-transcript-store-plan.md).

## STATUS (read first; do not re-plan)

| Step | State | Evidence |
|---|---|---|
| 1 Daily upload from every machine | ⬜ open | — |
| 2 Normalizer and tool-call capture | ⬜ open | — |
| 3 ScaleDown clean + topic segmenter | ⬜ open | — |
| 4 Store schema, writer and Dropbox publish | ⬜ open | — |
| 5 Smoke batch: first 1,000 calls | ⬜ open | — |
| 6 Full backfill (about 15 h, background) | ⬜ open | — |
| 7 Daily timer on edge-dev3 | ⬜ open | — |
| 8 Reader helper and `transcript-query` skill | ⬜ open | — |
| 9 Mining checks | ⬜ open | — |

**A fresh session starts at step 1.** Steps 1 and 2–4 can run in parallel. Step 5 is a quality check before step 6.

**Stages, as GitHub child issues of #2050:**

| Stage | Plan steps | What it covers |
|---|---|---|
| A | 1 | upload |
| B | 2–4 | pipeline |
| C | 5–7 | backfill and timer |
| D | 8 | reader and skill |
| E | 9 | mining |

Child issues: A #2059, B #2060, C #2061, D #2062, E #2063.

> **Owner rulings (Albert, 2026-10-29), apply to every step:**
> - **ScaleDown cost does not matter.** He said: "scaledown is close to free. don't worry about scaledown costs." There is no cost gate for ScaleDown.
> - **Minimize LLM use.** He said: "we only have to keep an eye on costs when it comes to LLMs, which we absolutely want to minimize use of in favor of Scaledown.ai in every way possible and in every place possible." Any reading, cleaning, labelling, summarizing or extraction of transcript text uses ScaleDown, never Claude, Codex or another LLM. The implementing session's own context should touch only counts, schemas and small samples.
> - **Reviewers never block.** He said: "disregard reviewers for now. do what you need to do without worrying about it getting reviewed. if the reviewers work, great, get the review. if they don't, don't let it hold you back." Merge on green CI. If the `ai-review` check or any reviewer fails or is unavailable, merge anyway and note it on the PR.

---

## Part 1 — Why

### 1. Ultimate goal

Albert (the business owner, non-technical) wants to ask questions about how his AI work is going. For example: "why do reviewers keep failing?", "where are we wasting tokens?", "what should become a skill?".

He wants the answer to come from a ready, organized store, not from an AI rediscovering raw transcripts, re-sending them to ScaleDown and reprocessing them each time.

The store must have these properties:
- **Shared:** readable from every machine.
- **Private:** only Albert's Dropbox; never GitHub, and never the business database.
- **Clean:** ScaleDown has removed the fluff.
- **Topic-cut:** every portion of every conversation carries a topic label. A question about reviewers then reads only the reviewer portions, and an expensive model never reads the 90% that is about something else.

**If a step conflicts with this goal, the goal wins.** Stop and flag it on #2050.

### 2. What this is

`popcre/ai-devops` is Albert's AI toolkit. It holds scripts in `bin/` and `tools/`, skills in `skills/`, an installer, and tests in `tests/`. The repository is **public**, so this plan's code goes there, but **no transcript content ever does**.

**Machines:**

| Machine | Operating system |
|---|---|
| edge-dev3 | Linux. The always-on build host and the store writer. |
| hetz | Linux |
| edge-dev | Windows |
| 4837 | Windows |
| 916 | Windows |
| al8960ofc | Linux. Also seen as hostname edge-dev3 in some contexts; check `hostname`. |

**Transcript sources on each machine:**
- Claude Code: `~/.claude/projects/**.jsonl`
- Codex: `~/.codex/sessions/`, `~/.codex/archived_sessions/`
- Others under each machine's folder, such as ZCode/MiMo sqlite on edge-dev. Those are skipped in v1.

**Archive:** `~/Dropbox/ai/chat_transcripts/<machine>/` holds raw copies, uncompressed. The total is about 25 GB, going back to April 2026. Copies arrive only when someone runs the `claude-transcript-backup` skill (`skills/claude/claude-transcript-backup/SKILL.md`) by hand. Nothing is automatic today.

### 3. What triggered this

On 2026-10-29 three studies each re-walked the archive and paid ScaleDown again:

| Study | Prefilter | ScaleDown calls | ScaleDown time |
|---|---|---|---|
| Reviewer failures | about 10 min | 392 | about 30 min |
| Reviewer quality | about 5 min | 273 | about 20 min |
| Review value | about 40 min | 3,842 | about 2 h |

The results lived in session temp folders and were lost.

Albert then asked for a shared database instead (2026-10-29, quoted in the design doc). His words: "i don't want an expensive LLM to have to read the irrelevant 90% of the conversation just to find the relevant 10%".

### 4. Scope

**In:**
- Daily automatic upload of transcripts from all 5 machines to Dropbox.
- Normalizing Claude and Codex `.jsonl` transcripts.
- ScaleDown cleaning and topic segmentation.
- A SQLite store built on edge-dev3 and published read-only to Dropbox.
- An inbox for writes from other machines.
- A daily incremental timer.
- A reader helper and skill.
- The 5 mining checks.
- Importing the existing review labels.

**NOT in this plan:**
- ZCode/MiMo sqlite transcripts (edge-dev). Add them as a follow-up issue.
- A web UI or dashboard.
- Postgres, Supabase or shared-db.
- Re-labelling with any LLM other than ScaleDown.
- Deleting or pruning anything in the Dropbox archive.
- Changing the reviewer system (#2041).

---

## Part 2 — What we know

### 5. Current state

**Nothing has been built in the repo.**

**Session-local prototypes.** These live on edge-dev3 and are not durable. Their logic is described in full below, so they are not needed.

| Prototype | Where | What it does |
|---|---|---|
| `tidx.py` | the 2026-10-29 session scratchpad | Builds `~/.local/share/ai-devops/transcript-index/index.db`, an FTS5 table of raw turns. A full build ran more than 10 min and passed 5 GB. **That approach is superseded:** the store holds cleaned segments, not raw turns. You may delete `index.db` once step 6 lands. |
| `labels.db` | `~/.local/share/ai-devops/transcript-index/labels.db` | 6,490 review labels in table `review_labels(src, repo, work, mode, reviewer, verdict, value, why)`, from the review-value study. Import it in step 4. |
| ScaleDown outputs | `/var/tmp/ai-sessions-1000/claude-93403b01-6a8b-4732-b1be-4bdda8f255ac/val/sum/*.md` | The 3,842 raw outputs behind `labels.db`. They may be swept; `labels.db` is the durable copy. |
| `seg.py` | the scratchpad | The topic-segmentation proof (see §6). |

**Existing pieces to reuse:**
- **Backup skills:**
  - `skills/claude/claude-transcript-backup/SKILL.md` documents where transcripts live on each operating system, how to copy them to Dropbox, and the Windows symlink trap.
  - `skills/shared/transcript-dropbox-upload/SKILL.md` covers the old private-repo-to-Dropbox route.
  - **Rule:** the private repo `u2giants/ai-devops-transcripts` is FROZEN since 2026-09-27. Never add to it.
- **Timer installer pattern:**
  - Linux: `bin/ai-install-session-tmp` installs the `ai-session-tmp-sweep.timer` user unit, tested by `tests/test-ai-install-session-tmp.sh`.
  - Windows: `bin/ai-housekeeping` and `setup-machine.ps1` use `Register-ScheduledTask`.
- **CI suite registration:**
  - Every new `tests/test-*.sh` needs `config/ci-suites/<name>.json`, for example `{"kind":"bash","linux_seconds":5}`.
  - It also needs path entries in `config/ci-suite-manifest.json`.
  - The workflow-policy suite fails otherwise; PR #2044 hit this.

### 6. Key findings

**Topic segmentation works with ScaleDown Summarize.** Prototype run, 2026-10-29:
- **Input:** one 3.4 MB hetz session from the PopDAM umbrella work. It held 496 K characters of text.
- **Split:** 13 segments of up to 40,000 characters.
- **Output:** 20 topic sections, 17.6 K characters in total. That is **28× smaller**, in 60 s at 1 call at a time.
- **Off-list labels:** 5 of the 20 topics did not follow the allowed list; they were free text. The build must validate the label and re-ask once, or map it to `other`.

**The ScaleDown API:**

| Item | Value |
|---|---|
| Endpoint | `POST https://api.scaledown.xyz/v1/chat/completions` |
| Header | `x-api-key` |
| Body | `{"model":"summarize","messages":[system, user]}` |
| Reply | `choices[0].message.content` is often a JSON string with a `summary` field. Fall back to the raw string. |
| Timeout | 300 s per call worked |
| Concurrency | 6–8 threads worked. Retry each call up to 3 times. |
| Known failure | about 10 of 392 calls failed transiently once; a re-run fixed them |

**The API key** comes from 1Password vault `vibe_coding`, item `scaledown.ai API key for testing` (item id `b2ismrxfonoqigu7yht7o5rnya`, field `credential`).
- On edge-dev3, `op` has no signed-in account. Export `OP_SERVICE_ACCOUNT_TOKEN` from `~/.config/ai-devops/op-service-account` first.
- Never print the key.

**Text extraction from the `.jsonl`:**
- Each line is JSON.
- Collect every string under `message` (Claude) or `payload` (Codex). Skip the keys `signature`, `data`, `thinkingSignature` and `encrypted_content`, which are binary or noise.
- Get the working folder from `cwd` or `payload.cwd`, and the role from `type` or `payload.role`.
- Text is about 15% of the file size.

**Duplicates:**
- Claude desktop forks one conversation into several `.jsonl` files. In one sample, 16 of 57 were copies.
- De-duplicate by a hash of each turn's text, so a shared opening is processed once.

**Prefiltering:**
- Keyword prefiltering made the earlier studies affordable.
- For this store, do **not** prefilter by topic: every conversation must be labelled.
- Do skip turns under 20 characters, and cap each turn at 6,000 characters before segmenting.

**Secrets redaction.** Apply this regex to all text before anything is stored:
`(sk-[A-Za-z0-9_-]{16,}|gh[psou]_[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_.-]+|(?i:(api[_-]?key|token|password|secret)["\s:=]+)[^\s"]{12,})`.

**Archive freshness.** The Dropbox archive held nothing newer than Oct 21–22 for several machines until hand uploads. Upload is therefore the first dependency.

**Edge cases:**
- On edge-dev, `C:\Users\ahazan\.claude\projects` and `.codex\sessions` are symlinks into `D:\ai-data\...`. Copy from the target folder; `find` and robocopy on the symlink path see 0 files.
- On hetz, transcripts exist under both `/root` and `/home/ai`.

### 7. Rejected approaches

**(a) Ad hoc per question.** This is today's way, and it is what triggered this work.

**Raw full-text index only** (the first prototype).
- It is several GB.
- An LLM would still have to read irrelevant text.
- Albert rejected raw-only storage.

**A live SQLite file opened by several machines on Dropbox or SMB-over-Tailscale.**
- Neither gives SQLite the file locking it needs.
- Concurrent writers corrupt the database, and Dropbox creates conflicted copies.
- Albert asked about this; it is answered in the design doc.

**Postgres on edge-dev3 over Tailscale.**
- It allows live multi-writer access, but it adds a server to run and a client on each Windows machine.
- Not needed while only edge-dev3 writes.
- Revisit only if the one-day inbox delay hurts.

**Supabase or shared-db.** Rejected because:
- it is a business database with its own change process;
- private transcripts have no business purpose there;
- it widens who can read them.

**Using an LLM (Claude, Codex) for cleaning or labelling.** Albert said not to: ScaleDown is the cheap extractor.

### 8. Decisions

**Locked (Albert, 2026-10-29):**
- edge-dev3 is the single writer.
- Every other machine only uploads raw transcripts to Dropbox and reads the published copy.
- The published store is a read-only SQLite file in Albert's private Dropbox.
- Remote writes go through an inbox folder.
- ScaleDown cleans and topic-labels every portion of every conversation. The store keeps cleaned segments plus a pointer to the raw file, never raw text.
- Tool-call names and counts are kept per segment, because the anti-pattern mining needs the sequence.
- The topic list is fixed (below).
- Hallucinations fold into "AI mistakes".

**Topics:**

| Topic slug | Covers |
|---|---|
| `ci` | CI issues |
| `reviewer-model` | reviewer LLM quality |
| `reviewer-tooling` | reviewer tooling |
| `ai-devops-process` | ai-devops process and tooling |
| `database` | database and shared-db |
| `machines-setup` | machines, setup and installs |
| `vendor-credit` | vendor credit and quota |
| `secrets` | secrets and credential incidents |
| `ai-mistakes` | mistakes, rework, unverified or false claims, hallucinations |
| `agent-loop` | agents repeating the same action without progress |
| `agent-stuck-waiting` | agents waiting idle without realizing it |
| `idle-waiting` | general waiting and idle time |
| `token-waste-process` | token waste in the working process |
| `token-waste-tools` | token waste in tools |
| `should-be-skill` | repeated work that should be a skill |
| `owner-decision` | owner decisions and rulings |
| `business-rules` | business rules |
| `ai-interaction-ideas` | other ideas for working better with AI |
| `other` | anything else |

**Each segment carries:**
- one or more topics;
- a specific 3–8 word subject;
- the app or repository (from `cwd`, or from the text), so "reviewer issues in DesignFlow" needs no extra topic.

**Mining checks.** These run after labelling, across sessions, together with the skill and instruction files. They are not topics.
- skill bypassing
- unused or redundant instructions
- overlapping trigger phrasing
- tool-sequence anti-patterns
- orphaned resources and stale references
- hallucination and verification cross-checks against Git and GitHub

**Open for the implementer:**
- Segment size: 40 K characters worked; anything from 30–60 K is fine.
- Thread count: 6–8.
- Exact column names, as long as §9 step 4's fields exist.
- The daily run time.

---

## Part 3 — How to build it

> **Context cut points:** after step 4, and after step 6. Re-read the downstream steps before starting each phase.

### 9. Steps

#### Step 1 — Daily upload on all 5 machines

**What to build:**
- **Linux:** `bin/ai-transcript-upload`. It copies new or changed files from the sources in §2 into `~/Dropbox/ai/chat_transcripts/<hostname>/{claude,codex}/<relative path>`. It copies only what is missing or older, never deletes, and never reads contents.
- **Windows:** `bin/ai-transcript-upload.ps1`, plus the `.cmd` twin the repo requires for `bin/` scripts. It uses robocopy `/XO`, without `/MIR` or `/PURGE`.
- **Install:** schedule it daily with the existing patterns: a systemd user timer like `bin/ai-install-session-tmp` on Linux, and `Register-ScheduledTask` like `bin/ai-housekeeping` on Windows.
- **Machine-specific paths:**
  - edge-dev: copy from `D:\ai-data\...`, the symlink targets.
  - hetz: copy from both `/root` and `/home/ai`.
- **Skill:** update `skills/claude/claude-transcript-backup/SKILL.md` to say it is now automatic and the skill is the manual fallback.

**Done when:**
- `tests/test-ai-transcript-upload.sh` passes. It must cover: copies new; skips identical; never deletes in the destination; follows the symlink target.
- On each of the 5 machines the scheduled task exists and has run once.
- `find ~/Dropbox/ai/chat_transcripts/<m> -newermt today` is non-empty for each machine, checked from edge-dev3.
- The proof is posted on #2050 with times in EDT.

**Installing on machines** is the `installation` task class. Run `ai-task-gates start --class installation` first. The observation-week freeze window file (#1948) refuses installation while it is present: check whether it is still on each host, and if so wait for #2041 step 4 to lift it.

#### Step 2 — `tools/transcript_store/normalize.py`

**Input:** one `.jsonl` path.

**Output:** an ordered list of turns. Each turn is `{ts, role, text, tools: [tool names called in this turn]}`.
- Tool names come from the `tool_use` blocks' `name` (Claude) or the function-call `name` (Codex).
- Plus the session metadata `{machine, path, cwd, repo, first_ts, last_ts}`. The repo is the last part of `cwd`, with worktree suffixes removed: for example `-worksp-popdam--claude-worktrees-x` becomes `popdam`, and `/home/ahazan/repos/ai-devops/.claude/worktrees/x` becomes `ai-devops`.

**Rules:**
- Apply the redaction regex from §6.
- Skip turns under 20 characters.
- Cap each turn at 6,000 characters.
- Compute `turn_hash = sha256(text)` for de-duplication.

**Done when:** `tests/test_transcript_normalize.py` passes. It must cover:
- Claude and Codex fixtures. These are tiny **synthetic** `.jsonl` files written in the test, never real transcripts.
- A redaction case.
- Signature fields skipped.
- Tool names captured.
- Repo derived from the worktree path.

#### Step 3 — `tools/transcript_store/segment.py`

**What it does:**
1. Groups a session's not-yet-seen turns (by `turn_hash`) into chunks of at most 40 K characters, cut on turn boundaries.
2. Calls ScaleDown once per chunk, with the system prompt from step 3a.
3. Parses each `### TOPIC: <slugs> | <subject> | repo=<repo>` header and the body under it.
4. Validates every slug against §8. If any is invalid, it re-asks once with "use only these slugs: …". If still invalid, the slug becomes `other`.
5. Attaches the chunk's tool-name counts to every section from that chunk.

**Step 3a — the system prompt.** Store it as `tools/transcript_store/prompt_v1.txt`. It has three parts:
- "Remove all fluff (tool output dumps, file listings, repeated text, narration). Split what remains into topic sections."
- The exact slug list from §8.
- The output format above. Keep exact error strings, decisions, outcomes and dates.

The prompt version is stored with every row (see risks).

**Reliability:**
- Threads: 6–8.
- Retries: 3, with backoff.
- On final failure, record the chunk as `failed` so the next run retries it. Never silently drop it.

**Done when:**
- `tests/test_transcript_segment.py` passes with a fake ScaleDown, an injected function. It must cover:
  - header parsing
  - an invalid slug re-asked, then mapped to `other`
  - a JSON-wrapped reply
  - a failed chunk recorded as failed
- One live run on a real edge-dev3 session gives sections with valid slugs. Record its numbers in `tests/verification/transcript-store/live-segment-<date>.txt` as counts and sizes only, with no content.

#### Step 4 — `tools/transcript_store/build.py` (the writer)

**Where it writes:**
- The working database is `~/.local/share/ai-devops/transcript-store/store.db` on edge-dev3. It is **never** written inside Dropbox.

**Schema:**

| Table | Columns |
|---|---|
| `sessions` | `path PK, machine, repo, cwd, first_ts, last_ts, mtime, size, status` |
| `segments` | `id, path, chunk_no, topic_slugs, subject, repo, text, tool_counts_json, prompt_version, created` |
| `segments_fts` | FTS5 over `subject, text` |
| `seen_turns` | `turn_hash PK` |
| `chunks` | `path, chunk_no, status (ok/failed), error, created` |
| `question_labels` | `question, src, fields_json, created` |
| `inbox_applied` | `filename PK` |

**Import:** `labels.db` `review_labels` goes into `question_labels`, with `question='review-value-2026-10-29'`.

**Flow:**
1. Scan the archive.
2. For every session whose `mtime` or `size` changed: normalize, then segment the new turns, then insert.
3. Apply each file in `Dropbox/ai/transcript-store/inbox/*.json` exactly once. Each file is JSON lines of `question_labels`. Validate fields; a bad file goes to `inbox/rejected/`.

**Publish:**
1. `sqlite3 store.db ".backup <tmp>"`.
2. Run `PRAGMA integrity_check` on the copy.
3. Copy it to `Dropbox/ai/transcript-store/store.db.tmp`.
4. Rename it to `store.db` in a single atomic step.

**Done when:** `tests/test_transcript_build.py` passes. It must cover:
- incremental rebuild skips an unchanged file;
- changed file re-processed only for new turns;
- an inbox file applied once;
- a bad inbox file rejected;
- the published copy passes the integrity check and opens read-only.

#### Step 5 — Smoke batch

- Run `build.py --limit-calls 1000` on the newest sessions.
- Record the wall time, calls, failures, and the slug-validity rate in `tests/verification/transcript-store/smoke-<date>.txt`. Cost is not a criterion (owner ruling, 2026-10-29).
- If the failure rate is above 5% or more than 10% of slugs are invalid, fix the prompt or parser before step 6.

**Done when:** the file exists, and a comment on #2050 states the projection.

#### Step 6 — Full backfill

- Run `build.py` over the whole archive in the background: `systemd-run --user` or `nohup`. Expect about 15 h: about 90,000 calls at 8 threads.
- It must resume after a crash: chunks marked `ok` are skipped.

**Done when:**
- every session is `status=ok` or has listed `failed` chunks, and the failed ones are under 1% and retried once;
- the published `Dropbox/ai/transcript-store/store.db` exists;
- `select topic_slugs, count(*) from segments group by 1` is posted on #2050.

#### Step 7 — Daily timer on edge-dev3

- `bin/ai-install-transcript-store` installs `ai-transcript-store.timer`, which runs daily after the upload timers, for example at 05:30 local. It runs `build.py` and then publishes.
- The pattern is `bin/ai-install-session-tmp`.

**Done when:**
- `systemctl --user list-timers | grep ai-transcript-store` shows it;
- the next day, the published file's mtime is fresh, and the segment count grew if new sessions arrived.

#### Step 8 — Reader helper and skill

**The helper, `bin/ai-transcript-query`** (with a `.cmd` twin):
- Opens the local Dropbox `store.db` read-only. It uses the SQLite URI `?mode=ro&immutable=1` so Dropbox never sees writes.
- **Search mode:** `--topic reviewer-tooling --repo designflow --since 2026-10-01 --text "402"`. It prints segment subjects and text, capped.
- **Statistics mode:** `--stats` prints counts by topic and repo.
- **Inbox mode:** `--add-labels <file>` validates a labels file and writes it to the inbox.

**The skill, `skills/shared/transcript-query/SKILL.md`.** Its triggers are questions like "look through transcripts", "what have we learned about X", "how often does Y happen". It tells sessions:
1. Query the store first.
2. Read the raw transcripts only through the `path` pointer, and only for drill-down.
3. Call ScaleDown only for questions the stored segments can't answer.
4. Write new question labels back through the inbox.
5. Never paste raw transcript text into GitHub.

**Also:**
- Update `skills/shared/scaledown-compress/SKILL.md` and the memory entry `scaledown-transcript-extract-2026-10-21` to point to the store.
- Link this plan from `docs/task-router.md`, the transcript row.

**Done when:**
- `tests/test-ai-transcript-query.sh` passes against a synthetic store;
- on a Windows machine (edge-dev), `ai-transcript-query --stats` reads the Dropbox copy.

#### Step 9 — Mining checks

`tools/transcript_store/mine.py`, one subcommand per check, each writing a report:

| Check | How |
|---|---|
| Skill bypassing | Match segments against `skills/**/SKILL.md` descriptions by keyword. Flag segments that do the skill's job with no record of the skill being used (no tool or skill name in `tool_counts`). |
| Unused or redundant instructions | For each instruction line in the globals (`templates/` or the installed `~/.claude/CLAUDE.md`), count segments that mention or obey it. Also find near-duplicate lines. |
| Overlapping triggers | Pairwise similarity of skill `description` fields. Report pairs above a threshold. |
| Tool-sequence anti-patterns | Over `tool_counts` and per-turn tool order: flag the same tool called 5+ times in a row, read-after-write of the same file, and polling loops. |
| Orphaned or stale references | Extract paths, issue/PR numbers, branches and skill names from segments in the last 30 days. Check that each still exists, with `git ls-files` and `gh`. |
| Hallucination cross-check | For `ai-mistakes` segments and "done/merged/fixed" claims, check the named PR or commit really exists or merged. |

**Report:**
- Reports go to `Dropbox/ai/transcript-store/reports/<check>-<date>.md`, which is private.
- A counts-only summary is posted on #2050.

**Done when:** each subcommand has a test with synthetic data and one real report exists.

### 10. Tests

| Test file | What it covers |
|---|---|
| `tests/test_transcript_normalize.py` | step 2 |
| `tests/test_transcript_segment.py` | step 3 |
| `tests/test_transcript_build.py` | step 4 |
| `tests/test-ai-transcript-upload.sh` | step 1 |
| `tests/test-ai-transcript-query.sh` | step 8 |
| `tests/test_transcript_mine.py` | step 9 |

- Each Python test is wrapped by a `tests/test-transcript-store.sh` runner and registered in `config/ci-suites/` and `config/ci-suite-manifest.json`.
- All fixtures are synthetic.
- These existing suites must stay green: `test-workflow-policy.sh`, `test-markdown-links.sh`, `bin/ai-doc-safety .`, and the bin/cmd launcher suite (`test-bin-cmd-launchers.sh` or equivalent).
- Run them on edge-dev3 with `PYTHONDONTWRITEBYTECODE=1`.

**Adversarial cases (transcripts and the inbox are untrusted input):**

| Input | Hostile case | Test |
|---|---|---|
| Transcript `.jsonl` | A malformed line or a non-object JSON value | `test_normalize_skips_malformed_lines` |
| Transcript text | Holds an API key or token | `test_normalize_redacts_secrets` |
| Transcript text | Holds a fake `### TOPIC:` header meant to inject labels | `test_segment_header_only_from_reply` (headers are parsed only from the ScaleDown reply, and the reply's slugs are validated) |
| ScaleDown reply | Empty, wrapped in JSON, not JSON, or an HTTP 402/429 error | `test_segment_reply_shapes`, `test_segment_failure_recorded` |
| Inbox file | Bad JSON, unknown fields, an oversized file, or a path in a field | `test_build_inbox_rejects_bad_file` |
| Inbox filename | Path traversal (`../`) | `test_build_inbox_rejects_traversal` |
| Published file | Dropbox serves a partially-synced file | `test_query_opens_readonly_immutable`; the publish writes a temporary file and then renames it |

### 11. Constraints and gotchas

**Privacy:**
- `popcre/ai-devops` is PUBLIC.
- Never commit, paste or post transcript content, segment text, `store.db`, or real-transcript fixtures.
- Verification files are counts and sizes only.
- Run `bin/ai-doc-safety .` before every PR.

**Raw transcripts:**
- Raw transcripts are private evidence: run `ai-task-gates start --class private-evidence` before reading them.
- Never put transcripts in `u2giants/ai-devops-transcripts`, which is frozen.

**Dropbox:**
- Never write `store.db` while Dropbox is syncing it. Only the atomic publish rename touches that path.
- Never delete or prune anything in `Dropbox/ai/chat_transcripts/`.

**Secrets and tools:**
- ScaleDown is the only model that reads raw text. Claude and Codex must not bulk-read transcripts.
- Secrets come from 1Password `vibe_coding` only. Never put them on the command line or in logs.

**Process:**
- Reviewers never block; see the owner rulings under STATUS.
- Branch, then PR, then merge yourself. Albert does not merge.
- Prose-only PRs: `gh pr merge --squash --admin` after doc-safety.
- Code PRs go through the merge queue: `gh pr merge --squash` enables it.
- Commit as Albert's verified identity with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Sign GitHub posts with `$AI_GH_SIGNATURE`.
- Quote times in EDT.

**Waiting and installs:**
- Wait on PR checks with `bin/ai-pr-wait <pr>` run in the background. A hook blocks hand-written polling loops.
- Installation is blocked while the observation-week window file exists (#1948). See step 1.

**Windows:**
- PowerShell 5.1 strips quotes from native arguments; test with both `powershell` and `pwsh`.
- Avoid CRLF in bash scripts.

### 12. Access and environment

**Hosts:**
- **edge-dev3:** this Linux host, user `ahazan`. The repo is at `/home/ahazan/repos/ai-devops`; use worktrees for edits.
- **Dropbox root:** `~/Dropbox`.
- **SSH to other hosts** uses key `~/.ssh/916-alien`:
  - hetz: `ssh -i ~/.ssh/916-alien root@hetz`
  - edge-dev, 4837 and 916: Windows OpenSSH; the host aliases are in `~/.ssh/ai-devops.conf`.

**Secrets and GitHub:**
- **ScaleDown key:** see §6.
- **GitHub:** `gh` is authenticated as u2giants.

**Python:**
- Python 3.14 with stdlib only. `sqlite3` with FTS5 is available.
- Use `python3`; hetz has no `python`.

---

## Part 4 — Landing

### 13. Definition of done, and risks

**Done when:**
- Steps 1–9 are merged, and the CI suites are green.
- The upload task runs on 5/5 machines.
- The full store is published in Dropbox.
- The daily timer has run on two consecutive days.
- `ai-transcript-query` works on edge-dev3 and on one Windows machine.
- One real question has been answered from the store with no new ScaleDown spend. For example, re-derive the shared-db review-value table.
- This plan's STATUS table cites an artifact for each row.
- #2050's `- [ ] live proof` is ticked with the evidence links, and the handoff is closed.

**Risks:**

| Risk | Mitigation |
|---|---|
| ScaleDown rate limits | Step 5's smoke batch finds them before the backfill. |
| Label quality: ScaleDown topics are approximate | `prompt_version` is stored, so a better prompt can relabel later (`build.py --relabel --prompt v2`). |
| Disk | The working DB is expected under 2 GB; edge-dev3 has about 1 TB free. |
| Dropbox conflicted copies | Avoided by the single writer and atomic rename. If `store (conflicted copy).db` appears, the writer deletes it on the next run. |
| A machine's upload fails silently | `--stats` shows the last session time per machine. The skill tells sessions to report a machine more than 2 days stale. |

**Rollback:** disable the timers and delete `Dropbox/ai/transcript-store/`. The raw archive is untouched.

---

## Self-audit (2026-10-29)

1. **Could a fresh session execute this without asking anything?** Yes.
   - §2 and §12 give the hosts and paths.
   - §5 lists what exists and its exact locations.
   - §6 gives the API, the key location, the extraction rules and the regex.
   - §9 names every file, schema and done-when.
   - §8 fixes the topics.
   - Gaps found and fixed while drafting: the freeze blocking installation (step 1); the repo-name derivation rule (step 2).
2. **Does it carry all the background, including what was ruled out?** Yes.
   - §3 covers the cost history.
   - §7 covers ad hoc, raw-only, live SQLite on Dropbox or SMB, Postgres, Supabase, and LLM labelling.
   - §6 covers the prototype numbers and their pitfalls.
3. **Is the goal clear enough for judgment calls?** Yes: §1 says shared, private, clean and topic-cut, why, and "goal wins".
