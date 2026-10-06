# Phase E metrics collection checklist — reviewer-pipeline-core

**Purpose:** capture the Phase E2 before/after metrics with commands + artifact
paths (never bare numbers), so the later helper-retire PR has a proof trail.

**Window baseline (before):** 2026-09-30T02:56:50Z (PR #1135 merge `a5bc30be`).
**Before snapshot taken:** 2026-10-05T21:35:12Z —
  `~/.local/state/ai-devops/review-lifecycle/phase-e-window-20261005T2135Z.txt`
**After snapshot:** take the same commands immediately before the helper-retire
PR merges, and again on installed-tree live proof. Save each as
`~/.local/state/ai-devops/review-lifecycle/phase-e-metrics-<UTCstamp>.txt`.

---

## 1. `*_captured: 0` count

The incident signature from §3 of the plan: a review ends with empty evidence
capture (`recent_provider_logs_captured: 0`).

```bash
# Count reviewer-issue notes with *_captured: 0 since baseline
grep -rl '_captured: 0' ~/.local/state/ai-devops/ --include='*.md' --include='*.txt' 2>/dev/null
# GitHub-side: reviewer issues opened since 2026-09-30 whose body has captured: 0
bin/ai-gh issue list --search 'repo:popcre/ai-devops captured: 0 created:>=2026-09-30' --json number,title,body
```

Artifact: paste the file list + issue numbers into the metrics note.
Before (2026-10-05): 4 of 4 readable issues had `*_captured: 0`
  (gemini report-not-durably-published; codex credit; qwen code-config; muse code-config).

## 2. Quarantine events

```bash
# Preflight quarantine / qualification-revocation events since baseline
find ~/.local/state/ai-devops -name '*.json' -newermt '2026-09-30' -print0 \
  | xargs -0 grep -l 'quarantine' | wc -l
# Qualification-store version history (Phase B: last good retained)
ls ~/.local/state/ai-devops/review-preflight/*.json 2>/dev/null
bin/ai-review-preflight usable gemini; bin/ai-review-preflight usable qwen
```

Artifact: list of event files + usable/not-usable output per provider.

## 3. Outage-vs-code issue split

Phase C routes 403/404/429/92 to `failure_class=outage|credit|capacity`, never `code`.

```bash
# Lifecycle failure_class distribution since baseline
find ~/.local/state/ai-devops/review-lifecycle/runs -name '*.json' -newermt '2026-09-30' \
  -print0 | xargs -0 jq -r '.failure_class // "none"' | sort | uniq -c
# Scoreboard failure_class
jq -r 'select(.timestamp >= "2026-09-30") | .failure_class // "none"' \
  ~/.local/state/ai-devops/review-scoreboard/reviews.jsonl | sort | uniq -c
# GitHub issues labeled by class (bin/ai-reviewer-issue summaries)
bin/ai-gh issue list --search 'repo:popcre/ai-devops label:outage created:>=2026-09-30' --json number,title
bin/ai-gh issue list --search 'repo:popcre/ai-devops label:code created:>=2026-09-30' --json number,title
```

Artifact: the two count tables + issue numbers.

## 4. Packet-store disk use

```bash
# Durable packet stores (hidden dot-dirs — use find, not bare ls)
find /c/repos -maxdepth 5 -type d -name '.ai-review-*' -path '*/.ai/reviews/packets/*' 2>/dev/null \
  | wc -l
du -sh $(find /c/repos -maxdepth 4 -type d -path '*/.ai/reviews/packets' 2>/dev/null) 2>/dev/null
# Working sandboxes (should be empty after store-before-delete)
ls -d ~/.local/state/ai-devops/review-sandboxes/rlc-* 2>/dev/null | wc -l
```

Before (2026-10-05): 9 of 23 packet runs have a surviving durable copy;
  0 rlc-* sandboxes remain; durable stores live under per-repo
  `.ai/reviews/packets/.ai-review-rlc-*` and die with their worktree.

## 5. Packet coverage (Criterion B progress)

```bash
find ~/.local/state/ai-devops/review-lifecycle/runs -name '*.json' -newermt '2026-09-30' \
  -print0 | xargs -0 grep -lE '"packet_sha256": "[a-f0-9]' | wc -l
```

Before (2026-10-05T21:35Z): 23/50 (grok 21, deepseek 2).
**Blocker:** only grok+deepseek are registered runner doors
(`config/review-runner-doors.json`); muse/qwen/gemini/stepfun finish through the
legacy pool path (`bin/ai-review-pool:423`) that omits `--packet-sha256`.

---

## Duplicated helpers Phase E would retire (list only — do NOT delete yet)

| Helper / duplicated concern | Canonical owner after Phase E | Still has callers (as of 2026-10-05) |
|---|---|---|
| Legacy pool dispatch + finish without packet args (`bin/ai-review-pool:145-430`, especially `:423`) | `ai-review-engine` + `tools/lib/review-lifecycle-core.sh` | Every non-door provider via `ai-review <provider> <mode>`: muse, qwen, gemini, stepfun; grok/deepseek only when not door-routed |
| `identity_json()` in `bin/ai-review-lifecycle:62` | `rlc_identity()` `tools/lib/review-lifecycle-core.sh:229` | `ai-review-lifecycle begin` — called by `ai-claude-review`, `ai-codex-review`, `ai-glm`, `ai-grok-review`, `ai-kimi`, `ai-review-pool` (legacy), `ai-task-gates` |
| Scoreboard `lock_acquire()` `bin/ai-review-scoreboard:21` vs lifecycle lock `bin/ai-review-lifecycle:154` | one lock home in the core | `ai-review-scoreboard` called by `ai-reviewer-issue`, `ai-review-lifecycle` |
| Per-wrapper session-meta packet bookkeeping (`ai-muse:931,990`, `ai-gemini:362,377`, `ai-qwen:1616`, `ai-deepseek-agent:640,926,1136`) | lifecycle state `packet_dir`/`packet_sha256` via core finish | Session CLIs remain (named sessions), but their duplicate packet fields are superseded for formal reviews |
| Wrapper-local sandbox/packet cleanup traps outside the core | `rlc_cleanup_after_store` `tools/lib/review-lifecycle-core.sh:300` | `ai-claude-review`, `ai-codex-review` (Phase A made them store-before-delete; the trap copies remain) |

**Retirement gate (unchanged):** clean window MET first (14 days from
2026-09-30T02:56:50Z, or 50 packet reviews with zero missing-packet incidents),
then this metrics snapshot, then a separate reviewer-safety PR with one
read-only exact-head final review.
