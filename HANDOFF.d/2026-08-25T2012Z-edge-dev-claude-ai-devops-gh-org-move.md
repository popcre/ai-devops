---
issue: 84
status: OPEN
owner: claude/ai-devops-gh-org-move
---

# HANDOFF — move `ai-devops` to the `popcre` GitHub org (2026-08-25 20:12 UTC, edge-dev/claude)

**The plan itself lives in [`fix_to_gh_org.md`](../fix_to_gh_org.md) at the repo
root. Read that first — this file is the session context around it.**

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put this whole list to Albert in **one message before starting work**. Do not
raise them one at a time as you trip over them.

### BLOCKING — work cannot finish without an answer

1. **Do the two private sibling repos move too?**
   `u2giants/ai-devops-memory` (portable memory hub) and
   `u2giants/ai-devops-transcripts` (session transcript archive) are both private
   and are both name-checked by this repo's scripts.
   **Recommendation: no — leave them where they are.** They are private, so an
   organization gains them no merge queue, and moving them multiplies the
   identity-check work for no benefit.
   *Blocks:* Phase A, because the allow-list is written differently depending on
   the answer. One word settles it.

### RECOVERABLE — a wrong guess is fixable but wastes rework

2. **Who should be able to read `ai-devops` inside `popcre`?**
   The org grants members **read** by default. Its members are `u2giants`,
   `devopswithkube` and `VaibhavBarot`. `VaibhavBarot` has no access today and
   would gain read on arrival. The repo is public, so nothing new is exposed —
   but it adds them to the repo.
   **Recommendation: set the repository permission explicitly rather than inherit
   the org default.**
   *Blocks:* nothing; adjustable afterwards.

3. **Timing of the transfer.** Phase A (the code change) is safe to do at any
   time. Phases C–E need a quiet moment when no other AI session is mid-push on
   `ai-devops`.
   **Recommendation: Albert says go when he is not running other sessions.**

### NOT PART OF THIS WORK, AND NOBODY IS ON IT

4. **The shared working copy at `C:\repos\ai-devops` is carrying another
   session's unfinished work.** As of 2026-08-25 20:12 UTC, local `main` was **3
   commits ahead** of `origin/main` (`90b21ea`, `6c6f255`, `b5f7c76`, all Grok
   locking/reservation fixes) and **6 behind**, with four modified files
   (`bin/ai-deepseek-agent`, `bin/ai-muse`, `tests/test-ai-deepseek-agent.sh`,
   `tests/test-ai-muse.sh`). Nobody in this session owns that work. It is
   unpushed, so it exists on this machine only and would be lost if the checkout
   were reset.
   **Recommendation: ask whichever session owns the Grok locking work to push or
   abandon it.** Not a blocker for this plan — this session deliberately worked
   from a separate worktree based on `origin/main` and never touched those files.

5. **There are 7 live git worktrees registered against `ai-devops`**, including
   two under `C:\Users\ahazan\AppData\Local\Temp\` and two detached-HEAD clones
   named `ai-devops-gemini-qualification-final`(`-v2`). Several look abandoned.
   **Recommendation: run the `cleanup-worktree` skill separately.** Out of scope
   here, and age alone is not proof any of them is safe to delete.

### Already settled — do NOT re-ask

- **Destination org is `popcre`** (Albert, 2026-08-25). `popcre` is **not**
  reserved for DesignFlow; older wording saying so is superseded.
- **Repos stay PUBLIC** (Albert, 2026-08-25). Public + free org = merge queue at
  no cost; private would require a paid Team plan.
- **The reason for the whole exercise** — GitHub only gives merge queues to
  org-owned repos — is settled and evidenced. Do not re-litigate it.

## 1. What this application is

`ai-devops` (`https://github.com/u2giants/ai-devops`, public) is Albert Hazan's
**AI operations and configuration hub** for POP Creations. It is not a customer
product. It holds the shell/PowerShell tooling in `bin/`, the machine bootstrap
and installer scripts, the shared AI reviewer wrappers (`ai-grok`, `ai-muse`,
`ai-deepseek-agent`, `ai-gemini`, `ai-kimi`, `ai-qwen`), the cross-tool
`templates/system/` standards (including `machine-atlas.md` and
`handoff-standard.md`), and the skills that other repos' AI sessions load.

Every workstation Albert uses clones this repo and installs from it. That is why
its identity checks matter: a machine bootstrapped from a look-alike fork would
be a serious compromise.

Two private siblings orbit it: `u2giants/ai-devops-memory` (portable memory hub)
and `u2giants/ai-devops-transcripts` (Claude session transcripts).

Stack: Bash + PowerShell scripts, one GitHub Actions workflow (`verify.yml`)
running on `ubuntu-24.04` and `windows-2025`. No server, no deployment, no
database.

## 2. What we set out to do this session, and why

Albert asked: *"we need to do this same thing for the ai-devops repo. Can you put
a plan to do that into fix_to_gh_org.md in the ai-devops repo and link to it from
Handoff?"*

"This same thing" refers to work done earlier in the same session for
`u2giants/shared-db`: planning its move to a GitHub organization so it can use
GitHub's **merge queue**, which is offered only to org-owned repositories.
`u2giants` is a personal account, so no repo under it qualifies. That constraint
was discovered while filing shared-db issue **#1435** (the merge-queue proposal),
and it is what triggered this whole line of work.

Objective for this session: **produce the plan, not execute it.** Nothing about
`ai-devops` has been transferred or changed beyond adding the plan document,
this handoff, and issue #84.

## 3. Current state — what is true right now

**Done and verified:**

- **Issue [#84](https://github.com/u2giants/ai-devops/issues/84) opened** in
  `u2giants/ai-devops`, carrying the rationale and acceptance criteria.
- **`fix_to_gh_org.md` written** at the repo root — the full plan, Phases A–E.
- **This handoff written.**
- **Full GitHub-side inventory of `ai-devops` taken** (see §5). Headline: there is
  effectively nothing to restore after a transfer.
- **The real hazard identified**: six fail-closed identity assertions in `bin/`
  that hard-code `u2giants` (see §5 and `fix_to_gh_org.md` §3).

**Committed / pushed:** this work is on branch
`claude/ai-devops-gh-org-move`, built in an isolated worktree at
`C:\repos\ai-devops-worktrees\gh-org-move`, based on `origin/main` (`f26d5eb`).
See §6 for whether it has merged by the time you read this — if
`fix_to_gh_org.md` exists on `main`, it did.

**Not started — all of it is the actual plan:** Phase A (parameterise the identity
assertions), Phase B (prove Windows runners in `popcre`), Phase C (the transfer),
Phase D (fresh-clone proof), Phase E (enable the queue, sweep references).

**Deliberately NOT done:** no code in `bin/` was touched, the repository was not
transferred, and no other session's files were staged.

## 4. Everything we tried that did NOT work

1. **Creating the working worktree under the session scratchpad failed on
   Windows path length.** `git worktree add` into
   `C:\Users\ahazan\AppData\Local\Temp\claude\C--repos-shared-db--claude-worktrees-…\scratchpad\aidevops-org-wt`
   aborted with `Filename too long` on ten files (the longest being
   `tests/verification/full-remediation/20260821T233700Z/step-04-instruction-closure.md`
   and `skills/shared/wb-starlabs-scrape/scripts/append_property_character_batch.test.mjs`),
   then `fatal: Could not reset index file to revision 'HEAD'`. The scratchpad
   prefix alone is ~150 characters, and this repo has deep paths.
   **It also left a half-registered worktree and a stray branch** that had to be
   cleaned with `git worktree prune` + `git branch -D`.
   **Fix that worked:** use the short, already-sanctioned path
   `C:\repos\ai-devops-worktrees\<name>`. Do the same — do not put an
   `ai-devops` worktree under the scratchpad.

2. **Reading the `popcre` org Actions policy directly failed** (earlier in the
   same session, while working on shared-db). `gh api orgs/popcre/actions/permissions`
   returns `403` because the local `gh` token lacks the `admin:org` scope. A
   `gh auth refresh -h github.com -s admin:org` was attempted and **did not take** —
   the token scopes were unchanged afterwards, and no `GH_TOKEN`/`GITHUB_TOKEN`
   environment variable was overriding it.
   **Do not chase that scope.** It turned out to be unnecessary — see §5.

3. **Assuming GitHub's URL redirect makes hard-coded owner strings harmless.**
   That reasoning is correct for `shared-db` and **wrong for `ai-devops`**. It was
   the initial assumption and inspection disproved it. See §5.

## 5. Root causes and key findings

**Finding 1 — `ai-devops` carries almost no GitHub-side state.** Verified
2026-08-25:

- `gh secret list -R u2giants/ai-devops` → empty
- `gh variable list -R u2giants/ai-devops` → empty
- `gh api repos/u2giants/ai-devops/environments` → none
- `gh api repos/u2giants/ai-devops/branches/main/protection` → `404 Branch not protected`
- collaborators: `u2giants` only
- workflows: `verify.yml` only

So unlike `shared-db` (8 secrets, 6 variables, 2 environments, 11 required
checks), **there is nothing to restore here.**

**Finding 2 — the risk is in this repo's own code, and the redirect does not
cover it.** Six fail-closed assertions hard-code the owner:

| File | Line |
|---|---|
| `bin/bootstrap-windows-dev.ps1` | 54, 120 |
| `bin/install-ai-devops-windows.ps1` | 105, 549 |
| `bin/ai-devops` | 109 (asserts `ai-devops-memory`) |
| `bin/ai-transcript-destination-check` | 18 (asserts `ai-devops-transcripts`) |
| `bin/ai-memory-sync` | 29, 51 (asserts `ai-devops-memory`) |

Git does **not** rewrite a clone's `origin` when it follows a redirect. So:

- machines already set up keep the string `u2giants/...` and keep passing —
  **hiding the breakage**;
- a fresh `git clone https://github.com/popcre/ai-devops.git` records
  `popcre/ai-devops`, the literal comparison fails, and **the installer aborts**.

The failure therefore surfaces only when a NEW machine is bootstrapped — the worst
possible moment. **This is why the code change must merge before the transfer**,
and why it must accept **both** owners rather than swap one for the other. A
straight swap would break every existing machine's doctor check immediately.

**Finding 3 — `popcre` does not restrict GitHub Actions, proven without the
`admin:org` scope.** `popcre/designflow-bff`, `popcre/designflow-frontend` and
`popcre/infrastructure` each report `allowed_actions: "all"` at the repository
level. GitHub does not permit a repository policy to be *less* restrictive than
its organization's, so a repo reading `"all"` is only possible if the org is
`"all"` too. That is conclusive.

**Finding 4 — third-party actions were additionally proven to run in `popcre`.**
A throwaway private probe repo, **`popcre/actions-policy-probe`**, run
**32892354687**, ran all 15 steps green including `supabase/setup-cli@v1`
(installed CLI 2.115.0), `docker/setup-buildx-action@v3`,
`docker/metadata-action@v5` and `actions/upload-artifact@v4`. That repo is
deliberately still alive as a known-good control; delete it once both transfers
are verified.
**Caveat this repo cares about:** the probe ran **Linux only**. `verify.yml` here
needs **`windows-2025`**, which is untested in `popcre`.

**Finding 5 — the local checkout is shared with other live sessions.** See §0
item 4. This session never worked in `C:\repos\ai-devops` directly for that
reason.

## 6. Exact next steps

0. **Put §0 to Albert in one message.** *You'll know it worked when* you have a
   yes/no on the sibling repos, which is the only true blocker.

1. **Confirm this handoff and `fix_to_gh_org.md` are on `main`.**
   ```
   gh api repos/u2giants/ai-devops/contents/fix_to_gh_org.md --jq .name
   ```
   *You'll know it worked when* that prints `fix_to_gh_org.md`. If it 404s, the
   PR from `claude/ai-devops-gh-org-move` did not merge — check
   `gh pr list -R u2giants/ai-devops --state all --head claude/ai-devops-gh-org-move`.

2. **Execute Phase A** from `fix_to_gh_org.md` §5: replace the six literals with
   one allow-list that accepts both `u2giants/ai-devops` and `popcre/ai-devops`,
   keeping the checks fail-closed, and add a test proving an unknown owner is
   still refused. *You'll know it worked when* `verify.yml` is green AND the new
   test proves both acceptance of `popcre` and rejection of e.g.
   `attacker/ai-devops`.

3. **Execute Phase B**: confirm a `windows-2025` job actually runs in `popcre`.
   Cheapest route is to add a Windows job to the existing
   `popcre/actions-policy-probe` repo. *You'll know it worked when* a Windows job
   in `popcre` completes green.

4. **Execute Phase C** (the transfer) only after step 2 has merged and no other
   session is mid-push. *You'll know it worked when* `gh repo view popcre/ai-devops`
   shows it PUBLIC and an old clone can still `git fetch`.

5. **Execute Phase D** — the proof that matters. Clone fresh from the `popcre`
   URL into a scratch directory, run `bin/ai-devops`; then run the doctor on an
   existing machine whose origin still says `u2giants`. *You'll know it worked
   when* **both** pass on the same commit.

6. **Execute Phase E**: enable the merge queue, then sweep documentation
   references and the four Claude skills. *You'll know it worked when* a PR can
   be added to a queue in the GitHub UI.

7. **Retire this handoff** when #84 closes — delete this file in the same PR.

## 7. Constraints and gotchas in force

- **Never rewrite the root `HANDOFF.md`.** It is a pointer file whose line 1
  carries `handoff-pointer: v1`. Linking "from Handoff" means adding a file under
  `HANDOFF.d/` — which is what this file is. Never edit another session's
  `HANDOFF.d/` file either.
- **`C:\repos\ai-devops` is shared with other live AI sessions.** Branch from
  `origin/main` in a separate worktree; stage only your own files; never
  `git add -A`; never rebase local `main`.
- **`ai-devops` local `main` routinely carries other sessions' unpushed commits.**
  Push via a branch and PR, never directly.
- **Do not put an `ai-devops` worktree under the session scratchpad** — Windows
  path length breaks it (§4.1). Use `C:\repos\ai-devops-worktrees\<name>`.
- **Albert does not merge — the session that opens a PR merges it.** Do not end a
  report asking him to click Merge.
- **Committer identity must be `Albert Hazan <u2giants@users.noreply.github.com>`.**
  Verify with `git var GIT_COMMITTER_IDENT` before the first commit in a repo.
- **The identity assertions must stay fail-closed.** Widening the allow-list by
  one entry is the goal; turning any check into a warning is a regression.
- **`gh pr merge` from a linked worktree can print `'main' is already used by
  worktree`.** That is local branch cleanup failing *after* a successful merge.
  Confirm with `gh pr view <n> --json state` before reporting a failure.

## 8. Access and environment

- **`gh` CLI:** authenticated as `u2giants`, token in the OS keyring. Scopes:
  `admin:public_key`, `gist`, `read:org`, `repo`, `workflow`. **`admin:org` is
  absent and is NOT needed** (§5, Finding 3). A refresh attempt did not take (§4.2).
- **Org role:** `u2giants` is an **admin/owner** of `popcre`, so the transfer is
  within reach without extra grants.
- **Machine:** `edge-dev` (Windows 11). Shell available as both PowerShell and
  Git Bash; this session used Git Bash.
- **Repo checkouts:** canonical clone `C:\repos\ai-devops` (shared, dirty);
  this work in `C:\repos\ai-devops-worktrees\gh-org-move` on branch
  `claude/ai-devops-gh-org-move`, based on `origin/main` `f26d5eb`.
- **Secrets:** none are needed for this work. `ai-devops` has no Actions secrets
  at all. Anything else lives in 1Password vault **`vibe_coding`** — reference by
  item, never by value.
- **Related artifacts elsewhere:** the shared-db restore sheet from the same
  session is at
  `…\scratchpad\transfer-inventory\RESTORE-PLAN.md` on `edge-dev`. It is a
  scratch file, not committed; if it matters to you, re-derive it rather than
  depend on it surviving.

## 9. Open questions and risks

- **RISK — `windows-2025` runners in `popcre` are unproven.** Everything else
  about the org's CI is evidenced; this is not. Mitigated by Phase B running
  before the transfer. Windows runners bill at 2× minutes, but `ai-devops` will be
  public in `popcre`, and public-repo minutes are free.
- **RISK — the identity change is security-sensitive.** These assertions exist to
  stop a machine being bootstrapped from a look-alike fork. The change must widen
  the allow-list by exactly one known-good entry and stay fail-closed. Reviewers
  should treat any softening as a defect.
- **RISK — the breakage is invisible until a new machine is set up.** If Phase A
  is skipped or done wrong, nothing fails until someone bootstraps a workstation,
  and then that workstation is unusable. Phase D step 5 exists precisely to catch
  this while someone is watching.
- **UNCERTAIN — how many machines exist and their clone URLs.**
  `templates/system/machine-atlas.md` is marked "protected source" and was not
  read in full (standing rule: read only the current machine's section). The
  count of affected workstations is therefore unknown. It does not change the
  plan — the both-owners-accepted design is safe at any machine count — but
  someone should confirm no machine has an unusual remote.
- **DECIDED 2026-08-25 — destination is `popcre`, public.** Do not revisit.
- **DECIDED 2026-08-25 — `admin:org` is not required.** Do not revisit.
- **DECIDED 2026-08-25 — code change lands BEFORE the transfer.** Reversing that
  order is what creates the flag-day described in §5.

---

## Self-audit (required by the handoff standard)

1. **Could a street-newcomer continue without asking a question?** Yes. §1 explains
   what the repo is with zero assumed knowledge; §2 gives the trigger; §5 names
   every file and line number of the hazard; §6 gives seven numbered steps each
   with a verification gate; §8 gives the exact branch, base commit and checkout
   paths.
2. **As effectively as this session can right now?** Yes. The two things that cost
   this session real time — the Windows path-length worktree failure and the
   `admin:org` dead end — are both written up in §4 with the fix, so they cost the
   next session nothing.
3. **Is every relevant detail present?** Yes: background (§1–2), current state
   with commit SHA and branch (§3), failures (§4), findings with `file:line` (§5),
   next steps with gates (§6), constraints (§7), access (§8), risks (§9).
4. **Would Albert see every decision he owns by reading only §0?** Checked by
   walking §1–§9 line by line. The sibling-repo question (§4 of the plan doc,
   §0.1), the `VaibhavBarot` access question (§0.2), the timing question (§0.3),
   the other session's unpushed Grok work (§3, §0.4) and the seven stale worktrees
   (§0.5) all appear in §0. The last two are outside this workstream and are in
   §0 precisely because nobody else is raising them.
