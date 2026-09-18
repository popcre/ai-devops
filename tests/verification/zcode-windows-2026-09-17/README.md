# ZCode Windows baseline — qualification facts (2026-09-17)

Live machine: `edge-dev`, user `ahazan`. Every claim below carries the exact
command that reproduces it. Probes were run from Git Bash on 2026-09-17
(evening local time) against the installed ZCode build. This file freezes the
baseline that [Step 1 of the ZCode Windows support
plan](../../../plan_zcode-windows-support.md) requires; it is evidence, not a
test — nothing here runs in CI.

## 1. Versions (two version numbers — always record both)

- **Desktop app:** `3.12.3.7463` (ProductVersion = FileVersion).

  ```powershell
  (Get-Item 'C:\Program Files\ZCode\ZCode.exe').VersionInfo | Format-List
  # CompanyName: ZCode   ProductName: ZCode
  ```

- **CLI core (zcode.cjs):** `0.16.5`.

  ```bash
  ELECTRON_RUN_AS_NODE=1 "/c/Program Files/ZCode/ZCode.exe" \
    "/c/Program Files/ZCode/resources/glm/zcode.cjs" --help | head -1
  # zcode 0.16.5
  ```

- **Embedded Node:** `v24.14.0` (from `zcode doctor`, §9).

## 2. Install source (decides D9 — outcome: real winget package EXISTS)

- **winget positively confirms the package:** id `ZhipuAI.ZCode`, version
  `3.12.3` (matches the installed desktop `3.12.3.7463` major.minor.patch).

  ```bash
  winget search --exact --id ZhipuAI.ZCode
  # Z Code   ZhipuAI.ZCode   3.12.3   winget
  ```

- **Registry uninstall key** (HKLM, all-users Electron NSIS-style install):

  ```powershell
  Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' |
    ForEach-Object { $p = Get-ItemProperty $_.PSPath;
      if ($p.DisplayName -like '*ZCode*') { $p | Select-Object DisplayName,
        DisplayVersion, InstallLocation, Publisher, UninstallString | Format-List } }
  # DisplayName     : ZCode 3.12.3
  # DisplayVersion  : 3.12.3
  # Publisher       : ZCode
  # UninstallString : "C:\Program Files\ZCode\Uninstall ZCode.exe" /allusers
  ```

- **Install dir:** `C:\Program Files\ZCode` — `ZCode.exe` (Electron shell) plus
  standard Electron runtime files; `resources\` holds `app.asar`,
  `app.asar.unpacked`, `config\provider\zcode-builtin.json`, `glm\zcode.cjs`
  (the CLI core), `tools\`, `elevate.exe`, `app-update.yml` (vendor bytes —
  never edit).

  ```bash
  ls "/c/Program Files/ZCode" && ls "/c/Program Files/ZCode/resources"
  ```

**D9 outcome:** the winget id `ZhipuAI.ZCode` is positively confirmed, so
Step 2 wires the winget DSC resource (presence + managed install channel) —
no vendored installer row is needed.

## 3. Headless provider-env requirement (decides D13 — env set is REQUIRED)

- **Without the provider env vars, every headless `-p` run fails before the
  model call** (reproduced twice, deterministically):

  ```bash
  cd /tmp && env -u ZCODE_BUILTIN_PROVIDER_CONFIG_FILE \
    -u ZCODE_BUILTIN_PROVIDER_BUNDLED_CONFIG_FILE \
    -u ZCODE_PERSONAL_PROVIDER_CONFIG_FILE \
    ELECTRON_RUN_AS_NODE=1 "/c/Program Files/ZCode/ZCode.exe" \
    "/c/Program Files/ZCode/resources/glm/zcode.cjs" -p "OK?" --json
  # 无法定位 CLI ZCode Built-in Provider Config：
  # C:\Program Files\ZCode\resources\glm\provider\zcode-builtin.json,
  # C:\config\provider\zcode-builtin.json
  ```

  (Message is Chinese: "cannot locate CLI ZCode Built-in Provider Config".
  The two probed fallback paths do not exist.)

- **With the blocker-watch env assembly, the run authenticates and answers:**

  ```bash
  NEWEST_M=$(cygpath -m "$(ls -t ~/.zcode/v2/runtime/provider/*/*/*/zcode-builtin.json | head -1)")
  env ZCODE_BUILTIN_PROVIDER_CONFIG_FILE="$NEWEST_M" \
    ZCODE_BUILTIN_PROVIDER_BUNDLED_CONFIG_FILE="C:/Program Files/ZCode/resources/config/provider/zcode-builtin.json" \
    ZCODE_PERSONAL_PROVIDER_CONFIG_FILE="$(cygpath -m ~/.zcode/v2/provider_config.json)" \
    ELECTRON_RUN_AS_NODE=1 "/c/Program Files/ZCode/ZCode.exe" \
    "/c/Program Files/ZCode/resources/glm/zcode.cjs" -p "Reply with the single word OK" --json
  # "response": "OK"  — one model request, status idle
  ```

  The newest runtime provider config on the probe date was
  `~/.zcode/v2/runtime/provider/windows-x86_64/3.12.3/endpoint-78d7c3be…/zcode-builtin.json`
  (the endpoint hash directory changes; resolve the newest at run time, as
  `bin/ai-blocker-watch` `{zcode_builtin}` already does).

**D13 outcome:** shims and `bin/ai-zcode` MUST assemble the same three
`ZCODE_*_PROVIDER_CONFIG_FILE` vars (resolving the newest runtime copy) plus
`ELECTRON_RUN_AS_NODE=1`. Plain invocation is not an option.

## 4. Which model answered

`~/.zcode/v2/provider_config.json` (read with grep — never dump the file):

```bash
grep -o '"modelId[^,}]*' ~/.zcode/v2/provider_config.json      # "modelId": "GLM-5.3"
grep -o '"account[^,}]*'  ~/.zcode/v2/provider_config.json | head -1
# "account:zai-individual-coding-plan"
```

The headless probes authenticated as the signed-in desktop user (credentials
exist at `~/.zcode/v2/credentials.json` — existence only, never read) and ran
**GLM-5.3** under `account:zai-individual-coding-plan`.

## 5. Parser vs `--help` drift — flags the CLI ADVERTISES BUT REJECTS

`--max-turns <n>`, `--settings <path>`, and `--allowed-tools <list>` are listed
by `--help` but rejected by the 0.16.5 argument parser wherever they are
placed:

```bash
… zcode.cjs --max-turns 2 --json -p "Reply with the single word OK"
# Unknown option '--max-turns'. To specify a positional argument starting with a '-',
# place it at the end of the command after '--', as in '-- "--max-turns'
… zcode.cjs --settings C:/tmp/settings.json --mode plan -p "…" --json
# Unknown option '--settings'. (same usage dump)
… zcode.cjs --allowed-tools "Read,Grep,Glob" --mode yolo -p "test" --json
# Unknown option '--allowed-tools'. (same usage dump)
```

Proven-accepted flags in 0.16.5: `-p/--print <prompt>`, `--json`,
`--mode plan|build|edit|yolo`, `--disallowed-tools "Edit,Write,ApplyPatch,Bash"`,
`--cwd`, and the subcommands (`version`, `doctor`, `skills`, `login`,
`logout`, `plugins`, `commands`). **Consequence for the wrapper:** turn
bounding via `--max-turns` is UNAVAILABLE, a tool ALLOWLIST is UNAVAILABLE,
and an isolated per-run settings file is UNAVAILABLE. Safety bounds are:
`--mode plan` + `--disallowed-tools` denylist + a wrapper-enforced wall-clock
timeout. (`--resume`, `--target` were not probed headlessly; `--resume` is
already proven by the shipped blocker-watch harness.)

⚠️ **Correction of a first misreading (recorded so it is not repeated):** an
early probe claimed write-denial "via `--allowed-tools`". That run had
actually been rejected by the parser before any model call — no denial was
proven. Only the two probes in §6 below are write-denial evidence.

## 6. Write-denial proofs

Both proofs ran in an empty throwaway directory and asked the model to create
a file; neither produced one:

- `--mode plan` (permission mode denies writes) — the run completed
  (`projection.status: idle`, full JSON, model listed the directory):

  ```bash
  … zcode.cjs --mode plan -p "Create a file named probe-plan.txt in the
    current directory containing the word hello. Then reply DONE." --json
  # ls shows 0 matching files after the run
  ```

- `--mode plan` + write/bash tool DENYLIST (the mechanism the wrapper uses,
  since allowlists do not exist in this build):

  ```bash
  … zcode.cjs --disallowed-tools "Edit,Write,ApplyPatch,Bash" --mode plan \
    -p "Create a file named probe-dis.txt containing hello, then reply DONE." --json
  # run completed (status idle, response answered); directory still empty
  ```

## 7. Hooks — do NOT fire in headless `-p` runs (0.16.5)

Three scopes probed, all with `hooks.enabled: true` and
`UserPromptSubmit`/`PostToolUse`/`Stop` command hooks whose command appended
stdin to a capture file (`bash -c 'cat >> <file>'`):

1. **Workspace scope** (`<cwd>/.zcode/config.json`): hooks do not run; the
   daily log records the reason —
   `config.project_hooks.pending_trust` (warn, module `adapters.config`,
   "Project hooks pending workspace trust") and
   `workspace_hook.feature_disabled` (module `workspace_hook_trust`). The
   workspace-hook trust feature is disabled in this build.
2. **User scope** (`~/.zcode/cli/config.json`, temporarily backed up,
   probe-written, and restored within the same minute): hooks do not run and
   the log records **no dispatch events at all** in the probe window —
   headless `-p` mode does not dispatch config-file hooks, from any scope.
3. `--settings` (isolated config file) — the flag is rejected by the parser
   (§5), so that documented route does not exist in this build.

Log inspection command:

```bash
grep -h '"event":"config.project_hooks.pending_trust"' \
  ~/.zcode/cli/log/zcode-$(date +%F).jsonl
```

**Consequence (feeds Step 7):** the completion-check hook registration
targets **interactive/TUI sessions**; its live verification in this build is
structural (config shape parses, `hooks.enabled: true`, `--check` exits
clean/2 on drift), not a headless firing proof. The hook stdin payload shape
could not be captured live in a headless run — hooks never dispatch there;
the payload contract remains as documented by the vendor `zcode-guide`
plugin (JSON on stdin carrying session and tool context), unverified live.

## 8. `--json` headless output shape (what the wrapper parses)

One JSON document on stdout when the run completes:

```json
{
  "sessionId": "sess_<uuid>",
  "traceId": "<uuid>",
  "turnId": "turn_<uuid>",
  "response": "OK",
  "usage": { "source": "provider", "modelRequestCount": 1, "inputTokens": 39890,
             "outputTokens": 30, "totalTokens": 39920, "cacheReadTokens": 9728,
             "cacheWriteTokens": 0, "reasoningTokens": 0, "webFetchRequests": 0,
             "webSearchRequests": 0 },
  "eventCount": 39,
  "projection": { "status": "idle", "turnCount": 1, "totalTokenCount": 39920,
                  "contextUsed": 39920, "contextWindow": 200000 }
}
```

Stderr carries a harmless one-line `ZCode Built-in skipped (not-due)` notice.
The wrapper's `ask` parses `response` (final text), `sessionId`, and
`usage`/`projection` for spend reporting.

## 9. `zcode doctor` (CLI core's own probe — minimal)

```bash
… zcode.cjs doctor   # with the §3 env set
# version: 0.16.5
# process: node
# node: v24.14.0
# platform: win32/x64
# sea: no (optional)
# default artifact: node-bundle
```

No auth/MCP/hook checks of its own — `ai-zcode doctor` must do those itself.

## 10. Unmanaged-state inventory (the baseline Step 4/5/6 migrate)

```bash
cmd //c "dir /AL C:\Users\ahazan\.zcode"   # 09/17/2026 <JUNCTION> skills [\??\C:\Users\ahazan\.claude\skills]
cmd //c "dir /AL C:\Users\ahazan\.agents"  # 09/17/2026 <JUNCTION> skills [\??\C:\Users\ahazan\.codex\skills]
```

- `~/.zcode/skills` is a hand-made junction → `~/.claude/skills`
  (`~/.agents/skills` separately → `~/.codex/skills`; D11 leaves it alone).
- `~/.zcode/cli/config.json` — **exists as of 2026-09-17 evening** (the plan's
  same-day earlier baseline said absent; the desktop app created it). It
  contains ONLY `plugins.enabledPlugins` (`computer-use@…: true`) — no `mcp`,
  no `hooks`. The MCP writer must merge around this real file.
- `~/.zcode/AGENTS.md` — absent (to be seeded, Step 5).
- `~/.zcode/v2/setting.json` — `memoryEnabled: true` (owner enabled it
  2026-09-17; plan §13 Q3 settled).
- `~/.zcode/v2/credentials.json` — exists (existence-only check everywhere).
- Session store (Step 8 targets): `~/.zcode/cli/db/db.sqlite` + `-wal`/`-shm`,
  `~/.zcode/cli/rollout/model-io-sess_<uuid>.jsonl`,
  `~/.zcode/cli/exec/sess_<uuid>/`, logs in `~/.zcode/cli/log/zcode-<date>.jsonl`.

**Junction leak, proven live:** `zcode skills list` (with the §3 env set)
reports **111 skills** with duplicate `user/zcode` + `user/agents` entries per
name and Claude-only skills (e.g. `claude-transcript-backup`) visible to
ZCode — exactly the D1-migration motivation.
