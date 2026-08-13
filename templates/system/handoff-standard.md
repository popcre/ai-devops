# HANDOFF standard — how EVERY session must write a handoff

This is a hard standard, not a suggestion. Albert starts new sessions with clean
context windows and relies on the handoff as the ONLY memory carried forward.
Skimpy handoffs force him to stay in long sessions babysitting — the exact thing
this standard exists to prevent. Applies to Claude AND Codex, every time.

## Where the handoff goes: ONE WRITE-ONCE FILE PER SESSION (`HANDOFF.d/`)

This is the most important mechanical rule in this standard, and it overrides
every older instruction that said "rewrite `HANDOFF.md`".

Several AI agents (Claude, Codex, Grok, GLM, Kimi, Qwen) work on the same repos
at the same time — sometimes in the SAME working copy on the same machine,
sometimes in different clones of the same GitHub repo. A single shared
`HANDOFF.md` that each session rewrites makes **data loss the default**: in one
working copy the second writer silently overwrites the first (git never sees two
versions, so it cannot help), and across clones both sides rewrite and push,
producing either a merge conflict a non-programmer will never resolve or a
resolution that quietly drops one session's work. This has already happened.

### The rule

- **Each session writes exactly ONE new file** under `HANDOFF.d/` and nothing else:

  ```
  HANDOFF.d/<UTC-timestamp>-<machine>-<agent>-<slug>.md
  ```

  Example: `HANDOFF.d/2026-07-29T2140Z-t16-claude-supabase-mcp-scoping.md`

- **Write-once.** Create it, fill it, done. You may keep editing **your own**
  file while your session is still running. You must **never** open, edit,
  reformat, "tidy", or merge **another** session's file. If you think another
  session's handoff is wrong or stale, say so in YOUR file — do not rewrite theirs.

- **Deleting is not editing.** The write-once rule protects the *text* from being
  rewritten while another session may be mid-write. It was never meant to make a
  finished file immortal — but that is what it did: only the authoring session
  could delete, authoring sessions never come back, and `HANDOFF.d/` silently
  grew until stale files were actively misdirecting readers. So: **any session
  may delete another session's file once it has verified, itself, that every gate
  in that file's "Done when" block passes.** Run the gates; do not take the
  file's own word for it, and do not delete on age, on a closed chat, or on a
  hunch. Git history keeps the text, so a wrong delete is recoverable — but say
  in your commit message which file you deleted and which gates you ran.

- **`HANDOFF.md` is a short STATIC pointer.** It is written once (see below) and
  is **never rewritten at closeout**. It exists only so the standing rule "read
  `HANDOFF.md` on start" still has one named entry point.

Because each session owns a distinct filename, two sessions can never write the
same file, so there is nothing to conflict and nothing to overwrite — in a shared
working copy or across clones. No `.gitattributes` merge driver is involved, and
**`merge=union` must never be added** for handoffs: it merges lines with no
understanding of Markdown structure, so it would silently produce a file with two
contradictory "current state" sections instead of a loud conflict.

### Filename fields — how to derive them at runtime

| Field | How to get it | Example |
|---|---|---|
| `<UTC-timestamp>` | `date -u +%Y-%m-%dT%H%MZ` (Bash) / `(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHHmm')+'Z'` (PowerShell). **Must include the time**, not just the date — two sessions on one day are normal. | `2026-07-29T2140Z` |
| `<machine>` | Short hostname, lowercased, non-alphanumerics → `-`: `hostname` (Bash) / `$env:COMPUTERNAME` (PowerShell). Use the short machine nickname when it is well known (`t16`, `916`, `4837`, `al8960ofc`, `hetz`). | `t16` |
| `<agent>` | The agent you are: `claude`, `codex`, `grok`, `glm`, `kimi`, `qwen`. Never omit it — two agents on the same machine in the same minute is possible. | `claude` |
| `<slug>` | 2–5 word kebab-case topic of THIS workstream. Lowercase `a-z0-9-` only. | `supabase-mcp-scoping` |

If you cannot determine the machine or agent name for certain, use a specific
best guess rather than a placeholder — never write `unknown`, `machine`, or
`agent` literally, and never drop the field (dropping a field is what creates
collisions).

### The static `HANDOFF.md` pointer

If the repo has no `HANDOFF.md`, or has one that is already the pointer, write /
leave exactly this (the HTML marker on line 1 is how tools detect the pointer
form — keep it verbatim):

```md
<!-- handoff-pointer: v1 — do not rewrite this file; add a file under HANDOFF.d/ instead -->
# HANDOFF

Active handoffs live in [`HANDOFF.d/`](HANDOFF.d/) — one write-once file per AI
session, named `<UTC-timestamp>-<machine>-<agent>-<slug>.md`.

**Starting a session:** list `HANDOFF.d/`, read the open files **newest first**.
Every file present is an OPEN workstream; finished ones are deleted (git history
keeps the text).

**Ending a session:** create your OWN new file in `HANDOFF.d/` following
`templates/system/handoff-standard.md` (all 10 sections, 0–9). **Do not rewrite this
file, and do not edit another session's file.** Concurrent sessions rely on that.
```

### Legacy (un-migrated) repos — detect and migrate

Most repos still hold the OLD form: a root `HANDOFF.md` containing a full 9-section
handoff document. The transition must be non-breaking, so detect it:

1. `HANDOFF.md` missing → nothing to migrate; write the pointer when you create
   your first `HANDOFF.d/` file.
2. `HANDOFF.md` exists and line 1 contains `handoff-pointer: v1` → already the
   pointer. Leave it completely alone.
3. `HANDOFF.md` exists **without** that marker → **legacy full document**. Treat
   its entire contents as ONE open workstream:
   - `git mv HANDOFF.md HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md`, where
     `<slug>` describes that legacy work (e.g. `legacy-migrated-handoff`). Do not
     rewrite or summarize its body — move the text verbatim.
   - Then create `HANDOFF.md` as the static pointer above.
   - Then write your own session's separate file for your own work.

Also migrate sibling legacy handoff documents (`HANDOFF-<topic>.md`,
`fix_<topic>.md` used as a handoff) the same way when you touch them: one file
each under `HANDOFF.d/`, text moved verbatim.

Never do a legacy migration if another session may be mid-write in the same
working copy and you cannot tell — in that case just add your own `HANDOFF.d/`
file and note in it that migration is still pending.

### Retention — automatic, never a manual chore

- When a workstream is **genuinely proven done** (verified, committed, pushed,
  deployed as applicable), **delete that workstream's `HANDOFF.d/` file** in the
  same commit that finishes it. Git history preserves the text forever, so
  nothing is lost. Delete only files for work you can prove is done — yours, or
  anyone's whose "Done when" gates you have just run yourself.
- **Every handoff must end with a `## Done when` block** — the gates that prove
  the workstream is finished, written so a stranger can run them without asking
  a question. Each line is a command or an observation plus its expected result;
  no prose like "when the feature works". This block is what lets a later session
  retire the file. A handoff without one cannot be retired by anyone but its
  author, which is the failure this whole section exists to prevent.
- **Stale-pointer check when you retire a file:** before deleting, grep the repo
  for its filename. Other handoffs, plans, or docs may link to it. Fix the links
  in files you own, and note any you cannot touch in YOUR file.
- **A file's presence means OPEN.** Session start reads only the files that are
  present; it does not need any status field, index, or archive folder.
- **Threshold warning:** if `HANDOFF.d/` holds **more than 5** files, say so
  loudly in the closing report, list them oldest-first with their dates, and ask
  which are actually finished. Never let them silently accumulate — 50 nine-section
  essays a year is exactly the drowning a fresh developer must be spared.
- Do not create an `archive/`, `done/`, or index file. Deletion + git history IS
  the archive. A generated index would just be another shared mutable file for
  sessions to clobber.

## The mindset (read this first)

Write the handoff for a brand-new developer who **walked in off the street this
morning**. They have:

- NO knowledge of the application or the business it serves
- NO knowledge of what this session was trying to accomplish or why
- NO knowledge of anything discussed in this session
- NO knowledge of what was tried, what failed, or what the dead ends were
- NO access to this chat — when it's gone, it's gone

Your job: make that stranger able to continue **as effectively as you can right
now, with everything you currently know**. If they would have to ask you a
single question to keep going, that question's answer belongs in the handoff.

Default to TOO MUCH. A handoff that is too long costs a few minutes of reading.
A handoff that is too short costs Albert a whole session of rediscovery. These
are not symmetric — always err long.

## Required structure

Use these sections. Never drop one silently — if a section genuinely doesn't
apply, write "N/A" and one line saying why.

All 10 sections (**0–9**) apply to **your session's own `HANDOFF.d/` file** — the
verbosity bar is per session file, not per repo. A three-sentence handoff is still
a failure.

```md
# HANDOFF — <topic> (<UTC date/time>, <machine>/<agent>)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE
Mandatory, and it goes FIRST. Every decision, approval or judgement Albert must
supply — CONSOLIDATED. This is an index, not a new home: each item still lives
where it belongs operationally AND is listed here. The duplication is the point.

Group by consequence, not topic:
- BLOCKING — the work cannot finish without an answer. Say what each one blocks.
- RECOVERABLE — a wrong guess is fixable but wastes rework.
- NOT PART OF THIS WORK, AND NOBODY IS ON IT — anything you learned that needs
  his ruling even though it is out of scope: a bug noticed in passing, a stale
  ticket, an open marker, a security exposure. THIS IS THE CATEGORY THAT GOES
  MISSING, because "not my scope" is exactly why five sessions already skipped it.
  A finding that needs a human ruling is an ASK, not a finding — promote it.

Also list "Already settled — do NOT re-ask", with dates.

Rules: plain business English, one or two sentences each, no jargon. A
RECOMMENDATION for every item, so most can be answered with one word. Tell the
next session to put the WHOLE list to him in ONE message, before starting work —
not one at a time as each is tripped over.

THE SWEEP: before finishing, re-read the whole handoff and extract every sentence
needing the owner. Tells: ⛔, "approve", "owner", "decide", "waiting on", "needs a
ruling", "unanswered", "nobody has", his name. Anything found in §1–§9 or part (b)
MUST also appear here. If there are genuinely none, write "None" explicitly — an
empty §0 is information, a missing one is indistinguishable from a skipped sweep.

## 1. What this application is
Plain-English: what the product does, who uses it, why it exists. Assume zero
prior knowledge. Name the repos, the stack, and where it runs (URLs, hosts).

## 2. What we set out to do this session, and why
The goal in business terms + the technical objective + what triggered it
(bug report, feature request, incident).

## 3. Current state — what is true right now
- What works / is done (verified how?)
- What is half-done and its EXACT current state (files touched, file:line)
- What has not been started
- Is the code committed? pushed? deployed? On which branch/environment?

## 4. Everything we tried that did NOT work
The most-skipped, most-important section. For each dead end: what we tried,
why it seemed reasonable, how it failed, and why. This is what stops the next
session from wasting hours repeating your mistakes.

## 5. Root causes and key findings
What we actually learned about the problem, with file:line references and any
non-obvious discoveries ("the RFQ sub-grid columns come from the backend, not
colDefs" — the kind of thing that took you an hour to figure out).

## 6. Exact next steps
Numbered, in order, specific enough to execute without judgment calls. Each step
ends with a verification gate: "you'll know it worked when ___."

## 7. Constraints and gotchas in force
Standing rules that apply (branch policy, no band-aids, AG-Grid rules, file-date
preservation, etc.) and any traps specific to this work.

## 8. Access and environment
Which CLIs/MCPs are authenticated, which env/branch/URL, where secrets live
(1Password vault name — NEVER the values). Enough that the stranger can act
without asking for logins.

## 9. Open questions and risks
What's uncertain, what could go wrong, decisions made and why (with dates, so a
later session doesn't contradict them).
```

## Mandatory self-audit gate (do this BEFORE showing the handoff)

After drafting, grade your OWN handoff against these questions. **Write an
answer to every question and cite the handoff section(s) that prove the answer.**
Do not merely acknowledge that the questions were asked. If an answer exposes
any missing or weak detail, add it to **your own `HANDOFF.d/` file**, reread the affected sections,
and answer all questions again. Do NOT present the handoff to Albert until every
answer is an evidence-backed "yes" and every identified gap has been closed:

1. Could a developer who walked in off the street — with zero knowledge of this
   app, this session, and this chat — pick up and continue **without asking me a
   single question**?
2. Could they continue **as effectively as I can right now**, with everything I
   currently know?
3. Did I include what we tried that FAILED, and why — not just the final plan?
4. Is every next step concrete enough to execute without guessing, each with a
   way to verify it worked?
5. Did I explain every term, identifier, path, and URL a newcomer wouldn't know?
6. Did I run the section-0 sweep — walking §1–§9 and part (b) line by line — so
   that every decision needing Albert appears in §0, including the ones outside
   this workstream?

Then ask and answer these **four** final synthesis questions exactly:

1. **Is my `HANDOFF.d/` file comprehensive enough that a brand-new developer with
   no knowledge of this project and no context about what we did or what remains
   could pick up where I left off and not skip a beat?**
2. **Is it detailed enough that they could continue as well as I could right
   now, with all my knowledge from this session and all relevant background
   about what we are trying to accomplish?**
3. **Is every single relevant detail—background, goals, intended outcome,
   current state, failed attempts, decisions, constraints, risks, exact next
   actions, and verification evidence—present for the implementing agent to
   execute flawlessly?**
4. **If Albert read ONLY section 0, would he see every decision I need from him,
   including the ones outside this workstream?** Answer it the hard way — walk
   §1–§9 and part (b) line by line, list every sentence needing his judgement,
   and confirm each appears in §0. **Do not answer from memory or from intent.**
   The failure this catches is a decision correctly written down somewhere else
   and never promoted, so it reaches him days late or never. Measured on
   2026-08-07 in `u2giants/shared-db`: of eight items needing Albert, three
   would have been raised, two silently self-decided, and **three never raised
   at all** — and those three had been waiting the longest.

For each answer, name the supporting sections and any gap found. A found gap
must be fixed before re-running the entire audit. Preserve the final answers in
the closing report or at the end of your own `HANDOFF.d/` file so the audit is
inspectable.

State in your closing message that the self-audit passed. Albert should never
again have to ask "is this comprehensive enough for a fresh developer?" — you
must have already answered it yourself.

## Comprehensiveness checklist (objective — every item must be YES)

This is what "comprehensive" means. It is a fixed bar, not a feeling. "It could
always be more detailed" is NOT an item on this list — do not treat it as one.

- [ ] All 10 sections (0–9) present (or "N/A" + reason).
- [ ] Section 0 exists AND the sweep was actually run: every owner decision
      anywhere in §1–§9 or part (b) also appears in §0 — including the ones
      outside this workstream — each with a recommendation; or §0 says "None".
- [ ] A street-newcomer could continue WITHOUT asking a single question.
- [ ] They could continue as effectively as you can right now — every non-obvious
      thing learned this session is written down.
- [ ] The failed attempts / dead ends are included, with why they failed.
- [ ] Every next step is concrete and has a "you'll know it worked when ___" gate.
- [ ] Every term, identifier, path, URL, and commit SHA a newcomer wouldn't know
      is defined or referenced.
- [ ] Commit / push / deploy status is explicit for each piece of work.
- [ ] Secrets are referenced by location only (vault/item), never by value.
- [ ] In a multi-workstream handoff, YOUR workstream's section clears every bar
      above (you need not re-audit other sessions' sections, but do not claim the
      whole file passes if yours is thin).

## Answering "is it comprehensive enough?" (do NOT reflex-answer "No")

The recurring failure this standard exists to end: when asked whether the handoff
is comprehensive / thorough / detailed enough, the answer comes back "No, I'll fix
it" EVERY time — regardless of whether the handoff is actually deficient. That
reflex is the bug. When asked:

1. Re-read the actual handoff file first. Never answer from memory — it may already
   be complete.
2. Grade it once against the comprehensiveness checklist above — the fixed bar, not a vibe.
3. If every item passes, answer "Yes." Say it plainly and show the evidence (map
   each audit dimension to the section that satisfies it). Then stop — do not invent
   work or append "but I could add more."
4. Answer "No" ONLY if you can name a SPECIFIC missing checklist item — a real gap a
   newcomer would trip on. Name it, fix exactly that, re-grade, then answer "Yes."
5. Never answer "No, I'll improve it" as a reflex or a hedge. "More detail is always
   possible" is not a deficiency. Padding a passing handoff wastes the user's time
   and trains them to keep asking. A truthful "Yes" is the goal — reach it by making
   the handoff good, then saying so.

The bar for "Yes": a stranger could continue as effectively as you can right now.
If that is true, the answer is Yes — say it.

## Anti-patterns (these are why past handoffs were too skimpy)

- Assuming the reader knows what the app does, or what "the RFQ issue" refers to.
- Listing the final plan but omitting the failed attempts.
- "Continue where we left off" without saying where that is, in file:line terms.
- Vague next steps ("finish the migration") instead of exact ones.
- Jargon or internal shorthand from this session with no definition.
- Writing three sentences and calling it a handoff. If it's under a screen of
  text for anything non-trivial, it's almost certainly too thin — re-audit.
- **Rewriting the shared root `HANDOFF.md`, or editing another session's
  `HANDOFF.d/` file.** That is the concurrency data-loss bug this standard was
  restructured to remove.

## Mechanics

- Write it to your own new `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md`, then
  commit and push — a handoff that lives only in chat is lost. See
  **§ Where the handoff goes** above for the naming rules, the static `HANDOFF.md`
  pointer, legacy migration, and retention.
- Stage only your own file (and your own code hunks). In a concurrently-edited
  checkout, never `git add -A` another session's uncommitted work.
- End the file with a `## Done when` block (see **Retention**). It is required —
  without it, nobody but you can ever retire the file.
- A `HANDOFF.d/` file is deleted only when the work it describes is truly
  complete. That may be someone else's file, but only after YOU have run its
  `## Done when` gates and they all pass.
- Never add `.gitattributes merge=union` for handoffs — line-unioning Markdown
  produces a silently wrong document instead of a loud conflict.
