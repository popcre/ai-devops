# Issue #210 — balanced, independent Windows sections

**Parent:** #159 (repository-throughput restructure), plan gate B5.
**Base:** `b418c2c2` (#260, "Stop duplicate hosted Windows reviewer runs", PR #353).
**Scope, as reduced by plan drift item 3:** the self-hosted reviewer lane plus
any measured wall-clock case on hosted.

## What the measurements forced

The reviewer lane was measured, not assumed, before anything was changed.

- The qualified pool (`ai-devops-windows-qualified`) resolves to exactly one
  host, EDGE-RUNN-ENVY. EDGE-ALIEN carries `ai-devops-windows-paused` and was
  placed on ice by the owner on 2026-09-03; that is an owner decision, not an
  engineering task.
- Dividing a lane across sections on **one** machine is not parallelism. It is
  the "apparent parallelism by competing on one machine" that #210 explicitly
  forbids, and it would make each section slower, not faster.
- The reviewer lane already completes in about 538 seconds (~9 minutes), well
  inside the 20-minute bound the plan sets.

So the reviewer lane is left exactly as #260 built it, and the actionable target
is the hosted `windows-offline` matrix — the measured wall-clock case on hosted
that drift item 3 allows. Hosted concurrency is unmetered on a public
repository, so four sections genuinely run on four separate machines at the same
time.

## Baseline: three consecutive green hosted runs

All three are `pull_request` runs of the ordinary lane, `selected=21 of 69`.

| Run | Bash total | Job wall clock |
| --- | --- | --- |
| 34394706703 | 3,716 s | 62 m 56 s |
| 34377910065 | 3,662 s | 61 m 57 s |
| 34366159903 | 3,586 s | 60 m 42 s |

PowerShell suites: about 45 seconds for all 18. Checkout and dependency setup:
about 15 seconds. The Bash suites are effectively the whole job.

## Choosing the number of sections

Sections are packed longest-processing-time first on the **worst** observed time
of each suite, so the mapping is sized for the slow case rather than the lucky
one. `test-ai-kimi.sh` at 1,098 seconds is an irreducible floor: no split can
make a section shorter than its slowest indivisible suite.

| Sections | Worst section | Verdict |
| --- | --- | --- |
| 3 | 22.5 min | breaches the 20-minute bound |
| 4 | 18.3 min | inside the bound |
| 5 | 18.3 min | no further gain; the floor dominates |

Four sections is therefore the smallest split that satisfies the plan's bound,
and the first that spends no machines for nothing.

## The declared mapping

Boundaries live in `config/ci-suite-manifest.json`, not in the workflow, so a
reviewer can read which section proves what.

| Section | Suites | Worst-case seconds |
| --- | --- | --- |
| 1 | 1 (`test-ai-kimi.sh`) | 1,098 |
| 2 | 11 + all 18 PowerShell suites | 889 + ~45 |
| 3 | 6 | 890 |
| 4 | 3 | 890 |

The PowerShell suites are not divisible by this mapping, so exactly one section
owns them and every other section skips them **by declaration**, printing which
section holds them.

## Result

| Measure | Before | After | Note |
| --- | --- | --- | --- |
| Ordinary PR wall clock | 60–63 min | ~18.6 min | worst section plus setup |
| Hosted runner-minutes | ~62.9 | ~63.5 | +0.6 min for 3.4x wall clock |
| Queue waste | none | none | hosted concurrency is unmetered |
| Failure detection | up to 63 min | ~15 min for sections 2–4 | a defect no longer waits behind Kimi |

Runner-minutes rise very slightly, by three extra checkouts. On a public
repository those minutes are unmetered, so the trade is wall clock and
failure-detection time bought for nothing that is billed.

## Measured live on the change itself

Run 34420312687, the ordinary pull-request lane of this branch. All four
sections started together on four separate hosted machines, the complete
backstop correctly did not run, and the aggregate published one green result.

| Job | Result | Wall clock |
| --- | --- | --- |
| `windows-offline-section (1)` | success | 19 m |
| `windows-offline-section (2)` | success | 16 m |
| `windows-offline-section (3)` | success | 14 m |
| `windows-offline-section (4)` | success | 15 m |
| `windows-offline-complete` | skipped | — |
| `windows-offline` (aggregate) | success | under 1 m |

The worst section measured 19 minutes against the predicted 18.3 and the
20-minute bound, and against a 60-63 minute job before the change.

## Every assertion preserved

- **Coverage is proved at run time, not just in a policy test.** A section runs
  only if the declared sections sort-equal the ordinary lane exactly, with no
  suite in two sections. A bad mapping exits 2 (configuration error), never 0.
- **The backstop cannot be narrowed by a sectioning mistake.** `--shard` is
  accepted only together with `--windows-offline --exclude-reviewer-safety`.
  Scheduled, manual, qualification and no-argument runs pass no section and run
  the complete matrix in `windows-offline-complete`.
- **#260's fail-closed reviewer coverage is untouched.** The start deadline, the
  42-minute completion deadline and `windows-reviewer-fallback` are unchanged,
  and the scheduled reporter still watches the complete matrix.
- **One stable required context.** A single aggregate job keeps the name
  `windows-offline`, so #166 can require it without knowing how many sections
  exist. It fails closed: a lane result other than success fails it, and a skip
  is accepted only when the fast classifier proved the change was prose-only.

## Injected-failure evidence

`tests/test-windows-bash-selection.sh` — 23 passed, 0 failed, including live
PowerShell. New section cases, all proved against injected fixtures:

- the declared sections partition the ordinary lane with nothing lost or repeated
- a clean lane passes in every section
- an injected defect fails its own section, leaving the others honest
- the complete scheduled backstop still sees a defect no section could hide
- sections that do not cover the lane fail instead of dropping a suite
- a suite declared in two sections fails instead of running twice
- a section request that disagrees with the declaration fails closed
- a manifest with no declared sections refuses to run one
- a section that does not own the PowerShell suites says so and skips them
- PowerShell sectioning is refused outside the ordinary pull-request lane
- a section argument with anything but one `<i>/<n>` pair is refused

Guard matrix on `tests/test-all.sh`, exit codes only:

| Case | Expected | Got |
| --- | --- | --- |
| section without lane context | 2 | 2 |
| section without reviewer exclusion | 2 | 2 |
| section index above total | 2 | 2 |
| section index zero | 2 | 2 |
| malformed `1of4` | 2 | 2 |
| two separators `1/2/4` | 2 | 2 |
| missing index `/4` | 2 | 2 |
| missing count `1/` | 2 | 2 |
| declared count disagrees (`1/3`) | 2 | 2 |
| valid section | 0 | 0 |
| unsectioned lane unchanged | 0 | 0 |

`tests/test-workflow-policy.sh` passes, including the new assertions that the
sections partition the lane, run on independent hosted machines, keep every
section reporting (`fail-fast: false`), and publish one stable fail-closed
aggregate.
