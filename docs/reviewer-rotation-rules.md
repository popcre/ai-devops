# Reviewer rotation rules

Owner rules, 2026-09-22. They exist because GLM was retired in the shared-db
allocator but stayed registered here, and a session spent an hour trying it.

1. **One source of truth for membership.** The shared-db allocator
   (`popcre/shared-db` `scripts/manage-migration-author-lanes.mjs`:
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
6. **No 1Password during a review.** A reviewer wrapper never calls `op`
   while running a review. The installer stores each reviewer secret once in
   a per-user protected store (Windows Credential Manager, or an owner-only
   file); the wrapper reads only that store. `op` is used solely to refresh
   the store at install time or after the stored key is rejected. As of
   2026-09-23 Muse is the one wrapper still calling `op` per run; its fix is
   tracked separately.
7. **Reviewer state stays on its home drive.** `~/.local/state/ai-devops` and
   everything under it must never be moved, junctioned, symlinked, or
   redirected to another drive, and disk cleanup must skip it. A junction to
   `D:` broke Grok's credential hard link on 2026-09-23.
8. **Paths must not grow with names.** Reviewer state, temp, and session paths
   use fixed-length identifiers (hashes or short IDs), never the repository,
   worktree, branch, or session name, so a long name cannot push a path past
   Windows limits.
9. **A Muse Contributor 404 is capacity, not a missing model.** Meta reports
   the shared team's Contributor capacity limit as `model_not_found` (HTTP
   404). `ai-muse` relaunches only an answer-free rejection of that kind: at
   most `AI_MUSE_CAPACITY_RETRIES` extra launches (default 6, so 7 attempts
   in all), waiting a jittered, growing delay based on
   `AI_MUSE_CAPACITY_BACKOFF` (default 20 seconds) before each, and it logs a
   `capacity` line on stderr for each relaunch. The code is `bin/ai-muse` and
   its checks are in `tests/test-ai-muse.sh`. Every other failure still stops the
   review; never switch Muse's model or disable it to get past a 404.
10. **Out of credit is told to Albert in the same session.** Owner rule,
    2026-09-24: "the session that hit that error should A) know that that's
    why it failed, and B) tell me in that same session." When a provider
    refuses a run for lack of paid credit, the Grok, Muse, Qwen, Gemini and
    DeepSeek wrappers stop at once and exit **92**, printing on stderr:

    ```
    AI_REVIEWER_OUT_OF_CREDIT provider=<provider> code=insufficient_quota
    OUT OF CREDIT: <which account, where to add credits> - then run: ai-review-preflight clear <provider>
    ```

    They also record a one-hour `out-of-credit` quarantine, so
    `ai-review-preflight usable <provider>` refuses the provider until it is
    cleared. The session that sees exit 92 or either line must, in its very
    next reply to Albert, quote the `OUT OF CREDIT:` line (which provider needs
    credits and where), then rotate to the next reviewer. Never retry the same
    provider, never report it as a generic failure, and never leave the news
    for another session. The shared-db governed-review runner reports the line
    verbatim in its `REFUSED` result with replacement code
    `insufficient_quota`. The classifier is `tools/reviewer_admission.py credit`;
    its fixtures are `tests/fixtures/reviewer-credit/` and its checks are in
    `tests/test-reviewer-credit.sh`. Rate limits and a bare
    `RESOURCE_EXHAUSTED` are not credit failures.
