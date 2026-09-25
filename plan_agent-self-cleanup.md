# Implementation plan — AI agents clean up after themselves

| Step | Status | Evidence |
|------|--------|----------|
| 1. Shrink what a review copies | ✅ done — merged `af80fcf0f11b66f99fa794ad159b4b6f110eae2d` (PR #797, Muse APPROVE at exact head; bounded shallow snapshots, not files-only: the packet/lifecycle tools run git inside the snapshot, so a no-`.git` shape cannot work — `tests/test-ai-review-snapshot-bounded-history.sh`, `tests/test-ai-review-sandbox.sh` 108/108, packet 138/138) | real-worktree dry run: 15 MB / 13 commits / 17 s vs old full clone 461 MB / 1,206 commits / 63 s; a real Muse review of PR #797 ran entirely inside a bounded snapshot |
| 2. Delete the copy when the review ends | ✅ done — merged `41f8e75ab4e2ad0a496547fffec427fe110ed956` (PR #823, Muse final APPROVE at exact head 6026815b): `with-copy` run wrapper in `bin/ai-review-sandbox` deletes on success/failure/abort via EXIT/INT/TERM trap; `AI_KEEP_SANDBOX=1` debugging exception; path-guarded delete unchanged; kimi start-failure paths release the snapshot (`tests/test-ai-review-sandbox-self-cleanup.sh` 22/22, `tests/test-ai-review-sandbox-delete-guard.sh` 9/9 + 4 symlink skips where `ln -s` is unavailable, `tests/test-ai-review-sandbox.sh` 108/108). Issue #802 one-line kimi refresh-copy base-hint fix landed here (`tests/test-ai-review-snapshot-bounded-history.sh` 23/23) | creating run deletes before returning; `AI_KEEP_SANDBOX=1` keeps |
| 3. Parent process sweeps orphans | ⬜ open | |
| 4. Daily sweep as backup only | ⬜ open (task already installed on this machine) | `AI-Debris-Housekeeping` scheduled task, 03:30 daily |
| 5. Prove it live with one real review | ⬜ open | |

**Where a fresh session starts:** Phase 3 (parent orphan sweep; plan §9 Phase 3). Re-read this STATUS table before each phase.

Related handoff: [HANDOFF.d/2026-09-25T1343Z-edge-dev-mimo-agent-self-cleanup-phase3.md](HANDOFF.d/2026-09-25T1343Z-edge-dev-mimo-agent-self-cleanup-phase3.md) (issue [#711](https://github.com/popcre/ai-devops/issues/711)). Do not rewrite root `HANDOFF.md`.

---

## 1. The ultimate goal — what we are actually trying to achieve

When an AI review (or any AI helper) creates a temporary working copy, **the same run deletes it before it returns**. Temporary review folders stop piling up on the C drive. A daily sweeper remains only as a crash backup — it is not the primary cleanup.

If a step conflicts with this goal, the goal wins — stop and flag it.

Business outcome: Albert's computer stops nearly filling its system disk because of leftover AI working copies. He is not a programmer; the fix must be automatic, not a habit he has to remember.

## 2. What this application is

**POP Creations / ai-devops** is Albert Hazan's AI development-operations toolkit. It dispatches AI reviewers (Claude, Codex, Gemini, Grok, Qwen, GLM, DeepSeek, Muse) to review pull requests and issues across these GitHub repositories:

| Repo | Purpose |
|------|---------|
| `popcre/ai-devops` (local `C:\repos\ai-devops`) | Reviewer wrappers, sandbox helpers, policies |
| `u2giants/shared-db` (local `C:\repos\shared-db`) | Shared Supabase schema (structure only via its PR flow) |
| `u2giants/licensor-source-data` | Licensor scrape landing data |
| `popcre/poppim-web`, `popcre/popdam3` | Product apps |

Stack: shell/PowerShell wrappers under `bin/`, Python tools under `tools/`, config under `config/`. Runs on Albert's Windows workstation (hostname `EDGE-DEV`). Reviewers are invoked as local CLI processes.

**Sandbox creation today (the mess):** `bin/ai-review-sandbox` (and callers such as `bin/ai-review-packet`) copy a full Git working tree into

```
C:\Users\ahazan\.local\state\ai-devops\review-sandboxes\<name>
```

Each copy is a **full clone including `.git` history**. On 2026-09-23 that directory held **3,950 copies / ~192 GB**. Each copy's `AI-REVIEW-SANDBOX.md` already says the copy is "disposable… deleted when the review session ends" — deletion was never enforced.

As of 2026-09-23 that path is a **directory junction** to `D:\ai-data\local\state\ai-devops\review-sandboxes` (HDD). New copies land on D. That prevents C from filling again but does **not** stop unbounded growth on D. This plan fixes the growth at the source.

## 3. What triggered this work

Albert (owner), 2026-09-23, after C: dropped to **5 GB free**:

> "on this computer there's something wrong with the `C:\Users\ahazan\.local` and `C:\Users\ahazan\.codex` folders. they're taking up the entire C drive. Fix it"

Cleanup recovered ~230 GB. Then Albert, same day:

> "daily auto-cleanup is a blunt tool, and needed as a backup. But i think the best strategy is for the agent that made the mess to clean up after itself."

> "so how do we do that? write an implementation plan."

Also from the same thread (locked design input):

> "does a review really need a full copy of a codebase's entire history?" — **No.** Owner is right; see §8.

## 4. Scope

### In scope
1. Make review copies **small** (no full history).
2. Make the **creating run delete its own copy** in a guaranteed cleanup path (success, failure, timeout, cancel).
3. Make the **parent wrapper sweep orphans** left by killed children.
4. Keep the **daily Windows scheduled task** as backup only (`AI-Debris-Housekeeping`, already installed on this machine).
5. Apply the same create/cleanup discipline to **Codex worktree groups** under `C:\Users\ahazan\.codex\worktrees` (now junctioned to `D:\ai-data\codex\worktrees`).
6. One **live proof** with a real review, then a leftover-proof issue if live proof is deferred.

### NOT in this plan (explicit)
- Moving more folders to D: (already done for the growth paths; see §5).
- Cleaning the six dirty leftover work folders (separate session; prompt already written: `prompt-for-six-worktrees.md`).
- Changing reviewer model choice, prompts, or review quality.
- Shared-database schema/structure work (route via `u2giants/shared-db` if ever needed).
- Rewriting `HANDOFF.md` root files.
- Deleting live repos under `C:\repos`.
- Changing 1Password / secrets layout.
- Cross-machine fleet management (this workstation only).

## 5. Current state of the code / machine (2026-07-23 is NOT the date — **2026-09-23**)

### Machine layout after today's cleanup (verified)

| Path | Role | Where bytes live now |
|------|------|----------------------|
| `C:\repos\` | Canonical landing-only checkouts | C: (SSD) — **keep on SSD** |
| `C:\Users\ahazan\.local\bin`, `.local\lib` | Tool programs | C: (SSD) — **keep on SSD** |
| `C:\Users\ahazan\.codex\packages`, `plugins`, `config.toml`, `auth.json` | Codex app + config + secrets | C: (SSD) — **keep on SSD** |
| `C:\Users\ahazan\.local\state\ai-devops\review-sandboxes` | Review copies (growth) | **Junction → `D:\ai-data\local\state\ai-devops\review-sandboxes`** |
| `C:\Users\ahazan\.codex\worktrees` | Codex task worktrees (growth) | **Junction → `D:\ai-data\codex\worktrees`** |
| `C:\Users\ahazan\.codex\archived_sessions`, `sessions` | Chat logs (growth) | **Junction → `D:\ai-data\codex\...`** |
| `C:\Users\ahazan\.local\state\ai-devops\grok` | Grok reviewer state (growth) | **Junction → `D:\ai-data\local\state\ai-devops\grok`** |
| `C:\Users\ahazan\.local\share\ai-devops` | Some helper installs | Still on C: (was locked by `opencode` process). Finish move when tools closed. |
| `C:\Users\ahazan\.codex\thread_history_1.sqlite`, `logs_2.sqlite` | Codex history DBs (growth) | Still on C: (locked while Codex runs). Move when Codex closed — script ready: `move-bulk-to-d.ps1` |

Drives: **C: = 512 GB NVMe SSD (fast)**. **D: = 1 TB HDD (slow, roomy)**. After cleanup C: ~267 GB free.

**SSD vs HDD rule (locked):** speed-sensitive stays on C: (live code, tool binaries, packages, auth/config). Bulk/growth goes to D: (review copies, worktrees, session logs, archives, thread history). Do not put live Git checkouts used for day-to-day coding on D: — HDD latency will make every command feel slow.

### Code that creates the mess (inspect in `C:\repos\ai-devops` on a fresh worktree)

Find the real call sites before editing (do not trust this list blindly):

```
bin/ai-review-sandbox
bin/ai-review-packet
bin/ai-review
bin/ai-gemini / bin/ai-grok-review / bin/ai-glm / kimi/qwen/muse wrappers
```

Search for: `review-sandboxes`, `AI-REVIEW-SANDBOX`, `git clone`, `cp -a`, `robocopy`, `worktrees`.

Each sandbox already writes:
- `AI-REVIEW-SANDBOX.md` — states disposable + should be deleted at session end
- `.ai-review-sandbox` — marker with source path + digest

### Daily backup sweeper (already installed — do not rebuild from scratch)

- Script: `C:\Users\ahazan\.local\bin\ai-housekeeping\cleanup-ai-debris.ps1`
- Task: `AI-Debris-Housekeeping`, daily 03:30, host `EDGE-DEV`
- Log: `D:\ai-data\logs\housekeeping.log`
- It deletes: review sandboxes >24h old, worktree groups >7d old that are clean and not on a small preserve list, archived sessions >14d old, codex root `*.bak`/`*.tmp-*` debris >7d old, stale `gemini-live-*` folders >3d old.
- It must **skip** anything dirty or on the preserve list. It is a net, not a broom.

## 6. Key findings and root cause

1. **Root cause of the 192 GB:** every review copied a full repository including `.git` object history. ~50 MB × 3,950. History is not needed to read a diff. (`AI-REVIEW-SANDBOX.md` in each copy documents the design: "disposable, self-contained snapshot".)
2. **Root cause of the pile-up:** cleanup was specified in prose ("deleted when the review session ends") but **not enforced in code**. No `trap`/`finally`, no parent sweep, no scheduled task until 2026-09-23.
3. **Second pile-up site:** `C:\Users\ahazan\.codex\worktrees\` held 160 Codex task folders (34 GB). 154 were clean/empty and removed 2026-09-23. **Six remain with uncommitted work** (Codex-owned) — separate investigation, do not delete here.
4. **Windows cost:** deleting or moving tens of thousands of tiny Git object files is extremely slow (minutes to hours). Smaller copies fix both disk use *and* cleanup time. Prefer fewer large files over millions of tiny ones where design allows.
5. **Junctions work** and keep every existing config path valid (`mklink /J`). No tool needed a config rewrite. Do not "fix" paths by editing every config when a junction will do.
6. A previous manual sweep on 2026-09-11 removed 14,664 items (`review-sandboxes-cleanup-20260911.log`) — proof this is a recurring leak, not a one-off.

## 7. Approaches considered and REJECTED

| Approach | Why rejected |
|----------|----------------|
| Rely on daily deletion only | Blunt; owner explicitly said it is backup only. Delay of up to 24h still allows a runaway day to fill D:. |
| Tell agents in a prompt to clean up | Prose without code enforcement is what caused this. Prompts drift; traps do not. |
| Keep full clones "so reviewers can run git log" | Reviewers need the diff under review and the files at that revision. `git log` against full remote history is rare and can use the real worktree or GitHub UI. 192 GB says the tradeoff is wrong. |
| Move everything to D: and stop | Stops C: from crashing but grows D: without bound (D: is 1 TB). Owner asked for cleanup-at-source. |
| Put live `C:\repos` on D: too | Owner's coding latency would tank. SSD holds live code (see §8). |
| Delete dirty worktree leftovers in this plan | Six folders hold uncommitted work. `cleanup-worktree` skill: never delete dirty copies without proof. Separate session owns that (prompt already written). |
| Use Recycle Bin for the 192 GB | Bin would hold 192 GB on the same volume — defeats the purpose. These copies are documented disposable snapshots; source of truth is GitHub + real worktrees. |
| One shared mutable cleanup log/index in the repo | Concurrent agents would clobber it (same failure mode as shared `HANDOFF.md`). |

## 8. Design decisions already made

### Locked (do not relitigate)

1. **(2026-09-23, owner)** The agent/run that creates a temporary copy must delete it before it returns. Daily sweeper is backup only.
2. **(2026-09-23, owner)** A review does **not** need full Git history. Copy a **exported snapshot** of the tree at the review revision + the patch under review.
3. **(2026-09-23)** SSD vs HDD split as in §5. Live code + tool programs on C:. Growth/bulk on D: via junctions.
4. **(2026-09-23)** Existing paths stay stable. Prefer junctions over rewriting every config (`CODEX_HOME`, wrapper paths, etc.).
5. **(2026-09-23)** Daily task `AI-Debris-Housekeeping` stays. Implementers may tighten its rules but must not remove it until self-cleanup has been live-proven for 14 days.
6. **(2026-09-23)** Six dirty Codex work folders are **out of scope** and must remain until their dedicated session ships or discards them.

### Open (implementer judgment)

1. Exact snapshot shape: `git archive` vs `git clone --depth 1` vs copy worktree without `.git`. Criteria: reviewer must read any file at the review revision and apply/read the diff; total copy size target **< 50 MB for typical repos** (today is ~50–80 MB with history); creation time **< 10s** on this machine.
2. Whether reviewers may run `git diff` inside the snapshot (then keep a minimal `.git` or provide the patch as a file) vs only read files + a `patch.diff`. Default recommendation: **files + `patch.diff` + metadata file**; no `.git`. If a wrapper needs `git diff`, use `--depth 1` single-commit clone.
3. Language of the trap: `bash` `trap` in `bin/ai-review-sandbox` vs PowerShell `try/finally` if any wrapper is PS. Match each file's existing language.
4. Preserve-list maintenance: which worktree folder names stay protected (today's six). Keep the list in one config file, not scattered literals.

## 9. The plan — numbered, executable steps

### Phase 1 — Shrink the copy (context cut point after this phase)

**Step 1.1 — Inventory the real creation path**

- In a **new worktree** from current upstream of `popcre/ai-devops` (never edit `C:\repos\ai-devops` directly for this work):
  ```
  git -C C:\repos\ai-devops worktree add C:\tmp\ai-devops-self-cleanup-<agent> -b <agent>/agent-self-cleanup origin/main
  ```
  (Adjust remote default branch if `main` is not it — check `git rev-parse --abbrev-ref origin/HEAD`.)
- Read `bin/ai-review-sandbox`, `bin/ai-review-packet`, and any caller that mentions `review-sandboxes`.
- Record every function that copies a tree. Name them in the PR description.
- **Verification gate:** you can point to the exact line that copies the tree and the exact line that should (but does not) delete it.

**Step 1.2 — Replace full copy with a small snapshot**

- New helper, e.g. `bin/ai-review-snapshot` (keep name consistent with repo style):
  - Inputs: source worktree or repo path, revision SHA, output directory under `review-sandboxes/`, name.
  - Behavior:
    1. Create output dir.
    2. Export tracked files at that revision (`git -C <src> archive <rev> | tar -x -C <out>` on Git Bash, or `git checkout-index` / equivalent). **Do not copy `.git`.**
    3. Write `patch.diff` (full diff under review) into the snapshot root.
    4. Write `AI-REVIEW-SANDBOX.md` with: disposable banner (keep existing wording), source path, revision SHA, snapshot tool version, `created_at`, and **"this run must delete this directory before returning."**
    5. Write `.ai-review-sandbox` marker (keep format compatible: source path + digest).
  - Untracked files that the reviewer must see: copy only those explicitly passed by the caller (allowlist), never a blind `cp -a` of the worktree.
- Update `bin/ai-review-sandbox` (and packet tool) to call the helper instead of full clone/copy.
- **Verification gate:**
  ```
  bin/ai-review-sandbox --help   # or existing equivalent
  # after one dry run against a real worktree:
  test ! -e "$SNAP/.git"           # no history
  du -sh "$SNAP"                   # expect well under 100 MB
  test -f "$SNAP/patch.diff"
  test -f "$SNAP/AI-REVIEW-SANDBOX.md"
  ```

**Step 1.3 — Compatibility check**

- Confirm every reviewer wrapper that mounts a sandbox only reads files + patch (grep wrappers for `git -C`, `git log`, `git show`).
- If one wrapper requires real Git history: give that wrapper `--depth 1` instead of full history, and note it in the PR.
- **Verification gate:** `rg -n "git (log|rev-list|cat-file)" bin/` shows no wrapper that needs full history, or each hit is explained in the PR.

### Phase 2 — Self-cleanup in the creating run (depends on Phase 1)

**Step 2.1 — Guaranteed delete on the way out**

- In `bin/ai-review-sandbox` (bash):
  ```
  SNAP=...
  cleanup() { rm -rf -- "$SNAP"; }
  trap cleanup EXIT
  ```
  - `trap` must cover success, failure, and `set -e` aborts.
  - Guard the delete: only remove if path is under `.../review-sandboxes/` and matches the created name (never `rm -rf` a caller-supplied free path).
- If any PowerShell wrapper creates copies: `try { ... } finally { Remove-Item -LiteralPath $snap -Recurse -Force }` with the same path guard.
- **Exception (locked):** if `AI_KEEP_SANDBOX=1` (or repo-standard env name), skip delete and print the path — for debugging only. Document in the script header.
- **Verification gate:**
  ```
  bin/ai-review-sandbox <normal args>   # success path
  test ! -d "$SNAP"
  bin/ai-review-sandbox <args that fail mid-review>
  test ! -d "$SNAP"
  AI_KEEP_SANDBOX=1 bin/ai-review-sandbox <args>
  test -d "$SNAP"
  ```

**Step 2.2 — Same discipline for Codex worktree groups**

- When a Codex task creates `C:\Users\ahazan\.codex\worktrees\<name>\...` (junction to D:), the task's closing step removes that group **only if** `git status` is clean and no local-only commits (or they were shipped).
- If dirty: leave it and write a one-line note to `D:\ai-data\logs\housekeeping.log` (or the repo's reviewer-events path) so the daily sweep and humans can see it. **Never delete dirty.**
- Prefer `git worktree remove` when the group is a linked worktree of `C:\repos\<repo>`; then `git -C C:\repos\<repo> worktree prune`.
- **Verification gate:** run one throwaway task; on completion `worktrees/<name>` is gone; `git -C C:\repos\ai-devops worktree list` has no stale entry.

### Phase 3 — Parent sweep for orphans (depends on Phase 2)

**Step 3.1 — Orphan sweep at parent start**

- Wrappers that spawn reviewers (`bin/ai-review`, pool scripts) run a **bounded** sweep at start:
  - Remove `review-sandboxes/*` whose `.ai-review-sandbox` marker age > 2 hours AND no matching live PID file if you write one at create time.
  - Do not touch anything younger than 2 hours (concurrent reviews).
- Keep this cheap: only list the sandbox root, not recursive scans of all repos.
- **Verification gate:** plant a fake sandbox with an old timestamp marker; start a parent run; fake dir is gone; a 10-minute-old dir remains.

**Step 3.2 — PID marker (optional but recommended)**

- On create, write `sandbox.pid` with the wrapper PID and start time.
- Orphan rule: marker older than 2h OR (PID not running AND age > 15 min).
- **Verification gate:** kill a wrapper mid-review (`taskkill`); after 15+ min the parent sweep or daily task removes it.

### Phase 4 — Daily backup only (already installed — tighten, do not replace)

**Step 4.1 — Align sweeper with new rules**

- Edit `C:\Users\ahazan\.local\bin\ai-housekeeping\cleanup-ai-debris.ps1` only if Phase 2 changes paths or marker names.
- Keep preserve-list for the six dirty work folders until that separate session finishes.
- Keep age thresholds: sandboxes 24h, worktrees 7d (clean only), archives 14d.
- **Verification gate:** `schtasks /Run /TN AI-Debris-Housekeeping` then read `D:\ai-data\logs\housekeeping.log` for a completed line with C/D free space.

**Step 4.2 — Do not remove the task until proven**

- After 14 days of reviews with zero leftover sandboxes older than 24h, the owner may retire the task. Not before. (Locked.)

### Phase 5 — Live proof (one unproven outcome)

**Step 5.1 — One real review end-to-end**

- Dispatch one real, low-risk review with the new wrapper (e.g. a docs-only PR).
- After it returns, on the machine:
  ```
  # no leftover sandbox older than the run
  ls "D:\ai-data\local\state\ai-devops\review-sandboxes"
  ```
- Record free space before/after in the PR.
- **Verification gate:** zero sandboxes from that run remain; wrapper log shows cleanup line; reviewer still produced a usable verdict.

**Step 5.2 — Leftover-proof rule**

- If code merges without live proof in the same session, open **exactly one** leftover-proof issue in `popcre/ai-devops` before that session ends, assign an owner (`owner:` line), and link the PR. Never batch proofs for a later chat.

**Context cut points:** end of Phase 1, end of Phase 2, end of Phase 5. Re-read §8–§9 before starting the next phase (drift check). Use `fresh-session` at each cut if the context is full.

## 10. Tests required

Named tests (adapt paths to the repo's existing test layout — `tests/` has shell tests today):

1. `tests/test-ai-review-snapshot-has-no-git.sh` — snapshot creates `patch.diff` + marker, and **no** `.git` directory.
2. `tests/test-ai-review-sandbox-self-cleanup.sh` — success path deletes snapshot; failure path deletes snapshot; `AI_KEEP_SANDBOX=1` keeps it.
3. `tests/test-ai-review-sandbox-delete-guard.sh` — cleanup refuses to delete a path outside `review-sandboxes/` (pass a malicious/wrong path; assert it still exists).
4. `tests/test-orphan-sweep-age.sh` — fake old sandbox removed; young sandbox kept.
5. Existing suite must stay green: run whatever `tests/` entrypoint the repo already uses (look for `tests/test-ai-review-lifecycle.sh` and the repo's CI workflow). Never invent a new framework.

Do not say "add tests" in a PR without these names or a written reason why one does not apply.

## 11. Constraints, standing rules, and gotchas in force

- **Worktree rule:** do not edit `C:\repos\ai-devops` (or any canonical checkout) for this work. Create a uniquely named worktree from current upstream; verify `git status --short --branch` before every commit.
- **Branch policy:** never push to protected `main` directly. Branch → PR → merge it yourself (Albert does not merge), unless DesignFlow (`develop`, never self-merge) or Albert says he wants to review.
- **Docs-only PRs** (every changed file is prose) merge immediately with owner override — do not wait for checks.
- **Signature:** every GitHub issue/PR/comment ends with `Posted by <Claude|Codex> chat <id> on <machine>` (`unknown` if id empty).
- **Shared-db:** structure changes only via `u2giants/shared-db` branch+PR. This plan should not need any.
- **Secrets:** 1Password vault `vibe_coding` only. Never put values in chat, args, logs, or commits.
- **Destructive deletes:** only inside `.../review-sandboxes/<created-name>` or a proven-clean worktree group. Never `rm -rf` a free-form path. Never delete dirty working copies (see `cleanup-worktree` skill).
- **Windows:** use one shell end-to-end for deletion; `-LiteralPath`; watch for reserved names (`NUL`); clear read-only attributes only inside the exact target; junctions already exist — do not double-link.
- **No silent failures:** cleanup must log one line per deleted sandbox to the housekeeping log (or script stderr captured by the wrapper).
- **Do not bundle** this with the six dirty work folders cleanup.
- **Output discipline:** keep routine command output short; put long logs in a scratch file.

## 12. Access and environment

- Machine: `EDGE-DEV`, Windows, user `ahazan`.
- Git identity must be `Albert Hazan <u2giants@users.noreply.github.com>` — run `git var GIT_COMMITTER_IDENT` before the first commit.
- GitHub: `gh` authenticated as Albert's accounts (`u2giants` personal, `popcre` DesignFlow only — never mix).
- Secrets: 1Password vault `vibe_coding` (item titles only in docs; never values).
- Local repos: `C:\repos\ai-devops`, `C:\repos\shared-db`, `C:\repos\licensor-source-data`, `C:\repos\poppim-web`, `C:\repos\popdam3`.
- Growth data root (via junctions): `D:\ai-data\`.
- Daily task: `AI-Debris-Housekeeping`.
- Claude/MiMo memory and skills live under `C:\Users\ahazan\.local\share\mimocode` and `C:\Users\ahazan\.agents` — do not relocate them in this plan.
- Codex home: `C:\Users\ahazan\.codex` (`CODEX_HOME` in its `config.toml`) — do not rewrite that config in this plan; junctions already cover growth paths.

## 13. Definition of done + risks and open questions

### Definition of done
- [ ] Phase 1–3 code merged to the repo's mainline via PR (or `develop` if that repo uses it).
- [ ] Named tests in §10 pass in CI.
- [ ] One live review (Phase 5) left **zero** sandboxes from that run; evidence linked in the PR.
- [ ] If live proof deferred: exactly one leftover-proof issue open, assigned, with `owner:` line.
- [ ] Daily task still installed and logged success once after the change.
- [ ] Plan STATUS table updated (done rows cite a commit SHA or test path — never a bare count).
- [ ] `HANDOFF.d/` file created in `ai-devops` linking to this plan; this plan links back. Root `HANDOFF.md` untouched.
- [ ] Albert gets a plain-English closeout: what changed, proof, what is still open.

### Risks
| Risk | Mitigation / rollback |
|------|------------------------|
| A reviewer wrapper secretly needs `.git` history | Phase 1.3 grep; fallback `--depth 1` for that wrapper only |
| `trap` misses a kill -9 / crash | Phase 3 parent sweep + daily backup task |
| Snapshot deletes a path outside its folder (bad `rm`) | Delete-guard test + path prefix check + only delete the name created in this run |
| Junction confusion (someone deletes "the folder" and loses D: data) | Document in `AGENTS.md` / machine atlas: those paths are junctions; delete the junction only after moving data back |
| Concurrent reviews collide on names | Name = caller + timestamp + random suffix (keep existing convention) |
| Daily task deletes a live review older than 24h | Keep 24h floor; Phase 2 should make long-lived copies rare; `AI_KEEP_SANDBOX` for debugging only |

### Open questions
1. Snapshot format final pick (`git archive` vs shallow clone) — decide in Phase 1.2 with size/time measurements on this machine.
2. Whether Muse/DeepSeek private-review paths need a different untracked-file allowlist — inspect their wrappers in Phase 1.3.
3. After 14 days green, does Albert want the daily task retired or kept as belt-and-braces? (Recommendation: **keep it**.)

---

## Self-audit (required by implementation-plan-writer)

1. **Could a brand-new AI session with no project knowledge execute this without asking anything?**  
   Yes — §2 names the product/repos/paths; §5 gives the machine layout and junctions; §9 steps name `bin/ai-review-sandbox`, `bin/ai-review-packet`, exact env flag `AI_KEEP_SANDBOX`, exact task name `AI-Debris-Housekeeping`, and verification commands; §12 lists access. Gap found and fixed: original draft said "2026-07-23" in §5 header — corrected to **2026-09-23**.

2. **Does it carry every piece of background, nuance, and reasoning I currently hold — including what we ruled out and why?**  
   Yes — §3 quotes the owner; §6 records the 192 GB / 3,950 copies / 14,664 prior sweep; §7 rejects daily-only, prompt-only, full-clone, move-only, SSD-to-HDD of live repos, dirty-worktree deletion, Recycle Bin, shared mutable index; §8 locks six decisions and lists three open ones.

3. **Is the ultimate goal clear enough for judgment calls when a step is wrong?**  
   Yes — §1 states the business outcome (Albert's disk stops filling; cleanup is automatic) and the override rule "if a step conflicts with this goal, the goal wins."

**Checklist:** 13 sections present; goal up top with override; rejected approaches named; steps have file targets + verification gates; locked vs open labeled; out-of-scope list present; tests named; terms/paths defined; secrets by vault name only; DoD includes commit/PR/CI/live proof; HANDOFF.d cross-link instructed (§ STATUS header + §13).

**Final answers:** Yes / Yes / Yes, with the one gap fixed (date typo in §5).
