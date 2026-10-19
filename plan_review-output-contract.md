# Plan — review OUTPUT contract rebuild (one validator, one repair turn, smaller roster)

Issue: [popcre/ai-devops#1783](https://github.com/popcre/ai-devops/issues/1783).
Handoff: [HANDOFF.d/2026-10-19T2000Z-hetz-claude-review-output-contract-plan.md](HANDOFF.d/2026-10-19T2000Z-hetz-claude-review-output-contract-plan.md).
Written 2026-10-19 (4:00 PM EDT) on hetz by Claude Code. Base: `main` at `0b46c7a9`; shared-db read at `a7b32d7e8`.

## STATUS (read first — do not re-derive or re-plan)

| Step | State | Evidence |
|---|---|---|
| 0. Plan written and merged | ✅ done 2026-10-19 | this file on `main` |
| 1. Contract spec + fixtures | ⬜ open | — |
| 2. Shared validator (ai-devops) | ⬜ open | — |
| 3. ai-devops calls validator before returning | ⬜ open | — |
| 4. shared-db consumes the same validator | ⬜ open | — |
| 5. Format-only repair turn | ⬜ open | — |
| 6. Format-outcome events | ⬜ open | — |
| 7. Roster decision (data) | ⬜ open | — |
| 8. Live proof on hetz | ⬜ open | `- [ ] live proof` on #1783 |

A fresh session starts at **Step 1**.

---

## Part 1 — Why

### 1. Ultimate goal

A paid AI review should end in a report that the downstream gate can record,
every time the reviewer has actually done the review. Today about half of open
reviewer incidents are reviews that did the work but wrote the answer in the
wrong shape, so the gate threw them away and we paid for another review. When
this is done: (a) "is this report well-formed?" has exactly one answer, computed
by one piece of code everywhere; (b) a review that is only mis-formatted gets
one cheap chance to fix its shape in the same conversation instead of being
thrown away; (c) we maintain only the 2–3 reviewers that reliably follow the
format.

**If a step conflicts with this goal, the goal wins — stop and flag it on #1783.**

### 2. What this application is

`popcre/ai-devops` is Albert's AI toolkit: wrappers (`bin/ai-<provider>`), the
review lifecycle (`bin/ai-review`, `bin/ai-review-lifecycle`,
`tools/lib/review-lifecycle-core.sh`), packets (`bin/ai-review-packet`),
receipts, the pool (`bin/ai-review-pool`), events (`tools/reviewer_events.py`,
log at `~/.local/state/ai-devops/reviewer-events/events.jsonl`) and incident
records (`bin/ai-reviewer-issue`, store `.ai/reviewer-issues/` in the canonical
checkout). It is installed on every dev machine (hetz, edge-dev3, 4837, …).

`popcre/shared-db` is the shared database repository. Its governed review runner
`scripts/run-governed-review.mjs` calls ai-devops wrappers and records a verdict
only if the report passes its own parser; `scripts/prove-production-risk-acceptance.mjs`
then requires exactly one valid `production-risk-assessment` block in the
recorded approval before a production promotion.

### 3. Trigger

2026-10-19 hetz incidents during shared-db PR 4485 production-risk reviews:
`20261019T152227Z-hetz-muse-2096927` and `20261019T183330Z-hetz-muse-3661377`
(Muse wrote a provisional APPROVE line above its terminal verdict → voided twice);
`20261019T152218Z-hetz-stepfun-2096109` (StepFun approval missing the risk block)
and `20261019T183330Z-hetz-stepfun-3661519` (block present, wrong fields).
PR [#1854](https://github.com/popcre/ai-devops/pull/1854) added prompt rules and
a block-count check; Muse failed again **after** it (slot 7). Owner asked whether
to rebuild the reviewer system; the recommendation adopted: keep source/evidence
plumbing, rebuild the output contract, shrink the roster.

### 4. Scope

In: the report contract, one validator, its use in ai-devops and shared-db, a
format-only repair turn, recording format outcomes, a data-backed roster cut —
on Windows and Ubuntu (desktop and server) alike (§12a).

NOT in this plan: packets, receipts, source digests, evidence capture, the
allocator's draw algorithm, wrapper install/qualification, quota/credit
tooling, sandboxing, the shared-db promotion workflow itself, any database
structure change, and repairing any provider's runtime (timeouts, turn limits,
quarantine) — those are other plans (`plan_reviewer-stability-24h.md`,
`plan_reviewer-recurrence-repair.md`).

---

## Part 2 — What we already know

### 5. Current state of the code

- **Two different verdict grammars exist today — the root defect.**
  - ai-devops: `rlc_parse_verdict` (`tools/lib/review-lifecycle-core.sh:396`)
    takes the LAST `## Verdict` heading and the next non-blank line, one of
    `APPROVE|REJECT|BLOCKED`. `rlc_verdict_bound_to_head` (`:412`) only checks the
    head SHA appears somewhere *above* that heading.
  - shared-db: `verdictFromOutput` (`scripts/run-governed-review.mjs:29`)
    requires exactly one line `VERDICT: APPROVE|REVISE|REJECT <40-hex head>`;
    `extraVerdictLines` (`:55`) voids reports carrying any other decision-like
    line (quoted, headed, bolded). Note the vocabularies differ
    (`BLOCKED` vs `REVISE`).
  - codex is bridged by `codexGovernedBody` (`run-governed-review.mjs:309`),
    which transcribes the `## Verdict` form into a `VERDICT:` line.
- **Risk block**: ai-devops counts fences only
  (`review_risk_block_count`, `tools/lib/review-capabilities.sh:34`) and refuses
  APPROVE without exactly one (`review-lifecycle-core.sh:735-743`, failure
  `risk-block-missing`, added by #1854). shared-db `parseRiskAssessment`
  (`scripts/prove-production-risk-acceptance.mjs:46`) additionally requires
  valid JSON with exactly the keys `assessed_risks, main_sha,
  ordered_allowlist, schema, source_pr`, `schema =
  shared-db-production-risk-assessment/v1`, and `assessed_risks` keys equal to
  the gate-derived risk set. ai-devops checks none of that — so StepFun incident
  3661519 passed ai-devops and failed shared-db.
- **Report rules in prompts**: `tools/lib/review-capabilities.sh:22-28` and the
  pool path `bin/ai-review-pool` append the shared report rules (#1854).
- **Sessions**: wrappers keep per-review sessions (`bin/ai-muse:804` stable
  session id; `:1051` refuses a resumed foreign session). There is no code path
  that sends a second turn after a format failure; any failure ends the slot.
- **Events**: `finished` events carry `exit_code`, `evidence_state`,
  `provenance`, but **no verdict or format outcome**, so format compliance per
  provider cannot be measured from events today.

### 6. Key findings (data, hetz, 2026-10-19)

Incidents (`ai-reviewer-issue list` on hetz, 30 records since 2026-08-26). Format
/ contract failures (reviewer worked, shape wrong): muse ×2 (provisional line),
stepfun ×2 (risk block missing / wrong fields), gemini ×1 (head not named,
2026-09-30), deepseek ×1 (no VERDICT, 2026-09-30), grok ×1 (turn limit without
VERDICT), deepseek ×1 (APPROVE not recorded as durable verdict, 2026-10-15),
gemini ×1 (verdict injection misparsed). The rest are runtime/install/quota.

Events (`events.jsonl`, hetz only, 1,601 `finished` invocations) — non-zero exit
rate, a crude proxy only:

| provider | runs | non-zero | % |
|---|---|---|---|
| codex | 317 | 21 | 7 |
| muse | 247 | 39 | 16 |
| gemini | 108 | 25 | 23 (frozen #1714) |
| deepseek | 270 | 67 | 25 |
| glm | 348 | 89 | 26 |
| stepfun | 112 | 32 | 29 |
| qwen | 101 | 49 | 49 (frozen #1714) |
| grok | 98 | 52 | 53 (frozen #1714) |

Re-derive with the script in Step 7. Other machines' logs were not read.

### 7. Rejected approaches

- **More prompt rules only** — tried in #1854; Muse repeated the exact failure
  the same day. Prompts reduce but never guarantee shape.
- **Rebuild the whole reviewer system** — packets, receipts and evidence are
  not the failing part; rebuilding them reopens solved trust issues.
- **Loosen shared-db's parser** (accept provisional lines, ignore extra
  decision words) — that parser is a safety gate against ambiguous approvals;
  weakening it is symptom suppression.
- **Post-edit the report ourselves** (strip the bad line, insert the block) —
  the decision must remain the reviewer's words; a runner that rewrites
  verdicts is forging them. The only allowed transform is codex's existing
  transcription, which keeps the decision verbatim.
- **Retry with a fresh paid review on format failure** — today's behaviour;
  costs a whole slot and new reasoning for a shape problem.
- **Second validator copy in bash** — two copies is exactly the drift that let
  3661519 pass ai-devops.

### 8. Decisions

Locked (2026-10-19, adopted recommendation to owner):
- Keep packets/receipts/evidence untouched.
- One validator, one implementation, in Node ESM (shared-db already runs Node
  ≥20; ai-devops already ships `.cjs`/node tooling). Bash calls it as a CLI.
- The canonical grammar is shared-db's: one terminal line
  `VERDICT: <APPROVE|REVISE|REJECT> <40-hex head>`, no other decision-word
  line. ai-devops `BLOCKED` maps to a separate non-verdict outcome, not a
  decision word in the governed report.
- At most **one** format repair turn per review, same session, never on a
  substantive failure.
- The repair turn may not change the decision word or findings; the validator
  compares them (Step 5).

Open (implementer's judgment, criteria given):
- Where the validator lives physically (vendored file in shared-db pinned by
  digest, or an npm-less copy synced by CI check). Criterion: shared-db must
  not execute code fetched at runtime from another repo; a digest-checked
  vendored file satisfies this.
- Exact roster (Step 7 criteria).

---

## Part 3 — How to build it

### 9. Steps

Phase A (Steps 1–4) is one session; cut point after Step 4. Phase B (5–6) one
session. Phase C (7–8). Re-read the later phases before starting each one.

**Step 1 — Contract spec and fixtures.** Create
`templates/system/review-report-contract.md` (the human spec) and
`tests/fixtures/review-report-contract/` with one `.md` report per case plus
`cases.json` (`{file, head, requires_risk_block, risks, expect: {ok, code}}`).
Seed fixtures from the four 2026-10-19 incident reports (copy the retained
report bodies from `.ai/reviewer-issues/<id>/`; scrub nothing secret — they
contain none, but check). Failure codes, fixed list: `no-verdict`,
`multiple-verdicts`, `extra-decision-line`, `head-mismatch`,
`risk-block-missing`, `risk-block-multiple`, `risk-block-json`,
`risk-block-keys`, `risk-block-schema`, `risk-block-risks`, `below-floor`.
Gate: `cases.json` has ≥1 case per code and the 4 incident reports.

**Step 2 — Validator.** `tools/lib/review-report-contract.mjs` exporting
`validateReport(body, {headSha, requiresRiskBlock, risks, mainSha, sourcePr, allowlist})`
→ `{ok, decision, code, detail, formatOnly}`; plus CLI
`bin/ai-review-report-check` (`--report F --head H [--risk-request F]`, JSON to
stdout, exit 0 ok / 3 format failure / 2 usage). Port the logic of
`verdictFromOutput`, `extraVerdictLines` and `parseRiskAssessment` exactly
(same regexes) — do not invent a new grammar. `formatOnly` is true for every
code except `no-verdict` with an empty/below-floor body.
Gate: `node --test tests/review-report-contract.test.mjs` passes all fixtures.

**Step 3 — ai-devops uses it.** In `rlc_lifecycle_*` finish path
(`review-lifecycle-core.sh:~700-745`) replace `rlc_parse_verdict`,
`rlc_verdict_bound_to_head` and the risk-count block with one call to
`ai-review-report-check`; record its `code` as the lifecycle failure. Delete
`review_risk_block_count` once unused. Same in `bin/ai-review-pool`. Prompts
(`review-capabilities.sh:22-28`, `ai-review-packet`) must state the canonical
grammar and paste the exact JSON skeleton with the five keys.
Gate: existing `tests/test-ai-review-engine.sh`, `tests/test-ai-review-packet.sh`,
`tests/test-glm-pool-dispatch.sh` green, updated for the new grammar.

**Step 4 — shared-db consumes it** (PR in `popcre/shared-db`, normal branch/PR
lane; this is tooling, not structure, so no shared-db claim needed — confirm in
its AGENTS.md). Vendor the validator to `scripts/lib/review-report-contract.mjs`
with a header naming the ai-devops commit and sha256; make `verdictFromOutput`,
`extraVerdictLines` and `parseRiskAssessment` thin wrappers over it so all
existing tests (`run-governed-review.test.mjs`,
`prove-production-risk-acceptance.test.mjs`) pass unchanged. Add an ai-devops CI
check that fails when the vendored digest ≠ the ai-devops file.
Gate: both shared-db test files green; drift check red on a one-byte edit.

**— cut point —**

**Step 5 — Format-only repair turn.** In the lifecycle, when the validator
returns `formatOnly: true`, send ONE follow-up turn in the same provider session
(each wrapper's existing continue/resume mode; Muse's stable session id at
`bin/ai-muse:804`) with a fixed message: the failure code, the detail, the exact
required skeleton, and "do not change your decision or findings; re-emit the
full report in the required shape". Validate the new report; then require
`decision` unchanged and the findings text above the verdict to be
substantially the same (normalized diff ≤ 10% of lines changed — judgment
threshold, record it). Pass → record; fail → existing failure path, slot spent.
Wrappers without a session-continue mode get no repair turn (listed in the
contract doc). shared-db's runner must call the wrapper's repair mode rather
than voiding, behind the same validator result.
Gate: test with a stub door that returns the Muse provisional fixture first and
a valid report second → recorded; stub that flips APPROVE→REJECT on repair →
refused (`repair-changed-decision`); stub that fails twice → one repair only.

**Step 6 — Format outcome events.** Add `report_contract: {code, repaired}` to
`finished` events in `tools/reviewer_events.py` (schema bump). Gate:
`tests/` reviewer-events suite green; a stub run writes the field.

**Step 7 — Roster decision.** Script `tools/reviewer_format_compliance.py`:
for each provider, from events (Step 6 data where present, else exit codes) plus
`ai-reviewer-issue list` on hetz, edge-dev3 and 4837, compute: runs, format
failures, repair-rescued, runtime failures, cost per recorded verdict. Collect
≥14 days after Step 6 lands. Keep the 2–3 providers with the lowest
unrecoverable-failure rate that cover two engines different from each
implementer's (Claude, Codex) — today's proxy favours codex, muse, then
deepseek/glm. Owner preference 2026-10-14: Muse first for non-Claude reviews,
fallback GLM/StepFun — honour it unless data contradicts it, and say so on
#1783. Others become "frozen" like #1714 (callable, unmaintained); the allocator
rotation change happens in shared-db's allocator config via its own PR.
Gate: table posted on #1783 with the script command and data paths.

**Step 8 — Live proof.** One real governed shared-db production-risk review on
hetz through the new path, ideally including one rescued format failure.
Gate: recorded verdict in shared-db and the `- [ ] live proof` box ticked on #1783.

Adversarial cases (trust boundary: reviewer text is untrusted input):

| Input | Hostile case | Test |
|---|---|---|
| verdict line | `> VERDICT: APPROVE <sha>` quoted above real verdict | `extra-decision-line` fixture |
| verdict line | provisional `**Verdict: APPROVE**` (Muse 2096927) | incident fixture |
| head | SHA of another commit / short SHA / uppercase | `head-mismatch` fixtures |
| risk block | two fences; fence with info suffix `production-risk-assessment json` | `risk-block-multiple`, suffix-accepted fixture |
| risk block | JSON with extra key / missing key (StepFun 3661519) | `risk-block-keys` fixture |
| risk block | `assessed_risks` missing a gate-derived risk | `risk-block-risks` fixture |
| repair turn | reviewer flips decision on repair | `repair-changed-decision` test |
| repair turn | reviewer rewrites findings wholesale | findings-drift test |
| repair turn | second repair requested | one-repair-only test |
| report | decision word inside a code block of findings | fixture: allowed only if not line-leading |

### 10. Tests

New: `tests/review-report-contract.test.mjs` (all fixtures),
`tests/test-review-repair-turn.sh` (three stub-door cases in Step 5), drift
check test, events field test. Must stay green: `tests/test-ai-review-engine.sh`,
`tests/test-ai-review-packet.sh`, `tests/test-glm-pool-dispatch.sh`, the repo's
CI suite manifest, and in shared-db `node --test scripts/run-governed-review.test.mjs
scripts/prove-production-risk-acceptance.test.mjs`.

### 11. Constraints and gotchas

- Never push to protected `main`; branch + PR + merge queue; you merge.
- Every GitHub post signed `Posted by Claude chat <id> on <machine>`.
- Changes to review code need an AI review from a different engine via `ai-review`.
- shared-db: only shape changes need claims; this is tooling — verify in its AGENTS.md.
- Do not weaken shared-db's parser semantics; Step 4 must pass existing tests unchanged.
- Times in EST/EDT. Scratch under `$TMPDIR`.
- Tests touching events must set `AI_REVIEW_EVENT_DIR` (live log is refused).
- `PYTHONDONTWRITEBYTECODE` on edge-dev3 can break `__pycache__` fixtures.

### 12. Access and environment

hetz (`/worksp/ai-devops`, `/worksp/shared-db`), `gh` authenticated as
`u2giants`, node ≥20, python3. Incident store: `.ai/reviewer-issues/` in the
canonical checkout (a worktree's `ai-reviewer-issue path` points at its own empty
store — run `list` from the canonical checkout). No secrets needed.

### 12a. Platforms (owner requirement, 2026-10-19)

Albert, in his chat: "will this plan account for the fact that the reviewer
tooling is run on both windows and ubuntu (desktop and server)?" Every step
must therefore work the same on all three:

| Platform | Hosts | Review path | Install route |
|---|---|---|---|
| Ubuntu server | hetz, 916-alien | Bash lifecycle core + doors | `update.sh` protected install (`authorize-install`, see `docs/deployment.md`) |
| Ubuntu desktop | edge-dev3, edge-dev | same as server | same as server |
| Windows | 4837 (`C:\repos\ai-devops`) | Git Bash for Bash suites, PowerShell for PowerShell suites; OpenCode folder shell for StepFun review/ask | `bin/install-ai-devops-windows.ps1 -RepoPath <checkout> -ExpectedHead <SHA>` |

EDGE-ALIEN and Envy are not review hosts; install nothing there.

Acceptance criterion **P1 (parity):** the validator, the repair turn and the
format-outcome events behave the same on all three platforms. A step is not done
until its tests pass on Linux **and** on Windows (Git Bash plus PowerShell
5.1 and 7), and Step 8's live proof includes one governed review on a Linux host
and one on 4837.

Known Windows traps the steps must handle:
- Validator is Node (no `grep -P`/GNU-only flags); normalize CRLF before parsing,
  and keep `.gitattributes` `eol=lf` for every new Bash script.
- PowerShell 5.1 strips quotes from native arguments: pass report paths and
  prompts as files, never as quoted argv text.
- `gh` cannot read the keyring over Windows SSH; use gh file storage when
  driving 4837 remotely.
- StepFun `implement` is refused on Windows (review/ask only); the repair turn
  uses the review route there.
- Gemini fails over SSH on 4837; it is frozen anyway (#1714). Score it nowhere.
- Windows reviewers run from the installed checkout; prove the installed hash,
  not a worktree copy.

Roster scoring (Step 7) is **per provider per platform**: a provider kept in
rotation must meet the bar on every platform where it is drawn, or be marked
platform-limited in `config/review-runner-doors.json` capabilities (no
provider-name branches, rule #1834).

---

## Part 4 — Landing

### 13. Done, risks, open questions

Done: Steps 1–8 merged with green CI in both repos; installed on hetz, 916-alien,
edge-dev3, edge-dev and 4837 by the §12a routes with installed hashes verified;
criterion P1 met (Linux and Windows tests plus a live governed review on each
platform); live proof ticked on #1783; STATUS here updated with SHAs.

Risks: grammar change breaks in-flight reviews → land ai-devops accepting both
grammars for one release, then remove `## Verdict`. Repair turn could launder a
weak review → decision/findings lock in Step 5. Vendored copy drifts → CI check.
Rollback: revert the lifecycle call site; validator is additive.

Open: findings-drift threshold (10% starting point); which wrappers support a
same-session continue; final roster (Step 7 data).

## Self-audit

1. Fresh session executes without asking? Yes — §2, §5 give every file:line;
   §9 gives files, behaviour and gates; §12 the store path trap.
2. All background and ruled-out options? Yes — §3 incidents, §6 data, §7 rejections incl. #1854.
3. Goal clear for judgment calls? Yes — §1 plain-English goal with the override rule; §8 locks the safety-critical choices.
