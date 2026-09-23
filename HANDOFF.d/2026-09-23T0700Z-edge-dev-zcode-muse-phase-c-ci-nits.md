---
issue: 542
status: OPEN
owner: zcode/542-muse-phase-d
---

# Phase C landing leftovers: two non-blocking CI wording nits

Recorded at session close (2026-09-23) because their only evidence lived in a
local review artifact that was deleted with the landed worktree. Non-blocking:
the Grok round-4 reviewer judged both P3, log/comment-only. Fold them into
Phase D3's workflow/docs touch or a tiny maintenance PR; do not open a PR for
them alone unless they start to mislead.

## Nit 1 — aggregate failure message says "five" Windows sections

`.github/workflows/verify.yml`, the `windows-offline` aggregate job's
fail-closed message prints "the five Windows sections reported cancelled"
(`printf 'windows-offline: %s reported %s; failing closed.'` wording). The
section matrix became six when PR #666 split Gemini, GLM and Muse Code into
dedicated sections. Observed live during PR #678's first queue run
(35800378021, cancelled at the 40-minute wall on 2026-09-23).

## Nit 2 — blacksmith workflow comment misstates the hosted ceiling

`.github/workflows/windows-offline-blacksmith.yml` (~line 45, per the round-4
review): a comment describes the hosted lane's timeout in terms that no longer
match the verify.yml section job it mirrors.

## Reviewer evidence (verbatim, Grok 4.6 round 4, 2026-09-23)

> **[P3] PR aggregate still says five sections after the matrix became four**
> — `.github/workflows/verify.yml:314` … Log-only; does not change which
> suites run.
>
> **[P3] Blacksmith comment now misstates the hosted ceiling** —
> `.github/workflows/windows-offline-blacksmith.yml:45`

(Note: round 4 wrote "became four" before main's six-section split landed;
the count discrepancy is now five-vs-six. The substance — stale count in a
failure message — stands.)

## Next step

Whoever next edits either workflow (expected: Phase D3) updates the message
and comment to derive from the manifest's shard count instead of a literal,
or simply corrects the literals. Then delete this file in the same PR.
