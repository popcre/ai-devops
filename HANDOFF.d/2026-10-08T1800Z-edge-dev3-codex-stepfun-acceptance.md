---
issue: 1336
status: BLOCKED
owner: codex/stepfun-final-completion-20261008
---

# StepFun installed acceptance handoff

Written October 8, 2026, 2:00 PM EDT by Codex chat
01a116c7-2bc6-7172-ac72-edee2c3002a6 on edge-dev3.

## 0. Business decisions only the owner can make

None. Sweep of sections 1–9 and the agent blocks found no outstanding business
decision. Albert's exact chat instruction **“don't redact. close that issue”**
remains binding: credential incident CLOSED_BY_OWNER_DIRECTION. Do not rotate,
redact, revoke NAS sessions, generate replacement credentials, or restart the
incident rollout. Ordinary use of existing credentials for installation is allowed.

## 1. What this application is

`popcre/ai-devops` is the public recovery toolkit for Albert's AI clients and
reviewers. Its deployment is installation on Linux edge-dev3 and Windows edge-dev;
there is no application server to deploy. StepFun provides isolated model reviews.
The existing work card is https://github.com/popcre/ai-devops/issues/1336.
No shared-db repository, Supabase database, structural claim, or production database
was touched. Subagents were used for toolkit installation and tests only.

## 2. What we set out to do and why

Finish StepFun shipment, prove complete installed behavior on both machines, and
close the credential incident. The incident is already closed by owner direction:
https://github.com/popcre/ai-devops/issues/1336#issuecomment-6041783343.
Earlier checked live-proof boxes and launcher receipts overstated complete Windows
acceptance. Keep remaining proof on #1336; do not create a leftover-proof issue.
Wrap-up freezes new scope, but these existing deliverables remain authorized.

## 3. Current state

At 2:00 PM EDT, correction PR https://github.com/popcre/ai-devops/pull/1520 was
OPEN, CLEAN, all required checks successful, already queued to merge.
Head `ce9ee4a71f960cdbcfb8cd8de64030e045cac3dc`; independent Muse final APPROVE.
Grok Windows CI passed at 1:49:50 PM EDT and verification-closure at 1:51:13 PM EDT.
No running local waiter, paid reviewer, installer, or subagent remains.
Queue landing, corrected full installations, fresh installed acceptance, and issue
closure remain unfinished. GitHub state is moving: refresh before acting.

Correction worktree:
`/home/ahazan/repos/.worktrees/ai-devops-stepfun-store-contract-closure-20261008`,
branch `codex/stepfun-store-contract-closure-20261008`, clean, committed and pushed.
Base `230235788296b9a3f6f2fa6bd7f940195a165304`.
Commits `01a4a4b2979c67876485e3485e3a4b591bda5329` and the PR head above.
Six owned files: `tools/lib/review-doors/stepfun.sh`, `tests/test-ai-stepfun.sh`,
`bin/ai-install-skills`, `bin/install-ai-devops-windows.ps1`, and both skill-installer
fixture suites. Fixes enforce protected-store credential selection and reconcile
stale nonempty skill markers when actual skill content is already identical.

Validation: StepFun 109 pass/0 fail/0 skip; shared review engine 187 pass/0 fail/0
skip; Bash skill suite all 13 matrices pass; actual Windows native installer fixture
PASS at approximately 1:09 PM EDT. Source review report:
`.ai/reviews/muse-final-check-20261008T165500-1902288-6437.md` in correction
worktree, SHA256 `4359a5f5b1231ed071053063a28c6a007dfb972b7ee01536e53dca94f1441e64`.
Review source digest `b7a44d17b9e753b93d197fa4a2395c56f42380e3bb3774adb88df8643f487ca3`.
Report finished 1:01:03 PM EDT; implementer Codex, reviewer Muse Spark 1.3.
Nested reviewer limitations were reproduced at base; actual host tests passed.

Both canonical checkouts actually installed approved merged baseline
`e1723db85c9cc20dc3bed310d66b0463a0552052` from PR #1515.
Linux canonical `/home/ahazan/repos/ai-devops`; Windows `C:\repos\ai-devops`.
They must stay landing-only. Baseline source digest
`2ef4fd4a0e761678be61b878c92a753c67cbc17146fa93e9ced4d2b6cfb29187`.

Linux full install completed 12:25:50 PM EDT: all 30 stages, 20 required stages,
94 managed routes and seven components passed at e172. Protected receipt:
`/home/ahazan/.local/state/ai-devops/proofs/stepfun-linux-e172-full-install-receipt-proof.json`.
Manifest SHA256 `87b2503f5942770d85748437b86e010fed23aee9293df7cfbbff5fee6451f66c`;
stage-report SHA256 `f711d4246f1c3c1f2745cbe6c503ebf60822329190a96da3531d93d790cd2097`;
completion SHA256 `537223a1350ab9c2ce300cf1e75281ef81864644aee175e812fbd72325bd8ac2`.
Installed live doctor passed. Genuine installed formal review returned REVISE,
identifying the credential-selection defect now fixed in #1520; protocol success
does not mean source acceptance. Report:
`/home/ahazan/.local/state/ai-devops/stepfun/reports/20261008T162718Z-e1723db85c9c-687067.md`.

Windows normal public full installer completed 12:47:07 PM EDT, native task result
0, no skipped/partial/test installation flags. Installed StepFun live doctor passed.
Protected evidence roots:
Windows `C:\Users\ahazan\.local\state\ai-devops\stepfun-install-proof\2026-10-08-full-preparation`;
Linux `/home/ahazan/.local/state/ai-devops/stepfun-install-proof/2026-10-08-full-preparation`.
Native XML/action metadata and transcript are there. Task under `\ai-devops\`:
`stepfun-public-full-install-0af6469e-c1f1-4224-aee5-0f3e63d2216d`, Ready, retained
for exact final audit then exact-owned-task cleanup. It ran the public installer
directly as the existing interactive desktop user, limited privilege, 45-minute limit.
Windows installation has no Linux-style completion JSON; don't invent one.

Original Windows opaque preimages: 641 files including 547 skill files, launchers,
settings, Git configuration, three existing reviewer stores, four scheduled tasks,
and persistent user PATH. Final read-only checker covers 36 Bash/cmd pairs,
176 skills, four globals, four existing tasks, PATH, three store hashes/ACLs,
settings and Git configuration. Earlier output had 82 false failures; corrected
checker remains unrerun and two genuine stale MiMo markers will fail at e172.
PR #1520 repairs those markers through the ordinary full public installer.

Windows Gemini preserving recovery retained all 7,531 files/982,189,026 bytes and
original junction/target. Existing cached account was reused. Full installer Gemini
qualification healthy at 12:46 PM EDT; Qwen supported retry healthy around
12:49 PM EDT after identity became available. Gemini local record
`20261008T121438Z-edge-dev-gemini-2932789` partially resolved at 1:10:22 PM EDT
with actual repair/qualification evidence; original null source/lifecycle joins
remain null. No current Windows Qwen incident record found; historical Oct 5 record
is unrelated. Linux Qwen capacity records remain separate and unresolved.

### Agent: linux_completion

- Asked: complete Linux full installed proof and prepare final verifier.
- Did: receipt/source joins, reusable verifier and historical local-record audit;
  Root performed privileged full installation and adjudicated actual REVISE.
- Found: installed source defect; no StepFun local incident record among 55 older
  Gemini/Qwen records. No historical records should be falsely resolved.
- Branch/worktree: Linux e172 review/candidate worktrees below; retained evidence.
- State: completed/idle; no promised background work.
- Deliberately did not: rotate credentials or declare old-source REVISE acceptance.

### Agent: windows_completion

- Asked: prepare and verify public Windows full install and run isolated fixtures.
- Did: preimages, native public task preparation, read-only checker, and final ce9
  native fixture PASS. Root launched actual full installer and qualification retry.
- Found: stale identical-content markers; original local globals are preserved by
  normal installer defaults; unmanaged Claude extensions are permitted.
- Worktree: isolated Windows fixture Temp UUID
  `7630bcad-6625-467e-b166-4cfed71037ea`, retained, resumable evidence.
- State: completed/idle, verified PASS approximately 1:09 PM EDT.
- Deliberately did not: execute rejected private transport or change live runtime
  during fixture test, fabricate missing incident joins, or adopt local globals.

Earlier narrow_installer, narrow_windows and stepfun_install_plan preparation is
superseded by normal full-install work above. They are not active owners. Cancelled
MCP launcher PR #1411 remains CLOSED without merge; its unique dirty worktree
`/home/ahazan/repos/.worktrees/ai-devops-mcp-launcher-narrow-install` is deliberately
preserved, outside authorized StepFun scope. Do not resume its five-host rollout.

## 4. Attempts that failed and why

1. Private Windows capture/worker/controller prototypes were independently rejected
   before installation. Unlocked candidate paths, unverifiable evidence producers,
   and synthetic fixture deployment prohibition prevented valid approval. Preserve
   private evidence under the full-preparation root, including attachment-only-e172
   and transport UUID ce726d67-0959-4e9a-a9ac-8d87be25c201. Never execute or repair
   these abandoned transports. Native task running the public installer is valid.
2. Raw Linux LF hashes falsely rejected legitimate Windows CRLF checkout bytes.
   Bind actual Git objects/filtered source, not cross-platform raw byte expectations.
3. Broad Windows first checker misclassified route capitalization, unmanaged extra
   files and preserved local globals. Corrected semantic checks keep managed-source
   and marker hashes strict. Two stale markers are real, not exceptions to waive.
4. Linux full install initially lacked sudo authentication; existing protected vault
   credential and PTY-based normal sudo authentication recovered it. Another attempt
   lacked actual user DBus context; validated `/run/user/1000/bus` recovered required
   GLM OpenCode service. No stage was removed or bypassed.
5. Qwen first qualification failed before canary because exact runtime identity was
   unavailable; supported retry after normal install completed identity succeeded.
   This was not retrying a known quota-only failure.
6. Three bounded PR waits expired while Grok CI ran. It ultimately passed; do not
   cancel/skip/retry a healthy check merely because a wait expired.

## 5. Findings

Protected-store-only is the real StepFun contract: ambient provider-key variables
must not override the installed store. Marker reconciliation must run even when
actual skill files are identical. Full installer success, launcher catalog success,
doctor protocol success and genuine model acceptance are distinct outcomes.
The earlier live review's REVISE cannot be relabelled APPROVE.
Approved merged installation targets may be ancestors behind moving main; do not
chase unrelated changes and restart approvals needlessly. Source-bound reviews and
normal one-use installation authority must nevertheless match the actual target.
Normal Windows globals preserve local differences unless explicitly adopted;
adoption is outside this scope. Phase 4 cache sessions remain skip-unsafe.
Measured cache 93–97% is evidence, not a guaranteed savings promise.

## 6. Exact next steps with success gates

1. Read this handoff, repository AGENTS and deployment procedure; refresh #1520
   through `bin/ai-gh` and use bounded `bin/ai-pr-wait 1520 --timeout-minutes 15`.
   It is already queued; no admin bypass. Gate: MERGED and actual merge SHA present
   on fetched origin/main. If queue remains blocked, keep #1336 open and named.
2. Freeze that merged correction SHA as the installation target. Prepare clean
   host-local candidates from current upstream for Linux and Windows. Declare the
   correct task classes. Obtain independent exact-target final source review on each
   host (Linux Grok, Windows Muse), using existing normal reviewer lifecycle and
   implementer Codex. Gate: actual reports/lifecycle/digest bind target; APPROVE.
3. Prove both canonical installed baselines remain e172, preserve fresh preimages
   and check local test/CI collision. Issue NORMAL one-use installation authority via
   `ai-task-gates authorize-install` using actual baseline launcher and original
   approved report. No stale/first/legacy/partial flags now: e172 receipts are valid.
   Gate: authority joins actual checkout, launcher, target and source review.
4. Linux: ordinary full public updater with existing authenticated sudo and valid
   real user DBus context. Existing fixed e172 helper is protected reference only:
   `proofs/stepfun-linux-e172-authenticated-install.py` under Linux state root.
   Prepare a new exact-target protected helper/output, do not overwrite old proofs.
   Vault values must flow only through op_run environment and pipes, not output.
   Gate: full installer exit 0, all required stages pass, all components target.
5. Windows: archive e172 `native-public-installer-action.json` to unique original
   name before new metadata. Register a new exact-owned native task running approved
   public `bin/install-ai-devops-windows.ps1 -RepoPath C:\repos\ai-devops
   -ExpectedHead TARGET` directly with defaults; preserve original interactive-user
   limited token/action semantics. Start with Task Scheduler, retain native XML,
   action and protected transcript. Gate: terminal result 0, full installer stages
   actually succeed; actual one-use authority consumed normally.
6. Linux verifier `proofs/stepfun-linux-receipt-verifier.py TARGET OUTPUT` is
   read-only, tested e172 at 1:01:17 PM EDT; output path must stay under private
   proofs. Windows `windows-post-install-readonly.ps1 -BaselineDirectory BASELINE
   -OutputFile NEW_OUTPUT -TargetHead TARGET` under protected preparation root;
   script SHA256 `276359137af679f26a3ae6deb69da70cb1ab428f021a2bdf31935f2681971888`.
   Gate: all source/receipt joins, strict skill markers, opaque original stores,
   settings, preserved globals and tasks pass. Do not invent evidence timestamps.
7. Run fresh installed StepFun `doctor --live` and genuine installed formal review
   on each host, serialized provider access. Bind actual target/report/lifecycle,
   preserve authentic verdict. Gate: real endpoint/protocol and corrected behavior
   accepted; any REVISE remains open. Validate Gemini/Qwen healthy qualification
   without falsely resolving unrelated host records.
8. Update this plan STATUS with final target, immutable receipts and live outcomes;
   ship prose-only completion through normal PR/queue, attach every created PR.
   Docs-only changes do not require reinstall. On #1336 check live-proof only after
   both hosts pass, post signed evidence and close. Gate: merged correction,
   installed proof, genuine live acceptance and issue closure all independently true.
9. Audit exact owned terminal native task, archive metadata, remove only that task.
   Cleanup eligible owned worktrees only after unique ignored review evidence is
   backed up and merge/ownership proven. Gate: no lost source or private evidence.
   Retire this handoff only after all obligations are complete and successor audit.

## 7. Constraints and workspace decisions

All GitHub operations through ai-gh; bounded event-aware waits with explicit
deadlines, no duplicate polling or platform bypass. AI reviewer gates technical
actions; no human technical approval request. Every GitHub post signed with this
chat ID and edge-dev3. Keep main protected and canonical checkouts landing-only.
No new scope during wrap-up, no memory edits, no raw private artifacts committed.
Credential directive above supersedes generic rotation/redaction procedures.

Retain unmerged correction worktree/branch and ignored review evidence. Retain
Linux e172 candidates:
`/home/ahazan/repos/.worktrees/ai-devops-stepfun-linux-review-e172` and
`/home/ahazan/repos/.worktrees/ai-devops-stepfun-linux-receipt-reconcile-e172`.
Retain old docs worktree
`/home/ahazan/repos/.worktrees/ai-devops-stepfun-installed-proof-20261008` (PR #1508
merged as ec3dd67a1d5eaa8b7027cbbfaa6458c3a79ac99f).
This handoff/plan branch is
`/home/ahazan/repos/.worktrees/ai-devops-stepfun-final-completion-20261008`;
origin/main fetched at approximately 2:01 PM EDT was
`8602fca1` (full SHA available from Git; changing fact, not installation target).
No cleanup deletion performed: evidence and continuing proof work require retention.
Other sessions' worktrees, including shared cwd37e5, are untouched. No orphaned
half-merge or mystery newly untracked file is intentionally left in owned source.

## 8. Access and environment

Linux Bash, Git, installed public wrappers; Windows SSH alias `edge-dev` and native
PowerShell 7. Existing SSH helper is protected scratch
`/tmp/codex-windows-root-operation-c76p1w8a/remote.py`; don't depend on temp survival.
It accepts a PS script path, sends UTF16LE EncodedCommand over existing SSH, and
captures protected output; no credential values may be put in its script.
Recreate equivalent ordinary transport if scratch gone, never private installer.

Existing credentials live in 1Password vault `vibe_coding`; existing edge-dev3
sudo entry is titled edge-dev3 ahazan sudo password. Load secrets-to-1password
before access; use metadata-only lookup then serialized op_run environment/pipe.
No password value, transcript, raw store or private report belongs in public Git.
Existing StepFun protected store is used by installed wrapper, never ambient
override. Session sweep: no new credential plaintext appeared during resumed work;
existing incident intentionally closed with no further credential action.

Protected Linux proofs root `/home/ahazan/.local/state/ai-devops/proofs` contains
focused test outputs, install receipts, actual doctor/formal outputs and readonly
verifier. Windows preparation root in section 3 holds all native task evidence,
preimages, repaired checker, qualification retry and local-record resolution proofs.
The evidence files are retained privately; this public handoff contains safe names
and hashes only, never their raw contents.

## 9. Risks, unresolved state, and self-audit

Merge queue is external and its current position is not established by CLEAN.
Corrected full installations and fresh formal acceptance are not yet started;
e172 proof must not be claimed for the new target. Old Linux credential-store hash
baseline was not available: do not invent one or introduce a new closure gate.
Windows some unmanaged historical extras lack original preimages; preserve them,
do not claim nonexistent byte proof. Earlier incident join fields remain null.
No new fixes or unrelated business decisions discovered during wrap-up.

Self-audit completed against the actual text:

- Newcomer without questions: YES; sections 1–3 define goal/state, 6–8 execution,
  access, constraints and explicit success gates.
- As effectively as this session: YES; exact source/receipt/report bindings,
  private evidence locations, host distinctions and retained state in 3–8.
- Failed attempts present: YES; section 4 records all material abandoned paths.
- Concrete steps with verification: YES; every section 6 step ends in a gate.
- Identifiers explained/referenced: YES; machine roles, source SHAs, PRs, report
  paths, authority and task semantics appear in 1–8.
- Section-0 sweep: YES; line-by-line sections 1–9 and agent blocks contain no
  owner-only unanswered judgment. Existing owner directive appears in section 0.

Final synthesis:
1. Is this comprehensive for a brand-new developer without context? YES: 1–9.
2. Could they continue as well as this session with its knowledge? YES: 3–8.
3. Are relevant goals, state, failures, constraints, steps and evidence present?
   YES: 2–9, including authentic REVISE and strict marker acceptance.
4. Does section 0 show every needed business decision and no technical approval?
   YES: actual line-by-line sweep found none; binding no-redaction instruction is
   explicit, reviewer approvals remain section 6 rather than owner questions.

Successor prompt: In popcre/ai-devops, read this handoff and finish existing issue
#1336. Refresh queued correction #1520, obtain its actual merged target, perform
normal reviewed full Linux and Windows installations and prove installed live
acceptance before closing. Preserve the closed credential incident and all private
evidence; do not rotate or redact. Follow section 6, keep every gap on #1336.
