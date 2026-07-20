# Monitor Signals

- Queue jam: the same path appears in `RedoEvent` or `PullEvent` at least five times in ten minutes, no `DoneEvent` follows, and the session remains enabled.
- Basis corruption: `PrepareDownloadFile` reports hash `31d6cfe0d16ae931b73c59d7e0c089c0`.
- Transport instability: repeated error code 26, daemon-status failures, or domain-socket failures.
- Hidden lag: a timestamped canary written on the source arrives late or not at all on a destination.

Emit source, destination, share, exact path, pattern, first/last seen, repeat count, and recommended next action.
