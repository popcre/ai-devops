---
issue: 56
status: OPEN
owner: edge-dev/codex/grok-review-repair-plan
---

# HANDOFF — Grok review concurrency, cancellation, and observability repair plan

Implementation plan: [`../plan_grok-review-concurrency-cancellation-observability.md`](../plan_grok-review-concurrency-cancellation-observability.md)

## 0. Decisions only the owner can make

### Blocking

None. The plan makes safe evidence-based choices and requires no purchase, production action, credential rotation, or policy change.

### Recoverable

None.

### Not part of this work, and nobody is on it

- The repository has 13 older open handoffs. That exceeds the safe limit of five. This session did not edit or retire another session's file.

### Already settled — do not re-ask

- Fix all four issue-56 behaviors: clone-proof serialization, cross-clone visibility, truthful cancellation/interruption, and mid-turn progress.
- Also fix the incident recorder's proven wrong-run attachment behavior because both #56 packages captured unrelated metadata.
- Keep every Grok safety control: read-only permissions, terminal `stopReason`, fixed model, bounded turns, exact-session reuse, private review copies, and packet hashes.

## 1. What this application is

`u2giants/ai-devops` is Albert's public toolkit for installing and operating AI coding reviewers. It is Bash, PowerShell, tests, and documentation, not a hosted application. `bin/ai-grok-review` runs paid read-only Grok reviews; `bin/ai-reviewer-issue` captures local diagnostic records when reviewers misbehave.

## 2. What this session set out to do

Albert asked Codex to read ai-devops issue #56 and the reviewer logs, then use the implementation-plan-writer skill to write a complete repair plan. This session investigated the live GitHub issue, the two local evidence folders, current Grok state, source code, tests, protected design rules, and earlier reviewer plans. It wrote the linked implementation plan; it did not implement the fix.

## 3. Current state

- Plan: `plan_grok-review-concurrency-cancellation-observability.md`.
- GitHub issue: `https://github.com/u2giants/ai-devops/issues/56`, OPEN with no comments when read on 2026-08-20.
- GitHub source at planning time: fetched `origin/main` `c7f0b83b0b0c2959184e5d4f4a370c38a9a34e9d`.
- Local checkout at planning time: `main` `12b0f0e84980eb6df9f6363045964c45c1ae9888`, behind GitHub and dirty with another session's `.gitignore` and memory edits. Do not pull/reset over them.
- No implementation, test, installed-wrapper, production, or deployment change was made.
- No Grok repository locks were active when checked after the incident.
- Both incident packages attached `review-1320-supersede` metadata even though the affected progress run was `review-1335-restore`; both captured-provider-log inventories were empty; their scoreboard/report attachments were unrelated older evidence.

## 4. Everything tried that did not work

1. The old wrapper used checkout path plus remote as one identity for both session records and the paid-review lock. It worked within one checkout but separate clones bypassed it.
2. Clones were introduced to prevent evidence packets from colliding. That fixed wrong-commit evidence but defeated the path-scoped lock. Banning clones would restore the earlier defect.
3. Two local processes were killed after wrong-commit reviews started. This did not prove their provider turns stopped and may have left billed work running.
4. The recorder's “latest Grok JSON” capture attached the most recent unrelated completed session rather than the named affected run. Recency is not valid evidence correlation.
5. The wrapper's process id and lock proved only local ownership, not provider health or progress. The caller could not distinguish a long healthy turn from a stuck one.

## 5. Root causes and key findings

- Session identity and cost-lock identity have different jobs. Preserve path-bound session storage; add a separate normalized upstream repository lock.
- GitHub HTTPS, SSH, `.git`, case, and local-path clone origins must resolve to one canonical upstream identity.
- Local process stopping and provider cancellation are separate facts; never claim the second from the first.
- Plain JSON provides reliable final information only. The safe default progress design is a factual elapsed-time heartbeat unless installed-version evidence proves streaming events safe.
- Incident capture needs an explicit session/repository/caller join key. Missing evidence must be labelled, never replaced by the newest item.

## 6. Exact next steps

1. Open the linked plan and read its STATUS table, then all sections. **You'll know it worked when:** the implementer can state that Step 1 is the first open row and no repair is claimed complete.
2. Reconcile from fetched GitHub `main` without touching the dirty checkout; use a clean clone if necessary. **You'll know it worked when:** the baseline artifact records the exact base and excluded concurrent files.
3. Execute Phases A–F in order, updating the plan after each phase and re-reading downstream phases for drift. **You'll know it worked when:** every completed STATUS row cites an openable artifact.
4. Close issue #56 and remove this handoff only after the installed live canary, exact-head review, GitHub push, and all definition-of-done checks pass. **You'll know it worked when:** #56 is closed with evidence and no handoff claims unfinished work.

## 7. Constraints and gotchas

- Never broaden Grok permissions, remove `--max-turns`, trust exit status as completion, add arbitrary flags, restore `--worktree`, or use automatic permission mode.
- Preserve private session-specific snapshots and exact-head evidence.
- Do not read `~/.grok/auth.json` or put secrets in test evidence.
- Do not edit another session's handoff or dirty memory files. Never use broad staging or force-push.
- This repo has no CI, deployment, database, or production service.
- GPT-5.6 stays at low or medium reasoning effort.

## 8. Access and environment

- Machine: `edge-dev`, Windows; PowerShell primary, Git Bash for Bash scripts.
- Repo: `C:\repos\ai-devops`; GitHub `u2giants/ai-devops`; target `main`.
- `gh` is authenticated. Git identity was correct at planning time and must be rechecked before commit.
- Grok authentication exists in private CLI state. Tests must use temporary state and stubs; one bounded live qualification occurs only near delivery.
- No 1Password secret, server, database, or cloud access is required.

## 9. Open questions and risks

- Installed Grok may or may not expose a confirmable remote abort. The plan defines the evidence gate and safe warning-only fallback.
- Streaming output may not preserve the current terminal contract. The elapsed-time heartbeat is the default unless proved otherwise.
- Historical evidence may lack enough fields for exact correlation. The recorder must report absence rather than infer.
- A malformed global lock may temporarily block a review. That is safer than silently allowing a second paid turn.

## Mandatory self-audit

1. A new developer can continue without questions: Sections 1–3 define the product, request, issue, SHAs, dirty checkout, and evidence defect; Section 6 links the exhaustive build plan and gives ordered gates.
2. The handoff preserves failed approaches and hard-won findings: Sections 4–5 cover clones, local kills, recorder correlation, and the identity split.
3. Every next step is concrete and verifiable: all four items in Section 6 end with a success condition.
4. Commit/push/deploy state is explicit: Section 3 says implementation is untouched; Section 6 requires push and issue closure; Section 7 states there is no deployment.
5. Secrets and owner decisions are handled: Section 0 has no owner decision; Sections 7–8 name protected locations without values.

Self-audit passed on 2026-08-20.
