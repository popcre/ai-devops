# Plan — ai-muse native-engine parity: close every closable gap, add the native extras, switch the default to Muse Code

Issue: [#542](https://github.com/popcre/ai-devops/issues/542) · Owner decision: Albert, 2026-09-17 · Plan written: 2026-09-17 (edge-dev, Claude)
Handoff: [`HANDOFF.d/2026-09-17T1416Z-edge-dev-claude-muse-native-parity-plan.md`](HANDOFF.d/2026-09-17T1416Z-edge-dev-claude-muse-native-parity-plan.md)

## STATUS

A fresh session starts at the first non-done row. Re-read §5–§8 and the target
phase in full before starting each phase (drift check); pair with `fresh-session`
at every cut point.

| Step | What | State | Evidence / notes |
|---|---|---|---|
| 0A | Credential-lock wait branch landed or explicitly coordinated | ⬜ open | Dependency, owned by another live session — see §5 |
| 0B | Phase A worktree + `ai-task-gates start --class reviewer-safety` | ⬜ open | — |
| A1 | `muse-code` adapter in `tools/reviewer_usage.py` | ⬜ open | — |
| A2 | Wrapper reads durable-store usage at retain time (`turn_usage`) | ⬜ open | — |
| A3 | Stub store + usage tests in `tests/test-ai-muse-code.sh` (+ adapter unit tests) | ⬜ open | — |
| B1 | Doctor catalog checks (exists / `is_current` / `visibility`, report limits + cost) | ⬜ open | — |
| B2 | Catalog-priced cost estimate in the adapter (provenance-labeled) | ⬜ open | — |
| B3 | Catalog + doctor tests | ⬜ open | — |
| C1 | `AI_MUSE_REASONING_EFFORT` support + metadata record + tests | ⬜ open | — |
| C2 | `delete` also removes the date-bucketed durable log + tests | ⬜ open | — |
| D1 | Live qualification turns on the muse-code engine | ⬜ open | — |
| D2 | shared-db `REVIEWERS` evidence update (scripts/docs PR) | ⬜ open | — |
| D3 | Default flip to `muse-code` + docs + test expectation flip | ⬜ open | — |
| D4 | Post-flip governed review through shared-db verified | ⬜ open | — |

Every code phase lands as its own branch + PR through the merge queue, under
task class `reviewer-safety`, with one independent read-only exact-head review
before merge (§11). A row marked done must cite an artifact (file, commit SHA,
CI run, or command), never a bare claim.

---

## Part 1 — Why

### 1. The ultimate goal

Albert decided on 2026-09-17: **Muse reviews must run on Meta's native Muse Code
CLI through our wrapper, not through the OpenCode harness — but only once the
wrapper over the native CLI (a) has everything the OpenCode path had that a
wrapper can provide, and (b) exposes the native capabilities worth having that
the wrapper does not use yet.**

When this plan is done:

- `ai-muse` defaults to the `muse-code` engine with no env var needed; the
  OpenCode engine remains installed and selectable via `AI_MUSE_ENGINE=opencode`.
- Every completed Muse turn on the native engine records **truthful token usage
  and a catalog-priced cost estimate** in its retained metadata, with provenance
  strings — same honesty standard as the OpenCode path, no invented counters.
- `ai-muse doctor` (muse-code engine) **reads Meta's first-party model catalog**
  and alarms when the configured model is missing, not current, or invisible —
  so capability/pricing drift is visible the moment Meta ships it, instead of
  living in a hand-pinned config that silently rots.
- shared-db's reviewer machinery draws Muse through the native engine and its
  `REVIEWERS` evidence names the native-engine qualification.

**If any step in this plan conflicts with that goal, the goal wins — stop and
flag it.** If a step turns out wrong (paths moved, CLI behaves differently),
steer by the goal, not by the step's letter.

### 2. What this application is

`popcre/ai-devops` is Albert's public AI-workflow toolkit. `bin/ai-muse` gives
Claude and Codex named, persistent Muse Spark 1.3 Contributor conversations and
read-only governed reviews. It has **two engines** (PR #529):

- `opencode` (default today): the pinned OpenCode harness
  (`~/.local/lib/ai-devops/opencode/<version>/node_modules/opencode-ai/bin/opencode.exe`),
  model id `meta-model-api/muse-spark-1.3-contributor`.
- `muse-code` (opt-in, `AI_MUSE_ENGINE=muse-code`): Meta's native Windows CLI,
  a private hash-verified copy of
  `%LOCALAPPDATA%\Programs\muse\muse-bin-<version>.exe`
  (`config/muse-code/version` = `1.3.0-R3233.1`, SHA-256 in
  `config/muse-code/sha256`, copied to
  `~/.local/share/ai-devops/muse-code-bin/muse-<sha>.exe`; the auto-updating
  `muse` launcher is never used), model id `muse-spark-1.3-contributor`.

Consumers: interactive Claude/Codex sessions (`AI_MUSE_CALLER=claude|codex`,
e.g. the `ask-muse` skill), and `u2giants/shared-db`'s governed review
pipeline, whose preflight runs `ai-muse doctor` and expects `PASS  <check>`
lines (`scripts/run-governed-review.mjs`, `reviewerExecutionPreflight` in
`scripts/manage-migration-author-lanes.mjs`). Runs on Windows machines
(e.g. `edge-dev`) under Git Bash. No UI, no database.

Architecture doc: [`docs/muse-opencode.md`](docs/muse-opencode.md) — the
section "Muse Code engine (trial)" is this plan's starting state.

### 3. What triggered this work

Owner decision, 2026-09-17 (this planning session), preceded by an
investigation that established:

1. The native engine's only true functional deficits vs OpenCode are
   wrapper-closable (usage telemetry) or process-shaped (live qualification).
2. The OpenCode path's hand-maintained model config has already drifted: the
   2026-09-05 configuration pinned output at 65,536 tokens as "Meta's published
   maximum", while Meta's current first-party catalog lists `output_limit`
   128,000 for `muse-spark-1.3-contributor` — the OpenCode engine has been
   capping reviewer output at half of what the model allows.
3. Meta's implicit prompt caching demonstrably fires on the native path
   (measured `cache_read_tokens` 8,561 → 19,825 → 20,209 across successive turns
   of one live session on 2026-09-16), so switching does not lose caching —
   only the *explicit* OpenCode-side cache-key/retention pin, which no wrapper
   can replicate (no CLI flag exists).

### 4. Scope — in and out

**In scope** (this plan):

- Usage/cost telemetry for the muse-code engine, read from the CLI's durable
  session store after each turn.
- Doctor checks against the CLI's first-party model catalog, and a
  catalog-priced cost estimate carried in the usage JSON.
- `--reasoning-effort` exposure (`AI_MUSE_REASONING_EFFORT`).
- Deletion hygiene: `ai-muse delete` must remove the date-bucketed durable
  session log, not only the `.msp-view-v1` projection.
- Live qualification of the engine, the shared-db `REVIEWERS` evidence update,
  and the default flip (with post-flip verification).

**NOT in scope** (do not grow into these):

- Removing or degrading the OpenCode engine — it stays installed, tested, and
  selectable. Old retained sessions are engine-tagged and stay readable only
  through their own engine.
- The credential-lock wait work (`claude/muse-cred-lock-wait-20260917`) —
  another live session owns it; it is a *dependency*, not a step here.
- Any other wrapper (`ai-glm`, `ai-qwen`, `ai-gemini`, …) or the reviewer
  rotation logic in shared-db beyond the one evidence-field update.
- MSP `serve`/stdio integration, subagents, worktrees, image input, presets.
- Changing the read-only launch flags, the evidence packet, the sandbox, the
  credential boundary, or `reconcile` semantics.

---

## Part 2 — What we already know

### 5. Current state of the code

All `bin/ai-muse` line numbers are as of `origin/main` `9224759b` (2026-09-17).
Re-grep before editing; function names are the stable anchors.

- Engine selection: `bin/ai-muse:24-34` — `ENGINE="${AI_MUSE_ENGINE:-opencode}"`;
  each engine pins its `VERSION`, `BIN`, `MODEL`. The flip is one default change
  plus docs/tests (Phase D3).
- Private runtime: `runtime_env` (~:161-179) isolates XDG dirs for muse-code:
  `XDG_DATA_HOME=~/.local/share/ai-devops/muse-code`,
  `XDG_STATE_HOME=~/.local/state/ai-devops/muse-code`, etc. `require_runtime`
  (~:211-215) enforces the pinned, SHA-verified private binary copy.
- Turn execution: `run_turn` (~:381-441). muse-code args at ~:394:
  `exec --json --model "$MODEL" --session-id "$sid" --workspace <review copy>
  --disable-write --disable-shell --disable-web-tools
  --no-foreign-personal-context --user-input-auto-resolve --prompt-file <file>`.
  The wrapper chooses the session UUID; a turn answered in another session is
  rejected (~:441). Do not change these flags.
- Completion parsing: `parse_turn` (~:443-470). muse-code branch: exactly one
  session stream; `FINISH="stop"` only from a final `run.terminal.completed`
  with `payload.terminal=="completed"`; `TEXT` from that event's
  `payload.text`; **`TOKENS=null`** — the stdout stream carries no usage.
- Usage recording: `turn_usage` (~:354-363) — muse-code early-returns
  `{"scope":"turn","completeness":"unavailable","availability_reason":"engine-usage-not-reported"}`;
  the OpenCode branch shells `tools/reviewer_usage.py opencode <stdout-jsonl>`.
  `retain_turn` (~:365-380) writes `retained_turn.usage_json` into session
  metadata at retain time — **usage is post-turn metadata, never streamed**.
- Engine isolation: `require_engine_model` (~:551-553) — a stored model id
  containing `/` means opencode, bare means muse-code; sessions never cross
  engines. Keep this contract when new metadata fields are added.
- Transcript: `cmd_transcript` muse-code branch (~:557-561) runs the pinned CLI's
  `export --session <sid> --out <private tmp>` and prints the file.
- Deletion: `muse_code_delete_session` (~:562-571) removes only
  `<XDG_DATA_HOME>/muse/sessions/.msp-view-v1/<sid>` (with an
  enter-verified-parent, no-symlink discipline worth copying). **Gap C2:** the
  date-bucketed durable log (see §6a) survives deletion, including full prompt
  and response text.
- Doctor: `cmd_doctor` (~:638+). muse-code branch proves the pinned version,
  config presence, fingerprint, and prints `PASS  <check>` lines — a format
  shared-db's preflight consumes; keep it.
- Formatter: `tools/reviewer_usage.py` — argparse adapters `deepseek` and
  `opencode`. Output JSON: `{scope, counters{input, cache_read, cache_write,
  output, reasoning, total, cost}, counter_provenance, counting_semantics,
  completeness, availability_reason, adapter_cost_estimate?, cost_provenance?,
  schema_version, provider, model, runtime_version, session_id, run_id,
  observed_at}`. The `opencode` adapter refuses non-`1.18.12` versions
  (`unqualified-opencode-version`) — copy that version-gating pattern.
- Tests: `tests/test-ai-muse-code.sh` (offline; a stub bash "CLI" at a fake
  `%LOCALAPPDATA%\Programs\muse\muse-bin-$VERSION.exe` with modes
  `fail|malformed|wrongsid|mixed|nostream|noterminal|failed|completedthenfailed`;
  the stub pins its own sha256 through a private tool copy), `tests/test-ai-muse.sh`
  (both engines' shared behavior), `tests/test-muse-opencode-contract.sh`
  (OpenCode contract). All must stay green.
- Trial status: PR #529 (commit `c383cf66`) landed the engine; hardening
  followed (fingerprint, ACLs, export pinning, minimal env). Live muse-code
  sessions already exist (e.g. `claude--liveproof-0917`, 2026-09-17) — the
  engine works live; it has **not** been qualified as a shared-db reviewer.
- shared-db side: `scripts/manage-migration-author-lanes.mjs` `REVIEWERS` row
  `muse-spark-1.3-contributor` (`readsRepositoryVerified`, ~line 284 at shared-db
  `main` `14464e77`) cites the OpenCode-side identifier
  (`meta-model-api/muse-spark-1.3-contributor`, 2026-09-08, qualification via
  issue #2285). Phase D2 updates this evidence after native-engine
  qualification.
- **In-flight dependency (0A):** branch `claude/muse-cred-lock-wait-20260917`
  in worktree `C:\repos\ai-devops-wt-muse-lock-0917` has **uncommitted** changes
  to `bin/ai-muse` (`load_key`: bounded machine-wide 1Password credential-lock
  wait, `AI_MUSE_CREDENTIAL_WAIT_SECONDS`, default 120s) and
  `tests/test-ai-muse.sh` (concurrent-read tests). Another live session owns it.
  Phase A edits the same file; **do not start Phase A's wrapper edit until that
  branch lands (or the owner explicitly coordinates)**, and rebase on its
  result. Never touch that worktree.

### 6. Key findings and root cause

These cost real investigation time; none are re-derivable from the code alone.

**(a) The usage data exists — in the durable store, not on stdout.** The
muse-code `--json` stdout stream (retained examples under
`~/.local/state/ai-devops/muse/sessions/<repo>/<caller>--<name>.<event>.jsonl`)
contains only lifecycle events (`run.lifecycle.started`,
`run.model.configured`, `run.output.delta`, `task.lifecycle.*`, `tool.result`,
`runtime.command.accepted`, `session.run.linked`,
`session.workspace_branch.observed`, `run.terminal.completed`) — **zero token
counters anywhere**. But the CLI's own durable store at

```
<XDG_DATA_HOME>/muse/sessions/YYYY/MM/DD/<session-uuid>/session.jsonl
```

(e.g. `~/.local/share/ai-devops/muse-code/muse/sessions/2026/09/16/46985044-…/session.jsonl`)
records `runtime.session` events whose `.payload.event.kind=="model_completed"`
carry, per model call:

```json
{"input_tokens":19835,"output_tokens":472,"cached_tokens":8561,
 "cache_write_tokens":0,"cache_read_tokens":8561,"reasoning_tokens":387}
```

plus `.payload.event.duration_ms`, `.payload.event.finish_reason`,
`.payload.event.model`, and a `.payload.run_id`. Verified 2026-09-17 against
five live sessions on edge-dev. A separate sibling tree
`<XDG_DATA_HOME>/muse/sessions/.msp-view-v1/<uuid>/` holds only projections
(`HEAD.json`, snapshots, journal bins) — that is what deletion currently
removes.

**(b) Turn scoping key.** In the captured stdout stream,
`runtime.command.accepted` / `session.run.linked` / `run.model.configured`
carry a `command_id` equal to the `run_stream.id`, and the durable store's
`model_completed` events carry the same value as `.payload.run_id` (verified:
`598a47c8-…` matched on both sides for a liveproof turn). So the wrapper can
extract this turn's run id from the stdout it already retains and select
exactly the store's `model_completed` events for that run — no offset
bookkeeping. Multi-turn sessions append; scoping by run id is exact.

**(c) First-party model catalog.** The CLI maintains
`<XDG_DATA_HOME>/muse/model-catalog/*.json`. The current file is named
`6d657461__p746268.json` (hex `meta` + `__` + hex `tbh` — provider/profile;
**do not hardcode this name**: glob `*.json` and select rows by `model_id`).
Shape: `{profile_id, provider_id, rows[], schema_version, source}`; the
`muse-spark-1.3-contributor` row has `context_limit: 1007997`,
`output_limit: 128000`, `reasoning_effort_variants: [minimal, low, medium,
high, xhigh, max]`, `cost: {input: "0.10", output: "0.20", cached: "0.002",
currency: "USD"}` (per-million prices as strings), `is_current: true`,
`visibility: "visible"`. The 65,536-vs-128,000 drift in §3 came from here.

**(d) Caching fires natively.** Implicit prefix caching measured on live
muse-code turns (see §3.3). The explicit OpenCode cache key
(`ai-devops-muse-review`, 24h retention) has **no CLI equivalent** and cannot
be wrapper-replicated. Accepted loss; the usage counters make the native hit
rate measurable going forward.

**(e) shared-db consumes doctor output.** `PASS  <check>` lines are a
cross-repo contract (`manage-migration-author-lanes.mjs` comments at ~:2712,
~:2732 name `ai-glm, ai-muse, ai-codex-review`). New doctor checks must use
the same `PASS  `/`FAIL  ` line format.

**(f) CLI flags of interest.** `muse --help`: `--reasoning-effort
none|minimal|low|medium|high|xhigh|max|ultra` (default `high`). The catalog's
tier list for this model tops out at `max` — validate a requested tier against
the catalog when one is readable, else against the help's fixed list.

### 7. Approaches considered and REJECTED

- **Flip the default now, close gaps later.** Rejected: unqualified engine in
  the shared-db reviewer path violates its own review-evidence rules; the
  toolkit doc's policy ("the default stays opencode until the new engine has
  earned it") exists for this reason.
- **Parse usage from the stdout stream.** Rejected as impossible: no token
  fields exist there (§6a). Anything "derived" from stdout would be invented —
  forbidden by the usage-honesty rules.
- **Estimate tokens from text length.** Rejected outright: invented counters,
  same rule (`plan_reviewer-cache-efficiency.md`: "never … invent provider
  token counts").
- **Use `muse trace inspect --session-log` as the evidence reader.** Rejected:
  an extra subprocess and output format to pin, for the same data the wrapper
  can read directly from the file it already guards. Keep `trace inspect` as a
  human debugging tool only.
- **Hardcode the catalog filename, limits, or prices.** Rejected: the filename
  is a provider/profile hex encoding that can change; limits/prices are exactly
  the things that drift (§3.2). Read, report, and price from the catalog with
  provenance strings; pin nothing.
- **MSP `serve` mode for structured integration.** Rejected: re-introduces the
  daemon/server class of failure `docs/muse-opencode.md` documents ("Why there
  is no Muse service"). Direct `exec` per turn stays.
- **Enabling subagents/worktrees/presets/image input.** Rejected: review
  isolation is the product; those features are deliberately disabled and stay
  out of scope.
- **Editing the in-flight credential-lock worktree.** Rejected: live work by
  another session (§5, 0A). Wait for it to land.
- **Computing `total` as input+output for the adapter.** Rejected as an
  unproven semantic: the OpenCode adapter reports the provider's own `total`.
  The store has no `total_tokens` field. Report `total: null` with a semantics
  note unless §8's open question resolves it.

### 8. Design decisions already made

**Locked (do not relitigate):**

- Both engines stay; sessions stay engine-tagged; `require_engine_model`
  unchanged. (2026-09-17, owner direction + PR #529 design.)
- Read-only launch flags (§5) unchanged. (Trial design.)
- Usage honesty: fail closed. Any unreadable store, shape mismatch, ambiguous
  scope, or version mismatch produces `completeness:"unavailable"` with a
  specific `availability_reason` — never zeros, never guesses. (Existing
  standard, `plan_completion-honesty-enforcement.md` lineage.)
- The adapter is version-gated: it refuses to parse for any runtime version ≠
  `config/muse-code/version` (mirrors the OpenCode `1.18.12` gate).
- Usage is read once, post-turn, inside the existing retain path; no provider
  re-contact, no replay. (Retained-evidence rules.)
- Cost appears only as a labeled estimate (`catalog-priced estimate, not
  billed cost`) with provenance — mirroring `adapter_cost_estimate`.
- The default flips only after D1 (live qualification) and D2 (shared-db
  evidence) are done. (Owner's sequencing, 2026-09-17.)
- New doctor checks print `PASS  <name>` / `FAIL  <name>` lines. (Cross-repo
  contract, §6e.)
- Each phase is one PR, class `reviewer-safety`, independent read-only
  exact-head review before merge.

**Open for the implementer (with criteria):**

- *Token-field semantics.* Working assumption (mirroring OpenCode's documented
  semantics and the live samples where `input_tokens ≥ cached_tokens`):
  `input_tokens` includes cached tokens; `output_tokens` includes reasoning.
  Verify empirically on one live two-turn session before finalizing the
  adapter's `counting_semantics` string (e.g. confirm `input_tokens ≥
  cache_read_tokens` across all observed rows and that no row contradicts
  inclusion). If contradicted, re-map conservatively (report only
  unambiguous fields, mark `partial`) and record the observation in
  `docs/muse-opencode.md`.
- *Durable-log discovery.* Either reconstruct the date path from the turn's
  local date or do a bounded `find` by exact session UUID under
  `<XDG_DATA_HOME>/muse/sessions` (maxdepth 4, symlink-guarded). Implementer's
  choice; must be bounded, symlink-safe, and fail closed.
- *Catalog `is_current`/`visibility` failure mode.* Recommendation: a missing
  model row or `visibility != "visible"` is a doctor **FAIL** (the drift alarm
  is the point); `is_current: false` may be a named WARN-style line as long as
  it is loud. Implementer may refine naming, not silence it.

---

## Part 3 — How to build it

### 9. The plan — phased steps

#### Phase 0 — prerequisites

- **0A. Land/coordinate the credential-lock dependency.** Check
  `git -C C:\repos\ai-devops-wt-muse-lock-0917 status` (read-only!) and the PR
  list (`ai-gh pr list`). If landed, note the merge SHA here and rebase
  expectations. If still open/uncommitted after a reasonable wait, ask Albert
  whether to proceed on a coordinating basis. Do not edit that worktree.
  *Gate:* the branch is merged to `main` (or Albert explicitly clears Phase A
  to proceed without it).
- **0B. Start each phase fresh.** Own worktree
  (`git -C C:\repos\ai-devops fetch origin --prune && git -C C:\repos\ai-devops
  worktree add C:\repos\ai-devops-worktrees/<slug> -b claude/<slug> origin/main`),
  then `ai-task-gates start --class reviewer-safety --reason "<phase summary>"`.
  *Gate:* `ai-task-gates explain` shows the class and an empty change set.

#### Phase A — usage telemetry from the durable store (the big gap)

- **A1. Adapter.** In `tools/reviewer_usage.py`, add a `muse-code` adapter:
  - Input file: the durable `session.jsonl` (JSONL), not stdout.
  - Select events where `.payload_type=="runtime.session"` and
    `.payload.event.kind=="model_completed"` and `.payload.run_id == <run>`
    (run id passed via the existing `--run` argument).
  - Map: `input_tokens→input`, `cache_read_tokens→cache_read`,
    `cache_write_tokens→cache_write`, `output_tokens→output`,
    `reasoning_tokens→reasoning`, `total→null` (see §7/§8).
  - Coherence guard: if `cache_read > input` on any row, drop `cache_read` to
    `null` (copy the `deepseek` adapter's guard).
  - `completeness`: `core-complete` when input+output present and coherent;
    `partial` otherwise; `unavailable` + `availability_reason` (e.g.
    `durable-store-unreadable`, `no-model-completed-for-run`,
    `unqualified-muse-code-version`) on any failure.
  - Version gate: `--version` must equal the pinned
    `config/muse-code/version` else `unqualified-muse-code-version`.
  - `counter_provenance`: `muse-code-<version>-durable-store-model-completed`.
  - Intent: same truthful shape as the other adapters; a reviewer's spend is
    accountable without invented numbers.
  - *Gate:* a focused offline test (A3) proves mapping, scoping (decoy run id
    ignored), and all three unavailable paths.
- **A2. Wrapper wiring.** In `bin/ai-muse`:
  - Replace the `turn_usage` muse-code early-return (~:356) with: locate the
    durable log for the turn's `sid` (§8 open decision, fail closed), extract
    the run id from the captured stdout (`runtime.command.accepted`
    `command_id`, falling back to the first `session.run.linked`
    `run_stream.id`), invoke `python3 tools/reviewer_usage.py muse-code <log>
    --version … --provider muse --model "$MODEL" --session <sid> --run <run>`.
  - Any failure keeps today's honest behavior: print the "usage unavailable"
    stderr line, retain `unavailable` + specific reason. Never block a
    completed review on usage extraction.
  - *Gate:* `tests/test-ai-muse-code.sh` shows a stub turn whose retained
    metadata contains the mapped counters, and a garbage-store turn that still
    completes with `completeness:"unavailable"`.
- **A3. Tests.** Extend `tests/test-ai-muse-code.sh`: the stub CLI additionally
  writes a date-bucketed `session.jsonl` containing two `model_completed`
  events (different `run_id`s; realistic counters) plus a `runtime.command.accepted`
  stdout event carrying the current run id. Assert: correct counters in
  `retained_turn.usage_json`; decoy run excluded; missing store →
  `durable-store-unreadable`; malformed JSON → unavailable; turn still proves
  completion in all those cases. Add adapter-level unit coverage (new
  `tests/test-reviewer-usage-muse-code.sh` or extend the suite you find that
  already covers `reviewer_usage.py` — search `tests/` for existing coverage
  first and reuse its fixture style).
  *Gate:* the whole file passes from Git Bash on Windows.

#### Phase B — first-party catalog truth

- **B1. Doctor.** In `cmd_doctor` (muse-code branch), after the existing
  checks, read `<XDG_DATA_HOME>/muse/model-catalog/*.json` (glob; select the
  row whose `model_id` matches the configured `MODEL`). New `PASS `/`FAIL `
  checks: catalog present and parseable; model row exists; `visibility ==
  "visible"`; report `context_limit`, `output_limit`, per-million cost, and
  `is_current` in the doctor summary text (report-only values — see §8).
  *Gate:* stub-catalog tests in B3; doctor still exits 0 on a healthy stub and
  non-zero when the model row is missing.
- **B2. Catalog-priced estimate.** In the `muse-code` adapter: when the
  catalog row is readable and its `cost` parses as positive decimals, emit
  `catalog_cost_estimate` (USD, per the row's `currency`) computed from the
  summed counters, plus `cost_provenance:
  "first-party model catalog price; estimate, not billed cost"`. Catalog
  unreadable → estimate `null`, completeness unaffected.
  *Gate:* unit test prices a fixture row exactly (e.g. 19,835 input / 472
  output / 8,561 cached at $0.10/$0.20/$0.002 per M) and omits the estimate
  when the catalog is absent.
- **B3. Tests.** Stub catalog file(s) in `tests/test-ai-muse-code.sh`:
  healthy row, missing model, invisible model, unparseable file; plus the B2
  pricing fixture. *Gate:* suite green.

#### Phase C — native extras

- **C1. Reasoning effort.** In `run_turn`, when `AI_MUSE_REASONING_EFFORT` is
  set and non-empty: validate the tier (against the catalog's
  `reasoning_effort_variants` when readable, else the help's fixed list);
  refuse `start_failed` on an unknown tier **before** any provider contact;
  append `--reasoning-effort <tier>` to the muse-code args. Unset → args
  byte-identical to today (do not pass the flag; the CLI default `high`
  stands). Record the effective tier in `retained_turn` metadata. OpenCode
  engine ignores the variable (document that).
  *Gate:* stub tests capture provider args — flag present only when env set;
  unknown tier refuses with no `provider-args` file written; metadata carries
  the tier.
- **C2. Deletion hygiene.** Extend `muse_code_delete_session` to also remove
  the date-bucketed durable dir `<XDG_DATA_HOME>/muse/sessions/*/*/*/<sid>`
  using the same enter-verified-parent + no-symlink + exact-UUID discipline as
  the existing `.msp-view-v1` removal; both removals must succeed positively
  (or the error names which store survived). *Gate:* stub test creates both
  trees, deletes, asserts both gone; a symlinked durable path is refused.

#### Phase D — qualification, evidence, flip

- **D1. Live qualification.** From a real repo checkout with a real review
  brief (the pattern of #2285), run genuine muse-code turns:
  `AI_MUSE_CALLER=claude AI_MUSE_ENGINE=muse-code ai-muse new <name>
  --prompt-file <brief>` (+ an `ask` follow-up). Confirm: cited files in the
  response, final `VERDICT:` line under `REQUIRE_VERDICT=1`, usage counters
  recorded non-null, doctor catalog lines PASS. Save the evidence pointers
  (session name, report path, retained usage JSON path) in the PR/issue #542.
  *Gate:* the qualification artifacts exist and are cited; no
  `engine-usage-not-reported` in the qualified turns.
- **D2. shared-db evidence.** In a shared-db worktree (its §2.1-W rule), one
  scripts/docs-only PR updating the `muse-spark-1.3-contributor` row's
  `readsRepositoryVerified` to cite the native-engine qualification (date,
  evidence string naming `ai-muse` muse-code engine, the qualification
  artifacts). No reviewer-rotation logic changes. Merge promptly per its
  docs-only §5 rule. *Gate:* PR merged; `node scripts/manage-migration-author-lanes.mjs
  --queue-audit` still exits clean.
- **D3. Flip.** In ai-devops: change `bin/ai-muse:24` default to `muse-code`;
  flip the `default engine stays OpenCode` test expectation in
  `tests/test-ai-muse-code.sh` to `engine: muse-code`; rewrite
  `docs/muse-opencode.md`'s trial section into the native-engine section of
  record (decision + date + rollback: `AI_MUSE_ENGINE=opencode`); update the
  task-router row (§Registration). *Gate:* full offline suites green; doctor
  on a machine without the native binary fails closed with the existing
  `local_dependency_unavailable` message naming the fix.
- **D4. Post-flip verification.** Watch one real governed shared-db review
  round that draws Muse: reviewer assigned, preflight doctor PASS, verdict
  recorded with coverage, usage present. *Gate:* the review event's evidence
  (assignment ref + verdict) cited in #542; then close #542, update this
  STATUS table, and retire the handoff file.

**Cut points:** 0→A, A→B, B→C, C→D are each natural fresh-session boundaries
(different files/risk profiles). Phases A, B, C are independent enough to
serialize in order; D strictly last.

### 10. Tests required

New (named) — see steps A3, B3, C1, C2 for full behavior lists:

- `tests/test-ai-muse-code.sh` extensions: durable-store usage (correct,
  scoped, unavailable-on-garbage/missing), catalog doctor checks, catalog
  pricing fixture, reasoning-effort args/refusal/metadata, dual-store deletion
  + symlink refusal, flipped default expectation (at D3).
- Adapter unit tests: `tests/test-reviewer-usage-muse-code.sh` (or the
  existing `reviewer_usage.py` coverage file you find in `tests/` — reuse its
  fixture style and name the choice in the PR).

Existing suites that must stay green on every phase PR (Git Bash, Windows):

- `tests/test-ai-muse.sh` (both engines' shared behavior, incl. the in-flight
  credential-lock tests once 0A lands)
- `tests/test-ai-muse-code.sh` (pre-existing cases untouched)
- `tests/test-muse-opencode-contract.sh` (OpenCode contract — must not move)
- The repo's full offline suite per [`docs/development.md`](docs/development.md),
  after `bin/ai-test-local --check-collision` proves no overlap with a remote
  job on the same host.

### 11. Constraints, standing rules, and gotchas

- **Repo contract** (AGENTS.md): branch + PR, never push `main`, merge queue;
  commit ident must read `Albert Hazan <u2giants@users.noreply.github.com>`
  (`git var GIT_COMMITTER_IDENT`); canonical checkout is landing-only — work
  in your own current-upstream worktree; stage only task-owned files.
- **Reviewer-safety path:** every phase PR (A–D3) declares
  `ai-task-gates start --class reviewer-safety` and gets **one independent
  read-only exact-head final review before merge**. A verdict with no coverage
  statement is not review evidence.
- **GitHub discipline:** all calls through `bin/ai-gh`; waits through
  `bin/ai-pr-wait` / `bin/ai-gh-wait`; never `gh run watch`, never open-ended
  sleep loops; at most one GitHub call per 5 minutes per waiter.
- **Public repo:** never commit raw transcripts, private `.jsonl` stores,
  licensed data, or secrets. The usage counters and prices quoted in this plan
  are aggregate numbers without content and are safe. Key location only: the
  wrapper reads 1Password vault `vibe_coding`, item "Meta ai Muse Spark API
  Key", field "api key" — never print or commit it.
- **Windows:** run Bash tests through Git Bash; PowerShell-facing launchers
  (`.cmd`) must keep working if `bin/` gains files (none planned).
- **Fail-closed everywhere:** unknown engine, unpinned version, missing
  private binary, shape-mismatched store, unreadable catalog — each refuses or
  degrades to an explicit `unavailable` with a reason. No silent fallbacks, no
  best-effort zeros.
- **Do not change:** read-only launch flags; evidence packet/sandbox/reconcile
  semantics; `PASS  <check>` doctor line format; `require_engine_model`
  engine-tagging; the OpenCode engine's behavior and tests.
- **Conflict guard:** `bin/ai-muse` is hot — rebase each phase on the then-
  current `origin/main` and re-run the full muse suites before requesting
  review.
- **shared-db (Phase D2 only):** its AGENTS.md §2.1-W worktree rule, branch +
  PR, docs/scripts-only fast-path merge; no `db-work` issue needed for a
  scripts+docs PR that changes no schema — but if in doubt, follow that repo's
  own gate tooling (`ai-task-gates explain` there) rather than guessing.

### 12. Access and environment

- Machine: Windows (`edge-dev`), Git Bash, `jq` and `python3` on PATH.
- Pinned native binary source: `%LOCALAPPDATA%\Programs\muse\muse-bin-1.3.0-R3233.1.exe`;
  pin files: `config/muse-code/version`, `config/muse-code/sha256`. Wrapper
  runs a private verified copy under `~/.local/share/ai-devops/muse-code-bin/`.
- Private stores (muse-code engine): data
  `~/.local/share/ai-devops/muse-code/muse` (sessions + model-catalog), state
  `~/.local/state/ai-devops/muse-code`, config
  `~/.config/ai-devops-muse/muse-code-xdg`. Wrapper session metadata:
  `~/.local/state/ai-devops/muse/sessions/<repo>/<caller>--<name>.json`.
- Live captured muse-code turn streams for shape reference (read-only, private):
  `~/.local/state/ai-devops/muse/sessions/…/claude--liveproof-0917.*.jsonl`;
  durable-store samples under
  `~/.local/share/ai-devops/muse-code/muse/sessions/2026/09/16/`.
- Run a manual native-engine turn (real key, real cost — keep prompts small):
  `AI_MUSE_CALLER=claude AI_MUSE_ENGINE=muse-code ai-muse doctor`, then
  `AI_MUSE_CALLER=claude AI_MUSE_ENGINE=muse-code ai-muse new <name>
  --prompt "…"`. `reconcile`, `transcript`, `delete` as documented in
  `docs/muse-opencode.md`.
- Run the tests: `bash tests/test-ai-muse-code.sh` from the worktree root (the
  suite builds its own fake home/stub; no provider or 1Password contact).
- shared-db (D2): clone/worktree of `u2giants/shared-db`; target file
  `scripts/manage-migration-author-lanes.mjs` (`REVIEWERS` array).

---

## Part 4 — Landing it

### 13. Definition of done + risks and open questions

**Done when:**

- Phases A–C merged (each: branch → PR → reviewer-safety class → independent
  exact-head review → merge queue → verified on `origin/main`), all muse suites
  green on the landed SHAs.
- D1 qualification artifacts cited in #542; D2 shared-db PR merged and its
  queue audit clean; D3 flip landed with docs; D4 live governed review verified.
- This STATUS table fully done with artifact citations; #542 closed; the
  `HANDOFF.d/` file for this plan retired; `docs/task-router.md` row updated.

**Risks and rollback:**

- *Durable-store / catalog formats are internal to the pinned build.* A CLI
  version bump can change both. Mitigation: version-gated adapter, fail-closed
  wrapper, stub-pinned tests; on a pinned-version update, re-capture a live
  store sample and extend fixtures before trusting.
- *Token semantics mis-mapping.* Mitigation: §8 empirical check + coherence
  guards + provenance strings; worst case fields degrade to `null`, never lie.
- *Collisions on `bin/ai-muse`* (hot file; in-flight 0A branch). Mitigation:
  serialize phases, rebase, full suite rerun before review.
- *Meta's installer auto-update swapping the binary.* Already mitigated: the
  wrapper only ever runs the SHA-verified private copy; unchanged by this plan.
- *Flip fallout.* Rollback: `AI_MUSE_ENGINE=opencode` restores the old engine
  per invocation immediately; revert the D3 commit to restore the default.
  Engine-tagged sessions mean nothing is stranded either way.
- *Merge-queue serialization delays.* Ordinary; use `ai-pr-wait` and do useful
  work between checks.

**Genuinely open:** exact inclusion semantics of `input_tokens`/
`output_tokens` (§8, resolved empirically in A1); whether Meta exposes an
explicit cache-control surface on the native CLI in the future (if it appears,
a follow-up plan can pin cache keys — do not stuff it into this one).

---

## Registration

- Tracking issue: [#542](https://github.com/popcre/ai-devops/issues/542).
- Handoff: [`HANDOFF.d/2026-09-17T1416Z-edge-dev-claude-muse-native-parity-plan.md`](HANDOFF.d/2026-09-17T1416Z-edge-dev-claude-muse-native-parity-plan.md).
- Router row added to [`docs/task-router.md`](docs/task-router.md) (same PR as this plan).
- Operational memory belongs in the **private** hub (`u2giants/ai-devops-memory`),
  never this public tree — a fact pointing here may be unioned there by its own
  qualified process; nothing to commit in this repo.

## Self-audit (mandatory gate — preserved)

1. *Could a brand-new session execute this without asking anything?* Yes —
   §5 pins exact state incl. the in-flight dependency; §6 carries the store
   layouts, event shapes, sample values, scoping key, catalog shape and drift
   evidence; §9 names files/functions/args per step with gates; §12 gives
   paths, commands, and key location; §11 states the repo's delivery and
   review rules a newcomer cannot assume.
2. *Does it carry all background and rejections?* Yes — §3 (trigger + drift),
   §6 (all investigation findings a–f), §7 (nine rejected approaches with
   reasons), §8 (locked vs open with criteria).
3. *Is the goal clear enough to steer by when a step is wrong?* Yes — §1
   states the end state in plain terms and the "goal wins — stop and flag"
   rule; §4 fences scope.
