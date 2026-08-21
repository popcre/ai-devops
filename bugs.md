# Reviewer system audit — 2026-08-20

Scope: every current reviewer wrapper and the shared packet, snapshot, preflight,
scoreboard, and incident-recording helpers. This is a read-only audit report; no
reviewer behavior was changed.

Severity meanings:

- **CRITICAL:** can expose or overwrite files outside the intended boundary, or
  can attach evidence from the wrong repository/run.
- **HIGH:** can approve without a trustworthy review, violate read-only claims,
  duplicate paid work, lose a paid run, or make a reviewer unusable.
- **MEDIUM:** materially weakens visibility, recovery, or evidence freshness.
- **LOW:** poor failure guidance without evidence corruption.

## CRITICAL

### 1. DeepSeek session names can escape their storage folder

- Files: `bin/ai-deepseek-agent:177-180`, `bin/ai-deepseek-agent:217-233`
- Confidence: high
- What happens: the caller-provided session name is placed directly into a file
  path without proving that the result stays inside DeepSeek's private session
  folder.
- User-visible failure: a crafted name such as `../../target` can make `show`
  disclose, or `reply` rewrite, a reachable JSON file outside DeepSeek's session
  storage.
- Required correction: restrict names to a safe character set, resolve the final
  path, prove it remains inside the session folder, and add hostile path tests.

### 2. Reviewer incident reports can attach another run's evidence

- Files: `bin/ai-reviewer-issue:54-60`, `bin/ai-reviewer-issue:119-155`
- Confidence: certain; reproduced in both Grok issue-56 evidence packages
- What happens: the recorder selects the newest provider record instead of the
  named run, repository, commit, and caller.
- User-visible failure: a failure in repository B can be documented with a
  successful or unrelated review from repository A. The packet looks official
  while describing the wrong event.
- Existing tracker: issue #56, plan step 6.

## HIGH

### 3. Gemini's read-only proof can miss real writes

- Files: `bin/ai-gemini:21-26`
- Confidence: high
- What happens: it compares only the short Git status text before and after a
  run. A file that was already shown as modified can be changed again without
  changing that text. Ignored files and paths outside the repository are not
  covered.
- User-visible failure: Gemini can alter code or review evidence and still be
  reported as read-only.
- Existing tracker: issue #38. The required hostile-write qualification remains
  open in `plan_ai-gemini-wrapper.md`.

### 4. Gemini can report success when no report was saved

- Files: `bin/ai-gemini:35-37`
- Confidence: high; matches the bare-PASS/empty-report trial evidence
- What happens: an unsafe or unwritable report destination returns success, and
  the caller then prints `PASS` with a report path.
- User-visible failure: a change appears independently approved, but there is no
  durable review to inspect.
- Existing tracker: issue #38.

### 5. Gemini can accept the wrong resumed conversation

- Files: `bin/ai-gemini:24`, `bin/ai-gemini:37`
- Confidence: high
- What happens: any non-empty returned conversation identifier is accepted; it
  is not compared with the stored identifier requested by the caller.
- User-visible failure: a verdict from another conversation can be attributed to
  the current review.
- Existing tracker: issue #38.

### 6. Gemini has no in-progress record, lock, or failed-run recovery

- Files: `bin/ai-gemini:36-39`
- Confidence: high
- What happens: state is written only after the paid provider call. Concurrent
  replies, deletion during a call, timeout, or interruption are not governed.
- User-visible failure: paid work can vanish, two calls can advance one
  conversation at once, and there is no trustworthy way to recover or explain
  the result.
- Existing tracker: issue #38.

### 7. Grok's one-paid-review rule fails across clones

- Files: `bin/ai-grok-review:202-206`, `bin/ai-grok-review:597-604`,
  `bin/ai-grok-review:658-665`
- Confidence: certain; observed with concurrent shared-db reviews
- What happens: the lock identity includes the physical checkout path. Two
  clones of the same GitHub repository therefore receive different locks.
- User-visible failure: duplicate billed reviews can run against the same
  repository at the same time.
- Existing tracker: issue #56; all repair-plan steps remain open.

### 8. Kimi has the same clone-based duplicate-run weakness

- Files: `bin/ai-kimi:349-353`, `bin/ai-kimi:1012-1014`
- Confidence: high
- What happens: Kimi also includes the physical checkout path in the identity
  used for its claimed repository-wide lock.
- User-visible failure: separate clones can start concurrent Kimi jobs for the
  same upstream repository.
- Tracker gap: this is not covered by the current issue-46 closeout plan.

### 9. Kimi is still unavailable as a trusted live reviewer

- Files: `plan_kimi-review-failure-recovery.md:11-18`
- Confidence: certain from repeated installed live probes
- What happens: authentication and safety checks pass, but the provider does not
  return the required completion record.
- User-visible failure: Kimi cannot currently deliver a qualified review. Its
  repaired failure handling is correctly keeping it quarantined.
- Existing tracker: issue #46.

### 10. Muse rejects valid repositories containing historic review reports

- Files: `bin/ai-muse:96-97`
- Confidence: high; reproduced in shared-db
- What happens: Muse rejects the repository when any file under `.ai/reviews/`
  is tracked, even when those historic reports are deliberate, cited records.
- User-visible failure: Muse cannot start in shared-db.
- Existing tracker: issues #45 and #51.

### 11. Muse leaves no visible state during a long provider call

- Files: `bin/ai-muse:139-146`
- Confidence: high; reproduced in two 17-minute stalls
- What happens: session metadata and output are created only after the provider
  turn finishes.
- User-visible failure: a caller cannot tell whether Muse never started, is
  healthy, is stuck, or has vanished; repeated attempts can waste more time and
  paid usage.
- Existing tracker: issue #51.

### 12. Codex reports success even when the review command failed

- Files: `bin/ai-codex-review:138-159`
- Confidence: high
- What happens: command failure or a missing output artifact adds a warning but
  the wrapper still exits successfully and does not require a verdict.
- User-visible failure: automation can treat “no review happened” as successful
  independent review.

### 13. Codex omits all brand-new files from its review

- Files: `bin/ai-codex-review:69-73`
- Confidence: high
- What happens: it uses a comparison that sees tracked edits but not new,
  untracked files.
- User-visible failure: a newly added file—the main substance of many changes—
  can receive no review while the wrapper reports completion.

### 14. Evidence packet verification does not bind file names or empty files

- Files: `bin/ai-review-packet:452-475`
- Confidence: high
- What happens: the seal hashes concatenated file contents, not each file name
  and boundary. Empty files contribute nothing.
- User-visible failure: files can be renamed, regrouped, or empty files added or
  removed while verification still says the packet is intact.

### 15. Review snapshots can copy content from outside the repository

- Files: `bin/ai-review-sandbox:85-94`
- Confidence: high
- What happens: an untracked link is copied by following its target.
- User-visible failure: a link to an outside file can pull that file into the
  supposedly self-contained review copy, exposing content and making the
  snapshot claim false.

### 16. Qwen can silently continue a review against a different code version

- Files: `bin/ai-qwen:894-899`, `bin/ai-qwen:949`
- Confidence: high
- What happens: stored session metadata does not bind the conversation to the
  original base, commit, working-tree state, or evidence packet. Continuation
  refreshes the review copy to current code and resumes old reasoning.
- User-visible failure: Qwen can combine conclusions from two different versions
  without warning and no freshness check can detect it.

### 17. The scoreboard can call unknown evidence current

- Files: `bin/ai-review-scoreboard:39-45`
- Confidence: high
- What happens: evidence defaults to current and is marked stale only when both
  the repository and commit are available and a mismatch is proven. Missing or
  unreadable identity stays “current”; later uncommitted changes are ignored.
- User-visible failure: a dashboard can present unverifiable or changed evidence
  as safe to use.

## MEDIUM

### 18. Grok interruption and deletion do not tell the truth about remote work

- Files: `bin/ai-grok-review:604`, `bin/ai-grok-review:665`,
  `bin/ai-grok-review:762-767`
- Confidence: high
- What happens: the local lock can disappear, or records can be deleted, without
  proof that the remote paid turn stopped.
- User-visible failure: another review may be started while the first provider
  call is still running.
- Existing tracker: issue #56.

### 19. Grok has no useful live progress or cross-clone activity view

- Files: `bin/ai-grok-review:303-330`, `bin/ai-grok-review:730-743`
- Confidence: certain
- What happens: the caller stays silent until final output, and `list` sees only
  completed records for the current checkout.
- User-visible failure: a healthy long review, a stuck review, and an abandoned
  review look the same.
- Existing tracker: issue #56.

### 20. GLM says the service started before it is ready

- Files: `bin/ai-glm:1551`, `bin/ai-glm:1582`
- Confidence: high
- What happens: `start` reports success immediately; only `restart` waits for a
  health check.
- User-visible failure: the next automated review can fail for roughly 20
  seconds even though the start command reported success.

### 21. Muse assigns omitted callers to Codex

- Files: `bin/ai-muse:11`, `skills/shared/ask-muse/SKILL.md:31-33`
- Confidence: high; reproduced in a Claude-launched run
- What happens: caller identity defaults to Codex and relies on every other
  caller remembering an environment setting.
- User-visible failure: Claude-started sessions can become invisible to Claude
  for later continuation.

### 22. DeepSeek can corrupt conversation history on failure or concurrency

- Files: `bin/ai-deepseek-agent:146-157`, `bin/ai-deepseek-agent:231-232`
- Confidence: high
- What happens: history is rewritten without a lock or atomic replacement, and
  the user message is permanently added before the provider succeeds.
- User-visible failure: concurrent replies can lose turns; a failed request
  leaves a dangling turn that is sent again later.

### 23. Codex review files can collide within the same second

- Files: `bin/ai-codex-review:66-67`
- Confidence: high
- What happens: the output name uses only mode plus a timestamp rounded to one
  second.
- User-visible failure: concurrent reviews can overwrite or mix their reports.

### 24. Central health and evidence tools cover only three providers

- Files: `bin/ai-review-preflight:21`, `bin/ai-review-preflight:140`,
  `bin/ai-review-preflight:165`, `bin/ai-review-scoreboard:18`,
  `bin/ai-review-scoreboard:65`
- Confidence: high
- What happens: Grok, Kimi, and GLM are integrated; Muse, Gemini, Qwen, Codex,
  and DeepSeek are not consistently represented.
- User-visible failure: “reviewer health” and performance reports describe only
  part of the reviewer fleet, while ungoverned reviewers are still available.

### 25. Gemini's plan, standing instruction, and actual code contradict each other

- Files: `plan_ai-gemini-wrapper.md:13-26`,
  `plan_ai-gemini-wrapper.md:116-128`, `AGENTS.md:69`, `bin/ai-gemini`
- Confidence: high
- What happens: one status section says initial work is complete, another says
  no wrapper exists and implementation is blocked, the standing rule says not
  to implement, yet a wrapper and skill are present.
- User-visible failure: one session may use an unsafe unfinished reviewer while
  another refuses to work on it, depending on which source it reads.

## LOW

### 26. Kimi missing-job commands return raw file errors

- Files: `bin/ai-kimi:1059-1070`, `bin/ai-kimi:1111-1112`
- Confidence: high
- What happens: `status` and `logs` do not perform the friendly existence check
  used by `wait`.
- User-visible failure: a mistyped job name produces a raw parser/file error
  instead of saying that the job does not exist and how to list valid jobs.

## What the passing tests do and do not prove

The current offline tests verify many important safety rules and the corrected
Windows run passed the shared packet, snapshot, preflight, scoreboard, incident,
and Grok suites encountered during this audit. However, the findings above are
mostly missing-test cases: clone equivalence, hostile links, filename-bound
packet seals, already-dirty Gemini files, wrong conversation identifiers,
DeepSeek path traversal, Codex command failure, and cross-version Qwen resume.
Passing the existing suite therefore does not contradict these findings.

## Recommended repair order

1. Stop offering Gemini, Codex review, DeepSeek, and Qwen as approval-capable
   reviewers until their HIGH findings are fixed and tested.
2. Fix incident correlation and packet/snapshot integrity because every provider
   relies on trustworthy evidence.
3. Implement issue #56 and extend the same normalized repository lock to Kimi.
4. Repair Muse startup/state visibility and complete Kimi live qualification.
5. Bring every active reviewer under one health, quarantine, evidence-freshness,
   and performance contract.

## Implementation plans

- Shared evidence: [`plan_reviewer_shared_evidence_integrity.md`](plan_reviewer_shared_evidence_integrity.md)
- Codex: [`plan_codex_reviewer_trust_repair.md`](plan_codex_reviewer_trust_repair.md)
- DeepSeek: [`plan_deepseek_reviewer_safety_repair.md`](plan_deepseek_reviewer_safety_repair.md)
- Gemini: [`plan_gemini_reviewer_safety_repair.md`](plan_gemini_reviewer_safety_repair.md)
- Grok: [`plan_grok_reviewer_runtime_repair.md`](plan_grok_reviewer_runtime_repair.md)
- Kimi: [`plan_kimi_reviewer_completion_repair.md`](plan_kimi_reviewer_completion_repair.md)
- Muse: [`plan_muse_reviewer_availability_repair.md`](plan_muse_reviewer_availability_repair.md)
- Qwen: [`plan_qwen_reviewer_evidence_repair.md`](plan_qwen_reviewer_evidence_repair.md)
- GLM: [`plan_glm_reviewer_startup_repair.md`](plan_glm_reviewer_startup_repair.md)
