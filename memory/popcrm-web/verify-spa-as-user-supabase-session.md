---
name: verify-spa-as-user-supabase-session
description: How to browser-verify a Supabase SSO SPA (popcrm-web etc.) as a specific user without real Microsoft SSO
metadata: 
  node_type: memory
  type: reference
  originSessionId: c4eb4913-a145-4f56-ae3a-7c640a488fd5
---

To drive one of the shared-Supabase React SPAs (popcrm-web, poppim-web, popdam)
in a real browser **as a specific user** when the app only supports Microsoft
Azure SSO (not automatable):

1. Run the dev server with a temp `.env` (`VITE_SUPABASE_URL` + anon key from
   1Password `Supabase Runtime Keys - shared POP database (production)`). `.env`
   is gitignored.
2. Mint a real session with the **service-role** key (in
   `/home/ai/.crm-worker.env` for CRM). Node 20 here lacks native WebSocket, so
   use the GoTrue **REST** API, not the supabase-js client:
   - `POST {URL}/auth/v1/admin/generate_link` (service-role bearer, body
     `{type:"magiclink", email}`) → returns `hashed_token`.
   - `POST {URL}/auth/v1/verify` (anon apikey, body
     `{type:"magiclink", token_hash}`) → returns `access_token` + `refresh_token`.
3. In Playwright, navigate to the app, then
   `localStorage.setItem('sb-<project-ref>-auth-token', JSON.stringify(session))`
   (ref = `qsllyeztdwjgirsysgai` for prod), then reload — the SPA restores the
   session and renders as that user. Base64-encode the JSON to dodge escaping.

Clean up after: delete the temp `.env`, the minted-session scratchpad files, and
any screenshots. The session JWT is ~1h and harmless once expired, but don't
leave it lying around. See [[verify]].
