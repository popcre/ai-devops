# Triage Prompt Template

```text
Use the synology-sharesync-triage workflow. Prove whether this is pairing, transport, live transfer, or destination queue state using exact file hashes, ShareSync database rows, and log lines. Detect connection-26 loops, daemon/socket failures, repeated retry events, empty-file basis hashes, and later DoneEvent progress. Prefer the safe file-level unstick. Do not alter ShareSync database state without showing the exact path, verifying a backup, and receiving explicit approval. Report the decisive evidence and narrowest next action.
```
