# Portable memory architecture

This public repository contains only the reusable memory schema and tooling.
Operational memory facts live in the private repository
`u2giants/ai-devops-memory`; they must never be copied into this tree.

The private hub uses this shape:

```text
memory/<canonical-project>/
  MEMORY.md
  <portable-fact>.md
  .forgotten
```

- `MEMORY.md` indexes every surviving fact.
- `.forgotten` tombstones are the only deletion authority.
- Synchronization unions facts and index entries; absence never means deletion.
- Automated writers verify the canonical private remote before copying data.
- Credential-pattern and health checks must pass before every push.
- Raw Claude and Codex transcripts are never memory inputs.

`project-map.tsv` is the secret-free canonicalization table shared by the public
sync tool and the private hub. Machine paths, credentials, facts, host topology,
and private-repository contents remain outside this public repository.

Use `ai-memory-health --repo-root <private-hub> --hub-only --index-only` for a
read-only coverage check. Automatic memory writers remain disabled. A manual,
explicitly initiated private-hub union is the qualified production policy.
