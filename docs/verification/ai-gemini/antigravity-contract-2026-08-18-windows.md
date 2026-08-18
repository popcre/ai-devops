# Antigravity CLI contract and safety-boundary result

Date: 2026-08-18
Machine: edge-dev, Windows 11
CLI: Antigravity `agy` 1.1.14
Repository revision: `f25c725765f779012c3fc6448b109de3e09a81a6`

## Result

`ai-gemini` is blocked before implementation. The release requires a dedicated,
non-writing permission profile that does not alter Albert's ordinary Antigravity
settings. The documented CLI and the installed 1.1.14 command provide no
per-process configuration-home or permissions-profile flag.

The available `--project` and `--new-project` flags select an existing project or
create one, but neither accepts a reviewer permission policy. Google documents
project settings as interactive project configuration, and a new project starts
with read and write access to its folders. Automatically creating or modifying a
project would therefore not prove an isolated read-only boundary. Copying OAuth
or rewriting/restoring the shared settings file is prohibited by the plan.

No `bin/ai-gemini` wrapper, machine installer entry, or live review was created.

## Reproducible observations

The following commands were run using the installed executable. They did not
print OAuth data or inspect the account files.

```powershell
$agy = "$env:LOCALAPPDATA\agy\bin\agy.exe"
& $agy --version
& $agy --help
& $agy models
& $agy --output-format json --print-timeout 1m --print '/usage'
```

Observed command-line options include `--conversation`, `--model`, `--project`,
`--new-project`, `--mode`, `--sandbox`, `--log-file`, and JSON output. No option
selects a settings file, configuration directory, profile, permissions file, or
data home. The available models included `gemini-3.7-flash-high`.

`/usage` returned structured Gemini weekly and five-hour buckets with fractions
and reset times. Its response had zero model tokens. This confirms the fixture
shape only; it does not prove a future version will keep that contract.

## Official documentation checked

- [Permissions](https://antigravity.google/docs/cli/permissions) places fine-grained rules in `~/.gemini/antigravity-cli/settings.json` and says workspace reads and writes are automatically allowed by default.
- [CLI settings](https://antigravity.google/docs/cli-settings) identifies the same persistent settings file and documents only individual launch overrides such as `--sandbox`.
- [Projects](https://antigravity.google/docs/cli/projects) documents selecting or creating projects, but does not document passing a read-only permission policy through the CLI. Project settings are separate, persistent project configuration.

## Contract fixtures

`tests/test-ai-gemini.sh` verifies redacted, static examples for model listing,
successful and empty turns, exact `/model`, `/usage`, quota/authentication errors,
and malformed JSON. It never invokes `agy`.

Run:

```bash
bash tests/test-ai-gemini.sh
```

## Required upstream change before resuming

Google must document and provide a command-line mechanism that lets the wrapper
select a dedicated read-only permission profile without copying OAuth or changing
the shared global settings file. After that exists, repeat the Windows hostile
write canary and then continue with plan Step 2.
