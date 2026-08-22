# Implementation plan: make stale artifacts visible and attributable

Written 2026-08-14T2015Z on machine `al8960ofc` by a Claude Opus 5 session.
Repo: `C:\repos\ai-devops` (`u2giants/ai-devops`), branch `main`, at `99311f8`.

Companion handoff (links back here):
[`HANDOFF.d/2026-08-14T2015Z-al8960ofc-claude-housekeeping-visibility.md`](HANDOFF.d/2026-08-14T2015Z-al8960ofc-claude-housekeeping-visibility.md)

Codex safety-correction handoff:
[`HANDOFF.d/2026-08-16T0303Z-al8960ofc-codex-housekeeping-plan-corrections.md`](HANDOFF.d/2026-08-16T0303Z-al8960ofc-codex-housekeeping-plan-corrections.md)

---

## STATUS

Read this table first. Do not re-derive it, and do not re-plan from chat.

| # | Step | Status | Evidence (an artifact, never a bare number) |
|---|---|---|---|
| 1 | Retract the superseded "more than 5 files" rule in `skills/claude/wrap-up/SKILL.md` | ⬜ open | — |
| 2 | Repair the dangling `HANDOFF.d/` pointer in `AGENTS.md` | ⬜ open | — |
| 3 | Make the handoff contract block MANDATORY in this repo | ⬜ open | — |
| 4 | Build `bin/ai-housekeeping` — report-only inventory | ⬜ open | — |
| 5 | Add `tests/test-ai-housekeeping.sh` | ⬜ open | — |
| 6 | Register the command (installer catalog, router, docs) | ⬜ open | — |
| 7 | Schedule the report and give it a log nobody has to remember | ⬜ open | — |
| 8 | Run it once, act on what it finds, record the result here | ⬜ open | — |

**A fresh session starts at step 1.** Steps 1 and 2 are two-line doc fixes and
are independent of everything else; do them first so the repo stops teaching
sessions a rule the owner overruled.

**When you execute any step, you own updating this table** in the same commit.
Mark it `✅ done` with a real artifact in the evidence cell: a commit SHA, a test
file path, or the exact command to re-run. A count or a percentage with nothing
behind it is not evidence. The `session-docs-update` skill enforces this gate.

---

## Part 1 — Why

### 1. The ultimate goal, in plain business English

**Albert must be able to run one command and get a one-screen summary of likely
housekeeping work in this repo, with a detailed view available when needed,
without asking an AI session to perform the initial inventory.**

Today he cannot. Leftovers pile up (branches, worktrees, handoff files, agent job
records), he notices them by accident, and each discovery costs a session doing
archaeology to work out whether each item is finished or still live. Twice now a
human has had to order a manual sweep.

Three things must be true when this is done that are not true today:

1. One command prints a short plain-English summary, while `--details` prints
   every supported artifact and the recorded owner, or `OWNER UNKNOWN` when no
   trustworthy ownership record exists.
2. Windows machines keep a daily local snapshot, and every wrap-up surfaces the
   current summary, so the report is both available historically and actually
   shown to Albert.
3. A machine can identify handoffs that need successor review. It must never
   claim a handoff is finished solely because its GitHub issue is closed.

**Non-goals of the goal:** this is NOT about deleting things automatically, and
it is NOT about reducing the number of files. The owner has already ruled that
file count is never the problem; only *stale* files are (see §8, locked decision
D2).

> **If a step in this plan conflicts with the goal above, the goal wins. Stop and
> flag it rather than implementing the step as written.** A step that makes the
> report *quieter* or that starts deleting things to make a number go down is
> working against the goal even if it matches the words.

### 2. What this application is

`u2giants/ai-devops` is Albert Hazan's public toolkit for his multi-model AI
coding workflow. It is 100% owned Bash, PowerShell, and Markdown: CLI helpers
under `bin/`, global instruction templates for Claude and Codex, repo doc
templates, skills, machine setup scripts, and cross-machine memory.

- **There is no application, database, container, hosted service, or CI.** Do not
  go looking for them and do not scaffold them. "Green" means the local test
  suites named in `docs/development.md`.
- **Branch policy: `main` only.** Short-lived worktrees are acceptable for a
  piece of work and must be merged back and removed.
- The canonical router is [`AGENTS.md`](AGENTS.md). Read it before anything else.
- Installed commands are symlinked from `bin/` to `/usr/local/bin/ai-*` by
  `install.sh` (see its pruning/symlink loop around `install.sh:91-114`), and
  reconciled across machines through the catalog `config/machine-tools.tsv`.
- Users: Albert (a business owner, explicitly **not** a programmer) plus many
  concurrent AI sessions — Claude, Codex, GLM, Kimi, Qwen, Grok — across several
  Windows machines and Ubuntu hosts.

### 3. What triggered this work

On 2026-08-14 Albert closed out a finished handoff file and asked:

> "why do we constantly have stale files, worktrees, branches, etc. is there no
> housekeeping instructions in the documentation of this repo?"

Measured on `al8960ofc` that day, at `main` = `99311f8`:

| Artifact class | Count | How it was measured |
|---|---|---|
| Registered git worktrees (excl. the main checkout) | 11 | `git worktree list` |
| Local branches | 26 | `git branch \| wc -l` |
| `plan_*.md` files at repo root | 14 | `ls plan_*.md` |
| `refs/codex/turn-diffs/checkpoints/*` refs | 15 | `grep -c refs/codex/turn-diffs .git/packed-refs` |
| Handoff files in `HANDOFF.d/` | 0 | after that morning's deletion |

Two manual sweeps have already been needed: `HANDOFF.d/` went from 8 files to 3
on 2026-08-12, and the sibling repo `u2giants/shared-db` had **30 handoff files,
27 of them finished** (issue #658, cleaned 2026-08-13). The pattern, not any one
file, is the trigger.

Reproduce the symptom on any machine that has run several agent sessions:

```bash
cd /c/repos/ai-devops && git worktree list && git branch
```

### 4. Scope — in and out

**IN scope**

- Two documentation corrections that are actively misleading sessions today
  (steps 1 and 2).
- Making the four-line handoff contract block mandatory in this repo (step 3).
- A new read-only command `bin/ai-housekeeping` that inventories and reports
  (step 4), its test (step 5), its registration (step 6), and its schedule
  (step 7).
- One supervised cleanup pass driven by the report's first real run (step 8).

**NOT in scope — do not do these, even if they look obvious**

- ❌ **Any `--apply`, `--fix`, `--clean`, or auto-delete mode.** Explicitly cut
  after review; see §7 rejected approach R1 and §8 locked decision D1. If you
  believe the report has earned it, that is a NEW plan, not this one.
- ❌ Deleting any branch, worktree, handoff file, plan file, or agent job record
  from inside the tool. The tool prints the command; a human or an informed
  session runs it.
- ❌ Age-based expiry of agent job records under `~/.local/state/ai-devops/`.
  See R3.
- ❌ Touching `u2giants/shared-db`, its reaper script, or its orchestrator
  workflow. The lesson is borrowed; the code is not.
- ❌ Adding CI, GitHub Actions, or a pull-request gate to this repo. It has none
  by design.
- ❌ Adding a cap on how many `HANDOFF.d/` files may exist. Owner ruling, D2.
- ❌ Rewriting `bin/ai-workspace-status`. The new command is separate; see D4.
- ❌ Cleaning up the 14 root `plan_*.md` files. Most are deliberate records; the
  tool classifies and reports them, nothing more (R4).

---

## Part 2 — What we already know

### 5. Current state of the code

Nothing has been built for this plan. Every step is ⬜ open. What exists today:

**Rules that exist and are correct, except for the closed-issue terminology
called out in step 1**

| Where | What it says |
|---|---|
| `AGENTS.md:93-108` | `HANDOFF.d/<UTC>-<machine>-<agent>-<slug>.md` naming; presence = OPEN; legacy root `HANDOFF.md` must be `git mv`'d in |
| `skills/shared/handoff-writer/SKILL.md:60-79` | The contract block (`issue:` / `status:` / `owner:`), and why it is worth four lines. Currently headed **"REQUIRED where the repo enforces it; good practice everywhere"** |
| `skills/shared/handoff-writer/SKILL.md:146-175` | Delete a finished file, never mark it done; the successor rule and its three proof conditions; the owner's no-cap ruling |
| `skills/shared/cleanup-worktree/SKILL.md` | The full safe worktree-removal procedure, including squash-merge-safe proof commands |
| `skills/claude/shared-db-handover/SKILL.md:246-258` | The squash-merge lesson: `git branch --merged` misreported 74 of 130 branches |
| `bin/ai-glm:1389`, `:1642-1665` | `reconcile_implementation_records()` and the scratch-clone WARN, both invoked only from `cmd_doctor` |
| `bin/ai-kimi:545`, `bin/ai-qwen:486` | `doctor_worktrees()` — sweeps only wrapper-owned records with exact ownership proof |
| `bin/ai-kimi:833`, `bin/ai-qwen:730` | Disposable worktree teardown at normal end of job |

**Rules that are wrong or broken today — these are steps 1 and 2**

| Where | The defect |
|---|---|
| `skills/claude/wrap-up/SKILL.md:59-62` | Still instructs: *"If `HANDOFF.d/` holds more than 5 files, warn loudly."* The owner overruled this on 2026-08-13 and `handoff-writer/SKILL.md:161-175` explicitly says any such wording is **superseded**. Sessions wrapping up today follow the dead rule |
| `AGENTS.md:403-404` | Points readers at *"the newest open file under `HANDOFF.d/`"* for the `916` machine rollout. `HANDOFF.d/` is now empty; the pointer resolves to nothing |

**Infrastructure the new tool will reuse**

| Where | What it gives us |
|---|---|
| `bin/ai-memory-sync` | An existing Bash tool that already runs unattended. Note `bin/ai-memory-sync:27` — it writes to `$HOME/.cache/ai-memory-sync.log` via its `log()` helper (line 32), which `tee`s to the log. Copy that pattern |
| `bin/setup-machine.ps1:688` | Registers the `ai-memory-sync` Windows Scheduled Task (every 30 minutes) |
| `bin/setup-machine.ps1:673-677` | The VBS launcher shim. It runs the script with `>/dev/null 2>&1`, so **stdout is thrown away**. A report that only prints to stdout will be invisible when scheduled. This is why step 7 requires its own log file |
| `bin/ai-workspace-status` (105 lines) | The house style to copy: read-only, plain English, `c_head`/`c_warn` colour helpers, loud warnings, never changes anything |
| `config/machine-tools.tsv` | The cross-machine command catalog. Header at line 1: `command<TAB>repo_source<TAB>windows_form<TAB>ubuntu_link<TAB>provider<TAB>windows_owner` |
| `tests/` (21 files) | Dependency-free Bash/PowerShell test convention; `tests/test-ai-memory-sync.sh` is the closest model |

**Untracked paths in `C:\repos\ai-devops` that are NOT this work — leave alone**

- `.ai/` — gitignored review artifacts
- `docs/claude-remote-control-hardening-v2.md` — another session's file

### 6. Key findings and root cause

**Finding 1 — the rules are not missing. Three structural gaps are.**
A full search of `AGENTS.md`, `CLAUDE.md`, all of `docs/`, all of `skills/`, and
the `bin/` wrappers found detailed housekeeping rules for handoffs, worktrees,
and job records. The pile-up is not caused by absent instructions.

**Finding 2 — no hygiene runs on a schedule, though timers exist.**
Every cleaner is manually triggered: `ai-glm doctor`, `ai-kimi doctor`,
`ai-qwen doctor`, the `cleanup-worktree` skill, `wrap-up`. Two Scheduled Tasks do
exist (`ai-memory-sync`, `AiDevOps-OpenCodeGlm`) but neither does housekeeping.
There are no Claude Code hooks configured. **Correction to a claim made earlier
in the originating session: "nothing runs on a timer" is false — the timer
machinery exists and is proven, which is exactly why step 7 is cheap.** Note it
is Windows-only; no equivalent schedule exists on the Ubuntu machines.

**Finding 3 (the root cause) — there is no machine-checkable review signal.**
The successor rule at `handoff-writer/SKILL.md:149-160` deliberately assigns
deletion to a *later* session, because the writing session cannot prove its own
work landed. That later session then cannot prove it either, because the
contract block that would make ownership and issue state a one-command lookup is optional here
(`handoff-writer/SKILL.md:60`, "REQUIRED **where the repo enforces it**"). This
repo enforces nothing. A closed issue is useful evidence, but is not proof that
rollout, verification, documentation, and cleanup are complete. So the later
session either guesses or repeats the archaeology; that is what left 27 files
behind in `shared-db`.

**This is the finding that reorders the whole plan.** Without the contract block
the report can only print a list of files and hand Albert back the archaeology.
With it, "needs successor review" becomes a fact a script can establish and the
responsible session is visible. Final deletion still requires the successor
rule's three human-reviewed proof conditions. That is why step 3 comes before
step 4.

**Finding 4 — merged-ness cannot be proven offline.**
`git branch --merged` is disqualified: it misreported 74 of 130 branches in
`shared-db` because squash merges destroy ancestry. The reliable proof needs
GitHub (`gh pr list --state merged --head <branch>`), which needs network and
auth. A scheduled tool must therefore **refuse and say so** when `gh` is absent
or unauthenticated, never quietly fall back to the ancestry test.

**Finding 5 — a clean, merged worktree can still hold the only copy of work.**
Recorded in this repo's own memory: a stopped session's tested fix was 100%
uncommitted inside its worktree and would have been lost with it. A timer cannot
see intent. This is the single strongest argument against `--apply`.

**Finding 6 — the artifact classes split into two different regimes.**

| Regime | Classes | Consequence |
|---|---|---|
| **Machine-local** | worktrees, local branches, local `refs/codex/*`, agent job records under `~/.local/state/ai-devops/{glm,kimi,qwen}`, scratch clones | Cleanup affects only this clone or machine. A local branch or unusual ref is not shared unless separately pushed |
| **Shared via git** | tracked `HANDOFF.d/` files and `plan_*.md` files | Deleting one is a **git commit** in a repo several sessions write to concurrently. It can collide mid-commit, and on another machine the file returns at the next pull |

A single tool that treats both the same will get one of them badly wrong. The
report must label every line with its regime.

**Finding 7 — worktrees can hide.** `.claude/` is gitignored (it once reached
1.1 GB) and some worktrees live inside it. An inventory that only walks
`C:\repos\ai-devops-worktrees` will miss them. Always use
`git worktree list --porcelain`, which reads `.git/worktrees/*/gitdir`.

**Finding 8 — cheap provable wins already visible.** Two branches sit on the
identical commit `d6b78e4`: `claude/glm-plan-loose-ends-af75d8` and
`claude/handoff-md-review-921220` (verified with `git branch --points-at`). Four
`codex/issue-976-*` branches exist while `main` history contains `(#976)` squash
commits. And `claude/context-engineering-consolidation-11f12d` has a branch but
no registered worktree.

**Finding 9 — most root plan files are deliberate records, not litter.** Of the
14, roughly 9 are complete and kept on purpose; `AGENTS.md` describes the GLM
plans as "CLOSED… records only" and `plan_phase3-config-consolidation.md` as
"retained as the completed implementation and verification record". A sweep keyed
on "all STATUS rows done" would destroy intentional history.

**Independent review.** This diagnosis and the original fix idea were reviewed by
Qwen 3.8 Max (`qwen3.8-max-preview`) in read-only mode via
`AI_QWEN_CALLER=claude ai-qwen new housekeeping-stale-artifacts`, session
`housekeeping-stale-artifacts`, 2026-08-14. It read the repo itself rather than
trusting the brief. Findings 3, 4, 5, 6, 7 and 9 come from that review; findings
1, 2 and 8 were verified by hand afterwards against the files cited above. Its
report is saved at
`.ai/reviews/qwen-housekeeping-stale-artifacts-20260814T192916Z.md`, which is
**gitignored and therefore exists only on `al8960ofc`**. Everything from it that
matters has been copied into this plan; do not go looking for that file on
another machine.

### 7. Approaches considered and REJECTED

**R1 — Ship `--apply` in version 1 (the original proposal). REJECTED.**
The first draft of this work was a single tool with a report-only default and an
`--apply` that "cleans only the provably-safe subset." Rejected on three
independent grounds, any one of which is sufficient:
(a) merged-ness has no offline proof (finding 4);
(b) a clean merged worktree can still hold the only copy of real work
(finding 5);
(c) deleting a shared file is a git commit in a concurrently-written repo, which
violates this repo's own concurrency law that a session touches only its own
files and its own hunks (finding 6).
**If you are reading this plan and about to add `--apply` because report-only
feels toothless: stop. That is the rejected approach.** Report-only that names
the governed cleanup procedure for a human or informed session is the whole
design.

**R2 — Cap the number of `HANDOFF.d/` files, or fail on more than five.
REJECTED by owner ruling.** Albert, 2026-08-13, quoted verbatim at
`skills/shared/handoff-writer/SKILL.md:167-171`:

> "when the 6th file gets there legitimately, if there are five files already
> there and some are stale, the legitimate file will get rejected. The sessions
> that do the work must take care of their own housekeeping. they are better
> informed than anyone as to whether something is finished or not."

Twenty concurrent workstreams legitimately means twenty files. Count files that
need successor review instead; the target is to resolve every review, not to
guess from the raw file count.

**R3 — Age-based expiry (TTL) for agent job records. REJECTED.**
`bin/ai-glm:1386` deliberately retains terminal records, and `:1653-1656`
refuses to sweep anything lacking exact ownership proof (dead PID + matching
stale lock + registered path). Those records are the audit trail Albert needs
when a job fails, and they cost effectively no disk. Report their age and count;
delete only via the wrappers' own `delete` subcommands.

**R4 — Sweep root `plan_*.md` files whose STATUS rows are all done. REJECTED.**
See finding 9. Classify and report (`active` vs `retained record`), never
auto-delete.

**R5 — Extend `bin/ai-workspace-status` instead of writing a new command.
REJECTED.** That tool is a fast per-repo safety snapshot run constantly before
commits; housekeeping needs `gh` network calls and a filesystem walk. Bolting
them on would make the everyday command slow and offline-fragile.

**R6 — Add a CI check or a pull-request gate. REJECTED.** This repo has no CI by
design (§2), and R2's ruling already rejects the gate concept.

**R7 — Ask each session to clean up after itself harder (a documentation-only
fix). REJECTED as insufficient on its own.** The rules already say this and the
pile-up happened anyway, because the session that could clean up is structurally
the one that cannot prove completion (finding 3). Steps 1-3 still tighten the
documentation, but documentation alone is what we already had.

### 8. Design decisions already made

**LOCKED — do not relitigate. Each has an owner ruling or a measured failure
behind it.**

- **D1 — Report-only. No delete path in this tool, in any flag, ever in this
  plan.** Basis: R1. Decided 2026-08-14.
- **D2 — No cap on `HANDOFF.d/` file count. Count successor-review candidates;
  resolve each through the successor rule.**
  Basis: owner ruling 2026-08-13, R2.
- **D3 — Merged-ness is proven with `gh`, or not claimed at all.** When `gh` is
  missing or unauthenticated the tool prints `UNKNOWN (gh unavailable)` and exits
  with a loud warning. It never falls back to `git branch --merged`. Basis:
  finding 4, and the standing "no silent failures" rule. Decided 2026-08-14.
- **D3a — A historical merged PR is not enough.** The current local branch HEAD
  must exactly equal the merged PR's recorded `headRefOid`. Even then the label
  is `MERGED CANDIDATE`, never "safe to delete"; the cleanup-worktree skill must
  still inspect ignored files, processes, and unique local state. Decided
  2026-08-15 after plan critique.
- **D4 — A new command, not an extension of `ai-workspace-status`.** Basis: R5.
- **D5 — The contract block becomes mandatory in this repo before the tool is
  built.** It makes ownership and issue state machine-checkable, but not final
  completion. Basis: finding 3.
  Decided 2026-08-14 on Qwen's recommendation.
- **D6 — Machine-local and git-shared artifacts are reported in separate,
  labelled sections.** Basis: finding 6.

**OPEN — the implementer's judgment, decide and record it in this file**

- **O1 — Detailed output layout.** The default is locked to a one-screen summary;
  `--details` provides one labelled block per artifact class. Criterion: Albert
  must understand every line without asking. Remedies name the governed skill or
  wrapper to use, not a copy-paste deletion command.
- **O2 — Whether step 7 schedules on Ubuntu too.** Windows is required. Ubuntu is
  optional; only add it if a cron/systemd convention already exists in the repo
  for user-level jobs. If none exists, write "Windows only" in the docs and stop.
- **O3 — Whether the report checks other repos on the machine or only the repo
  it is run in.** Recommendation: only the current repo in v1, matching
  `ai-workspace-status`. Do not build a multi-repo scanner.
- **O4 — Whether a "no findings" run prints anything at all when scheduled.**
  Recommendation: one line to the log, nothing to stdout.

---

## Part 3 — How to build it

### 9. The plan

Phases and context cut points:

- **Phase A = steps 1-3.** Documentation and rules only. Small; one session.
- **Phase B = steps 4-6.** The tool, its test, its registration. This is the bulk
  of the work. ← **natural context cut point: start a fresh session here.**
- **Phase C = steps 7-8.** Scheduling and the first supervised cleanup.
  ← **second cut point.**

At each cut, **re-read the remaining steps of this plan before starting**, and
re-run the measurements in §3 — the counts will have moved, and another session
may have changed the files named below. Pair this with the `fresh-session` skill.

---

### Step 1 — Retract the superseded five-file rule

**Change 1:** `skills/claude/wrap-up/SKILL.md`, the retention bullet at lines
59-62. Delete the sentence *"If `HANDOFF.d/` holds more than 5 files, warn loudly
in the closing report — list them oldest-first with dates and ask which are
actually finished."*

Replace it with the rule that actually applies:

> **Do not count files. Count SUCCESSOR REVIEW candidates — those whose `issue:`
> is already closed — and report those by name with their `owner:`. A closed
> issue is a review trigger, not proof that the handoff is finished; apply the
> successor rule before deletion. There is no limit on the total.** (Owner ruling 2026-08-13; see
> `skills/shared/handoff-writer/SKILL.md` retention section.)

**Change 2:** update `skills/shared/handoff-writer/SKILL.md:170-174` and the
matching retention wording in `templates/system/handoff-standard.md`. Preserve
the owner's no-cap ruling, but replace the unsafe definition "STALE = issue
closed" with `SUCCESSOR REVIEW = issue closed`, followed by the explicit warning
that closure does not prove completion and all three successor-rule conditions
still govern deletion.

**Also check** the closing-report template further down that same file; it
already reflects the correct rule, so the two halves of the file currently
contradict each other. Make them agree.

**Intent:** a session wrapping up today must not be told to warn about a file
count the owner explicitly permitted.

**Depends on:** nothing. **Parallel with:** step 2.

**Verification gate — you'll know it worked when:**

```bash
grep -rn "more than 5\|more than five\|Count STALE\|STALE files" skills/ templates/ docs/ AGENTS.md
```

returns **no live instruction** that treats file count or issue closure alone as
proof of staleness. Historical owner quotes and clearly labelled rejected or
superseded wording are allowed.

---

### Step 2 — Repair the dangling `HANDOFF.d/` pointer in `AGENTS.md`

**Change:** `AGENTS.md:403-404`. It currently says the `916` machine rollout is
"recorded in the newest open file under `HANDOFF.d/`". That file was deleted in
an earlier sweep and the folder is empty, so the pointer leads nowhere.

Decide by looking, in this order:

1. `git log --oneline --diff-filter=D -- HANDOFF.d/ | head` and read the deleted
   `2026-08-10T1138Z-albt16-codex-916-rollout.md` out of git history.
2. If the `916` rollout is still genuinely blocked (last measured: host
   `<protected-dev-peer-address>:22` refused a connection on 2026-08-12), rewrite the sentence
   to carry the fact inline — machine `916`, powered off, what is waiting on it —
   rather than pointing at a file.
3. If it is finished, say so and drop the pointer.

**Intent:** the router must never point at something that does not exist. Note
the general lesson for later steps: **deleting a handoff without updating the
router regenerates staleness one level up.** Add that sentence to
`skills/shared/handoff-writer/SKILL.md` in the retention section while you are
here.

**Depends on:** nothing. **Parallel with:** step 1.

**Verification gate:** `AGENTS.md` contains no phrase pointing to a
`HANDOFF.d/` file that does not exist:

```bash
grep -n "HANDOFF.d" AGENTS.md && ls -A HANDOFF.d/ 2>/dev/null
```

Every surviving reference must be either generic (describing the convention) or
resolve to a file that is actually present.

---

### Step 3 — Make the contract block mandatory in this repo

**This is the highest-leverage step in the plan. Do not skip it to get to the
tool.** Without it, step 4 can only print a list of filenames.

**Changes:**

1. `skills/shared/handoff-writer/SKILL.md:60` — the heading currently reads
   *"The contract block (REQUIRED where the repo enforces it; good practice
   everywhere)"*. This repo now enforces it. Keep the conditional wording for
   other repos, but add a sentence naming `u2giants/ai-devops` as a repo that
   enforces it.
2. `AGENTS.md`, the `HANDOFF.d/` section around lines 93-108 — state plainly:
   **every `HANDOFF.d/` file in this repo MUST open with the three-line contract
   block (`issue:`, `status:`, `owner:`).** A file without it cannot be retired
   by anyone but its author, and will be reported as `UNATTRIBUTED` by
   `ai-housekeeping`.
3. Same section — say what to do when there is no GitHub issue. Do not invent a
   parallel tracker: instruct the session to open one on `u2giants/ai-devops`
   with `gh issue create`, or, if the work genuinely has no issue, write
   `issue: none` plus a one-line reason. `issue: none` is legal but will be
   reported as `UNPROVABLE`.
4. Mirror both into `templates/system/handoff-standard.md` so Codex sessions and
   other machines get the same rule.

**Intent:** after this step, any reader or script can identify who owns the
handoff and whether its issue is closed. Neither may infer that the handoff is
finished; deletion still requires the successor rule's three proof conditions.

**Depends on:** nothing, but step 4's successor-review detection depends on it.

**Verification gate:** do not create a throwaway public issue. Confirm the rule
and its `OPEN`/`BLOCKED` status restriction survive a fresh read:
`grep -n "contract block" AGENTS.md skills/shared/handoff-writer/SKILL.md templates/system/handoff-standard.md`
returns a hit in all three. Step 5's fixture tests will prove parsing without
leaving public or repository residue.

---

### Step 4 — Build `bin/ai-housekeeping` (report-only)

**Create:** `bin/ai-housekeeping`, a Bash script. Model it closely on
`bin/ai-workspace-status` (105 lines) for style, and on `bin/ai-memory-sync` for
its `log()`/logfile pattern.

**Header contract, copy this shape:**

```bash
#!/usr/bin/env bash
# ai-housekeeping — read-only inventory of housekeeping candidates in this repo.
#
#   ai-housekeeping            # print the report
#   ai-housekeeping --details  # print every supported artifact
#   ai-housekeeping --log      # also append the report to the housekeeping log
#   ai-housekeeping --quiet    # print nothing when there are no review candidates
#
# READ-ONLY BY DESIGN: it never deletes, commits, checks out, or prunes
# anything. Findings name the governed cleanup procedure; they do not print
# copy-paste deletion commands.
# There is deliberately no --apply. See plan_repo-housekeeping-visibility.md.
set -uo pipefail
```

**Default output:** one summary block designed to fit on one screen. It reports
counts for each classification, loud warnings, and the log location. Detailed
rows below appear only with `--details`. Ownership is never guessed: print the
recorded owner or `OWNER UNKNOWN`.

**Detailed behavior, section by section (`--details`).**

**A. Preflight.** Must be inside a git work tree (copy the guard at
`ai-workspace-status:20-23`). Determine whether `gh` exists and is
authenticated (`gh auth status`). If not, set a flag; every merged-ness answer
below becomes `UNKNOWN (gh unavailable)` and the report ends with a loud warning
telling the reader the branch and worktree sections are incomplete and why. **It
must never guess.** (D3.)

**B. Worktrees — MACHINE-LOCAL.** Enumerate with
`git worktree list --porcelain`, never by walking a directory (finding 7). For
each, report: path, branch, whether the working tree is dirty, and its PR state.
Query enough GitHub data to obtain `state`, `headRefOid`, and `mergedAt`. Do not
attempt generic cross-platform process detection in v1; the governed cleanup
procedure performs the deeper process, ignored-file, and unique-state checks.
Classify:

- `LIVE` — dirty or has an open PR.
- `MERGED CANDIDATE` — clean, a PR is merged, and the current local HEAD exactly
  equals that PR's recorded `headRefOid`.
- `UNKNOWN` — anything else, including all rows when `gh` is unavailable.

Print for each `MERGED CANDIDATE` row the governed next step and say who runs it:

```
  next review: use the cleanup-worktree skill on <path>   (a human or an informed session, never this tool)
```

**C. Branches — MACHINE-LOCAL unless separately pushed.** For every local branch
except `main`: its short SHA, its PR state and recorded `headRefOid` from `gh`,
and two cheap provable extras that need no network —
branches sharing an identical SHA with another branch (`git branch --points-at`),
and branches with no registered worktree. **Never call `git branch --merged`**
(finding 4); if you find yourself typing it, re-read D3.

Classify branches with the same cautious rules as worktrees: `LIVE` for an open
PR, `MERGED CANDIDATE` only when local HEAD exactly equals the merged PR's
recorded `headRefOid`, and `UNKNOWN` otherwise. Identical SHAs and missing
worktrees are facts to display, not deletion verdicts. If several PRs exist for
one branch, an open PR takes precedence; otherwise search all merged PRs for an
exact `headRefOid` match. A merged PR with a different head never qualifies.

**D. Handoff files — GIT-SHARED.** For every file in `HANDOFF.d/`: parse the
contract block. Then classify:

- `SUCCESSOR REVIEW` — `issue:` names a number and `gh issue view <n>` reports
  `CLOSED`. This prompts the successor rule; it is not proof of completion.
- `OPEN` — issue still open.
- `UNPROVABLE` — `issue: none`.
- `UNATTRIBUTED` — no contract block at all (a rule violation after step 3).

Print `owner:` on every line, or `OWNER UNKNOWN` when absent, so missing
attribution is explicit (finding 3, and the
owner's "the sessions that do the work must take care of their own housekeeping").

**E. Plan files — GIT-SHARED, classify only.** For each root `plan_*.md`: read
its STATUS table and report `active` (any row not done) or `all-steps-done`.
**Label the second one `retained record — review by hand, do not delete`** and
say so in the output text itself, so no future reader mistakes it for litter
(finding 9, R4).

**F. Agent job records and scratch clones — MACHINE-LOCAL.** Count and show the
oldest date per provider under `~/.local/state/ai-devops/{glm,kimi,qwen}`. Report
only. The remedy line names `ai-glm doctor`, `ai-kimi doctor`, `ai-qwen doctor`
and the wrappers' own `delete` subcommands. **No TTL** (R3).

**G. Odd refs — CLONE-LOCAL unless proven pushed.** Count
`refs/codex/turn-diffs/checkpoints/*`. Report
the count and that nobody currently owns them. No remedy is known; say that
plainly rather than inventing one.

**H. Footer.** One plain-English summary line, e.g.
`3 handoffs need successor review, 6 merged worktree candidates, 15 unowned refs. Nothing was changed.`
Exit `0` when it ran correctly, whatever it found. Exit non-zero only when the
tool itself could not run (not in a repo). A review candidate is not an error.

**Hard requirements**

- Read-only. No `rm`, `git branch -d`, `git worktree remove`, `git commit`,
  `git checkout`, or `git prune` anywhere in the file. This is testable; step 5
  tests it.
- Fails loudly, never silently. Any check it could not perform is printed as
  `UNKNOWN` with the reason.
- Plain English throughout — Albert reads this output.
- Pure ASCII if you also touch any `.ps1`; that is enforced by
  `tests/test-windows-scripts.sh`.

**Depends on:** step 3 (for section D to mean anything).

**Verification gate:**

```bash
bash bin/ai-housekeeping
```

run from `C:\repos\ai-devops` prints all eight blocks; then
`git status --porcelain` shows **exactly** the same output as before the run
(the two known untracked paths from §5, nothing more). Confirm section B lists at
least the worktrees `git worktree list` shows, and that section C flags the
identical-SHA pair from finding 8 if those branches still exist.

---

### Step 5 — Add `tests/test-ai-housekeeping.sh`

**Create:** `tests/test-ai-housekeeping.sh`, dependency-free Bash, following the
conventions in `tests/test-ai-memory-sync.sh`.

Required cases, by name:

1. `refuses outside a git repository` — run in `mktemp -d`; expect non-zero exit
   and a clear message.
2. `never mutates the repository` — snapshot `git status --porcelain`,
   `git worktree list`, and `git branch` in a throwaway fixture repo; run the
   tool; assert all three are byte-identical afterwards.
3. `contains no destructive execution path` — exercise every supported flag in
   a throwaway fixture whose `git`, `rm`, and wrapper commands are instrumented;
   fail if the tool invokes a mutating command. Quoted documentation text is not
   execution and must not make this test fail.
4. `never calls git branch --merged` — grep the source; this is D3 and finding 4
   encoded as a test so nobody reintroduces it.
5. `reports UNKNOWN when gh is unavailable` — run with a `PATH` that has no `gh`;
   assert the output contains `UNKNOWN` and the loud warning, and that the exit
   code is still `0`.
6. `classifies a closed-issue handoff for SUCCESSOR REVIEW` — fixture handoff
   with a contract block and `gh` stubbed to return `CLOSED`; assert it never
   prints `finished`, `safe`, or `STALE` for that condition.
7. `classifies a handoff with no contract block as UNATTRIBUTED`.
8. `labels an all-done plan file as a retained record` — assert the output
   contains the words `retained record`, i.e. it does not recommend deletion
   (R4 encoded as a test).
9. `exits 0 when it finds review candidates` — a finding is not a failure.
10. `historical merged PR with newer local commits is UNKNOWN` — stub a merged
    PR whose `headRefOid` differs from local HEAD; it must never be a merged
    candidate.
11. `exact merged PR head is only a MERGED CANDIDATE` — equal SHAs produce the
    cautious label and the cleanup-worktree review instruction, never `safe`.
12. `default is one-screen summary and details are opt-in` — default output has
    no per-artifact rows; `--details` has the labelled blocks.

**Existing suites that must stay green** (see `docs/development.md`):
`tests/test-windows-scripts.sh`, and the full suite. The full run takes roughly
12 minutes — run it in the background, not in the foreground.

**Depends on:** step 4.

**Verification gate:** `bash tests/test-ai-housekeeping.sh` prints all twelve cases
passing and `0 failed`; `bash tests/test-windows-scripts.sh` still reports
`0 failed`.

---

### Step 6 — Register the command

Four small registrations. Miss one and the tool exists only on this machine.

1. **`config/machine-tools.tsv`** — add a row. Header at line 1 is
   `command<TAB>repo_source<TAB>windows_form<TAB>ubuntu_link<TAB>provider<TAB>windows_owner`.
   Use provider `none` (it needs no AI provider). Copy the `windows_form` and
   `windows_owner` values from a comparable non-provider row and keep the tabs
   literal.
2. **`install.sh`** — verify the symlink loop (around lines 91-114) picks
   `bin/ai-housekeeping` up automatically. It globs `bin/`, so most likely no
   edit is needed. **Confirm by reading it; do not assume.**
3. **`AGENTS.md`** — two edits: add `ai-housekeeping` to the installed-commands
   list at line 210, and add a Documentation-map row (the table starts at line
   46) reading roughly: *"Find branches, worktrees, handoff files, or agent
   job records | `AGENTS.md`, `bin/ai-housekeeping`,
   `plan_repo-housekeeping-visibility.md` STATUS first, `skills/shared/cleanup-worktree/SKILL.md`
   | Do not build a delete mode; see the plan's rejected approaches"*.
4. **`docs/`** — add a short `docs/housekeeping.md` (there is none today) that
   explains in plain English what each artifact class is, what each cautious
   classification means, and who is allowed to review or clean it. State that
   ownership appears only when recorded and that local branches/refs are not
   shared by default. Link it from the new `AGENTS.md` row.
   Also link it from `skills/shared/cleanup-worktree/SKILL.md` and
   `skills/claude/wrap-up/SKILL.md`, so the trigger paths lead there.

**Depends on:** step 4.

**Verification gate:** on a second machine (or after re-running `install.sh`
locally), `command -v ai-housekeeping` resolves, and `ai-housekeeping` runs from
a different repo directory without error. Plus:
`grep -n "ai-housekeeping" AGENTS.md config/machine-tools.tsv docs/housekeeping.md`
returns hits in all three.

---

### Step 7 — Schedule the report, with a log nobody has to remember

**The trap this step exists to avoid:** the existing `ai-memory-sync` Scheduled
Task runs its script through a VBS shim that discards output —
`bin/setup-machine.ps1:673-677` runs it with `>/dev/null 2>&1`. **A report
attached to that task and printing only to stdout would be invisible.** It must
write its own log.

**Changes:**

1. Give `ai-housekeeping --log` a log file at
   `$HOME/.cache/ai-housekeeping.log`, using the same `log()`/`tee` pattern as
   `bin/ai-memory-sync:32`. Append a dated block per run.
2. Use a daily cadence. `ai-memory-sync` fires every 30 minutes; a housekeeping
   report at that rate is noise. Either (a) add a date-stamp gate inside the
   script so it only writes a full report once per day, or (b) register a
   separate daily Scheduled Task. **Decision: (b), a separate task named
   `AiDevOps-Housekeeping`** — it
   keeps the two tools independent and is easier for Albert to disable. Follow
   the registration pattern at `bin/setup-machine.ps1:688` and its test
   `tests/test-memory-sync-scheduled-task.ps1`.
3. It must be cheap and offline-tolerant: when `gh` cannot reach GitHub, it logs
   `UNKNOWN` and exits `0` (D3). It must never block, never retry in a loop, and
   never wake a sleeping machine.
4. Surface it where Albert will actually see it: add one line to the closing
   report in `skills/claude/wrap-up/SKILL.md` telling the wrapping-up session to
   run `ai-housekeeping` and report the summary in plain English. The scheduled
   log is history and diagnosis, not user notification; the wrap-up report is
   the visibility mechanism.
5. Prevent unbounded log growth using the existing repository convention if one
   exists. If none exists, keep only the latest 30 dated daily blocks using a
   recoverable rewrite through a temporary file, and test that retention rule.

**Open decision O2 applies here** — Windows is required; Ubuntu only if a
user-level cron/systemd convention already exists in this repo. If it does not,
document "Windows only" and stop.

**Depends on:** steps 4 and 6.

**Verification gate:** run the registered task once by hand
(`Start-ScheduledTask -TaskName 'AiDevOps-Housekeeping'` in PowerShell), then confirm
`$HOME/.cache/ai-housekeeping.log` has a new dated block. Add a PowerShell test
alongside `tests/test-memory-sync-scheduled-task.ps1` asserting the task exists
with the expected name, trigger, and command.

---

### Step 8 — Run it once, act on what it finds, record the result

The report is worthless until someone acts on its first run. This step closes the
loop.

1. Run `ai-housekeeping` on `al8960ofc` and save the output into this plan file
   as the step-8 evidence.
2. For every `MERGED CANDIDATE` worktree, use the `cleanup-worktree` skill — **one at a
   time, proving each one holds no unique uncommitted work first** (finding 5).
   Do not batch them.
3. For every `SUCCESSOR REVIEW` handoff, follow the successor rule's three conditions at
   `skills/shared/handoff-writer/SKILL.md:151-158` before deleting anything.
4. Handle the two cheap wins from finding 8 explicitly: the identical-SHA branch
   pair, and the orphan branch with no worktree.
5. **Do not touch anything the report marked `UNKNOWN` or `retained record`.**
   Report those to Albert with a one-line recommendation each and let him decide.
6. Update the STATUS table with what was actually cleaned and what was left.

**Depends on:** all previous steps.

**Verification gate:** a second `ai-housekeeping` run shows the acted-on items
gone and the `UNKNOWN`/`retained record` items unchanged. `git worktree list` and
`git branch` confirm it. Albert has the before/after counts in plain English.

---

### 10. Tests required

| Test | Where | Asserts |
|---|---|---|
| New: `tests/test-ai-housekeeping.sh` | new file | The twelve cases named in step 5 |
| New: scheduled-task test | `tests/` beside `test-memory-sync-scheduled-task.ps1` | The daily task exists with the right name, trigger, command (step 7) |
| Existing: `tests/test-windows-scripts.sh` | unchanged | Must stay at `0 failed`; enforces pure-ASCII `.ps1` |
| Existing: full suite per `docs/development.md` | unchanged | Must stay green. ~12 minutes; run it in the background |

Several cases exist purely to stop a future session undoing a decision: cases
3/4 encode D1 and D3, case 8 encodes R4, and cases 10/11 encode D3a. Do not
weaken them.

### 11. Constraints, standing rules, and gotchas

- **Branch policy: `main` only** in this repo. A short-lived worktree is fine and
  must be merged back and removed — do not leave one behind while building a
  housekeeping tool.
- **Verify commit identity before your first commit in any checkout:**
  `git var GIT_COMMITTER_IDENT` must read
  `Albert Hazan <u2giants@users.noreply.github.com>`. Git silently invents an
  identity when none is set; that has already put wrong-identity commits into
  shared branches. Fix with `bin/ai-git-identity` before committing.
- **Commit trailer in this repo:** `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`
  (Albert settled this on 2026-08-12; older handoffs disagree and are wrong).
- **Several AI sessions work this repo at once.** Never `git add -A`. Stage only
  your own hunks. Never edit or delete another session's `HANDOFF.d/` file.
  Never rewrite the root `HANDOFF.md` — it is a static pointer. Re-check
  `git log` before trusting any STATUS table.
- **No band-aids.** Root-cause fixes only. If something must be temporary, label
  it TEMPORARY in your `HANDOFF.d/` file with the permanent fix described.
- **No silent failures.** Every fallback must alert loudly. This is the direct
  basis for D3.
- **Nothing hard-coded** that should be configurable — paths, log locations, and
  the state directory should read from environment variables with sane defaults,
  as `bin/ai-memory-sync:25-27` does.
- **No production, shared-cloud, Supabase, NAS, or database work.** Nothing in
  this plan needs any of it.
- **No secrets.** Nothing here needs a credential. Never print or read
  `~/.grok/auth.json`, the OpenCode server password, or any 1Password value.
- **Do not hand-edit installed configs** under `~/.claude`, `~/.codex`, or
  `~/.config/opencode`. Change the canonical repo files and reinstall.
- **`.ps1` files in this repo must be pure ASCII** — enforced by
  `tests/test-windows-scripts.sh`.
- **If Codex is used at any point:** GPT-5.6 reasoning effort stays explicitly
  `low` or `medium`. Never `high`, never `none`. Read the run header Codex prints
  and stop a run that says anything else.
- **`ai-glm` and `ai-grok-review` are not on the Bash tool's `PATH` on
  `al8960ofc`.** `bash -lc "ai-glm ..."` returns `command not found`. Run
  `ai-glm` from PowerShell, and invoke Grok by repo path
  (`bash bin/ai-grok-review ...`). This has cost calls in three sessions now.
  `ai-qwen` DOES work from Git Bash.
- **UI verification is N/A** — this repo has no UI.

### 12. Access and environment

- Repo: `C:\repos\ai-devops`, branch `main`,
  `https://github.com/u2giants/ai-devops`. Public.
- Machine: `al8960ofc`, Windows 11 Pro, PowerShell 7 primary, user `ahazan2`.
  Per-machine facts: `templates/system/machine-atlas.md`.
- Shell: Git Bash for the Bash scripts; PowerShell 7 for `.ps1` and Scheduled
  Tasks. Both are available.
- **`gh` is installed and authenticated** on this machine — that is what makes
  D3 workable. Verify with `gh auth status` before assuming it on another
  machine; step 4's preflight must handle its absence anyway.
- Second-opinion wrappers, if you want another model to review your work:
  `AI_QWEN_CALLER=claude ai-qwen new <name> --prompt-file <file>` (works from Git
  Bash), `bash bin/ai-grok-review ...`, `ai-glm` from PowerShell only.
- **Secrets: none needed.** Nothing in this plan touches a credential, so there
  is nothing to sweep to 1Password at the end. If that changes, secrets go to the
  `vibe_coding` vault by location only, never by value.
- **How to run the thing locally:** there is no server and nothing to deploy.
  `bash bin/ai-housekeeping` from inside the repo is the whole runtime.
  `bash tests/test-ai-housekeeping.sh` is the whole test loop.

---

## Part 4 — Landing it

### 13. Definition of done, risks, and open questions

**Definition of done — every box must be ticked**

- [ ] Steps 1-8 all `✅ done` in the STATUS table, each with a real artifact in
      the evidence cell.
- [ ] `bash bin/ai-housekeeping` prints the one-screen summary, and
      `bash bin/ai-housekeeping --details` prints all eight blocks.
- [ ] `bash tests/test-ai-housekeeping.sh` — all twelve cases pass, `0 failed`.
- [ ] `bash tests/test-windows-scripts.sh` — `0 failed`.
- [ ] Full suite per `docs/development.md` green (run in the background).
- [ ] `git status --porcelain` after a report run shows no new changes.
- [ ] Committed and pushed to `origin/main`; the SHA recorded in the STATUS
      table. (There is no CI and nothing to deploy in this repo — that part of
      the standard checklist is N/A here.)
- [ ] Registered in `config/machine-tools.tsv`, `AGENTS.md` (both places), and
      `docs/housekeeping.md`.
- [ ] `command -v ai-housekeeping` resolves after `install.sh` on a second
      machine.
- [ ] The daily Scheduled Task exists and has written at least one dated block to
      `$HOME/.cache/ai-housekeeping.log`.
- [ ] A memory entry exists saying: *"repo housekeeping — read
      `plan_repo-housekeeping-visibility.md` STATUS first; do not re-derive or
      re-plan; there is deliberately no delete mode."*
- [ ] This plan file is either de-staled with the final state, or deleted because
      every step is proven done — and its `HANDOFF.d/` companion is deleted in the
      same commit.
- [ ] Albert has been given the before/after counts in plain English.

**Risks and rollback**

| Risk | Mitigation / rollback |
|---|---|
| A future session adds `--apply` because report-only feels toothless | R1, D1, and tests 3 and 4 all block it. Rollback is trivial: revert the commit, the tool never changed state |
| The scheduled report becomes noise Albert ignores | O4 and step 7's daily cadence; if it still nags, disable the task — the manual command keeps working |
| A historical merged PR exists but the branch gained newer commits | D3a requires exact equality between local HEAD and the PR's recorded `headRefOid`; even equality yields only `MERGED CANDIDATE`, followed by governed review |
| A closed issue still has unfinished rollout or verification | The label is `SUCCESSOR REVIEW`, never `STALE` or finished; deletion still requires all three successor-rule proofs |
| `gh` unauthenticated on a machine makes the report look empty | D3: it prints `UNKNOWN` plus a loud warning, never silence. Test case 5 enforces it |
| Step 3 makes handoff writing feel bureaucratic and sessions skip the block | The tool reports those as `UNATTRIBUTED` by name, so skipping is visible rather than free |
| Another session edits the same files concurrently | Stage only your own hunks; re-check `git log` before every commit |
| Deleting handoffs in step 8 leaves the router dangling again | Step 2's added rule covers exactly this. Re-grep `AGENTS.md` after any deletion |

**Open questions**

1. **O1-O4 in §8** are the implementer's calls; record the decision in this file
   when you make it.
2. **Does the `916` machine rollout still matter?** Step 2 forces an answer.
   Last measured 2026-08-12: `<protected-dev-peer-address>:22` refused a connection.
3. **What are the 15 `refs/codex/turn-diffs/checkpoints/*` refs, and who owns
   them?** Nobody knows. The tool reports them; deciding their fate is future
   work, deliberately not in this plan. Criterion for acting: identify which tool
   writes them and whether it reads them back.
4. **Should other repos on the machine get this?** O3 says no for v1. Revisit
   only after the report has proven useful here for a few weeks.

---

## Mandatory self-audit

**1. Could a brand-new AI session with no project knowledge and no context from
the originating conversation execute this plan to perfection, without asking
anything?** Yes. §2 defines the repo, stack, branch policy, users, and the
absence of CI. §5 gives the exact current state with `file:line` refs for every
file to be touched, plus the two untracked paths to leave alone. Every step names
its target files, its intent, its dependencies, and a verification gate that is a
runnable command. §12 gives the machine, the shells, which wrappers work from
which shell, and the fact that there is no server and no deploy. The one piece of
evidence that does not travel — Qwen's review file under gitignored `.ai/` — is
flagged as machine-local in §6 with its contents already copied into the plan.

**2. Does the plan carry every piece of background, nuance, and reasoning I hold,
including what was ruled out and why?** Yes. §6 carries all nine findings,
including the correction that timers already exist (finding 2), the root cause
that reordered the plan (finding 3), and the two findings that killed the
original design (4 and 5). §7 carries seven rejected approaches, including my own
first proposal as R1 with the three independent reasons it failed, and the owner
ruling behind R2 quoted verbatim with its file:line. §8 separates six locked
decisions from four open ones. Three of the rejections are additionally encoded
as test cases in step 5 so they cannot be quietly undone.

**3. Is the ultimate goal stated clearly enough that the implementer could make a
correct judgment call if a step turns out to be wrong?** Yes. §1 states it in
business English before any technical wording, names the three things that must
become true, names two explicit non-goals (auto-deletion and reducing file
counts), and carries the instruction that the goal wins over any conflicting
step. The most likely wrong turn — adding a delete mode — is pre-answered in
three places: the goal's non-goals, R1, and D1.

**Gap found during the audit and fixed before showing this plan:** the first
draft had no verification gate on step 6 (registration) and no statement of who
is allowed to run each remedy the tool prints. Both were added — step 6 now
verifies on a second machine, and every remedy line in step 4 section B names the
human or informed session as the actor, never the tool.

**Second audit after the 2026-08-15 critique:** the unsafe proof rules were
removed. A historical merged PR no longer proves the current branch landed;
closed issues now trigger successor review rather than a stale verdict; local
branches and unusual refs are correctly labelled machine/clone-local; missing
owners are explicit; process detection is no longer left for the implementer to
invent; default versus detailed output is fixed; destructive-execution tests no
longer conflict with quoted guidance; and the scheduled log's role and retention
are defined.

**Checklist re-graded after those fixes: all items pass.** Self-audit passed on
2026-08-15.
