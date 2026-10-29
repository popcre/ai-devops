# Does AI review pay off by repository, or by type of work? (2026-10-29)

**Question (Albert, 2026-10-29).** Was the 2026-10-13 decision right to require reviews only in shared-db? Should the rule instead depend on the type of work or the type of chat?

## Method

1. **Archive.** The full Dropbox `ai/chat_transcripts/` archive covers every machine, April to October 2026, about 12,000 transcript files.
2. **Local prefilter.** [`prefilter.py`](../tests/verification/review-value/prefilter.py) keeps only passages where a reviewer name sits near a verdict or finding word. That cuts the archive to 38 MB, from 3,842 chunks.
3. **ScaleDown labels.** ScaleDown Summarize labels each review with:
   - repository
   - type of work
   - type of session
   - review mode
   - verdict
   - value: real, minor, none or wrong
4. **Tally.** Counting is plain Python, with no LLM. The output is [`tally-2026-10-29.txt`](../tests/verification/review-value/tally-2026-10-29.txt), covering 6,128 reviews with a verdict.

**How "caught" is counted.** A review counts as caught-real only if the value is "real" and the verdict was REJECT or REVISE. A hand check found that ScaleDown also marks many APPROVEs as "real", so those are excluded.

**How to read the numbers.** The labels are machine-made. Treat the percentages as relative, not absolute. The 2026-10-13 study measured 8% on a stricter scorer.

## Findings

**1. shared-db is not where the value lives.**

| Repository | Caught real |
|---|---|
| shared-db | 15% |
| ai-devops | 20% |
| dflow | 16% |
| popdam | 27% |
| other repositories | 30% |
| theoracle | 7% |

The earlier "only shared-db pays off" result does not hold up on the full archive.

**2. Type of work matters more than repository.**

| Type of work | Caught real |
|---|---|
| bugfix | 28% |
| implementation plan | 24% |
| database schema | 23% |
| code feature | 18% |
| config or infra | 18% |
| docs or prose | 17% |
| tooling scripts | 12% |

Database-schema changes outside shared-db scored 43%.

**3. Review mode matters most.**

| Review mode | Caught real |
|---|---|
| first diff review | 29% |
| plan review | 25% |
| repeated final checks | 11% |

The value is in the first look. Re-reviewing the same work again and again adds little.

**4. Wrong findings are rare,** about 1%. A review almost never causes harm. Its cost is time and money, and running reviews in CI with no session waiting removes the time cost.

## Decision

- Albert handed this decision to the AI.
- **Review every PR in every repository, shared-db included, with the same merge rule.** That rule is set in [plan_simple-reviewer-rebuild.md](../plan_simple-reviewer-rebuild.md) §8.
- **Implementation plans get a plan review** when they are opened as a PR.
- **One review per head.** No repeated final-check rounds; a second round happens only after a real change.
- **No per-repository opt-out.** If cost becomes a problem, cut repeated final checks first, then tooling-script PRs.
