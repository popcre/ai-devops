# WarpBuild Azure BYOC Windows CI

WarpBuild BYOC creates a fresh Windows Server 2022 VM in POP Creations' dedicated
Azure CI subscription (`warpbuild ci runners`) for each GitHub Actions job and
deletes it after the job. Required CI is **not** on this lane yet. Issue:
[popcre/ai-devops#961](https://github.com/popcre/ai-devops/issues/961).

Do not put secrets, API keys, signed vendor URLs, subscription GUIDs, or private
account identifiers in this public repository. Resolve live values with `az` and
1Password (`op run`) at use time.

## Live state (2026-10-02)

| Piece | State |
|---|---|
| Cloud connection | Verified on the dedicated CI subscription (Oracle/Teams-bot subscription stays frozen) |
| Stacks | `popcre-ci-use1` (eastus), `popcre-ci-use2` (eastus2), `popcre-ci-cus` (centralus) — all active |
| Runner sets | `warp-custom-win2022-canary` / `warp-custom-warpbuild-win2022-canary` (eastus); `warp-custom-win2022-use2` / `warp-custom-warpbuild-win2022-use2` (eastus2); `warp-custom-win2022-cus` / `warp-custom-warpbuild-win2022-cus` (centralus). On-demand, image `windows-server-2022`, arch x64 |
| Instance types (cheapest first) | `Standard_D4as_v4`, `Standard_D4s_v4`, `Standard_D4ds_v4` on every runner — fallback list, not a sum |
| Canary workflow | `.github/workflows/warpbuild-win2022-canary.yml` — manual `workflow_dispatch` only, non-required |
| Canary proof | Green 2026-09-30 and 2026-10-05 on eastus only: [run 36731941680 job 109943590499](https://github.com/popcre/ai-devops/actions/runs/36731941680/job/109943590499). Windows NT 10.0.20348, X64, git/pwsh/node/bash present; VM and OS disk deleted after the job |
| Multi-region canary | use2/cus **blocked** (2026-10-05): WarpBuild gallery image not in those regions (`GalleryImageNotFound`). Jobs queue forever; VM create loops and fails. |
| Required CI | **Still Blacksmith** (`blacksmith-4vcpu-windows-2025`). Practice-lane PR #1220 **MERGED 2026-10-02** (merge `5970c621`) — non-blocking `windows-offline-warpbuild-proof` beside Blacksmith required. Hard cut-over is still not landed. |
| Owner rule (2026-10-01) | **Blacksmith stays in the pool until WarpBuild is fully up.** Use Blacksmith for runs that would otherwise get stuck. Do not turn Blacksmith off. Do not stop WarpBuild bring-up. "Fully up" is a technical judgment (AI); only the cost choice is Albert's. |
| Owner rule (2026-10-02) | **No West Europe.** US regions only (eastus / eastus2 / centralus). |
| Azure quota (2026-10-02, eastus) | `standardDASv4Family` **8/10** vCPU, regional `cores` **8/12**. Fits **two** 4-vCPU VMs. Target 40 / 64 for ten. Quota is per family **and** per region. |
| Quota raise path | Programmatic support ticket is **blocked** on this subscription (`InvalidSupportPlan`, Free plan). `az quota` / Microsoft.Quota RP are not available. Portal **Usage + quotas → Request increase** is the working path. |

### Practice lane and post-merge verify (2026-10-02)

PR #1220 landed the **practice lane** (`windows-offline-warpbuild-proof`:
`continue-on-error`, `max-parallel: 2`, fork-guarded, label
`warp-custom-warpbuild-win2022-canary`). It is outside `verification-closure`.
Required Windows stayed on Blacksmith.

Post-merge full required Windows verify on main (`windows-offline-complete`,
run `37004196465`) was red on sections 1/2/4/5 — **not a WarpBuild regression**.
The same suites already failed on 2026-09-29 (run `36545978861`) before #1220.
Root causes are Windows platform test bugs (see pitfalls). Fixes: PR #1242
(`mimo/win-complete-suite-fix`). After that lands, re-dispatch verify on main
and post the green required job URL on #961.

### Practice lane is NOT the hard cut-over

An earlier hard cut of required `runs-on` to the WarpBuild label failed broadly
(`doc-safety`, `linux-offline-shard` 2/4, all `windows-offline-section` 1–8,
`windows-reviewer-fallback-*`, `verification-closure`). Do **not** re-point
required Windows until the full suite is proven green on BYOC and Blacksmith
remains a live fallback. Open sibling PR #1193
(`mimo/runner-pool-github-envy-warpbuild`) is a different routing preference
and must not silently drop WarpBuild or Blacksmith.

## Runbook

These steps encode the 2026-10-02 multi-region bring-up. Do not skip sync, and
do not pass signed URLs through `cmd.exe`.

### 0. Preconditions

- Dedicated CI subscription only (`warpbuild ci runners`). The Oracle/Teams-bot
  subscription stays frozen.
- WarpBuild API key is in 1Password vault `vibe_coding`. Resolve only via
  `1password_op_run` / `op run` with an `op://` reference. Never print it.
- `az account show` must already be that CI subscription.
- Quota is **per VM family per region** (`Standard DASv4` ≠ `Standard DSv4` ≠
  `Standard DDSv4`). Plan 4-vCPU boxes against each family's vCPU limit. One
  family in one region will not yield 24+ vCPUs on the default quota.
- US regions only: eastus, eastus2, centralus. **No West Europe** (owner
  2026-10-02).
- **Windows image is East US only (hard blocker, 2026-10-05).** WarpBuild
  community gallery `win-2022-x64-core` / `2026.09.2901` is not replicated to
  eastus2 or centralus. VM create fails with `GalleryImageNotFound`. Stacks can
  be created and stay `active`, but jobs never get a runner outside eastus
  until WarpBuild replicates the image (contact support@warpbuild.com). East US
  canary is the only proven region.

### 1. Create a stack (new region)

1. `POST /api/v1/stacks` with `alias`, `kind: "avm"`, `region`, existing
   `connection_id`, `onboarding_mode: "create"`.
2. Response is `status: pending` plus a `redirect` action whose
   `redirect_url` is an Azure portal deep link to a **short-lived signed** ARM
   template. If it expires, fetch a fresh one from
   `GET /api/v1/stacks/{id}/actions` (the detail body has no actions).
3. Extract the template URI (after `/uri/`, URL-decoded). Do **not** pass that
   URL on a `cmd.exe` command line — `&` in the SAS query splits the command
   and `az` cannot fetch it. Download the JSON with
   `Invoke-WebRequest -OutFile`, then:
   `az deployment sub create --location <region> --template-file <local.json> --name warpbuild-<alias>-<timestamp>`.
   Success is `provisioningState: Succeeded`. That creates the `wb-*` resource
   group, VNet, subnets, NAT, NSG, and storage account.
4. **ARM here is Azure Resource Manager**, not ARM64 CPU. Windows VMs stay x64
   (`Standard_D*`). Never change `arch` away from `x64` for this suite.
5. `POST /api/v1/stacks/{id}/sync` with `{}`. Without this the stack stays
   `pending` even after a successful ARM deploy. Confirm `GET /stacks` shows
   `status: active` and `avm_configurations` filled in.

### 2. Create a BYOC runner on a stack

`POST /api/v1/runners` with `name`, `labels` (include a `warp-custom-…` label
workflows can use), `provider_id` = stack id, and:

```json
"configuration": {
  "byoc_sku": {
    "arch": "x64",
    "is_public": true,
    "imdsv2_required": false,
    "instance_types": ["Standard_D4as_v4", "Standard_D4s_v4", "Standard_D4ds_v4"]
  },
  "storage": { "tier": "custom", "size": 150, "performance_tier": "P20" },
  "image": "windows-server-2022",
  "capacity_type": "ondemand"
}
```

- `instance_types` is a **priority fallback list**. Put cheapest first. It is
  not a capacity sum — concurrency is limited by Azure quota and job fan-out.
- Same shape works as `PATCH /runners/{id}` to update an existing set.
- `POST /custom-runners` does not exist; use `/runners`.
- Disk floor in vendor docs is 256 GB / P20; the live canary used 150 GB and
  passed the tooling canary only — reconfirm before required suites.

### 3. Run the canary

1. Point the canary workflow (or proof lane) at one of the `warp-custom-*`
   labels. Required Windows stays on Blacksmith.
2. Dispatch: `bin/ai-gh workflow run warpbuild-win2022-canary.yml` (or the
   Actions UI). It is `workflow_dispatch` only and must stay non-required.
3. Watch with `bin/ai-gh run view <run> --json status,jobs` (bounded; no
   `gh run watch`).
4. Pass criteria: job completes on a WarpBuild Windows runner, `git` / `pwsh` /
   `node` / `bash` present, X64, then the VM and OS disk are deleted.
5. If the job stays `queued` with empty `runner_name`, check runner-group
   public access first (below), then quota, then the stuck-canary section.

### 4. Updating labels / proof lane

Workflow `runs-on` and `config/ci-runner-routing.json` (`warpbuild_windows`)
must name the same label. Proof lane stays `continue-on-error`, fork-guarded,
and outside `verification-closure`. Keep Blacksmith as the required lane until
a reviewed cut-over.

## Pitfalls already paid for (do not repeat)

Everything in this section was learned the hard way across the 2026-09-28
bring-up, the 2026-09-30 canary/stuck-queue work, and the 2026-10-02
practice-lane land. Read it before touching stacks, runners, or the proof lane.

**First five minutes when something looks wrong**

1. Job `queued` with empty `runner_name` → runner-group public flag, then quota.
2. Job never appears in org runners → VM is booting or already dead; capture
   `C:\warpbuilds\runner.github.stdout.log` **now**.
3. Many proof jobs waiting → that is capacity (2 VMs × every open PR), not an
   outage. Do not "fix" it by moving proof jobs to Blacksmith.
4. A suite fails on `windows-offline-complete` but passed on the PR sections →
   Windows platform trap (section C), not WarpBuild.
5. Do not turn Blacksmith off to "force" WarpBuild to catch up.

### A. Standing up a stack / VM

| Mistake | What actually happens | Do this instead |
|---|---|---|
| Assumed ARM template = ARM64 CPU | ARM is Azure Resource Manager; VMs are still x64 | Keep `arch: x64` and `Standard_D*` |
| Passed signed template URL through `cmd.exe` / `az` | `&` splits the command; `az` cannot fetch the URL | Download template to a file, use `--template-file` |
| Trusted `status: pending` after ARM success | Stack never activates until WarpBuild syncs | `POST /stacks/{id}/sync`, then re-list |
| Used `GET /stacks/{id}` for the deploy link | Detail body has no `actions` | `GET /stacks/{id}/actions` |
| Signed template URL expired mid-flow | Deploy fails with a bad URI | Fetch a fresh `redirect_url` from `/actions`; do not cache SAS links |
| Treated `az vm list-usage` empty output as "no quota used" | Happens while `Microsoft.Compute` is still unregistered | Register the provider first, then re-read usage |
| PATCHed runner storage to 256 GB | API returned 200; disk stayed 150 GB | Re-read live size; vendor floor 256 GB is still unproven for the full suite |
| Assumed one family in one region covers 24+ vCPUs | Quota is **per family per region** (`DASv4` ≠ `DSv4` ≠ `DDSv4`) | Split across families and regions; cheapest first |
| Created a region we did not want | Extra spend / latency | US only: eastus, eastus2, centralus. **No West Europe** (owner 2026-10-02) |
| Left `wb-*` VMs or orphan disks around after a failed run | They eat quota and block the next job | Safe to delete when no canary/proof job is running |
| Assumed a new stack would run Windows jobs | VM create fails `GalleryImageNotFound` outside eastus | WarpBuild `win-2022-x64-core` image is eastus-only until they replicate it |

### B. Jobs stuck in `queued`

| Mistake | What actually happens | Do this instead |
|---|---|---|
| Runner online + correct label, job still queued for hours | Public repo needs runner-group public access | Set `allows_public_repositories=true` on the runner group (see below) |
| Guessed OS vs quota vs labels | Wastes hours | Read `runner.github.stdout.log` on the live VM (below) |
| Waited to capture logs | Ephemeral VM dies in ~40–120s after failed pickup | `az vm run-command` **immediately** with a tiny log-tail script |
| `az vm run-command` preempted / ResourceNotFound | A newer op wins; the VM is already gone | Retry once on the other `wb-*` VM; do not loop |
| Thought only 2 proof jobs were "stuck" | Every open PR adds 8 proof jobs; 2 VMs serve the whole org queue | Capacity fact, not a bug. Raise quota or accept the wait |
| Expected Blacksmith to take WarpBuild proof jobs | Proof lane has **no Blacksmith fallback by design** — it *is* the WarpBuild proof | Leave it; required CI already runs on Blacksmith |
| Assumed a green PR section path proves the full suite | `windows-offline-section` is **PR-only**; `windows-offline-complete` is the manual/schedule full suite | Always prove `windows-offline-complete` on main after a change |
| Left proof jobs queued across many PR commits | PR concurrency `cancel-in-progress` **discards** the queue when a new commit lands | More machines is the real fix; do not weaken required checks |

### C. Windows CI test traps (cost a full day on 2026-10-02)

These are not WarpBuild bugs — they are Windows platform differences that the
full suite exposes. Details live in `docs/development.md` ("Windows CI platform
differences"); the short version:

| Mistake | What actually happens | Do this instead |
|---|---|---|
| Asserted symlink behavior | `ln -s` falls back to a **copy** on Windows | Skip with a reason when `[ -L ]` is false |
| Asserted `chmod 600` mode bits | Git Bash maps it to `644` | Skip POSIX mode checks on MINGW/MSYS/CYGWIN |
| Mixed `realpath` and `pwd -P` across a stored path and a validator | `C:/Users/...` vs `/c/Users/...` never match; ~20 tests fail at once | Use the **same** resolver on both sides (`tests/lib-reviewer-approval.sh` is the reference) |
| Set `PATH=/usr/bin:/bin` in a test | jq disappears (it lives under `C:\Program Files\jq\`) | Add `$(dirname "$(command -v jq)")` when narrowing PATH |
| Ran Linux-only suites on Windows | Product prints `STOP … Linux-only` and the test fails | `exit 0` with a skip reason on non-Linux |

### D. Quota, cost, and support

| Mistake | What actually happens | Do this instead |
|---|---|---|
| Tried to open an Azure support ticket via API on this subscription | 202 then `InvalidSupportPlan` — Free plan cannot file tickets | Portal **Usage + quotas → Request increase** |
| Called `az quota create` / Microsoft.Quota RP | `MissingSubscription` / resource type not found | Same portal path; do not keep retrying the RP |
| Assumed quota is "Azure-wide" | It is per family per region | Measure `az vm list-usage --location <region>` before promising concurrency |
| Underestimated proof-lane demand | 8 jobs × every open PR against 2 VMs | Budget concurrency from quota, not from `max-parallel` alone |
| Compared WarpBuild cost to Blacksmith before invoices | Nothing is measured yet | Wait for real invoices before any cost decision |

### E. Safety / process (repeatedly binding)

- **Do not turn Blacksmith off** (owner, 2026-10-01) until WarpBuild is fully
  up **and** Albert makes a fresh cost decision.
- **Never** put secrets, API keys, signed vendor URLs, subscription GUIDs, or
  account emails in this public repo. Resolve live with `az account show` and
  `op run`. `C:\debuginit.txt` on a BYOC VM can contain credential blobs —
  do not paste it into chat or tickets.
- **Never** retrieve, type, or log an Azure password through an agent. The
  Microsoft consent link opens a real sign-in page.
- Two distinct grants exist: **directory admin consent** and an **Azure ARM
  template**. Preview exact roles/scopes before any infrastructure change;
  independent review APPROVE is required. Do not treat
  `ai-task-gates check` "no changes" output as permission to bypass that.
- Check **names** (`windows-offline`, `windows-offline-section (N, lane)`, …)
  must stay stable or required gates break. Keep
  `windows-offline-blacksmith.yml` usable as the manual escape hatch.
- Oracle / Teams-bot subscription stays frozen. Dedicated CI subscription only.
- No Spot for required-test evidence. Disk floor is 256 GB per vendor docs;
  the live canary used 150 GB and only proved the tooling canary.

## Public-repo runner group (hard requirement)

`popcre/ai-devops` is public. A self-hosted / BYOC runner only accepts jobs from
public repositories if its **runner group** has
`allows_public_repositories=true`.

Observed failure (2026-09-30): WarpBuild VMs booted, cloud-init succeeded, the
runner showed "Connected to GitHub" / "Listening for Jobs" with the correct
label, and the job stayed `queued` for hours. GitHub org **Default** runner
group had `allows_public_repositories=false`. Blacksmith groups already allowed
public. Fix applied live:

- Enabled `allows_public_repositories` on the Default group.
- Created runner group **WarpBuild BYOC** (id 6) with public allowed for future
  scoping. Ephemeral WarpBuild runners have been landing in Default; move them
  if/when WarpBuild can target a group.

If a job with a `warp-custom-*` label stays queued while a matching runner is
online, check runner-group public access first.

## Diagnosing a stuck BYOC canary

1. `bin/ai-gh run view <run> --json status,jobs` — if `queued` with empty
   `runner_name`, the pool is not picking up the job.
2. `az vm list` on the dedicated subscription. Rapid create/delete of `wb-*`
   VMs means bootstrap or pickup is failing; a healthy job holds one VM until
   the job ends, then deletes it.
3. Azure activity log shows WarpBuild's service principal running
   `CloudInitScriptExecution`. Capture `C:\debuginit.txt` and
   `C:\warpbuilds\runner.github.stdout.log` via `az vm run-command` **immediately**
   — VMs can die in under a minute after failed pickup.
4. Quota: the stack's region and the VM family (`standardDASv4Family`,
   `standardDSv4Family`, `standardDDSv4Family`) must both have room for a
   4-vCPU VM. Leftover `wb-*` VMs or orphan disks in the stack resource group
   are safe to delete when no canary job is running.

## Safety boundaries

- Independent review before any new Azure topology, role, or required-CI
  cut-over. The canary and the Default-group public flag were operational CI
  enablement on an already-approved dedicated subscription, not a new grant.
- Required workflows stay on Blacksmith until a reviewed cut-over proves the
  full Windows suite on BYOC and invoices meet the cost goal. Preserve
  `config/ci-suite-manifest.json` fan-out and reviewer safeguards.
- No Spot for required-test evidence. Disk floor is 256 GB per vendor docs;
  the live canary runner was created at 150 GB and still passed the tooling
  canary — reconfirm before assuming required suites fit.
