# IMPLEMENTATION PLAN: ai-glm implementation-mode permission failures (2026-08-12)

## STATUS

| Step | Status | Last updated | Evidence |
|---|---|---:|---|
| 1. Make the failure diagnosable | ✅ done | 2026-08-12 | `bin/ai-glm` `permission_reason_id` / `permission_failure_detail`; new `failure_detail` field in the record and in `ai-glm show`; `tests/test-ai-glm.sh` section "permission failure is diagnosable (step 1)" proves 10 distinct branch ids and secret redaction |
| 2. Measure the real permission shapes OpenCode 1.18.12 sends | ✅ done | 2026-08-12 | Section 6, finding 6. Three paid probe runs against a throwaway fixture; measured table in section 6 |
| 3. Widen the implement-mode allowlist to the measured write actions | ⚠️ open, premise now disputed | 2026-08-12 | Section 6, finding 6: no write-class action asked in any measured run, so there is nothing measured to widen to. Re-scope before doing this |
| 4. Accept the measured non-`resources` permission shapes | ⚠️ open, premise now disputed | 2026-08-12 | Section 6, finding 6: no non-`resources` shape was observed. Finding 3's original hypothesis is already disproven |
| 5. Add regression tests for every classifier branch | ⬜ open | 2026-08-12 | Section 10 |
| 7. Separate transport failure from unsafe permission state | ✅ done | 2026-08-12 | `permission_http` retries a dropped local poll 3× (`AI_GLM_PERMISSION_HTTP_ATTEMPTS`); `classify_permissions` gives status `000` its own branch; new durable code + failure_kind `transport-failed`; docs constraint 30 + troubleshooting row; skill guidance; `tests/test-ai-glm.sh` section "transport failure is not a permission failure (step 7)" |
| 6. Re-run the two real failed jobs and close | ⬜ open | 2026-08-12 | Section 9, step 6 |

**Fresh-session start (updated 2026-08-12, second pass):** steps 1, 7, and 2 are
done. **Do NOT simply proceed to step 3.** Step 2's measurement (finding 6)
removed the evidence step 3 was built on: OpenCode 1.18.12 never asked the
wrapper for `edit`, `write`, `patch`, or `bash` in three live implement runs, so
there is no measured write-class shape to widen the allowlist to, and widening it
would weaken the sandbox for no observed benefit. Steps 3 and 4 need re-scoping
by a human decision before anyone writes code for them. The one genuinely
unexplained failure left is `popcrm-codebase-audit-remediation`
(`permission-unsupported-action`); step 1 now makes the next occurrence fully
diagnosable, which is the cheapest way to learn what actually asked. Step 6 can
run whenever Albert wants the two stale records re-tried.

**Superseded first-pass note:** steps 1 and 7 shipped on 2026-08-12; begin at step 2.
Step 1's `failure_detail` field is now the thing that tells you which branch
rejected a run, so use `ai-glm show <name>` and read `failure_detail.reason_id`
before touching any allowlist. Step 7 fixed a different defect (a dropped local
HTTP poll reported as a permission failure) and is independent of steps 2-4.
Step 6 stays last regardless.

**Note for step 2 onward:** the step-1 and step-7 work was done in the worktree
`C:\repos\ai-devops-worktrees\glm-permission-failures-a7e4a8` on branch
`claude/glm-permission-failures-a7e4a8`, not directly on `main`. Merge or
cherry-pick it to `main` before continuing. One unrelated pre-existing test was
also repaired: `sandbox is a clone, not a worktree` grepped for
`git clone --quiet --no-hardlinks`, which stopped matching when Windows
long-path support inserted `-c core.longpaths=true`. It now matches the clone
flags and additionally forbids `git worktree add`.

**Concurrency and file ownership.** This plan touches only `bin/ai-glm`,
`config/opencode/*`, `tests/test-ai-glm.sh`, `docs/glm-opencode.md`, and
`skills/shared/ask-glm/SKILL.md`. It shares no file with
`plan_context-engineering-consolidation.md`, which owns the global instruction
files, `AGENTS.md`, `docs/context-engineering.md`, the skills usage guides, and
the context-audit tooling. The two plans can therefore run at the same time in
separate sessions. Pull `main` immediately before committing either one.
`plan_ai-glm-permission-deadlock.md` is complete and shipped; treat it as the
historical record of the original fail-closed design and do not reopen it.

## 1. The ultimate goal

`ai-glm implement` must be able to finish an ordinary coding task on Windows
without the safety wrapper killing it for a permission shape that is in fact
safe, and without ever loosening the controls that keep GLM inside its
disposable clone.

Two things are true at once and both must survive this work:

- The wrapper is right to fail closed. It has no way to know that an unmeasured
  permission shape is harmless, and approving unknown shapes would defeat the
  entire sandbox design.
- Failing closed on a shape that GLM emits during normal file editing makes
  implementation mode unusable, and it burns a paid provider turn each time.

The fix is therefore to **measure** the real shapes, allow exactly those, and
keep failing closed on everything else. It is not to approve broadly.

If any step below conflicts with that, the goal wins: stop and flag it.

## 2. What this application is

`u2giants/ai-devops` is Albert Hazan's public toolkit for his multi-model AI
coding workflow. It is Bash, PowerShell, and Markdown. There is no hosted
service, no database, no container, and no CI. Branch policy is `main` only.

The component in scope is `bin/ai-glm`, a Bash wrapper around a locally hosted
OpenCode server that runs Z.ai GLM 5.2. It owns the server URL, credentials,
model pin, locking, read-only enforcement for review sessions, and the
permission gate that this plan is about.

- Wrapper: `bin/ai-glm`
- Agent definitions: `config/opencode/agent/glm-review.md` and
  `config/opencode/agent/glm-implement.md`
- Server config: `config/opencode/opencode.json`
- Pinned OpenCode version: `config/opencode/version` (1.18.12)
- Windows setup: `bin/setup-opencode-glm.ps1`
- Ubuntu setup: `bin/setup-opencode-glm.sh`
- Tests: `tests/test-ai-glm.sh`
- Skill that teaches its use: `skills/shared/ask-glm/SKILL.md`
- Job records: `~/.local/state/ai-devops/glm/sessions/<repo-id>/<caller>--<name>.json`
- Machine observed: `al8960ofc` (Windows 11, PowerShell 7 primary)

Albert is a business owner, not a programmer. A wrapper that fails with an
opaque code and no recoverable diagnostic costs him a paid run and a session.

## 3. What triggered this work

On 2026-08-12 a Claude session dispatched step 2 of
`plan_context-engineering-consolidation.md` to GLM as job
`context-ownership-map-step2`. It failed after about eight minutes.

Observed terminal record (`ai-glm show context-ownership-map-step2`):

- `status`: `failed`
- `failure`: `permission-invalid-response`
- `failure_summary`: "blocked an invalid or unsupported permission response on
  the first observable poll"
- `failure_kind`: `permission-failed`
- `outcome`: `permission-failed-partial`
- `changes_present`: `true`
- `artifact_state`: `durable`
- OpenCode session: `ses_009405983ffema7EaLxUljpFbw`
- Base SHA: `8783f1bbd2abc723ff972271248efc9ced83b3c8`

The incomplete patch was preserved correctly and shows GLM had already produced
real work before the block: `AGENTS.md` +1, `docs/context-engineering.md` +137,
`docs/skills-usage-guide.md` +17, across 3 files.

A second, different permission failure the same day, in another repository:

- Job `popcrm-codebase-audit-remediation` (caller `codex`, repo `popcrm-web`)
- `failure`: `permission-unsupported-action`
- `outcome`: `permission-failed-no-changes`

A third failure the same day was **not** a permission failure and is out of
scope here: job `automatic-gates-repo-neutral-compact` failed with
`turn-timeout` / `timed-out-no-changes`.

Several implementation jobs did complete successfully on 2026-08-12
(`issue-729-safe-launch-v3`, `issue-617-digest-pin-local`,
`catalog-verifier-net-acl-v2`, `pr823-comment-accuracy-fix`). So the failure is
**intermittent, not universal**. Any root-cause claim must explain why the same
wrapper succeeds on some implementation jobs and blocks others. A plan that
assumes implementation mode is uniformly broken is wrong.

## 4. Scope: in and out

### In scope

1. Make every permission rejection produce a durable, sanitized diagnostic in
   the job record, so the exact classifier branch is recoverable after the fact.
2. Measure, against the pinned OpenCode 1.18.12 binary, the actual permission
   payloads emitted for `edit`, `write`, `patch`, `bash`, and `todowrite` in
   implement mode, and for `read`, `list`, `glob`, `grep` in both modes.
3. Extend `classify_permissions` to accept exactly the measured implement-mode
   shapes, with the same inside-the-clone path proof already applied to reads.
4. Add regression fixtures for every rejection branch and every accepted shape.
5. Re-run the two real failed jobs and record the result.

### Not in this plan

- No change to review-mode read-only enforcement. Review sessions keep no write,
  edit, patch, or bash tool.
- No blanket approval, no `"*"` wildcard beyond the already-measured
  `todowrite` exception, and no "approve everything" escape hatch.
- No OpenCode version bump. The pin stays at 1.18.12 unless step 2 proves the
  shape drift is a fixed upstream bug, and then only as a separate decision.
- No change to the disposable-clone design, the remote removal, or the locking.
- No credential, auth-file, or 1Password change. This work needs no secret.
- No production, shared-cloud, Supabase, NAS, or database mutation.
- No change to Grok, Codex, Kimi, or DeepSeek wrappers. The Grok worktree bug
  reported separately on `al8960ofc` is unrelated and has its own prompt.
- No retry loop that re-sends paid provider turns to probe the failure.

## 5. Current state of the code

### The permission path, as written today

`bin/ai-glm:406` `classify_permissions` is the gate. It returns a TSV of
approvable permission entries, or writes a one-line reason to stderr and returns
1. Its rejection reasons are:

| Line | Reason text written to stderr |
|---:|---|
| 411 | `un-approvable OpenCode permission request` |
| 413 | `permission endpoint returned HTTP <status>` |
| 417 | `malformed permission response` |
| 419 | `unsupported permission response envelope` |
| 439 | `permission entry is missing an id` |
| 440 | `unknown permission action: <action>` |
| 441 | `permission entry is missing resources` |

`handle_permissions` maps those seven strings onto **four** durable codes. Only
three of the seven get a specific code: `unknown permission action:` becomes
`permission-unsupported-action`, the `todowrite` shape mismatch becomes
`permission-unsupported-shape`, and anything containing `outside` becomes
`permission-outside-directory`. **The remaining five reasons all collapse into
the single fallback `permission-invalid-response`.**

The full reason text and the sanitized body are passed to `die`, which prints
them to the caller's stderr. `record_implementation_permission_failure`
(`bin/ai-glm:452`) stores only the code and the generic summary. Nothing durable
records which of the five branches fired.

### The implement-mode allowlist

`bin/ai-glm:440` accepts exactly: `read`, `list`, `glob`, `grep`, `todowrite`.

`config/opencode/agent/glm-implement.md` grants the tools `write`, `edit`,
`patch`, `bash`, and `todowrite`, and pre-allows only `read`, `list`, `glob`,
and `grep` in its `permission:` block. `config/opencode/opencode.json` likewise
sets `read`, `list`, `glob`, `grep` to `allow` and `webfetch` to `deny`, and
says nothing about `edit`, `write`, `patch`, or `bash`.

So whenever OpenCode decides to **ask** about a write-class action, the wrapper
sees an action outside its allowlist and kills the job.

### Resource extraction

`bin/ai-glm:435-437` reads the requested paths from `.resources[]` only, and
`bin/ai-glm:441` fails the run if that array is absent or empty. There is a
single documented exception, `todowrite`, whose measured shape is
`resources:["*"]` with `save:["*"]`.

### Evidence that is gone

- `~/.local/state/ai-devops/glm/logs/` is empty.
- No OpenCode server log directory exists on this machine
  (`%LOCALAPPDATA%\Temp\opencode` is empty).
- The dispatching session's stderr, which held the only copy of the exact
  reason, is not recoverable.

That absence is itself finding 1.

### Git state

- Repo `C:\repos\ai-devops`, branch `main`, in sync with `origin/main`.
- Unrelated untracked paths that must remain untouched: `.ai/` and
  `docs/claude-remote-control-hardening-v2.md`.
- Nothing in this plan has been implemented.

## 6. Key findings and root cause

### Finding 1 (proven): the wrapper discards its own diagnosis

Five distinct rejection branches share one durable code. The specific reason and
the sanitized response body go only to the caller's stderr, which no future
session can read. For an unattended background job this guarantees that the one
piece of information needed to fix the bug is destroyed at the moment of
failure. This is why the exact cause of `context-ownership-map-step2` cannot be
stated today, and it is the highest-value fix in this plan.

### Finding 2 (proven by code, cause of the popcrm failure): implement mode has no write-class permission path

The implement agent is deliberately given `write`, `edit`, `patch`, and `bash`
tools, but neither the agent file nor `opencode.json` pre-allows them, and the
wrapper's allowlist does not contain them. Any write-class permission ask is
therefore fatal. `popcrm-codebase-audit-remediation` failed exactly this way
with `permission-unsupported-action` and no changes.

### Finding 3 (RESOLVED 2026-08-12 by recovered stderr): the step-2 failure was a transport failure, not a permission shape at all

**This finding originally hypothesized a missing-`resources` shape mismatch.
That hypothesis is wrong.** The dispatching Claude session's stderr was
recovered from its background-task output file before it was lost, and it names
the branch exactly:

```text
ai-glm: error: GLM permission failed: permission endpoint returned HTTP 000.
       status=000 mode=implement path=missing sanitized_response=
```

That is `bin/ai-glm:413`, the HTTP-status branch, and `000` is not a status the
OpenCode server can send. It is the value `permission_http` assigns at
`bin/ai-glm:360` when the `curl` call itself returns nonzero — connection
refused, connection reset, or the 20-second `-m 20` timeout expiring. The body
was empty and the path category was `missing`, both consistent with "no reply
was ever received". The permission payload was never seen, so no allowlist,
action, or key shape was involved.

`classify_permissions` then treats `000` like any other non-2xx status and fails
closed, killing an eight-minute job and reporting it to the user as a permission
problem. **A dropped local HTTP request is being classified as an unsafe
permission state.** Those are different failures with different correct
responses: an unsafe permission must stop the run, whereas a single dropped poll
against a loopback server that is still healthy should be retried a bounded
number of times before the run is destroyed.

Corroborating evidence: `ai-glm doctor` was run minutes after the failure and
passed every check, with the scheduled task `Running` and the health endpoint
answering. The service did not go down. This is consistent with a transient
loopback stall — note hard-won constraint 24 in `docs/glm-opencode.md`, which
already records that the permission endpoint can fail to answer while a
`glob`/`grep` permission is pending.

This finding no longer blocks on step 2. Its fix is step 7 below. Findings 1, 2,
4, and 5 are unchanged, and the popcrm failure
(`permission-unsupported-action`) is still a genuine allowlist gap.

### Finding 4 (proven): the failure is intermittent

Four implementation jobs completed normally on the same day on the same machine.
So OpenCode 1.18.12 does not ask for a write-class permission on every edit. The
trigger is conditional, and step 2 must find the condition rather than declaring
implementation mode broken.

### Finding 5 (proven): the safety design worked

In both failures the wrapper preserved the right things. The partial diff was
exported as `.incomplete.patch` with an INCOMPLETE report, the clone was cleaned,
the primary checkout was untouched, the job record stayed durable, and the exit
code was nonzero. Nothing about the fail-closed posture should be weakened. Only
its blindness should be fixed.

### Finding 6 (measured 2026-08-12, step 2): implement mode does not ask at all

Measured against the pinned OpenCode 1.18.12 binary and the live API on
2026-08-12, machine `al8960ofc`, through `ai-glm implement` only, using a
throwaway three-file git fixture. Three paid runs, tokens per run under 400.

| Action forced | Did OpenCode ask? | Evidence |
|---|---|---|
| `read` (inside the clone) | no | runs 1 and 2 completed |
| `list` (inside the clone) | no | runs 1 and 2 completed |
| `glob` (`src/*.md`) | no | runs 1 and 2 completed |
| `grep` (`MARKER_ALPHA`) | no | runs 1 and 2 completed |
| `edit` on an EXISTING file | no | runs 1 and 2; the exported patch really contains the edit |
| `write` of a NEW file | no | runs 1 and 2; `src/created.txt` is in the patch |
| `patch`/append to an existing file | no | runs 1 and 2 |
| `bash` (`git status --porcelain`) | no | runs 1 and 2; GLM reported the command's real output |
| `todowrite` | not triggered | the task was too small for GLM to open a todo list; the 2026-08-10 measurement stands |
| outside-directory `read` (`C:/Windows/win.ini`) | **no ask reached the wrapper** | run 3: GLM refused on its own, citing its agent-file constraints, and never called the tool |

**No permission request of any kind reached `classify_permissions` in any of the
three runs.** Reproduced twice for every row except the two marked otherwise.

Consequences, and they are large:

1. **Step 3's premise is not supported by measurement.** The plan assumed a
   write-class ask was killing jobs. In practice OpenCode 1.18.12 never asked for
   `edit`, `write`, `patch`, or `bash` in implement mode. Widening the allowlist
   would reduce sandbox guarantees while fixing nothing observed. Do not widen it
   on the strength of code reading alone; find a payload first.
2. **Step 4 has nothing to accept.** No non-`resources` shape was seen at all.
3. **Open decision 1 (`bash`) resolves itself for now.** The wrapper is never
   asked about `bash`, so there is nothing to approve. The remote-less clone
   remains the actual control, exactly as hard-won constraint 1 says.
4. **The `popcrm-codebase-audit-remediation` failure
   (`permission-unsupported-action`) is still unexplained.** Something did ask,
   with an action outside the allowlist, and this fixture did not reproduce it.
   Its record predates `failure_detail`, so the action is not recoverable. The
   honest next move is to wait for the next occurrence, which step 1 now makes
   fully diagnosable, rather than to guess at an allowlist.

### Finding 7 (2026-08-12): the intermittency in finding 4 was the transport bug

Finding 4 asked why four jobs succeeded and two failed. The answer is not a
conditional permission ask. A concurrent investigation compared the durable
records of the two `permission-invalid-response` failures and found they share
`failure_detected_at` to the second:

- `context-ownership-map-step2` (caller `claude`, repo `ai-devops` worktree)
- `orderlist-production-package-837` (caller `codex`, repo `shared-db`) - a
  **third** permission failure that no earlier handoff had noticed

Both were detected at 16:20:47 and finished at 16:21:10 on 2026-08-12, in
different repositories under different callers. Two independent jobs cannot hit a
genuine permission wall in the same second. One transient stall of the local
OpenCode server hit both, and both were mislabelled as permission problems. Both
had `changes_present: true` and real exported work; the orderlist patch is
ordinary migration-checker output with no sign of a blocked action.

That is exactly the defect step 7 fixed. Neither record carries `failure_detail`
because both predate it, so this rests on the timestamp match plus the shared
code. It is corroboration, not proof, and it is strong.

### Root cause

`classify_permissions` was written against a measured snapshot of read-class
permission traffic. Implement mode introduced write-class tools without
extending that measurement, and the failure reporting was built to be safe
(sanitized, no secrets) at the cost of being diagnosable. The result is a gate
that blocks legitimate work and then deletes the evidence needed to tell whether
the block was correct.

## 7. Approaches considered and rejected

1. **Add `bash`, `edit`, `write`, `patch` to the allowlist right now. Rejected
   as a first move.** Without step 1 there is no proof that an action mismatch
   caused the step-2 failure, and the popcrm failure shows the allowlist is only
   one of at least two problems. Widening blind would likely leave the real bug
   in place while reducing the sandbox's guarantees.
2. **Set `edit`, `write`, `patch`, `bash` to `allow` in `opencode.json` so
   OpenCode never asks. Rejected.** It moves the decision out of the wrapper,
   which is the only component that proves the path is inside the disposable
   clone. It would also silently apply to any future agent that reads that
   config.
3. **Approve any permission whose resources are all inside the clone,
   regardless of action. Rejected.** Path containment is not sufficient for
   `bash`: a command string is not a path, and an inside-the-clone shell can
   still reach the network or the parent filesystem.
4. **Retry the failed job a few times and see what happens. Rejected.** Every
   retry is a paid provider turn, and the wrapper destroys the diagnostic on
   each one, so retries produce cost without information.
5. **Upgrade or downgrade the pinned OpenCode version. Rejected as a first
   move.** The pin exists so that measured shapes stay valid. A version change
   invalidates every measurement in the wrapper's comments and is a separate,
   larger decision.
6. **Log the raw permission body to disk for debugging. Rejected.** Raw bodies
   can carry file contents and prompt text. The existing
   `sanitize_permission_body` output is the only thing that may be persisted.
7. **Give up on implement mode and route all writing work to Codex. Rejected.**
   The disposable-clone design is sound and already produced correct patches
   four times on the day of the failure.

## 8. Design decisions

### Locked decisions

1. **Fail closed stays.** An unmeasured shape must still stop the run.
2. **Diagnose before widening.** No allowlist change ships before step 1.
3. **Measure, do not guess.** Every new accepted shape must be recorded with the
   date, the OpenCode version, and the observed payload, in a code comment next
   to the check, matching the existing `todowrite` precedent at
   `bin/ai-glm:426-433`.
4. **Sanitized only.** Durable records may hold the classifier reason, the
   action, the path category, and the sanitized body. Never the raw body, file
   contents, prompt text, or any credential.
5. **Review mode is untouched.** No write, edit, patch, or bash tool, ever.
6. **Path containment is still required** for every action that carries paths.
7. **`bash` is decided separately from the file-writing actions.** File writes
   inside a proven-contained clone are a different risk from arbitrary shell.
8. **No new sync system, no new wrapper, no new CLI.** The fix belongs in
   `bin/ai-glm` and its config and tests.

### Open decisions for the implementing session

1. Whether `bash` should be approved at all, or whether the implement agent
   should instead pre-allow `bash` in its own agent file so the wrapper never
   sees the ask. Decide from the step-2 measurement of what a `bash` permission
   payload actually contains. If a `bash` payload carries no provable path, the
   wrapper cannot contain it and must not approve it.
2. Whether the durable diagnostic is a new field (`failure_detail`) or an
   extension of `failure_summary`. Prefer a new field so existing consumers and
   the `ai-glm show` output shape do not change meaning.
3. Whether accepted non-`resources` keys are added as a measured alias list or a
   per-action extractor. Prefer whichever keeps the "unknown means stop" default
   most obvious to a reader.

## 9. The implementation plan

### Step 1. Make the failure diagnosable

**Targets:** `bin/ai-glm` (`classify_permissions`,
`record_implementation_permission_failure`, `fail_permission`,
`handle_permissions`), `tests/test-ai-glm.sh`.

Give each of the seven rejection reasons its own durable code, or keep the four
codes and add a `failure_detail` field carrying the exact reason string plus the
sanitized body and the offending action. Persist it in the job record so
`ai-glm show <name>` reveals which branch fired. Keep the sanitizer in the path;
nothing unsanitized may be written.

**Dependencies:** none.

**Verification gate:** a fixture that feeds each of the seven reasons through
the failure path produces seven distinguishable durable records; no fixture
writes an unsanitized body; `tests/test-ai-glm.sh` passes; a `.env`-style
secret in a fixture body never appears in the record.

### Step 2. Measure the real permission shapes

**Targets:** a throwaway fixture repository; the pinned OpenCode 1.18.12 binary;
notes recorded into `docs/` and into code comments.

Run a minimal implement job against a harmless fixture that forces each tool in
turn: read a file, list a directory, glob, grep, edit a file, create a file,
apply a patch, run one shell command, and update the todo list. Capture the
permission payload for each. Record for each action: whether OpenCode asks at
all, the exact JSON keys, whether paths appear and under which key, and whether
the ask depends on the file already existing.

This step must also answer finding 4: why four jobs succeeded and two did not.

**Dependencies:** step 1, so a block during measurement is self-describing.

**Verification gate:** a written table of action, asks-or-not, payload keys, and
path key, with the OpenCode version and date; every entry reproducible twice.

### Step 3. Widen the implement allowlist to the measured write actions

**Targets:** `bin/ai-glm:440`, `config/opencode/agent/glm-implement.md`,
`tests/test-ai-glm.sh`.

Accept exactly the file-writing actions measured in step 2, each with a comment
naming the version and date, and each still required to prove every path is
inside the clone. Decide `bash` per open decision 1 and write down the reason
either way. Review mode's allowlist must not change.

**Dependencies:** steps 1-2.

**Verification gate:** implement-mode fixtures approve the measured write
actions and still reject an unmeasured action; review-mode fixtures reject every
write action; an inside-path fixture approves and an outside-path fixture fails
with `permission-outside-directory`.

### Step 4. Accept the measured non-`resources` shapes

**Targets:** `bin/ai-glm:435-441`, `tests/test-ai-glm.sh`.

Extract paths from the measured keys per action instead of `.resources` alone.
An action whose payload has no recognized path key must still fail closed with a
clear reason, not be approved.

**Dependencies:** step 2.

**Verification gate:** fixtures for each measured key shape approve; a payload
with an unrecognized key fails with the specific reason from step 1; the
existing `todowrite` wildcard behavior is unchanged.

### Step 5. Regression tests for every branch

**Targets:** `tests/test-ai-glm.sh`, and `docs/development.md` if a new test
file is added.

Cover: each of the seven rejection reasons, each approved action shape, review
versus implement divergence, inside/outside/invalid path categories, the
`todowrite` exception, secret redaction in the durable record, and the
"approval did not clear after two polls" path.

**Dependencies:** steps 1-4.

**Verification gate:** every test fails when its guard is removed from the
source and passes against the real source, with a plain-English reason.

### Step 7. Separate transport failure from unsafe permission state

**Targets:** `bin/ai-glm` (`permission_http`, `classify_permissions`, and the
`handle_permissions` code mapping), `tests/test-ai-glm.sh`,
`docs/glm-opencode.md` troubleshooting table, `skills/shared/ask-glm/SKILL.md`.

This step exists because of finding 3. It is **independent of steps 2-4**: it
touches the transport layer, not the permission allowlist or the path
extractors, so a second session can work it at the same time as the measurement
work. Take step 1 first if both are being done by the same session, because step
1's durable detail field is what proves this branch fired next time.

Required behavior:

1. **Distinguish "no reply" from "a reply we refuse."** `permission_http`
   already sets `000` on a nonzero `curl` exit; carry that fact through as an
   explicit transport-failure state rather than letting it fall into the generic
   non-2xx branch of `classify_permissions`.
2. **Retry a dropped poll, bounded and free.** A transport failure costs no
   provider tokens: nothing is re-sent to Z.ai, because the poll is a local
   loopback GET against our own OpenCode server. Retry a small fixed number of
   times (three is the same bound the Windows service wrapper already uses)
   with a short backoff, then fail. This does **not** violate rejected approach
   4 in section 7, which forbids retrying whole paid provider *turns*.
3. **Fail with the truth if the retries are exhausted.** The message must say
   the local permission endpoint did not answer, name the retry count and the
   timeout, and tell the caller to check `ai-glm doctor` and `server status`.
   It must not say "GLM permission failed", which sends the reader hunting for a
   permission problem that never existed.
4. **Give it its own durable code**, for example `transport-failed`, distinct
   from `permission-invalid-response`, so the two never merge again in the job
   record.
5. **Do not weaken any permission rule.** A real non-2xx status from a server
   that did answer keeps failing closed exactly as it does today. Only the
   never-answered case changes.

**Dependencies:** step 1 preferred but not blocking. Independent of steps 2-4.

**Verification gate:** an offline fixture that forces `curl` to fail proves the
retry runs the configured number of times and then produces the transport code
and message, not a permission code; a fixture returning a genuine HTTP 500 still
fails closed as a permission error with no retry; a fixture that fails twice and
succeeds on the third poll completes the turn normally; `tests/test-ai-glm.sh`
passes; the troubleshooting table and skill guidance name the new message.

### Step 6. Re-run the two real failed jobs and close

**Targets:** the job records; this plan's STATUS table; the implementing
session's own `HANDOFF.d/` file.

Delete the stale records with `ai-glm delete`, re-dispatch
`context-ownership-map-step2` and `popcrm-codebase-audit-remediation` as fresh
implementation jobs, and record the outcome, the patch, and the reported token
usage. If step 2 of the context-engineering plan has already been completed by
hand by then, substitute an equivalent real task rather than inventing a toy one.

**Dependencies:** steps 1-5, all named local suites passing.

**Verification gate:** both jobs reach a terminal non-failed outcome with a real
patch, the primary checkouts are unchanged, the clones are cleaned, and
`ai-glm doctor` passes with no warning.

## 10. Tests required

1. **Branch-distinguishability test:** each of the seven classifier rejection
   reasons yields a distinguishable durable record.
2. **Redaction test:** a permission body containing secret-like text never
   reaches the job record, the report, or the patch.
3. **Allowlist divergence test:** implement mode accepts the measured write
   actions; review mode rejects all of them.
4. **Path containment test:** inside approves, outside and invalid fail with
   `permission-outside-directory`.
5. **Unknown-shape test:** an unmeasured action and an unmeasured path key both
   still fail closed.
6. **`todowrite` exception test:** the exact measured `resources:["*"]` plus
   `save:["*"]` shape approves and any other `todowrite` shape fails.
7. **Approval-ineffective test:** an id still pending after two follow-up polls
   fails with `permission-approval-ineffective`.
8. **Artifact preservation test:** a permission failure after real edits still
   exports `.incomplete.patch` and an INCOMPLETE report, and leaves the primary
   checkout unchanged.
9. **Idempotence test:** re-running the same named job after a terminal failure
   is refused until the record is deleted.
10. **Existing suites:** the full Bash and PowerShell suites named in
    `docs/development.md`, with `tests/test-ai-glm.sh` explicitly included.

## 11. Constraints, standing rules, and gotchas

- Work on `main` in `C:\repos\ai-devops`. Preserve the unrelated untracked `.ai/`
  and `docs/claude-remote-control-hardening-v2.md`.
- Before the first commit, `git var GIT_COMMITTER_IDENT` must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Never call `opencode`, `opencode run`, `opencode serve`, or the server's HTTP
  API directly. All work goes through `bin/ai-glm`, including measurement.
- Never read or print `~/.grok/auth.json`, the OpenCode server password, or any
  1Password value. This plan needs no secret.
- Do not hand-edit installed copies under `~/.config/opencode` or the Codex and
  Claude configs. Change the canonical files in this repo and reinstall through
  `bin/setup-opencode-glm.ps1` or `.sh`.
- OpenCode 1.18.12 does not enforce bash allow/deny rules. The remote-less clone
  is the actual control. Do not add a rule and treat it as a boundary.
- Measurement runs cost real provider tokens. Use the smallest fixture that
  forces the tool, and never loop retries.
- Do not delete a failed job's clone or patch while it may hold unique work.
- Serialize 1Password operations if any unexpectedly become necessary.
- GPT-5.6 reasoning stays explicitly `low` or `medium` if Codex is used here.
- This repo has no GitHub Actions CI. "Green" means the named local suites.

## 12. Access and environment

- Repository: `C:\repos\ai-devops`, `main`,
  `https://github.com/u2giants/ai-devops`.
- Machine: `al8960ofc`. Facts in `templates/system/machine-atlas.md`.
- `ai-glm doctor` passed all required checks on 2026-08-12 after the empty
  scratch-clone directories under
  `~/.local/state/ai-devops/glm/wt` were swept.
- OpenCode server runs behind Windows Scheduled Task `AiDevOps-OpenCodeGlm`;
  control it only with `ai-glm server start|stop|restart|status`.
- Job records: `~/.local/state/ai-devops/glm/sessions/`.
- Delegate artifacts belong under the untracked `.ai/reviews/`.
- There is no server to start and nothing to deploy for this toolkit.

## 13. Definition of done, rollback, risks, open questions

### Definition of done

- [ ] Every permission rejection is recoverable from the durable job record.
- [ ] The real payload shapes for OpenCode 1.18.12 are measured and written down.
- [ ] Implement mode approves exactly the measured write actions, no more.
- [ ] Unmeasured actions and unmeasured path keys still fail closed.
- [ ] Review mode is provably still read-only.
- [ ] Secrets never reach a record, report, or patch.
- [ ] Both real failed jobs re-run to a terminal non-failed outcome.
- [ ] All named local Bash and PowerShell suites pass.
- [ ] Focused commits are pushed to `main`; local and `origin/main` match.
- [ ] The plan STATUS table and the implementing session's handoff are current.

### Rollback

Every change is confined to `bin/ai-glm`, `config/opencode/`, and `tests/`.
Roll back by reverting the specific commit and re-running
`bin/setup-opencode-glm.ps1`, then `ai-glm doctor`. Do not roll back by deleting
job records or clones. If a widened allowlist ever approves something
unexpected, revert step 3 first: it is the only step that reduces refusals.

### Risks

1. Widening the allowlist is the one change that can weaken the sandbox. It must
   stay last, smallest, and measured.
2. A measurement taken once may not cover a conditional ask, which is exactly
   what finding 4 warns about. Measure twice and vary the file state.
3. Persisting a diagnostic risks persisting secret text if the sanitizer is
   bypassed. Route every write through the existing sanitizer.
4. An OpenCode update would invalidate every measured shape. The pin protects
   this; do not change it casually.
5. Concurrent sessions use `ai-glm` constantly. Do not restart the server or
   delete records that belong to another session's running job.

### Open questions

1. Does OpenCode 1.18.12 ask for `edit` only on pre-existing files, only on new
   files, or on a size or count threshold? This is the likeliest explanation for
   the intermittency in finding 4.
2. Can a `bash` permission payload be contained by path at all? If not, the
   correct answer is to pre-allow it in the agent file and rely on the
   remote-less clone, or to refuse it and tell the agent to avoid the shell.
3. Should review mode also gain the richer diagnostic? Probably yes, since it
   shares `classify_permissions`, but it has not failed in the field.

## Mandatory plan self-audit

### 1. Could a brand-new session execute this without asking Albert anything?

Yes. Sections 2 and 5 name every file, line, config, record path, and command.
Section 3 gives the exact observed failures with their job names, codes, and
session ids. Section 9 gives ordered steps with dependencies and gates.

### 2. Does it preserve background, nuance, and rejected work?

Yes. Section 6 separates what is proven from what is hypothesis, and finding 4
explicitly forbids the tempting "implement mode is broken" conclusion. Section 7
records seven rejected approaches with reasons, including the two that look
fastest.

### 3. Is the goal clear enough to guide a judgment call?

Yes. Section 1 states that both fail-closed safety and usable implement mode
must survive, and that measurement is the only permitted way to widen the gate.
Section 8 locks the rules that a shortcut would break.

Self-audit passed on 2026-08-12.
