---
issue: 596
status: OPEN
owner: kimi/596-blocker-watch-deps
---

# HANDOFF — ai-devops #596: blocker-watch derives blocked-by links from `depends_on:` fences

Session: Kimi (Kimi Work desktop agent) on edge-dev, 2026-09-18 ~11:53–17:31 UTC.
Worktree: `C:\repos\ai-devops-worktrees\596-blocker-watch-deps`, branch
`kimi/596-blocker-watch-deps` (from `origin/main` d1260fff). Task class `code`
declared via `ai-task-gates start --class code` for this worktree.

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**Put both items to Albert in ONE message before starting work.**

1. **Local test suite cannot complete on edge-dev right now (environmental).
   Deviating from "local tests green before PR" needs a ruling.** The required
   gate for class `code` is `local-tests`. `tests/test-ai-blocker-watch.sh`
   hangs mid-run on this machine in BOTH the Kimi sandbox MSYS2 and real Git
   Bash, at a different test each run (8, 9, then 20 tests in before the hang),
   never with a FAIL — and the UNMODIFIED `main` suite hangs identically
   (control run). All isolated repros of the new code pass 100%.
   **Recommendation:** retry the suite up to ~5 times first (it is flaky, not
   broken — each attempt gets different distances); if it never completes, push
   and open the PR anyway and treat GitHub CI (clean runners) as the
   authoritative green, watching with `bin/ai-pr-wait`. Blocks step 6.2 (PR
   creation) — the first externally visible action. A wrong guess is
   recoverable (close the PR, fix, reopen).
2. **Not part of this work and nobody is on it:** the 2026-09-18 rename
   `u2giants/shared-db` → `popcre/shared-db` (shared-db #2530) left dozens of
   prose references to the old slug across ai-devops skills (e.g.
   `skills/shared/shared-db-handover/SKILL.md`, `shared-db-orchestrator`) and
   docs. Issue #596 scoped the rename fix to `config/blocker-watch.json` only.
   **Recommendation:** file one follow-up issue to sweep prose references;
   GitHub redirects make them cosmetically stale, not broken.

**Already settled — do NOT re-ask:**
- 2026-09-18 (issue #596 itself, Albert's corrected direction): no forced
  registration step in closing rituals; fixes target the moment the dependency
  is created. The watcher derives links from fence data; sessions were never
  trusted to record them.
- The watcher only ever ADDS links; removing stale ones is the issue author's
  job (this session's design choice, matching the issue's "link present →
  nothing to do; link missing → create it").
- Task class is `code` (declared and confirmed by `ai-task-gates explain`:
  observed == effective == code; required gate `local-tests`). The change set
  does NOT touch the reviewer-safety path, so no independent exact-head review
  is required.

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery toolkit for his multi-model AI
workflow (Claude/Codex/ZCode/GLM/etc.) — shell tools in `bin/`, config in
`config/`, AI skills in `skills/`, tests in `tests/`. Not an app or service.
`bin/ai-blocker-watch` is the "blocker watcher": a scheduled tool (Windows Task
Scheduler task `ai-devops\blocker-watch`, every 10 min) that (a) comments on
open issues when their GitHub-native "blocked by" blocker closes, (b) headlessly
resumes AI sessions that registered a `wait`, (c) alarms on unowned stalled
blockers. `config/blocker-watch.json` lists the watched repos and names
`propagate_on_host: edge-dev` — the ONE machine that posts to GitHub; other
machines only wake their own sessions. This machine IS edge-dev.

## 2. What we set out to do this session, and why

Implement https://github.com/popcre/ai-devops/issues/596 (OPEN, no labels, no
comments). A session filed blocker popcre/shared-db#3234 (blocking #3180's
follow-through) and handed the wait to "a future session" — nothing was
registered until Albert asked ~15 hours later. The issue's three fixes:

- **Fix 1:** the watcher's tick parses `depends_on:` from `db-work-scope`
  fences on OPEN issues in configured repos and maintains GitHub native
  "blocked by" links automatically (present → nothing; missing → create + note
  in tick log). Malformed fences: skip + count, never crash the tick.
- **Fix 2:** state the standing rule where issue-creation/handover guidance
  lives (`shared-db-handover` path A, queue intake rules): the session that
  files or identifies "this cannot proceed until N closes" either registers
  `ai-blocker-watch wait N --for M` and ends its turn, or hands the wait to a
  NAMED session/owner in the issue — never "a future session".
- **Fix 3:** `config/blocker-watch.json` still listed `u2giants/shared-db`;
  the repo moved to `popcre/shared-db` on 2026-09-18 (shared-db #2530).
  One-line change + re-run the #549 per-machine proof on the propagating host.

## 3. Current state — what is true right now

**All three fixes are implemented, committed, and pushed** on branch
`kimi/596-blocker-watch-deps` in worktree
`C:\repos\ai-devops-worktrees\596-blocker-watch-deps`. No PR exists yet.

Changed files (all verified by reading the written result):

- `config/blocker-watch.json` — `repos[0]` now `popcre/shared-db`; new keys
  `links_enabled: true`, `links_interval_minutes: 60`; `_comment` documents the
  rename and the links scan. `jq empty` passes.
- `bin/ai-blocker-watch` — header documents a fourth mechanism and the new
  `links` subcommand; new `links_on`, `LINKS_Q` (GraphQL: open issues' number,
  databaseId, body, blockedBy numbers), `parse_depends_on` (stdin body → dep
  numbers; rc 1 = malformed), `maintain_links` (two-pass scan + link creation),
  `maybe_links` (interval gate), `cmd_links`; `cmd_tick` calls `maybe_links`
  between the wake loop and `maybe_alarm`; case arm `links`; help sed range
  updated to 2,71. `bash -n` clean.
- `tests/test-ai-blocker-watch.sh` — fake gh gained a `*graphql*databaseId*`
  arm (BEFORE `*graphql*states:OPEN*`) reading `$F/gql_links.json`; new test
  block after the alarm section: 14 new checks (link creation from fence,
  id-from-open-scan, present-link no-op, malformed skip+count without failure,
  `#`-prefix/comma lists, closed-blocker REST fallback, self-dependency skip,
  dry-run no-post, standalone `links`, interval gate, disabled-config refusal,
  foreign-host no-op, unreachable-GitHub failure).
- `skills/shared/shared-db-handover/SKILL.md` — path A gained the standing
  rule paragraph ("A dependency you file is yours to register — never to 'a
  future session.'") right after the nine-things narrative paragraph.
- `skills/shared/shared-db-orchestrator/references/operating-manual.md` —
  "Dynamic queues and automatic refill" gained a paragraph defining the
  `depends_on:` contract and the same standing rule.
- `docs/task-router.md` — the blocker-watch row (line 43) now mentions the
  tick's link maintenance.
- This handoff file, `HANDOFF.d/2026-09-18T1731Z-edge-dev-kimi-596-blocker-watch-deps.md`.

**Test evidence:**
- `parse_depends_on` extracted standalone: **16/16 unit cases pass** (valid
  single, `#`-prefix + list, empty, no fence, missing line, bad token, zero,
  duplicate line, two fences, unterminated fence, YAML-list style, prose
  suffix, leading-zero normalization, objects-list coexistence, uppercase
  field rejection, trailing-space fence markers).
- `tests/test-shared-db-fast-close-skill.sh` PASS and
  `tests/test-shared-db-routing-rules.sh` 26/26 PASS (both grep-contract tests
  over the edited skill files).
- `tests/test-ai-blocker-watch.sh`: **never completed locally** — hangs
  mid-run (see §4). In the furthest run, all 20 tests up to "one search query
  per tick covers every configured repo" passed, including several ticks that
  exercised the new `maybe_links` path with empty fixtures. None of the new
  links tests has been reached by a full suite run yet.
- `bin/ai-task-gates explain`: declared/observed/effective class all `code`;
  required gate `local-tests`; forbidden actions database/deploy/
  infrastructure/production.

**Git state:** branch committed and pushed; `git var GIT_COMMITTER_IDENT` =
`Albert Hazan <u2giants@users.noreply.github.com>` (verified). Canonical
checkout `C:\repos\ai-devops` untouched (it is landing-only) except temp files
that were cleaned. The worktree's `.tmp-repro*.sh` diagnostics were deleted
before commit.

## 4. Everything we tried that did NOT work

1. **`bin/ai-gh` bare fails in Kimi shells: "the real gh is not installed."**
   gh IS installed at `C:\Program Files\GitHub CLI\gh.exe` but not on the Kimi
   PATH. Fix: `export AI_GH_REAL_GH="/c/Program Files/GitHub CLI/gh.exe"`.
2. **`jq` not on the Kimi PATH** (repo tools die with "jq is required"). It
   lives at `C:\Program Files\jq\jq.exe` → `export PATH="/c/Program Files/jq:$PATH"`.
   A login Git Bash shell (`bash -lc`) has neither jq nor gh on PATH either.
3. **The test-suite hang — the big one.** `tests/test-ai-blocker-watch.sh`
   hangs inside a `BW tick` at a different point every run (after 8, 9, then 20
   passing tests; a single isolated tick with fixture env also hung 3/3 at the
   LINKS_Q GraphQL call via `gh_api`). Tried: the Kimi sandbox MSYS2 bash, and
   real Git Bash `"/c/Program Files/Git/bin/bash.exe" -lc` — both hang.
   **Control: the UNMODIFIED suite on `main` (C:\repos\ai-devops) hangs the
   same way** → the hang is environmental (this host's process-spawn/pipe
   behavior under load; MSYS2 FIFO/fork flakiness), NOT this change. All
   isolated repros of the new code path passed: fake gh with LINKS_Q args
   (instant), `gh_api`-style pipe through `tr` 10/10, `parse_depends_on` 16/16,
   the scan loop's `base64 -d | tr | parse_depends_on` pipeline 15/15.
   Earlier in the session even a bare `parse_depends_on` unit run hung once,
   then passed 5/5 on identical input — same flakiness signature.
   **Do not burn hours re-diagnosing the environment; retry the suite (it gets
   different distances each run) or let CI be the authority (§0 item 1).**
4. `ai-test-local --check-collision` answered "unknown — runner status is
   unavailable", so the no-overlap boundary for a full local series could not
   be checked today. The single-test-file runs above are far below that bar.

## 5. Root causes and key findings

- **The `depends_on:` contract** (from `C:\repos\shared-db\scripts\manage-migration-author-lanes.mjs`
  `parseQueueScope` ~:755 and :793-794): the fence is exactly one
  ```` ```db-work-scope ```` block; `depends_on:` is ONE inline
  comma-separated field of SAME-REPO issue numbers, optional `#` prefix;
  empty/absent = no deps; non-numbers, `0`, negatives, or YAML-list style are
  malformed there and must be malformed in the watcher too. List items (`- x`)
  are legal only inside `objects:`/`writes:`/`reads:`. The watcher's
  `parse_depends_on` mirrors exactly this, including a structural pass so a
  YAML-list `depends_on:` is counted malformed instead of silently empty.
- **Design choices in `maintain_links`** (all in the script's comments):
  interval-gated by `links_interval_minutes` (default 60) with state file
  `~/.ai-devops/blocker-watch/last-links`; posts links only on
  `propagate_on_host` (dry-run reads anywhere); one paginated GraphQL walk per
  configured repo (10-page cap, like the alarm); blocker id comes from the
  open-issue map (`databaseId`) when the blocker is open, else ONE REST read —
  a closed blocker still gets its (truthful) link, an unreadable target is
  skipped+counted, never a failure; existing links are pre-filtered from the
  scan's `blockedBy` data; duplicate edges deduped; self-dependencies skipped;
  failed reads/POSTs set FAILED=1 so the tick exits non-zero; malformed fences
  are counted and logged, never fatal. Links are only ever ADDED.
- **Why a separate scan instead of folding into the alarm walk:** separate
  concern, separate clock (`last-links` vs `last-alarm`); the alarm's
  `PARENTS_Q` stays untouched. Cost is one page walk per repo per hour, same
  order as the alarm, throttled by `ai-gh`.
- **The tick already writes `last-links` on its first run**, so existing tests
  that count GraphQL calls inside the interval are unaffected (verified by the
  furthest suite run passing the propagation/alarm sections).
- Issue #596's "Verified working" section confirms the scheduled task runs on
  this machine and `wait --for` records native links per #549.

## 6. Exact next steps

0. `cd /c/repos/ai-devops-worktrees/596-blocker-watch-deps` and confirm you are
   on `kimi/596-blocker-watch-deps`, clean tree, HEAD == the pushed tip.
   `export PATH="/c/Program Files/jq:$PATH"` and
   `export AI_GH_REAL_GH="/c/Program Files/GitHub CLI/gh.exe"` in every shell.
   **Consume this handoff, then `git rm` it from the branch** so the PR diff is
   only the six implementation files (this file survives in branch history).
   Gate: `git status --short` shows only the handoff deletion.
1. Put §0's two items to Albert in ONE message. Do not start step 2 until item
   1 (local-tests vs CI-authority) is answered IF the suite will not complete.
2. Run `bash tests/test-ai-blocker-watch.sh`. If it hangs (killed run shows
   only `ok` lines, no `FAIL`), retry — up to ~5 attempts; it is flaky, and
   each attempt reaches a different depth. A `FAIL` line is a REAL failure:
   fix it before continuing. **Gate: final line `N passed, 0 failed`** (N = 41:
   27 pre-existing + 14 new).
3. Also run `bash tests/test-shared-db-fast-close-skill.sh` and
   `bash tests/test-shared-db-routing-rules.sh` (both passed this session).
   Gate: PASS / `26 passed, 0 failed`.
4. Open the PR from the pushed branch:
   `bin/ai-gh pr create --repo popcre/ai-devops --title "fix(#596): blocker-watch derives blocked-by links from db-work-scope depends_on" --body ...`
   — body: summarize the three fixes, name issue #596 with `Closes #596`,
   list test evidence honestly (parser 16/16, skill tests pass, full suite
   green-locally or CI-authoritative per §0 item 1).
   Gate: PR number returned.
5. Wait on CI with `bin/ai-pr-wait <pr>` (never `gh run watch`, never an
   unbounded poll; surface a failing check immediately). Fix any real CI
   failure (the suite runs there on clean runners) and re-push.
   Gate: required checks green.
6. Merge through the merge queue per the repo contract (never push to `main`,
   never force-push). Gate: PR state MERGED.
7. Reconcile and verify on main: `git fetch origin main` in the CANONICAL
   checkout `C:\repos\ai-devops` (landing-only), confirm the squashed commit
   is on `origin/main` and contains all six files. Gate: `git log origin/main
   --oneline -3` shows it; `git diff` pre/post shows the config slug.
8. **Re-run the #549 per-machine proof on edge-dev** (this host is
   `propagate_on_host`; the scheduled task `ai-devops\blocker-watch` runs every
   10 min from the installed checkout): after the canonical checkout lands on
   the new main, run `bin/ai-blocker-watch links --dry-run` from
   `C:\repos\ai-devops` — a read-only live pass proving `popcre/shared-db`
   open issues parse under the new slug — then let one real scheduled tick run
   (or run `bin/ai-blocker-watch tick` once) and inspect
   `~/.ai-devops/blocker-watch/tick.log` for the links scan lines.
   Gate: dry-run exits 0 and logs `links:` lines naming `popcre/shared-db`
   refs (or silence = nothing to link); the real tick exits 0.
   NOTE: a real tick on the propagating host may post blocker comments and
   create links — that is the watcher's normal production behavior and the
   point of the change.
9. `bin/ai-task-gates end`; remove the worktree only after the PR is merged
   (use the `cleanup-worktree` skill; the worktree holds no uncommitted work
   once pushed). Report the merge commit SHA and check states to Albert.
10. **Reciprocal drift check (required before declaring done):** re-read steps
    0–9 and issue #596's three fixes end to end and report anything this
    session did or learned that changes a later step's assumption (renames,
    file moves, interface changes, new evidence about the suite hang). Fix the
    handoff/plan text that drifted, or state "no drift".

## 7. Constraints and gotchas in force

- Repo contract (AGENTS.md): branch + PR only, merge queue, never push to
  `main`; committer must be `Albert Hazan <u2giants@users.noreply.github.com>`;
  stage only task-owned files; all GitHub calls via `bin/ai-gh` (machine-wide
  throttle; with `AI_GH_REAL_GH` in Kimi shells); at most one GitHub call per 5
  minutes per waiter; no `gh run watch`; waits need deadlines.
- The canonical checkout `C:\repos\ai-devops` is landing-only — do not edit or
  commit there; the work happens in the worktree named in the header.
- `ai-task-gates` state for this worktree is class `code` — confirm with
  `bin/ai-task-gates status`; the `ship` action runs `check --before ship`
  itself.
- `bin/ai-blocker-watch` is bash and must stay Git-Bash compatible; `jq`,
  `base64`, `awk`, `tr` are the allowed tools (all already used by the script).
- Do not weaken the malformed-fence handling to "silent": the issue demands
  skip + count (visible in the tick log), never a crash.
- The watcher never deletes or rewrites links, comments, or issues — it only
  adds. Keep it that way.
- This repository is public: no secrets, no private data, no raw transcripts.

## 8. Access and environment

- Machine: `edge-dev` (the watcher's `propagate_on_host`). OS: Windows; shells:
  Kimi sandbox MSYS2 (flaky, see §4.3) and Git Bash at
  `C:\Program Files\Git\bin\bash.exe`.
- Tools not on the Kimi PATH: `jq` (`C:\Program Files\jq\jq.exe`), `gh`
  (`C:\Program Files\GitHub CLI\gh.exe`; `bin/ai-gh` needs `AI_GH_REAL_GH`).
- `gh` is authenticated as Albert and works through `bin/ai-gh` (used
  repeatedly this session: issue views).
- Shared-db local checkout exists at `C:\repos\shared-db` (read-only reference
  for the fence contract; do NOT change it from this workstream).
- No secrets were touched. Nothing belongs in 1Password from this session.

## 9. Open questions and risks

- (2026-09-18) Will the full suite ever go green locally on edge-dev? Unknown
  — environmental. Mitigation in §0 item 1 / §6 step 2. CI is clean-runner
  authoritative.
- (2026-09-18) The first live links scan on `popcre/shared-db` may create a
  batch of native links at once (every historical `depends_on:` lacking a
  link). That is by design; each creation is logged. If the volume looks wrong,
  `--dry-run` shows the full plan first (§6 step 8).
- (2026-09-18) `links_interval_minutes: 60` is a judgment default mirroring
  `alarm_interval_minutes`; tune via config if the tick log shows waste.
- (2026-09-18) The 19-repo hourly walk fetches full issue bodies; bounded at
  10 pages (1000 issues) per repo per scan. If a repo exceeds that, the scan
  notes it and the tick fails loudly (same contract as the alarm).
- (2026-09-18) Decisions recorded: links only added, never removed; closed
  blockers still linked; self-deps skipped as malformed; separate clock and
  scan from the alarm; new `links` subcommand mirrors `alarm`.

---

*Self-audit (handoff-writer gate): all 10 sections present; §0 sweep run over
§1–§9 (two owner items promoted: the local-tests deviation and the stale-slug
prose sweep; no sub-agents, so no part (b)); every next step has a gate; every
identifier (paths, branch, worktree, tool locations, issue/PR numbers) is
defined inline. Answers: (1) Yes — §3/§6 carry exact state and steps; (2) Yes —
§4/§5 carry the session's hard-won knowledge (environment flakiness proof,
fence contract, design rationale); (3) Yes — background §1–2, state §3,
failures §4, decisions §0/§9, constraints §7, risks §9, actions + gates §6;
(4) Yes — walked §1–§9 line by line: the only owner-requiring sentences are the
local-tests deviation (§3 test evidence, §4.3, §6.2) and the stale-slug
observation (§2 Fix 3 scope) — both are in §0.*
