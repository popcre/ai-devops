---
name: Minimize Cloud Services
description: User pushes back on adding new cloud services — prefer existing infrastructure
type: feedback
---

Don't add new cloud services (Vercel, Cloudflare Workers, etc.) when user already has working infrastructure.

**Why:** User found 4 services (Cloudflare + Supabase + Synology + Vercel) too complicated for a small monitoring project. Prefers using what they already have: Coolify, Supabase, DigitalOcean.

**How to apply:** Before suggesting a deployment target, check what infrastructure the user already has and propose deploying there first. Only suggest new services if existing infra genuinely can't handle the requirement.
