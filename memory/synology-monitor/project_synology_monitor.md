---
name: Synology Monitor Project
description: Cloud-hosted monitoring app for 2x DS1621xs+ NAS units with Go agents, Supabase backend, Next.js UI on Coolify, and GPT-5.4-mini AI analysis
type: project
---

Monitoring application for 2x Synology DS1621xs+ running DSM 7.3.2-86009 Update 3, located in New York.

**Architecture (3 components)**:
- Supabase (shared with POPdam, project ID: ryltkzzernhwnojzouyb) — Postgres DB + pg_cron/pg_net AI pipeline
- Coolify (VPS at 178.156.180.212) — Next.js web UI deployed as Docker container
- Synology Docker — Go agents on each NAS

**AI**: OpenAI GPT-5.4-mini via direct API, called from pg_cron + pg_net inside Postgres
**Why pg_cron over edge functions**: User had timeout/rate limit issues with Supabase edge functions in POPdam project
**Notifications**: Browser push notifications (Web Push API + VAPID)

**Key design decisions**:
- All smon_ prefixed tables in shared Supabase project (to coexist with POPdam tables)
- No Vercel, no Cloudflare Workers — keep it simple with existing infrastructure
- Heavy processing in pg_cron jobs, edge functions only for thin operations

**How to apply:** Minimize number of cloud services. User prefers deploying on infrastructure they already have (Coolify, Supabase, DigitalOcean) rather than adding new services.
