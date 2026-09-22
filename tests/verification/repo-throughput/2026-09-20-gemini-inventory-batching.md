# Benchmark — batched Gemini byte inventory (2026-09-20)

Evidence for plan `plan_workflow-efficiency.md` step P1 and issue
[#633](https://github.com/popcre/ai-devops/issues/633). Synthetic fixture only:
no repository, customer or reviewer content is included.

## What was measured

One full review-copy inventory pass (`provider_wrapper_tree_inventory`,
reached through `ai-gemini`'s `inventory()`), against the exact per-file
implementation that shipped before this change.

## Fixture

- 30,384 regular files, matching the file count recorded in the 2026-09-18
  edge-dev incident.
- 62 directories, 500 files each; sizes cycle from 1 byte to about 10 KiB of
  random bytes, so hashing cost is not uniformly trivial.
- Generated fresh for the run and deleted afterwards.

## Host and load

- `916-alien`, Windows 11 Pro 10.0.26200, Git Bash (`MINGW64_NT-10.0-26200`).
- Load average at start: 6.36 — a loaded developer box, not an idle runner.

## Result

| Implementation | Run | Elapsed |
|---|---|---|
| Batched | 1 | 7.627 s |
| Batched | 2 | 7.574 s |
| Batched | 3 | 6.899 s |
| Per-file (pre-change reference) | 1 | 952.305 s |

Both implementations produced the same digest,
`90e5885cada4a868a326d515e63021180ff82a4d557b0a9e3c39a686daef86af`, so the
record stream is byte-identical and stored `review_tree_sha256` /
`source_tree_sha256` values remain comparable. No digest version was
introduced and no session needs re-baselining.

Against the plan's P1 target of a pass in 30 seconds or less: met, with the
slowest batched run at 7.6 s. The per-file reference at the same scale took
15 minutes 52 seconds on this host, and the incident host was slower still.

## Smaller scale, inside the suite

`tests/test-provider-wrapper-common.sh` runs a 4,000-file batched pass with a
60-second ceiling (measured at 1-2 s here) and proves byte parity separately on
an adversarial fixture and on an argument list larger than this host's exec
limit, so the multi-invocation batch boundary is covered without paying for a
30k-file reference run in every suite execution.

## Reproducing

The benchmark is a throwaway script, not installed tooling: source
`tools/lib/provider-wrapper-common.sh`, generate the tree, and time
`provider_wrapper_tree_inventory` against the per-file reference kept in
`tests/test-provider-wrapper-common.sh` as `legacy_tree_inventory`.

## What this does not prove

An installed live Gemini exercise. The `agy` runtime is not installed on
`916-alien`, so no real provider prepare was run. That evidence is owned by
[#676](https://github.com/popcre/ai-devops/issues/676) and P1 stays open in the
plan until it is recorded here.
