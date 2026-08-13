# IMPLEMENTATION PLAN: context-engineering consolidation (2026-08-12)

## STATUS

| Step | Status | Last updated | Evidence |
|---|---|---:|---|
| 1. Freeze a measured baseline | ✅ done | 2026-08-12 | Parser corrected for YAML block scalars; regression test fails on the old parser and passes on the new one; corrected manifests Claude 21,521 bytes / about 5,381 tokens, Codex 14,015 bytes / about 3,504 tokens; two fixed-timestamp runs byte-identical; all Bash and PowerShell suites pass |
| 2. Define the context ownership map | ✅ done | 2026-08-12 | Ownership map added to `docs/context-engineering.md` (per-class owner table, eight-row decision table, pointer definition, stale/retention rules, ten real rules classified); router row in `AGENTS.md`; pointers plus corrected Windows installer routing in both skills usage guides; all cited paths verified to exist; no instruction file trimmed |
| 3. Add context-audit tooling and tests | ✅ done | 2026-08-12 | Warning budgets in `tools/context-audit/budgets.json` (warn only, never fail, even under `--strict`); per-category safety-marker reasons, cross-client parity with a divergence allowlist, and global-vs-skill-description overlap added to `tools/context-audit/context-audit.py` plus a `--strict` exit; `tools/skill-trigger-eval/codex-trigger-eval.py` added as the Codex runner (explicit low/medium effort, read-only sandbox, `--print-command` dry run); `tests/test-context-audit.ps1` extended to prove all six safety categories fail individually with a plain reason, parity and stale-allowlist failures, budget warnings that do not fail, and overlap detection; enforcement documented in `docs/context-engineering.md`, `docs/development.md`, and both tool READMEs; real sources pass `--strict` with zero mismatches, zero overlaps, zero budget warnings; all suites in `docs/development.md` plus `tests/test-windows-scripts.sh` pass |
| 4. Slim the always-loaded global files | 🟡 source done, pilot probes owed | 2026-08-12 (revised in step 5) | Both globals trimmed: 33,311 → 25,764 bytes (22.7%); `--strict` exits 0 with zero missing safety markers, zero parity mismatches, zero global-vs-skill-description overlaps; `alwaysLoadedBytes` budget ratcheted to 25,764 (target 23,318 unchanged); every removed passage mapped to its canonical owner in the new "Where the removed global detail now lives" table in `docs/context-engineering.md`; all seven named Bash/PowerShell suites pass. Live Claude/Codex safety-and-routing probes are NOT run: they need the trimmed globals installed, which is step 8. |
| 5. Turn `AGENTS.md` into a tighter router | ✅ done | 2026-08-12 | Startup-routed 50,729 → 35,972 bytes (29.1%), 632 bytes above the 35,340 target; `AGENTS.md` alone 48,451 → 33,694. Quirk and incident narratives moved verbatim to `docs/design-decisions.md` and `docs/critical-incidents.md`; the GLM/Grok/Kimi router rows now point at the STEP 0 headers and `glm-opencode.md` §5 that already hold the same constraints. `--strict` exits 0 with zero missing safety markers, zero parity mismatches, zero overlaps, zero broken links, zero budget warnings; both budgets ratcheted in all three places; all seven named suites pass |
| 6. Remove cross-client skill duplication safely | ✅ done | 2026-08-12 | **Eval sets exist.** `tools/skill-trigger-eval/qwen-code.eval.json` and `codex-shared-db-change.eval.json`, 10 positive + 10 negative each. `qwen-code` scores **10/10 should-fire, 0/10 should-not-fire** against the real `codex` CLI at `low` effort in a read-only sandbox, reproducibly. Two detection bugs in `codex-trigger-eval.py` were found and fixed by that run (escaped path separators understated the score to 0/1; matching command OUTPUT rather than the command overstated it by 4 unearned false positives from this repo's own files). Every hit now records the matching command in an `evidence` field, locked by the new offline `tests/test-codex-trigger-eval.sh`. The stale "Codex has no skills system" sentence in `AGENTS-global-codex.md` is corrected. Always-loaded 24,703 bytes, still under budget; `--strict` exits 0; all seven named suites pass. **Consolidation done: duplicate paragraph groups 12 → 2.** The exact-body Qwen pair (identical `SKILL.md` apart from the name, identical `agents/openai.yaml`) is merged into `skills/shared/qwen-code`; task-triggered text fell 408,341 → 402,831 bytes and the merged skill **still scores 10/10 and 0/10** after installing to both clients, with the old Codex copy quarantined recoverably. The last 2 duplicates are kept deliberately (a credential-incident STOP banner and the handoff self-audit gate) with reasons in `docs/context-engineering.md`. No other pair was merged: their bodies genuinely differ. `docs/codex-skills-usage-guide.md` `--migrate-obsolete` line corrected. **`codex-shared-db-change` fixed and verified: 8/10 → 10/10 should-fire, still 0/10 should-not-fire.** It had been missing its own verbatim trigger phrase. Description-only change (the name is load-bearing), reinstalled and re-scored; overlap stays 0 |
| 7. Repair installation drift without clobbering local facts | ✅ done | 2026-08-13 | **Drift re-measured first: 3, not four** (1 skill + both globals) — the audit reports 0 unless `--claude-home`/`--codex-home` are passed, which is why earlier numbers disagreed. Both installers now reconcile preview-first: every skill is classified (absent, identical, update, local-edits, unmanaged) and printed before anything is written, and the same lines appear in a dry run and a real run. **The `rm -rf`-then-copy step is gone**, so a file added inside a managed skill is no longer silently deleted; only files the installer wrote and the repo has since dropped are removed. Anything replaced that held hand edits is copied to `<client>/skills-backup/<name>` first, and a global is never replaced without the explicit `--adopt-globals` / `-AdoptGlobals` boundary, which backs it up to `<client>/globals-backup/` and prints the restore command. The `.ai-devops-managed` marker now records a SHA-256 per installed file — that record is what distinguishes a hand edit from a source update. New `tests/test-installer-parity.sh` proves both installers write the same files and byte-identical markers, and that refreshing one's install with the other reports "up to date" rather than phantom edits; `tests/test-ai-install-skills.sh` 5 → 9 cases and `tests/test-install-ai-devops-windows.ps1` 5 → 8 cases cover the full fixture matrix plus idempotence. Audit parity gained `previewClassification`, `recoverableBackup`, `globalAdoptFlag`; parity differences stay 0. **Applied on `al8960ofc`: skill drift 1 → 0, second apply changed nothing, globals untouched as required until step 8.** PowerShell child path stayed 5.1-safe. All named suites pass |
| 7a. Albert's gate: score the three unmeasured load-bearing skills | ✅ done | 2026-08-13 | Commit `45466a3`. Three committed 20-query sets, all measured at `--runs 3` on the Claude runner against a neutral scratch project: `handoff-writer` **8/10 fire, 0/10 false positive**, `shared-db-change` (Claude twin) **7/10, 0/10**, `synology-long-running-operations` **2/10, 0/10**. Precision is perfect on all three — no near-miss fired once, in any round. **Two description edits were written, measured and reverted**: `shared-db-change` rewritten to copy its 10/10 Codex twin's structure scored 7/10 → **6/10**, and `synology-long-running-operations` rewritten to lead with the shape of the work stayed at **2/10**. Per the standing rule no skill description changed. **Two runner traps found and fixed, and the first three-set run scrapped because of them**: `skill-trigger-eval.py` counted the skill name appearing in ANY tool call's input (a `Grep`/`Read` of a file naming the skill scored as a fire), and defaulted to the caller's cwd — run inside this repo, which names every skill in its docs and eval sets, `handoff-writer` appeared to fire on "commit and push everything". Only a `Skill` block's own delta counts now, and runs default to a fresh neutral scratch project seeded with a small ordinary codebase, because an empty directory is inert and manufactures misses. **`--runs 1` is not a measurement** — identical rounds disagreed on which queries fired, including prompts quoted verbatim in a skill's own description. `--strict` exits 0, overlaps 0, broken links 0, manifest bytes unchanged at 21,521. Full write-up in `docs/skill-trigger-eval.md` |
| 8. Pilot on one Windows machine and representative repos | ✅ done | 2026-08-13 | **Trimmed globals installed on `al8960ofc` via `--adopt-globals`.** All nine named suites passed first. Both machine sections were saved before the install and re-appended after, and verified **byte-identical** to the saved copies; the installed bodies match the repo templates exactly under `tr -d '\r'` (mixed CRLF/LF is the known step-10 line-ending item). Exit code 0 was **not** accepted as proof — the new shared-db STRUCTURE-not-data text was grepped out of both installed files. `installed source drift` 8 → **2, and the JSON confirms both rows are the globals**, which now differ only by the machine sections and always will. The native PowerShell installer then reported every skill "up to date" against what the Bash installer wrote, and correctly refused both globals without `-AdoptGlobals` — the parity assertion this step owed. **Step-4 and step-5 probes pass** against fresh `claude -p` sessions carrying the new global: shared-db routing, refusal of a prod `terraform apply`, Git-identity check before a first commit, the `HANDOFF.d` process, the NAS 25-second constraint, and correct recovery of a recorded design reason. **Two probes were mis-designed and re-run** (§ step-8 drift 1). **The step-6 Codex probe was first recorded as passing on no evidence and is now actually measured** (§ step-8 drift 7): `codex-shared-db-change` scores **10/10 should-fire, 0/10 should-not-fire** on the real `codex` CLI at `low` effort, after the pilot, unchanged from step 6. **Pre-flight found the globals 2,233 bytes over budget from commit `df59ffa`, Albert's own shared-db ruling** — legitimate content, installed deliberately, but it moves step 10's numbers and adds 6 overlaps. **`synology-long-running-operations` re-scored after the pilot: 2/10 → 1/10, still 0/10 false positives** — hypothesis (b) refuted, see drift 3 |
| 9. Roll out to all configured machines | ⬜ open | 2026-08-12 | Rollout gates in section 9 |
| 10. Measure results and close the workstream | ⬜ open | 2026-08-12 | Acceptance gates in sections 10 and 13 |

**Fresh-session start:** **step 9, the rollout** to `916-alien`, `albt16` and
the Ubuntu AI users. Steps 1-8 are done: the pilot installed the trimmed globals
on `al8960ofc` on 2026-08-13 and every safety and routing probe passed, so
step 4's two deferred probes are discharged too. **Read the step-8 drift block
first** — in particular finding 5 (drift settles at 2, not 0, on any machine
with a machine section) and finding 6 (nothing re-appends that section for you).
Before each phase, re-read that phase and sections 1, 4, 8, 11, and 13 to catch
drift.

**Drift recorded by step 8 (read before starting step 9).**

1. **A behaviour probe must detect the ACT, not the ANSWER — the same trap the
   trigger-eval runners hit, in a third place.** Two of the six first-pass probes
   were scored wrong by the probe, not failed by the globals. The git-identity
   probe told a folder that was not a git repo to commit, so the rule was never
   reached; the pointer probe searched the ANSWER TEXT for `design-decisions`,
   but an agent that opens a file has no reason to name it afterwards. Rewritten
   to watch the `tool_use` blocks for the paths actually opened, and to ask
   questions the pointed-to doc alone can answer, both pass. **Never score a
   probe on what the model says when you can score it on what it did.**
2. **The pointer design holds, but `AGENTS.md` is not opened as a router in
   one-shot sessions.** Asked for a reason recorded ONLY in
   `docs/design-decisions.md` (Fable: "being removed from the subscription
   plan"), a fresh session found and quoted it exactly — by `Grep`, never by
   following the router. Across four routing probes the router file was opened
   zero times; correct answers came from search, from source code, from the
   always-loaded global, and from this machine's memory files. **No probe
   produced a wrong answer**, so step 5's move of narrative out of the router is
   vindicated on outcome. But two of those routes are machine-local (memory) or
   luck (self-evident code), so step 10 should re-test in an interactive session
   before concluding the router is load-bearing at all.
3. **Hypothesis (b) for `synology-long-running-operations` is REFUTED, and the
   result is stronger than "no change": 2/10 → 1/10.** The new rule 9a is not
   merely present, it now says outright "Load the shared
   `synology-long-running-operations` skill before any NAS read that will exceed
   25 seconds" — an explicit instruction to open the skill — and the score went
   DOWN. Precision stayed perfect at 0/10. **An explicit load-this-skill
   instruction in the always-loaded global does not make a skill fire; it
   substitutes for it.** This is the 1Password precedent confirmed a second time:
   where a global covers a topic, the model answers from the global. The SAFETY
   constraint is intact — probe P6 shows a fresh session correctly citing the
   25-second limit and the background method — what is unreachable is the
   skill's procedure (managed SSH, PID/status, durable output, exit evidence).
   Hypothesis (a), the missing Synology MCP, is still untested. Step 10 must
   decide whether this skill's body belongs in the global or the skill.
4. **Pre-flight measured the globals 2,233 bytes OVER budget, from `df59ffa`.**
   Albert's shared-db STRUCTURE-not-data ruling grew both globals by design on
   2026-08-13. Four budget warnings and 6 global-vs-skill-description overlaps
   now stand where step 6 had driven overlaps to 0; all six are the shared-db
   block echoed between the globals and the `shared-db-*` skill descriptions.
   `--strict` still exits 0 — none of this fails. **Do not "fix" it by raising a
   budget.** Step 10 sets real budgets and should decide whether that block
   belongs in the globals at all, given finding 3 above.
5. **The two drift rows will never reach 0 on a machine with a machine section**,
   because `--adopt-globals` installs the repo template and the section is then
   re-appended by hand. Step 9 should expect exactly 2 on every machine after a
   successful install, not 0, and step 10's acceptance gate must say so.
6. **Nothing re-appends the machine section, and the installer only prints a
   NOTE.** It worked here only because it was done deliberately. Step 9 repeats
   this on `916-alien`, `albt16` and the Ubuntu users, each with its own section.
   Worth considering in step 10: have the installer detect and carry the section
   itself, since the manual step is now proven to be the riskiest in the rollout.

7. **The step-6 Codex probe was recorded as passing without ever being run, and
   the error survived a commit.** Every one of the six first-pass probes was a
   `claude -p` session; no Codex session was started, yet the STATUS row claimed
   "step-4, step-5 and step-6 probes all pass". Caught only on a post-restart
   re-check. Now measured for real with the existing Codex runner:
   `codex-shared-db-change` **10/10 should-fire, 0/10 should-not-fire** at `low`
   effort, unchanged from step 6, so the conclusion held — but it was luck, not
   evidence. **A probe for a client is not run until that client's binary runs
   it.** Step 9 must re-run this per machine, not assume it.
8. **A hand edit was found inside an INSTALLED skill that exists nowhere in
   git.** `~/.codex/skills/disney-source-data-scrape/SKILL.md` on `al8960ofc`
   carries a "Studio boundary" section (keep Disney, Lucasfilm, Marvel and 20th
   Century in separate outputs, tables, crawl histories and loaders; never send
   one studio's rows through another's loader) that is absent from the repo,
   from every worktree, from all of git history, and from the Claude copy of the
   same shared skill. It postdates the pilot install, so it is another session's
   in-flight work, and it was left untouched. **Step 7's redesign is what makes
   this survivable** — the installer now classifies it as local-edits and copies
   it to `skills-backup` instead of deleting it. Step 9 will hit the same class
   of edit on other machines: read every `LOCAL EDITS` line in the preview
   rather than skimming past it, because at least one of them is real content
   that exists nowhere else.

**Drift recorded by step 7 (read before starting step 8).**

1. **The globals on `al8960ofc` are still the OLD text, deliberately.** Step 7
   built the `--adopt-globals` boundary but did not cross it. `installed source
   drift` on this machine is now exactly 2, both globals, and that is the correct
   reading until the pilot.
2. **`installed source drift: 0` means "not measured" unless you pass the homes.**
   `context-audit.py` skips the check when `--claude-home`/`--codex-home` are
   absent, and every summary in this plan before step 7 was run without them. Use
   `--claude-home "$USERPROFILE/.claude" --codex-home "$USERPROFILE/.codex"`.
3. **The marker format changed and both installers write it.** It now carries
   `<sha256>  <path>` per installed file, LF endings, ordinal-sorted. A legacy
   empty marker still proves ownership, but a skill under one that differs is
   reported as `local-edits` and backed up — expect that once per machine on the
   first sync after this, and it is not a fault.
4. **Line endings are real drift.** The one skill drift found on this machine was
   `codex-shared-db-change` installed with LF from a step-6 worktree against a
   CRLF source. Whichever checkout you install from decides the bytes on disk, so
   install and audit from the same checkout or the diff never closes.
5. **A backup and a quarantine now sit on this machine** —
   `~/.codex/skills-backup/codex-shared-db-change` and
   `~/.codex/skills-quarantine/codex-qwen-code`. Both are recoverable copies, not
   rubbish; step 8's rollback plan can use the same mechanism.
6. **`tests/test-installer-parity.sh` is new and needs `pwsh`.** It skips itself
   elsewhere. It is the slowest suite in the repo (about 2 minutes) because it
   hashes every installed file twice.

**Decisions Albert made on 2026-08-12 (binding, do not re-ask).**

1. **The response-style contract was shortened by Albert himself.** He replaced
   the long version in both globals with six bullets: no jargon, no preamble, no
   padding, be direct and specific when asking him for something, one question at
   a time, no em dashes. This supersedes the step-4 note that the block must not
   be touched. The former text is in git history at commit `24f709e`.
2. **22.7% was accepted as good enough for the globals.** Step 5 nonetheless took
   them to 25.8% below baseline as a side effect. Step 10 still sets the final
   number.
3. **The second pilot repo is `popdam`, not `poppim-web`.** `shared-db` remains
   the third. Step 8 must still check for concurrent work in both first.
4. **Step 7 keeps `bin/install-ai-devops-windows.ps1` PowerShell 5.1-safe.** Do
   not introduce PowerShell 7-only syntax into that child path and do not migrate
   `bin/setup-machine.ps1:187,192` to `pwsh`. Albert does not use 5.1 himself; the
   decision is that the migration is not worth a new machine requirement.
6. **The three unmeasured load-bearing skills are tested BEFORE the step-8
   pilot** (Albert, 2026-08-12). `synology-long-running-operations`,
   `shared-db-change` (the Claude twin, which needs the CLAUDE runner
   `skill-trigger-eval.py`), and `handoff-writer`. This is a new gate on step 8:
   the pilot does not start until all three have a committed eval set and a
   recorded score. Rationale: the fourth one, `codex-shared-db-change`, was
   measured for the first time on 2026-08-12 and was **broken** — it missed its
   own verbatim trigger phrase. Nothing else in the repo would ever have caught
   it. Fix any failure by editing the DESCRIPTION only, never the name, and keep
   an edit only if should-fire improves while should-not-fire stays at 0/10.

5. **Writing the first Codex trigger eval sets is the opening task of step 6.**
   **Done on 2026-08-12**, and the stale Codex "no skills system" sentence is
   corrected in the same commit on that evidence. The rest of step 6 is unblocked.

**Drift recorded by step 6 (read before starting step 7).**

1. **`codex-trigger-eval.py` changed shape.** `run_query` now returns
   `(opened, evidence)` rather than a bool, and every result row carries an
   `evidence` list. Anything that consumed its JSON output must expect the new
   field.
2. **A trigger only counts when the model RAN a command opening the skill.**
   Output text no longer counts. Any earlier Codex trigger number, including one
   quoted in a later step, is not comparable to a number measured after
   2026-08-12.
3. **Do not run a Codex eval from a checkout that contains the eval fixtures**
   without reading the `evidence` field. Self-contamination is what produced the
   4 unearned false positives.
4. **`AGENTS-global-codex.md` changed twice more** (the skills sentence and the
   session-rituals heading). Always-loaded is 24,703 bytes, 10 under the ratcheted
   24,713 budget, so **step 6's remaining work has almost no headroom**; measure
   from `C:\repos\ai-devops` after committing.
5. **The ritual summaries under that sentence are NOT yet trimmed.** They are
   still the main always-loaded reduction candidate, and each now needs its own
   eval set before removal.
6. **RESOLVED: `codex-shared-db-change` scored 8/10 and now scores 10/10.** It
   had been missing **its own verbatim trigger phrase**, "make db changes the
   proper way", and Rule 0 schema inspection, in this repo and in
   the `popdam3` app repo alike. The fix was description-only: trigger phrases moved
   to the front of a description that had buried them behind a slash-list,
   `"what columns exist"` added, and a stale "Codex has no auto-loaded skills"
   sentence deleted. False positives stayed 0/10 and overlap stayed 0. **The
   lesson generalizes: a skill description is routing, and it is measurable.**
7. **The merged skill's installed name changed** from `codex-qwen-code` to
   `qwen-code` on the Codex side. The eval set is renamed to match
   (`qwen-code.eval.json`). The old installed copy is in
   `~/.codex/skills-quarantine/codex-qwen-code` on `al8960ofc`, recoverable, not
   deleted.
8. **`bin/ai-install-skills` was RUN on `al8960ofc` twice this session**, to make
   the merged and re-worded skills real before scoring them. **Step 7's drift
   baseline on this machine is therefore reset:** installed skills now match
   source, and the step-7 STATUS line's "four installed skill drifts found" is
   **stale**. Re-measure before designing anything around it. Only SKILLS were
   installed — `install_global` seeds a global solely when absent, and both
   globals exist and differ, so **neither global was touched.** That is still
   correct until step 8.
9. **Step 7 now has a real obsolete-managed fixture to test against**, not a
   synthetic one: `~/.codex/skills-quarantine/codex-qwen-code` on `al8960ofc`,
   produced by the normal path. Do not delete it before step 7 uses it.
10. **Step 10 baseline, measured from `C:
eposi-devops` (CRLF-canonical):**
   always-loaded **24,703** bytes, startup-routed **35,972**, task-triggered
   **401,605** across 47 files, duplicate paragraph groups **2**, overlaps **0**.
   The pre-merge task-triggered figure was only ever measured inside a worktree
   (408,341), so **do not present the difference as an exact canonical delta.**
11. **Trigger scores now exist and belong in step 10's before/after.**
   `qwen-code` 10/10 and 0/10 (unchanged by its merge); `codex-shared-db-change`
   8/10 → 10/10, 0/10 throughout. Three of the four load-bearing skills the
   globals name still have **no** eval set: `synology-long-running-operations`,
   `shared-db-change` (the Claude twin), and `handoff-writer`. Step 8's pilot has
   nothing to compare those three against.

**Drift recorded by step 5 (read before starting step 6).**

1. **Two new documents exist and are now load-bearing.**
   `docs/design-decisions.md` owns the ten "intentional quirks" narratives and
   `docs/critical-incidents.md` owns the two incident narratives. `AGENTS.md`
   keeps a one-line rule plus a pointer for each. Renaming or merging either file
   means updating `AGENTS.md`, `docs/context-engineering.md`, and the
   documentation map in the same commit.
2. **An eleventh parity rule now exists: "destructive actions recoverable".**
   Step 5 discovered the audit's destructive-action safety marker had only ever
   been satisfied incidentally, by prose inside the `AGENTS.md` quirks section,
   and it failed the moment that prose moved out. No global had ever carried the
   rule. Both globals now carry it and `PARITY_RULES` enforces it. Any later step
   that touches it must touch both globals. Step 3's "ten rules" evidence line is
   superseded by eleven.
3. **Both budgets moved and are ratcheted in all three places.**
   `alwaysLoadedBytes` 25,764 to 24,713 and `startupRoutedBytes` 50,486 to 35,972.
   The startup-routed `target` stays 35,340; the router is 632 bytes above it, and
   that gap is left for step 6 or step 10. Step 6 and step 10 must not measure
   against any older number.
4. **Open question 3 is answered: do not enable `@AGENTS.md`.** The repo
   `CLAUDE.md` keeps its explicit read instruction. An import would pull the full
   router into every Claude session in this repo unconditionally, including
   trivial ones, which is the opposite of what step 5 just achieved. Never enable
   both mechanisms. Step 8 may revisit this with real loaded-context evidence, but
   the default is now explicitly "explicit read, no import".
5. **The plan's own "Newest handoff" link was broken** and is fixed. It named a
   step-1 handoff that was deleted when that work closed. The audit's broken-link
   count is back to zero; keep it there.
6. **Nothing changed in the installers, skills, globals-on-disk, or machine
   files.** Steps 6 and 7 still start from the step-3 source layout, and no
   machine has the new text.

**Drift recorded by step 4 (read before starting step 5).**

1. **Two step-4 gates are deferred to step 8, not skipped.** The live "a
   representative Claude and Codex session answers safety and routing probes"
   gate needs the trimmed globals installed on a machine, and the plan forbids
   installing before the pilot. Step 8 must run those probes against the trimmed
   globals and roll back on any failure. Do not treat step 4 as fully closed
   until it does.
2. **The stale `AGENTS-global-codex.md` "Codex has no skills system" claim is
   still there** (now around line 43). Step 4 deliberately did not touch it,
   because the plan gates that correction on Codex skill-loading and trigger
   evidence, and no Codex eval set exists yet. Step 6 owns writing the eval sets
   and then correcting the sentence and the ritual summaries under it.
3. **The always-loaded target was not reached, on purpose.** 25,764 versus the
   23,318 target. The only remaining candidates are the shared response-style
   contract (identical in both globals and governing every turn) and the Codex
   ritual summaries (gated by item 2). Do not close the gap by shaving safety
   prose. Step 10 may set the final budget to whatever proves safe.
4. **Pointers are prose paths, not Markdown links, so the audit's broken-link
   check does not cover them.** All nine were verified to exist by hand on
   2026-08-12. If a later step renames `templates/system/handoff-standard.md`,
   `docs/cloud-build-prod-trigger-incident-2026-07-20.md`,
   `docs/future-visual-testing.md`, `bin/ai-git-identity`, or the
   `synology-long-running-operations`, `shared-db-change`,
   `codex-shared-db-change`, or `handoff-writer` skills, it must fix both
   globals in the same commit. A step-5 or step-10 improvement worth making:
   teach the audit to check backticked paths in the globals.
5. **Step 5's startup-routed baseline moved again.** `AGENTS.md` plus `CLAUDE.md`
   now measure 50,729 bytes, over the 50,486 warning budget by 243. Step 5 must
   measure against 50,729 and ratchet that budget when it lands.
6. **Nothing changed in the installers, skills, or machine files.** Steps 6 and 7
   start from the same source layout the step-3 evidence describes.
7. **A budget lives in three places, not one.** Ratcheting means editing
   `tools/context-audit/budgets.json`, the `DEFAULT_BUDGETS` fallback in
   `tools/context-audit/context-audit.py`, and the budget table in
   `docs/context-engineering.md`. Step 4 updated all three for
   `alwaysLoadedBytes`. Steps 5, 6, and 10 must do the same for theirs or the
   numbers silently disagree.
8. **Installed globals on every machine are now far behind source.** Both
   installers seed a global only when absent, so no machine has the trimmed text.
   The gap is no longer "source plus a machine overlay"; it is a substantial
   rewrite plus an overlay. Step 7's reconciliation preview must be judged
   against that larger diff, and step 8 must prove the new text actually landed
   rather than assuming installer success means the file changed.
9. **Step 6 must treat four skills as load-bearing.** The globals now point at
   `synology-long-running-operations`, `shared-db-change`,
   `codex-shared-db-change`, and `handoff-writer` by name. Consolidating,
   renaming, or merging any of them requires updating both globals in the same
   commit, and must not create a global-versus-skill-description overlap, which
   is currently zero.

**Drift recorded by step 3 (read before starting step 4).**

1. **Budgets are a file, not a number in prose.** Every reduction in steps 4-6
   must ratchet the matching entry in `tools/context-audit/budgets.json` down and
   update the budget table in `docs/context-engineering.md`. Never raise a budget
   to silence a warning. Budgets warn only; they never fail a run.
2. **Two baseline measurements moved.** `AGENTS.md` is now 48,208 bytes (about
   12,052 estimated tokens), not the 47,123 bytes / 11,731 tokens in section 5,
   and startup-routed context totals 50,486 bytes, not 49,401. Step 5 must
   measure before/after against the current number, not the section-5 number.
3. **Steps 4-6 have a new hard gate.** `python tools/context-audit/context-audit.py
   --root . --strict` must exit 0 after every trim. It fails on a missing safety
   marker, a cross-client parity mismatch, or a stale divergence-allowlist entry.
   In particular, step 4 cannot delete a rule from only one client global: the ten
   parity rules must stay in both, or the rule must be added to the divergence
   allowlist in `context-audit.py` with a stated reason.
4. **Step 4's Codex trigger evidence now has a tool.** The gate "only runtime
   trigger tests may decide what summary can be removed" is served by
   `tools/skill-trigger-eval/codex-trigger-eval.py`. It counts a trigger when
   Codex opens the installed `SKILL.md`, which proves selection, not obedience —
   do not over-claim from its score. It needs eval sets, which do not exist yet
   for any Codex skill; writing them is step 4 or 6 work.
5. **Step 6 gained a second duplication signal.** Besides the 12 duplicate
   paragraph groups across skill bodies, the audit now reports overlap between an
   always-loaded global and a per-client skill description. It is currently zero,
   so step 4 must not create one by pasting a skill's description into a global.
6. **Steps 8-9 should run the enforcement checks.** Add `--strict` and
   `pwsh -NoProfile -File tests/test-context-audit.ps1` to the pilot and per-machine
   probes. Step 10 sets final budgets by editing `budgets.json`, not by inventing
   numbers in prose.
7. **No installer file changed.** Step 3 named `tests/test-ai-install-skills.sh`,
   `tests/test-install-ai-devops-windows.ps1`, and `tests/test-windows-scripts.sh`
   as targets, but no enforcement change needed them; all three were run and pass
   unchanged. Steps 6-7 still own installer behavior, and their targets are
   unaffected by step 3.

**End-of-phase reciprocal instruction (applies to every step below).** When you
finish a phase, re-read **all remaining phases through step 10** and report any
drift your work created: a renamed or moved file, a changed interface or report
field, a decision that invalidates a later approach, or a measurement a later
step assumed. Record the drift in this plan (STATUS evidence plus the affected
step's text) before you cut to a fresh session. Finishing a phase without that
sweep is an incomplete phase.

**Newest handoff:**
[`HANDOFF.d/2026-08-13T0130Z-al8960ofc-claude-context-step7-installer-reconcile.md`](HANDOFF.d/2026-08-13T0130Z-al8960ofc-claude-context-step7-installer-reconcile.md)
(earlier step handoffs were deleted on completion; when you delete your own
handoff, fix every link that names it)

## 1. The ultimate goal: what we are actually trying to achieve

Albert's Claude Code and Codex sessions should start with the smallest reliable
set of instructions, find detailed facts only when needed, retain important
decisions between sessions, and behave the same way on every configured Windows
and Ubuntu machine. The change must reduce repeated context without weakening
safety, losing hard-won incident knowledge, hiding failures, or making a new
session ask Albert questions that the documentation already answers.

This is not a race to the smallest file. The target is the smallest **high-signal**
context that preserves correct behavior. Safety and correctness are acceptance
requirements. Token reduction is a measured benefit, not the sole goal.

If any step below conflicts with this goal, the goal wins: stop and flag it.

## 2. What this application is

`u2giants/ai-devops` is Albert Hazan's public backup-and-restore toolkit for his
multi-model AI coding workflow. It contains Bash and PowerShell command-line
tools, global Claude/Codex instructions, repo documentation templates, skills,
machine setup, and cross-machine memory. It is not a hosted application and has
no database, container, or production service.

- Canonical repository: `https://github.com/u2giants/ai-devops`
- Local Windows checkout audited: `C:\repos\ai-devops`
- Branch policy: `main` only
- Audited commit: `c23303cb90dd7dd7ac8c71d103480deaff759776`
- Windows source-of-truth installer: `bin/setup-machine.ps1`
- Ubuntu/Git-Bash instruction/skill installer: `bin/ai-install-skills`
- Native Windows instruction/skill installer:
  `bin/install-ai-devops-windows.ps1`
- Claude global source: `templates/system/CLAUDE-global.md`
- Codex global source: `templates/system/AGENTS-global-codex.md`
- Repo router: `AGENTS.md`
- Claude repo adapter: `CLAUDE.md`
- Skills: `skills/shared/`, `skills/claude/`, and `skills/codex/`
- Windows machines in scope: `916-alien`, `albt16`, and `al8960ofc`
- Ubuntu machines in scope: only those already managed by ai-devops, including
  the `hetz` AI user setup. No production workload mutation is part of this plan.

Albert is a business owner, not a programmer. The toolkit is his engineering
department's durable memory. A shorter prompt that makes sessions less safe or
forces Albert to re-explain facts is a failure.

## 3. What triggered this work

Albert supplied this X post and asked whether its claims about context and graph
engineering would improve the Windows Claude Code and Codex configuration:

- Main post: `https://x.com/i/status/2087218720594706679`
- Referenced post/article card:
  `https://x.com/Sprytixl/status/2087066798608752671`
- Referenced X article:
  `https://x.com/i/article/2087066798608752671`

The main post recommends storing decisions, contracts, dead ends, current state,
sources, and open questions outside the conversation, then loading pointers
instead of replaying raw history. It claims six files cut tokens by 84%, raise
accuracy by 39%, and turn a $20 workflow into a $3 workflow. It describes the
material as an Anthropic leak and claims Google and Microsoft engineers use it.

### Evidence-based opinion about the post, limited to this setup

The central context-engineering principle is correct and directly relevant:
keep always-loaded instructions lean, retrieve detail just in time, compact long
work, and write durable state outside the chat. Anthropic's official article
describes that hybrid model, including `CLAUDE.md`, just-in-time file search,
compaction, structured notes, and focused subagents:
`https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents`.

OpenAI independently recommends leaner prompts, one statement per rule, and only
the tools relevant to the task. OpenAI reports directional internal coding-agent
results of roughly 10-15% higher scores, 41-66% fewer tokens, and 33-67% lower
cost, while warning that each workload must be evaluated:
`https://developers.openai.com/api/docs/guides/latest-model`.

The X post overstates what the evidence proves. The 84% and 39% figures are from
a particular Anthropic Developer Platform evaluation of context editing plus a
memory tool, including a 100-turn web-search workload. They are not evidence that
six Markdown files produce those gains in Claude Code or Codex. No primary
evidence found in this audit supports “leaked,” the Google/Microsoft attribution,
the one-million-to-40,000 calculation, or the $3-versus-$20 promise. Prompt cache
discounts are real, but provider-managed Claude Code and Codex subscriptions do
not expose a simple configuration that makes this arithmetic transferable.

“Graph engineering” is useful here only as a description of explicit workflow
steps and feedback edges: understand -> plan -> implement -> test -> review ->
ship, with failures routed back to a bounded correction step. The repo already
implements much of that in its staged prompts, delegation wrappers, verification
gates, plans, and handoffs. This plan does **not** propose a graph database,
GraphRAG, a code-indexing service, or six ritual files in every repository.

## 4. Scope: in and out

### In scope

1. Measure which global, repo, and skill text is always loaded, conditionally
   loaded, duplicated, stale, or installed differently from its source.
2. Define one owner for each rule or fact: global instruction, machine atlas,
   repo router, topic document, skill, memory, plan, or handoff.
3. Slim global and repo-start context while preserving hard safety gates.
4. Replace avoidable client-specific skill copies with shared sources when both
   clients require identical behavior.
5. Add automated checks for size budgets, duplicate rules, broken links, source
   collisions, stale installed copies, and required safety markers.
6. Pilot and measure the behavior on Windows before broad rollout.
7. Roll out only through existing ai-devops installers and verify every machine.

### Not in this plan

- No production, shared-cloud, Supabase, Coolify, NAS, or database mutation.
- No change to application code in other repositories.
- No wholesale rewrite of every application `AGENTS.md` in the first change.
- No third-party knowledge graph, vector database, GraphRAG service, or daemon.
- No new six-file convention copied from the X post.
- No secret, transcript, `.env`, credential, or private licensed-data loading.
- No removal of a safety rule merely because it is long.
- No assumption that approximate characters divided by four equals billed
  tokens. Exact model token measurements must use supported usage reports.
- No unbounded multi-agent workflow. Delegation remains task-specific and
  bounded.
- No model or reasoning-effort change. GPT-5.6 stays explicitly `low` or
  `medium` per Albert's standing rule.

## 5. Current state of the code and configuration

### What already works

- `AGENTS.md` is the canonical operating guide and documentation router.
- `CLAUDE.md:3-12` tells Claude to read `AGENTS.md` first and avoid bulk-reading
  Markdown.
- `templates/system/CLAUDE-global.md:257-280` and the Codex global template's
  session rules already require router-first, task-specific loading and open
  handoff reading.
- `skills/codex/codex-context-optimizer/SKILL.md` already defines the desired
  minimal loading order and the durable-rule ownership pattern.
- `HANDOFF.d/` already separates active workstreams instead of replaying chat.
- `memory/` and `bin/ai-memory-sync` already persist selected durable knowledge
  across machines.
- `skills/shared/` already provides one source for cross-client behavior.
- `bin/ai-install-skills:122-150` installs managed skills and
  `bin/ai-install-skills:208-224` seeds global files on its Bash path.
- `bin/install-ai-devops-windows.ps1` independently implements the native
  Windows skill copy, managed markers, orphan quarantine, and seed-if-absent
  globals. `bin/setup-machine.ps1:185-192` delegates to this PowerShell path,
  not to the Bash installer. Both implementations must remain aligned.

### Measured audit baseline on 2026-08-12

The measurements below are read-only approximations using file length divided
by four. They help compare files; they are not billing claims.

- Global Claude source: 17,053 bytes, 289 lines, about 4,239 tokens.
- Installed Claude global on `al8960ofc`: 18,038 bytes, 306 lines, about 4,484
  tokens. It is not byte-identical to the source because local machine context
  is appended.
- Global Codex source: 16,258 bytes, 282 lines, about 4,036 tokens.
- Installed Codex global on `al8960ofc`: 18,949 bytes, 325 lines, about 4,705
  tokens. It is not byte-identical to the source because machine facts are
  appended.
- This repo's `AGENTS.md`: 47,123 bytes, 707 lines, about 11,731 tokens.
- This repo's `CLAUDE.md`: 2,278 bytes, 47 lines, about 566 tokens.
- Managed set audited: 52 files and about 121,425 approximate tokens across two
  globals, repo instructions, and 48 skills. This total is **not** loaded on
  every turn. Skills are conditionally selected, so treating the full skill
  library as prompt overhead would be a serious analysis error.
- Skill source counts: 17 shared, 18 Claude-only, and 13 Codex-only.
- Skill bodies are task-triggered, but the per-client catalog of skill names and
  descriptions is startup context used for skill selection. The baseline must
  measure that manifest separately for Claude and Codex. The initial audit did
  not yet calculate this number.
- Four installed skill sources differ from the current repository on this
  machine: Claude `kimi-code-delegation`, Claude `shared-db-handover`, Claude
  `shared-db-orchestrator`, and Codex `kimi-code-delegation`.
- Twelve exact duplicate paragraph groups of at least 180 characters exist
  across skills, spanning 6 files and 3 distinct file pairs. Most are deliberate
  client pairs, especially Qwen; one large group is shared between Claude and
  Codex documentation-update skills. An earlier manual estimate said fourteen;
  it is superseded, because the tool returns 12 at 100, 120, and 180 normalized
  characters alike.
- `templates/system/AGENTS-global-codex.md:44-47` still says Codex has no skills
  system. That statement is stale: the repo has `skills/codex/`, installs them
  into `~/.codex/skills/`, documents Codex skills, and the current Codex runtime
  receives their name/description catalog. The stale sentence is itself a
  context-ownership defect.
- Model-version text is inconsistent: the global safety rule names GPT-5.6,
  while `config/models.env.example`, older staged prompt filenames, the current
  repo `CLAUDE.md`, a cost-efficiency template, and the context-optimizer skill
  still mention GPT-5.4 or GPT-5.5. Some may be intentional historical or role
  names. The ownership audit must classify each before changing it; do not
  mechanically replace model strings.
- The two global templates duplicate material intentionally, including response
  style, production-cloud safety, 1Password serialization, and Synology long-read
  safety. Because the two clients load different global files, cross-file
  duplication does not itself double one client's prompt. It does create drift
  risk and maintenance cost.
- Representative application `AGENTS.md` sizes vary widely: about 4,150 tokens
  for `devops-mcp`, 11,566 for `poppim-web`, 13,181 for `popcrm-web`, 26,293 for
  `popdam3`, 34,670 for `oracle`, and 40,316 for `shared-db`.
- Representative `CLAUDE.md` files tell Claude to read `AGENTS.md` but use prose
  links rather than the `@AGENTS.md` import mechanism. They range from about 318
  to 1,445 tokens. Several repeat shared-database, deployment, branch, and commit
  rules already present globally or in `AGENTS.md`.

### Git and deployment state

- Branch: `main`
- Local/remote base at audit start: commit
  `c23303cb90dd7dd7ac8c71d103480deaff759776`
- Existing unrelated untracked work was present and must remain untouched:
  `.ai/` and `docs/claude-remote-control-hardening-v2.md`.
- No context implementation is committed, pushed, installed, or deployed.
- The only planned-session artifacts are this file and its linked handoff.

## 6. Key findings and root cause

### Finding 1: the architecture is already context-engineered

The repo already separates global rules, repo routing, skills, machine facts,
memory, plans, and handoffs. The correct project is consolidation, measurement,
and enforcement, not adopting the X post's six-file pattern.

### Finding 2: the largest immediate cost is always-loaded prose

On this repo, Claude can begin with about 4,484 tokens of user-level instruction,
566 tokens of repo-specific Claude notes, and then be told to read an 11,731-token
`AGENTS.md`. Codex receives a comparable global plus the same large repo router.
The application repos can be larger. The router contains valuable reference
material, but much of it is topic detail that could live behind links.

### Finding 3: “move everything into files” is not enough

Files save context only when the agent receives a pointer and reads the file on
demand. If every session is instructed to read every file, the tokens simply
move. This directly answers the skeptical reply under the X post. The design
must distinguish always-loaded, required-at-start, and task-triggered material.

### Finding 4: global duplication is partly required, skill duplication is not

Claude and Codex require separate global entry files, so identical non-negotiable
safety text may need generated or synchronized client outputs. In contrast,
identical skill behavior should normally live once under `skills/shared/`, as
`CLAUDE.md:24-33` already requires. Exact duplicate Qwen skill paragraphs show a
candidate consolidation, but client-specific invocation differences must be
proven before moving them.

### Finding 5: installer policy preserves local edits but permits drift

`bin/ai-install-skills:208-224` seeds globals only when absent on its Bash path.
The native Windows installer separately implements the same policy, and
`bin/setup-machine.ps1:185-192` calls that PowerShell implementation. Existing
globals are not overwritten. That prevents destructive loss of local facts but
also means repo source changes do not automatically reach established machines.
The same tension appears in skill installation state: four drifted installed
skills were found on this machine. A safe solution needs managed blocks or a
three-way reconciliation in both installer implementations, not blind overwrite.

### Finding 6: size alone cannot decide what to remove

The longest rules include production protection, shared-database discipline,
secret handling, wrong Git identity prevention, the Windows Codex junction bug,
and measured wrapper failure modes. Removing them because they are verbose could
repeat costly incidents. Each reduction needs a rule-level owner, trigger, and
verification test.

### Finding 7: the graph idea already exists at the workflow level

The seven-stage pipeline, plan status tables, review wrappers, tests, deployment
checks, and bounded debate loops are execution graphs in practical terms. A new
graph product would add moving parts without a demonstrated missing capability.

### Finding 8: Windows has a parallel installer that can invalidate a pilot

The initial draft incorrectly treated `bin/ai-install-skills` as the path used by
Windows setup. In fact, `bin/setup-machine.ps1:185-192` invokes
`bin/install-ai-devops-windows.ps1`, which independently implements managed
skills, quarantine, and global seeding. A change made only in the Bash installer
would never run in the proposed Windows pilot. Installer parity is therefore an
explicit implementation and test requirement.

### Finding 9: skill descriptions belong in the startup baseline

Skill bodies are progressively disclosed, but clients must receive enough skill
metadata to select them. The `name` and `description` catalog is therefore part
of startup context for both Claude and Codex. Descriptions should remain precise
enough to trigger correctly, but their length and overlap must be measured. This
is a safer first optimization than trimming procedure bodies blindly.

### Finding 10: Codex's stale global summary duplicates its live skill catalog

The Codex global template both claims that Codex has no skills and embeds long
ritual summaries, while the current runtime also receives installed Codex skill
names and descriptions. The audit must compare the always-loaded ritual-summary
block against the skill catalog. The likely fix is a short routing rule plus live
skills, but only runtime trigger tests may decide what summary can be removed.

### Root cause

The system grew by preserving every hard-won lesson near the place where it was
needed. That correctly reduced repeat incidents, but no automated ownership and
context-budget gate prevents the same rule from living in global instructions,
repo files, skills, and docs at once. Installers also protect local changes so
strongly that source and installed state can silently diverge, and the Bash and
native Windows implementations can diverge from each other. The permanent fix is
a tested ownership model plus cross-installer parity and safe reconciliation,
not a one-time edit.

## 7. Approaches considered and rejected

1. **Create six files named decisions, contracts, dead ends, state, sources, and
   open questions in every repo. Rejected.** Existing `AGENTS.md`, topic docs,
   plans, `HANDOFF.d/`, and memory already own those roles. Six more files would
   duplicate state and invite contradiction.
2. **Adopt a knowledge graph or GraphRAG service. Rejected.** No measured task in
   this audit requires semantic relationship search. File paths, `rg`, routers,
   and skills already provide just-in-time discovery with fewer moving parts.
3. **Delete long instructions until token counts look good. Rejected.** Length is
   not a proxy for low value. Safety and incident-derived constraints need tests
   before relocation or compression.
4. **Make every `CLAUDE.md` only `@AGENTS.md`. Rejected as a blanket rule.** This
   may remove valid Claude-only tool and ignore guidance, and importing a huge
   `AGENTS.md` can increase automatic startup context. It should be evaluated on
   representative repos, not assumed.
5. **Blindly overwrite installed global files from templates. Rejected.** This
   would erase machine-specific facts and local configuration. The current
   non-clobber behavior exists for a sound reason.
6. **Keep identical Claude/Codex skills forever. Rejected.** It preserves client
   drift and doubles maintenance. Shared behavior belongs under `skills/shared/`
   unless a measured client difference requires an adapter.
7. **Deduplicate the two global files through runtime imports without testing
   client behavior. Rejected.** Claude and Codex have different discovery and
   loading rules. The safe design is one canonical shared source rendered or
   validated into client entrypoints, unless both clients officially support the
   same import semantics.
8. **Assume prompt caching makes large stable globals free. Rejected.** Cache
   behavior, lifetime, and billing vary by product. Cached input is still context
   that can reduce attention quality.
9. **Run a broad rewrite across all repos at once. Rejected.** It would make
   regressions hard to attribute. A pilot and measured rollout are required.

## 8. Design decisions

### Locked decisions, 2026-08-12

1. **Safety outranks token reduction.** Production, shared-database, secrets,
   destructive-action, identity, and Windows sandbox rules cannot be dropped.
2. **One durable owner per fact or rule.** Other locations link or carry a short
   client adapter. Unexplained copies are defects.
3. **Use existing artifact roles.** Global = universal behavior; machine atlas =
   machine facts; repo `AGENTS.md` = router and repo invariants; topic docs =
   detail; skills = triggered procedures; memory = durable learned facts; plan =
   forward work; handoff = active session state.
4. **No six-file convention and no graph service without a measured need.**
5. **Skills stay progressively disclosed.** Do not preload the full skill body or
   count the whole library as startup context.
6. **The rollout uses ai-devops scripts only.** No hand-edited machine configs.
7. **The first rollout target is one Windows dev box.** Do not fan out an
   unproven prompt change.
8. **Every reduction has a behavioral test and rollback.** File-size improvement
   alone is not success.
9. **Preserve Albert's GPT-5.6 low/medium limit.** Context work does not authorize
   model-setting changes.

### Open decisions for the implementing session

1. Whether shared global text should be generated from fragments, validated by a
   parity test, or expressed through supported imports. Choose the simplest
   method that preserves exact client behavior and produces reviewable Markdown.
2. Initial context budgets. Establish baselines first; do not invent hard limits.
   A reasonable first target is a 25-40% reduction in always-loaded global plus
   repo-start text with zero safety-test failures, but measured quality decides.
3. **Settled 2026-08-12:** the pilots after `ai-devops` are `popdam` and
   `shared-db`, after checking for concurrent work.
4. Whether installed-global reconciliation uses explicit managed markers or a
   separate generated base plus machine overlay. Choose based on safe preservation
   tests, not convenience.

## 9. The implementation plan

### Phase A: baseline and ownership

#### Step 1. Freeze a measured baseline

**Targets:** add a dependency-free read-only audit under `tools/context-audit/`
or `tests/`; do not install a new CLI unless the pilot proves a recurring
operational need. Add fixtures/tests under `tests/`; record the baseline in
`docs/context-engineering.md`; inspect both `bin/ai-install-skills` and
`bin/install-ai-devops-windows.ps1`.

The audit must classify files as always loaded, startup-routed, task-triggered,
or archive/ignored. It must measure the per-client skill `name` + `description`
manifest separately from task-triggered skill bodies. It must report bytes,
lines, a clearly labeled token estimate, exact duplicate paragraphs, broken doc
links, duplicate skill names, installed source drift, cross-installer behavior
drift, and required safety-marker presence. It must exclude `.git/`,
transcripts, chat archives, dependencies, generated output, worktrees, `.ai/`,
secrets, and network drives. It must never read secret values.

Count tracked source skills with a deterministic filesystem or Git-index method,
not one glob pass. During this audit GLM's glob silently omitted the real tracked
`skills/shared/secrets-to-1password/SKILL.md` and produced a false count.

**Dependencies:** none.

**Verification gate:** a clean checkout produces a stable machine-readable JSON
report and human summary; two consecutive runs match apart from timestamps; a
fixture containing a secret-like `.env` proves the audit skips it; the existing
test suites remain green.

**Correction closed, 2026-08-12.** All six items below were implemented and
verified. `frontmatter()` now parses YAML block scalars (`>`, `>-`, `|`, `|-`,
and the `+` forms) with documented folding rules; `tests/test-context-audit.ps1`
adds folded and CRLF fixtures that fail against the old parser and pass against
the new one; the real audit was rerun twice with a fixed timestamp to
byte-identical output; `docs/context-engineering.md` now shows Claude 21,521
bytes / about 5,381 tokens and Codex 14,015 bytes / about 3,504 tokens, records
the superseded values, and describes installer parity as static capability
matching; `docs/development.md` lists the audit test; the audit README says
bytes divided by four. The fourteen-versus-twelve duplicate-paragraph question
resolved as a stale manual estimate: the tool returns 12 groups over skill files
at 100, 120, and 180 normalized characters, so 12 stands and 14 is retired.
The original correction brief follows for the record.

**Required correction from Kimi K3 review, 2026-08-12:**
`tools/context-audit/context-audit.py:77-88` treats YAML folded or literal
frontmatter descriptions (`description: >-`, `>`, `|-`, or `|`) as the marker
text instead of joining the following indented lines. Seven current skills use
folded descriptions. This materially understates both client manifests in
`docs/context-engineering.md:29-30` and the step-1 handoff. Before step 2:

1. Parse single-line and folded/literal frontmatter descriptions without adding
   a dependency; preserve deterministic whitespace folding.
2. Add fixtures for folded descriptions and CRLF input. Assert the real
   description text enters both applicable client manifests and the literal
   scalar marker does not.
3. Regenerate the real baseline and correct the Claude/Codex manifest bytes and
   estimated-token rows in `docs/context-engineering.md`.
4. Add `tests/test-context-audit.ps1` to the named PowerShell suites in
   `docs/development.md`.
5. Change `tools/context-audit/README.md` from “characters divided by four” to
   “bytes divided by four,” and describe installer parity as a static capability
   check rather than measured behavioral equivalence.
6. Reconcile the earlier manual count of fourteen duplicate paragraphs with the
   tool's count of twelve by documenting the method difference or fixing the
   detector if the difference is a bug.

**Correction gate:** the folded-description fixture fails against commit
`f20ea6b` and passes after the parser fix; two real runs remain byte-identical
with a fixed timestamp; corrected manifest totals are reproducible; all step-1
and existing installer/memory suites pass. Then mark step 1 done again and begin
step 2.

**Natural context cut:** start a fresh session after the audit tool and fixtures
are committed and pushed. Re-read the remaining phases before continuing.

#### Step 2. Define the context ownership map

**Targets:** create `docs/context-engineering.md`; update the documentation maps
in `AGENTS.md`, `docs/skills-usage-guide.md`, and
`docs/codex-skills-usage-guide.md`.

For every class of information, name its canonical owner, who loads it, when it
loads, maximum useful detail, and how another artifact links to it. Include a
decision table for global vs machine vs repo vs topic doc vs skill vs memory vs
plan vs handoff. Define “pointer” as a path/link plus a clear trigger, not a vague
mention. Define stale-state rules and deletion/retention ownership.
Correct the Windows rows in `docs/skills-usage-guide.md` that still teach the
Bash-only installer path; name the native PowerShell installer and the exact
platform routing.

**Dependencies:** step 1 baseline.

**Verification gate:** reviewers can classify ten representative existing rules
without disagreement; every destination exists; link checking passes; no rule is
assigned to two canonical owners.

### Phase B: enforcement before reduction

#### Step 3. Add context-audit tooling and regression tests

**Targets:** the audit tool from step 1; `tests/test-ai-install-skills.sh`,
`tests/test-install-ai-devops-windows.ps1`, `tests/test-windows-scripts.sh`, and
`tests/test-context-audit.ps1`, which step 1 already created and listed in
`docs/development.md`. Extend that file rather than creating a second audit
test.

Add configurable warning budgets, not immediate hard failures, for global,
repo-start, and per-client skill-description context. Add exact safety-marker
tests for production mutation,
shared-db change routing, secret handling, destructive actions, Git identity,
and GPT-5.6 low/medium limits. Add cross-client parity tests for rules that must
match and divergence allowlists for client-only behavior. Add duplicate skill
body detection, global ritual-summary versus skill-description overlap, and
source/installed drift reporting. Reuse `tools/skill-trigger-eval/` for Claude
description quality. Add a separate Codex runner because the current harness is
Claude-specific. The context audit measures size and duplication; trigger evals
measure selection quality. Neither replaces the other.

**Dependencies:** steps 1-2.

**Verification gate:** each test fails when its marker is removed from a fixture,
passes with the real sources, and emits a plain reason. Budgets warn on current
state and can be ratcheted only after measured reductions.

**Completed 2026-08-12.** Budgets live in `tools/context-audit/budgets.json` set
at the measured baseline, so any growth warns from the next run, with the
step-4-6 `target` recorded beside each one. Budgets warn only and never change
the exit status, including under the new `--strict` flag. `--strict` exits 1 on a
missing safety marker, a cross-client parity mismatch, or a stale
divergence-allowlist entry. `tests/test-context-audit.ps1` removes each of the six
locked safety categories independently and requires a plain-English reason naming
that category, and proves the other five are unaffected. Parity covered ten
rules (step 5 added an eleventh, destructive actions recoverable)
that must appear in both globals plus an allowlist for genuinely client-only
text. Duplicate detection now covers both skill-body paragraphs and
always-loaded-global versus skill-description overlap. `codex-trigger-eval.py`
is the separate Codex runner; it pins `low`/`medium` reasoning and a read-only
sandbox, and its `--print-command` dry run is asserted offline. The real sources
pass `--strict` cleanly. Eval sets for Codex skills are not written yet; that is
step 4 or 6 work.

### Phase C: reduce always-loaded context

#### Step 4. Slim the global files

**Targets:** `templates/system/CLAUDE-global.md`,
`templates/system/AGENTS-global-codex.md`, selected shared fragments or validation
data if chosen, `templates/system/machine-atlas.md`, installer tests, and relevant
usage docs. Include both `bin/ai-install-skills` and
`bin/install-ai-devops-windows.ps1` anywhere installation behavior changes.

Keep universal response style, authority boundaries, production/cloud safety,
secret rules, destructive-action rules, model-effort rule, Git identity gate,
and the short routing contract always loaded. Move detailed procedures, incident
histories, machine facts, long handoff templates, and provider-specific workflows
behind skills or topic-doc links. A link must say exactly when to load its target.
Do not shorten a rule until its behavioral test exists. Correct the stale
`AGENTS-global-codex.md:44-47` claim only after Codex skill-loading and trigger
tests capture current behavior.

**Dependencies:** step 3 enforcement.

**Verification gate:** `python tools/context-audit/context-audit.py --root .
--strict` exits 0 after every trim (it now also fails on a one-sided parity
deletion); the matching budget in `tools/context-audit/budgets.json` is ratcheted
down and the budget table in `docs/context-engineering.md` updated;
required-marker tests pass; both installed-client fixtures
load the correct global and overlay; a representative Claude and Codex session
correctly answers safety and routing probes without opening unrelated docs;
always-loaded measured text falls materially from baseline with no quality loss.

**Source side completed 2026-08-12.** Both globals were trimmed from 33,311 to
25,764 bytes (22.7%) with no rule deleted: each removed passage now sits with its
canonical owner and the global carries the rule plus a pointer stating when to
open that owner. The moves are tabulated in `docs/context-engineering.md` under
"Where the removed global detail now lives". `--strict` exits 0; safety markers,
cross-client parity, and global-vs-skill-description overlap are all clean; the
`alwaysLoadedBytes` budget is ratcheted to 25,764 in both
`tools/context-audit/budgets.json` and the tool's fallback defaults; all seven
named Bash/PowerShell suites pass. Two gates remain and are recorded as drift
above: the live client probes belong to step 8, and the stale Codex
"no skills system" sentence with its ritual summaries stays until step 6 has
Codex trigger evidence.

#### Step 5. Tighten `AGENTS.md` as a router

**Targets:** `AGENTS.md`, affected topic docs, `CLAUDE.md`, and router-link tests.

Keep project summary, task-to-doc map, boundaries, identifiers needed for most
tasks, what to ignore, active plan links, and truly repo-wide invariants. Move
full incident narratives and specialist procedures to named docs or skills. Keep
one-sentence warnings and direct pointers in the router. Validate whether Claude
should use an `@AGENTS.md` import or explicit read instruction; do not enable both
if that duplicates the file in context.

**Dependencies:** step 4 and ownership map.

**Verification gate:** every current documentation-map task still resolves to
the correct source; a fresh Claude and Codex session can orient in under five
minutes; link tests pass; incident-specific probes find the detail only when
triggered; startup context is lower than baseline.

**Completed 2026-08-12.** Startup-routed context fell from 50,729 to 35,972
bytes, a 29.1% cut that lands 632 bytes above the 35,340 target; `AGENTS.md`
alone went from 48,451 to 33,694 bytes. Measure from `C:
eposi-devops`: a
worktree whose files still have LF endings reports about 400 bytes less. Nothing was deleted. The ten "intentional quirks"
narratives moved verbatim into `docs/design-decisions.md`, the two incident
narratives into `docs/critical-incidents.md` (one paragraph the source repeated
twice is now single), and the router keeps a one-line rule plus a pointer with a
stated trigger for each. The three oversized delegate-wrapper rows now point at
`docs/glm-opencode.md` section 5 and the STEP 0 VERIFICATION headers in
`bin/ai-grok-review`, `bin/ai-grok-implement`, and `bin/ai-kimi`, which were
verified to contain the same constraints in full. `--strict` exits 0 with zero
missing safety markers, zero parity mismatches, zero overlaps, zero broken links,
and zero budget warnings. Both moved budgets are ratcheted in all three places.
Open question 3 is answered: no `@AGENTS.md` import.

**Natural context cut:** start a fresh session after global/router changes are
committed, pushed, and proven on local fixtures. Do not install them broadly yet.

### Phase D: skill consolidation and safe installation

#### Step 6. Consolidate cross-client skill duplication

**Targets:** proven duplicate pairs under `skills/claude/` and `skills/codex/`,
new or existing canonical packages under `skills/shared/`, installer collision
tests, and both skills usage guides.

Start with exact-body candidates such as Qwen. Separate shared policy from a
small client adapter only when invocation differs. Do not merge skills merely
because paragraphs match. Preserve trigger descriptions and tool-specific safety
rules. Retire old managed copies through the existing quarantine mechanism.
Correct `docs/codex-skills-usage-guide.md:84`: `--migrate-obsolete` is now a
no-op, while managed orphan quarantine is automatic.

**Dependencies:** steps 2-3.

**Verification gate:** the installer fails closed on name collisions; both client
install fixtures receive the intended skill; trigger tests still fire on real
prompts; client-only commands remain correct; duplicate paragraph report falls
without new cross-file contradictions.

#### Step 7. Repair installation drift safely

**Targets:** `bin/ai-install-skills`, `bin/install-ai-devops-windows.ps1`,
`bin/setup-machine.ps1`, config templates or managed-block metadata chosen in
step 8, and installer tests.

Implement preview-first reconciliation. Preserve unowned local files and machine
overlays. Show the exact source/installed differences. Require an explicit
managed boundary before replacing a global. Keep recoverable backups or generated
base files and prove idempotence. Implement equivalent behavior in the Bash and
native PowerShell installers. Do not add a second sync system.

`bin/setup-machine.ps1:187,192` currently invokes the native installer through
Windows PowerShell 5.1 (`powershell`), even though setup itself requires
PowerShell 7. The implementation must either keep
`bin/install-ai-devops-windows.ps1` fully 5.1-compatible or deliberately change
those calls to `pwsh` and add a regression test for the new requirement.
**Decided by Albert on 2026-08-12: keep the child path 5.1-safe.** Do not migrate
those calls and do not introduce PowerShell 7-only syntax into that child path.

**Dependencies:** stable source layout after steps 4-6.

**Verification gate:** fixtures cover absent, identical, locally extended,
locally conflicting, obsolete managed, and vendor-unmanaged files; dry-run makes
no writes; apply preserves overlays; second apply makes no changes; no duplicate
TOML keys; installed skill hashes match sources; Bash/PowerShell parity tests
prove both installers produce the same managed skill/global outcome.

### Phase E: controlled pilot and rollout

#### Step 8. Pilot on one Windows machine

**Targets:** `al8960ofc` first unless concurrent work makes another dev box safer;
the current repo plus `popdam` (medium) and `shared-db` (large/high-risk), chosen
by Albert on 2026-08-12. Check for concurrent work in both before starting.

Before install, save hashes and recoverable copies of the installed global files,
list managed skills, and record real usage from matched Claude and Codex tasks.
Run installer dry-run, inspect it, then install. Fully restart clients so startup
context reloads. Run routing, safety, task-quality, token/cache, and no-drift
probes. Use identical tasks and comparable fresh sessions for before/after data.
Capture the native PowerShell installer's output and assert that the new
reconciliation path actually executed; command success alone is insufficient.

**Dependencies:** steps 1-7 committed and all named local Bash/PowerShell suites
from `docs/development.md` passing. This repo has no GitHub Actions CI. **Plus a gate
added by Albert on 2026-08-12:** `synology-long-running-operations`,
`shared-db-change`, and `handoff-writer` each have a committed eval set and a
recorded trigger score before the pilot starts.

**Verification gate:** all safety probes pass, real tasks complete correctly,
no machine facts disappear, installed hashes/overlays match design, and measured
always-loaded global/router/manifest size falls without material extra tool calls
or latency. Task correctness and safety are hard gates. Total input, cached
input, billed cost, and dollar savings are report-only when the product exposes
official fields; lack of a subscription usage field or a billed-token drop does
not fail an otherwise correct pilot. Roll back immediately on any safety or
correctness regression.

#### Step 9. Roll out to all configured machines

**Targets:** `916-alien`, `albt16`, remaining managed Windows boxes, then Ubuntu
AI users. Use `bin/setup-machine.ps1`, `bin/install-ai-devops-windows.ps1`, and
`bin/ai-install-skills` only through their documented platform paths.

Check reachability and concurrent work first. Pull `main` fast-forward-only. Run
dry-run and diff review per machine. Install, restart the affected clients, and
run `ai-devops doctor`, source/install hash checks, memory task checks, and a
short behavior probe. Do not touch production workload state.

**Dependencies:** step 8 verification-gate evidence recorded in this plan's
STATUS table. No separate human approval is required by this plan.

**Verification gate:** every reachable machine reports the expected commit,
correct global base plus overlay, current managed skills, GPT-5.6 low/medium,
working Codex sandbox canary, and no secrets in committed or generated config.
Offline machines remain explicitly open in the plan and handoff.

### Phase F: evaluation and closeout

#### Step 10. Measure, ratchet budgets, and close

**Targets:** `docs/context-engineering.md`, this plan's STATUS table, tests,
relevant memory entry, and this session's/future implementer's own handoff.

Compare before/after startup context, total input, cached input where officially
reported, tool calls, latency, task success, safety probes, and user corrections.
Set warning or failure budgets only from the observed safe result. Record cases
where more context was necessary. Delete this plan's open handoff only when all
reachable rollouts and acceptance checks are proven; keep unavailable machines
as an explicit separate open workstream if necessary.

**Dependencies:** steps 8-9.

**Verification gate:** report includes reproducible commands and official usage
fields, not estimates; all STATUS rows are current; Git author identity is
correct; focused commits are pushed to `main`; all named local Bash/PowerShell
suites pass; there is no GitHub Actions CI and no deploy because this toolkit has
no hosted service; installed state matches the pushed commit on every completed
machine.

## 10. Tests required

1. **Context classification test:** fixtures prove always-loaded, routed,
   triggered, and ignored files are counted separately.
2. **Secret exclusion test:** `.env`, credential, transcript, chat, `.git`, `.ai`,
   dependency, generated, worktree, and network-root fixtures are never opened.
3. **Stable output test:** repeated audits produce identical content after
   timestamp normalization.
4. **Safety-marker test:** independently remove each locked safety category from
   a fixture and require a clear failure naming the missing category.
5. **Cross-client parity test:** shared global rules match semantically or through
   canonical fragment identity; allowed client differences are explicit.
6. **Skill-description manifest test:** measure name/description startup text per
   client; warn on descriptions that are long, duplicative, or too vague to
   trigger reliably. Cover single-line, folded/literal YAML descriptions and
   CRLF files so scalar markers can never replace real text. Reuse the existing
   Claude trigger-eval harness and add a
   separate Codex runner; do not pretend size measurement proves trigger quality.
7. **Duplicate-skill test:** shared/client name collisions fail; exact duplicate
   client skills and global ritual-summary versus skill-description overlap
   generate consolidation warnings.
8. **Broken-pointer test:** all router, skill, plan, and handoff links resolve.
9. **Installer dry-run test:** reports changes and writes nothing.
10. **Installer reconciliation matrix:** absent, same, local overlay, local
   conflict, managed obsolete, and unmanaged vendor files behave as designed.
11. **Bash/PowerShell installer parity test:** equivalent fixtures produce the
    same installed managed files, quarantine results, overlays, and diagnostics.
12. **Idempotence test:** a second installation changes nothing.
13. **Windows path test:** `%USERPROFILE%` wins over a misleading `HOME`; no file
    lands on `Z:`.
14. **Codex TOML test:** no duplicate keys and no Claude script touches Codex
    config outside its named managed block.
15. **Behavior probes:** Claude and Codex both route a shared-db change, a
    production request, a normal code fix, an old-session continuation, and a
    Windows Codex sandbox diagnosis correctly.
16. **Representative task evaluation:** at least five matched before/after tasks
    across simple, repo-navigation, implementation, high-risk, and long-horizon
    work. Record correctness, total/cached input where exposed, tool calls,
    elapsed time, and required human correction.
17. **Existing suites:** run the complete existing Bash and PowerShell test
    suites named by `docs/development.md`; no current test may be skipped silently.

## 11. Constraints, standing rules, and gotchas

- Work on `main`. Preserve unrelated `.ai/` and
  `docs/claude-remote-control-hardening-v2.md` work.
- Before every commit, `git var GIT_COMMITTER_IDENT` must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- GPT-5.6 reasoning must remain explicitly `low` or `medium`.
- No production/shared-cloud mutation. Never run Terraform apply/destroy or
  mutating production `gcloud` commands.
- No shared Supabase change is required. If that changes, stop and use the
  canonical `shared-db` branch/PR workflow first.
- Never read or expose secrets, transcript contents, auth files, `.env` values,
  or licensed private data.
- Serialize 1Password operations. This plan should not need any secret read.
- Use PowerShell 7 for `setup-machine.ps1`. Its current child invocation of
  `install-ai-devops-windows.ps1` uses Windows PowerShell 5.1 at lines 187 and
  192, so keep that child 5.1-safe or explicitly migrate the invocation to
  `pwsh` with tests. A bare `bash` may be WSL and not inherit Windows environment
  variables; use the correct native or Git Bash path.
- Do not hand-edit `C:\Users\ahazan2\.codex\config.toml` or Claude config. Use
  repo installers and managed blocks only.
- Do not trust `codex --version` as a functional check. Run the real sandbox
  write canary in `ai-devops doctor`.
- Installed globals currently contain local additions. Preserve them until the
  overlay design proves safe.
- The full skill library is not always-loaded context. Do not optimize the sum of
  all skill bodies as if it were a per-turn cost.
- Exact duplicate text can be intentional when clients need separate entry files.
  Optimize maintenance ownership and runtime context separately.
- Plans and handoffs serve different jobs. Do not combine them or rewrite root
  `HANDOFF.md`.
- Any unavoidable workaround must be labeled TEMPORARY in the implementing
  session's own handoff.
- **Do not delegate a step of this plan to `ai-glm implement` until the GLM
  permission bug is fixed.** On 2026-08-12 step 2 was dispatched to GLM as job
  `context-ownership-map-step2` and the wrapper's permission gate killed it after
  GLM had already edited three files. The partial patch was preserved, but the
  step had to be completed by hand. Root cause and fix are tracked in
  [`plan_ai-glm-permission-failures.md`](plan_ai-glm-permission-failures.md).
  GLM **review** sessions are unaffected and remain the right tool for a second
  opinion on steps 4-6.

## 12. Access and environment

- GitHub CLI `gh`, Git, PowerShell 7, Claude Code, Codex, `ai-glm`, and
  `ai-grok-review` are expected on `al8960ofc`; verify with real doctor/status
  calls before relying on them.
- Repository: `C:\repos\ai-devops`, `main`, remote
  `https://github.com/u2giants/ai-devops`.
- Machine facts: `templates/system/machine-atlas.md`.
- Config ownership: `docs/config-inventory.md`.
- Skill installation: `bin/install-ai-devops-windows.ps1` on native Windows;
  `bin/ai-install-skills` on Ubuntu/Git Bash where documented.
- Windows setup: `bin/setup-machine.ps1`.
- Secrets, if an unrelated validation unexpectedly needs them, live only in the
  1Password vault `vibe_coding`; never place values in a prompt or plan.
- There is no local server to start and no URL to deploy for this toolkit.
- Delegate review artifacts belong under `.ai/reviews/`, which is untracked and
  must not be committed.

## 13. Definition of done, rollback, risks, and open questions

### Definition of done

- [ ] Baseline audit is reproducible and excludes sensitive/irrelevant paths.
- [ ] Ownership map assigns every rule class one canonical home.
- [ ] Locked safety rules have regression tests.
- [ ] Always-loaded global plus repo-start context is materially smaller.
- [ ] Representative task quality and safety are equal or better.
- [ ] Cross-client skill duplicates are consolidated only where behavior matches.
- [ ] Installed/source drift is visible and safely reconcilable.
- [ ] One Windows pilot passes before broad rollout.
- [ ] Every reachable managed machine is verified against the pushed SHA.
- [ ] Offline machines have a separate accurate open handoff.
- [ ] All named local Bash and PowerShell tests pass. This repo has no GitHub
      Actions CI and no CI gate may be invented.
- [ ] Documentation, memory, plan STATUS, and handoffs describe current reality.
- [ ] Focused commits are pushed to `main`; local and `origin/main` match.
- [ ] No hosted deployment is claimed because none exists.

### Rollback

Keep pre-install hashes and recoverable copies of installed globals and managed
skill manifests for each pilot machine. If a behavior or safety probe fails,
restore the prior generated base/overlay through the same installer mechanism,
restart the clients, rerun the failing probe and `ai-devops doctor`, and record
the failure in the plan and an open handoff. Never use `git reset --hard`, delete
unowned skill directories, or overwrite local overlays to roll back.

### Risks

1. Shortening prompts can remove a rare but critical safety condition.
2. Moving detail behind a link can fail if the trigger is vague or the target is
   not reachable.
3. Generated shared fragments can make Markdown harder to review if the build is
   opaque. Prefer transparent source and deterministic output.
4. Provider updates can change loading, compaction, caching, or skill behavior.
5. Before/after token comparisons can be invalid if models, tasks, sessions, or
   cache state differ.
6. Existing machine-local additions can be lost by an unsafe reconciliation.
7. Application repo routers may require separate plans because they contain
   business-critical detail and concurrent work.

### Open questions and decision criteria

1. **Managed base plus overlay, managed blocks, or generated client globals?**
   Decide after fixture tests. Choose the smallest design that preserves local
   facts, is deterministic, and is reviewable without a custom parser.
2. **What budget should become a gate?** Use pilot distributions. Warn first;
   fail only after safe stable baselines exist.
3. **Does `@AGENTS.md` improve Claude startup behavior? Answered 2026-08-12: no,
   do not enable it.** An import loads the whole router into every Claude session
   in this repo unconditionally, undoing step 5's reduction. `CLAUDE.md` keeps its
   explicit read instruction, and the two mechanisms are never both enabled.
   Step 8 may revisit with real loaded-context measurements.
4. **Which application repos need their own follow-up plan?** Use the audit to
   rank always-loaded size, duplication, risk, and task frequency. Do not bulk
   rewrite them under this plan.

## Review and debate record

This section must be updated after each independent review. Reviews occur in
this order: Claude, GLM 5.2, then Grok 4.5. Each reviewer must answer:

1. What material evidence or background is missing?
2. Which conclusions are wrong or unsupported?
3. What proposed work is unnecessary or too complex?
4. What safety, rollout, or measurement failure could invalidate the plan?

The planning agent must challenge unsupported reviewer claims, update this file
only for evidence-backed corrections, and run bounded follow-up turns until
there is evidence-backed consensus or the documented turn/cost limit is reached.
Agreement without re-reading the current plan and evidence is not consensus.

### Claude review

Claude completed a read-only review with Opus through Claude Code 2.1.217. It
re-read the plan and named source files. Its material objections were:

1. **Accepted:** the initial plan named the wrong Windows installer path. Claude
   proved `bin/setup-machine.ps1:185-192` calls
   `bin/install-ai-devops-windows.ps1`, not `bin/ai-install-skills`. The plan now
   requires changes and parity tests in both implementations.
2. **Accepted and broadened:** the plan omitted always-visible skill manifest
   metadata. Claude stated this for Claude Code; the correction applies to both
   Claude and Codex because both clients need the name/description catalog to
   select skills. Bodies remain task-triggered.
3. **Accepted:** code citations were corrected from header comments to the Bash
   install functions at `bin/ai-install-skills:122-150` and `:208-224`.
4. **Accepted:** step 6/7 must correct the stale
   `docs/codex-skills-usage-guide.md:84` statement that
   `--migrate-obsolete` performs quarantine; `bin/ai-install-skills:74` now treats
   it as a no-op while managed orphan quarantine is automatic.
5. **Accepted framing correction:** benefits must lead with attention quality and
   correctness, not promise marginal billed savings on stable cached prefixes.
6. **Rejected as a removal:** Claude questioned whether the audit/tests are too
   heavy before trimming prose. Because these files govern production safety,
   secrets, database discipline, destructive action, and multiple machines, the
   tests remain before broad reduction. The implementation may keep the audit
   tool small and dependency-free, but it may not trim locked controls before
   their regression gates exist.

After these corrections, Claude's two high-severity objections are addressed in
the current plan. The plan will be relayed to GLM and Grok for independent
challenge rather than treating Claude's answer as authority.

### GLM 5.2 review

GLM 5.2 completed an initial review and one rebuttal in the persistent read-only
session `context-engineering-consolidation-review`.

Initial GLM findings:

1. **Accepted:** reuse `tools/skill-trigger-eval/` for Claude description quality
   rather than building a competing trigger mechanism. A Codex runner is still
   needed because the current tool is Claude-specific.
2. **Accepted:** detect duplication between Codex's inline global ritual summaries
   and live skill descriptions, not only duplication among skill bodies.
3. **Accepted with caution:** record GPT-5.4/5.5/5.6 text drift as an ownership
   audit case. Do not mechanically replace strings because some names may be
   historical stage identifiers or intentional model roles.
4. **Accepted:** prefer a small dependency-free test script over a permanently
   installed `ai-context-audit` command unless an operational use proves the CLI
   is necessary.
5. **Rejected after debate:** GLM initially claimed Codex had no skill system,
   relying on stale `AGENTS-global-codex.md:44-47`. Current Codex runtime,
   official OpenAI material, `skills/codex/`, the installer, and the repo's Codex
   usage guide prove the statement is stale. GLM retracted the objection.
6. **Rejected after debate:** GLM's glob silently omitted the tracked
   `skills/shared/secrets-to-1password/SKILL.md`, leading it to claim 16 shared
   skills and a dangling reference. Direct filesystem and Git-index evidence
   proved 17 shared skills and a real installed source. GLM retracted both claims
   and recommended deterministic counting rather than a single glob.

Final GLM position: no material objection remains to the plan's structure, root
cause, scope, safety gates, installer parity, or pilot. The accepted additive
refinements are now in findings 9-10, steps 1, 3-4, and tests 6-7. GLM usage was
reported by the wrapper; no money figure is available for GLM.

### Grok 4.5 review

Grok 4.5 completed the initial read-only review through `ai-grok-review` using
the pinned `grok-4.5-build` model. It reported 594,170 tokens, 498,432 cached
tokens, nine turns, and cost `$0.3848336`.

All six material objections were accepted:

1. The repo has no GitHub Actions CI, so every “CI green” gate was replaced with
   the named local Bash and PowerShell suites from `docs/development.md`.
2. The pilot now treats safety, correctness, overlays, and reduced always-loaded
   text as hard gates. Provider input/cache/cost fields are report-only when
   officially exposed; billed-token reduction is not a required pass condition.
3. Step 3 now names `tests/test-install-ai-devops-windows.ps1`, and the access
   section names the native Windows installer explicitly.
4. The plan now records that `setup-machine.ps1:187,192` invokes the installer
   through Windows PowerShell 5.1. Implementation must preserve 5.1 compatibility
   or deliberately switch to `pwsh` with tests.
5. “Pilot approval” was replaced by an evidence gate recorded in STATUS so the
   implementer does not stop and ask Albert for an undefined approval.
6. The audit defaults to a dependency-free tool/test script. A permanently
   installed CLI requires a proven operational need.

Grok also noted that this handoff lagged the plan review state; it is corrected.
The corrected plan was sent back to the same Grok session for a bounded
consensus check. Grok re-read the plan and handoff, marked all six objections
resolved, found no new conflict, and reported no remaining material objection.
The follow-up used 300,046 tokens, 279,424 cached tokens, three turns, and cost
`$0.1340952`. Total Grok review cost was `$0.5189288`, below the `$1.50` ceiling.

### Kimi K3 implementation review

Kimi reviewed the completed step-1 implementation through the protected
read-only `ai-kimi` session `context-engineering-step1-review`. The wrapper
requested `kimi-code/k3`; Kimi headless output does not report the returned
model, tokens, cache, or cost, so none are claimed.

Kimi found one material defect, accepted by Codex after direct source review:
seven skill files use folded YAML descriptions, while the audit's frontmatter
parser records only the literal scalar marker `>-`. The published Claude and
Codex manifest totals were therefore understated. The correction was implemented
and verified on 2026-08-12; step 1 is done again and its totals are corrected.

Kimi also confirmed that secret exclusions, deterministic tracked-path
discovery, drift reporting, the Windows automatic-quarantine test correction,
and the fresh-session handoff were otherwise sound. Its non-blocking findings
were folded into the correction and are all now applied: the new test is listed
in `docs/development.md`, the audit README says bytes rather than characters,
installer parity is described as a static capability check, and the manual
fourteen-versus-tool twelve duplicate-paragraph count is reconciled in favor of
twelve. The saved review is untracked at
`.ai/reviews/kimi-context-engineering-step1-review-20260812T142135Z.md`.

### Final consensus ledger

#### Agreed decisions

1. Preserve safety and correctness before optimizing size or billed tokens.
2. Use one canonical owner per fact and existing artifact roles rather than the
   X post's six-file convention.
3. Do not add a graph/GraphRAG service without a measured missing capability.
4. Measure always-loaded globals, repo-start text, and skill metadata separately
   from task-triggered skill bodies.
5. Test locked safety rules before moving or shortening their text.
6. Keep Bash and native Windows installers behaviorally aligned and preserve
   machine overlays through preview-first reconciliation.
7. Reuse the Claude trigger-eval harness, add a Codex runner, and test selection
   quality separately from text size.
8. Pilot one Windows machine first. Hard gates are safety, correctness, overlay
   preservation, and reduced always-loaded text. Provider token/cache/cost fields
   are report-only where officially exposed.
9. Use named local Bash/PowerShell suites. This repo has no GitHub Actions CI.
10. Preserve PowerShell 5.1 compatibility for the current child installer path
    or deliberately migrate it to `pwsh` with tests.

#### Rejected alternatives

The nine alternatives in section 7 remain rejected. The reviews also reject
inventing CI, requiring billed-token savings as a hard pass, requiring undefined
human pilot approval, installing a permanent audit CLI without operational need,
trusting the stale “Codex has no skills” sentence, and treating one failed glob
as proof a tracked skill is absent.

#### Unresolved objections

None material. Claude's two high-severity findings, GLM's supported refinements,
and Grok's six practical gaps are resolved in the current plan.

#### Evidence still needed during implementation

1. Exact step-1 baseline and installed/source drift remeasurement.
2. Live Claude and Codex trigger evidence before deleting ritual summaries or
   merging client skills.
3. Pilot discovery of which official token/cache/cost fields each product exposes.
4. Corrected per-client manifest totals after folded YAML descriptions are parsed;
   the current published totals are not valid budget inputs.

These are implementation gates already assigned to steps 1, 4, 6, and 8. They do
not require Albert to answer a planning question.

## Mandatory plan self-audit

### 1. Could a brand-new AI session execute this without asking Albert anything?

Yes. Sections 1-5 define the business goal, toolkit, repositories, machines,
trigger, scope, exact baseline, and current Git state. Sections 9-12 give ordered
file targets, dependencies, tests, verification gates, access, and platform
constraints. Section 13 defines completion and rollback.

### 2. Does the plan preserve all current background, nuance, and rejected work?

Yes. Sections 3 and 6 distinguish supported context-engineering evidence from
the X post's unsupported marketing. Section 7 records nine rejected approaches
and why. Section 8 separates locked rules from real implementation choices.
The review record will preserve material corrections from Claude, GLM, and Grok.

### 3. Is the goal clear enough to guide a judgment call if a step is wrong?

Yes. Section 1 defines the desired business outcome and explicitly says the goal
wins over a conflicting step. Sections 8 and 13 state the safety priority,
decision criteria, risks, and rollback needed to choose correctly.

### Checklist result

All 13 required sections are present. The plan includes an explicit out-of-scope
list, file-specific steps, verification gates, named tests, locked/open decisions,
secret-safe access notes, commit/push/local-test completion, and mutual
plan/handoff links. The final post-debate self-audit passed on 2026-08-12.
