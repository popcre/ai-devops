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
  minutes, or no completion within 42 minutes releases a hosted fallback that
  runs both omitted suites. A watchdog error also releases the fallback rather
  than treating its missing output as success. Scheduled, manual, qualification, and direct
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

Pull-request run `34366159903` at `c425583a` passed all executed jobs:

- Hosted `windows-offline`: 60m42s job / 60m31s test step, down 20m44s
  (25.5%) from the 81m15s baseline step.
- Qualified `windows-reviewer-safety`: 18m36s job / 18m28s test step.
- The hosted watcher observed reviewer success and passed in 21m21s;
  `windows-reviewer-fallback` correctly skipped.
- Linux passed in 11m36s. The workflow completed successfully without a local
  suite competing with any active Windows runner.

## Merge-queue dependency repair

Merge-group runs `34385010191`, `34385198205`, and `34385457668` were ejected
before project tests because the runner's unrelated Google Chrome apt feed
served a package index whose hash did not match its release file. The Linux job
now refreshes Ubuntu's signed source only before installing the same `jq`,
`ripgrep`, and `shellcheck` packages; policy mutation proves the third-party
source isolation cannot disappear silently.

## Live fallback proof

Run `34387666739` made the qualified lane fail on the known Grok
timing assertions after 223 passes. The watchdog detected the failure and
started `windows-reviewer-fallback` on `windows-2025`, proving the live failure
route. The fallback reached Grok but its initial 30-minute job ceiling cancelled
the process before completion; prior hosted evidence measured Grok alone at
41m20s. The fallback ceiling is therefore 60 minutes: bounded above that
measured worst case without changing or weakening any assertion.

## Corrected-head local verification

Commit `5f64ad8b` passed the focused workflow policy suite, the 12-case Windows
Bash selection and injected-failure suite, and all 79 task-gates assertions.
The PowerShell guard requires its exact refusal message when `pwsh` is present
and skips explicitly on Linux hosts where PowerShell 7 is not installed.
