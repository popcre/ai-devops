# Grok Build 1.0.13 qualification AFTER the upgrade

Captured: 2026-09-04T02:10Z on EDGE-DEV (Windows), by the repository-owned
installer `bin/install-windows-ai-provider-clis.ps1`. Pairs with
[the 1.0.5 baseline](baseline-1.0.5-before.md).

## Installer run (unabridged)
```
Grok Build CLI reports '1.0.5'; this repository qualifies exactly 1.0.13.
Backed up C:\Users\ahazan\.grok\bin\grok.exe -> C:\Users\ahazan\.local\state\ai-devops\provider-cli\backups\grok.20260904T020304Z.bak
Installing Grok 1.0.13 (current: 1.0.5)...
  ✓ grok v1.0.13 installed successfully!
Grok Build CLI is now exactly 1.0.13 (previous binary kept at C:\Users\ahazan\.local\state\ai-devops\provider-cli\backups\grok.20260904T020304Z.bak).
```

## Version, policy and both wrapper doctors
```
grok 1.0.13 (5e9a58528b76) [stable]
bin/ai-provider-version check grok  -> 1.0.13, exit 0
install-windows-ai-provider-clis.ps1 -TestOnly -> Grok Build CLI  OK  (1.0.13), exit 0
ai-grok-review  doctor -> version policy: OK (exactly 1.0.13, the qualified build)
ai-grok-implement doctor -> version policy: OK (exactly 1.0.13, the qualified build)
```

Kimi and Qwen were reported `OK` before and after; qualifying Grok upgraded
nothing else.

## Rollback rehearsal
The kept backup was copied aside and executed without touching the live binary:
```
grok 1.0.5 (5115b46bc9) [stable]   (exit 0)
```
The upgrade is therefore reversible from the artifact the installer keeps, and
that artifact is the executable only — no credentials, sessions or logs.

## Flag surface
Every flag both wrappers pass to Grok is still accepted by 1.0.13, including the
undocumented-but-supported `--no-memory`, plus `--no-subagents`,
`--disable-web-search`, `--disallowed-tools`, `--permission-mode`, `--allow`,
`--deny`, `--output-format`, `--max-turns`, `--prompt-file`, `-p`, `-r`, `--cwd`.

## Terminal JSON contract (live, headless, read-only, 1 turn)
Every key the wrappers parse is present and unchanged in shape:
```json
{
  "text": "OK",
  "stopReason": "end_turn",
  "sessionId": "…",
  "usage": { "input_tokens": 20236, "output_tokens": 37, "total_tokens": 20273 },
  "num_turns": 1,
  "total_cost_usd": 0.00691798,
  "modelUsage": { "grok-4.6-build": { "modelCalls": 1, "costUSD": 0.00691798 } }
}
```
`stopReason`, `total_cost_usd` and the `modelUsage` model-identity key are the
three the wrappers depend on for cancellation, cost ceilings and model truth.
Measured cost of this probe: $0.0069.
