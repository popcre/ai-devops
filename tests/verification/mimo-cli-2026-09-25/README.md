# MiMoCode CLI qualification — edge-dev 2026-09-25 (EDT)

Probe machine: **edge-dev** (Windows 11). The standalone MiMoCode CLI was
absent until this probe (`tests/verification/mimo-windows-2026-09-23/README.md`
recorded it ABSENT). Everything below is live, captured verbatim on 2026-09-25.
This closes plan decision D10 (exact `mimo run` flag set) and re-baselines
`bin/ai-mimo` STEP 0. Issue: #829.

## Install (sanctioned route)

Official Xiaomi npm package `@mimo-ai/cli` (publisher "Xiaomi MiMo Team",
repo `XiaomiMiMo/MiMo-Code`, homepage `https://mimo.xiaomi.com/coder`; the
Desktop app itself depends on the same `@mimo-ai` npm scope).

```bash
npm install -g @mimo-ai/cli
# added 3 packages in 32s
# npm warn allow-scripts: @mimo-ai/cli@0.1.15 (postinstall: bun ./postinstall.mjs || node ./postinstall.mjs)
```

The blocked postinstall is harmless on Windows: `postinstall.mjs` returns early
on `win32` ("the bin/mimo wrapper finds the binary via node_modules traversal")
and only prints a migration notice recommending the vendor's native installer
(`irm https://mimo.xiaomi.com/install.ps1 | iex`). The npm route stays the
toolkit route: supported package management, reversible
(`npm uninstall -g @mimo-ai/cli`), no OS binary overwritten. Platform binaries
`@mimo-ai/mimocode-windows-x64{,-baseline}` ship as package deps.

```bash
$ command -v mimo
/c/Users/ahazan/AppData/Roaming/npm/mimo

$ mimo --version
0.1.15
```

## `mimo run --help` (verbatim — closes D10)

```text
mimo run [message..]

run mimocode with a message

Positionals:
  message  message to send                                                     [array] [default: []]

Options:
  -h, --help                                  show help                                    [boolean]
  -v, --version                               show version number                          [boolean]
      --print-logs                            print logs to stderr                         [boolean]
      --log-level                             log level
                                                [string] [choices: "DEBUG", "INFO", "WARN", "ERROR"]
      --pure                                  run without external plugins                 [boolean]
      --command                               the command to run, use message for args      [string]
  -c, --continue                              continue the last session                    [boolean]
  -s, --session                               session id to continue                        [string]
      --fork                                  fork the session before continuing (requires
                                              --continue or --session)                     [boolean]
      --share                                 share the session                            [boolean]
  -m, --model                                 model to use in the format of provider/model  [string]
      --agent                                 agent to use                                  [string]
      --format                                format: default (formatted) or json (raw JSON events)
                                          [string] [choices: "default", "json"] [default: "default"]
  -f, --file                                  file(s) to attach to message                   [array]
      --title                                 title for the session (uses truncated prompt if no
                                              value provided)                               [string]
      --attach                                attach to a running mimocode server (use the URL
                                              printed by `mimo serve`)                      [string]
  -p, --password                              basic auth password (defaults to
                                              MIMOCODE_SERVER_PASSWORD)                     [string]
      --dir                                   directory to run in, path on remote server if
                                              attaching                                     [string]
      --port                                  port for the local server (defaults to random port if
                                              no value provided)                            [number]
      --variant                               model variant (provider-specific reasoning effort,
                                              e.g., high, max, minimal)                     [string]
      --thinking                              show thinking blocks        [boolean] [default: false]
      --role                                  role for the injected message (assistant injects text
                                              as model output then triggers continuation)
                                                             [string] [choices: "user", "assistant"]
      --dangerously-skip-permissions, --yolo  auto-approve permissions that are not explicitly
                                              denied (dangerous!)         [boolean] [default: false]
```

Qualification consequences for `bin/ai-mimo`:

- **Model selector EXISTS**: `-m/--model`, format `provider/model`.
- **Directory flag is `--dir`** — the wrapper's pre-qualification `--cwd`
  guess was wrong and is now refused as an unknown option.
- `--yolo` is an alias of `--dangerously-skip-permissions` (wrapper refusal
  already covered both; now proven).
- `--format json` exists but its raw event shape is UNQUALIFIED; the wrapper's
  `--json-output` keeps wrapping text locally with jq.

## Models (verbatim)

```text
$ mimo models
deepseek/deepseek-flash — window 1M, compacts at 900K
deepseek/deepseek-v4-pro — window 1M, compacts at 900K
mimo/mimo-auto — window 1M, compacts at 900K
xiaomi/mimo-v2.5 — window 1.05M, compacts at 944K
xiaomi/mimo-v2.5-pro — window 1.05M, compacts at 944K
xiaomi/mimo-v2.5-pro-ultraspeed — window 1.05M, compacts at 944K
xiaomi/mimo-v2.6-flash — window 1.05M, compacts at 944K
xiaomi/mimo-v2.6-pro — window 1.05M, compacts at 944K
xiaomi/mimo-v2.6-pro-ultraspeed — window 1.05M, compacts at 944K
```

Lower tier (delegation sheet): `xiaomi/mimo-v2.6-flash`.

## Model-selector live probe (bounded, one word)

```bash
$ cd /tmp && timeout 120 mimo run -m xiaomi/mimo-v2.6-flash --agent plan "Reply with the single word OK" </dev/null >out 2>err; echo "rc=$?"
rc=0
--stdout-- (empty)
--stderr--
> plan · mimo-v2.6-flash
Error: Invalid API Key: Please provide valid API Key
```

Read: `-m xiaomi/mimo-v2.6-flash` and `--agent plan` were both accepted and
parsed (the run header shows `plan · mimo-v2.6-flash`); the run then failed on
authentication, not on the flags. **Trap:** the failed run exits **0** with the
error on stderr and EMPTY stdout — `bin/ai-mimo`'s empty-answer check is the
honesty gate for this (kept, and documented in its STEP 0).

## Auth state (why the end-to-end answer is still pending)

```text
$ mimo providers list
  Credentials ~/.local/share/mimocode/auth.json
  0 credentials
  Environment
  ● DeepSeek  DEEPSEEK_API_KEY
  1 environment variable

$ mimo providers whoami
  Current user
  ■ Not logged in. Run `mimo auth login` to log in.
```

The Desktop app's login does NOT carry over to the CLI (no auth.json existed
before this probe). Login is interactive browser OAuth + pasted code:

```text
$ mimo providers login -p xiaomi
  Add credential
  ● Browser didn't open? Use the url below to sign in:
    https://platform.xiaomimimo.com/authorize?...&kn=mimocode&key_name=mimo-code-cli-key-...
  Paste code here if prompted >
```

This one-time step belongs to the owner (Xiaomi account credentials); it cannot
be done headlessly by a session. Until it runs, an end-to-end flash answer
stays unproven, which is why #829 stays open.

**Owner rule (Albert, relayed 2026-09-25): subscription-only.** Nothing may go
through pay-per-token APIs — only his subscriptions (Xiaomi MiMo included). No
API key was created or used anywhere in this qualification. The login above is
browser account sign-in (OAuth), not an API-key paste. Abort condition: if the
login flow demands creating/paying for a platform API key instead of signing in
with the existing Xiaomi subscription account, the headless path is forbidden
by this rule — the manual Desktop path remains the MiMo dispatch route and that
becomes the recorded verdict on #829.

## Agents (verbatim names, `mimo agent list`)

```text
build (primary)
checkpoint-writer (subagent)
compaction (subagent)
compose (primary)
distill (subagent)
dream (subagent)
explore (subagent)
general (subagent)
plan (primary)
summary (subagent)
title (subagent)
```

`plan` and `build` (the wrapper's two pinned agents) both exist as primary
agents.

## Other facts

- Bare `mimo`, `mimo -h`, and `mimo --help` launch the interactive TUI and
  produce no piped output (they hang under a closed stdin; `mimo <subcommand>
  --help` is the working help form). `mimo --version` prints and exits.
- The commands reference `mimo account login` (named in the plan's Step 2 and
  `bin/setup-machine.ps1`) does not exist; the real command is
  `mimo providers login` (alias `mimo auth login`).
- Top-level commands (from `mimo providers login --help` banner): completion,
  acp, mcp, [project] (TUI, default), attach, run, debug, providers (auth),
  agent, upgrade, uninstall, serve, llm-server, models, stats, export, import,
  github, pr.
