---
issue: 961
status: OPEN
owner: mimo/warpbuild-azure-byoc-handoff
---

# HANDOFF — WarpBuild Azure BYOC Windows CI (2026-09-30, edge-dev/MiMo)

## 0. Decisions only the owner can make

**Put this whole list to the owner in ONE message before starting work.**

### Blocking

- **None right now for Albert.** Payment and Microsoft sign-in are already done (2026-09-28). Independent technical review already approved dedicated-subscription BYOC + stack + runner + canary (DeepSeek, 2026-09-28/29). Do not re-ask for those.

### Wrong guess is recoverable (recommend first)

- **Azure core quota on the CI subscription is tight (East US ~10 cores, DASv4 family 10, DASv5 family 0).** Recommendation: accept quota increases already submitted (DASv5 4, total cores 12 — both InProgress) and do not run more than one concurrent WarpBuild Windows job until a second 4-core VM is proven necessary. Blocks: reliable canary and any later required-CI migration if quota stays 0/10.

- **Disk size on the runner is 150 GB (API clamped it); vendor docs want ≥256 GB.** Recommendation: after canary is green, PATCH storage again or recreate the runner; do not block the canary on this. Blocks: nothing for first proof; required CI later should use ≥256 GB if suites need it.

### Not part of this workstream — nobody is on it

- **WarpBuild stock Windows runners also exist on the account** (`warp-windows-latest-x64-*` etc., WarpBuild-managed, not BYOC). Recommendation: leave them unused; this workstream is BYOC-only per the original cost goal. Do not mix labels into required CI by accident.

### Already settled — do NOT re-ask

- 2026-09-28: separate Azure subscription **warpbuild ci runners** (`7d163b8f-aa4f-4079-bf84-94b699631b3d`) is the only place for WarpBuild CI resources. Oracle subscription stays frozen (bot only).
- 2026-09-28: Entra consent stays least-privilege (`User.Read` only). No directory admin roles for WarpBuild.
- 2026-09-28: required CI must NOT move until a non-required canary passes live.
- 2026-09-28: first proof is on-demand Windows Server 2022, no Spot, no warm pool.
- 2026-09-28: Albert is not technical — no CLI/jargon asks; report in plain English.

## 1. What this application is

`popcre/ai-devops` is the public GitHub toolkit for POP Creations’ AI CI workflows (https://github.com/popcre/ai-devops). Windows CI historically ran on Blacksmith and local self-hosted runners. This workstream adds **WarpBuild Azure BYOC**: ephemeral Windows VMs in Albert’s Azure, managed by WarpBuild, billed as Azure compute + a small WarpBuild per-minute fee. Goal: cheaper/on-demand Windows CI without giving a third party the production subscription.

Related:

- Parent issue: https://github.com/popcre/ai-devops/issues/961
- Canary workflow (merged, non-required): `.github/workflows/warpbuild-win2022-canary.yml`
- Azure subscription for CI: `warpbuild ci runners` (`7d163b8f-aa4f-4079-bf84-94b699631b3d`), tenant `1caeb1c0-a087-4cb9-b046-a5e22404f971`
- Production bot (do not touch): `theoracle-popcre-teams-bot` in `rg-oracle-teams-bot` on `37077c95-ea53-4a19-8380-f3f48f0cc75d`

## 2. What we set out to do this session, and why

Continue from `HANDOFF.d/2026-09-28T1125Z-edge-dev3-codex-warpbuild-azure-byoc.md` (Codex). Albert chose WarpBuild BYOC after Blacksmith costs looked high. Session goal: finish connection, provision an on-demand Windows runner, prove it with a **non-required** canary job, and leave required CI unmigrated until that proof.

## 3. Current state — what is true right now

### Done and verified

- **GitHub org `popcre`:** WarpBuild app `warpbuildbot` connected.
- **Payment + Microsoft sign-in:** complete (owner, 2026-09-28).
- **Dedicated subscription** `warpbuild ci runners` active. Providers Compute/Network/Storage/ManagedIdentity registered. Oracle sub has **zero** WarpBuild role assignments (verified).
- **Entra app:** Warpbuild CI SP `97f1be95-1688-4f6c-905a-e7f8c7f0919c`, app id `2c61c7e8-c6a9-462f-bec1-671e2fd9b98e`, admin consent `User.Read` only.
- **Azure RBAC:** vendor template applied on CI subscription only (Contributor + Reader + Storage Blob Data Contributor at subscription scope to SP `97f1be95-…`). Independent review approved this **because** the subscription is dedicated (DeepSeek REJECT for Oracle; APPROVE after split).
- **Stack:** `popcre-ci-use1` (`wuo7sl998g95d676`) Active, East US, RG `wb-popcre-ci-use1-wuo7sl998g95d676`. Connection id `eed74623-04ee-43f3-9468-a6f43b1aa362`.
- **Runner:** `warp-custom-win2022-canary` (id `wts3yujcycg8o15x`), active. Labels: `warp-custom-warpbuild-win2022-canary`, `warp-custom-win2022-canary`. Image `windows-server-2022`, capacity `ondemand`, instance type `Standard_D4as_v4`, IMDSv2 **false**, pool_size 0.
- **Canary workflow** merged via PR #987 (`workflow_dispatch` only — never a required check).
- **Issue #961** is the parent; many progress comments there.

### In flight

- Canary run **https://github.com/popcre/ai-devops/actions/runs/36711422102** — job `windows-tooling-canary` **queued** as of 2026-09-30T12:09Z. No Azure VM allocated on the last check (leftovers deleted to free cores).
- Azure quota requests InProgress: `standardDASv5Family` → 4; East US `cores` → 12.

### Not started

- Required CI migration (windows-offline / verify.yml paths) — **explicitly blocked** until canary is green and reviewed.
- Budget alert on CI subscription (recommended by reviewer; API create failed on schema; do in portal if needed).

### Git / deploy status

- Handoff branch: `chore/warpbuild-byoc-handoff` (this file only).
- Canary workflow on `origin/main` (merged PR #987).
- No verify.yml / required-check changes committed.

## 4. Everything we tried that did NOT work

1. **Browser UI automation for WarpBuild forms** — flaky (SendKeys, window handles, coordinate drift). Worked once for stack create (Albert finished it). Prefer WarpBuild REST API (`https://api.warpbuild.com/api/v1`).
2. **ARM template applied with Application ID instead of Object ID** — created role assignments whose `principalId` was `2c61c7e8-…`; Verify Connection returned **400**. Fix: delete broken assignments; apply template with `appObjectId=97f1be95-…`.
3. **Template integration ID ≠ live wizard ID** — template hardcoded `warpbuildIntegrationId` `d516a187-…` while the live setup used `eed74623-04ee-43f3-9468-a6f43b1aa362`. Verify still 400 until template output matched `eed74623-…`.
4. **First subscription used was Oracle (`37077c95-…`)** — security review REJECTed subscription-wide Contributor there. Moved everything to `warpbuild ci runners`.
5. **UI “Successfully created custom runner” was not durable** — GET `/runners` was empty; create must go through `POST /runners`.
6. **WarpBuild create 400 FVE_008 “operation is marked suspended”** — onboarding temporarily blocked; cleared later (2026-09-29). Schema then worked.
7. **Wrong create schema** — `stack_id` is wrong; **`provider_id`** is the stack id. `byoc_sku` is required (`arch`, `instance_types`). `capacity_type` is `ondemand` or `spot`. Storage `tier` is `low|medium|high|extreme|custom` + `size` int. See `WarpBuilds/terraform-provider-warpbuild` models.
8. **Job label mismatch** — workflow `runs-on: warp-custom-warpbuild-win2022-canary` vs runner label `warp-custom-win2022-canary`. Patched runner labels to include both.
9. **Instance type Standard_D4as_v5** — Azure quota `standardDASv5Family` limit **0** on CI sub. Switched to **Standard_D4as_v4** (family limit 10).
10. **Then Total Regional Cores / DASv4 family: limit 10, usage 8** (two leftover 4-core VMs) — new VMs 409. Leftover VMs removed; canary re-dispatched.
11. **IMDSv2 required true** — suspected first-boot block; set **false** on runner `wts3yujcycg8o15x`.
12. **`gh run watch` / tight polling** — forbidden (rate limit). Use `bin/ai-gh-wait` (≥300s interval) or `bin/ai-pr-wait`.
13. **op:// secret reference with `+` in title** — parse error. Use item id: `op://vibe_coding/7xlkdojgsymtifrqwgnntjaqk4/credential`.
14. **GUI “Create Stack” automation** often missed; Albert created the stack by hand after a filled form.

## 5. Root causes and key findings

- **400 Verify = wrong identity + wrong integration id**, not missing Azure roles (see §4.1–2).
- **WarpBuild API is the reliable control plane**; OpenAPI is not at `/api/v1/openapi.json`. Schema recovered from `WarpBuilds/terraform-provider-warpbuild` (`model_commons_setup_runner_input.go`, `docs/resources/runner.md`).
- **API key** is 1Password `vibe_coding` / `warpbuild api key ci+cache` / field `credential`. Use `op run --env-file` with `op://vibe_coding/7xlkdojgsymtifrqwgnntjaqk4/credential`. Base URL `https://api.warpbuild.com/api/v1`. Endpoints: `GET/POST/PATCH/DELETE /runners`, `GET /stacks`, `GET /stacks/{id}/errors`, `GET /runner-images`.
- **Azure JIT Windows VMs** use community gallery `warpbuild-b0bf50c0-…/win-2022-x64-core`. They appear in RG `wb-popcre-ci-use1-…` then are deleted if the job never binds.
- **Stack errors** (`GET /stacks/{id}/errors`) are the fastest way to see why a job stays queued (quota 409s show up here).
- **Independent production review** (DeepSeek session `20260928-085455-769239`): dedicated subscription + vendor roles + canary-only is the approved shape. Re-review stack/runner changes if scope expands.
- **Machine:** this session ran on Windows `edge-dev` with Git Bash (`C:\Program Files\Git\bin\bash.exe`); PowerShell quoting is hostile — prefer `bash` script files under Temp for multi-line API calls.

## 6. Exact next steps and gates

1. **Confirm canary run 36711422102 (or the current equivalent) reaches a terminal state.**  
   Check: `bin/ai-gh run view <id> --json status,conclusion,jobs` and `GET /stacks/wuo7sl998g95d676/errors`.  
   Gate: job status is `completed` with `conclusion: success` **or** a clear stack error to fix.

2. **If still queued and stack errors are quota 409:** delete leftover WarpBuild VMs in `wb-popcre-ci-use1-wuo7sl998g95d676`, re-dispatch `workflow_dispatch` on `warpbuild-win2022-canary.yml` (`bin/ai-gh workflow run warpbuild-win2022-canary.yml --ref main`).  
   Gate: a new VM appears (`az vm list`) and the job leaves `queued`.

3. **If job runs:** capture job URL + runner name (`$RUNNER_NAME`) as live proof on issue #961. Do **not** change verify.yml.  
   Gate: comment on #961 includes the green run URL and “required CI still unmigrated.”

4. **If job fails on tooling:** fix only what the canary needs (tool paths, workflow step). Keep `workflow_dispatch` only.  
   Gate: next canary run is green.

5. **After green canary — next session/phase (not this file’s closer):** migrate required Windows CI in a **new** worktree/PR, preserve fan-out and reviewer-safety suites, get independent review if it touches reviewer safety paths, merge via queue.  
   Gate: required checks green on WarpBuild labels; no required job left on Blacksmith for migrated paths.

6. **Retirement:** when required CI is proven on WarpBuild and issue #961 children are done, delete this handoff and the Codex one `2026-09-28T1125Z-edge-dev3-codex-warpbuild-azure-byoc.md` only if all its obligations are carried forward (successor rule).

**Reciprocal instruction:** when you finish a phase, re-read §0 and §6–§9 through plan-end and report any drift (quota, labels, subscription ids, review verdicts) back onto #961 and this file’s successor.

## 7. Constraints and gotchas in force

- Public repo: no API keys, signed Azure template URLs, invoices, or tenant/subscription secrets in commits. Subscription **ids** already appear in public issue comments — do not paste secrets; ids alone are OK.
- Never grant WarpBuild RBAC on `37077c95-ea53-4a19-8380-f3f48f0cc75d` (Oracle).
- Required CI moves only after a green non-required canary (owner + review).
- No Spot for first proof; no warm pool (`pool_size` 0).
- Workflow must stay `workflow_dispatch` only until a later deliberate migration.
- Use `bin/ai-gh` for GitHub; never `gh run watch`; waits ≥5 minutes via `bin/ai-gh-wait` / `bin/ai-pr-wait`.
- Canonical `C:\repos\ai-devops` is landing-only — write in a worktree, branch, PR.
- Production/shared-cloud mutations need independent reviewer APPROVE of the exact change (already granted for this BYOC topology; re-review if scope grows).
- `ai-task-gates start --class infrastructure` was used 2026-09-28; re-declare if the change set grows.

## 8. Access and environment

- Repo: `popcre/ai-devops`. This box: `edge-dev`, Windows, Git Bash. Azure CLI logged in as Albert@popcre.com.
- Subscriptions: CI `7d163b8f-aa4f-4079-bf84-94b699631b3d` (active); Oracle `37077c95-ea53-4a19-8380-f3f48f0cc75d` (frozen).
- WarpBuild API: key in 1Password vault `vibe_coding`, item `warpbuild api key ci+cache` (`7xlkdojgsymtifrqwgnntjaqk4`), field `credential`. Org `wqml901c6tph0evf` / `pop_creations`.
- Runner id `wts3yujcycg8o15x`; stack id `wuo7sl998g95d676`.
- DeepSeek review thread id `20260928-085455-769239` (reuse for later infra approvals if still valid; re-open if tool requires).
- Issue #961 has the long audit trail. Codex predecessor handoff in that worktree (path on D: machine: `D:\ai-data\codex\worktrees\edge-dev-runner-handoff\ai-devops\HANDOFF.d\2026-09-28T1125Z-edge-dev3-codex-warpbuild-azure-byoc.md`).

## 9. Open questions and risks

- **Will the canary agent register?** VMs have been created (and some destroyed) without a GitHub runner ever appearing. If the next attempt still queues with no stack error, treat as a WarpBuild agent/network issue (NSG, public IP, IMDS) and open a WarpBuild support ticket with stack id + runner id + job URL.
- **Quota:** if InProgress requests stay pending, canary can only use up to leftover free cores (4). One concurrent Windows job max until raised.
- **Windows Server 2022 vs 2025:** WarpBuild Azure BYOC docs say 2022; repo’s Blacksmith sections use 2025. Canary proves 2022 only; required CI migration must re-check suite compatibility.
- **150 GB disk** may be tight for some suites later (vendor min 256 GB).
- **Cost:** budget alert not yet created (portal). Reviewer asked for it before a runner fleet; one canary is low risk but add before migration.
- **Stock WarpBuild Windows labels** on the same account could be picked up by accident if someone copies labels; keep required CI on explicit `warp-custom-…` labels only.

---

## Self-audit (handoff-writer gate)

1. **Comprehensive for a brand-new developer?** Yes — §§1–2 give product and goal; §3 live ids and states; §4 every dead end; §5 schema/API/quota findings; §6 numbered gates; §7–8 access; §9 risks.  
2. **As effective as this session?** Yes — API schema, secret reference, exact ids, label pair, D4as_v4 vs D4as_v5, IMDSv2, stack-errors URL are written down (§4–5, §8).  
3. **Every relevant detail?** Background, goals, outcomes, state, failures, decisions, constraints, risks, next actions, verification (job URL / gates) are in §§1–9. Secrets by vault location only (§8).  
4. **Section 0 alone enough for the owner?** Yes after the sweep — no open owner password/payment/consent items; remaining asks are quota/disk/budget with recommendations; “already settled” prevents re-asks. Promoted the unused stock-runner risk from §9 into §0.
