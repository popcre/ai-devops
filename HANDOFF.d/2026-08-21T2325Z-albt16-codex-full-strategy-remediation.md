---
issue: 62
status: OPEN
owner: codex/full-strategy-remediation-62
---

# HANDOFF — complete strategy remediation (2026-08-21 23:25Z, albt16/codex)

Canonical plan: [`../plan_full-strategy-remediation.md`](../plan_full-strategy-remediation.md)

## 0. DECISIONS ONLY THE OWNER CAN MAKE

### Blocking

Four external conditions remain after every in-scope repair and reachable
rollout completed:

- GitHub currently advertises 41 platform-managed `refs/pull/*` that still reach
  the removed objects. Deletion requires GitHub Support. The support submission
  itself requires Albert's action-time confirmation because it is an external
  message.
- Windows machine `916` is offline; Tailscale last saw it on 2026-08-19 and a
  fresh ping timed out on 2026-08-24. Resume only when the machine is online.
- `edge-dev` is online, but fresh checks on 2026-08-24 returned SSH authentication
  denied and DCOM access denied. Resume only with machine-owner access; do not
  weaken authentication or obtain broader credentials to bypass this boundary.
- The unchanged plan gates for Steps 5 and 12 require clean disposable Ubuntu
  and Windows 11 first/second-run restore proofs. Existing-machine reruns do not
  satisfy those gates; provide or authorize suitable disposable environments.

### Recoverable choices already settled — do not re-ask

- 2026-08-21: portable cross-machine Markdown memory moves to a new private
  `u2giants/ai-devops-memory` hub; unattended pushes to the public toolkit stop.
- 2026-08-21: preserve and complete the seven-stage workflow; do not delete it as
  a substitute for repair.
- 2026-08-21: Claude Opus 5 and Codex are the two supported approval adapters over
  one shared lifecycle. Other provider commands remain available but advisory or
  quarantined until their own hostile qualification passes.
- 2026-08-21: keep the existing public GitHub repository and clean it through a
  recoverable coordinated history rewrite rather than creating a replacement.
- 2026-08-21: `hetz` host-level changes go through `u2giants/ansible`; no permanent
  SSH hand edits.
- 2026-08-22: keep every retired memory schedule absent until Albert explicitly
  chooses a future scheduling policy; manual private-hub unions are the safe
  production state.

If a new owner decision appears, present the whole decision set in one message
rather than serial approval prompts. The next session should not redo completed
implementation. It starts with the four external conditions above.

## Current closeout state — authoritative 2026-08-24

- Canonical tested runtime release is
  `8435f7938d9865158975c2a4dbd7e43a3c3bde97`; later closeout-only documentation
  commits do not change that deployment pin. The release replaces the
  pathological hub-by-local memory comparison
  with one-time indexes while preserving duplicate aliases, CRLF, missing final
  newline, and multiple local checkouts. Its 500-by-500 regression passed.
- Hosted source gate `32676734390` is fully green: Linux 7m50s, focused Windows
  reviewer safety 10m38s, and the complete Windows matrix 1h2m29s within its
  75-minute bound. Claude Opus 5 approved the exact source in provider session
  `1deadafa-1bf3-4f5e-8889-190c8d4ca192`.
- `hetz` is clean on `main` at `8435f793...`; its owner-only manifest and
  versioned completion marker match, retired memory cron count is zero, and
  every required `ai-devops doctor` check passed. The checkout is `root:ai`
  mode `0750`: runtime user `ai` can read/run it but cannot write. `/worksp/hiclaw`
  remains `ai:ai` mode `0755`.
- Ansible `origin/main` at `1e5fe45b4cbe3df85e2e85f19e6c7d525938845b`
  pins the release with both predecessor allowlists empty and records the
  historical-transition containment. Exact Claude-approved ownership commit
  `16c614753c40088e7293b02140dcc8266936f906` established the boundary in run
  `32687426166`; exact Claude-approved idempotence commit
  `b474a59864b09f53cd6f629dae07cbd8bb9d3751` passed production runs
  `32689410687` and `32689623813`, each with `changed=0`, `unreachable=0`,
  `failed=0`. Drift run `32689224921` passed Phase 1 and software inventory.
- albt16 and 4837 are clean at `8435f793...`; both live `ai-glm doctor` runs passed
  all required checks. On both machines `ai-memory-sync` is disabled,
  `ai-memory-health` is ready, and no memory-sync lock remains. The formerly
  hours-long T16 sync completed in about two minutes after the repair.
- The 737 stale T16 reviewer sandboxes and 139 matching Claude project-memory
  directories were inspected and moved recoverably to
  `C:\Users\ahazan2\.local\state\ai-devops\cleanup-backups\20260824T0032Z-review-sandbox-debris`;
  nothing was permanently deleted.
- Private `u2giants/ai-devops-memory` is the only memory hub. It is clean and
  synchronized at `dc18be38006f11c8663b4cd7bd0a02f80cdc0dbd` with 940 tracked
  files. A hub-only coverage audit found 840 memory files across 27 projects and
  zero coverage findings. The wider read-only local health scan still reports
  consolidation suggestions; scheduled health reporting owns that non-destructive
  maintenance and no automated deletion is permitted.
- The live seven-stage canary run
  `20260822T160752Z-332946-21980-implement-and-prove-the-disposable-canar`
  completed all stages once. Review stages 2/4/6/7 were `APPROVE`, tests passed,
  and local no-remote commit `598fc4459dbf6b4915a2692ebc65d07147db3d4e`
  contains the exact two-file result.
- Public `main`, visible branches, and tags were rewritten and protected by the
  active `Protect main history` ruleset. The 41 currently advertised hidden pull
  refs are a GitHub-owned external blocker, not an unperformed local rewrite.
- Production reflog evidence records repeated historical checkout movement
  outside governed Ansible dispatches, most recently an intervening local
  `32fe573` commit and `pull --ff-only` to `8435f793`. Direct non-sudo recurrence
  is contained by governed ownership. The actor remains unknown and is explicitly
  open in Ansible; do not infer attribution from reflog alone.
- Step 7's full archive rollback proof is committed at
  `tests/verification/full-remediation/20260824T022652Z/step-07-archive-rollback.md`.
  Steps 5 and 12 remain verifying because their exact clean-disposable restore
  gates have not been run.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public GitHub backup-and-restore toolkit
for Claude, Codex, delegated reviewers, skills, machine configuration, and
portable AI memory. It contains scripts and documentation, not a hosted app.
Deployment means committing verified source to `main`, enforcing it on GitHub,
installing the exact revision on managed Windows/Ubuntu machines, and proving
restore/capability.

## 2. What we set out to do this session, and why

Albert first requested a deep audit, then asked Codex to debate the conclusions
with Claude Opus 5, and finally authorized a revised implementation plan plus
complete production execution. The audit found a live four-machine memory-index
oscillation, public transcript history, false-success restore/reviewer paths,
missing enforcement, an unfinished seven-stage workflow, and context/privacy/
reproducibility weaknesses.

The immediate objective of this session is to publish a zero-context-safe plan
for all 30 negotiated findings, then execute its incident-first phases without
losing concurrent work.

## 3. Original start snapshot — historical, superseded above

- GitHub issue #62 is open and tracks the full remediation.
- The canonical plan exists at `plan_full-strategy-remediation.md`; its STATUS
  table is authoritative and must be updated whenever work lands.
- The plan was drafted from clean local `main` synchronized at
  `3ca5b2b1846fad03e4f0d251e22142ca043dee84`. Scheduled memory jobs can advance
  remote `main`; re-fetch before acting.
- No memory job has yet been disabled by this session. No production machine,
  config, provider wrapper, history, or GitHub rule has yet changed.
- Existing open handoffs own separate Gemini/Grok/provider work. Read their plan
  STATUS tables and import verified work; never edit their handoff files.
- Claude Code authentication was restored and a live JSON probe identified the
  canonical model as `claude-opus-5`.
- The initial audit in `bugs.md` is committed but still contains pre-debate
  counts/remedies; Step 0 corrects it.

Commit/push/deploy state: this new plan/handoff are uncommitted at the moment this
handoff is created. Production remains unchanged.

## 4. Everything we tried that did NOT work

1. The first Claude invocation failed because the local OAuth session had
   expired. Normal `claude auth login` restored it; do not repurpose the
   separately named shared-db API credential.
2. Claude initially called 2,094 matching history objects “blobs.” Object-type
   verification proved 1,464 blobs plus 630 trees; Claude conceded. Preserve the
   corrected classes in all public reporting.
3. Codex's initial 44,700-byte installed-global number did not reproduce. Current
   files total 21,808 bytes; the qualitative undercount remains but severity is
   MEDIUM.
4. The initial audit proposed adding secret scanning, but GitHub already has
   secret scanning and push protection. The missing enforcement is CI plus
   force-push/branch-deletion protection.
5. Treating the memory defect as a latent “orphan count” missed its cadence and
   content. Git history proves a repeating four-machine loop that periodically
   removes safety-control index entries; treat it as an active incident.
6. Fixing every reviewer independently would preserve the duplication root cause.
   The plan keeps provider capabilities but centralizes approval lifecycle and
   limits supported approval paths to Claude/Codex.

## 5. Root causes and key findings

- `bin/ai-sync-memory` warns an index will shrink and copies it anyway;
  `bin/ai-memory-sync` pushes before reconciliation and can hard-reset the only
  failed-push commit. The existing test positively requires that reset line.
- Four automatic writers (`albt16`, `edge-dev`, `al8960ofc`, `hetz`) have repeated
  the destructive index cycle about every 30 minutes.
- Public `origin/main` reaches 1,464 transcript blobs (870 `.jsonl`) and about
  1.2 GB uncompressed despite documentation claiming full removal.
- The repo's core failure pattern is rules without gates: no full-suite command,
  no GitHub workflow, no branch rules, and reviewer governance not called by
  provider wrappers.
- The plan's §6 and finding-to-step table contain the full root-cause/coverage
  record. Existing provider plans retain stricter provider-specific constraints.

## 6. Exact next steps

1. On clean disposable Ubuntu, run the canonical restore twice and capture
   non-secret source/config/doctor reports. **Worked when:** the first run reaches
   compliance and the unchanged second run has no unintended changes at exact
   `8435f793...`.
2. On clean disposable Windows 11, run the canonical bootstrap, honor any reboot,
   then rerun unchanged and capture the same evidence. **Worked when:** both runs
   identify exact source/config schema and the second has no unintended changes.
3. With Albert's action-time confirmation, send GitHub Support the prepared
   request to delete/garbage-collect the 41 currently advertised hidden pull
   refs. **Worked when:** a fresh unauthenticated mirror no longer receives old
   objects.
4. When 916 is online, fast-forward/install `8435f793...`, keep the memory writer
   disabled, run the required doctors, and record SHA/clean state. **Worked when:**
   the machine has exact source and clean required checks.
5. Obtain machine-owner access to edge-dev, then perform the same exact rollout.
   Do not bypass SSH authentication or DCOM authority. **Worked when:** exact
   source, disabled writer, ready health task, no lock, and green doctor are proven.
6. Close issue #62 and retire this handoff only after Steps 5, 12, and 15-17 are genuinely
   complete. Do not mark the goal complete merely because external access is
   unavailable.

## 7. Constraints and gotchas in force

- Direct-to-`main`; fetch/reconcile frequently; stage only owned files/hunks.
- Verify Albert's Git committer identity before every commit.
- Raw transcripts are forbidden context. Secrets never appear in chat, command
  arguments, logs, Git, or this handoff.
- Every destructive operation has a verified recovery copy first. History rewrite
  happens in an isolated mirror after all writers are frozen.
- Reviewer safety changes require independent exact-head review.
- Preserve capabilities; advisory/quarantine is not deletion.
- Windows Bash suites use Git Bash, not WSL. Do not replace OS binaries.
- `hetz` host state routes through Ansible; no Terraform/mutating production
  `gcloud` or shared-database work is authorized.

## 8. Access and environment

- Checkout: `C:\repos\ai-devops`; target: `u2giants/ai-devops` `main`.
- GitHub CLI authenticated as `u2giants`; issue #62 exists.
- Current machine: `albt16`, Windows 11, user `ahazan2`, PowerShell 7.
- Git Bash: `C:\Program Files\Git\bin\bash.exe`.
- Claude Code 2.1.211 authenticated through the normal Claude account; verified
  canonical model `claude-opus-5`.
- Secrets live in 1Password vault `vibe_coding`; use documented item titles only.
- Managed hosts observed: `albt16`, `edge-dev`, `al8960ofc`, `hetz`. Resolve
  access through managed SSH/Ansible inventory, never copied credentials.

## 9. Open questions and risks

The four owner/external conditions in §0 are open. All provider, source,
production-server, reachable-Windows, CI, ruleset, canary, and Step 7 archive
recoverability work is complete. Clean-disposable restore proof is not complete.
None of the remaining conditions authorizes a weaker success definition, an
authentication/history-retention bypass, or substituting existing-machine proof
for a clean-machine gate.

Rollback risks and procedures are in plan §13. The largest risks are memory loss,
old-history contamination after rewrite, and concurrent `main` movement. The plan
requires protected copies, fresh clones, and exact-head checks for each.

## Handoff self-audit — passed 2026-08-24

1. **Can a brand-new developer continue without asking a question? — Yes.** §§1–3
   explain the system, objective, exact current release/deployment state; §6 names
   the restart sequence and unchanged verification gates; the canonical plan
   supplies all 17 steps.
2. **Can they continue as effectively as this session? — Yes.** §§4–5 preserve
   failed approaches, corrections, cadence, counts, root causes, production run
   IDs, and the remaining clean-disposable gap; §§7–8 carry every operating and
   environment constraint.
3. **Is every needed detail present? — Yes.** Background/goals (§§1–2), current
   state (§3), failed attempts (§4), findings (§5), actions (§6), constraints (§7),
   access (§8), risks/decisions (§§0,9), and reciprocal plan link are present.
4. **Would Albert see every decision by reading only §0? — Yes.** A line-by-line
   sweep of §§1–9 found the four remaining external conditions and every settled
   architecture choice represented in §0. The one-message delivery instruction
   prevents serial approval prompts; “do not re-ask” wording protects locked
   decisions.
