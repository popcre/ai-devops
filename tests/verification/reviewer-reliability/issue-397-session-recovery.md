# Issue #397: exact-session completion recovery

This is the qualification record required by the reviewer reliability plan. It
records the completed recovery slice under #337. Parent #159 remains open for
its later children.

## Root causes and repaired behavior

- Qwen could discard the pending stream before active metadata was durable, and
  a conditional caller could swallow report-publication failure. Local
  `finalize` now validates the exact session, terminal stream, source packet,
  model, runtime/preloader fingerprints, and original invocation. It publishes
  the report and metadata before removing pending bytes. It sends no prompt.
- GLM could mistake the previous stopped assistant for the submitted turn while
  the status endpoint was blind. A pre-submission assistant watermark identifies
  the new turn. Completed bytes are retained before optional reporting, and
  `recover` only observes the existing remote turn or finalizes retained bytes.
  Permission replies for that existing turn remain allowed; no prompt is replayed.
- Muse `reconcile` previously cleared uncertain state solely because a session
  ID existed. It now requires a retained successful process and exact matching
  terminal stream. Raw response, request, process result, session, packet, and
  original invocation survive local post-processing failure. Recovery compares
  an existing report byte-for-byte and reuses its inode; a different report is
  never replaced. Native Windows and Git Bash paths represent the same stored
  identity consistently.
- GLM and Muse can retain a completed response after source movement, explicitly
  non-authorizing, then permit an ordinary fresh turn in the same conversation.
  Shared `verify-retained` validates the sealed isolated snapshot and full patch
  but never emits the live-source authorization receipt.
- Dependency #395 keeps the original paid invocation as the sandbox owner for
  local recovery. A failed local retry cannot create an additional fictitious
  paid-work cleanup obligation. Each successful local retry still needs its own
  durable linked receipt.

## Recorded local evidence

- Exact-head independent GLM review of
  `c68854717ad447223cb3bf0d15924e0b06d839b9`, base
  `69716e401c7d1913d235a160d9b6ec710c2648e8`: wrapper exit 0, terminal APPROVE,
  model `zai-coding-plan/glm-5.3`. The private report remains under the owning
  worktree's ignored `.ai/reviews/`. Its valid availability findings drive the
  subsequent deterministic-context and local-retry ownership repairs; that
  approval does not cover later commits.
- Packet suite: 113 passed, 0 failed. Includes unchanged retained evidence after
  source movement, no authorizing receipt, snapshot tampering, and packet tampering.
- Qwen narrowed real-evidence recovery fixture: 7 passed, 0 failed. Metadata
  publication failure retains the complete response; exact local retry reuses
  one report; a different returned session cannot be adopted.
- GLM recovery fixture: successful prior-watermark, failed-publication,
  retained-byte tamper, exact retry/repeat, completed-stale, and missing-origin
  refusal cases. Provider submission count remains zero during recovery.
- Muse report-retry subset with dependency `aec890d7`: 47 passed, 0 failed.
  Includes changed-report refusal, identical inode reuse, fresh continuation,
  and refusal to clear a failed process merely because its session ID is known.
  Stale completion, retained-byte tamper, and no-provider repeat cases also
  passed in the preceding focused run. The first full owning suite recorded
  139 passed and 6 failed: shared cleanup obscured original failure states and
  skipped exact staging/lock cleanup. Dependency `ebbc1773` repairs that cause;
  the integrated full run then recorded 142 passed and 3 cascading fixture
  failures: a test claimed evidence was missing while retaining a recoverable
  successful turn. The fixture now removes that proof for the refusal check.
  The final recovery subset, including #333 immutable usage observations, passed
  53 checks with zero failures. All new recovery cases passed.
- GLM elapsed-deadline fixtures: 3 passed, 0 failed. HTTP time and initial sleep
  count against the existing turn limit; an expired recorded deadline permits
  no further polling. The existing recovery composite also passed afterward.
- GLM permission authentication now travels through the existing protected curl
  configuration pipe. The synthetic regression proves authentication remains
  present on standard input and absent from command arguments. No real password
  was inspected; this is code-path evidence, not proof of external disclosure.
- Independent GLM review of `060cd3d27256be6b66e49a1aeccb37871d35d73a`
  returned APPROVE with wrapper exit 0. Its valid Muse accounting retry finding
  is repaired by saving the chosen accounting JSON in the existing atomic
  retained-turn write. There is no second metadata write that can leave the
  paid report and retained accounting inconsistent. The focused owning recovery
  suite passed 55 checks, including a fault that rejects the former second
  write and recovery of the original unavailable accounting without recomputation.
- DeepSeek formal reviews now bind caller, requested model, repository and
  session across wrapper restarts. Changed caller/model refuses before provider
  contact; ordinary conversations retain their existing model selection.
  Source-change metadata preserves these identities so ordinary fresh-source
  review continuation remains possible. The existing focused suite passed
  32 checks with zero failures/skips; unknown legacy model provenance is not
  inferred from current configuration.

## Final integrated qualification

### DeepSeek local publication recovery

The additional DeepSeek slice retains the exact request, original invocation,
HTTP observation, paid response hash, attachment ledger intent and formal
packet before local publication. `ai-deepseek-agent finalize SESSION` repairs
the transcript, ledger and metadata without credentials or a provider request.
Pending evidence blocks accidental replay. Completed source-stale work remains
non-authorizing; a later explicit turn can resolve fresh source. Proven HTTP
refusals can also be finalized locally as incomplete, with a nonzero result and
ordinary explicit continuation preserved. Unknown transport outcomes and legacy
markers lacking exact retained intent remain fenced rather than guessed.

The owning offline recovery cases cover publication faults, changed response
bytes and source inventories, caller mismatch, repeat finalization, stale
formal source, HTTP refusal and explicit continuation. The final DeepSeek suite
passed 131/0/0, including 26/0/0 focused recovery checks. The extraction helper
preserves existing terminal parsing for the separate #394 native-status repair.

The expired-deadline recovery regression passes: recovery makes one bounded
GET observation before consulting the original polling deadline. A new terminal
assistant message can be retained after that deadline; an old or incomplete
message leaves the original deadline and pending fence unchanged. No POST,
deadline renewal, or automatic replay is introduced (owning focused case: 1/0).

Grok 1.0.13 exposes retained transcript export but no documented authoritative
remote-run status or acknowledged cancellation command. A live timed-out review
was exported read-only: 8,321 bytes, SHA-256
`9e322a20d35ab15f9e500dc995e5c35862981aa6502f62163e194522a0cc750e`.
The private export contains intermediate paid progress and no terminal verdict.
Its existing incident and uncertain work lock remain open and untouched. Local
leader state cannot establish remote cancellation. This is an unresolved
qualification limitation, not a recovered result or permission to retry.

PR #447 landed the provider recovery matrix as
`24279f17b960f20e7731bd80e8fd82e6dec5bbbe`. Its exact source head
`6bf539b9004c97e8207bcdc0da60c67602b79563` received independent APPROVE;
required run `34837962149` and merge-queue run `34842163354` passed. Installed
live canaries then exposed two defects: protected DeepSeek re-entry dropped the
governed run identity, and an ordinary retained DeepSeek turn could remain
fenced after source movement. PR #453 repaired both and landed as
`3098a89a65df5b5de2c00debc0653e7df0871c85`. Its exact head
`cbfec6023ef4199c10f09a06f93f54891cd41ddb` received independent APPROVE;
required run `34848157010` and merge-queue run `34852705794` passed. The
canonical installation at `3098a89a` passed the machine-tools doctor.

Installed governed live evidence on exact `3098a89a` proves:

- Qwen retained a paid terminal result when local report publication failed,
  then `finalize` published it without provider resubmission.
- GLM retained a completed turn across a service restart, and `recover`
  published the same exact-session result without replay.
- Muse returned APPROVE, then a separate wrapper process continued the same
  repository/caller/model/source conversation and returned APPROVE again.
- DeepSeek preserved a formal session across an initial durable BLOCKED result,
  accepted the requested large attachment evidence in the same conversation,
  and returned exact-head APPROVE. The attachment set exceeded the Windows
  command-line ceiling, proving protected attachment transport rather than
  inline argument transport.

The exact suites exercise Kimi, Grok, Gemini, DeepSeek, Qwen, GLM and Muse
restart/continuation, two repository/caller identities, concurrent names and
changed-identity refusal. They reuse each provider's owning tests; no generic
replacement harness was introduced. DeepSeek incident
`20260911T005524Z-edge-dev-deepseek-294011` has an append-only RESOLVED record
with the live evidence. Qwen incident
`20260910T081507Z-edge-dev-qwen-1166` remains open because its stale PR-base
symptom belongs to #393 source-identity acceptance, not this recovery slice.

Legacy GLM records without an original invocation binding and prior-assistant
watermark remain unknown. A session ID or a unique timestamp is not sufficient
to invent that provenance. Paid transcripts are retained privately and no
uncertain prompt is automatically repeated. Pre-existing live-checkout sessions
also cannot acquire an invented isolated historical snapshot.

### Historical current-main drift gate — incomplete Windows verification

[Run 34856869730](https://github.com/popcre/ai-devops/actions/runs/34856869730)
tests exact code head `22a7f22b88198e1bcc26ec99ebc135819b8f06f4`.
The September 14, 16:05 UTC refresh confirms Linux passed, the hosted reviewer fallback
passed at 15:55:04 UTC, and the reviewer-safety aggregate passed at 15:55:10 UTC.
The preferred reviewer job reports success, but its log states that its
30-minute bound was reached at 15:08:40 UTC and hosted fallback was required.
That job status is not proof that the preferred suite completed; the passing
hosted fallback supplies the reviewer evidence for this run.

The hosted fallback's completed log reports Codex 49 passed / 0 failed (no
skip count reported) and Grok 234 passed / 0 failed / 0 skipped. The canonical
checkout remains clean at `28c86d1b0c4fd9bbb7a1801a4f8b6454b2bbbbfd` and all
four installed Qwen, GLM, Muse and DeepSeek launchers still resolve there.
Compared with the installed live-canary head `3098a89a`, Qwen, Muse and
DeepSeek wrappers are unchanged; GLM's only wrapper change adds the documented
lost-evidence command to a preservation warning. No new provider replay or
installation was used for this read-only drift check.

The complete hosted Windows job (`104018683199`) started at 14:38:20 UTC and
ended CANCELLED at 16:23:47 UTC on September 14, after its 105-minute bound.
The whole run is CANCELLED. Its log selected all 74 Bash suites, completed only
the first 18, and entered Kimi as suite 19 at 16:06:51 UTC. Kimi was still
reporting individual passing checks when cancellation arrived; it produced no
completed suite result. No full Bash result or PowerShell-suite completion was
produced. Cancellation is incomplete verification, not an established code
failure or a passing full run.

At that checkpoint #397 remained OPEN. The prior paid-recovery, installation, incident and passing
fallback evidence remains recorded above; it does not replace the missing full
Windows proof. The complete-matrix scheduling repair recorded in the latest handoff must provide an
evidence-backed path to complete verification before closure. Do not rerun this
unchanged cancelled workflow or infer completion from the reviewer aggregate.

### September 14 continuation: complete scheduling and exposed failures

The separate merge-policy repair landed through PR459 as
`7f3b3b8eea6e6bf886cf2f23b87e4a25a54c531c`; live ruleset21564317 requires
`verification-closure`. Its interrupted predecessor task was not resumed or
duplicated. Preserved #397 work was rebased onto that current main.

PR460 merged as `3194b163ae3cb8eb716298724f4c51cc7809820e` after exact-head
GLM5.3 approval, corrected CI34891922168 and queue34896562246. Complete mode
partitions all discovered Bash suites across five independent hosted machines;
section3 runs all PowerShell suites exactly once. Ordinary PR sections,
no-argument serial behavior and the105-minute bound are retained. The initial
Linux fixture failure was repaired by capturing the actual PowerShell exception
message; all48 selection assertions remain. Corrected Linux ran75 suites with0
failures, all five PR Windows sections and18 PowerShell suites passed, and the
hosted reviewer supplied Codex49/0 and Grok234/0/0.

The normal acceptance launcher then exposed a missing-ref API error body being
mistaken for a SHA. PR461 discards output when that lookup fails, preserving
tag creation, hard reread, exact-SHA verification, duplicate refusal and explicit
cancellation safeguards. Its regression failed before the fix and the full
owning suite passed after it. Exact-head GLM5.3 approved549024aa; CI34899250878
and queue34903218130 passed. PR461 merged as
`f3d3144080c2129a500fa8f752c7c8f2c7b0c4d9`, verified on origin/main.

The reviewed controller successfully dispatched complete run34899253151 on
exact PR460 source3194. All75 Bash suites and18 PowerShell suites completed;
complete-section durations were1768,1638,2426,3118 and2199 seconds respectively
(section3's PowerShell work completed separately). Every section stayed within
the existing bound. Two suites failed, so this run is diagnostic, not acceptance:

- Section2's evidence mutation fixture compared a DOS-alias path to its
  canonical spelling and never injected the intended write. A real Windows
  alias reproduced the failure. The repaired test retains the original refusal,
  compares resolved paths, and additionally proves late bytes retained and no
  receipt sealed. Windows owner:152 passed,0 failed,4 skipped.
- Section4 correctly rejected invalid Kimi authentication but exceeded the
  unchanged ten-second expectation by preparing full evidence before the
  doctor. Moving the unchanged doctor before evidence preparation preserves
  all successful-admission gates. The original timing/ordering regression was
  reproduced; traced refusal changed from about9.9 to0.8 seconds. Windows
  owner:95 passed,0 failed (skip count unreported), including healthy full
  evidence/cleanup proof and refusal after injected packet-verification failure.

PR462 integrated current main without force-pushing, producing final head
`dfac0198e70f3522f1c489422557079aa1ed06a8` against basef3d31440. GLM5.3 APPROVE
was refreshed on that exact head. CI34905796159 and merge-group34909141150
passed, and PR462 merged as `e298568452879055c88c4178689ed4cb7c5d7353`.
The merged Git tree is `44dad99fcc6ecb0a7b03e79489748d7e00796693`, exactly
equal to the repaired full-run candidate; this Git object ID is distinct from
the review packet's SHA256 digest.

Repaired complete run34905839047 was dispatched by the normal controller on
dfac0198. All five Windows sections passed:15 Bash suites each,75 distinct
tracked suites with no omissions or duplicates, and all18 PowerShell suites
once in section3. Section Bash durations were2059,1665,1894,3040,2117 seconds,
all within105 minutes. The previously failing evidence suite passed155/0/1;
preflight passed95/0 (skips unreported). The whole
[run34905839047](https://github.com/popcre/ai-devops/actions/runs/34905839047)
is terminal SUCCESS, with no failed/cancelled or unfinished job. Linux passed
75 suites with0 failures. Hosted reviewer proof completed: Codex49/0 (skips
unreported), its helper7/0/0, and Grok234/0/0. The preferred30-minute timeout
is not counted as completed proof; the successful hosted fallback supplies it.

EDGE-DEV's clean canonical main was fast-forwarded to e2985684 after fresh
task/process checks and an idle physical-host runner check. No other task was
active in the checkout; persistent MCP launchers were untouched. Seven command
shims target canonical source, and eight installed source hashes equal the
reviewed candidate. The machine-tools doctor passed. Installed synthetic
invalid-auth checks passed5/0; an actual default installed DeepSeek preflight
passed full ordinary health and real isolated packet verification. No provider
request, configuration change or service restart was needed. Relative to the
original paid live-canary commit3098a89a, recovery paths are unchanged except
GLM's preservation-warning wording, so paid canaries were not replayed.

Private proof: `C:/Temp/397-complete-coverage-proof.json`,
`397-installed-source-proof.json`, `397-installed-machine-doctor.log`,
`397-installed-refusal.log`, and `397-installed-healthy.log`. The
[continuation record](../../../HANDOFF.d/2026-09-14T2133Z-edge-dev-codex-reviewer-acceptance-continuation.md)
retains exact reports, failed attempts, private-work boundaries and downstream
acceptance gates. #397's recovery slice is accepted. Its earlier automatic
closure at PR460 landing was corrected by reopening until this final gate
passed. Qwen's separate #393 incident and Grok's unproven remote-work fence
remain intact; the frozen #398 round remains open. No parent completion is claimed.
