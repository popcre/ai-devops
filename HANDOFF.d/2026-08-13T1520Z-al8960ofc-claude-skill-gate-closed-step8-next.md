# Handoff: Albert's skill-test gate is CLOSED. Step 8, the pilot, is next and has not started

- **Machine:** `al8960ofc` (Windows 11, user `ahazan2`, PowerShell 7 primary)
- **Agent:** Claude (Opus 5) in Claude Code
- **Repo:** `u2giants/ai-devops`. Worked in the worktree
  `C:\repos\ai-devops-worktrees\skill-tests-step-8-pilot-364d84` on branch
  `claude/skill-tests-step-8-pilot-364d84`. **Commit `45466a3` is on
  `origin/main`** (the eval sets, the two runner fixes, the docs write-up, the
  plan link repair). A second commit carries the plan STATUS row 7a.
- **Status:** **the three-eval-set gate Albert set on 2026-08-12 is done.** It
  was the only thing blocking step 8. **Step 8 itself has not started — not one
  byte of either global has been touched on this machine.** Steps 9 and 10
  remain, and step 4 still owes two probes to step 8. The plan is
  [`plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md);
  step 7's file in this folder remains the reference for how the installers work.

---

## 0. ⚠️ DECISIONS ONLY ALBERT CAN MAKE

Put this whole list to Albert in ONE message before starting work.

### Blocking — the next session cannot finish without an answer

1. **Nothing blocks step 8 any more.** Albert said "go ahead" and "proceed to the
   step 8 pilot" on 2026-08-13. The pilot changes this machine's always-loaded
   globals, so confirm he is ready for both clients to be fully restarted
   (that ends whatever session is running), then run it.

### A wrong guess is recoverable, but the rework is wasteful

2. **The `al8960ofc` machine section inside both installed globals contains one
   block that is arguably dead: the `Z:` home-drive trap, marked FIXED.** The fix
   is global now (the installer uses `%USERPROFILE%`; a User env var pins
   `HOME`), so the text is history, not configuration, and every session on this
   machine pays for it at startup. Albert asked about this directly on
   2026-08-13 and was told to leave it until step 10.
   *Recommendation: keep leaving it. Changing the globals and their machine
   sections in the same step makes it impossible to attribute any behavior
   change. Step 10 sets the real budgets and is the right moment.*
3. **Line endings: unchanged from step 7.** A few files carry CRLF in the
   committed blob, so two checkouts of the same commit differ byte for byte.
   *Recommendation: still leave it until step 10, and do NOT normalize
   mid-pilot.* Install and audit from the SAME checkout or the number never
   closes.

### Not part of this work, and nobody is on it

4. **Nothing new.** The `916-alien` rollout is still unfinished, its handoff is
   still deleted at Albert's instruction (2026-08-12), and the machine was
   unreachable every time it was tested. Do not re-create that file
   speculatively; git history holds it.

### Already settled — do NOT re-ask

- **The gate is closed. Do not re-run it as a prerequisite.** Scores are in the
  plan's STATUS row 7a and in `docs/skill-trigger-eval.md`.
- **A description edit is kept only if should-fire improves while should-not-fire
  stays 0/10.** Two edits failed that test this session and were reverted.
- **Fix a load-bearing skill by editing its DESCRIPTION, never its name.**
- **Keep `bin/install-ai-devops-windows.ps1` PowerShell 5.1-safe.**
- **A trigger score proves selection, never obedience.**
- **The last 2 duplicate paragraphs stay.** Both are safety text.
- Everything settled in the step-5, step-6, and step-7 handoffs still stands: the
  short response-style contract; 22.7% accepted for the globals; pilots are
  `popdam` and `shared-db`; no `@AGENTS.md` import; GPT-5.6 stays `low`/`medium`;
  budgets warn and never fail; do not delegate plan steps to `ai-glm implement`;
  an installer classifies before it writes; a global is never replaced without
  `--adopt-globals`.

---

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public backup-and-restore toolkit for his
multi-model AI coding workflow. Albert is a business owner, not a programmer;
this repo is the durable memory of his "engineering department". It is 100% owned
Bash, PowerShell, Python, and Markdown. There is no app, database, container,
hosted service, or CI, and nothing here is deployed. Branch policy is `main` only.

What matters for this work:

- **The two globals.** `templates/system/CLAUDE-global.md` and
  `AGENTS-global-codex.md` install as `~/.claude/CLAUDE.md` and
  `~/.codex/AGENTS.md`. They are **always loaded** — every session on every
  machine pays for every byte. Replacing them is the whole of step 8.
- **A "skill"** is a folder under `skills/` with a `SKILL.md` whose YAML
  front-matter has a `name` and a `description`. The description is the ONLY
  thing the model sees when deciding whether to open the skill, which is why a
  trigger score measures the description and nothing else.
- **The two installers.** `bin/ai-install-skills` (Bash) and
  `bin/install-ai-devops-windows.ps1` (native PowerShell). They must behave
  identically; `tests/test-installer-parity.sh` proves it.
- **The two trigger-eval runners** in `tools/skill-trigger-eval/`:
  `skill-trigger-eval.py` (Claude — counts a `Skill` tool call) and
  `codex-trigger-eval.py` (Codex — counts a command that opens the installed
  `SKILL.md`). One eval-set format feeds both.
- `tools/context-audit/context-audit.py` — the dependency-free audit and its
  `--strict` gates.

## 2. What we set out to do this session, and why

Close **Albert's gate on step 8**: the three load-bearing skills that had never
been measured — `synology-long-running-operations`, `shared-db-change` (the
Claude twin), and `handoff-writer` — each needed a committed eval set and a
recorded trigger score before the pilot could start.

Business reason: these three skills carry safety rules. If one silently fails to
fire, Albert gets an agent that overloads the NAS, mutates the shared database
without going through `shared-db`, or writes a three-sentence handoff — and
nothing anywhere would show it. Only a written eval set found the Codex twin at
8/10 in step 6.

## 3. Current state — what is true right now

### Commit `45466a3` — the gate

Three committed 20-query eval sets (10 positive, 10 negative each) in
`tools/skill-trigger-eval/`, and this recorded result at `--runs 3`:

| Skill | Should fire | Should NOT fire |
|---|---:|---:|
| `handoff-writer` | **8/10** | **0/10** |
| `shared-db-change` (Claude twin) | **7/10** | **0/10** |
| `synology-long-running-operations` | **2/10** | **0/10** |

**Precision is perfect on all three.** No near-miss prompt fired once, in any
round, in any configuration. That is the half that protects Albert from a skill
hijacking unrelated work.

**No skill description changed.** Two were written, measured, and reverted:

- `shared-db-change` rewritten to lead with the read-only schema-question case,
  copying the structure of the 10/10 `codex-shared-db-change` twin: **7/10 →
  6/10**.
- `synology-long-running-operations` rewritten to lead with the shape of the work
  and name every missed case: **2/10 → 2/10**.

Also in the commit: both runner fixes (§4), the full write-up appended to
`docs/skill-trigger-eval.md`, and the plan's broken link to the deleted step-6
handoff repaired (broken links 1 → 0).

### This machine's installed state — matters for step 8

- **Both globals are still the OLD text, deliberately.** Unchanged from step 7.
- Skills are installed current with this worktree; `installed source drift`
  measured from here is **2, and both rows are the globals**. From
  `C:\repos\ai-devops` expect 8 (6 line-endings-only skills plus the 2 globals).
- **Two recoverable directories exist and must not be deleted:**
  `~/.codex/skills-backup/codex-shared-db-change` and
  `~/.codex/skills-quarantine/codex-qwen-code`.
- **Both installed globals carry an `al8960ofc` machine section that the repo
  copy does not have** — this is the single biggest risk in step 8; see §6 step 2
  and §9.

### Measurements, from this worktree

| Class | Bytes | Note |
|---|---:|---|
| always-loaded globals | **24,703** | unchanged; budget 24,713 |
| startup-routed | **35,971** | budget 35,972 — 1 byte of headroom |
| Claude skill manifest | **21,521** | unchanged — proves the reverts landed |
| duplicate paragraph groups | **2** | unchanged, deliberate |
| overlaps / parity / broken links / safety markers | **0** | broken links fixed this session |

### Verified green on 2026-08-13

```bash
python tools/context-audit/context-audit.py --root . --strict   # exit 0
bash tests/test-codex-trigger-eval.sh                           # offline, no model call
```

The full suite list is in `docs/development.md` and in the step-7 handoff; the
suites were not re-run this session because no installer or audit code changed.
**Run them before the pilot.**

## 4. Everything we tried that did NOT work

- **The entire first three-set run was scrapped, and it looked authoritative.**
  `skill-trigger-eval.py` matched the skill name inside **any** tool call's
  input, not just a `Skill` call. Run from inside this repo — which names every
  skill in its docs, its globals, and its own eval sets — the model merely
  *reading a file* scored as a trigger. `handoff-writer` appeared to fire on
  "commit and push everything", "secrets sweep", and "summarize what you changed
  in the last three files": **7 false positives out of 10**, none real. This is
  the same contamination trap the Codex runner hit in step 6, in a second place
  nobody checked. **Fixed** by attributing deltas to their block via
  `content_block_start` and counting only a `Skill` block, and by defaulting the
  project to a scratch dir.
- **An empty scratch directory is not a neutral test.** It is inert. Prompts like
  "write a handoff for what we did in this session" have nothing to act on, so
  the model asks a clarifying question instead of selecting a skill and the run
  scores a miss it never earned. `handoff-writer` read 4/10 that way, versus 8/10
  once given something plausible to work with. **Fixed** by seeding a small
  ordinary project (README, two source files, a notes file, an empty
  `HANDOFF.d/`) that names none of our skills, repos, or machines.
- **`--runs 1` is not a measurement, and it wasted two full rounds.** Two
  identical rounds scored `handoff-writer` 4/10 and 5/10 **on different queries**,
  including prompts quoted verbatim in the skill's own description. There were
  zero errored runs; it is genuine variance. Nothing about a description can be
  judged from single runs. Use `--runs 3`.
- **Porting a 10/10 twin's description wording does not port its score.** The
  `codex-shared-db-change` description scores 10/10 on the Codex runner; writing
  the Claude twin in the same shape made it *worse* (7 → 6). This is the second
  recorded instance, after the 1Password rewrite in July that scored identically.
  **Measure every rewrite; never ship one because it reads better.**
- **Naming every missed case in a description did not raise
  `synology-long-running-operations` at all** (2/10 → 2/10). Whatever is
  suppressing it is not vocabulary.

## 5. Root causes and key findings

- **A measurement harness can fail in the direction that flatters it.** Both
  runner bugs *inflated* scores. Had the first run been believed, the gate would
  have been recorded as passed with `handoff-writer` at 7 false positives out of
  10 and nobody would have looked again. When a score is surprisingly good, doubt
  the harness exactly as hard as when it is bad.
- **The test environment is part of what you are measuring.** Contamination and
  inertness are the same class of mistake in opposite directions: one lets the
  environment answer for the model, the other denies it anything to answer with.
  A neutral, plausible project is the only setting that measures the description.
- **Perfect precision, mediocre sensitivity, on all three skills.** None of these
  skills fires when it should not. The failure mode across this whole toolkit is
  silence, not overreach.
- **`synology-long-running-operations` at 2/10 is a genuine open problem** and
  wording is not the lever. Two untested hypotheses, in
  `docs/skill-trigger-eval.md`: (a) the eval project has **no Synology MCP
  configured**, so the model may see no NAS tooling to reach for and answers
  generically — test this by running the set with the MCP available before
  rewriting anything; (b) rule **9a of the always-loaded Claude global already
  covers this exact topic**, and the documented 1Password precedent is that where
  a global already covers a topic, Claude answers directly and no description
  wording overrides it. **If (b) is true, step 8 will change this score by
  itself** — the pilot installs a global whose 9a text differs. Re-score this
  skill after the pilot before concluding anything.
- Everything step 7 found still holds: the installer was the drift; a
  "no evidence of edits" state cannot be assumed; two installers with the same
  job will drift apart; install and audit from the same checkout.

## 6. Exact next steps

These cover the whole remaining plan, steps 8 through 10, in order.

1. **Pre-flight.** Fast-forward `main`, check for concurrent sessions in this
   repo, and run the full named suite list from `docs/development.md` plus
   `tests/test-windows-scripts.sh`. Record `installed source drift` **with the
   homes passed** and note which checkout you measured from:
   ```bash
   python tools/context-audit/context-audit.py --root . --strict \
     --claude-home "$USERPROFILE/.claude" --codex-home "$USERPROFILE/.codex"
   ```
   *You'll know it worked when* every suite passes and drift is 2 from a
   worktree (8 from `C:\repos\ai-devops`, 6 of them line-endings-only).

2. **Step 8 — the pilot on `al8960ofc`. Save the machine sections FIRST.**
   Both installed globals end with an `al8960ofc` section that the repo copy does
   not contain, and `--adopt-globals` replaces the whole file. The installer
   backs the old file up to `<client>/globals-backup/` and prints the restore
   command, and it prints a NOTE telling you to re-append the machine section
   from `templates/system/machine-atlas.md` — **but nothing re-appends it for
   you.** Copy both sections out before you start:
   ```bash
   sed -n '/^## al8960ofc/,$p' "$USERPROFILE/.claude/CLAUDE.md" > /tmp/claude-machine.md
   sed -n '/^# Machine facts — al8960ofc/,$p' "$USERPROFILE/.codex/AGENTS.md" > /tmp/codex-machine.md
   bash bin/ai-install-skills --dry-run      # read EVERY line
   bash bin/ai-install-skills --adopt-globals
   # re-append both sections, then fully restart BOTH clients
   ```
   The Claude section holds the toolkit clone path and the `Z:` trap; the Codex
   section additionally holds the WSL env trap, the Claude Desktop MSIX config
   path, the two remote MCP URLs, and the Hetzner SSH aliases. Losing them costs
   a future session hours.
   Then run the deferred probes: the **step-4** probes (does a session still
   route a shared-db change correctly, refuse a production mutation, verify Git
   identity, and open `templates/system/handoff-standard.md` when writing a
   handoff?), the **step-5** probe (does it open `docs/design-decisions.md`
   instead of guessing?), and the **step-6** probe (does a Codex session open the
   skill it needs?). Capture the **native PowerShell** installer's output too and
   assert the reconciliation path actually ran.
   *You'll know it worked when* every safety probe passes, real tasks complete
   correctly, **both machine sections are still present in the installed files**,
   the installed file actually contains the new text — **do not accept exit code
   0 as proof** — and drift falls to the line-endings-only rows.

3. **Re-score `synology-long-running-operations` after the pilot**, before
   touching its description again, and test the MCP hypothesis in §5. If the
   score moves without any edit, that is the finding, and it belongs in
   `docs/skill-trigger-eval.md` and the plan.

4. **Step 9 — roll out to `916-alien`, `albt16`, then the Ubuntu AI users.**
   Check reachability and concurrent work, fast-forward `main`, dry-run and diff
   per machine, install, restart clients, run `ai-devops doctor`. **Expect the
   first sync on every machine to report `LOCAL EDITS` for skills nobody
   edited** — their markers are legacy and carry no hashes. That is correct and
   loud; do not "fix" it. Every machine has its own global machine section: apply
   step 2's save-and-re-append there too.

5. **Step 10 — measure, set final budgets, close.** Compare before/after startup
   context, tool calls, task success, safety probes, and the trigger scores. Set
   real budgets from what proved safe, editing **all three places**. Decide the
   `.gitattributes` line-ending question (§0 item 3) and the dead `Z:` trap text
   (§0 item 2). Update STATUS, write a memory entry, and delete the handoffs
   whose work is proven done.

6. **A worthwhile addition for step 10:** teach the audit to validate backticked
   prose paths inside the globals and the router — the pointers this whole design
   depends on are still not link-checked. **Consider also deciding what a passing
   trigger score is.** Five data points now exist (`qwen-code` 10/10 twice,
   `codex-shared-db-change` 8/10 then 10/10, and this session's 8/7/2) and nobody
   has set a bar.

7. **Do not delegate any of this to `ai-glm implement`** until the GLM permission
   bug is fixed. GLM review sessions are fine.

## 7. Constraints and gotchas in force

- **Eval runs cost real model calls.** Twenty queries at `--runs 3` and
  `--workers 6` takes about eight minutes per skill. Run them in the background.
  Never at `high` effort for Codex — `low`/`medium` only, by standing rule.
- **The trigger-eval runner tests the INSTALLED skill.** Reinstall between an
  edit and a score, or you measure the old text. A revert needs a reinstall too.
- **Never run the eval from inside this repo** unless the repo's own content is
  deliberately part of the test. The default neutral project exists for this.
- **Install and audit from the SAME checkout**, and pass the homes, or
  `installed source drift: 0` silently means "not measured".
- **A budget number lives in three places:** `tools/context-audit/budgets.json`,
  `DEFAULT_BUDGETS` in `context-audit.py`, and the table in
  `docs/context-engineering.md`. **Never raise a budget to silence a warning.**
- **`bin/install-ai-devops-windows.ps1` must stay PowerShell 5.1-safe.**
- **Anything added to one installer must be added to the other**, and
  `tests/test-installer-parity.sh` must still pass.
- **Never delete a rule from only one client global** — eleven parity rules must
  appear in both, or the rule needs a `PARITY_DIVERGENCE_ALLOWLIST` entry.
- **`.gitignore` has a narrow negation for `*secret*.eval.json`.** An eval set
  whose filename contains "secret"/"token"/"private" is otherwise silently
  refused by `git add`. Eval prompts must never contain real credential values.
- **The pointers are still not link-checked** (backticked prose paths). Renaming
  `templates/system/handoff-standard.md`, `docs/design-decisions.md`,
  `docs/critical-incidents.md`, `bin/ai-git-identity`, `docs/glm-opencode.md`,
  `bin/ai-grok-review`, `bin/ai-grok-implement`, `bin/ai-kimi`,
  `docs/future-visual-testing.md`, or any of the four load-bearing skills means
  updating the globals and `AGENTS.md` in the same commit.
- **New skills go in `skills/shared/` by default.** A name may live in `shared/`
  OR a client tree, never both.
- **Concurrent sessions work this repo.** Re-fetch before pushing; never
  `git add -A` over another session's uncommitted work; never edit or delete
  another session's `HANDOFF.d/` file.
- Commit identity must read `Albert Hazan <u2giants@users.noreply.github.com>`;
  verified this session with `git var GIT_COMMITTER_IDENT`.
- No production, shared-cloud, Supabase, Coolify, NAS, or database mutation is
  part of this plan. No secret read should ever be needed.

## 8. Access and environment

- **No credential, secret, 1Password read, cloud call, or network access beyond
  `git fetch`/`push` was required, and none was made.** No secret appeared in
  this session, so nothing was swept to the vault. If a later step unexpectedly
  needs one, secrets live only in the 1Password vault `vibe_coding` — reference
  by item name, never by value.
- **Model calls WERE made this session** (unlike step 7): roughly 200 `claude -p`
  runs across four eval rounds. Budget for that when re-running.
- Tools confirmed present on `al8960ofc`: `git`, `python` 3.14, `bash` (Git
  Bash), `pwsh` (PowerShell 7), and a logged-in `claude` CLI — the Claude runner
  needs `claude auth status` to be logged in, and it was. `codex` 0.145.0 is at
  `C:\Users\ahazan2\.codex\packages\standalone\current\bin\codex`, authenticated;
  not exercised this session.
- **35 Claude skills and 30 Codex skills are installed on this machine.** If a
  set scores 0 everywhere, check installation before blaming the skill.
- Primary checkout `C:\repos\ai-devops`; this work happened in the worktree
  `C:\repos\ai-devops-worktrees\skill-tests-step-8-pilot-364d84`.
- Steps 9 will need SSH or local access to `916-alien`, `albt16`, and the Ubuntu
  AI users. Verify reachability with a real call before planning around it.
- There is no server to start, no URL to deploy, and no CI.

## 9. Open questions and risks

- **Risk (highest for step 8): the machine sections are wiped by
  `--adopt-globals`.** Nothing re-appends them automatically; the installer only
  prints a NOTE. Save both before installing (§6 step 2) and verify they are back
  afterwards. The pilot's own gate says "no machine facts disappear".
- **Risk: `synology-long-running-operations` stays at 2/10.** It is a safety
  skill that protects a production NAS from being overloaded by a read that looks
  harmless. It is currently silent on 8 of 10 realistic prompts. It is not a
  step-8 blocker (its precision is perfect and the global's rule 9a still
  carries the constraint), but it must not be forgotten at step 10.
- **Risk: the first sync on every other machine reports `LOCAL EDITS` for skills
  nobody edited.** Expected, correct, and alarming-looking during step 9.
- **Risk: a pointer is never followed.** The whole design assumes an agent opens
  `docs/design-decisions.md` or `templates/system/handoff-standard.md` when told
  to. Step 8's probes must test it. If a probe shows an agent "fixing" an
  intentional quirk because the reasoning left the router, restore that block and
  record it.
- **Risk: rollback must not be improvised.** Roll back through the same installer
  and the copies it made (`globals-backup`, `skills-backup`,
  `skills-quarantine`). Never `git reset --hard`, never delete unowned skill
  directories, never overwrite a local overlay.
- **Open question: what should the final budgets be?** 23,318 and 35,340 were
  flat 30% guesses from step 3, never measurements. Step 10 sets the real ones.
- **Open question: what is a passing trigger score?** Still undecided, now with
  five data points instead of three.
- **Decision, 2026-08-13:** an eval runner counts a trigger ONLY from the client's
  own skill-selection mechanism — a `Skill` tool call for Claude, an opened
  `SKILL.md` for Codex — never from the skill's name appearing in anything else.
- **Decision, 2026-08-13:** trigger evals run against a neutral seeded project,
  never the caller's cwd and never an empty directory.
- **Decision, 2026-08-13:** no trigger score is acted on below `--runs 3`.
- **Decision, 2026-08-13:** the gate's answer is recorded as measured. Two skills
  that under-fire ship unchanged rather than take an unproven edit.

---

**Self-audit gate: passed 2026-08-13.** All ten sections present. §0 was built by
walking §1-§9 and promoting every sentence needing Albert's judgement; the dead
`Z:` trap text (which Albert asked about directly this session) and the
line-ending question were found that way and are asks, not findings. A newcomer
has the app description with its jargon defined including what a "skill" and a
"description" actually are (§1), the goal and its business reason (§2), exact
state with the score table, this machine's installed state, and the measurement
table (§3), the dead ends including the scrapped first run, the inert empty
directory, the useless single-run rounds, and the twin-wording failure (§4), the
durable findings with two named, testable hypotheses for the one unsolved score
(§5), executable steps for every remaining phase each with a verification gate
and the exact commands (§6), the standing traps (§7), the environment including
the model-call cost this work carries (§8), and the dated decisions and risks
(§9). No secret value appears anywhere.
