issue: 1881
status: OPEN
owner: claude/cd3125e3-e300-43fe-a3a2-35c4277eb456
---
# Install the Codex Windows reviewer fix (#1900) on al8960ofc

## 1. Goal
The installed toolkit on al8960ofc (host `4837`, checkout `C:\repos\ai-devops`, user ahazan2) must include merged fix https://github.com/popcre/ai-devops/pull/1900 (merge commit `6d68a2e251e903f666dc9db71b7e1aba9ec6c369`), so Windows Codex reviews return APPROVE/REJECT instead of BLOCKED.

## 2. Current state
- Fix merged 2026-10-20 7:18 PM EDT. Installed checkout still at `21a37359` (pre-fix).
- Live proof done from a fresh clone: REJECT verdict; checklist ticked on https://github.com/popcre/ai-devops/issues/1881 (Windows comment).

## 3. Root cause (verified)
1. Over SSH, every Codex sandboxed command fails `windows sandbox: timed out after 15000ms connecting runner pipe-in` (codex 0.145.0 and 0.163.0 alike; unelevated mode fails 0xC0000142). From the desktop session (interactive scheduled task, `schtasks /Create /IT ... & schtasks /Run`) it works. Same limit as Gemini (#1577).
2. The per-run reviewer `CODEX_HOME` from #1888 was empty, so elevated sandbox setup re-ran each review and commands hung. #1900 junctions `.sandbox`, `.sandbox-bin`, `.sandbox-secrets` into it.

## 4. Tried and failed
- Upgrading Codex to 0.163.0 (npm global on al8960ofc is now 0.163.0; the standalone 0.145.0 still wins on the desktop PATH) — did not fix SSH.
- `ln -s` for the state dirs — no symlink rights; junctions used instead.

## 5. Next step
Follow the reviewer-safety install route in https://github.com/popcre/ai-devops/blob/main/docs/deployment.md (independent exact-head APPROVE, `ai-release-live-check fleet`, `ai-task-gates authorize-install`, then `bin/install-ai-devops-windows.ps1 -RepoPath C:\repos\ai-devops -ExpectedHead 6d68a2e251e903f666dc9db71b7e1aba9ec6c369`). Run the Windows steps from the desktop session.

## 6. Verify
`git -C C:\repos\ai-devops log -1` shows 6d68a2e2, and `ai-codex-review diff-review` started in the desktop session using the installed toolkit returns APPROVE or REJECT.

## 7. Risks
Do not run Codex reviews over SSH on 4837 and call it a new bug. Never weaken the sandbox.

## 8. Ownership
Unowned; next session takes it.

## 9. Retention
Delete this file once step 6 is proven.

Posted by Claude chat c7eaa938-0192-409f-a00e-5cc317519c2d on edge-dev3
