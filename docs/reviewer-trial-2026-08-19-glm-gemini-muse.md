# Reviewer trial, 2026-08-19: GLM restored, Gemini and Muse trialled

**Owner instruction (Albert Hazan, in chat, 2026-08-19):** *"Stop Kimi. Restore GLM.
And start using Gemini and Muse and tell me (and document in ai-devops) if they're
helpful."*

This document is that report. It was produced during the `shared-db` orchestrator
session `claude-20260819-092000Z` (marker `u2giants/shared-db#1229`) on machine
`edge-dev`.

## The one-line answer

**GLM and Muse are both usable. Gemini, on this evidence, is not.**

| Reviewer | Usable? | What happened |
|---|---|---|
| **GLM 5.3** (`ai-glm`) | **Yes** | Full 10 KB review with a coverage statement, saved to file, honest about its own limits |
| **Muse Spark 1.2 Contributor** (`ai-muse`) | **Yes, with a wrapper defect** | Complete seven-point review ending in `VERDICT: APPROVE`; the wrapper failed to detect its own verdict but **saved the output**, so nothing was lost |
| **Gemini 3.7 Flash High** (`ai-gemini`) | **No** | Two attempts, no usable review. First: `no usable Gemini verdict`. Second: bare `PASS` with an **empty report** |

## Why this trial happened

`kimi-k3` failed **11 times against 5 successes in a single session**, in three
distinct modes — findings discarded above the verdict heading, usage-limit
exhaustion, and nine consecutive six-second `exit 127` deaths. Recorded in full as
reviewer issue `20260820T004602Z-edge-dev-kimi-k3-385556` and on
`u2giants/shared-db#1220`.

With `qwen-3.8-max` and `glm-5.3` already paused, stopping Kimi would have left
`grok-4.6` as the only active reviewer. That is not a theoretical weakness: **twice
in that session a second reviewer overturned the first reviewer's conclusion**, and
on one of those the second reviewer refuted an author's design rationale using the
author's own test fixture. A rotation of one is not a rotation.

## Method

All three reviewed **the same pull request, from the same self-contained copy, on the
same brief**, independently. The subject was `u2giants/shared-db#1282` — the
supersession of a migration that could not apply to production because its own verify
block hit the statement timeout (`#1280`). A real, non-trivial review with a genuine
correctness question in it: whether a `create or replace` on a live view had been
carried forward faithfully or would silently revert two earlier licensors'
classification.

Gemini and Muse were run **alongside** the governed review, never in place of it. An
unproven reviewer does not go on the gate for a production-bound migration.

## GLM 5.3 — restored, and the pause was a false diagnosis

**The pause was wrong, and the reason matters.** `glm-5.3` was paused on 2026-08-18
after three consecutive `provider_unavailable` failures (sequences 161, 164, 167),
each creating a session that never produced a turn. That reads as an unreliable
provider.

It was not. `ai-glm doctor` showed every check passing except one:

```
FAIL  health endpoint answers
1 check(s) FAILED.
```

**Its local `opencode` server was simply not running.** Running
`opencode-glm-launch` started it; `ai-glm doctor` then passed every check, and GLM
produced a good review on the first attempt.

The lesson worth keeping: *"provider unavailable"* was read as a statement about the
model when it was a statement about a stopped local service on this machine. The
existing pause note in `scripts/manage-migration-author-lanes.mjs` says to *"restore
it by deleting 'glm-5.3' from this list once the provider answers a probe"* — that
instruction was right, and probing first is what found this.

**Review quality.** Full review, saved to
`.ai/reviews/glm-trial-1282-glm-20260820T012255Z.md` (10,405 bytes), with a coverage
statement naming what it read in full, in part, and by grep. Verdict `APPROVE`, no
findings.

Its best trait was declaring its own limits without being asked:

> Not done (no shell): re-measuring the 14 ms, byte-hashing the two bodies (visual
> full-text comparison instead), and running the contract tests — the packet records
> no test run, so behavioural evidence rests on the CI lane I verified exists and
> covers the file.

That is exactly the discipline `AGENTS.md` now requires of reviewers ("require the
reviewer to say what it covered — not merely what it concluded"), volunteered rather
than extracted.

Reported usage: 1,578 input, 2,640 output, 1,564 reasoning, 138,496 cache read.

## Muse Spark 1.2 Contributor — good reviewer, broken verdict detection

**The model performed well. The wrapper mislabelled its work as a failure.**

`ai-muse` printed, in 231 bytes and with exit code 0:

```
ai-muse: error: Muse stopped without a usable verdict. Incomplete output saved: …/muse-incomplete-20260820T012150Z.md
```

The saved file is 9,843 bytes and its final two lines are:

```
Findings: No findings. The PR correctly supersedes `19151536` with a catalogue-only
verification, faithfully carries forward both bodies without reverting Sega/Peanuts,
is safe for both preview reinstall and production first-install, and leaves no
house-rule or scope violations.

VERDICT: APPROVE
```

The verdict was present, correctly formatted, and the last line of the output. The
wrapper wrote a header over it reading *"Muse did not produce the required final
verdict. This is not a review result."* That header is false.

**Likely cause:** the captured stream is full of interleaved ANSI escape sequences
(`ESC[0m`, `ESC[90m`), because the wrapper captures the interactive renderer rather
than a plain-text stream. Stripping them with
`sed 's/\x1b\[[0-9;]*m//g'` made the verdict trivially greppable. Two things to check
in the matcher: whether it strips ANSI before searching, and whether it inspects the
whole output or only a bounded tail.

Recorded in full as reviewer issue
`20260820T013646Z-edge-dev-muse-spark-1.2-contributor-394599`.

**Review quality was genuinely high** — comparable to Grok's best work in the same
session. It answered all seven numbered questions with file and line citations,
including a per-mutation spot-check naming the exact catalogue predicate that would
fail for each of the 13 mutations, and a house-rule audit with line numbers covering
the numeric-cast rules, the JSON-null and numeric-string traps, exception handlers,
warning-only failures, and pinned literals. It also correctly honoured the *"known
and accepted, do not re-raise"* section of the brief rather than padding its findings
with it.

**Severity relative to Kimi — the distinction that matters.** `ai-muse` **saves the
output**; the review was fully recoverable. `ai-kimi` discarded its findings with no
artifact anywhere — not in `ai-kimi show`, not in `ai-kimi transcript`, and not in the
session JSON, which holds metadata only. **Muse mislabels a good review; Kimi destroys
one.** A nuisance with a workaround is not the same as data loss, and these two should
not be lumped together when deciding what to pause.

That said, the impact is real and should not be dismissed. Under the rule added to
`AGENTS.md` on 2026-08-19 — *"an orchestrator must never accept a bare verdict as
review evidence"*, *"silence is never approval"* — a wrapper reporting no usable
verdict must be treated as `verdict=none` and the reviewer replaced through the
governed rotation. Followed literally, a correct `APPROVE` is discarded and a full
replacement cycle is spent. And the artifact is named `muse-incomplete-*.md` and
headed *"This is not a review result"*, so a future reader has every reason to skip
it. **The most misleading part of this defect is not the missed detection; it is the
confident false header written over correct work.**

## Gemini 3.7 Flash High — not usable on this evidence

Two attempts on the identical brief and copy:

| Attempt | Result | Bytes |
|---|---|---|
| 1 | `ai-gemini: error: no usable Gemini verdict` | 65 |
| 2 | `PASS session=trial-1282-gemini-b report=` — a bare pass with an **empty report** | 251 |

`ai-gemini doctor` passes (`agy=1.1.15 model=gemini-3.7-flash-high
disposable-copy=yes containment=--sandbox`), so the installation is sound. It is not
producing findings.

Attempt 2 is the more concerning of the two, because a bare `PASS` with no content is
precisely the shape the `AGENTS.md` rule names: an approval with no coverage
statement, which must be treated as a provider failure rather than a clean review. A
caller reading only the exit status would have recorded an approval.

**Recommendation: do not add `gemini` to `ACTIVE_REVIEWERS` yet.** Retry the trial
after someone has looked at why the report comes back empty. Two attempts is thin
evidence for a permanent judgement, and this document should not be read as one.

## A defect shared across FOUR wrappers

Every wrapper prints, on essentially every run:

```
warning: not writing a review file: '.ai/reviews' is not git-ignored in <path>
(it would be committable). Add '.ai/reviews/' to .gitignore.
```

**The warning is false.** Line 36 of `u2giants/shared-db`'s `.gitignore` is literally
`.ai/reviews/`, and `git status --porcelain` after a run is empty. The check is wrong,
not the repository. Confirmed in `ai-kimi`, `ai-grok-review` and `ai-gemini`.

Its consequence is worse than cosmetic: the wrapper **silently skips writing the
review file** — the very artifact that made Muse's lost verdict recoverable and whose
absence made Kimi's unrecoverable. The ignore test should use `git check-ignore`
rather than whatever string comparison it currently performs.

## Grok 4.6, measured over the same session for comparison

19 successes, 1 failure. The failure was sequence 209, cancelled at its 20-turn limit
with no verdict on an oversized four-migration promotion brief (2,706,144 tokens,
$0.41); splitting the brief in two and passing `--max-turns 40` fixed it completely,
so that is arguably a brief-sizing error by the caller rather than a wrapper defect.

**One recurring nuisance:** `ai-grok-review` omitted the `## Verdict` section
entirely on sequences 205, 223, 225, 227, 229, 231, 233 and 235 — eight times — so
the harness printed only its progress narration and discarded both findings and
verdict. Always recoverable in one extra turn by asking the same named session to
re-emit everything inside a single `## Verdict` block, and the recovered content was
always complete. Cost is one extra round trip each time, plus the risk that a caller
reads the narration as the review.

**A separate environmental limitation worth recording:** `gh issue view` is **blocked
inside the `ai-grok-review` sandbox**. On sequence 229 the reviewer could not read the
issue under review and said so plainly, working from the brief and the migration
header instead. It reached a correct verdict, but any brief that assumes the reviewer
can fetch its own issue will silently lose that context. Briefs should carry what the
reviewer needs.

## Recommended roster change

In `u2giants/shared-db`, `scripts/manage-migration-author-lanes.mjs`:

- **Add `kimi-k3` to `RETIRED_REVIEWERS`** (pause, not deletion — its historical
  verdicts must stay readable, and one lookup there is not null-guarded).
- **Remove `glm-5.3` from `RETIRED_REVIEWERS`** (restore; it answers a probe).
- **Do not add `gemini` yet.**
- **Muse is a candidate** once its verdict detection is fixed, or immediately if the
  caller is willing to read the saved artifact on every "incomplete" result. Note it
  is not currently in the `REVIEWERS` registry at all, so adding it is a registry
  change and not merely an un-pause.

That change is not made in this document; it belongs in a reviewed `shared-db` pull
request.

## Housekeeping note

`C:/repos/ai-devops` currently holds an untracked file `MUSE_CANARY=blue-heron-39`
(90 bytes, dated 2026-08-18 17:23), containing a path to a temporary
`muse-review-*` directory. It appears to be the artifact of a deliberate containment
test of Muse by an earlier session, not of this trial. Left in place — it is another
session's file — but recorded here because it leaves this repository not
handoff-clean.
