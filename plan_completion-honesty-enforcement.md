# Implementation plan — stop AI sessions from declaring work complete while authorized work is still pending

Open handoff for this plan:
[`HANDOFF.d/2026-08-26T1127Z-edge-dev-claude-completion-honesty.md`](HANDOFF.d/2026-08-26T1127Z-edge-dev-claude-completion-honesty.md)

Created 2026-08-26 by a Claude session on `edge-dev`, branch
`claude/fix-misleading-instructions-f5be3d`. **No implementation work has been
done.** Every STATUS row below is open.

---

## STATUS

| # | Step | State | Evidence (artifact, never a bare number) |
|---|------|-------|------------------------------------------|
| 0 | Confirm the diagnosis on the machine that failed | ⬜ open | — |
| 1 | Write the canonical Closeout Contract text | ⬜ open | — |
| 2 | Land it identically in both client globals | ⬜ open | — |
| 3 | Teach `context-audit.py` the new safety + parity category | ⬜ open | — |
| 4 | Extend `tests/test-context-audit.ps1` fixtures | ⬜ open | — |
| 5 | Build the Claude `Stop` hook `bin/ai-completion-check-hook` | ⬜ open | — |
| 6 | Installer + `--check` support for the hook | ⬜ open | — |
| 7 | Unit test the hook (`tests/test-ai-completion-check-hook.sh`) | ⬜ open | — |
| 8 | Codex compensating control (no Stop hook exists) | ⬜ open | — |
| 9 | Behavioral eval harness `tools/completion-eval/` | ⬜ open | — |
| 10 | Run the eval before/after on Claude and Codex, record scores | ⬜ open | — |
| 11 | Reconcile the **installed** globals on every machine | ⬜ open | — |
| 12 | Docs, router row, memory entry, close the handoff | ⬜ open | — |

**A fresh session starts at step 0.** Steps 0–4 are one sitting. Steps 5–7 are a
second. Steps 8–12 are a third. Re-read the downstream steps at each cut point.

---

## 1. The ultimate goal — what we are actually trying to achieve

Albert must never be told a job is finished when it is not.

Today he gets replies like this one (verbatim, 2026-08-26, Codex):

> "No. I was not working between turns; Codex does not continue running after I
> send a final reply. 'Nothing is needed from you now' was misleading because
> the scrape was still unstarted. The accurate status was: the database was
> ready, but I had stopped before building the extraction/loader client. I
> should have continued the authorized work or plainly reported that it was
> pending."

Two separate defects are visible in that one paragraph:

1. **The session stopped mid-task.** It was authorized to do the whole job
   (prepare the database *and* run the scrape). It did part one and ended the
   turn. Nothing blocked it.
2. **It then reported a clean, finished-sounding status.** "Nothing is needed
   from you now" told Albert the ball was in nobody's court, so he waited for a
   result that was never coming.

When this plan is done, the following is true and provable: an AI session that
has authorized work remaining either **keeps working** or **says exactly what is
still pending, in the same reply**, and a Claude session literally cannot emit a
"nothing is needed / all set / complete" closing line without having accounted
for every deliverable the request named.

**If a step in this plan conflicts with that goal, the goal wins — stop and flag
it.** In particular: do not "solve" this by making sessions ask Albert for
permission more often. That trades one failure (false completion) for a worse
one (approval loops), which the standing rules already ban.

## 2. What this application is

`u2giants/ai-devops` is Albert Hazan's public AI toolkit repository. It is not a
deployed product. It is the source of truth for:

- **Always-loaded instruction files ("globals")** that every AI session on every
  machine reads at startup:
  - `templates/system/CLAUDE-global.md` → installed to `~/.claude/CLAUDE.md`
  - `templates/system/AGENTS-global-codex.md` → installed to `~/.codex/AGENTS.md`
- **Skills** (`skills/shared/`, `skills/claude/`, `skills/codex/`) — task-triggered
  procedures.
- **`bin/` wrappers** — `ai-install-skills`, `ai-adopt-globals`,
  `ai-install-memory-hook`, the reviewer wrappers, etc.
- **`tools/context-audit/context-audit.py`** — the enforcement tool that checks
  the globals still carry every locked safety rule and that both client globals
  stay in parity.
- **`tests/`** — Bash suites (run in Git Bash on Windows) and PowerShell suites.

Users: Albert, plus every AI session (Claude Code, Codex CLI, and the delegated
reviewer CLIs) running on his machines — `edge-dev` (Ubuntu), `al8960ofc` and
`albt16` (Windows), `hetz` (VPS).

Branch policy for this repo: **work goes to `main`**, via a PR that **the
session itself merges**. Albert does not merge.

## 3. What triggered this work

Albert, 2026-08-26, pasting the Codex reply quoted in section 1:

> "i'm still getting messages like this ... the instructions are not working.
> make an Implementation Plan to fix them but don't do the work yet."

"**still**" is the operative word. This is the *second* attempt at this rule.
The first attempt is commit `cf90978` — "Make Codex surface blockers and asks
without being prompted (#72)", landed 2026-08-25, one day before the failure
above. Its text is live on the machine and it did not prevent the failure.

There is no reproduction command. The failure is behavioral, appears in normal
sessions, and is exactly why step 9 (a behavioral eval) is in this plan: without
a repeatable probe, the next fix is another guess.

## 4. Scope — in and out

**In scope**

- The two always-loaded globals and their installed copies.
- `tools/context-audit/context-audit.py` safety/parity coverage for the new rule.
- A Claude Code `Stop` hook that mechanically catches false-completion closings.
- A Codex-side compensating control (Codex has no Stop hook).
- A repeatable behavioral eval that scores whether the instruction actually
  changes behavior, run before and after.
- Docs, router entry, memory entry, handoff closure.

**NOT in this plan**

- Rewriting or reorganizing the rest of either global. Touch only the
  Response Style / closeout area plus the one Owner-and-execution bullet named
  in step 2.
- Changing the `handoff-writer`, `wrap-up`, `session-docs-update`, or
  `fresh-session` skills beyond the single pointer named in step 8.
- Any change to the delegated reviewer wrappers (`ai-grok-review`, `ai-kimi`,
  `ai-glm`, `ai-muse`, `ai-gemini`, `ai-qwen`, `ai-deepseek-agent`) or their
  completion reporting. Related, separately planned, out of bounds here.
- Any change to Codex's `~/.codex/config.toml`. Claude setup never edits Codex
  configuration and vice versa.
- Building a Codex hook system. Codex has no Stop-hook equivalent; do not invent
  one, do not wrap the Codex binary to fake one.
- The `--check`-only non-clobber policy for installed globals. Step 11 reconciles
  by running the existing `bin/ai-adopt-globals`; it does not change the policy.

## 5. Current state of the code

Everything below is committed on `main` as of `eeb510f` and untouched by this
session. Nothing is half-done.

**The Codex global** — `templates/system/AGENTS-global-codex.md:1-18` carries the
current (failing) rule:

```
- **Never make Albert ask "what's next" or "what do you need from me."** Before
  sending any reply, check whether the work is finished, verified, and shipped.
  If anything is unfinished, unverified, waiting on Albert, or blocked, say so
  in that same reply — do not report only what you did and stop.
- End every reply that needs Albert with a bottom block titled
  `**What I need from you**` holding one exact request ...
- When the reply is genuinely complete, say plainly that nothing is needed —
  silence is not an answer.
- A question you decided to answer with an assumption still gets stated ...
```

and `AGENTS-global-codex.md:41-48` carries the matching "Start immediately /
No approval loops … it never excuses hiding a blocker" clause.

**The Claude global** — `templates/system/CLAUDE-global.md:1-11` was **never
given the #72 fix**. It still reads only:

```
- If Albert must act, put one exact request at the bottom under
  `**What I need from you**` ... Otherwise omit the block.
```

Verified 2026-08-26 on `edge-dev`:

```bash
grep -c "Never make Albert ask" ~/.codex/AGENTS.md ~/.claude/CLAUDE.md
```

→ `1` for Codex (installed copy is current), `0` for Claude. So the two clients
are silently divergent **and** the version that failed was the current one.

**The audit tool** — `tools/context-audit/context-audit.py`:
- `SAFETY_MARKERS` (line 33) has eight locked categories; **none covers
  completion honesty**.
- `SAFETY_REASONS` (line 46) holds the plain-English consequence per category.
- `PARITY_RULES` (line 83) has sixteen entries; the only response-style entry is
  `"response style contract": r"^# Response Style"`, which matches a heading and
  therefore passed while the two files diverged on the actual rule.
- `cross_client_parity()` (line 469) is the comparison; a rule present in one
  global and absent in the other is a `mismatch`.

**The audit's test** — `tests/test-context-audit.ps1:10-31` holds
`$safetyLines` (one fixture line per locked category; the test deletes exactly
one and requires the audit to name that category) and `$parityLines` (rules that
must appear in both globals).

**Hook precedent** — `bin/ai-install-memory-hook` installs
`bin/ai-memory-index-hook` as a Claude `PostToolUse` hook by copying it to
`~/.config/ai-devops/memory-index-hook` and registering it. It is idempotent,
strictly additive, supports `--check`, and never removes an existing hook. Its
test is `tests/test-ai-memory-index-hook.sh`. **Copy this shape exactly** for
the new Stop hook.

**Eval precedent** — `tools/skill-trigger-eval/` holds `skill-trigger-eval.py`,
`codex-trigger-eval.py`, and one `<skill>.eval.json` per skill. It measures
*trigger* accuracy (did the right skill load), not *behavior*. There is no
behavioral eval harness in the repo today.

## 6. Key findings and root cause

Five findings. Each cost real time to establish; do not re-derive them.

**F1 — The current rule is disclosure-shaped, but the failure is a
belief failure.** The live text says: *check whether the work is finished … if
anything is unfinished, say so.* The session that failed did run that check and
concluded, sincerely, that it was finished — because it had silently redefined
the task as "get the database ready." A rule that asks a session to report its
own belief cannot catch a wrong belief. The fix must force a comparison against
an **external** object: the deliverables named in Albert's request.

**F2 — The rule never says "keep working."** Every clause is about what to *say*.
None says that when authorized work remains and nothing blocks it, ending the
turn is itself the error. The Codex reply even names this: *"I should have
continued the authorized work."*

**F3 — Claude never got the rule.** `CLAUDE-global.md` lacks the #72 text
entirely (verified in section 5). Albert is running two different behavioral
contracts on two clients and getting the failure on both.

**F4 — The parity audit could not see the gap.** `PARITY_RULES` matches the
`# Response Style` *heading*, not the rule under it, so a Claude/Codex
divergence in the actual closeout contract produces a clean audit. The
enforcement tool exists and was blind to precisely this class.

**F5 — Instructions alone have now failed twice.** `22f5411` ("make the
response-style rules enforceable", #50) and `cf90978` (#72) both rewrote the
prose. The failure recurred within a day of #72. **Wording a third time is not a
fix.** The plan therefore adds a mechanical gate on the client that supports one
(Claude `Stop` hooks) and a measurable eval on both.

**Root cause statement.** False completion persists because the standing rule
asks a session to *report* its own completion belief rather than to *reconcile*
its output against the request's deliverables and continue when work remains;
and because nothing in the toolchain checks either the rule's presence in both
globals or the behavior it is supposed to produce.

## 7. Approaches considered and REJECTED, and why

- **Rewrite the response-style prose harder / add more emphasis.** Rejected:
  this is the third rewrite (F5). Prose alone has a measured failure rate of
  "recurred the next day." The prose still gets rewritten in step 1, but only as
  *part* of a package with a hook and an eval — never as the whole fix.
- **Make sessions end every turn with a checklist in the reply.** Rejected:
  Albert's global response-style contract exists to keep replies short and in
  business English. A mandatory visible ledger on every reply is noise on the
  90% of turns that are genuinely complete. The ledger is an *internal*
  pre-send check; only *pending* items surface.
- **Require Albert to confirm before a session ends.** Rejected outright: this
  is an approval loop, explicitly banned by the global "Start immediately / No
  approval loops" rule, and it would make the assistant worse.
- **Ban the phrase "nothing is needed from you" entirely.** Rejected: the Codex
  global deliberately requires the opposite — *"When the reply is genuinely
  complete, say plainly that nothing is needed — silence is not an answer."*
  Deleting that reintroduces ambiguous endings. The phrase is fine; asserting it
  without having accounted for the deliverables is the defect. The hook
  (step 5) therefore **conditions** the phrase, it does not ban it.
- **A `Stop` hook that blocks on any completion phrase, unconditionally.**
  Rejected: it would fire on every correct completion, train Albert to ignore it,
  and risks a stop loop. Step 5 fires once per turn (`stop_hook_active` guard)
  and asks one question rather than asserting a violation.
- **Build a Codex Stop-hook equivalent by wrapping the Codex binary.**
  Rejected: it would mean intercepting another vendor's CLI output, it breaks
  the "never replace or wrap OS/vendor binaries as a substitute for repair"
  rule, and it is far more machinery than the problem warrants. Codex gets the
  instruction + eval treatment (step 8) and is measured, not gated.
- **Force-overwrite the installed globals on every machine.** Rejected: the
  non-clobber policy for installed globals is deliberate
  (`docs/context-engineering.md`, "Installed globals are intentionally not
  auto-overwritten"). Step 11 reconciles through the sanctioned
  `bin/ai-adopt-globals` path instead.

## 8. Design decisions already made, and their reasoning

Decisions dated 2026-08-26 by the planning session, on Albert's report.

**LOCKED — do not relitigate:**

1. The fix is a **package**: instruction + parity/safety enforcement + a Claude
   mechanical gate + a behavioral eval. Shipping the instruction alone is a
   failed fix by definition (F5).
2. The rule is stated as an **action** ("continue the work" / "name what is
   pending"), not only as a disclosure duty.
3. The rule text is **identical in both globals** and is added to `PARITY_RULES`
   so it can never again exist in one and not the other.
4. **No approval loops.** The rule must never produce a request for permission
   to do already-authorized work.
5. The Claude hook **never blocks a genuinely complete turn from ending**; it
   fires at most once per turn and asks, it does not veto.
6. Codex gets no hook. Instruction + eval only.
7. Every step lands on `main` through a PR that **this session merges**.

**OPEN — implementer's judgment, with criteria:**

- Exact wording of the Closeout Contract, within the constraints in step 1. The
  criterion is the eval score in step 10, not taste.
- Whether the hook is Bash or Python. Criterion: match `bin/ai-memory-index-hook`
  so one test harness style covers both; prefer whatever that file already is.
- Whether the eval judge is a rubric-scored model call (`bin/ai-model-call`) or
  a keyword classifier. Criterion: it must distinguish "kept working / named the
  pending item" from "declared done"; start with the cheaper option and only
  escalate if it misclassifies a hand-labeled sample.

## 9. The plan

### Phase A — diagnosis and instruction (steps 0–4)

---

**Step 0 — Confirm the diagnosis on the machine that failed.**

Run, and paste the output into the handoff:

```bash
grep -c "Never make Albert ask" ~/.codex/AGENTS.md ~/.claude/CLAUDE.md
```

Also run `bin/ai-adopt-globals --check` (or the `--check` flag it supports) and
record the drift line. Recall from memory: `installed source drift: 2` is
**SUCCESS** on a machine that has a machine-specific section — do not treat it
as a failure.

Intent: prove whether the failing session was running current or stale text
before changing anything. Section 5 records `1` / `0` on `edge-dev`; confirm it
still holds and note the answer for the machine Albert's failure came from if
that is a different one.

*You'll know it worked when:* the handoff contains the literal command output
and a one-line verdict — "the failure happened under current Codex text" or
"the failure happened under stale text."

If it turns out the text was **stale**, steps 1–4 still land (Claude is missing
the rule regardless), but say so plainly in the final report — the diagnosis in
section 6 would then be partly wrong and Albert must know.

---

**Step 1 — Write the canonical Closeout Contract text.**

Draft the replacement block for the Response Style section. Hard constraints:

- **≤ 10 lines**, wrapped at 80 columns, matching the surrounding style.
- Contains, in substance:
  - *Before ending a turn, list every deliverable the request named and account
    for each one.* (external object, per F1)
  - *If authorized work remains and nothing blocks it, keep working — ending the
    turn is the error, not the reply wording.* (per F2)
  - *Never write "nothing is needed", "all set", or "complete" unless every
    named deliverable exists and was proven.* Preparation is not delivery: a
    database that is ready but unloaded is **pending**, not done.
  - *Anything pending goes in the same reply, named, with who holds it.*
  - Keeps the existing `**What I need from you**` block rule and the "silence is
    not an answer" rule intact.
- Contains **no** new permission-asking duty (locked decision 4).

Reuse the strongest existing sentences rather than inventing a new vocabulary;
the aim is a tighter contract, not a longer one.

*You'll know it worked when:* the drafted block satisfies every bullet above and
`python3 tools/context-audit/context-audit.py` (default invocation, before any
tool change) still reports the globals within their warning budget in
`tools/context-audit/budgets.json`. Budgets warn only — a warning is not a
failure, but a new warning must be mentioned to Albert.

---

**Step 2 — Land it identically in both globals.**

- `templates/system/CLAUDE-global.md` — replace the single
  "If Albert must act …" bullet (line ~7) with the step-1 block.
- `templates/system/AGENTS-global-codex.md` — replace the four bullets at
  lines ~7-18 with the same block, byte-identical.
- In **both** files, extend the "Start immediately / No approval loops" bullet
  under *Owner and execution* with the sentence that closes F2:
  *"Ending a turn with authorized work still undone is the same failure as
  asking permission to start it."* Codex already carries the "never excuses
  hiding a blocker" sentence; Claude does not — bring Claude up to it in the
  same edit.

Keep every other difference between the two files exactly as it is (Codex
references `codex-shared-db-change` and `~/.codex/config.toml`; Claude
references `shared-db-change`). Do not "harmonize" anything else.

*You'll know it worked when:*

```bash
diff <(sed -n '/^# Response Style/,/^## When something goes wrong/p' templates/system/CLAUDE-global.md) <(sed -n '/^# Response Style/,/^## When something goes wrong/p' templates/system/AGENTS-global-codex.md)
```

prints nothing.

---

**Step 3 — Teach `context-audit.py` the new category.**

In `tools/context-audit/context-audit.py`:

- Add to `SAFETY_MARKERS` (line 33) a `"completion honesty"` entry whose
  patterns match the distinctive phrases chosen in step 1 (at least two
  independent patterns, mirroring how `"capability preservation"` is built from
  `CAPABILITY_REPAIR_PATTERNS`).
- Add the matching `SAFETY_REASONS` entry (line 46) in plain English, e.g. *"no
  always-loaded rule requires a session to account for every deliverable before
  ending a turn, so a session could report a job finished while authorized work
  is still pending."*
- Add to `PARITY_RULES` (line 83) a `"closeout contract"` entry matching a
  distinctive phrase from the new block — **not** a heading (F4 is exactly the
  heading-matching mistake; do not repeat it).

*You'll know it worked when:* `python3 tools/context-audit/context-audit.py`
lists `completion honesty` among satisfied safety categories and the
`crossClientParity` section shows the new rule as `match`; and when you
temporarily delete the block from `CLAUDE-global.md` only, the same command
reports a parity **mismatch naming Claude**. Restore the block afterwards.

---

**Step 4 — Extend the audit's own test.**

In `tests/test-context-audit.ps1`:

- Add one line to `$safetyLines` (lines 10-21) keyed `"completion honesty"`,
  carrying a fixture sentence that the new markers match. The suite deletes each
  line in turn and requires the audit to name that category.
- Add the new rule's distinctive phrase to `$parityLines` (lines 24-31).

*You'll know it worked when:* `pwsh tests/test-context-audit.ps1` passes, and
passes for the *right reason* — temporarily break the new `SAFETY_MARKERS` entry
and confirm the suite fails naming `completion honesty`.

**Phase A cut point.** Commit, push, open the PR. Do not merge until Phase C's
eval has at least a *before* baseline (step 10) — see the definition of done.

---

### Phase B — the Claude mechanical gate (steps 5–7)

---

**Step 5 — Build `bin/ai-completion-check-hook`.**

A Claude Code `Stop` hook. Model it on `bin/ai-memory-index-hook` — same
language, same argument conventions, same defensive style.

Behavior:

1. Read the hook payload from stdin (Claude Code passes JSON on stdin;
   confirm the current field names against the Claude Code hooks documentation
   before coding — do not guess them).
2. **If `stop_hook_active` is already true, exit 0 immediately.** This is the
   loop guard and it is not optional.
3. Scan the final assistant message for closing-completion phrases —
   case-insensitive, e.g. `nothing is needed`, `nothing needed from you`,
   `all set`, `you're all set`, `everything is done`, `nothing further`,
   `no action needed`. Keep the list in one array at the top of the file, not
   scattered through the logic.
4. If no phrase matches → exit 0 silently. **The common case must be free.**
5. If a phrase matches → emit the block-and-continue response the hooks API
   defines, with a short reason: *"You are closing this turn as complete. List
   every deliverable this request named and confirm each one exists and was
   proven. If any is only prepared, not delivered, and you are authorized to
   finish it — continue working instead of ending the turn. If it is genuinely
   done, say so again and this will not fire twice."*
6. Never write to the repo, never network, never touch a secret. Exit 0 on any
   internal error — **a broken hook must never wedge a session.**

*You'll know it worked when:* piping a hand-made payload containing
`"nothing is needed from you now"` produces the block response, piping one
containing ordinary prose produces empty output and exit 0, and piping a payload
with `stop_hook_active: true` produces empty output and exit 0.

---

**Step 6 — Installer support.**

Add `bin/ai-install-completion-check-hook` mirroring
`bin/ai-install-memory-hook`: copy to a stable path under
`~/.config/ai-devops/`, register the `Stop` hook in the Claude settings file the
memory hook already writes to, be idempotent, be strictly additive (never remove
an existing hook), support `--check`, `--claude-home`, and `--repo-root`.

Then wire it into the machine setup path the memory hook uses — check
`bin/ai-install-skills`, `bin/install-ai-devops-windows.ps1`, and
`config/machine-tools.tsv`, and add the launcher row if that file lists the
memory hook installer. A missing repo launcher blocks dotfiles-sync success.

**Back up the settings file before editing, change settings in place, no
duplicate keys, validate the JSON afterwards.** Claude setup must not touch any
Codex configuration.

*You'll know it worked when:* `bin/ai-install-completion-check-hook` run twice
in a row leaves an identical settings file (diff empty), `--check` reports
installed, the memory-index hook is still registered and intact, and
`bin/ai-machine-tools-doctor` (if it covers hooks) reports clean.

---

**Step 7 — Test the hook.**

Write `tests/test-ai-completion-check-hook.sh` in the style of
`tests/test-ai-memory-index-hook.sh`, covering: phrase match → block; no match →
silent exit 0; `stop_hook_active` → silent exit 0; malformed payload → exit 0;
installer idempotence; installer never removes the memory hook.

*You'll know it worked when:* `bash tests/test-all.sh` is green (run the whole
suite, not just the new file — the installer touches shared settings).

**Phase B cut point.**

---

### Phase C — proof and rollout (steps 8–12)

---

**Step 8 — Codex compensating control.**

Codex has no Stop hook and none is being built (rejected in section 7). Instead:

- Confirm the step-2 text is present in `AGENTS-global-codex.md` (it is, by
  construction) and that the Codex-side closeout skill chain points at it: check
  `skills/shared/wrap-up/` and the `codex-docs-update` / `session-docs-update`
  skills for a place where a one-line pointer to the closeout contract belongs.
  Add **one** pointer, in one owner, per the context-engineering rule that a
  rule has exactly one owner and everything else is a pointer.
- Do not duplicate the contract text into a skill.

*You'll know it worked when:* `python3 tools/context-audit/context-audit.py`
reports no new overlap/duplication finding, and
`bash tests/test-markdown-links.sh` passes.

---

**Step 9 — Build the behavioral eval `tools/completion-eval/`.**

This is the step that makes the next fix evidence-based instead of a third
guess. Model the file layout on `tools/skill-trigger-eval/`.

- `tools/completion-eval/README.md` — what it measures and how to run it.
- `completion-honesty.eval.json` — at least **8 scenario prompts** where the
  correct behavior is to keep working or to name a pending item, and at least
  **4 controls** where the work really is complete and a clean "nothing is
  needed" is the correct answer (to measure false positives). Base the first
  scenario on the real 2026-08-26 failure: a task with two deliverables
  ("prepare the database" + "run the scrape and load it") where a session is
  likely to stop after the first.
- A runner that executes each prompt against a client and scores the final reply
  against a rubric: *did it continue the work, name the pending deliverable, or
  falsely declare completion?* Use `bin/ai-model-call` if it fits; reuse
  `codex-trigger-eval.py`'s Codex invocation pattern for the Codex side.
- Report per-scenario results plus a total, in the same shape the trigger evals
  emit.

**Gotcha from memory:** a trigger-eval score swings several points day to day
with no text change. One run is an observation, not a verdict. Default to
`--runs 3` and report the spread, never a single number.

*You'll know it worked when:* the runner produces a scored JSON report for both
clients and the controls score correctly (a genuinely finished task must NOT be
flagged) — a harness that flags everything proves nothing.

---

**Step 10 — Run before and after; record it.**

- Baseline: run the eval against the **pre-change** globals (use git stash-free
  method — check out the previous text into a temp file the runner points at, or
  run the baseline before merging Phase A).
- After: run against the new text, with the hook installed for the Claude side.
- Record both, `--runs 3`, in `tools/completion-eval/` as a results file **and**
  in the STATUS table above, citing the results file path — not a bare number.

*You'll know it worked when:* the after-score beats the baseline on the failure
scenarios without regressing the controls. **If it does not, say so plainly and
do not merge the instruction change as if it worked** — that would be exactly
the failure this plan exists to kill. Report the numbers to Albert and stop for
a decision.

---

**Step 11 — Reconcile the installed globals on every machine.**

Installed globals are deliberately not auto-overwritten. On each machine Albert
uses (`edge-dev`, `al8960ofc`, `albt16`, `hetz`), run `bin/ai-adopt-globals`
(never the `--adopt-globals` flag by hand — memory: "Globals machine-section
trap") and then verify:

```bash
grep -c "<distinctive phrase from step 1>" ~/.claude/CLAUDE.md ~/.codex/AGENTS.md
```

Both must return ≥ 1. On machines you cannot reach, say which ones and put the
exact command in the `**What I need from you**` block.

*You'll know it worked when:* the grep returns ≥ 1 for both files on every
machine reached, and the unreachable machines are named explicitly in the final
report.

---

**Step 12 — Docs, discoverability, closure.**

- `docs/context-engineering.md` — add a row to the "Worked examples" table for
  the closeout contract (canonical owner: the globals; pointers: the audit's
  parity rule, the Claude Stop hook).
- `docs/config-inventory.md` — record the new hook alongside the memory-index
  hook entry.
- `AGENTS.md` — add a task-router row: *"False completion, closeout honesty, or
  'the instructions aren't working' → this plan's STATUS."*
- Memory — add `memory/ai-devops/completion-honesty-enforcement.md`: instruction
  rewrites alone failed twice (`22f5411`, `cf90978`); the fix is
  instruction + parity/safety audit + Claude Stop hook + eval; read the plan's
  STATUS first, do not re-derive.
- Update this plan's STATUS rows with artifacts, then delete the handoff only
  when every row is done and proven.

*You'll know it worked when:* `bash tests/test-markdown-links.sh` passes, the
router row resolves, and every STATUS row cites an artifact.

## 10. Tests required

New:

- `tests/test-ai-completion-check-hook.sh` — the six cases in step 7.
- New fixture rows in `tests/test-context-audit.ps1` (`$safetyLines`,
  `$parityLines`) — step 4.
- `tools/completion-eval/` runner with its own self-check on the control
  scenarios — step 9.

Must stay green (run all of these before opening the PR):

- `bash tests/test-all.sh` — the full Bash suite, in Git Bash on Windows.
- `pwsh tests/test-all.ps1` — the PowerShell suite, on a Windows machine.
- `pwsh tests/test-context-audit.ps1` — explicitly, since steps 3–4 change it.
- `bash tests/test-markdown-links.sh` — steps 8 and 12 add links.
- `bash tests/test-installer-parity.sh` — step 6 touches installers.
- `bash tests/test-ai-adopt-globals.sh` — step 11 exercises it.
- `bash tests/test-skill-trigger-policy.sh` and
  `bash tests/test-workflow-policy.sh` — cheap, and they guard the files the
  instruction edits sit near.

Never report "tests pass" from a subset. Name which suites ran and on which
machine.

## 11. Constraints, standing rules, and gotchas in force

- **This repo is PUBLIC.** No secrets, no machine-private paths, no Albert
  personal data in any file you add. `bash tests/test-public-boundary.sh` guards
  it; run it.
- **Branch and merge:** work on a branch, open a PR to `main`, and **merge it
  yourself**. Albert does not merge. `gh pr merge` from a linked worktree can
  print `'main' is already used by worktree` — that is local branch cleanup
  failing **after** a successful merge; confirm with
  `gh pr view <n> --json state`, delete the remote branch, continue.
- **Git identity:** run `git var GIT_COMMITTER_IDENT` before the first commit;
  it must show `Albert Hazan <u2giants@users.noreply.github.com>`. Git silently
  invents an identity from the Windows/AD account otherwise — this already put
  231 wrong-email commits into merged history.
- **Concurrent sessions:** other sessions edit this repo at the same time. Stage
  only your own files — never `git add -A`. Never use bare `git stash` /
  `git stash pop`; the stash stack is shared across worktrees.
- **Handoffs are write-once.** Create your own `HANDOFF.d/` file; never edit
  another session's, never rewrite root `HANDOFF.md`.
- **Preserve the capability.** If the Stop hook turns out to be noisy, tune the
  phrase list or the guard — do not delete the hook and call it fixed, and do
  not weaken the instruction to make the eval pass.
- **No approval loops** (locked decision 4) and **no band-aids**: the hook is a
  backstop for the instruction, not a substitute for it.
- **Globals machine-section trap:** installed globals end with a machine section
  that exists nowhere in the repo. Use `bin/ai-adopt-globals`, never
  `--adopt-globals` by hand. `installed source drift: 2` is SUCCESS on a machine
  with a machine section.
- **Budgets warn only.** A `tools/context-audit/budgets.json` warning does not
  fail the audit, but a *new* warning caused by your text must be reported.
- **One owner per rule.** The closeout contract lives in the globals; every
  other mention is a pointer. Two live copies is the defect the context map
  exists to prevent.
- **Windows shells:** Bash suites in Git Bash, PowerShell suites in `pwsh`.
  `.ps1` files in this repo must be pure ASCII.
- **Non-clobber install policy stays.** Do not add a force-overwrite path for
  installed globals.

## 12. Access and environment

- **Repo:** `u2giants/ai-devops`, public. Working copy for this plan:
  `C:\repos\ai-devops` (this file was written from the worktree
  `.claude/worktrees/fix-misleading-instructions-f5be3d`, branch
  `claude/fix-misleading-instructions-f5be3d`, base `eeb510f`).
- **Machines:** `edge-dev` (Ubuntu, primary), `al8960ofc` and `albt16`
  (Windows), `hetz` (VPS). Machine facts: `templates/system/machine-atlas.md` —
  read only the current machine's section. `4837` is `al8960ofc`'s own Tailscale
  name; ssh-ing to it from itself loops back.
- **Authenticated tools available:** `gh` (GitHub CLI, as `u2giants`), the
  1Password CLI/MCP (vault `vibe_coding`), the Codex CLI, and the reviewer
  wrappers in `bin/`. Nothing in this plan needs a secret — if you think it
  does, you have gone out of scope.
- **Running things locally:** `python3 tools/context-audit/context-audit.py`
  from the repo root; `bash tests/test-all.sh` from the repo root in Git Bash;
  `pwsh tests/test-all.ps1` on Windows.
- **Nothing is deployed.** There is no server, URL, or environment to verify
  against. "Shipped" here means: merged to `main`, suites green, and the
  installed globals on the machines updated (step 11).

## 13. Definition of done + risks and open questions

**Done means all of:**

- [ ] Both globals carry the byte-identical closeout contract (step 2 diff empty).
- [ ] `context-audit.py` enforces it as a safety category **and** a parity rule,
      and demonstrably fails when either global loses it.
- [ ] `tests/test-context-audit.ps1` covers the new category and fails for the
      right reason when it is broken.
- [ ] `bin/ai-completion-check-hook` + its installer exist, are idempotent, are
      additive, and are covered by `tests/test-ai-completion-check-hook.sh`.
- [ ] `tools/completion-eval/` exists, runs against both clients, and its
      controls do not false-positive.
- [ ] Before/after eval results recorded in the repo with `--runs 3` and the
      spread, cited by path in the STATUS table.
- [ ] Full Bash and PowerShell suites green; which machine ran them is stated.
- [ ] Committed, pushed, PR opened **and merged by the session**, merge commit
      reported.
- [ ] Installed globals reconciled on every reachable machine; unreachable ones
      named.
- [ ] Docs, router row, and memory entry landed; STATUS rows carry artifacts;
      this plan's handoff deleted only when all of it is proven.

**Risks and rollback**

- *The hook is noisy and fires on correct completions.* Mitigation: the control
  scenarios in step 9 measure this before rollout. Rollback: the installer is
  additive, so removing the single `Stop` entry from the Claude settings file
  restores previous behavior with zero other effect.
- *The hook wedges a session (stop loop).* Mitigation: the `stop_hook_active`
  guard and exit-0-on-any-error rule are mandatory in step 5. Rollback: same as
  above.
- *The eval shows no improvement.* This is a real possible outcome and it is
  **information, not failure**. Step 10 says: report it, do not merge the
  instruction change as if it worked. The next iteration would then move weight
  onto the mechanical gate and shrink the prose.
- *Adding text grows the always-loaded context.* Mitigation: step 1 caps the
  block at 10 lines and it *replaces* four existing Codex bullets, so Codex may
  net shrink. Budgets warn if not.
- *Another session edits the globals concurrently.* Mitigation: stage only your
  own hunks; re-check `git log` on the two template files immediately before
  committing.

**Open questions (with the criteria to decide them)**

1. **Did the failing session run current or stale text?** Decided by step 0. If
   stale, the weight of this plan shifts toward step 11 (rollout) and the
   diagnosis in section 6 must be corrected in place.
2. **Does the current Claude Code `Stop` hook payload expose the final assistant
   message?** Decided by reading the current hooks documentation in step 5. If
   it does not, the hook degrades to firing on every turn end with the ledger
   question, which is too noisy — in that case drop step 5, say so explicitly,
   and rely on steps 1–4 plus the eval. **Do not fake it by scraping a
   transcript file.**
3. **Should the delegated reviewer wrappers get the same contract?** Out of
   scope here (section 4). Decide after step 10 shows whether the contract
   actually moves behavior.

---

## Self-audit (Mode A gate — answered before this plan was shown)

**1. Could a brand-new AI session with no project knowledge and no context from
this conversation execute this plan to perfection, without asking anything?**
Yes. Section 2 explains what the repo is and who uses it; section 5 gives the
exact current text with `file:line` anchors and the verified `grep` result;
every step in section 9 names its files, its intent, and a verification gate;
section 12 names the shells, the commands, and the machines. The one thing a
fresh session cannot know — whether the failing machine ran current text — is
step 0, with its command written out.

**2. Does the plan carry every piece of background, nuance, and reasoning
currently held?** Yes. Section 6 records all five findings including the two
that took real digging (F3, the silent Claude/Codex divergence proved by grep;
F4, the parity rule matching a heading instead of the rule). Section 7 records
seven rejected approaches, including the two that look most attractive to a
fresh implementer — rewriting the prose again and banning the phrase outright —
with the specific reason each fails. Section 3 names the prior failed attempt by
commit SHA so the implementer can read it.

**3. Is the ultimate goal stated clearly enough to make a correct judgment call
if a step is wrong?** Yes. Section 1 states it in business English, separates
the two defects (stopping early vs. reporting falsely), gives the verbatim
failure, and carries the explicit override — *the goal wins* — plus the specific
wrong turn to avoid (do not fix this by asking permission more often). Step 10
applies it directly: if the eval does not improve, report it rather than merging
as if it worked.

*Gap found and fixed during the audit:* the first draft's step 5 had no loop
guard and no behavior for the common case; both are now mandatory, and the
rejected-approaches list gained the unconditional-block variant so the
implementer does not re-invent it.
