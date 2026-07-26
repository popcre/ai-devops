---
name: project_twenty_crm_customizations
description: Pop Creations custom features added to Twenty CRM fork — what was built and where
metadata: 
  node_type: memory
  type: project
  originSessionId: 7655c9c6-6737-4347-b365-81f57adcdcb1
---

## ParticipantChip right-click context menu

- File: `/worksp/twenty/fork/packages/twenty-front/src/modules/activities/components/ParticipantChip.tsx`
- Right-clicking a person chip in the email section opens a portal-based context menu
- Menu item "Open People record" navigates to the person's show page via `useNavigate` + `getLinkToShowPage`
- Only appears when `participant.person` is defined (not for bare email senders)

## "Needs Routing" Companies View

- A Companies FOLDER in the left nav contains both "All Companies" and "Needs Routing"
- "Needs Routing" is filtered to `customerStatus IS ['UNASSIGNED']` — shows only "New Company" status records
- Filter uses `IS` operand (not `IS_EMPTY`) because `IS_EMPTY` throws for SELECT fields in the GQL filter builder (`turnRecordFilterIntoGqlOperationFilter.ts`)
- Stored in `core.view`, `core.viewFilter`, `core.navigationMenuItem`

## Twenty View/Nav System

- Views: `core.view` table
- View filters: `core.viewFilter` table
- Nav items: `core.navigationMenuItem` — types: FOLDER, VIEW, OBJECT, RECORD, LINK
- IS_EMPTY operand for SELECT fields is broken in frontend filter logic; use `IS` with `["UNASSIGNED"]` for specific value or `[""]` for NULL

## Deployment

- Coolify build: dockercompose build_pack, image `ghcr.io/u2giants/twenty:latest`
- API: `http://localhost:8000/api/v1/`
- Coolify token: `1|mlVx9mbwsN1Sga6eLtJEvmPioy6Sra9AnepnCe3K7d0a2927`
- Deployments history endpoint: use `/api/v1/deployments?application_uuid={uuid}` (not `/applications/{uuid}/deployments`)
