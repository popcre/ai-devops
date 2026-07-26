---
name: project-albert-u2giants-same-person
description: "albert@popcre.com and u2giants@gmail.com are the same person (Albert); consolidated to albert, Google SSO greyed out"
metadata: 
  node_type: memory
  type: project
  originSessionId: cfe0174c-37ff-45c5-9c62-ecc3556af31b
---

`albert@popcre.com` (Microsoft SSO, Admin, workspace creator) and `u2giants@gmail.com`
(Google SSO, "Albert Test" member, was a Member role) are the **same person** — Albert.

Decision (2026-05-29): do NOT build per-user account-linking (Twenty auth is email-keyed
with a unique email; would require forking core auth). Instead:
- **Folded** the u2giants workspace member's data into Albert's member — migration
  `packages/twenty-server/src/modules/pop-creations/migrations/009_fold_u2giants_member_into_albert.sql`
  (reassigned 115 messageParticipant + 2 calendarEventParticipant rows; nothing deleted —
  u2giants core.user / userWorkspace / role / workspaceMember rows left dormant).
- **Greyed out** the Google SSO button (kept the code/functionality) via the
  `IS_GOOGLE_SSO_TEMPORARILY_DISABLED` flag in
  `packages/twenty-front/.../sign-in-up/components/internal/SignInUpWithGoogle.tsx`.
  Flip the flag to `false` to re-enable.

Key ids: workspace `99c80ca1-610f-48b5-bd1f-9178201bdcb7`, workspace schema
`workspace_93r34ew9zc9644a9y5f1yeylz`; Albert member `9c336883-8834-4823-839e-5af5828910e3`,
u2giants member `80b8a522-e853-48a8-8b63-1f2c0d95765b`.

Note: as of the 2026-05-29 deploy, Google SSO is NOT configured on the server — only
`AUTH_MICROSOFT_*` env is set, no `AUTH_GOOGLE_*`. So the backend reports `authProviders.google
= false` and the Google button does not render on the live login at all. The workspace
`isGoogleAuthEnabled` flag was also flipped to false on 2026-05-29 (matches reality; reversible).
The greying change is therefore a
safety net: if Google OAuth env is ever added back, the button renders greyed/disabled until the
flag is flipped to false. See [[feedback-no-direct-db-writes]].
