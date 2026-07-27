---
name: synology-long-running-operations
description: Run non-destructive Synology NAS operations that are expected to exceed the Synology Monitor MCP run_command 25-second budget without weakening its safety timeout. Use for whole-volume or large-subtree find scans, inventories, hashing, audits, large log processing, or any safe NAS read that timed out or predictably will time out; use managed SSH only when no native NAS background-job capability exists.
---

# Synology Long-Running Operations

Keep interactive diagnostics short while making expensive reads durable,
observable, and deliberately low impact. “Read-only” describes mutation risk,
not CPU, memory, or disk-I/O cost.

## Decision order

1. Estimate whether the command can finish inside 25 seconds. Treat a prior
   timeout, a whole-volume traversal, millions of paths, recursive hashing, or
   a 56 TB filesystem walk as long-running.
2. Prefer an existing named Synology Monitor capability with tuned scope.
3. Prefer a native NAS background job when one exists: start it, poll status,
   then fetch its compact result.
4. If neither exists, obtain explicit approval for the broad read and use the
   managed SSH alias for the exact NAS. Do not increase or bypass the MCP
   timeout.
5. If the operation will recur, finish the immediate authorized task safely,
   then recommend a native NAS API background-job capability as the permanent
   product solution.

## Preflight

- Resolve and state the exact NAS and scan root. Never broaden an ambiguous
  request to both NASes or all volumes.
- Verify SSH non-interactively and confirm the remote hostname.
- Check that no equivalent job is already running.
- Check available priority controls. Use `nice -n 19`; add idle-class `ionice`
  only when the NAS actually provides it. Do not claim I/O throttling when only
  CPU niceness is available.
- Choose a unique job directory under the owning application's durable
  operations area. For Synology Monitor manual reports, use
  `/volume1/docker/synology-monitor-agent/manual-scans/<descriptive-job-id>/`.
  Refuse to overwrite an existing directory.
- Do not use privileged access merely to suppress permission errors. Record
  inaccessible paths; decide separately whether privileged coverage is needed.

## Launch contract

Run the exact read in a detached process and persist:

- `started-at.txt`
- `scan.pid`
- incremental primary output
- separate `stderr`
- an exit-code file and `completed-at.txt` when the wrapper finishes
- a compact summary derived only after successful completion

Use `nohup`, disconnected stdin, and the lowest practical priority. Quote every
path. Keep the command read-only against user data; report files and job-state
files are the only authorized writes. Never add deletion, repair, permission
changes, service restarts, or database mutations to a safe-read request.

If the SSH launch fails after creating an empty job directory, either reuse it
only after proving it contains no results or choose a new unique identifier.
Report the failed launch; do not silently leave a mystery job.

## Monitor and finish

1. Immediately verify the recorded PID, hostname, exact command, priority, and
   growth of output/error files.
2. For a request to “run” or “finish” the job, keep checking until it exits.
   Backgrounding is an execution method, not proof of completion.
3. Treat permission errors, killed processes, full disks, and absent exit-code
   markers as incomplete coverage. Quantify and explain them.
4. Validate the result before recommending action. For filesystem cleanup,
   separate Synology metadata (`@eaDir`), system/application trees (`/@...`),
   recycle/snapshot trees, and user-visible paths.
5. When Synology Drive or ShareSync could explain missing content, use
   `synology-sharesync-triage` and compare source/destination evidence before
   proposing deletion.
6. Report the job directory, PID, start/end time, exit code, complete counts,
   excluded/inaccessible scope, and whether any user data changed.

## Safety boundary

- Do not weaken the MCP's 25-second command timeout or 45-second tool deadline.
- Do not confuse “non-destructive” with “safe at any load.” Broad metadata reads
  require explicit approval and production-load awareness.
- Do not delete empty directories from a raw `find -empty` report. Synology
  metadata, package state, sync-created structure, permissions, mount points,
  and transient application directories require classification first.
- Do not call a partial or timed-out result complete.
