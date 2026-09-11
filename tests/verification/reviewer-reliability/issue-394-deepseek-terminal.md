# #394 DeepSeek terminal encoding and validation slice

This is a bounded component repair, not completion of #394 or the nine-provider
programme. It does not change usage counting, shared database code, provider
selection, continuation policy, or the frozen maintenance round.

## Source and reproduction

- Base: `7fd27fc0310d` from fetched `origin/main`, September 11, 2026.
- Host: Windows; Git Bash 5.3.15; Python 3.13.15.
- Existing provider-shaped offline suite plus new regressions: **71 passed,
  4 failed, 0 skipped** before the repair.
- The three terminal failures accepted trailing text, multiple verdict headings,
  or a verdict inside a fenced example. The fourth failed a Unicode review with
  `PYTHONIOENCODING=ascii`, reproducing the Windows stdout conversion failure.

## Repair and invariants

Response extraction writes an explicit UTF-8 file; transcript display also
uses explicit UTF-8. Formal review accepts one final verdict outside a fenced
block. Missing or malformed provider text and unusable verdicts remain nonzero;
valid APPROVE, REJECT, and evidence-based BLOCKED keep their existing contract.

The exact provider response is created in existing private session storage
before contact, with a unique session-linked name that cannot appear in the
conversation listing. Local extraction and verdict failures retain this file;
HTTP errors expose a stable reason without printing the private response body.
No automatic second provider call is introduced. Explicit continuation behavior,
conversation locking, the evidence boundary, and attachment accounting remain.

This is local response retention only. Central publication, interruption
provenance, the cross-provider terminal matrix, and governed reason parity remain
with their existing programme owners. No historical incident is resolved by
this synthetic reproduction alone.

## Verification

Command: `bash tests/test-ai-deepseek-agent.sh` through Git Bash.
Final suite: **85 passed, 0 failed, 0 skipped** on September 11, 2026.
This includes HTTP-body privacy and malformed-response retention fixtures.
The repaired wrapper SHA-256 is
`be0f1cdd8708355d76285e7c3ba682fe4e137ec3fb8097a13ea30434098b47c6`;
the focused suite SHA-256 is
`0f13d255f8e4ebb8b3bb27ef22232858067cec58382d48910309ca224a387707`.
`git diff --check` passed. Exact-head independent review, required CI, merge,
installation and authenticated live acceptance are serialized by the parent
delivery task and must be linked before this slice is reported deployed.
