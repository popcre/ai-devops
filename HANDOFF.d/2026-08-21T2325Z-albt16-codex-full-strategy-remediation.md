---
issue: 62
status: OPEN
owner: codex/full-strategy-remediation-62
---

# HANDOFF — complete strategy remediation (2026-08-21 23:25Z, albt16/codex)

Canonical plan: [`../plan_full-strategy-remediation.md`](../plan_full-strategy-remediation.md)

## 0. DECISIONS ONLY THE OWNER CAN MAKE

### Blocking

None. Albert explicitly authorized rewriting the full plan, implementing every
negotiated fix, and carrying the result through production. Do not pause to ask
whether to begin or whether to perform ordinary reversible steps.

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

The next session must present this whole section in one message only if a new
owner decision appears. There are currently none.

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

## 3. Current state — what is true right now

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

1. Self-audit and commit/push the plan, this handoff, corrected `bugs.md`, and
   router links. **Worked when:** issue #62 links to a commit on `origin/main` and
   Step 0 cites it.
2. Execute Step 1 incident containment on all four writers before any long code
   phase. **Worked when:** two schedule intervals pass with no new automatic
   memory commit and protected evidence names every host/task.
3. Continue from the first open STATUS row in the plan. Re-read downstream phases
   before each phase and update the plan in the same session. **Worked when:** no
   completed work is described as open and every done cell cites an artifact.
4. Never delete this handoff merely because a phase completed. Retire it only
   with Step 17 after final CI, install, history, exact-head review, and issue #62
   are all complete. **Worked when:** Git history retains this handoff while the
   live tree has no open workstream file.

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

No owner decision is open. Technical uncertainties are governed by plan gates:
provider qualification may leave a provider advisory; a sensitive-memory scan may
escalate the public-memory finding; history rewrite pauses if any writer or unknown
ref remains; Windows may require reboot/application shutdown. None authorizes a
weaker success definition.

Rollback risks and procedures are in plan §13. The largest risks are memory loss,
old-history contamination after rewrite, and concurrent `main` movement. The plan
requires protected copies, fresh clones, and exact-head checks for each.

## Handoff self-audit — passed 2026-08-21

1. **Can a brand-new developer continue without asking a question? — Yes.** §§1–3
   explain the system, objective, exact current commit/state; §6 names the restart
   sequence and verification gates; the canonical plan supplies all 17 steps.
2. **Can they continue as effectively as this session? — Yes.** §§4–5 preserve
   failed approaches, corrections, cadence, counts, and root causes; §§7–8 carry
   every operating/environment constraint.
3. **Is every needed detail present? — Yes.** Background/goals (§§1–2), current
   state (§3), failed attempts (§4), findings (§5), actions (§6), constraints (§7),
   access (§8), risks/decisions (§§0,9), and reciprocal plan link are present.
4. **Would Albert see every decision by reading only §0? — Yes.** A line-by-line
   sweep of §§1–9 found no unresolved owner choice. All settled architecture choices
   that otherwise appear in §§5–9 are consolidated in §0 with dates and “do not
   re-ask” wording.
