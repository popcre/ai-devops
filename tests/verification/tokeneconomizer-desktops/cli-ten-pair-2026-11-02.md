# November 2 matched ten-pair native CLI cost study

Owner: Claude Code session on edge-dev3, for
[#2220](https://github.com/popcre/ai-devops/issues/2220). Recorded November 2,
2026, 9:30 PM EST. Owner approval: November 2, about 8:55 PM EST.
Related: [schedule](measurement.md), [prior smoke](native-smoke-2026-11-01.md),
[qualification](report.md).

## Verdict

CLI only. Desktop acceptance remains blocked; nothing here covers a desktop app.

- Loopguard (nudge only): **reject**. Eight nudges fired, no check was
  missed, but treatment pairs cost 7.3% more than baseline before warm-up,
  and 32.4% more with its warm-up and own preflight included.
- Environment facts (envfacts only): **reject**. No check was missed and the
  pair arms cost 12.7% less, but with the four learning sessions and preflight
  the total is 31.9% higher. The 10% acceptance bar counts setup, so it fails.
  Break-even would need roughly 35 more sessions; not tested and not claimed.

## Frozen controls

Upstream pin c53a4a6dcdebaeb9df6fcaa5c7026f0401cd8f23 (0.1.0), loaded per
session with the supported plugin-directory flag only; no global install.
Claude Code 2.1.309, claude-opus-5-5, effort medium; helper calls used the
pin's default haiku alias. Fresh synthetic repository commit
310bd8075f51306527bbe718c39e1159d455f75e. Each run got a fresh clone; each
mechanism its own optimizer state; baselines loaded the same plugin directory
with the optimizer's supported disable switch, so the two arms saw identical
inventories.

Confound fix: every run used supported setting sources limited to project and
local, an empty strict MCP config and a task-owned settings file (auto-memory
off). The user's real settings, hooks and skills were not edited. The native
init inventory (27 tools, 20 skills, 62 commands, 4 plugins, 0 MCP servers,
model claude-opus-5-5) was byte-identical across the baseline, loop and facts
preflights. The study removes ordinary MCP servers from both arms equally; it
therefore says nothing about MCP-heavy sessions.

Toolprune, proposer, repomap and forced aborts were off. Order alternated:
loop odd pairs baseline-first, facts odd pairs treatment-first. Driver,
wrapper, settings and task-packet hashes were frozen before warm-up.
Pre-registered quality stop: two pairs in which treatment missed a required
check while baseline passed. It never triggered.

Counters come from each native run's final usage result. Optimizer side
calls (judge, writer, fold) were captured by a pass-through wrapper that saved
their native JSON usage. This replaces the prior loopback telemetry collector;
both read the same native counters. All runs reported a cost; none is unknown.
USD values are native list-price equivalents, not cash charges.

## Tasks and required checks

Loop: run a deliberately failing synthetic probe twenty times, then fix
work.py and run the unit test. Facts: fix work.py, run the app (needs a
setting) and run the unit test. Required: only work.py changed, independent
unit test passes, agent ran a passing test, and for facts the app printed
its expected line. All 40 pair arms and all 9 learning runs passed.

## Costs

| Item | Runs | Total USD | Average per run |
|---|---|---|---|
| Preflight, inventory proof | 3 | 0.2083 | 0.0694 |
| Loop warm-up (5 clean, thresholds) | 5 | 0.2809 | 0.0562 |
| Facts learning (fact went ACTIVE, fire 4/4) | 4 | 0.2875 | 0.0719 |
| Loop baseline | 10 | 1.2550 | 0.1255 |
| Loop treatment incl. helpers 0.0503 | 10 | 1.3467 | 0.1347 |
| Facts baseline | 10 | 0.7185 | 0.0719 |
| Facts treatment (no helpers) | 10 | 0.6271 | 0.0627 |
| **Study total** | 52 | **4.7241** | |

Pair token sums, input / output / cache-read / cache-creation:

- Loop baseline 118 / 22326 / 1081490 / 73959.
- Loop treatment 138 / 22671 / 1264036 / 73703.
- Facts baseline 82 / 9098 / 702976 / 49458.
- Facts treatment 62 / 7029 / 518193 / 47835.

The prompt asked for twenty probe calls, so the nudge could not shorten that
work; it added judge calls and extra context. Facts treatment avoided one
setup round trip in nine of ten pairs (one treatment still hit the setup
failure once). No reruns were used. Coordinator orchestration usage is
unavailable, not zero.

## Still open

Desktop installations, managed rollout and per-desktop ten-pair acceptance
remain blocked on #2220 as before. No transcripts, prompts, account data or
secrets are published here.
