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

## Index size, and why you must not trim it by hand

Each project's `MEMORY.md` index is loaded into **every** session, so it carries a
size budget: `ai-memory-health` fails at **12KB** or 200 lines (lowered from 25KB
on 2026-08-26). That check now runs in `--coverage-only` too — the mode
`bin/ai-memory-sync` gates on — because before then it was skipped there, so the
budget existed and never blocked a single sync.

**Do not shrink an index by rewriting its lines.** `bin/ai-sync-memory` unions the
index keyed on **full line text**, so a rewritten line is not recognised as the
same entry: it is appended beside the original and the index *grows*. A 2026-08-26
proposal to trim ~48 lines would have roughly doubled the index on every machine,
with no line-grained way back — tombstones (`ai-memory-sync forget`) are
file-grained by design, and would remove both versions along with the memory file.

Reduce an index by retiring entries that are genuinely dead, through the tombstone
path. Shorten a line only after the union is keyed on the filename instead.
