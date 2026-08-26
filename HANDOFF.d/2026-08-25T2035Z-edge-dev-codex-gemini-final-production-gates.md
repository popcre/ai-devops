---
issue: 38
status: OPEN
owner: codex/gemini-final-production-gates
---

# Gemini final production gates — 2026-08-25

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None — nothing in this workstream currently needs Albert. The remaining actions
are already authorized, reversible, and have explicit fail-closed gates.

Already settled — do not re-ask:

1. Preserve Gemini capability; repair it rather than remove, disable, bypass, or
   replace it.
2. Qualification is per machine. Windows availability does not authorize Ubuntu.
3. Do not rerun the full master gate for source `f26d5eb`; it was run once after
   APPROVE and passed, exactly as Albert directed.
4. Do not push or claim full Gemini production qualification until every gate in
   §6 passes.

## 1. What this application is

`u2giants/ai-devops` is POP Creations' public backup-and-restore toolkit for its
multi-model AI coding workflow. `bin/ai-gemini` runs Gemini 3.7 Flash through
Antigravity's `agy` CLI inside a disposable, read-only-reviewed repository copy.
Production for this task means current GitHub `main`, green exact-head CI, and
separate governed qualification records on Windows `edge-dev` and Ubuntu.

Windows source work was isolated in
`C:\repos\ai-devops-gemini-qualification-final-v2` because the primary
`C:\repos\ai-devops` checkout contained another session's changes. Ubuntu is
reached as SSH alias `vps`, login `ai`, repository `/worksp/ai-devops`.

## 2. What we set out to do this session, and why

Finish Section 6 of `plan_gemini_reviewer_safety_repair.md`: add a durable,
hash-bound qualification record, converge through targeted tests and independent
review, run the full master gate once only after APPROVE, push the reviewed source,
qualify each platform, prove Gemini on real open issue #38, then close the docs and
issue. This was necessary because a successful historical containment canary did
not authorize changed wrapper/runtime/model bytes indefinitely.

## 3. Current state — what is true right now

- `origin/main` and this worktree are clean at
  `f26d5eb3b13ce6a01f2f61a262ef02e5b0016a2a` before this documentation-only
  working-tree update. These new Markdown changes are intentionally uncommitted
  because `codex-docs-update` does not commit, push, install, or close issues.
- Governed qualification code is landed. Targeted suites passed: 62 Gemini and
  51 preflight checks, zero failures.
- Exact-source independent review returned APPROVE with 113 bound checks and no
  blocking findings. Evidence:
  `.ai/reviews/codex-final-check-20260825T193706-749378-23914.md`.
- The one post-APPROVE full master gate passed: 53 Bash suites and 16 PowerShell
  suites, zero failures. It must not be repeated for this source.
- Exact-head CI run `32891794146` at
  https://github.com/u2giants/ai-devops/actions/runs/32891794146 completed
  successfully: `linux-offline`, `windows-reviewer-safety`, and
  `windows-offline` all passed.
- Windows is qualified on current source and preflight reports Gemini
  `available`. Windows production use is permitted by its local record.
- Ubuntu is still on older installed source and reports `quarantined`. Do not
  qualify or use Gemini there until run `32891794146` is fully green and current
  source is installed as `ai`.
- GitHub issue #38 is OPEN. Its real Gemini review has not started.
- Documentation updated in this uncommitted docs-only pass:
  `plan_gemini_reviewer_safety_repair.md`, `bugs.md`, and
  `tests/verification/reviewer-production-completion/2026-08-25-gemini-governed-qualification-progress.md`.
- The predecessor handoffs remain untouched. Delete them only during proven final
  closeout under the successor rule.

## 4. Everything we tried that did NOT work

1. Repeating the 40–60 minute master gate between design reviews consumed hours.
   The corrected sequence was targeted tests plus independent review until
   APPROVE, then exactly one master gate.
2. The first final review rejected an unrelated but real contradiction in
   `fix_muse_wrapper_reject.md`. Commit `c87fe62` repaired it; removal or bypass
   was not used.
3. Normal `agy models` discovery hung on Ubuntu and blocked qualification despite
   usable local identity and live canary behavior. Commit `8776d47` separated the
   qualification identity path from that network-sensitive command.
4. After that repair, record validation still called ordinary doctor, indirectly
   reintroducing the same discovery hang. Commit `f26d5eb` changed validation to
   local `doctor --identity` and added a regression test.
5. CI runs for immutable commits were canceled when later work reached `main`.
   Commit `817f806` keyed concurrency by event and exact SHA, preserving the
   evidence while allowing normal mainline work to continue.
6. Partial or terminated test runs were never counted as passing evidence. Only
   terminal summaries and terminal reviewer verdicts count.

## 5. Root causes and key findings

1. Qualification is a machine-local capability grant, not a project-wide flag.
   It must bind wrapper bytes, runtime bytes/version, model, provider, and epoch.
2. Network-sensitive model discovery cannot be part of validating an already
   recorded local identity; the live qualification itself proves authenticated
   provider behavior.
3. Exact-source evidence must survive concurrent normal commits. CI cancellation
   policy was part of the release-integrity problem.
4. Windows and Ubuntu are intentionally independent. Windows is usable now;
   Ubuntu's quarantine is the safety mechanism working correctly, not a reason to
   freeze all of `main`.
5. A truthful APPROVE, REJECT, or BLOCKED from the real issue review proves the
   wrapper can operate. The business gate is trustworthy execution and durable
   evidence, not a predetermined positive opinion.

## 6. Exact next steps

1. Reconcile these uncommitted documentation changes with current `origin/main`
   without broad staging or overwriting another session. Verify
   `git var GIT_COMMITTER_IDENT` is `Albert Hazan
   <u2giants@users.noreply.github.com>`. You'll know it worked when the intended
   Markdown-only diff is preserved and ancestry is explicit.
2. On Ubuntu, as `ai`, fast-forward `/worksp/ai-devops` to current `origin/main`
   and run `./install.sh --skip-secrets`. Verify `ai-devops doctor`, installed
   manifests, and source hashes. You'll know it worked when installed wrapper and
   manifest hashes match GitHub and Gemini remains `quarantined` before the canary.
3. With `PATH="$HOME/.local/bin:$PATH"`, run the installed governed Gemini
   qualification and then preflight status. You'll know it worked when Ubuntu
   writes its own current record and reports Gemini `available`.
4. Save `gh issue view 38` to a protected prompt file and run one real Gemini
   review with a short session name. You'll know it worked when `.ai/reviews/`
   contains a durable report binding exact head, model, conversation, evidence
   packet, and terminal APPROVE, REJECT, or BLOCKED verdict.
5. Update this progress note and the Step 6/bug status from partial to complete,
   comment the evidence on issue #38, and close it only when the prior gates pass.
   You'll know it worked when the GitHub issue is CLOSED and its comment links the
   exact artifacts.
6. Under the handoff successor rule, delete the superseded Gemini continuation
   handoffs only after every obligation and dead end is retained in the final
   plan/evidence. Include this file and the 2026-08-25T1053Z and
   2026-08-24T1503Z Gemini predecessors in that proof. You'll know it worked when
   no finished Gemini handoff remains and Git history retains each record.
7. Commit only the intended closeout files, push without force, and require green
   exact-head CI for the documentation closeout. Then reread the whole plan through
   its definition of done. You'll know it worked when `origin/main` contains the
   closeout commit, CI is green, both machines remain available, and every plan
   gate is evidence-backed.

## 7. Constraints and gotchas in force

- Work directly on `main`; several sessions share checkouts. Never broad-stage,
  reset, force-push, or overwrite another session's changes.
- Do not rerun the full master gate for `f26d5eb`.
- Do not manually edit qualification records or source flags to clear quarantine.
- Install Ubuntu as `ai`, never root; never live-edit production.
- Do not print provider payloads, raw process command lines, OAuth data, or secret
  values. Existing credentials remain in protected CLI state/1Password vault
  `vibe_coding`.
- Never use permission-bypass flags or change global Antigravity settings.
- Keep Ubuntu quarantined until its own exact-source qualification passes.
- Do not close issue #38 or claim cross-platform production completion before the
  real review and every stated gate passes.

## 8. Access and environment

- Windows host: `edge-dev`; PowerShell 7; Git Bash at
  `C:\Program Files\Git\bin\bash.exe`; `gh` authenticated as `u2giants`.
- Isolated clean worktree used here:
  `C:\repos\ai-devops-gemini-qualification-final-v2`.
- Shared primary checkout: `C:\repos\ai-devops`; it had another session's
  unrelated changes and was deliberately not modified by this work.
- Ubuntu: SSH alias `vps`, login `ai`, repo `/worksp/ai-devops`, runtime state
  `/home/ai/.local/state/ai-devops/`, `agy` under `~/.local/bin/`.
- Secrets: 1Password vault `vibe_coding`; no credential change is required.

## 9. Open questions and risks

1. `origin/main` may move before documentation closeout. Reconcile safely and
   ensure review/install evidence still binds the intended source.
2. Ubuntu's installed source is deliberately stale pending installation. Its
   current quarantine must not be described as a Gemini product failure.
3. The real issue review may truthfully reject the issue content. That is not a
   wrapper failure if the durable evidence contract passes.
4. The handoff contract audit found these unrelated stale files whose linked
   issues are already closed. They were not edited or deleted in this docs-only
   pass; their owners/successors must verify retention before retirement:
   - `2026-08-17T2115Z-al8960ofc-codex-reviewer-system-repair.md` — issue #34,
     owner `codex/reviewer-system-repair-analysis`.
   - `2026-08-18T0114Z-al8960ofc-claude-reviewer-packet-phase-a.md` — issue #34,
     owner `claude/reviewer-packet-phase-a`.
   - `2026-08-18T1404Z-edge-dev-codex-shared-db-finish-first-plan.md` — issue #34,
     owner `codex/shared-db-finish-first-plan`.
   - `2026-08-18T1929Z-al8960ofc-codex-muse-opencode-plan.md` — issue #40,
     owner `main / al8960ofc Codex / Muse OpenCode plan`.
   - `2026-08-18T2024Z-edge-dev-codex-muse-contract-gate.md` — issue #40,
     owner `main / edge-dev Codex / Muse OpenCode harness`.
   - `2026-08-20T1752Z-edge-dev-codex-grok-review-repair-plan.md` — issue #56,
     owner `edge-dev/codex/grok-review-repair-plan`.
   - `2026-08-21T1122Z-edge-dev-codex-reviewer-repair-plans.md` — issue #56,
     owner `edge-dev/codex/reviewer-repair-plans`.

## Mandatory handoff self-audit

1. **Yes.** §§1–3 identify the product, repositories, environments, exact commit,
   test/review/CI state, machine status, issue, and uncommitted documentation.
2. **Yes.** §§4–5 retain every expensive dead end and the reasoning behind the
   identity, validation, CI-concurrency, and per-machine design.
3. **Yes.** §6 gives ordered executable actions with a success gate for CI,
   reconciliation, Ubuntu install/qualification, real review, issue/docs closeout,
   handoff retirement, push, and final CI; §§7–9 preserve constraints and risks.
4. **Yes.** A line-by-line sweep of §§1–9 found no action requiring Albert's
   decision. All settled owner directions are consolidated in §0, and no hidden
   approval, choice, or unrelated owner ruling remains elsewhere.
