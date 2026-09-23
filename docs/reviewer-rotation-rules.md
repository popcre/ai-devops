# Reviewer rotation rules

Owner rules, 2026-09-22. They exist because GLM was retired in the shared-db
allocator but stayed registered here, and a session spent an hour trying it.

1. **One source of truth for membership.** The shared-db allocator
   (`u2giants/shared-db` `scripts/manage-migration-author-lanes.mjs`:
   `REVIEWERS` minus `RETIRED_REVIEWERS` and `QUARANTINED_REVIEWERS`) decides
   who is in rotation. `config/reviewer-registry.json` only mirrors it.
   `bin/ai-reviewer-membership-drift` compares the two and fails on any
   difference; the `Reviewer membership drift` workflow runs it every six hours
   and on registry changes. Providers that review outside the allocator
   (Claude approval gate, Codex overflow) are listed in
   `config/reviewer-membership-scope.json`.
2. **Unreachable reviewer: check membership, then move on.** Run
   `bin/ai-reviewer-membership-drift` or read the registry first. If the
   reviewer is out of rotation, never retry it. If it is in rotation but
   unreachable, move to the next registered reviewer within minutes.
3. **Owner policy lands everywhere at once.** A reviewer policy change
   (membership, concurrency, version, restrictions) updates code, config and
   docs in the same change. A rule only in docs is not applied. Example: "no
   limit on concurrent reviews per reviewer" was documented while the allocator
   still made sessions wait.
4. **No per-reviewer concurrency limit.** Never wait for a reviewer because it
   is busy with another review.
5. **CLI versions: a floor, not a pin.** Wrappers enforce a minimum version and
   accept newer ones. A new CLI version is proven by one live, well-formed
   review. It needs no full qualification suite and no Windows run.
