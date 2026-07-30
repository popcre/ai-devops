---
name: cleanup-worktree
description: >-
  Safely audit, recover, reconcile, and remove stale Git worktrees and temporary
  repository copies created by Codex, Claude, their desktop apps, CLIs, or
  delegated coding agents. Use when Git says a branch is already used by another
  worktree, a branch switch fails because of a path under C:\tmp or another
  unexpected directory, the user asks to clean worktrees or AI housekeeping, or
  old .claude/worktrees, Codex worktrees, detached review checkouts, audit clones,
  and temp repos may be abandoned. Works on Windows PowerShell/Git Bash, WSL,
  Linux, and macOS. Never treats age or an ended chat as proof that work is safe
  to delete.
---

# Cleanup Worktree

Reconcile Git's worktree records with the filesystem, preserve every unique
change, then remove only items proven safe. Cover Codex and Claude equally:
client ownership changes where paths tend to appear, not the Git safety rules.

The non-negotiable rule is:

> Never delete a dirty working copy until every changed file and local commit is
> proven duplicated, superseded, intentionally disposable, or safely preserved.

## 1. Establish scope and protect live work

Read the target repo's `AGENTS.md`, the OPEN handoffs (`HANDOFF.d/` newest-first,
or the legacy root `HANDOFF.md` if it is still a full document), and relevant local rules before
changing anything. If the user asked for a machine-wide audit, scan local fixed
drives and known repository roots, but do not traverse large network mounts
unless explicitly invited.

Before cleanup:

- Record the current repo, branch, status, remotes, and worktree list.
- Check for concurrent AI tasks, live terminal processes, lock files, and recent
  file activity when those signals are available. An ended chat does not prove
  its filesystem worktree is inactive; an active chat may use an ordinary clone.
- Treat the user's primary checkout and every dirty checkout as protected until
  classified.
- Do not switch the primary checkout merely to release a branch. Remove the
  stale linked worktree registration and exact directory after proving safety.
- Do not use destructive Git commands such as `reset --hard` or `clean -fd`.

Explain a branch-lock error in plain English: Git permits one checked-out branch
in only one linked worktree at a time. The unexpected path is a separate working
folder made for isolation; Git remembers it even if the AI task is closed.

## 2. Build the inventory from Git and the filesystem

For every discovered repository, use Git's own record first:

```text
git -C <repo> worktree list --porcelain
git -C <repo> status --short --branch
git -C <repo> branch --all --verbose --no-abbrev
git -C <repo> remote -v
git -C <repo> log --oneline --decorate -20
```

Then inspect each linked path:

```text
git -C <worktree> status --short --branch
git -C <worktree> diff --stat
git -C <worktree> diff
git -C <worktree> log --oneline --decorate --all --max-count=30
git -C <worktree> rev-list --left-right --count <upstream>...HEAD
```

Use `git worktree list --porcelain` rather than guessing from folder names.
Also discover ordinary standalone clones because Git does not list them as
worktrees. Common clues include:

- Codex desktop or CLI paths under temp directories or repo-specific
  `*-worktrees` directories.
- Claude paths under `.claude/worktrees/`.
- Delegated-agent, review, audit, or detached checkouts under temp roots.

For machine-wide discovery, search for both `.git` directories and `.git`
files: linked worktrees normally contain a `.git` file. Resolve
`git rev-parse --path-format=absolute --git-common-dir` for every candidate and
group matching results so each worktree family is audited once.

Do not assume those conventions are exhaustive. Resolve each candidate's
top-level directory, common Git directory, origin URL, HEAD, upstream, status,
and last activity.

## 3. Classify every candidate with evidence

Assign one category:

1. **Active/protected** — a running task or user-designated checkout uses it.
   Leave it unchanged.
2. **Clean and incorporated** — no local changes; its commit is on the required
   target branch, or its merged PR proves incorporation. Safe to remove.
3. **Dirty but duplicated or superseded** — compare the actual diff, blobs, and
   current target files. Similar filenames or commit messages are insufficient.
   Remove only after documenting the proof.
4. **Dirty with unique value** — preserve and ship the work through that repo's
   normal rules: branch/PR where required, direct main only where allowed,
   tests, review, and remote verification. Cleanup follows only after the work
   is durable.
5. **Disposable generated debris** — logs, PID files, screenshots, patches,
   caches, or reserved-name artifacts may be removed only after provenance and
   lack of unique value are established.
6. **Unclear/conflicting** — keep it. Investigate history, PRs, session records,
   and current code. Ask the user only if evidence cannot resolve a material
   choice.

For a branch or commit, prove incorporation with ancestry and remote/PR state,
not just “merged” in a branch name:

```text
git merge-base --is-ancestor <candidate-sha> <target-sha>
git branch --contains <candidate-sha>
git log --cherry-mark --left-right <target>...<candidate>
git cherry <target> <candidate>
git ls-remote --heads origin <candidate-branch>
gh pr list --state all --head <branch> --json number,state,mergedAt,url,headRefName,baseRefName
```

Clean means only “no uncommitted files”; it does not mean the local commits
exist remotely. Treat a clean branch absent from `ls-remote` as unique local
work until incorporation is proved. When changes were recreated or squashed,
ancestry may be false; a `-` result from `git cherry` proves an equivalent patch
is already present. Otherwise compare the full patch and final file behavior,
then record why the newer implementation supersedes the old one.

## 4. Recover valuable work before cleanup

If a candidate contains unique work:

- Read its repo rules and handoff.
- Separate intentional source/docs from temporary artifacts.
- Test the recovered change proportionately.
- Commit with the configured owner identity, push, and complete the repo's
  required PR/merge/deploy workflow.
- Confirm the durable remote SHA contains the intended files.

Do not combine unrelated abandoned changes merely because they were found
together. Do not mutate production, secrets, databases, or deployments unless
the user's request and the repo workflow authorize that work.

## 5. Remove only the exact proven-safe target

Prefer Git-aware removal for linked worktrees:

```text
git -C <main-repo> worktree remove <exact-worktree-path>
git -C <main-repo> worktree prune --verbose
```

Use `--force` only when the evidence review has already proved all dirty or
locked contents disposable or preserved. Never use it to bypass investigation.
After Git removes the registration, delete a leftover directory only after
resolving and rechecking its absolute path.

For an ordinary clone, Git has no parent worktree registration. Remove the exact
verified clone directory only after the same status, commit, PR, and uniqueness
checks.

### Windows-specific cleanup

- Use one shell end-to-end for deletion; prefer native PowerShell cmdlets with
  `-LiteralPath`.
- Resolve the absolute target and prove it is inside the intended temp,
  worktree, or clone directory. Never recursively delete a drive root, user
  profile, repo root, `$HOME`, or an unresolved variable.
- Clear read-only attributes only inside the exact verified cleanup target.
- Reserved device-name artifacts such as `NUL` may require the extended path
  form (`\\?\C:\...`) and a narrowly scoped native deletion. Do not broaden the
  command to the parent directory.
- A failed first removal can leave a directory without a registration, or a
  registration without a directory. Re-run both the Git inventory and the
  filesystem check before retrying.
- Treat a clone showing mass staged deletions plus same-named untracked
  replacements as an integrity warning, not ordinary dirt. Preserve it until
  blob hashes or a fresh clone comparison proves equivalence.
- When permanent recursive deletion is blocked or unnecessary, move only the
  exact verified directory to the Recycle Bin, verify the move, and empty the
  bin only when the user authorized permanent deletion.
- Distinguish native PowerShell, Git Bash, and WSL. Windows environment variables
  and paths do not automatically cross into WSL.

### Linux and macOS cleanup

- Resolve candidates with `realpath` (or the platform equivalent) before
  recursive removal.
- Do not cross mount points or scan network volumes without permission.
- Check ownership and permissions before changing them; do not run Git as root
  in a user-owned repo merely to make cleanup easier.

## 6. Clean branches and metadata last

Only after worktrees are gone:

- Prune stale worktree metadata and remote-tracking references.
- Delete a local branch only when its work is incorporated or intentionally
  discarded with evidence.
- Delete a remote branch only when the repo convention permits it and no active
  PR/task needs it.
- Leave unrelated branches and caches alone. “Housekeeping” is not authority to
  rewrite history, remove active environments, or alter canonical data.

## 7. Verify and report in business English

Finish with a fresh machine-wide or scoped audit:

- `git worktree list --porcelain` has only intended linked worktrees.
- No removed branch remains locked by a stale registration.
- Protected repos remain clean or retain their pre-existing changes.
- Recovered work exists at the verified remote SHA/PR.
- Exact removed directories no longer exist.
- No active task or network-mounted directory was touched.

Report:

1. What was safely removed and why.
2. What valuable work was recovered, with commit/PR evidence.
3. What remains and why it is protected or uncertain.
4. Whether cleanup is recoverable (for example, work preserved on GitHub) and
   any intentionally deleted material that is not.

Avoid unexplained Git terminology. Say “a separate working folder still reserved
the `main` branch” before mentioning “linked worktree.”

## Relationship to other skills

- Use `close-old-session` when reconciling the stale task's remembered to-do
  list. Use this skill for the machine and Git working-copy cleanup itself.
- Use the repo's normal ship/closeout skill for recovered source changes.
- Use `cleanup-worktree` again after shipping to remove only the now-safe
  temporary working copy.
