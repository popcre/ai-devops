# fix_to_gh_org — move `ai-devops` to the `popcre` GitHub organization

**Issue:** [#84](https://github.com/u2giants/ai-devops/issues/84)
**Written:** 2026-08-25 (edge-dev / claude)
**Status:** **Phases A and B DONE** (2026-08-26). Phases C–E not started; the
repository has **not** been transferred. Phase C is the first irreversible step
and needs Albert to say go.

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

### Phase D — prove it on a real machine

14. Clone fresh from `https://github.com/popcre/ai-devops.git` into a scratch
    directory and run `bin/ai-devops` (the doctor). It must pass.
15. Run the Windows installer's identity check against the new URL. It must pass.
16. Run the doctor on an **existing** machine whose `origin` still says
    `u2giants`. It must also still pass — this is the check that proves we did
    not create a flag-day.

*You will know Phase D worked when:* the doctor passes from BOTH a new-URL clone
and an old-URL clone, on the same commit.

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
