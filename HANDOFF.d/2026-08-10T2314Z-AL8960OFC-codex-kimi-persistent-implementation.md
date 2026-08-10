# Handoff: implement persistent Kimi implementation sessions

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public backup and restore toolkit for his
multi-model AI workflow. `bin/ai-kimi` is its supported Kimi Code wrapper. The repo uses
`main` and has no hosted service, database, CI, or deployment.

## 2. What we set out to do, and why

Albert rejected one-shot Kimi implementation. Later write runs lose the prior paid
reasoning. The goal is an exact persistent implementation conversation with exact code
continuity, while keeping disposable workspaces and manual patch review.

The complete brief is
[`../plan_kimi-persistent-implementation-sessions.md`](../plan_kimi-persistent-implementation-sessions.md).
Read it in full and start at its first open STATUS row.

## 3. Current state

- Planned base: `52704f98549e23044e53da4c9190e48ca59e2757`, equal to `origin/main`.
- Reviews persist by exact ID; implementations are rejected by `ask` at
  `bin/ai-kimi:808-810`.
- Complete and failed-partial runs safely export patches and remove normal worktrees.
- No implementation code for persistence has started.
- Unrelated `.ai/` and `docs/claude-remote-control-hardening-v2.md` must remain untouched.

## 4. Everything tried that did not work

No code attempt was made. The plan rejects permanent worktrees, resume without files,
transcript-pasting, newest-by-directory continuation, real-repo application, silent
rebasing, patch chains, and guessed migration. Plan section 7 explains why.

## 5. Root causes and key findings

- Exact-ID transport exists but implementation resume is blocked by policy.
- Conversation memory is not enough; each workspace needs complete earlier code.
- Use immutable base plus one cumulative binary patch in a fresh worktree per turn.
- Cross-directory and failed-turn resume must be measured on Kimi 0.32.0 first.

## 6. Exact next steps

1. Read the plan and routed Kimi files. Gate: understand locked decisions and measurements.
2. Run Phase 1 before production edits. Gate: exact conversation and file continuity work
   across disposable paths.
3. Follow phases 2-5, updating STATUS and current state after every gate.
4. Verify identity, commit, push, and prove `HEAD == origin/main`. Delete only this handoff
   after every plan row is complete.

## 7. Constraints and gotchas

- Exact ID only; reviews and implementation remain separate.
- Successful turns require `session.resume_hint`.
- No persistent normal worktree and no auto-apply.
- Preserve incomplete recovery, locks, atomic writes, secret safety, Git Bash, and
  unrelated concurrent files.

## 8. Access and environment

- `C:\repos\ai-devops`, `main`, `https://github.com/u2giants/ai-devops`.
- Windows `AL8960OFC`; PowerShell 7 plus Git Bash; Kimi Code 0.32.0.
- Kimi OAuth is under `~/.kimi-code`; never expose it. Other secrets stay in 1Password
  account `popcreations.1password.com`, vault `vibe_coding`.

## 9. Open questions and risks

- Can exact ID resume safely in a different reconstructed worktree?
- Which failure classes preserve a safely resumable conversation?
- Phase 1 must answer both. If proof fails, preserve code and require a visible new-session
  recovery instead of pretending continuity.

## Mandatory self-audit

1. Yes. The linked plan has all 13 sections, steps, tests, gates, files, and decisions.
2. Yes. Sections 3-5 preserve current state, rejected paths, root cause, and architecture.
3. Yes. Sections 6-9 give steps, constraints, access, risks, and proof rules. Links are
   bidirectional.

Self-audit passed on 2026-08-10.
