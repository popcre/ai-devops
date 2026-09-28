---
issue: null # Wrap-up scope freeze forbade opening a new issue; successor must create the parent issue before implementation.
status: BLOCKED
owner: codex/warpbuild-byoc-handoff
---

# HANDOFF — WarpBuild Azure BYOC Windows CI (2026-09-28, edge-dev3/Codex)

## 0. Decisions only the owner can make

- **Blocking — payment method:** WarpBuild's signed-in billing page showed no payment method and said one is required to continue. Albert must enter the card himself; the page says it makes a refundable $2 verification charge. Recommend using the business payment method he wants charged for CI. This blocks live runner use.
- **Blocking — Microsoft sign-in:** The Microsoft admin-consent tab reached the password screen. Albert must complete sign-in himself and stop before approving access. Recommend using the same identity as the authenticated Azure CLI subscription. This blocks inspection of the live consent screen and deployment preview.
- **Already settled — target and service:** Albert chose WarpBuild BYOC, the existing Azure subscription he named in chat, and a runner that starts per job. Do not ask him to choose a standing VM or another cloud again. Resolve the subscription identity read-only with `az account show`; do not put its private identifiers in this public file.
- **Not Albert's technical decision:** Independent read-only review of the exact Azure permissions, template, and target is required before the agent makes any infrastructure change. Only an explicit APPROVE authorizes it. Do not ask Albert to judge the technical Azure permissions.

## 1. What this project is

`popcre/ai-devops` is a public GitHub repository holding POP Creations' AI workflow toolkit and GitHub Actions CI. Its Windows verification jobs currently use Blacksmith hosted Windows runners. WarpBuild BYOC (bring your own cloud) would instead create a fresh Windows VM in the owner's Azure subscription for each GitHub Actions job and remove it after the job. WarpBuild manages runner registration and lifetime; Azure bills VM, disk, storage, and networking, and WarpBuild bills a per-minute management fee. Official setup: <https://www.warpbuild.com/docs/ci/byoc/azure> and <https://www.warpbuild.com/docs/ci/byoc/azure/config>.

## 2. Goal and reason

Albert's Blacksmith billing dashboard showed substantially higher month-to-date usage than an earlier partial invoice. He chose WarpBuild BYOC to lower Windows CI costs, authorized using the existing Azure subscription, and asked for the lowest-cost VM that works for this repository. This session began the vendor setup but stopped before Azure authorization, cloud changes, or workflow migration. Keep the billing screenshot and invoice in the user's private files; do not copy them into this public repository.

## 3. Current state and proof

- On 2026-09-28 the local `az` CLI was authenticated as the subscription owner and showed the owner-named subscription enabled. The subscription held only an existing bot resource in its own resource group; Compute, Network, and Storage resource providers were not registered. These are read-only observations and must be rechecked before any write.
- The WarpBuild browser session is signed in to an existing workspace with the `popcre` GitHub organization connected. The BYOC page showed no cloud connections. Clicking Azure > Continue created a **pending WarpBuild cloud integration request** and displayed two required steps: Microsoft directory admin consent for the WarpBuild CI app, then deployment of a vendor-hosted ARM template granting Azure permissions. No consent was accepted and no template was submitted.
- The in-app browser had three relevant tabs: WarpBuild BYOC, Microsoft admin consent, and Azure portal deployment preview. The Microsoft tab was at the password prompt for the same account as Azure CLI. The vendor's signed template link was short-lived; obtain a fresh link if expired. Never paste its signed URL or contents into a public artifact.
- WarpBuild billing showed $10 promotional credit, no payment method, and a banner requesting one. Albert has been told to enter a card himself. No Azure resources, registered providers, runners, VM, or workflow changes were made.
- Repository source remains on `origin/main`; this handoff is the only file authored by this session. The handoff branch is `codex/warpbuild-byoc-handoff`. No code or CI change is claimed complete.

## 4. Failed or incomplete attempts

- The first semantic click on WarpBuild's “Connect Cloud Account” appeared to do nothing; a visual click opened the AWS/GCP/Azure choice. Continue led to a pending integration request, not an Azure connection.
- Azure CLI could not inspect the WarpBuild application before consent: `az ad app show` and `az ad sp show` both reported the application did not exist in the current tenant. Inspect the actual consent screen after sign-in.
- The Microsoft consent link opened a fresh sign-in page. Entering the Azure account email led to the password prompt. Do not retrieve, type, or log a password through the agent.
- `az vm list-usage --location eastus` returned no quota entries while Compute was unregistered. Do not interpret this as zero quota or sufficient capacity; recheck after provider registration is approved.
- `ai-task-gates check --before infrastructure` refused with “no changes and no task class were found.” The session had declared `infrastructure`; no repository change existed then. Do not treat that command's failure as permission to bypass the independent infrastructure review.

## 5. Findings that affect the implementation

- The cost candidate is an on-demand Azure D4as_v5-class Windows VM: 4 vCPU, 16 GB, East US, Windows Server 2022, no warm pool or static IP. WarpBuild Azure BYOC currently supports East US and requires a minimum 256 GB disk; its best-practice disk is P20. Reconfirm live price, SKU availability, and image before selection. Spot is cheaper but can interrupt the required CI suite; do not use it for first proof.
- WarpBuild's Azure BYOC documentation currently supports Windows Server **2022**. Existing CI labels in `.github/workflows/verify.yml` use Blacksmith Windows **2025**. Compatibility is unproven; a passing canary is mandatory before routing required jobs. Windows suites contain timing-sensitive reviewer tests and six-way sections; preserve their fan-out and safeguards.
- The Azure connection path has two distinct grants: directory admin consent and an Azure ARM template. The latter is a security-sensitive expansion in a subscription that already hosts another service. Preview exact roles, scopes, resources, and changes before independent review. Do not use a blanket approval based on documentation alone.
- The `popcre` GitHub organization appears connected in WarpBuild account settings, but repository authorization and runner-group selection have not been proved. Confirm the exact repository before a canary.
- The existing Azure subscription is not a disposable CI account. Put CI resources in an isolated new resource group or stack, with a bounded budget and clear ownership after review; do not touch the existing bot resource.

## 6. Exact next steps and gates

1. Start a new session in this repository, read `AGENTS.md`, this handoff, and the Windows CI row of `docs/task-router.md`. Create one parent issue for the multi-step migration; the wrap-up scope freeze forbade this session from opening it. **Gate:** issue body assigns one outcome at a time and links this handoff.
2. Recheck `az account show`, subscription resources and provider states, WarpBuild account/billing, and GitHub organization connection. Have Albert complete the Microsoft sign-in and add a payment method himself if still pending; do not approve consent or submit a deployment during that handoff. **Gate:** signed-in consent and template preview are visible, payment method is present, and exact target subscription matches his choice.
3. Generate a fresh WarpBuild Azure connection request if the previous signed template expired. Inspect the full admin-consent permissions and exact ARM template contents, roles, scope, resources, and deployment target read-only. Keep signed URLs and account identifiers out of logs, chat, and the public repo. **Gate:** a concrete proposed change set and recovery path exist, with no ambiguous or broad authority.
4. Dispatch those exact inputs to an available independent read-only reviewer under the standing production/shared-cloud rule. Accept only explicit APPROVE; otherwise stop and resolve the review finding. Apply the browser confirmation policy at the actual security-grant action. **Gate:** approval identifies the same template, app, subscription, scopes, and actions that will be executed.
5. After approval, register only required providers, complete consent/template, verify WarpBuild connection, create an East US Windows Server 2022 runner set using the smallest non-burst 4 vCPU/16 GB on-demand shape that passes capability checks, minimum 256 GB disk, no warm pool, and no static IP unless needed. **Gate:** Azure resources are confined to the reviewed CI stack, no VM runs when idle, and WarpBuild shows a healthy connection and runner label.
6. Run one non-required canary job on the new label to prove Windows tooling, repository access, job startup/termination, and Windows 2022 compatibility. **Gate:** job passes, VM terminates, exact cloud costs are visible, and the existing bot is untouched.
7. Only after the canary, change owned workflows in a current-upstream worktree, run focused tests, commit, push, PR, merge through required checks, and verify on `origin/main`. Keep the CI migration scoped to one proven outcome per session and preserve source-bound reviewer safeguards. **Gate:** required CI passes on WarpBuild, no Blacksmith labels remain in migrated paths, and first invoices support the cost goal. Retire this handoff only under the successor rule.

## 7. Constraints and safety rules

- Repository is public; no raw invoices, screenshots, private account IDs, secrets, signed template URLs, or credential values in commits or GitHub comments.
- Canonical checkout is landing-only. Every write-capable task uses a current-upstream worktree. Do not push to protected `main`; use branch, PR, checks, queue, and verified merge. Use `bin/ai-gh` for GitHub calls.
- The user's choice authorizes the setup goal, but shared cloud infrastructure remains gated by exact target, independent APPROVE, and browser security confirmation at the moment of granting access. Do not construe the pending vendor request as permission to finish the Azure grants.
- Payments and passwords are owner-operated. The browser handoff policy requires the owner to enter the card and password himself.
- WarpBuild's Windows BYOC GCP support is pending; this work targets Azure only. On-demand is the initial choice because Spot preemption would invalidate required test evidence.
- A handoff is not completion. No Azure setup or CI migration is done as of this document.

## 8. Access and environment

- Repository origin: <https://github.com/popcre/ai-devops>; local canonical checkout: `/home/ahazan/repos/ai-devops`; handoff worktree: `/home/ahazan/.codex/worktrees/warpbuild-byoc-handoff/ai-devops`.
- Azure CLI `az` version 2.90.0 was authenticated on 2026-09-28. Recheck it live rather than relying on this snapshot.
- WarpBuild browser: <https://app.warpbuild.com/ci/byoc>; account settings: <https://app.warpbuild.com/settings/account>; billing: <https://app.warpbuild.com/settings/billing>. In-app browser tabs were marked for handoff, but may expire between sessions.
- Relevant docs: `docs/independent-windows-runner-setup.md`, `docs/self-hosted-windows-runner.md`, `docs/task-router.md`, and official WarpBuild Azure BYOC docs linked in §1.
- No reusable secret was generated or stored. A short-lived vendor-signed preview URL appeared in the browser and will expire; obtain a fresh one rather than saving it.

## 9. Open questions and risks

- Microsoft consent may require a directory role beyond subscription Owner; the vendor docs mention Privileged Role Administrator. Verify the actual prompt and tenant role before assuming access.
- The vendor ARM template's permissions and new resource names are not yet reviewed. It may request broader access than the CI stack needs; reject or redesign if so.
- Payment method and Microsoft password are still pending with Albert. No credential should pass through a chat, shell argument, or public artifact.
- Azure regional VM quotas and whether the chosen VM/image can run all Windows 2025-era tests remain unproven. Do not cut over required CI before live canary evidence.
- No issue was opened due to the user's wrap-up scope freeze. The successor must open exactly one parent issue before implementing the multi-step route.

## Self-audit

1. **Can a new developer continue without this chat? Yes.** §§1–3 define the product, cost objective, exact pending integration state, and what has not changed; §8 gives entry points.
2. **Can they continue as effectively as this session? Yes.** §4 records failed or incomplete attempts; §5 records the Windows 2022 versus 2025 compatibility gap and both permission grants; §7 preserves safety boundaries.
3. **Are all material facts and executable next actions present? Yes.** §6 gives ordered actions with observable gates; §§7–9 name access, risks, and constraints. No unproven live outcome is described as complete.
4. **Does §0 contain every owner decision? Yes.** The line-by-line sweep of §§1–9 found only the owner-operated payment and Microsoft sign-in steps, plus the already settled cloud/service choice. §0 states all three; independent technical approval is assigned to a reviewer, not Albert. No other owner judgement remains hidden in later sections.
