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

**A fresh session starts with Stage B (steps 2–4) and Stage D (step 8), which need no installs.** Step 1 writes and tests its scripts at once, but installing them on hosts waits while the observation-week freeze window file (#1948) is present on that host; check first with `ai-task-gates start --class installation`. The freeze never blocks B or D. Step 5 is a quality check before step 6.

**Order:** environment check (§12) → B → (D in parallel) → A install when unfrozen → C → E.

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
> - **Single writer, Dropbox, ScaleDown-only text processing, fixed 19-slug topic list** are also locked. Do not reopen them.
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

**Host inventory.** This table is the single list of hosts. Every other section says "every active host in this table", never a number.

| Archive folder (`chat_transcripts/<folder>`) | Live `hostname` | OS | Role | Last file in archive (2026-10-29 check) |
|---|---|---|---|---|
| `edge-dev3` | `edge-dev3` | Linux (Ubuntu) | active: uploader and the store writer | 2026-10-29 |
| `hetz` | `hetz` | Linux | active uploader, pulled by edge-dev3 over SSH (no `~/Dropbox` for `root` or `ai`, checked 2026-10-29) | 2026-10-29 |
| `edge-dev` | `edge-dev` | Windows | active uploader | 2026-10-29 |
| `al8960ofc` | `al8960ofc` (SSH alias `4837`, checked 2026-10-29) | Windows | active uploader | 2026-10-07 |
| `916-alien` | `916-alien` (SSH alias `916`, checked 2026-10-29) | Windows | active uploader; folder starts with the first automatic upload | — |
| `4837` | none (alias `4837` prints `al8960ofc`) | Windows | archive-only: older folder name of the machine now uploading as `al8960ofc` | 2026-09-06 |
| `916` | none (alias `916` prints `916-alien`) | Windows | archive-only: older folder name of the machine now uploading as `916-alien` | 2026-09-06 |
| `compshop`, `seafile`, `t16` | none known | — | archive-only: ingest, never upload | 2026-09-06 |

**Checked 2026-10-29 (#2059):** every alias in `~/.ssh/ai-devops.conf` that answered was run with `hostname`. Besides the rows above, `envy` → `edge-runn-envy` and `alien` → `edge-alien` (runner-only machines, not transcript hosts), `coolify`/`vps2` → `hetz`, `seafile` → `seafile-br`; the rest refused the key. Destination subfolders mirror the source paths (`claude/projects/`, `codex/sessions/`, `codex/archived_sessions/`; on hetz under `root/` and `ai/`), matching the layout the manual backups already used, so existing copies are not duplicated.

**Verify every "to verify" row before step 1 installs anything:** run `hostname` on edge-dev3 (it printed `edge-dev3` on 2026-10-29) and on each SSH alias in `~/.ssh/ai-devops.conf`. If no live host prints `al8960ofc`, mark the row archive-only: it is an older name for a machine whose new uploads now land under its current hostname. If one does, it is an active uploader. Record the result in this table in the same PR. The upload script always writes to `chat_transcripts/<live hostname>/`, so one host never feeds two folders. Archive-only folders are still ingested by step 4; `--stats` reports each folder separately.

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
- Daily automatic upload of transcripts from every active host in §2's table to Dropbox.
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

**The API key:** see the `scaledown-compress` skill (`skills/shared/scaledown-compress/SKILL.md`) for the key location and how to load it. Never print the key, and never write its 1Password item name or id into this public repo.

**Text extraction from the `.jsonl`:**
- Each line is JSON.
- Collect every string under `message` (Claude) or `payload` (Codex). Skip the keys `signature`, `data`, `thinkingSignature` and `encrypted_content`, which are binary or noise.
- Get the working folder from `cwd` or `payload.cwd`, and the role from `type` or `payload.role`.
- Text is about 15% of the file size.

**Duplicates:**
- Claude desktop forks one conversation into several `.jsonl` files. In one sample, 16 of 57 were copies.
- De-duplicate **per conversation lineage only**, never globally. Two unrelated sessions that both say "continue" must both keep it. The lineage rules are in step 2.

**Prefiltering:**
- Keyword prefiltering made the earlier studies affordable.
- For this store, do **not** prefilter by topic: every conversation must be labelled.
- Do skip turns under 20 characters, and cap each turn at 6,000 characters before segmenting.

**Secrets redaction.** Redaction runs in `normalize.py`, **before any text is sent to ScaleDown** and before anything is stored. Each match becomes `[REDACTED:<kind>]`. Patterns (Python `re`, all applied):

Each line is `kind<TAB>pattern`; the alternations use real `|`:

```text
anthropic	sk-ant-[A-Za-z0-9_-]{20,}
openai-style	sk-[A-Za-z0-9_-]{16,}
github	gh[psour]_[A-Za-z0-9]{20,}
github-pat	github_pat_[A-Za-z0-9_]{20,}
aws-key-id	(AKIA|ASIA)[A-Z0-9]{16}
aws-secret	(?i)aws.{0,20}secret.{0,20}[=:\s"']+[A-Za-z0-9/+=]{40}
dropbox	sl\.[A-Za-z0-9_-]{100,}
jwt	eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_.-]+
pem	-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----
op-ref	op://[^\s"'<>]+
bearer	(?i)bearer\s+[A-Za-z0-9._~+/=-]{16,}
key-value	(?i)(api[_-]?key|token|password|secret|passwd)["'\s:=]+[^\s"']{12,}
```

Store them in `tools/transcript_store/redact_patterns.tsv`; `normalize.py` and the inbox reader both load that one file. Apply `anthropic` before `openai-style`.

`op://` references are not secrets, but they map the vault, so they are redacted too. The test suite has one synthetic positive and one near-miss negative per kind. A redaction count per session is kept in `sessions.redactions`; it is never posted publicly.

**Archive freshness.** The Dropbox archive held nothing newer than Oct 21–22 for several machines until hand uploads. Upload is therefore the first dependency.

**Edge cases:**
- On edge-dev, `C:\Users\ahazan\.claude\projects` and `.codex\sessions` are symlinks into `D:\ai-data\...`. Copy from the target folder; `find` and robocopy on the symlink path see 0 files.
- On hetz, transcripts exist under both `/root` and `/home/ai`. The exact path map is in step 1.

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
- ScaleDown cleans and topic-labels every portion of every conversation. The store keeps cleaned segments plus a pointer to the raw file, never raw text. Drill-down reads the raw file from the **reader's own Dropbox** archive copy through that pointer; a reader that has no local copy (Smart Sync online-only) lets Dropbox download that one file on open. Raw text never enters the DB.
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

**Topic decision rules** (put verbatim in the prompt and in the parser's tests):
- **Multi-topic syntax:** 1–3 slugs, comma-separated, no spaces, most important first: `ci,ai-mistakes`. More than 3 keeps the first 3.
- `agent-loop` = the agent **acts** repeatedly (same command, same edit, same retry) without progress. `agent-stuck-waiting` = the agent **does nothing** while believing something is happening (waiting on a dead job, a reviewer that never answers). `idle-waiting` = legitimate or human-caused waiting (CI queue, a long build, waiting on Albert). Tie-break: action repeated → `agent-loop`; agent unaware → `agent-stuck-waiting`; otherwise `idle-waiting`.
- `token-waste-process` = waste from how the work was run (re-reading files, redoing work, oversized context). `token-waste-tools` = waste caused by a tool's output or behaviour (huge dumps, verbose logs, a tool that loops). Tie-break: a tool's own output caused it → `token-waste-tools`.
- `reviewer-model` = what a reviewer said (quality, wrong findings, missed bugs). `reviewer-tooling` = whether the review ran (wrappers, timeouts, install, auth). Tie-break: no verdict was produced → `reviewer-tooling`.
- `ai-devops-process` vs `machines-setup`: toolkit scripts, skills, globals → `ai-devops-process`; one machine's OS, install, network → `machines-setup`.
- `owner-decision` is added alongside the subject topic whenever Albert rules on something.
- `other` only when nothing else fits; never alongside another slug.
- **Subject:** 3–8 words. The parser truncates to 8 words and accepts a shorter one; it never re-asks for length.
- **Repo:** the derived `repo` from step 2 is authoritative. The model's `repo=` is kept as `repo_hint` only and used when the derived repo is `unknown`.

**Each segment carries:**
- one to three topics;
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

#### Step 1 — Daily upload on every active host

**What to build:**
- **Linux:** `bin/ai-transcript-upload`. **Windows:** `bin/ai-transcript-upload.ps1` plus the `.cmd` twin the repo requires for `bin/` scripts (the twin only calls the `.ps1` with the same arguments). Both never delete in the destination and never read file contents.
- **Copy rules (both OSes):**
  1. **Skip hot files:** skip any source file modified in the last 15 minutes; the next daily run takes it.
  2. **Copy through a temp name outside the read path:** copy to `chat_transcripts/<host>/.partial/<same relative path>`, check the copied size equals the source size, then rename into place. The writer ignores `.partial/`. If the size changed during the copy, discard and retry once; on a second mismatch, skip the file this run.
  3. **Re-copy rule:** copy when the destination is missing, or its size differs from the source, or the source mtime is newer. Size wins over mtime, so Dropbox mtime changes and clock skew cannot block a copy. On Windows, use a per-file PowerShell loop with `Copy-Item`, not robocopy `/XO`.
  4. Renamed or deleted sources are left as they are in Dropbox.
  5. Each run writes a one-line log `~/.local/state/ai-devops/transcript-upload.log` (Windows: `%LOCALAPPDATA%\ai-devops\transcript-upload.log`) with the EDT time, files scanned, copied, skipped-hot, and errors. It also writes the same line to `chat_transcripts/<host>/.upload-last.txt`, so edge-dev3 can read every host's last run.
- **Exact source → destination map** (`<D>` = `Dropbox/ai/chat_transcripts/<live hostname>`):

| Host | Runs as | Source | Destination |
|---|---|---|---|
| edge-dev3 | `ahazan` | `/home/ahazan/.claude/projects/`, `/home/ahazan/.codex/sessions/`, `/home/ahazan/.codex/archived_sessions/` | `<D>/claude/`, `<D>/codex/sessions/`, `<D>/codex/archived_sessions/` |
| hetz | `root` (reads both homes) | `/root/.claude/projects/`, `/root/.codex/sessions/`, `/home/ai/.claude/projects/`, `/home/ai/.codex/sessions/` | `<D>/root/claude/`, `<D>/root/codex/`, `<D>/ai/claude/`, `<D>/ai/codex/` |
| edge-dev | `ahazan` | `D:\ai-data\` targets of the `C:\Users\ahazan\.claude\projects` and `.codex\sessions` symlinks; resolve with `(Get-Item <link>).Target` at run time | `<D>\claude\`, `<D>\codex\` |
| 4837, 916 | `ahazan` | `%USERPROFILE%\.claude\projects\`, `%USERPROFILE%\.codex\sessions\`, `%USERPROFILE%\.codex\archived_sessions\` (resolve symlinks the same way) | `<D>\claude\`, `<D>\codex\` |

  hetz has Dropbox only if `~/Dropbox` exists for the run user. If it does not, the hetz upload instead runs from edge-dev3 as a pull: `rsync -a` over SSH into `<D>`, using the same hot-file and `.partial` rules.
- **Install:** schedule it daily: a systemd user timer like `bin/ai-install-session-tmp` on Linux, and `Register-ScheduledTask` like `bin/ai-housekeeping` on Windows (task runs as `ahazan`, only when logged on is not required).
- **Skill:** update `skills/claude/claude-transcript-backup/SKILL.md` to say it is now automatic and the skill is the manual fallback.

**Done when:**
- `tests/test-ai-transcript-upload.sh` passes. It must cover: copies new; skips identical; re-copies on a size change; skips a file modified within 15 minutes; never deletes in the destination; never leaves a file outside `.partial/` with a wrong size; follows the symlink target.
- On every active host in §2's table the scheduled task exists.
- For every active host, `chat_transcripts/<host>/.upload-last.txt` shows a run today with 0 errors, read from edge-dev3. A quiet day with 0 files copied passes; new files are not required.
- The proof is posted on #2050 with times in EDT.

**Installing on machines** is the `installation` task class. Run `ai-task-gates start --class installation` first. The observation-week freeze window file (#1948) refuses installation while it is present on a host. Merge the scripts and tests anyway, install on every unfrozen host, and leave the frozen hosts' rows open in STATUS; install there once #2041 step 4 lifts the freeze. Steps 2–8 do not wait for this: until uploads run, they use the archive as it is.

#### Step 2 — `tools/transcript_store/normalize.py`

**Input:** one `.jsonl` path.

**Output:** an ordered list of turns. Each turn is `{ts, role, text, tools: [tool names called in this turn]}`.
- Tool names come from the `tool_use` blocks' `name` (Claude) or the function-call `name` (Codex).
- Plus the session metadata `{machine, path, cwd, repo, session_id, parent_session_id, first_ts, last_ts}`.

**Repo derivation rules**, in order; the first match wins:
1. Normalize `cwd`: replace `\` with `/`, lower-case a Windows drive letter, strip a trailing `/`.
2. If it contains `/.claude/worktrees/`, `/.codex/worktrees/` or `/worktrees/`, cut from there.
3. If the remaining path has a component directly after `repos/`, `worksp/` or `src/`, that component is the repo (`C:/Users/ahazan/repos/ai-devops` → `ai-devops`; `/home/ahazan/repos/designflow-frontend` → `designflow-frontend`).
4. For the Claude project-folder form (`-home-ahazan-repos-ai-devops--claude-worktrees-x`, `-worksp-popdam--claude-worktrees-x`): cut at `--claude-worktrees`, then take the part after the last `-repos-` or `-worksp-`.
5. A home folder, `/tmp`, `/var/tmp`, a scratchpad or anything else → `unknown`. The model's `repo_hint` is then used for display, but `repo` stays `unknown`.
6. An umbrella session that works across several repos keeps its `cwd` repo for all segments; the model's per-section `repo_hint` lets "reviewer issues in DesignFlow" still match by `repo = ? OR repo_hint = ?`.

**Conversation lineage (for de-duplication):**
- `session_id` is the Claude `sessionId` field, or the Codex session id in the file's first `session_meta` line.
- A Claude fork repeats its parent's turns at the top of a new file. Two files are in the same lineage when their first 3 kept turns have the same `turn_hash` values. The lineage id is the `session_id` of the earliest file (by `first_ts`) in that group.
- `turn_hash = sha256(role + "\x00" + text)`, computed **after** redaction and the 6,000-character cap, with text whitespace-normalized (runs of whitespace → one space, trimmed).
- `turn_key = (lineage_id, turn_hash, occurrence_no)`, where `occurrence_no` counts identical hashes within that lineage, so repeated "continue" turns all survive.

**Rules:**
- Apply the redaction regex from §6.
- Skip turns under 20 characters.
- Cap each turn at 6,000 characters.
- Compute `turn_hash` and the lineage as above.

**Done when:** `tests/test_transcript_normalize.py` passes. It must cover:
- Claude and Codex fixtures. These are tiny **synthetic** `.jsonl` files written in the test, never real transcripts.
- A redaction case.
- Signature fields skipped.
- Tool names captured.
- Repo derived from each rule in the list above, including a Windows `C:\` path, a project-folder name and a non-repo `cwd` giving `unknown`.
- Two forks in one lineage share their opening; two unrelated sessions with an identical "continue" turn both keep it.
- Every redaction kind: one positive, one near-miss negative.

#### Step 3 — `tools/transcript_store/segment.py`

**What it does:**
1. Takes the turns of a lineage whose `turn_key` is not yet in `seen_turns`, in order, and groups them into chunks of at most 40 K characters, cut on turn boundaries.
   - **Stable chunk id:** `chunk_id = sha256(lineage_id + first turn_key + last turn_key)`. A chunk never changes once it is `ok`.
   - **Append:** when a file grows, only turns after the last `ok` chunk's last turn are chunked. A trailing chunk under 4 K characters whose session was modified in the last 24 h is held as `pending` and not sent, so a live conversation is not cut mid-topic each day; it is sent once the session is quiet for 24 h or grows past 40 K.
   - **Resume:** a crash leaves chunks `sending` or `failed`; the next run re-sends exactly those chunk ids with the same turn range. It never re-chunks turns that already belong to a chunk row.
   - **Rechunk** happens only with `build.py --relabel` (step 4), which builds new chunk ids under a new `prompt_version` and leaves the old rows until the swap.
2. Calls ScaleDown once per chunk, with the system prompt from step 3a.
3. Parses each `### TOPIC: <slugs> | <subject> | repo=<repo>` header and the body under it.
4. Validates every slug against §8. If any is invalid, it re-asks once with "use only these slugs: …". If still invalid, the slug becomes `other`.
5. Tool data: ScaleDown never sees tool output, so tool calls are stored per **chunk**, not per section: `chunks.tool_seq_json` is the ordered list of tool names per turn. Each segment links to its `chunk_id`. Mining reads chunks; it never attributes a chunk's counts to one section.

**Step 3a — the system prompt.** Store it as `tools/transcript_store/prompt_v1.txt`. It has three parts:
- "Remove all fluff (tool output dumps, file listings, repeated text, narration). Split what remains into topic sections."
- The exact slug list from §8 **and the topic decision rules from §8**, verbatim.
- The output format above, with the multi-topic syntax. Keep exact error strings, decisions, outcomes and dates.

**Invalid slugs:** the parser first maps known near-misses (case, `_` vs `-`, plurals, and a fixed alias table in `tools/transcript_store/aliases.json`, for example `reviewer-quality` → `reviewer-model`, `git/pr-workflow` → `ai-devops-process`, `database/shared-db` → `database`). Only a slug still invalid after aliasing is re-asked once; then `other`. The alias table is reviewed after step 5.

The prompt version is stored with every row (see risks).

**Reliability:**
- Threads: 6–8.
- Retries: 3, with backoff.
- On final failure, record the chunk as `failed` so the next run retries it. Never silently drop it.

**Done when:**
- `tests/test_transcript_segment.py` passes with a fake ScaleDown, an injected function. It must cover:
  - header parsing
  - an alias-mapped slug; an invalid slug re-asked, then mapped to `other`
  - multi-topic parsing, more than 3 slugs truncated, `other` mixed with another slug dropped
  - resume re-sends only `sending`/`failed` chunk ids; a grown file chunks only the new tail; a short live tail is held `pending`
  - a JSON-wrapped reply
  - a failed chunk recorded as failed
- One live run on a real edge-dev3 session gives sections with valid slugs. Record its numbers in `tests/verification/transcript-store/live-segment-<date>.txt` as counts and sizes only, with no content.

#### Step 4 — `tools/transcript_store/build.py` (the writer)

**Where it writes:**
- The working database is `~/.local/share/ai-devops/transcript-store/store.db` on edge-dev3. It is **never** written inside Dropbox.

**Schema:**

| Table | Columns |
|---|---|
| `sessions` | `path PK, machine, session_id, lineage_id, repo, cwd, first_ts, last_ts, mtime, size, bytes_parsed, redactions, status (new/partial/ok/failed)` |
| `chunks` | `chunk_id PK, lineage_id, path, first_turn_key, last_turn_key, chars, tool_seq_json, status (pending/sending/ok/failed), attempts, error, prompt_version, created` |
| `segments` | `id PK, chunk_id, section_no, path, topic_slugs, subject, repo, repo_hint, text, prompt_version, created`; `id = sha256(chunk_id + section_no + prompt_version)` |
| `segments_fts` | FTS5 over `subject, text` |
| `seen_turns` | `lineage_id, turn_hash, occurrence_no, chunk_id`; PK on the first three |
| `question_labels` | `question, src, prompt_version, fields_json, created` |
| `inbox_applied` | `filename PK, sha256, applied` |
| `meta` | `key PK, value` (schema version, last build time, published file name) |

**Import:** `labels.db` `review_labels(src, repo, work, mode, reviewer, verdict, value, why)` → `question_labels` with `question='review-value-2026-10-29'`, `src=src`, `prompt_version='review-value-v0'`, `fields_json` = JSON of `{repo, work, mode, reviewer, verdict, value, why}`, `created` = the import time. The test checks a row count of 6,490 and one round-tripped row.

**Shrunk or rotated file:** if a session's current `size` is less than its `bytes_parsed`, the file was rewritten. Drop that lineage's `seen_turns`, chunks and segments in one transaction and reprocess the whole lineage from byte 0.

**Writer scan excludes helper files:** anything under a `.partial/` folder, `.upload-last.txt`, any `conflicted copy` file, and any file not ending in `.jsonl`.

**Truncated last lines:** a `.jsonl` line that is not valid JSON is skipped only if it is the file's last line (an upload caught mid-write); `bytes_parsed` stops before it, so the next run re-reads from there. A bad line elsewhere is skipped and counted.

**Flow:**
1. Scan the archive.
2. For every session whose `mtime` or `size` changed: normalize, then segment the new turns, then insert.
3. Apply each file in `Dropbox/ai/transcript-store/inbox/*.jsonl` exactly once (keyed by file name and sha256).

**Inbox schema:**
- File name matches `^[a-z0-9-]{1,40}__[0-9]{8}T[0-9]{6}Z__[a-z0-9-]{1,30}\.jsonl$` (question, UTC time, host, separated by `__`). A question slug may not contain `__`, so the split is unambiguous. Anything else, including `..` or a `/`, is rejected. Files whose name contains `conflicted copy` are moved to `inbox/conflicts/`, never deleted.
- At most 5 MB and 20,000 lines per file; each line at most 8 KB.
- Each line is a JSON object with exactly these keys: `question` (string, same as the file's question part), `src` (string: a raw-archive path relative to `chat_transcripts/`, no `..`), `prompt_version` (string ≤ 40), `fields` (flat object, at most 30 keys, string/number/bool values ≤ 2,000 characters each).
- Every string value in each line is passed through the same redaction patterns as transcripts before it is stored.
- The inbox is not authenticated: only Albert's own Dropbox can write it, which is the trust boundary. A whole file is applied in one transaction or not at all.
- A bad file moves to `inbox/rejected/` with a sibling `.reason.txt`. `rejected/` and `applied/` keep 90 days, then the writer deletes files older than that **only** in those two folders.

**Publish protocol** (no temp file is ever created in a Dropbox read path):
1. `sqlite3 store.db ".backup ~/.local/share/ai-devops/transcript-store/stage/store-<UTC stamp>.db"` — local disk, outside Dropbox.
2. Run `PRAGMA integrity_check` and `PRAGMA journal_mode=DELETE` on that copy; abort on anything but `ok`.
3. Copy it into Dropbox as `Dropbox/ai/transcript-store/db/.incoming-store-<UTC stamp>.db` (a name readers never follow), compare its size and sha256 with the local copy, then rename it to its final versioned name `db/store-<UTC stamp>.db`.
4. **Last**, write the pointer `Dropbox/ai/transcript-store/CURRENT.json` = `{"file": "db/store-<stamp>.db", "sha256": …, "size": …, "built": <EDT time>, "schema": 1}`. The pointer is written to a local temp file and copied over the old pointer; it is under 1 KB.
5. Keep the newest 3 versioned files; delete older ones in `db/` only after the pointer names a newer one for at least 24 h.
6. **Conflicted copies:** if any `conflicted copy` file appears under `transcript-store/`, the writer never deletes it. It moves it to `transcript-store/conflicts/` and reports it in the run log and `--stats`.
7. **Detection instead of "never while syncing":** the writer is the only process that writes these paths, and it never edits a published file in place; each publish is a new name. No sync-state detection is needed.

**Read protocol** (step 8 implements it):
1. Read `CURRENT.json`. If it is unparsable, wait 5 s and re-read up to 3 times (Dropbox may be mid-replace). If it is still missing, unparsable or a Smart Sync placeholder (0 bytes or not readable), print "store not available locally; open Dropbox and make `ai/transcript-store` available offline" and stop.
2. Copy the named file to the local temp folder, verify size and sha256, then open the local copy with `?mode=ro`. A mismatch means Dropbox is still syncing: wait 30 s and retry once, then fall back to the newest older file in `db/` that verifies.
3. Reuse the local copy while its sha256 matches the pointer; delete it when a newer one is fetched.

**Done when:** `tests/test_transcript_build.py` passes. It must cover:
- incremental rebuild skips an unchanged file;
- a grown file is processed only for new turns;
- a truncated last line is skipped and re-read next run;
- the `labels.db` import mapping;
- an inbox file applied once; a bad, oversized, traversal or conflicted inbox file handled as above;
- publish writes a versioned file then the pointer; a conflicted copy is moved, not deleted;
- a reader given a pointer to a wrong-size file falls back to the previous version.

#### Step 5 — Smoke batch

- Run `build.py --limit-calls 1000` on the newest sessions.
- Record the wall time, calls, failures, the alias-mapped rate, the re-ask rate and the final `other` rate in `tests/verification/transcript-store/smoke-<date>.txt`, counts only. Cost is not a criterion (owner ruling, 2026-10-29).
- **Label validation gate:** draw 50 random segments. The implementing session reads only their `subject` (3–8 words) and the topic slugs, plus a ScaleDown one-line summary of the source chunk, never the chunk text, and marks each label right or wrong. It records only the counts.

**Gate (all must hold before step 6):**
- ScaleDown failure rate ≤ 5% after retries;
- re-ask rate ≤ 10% of sections (after aliasing);
- `other` ≤ 25% of sections;
- hand-check: ≥ 40 of 50 segments have a correct first slug.

If one fails, change the prompt, decision rules or alias table, bump `prompt_version`, and re-run a fresh 1,000-call batch.

**Done when:** the file exists with all four numbers passing, and a comment on #2050 states the numbers and the projection.

#### Step 6 — Full backfill

- Run `build.py` over the whole archive in the background: `systemd-run --user` or `nohup`. Expect about 15 h: about 90,000 calls at 8 threads.
- It must resume after a crash using the chunk rules in step 3.

**Done when:**
- every session is `status=ok` or has listed `failed` chunks, and the failed ones are under 1% and retried once;
- `Dropbox/ai/transcript-store/CURRENT.json` names a `db/store-<stamp>.db` file whose size and sha256 match the pointer;
- the per-topic segment counts are posted on #2050, without the `secrets` count, which stays in the private run log.

#### Step 7 — Daily timer on edge-dev3

- `bin/ai-install-transcript-store` installs `ai-transcript-store.timer`, which runs daily after the upload timers, for example at 05:30 local. It runs `build.py` and then publishes.
- The pattern is `bin/ai-install-session-tmp`.

**Done when:**
- `systemctl --user list-timers | grep ai-transcript-store` shows it;
- the next day, `CURRENT.json` names a file built today, and the run log shows 0 errors (a day with no new sessions passes).

#### Step 8 — Reader helper and skill

**The helper, `bin/ai-transcript-query`** (with a `.cmd` twin):
- Follows the read protocol in step 4: pointer, local temp copy, verify, open read-only. It never opens a file inside the Dropbox folder with SQLite.
- **Drill-down:** `--raw <segment id>` prints the raw-file path from the reader's own Dropbox archive (`chat_transcripts/<path>`) and the turn range; it does not copy raw text anywhere.
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
- `tests/test-ai-transcript-query.sh` passes against a synthetic store and pointer, including a placeholder pointer and a size mismatch;
- on a Windows machine (edge-dev), `ai-transcript-query --stats` reads the Dropbox copy.
- Stage D can start before the real store exists: it is tested against a synthetic store, and the live Windows check waits for step 6.

#### Step 9 — Mining checks

`tools/transcript_store/mine.py`, one subcommand per check, each writing a report:

**Repo set:** the `popcre` and `u2giants` repositories that appear as a segment `repo` at least 20 times, resolved with `gh repo view`; `unknown` is skipped. A repo `gh repo view` cannot find (renamed, deleted, or not Albert's) is listed in the report as unresolved and its references are not flagged as stale.

**Key phrase** of an instruction bullet: its bold lead-in if it has one; otherwise its 3 rarest words (by document frequency across all segments) that are 4+ letters long. A segment matches when it contains all of them, case-insensitive. Local checkouts under `/home/ahazan/repos/` are used for `git ls-files` and `git log` where present.

| Check | How | Threshold |
|---|---|---|
| Skill bypassing | Tokenize each `skills/**/SKILL.md` `description`; score each segment's `subject + text` by shared rare words (TF-IDF cosine, stdlib). Flag a segment when its score to a skill ≥ 0.35 and the chunk's `tool_seq_json` has no `Skill` call or that skill's name. | flag ≥ 0.35 |
| Unused or redundant instructions | For each bullet in `templates/` globals, count segments whose text matches its key phrase. Report bullets with 0 matches in 90 days, and bullet pairs with cosine ≥ 0.8. | 0 hits / 90 d; pairs ≥ 0.8 |
| Overlapping triggers | Pairwise TF-IDF cosine of skill `description` fields. | report ≥ 0.5 |
| Tool-sequence anti-patterns | Over `chunks.tool_seq_json`: the same tool 5+ times in a row; a `Read` of a path right after an `Edit`/`Write` of it; 3+ identical `Bash` polling calls. | as stated |
| Orphaned or stale references | Extract paths, `#123` refs, branches and skill names from segments in the last 30 days. Paths and skills: `git ls-files`. Issues and PRs: `gh api graphql`, batching up to 50 numbers per query. | missing = stale |
| Hallucination cross-check | Every segment (not only `ai-mistakes`) with a "merged/done/fixed/pushed" claim naming a PR, issue or commit: check it exists and is merged or closed at the segment's time. | mismatch = flag |

**`gh` rate limits:** before each batch, read `gh api rate_limit`; if under 500 remaining, sleep until reset (bounded by the reset time it returns), and cache every answer in `meta` so a re-run costs nothing. GraphQL batching keeps a full run under 2,000 points.

**Report:**
- Reports go to `Dropbox/ai/transcript-store/reports/<check>-<date>.md`, which is private.
- A counts-only summary is posted on #2050, with no excerpts, paths or secrets counts.

**Done when:**
- each subcommand has a test with synthetic data;
- each check has one real report; and
- for each check, 20 randomly drawn flags are hand-checked from their subject and the referenced object (no transcript text read), with **precision ≥ 14/20 (70%)**. A check below that has its threshold raised and is re-checked; the counts go on #2050. A check that finds fewer than 20 flags hand-checks all of them.

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
| Inbox file | Bad JSON, unknown fields, over 5 MB, a line over 8 KB, or a path with `..` in `src` | `test_build_inbox_rejects_bad_file` |
| Transcript `.jsonl` | Truncated last line from a mid-write upload | `test_build_truncated_last_line_reread` |
| Inbox filename | Path traversal (`../`) | `test_build_inbox_rejects_traversal` |
| Published file | Dropbox serves a partially-synced or placeholder file | `test_query_verifies_pointer_hash`, `test_query_placeholder_message`; publish never syncs a temp file |

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
- Follow the publish and read protocols in step 4. Never open SQLite on a file inside Dropbox.
- Never delete or prune anything in `Dropbox/ai/chat_transcripts/`. Never delete a conflicted copy anywhere.
- **Quota, backup and retention:** the raw archive is about 25 GB and grows; the store adds 3 × ~2 GB versioned files plus reports. Before step 6, check free Dropbox quota (`df` on the Dropbox folder is not enough; read the Dropbox account page or the client's status) and stop if under 15 GB free. Backup is Dropbox's own version history plus the 3 kept versions, plus the working DB on edge-dev3; recovery is "point `CURRENT.json` at an older file". Reports keep 1 year.

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
- Python 3.10 or newer, stdlib only. edge-dev3 had Python 3.14.4 with SQLite 3.46.1 on 2026-10-29.
- Use `python3`; hetz has no `python`.

**Environment check (step 0, run before stage B and again before installs).** On Windows, first run a PowerShell pre-check, `bin/ai-transcript-envcheck.ps1` (with its `.cmd` twin), which needs no Python: it reports whether `python3`/`py -3` exists and is ≥ 3.10, and whether the Dropbox folder and `chat_transcripts\` are present. If Python is missing it says so and stops; run the toolkit installer, then re-run. Then `tools/transcript_store/envcheck.py` prints, for this host: Python version ≥ 3.10, `sqlite3` with FTS5 (create a temp FTS5 table), Dropbox folder present, `chat_transcripts/` readable, and free local disk ≥ 10 GB. The writer needs all of them; Windows readers need Python, SQLite (FTS5 only for `--text`) and Dropbox. Run it on edge-dev3 and every active host; record pass/fail per host on #2050. A host without Python ≥ 3.10 gets the reader through the toolkit's existing installer, not by hand.

---

## Part 4 — Landing

### 13. Definition of done, and risks

**Done when:**
- Steps 1–9 are merged, and the CI suites are green.
- The upload task runs on every active host in §2's table.
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
| Label quality: ScaleDown topics are approximate | Relabel (built in step 4, tested in `test_transcript_build.py`): `build.py --relabel --prompt v2` re-chunks every lineage into new chunk ids under `prompt_version=v2` in a side table, then swaps them in one transaction and publishes. Old rows are deleted only after the swap. Re-run step 5's gate on v2 first. |
| Disk | The working DB is expected under 2 GB; edge-dev3 has about 1 TB free. |
| Dropbox conflicted copies | Avoided by the single writer and new-name publishing. Any conflicted copy is moved to `conflicts/` and reported, never deleted. |
| Dropbox quota | Checked before step 6 (§11). |
| A machine's upload fails silently | `--stats` shows the last session time per machine. The skill tells sessions to report a machine more than 2 days stale. |

**Rollback:** disable the timers. To undo a bad build, point `CURRENT.json` at the previous versioned file. To remove the store entirely, move `Dropbox/ai/transcript-store/` to Dropbox's trash (recoverable for its history window). The raw archive is untouched.

---

## Self-audit (2026-10-29)

1. **Could a fresh session execute this without asking anything?** Yes.
   - §2 and §12 give the hosts and paths.
   - §5 lists what exists and its exact locations.
   - §6 gives the API, the key location, the extraction rules and the regex.
   - §9 names every file, schema and done-when.
   - §8 fixes the topics.
   - Gaps found and fixed while drafting: the freeze blocking installation (step 1); the repo-name derivation rule (step 2).
   - Gaps fixed after the Muse critique (2026-10-29): lineage-scoped de-dup and stable chunk ids with append, resume and rechunk rules (steps 2–3); versioned publish plus pointer and a copy-then-open reader (step 4); hot-file skip, `.partial` copies and size re-copy (step 1); one host table (§2); redaction before ScaleDown with broader patterns, and no key item details in the public plan (§6); topic decision rules and a measured label gate (§8, step 5); B and D first when installs are frozen, and a quiet-day upload gate (STATUS, step 1); mining thresholds, repo set, rate limits and a 20-sample precision gate (step 9); labels mapping, inbox schema, repo rules, relabel, exact paths, environment check, quota and retention.
   - Fixed after the Muse re-check: redaction patterns in a code block with real `|`; step 6 gate names `CURRENT.json`; `__`-separated inbox names and inbox redaction; shrunk-file reprocessing; helper files excluded from the scan; incoming-name-then-rename publish and pointer re-read; mining key-phrase and unresolved-repo rules; a Python-free Windows pre-check.
   - Still to verify by the implementer, not assumable: the `al8960ofc` row (§2) and whether hetz has a Dropbox client (step 1 gives the pull fallback).
2. **Does it carry all the background, including what was ruled out?** Yes.
   - §3 covers the cost history.
   - §7 covers ad hoc, raw-only, live SQLite on Dropbox or SMB, Postgres, Supabase, and LLM labelling.
   - §6 covers the prototype numbers and their pitfalls.
3. **Is the goal clear enough for judgment calls?** Yes: §1 says shared, private, clean and topic-cut, why, and "goal wins".
4. **Does every step have a measurable gate?** Yes: step 1 reads each host's last-run line; step 5 has four numeric thresholds; step 9 has per-check thresholds and a 70% precision sample. Public posts carry counts only, never excerpts or the `secrets` count.
