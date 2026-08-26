# HANDOFF — false completion: sessions report "nothing is needed" while authorized work is pending (2026-08-26 11:27 UTC, edge-dev/claude)

- **Status:** OPEN — planning only. No implementation work has been done.
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
2. **If the eval (step 10) shows the existing wording works once Claude actually
   has it, is that the end of the workstream?** *Recommendation: no — keep the
   audit coverage, the eval, and the machine reconciliation (steps 3, 4, 9, 11).*
   Those are what let anyone tell whether a rule is in force and working; their
   absence is the proven root cause. Only the rewrite (step 2) gets dropped.

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

- 2026-08-26 — the fix is a package (get the existing rule into both clients +
  audit enforcement + Claude hook + behavioral eval), not another prose rewrite.
- 2026-08-26 — **measure before rewording.** Albert challenged the first draft:
  Claude never had the rule, so its wording is untested there. Any rewrite is
  now step 2 and is conditional on the step-10 measurement. The default is **no
  rewrite**. See the plan's "Order correction" note — do not reverse it.
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

- **Done this session:** diagnosis (five findings, section 5 below) and the
  implementation plan file. Nothing else.
- **Not started:** every one of the plan's twelve steps.
- **Files added on this branch:** `plan_completion-honesty-enforcement.md` and
  this handoff. No instruction file, tool, test, or wrapper was modified.
- **Committed/pushed:** see the PR referenced in the final session report; the
  branch is `claude/fix-misleading-instructions-f5be3d` off `eeb510f`.

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

The plan file holds all twelve steps with their verification gates. In short:

1. **Step 0** — run the two diagnostic commands on the machine Albert's failure
   came from and record the answer in this handoff.
   *You'll know it worked when:* the grep output and a one-line verdict
   ("current text" vs "stale text") are written down.
2. **Steps 1, 3, 4** — copy the **existing** rule text verbatim into
   `CLAUDE-global.md` (no rewrite), add it to `context-audit.py` as a safety
   category **and** a parity rule, extend `tests/test-context-audit.ps1`
   fixtures. **Step 2 (any rewrite) is skipped for now** — it is conditional on
   step 10.
3. **Steps 9–10 come next, before any rewrite** — build the eval and score the
   existing wording on both clients. That measurement decides whether step 2
   ever happens.
4. **Steps 5–7** — build `bin/ai-completion-check-hook` (Claude `Stop` hook,
   `stop_hook_active` loop guard mandatory, silent exit 0 on the common path),
   its installer, and its test.
5. **Step 8** — the Codex compensating pointer.
6. **Steps 11–12** — reconcile installed globals on every machine via
   `bin/ai-adopt-globals`, then docs, router row, memory entry, and delete this
   handoff once every STATUS row cites an artifact.

Do not start at step 5 because it looks like the real fix, and do not start with
a rewrite because the text reads improvably. Step 1 is nearly free, and step 0
can invalidate part of the diagnosis.

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
