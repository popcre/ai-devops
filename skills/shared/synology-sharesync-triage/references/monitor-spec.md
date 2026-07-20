# Synology Monitor ShareSync Spec

Build monitoring around five checks:

1. Pair health from `sys.sqlite`: peer, share, `linked`, `status`, `error`, and `is_daemon_enable`.
2. Queue jams: repeated retry events for one path without a matching `DoneEvent`.
3. Basis corruption: the empty-file MD5 in `PrepareDownloadFile` output.
4. Transport flaps: repeated error code 26, daemon-status, or socket failures.
5. End-to-end canaries: timestamped source markers with destination arrival thresholds.

Use `critical` for basis corruption, path loops, and overdue canaries; `warning` for repeated transport failures; and `info` for disabled sessions, unlinked pairs, or queue-depth drift. Include evidence and a narrow remediation hint in every alert.
