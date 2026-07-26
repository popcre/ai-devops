---
name: db-schema-reference
description: "Complete table inventory — what exists, who writes it, who reads it, and status. Check here before dropping anything. RULE: zero code references ≠ dead — it may be unwired infrastructure."
metadata: 
  node_type: memory
  type: reference
  originSessionId: d55a3937-ec07-4fe0-b642-b69b7dcd321c
---

Last audited: 2026-05-31. 53 tables.

## RULE before touching anything
"Unused" has three distinct meanings — confirm which before acting:
1. **Unwired infrastructure** — designed, partially built, never activated. Keep.
2. **Feature gap** — should be wired up; something is broken or missing without it.
3. **Superseded** — replaced by newer code that does the same thing. Safe to drop with confirmation.

---

## Infrastructure / telemetry (written by Go agent)

| Table | Agent writes | Web reads | Notes |
|---|---|---|---|
| `nas_units` | ✅ heartbeat | ✅ | NAS registry |
| `metrics` | ✅ all collectors | ✅ | Partitioned time-series |
| `nas_logs` | ✅ logwatcher | ✅ | Partitioned |
| `storage_snapshots` | ✅ storage | ✅ | Partitioned |
| `container_status` | ✅ docker | ✅ | Partitioned; CPU/mem always 0 here — use `container_io` |
| `container_io` | ✅ | ✅ | Correct source for container CPU/mem |
| `security_events` | ✅ | ✅ | |
| `alerts` | ✅ | ✅ | |
| `disk_io_stats` | ✅ diskstats (15s) | ✅ | IOPS/latency/util/queue per device |
| `process_snapshots` | ✅ | ✅ | |
| `net_connections` | ✅ | ✅ | |
| `scheduled_tasks` | ✅ | ✅ | DSM error 103 on edgesynology1 |
| `backup_tasks` | ✅ | ✅ | |
| `snapshot_replicas` | ✅ | ✅ | |
| `service_health` | ✅ | ✅ | |
| `package_status` | ✅ | ✅ | |
| `dsm_errors` | ✅ | ✅ | |
| `drive_activities` | ✅ | ✅ | Partitioned |
| `sync_task_snapshots` | ✅ | ✅ | |
| `ingestion_health` | via function | ✅ | |
| `ingestion_events` | via function | ✅ | |
| `custom_metric_schedules` | reads/claims | ✅ | Agent polls and runs commands |
| `custom_metric_data` | ✅ | ✅ | Raw output of custom commands |

### Write-only (agent writes, web never reads)
| Table | Status | Notes |
|---|---|---|
| `drive_team_folders` | **Feature gap** — data is there, no reader wired yet | Time-series snapshots of team folder usage/quota per poll cycle. Should eventually be displayed or used in issue context. |
| `drive_team_folders_partitioned` | **Unwired infrastructure** — keep | Partition parent table for `drive_team_folders` at scale. No child partitions created yet; agent writes to base table. Activate when volume demands pg_partman rotation. Do NOT drop. |

---

## Issue-agent pipeline (web app)

| Table | Written by | Read by | Notes |
|---|---|---|---|
| `issues` | issue-store, detector | ✅ everywhere | Central issue record |
| `issue_messages` | issue-store | ✅ stage2, UI | Conversation transcript |
| `issue_evidence` | issue-store, copilot, resolution API, seedIssueFromOrigin | ✅ issue-store loadIssue | **Active. Do NOT confuse with `issue_evidence_items`.** Curated notes (title/detail). Used by copilot + resolution features. |
| `issue_evidence_items` | stage1, stage2 tool results | ✅ stage2, stage3, fetch_evidence | Lossless telemetry store. Different purpose from `issue_evidence`. |
| `issue_actions` | stage2-turn, pipeline-v2 | ✅ UI, store | Approved/executed actions |
| `issue_jobs` | workflow-store | ✅ workflow-store | Job queue |
| `issue_stage_runs` | issue-stage-store | ✅ | Stage execution history |
| `issue_state_transitions` | issue-store | (audit trail) | |
| `issue_facts` / `facts` / `fact_sources` | backend-findings | ✅ | |
| `capability_state` | backend-findings | ✅ | |

---

## AI / config

| Table | Written by | Read by | Notes |
|---|---|---|---|
| `ai_settings` | settings API | ai-settings.ts | Model selection for all features |
| `ai_model_calls` | call-model.ts | AI usage API | Token/cost tracking |
| `agent_memory` | stage3 explainer | agent-memory-store | Durable lessons from past issues |

### Cluster / second-opinion
| Table / key | Status | Notes |
|---|---|---|
| `analysis_runs` / `analyzed_problems` | **Readers fixed 2026-05-31** | `analyzeRecentLogs()` (the writer) still has no callers — it's an AI clustering job that was orphaned when `/api/analysis` was rewritten to use `runIssueDetection`. The three readers (`backend-findings.ts`, `copilot.ts::buildProblemPrompt`, `resolution/create`) were updated to read from `issues` instead. The tables remain in schema for potential future use as a separate AI clustering layer on top of `issues`. |
| `ai_settings.cluster_model` / `getClusterModel()` | **Unwired** | `log-analyzer.ts` hardcodes its model string. This getter is the intended abstraction; wire it through when the cluster feature is revisited. |
| `ai_settings.second_opinion_model` / `getSecondOpinionModel()` | **Unwired feature** | Planned: a second model cross-checks a Stage 2 diagnosis before presenting to the operator. Not yet built. PLAN.md §2/§13 explicitly flags it as planned but out of scope for the initial rebuild. |
| `analyzed_problems.related_problem_ids` | **Unwired** | Column exists, nothing writes to it. Was intended for grouping related problems across runs. |

---

## Copilot / resolution

| Table | Written by | Read by | Notes |
|---|---|---|---|
| `copilot_sessions/messages/actions` | copilot.ts | copilot.ts | Legacy chat interface — active |
| `sync_remediations` | pg_cron every 15min (db functions) | 2 dashboard pages | **Active**. DB functions detect stuck syncs/conflicts and flag recommendations. Executes no actual NAS commands — creates `pending` flagging records only. |
| `push_subscriptions` | settings page | push service | |

### Superseded (candidate for drop — confirm before acting)
| Table | Superseded by | Notes |
|---|---|---|
| `issue_resolutions` | `issues` table | `/api/resolution/*` routes were rewritten to use `issues` + `issue_messages` + `issue_actions`. Zero TS code touches these old tables. |
| `resolution_steps` | `issue_actions` | Same — superseded |
| `resolution_log` | `issue_state_transitions` | Same |
| `resolution_messages` | `issue_messages` | Same |

These are confirmed superseded but NOT yet dropped — migration 00041 is a placeholder pending owner confirmation.

---

## Auth / user

| Table | Notes |
|---|---|
| `user_roles` | Auth checks in issue-store |
| `push_subscriptions` | Web push |
| `ai_analyses` | Written/read by log-analyzer (same unwired-callers issue as analyzed_problems) |
