---
issue: 894
status: BLOCKED
owner: codex/typesafe-wrapup-handoff
---

# HANDOFF — TypeSafe Windows proof (2026-09-28 11:38 AM UTC, edge-dev3/Codex)

## 0. Decisions only Albert can make

- **Blocking, issue #894:** Albert needs to check the signed-in ChatGPT Windows desktop skill picker for `@TypeSafe` and report whether it appears. Recommend opening the desktop prompt, typing `@TypeSafe`, and reporting the exact visible result or a screenshot. The Start-menu package name and installed files are insufficient proof.
- **Blocking, issue #894:** Albert needs to authenticate MiMoCode on edge-dev through its normal interactive sign-in, then make a desktop prompt use `typesafe-ai`. Recommend asking it to read the skill's first paragraph and identify the model; success says `Jev`. The headless CLI currently reports `Not logged in` / `Invalid API Key`.
- **No ruling requested for issue #919:** A separate Windows maintenance session owns the state-directory repair. It must coordinate a safe quiet window before touching the live state. Albert should be asked only if that session cannot arrange the maintenance window through the existing process.
- **Already settled:** Albert asked for explicit invocation with minimal context, confirmed “acode” means ZCode, provided the edge-dev SSH host fingerprint, and asked this session to wrap up. Do not re-ask these choices.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's public recovery and machine setup toolkit for his AI coding clients. It installs skills and client configuration on Windows; installation, rather than a hosted deployment, is its release mechanism. This work concerned Claude Code, Codex/ChatGPT Windows, ZCode, and Xiaomi MiMo Desktop/MiMoCode on the Windows machine edge-dev. The canonical Linux repository is `/home/ahazan/repos/ai-devops`; every write task uses an isolated worktree. The Windows installation target was the authenticated `edge-dev` machine.

## 2. What we set out to do and why

Albert wanted the TypeSafe AI agent skill available by a memorable name in four clients without loading its full text into each session. He then reported a merge-queue failure and asked for prevention. The session also found a separate Windows state-path defect during installation checks. At wrap-up, code and prevention have landed; two interactive Windows behavior proofs and the separate maintenance repair remain open.

## 3. Current state and delivery proof

- The shared skill is `skills/shared/typesafe-ai/SKILL.md` with its license, short discovery description, and Claude `disable-model-invocation: true`. PR [#892](https://github.com/popcre/ai-devops/pull/892) merged as `3d509f4`. Its Codex manifest `skills/shared/typesafe-ai/agents/openai.yaml` sets `policy.allow_implicit_invocation: false`; PR [#906](https://github.com/popcre/ai-devops/pull/906) merged as `769901f`. Usage guidance is `docs/skills-usage-guide.md`. These changes are committed, pushed, and on `origin/main`.
- All four managed Windows skill copies were installed on edge-dev and SHA256 matched the merged source. Claude Code's `/typesafe-ai` live invocation succeeded. ZCode's explicit invocation read the skill and answered `Jev`. These facts and exact evidence are in [issue #894](https://github.com/popcre/ai-devops/issues/894), which remains OPEN for ChatGPT picker and MiMo live proof.
- The queue fault was narrowed checks omitting PowerShell scripts, followed by a full merge-queue ASCII failure. PR [#905](https://github.com/popcre/ai-devops/pull/905) added `.ps1` selection, tests, and corrected documentation. It merged as `cede8ea75d267961e8053698c4fbc798f04d3435`; 17 checks passed, none failed or pending. The proof was posted on [issue #913](https://github.com/popcre/ai-devops/issues/913), now CLOSED. The separate earlier non-ASCII script repair was PR #897.
- A Windows state junction defect is recorded in [issue #919](https://github.com/popcre/ai-devops/issues/919), OPEN. No D: state was moved and no junction removed. A proposed code workaround exists only in another agent's isolated worktree and must not be shipped because policy requires physical C: storage.
- This wrap-up handoff is the only new file owned by this closeout. No secrets appeared in this session; the SSH host key fingerprint was public identity material, not a secret. No shared database structure or data was changed.

## 4. What did not work

- A signed-out browser page did not establish ChatGPT Windows desktop sign-in or skill availability. The browser session is irrelevant to the already signed-in desktop conversation. Check the desktop picker itself.
- MiMo headless invocation failed with `Invalid API Key`; `mimo auth whoami` said `Not logged in`. Installed files and a healthy `ai-mimo doctor` do not prove that the desktop agent can invoke the skill.
- A temporary `AI_TASK_GATES_DIR` override made `ai-task-gates` write through physical D:, but that path violates `docs/reviewer-rotation-rules.md` rule 7 and is diagnostic only. Do not ship or install the candidate `readlink -f` workaround; it preserves the prohibited D: placement.
- The first queue prevention run caught a stale manual-only skill count in `docs/context-engineering.md`; it was corrected in the merged PR #905. Do not re-run the already passing merge-queue commit just to repeat proof.

## 5. Root causes and findings

- `tests/lib-selection.sh` did not select `test-windows-scripts.sh` for changed `.ps1` files, so narrowed PR checks missed an ASCII failure that the merge group caught. PR #905 closes that gap; issue #913 holds the final evidence.
- ChatGPT Windows Start menu resolves to `OpenAI.Codex_2p2nqsd0c76g0!App`, and the TypeSafe skill is installed in that Windows user's Codex skills root. This package mapping is not a live `@TypeSafe` picker result.
- `C:\Users\ahazan\.local\state\ai-devops` is a junction to `D:\ai-data\local\state\ai-devops`; Windows reports an untrusted mount point through the C: path. The D: tree had 51,132 files, about 2.66 GB, and eight active BlockerWatch-related processes at the last Windows check. The exact inventory, prerequisites, and repair success gate are in issue #919. `docs/reviewer-rotation-rules.md` requires state physically on C: to preserve credential hard-link behavior.

## 6. Exact next steps

1. **Issue #894, ChatGPT proof:** In authenticated ChatGPT Windows desktop, type `@TypeSafe` in a prompt and record the actual picker item or its absence on issue #894. It works when the item is selectable and its invoked skill reads the installed TypeSafe instructions; if absent, investigate the supported desktop skill registration route without claiming installed-file presence as proof.
2. **Issue #894, MiMo proof:** Complete normal MiMo Desktop/MiMoCode sign-in on edge-dev. Ask: `Use the typesafe-ai skill. Read its SKILL.md and tell me the model named in its first paragraph. Do not call TypeSafe or edit files.` Record the response on #894. It works when the signed-in client explicitly reads the installed skill and says `Jev`; then close #894 only when both live proofs are recorded.
3. **Issue #919, separate maintenance session:** Follow the issue's quiet-window, backup, reconciliation, physical C: move, and original-command smoke-check procedure. It works when `ai-task-gates start/status/check` succeeds without overrides, `~/.local/state/ai-devops` is an ordinary physical C: directory, and BlockerWatch plus reviewers still work. Preserve the D: original until proof passes. This is a separate task; do not bundle it into #894.
4. When #894 is truly complete, retire this handoff under `templates/system/handoff-standard.md` successor rules. Verify the predecessor work is on `origin/main` and all obligations are either done or carried forward before deleting this file.

## 7. Constraints and gotchas

- Follow repository `AGENTS.md`: new worktree for writes, `ai-task-gates`, `bin/ai-gh` for GitHub, PR and merge queue for code, and Windows installation guidance in `docs/deployment.md`. All GitHub posts need `Posted by Codex chat <id> on <machine>`; name human-facing times in EDT/EST.
- Do not store or print secret values. The public SSH host key fingerprint Albert supplied was `SHA256:gpgtYCaaFDDNe99xnjC1EkoaMivpRfz6oxx+zmwM0D0`; the Windows agent independently matched it before SSH.
- Do not edit another agent's isolated `codex/fix-gate-junction` worktree. Do not disable BlockerWatch or relocate live state while writers remain.
- MiMo's managed skills root is `~/.config/mimocode/skills/`; ZCode is the client's name, not “acode.” Client invocation differs: Claude `/typesafe-ai`, Codex `$typesafe-ai`, ZCode `$typesafe-ai`, and ChatGPT desktop `@TypeSafe` picker. ChatGPT may still choose installed skills automatically; the skill manifest's explicit-only policy applies to Codex, and the Claude frontmatter to Claude Code.

## 8. Access and environment

- Repository: `https://github.com/popcre/ai-devops`; current upstream branch `main`; current closeout worktree `/tmp/ai-devops-typesafe-wrapup` on `codex/typesafe-wrapup-handoff`. The canonical checkout is landing-only. The original worktree `/tmp/ai-devops-typesafe-explicit` has no uncommitted files and its PR #906 is merged.
- `bin/ai-gh` is authenticated for repository issue and PR reads/writes through the repository's rate-controlled wrapper. SSH to edge-dev was established after host-key fingerprint match. MiMo CLI was unauthenticated at the last check. The ChatGPT desktop picker cannot be proven by SSH alone.
- Issue links: [#894](https://github.com/popcre/ai-devops/issues/894) live TypeSafe proof; [#919](https://github.com/popcre/ai-devops/issues/919) Windows physical C: state repair; [#913](https://github.com/popcre/ai-devops/issues/913) closed queue-prevention record. No secret value or connection string appeared here.

## 9. Open questions and risks

- The authenticated ChatGPT Windows picker result remains unknown. The Start-menu app identity creates ambiguity about ChatGPT versus Codex surface, so record exactly which app was opened and what the picker showed.
- MiMo needs an interactive sign-in before behavior proof; a headless CLI error must not be mistaken for a missing skill.
- The Windows state move risks data loss or broken reviewer credentials if a writer races the final copy or if hard links are not preserved. Issue #919's maintenance session owns this, and no repair was performed in this session.
- No owner decision beyond the two requested interactive checks in §0 is currently required. If either check reveals a new integration problem, handle it as a new scoped continuation under #894.

## Self-audit

1. **Newcomer continuity: yes.** §§1–3 define the toolkit, goals, delivered commits, remaining issues, and installed-versus-live distinction; §6 gives exact next actions and success checks.
2. **Equal knowledge: yes.** §§4–5 preserve failed browser, MiMo, queue, and D: workaround paths; §§7–8 preserve routing and access facts.
3. **All execution details: yes.** §§3–9 cover evidence, failed attempts, causes, constraints, environment, risks, and measurable verification. Issue #919 holds the detailed maintenance inventory without copying private state into this public repository.
4. **Owner decision sweep: yes.** Every item in §§1–9 involving Albert's input is promoted to §0: ChatGPT picker check and MiMo sign-in/check. The #919 maintenance owner and its conditional escalation are also named there. No other approval is requested.
