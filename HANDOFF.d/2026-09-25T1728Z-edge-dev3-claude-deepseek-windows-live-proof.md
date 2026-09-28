---
issue: 852
status: OPEN
owner: claude/ai-deepseek-windows-support-0f271b
---

# HANDOFF — ai-deepseek Windows live proof (2026-09-25 17:28 UTC / 1:28 PM EDT, edge-dev3/claude)

Issue that proves this done: [popcre/ai-devops#852](https://github.com/popcre/ai-devops/issues/852)
Landed code: [popcre/ai-devops#857](https://github.com/popcre/ai-devops/pull/857), merge commit `36349397604b572d9d019d8c4e07fa58cec4f351`.

## 0. Decisions only the owner can make

None. Albert already asked for this work ("do issue #852"). The only thing
needed from him is a Windows machine that is powered on and running a session.

## 1. What this application is

`popcre/ai-devops` holds Albert's shared AI tooling. `bin/ai-deepseek` is the
write-capable DeepSeek harness: it clones a repository into a private
remote-less clone, runs DeepSeek inside the pinned OpenCode (`opencode.exe`),
then `land` fetches the result branch `deepseek/<name>` back into the real
repository and `cleanup` deletes the clone. Windows runs it through Git Bash
via `bin/ai-deepseek.cmd`.

## 2. What we set out to do, and why

Issue #852: make `bin/ai-deepseek` work on Windows (Git Bash), add its test to
the Windows CI lane, and prove it live on a real Windows machine. The harness
was Linux-only when it merged in #846.

## 3. Current state — what is true right now

Done and merged (#857):
- On Windows, the default config, state, and OpenCode paths come from
  `USERPROFILE`, converted with `cygpath -u`.
- `--dir` and the three `XDG_*` variables are passed to `opencode.exe` as
  Windows paths (`cygpath -w`) through a new `native_path` helper.
- The 1Password CLI resolves to the trusted WinGet package `op.exe` (the
  issue #686 pattern copied from `bin/ai-deepseek-agent`). `AI_DEEPSEEK_TEST_DIR`
  lets the test fixture `op` pass that check.
- Token file, reference line, and `op read` output are stripped of CR.
- `tests/test-ai-deepseek.sh` skips the `/proc` argv-leak scan visibly
  (`SKIP:` line) only when `/proc` is missing. Git Bash has `/proc`, so on
  Windows CI the scan ran and passed.
- `config/ci-suite-manifest.json` lists the suite in `windows_offline_bash`
  and in Windows shard 6 (it was already in `windows_sensitive_bash`).
- Windows CI section 6 on #857: 27/27 PASS.
- Installer: no change needed; `bin/ai-deepseek.cmd` already existed, and
  `tests/test-bin-cmd-launchers.sh` passes.

NOT done: the live proof on a real Windows machine (section 6 below).

## 4. What was tried and did not work

- Reaching a Windows machine from edge-dev3: `ssh 4837`, `ssh al8960ofc`, and
  `ssh <4837 Tailscale address>` all timed out or failed host-key verification. edge-dev3
  has no `~/.ssh/config`, no Windows key, and no `tailscale` command. So no live
  Windows run was possible from this session.
- First CI push failed `tests/test-workflow-policy.sh`: my manifest edit hit
  `windows_sensitive_bash` (first match) instead of `windows_offline_bash`.
  Fixed in the second commit on #857.

## 5. Root causes and key findings

- `opencode.exe` is a native Windows program, so MSYS-style `/c/...` paths in
  `--dir` or `XDG_*` are wrong for it; they must be `C:\...`.
- The Windows home for managed files is `USERPROFILE`, not Git Bash `$HOME`
  (they can differ; see memory `4837-home-drive-z-trap`).

## 6. Exact next steps

Run these ON a Windows machine (4837 = al8960ofc, or 916), in Git Bash,
from a checkout of `popcre/ai-devops` at current `main`:

1. Sync: "sync my dotfiles" (installs current `bin/` and profiles). Confirm
   `bin/setup-opencode-glm.sh` has installed the pinned OpenCode.
2. `ai-deepseek doctor --live` — success is every line `PASS`, ending with
   `PASS live turn`.
3. Make a scratch repository (e.g. `git init` a temp folder with one commit;
   no GitHub remote is needed), then:
   `ai-deepseek implement winproof --repo <scratch> --prompt "Add a file hello.txt containing hi and commit it."`
   Success: output ends with `TASK: winproof  SESSION: ses_...` and
   `TOOL_ERRORS: 0`.
4. `ai-deepseek land winproof` — success: `Landed deepseek/winproof at <sha>`,
   and `git -C <scratch> log deepseek/winproof` shows the commit.
5. `ai-deepseek cleanup winproof` — success: `Removed task 'winproof'`.
6. Comment the outputs on #852 (signed), close #852, and delete this
   handoff file in a docs-only PR.

If a step fails, fix it in a new worktree branch with a PR, re-run the steps,
then close.

## 7. Constraints and gotchas in force

- SSH into Windows lands in an elevated session (memory
  `windows-ssh-sessions-are-elevated`); that does not matter for this proof.
- `4837` is the same computer as `al8960ofc`.
- Never push to `main`; PR plus merge queue. Sign GitHub posts.
- The DeepSeek key comes from 1Password (`DEEPSEEK_API_KEY=op://...` in
  `~/.config/ai-devops/mcp.env` under the Windows profile) — never paste it.

## 8. Access and environment

- Windows: 4837/al8960ofc (Tailscale address in the private machine atlas); 916 (Tailscale address in the private machine atlas, user
  `ahazan2`, key `~/.ssh/916-alien`, often offline).
- 1Password service-account token file: `%USERPROFILE%\.config\ai-devops\op-service-account`.

## 9. Open questions and risks

- Untested live: whether `opencode.exe` accepts the `C:\` XDG paths the same
  way the Linux build accepts POSIX ones. CI used a fake OpenCode.
- Untested live: `timeout` wrapping a native `.exe` from Git Bash; if the turn
  hangs or is not killed, look there first.
