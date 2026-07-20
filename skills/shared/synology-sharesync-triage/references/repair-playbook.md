# Repair Playbook

## Preconditions

- Work only on the destination NAS.
- Have root-capable access and explicit approval for the row deletion.
- Prove the exact stuck path first.
- Try the safe move-rename-wait-move-back unstick when applicable.

## Sequence

1. Create a timestamped backup directory under `/volume1/@SynologyDriveShareSync/`.
2. Copy `sys.sqlite`, `history.sqlite`, and existing WAL/SHM companions into it.
3. Verify each expected backup exists and is non-empty.
4. Stop ShareSync:

```sh
/var/packages/SynologyDrive/target/sharesync/bin/srvctl --stop
```

5. Delete only exact-path `history_table` rows, recording before and after counts.
6. Start ShareSync:

```sh
/var/packages/SynologyDrive/target/sharesync/bin/srvctl --start
```

7. Recheck the stale count, logs, destination file, and later `DoneEvent` progress.

If anything fails after stopping the service, attempt the restart and report both the original failure and restart result.
