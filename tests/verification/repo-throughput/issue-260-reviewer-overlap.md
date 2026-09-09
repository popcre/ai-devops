# Issue #260 — fail-closed Windows reviewer-lane split

## Baseline

- Exact-head run `34299171284` at `d8317bfd` completed the hosted
  `windows-offline` step in 81m15s. Codex consumed 293s and Grok 1075s, so the
  duplicated reviewer work cost 22m48s and the remaining measured matrix was
  58m27s.
- Earlier ordinary hosted runs were 72–75 minutes when Grok met its normal
  timing. Runs `33809598271` and `33821226383` demonstrate the worse case:
  hosted Grok missed concurrency windows while the same-commit qualified lane
  passed.

## Assignment and fallback contract

- The manifest remains the complete source: 23 Windows-sensitive Bash suites.
- Ordinary hosted pull-request execution subtracts exactly Codex and Grok; the
  qualified self-hosted lane owns those two suites.
- A hosted watcher observes the reviewer job. Skip/failure, no start within 10
  minutes, or no completion within 32 minutes releases a hosted fallback that
  runs both omitted suites. Scheduled, manual, qualification, and direct
  no-argument execution remain complete.

## Injected failures

- `tests/test-windows-bash-selection.sh` injects a failing reviewer suite. The
  split hosted selection omits it, the unchanged complete selection catches it,
  and exclusion outside the Windows pull-request mode fails closed.
- `tests/test-workflow-policy.sh` rejects deletion of the fallback result gate
  and deletion of the queued-job deadline. It also proves the ordinary lane
  assignments are disjoint and their union is the complete Windows-sensitive
  set.

## After measurement

Pending the first exact-head pull-request run. Record the run, SHA, hosted job
duration, reviewer job duration, and whether the fallback was correctly skipped
or released before merge.
