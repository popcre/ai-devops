# Plan — Model-tier delegation: frontier models plan, lower-tier models implement

Parent issue: [popcre/ai-devops #782](https://github.com/popcre/ai-devops/issues/782)
Registered handoff: [`HANDOFF.d/2026-09-24T1605Z-edge-dev-zcode-model-tier-delegation.md`](HANDOFF.d/2026-09-24T1605Z-edge-dev-zcode-model-tier-delegation.md)

## STATUS — read this first

| # | Step | Status | Evidence |
|---|------|--------|----------|
| 0 | Plan written, registered in `HANDOFF.d/`, parent issue opened | ✅ done 2026-09-24 | This file merged on `main` (see git log for `plan_model_tier_delegation.md`); [issue #782](https://github.com/popcre/ai-devops/issues/782) first comment links it |
| 1 | Verify the three lower-tier dispatch paths (read-only) | ✅ done 2026-09-25 | Codex: `codex exec -m <MODEL>` supported (0.153.2 help quoted; Luna slug + plan exposure unverified — bounded live probe at first dispatch). ZCode: no headless model selector; manual path + gap [#828](https://github.com/popcre/ai-devops/issues/828). MiMo: CLI absent, `mimo run` flags unqualified (D10); manual path + gap [#829](https://github.com/popcre/ai-devops/issues/829). [Step 1 comment on #782](https://github.com/popcre/ai-devops/issues/782#issuecomment-5827260474) |
| 2 | Write `templates/system/model-tier-delegation.md` | ✅ done 2026-09-25 | File on `main` (this PR); `grep -c '^## '` returns 7 and all seven plan-named sections present by name (output quoted in the comment); dispatch table carries the three Step 1 rows: Codex `codex exec -m <MODEL>` with Luna slug + headless exposure marked unverified, ZCode manual path + [#828](https://github.com/popcre/ai-devops/issues/828), MiMo manual path + [#829](https://github.com/popcre/ai-devops/issues/829). [Step 2 comment on #782](https://github.com/popcre/ai-devops/issues/782#issuecomment-5833570138) |
| 3 | Add the identical routing block to the three client globals | ⬜ open | — |
| 4 | Point `CHATGPT-codex-cost-efficient.md` and `implementation-plan-standard.md` at the sheet | ⬜ open | — |
| 5 | Re-adopt globals on edge-dev and grep-verify installed copies | ⬜ open | — |
| 6 | Land the PR, add the router row, update issue #782 and this STATUS | ⬜ open | — |

**A fresh session starts at: Step 3.** Work through the steps in order; after each
step, set its STATUS row to done with real evidence, commit, and comment the next
step on issue #782. Re-read this plan before starting each step (drift check).

---

## Part 1 — Why

### 1. The ultimate goal — what we are actually trying to achieve

Albert pays frontier-model prices for mechanical implementation work. Today, when
a session running GPT-Sol-6 (medium) in Codex, GLM 5.3 MAX in ZCode, or Mimo v2.6
pro in MiMoCode holds a fully-specced implementation plan, that expensive tier
still types in the code itself. The work is mechanical: the plan already names the
files, the edits, and the pass/fail check for every step.

When this is done: **any frontier session holding a plan that passes the
implementation-plan standard hands the mechanical build to its harness's lower
tier — GPT-6 Luna (Codex), GLM 5.3 Flash (ZCode), Mimo v2.6 flash (MiMoCode) — and
verifies the result itself before anything lands.** Money is saved on every
planned task. Quality does not change, because every step keeps its verification
gate and the frontier session that wrote the plan is the one checking the result.

**If a step in this plan conflicts with this goal, the goal wins — stop and flag
it on issue #782 instead of improvising.**

### 2. What this repository is

`popcre/ai-devops` is not an application — it is the AI DevOps toolkit that
installs and configures Albert's four AI coding clients (Codex, ZCode, MiMo, and
Claude) on his Windows machines, and owns the shared rules those clients load:

- `templates/system/AGENTS-global-codex.md` → deployed to `~/.codex/AGENTS.md`
- `templates/system/AGENTS-global-zcode.md` → deployed to `~/.zcode/AGENTS.md`
- `templates/system/AGENTS-global-mimo.md` → deployed to `~/.config/mimocode/AGENTS.md`

The deployment map is `bin/ai-adopt-globals` lines 67–69 (home dirs) and 170–172
(the three template→destination pairs). `ai-adopt-globals` replaces the installed
file while preserving machine-specific sections. This machine is `edge-dev`
(Windows, Git Bash). Nothing here runs as a service; the deliverables are prose
and config templates.

### 3. What triggered this work

Albert's request in ZCode chat, 2026-09-24 (~11:30 AM EDT): his frontier models
(GPT-Sol-6 medium, GLM 5.3 MAX, Mimo v2.6 pro) should write very well-specced
plans and hand actual implementation to the lower tier (GPT-6 Luna, GLM 5.3
Flash, Mimo v2.6 flash), with the plans written deliberately so a lower-tier
model can implement them perfectly. A same-chat investigation confirmed **no
standing instruction like this exists anywhere** (see §6), and Albert approved
building it, with one constraint: the implementation plan itself must never name
its implementer (see §8).

### 4. Scope — in and out

**In this plan:**

- One canonical instruction sheet, `templates/system/model-tier-delegation.md`.
- One short, byte-identical routing block added to each of the three client
  globals (`AGENTS-global-codex.md`, `AGENTS-global-zcode.md`,
  `AGENTS-global-mimo.md`).
- Pointer updates in `templates/system/CHATGPT-codex-cost-efficient.md` and
  `templates/system/implementation-plan-standard.md`.
- Read-only verification of each harness's lower-tier dispatch path, recorded in
  the sheet's dispatch table.
- Re-adopting the globals on `edge-dev` and verifying the installed copies.
- Landing the PR, the `AGENTS.md` router row, and the issue/STATUS updates.

**NOT in this plan:**

- **No wrapper changes.** If a harness has no supported way to dispatch to its
  lower tier, that gap gets its own new issue (named in the sheet), not a fix
  here. This plan is prose-only.
- **No changes to `CLAUDE-global.md`.** Claude is not in Albert's frontier trio.
- **No change to the plan standard's quality bar.** The bar is already
  "zero questions"; we add a pointer, not a second tier.
- **No forced handoff.** Judgment-heavy work stays on the frontier tier by
  design; the sheet's do-not-handoff list says so.
- **No shared-db work, no reviewer-rotation changes, no scheduling/automation.**

---

## Part 2 — What we already know

### 5. Current state of the code

All on `main`, committed and clean as of 2026-09-24 3:55 PM UTC (main tip
`d7a5dc5e56a7`). Nothing in this plan is half-done; every artifact below exists
and works:

- `templates/system/AGENTS-global-codex.md` — 244 lines. Structure: Response
  Style → Global operating rules → `## Model, engineering, and Git rules` at
  line 194 → `## Work discipline`. **Contains no model-tier routing today.**
- `templates/system/AGENTS-global-zcode.md` — 244 lines, same structure, same
  line numbers for the section headings.
- `templates/system/AGENTS-global-mimo.md` — 262 lines, same structure (extra
  MiMo-specific content makes it longer); `## Model, engineering, and Git rules`
  also at line 194.
- `templates/system/CHATGPT-codex-cost-efficient.md` — 55 lines. Its
  `## Model routing` section (lines 44–55) already contains the kernel of this
  idea for ChatGPT-app use, but with retired model names (GPT-5.4/5.5 vs
  GPT-5.6) and no pointer to any canonical sheet.
- `templates/system/implementation-plan-standard.md` — 170 lines. The
  cross-tool plan standard (mirrored into the `implementation-plan-writer`
  skill). Demands plans a brand-new session executes "without asking a single
  question." Says nothing about who implements.
- `bin/ai-adopt-globals` — deploys the three globals (lines 170–172) preserving
  machine sections. Tested by `tests/test-ai-adopt-globals.sh`.
- `bin/ai-zcode` — headless ZCode wrapper. Read-only by default for asks
  (`DEFAULT_DISALLOWED_TOOLS="Edit,Write,ApplyPatch,Bash"`, line 68) — it was
  built for reviews/asks, and its doc header records parser limits. Whether it
  can run a **writable** lower-tier implementation session is exactly what
  Step 1 verifies; do not assume.
- `bin/ai-mimo` — headless MiMo wrapper (`ai-mimo ask`, `ai-mimo doctor`).
- `AGENTS.md` (repo root) — the task router; rows follow the pattern
  `| topic | plan link STATUS, issue #N | guidance |` (see lines 68–73).

### 6. Key findings and root cause

Investigated 2026-09-24, 11:30 AM–12:00 PM EDT, in ZCode chat:

1. **No existing tiering document anywhere.** Searched
   `popcre/ai-devops` (docs, templates, skills, bin, plans), both skills
   directories (`~/.agents/skills`, `~/.zcode/skills`), and the ZCode global
   instructions for: `luna`, `gpt-6`, `sol-6`, `glm-5.3-flash`, `mimo.*flash`,
   `frontier`, `lower-tier`, `cheap/fast/budget/smaller model`, `tiering`. Every
   hit was incidental (plan files using the word "tier" for other things,
   vendor model docs inside the openai-docs system skill, the MiMo setup doc).
2. **The plan-quality half already exists.** The `implementation-plan-writer`
   skill and `templates/system/implementation-plan-standard.md` already demand
   exactly the spec quality a lower-tier implementer needs: zero questions,
   concrete files per step, per-step verification gates. The missing pieces are
   (a) the **routing rule** — who implements — and (b) the **verification duty**
   — who checks the lower tier's output.
3. **The ChatGPT template has the routing kernel but stale names.**
   `CHATGPT-codex-cost-efficient.md:44-55` routes implementation to a cheaper
   model "when the prompt has exact anchors and verification gates" — the right
   instinct — but predates GPT-Sol-6 / GPT-6 Luna naming and lives only inside
   the ChatGPT app context.
4. **Dispatch-path reality is unverified.** The three lower tiers are selectable
   in each client's interactive app, but the headless wrappers'
   model-selection support differs and is undocumented in one place. A sheet
   that says "hand off to Flash" without naming the exact command (or the
   documented manual fallback) will not be followed.
5. **Globals are near-identical variants of one document.** A rule added to one
   global must be added to all three in the same change, byte-identically —
   the same deliberate-duplication pattern as the six shared-db Cursor rules.

### 7. Approaches considered and REJECTED

- **Naming the implementer inside each implementation plan.** REJECTED by
  Albert, 2026-09-24: the model lineup rotates weekly (GLM reviewer paused
  2026-09-18, Kimi out and back, etc.), so implementer-named plans stale-date
  immediately. Routing authority lives in the globals + sheet only. Do not
  relitigate.
- **Three bespoke per-client routing sheets.** REJECTED: three competing copies
  drift apart silently. One canonical sheet; the globals carry only a short
  identical pointer block.
- **A second, "extra-detailed" plan tier used only for handoffs.** REJECTED in
  conversation 2026-09-24: two quality bars create ambiguity about which plan is
  "good enough." The single standard bar applies to every plan.
- **Building new wrapper flags (e.g. `--model glm-5.3-flash`) in this plan.**
  REJECTED for scope: this plan is prose-only so it lands as a docs PR with no
  checks wait; a wrapper change is code, needs its own tests and issue. Gaps
  found in Step 1 become new issues named in the sheet.
- **Letting the lower tier verify its own work.** REJECTED: the point of the
  frontier tier's judgment is the verification pass. The cheap model grading its
  own output against its own interpretation is how errors land silently.

### 8. Design decisions already made

- **LOCKED (Albert, 2026-09-24): plans are implementer-agnostic.** No
  implementation plan names its implementer. The routing rule lives in the
  three globals and the canonical sheet, nowhere else.
- **LOCKED (Albert, 2026-09-24): build it.** Instruction sheet + globals wiring
  approved in chat.
- **LOCKED (conversation, 2026-09-24): the frontier session keeps the
  verification duty.** It runs each step's gate on the lower tier's result
  before anything lands; a failed gate goes back to the lower tier once with
  the failing check quoted, and if it fails again the frontier session does the
  step itself.
- **OPEN (Step 1 decides): the exact dispatch command per harness.** Criteria:
  use an existing, supported selector if the wrapper/client has one; otherwise
  document the manual path (open the client's app, select the lower-tier model,
  hand it the plan file path) and file a gap issue. Never invent an unsupported
  flag.
- **OPEN (Step 4 decides): whether `CHATGPT-codex-cost-efficient.md` keeps its
  own Model routing section.** Criteria: keep it, refreshed to current model
  names and pointing at the sheet — fold it away only if it directly
  contradicts the sheet.

---

## Part 3 — How to build it

### 9. The steps

Single phase — the whole plan fits one session comfortably. Steps run in order;
none may start before the previous is marked done in STATUS.

**Step 1 — Verify the three lower-tier dispatch paths (read-only).**
For each harness, establish how a frontier session dispatches an implementation
task to its lower tier, without changing anything:

- Codex → GPT-6 Luna: check the installed Codex CLI's supported model selector
  (for example `codex exec --model …`; confirm against `codex --help` output on
  this machine) and whether Albert's ChatGPT plan exposes Luna headlessly.
- ZCode → GLM 5.3 Flash: read `bin/ai-zcode` end to end. Note its provider-env
  assembly (lines 25–28) and the default read-only tool disallow (line 68);
  determine whether a writable headless run with a specific model is supported
  today (env or flag). Do not modify the wrapper.
- MiMo → Mimo v2.6 flash: same treatment for `bin/ai-mimo`.

Record the verdict for each harness as one row of the dispatch table drafted in
Step 2 — exact command if supported, else the manual path (open the app, pick
the lower-tier model, hand it the plan path) plus a filed gap issue.
**You'll know it worked when:** each of the three rows names either a command
whose help output you quoted in the issue #782 comment, or a manual path plus a
gap issue number. Anything you could not prove stays "unverified" — never guess.

**Step 2 — Write `templates/system/model-tier-delegation.md`.**
The canonical instruction sheet, in the plain, imperative style of
`CHATGPT-codex-cost-efficient.md`. Required sections, exactly these seven:

1. **The rule** — frontier sessions plan, spec, and verify; mechanical
   implementation from a passing plan goes to the lower tier. Name the three
   harness pairs (frontier → lower) in a small table.
2. **Handoff checklist** — all must be true: the plan passes
   `templates/system/implementation-plan-standard.md`; every step has its
   verification gate; the remaining work is mechanical (named files, named
   edits); no step is on the do-not list below.
3. **Do-NOT-handoff list** — architecture or judgment calls, security review,
   cross-repo design, anything touching production or the shared database
   (shared-db work has its own governed route), ambiguous steps, trust-boundary
   work whose adversarial-cases table is missing, and any step whose gate the
   lower tier cannot run itself.
4. **The verification duty** — the frontier session runs every step's gate on
   the lower tier's result before landing; one retry quoting the failing check,
   then the frontier session implements the step itself; the frontier session
   owns the commit/PR either way.
5. **The implementer-agnostic rule** — plans never name their implementer; this
   sheet is the only routing authority; if a plan seems to require a specific
   implementer, that is a defect in the plan.
6. **Per-harness dispatch table** — the three verified rows from Step 1.
7. **Failure modes and responses** — lower tier skips a gate → re-run the gate
   quoted; improvises beyond scope → revert the extra edits, re-dispatch once;
   silently "improves" the plan → treat as a failed step, frontier implements.

**You'll know it worked when:** the file exists at
`templates/system/model-tier-delegation.md`, `grep -c '^## ' templates/system/model-tier-delegation.md`
returns 7, and each of the seven sections above is present by name.

**Step 3 — Add the identical routing block to the three globals.**
Add one short block (≤ 10 lines) as the last subsection of `## Owner and
execution` in each of `AGENTS-global-codex.md`, `AGENTS-global-zcode.md`,
`AGENTS-global-mimo.md`. The block must be **byte-identical in all three** and
say, in this shape: when you hold an implementation plan that passes the
standard and the remaining steps are mechanical, dispatch them to your
harness's lower tier per `templates/system/model-tier-delegation.md` (rule,
do-not list, dispatch commands, verification duty all live there); you keep the
verification duty; plans never name their implementer.
**You'll know it worked when:** `grep -l "model-tier-delegation" templates/system/AGENTS-global-*.md`
lists exactly the three files, and `diff <(sed -n '/^### /' ...) `-extracted
blocks match — simplest proof: extract the block from each file and `diff` the
three extracts pairwise; all empty.

**Step 4 — Point the two related templates at the sheet.**
- `CHATGPT-codex-cost-efficient.md`: refresh the `## Model routing` section's
  retired names (GPT-5.4/5.5/5.6) to the current frontier/lower naming and add
  one pointer line to the sheet.
- `implementation-plan-standard.md`: add one sentence where the zero-questions
  bar is stated: the bar exists so ANY session — including a lower-tier
  implementer chosen later — can execute the plan; plans never name their
  implementer; routing lives in `model-tier-delegation.md`.
**You'll know it worked when:** `grep -n "model-tier-delegation" templates/system/CHATGPT-codex-cost-efficient.md templates/system/implementation-plan-standard.md`
hits both files, and no retired "GPT-5.4" / "GPT-5.5" strings remain in the
ChatGPT template's routing section.

**Step 5 — Re-adopt the globals on edge-dev and verify.**
Run `bin/ai-adopt-globals` from the repo (it preserves machine sections), then
verify the installed copies carry the block.
**You'll know it worked when:** `grep -l "model-tier-delegation" ~/.codex/AGENTS.md ~/.zcode/AGENTS.md ~/.config/mimocode/AGENTS.md`
lists all three installed files. If `ai-adopt-globals` has a dry-run mode, run
it first and paste its output in the issue comment.

**Step 6 — Land it.**
One docs-only PR containing Steps 2–4's files plus this plan's updated STATUS
rows and the new `HANDOFF.d/` contract file. Add the router row to root
`AGENTS.md` in the `## Task router` table:
`| Frontier/lower-tier model routing, handoff policy | [Model-tier delegation plan](plan_model_tier_delegation.md) STATUS, [issue #782](https://github.com/popcre/ai-devops/issues/782) | Plans stay implementer-agnostic; frontier session verifies; no wrapper changes |`.
Because every changed file is prose, merge with `gh pr merge --squash --admin`
immediately per the standing docs-only rule. Then comment on issue #782 with
the merged SHA and where the next session starts, and update this STATUS table.
**You'll know it worked when:** `gh pr view <n> --json state,mergeCommit` shows
MERGED and the issue comment is posted with your signature.

### 10. Tests required

No new tests — every changed file is prose. The functional tests are the gates
inside Steps 2–5 (the greps and diffs are the tests; run them verbatim and paste
output into the issue comment). One existing suite must stay green if it runs on
this machine: `tests/test-ai-adopt-globals.sh` (it asserts on the globals
deployment the plan touches). The PR's own CI is the remaining gate.

### 11. Constraints, standing rules, and gotchas in force

- **Canonical checkout is landing-only.** Do all edits in your own worktree cut
  from `origin/main` (`git -C /c/repos/ai-devops worktree add …`), never in
  `C:\repos\ai-devops` directly. Two other sessions left untracked
  `HANDOFF.d/` files there on 2026-09-24 — do not touch them.
- **New `HANDOFF.d/` files need the contract block** (issue / status / owner
  fenced frontmatter) or the Handoff Contract Guard fails the PR. Delete the
  file only when this work is truly finished; never edit another session's.
- **Docs-only PRs merge immediately** (`gh pr merge --squash --admin`), no
  checks wait. If even one changed file is code, the normal checks apply — and
  that means this plan's scope was exceeded; stop and re-read §4.
- **Sign everything posted to GitHub**: `Posted by ZCode chat <id> on <machine>`
  (`$ZCODE_SESSION_ID`, or `unknown` when empty).
- **Human-facing times are EST/EDT, named** — e.g. `3:45 PM EDT`. Machine
  filenames stay UTC.
- **No secrets are involved.** If a step somehow needs one, stop; this plan
  needs none.
- **Never rename or edit the three globals' machine sections**;
  `ai-adopt-globals` preserves them — your template edits must not touch them.
- **Keep the three routing blocks byte-identical** — the deliberate-duplication
  pattern; a fourth divergent copy is the failure mode §7 rejected.
- **ASCII only** in any script file — no scripts are planned; if you add one,
  stop (scope).

### 12. Access and environment

- GitHub CLI authenticated as `u2giants`; repo `popcre/ai-devops`; parent issue
  **#782** (label `enhancement`).
- Machine: `edge-dev`, Windows, Git Bash. Worktree recipe:
  `git -C /c/repos/ai-devops fetch origin --prune` then
  `git -C /c/repos/ai-devops worktree add /c/repos/ai-devops/.claude/worktrees/model-tier-delegation -b docs/model-tier-delegation origin/main`
  (a worktree on this branch already exists from the planning session — reuse it
  if clean, else cut a fresh one and a fresh branch suffix).
- Task gate already declared for the planning session: class `prose`. Re-declare
  in your own worktree: `bin/ai-task-gates start --class prose --reason "…"`.
- No app to run, no URLs, no logins, no 1Password items.

---

## Part 4 — Landing it

### 13. Definition of done, risks, open questions

**Definition of done** (every item cites an artifact in the STATUS table):

- [ ] `templates/system/model-tier-delegation.md` on `main` with all seven
      sections, dispatch table carrying three verified rows.
- [ ] All three globals on `main` carry the byte-identical block (pairwise-diff
      proof pasted on #782).
- [ ] Both pointer templates updated; no retired model names in the ChatGPT
      template's routing section.
- [ ] Globals re-adopted on `edge-dev`; all three installed files grep-positive.
- [ ] PR merged (squash) with SHA on `main`; router row present in `AGENTS.md`.
- [ ] Issue #782 updated; every STATUS row done with evidence; the
      `HANDOFF.d/` file retired in the same PR that completes the work.

**Risks and rollback:** the whole change is prose + template text, one squash
commit — rollback is `git revert` of that commit plus one `ai-adopt-globals`
re-run. The real risks are (a) other machines keep stale globals until their
next `ai-adopt-globals` run (acceptable; adoption is routine maintenance) and
(b) frontier sessions ignore the rule — caught by the verification duty, since
an unverified lower-tier result cannot land.

**Open questions:** none blocking. Step 1 decides the dispatch commands under
its stated criteria; a discovered gap produces its own issue and the manual
fallback row, not a blocker here.

---

## Self-audit (mandatory gate — final answers preserved)

1. **Could a brand-new AI session execute this without asking anything?**
   Yes. §5 names every file with line numbers; §9 gives each step an exact
   insertion point, exact content requirements, and a runnable verification
   command; §12 gives the worktree recipe, issue number, and gate declaration;
   §7/§8 pre-answer the two judgment calls (implementer-naming, wrapper gaps)
   a session would otherwise ask about.
2. **Does the plan carry every piece of background and reasoning I hold?**
   Yes. The 2026-09-24 investigation findings and their search terms (§6), all
   five rejected approaches with their reasons (§7), Albert's two locked
   rulings with dates (§8), and the untracked-HANDOFF/landing-only gotchas
   (§11) are all recorded.
3. **Is the goal clear enough to steer by when a step is wrong?**
   Yes. §1 states the outcome in plain business English with the explicit
   "goal wins — stop and flag" instruction, and the do-not-handoff list in
   Step 2's sheet spec protects the quality half of the goal from a
   cost-only misreading.
