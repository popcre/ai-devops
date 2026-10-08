# Deployment

For this repo, "deployment" means **installing the toolkit onto a host** — there
is no cloud release, container, or CI/CD. Canonical guide:
[`../AGENTS.md`](../AGENTS.md). First-time / disaster restore:
[`restore-from-zero.md`](restore-from-zero.md).

## What "deploy" means here

- GitHub Actions runs offline Linux and Windows verification only. It never
  installs onto or mutates a production machine.
- **No** container image, registry, or tag pattern — nothing is built or
  published.
- **No** hosting platform, Coolify/Supabase app, or project ID.
- The toolkit is git-cloned to `/worksp/ai-devops` and installed locally with
`install.sh`. Access to the host is via ordinary SSH; there is no deploy
  automation over SSH.

Dotfiles sync uses commands-only repair tools for repo-owned Grok, Kimi,
DeepSeek, and GLM launchers. The shared list is `config/machine-tools.tsv`.
Use `bin/ai-machine-tools-doctor` to check it, then the matching narrow installer
in `bin/`. These tools do not change secrets, MCP, SSH, packages, or services.
The generic executable loop in `install.sh` remains the Ubuntu fresh-install
owner and is intentionally unchanged.

A new script in `bin/` is therefore NOT a usable command on Windows until it
also has a row in `config/machine-tools.tsv`. Ubuntu picks it up from the
`install.sh` glob, which hides the gap; the Windows launchers come only from
the catalog. Add the row in the same change that adds the script, or sessions
will be told to run a command that does not exist on the machine.

The Windows runner maintenance boundary is the one narrow exception to the
global command catalog. Its explicit `.ps1` entrypoints are installed only by
an elevated administrator following
[`independent-windows-runner-setup.md`](independent-windows-runner-setup.md).
They create one fixed S4U scheduled task and a hash-verified protected payload;
they are deliberately not added to `config/machine-tools.tsv`. Installation,
update and removal are protected deployment actions and require the repository
task gate plus exact-host approval. Offline tests must mock Task Scheduler and
ACL behavior and may not register a real task.

## Install

```bash
cd /worksp/ai-devops
./install.sh
```

`install.sh`:
1. Verifies/installs base dependencies (`git`, `curl`, `jq`, `ripgrep`,
   `unzip`, `python3`, `pip3`, and `gh`). It detects, installs, and verifies
   `node`, `npm`, and `npx` independently.
2. Creates `/etc/ai-devops/` and `/var/log/ai-devops/`.
3. Seeds `/etc/ai-devops/models.env` and `server.env` from the examples **only if
   absent**, then runs the versioned merge-based config migrator (never
   overwrites user values).
4. Authenticates and fast-forwards the private protected-configuration checkout,
   then resolves SSH topology and provider identifiers through
   `ai-private-config`.
5. Symlinks executable Unix entrypoints in `bin/` into `/usr/local/bin/`.
   Windows-only `.ps1`/`.bat` files are not chmodded or linked, so an update
   leaves the Git checkout clean. The next stage installs the managed
   `hooks/post-merge` reviewer auto-requalification hook (#804) through
   `bin/ai-install-post-merge-hook`: after a pull merges new reviewer wrapper
   code, any reviewer whose live qualification no longer matches its
   installed wrapper, runtime, or preloader bytes is re-qualified
   automatically (`ai-review-preflight requalify`); a failed requalification
   is recorded with `ai-reviewer-issue record` and printed. A hook without
   the managed marker is foreign and left untouched. The Windows installer
   runs the same script (and its own end-of-run requalify) on its real
   (non-dry-run) path.
6. Runs the canonical `ai-install-skills` installer so client-specific and shared
   skills use the same collision-safe behavior on Ubuntu and Windows. The shared
   `ask-glm` skill reaches both Claude and Codex. Secret setup injects
   the Z.ai Coding Plan key from 1Password, proves a real GLM-5.3 OpenCode
   agent call, and installs the protected Muse review profile into its isolated
   configuration root; non-interactive updates reuse the existing protected
   bootstrap file automatically and never change normal Claude/Codex
   authentication. The user install also prepares Qwen's and DeepSeek's
   protected per-user key stores. Their reviews read those stores without
   calling 1Password; `ai-qwen store-key` and `ai-deepseek-agent store-key`
   explicitly refresh them after key rotation.
7. Clones, validates, and manually seeds the private portable-memory hub. On a
   new Claude home with no project memory yet, this truthfully reports a
   fresh-machine seed and uploads nothing; matching project memory is applied
   by a later explicitly initiated sync after Claude creates the project.
8. Schedules **BlockerWatch** — the `ai-blocker-watch` system (optional stage):
   a marked, idempotent user crontab entry running `ai-blocker-watch tick`, so
   legacy wait records on this machine are re-surfaced (registration is OUT;
   #1183 child 3). Windows
   machines get the same outcome from `bin/install-ai-devops-windows.ps1`, which
   registers the Task Scheduler job via the same `schedule` command. Only the
   machine named by `propagate_on_host` in `config/blocker-watch.json` posts
   blocker comments; every other machine just wakes its own sessions.
   The Windows installer also schedules `ai-reviewer-start-watch tick` every
   `schedule_every_minutes`, but only on the one machine named by
   `run_on_host` in `config/reviewer-start-watch.json`: it reroutes shared-db
   reviewers that were drawn but never started, and drawing the replacement
   needs this machine's `ai-review-preflight` and reviewer wrappers. Its state
   and `tick.log` live in `~/.ai-devops/reviewer-start-watch`.
9. Schedules the shared-db worktree reap (optional stage): one marked,
   idempotent `ai-reap-shared-db-worktrees schedule` registration per platform
   (Task Scheduler on Windows, user crontab elsewhere), so merged shared-db
   worktrees retire themselves daily on every agent machine. Machines without a
   shared-db checkout schedule the sweep anyway; the run exits 0 with nothing
   to reap until one appears. All safety refusals live in shared-db's reaper.
   CI **watchdog** timers (queue-slow, runner-pool, drift) belong to the
   **watchdog duty pool** — see [`watchdog-duty-pool.md`](watchdog-duty-pool.md)
   for claim/lease rotation and how to add a machine; never paid Blacksmith.
   The installer schedules `ai-local-watch tick-all` (Task Scheduler / user
   crontab) only on hosts listed in `config/local-watch.json` `watch_hosts`
   (edge-dev, edge-dev3, hetz). That single entry claims the duty lease and
   runs the four watchdog ticks. GitHub Actions stay as a free weekly backup.
10. Records exact source, config, owned symlinks, config files, managed
    skill markers, and hashes in `/etc/ai-devops/install-manifest.tsv`.
11. Runs `ai-devops doctor`.

Recovery-critical WinGet, npm/MCP, and model versions are governed by
`config/tool-versions.json`. The install and Windows bootstrap paths use those
reviewed pins; `tests/test-tool-version-pins.sh` prevents a mutable `latest`
specifier or a consumer/catalog mismatch. Upgrades are deliberate repository
changes, not an incidental side effect of deployment.

Every operation is an explicit required, optional, or skipped stage. The final
summary names every result, and any required failure makes the installer
nonzero after preserving the successful earlier stages. Secrets are required
when an interactive/token-backed install selects them; `--require-secrets`
forces that mode and `--skip-secrets` records an intentional skip.

Idempotent — safe to re-run.

For an update containing reviewer-safety paths, leave the installed checkout
unchanged while preparing two linked worktrees: a disposable installation
candidate at its current HEAD and a separate reviewer candidate at the exact
merged target. From the installation candidate, run the target worktree's
reviewed gate with `start --class installation`, then advance only that
candidate to the target commit. Declare the separate reviewer candidate as
`reviewer-safety` and obtain its read-only exact-head independent `APPROVE` review.
Run `ai-task-gates authorize-install --target-head <full SHA>
--installed-checkout <canonical checkout> --installed-launcher <managed
ai-task-gates launcher> --review-report <exact-head APPROVE report>
--reviewer-approval <exact-head APPROVE report>`. On Windows, pass
the managed extensionless launcher; on Ubuntu, pass its symlink. This separate
installation task leaves `check --before deploy` forbidden for a reviewer-safety
change. The authorization binds the candidate, review, installed checkout,
launcher, and recorded old HEAD in the same Git repository, and is consumed
once by the Windows installer. Fetch `origin/main` immediately before issuing
authorization; the target must be a merged release (in fetched `origin/main`
history). Linux `update.sh` and the Windows installer both accept it even
after later merges and install exactly that SHA, never the newer tip. If
another session fast-forwards the installed checkout during the review, the
authorization accepts a move that stays inside the declared start..target
range and binds the checkout's actual HEAD; a move backward, sideways, or past
the target still stops. The
installed checkout must be the durable primary checkout and the launcher must
have its supported canonical path. Only after it passes may the
canonical checkout fast-forward and the supported installer run. Verify the
installed command hashes and routing afterward. On Windows, pass
`-RepoPath <canonical checkout> -ExpectedHead <full target SHA>` to the
reviewed target worktree's `bin/install-ai-devops-windows.ps1`. The old
installed bootstrap and installer do not have this gate and cannot perform the
first protected migration. The full target installer refreshes the managed
command launchers and source receipts before consuming authorization.
The Windows installer compares the managed launcher receipt with the fetched
release, so it also detects a checkout that was advanced before the installer
started. It refuses a reviewer-safety change without both `-ExpectedHead` and
the matching one-use authorization, including when invoked through bootstrap
or setup. Windows bootstrap may provision only the fixed `Git.Git`
prerequisite when Git is absent; it then checks the canonical source and
authorization before runner setup, WinGet configuration, provider installs,
remote access, or machine setup, including with `-SkipMachineSetup`.
Direct `setup-machine.ps1` and the legacy developer-computer launcher use
the same pinned source gate before their package and configuration work.
After a launcher write is interrupted, the normal installer first restores
the exact recorded prior launcher and PATH state under its installation lock,
then checks the pending one-use authority. A changed launcher or PATH stops
the retry for manual repair.
The source-only gate retains a pending authorization until the full
installer finishes and refreshes the managed command launchers; a failed full
installation can retry against the same pinned target. Legacy launchers
without a receipt need the same one-time path. If both managed gate launchers
are absent, use `authorize-install --first-install` with a separate exact-head
review whose approved report contains the exact line `Approved first-managed-install.`. This applies even
to a newly cloned checkout: a clone reflog does not establish installation
history. If another managed launcher remains, or just one gate launcher remains,
use `authorize-install
--recover-launchers` with a review naming
`Approved partial-managed-launcher-recovery.`. The authority records hashes for every
present managed launcher, exact absence of the missing gate launcher files,
and the installed gate source hash. The installer checks them again before
writing either file.
The full installer refreshes launchers after ordinary updates as well, so the
next release starts from the current installed-source receipt. A source-only
update must be followed by a full install before beginning another release.
For Windows four-line launchers, use the explicit
`authorize-install --legacy-migration` route, including a reviewed cross-commit
update. Linux legacy migration remains an unchanged-checkout operation. The
independent exact-head review must examine the full target source and the
`legacy-managed-launcher-refresh` operation; its approved report must contain the exact line `Approved legacy-managed-launcher-refresh.` for that
operation. The one-use authority records hashes of both launcher files and
the original installed gate source, which the installer checks again before
refreshing the launcher receipt. It retains the original checkout baseline
through source-only advancement and launcher stamping; the original source
hash is verified against that exact commit, not the newer working tree.
This route refuses launchers that already have a receipt. Receipted Windows
updates bind the actual old checkout and the original receipt SHA separately,
so a clean checkout that is ahead of its receipt is never substituted for the
receipt's release range. An altered receipt or original-source binding refuses.
Ask for an operation's approval line with `ai-review <provider> final-check
--operation <name>` (`legacy-managed-launcher-refresh`,
`first-managed-install`, `partial-managed-launcher-recovery`, or
`stale-linux-manifest-recovery`); the reviewer request then names the exact
`Approved <name>.` line, and the report records the operation. For
`stale-linux-manifest-recovery`, run the review on the affected Linux host: the
review wrapper itself reads `/usr/local/bin/ai-task-gates` and
`/etc/ai-devops/install-manifest.tsv` (no caller input) and writes the stale
manifest SHA and hash plus the live installed SHA and gate hash into both the
reviewer request and the wrapper-written report header. If that host evidence
cannot be read, no reviewer starts.

The route accepts only the supported `popcre/ai-devops` and redirected
`u2giants/ai-devops` GitHub origins. It compares the full release range,
including deleted paths, and refuses a divergent or dirty candidate. The
first rollout uses the reviewed gate from the target worktree, so an older
installed gate does not need to understand these new options.

For a first Ubuntu installation at an unchanged commit, start a separate clean
installation task and obtain an assigned AI reviewer's read-only `APPROVE` for the exact
target source and `first-managed-install` operation. From that task's exact
target worktree, issue `authorize-install --first-install` with the target SHA,
canonical checkout, `/usr/local/bin/ai-task-gates` launcher, approved report,
and the same report as `--reviewer-approval`; then invoke the target `install.sh`. The canonical launcher
and manifest must be absent before authorization. Both Ubuntu and Windows
first installation require the reviewed one-use authority. For a
same-source maintenance reinstall, omit `--first-install`: the check requires
the installed source receipt to match the current commit and gate bytes. The
Ubuntu `/etc/ai-devops/install-manifest.tsv` supplies that receipt; the Windows managed Bash and
`.cmd` launchers carry matching source commit and SHA-256 markers and must
match the installed command and user profile routes. The Windows
machine-tools installer writes those markers when it installs launchers.

The installer does not enable recurring memory synchronization. Automatic
memory writers remain disabled; a manual private-hub union is the qualified
production policy.

Skill-only maintenance supports preview and a recoverable legacy migration:

```bash
ai-install-skills --dry-run
ai-install-skills --keep-orphans
ai-install-skills --adopt-globals
```

For a narrow refresh, use `ai-install-skills --only shared-db-orchestrator
--only shared-db-handover` (Git Bash on Windows). Repeat `--only` for each exact
skill name; unknown names and selected shared/client collisions fail before any
writes. `--dry-run` previews the same selection. Scoped refresh retains normal
local-edit backups and the install audit log, but does not touch unrelated
skills, retired skills, globals, Git identity, or command launchers. Codex is
still skipped when its home directory is absent. `--adopt-globals` and `--log`
cannot be combined with `--only`. Omitting `--only` retains full installation.

On Windows, `bin/install-ai-devops-windows.ps1 -SkillsDryRun` previews skill and
global operations and skips repository, tool, and login work. Both installers
retire skills automatically: any skill they previously installed (marked with a
`.ai-devops-managed` file) that the repo no longer ships is moved into
`<client>/skills-quarantine/`. Skills ai-devops did not install — vendor skills
shipped with the client, or hand-authored local ones — carry no marker and are
never touched. Pass `--keep-orphans` (Bash) to opt out.

### Preview-first reconciliation

Every install classifies each skill before touching it and prints one line per
skill. The same lines appear in a dry run and in a real run, so the preview is
the plan:

| Line | State | What happens |
|---|---|---|
| `+ name` | absent | installed |
| `= name` | identical | nothing is written |
| `~ name` | update | only the changed files are copied |
| `! name … LOCAL EDITS` | an installed file was edited by hand | copied to `<client>/skills-backup/<name>`, then updated |
| `! name … never installed it` | a directory we do not own is in the way | copied to `<client>/skills-backup/<name>`, then adopted |
| `- name retired` | the repo no longer ships it | moved to `<client>/skills-quarantine/<name>` |

Two rules make this safe. **Files inside a managed skill that the repo does not
ship are never deleted**, so a local extension survives every update; only files
the installer itself wrote and the repo has since dropped are removed. And
**anything replaced that held local edits is copied somewhere recoverable
first** — nothing is ever deleted outright.

The `.ai-devops-managed` marker records a SHA-256 for every file the installer
wrote. That record is what tells a hand edit apart from an ordinary source
update. Markers written before this existed carry no hashes; a skill under one
that differs is treated as locally edited, so the first run after upgrading may
report edits that are really just old installs. That is deliberate — it backs
the copy up rather than assuming.

**Globals are never replaced without being asked.** `~/.claude/CLAUDE.md` and
`~/.codex/AGENTS.md` carry per-machine sections, so a differing global is
reported and left alone. `--adopt-globals` (Bash) or `-AdoptGlobals`
(PowerShell) is the explicit managed boundary: it copies the installed file to
`<client>/globals-backup/` and prints the one-line restore command before
replacing it.

Both installers implement the same engine, and `tests/test-installer-parity.sh`
proves it: same file set, byte-identical markers, and a refresh with one after
an install by the other reports "up to date" rather than inventing local edits.

## Reviewer approval (no human approvals)

Owner ruling 2026-09-28 (#996): no human approves anything. Every gate that
once took an owner request now takes `--reviewer-approval <report>`: the report
of an AI reviewer run through `ai-review`. The gate accepts it only when the
reviewer lifecycle recorded that exact report (path and SHA-256) as a completed,
non-stale `APPROVE` for this repository, the exact head, and the exact source
digest, by a provider different from the implementing engine that
`ai-review` recorded (`--implementer ENGINE`, else `AI_IMPLEMENTER_ENGINE`,
else detected for Claude Code and Codex; a row without one cannot lift a gate). An
install, deploy, or other live action needs a `final-check` or
`security-review` report; `review`, `pr-wait`, and `code-only-review` also
accept an ungated `plan-review`. A protected class's forbidden actions still
have no approval path.

## Update

```bash
cd /worksp/ai-devops
./update.sh --reviewer-approval <exact-head APPROVE report>
```

`update.sh` never overwrites `/etc/ai-devops/*.env`. It returns nonzero if the
installer has any required failure and reports the exact source SHA attempted.

On Linux, `update.sh --expected-head <full-merged-SHA> --reviewer-approval
<exact-head APPROVE report>` pins a protected update before the installed
checkout moves. The **first** protected rollout must invoke the merged target
script from a clean, exact-SHA worktree sharing the installed checkout's Git
common directory:

```bash
cd /worksp/ai-devops-candidate
./update.sh --installed-checkout /worksp/ai-devops --expected-head <full-merged-SHA> --reviewer-approval <exact-head APPROVE report>
```

The updater verifies the candidate and installed checkout relationship, fetches
`origin/main`, requires the pinned SHA to be in its history, records an installation task in the exact target
candidate, runs its gate, then advances only the named
installed checkout. Later updates can run from the installed checkout itself.
`install.sh` checks the same pending authorization before its first machine
change, including when called directly. Same-source maintenance uses
`./install.sh --reviewer-approval <exact-head APPROVE report>`; a protected source
change cannot use that route. One checkout lock covers the update and install.
The installer saves protected config, the manifest, managed launcher targets,
the user crontab, and the protected configuration checkout's commit before it
starts. On a required-stage failure it restores those items where their exact
prior state can be proved; the updater returns to the prior clean checkout only
after that restoration is confirmed. A foreign concurrent change stops
automatic rollback and leaves the authorization pending for repair. Per-user
provider and skill changes are not an atomic transaction, so a failed update
still needs explicit capability verification before being called rolled back.
Reviewer requalification is a required installer stage before authorization
is finalized, including on a direct retry. The installer records each stage's
result in a protected local report; the gate checks and binds that report
before the one-use authorization can be consumed.

If the installed Linux manifest names an older source SHA than the live clean
checkout, the independent exact-head report must explicitly name
`Approved stale-linux-manifest-recovery.` and bind the stale manifest SHA and file hash
plus the live installed SHA and gate hash. The gate trusts the operation and
evidence rows only in the wrapper-written header before `## Result`; rows in
reviewer text never count. The separate installation task then
uses `authorize-install --stale-manifest-recovery` for one pinned target update.

Field notes from the 2026-10-06 edge-dev3 recovery (verified, not theory):

- Run `update.sh` from the candidate worktree, never from the installed
  checkout; otherwise it stops with `candidate and installed checkout must differ`.
- Run `authorize-install` with the **candidate's** `bin/ai-task-gates`. The
  installed launcher points into the installed checkout, so while that checkout
  predates a gate fix it still runs the old gate (it refused a valid report with
  `Review does not name exact target` until the candidate's copy was used).
- The review, authorization and `update.sh` must all name the same exact SHA.
  Since 2026-10-07 that SHA only has to be merged (in fetched `origin/main`
  history), not the tip: later merges no longer force a redo. `update.sh`
  advances the installed checkout to exactly the pinned SHA, never the newer
  tip, and refuses a pinned SHA that is not merged (`explicitly approved commit
  is not in fetched origin/main history`) or a candidate at any other SHA
  (`candidate checkout is not the exact approved target`). The protection the
  old tip check gave (install only published, merged code) is unchanged.
- Pass the review report at the path the review wrote it; a copy elsewhere is
  not accepted.
- `another installation is active for this checkout` can be a leftover
  `setup-desktop-apps.sh --claude-only --wait-for-desktop-exit` started by an
  earlier install that inherited the checkout lock and waits until the Claude
  desktop app exits. Fixed in
  [#1385](https://github.com/popcre/ai-devops/pull/1385): the waiter no longer
  inherits the lock fd. For a waiter started before that fix, find the holder
  with `fuser -v ~/.local/state/ai-devops/task-gates/install-*.lock`; stopping
  it is safe because the next install starts it again.
Without that exact reviewed evidence, the updater stops before changing the
installed checkout.

Reviewer hosts do not need `update.sh` for requalification: the managed
`post-merge` hook runs `ai-review-preflight requalify` on every pull whose
result is on `origin/main` (development-branch merges are skipped). The two
documented update paths — `update.sh` and rerunning the Windows installer —
each fast-forward with hooks disabled and run one explicit
`ai-review-preflight requalify` during installation, so a failed canary can
never masquerade as a pull or install failure mid-update. A failed automatic
requalification is recorded with `ai-reviewer-issue record`; it fails
`update.sh` (except a `provider-outage/capacity` event such as an exhausted
quota, which is recorded and leaves the reviewer quarantined but does not fail
the install) and is printed (without aborting later skill stages) by the
Windows installer, and the reviewer stays quarantined
(`live-qualification-required`) until it is fixed. A live canary can take up
to its qualification timeout (default 30 minutes per reviewer), so a pull
shortly after a merged wrapper change may pause while requalification runs.

## Rollback

- **Code:** `git -C /worksp/ai-devops checkout <previous-sha>` then
  `./install.sh`, then `ai-review-preflight requalify`. The rolled-back
  wrapper hashes no longer match the live qualification records, and the
  post-merge hook only requalifies `origin/main` results, so requalify by hand.
- **Symlinks only:** `./uninstall.sh` removes the `/usr/local/bin/ai-*` symlinks.
- Config in `/etc/ai-devops/` is preserved by both paths.

## Uninstall

```bash
./uninstall.sh --dry-run      # exact read-only ownership/removal preview
./uninstall.sh                # minimal: owned symlinks and the managed hook
./uninstall.sh --purge        # minimal + archive/remove config
./uninstall.sh --full         # archive/remove config and clean checkout
```

`uninstall.sh` removes only manifest-owned symlinks whose target and hash still
match, plus the managed post-merge hook while its bytes still match the
shipped `hooks/post-merge`. Destructive modes first create and verify a protected config archive and
Git bundle, refuse broad paths or a dirty checkout, and never touch
Claude/Codex/gh login state.

## Runtime environment variables

Live in `/etc/ai-devops/models.env` and `server.env` on each host — not in the
repo, not in any CI system. See [`configuration.md`](configuration.md).

## Restore on a fresh server

The full disaster-recovery procedure (create server → install git → clone → run
`install.sh` → log in to gh/claude/codex → `ai-devops doctor`) is in
[`restore-from-zero.md`](restore-from-zero.md).
