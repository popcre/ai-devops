# Handoff: context-engineering step 4 — the two always-loaded globals are slimmed

- **Machine:** `al8960ofc` (Windows 11, user `ahazan2`, PowerShell 7 primary)
- **Agent:** Claude (Opus 5) in Claude Code
- **Repo:** `u2giants/ai-devops`, worked in the worktree
  `C:\repos\ai-devops-worktrees\context-engineering-consolidation-d3d183` on
  branch `claude/context-engineering-consolidation-d3d183`
- **Status:** step 4 source work is complete, committed, and pushed. Two named
  step-4 gates are deliberately deferred and recorded in the plan.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public backup-and-restore toolkit for his
multi-model AI coding workflow. Albert is a business owner, not a programmer;
this repo is the durable memory of his "engineering department". It is 100%
owned Bash, PowerShell, Python, and Markdown. There is no app, database,
container, hosted service, or CI. Nothing here is deployed.

What it holds:

- `templates/system/CLAUDE-global.md` — the file installed as the user-level
  `~/.claude/CLAUDE.md` on every machine. Claude Code loads it at the start of
  every session in every repo.
- `templates/system/AGENTS-global-codex.md` — the Codex equivalent, installed as
  `~/.codex/AGENTS.md`.
- `AGENTS.md` — this repo's own router, read at session start inside this repo.
- `skills/shared/`, `skills/claude/`, `skills/codex/` — procedures loaded only
  when a task triggers them.
- `docs/`, `templates/system/`, `bin/`, `tests/`, `tools/`.

Those two global templates are the "always-loaded" context class: every session
on every machine pays for every byte in them, whatever the task.

## 2. What we set out to do this session, and why

Execute **step 4** of
[`plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md):
slim the always-loaded global files.

Business reason: sessions were starting with roughly 8,300 estimated tokens of
standing instruction before reading a single line of the actual repo, and much
of that was detailed procedure that only matters for one kind of task. The plan's
stated goal is the smallest *high-signal* context, not the smallest file, and
safety is an acceptance requirement, not a trade.

Steps 1-3 (baseline, ownership map, enforcement tooling) were already done by
earlier sessions. Enforcement came first on purpose so that step 4 could not
quietly delete a safety rule.

## 3. Current state

**Done and pushed.**

- `templates/system/CLAUDE-global.md`: 17,053 → 12,933 bytes.
- `templates/system/AGENTS-global-codex.md`: 16,258 → 12,831 bytes.
- Always-loaded class: **33,311 → 25,764 bytes, a 22.7% cut**
  (about 8,329 → about 6,442 estimated tokens).
- `tools/context-audit/budgets.json` and the `DEFAULT_BUDGETS` fallback in
  `tools/context-audit/context-audit.py` both ratcheted: `alwaysLoadedBytes`
  budget 33,311 → 25,764. The `target` stays 23,318. No budget was raised.
- `docs/context-engineering.md`: new **"Where the removed global detail now
  lives"** table (the audit trail of every moved passage), a ratchet note, and a
  corrected baseline row and budget row.
- `plan_context-engineering-consolidation.md`: STATUS row 4 updated, a step-4
  drift block added at the top, and a completion note added to the step 4
  section.

**Verified green on 2026-08-12:**

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
mismatches, zero stale divergence-allowlist entries, and zero
global-versus-skill-description overlaps.

**Not done, and why (both are recorded as drift in the plan):**

1. **Live client probes.** Step 4's gate says a representative Claude and Codex
   session must answer safety and routing probes correctly. That requires the
   trimmed globals to be *installed*, and the plan forbids installing before the
   step 8 pilot. Step 8 must run those probes against these globals and roll
   back on any failure. Step 4 is not fully closed until it does.
2. **The stale Codex "no skills system" sentence** near line 43 of
   `templates/system/AGENTS-global-codex.md`, and the ritual summaries under it,
   are untouched. The plan gates that correction on Codex skill-loading and
   trigger evidence, and no Codex eval set exists yet. Step 6 owns it.

**Nothing was installed on this machine.** The installed
`C:\Users\ahazan2\.claude\CLAUDE.md` and `C:\Users\ahazan2\.codex\AGENTS.md`
still hold the old text plus local machine additions. That is correct and
intentional.

## 4. Everything we tried that did NOT work

- **Chasing the 23,318-byte target by shaving more prose. Abandoned on
  purpose.** After moving every genuinely relocatable passage, the only material
  left is the response-style contract (identical in both globals, governs every
  single turn) and the Codex ritual summaries (gated by trigger evidence).
  Cutting either would trade behavior quality for a number, which section 1 of
  the plan explicitly forbids. The gap is documented rather than closed. **Do not
  "finish the job" by trimming safety or style prose.**
- **Pointing the Codex global at Codex skills as the destination for removed
  handoff detail. Rejected.** That would have leaned on the very assumption
  (Codex skill triggering) the plan gates behind evidence. Every Codex pointer
  therefore names a **file path** (`templates/system/handoff-standard.md`) that
  Codex can open unconditionally, not a skill name alone.
- **Relying on the audit's broken-link check to protect the new pointers. It does
  not.** The pointers are backticked prose paths, not Markdown links, so the
  link checker never sees them. All nine were verified by hand instead. See the
  gotcha in section 7.
- One stray non-ASCII character ("步") was typed into the Codex global mid-edit
  and immediately corrected. Worth knowing only because the repo's PowerShell
  files must stay pure ASCII; grep for non-ASCII if anything downstream behaves
  oddly.

## 5. Root causes and key findings

- The two globals were large not because the rules are many, but because each
  rule carried its **full procedure and its incident narrative** inline. The
  ownership map from step 2 already named a canonical owner for every one of
  those procedures; the text was simply never moved.
- The single largest block anywhere in either global was the Codex "HANDOFF
  quality standard" section (about 4,300 bytes), which restated
  `templates/system/handoff-standard.md` — a 19,327-byte document that already
  says all of it, better. That one substitution is roughly half the total saving.
- Safety-marker checks in `tools/context-audit/context-audit.py:26-62` run over
  **all** classified files, not just the globals, so they are a weak gate on
  global edits specifically. The **parity** rules at `:66-77` are the real gate:
  they assert ten rules appear in *both* globals, which is what stops a one-sided
  deletion. Keep that in mind when editing either global.
- `installed source drift` now reports 0 on this machine. The four drifted
  skills recorded in the plan's section 5 baseline are gone. Step 7 should
  re-measure rather than assume those four are still drifted.

## 6. Exact next steps

1. **Start step 5: tighten `AGENTS.md` as a router.** Measure against the
   *current* number, **50,729 bytes** for `AGENTS.md` + `CLAUDE.md`, not the
   50,486 in `budgets.json` and not the 49,401 in the section-5 baseline. It is
   already 243 bytes over its warning budget.
   *You will know it worked when* `python tools/context-audit/context-audit.py
   --root . --strict` exits 0, `startupRoutedBytes` falls, and you have ratcheted
   that budget in `tools/context-audit/budgets.json`, in `DEFAULT_BUDGETS` in
   `tools/context-audit/context-audit.py`, and in the budget table in
   `docs/context-engineering.md`. All three, or the numbers disagree.
2. **Use the same method that worked here:** for each long block, find its
   canonical owner in the ownership map in `docs/context-engineering.md`, leave
   the *rule* in place, replace the *procedure* with a pointer that says exactly
   when to open the owner, and add a row to the "Where the removed global detail
   now lives" table (rename it if step 5 starts covering the router too).
3. **Re-run every suite in `docs/development.md` plus
   `tests/test-windows-scripts.sh`** after each trim, not only at the end.
4. **Do not delegate any of this to `ai-glm implement`** until the GLM permission
   bug is fixed (plan section 11; it killed step 2 mid-edit after GLM had already
   changed three files).
5. **Merge this branch to `main` when convenient.** The work is pushed on
   `claude/context-engineering-consolidation-d3d183`. Albert's standing rule is
   main-only for `u2giants` app repos; this branch exists only because the
   session ran in a worktree.

## 7. Constraints and gotchas in force

- **Never raise a budget to silence a warning.** Ratchet down only after a
  measured reduction lands and its tests pass.
- **Never delete a rule from only one client global.** Ten parity rules must
  appear in both, or the rule needs an entry in
  `PARITY_DIVERGENCE_ALLOWLIST` in `tools/context-audit/context-audit.py` with a
  stated reason. `--strict` fails on a stale allowlist entry too.
- **The new pointers are not link-checked.** If any later step renames
  `templates/system/handoff-standard.md`,
  `docs/cloud-build-prod-trigger-incident-2026-07-20.md`,
  `docs/future-visual-testing.md`, `bin/ai-git-identity`, or the
  `synology-long-running-operations`, `shared-db-change`,
  `codex-shared-db-change`, or `handoff-writer` skills, it must update both
  globals in the same commit. Teaching the audit to validate backticked paths
  inside the globals is a good step-5 or step-10 addition.
- Budgets warn only. They never fail a run, even under `--strict`.
- Commit identity must read
  `Albert Hazan <u2giants@users.noreply.github.com>`; verified this session.
- `.ai/` and `docs/claude-remote-control-hardening-v2.md` are unrelated
  untracked work in the primary checkout `C:\repos\ai-devops`. Leave them alone.
- **`HANDOFF.d/` now holds 8 open files, above the 5-file warning line.** Several
  are step-1/step-2 context-engineering files whose work is now proven done. The
  owning session must delete its own; nobody may delete another session's.

## 8. Access and environment

- Everything needed was local. No credential, secret, 1Password read, cloud call,
  or network access was required, and none was made.
- Tools used: `git`, `python`, `bash`, `pwsh`. All present on `al8960ofc`.
- Primary checkout `C:\repos\ai-devops`; this work happened in the worktree
  `C:\repos\ai-devops-worktrees\context-engineering-consolidation-d3d183`.
- No production, cloud, Supabase, NAS, or database resource was touched or read.

## 9. Open questions and risks

- **Risk: a pointer is never followed.** The whole design assumes an agent reads
  `templates/system/handoff-standard.md` when told to. That is exactly what the
  step 8 pilot probes must test. If a probe shows an agent writing a
  three-section handoff because the detail left the global, restore that block
  and record it. This is the single most likely failure mode of step 4.
- **Risk: the Codex global still contains a false statement** ("Codex has no
  skills system") while its ritual summaries duplicate the live skill catalog.
  Known, gated, owned by step 6. Nobody should "fix" it without the eval sets.
- **Open question: what should the final always-loaded budget be?** 23,318 was a
  guess in step 3 (a flat 30% cut), not a measurement. Step 10 sets the real one
  from pilot evidence. Do not treat 23,318 as a requirement.
- **Decision made 2026-08-12:** stop at 22.7% rather than gut the response-style
  contract. Rationale in section 4. Reopen only with measured evidence that the
  style block is not earning its bytes.
