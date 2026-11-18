---
issue: 2607
status: OPEN
owner: codex/muse-reviewer-closeout
---

# HANDOFF — Muse reviewer and standalone release

## 0. Business decisions only the owner can make

Albert said “i don't want 2 muse installations.” Both reviewer roles already share one Muse Spark connection. The remaining choice, if it affects his use, is whether the separate standalone Muse Code app is a capability he wants to retain or the one entry point he wants both reviewers to use. No instruction to uninstall it was given. There is no technical approval to request.

## 1. What this application is

[AI DevOps](https://github.com/popcre/ai-devops) runs advisory code reviews on GitHub and on-demand second opinions. Both current routes use Muse Spark through OpenCode. Muse Code is Meta's separate terminal app.

## 2. What we set out to do and why

Verify the installed Linux Muse Code pin, keep the active version from updating itself, and prove Muse reviews in both roles. Keep the owner’s single-installation preference visible.

## 3. Current state

[PR #2605](https://github.com/popcre/ai-devops/pull/2605) merged the [Linux x86_64 pin](https://github.com/popcre/ai-devops/tree/main/config/muse-code/linux-x86_64) for 1.4.23-R8977.1. Its binary on hetz matched Meta’s stable manifest SHA-256 and 466999640-byte size. The local launcher forces MUSE_NO_AUTO_UPDATE=1. A forced update request left the update timestamp unchanged, and the Linux installer verification passed against the real binary. The installed toolkit checkout was behind upstream and was deliberately not advanced through unrelated changes.

[GitHub PR #2600](https://github.com/popcre/ai-devops/pull/2600#issuecomment-6962391904) recorded a genuine Muse APPROVE with specific findings at 5:08 PM EST on November 17. On hetz the live second-opinion readiness check returned READY. A second live call reviewed a synthetic age eligibility change, identified that age 18 was wrongly excluded, and returned REVISE.

## 4. Attempts that failed

The first plain version probe triggered Meta’s launcher to update the standalone app and remove its older binaries, including the former pin. The current launcher guard prevents recurrence on hetz. No live reviewer test can prove 1.4.23 on the supported reviewer routes because those routes do not invoke the app.

## 5. Root causes and findings

[The installed entry point](https://github.com/popcre/ai-devops/blob/main/bin/ai-muse) delegates to [the second-opinion runner](https://github.com/popcre/ai-devops/blob/main/bin/ai-second-opinion). [GitHub’s review workflow](https://github.com/popcre/ai-devops/blob/main/.github/workflows/ai-review.yml) uses the same Muse Spark service. References describing native Muse Code as the current reviewer are stale. [Issue #2607](https://github.com/popcre/ai-devops/issues/2607) already tracks documentation and pin-proof follow-up.

## 6. Exact next steps

Check current issue ownership before editing. Verify whether the issue’s documentation and pin-proof work has already landed. If outstanding, correct the reviewer description using the live checks above. Recheck the installed pin during the next supported toolkit update and verify the local Muse launcher still reports 1.4.23 with automatic updates disabled. If consolidation changes either reviewer, require a substantive exact-revision GitHub verdict and an end-to-end second opinion before removing or switching any path.

## 7. Constraints

Keep the advisory GitHub and second-opinion functions working. Preserve the existing [candidate-route rollout hold](https://github.com/popcre/ai-devops/issues/2531). Keep the Windows pin independent. Do not advance hetz via a plain pull or replace Meta’s launcher indiscriminately.

## 8. Access and environment

The standalone version and local second opinion were verified on hetz. GitHub runner proof is public in the exact pull request comment above. No credentials are needed to read this evidence. No shared database work or claims. The two investigation subagents finished.

## 9. Risks

A future standalone reinstall can replace the local launcher guard. A toolkit pin release alone does not change either reviewer’s engine. The owner’s underlying consolidation choice remains as described in section 0.

## Self-audit

1. Fresh-reader execution: yes, sections 1–3 and 6 name the goal, starting evidence, and actions.
2. Equivalent context: yes, sections 3–5 and 7–9 record the observed paths, limits, and custody.
3. Failed attempts: yes, section 4 distinguishes the accidental update and native-review limitation.
4. Actions and checks: yes, section 6 ties each remaining action to observable evidence.
5. Identifiers explained: yes, sections 1, 3, and 5 distinguish the app, service, and roles.
6. Portable references: yes, linked repository files, pull requests, and issues use GitHub URLs.
7. Owner sweep: yes, the only owner choice found in sections 1–9 is standalone retention or consolidation, captured in section 0.

Synthesis: A new developer can continue using sections 1–6. They have the same known evidence and modes of failure in sections 3–5. Scope, constraints, risks, and acceptance are covered in sections 2 and 6–9. Section 0 contains the single business choice and leaves technical approval out. Optional fresh-reader check skipped.
