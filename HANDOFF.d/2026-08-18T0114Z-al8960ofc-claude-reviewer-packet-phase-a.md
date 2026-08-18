---
issue: 34
status: OPEN
owner: claude/reviewer-packet-phase-a
---

# HANDOFF — reviewer evidence packets: Phase A shipped, speed gate NOT met (2026-08-18 01:14Z, al8960ofc/claude)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put **all** of these to Albert in ONE message, before starting work.

### Blocking — Step 4 should not start until this is answered

1. **The speed fix did not work. Do we keep going?**
   We paid for a live test comparing the old way against the new evidence packet
   on the same code. The reviewer took **8 turns either way**. It finished 18%
   faster and 10% cheaper, which is real but small. The plan was built on the
   idea that packets would cut the work dramatically. They did not.
   **Recommendation: pause the speed work (Steps 4–8) and first spend ~$1 on five
   live reviews to find out whether the original 15-minute/no-answer failure even
   still happens.** The tool has been upgraded since those failures were recorded
   (see §5), so we may be fixing a problem that is already gone. Blocks Step 4
   and everything after it.

### A wrong guess is recoverable, but rework is wasteful

2. **Should the reviewer's time limit be cut to 5 minutes / 6 turns (Step 5)?**
   **Recommendation: not yet.** Real work took 8 turns. A 6-turn limit would cut
   reviews off before they answer — which is the exact failure we are trying to
   remove. Decide after the measurement in item 1.
3. **Is a 10% cost saving on its own worth finishing this project?**
   Phase A already banks that saving and is live. Steps 4–9 are a further several
   sessions of work. **Recommendation: yes, but only Steps 4, 6 and 9** (dead
   provider detected in seconds, sensible failure handling, and the routing rule
   that stops another #1113) — those stand on their own merits and do not depend
   on the unproven speed claim.

### Not part of this work, and nobody is on it

4. **The reviewer just found four real defects in code I had already committed
   and had 57 passing tests behind.** They are all fixed now. But it means our
   own test suites can pass while the code is wrong. **Recommendation: make a
   delegated review a standing step before anything merges in this repo, not an
   optional extra.** Needs Albert's ruling because it slows every change slightly.
5. **Two other handoff files in `HANDOFF.d/` are stale** and should be retired by
   whoever owns them (see §3). Not mine to delete.

### Already settled — do NOT re-ask

- 2026-08-17 — read-only, exact-commit, fail-closed rules stay; speed comes only
  from removing waste.
- 2026-08-17 — Qwen stays out of rotation.
- 2026-08-17 — #1113 is application-owned offline Item Master work; its private
  artifact goes only to a private `popcre/designflow-item-master` issue.
- 2026-08-17 — `ai-review-sandbox` is the sanctioned answer for worktrees. Never
  hand a reviewer a raw worktree path; never add a second boundary directory.
- 2026-08-17 (commit `d51655a`) — ownership split: `ai-devops` owns wrappers,
  installed rules, health checks, packets and the source-routing rule; `shared-db`
  owns its own lane scheduling, merge freeze and promotion sequencing.
- 2026-08-18 — the packet is **additive**: reviewers keep full read of the repo.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's toolkit repository. **100% Bash and
Markdown — no app, no database, no container, no CI/CD.** Do not go looking for
those and do not scaffold them.

It installs and drives the "delegated reviewers": other AI coding tools that read
a diff and give an independent verdict before code merges. The commands are
`bin/ai-grok-review` (xAI Grok), `bin/ai-glm` (Z.ai GLM via OpenCode),
`bin/ai-kimi` (Kimi Code), `bin/ai-qwen` (excluded from rotation), plus
`bin/ai-review-sandbox` (makes a linked Git worktree reviewable) and — new this
session — `bin/ai-review-packet`.

The heaviest consumer is the `u2giants/shared-db` orchestrator, which requires an
independent review before any database structure change reaches production.

Clone on this machine: `C:\repos\ai-devops`, branch `main`. Repo policy is
**main-only, no branches**. On a deployed host the toolkit home is always
`/worksp/ai-devops` (never `/opt/ai-devops`); real config lives in
`/etc/ai-devops/*.env` and never in the repo.

## 2. What we set out to do this session, and why

A 24-hour `u2giants/shared-db` session on 2026-08-16/17 had terrible throughput:
small code reviews took 15+ minutes and often returned **no answer at all**,
after burning ~3 million tokens. The analysis is
[`fix_reviewer_system.md`](../fix_reviewer_system.md), tracked as
[issue #34](https://github.com/u2giants/ai-devops/issues/34).

Albert asked two things: write an implementation plan, and answer *how much of
the problem is caused by the restrictions we place on reviewers* (one folder,
one worktree). Then he asked to start implementing, and then to verify the
improvement with a real paid run.

**The answer to his question shaped the whole design.** The folder boundary costs
almost nothing — reviewers already have full read and search over the entire
repository directory, and the worktree problem was already fixed by
`ai-review-sandbox`. What costs everything is `--deny Bash`: with no shell a
reviewer cannot run `git diff`, so it cannot find out *what changed* — the only
question a review is about. It gets a haystack and no way to find the needle.
We must not give it a shell (that would end read-only review), so instead the
wrapper now precomputes the shell-derived facts into a small `.ai-review/` folder.

## 3. Current state — what is true right now

**Everything below is committed AND pushed to `main` on `u2giants/ai-devops`.**
Nothing is left uncommitted. There is no CI and no deployment in this repo, so
"shipped" means: tests green locally, committed, pushed.

| Commit | What it is |
|---|---|
| `9a6fd2c` | the implementation plan |
| `1e0b939` | plan aligned to the ownership split |
| `d192de6` | merge of the plan branch into `main` |
| `e724444` | **Step 1** — `bin/ai-review-packet` + 57 tests |
| `5ac2d4c` | **Steps 2–3** — packets wired into all three wrappers |
| `a983dac` | **four defects fixed** + the failed gate recorded |

Working files:

- [`plan_reviewer-system-repair.md`](../plan_reviewer-system-repair.md) — **the
  build spec. Read its STATUS table first.** Steps 1–3 done, 4–9 open.
- [`fix_reviewer_system.md`](../fix_reviewer_system.md) — the original analysis.
- [`bin/ai-review-packet`](../bin/ai-review-packet) — new, ~470 lines.
- [`tests/test-ai-review-packet.sh`](../tests/test-ai-review-packet.sh) — 67 tests.

**Verified how:** every suite was run to completion on this machine, fully
offline (stub binaries, no provider calls, no cost):

| Suite | Result |
|---|---|
| `bash tests/test-ai-review-packet.sh` | 67 passed, 0 failed |
| `bash tests/test-ai-grok-review.sh` | 102 passed, 0 failed |
| `bash tests/test-ai-kimi.sh` | 134 passed, 0 failed |
| `bash tests/test-ai-glm.sh` | 221 passed, 0 failed |

Plus two **real paid Grok runs** (~$0.20 total) — see §5.

**Not started:** Steps 4–9. A fresh session starts at **Step 4**.

**Other files in `HANDOFF.d/` (do NOT edit or delete them — not yours):**

- `2026-08-17T2115Z-al8960ofc-codex-reviewer-system-repair.md` — the predecessor
  for THIS workstream (issue 34). Its analysis is done and its "exact next steps"
  1–3 are now complete; steps 4–9 live in the plan. **It is safe to retire once
  Step 9 lands**, but its steps are not all finished, so I left it.
- `2026-08-17T2300Z-al8960ofc-claude-reviewer-packet-plan.md` — my own earlier
  file from this same session, fully superseded by this one. **I deleted it** in
  the same commit as this file.
- `2026-08-14T2015Z-...-housekeeping-visibility.md`,
  `2026-08-16T0303Z-...-housekeeping-plan-corrections.md`,
  `2026-08-17T0017Z-...-kimi-windows-execution-plan.md` — unrelated workstreams,
  untouched. Owner item 5 in §0 flags them for their owners.

## 4. Everything we tried that did NOT work

**This is the most important section. Read it before proposing anything.**

- **The central premise did not hold up.** We predicted the packet would collapse
  the reviewer's turn count. Measured live: **8 turns with the packet, 8 without.**
  Do not build on "packets made reviews cheap" — they made them ~10% cheaper.
- **Giving reviewers a shell — rejected, do not revisit.** A shell is arbitrary
  execution and would end structural read-only review, which the entire governance
  model rests on. There is no safe allowlist; `git` alone can write, fetch, and run
  hooks and pagers.
- **Widening the boundary to two directories — impossible, not a policy choice.**
  None of the reviewer CLIs accept a second directory. `ai-review-sandbox` already
  solves the underlying need.
- **Pointing a reviewer at a raw linked worktree — kills the run.** A worktree's
  `.git` is a *file* pointing outside the boundary, so the first Git-adjacent read
  is refused and the run dies before reading any code (observed 2026-08-17).
- **Re-enabling web search — rejected.** Grok was observed using `web_fetch`
  during a purely local review, which is why `--disable-web-search` is in the
  frozen permission prefix.
- **Raising the turn ceiling when a review exhausts it — rejected.** Tried during
  the original session; it multiplied cost and produced no verdicts. Turn
  exhaustion means the input was too big or the ask too vague.
- **My first packet was 33 KB and useless.** Built against this repo, an unrelated
  untracked `.ai/` scratch directory produced 200 lines of npm-cache paths that
  buried the single changed file. Fixed with a 40-line list cap that spills to a
  separate file and announces the true total. Same packet rebuilt: 8.4 KB.
- **My first test assertion was wrong, not the code.** `meta records a full
  40-char base sha` failed because I wrote a malformed shell test, and I nearly
  went hunting in the wrapper. The value was correct all along. If a single test
  fails oddly, suspect the assertion first.
- **`resolve_base` originally ran in a command substitution** — a subshell — so
  the "how the base was chosen" note was silently lost. Never call it that way.
- **`git rev-parse --git-path` returns a path relative to the repo**, so appending
  the packet exclusion from the caller's directory wrote to the wrong file and the
  packet showed up as a change. Resolve it against the repo root.
- **Four defects shipped past 57 passing tests** — see §5. The tests all deleted
  the packet before rebuilding, so the rebuild path was never exercised.
- **A GLM test asserted a literal line of code** (`boundary="$(review_boundary
  ...)"`). Refactoring broke it even though the guarantee held. It now asserts the
  behaviour plus seven new properties.
- **Do NOT fix any reviewer problem** by broadening filesystem/shell/web
  permissions, accepting partial output, or weakening exact-commit binding.

## 5. Root causes and key findings

### 5a. The finding that shaped the design

The hand-feeding is caused by **`--deny Bash`**, not by the folder boundary.
Evidence: [`bin/ai-grok-review:67`](../bin/ai-grok-review#L67) grants
`--allow Read --allow Grep` over the whole directory;
[`bin/ai-kimi:58`](../bin/ai-kimi#L58) grants `read, grep, glob, ls`. They can
read anything. They cannot run `git diff`.

**Consequence, and it must not be undone: the packet is ADDITIVE.** Full repo
read stays. The manifest explicitly tells the reviewer it may open any other
file. Guarded by the test `reviewer_retains_access_outside_the_packet`. A future
session that turns the packet into a sealed room will have fixed the wrong
problem and starved reviews of context.

### 5b. The live A/B — the gate FAILED

Same commit (`e724444`), same question, same model (`grok-4.6`), same
permissions, one disposable clone, run back to back:

| | Prose brief (old) | Evidence packet (new) |
|---|---:|---:|
| Wall time | 408 s | 333 s (−18%) |
| **Turns** | **8** | **8 (no change)** |
| Tokens | 595,346 | 562,356 (−6%) |
| Cost | $0.1047 | $0.0944 (−10%) |
| Verdict returned | yes | yes |

**Neither run reproduced the failure this project exists to fix.** Both returned
a verdict in 8 turns. The catastrophic runs (20 turns, ~3M tokens, no verdict)
were measured on **Grok CLI 0.2.118**; this machine now runs **1.0.3** with
`grok-4.6` (`bin/ai-grok-review doctor` prints the version). Part of the original
problem may already be fixed upstream. The old prose brief was also a *fair* one,
so the comparison is generous to the new design.

### 5c. What the paid run bought us: four real defects

Grok **rejected** `bin/ai-review-packet` and was right three times; the run
exposed a fourth in the wrapper. All fixed in `a983dac`, one regression test each:

1. **A rebuild could seal a mixture of two runs.** The old packet was removed with
   the error suppressed and the failure survivable, so run-specific files
   (`patch.full.diff`, `*-files.txt`) could persist into the next packet, enter the
   hash, and `verify` would bless the mixture. Now refused loudly; a failed delete
   is fatal.
2. **Patch and file lists could describe different trees.** The patch was captured
   before `--tests` ran and the lists after, so a test with side effects sealed a
   tree that never existed. Tests now run first, evidence is captured together,
   and a tree that moved is announced in the manifest.
3. **`git diff` failures were swallowed** (`|| true`), so an empty patch could be
   sealed as "nothing changed". Now fatal.
4. **`extract_answer` discarded every finding above `## Verdict`.** Grok produced
   42 lines of evidenced defects and the caller saw the word "REJECT". The verdict
   still leads; the reasoning is now kept below it.

### 5d. Other findings worth real time

- `grok doctor` is a **terminal** diagnostic (checks colour/clipboard), NOT an
  auth check. Use `grok models`. This caused a false "not authenticated"
  conclusion on 2026-08-05.
- Grok has two terminal-success spellings: `end_turn` and `EndTurn`.
- Kimi agent-profile tool names are **case-sensitive and fail silently** — a typo
  yields an agent with no tools that looks safe for the wrong reason.
- `GROK_PERMS` is a **provider cache key**; changing it discards the cache.
- No `flock` in Git Bash; the wrappers use a portable mutex.
- The packet is added to `.git/info/exclude`, never `.gitignore`, so it can never
  trip the read-only working-tree canaries. Those canaries were re-verified green.

## 6. Exact next steps

**Before anything: put §0 to Albert in one message and wait.** Item 1 blocks.

Then follow the STATUS table in
[`plan_reviewer-system-repair.md`](../plan_reviewer-system-repair.md). Read its
**DRIFT RECORDED 2026-08-18** block first — it lists what Phase A changed for
each later step.

1. **Measure before building (new, from the failed gate).** Run five live reviews
   through `ai-grok-review` on real small diffs and record turns, wall time,
   tokens and whether a verdict came back.
   *You'll know it worked when:* you can state the real turn distribution, and
   whether the 15-minute/no-verdict failure still occurs at all, from a file you
   can open — not from memory.
2. **Step 4 — `bin/ai-review-preflight` + quarantine.** Prove in seconds:
   auth, allowance, directory readable, base/head present, result file writable.
   Reuse `ai-review-packet build` (offline, fail-fast) rather than writing a
   second implementation. Quarantine state under
   `$HOME/.local/state/ai-devops/review-quarantine/`; suggested cooling 30 min.
   *You'll know it worked when:* with a deliberately invalid Kimi credential,
   `ai-review-preflight kimi <dir>` fails in **under 10 seconds** naming the
   failure class. Time it.
3. **Step 5 — budgets. DO NOT start until step 1 above is done and Albert has
   answered §0 item 2.** A 6-turn ceiling on 8-turn work manufactures the exact
   failure we are removing.
4. **Step 6 — failure-specific rotation.** Replace the "double the turns" advice
   at [`bin/ai-grok-review:351`](../bin/ai-grok-review#L351). Note
   `extract_answer`'s contract changed — do not assume the old verdict-only shape.
   *You'll know it worked when:* forcing each failure class prints the matching
   guidance, and turn exhaustion never prints a larger `--max-turns`.
5. **Step 7 — `ai-review` front door + ledger.** The wrappers already accept
   `--base`, `--tests`, `--decision`, `--assert-head` and already record `base`,
   `head`, `packet_sha256`. Pass them through; read those fields. Token/cost must
   be allowed to be absent.
   *You'll know it worked when:* three runs append three well-formed ledger rows
   and a quarantined provider is skipped without being contacted.
6. **Step 8 — the 30-review trial.** Re-derive the success criteria against the
   current tool version first (§5b).
7. **Step 9 — the global source-routing rule + the #1097→#1113 regression.**
   Independent of 1–8; can run in parallel in another session. The rule text goes
   in `templates/system/` and `skills/shared/`; do **not** reach into `shared-db`.

**At the end of your phase: re-read every remaining step through Step 9, report
any drift, and update the plan's STATUS row with an artifact you can open.**

## 7. Constraints and gotchas in force

- **No band-aids.** Root-cause fixes only; label any unavoidable workaround
  TEMPORARY in your own `HANDOFF.d/` file with the permanent fix described.
- **No silent failures.** Truncation, a skipped test, a missing packet — all must
  say so loudly. When you find one, sweep for the same pattern.
- **Nothing hard-coded** that should be configurable; follow the existing
  `${AI_GROK_MAX_TURNS:-20}` env-override idiom.
- **Every destructive action must be recoverable before you take it.** Never
  `git add -A` over another session's files. Copy the `is_managed()` guard shape
  before deleting anything.
- **Commit identity:** run `git var GIT_COMMITTER_IDENT` before your first commit.
  It must read `Albert Hazan <u2giants@users.noreply.github.com>`. Fix with
  `bin/ai-git-identity` BEFORE committing — afterwards means rewriting history.
- **Main-only.** No branches in this repo.
- **New skills go in `skills/shared/`** by default (installs to Claude AND Codex).
- **Do not mention or use Fable** in this repo.
- **Never rewrite the root `HANDOFF.md`**; never edit another session's
  `HANDOFF.d/` file.
- **Concurrency is real.** `main` moved 4 times during this session from other
  machines. Always `git fetch` and fast-forward before committing; stash your work
  first if needed.
- **`.ps1` files in this repo must be pure ASCII.**
- **Quote every variable expansion** — a quoting defect once made a valid Grok
  finding unusable. Run `shellcheck` if available (it is NOT installed here).
- **Windows:** the Bash tool is Git Bash. Use `/c/repos/ai-devops`, forward
  slashes, `$VAR`. The test suites take **10–20 minutes each** — run them in the
  background and wait; do not assume they hung.

## 8. Access and environment

- **Machine:** `al8960ofc` (Windows 11, user `ahazan2`, PowerShell 7 primary,
  Git Bash available). Repo at `C:\repos\ai-devops`, branch `main`.
- **Authenticated CLIs:** `gh` (as `u2giants`), `gcloud`, `az`, `supabase`,
  `vercel`, `op` (when toggled on). **Verify with a real call before claiming a
  capability is missing.**
- **Grok:** binary at `/c/Users/ahazan2/.grok/bin/grok`, version 1.0.3, model
  `grok-4.6`, auth confirmed working this session. `bin/ai-grok-review doctor`
  is free (no billable probe).
- **Secrets:** 1Password vault `vibe_coding` **only**. The GLM key is in the
  item's *"api key"* field, NOT `credential` (an empty key once fork-bombed the
  launcher). The service-account token is in `op_service_account_token`, not
  `credential`. **Serialise all 1Password reads** — never fan out `op read`,
  `op run`, or 1Password MCP calls in parallel; a per-launch storm once locked the
  shared account. **Never paste secret values into files, docs, or commits.**
- **No new secrets are needed** for Steps 4–9.
- **How to run things:** the wrappers are plain Bash on `PATH`. No server, no
  container, no deploy step.
- **Live runs cost money.** The two this session cost ~$0.20 total. Get Albert's
  approval before a batch.

## 9. Open questions and risks

- **2026-08-18 — The speed premise is unconfirmed.** Recorded as a failed gate in
  the plan, not quietly dropped. The next session must not cite it as proven.
- **2026-08-18 — We may be fixing a solved problem.** The tool upgraded from
  0.2.118 to 1.0.3 between the original failures and now. Step 1 of §6 exists to
  settle this.
- **Risk: short budgets could manufacture the failure.** Real work took 8 turns;
  the planned default is 6. Fail-closed means a cut-off review approves nothing —
  but it also delivers nothing, which was the original complaint.
- **Risk: our tests can pass while the code is wrong.** 57 green tests hid four
  real defects. Regression tests were added, but the general lesson (§0 item 4)
  needs Albert's ruling.
- **Risk: packets could drift back into repo dumps.** The inclusion rule ("only
  what a shell would be needed to get"), the 400 KB patch split and the 40-line
  list cap are what hold that line. Test 3 enforces reference-don't-inline.
- **2026-08-18 — decided:** the packet is additive; full repo read is retained.
  Do not reverse without re-reading §5a.
- **Open:** the right "pointer" files per packet will vary by repository. Start
  with `AGENTS.md` plus whatever policy doc the changed paths implicate.
- **Open:** which providers actually report token/cost. The ledger must tolerate
  absence.

## Mandatory self-audit

**1. Could a brand-new developer with no project knowledge and no session context
pick up where I left off and not skip a beat?**
Yes. §1 defines the repo, stack, machine and every command from scratch, including
that there is no app/CI here. §3 lists every commit SHA, every test result with the
exact command, and what is not started. §6 gives numbered steps each with a
"you'll know it worked when" gate. §7 carries the traps (Kimi's silent
case-sensitivity, `grok doctor` not being an auth check, no `flock`, 10–20 minute
suites). §8 gives machine, branch, credential locations and the serialised-1Password
rule. Gap found and fixed during the audit: the first draft did not say the test
suites take 10–20 minutes, which would make a newcomer think they had hung — §7 now
says so.

**2. Could they continue as effectively as I can right now?**
Yes. §5 carries every non-obvious discovery with `file:line` evidence, including
the one that shaped the design (§5a) and the four defects with their causes (§5c).
§4 carries eleven dead ends including three of my own mistakes this session
(33 KB packet, malformed assertion, subshell losing the base rule) so they are not
repeated. Gap found and fixed: the first draft omitted that `main` moved four times
mid-session from other machines — §7 now warns to fetch before committing.

**3. Is every relevant detail present for flawless execution?**
Yes. Background §1–2, goal §2, current state §3 with commit/push status per item,
failures §4, root causes §5, exact next steps §6, constraints §7, environment §8,
risks and dated decisions §9. Measurements are given as a table with both sides, not
as a bare claim. Gap found and fixed: the drift affecting later phases was only in
the plan; §6 now points at the plan's DRIFT block explicitly so it cannot be missed.

**4. If Albert read ONLY section 0, would he see every decision he needs —
including ones outside this workstream?**
Yes, checked the hard way by walking §1–§9 line by line. Extracted: the failed gate
(§5b) → §0 item 1; the 6-turn risk (§9) → §0 item 2; whether a 10% saving justifies
the remaining work (§3 scope) → §0 item 3; the out-of-scope finding that our tests
passed while the code was wrong (§5c) → §0 item 4 — **this is the one that would
otherwise have stayed filed as a "finding" and never been raised**; the stale
handoff files owned by others (§3) → §0 item 5. Settled rulings are listed so they
are not re-asked. §0 instructs the next session to put all five in one message.
