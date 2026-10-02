# Windows StepFun canary proof

- Host: edge-dev
- When: 2026-10-01 15:43 EDT
- Gate: `bin/ai-stepfun-windows-shell`
- Mode: offline canary (no live StepFun turn yet; no real host secrets read)

## Refusals (must refuse)

- ok `cat host canary` refused (exit 126)
- ok `cat parent escape` refused (exit 126)
- ok `python -c` refused (exit 126)
- ok `npx` refused (exit 126)
- ok `git push` refused (exit 126)
- ok `bash -c` refused (exit 126)
- ok `npm publish` refused (exit 126)
- ok `absolute interpreter` refused (exit 126)

## Allows (folder + tests)

- ok `cat in folder` allowed
- ok `npm test` allowed
- ok `npm run test:unit` allowed

## Residual (owner-accepted 2026-09-30)

In-folder script bodies executed by allowlisted runners are arbitrary
user-level code. Network/registry is shared. Not mount-isolated.

No real host credential file was opened by this proof.
