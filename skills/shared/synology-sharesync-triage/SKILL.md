---
name: synology-sharesync-triage
description: Diagnose and repair Synology Drive ShareSync stalls, repeated single-file syncing, destination-side basis-file corruption, connection-26 flaps, and hidden queue jams across source and destination NASes. Use when a share looks stuck, a file is missing on a replica, ShareSync shows syncing one file for a long time, or the user wants proof of root cause and a targeted fix.
---

# Synology ShareSync Triage

Prove whether the fault is pairing, transport, live transfer, or destination queue state. Prefer exact paths, hashes, log lines, and database rows over guesses. Use the configured `synology-monitor` MCP for read-only evidence when it exposes the needed data; use the managed NAS SSH aliases only when deeper inspection is required.

## Workflow

1. Confirm the source and destination file state and hashes.
2. Confirm the ShareSync pairing from `sys.sqlite`.
3. Inspect `dscc_monitor.log` for connection failures.
4. Inspect `dscc.log` for file-specific retry loops and later progress.
5. Classify the blocker as pairing, transport, queue corruption, or live transfer.
6. Try the safe file-level unstick first when appropriate: move the stuck source file out, rename it, wait for sync, then move it back.
7. If exact evidence shows stale destination queue state and the safe unstick fails, propose the targeted database repair below.

## Evidence locations

- Database root: `/volume1/@SynologyDriveShareSync/db`
- Logs: `/volume1/@SynologyDriveShareSync/log/dscc.log` and `dscc_monitor.log`
- Control binary: `/var/packages/SynologyDrive/target/sharesync/bin/srvctl`

Read `connection_table`, `session_table`, and `server_view_table` in `sys.sqlite`. A healthy definition has a destination connection for the source, `linked=1`, the expected share name, `status=1`, and `error=0`. Do not blame pairing when those facts are correct without stronger evidence.

## Failure patterns

- Transport flap: repeated `failed to get daemon status`, `open domain socket fail`, `Switch connection`, disconnected/recovered states, or error code 26.
- Queue jam: the same path repeatedly produces `RedoEvent`, `PullEvent`, `download it`, or `PrepareDownloadFile`, with no later `DoneEvent`.
- Basis-file corruption: `PrepareDownloadFile` reports `file_hash = 31d6cfe0d16ae931b73c59d7e0c089c0`, the MD5 of an empty file. Treat this as destination-side stale basis or queue state.
- Live transfer failure: isolated code `-2` I/O or code `-1` interrupted errors. If later `DoneEvent` lines appear, the queue is draining; do not overreact.

## Targeted repair

Perform this only on the destination NAS with root-capable access, only for an exact proven path, and only after explicit user approval because it deletes local ShareSync database rows.

1. Back up `sys.sqlite`, `history.sqlite`, and any `history.sqlite-wal` or `history.sqlite-shm` files to a timestamped directory on the same NAS.
2. Verify the backup files exist and are non-empty before continuing.
3. Stop ShareSync.
4. Count and delete only `history_table` rows whose path exactly equals the proven stuck path.
5. Restart ShareSync even if a later verification step fails.
6. Verify the stale row count is zero, the old retry loop stopped, newer `DoneEvent` lines appear, and the destination file state is correct.

Never delete broad row sets or recreate the whole task before the narrow options fail. Report loudly if any command, backup, restart, or verification fails.

## Report

State the classification, exact stuck path, decisive database and log evidence, whether later events are progressing, whether the target file arrived, and the narrow next action.

## References

- Read [references/sqlite-queries.md](references/sqlite-queries.md) for exact read and narrow-delete queries.
- Read [references/repair-playbook.md](references/repair-playbook.md) before any database repair.
- Read [references/monitor-signals.md](references/monitor-signals.md) when defining alerts.
- Read [references/monitor-spec.md](references/monitor-spec.md) when building or extending automated ShareSync monitoring.
- Read [references/triage-prompt-template.md](references/triage-prompt-template.md) when handing the workflow to another AI tool.
