# SLM history-compaction pilot — paired week (issue 1751)

Started **2026-10-14 1:57 PM EST**. Corrected the same day: pilot host is
**edge-dev3** (Claude lives there; edge-dev's live client is MiMoCode).
Handoff: `HANDOFF.d/2026-10-14T1710Z-edge-dev-mimo-slm-compaction-pilot.md`
(branch `docs/slm-compaction-handoff`). Decision record:
[`docs/compression-and-process-fixes.md`](../../../docs/compression-and-process-fixes.md).

## Scope limit (read this first)

**DietCode's history-compaction proxy is Claude Code only.** It speaks the
Anthropic Messages API (`dietcode claude`). It does **not** optimize MiMoCode,
Codex, or Cursor history. This pilot can only prove or disprove savings for
**Claude sessions**. Any MiMoCode spend claim would be a different workstream.

| Client on edge-dev | Used here? | DietCode proxy? |
|---|---|---|
| Claude Code | yes (edge-dev3) | **yes** (`dietcode claude`) |
| MiMoCode | yes (edge-dev is MiMo-first) | **no** |
| Codex / Cursor | present | hooks only, not history compaction |

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
| Path | `~/.local/bin/dietcode claude` → local proxy + real `claude` |
| `claude` on PATH | symlink `~/.local/bin/claude` → `~/.config/Claude/claude-code/2.1.295/.../claude` (v2.1.295) |
| Config | `~/.scaledown/config.json` (key from 1Password `vibe_coding` → `scaledown.ai API key for testing` → field `credential`) |
| Upstream | `https://api.anthropic.com` (default `SCALEDOWN_PROXY_UPSTREAM`) |
| Native compact | pushed aside by the wrapper (`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`) |
| Full `dietcode setup` hooks/MCP | **Not installed** for this pilot (hooks only add tokens; proxy is the history-compaction path) |
| edge-dev | DietCode **uninstalled** (was the wrong host) |
| Fleet | 4837 and any other host must not get DietCode until step 5 says adopt |

How to run a pilot session on edge-dev3:

```text
export PATH="$HOME/.local/bin:$PATH"
dietcode claude
```

(or `dietcode claude -p "..."` for a one-shot). Plain `claude` stays the
control arm when needed.

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
- [ ] Pilot week sessions collected (waiting on real Claude work through `dietcode claude`)
- [ ] Paired table filled
- [ ] Decision (adopt / iterate / drop) on issue 1751 + doc update
