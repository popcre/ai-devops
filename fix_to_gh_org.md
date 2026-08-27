# fix_to_gh_org — move `ai-devops` to the `popcre` GitHub organization

**Issue:** [#84](https://github.com/u2giants/ai-devops/issues/84)
**Written:** 2026-08-25 (edge-dev / claude)
**Status:** **Phases A–E DONE** (2026-08-26). The repository **has been
transferred** and now lives at `popcre/ai-devops`, public. Phase D proved there is
no flag-day. The merge queue is live. Only Phase F remains.

---

## 1. Why we are doing this

GitHub's built-in **merge queue** — the feature that puts concurrent pull requests
into a single ordered line, brings each one up to date, tests it and merges it
without anyone racing for a slot — is offered **only to repositories owned by a
GitHub organization**. `u2giants` is a personal account. No repository under it can
ever have a merge queue, no matter the plan.

This was discovered while planning the same move for `u2giants/shared-db` (that
repo's issue **#1435** documents the cost of not having a queue: one small change
took five attempts, three burned migration slots, four paid external reviews and
about nine hours, with the code unchanged after the first approval).

Albert's decision, 2026-08-25: the destination organization is **`popcre`**, and
repos stay **public**. `popcre` is *not* reserved for DesignFlow — that older
wording is superseded.

**Public + free organization = merge queue at no cost.** A private repo in a free
org does not get one; that needs a paid Team plan.

---

## 2. Why `ai-devops` is NOT the same job as `shared-db`

This is the single most important thing on this page. Do not reuse the shared-db
runbook here — the difficulty is in the opposite place.

| | `shared-db` | `ai-devops` |
|---|---|---|
| Actions secrets | 8 | **0** |
| Actions variables | 6 | **0** |
| Environments | 2 | **0** |
| Branch protection | 11 required checks, admins enforced | **none at all** |
| Workflows | 28 | 1 (`verify.yml`) |
| Collaborators | 2 | 1 (`u2giants`) |
| Hard-coded self-identity checks | none | **6 sites, fail-closed** |

**There is nothing to restore after transferring `ai-devops`.** No secrets to
re-add, no variables, no environments, no protection rules to rebuild. Verified
2026-08-25 via `gh secret list`, `gh variable list`,
`gh api repos/u2giants/ai-devops/environments` and
`gh api repos/u2giants/ai-devops/branches/main/protection` (which returns
`404 Branch not protected`).

**The entire risk is inside this repository's own code.**

---

## 3. The actual hazard: fail-closed identity assertions

`ai-devops` is the configuration hub that every workstation clones and installs
from. To stop a machine being bootstrapped from a look-alike fork, several scripts
**assert the repository's canonical GitHub identity and abort if it does not
match**. Those assertions name `u2giants` as a literal string.

Confirmed sites (2026-08-25):

| File | Line | Asserts |
|---|---|---|
| `bin/bootstrap-windows-dev.ps1` | 54 | origin remote `== github.com/u2giants/ai-devops` |
| `bin/bootstrap-windows-dev.ps1` | 120 | `$RepoUrl` `== github.com/u2giants/ai-devops` |
| `bin/install-ai-devops-windows.ps1` | 105 | `$expectedIdentity = 'github.com/u2giants/ai-devops'` |
| `bin/install-ai-devops-windows.ps1` | 549 | throws `Noncanonical RepoUrl` |
| `bin/ai-devops` | 109 | private memory hub origin `== github.com/u2giants/ai-devops-memory` |
| `bin/ai-transcript-destination-check` | 18 | origin `== github.com/u2giants/ai-devops-transcripts` |
| `bin/ai-memory-sync` | 29, 51 | memory remote `== github.com/u2giants/ai-devops-memory` |

### Why GitHub's redirect does NOT save us

GitHub permanently redirects the old repository URL, and that covers `git fetch`,
`git push`, `git clone` and the web. It is why the shared-db plan can be relaxed
about hard-coded paths. **It does not help here**, for two distinct reasons:

1. **Existing clones keep the old remote string.** Git does not rewrite
   `origin` when it follows a redirect. So machines already set up will keep
   asserting `u2giants/...` successfully and appear fine — hiding the problem.
2. **A fresh clone from the new URL records the NEW string.** `git clone
   https://github.com/popcre/ai-devops.git` sets origin to `popcre/ai-devops`,
   the assertion compares it to the literal `u2giants/ai-devops`, and the
   installer **aborts**.

The failure therefore appears **only when a new machine is set up**, which is
exactly when nobody is watching and the machine is unusable. That is why the code
change must land *before* the transfer, not after.

### The ordering rule this creates

> **Parameterise the identity assertions and merge them to `main` BEFORE
> transferring the repository.** The new code must accept BOTH the old and the new
> owner during the changeover, so there is no moment where either a pre-transfer
> or a post-transfer clone is rejected.

Making them accept both — rather than swapping `u2giants` for `popcre` — is what
removes the flag-day. A straight swap would break every existing machine's doctor
check the instant it merged, before the transfer had even happened.

---

## 4. The two private sibling repositories

`ai-devops` references two private siblings that are **not** part of this move
unless Albert says so:

- `u2giants/ai-devops-memory` (PRIVATE) — the portable-memory hub
- `u2giants/ai-devops-transcripts` (PRIVATE) — session transcript archive

Both are asserted by the scripts above. **Recommendation: leave both under
`u2giants` for now.** They are private, so moving them into a free org gains no
merge queue, and moving them multiplies the identity-assertion surface for no
benefit. The parameterisation in §5 must therefore keep working with siblings
that stay put — which it does, since each repo's accepted owners are configured
independently.

**DECIDED 2026-08-25 (Albert): no — both private siblings stay under
`u2giants`.** Phase A implements exactly that: their keys in
`config/repo-identities.tsv` accept `u2giants` only, and a test proves a
`popcre`-owned sibling is refused. Do not re-ask.

---

## 5. Execution plan

### Phase A — code first (safe, reversible, no downtime)

> **DONE 2026-08-25.** What actually shipped is recorded under this list.

1. Introduce a single source of truth for accepted repository identities, e.g. a
   small table in one place that each script reads, rather than six literals.
2. For `ai-devops`, accept **both** `github.com/u2giants/ai-devops` and
   `github.com/popcre/ai-devops`.
3. For `ai-devops-memory` and `ai-devops-transcripts`, accept `u2giants` only
   (unless §4 is decided otherwise), so nothing about them changes.
4. Keep the checks **fail-closed**: an unrecognised owner must still abort. The
   point is to widen the allow-list by exactly one entry, never to weaken the
   guard. A change that turns any of these into a warning is a regression and
   must be rejected in review.
5. Add a test asserting that a `popcre`-owned origin is accepted and that a
   third-party owner (e.g. `attacker/ai-devops`) is still refused.
6. Open a PR, get `verify.yml` green, merge to `main`.

*You will know Phase A worked when:* `verify.yml` passes, and the new test proves
both that `popcre` is accepted and that an unknown owner is still rejected.

#### What Phase A actually shipped

- **`config/repo-identities.tsv`** — the single source of truth. `ai-devops`
  lists both `github.com/u2giants/ai-devops` and `github.com/popcre/ai-devops`;
  `ai-devops-memory` and `ai-devops-transcripts` list `u2giants` only.
- **`bin/ai-repo-identity`** (Bash) and **`bin/repo-identity.ps1`**
  (dot-sourced PowerShell) read that table. Both refuse an unlisted identity,
  and both refuse *everything* when the table is missing or empty. The Bash
  helper exits **2** on a broken table and **1** on an ordinary refusal, so a
  caller can never mistake "cannot read the allow-list" for "not the public
  repo".
- **Rewired guards:** `bin/bootstrap-windows-dev.ps1` (both sites),
  `bin/install-ai-devops-windows.ps1` (both sites), and
  `bin/ai-sync-memory`'s public-hub guard.
- **A seventh site the plan did not list:** `bin/ai-sync-memory` refuses to use
  the public `ai-devops` repo as a private memory hub. Its owner check was
  *inverted* — hard-coding `u2giants` there would have silently **permitted**
  publishing private memory into a `popcre`-owned clone. It now reads the same
  allow-list, so every accepted `ai-devops` identity is rejected as a hub.
- **The sibling guards were deliberately left literal.**
  `bin/ai-facts`, `bin/ai-devops`, `bin/ai-memory-sync` and
  `bin/ai-transcript-destination-check` still compare literals, because their
  values do not change in this move and several of them are installed as
  symlinks on Ubuntu, where adding a runtime lookup is avoidable risk. Drift is
  prevented instead by a test that fails if any `github.com/*/ai-devops*`
  literal in `bin/` is absent from the table — so the table stays authoritative
  and nobody can add an eighth literal unnoticed.
- **Tests:** `tests/test-ai-repo-identity.sh` (29 checks) and
  `tests/test-repo-identity.ps1` (12 checks). Both suites auto-register with
  `tests/test-all.sh` / `tests/test-all.ps1`.
- **Docs:** `docs/config-inventory.md` gains a "Repository identity allow-list"
  section. `docs/restore-from-zero.md` now says to clone before running the
  Windows bootstrap — the bootstrap reads the allow-list from the checkout, so
  it is no longer supported as a lone saved file. That was always the README's
  documented path; the restore doc had drifted.

### Phase B — prove the org tolerates this repo's CI

> **DONE 2026-08-26.** Evidence recorded under this list.

7. `verify.yml` uses only `actions/checkout` (pinned to SHA
   `11d5960a326750d5838078e36cf38b85af677262`) and runs on `ubuntu-24.04`,
   `windows-2025`.
8. `popcre`'s Actions policy is already known to be **"allow all actions"** —
   established 2026-08-25 by observing that `popcre/designflow-bff`,
   `popcre/designflow-frontend` and `popcre/infrastructure` each report
   `allowed_actions: "all"`, which GitHub only permits when the org policy is
   itself "all". Third-party actions were additionally proven to run there by a
   throwaway probe repo (`popcre/actions-policy-probe`, run `32892354687`,
   all 15 steps green).
9. **`windows-2025` runners are the one untested thing.** The probe used Linux
   only. Windows runners bill at **2× minutes** and this repo would be **public**
   in `popcre`, so public-repo minutes are free — but confirm the org has not
   disabled Windows runners before relying on it.

*You will know Phase B worked when:* a Windows job in `popcre` completes green.

#### Phase B evidence

`windows-2025` **runs in `popcre`. Proven, not assumed.**

- Workflow `.github/workflows/windows-probe.yml` added to the existing throwaway
  repo **`popcre/actions-policy-probe`** (commit `3eca5bb`). It mirrors what
  `ai-devops` `verify.yml` needs on Windows.
- Run **[32964936717](https://github.com/popcre/actions-policy-probe/actions/runs/32964936717)**,
  2026-08-26 11:45 UTC. The GitHub API reports the job's labels as
  **`["windows-2025"]`** — that is the confirmation that matters, not merely a
  green tick.
- All six steps green: pinned `actions/checkout`, runner identity, **`jq` present
  on the image**, **Git Bash executes a Bash suite**, result. Job ran 14 seconds.

That closes the only unevidenced assumption behind the transfer. The probe repo
is deliberately still alive as a known-good control; delete it once the transfer
is verified.

### Phase C — the transfer (minutes)

10. Confirm no open PRs and no running workflows on `u2giants/ai-devops`.
    **Note:** at the time of writing the shared working copy at `C:\repos\ai-devops`
    had 3 unpushed commits and 4 modified files belonging to another session. A
    transfer does not touch a local clone, but do not transfer while another
    session is mid-push — its push would land during the changeover.
11. Transfer `u2giants/ai-devops` → `popcre/ai-devops`, keeping it **public**.
12. Confirm nothing needs restoring (per §2 there is nothing) — but re-run the
    four inventory commands afterwards to prove it rather than assume it.
13. Decide `popcre` repo access. The org's default repository permission is
    **read**, and its members are `u2giants`, `devopswithkube`, `VaibhavBarot`.
    `VaibhavBarot` would gain read on arrival. The repo is public so this exposes
    nothing new, but set the permission deliberately.

*You will know Phase C worked when:* `gh repo view popcre/ai-devops` returns the
repo as PUBLIC and `git fetch` from an old clone still succeeds via redirect.


#### Phase C evidence

> **DONE 2026-08-26.** Albert gave the go after being shown the pre-flight.

- **Pre-flight (step 2 of the handoff):** local `main` in `C:eposi-devops` had
  **no unpushed commits** — the one non-recoverable risk, and it was clear. Seven
  modified files and one untracked file belonged to another session; a transfer
  does not touch a local clone, so they were left alone. Six `verify` runs were
  in flight and three `push` events had landed on `main` in the preceding 30
  minutes (those are squash-merges, which register as pushes). Albert was shown
  this and said go.
- **Pre-transfer inventory re-run:** 0 secrets, 0 variables, 0 environments,
  `404 Branch not protected`, one collaborator (`u2giants`). Confirms §2.
- **Transfer executed** via `gh api -X POST repos/u2giants/ai-devops/transfer
  -f new_owner=popcre`. GitHub processes this asynchronously and echoes the old
  name in the response; `gh api repos/u2giants/ai-devops --jq .full_name`
  returned **`popcre/ai-devops`** on the first poll.
- **Gates met:** `gh repo view popcre/ai-devops` reports `visibility: PUBLIC`,
  `isInOrganization: true`, default branch `main`. An existing clone whose
  `origin` still reads `github.com/u2giants/ai-devops.git` **fetched
  successfully** through the redirect. Issue **#84 kept its number**.
- **Post-transfer inventory is identical** to pre-transfer: 0 secrets, 0
  variables, 0 environments, `404 Branch not protected`. **Nothing needed
  restoring**, exactly as §2 predicted.
- **Step 13 (repo access) is settled:** Albert removed `VaibhavBarot` from the
  org entirely before the transfer. Remaining members are `u2giants` and
  `devopswithkube`, both org owners, so the org default grants nothing to a
  third party and no explicit repository permission was needed.

### Phase D — prove it on a real machine

14. Clone fresh from `https://github.com/popcre/ai-devops.git` into a scratch
    directory and run `bin/ai-devops` (the doctor). It must pass.
15. Run the Windows installer's identity check against the new URL. It must pass.
16. Run the doctor on an **existing** machine whose `origin` still says
    `u2giants`. It must also still pass — this is the check that proves we did
    not create a flag-day.

*You will know Phase D worked when:* the doctor passes from BOTH a new-URL clone
and an old-URL clone, on the same commit.


#### Phase D evidence

> **DONE 2026-08-26.** Both directions proven on the same commit, `e92e6dc`.

**Step 14 — new-URL clone.** A fresh `git clone
https://github.com/popcre/ai-devops.git` records `origin` as `popcre/ai-devops`.

**Step 16 — old-URL clone.** A fresh clone from the *old* URL still records
`origin` as `u2giants/ai-devops` (git keeps the URL you typed, it does not
rewrite it on a redirect) — which is exactly the state of every machine already
set up. Pinned to the same commit.

**The controlling comparison.** `bin/ai-devops doctor` produced **byte-identical**
output from both clones at `e92e6dc` (verified by `diff` after stripping ANSI
colour). The move changed nothing.

> **Read this before repeating the test.** The doctor exits **1** on this Windows
> workstation, from *both* clones. Every failing check is an *installed-machine*
> path (`/worksp/ai-devops`, `/etc/ai-devops/models.env`, install manifest) that
> only exists on a Linux-installed host. **None of them is identity-related**, and
> the failures are identical on both sides. Do not read that exit code as a Phase
> D failure — the equality of the two outputs is the evidence, not the exit code.

**Step 15 — the installer source gate.** `install-ai-devops-windows.ps1` takes a
`-SourceGateOnly` switch that runs the identity gate and changes nothing:

| Clone `origin` | Result |
|---|---|
| `github.com/popcre/ai-devops` | **Source gate passed** |
| `github.com/u2giants/ai-devops` | **Source gate passed** |
| `github.com/attacker/ai-devops` | **Refused**, exit 1: `Noncanonical ai-devops origin: ... (accepted: github.com/u2giants/ai-devops, github.com/popcre/ai-devops)` |

The hostile case is the one that matters: the guard is still **fail-closed**. An
earlier attempt at this negative control passed a bad value to `-RepoUrl` and
wrongly reported a pass — with an existing `-RepoPath` the gate reads `origin`,
**not** `-RepoUrl`. Set the clone's actual `origin` to the hostile value.

**Suites re-run from the `popcre` clone:** `tests/test-ai-repo-identity.sh`
**29/29**, `tests/test-repo-identity.ps1` **12/12**.

**A false alarm, recorded so nobody re-raises it.**
`install-ai-devops-windows.ps1:109` still compares against a hard-coded
`$expectedIdentity` and looks like a leftover flag-day bug sitting *before* the
allow-list call at `:111`. It is not — it is inside an
`AI_DEVOPS_INSTALL_TEST_MODE -eq '1'` branch. The production path uses the
allow-list.

### Phase E — merge queue and cleanup

17. Enable the merge queue on `popcre/ai-devops`.
18. Sweep the remaining `u2giants/ai-devops` references in documentation
    (567 occurrences across the repo as of 2026-08-25, the vast majority prose in
    `docs/`, `templates/` and `HANDOFF.d/`). These work via redirect and are not
    urgent, but they should not be left depending on a forwarding address forever.
    **Do not bulk sed `HANDOFF.d/`** — those are other sessions' write-once files.
19. Update the four Claude skills that name the repo:
    `sync-dotfiles`, `claude-transcript-backup`, `grok-cli`,
    `kimi-code-delegation` (in `C:\Users\ahazan\.claude\skills\`).


#### Phase E progress

**Step 17 has a prerequisite the plan did not name: `verify.yml` had no
`merge_group:` trigger.** GitHub only runs a workflow against a queued merge
group if the workflow subscribes to that event. Enabling the queue first would
have produced a queue that accepts pull requests and then waits forever for
checks that never start. The trigger is added in this change and must be on
`main` **before** the queue is switched on.

**Step 18 — the sweep is surgical, never a bulk `sed`.** 27 references were
rewritten across 19 files: the clone URLs and installer defaults that decide
where a new machine actually clones from (`README.md`, `bin/setup-machine.ps1`,
`bin/bootstrap-windows-dev.ps1`, `bin/install-ai-devops-windows.ps1`,
`docs/restore-from-zero.md`, `docs/development.md`,
`docs/codex-skills-usage-guide.md`,
`templates/prompts/install-ai-devops-windows-codex.md`), plus live identity
prose in `AGENTS.md`, `templates/system/`, `docs/windows-winget-configuration.md`
and five `SKILL.md` files.

**What was deliberately left as `u2giants`, and why — do not "finish" this:**

- `config/repo-identities.tsv` — the old owner is an *intended* allow-list entry.
  Removing it recreates the flag-day this whole plan exists to prevent.
- **All of `tests/`** — several suites assert that the old owner is still
  accepted. Rewriting them would delete the regression test for the move.
- **Every `ai-devops-memory`, `ai-devops-transcripts` and
  `ai-devops-private-config` reference** — those repositories did not move.
- **`HANDOFF.d/`, `plan_*.md`, and dated incident/audit/verification documents**
  — write-once records of what was true when they were written.

These all resolve through GitHub's redirect, so nothing is broken by leaving
them.

#### Phase E completion — the merge queue is live

**DONE 2026-08-26.** Ruleset **`main: pull request + merge queue`** (id
`21564317`) is `active` on `popcre/ai-devops`. A second, pre-existing ruleset
`Protect main history` (id `21183703`) supplies `deletion` and
`non_fast_forward` and was left alone.

| Setting | Value |
|---|---|
| `merge_method` | `SQUASH` (matches existing practice) |
| `grouping_strategy` | `ALLGREEN` |
| `max_entries_to_build` / `max_entries_to_merge` | 5 / 5 |
| `min_entries_to_merge` | 1 (a solo PR never waits for a second) |
| `min_entries_to_merge_wait_minutes` | 0 |
| `check_response_timeout_minutes` | **120** |
| required approvals | 0 (sessions self-merge) |
| **required checks** | **`linux-offline` + `windows-offline` only** |

`check_response_timeout_minutes` must exceed `windows-offline`'s 75-minute
`timeout-minutes` **plus** runner-queue wait. Too low and a healthy 70-minute job
that waited 20 minutes for a runner is declared failed, requeued and rebuilt — a
retry storm. 120 gives 75 + ~45 minutes of margin.

**One default had to be turned off.** GitHub set
`require_extra_approval_for_unattributed_changes: true` on the `pull_request`
rule without being asked. With 0 required approvals that can still demand an
approval for commits it considers unattributed — and every commit here carries a
`Co-Authored-By` trailer. It is now `false`. Left on, it would have silently
blocked self-merges.

##### Why `windows-reviewer-safety` is NOT a required check

This was reviewed by GLM (`glm-5.3`) and the reasoning it produced overturned
the two options that were on the table. **Verified independently before
acting**, so do not undo it on intuition:

- `windows-reviewer-safety` runs exactly `tests/test-ai-codex-review.sh` and
  `tests/test-ai-grok-review.sh` through Git Bash (`verify.yml`, "Focused
  Windows reviewer safety suites").
- `windows-offline` runs `tests/test-all.ps1`, which invokes `tests/test-all.sh`,
  which **auto-discovers every `tests/test-*.sh`** (`test-all.sh:6`, a `find`
  glob) — including both of those, on the same `windows-2025` runner through the
  same Git Bash.

So `windows-reviewer-safety` is a strict **subset** of `windows-offline`.
Requiring it adds failure surface and **zero** coverage. It stays in the
workflow as a fast early signal; it is simply not required.

**The corollary matters more than the decision.** Both flaky suites from issue
**#89** are inside `windows-offline` via that same glob, so they are in the
required path **under every possible configuration**. Excluding
`windows-reviewer-safety` does *not* dodge the flake — an earlier draft of this
plan assumed it did, and that was wrong. The only thing that actually removes
the risk is fixing them, which is Phase F.

A flake costs **latency, not a deadlock**: a failed batch returns its entries to
the queue and retries. Do not respond to a first flake by stripping required
checks; re-queue.

##### Traps to guard — these block the queue SILENTLY

1. **Required checks are matched by check-run name.** These three job names are
   frozen. Renaming a job — or the workflow's `name:` — leaves a permanently
   "expected" check that never reports, with no error pointing at the stale name.
   Change a name and the ruleset in the same commit.
2. **Any workflow contributing a required check MUST subscribe to `merge_group:`.**
   That was the bug fixed in this phase; the next workflow anyone adds will
   reintroduce it.
3. **Do not add `paths:` / `paths-ignore:` / `branches:` filters or `if:` skips to
   a required job.** A required check filtered out of a merge group parks the
   queue until `check_response_timeout_minutes` expires. `pull_request:` and
   `merge_group:` are deliberately bare — keep them bare.
4. **No job matrices.** Matrix-expanded check names multiply every trap above.

##### MEASURED 2026-08-26 EVENING — the queue did not converge, and why

**This is the most important paragraph in this section. Read it before changing
anything about the queue.**

Pull request #104 was queued at **position 1**, `AWAITING_CHECKS`, and **never
merged on its own**. It was dequeued and merged directly instead.

What happened, from the run and commit records:

- Only **three** `merge_group` builds have ever completed on this repository, all
  for one pull request.
- Meanwhile `main` received commits at **18:26, 18:37, 18:51 and 18:54 UTC** that
  produced **no** completed `merge_group` build — they did not go through the
  queue.
- Each of those advanced `main`, which **invalidates the queued pull request and
  rebuilds its merge group from scratch**. Four ~65-minute Windows builds for the
  same pull request were running **concurrently** at one point, because superseded
  merge-group builds are **not** cancelled (Finding 4 above, now observed rather
  than predicted).

**The mechanism, stated plainly: a required check that takes longer than the
interval between bypassed merges can never finish.** The queued entry is reset
every time someone merges around the queue. It is not a deadlock and not a flake —
the entry stays healthy at position 1 forever.

**The cause is the `OrganizationAdmin` bypass actor**, added earlier the same day
(§5 Finding 8). It was necessary: without any bypass actor **nothing could merge
at all**, not even a one-file documentation change, because a ruleset ignores
`--admin` entirely. So both settings are individually justified and jointly
unusable:

| Bypass actor | Consequence |
|---|---|
| **absent** | nothing can merge until a 64-minute job finishes; `--admin` does not help |
| **present** | anyone using it starves every pull request that uses the queue |

**Neither is the real problem.** Both are downstream of `windows-offline` taking
~64 minutes. Shorten that job and both symptoms disappear — which is exactly
issue **#98**. Do **not** "fix" this by removing the bypass actor, and do not
conclude the merge queue was a mistake; the queue caught a genuine collision the
same afternoon (another session had edited `tests/test-ai-repo-identity.sh`
concurrently, and a blind merge would have risked reverting it).

Until #98 lands, expect to dequeue and merge directly. Re-verify a clean merge
against the current `main` first — that is the protection the queue would have
given you.
##### The practical cost, stated plainly

Every PR now runs `windows-offline` (~62 min) **twice** — once on
`pull_request`, once on `merge_group` — plus a third full run on `push: main`.
Open-to-merged is roughly **2–2.5 hours even with an empty queue**. Sessions
that previously opened and merged a PR within minutes must not sit polling for
hours; that is a workflow change, not a settings knob.

Note also that `verify.yml`'s `concurrency` group keys on event name + SHA, so
superseded merge-group builds are **not** cancelled (a new merge commit is a new
SHA). Queue churn therefore leaves ~62-minute orphan builds consuming runner
slots.
### Phase F — the flaky reviewer suites (AFTER the move is fully done)

**Do not start this until Phases A–E are complete and the transfer is verified.**
Albert's sequencing, 2026-08-26.

20. Work issue **[#89](https://github.com/u2giants/ai-devops/issues/89)** per
    [`fix_test_ai.md`](fix_test_ai.md): `tests/test-ai-grok-review.sh` and
    `tests/test-ai-kimi.sh` assert on wall-clock timing and fail intermittently
    on a loaded machine while passing in CI.

**Why it is last, not first.** It is real and it is not urgent: CI is green, so
it blocks nothing, and the org move has an irreversible step in the middle that
deserves undivided attention. It is queued here rather than left loose so it
cannot be forgotten — a flaky suite nobody is assigned to becomes a suite
everybody ignores.

**Why it belongs to this plan at all.** After the transfer, these suites are the
ones that would tell you whether the reviewer wrappers still work from a
`popcre`-owned clone. Fixing them last means the noise is gone before anyone has
to trust them again.

*You will know Phase F worked when:* both suites pass 10 consecutive local runs
**on a loaded machine**, still fail when their guarded defect is reintroduced,
CI stays green, and the check counts are unchanged or higher (191 Grok, 203
Kimi).

---

## 5b. Carried forward when this plan's handoff was retired

These were in `HANDOFF.d/2026-08-26T1149Z-...-gh-org-move.md` §0 as "not part of
this work, and nobody is on it". That file is deleted with issue #84, so they are
preserved here rather than lost. **Neither belongs to this plan; both still need
an owner.**

1. **The shared working copy `C:\repos\ai-devops` carries another session's
   uncommitted work.** As of 2026-08-26 13:00 UTC: seven modified files
   (`bin/ai-deepseek-agent`, `bin/ai-muse`, `docs/muse-opencode.md`,
   `plan_reviewer-cache-efficiency.md`, `tests/test-ai-deepseek-agent.sh`,
   `tests/test-ai-muse.sh`, and one `HANDOFF.d/` file) plus one untracked Codex
   handoff. Local `main` had **no** unpushed commits, which is why the transfer
   was safe. This is the reviewer-cache workstream; nobody in the move sessions
   ever owned those files and none of them was touched.
2. **Live git worktrees registered against `ai-devops`**, several apparently
   abandoned, including two under `C:\Users\ahazan\AppData\Local\Temp\` and two
   detached-HEAD clones named `ai-devops-gemini-qualification-final`(`-v2`).
   **Recommendation: run the `cleanup-worktree` skill in its own session.** Age
   alone is not proof any of them is safe to delete.

## 6. What will NOT break

Established by inspection on 2026-08-25, so a later session does not re-derive it:

- **Existing clones on every machine.** GitHub's redirect covers fetch/push/clone
  indefinitely, and the identity assertions still see the old string (see §3).
- **CI.** One workflow, one first-party action, pinned by SHA.
- **Issues and PRs.** Numbers, comments, labels and history all transfer intact.
  Issue #84 stays #84.
- **Secrets/variables/environments.** There are none.
- **Cross-repo automation.** Nothing dispatches into `ai-devops`.

---

## 7. Rollback

The transfer is reversible: transfer the repository back to `u2giants` the same
way. The Phase A code change is deliberately additive (both owners accepted), so
it does not need reverting and is safe to leave in place either way.

---

## 8. Open decisions for Albert

Consolidated here and repeated in the handoff's section 0.

1. ~~**Move the two private sibling repos too?**~~ **DECIDED 2026-08-25: no.**
   Both stay under `u2giants`. Implemented in Phase A. Do not re-ask.
2. **`VaibhavBarot` read access** on arrival in `popcre`. Recommendation: set
   shared repo permission explicitly rather than inherit the org default.
3. **Timing.** ~~Phase A is safe now.~~ Phase A is done. Phases C–E still need a
   quiet moment when no other session is mid-push on `ai-devops`.
