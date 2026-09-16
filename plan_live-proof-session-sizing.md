# IMPLEMENTATION PLAN — one unproven live-proof outcome per session (2026-09-16)

**Tracking issue:** [popcre/ai-devops #511](https://github.com/popcre/ai-devops/issues/511)
**Handoff:** retired 2026-09-16. The original handoff and the temporary PR #520 handoff were deleted after their obligations were incorporated here.
**Branch for the source-rule follow-up:** `grok/511-no-deferred-proof-dump` in [PR #520](https://github.com/popcre/ai-devops/pull/520).

Related: [popcre/ai-devops #401](https://github.com/popcre/ai-devops/issues/401), [u2giants/shared-db #3027](https://github.com/u2giants/shared-db/issues/3027) (non-orchestrator), [u2giants/shared-db #3028](https://github.com/u2giants/shared-db/issues/3028) (non-orchestrator, CLOSED), [u2giants/shared-db #3029](https://github.com/u2giants/shared-db/issues/3029) (non-orchestrator).

## STATUS — read first

The original refuse-bundle work is complete. The source-rule follow-up is implemented on PR #520 but is not accepted until exact-head review, merge, and installed-global proof. Remaining leftover proofs stay with live [shared-db#3027](https://github.com/u2giants/shared-db/issues/3027) (non-orchestrator); do not start a second chat on them.

| # | Step | State | Date | Evidence |
|---|---|---|---|---|
| 0 | Confirm the gap still exists on current `origin/main` | ✅ complete | 2026-09-16 | `origin/main` `82216ba3` had no `one unproven live-behavior outcome` in `templates/system/`; #401 still named [shared-db#3027](https://github.com/u2giants/shared-db/issues/3027) on Steps 1, 2, 2A, 3, 4, 6, and 7. |
| 1 | Add the locked sentence to both globals | ✅ complete | 2026-09-16 | Phrase present unwrapped in both `templates/system/CLAUDE-global.md` and `templates/system/AGENTS-global-codex.md`. |
| 2 | Guard the phrase in the cheap Linux test and in parity audit | ✅ complete | 2026-09-16 | Phrase added to `tests/test-client-globals-required-phrases.sh` and `PARITY_RULES` in `tools/context-audit/context-audit.py`. |
| 3 | One sentence in `shared-db-handover` | ✅ complete | 2026-09-16 | Skill says leftover live proofs are one issue and one session each, and still says proofs never go to the orchestrator. |
| 4 | Stop #401 STATUS from dumping several unproven steps on one ticket | ✅ complete | 2026-09-16 | 3027 session live at 2026-09-16T20:18Z (helper PR [shared-db#3101](https://github.com/u2giants/shared-db/pull/3101) updating; transcript 20:09Z). Split forbidden. Legend added. Posted proofs on Steps 1 and 2A stay with 3027. Remaining unproven Steps 2, 3, 4, 6, 7 stay with 3027 with “No further steps may be added to #3027.” 3029 not started. |
| 5 | Keep routers pointing here; merge; install globals | ✅ complete | 2026-09-16 | PR #515 merged as `837fe41d`. Installed Claude and Codex globals on edge-dev contain `one unproven live-behavior outcome`. #511 closed. |
| 6 | Prevent later live-proof dumps at the source | 🟡 partial | 2026-09-17 | PR #520 adds `Never save several unproven steps` to both globals and the handover rule. Not yet on `origin/main` or installed. |
| 7 | Require one live-proof owner when code lands | 🟡 partial | 2026-09-17 | PR #520 adds `opened when that code landed` to both plan-writer sources and guards both new rules. Not yet on `origin/main`. |
| 8 | Review, merge, install, and close | ⬜ open | 2026-09-17 | Rebase and focused validation are owned by the PR repair; exact-head independent review, merge queue, installed proof, and issue close remain. |

**Fresh-session starting point:** Step 8 on PR #520 after its rebased head passes focused validation. Do not re-implement Steps 1–7. 3027 leftover proofs are not this plan’s work.

---

# Part 1 — Why

## 1. The ultimate goal — what we are trying to achieve

Albert should be able to ask a chat to finish one leftover proof and get that one proof, not an eight-hour manager of helpers that never ships.

Today, leftover “prove it works live” work can be stuffed into one ticket and one chat. That chat then tries to rebuild broken features, review them, merge them, and prove them all at once. Albert sees waiting, questions he cannot answer, and nothing finished.

When this is done: a chat that is handed several leftover proofs **refuses the bundle**, or splits it, instead of pretending it is one job. The #401 scoreboard does not point several unproven steps at one ticket. The chat that already owns 3027 is not robbed of its remaining work.

**If any step below conflicts with this goal, the goal wins — stop and flag it.** In particular: do not weaken merge-safety checks, do not drop “prove it live,” and do not take over 3027’s remaining product work under this issue.

## 2. What this application is

`popcre/ai-devops` is Albert Hazan’s public recovery toolkit for a multi-model AI workflow. It is not an app, service, database, container stack, or deployment pipeline.

- **Repo:** `popcre/ai-devops`. Canonical local checkout `C:\repos\ai-devops` is landing-only.
- **This plan’s files live only here.** `u2giants/shared-db` is named because the eight-hour chat ran there; this plan does not change shared-db product code.
- **Target branch:** `main`, via a feature branch and pull request. Protected `main` uses a merge queue.
- **Stack:** Markdown globals and skills, Bash tests, Python context-audit. No UI.
- **Where “installed” means:** `templates/system/CLAUDE-global.md` → `~/.claude/CLAUDE.md`; `templates/system/AGENTS-global-codex.md` → `~/.codex/AGENTS.md`, via `bin/ai-adopt-globals`. Source on `main` is not enough until that install runs.
- **Git identity:** `Albert Hazan <u2giants@users.noreply.github.com>` (`git var GIT_COMMITTER_IDENT` before the first commit).

## 3. What triggered this work

On 2026-09-16 Albert opened a Claude chat named **Issues #3027, #3028, #3029 to production** and said: confirm this is not orchestrator work, then complete those three tickets through to production.

The chat ran about eight hours (11:27Z–19:38Z) on machine `edge-dev`. Transcript (private, do not commit): `C:\Users\ahazan\.claude\projects\C--repos-shared-db--claude-worktrees-issues-3027-3028-3029-prod-f35ee9\8acb349f-c36a-4c69-b7af-e806e7906714.jsonl`.

End state checked live 2026-09-16: 3028 CLOSED by another chat; 3027 OPEN; 3029 OPEN and never started. Albert asked what went wrong and whether https://github.com/popcre/ai-devops and https://github.com/u2giants/shared-db can fix it, then asked for this plan.

Plain-English diagnosis (not in git; do not commit transcripts): `C:\Users\ahazan\.grok\tmp\what-went-wrong-3027.md`.

## 4. Scope — in and out

**In this plan**

- One standing rule: a session owns one unproven live-behavior outcome.
- Cheap tests so the phrase cannot be dropped or line-wrapped.
- One sentence in the shared-db handover skill so leftover proofs are not bundled when filed.
- Stop the #401 STATUS table from pointing several unproven steps at 3027, without stealing work from a live 3027 session.
- Router links so the next session finds this plan.

**NOT in this plan**

- Finishing shared-db batch production ( #401 Step 6 ) or “swap a reviewer that never starts” ( #401 Step 7 ). Those stay with 3027 / #401.
- Writing 3029’s five-outcome trial report.
- Weakening exact-head merge, required checks, or live-proof acceptance.
- Re-doing already-landed 2026-09-16 rules: orchestrator-only-shape-work (#500), stalled-subagent restart and quoted authority and Grok production approvals and prose verification skip (#508), live-path-before-proof and owned waits and no colliding parallel agents (#509).
- New tools, memory files, harnesses, or a second orchestrator.
- Asking Albert to approve production.
- Editing the still-running 3027 chat’s worktrees or branches.

**Why a new plan, not a #401 rewrite (#168).** #401 is the throughput programme. Stuffing “how leftover proofs are packaged” into it is how 3027 happened. This plan owns session job-sizing. Retirement: when #511 is closed and the STATUS table no longer dumps several unproven steps on one issue, keep this file as a decision record and delete its handoff.

---

# Part 2 — What we already know

## 5. Current state of the code

✅ UPDATED 2026-09-17 — PR #515 (`837fe41d`) and its installed last-line defense remain complete. #511 was reopened because refusing a later bundle did not prevent earlier sessions from creating the pile. PR #520 owns only that source-side follow-up.

**Already on main, works, do not rewrite**

- Orchestrator gets only database-shape work: `skills/shared/shared-db-handover/SKILL.md:10-18` and both globals (PR #500, `e67d959d`).
- Stalled subagent restart, quote Albert’s exact words, Grok/independent-reviewer production approvals, prose verification skip: `templates/system/CLAUDE-global.md` (PR #508, `f60a78ad`). Codex copy in `templates/system/AGENTS-global-codex.md`.
- Trace live path before a proof; `Waiting on —` must name owner and last activity; overlapping files go to one agent in sequence: PR #509, `2719315e`.
- Cheap phrase guard includes `one unproven live-behavior outcome` (must stay unwrapped).
- Cross-client parity map includes `"one unproven outcome per session"`. Adding another `PARITY_RULES` key also requires the same phrase in `$parityLines` in `tests/test-context-audit.ps1` (see `docs/development.md`).
- Handover skill: one issue and one session per leftover proof; proofs still never go to the orchestrator.
- #401 legend: a Live proof owner cell names at most one unproven step and one issue. Remaining unproven 3027 rows say no further steps may be added. Posted proofs on Steps 1 and 2A stay with 3027.

**On PR #520, not yet accepted**

- Both globals say that code landing without live proof creates exactly one leftover-proof issue for that step in the same session and never saves several unproven steps for a later chat.
- Both implementation-plan sources require a `code landed, not accepted` row to name that one owner issue when the code lands.
- The handover skill, required-phrase test, parity map, and Windows parity fixture carry the same rule.

**Not this plan’s work (do not take over)**

- 3027 leftover proofs (non-orchestrator) stay with that live owner.
- 3029 five-outcome trial is not started.

**Untouched by this plan**

- shared-db production-train code, reviewer-reroute wiring, merge-queue settings.

## 6. Key findings and root cause

**Ultimate source:** a split definition of done. Implementation chats treated merged code as finished. The programme treated live proof as finished, but saved that proof for later. Later, leftover proofs were stuffed into three tickets, and Albert asked one chat to take all three to production. Two “merged” features had never been able to run, so “prove it” meant rebuild, review, merge, then prove.

Evidence:

- #401 STATUS legend already says 🟨 means “code landed, not accepted” (`plan_shared-db-complete-throughput-repair.md:24-26`). The scoreboard knew. The packaging still pointed seven steps at 3027.
- 2026-09-16 routing comment on those issues labelled them orchestrator work even though they do not change database shape. The 3027 chat froze until Albert overrode it. #500 later forbade that routing; this plan does not repeat #500.
- The 3027 chat spawned eight helpers, messaged other sessions 19 times, and wrote one file in the parent. Helpers stopped to “wait” at least four times. Parallel helpers plus exact-head merge caused seven redo cycles in 2.5 hours. Those are symptoms. #508/#509 already cover helper-wait, quoted authority, owned waits, and colliding files.
- **The gap this plan closed:** nothing told a session to refuse a bundle, and the scoreboard pointed seven unproven steps at one ticket. Do not reopen that packaging.
- **The source gap PR #520 closes:** nothing required the session that landed unproven code to create its one proof owner immediately. Refusing a later bundle alone still allowed the pile to be created.

**Do not confuse this with “the merge process is too slow.”** Exact-head merge is how colliding work is stopped. The fix is one worker and one unproven outcome, not a weaker merge.

## 7. Approaches considered and REJECTED, and why

1. **Fold this into #401 and keep 3027 as the single live-proof owner.** Rejected 2026-09-16. That packaging *is* the failure. #401 stays the throughput programme; this plan owns job-sizing.
2. **Have this plan finish Step 6 and Step 7 in shared-db.** Rejected 2026-09-16. A live 3027 session and its helpers already own that work. A second owner would collide again.
3. **Weaken exact-head merge or skip reviewers so proofs land faster.** Rejected 2026-09-16. That is how fake-done code shipped. Live proof found the batch feature could not run.
4. **Drop live proof and accept merged code.** Rejected 2026-09-16. Same fake-done failure.
5. **Add a new tool or memory file that tracks session size.** Rejected 2026-09-16. Albert’s standing bar is one sentence, no new moving parts. Globals + scoreboard packaging are enough.
6. **Ask Albert to approve production canaries.** Rejected. Owner ruling 2026-09-16 already sends those approvals to an independent reviewer (`templates/system/CLAUDE-global.md` production-safety bullet). Do not re-ask.
7. **Split 3027 into new issues while its session is still working.** Rejected unless Step 0/4 prove that session is idle. Stealing live work is how collisions start.

## 8. Design decisions already made (dated)

**LOCKED — do not relitigate**

- 2026-09-16: one unproven live-behavior outcome per session. Exact sentence is in §9 Step 1. Do not paraphrase it into a paragraph.
- 2026-09-16: do not steal remaining 3027 work from a live session. If that session is live, Step 4 only forbids *adding more* steps to 3027.
- 2026-09-16: do not weaken merge-safety or drop live proof.
- 2026-09-16: production technical approvals go to an independent reviewer, not Albert.
- 2026-09-16: proofs, reports, and tooling never go to the shared-db orchestrator (#500).
- 2026-09-16: this plan does not implement shared-db product fixes.
- 2026-09-16: both Claude and Codex globals get the same sentence; the required phrase must not wrap across lines (#209).
- 2026-09-16: when code lands without live proof, its session files exactly one leftover-proof owner issue for that step; several unproven steps are never saved for a later chat.

**OPEN — implementer’s judgment**

- Exact GitHub issue titles if Step 4 opens new leftover-proof issues (one step each, labelled non-orchestrator in the body).
- Whether to install globals on every in-scope machine in this same session or only on `edge-dev` and leave fleet sync to the supported route. Prefer: install on the machine that implements, then run the supported sync; do not invent a second installer.

---

# Part 3 — How to build it

## 9. The plan — numbered, ordered steps

Declare `ai-task-gates start --class code` before Step 1 (globals + test + skill). Recheck with `ai-task-gates check --before ship` before the PR wait. If you only edit this plan file, that is prose; this implementing work is code.

### Step 0 — Confirm the gap

**Depends on:** nothing.
**Files:** none written.
**Do:**

```powershell
git fetch origin
git grep -n "one unproven live-behavior outcome" origin/main -- templates/system/
git grep -n "Live proof owner (routed 2026-09-16): \[shared-db#3027\]" origin/main -- plan_shared-db-complete-throughput-repair.md
```

**You’ll know it worked when:** the first grep is empty and the second still lists several rows. If the first grep already matches, close #511 with the commit that added it and stop.

### Step 1 — Add the locked sentence to both globals

**Depends on:** Step 0.
**Files:**

- `templates/system/CLAUDE-global.md` — new bullet immediately after the **Start immediately.** bullet (after line 112 on `9b205e22`).
- `templates/system/AGENTS-global-codex.md` — same place (after line 94 on `9b205e22`).

**Insert this exact bullet, one line, do not wrap the marked phrase:**

```
- **One unproven outcome per session.** A session owns one unproven live-behavior outcome; refuse a bundle of leftover proofs or "take tickets N, M, and P to production" as one job — split them first, or stop and say the job is too big.
```

The phrase `one unproven live-behavior outcome` must appear on one physical line in both files.

**Behavior when done:** a new chat handed 3027+3028+3029 as one job splits or refuses instead of starting eight helpers.

**You’ll know it worked when:** `git grep -n "one unproven live-behavior outcome" templates/system/CLAUDE-global.md templates/system/AGENTS-global-codex.md` prints one hit in each file, and neither line is split.

### Step 2 — Guard the phrase

**Depends on:** Step 1.
**Files:**

- `tests/test-client-globals-required-phrases.sh` — add `"one unproven live-behavior outcome"` to `required_phrases` after line 34.
- `tools/context-audit/context-audit.py` — add to `PARITY_RULES` (after line 128 is fine): `"one unproven outcome per session": r"one unproven live-behavior outcome",`

**You’ll know it worked when:** Git Bash `bash tests/test-client-globals-required-phrases.sh` prints `PASS: Claude and Codex globals carry the required autonomy phrases, unwrapped`. Temporarily wrapping the phrase in one global must fail that script. Context-audit `--strict` must not report this rule as a mismatch.

### Step 3 — Handover skill, one sentence

**Depends on:** Step 0 (can run with Step 1).
**File:** `skills/shared/shared-db-handover/SKILL.md` after the sentence that ends “When in doubt, it does not go to the orchestrator.” (currently lines 16–17).

**Insert:**

```
When you keep leftover live-proof work, open one issue per unproven step and start one session per issue. Do not bundle several leftover proofs into one ticket or one chat.
```

**You’ll know it worked when:** `git grep -n "one issue per unproven step" skills/shared/shared-db-handover/SKILL.md` hits, and the skill still says proofs are never sent to the orchestrator.

### Step 4 — #401 STATUS packaging

**Depends on:** Step 0, and a live liveness check of 3027.
**File:** `plan_shared-db-complete-throughput-repair.md` STATUS table and legend (lines 7–33).

**Do, in order:**

1. Check whether the 3027 session is still live: look at `C:\Users\ahazan\.claude\projects\C--repos-shared-db--claude-worktrees-issues-3027-3028-3029-prod-f35ee9\8acb349f-c36a-4c69-b7af-e806e7906714.jsonl` last timestamp, and whether its helpers still have open PRs they are updating. Do not kill that session.
2. Add this sentence to the STATUS legend (after the existing legend paragraph, before “Acceptance audit”):

   `A Live proof owner cell names at most one unproven step and one issue. Do not route a new unproven step onto an issue that already owns a different unproven step. Session job-sizing: plan_live-proof-session-sizing.md (#511).`

3. **If the 3027 session is live:** do not open replacement issues. For rows whose live proof is already posted on 3027, leave the owner as 3027. For rows still unproven (at last check, Steps 6 and 7, maybe others — re-read 3027 comments), keep 3027 as owner and add: `No further steps may be added to #3027.` Do not start a second chat on those steps.
4. **If the 3027 session is idle** (no assistant/tool activity and no helper PR updates for >30 minutes, and Albert has not told it to continue): open **one** new `u2giants/shared-db` issue per remaining unproven step. Each issue body must say it is **non-orchestrator** work. Point that STATUS row at the new issue. Comment on 3027 that remaining unproven steps moved, with links. Do not close 3027 until its already-posted proofs are recorded on the #401 row they belong to.
5. 3029 stays blocked until every 🟨/⬜ #401 step that 3029 depends on is ✅. Do not start 3029 from this issue.

**You’ll know it worked when:** no STATUS cell assigns two different unproven steps to the same issue as *new* work, and you can point to either the liveness evidence that forbade a split or the new per-step issues.

**Judgment call:** idle vs live. If unsure, treat it as live.

### Step 5 — Routers, merge, install

**Depends on:** Steps 1–4.
**Files already linked by the planning commit:** `AGENTS.md` task-router table, `docs/task-router.md`. Confirm those rows still exist after rebase onto current `origin/main`.

Then:

1. Commit only task-owned files. Push. Open a PR to `main` titled like `fix(#511): one unproven live-proof outcome per session`.
2. This change set includes globals, a test, a skill, and Python — **not** documentation-only. Wait with `bin/ai-pr-wait <pr>`. Merge through the queue. Confirm the squash commit on `origin/main`.
3. Install: `bin/ai-adopt-globals` on this machine (installation class; #511 plus Albert’s “write up a plan to implement” and this plan’s Step 5 are the owner request to install the new global sentence). Preserve machine sections. Verify:

   ```powershell
   Select-String -Path "$env:USERPROFILE\.claude\CLAUDE.md","$env:USERPROFILE\.codex\AGENTS.md" -Pattern "one unproven live-behavior outcome"
   ```

**You’ll know it worked when:** `origin/main` contains the phrase, the PR is merged, both installed globals contain the phrase, and #511 comments with the merge commit SHA.

**Context cut:** if context is full after Step 4, stop, update this STATUS table, and let a fresh session do Step 5 from the handoff.

### Step 6 — Prevent the dump at its source

**Depends on:** the completed Steps 1–5.
**Files:** both global templates and `skills/shared/shared-db-handover/SKILL.md`.
**Do:** add one matching global rule: when code lands without live proof, open exactly one leftover-proof issue for that step in the same session; never save several unproven steps for a later chat. Keep proofs out of the shared-db orchestrator.
**You’ll know it worked when:** `git grep -n "Never save several unproven steps" templates/system/CLAUDE-global.md templates/system/AGENTS-global-codex.md` finds one unwrapped line in each file.

### Step 7 — Make the plan writer assign the owner immediately

**Depends on:** Step 6.
**Files:** `templates/system/implementation-plan-standard.md`, `skills/shared/implementation-plan-writer/SKILL.md`, and the existing phrase/parity guards.
**Do:** require each `code landed, not accepted` STATUS row to name exactly one live-proof owner issue opened when that code landed. Guard `Never save several unproven steps` in the required-phrase test, parity map, and Windows parity fixture.
**You’ll know it worked when:** both plan-writer sources contain `opened when that code landed`, and the focused global/context tests pass.

### Step 8 — Review, merge, install, close

**Depends on:** Step 7 and focused validation.
**Do:** obtain a read-only exact-head independent review because installed routing rules change; merge through the normal queue; verify current `origin/main`; run `bin/ai-adopt-globals`; verify both installed globals contain `Never save several unproven steps`; comment the merge SHA; then the issue-opening session closes #511. Do not create or take over any current leftover-proof ticket.
**You’ll know it worked when:** the phrase is on current main and in both installed globals, the temporary handoff is absent, and #511 is closed with the merge SHA recorded.

## 10. Tests required

Add no other tests beyond the existing phrase and parity guards.

- **Must add:** the one phrase in `tests/test-client-globals-required-phrases.sh` as named in Step 2.
- **Must stay green:** `bash tests/test-client-globals-required-phrases.sh` via Git Bash on Windows.
- **Must stay green:** the existing context-audit required-check path that uses `PARITY_RULES` (the Windows `tests/test-context-audit.ps1` suite is *not* required on every prose-adjacent PR, but adding a `PARITY_RULES` key is the Linux-cheap equivalent for this rule; run `python tools/context-audit/context-audit.py --root . --strict` if it finishes in this session, and do not fail closed on budget warnings unless this edit caused a new budget breach — if it did, shorten nothing else; say so on #511).
- **Must stay green for PR #520:** the required-phrase test, `tests/test-context-audit.ps1`, strict context audit, and Markdown reachability validation.
- Do not run a local full Windows reviewer series. Check `bin/ai-test-local --check-collision` before any local full suite; a busy self-hosted runner on this host is a stop for that suite only.

**Ran 2026-09-16:** phrase test PASS; wrap-fail then restore PASS; `python tools/context-audit/context-audit.py --root . --strict` 0 parity mismatches. Pre-existing always-loaded budget warning remained (42341 vs 12449); one bullet added; no other rules deleted. First PR #515 Windows section 3 failed because `$parityLines` lacked the new phrase — not a 30-minute runner timeout. Fixture fix then passed.

## 11. Constraints, standing rules, and gotchas in force

- Branch and PR; never push to `main`. Merge through the queue. Albert does not merge.
- Stage only task-owned files. This machine’s `claude-trancsript` worktree has unrelated deletes; do not commit them.
- Canonical `C:\repos\ai-devops` is landing-only.
- Globals: one owner per rule (`docs/context-spec.md`). This new rule lives in the globals. Routers carry only a path plus trigger.
- Do not wrap the required phrase (#209).
- Do not bulk-load Markdown. Read this plan’s STATUS, then only the files a step names.
- Shared-db structure changes stay in `u2giants/shared-db`. This plan makes none.
- GitHub calls through `bin/ai-gh`. No `gh run watch`. `bin/ai-pr-wait` for the PR.
- Installation writes outside the repo. Read `docs/deployment.md` / skills-usage-guide before `ai-adopt-globals`. Preserve machine sections. A linked worktree run can install globals then refuse machine launchers; finish from the canonical checkout (`docs/skills-usage-guide.md`).
- Public repo: never commit transcripts or the diagnosis file under `.grok\tmp`.
- Do not start a second 3027 chat.
- Response Style still applies to Albert; this plan file is allowed to run long.

## 12. Access and environment

- **Git:** authenticated as `u2giants` on `popcre/ai-devops` and `u2giants/shared-db`.
- **CLIs:** `git`, Git Bash for the phrase test, PowerShell, `bin/ai-gh`, `bin/ai-pr-wait`, `bin/ai-task-gates`, `bin/ai-adopt-globals`.
- **No secrets needed.** 1Password vault `vibe_coding` is unused here.
- **No local app server.**
- **Worktree:** create from current `origin/main`. Suggested path `C:\repos\ai-devops-worktrees\issue-511-live-proof-session-sizing` on a new branch. Do not continue in `C:\Users\ahazan\.grok\worktrees\repos-ai-devops\claude-trancsript` (dirty, on `main`).
- **3027 transcript path** (read-only, private): see §3.

---

# Part 4 — Landing it

## 13. Definition of done + risks and open questions

**Done when all of these are true**

- [x] Steps 1–3 merged on `origin/main` (globals, phrase test, parity rule, handover sentence).
- [x] Step 4’s STATUS legend is on `origin/main`, and either 3027 was left as live owner of remaining unproven steps with “no further steps,” or idle-split issues exist, one per remaining unproven step.
- [x] Installed Claude and Codex globals on the implementing machine contain `one unproven live-behavior outcome`.
- [x] #511 comments the merge commit SHA and is closed only after the above.
- [x] This plan’s STATUS table is updated in the same commits as the work (or in a follow-up docs commit if the implementer must split).
- [x] This handoff is deleted in the commit that closes #511, under the successor rule.
- [ ] Current `origin/main` and both installed globals contain `Never save several unproven steps`.
- [ ] Both plan-writer sources contain `opened when that code landed`, with focused guards passing.
- [ ] PR #520 has read-only exact-head independent approval and lands through the normal merge path.
- [x] The temporary PR #520 handoff is deleted after all obligations were incorporated in this plan.

**Risks**

- Colliding with the 3027 session (mitigation: Step 4 liveness rule; if unsure, treat as live).
- Line-wrapping the phrase and shipping a green-looking global that fails later (#209). Mitigation: Step 2.
- Budget warning on always-loaded globals. Mitigation: the sentence is one bullet; do not add a paragraph. If a warning appears, report it; do not delete other safety rules to fit.
- Installing globals without preserving machine sections. Mitigation: `ai-adopt-globals` only.

**Open questions**

- None that block implementation. Idle-vs-live is a judgment call with a fail-safe (treat as live).

**Rollback**

- Revert the #511 merge. Installed globals revert on the next `ai-adopt-globals` from `main`. Do not revert #500/#508/#509.

---

## Self-audit (planning session, 2026-09-16)

1. **Could a brand-new AI session execute this without asking?** Yes. §2 names the repos and identity. §9 names every file, the exact sentence, the exact test phrase, the 3027 liveness rule, and the merge/install commands. §12 names the dirty worktree to avoid. No owner question is required (handoff §0).
2. **Does it carry the reasoning, including rejects?** Yes. §6 is the root cause. §7 lists seven rejected approaches with dates. §8 labels locked vs open. §4 says what is out of scope and why #401 is not the home (#168).
3. **Is the goal clear enough if a step is wrong?** Yes. §1: one leftover proof per chat, no eight-hour crew, no stolen 3027 work, no weaker merge. “If a step conflicts with this goal, the goal wins.”
