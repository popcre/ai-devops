# Current context contract

Selective fresh-reader checks for complex plans/handoffs: read
[`plan_selective-fresh-reader.md`](../plan_selective-fresh-reader.md) STATUS first;
this is an open pilot plan, not an installed or mandatory review workflow.

This is the compact, current specification for Claude/Codex context in
`ai-devops`. The completed historical work and decisions remain in the STATUS
table of [`../plan_context-engineering-consolidation.md`](../plan_context-engineering-consolidation.md).

- Always-loaded globals contain only universal behavior and safety rules.
- `AGENTS.md` holds repository invariants and the category router;
  `docs/task-router.md` holds specialized routes; `CLAUDE.md` is a small adapter.
- Procedures live in task-triggered skills/docs; machine facts live in the
  machine atlas and are preserved by `ai-adopt-globals`.
- Portable facts live in the protected Markdown hub and are read through
  `ai-facts`; Codex SQLite is never the portable sync target.
- A rule has one owner. Other files carry only a path plus a trigger.
- Source budgets and effective installed-global bytes are separate ratchets.
  Installed measurement includes preserved machine sections.
- Skill-description changes require the matching committed trigger-eval set.
  Use repeated runs and more than one platform for decisions; a single
  stochastic score is only an observation.

Generate the current measurements rather than copying numbers into prose:

```powershell
python tools/context-audit/context-audit.py --root . `
  --claude-home "$env:USERPROFILE\.claude" `
  --codex-home "$env:USERPROFILE\.codex" `
  --json .ai/context-current.json --strict
python tools/context-audit/render-measurements.py .ai/context-current.json
```

Acceptance is: strict audit success, no budget warnings, no missing safety or
parity rules, no broken links, and an explicit effective-installed measurement.

## What a root router may contain

A repository's root router (`AGENTS.md`) answers one question: what does a
session need to know before it does anything here. It carries only:

1. what the repository is for, in a few lines;
2. the safety and ownership boundaries that never change — who may write here,
   what may never be edited directly, which identity is used;
3. the routes for the tasks that actually come up often, one line each; and
4. links to the specialized routes for everything else.

Everything else has an owned home and is reached from there: procedures live in
task-triggered skills and docs, machine facts in the machine atlas, live values
resolved at the moment they are needed, and history in its plan's STATUS table.
A rule has one owner; every other mention is a path plus a trigger.

Size is a warning, never a failure. A router that grows past its budget gets a
diagnostic saying so, and the fix is to move content to its owner — never to
delete a safeguard to fit. Nothing may be dropped in a migration: every removed
line is accounted for as kept, moved, consolidated, or deliberately removed.

## Task classes and gates

`config/task-gates.json` says what a change is (its class) and, separately,
which gates that class must pass. `config/task-gates.schema.json` is the
contract; `tools/ci/validate-task-gates.py` enforces it. A repository may ship
its own `.ai-devops/task-gates.json`, which can only strengthen a class.

Toolkit installation is a distinct non-protected class: it keeps deployment
refused until an assigned AI reviewer's exact-head APPROVE is recorded, then permits the supported
installer to run. It must not be modelled as protected `deployment`, because a
forbidden action on a protected class has no authorization path and would make
the installer permanently unusable.

A toolkit update can also carry reviewer-safety changes made since the host's
last installed commit. For the supported `popcre/ai-devops` and redirected
`u2giants/ai-devops` GitHub origins only, `deploy` is allowed for that
protected class when its repository declaration carries
`reviewed-toolkit-installation` and the check records an assigned AI reviewer's
APPROVE bound to the install action, repository, and exact head. The release still requires local tests,
exact-head independent review, and installed-routing proof. A different
repository or a foreign Git host cannot use this route even if it adds the same
declaration. The source repository must have the canonical GitHub origin.
If the same release contains a stronger deployment or infrastructure path,
the narrow reviewer-safety route refuses that mixed release.
The deployment check runs in a disposable candidate worktree, started at the
installed checkout's old HEAD and then advanced to the exact reviewed target.
It verifies that the distinct installed checkout and its managed launcher still
point to that old HEAD in the same Git repository before any live checkout
mutation. The installed checkout must be the durable primary checkout, the
launcher must be at its supported canonical path, and the exact target must
already be in fetched `origin/main` history. A caller cannot replace the recorded comparison base; an empty or
dirty reviewer-safety release cannot enter this route.
An unchanged checkout uses the installation-class reviewer-approval path only
with its canonical managed launcher and a source receipt matching the current
commit and gate bytes. Ubuntu uses `/etc/ai-devops/install-manifest.tsv`; Windows
uses matching commit and SHA-256 markers in both managed launchers, with their
full command and home routing checked. An explicit
`--first-install` instead requires that the canonical launcher is absent.
Missing or stale receipts cannot turn a late declaration after a pull into an
authorized maintenance install.

Inside a private-evidence repository, named tooling paths may use
`private-tooling` so local-tests are required. Review stays refused for both
private classes: a formal review snapshots the whole private repository. Any
licensed path in the change set forces `private-evidence` even if a higher-ranked
class was declared.

The one exception is the sealed attachment-only route, `code-only-review`,
requested solely by `bin/ai-review --code-only` (DeepSeek with an exact paths
file; the exporter admits only the selected code and the source never becomes a
provider working directory). It is a separate action, not a permission loop
around `review`: the formal review action stays forbidden, and the sealed action
refuses to start on a private class unless that repository's own
`.ai-devops/task-gates.json` declares the `synthetic-fixtures-only` gate for
that class. Opening the route is therefore each private repository's own
reviewed decision, made once in its own policy file rather than per review.

A second, equally narrow exception is the central `reviewer_release` map
(#1239). Its first entry is `database` for `private-tooling`, released
by the gate `reviewed-private-data-writer`. When the effective class is
`private-tooling` and the repository's own policy declares that gate, an
owner-requested row write authored as writer code reaches the reviewer-approval
step instead of the protected stop: it still needs an assigned AI reviewer's
lifecycle-recorded `final-check` or `security-review` APPROVE of the exact head
(`--reviewer-approval`). It never releases `private-evidence`, so one licensed
row in the change set keeps the action sealed, and it opens no other action.
A further entry names `production` for `infrastructure`, released by the gate
`reviewed-production-dispatch` (owner ruling 2026-10-20 in his chat: "yes, make
the change and finish the install"). It is closed to exactly `u2giants/ansible`:
the canonical origin, the gate declared in a clean consumer file committed at
HEAD, a clean worktree (ignored files included), and HEAD equal to the real
GitHub `main` read fresh from the fixed canonical URL with no system, global or
repository Git config. That `main` is the commit the apply workflow dispatches,
so the exact-head lifecycle APPROVE names the dispatched resource, and a local
tracking ref or `insteadOf` rewrite cannot impersonate it. Any other repository,
a dirty, stale or unpushed head, an uncommitted declaration, an unreachable
GitHub, or a broadened central entry stays sealed, and the `infrastructure`
action itself is never opened.

The central `application_source_releases` map is a separate source-only route for
four exact DesignFlow sandbox targets: backend (core), tracking, frontend, and
Item Master (item). `deploy` can reach each application's
existing Cloud Build branch-source push only with the exact committed central
manifest, a committed consumer declaration requiring `cloud-build-release-review`,
and an independent lifecycle-recorded exact-head `final-check` or
`security-review` APPROVE. It does not authorize manual cloud changes or weaken
any other protected action; without the explicit target flag, generic refusal
remains in force.

Backend retains its original admission and platform behavior. The three new
targets require qualified Linux, actual `sandbox-albert` branch, a recorded base
equal to the unique merge-base with current `origin/develop`, complete ancestry,
and no structural/infrastructure/production/private contributors. The native
`tools/application_source_release.py` proof refuses Git context injection before
discovery. It reads the canonical GitHub develop ref through the installed,
provenance-verified `ai-gh` helper and `/usr/bin/gh`, twice around admission.
Each exact-ref request has a finite 600-second shared-queue allowance; local
Git/configuration/helper checks retain 30 seconds. There are no added retries,
cached-ref acceptance or queue bypasses. A deadline expiry still refuses;
network failure, ref drift, source/helper movement or malformed responses refuse
without a receipt. Existing SSH/proxy/authentication settings remain usable;
normal fetch is outside the gate. No runtime test override, production target,
manual cloud mutation, or broader application-workflow is added. Source admission
is not deployment/live acceptance; DesignFlow's existing no-self-merge and PR
rules remain unchanged. See the [scoped plan](../plan_exact-designflow-sandbox-source-releases.md).
For the three new repositories, a consumer requiring `cloud-build-release-review`
must supply the exact target flag on every deploy, including future releases
after the declaration is upstream. Generic deploy cannot omit the closed proof;
other actions and backend's original route remain unchanged.

The separate `application-workflow` action admits only the authenticated HTS
Alsand sandbox workflow. The exact issue94 profiles remain; version 2 also
admits source-pinned, expiring synthetic acceptance with fixed routes, two
fixtures and strict provider/cost bounds (#2395). Version 3 separately admits
one synthetic dedicated legacy HTS call: pinned Luna/OpenRouter, 512 output
tokens, $0.10, no automatic retry or new records, and an exact request prefix.
Version 4 separately declares one HTTP request with up to nine internal Luna
calls, 4096 main output tokens and a $3.23 conservative request risk. It binds
verified prior usage to an aggregate prior-plus-nine call limit and reserves
that risk inside the unchanged $10 cumulative cap. No retry, billable tools or
separate paid preprocessing request is admitted. The receipt is not a transport
counter: the executor verifies the deployed call graph and reconciles actual
usage against its private hash-bound prior snapshot.
Version 5 is a distinct frozen R9 real-cohort diagnostic: at most 83 initial
inquiries, one inquiry in flight, zero owner answers, unchanged frozen membership,
and only job submission/detail routes. Private hash-bound input, readiness,
qualification, prior spend, provenance, runner, catalog and pricing evidence must
be checked by the executor before cohort access and bound immutably to its one
common ledger. V5 requires a verified conservative exposure receipt: reported
provider calls remain distinct from their upper bound, and accounted cost remains
distinct from the reserve for unobserved usage. Its budget baseline is the sum
rounded to eight decimal places and must be below $10. Its observed submission
stop is $10 minus that baseline;
it explicitly authorizes up to $45.50 exposure including one 99-call inquiry's
$35.4915 conservative overshoot. Starting credit need cover the observed remaining
allowance, not pretend that the full risk is prepaid. The session call limit
is the verified prior upper bound plus 8,217; old exact-usage receipts cannot
qualify v5 and existing profiles 1–4 are unchanged. This is not a hard provider
cap or transport enforcer. No item writes, learning, answer submissions, ambiguous
POST retries, separate HTTP provider retries or classification application are admitted.
V5 alone has a fixed maximum 72-hour initial lifetime, never renewed after claim;
older expiring profiles retain 24 hours. Actual runtime timeout evidence must fit
170,000 ms with the fixed three attempts and two automatic record answers.
Version 6 permits one declared original-v5 operational continuation solely for
a proved pre-provider immutable-input repair. It binds exact original ledger,
admission, manifest, readiness, runner and served-source evidence plus a private
receipt; the new runner/source must differ and expiry must remain identical.
All v5 routes and limits remain fixed. The executor verifies the original run,
three no-launch failed attempts and unchanged input/key/budget/qualification,
then appends one epoch and zero-reconciliation overlay. It cannot reset, chain,
rePOST the failed inquiry or relabel its outcome. Closed native metadata
admission never substitutes for that private proof.
Version 7 is a separate closed current-v6-parent transition solely for the
proved pre-snapshot JSON literal bind repair. The same twelve header fields
now bind the paused CURRENT v6 ledger/admission/manifest, with integer parent
schema 6 and unchanged original expiry. A new runner/source and private receipt
are required. The executor verifies the embedded v5 lineage, one prior epoch,
preserved failures/costs/current inquiry and synthetic roundtrip proof before
appending exactly one additional epoch. No third transition, new zero-cost
overlay, retry/rePOST, reset or input/key change is admitted; v5/v6 are unchanged.
Version 8 separately binds the immediate current-v7 parent for the fixed
prepack-item-identity-join repair. Its twelve fields require integer parent
schema 7, a distinct new runner/source and the identical original expiry.
The executor verifies the full v5→v6→v7 history, exactly two prior epochs and
preserved pre-create refusal/canonical identity proof before the third epoch.
No fourth epoch, retry/rePOST, reset, product-flag change or new zero-cost
overlay is admitted; all v5 limits and v5/v6/v7 predicates remain unchanged.
It excludes generic chat and shadow routes. It requires a clean committed
`.ai-devops/application-workflow-target.json` matching the closed target in
`tools/application_workflow_target.py`, canonical origin and effective reviewer-safety
or ui-live-workflow class. AI review is advisory (#2041). All ordinary SQL/database, structural, cloud, production,
manual-promotion, flag-change and operative Apply/Save prohibitions remain binding.
Use `check --before application-workflow --application-workflow-target
.ai-devops/application-workflow-target.json`; target
identity must be proved immediately before requests. Admission is an auditable
receipt, not an HTTP proxy. Repository-specific workflow prohibitions still win.
See [the scoped implementation and verification contract](hts-sandbox-workflow-gate.md).

`bin/ai-task-gates` records the declared class at the start of work and
rechecks the complete change set before any expensive or risky action. The
stronger of the declared and observed classes is the effective class whose
protection level applies, while required proofs from both classes are additive.
Forbidden actions come from the
effective class, so an explicitly declared production task can enter the
production gate without dropping the deployment proofs attached to its changed
files. A
protected class — reviewer safety, shared database, deployment, infrastructure,
production, private evidence — can never be acknowledged or reviewer-approved
away. A protected external action with neither changes nor a declared class is
also refused rather than guessed safe.

### The review-mode variables are a guardrail, not a boundary

Database verification uses the distinct `database-read` action. Unlike `database`,
it authorizes only bounded observation in a server-enforced READ ONLY transaction
followed by rollback, after fresh target proof. Calling a function that mutates,
refreshing a materialized view, acquiring explicit locks, or changing settings or
privileges is not observation. Existing mutation, archive, privacy, identity and
consumer-policy restrictions remain unchanged. Admission is not a SQL executor;
the caller must verify transaction_read_only before querying and retain private
results in their approved custody. The action is read-only verification under
production-owner authorization rules, not a release for production changes.

`bin/ai-review` exports `AI_REVIEW_GATE_MODE` and `AI_REVIEW_REVIEWER_APPROVAL` so
the reviewer lifecycle, which the provider wrappers call for every mode, can see
the review mode and the assigned AI reviewer's approval report. They keep an honest caller from being
refused; they are not a security boundary. Anyone who can set an environment
variable in the session can already run the provider wrapper directly. Export
neither by hand: an approval left set in a shell would re-authorize every later
review in it, each one recorded as if newly approved.

### Closed public generated-definition check

The [DesignFlow generated-fixture gate plan](designflow-generated-fixture-native-gate-plan.md) records the closed scope, qualification gates and retirement conditions.

`generated-definition-boundary-v1` is the sole public generated-only database
exception for `popcre/designflow-backend` reviewer-safety tasks. Its consumer must
add `reviewed-generated-definition-fixture-only` without changing any other
policy. The strongest class and global forbidden defaults remain unchanged.
`check --before database --action-manifest-stdin --reviewer-approval REPORT`
accepts only its exact closed descriptor, reviewed nine-path contributor set,
clean physical source/base, ordinary whole-source independent final review and
passing test evidence. That review seals protected source; it does not add a
second AI approval requirement for ordinary application row writes.

The installed public-only validator reuses native no-follow IO and lifecycle
proofs. It rehashes the exact eight source paths and every entry in the pinned
OWN dependency and npm inventories, as well as Node, admission bytes and output
absence. Initial inventories deliberately bind the qualified physical runtime;
they are not generic portable dependency manifests. Source/runtime files must
satisfy the existing native custody permission checks. Fixture/runtime pin
changes require reviewed installed configuration and source qualification.
Only fixed public generated definitions are in scope; no SQL, Docker, Node
module, provider, private capture or application process is launched by this
check. Existing #770 and Oracle routes retain their separate contracts.

Every attempt needs a fresh observed check and coordinator decision. The
existing task override records immutable source/input audit evidence; repeated
valid checks may succeed after revalidation. No token, consumption state,
execution lease or refund is created. Correlation IDs are not credentials and
no cryptographic control of later same-UID execution is claimed. Existing
result absence and exclusive output writing still prevent output reuse. A lost
response requires inspection of actual evidence before execution is decided.

The separate HTS schema-9 diagnostic metadata profile permits only exact,
admin-owned sandbox tagging after terminal evaluation. Its closed scenarios
are read-only inspection, one-way evaluation marking, and a single-synthetic
mark/reverse/mark proof. It has zero provider authority and does not extend
any frozen-evaluation epoch, budget or expiry. See
[the HTS gate contract](hts-sandbox-workflow-gate.md#post-run-diagnostic-metadata-schema-9).

The prepared HTS schema-10 profile is a distinct routing-only fourth epoch,
not diagnostic tagging. It preserves the original v8 lineage and lifetime,
uses one fixed isolated service/queue/lane, and separates tool provenance from
the current-security server image and semantic proof. Its private origin stays
unbound, with admission refused, until actual governed resource metadata is
proved. Original profile predicates are unchanged.
