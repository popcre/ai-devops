---
issue: null
status: OPEN
owner: mimo/reviewer-issues-after-watchdog
---

# HANDOFF — open reviewer incidents after watchdog duty-pool close

Machine: edge-dev · Agent: mimo · Written: 2026-10-05 (wrap-up)
GitHub signature: `Posted by MiMo chat unknown on edge-dev`

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

- **Already decided (do not re-ask):** Watchdog duty pool is done and shipped;
  do not rebuild it. Never pay Blacksmith for alarms. Claim issue is #1288.
- **Still his:** nothing for this handoff. Reviewer-wrapper repairs are
  technical.
- **Not Albert's call:** which provider door to fix first, whether to re-try
  quarantined Qwen/Gemini, or how to make review reports publish durably.

## 1. What this application is

`popcre/ai-devops` — public AI workflow recovery toolkit. This handoff is NOT
about the watchdog feature (that is complete). It carries **open reviewer-tool
incidents** recorded while getting an independent review for PR #1286.

## 2. What we set out to do this session, and why

Implement plan P0–P5 (local watchdog timers + claim/lease). That landed
(#1286, #1313, #1316; issue #1287 closed). Getting the required independent
review hit broken reviewer infrastructure; those failures are logged and still
unrepaired.

## 3. Current state — what is true right now

| Outcome | State | Artifact |
|---|---|---|
| Watchdog duty pool P0–P5 | **Done** | PR #1286 `62c264b`, #1313 `1c50538`, #1316 `cceeab1`; #1287 CLOSED |
| Muse independent APPROVE | Done | `.ai/reviews/muse-final-check-20261005T143608-139089-19692.md` (head `bf20f262`) |
| Reviewer incidents from this session | **OPEN** | `.ai/reviewer-issues/20261005T*` (see §6) |
| Qwen / Gemini preflight | Quarantined (`live-qualification-required`) | `ai-review-preflight usable <provider>` |
| Stale `*.tmp.*` in `~/.ai-devops/gh-throttle/` | Quarantined to `quarantine-tmp-20261005/` (subagent) | May need a durable fix in `bin/ai-gh` |

## 4. Everything we tried that did NOT work

- `ai-review --implementer mimo …` — refused: MiMo is not in
  `config/reviewer-registry.json` (registry state: absent).
- DeepSeek door — `provider call failed (exit 1)`.
- Grok door — `non-terminal stopReason: cancelled`.
- Gemini / Muse pool — review text written under `.ai/reviews/` but lifecycle
  reported `required report is not durably published`.
- First Muse pass REJECTED `d71152f` (real bugs); fixed; second pass APPROVE.

## 5. Root causes and key findings

1. Report publish / sandbox evidence path fails open (reports exist on disk but
   are not durable to the lifecycle store).
2. `--implementer` cannot name MiMo; independence recording needs a registry
   row or a documented alias.
3. Quarantined providers need live requalification before another formal review.
4. Stale throttle `*.tmp.*` files break quota-context switching.

## 6. Exact next steps

1. **Reviewer-log repair round** for every 20261005 incident in
   `.ai/reviewer-issues/` (start with
   `20261005T121424Z-edge-dev-gemini-366723`). Load `log-reviewer-issue` +
   `docs/reviewer-issues.md`; use `ai-reviewer-issue maintenance show` before a
   sweep. Do not invent a resolved status.
2. Diagnose `ai-review-engine` durable-publish (MANIFEST seal / packet retain)
   so a completed review is stored.
3. Decide how a MiMo implementer is recorded (registry row vs alias) — technical.
4. Leave Qwen/Gemini quarantined until live qualification passes.

**Verify success:** `ai-review <provider> final-check` on any small PR returns a
durable report path with VERDICT + full head SHA; affected incidents resolved or
partially-resolved with evidence.

## 7. Constraints and gotchas in force

- Branch + PR + merge queue; never push `main`; `git var GIT_COMMITTER_IDENT`
  must be Albert’s identity.
- Secrets: 1Password `vibe_coding` only. `RUNNER_POOL_READ_TOKEN` item title
  `GitHub PAT ai-devops RUNNER pool read token`; host files at
  `~/.config/ai-devops/secrets/watchdog.env` (chmod 600).
- Do not re-do PR #1193. Leave `C:\repos\ai-devops-wt-runner-pool` alone.
- Worktree `C:\repos\ai-devops-wt-watchdog-local` (branch
  `mimo/watchdog-duty-pool-live-proof`, tip `f48eb8a`) is **stale** vs main —
  do not merge it (it would regress §7 docs). Safe to retire via
  `cleanup-worktree` after confirming nothing unique is needed.
- Times in human output: EST.

## 8. Access and environment

- Hosts: edge-dev (Windows), edge-dev3 (`ssh -i ~/.ssh/916-alien ahazan@edge-dev3`,
  `/home/ahazan/repos/ai-devops`), hetz (`ssh vps2-direct`, user `ai`,
  `/worksp/ai-devops`).
- `ai-local-watch` is scheduled on all three. Claim issue #1288.
- `gh` as `u2giants` on edge-dev.

## 9. Open questions and risks

- Whether `bin/ai-gh` should ignore/quarantine `*.tmp.*` permanently (subagent
  finding).
- How long Qwen/Gemini stay quarantined without a live qualification session.

---

## Self-audit (handoff-standard)

1. **Cold start?** Yes — §1–§3 name repo, PRs, issue #1287 closed, and that
   reviewer incidents are the open work.
2. **As effective as me?** Yes — §4 failures, §5 causes, §6 next commands and
   verify line.
3. **Failures included?** Yes — §4.
4. **Concrete next steps + verify?** Yes — §6.
5. **Terms/paths explained?** Yes — claim issue, duty pool, doors, quarantine.
6. **§0 sweep?** Yes — no Albert decision required.

**Synthesis:** A brand-new developer can open a maintenance round on the
20261005 reviewer incidents using this file + `docs/reviewer-issues.md` +
`plan_reviewer-log-repair-checkpoints.md`, without touching the finished
watchdog work. Evidence: §3 artifacts, §6 verify line.
