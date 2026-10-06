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
   (Codex approval gate, StepFun on Ubuntu/Linux) are listed in
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
   the store at install time or through an explicit maintenance command after
   a stored key is rejected. A review with a missing or rejected key stops.
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
    refuses a run for lack of paid credit, the Grok, Muse, Qwen, Gemini,
    DeepSeek and StepFun wrappers stop at once and exit **92**, printing on stderr:

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

11. **Credit pause is a one-command switch, not a roster edit.** Owner rule,
    2026-09-30: subscription credit pauses must be as easy as on/off. Use
    `ai-review-preflight quarantine <provider> out-of-credit` to turn a
    provider off and `ai-review-preflight clear <provider>` to turn it back
    on after a refill. The allocator already skips quarantined providers.
    Never edit `RETIRED_REVIEWERS` or `config/reviewer-registry.json` for a
    credit pause — that path needs two repos, tests, and a review. Reserve
    roster edits for permanent retirement or a real membership change.

12. **StepFun is in the allocator rotation (shared-db#3657, merged
    2026-10-01); it is drawn only where `ai-review-preflight usable stepfun`
    passes. Linux is bubblewrap-isolated, Windows
    is folder + test shell (weaker).** Owner instruction 2026-09-25: StepFun
    on Ubuntu only with bubblewrap. Owner instruction 2026-09-30 (MiMo chat,
    *folder + test shell*): Windows may run `review`/`ask` via the pinned
    OpenCode engine inside a disposable remote-less folder with a gated test
    command path (`bin/ai-stepfun-windows-shell`). **Windows is not
    rule-12 equivalent and is not mount-isolated.** On Windows, OpenCode file
    tools are removed (`tools:` map — the only enforcement on pin 1.18.12);
    `implement` is refused; exploration/tests run through the gate
    (`ls`/`cat`/`head` in-folder + allowlisted test runners). Residual
    (owner-accepted 2026-09-30): in-folder scripts and runner abuse are
    arbitrary user-level code; network is shared. Linux turns still run under
    bubblewrap with an empty home, /tmp and /run and a cleared environment,
    so the model never sees SSH keys or the agent socket, git or gh
    credentials, the 1Password token, or the Docker socket. The
    commit/remote refusal is an extra end-state check. Accepted exposure on
    Linux: shared network (StepFun API). The shared-db allocator has no
    platform field, so StepFun is listed in
    `config/reviewer-membership-scope.json` and is never assigned by the
    allocator.

---

## Reviewer lookup table (wrapper → pin → reroute)

One unowned reference for "this reviewer is down — which wrapper do I fix,
what pin applies, where do I go next." Membership truth stays with the
shared-db allocator and `config/reviewer-registry.json` (rule 1). This table
does not replace `ai-review-preflight usable <provider>`, which reports the
resolved `wrapper_command` and live `usable` state for the machine you are on.

**Reroute-on-empty policy (after #1183 child 1).** An empty reviewer verdict
(no well-formed VERDICT line, or an empty report) is a **result** failure of
the **review step** — never a PR test-verdict red, and never a PASS. It
reroutes to the next registered rotation reviewer within minutes (rule 2).
Timeout, kill, and rate-limit are **capacity**, not result: they do not
invalidate an existing exact-head approval and do not start a new review
cycle. Out-of-credit (exit 92) quarantines the provider for one hour,
tells Albert in the same session, and rotates (rules 10–11). Muse capacity
404 is capacity: relaunch with backoff (rule 9), not a reroute.

| Reviewer / Provider | Wrapper command | Pin source & match mode | Primary use | Reroute-on-empty / fallback | Notes |
|---|---|---|---|---|---|
| **Claude** | `ai-claude-review` (legacy name; registry refuses) | n/a — absent from pool | Orchestrator/writer only. Never a formal or assigned review. | n/a — never drawn | Removed 2026-09-30 (owner: "take claude out of the reviewer pool"). `ai-review claude` exits 2 via the registry gate. |
| **Codex** | `ai-codex-review` (also `ai-review codex <mode>`) | `CODEX_CMD` in `/etc/ai-devops/models.env` (default `codex exec -m gpt-5.6-sol --sandbox read-only -c model_reasoning_effort=medium`). No entry in `config/provider-cli-versions.json`. | Approval-gate wrapper only (one-shot modes). Not a rotation or overflow reviewer. | Not drawn by the allocator. Gate failures fail closed. | Outside allocator (`config/reviewer-membership-scope.json`). shared-db `RETIRED_REVIEWERS` carries `codex-gpt-5.6-sol` since 2026-09-06. |
| **Grok** | `ai-grok-review` (formal); `ai-grok-implement` (isolated edits / investigate) | `config/provider-cli-versions.json`: `supported_version` 1.0.13, `version_match: minimum` (floor, same major). Model pin `grok-4.6` + `dismiss_campaigns`. | Rotation reviewer. | Next registered rotation reviewer. Exit 92 → quarantine + tell Albert + rotate. | Never call `grok` directly. xAI launch campaigns replace the default model and beat `config.toml`; the installers pin `models.default` and dismiss campaigns. |
| **Muse** | `ai-muse` | OpenCode `1.18.12` (`config/opencode/version`). Model pin `muse-spark-1.3-contributor`. Not in `provider-cli-versions.json`. | Rotation reviewer. Default pipeline review provider. | Next registered rotation reviewer. Capacity 404 (HTTP 404 `model_not_found`) = capacity: relaunch ≤ `AI_MUSE_CAPACITY_RETRIES` (default 6) with jittered backoff. | Never switch Muse's model or disable it to get past a 404 (rule 9). |
| **Qwen** | `ai-qwen` | `config/provider-cli-versions.json`: `supported_version` null (not pinned; presence sufficient). Model pin `qwen3.8-max`. | Rotation reviewer. | Next registered rotation reviewer. | Registry membership is not usability — `ai-review-preflight status qwen` is the live answer. Reviews run in a disposable remote-less copy. |
| **Gemini** | `ai-gemini` | `config/provider-cli-versions.json`: not pinned there; `ai-review-preflight` binds live qualification to the exact `agy` version **and hash** (hash-pin). Model pin `gemini-3.8-flash-high`. | Rotation reviewer. | Next registered rotation reviewer. Exit 92 → quarantine + tell Albert + rotate. | Any `agy` change re-quarantines Gemini until re-qualified. Headroom: `ai-gemini-usage`. |
| **DeepSeek** | `ai-deepseek-agent` (via `ai-review deepseek <mode> --code-only`) | OpenCode `1.18.12` (`config/opencode/version`). Model pin `deepseek-flash` (DeepSeek V4.1 Flash). Not in `provider-cli-versions.json`. | Rotation reviewer. Also freeform multi-turn debate. | Next registered rotation reviewer. | Formal rotation reviews on the read-only `ai-deepseek-agent`. Any other model id is refused before credential use. |
| **Kimi** | `ai-kimi` | `config/provider-cli-versions.json`: `supported_version` null (not pinned; presence sufficient). Model pin `kimi-code/k3`. | **Absent from rotation** (account out of credit since 2026-09-10). Structurally read-only reviews when active. | n/a — not in rotation. Never retry. | Re-entry requires a reviewed registry change backed by a live well-formed verdict. Historical evidence retained. |
| **GLM** | `ai-glm` | OpenCode `1.18.12` (`config/opencode/version`). Model pin `glm-5.3`. Agent pins in `config/opencode/agent/*.md`. Not in `provider-cli-versions.json`. | Rotation reviewer (restored 2026-09-30). Also explicitly requested second opinion. | Next registered rotation reviewer. GLM never reviews GLM-orchestrated (ZCode) work. | Windows runs `ai-glm` on the Ubuntu host over SSH. |
| **StepFun** | `ai-stepfun` | `bin/ai-stepfun` enforces its own floor 0.1.1 (StepCode). Not in `provider-cli-versions.json`. OpenCode `1.18.12` for the Windows path. Model pin `step-5-preview`. | Allocator rotation reviewer (shared-db#3657) plus second opinions. Ubuntu/Linux only (bubblewrap). Windows: folder + test shell via OpenCode (not rule-12 equivalent). | In allocator rotation; skipped wherever preflight reports it unusable. | Windows `implement` is refused. Drawn on a machine only when preflight there says usable. |
| **ZCode** | `ai-zcode` (headless driver only) | n/a | Interactive client (GLM-5.3 desktop agent). **Not a reviewer.** | n/a | No ZCode reviewer, ever (owner ruling 2026-09-17). |
| **MiMo** | `ai-mimo` (headless driver only) | n/a | Interactive client. **Not a reviewer.** | n/a | No MiMo reviewer. |
