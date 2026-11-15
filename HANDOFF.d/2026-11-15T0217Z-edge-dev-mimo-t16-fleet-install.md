---
issue: 2518
status: OPEN
owner: mimo/edge-dev-t16-fleet-install
---

# Install the toolkit skill update on t16

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

**None — nothing in this workstream needs the owner.**

Sweep performed: the remaining work is one routine toolkit install on one dev
box. It needs no business judgement, no budget decision, no customer or
product call, and no permission. It is ordinary machine maintenance that an AI
session performs by itself. The only thing standing in the way is network
reachability, which is an access fact, not a decision.

**Already settled — do NOT re-ask:**

- 2026-11-13: the brief-content standard for reviewer skills is approved and
  merged. Do not reopen whether reviewers should receive full background and
  context. Owner asked for it explicitly.
- 2026-11-13: networking-only boxes must never receive the toolkit. Settled in
  the repository contract; see §7.

Next session: if anything in §1–§9 turns out to need a business ruling from
Albert, put the whole list to him in ONE message before starting work.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's **public recovery toolkit** for a
multi-model AI coding workflow (plan → review → implement → test → review). It
is not an app, a service, a database, or a product deployment pipeline.

- **Who uses it:** Albert and AI coding sessions (Claude, Codex, Grok, GLM,
  Kimi, Qwen, ZCode, MiMo) on Windows development machines and Ubuntu servers.
- **What it contains:** command-line tools under `bin/`, lifecycle scripts
  (`install.sh`, `update.sh`, `uninstall.sh`), configuration examples and
  registries under `config/`, agent skills under `skills/`, templates under
  `templates/`, documentation under `docs/`, and tests under `tests/`.
- **Why it exists:** so the entire multi-model workflow can be restored from
  zero on a fresh machine and kept working without private chat context.
- **Where it runs:** one checkout per machine. On the production Ubuntu server
  the checkout lives in the shared work area; on Windows dev machines it lives
  under the user's repos folder. Each machine also has *installed* copies of
  the skills in each AI client's own config folder.
- **Repository:** https://github.com/popcre/ai-devops (public).

## 2. What we set out to do this session, and why

Two jobs, both initiated by Albert:

**(a) Make reviewer briefs carry full context.** Albert asked what the
`ask-muse` skill contains, and specifically whether it tells the AI agent to
include all background info and all context for its questions so the reviewer
(Muse) can make a knowledgeable decision with all the data needed. It did not:
the skill said to hand over a brief file but never said what the brief must
contain. Albert asked for one rule, drafted, and added to all the other
reviewer skills (GLM, Gemini, StepFun, DeepSeek, and the rest).

**(b) Install the updated skills on every computer.** Once the rule was merged,
Albert asked whether it could be installed on all computers from here.

Technical objective: one shared "Brief content" standard in every
second-opinion/review skill, then the whole fleet running it.

## 3. Current state — what is true right now

### (a) The rule — DONE, merged and live

One shared section titled **"Brief content — the other model gets nothing but
this"** was added to all **nine** reviewer / second-opinion skills:

- `skills/shared/ask-muse/SKILL.md`
- `skills/shared/ask-glm/SKILL.md`
- `skills/shared/stepfun/SKILL.md`
- `skills/shared/deepseek-second-opinion/SKILL.md`
- `skills/shared/gemini-code-delegation/SKILL.md`
- `skills/shared/grok-cli/SKILL.md`
- `skills/shared/qwen-code/SKILL.md`
- `skills/shared/kimi-code-delegation/SKILL.md`
- `skills/claude/codex-second-opinion/SKILL.md`

Each is reachable under
https://github.com/popcre/ai-devops/tree/main/skills
(for example
https://github.com/popcre/ai-devops/blob/main/skills/shared/ask-muse/SKILL.md).

The standard requires every brief to pass **the stranger test** ("a stranger who
walked in this morning could make the right call from the brief alone") and to
carry: **Background**, **the material**, **the question**, **Constraints**, and
**Required output** — and forbids secrets in a brief. Skills that already had
brief-writing advice kept only their provider-specific practice (caching /
prefix-stability / process-list notes); their generic bullets were folded into
the shared section.

- **Shipped:** pull request https://github.com/popcre/ai-devops/pull/2505
- **Merge commit:**
  https://github.com/popcre/ai-devops/commit/86c203c6d953533bfd035ebbe2fec0fe0a5ff124
  — confirmed on `main`.
- **Verification that passed before merge:** the shared delegation-template
  test suite (20 passed, 0 failed) and the repository's public-documentation
  safety check on the exact head (9 files, pass). This was a prose-only change.

### (b) The fleet install — DONE on five machines, NOT DONE on one

Installed and **verified live** (rule text confirmed present in an installed
reviewer skill on each):

| Machine | Kind | Checkout | Result |
|---|---|---|---|
| edge-dev (this session's machine) | Windows | its repos checkout | installed, verified |
| al8960ofc (also known as 4837) | Windows | its repos checkout | installed, verified |
| 916-alien (also known as 916) | Windows | its repos checkout | installed, verified |
| edge-dev3 | Linux desktop | its repos checkout | installed, verified |
| hetz (production Ubuntu server) | Linux server | its work-area checkout | installed, verified |

All five now sit at release `d1fa0bdf3e1a2e6a9219cb2ffd92315d6228ea18` or
later and report the rule in the installed skills.

**NOT done — the whole point of this handoff:** **t16** (the fourth Windows 11
dev box, a domain-joined machine whose user is `ahazan2`) did not get the
install. It never answers on the network from edge-dev — the SSH connection
timed out. Its installed skills are still the OLD ones, without the brief
standard.

**Not attempted, by design (never install on these):** `edge-alien`,
`edge-runn-envy`, `edge-runn-xps` are networking-only machines. The two Synology
NAS boxes are storage appliances, not toolkit machines.

**Commit/push/deploy status:** the rule is merged to `main` and deployed to five
machines. No application deployment is involved — this is tooling, and its
"deployment" mechanism is installation on each machine.

## 4. Everything we tried that did NOT work

These cost real time. Do not repeat them.

1. **First attempt to open the pull request was refused.** The shared GitHub
   throttle on the machine reported the core budget paused until its own reset
   (roughly 20 minutes out). It was not a permissions problem and not a bug —
   other AI sessions on the same machine had been spending the hourly budget.
   *Fix that worked:* wait out the published reset time with one bounded sleep,
   then retry once. Do not poll in a loop.

2. **The merge command appeared to hang, twice.** Same throttle: the call was
   queued behind live waiters from other sessions, and the command window
   expired before its turn came. *Fix that worked:* rerun with standard input
   closed (so the command cannot stall on an interactive prompt) and a longer
   window. The merge itself succeeded first time once it actually ran.

3. **The Windows installer died immediately** with
   `Cannot bind argument to parameter 'Path' because it is null`.
   This was **not** a repository problem. Root cause in §5.
   *Fix that worked:* run the installer from a PowerShell that actually has the
   `ProgramFiles` environment variable set (or set it first), instead of
   spawning a child PowerShell from the Git Bash tool shell.

4. **Remote probes of the Windows boxes echoed the command back literally.**
   The default remote shell on those boxes is the classic command interpreter,
   not PowerShell, so a PowerShell one-liner is echoed as text.
   *Fix that worked:* invoke PowerShell explicitly, and pass the script as an
   encoded command so quoting survives the trip.

5. **A remote probe returned "not a git repository" for a checkout that was
   clearly a repository.** The `$(...)` inside a double-quoted string was
   expanded by the LOCAL shell before the command was ever sent.
   *Fix that worked:* single-quote the remote command so nothing expands
   locally.

6. **`sudo` on the Linux desktop cannot be primed the obvious way.** It has no
   passwordless rule, and priming it from a plain pipe does not give later sudo
   calls in the same run a terminal ticket — the installer's own privileged
   steps then stop with "A terminal is required to authenticate".
   *Fix that worked:* run the whole update under a pseudo-terminal wrapper and
   feed the password from a protected, user-only file, then delete that file.
   Details in §7 and §8.

7. **Do not hand-edit the installed skill folders to force the change.** They
   are a build output rewritten from the repository on every install; a
   hand-edit is silently replaced and leaves the machine's recorded source
   revision inconsistent. Use the real installer.

## 5. Root causes and key findings

- **Why the skills were thin.** The reviewer skills told the agent to pass a
  brief file but never said what the brief must contain. There was no shared
  standard. Some skills (the DeepSeek and Codex debate skills) had good local
  guidance; others (Muse, GLM, StepFun) had none at all. The fix is the shared
  section now in all nine.

- **Why the install needed no approval.** The Windows installer classifies a
  release as a "protected update" only when the changed files match the
  reviewer-safety path rules. That class has been retired from the task-gate
  policy, so a skills-only release installs as an **ordinary update** — no
  one-use authorization, no review. This is why the fleet install was quick.

- **Why the Windows installer failed at startup.** When a PowerShell process is
  spawned from the Git Bash tool shell, the environment variables whose names
  contain a space or parentheses (`ProgramFiles`, `ProgramFiles(x86)`) are
  dropped. The installer then calls `Join-Path` with an empty base path and
  PowerShell reports a confusing "parameter is null" error. Reproduce cheaply:
  in a child PowerShell, print the value of `ProgramFiles`; if it is empty,
  that is the cause. This will bite anyone running that installer from a Bash
  tool shell again.

- **Reviewer requalification is the slow stage.** A large release jump can make
  the installer pause while reviewers are re-proved live (the timeout is on the
  order of 30 minutes per reviewer). A skills-only jump is usually fast, but
  expect a long run on a machine that is far behind.

- **The GitHub throttle is shared across every session on the machine.** A
  refusal is budget, not an error. Never work around it with a direct call.

## 6. Exact next steps

Only one thing is left.

1. **Get onto a network that can reach t16.** It is a domain-joined Windows 11
   dev box; the working theory is that it sits on a different site from the
   machine this session ran on. Other Windows dev boxes have been reached
   before from the right network, so the box itself is expected to be healthy.

2. **Identify its installed checkout** by reading the managed launcher receipt
   on the box (the small command shim whose header records `source-sha=` and a
   path). Use that path as the checkout — do not assume a drive letter.

3. **Run the normal Windows installer** for that checkout. Same procedure that
   worked on the other Windows boxes: the repository's own Windows install
   script, pointed at the checkout from step 2. Make sure the shell you run it
   from has the `ProgramFiles` variable set (see §5).

   *You'll know it worked when* the script prints its completion banner naming
   the checkout path, and no stage reports a failure.

4. **Verify the rule is live.** Open an installed reviewer skill on that box
   (for example the Muse skill in either the Claude or the MiMo skills folder)
   and confirm it contains the section heading `Brief content` and the sentence
   about a stranger walking in this morning.

   *You'll know it worked when* both strings are present in an installed skill
   file on t16.

5. **Close out.** When steps 3 and 4 are verified, close
   https://github.com/popcre/ai-devops/issues/2518 and delete **this** handoff
   file in the same change (see the successor rule in §7). Do not delete any
   other session's file.

## 7. Constraints and gotchas in force

- **Never install the toolkit on `edge-alien`, `edge-runn-envy`, or
  `edge-runn-xps`.** They are networking-only machines. This mistake has
  happened repeatedly; check the hostname first. Settled owner rule.
- **Never run `git pull` or a merge in an installed checkout.** It advances only
  through the protected installer. A plain pull is recorded and warned about.
- **Never hand-edit installed skill folders.** They are rewritten from the
  repository on every install.
- **All file references in this file and in any resume prompt are GitHub URLs**,
  never machine-local paths, because the next session may run on a different
  machine.
- **Secrets:** only through 1Password (vault `vibe_coding`) or protected
  user-only files. Never in chat, arguments, output, logs, or commits. Delete
  any temporary protected file as soon as its job is done.
- **Concurrency:** other AI sessions work the same repository. Never rewrite the
  root `HANDOFF.md`, never edit another session's `HANDOFF.d/` file, never
  broadly stage another session's uncommitted work, and never delete a branch,
  worktree, or checkout another session may be using.
- **Retirement rule for this file:** delete it only when issue 2518 is closed,
  the install on t16 is verified, and nothing above is still owed. A closed
  issue alone is not proof — apply the successor rule from the handoff
  standard.

## 8. Access and environment

- **This session ran on** the Windows dev box named `edge-dev`, from that
  machine's landing/working checkout of the repository. The *installed* checkout
  on that machine is a different folder — see §5 about reading the launcher
  receipt rather than assuming a drive letter or a folder name.
- **Reachable over SSH from that machine:** the Linux desktop, the production
  Ubuntu server (aliases `vps` / `coolify`, privileged user has passwordless
  sudo), and two Windows dev boxes. Windows boxes need PowerShell invoked
  explicitly.
- **NOT reachable from that machine:** `t16` (connection timed out). This is the
  only blocker in the workstream.
- **Secrets:** 1Password vault `vibe_coding`, reachable through the 1Password
  integration. The Linux desktop's user password lives in an item named for that
  machine and its sudo user; it is used through a protected local file and is
  never printed. **Never write its value anywhere.**
- **GitHub access:** through the repository's throttled wrapper, never a raw
  call. Budget refusals are normal; wait out the published reset.

## 9. Open questions and risks

- **(2026-11-15) How to reach t16 from the current session's network.** It
  timed out; it may be on a different site. If it is genuinely offline, the
  install waits for it to come back — nothing else depends on it. The rule is
  already live everywhere else.
- **(2026-11-15) The `ProgramFiles` trap will recur.** Anyone running the
  Windows installer from a Bash tool shell will hit the confusing null-parameter
  error again. The one-line diagnosis is in §5. A permanent fix in the installer
  (falling back to a sensible default when the variable is missing) has **not**
  been made and is deliberately out of scope for this workstream — do not treat
  this handoff as authorising it.
- **(2026-11-15) Long installs on far-behind machines.** A box that has not been
  updated in a while may spend significant time in reviewer requalification.
  Budget for it rather than assuming the run failed.

---

## Self-audit (handoff standard)

1. **Could a brand-new developer with no project knowledge pick up here and not
   skip a beat?** Yes — §1 defines what the toolkit is and where it runs, §2
   states the two jobs and why, §3 gives the verified state including the one
   machine still outstanding, §6 gives the exact remaining steps with success
   gates.
2. **Could they continue as well as I could right now?** Yes — §4 records every
   dead end with the fix that worked, and §5 records the non-obvious causes
   (especially the environment-variable trap) that cost me the most time.
3. **Is every relevant detail included?** Yes — background (§1), goals (§2),
   current state with URLs (§3), failures (§4), findings (§5), exact next
   actions with verification (§6), constraints (§7), access (§8), risks (§9).
4. **If the owner read only §0, would he see every business decision?** Yes —
   §0 states explicitly that there are none, lists what is already settled so it
   cannot be re-opened, and instructs the next session to raise any new
   business question in one message. No technical approval appears in §0.
