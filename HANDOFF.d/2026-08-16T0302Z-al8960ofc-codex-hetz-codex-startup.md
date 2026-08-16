---
issue: none
status: OPEN
owner: codex/hetz-codex-startup
---

# HANDOFF — Hetz Codex startup failures (2026-08-16 03:02 UTC, al8960ofc/codex)

## 0. DECISIONS ONLY THE OWNER CAN MAKE

### Blocking

1. Approve rotating the three bearer tokens used by the DesignFlow, Synology
   monitor, and Recall AI connectors. Their live values were accidentally shown
   in this session's private command output while diagnosing process buildup.
   Recommendation: approve rotation, then update the corresponding entries in
   the `vibe_coding` 1Password vault and rerun `bin/setup-secrets.sh` on Hetz.
   This blocks calling the credential exposure fully remediated.

### Recoverable

None.

### Not part of this work, and nobody is on it

1. `ai-install-skills` reported that the Ubuntu `ai-qwen` command shortcut is
   missing or broken. Recommendation: run the normal dotfiles-sync repair in a
   separate session. It did not prevent the Codex skill and launcher updates.

### Already settled — do not re-ask

- GPT-5.6 reasoning stays low or medium only.
- Production and shared cloud infrastructure remain read-only by default.
- Do not solve the 1Password failure by increasing Codex's startup timeout. The
  permanent launcher correction is already committed and deployed.

The next session must put the complete list above to Albert in one message before
starting further work.

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's public backup-and-restore toolkit for his
AI coding setup. It installs command-line tools, reusable skills, machine setup,
and connector configuration. There is no web application, database, container,
or CI service in this repo. The affected machine is the Hetzner VPS named `hetz`;
Codex runs there as Linux user `ai`, with its settings under `/home/ai/.codex`.

## 2. What we set out to do this session, and why

Albert reported four warnings every time Codex started on Hetz:

- two copies of `codex-transcript-miner/SKILL.md` had an invalid header;
- the Vercel connector closed during startup;
- the 1Password connector exceeded Codex's 30-second startup limit;
- Codex consequently reported incomplete connector startup.

The goal was to find root causes, correct the repository source, deploy the fix
to Hetz, and prove a clean new Codex start.

## 3. Current state — what is true right now

Completed and proven:

- Commit `41dfeef5d802ab49b5a480f5106cf7234d29d1a1` is on GitHub `main` and on
  `/worksp/ai-devops` at Hetz.
- `skills/codex/codex-transcript-miner/SKILL.md` now starts with `---`, as Codex
  requires. `ai-install-skills` copied it to
  `/home/ai/.codex/skills/codex-transcript-miner/SKILL.md`; the installed first
  line was verified as `---`.
- `bin/setup-secrets.sh` now holds the shared file lock only while retrieving
  secrets, releases it, then starts the long-running connector. The generated
  `/home/ai/.config/ai-devops/mcp-launch.sh` contains that corrected sequence.
- `bin/setup-secrets.sh --no-legacy` completed on Hetz. All seven configured
  1Password references resolved successfully, and the GLM end-to-end check
  passed.
- Seven abandoned 1Password connector processes older than one hour and one
  abandoned Vercel connector were stopped. Vercel's local login port `23098` is
  now free. These connectors are recreated automatically by a new Codex start.
- Relevant local checks passed before commit: `bash -n bin/setup-secrets.sh`,
  `tests/test-mcp-launch-lock.sh`, `tests/test-installer-parity.sh`, and
  `tests/test-windows-scripts.sh` with 25 Windows checks passing.

Still open:

- A fresh interactive Codex start has not been run after cleanup. The final
  startup banner is therefore not yet proven clean.
- A read-only check immediately before closeout still reported
  `/home/ai/.config/ai-devops/op-refresh.lock` occupied. Determine the holder
  without printing command lines that contain tokens, stop only the obsolete
  connector tree, and prove the lock becomes free.
- Hetz Codex's Vercel entry still invokes `mcp-remote@latest`. The repository's
  generated Claude configuration pins `mcp-remote@0.1.38`, but no Ubuntu Codex
  reconciler currently owns this existing Codex entry. After the abandoned port
  holder was removed, verify whether the current entry starts or asks for browser
  authorization before changing it.
- `ai-install-skills` updated the skills successfully, then its broader machine
  check ended `SYNC INCOMPLETE` because `ai-qwen` is missing or broken. Treat
  this as a separate machine-tool repair.

The local primary checkout `C:\repos\ai-devops` contains unrelated work from
other sessions and is behind GitHub. It was deliberately not pulled, staged, or
changed. This session used the isolated worktree
`C:\tmp\ai-devops-codex-startup-fix`.

## 4. Everything we tried that did NOT work

1. The first direct connector probes ran as user `ai` but inherited working
   directory `/root`. `npx` failed with permission errors. That was a test setup
   error, not the Codex failure. A valid probe must set `HOME=/home/ai` and start
   in `/home/ai` or `/worksp/ai-devops`.
2. Increasing or merely testing a 45-second timeout did not help 1Password. The
   connector produced no response because it was waiting behind a file lock that
   another long-running connector inherited. More timeout would hide the faulty
   lock lifetime.
3. The Vercel probe failed with `EADDRINUSE` on local port `23098`. This proved
   an abandoned OAuth listener, not a Vercel service outage. Stopping the
   abandoned connector released the port.
4. The first cleanup command matched its own remote shell command while looking
   for `flock ... 1password-mcp`, which terminated that SSH check early. Do not
   match full command text from within a command containing the same pattern.
   Identify holders through `/proc/<pid>` or exact process parentage, and never
   print arguments because connector arguments can contain live tokens.
5. `ai-install-skills` did not return overall success because its final machine
   check found the unrelated missing `ai-qwen` shortcut. Its earlier output
   proves the skill copies were installed; do not rerun or reinterpret this as a
   failed skill copy.

## 5. Root causes and key findings

1. Skill header: the transcript safety notice appeared before the required YAML
   header. Codex only recognizes the header when `---` is the first line. The
   same source was installed under `/home/ai/.codex/skills`, producing two
   warnings for one repository defect.
2. 1Password timeout: the old Ubuntu launcher in `bin/setup-secrets.sh` used
   `exec flock ... op run ... -- <connector>`. Linux child processes inherit the
   open lock, so the lock lasted as long as the connector, not just as long as
   secret retrieval. Later connector startups queued and missed Codex's limit.
   The permanent correction is documented in `docs/critical-incidents.md` and
   `docs/mcp-1password-rate-limit-hardening.md` at commit `41dfeef`.
3. Vercel: an abandoned `mcp-remote` process had kept OAuth callback port
   `23098` open for several days. A new Vercel connector found the existing port,
   then tried to listen on it and exited. The port is now free.
4. Process buildup: repeated sessions had left many connector processes running.
   Cleanup must be age- and parentage-based and must not display arguments,
   because remote connector commands carry bearer tokens.
5. During diagnosis, command output printed three existing connector bearer
   tokens. They were not written to repository files or commits, but they now
   exist in the private session record. Rotation needs Albert's approval and is
   listed in section 0.

## 6. Exact next steps

1. Ask Albert once for every decision in section 0. You will know this is done
   when rotation is explicitly approved or declined and the `ai-qwen` repair is
   accepted as a separate task.
2. On Hetz, identify the current holder of
   `/home/ai/.config/ai-devops/op-refresh.lock` without printing process
   arguments. Use PID, owner, elapsed time, executable name, and parent PID only.
   Stop only an obsolete connector or old launcher tree. You will know it worked
   when `flock -n /home/ai/.config/ai-devops/op-refresh.lock true` exits zero.
3. Start a new interactive Codex session as user `ai` from
   `/worksp/ai-devops`. You will know the skill and 1Password fixes worked when
   the banner has no invalid-skill warning and no 1Password timeout.
4. Observe Vercel during that fresh start. If it requests browser authorization,
   complete the displayed Vercel URL in Albert's browser. If it again closes,
   back up `/home/ai/.codex/config.toml`, then use `codex mcp remove vercel` and
   `codex mcp add vercel -- /usr/bin/npx -y mcp-remote@0.1.38
   https://mcp.vercel.com`; do not hand-edit the file. You will know it worked
   when `codex mcp get vercel` shows version `0.1.38` and the next Codex banner
   has no Vercel failure.
5. If rotation is approved, rotate only the three exposed connector tokens in
   1Password vault `vibe_coding`, update their owning services, rerun
   `/worksp/ai-devops/bin/setup-secrets.sh --no-legacy` as user `ai`, and restart
   affected connectors. You will know it worked when all references resolve and
   the old tokens no longer authenticate. Never print either old or new values.
6. Repair the separate `ai-qwen` shortcut through the documented
   `codex-sync-dotfiles` workflow. You will know it worked when
   `ai-machine-tools-doctor` reports the Ubuntu `ai-qwen` link healthy and
   `ai-install-skills --dry-run` no longer ends `SYNC INCOMPLETE`.
7. When steps 1–5 are proven, delete this handoff in the same commit that records
   any durable follow-up. Git history preserves it.

## 7. Constraints and gotchas in force

- Work on GitHub `main`; this repo's default is main-only. A short-lived worktree
  is acceptable only if merged and removed afterward.
- Before any commit, `git var GIT_COMMITTER_IDENT` must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Do not stage, overwrite, pull through, or clean the unrelated changes in
  `C:\repos\ai-devops`.
- Do not increase Codex's connector timeout as the fix.
- Never print process arguments for remote connectors. They may contain live
  bearer tokens.
- Never rotate a credential without Albert's explicit approval.
- 1Password reads must remain serialized. The corrected lock surrounds only the
  short retrieval step, never a long-running child process.
- Production and shared cloud infrastructure are read-only. No production
  service mutation is authorized by this handoff except an explicitly approved
  token rotation.

## 8. Access and environment

- Local repo: `C:\repos\ai-devops`, Windows machine `al8960ofc`.
- Isolated worktree used by this session:
  `C:\tmp\ai-devops-codex-startup-fix`.
- GitHub repo: `u2giants/ai-devops`; fix commit `41dfeef` is on `main`.
- VPS SSH alias: `vps`; host nickname `hetz`. SSH currently connects as root;
  Codex and connector commands must run as Linux user `ai` with
  `HOME=/home/ai`.
- Hetz checkout: `/worksp/ai-devops`, branch `main`, deployed fix `41dfeef` or a
  later descendant.
- Codex config: `/home/ai/.codex/config.toml`.
- Generated launcher: `/home/ai/.config/ai-devops/mcp-launch.sh`.
- Shared lock: `/home/ai/.config/ai-devops/op-refresh.lock`.
- Secrets live in 1Password vault `vibe_coding`; no secret value belongs in this
  handoff, source code, Git history, or command output.
- Official OpenAI guidance consulted: the Codex configuration reference and
  skills documentation. The configuration reference confirms user settings live
  at `~/.codex/config.toml`; the skills documentation requires a valid skill
  header.

## 9. Open questions and risks

1. Which current process still holds the refresh lock after abandoned connector
   cleanup? It must be identified safely before claiming the 1Password startup
   is clean.
2. Will Vercel reuse its existing browser authorization after the old listener
   is gone, or require a fresh authorization? Only a new interactive Codex start
   can answer this.
3. The credential exposure is limited to private session output, but the values
   are live until Albert approves rotation. Treat them as exposed and never
   reproduce them.
4. The primary Windows checkout contains concurrent work and is far behind
   GitHub. Pulling there without reconciling its owners could damage their work.
5. The temporary worktree must be removed only after this handoff is committed
   and pushed. Its branch can then be deleted because GitHub `main` contains all
   session commits.

## Mandatory self-audit

1. Yes, a street-new developer can continue without questions. Sections 1–3
   define the repo, host, original symptoms, completed work, and exact remaining
   state; sections 6 and 8 give ordered commands, paths, access, and proof gates.
2. Yes, they can continue as effectively as this session. Sections 4 and 5
   preserve the failed probes, self-matching cleanup failure, lock inheritance,
   Vercel port conflict, process-argument secret risk, and unrelated `ai-qwen`
   failure.
3. Yes, every failed attempt and why it failed is in section 4.
4. Yes, every next step in section 6 ends with an observable success condition.
5. Yes, sections 1 and 8 define the repo, machines, users, paths, lock, vault,
   commit, and configuration locations.
6. Yes, the section-0 sweep was run across sections 1–9. The credential rotation
   approval and separate `ai-qwen` repair are both promoted to section 0. No
   other sentence requires Albert's judgment.

Final synthesis:

1. Yes. Sections 1–9 give a context-free developer all state and continuation
   evidence needed without access to this chat.
2. Yes. The non-obvious knowledge and operational traps are preserved in
   sections 4, 5, 7, and 9.
3. Yes. Background, goal, outcome, current state, failures, decisions,
   constraints, risks, exact actions, and verification evidence are present in
   sections 0–9.
4. Yes. A line-by-line sweep of sections 1–9 found two owner-level items:
   approval to rotate exposed tokens and the out-of-scope `ai-qwen` repair.
   Both appear in section 0 with recommendations.
