# Handoff: context-engineering step 6 — DONE. Codex skills are now measurable, and one safety skill was found broken and fixed

- **Machine:** `al8960ofc` (Windows 11, user `ahazan2`, PowerShell 7 primary)
- **Agent:** Claude (Opus 5) in Claude Code
- **Repo:** `u2giants/ai-devops`. Worked in the worktree
  `C:\repos\ai-devops-worktrees\router-tightened-step-6-2b48cf` on branch
  `claude/router-tightened-step-6-2b48cf`. **Every commit is on `origin/main`.**
- **Status:** **step 6 is complete, committed, and pushed** in three commits:
  `92d36ff` (the eval sets and two runner bug fixes), `29ea53f` (the Qwen merge),
  `7e3459b` (the shared-db under-firing fix). Duplicate paragraph groups are
  **12 → 2**, and both committed eval sets score **10/10 should-fire, 0/10
  should-not-fire**. **Next phase is step 7.** Steps 7, 8, 9, 10 remain, and
  step 4 still owes two probes to step 8. The plan is
  [`plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md).

---

## 0. ⚠️ DECISIONS ONLY ALBERT CAN MAKE

Put this whole list to Albert in ONE message before starting work.

### Blocking — the next session cannot finish without an answer

1. **Nothing is blocking.** Step 7 can start immediately and run to completion
   without Albert. The first thing that genuinely needs him is still step 8, the
   pilot, because that is the first step that changes a machine's globals.

### A wrong guess is recoverable, but the rework is wasteful

2. **Three of the four skills Albert's global instructions name have never been
   tested.** This session measured one of them, `codex-shared-db-change`, and
   found it opening on only 8 of 10 prompts it should have — including its own
   trigger phrase. It is fixed. The other three have no test at all:
   `synology-long-running-operations`, `shared-db-change` (the Claude twin), and
   `handoff-writer`.
   *Recommendation: write and score a set for each before step 8, so the pilot has
   a real before-and-after number instead of a guess. About an hour of model runs,
   no risk, fully reversible.*
3. **The Claude twin `skills/claude/shared-db-change` has the same buried wording
   the Codex one had, but Claude picks skills a different way**, so the Codex
   result does not transfer and the Claude one may be fine.
   *Recommendation: measure it with `skill-trigger-eval.py` before changing a
   character of it. Do NOT copy the Codex fix across blind — the Codex fix was
   only defensible because there was a before and after number.*

### Not part of this work, and nobody is on it

4. **`HANDOFF.d/` holds 6 open files, one OVER the 5-file warning line.** The
   oldest, `2026-08-10T1138Z-albt16-codex-916-rollout.md`, is the powered-off
   `916` machine rollout and is not this workstream's to close.
   *Recommendation: Albert decides whether the `916` rollout is still wanted. If
   it is not, that file can be deleted and the count drops to 5.*

### Already settled — do NOT re-ask

- **Codex has a skills system.** Measured on 2026-08-12, not assumed. The false
  sentence in the Codex global is corrected. Do not "restore" it.
- **A Codex trigger counts only when the model RAN a command opening the skill.**
  Text scrolling past in a command's output does not count. Deliberate, and the
  reason a score can be trusted at all.
- **The last 2 duplicate paragraphs stay.** Both are safety text. Reasons are in
  `docs/context-engineering.md`.
- **No other client skill pair gets merged** without its own eval set, measured
  before and after. A matching name is not evidence of duplication.
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
  installed as `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`. Every session on
  every machine pays for every byte.
- `skills/shared/` (installs to BOTH clients), `skills/claude/`, `skills/codex/`.
  `bin/ai-install-skills` routes by folder and **fails closed on a name collision**
  between `shared/` and a client tree. A skill is a procedure the model loads only
  when a task fits it.
- `tools/skill-trigger-eval/` — two runners plus the eval sets. An **eval set** is
  a list of realistic prompts, each labelled "this should open the skill" or "this
  should not". The Claude runner watches for Claude's `Skill` tool event; the
  Codex runner watches for Codex opening the installed `SKILL.md`, because Codex
  emits no such event.
- `tools/context-audit/context-audit.py` — the dependency-free audit and its
  enforcement gates (`--strict`).
- `docs/context-engineering.md` — the baseline, the ownership map, the budgets,
  and the audit trail of what moved where.

## 2. What we set out to do this session, and why

Execute **step 6 of the plan: remove cross-client skill duplication safely** —
opening with the task Albert gated it on, writing the first Codex trigger eval
sets.

Business reason for the gate: merging two copies of a skill into one, or trimming
the Codex global, can leave a skill that silently stops firing. Albert would
experience that as the assistant "just not doing the thing anymore", with no way
to tell the skill was at fault. Before this session there was **no way at all** to
measure whether a Codex skill fires.

All of step 6 got done: the eval sets, the merge they were meant to gate, and a
safety fix that only existed because the measurement existed.

## 3. Current state — what is true right now

### Commit `92d36ff` — the eval sets and the runner they broke

- **New:** `tools/skill-trigger-eval/qwen-code.eval.json` (committed as
  `codex-qwen-code.eval.json`, renamed in the next commit) — 10 should-fire, 10
  should-not-fire. Chosen first because the Claude and Codex copies of the Qwen
  skill had byte-identical descriptions, so **one set scores both clients**.
- **New:** `tools/skill-trigger-eval/codex-shared-db-change.eval.json` — same
  shape. Chosen because both globals name that skill, so it is load-bearing. Its
  positives deliberately cover Rule 0 read-only inspection as well as schema
  changes, because the description routes both there.
- **`tools/skill-trigger-eval/codex-trigger-eval.py` gained two bug fixes** (see
  §4) and an `evidence` field on every hit. **`run_query` now returns
  `(opened, evidence)` instead of a bool** — anything consuming its JSON must
  expect the new field.
- **New:** `tests/test-codex-trigger-eval.sh` — offline, calls no model. Locks the
  two hard invocation rules (explicit `low`/`medium` effort, read-only sandbox)
  and both detection fixes.
- **`templates/system/AGENTS-global-codex.md`:** the false "Codex has no skills
  system" sentence is corrected on measured evidence, and the session-rituals
  heading now points at `~/.codex/skills/` instead of `skills/claude/`.
- **`.gitignore`:** the per-run output rule was `*.results.json`, which never
  matched the Codex runner's `<set>.codex-results.json`. Now `*results.json`.

### Commit `29ea53f` — the merge

- **The Qwen pair is merged into `skills/shared/qwen-code`.**
  `skills/claude/qwen-code` and `skills/codex/codex-qwen-code` were identical
  apart from the name, including `agents/openai.yaml`.
- **Duplicate paragraph groups 12 → 2.** Task-triggered text fell about 5.5 KB
  and one file.
- **The merged skill scores 10/10 and 0/10 after installing to both clients** —
  identical to its pre-merge score. That was the gate for keeping the merge.
- Eval set renamed `qwen-code.eval.json` to match the new installed name.
- **The last 2 duplicates are kept on purpose**, with reasons in
  `docs/context-engineering.md`: a credential-incident STOP banner shared by the
  two transcript skills, and the handoff self-audit gate shared by the two
  docs-update skills.
- `docs/codex-skills-usage-guide.md` corrected: `--migrate-obsolete` is a no-op
  and quarantine is automatic.

### Commit `7e3459b` — the safety fix the measurement found

- **`codex-shared-db-change` scored 8/10, and now scores 10/10** should-fire, with
  should-not-fire at 0/10 throughout. The two misses were **its own verbatim
  trigger phrase**, "make db changes the proper way", and Rule 0 schema
  inspection ("review the schema — what columns exist…").
- **They missed in this repo AND in `C:\repos\popdam3`, a real app repo on the
  shared database.** It was never a wrong-repo artifact. In practice a Codex
  session could have changed the shared database without opening the rules that
  stop an app repo authoring its own migration.
- The fix was **description-only** — the name is load-bearing because both globals
  point at it. Trigger phrases were moved to the front of a description that had
  buried them behind a slash-list of object types, `"what columns exist"` was
  added, and a stale "Codex has no auto-loaded skills" sentence was deleted.
  64 characters shorter. Overlap stayed 0.

### This machine's installed state — matters for step 7

- **`bin/ai-install-skills` was RUN on `al8960ofc` twice**, because the runner
  tests the INSTALLED skill, not the repo copy. So **installed skills on this
  machine now match source, and `installed source drift` reads 0.** The plan's
  old step-7 evidence line, "four installed skill drifts found", is **stale** and
  is marked stale in the plan.
- **Neither global was touched.** `install_global` seeds a global only when it is
  absent; both exist and differ, so the installer printed a diff hint and moved
  on. **No machine has the trimmed globals. That is still correct until step 8.**
- **A real obsolete-managed fixture now exists** at
  `~/.codex/skills-quarantine/codex-qwen-code`, produced by the normal path.
  Step 7's fixture matrix needs exactly this case. **Do not delete it before
  step 7 uses it.**

### Measurements, taken from `C:\repos\ai-devops` after pushing (CRLF-canonical)

| Class | Bytes | Note |
|---|---:|---|
| always-loaded globals | **24,703** | budget 24,713 — **10 bytes of headroom** |
| startup-routed (`AGENTS.md` + `CLAUDE.md`) | **35,972** | unchanged this session |
| task-triggered | **401,605** across 47 files | was 408,341 pre-merge, but that figure was measured inside a worktree, so **do not present the difference as an exact canonical delta** |
| duplicate paragraph groups | **2** | from 12 |
| global-vs-skill-description overlaps | **0** | unchanged |

**No budget was raised at any point.**

### Verified green on 2026-08-12 — all seven named suites plus the new one

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

## 4. Everything we tried that did NOT work

- **Trusting the runner's score. The first real run was wrong in BOTH directions,
  and neither error was visible from the score.** This is the single most
  important thing to carry forward.
  - **Understated.** The runner matched the installed path against the raw event
    line. Codex reports the command it ran inside a JSON string, and that command
    is itself a quoted shell string, so one path separator arrives as two or four
    backslashes. A query where Codex had **visibly** opened the skill scored 0/1.
    Fixed by collapsing backslash runs before matching.
  - **Overstated.** Matching anywhere in the event line counted a trigger whenever
    the skill path merely *appeared* in something the model read. This repo
    contains several such files — including the new test fixture, which embeds the
    literal installed path. That produced **4 unearned false positives out of 10
    legitimate negatives.** Fixed by counting only a `command_execution`'s
    **command**, never its output.
- **Assuming those false positives were flaky model behavior. They were not.**
  Re-running each one alone produced no trigger, which looked like
  nondeterminism. It was deterministic self-contamination. **Do not diagnose a
  trigger score by re-running and eyeballing; read the `evidence` field, which
  exists for exactly this reason.**
- **Guessing which needle matched. Wasted two rounds.** The evidence snippet was
  truncated at 400 characters and the real match was past the cut. Compute the
  answer, do not infer it.
- **Blaming the repo for the shared-db misses.** The obvious excuse was "this repo
  has no database, so of course Codex skipped it". Re-running both misses with
  `--project C:\repos\popdam3` killed that excuse in five minutes. **Kill the
  convenient explanation before you accept a bad number.**
- **Writing the corrected global sentence at natural length. It blew the budget by
  70 bytes.** The globals are ratcheted to the byte. Any replacement sentence must
  be counted, not estimated; the fix was to shorten both the sentence and the
  heading below it.
- **Editing a skill and re-scoring without reinstalling. Measures nothing.** The
  runner reads `~/.codex/skills/<name>/SKILL.md`. Run `bash bin/ai-install-skills`
  between every edit and every score.

## 5. Root causes and key findings

- **A skill description is routing, and it is measurable.** This is the durable
  lesson. `codex-shared-db-change` failed on its own trigger phrase because the
  phrase sat mid-sentence behind a long slash-list of object types. Front-loading
  the quoted phrases fixed it, with zero new false positives.
- **An under-firing safety skill is invisible to every gate this repo has.**
  Nothing in the audit, the test suites, or `--strict` would ever have surfaced
  the 8/10. Only a written eval set found it. Three of the four load-bearing
  skills still have none.
- **Codex's trigger signal is structurally weaker than Claude's, and the weakness
  is exploitable by accident.** Claude emits a `Skill` tool event — an unambiguous
  selection. Codex only reads a file, so "selection" has to be inferred from a
  command. Any file that names the path can forge that inference. The rule that
  saves it: *a command the model chose to run is a decision; text scrolling past
  in output is not.*
- **A trigger score proves selection, never obedience.** Worth repeating because
  10/10 reads like more than it is. It means Codex went and looked at the right
  skill, not that it followed it.
- **The globals have 10 bytes of headroom.** Any step-7 or step-8 edit to a global
  is effectively a zero-sum trade until step 10 sets real budgets.
- **The `.gitignore` bug means an eval run in an older clone can leave results
  staged.** Nothing was committed here, but check `git status` after an eval run
  in any clone made before `92d36ff`.
- **The Codex ritual summaries in the global remain the main always-loaded
  reduction candidate**, and each now needs its own eval set before removal —
  which is exactly what the eval-set gate was built for.

## 6. Exact next steps

These cover the whole remaining plan, steps 7 through 10, in order.

1. **Score the three unmeasured load-bearing skills. Do this before step 8.**
   `synology-long-running-operations`, `shared-db-change` (the Claude twin, which
   needs the Claude runner `skill-trigger-eval.py`, not the Codex one), and
   `handoff-writer`. Write one set each, 10 positive and 10 negative, modelled on
   the two committed sets. Fix only by editing the DESCRIPTION, never the name.
   ```bash
   bash bin/ai-install-skills            # the runner tests the INSTALLED skill
   python tools/skill-trigger-eval/codex-trigger-eval.py \
     --skill <name> \
     --eval-set tools/skill-trigger-eval/<name>.eval.json \
     --workers 4 --timeout 300
   ```
   *You'll know it worked when* each of the three has a committed set and a
   recorded score, any edit improved should-fire while should-not-fire stayed at
   0/10, `--strict` exits 0, and overlap is still 0.
2. **Step 7 — repair installation drift safely.** Preview-first reconciliation in
   BOTH `bin/ai-install-skills` and `bin/install-ai-devops-windows.ps1`, keeping
   machine overlays. **Re-measure drift first: this machine now reads 0 because
   the installer was run here during step 6, and the plan's "four installed skill
   drifts" line is stale.** Use the real quarantined fixture at
   `~/.codex/skills-quarantine/codex-qwen-code` for the obsolete-managed case.
   Keep the child installer path PowerShell 5.1-safe (Albert's decision).
   *You'll know it worked when* the fixture matrix (absent, identical, locally
   extended, locally conflicting, obsolete managed, vendor-unmanaged) behaves as
   designed, a dry run writes nothing, a second apply changes nothing, and both
   installers produce the same managed outcome.
3. **Step 8 — pilot on `al8960ofc`, then `popdam` and `shared-db`.** Save
   pre-install hashes and recoverable copies of both installed globals first. Run
   the installer dry-run, inspect it, install, then **fully restart both clients**
   so startup context reloads. Run the deferred step-4 probes: does a session
   still route a shared-db change correctly, refuse a production mutation, verify
   Git identity, and open `templates/system/handoff-standard.md` when writing a
   handoff? Add the step-5 probe (does it open `docs/design-decisions.md` instead
   of guessing?) and a **step-6 probe: does a Codex session open the skill it
   needs, now that the global tells it skills exist?**
   *You'll know it worked when* every safety probe passes, real tasks complete
   correctly, no machine-specific facts vanished, and the installed file actually
   contains the new text — do not accept installer exit code 0 as proof.
4. **Step 9 — roll out to `916-alien`, `albt16`, then the Ubuntu AI users.** Check
   reachability and concurrent work, fast-forward `main`, dry-run and diff per
   machine, install, restart clients, run `ai-devops doctor`.
5. **Step 10 — measure, set final budgets, close.** Compare before/after startup
   context, tool calls, task success, safety probes, **and the trigger scores from
   step 1 above**. Set the real budgets from what proved safe, editing all three
   places. Update the plan STATUS, write a memory entry if anything durable was
   learned, and delete the handoffs whose work is proven done.
6. **A worthwhile addition for step 7 or 10:** teach the audit to validate
   backticked prose paths inside the globals and the router. The pointers this
   whole design depends on are still not link-checked (see §7).
7. **Do not delegate any of this to `ai-glm implement`** until the GLM permission
   bug is fixed. GLM review sessions are fine.

## 7. Constraints and gotchas in force

- **The runner tests the INSTALLED skill.** Reinstall between an edit and a score,
  or you measure the old text. This is the easiest way to waste an hour.
- **A budget number lives in three places:** `tools/context-audit/budgets.json`,
  `DEFAULT_BUDGETS` in `tools/context-audit/context-audit.py`, and the table in
  `docs/context-engineering.md`. Ratchet all three or they silently disagree.
  **Never raise a budget to silence a warning.**
- **Measure sizes from `C:\repos\ai-devops` after committing.** A worktree with
  LF-ending edits can understate byte counts by roughly 400. This session's global
  edits happened to be CRLF-clean and both checkouts agreed at 24,703, but the
  task-triggered figure did move between the two, so do not rely on it.
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
  `--workers 4` runs about 5 minutes. Run them in the background, and never at
  `high` effort — the runner refuses anything but `low`/`medium`, by standing rule.
- **New skills go in `skills/shared/` by default.** A name may live in `shared/`
  OR a client tree, never both; the installer fails closed on the collision.
- **Concurrent sessions work this repo.** Re-fetch before pushing; never
  `git add -A` over another session's uncommitted work; never edit or delete
  another session's `HANDOFF.d/` file. Every push this session needed a rebase.
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
  authenticated. The Claude runner additionally needs `claude auth status` to be
  logged in; that was never exercised this session.
- **30 Codex skills and 35 Claude skills are installed on this machine**, current
  with source as of `7e3459b`. If a set scores 0 everywhere, check installation
  before blaming the skill.
- `C:\repos\popdam3` is a local app repo on the shared database, used read-only
  this session to disprove the "wrong repo" explanation. Nothing was changed in it.
- Primary checkout `C:\repos\ai-devops`; this work happened in the worktree
  `C:\repos\ai-devops-worktrees\router-tightened-step-6-2b48cf`.
- Steps 8 and 9 will need SSH or local access to `916-alien`, `albt16`, and the
  Ubuntu AI users. Verify reachability with a real call before planning around it.
- There is no server to start, no URL to deploy, and no CI.

## 9. Open questions and risks

- **Risk (new, and the reason this session took as long as it did): a measurement
  tool that is wrong looks exactly like a result.** The Codex runner reported both
  a false 0 and four false 1s within one hour, and every one of them was
  believable. Anything step 10 concludes from a trigger score must be supported by
  the `evidence` field. If evidence is empty, the number is not usable.
- **Risk: an under-firing safety skill is invisible.** Only a written eval set
  found the 8/10. Three of the four load-bearing skills still have no set, so the
  same defect could be sitting in any of them right now, undetected. §6 step 1.
- **Risk (highest, unchanged): a pointer is never followed.** The whole design
  assumes an agent opens `docs/design-decisions.md` or
  `templates/system/handoff-standard.md` when told to. Step 8's probes must test
  it. If a probe shows an agent "fixing" an intentional quirk because the
  reasoning left the router, restore that block and record it.
- **Risk: rollback must not be improvised.** Before step 8 installs anything, save
  hashes and recoverable copies of both installed globals and the managed-skill
  manifest. Roll back through the same installer. Never `git reset --hard`, never
  delete unowned skill directories, never overwrite a local overlay.
- **Risk: the installed globals are far from source.** Installers seed only when
  absent, and the globals have been rewritten three times since any machine was
  seeded. Step 7's preview will show a large diff; that is expected. Note this is
  now true of the globals ONLY — installed skills on `al8960ofc` are current.
- **Open question: what should the final budgets be?** 23,318 and 35,340 were flat
  30% guesses from step 3, never measurements. Step 10 sets the real ones.
- **Open question: what is a passing trigger score?** Three data points exist:
  `qwen-code` 10/10 and 0/10 before and after its merge, and
  `codex-shared-db-change` 8/10 then 10/10, 0/10 throughout. The merge used "no
  regression against the pre-merge score", which worked well. Nobody has decided
  what score is acceptable for a skill measured in isolation — 8/10 on a safety
  skill clearly is not, but the line is undrawn.
- **Decision, 2026-08-12 (step 6):** Codex has a skills system, measured, and the
  global now says so.
- **Decision, 2026-08-12 (step 6):** only a command the model ran counts as a
  trigger; output text does not.
- **Decision, 2026-08-12 (step 6):** the last 2 duplicate paragraphs stay, because
  both are safety text and a gate that is pointed at is a gate that gets skipped.
- **Decision, 2026-08-12 (step 6):** a load-bearing skill is fixed by editing its
  description and re-scoring, never by renaming it and never by reading it and
  deciding it looks better.

---

**Self-audit gate: passed 2026-08-12, re-run after step 6 completed.** All ten
sections present. §0 was rebuilt by walking §1-§9 line by line and promoting every
sentence needing Albert's judgement; the three unmeasured load-bearing skills and
the unmeasured Claude twin were found that way and are now asks, not findings. A
newcomer has the app description with its jargon defined (§1), the goal and its
business reason (§2), exact current state per commit SHA with the measurement
table and this machine's installed state (§3), the dead ends including both
directions the measurement lied in and the convenient explanation that was wrong
(§4), the durable findings (§5), executable steps for every remaining phase each
with a verification gate (§6), the standing traps (§7), the environment including
the exact `codex` version and path (§8), and the dated decisions and risks (§9).
No secret value appears anywhere.
