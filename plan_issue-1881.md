# Implementation plan — popcre/ai-devops#1881 (trim and enforce the always-loaded AI ruleset: close out)

## Verdict (read first)

**One step left (checked 2026-11-04 9:42 PM EST).** The programme plan is
[`plan_ruleset-trim-and-enforce.md`](plan_ruleset-trim-and-enforce.md); its
STATUS is authoritative. Phases 1–5 are done with commits and tests. Phase 6.1
(live proof by transcript re-audit) ran on 2026-10-28 and did not pass: 3 of 4
criteria met; 2 of 41 sessions acted on a superseded rule, and both audited
machines had drifted installs. The re-run is tracked by #1998 and planned in
[`plan_issue-1998.md`](plan_issue-1998.md). This plan therefore adds only the
pieces #1998 does not cover: the hook gap for `gh run` polling loops that the
audit found in 7 of 41 sessions, and the closure procedure for #1881.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Extend the poll-guard hook to `gh run view/watch` loops | ⬜ open (2026-11-04) | — |
| 2 Hook block message names the current wait form (shared with #1998 step 1) | ⬜ open | — |
| 3 Reinstall globals on edge-dev3, edge-dev, al8960ofc; `--check` CLEAN | ⬜ open (edge-dev3 CLEAN 2026-11-04) | — |
| 4 Phase 6.1 re-audit passes all four criteria (#1998 steps 3–4) | ⬜ open | — |
| 5 Mark 6.1 ✅ in the programme plan; tick the issue checklist; close #1881 | ⬜ open | — |

A fresh session starts at Step 1 (Steps 1–2 are one PR). Handoff registration:
[HANDOFF.d/2026-11-04T2142Z-al8960ofc-claude-open-issue-plans-batch2.md](HANDOFF.d/2026-11-04T2142Z-al8960ofc-claude-open-issue-plans-batch2.md).

---

## 1. Ultimate goal

Every AI session Albert runs loads a block of standing rules. In October it was
about 8,000 words, stale in places, and the short rules were being skipped
(job plan followed in 7 of 44 sessions; hand-written PR polling in 11 of 44).
The goal: **agents actually obey the rules that matter, and the rules are
enforced by tooling where breaking them costs money or safety.** "Done" is a
fresh sample of real sessions showing no hand-rolled CI polling, no task-class
rejections, no action on retired rules, and no more owner corrections than
before. **If a step conflicts with this goal, the goal wins — stop and flag it
on #1881.** Never delete a safety rule to save words; never loosen an audit
criterion to pass.

## 2. What this application is

`popcre/ai-devops`: templates in `templates/system/` (`CLAUDE-global.md`,
`AGENTS-global-{codex,zcode,mimo}.md`) rendered by `bin/ai-render-globals` and
installed by `bin/ai-adopt-globals`; drift check `bin/ai-adopt-globals --check`.
Enforcement hooks: `bin/ai-pr-poll-guard-hook` (Claude PreToolUse, installed by
`bin/ai-install-pr-poll-guard-hook`), tests in
`tests/test-ai-pr-poll-guard-hook.sh` (28 cases). Machines: edge-dev3 (Ubuntu),
edge-dev and al8960ofc (Windows), hetz (VPS). Audit evidence is private
(`Dropbox/ai/chat_transcripts/_audit/`), never in Git; the transcript store and
`transcript-query` skill are the sampling tools.

## 3. Trigger

#1881 (2026-10-20 audit). Latest state: #1881 comment on 2026-10-28 ("Step
6.1 live proof — not passed: 3 of 4 criteria met") naming three gaps:
1. 7/41 sessions ran `gh run view` + `sleep` loops; the hook matches only
   `gh pr`.
2. The hook's block message still prescribes `--timeout-minutes N --fit-tool-call`
   although the 2026-10-21 ruling made the 60-minute background wait the default.
3. Neither audited machine had been reinstalled after rule-changing merges.

## 4. Scope

In scope: hook pattern extension, hook message, reinstall + drift check, the
re-audit (delegated to #1998's plan), closure.
**NOT in this plan:** further trimming of the globals (3.2 stopped above the
1,200-word target deliberately; the four-client block and test-pinned phrases
stay); any change to `ai-pr-wait` itself; a new tool (owner ruling 2026-10-21:
add NO new tooling); re-running the audit on hetz or al8960ofc (owner scope
2026-10-21: edge-dev3 and edge-dev only).

## 5. Current state (main `8e3b916a`)

- `bin/ai-pr-poll-guard-hook:59-70`: five `reason` patterns, all anchored on
  `g[h] pr (view|checks|merge)` or `ai-pr-wait`; none mentions `gh run`.
- `bin/ai-pr-poll-guard-hook:72`: block message text "Use one bounded wait
  instead: bin/ai-pr-wait <pr> --timeout-minutes N (add --fit-tool-call …)".
- `bin/ai-pr-wait`: `TIMEOUT_MINUTES=60` default; background use is the
  documented form in all four globals.
- `plan_ruleset-trim-and-enforce.md` STATUS: 1.1–5.1 ✅; 6.1 ❌; 2.3 ✅.
- edge-dev3 `ai-adopt-globals --check`: CLEAN on 2026-11-04 (per
  `plan_issue-1998.md` verdict). edge-dev and al8960ofc: unknown since 10-28.

## 6. Key findings

- The hook sees one Bash command at a time; loops over `gh run view`,
  `gh run watch`, `gh run list` with `sleep` are the same anti-pattern as
  `gh pr` loops and burn the same quota (memory note: `gh run watch` burns the
  API quota). `gh run watch` is itself a polling loop even without `sleep`.
- The hook must not block a single `gh run view` (a legitimate one-shot read);
  only loops/sleep combinations.
- Test harness pattern: `tests/test-ai-pr-poll-guard-hook.sh` feeds JSON
  `{"tool_input":{"command":"…"}}` to the hook and asserts exit 2 + the reason.

## 7. Rejected approaches

- A separate `gh run` hook: rejected; one hook, one install path, one test file.
- Blocking all `gh run watch`: considered. `gh run watch` with no loop is a
  single foreground wait that still polls internally; the audit counted it as
  a loop. Decision below leaves it as a judgment call with a default.
- Trimming the globals further to hit 1,200 words: rejected (3.2 decision,
  2026-10-20, locked).

## 8. Decisions

Locked: the four audit criteria and their targets (≤2/40 polling loops, 0
class rejections, 0 superseded-rule sessions, ≤23/44 corrections); scope
edge-dev3 + edge-dev; no new tooling.
Open: whether bare `gh run watch` is blocked. Default: block it (reason
"gh run watch is a polling loop; use bin/ai-pr-wait in the background"), since
`ai-pr-wait` covers the PR case and a workflow run can be read once with
`gh run view` after the PR wait wakes.

## 9. Steps

**Step 1 — Hook patterns.** In `bin/ai-pr-poll-guard-hook` after the five
existing `elif` branches, add:
- `\bsleep\b.*\bg[h] run (view|list|watch)\b` → "sleep followed by a workflow-run read";
- `\b(until|while|for)\b.*\bg[h] run (view|list|watch)\b` → "a loop over a workflow-run read";
- `\bg[h] run watch\b` → "gh run watch is a polling loop" (per §8 default).
Keep the `g[h]` spelling (it stops the hook matching itself). Gate: new cases
in `tests/test-ai-pr-poll-guard-hook.sh`: `blocks sleep + gh run view`,
`blocks while loop over gh run list`, `blocks gh run watch`, and negatives
`allows single gh run view`, `allows gh run list -L 5`. All 33+ cases pass.

**Step 2 — Message.** Replace line 72's text with: "Blocked: hand-written
polling ($reason). It cannot see a merge-queue ejection and burns the GitHub
API quota. Run `bin/ai-pr-wait <pr>` in the background (run_in_background) and
do other work until it wakes you; rerun it on exit 2." Update the existing
test that asserts the old message substring. Gate: `grep -c fit-tool-call bin/ai-pr-poll-guard-hook` prints 0; test file green.

**Step 3 — Reinstall and drift check.** After Steps 1–2 merge: on edge-dev3,
edge-dev and al8960ofc run the documented protected install (`update.sh`, see
`docs/deployment.md`) then `bin/ai-adopt-globals --check` and
`bin/ai-install-pr-poll-guard-hook --check` (or its documented verify flag).
Gate: all four globals CLEAN on each machine; hook installed at the current
SHA. Record date and SHA on #1881.

**Step 4 — Re-audit.** Execute `plan_issue-1998.md` steps 3–4 at least seven
days after Step 3 (sessions must have run under the new install). Gate: all
four criteria met on the fresh sample; counts posted on #1881.

**Step 5 — Close.** Set 6.1 ✅ in `plan_ruleset-trim-and-enforce.md` with the
comment link; tick the six checklist boxes in #1881's body; close #1881 and
#1998 with signed comments.

## 10. Tests required

- New (by name) in `tests/test-ai-pr-poll-guard-hook.sh`: the five cases in
  Step 1 plus the updated message assertion.
- Existing green: `tests/test-ai-pr-poll-guard-hook.sh`,
  `tests/test-ai-pr-wait.sh`, `tests/test-client-globals-required-phrases.sh`,
  `tests/test-ai-adopt-globals.sh`, `tests/test-ai-render-globals.sh`.

## 11. Constraints and gotchas

- The hook runs on every Bash call in Claude; a false positive blocks real
  work. Keep patterns loop-anchored; test negatives.
- Windows: the hook runs under Git Bash; CRLF in the script breaks it
  (`.gitattributes` enforces LF — do not override).
- Audit evidence stays private; post counts only, never transcript text.
- Protected `main`, PR, `bin/ai-pr-wait` in the background, signed comments.

## 12. Access and environment

`gh` as `u2giants`; SSH to edge-dev3/edge-dev per
`templates/system/machine-atlas.md`; local Git Bash on al8960ofc. Transcript
store access per the `transcript-query` skill. No secrets.

## 13. Definition of done, risks, open questions

Done: hook change merged and installed on three machines; re-audit passes;
STATUS and issue updated; #1881 and #1998 closed. Risk: hook false positives —
rollback is `git revert` plus reinstall. Open: `gh run watch` policy (§8,
default given).

## Self-audit

1. Executable without questions: yes — §5 line anchors, §9 regexes, test names
   and gates.
2. Background carried: yes — programme history lives in
   `plan_ruleset-trim-and-enforce.md`; §3/§6/§7 carry the audit gaps and the
   decisions not to trim further or add tools.
3. Goal for judgment: yes — §1 with the "never loosen a criterion" rule.
