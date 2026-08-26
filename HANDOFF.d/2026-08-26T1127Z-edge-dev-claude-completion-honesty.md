# HANDOFF — false completion: sessions report "nothing is needed" while authorized work is pending (2026-08-26 11:27 UTC, edge-dev/claude)

- **Status:** OPEN — the plan was implemented on 2026-08-26 except the new-text
  measurement and the machine rollout. Read the plan's STATUS table for exactly
  what is proven and what is not.
- **The plan is the brief:** [`plan_completion-honesty-enforcement.md`](../plan_completion-honesty-enforcement.md)
  — read its STATUS table first. Every row is open; a fresh session starts at
  step 0. Do not re-derive or re-plan.
- **Written:** 2026-08-26 (UTC) on `edge-dev` by Claude (Opus 5), branch
  `claude/fix-misleading-instructions-f5be3d`, base `eeb510f`.

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put this whole list to Albert in **one** message before starting work.

**BLOCKING** — none. The plan is authorized ordinary work in this repo and can
be executed end to end without a ruling.

**RECOVERABLE** (a wrong guess is fixable but wastes rework):

1. **Should a Claude `Stop` hook be installed on Albert's machines at all?**
   It is the only mechanical gate available, and prose alone has now failed
   twice. It can be noisy. *Recommendation: yes* — it is additive, reversible by
   deleting one settings entry, and step 9's control scenarios measure the noise
   before rollout. Ask only if Albert has said he dislikes hooks.
2. **If two successive rewrites fail to move a working eval, does Codex get a
   mechanical backstop after all?** Decision 6 (no Codex hook) was made while
   the wording still looked salvageable; Albert has since called Codex
   "borderline useless" on this. *Recommendation: ask only if it actually
   happens* — do not pre-emptively reopen it.

**NOT PART OF THIS WORK, AND NOBODY IS ON IT:**

3. **`templates/system/CLAUDE-global.md` never received the #72 response-style
   fix** (commit `cf90978`, 2026-08-25). That was a one-client edit that should
   have been two. Nobody noticed for a day because the parity audit matches the
   `# Response Style` heading, not the rule. The plan fixes both, but Albert
   should know that a *previous* rule change reached only half his tooling —
   there may be others. *Recommendation: after this plan lands, run one sweep of
   the last six months of global-instruction commits for the same one-sided
   pattern.* Not scheduled by anyone today.
4. **The delegated reviewer wrappers** (`ai-grok-review`, `ai-kimi`, `ai-glm`,
   `ai-muse`, `ai-gemini`, `ai-qwen`, `ai-deepseek-agent`) have their own
   history of reporting completion that did not happen — Grok returns exit 0
   with a 0-byte file while still working; GLM and Kimi have open
   incomplete-implementation recovery plans. This handoff's work does not touch
   them. *Recommendation: decide after step 10 whether the same closeout
   contract is worth pushing into the wrapper reporting layer.*

**Already settled — do NOT re-ask:**

- 2026-08-26 — the fix is a package (rewritten rule in both clients + audit
  enforcement + Claude hook + behavioral eval). The rewrite is required, but it
  never ships alone — that is what failed twice.
- 2026-08-26 — **the rewrite is required.** Two rulings landed the same day and
  the second governs: Albert first asked whether the wording was fine and merely
  unused (true for Claude, where it was never installed), then supplied the
  frequency evidence — the rule *was* live on Codex and Codex was "the much
  worse offender, to the point it was borderline useless." Sustained failure
  under live text is a failure of the text. Step 2 is not conditional. Read the
  plan's "Order history" note before touching the order — a session that sees
  only the first ruling will wrongly re-suspend the rewrite.
- 2026-08-26 — no approval loops. Nothing in this work may make a session ask
  permission to do work it was already told to do.
- 2026-08-26 — no Codex hook system will be built.
- 2026-08-21 — the dflow test login in this public repo's history is not being
  rotated. Unrelated, but it comes up in every public-boundary conversation.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public AI toolkit repo. Not a deployed
product. It owns the always-loaded instruction files every AI session reads at
startup (`templates/system/CLAUDE-global.md` → `~/.claude/CLAUDE.md`;
`templates/system/AGENTS-global-codex.md` → `~/.codex/AGENTS.md`), the skills
library, the `bin/` wrappers, the context-audit enforcement tool, and the test
suites. Users: Albert plus every AI session on `edge-dev` (Ubuntu, primary),
`al8960ofc` / `albt16` (Windows), and `hetz` (VPS). Work lands on `main` via a
PR that the session itself merges.

## 2. What we set out to do this session, and why

Albert reported, 2026-08-26, that he is **still** getting replies telling him a
job is finished when it is not — pasting a Codex reply that admitted "'Nothing
is needed from you now' was misleading because the scrape was still unstarted …
I should have continued the authorized work." He asked for an implementation
plan to fix the instructions, explicitly **not** the work itself.

Business goal: Albert must never be told a job is done when it is not, and a
session with authorized work left must keep working rather than end the turn.

## 3. Current state — what is true right now

**Done and proven (steps 0-9, evidence in the plan's STATUS table):** the
rewritten closeout contract is byte-identical in both globals; `context-audit.py`
enforces it as a safety marker plus three parity rules and demonstrably fails
when either global loses it; `bin/ai-completion-check-hook` and its installer
exist with 33 passing assertions; `skills/codex/codex-session-closeout` carries
the Codex pointer; `tools/completion-eval/` exists with old-text baselines.

**Live on `edge-dev` only:** the Stop hook is installed and returns
`decision: block` on a false completion through its installed copy. Nothing else
on this machine changed — the settings diff shows only the added Stop entry.

**NOT done, and nobody may claim otherwise:**

1. **The rewritten globals are not adopted on ANY machine.** The repo has the new
   text; every machine still runs the old. `bin/ai-adopt-globals` is the route.
2. **There is no new-text measurement.** Only old-text baselines exist. The
   rewrite rests on the owner ruling and observed behaviour, not on a measured
   improvement.
3. **The eval's scorer is not trustworthy yet** — see section 9.

**Committed:** on branch `claude/completion-honesty-implement`; see the PR in the
session report.

## 4. Everything we tried that did NOT work

Nothing was tried this session — it was planning only. But the *repo* has two
failed attempts at this exact rule, and they are the reason the plan is shaped
the way it is:

- **`22f5411` — "make the response-style rules enforceable" (#50).** Rewrote the
  response-style contract. The failure class continued.
- **`cf90978` — "Make Codex surface blockers and asks without being prompted"
  (#72), 2026-08-25.** Added the four bullets now at
  `AGENTS-global-codex.md:7-18` ("Never make Albert ask what's next…", "say
  plainly that nothing is needed…"). Albert's failure report came **one day
  later**, and the installed Codex global on `edge-dev` was verified to already
  contain that text. Prose alone, twice, did not hold.

The plan's section 7 records five further approaches considered and rejected
this session (ban the phrase outright, unconditional Stop hook, confirm-before-
ending, force-overwriting installed globals, wrapping the Codex binary) with the
reason each fails. Read it before "improving" the plan.

## 5. Root causes and key findings

- **F0 — the wording is established as inadequate on Codex, not merely
  suspected.** The rule was live and current there, and Albert's frequency
  report is that Codex was "the much worse offender, to the point it was
  borderline useless." A sustained pattern under live text convicts the text.
  Claude, by contrast, never had the rule at all (F3), so nothing is known about
  the wording there — keep a Claude arm in the eval and do not assume the Codex
  diagnosis transfers wholesale. Codex also gets no mechanical backstop, so on
  that client the wording is the only defense there is.
- **F1 — the rule is disclosure-shaped; the failure is a belief failure.**
  `AGENTS-global-codex.md:7-11` asks a session to check whether the work is
  finished and say so if not. The failing session did that and sincerely
  believed it was finished, because it had quietly narrowed the task. A
  self-report cannot catch a wrong self-belief; the check must be against an
  external object — the deliverables the request named.
- **F2 — nothing says "keep working."** Every clause governs what to *say*, none
  says that ending a turn with authorized work outstanding is itself the error.
- **F3 — Claude never got the rule.** Verified 2026-08-26 on `edge-dev`:
  `grep -c "Never make Albert ask" ~/.codex/AGENTS.md ~/.claude/CLAUDE.md` →
  `1` and `0`. Two clients, two different behavioral contracts.
- **F4 — the parity audit was blind to it.**
  `tools/context-audit/context-audit.py:83` `PARITY_RULES` matches
  `^# Response Style` — a heading — so the two globals diverged on the actual
  rule while the audit stayed clean.
- **F5 — the enforcement surfaces already exist and are unused for this.**
  `SAFETY_MARKERS` (line 33) has eight locked categories and no completion
  category; `bin/ai-install-memory-hook` is a working precedent for installing a
  Claude hook idempotently and additively; `tools/skill-trigger-eval/` is a
  working precedent for scored evals (trigger accuracy only — there is no
  behavioral eval in the repo today).

## 6. Exact next steps

**Read the plan's STATUS table and its numbered remaining-work block first.**
This section is the short form of it; the plan governs.

1. **Merge the PR on branch `claude/completion-honesty-implement`** (six
   commits). It was queued behind ~12 other org CI runs for 2+ hours on
   2026-08-26 — Actions contention, not a branch fault. One earlier run passed;
   one hit a transient runner `startup_failure`, so rerun rather than debug.
   The repo now has a **merge queue**: `--squash --delete-branch` is refused, so
   run plain `gh pr merge <n>` and let the queue take it. Delete the remote
   branch afterwards. Albert does not merge — the session does.
   *You'll know it worked when:* `gh pr view <n> --json state` says MERGED and
   the merge commit is reported to Albert.

2. **Adopt the globals on every machine** — `bin/ai-adopt-globals`, never
   `--adopt-globals` by hand. Nothing has adopted them: the repo carries the
   rewritten closeout rule, every machine still runs the old text. Verify with
   `grep -c "Account for the whole job" ~/.claude/CLAUDE.md ~/.codex/AGENTS.md`
   — both must return >= 1. `installed source drift: 2` is SUCCESS on a machine
   that has a machine section. Machines: `edge-dev`, `al8960ofc`, `albt16`,
   `hetz`. Name any you cannot reach rather than implying full coverage.

3. **Close out:** tick step 11's STATUS row with the machines actually reached,
   then delete this handoff file. Do not hunt for eval results — step 10 is
   closed by owner ruling.

**Not in this workstream, and nobody is on either:** the one-sided-rule sweep
(section 0 item 3) and the reviewer wrappers' own false-completion history
(section 0 item 4). Both are separate sessions.

## 6b. What this session did AFTER the plan was written

The plan was written first, then most of it was implemented the same day, so the
prose sections below (7-9) describe the planning state. What actually landed:

- The rewritten closeout contract in **both** globals, byte-identical.
- `completion honesty` as a safety marker + 3 parity rules in
  `tools/context-audit/context-audit.py`, proven by deletion.
- `bin/ai-completion-check-hook` + installer + 36 tests. **It shipped with two
  defects that were caught in use within the hour and fixed:** it only knew the
  phrase "nothing is needed", so real closings like "Nothing right now" passed
  silently; and it scanned the whole message, so a reply *quoting* the phrase
  tripped it. It now judges the closing paragraphs. Both cases are locked in
  tests.
- `tools/completion-eval/` + old-text baselines. **Its finding matters: the
  scenarios cannot reproduce the failure** — they tell the model what is
  unfinished, while the real failure is not noticing. Codex on the old text and
  Claude with no rule both scored zero. Owner then closed measuring.
- **Unrelated but landed in the same branch:** `bin/ai-memory-health`'s index
  size check now runs in `--coverage-only` (the only mode `bin/ai-memory-sync`
  gates on) and the limit dropped 25KB -> 12KB. This came out of a GLM 5.3
  review that REJECTED a proposal to trim the memory index: `bin/ai-sync-memory`
  keys its union on full line text, so rewritten lines are appended, not
  replaced — a trim would have doubled the index. Do not retry that trim.

## 7. Constraints and gotchas in force

- Public repo — no secrets, no private paths; run `tests/test-public-boundary.sh`.
- Branch → PR → **the session merges it**. Albert does not merge. The
  `'main' is already used by worktree` error from `gh pr merge` fires *after* a
  successful merge; confirm with `gh pr view <n> --json state`.
- `git var GIT_COMMITTER_IDENT` must show
  `Albert Hazan <u2giants@users.noreply.github.com>` before the first commit.
- Concurrent sessions edit this repo: stage only your own files, never
  `git add -A`, never bare `git stash` / `git stash pop`.
- Installed globals are deliberately never auto-overwritten; use
  `bin/ai-adopt-globals`, never `--adopt-globals` by hand.
  `installed source drift: 2` is SUCCESS on a machine with a machine section.
- Preserve the capability: if the hook is noisy, tune it — do not delete it and
  call that a fix, and do not weaken the instruction to make an eval pass.
- One owner per rule. The contract lives in the globals; everything else is a
  pointer. `.ps1` files must be pure ASCII. Bash suites in Git Bash, PowerShell
  suites in `pwsh`.

## 8. Access and environment

Repo `u2giants/ai-devops` (public), working copy `C:\repos\ai-devops`; this
session used the worktree `.claude/worktrees/fix-misleading-instructions-f5be3d`.
Authenticated and available: `gh` as `u2giants`, the 1Password CLI/MCP (vault
`vibe_coding` — **no secret is needed for any step of this plan**), the Codex
CLI, and the `bin/` reviewer wrappers. Run `python3
tools/context-audit/context-audit.py`, `bash tests/test-all.sh`, and `pwsh
tests/test-all.ps1` from the repo root. Nothing here is deployed; "shipped"
means merged to `main` with suites green and the installed globals updated.

## 9. Open questions and risks

**The eval scorer is the weak link, and it is proven weak.** Its keyword
classifier misclassified 6 of 24 replies on the first baselines — a correct
"Nothing outstanding on this one" read as hedging, and a correct "The fix is not
finished yet, I am merging it now" read as a false completion. Five are fixed
and locked in `tests/test-completion-eval.sh`; one remains (a pending word inside
unrelated mid-answer prose). The plan's own criterion was to escalate to a
rubric-scored model judge if the cheap scorer misclassified a hand-labelled
sample. It did. **Escalate before quoting any number from this tool.**

**Floor effect on the Claude arm.** With NO closeout rule installed, Claude
produced zero false completions across all eight pending scenarios. Either the
narrated proxy is too easy on that client or its base behaviour is already
correct there. Either way the Claude arm cannot show improvement, so do not read
a flat Claude score as "the rewrite did nothing". The Codex arm is the one that
carries signal — Codex is where the failure was observed.

**Budget warning, worsened deliberately.** The always-loaded globals were already
over their 12449-byte warning budget before this work (14754 bytes) and are now
16340. Budgets warn only, never fail. Claude gained a rule it never had, which is
most of the increase.


- **Did the failing session run current or stale global text?** Step 0 decides
  it. If stale, finding F1 is partly wrong and the weight shifts to rollout
  (step 11) — correct section 6 of the plan in place rather than appending.
- **Does the Claude `Stop` hook payload actually expose the final assistant
  message?** Must be confirmed against current hooks documentation in step 5.
  If not, the hook degrades to firing on every turn end, which is too noisy —
  drop it, say so explicitly, and rely on the instruction plus the eval. Do not
  fake it by scraping a transcript file.
- **The eval may show no improvement.** That is information, not failure. Step
  10 requires reporting it rather than merging as if it worked — which is
  precisely the failure mode this whole workstream exists to kill.
- **Risk: hook noise or a stop loop.** Mitigated by the `stop_hook_active`
  guard, exit-0-on-error, and the control scenarios. Rollback is deleting one
  additive settings entry.
- **Risk: context growth.** The new block is capped at 10 lines and replaces
  four existing Codex bullets; budgets warn if it still grows.
- **Decision recorded 2026-08-26:** Codex gets no hook. Instruction + eval only.
  Do not contradict this in a later session without new evidence.
