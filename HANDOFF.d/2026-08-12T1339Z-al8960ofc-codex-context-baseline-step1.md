# Handoff: context-engineering baseline complete, ownership map next

## 0. Decisions only the owner can make

None. Nothing in this workstream needs Albert before the next session starts.

Already settled, do not re-ask:

- On 2026-08-12, the reviewed plan locked safety and correctness above token
  reduction. Do not remove a safety rule to meet a size target.
- On 2026-08-12, the work was ordered phase by phase. Step 2 is next. Do not
  skip to trimming globals, `AGENTS.md`, or skills.
- On 2026-08-12, generated audit reports were kept under untracked `.ai/` and
  excluded from Git. The tracked tool, tests, documentation, and plan update are
  the source of truth.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public backup-and-restore toolkit for his
Claude Code, Codex, shared skills, machine setup, durable memory, and multi-model
development workflow. It is Bash, PowerShell, Python standard-library tooling,
and Markdown. It is not a hosted application. It has no database, container,
production service, deployment URL, or GitHub Actions workflow.

The repository is `C:\repos\ai-devops` on Windows machine `al8960ofc`. Its
canonical remote is `https://github.com/u2giants/ai-devops`. It uses `main`
only. The active implementation plan is
[`../plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md).

## 2. What we set out to do this session, and why

Albert asked this session to read the repo guide, prior audit handoff, and full
context-engineering plan, then begin at the first open STATUS row and implement
phase by phase. The first open row was step 1, "Freeze a measured baseline."

The business goal is to reduce repeated Claude and Codex context without losing
safety rules, machine facts, hard-won incident knowledge, or the ability of a
fresh session to work without asking Albert to explain the system again.

The technical objective for this session was narrower: add a small read-only
audit, prove it skips secrets and irrelevant paths, record a repeatable baseline,
run the existing installer and memory tests, update the plan, commit, and push.
No prompt or instruction trimming was authorized in step 1.

## 3. Current state, what is true right now

Step 1 is complete. The plan STATUS row is `done`, and the fresh-session marker
points to step 2 at
`plan_context-engineering-consolidation.md:18`. Step 2 begins at
`plan_context-engineering-consolidation.md:435`.

The following work is committed and pushed to `origin/main` at commit
`f20ea6b98bc62e9d6b9c434fa3811fb96d2ec981`:

- `tools/context-audit/context-audit.py` is the dependency-free read-only audit.
  It uses tracked paths from Git at line 48, reports installed drift at line 122,
  compares Bash/PowerShell installer capabilities at line 155, and builds the
  report at line 175.
- `tools/context-audit/README.md` gives the exact local command and exclusions.
- `tests/test-context-audit.ps1` proves stable output, context classification,
  both client manifests, installer parity, required safety markers, and secret
  exclusion.
- `docs/context-engineering.md:7` records the frozen measurements and
  `docs/context-engineering.md:51` gives the reproduction command.
- `tests/test-install-ai-devops-windows.ps1:123` now tests the shipped automatic
  quarantine behavior. `-MigrateObsolete` remains accepted as a no-op.
- `docs/development.md` now describes quarantine as automatic.

Measured tracked-source baseline on 2026-08-12:

- always-loaded global templates: 2 files, 33,311 bytes, about 8,329 estimated
  tokens;
- startup-routed `AGENTS.md` and `CLAUDE.md`: 2 files, 49,401 bytes, about
  12,351 estimated tokens;
- task-triggered skill bodies: 48 files, 405,271 bytes, about 101,333 estimated
  tokens. This third total is not startup context;
- Claude name/description manifest: 35 skills, 18,448 bytes, about 4,612
  estimated tokens;
- Codex name/description manifest: 30 skills, 10,593 bytes, about 2,649
  estimated tokens;
- 12 exact normalized duplicate paragraph groups, no duplicate skill names, no
  broken audited relative links, no installer-capability differences, and no
  missing locked safety category;
- four drifted installed skill files on this machine: Claude
  `shared-db-handover`, Claude `shared-db-orchestrator`, Claude
  `kimi-code-delegation`, and Codex `kimi-code-delegation`;
- both installed global files differ from source because this machine has local
  additions under the current non-clobber policy. Step 1 reports that state and
  does not reconcile it.

Verification completed:

- `pwsh -NoProfile -File tests/test-context-audit.ps1` passed.
- Two real reports with the same `--generated-at` value had identical hashes.
- Git Bash `tests/test-ai-install-skills.sh` passed.
- Git Bash `tests/test-ai-memory-sync.sh` passed.
- `tests/test-install-ai-devops-windows.ps1` passed.
- `tests/test-mcp-env-launch.ps1` passed.
- `tests/test-memory-sync-scheduled-task.ps1` passed.
- Local `main` and `origin/main` both equal `f20ea6b`.

No hosted deployment exists. Nothing was installed on this machine. No global,
repo instruction, skill body, machine config, production system, shared cloud,
or database was changed.

Unrelated untracked paths remain untouched: `.ai/` and
`docs/claude-remote-control-hardening-v2.md`.

## 4. Everything we tried that did not work

1. The first fixture audit failed because the tool always tried to inspect the
   real plan and `HANDOFF.md`, even when a small temporary fixture did not contain
   them. The permanent fix was to make link checking skip optional files that do
   not exist. Do not restore an assumption that every fixture is a full repo.
2. The first full existing-suite run failed in
   `tests/test-install-ai-devops-windows.ps1`. The stale test expected retired
   skill quarantine only after `-MigrateObsolete`. The real Bash and PowerShell
   installers already quarantine managed or explicitly retired skills
   automatically and accept the old flag as a no-op. The test fixture now creates
   `config/retired-skills.txt`, previews automatic retirement, applies without
   the old flag, and proves the old flag is harmless.
3. The first push was rejected because another session had pushed memory-sync
   commits to `main`. The tracked tree was clean, so this session fetched
   `origin/main`, rebased its one focused commit, reran the focused audit test,
   and pushed successfully. Do not force-push or discard the intervening memory
   commits.
4. Initial link checking treated a Markdown example inside a fenced code block
   in the handoff-writer skill as a real relative link and reported a false
   broken path. The checker now removes fenced code before checking links.

## 5. Root causes and key findings

- A stable baseline needs deterministic source discovery. The tool uses
  `git ls-files`, with a sorted filesystem fallback only for fixtures. This
  avoids the prior GLM mistake where one glob silently missed a tracked skill.
- Secret safety comes from limiting the input set, not from reading everything
  and redacting later. The audit skips `.env`, credential suffixes, `.git`,
  `.ai`, transcripts, chats, dependencies, generated directories, worktrees,
  and network roots before reading content.
- Skill bodies and skill selection metadata are different costs. The baseline
  reports the 48 conditional bodies separately from each client's always-visible
  name and description manifest.
- Installed drift is real but is not automatically wrong. The two global files
  intentionally contain local additions. Step 7 owns safe reconciliation after
  ownership, tests, and source layout are stable.
- The existing Windows test failure was documentation/test drift, not an
  installer defect. The plan had already recorded automatic quarantine and the
  old flag's no-op status, but one test and one line in `docs/development.md`
  still taught the retired behavior.
- The tool found no current static capability difference between the Bash and
  native PowerShell installers for managed markers, shared-name collision
  refusal, quarantine, non-clobber globals, and dry-run support. This is a
  baseline signal, not proof of full behavioral parity. Step 3 adds deeper tests.

## 6. Exact next steps

1. Read `AGENTS.md`, this handoff, the older context audit handoff, and the full
   active plan. Then re-read plan sections 1, 4, 8, 11, 13, and step 2 at line
   435. You will know this worked when you can state the goal, locked safety
   decisions, step 2 targets, and its verification gate without chat context.
2. Mark step 2 `in progress` in the plan before editing implementation files.
   You will know this worked when the STATUS table names the ownership-map work
   as current and no later step is marked started.
3. Expand `docs/context-engineering.md` with the canonical ownership table
   required by step 2: global, machine atlas, repo `AGENTS.md`, topic doc, skill,
   memory, plan, and handoff. For each, name who loads it, when it loads, maximum
   useful detail, stale-state/retention owner, and how other artifacts point to
   it. Define a pointer as a real path/link plus a clear trigger. You will know
   this worked when ten representative rules can each be assigned to one owner.
4. Update the documentation map in `AGENTS.md` and the relevant maps in
   `docs/skills-usage-guide.md` and `docs/codex-skills-usage-guide.md`. Correct
   Windows routing so native Windows uses
   `bin/install-ai-devops-windows.ps1`, while Ubuntu/Git Bash uses the documented
   Bash path. You will know this worked when every named destination exists and
   no Windows row falsely claims setup uses only `bin/ai-install-skills`.
5. Add or extend link/ownership tests only as needed for step 2's gate. Do not
   begin step 3 budgets or safety-fixture removal tests early. You will know this
   worked when links pass and the ownership table has no two canonical homes for
   the same rule class.
6. Run the focused context audit test and every existing suite required by the
   files changed. Update the plan STATUS and current fresh-session start before
   the next natural cut. You will know this worked when step 2 is marked done,
   test evidence is recorded, and step 3 is the first open row.
7. Verify `git var GIT_COMMITTER_IDENT`, stage only this workstream, commit to
   `main`, rebase safely if memory sync moves the remote, and push. You will know
   this worked when local `HEAD` and `origin/main` match and unrelated untracked
   paths still exist unchanged.
8. At the next natural context cut, write a new handoff under `HANDOFF.d/` using
   the handoff-writer skill. Do not edit this file or the older handoff. You will
   know this worked when the new session starts at step 3 from a committed,
   pushed, self-audited handoff.

## 7. Constraints and gotchas in force

- Work on `main`. Preserve unrelated `.ai/` and
  `docs/claude-remote-control-hardening-v2.md`.
- Do not skip to trimming instructions. Steps 2 and 3 must establish ownership
  and enforcement before steps 4 and 5 reduce always-loaded text.
- Never read or expose secrets, transcript contents, chat archives, `.env`
  values, auth files, or licensed private data.
- No production, shared-cloud, Supabase, Coolify, NAS, database, or Terraform
  mutation is in scope.
- GPT-5.6 must remain explicitly at low or medium reasoning effort.
- Before each commit, `git var GIT_COMMITTER_IDENT` must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Use the existing installers only. Do not hand-edit installed Claude or Codex
  globals or `C:\Users\ahazan2\.codex\config.toml`.
- A bare `bash` on this Windows machine is WSL. Use
  `C:\Program Files\Git\bin\bash.exe` for the Bash test suites.
- The full skill library is not startup context. Keep skill bodies separate from
  name/description manifest measurements.
- Never rewrite root `HANDOFF.md` or edit another session's handoff. This file is
  write-once. A later completing session may delete only the handoff it can prove
  is finished, normally its own.
- Memory sync can move `origin/main` during work. Fetch and rebase a clean,
  focused commit. Never force-push or use destructive reset.

## 8. Access and environment

- Local repo: `C:\repos\ai-devops`.
- Branch and remote: `main`, `https://github.com/u2giants/ai-devops`.
- Completed SHA: `f20ea6b98bc62e9d6b9c434fa3811fb96d2ec981`.
- Machine: Windows 11 development box `al8960ofc`, user `ahazan2`.
- PowerShell 7, Python, Git, Git Bash, and GitHub CLI were sufficient for step 1.
- No secret or 1Password access was used or is expected for step 2. If an
  unrelated need appears, secrets live only in 1Password vault `vibe_coding` and
  values must never enter prompts, logs, commits, or handoffs.
- Generated local evidence is under untracked `.ai/context-audit/`. It is safe to
  regenerate and must not be committed.
- There is no service URL, hosted deploy, container, or GitHub Actions CI for
  this toolkit.

## 9. Open questions and risks

- Step 2 must make rule ownership precise enough that two reviewers can classify
  the same rule the same way. A vague table would allow duplication to return.
- Windows installer documentation is known to have drifted once. Search the two
  usage guides before editing, and test every stated path against
  `bin/setup-machine.ps1` and `bin/install-ai-devops-windows.ps1`.
- The baseline duplicate count is exact normalized text only. It is a review
  aid, not permission to delete or merge content.
- Installed global differences contain machine additions. Do not treat their
  drift entries as a failure or overwrite them during step 2.
- The initial context budgets, shared-global design, application pilot repos,
  and reconciliation design remain deliberately open for later plan steps. Step
  2 should define ownership, not decide later implementations early.

## Mandatory self-audit

1. Yes. Sections 1-3 define the toolkit, goal, exact completed state, commit,
   measurements, verification, and untouched work so a newcomer can start step 2.
2. Yes. Sections 4-5 preserve every failure and non-obvious finding from this
   session, including the stale test, false link, deterministic counting, and
   concurrent push.
3. Yes. Section 6 gives ordered, executable next actions with a verification
   gate for every action. Sections 7-9 preserve constraints, access, risks, and
   deferred decisions.
4. Yes. A line-by-line sweep of sections 1-9 found no sentence needing Albert's
   judgment. Section 0 says so explicitly and lists the decisions already settled
   so the next session does not re-ask them.

All ten required sections are present. The handoff contains no secret values.
The mandatory handoff self-audit passed on 2026-08-12.
