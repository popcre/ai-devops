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

## Two-turn live qualification through the real wrapper
Session `qual1013d`, `AI_GROK_CALLER=codex`, read-only, at head `20898d21ee4e`:

| Turn | Call | Tokens | Cost |
|---|---|---|---|
| 1 | `ai-grok-review new` | 55567 (28928 cached) | $0.01211862 |
| 2 | `ai-grok-review ask` (resume) | 15979 (15232 cached) | $0.00165002 |

Both turns returned a terminal result with a verdict; the session resumed
cleanly and prompt caching worked across turns. Turn 2's cost is far below
turn 1's, which re-confirms on 1.0.13 that resumed `total_cost_usd` is per-call
and must be summed by the caller, not read as a running total.

Total live spend for the whole qualification, including the contract probe and
one deliberate max-turns cancellation: under $0.04.

## Behaviour re-checked rather than assumed
- `--worktree` still creates no worktree in headless `-p` mode. 1.0.13 now says
  so in its own help, so the wrapper's git-owned worktree stays correct.
- A cancelled session still may not resume cleanly; the wrapper's advice to
  start a fresh named session is unchanged and no longer names a stale version.

## Wrapper-behaviour evaluation on 1.0.13 (plan Phases 3 and 4)

Each 1.0.6-1.0.13 wrapper-facing addition was evaluated against live 1.0.13
behaviour. Where the existing handling is already correct, the outcome is
recorded as evaluated / no change rather than a speculative rewrite.

- **Headless permission handling — evaluated, no change.** Four live read-only
  sessions on 1.0.13 (`qual1013c`, `qual1013d`, `i251review`, `i251review2`,
  `i251review3`) ran to a terminal result under the frozen narrow prefix with no
  interactive permission prompt and no hang. Nothing in 1.0.6-1.0.13 removed a
  real non-interactive prompt that the narrow rules did not already cover, so
  the fixed prefix is unchanged. `--always-approve`, `--permission-mode auto`
  and `bypassPermissions` remain forbidden in every form.
- **Terminal-result and stop-reason handling — evaluated, comment corrected.**
  1.0.13 still emits `end_turn` on success and `cancelled` on cancellation; it
  introduced no new terminal spelling. The unrecognised-reason branch therefore
  stays a refusal, not a guess. One deliberate max-turns cancellation during
  qualification exercised that path.
- **Usage and cost handling — re-confirmed, no change.** Resumed
  `total_cost_usd` is per-call on 1.0.13, not a running total (turn 2 of
  `qual1013d` cost far less than turn 1). Model identity still comes from the
  `modelUsage` key, not a top-level `model` field.
- **Session discovery and transcript — evaluated, no change.** `list`, `show`,
  `transcript` and resume all work on 1.0.13 against the exact named session.
  Sessions remain scoped by repository and caller; the wrapper still requires an
  explicit session name and never falls back to "most recent". 1.0.11's
  browsable headless sessions change nothing the wrapper relies on.
- **Implementation wrapper — audited, no behavioural change.** Its full suite
  passes on 1.0.13 (40 checks). Wrapper-owned Git worktree creation, patch
  export, primary-checkout immutability, failure preservation and cleanup are
  retained; 1.0.13's own documentation now confirms headless `-p` creates no
  worktree, which is why the wrapper keeps creating its own.
