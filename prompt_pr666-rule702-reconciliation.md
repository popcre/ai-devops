Paste this into a fresh session. It is self-contained.

---

Reconcile popcre/ai-devops PR #666 (sealed private code reviews) with main's #702 rule, then land it or close it with a decision. Albert owns POP Creations and is not a programmer — report in plain English, under 120 words, with a **Still open** block.

## Where things stand

- PR #666 "Allow read-only private code review without permission loops" (branch `codex/readonly-private-review-20260920`, head 46c86f28) carries the complete sealed attachment-only export work: `bin/ai-review-code-only.py`, the `ai-review-sandbox` sealing path, the private-source front-door gate, and offline DeepSeek mock fixtures. It was recovered from abandoned work folders (ai-devops issue #713) and pushed on 2026-09-24.
- A Codex reviewer placed a safety hold on the earlier head: keep the PR open until a tested code-only review boundary is designed and verified. The branch now contains that boundary and passes its own suites on Windows (test-ai-review-lifecycle 66/66, test-ai-review-code-only 99/99, test-ai-review-sandbox 6/6).
- But it was assembled before #702 (commit 88098b17, "Keep formal review out of private repos") landed on main, and the two now conflict. Merged against current main, exactly two checks fail in tests/test-ai-task-gates.sh:
  - `the protected stop says there is no owner-request path` — #702's contract: `check --before review --owner-request` on a licensor repo must print the protected stop. The branch removes `review` from `private-evidence` forbidden_actions in config/task-gates.json, so the stop never fires.
  - `private code review needs no owner request or acknowledgement` — the branch's contract: plain `check --before review` on a private code-only change set returns 0.
- Full analysis comment: https://github.com/popcre/ai-devops/pull/666 (2026-09-24, posted by ZCode).

## The job

1. Decide the reconciliation design. The leading candidate (not decided): keep `review` forbidden for `private-evidence` per #702, and give the sealed code-only route its own narrower gate action (for example `code-only-review`) whose required gates include `synthetic-fixtures-only`; `bin/ai-review` requests that action only on the `--code-only` path. Any design is fine if both contracts' checks pass and no unsealed review path opens. This is a reviewer-safety policy change — treat it with that class's care, and do not weaken any refusal that #702 added.
2. Work in your own worktree cut from current origin/main; merge or rebase the PR branch; keep the branch history readable.
3. Verify: the three sealed-route suites above plus tests/test-ai-task-gates.sh and tests/test-ai-review-preflight.sh, all green locally, then CI green on the PR.
4. Draw a fresh exact-head review (`bin/ai-review grok diff-review --base <merge-base> --assert-head <full head sha> --tests "<fast suites>"`). If Grok is quarantined, wait out the epoch and retry; do not swap providers mid-review. Qwen may still be down with a qualification mismatch (machine drift).
5. On APPROVE: freeze the branch, merge via the queue, verify the remote SHA, and confirm the safety hold is satisfied (comment on the PR saying how).
6. If you conclude the design cannot satisfy both contracts, say so on the PR with the evidence and leave it open for Albert — do not force a merge and do not close it silently.

## Rules in force

- Start with `ai-task-gates start --class reviewer-safety`; this change set is that class.
- Never push directly to protected main; PR + merge through the queue; you merge it yourself.
- Sign every GitHub post: `Posted by <Claude|Codex|ZCode> chat <session id> on <machine>`. Quote times in EST.
- Waiting is not reporting: hold waits inside the turn; come back with a finished result or a real blocker with its verbatim evidence line.
- Do not use reset --hard or clean -fd over unreviewed work.

Posted by ZCode chat sess_d22c4c83-beb4-424b-af5c-15331f6c80f1 on EDGE-DEV, 2026-09-24
