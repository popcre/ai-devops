# SLM history-compaction pilot — paired week (issue 1751)

Started **2026-10-14 1:57 PM EST**. Corrected the same day: pilot host is
**edge-dev3** (Claude lives there; edge-dev's live client is MiMoCode).
Handoff: `HANDOFF.d/2026-10-14T1710Z-edge-dev-mimo-slm-compaction-pilot.md`
(branch `docs/slm-compaction-handoff`). Decision record:
[`docs/compression-and-process-fixes.md`](../../../docs/compression-and-process-fixes.md).

## Scope limit (read this first)

**DietCode's history-compaction proxy is Claude Code only.** It speaks the
Anthropic Messages API. It does **not** optimize MiMoCode, ChatGPT Desktop, or
Cursor history. This pilot can only prove or disprove savings for **Claude
sessions**. Any MiMoCode or ChatGPT spend claim would be a different workstream.

**What "hooks" means.** DietCode can install small plugins into Claude Code
CLI and Codex *CLI* (terminal tools): they label your prompt's intent and
squeeze large tool output. Hooks **add** tokens; they do **not** shrink
history. The real history savings is only the **proxy** (below), and that
proxy is Claude-only.

| Client | Albert's actual use | DietCode history proxy? | DietCode hooks? |
|---|---|---|---|
| Claude Desktop (GUI) → spawns Claude Code | edge-dev3, primary | **yes**, if the spawned binary is wrapped | n/a (Desktop owns the process) |
| Claude Code CLI | not used day-to-day | yes (`dietcode claude`) | yes |
| MiMoCode / MiMo Desktop | edge-dev | **no** | no |
| ChatGPT Desktop for Windows | Windows host | **no** — no DietCode path | no (Codex *CLI* only) |
| Codex CLI / Cursor | not Albert's daily drivers | no history proxy | Codex CLI hooks only; Cursor rules only |

## Owner decisions (this session)

| Question | Decision | Record |
|---|---|---|
| Pilot machine | **edge-dev3** (corrected) | Albert named Claude as edge-dev3-only; original edge-dev pick was wrong for this tool |
| Quality stop | **Stop after 2 lost-detail failures** in the same week (one incident is recorded, not fatal) | Albert 2026-10-14 (noted: handoff default was "stop same day") |

Already settled (do not re-ask): ScaleDown may process code and conversations;
API key is in 1Password (`vibe_coding` → `scaledown.ai API key for testing`);
process fixes A–F are live.

## What this pilot measures

Whether a cheap SLM (ScaleDown via DietCode proxy) can own **history
compaction** for long Claude sessions — cutting paid input tokens without
destroying prompt-cache hit rate.

Paired table fields (required before adopt / iterate / drop):

- tokens per turn (billed input, output)
- cache hit rate (`cache_read / (cache_read + cache_write)`)
- compact events (native vs DietCode)
- quality notes (lost details on coding tasks)

## Baseline (days 1–3 gate) — Claude sessions on edge-dev3

Source: `~/.claude/projects/**/*.jsonl` on **edge-dev3**, extracted by
[`extract_claude_usage.py`](extract_claude_usage.py) on 2026-10-14.
No DietCode. Native Claude auto-compaction.

**Gate met:** 21 sessions with turns ≥ 10 (need ≥ 10).

| Metric | Value |
|---|---|
| Sessions (turns ≥ 10) | 21 |
| Turns | 4,740 |
| Billed input | 2,058,171,005 |
| Output | 3,121,418 |
| cache_write | 95,748,073 |
| cache_read | 1,962,405,660 |
| **Cache hit** | **95.35%** |
| Compact events (markers) | 0 |

### Largest sessions (edge-dev3 baseline sample)

| Session (prefix) | Turns | Asst | Billed in | Out | cache_w | cache_r | Hit % | Compact | Last day |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 42ccdc95-141 | 600 | 932 | 309,069,186 | 412,959 | 2,001,393 | 307,065,459 | 99.35 | 0 | 2026-10-13 |
| 7623097e-a8d | 383 | 542 | 131,615,610 | 238,074 | 5,091,551 | 126,522,433 | 96.13 | 0 | 2026-10-14 |
| f5bb43ea-3c9 | 291 | 497 | 104,584,625 | 206,975 | 3,775,513 | 100,808,050 | 96.39 | 0 | 2026-10-14 |
| a7c97172-ca8 | 234 | 375 | 66,925,093 | 137,298 | 3,557,033 | 63,367,280 | 94.68 | 0 | 2026-10-14 |
| e9693af2-42d | 137 | 254 | 47,538,816 | 206,642 | 1,093,103 | 46,445,197 | 97.70 | 0 | 2026-10-14 |

Notes:
- Compact-marker count is 0 on this extract — either these sessions stayed
  under the native auto-compact threshold, or the marker shape differs. Recheck
  during the pilot week when DietCode owns compaction.
- An earlier extract from **edge-dev** `~/.claude` (19 sessions, 95.29% hit,
  108 compact markers) is **retired as the pilot baseline** — that host's live
  client is MiMoCode, not Claude.

## Pilot setup (days 4–10) — DietCode on edge-dev3 only

| Item | Value |
|---|---|
| Host | **edge-dev3** |
| Package | `dietcode@0.5.0` (`npm install -g --prefix ~/.local`) |
| Claude Desktop path | **wrapped**: `~/.config/Claude/claude-code/2.1.295/71164c85f9d2/claude` is a fail-open script; real ELF kept as `claude-real` |
| Why wrap | Claude Desktop launches that absolute path as a child; a PATH alias alone never saw Albert's real sessions |
| Proxy | persistent `dietcode proxy --port 8788` on 127.0.0.1, started by the wrapper |
| Config | `~/.scaledown/config.json` (key from 1Password `vibe_coding` → `scaledown.ai API key for testing` → field `credential`) |
| Upstream | `https://api.anthropic.com` (default `SCALEDOWN_PROXY_UPSTREAM`) |
| Native compact | pushed aside (`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=95` in wrapper) |
| Full `dietcode setup` hooks/MCP | **Not installed** (hooks only add tokens) |
| edge-dev | DietCode **uninstalled** (wrong host) |
| Claude Desktop already-running sessions | keep old env until that session ends; **new** Desktop agent sessions hit the proxy |
| Remote Claude (`claude-ssh-remote` / vps2) | **out of scope** — runs on the VPS, not behind this proxy |
| Fleet | 4837 and any other host must not get DietCode until step 5 says adopt |

How a pilot session is produced on edge-dev3:

- **Normal path (what Albert does):** open Claude Desktop and work. New agent
  sessions spawn `claude`, which the wrapper sends through DietCode.
- **CLI path:** `dietcode claude` or the wrapped `claude` binary.
- **Control arm:** temporarily point at `claude-real` (bypass wrapper) for a
  same-work comparison without compaction.

## How to re-measure

```text
python3 extract_claude_usage.py 25 out.jsonl
```

Same metrics as the baseline. Compare **substantial sessions only**
(turns ≥ 10), same work mix if possible. Report cache hit and billed input
per turn.

## Quality log

Stop the pilot (this week) after **two** coding-task failures caused by a
detail lost in compaction. One incident is recorded and the pilot continues.

| Date EST | Session | What was lost | Recovered? | Count |
|---|---|---|---|---:|
| — | — | — | — | 0 |

## Incident — DietCode proxy broke Claude Desktop (2026-10-14)

**Symptom (Albert):** cannot start new Claude sessions.
`BrotliDecompressionError fetching "http://127.0.0.1:8788/v1/messages?beta=true"`.

**Cause:** the Claude Desktop spawn path was wrapped to force
`ANTHROPIC_BASE_URL=http://127.0.0.1:8788` through DietCode's proxy. The proxy
mishandled `Content-Encoding: br` on the Messages API response, so the Claude
client could not decode it.

**Repair (done):** real ELF restored as `claude` on edge-dev3; DietCode proxy
stopped; no `ANTHROPIC_BASE_URL` left in shell/env files. Claude is stock again.

**Pilot consequence:** history-compaction proxy path is **not** running. Do not
re-wrap Claude Desktop until DietCode's response-decoding bug is fixed or a
different intercept is proven on a throwaway session first. Paired-week numbers
are blocked.

## Known risks (from handoff §9)

- Cache-hit impact of DietCode on our traffic is unmeasured until this week.
- Quality risk: rare critical detail (path, SHA, review evidence) dropped.
  Mitigation: `sd_retrieve` / local stash; test on a real coding task.
- ScaleDown summarize cap is 1000 tokens; watch summary decay on very long sessions.
- **MiMoCode and Codex get no history-compaction from this pilot** — say so in
  the verdict; do not generalize Claude numbers to every client.
- Free tier ~50M ScaleDown tokens; watch usage so the pilot does not surprise-bill.

## Status

- [x] Owner machine + stop rule
- [x] Task class declared (`code`)
- [x] Baseline ≥ 10 sessions with numbers (edge-dev3: 21 sessions, 95.35% hit)
- [x] DietCode installed on edge-dev3 only (proxy path); removed from edge-dev
- [x] Claude Desktop spawn path wrapped (proxy on 127.0.0.1:8788, fail-open)
- [x] ChatGPT Desktop / MiMoCode documented as out of scope for this proxy
- [x] **Rolled back** Claude Desktop wrap after BrotliDecompressionError (see Incident)
- [ ] DietCode proxy defect fixed or alternate intercept proven on a throwaway session
- [ ] Pilot week sessions collected (blocked on working history-compaction path)
- [ ] Paired table filled
- [ ] Decision (adopt / iterate / drop) on issue 1751 + doc update
