---
issue: plan-doctor-orphan-scan-guard
status: OPEN
owner: mimo/doctor-orphan-scan-guard
---

# HANDOFF — doctor orphan-scan guard + process re-cut landing (2026-09-29)

## 0. Decisions already made (do not re-ask)

- **Albert accepted (2026-09-29):** one small doctor-safety PR; no new plan book; drop item 3 (easier upgrades).
- Four-advisor debate (GLM, Gemini, StepFun, Qwen) plus parent agreed the keep-set is only the doctor residual.
- Locked: no item 3, no item 9, no loss ledger, no lease TTL, no new `plan_*.md`, do not re-run #168.

## 1. Plan

Comprehensive build plan (13 sections, STATUS table):

[`IMPLEMENTATION-PLAN.md`](../IMPLEMENTATION-PLAN.md)

**Fresh session starts at that plan's STATUS step 1.**

## 2. Why this exists

Transcript mining produced nine process findings. After debate, only one real code change remains: prove the review health-check's leftover-folder scan is cheap (and bound or name the other slow path). Everything else is documentation of what we will not do, and routing of leftovers into plans that already exist.

## 3. Next steps

1. Implement plan steps 1–2 (code + tests) on `mimo/doctor-orphan-scan-guard`.
2. Docs steps 3–6 (handoff corrections, decision ledger, index, fold lines).
3. Independent exact-head review (reviewer-safety).
4. Merge via queue; live `ai-glm doctor` with seeded orphans inside the 10s window.
5. Update plan STATUS rows with artifacts.

## 4. Constraints

See plan §11. Summary: branch + PR + queue only; Git Bash on Windows; `bin/ai-gh`; independent exact-head review required; never rebuild item 3/9; never wall-clock asserts.

## 5. Access

Worktree: `C:\repos\ai-devops-wt-doctor-orphan-guard`  
Host: `edge-dev`  
Test: `bash tests/test-ai-glm.sh`

Posted by MiMo chat ses_ffe5f125429feffegbh72RPXnT on edge-dev
