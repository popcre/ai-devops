# Memory Index

- [AI does everything](feedback_no_direct_db_writes.md) — user is not a programmer, runs nothing; AI commits/pushes/applies migrations/deploys end-to-end. Apply SQL directly to prod EXCEPT when it should live in code on GitHub (source of truth) — those get a committed migration file first, then apply.
- [GitHub repo](reference_github_repo.md) — Fork is at github.com/u2giants/twenty; local source at /worksp/twenty/fork
- [Albert = u2giants](project_albert_u2giants_same_person.md) — albert@popcre.com & u2giants@gmail.com are same person; folded into albert, Google SSO greyed out (not account-linked)
- [Email routing architecture](project_email_routing_architecture.md) — Router logic, subdomain fix, customerStatus values, Burlington/TJX status, ghost company pattern
- [Twenty CRM customizations](project_twenty_crm_customizations.md) — ParticipantChip right-click menu, Needs Routing view, nav system, Coolify deployment details
- [Workspace DB schema](project_workspace_db.md) — Postgres workspace schema name `workspace_93r34ew9zc9644a9y5f1yeylz` and key tables
- [v2.8 upgrade + drift](project_v28_upgrade_and_drift.md) — fork is v1.20→re-fork to v2.8 (plan in 2.8_upgrade.md); data model is code-defined; view/nav drift captured in migrations 010/011
