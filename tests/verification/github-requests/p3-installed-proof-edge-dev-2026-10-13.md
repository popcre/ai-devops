# P3 managed-caller installed proof — edge-dev, 2026-10-13

Owner: [#931](https://github.com/popcre/ai-devops/issues/931), [#933](https://github.com/popcre/ai-devops/issues/933), [#936](https://github.com/popcre/ai-devops/issues/936), under [#658](https://github.com/popcre/ai-devops/issues/658).

Host: `edge-dev` (Windows 11, the `edge-dev-win` GitHub Actions runner host).
Time: 2026-10-13, approximately 3:32 PM – 4:09 PM EDT.
Repository HEAD at proof time: `4ae0f464ffa9825121b5435ae80fa52960e0a53a` (contains PR #973 as `9cf87d4` and PR #935 as `42f423f9`).

This record covers the bounded installed operations required before #931/#933/#936 may close. It is source-coverage acceptance for the P3 caller routing; it does not claim fleet-wide quota acceptance or section-13 measured savings.

## Installed file hashes (edge-dev checkout `C:\repos\ai-devops`)

| File | SHA-256 |
|---|---|
| `bin/runner-github-admission.ps1` | `f160edcbd48a722d99f75f690c3c14bf9f026454fb43db1d7952e16cd38d05cf` |
| `bin/ai-gh` | `d6c5d3228cb0299ce721fff2814bd756206803c5af077ff02d56c62952d23cfa` |
| `C:\actions-runner\.runner` | `d764ecf02076cb351a6e9300aae3ceb6dd5760fcad6bd2a70831c46135cce4dc` |

PR #935 merge commit `42f423f9af17fa9ecbf35a861e27c057fafd1f58` is an ancestor of HEAD.
PR #973 merge commit `9cf87d46e73642332c22a516faf843836503a7fd` is an ancestor of HEAD.

## #931 — bounded installed operations for each P3 changed capability

Each operation was run from the installed checkout on `edge-dev` and recorded in
`~/.ai-devops/gh-throttle/measurements/2026-10-13.jsonl` with its fixed caller
label. No responses were cached; each call used fresh `ai-gh` admission.

| Capability | Operation | Result | Telemetry caller label | Time (UTC) |
|---|---|---|---|---|
| `ai-test-local` runner collision | `ai-test-local --check-collision` | `clear — this host's runner(s) are idle: edge-dev-win` | `ai-test-local` | 15:33:05Z |
| `ai-workspace-status` | `ai-workspace-status` | Completed; showed branch/PR status | `ai-workspace-status` | 15:33:29Z |
| `ai-reviewer-membership-drift` | `node bin/ai-reviewer-membership-drift.cjs` | `OK reviewer membership matches the shared-db allocator: deepseek, gemini, glm, grok, muse, qwen, stepfun` | `ai-reviewer-membership-drift` | 15:34:42Z |
| `ai-verify-run` status | `ai-verify-run status --repo popcre/ai-devops` | Listed 20 recent workflow runs with IDs, events, statuses, and SHAs | `ai-verify-run` | 15:38:06Z |
| `ai-merge-group-evidence` | `ai-merge-group-evidence --ref refs/heads/gh-readonly-queue/main/pr-1671-… --merge-group-sha 1cc10b53…` | `pull request 1671 has no readable live merge-queue entry` (expected: already merged; path entered admission and failed safe) | `ai-merge-group-evidence` | 15:43:06Z, 15:43:17Z |
| `ai-transcript-destination-check` | `ai-transcript-destination-check /c/repos/ai-devops-transcripts` | `PASS: canonical private transcript destination verified` (privacy read via `ai-gh`) | `ai-transcript-destination-check` | 15:53:58Z |
| `ai-memory-sync` privacy | `AI_GH_CALLER=ai-memory-sync bin/ai-gh api repos/u2giants/ai-devops-memory --jq .private` | `true` (repository confirmed private) | `ai-memory-sync` | 15:57:49Z |

The source regression guard `tools/ci/check-managed-github-transport.py` is
already on `origin/main` (PR #973) and continues to reject new direct managed
`gh`, Node, and HTTP bypasses. No new bypass was introduced.

CI job-token and `github-script` SDK callers in `.github/workflows/` remain
separate identity classes, dispositioned in
[`p3-source-coverage.md`](p3-source-coverage.md) rather than routed through the
personal-credential wrapper.

## #933 / #936 — Windows runner maintenance admission proof

The elevated runner maintenance script's REST calls are routed through
`bin/runner-github-admission.ps1` (PR #935). The single installed live proof
left by that PR is one bounded **read-only** runner-list request.

### What was run

From an interactive PowerShell session on `edge-dev` (the Windows runner host),
with the standard `ProgramFiles` environment present (see note below):

```
C:\repos\ai-devops\bin\runner-github-admission.ps1 -Operation list -Repository popcre/ai-devops
```

### Result

- **Entered `ai-gh`:** yes. Telemetry record at `2026-10-13T16:07:14Z` shows
  `operation: api.unknown`, `result: success`, `cli_executions: 1`. The adapter
  invoked the adjacent `ai-gh.cmd` shared admission; no direct `gh` call was
  made.
- **Returned a valid list:** yes. `total_count: 8`, including `edge-dev-win`
  (id 26, `online`, `busy: false`) and the `edge-dev3-linux*` runners. The
  response was well-formed JSON with runner IDs, names, OS, status, and labels.
- **Token values out of logs:** yes. A scan of `measurements/2026-10-13.jsonl`
  for `token`, `ghp_`, `gho_`, `github_pat` found **0** matches. The adapter
  writes no token material to its call path for the `list` operation.
- **Runner registration unchanged:** yes. `C:\actions-runner\.runner` SHA-256
  `d764ecf0…cce4dc` is unchanged before and after.
- **Service state unchanged:** yes. `actions.runner.popcre-ai-devops.edge-dev-win`
  remained `Running` / `Automatic` before and after.
- **Existing BlockerWatch task unchanged and still ticks:** yes. The
  `\ai-devops\blocker-watch` task continued its normal 10-minute schedule during
  the proof window (last run 11:59:01 AM EDT, next run 12:09:00 PM EDT at
  check time). Its principal and action were not edited.
- **No token or deletion endpoints called:** correct. Only `-Operation list`
  was invoked. `remove-token`, `delete`, and `registration-token` were not
  called live.

### Elevation note

This session was interactive but not elevated (`edge-dev\ahazan`,
`Administrator: False`). Creating a `Highest` run-level scheduled task requires
elevation that this session does not hold. The read-only `list` operation does
not require elevation — it is an authenticated read through `ai-gh` — and the
proof above was collected in the interactive context that matches the
`InteractiveToken` authentication the existing BlockerWatch task uses
successfully. If a future elevated proof is required for the mutating
operations (`remove-token`, `delete`, `registration-token`), those remain
unproven live by design and must not be called for proof purposes.

A prior attempt to run the adapter without the standard `ProgramFiles`
environment variable failed closed with `Shared GitHub admission is
unavailable` / `The system cannot find the path specified` because the
`ai-gh.cmd` launcher resolves Git Bash via `%ProgramFiles%`. That is a
degraded-session environment issue, not a defect in the adapter; the
adapter correctly refused rather than falling back to direct `gh`.

### Prior evidence retained

- Windows fake transport: 8/8 passed (PR #935).
- Independent exact-head Codex final-check APPROVE at `980a8c4` (PR #935).
- SSH-context read-only call previously failed closed with HTTP 401 (invalid
  GitHub credential in that context); no fallback was used.

## Scope boundary

This proof establishes P3 managed-caller source routing and the Windows runner
maintenance read-only admission path on `edge-dev`. It does not establish:

- Fleet-wide installation on other hosts.
- Aggregate request/point savings or section-13 comparable acceptance (#660, P8).
- Live proof of mutating runner-maintenance endpoints.
- P2/P4/P5/P6 acceptance.

Posted by MiMo chat <id> on edge-dev
