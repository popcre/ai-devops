# Handoff: context-engineering step 5 — `AGENTS.md` is now a router

- **Machine:** `al8960ofc` (Windows 11, user `ahazan2`, PowerShell 7 primary)
- **Agent:** Claude (Opus 5) in Claude Code
- **Repo:** `u2giants/ai-devops`. Worked in the worktree
  `C:\repos\ai-devops-worktrees\context-engineering-consolidation-11f12d` on
  branch `claude/context-engineering-consolidation-11f12d`; both commits are on
  `origin/main`.
- **Status:** step 5 is **complete, committed, and pushed** (`b8dd5ad`, plus a
  byte-count correction). Steps 6, 7, 8, 9, 10 remain, and step 4 still owes two
  gates to steps 6 and 8. The plan is
  [`plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md).

---

## 0. ⚠️ DECISIONS ONLY ALBERT CAN MAKE

Put this whole list to Albert in ONE message before starting work.

### Blocking — the next session cannot finish without an answer

1. **Nothing is blocking.** Step 6 can start immediately and run to completion
   without Albert. The first thing that genuinely needs him is step 8.

### A wrong guess is recoverable, but the rework is wasteful

2. **Step 6 will merge skills that currently exist as two near-identical copies,
   one for Claude and one for Codex.** Merging changes which file a future
   session edits, and a merged skill that stops firing costs Albert a session.
   *Recommendation: merge only where a trigger eval proves both clients still
   fire, starting with the exact-body Qwen pair, and leave the rest alone.*
3. **Step 6 may correct the false sentence in the Codex global that says Codex
   has no skills system.** Albert already ruled on 2026-08-12 that writing the
   first Codex trigger eval sets is step 6's opening task, which unblocks this.
   *Recommendation: correct the sentence as soon as the eval sets exist, in the
   same commit, and keep the parity check green.*

### Not part of this work, and nobody is on it

4. **`HANDOFF.d/` now holds 5 open files, at the warning line.** The oldest,
   `2026-08-10T1138Z-albt16-codex-916-rollout.md`, is the powered-off `916`
   machine rollout. It is not this workstream's to close.
   *Recommendation: Albert decides whether the `916` rollout is still wanted.*

### Already settled — do NOT re-ask

- **The response-style contract is the short six-bullet version.** Albert wrote
  the replacement himself on 2026-08-12. The step-4 note saying it must never be
  touched is superseded. The old text is in git history at `24f709e`.
- **22.7% was accepted for the globals.** They now sit 25.8% below baseline.
- **The pilot repos after `ai-devops` are `popdam` and `shared-db`**, not
  `poppim-web` (Albert, 2026-08-12).
- **`bin/install-ai-devops-windows.ps1` stays PowerShell 5.1-safe.** Do not
  migrate `bin/setup-machine.ps1:187,192` to `pwsh` (Albert, 2026-08-12).
- **Do not enable `@AGENTS.md`.** Plan open question 3, answered in step 5.
- **Writing the first Codex trigger eval sets is step 6's opening task.**
- Safety outranks token reduction; no six-file convention or knowledge graph;
  GPT-5.6 stays low/medium; budgets warn and never fail; do not delegate plan
  steps to `ai-glm implement`.

---

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public backup-and-restore toolkit for his
multi-model AI coding workflow. Albert is a business owner, not a programmer;
this repo is the durable memory of his "engineering department". It is 100% owned
Bash, PowerShell, Python, and Markdown. There is no app, database, container,
hosted service, or CI, and nothing here is deployed. Branch policy is `main` only.

What matters for this work:

- `templates/system/CLAUDE-global.md` and
  `templates/system/AGENTS-global-codex.md` — the two **always-loaded** globals,
  installed as `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`. Every session on
  every machine pays for every byte.
- `AGENTS.md` — this repo's **startup-routed** router, plus the short `CLAUDE.md`
  adapter that points at it.
- `docs/design-decisions.md` and `docs/critical-incidents.md` — **new in step 5.**
  They own the long narratives the router used to carry inline.
- `skills/shared/`, `skills/claude/`, `skills/codex/` — task-triggered procedures.
- `tools/context-audit/context-audit.py` — the dependency-free audit and its
  enforcement gates.
- `docs/context-engineering.md` — the baseline, the ownership map, the budgets,
  and the "Where the removed global and router detail now lives" audit trail.

## 2. What we set out to do this session, and why

Execute **step 5** of the plan: turn `AGENTS.md` into a tight router.

Business reason: a session in this repo was told to read a 48 KB router before
doing anything, on top of the globals. Most of that router was incident
storytelling and specialist wrapper constraints that only matter for one kind of
task. The plan's rule is that the router keeps the rule and a pointer, and the
detail lives in a named doc that is opened only when triggered.

Albert also, in the same session, replaced the long response-style contract in
both globals with a short one and confirmed three open decisions.

## 3. Current state — what is true right now

**Done, committed, and pushed to `main`.**

- `AGENTS.md`: 48,451 → **33,694 bytes**. Startup-routed class (`AGENTS.md` +
  `CLAUDE.md`): 50,729 → **35,972 bytes, a 29.1% cut**. The 35,340 target is
  missed by 632 bytes, deliberately.
- Always-loaded globals: 25,764 → **24,713 bytes**, 25.8% below the original
  33,311 baseline.
- **New:** `docs/design-decisions.md` holds the ten "looks like / actually / why /
  do not change" narratives, verbatim.
- **New:** `docs/critical-incidents.md` holds the 2026-07-16 Codex-on-Windows and
  2026-07-23 1Password lockout narratives, verbatim. One paragraph the source had
  duplicated twice is now single.
- The router keeps a compact table of the ten quirks (one line each) and a
  two-bullet incident summary, each with a pointer that states its trigger.
- The GLM, Grok, and Kimi documentation-map rows were the three largest cells in
  the file. They now point at `docs/glm-opencode.md` section 5 and the STEP 0
  VERIFICATION headers in `bin/ai-grok-review`, `bin/ai-grok-implement`, and
  `bin/ai-kimi`. Each was opened and confirmed to hold the same constraints.
- **Both globals gained a rule:** "every destructive action must be recoverable
  before you take it", with the concrete bans (no `git reset --hard` over
  unreviewed work, no `git add -A` over another session's files, no deleting a
  directory you do not own, no overwriting a machine-local overlay).
- `PARITY_RULES` in `tools/context-audit/context-audit.py` gained an **eleventh**
  rule, `destructive actions recoverable`, so that rule can never be deleted from
  only one global.
- Budgets ratcheted in all three places: `alwaysLoadedBytes` 25,764 → 24,713,
  `startupRoutedBytes` 50,486 → 35,972.
- `plan_context-engineering-consolidation.md`: STATUS row 5 marked done, a
  step-5 drift block and an Albert-decisions block added at the top, the step 5
  and step 7 and step 8 sections updated, open question 3 answered, and the
  broken "Newest handoff" link fixed.
- `docs/context-engineering.md`: budget table, both ratchet notes, the renamed
  "Where the removed global **and router** detail now lives" table with four new
  rows, the parity count (ten → eleven), and the current-boundary paragraph.

**Commits:** `b8dd5ad` (the work) and one follow-up correcting the byte counts,
both on `origin/main`.

**Verified green on 2026-08-12, all seven named suites:**

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

The audit from `C:\repos\ai-devops` reports **zero** on every counter that
matters: missing safety markers, parity mismatches, stale allowlist entries,
broken relative links, global-versus-skill-description overlaps, and budget
warnings. Duplicate paragraphs still read 12; those are step 6's work.

**Nothing was installed on any machine.** The trimmed globals still exist only in
the repo. That remains correct until step 8.

**Where the whole plan stands:** steps 1, 2, 3, 5 done; step 4 source-done with
two gates owed (probes to step 8, the stale Codex sentence to step 6); steps 6,
7, 8, 9, 10 open.

## 4. Everything we tried that did NOT work

- **Trusting byte counts measured inside this worktree. They were wrong by about
  400 bytes.** Files edited here were written with LF endings while the repo
  checks out CRLF, so every figure was understated until the work was committed
  and re-measured. `docs/context-engineering.md` already warned about this for
  drift; it applies to size too. **Always re-measure from `C:\repos\ai-devops`
  after committing, and publish those numbers.** The first commit had to be
  followed by a correction commit for exactly this.
- **Assuming the audit's safety markers were already protecting the globals. They
  were not.** Moving the quirks narratives out of `AGENTS.md` immediately broke
  the "destructive actions" marker, because the only text in the always-loaded
  and startup-routed classes containing the word "destructive" was an incidental
  sentence about `bin/ai-memory-sync`. No global had ever carried a
  destructive-action rule. The fix was to write the real rule into both globals,
  not to drag the prose back. **Expect more markers to be satisfied by accident;
  check what actually matches before you move any block.**
- **Trimming the router's oversized rows without opening their targets first.
  Rejected.** The GLM, Grok, and Kimi cells each encode failures that cost real
  money. Every constraint was located in `docs/glm-opencode.md` section 5 and in
  the wrapper STEP 0 headers before the cell was shortened. Do not shorten a
  pointer row on the assumption that the target says the same thing.
- **Adding two documentation-map rows for the new docs pushed the startup class
  back over budget**, twice. Ratchet the budget *after* the file stops changing,
  not in the middle.
- Pushing to `main` needed a rebase both times; concurrent memory-sync commits
  land on `main` constantly. Re-fetch before every push.

## 5. Root causes and key findings

- **The router was large because it was also the incident archive.** Two
  sections, "Intentional quirks" (about 10.5 KB) and "Critical incidents" (about
  6.8 KB), were 36% of the file and are read by almost no task. Moving them and
  leaving a one-line rule plus a trigger is most of the 29.1% cut.
- **Three table cells in the documentation map were each larger than some whole
  docs.** The GLM row alone was about 1.9 KB of constraints inside a "usually do
  not need" column. A router row should point; if it explains, its content has an
  owner somewhere else.
- **The safety-marker check remains a weak gate and the parity check is the real
  one.** Markers run over all classified files, so a rule can be "present" via any
  file. Parity asserts a rule appears in *both* globals, which is what stops a
  one-sided deletion. Step 5 raised parity from ten rules to eleven.
- **A budget number lives in three places** that can silently disagree:
  `tools/context-audit/budgets.json`, `DEFAULT_BUDGETS` at
  `tools/context-audit/context-audit.py:91`, and the table in
  `docs/context-engineering.md`. Step 5 updated all three, twice.
- **The audit's broken-link count was 1 before this session started**, from the
  plan naming a handoff that a previous session had deleted. It is 0 now. A
  handoff file deleted on completion breaks every link that named it.
- `installed source drift` still reports 0 on this machine, as in step 4. **Step
  7 must re-measure rather than assume the four skills named in the plan's
  section-5 baseline are still the problem.**

## 6. Exact next steps

These cover the whole remaining plan, steps 6 through 10, in order.

1. **Step 6, first task — write the first Codex trigger eval sets** for
   `tools/skill-trigger-eval/codex-trigger-eval.py`. Albert confirmed this is the
   opening task on 2026-08-12. Nothing else in step 6, and no correction of the
   stale Codex "no skills system" sentence at about line 43 of
   `templates/system/AGENTS-global-codex.md`, may be decided before they exist.
   The runner counts a trigger when Codex opens the installed `SKILL.md`, which
   proves *selection*, not obedience. Do not over-claim from its score.
   *You'll know it worked when* a real prompt set produces a reproducible score
   for at least one Codex skill and the runner's `--print-command` dry run still
   asserts `low`/`medium` effort and a read-only sandbox.
2. **Step 6, main task — consolidate cross-client skill duplication.** Work the
   12 measured duplicate paragraph groups, beginning with the exact-body Qwen
   pair. Separate shared policy from a small client adapter only where invocation
   genuinely differs. Retire old managed copies through the existing quarantine
   mechanism. Correct `docs/codex-skills-usage-guide.md:84` (`--migrate-obsolete`
   is a no-op now; quarantine is automatic). **Four skills are load-bearing**
   because the globals name them: `synology-long-running-operations`,
   `shared-db-change`, `codex-shared-db-change`, `handoff-writer`. Renaming or
   merging any of them means updating both globals in the same commit.
   *You'll know it worked when* the duplicate-paragraph count falls, the
   installer still fails closed on a name collision, both client fixtures receive
   the intended skill, trigger tests still fire, and overlap stays zero.
3. **Step 7 — repair installation drift safely.** Preview-first reconciliation in
   BOTH `bin/ai-install-skills` and `bin/install-ai-devops-windows.ps1`, keeping
   machine overlays. Re-measure drift first. Keep the child installer path
   PowerShell 5.1-safe (Albert's decision).
   *You'll know it worked when* the fixture matrix (absent, identical, locally
   extended, locally conflicting, obsolete managed, vendor-unmanaged) behaves as
   designed, a dry run writes nothing, a second apply changes nothing, and both
   installers produce the same managed outcome.
4. **Step 8 — pilot on `al8960ofc`, then `popdam` and `shared-db`.** Save
   pre-install hashes and recoverable copies of both installed globals first. Run
   the installer dry-run, inspect, install, then **fully restart both clients** so
   startup context reloads. Run the deferred step-4 probes here: does a session
   still route a shared-db change correctly, refuse a production mutation, verify
   Git identity, and open `templates/system/handoff-standard.md` when writing a
   handoff? Add a step-5 probe: does a session asked about a strange behavior open
   `docs/design-decisions.md` instead of guessing?
   *You'll know it worked when* every safety probe passes, real tasks complete
   correctly, no machine-specific facts vanished, and the installed file actually
   contains the new text (do not accept installer exit code 0 as proof).
5. **Step 9 — roll out to `916-alien`, `albt16`, then the Ubuntu AI users.**
   Check reachability and concurrent work, fast-forward `main`, dry-run and diff
   per machine, install, restart clients, run `ai-devops doctor`.
6. **Step 10 — measure, set final budgets, close.** Compare before/after startup
   context, tool calls, task success, and safety probes. Set the real budgets from
   what proved safe, editing all three places. Consider closing the remaining 632
   bytes to the startup-routed target and the 1,395 bytes to the always-loaded
   target, or resetting both targets to what proved safe. Update the plan STATUS,
   write a memory entry if anything durable was learned, and delete the handoffs
   whose work is proven done.
7. **A worthwhile addition for step 6 or 10:** teach the audit to validate
   backticked prose paths inside the globals and the router. The pointers this
   design depends on are still not link-checked (see §7).
8. **Do not delegate any of this to `ai-glm implement`** until the GLM permission
   bug is fixed. GLM review sessions are fine.

## 7. Constraints and gotchas in force

- **Measure sizes from `C:\repos\ai-devops` after committing.** A worktree with
  LF-ending edits understates every byte count by roughly 400. This bit step 5.
- **Never raise a budget to silence a warning.** Ratchet down only after a
  measured reduction lands and its tests pass, and remember the number lives in
  three files.
- **Never delete a rule from only one client global.** Eleven parity rules must
  appear in both, or the rule needs an entry in `PARITY_DIVERGENCE_ALLOWLIST`
  (`tools/context-audit/context-audit.py:84`) with a stated reason. `--strict`
  also fails on a *stale* allowlist entry.
- **The pointers are still not link-checked.** They are backticked prose paths,
  not Markdown links, so the link checker never sees them. If any later step
  renames `templates/system/handoff-standard.md`,
  `docs/cloud-build-prod-trigger-incident-2026-07-20.md`,
  `docs/future-visual-testing.md`, `bin/ai-git-identity`, `docs/glm-opencode.md`,
  `bin/ai-grok-review`, `bin/ai-grok-implement`, `bin/ai-kimi`, or the
  `synology-long-running-operations`, `shared-db-change`,
  `codex-shared-db-change`, or `handoff-writer` skills, it must update the
  globals and the router in the same commit.
- **`docs/design-decisions.md` and `docs/critical-incidents.md` are now
  load-bearing.** Renaming or merging either means updating `AGENTS.md`,
  `docs/context-engineering.md`, and the documentation map together.
- Budgets warn only. They never fail a run, even under `--strict`.
- **Concurrent sessions work this repo.** Re-fetch before pushing; never
  `git add -A` over another session's uncommitted work; never edit or delete
  another session's `HANDOFF.d/` file.
- Commit identity must read `Albert Hazan <u2giants@users.noreply.github.com>`;
  verified this session with `git var GIT_COMMITTER_IDENT`.
- `.ai/` and `docs/claude-remote-control-hardening-v2.md` are unrelated untracked
  work in the primary checkout. Leave them alone. `.ai/` must never be committed.
- No production, shared-cloud, Supabase, Coolify, NAS, or database mutation is
  part of this plan. No secret read should ever be needed.
- New skills go in `skills/shared/` by default.
- **`HANDOFF.d/` holds 5 open files, at the warning line.** See §0 item 4.

## 8. Access and environment

- Everything needed was local. **No credential, secret, 1Password read, cloud
  call, or network access beyond `git fetch`/`push` was required, and none was
  made.** Secrets, if a later step unexpectedly needs one, live only in the
  1Password vault `vibe_coding` — reference by item name, never by value.
- Tools used and confirmed present on `al8960ofc`: `git`, `python`, `bash`
  (Git Bash), `pwsh` (PowerShell 7).
- Primary checkout `C:\repos\ai-devops`; this work happened in the worktree
  `C:\repos\ai-devops-worktrees\context-engineering-consolidation-11f12d`.
- Steps 8 and 9 will need SSH or local access to `916-alien`, `albt16`, and the
  Ubuntu AI users. Verify reachability with a real call before planning around it.
- There is no server to start, no URL to deploy, and no CI. Only the named local
  Bash and PowerShell suites gate this work.

## 9. Open questions and risks

- **Risk (highest, unchanged): a pointer is never followed.** The whole design
  assumes an agent opens `docs/design-decisions.md` or
  `templates/system/handoff-standard.md` when told to. Step 8's probes must test
  it. If a probe shows an agent "fixing" an intentional quirk because the
  reasoning left the router, restore that block and record it.
- **Risk: rollback must not be improvised.** Before step 8 installs anything,
  save hashes and recoverable copies of both installed globals and the
  managed-skill manifest. Roll back through the same installer. Never
  `git reset --hard`, never delete unowned skill directories, never overwrite a
  local overlay.
- **Risk: the installed globals are now very far from source.** Installers seed
  only when absent, and the globals have been rewritten twice since any machine
  was seeded. Step 7's preview will show a large diff; that is expected.
- **Open question: what should the final budgets be?** 23,318 and 35,340 were
  flat 30% guesses from step 3, never measurements. Step 10 sets the real ones.
- **Decision, 2026-08-12 (Albert):** the response-style contract is the short
  version; pilots are `popdam` and `shared-db`; the Windows installer child path
  stays PowerShell 5.1-safe; Codex trigger eval sets open step 6.
- **Decision, 2026-08-12 (step 5):** no `@AGENTS.md` import. An import would load
  the whole router into every Claude session in this repo unconditionally, which
  is the opposite of what step 5 achieved. Never enable both mechanisms.
- **Decision, 2026-08-12 (step 5):** the destructive-action rule is a real
  always-loaded rule in both globals and an enforced parity rule, rather than
  prose that happened to satisfy a regex.

---

**Self-audit gate: passed 2026-08-12.** All ten sections present. §0 was built by
re-reading §1-§9 and promoting every sentence needing Albert's judgement. A
newcomer has the app description (§1), the goal (§2), exact current state with
commit SHAs and byte counts (§3), the dead ends including the LF/CRLF trap and
the accidental safety marker (§4), the non-obvious findings with `file:line`
(§5), executable steps for all five remaining plan phases each with a
verification gate (§6), the standing traps (§7), the environment (§8), and the
dated decisions (§9). No secret value appears anywhere.
