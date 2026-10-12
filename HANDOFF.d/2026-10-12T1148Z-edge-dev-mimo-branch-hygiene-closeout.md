---
issue: 1585
status: OPEN
owner: mimo/branch-hygiene-closeout
---

# Branch hygiene: cleanup done, long-term fix opened as #1585 / #1590

Written 2026-10-12T1148Z on machine `edge-dev` by a MiMo session.
Repo: `C:\repos\ai-devops` (`popcre/ai-devops`), branch `mimo/branch-hygiene-closeout`.

---

## 0. Business decisions only the owner can make

**Nothing blocks the next session.** Both items below are small and recoverable.

**Blocking:** none.

**A wrong guess is recoverable — answer once, in one message:**

1. **Should `plan_repo-housekeeping-visibility.md` be edited to name issue #1585?**
   The plan still carries no issue reference, so the task router cannot find it.
   Recommendation: **yes** — one docs-only PR, and fold it into stage 1 (#1586),
   which is already a docs stage. Blocks nothing today.
2. **Disposition of the parked evidence branch `mimo/branch-hygiene-review-packet`
   (worktree `C:\repos\ai-devops-wt-branch-hygiene`).** It holds the two decision
   packets and all six Muse review reports, and it cannot be pushed (see §7).
   Recommendation: **keep it until #1585 stage 4 has run once, then delete it**
   with `cleanup-worktree`; its value is only as the record behind #1585/#1590.

**Already settled — do NOT re-ask:**

- 2026-10-11, verbatim: *"i authorise opening issues for the housekeeping plan
  and the wrap-up defect."* Done: **#1585** (parent) with children **#1586–#1589**,
  and **#1590**.
- No automatic, bulk, or age-triggered branch deletion. Owner's locked non-goal,
  `plan_repo-housekeeping-visibility.md:64-72`.
- 33 remote branches with no open PR were reviewed and **kept**; one remote head
  was deleted after reviewer APPROVE. Do not re-open that review.

**Instruction to the next session:** put both open items above to Albert in
**one** message before starting work. Do not trickle them.

---

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's **public** recovery toolkit for his
multi-model AI workflow. It is not an app, service, or deployment: it is
100% Bash, PowerShell and Markdown — CLI helpers in `bin/`, skills in `skills/`,
instruction templates in `templates/`, plans as root `plan_*.md`, docs in `docs/`.

- Remote: `https://github.com/popcre/ai-devops.git`
- `main` is protected and uses a **merge queue**. Never push to `main`; branch →
  PR → queue. Documentation-only PRs may be merged immediately the normal way.
- Canonical local checkout `C:\repos\ai-devops` is **landing-only**; write-capable
  work uses its own worktree.

## 2. What we set out to do this session, and why

Albert asked, in order:

1. "delete local branches of this repo that were already merged into main and
   then analyze the remote branches to see what should be deleted"
2. "delete the 13 merged remote branches. analyze the 14 likely-abandoned ones"
3. "delete the 12 safe ones, delete the two unsubmitted branches"
4. "are sessions failing to clean up branches?"
5. "i am non-technical and unqualified to decide. ask a reviewer. and how do we
   solve this problem for the long term?"
6. "the 34 no-PR branches get this same reviewer pass / does my own plan
   disqualify it for the wrong reason? / what is the Issue # of the August
   housekeeping plan?"
7. "i authorise opening issues for the housekeeping plan and the wrap-up defect.
   if either would benefit from being a multi-stage plan then make them child
   issues linked by a parent issue"

The technical objective: inventory, evidence, reviewer-gate, and execute branch
cleanup; then diagnose why it accumulates and open durable tracking.

## 3. Current state — what is true right now

**Executed and verified (this session):**

| what | count | proof |
|---|---|---|
| local branches deleted | **16** | 9 after `git cherry` `unique=0` + subject in `origin/main`; 7 after Muse **APPROVE** (run `20261011T194449-2552009-5237`) |
| remote heads deleted | **28** | 13 ancestry-proven; 14 after two Muse passes; 1 (`mimo/1183-c5c-wrappers`) after APPROVE run `20261011T205201-2837373-5306` and a 7/7 execution gate |

Counts as of 2026-10-12T1148Z: **15 local branches, 75 remote** (inventory moves
continuously — a concurrent session created `mimo/1547-token-posture-evidence`
mid-session).

**Opened on GitHub:**

- **#1585** parent — *Repo housekeeping: make stale artifacts visible*
  - **#1586** stage 1 — doc and rule corrections (plan steps 1–2)
  - **#1587** stage 2 — handoff contract block mandatory (step 3)
  - **#1588** stage 3 — build `bin/ai-housekeeping` + tests + registration (steps 4–6)
  - **#1589** stage 4 — schedule the report and run it once (steps 7–8)
  - Sub-issue linkage verified via `GET /repos/popcre/ai-devops/issues/1585/sub_issues`
- **#1590** standalone — *wrap-up step 6 endorses `git branch --merged`, which this
  repo disqualifies*

**Committed / pushed / PR status:** **nothing was pushed to `main`, and no PR was
opened before this handoff.** The only deliverable landing is this handoff file
itself, on branch `mimo/branch-hygiene-closeout`.

**Live artefacts (not pushed):**

- Worktree `C:\repos\ai-devops-wt-branch-hygiene`, branch
  `mimo/branch-hygiene-review-packet`, tree clean, **ahead 10 / behind 16** of
  `origin/main`. Holds:
  - `plan_branch-hygiene-review-packet.md` — v1/v2/v3 of the local-branch packet; v3 **APPROVED**
  - `plan_remote-branch-hygiene-34.md` + round-3/4 addenda; final round **APPROVED**
  - `.ai/reviews/muse-plan-review-*.md` — all six Muse reports
- This worktree: `C:\repos\ai-devops-wt-closeout`, branch
  `mimo/branch-hygiene-closeout`, tracks `origin/main`.

**Not started:** every stage of #1585; the #1590 fix.

## 4. Everything we tried that did NOT work

This section exists so you do not repeat these.

1. **`git branch --merged origin/main` as a merge test.** Returned **only
   `main`**, while 7 branches were independently proven merged. Under squash
   merge the branch tip is never an ancestor of `main`, so the command
   **under-reports** (false negative). It is sound but useless as an inventory.
   This is exactly issue **#1590**.
2. **Reading `skills/wrap-up/SKILL.md` (wrong path) and concluding the session
   closer has no cleanup step.** The real path is
   **`skills/shared/wrap-up/SKILL.md`**, and step 6 *does* gate branch deletion.
   Muse REJECTed packet v1 on this (finding H1). Always confirm a `grep` that
   returns nothing is not a path miss.
3. **Treating a same-subject commit in `main` as proof of incorporation.**
   `codex/reviewer-install-gate`: branch patch 714 lines, matched main commit
   4734 lines, 4226 differing — a **subject collision**. Never authorise a
   deletion on subject grep alone.
4. **Claiming `--ignore-all-space` equality was "exact".** Muse REJECTed (H2).
   Re-ran with **no flags**: equal anyway, 59502 characters each. `--ignore-all-space`
   was never needed; withdraw it rather than defend it.
5. **PowerShell `-ceq` on two arrays.** It *filters*, it does not compare —
   returned empty, not `True`. Always `-join` to a string first.
6. **`--grep=$var` unquoted in PowerShell.** The argument was split on spaces, so
   every subject lookup returned **NOT FOUND** and looked like real evidence.
   Re-ran with `--grep="$s"` and all nine hit.
7. **`bin/ai-review <provider> plan-review <file>` — there is no file argument.**
   The reviewer reads a snapshot of the repo, so the packet must be a **committed
   file on a branch in a worktree**. That is why the evidence worktree exists.
8. **`bash -lc '…'`** resolved to WSL, which has no distro installed. Use
   **`C:\Program Files\Git\bin\bash.exe`** explicitly on this machine.
9. **Gemini and Qwen reviewers are quarantined** (`live-qualification-required`).
   Muse (`muse-spark-1.3-contributor`, engine `muse-code`) worked every time.
   Do not retry a quarantined provider to get past it.
10. **`bin/ai-gh pr list --head <branch>` once per branch.** 34 branches meant 34
    calls. One **`bin/ai-gh pr list --state all --limit 500 --json …`** covered
    the whole population.
11. **`ai-doc-reachability` needs `--base`.** Without it: *"No PR base was
    supplied… Refusing to guess."*

## 5. Root causes and key findings

- **Why local branches survive a merge.** Documented in
  `docs/standing-rules-details.md` § *Worktree merge quirk*: `gh pr merge` from a
  linked worktree can print `'main' is already used by worktree` — *"That is
  local branch cleanup failing AFTER the merge succeeded."* Confirmed live: 7 of
  19 local branches had **MERGED** PRs whose remote heads GitHub had already
  deleted, while the local branch remained.
- **Why remote branches survive.** `delete_branch_on_merge` is **true** on the
  repo, so a merged PR cleans up its own remote head. The residue is therefore
  (a) branches that **never got a PR** (34 at census) and (b) branches whose PR
  was **closed unmerged** (8 of the 14 analysed). Auto-delete never fires for
  those.
- **The live instruction defect:** `skills/shared/wrap-up/SKILL.md:155` tells
  sessions to test with `git branch --merged origin/main`, which
  `plan_repo-housekeeping-visibility.md:234-239` disqualifies. Two current
  instructions contradict. → **#1590**.
- **The plan was right and simply never ran.**
  `plan_repo-housekeeping-visibility.md` (2026-08-14) has **8 steps, all `⬜ open`**,
  and its companion handoff carries `issue: none` because posting was never
  authorised — until this session. → **#1585**.
- **The proof standard that finally satisfied Muse** for a single remote delete:
  12-of-12 commit accounting (11 ancestors of merged PR head `0eab6820` + tip
  byte-equal to merged squash `7ade4689`), **plus** plain `git diff` with **no
  flags** equal at 59502 chars, **plus** `git diff --summary` empty on both
  sides, **plus** `git diff --numstat` showing **0 binary files**, **plus** both
  squash commits still ancestors of `origin/main` with no `Revert…(#1291|#1318)`
  match, **plus** `git worktree list --porcelain` clean.
- **`git cherry` is patch-equivalence, not reachance.** Under squash it reports
  `unique > 0` for branches whose content demonstrably landed. Use it as a lead,
  never as the authorisation.

## 6. Exact next steps

1. **Answer the two §0 items with Albert in one message.** Gate for everything
   below that depends on them. *You'll know it worked when* both have a one-word
   answer recorded in this file's successor.
2. **Start #1586 (stage 1).** Retract the superseded "more than 5 files" rule in
   `skills/shared/wrap-up/SKILL.md` and repair the dangling `HANDOFF.d/` pointer
   in `AGENTS.md`; update the plan's STATUS rows 1–2 in the same commit.
   *You'll know it worked when* `bin/ai-doc-reachability --base origin/main`
   passes on that PR and the plan rows read `✅ done` with a commit SHA.
3. **Fix #1590** — remove the `git branch --merged` alternative from step 6 of
   `skills/shared/wrap-up/SKILL.md:152-156`, keep
   `gh pr view <n> --json state,mergedAt` as the gate. Because this edits an
   **installed routing rule**, run `ai-task-gates start --class reviewer-safety`
   and get an independent exact-head review before merge.
   *You'll know it worked when* the merged text no longer contains
   `branch --merged` and the review report is APPROVE.
4. **If Albert approved §0 item 1:** open a docs-only PR adding `issue: 1585`
   linkage to `plan_repo-housekeeping-visibility.md`. *You'll know it worked
   when* the plan header resolves to #1585.
5. **Then #1587 → #1588 → #1589** in order; #1589 closes #1585 with the live
   proof pasted into it.

## 7. Constraints and gotchas in force

- **Never push `main`.** Branch → PR → merge queue. Docs-only PRs merge
  immediately the normal way, never `--admin`.
- Before the first commit: `git var GIT_COMMITTER_IDENT` must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Declare every task: `bin/ai-task-gates start --class <class>` (this session used
  `prose`; #1590 needs `reviewer-safety`).
- **All GitHub calls go through `bin/ai-gh`**, never bare `gh`.
- **No automatic, bulk, or age-based branch deletion** — owner non-goal,
  `plan_repo-housekeeping-visibility.md:64-72`.
- **The evidence branch must never be pushed.** Both packet files fail
  `bin/ai-doc-reachability` (root-level `plan_*.md` with no living-root link), and
  the packets say so themselves. Keep it local or add the link first and re-run
  the gate to PASS.
- `mimo/branch-hygiene-review-packet` and its worktree are **mine, not yours to
  tidy** except under §0 item 2 or the `cleanup-worktree` successor rule.
- Do not edit another session's `HANDOFF.d/` file; never rewrite root `HANDOFF.md`.
- Human-facing times are **EST/EDT**, named as such.
- Signature lines read `Posted by MiMo chat unknown on edge-dev` because
  `$MIMO_SESSION_ID` is **unset** on this machine.

## 8. Access and environment

- **Machine:** `edge-dev`. **Repo:** `C:\repos\ai-devops`.
- **Shell:** PowerShell by default, but any `git`/`gh` pipeline that needs bash
  must use **`C:\Program Files\Git\bin\bash.exe`** — `bash -lc` hits a WSL with
  no distro.
- **GitHub:** `bin/ai-gh` is authenticated (repo `popcre/ai-devops`).
- **Reviewers:** Muse works. Gemini and Qwen are `quarantined` /
  `live-qualification-required`. Check
  `C:\Users\ahazan\.local\state\ai-devops\review-lifecycle\runs\*\*\*.json`
  for the failure record if preflight fails again.
- **Review reports (this session):**
  `C:\repos\ai-devops-wt-branch-hygiene\.ai\reviews\muse-plan-review-*.md`
  — six files. The two APPROVEs are run `20261011T194449-2552009-5237`
  (locals) and `20261011T205201-2837373-5306` (remote Tier A).
- **Secrets:** 1Password vault `vibe_coding`. **No credential appeared in this
  session** — nothing to rotate.
- Session scratch written by this session into `.git/` of the main checkout:
  `remote-branches.txt`, `open-prs.json`, `open-pr-heads.txt`, `remote-cherry.txt`,
  `all-prs.json`, `all-prs.err`, `nopr-34.txt`, `nopr-evidence.txt`,
  `nopr-table.md`, `ai-gh-err.txt`. **Creator (this session) should delete them
  on close**; they are untracked scratch, not part of any commit.

## 9. Open questions and risks

- **33 remote branches with no open PR were deliberately kept.** 31 of the 34
  analysed are the **sole copy** of commits not in `main`. Do not delete them
  without the §5 proof standard and a fresh reviewer pass. Dated 2026-10-11.
- **The 27 earlier remote deletions and 9 earlier local deletions are
  unreproducible** — their refs are gone. Their authorising `git cherry` output
  exists only in a console transcript. Accepted residual risk, recorded in the
  approved packet. Do not cite them as re-verified.
- **Cross-machine check is impossible from here.** `git worktree list
  --porcelain` is machine-local; another clone could hold a branch checked out.
  Accepted and disclosed for the one remote delete.
- **TOCTOU** between the 7-point execution gate and `push --delete` is not
  atomic. Accepted; the refspec was exact, no wildcard.
- **Inventory drifts.** Local went 19 → 21 → 15 across the session because
  concurrent sessions create and switch branches. Re-census at execution time;
  never act on a count from this file.
- **Dated decisions:** 2026-10-11 — no bulk deletion; keep the 33; Tier B
  (delete a remote head just because a local copy exists) was **withdrawn** as
  unsafe. Do not revive Tier B without new evidence.

---

## Self-audit (handoff-writer gate)

1. **A newcomer could continue without asking a question?** Yes — §1 defines the
   repo, §3 gives exact state and counts, §4 lists every dead end with the fix,
   §6 gives numbered steps each with a verification gate, §7/§8 give the
   environment and traps.
2. **As effective as this session?** Yes — §5 carries every non-obvious finding
   (the merge quirk, why auto-delete misses, the proof standard that passed the
   reviewer, the `cherry`/`--merged` semantics), and §4 carries all eleven failed
   approaches.
3. **Every relevant detail?** Yes — background §1–§2, state §3, failures §4,
   findings §5, actions §6, constraints §7, access §8, risks §9, commit/push
   status stated explicitly in §3 (*nothing pushed to `main`*), secrets by
   location only in §8.
4. **Section 0 sweep re-run line by line over §1–§9:** the only sentences needing
   Albert are §0 items 1 and 2 (plan-file link; evidence-branch disposition) —
   both promoted there with recommendations. §9's risks are decisions already
   settled (listed under "Already settled") or technical matters for a reviewer
   (#1590) and #1585 stages, not owner asks. No technical approval appears in §0.

All four answers: **yes**, evidence-backed above.

---
Posted by MiMo chat unknown on edge-dev
