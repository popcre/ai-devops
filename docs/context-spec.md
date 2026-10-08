# Current context contract

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
(#1239). Today it names one entry: `database` for `private-tooling`, released
by the gate `reviewed-private-data-writer`. When the effective class is
`private-tooling` and the repository's own policy declares that gate, an
owner-requested row write authored as writer code reaches the reviewer-approval
step instead of the protected stop: it still needs an assigned AI reviewer's
lifecycle-recorded `final-check` or `security-review` APPROVE of the exact head
(`--reviewer-approval`). It never releases `private-evidence`, so one licensed
row in the change set keeps the action sealed, and it opens no other action.

The central `application_source_releases` map is a separate source-only route for
the single reviewed DesignFlow backend sandbox target. `deploy` can reach its
existing Cloud Build branch-source push only with the exact committed central
manifest, a committed consumer declaration requiring `cloud-build-release-review`,
and an independent lifecycle-recorded exact-head `final-check` or
`security-review` APPROVE. It does not authorize manual cloud changes or weaken
any other protected action; without the explicit target flag, generic refusal
remains in force.

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

`bin/ai-review` exports `AI_REVIEW_GATE_MODE` and `AI_REVIEW_REVIEWER_APPROVAL` so
the reviewer lifecycle, which the provider wrappers call for every mode, can see
the review mode and the assigned AI reviewer's approval report. They keep an honest caller from being
refused; they are not a security boundary. Anyone who can set an environment
variable in the session can already run the provider wrapper directly. Export
neither by hand: an approval left set in a shell would re-authorize every later
review in it, each one recorded as if newly approved.
