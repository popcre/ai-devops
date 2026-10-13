<!-- handoff-contract
issue: none
status: DONE
owner: mimo/1547-wrapup-edge-dev3-lab-cleanup
-->

# edge-dev3 lab-1547 cleanup after #1547

## 0. BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

None. Delete or keep the disposable lab folder on `edge-dev3` is an operator
cleanup choice; default is delete after confirming the VM is unused.

## 1. What this application is

Not an application. This is leftover throwaway lab infrastructure created to
investigate [popcre/ai-devops#1547](https://github.com/popcre/ai-devops/issues/1547)
(SSH token posture on Windows runners). The issue is **closed** (2026-10-12).
No Microsoft regression exists; stock Windows OpenSSH already elevates local
admins. The lab is no longer required for that investigation.

## 2. What we set out to do this session, and why

Albert asked for root-cause work on #1547 (SSH sessions elevated when they
should be filtered), then authorized solving it. Mid-session the `edge-dev3`
lab session reversed the diagnosis and closed #1547. This wrap-up records the
remaining **lab cleanup** so ~130GB on `edge-dev3` is not forgotten.

## 3. Current state — what is true right now

- [#1547](https://github.com/popcre/ai-devops/issues/1547) is **CLOSED**
  (2026-10-12). Conclusion: no Windows servicing regression; stock OpenSSH
  gives local admins a full elevated Network logon token.
- Documentation correction landed on `origin/main` via
  [PR #1624](https://github.com/popcre/ai-devops/pull/1624) (`f93ea115`):
  plan, runbook, and `qualify-windows-runner.ps1` posture note.
- Earlier related merges: [PR #1555](https://github.com/popcre/ai-devops/pull/1555),
  [PR #1576](https://github.com/popcre/ai-devops/pull/1576).
- **Lab cleanup COMPLETED** on host **`edge-dev3`** (2026-10-13, MiMo wrap-up):
  - Final `ls` / `du` confirmed `/home/ahazan/lab-1547/` (~130GB) held only lab
    assets (Win11 ISOs, disk images, boot probe scripts, screenshots).
  - Docker containers **`lab-1547-qemu`** and **`lab-1547-old`** were
    **Exited (0)** and are now removed (`docker rm`).
  - `/home/ahazan/lab-1547/` is **deleted** (verify: path does not exist).
  - No `lab-1547` or lab QEMU images remain on `edge-dev3`.
  - 1Password item `labadmin - lab-1547 QEMU Windows VM (edge-dev3, disposable)`
    (`jzenegsm2nt7brxoeotsnizkx4`) is **archived** in vault `vibe_coding`.
- Prior lab notes (historical): QEMU ran inside Docker with `--ulimit
  memlock=-1` and `/dev/kvm` (host QEMU hits `Failed to initialize io_uring:
  Cannot allocate memory` because `ulimit -l` is 8192). Windows was never
  installed on the lab disk.

## 4. Everything we tried that did NOT work

- Host `qemu-system-x86_64` on `edge-dev3` without Docker: io_uring memlock
  failure (fixed only inside Docker with unlimited memlock).
- Booting the raw Microsoft ISO as virtio/USB/SCSI CD: OVMF timeouts or
  `0xc000000f` Recovery (BCD cannot see `sources\boot.wim` on the wrong volume).
- Flat FAT32 installer without GPT/ESP: `BdsDxe: No bootable option`.
- GPT+ESP FAT installer (`win11-gpt.img`): firmware **starts** the USB/virtio
  device (TianoCore splash) but Windows Setup never completed; target
  `lab-1547.qcow2` stayed ~384KB. Windows was never installed.
- Creating PRs with `gh` PAT: `Resource not accessible by personal access token`;
  `bin/ai-gh` hung on throttle locks but did create
  [PR #1624](https://github.com/popcre/ai-devops/pull/1624).

## 5. Root causes and key findings

- **#1547 finding (authoritative, closed):** Windows SSH has always given a
  local admin a full elevated token. The older "filtered" claim (#262) was not
  reproduced and had no command output. Lab VM matched elevated before and
  after KB5124007/KB5126052/KB5129195.
- Do **not** file a Microsoft regression. Do **not** set
  `LocalAccountTokenFilterPolicy`, enable Windows sudo, or weaken UAC.
- Operating posture (still in force): treat SSH as host-admin; measure token
  posture in host proofs; negative privilege tests only from a proven
  non-elevated context.

## 6. Exact next steps

Lab teardown steps 1–3 (was: inventory, `docker rm`, delete
`/home/ahazan/lab-1547/`, archive the labadmin 1Password item) are **done and
verified**. Remaining bookkeeping only:

1. Land this handoff on `origin/main` via
   [PR #1627](https://github.com/popcre/ai-devops/pull/1627) (docs-only).
   That PR is **blocked** while
   [issue #1631](https://github.com/popcre/ai-devops/issues/1631) keeps
   `doc-safety` red on every merge-group run (from #1626 tracking
   `.ai/reviewer-issues` on main). Do not use `--admin`.
2. After PR #1627 is MERGED and
   `HANDOFF.d/2026-10-12T1915Z-edge-dev-mimo-lab-1547-cleanup.md` is on
   `origin/main`, delete this file on a small docs PR (successor rule).
3. After the branch is merged, remove worktree `C:/tmp/wt-1547-correct` if
   its tree is still clean (use `cleanup-worktree`).

## 7. Constraints and gotchas in force

- Never weaken UAC, remote-token filtering, or set
  `LocalAccountTokenFilterPolicy`; never enable Windows sudo.
- Never use lab credentials on production or CI runners.
- Do not reopen #1547 for the Microsoft story; that conclusion is settled.
- `bin/ai-gh` may stall on lock reclaim; plain `gh` can read PRs/issues but its
  PAT cannot create pull requests.
- Host QEMU on `edge-dev3` needs Docker `--ulimit memlock=-1` (and KVM device).

## 8. Access and environment

- Host: `edge-dev3` (Linux, Tailscale alias `edge-dev3`, user `ahazan`, SSH key
  `~/.ssh/916-alien` from `edge-dev`). Lab root `/home/ahazan/lab-1547/` is gone.
- Password item archived (was 1Password vault `vibe_coding`,
  `labadmin - lab-1547 QEMU Windows VM (edge-dev3, disposable)`).
- Repo: https://github.com/popcre/ai-devops — this checkout is `C:/repos/ai-devops`.

## 9. Open questions and risks

- None on `edge-dev3` disk pressure (lab deleted). Residual risk is only
  PR #1627 / this handoff waiting on #1631 so `doc-safety` can go green.
- If anyone still wants a Windows KB bisect for curiosity, rebuild a lab from
  the closed-issue notes; do not treat #1547 as open work.

---

## Mandatory self-audit gate

1. Business-only decisions called out? **Yes** (section 0).
2. Durable findings written? **Yes** (#1547 conclusion, no-MS-report, posture).
3. Next steps concrete and cold-readable? **Yes** (section 6).
4. Constraints listed? **Yes** (section 7).
5. Access/environment complete? **Yes** (section 8).
6. GitHub URLs used for repo files/issues/PRs? **Yes**.
7. Contract block at top? **Yes** (`issue: none` — cleanup only, product issue
   #1547 closed; this file tracks lab teardown).
8. No secrets printed in this file? **Yes** (password not inlined).
9. Successor can act without chat context? **Yes**.
