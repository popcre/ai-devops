---
name: handoff-writer
description: Write a fresh-developer-grade handoff as one write-once file under HANDOFF.d/, or judge whether an existing handoff is comprehensive enough. Use when the user says "put that plan in handoff.md", "write a handoff", "give me a detailed prompt for the new chat", or asks whether the handoff is thorough, detailed, or comprehensive enough for a fresh developer to pick up and not skip a beat. The handoff must pass the concrete self-audit before it is shown. Do not trigger on a bare "wrap up"; the active client's closeout skill owns that phrase. Shared by Claude and Codex.
---

# handoff-writer

The user works across many short sessions with clean context windows; the handoff
IS the memory carried forward. A thin handoff forces them to babysit long
sessions — the exact thing this skill prevents. It applies to two situations:
**writing** a handoff, and **judging** one the user is challenging.

The recurring failure this skill exists to kill: the user asks *"is the handoff
comprehensive enough for a fresh developer to pick up and not skip a beat?"* and
the answer comes back *"No, I'll fix it now."* — **every single time**, whether
or not the handoff is actually deficient. That reflex is the bug. The cure is two
parts: (1) make the handoff genuinely complete at write time so "Yes" is
truthful, and (2) when asked, verify against the concrete checklist and answer
**Yes** when it passes — instead of reflexively hedging to "No."

## When to use

- "put that context in handoff.md" / "write a comprehensive handoff"
- "write a fix_<topic>.md"
- "give me a very detailed prompt to give another ai session"
- "this session's context window is getting full"
- **The verification question** — any form of "is the handoff thorough / detailed /
  comprehensive / complete enough?", "does it have every relevant detail and
  nuance?", "could a fresh developer continue as well as you?" → go to
  **§ Answering the verification question**. Do NOT reflexively answer "No."

## FIRST: where the handoff goes — one write-once file per session

Many AI agents (Claude, Codex, Grok, GLM, Kimi, Qwen) work the same repos
concurrently — sometimes in the SAME working copy, sometimes in different clones
of the same GitHub repo. A shared root `HANDOFF.md` that each session rewrites
loses data by default: in one working copy the second writer silently overwrites
the first (git never sees two versions, so it cannot help); across clones both
push and either conflict — which the owner, who is not a programmer, will never
resolve — or lose one side in the resolution. This has already happened.

So: **create ONE new file, and only that file:**

```
HANDOFF.d/<UTC-timestamp>-<machine>-<agent>-<slug>.md
```

Example: `HANDOFF.d/2026-07-29T2140Z-t16-claude-supabase-mcp-scoping.md`

| Field | How to derive it at runtime | Example |
|---|---|---|
| UTC timestamp | `date -u +%Y-%m-%dT%H%MZ` (Bash) / `(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHHmm')+'Z'` (PowerShell). **Must include the time** — several sessions per day is normal. | `2026-07-29T2140Z` |
| machine | Short hostname lowercased (`hostname` / `$env:COMPUTERNAME`); prefer the known nickname (`t16`, `916`, `4837`, `al8960ofc`, `hetz`). | `t16` |
| agent | `claude`, `codex`, `grok`, `glm`, `kimi`, `qwen` — whichever you are. Never omit. | `claude` |
| slug | 2–5 word kebab-case topic, `a-z0-9-` only. | `supabase-mcp-scoping` |

Never write a literal placeholder (`unknown`, `machine`, `agent`) and never drop a
field — dropping a field is what creates collisions.

Hard rules:

- **You may edit only your OWN file.** Never open, edit, reformat, "tidy", merge,
  or delete another session's `HANDOFF.d/` file. If another session's handoff
  looks wrong or stale, say so in YOURS.
- **Never rewrite the root `HANDOFF.md`.** It is a short static pointer, written
  once, so that "read HANDOFF.md on start" still has one entry point:

  ```md
  <!-- handoff-pointer: v1 — do not rewrite this file; add a file under HANDOFF.d/ instead -->
  # HANDOFF

  Active handoffs live in [`HANDOFF.d/`](HANDOFF.d/) — one write-once file per AI
  session, named `<UTC-timestamp>-<machine>-<agent>-<slug>.md`.

  **Starting a session:** list `HANDOFF.d/`, read the open files **newest first**.
  Every file present is an OPEN workstream; finished ones are deleted (git history
  keeps the text).

  **Ending a session:** create your OWN new file in `HANDOFF.d/` following the
  handoff standard (all 9 sections). **Do not rewrite this file, and do not edit
  another session's file.** Concurrent sessions rely on that.
  ```

- **Never add `.gitattributes merge=union`** for handoffs. It unions lines with no
  understanding of Markdown, so it merges without a conflict yet yields a wrong
  file (two contradictory "current state" sections, duplicated next steps, one
  session's deletions silently undone). A loud conflict beats silent corruption.
- **Do not build an index or archive folder.** A generated index is the same shared
  mutable file one level up — sessions would clobber the index instead. Presence in
  `HANDOFF.d/` means open; deletion + git history is the archive.

### Legacy (un-migrated) repos

Most repos still have the OLD form. Detect it before writing:

1. No `HANDOFF.md` → nothing to migrate; write the pointer above alongside your
   first `HANDOFF.d/` file.
2. `HANDOFF.md` line 1 contains `handoff-pointer: v1` → already the pointer.
   Leave it entirely alone.
3. `HANDOFF.md` exists **without** that marker → **legacy full document**. Treat
   the whole thing as ONE open workstream:
   `git mv HANDOFF.md HANDOFF.d/<UTC>-<machine>-<agent>-legacy-migrated-handoff.md`
   (move the text **verbatim** — do not rewrite or summarize it), then create
   `HANDOFF.md` as the static pointer, then write your own separate session file.
   Migrate sibling legacy docs (`HANDOFF-<topic>.md`, a `fix_<topic>.md` used as a
   handoff) the same way when you touch them.

If another session might be mid-write in the same working copy and you cannot
tell, skip the migration: just add your own `HANDOFF.d/` file and note that
migration is still pending.

### Retention (automatic — never a manual chore)

- When a workstream is **genuinely proven done** (verified, committed, pushed,
  deployed as applicable), **delete its `HANDOFF.d/` file** in the same commit that
  finishes it. Git history preserves the text. Delete only work you can prove is
  done — normally only your own.
- **Presence = OPEN.** Session start reads only the files that are there.
- **If `HANDOFF.d/` holds more than 5 files, warn loudly** in the closing report:
  list them oldest-first with dates and ask which are actually finished. Silent
  accumulation buries a fresh developer under dozens of nine-section essays.

## Two modes

- **Mode A — WRITE:** produce or update a handoff. Follow the structure + gate below.
- **Mode B — JUDGE:** the user is asking whether an existing handoff is good
  enough. Re-read the actual file, grade it, and answer per § Answering the
  verification question.

## Required structure (use these 9 sections in YOUR `HANDOFF.d/` file; never drop one silently — write "N/A" + why if truly inapplicable)

Write for a developer who **walked in off the street this morning**: zero
knowledge of the app, the business, this session, this chat, or what failed. Make
them able to continue **as effectively as you can right now, with everything you
know**. If they'd have to ask you one question to proceed, that answer belongs in
the handoff. Default to TOO MUCH — too long costs minutes, too short costs a whole
session; those are not symmetric, so err long.

1. **What this application is** — plain English: what it does, who uses it, why.
   Repos, stack, where it runs (URLs, hosts).
2. **What we set out to do this session, and why** — goal in business terms + the
   technical objective + what triggered it (bug, feature, incident).
3. **Current state — what is true right now** — what works (verified how?);
   what is half-done and its EXACT state (files, `file:line`); what is not started;
   is the code committed / pushed / deployed, on which branch/environment.
4. **Everything we tried that did NOT work** — the most-skipped, most-important
   section. Each dead end: what we tried, why it seemed reasonable, how it failed,
   why. This is what stops the next session repeating your hours of mistakes.
5. **Root causes and key findings** — what you actually learned, with `file:line`
   refs and the non-obvious discoveries that each took you real time to work out.
6. **Exact next steps** — numbered, in order, specific enough to execute without
   judgment calls. Each ends with a verification gate: "you'll know it worked when ___."
7. **Constraints and gotchas in force** — standing rules (branch policy, no
   band-aids, concurrency, file-date preservation, etc.) and traps specific to this work.
8. **Access and environment** — which CLIs/MCPs are authenticated, which
   env/branch/URL, where secrets live (1Password vault name — NEVER the values).
9. **Open questions and risks** — what's uncertain, what could break, decisions
   made and why, each dated so a later session can't unknowingly contradict them.

## Comprehensiveness checklist (objective — every item must be YES)

This is what "comprehensive" means. It is a fixed bar, not a feeling. "It could
always be more detailed" is NOT a checklist item — do not treat it as one.

- [ ] All 9 sections present (or "N/A" + reason).
- [ ] A street-newcomer could continue **without asking a single question**.
- [ ] They could continue **as effectively as you can right now** — every
      non-obvious thing you learned this session is written down.
- [ ] The **failed attempts / dead ends** are included with why they failed.
- [ ] Every next step is concrete + has a "you'll know it worked when ___" gate.
- [ ] Every term, identifier, path, URL, and commit SHA a newcomer wouldn't know
      is defined or referenced.
- [ ] Commit/push/deploy status is explicit for each piece of work.
- [ ] Secrets are referenced by location only (vault/item), never by value.
- [ ] For a multi-workstream handoff: **your** workstream's section clears every
      bar above. (You are not responsible for re-auditing other sessions'
      sections, but do not claim the whole file passes if yours is thin.)

## Mandatory self-audit gate (Mode A — BEFORE showing the handoff)

After drafting, grade the handoff against the checklist above. If ANY item is
"no," expand and re-grade — loop until all pass. The FIRST version you present to
the user MUST already pass; do not show a draft you know is thin and plan to
improve after they push back. In your closing message, state that the self-audit
passed and name what makes it comprehensive (which section covers each dimension).

Write and answer the following three questions, citing the handoff sections that
support each answer:

1. Is my `HANDOFF.d/` file comprehensive enough that a brand-new developer with no
   project knowledge and no session context could pick up where I left off and
   not skip a beat?
2. Is it detailed enough that they could continue as well as I could right now,
   with all my session knowledge and the relevant background and purpose?
3. Is every single relevant detail needed for flawless execution included:
   background, goals, intended outcome, current state, failures, decisions,
   constraints, risks, exact next actions, and verification evidence?

Do not accept a bare "yes." For each answer, name the supporting sections and
any gap discovered. Fix every gap in the handoff, then reread and repeat the
whole audit until all three answers are evidence-backed yeses. Preserve the
final answers in the closing report or at the end of the handoff.

## Answering the verification question (Mode B — the reflex this skill fixes)

When the user asks whether the handoff is comprehensive/detailed/thorough enough:

1. **Re-read the actual handoff file first.** Never answer from memory — it may
   already be complete, or the relevant section may be someone else's.
2. **Grade it once against the checklist above** — the fixed bar, not a vibe.
3. **If every checklist item passes → answer "Yes."** Say so plainly, and show
   the evidence: map each audit dimension to the section that satisfies it. Then
   stop. Do not invent work. Do not append "but I could add more."
4. **Only answer "No" if you can name a SPECIFIC missing checklist item** — a real
   gap a newcomer would trip on (an undocumented dead end, a vague next step, a
   missing `file:line`, an unstated deploy status). Name it, fix exactly that,
   then re-grade and answer "Yes."
5. **Never answer "No, I'll improve it" as a reflex or a hedge.** "More detail is
   always possible" is not a deficiency; padding a passing handoff wastes the
   user's time and trains them to keep asking. A truthful "Yes" is the goal —
   reach it by making the handoff good, not by refusing to ever say it.

The bar for "Yes": a stranger could continue **as effectively as you can right
now**. If that is true, the answer is Yes — say it.

## Anti-patterns (why past handoffs were too thin)

- Assuming the reader knows what the app does or what "the X issue" refers to.
- Listing the final plan but omitting the failed attempts.
- "Continue where we left off" without saying where, in `file:line` terms.
- Vague next steps ("finish the migration") instead of exact, verifiable ones.
- Session jargon with no definition.
- Three sentences called a handoff. Under a screen of text for non-trivial work is
  almost certainly too thin — re-audit. (The per-session file does NOT lower the
  verbosity bar; all 9 sections and the "what did NOT work" section still apply.)
- **Rewriting the root `HANDOFF.md`, or editing/deleting another session's
  `HANDOFF.d/` file.** That is the concurrency data-loss bug this design removes.
- Reflexively answering "No, not comprehensive enough" to look diligent when the
  checklist already passes.

## Mechanics

- Write to your own new `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md`, commit and
  push — a handoff that lives only in chat is lost. See § FIRST above.
- In a concurrently-edited checkout, stage only your own file and your own hunks;
  never `git add -A` another session's uncommitted work.
- Your `HANDOFF.d/` file is deleted only when the work it describes is truly
  complete. Never delete another session's.
- Record infra/design decisions with dates so a later session can't contradict them.

---

_Canonical cross-tool standard: `templates/system/handoff-standard.md`
in the `ai-devops` repo. This SKILL.md is self-contained and does not depend on it
being checked out; keep the two in sync when either changes._
