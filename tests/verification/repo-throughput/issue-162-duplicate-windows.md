# Issue #162 duplicate Windows verification evidence

## Baseline and ownership

Run `34237405958` tested pull-request head
`a9417c273701a73e7ad12c143ae8bc4f2f42942e` on 2026-09-08. Its hosted
Windows job passed after 95 minutes. The Bash phase ran all 66 then-declared
suites in 5,637 seconds; the same suites took 686 seconds in the Linux job.
The 18 PowerShell suites took about 43 seconds.

The two suites already owned by the parallel `windows-reviewer-safety` job
were the largest duplicated block: Codex review took 318 seconds and Grok
review took 1,149 seconds in `windows-offline`, or 1,467 duplicated seconds.

The schema-2 suite manifest is the assertion map:

- `bash` is complete discovery: 67 suites after this change's new injection
  test. Linux, scheduled/manual Windows, qualification, and local no-argument
  verification still run all of them.
- `windows_sensitive_bash` contains 23 conservative platform-sensitive suites.
  Selection retained any suite that exercises or depends on Git Bash paths,
  CRLF, `cygpath`, `USERPROFILE`/`AppData`, Windows ACLs, PowerShell, native
  process trees, Windows symlink behavior, or Windows installer behavior.
- `windows_reviewer_safety_bash` names the Codex and Grok early-signal repeat.
  Issue #260 owns removing that intentional overlap with a failover contract.
- `windows_offline_bash` owns all 23 Windows-sensitive suites. Their measured
  baseline sum was 4,763 seconds. The remaining 44 Bash suites are
  still complete on Linux and all full-matrix backstops.
- `powershell` remains complete discovery: all 18 suites run in every Windows
  offline job.

`tests/test-workflow-policy.sh` proves that discovery and the manifest are
identical, all Windows groups are unique subsets, hosted Windows equals the
full Windows-sensitive set, and the reviewer list matches its manifest subset.
A stale, duplicate, or invalid mapping fails closed.

## Event map

| Event | Before | After |
|---|---|---|
| pull request | all Bash plus all PowerShell in `windows-offline`; Codex/Grok repeated in reviewer lane | 23 Windows-sensitive Bash plus all PowerShell; Codex/Grok early-signal repeat remains owned by #260 |
| merge group | Linux compatibility gate; both Windows jobs skipped | unchanged; run `34259726634` passed the gate in about 12 minutes |
| schedule | all Bash plus all PowerShell, plus reviewer lane | unchanged complete backstop |
| manual | all Bash plus all PowerShell, plus reviewer lane; exact-SHA success reuse | unchanged complete backstop |
| runner qualification | all Bash plus all PowerShell | unchanged complete qualification |
| push to `main` | no workflow trigger | unchanged; policy rejects reintroducing duplicate post-merge proof |

The concurrency identity is intentionally unchanged: obsolete pull-request
proof cancels by PR number; merge groups keep per-queue-ref evidence; manual
runs keep immutable-SHA identity and cannot cancel one another.

## Failure and line-ending proof

`tests/test-windows-bash-selection.sh` injects a nonzero Windows-assigned suite
and proves both selected and no-argument runs fail. It also proves stale and
duplicate assignments return configuration error 2 rather than silently
dropping or repeating coverage. `tests/test-line-endings.sh` remains in the
Windows-sensitive set and continues to use `git ls-files --eol` for committed
and checked-out shell content.

## Verification

- Focused selection, workflow-policy, line-ending, local-selection, and runner
  qualification checks passed. The final exact-head rerun recorded 6/6
  Windows-selection cases and the complete workflow-policy contract green.
- Complete guarded local offline verification ran all 67 Bash and 18
  PowerShell suites. PowerShell passed 18/18. Bash passed 66/67 under five-way
  load; the sole miss was the preflight suite's under-ten-second Kimi timing
  assertion. The complete preflight suite then passed 78/78 both directly and
  through the guarded one-worker runner, proving the assertion remains active
  and the loaded miss did not hide a behavior failure.
- Pull request #339 is the immutable acceptance record: its final-head Linux,
  hosted Windows, and independent reviewer-safety jobs all passed before merge.
  The merge queue then retested the exact tree that landed on `main`; no
  post-merge push matrix repeated that proof.

The 2026-09-07 scheduled run `34122199011` is not misreported as green: its
Grok suite had two transient failures while the simultaneous reviewer-safety
copy passed. Issue #307 remains open until a later scheduled run passes. Later
complete pull-request matrices, including `34237405958`, passed the same full
Windows suite; this change does not suppress that incident or weaken the
scheduled backstop.
