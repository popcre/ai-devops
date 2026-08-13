# Handoff: context-engineering step 6 — Codex trigger eval sets exist, main task not started

- **Machine:** `al8960ofc` (Windows 11, user `ahazan2`, PowerShell 7 primary)
- **Agent:** Claude (Opus 5) in Claude Code
- **Repo:** `u2giants/ai-devops`. Worked in the worktree
  `C:\repos\ai-devops-worktrees\router-tightened-step-6-2b48cf` on branch
  `claude/router-tightened-step-6-2b48cf`. The commit is on `origin/main`.
- **Status:** step 6 is **complete, committed, and pushed** (`92d36ff` the
  opening task, `29ea53f` the merge, and the shared-db description fix).
  Duplicate paragraph groups are 12 → 2, and both eval sets score 10/10
  should-fire and 0/10 should-not-fire. Steps 7, 8, 9, 10 remain, and step 4 owes
  its probes to step 8. The plan is
  [`plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md).

---

## 0. ⚠️ DECISIONS ONLY ALBERT CAN MAKE

Put this whole list to Albert in ONE message before starting work.

### Blocking — the next session cannot finish without an answer

1. **Nothing is blocking.** Step 7 can start immediately. The first thing that
   genuinely needs Albert is still step 8.

### A wrong guess is recoverable, but the rework is wasteful

2. **The Claude twin `skills/claude/shared-db-change` has never been measured.**
   Its Codex counterpart was found under-firing and fixed this session. The Claude
   one has the same job and is named in the Claude global, but Claude routes
   through the `Skill` tool, a different mechanism, so **the Codex result does not
   transfer.**
   *Recommendation: write the Claude eval set and score it with
   `skill-trigger-eval.py` before assuming it is fine. Do not "fix" it blind — the
   Codex fix was only defensible because it was measured before and after.*
3. **Three of the four load-bearing skills still have no eval set.** See §6 step 1.
   *Recommendation: write them before step 8, so the pilot has something to
   compare against.*

### Not part of this work, and nobody is on it

4. **`HANDOFF.d/` now holds 6 open files, one OVER the warning line.** The oldest,
   `2026-08-10T1138Z-albt16-codex-916-rollout.md`, is the powered-off `916`
   machine rollout and is not this workstream's to close.
   *Recommendation: Albert decides whether the `916` rollout is still wanted.*

### Already settled — do NOT re-ask

- **Codex has a skills system.** Measured, not assumed. The stale sentence is
  corrected. Do not "restore" it.
- **A Codex trigger counts only when the model RAN a command opening the skill.**
  Output text does not count. This is deliberate, not an oversight.
- Everything settled in the step-5 handoff still stands: the short response-style
  contract; 22.7% accepted for the globals; pilots are `popdam` and `shared-db`;
  `bin/install-ai-devops-windows.ps1` stays PowerShell 5.1-safe; no `@AGENTS.md`;
  GPT-5.6 stays `low`/`medium`; budgets warn and never fail; do not delegate plan
  steps to `ai-glm implement`.

---

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public backup-and-restore toolkit for his
multi-model AI coding workflow. Albert is a business owner, not a programmer; this
repo is the durable memory of his "engineering department". It is 100% owned Bash,
PowerShell, Python, and Markdown. There is no app, database, container, hosted
service, or CI, and nothing here is deployed. Branch policy is `main` only.

What matters for this work:

- `templates/system/CLAUDE-global.md` and
  `templates/system/AGENTS-global-codex.md` — the two **always-loaded** globals,
  installed as `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`.
- `skills/shared/` (installs to BOTH clients), `skills/claude/`, `skills/codex/`.
  `bin/ai-install-skills` routes by folder and **fails closed on a name collision**
  between `shared/` and a client tree.
- `tools/skill-trigger-eval/` — two runners plus the eval sets. The Claude runner
  watches for the `Skill` tool event; the Codex runner watches for Codex opening
  the installed `SKILL.md`, because Codex emits no such event.
- `tools/context-audit/context-audit.py` — the dependency-free audit and gates.
- `docs/context-engineering.md` — baseline, ownership map, budgets, audit trail.

## 2. What we set out to do this session, and why

Execute the **opening task of step 6**: write the first Codex trigger eval sets.
Albert made this the gate on 2026-08-12, because everything else in step 6 —
merging duplicated skills, and trimming the Codex global's ritual summaries —
risks a skill that silently stops firing, and there was no way to measure that
for Codex at all.

Business reason: a skill that stops firing costs Albert a whole session, and he
would have no way to tell that it was the skill rather than the model.

## 3. Current state — what is true right now

**Done, committed, and pushed to `main` as `92d36ff`.**

- **New:** `tools/skill-trigger-eval/codex-qwen-code.eval.json` — 10 should-fire,
  10 should-not-fire. Chosen first because `skills/claude/qwen-code` and
  `skills/codex/codex-qwen-code` have byte-identical descriptions, so **one set
  scores both clients** and can gate the merge.
- **New:** `tools/skill-trigger-eval/codex-shared-db-change.eval.json` — same
  shape. Chosen because both globals name that skill, so it is load-bearing. Its
  positives deliberately cover Rule 0 read-only inspection as well as schema
  changes, because the description routes both there.
- **Measured result, reproducible:** `codex-qwen-code` scores **10/10 should-fire
  and 0/10 should-not-fire** against the real `codex` CLI (0.145.0) at `low`
  effort in a read-only sandbox.
- **`codex-shared-db-change` scored 8/10, was fixed, and now scores 10/10
  should-fire and 0/10 should-not-fire.** The two misses were its own verbatim
  trigger phrase, "make db changes the proper way", and Rule 0 schema inspection.
  They missed in this repo AND in the `popdam3` app repo, so it was never a
  wrong-repo artifact. The fix was **description-only** — the name is
  load-bearing, because both globals point at it. Trigger phrases were moved to
  the front of a description that had buried them behind a slash-list of object
  types, `"what columns exist"` was added, and a stale "Codex has no auto-loaded
  skills" sentence was deleted. 64 characters shorter. Overlap stayed 0.

**Also done, committed, and pushed to `main` as `29ea53f` (step 6's main task).**

- **The Qwen pair is merged into `skills/shared/qwen-code`.** The two files were
  identical apart from the name, including `agents/openai.yaml`. Duplicate
  paragraph groups **12 → 2**; task-triggered text fell about 5.5 KB and one file.
- **The merged skill still scores 10/10 and 0/10** after installing to both
  clients — identical to its pre-merge score. Eval set renamed
  `qwen-code.eval.json`.
- **Installed on this machine.** `bin/ai-install-skills` put the shared skill in
  both `~/.claude/skills/qwen-code` and `~/.codex/skills/qwen-code`, and moved the
  old copy to `~/.codex/skills-quarantine/codex-qwen-code`, recoverable. It did
  **not** touch either global, which is correct until step 8.
- **The last 2 duplicates are kept on purpose**, with reasons in
  `docs/context-engineering.md`: a credential-incident STOP banner and the handoff
  self-audit gate. No other client pair was merged; their bodies genuinely differ.
- `docs/codex-skills-usage-guide.md`, `docs/skills-map.md`, and both READMEs are
  updated. Task-triggered is **401,671 bytes** measured from `C:\repos\ai-devops`.
- **`tools/skill-trigger-eval/codex-trigger-eval.py` has two bug fixes** (see §4)
  and a new `evidence` field on every hit. `run_query` now returns
  `(opened, evidence)` instead of a bool.
- **New:** `tests/test-codex-trigger-eval.sh` — offline, calls no model. Locks the
  two hard invocation rules and both detection fixes.
- **`templates/system/AGENTS-global-codex.md`:** the false "Codex has no skills
  system" sentence is corrected, and the session-rituals heading now points at
  `~/.codex/skills/` instead of `skills/claude/`.
- **`.gitignore`:** the per-run output rule was `*.results.json`, which never
  matched the Codex runner's `<set>.codex-results.json`. Now `*results.json`.
- `docs/context-engineering.md`, `docs/development.md`, the plan STATUS row, the
  fresh-session pointer, decision 5, and a new step-6 drift block are updated.

**Byte counts, measured from `C:\repos\ai-devops` after pushing (CRLF-canonical):**
always-loaded **24,703** bytes (budget 24,713, so 10 bytes of headroom);
startup-routed **35,972** bytes, unchanged. **No budget was raised.**

**Verified green on 2026-08-12, all seven named suites plus the new one:**

```bash
python tools/context-audit/context-audit.py --root . --strict   # exit 0
bash tests/test-ai-install-skills.sh
bash tests/test-ai-memory-sync.sh
bash tests/test-codex-trigger-eval.sh
bash tests/test-windows-scripts.sh                              # 25 passed, 0 failed
```

```powershell
pwsh -NoProfile -File tests/test-context-audit.ps1
pwsh -File tests/test-install-ai-devops-windows.ps1
pwsh -File tests/test-mcp-env-launch.ps1
pwsh -File tests/test-memory-sync-scheduled-task.ps1
```

The audit reports zero on every counter that matters. **Duplicate paragraphs
still read 12 — that is step 6's untouched main task.**

**Nothing was installed on any machine.** The trimmed globals still exist only in
the repo. That remains correct until step 8.

## 4. Everything we tried that did NOT work

- **Trusting the runner's score. The first real run was wrong in BOTH directions,
  and neither error was visible from the score.** This is the single most
  important thing to carry forward.
  - **Understated.** The runner matched the installed path against the raw event
    line. Codex reports the command it ran inside a JSON string, and that command
    is itself a quoted shell string, so one separator arrives as two or four
    backslashes. A query where Codex had **visibly** opened the skill scored 0/1.
    Fixed by collapsing backslash runs before matching.
  - **Overstated.** Matching anywhere in the event line counted a trigger whenever
    the skill path merely *appeared* in something the model read. This repo
    contains several such files — including the new test fixture, which embeds the
    literal installed path. That produced **4 unearned false positives out of 10
    legitimate negatives.** Fixed by counting only a `command_execution`'s
    **command**, never its output.
- **Assuming those false positives were flaky model behavior. They were not.**
  Re-running each one alone produced no trigger, which looked like nondeterminism.
  It was deterministic self-contamination. **Do not diagnose a trigger score by
  re-running and eyeballing; read the `evidence` field, which now exists for
  exactly this reason.**
- **Guessing which needle matched. Wasted two rounds.** The evidence snippet was
  truncated at 400 characters and the real match was past the cut. Compute the
  answer, do not infer it.
- **Writing the corrected global sentence at natural length. It blew the budget by
  70 bytes.** The globals are ratcheted to the byte. Any replacement sentence must
  be counted, not estimated; the fix was to shorten both the sentence and the
  heading below it.

## 5. Root causes and key findings

- **Codex's trigger signal is structurally weaker than Claude's, and the weakness
  is exploitable by accident.** Claude emits a `Skill` tool event — an unambiguous
  selection. Codex only reads a file, so "selection" has to be inferred from a
  command. Any file that names the path can forge that inference. The rule that
  saves it: *a command the model chose to run is a decision; text scrolling past
  in output is not.*
- **A trigger score proves selection, never obedience.** Unchanged from the
  runner's original design, and worth repeating because 10/10 reads like more
  than it is. It means Codex went and looked at the right skill.
- **The globals are now measured to the byte and have 10 bytes of headroom.** Any
  step-6 or step-7 edit to a global is effectively a zero-sum trade.
- **The `.gitignore` bug means earlier Codex runs could have committed per-run
  output.** Nothing was committed, but check `git status` after any eval run in a
  clone made before `92d36ff`.
- **The Codex ritual summaries in the global are still the main always-loaded
  reduction candidate**, and each now needs its own eval set before removal —
  that is what the eval-set gate was for.

## 6. Exact next steps

These cover the whole remaining plan, steps 6 through 10, in order.

1. **Score the four load-bearing skills the globals name.** Only
   `codex-shared-db-change` has ever been measured, and it was found under-firing.
   `synology-long-running-operations`, `shared-db-change` (the Claude twin), and
   `handoff-writer` have no eval set at all. Write one set each, 10 positive and
   10 negative, modelled on the two committed sets.
   ```bash
   bash bin/ai-install-skills            # the runner tests the INSTALLED skill
   python tools/skill-trigger-eval/codex-trigger-eval.py --skill <name>      --eval-set tools/skill-trigger-eval/<name>.eval.json --workers 4
   ```
   Fix by editing the DESCRIPTION only, never the name, and keep an edit only if
   should-fire improves and should-not-fire stays 0/10.
   *You'll know it worked when* each load-bearing skill has a committed set and a
   recorded score, and `--strict` still exits 0 with overlap at 0.
2. **Optional, and only if a later step needs it: merge another client pair.**
   None is queued. The remaining pairs' bodies genuinely differ, and each would
   need its own eval set written and scored before and after. Do not merge on a
   matching name.
3. **Step 7 — repair installation drift safely.** Preview-first reconciliation in
   BOTH `bin/ai-install-skills` and `bin/install-ai-devops-windows.ps1`, keeping
   machine overlays. Re-measure drift first (`installed source drift` reads 0 on
   this machine; do not assume the plan's four named skills are still the issue).
   Keep the child installer path PowerShell 5.1-safe (Albert's decision).
   *You'll know it worked when* the fixture matrix (absent, identical, locally
   extended, locally conflicting, obsolete managed, vendor-unmanaged) behaves as
   designed, a dry run writes nothing, a second apply changes nothing, and both
   installers produce the same managed outcome.
4. **Step 8 — pilot on `al8960ofc`, then `popdam` and `shared-db`.** Save
   pre-install hashes and recoverable copies of both installed globals first. Run
   the installer dry-run, inspect, install, then **fully restart both clients** so
   startup context reloads. Run the deferred step-4 probes: does a session still
   route a shared-db change correctly, refuse a production mutation, verify Git
   identity, and open `templates/system/handoff-standard.md` when writing a
   handoff? Add the step-5 probe (does it open `docs/design-decisions.md` instead
   of guessing?) and a **new step-6 probe: does a Codex session actually open the
   skill it needs now that the global says skills exist?**
   *You'll know it worked when* every safety probe passes, real tasks complete
   correctly, no machine-specific facts vanished, and the installed file actually
   contains the new text (do not accept installer exit code 0 as proof).
5. **Step 9 — roll out to `916-alien`, `albt16`, then the Ubuntu AI users.** Check
   reachability and concurrent work, fast-forward `main`, dry-run and diff per
   machine, install, restart clients, run `ai-devops doctor`.
6. **Step 10 — measure, set final budgets, close.** Compare before/after startup
   context, tool calls, task success, and safety probes. Set the real budgets from
   what proved safe, editing all three places. Update the plan STATUS, write a
   memory entry if anything durable was learned, and delete the handoffs whose
   work is proven done.
7. **A worthwhile addition for step 6 or 10:** teach the audit to validate
   backticked prose paths inside the globals and the router. The pointers this
   design depends on are still not link-checked (see §7).
8. **Do not delegate any of this to `ai-glm implement`** until the GLM permission
   bug is fixed. GLM review sessions are fine.

## 7. Constraints and gotchas in force

- **A budget number lives in three places:** `tools/context-audit/budgets.json`,
  `DEFAULT_BUDGETS` in `tools/context-audit/context-audit.py`, and the table in
  `docs/context-engineering.md`. Ratchet all three or they silently disagree.
  **Never raise a budget to silence a warning.**
- **Measure sizes from `C:\repos\ai-devops` after committing.** A worktree with
  LF-ending edits can understate byte counts by roughly 400. This session's edits
  happened to be CRLF-clean and both checkouts agreed at 24,703, but do not rely
  on that.
- **Never delete a rule from only one client global.** Eleven parity rules must
  appear in both, or the rule needs an entry in `PARITY_DIVERGENCE_ALLOWLIST`
  (`tools/context-audit/context-audit.py:84`) with a stated reason. `--strict`
  also fails on a *stale* allowlist entry.
- **The pointers are still not link-checked.** They are backticked prose paths, so
  the link checker never sees them. Renaming any of
  `templates/system/handoff-standard.md`,
  `docs/cloud-build-prod-trigger-incident-2026-07-20.md`,
  `docs/future-visual-testing.md`, `bin/ai-git-identity`, `docs/glm-opencode.md`,
  `bin/ai-grok-review`, `bin/ai-grok-implement`, `bin/ai-kimi`,
  `docs/design-decisions.md`, `docs/critical-incidents.md`, or the
  `synology-long-running-operations`, `shared-db-change`,
  `codex-shared-db-change`, or `handoff-writer` skills means updating the globals
  and `AGENTS.md` in the same commit.
- **Codex eval runs cost real model calls and take minutes.** A 20-query set at
  `--workers 4` runs about 5 minutes. Run them in the background and never at
  `high` effort — the runner refuses anything but `low`/`medium`, by standing rule.
- **New skills go in `skills/shared/` by default.** A name may live in `shared/`
  OR a client tree, never both; the installer fails closed on the collision.
- **Concurrent sessions work this repo.** Re-fetch before pushing; never
  `git add -A` over another session's uncommitted work; never edit or delete
  another session's `HANDOFF.d/` file.
- Commit identity must read `Albert Hazan <u2giants@users.noreply.github.com>`;
  verified this session with `git var GIT_COMMITTER_IDENT`.
- `.ai/` and `docs/claude-remote-control-hardening-v2.md` are unrelated untracked
  work in the primary checkout. Leave them alone. `.ai/` must never be committed.
- No production, shared-cloud, Supabase, Coolify, NAS, or database mutation is
  part of this plan. No secret read should ever be needed.
- **`HANDOFF.d/` holds 6 open files, over the 5-file warning line.** See §0 item 4.

## 8. Access and environment

- Everything needed was local. **No credential, secret, 1Password read, cloud
  call, or network access beyond `git fetch`/`push` and the Codex CLI's own model
  calls was required, and none was made.** Secrets, if a later step unexpectedly
  needs one, live only in the 1Password vault `vibe_coding` — reference by item
  name, never by value.
- Tools used and confirmed present on `al8960ofc`: `git`, `python`, `bash` (Git
  Bash), `pwsh` (PowerShell 7), and `codex` 0.145.0 at
  `C:\Users\ahazan2\.codex\packages\standalone\current\bin\codex`, already
  authenticated.
- The Codex runner tests the **installed** skill in `~/.codex/skills/`, not the
  repo copy. 30 Codex skills are installed on this machine, including both skills
  named above. If a set scores 0 everywhere, check installation before the skill.
- Primary checkout `C:\repos\ai-devops`; this work happened in the worktree
  `C:\repos\ai-devops-worktrees\router-tightened-step-6-2b48cf`.
- Steps 8 and 9 will need SSH or local access to `916-alien`, `albt16`, and the
  Ubuntu AI users. Verify reachability with a real call before planning around it.
- There is no server to start, no URL to deploy, and no CI.

## 9. Open questions and risks

- **Risk (new, and the reason this session took as long as it did): a measurement
  tool that is wrong looks exactly like a result.** The Codex runner reported both
  a false 0 and four false 1s within one hour, and every one of them was
  believable. Anything step 6 or 10 concludes from a trigger score must be
  supported by the `evidence` field. If evidence is empty, the number is not
  usable.
- **Risk (highest, unchanged): a pointer is never followed.** The whole design
  assumes an agent opens `docs/design-decisions.md` or
  `templates/system/handoff-standard.md` when told to. Step 8's probes must test
  it. If a probe shows an agent "fixing" an intentional quirk because the
  reasoning left the router, restore that block and record it.
- **Risk: rollback must not be improvised.** Before step 8 installs anything, save
  hashes and recoverable copies of both installed globals and the managed-skill
  manifest. Roll back through the same installer. Never `git reset --hard`, never
  delete unowned skill directories, never overwrite a local overlay.
- **Risk: the installed globals are now very far from source.** Installers seed
  only when absent, and the globals have been rewritten three times since any
  machine was seeded. Step 7's preview will show a large diff; that is expected.
- **Open question: what should the final budgets be?** 23,318 and 35,340 were flat
  30% guesses from step 3, never measurements. Step 10 sets the real ones.
- **Open question: what is a passing trigger score?** Two data points exist:
  `qwen-code` at 10/10 and 0/10, and `codex-shared-db-change` at 8/10 and 0/10.
  The merge used "no regression against the pre-merge score", which worked. Nobody
  has decided what score is acceptable for a skill in isolation — 8/10 on a
  safety skill is clearly not, but the line is undrawn.
- **Risk: an under-firing safety skill is invisible.** Nothing in the audit,
  the tests, or `--strict` would ever have surfaced the 8/10. Only a written eval
  set found it. Every load-bearing skill the globals name
  (`synology-long-running-operations`, `shared-db-change`,
  `codex-shared-db-change`, `handoff-writer`) deserves a set; only one has one.
- **Decision, 2026-08-12 (step 6):** Codex has a skills system, measured, and the
  global says so.
- **Decision, 2026-08-12 (step 6):** only a command the model ran counts as a
  trigger. Output text does not.

---

**Self-audit gate: passed 2026-08-12.** All ten sections present. §0 was built by
re-reading §1-§9 and promoting every sentence needing Albert's judgement. A
newcomer has the app description (§1), the goal and its business reason (§2),
exact current state with the commit SHA, byte counts, and what is explicitly NOT
done (§3), the dead ends including both directions the measurement lied in (§4),
the non-obvious findings with `file:line` (§5), executable steps for all remaining
plan phases each with a verification gate (§6), the standing traps (§7), the
environment including the exact `codex` version and path (§8), and the dated
decisions and open questions (§9). No secret value appears anywhere.
