---
issue: 2791                            # finished when that issue's "other machines" item is done and §6 steps 2-4 have landed or moved to their own issues
status: OPEN
owner: zcode/wrapup-2795-skill-shadows
---

# HANDOFF — ZCode doubled-skill follow-ups (`2026-11-24T1850Z`, `edge-dev`/`zcode`)

Written at the close of ZCode chat "skill names not appearing" (session `sess_7614d688-0c3b-4933-bdca-59a1e961bdb1`) on edge-dev, 2026-11-24 1:50 PM EST. The fix itself is finished, merged and installed. This file carries only what is still open.

## 0. Business Decisions Only the Owner Can Make

- **One judgement call, not blocking anything:** should computers 4837 and 916 receive today's ZCode fix sooner than their next routine toolkit update? **Recommendation: wait.** The routine update delivers it with no help from anyone, and nothing shows that ZCode helper agents are used on those two machines. "Sooner" is possible only from a session started on each of those computers, because edge-dev has no route into them.
- **Already settled — do NOT re-ask:**
  - **2026-11-24:** the fix keeps every skill folder as it was and tells ZCode to ignore the second copy ([PR #2805](https://github.com/popcre/ai-devops/pull/2805), merged).
  - **2026-10-29:** AI review is advice only and never blocks a merge; no human is ever asked to approve.
  - **2026-08-13:** no cap on the number of `HANDOFF.d/` files; a file's presence means open.
- Nothing else in this file needs the owner. Every step in §6 is technical.

## 1. What This Application Is

- **`popcre/ai-devops`** is Albert Hazan's recovery toolkit for a multi-model AI coding workflow: command-line tools in `bin/`, the installers ([`install.sh`](https://github.com/popcre/ai-devops/blob/main/install.sh) on Ubuntu, [`bin/install-ai-devops-windows.ps1`](https://github.com/popcre/ai-devops/blob/main/bin/install-ai-devops-windows.ps1) on Windows), the shared skills under `skills/shared` (65 of them), docs and tests. It is not an app or a service. The owner is not a programmer; he directs and judges results.
- The Windows installer copies the same 65 shared skills into each AI client's own skill folder: Claude, Codex, ZCode, MiMo and Antigravity.
- **ZCode** is a Windows desktop coding agent (Z.AI GLM; version 4.0.0.10870 on edge-dev). It reads skills from two places under the user's home folder, `.zcode/skills` and `.agents/skills`, and it can hand work to helper agents ("subagents").
- **Machines named here:** `edge-dev` (this Windows computer), `edge-dev3` and `hetz` (Ubuntu), `4837` and `916` (other Windows computers). edge-dev reached edge-dev3 by ssh during this session. No route from edge-dev to 4837 or 916 was found (their names do not resolve there and no ssh alias names them). hetz was not tried.

## 2. What We Set Out to Do This Session, and Why

Albert's request, 2026-11-24: "pull the latest repo and resolve https://github.com/popcre/ai-devops/issues/2795".

Issue [#2795](https://github.com/popcre/ai-devops/issues/2795): inside a ZCode helper agent the Skill tool refused every user-level skill by bare name with "Skill name is ambiguous for subagent; use the fully qualified skill name", because identical copies sat in `.zcode/skills` and `.agents/skills`. Business meaning: any ZCode work handed to a helper that needed a skill could not load that skill's instructions.

## 3. Current State — What Is True Right Now

### Done and verified

- **Fix merged.** [PR #2805](https://github.com/popcre/ai-devops/pull/2805) merged through the queue on 2026-11-24 at 1:24 PM EST as [commit 7afada65](https://github.com/popcre/ai-devops/commit/7afada65cdfac19b4362e979bf6535cd4692a726). The queue squashed three commits; every changed file is identical to the tested head [29faef2f](https://github.com/popcre/ai-devops/commit/29faef2fdb1ef7638d3eac8da303f29e562d694e). All 36 checks were green on that head.
- **What it does.** New writer [bin/configure-zcode-skill-shadows.ps1](https://github.com/popcre/ai-devops/blob/main/bin/configure-zcode-skill-shadows.ps1), called by the Windows installer right after its ZCode skills stage ([bin/install-ai-devops-windows.ps1, lines 1191 to 1203](https://github.com/popcre/ai-devops/blob/main/bin/install-ai-devops-windows.ps1#L1191-L1203)). For each toolkit skill that `.agents/skills` also holds, it writes one off-switch into ZCode's own settings file (`.zcode/cli/config.json`, key `skill`, one entry per doubled copy, `{ "enable": false }`). ZCode then lists each skill once and a helper agent loads it by bare name. Skill folders are unchanged; other clients are untouched.
- **Tests.** [tests/test-configure-zcode-skill-shadows.ps1](https://github.com/popcre/ai-devops/blob/main/tests/test-configure-zcode-skill-shadows.ps1) (70 checks under each PowerShell edition), the installer suite ([scenario from line 360](https://github.com/popcre/ai-devops/blob/main/tests/test-install-ai-devops-windows.ps1#L360)) and [tests/test-installer-parity.sh](https://github.com/popcre/ai-devops/blob/main/tests/test-installer-parity.sh) all pass.
- **Docs.** [docs/model-setup.md from line 103](https://github.com/popcre/ai-devops/blob/main/docs/model-setup.md#L103) and the ZCode row of [docs/config-inventory.md](https://github.com/popcre/ai-devops/blob/main/docs/config-inventory.md#L117).
- **Issue #2795 is closed** (automatically on merge) with the cause, the fix, the proof and the installed-release proof as comments. A note on [#2791](https://github.com/popcre/ai-devops/issues/2791) says its ZCode proof line no longer holds.
- **Installed on edge-dev.** The Windows installer, admitted by the gate as an ordinary toolkit installation, installed release [48205245](https://github.com/popcre/ai-devops/commit/482052458d1e369f29810b386b940ed06a4dc932). Checked at 1:31 PM EST: installed copy at that commit and clean, launcher stamp equal to it, and the installed writer answers "already current: 65 hidden" under both Windows PowerShell 5.1 and PowerShell 7. `main` has moved on since (5f98fc9c at 1:50 PM EST); that is normal, the installed copy advances only through the installer.
- **Live proof.** One helper agent was refused the bare name before the fix. After one run of the writer, at 11:43 AM EST, two helper agents loaded bare names (`supabase-postgres-best-practices`, `slm-agent-evaluate`); a third loaded one again by 1:31 PM EST, after the install.
- **Shared database rulebook (`popcre/shared-db`).** Only the local copy on edge-dev was brought forward, to [11c1f2306](https://github.com/popcre/shared-db/commit/11c1f230693739f47378a070ca8b0599140fa7c5), after 11:01 AM EST. Nothing was pushed, no issue was touched, no database was read or written, no claim was held. The toolkit's close-out checker agreed after 1:46 PM EST: zero blocking claims, zero blocking stages, 10 open claims and 3 stages read. Two shared-db pull requests carry the `promotion-parked` label and none the `promotion-held` label; this session merged none of them.
- **Secrets sweep:** swept, nothing new. No credential, token or connection string appeared; the merged change holds only ordinary words such as "token" in documentation rows.
- **Docs pass:** nothing outside this file is stale. No rule book mis-states what changed. The one misleading sentence found is a code comment, listed as §6 step 3b.

### Still open

1. **4837 and 916.** They receive the fix at their next toolkit update. Whether they are affected at all was not inspected; there is no route to them from edge-dev.
2. **MiMo.** It also reads `.agents/skills`. Whether its helper agents hit the same refusal is unknown: [issue #2827](https://github.com/popcre/ai-devops/issues/2827), open, no owner.
3. **Two small defects in the installer parity test,** found on the way, both in [tests/test-installer-parity.sh](https://github.com/popcre/ai-devops/blob/main/tests/test-installer-parity.sh):
   a. on Windows it leaves a folder named `Microsoft` (holding `Windows/PowerShell/ModuleAnalysisCache`) in whatever folder it was started from. Present before this session's change: reproduced with the unchanged test on main `0f4c4226`.
   b. its header sentence at [line 11](https://github.com/popcre/ai-devops/blob/main/tests/test-installer-parity.sh#L11) says the test skips where `pwsh` is missing because "Linux/macOS have one installer". Linux CI does have `pwsh` and does run this test there.
4. **A leftover file that looks like a database password,** in the local shared-db folder on edge-dev: `.ai/tmp-dbpass.txt`, 41 bytes, dated 2026-11-12, untracked and not ignored by git. It existed before this session, was not opened, and nobody owns it. It is mentioned in no shared-db document.

Nothing is half-edited, no pull request of this session is open, no branch or working copy of the fix is left, and nothing is unpushed.

## 4. Everything We Tried That Did NOT Work

1. **A "fully qualified" skill name.** The refusal tells the caller to use one, but ZCode only gives such a name to plugin skills and to namespaced roots. `zcode:slm-agent-evaluate`, `agents:slm-agent-evaluate` and `agents/slm-agent-evaluate` all answer "Unknown skill" (recorded on #2795, confirmed by reading ZCode's code). Dead end by design.
2. **Removing a skill root or changing the folder layout.** ZCode has no setting that removes a root. Relying on `.agents/skills` alone would make ZCode depend on a hand-made link that the toolkit does not own, and would break on a machine without it. Making the two folders one folder does not help either: ZCode tells skills apart by path spelling, so it would still list each twice. Both rejected before any code was written.
3. **Reusing the toolkit's shared JSON writer** ([`bin/windows-json-file.ps1`](https://github.com/popcre/ai-devops/blob/main/bin/windows-json-file.ps1)) for the new stage. It needs PowerShell 7 only features, and every documented way of starting the Windows installer uses Windows PowerShell 5.1. The new writer therefore reads and writes JSON with means that exist in both editions, and calls Windows directly for the two things .NET Framework lacks (final path of a file, atomic replace).
4. **First check run, Linux.** The new stage tried its Windows calls on a Linux runner, where the installer parity test also runs. It failed there and the test failed. Fixed: the stage now stands down off Windows and says so ([bin/install-ai-devops-windows.ps1, line 1194](https://github.com/popcre/ai-devops/blob/main/bin/install-ai-devops-windows.ps1#L1194)); the writer does the same at [line 53](https://github.com/popcre/ai-devops/blob/main/bin/configure-zcode-skill-shadows.ps1#L53).
5. **First check run, Windows.** On a hosted runner the installer is handed its folders spelled short (`RUNNER~1`). Windows PowerShell 5.1 spells that out in `Path.GetFullPath`, PowerShell 7 keeps it, so the two editions wrote the off-switch under two different spellings. Fixed: the writer asks Windows for the long spelling of every path ([line 88](https://github.com/popcre/ai-devops/blob/main/bin/configure-zcode-skill-shadows.ps1#L88)), and the suite gained that scenario.
6. **Reproducing the Linux path before pushing.** edge-dev3 was reached by ssh but has no `pwsh`, so the parity test would only skip there. The Linux fix was reasoned out and left to CI; it passed there.
7. **Mistakes made while writing the tests,** each cost one run: a variable named `$home` (PowerShell variable names ignore case, and `$HOME` is read-only); `"$Path:"` inside a double-quoted string (parsed as a drive variable; write `${Path}:`); a helper that returned one entry as a bare string instead of a one-item array (return `,@(...)`); a check written for an output line the writer no longer prints; in `jq`, `a // b` yields `b` when `a` is `false` (use `-e '.x == false'`); a prefix check written for `\?\` where the system returns `\\?\`.
8. **Searching ZCode's program file with `grep -o -E ".{2600}needle"`.** The file is one 15.8 MB line; that pattern ran past two minutes. A five-line Node script that reads the file and prints a window around each match answers at once.
9. **Reading MiMo's behaviour the same way.** MiMo's program on edge-dev is packed in a seed archive, and no unpacked code file was found in a bounded search. Not examined further; filed as #2827.
10. **The pull-request waiter gave up once** after its 60-minute deadline while three Windows sections were still running. Restarted once; it then reported success. Windows sections take up to 40 minutes, so expect one restart.
11. **`$TMPDIR` is empty in this shell.** Give scratch files an explicit folder, or the redirect lands in the root of the drive and is refused.

## 5. Root Causes and Key Findings

- **Why ZCode refused.** ZCode lists every `SKILL.md` one folder deep under each of its two roots and tells skills apart by file path, so a skill in both roots is listed twice. A main session loads the first found. A helper agent goes through a second path that matches every listed skill by name and gives up when more than one matches.
- **Why the pair exists.** On edge-dev, `.agents/skills` has been a link to `.codex/skills` since 2026-10-05. The link was not made by the toolkit. Wherever it exists, all 65 shared skills are doubled for ZCode; where it does not exist, nothing is doubled and the writer writes nothing.
- **The lever.** ZCode's settings file accepts an off-switch keyed by the absolute path of a `SKILL.md`. ZCode honours it by that path or by the path's link target, so the long spelling works for both.
- **Who owns which entry.** The writer touches only entries shaped `<second root>\<name>\SKILL.md` whose `<name>` is a toolkit skill (carrying the managed marker, or retired into `skills-quarantine`). Such an entry is written while the pair exists and removed once it is gone. Everything else in the file is preserved ([classification at line 157](https://github.com/popcre/ai-devops/blob/main/bin/configure-zcode-skill-shadows.ps1#L157), [reconcile at line 230](https://github.com/popcre/ai-devops/blob/main/bin/configure-zcode-skill-shadows.ps1#L230)).
- **Safety guard.** An off-switch also switches off its link target. If the two roots were one folder, an entry would turn the skill off in ZCode entirely, so the writer compares the final paths of the two files first and skips equal ones with a warning ([line 97](https://github.com/popcre/ai-devops/blob/main/bin/configure-zcode-skill-shadows.ps1#L97), [line 277](https://github.com/popcre/ai-devops/blob/main/bin/configure-zcode-skill-shadows.ps1#L277)).
- **No restart needed.** A helper agent started after the settings file changed already sees the change.
- **The Windows installer is not Windows-only in tests.** Linux CI runs it under `pwsh`. Any stage that needs Windows must stand down elsewhere and say so.
- **Two PowerShell editions, two spellings of one path.** Anything written into a file from a path must use one normalization for both editions, or machines updated by both rewrite the file on every alternation.

## 6. Exact Next Steps

No step needs the owner. Take them in order; each says how you know it worked.

1. **4837 and 916, only if the owner asks for sooner than their next routine update.** Start a session on that computer. Run the installed copy of [`bin/configure-zcode-skill-shadows.ps1`](https://github.com/popcre/ai-devops/blob/main/bin/configure-zcode-skill-shadows.ps1) there in preview mode (with `-DryRun`). **You'll know it worked when** the preview reports either "none to hide" (that machine is not affected) or a list of copies it would hide; a real run then ends with "skill shadows configured", and a helper agent loads a bare skill name.
2. **MiMo, issue [#2827](https://github.com/popcre/ai-devops/issues/2827).** In a MiMo session on a machine where MiMo is installed (edge-dev is one), have a helper agent load one bare shared skill name, on a reference-only skill such as `supabase-postgres-best-practices`, and report the raw outcome. If it loads, close #2827 with that evidence. If it is refused, find MiMo's per-skill switch in its own settings file and apply the same cure as PR #2805, in the MiMo install stage only, with tests. **You'll know it worked when** #2827 is closed by one of those two outcomes.
3. **The two small defects in the parity test.** One short pull request covers both: (a) point PowerShell's module cache at a scratch folder for the child process the test starts, so nothing is left behind, and assert the folder is absent afterwards; (b) replace the sentence at [line 11](https://github.com/popcre/ai-devops/blob/main/tests/test-installer-parity.sh#L11) with one that says the test runs wherever `pwsh` exists, Linux CI included, and that the ZCode part applies on Windows only. Give the defects an issue of their own first, or say in the pull request that they came from here. **You'll know it worked when** the test leaves no `Microsoft` folder behind when started from an empty folder, and the header says what actually happens.
4. **The password-named file in the shared-db folder on edge-dev** (`.ai/tmp-dbpass.txt`, see §3). Do not print it. Decide what it is without opening it in chat: the folder `.ai/tmp-pg` next to it suggests a throwaway local test database. If a local tool still needs it, leave it and add that folder to `.git/info/exclude` on that machine so it cannot be staged by mistake; if nothing needs it, delete it. If it turns out to hold a real credential, it belongs in the 1Password vault `vibe_coding` and the file goes. Record the decision in one comment on the shared-db issue that owns local test tooling, or open one. **You'll know it worked when** `git status` in that folder no longer shows the file as untracked.
5. **Close this workstream.** When steps 1 to 4 are done or each has an issue of its own, delete this file in the pull request that closes the last of them (the successor rule in the handoff standard). **You'll know it worked when** `HANDOFF.d/` no longer lists this file and nothing open still points at it.

## 7. Constraints and Gotchas in Force

- **Never pull or merge in the installed toolkit folder on a machine.** It advances only through its own installer, started from a separate working copy at the merged commit, with the task gate declared as `installation`. Declaring the gate inside the installed folder is refused as "same-source".
- **The Windows installer must stay usable by Windows PowerShell 5.1.** No `??`, no ternary, no `ConvertFrom-Json -AsHashtable`, no three-argument `File.Move`. Script files under `bin/` must stay ASCII-only.
- **Every test that starts the installer must pin all of its home folders** (`ClaudeHome`, `CodexHome`, `ZCodeHome`, `MimoHome`, and since PR #2805 `AgentsSkillsRoot`) to scratch folders. A missing one reads the real home. An earlier incident wiped a real skills folder this way.
- **`main` is protected.** Branch, pull request, merge queue. The queue squashes, so compare landed files, never commit ancestry, when proving a branch landed.
- **The pull-request waiter stops after 60 minutes.** Windows sections take up to 40; start it again when it exits with code 2.
- **Do not touch:** other sessions' `HANDOFF.d/` files; the hand-made `.agents/skills` link (not toolkit-owned; the writer only reads it); MiMo's settings until #2827 says what is needed; the parked shared-db pull requests (not this session's).
- **ZCode's off-switch is a vendor feature read from its code, not from a published promise.** If a future ZCode ignores the `skill` entries, helpers go back to refusing bare names; nothing else breaks.

## 8. Access and Environment

- **GitHub:** `gh` is signed in on edge-dev; calls go through the toolkit's `bin/ai-gh`. The commit identity must read `Albert Hazan <u2giants@users.noreply.github.com>`.
- **PowerShell:** both Windows PowerShell 5.1 (`powershell.exe`) and PowerShell 7 (`pwsh`) are on edge-dev. edge-dev3 has neither.
- **ZCode on edge-dev:** desktop app signed in; its helper agents are started from this chat.
- **MiMo on edge-dev:** installed, with 65 managed skills; no unattended mode was found for it.
- **Secrets:** none were used. Should one be needed it lives in the 1Password vault `vibe_coding`, by reference only.
- **Close-out receipt:** the toolkit checker's JSON for this session is kept in this session's private scratch on edge-dev only; its verdict is quoted in §3.

## 9. Open Questions and Risks

- **Are 4837 and 916 affected?** Unknown. They are affected only if `.agents/skills` exists there and holds same-named copies.
- **MiMo (decided 2026-11-24: file, do not guess).** Tracked as #2827. The standing delegation pairs include MiMo Pro to MiMo Flash for helper steps, so a refusal there would matter.
- **ZCode could change its settings shape.** Decided 2026-11-24: accept the risk; the writer fails safe (a failed stage is a warning, the install completes).
- **A retired toolkit skill that someone keeps privately under the same name in `.agents/skills`.** Its copy would stay switched off for ZCode after the toolkit retires the skill, until the next installer run removes the entry. Judged rare enough to leave as is on 2026-11-24.
- **The installed toolkit on edge-dev is already behind `main` again.** Normal; `main` moves several times an hour.

## Part (b) — Helper Agents Dispatched This Session

Four helper agents, each a one-step probe with no files, no branch and no working copy of its own. All four are finished; there is nothing to resume or to clean.

### Agent: probe 1 (general-purpose helper)
- **Asked to do:** call the Skill tool once with the bare name `supabase-postgres-best-practices`, follow nothing, report the raw outcome.
- **Actually did:** exactly that.
- **Found:** `REFUSED — Skill name is ambiguous for subagent; use the fully qualified skill name`. This reproduced #2795 before any change.
- **PR / branch:** none.
- **Worktree:** finished.
- **Deliberately did NOT do, and why:** nothing beyond the one call, so the probe could not change anything.

### Agent: probe 2 (same name, after the fix)
- **Asked to do:** the same call, after the settings file was changed at 11:43 AM EST.
- **Actually did:** exactly that.
- **Found:** `LOADED`.
- **PR / branch:** none. **Worktree:** finished.
- **Deliberately did NOT do, and why:** did not follow the loaded skill; it is reference text and following it was out of scope.

### Agent: probe 3 (`slm-agent-evaluate`, the skill named on #2795 and #2791)
- **Asked to do:** the same call with that name, and call no MCP tool.
- **Actually did:** exactly that.
- **Found:** `LOADED`.
- **PR / branch:** none. **Worktree:** finished.
- **Deliberately did NOT do, and why:** did not run the skill; running it writes a report file and calls a paid helper, which a probe must not do.

### Agent: probe 4 (after the release was installed)
- **Asked to do:** the same call as probe 1, with the installed release in place.
- **Actually did:** exactly that.
- **Found:** `LOADED`, by 1:31 PM EST.
- **PR / branch:** none. **Worktree:** finished.
- **Deliberately did NOT do, and why:** nothing beyond the one call.

## Mandatory Self-Audit Gate

1. **Can a newcomer continue without asking a question?** Yes. §1 defines the toolkit, ZCode and every machine; §3 separates what is done from what is open, with links; §6 gives each next step and its proof. Nothing in flight needs explaining because nothing is in flight.
2. **Can they continue as well as I could now?** Yes. The vendor behaviour, the two-edition path spelling, the Linux-runner fact and every dead end are in §4 and §5.
3. **Is every detail for flawless execution present?** Yes: background (§2), state (§3), failures (§4), causes (§5), steps and gates (§6), constraints (§7), access (§8), risks (§9), helper agents (part b). Every file and commit is a GitHub link; no machine path is written.
4. **If the owner read only §0, would he see every decision and no technical approval?** Yes. §2 to §9 and part (b) were walked line by line: the only sentence needing his judgement is "sooner on 4837 and 916?", which is §0's first item with a recommendation. Steps in §6 are technical and are not asks. §0 says explicitly that nothing else needs him.

The checklist passes on every item. Gap found while auditing and fixed: the password-named file was first only a note in §3, with nobody assigned. It now has its own step (§6 step 4) and is marked technical, so it needs no owner decision.
