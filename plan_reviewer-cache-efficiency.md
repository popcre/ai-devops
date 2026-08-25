# Implementation plan — reviewer cache-hit reporting (items 1 and 2 withdrawn)

**Repository:** `u2giants/ai-devops` (public)
**Authored:** 2026-08-25 by Claude (Opus 5) on machine `edge-dev`
**Rewritten:** 2026-08-25 after an adversarial audit by Grok 4.6 rejected two of
the three original items on evidence. See § 7.
**Base commit:** `722c2a4e577ccd9f0cfd99094f81c84f360b5744`
**Handoff:** [`HANDOFF.d/2026-08-25T1600Z-edge-dev-claude-reviewer-cache-efficiency.md`](HANDOFF.d/2026-08-25T1600Z-edge-dev-claude-reviewer-cache-efficiency.md)

---

## STATUS — read this first

**Two of the three items originally in this plan are WITHDRAWN. Do not
implement them.** They were rejected on evidence by an independent review after
the first draft was written, and the reasoning is preserved in § 6 and § 7
precisely so nobody re-derives them. Only Phase 4 (cache-hit token reporting)
remains, plus an optional read-only measurement spike.

| # | Step | Status | Evidence |
|---|---|---|---|
| 0.1 | Audit of all nine reviewer wrappers | ✅ done 2026-08-25 | § 6; findings re-derivable at commit `4915ada` |
| 0.2 | Grok 4.6 adversarial audit of the first draft, 2 turns | ✅ done 2026-08-25 | `.ai/reviews/grok-cache-plan-audit-20260825T133222Z-2115436.md`, `.ai/reviews/grok-cache-plan-audit-20260825T134332Z-2123838.md` — REJECT both turns; $0.246 total |
| 0.3 | Claude verified Grok's load-bearing claims against source | ✅ done 2026-08-25 | § 6, every row cites `file:line` you can re-read |
| 0.4 | Items 1 and 2 withdrawn; plan rewritten | ✅ done 2026-08-25 | This file |
| 1.1 | **Item 1 — deterministic gate snapshot paths** | ❌ **WON'T DO — disproven by measurement for Claude; mechanism plus absence of data for Codex** | § 7 R-A and [`docs/reviewer-prompt-cache-measurement-2026-08-25.md`](docs/reviewer-prompt-cache-measurement-2026-08-25.md). Claude: `cache_read_input_tokens` is 2,800 in every run regardless of directory or repetition, and the CLI's prefix drifts 1–3 tokens between identical runs. Codex: `codex exec` reports no cache split at all, so its disproof rests on the same mechanism, not on a measurement |
| 1.2 | **Item 2 — digest-gated snapshot reuse** | ❌ **WON'T DO** | § 7 R-B. The digest cannot see what a reviewer can read; the unconditional wipe is an integrity boundary |
| 2.1 | DeepSeek: capture and report cache-hit tokens | ⬜ open | — |
| 2.2 | Muse: labelled cache rows, from a real fixture | ⬜ open | — |
| 2.3 | Tests for both usage reporters | ⬜ open | — |
| 3.1 | Measurement spike (read-only, no code) | ✅ done 2026-08-25 | [`docs/reviewer-prompt-cache-measurement-2026-08-25.md`](docs/reviewer-prompt-cache-measurement-2026-08-25.md) — 6 Claude probes across 3 directories: cache reads pinned at 2,800 tokens in every one. 2 Codex probes: no cache data reported |
| 4.1 | Suite green, gate reviews APPROVE, commit and push | ⬜ open | — |

**A fresh session starts at Step 2.1.**

**Rule for this table:** ✅ requires an artifact — a path, a commit SHA, or the
exact command to re-run. Not a count, not a PR number.

---

# Part 1 — Why

## 1. The ultimate goal

**Albert should be able to look at a reviewer's report and see how much of it
was served from the provider's cache**, the way Grok's reports already show it.
Today DeepSeek and Muse both receive that number from their provider and throw
it away, so nobody can tell whether caching is working for them or what a review
actually cost.

That is the whole goal now. It is smaller than the goal in the first draft,
deliberately, because the two larger items turned out to be unsound.

**What must not happen in exchange:** nothing about review safety, read-only
boundaries, evidence integrity, or verdict trustworthiness may weaken. This item
is pure observability — it changes what gets *printed*, never what a reviewer
sees or reads.

> **If a step conflicts with this goal, the goal wins — stop and flag it.**
> Concretely: if you find yourself about to report a token number the provider
> did not actually return, or about to modify what a reviewer reads in order to
> report something, stop. `unavailable` is a correct answer. A fabricated `0` is
> not.

## 2. What this application is

`ai-devops` is Albert Hazan's personal DevOps toolkit — the machinery that lets
AI sessions work safely across his machines. It is not customer-facing.

- **GitHub:** `u2giants/ai-devops`, **public**. Never commit a secret value.
  Secrets live in the 1Password vault `vibe_coding`, referenced by item title.
- **Branch policy:** `AGENTS.md:20` — work directly on `main`, no feature
  branches. Reconcile concurrent `main` without force and confirm the commit
  reached `origin/main` (`AGENTS.md:114-115`).
- **Stack:** `bash` for `bin/ai-*`, PowerShell for Windows setup, `jq`, `git`.
  No server, no database, nothing to deploy.
- **Platforms:** Windows 11 + Git Bash (planned on `edge-dev`) and Ubuntu
  (`hetz`). Both must keep working.

### The reviewer subsystem

Claude and Codex do not review their own work unsupervised. `bin/ai-*` wrappers
hand a change to an independent model for a read-only second opinion.
`bin/ai-claude-review` and `bin/ai-codex-review` are the **approval gates** —
`bin/ai-review:9-11` refuses every other provider as *"advisory or
quarantined"*. Grok, GLM, Kimi, Qwen, Muse, DeepSeek and Gemini are advisory.

Two shared pieces of plumbing matter to this plan's history:
`bin/ai-review-sandbox` builds a disposable self-contained clone (needed because
a linked worktree's `.git` is a file pointing outside the reviewer's
single-directory boundary), and `bin/ai-review-packet` writes the facts a
shell-less reviewer cannot get itself. **Neither is changed by this plan any
more.**

**The two reviewers this plan does touch:**

- `bin/ai-deepseek-agent` — a freeform multi-turn conversation with DeepSeek.
  There is no DeepSeek CLI with session resume, so the wrapper keeps the thread
  in a local JSON transcript and **resends it as the request body every turn**.
  That file is the request, not a log. This fact governs Step 2.1.
- `bin/ai-muse` — persistent named Muse Spark reviews driven through OpenCode in
  direct mode (one `opencode run` per turn, resuming an exact session id).

## 3. What triggered this work

On 2026-08-25 Albert asked for an audit of every reviewer setup to confirm they
were being used efficiently — maximising caching and holding persistent
per-subject sessions. The audit found the subsystem broadly healthy: seven of
nine reviewers hold real named sessions with stable prompt prefixes.

It raised three candidate defects. An adversarial review by Grok 4.6, plus
independent verification of its claims, established that **two of the three were
based on incorrect mechanics** and that fixing them would have made the system
less safe. Those two are now recorded as won't-do with their evidence. The
third — discarded cache-hit numbers — is real, cheap, and safe.

**Nothing is broken today.** Nobody is blocked. This is observability work on a
system that is functioning, which is exactly why any regression would be a net
loss.

**See the remaining defect for yourself** (read-only, free):

```bash
sed -n '292,299p' bin/ai-deepseek-agent
```

The response body is parsed for `choices[0].message.content` and nothing else;
`usage.prompt_cache_hit_tokens` arrives in that same JSON and is dropped.

```bash
sed -n '277p;306p' bin/ai-muse
```

The whole `tokens` object is captured, then printed into the report as one
opaque cell.

## 4. Scope — in and out

### In scope

1. DeepSeek: capture usage from the response, print a summary to **stderr**, and
   append it to a **sidecar** file.
2. Muse: break the captured token object into labelled rows in the report, plus
   a one-line stderr summary.
3. Tests for both.
4. ~~A read-only measurement spike answering whether the gate reviewers have any
   cacheable prefix.~~ **Done 2026-08-25** — see
   [`docs/reviewer-prompt-cache-measurement-2026-08-25.md`](docs/reviewer-prompt-cache-measurement-2026-08-25.md).
   No code changed.

### Explicitly NOT in this plan

- **Deterministic snapshot paths for the gate reviewers.** Withdrawn — § 7 R-A.
- **Digest-gated snapshot reuse in `ai-review-sandbox`.** Withdrawn — § 7 R-B.
- **Any prompt reordering in either gate reviewer.** Withdrawn — § 7 R-C.
- **Moving Muse to OpenCode server mode.** Server mode failed Meta
  authorization, and a shared server was separately rejected for fault
  isolation: a broken Muse config could take GLM down.
  `docs/muse-opencode.md:3-6` and the "Why there is no Muse service" section;
  `plan_muse-opencode-harness.md:19,31-32,160`. **Locked. Do not reopen.**
- **Cache reporting for Kimi or Qwen.** Their CLIs emit no usage data at all in
  headless output; `bin/ai-kimi:888,1504` prints `unavailable` and says why.
- **Anything touching `bin/ai-gemini`.** Quarantined (`bin/ai-gemini:41`).
- **Cache reporting for GLM.** Out of the requested scope; record as a follow-up
  if it looks trivial, do not build it here.
- **`source_digest`, `source_inventory`, packet inclusion rules, reviewer tool
  boundaries, model pins, `bin/ai-review` gate policy, `ai-review-scoreboard`.**

---

# Part 2 — What we already know

## 5. Current state of the code

Everything is committed and pushed at `722c2a4`. Nothing is half-done; there is
no work in progress to pick up.

| File | Lines | Relevant today |
|---|---|---|
| `bin/ai-deepseek-agent` | 600 | Response parsing ~292-299; transcript build 311-321; review boundary check 380-387; `list` globs sessions at 478 |
| `bin/ai-muse` | 394 | Token capture at 277; report assembly at 306 |
| `tests/test-ai-deepseek-agent.sh` | 215 | curl stub at ~31 emits **no** `usage` today |
| `tests/test-ai-muse.sh` | 313 | success stub emits `tokens:{"total":3}` at ~112 |

Run the offline suite:

```bash
bash tests/test-all.sh
```

It must end `failures=0`.

**The model to copy:** `bin/ai-grok-review:858-864` (`report_usage`) prints
total, uncached-in, cache-read, turns, cost and model to stderr. Copy its
*shape* — **not** its `// 0` defaulting, which turns an absent field into a
false zero (§ 8 D4).

## 6. Key findings and root cause

### Finding A — the real, remaining defect

- **DeepSeek** (`bin/ai-deepseek-agent:292-299`): the embedded Python prints
  `data["choices"][0]["message"]["content"]` and exits. The API returns
  `usage.prompt_cache_hit_tokens` and `usage.prompt_cache_miss_tokens` in the
  same body. They are discarded. The conversation shape is ideal for
  caching — system message first, strictly append-only (`:311-321`) — so the hit
  rate ought to be high, but it has never been observed.
- **Muse** (`bin/ai-muse:277`): captures the entire `.part.tokens` object from
  the terminal `step_finish` event, then `:306` prints it as a single opaque
  cell. The cache numbers are in there, unlabelled.

### Finding B — why item 1 was withdrawn (my original mechanism was wrong)

The first draft claimed the gate reviewers' randomized snapshot path caused "the
whole repository context" to be re-billed on each of the four pipeline stages.
**That is false, and I verified it.** The user prompt sent to Claude is the
template at `bin/ai-claude-review:90-99` — **409 bytes unexpanded, and about 748
bytes (~190 tokens) once `$MODE`, `$PACKET_DIR`, `$REVIEW_DIR` and `$DECISION`
are substituted** for a representative `diff-review`. The repository never
appears in the prompt; it arrives as *tool results* from Read/Grep/Glob inside
the session. A stable directory name therefore cannot make repository context
cacheable, because repository context was never prompt prefix.

Re-derive the unexpanded figure with:

```bash
sed -n '90,99p' bin/ai-claude-review | tr -d '\r' | wc -c
```

*(An earlier revision of this plan said "326 bytes". That was measured over the
wrong line range — `:93-101` instead of `:90-99`, which picks up two later,
unrelated lines — and is corrected here. Treat both figures as approximate; line
endings shift them by a few bytes. The conclusion never depended on either: the
measurement in Finding E used a **two-token** prompt and still created 7,832
tokens of prefix, so prompt size is a rounding error regardless.)*

Two further facts kill the idea independently:

- `bin/ai-claude-review:12` passes `--no-session-persistence`, so each stage is a
  new session by design.
- The packet path in the prompt must stay unique per run (see Finding C), so the
  prefix cannot be byte-identical anyway.

Even in the best case the cacheable text is tens of tokens, below the ~1024-token
floor at which provider prefix caching typically engages.

### Finding C — why item 2 was withdrawn

The proposed reuse gate compared `source_digest` values. `source_digest` cannot
see most of what a reviewer can read:

| Readable inside the review directory | Why the digest misses it | Evidence |
|---|---|---|
| Every `.gitignore`d file | `--exclude-standard` | `bin/ai-review-sandbox:114` |
| `.ai-review*` evidence packets | explicit skip | `bin/ai-review-sandbox:120` |
| `AI-REVIEW-SANDBOX.md` | same skip | `bin/ai-review-sandbox:120` |
| The entire `.git/` — config, hooks, `info/exclude`, unreachable objects | never walked | `bin/ai-review-sandbox:110-135` |
| Untracked executable bits | hashed as content + type + size only | `bin/ai-review-sandbox:125-135` |
| Empty directories, submodule interiors | git does not list them | — |

This is not theoretical. `bin/ai-review-packet:288` runs `--tests` with
`cd "$root"` — **inside the snapshot** for gate reviewers — so test artifacts
land in exactly that digest-invisible space.

What currently contains the problem is the thing item 2 wanted to remove:
`create_or_refresh` builds into a sibling directory and then **deletes and
replaces** the old one (`bin/ai-review-sandbox:253-262`). Every turn wipes the
slate. The same digest is also what the reviewer-write detectors use
(`bin/ai-claude-review:107-108`, `bin/ai-codex-review:243`), so reuse would turn
an undetectable write into the *next* review's tree with a matching digest.

That is the definition of a reviewer approving a verdict against source it did
not read. The clone is an integrity boundary, and item 2's only benefit was
wall-clock.

### Finding E — the measurement, which closes item 1 for good

Run 2026-08-25 with the exact governed gate command; full table in
[`docs/reviewer-prompt-cache-measurement-2026-08-25.md`](docs/reviewer-prompt-cache-measurement-2026-08-25.md).

- **`cache_read_input_tokens` = 2,800 in all six Claude probes** — repository
  worktree, empty directory A, empty directory B, and immediate repeats in the
  same directory. The working directory does not move it. Repetition does not
  move it.
- **The large prefix is re-created and never read back.** Byte-identical repeat
  runs each created ~11.9k tokens (in the repo) or ~7.8k (in an empty directory)
  and still read only 2,800.
- **The prefix is not byte-stable even with everything the wrapper controls held
  fixed** — counts drift 1–3 tokens between consecutive identical runs
  (11,879 → 11,878 → 11,877), so something in the CLI's own system content
  varies per invocation. This is what makes item 1 *impossible* rather than
  merely unhelpful.
- **The repository adds ~4,045 tokens of context** over an empty directory
  (11,877 vs 7,832) — real, but cache-neutral.
- **Codex reports no cache data at all**: `codex exec` prints one
  `tokens used 17,672` total for a two-token prompt, with no hit/miss split.

**What the spike does NOT establish.** The probes used a two-token prompt and
never executed a `Read`, so they measure *cross-invocation prefix reuse* and
nothing else. They say nothing about how caching behaves inside one review's
multi-turn tool loop, where the conversation grows with every tool result. That
limit was raised by the third reviewer and is worth stating precisely — but it
does not reopen item 1, for a reason worth writing down: within a single
invocation the snapshot path is constant no matter how it was generated, so
path *determinism across runs* cannot affect intra-invocation caching. And
across invocations there is no session to resume and the CLI's own prefix drifts
anyway. Intra-invocation cost is a real question; it is simply a different one,
and no wrapper-side naming change addresses it.

**A real cost the spike did find:** each gate invocation creates ~12,000 tokens
of prefix that is never redeemed, four times per pipeline run. The only levers
are session reuse (dropping `--no-session-persistence`, which would trade away
the stage independence that makes a gate a gate) and fewer gate invocations (a
pipeline scope decision). Neither is a wrapper change and neither belongs in
this plan; both are recorded in the measurement doc.

### Finding D — the concurrency contract that item 1 also violated

`tests/test-ai-claude-review.sh:70-73` and `tests/test-ai-codex-review.sh:133-138`
require two concurrent same-repo gate reviews to **both complete** with distinct
reports. The first draft simultaneously forbade weakening existing tests and
required a new test asserting concurrent reviews refuse. Those cannot both hold.

Sharing one snapshot directory across runs also breaks the packet contract:
`bin/ai-review-packet:243-257` deletes and rebuilds a same-tag packet — the hard
refusal only fires when the recorded owner tag *differs*. Two concurrent runs
sharing a tag would swap each other's evidence mid-review, which is the
shared-db#1296 incident that packet naming exists to prevent, on an approval
gate.

## 7. Approaches considered and REJECTED

| # | Approach | Why rejected |
|---|---|---|
| **R-A** | **Deterministic snapshot paths for the gate reviewers** | The premise was wrong (Finding B): ~748-byte rendered prompt, repository arrives as tool results, `--no-session-persistence` on, packet path must stay unique. **Now measured and disproven for Claude** (Finding E): cache reads are fixed at 2,800 tokens in every directory and on every repeat, and the CLI's prefix is not byte-stable between runs, so no wrapper-side change can produce a matching prefix. |
| **R-B** | **Digest-gated snapshot reuse** | The digest cannot see ignored files, packets, `.git`, exec bits, empty dirs, or submodule interiors (Finding C). The unconditional wipe is an integrity boundary. Benefit was wall-clock only. **And for the gate reviewers there is normally nothing to reuse at all:** each run gets a unique `TAG` (`bin/ai-claude-review:61`) and `trap cleanup EXIT` removes the snapshot when the run ends (`:64-67`). Reuse would therefore require inventing a snapshot *retention* lifecycle first — with its own staleness, accumulation, and shared-directory problems, the last of which Finding D shows is already forbidden. |
| **R-C** | **Reordering the gate prompts so invariant text leads** | Fights both verdict parsers in opposite directions: Codex requires the verdict to be the **final two non-empty lines** with exactly one heading (`bin/ai-codex-review:245-247`); Claude takes the **first** heading (`bin/ai-claude-review:109`). It would also move the READ-ONLY instruction off the front for a cache benefit Finding B shows does not exist. |
| **R-D** | **In-place refresh instead of reuse** (`git clean -fdx`, re-checkout, re-apply) | `git clean` never walks `.git/`, so config, hooks, `info/exclude` drift and unreachable objects survive; a single `-f` refuses to delete a nested repo, so submodule leftovers survive. Worse, it **mutates the published directory**: a mid-refresh failure leaves a half-wiped tree at the exact path the next turn will use, which is the mixed-evidence failure the sibling-build-then-`mv` publish was written to make impossible. On Windows it also invites EBUSY. Making it truly equivalent means re-cloning, which saves nothing. |
| **R-E** | **A content-addressed immutable snapshot directory** | Not a one-line change: you must never delete it while a review may be running and never write into it, but Codex `--tests` writes into `$root`. Still machinery, still unmeasured. |
| **R-F** | **Sharing one snapshot with a refcount or shared-read lock** | Adding a locking scheme to an approval gate to chase an unmeasured cache benefit is the wrong trade. Per-run directories are already lock-free and correct. |
| **R-G** | **Muse on the GLM OpenCode server** | Server mode failed Meta authorization; a shared server was rejected for fault isolation. `docs/muse-opencode.md:3-6`, `plan_muse-opencode-harness.md:19,160`. **Locked.** |
| **R-H** | **Adding usage fields to the DeepSeek transcript JSON** | The transcript **is the request body**, replayed verbatim as `messages` (`bin/ai-deepseek-agent:267-268`). New fields would change the cached prefix we are trying to measure and break the review-boundary assertion that `messages[0]` is exactly the boundary system prompt (`:380-387`). Usage goes in a sidecar. |
| **R-I** | **Printing DeepSeek usage on stdout** | stdout is a contract: callers consume the reply, and `send` already prints `SESSION_ID:` there. stderr, matching `bin/ai-grok-review:858`. |
| **R-J** | **Naming the sidecar `*.usage.json`** | `bin/ai-deepseek-agent:478` globs `*.json` (minus `*.meta.json`) to list sessions, so a `.usage.json` file would be listed as a session. Use `.usage.jsonl`. |
| **R-K** | **Reporting `0` for an absent field** | Zero is a claim; absent is a different fact. `bin/ai-kimi:888,1504` sets the convention: `unavailable`. Do not copy Grok's `// 0` at `bin/ai-grok-review:861`. |

## 8. Design decisions

### D1 — Items 1 and 2 are withdrawn, not deferred. **LOCKED.**
*(2026-08-25, after three adversarial review turns and independent verification)*
Do not resurrect either from the first draft.

**Item 1 and item 2 died of different causes, so they have different reopening
bars. Do not let evidence for one revive the other.**

- **Item 1 (caching) was a wrong mechanism, and the measurement has now been
  taken.** Step 3.1 ran on 2026-08-25 and the answer was no. **For Claude that
  is a direct disproof:** cache reads are fixed at 2,800 tokens regardless of
  working directory or repetition, and the CLI's own prefix drifts between
  identical runs. **For Codex it is mechanism plus absence of data** — `codex
  exec` reports no cache split at all, so no Codex number was ever observed.
  Reopening therefore requires a **change in CLI or provider behaviour** — a new
  measurement showing reads that move with something the wrapper controls, and
  for Codex a CLI that reports cache figures at all — not a new argument. Even then,
  Findings C and D independently forbid sharing a snapshot directory or a packet
  tag, so a favourable measurement would license a prompt change at most.
- **Item 2 (snapshot reuse) was never a caching idea at all.** It was
  wall-clock only, and it failed on evidence integrity. Reopening it requires a
  Read-complete identity — one covering everything under the snapshot a reviewer
  can read, including ignored files, packets and `.git` — **or** a publish path
  that keeps the all-or-nothing wipe. A traced request is irrelevant to it.

If either bar is met, that is a **new plan** with its own review, not a
resurrection of this one.

### D2 — DeepSeek usage goes to stderr and a sidecar; stdout and the transcript are untouched. **LOCKED.**
*(2026-08-25)* See R-H, R-I, R-J.

### D3 — Muse field names come from a real `step_finish`, never a guess. **LOCKED — and the fixture now exists.**
*(2026-08-25)* The existing test stub emits only `{"total":3}`, so an offline
test cannot catch a wrong `jq` path against production field names. **Keep the
raw object in the report** so nothing is lost if a field is renamed upstream.

**Observed shape**, captured from a real Muse Spark 1.2 Contributor turn on
2026-08-25 (session `reviewer-cache-plan-audit`, message
`msg_0397b54cb001IM3ZlOAz7JdTzU`), read from the `step_finish` event in
`ai-muse transcript`:

```json
{"total":107025,"input":21643,"output":6424,"reasoning":5373,
 "cache":{"write":0,"read":73585}}
```

So the paths are `.total`, `.input`, `.output`, `.reasoning`, `.cache.read`
and `.cache.write` — note **cache figures are nested one level under
`.cache`**, not flat. `.reasoning` has no equivalent in the DeepSeek shape and
should get its own row.

This is one observation from one provider version. It is what D3 asked for and
it unblocks Step 2.2, but it is not a contract: keep the raw object row, keep
the type guard, and re-check the shape if the report ever prints `unavailable`
across the board.

### D4 — Absent means `unavailable`, never `0`. **LOCKED.** *(2026-08-25)* See R-K.

### D5 — The measurement spike is done. **CLOSED 2026-08-25.**
*(Was "optional and open" until the spike ran the same day.)* Step 3.1 settled
the caching question with evidence instead of taste, changed no code, and
produced [`docs/reviewer-prompt-cache-measurement-2026-08-25.md`](docs/reviewer-prompt-cache-measurement-2026-08-25.md).
Nothing here needs re-running unless the Claude or Codex CLI changes its prefix
behaviour.

---

# Part 3 — How to build it

## 9. The plan

### Phase 2 — Cache-hit reporting (the whole of the work)

#### Step 2.1 — DeepSeek

**File:** `bin/ai-deepseek-agent`, the response-parsing block at ~292-299 and its
callers (~260-296, 518-520, 574).

**What to change:**

- In the embedded Python that reads the response (`bin/ai-deepseek-agent:292-296`),
  also read the `usage` object and take `prompt_cache_hit_tokens`,
  `prompt_cache_miss_tokens`, `prompt_tokens`, `completion_tokens`,
  `total_tokens`. **The body is deleted at `:298`** (`rm -f` of the request,
  response and status files), so extract before that line. The failure paths at
  `:281-282` and `:288-289` delete the body with no parse — correct, there is no
  usage to report.
- **Do not write the sidecar inside `call_api`.** `call_api` has no session id,
  and `doctor --live` calls it at `:472` while session setup is skipped for
  `doctor` at `:158`. A write there would either break the existing
  `live doctor leaves the repository byte state unchanged` test
  (`tests/test-ai-deepseek-agent.sh:54`) or drop a stray file in the working
  directory. **Return** the usage from `call_api` — a second output file is the
  simplest route — and append the sidecar only in `send` (`:520`) and `reply`
  (`:574`).
- **Append the sidecar while the transcript lock is still held** — before
  `release_lock` at `:544` and `:597` — so two concurrent replies cannot
  interleave partial JSONL lines. Concurrent replies already serialize
  (`tests/test-ai-deepseek-agent.sh:75-77`).
- **A sidecar write failure must not fail the turn.** If the transcript has
  already published, the turn succeeded; usage is observability. Warn on stderr
  and carry on. This is explicitly *not* the attachment-ledger
  `recovery-required` path at `:533-537`.
- Use the wrapper's own `session_path` helper with a `.usage.jsonl` suffix so
  the existing symlink and path-escape checks apply.
- **Clean up the extra temp file on every path.** If `call_api` returns usage in
  a second file, `doctor --live` at `:472` must delete it too — it currently
  removes only its message and reply files — and the new path must be covered by
  `ACTIVE_API_TMP` (`:264`) so the interrupt handler's `rm -f` at `:226` catches
  it. Otherwise every doctor run and every interrupted turn leaks one temp file.
- **The sidecar is observability, not a completion record.** Do not give it
  attachment-ledger semantics: nothing may later treat a present or absent
  sidecar line as evidence that a turn did or did not publish
  (`bin/ai-deepseek-agent:533-537` is the ledger path; the sidecar is not it).
- The reply file and stdout stay **byte-identical** to today.
- Print one line to **stderr**, in the shape of `bin/ai-grok-review:858`:
  `tokens: <total> (cache hit: <n>, miss: <n>) model: <model>`. Any field the
  provider omitted prints `unavailable` (D4).
- Append the usage object as one JSON line to a sidecar beside the transcript,
  named `<session>.usage.jsonl` — **not** `.usage.json` (R-J).
- Do not touch the transcript JSON (R-H).

**Behaviour when done:** a `send` or `reply` prints exactly what it printed
before on stdout, plus a usage line on stderr, and grows a sidecar by one line.

**Verification gate:** `bash tests/test-ai-deepseek-agent.sh` passes including
the new cases below, and `ai-deepseek-agent list` still lists exactly the
sessions it listed before the change.

#### Step 2.2 — Muse

**File:** `bin/ai-muse:277` (capture, already correct) and `:306` (report).

**What to change:**

- **The fixture already exists — do not re-prove it.** D3 records a real
  OpenCode `step_finish` token object captured on 2026-08-25, with its
  provenance. Use those paths. Re-capture only if the provider or OpenCode
  version changes, or if the report starts printing `unavailable` across the
  board.
- Replace the single opaque `| tokens | {...} |` row with labelled rows:
  **input, output, reasoning, cache read, cache write, total** — six rows, from
  the shape D3 recorded. `reasoning` is easy to miss because DeepSeek has no
  equivalent; it is present in real Muse output and must get its own row.
  Omitted fields print `unavailable`.
- Keep the raw object as an additional row.
- Print a one-line stderr summary per turn, same shape as DeepSeek's, matching
  the existing session lines already written to stderr at `bin/ai-muse:326`.
- `TOKENS` is initialised at `:235`, captured at `:277` and consumed **only** at
  `:306`. Leave `preserve_failure` (`:284-288`) alone — it omits provider bodies
  on purpose. Adding rows to the same staged-descriptor write is safe with the
  exclusive `set -C` staging, which is reserved before the provider runs
  (`:177-179`, `:318`, `:335`); more bytes on a held descriptor change no
  destination check.
- Guard every `jq` read defensively — including reads inside string
  interpolations, `"…\(.input)…"`, which fail exactly the same way.
  `bin/ai-muse:3` **does** use `set -e`, so a failed command substitution in the
  report path would abort *after* the provider already answered. Missing fields
  must yield `unavailable`, never a failed command.
- **Use the optional-access operator, `.field? // "unavailable"`, or a
  type-guarded read.** An earlier revision of this plan claimed `TOKENS` is only
  ever an object or `null` because the capture at `bin/ai-muse:277` ends in
  `//null`. **That is wrong.** jq's `//` falls through only on `null` and
  `false`, so `TOKENS` is `null` *or the compact encoding of whatever
  `.part.tokens` actually held* (any value except `false`, which the capture's
  own `//empty` collapses to `null`) — an object in every case observed so far, but
  nothing constrains it. The upstream validation at `:271-274` checks that each
  NDJSON line is an object with one session id; it says nothing about the type
  of `.part.tokens`.

  This matters because the naive form fails exactly where the guard is needed.
  Verified at the shell:

  ```bash
  echo '5' | jq -r '.input // "unavailable"'
  ```

  errors with `Cannot index number with string ("input")` and exits non-zero,
  which under `set -e` aborts the report *after* Muse has already answered.
  `echo '5' | jq -r '.input? // "unavailable"'` prints `unavailable`. A single
  type-guarded expression is better still:
  `if type=="object" then (.input? // "unavailable") else "unavailable" end`.
- **For the nested cache fields, the `?` must go on the FIRST index, not only
  the last.** `.cache.read?` is not safe; `.cache?.read?` is. Measured at the
  shell against every value `TOKENS` can take:

  | `TOKENS` | `.cache.read? // "unavailable"` | `.cache?.read? // "unavailable"` |
  |---|---|---|
  | `{"cache":{"read":7}}` | `7` | `7` |
  | `{}` | `unavailable` | `unavailable` |
  | `{"cache":5}` | `unavailable` | `unavailable` |
  | `{"cache":null}` | `unavailable` | `unavailable` |
  | `null` | `unavailable` | `unavailable` |
  | `5` | **error, exit 5** | `unavailable` |
  | `"str"` | **error, exit 5** | `unavailable` |
  | `[1,2]` | **error, exit 5** | `unavailable` |

  Note *why*, because the obvious reason is the wrong one: a **missing**
  `.cache` is harmless — indexing `null` yields `null` in jq. The failure is
  when `TOKENS` **itself** is a scalar, string, or array, which is exactly the
  case this guard exists for. A trailing `?` cannot rescue an index that already
  threw. Use `.cache?.read?` / `.cache?.write?`, or the type-guarded form.
- **Do not rename the existing `reviewed commit` or `evidence fingerprint` report
  labels.** `tests/test-ai-muse.sh:254` greps for those exact strings. Add the
  new rows; leave the existing ones alone.

**Verification gate:** `bash tests/test-ai-muse.sh` passes including the new
cases; a published report shows labelled rows.

#### Step 2.3 — Tests

`tests/test-ai-deepseek-agent.sh` — note the curl stub currently emits **no**
`usage`, so `missing_usage_reports_unavailable` is the default path and the
stub must be *extended* for the positive case:

| Test | Asserts |
|---|---|
| `usage_line_written_to_stderr` | Summary appears on stderr when the stub returns `usage` |
| `stdout_reply_unchanged` | stdout unchanged for a fixed stub. **Assert on `reply`, or mask the `SESSION_ID:` line** — `send`'s stdout embeds a date/pid/random id (`new_id` at `bin/ai-deepseek-agent:180`, collision loop at `:515-516`), so literal byte-identity is impossible there. `tests/test-ai-deepseek-agent.sh:58` already shows the masking idiom |
| `transcript_json_shape_unchanged` | No new keys; `messages[0]` is still exactly the boundary |
| `usage_sidecar_appends_per_turn` | Two turns → two sidecar lines |
| `usage_sidecar_not_listed_as_session` | `list` output is unchanged with a sidecar present (guards R-J) |
| `missing_usage_reports_unavailable` | No `usage` in the response → `unavailable`, never `0`, turn still succeeds |
| `doctor_live_creates_no_sidecar` | `doctor --live` writes no sidecar and no session directory (guards the `call_api` split) |
| `doctor_live_leaves_no_temp_files` | `doctor --live` leaves no stray temp file behind (guards the extra-file cleanup in Step 2.1) |
| `sidecar_write_failure_does_not_fail_the_turn` | An unwritable sidecar path warns but the turn still succeeds. **Inject the failure by pre-creating a _directory_ at the sidecar path** (`session_path` rejects symlinks but not directories), not with `chmod` — `chmod` is unreliable on Git Bash/Windows, which is the machine in § 12. **Target `reply` on an existing session**: `send`'s id is unpredictable (`bin/ai-deepseek-agent:180`, `:515-516`), so there is no path to pre-create |
| `stderr_usage_is_not_on_stdout` | The usage line is absent from a stdout capture (extends the existing `SESSION_ID` capture at `tests/test-ai-deepseek-agent.sh:58`) |
| `usage_sidecar_appends_under_lock` | Two concurrent replies produce two well-formed JSONL lines (extends `tests/test-ai-deepseek-agent.sh:75-77`) |

`tests/test-ai-muse.sh` — the success stub emits only `tokens:{"total":3}`, so a
richer fixture is needed:

| Test | Asserts |
|---|---|
| `report_breaks_out_cache_tokens` | Labelled rows present with a rich fixture |
| `missing_token_fields_report_unavailable` | Sparse fixture → `unavailable`, report still publishes |
| `raw_token_object_retained` | Raw object still in the report |
| `stderr_usage_line_on_new_and_ask` | Both `new` and `ask` print the summary |
| `null_tokens_object_still_publishes` | A `step_finish` with no `tokens` (so `TOKENS` stays `null`, `bin/ai-muse:235`) still publishes a report |
| `scalar_tokens_value_still_publishes` | A `step_finish` carrying `"tokens":5` — a scalar, not an object — still publishes, with `unavailable` rows. This is the case the naive `// "unavailable"` form fails |

**Known limit, state it in the commit message:** these are offline stub tests.
They cannot prove the `jq` paths match production field names — only D3's real
fixture can. Do not claim otherwise.

**Verification gate:** `bash tests/test-all.sh` ends `failures=0`.

---

### Phase 3 — Measurement spike — ✅ DONE 2026-08-25, no code changed

#### Step 3.1 — complete

Ran the exact governed gate command with a trivial prompt, six times for Claude
across three working directories and twice for Codex, and read the CLI's own
reported usage. Result and full table:
[`docs/reviewer-prompt-cache-measurement-2026-08-25.md`](docs/reviewer-prompt-cache-measurement-2026-08-25.md).

The answer closed item 1 permanently (Finding E) and updated D1's reopening bar.
**Nothing here needs re-running** unless the Claude or Codex CLI changes its
prefix behaviour.

---

### Phase 4 — Land it

#### Step 4.1

```bash
bash tests/test-all.sh
```

Then the gates:

```bash
ai-review claude diff-review
```
```bash
ai-review codex diff-review
```

Both must return `APPROVE`.

**Then the independent exact-head review that `AGENTS.md:39-42` requires.** That
rule says changes to *reviewer wrappers* need one read-only exact-head final
review before merge — and Phase 2 changes two of them, `bin/ai-deepseek-agent`
and `bin/ai-muse`. The docs-only commits in this workstream did not trigger it
("ordinary plans, analysis notes, and documentation-router wording do not"), but
the implementation does:

```bash
ai-review claude final-check
```

Then update `docs/muse-opencode.md` (note the new cache reporting; reaffirm
direct mode is deliberate and unchanged), update this plan's STATUS with
artifacts, close the handoff, load `session-docs-update`, and commit on `main`
per `AGENTS.md:20`. One commit; this is one coherent change.

## 10. Tests required

Every test named in Step 2.3. Plus: **the entire existing suite stays green.**
No test may be deleted, skipped, or relaxed. If an existing test fails, that is
a finding about your change.

Note especially that `tests/test-ai-review-sandbox.sh:250` asserts
`ai-codex-review` still contains `remove-copy`. The withdrawn item 1 would have
broken it. Nothing in the remaining work touches it — if it goes red, you have
strayed out of scope.

## 11. Constraints, standing rules, and gotchas

**Process**

- Work directly on `main` (`AGENTS.md:20`).
- Run `git var GIT_COMMITTER_IDENT` before your first commit; it must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- This checkout may be shared. **Stage only your own files** — never `git add -A`.
- Public repository. No secret values, ever.

**Traps specific to this work**

- **The DeepSeek transcript is the request body.** Never add fields to it.
- **The sidecar must not be `*.json`** or `list` will treat it as a session
  (`bin/ai-deepseek-agent:478`).
- **stdout is a contract** for both wrappers. Usage goes to stderr only.
- **Field names fail silently** in this ecosystem — the Kimi agent-file incident
  is the canonical case (`config/kimi/readonly-review.md`). Verify Muse's token
  field names against real output.
- **The two files differ on `set -e`.** `bin/ai-deepseek-agent:36` is
  `set -uo pipefail` — no `-e`; `bin/ai-muse:3` is `set -euo pipefail`. So a
  failing command substitution aborts Muse and does not abort DeepSeek. Write
  defensively for both (`bin/ai-glm:52-55` records this class of bug costing
  every Windows run).
- **Do not simplify a measured guardrail without reading its reason**
  (`AGENTS.md:52`). These files are dense with comments recording incidents that
  cost real money.
- **GPT-5.6 runs at `low` or `medium` reasoning only.**
- **Never redirect output into the repository while a reviewer turn is running.**
  `ai-muse` snapshots the tree before and after each turn and rejects the
  response if the source moved — and an untracked file is a move. This cost a
  full Muse turn on 2026-08-25: a `2>muse1.err` redirect in the repository root
  made the wrapper reject an otherwise complete review. Send scratch output to
  the session scratchpad instead. The turn is recoverable — the answer is in
  `ai-muse transcript`, and `ai-muse reconcile <name>` returns the session to
  `active` — but the report is not published.

## 12. Access and environment

- **Machine:** `edge-dev` (Windows 11). **Git Bash** for the Bash tools and
  suites.
- **Repository:** `C:\repos\ai-devops`.
- **Commands needed:** `git`, `jq`, `bash`, `sha256sum`, `curl`, `python`.
- **Reviewer health:** `ai-review doctor` (both gates),
  `ai-deepseek-agent doctor`, `AI_MUSE_CALLER=claude ai-muse doctor`.
- **Secrets — location only, never value.** 1Password vault `vibe_coding`:
  Muse's key is item *"Meta ai Muse Spark API Key"*, field *api key*; DeepSeek's
  resolves through `~/.config/ai-devops/mcp.env` and the service-account token,
  handled by the wrapper. Serialize 1Password access; load
  `secrets-to-1password` before any write; move values only through pipes or
  0600 files.
- **Nothing to deploy.** "Verify" means: run the suite, and run one real review.

---

# Part 4 — Landing it

## 13. Definition of done, risks, open questions

### Definition of done

- [ ] DeepSeek and Muse both report cache-hit tokens; absent fields say
      `unavailable`.
- [ ] Every test in Step 2.3 exists and passes; `bash tests/test-all.sh` ends
      `failures=0`; no existing test weakened.
- [ ] Muse's `jq` paths were written against a **real** `step_finish`, and the
      fixture or a note naming it is recorded in the commit.
- [ ] A real DeepSeek turn and a real Muse turn each show the stderr line and a
      populated report — pasted into the closing report as proof.
- [ ] Both gate reviews return APPROVE, **and** the `AGENTS.md:39-42`
      independent exact-head final review has run against the implementation.
- [ ] `docs/muse-opencode.md` updated; STATUS updated with artifacts; handoff
      closed.
- [ ] Committed on `main`, pushed, confirmed on `origin/main`.

### Risks and rollback

| Risk | Severity | Mitigation | Rollback |
|---|---|---|---|
| Muse `jq` paths wrong → `unavailable` everywhere, or a wrong number | Medium | D3 real fixture; raw object retained so nothing is lost | Revert the commit |
| DeepSeek change alters stdout and breaks a caller | Medium | `stdout_reply_unchanged` test | Revert the commit |
| Sidecar pollutes `list` | Low | `.usage.jsonl` naming plus `usage_sidecar_not_listed_as_session` | Delete sidecars; revert |
| A future session resurrects withdrawn items 1 or 2 from the first draft | **Medium and real** | § 7 R-A/R-B/R-C/R-D with evidence; D1 requires a traced request before reopening; the STATUS table marks them ❌ | — |

Overall risk is low: this change alters what is printed, never what a reviewer
reads.

One path deserves naming. DeepSeek's `--review` mode parses `## Verdict` out of
the **reply file** (`bin/ai-deepseek-agent:325-332`, used at `:523` and `:577`).
If a botched extract ever wrote usage into that file, the parse would fail
closed — or, if the text contained a heading, pick the wrong word. That is a
broken extract rather than stale code, and the byte-identical reply-file
requirement plus `stdout_reply_unchanged` and `transcript_json_shape_unchanged`
close it. Muse's next turn resumes an OpenCode session id, not the markdown
report, so labelled rows cannot change what Muse reads. **Do not feed usage into
`write_review_metadata` (`bin/ai-deepseek-agent:391-414`)** — that JSON is
evidence about HEAD, not tokens.

### Open questions

1. ~~Muse's exact token field names.~~ **Settled 2026-08-25** — captured from a
   real turn and recorded in D3: `.total`, `.input`, `.output`, `.reasoning`,
   and `.cache.read` / `.cache.write` nested under `.cache`. Still write the
   type guard and keep the raw object row; one observation is not a contract.
2. **Whether GLM should get the same reporting.** Out of scope by instruction.
   Record as a follow-up if trivial.
3. ~~Whether the gate reviewers have any cacheable prefix at all.~~
   **Settled 2026-08-25.** They do not have one the wrapper can influence — see
   Finding E and the measurement doc. What remains genuinely open is whether the
   ~12k-token unredeemed prefix per gate invocation is worth attacking through
   session reuse or fewer invocations. Both trade something real (stage
   independence, or review coverage) and both are out of scope here.

4. **Should the governed Codex command pin an empty MCP configuration?** The
   spike incidentally showed `codex exec` loading ambient MCP servers, where
   Claude's governed command pins `--strict-mcp-config` with no servers
   (`bin/ai-claude-review:12`). That is a safety question, not a caching one,
   and it is out of scope for this plan — but it should not be lost. Raised with
   Albert 2026-08-25.

---

## Review record

| Turn | Reviewer | Verdict | Cost | Artifact |
|---|---|---|---|---|
| 1 | Grok 4.6 (`grok-4.6-build`) | REJECT | $0.1784 | `.ai/reviews/grok-cache-plan-audit-20260825T133222Z-2115436.md` |
| 2 | Grok 4.6 | REJECT first draft; recommends Phase 4 only | $0.0679 | `.ai/reviews/grok-cache-plan-audit-20260825T134332Z-2123838.md` |
| 3 | Grok 4.6 — review of this rewrite | **APPROVE**; no material objection, four spec nits | $0.1927 | `.ai/reviews/grok-cache-plan-audit-20260825T135220Z-4523.md` |

| 4 | GLM 5.3 — independent audit of the plan and the measurement | **APPROVE**; six defects found in the Phase 2 spec | not reported by provider | `.ai/reviews/glm-reviewer-cache-plan-audit-20260825T143401Z.md` |
| 5 | GLM 5.3 — review of the fixes | **APPROVE**; one must-fix (the `TOKENS` type guarantee) plus four mis-cites introduced by the fix pass | not reported by provider | `.ai/reviews/glm-reviewer-cache-plan-audit-20260825T144141Z.md` |
| 6 | GLM 5.3 — closing turn | **APPROVE**, no material objection remaining; two optional nits, both taken | not reported by provider | `.ai/reviews/glm-reviewer-cache-plan-audit-20260825T144623Z.md` |
| 7 | Muse Spark 1.2 Contributor — third independent audit | **APPROVE** with three carry items | 107,025 tokens, 73,585 from cache | `ai-muse transcript reviewer-cache-plan-audit` (report unpublished — see below) |

Sessions: `ai-grok-review show cache-plan-audit`, `ai-glm show
reviewer-cache-plan-audit`.

Every figure here is provider-returned, per this plan's own rule. Grok's costs
and token counts come from the usage line `ai-grok-review` prints on stderr
(`tokens: … cached: … cost: $…`): **$0.439** over three turns, and turn 3 read
1,414,014 tokens of which 1,165,696 were cached. GLM reports no cost at all; its
per-turn footer carries `tokens.cache.read`, which was 100,480 on turn 1 and
103,808 on turn 2.

GLM independently tried to argue both withdrawals back and could not, which is
the useful part: two models with different evidence reached the same conclusion.
It also caught two errors that had survived Grok's three turns and my own
checking — the "326 bytes" prompt figure, measured over the wrong line range,
and a false claim about jq's `//` operator that would have told an implementer a
defensive guard was unnecessary in exactly the case that needs it.

Muse's turn was rejected by its own wrapper's source-changed guard, because a
stray `.err` redirect appeared in the repository root while it was running. The
review itself completed and is in the transcript; the session was reconciled
back to `active`. Its most useful contributions were the limit-of-evidence note
on the measurement (now in the measurement doc) and — from the token block of
its own `step_finish` event — the real Muse field shape that D3 had been waiting
for.

**A process lesson, recorded because it recurred:** every wrong citation in this
plan came from prose written from a previous reviewer's line numbers without
re-deriving them. Four more were introduced while *fixing* the first batch.
Re-grep every `file:line` you write before committing it — this repository's
whole review method depends on those citations being re-derivable.

All four of turn 3's nits were verified against the source and applied: the
prompt line range (`:90-99`, not `:93-101`), the `call_api` versus `send`/`reply`
split for the sidecar write, sidecar-failure semantics, and the `set -e`
difference between the two files.

Grok's conclusions are labelled as Grok's. Claude independently verified every
load-bearing citation against the source before accepting it; the verification
is what § 6 records, with `file:line` refs a reader can re-derive.

---

## Self-audit (required by `implementation-plan-writer`; preserved here)

**1. Could a brand-new session execute this without asking anything?**

Yes. § 2 explains the repository, its branch rule, and specifically what the two
wrappers being changed *are* — including the fact that DeepSeek's transcript is
the request body, which is the single most dangerous thing to get wrong here.
§ 3 gives two read-only commands that show the defect. § 5 names files and line
numbers and warns that both test stubs need extending. § 9 gives per-step target
files, behaviour, and verification gates. The one genuine unknown — Muse's field
names — is flagged three times (D3, Step 2.2, open question 1) with an explicit
"do not guess".

**2. Does the plan carry every piece of background and reasoning, including what
was ruled out and why?**

Yes, and this is now the plan's main value. § 7 records eleven rejected
approaches. Four of them (R-A through R-D) are the plan's own withdrawn items,
each with the evidence that killed it, so the next session cannot re-derive a
design that two review turns and independent verification already refuted. § 6
Findings B, C, D and E record the *mechanics* — the ~748-byte prompt, the six
categories of readable-but-undigested state, the concurrency tests — rather than
just the conclusions, so a future session can tell whether changed circumstances
would change the answer.

**3. Is the goal clear enough to steer by if a step is wrong?**

Yes. § 1 states the goal in one sentence, names what may not be traded for it,
and gives the concrete tie-break: `unavailable` is a correct answer, a
fabricated `0` is not. The scope is now small enough that the risk of a step
being wrong is mostly confined to one `jq` path, which D3 addresses directly.

**Gaps found and fixed in this rewrite:** the first draft failed audit question 2
badly — it asserted a caching mechanism (repository context as prompt prefix)
that the source contradicts, locked three decisions before the review that was
supposed to test them, and specified a test that contradicted an existing test.
All three are fixed: the mechanism is corrected in Finding B, nothing is locked
that has not survived review, and the contradicting test is gone with its item.

All comprehensiveness-checklist items pass.
