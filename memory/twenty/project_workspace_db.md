---
name: project_workspace_db
description: Twenty CRM database workspace schema name for Pop Creations
metadata: 
  node_type: memory
  type: reference
  originSessionId: 7655c9c6-6737-4347-b365-81f57adcdcb1
---

Workspace schema: `workspace_93r34ew9zc9644a9y5f1yeylz`

Used for all direct SQL queries against the Twenty CRM Postgres database. Key tables:
- `workspace_93r34ew9zc9644a9y5f1yeylz.company` — companies with `customerStatus`, `routingDomain`, `domainNamePrimaryLinkUrl`
- `workspace_93r34ew9zc9644a9y5f1yeylz.person` — people with `companyId`
- `core.view`, `core.viewFilter`, `core.navigationMenuItem` — UI nav/view config
