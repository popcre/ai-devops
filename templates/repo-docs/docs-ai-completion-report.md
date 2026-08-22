# AI Completion Report (template)

Fill this in when a staged task is finished. It is the human-facing record of
what happened. Keep it in the repo (e.g. under `.ai/runs/<run>/` or the PR body).

---

## Task

- **Request:** <the original ask, in one or two sentences>
- **Branch:** <feature branch name>
- **PR:** <PR URL, if opened>

## What changed

- <bullet list of the actual changes, per file or per feature>

## Tests

- **Added / updated:** <which tests>
- **Result:** <pass/fail summary, commands run>
- **Visual testing:** <yes/no; what was verified, or why not needed>

## Reviews

| Gate | Model | Verdict |
|------|-------|---------|
| Plan review | Opus | <approve / approve-with-changes / block> |
| Diff review | Opus | <verdict> |
| Security review | Opus | <verdict> |
| Final review | Claude Opus 5 | <ready / not ready> |

## Plan deviations

- <anything that differed from the approved plan, and why>

## Remaining risks / follow-ups

- <known risks, TODOs, or things to watch>

## Plain-English summary for Albert

<3–6 sentences a non-programmer can understand: what changed, whether it does
what was wanted, and anything to watch out for.>
