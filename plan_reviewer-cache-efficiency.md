# Implementation plan — reviewer cache and snapshot efficiency

**Repository:** `u2giants/ai-devops` (public)
**Authored:** 2026-08-25 by Claude (Opus 5) on machine `edge-dev`
**Authored from commit:** `4915adac90f7867b4475a3d146920f5e3480b0a4`
**Handoff for this plan:** [`HANDOFF.d/2026-08-25T1600Z-edge-dev-claude-reviewer-cache-efficiency.md`](HANDOFF.d/2026-08-25T1600Z-edge-dev-claude-reviewer-cache-efficiency.md)

---

## STATUS — read this first

A fresh session starts at **Phase 1, Step 1.1**. Nothing below has been built.
The only work done so far is the audit that produced this plan (read-only; no
files were changed).

| # | Step | Status | Evidence |
|---|---|---|---|
| 0.1 | Audit of all nine reviewer wrappers | ✅ done 2026-08-25 | This plan, § 6 (findings carry `file:line` refs re-derivable from commit `4915ada`) |
| 1.1 | Multi-reviewer review of THIS plan before any code | ⬜ open | — |
| 1.2 | Resolve reviewer disagreements, update plan | ⬜ open | — |
| 2.1 | `ai-review-sandbox`: digest-gated snapshot reuse | ⬜ open | — |
| 2.2 | Tests for digest-gated reuse | ⬜ open | — |
| 2.3 | Multi-reviewer review of the 2.1 diff | ⬜ open | — |
| 3.1 | `ai-claude-review`: deterministic sandbox tag | ⬜ open | — |
| 3.2 | `ai-codex-review`: deterministic sandbox tag | ⬜ open | — |
| 3.3 | Reorder both gate prompts: invariant prefix first | ⬜ open | — |
| 3.4 | Tests for deterministic tags and retained snapshots | ⬜ open | — |
| 4.1 | DeepSeek: capture and report cache-hit tokens | ⬜ open | — |
| 4.2 | Muse: break out cache-hit tokens in report + stderr | ⬜ open | — |
| 4.3 | Tests for both usage reporters | ⬜ open | — |
| 5.1 | Full offline suite green | ⬜ open | — |
| 5.2 | Gate reviews (Claude + Codex `diff-review`) APPROVE | ⬜ open | — |
| 5.3 | Commit, push, docs updated, handoff closed | ⬜ open | — |

**Rule for this table:** a row moves to ✅ only with an artifact in the evidence
cell — a commit SHA, a test file path, a saved report under `.ai/reviews/`, or
the exact command to re-run. A bare "it passed" is not evidence.

---

# Part 1 — Why

## 1. The ultimate goal — what we are actually trying to achieve

**Albert pays for every token these reviewers read. Today a large share of that
spend is buying the same thing over and over.**

When the governed pipeline runs its four review stages against one unchanged
code state, each stage sends the reviewer a prompt whose opening bytes are
different from the last one's — so the provider's prompt cache cannot recognise
it, and the whole repository context is billed again at full price. Separately,
every follow-up turn in every reviewer conversation re-clones the repository and
rebuilds its evidence packet from scratch, even when not a single byte of source
has moved, costing wall-clock time on every question. And for two reviewers we
cannot even see whether caching is working, because the numbers the provider
returns are thrown away.

**When this work is done:**

- Repeated review stages against the same code hit the provider's prompt cache
  instead of paying full price for identical context.
- A follow-up question to any reviewer is near-instant when the code has not
  changed, instead of waiting on a full repository clone and packet rebuild.
- Albert can look at a DeepSeek or Muse review report and see how many tokens
  were served from cache — the same visibility Grok already gives.

**Nothing about review safety, read-only boundaries, evidence integrity, or
verdict trustworthiness may get weaker in exchange for any of this.** That is
not a trade we are willing to make. A cheaper review that can approve stale code
is worthless — it is worse than worthless, because it looks like a review.

> **If a step in this plan conflicts with this goal, the goal wins — stop and
> flag it.** In particular: if you find that a step would let a reviewer see
> stale code, skip an integrity check, or report a cached-token number the
> provider did not actually return, do not implement that step. Stop, write down
> what you found, and raise it. Under-delivering on speed is acceptable.
> Under-delivering on evidence integrity is not.

## 2. What this application is

`ai-devops` is Albert Hazan's personal DevOps toolkit repository. It is not a
customer-facing application — it is the machinery that lets AI sessions (Claude
Code and Codex) work safely across his machines and projects.

- **GitHub:** `u2giants/ai-devops`, **public**. No secret values may ever be
  committed. Secrets live in the 1Password vault `vibe_coding` and are
  referenced by item title only.
- **Branch policy:** `AGENTS.md:20` — *"Work directly on `main`; do not create
  feature branches for this repository."* This plan was authored inside a Git
  worktree on branch `claude/reviewer-setup-audit-23cef2`; the implementer
  should land the work on `main` per that rule, reconciling concurrent `main`
  safely and confirming the commit is present on `origin/main`
  (`AGENTS.md:114-115`).
- **Stack:** POSIX shell (`bash`) for the `bin/ai-*` tools, PowerShell for
  Windows setup scripts, `jq` for JSON, `git` for everything. There is no
  server, no database, no deployment. "Deployed" here means *installed onto a
  machine* by the repository's own installers.
- **Where it runs:** developer machines. This work was planned on `edge-dev`
  (Windows 11, Git Bash). The tools also run on Ubuntu hosts (`hetz`) and other
  Windows boxes. **Both platforms must keep working** — Git Bash path quirks are
  a recurring source of bugs in exactly the files this plan touches.
- **Who uses it:** Albert, and the AI sessions acting on his behalf.

### The reviewer subsystem, in one paragraph

Claude and Codex do not review their own work unsupervised. The repository ships
a family of wrapper commands under `bin/` that hand a code change to an
independent model for a read-only second opinion. Two of them —
`bin/ai-claude-review` (Claude Opus 5) and `bin/ai-codex-review` (GPT-5.6) — are
**gate reviewers**: they are the only reviewers permitted to satisfy an approval
gate, enforced by the front door `bin/ai-review` (see `bin/ai-review:9-11`,
which refuses every other provider with *"is advisory or quarantined and cannot
satisfy an approval gate"*). The rest — Grok, GLM, Kimi, Qwen, Muse, DeepSeek,
Gemini — are **advisory**: valuable second opinions that cannot approve
anything. All of them share two pieces of plumbing:

- **`bin/ai-review-sandbox`** — builds a disposable, self-contained clone of the
  code under review. It exists because every reviewer CLI accepts exactly one
  directory as its boundary, and in a linked Git worktree the `.git` control
  files live *outside* that boundary, so the reviewer's first git-adjacent read
  is refused and the run dies before reading any code (observed 2026-08-17; see
  the header of that file).
- **`bin/ai-review-packet`** — writes a small `.ai-review/` directory inside the
  boundary containing the facts a shell would have produced: base and head SHAs,
  changed-file list, the patch, untracked inventory, test results. It exists
  because a reviewer with no shell cannot run `git diff`, and without it
  reviewers burned ~3,000,000 tokens over 20 turns producing no verdict, three
  times over (see that file's header and `fix_reviewer_system.md`).

## 3. What triggered this work

On 2026-08-25 Albert asked for an audit of all reviewer setups (wrappers and
OpenCode harnesses) to confirm they were being used efficiently — maximising
context and prompt caching and maintaining persistent per-subject sessions. The
audit found the subsystem broadly healthy: seven of nine reviewers hold real
named sessions with stable, cache-friendly prompt prefixes.

It found three specific defects, which are the entire content of this plan.
**This is not a bug report from a user — it is a cost and latency finding, and
there is no user-visible breakage today.** Nothing is currently failing. That
matters for how you weigh risk: we are optimising a working system, so *any*
regression in correctness is a net loss.

**How to see the problem for yourself** (read-only, safe, costs nothing):

```bash
grep -n 'RUN_ID=\|TAG=' bin/ai-claude-review bin/ai-codex-review
```

You will see the sandbox tag mixes in `$$` (process id) and `$RANDOM`, so the
review directory has a different absolute path on every single run.

```bash
sed -n '245,272p' bin/ai-review-sandbox
```

You will see `create_or_refresh` rebuild the clone unconditionally — it never
consults the `source_digest=` value it wrote into the snapshot's own marker file
on the previous run.

## 4. Scope — in and out

### In scope

1. **Deterministic snapshot paths for the two gate reviewers**, plus reordering
   their prompts so the cacheable, invariant text comes first.
2. **Digest-gated snapshot reuse in `bin/ai-review-sandbox`**, which removes the
   redundant clone-and-packet rebuild for *every* reviewer, Muse included.
3. **Cache-hit token capture and reporting for DeepSeek and Muse.**
4. Tests for all of the above, and documentation updates.

### Explicitly NOT in this plan

- **Do not move Muse from direct mode to OpenCode server mode.** This was
  investigated and rejected on two independent grounds — server mode *failed
  Meta authorization*, and one shared server would couple two credentials and
  outage domains so a broken Muse config could take GLM down. See
  `docs/muse-opencode.md` lines 3-6 and the "Why there is no Muse service"
  section, and `plan_muse-opencode-harness.md` lines 19, 31-32, 160. **This is a
  locked decision. Do not reopen it inside this plan.** The Node cold start on
  each Muse turn is the accepted, documented price of the working path.
- **Do not add cache reporting for Kimi or Qwen.** Their CLIs emit no usage,
  token, cost, or model data in headless output at all. `bin/ai-kimi:888` and
  `bin/ai-kimi:1504` say so explicitly and print `unavailable`. Inventing a
  number there would be a lie in a report.
- **Do not touch `bin/ai-gemini`.** Gemini is quarantined pending live safety
  qualification (`QUARANTINED=1` at `bin/ai-gemini:41`). Leave it alone.
- **Do not add cache reporting for GLM.** Out of the requested scope. If it is
  easy, write it down as a follow-up; do not build it here.
- **Do not change any reviewer's read-only tool boundary, permission map, agent
  file, model pin, completion rule, or verdict format.**
- **Do not refactor `bin/ai-review-packet`'s inclusion rule** or change what
  goes into a packet.
- **Do not change `bin/ai-review`'s gate policy** (which providers may approve).
- **Do not merge, extract, or genericise the reviewer wrappers.** Copying or
  unifying safety code across providers was considered and rejected in
  `plan_muse-opencode-harness.md:145,161-162`.
- **Do not change `bin/ai-review-scoreboard`.** Feeding new cache metrics into
  the scoreboard is a possible follow-up, not this work.

---

# Part 2 — What we already know

## 5. Current state of the code

Everything described here is **committed and pushed** as of
`4915adac90f7867b4475a3d146920f5e3480b0a4` on `main`. Nothing is half-done.
There is no work-in-progress to pick up, no stashed changes, and no partially
applied refactor. You are starting from a clean, working system.

### The files you will change

| File | Lines | What it does today |
|---|---|---|
| `bin/ai-review-sandbox` | 343 | Builds/refreshes disposable review clones. `create_or_refresh` at line 245 always rebuilds. |
| `bin/ai-claude-review` | 122 | Gate reviewer, Claude Opus 5. Random tag at line 61. |
| `bin/ai-codex-review` | 271 | Gate reviewer, GPT-5.6. Random tag at lines 121/126. |
| `bin/ai-deepseek-agent` | 600 | Freeform DeepSeek conversation. Response parsing at line 295. |
| `bin/ai-muse` | 394 | Persistent Muse Spark reviews. Token capture at line 277, report at line 306. |

### The tests you will extend

| File | Lines | Covers |
|---|---|---|
| `tests/test-ai-review-sandbox.sh` | 258 | Snapshot build, hostile races, managed-path refusals |
| `tests/test-ai-claude-review.sh` | 77 | Gate reviewer command validation |
| `tests/test-ai-codex-review.sh` | 149 | Gate reviewer command validation |
| `tests/test-ai-deepseek-agent.sh` | 215 | Transcript shape, review boundary |
| `tests/test-ai-muse.sh` | 313 | Session lifecycle, report publishing |

Run the whole offline suite with:

```bash
bash tests/test-all.sh
```

It discovers every `tests/test-*.sh`, runs each, and prints
`OFFLINE BASH SUMMARY tests=<n> failures=<n>`. It must end with `failures=0`.

### Useful existing machinery you should reuse, not reinvent

- **`AI_DEVOPS_TEST_MODE=1`** plus **`AI_REVIEW_SANDBOX_TEST_HOOK`** — a
  deterministic hostile-test hook (`bin/ai-review-sandbox:150-155`). It is
  invoked at named points (`after-copy`) with `(point, root, attempt)` and lets
  a test mutate the source mid-build. It never evaluates text from an
  environment variable. **Use this pattern for the new race tests.**
- **`AI_REVIEW_SANDBOX_TEST_FAIL_DIFF=1`** — forces the diff step to fail
  (`bin/ai-review-sandbox:207-209`).
- **`ai-review-sandbox digest <dir>`** — the public subcommand that computes a
  source digest for any directory (`bin/ai-review-sandbox:340`). Already used by
  `bin/ai-claude-review:105` as the reviewer-write detector.

## 6. Key findings and root cause

### Finding A — the gate reviewers make their own prompt uncacheable

`bin/ai-claude-review:61`:

```bash
RUN_ID="$(date -u +%Y%m%dT%H%M%S)-$$-$RANDOM"; TAG="claude-${MODE}-${RUN_ID}"
```

`bin/ai-codex-review:121,126` does the same with a `codex-` prefix. That `TAG`
is passed to `ai-review-sandbox ensure-copy`, and `sandbox_id`
(`bin/ai-review-sandbox:65-69`) turns it into the directory name
`<tag>-<12 hex of repo root>`. So the review directory's **absolute path changes
on every run**.

That path is then written into the very first characters of the prompt
(`bin/ai-claude-review:93-101`), which begins:

```
You are performing a READ-ONLY $MODE. ...
Read $PACKET_DIR/MANIFEST.md first. ...
```

Two independent things therefore break prefix caching: the random path, **and**
`$MODE` appearing in the opening line. The seven-stage pipeline
(`bin/ai-model-call`) drives four review stages — `plan-review`, `diff-review`,
`security`, `final` — against the same source. Every one is a cold, full-price
read of the same repository. `bin/ai-claude-review:12` additionally passes
`--no-session-persistence`, so there is no session to resume either.

**Root cause:** one identifier is doing two jobs. `RUN_ID` legitimately needs to
be unique — it names the report file (`bin/ai-claude-review:110`) and feeds
lifecycle accounting. The *sandbox tag* has no such requirement and inherited
the uniqueness by accident.

### Finding B — the snapshot is rebuilt even when nothing changed

`bin/ai-review-sandbox:245-271`, `create_or_refresh`, always runs the full
build: `git clone --no-hardlinks`, detach at base, apply `git diff HEAD --binary`,
copy untracked files, validate links, write the marker. It then publishes with a
before/after `source_digest` comparison to refuse mixed evidence.

The snapshot already records the digest it was built from —
`bin/ai-review-sandbox:200` writes `source_digest=<hash>` into the
`.ai-review-sandbox` marker file. **Nothing ever reads that value back to decide
whether a rebuild is needed.**

Every wrapper pays this on every turn. `ai-muse` calls `prepare()` on both `new`
and `ask` (`bin/ai-muse:132-139`); `ai-grok-review`'s `cmd_ask` calls
`prepare_review` (`bin/ai-grok-review:1162`); `ai-kimi` does the same at
`bin/ai-kimi:1106,1739`. **This is universal, not a Muse-specific defect** — an
earlier draft of the audit wrongly claimed Grok and Kimi already skipped it.
They do not. Fixing it once in the shared file fixes it for all of them.

### Finding C — cache numbers the provider returns are discarded

- **DeepSeek:** `bin/ai-deepseek-agent:295` extracts
  `data["choices"][0]["message"]["content"]` and nothing else. The DeepSeek API
  returns `usage.prompt_cache_hit_tokens` and `usage.prompt_cache_miss_tokens`
  in the same response body. They are dropped on the floor. The conversation
  shape is ideal for caching — system message first, strictly append-only
  (`bin/ai-deepseek-agent:311-321`) — so the hit rate should be high, but nobody
  can confirm it.
- **Muse:** `bin/ai-muse:277` already captures the whole `tokens` object from
  the terminal `step_finish` event as compact JSON, and `bin/ai-muse:306` prints
  it into the report as a single opaque `| tokens | {...} |` cell. The cache
  numbers are *in there*, unlabelled and unreadable at a glance.
- **The good example to copy:** `bin/ai-grok-review:858-864`, `report_usage`,
  which prints total, uncached-in, `cache_read_input_tokens`, turns, cost, and
  model. `bin/ai-grok-review:954` puts the same in the session list.

## 7. Approaches considered and REJECTED

Read this section before you "improve" anything. Each item cost real
investigation.

| # | Approach | Why rejected |
|---|---|---|
| 1 | Run Muse on the GLM OpenCode **server** so the process stays warm | **Server mode failed Meta authorization.** Also rejected independently for fault isolation: one server means coupled credentials, restarts, logs, and outage domains, so a broken Muse config could take GLM down. `docs/muse-opencode.md:3-6,49-54`; `plan_muse-opencode-harness.md:19,31-32,160`. **Locked. Do not reopen.** |
| 2 | Just make `ai-muse` skip its rebuild, since that is what Albert asked about | The defect is in shared plumbing and affects all seven advisory reviewers plus both gates. A Muse-local patch would leave the same waste everywhere else and create a second code path to drift. Fix `ai-review-sandbox` once. |
| 3 | Give the gate reviewers a **per-mode** stable tag (`claude-diff-review`) | Repeated runs of the *same* stage would cache, but the four different stages still would not — and cross-stage reuse is where the actual money is. See design decision D2 for the accepted answer and its cost. |
| 4 | Cache by comparing file modification times instead of content digests | Mtimes lie — Git checkouts, worktree operations, and Windows filesystems all produce misleading timestamps. The content digest already exists and is already trusted by the reviewer-write detector. Never introduce a second, weaker notion of "changed". |
| 5 | Have the reuse path `die` when it detects a mutated snapshot | A reviewer that wrote into its snapshot is a real safety signal, but at *reuse* time the correct response is to rebuild, not to fail. The post-run write detector at `bin/ai-claude-review:105` is what must stay fail-closed. Reuse must be fail-*safe*: any doubt, rebuild. |
| 6 | Add cache/token fields into the DeepSeek transcript JSON | The transcript **is the request body** — it is replayed verbatim as `messages` on every turn (`bin/ai-deepseek-agent:267-268`). Adding fields would change the cached prefix (destroying the very thing we are measuring) and would break the review-boundary check that asserts `messages[0]` is exactly the boundary system prompt (`bin/ai-deepseek-agent:380-387`). Usage must go in a **sidecar** file. |
| 7 | Print DeepSeek usage on stdout with the reply | stdout is a contract: callers consume the reply text, and `send` already prints `SESSION_ID: <id>` there. Usage goes to **stderr**, matching `bin/ai-grok-review:858` (`report_usage` writes to `>&2`). |
| 8 | Report `0` when a provider omits cache fields | Zero is a claim. Absent is a different fact. The repository convention is to print `unavailable` — `bin/ai-kimi:888,1504`. Follow it. |
| 9 | Keep the snapshot AND the packet across runs | The packet embeds the per-stage `--decision` text in its manifest, so it genuinely differs per stage and its hash must be re-derived. Retain the snapshot; keep rebuilding the packet. |

## 8. Design decisions already made

**Locked** — implement as written; do not redesign. **Open** — your judgment,
criteria given.

### D1 — Split "run identity" from "snapshot identity". **LOCKED.**
*(2026-08-25)* `RUN_ID` keeps its `$$`/`$RANDOM` uniqueness and keeps naming the
report file and lifecycle record. A new, separate variable names the sandbox and
must contain no time, pid, or random component.

### D2 — The gate sandbox tag is per-provider, not per-mode. **LOCKED.**
*(2026-08-25)* Use `claude-review` and `codex-review` — the same tag for all five
modes. The snapshot contents are identical across modes, so one tag lets all four
pipeline stages reuse one warm directory and one cached prefix.

**Accepted cost, stated plainly:** two review modes running *concurrently* in the
same repository will now contend for one snapshot directory.
`create_or_refresh` takes a `<stage>.lock` directory and dies with *"snapshot is
already being built for tag ..."* if one is already in progress
(`bin/ai-review-sandbox:248`). The seven-stage pipeline runs its stages
sequentially, so this does not affect it. A human running two gate reviews at
once in one repo will get a clear refusal instead of two independent snapshots.
**That refusal is acceptable and must be tested for** (Step 3.4). If review of
this plan finds a real workflow that needs concurrent same-repo gate reviews,
raise it in Phase 1 — do not silently switch to per-mode tags.

### D3 — The reuse gate is a three-way digest equality. **LOCKED.**
*(2026-08-25)* Reuse the existing snapshot only when **all** of these hold:

1. The stage directory exists and passes `is_managed` (marker present **and**
   physically under `$SANDBOX_DIR` — `bin/ai-review-sandbox:83-91`).
2. The marker's recorded source root matches the requested root.
3. The marker's recorded `source_digest=` equals `source_digest <root>` computed
   now.
4. `source_digest <stage>` — the snapshot's own current digest — also equals it.

Condition 4 is what catches a reviewer that wrote into its snapshot, or a
partially deleted directory. It is the same comparison
`bin/ai-claude-review:105` already trusts as the reviewer-write detector, which
is why it is sound: the snapshot is built to be byte-identical to the source for
every review-visible file, so all three digests must agree.

**Anything else → rebuild.** The reuse path must never `die`; a failure to
*verify* reuse is simply a decision to rebuild.

### D4 — Reuse must be silent to callers. **LOCKED.**
*(2026-08-25)* `ensure-copy` / `refresh-copy` must still print the same directory
path on stdout whether it rebuilt or reused. No caller may need to change. Say
what happened on **stderr** only.

### D5 — There must be a force-rebuild escape hatch. **LOCKED.**
*(2026-08-25)* `AI_REVIEW_SANDBOX_FORCE_REBUILD=1` skips the reuse check
entirely. This is the first thing to try when diagnosing anything odd, and the
recovery instruction to put in the docs.

### D6 — The gate reviewers stop deleting their snapshot on exit. **LOCKED.**
*(2026-08-25)* A stable tag is pointless if `cleanup` removes the directory at
the end of every run (`bin/ai-claude-review:64-67`,
`bin/ai-codex-review:133`). Retain the snapshot; keep removing the packet.
Snapshots remain disposable and safe to delete by hand at any time; document the
manual cleanup command.

### D7 — Prompt reordering: invariant text first. **LOCKED.**
*(2026-08-25)* A stable path is necessary but not sufficient — `$MODE` currently
sits in the opening line. Restructure both gate prompts so the mode-independent
text (packet location, review boundary, tool restriction, verdict format) forms
one identical opening block, and the mode-specific `$DECISION` comes **after**
it. The *semantic content must not change* — same instructions, same verdict
contract, same words wherever possible, only reordered.

### D8 — Never report a number the provider did not return. **LOCKED.**
*(2026-08-25)* Absent fields print `unavailable`, never `0`. See rejected
approach 8.

### D9 — Which reviewers review this work, and when. **LOCKED for item 2, open elsewhere.**
*(2026-08-25, at Albert's explicit instruction)* The `ai-review-sandbox` change
(item 2) is the highest-risk change in this plan — it touches shared evidence
plumbing that every reviewer and both approval gates depend on. It **must** be
reviewed by multiple independent models both at plan stage and at diff stage.
See Steps 1.1 and 2.3 for exactly who and exactly what to ask. **Kimi and Gemini
are excluded — both are quarantined** (`memory` entry "Kimi review failure
recovery", issue #46; `bin/ai-gemini:41`).

### D10 — Phase order. **OPEN, with criteria.**
Phases 3 and 4 are independent of each other and of Phase 2. The order below
puts Phase 2 first because it is the riskiest and benefits every reviewer. If
you have a concrete reason to reorder — for example a reviewer is unavailable
and Phase 2's review would block — you may do Phase 3 or 4 first. **Do not
merge phases into one commit**; each phase lands separately so a rollback is
surgical.

---

# Part 3 — How to build it

## 9. The plan

Phases are context cut points. **Re-read the downstream phases before starting
each one** — the plan may have been updated by the previous phase's reviewers.
Consider a fresh session at each boundary (`fresh-session` skill).

---

### Phase 1 — Review this plan before writing any code

Albert asked specifically that item 2 be reviewed by multiple reviewers *in
planning* as well as in implementation. This phase is not optional and it comes
before the first line of code.

#### Step 1.1 — Send this plan to three independent reviewers

Run all three. Each gets the **same** brief. Use the repository's own skills so
the session bookkeeping and read-only boundaries are handled for you:

| Reviewer | How to invoke | Skill |
|---|---|---|
| GLM 5.3 | `ai-glm new plan-cache-review --prompt-file <brief>` | `ask-glm` |
| Grok | `ai-grok-review` via its skill | `grok-cli` |
| Codex (GPT-5.6) | second-opinion flow | `codex-second-opinion` |

Optionally add Muse (`ask-muse`) and Qwen (`qwen-code`) if you want more
coverage; three is the floor, not the ceiling.

**The brief must ask these five questions explicitly.** Do not just say "review
this plan" — a vague brief is how reviews burn their budget wandering
(`bin/ai-grok-review:1147-1152`):

1. Read `plan_reviewer-cache-efficiency.md` § 8 decision **D3**. Is the
   three-way digest equality *sufficient* to guarantee a reused snapshot is
   byte-identical to what a fresh rebuild would produce? Name any case where all
   three digests match but the snapshot is materially different from a fresh
   build. Consider at minimum: ignored files, submodules/gitlinks, symlinks,
   file permission bits, the `.git/info/exclude` entries the builder appends,
   `AI-REVIEW-SANDBOX.md`, empty directories, and case-insensitive filesystems.
2. `source_digest` (`bin/ai-review-sandbox:140-148`) covers the HEAD tree hash,
   the tracked diff bytes and its sha256, and every untracked non-ignored file's
   path, type, byte count and sha256. Is anything a reviewer can *see* excluded
   from that digest? If yes, reuse is unsound as designed — say so.
3. Decision **D2** makes all five gate modes share one snapshot directory,
   which serialises concurrent same-repo gate reviews. Is there a real workflow
   in this repository that runs two gate reviews concurrently in one repo? Check
   `bin/ai-model-call` and `bin/ai-review-lifecycle` before answering.
4. Decision **D6** stops deleting the gate snapshot on exit. What is the worst
   consequence of a retained snapshot on disk, and does anything in this
   repository assume the directory is gone after a review?
5. Is there anything in this plan that would let a reviewer approve a verdict
   against source it did not actually read?

**Verification gate:** three review reports exist under `.ai/reviews/`, each
answering all five questions. Record their paths in the STATUS table.

#### Step 1.2 — Resolve disagreements and update the plan

Any reviewer identifying a case where the D3 gate is insufficient **blocks Phase
2** until this plan is amended. Do not argue a finding away in chat and proceed
— amend the plan file, note the change in the STATUS table with the date, and
say which reviewer prompted it.

If reviewers disagree with each other, the conservative reading wins: a
disputed reuse case becomes an unconditional rebuild.

**Verification gate:** every reviewer finding is either incorporated into the
plan or has a written reason recorded here for rejecting it. `git diff` on this
plan file shows the amendments.

---

### Phase 2 — Digest-gated snapshot reuse (the risky one)

#### Step 2.1 — Add the reuse gate to `bin/ai-review-sandbox`

**File:** `bin/ai-review-sandbox`, function `create_or_refresh` (line 245).

Add a new helper — suggested name `snapshot_is_current` — and call it at the top
of `create_or_refresh`, before the lock is taken and before the build loop.

**Behaviour when done:**

- Returns success only when all four D3 conditions hold.
- On success, `create_or_refresh` returns 0 immediately without cloning, without
  touching the existing directory, and without taking the build lock. The caller
  prints the same stage path it always did (D4).
- On any other outcome — directory missing, not managed, marker unreadable,
  recorded root mismatch, digest mismatch, digest computation failing — it
  returns non-zero and the existing build path runs **completely unchanged**.
- It must never `die`. `source_digest` itself dies on an unreadable tree
  (`bin/ai-review-sandbox:147`), so if you call it on the *snapshot* you must
  invoke it in a way that a failure becomes a rebuild rather than an abort.
  A subshell whose failure you catch is the straightforward approach.
- Respect `AI_REVIEW_SANDBOX_FORCE_REBUILD=1` by returning non-zero immediately
  (D5).
- Emit one line to **stderr** on reuse, in the existing `warn`/message style,
  naming the tag and saying the source is unchanged. Nothing on stdout (D4).

**Do not change:** the marker format, `sandbox_id`, `sandbox_path`, `is_managed`,
`remove_sandbox`, `source_digest`, `source_inventory`, the two-attempt
before/after race protection, or any `die` message on the build path. The
version string at `bin/ai-review-sandbox:45` should be bumped.

**Also confirm** `cmd_refresh_copy` (line 285) benefits: it calls the same
`create_or_refresh`, so it inherits reuse automatically. It must keep its
existing pre-checks (managed path, recorded tag match) — those run *before*
`create_or_refresh` and must not move.

**Verification gate:**
```bash
bash tests/test-ai-review-sandbox.sh
```
still passes with the existing tests untouched, and a manual check shows reuse:
build a snapshot in a scratch repo, note the directory's inode/creation time,
run `ensure-copy` again with no source change, and confirm the directory was not
rebuilt and the stderr line appeared.

#### Step 2.2 — Tests for digest-gated reuse

**File:** `tests/test-ai-review-sandbox.sh`. Add these cases by name:

| Test | Asserts |
|---|---|
| `reuse_when_source_unchanged` | Second `ensure-copy` does not rebuild; stdout path identical; a sentinel file placed inside the snapshot by the test survives |
| `rebuild_when_tracked_file_modified` | Editing a tracked file forces a rebuild; the sentinel is gone |
| `rebuild_when_untracked_file_added` | A new untracked, non-ignored file forces a rebuild |
| `rebuild_when_untracked_file_removed` | Deleting one forces a rebuild |
| `rebuild_when_head_moves` | A new commit forces a rebuild |
| `rebuild_when_snapshot_mutated` | Writing into the *snapshot* forces a rebuild — this is the reviewer-write case |
| `rebuild_when_marker_missing_or_corrupt` | A truncated/absent `.ai-review-sandbox` marker forces a rebuild, never a reuse and never a `die` |
| `no_reuse_for_unmanaged_directory` | A directory outside `$SANDBOX_DIR` is never reused |
| `force_rebuild_env_overrides_reuse` | `AI_REVIEW_SANDBOX_FORCE_REBUILD=1` always rebuilds |
| `reuse_prints_nothing_extra_on_stdout` | stdout is exactly the path, byte for byte, on both the build and the reuse path |
| `ignored_file_change_does_not_force_rebuild` | Changing a `.gitignore`d file reuses — correct, because it is not review-visible |

Use `AI_DEVOPS_TEST_MODE=1` and the existing `AI_REVIEW_SANDBOX_TEST_HOOK`
pattern for anything needing a mid-build mutation. Follow the file's existing
scratch-repo setup and assertion helpers rather than inventing new ones.

**Verification gate:** `bash tests/test-all.sh` ends `failures=0`.

#### Step 2.3 — Multi-reviewer review of the Phase 2 diff

Same reviewer set as Step 1.1 — GLM, Grok, Codex — now reviewing the actual
change, plus **both gate reviewers**:

```bash
ai-review claude diff-review
```
```bash
ai-review codex diff-review
```

Advisory reviewers get this brief: *"This change makes a review snapshot
reusable when a digest says the source is unchanged. Find any case where a
reviewer could now be handed code that does not match the working tree. Assume
the author is wrong."*

**Verification gate:** both gate reviews return `## Verdict / APPROVE`, and no
advisory reviewer has an unresolved finding. **A `REJECT` from either gate stops
this phase** — fix and re-run; do not proceed with an outstanding rejection.

Commit Phase 2 on its own.

---

### Phase 3 — Deterministic gate snapshot paths

#### Step 3.1 — `bin/ai-claude-review`

At line 61, split the identifier (D1):

- `RUN_ID` keeps `$(date -u +%Y%m%dT%H%M%S)-$$-$RANDOM` and keeps feeding the
  lifecycle `--run-id` (line 70) and the report filename (line 110).
- Add `SANDBOX_TAG="claude-review"` (D2) and use it for `ensure-copy` (line 71)
  and for `ai-review-packet build` (line 91).
- Update `cleanup` (lines 64-67): keep `"$PACKET" remove`, **delete** the
  `"$SANDBOX" remove-copy` line (D6).

Verify by eye that `TAG` has no other uses before removing it — `grep -n 'TAG'
bin/ai-claude-review`.

#### Step 3.2 — `bin/ai-codex-review`

The same change at lines 121/126/133/182, with `SANDBOX_TAG="codex-review"`.
Note this file has more structure around it (`--tests` handling, timeout,
`secure_review_directory`); change only the tag and the cleanup line.

#### Step 3.3 — Reorder both prompts (D7)

**File:** `bin/ai-claude-review:93-101` and the equivalent block in
`bin/ai-codex-review`.

Restructure to: **(a)** an invariant opening block — packet manifest location,
the review directory boundary, the Read/Grep/Glob-only restriction, the "do not
edit, create, commit, push, merge, delete" instruction, and the `## Verdict`
format contract; then **(b)** a separator; then **(c)** `You are performing a
READ-ONLY $MODE.` and `$DECISION`.

The instructions must be semantically identical to today's. Keep the same
sentences wherever possible — this is a reordering, not a rewrite. `$DECISION`
already carries any `AI_REVIEW_BRIEF_FILE` stage brief appended to it
(`bin/ai-claude-review:84-90`), so it stays last naturally.

**Behaviour when done:** for one repository at one source state, the first N
characters of the prompt are byte-identical across all five modes, with N as
large as the invariant block.

#### Step 3.4 — Tests

In `tests/test-ai-claude-review.sh` and `tests/test-ai-codex-review.sh`:

| Test | Asserts |
|---|---|
| `sandbox_tag_is_deterministic` | The tag string contains no `$$`, `$RANDOM`, or timestamp — assert on the literal in the script and, if the harness allows, on two runs producing the same directory |
| `run_id_remains_unique` | Two runs still produce different report filenames |
| `snapshot_survives_exit` | After a completed run the snapshot directory still exists |
| `packet_removed_on_exit` | The packet directory is gone |
| `prompt_prefix_identical_across_modes` | The invariant block is byte-identical for two different modes |
| `concurrent_same_repo_review_refuses_clearly` | A second concurrent review in the same repo fails with the existing "already being built" message rather than corrupting anything (D2's accepted cost) |

**Verification gate:** `bash tests/test-all.sh` ends `failures=0`. Commit Phase 3
separately.

---

### Phase 4 — Cache-hit token reporting

#### Step 4.1 — DeepSeek

**File:** `bin/ai-deepseek-agent`, the embedded Python at line ~295 and its
callers around lines 260-296, 518-520, 572.

- Extend the extraction to also read `data.get("usage", {})` and pull
  `prompt_cache_hit_tokens`, `prompt_cache_miss_tokens`, `total_tokens`, and
  `prompt_tokens`/`completion_tokens` if present.
- Write the reply to the existing reply file **unchanged** — stdout must remain
  byte-identical (rejected approach 7).
- Print one line to **stderr** in the Grok style, e.g.
  `tokens: <total> (cache hit: <n>, miss: <n>) model: <model>`; any absent field
  prints `unavailable` (D8).
- Append the usage object to a **sidecar** file beside the session transcript —
  suggested `<session>.usage.jsonl`, one JSON object per turn. **Do not touch
  the transcript JSON itself** (rejected approach 6): it is replayed verbatim as
  the request body and is guarded by `review_system_present`
  (`bin/ai-deepseek-agent:380-387`).

#### Step 4.2 — Muse

**File:** `bin/ai-muse:277` (capture) and `:306` (report).

- `TOKENS` already holds the complete `.part.tokens` object. Keep capturing it.
- In the report table, replace the single opaque `| tokens | {...} |` row with
  labelled rows — input, output, cache read, cache write, total — reading the
  fields OpenCode actually emits. **Check the real field names against a live
  event stream or a saved fixture before writing the `jq` paths**; do not guess.
  `docs/muse-opencode.md` records that a measured follow-up "reported a large
  cache read", so the field exists; confirm its exact spelling.
- Any field OpenCode omits prints `unavailable` (D8).
- Also print a one-line stderr summary on each turn, matching Grok's shape.
- Keep the raw object in the report as well, so nothing is lost if a field name
  changes.

#### Step 4.3 — Tests

In `tests/test-ai-deepseek-agent.sh`:

| Test | Asserts |
|---|---|
| `usage_line_written_to_stderr` | The summary appears on stderr |
| `stdout_reply_unchanged` | stdout is byte-identical to before the change for a fixed stub response |
| `transcript_json_shape_unchanged` | The messages file has no new keys and `messages[0]` is still exactly the boundary |
| `usage_sidecar_appends_per_turn` | Two turns produce two sidecar lines |
| `missing_usage_reports_unavailable` | A stub response with no `usage` prints `unavailable`, never `0`, and does not fail the turn |

In `tests/test-ai-muse.sh`:

| Test | Asserts |
|---|---|
| `report_breaks_out_cache_tokens` | The published report contains the labelled cache rows |
| `missing_token_fields_report_unavailable` | A stub `step_finish` without token fields yields `unavailable` and still publishes |
| `raw_token_object_retained` | The raw object is still present in the report |

**Verification gate:** `bash tests/test-all.sh` ends `failures=0`. Commit Phase 4
separately.

---

### Phase 5 — Land it

#### Step 5.1 — Full suite
```bash
bash tests/test-all.sh
```
Must end `failures=0`. On Windows also run the PowerShell suite per
`docs/development.md`.

#### Step 5.2 — Gate reviews of the complete change
```bash
ai-review claude diff-review
```
```bash
ai-review codex diff-review
```
Both must return `APPROVE`. Then:
```bash
ai-review claude final-check
```

#### Step 5.3 — Documentation, commit, push

- Update the verification header of `bin/ai-review-sandbox` to describe the
  reuse gate and the `AI_REVIEW_SANDBOX_FORCE_REBUILD` escape hatch. That header
  is load-bearing: `AGENTS.md:61` routes readers to it.
- Update `docs/architecture.md` where the review sandbox is described.
- Add a line to `docs/muse-opencode.md` noting the new cache reporting, and
  reaffirming that direct mode is unchanged and deliberate.
- Update this plan's STATUS table with artifacts.
- Update the handoff file and mark it closed.
- Load the `session-docs-update` skill — it carries a mandatory plan-file gate
  for exactly this.
- Commit on `main` (`AGENTS.md:20`), reconcile concurrent `main` without force,
  push, and confirm the commit is present on `origin/main`.

## 10. Tests required

Every test named in Steps 2.2, 3.4 and 4.3 above must exist and pass. In
addition, **the entire existing suite must stay green** — no test may be
deleted, weakened, skipped, or have an assertion relaxed to accommodate this
work. If an existing test now fails, that is a finding about your change, not
about the test.

Guarded properties that must still hold afterwards:

- `tests/test-ai-review-packet.sh` — the packet stays *additive*; the reviewer
  keeps full read access to the repository.
- `tests/test-ai-glm.sh` — GLM's disposable-clone and `origin`-removal controls.
- The read-only agent toolsets in `config/opencode/agent/glm-review.md`,
  `config/opencode-muse/agent/muse-review.md`, `config/kimi/readonly-review.md`
  are untouched by this work.

## 11. Constraints, standing rules, and gotchas

**Repository and process**

- Work directly on `main`; no feature branches (`AGENTS.md:20`).
- Before your first commit run `git var GIT_COMMITTER_IDENT`; it must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- This checkout may be shared with other sessions. **Stage only your own
  files** — never `git add -A`. Check for other sessions' changes before pull,
  merge, or commit.
- This repository is **public**. No secret values, ever.

**Engineering**

- Prefer permanent fixes with the fewest moving parts. No band-aids, no silent
  failures, nothing hard-coded that belongs in configuration.
- **Do not simplify a measured guardrail without reading its reason**
  (`AGENTS.md:52`). The files in this plan are dense with comments explaining
  incidents that cost real money. If a check looks redundant, find out why it
  was added before touching it.
- Test everything you create.

**Traps specific to this work**

- **Git Bash path spellings.** `ai-review-sandbox` already handles 8.3 vs long
  paths and mount-point aliases (`bin/ai-review-sandbox:83-91`, `71-78`). Your
  new comparisons must use the same `canon`/`canon_quiet` helpers, never raw
  string equality on paths.
- **`source_digest` dies on failure** (`bin/ai-review-sandbox:147`). In the
  reuse path a failure must become a rebuild, not an abort.
- **The DeepSeek transcript is the request body.** Never add fields to it.
- **Tool names and field names are case-sensitive and fail silently** in this
  ecosystem — the Kimi agent-file incident is the canonical example
  (`config/kimi/readonly-review.md`). Verify Muse's token field names against
  real output.
- **`set -euo pipefail` is in force** in these scripts. An assignment from a
  failing command substitution aborts the script; `ai-glm` has a comment about
  exactly this costing every Windows run (`bin/ai-glm:52-55`).
- **A snapshot must never be reused across different repository roots.** The
  marker records the source root; check it (D3 condition 2).
- **Reviewer quarantines:** Kimi (issue #46) and Gemini are quarantined. Do not
  route review work to them.
- **GPT-5.6 runs at `low` or `medium` reasoning only** — never `high`, `none`,
  or `minimal`. The gate wrapper enforces this
  (`bin/ai-codex-review:56`); do not weaken it.

## 12. Access and environment

- **Machine:** planned on `edge-dev` (Windows 11). Use **Git Bash** for the Bash
  tools and suites; PowerShell for `.ps1` suites.
- **Repository:** `C:\repos\ai-devops` (this plan was authored in the worktree
  `C:\repos\ai-devops\.claude\worktrees\reviewer-setup-audit-23cef2`).
- **Required commands:** `git`, `jq`, `bash`, `sha256sum`, `curl`, `python`.
- **Reviewer CLIs:** Claude Code and Codex must be authenticated for the gate
  reviews. Check with `ai-review doctor`, which runs both wrappers' doctors.
- **Advisory reviewers:** `ai-glm doctor`, `AI_MUSE_CALLER=claude ai-muse
  doctor`, `ai-grok-review` per its skill, `ai-deepseek-agent doctor`.
- **Secrets — by location only, never by value.** 1Password vault
  `vibe_coding`: the Muse key is item *"Meta ai Muse Spark API Key"*, field
  *api key*; DeepSeek and other provider keys resolve through
  `~/.config/ai-devops/mcp.env` and the service-account token file, handled by
  the wrappers themselves. **Serialize 1Password access** and load the
  `secrets-to-1password` skill before any 1Password write. Move secret values
  only through pipes or 0600 files — never chat, command arguments, logs, or
  commits.
- **There is nothing to deploy or serve.** "Verify locally" means: run the test
  suite, and run a real review against a scratch repository.

---

# Part 4 — Landing it

## 13. Definition of done, risks, open questions

### Definition of done

- [ ] All three work items implemented as specified in Phases 2, 3, 4.
- [ ] Every named test in Steps 2.2, 3.4, 4.3 exists and passes.
- [ ] `bash tests/test-all.sh` ends `failures=0`; no existing test weakened.
- [ ] Phase 1 plan review completed by ≥3 independent reviewers, findings
      resolved in writing.
- [ ] Phase 2 diff reviewed by ≥3 advisory reviewers **and** both gates, all
      APPROVE.
- [ ] `ai-review claude final-check` returns APPROVE on the complete change.
- [ ] Measured proof of the win, recorded with artifacts: a before/after
      cache-read comparison for two consecutive gate stages on unchanged source,
      and a before/after wall-clock timing for a second `ensure-copy` on
      unchanged source.
- [ ] `bin/ai-review-sandbox` header, `docs/architecture.md`, and
      `docs/muse-opencode.md` updated.
- [ ] This plan's STATUS table updated with real artifacts in every evidence
      cell.
- [ ] Three separate commits (one per phase) on `main`, pushed, confirmed
      present on `origin/main`.
- [ ] Handoff file updated and marked closed.

### Risks and rollback

| Risk | Severity | Mitigation | Rollback |
|---|---|---|---|
| Reuse gate wrongly reuses a stale snapshot → a reviewer approves code that is not the working tree | **Critical** — this is the one that matters | Three-way digest equality (D3); fail-safe-to-rebuild; the dedicated test list in 2.2; multi-reviewer review at plan *and* diff stage | Revert the Phase 2 commit; behaviour returns to always-rebuild |
| Retained snapshots accumulate on disk | Low | They live under `$AI_REVIEW_SANDBOX_DIR` and are safe to delete at any time; document `ai-review-sandbox remove-copy` | Delete the directory |
| Shared gate tag blocks a legitimate concurrent review | Low-medium | Explicitly tested (3.4); the failure is a clear refusal, not corruption | Switch that wrapper to a per-mode tag (rejected approach 3) — a one-line change |
| Prompt reordering subtly changes reviewer behaviour | Medium | Semantics preserved; same sentences reordered; gate reviews must still produce valid verdicts in 5.2 | Revert Step 3.3 alone; the tag change in 3.1/3.2 stands independently |
| Muse token field names guessed wrong → `unavailable` everywhere, or a wrong number | Medium | Verify against real output before writing `jq` paths; raw object retained | Revert Phase 4 commit |
| DeepSeek change alters stdout and breaks a caller | Medium | `stdout_reply_unchanged` test | Revert Phase 4 commit |

### Open questions

1. **Exact Muse token field names.** Not verified during planning — no live Muse
   call was made. Resolve by inspecting a real event stream or a saved fixture
   before writing Step 4.2. **Do not guess.**
2. **How much cache reuse the gate change actually buys.** Unknown until
   measured; the definition of done requires measuring it. If the measured win
   is negligible, say so plainly in the closing report rather than claiming a
   victory — and consider whether Step 3.3's reordering is worth keeping.
3. **Whether GLM should get the same cache reporting.** Out of scope by
   instruction. If Phase 4 makes it trivial, record it as a follow-up item; do
   not build it.
4. **Whether reuse should also apply to the packet.** Currently no, because the
   per-stage decision text changes its manifest (rejected approach 9). If a
   reviewer in Phase 1 argues the decision text should move out of the manifest,
   that is a larger change and belongs in its own plan.

---

## Self-audit (required by `implementation-plan-writer`; preserved here)

**1. Could a brand-new AI session with no project knowledge and no context from
this conversation execute this plan to perfection, without asking anything?**

Yes. § 2 explains what the repository is, where it lives, its branch rule, its
platforms, and — critically — what the reviewer subsystem *is* and why the
sandbox and packet exist, since neither is guessable from the filenames. § 3
gives two copy-pasteable read-only commands that reproduce both defects. § 5
names every file with line counts and current line numbers, states plainly that
nothing is half-done, and points at the existing test hooks
(`AI_DEVOPS_TEST_MODE`, `AI_REVIEW_SANDBOX_TEST_HOOK`) so the implementer does
not invent a new harness. § 9 names target files, functions, and line numbers
for each step, with a verification gate on each. § 12 gives the commands, the
authentication checks, and secret *locations*. The one genuine unknown — Muse's
token field names — is called out twice, in Step 4.2 and open question 1, with
the instruction not to guess.

**2. Does the plan carry every piece of background, nuance and reasoning I
currently hold, including what was ruled out and why?**

Yes. § 7 records nine rejected approaches with their reasons, including the two
that a well-meaning implementer would otherwise walk straight into: putting Muse
on the GLM server (which failed Meta authorization and was rejected for fault
isolation — cited to `docs/muse-opencode.md:3-6` and
`plan_muse-opencode-harness.md:19,160`), and patching `ai-muse` locally instead
of the shared plumbing. § 6 Finding B explicitly records the audit's own
mid-course correction — that an earlier draft wrongly claimed Grok and Kimi
already skipped the rebuild — so the implementer does not inherit that error.
§ 8 labels ten decisions locked or open with dates and reasoning, and D2 states
its accepted cost (serialised concurrent gate reviews) rather than hiding it.
§ 11 lists the environment-specific traps that cost time in this codebase: Git
Bash path spellings, `source_digest` dying on failure, the DeepSeek transcript
being the request body, silent case-sensitive field names, and `set -e`
aborting on a failed command substitution.

**3. Is the ultimate goal stated clearly enough that the implementer could make
a correct judgment call if a step turns out to be wrong?**

Yes. § 1 states the goal in business terms before any technical wording, names
the three concrete outcomes, and then constrains them: no safety, boundary,
evidence-integrity or verdict-trust property may weaken in exchange for speed or
cost. It gives the tie-break instruction explicitly — *"if a step conflicts with
this goal, the goal wins — stop and flag it"* — and, unusually, names the
specific conflicts to watch for (stale code, skipped integrity checks, invented
cache numbers) and states which direction to fail in: under-delivering on speed
is acceptable, under-delivering on integrity is not. § 3 reinforces the weighting
by noting nothing is currently broken, so any regression is a net loss.

**Gap found and fixed during the audit:** the first draft specified Phase 1's
multi-reviewer review as "send the plan to three reviewers", which is exactly
the vague brief this repository has measured as burning a review's whole budget.
Step 1.1 now carries five specific adversarial questions, names the edge cases
to consider (submodules, symlinks, permission bits, case-insensitive
filesystems), and states that a reviewer finding blocks Phase 2 until the plan
is amended in writing.

All comprehensiveness-checklist items pass.
