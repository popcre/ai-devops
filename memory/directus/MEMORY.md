# Memory index

- [Platform decision: Directus](platform-decision-directus.md) — PM/CRM/DAM super-app on self-hosted Directus (OIG granted); solo non-programmer + AI; Data-Studio-first; phased PM→CRM→DAM. Not Plane, not Twenty.
- [Entra role hub (Model B)](entra-role-hub.md) — roles centralize in Entra ID groups; Directus is the single writer, CRM/DAM read-only consumers; hourly sync timer. Supersedes the Designflow PLM idea.
- [designflow.app domain plan](designflow-domain-plan.md) — pm/crm/dam = human frontend URLs (permanent); data.designflow.app = Directus backend API only; never retire pm, rebind it to poppim-web at launch.
- [Product image storage](product-image-storage.md) — cover_url from ClickUp CDN; _large thumbs now 403; clickup-to-spaces.mjs copies originals to DigitalOcean Spaces (Space `poppim`@nyc3) and repoints cover_url.
- [Feedback: store originals](feedback-store-originals.md) — keep original images as-is regardless of size; don't silently resize/optimize stored assets — ask first.
- [Directus access model](directus-access-model.md) — Directus 11 uses policies; non-admin roles share an "All Access (temp)" policy granting full data access until gating is added later.
- [Git objects root-owned](git-objects-root-owned.md) — commits fail with "invalid object"/Permission denied when sudo git left .git root-owned; fix is `sudo chown -R ai:ai /worksp/directus/.git`, run automatically.
