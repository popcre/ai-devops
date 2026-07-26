---
name: project_popsg_tester_login
description: AI browser-test login for PopSG/PopDAM exists in 1Password (ai-tester@popcre.com); how access is gated + teardown
metadata: 
  node_type: memory
  type: reference
  originSessionId: 19eecc5d-4fd8-4df8-b1da-1513b95eb129
  modified: 2026-07-22T23:06:38.309Z
---

An email/password AI test account for the PopSG + PopDAM apps (shared Supabase `qsllyeztdwjgirsysgai`) lives in 1Password vault `vibe_coding`, item "PopSG PopDAM AI tester login" (id `eknc4mbmburdz7njt6vifham6u`).

- Login email: `ai-tester@popcre.com`; password in the item's password field. Role `user` (not admin); app_access = popdam + styleguides. auth user id `68a61bae-7e93-46df-b5b1-c89982bcb5cf`.
- **Access is invitation-gated** by the `handle_new_user` trigger on `auth.users`: email/password (and Google) signups RAISE "Access denied" unless a matching row exists in `public.invitations`. Azure/Authentik SSO bypass invitations. So to make an email/password user work: (1) insert `invitations` row (email, role, apps), (2) create the user via `/auth/v1/admin/users` with `email_confirm=true` (service-role key from 1Password item "Supabase Runtime Keys - shared POP database (production)"). The trigger then provisions `profiles`, `user_roles`, `app_access`.
- Browser login without typing the password: password-grant token exchange (anon key + password) → inject the session JSON into `localStorage["sb-popdam-auth-token"]`, then load `/library`.
- Teardown: `delete from auth.users where id='68a61bae-...';` (cascades) + `delete from invitations where email='ai-tester@popcre.com';` + delete the 1Password item. Full steps are in the item's notes.

DB access path for this project: [[project_secret_access_paths]] (psql via pooler `aws-1-us-east-1.pooler.supabase.com:6543`, user `postgres.qsllyeztdwjgirsysgai`, PGPASSWORD from op item "Supabase DB Password - shared POP database"). App-mode split: [[project_popsg_search_paths]].
