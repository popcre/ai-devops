# SLM history-compaction pilot — paired week (issue 1751)

Started **2026-10-14 1:57 PM EST** on **edge-dev**.
Handoff: `HANDOFF.d/2026-10-14T1710Z-edge-dev-mimo-slm-compaction-pilot.md`
(branch `docs/slm-compaction-handoff`). Decision record:
[`docs/compression-and-process-fixes.md`](../../../docs/compression-and-process-fixes.md).

## Owner decisions (this session)

| Question | Decision | Record |
|---|---|---|
| Pilot machine | **edge-dev** | Albert 2026-10-14 |
| Quality stop | **Stop after 2 lost-detail failures** in the same week (one incident is recorded, not fatal) | Albert 2026-10-14 (noted: handoff default was "stop same day") |

Already settled (do not re-ask): ScaleDown may process code and conversations;
API key is in 1Password; process fixes A–F are live.

## What this pilot measures

Whether a cheap SLM (ScaleDown via DietCode proxy) can own **history
compaction** for long Claude sessions — cutting paid input tokens without
destroying prompt-cache hit rate.

Paired table fields (required before adopt / iterate / drop):

- tokens per turn (billed input, output)
- cache hit rate (`cache_read / (cache_read + cache_write)`)
- compact events (native vs DietCode)
- quality notes (lost details on coding tasks)

## Baseline (days 1–3 gate) — historical Claude sessions

Source: `~/.claude/projects/**/*.jsonl`, extracted by
[`extract_claude_usage.py`](extract_claude_usage.py) on 2026-10-14.
No DietCode. Native Claude auto-compaction. edge-dev was Headroom-wired for
some of these sessions.

**Gate met:** 19 sessions with turns ≥ 10 (need ≥ 10).

| Metric | Value |
|---|---|
| Sessions (turns ≥ 10) | 19 |
| Billed input | 680,339,354 |
| Output | 1,959,220 |
| cache_write | 32,038,369 |
| cache_read | 648,203,628 |
| **Cache hit** | **95.29%** |
| Compact events (markers) | 108 |

### Largest sessions (baseline sample)

| Session (prefix) | Turns | Asst | Billed in | Out | cache_w | cache_r | Hit % | Compact | Last day |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 8c95a983-803 | 267 | 465 | 97,801,683 | 293,510 | 4,352,906 | 93,364,068 | 95.55 | 0 | 2026-09-25 |
| agent-a2bfc5 | 400 | 608 | 91,249,082 | 157,425 | 5,782,555 | 85,465,311 | 93.66 | 24 | 2026-09-23 |
| f3421dc4-2a6 | 460 | 698 | 88,698,579 | 303,027 | 5,271,307 | 83,425,586 | 94.06 | 2 | 2026-09-25 |
| 4d0f5e48-632 | 383 | 620 | 79,034,236 | 293,896 | 1,187,388 | 77,845,606 | 98.50 | 10 | 2026-09-24 |
| 24095101-000 | 306 | 496 | 60,194,922 | 214,661 | 1,582,178 | 58,611,750 | 97.37 | 8 | 2026-09-25 |

Full extract (JSONL): session temp `slm-baseline/baseline-sessions.jsonl`
(not committed — rebuild with the extractor).

## Pilot setup (days 4–10) — DietCode on edge-dev only

| Item | Value |
|---|---|
| Package | `dietcode@0.5.0` (npm global on edge-dev) |
| Path | `dietcode claude` → local proxy + real `claude` |
| Config | `~/.scaledown/config.json` (key from 1Password `vibe_coding` → `scaledown.ai API key for testing` → field `credential`) |
| Upstream | `https://api.anthropic.com` (default `SCALEDOWN_PROXY_UPSTREAM`) — **bypasses Headroom** so DietCode effect is isolated |
| Native compact | pushed aside (`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` default 95 in wrapper) |
| Full `dietcode setup` hooks/MCP | **Not installed** for this pilot (hooks only add tokens; proxy is the history-compaction path) |
| Fleet | edge-dev3 / 4837 **must not** get DietCode until step 5 says adopt |

How to run a pilot session:

```text
dietcode claude
```

(or `dietcode claude -p "..."` for a one-shot). Plain `claude` / `command claude`
stays the control arm when needed.

## How to re-measure

```text
python extract_claude_usage.py 25 out.jsonl
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
- Codex path is hooks-only — do not claim Codex savings from this pilot.
- Free tier ~50M ScaleDown tokens; watch usage so the pilot does not surprise-bill.

## Status

- [x] Owner machine + stop rule
- [x] Task class declared (`code`)
- [x] Baseline ≥ 10 sessions with numbers
- [x] DietCode installed on edge-dev only (proxy path)
- [ ] Pilot week sessions collected (waiting on real Claude work through `dietcode claude`)
- [ ] Paired table filled
- [ ] Decision (adopt / iterate / drop) on issue 1751 + doc update
