# Handoff: context-engineering step 4 — the two always-loaded globals are slimmed

- **Machine:** `al8960ofc` (Windows 11, user `ahazan2`, PowerShell 7 primary)
- **Agent:** Claude (Opus 5) in Claude Code
- **Repo:** `u2giants/ai-devops`. Worked in the worktree
  `C:\repos\ai-devops-worktrees\context-engineering-consolidation-d3d183` on
  branch `claude/context-engineering-consolidation-d3d183`; merged to `main`.
- **Status:** step 4 source work is complete, committed, and pushed to `main`
  (`24f709e`, `3544036`). Two named step-4 gates are deliberately deferred and
  recorded in the plan. The plan is
  [`plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md);
  steps 5 through 10 remain.

---

## 0. ⚠️ DECISIONS ONLY ALBERT CAN MAKE

Put this whole list to Albert in ONE message before starting work. Do not raise
them one at a time as you trip over them.

### Blocking — the next session cannot finish without an answer

1. **Nothing is blocking.** Step 5 can start immediately and run to completion
   without Albert. The first thing that genuinely needs him is step 8, below.

### A wrong guess is recoverable, but the rework is wasteful

2. **May the response-style contract ever be shortened?** It is the first ~1,500
   bytes of both globals (identical in each) and is now the largest remaining
   always-loaded block. It is also Albert's own voice rules, which is why this
   session refused to touch it. *Recommendation: leave it alone.* Blocks nothing;
   decides whether the 23,318-byte target is reachable at all.
3. **Is 22.7% good enough for the always-loaded files, or should the plan keep
   pushing toward 30%?** *Recommendation: accept 22.7% and let step 10 set the
   final number from pilot evidence.* Cutting further means trimming safety or
   style prose, which the plan forbids.
4. **Which two application repos are the second and third pilots (plan step 8)?**
   The plan suggests one medium and one large/high-risk, likely `poppim-web` and
   `shared-db`. *Recommendation: confirm `poppim-web` and `shared-db`, after
   checking that no other session is working in them.* Blocks step 8.
5. **Step 8 changes how Albert's own AI sessions behave on `al8960ofc` first.**
   Installing the trimmed globals replaces the instructions every Claude and
   Codex session on that machine starts with. Rollback is prepared (see §9).
   *Recommendation: pilot on `al8960ofc` as the plan says, with pre-install
   hashes and copies saved first.* Blocks step 8; step 9 then touches
   `916-alien`, `albt16`, and the Ubuntu boxes.
6. **Step 7 must choose PowerShell 5.1 compatibility or migrate to `pwsh`.**
   `bin/setup-machine.ps1:187,192` currently launches the native installer under
   Windows PowerShell 5.1. *Recommendation: keep the child 5.1-safe; migrating is
   a bigger change than step 7 needs.* Technical, but it changes a machine
   requirement, so Albert should know it was decided.

### Not part of this work, and nobody is on it

7. **The Codex global still contains a statement that is simply false** — that
   Codex has no skills system (around line 43 of
   `templates/system/AGENTS-global-codex.md`). Codex does have skills; this repo
   ships and installs them. The plan gates the correction behind Codex trigger
   evidence that nobody has produced yet, so it stays wrong until step 6.
   *Recommendation: keep the gate; it is a stale sentence, not an unsafe one.*
8. **No Codex trigger eval set exists for any Codex skill.** The runner
   (`tools/skill-trigger-eval/codex-trigger-eval.py`) was built in step 3 and has
   nothing to run. Until it does, no evidence-based decision about Codex skill
   summaries is possible. *Recommendation: make writing the first eval sets the
   opening task of step 6.*

### Already settled — do NOT re-ask

- **Safety outranks token reduction** (plan section 8, locked 2026-08-12).
- **No six-file convention, no knowledge graph, no GraphRAG service** (plan
  section 7, rejected 2026-08-12).
- **GPT-5.6 stays at `low` or `medium`.** Not open for discussion.
- **Do not delegate plan steps to `ai-glm implement`** until the GLM permission
  bug is fixed (plan section 11, 2026-08-12).
- **Budgets warn, they never fail a run** (step 3, 2026-08-12).
- **Stopping this session's global trim at 22.7% rather than gutting the
  response-style block** (2026-08-12; reopen only with measured evidence).

---

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public backup-and-restore toolkit for his
multi-model AI coding workflow. Albert is a business owner, not a programmer;
this repo is the durable memory of his "engineering department". It is 100% owned
Bash, PowerShell, Python, and Markdown. There is no app, database, container,
hosted service, or CI, and nothing here is deployed. The canonical repo is
`https://github.com/u2giants/ai-devops`, branch policy is `main` only.

What matters for this work:

- `templates/system/CLAUDE-global.md` — installed as the user-level
  `~/.claude/CLAUDE.md` on every machine. Claude Code loads it at the start of
  every session in every repo.
- `templates/system/AGENTS-global-codex.md` — the Codex twin, installed as
  `~/.codex/AGENTS.md`.
- `AGENTS.md` — this repo's own router, read at session start inside this repo.
  `CLAUDE.md` is a short Claude-specific adapter that points at it.
- `skills/shared/`, `skills/claude/`, `skills/codex/` — procedures loaded only
  when a task triggers them. `bin/ai-install-skills` (Bash) and
  `bin/install-ai-devops-windows.ps1` (native Windows) install them;
  `bin/setup-machine.ps1` calls the PowerShell one.
- `tools/context-audit/context-audit.py` — the dependency-free audit built in
  step 1 and given enforcement teeth in step 3.
- `docs/context-engineering.md` — the measured baseline, the ownership map (which
  artifact owns which kind of rule), and the warning budgets.

The two global templates are the "always-loaded" context class: every session on
every machine pays for every byte in them, whatever the task. That is why they
are the first thing the plan reduces.

## 2. What we set out to do this session, and why

Execute **step 4** of the plan: slim the always-loaded global files.

Business reason: sessions were starting with roughly 8,300 estimated tokens of
standing instruction before reading a single line of the actual repo, and most of
that was detailed procedure that only matters for one kind of task. The plan's
stated goal is the smallest *high-signal* context, not the smallest file. Safety
is an acceptance requirement, not something to trade away.

Steps 1-3 (baseline, ownership map, enforcement tooling and tests) were already
done by earlier sessions. Enforcement came before reduction on purpose, so that
step 4 could not quietly delete a safety rule.

## 3. Current state — what is true right now

**Done, committed, and pushed to `main`.**

- `templates/system/CLAUDE-global.md`: 17,053 → 12,933 bytes.
- `templates/system/AGENTS-global-codex.md`: 16,258 → 12,831 bytes.
- Always-loaded class: **33,311 → 25,764 bytes, a 22.7% cut** (about 8,329 →
  about 6,442 estimated tokens; the estimate is bytes ÷ 4, not a billing claim).
- `tools/context-audit/budgets.json` and the `DEFAULT_BUDGETS` fallback at
  `tools/context-audit/context-audit.py:91` both ratcheted: `alwaysLoadedBytes`
  budget 33,311 → 25,764. `target` stays 23,318. No budget was raised.
- `docs/context-engineering.md`: new **"Where the removed global detail now
  lives"** table (the audit trail of every moved passage and its trigger), a
  ratchet note, a corrected baseline row, and a corrected budget row.
- `plan_context-engineering-consolidation.md`: STATUS row 4 updated to
  "source done, pilot probes owed", a nine-item step-4 drift block added at the
  top, and a completion note added inside the step 4 section.
- This handoff.

**Commits:** `24f709e` (the trim) and `3544036` (a handoff correction) on
`origin/main`. Both also on the branch
`claude/context-engineering-consolidation-d3d183`, which was rebased onto
`c6b5686` after a concurrent session cleared five finished handoff files.

**Verified green on 2026-08-12, all from the worktree root:**

```bash
python tools/context-audit/context-audit.py --root . --strict   # exit 0
bash tests/test-ai-install-skills.sh
bash tests/test-ai-memory-sync.sh
bash tests/test-windows-scripts.sh                              # 25 passed, 0 failed
```

```powershell
pwsh -NoProfile -File tests/test-context-audit.ps1
pwsh -File tests/test-install-ai-devops-windows.ps1
pwsh -File tests/test-mcp-env-launch.ps1
pwsh -File tests/test-memory-sync-scheduled-task.ps1
```

The audit reports zero missing safety markers, zero cross-client parity
mismatches, zero stale divergence-allowlist entries, zero broken relative links,
and zero global-versus-skill-description overlaps. One budget warning remains and
is expected: startup-routed (`AGENTS.md` + `CLAUDE.md`) sits at 50,729 bytes,
243 over its 50,486 budget. That is step 5's problem.

**Deliberately NOT done (both recorded as drift in the plan):**

1. **Live client probes.** Step 4's gate says a representative Claude and Codex
   session must answer safety and routing probes correctly. That needs the
   trimmed globals *installed*, and the plan forbids installing before the step 8
   pilot. Step 8 must run those probes and roll back on any failure. Step 4 is
   not fully closed until it does.
2. **The stale Codex "no skills system" sentence** and the ritual summaries under
   it. Gated on Codex trigger evidence that does not exist. Step 6 owns it.

**Nothing was installed on this machine.** `C:\Users\ahazan2\.claude\CLAUDE.md`
and `C:\Users\ahazan2\.codex\AGENTS.md` still hold the old text plus local machine
additions. That is correct and intentional.

**Where the whole plan stands:** steps 1, 2, 3 done; step 4 source-done with two
gates owed to step 8 and step 6; steps 5, 6, 7, 8, 9, 10 open.

## 4. Everything we tried that did NOT work

- **Chasing the 23,318-byte target by shaving more prose. Abandoned on purpose.**
  After relocating everything with a real canonical owner, the only material left
  is the response-style contract (identical in both globals, governs every turn)
  and the Codex ritual summaries (gated). Cutting either trades behavior quality
  for a number, which plan section 1 forbids. The gap is documented rather than
  closed. **Do not "finish the job" by trimming safety or style prose.**
- **Pointing the Codex global at Codex *skills* as the destination for removed
  handoff detail. Rejected.** That would lean on the very assumption (Codex skill
  triggering) the plan gates behind evidence. Every Codex pointer therefore names
  a **file path** it can open unconditionally
  (`templates/system/handoff-standard.md`), not a skill name alone.
- **Relying on the audit's broken-link check to protect the new pointers. It does
  not.** They are backticked prose paths, not Markdown links, so the link checker
  never sees them. All nine were verified to exist by hand instead. See §7.
- **Pushing straight to `main`. Failed once**, because a concurrent session had
  advanced `main` to `c6b5686` mid-work. Rebasing onto it and force-pushing the
  personal branch with `--force-with-lease` was the fix. Expect concurrent
  sessions in this repo; re-fetch before assuming your branch is current.
- One stray non-ASCII character ("步") was typed into the Codex global mid-edit
  and corrected immediately. Mentioned only because this repo's PowerShell files
  must stay pure ASCII; grep for non-ASCII if anything downstream misbehaves.

## 5. Root causes and key findings

- The globals were large not because the rules are many, but because each rule
  carried its **full procedure and its incident narrative inline**. Step 2's
  ownership map already named a canonical owner for every one of those
  procedures; nobody had ever moved the text.
- The single largest block in either global was the Codex "HANDOFF quality
  standard" section, about 4,300 bytes, restating
  `templates/system/handoff-standard.md` — a 19,327-byte document that already
  says all of it, better. That one substitution is roughly half the total saving.
- **The safety-marker check is a weak gate on global edits.**
  `tools/context-audit/context-audit.py:26-62` runs its six category regexes over
  *all* classified files, not just the globals, so a rule deleted from a global
  can still be "present" via `AGENTS.md` or a skill. The **parity** rules at
  `:66-77` are the real gate: they assert ten named rules appear in *both*
  globals, which is what actually stops a one-sided deletion. Anyone editing a
  global should think in terms of parity, not safety markers.
- `installed source drift` now reports **0** on this machine. The four drifted
  skills recorded in the plan's section 5 baseline (Claude `kimi-code-delegation`,
  `shared-db-handover`, `shared-db-orchestrator`, Codex `kimi-code-delegation`)
  are no longer drifted. **Step 7 must re-measure rather than assume those four
  are still the problem.**
- A budget number lives in **three** places that can silently disagree:
  `budgets.json`, `DEFAULT_BUDGETS` in the tool, and the table in
  `docs/context-engineering.md`. Step 4 updated all three.

## 6. Exact next steps

These cover the whole remaining plan, steps 5 through 10, in order.

1. **Step 5 — tighten `AGENTS.md` as a router.** Measure against the *current*
   number, **50,729 bytes** for `AGENTS.md` + `CLAUDE.md` — not the 50,486 in
   `budgets.json` and not the 49,401 in the plan's section-5 baseline. Keep the
   project summary, the task-to-doc map, boundaries, common identifiers, what to
   ignore, active plan links, and repo-wide invariants. Move full incident
   narratives and specialist procedures to named docs, leaving a one-sentence
   warning plus a pointer. Also decide the `@AGENTS.md` question in plan section
   13, open question 3: test whether a Claude import beats the current explicit
   read instruction, and never enable both.
   *You'll know it worked when* `python tools/context-audit/context-audit.py
   --root . --strict` exits 0, `startupRoutedBytes` has fallen, the budget
   warning is gone, and you have ratcheted that budget in all three places named
   in §5.
2. **Use the method that worked in step 4:** for each long block, find its
   canonical owner in the ownership map in `docs/context-engineering.md`, leave
   the *rule* in place, replace the *procedure* with a pointer that says exactly
   when to open the owner, and add a row to the "Where the removed global detail
   now lives" table (rename that heading if step 5 makes it cover the router too).
3. **Step 6 — consolidate cross-client skill duplication.** Start by writing the
   first Codex trigger eval sets for
   `tools/skill-trigger-eval/codex-trigger-eval.py`; nothing else in step 6 or
   the Codex global correction can be decided without them. Then work the 12
   measured duplicate paragraph groups, beginning with the exact-body Qwen pair.
   Correct `docs/codex-skills-usage-guide.md:84` (`--migrate-obsolete` is a no-op
   now; quarantine is automatic). Treat the four skills the globals point at as
   load-bearing — see §7.
   *You'll know it worked when* the duplicate-paragraph count falls, the
   installer still fails closed on a name collision, both client fixtures receive
   the intended skill, trigger tests still fire, and overlap stays zero.
4. **Step 7 — repair installation drift safely.** Preview-first reconciliation in
   BOTH `bin/ai-install-skills` and `bin/install-ai-devops-windows.ps1`, keeping
   machine overlays. Re-measure drift first (see §5). Decide the PowerShell
   5.1-versus-`pwsh` question in §0 item 6.
   *You'll know it worked when* the fixture matrix (absent, identical, locally
   extended, locally conflicting, obsolete managed, vendor-unmanaged) behaves as
   designed, a dry run writes nothing, a second apply changes nothing, and the
   Bash and PowerShell installers produce the same managed outcome.
5. **Step 8 — pilot on `al8960ofc`.** Save pre-install hashes and recoverable
   copies of both installed globals first. Run the installer dry-run, inspect,
   install, then **fully restart both clients** so startup context reloads. Run
   the deferred step-4 probes here: does a session still route a shared-db change
   correctly, refuse a production mutation, verify Git identity, and open
   `templates/system/handoff-standard.md` when writing a handoff?
   *You'll know it worked when* every safety probe passes, real tasks complete
   correctly, no machine-specific facts vanished, and the installed file actually
   contains the new text (do not accept installer exit code 0 as proof).
6. **Step 9 — roll out to `916-alien`, `albt16`, then the Ubuntu AI users.**
   Check reachability and concurrent work, fast-forward `main`, dry-run and diff
   per machine, install, restart clients, run `ai-devops doctor`.
   *You'll know it worked when* each machine reports the expected commit, the
   correct global plus its overlay, current managed skills, GPT-5.6 low/medium,
   and a working Codex sandbox canary. Offline machines stay explicitly open.
7. **Step 10 — measure, set final budgets, close.** Compare before/after startup
   context, tool calls, task success, and safety probes. Set the real budgets from
   what proved safe, editing all three places. Update the plan STATUS, write a
   memory entry if anything durable was learned, and delete the handoffs whose
   work is proven done.
   *You'll know it worked when* every STATUS row is current, all named suites
   pass, `main` and `origin/main` match, and installed state matches the pushed
   commit on every completed machine.
8. **Do not delegate any of this to `ai-glm implement`** until the GLM permission
   bug is fixed. GLM review sessions are fine and are the right tool for a second
   opinion on steps 5 and 6.

## 7. Constraints and gotchas in force

- **Never raise a budget to silence a warning.** Ratchet down only after a
  measured reduction lands and its tests pass. And remember a budget lives in
  three files (§5).
- **Never delete a rule from only one client global.** Ten parity rules must
  appear in both, or the rule needs an entry in `PARITY_DIVERGENCE_ALLOWLIST`
  (`tools/context-audit/context-audit.py:84`) with a stated reason. `--strict`
  also fails on a *stale* allowlist entry, so do not leave one behind.
- **The new pointers are not link-checked.** If any later step renames
  `templates/system/handoff-standard.md`,
  `docs/cloud-build-prod-trigger-incident-2026-07-20.md`,
  `docs/future-visual-testing.md`, `bin/ai-git-identity`, or the
  `synology-long-running-operations`, `shared-db-change`,
  `codex-shared-db-change`, or `handoff-writer` skills, it must update both
  globals in the same commit. Teaching the audit to validate backticked paths
  inside the globals is a good step-5 or step-10 addition.
- Budgets warn only. They never fail a run, even under `--strict`.
- **Concurrent sessions work this repo.** Re-fetch before pushing; never
  `git add -A` over another session's uncommitted work; never edit or delete
  another session's `HANDOFF.d/` file.
- Commit identity must read `Albert Hazan <u2giants@users.noreply.github.com>`;
  verified this session with `git var GIT_COMMITTER_IDENT`.
- `.ai/` and `docs/claude-remote-control-hardening-v2.md` are unrelated untracked
  work in the primary checkout `C:\repos\ai-devops`. Leave them alone. `.ai/` must
  never be committed.
- No production, shared-cloud, Supabase, Coolify, NAS, or database mutation is
  part of this plan. No secret read should ever be needed.
- The toolkit home is `/worksp/ai-devops` on Linux, never `/opt/ai-devops`.
- New skills go in `skills/shared/` by default unless there is a named
  client-specific reason.
- `HANDOFF.d/` holds 4 open files, under the 5-file warning line. A concurrent
  session cleared five finished files in `c6b5686` while this work was in flight.

## 8. Access and environment

- Everything needed was local. **No credential, secret, 1Password read, cloud
  call, or network access beyond `git fetch`/`push` was required, and none was
  made.** Secrets, if some later step unexpectedly needs one, live only in the
  1Password vault `vibe_coding` — reference by item name, never by value.
- Tools used and confirmed present on `al8960ofc`: `git`, `python`, `bash`
  (Git Bash), `pwsh` (PowerShell 7).
- Primary checkout `C:\repos\ai-devops`; this work happened in the worktree
  `C:\repos\ai-devops-worktrees\context-engineering-consolidation-d3d183`.
- Steps 8 and 9 will need SSH or local access to `916-alien`, `albt16`, and the
  Ubuntu AI users. Verify reachability with a real call before planning around it.
- There is no server to start, no URL to deploy, and no CI. Only the named local
  Bash and PowerShell suites gate this work.

## 9. Open questions and risks

- **Risk (highest): a pointer is never followed.** The whole design assumes an
  agent opens `templates/system/handoff-standard.md` when told to. That is
  exactly what the step 8 probes must test. If a probe shows an agent writing a
  three-section handoff because the detail left the global, restore that block and
  record it. This is the single most likely failure mode of step 4.
- **Risk: rollback must not be improvised.** Before step 8 installs anything, save
  hashes and recoverable copies of both installed globals and the managed-skill
  manifest. Roll back through the same installer mechanism. Never
  `git reset --hard`, never delete unowned skill directories, never overwrite a
  local overlay to roll back.
- **Risk: the trimmed globals are much further from the installed ones than the
  plan originally assumed**, because installers only seed when absent. Step 7's
  reconciliation preview will show a large diff; that is expected, not a bug.
- **Open question: what should the final always-loaded budget be?** 23,318 was a
  flat 30% guess written in step 3, never a measurement. Step 10 sets the real one
  from pilot evidence. Do not treat 23,318 as a requirement.
- **Open question: does `@AGENTS.md` help Claude startup?** Unanswered; step 5
  owns it. Test actual loaded context, do not infer from syntax.
- **Decision, 2026-08-12:** stopped the global trim at 22.7% rather than gut the
  response-style contract. Rationale in §4. Reopen only with measured evidence
  that the style block is not earning its bytes.
- **Decision, 2026-08-12:** every removed passage keeps a pointer naming its
  trigger, and the moves are tabulated in `docs/context-engineering.md`. A future
  session that cannot find a rule should look there first.

---

**Self-audit gate: passed 2026-08-12.** All ten sections present. §0 was built by
re-reading §1-§9 line by line and promoting every sentence needing Albert's
judgement, including the two items outside this workstream (the false Codex
sentence and the missing Codex eval sets). A newcomer has the app description
(§1), the goal (§2), exact current state with commit SHAs and byte counts (§3),
the dead ends (§4), the non-obvious findings with `file:line` (§5), executable
steps for all six remaining plan phases each with a verification gate (§6), the
standing traps (§7), the environment (§8), and the dated decisions (§9). No
secret value appears anywhere.
