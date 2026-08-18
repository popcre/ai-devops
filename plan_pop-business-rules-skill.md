# Implementation plan: `pop-business-rules` Skill

**Tracking issue:** [u2giants/ai-devops #35](https://github.com/u2giants/ai-devops/issues/35)  
**Handoff:** [HANDOFF.d/2026-08-18T1631Z-edge-dev-codex-pop-business-rules-skill-plan.md](HANDOFF.d/2026-08-18T1631Z-edge-dev-codex-pop-business-rules-skill-plan.md)

## STATUS

| Step | Status | Last updated | Evidence |
|---|---|---|---|
| 1. Confirm the canonical library is published | 🔄 in progress | 2026-08-18 | shared-db PR #1178 is accepted by Grok 4.6 and awaiting final CI/merge |
| 2. Author the shared Skill | ✅ complete | 2026-08-18 | `skills/shared/pop-business-rules/SKILL.md` |
| 3. Add trigger evaluations and behavioral contract tests | ✅ complete | 2026-08-18 | Eval JSON and offline contract test added; local tests pass |
| 4. Register the Skill in repository documentation | ✅ complete | 2026-08-18 | Router and Claude/Codex usage guides updated |
| 5. Install and verify on Claude and Codex | ⬜ open | 2026-08-18 | Planned installer and trigger evidence in Phase 5 |
| 6. Commit, push, verify CI, and close the workstream | ⬜ open | 2026-08-18 | Planned GitHub and cleanup checks in Phase 6 |

**Fresh-session starting point:** Step 1. Read this entire plan before editing anything.

## 1. Ultimate goal

Albert should be able to tell any Claude or Codex session, in ordinary language,
to find, explain, add, correct, or audit POP Creations business rules. The AI
must reliably enter the one companywide Business Logic Library, load only the
relevant topics, distinguish settled rules from proposals and history, and keep
applications from becoming competing rulebooks.

The Skill is the procedure and router. It is not a second copy of the rules. The
business rules remain owned by `u2giants/shared-db/docs/business-rules/`.

If a step conflicts with this goal, the goal wins. Stop and flag the conflict.

## 2. What this repository is

`u2giants/ai-devops` is Albert Hazan's public toolkit for installing and keeping
AI coding tools, shared Skills, instructions, and workflows consistent across
Windows and Ubuntu machines. It is not a customer-facing application and has no
production website.

The new Skill belongs at `skills/shared/pop-business-rules/` because both Claude
and Codex must follow the identical procedure. `bin/ai-install-skills` installs
shared Skills into both clients. The default branch is `main`; ordinary work in
this `u2giants` repo is main-only after reconciliation with concurrent work.

The separate `u2giants/shared-db` repository owns the Business Logic Library.
Its intended entry point is:

`https://github.com/u2giants/shared-db/blob/main/docs/business-rules/application-map.md`

`shared-db` mirrors its complete contents into consumer application repositories.
The Skill must support both the canonical checkout and those read-only mirrors.

## 3. What triggered this work

On 2026-08-18 Albert rejected application-specific business-rule ownership. His
direction is that POP's way of doing business applies across applications. A
selective map may tell an application or task what to read, but applications
must not own separate versions of business rules.

Albert then asked how to interact with the library. The agreed answer was one
cross-client Skill named `pop-business-rules`. Albert's expected phrases include:

- “Use the pop-business-rules Skill. Add this business rule: ...”
- “Use our Business Logic Library. What are our rules for creating Properties?”
- “Before changing PopCRM customers, identify every applicable business rule.”
- “Audit this implementation against our merchandise-group and mgCategory rules.”

No software defect or URL reproduces this request. The failure being prevented
is documentation drift: copied rules, stale rules that still look current, and
AI sessions reading an application plan as business authority.

## 4. Scope

### In scope

- Create one shared Claude/Codex Skill named `pop-business-rules`.
- Make it trigger on natural requests to read, explain, add, change, collect,
  reconcile, or audit POP business rules.
- Route sessions through the central application/task map and applicable topic
  documents without loading the whole library by default.
- Define separate read, add/change, and audit procedures.
- Enforce `Settled`, `Proposed`, `Historical`, and `Unknown` handling.
- Prevent the Skill from treating code, screens, database shape, plans, or old
  documents as authority for a new business rule.
- Require conflict and stale-copy cleanup whenever a rule changes.
- Route database structure changes through the existing shared-db process.
- Add realistic positive and negative trigger evaluations.
- Add offline tests that pin the Skill's routing and safety language.
- Register the Skill in the ai-devops documentation and installer guidance.
- Install and verify it in both Claude and Codex on the implementation machine.

### Not in this plan

- Collecting or rewriting the business rules themselves.
- Finishing the separate cross-repository business-rule audit.
- Creating the `core.mg_category` database tables tracked by shared-db issue #1163.
- Moving the Business Logic Library out of `u2giants/shared-db`.
- Creating an MCP server, database, search index, vector store, or web interface.
- Copying the Business Logic Library into `ai-devops` or into the Skill body.
- Automatically editing every application whenever a rule changes.
- Installing a separate Claude-only or Codex-only copy of the Skill.

## 5. Current state

### ai-devops

- Shared Skills already live under `skills/shared/<name>/SKILL.md` and are
  installed into both clients by `bin/ai-install-skills`.
- `AGENTS.md` routes new-Skill work to `docs/skills-map.md`,
  `docs/skills-usage-guide.md`, and one shared Skill directory.
- Trigger-evaluation infrastructure exists under `tools/skill-trigger-eval/`.
- `docs/skill-trigger-eval.md` explains the real Claude and Codex trigger paths.
- Offline installer and trigger-runner tests already exist under `tests/`.
- There is no `skills/shared/pop-business-rules/` directory today.
- Issue #35 tracks implementation.
- This plan was authored on branch `codex/pop-business-rules-plan` from
  `origin/main` commit `74b78f6`. The implementer must verify the current state
  rather than assume that SHA is still current.

### Business Logic Library

The planning session created, but had not yet committed or published, these
files in an isolated shared-db worktree:

- `docs/business-rules/README.md`
- `docs/business-rules/application-map.md`
- `docs/business-rules/product-development-workflow.md`
- `docs/business-rules/rfq-pricing.md`
- `docs/business-rules/digital-assets-and-file-integrity.md`

The intended map also routes to existing central documents for shared business
objects, licensing, merchandise taxonomy, and ERP meaning. Because those files
were uncommitted when this plan was written, Phase 1 is a hard dependency. Do
not ship a Skill whose canonical entry link returns 404.

## 6. Key findings and root cause

1. The business rules and the procedure for using them have different owners.
   `shared-db` owns the knowledge; `ai-devops` owns the reusable AI procedure.
2. A Skill is appropriate because this is a repeatable task-triggered procedure,
   not a universal rule that must consume every session's startup context.
3. The Skill must live in `skills/shared/`; separate client copies would create
   exactly the drift this work is intended to stop.
4. The application/task map is load-bearing. It prevents both extremes: reading
   every business document on every task, or assuming an application-specific
   file owns the rule.
5. Trigger selection and behavioral obedience are separate. Trigger evaluation
   proves the Skill was opened; offline content tests and scenario checks prove
   the procedure itself contains the required safeguards.
6. A repository mirror may lag canonical `shared-db/main`. The Skill must prefer
   an available current canonical checkout or GitHub source when a required map
   is missing from an old mirror, and must report that fallback instead of
   silently inventing a rule.

Evidence sources:

- `AGENTS.md`, rows for “Create a NEW skill” and “Write a skill description.”
- `docs/context-engineering.md`, ownership map and task-triggered Skill guidance.
- `docs/skills-usage-guide.md`, shared-Skill installation behavior.
- `docs/skill-trigger-eval.md` and `tools/skill-trigger-eval/README.md`.
- The canonical-library design in `u2giants/shared-db/docs/business-rules/README.md`
  after Phase 1 publishes it.

## 7. Approaches considered and rejected

### Put all business rules inside the Skill

Rejected. It creates a second authority and makes every rule change a coordinated
change across two repositories. The Skill must link and route, never copy rules.

### Create application-specific Skills or rule files

Rejected by Albert on 2026-08-18. Applications are views into the same business.
The application/task map handles selective relevance without dividing ownership.

### Put the full library into global Claude/Codex instructions

Rejected. It would load unrelated business context into every session and grow
the always-loaded prompt indefinitely. Only the Skill name and description need
to participate in task selection.

### Build search infrastructure first

Rejected. The topic map and Markdown links solve current discovery with fewer
moving parts. Search can be reconsidered only if measured use shows the map is
insufficient.

### Treat code, data, or screens as proof of a business rule

Rejected. They can reveal a conflict or an unanswered question, but can also
encode old or accidental behavior. Only an owner or explicitly named business
authority can settle a new rule.

### Use skill-creator's old bundled trigger loop

Rejected. `AGENTS.md` and `docs/skill-trigger-eval.md` state that it tests a
mechanism that no longer triggers and is Unix-only. Use this repo's Claude and
Codex trigger evaluators.

## 8. Locked and open design decisions

### Locked decisions, do not relitigate

- Name: `pop-business-rules`.
- Location: `skills/shared/pop-business-rules/SKILL.md`.
- One cross-client source, installed into Claude and Codex.
- The Skill contains procedure and routing only, never copied business rules.
- Canonical knowledge remains in `u2giants/shared-db/docs/business-rules/`.
- Business rules are organized by topic, never by application.
- The application/task map controls selective loading but never limits a rule's scope.
- Four statuses are mandatory: Settled, Proposed, Historical, Unknown.
- Proposed and Unknown material must not be implemented as settled behavior.
- A change must correct or mark conflicting current statements in the same workstream.
- Application repositories retain links and implementation evidence, not duplicate rules.

### Open implementation judgment

- Exact frontmatter description wording. Choose the shortest wording that fires
  on the positive set with zero false positives in the negative set.
- Whether the Skill needs a small reference file for examples. Prefer one
  self-contained `SKILL.md`; add references only if the procedure becomes hard
  to scan.
- Exact test script name and language. Prefer the repository's existing Bash
  style unless a Windows-only assertion makes PowerShell materially clearer.

## 9. Implementation plan

### Phase 1: prove the dependency is real and published

1. Fetch both `u2giants/ai-devops` and `u2giants/shared-db`. Confirm the Skill
   branch is based on current `ai-devops/main` and confirm the central library is
   present on `shared-db/main`, not merely in a local worktree.

   Required checks:

   ```bash
   git fetch origin
   git status --short
   gh api repos/u2giants/shared-db/contents/docs/business-rules/application-map.md?ref=main
   gh api repos/u2giants/shared-db/contents/docs/business-rules/README.md?ref=main
   ```

   If either GitHub call returns 404, stop. Finish and publish the separate
   shared-db documentation work first. Do not weaken the Skill to point at an
   unpublished branch.

   **Verification gate:** both GitHub content calls return file metadata for
   `main`, and the map links to topic documents that also exist on `main`.

### Phase 2: author the shared Skill

2. Read the installed `skill-creator` Skill completely, then create
   `skills/shared/pop-business-rules/SKILL.md`. Its frontmatter description must
   cover these trigger families without becoming a miniature procedure:

   - “use our Business Logic Library”;
   - “use pop-business-rules”;
   - find, explain, summarize, or cite a POP business rule;
   - add, change, correct, collect, or record a POP business rule;
   - identify the rules relevant to an application, feature, task, or object;
   - audit software or documentation against POP business rules;
   - reconcile duplicate, conflicting, or stale business-rule statements.

   The body must define these procedures:

   **Common entry procedure**

   - Locate `u2giants/shared-db` locally when available.
   - If inside a consumer repo, recognize `shared-db/` as a read-only mirror.
   - Start at `docs/business-rules/application-map.md`.
   - Load only topics touched by the task, including every topic for cross-topic work.
   - If local content is missing or stale, read canonical `shared-db/main` and say so.
   - Never infer a settled rule from application behavior alone.

   **Read/explain procedure**

   - Separate Settled, Proposed, Historical, and Unknown statements in the answer.
   - Cite the official topic file and, when useful, the exact heading.
   - Report material conflicts instead of silently selecting the convenient statement.

   **Add/change procedure**

   - Capture the exact business question and Albert's or the named authority's answer.
   - Update an existing business-topic document; create a topic only if none fits.
   - Record status, decision authority, and effective date.
   - Search the central repo and relevant application repos for conflicting current text.
   - Correct it, mark it Historical, or replace it with a pointer in the same workstream.
   - Update the application/task map when relevance changes.
   - Keep implementation details in the application and business meaning centrally.
   - Ask one clear owner question if authority is missing; do not promote a proposal.

   **Audit procedure**

   - Build the applicable-topic list from the map.
   - Compare code/docs/workflow behavior against Settled rules.
   - Report missing rules, duplicate authorities, stale current-looking text, broken
     links, behavior based on Proposed rules, and implementation conflicts.
   - Do not change code during a read-only audit unless the user also requested a fix.

   **Routing and safety**

   - Database structure work routes through `codex-shared-db-change` or
     `shared-db-orchestrator`; the Skill does not authorize direct database changes.
   - Curated Master Data imports retain their existing governance.
   - Licensed row contents never enter public documentation or outside-model prompts.
   - Never rewrite another session's handoff or application mirror.

   **Verification gate:** a reviewer can answer where to start, what to read, how
   to classify authority, how to add a rule, and how to clean conflicts using
   only this Skill and the linked library. The Skill contains no copied rule such
   as a royalty percentage, workflow status, or `mgCategory` mapping.

### Phase 3: test selection and behavior

3. Add `tools/skill-trigger-eval/pop-business-rules.eval.json` with at least 20
   realistic prompts: at least 10 positives and 10 near-miss negatives.

   Positive examples must include explicit Skill invocation, implicit library
   wording, adding a rule, explaining a rule, app-relevance discovery, conflict
   reconciliation, and auditing an implementation.

   Negative examples must include programming logic, ESLint rules, database row
   security, generic documentation cleanup, legal advice, another company's
   policies, and ordinary feature behavior where no business-rule request exists.

   Run both real evaluators after installing the Skill:

   ```bash
   python tools/skill-trigger-eval/skill-trigger-eval.py \
     --skill pop-business-rules \
     --eval-set tools/skill-trigger-eval/pop-business-rules.eval.json

   python tools/skill-trigger-eval/codex-trigger-eval.py \
     --skill pop-business-rules \
     --eval-set tools/skill-trigger-eval/pop-business-rules.eval.json
   ```

   Inspect every evidence line. A target score is 100% positive triggers and zero
   negative triggers. If a positive misses because it lacks enough POP context,
   fix the eval prompt only when a real session would also lack enough context;
   otherwise improve the description. Never hide false positives by weakening
   the negative set.

4. Add `tests/test-pop-business-rules-skill.sh`. It must fail unless:

   - the Skill exists only under `skills/shared/`;
   - frontmatter contains the exact name and a non-empty description;
   - the canonical map path appears;
   - all four statuses appear;
   - the text prohibits copying rules and promoting Proposed/Unknown material;
   - read, add/change, and audit procedures exist;
   - conflict cleanup and application-map updates are required;
   - direct shared-database structure changes are routed away;
   - no local absolute machine path such as `C:\repos` is embedded;
   - no known business-rule values or spreadsheet-derived mapping are copied in.

   Add this test to the existing aggregate test entry point only if this repo has
   a maintained explicit test list. Do not create a second test runner.

   **Verification gate:** the offline test passes, and deliberately removing each
   load-bearing sentence makes its corresponding assertion fail.

### Phase 4: make the Skill discoverable

5. Update these files without copying the Skill body:

   - `docs/skills-map.md`: add `pop-business-rules`, its purpose, and natural phrases.
   - `docs/skills-usage-guide.md`: add the Skill to the shared-Skill catalog and
     explain that it routes to knowledge owned by `shared-db`.
   - `docs/codex-skills-usage-guide.md`: mention the shared Skill and example prompts.
   - `AGENTS.md`: add a task-router row for reading, adding, changing, or auditing
     POP business rules. Point to the Skill and the central map.
   - `README.md`: add a short entry only if README already catalogs shared Skills;
     otherwise do not grow it into a second skills map.

   Link this plan from the relevant AGENTS router row while issue #35 remains
   open, with instructions to read the STATUS table first. Remove the temporary
   active-plan pointer when all rows are complete and the handoff is retired.

   **Verification gate:** a new session can discover the Skill by searching
   `AGENTS.md` or `docs/skills-map.md`, and no documentation contains a copied
   business rule.

### Phase 5: install and verify both clients

6. Run the normal installer from the ai-devops checkout:

   ```bash
   bash bin/ai-install-skills --dry-run
   bash bin/ai-install-skills
   ```

   Verify byte-for-byte installation:

   ```bash
   diff skills/shared/pop-business-rules/SKILL.md ~/.claude/skills/pop-business-rules/SKILL.md
   diff skills/shared/pop-business-rules/SKILL.md ~/.codex/skills/pop-business-rules/SKILL.md
   ```

   On Windows, use Git Bash for these commands. Do not use `--adopt-globals`;
   this Skill does not require replacing global instruction files.

7. Run the existing installer and context tests named in `docs/development.md`,
   plus the new Skill test and both real trigger evaluations. Run one read-only
   behavioral probe per mode:

   - Read: ask for rules relevant to `mgCategory` and confirm it selects only the
     taxonomy topic plus linked context actually needed.
   - Add: in a disposable repository copy, ask it to record a hypothetical rule
     explicitly marked Proposed; confirm it does not modify an application file.
   - Audit: ask it to compare a small fixture containing one Settled conflict and
     one Historical statement; confirm it distinguishes them.

   Never use a real new business rule for the test fixture.

   **Verification gate:** installer tests pass, installed files match, both
   clients trigger correctly, and the three probes follow the routing contract.

### Phase 6: land and close

8. Reconcile the isolated branch with current `origin/main`. Preserve unrelated
   concurrent changes and stage only this work. Verify commit identity before the
   first commit:

   ```bash
   git var GIT_COMMITTER_IDENT
   ```

   It must show `Albert Hazan <u2giants@users.noreply.github.com>`. If not, run
   the repo's approved identity helper before committing.

9. Update this STATUS table with exact evidence for each completed row. Record
   trigger-evaluation results in a durable file under `docs/` or `tests/` if the
   evaluator does not already produce a committed artifact. Do not cite a bare
   percentage without the prompts and evidence behind it.

10. Commit, push, and verify GitHub checks. This is a `u2giants` repo, so land on
    `main` following current repository policy. Do not sweep another session's
    working files into the commit.

11. After issue #35 is closed and the merged commit is on `main`, remove this
    plan's temporary active-plan router pointer and delete this workstream's
    handoff file in the completing commit. Retain this plan as the implementation
    record unless repository convention explicitly closes plans another way.

    **Verification gate:** GitHub `main` contains the Skill, tests, and docs;
    checks are green; the installed Claude and Codex copies match `main`; issue
    #35 is closed; and no open handoff falsely claims this work remains unfinished.

### Natural context cut

If Phase 2 through Phase 4 consumes most of a session, stop after the offline
tests pass. Update this plan and write a fresh handoff before beginning live
client installation and trigger evaluation. The next session must reread Phases
5 and 6 in full before acting.

## 10. Tests required

- New `tests/test-pop-business-rules-skill.sh` with the assertions listed in Phase 3.
- New `tools/skill-trigger-eval/pop-business-rules.eval.json` with at least ten
  positives and ten near-miss negatives.
- Existing `bash tests/test-ai-install-skills.sh`.
- Existing `bash tests/test-installer-parity.sh`.
- Existing `bash tests/test-codex-trigger-eval.sh`.
- Existing context test appropriate to this machine, currently
  `pwsh -File tests/test-context-audit.ps1` on Windows.
- Real Claude trigger evaluation.
- Real Codex trigger evaluation at explicit low or medium reasoning effort, as
  enforced by the runner.
- Three behavioral probes for read, add/change, and audit modes.

All tests must fail loudly. A skipped client evaluation is not a pass; record the
specific access blocker and leave the corresponding STATUS row open.

## 11. Constraints and gotchas

- Use the `skill-creator` Skill when implementing this new Skill.
- Keep one source in `skills/shared/`; never create client-specific duplicates.
- Never place actual business rules in the Skill or ai-devops documentation.
- Never point at an unpublished branch as the permanent library.
- A consumer repo's `shared-db/` directory is a mirror and must not be edited.
- The Skill may read application documents for conflicts, but business rules are
  authored only in canonical `u2giants/shared-db` topic documents.
- `Settled` requires Albert or an explicitly named authority. Code and data are evidence only.
- Do not implement a Proposed or Unknown rule.
- Do not allow business-rule work to bypass shared-db database governance.
- ai-devops is public. Never include licensed rows, credentials, transcripts, or secrets.
- Use the real trigger evaluators. Do not use skill-creator's obsolete trigger loop.
- GPT-5.6 evaluations must use low or medium reasoning effort only.
- Preserve concurrent work. Never use `git add -A` in a dirty shared checkout.
- Do not modify `HANDOFF.md`; use one new file under `HANDOFF.d/`.
- No UI, deployment, database, or production infrastructure change is part of this plan.

## 12. Access and environment

- Repository: `https://github.com/u2giants/ai-devops`.
- Dependency repository: `https://github.com/u2giants/shared-db`.
- GitHub CLI `gh` must be authenticated for repository and issue verification.
- Claude CLI must be authenticated for the real Claude trigger evaluation.
- Codex CLI must be installed and authenticated for the Codex trigger evaluation.
- No Supabase, Cloud SQL, Google Cloud, deployment, or 1Password secret is needed.
- If authentication is unexpectedly required, credentials belong only in
  1Password vault `vibe_coding`; never put values in this repo or plan.
- Implementation branch/worktree should be isolated when the main checkout is dirty.
- Current planning worktree: `C:\repos\ai-devops-worktrees\codex-pop-business-rules-plan`.
  This machine-local path is planning evidence only and must not be embedded in the Skill.

## 13. Definition of done, risks, and open questions

### Definition of done

- [ ] Canonical Business Logic Library entry files exist on `shared-db/main`.
- [ ] `skills/shared/pop-business-rules/SKILL.md` implements all three modes.
- [ ] The Skill contains procedure and routing, with no copied business rules.
- [ ] The application/task map is the first content entry point.
- [ ] All four rule statuses are handled correctly.
- [ ] Conflicting and stale current-looking text must be corrected in the same workstream.
- [ ] Trigger eval set covers positives and near-miss negatives.
- [ ] Offline behavioral contract test passes.
- [ ] Existing installer, parity, trigger-runner, and context tests remain green.
- [ ] Claude and Codex trigger evaluations meet the stated target with inspected evidence.
- [ ] Read, add/change, and audit probes behave correctly.
- [ ] Documentation and AGENTS router make the Skill discoverable.
- [ ] Installed copies match the shared source byte for byte.
- [ ] Commit identity is correct; changes are committed and pushed.
- [ ] GitHub checks are green and `main` contains the result.
- [ ] Issue #35 is closed and the handoff is retired.

### Risks and rollback

- **Library not published:** hard stop at Phase 1. Rollback is unnecessary because
  implementation has not begun.
- **Trigger too broad:** it could intercept programming-rule or policy requests.
  Tighten the description and retain strong near-miss negatives.
- **Trigger too narrow:** users would need exact Skill wording. Expand the
  description based on missed realistic positives, not artificial keyword stuffing.
- **Skill duplicates knowledge:** remove the copied rule and replace it with a
  topic/map pointer before merge.
- **Mirror lag:** prefer canonical `shared-db/main` and report the fallback; never guess.
- **Bad procedure affects both clients:** revert the merged ai-devops commit, run
  `bin/ai-install-skills`, and verify both installed copies revert together.

### Open questions

No owner decision is required to begin. The design choices Albert settled on
2026-08-18 are recorded as locked in Section 8. Implementation wording may be
adjusted against measured trigger evidence without changing those decisions.

## Mandatory self-audit

1. **Could a brand-new AI session execute this without asking Albert anything? Yes.**
   Sections 1–4 define the outcome and scope; Sections 5–8 preserve current
   state, evidence, rejected approaches, and locked decisions; Section 9 names
   exact files, commands, behavior, dependencies, and gates; Sections 10–13
   specify testing, access, landing, risks, and rollback.
2. **Does it carry the background, nuance, and reasoning held by the planning session? Yes.**
   Sections 3, 6, 7, and 8 record Albert's direction, why a Skill is appropriate,
   why knowledge must not be copied, the unpublished-library dependency, client
   parity, trigger-versus-obedience distinction, and rejected alternatives.
3. **Is the goal clear enough to guide a correct judgment when a step is wrong? Yes.**
   Section 1 states the business outcome, separates procedure ownership from
   knowledge ownership, and explicitly says the goal wins over a conflicting step.

### Checklist result

- All 13 sections are present.
- A fresh session needs neither this chat nor unstated project knowledge.
- Rejected approaches and failed directions are explicit.
- Every implementation step names files and a verification gate.
- Locked and open decisions are labeled.
- Out-of-scope work is explicit.
- Tests are named by file, scenario, and expected behavior.
- Paths, repositories, URLs, issue, branch, and environment are defined.
- No secret values appear.
- Commit, push, CI, installation, and final cleanup are in the definition of done.
- The plan and handoff link to each other.

**Self-audit result: PASS.**
