---
name: contracts-not-a-data-source
description: Owner ruling 2026-08-19 — licence contracts are never a source of record; licence term and territory are out of scope for the shared DB entirely
metadata:
  type: feedback
---

Albert, 2026-08-19, visibly frustrated ("this is the 400th time i am saying this"):

> "you're not supposed to be referring to or using the contracts. the data scrapes +
> coldlion api feed are canonical."

> "this system has no connection to license term or territory. remove any and every
> record of that from this system for all licensors"

Recorded permanently as shared-db `AGENTS.md` §6.16 (PR #1241). Companion to §6.15,
see [[property-list-two-kinds-ruling]].

**Why:** the shared database models what we scraped and what we make. Legal entitlement
is a different system's job. A contract looks like an authoritative source — signed,
dated, specific — so every fresh session that meets one reaches for it. That reflex is
what he is tired of. A count "corrected" from a contract matches neither canonical source.

**How to apply:** never transcribe, cite, or commit a licence contract/schedule/amendment
as a data source, and never ask Albert to produce one. Never propose columns for licence
term, territory, expiry, restriction text or rights scope. A contract-versus-scrape
discrepancy is NOT a finding — the scrape wins by definition. If an issue proposes any of
this, close it citing §6.16 rather than escalating to Albert. Killed shared-db #732 in full
and `plm.nbcu_right` (removal on #1242).

**Not changed:** confidentiality. Licensed rows still never leave their approved private
repo (§6.14).
