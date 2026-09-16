# IMPLEMENTATION PLAN — never dump leftover live proofs on a later chat (2026-09-16)

**Tracking issue:** [popcre/ai-devops #511](https://github.com/popcre/ai-devops/issues/511)
**Handoff:** [`HANDOFF.d/2026-09-16T2004Z-edge-dev-grok-live-proof-session-sizing.md`](HANDOFF.d/2026-09-16T2004Z-edge-dev-grok-live-proof-session-sizing.md)

This plan is standing behavior for every future session. It is not a cleanup of any current ticket.

## STATUS — read first

A fresh session starts at **Step 0** only if the two required phrases are missing from `origin/main`. Otherwise this work is done.

| # | Step | State | Date | Evidence |
|---|---|---|---|---|
| 0 | Confirm the two standing rules are still missing from `origin/main` | ⬜ open | 2026-09-16 | `git grep -n "one unproven live-behavior outcome" origin/main -- templates/system/` and `git grep -n "Never save several unproven steps" origin/main -- templates/system/` both empty before this change. |
| 1 | Add both standing rules to Claude and Codex globals | ⬜ open | 2026-09-16 | Phrases unwrapped in both `templates/system/CLAUDE-global.md` and `templates/system/AGENTS-global-codex.md`. |
| 2 | Guard both phrases | ⬜ open | 2026-09-16 | `tests/test-client-globals-required-phrases.sh`; `PARITY_RULES` in `tools/context-audit/context-audit.py`. |
| 3 | Teach plan-writers not to create the pile | ⬜ open | 2026-09-16 | `templates/system/implementation-plan-standard.md` and `skills/shared/implementation-plan-writer/SKILL.md`. |
| 4 | Teach handover not to bundle leftover proofs | ⬜ open | 2026-09-16 | `skills/shared/shared-db-handover/SKILL.md`. |
| 5 | Merge and install | ⬜ open | 2026-09-16 | Merge commit on `origin/main`; installed `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` contain both phrases. |

**Fresh-session starting point:** Step 0. If both greps already hit, close #511.

---

# Part 1 — Why

## 1. The ultimate goal — what we are trying to achieve

A later chat must never inherit a pile of leftover “prove it works live” work that earlier chats deferred.

When this is done, two things are true on every machine that has installed the globals:

1. The session that merges code without live proof either proves it live or opens **exactly one** leftover-proof issue for **that** step before it ends.
2. A session handed several leftover proofs **refuses the bundle** instead of trying to finish them all.

Albert should not have to notice that a chat has been running for hours on a pile that should never have been stacked.

**If any step below conflicts with this goal, the goal wins — stop and flag it.** Do not weaken merge-safety. Do not drop live proof. Do not add a new tool.

## 2. What this application is

`popcre/ai-devops` is Albert Hazan’s public recovery toolkit. It owns the always-loaded Claude and Codex rules, the plan-writer standard, and the shared-db handover skill.

- **Repo:** `popcre/ai-devops`. Canonical checkout `C:\repos\ai-devops` is landing-only.
- **This change lives only here.** It applies to every future session in every repo those globals govern.
- **Target branch:** `main` via feature branch and pull request.
- **Installed copies:** `templates/system/CLAUDE-global.md` → `~/.claude/CLAUDE.md`; `templates/system/AGENTS-global-codex.md` → `~/.codex/AGENTS.md` via `bin/ai-adopt-globals`.
- **Git identity:** `Albert Hazan <u2giants@users.noreply.github.com>`.

## 3. What triggered this work

On 2026-09-16 a chat was handed three leftover live-proof tickets as one job and told to take them to production. Eight hours later the pile was still unfinished. Albert asked for the source, then for a plan, then corrected the first plan: it was about this week’s tickets. This rewrite is the standing fix for **every** future session.

The incident is only the example. The failure mode is: code is marked done at merge; live proof is saved for later; later, several unproven steps are dumped on one chat.

## 4. Scope — in and out

**In**

- Two standing rules in both globals.
- Tests so those phrases cannot be dropped or line-wrapped.
- Plan-writer standard: a “code landed, not accepted” row names exactly one leftover-proof issue, opened when that code landed.
- Handover skill: one leftover-proof issue per unproven step; never a later dump.

**Not in**

- Cleaning up, splitting, or finishing any current live-proof ticket.
- Weakening merge-safety or dropping live proof.
- New tools, memory files, or harnesses.
- Re-doing #500 / #508 / #509 (orchestrator-only-shape-work, stalled-helper restart, quoted authority, independent production approval, live-path-before-proof, no colliding helpers). Those stay.

---

# Part 2 — What we already know

## 5. Current state of the code

On `origin/main` `75650931` (re-check in Step 0):

- Both globals **lack** `one unproven live-behavior outcome` and `Never save several unproven steps`.
- `tests/test-client-globals-required-phrases.sh:23-35` does not yet list those phrases.
- `tools/context-audit/context-audit.py` `PARITY_RULES` (line 101) does not yet list them.
- Plan-writer STATUS rules require an artifact for “done,” but do **not** forbid dumping several unproven steps on one later issue (`templates/system/implementation-plan-standard.md:139-149`).
- Handover already says live proofs never go to the orchestrator (`skills/shared/shared-db-handover/SKILL.md:13-17`) and does **not** yet say leftover proofs must be one issue each, filed now.

Routers already point at this plan from #512.

## 6. Key findings and root cause

**Source:** leftover live proof is deferred, then bundled.

Implementation chats treat merge as finished. Live proof is saved. A later chat is handed the pile. That later chat cannot finish a programme of unproven work, especially when some “merged” features never actually ran.

Last-line defense (refuse a bundle) is not enough by itself. If the pile is never created, the later chat is never asked to swallow it.

## 7. Approaches considered and REJECTED, and why

1. **A plan that splits this week’s leftover-proof tickets.** Rejected 2026-09-16 by Albert: that is this incident, not the source. Future programmes would still dump a pile.
2. **Drop live proof.** Rejected. Live proof is how fake-done code is caught.
3. **Weaken merge-safety so a pile finishes faster.** Rejected. That ships the fake-done code.
4. **A new tool that tracks session size.** Rejected. One sentence in the globals plus the plan-writer rule is enough.
5. **Ask Albert to approve each leftover proof.** Rejected. He is not technical; production approvals already go to an independent reviewer.

## 8. Design decisions already made (dated)

**LOCKED**

- 2026-09-16: two rules, both globals, phrases must not wrap.
- 2026-09-16: the session that lands the code files the one leftover-proof issue, or proves it live. A later chat is not the filing clerk for a pile.
- 2026-09-16: a session handed a bundle splits or refuses.
- 2026-09-16: this plan does not touch current live-proof tickets.

**OPEN**

- Whether fleet install beyond this machine waits on the supported sync. Prefer: install here with `bin/ai-adopt-globals`, then the next sync carries it. Do not invent a second installer.

---

# Part 3 — How to build it

## 9. The plan — numbered, ordered steps

Declare `ai-task-gates start --class code`. Recheck `--before ship`.

### Step 0 — Confirm the gap

```powershell
git fetch origin
git grep -n "one unproven live-behavior outcome" origin/main -- templates/system/
git grep -n "Never save several unproven steps" origin/main -- templates/system/
```

You’ll know it worked when both are empty. If either already matches, stop and close #511.

### Step 1 — Both globals

Insert these two bullets, each on its own physical line, immediately after the **Start immediately.** bullet in:

- `templates/system/CLAUDE-global.md`
- `templates/system/AGENTS-global-codex.md`

```
- **One unproven outcome per session.** A session owns one unproven live-behavior outcome; refuse a bundle of leftover proofs or "take tickets N, M, and P to production" as one job — split them first, or stop and say the job is too big.
- **Do not defer live proof as a later dump.** When code lands without live proof, open exactly one leftover-proof issue for that step in the same session. Never save several unproven steps to hand to a later chat.
```

You’ll know it worked when `git grep -n "one unproven live-behavior outcome" templates/system/CLAUDE-global.md templates/system/AGENTS-global-codex.md` and the same for `Never save several unproven steps` each print one hit per file, unwrapped.

### Step 2 — Guard the phrases

- `tests/test-client-globals-required-phrases.sh`: add `"one unproven live-behavior outcome"` and `"Never save several unproven steps"`.
- `tools/context-audit/context-audit.py` `PARITY_RULES`: add `"one unproven outcome per session": r"one unproven live-behavior outcome"` and `"do not defer live-proof dumps": r"Never save several unproven steps"`.

You’ll know it worked when Git Bash `bash tests/test-client-globals-required-phrases.sh` prints PASS.

### Step 3 — Plan-writer standard

Add this bullet after the “row marked done cites an artifact” rule in both:

- `templates/system/implementation-plan-standard.md`
- `skills/shared/implementation-plan-writer/SKILL.md`

A STATUS row that is "code landed, not accepted" names exactly one live-proof owner issue, opened when that code landed. Do not point several unproven steps at one issue. Do not open a bundle of leftover proofs later for a later chat. The session that merged the code either proves it live or files that one leftover-proof issue before it ends.

You’ll know it worked when `git grep -n "opened when that code landed" templates/system/implementation-plan-standard.md skills/shared/implementation-plan-writer/SKILL.md` hits both.

### Step 4 — Handover skill

In `skills/shared/shared-db-handover/SKILL.md`, after “When in doubt, it does not go to the orchestrator.”, say leftover live-proof work is one issue per unproven step, one session per issue, never a later dump.

You’ll know it worked when `git grep -n "one issue per unproven step" skills/shared/shared-db-handover/SKILL.md` hits.

### Step 5 — Merge and install

This change set is **not** documentation-only (globals, test, Python, skills). `bin/ai-pr-wait`, merge through the queue, confirm `origin/main`. Then `bin/ai-adopt-globals` on this machine. Verify both installed files contain both phrases. Comment the merge SHA on #511 and close #511. Delete this handoff in that closeout commit, or in the same merge if already done.

You’ll know it worked when `Select-String -Path "$env:USERPROFILE\.claude\CLAUDE.md","$env:USERPROFILE\.codex\AGENTS.md" -Pattern "one unproven live-behavior outcome","Never save several unproven steps"` hits both files for both phrases.

## 10. Tests required

- Add the two phrases to `tests/test-client-globals-required-phrases.sh` as named in Step 2.
- Stay green: `bash tests/test-client-globals-required-phrases.sh`.
- Optional same-session: `python tools/context-audit/context-audit.py --root . --strict`. A new budget warning is reported, not fixed by deleting other safety rules.
- Do not run a local full Windows reviewer series. `bin/ai-test-local --check-collision` first if you must.

## 11. Constraints, standing rules, and gotchas in force

- Branch and PR. Stage only owned files.
- Do not wrap the required phrases (#209).
- One owner per rule: the two sentences live in the globals; routers only point here.
- Public repo: no transcripts.
- GitHub through `bin/ai-gh`. Wait with `bin/ai-pr-wait`.
- Install with `bin/ai-adopt-globals`; preserve machine sections.

## 12. Access and environment

- GitHub `popcre/ai-devops` as `u2giants`. No secrets. No app server.
- Worktree from current `origin/main`. Git Bash for the phrase test.

---

# Part 4 — Landing it

## 13. Definition of done + risks and open questions

**Done when**

- [ ] Both phrases are on `origin/main` in both globals, unwrapped.
- [ ] Phrase test PASSes on `origin/main`.
- [ ] Plan-writer standard and handover skill contain the no-dump rules.
- [ ] Installed Claude and Codex globals on the implementing machine contain both phrases.
- [ ] #511 closed with the merge SHA.
- [ ] This handoff deleted under the successor rule.

**Risks**

- Line-wrapping a phrase (#209). Mitigation: Step 2.
- Global byte budget warning. Mitigation: two bullets, no paragraph.
- Install without preserving machine sections. Mitigation: `ai-adopt-globals` only.

**Open questions:** none.

**Rollback:** revert the #511 merge. Next `ai-adopt-globals` restores installed copies. Do not revert #500/#508/#509.

---

## Self-audit

1. **Could a new session execute this without asking?** Yes. §9 names every file, both exact sentences, both test phrases, merge class, and install check. §4 forbids current-ticket cleanup.
2. **Reasoning and rejects?** Yes. §6 is the source (deferred dump). §7 rejects incident-specific cleanup, dropping live proof, weaker merges, a new tool, and asking Albert.
3. **Goal if a step is wrong?** Yes. §1: never hand a later chat a pile of leftover proofs. Goal wins; do not weaken merge-safety.
