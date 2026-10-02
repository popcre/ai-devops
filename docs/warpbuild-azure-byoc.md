# WarpBuild Azure BYOC Windows CI

WarpBuild BYOC creates a fresh Windows Server 2022 VM in POP Creations' dedicated
Azure CI subscription (`warpbuild ci runners`) for each GitHub Actions job and
deletes it after the job. Required CI is **not** on this lane yet. Issue:
[popcre/ai-devops#961](https://github.com/popcre/ai-devops/issues/961).

Do not put secrets, API keys, signed vendor URLs, subscription GUIDs, or private
account identifiers in this public repository. Resolve live values with `az` and
1Password (`op run`) at use time.

## Live state (2026-10-01)

| Piece | State |
|---|---|
| Cloud connection | Verified on the dedicated CI subscription (Oracle/Teams-bot subscription stays frozen) |
| Stack | `popcre-ci-use1` (eastus), active |
| Runner set | `warp-custom-win2022-canary` / `warp-custom-warpbuild-win2022-canary` (id `wts3yujcycg8o15x`), on-demand Standard_D4as_v4, image `windows-server-2022` |
| Canary workflow | `.github/workflows/warpbuild-win2022-canary.yml` — manual `workflow_dispatch` only, non-required |
| Canary proof | Green 2026-09-30: [run 36731941680 job 109943590499](https://github.com/popcre/ai-devops/actions/runs/36731941680/job/109943590499). Windows NT 10.0.20348, X64, git/pwsh/node/bash present; VM and OS disk deleted after the job |
| Required CI | **Still Blacksmith** (`blacksmith-4vcpu-windows-2025`). Cut-over PR `mimo/warpbuild-required-cutover` / #1220 is **not merged**; latest checks failed broadly (see below). |
| Owner rule (2026-10-01) | **Blacksmith stays in the pool until WarpBuild is fully up.** Use Blacksmith for runs that would otherwise get stuck. Do not turn Blacksmith off. Do not stop WarpBuild bring-up. |

### Cut-over attempt (not landed)

Branch `mimo/warpbuild-required-cutover` re-points required Windows `runs-on` to the WarpBuild label. PR #1220 was opened/closed/reopened several times. Latest verification on that branch failed: `doc-safety`, `linux-offline-shard` 2/4, all `windows-offline-section` 1–8, `windows-reviewer-fallback-*`, `verification-closure`. Do not merge those changes until the failures are diagnosed and Blacksmith remains a live fallback per the owner rule. Open sibling PR #1193 (`mimo/runner-pool-github-envy-warpbuild`) is a different routing preference and must not silently drop WarpBuild or Blacksmith.

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
4. Quota: East US `standardDASv4Family` / regional cores must have room for a
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
