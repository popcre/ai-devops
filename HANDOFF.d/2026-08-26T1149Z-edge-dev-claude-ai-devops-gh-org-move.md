---
issue: 84
status: OPEN
owner: claude/org-move-phase-b
---

# HANDOFF — move `ai-devops` to the `popcre` GitHub org (2026-08-26 11:49 UTC, edge-dev/claude)

**The plan itself lives in [`fix_to_gh_org.md`](../fix_to_gh_org.md) at the repo
root. Read that first — this file is the session context around it.**

**Phases A and B are DONE. Phase C is the transfer and it is the first
irreversible step — it needs Albert to say go.**

This file **supersedes and retires**
`HANDOFF.d/2026-08-25T2012Z-edge-dev-claude-ai-devops-gh-org-move.md`, deleted in
the same commit. Everything still open from it — every owner decision, every dead
end, every constraint — is carried forward below. Nothing was dropped.

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put this whole list to Albert in **one message before starting work**. Do not
raise them one at a time as you trip over them.

### BLOCKING — work cannot start without an answer

1. **Go / no-go on the transfer itself, and when.**
   Phase C moves `u2giants/ai-devops` to `popcre/ai-devops`. It is the first
   irreversible action in this plan. It is reversible *in principle* (transfer
   back the same way) but it changes the canonical URL for every machine Albert
   owns, and it must not happen while another AI session is mid-push on
   `ai-devops`.
   **Recommendation: Albert names a quiet moment when he is not running other
   sessions.** One sentence settles it. *Blocks: Phases C, D and E entirely.*

### RECOVERABLE — a wrong guess is fixable but wastes rework

2. **Who should be able to read `ai-devops` inside `popcre`?**
   The org grants members **read** by default. Its members are `u2giants`,
   `devopswithkube` and `VaibhavBarot`. `VaibhavBarot` has no access today and
   would gain read on arrival. The repo is public, so nothing new is exposed —
   but it adds them to the repo.
   **Recommendation: set the repository permission explicitly rather than
   inherit the org default.** *Blocks: nothing; adjustable afterwards.*

### NOT PART OF THIS WORK, AND NOBODY IS ON IT

3. **The shared working copy at `C:\repos\ai-devops` was carrying another
   session's unfinished work.** As of 2026-08-25 20:12 UTC, local `main` was 3
   commits ahead of `origin/main` (`90b21ea`, `6c6f255`, `b5f7c76`, Grok
   locking/reservation fixes) with four modified files (`bin/ai-deepseek-agent`,
   `bin/ai-muse`, `tests/test-ai-deepseek-agent.sh`, `tests/test-ai-muse.sh`).
   **Update 2026-08-26: those three commits are now ancestors of `origin/main`,
   so that work was pushed.** Whether the four modified files were also
   committed was not checked.
   **Recommendation: confirm the working copy is clean before Phase C** — a push
   landing during the changeover is the one local-state risk the transfer has.
   Nobody in this session owned that work; this session never touched those
   files.

4. **There are 7 live git worktrees registered against `ai-devops`**, including
   two under `C:\Users\ahazan\AppData\Local\Temp\` and two detached-HEAD clones
   named `ai-devops-gemini-qualification-final`(`-v2`). Several look abandoned.
   **Recommendation: run the `cleanup-worktree` skill separately.** Out of scope
   here, and age alone is not proof any of them is safe to delete.

5. **Six `HANDOFF.d/` files are STALE — their issues are already closed**, and
   six more carry no contract block at all so they can never be retired. The
   target for stale files is zero. Full list, with each file's owner, is in
   `HANDOFF.d/2026-08-26T1125Z-edge-dev-claude-flaky-reviewer-tests.md` §0 items
   4 and 5. **Recommendation: one session retires them all.** Out of scope here.

### Already settled — do NOT re-ask

- **Destination org is `popcre`** (Albert, 2026-08-25). `popcre` is **not**
  reserved for DesignFlow; older wording saying so is superseded.
- **Repos stay PUBLIC** (Albert, 2026-08-25). Public + free org = merge queue at
  no cost; private would require a paid Team plan.
- **The two private siblings do NOT move** (Albert, 2026-08-25).
  `ai-devops-memory` and `ai-devops-transcripts` stay under `u2giants`.
  Implemented in Phase A.
- **The reason for the whole exercise** — GitHub only gives merge queues to
  org-owned repos — is settled and evidenced. Do not re-litigate it.
- **`admin:org` scope is NOT required** (2026-08-25). Do not chase it; see §4.2.
- **The code change lands BEFORE the transfer** (2026-08-25). Reversing that
  order recreates the flag-day described in §5.
- **The flaky reviewer suites are Phase F — AFTER the move is fully done**
  (Albert, 2026-08-26). See `fix_to_gh_org.md` §5 Phase F and issue #89.

## 1. What this application is

`ai-devops` (`https://github.com/u2giants/ai-devops`, public) is Albert Hazan's
**AI operations and configuration hub** for POP Creations. It is not a customer
product. It holds the shell/PowerShell tooling in `bin/`, the machine bootstrap
and installer scripts, the shared AI reviewer wrappers (`ai-grok-review`,
`ai-muse`, `ai-deepseek-agent`, `ai-gemini`, `ai-kimi`, `ai-qwen`), the
cross-tool `templates/system/` standards (including `machine-atlas.md` and
`handoff-standard.md`), and the skills that other repos' AI sessions load.

Every workstation Albert uses clones this repo and installs from it. That is why
its identity checks matter: a machine bootstrapped from a look-alike fork would
be a serious compromise.

Two private siblings orbit it: `u2giants/ai-devops-memory` (portable memory hub)
and `u2giants/ai-devops-transcripts` (Claude session transcripts). **Neither is
moving.**

Stack: Bash + PowerShell scripts, one GitHub Actions workflow (`verify.yml`) with
three jobs on `ubuntu-24.04` and `windows-2025`. No server, no deployment, no
database.

## 2. What we set out to do this session, and why

`u2giants` is a personal GitHub account, and **GitHub offers merge queues only to
repositories owned by an organization**. That constraint was discovered while
filing `shared-db` issue #1435 (its merge-queue proposal, which documents one
small change costing five attempts, three burned migration slots, four paid
external reviews and about nine hours). Moving `ai-devops` into `popcre` is what
makes a merge queue possible at all.

The previous session produced the plan. **This session executed Phase A and
Phase B**, on Albert's instruction: *"no, leave the private siblings; do phase A
now."* Phase B followed because it was the last unevidenced assumption standing
between the plan and the transfer.

Albert then sequenced the flaky-test work (issue #89) as **Phase F, after the
move is fully done**.

## 3. Current state — what is true right now

### Phase A — DONE, merged, CI green

Merged to `main` as **`eeb510f`** (squash of PR
[#88](https://github.com/u2giants/ai-devops/pull/88)). All three CI jobs green.

- `config/repo-identities.tsv` — the single source of truth. `ai-devops` accepts
  **both** `github.com/u2giants/ai-devops` and `github.com/popcre/ai-devops`;
  the two siblings accept `u2giants` only.
- `bin/ai-repo-identity` (Bash: `list` / `canonical` / `accepts`) and
  `bin/repo-identity.ps1` (dot-sourced PowerShell:
  `Get-AiDevOpsAcceptedIdentity`, `Assert-AiDevOpsRepoIdentity`).
- Rewired guards: `bin/bootstrap-windows-dev.ps1:55` and `:120`;
  `bin/install-ai-devops-windows.ps1:111` and `:553`;
  `bin/ai-sync-memory`'s `public_ai_devops_hub()`.
- Tests: `tests/test-ai-repo-identity.sh` (29 checks),
  `tests/test-repo-identity.ps1` (12 checks).
- Docs: "Repository identity allow-list" section in `docs/config-inventory.md`;
  `docs/restore-from-zero.md` step 1 now clones before running the bootstrap.

### Phase B — DONE, evidenced

`windows-2025` **runs in `popcre`.**

- `.github/workflows/windows-probe.yml` added to `popcre/actions-policy-probe`
  (commit `3eca5bb`).
- Run **32964936717**, 2026-08-26 11:45 UTC. The API reports the job's labels as
  **`["windows-2025"]`** — that, not the green tick, is the confirmation.
- Six steps green: pinned `actions/checkout`, runner identity, `jq` present on
  the image, Git Bash executes a Bash suite, result. 14 seconds.

### Phases C, D, E — NOT STARTED

**The repository has not been transferred.** Nothing about `u2giants/ai-devops`
has changed except the merged code and docs above.

### Phase F — queued, not started

Issue [#89](https://github.com/u2giants/ai-devops/issues/89), diagnosis in
`fix_test_ai.md`, its own handoff at
`HANDOFF.d/2026-08-26T1125Z-edge-dev-claude-flaky-reviewer-tests.md`. **Do not
start it before the move is done.**

### This file

`fix_to_gh_org.md` (Phase B evidence + Phase F) and this handoff are on branch
`claude/org-move-phase-b`. If you are reading this from `main`, they landed.

## 4. Everything we tried that did NOT work

Carried forward from the retired predecessor, plus this session's own.

1. **Creating a worktree under the session scratchpad fails on Windows path
   length.** `git worktree add` into a scratchpad path aborted with
   `Filename too long` on ten files (longest:
   `tests/verification/full-remediation/20260821T233700Z/step-04-instruction-closure.md`,
   `skills/shared/wb-starlabs-scrape/scripts/append_property_character_batch.test.mjs`),
   then `fatal: Could not reset index file to revision 'HEAD'`. It also left a
   half-registered worktree and a stray branch needing `git worktree prune` +
   `git branch -D`. **Fix: use `C:\repos\ai-devops-worktrees\<name>`.**

2. **Reading the `popcre` org Actions policy directly fails.**
   `gh api orgs/popcre/actions/permissions` returns **403** — the local `gh`
   token lacks `admin:org`. A `gh auth refresh -h github.com -s admin:org` was
   attempted and **did not take**. **Do not chase that scope.** It is
   unnecessary: repository-level `allowed_actions: "all"` on three `popcre`
   repos proves the org policy is "all", because GitHub does not permit a repo
   policy less restrictive than its org's.

3. **Assuming GitHub's URL redirect makes hard-coded owner strings harmless.**
   True for `shared-db`, **false for `ai-devops`** — see §5, Finding 1.

4. **Judging `tests/test-all.sh` by a piped exit code.**
   `bash tests/test-all.sh 2>&1 | tail -40` returns **`tail`'s** exit code. The
   suite reported `tests=54 failures=1` in its summary while the harness recorded
   "exit code 0", and that was reported to Albert as a clean pass. **Read the
   `OFFLINE BASH SUMMARY tests=N failures=N` line, or use `${PIPESTATUS[0]}`.**

5. **Trying to identify a failing test from the suite log.** No `FAIL` line
   appears anywhere and every section shows its normal pass marker, yet the
   summary counts a failure. **Fix: run each `tests/test-*.sh` individually and
   record its exit code.**

6. **Writing scratch files to `$TMPDIR`.** It is empty here, so
   `> "$TMPDIR/x.sh"` becomes `> /x.sh` and fails with `Permission denied`.

7. **Passing multi-line Python or Markdown through a quoted Bash heredoc.**
   Backslashes collapse before the interpreter sees them: `C:\\repos\\ai-devops`
   arrived as `C:\repos\ai-devops`, and Python read `\r` and `\a` as control
   characters, writing `C:eposi-devops` into `docs/restore-from-zero.md`. A
   heredoc'd Markdown file died with `unexpected EOF while looking for matching
   quote`. **Fix: `chr(92)` inside Python, or the `Write` tool for prose. Read
   the result back.**

8. **Over-running the test suite.** Chasing an intermittent failure cost three
   ~50-minute full-suite runs plus CI polling. The first clean rerun was already
   the answer. **Run it once in the background; do not sit in a polling loop.**

## 5. Root causes and key findings

**Finding 1 — the risk is in this repo's own code, and the redirect does not
cover it.** Git does **not** rewrite a clone's `origin` when it follows a
redirect. So machines already set up keep the string `u2giants/...` and keep
passing — **hiding the breakage** — while a fresh
`git clone https://github.com/popcre/ai-devops.git` records `popcre/ai-devops`,
the literal comparison fails, and **the installer aborts**. The failure surfaces
only when a NEW machine is bootstrapped, which is the worst possible moment.
That is why the code change had to merge **before** the transfer and had to
accept **both** owners rather than swap one for the other.

**Finding 2 — `ai-devops` carries almost no GitHub-side state.** Verified
2026-08-25: no Actions secrets, no variables, no environments, branch protection
returns `404 Branch not protected`, one collaborator (`u2giants`), one workflow.
**There is nothing to restore after the transfer** — unlike `shared-db` (8
secrets, 6 variables, 2 environments, 11 required checks).

**Finding 3 — there was a SEVENTH identity site the plan did not list, and it
was the dangerous one.** `bin/ai-sync-memory`'s `public_ai_devops_hub()` refuses
to use the public `ai-devops` repo as a private memory hub. Its owner check is
**inverted**. Hard-coding `u2giants` there would have silently **permitted**
publishing private memory into a `popcre`-owned clone after the transfer. It now
reads the same allow-list.

**Finding 4 — the sibling guards were deliberately left as literals.**
`bin/ai-facts:20`, `bin/ai-devops:109`, `bin/ai-memory-sync:29,:51`,
`bin/ai-transcript-destination-check:18`. Their values do not change, and
`ai-facts` and `ai-transcript-destination-check` are installed as **symlinks
into the repo** by `bin/install-machine-tools.sh` on Ubuntu, where
`dirname "${BASH_SOURCE[0]}"/..` resolves to `/usr/local`, not the repo — so a
runtime table lookup there is avoidable risk. Drift is prevented by a check in
`tests/test-ai-repo-identity.sh` that fails if any `github.com/*/ai-devops*`
literal in `bin/` is missing from the table. That guard was proven by injecting a
fake literal and watching it go red.

**Finding 5 — `popcre` does not restrict Actions, and Windows works.** Three
`popcre` repos report `allowed_actions: "all"`; third-party actions ran green in
`popcre/actions-policy-probe` run `32892354687` (Linux, 15 steps); and
`windows-2025` ran green in run `32964936717` (§3).

**Finding 6 — new Bash files need their executable bit set in git.** `git add`
on Windows records `100644`; siblings are `100755`. Ubuntu CI cannot execute a
`644` file invoked by path. Fix with `git update-index --chmod=+x <path>`.

**Finding 7 — do not add `Set-StrictMode` to a dot-sourced PowerShell helper.**
It applies to the host script's scope. `bin/repo-identity.ps1` deliberately omits
it, with a comment, because neither `bootstrap-windows-dev.ps1` nor
`install-ai-devops-windows.ps1` was written under strict mode.

## 6. Exact next steps

0. **Commit and push this file and the `fix_to_gh_org.md` update**, and delete
   the retired predecessor handoff in the same commit. *You'll know it worked
   when* `gh api repos/u2giants/ai-devops/contents/fix_to_gh_org.md --jq .name`
   prints `fix_to_gh_org.md` and the 2026-08-25 handoff is gone from `main`.

1. **Put §0 to Albert in one message.** The only true blocker is item 1, go/no-go
   and timing on the transfer. *You'll know it worked when* you have a sentence
   naming a quiet moment, plus an answer on `VaibhavBarot` read access.

2. **Immediately before Phase C, prove the working copy is quiet.** In
   `C:\repos\ai-devops`: `git status --porcelain` clean, and
   `git log --oneline origin/main..main` empty. Also confirm no open PRs and no
   running workflows on `u2giants/ai-devops`. *You'll know it worked when* all
   three are empty. **Do not transfer otherwise** — a push landing during the
   changeover is the one local-state risk.

3. **Execute Phase C** (`fix_to_gh_org.md` §5, steps 10–13): transfer
   `u2giants/ai-devops` → `popcre/ai-devops`, keeping it **public**; re-run the
   four inventory commands to prove nothing needed restoring; set repo access
   deliberately per §0 item 2. *You'll know it worked when* `gh repo view
   popcre/ai-devops` shows it PUBLIC and an old clone can still `git fetch` via
   the redirect.

4. **Execute Phase D — the proof that matters** (steps 14–16). Clone fresh from
   the `popcre` URL into a scratch directory and run `bin/ai-devops` (the
   doctor); run the Windows installer's identity check against the new URL; then
   run the doctor on an **existing** machine whose `origin` still says
   `u2giants`. *You'll know it worked when* **both** the new-URL clone and the
   old-URL clone pass on the same commit. That is the check that proves there is
   no flag-day.

5. **Execute Phase E** (steps 17–19): enable the merge queue; sweep the
   remaining `u2giants/ai-devops` references (567 occurrences as of 2026-08-25,
   mostly prose — **do not bulk `sed` `HANDOFF.d/`**, those are other sessions'
   write-once files); update the four Claude skills that name the repo
   (`sync-dotfiles`, `claude-transcript-backup`, `grok-cli`,
   `kimi-code-delegation`, under Albert's `.claude\skills\`). *You'll know it
   worked when* a PR can be added to a queue in the GitHub UI.

6. **Delete `popcre/actions-policy-probe`** once the transfer is verified. It is
   deliberately alive as a known-good control until then.

7. **Close issue #84 and delete this handoff in the same PR.**

8. **Only then start Phase F** — issue #89, the flaky reviewer suites. Its own
   handoff and `fix_test_ai.md` carry the detail. *You'll know it worked when*
   both suites pass 10 consecutive runs on a loaded machine, still fail when
   their guarded defect is reintroduced, CI is green, and the check counts are
   unchanged or higher (191 Grok, 203 Kimi).

## 7. Constraints and gotchas in force

- **The identity assertions must stay fail-closed.** Widening the allow-list by
  a known-good entry is the goal; turning any check into a warning is a
  regression and must be rejected in review.
- **`C:\repos\ai-devops` is shared with other live AI sessions.** Branch from
  `origin/main` in a separate worktree; stage only your own files; never
  `git add -A`; never rebase local `main`.
- **`ai-devops` local `main` routinely carries other sessions' unpushed
  commits.** Push via a branch and PR, never directly.
- **Do not put an `ai-devops` worktree under the session scratchpad** — Windows
  path length breaks it (§4.1). Use `C:\repos\ai-devops-worktrees\<name>`.
- **The full Bash suite takes ~50 minutes on Windows.** Normal, not hung: CI
  budgets 45 minutes for Linux and 75 for Windows. Run it in the background once.
- **`$TMPDIR` is empty here**; Bash heredocs collapse backslashes (§4.6, §4.7).
- **PowerShell files are CRLF and must be pure ASCII.**
- **Committer identity must be `Albert Hazan <u2giants@users.noreply.github.com>`.**
  Verify with `git var GIT_COMMITTER_IDENT` before the first commit in a repo.
- **Albert does not merge — the session that opens a PR merges it.** Do not end
  a report asking him to click Merge.
- **`gh pr merge` from a linked worktree prints `'main' is already used by
  worktree`.** That is local branch cleanup failing **after** a successful merge;
  it happened on both PR #88 and PR #90. Confirm with
  `gh pr view <n> --json state`, delete the remote branch manually, continue.
- **Never rewrite the root `HANDOFF.md`** — line 1 carries `handoff-pointer: v1`.
  Never edit another session's `HANDOFF.d/` file; retiring a finished one under
  the successor rule is the only exception.

## 8. Access and environment

- **`gh` CLI:** authenticated as `u2giants`, token in the OS keyring. Scopes:
  `admin:public_key`, `gist`, `read:org`, `repo`, `workflow`. **`admin:org` is
  absent and is NOT needed** (§4.2, §5 Finding 5).
- **Org role:** `u2giants` is an **admin/owner** of `popcre`, so the transfer is
  within reach without extra grants.
- **Machine:** `edge-dev` (Windows 11 Pro). PowerShell 7 (`pwsh`) and Git Bash
  both available.
- **Repo checkouts:** canonical clone `C:\repos\ai-devops` (shared). This session
  worked in the linked worktree
  `C:\repos\ai-devops\.claude\worktrees\github-org-move-handoff-d576f2`, based on
  `origin/main`.
- **Probe repo:** `popcre/actions-policy-probe` (PRIVATE) — the known-good
  control for `popcre` CI. Delete after the transfer is verified.
- **Secrets:** none are needed. `ai-devops` has no Actions secrets at all.
  Anything else lives in 1Password vault **`vibe_coding`** — reference by item,
  never by value.

## 9. Open questions and risks

- **RISK — the breakage this plan prevents is invisible until a new machine is
  set up.** If Phase D step 16 (the old-URL clone) is skipped, nothing fails
  until someone bootstraps a workstation, and then that workstation is unusable.
  Phase D exists precisely to catch this while someone is watching.
- **RISK — a local push landing during the transfer.** §6 step 2 is the guard.
- **UNCERTAIN — how many machines exist and their clone URLs.**
  `templates/system/machine-atlas.md` is marked "protected source" and was not
  read in full (standing rule: read only the current machine's section). The
  count of affected workstations is unknown. It does not change the plan — the
  both-owners-accepted design is safe at any machine count — but someone should
  confirm no machine has an unusual remote.
- **UNCERTAIN — whether the four modified files in the shared checkout were ever
  committed.** The three Grok commits reached `origin/main`; the working-tree
  files were not re-checked. §0 item 3.
- **DECIDED 2026-08-25 — destination is `popcre`, public; siblings stay;
  `admin:org` not required; code lands before the transfer.** Do not revisit.
- **DECIDED 2026-08-26 — the sibling identity guards keep their literals**, with
  a drift test instead of a runtime lookup (Finding 4). Reversing that means
  solving the Ubuntu symlink path-resolution problem first.
- **DECIDED 2026-08-26 (Albert) — the flaky reviewer suites are Phase F, after
  the move is fully done.** Do not pull it forward.

---

## Self-audit (required by the handoff standard)

1. **Could a street-newcomer continue without asking a question?** Yes. §1
   explains what the repo is with zero assumed knowledge; §2 gives the trigger
   and the merge-queue constraint; §3 states exactly what is done and what is
   not; §5 names every finding with `file:line`; §6 gives nine numbered steps
   each with a verification gate; §8 gives the exact checkout paths and token
   scopes.
2. **As effectively as this session can right now?** Yes. The eight things that
   cost real time — the Windows path-length worktree failure, the `admin:org`
   dead end, the redirect assumption, the piped exit code that produced a false
   pass, the unusable suite log, the empty `$TMPDIR`, heredoc backslash
   collapse, and over-running the suite — are all in §4 with the fix that
   worked.
3. **Is every relevant detail present?** Yes: background (§1–2), current state
   with merge SHAs and run IDs (§3), failures (§4), findings with `file:line`
   (§5), next steps with gates (§6), constraints (§7), access (§8), risks (§9).
4. **Would Albert see every decision he owns by reading only §0?** Checked by
   walking §1–§9 line by line. The transfer go/no-go and timing (§6 step 3 →
   §0.1), `VaibhavBarot` read access (§6 step 3 → §0.2), the shared working copy
   and the unverified modified files (§9 → §0.3), the seven stale worktrees
   (§0.4), and the stale handoff files (§0.5) all appear in §0. Items 3, 4 and 5
   are outside this workstream and are in §0 precisely because nobody else is
   raising them.
