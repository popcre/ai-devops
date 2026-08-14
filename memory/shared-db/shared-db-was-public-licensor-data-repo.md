---
name: shared-db-was-public-licensor-data-repo
description: "u2giants/shared-db was PUBLIC until 2026-08-07 and held Disney's confidential extract; now private. Licensor portal extracts go to u2giants/licensor-source-data (private), never shared-db."
metadata: 
  node_type: memory
  type: project
  originSessionId: 774f5010-1b71-4c45-b45c-b250053f5c4d
  modified: 2026-08-07T16:25:19.594Z
---

`u2giants/shared-db` was created **PUBLIC** (2026-06-20) and stayed public until
**2026-08-07 ~15:10 UTC**, while holding
`docs/verification/opa-characters-20260806/opa-characters.csv` — 10,262 rows of
Disney's property/character list with Disney's own internal IDs, merged in
PR #466. The README beside it said the data was business-confidential and must
not be published. Nobody noticed until an automated security warning fired on an
unrelated sub-agent PR.

Albert had it made **private** immediately. Measured at the flip: **0 forks, 0
stars, 0 watchers** — no evidence anyone copied it, though crawlers leave no trace.

**Where licensor data goes now:** `u2giants/licensor-source-data` — created
2026-08-07, **PRIVATE**, one folder per licensor portal (`disney-opa/`,
`disney-dcpvault/`, `warner-bros/`). Never make it public. Never touch another
session's folder. `shared-db` gets a **pointer only**, never the data.

**The trap that nearly repeated the leak, same day:** a *schema design document*
is genuinely a shared-db artifact, so writing it into `C:/repos/shared-db/docs/`
feels correct — but if it quotes real style guide names, file names or licensor
ids, it **is** licensor data. It was caught untracked, one `git add .` from a
commit. Draft such docs in the private repo; only a sanitized version, with no
licensor strings, goes to shared-db, placed by the coordinator.

**Why:** these extracts come from licensee portals (Disney OPA, Warner Bros)
under commercial licensing agreements. Publishing them is a licensor-relationship
problem, not just a security one.

**How to apply:** before committing any licensor-portal extract, asset filename
list, or style-guide list anywhere, check the target repo's visibility with
`gh repo view <repo> --json visibility`. Nothing in `AGENTS.md`, the orchestrator
skill, or CI checks visibility before a commit — **that gap is still open**.
Albert wants `shared-db` public again eventually, which requires scrubbing the CSV
from its git history (deleting the file is not enough); tracked as **R-SEC-1** in
`COORDINATOR_INTAKE.md`.

Related: [[characters-are-appearances-not-characters]],
[[shared-db-apply-mechanics]], [[always-delegate-work-to-subagents]].
