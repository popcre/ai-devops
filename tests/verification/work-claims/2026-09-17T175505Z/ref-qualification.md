# Issue #131 Phase 1 ref qualification

Qualified at `2026-09-17T17:55:05Z` against `popcre/ai-devops` from clean
`origin/main` `26bb4a2efdd9cd243df6d4fb7c0d901ba3fb2868`.

Result: **PASS**. Select `refs/ai-devops-claims/<key>` for v1. GitHub's custom
ref namespace supports REST create/read/list and exact-object Git
force-with-lease update/delete from Windows Git Bash and Ubuntu. The branch
fallback was not needed.

## Re-derived authority

- Canonical remote: `https://github.com/popcre/ai-devops.git`.
- Repository policy: `feature-branch-pr`, target `main`.
- Issue #89: `CLOSED` at `2026-08-28T03:09:12Z`.
- Issue #131: `OPEN` (read at qualification time).
- Ruleset `21564317`: active, named `main: pull request + merge queue`; it
  protects the main branch with pull-request, merge-queue, non-fast-forward,
  deletion, and `verification-closure` requirements. No ruleset was changed.
- Both Windows and Ubuntu returned zero refs matching
  `refs/ai-devops-claims/qualification-20260917T175505Z-*` before creation.

## Synthetic objects

The commits reused the tree from the qualification base and contained only
harmless issue/UTC metadata plus this synthetic owner hash:
`c6961326554d2319ea69679a93244e01167adcaf0e07d2c276c8ea22874b4f73`.
No raw owner token was created, logged, or committed.

- Base: `26bb4a2efdd9cd243df6d4fb7c0d901ba3fb2868`
- Tree: `571f822230e8c02e9cf3b495d1318ad935e742e3`
- Initial object: `e39a1b03e1c77e1d828fd28b6d4e7b033768589e`
- Update object: `e41b7ad362b139f59d782f6de8b132babfc58c8e`
- Stale-candidate object: `dd84a80ab7432ffa6c3efe5cdda4e14515f47067`

## REST admission and lost-response recovery

Windows used `bin/ai-gh` for every GitHub API call.

1. Creating
   `refs/ai-devops-claims/qualification-20260917T175505Z-win-a7c9f21e`
   at the initial object returned `HTTP 201`.
2. A second create of that exact ref at the stale-candidate object returned
   `HTTP 422 Reference already exists` and exit 1.
3. Exact readback still returned the initial object. Reading its commit message
   returned the same owner hash above. This is the simulated lost-response
   re-adoption proof: ref, object, and owner hash all matched the candidate.
4. The matching-refs endpoint found exactly one qualification ref without any
   issue search.
5. A second ref for Ubuntu,
   `refs/ai-devops-claims/qualification-20260917T175505Z-ubuntu-b4d6e803`,
   was also created by REST at the initial object with `HTTP 201` and read back
   exactly before Git-protocol mutation.

## Windows Git Bash

- Git fetched and validated all three synthetic objects as commits.
- Exact lease `initial -> update` succeeded; immediate readback was
  `e41b7ad362b139f59d782f6de8b132babfc58c8e`.
- Stale lease `initial -> stale-candidate` exited 1 with `[rejected] (stale
  info)`; readback remained the update object.
- Stale lease delete from the initial object exited 1 with `[rejected] (stale
  info)`; readback remained the update object.
- Exact lease delete from the update object succeeded; exact readback was
  absent.

## Ubuntu

Host proof was Linux `6.8.0-139-generic` x86_64 with Git `2.43.0`.

- Git fetched and validated all three synthetic objects as commits.
- Exact lease `initial -> update` succeeded; immediate readback was
  `e41b7ad362b139f59d782f6de8b132babfc58c8e`.
- Stale lease `initial -> stale-candidate` exited 1 with `[rejected] (stale
  info)`; readback remained the update object.
- Stale lease delete from the initial object exited 1 with `[rejected] (stale
  info)`; readback remained the update object.
- Exact lease delete from the update object succeeded.

## Cleanup gate

After both expected-object deletions:

- Windows `git ls-remote` matching the disposable prefix returned zero refs.
- Ubuntu `git ls-remote` matching the disposable prefix returned zero refs.
- GitHub's matching-refs endpoint returned an empty array (`length = 0`).

No main branch, tag, existing ref, issue state, ruleset, workflow, production,
or infrastructure state was changed. Step 2 is qualified; Steps 3-6 remain
separate work.
