# Review-waste inventory + read-all cost baseline (2026-10-12T16:28:01Z)

**Plan:** [`plan_jev-review-waste-mining.md`](../../../plan_jev-review-waste-mining.md) Phase 1 (Steps 1.1–1.3)  
**Host:** `edge-dev` (Windows)  
**Task class:** `private-evidence` (raw transcript reads only; this artifact is aggregates only)  
**Archive machine name only:** local Dropbox transcript archive (10 machine directories). No archive paths, no transcript text, no private identifiers.

Privacy check (spend-reduction §9.1 standard): aggregate counts, byte/token totals, dated price assumptions, public join-key *names* and cardinalities only. No excerpts, prompts, cell sizes under 5 that identify one conversation, or archive paths.

---

## 1.1 Archive inventory

### Corpus size

| Metric | Value |
|---|---|
| Total files under archive root | 17,342 |
| Total bytes | 15,346,931,859 (~15.3 GB) |
| Session transcripts (`.jsonl`) | 9,235 files / 12,999,779,139 bytes (~13.0 GB) |
| Session metadata (`.json`) | 3,355 |
| Markdown (`.md`) | 1,504 |
| Plain text (`.txt`) | 867 |
| Logs (`.log`) | 816 |
| Other / lock / junk / mixed | remainder (`.lock`, timestamped copies, media, etc.) |
| File mtime date range | 2026-04-30 → 2026-10-12 |

Machine directories (names only): `4837`, `916`, `_audit`, `al8960ofc`, `compshop`, `edge-dev`, `edge-dev3`, `hetz`, `seafile`, `t16`.

Dominant session layout (file counts of `.jsonl`): `edge-dev/codex` 2,432; `edge-dev/claude` 1,595; `al8960ofc/claude` 1,098; `al8960ofc/codex` 763; `edge-dev3/codex` 758; `edge-dev3/claude` 620; plus qwen/grok/kimi/zcode and other hosts.

### Session record shapes (structural, sampled)

Two billed-usage shapes observed in `.jsonl` sessions:

| Family | Record types (sample) | Usage path |
|---|---|---|
| Codex-style | `event_msg`, `response_item`, `token_usage_record`, `turn_context`, `session_meta` | `payload.usage.{input_tokens,output_tokens,cached_input_tokens,cache_write_input_tokens,total_tokens,reasoning_output_tokens}` on `token_usage_record` (turn/thread aggregates are cumulative — **not** summed here) |
| Claude-style | `assistant`, `user`, `system`, `attachment`, `tool_result`, `ai-title`, … | `message.usage.{input_tokens,output_tokens,cache_creation_input_tokens,cache_read_input_tokens}` on `assistant` records |

### Review-activity candidate pool (cheap structural signals)

Full-archive marker scan (first 4 MB per eligible file; ≥20 KB files scanned for markers):

| Signal | Files with hit |
|---|---|
| `ai-review` (substring) | 7,273 |
| `ai-review-packet` | 1,911 |
| `ai-review-pool` | 534 |
| `reviewer_events` / `reviewer-events` | 537 / 435 |
| PR URL shape `…/pull/<n>` | 3,032 |
| `"run_id"` key | 84 |
| `"head":"<7–40 hex>"` shape | 52 |
| **Any review structural marker** | **7,701** |

200-file unbiased sample of session `.jsonl` (20 KB–8 MB):

| Measure | Rate | Extrapolated to 9,235 sessions |
|---|---|---|
| Contains `ai-review` substring | 145/200 = 72.5% | ~6,695 files |
| Contains explicit tool-path marker (`bin/ai-review`, `ai-review-pool`, `ai-review-packet`) | 49/200 = 24.5% | ~2,263 files |
| Contains ≥1 events-log `head` SHA | 65/200 = 32.5% | ~3,001 files |
| Head-join rate among `ai-review`-marked files | 52/145 ≈ 44.8% | lower bound (full 40-hex extract) |

120-file size-weighted sample: 76.7% of files review-marked; 90% of sampled bytes sat in review-marked files (large sessions dominate bytes). Extrapolated review-marked session bytes ≈ **11.7 GB**.

Token-field presence (first 4 MB scan): `input_tokens` 7,913 files; `output_tokens` 7,893; `cache_read` 4,122; `cache_creation` 3,866; `total_tokens` 6,093.

### Exclusions required before the candidate pool (spend-reduction §9.1)

Not applied as deletions in this step — named here so Phase 3 chunking skips them: system prompts, copied policy text, tool stdout dumps, subagent copies, duplicate transcripts, non-session junk (`.lock`, timestamped robocopy remainders, media). `_audit` and `tool-results` trees are likely non-session.

### MiMo sessions

`~/.local/share/mimocode/mimocode.db` exists (~905 MB SQLite). Not included in the byte counts above. Mining follows `mimo-transcript-backup` conventions in a later step if MiMo reviewer arcs are needed; this inventory treats Dropbox JSONL as the primary corpus.

---

## 1.2 Frontier-read-all vs Jev cost estimate

**Price assumptions (stated, dated 2026-10-12; not vendor quotes):**

| Model class | Input $/1M | Output $/1M | Used for |
|---|---|---|---|
| Frontier mid (Sonnet-class list) | 3.00 | 15.00 | read-all upper |
| Frontier small (Haiku-class list) | 0.80 | 4.00 | read-all lower |
| Jev pin `jev-1.13.0` (2026-09-20 verified) | 0.042 | (negligible / typed) | filter + value label |

**Tokenization heuristic:** ~4 characters per token on English mixed transcripts. Not a billed figure.

### Candidate content volume

| Pool | Est. bytes | Est. tokens (÷4) |
|---|---|---|
| A. All session `.jsonl` | 13.0 GB | 3.25e9 |
| B. Review-marked sessions (structural) | 11.7 GB | 2.93e9 |
| C. Explicit tool-path marked (24.5% of files) | ~3.2 GB* | ~0.80e9 |
| D. Events-head joined (32.5% of files) | ~4.2 GB* | ~1.05e9 |

\*Byte share assumed proportional to file-count share for C/D (uncertainty ±30%).

### Classification cost (what this plan pays)

Two-stage pipeline: Stage 1 `Noul`/`Choice` chunk filter over candidates; Stage 2 `Score` value only on stitched interactions (orders of magnitude fewer units than chunks).

Chunking intent (Step 3): ~6 KB window, ~1 KB overlap → ~5 KB step.

| Scenario | Chunks (approx) | Jev input tokens | Jev cost @ $0.042/1M | Frontier read-all same content @ $3/1M | @ $0.80/1M |
|---|---|---|---|---|---|
| B all review-marked | 2.34e6 | 2.93e9 | **~$123** | ~$8,790 | ~$2,340 |
| D events-joined only | 0.84e6 | 1.05e9 | **~$44** | ~$3,150 | ~$840 |
| C tool-path only | 0.64e6 | 0.80e9 | **~$34** | ~$2,400 | ~$640 |

Stage 2 (value `Score` on stitched interactions) is estimated separately after Step 4.1 stitch counts; it is not a second read of the full corpus. Frontier-only-on-marked slices (plan finding 10) is the savings shape: Jev marks, frontier reads a small marked subset.

**Call-volume note (cost is dollars, not calls):** 0.6–2.3M chunk units is operationally large. Per-run caps and a **date slice** (plan §13 risk row) are required before any full-archive pass. Recommended first full pass: **events-joined pool (D)** and/or a 2–4 week date slice; widen only if interaction yield is low.

**What cannot be priced from this inventory:**

- Provider-discounted / cache-billed rates actually charged (historical usage sample below is structural field sums, not invoices).
- Jev output token price for `Score` distributions (negligible vs input, but not separately quoted here).
- Whether TypeSafe applies its own caching or batch discounts.

### Historical billed usage (sample, context only)

120-file sample of session JSONL, summed from real usage paths (Codex `payload.usage`, Claude `message.usage`):

| Field | Sample sum (120 files, 7,169 usage records) | Naive extrapolate ×(9235/120) |
|---|---|---|
| input_tokens | 124,415,329 | ~9.57e9 |
| output_tokens | 2,720,146 | ~2.09e8 |
| cache_read_input_tokens / cached_input_tokens | 848,029,150 / 120,785,024 | ~6.53e10 / ~9.30e9 |
| cache_creation_input_tokens | 41,533,957 | ~3.20e9 |
| total_tokens | 124,598,098 | ~9.59e9 |

These numbers describe **past session spend** (how expensive the work already was), not the cost of this classification. Extrapolation is linear on file count and overstates shared sessions; treat as order-of-magnitude only.

---

## 1.3 Reviewer events spine join

**Writer:** `tools/reviewer_events.py`  
**Live log:** `~/.local/state/ai-devops/reviewer-events/events.jsonl` (override `AI_REVIEW_EVENT_DIR`)

### Log shape (keys only)

Every line: `schema_version`, `event`, `provider`, `run_id`, `timestamp`, `caller`, `head`, `operation`, `parent_run_id`, `repo`.  
Also present on subsets: `exit_code` (6,392), `evidence_references` (5,290), `provenance` (5,290), `evidence_state` (5,257), `wrapper_exit_code` (5,257), `owner_pid` (718).

### Cardinality

| Metric | Value |
|---|---|
| Event lines | 13,055 |
| `event=started` / `finished` / `child-started` | 6,662 / 6,392 / 1 |
| Unique `run_id` | 6,662 |
| Unique `head` (40-hex) | 2,839 |
| Unique `repo` paths | 1,447 |
| `operation` | `invocation` 12,870; `local-finalization` 90; `local-reconciliation` 66; `async-submission` 28 |
| Timestamp range | 2026-09-07T18:19:38Z → 2026-10-12T16:12:43Z |
| Top providers | muse 3,375; grok 2,526; codex 1,980; glm 1,167; qwen 1,157; gemini 1,089; deepseek 694; claude 515; kimi 424; stepfun 128 |

### Join keys that exist

| Key | Usable for |
|---|---|
| `head` (full SHA) | Primary transcript ↔ paid-review join (appear in session tool output / PR text) |
| `run_id` | Wrapper dispatch id; **not** commonly embedded in session prose (0/150 sample hit) — use as events-side grain |
| `parent_run_id` | Pool/child structure |
| `repo` + `timestamp` | Coarse session ↔ dispatch alignment |
| `provider` | Reviewer identity for post-label segmentation (plan §8: do not run a separate Jev segmentation) |
| `caller` / `operation` / `exit_code` | Distinguishes invocation vs finalization; failed dispatches |

### How many candidates tie to at least one event

On a 200-file session sample with full 40-hex extract against all 2,839 event heads: **65/200 (32.5%)** of session files contain ≥1 event `head`. Among `ai-review`-marked files: **~44.8%**. This is a **lower bound** (some arcs mention PR numbers without the head SHA).

**Definition of “work sent to a reviewer” for this plan:** a review interaction that joins to at least one `events.jsonl` row (dispatch/start/finish) via `head` and/or `run_id`, optionally confirmed by an explicit `bin/ai-review*` tool-path marker in the same transcript region. Prose mentions of the word “review” alone do **not** count (plan finding 3).

---

## Phase 1 gate check

| Gate | Status |
|---|---|
| Step 1.1 inventory aggregate counts | ✅ this artifact |
| Step 1.2 frontier vs Jev estimates + price date + model pin | ✅ §1.2 (Jev pin `jev-1.13.0` as of 2026-09-20; re-verify `GET /v1/models` in Phase 2) |
| Step 1.3 join keys + tie rate | ✅ §1.3 |
| No transcript text / private ids / archive paths | ✅ (machine names only) |

**Next:** Phase 2 (shared Jev client — `tools/lib/jev-client.sh` still absent as of this artifact; must build advisory §9.2).
