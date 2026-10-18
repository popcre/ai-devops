# Deployment

For this repo, "deployment" means **installing the toolkit onto a host** — there
is no cloud release, container, or CI/CD. Canonical guide:
[`../AGENTS.md`](../AGENTS.md). First-time / disaster restore:
[`restore-from-zero.md`](restore-from-zero.md).

For the dated edge-dev3 HTS continuation, see the
[visible maintenance-route feasibility record](verification/hts-maintenance-route-feasibility-20261011.md).
It distinguishes the supported visible installer from this session's unavailable
native desktop access; it grants no privilege or installation authority.

The one application-source exception is the centrally sealed DesignFlow
backend sandbox target. Its approved source push uses the repository's existing
Cloud Build route and requires the committed target manifest, local review-gate
declaration, and independent exact-head approval described in
[`context-spec.md`](context-spec.md). It grants no manual Cloud Run or other
cloud mutation.

## Machine classes (binding)

Two classes of host exist. Mixing them up has already caused repeated
wrong installs.

| Class | Hosts | What they get | What they must never get |
|---|---|---|---|
| **Dev** | Windows/Ubuntu development computers (Claude Desktop, Codex, editors) | Full toolkit: bootstrap/install, skills, MCP, reviewers, wrappers, secrets wiring | — |
| **Networking only** | **`edge-alien`, `edge-runn-envy`, `edge-runn-xps`** | SSH key, SSH config, hostnames, Tailscale | The ai-devops toolkit in any form (`bootstrap-windows-dev.ps1`, `install.sh`, `setup-machine.ps1`, skills, MCP, reviewers, agents, model config) |

**Rule:** if the hostname is one of the networking-only hosts, stop. Do not
clone-and-install, do not "reconcile", do not run a setup script to "clean up"
an MCP entry. Networking-only means networking only. CI runners and alien
gateway boxes are not development machines.

When a new non-dev host is added, it joins this table in the same change that
introduces it. Concrete addresses and keys stay in the private machine atlas
(`ai-private-config path machine_atlas`).

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

The scoped `az-mail` command is provisioned during the Ubuntu secrets stage and
Windows machine setup. Its private host allowlist comes from the protected
machine config; unsupported hosts receive no mailbox certificate.

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
   the managed marker is foreign and left untouched.

   **Installed checkout main guard (#1836).** The same step installs the
   managed `hooks/reference-transaction` hook. In the `prepared` state it
   refuses any update of `refs/heads/main`, and a commit move of `HEAD` in
   the primary worktree while it is detached or on `main`, so a plain
   `git pull`, `merge`, `reset`, or detached `checkout` there fails with
   guidance naming `update.sh` / `bin/install-ai-devops-windows.ps1`.
   Git resolves hooks through the common dir, so it also runs in linked
   worktrees; remote-tracking refs (`git fetch`), tags, other branches, and
   linked worktrees' own `HEAD` are always allowed. The protected installers
   are unaffected because they run every ref-moving git command with
   `core.hooksPath` pointed at an empty temporary directory (update.sh's
   candidate/advance/rollback commands; the Windows installer's
   fast-forward), so no hook runs for them. This is an accident guardrail,
   not enforcement: anyone can bypass it the same way (for example
   `git -c core.hooksPath=<empty> pull`) or by removing the hook. The
   `hooks/post-merge` unprotected-advance recorder and the `ai-task-gates`
   warning stay in place as the second layer. Rollback is a protected
   install of the prior release; `uninstall.sh` removes the owned hook. The Windows installer
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
   The installer (and `bin/install-ai-devops-windows.ps1`) also schedules
   `ai-reviewer-logs-sync` hourly on every machine: it uploads that machine's
   complete reviewer logs (incident packages, scoreboard, invocation events,
   lifecycle runs, `.ai/reviews` reports) as encrypted bundles to the private
   repository `u2giants/ai-devops-reviewer-logs`. Read the whole fleet with
   `ai-reviewer-logs-sync view` (key in 1Password; see its `--help`).
   `uninstall.sh` and a failed install's rollback remove the timer.
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

Reviewer-safety paths are listed in `config/task-gates.json`. They include the
reviewer wrappers and the reviewer-binary version pins (`config/muse-code/**`,
`config/opencode/version`, `config/provider-cli-versions.json`), because those
pins choose which reviewer program runs. A release that only re-pins a reviewer
binary therefore uses this same reviewed install route (#1650).

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
launcher, and the installed checkout's actual HEAD in the same Git repository, and is consumed
once by the Windows installer. Fetch `origin/main` immediately before issuing
authorization; the target must be a merged release (in fetched `origin/main`
history). Linux `update.sh` and the Windows installer both accept it even
after later merges and install exactly that SHA, never the newer tip. If
another session fast-forwards the installed checkout during the review, the
authorization accepts a move that stays inside the declared start..target
range and binds the checkout's actual HEAD; a move backward, sideways, or past
the target still stops. On Linux the installed manifest must still attest
that HEAD, so a bare pull without a reinstall still stops there. The
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
history. When the host already has a protected DeepSeek key but no provider
executable, the same native review can explicitly select
`AI_DEEPSEEK_ENGINE=attachment-api ai-review deepseek final-check --operation
first-managed-install --implementer codex --assert-head <full SHA>`.
This uses the existing DeepSeek API reviewer and its complete disposable source
copy, repository read tools, and tracked-source inventory. It retains the
shared runner's native lifecycle and exact-head approval; it cannot be selected
for an ordinary review, another operation, or implementation. There is no
automatic fallback. Windows commands requiring bubblewrap remain unavailable;
the reviewer must not infer test success. Credentials must already be in the
host's protected store, and installation still requires its normal one-use
authority after an approving review.
If another managed launcher remains, or just one gate launcher remains,
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

For a narrow refresh, preview with `ai-install-skills --dry-run --only
shared-db-orchestrator --only shared-db-handover`. A real narrow install requires
an explicit `installation` task in the clean merged candidate worktree and
`--reviewer-approval REPORT`: the candidate's `scoped-skills-install` action
validates its own committed gate, installer and helper, exact-source independent
lifecycle APPROVE, and passing bound tests. It accepts global skills only,
canonical client homes, exact names, and no audit destination override. The
current scoped lane is qualified on Linux and requires `flock`; other platforms
retain the existing full installation route, and unsupported scoped runs fail
closed.
The installer retains the prepared plan digest in a non-exported shell variable;
it refuses changed plan metadata before copying and before issuing a receipt.
The lane adds no admission bypass; existing lifecycle-store configuration remains
part of the same-user trust boundary.

It copies verified committed files from a private snapshot under the same
writer lock used by full installs of this installer version; local changes get a unique recoverable
backup. A verified scoped receipt under
`~/.local/state/ai-devops/scoped-skills/` records the full candidate SHA, critical
source hashes, exact names, absolute destinations, installed file hashes,
approval identity and report hash, and backup hashes checked against pre-install
content. Receipt publication re-runs the same exact-source approval gate and
captures its validated result directly. Audit, lock, trim-stage, receipt and
selected destination paths reject unsafe symlinks, hardlinks and wrong file
kinds before scoped writes. Source skills carrying installer-owned managed
markers are refused before copying. This receipt does not
advance or attest the full toolkit installation: the primary checkout,
launchers and full installation manifest stay unchanged. The full route retains
existing cache symlink support with a diagnostic. Nested first-sync adoption
reuses an inherited descriptor only after canonical lock-inode validation, and
every invocation still flocks it; inherited values never waive approval.
Legacy installer versions do not acquire this lock, so a scoped host operation
must be serialized against any active legacy installer. Repeat `--only` for each exact
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

The bounded private #770 review sends a native-generated, allowlisted evidence
projection alongside the public enforcement implementation. It contains scope
flags, opaque commitments, selected code hashes and verified installed source
identity, never private manifest values, credentials or row data. It is not a
verdict or live rehearsal proof. Conditional reviewer approval remains bound to
the unchanged private descriptor, genuine provider completion, and fresh native
checks at finish, initial-forward and original-restoration. Public enforcement
and the installation receipt are bound too: source movement requires a fresh
review. Hold the installer's existing checkout lock throughout any authorized
rehearsal and mandatory restoration; installation must remain serialized with
those actions.
The effective class remains `private-evidence`. Its sole database admission
requires DesignFlow's existing `synthetic-fixtures-only` declaration, the exact
closed #770 profile, a genuine independent selected-code APPROVE, and the private
manifest over stdin. Both native action stages validate and bind the descriptor.
Ordinary review reports, acknowledgement, small owner entries, other repositories,
production and credential issuance remain sealed.
The genuine response must contain one unindented `Action scope:` line naming
the exact profile and full descriptor hash. Its final sentence period is
optional; missing, changed, duplicated or decorated scope still refuses.
Provider response bytes are preserved, and failed earlier invocations are never
backfilled after this parser repair: obtain a fresh prospective approval.

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

Field notes from the 2026-10-13 Jev-fix rollout (604982bd → 2ccb7208 across
edge-dev, edge-dev3, and hetz; verified, not theory):

- `authorize-install`'s `start_head` is refreshed by every
  `ai-task-gates start --class installation` run in that worktree to the
  worktree's current HEAD (the printed `base` stays sticky at the first-ever
  base). Declare the installation task while the installation candidate is
  checked out at the INSTALLED checkout's HEAD, then advance the candidate to
  the target. Advancing first yields either
  `Empty release needs an installed receipt or explicit reviewed legacy migration.`
  (start equals target) or
  `Installed checkout moved since task declaration outside the reviewed release range.`
- Other sessions fast-forward the installed checkout while a rollout is in
  flight (all three hosts moved mid-session on 2026-10-13). Re-read each host's
  installed HEAD immediately before declaring the task, and pin the target at or
  ahead of every host; a checkout moved past the pinned target stops
  authorization by design — re-pin and re-review rather than rewinding the
  checkout.
- Reviewer final-checks can REJECT a merged target for defects in content
  another stream already merged (on 2026-10-13 both GLM and DeepSeek rejected
  `c4df0467` solely for a missing `HANDOFF.d` contract block and an unreachable
  plan-index link). Fix the named defects through the normal docs-only PR
  route, pin the new merged SHA, and re-review; do not shop for a reviewer
  that ignores the finding.
- edge-dev3 specifics: the codex symlink lives in `~/.local/bin`
  (`codex -> /usr/lib/chatgpt/resources/codex`), which non-interactive ssh does
  not put on PATH; without it the required `ai-devops doctor` stage FAILs with
  `review provider codex status invalid` and the install stops. Export
  `PATH="$HOME/.local/bin:$PATH"` for the update run. Sudo needs a PTY:
  `sudo -S -v` over a plain pipe caches per-ppid and the installer's `$SUDO`
  calls still stop with `A terminal is required to authenticate`; run the whole
  update under `script -qec '<run>' /dev/null` with the password line fed to
  the PTY so one tty ticket covers every later `$SUDO`.

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
