# Grok follow-ups and DeepSeek evidence boundary — 2026-08-24

Redacted, repository-safe evidence index for the reviewer repairs made after the
2026-08-23 reviewer-production-completion handoff. Raw provider streams, prompts,
credentials, and private sandbox state stay in protected machine-local state and
are not committed.

## 1. Grok — the three follow-ups Claude raised on issue #62

Claude's installed exact-source review of open issue #62 approved the process-tree
commit and named three nonblocking Grok follow-ups. All three were confirmed
against current source and repaired.

1. **`on_paid_signal` recorded paid-work uncertainty after fallible cleanup.**
   The interrupt path stopped the Grok process tree first and only then wrote
   `remote-uncertain`. It stayed fail-closed because EXIT cleanup is disarmed
   first, but the ordering disagreed with the safer `preserve_uncertain_paid_turn`
   helper. `bin/ai-grok-review:on_paid_signal` now disarms EXIT, records
   uncertainty (warning if the marker cannot be written), releases the local-only
   session lock, and only then attempts the stop.

2. **Two Windows-only cases were counted as passing checks on other platforms.**
   `tests/test-ai-grok-review.sh` gained a `skip()` counter. Skips are reported
   separately and no longer inflate non-Windows totals.

3. **A temporary supervisor stop directory could be orphaned.** When both the
   stop-file request and the termination fallback fail, the timeout path, the
   isolation-inspection path, and `on_paid_signal` now call
   `clear_active_stop_file`. Only temporary stop state is removed; the paid-work
   lock and its uncertainty marker are never released by cleanup.

### Grok proof

- `bash tests/test-ai-grok-review.sh` on Windows/Git Bash: **172 passed, 0 failed,
  0 skipped** (168 before this change, plus four new bound checks).
- Mutation check: deleting the new pre-cleanup uncertainty write makes
  `on_paid_signal records remote uncertainty before any fallible cleanup` and its
  companion fail (169 passed, 3 failed). The tests are not vacuous.

## 2. DeepSeek — reviews asserted evidence it never had

Running the handoff's recommended installed DeepSeek review of open issue #62 on
Ubuntu production produced a terminal `BLOCKED` verdict whose findings were false.
It reported that `.github/workflows/verify.yml`, `tests/test-all.sh`,
`tests/test-all.ps1`, and `memory/README.md` do not exist. All four exist at the
reviewed commit.

Root cause: `ai-deepseek-agent` talks to a text-only chat API. DeepSeek has no
repository, filesystem, or tool access, and `--review` never said so. It also
attached at most one `--file`. Because `--review` binds the verdict to the exact
Git HEAD in durable metadata, an unevidenced opinion was published in a shape
that reads as exact-source repository inspection.

This is a truthfulness defect, not a provider outage, so the capability was
repaired rather than distrusted or dropped:

- `--review` now sends an explicit evidence boundary: no repository access, the
  attached text is the only evidence, absence from the message is not evidence of
  absence from the repository, and a conclusion needing unavailable evidence must
  name the gap and return `BLOCKED`.
- `--file` is repeatable, so a reviewer can be handed the evidence a real
  judgement needs instead of a single attachment.
- Review metadata is `schema_version` 2 and records
  `evidence_scope: "attached-materials-only"`, `repository_access: false`, and the
  exact `attached_files` list, so no later reader can mistake the record's HEAD
  binding for proof of inspection at that commit.

An independent exact-source review of the first attempt returned `REJECT`
(`.ai/reviews/codex-final-check-20260824T030141-1702447-18935.md`) and was right:
`reply --review` resends the entire conversation, so files attached on an earlier
turn stay in front of DeepSeek, yet the per-turn attachment list reset and the
durable metadata recorded only the latest turn. A continued review therefore
understated its own evidence. Two further repairs followed:

- A per-session attachment ledger accumulates every file actually sent in the
  conversation. `attached_files` is now that accumulated list and
  `attached_files_this_turn` records the current turn, so neither over- nor
  understates the evidence. The ledger has no `.json` suffix, so `list` cannot
  mistake it for a conversation.
- The evidence boundary is worded around the conversation rather than one
  message, because a reply carries the earlier turns with it.

A second independent review of the corrected attempt also returned `REJECT`
(`.ai/reviews/codex-final-check-20260824T042033-1914854-21506.md`), and was again
right: the ledger stored names as newline-delimited text and later split and
trimmed them, so a legal path containing spaces or newlines would be renamed or
split in the durable record. The final repair stores attachments NUL-delimited
and passes this turn's paths as argv, so a name is recorded exactly as given.
Two hostile-filename cases bind it, and the suite reports skips separately so a
filesystem that cannot host such a name never counts as a pass.

A third independent review returned `REJECT` a third time
(`.ai/reviews/codex-final-check-20260824T112029-658-16571.md`), and was right
again: the boundary lived only in the user turn, while the supported
caller-controlled `--system` prompt is sent with higher authority. A conflicting
system prompt could have told DeepSeek it did have repository access, recreating
the fabrication while the wrapper still published completed review metadata. The
boundary is now the system prompt itself:

- `--system` is refused with `--review`, before provider contact. Ordinary
  non-review conversations keep the option.
- `reply --review` refuses, before provider contact, in a conversation whose
  first message is not exactly the boundary, so a continued review cannot inherit
  a permissive system prompt.

### DeepSeek proof

- `bash tests/test-ai-deepseek-agent.sh`: **67 passed, 0 failed, 0 skipped**
  (51 before, plus sixteen new bound checks covering the boundary text, the
  refusal to infer, the retained verdict requirement, repeatable attachments,
  honest metadata, cross-turn attachment accumulation, per-turn attribution,
  exclusion of the ledger from `list`, two hostile attachment names, refusal of
  a caller system prompt in review mode with no provider contact, the boundary
  being carried by the system message, preservation of `--system` for ordinary
  conversations, and refusal to continue a review in a conversation that never
  carried the boundary).
- Mutation checks, each run and each observed to fail the intended case:
  making the ledger overwrite instead of accumulate fails
  `a continued review records every file attached across the conversation`;
  reverting the ledger to newline delimiters fails
  `an attachment name containing a newline is recorded as one exact entry`;
  re-introducing `.strip()` on a recorded name fails
  `an attachment name keeping its leading and trailing spaces is recorded
  verbatim`; disabling the `--system` refusal fails
  `a review refuses a caller system prompt before any provider contact`.
  None of the new tests is vacuous.

`skills/shared/deepseek-second-opinion/SKILL.md` now states the boundary, the
refusals, and the reason, so a caller does not rediscover this by trusting a
fabricated finding.

## 3. Repository-wide offline gate

- `bash tests/test-all.sh`: **52 suites, 0 failures.**
- `pwsh -NoProfile -File tests/test-all.ps1`: **16 PowerShell suites, 0 failures**
  (`OFFLINE COMPLETE SUMMARY bash=1 powershell=16 failures=0`).
- `bash tests/test-ai-review-packet.sh`: 90 passed, 0 failed.
- `bash tests/test-ai-review-sandbox.sh`: 71 passed, 0 failed.
- `bash tests/test-ai-review-preflight.sh`: 36 passed, 0 failed.
- `bash tests/test-ai-review-scoreboard.sh`: 15 passed, 0 failed.
- `bash tests/test-ai-qwen.sh`: 90 passed, 0 failed (owner-waived live proof; the
  offline contract is complete and Qwen stays truthfully quarantined).

## 4. GLM returned to service

Albert renewed the Z.ai Coding Plan on 2026-08-24. The installed wrapper then
completed a real paid turn, so the dynamic `allowance-exhausted` quarantine was
cleared through `ai-review-preflight clear glm` — the blocker itself was resolved,
not the record falsified.

- Structural health: `ai-glm doctor` on Ubuntu production, all required checks
  passed (read-only review agent, loopback-only service, pinned version, model
  `glm-5.3` available, no secret value in service files).
- Allowance canary: session `glm-allowance-canary-20260824`, provider
  `zai-coding-plan/glm-5.3`, terminal `APPROVE`.
- Real open-issue review: open issue #62 reviewed at exact production head
  `8435f7938d9865158975c2a4dbd7e43a3c3bde97`, session
  `glm-issue-62-production-8435f79`, model `zai-coding-plan/glm-5.3`, terminal
  `APPROVE`, with a correct finding that issue #62 must remain open. Report:
  `/worksp/ai-devops/.ai/reviews/glm-glm-issue-62-production-8435f79-20260824T011317Z.md`.
- `ai-review-preflight status glm` then reported `available` without manual
  falsification.

## 5. Exposed MCP credentials

The DesignFlow DevOps and NAS MCP bearer tokens exposed in earlier reviewer output
were rotated on 2026-08-23 by the preceding session and recorded in the
`vibe_coding` item `DesignFlow MCP bearer tokens - DevOps and NAS (production)`.
Albert approved rotation again on 2026-08-24; because the rotation had already
completed, this session verified it instead of rotating a second time and risking
live consumers:

- Current `devops_token` against `https://mcp.designflow.app/mcp`: accepted.
- Current `nas_token` against `https://nas-mcp.designflow.app/mcp`: accepted.
- A deliberately invalid bearer token is rejected by both endpoints.
- Verification ran through protected `op://` injection. No value entered a
  command argument, chat, log, or this repository.

## 6. Independent exact-source review

Reviewer-safety changes require one independent read-only exact-head review with
the critical tests bound into its packet. Five were run, each with
`--tests "bash tests/test-ai-grok-review.sh && bash tests/test-ai-deepseek-agent.sh"`.
Four returned `REJECT` on real defects, and each is recorded above rather than
quietly corrected:

| Report | Verdict | What it caught |
|---|---|---|
| `codex-final-check-20260824T030141-1702447-18935.md` | REJECT | continued reviews recorded only the latest turn's attachments |
| `codex-final-check-20260824T042033-1914854-21506.md` | REJECT | a newline or space in a path corrupted the attachment record |
| `codex-final-check-20260824T112029-658-16571.md` | REJECT | a caller `--system` prompt could override the evidence boundary |
| `codex-final-check-20260824T123630-1767-29456.md` | REJECT | de-staled plan tables contradicted their own current-state prose |
| `codex-final-check-20260824T133922-727-10061.md` | APPROVE | no blocking or material findings; 239 bound checks passed |
| `codex-final-check-20260824T160644-502304-26468.md` | REJECT | a failed ledger write left the session usable with an incomplete record |

A sixth review, run against the already-pushed `b5155af`, found that the
transcript is published before the ledger is appended, so a ledger failure left a
saved turn whose attachments never reached the durable record — the same
understatement the ledger exists to prevent. A ledger failure now writes a
`.recovery-required` marker and `reply` refuses that session before any provider
contact, so the record can never quietly fall behind. Four further bound cases
cover it, and disabling the marker fails two of them.

The fifth review confirms the boundary is enforced as a system message,
conflicting caller system prompts are rejected, continuations verify the boundary
is still present, attachments are NUL-safe and published as
attached-materials-only with no repository-access claim, and Grok records
uncertain paid work before fallible shutdown.

## 7. Verification status of the final commit — read this

The DeepSeek recovery-marker repair (§2) landed in a later commit than the rest of
this note. Its verification is deliberately uneven, and the difference matters:

**Locally confirmed on the exact committed tree:**

- `bash tests/test-ai-deepseek-agent.sh`: 71 passed, 0 failed, 0 skipped.
- `bash tests/test-ai-gemini.sh`: 52 passed, 0 failed.
- `bash tests/test-markdown-links.sh`: PASS, 237 tracked Markdown files.

**NOT confirmed locally on that exact tree:** the complete `tests/test-all.sh`
sweep and `tests/test-all.ps1`. Three attempts were interrupted by session
restarts before finishing; the furthest reached 14 suites with zero failures. The
same code passed a complete 52-suite sweep before the recovery-marker change, and
the change is confined to `bin/ai-deepseek-agent` and its own suite.

**The exact-head GitHub Actions `verify` run is therefore the authoritative gate
for this commit,** not a local sweep. Do not record this commit as fully verified
until that run reports success on `linux-offline`, `windows-offline`, and
`windows-reviewer-safety`. If it fails, fix forward; do not assume the local
partial result cleared it.

## 8. Unrelated repair: a broken link that had turned `main` red

`origin/main` was failing CI on three consecutive commits (`a4a790b`, `3102d99`,
`b24578d`) before this commit. Cause: `fix_stale_name.md`, added by a concurrent
session, linked to `bin/mcp-secret-launch.ps1:53`. `tools/check-markdown-links.py`
strips a `#fragment` but not a `:NN` line suffix, so it resolved the whole string
as a path and reported a missing target. No other tracked Markdown file in the
repository uses that form.

Repaired here by pointing the link at `bin/mcp-secret-launch.ps1` and keeping the
line number in the visible link text. The checker was deliberately NOT changed:
teaching it to strip `:NN` would also hide genuine typos, and one document is the
smaller, more reversible fix. This edits another session's committed file, which
is normally avoided — but the file was already merged into shared code and, while
broken, no session could prove any change green.
