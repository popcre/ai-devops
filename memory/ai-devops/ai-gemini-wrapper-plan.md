# Safe `ai-gemini` reviewer plan

Tracking issue [u2giants/ai-devops#38](https://github.com/u2giants/ai-devops/issues/38) adds a review-only `ai-gemini` wrapper around Google Antigravity CLI. Read the STATUS table in [`../../plan_ai-gemini-wrapper.md`](../../plan_ai-gemini-wrapper.md) first; do not implement from chat or re-plan the architecture.

The 2026-08-18 Windows spike proved exact `gemini-3.7-flash-high` selection, structured `/model`, exact-ID resume, token/turn output, and cost-weighted `/usage`. It also proved the release blockers: plan mode is guidance rather than write prevention, Windows terminal sandboxing is unavailable, workspace writes are allowed by default, and JSON `SUCCESS` can contain an empty answer. The wrapper must prove an isolated fine-grained permission profile and hostile write canaries before shipping.
