# Antigravity CLI investigation for an `ai-gemini` reviewer

Date: 2026-08-18

Machine: `edge-dev`, Windows 11

Antigravity CLI: 1.1.14

Tracking: [u2giants/ai-devops#38](https://github.com/u2giants/ai-devops/issues/38)
Implementation plan: [`../plan_ai-gemini-wrapper.md`](../plan_ai-gemini-wrapper.md)

## Purpose

Determine whether Google’s subscription-authenticated Antigravity CLI can safely support a repo-owned Gemini 3.7 Flash reviewer. This record contains only redacted behavior and reproducible commands. It contains no account email, OAuth material, or secret value.

## Verified capabilities

- Installed executable: `%LOCALAPPDATA%\agy\bin\agy.exe`. The installer added `%LOCALAPPDATA%\agy\bin` to user PATH, but an already-running Codex process did not inherit it.
- `agy models` listed `gemini-3.7-flash-high`, `gemini-3.7-flash-medium`, and `gemini-3.7-flash-low`.
- Exact High marker request returned JSON `status:"SUCCESS"`, one conversation ID, `num_turns:1`, and `GEMINI_37_FLASH_TEST_OK`.
- Exact-ID resumption recalled the marker and reported `num_turns:2`.
- `agy --conversation <id> --output-format json --print '/model'` returned structured model data: ID `gemini-3.7-flash-high`, label `Gemini 3.7 Flash (High)`, effort `high`, `is_default:false`, with zero tokens.
- `agy --output-format json --print '/usage'` returned separate Gemini weekly and five-hour allowance fractions/reset times with zero tokens. Both were approximately 98% remaining after this spike.
- The first trivial marker reported 15,438 total tokens. The resumed conversation reported 32,018 total tokens. These are provider-returned figures, not price estimates.

## Safety failures and traps

- `--mode plan` is not a write prohibition. Google documents it as a `/plan` prompt prefix that steers the agent toward read-only investigation.
- Google documents that active workspaces auto-allow reads and writes unless fine-grained deny rules override the default.
- Google documents terminal sandboxing as preview on macOS/Linux and not yet available on Windows.
- A headless request that needed an unapproved terminal `command` was auto-denied and left the workspace unchanged, but Antigravity still returned process success plus JSON `status:"SUCCESS"` with an empty response. Success status alone cannot be accepted as completion.
- A native `write_to_file` request created `MUST_NOT_EXIST.txt` under Antigravity’s private scratch area, not the requested temporary workspace. The content was verified as `WRITE_PROBE` and the exact test file was deleted. This proves a write-capable tool remains reachable without a reviewer-specific deny policy.
- Combining `--mode plan` with `--disable-slash-commands` emitted a warning that plan mode had no effect. Do not combine them without current requalification.
- Normal response JSON did not name the model. Structured `/model` did.

## Reproduction commands

Use an isolated harmless directory, exact current executable, and a non-secret marker. Do not run hostile writes in a real repository.

```powershell
$agy = "$env:LOCALAPPDATA\agy\bin\agy.exe"
& $agy --version
& $agy models
& $agy --model gemini-3.7-flash-high --mode plan --output-format json --print-timeout 2m --print 'Reply with exactly GEMINI_37_FLASH_TEST_OK and nothing else.'
& $agy --conversation <conversation-id> --model gemini-3.7-flash-high --mode plan --output-format json --print-timeout 2m --print 'What exact test marker did I ask you to return? Reply with only that marker.'
& $agy --conversation <conversation-id> --output-format json --print-timeout 1m --print '/model'
& $agy --output-format json --print-timeout 1m --print '/usage'
```

Replace `<conversation-id>` with the ID from the marker response. Do not put the placeholder text into a command literally.

## Official documentation used

- Google Antigravity CLI permissions: <https://antigravity.google/docs/cli/permissions/>
- Google Antigravity execution modes: <https://antigravity.google/docs/cli/modes/>
- Google Antigravity sandbox: <https://antigravity.google/docs/cli/sandbox/>
- Google Antigravity headless mode: <https://antigravity.google/docs/cli/headless/>
- Google migration announcement for personal Gemini CLI accounts: <https://github.com/google-gemini/gemini-cli/discussions/28017>

## Conclusion

Antigravity has the model, subscription allowance, structured output, usage, and conversation mechanics required for a reviewer. It is not safe to wrap yet. Implementation is gated on proving an isolated fine-grained permission profile that denies every write and external action without changing Albert’s normal Antigravity settings. The complete build and stop criteria are in [`../plan_ai-gemini-wrapper.md`](../plan_ai-gemini-wrapper.md).
