---
issue: 2022
status: OPEN
owner: codex/entire-trial-control-handoff-20261031
---

# Entire controls testing and merging; GitHub retains official code

## 0. Business decisions only the owner can make

None — no unanswered business decision is needed to start this bounded test.
If a genuinely new business question appears, consolidate the whole list in
one message; never turn technical access, installation or review into an ask.

Already settled; do not re-ask:

- October 31, Albert: “let's test Entire controlling testing and merging, with
  GitHub retaining the official code.” This authorizes the replacement-control
  **trial**, not just mirrored results. It does not claim a successful or
  permanent protected-main cutover.
- Existing runners edge-runn-envy, edge-runn-xps and edge-alien are the requested
  compute. Preserve their GitHub services; do not substitute rented compute
  and claim existing-runner acceptance.
- All four clients × four development machines, all 16 live checks and the
  whole CI process remain required. No private capture, billing investigation,
  purchases, paid Agents, support dependency or deadline reset.
- Discovery November 2, 2026, 5:00 PM EST; stop November 12, 2026, 5:58 AM EST.

## 1. What this application is

[popcre/ai-devops](https://github.com/popcre/ai-devops) is Albert's public
multi-model coding/recovery toolkit: Bash/Python/PowerShell tools, installers,
shared client instructions, tests and CI. It is not a deployed business app.
Installation is its deployment mechanism. Development hosts: edge-dev3 Ubuntu;
edge-dev, al8960ofc (SSH alias4837) and916 Windows. Coding clients: Codex,
Claude, MiMo/MiMoCode and ZCode. The requested CI runner machines are distinct
from that development-host matrix and must not receive a full toolkit install.

Owning issue: [#2022](https://github.com/popcre/ai-devops/issues/2022).
Specification: [the whole plan, starting with the October31 amendment](https://github.com/popcre/ai-devops/blob/main/plan_entire-reversible-trial.md).
Operating record: [Entire trial](https://github.com/popcre/ai-devops/blob/main/docs/entire-trial.md).
Verification record: [report](https://github.com/popcre/ai-devops/blob/main/tests/verification/entire-trial/report.md).
Read all plan phases through T7/R8, not merely the next task.

## 2. Goal, trigger and session boundary

Albert challenged the premise that displaying GitHub checks in Entire solves
slow PR/check/merge delivery. It does not. The coordinator initially offered
display-only operation; Albert rejected that weaker outcome. His exact latest
authorization is in §0. This session deliberately cuts over before the new
controller experiment; no replacement CI or native merge was executed.

The desired evidence is actual test execution on existing runners, current-head
failure enforcement, actual Entire-controlled merge, official-code publication
to GitHub, complete suite/OS/process parity, measured end-to-end latency and
working GitHub-only recovery. Distinguish each result. A trial-target publication
does not prove the protected-main PR/queue bottleneck has disappeared.

## 3. Current state and evidence

### Source, delivery and fixtures

- [PR2195](https://github.com/popcre/ai-devops/pull/2195) merged the shared
  public-only/time-bound capture-free instruction block in all four globals,
  adoption/preservation fixtures and trial records. Exact corrected source
  [990c8b95](https://github.com/popcre/ai-devops/commit/990c8b95ab3d3f66d7153b374961aaea387cb800)
  passed ordinary Linux aggregate and all12 Windows PR sections in
  [run41117625277](https://github.com/popcre/ai-devops/actions/runs/41117625277).
  Queue landing is [d7f4c10](https://github.com/popcre/ai-devops/commit/d7f4c10d4fcd6cf3038366cd03e17c53820d869f),
  queue [run41120242623](https://github.com/popcre/ai-devops/actions/runs/41120242623)
  SUCCESS. Do not repeat the same completed full suite without new changes.
- Focused phrase/render/adoption/install-skills fixtures passed Linux and real
  Windows/Git Bash on all three development hosts at initial source
  [86370b0b](https://github.com/popcre/ai-devops/commit/86370b0b922cb991f868348abb002d7a596f8175).
  Do not relabel those manual receipts990; later ordinary CI qualifies990.
  CRLF machine-tail bytes, homes with spaces and synthetic capture-off config
  sentinels were preserved. These are fixtures, not native-client live proof.
- Latest main fetched for this handoff was
  [a518372b](https://github.com/popcre/ai-devops/commit/a518372b915eacc3ba593936103c61f2f64327a6).
  The three trial documents had no intervening changes versus990. New handoff,
  controlling amendment and record updates are prose only; their publication
  receipt is posted to #2022 after merge. Fresh execution uses its own current
  upstream worktree, not either outgoing task worktree.

### Partial installations — urgent, not delivered

The protected updates advanced source but did not complete. Last observations
were October 30 except Linux source/cleanliness rechecked October 31.
Recheck current state before writing; do not multiply an unfinished transaction.

| Host | Last observed installed source | Exact unfinished state |
|---|---|---|
| edge-dev3 | d7f4c10, clean | Required private-memory seed rejected outgoing union; updater exited1, no accepted complete transaction. |
| edge-dev | d7f4c10, clean | Both managed gate launcher receipts still1f4fb59; installer stopped at retired-task query under PowerShell5.1; no Done marker. |
| al8960ofc /4837 | d7f4c10, clean | Same stale1f4fb59 managed receipts and absent-retired-task failure; no Done marker. |
|916 | Last inventory1f4fb59, clean | Installation was not attempted. |

Windows process ExitCode captured via Start-Process was blank; both processes
actually exited, but blank is not success. Error: `schtasks.exe : ERROR: The
system cannot find the file specified.` Both retired task names were absent.
Source at [Windows installer lines1325–1333](https://github.com/popcre/ai-devops/blob/d7f4c10d4fcd6cf3038366cd03e17c53820d869f/bin/install-ai-devops-windows.ps1#L1325)
queries absent tasks before checking LASTEXITCODE; PowerShell5.1
NativeCommandError interrupts with ErrorActionStop. Test-mode fixtures skip
this stage, so no existing absent-retired-task case covers the failure.
Do not suppress all scheduler errors or disable the retirement capability.

Linux private-memory health found only index12468bytes versus12288limit,
180bytes too large. No missing/broken entries were reported. No private facts
or clone files were edited, union pushed, limit raised or stage bypassed.
The configuration-sync skill explicitly says stop on failure and not manipulate
the private clone; load it for supported recovery. A public installation fix
does not authorize editing private/generated memory to make a health test green.

Linux's ordinary [skills installer](https://github.com/popcre/ai-devops/blob/d7f4c10d4fcd6cf3038366cd03e17c53820d869f/bin/ai-install-skills#L852)
refreshes only Claude/Codex globals. [Explicit four-client adopter](https://github.com/popcre/ai-devops/blob/d7f4c10d4fcd6cf3038366cd03e17c53820d869f/bin/ai-adopt-globals)
also handles MiMo/ZCode. After the partial Linux update Claude/Codex matched
the target; MiMo/ZCode still lacked the trial block. Machine tails survived.
Repair this real default-distribution gap safely; do not invoke an unconditional
forced adopter that overwrites unknown local edits. Isolate all client homes
in installer tests before extending them, or fixtures could touch real homes.

### Native app matrix and access

All16 accepted fresh-app journeys: **0 passed**. No file, version, doctor or
CLI login receipt counts as a Desktop session. edge-dev has all four Desktop
apps; other Windows hosts lacked MiMo/ZCode apps in observed registrations and
locations. Linux has native ZCode but no MiMo app. Official MiMoCode CLI has a
Linux route; it is a distinct launch surface, not proof of MiMo Desktop.
Private inventory records exact versions and roots; refresh rather than guess.
Codex/Claude CLI status declared logged in on Linux and916, Codex on4837;
Claude SSH status onedge-dev/4837 said loggedInfalse. Desktop login is unproved.

The current computer-use surface had browser control but native app APIs were
disabled. No suitable native-control plugin was discovered. Do not bypass
that limitation through ad hoc UI automation or substitute headless sessions.
Use a supported capable session if available; otherwise name the exact blocker.
4837 WinGet and its signed installed binary both returned AccessDenied even
for a version query. Do not disable Windows protections or downgrade clients.

### GitHub/Entire and CI

[Latest feasibility receipt](https://github.com/popcre/ai-devops/issues/2022#issuecomment-6550148920)
contains sourced investigation and policy facts. Runner inventory October31
confirmed EDGE-ALIEN, EDGE-RUNN-ENVY and edge-runn-xps online. The active
[ruleset21564317](https://api.github.com/repos/popcre/ai-devops/rulesets/21564317)
requires PR, merge queue and verification-closure. Those settings were not
changed. October31's authorization changes trial intent; these remain actual
technical constraints until a supported transition is implemented.

Authenticated [Trail274/Change125](https://entire.com/gh/popcre/-/trails/274/changes/ai-devops/125)
readback October31 showed Merged and Checks29of29passed with links to the
actual GitHub jobs at990. Its separate nonrequired Entire Gates previously
failed for missing approvals/behind-base; GitHub still delivered normally.
No approval is required by this task and no gate was weakened. Historical
Trail231/Change98 after merge said Notchecked; archive behavior differs.

All12 workflows and182 suite registrations were inventoried:30PowerShell,
49Bash with Windows metadata,103Bash unannotated; the last group is not assumed
Linux-only. Full Windows backstop is correctly skipped on PR events; ordinary
PR success does not establish every trigger ran. An older full Windows run
had StepFun doctor assertion failures; current full-trigger parity is unproved.

The Entire project previously had no plugin. Neither Depot nor Buildkite was
connected; their login pages were only inspected. Vault title searches found
no existing provider entry, which does not establish that no account exists.
Buildkite's provider docs support self-hosted Entire checkout, but Entire's
overview says hosted agents. Validate actual Windows jobs before claiming
support. Depot's documented route uses Depot compute and lacks PR triggers;
it does not establish reuse of Albert's physical Windows runners. GitHub-hosted
runners cannot simply be registered to another controller.

### Disposable failure experiment

[DraftPR2196](https://github.com/popcre/ai-devops/pull/2196) is NEVER MERGE,
with no auto-merge request. Failed source
[9257823b](https://github.com/popcre/ai-devops/commit/9257823ba78fe284092f6aed878535d19a6d0f6a)
had one intentionally missing managed-policy phrase. GitHub
[run41117200862](https://github.com/popcre/ai-devops/actions/runs/41117200862)
reported actual Linux/Windows failures; authenticated
[Trail275/Change126](https://entire.com/gh/popcre/-/trails/275/changes/ai-devops/126)
showed5of27failed at that exact head. Repair source
[4e244108](https://github.com/popcre/ai-devops/commit/4e2441081c270288a50fbb058b9229ad0b57a784)
restored the phrase and was seen as current/pending rather than old acceptance.
Later all actual repair CI jobs passed; optional Entire Gates must not create
a wait. Reconcile current PR state once, retain evidence and close unmerged.
No last-green→newer-failure→repair acceptance chain has been fully qualified.
No faulty experimental source was installed or merged.

## 4. Failed attempts and rejected shortcuts

Do not repeat: equating a mirror with changed CI; claiming fixture/file presence
as native adoption; claiming current GitHub policy disappears behind Entire's
Merge button; using Git operation speed as delivery timing; treating vendor
documentation as a completed Windows job. Capture/privacy previously failed
and matched retrieval scored Entire8/10 versus ordinary10/10; do not rerun or
rewrite that as adoption success. Trail113/133 deletion is unsupported; closure
and unlink are not erasure. Support is not an active dependency.

GUI version calls can launch/hang the actual app: Linux zcode --version timed
out; use package metadata for version inventory. Some browser tabs became
stale: obtain a fresh tab from the already selected browser, compare exact
commits, and never infer identity from a cached title. Do not repeatedly poll
GitHub or await optional Entire approvals. Preserve original client hooks:
the trial prohibition is **Entire** capture hooks, not all normal session hooks.

## 5. Root causes and source map

The original implementation solved a narrower public-companion instruction
problem, not control replacement. The October31 amendment supersedes old
shadow-only constraints for the bounded experiment. The plan retains history;
read amendment precedence before interpreting historical restrictions.

Key owning sources, all portable:

- [Global renderer](https://github.com/popcre/ai-devops/blob/main/bin/ai-render-globals),
  [canonical Codex global](https://github.com/popcre/ai-devops/blob/main/templates/system/AGENTS-global-codex.md),
  [canonical Claude global](https://github.com/popcre/ai-devops/blob/main/templates/system/CLAUDE-global.md).
- [Installer/adoption tests](https://github.com/popcre/ai-devops/tree/main/tests),
  especially test-ai-install-skills, test-ai-adopt-globals and
  test-install-ai-devops-windows; extend existing harnesses rather than copy.
- [Deployment procedure](https://github.com/popcre/ai-devops/blob/main/docs/deployment.md),
  [configuration](https://github.com/popcre/ai-devops/blob/main/docs/configuration.md),
  [secrets onboarding](https://github.com/popcre/ai-devops/blob/main/docs/onboarding-secrets.md),
  [task router](https://github.com/popcre/ai-devops/blob/main/docs/task-router.md),
  [CI registrations](https://github.com/popcre/ai-devops/tree/main/config/ci-suites).
- [Entire native branches](https://docs.entire.com/guides/repositories/entire-native-branches)
  avoid upstream writes while developing but do not sync upstream automatically;
  [CI overview](https://docs.entire.com/guides/ci/overview),
  [Buildkite Entire self-hosted integration](https://buildkite.com/docs/pipelines/source-control/entire#check-out-repositories-on-self-hosted-agents)
  and [Windows agent install](https://buildkite.com/docs/agent/self-hosted/install/windows)
  define the candidate supported route. Refresh exact versions/commands.

## 6. Exact next steps and verification gates

1. Claim #2022 as the new coordinator and reconcile this handoff, the entire
   amended plan and current source/install/rules/runner evidence. Recover
   private baselines using §8. Gate: fresh manifest and owner, no stale state
   presented as live; all downstream T/R assumptions checked.
2. Execute planT1/T2: preserve/recover partial host transactions before writes,
   qualify Buildkite/current account access and supported self-hosted Windows
   setup; preserve GitHub runner capacity. Gate: an actual Entire-triggered
   exact-source job on one named runner, then all necessary runners/OS lanes;
   account or platform limits explicitly owned without purchases or broad grants.
3. ExecuteT3: supported isolated Entire merge trial, Git export proof, positive
   and newer-failure/repair cases with current proposed-merge identity. Gate:
   actual passing merge and rejection of bad/missing/stale results, not a screenshot
   of GitHub results. Export evidence before any cleanup.
4. ExecuteT4/T5: GitHub trial-target official-code publication, exact object/tree
   readback, separate protected-main feasibility and matched full-process timing.
   Gate: no remaining GitHub PR/check/queue delay is hidden in the claimed
   replacement; all triggers/suites/OS/review/fixer/recovery behaviors accounted
   for. Keep trial publication distinct from a permanent main cutover.
5. CompleteT6 and originalR2/R4/R5/R6 using tested source repairs and protected
   installations; qualify actual native clients. Gate: four completed install
   receipts and16 independent real-session journeys, or precise unmet cells.
6. ExecuteT7/R7/R8: GitHub-only recovery, preserve code/records/client capability,
   reconcile every report and issue checkbox; apply original stop regardless of
   sample count. Gate: all outcomes proved or honestly dispositioned; no fake
   completeness and no unowned technical blocker.

At the end of every phase, **re-read all downstream phases through T7/R8 and
the final acceptance checklist**, report drift on #2022 and update the plan
before continuing/cutting over. A single child success is not the whole job.

## 7. Constraints and gotchas

Current task is prose handoff publication only. Successor must redeclare before
code, installation or infrastructure, read applicable standing details, and
honor actual gate refusals without invented approval loops. No direct protected
main push, force-push or admin code merge. Prose follows exact-head doc-safety
and squash/admin; code/config follows normal delivery. All GitHub calls use
ai-gh; bounded event-aware waiters only. AI review is advisory.

Use task-owned current-upstream worktrees; canonical installations are landing
only. Public repo: never raw private inventories, addresses, transcripts,
licensed data, secret values or private submodules. No global logout, shared
App removal or native API workaround. Recover before destructive action.
Networking-only runner hosts are not full toolkit targets. Do not overlap full
tests with CI on a shared physical Windows host. Both Ubuntu and Windows need
proof for shared executable changes. Avoid test fixtures writing real homes.

## 8. Access and environment

GitHub CLI and git authentication worked as u2giants; Entire authenticated
browser worked, account u2giants. Commits use Albert Hazan's configured noreply
identity. No new provider connection exists from this work. Browser tab handles
are ephemeral; use known URLs and fresh supported browser selection. Native
app control remains a separate unqualified capability.

Resolve machine facts via ai-private-config path machine_atlas from the
approved private-config repository; never publish its contents. It identifies
installed roots, users, SSH aliases and supported installation routes. SSH
BatchMode access to the three Windows development hosts worked earlier.

Private custody ID **entire-2022-fleet-20261030**: owner-only trial evidence
under the coordinator's standard local state root, Entire-trial namespace,
dated20261030-fleet. Resolve the OS state root rather than copying this
machine's absolute paths. The inventory contains per-host baselines, hashes,
matrix, source/config backups and install-d7f4c10 logs/health/post-state JSON.
Do not publish them. The CI inventory, Windows-results summary, cutover PR
snapshot, issue snapshot and ruleset snapshot were also copied into its
cutover-20261031 evidence group with owner-only permissions. Those inventories
are supporting evidence, not native execution acceptance by themselves.

Secret store is1Password vault vibe_coding. Existing Linux sudo item title
edge-dev3 ahazan sudo password was used through an owner-only FIFO with echo
disabled; no value was exposed or retained. Load secrets-to-1password before
any secret handling. Do not print settings, PATH, environment or credential
files. Latest Codex configuration drift was project trust from another task;
preserve it, do not reset whole profiles for equality. No memory fact edits
are authorized merely to complete installer health.

## 9. Open technical questions, risks and dated decisions

October31: Buildkite self-hosted Entire/Windows parity and account availability
are unproved; docs disagree on hosted-only scope. Native Entire merging,
official GitHub publication, protected-main policy transition and speed benefit
remain unproved. These are coordinator-owned technical tests, not unanswered
business choices. New monetary commitments remain outside authority.

October30/31: partial installations and private-memory health need supported
recovery; existing client functionality must survive. Missing native apps,
login/control limits and differing configuration roots can prevent16-cell
acceptance. Never erase a cell or call a replacement wrapper the requested app.
Private capture and past privacy/retrieval failures remain unchanged.

Preserve predecessor handoffs: they include historical decisions/obligations;
this cutover does not retire them or rewrite the root pointer. Trial-owned
worktrees/branches remain recoverable; do not clean another session's files.

## Part B. Sub-agent accounting

**client_instructions:** asked to implement shared globals/preservation fixtures
in an isolated task worktree. Finished the patch; parent integrated and landed
the qualified result throughPR2195. Its original worktree still has uncommitted
source/tests, now superseded for delivery but retained for recovery. It did not
install, control native apps or qualify actual CI execution. Agent is completed,
not running; do not wait for it or recreate already-landed source blindly.

**ci_inventory:** inventoried workflows and staged Windows install candidates;
attempted protected edge-dev and4837 installs, then diagnosed absent scheduled
tasks and stale receipts read-only.916 was not touched. Completed; no background
installation is running. The coordinator mistakenly requested a hold after4837
had already also advanced; preserve both partial states. It made no scheduler
bypass, memory edit, native-client proof or CI-provider connection. Its public
delivery is integrated in the parent's evidence/issue, not a separate PR.

## Final whole-plan self-audit

1. **Can a newcomer continue without this chat? Yes.** §§0–3 give intent,
   source/live/install distinctions and receipts; §§5–8 give supported routes,
   exact next gates, custody/access and constraints. PlanT1–T7 covers through
   final disposition; originalR1–R8 and16cells are retained.
2. **Can they continue as effectively as this session? Yes.** §§3–5 preserve
   partial transactions, scheduler failure/test gap, Linux distribution gap,
   memory guard, app/control limits, provider-doc discrepancy, CI fault branch
   and the rejected display-only interpretation; PartB accounts for both helpers.
3. **Are all relevant execution details represented? Yes.** §§2–9 cover goal,
   exact source/delivery state, failures, supported alternatives, recovery,
   timing, deadlines and whole-process gates; all referenced public artifacts
   use GitHub/vendor URLs and private evidence is identified without disclosure.
   This certifies handoff completeness, not live-trial success.
4. **Does §0 contain every business decision and no technical approval? Yes.**
   Line-by-line sweep of §§1–9 and PartB found no unresolved owner judgment:
   controller choice is settled; all remaining access, compatibility, repair,
   test, publication and policy-feasibility questions have coordinator-owned
   gates. New spending stays prohibited. No missing technical prerequisite is
   disguised as an owner approval. Whole-plan and reciprocal-phase checks pass.
