# Implementation plan — delegated reviewer system repair

Tracking issue: [u2giants/ai-devops#34](https://github.com/u2giants/ai-devops/issues/34)
Analysis this plan implements: [`fix_reviewer_system.md`](fix_reviewer_system.md)
Handoff for this plan: [`HANDOFF.d/2026-08-17T2300Z-al8960ofc-claude-reviewer-packet-plan.md`](HANDOFF.d/2026-08-17T2300Z-al8960ofc-claude-reviewer-packet-plan.md)

---

## STATUS

Read this table first. Do not re-derive or re-plan what is already done.

| # | Step | Status | Evidence (artifact, not a number) |
|---|---|---|---|
| 1 | `ai-review-packet` builder + hashed manifest | ✅ done 2026-08-18 | [`bin/ai-review-packet`](bin/ai-review-packet); 57 tests pass via `bash tests/test-ai-review-packet.sh` |
| 2 | Wrapper-owned SHA identity (no caller-typed SHAs) | ⬜ open | — |
| 3 | Packet wiring into `ai-grok-review` / `ai-kimi` / `ai-glm` | ⬜ open | — |
| 4 | Provider preflight + quarantine (`ai-review-preflight`) | ⬜ open | — |
| 5 | Short ordinary budgets + early provisional verdict | ⬜ open | — |
| 6 | Failure-specific rotation | ⬜ open | — |
| 7 | Performance ledger + `ai-review` front door | ⬜ open | — |
| 8 | 30-review trial against the success criteria | ⬜ open | — |
| 9 | Global source-routing rule + #1097→#1113 regression | ⬜ open | — |

**A fresh session starts at Step 2.** Steps 1–3 are one phase and must land
together; Step 9 is independent of Steps 1–8 and may be done in parallel by a
different session.

---

# Part 1 — Why

## 1. The ultimate goal (plain business English)

Today, asking an independent AI reviewer to check a small code change takes
**fifteen minutes and frequently produces no answer at all**. The reviewer
spends its whole budget hunting around the repository working out what changed,
runs out of turns, and returns nothing. Millions of tokens are spent for zero
business decisions. Meanwhile the main branch moves on, so even a good answer
often arrives already invalid, and the whole cycle restarts.

**When this work is done:** an ordinary small review comes back with a clear
approve/reject-with-reasons answer in **under five minutes**, nearly every time,
and a dead or out-of-credit provider is detected in **seconds instead of
fifteen minutes**. Nothing about safety changes: reviews stay read-only, stay
bound to one exact commit, and still refuse to approve anything when in doubt.

**If a step in this plan conflicts with that goal, the goal wins — stop and
flag it.** Two guardrails on that freedom, because they are what the whole
system rests on:

- Never buy speed by weakening read-only, exact-commit binding, or fail-closed
  behaviour. A fast wrong approval is worse than a slow one.
- Never buy speed by starving the reviewer of context. A reviewer that approves
  a change it did not understand is the same failure wearing a different hat.

## 2. What this application is

`u2giants/ai-devops` is Albert Hazan's toolkit repository. It is **100% Bash and
Markdown** — no app, no database, no container, no CI/CD pipeline. Do not go
looking for those and do not scaffold them.

What it contains, for this work:

- `bin/ai-grok-review` (718 lines) — drives xAI's **Grok** CLI as a read-only
  reviewer in named, resumable sessions.
- `bin/ai-glm` (1,750 lines) — drives **Z.ai GLM** via OpenCode. Has both a
  read-only review agent and a separate implementation agent.
- `bin/ai-kimi` (1,177 lines) — drives **Kimi Code CLI** the same way.
- `bin/ai-qwen` — **Qwen**. Excluded from new rotation (locked decision, §8).
- `bin/ai-codex-review`, `bin/ai-deepseek-agent` — other providers, out of scope
  for the first pass (§4).
- `bin/ai-review-sandbox` (184 lines) — turns a linked Git worktree into a
  self-contained snapshot a single-directory reviewer can read. Already built
  and working; **do not undo it** (see §5 and §7).
- `tests/test-ai-*.sh` — the existing Bash test suite, one file per command.

Toolkit home on a deployed host is always `/worksp/ai-devops` (never
`/opt/ai-devops`). Real config lives in `/etc/ai-devops/*.env`, never in the
repo. On Albert's Windows dev machine `al8960ofc` the clone is at
`C:\repos\ai-devops`.

**Who uses it:** AI coding sessions (Claude Code and Codex) on Albert's machines
call these wrappers to get an independent second opinion on a diff before it
merges. The heaviest consumer is the `u2giants/shared-db` orchestrator, which
requires an independent review before any database structure change reaches
production.

Branch policy: **main-only, no branches** for `u2giants` repos. This plan was
authored in a worktree on `claude/reviewer-system-repair-0dd3c6`; merge it to
`main` and work on `main` from then on.

## 3. What triggered this work

A 24-hour `u2giants/shared-db` orchestrator session on **2026-08-16/17** had
badly poor throughput. Albert asked why. The investigation is written up in
[`fix_reviewer_system.md`](fix_reviewer_system.md); the measured reviewer
failures were:

- Grok: 20 turns, **2,961,649 tokens**, $0.39, cancelled, **no verdict**.
- Grok: 20 turns, **2,727,014 tokens**, $0.30, cancelled, **no verdict**.
- Grok: 20 turns, **2,559,906 tokens**, $0.29, cancelled, **no verdict**.
- Kimi: waited the full **900 seconds**, then returned HTTP 403 — out of
  allowance. The 403 was knowable in the first second.
- GLM: died before reading any code on a linked worktree (Git control files
  outside its boundary — since fixed by `ai-review-sandbox`); separately
  returned empty assistant turns until the no-progress limit; separately
  attempted a **web search** during a purely local review.
- One Grok result was unusable because of a **quoting defect in the wrapper**,
  despite containing a valid finding.
- Agents hand-expanded short commit prefixes into **wrong full SHAs**, so
  durable evidence named a commit that was never reviewed.

**How to reproduce the core symptom** (do this before changing anything, so you
have a "before" measurement):

```bash
cd /c/repos/ai-devops && ai-grok-review new baseline-probe --prompt "Review the last commit on this repository and give a verdict."
```

Expect: many turns, several minutes, a large token count, and a meaningful
chance of no `## Verdict` section. Record elapsed time and `num_turns` from the
JSON result — that is your baseline for Step 8.

Not everything that session was the reviewers' fault, and the plan must not
pretend otherwise. GitHub had a **documented major outage** (HTTP 503/504 on
API, Actions, issues, PRs, Git). The safety gates correctly found real defects
that needed real fixes. Unrelated documentation merges kept advancing `main` and
invalidating exact-head evidence. And issue **#1113** (offline Item Master
taxonomy analysis — no database structure change at all) sat in `shared-db`
purely because its predecessor plan #1097 lived there, consuming a scarce agent.
Steps 6–9 address these; Steps 1–5 address the reviewer itself.

## 4. Scope

**In scope:**

- A new `bin/ai-review-packet` that builds a hashed, sealed evidence packet.
- Wrapper-owned commit identity in `ai-grok-review`, `ai-kimi`, `ai-glm`.
- A new `bin/ai-review-preflight` proving a provider is usable before assignment.
- New short default budgets and an early-provisional-verdict protocol.
- Failure-specific rotation guidance emitted by the wrappers.
- A new `bin/ai-review` front door and a JSONL performance ledger.
- A **staleness signal**: the review service reports whether evidence is current
  or stale. It reports; it does not decide what anyone does about it.
- Tests in `tests/` for every one of the above.
- The **global source-routing rule** (installed into every AI session) plus the
  #1097→#1113 regression test.

**Ownership split — added to `fix_reviewer_system.md` on 2026-08-17 in commit
`d51655a`, and it binds this plan.** `ai-devops` owns the reviewer wrappers, the
rules installed into every AI session, provider health checks, review packets,
and the source-level rule that stops non-structural work reaching shared-db.
`shared-db` owns **only** its own database lane scheduling, merge freeze,
exact-main sequencing, and production-promotion workflow — tracked separately,
in that repository. Do not implement any of shared-db's scheduling as generic
reviewer behaviour.

**NOT in this plan — do not do these:**

- ❌ Broadening reviewer permissions: no `Bash`, no `Edit`, no web search, no
  second directory. See §7 for why each was rejected.
- ❌ Changing `ai-review-sandbox`'s snapshot approach. It works.
- ❌ Bringing Qwen back into rotation.
- ❌ Wiring `ai-codex-review` or `ai-deepseek-agent` into the packet system in
  this pass. Design the packet so they can be added later; do not add them now.
- ❌ Fixing the seven real safety defects the gates found in shared-db (sequence
  lock transactions, production approval retry, etc.). Those are separate work
  in `u2giants/shared-db`.
- ❌ **Merge freezing, lane scheduling, exact-main sequencing, or
  production-promotion ordering.** Those belong to `shared-db` under its own
  tracker. This plan builds the staleness *signal* only. Deciding when to freeze
  merges, which database change goes first, and when promotion may begin is
  shared-db's call, not the reviewer's.
- ❌ Any CI/CD, container, or deployment scaffolding in this repo.
- ❌ Raising any turn or time ceiling as a fix for anything.

---

# Part 2 — What we already know

## 5. Current state of the code

**Nothing in this plan is built yet.** No wrapper behaviour, machine
configuration, credential, or installed binary has been changed. The only work
done so far is analysis: [`fix_reviewer_system.md`](fix_reviewer_system.md) on
`main` at commit `c361855` ("document delegated reviewer system failures"), plus
its handoff at
[`HANDOFF.d/2026-08-17T2115Z-al8960ofc-codex-reviewer-system-repair.md`](HANDOFF.d/2026-08-17T2115Z-al8960ofc-codex-reviewer-system-repair.md).

What already exists and works — read these before writing code:

| Thing | Where | State |
|---|---|---|
| Grok read-only permission set | [`bin/ai-grok-review:67`](bin/ai-grok-review#L67) | `--permission-mode default --allow Read --allow Grep --deny Edit --deny Bash --disable-web-search --no-memory`. **Frozen prefix** — the header at line 62 warns that changing it throws away the provider cache. |
| Grok default budgets | [`bin/ai-grok-review:70`](bin/ai-grok-review#L70) | `DEFAULT_MAX_TURNS=20`, `WAIT_TIMEOUT=900`. Both env-overridable (`AI_GROK_MAX_TURNS`, `AI_GROK_WAIT_TIMEOUT`). |
| Grok turn-exhaustion advice | [`bin/ai-grok-review:340`](bin/ai-grok-review#L340) | On `max_turns` it prints advice to re-run with **double** the turns. This is exactly the wrong reflex and Step 6 replaces it. |
| Grok stop-reason handling | [`bin/ai-grok-review:322`](bin/ai-grok-review#L322) | `handle_stop_reason()` — the right place to hook failure classification. Note both `end_turn` and `EndTurn` are terminal-success spellings. |
| GLM turn deadline | [`bin/ai-glm:69`](bin/ai-glm#L69) | `TIMEOUT=1800` for a **single turn**. |
| GLM structural read-only | `opencode-xdg/opencode/agent/glm-review.md` | Enforced by `bash: false` in the agent profile; asserted by the self-test at [`bin/ai-glm:1555`](bin/ai-glm#L1555). |
| GLM working-tree canary | [`bin/ai-glm:885`](bin/ai-glm#L885) | A review that changes the tree is a hard failure. |
| Kimi wait ceiling | [`bin/ai-kimi:82`](bin/ai-kimi#L82) | `WAIT_TIMEOUT=900`. |
| Kimi structural read-only | [`bin/ai-kimi:412`](bin/ai-kimi#L412) | Refuses to run without the read-only agent profile file. Header lines 54–67 record that **tool names are case-sensitive and fail silently** — a typo yields an agent with no tools that looks safe for the wrong reason. |
| Worktree snapshot | [`bin/ai-review-sandbox`](bin/ai-review-sandbox) | Complete and in use. `ensure` echoes the path unchanged in an ordinary clone, so it is always safe to call. All three wrappers already call it ([`ai-grok-review:134`](bin/ai-grok-review#L134), [`ai-glm:141`](bin/ai-glm#L141), [`ai-kimi:177`](bin/ai-kimi#L177)). |
| Test suite | `tests/test-ai-grok-review.sh`, `tests/test-ai-glm.sh`, `tests/test-ai-kimi.sh`, `tests/test-ai-review-sandbox.sh` | Existing pattern to copy for new tests. |

Untracked files present in the working copy that are **not yours** — do not
touch, do not commit: `.ai/`, `docs/claude-remote-control-hardening-v2.md`.

## 6. Key findings and root cause

### 6a. The single most important finding: **the boundary is not the problem — the missing shell is**

Albert asked directly: how much of the hand-feeding is caused by the
restrictions we put on reviewers — the one-folder boundary, the worktree
limitation? The answer, from reading the wrappers, is precise and it changes the
design:

**The folder boundary costs almost nothing.** Every reviewer already has `Read`
and `Grep` (Grok, [`ai-grok-review:67`](bin/ai-grok-review#L67)) or
`read, grep, glob, ls` (Kimi, [`ai-kimi:58`](bin/ai-kimi#L58)) across the
**entire repository directory**. It can open any file, search any pattern, read
`AGENTS.md`, read any policy doc, read the tests. It is not short of context.
And the worktree limitation was a real bug that is **already fixed** —
`ai-review-sandbox` hands over a self-contained clone with its own `.git/`
inside the boundary, carrying full history, uncommitted edits, and untracked
files ([`bin/ai-review-sandbox:93-147`](bin/ai-review-sandbox#L93)).

**The `--deny Bash` restriction costs everything.** Without a shell, a reviewer
cannot run `git diff`, `git log`, `git rev-parse`, or the test suite. So it
cannot answer the one question a review is actually about: *what changed?* It
has a haystack and no way to find the needle. Its only remaining tactic is to
read and grep its way toward an inferred diff — which is exactly the observed
behaviour: twenty turns, three million tokens, and no verdict.

So the hand-feeding is **not** the boundary being too tight. It is that we
removed the shell (correctly — a shell is arbitrary execution and would end
read-only review) and never replaced the handful of facts only a shell could
produce.

**Design consequence, and it is the heart of this plan:** the packet is
**additive, not a replacement**. Keep the whole repository readable exactly as
it is today. Add a small `.ai-review/` directory inside the snapshot that
carries the shell-derived facts the reviewer cannot compute. That is what makes
"not too much, not too little" achievable: the packet carries the **exact
answers to the shell-only questions**, and the repository remains available for
any background the reviewer decides it needs.

`fix_reviewer_system.md` says the reviewer "must not rediscover the basic
comparison". Read that as *must not have to*, not *must not be able to*. Do not
implement the packet as a sealed room.

### 6b. The verdict is requested last, so exhaustion yields nothing

All three wrappers require a final `## Verdict` section. If the model
investigates to its last turn, governance gets nothing and correctly refuses to
approve. The failure mode is structural: the most valuable output is scheduled
at the least reliable moment.

### 6c. Provider health is discovered after assignment, not before

Kimi's 403 (allowance exhausted) arrived at second 900. Nothing in any wrapper
proves authentication, allowance, snapshot readability, or result-file
creation before committing a durable review slot to a provider.

### 6d. Exceptional ceilings became routine budgets

20 turns / 900s (Grok), 900s (Kimi), 1800s per turn (GLM) were chosen for hard
cases and are now what every two-file diff gets. Worse, Grok's own advice on
exhaustion is to double the turns
([`ai-grok-review:351`](bin/ai-grok-review#L351)), which rewards failing to
prioritise the decision.

### 6e. Identity was typed by hand

Agents expanded short SHA prefixes into full SHAs by guessing. The reviewer may
have read the right code while the durable evidence named a different commit.
The wrapper is standing in the repository and can simply ask Git.

### 6f. Reviews started before the head was stable

Exact-head binding is correct and stays. The scheduling was wrong: final reviews
launched while prerequisite or unrelated merges were still likely, so `main`
advanced mid-review and the verdict expired. Recurred across #1072, #1089,
#1090, #1108, #1115.

**But the fix here is a signal, not a scheduler** (§4 ownership split). This
repo makes the review service say clearly whether its evidence is current or
stale. `shared-db` decides when to freeze its merges and in what order its
database changes go. Do not build a merge queue in a reviewer wrapper.

## 7. Approaches considered and REJECTED

Do not "improve" this plan by reaching for any of these. Each was considered and
each is a known dead end.

| Rejected approach | Why it is wrong |
|---|---|
| **Give reviewers `Bash`** (even "read-only" git commands) | A shell is arbitrary execution. There is no reliable allowlist — `git` alone can write, fetch, and run hooks and pagers. It would end structural read-only, which is the property the entire governance model rests on. The packet exists precisely to deliver the shell's *output* without the shell. |
| **Widen the boundary to two directories (worktree + main repo)** | None of the reviewer CLIs accept a second directory — this is stated in the `ai-review-sandbox` header and was verified against the wrappers. It is not a policy choice we can reverse; the tools do not have the flag. `ai-review-sandbox` already solves the underlying need. |
| **Point the reviewer at the raw linked worktree** | Observed to kill the run on 2026-08-17 before any code was read: a worktree's `.git` is a *file* pointing outside the boundary, so the first Git-adjacent read is refused. This is a standing global rule, not just a local one. |
| **Re-enable web search so the reviewer can look up policy** | Grok was observed using `web_fetch` during a purely local review under `--allow Read` alone, which is why `--disable-web-search` is in the frozen prefix ([`ai-grok-review:64`](bin/ai-grok-review#L64)). It leaks scope and adds latency. Policy documents are inside the repository and readable. |
| **Raise the turn or time ceiling when a review exhausts it** | Tried during the session. It multiplied cost and produced no verdicts. Turn exhaustion means the packet was too big or the ask too vague; shrink the input, never grow the budget. |
| **Accept partial output when a run dies** | Fail-closed is the rule. A provisional verdict (Step 5) is explicitly *not* an approval — it exists so the orchestrator can act, not so a dead run can approve a merge. |
| **Give the reviewer a prose brief instead of structured evidence** | This is the current state. It is what produced the three-million-token no-verdict runs. |
| **Seal the reviewer off with only the packet, repository hidden** | Rejected for the reason in §6a: the reviewer's read access is cheap and valuable. Removing it would fix the wrong problem and starve reviews of background. |
| **Rotate blindly to the next provider on any failure** | Different failures need different responses (Step 6). Blind rotation made another provider reread the same repository from scratch, doubling the delay. |
| **Bring Qwen back to add rotation capacity** | Locked decision; see §8. |

## 8. Design decisions already made

**LOCKED — do not relitigate:**

- **2026-08-17 — Read-only, exact-head, terminal-verdict, fail-closed rules all
  stay.** Speed comes only from removing waste.
- **2026-08-17 — Qwen stays out of new rotation.**
- **2026-08-17 — #1113 is application-owned offline Item Master work.** Its
  correct destination is a private `popcre/designflow-item-master` issue, and
  its private artifact must not be published or moved until a safe private
  handoff exists.
- **2026-08-17 — `ai-review-sandbox` is the sanctioned worktree answer.** Do not
  hand any reviewer a raw worktree path; do not add a second boundary directory.
- **2026-08-18 (this plan) — The packet is additive.** Full repository read/grep
  access is retained. See §6a.
- **2026-08-18 (this plan) — Packet content is capped by the rules in Step 1.**
  "Not too much, not too little" is enforced by a byte budget and a
  reference-don't-inline rule, not by author judgment each time.

**OPEN — the implementer decides, with criteria given:**

- The exact byte cap for an inlined patch before it is split (Step 1 suggests
  400 KB; tune it if a real review proves it wrong, and record why).
- Packet file format details (Markdown vs JSON per file) — Step 1 states a
  default; deviate only with a reason recorded in the file header.
- Whether the ledger lives in JSONL or a directory of JSON files (Step 7).
- The precise cooling period for a quarantined provider (Step 4 suggests 30
  minutes for exhausted allowance).

---

# Part 3 — How to build it

## 9. The plan

### Phase A — the packet (Steps 1–3). These land together or not at all.

---

#### Step 1 — Build `bin/ai-review-packet`

**What to create:** a new executable Bash script `bin/ai-review-packet`,
following the house style of `bin/ai-review-sandbox` (a long `# WHY THIS EXISTS`
header explaining the reasoning to a stranger, `set -euo pipefail`, a `VERSION`,
`die`/`warn` helpers, subcommands).

**Interface:**

```
ai-review-packet build <repo-root> <tag> [--base <ref>] [--tests <cmd>]   # print packet dir
ai-review-packet verify <packet-dir>      # re-derive the hash; exit 1 on mismatch
ai-review-packet remove <repo-root> <tag>
```

**Where the packet goes:** inside the review directory as `.ai-review/`, so it
sits within the reviewer's single-directory boundary and needs no second path.
When `ai-review-sandbox ensure` produced a snapshot, write into the snapshot.
When the repo is an ordinary clone, `.ai-review/` is written into the working
tree and **must** be added to `.git/info/exclude` (never to the tracked
`.gitignore`) and removed afterwards — the same discipline
`ai-review-sandbox` already uses at
[`bin/ai-review-sandbox:126`](bin/ai-review-sandbox#L126).

**Packet contents — this is the "not too much, not too little" specification.**
Every item below is a fact the reviewer **cannot** obtain without a shell. That
test is the inclusion rule; anything failing it stays out and is referenced by
path instead.

`.ai-review/MANIFEST.md` — the entry point, and the only file the prompt names:

1. **Repository identity** — repo name, the real path being represented (the
   worktree root, not the snapshot path), and a one-line statement of whether
   this is a snapshot.
2. **Exact base and head** — full 40-character SHAs, derived by the wrapper via
   `git -C <root> rev-parse` (Step 2). Include each commit's subject line and
   author date so a human reading the evidence later can recognise them.
3. **Changed-file list** — `git diff --name-status <base> <head>`, plus a
   separate list of files with uncommitted edits and a separate list of
   intentionally included untracked files (`git ls-files --others
   --exclude-standard`). Untracked files matter because brand-new files are
   usually the point of the change.
4. **Test results** — if `--tests <cmd>` was given, the exact command, its exit
   code, and its output tail. If it was not given, say so **explicitly**: "no
   tests were run for this packet". Silence must never be readable as a pass.
5. **The decision requested** — one sentence, supplied by the caller, e.g.
   "Approve or reject this change for production merge."
6. **Scope and exclusions** — what the reviewer is and is not being asked to
   judge, in plain sentences.
7. **Required verdict vocabulary** — the exact allowed verdict strings and the
   exact required section heading, so the wrapper's terminal-verdict check can
   never fail on formatting.
8. **Pointers, not copies** — a short list of relevant policy/dependency files
   **by path**, each with a one-line "read this if you need to check X". The
   reviewer has `Read`; inlining these is the "too much" failure mode and it is
   what buries the diff.
9. **An explicit invitation to read further** — a sentence telling the reviewer
   it may open any file in this directory to confirm a finding, and that the
   packet is a starting point, not a fence. Without this sentence a
   conscientious reviewer may believe reading beyond the packet is forbidden.

`.ai-review/patch.diff` — the unified diff from `git diff <base> <head>` plus
uncommitted changes (`git diff HEAD`), generated with `--binary`. If it exceeds
**400 KB**, do not truncate silently: write `patch.diff` truncated with a loud
trailing marker, write the full diff to `patch.full.diff` alongside it, and say
in `MANIFEST.md` that the patch was split and where the remainder is. A silent
truncation is a silent failure and is forbidden by standing rules.

`.ai-review/MANIFEST.sha256` — SHA-256 over the concatenation of every other
file in `.ai-review/`, in sorted filename order, written as
`<hash>  <sorted file list>`. `verify` re-derives and compares.

**Behaviour when done:** a reviewer opening `.ai-review/MANIFEST.md` learns in
one read what changed, between which commits, what was tested, what it is being
asked to decide, and where to look for more — while retaining full freedom to
read the rest of the repository.

**Dependencies:** none. Start here.

**Verification gate — you'll know it worked when:**

```bash
cd /c/repos/ai-devops && ai-review-packet build . probe --tests 'bash tests/test-ai-review-sandbox.sh' && ai-review-packet verify "$(ai-review-packet build . probe)"
```

prints a packet directory, `verify` exits 0, and `MANIFEST.md` contains two
full 40-character SHAs, a non-empty changed-file list, and an explicit test
result line. Then hand-edit one byte of `patch.diff` and confirm `verify`
exits 1.

**DONE 2026-08-18.** Built as [`bin/ai-review-packet`](bin/ai-review-packet)
with 57 tests in [`tests/test-ai-review-packet.sh`](tests/test-ai-review-packet.sh).
Three things were learned building it, and later steps should assume them:

- **File lists need the same cap as the patch.** The first real packet built
  against this repo was **33 KB**, almost all of it an unrelated untracked
  `.ai/` scratch directory — the changed file was buried under 200 lines of npm
  cache paths. Lists over `AI_REVIEW_LIST_MAX_LINES` (default 40) now spill to
  their own file with the true total announced. Same packet rebuilt: **8.4 KB**,
  nothing dropped. This is the "too much" failure mode arriving in practice, so
  do not raise the caps without a measured reason.
- **Base resolution must never be silent.** There is no universally right base,
  so the rule that won is written into the manifest in words. `--base` is
  honoured exactly; a bad `--base` is refused rather than quietly falling back.
- **A raw linked worktree is refused at the door**, with the
  `ai-review-sandbox ensure` command named in the error. Emitting a packet a
  reviewer would die trying to read is worse than refusing.

---

#### Step 2 — Move commit identity into the wrapper

**What to change:** in `bin/ai-grok-review`, `bin/ai-kimi`, and `bin/ai-glm`,
every place a review result records a commit. Base and head must come from
`git -C "$repo" rev-parse HEAD` and `git -C "$repo" rev-parse "$base"` **inside
the wrapper**. A caller-supplied full SHA is accepted only as an *assertion to
check*: if it does not match what Git says, fail loudly and refuse the review.
A caller-supplied short prefix is resolved by Git, never expanded by hand.

Record in each result's metadata JSON: `base`, `head`, `packet_sha256`,
`changed_files_sha256`, `provider`, `session_id`, `terminal_reason`, `verdict`.
Grok's metadata is already assembled around
[`bin/ai-grok-review:549`](bin/ai-grok-review#L549) — extend that structure
rather than inventing a parallel one.

**Behaviour when done:** it is impossible for durable evidence to name a commit
the reviewer did not read.

**Dependencies:** Step 1 (needs `packet_sha256`).

**Verification gate:** invoke a review passing a deliberately wrong full SHA;
the wrapper refuses before contacting the provider, with a message naming both
the supplied and the actual SHA. Covered by test `caller SHA cannot enter
evidence` (§10).

---

#### Step 3 — Wire the packet into the three wrappers

**What to change:** in each wrapper, where the review boundary is currently
resolved — `review_boundary()` at
[`bin/ai-grok-review:534`](bin/ai-grok-review#L534) and the equivalent in
`ai-kimi` ([`bin/ai-kimi:177`](bin/ai-kimi#L177)) and `ai-glm`
([`bin/ai-glm:141`](bin/ai-glm#L141)) — call `ai-review-packet build` after
`ai-review-sandbox ensure`, and prepend to the review prompt a short fixed
preamble:

> Your evidence packet is at `.ai-review/MANIFEST.md` in this directory. Read it
> first. It contains the exact commits under review, the changed files, the full
> patch, and what you are being asked to decide. You may read any other file in
> this directory to confirm a finding — the packet is your starting point, not a
> boundary. Do not attempt to reconstruct the diff yourself; it is already in
> `.ai-review/patch.diff`.

Resolve `ai-review-packet` the same defensive way the wrappers already resolve
`ai-review-sandbox` (script-relative path first, then `PATH`) — see
[`bin/ai-grok-review:134`](bin/ai-grok-review#L134).

**Do not touch** `GROK_PERMS` at [`bin/ai-grok-review:67`](bin/ai-grok-review#L67),
`bash: false` in the GLM review agent profile, or Kimi's read-only agent
profile. Widening any of them fails this plan's purpose.

**Behaviour when done:** the reviewer's first turn reads the manifest and its
second turn is already about the code, not about locating the code.

**Dependencies:** Steps 1 and 2.

**Verification gate:** run the §3 baseline probe again with the packet in place.
Compare `num_turns` and elapsed time against the recorded baseline. Expect a
large drop. Record both numbers in the handoff — this is the evidence that the
central premise is correct. If turns do **not** drop, stop and re-read §6a
before continuing; something about the preamble or packet placement is wrong.

---

### Phase B — budgets, health, and failure handling (Steps 4–7).

---

#### Step 4 — `bin/ai-review-preflight` plus quarantine

**What to create:** a new script that, for a named provider, proves in **seconds**:
authentication is valid; allowance is not exhausted; the review directory is
readable; base and head exist; the manifest is readable; any local service the
provider needs is healthy (GLM has a local permission endpoint —
[`bin/ai-glm:380`](bin/ai-glm#L380)); and a result file can be created.

Quarantine state lives under `$HOME/.local/state/ai-devops/review-quarantine/`,
one file per provider holding the failure class and an expiry timestamp.
Suggested cooling period for exhausted allowance: **30 minutes** (open decision).

**Rules:** a preflight failure takes seconds, must **not** count as an attempted
review, and must not consume a rotation slot. A quarantined provider is skipped
without being contacted.

**Dependencies:** independent of Steps 1–3; can be built in parallel.

**Verification gate:** with a deliberately invalid Kimi credential in the
environment, `ai-review-preflight kimi <dir>` fails in **under 10 seconds** with
a message naming the failure class. Confirm the wall-clock with `time`.

---

#### Step 5 — Short ordinary budgets and the early verdict protocol

**What to change:** the defaults at
[`bin/ai-grok-review:70`](bin/ai-grok-review#L70),
[`bin/ai-kimi:82`](bin/ai-kimi#L82), and
[`bin/ai-glm:69`](bin/ai-glm#L69), plus a new review-class concept.

| Review class | Turns | Wall time | On limit |
|---|---:|---:|---|
| Small exact-head diff (**the new default**) | 6 | 5 min | verdict, or an explicit no-verdict. No automatic continuation. |
| Medium / security diff | 10 | 8 min | same |
| Explicit architecture investigation | 20 | 15 min | opt-in only, never automatic |

The existing long ceilings survive **only** as the explicitly requested
exceptional mode. The env overrides (`AI_GROK_MAX_TURNS`, etc.) stay so an
operator can still reach them deliberately.

**Early verdict protocol** — add to the prompt preamble a required three-part
shape: a **provisional verdict** stated early, then findings with evidence, then
the **final verdict**. At the halfway point of the turn budget the wrapper
captures whatever provisional result exists. State plainly in the wrapper's own
output that a provisional verdict **cannot approve a change** — it exists so the
orchestrator can narrow scope or start fixing instead of waiting blind.

**Behaviour when done:** a small review that dies at turn 6 still leaves the
orchestrator something actionable, and still cannot approve anything.

**Dependencies:** Step 3.

**Verification gate:** a two-file fixture diff returns a verdict within 6 turns
and 5 minutes on Grok. Kill a run at its halfway point and confirm a provisional
result was captured and is labelled non-approving.

---

#### Step 6 — Failure-specific rotation

**What to change:** `handle_stop_reason()` at
[`bin/ai-grok-review:322`](bin/ai-grok-review#L322) and its equivalents. Replace
the "double the turns" advice at
[`bin/ai-grok-review:351`](bin/ai-grok-review#L351).

| Failure class | Response |
|---|---|
| Exhausted allowance | Quarantine the provider (Step 4). |
| Broken snapshot | Rebuild once via `ai-review-sandbox`, then quarantine. |
| Empty assistant turns | Fail in 2–3 minutes. |
| Turn exhaustion | **Shrink the packet.** Never increase turns. |
| Service outage (HTTP 5xx) | Bounded retry, then wait. Distinguish from provider failure — GitHub's outage was misread as reviewer failure. |
| Substantive finding / blocker | **Stop and fix.** Never rotate to shop for a friendlier verdict. |

**Dependencies:** Steps 4 and 5.

**Verification gate:** force each class with a fixture and confirm the emitted
guidance matches the table. Specifically confirm turn exhaustion never prints a
larger `--max-turns`.

---

#### Step 7 — `bin/ai-review` front door and the performance ledger

**What to create:** one `ai-review` command that callers use instead of picking
a provider wrapper by hand. It runs preflight, picks the fastest healthy
provider for the review class from the ledger, builds the packet, runs the
review, classifies the outcome, and appends a ledger row.

Ledger row fields: timestamp, repo, base, head, packet hash, provider, review
class, elapsed seconds, turns, tokens, cost, verdict, accepted findings, failure
class, and whether the evidence went stale. **Token and cost must be allowed to
be absent** — not every provider reports them, and a missing value must not
break the row.

Provider wrappers stay below this interface and remain directly callable.
Agents must stop hand-assembling prompts, clones, turn limits, and terminal-state
interpretations.

**Dependencies:** Steps 1–6.

**Verification gate:** three consecutive `ai-review` runs append three
well-formed ledger rows; one run with a quarantined provider shows it was
skipped without being contacted.

---

#### Step 8 — The 30-review trial

Run at least **30 real reviews** through `ai-review` and measure against the
success criteria in `fix_reviewer_system.md`:

- 90% of small reviews finish within 5 minutes;
- 95% return a usable verdict;
- no small review exceeds 10 turns;
- no exhausted provider receives a durable assignment;
- no SHA is manually transcribed;
- under 5% of verdicts go stale before use;
- provider failures identified within 2 minutes.

**Verification gate:** a written report committed to `docs/` citing the ledger
file, with per-criterion pass/fail. If a criterion fails, the plan is not done —
tune and re-run rather than lowering the bar.

---

### Phase C — source routing (Step 9). Independent; may run in parallel.

---

#### Step 9 — the global source-routing rule and the #1113 regression

**What belongs in THIS repo** (per the ownership split in §4): the rule text
itself, installed into every AI session. That means the global instructions
template `templates/system/` and the `shared-db-orchestrator` /
`shared-db-change` skills under `skills/shared/`, plus the regression fixture in
`tests/`. This is the source-level rule that stops non-structural work being
sent to shared-db in the first place.

**What does NOT belong here:** issue templates, lane scheduling, and orchestrator
runtime enforcement inside `u2giants/shared-db`. Those are that repository's
work under its own tracker. Write the rule; do not reach into shared-db.

Every new or successor issue must answer, from scratch: *does this work change
the shape of the shared database?*

- **Yes** → shared-db structural issue, exact objects named, migration-author lane.
- **No, application data or offline analysis** → owning application repo/session.
- **Outside-sourced curated Master Data** → the existing controlled exception.
- **Planning or repo maintenance** → non-migration route; no shared-db
  implementation agent.

Rule text to encode: require a machine-readable scope block on every actionable
shared-db issue; **reclassify successors rather than inheriting the predecessor's
route**; refuse shared-db implementation unless the route is structural or the
Master Data exception; require exact database objects before a structural claim;
audit unclassified issues separately; on misrouting, stop, preserve private
artifacts, and hand off to the correct private repository.

**Verification gate:** a regression fixture reproducing #1097 → #1113 — a
successor issue inheriting a shared-db predecessor, whose own work touches no
database structure — is **rejected** from shared-db execution and consumes no
shared-db agent or lane.

---

## 10. Tests required

Add to `tests/`, following the existing `tests/test-ai-*.sh` pattern. New file
`tests/test-ai-review-packet.sh`; extend the three existing wrapper test files.
Name each test after the behaviour it proves.

1. `two-file diff returns a verdict within 6 turns and 5 minutes`
2. `packet manifest contains base, head, file list, patch, and test result`
3. `packet omits inlined policy files and references them by path instead`
4. `reviewer retains read access to files outside the packet` — asserts §6a is
   not accidentally undone by a future change
5. `oversized patch is split, never silently truncated`
6. `manifest hash mismatch fails verification`
7. `missing base or head fails before provider assignment`
8. `caller SHA transcription cannot enter evidence`
9. `exhausted allowance is skipped in seconds`
10. `linked worktrees produce complete self-contained snapshots with refs`
11. `empty turns terminate at the short no-progress limit`
12. `turn exhaustion recommends a smaller packet, never extra turns`
13. `a substantive blocker stops rotation`
14. `main advancement marks evidence stale before preview or merge`
15. `a non-database successor like #1113 is rejected from shared-db execution`
16. `metrics distinguish provider failure, GitHub outage, code blocker, and stale head`
17. `packet directory is excluded from git and removed after the review`

**Must stay green** — run the whole existing suite before every commit:

```bash
cd /c/repos/ai-devops && for t in tests/test-ai-*.sh; do echo "== $t"; bash "$t" || echo "FAILED: $t"; done
```

Also run the wrappers' own self-tests, which assert the read-only tool
boundaries — these are the canaries that catch an accidental permission
widening:

```bash
cd /c/repos/ai-devops && ai-glm selftest && ai-kimi doctor && ai-grok-review doctor
```

## 11. Constraints, standing rules, and gotchas

**Standing rules in force** (do not assume you have read them elsewhere):

- **No band-aids.** Root-cause, permanent, fewest-moving-parts fixes only. A
  temporary workaround must be labelled TEMPORARY in your `HANDOFF.d/` file with
  the permanent fix described.
- **No silent failures.** Every fallback alerts loudly. Truncation, a skipped
  test, an absent packet: all must say so. When you find one silent failure,
  sweep the codebase for the same pattern.
- **Nothing hard-coded** that should be configurable — budgets, model names,
  paths, cooling periods all get env overrides, following the existing
  `${AI_GROK_MAX_TURNS:-20}` idiom.
- **Add unit tests for the code you create.** §10 is the minimum, not the cap.
- **Every destructive action must be recoverable before you take it.** Never
  `git add -A` over another session's files; never delete a directory you do not
  own. `ai-review-packet remove` must refuse to delete anything lacking its own
  marker file — copy the `is_managed()` guard at
  [`bin/ai-review-sandbox:71`](bin/ai-review-sandbox#L71).
- **Commit identity:** run `git var GIT_COMMITTER_IDENT` before the first commit.
  It must read `Albert Hazan <u2giants@users.noreply.github.com>`. If not, fix it
  with `bin/ai-git-identity` **before** committing. Git invents an identity from
  the OS account rather than stopping, and that has already put 231
  wrong-identity commits into shared branches.
- **New skills go in `skills/shared/`** by default (installs to both Claude and
  Codex). Only put a skill in `skills/claude/` or `skills/codex/` if it is
  genuinely client-specific.
- Do not mention or use Fable in this repo.
- Do not edit the root `HANDOFF.md`; it is a static pointer to `HANDOFF.d/`.

**Gotchas specific to this work:**

- **Kimi tool names are case-sensitive and fail silently.** A typo in the agent
  profile's `tools:` list yields an agent with *no* tools, which reports "I have
  no working file-reading tool" — and the read-only canary passes for the wrong
  reason. See [`bin/ai-kimi:64`](bin/ai-kimi#L64).
- **Grok's frozen permission prefix is a cache key.** Changing it discards the
  provider cache mid-workstream. See [`bin/ai-grok-review:62`](bin/ai-grok-review#L62).
- **Grok has two spellings of terminal success:** `end_turn` and `EndTurn`.
  Handle both. See [`bin/ai-grok-review:41`](bin/ai-grok-review#L41).
- **`grok doctor` is a terminal diagnostic, not an auth check.** It checks
  terminal, clipboard, and colour support. Do not use it in preflight — that
  mistake produced a false "not authenticated" conclusion on 2026-08-05.
  See [`bin/ai-grok-review:43`](bin/ai-grok-review#L43).
- **Grok can return before its output file is complete.** The wrapper's wait
  loop exists for this; completion is proven from the JSON, never from process
  exit. See [`bin/ai-grok-review:49`](bin/ai-grok-review#L49).
- **`flock` does not exist in Git Bash.** The wrappers use a portable mutex
  ([`bin/ai-glm:170`](bin/ai-glm#L170)); reuse it, do not introduce `flock`.
- **`.ps1` files in this repo must be pure ASCII.**
- **A quoting defect once made a valid Grok finding unusable.** Quote every
  variable expansion in new code and run `shellcheck` on each new script.
- **Windows paths:** the Bash tool here is Git Bash. Use `/c/repos/ai-devops`,
  forward slashes, and `$VAR`.

## 12. Access and environment

- **Repo:** `C:\repos\ai-devops` on machine `al8960ofc` (Windows 11, user
  `ahazan2`, PowerShell 7 primary, Git Bash available). This plan was authored
  in the worktree `C:\repos\ai-devops-worktrees\github-spec-kit-evaluation-35279d`
  on branch `claude/reviewer-system-repair-0dd3c6`.
- **Target branch:** `main` (repo policy is main-only).
- **CLIs kept authenticated on this machine:** `gh` (as `u2giants`), `gcloud`,
  `az`, `supabase`, `vercel`, `op` (when toggled on). **Verify with a real call
  before ever claiming a capability is missing.**
- **Provider credentials:** in 1Password, vault `vibe_coding` **only**. The GLM
  key is in the item's *"api key"* field, **not** the `credential` field — an
  empty key once fork-bombed the launcher. The 1Password service-account token
  is in `op_service_account_token`, not `credential`. **Serialise all 1Password
  reads** — never fan out `op read`, `op run`, or 1Password MCP calls in
  parallel; a per-launch storm once locked the shared service account.
  **Never paste secret values into files, docs, or commits.**
- **Reading the provider docs:** read the header comment of each wrapper (they
  are long and carry hard-won findings) and `docs/glm-opencode.md` §5 before
  touching GLM or Windows setup.
- **No new secrets are needed for this work.**
- **How to run it locally:** the wrappers are plain Bash on `PATH` after
  `install.sh` / `bin/ai-install-skills`. There is no server to start, no
  container, and no deploy step.

---

# Part 4 — Landing it

## 13. Definition of done, risks, and open questions

**Definition of done — every box ticked:**

- [ ] `bin/ai-review-packet`, `bin/ai-review-preflight`, `bin/ai-review` exist,
      are executable, pass `shellcheck`, and carry a `# WHY THIS EXISTS` header.
- [ ] The three wrappers build and consume packets; none of their read-only
      boundaries were widened (proved by `ai-glm selftest`, `ai-kimi doctor`,
      `ai-grok-review doctor`).
- [ ] All 17 tests in §10 exist and pass; the whole existing `tests/` suite is
      still green.
- [ ] Baseline vs. post-packet turn count and elapsed time are recorded (Step 3).
- [ ] The 30-review trial report is committed to `docs/` and every success
      criterion passes.
- [ ] `git var GIT_COMMITTER_IDENT` verified before the first commit.
- [ ] Work committed **and pushed**; commit SHA reported.
- [ ] `AGENTS.md` router updated to link this plan and the new commands;
      `docs/` updated where reviewer behaviour is described.
- [ ] This plan's STATUS table updated with real artifact evidence per row.
- [ ] The `HANDOFF.d/` file for this work updated or deleted once proven done.
- [ ] `fix_reviewer_system.md` status line updated from "analysis complete" to
      reflect what shipped; issue #34 closed with the evidence.

There is no CI and no deployment in this repo, so "CI green / deployed SHA
verified" reduces to: the test suite passes locally and the commit is pushed.

**Risks and rollback:**

| Risk | Mitigation / rollback |
|---|---|
| The packet does not actually cut turns | Step 3's gate catches this before the rest is built. If turns do not drop, re-read §6a — the premise, not the plan, is what to re-examine. |
| Short budgets cause accidental approvals | Fail-closed is unchanged: no verdict means no approval, and a provisional verdict is explicitly non-approving (Step 5). |
| Packets grow into repository dumps | The inclusion rule (§ Step 1: "a fact the reviewer cannot obtain without a shell") plus the 400 KB split rule. Test 3 enforces reference-don't-inline. |
| A future change quietly widens permissions | Test 4 plus the three wrapper self-tests are the canaries. |
| Changing Grok's frozen prefix discards its cache | Do not change `GROK_PERMS`. The preamble goes in the prompt, not the flags. |
| Everything is behind one new `ai-review` front door | Provider wrappers stay directly callable, so the front door is never a single point of failure. |

**Open questions:**

- Final budget numbers are provisional until the 30-review trial validates them.
- The right set of "pointer" files in a packet will vary by repository. Start
  with `AGENTS.md` plus any policy doc the changed paths obviously implicate,
  and let the trial refine it.
- Provider metrics must tolerate absent token/cost data; confirm which providers
  actually report it during the trial.
- #1113's private artifact must be handed only to the private DesignFlow Item
  Master workflow, and must not be published or moved before a safe private
  handoff exists.

---

## Mandatory self-audit

**1. Could a brand-new AI session with no project knowledge and no context from
this conversation execute this plan to perfection, without asking anything?**

Yes. §2 defines the repo, stack, machine, and every command involved from
scratch. §5 tables the exact current state with `file:line` references for each
constant and function to be changed. §9 names target files, functions, and line
numbers per step, each with a runnable verification gate. §11 carries the
non-obvious traps (Kimi's silent case-sensitivity, Grok's dual success
spellings, `grok doctor` not being an auth check, no `flock` in Git Bash) that
would otherwise each cost a session. §12 gives the machine, branch, credential
locations, and the serialised-1Password rule. Gap found during the audit and
fixed: the first draft did not say where `.ai-review/` goes in an ordinary
clone versus a snapshot, nor that it must be excluded from Git — Step 1 now
specifies both, and test 17 enforces it.

**2. Does the plan carry every piece of background, nuance, and reasoning
currently held — including what was ruled out and why?**

Yes. §3 preserves the measured evidence (exact token counts, the 900-second
403, the wrong-SHA class of failure) and the causes that were *not* the
reviewers' fault, so the implementer does not over-attribute. §6 gives root
causes with evidence. §7 tables nine rejected approaches with the specific
reason each fails — including the two most tempting, giving reviewers a shell
and widening the boundary. §8 separates locked from open decisions so the
implementer knows where its judgment is wanted. Gap found and fixed: the first
draft implied the packet replaced repository access, which contradicts §6a and
would have starved reviews of context; §6a, Step 1 item 9, and test 4 now make
the additive design explicit and enforce it.

**3. Is the ultimate goal stated clearly enough that the implementer could make
a correct judgment call if a step turns out to be wrong?**

Yes. §1 states the goal in plain business English before any technical wording,
states the "if a step conflicts with the goal, the goal wins" instruction, and
adds the two guardrails that bound that freedom — never trade away safety, and
never trade away the reviewer's context. Step 3's gate is written so that a
failure there sends the implementer back to the premise in §6a rather than
forward into building the rest on a false footing.
