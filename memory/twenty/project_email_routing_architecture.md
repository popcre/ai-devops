---
name: project_email_routing_architecture
description: "How Pop Creations email routing works — key files, logic, and known patterns"
metadata: 
  node_type: memory
  type: project
  originSessionId: 7655c9c6-6737-4347-b365-81f57adcdcb1
---

## Email Router

- File: `/worksp/twenty/fork/packages/twenty-server/src/modules/pop-creations/services/email-router.service.ts`
- Matches sender email domain to a company using ILIKE on `COALESCE(NULLIF(routingDomain,''), domainNamePrimaryLinkUrl)`
- Only matches companies with `customerStatus IN ('ACTIVE_CUSTOMER', 'POTENTIAL_CUSTOMER')` — UNASSIGNED companies are never auto-matched
- Multiple routing domains: stored comma-separated in `routingDomain` field (e.g. `burlington.com,burlingtonstores.com`); the ILIKE substring check naturally handles this
- Subdomain fix (commit e8f18d9): added reverse ILIKE check so subdomains route to parent:
  ```sql
  emailDomain ILIKE '%.' || REGEXP_REPLACE(companyDomain, '^https?://', '')
  ```
  Both checks applied at two spots in the file (~line 521 and ~line 641)

## Ghost Company Problem

- A contact-sync cron auto-creates UNASSIGNED company records for each new email domain, including subdomains
- An email rerouter cron runs every 6 hours to reprocess UNROUTED/COMPANY_ONLY emails
- Subdomain ghosts (e.g. `dgmn.dollargeneral.com`) appear as "New Company" instead of routing to parent
- **Fixed**: router now does reverse subdomain check; past ghosts cleaned up with SQL reassigning people and soft-deleting the ghost

## CustomerStatus Values

- `ACTIVE_CUSTOMER` — green, fully matched by router
- `POTENTIAL_CUSTOMER` — yellow, matched by router
- `OTHER` — gray, NOT matched by router
- `UNASSIGNED` — red, labeled "New Company" in UI, NOT matched by router; these appear in "Needs Routing" view

## Burlington Routing

- `routingDomain = 'burlington.com,burlingtonstores.com'` (both domains needed)

## TJX — Pending Decision

Three fragmented UNASSIGNED records: `The TJX Companies`, `Tjxcanada`, `Tjxeurope`. All UNASSIGNED so emails from @tjxcanada.ca, etc. go unrouted. User needs to decide on consolidation and status. No fix applied yet.

**Why:** Router only matches ACTIVE/POTENTIAL; these are all UNASSIGNED.
**How to apply:** Don't auto-fix TJX without explicit user instruction on which record to keep and what status to assign.
