# Handoff: context-engineering step 7 — DONE. The installers can no longer eat local work, and "drift" now means something

- **Machine:** `al8960ofc` (Windows 11, user `ahazan2`, PowerShell 7 primary)
- **Agent:** Claude (Opus 5) in Claude Code
- **Repo:** `u2giants/ai-devops`. Worked in the worktree
  `C:\repos\ai-devops-worktrees\codex-eval-sets-step-7-2a3a55` on branch
  `claude/codex-eval-sets-step-7-2a3a55` (the branch name says "eval-sets"; it
  was created before the step was chosen — **it holds step 7 work, not eval
  sets**). **Both commits are on `origin/main`:** `e3c47ae` (the reconciliation
  engine, both installers, tests, docs) and `9e64289` (the audit's
  line-endings-only drift state).
- **Status:** **step 7 is complete, committed, pushed, and applied on this
  machine.** Steps 8, 9, 10 remain, step 4 still owes two probes to step 8, and
  **the three-eval-set gate Albert set on 2026-08-12 is still unstarted** — it
  blocks step 8. The plan is
  [`plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md).

---

## 0. ⚠️ DECISIONS ONLY ALBERT CAN MAKE

Put this whole list to Albert in ONE message before starting work.

### Blocking — the next session cannot finish without an answer

1. **Nothing blocks the eval-set gate.** It can start immediately and run to
   completion without Albert. The first thing that genuinely needs him is still
   step 8, the pilot, because it is the first step that changes a machine's
   always-loaded globals.

### A wrong guess is recoverable, but the rework is wasteful

2. **A handful of files in this repo carry CRLF inside the committed blob, so
   two checkouts of the same commit disagree byte for byte.** That is why the
   same machine audits as 0 drifts from a worktree and 8 from
   `C:\repos\ai-devops`. Step 7 made this legible (6 of the 8 now report
   `line-endings-only`) but did not normalize it.
   *Recommendation: leave it alone until step 10, then decide whether to add a
   `.gitattributes` that normalizes text files. Normalizing now would rewrite
   the working copy of nearly every file days before a pilot, and every installed
   hash with it. Do NOT "fix" it mid-pilot.*
3. **CLOSED 2026-08-13 — Albert approved deleting the step-4, step-5, and step-6
   handoffs**, and they are gone in the same commit that added the successor
   rule. `HANDOFF.d/` is back to 3 files. Nothing was lost: their commits are on
   `main`, every open obligation they named is carried in the plan's STATUS
   table, the plan's drift blocks, or §6 of this file, and git history keeps the
   text. **The rule changed so this does not rebuild:** the session that finishes
   the NEXT step of a workstream now deletes the previous step's file (three
   conditions, in `templates/system/handoff-standard.md`), and
   `context-audit.py` prints `open handoffs: N` and warns past 5 so it never
   depends on anyone remembering.

### Not part of this work, and nobody is on it

4. **Nothing new.** The `916-alien` rollout is still unfinished and its handoff
   is still deleted at Albert's instruction (2026-08-12); the machine was
   unreachable every time it was tested. Do not re-create that file
   speculatively; the instructions are recoverable from git history.

### Already settled — do NOT re-ask

- **The three unmeasured load-bearing skills are tested BEFORE the step-8 pilot**
  (Albert, 2026-08-12): `synology-long-running-operations`, `shared-db-change`
  (the CLAUDE twin — it needs the Claude runner `skill-trigger-eval.py`, not the
  Codex one), and `handoff-writer`. Decided; just do it.
- **Keep `bin/install-ai-devops-windows.ps1` PowerShell 5.1-safe** (Albert,
  2026-08-12). Step 7 honored this: no PS7-only syntax was added. Do not migrate
  `bin/setup-machine.ps1:187,192` to `pwsh`.
- **Fix a load-bearing skill by editing its DESCRIPTION, never its name**, and
  keep an edit only if should-fire improves while should-not-fire stays 0/10.
- **A Codex trigger counts only when the model RAN a command opening the skill.**
- **The last 2 duplicate paragraphs stay.** Both are safety text.
- Everything settled in the step-5 and step-6 handoffs still stands: the short
  response-style contract; 22.7% accepted for the globals; pilots are `popdam`
  and `shared-db`; no `@AGENTS.md` import; GPT-5.6 stays `low`/`medium`; budgets
  warn and never fail; do not delegate plan steps to `ai-glm implement`.

---

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public backup-and-restore toolkit for his
multi-model AI coding workflow. Albert is a business owner, not a programmer;
this repo is the durable memory of his "engineering department". It is 100% owned
Bash, PowerShell, Python, and Markdown. There is no app, database, container,
hosted service, or CI, and nothing here is deployed. Branch policy is `main` only.

What matters for this work:

- **The two installers.** `bin/ai-install-skills` (Bash, used on Ubuntu and in
  Git Bash on Windows) and `bin/install-ai-devops-windows.ps1` (native
  PowerShell, called by `bin/setup-machine.ps1`). They copy `skills/claude/`,
  `skills/codex/`, and `skills/shared/` into `~/.claude/skills` and
  `~/.codex/skills`, and seed the two globals. **Both must behave identically**,
  because one machine can be installed with one and refreshed with the other.
- **The managed marker.** `.ai-devops-managed`, a file the installer drops inside
  every skill it installs. It is what makes a blind prune safe: skill roots also
  hold skills we do NOT own (Codex ships its own `playwright`), and those have no
  marker and are never touched.
- `templates/system/CLAUDE-global.md` and `AGENTS-global-codex.md` — the two
  **always-loaded** globals, installed as `~/.claude/CLAUDE.md` and
  `~/.codex/AGENTS.md`. Every session on every machine pays for every byte.
- `tools/context-audit/context-audit.py` — the dependency-free audit and its
  `--strict` gates, including `installedDrift` (installed vs source) and
  `installerCapabilities` (are the two installers still equivalent?).
- `docs/context-engineering.md`, `docs/deployment.md`, `docs/design-decisions.md`
  — the baseline/budgets, the installer behavior table, and the "looks wrong but
  is deliberate" narratives.

## 2. What we set out to do this session, and why

Execute **step 7 of the plan: repair installation drift safely.**

Business reason: a machine's installed skills quietly diverge from the repo, and
nobody can see it. Albert experiences that as "the assistant behaves differently
on this computer" with nothing to point at. The step is not just "copy harder" —
the plan requires preview-first reconciliation that **preserves unowned local
files and machine overlays**, keeps recoverable backups, proves idempotence, and
does the same thing in both installers.

The important discovery is that the old installer was the drift's cause, not its
victim. See §5.

## 3. Current state — what is true right now

### Commit `e3c47ae` — the reconciliation engine

- **The `rm -rf`-then-copy step is gone from both installers.** It deleted, with
  no message, any file someone had added inside a managed skill directory.
- **Every skill is classified before anything is written**, and one line is
  printed per skill. The same output appears in `--dry-run` and in a real run, so
  the preview IS the plan:

  | Line | State | What happens |
  |---|---|---|
  | `+ name` | absent | installed |
  | `= name` | identical | nothing written |
  | `~ name` | update | only the changed files copied |
  | `! name … LOCAL EDITS` | an installed file was hand-edited | copied to `<client>/skills-backup/<name>`, then updated |
  | `! name … never installed it` | a directory we do not own is in the way | backed up, then adopted |
  | `- name retired` | repo no longer ships it | moved to `<client>/skills-quarantine/<name>` (unchanged from before) |

- **Files the repo does not ship are never deleted.** Only files the installer
  itself wrote, and the repo has since dropped, are removed.
- **The marker now records `<sha256>  <path>` per installed file**, LF endings,
  ordinal-sorted. That record is the ONLY thing that can distinguish a hand edit
  from an ordinary source update. A legacy (empty) marker still proves ownership,
  but a differing skill under one is reported `local-edits` and backed up.
- **Globals keep their non-clobber default and gained an explicit boundary:**
  `--adopt-globals` (Bash) / `-AdoptGlobals` (PowerShell) copies the installed
  file to `<client>/globals-backup/` and prints the one-line restore command
  before replacing it. **No global was installed anywhere. That is step 8's call.**
- The PowerShell dry run now previews globals too, instead of exiting first.
- **Tests:** `tests/test-ai-install-skills.sh` 5 → 9 cases,
  `tests/test-install-ai-devops-windows.ps1` 5 → 8 cases (full fixture matrix +
  idempotence), and a new `tests/test-installer-parity.sh` that runs BOTH
  installers on one fixture and proves same file set, byte-identical markers, and
  no phantom local edits when one refreshes the other's install. It skips itself
  where `pwsh` is absent, and takes about 2 minutes.
- **Audit:** three new parity patterns — `previewClassification`,
  `recoverableBackup`, `globalAdoptFlag`. Parity differences stay 0.
- Docs: the behavior table in `docs/deployment.md`, the EXTENDED note in
  `docs/design-decisions.md`, the new suite in `docs/development.md`, and one
  trimmed quirk row in `AGENTS.md`.

### Commit `9e64289` — drift now says WHY

`installedDrift` rows carry `state: "line-endings-only"` when the two copies are
identical after CRLF normalization, and the summary reports
`installed source drift: 8 (6 line endings only)`.

### This machine's installed state — matters for step 8

- **Applied here.** Skill drift 1 → 0 measured from this worktree; a second apply
  changed nothing (idempotent on real data, not just fixtures).
- **Both globals are still the OLD text, deliberately.** From
  `C:\repos\ai-devops` the machine reads **8 drifts: 6 line-endings-only skills
  and the 2 globals**. The globals are the only genuine content difference, and
  closing them is step 8.
- **Two recoverable directories now exist and must not be deleted:**
  `~/.codex/skills-backup/codex-shared-db-change` (produced by the new backup
  path — the skill's marker was legacy, so it was assumed edited) and
  `~/.codex/skills-quarantine/codex-qwen-code` (from step 6).

### Measurements, from `C:\repos\ai-devops` after pushing (CRLF-canonical)

| Class | Bytes | Note |
|---|---:|---|
| always-loaded globals | **24,703** | unchanged; budget 24,713 |
| startup-routed (`AGENTS.md` + `CLAUDE.md`) | **35,971** | budget 35,972 — **1 byte of headroom** |
| task-triggered | **401,605** across 47 files | unchanged |
| duplicate paragraph groups | **2** | unchanged |
| overlaps / parity / broken links / safety markers | **0** | unchanged |

**No budget was raised.** The new `AGENTS.md` row initially blew the startup
budget by 451 bytes; it was rewritten five times until it fit.

### Verified green on 2026-08-13

```bash
python tools/context-audit/context-audit.py --root . --strict   # exit 0
bash tests/test-ai-install-skills.sh          # 9 cases, about 2 min
bash tests/test-ai-memory-sync.sh
bash tests/test-codex-trigger-eval.sh
bash tests/test-installer-parity.sh           # new, needs pwsh, about 2 min
bash tests/test-windows-scripts.sh            # 25 passed, 0 failed
```

```powershell
pwsh -NoProfile -File tests/test-context-audit.ps1
pwsh -File tests/test-install-ai-devops-windows.ps1   # 8 cases
pwsh -File tests/test-mcp-env-launch.ps1
pwsh -File tests/test-memory-sync-scheduled-task.ps1
```

## 4. Everything we tried that did NOT work

- **Hashing every file with its own `sha256sum` call. It made one install take 8
  seconds and the Bash test suite hang past every timeout.** Spawning a process
  on Windows costs 50-100 ms, and the first draft spawned four per file per
  classification. It never looked like a performance problem — it looked like a
  hang, and two rounds went into hunting a deadlock that did not exist. **Fixed
  by hashing each directory in ONE pass** (`find -print0 | xargs -0 sha256sum`).
  If you add a check here, add it to the existing pass; do not add a call.
- **Assuming the hang was a bash bug.** It was reproduced with `bash -x`, with
  `</dev/null`, and with the installer traced separately — the installer always
  finished. Only timing the run showed the truth. **Time it before you debug it.**
- **`$_` inside a PowerShell `switch`.** Inside a `switch` block, `$_` is the
  switch's own value, not the pipeline item, so `$($_.Name)` printed empty and
  every skill logged as `=  (Claude) up to date`. Capture `$skillName` and
  `$skillPath` BEFORE the switch. A blanket search-and-replace for that also
  broke an unrelated line in the orphan-pruning loop; check the diff.
- **`Sort-Object` is not `sort`.** PowerShell's default sort is culture-aware and
  case-insensitive, so it wrote `agents/openai.yaml` before `SKILL.md` while the
  Bash `LC_ALL=C sort` did the reverse. The markers differed and the parity test
  caught it. Use `[Array]::Sort($keys, [StringComparer]::Ordinal)`.
- **PowerShell `-match` on a multi-line file returns an ARRAY, not a bool.**
  `Assert-True ((Get-Content x) -match "y")` throws a type error. Join first:
  `(((Get-Content x) -join "\`n") -match "y")`. Also `(Get-Content x) -join "\`n"
  -match "z"` parses as `-join ("\`n" -match "z")` — parenthesize.
- **Writing the `AGENTS.md` quirk row at natural length.** It blew the
  startup-routed budget by 451 bytes. The router is ratcheted to the byte; a new
  row must be paid for, not estimated. It was merged with the row above it and
  cut to 15 words.
- **Trusting `installed source drift: 0`.** The audit skips the check entirely
  unless `--claude-home` and `--codex-home` are passed, and every summary in the
  plan before this session was run without them. A zero there meant "not
  measured", and that is exactly how "four drifts" became "zero drifts" between
  step 6 and step 7 without anything changing.

## 5. Root causes and key findings

- **The installer was the drift.** The step existed because installed skills
  diverge from the repo; the actual mechanism was that the installer's own update
  path (`rm -rf` then copy) destroyed anything a person had added. Every sync
  silently punished a local extension. **Read the mechanism before designing the
  repair** — the obvious reading ("machines get stale, copy harder") would have
  made the real problem worse.
- **A "no evidence of edits" state cannot be assumed.** The marker had no
  content, so nothing on disk could tell a hand edit from a source update. The
  fix is a recorded hash per installed file, and it only starts working from the
  NEXT sync onward — the first sync after this upgrade backs a skill up on a
  legacy marker, which is deliberate conservatism, not a fault.
- **Two installers with the same job WILL drift apart, and only a test that runs
  both catches it.** The ordinal-vs-culture sort difference was invisible in
  either installer's own suite and would have made every cross-installer refresh
  report phantom local edits and write pointless backups. `--strict`'s
  pattern-based parity check does not catch behavior; the parity test does.
- **Line endings are drift, and this repo has them inconsistently.** A few files
  carry CRLF in the blob, so `core.autocrlf` produces different bytes in
  different checkouts, and the installer copies bytes. The audit now names it.
  Until it is normalized, **install and audit from the SAME checkout** or the
  number never closes.
- **The globals have essentially no headroom** — 1 byte on startup-routed, 10 on
  always-loaded. Any step-8 or step-10 edit to `AGENTS.md` or a global is a
  zero-sum trade until step 10 sets real budgets.
- **A trigger score proves selection, never obedience** (carried forward from
  step 6, still true and still worth repeating).

## 6. Exact next steps

These cover the whole remaining plan, steps 8 through 10, in order.

1. **Score the three unmeasured load-bearing skills. This is Albert's hard gate
   on step 8 — the pilot does not start until it is done.**
   `synology-long-running-operations`, `shared-db-change` (the Claude twin, which
   needs the CLAUDE runner `skill-trigger-eval.py`), and `handoff-writer`. Write
   one set each, 10 positive and 10 negative, modelled on the two committed sets
   in `tools/skill-trigger-eval/`. Fix only by editing the DESCRIPTION.
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
2. **Step 8 — pilot on `al8960ofc`, then `popdam` and `shared-db`.** Save
   pre-install hashes and recoverable copies of both installed globals first —
   **and note that the installer now does this for you**: `--adopt-globals` backs
   the file up to `<client>/globals-backup/` and prints the restore command. Run
   `bash bin/ai-install-skills --dry-run` and read every line, then
   `bash bin/ai-install-skills --adopt-globals`, then **fully restart both
   clients** so startup context reloads. Run the deferred step-4 probes (does a
   session still route a shared-db change correctly, refuse a production
   mutation, verify Git identity, and open
   `templates/system/handoff-standard.md` when writing a handoff?), the step-5
   probe (does it open `docs/design-decisions.md` instead of guessing?), and the
   step-6 probe (does a Codex session open the skill it needs?).
   *You'll know it worked when* every safety probe passes, real tasks complete
   correctly, no machine-specific facts vanished, and the installed file actually
   contains the new text — **do not accept installer exit code 0 as proof**, and
   expect `installed source drift` to fall to the line-endings-only rows.
3. **Step 9 — roll out to `916-alien`, `albt16`, then the Ubuntu AI users.**
   Check reachability and concurrent work, fast-forward `main`, dry-run and diff
   per machine, install, restart clients, run `ai-devops doctor`. The dry run is
   now genuinely informative — read it per machine rather than skimming.
4. **Step 10 — measure, set final budgets, close.** Compare before/after startup
   context, tool calls, task success, safety probes, and the trigger scores. Set
   real budgets from what proved safe, editing all three places. Decide the
   `.gitattributes` line-ending question (§0 item 2). Update the plan STATUS,
   write a memory entry if anything durable was learned, and delete the handoffs
   whose work is proven done.
5. **A worthwhile addition for step 10:** teach the audit to validate backticked
   prose paths inside the globals and the router. The pointers this whole design
   depends on are still not link-checked (see §7).
6. **Do not delegate any of this to `ai-glm implement`** until the GLM permission
   bug is fixed. GLM review sessions are fine.

## 7. Constraints and gotchas in force

- **Install and audit from the SAME checkout**, and pass the homes:
  `--claude-home "$USERPROFILE/.claude" --codex-home "$USERPROFILE/.codex"`.
  Without them the drift check silently reports 0.
- **The trigger-eval runner tests the INSTALLED skill.** Reinstall between an
  edit and a score, or you measure the old text.
- **A budget number lives in three places:** `tools/context-audit/budgets.json`,
  `DEFAULT_BUDGETS` in `tools/context-audit/context-audit.py`, and the table in
  `docs/context-engineering.md`. **Never raise a budget to silence a warning.**
- **`bin/install-ai-devops-windows.ps1` must stay PowerShell 5.1-safe** (Albert's
  decision) — `bin/setup-machine.ps1:187,192` invokes it through `powershell`.
  No ternaries, no `??`, no `-Parallel`, no `foreach -Parallel`.
- **Anything added to one installer must be added to the other**, and
  `tests/test-installer-parity.sh` must still pass. The marker format is the
  contract between them: `<sha256>  <path>`, LF, ordinal-sorted.
- **Never delete a rule from only one client global.** Eleven parity rules must
  appear in both, or the rule needs an entry in `PARITY_DIVERGENCE_ALLOWLIST`
  (`tools/context-audit/context-audit.py`) with a stated reason. `--strict` also
  fails on a *stale* allowlist entry.
- **The pointers are still not link-checked.** They are backticked prose paths.
  Renaming any of `templates/system/handoff-standard.md`,
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
  another session's `HANDOFF.d/` file. Both pushes this session needed a rebase.
- Commit identity must read `Albert Hazan <u2giants@users.noreply.github.com>`;
  verified this session with `git var GIT_COMMITTER_IDENT`.
- `.ai/` and `docs/claude-remote-control-hardening-v2.md` are unrelated untracked
  work in the primary checkout. Leave them alone. `.ai/` must never be committed.
- No production, shared-cloud, Supabase, Coolify, NAS, or database mutation is
  part of this plan. No secret read should ever be needed.

## 8. Access and environment

- Everything needed was local. **No credential, secret, 1Password read, cloud
  call, or network access beyond `git fetch`/`push` was required, and none was
  made.** No model call was made this session either. Secrets, if a later step
  unexpectedly needs one, live only in the 1Password vault `vibe_coding` —
  reference by item name, never by value.
- Tools used and confirmed present on `al8960ofc`: `git`, `python` 3.14,
  `bash` (Git Bash), `pwsh` (PowerShell 7). `codex` 0.145.0 is at
  `C:\Users\ahazan2\.codex\packages\standalone\current\bin\codex`, authenticated;
  it was not exercised this session. The Claude runner additionally needs
  `claude auth status` to be logged in; also not exercised.
- **35 Claude skills and 30 Codex skills are installed on this machine**, current
  with source apart from the 6 line-endings-only rows. If a set scores 0
  everywhere, check installation before blaming the skill.
- Primary checkout `C:\repos\ai-devops` (kept fast-forwarded); this work happened
  in the worktree `C:\repos\ai-devops-worktrees\codex-eval-sets-step-7-2a3a55`.
- Steps 8 and 9 will need SSH or local access to `916-alien`, `albt16`, and the
  Ubuntu AI users. Verify reachability with a real call before planning around it.
- There is no server to start, no URL to deploy, and no CI.

## 9. Open questions and risks

- **Risk: the first sync on every other machine will report `LOCAL EDITS` for
  skills nobody edited.** Their markers are legacy and carry no hashes, so the
  installer cannot prove otherwise and backs them up. That is correct behavior,
  it is loud, and it will look alarming during step 9. Expect it, read the
  backup path, and do not "fix" it by trusting the marker less.
- **Risk: line-ending drift makes any hash-based evidence checkout-dependent.**
  Step 8 must state which checkout it measured from, every time.
- **Risk (highest, unchanged): a pointer is never followed.** The whole design
  assumes an agent opens `docs/design-decisions.md` or
  `templates/system/handoff-standard.md` when told to. Step 8's probes must test
  it. If a probe shows an agent "fixing" an intentional quirk because the
  reasoning left the router, restore that block and record it.
- **Risk: an under-firing safety skill is invisible.** Only a written eval set
  found `codex-shared-db-change` at 8/10. Three of the four load-bearing skills
  still have no set. Albert closed this by making the three a gate on step 8.
- **Risk: rollback must not be improvised.** Roll back through the same
  installer and the copies it made (`globals-backup`, `skills-backup`,
  `skills-quarantine`). Never `git reset --hard`, never delete unowned skill
  directories, never overwrite a local overlay.
- **Open question: what should the final budgets be?** 23,318 and 35,340 were
  flat 30% guesses from step 3, never measurements. Step 10 sets the real ones.
- **Open question: what is a passing trigger score?** Three data points exist:
  `qwen-code` 10/10 and 0/10 before and after its merge, and
  `codex-shared-db-change` 8/10 then 10/10, 0/10 throughout. Nobody has decided
  what score is acceptable for a skill measured in isolation.
- **Decision, 2026-08-13 (step 7):** an installer must classify before it writes,
  and the classification must be identical in a dry run and a real run.
- **Decision, 2026-08-13 (step 7):** a file inside a managed skill that the repo
  does not ship is never deleted, and anything overwritten that held hand edits
  is copied somewhere recoverable first.
- **Decision, 2026-08-13 (step 7):** replacing a global needs an explicit flag.
  Non-clobber stays the default because globals carry per-machine sections.
- **Decision, 2026-08-13 (step 7):** line-ending-only differences are reported as
  such, not as content drift, and are not normalized before the pilot.

---

**Self-audit gate: passed 2026-08-13.** All ten sections present. §0 was built by
walking §1-§9 and promoting every sentence needing Albert's judgement; the
line-ending normalization question and the over-limit `HANDOFF.d/` count were
found that way and are asks, not findings. A newcomer has the app description
with its jargon defined (§1), the goal and its business reason (§2), exact state
per commit SHA with the behavior table, the measurement table, and this machine's
installed state (§3), the dead ends including the performance problem that
masqueraded as a hang and the four language traps that cost real time (§4), the
durable findings (§5), executable steps for every remaining phase each with a
verification gate (§6), the standing traps (§7), the environment (§8), and the
dated decisions and risks (§9). No secret value appears anywhere.
