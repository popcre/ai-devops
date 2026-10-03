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
| Canary proof | Green 2026-09-30 on eastus: [run 36731941680 job 109943590499](https://github.com/popcre/ai-devops/actions/runs/36731941680/job/109943590499). Windows NT 10.0.20348, X64, git/pwsh/node/bash present; VM and OS disk deleted after the job |
| Required CI | **Still Blacksmith** (`blacksmith-4vcpu-windows-2025`). Cut-over PR `mimo/warpbuild-required-cutover` / #1220 is **not merged**; latest checks failed broadly (see below). |
| Owner rule (2026-10-01) | **Blacksmith stays in the pool until WarpBuild is fully up.** Use Blacksmith for runs that would otherwise get stuck. Do not turn Blacksmith off. Do not stop WarpBuild bring-up. |
| Owner rule (2026-10-02) | **No West Europe.** US regions only (eastus / eastus2 / centralus). |

### Cut-over attempt (not landed)

Branch `mimo/warpbuild-required-cutover` re-points required Windows `runs-on` to the WarpBuild label. PR #1220 was opened/closed/reopened several times. Latest verification on that branch failed: `doc-safety`, `linux-offline-shard` 2/4, all `windows-offline-section` 1–8, `windows-reviewer-fallback-*`, `verification-closure`. Do not merge those changes until the failures are diagnosed and Blacksmith remains a live fallback per the owner rule. Open sibling PR #1193 (`mimo/runner-pool-github-envy-warpbuild`) is a different routing preference and must not silently drop WarpBuild or Blacksmith.

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
  2026-10-02). Vendor docs once said Azure BYOC was East US only; East US 2
  and Central US stacks were created successfully via the API in 2026-10.

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

| Mistake | What actually happens | Do this instead |
|---|---|---|
| Assumed ARM template = ARM64 CPU | ARM is Azure Resource Manager; VMs are still x64 | Keep `arch: x64` and `Standard_D*` |
| Passed signed template URL through `cmd.exe` / `az` | `&` splits the command; `az` cannot fetch the URL | Download template to a file, use `--template-file` |
| Trusted `status: pending` after ARM success | Stack never activates until WarpBuild syncs | `POST /stacks/{id}/sync`, then re-list |
| Used `GET /stacks/{id}` for the deploy link | Detail body has no `actions` | `GET /stacks/{id}/actions` |
| Expected one family in one region to cover 24+ vCPUs | Quota is per family per region | Split across DASv4 / DSv4 / DDSv4 and regions; cheapest first |
| Created a region we did not want | Extra spend / latency | US only: eastus, eastus2, centralus. **No West Europe** |
| Queued job while runner looked online | Public repo + runner group | Set `allows_public_repositories` on the group |

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
