# Three active reviewers, three different ways of losing the result — 2026-08-20

**Status:** open. Root causes identified, none fixed as of 2026-08-20T03:30Z.
**Affects:** `ai-glm`, `ai-muse`, `ai-grok-review` — i.e. **every reviewer in the
active rotation** after `u2giants/shared-db#1290` (merged `cef67d6`).
**Reported from:** shared-db orchestrator session `claude-20260820-030000Z`, during
two real production promotions.

---

## Summary

On 2026-08-20 all three active reviewers produced **correct, high-quality reviews**
and all three **misreported them to the caller** — each in a different direction:

| Reviewer | What the caller saw | What was actually true |
|---|---|---|
| **glm-5.3** | `status: active`, `last_activity_at` frozen at session-create time, no output | Working correctly the whole time; a full review in progress |
| **muse-spark-1.2-contributor** | **Zero bytes** on stdout; session absent from `ai-muse list` | A complete 10 KB review with `VERDICT: APPROVE` sitting on disk |
| **grok-4.6** | `warning: not writing a review file: '.ai/reviews' is not git-ignored` | `.ai/reviews/` **is** git-ignored; the check is wrong |

**Grok saves nothing and prints. Muse prints nothing and saves. GLM does both but
reports itself as idle while working.** There is no single check that covers all
three, which is exactly why the shared-db standing rule is *read the raw provider
stream*, never *check the wrapper's output*.

That rule was load-bearing **three separate times in one session**. Trusting any
wrapper's own summary would have produced two false reviewer failures and one review
of the wrong commit — and all three would have looked entirely normal in the record.

**The cost is not hypothetical.** This class of defect already caused glm-5.3 to be
paused for two days as an unreliable provider (2026-08-18 → 2026-08-20), on a
diagnosis that was wrong. With the rotation down to three names, one false failure
costs a third of review capacity.

---

## 1. `ai-glm` — `last_activity_at` cannot move during a turn

**Reviewer issue:** `20260820T032815Z-edge-dev-glm-543270`
**Tracked as:** `u2giants/shared-db#1298`

### Symptom

`ai-glm show <name>` reported, for the entire duration of a long review:

```
"last_activity_at": "2026-08-20T02:39:44Z"    <- identical to created_at, never moved
"status": "active"
```

with nothing on stdout. Every signal matched the documented *"session that never
produced a turn"* failure. **On that evidence the review was aborted** — and
`ai-glm transcript` then showed it had been working correctly the whole time, had
read all 364 lines of the migration under review, and had already made findings
nobody had asked it for. It had not yet reached a verdict, so all of it was lost.

### Root cause — this is structural, not a race

In `bin/ai-glm`, both `cmd_new` and `cmd_ask` do this, in this order:

```sh
send_prompt "$sid" "$pf"                        # send the brief
msg="$(await_turn "$sid" "$name" review ...)"   # BLOCKS for the entire model turn
...
write_meta "$mp" "$(jq --arg ts "$(date -u +%FT%TZ)" ... '.last_activity_at=$ts | ...')"
```

`last_activity_at` is written **only after `await_turn` returns**. During the whole
turn — precisely when a caller queries it to ask *"is this alive?"* — it still holds
the value written at session creation, or at the end of the **previous** turn.

**The field cannot move while the model is working.** It is a *last completed turn*
timestamp carrying a name that promises liveness, so a long healthy turn is
indistinguishable from a session that never started, using the wrapper's own status
command.

Note this is a **distinct fault** from the 2026-08-18 stopped-`opencode`-server case:
here `ai-glm doctor` passed every check and the session still looked dead.

### Honest apportionment

The caller's share is real and is recorded in the issue: a field with no documented
semantics was treated as authoritative, and a **destructive action (abort) was taken
on it without first reading the transcript**, which the standing evidence rule
already required. The harness invited the misreading; the caller should still not
have acted on it.

Both halves are true. **The harness half is the one that can be fixed once, for
everybody.**

### Suggested fix, ranked

1. **Update `last_activity_at` on every streamed provider event**, not only after the
   turn completes. Then *seconds since last activity* becomes a real liveness signal
   and the field matches its name.
2. If (1) is impractical because `await_turn` blocks: have **`show` derive the
   transcript's own last-event time and event count** and print them, so `show` alone
   answers *"is it working?"* without the caller needing to know to run `transcript`.
3. **Cheapest interim, worth doing regardless:** rename the field to
   `last_turn_completed_at` and have `show` print
   `liveness: run 'ai-glm transcript <name>'; this field does not move during a turn.`
   **A correctly named field would have prevented this incident outright.**

### How to verify a fix

Start a review with a deliberately long brief. While it is still running, from another
shell run `ai-glm show <name>` twice, 60 seconds apart. **The fix works when the two
calls report different liveness values.** Today they report identical ones.

---

## 2. `ai-muse` — returns zero bytes while the review sits on disk

**Reviewer issue:** `20260820T032847Z-edge-dev-muse-545005`

### Symptom

```
ai-muse new promo-sesame-212002 --prompt-file /tmp/brief-sesame.md
```

- **stdout: zero bytes.** Not a warning, not an error, not a partial line.
- the session did **not appear in `ai-muse list`** at all.
- `ai-muse transcript promo-sesame-212002` →
  `error: no session 'promo-sesame-212002' for caller 'codex' in this repository`.

On every observable signal, a dead reviewer.

**The review was on disk the entire time:**
`.ai/reviews/muse-promo-sesame-212002-20260820T024859Z-458758-8681.md`, **10,362
bytes** — a complete seven-part review, a coverage statement declaring all 2,629 lines
of the migration read across three sequential passes, findings with severities and
exact line numbers, and `VERDICT: APPROVE`.

It was substantively **the best review of the session.** It drew the distinction the
promotion turned on — that the expensive row counts in the migration sit *inside
function bodies* and are stored source at apply time, not executed code — which is why
`20260819212002` could be applied to production where `20260819151536` could not. It is
now the recorded review evidence for `shared-db#1289`, and that migration is in
production.

### Second defect, found while recovering it: caller mismatch on the read path

`ai-muse new` created the session under one caller, but `list` / `transcript` resolved
caller `codex` by default **in the same directory**, so the session could not be found
by the name that had just been used to create it.

A minimal probe (`ai-muse new musecheck --prompt "Reply with exactly: MUSE ALIVE"`)
returned promptly and correctly — which is what proved the **provider was healthy** and
the fault is in session bookkeeping and result delivery.

### Suggested fix, ranked

1. **Never exit silently.** If the turn produced text, print it. If the wrapper cannot
   detect a verdict, print the text **anyway** under an explicit banner —
   `verdict not detected — full model output follows` — with a distinct non-zero exit
   status. **Silence must never be a possible outcome of a completed turn.**
2. **Always print the saved report path, on every outcome including failure.** One
   line, `report: <path>`, turns an unrecoverable-looking failure into a recoverable
   one and costs nothing.
3. **Fix verdict detection** to accept the plain final-line form `VERDICT: APPROVE`
   anchored at line start — which is what the shared-db briefs mandate and what Muse
   actually emitted.
4. **Make `list`/`transcript`/`show` resolve the same caller that created the
   session**, or make lookup caller-agnostic with caller shown as a column. *A session
   you just created must be findable by name.*

### How to verify a fix

Run a Muse review whose brief mandates a final `VERDICT: APPROVE` line. The fix works
when **(a)** stdout is non-empty, **(b)** it names the saved report path, and **(c)**
`ai-muse list` shows the session under the same name immediately after creation.

---

## 3. `ai-grok-review` — the false `.ai/reviews is not git-ignored` warning

**Already documented** in [`reviewer-wrapper-gitignore-false-warning.md`](reviewer-wrapper-gitignore-false-warning.md).
This session confirmed it still fires and **pinned the exact mechanism**, which that
document did not yet state.

### The precise cause — measured, not inferred

`git check-ignore` **never matches a `dir/` pattern against a directory path.** You
must probe a path *inside* the directory. Measured in `u2giants/shared-db`, where
`.gitignore` contains `.ai/reviews/`:

```sh
$ rm -rf .ai                       # directory does not exist at all

$ git check-ignore -q .ai/reviews/         ; echo $?
1                                          # <-- the wrapper's check: FALSE NEGATIVE

$ git check-ignore -q .ai/reviews/probe.md ; echo $?
0                                          # <-- correct answer

$ git check-ignore -v .ai/reviews/probe.md
.gitignore:48:.ai/reviews/	.ai/reviews/probe.md
```

**Existence is irrelevant** — the third command resolves the rule correctly with `.ai`
absent, and creates nothing. The fault is purely that a *directory path* is being
tested against a *directory pattern*.

> **Correction.** An earlier note by this session (on `shared-db#1296`) said the check
> fails "because the directory does not exist yet" and implied the fix is to create it
> first. **That is wrong, and the wrong fix** — creating a directory as a side effect
> of a read-only check is worse than the bug. The existing
> `reviewer-wrapper-gitignore-false-warning.md` already prescribes the correct fix
> (probe a file path inside the directory); this measurement **confirms that fix works
> with the directory absent**, which is the case that matters.

### Consequence

Grok reviews leave **no durable artifact** — output exists only in the caller's stdout.
If the caller's process dies, the review is gone, with no saved file to fall back on.
That is the same failure mode that made a Kimi review unrecoverable on 2026-08-19.

---

## What ties all three together

Each wrapper has a **result-delivery contract that is implicit**, and each violates a
different half of it. The contract should be written down and made identical across
wrappers:

1. **A completed turn always produces output on stdout.** Silence is never a valid
   outcome. If a verdict cannot be parsed, emit the raw text under a banner.
2. **A completed turn always names its saved artifact path**, on success and on
   failure alike.
3. **Liveness is queryable while a turn is in flight**, and the field that answers it
   is named for what it means.
4. **A session created by name is findable by that name**, immediately, from the same
   directory.
5. **A guard that suppresses the expensive artifact must be right.** When a check
   disagrees with Git itself, the check is wrong — and the correct failure mode is to
   write the review somewhere else and say so loudly, never to discard it.

A conformance test asserting all five against every wrapper would have caught all
three of these defects before they cost a production session.

---

## ⚠️ Coordination note for whoever implements the fixes

**At the time of writing, `C:/repos/ai-devops` has substantial uncommitted work on
`main` from another session**, touching `bin/ai-gemini`, `bin/ai-grok-review`,
`bin/ai-kimi`, `bin/ai-muse` (staged *and* modified), `bin/ai-qwen`,
`tests/test-ai-kimi.sh`, `tests/test-ai-muse.sh` and more.

**This document deliberately changes no wrapper**, precisely to avoid clobbering that
work. `bin/ai-glm` happened to be untouched, but the fixes above belong together and
should land as one coordinated change once that session's work is committed.

Check `git status` in `ai-devops` before editing any wrapper.

---

## Related records

- Reviewer issue `20260820T032815Z-edge-dev-glm-543270` — the GLM liveness case.
- Reviewer issue `20260820T032847Z-edge-dev-muse-545005` — the Muse silent-return case.
- Reviewer issue `20260820T004602Z-edge-dev-kimi-k3-385556` — Kimi, 2026-08-19.
- Reviewer issue `20260820T013646Z-edge-dev-muse-spark-1.2-contributor-394599` — the
  earlier Muse verdict-detection observation.
- [`reviewer-wrapper-gitignore-false-warning.md`](reviewer-wrapper-gitignore-false-warning.md) — the Grok/Kimi/Gemini artifact-suppression bug.
- [`reviewer-trial-2026-08-19-glm-gemini-muse.md`](reviewer-trial-2026-08-19-glm-gemini-muse.md) — the head-to-head trial behind the roster change.
- `u2giants/shared-db#1298` — the GLM liveness signal.
- `u2giants/shared-db#1296` — evidence-packet isolation, and the corrected git-ignore mechanism above.
- `u2giants/shared-db#1297` — `replaceFailedReviewer` can strand a replacement.
- `u2giants/shared-db#1290` / `cef67d6` — the roster change that made all three of these the *active* rotation.
- `u2giants/shared-db#1220` — reviewer wrappers exiting 0 with no verdict.
- `ai-devops#45` — wrappers self-checking their own local dependencies.
