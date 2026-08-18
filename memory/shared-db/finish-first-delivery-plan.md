# Shared-db finish-first delivery replacement

The perpetual shared-db orchestrator is being replaced by the governed plan at [`../../plan_shared-db-finish-first-delivery.md`](../../plan_shared-db-finish-first-delivery.md). Read its STATUS table first. Do not re-derive the design from chat or implement directly from `shared-db_orchestrator_failure_analysis.md`.

Locked direction from the 2026-08-18 Codex/Grok/Kimi architecture review: keep durable migration-version, exact-object, stage, identity, review, ordering, forward-only, and live-verification controls; retire the standing coordinator, automatic refill, and three-lanes-full target; use one outcome in shared stages plus at most one isolated authoring outcome; add a read-only aging/orphan audit before activation; measure only live verified application outcomes.
