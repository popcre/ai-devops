# How one plumbing covers native harnesses and OpenCode

**Parent issue:** [#1110](https://github.com/popcre/ai-devops/issues/1110) · **Child:** [#1114](https://github.com/popcre/ai-devops/issues/1114)  
**Audience:** Albert (plain English first), then implementers.

---

## The short answer

Today every reviewer is a full program: it books the job, locks files, copies the tree, calls the model, writes the report, deletes evidence. That whole pile is copy-pasted — **that** is what breaks every 24–48 hours.

Tomorrow there is **one** booking office (the runner). Each model only has a **door** (an adapter). Whether the door talks to a native CLI or to OpenCode, the office still does the booking, the proof, and the cleanup.

```
                    ┌─────────────────────────────┐
                    │   ONE REVIEW RUNNER         │
                    │  identity · locks · packet  │
                    │  lifecycle · report floor   │
                    │  store proof THEN delete    │
                    └─────────────┬───────────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              ▼                   ▼                   ▼
        native door         native door          OpenCode door
        Claude / Codex      Grok · Qwen          GLM · Muse
        (their own CLI)     StepCode (Linux)     DeepSeek · StepFun*
```

\*StepFun is native StepCode on Ubuntu; on Windows it goes through OpenCode (see #1114).

**Same office. Different doors. One evidence pipeline.**

---

## What is a “harness”?

The harness is the program that actually runs the model session and its tools (read file, edit file, run command).

| Kind | Who | How we call it today |
|---|---|---|
| **Native harness** | Claude Code, Codex CLI, Grok Build, Qwen Code, StepCode | Wrapper execs that vendor CLI with pinned model, flags, and permissions |
| **OpenCode harness** | GLM, Muse, DeepSeek, and StepFun-on-Windows | Wrapper points at one pinned OpenCode binary plus a **profile** (`config/opencode-*/opencode.json` + `agent/*.md`) that pins model, tools, and protections |

Muse is special: default engine is Muse Code CLI; `AI_MUSE_ENGINE=opencode` rolls it onto OpenCode. Sessions never cross engines.

---

## What must live in the **one** runner (not in doors)

These are the pieces that are copy-pasted and keep breaking:

1. **Task gate** — is this review allowed for this change set?  
2. **Identity** — what exact tree is under review (head, base, digest)?  
3. **Sandbox** — disposable snapshot so the model cannot dirty the live repo.  
4. **Evidence packet** — sealed manifest + patch + identity + hash.  
5. **Durable store** — copy the **whole** packet, then delete the working copy.  
6. **Lifecycle** — begin → observe → terminal (`APPROVE|REVISE|REJECT|BLOCKED` + failure class).  
7. **Report floor** — a real suggestion report, not a bare “PASS” (`MIN_REPORT_CHARS`).  
8. **Cleanup order** — store first; only then remove sandbox/packet.

Grok’s door and StepFun’s door must both end up with the same packet format and the same lifecycle row.

## What stays in the **door** (adapter)

Only “how we talk to this model”:

- Which binary: `claude`, `codex`, `grok`, `qwen`, `step`, or `opencode` + which profile dir.  
- Credentials and model pin (never the runner’s job to invent).  
- Provider-specific tool list (read-only vs write).  
- Parsing that provider’s answer into **our** report shape.  
- **Implement mode** extras that are truly provider-specific (worktree style, recovery notes) — but still **called by** the runner so evidence and locks are not forked.

---

## Why this is not “a library wrappers may call”

We already tried that. `ai-review-lifecycle` exists; Muse, Gemini, Qwen, DeepSeek, and StepFun never call it. A shared file on disk is not a forcing function.

The runner must be **the only door**:

- `ai-review-pool` / preflight **refuse** a review that did not go through the runner.  
- Merge/gates accept **only** runner-produced records.  
- New provider = new door file + registration, not a new copy of the office.

That is the structural change that ends the 24–48h loop along with #1112 (keep last good approval).

---

## Review vs implement (two contracts, one office)

| | Review | Implement |
|---|---|---|
| Output | Suggestion report + packet | Patch / worktree + packet |
| Tools | Read/search (or read-only policy) | Write tools per owner ruling |
| Isolation | Snapshot, no writes | New remote-less worktree |
| Failure | Report quality / stale source | Preserve worktree for recovery |

Doors do not each invent their own locks and deletes. The runner owns both contracts; the door only supplies the provider-specific bits.

---

## Order of work (linked to issues)

1. **#1111** Keep full evidence in the shared delete path (no fingerprint move).  
2. **#1112** Keep last good approval until a new check passes — **this is the 24–48h fix**.  
3. **#1114** Collapse native + OpenCode doors onto one runner (this document).  
4. **#1115** Outage vs code labels.

Nothing in 3 starts until 1 lands; 2 can follow 1 closely because it is still in preflight/qualification code, not in every door.

---

## One code path for every reviewer (#1834)

**Rule.** In the shared review layers, provider-specific **policy data**
(timeouts, budgets, routes, platform guards, identity formats, wrapper paths)
is allowed. A **behaviour gate** — code that decides whether an evidence,
receipt, record, cleanup or qualification step happens at all — applies to
every provider unless a named capability in `config/review-runner-doors.json`
(`.capabilities.<provider>.<field>`) declares the exception. Shared code reads
it only through `tools/lib/review-capabilities.sh` (`review_capability`). An
absent field means the common path. The runner brief adds this rule whenever a
change touches these paths, so reviewers check every maintained provider.

Capability fields: `attachment_only_code_review` (deepseek),
`empty_verdict_exit_81` and `leading_verdict_contract` (gemini),
`pool_session_release` (muse), `receipt_source_root` (glm),
`credit_watch_refresh` (gemini, deepseek, glm, stepfun), `offline_doctor_probe`
(claude, codex, deepseek, stepfun, muse), `live_qualification_required`
(gemini, qwen), `no_live_doctor` (glm), `borrowed_user_binary_rebind` (kimi).

Full inventory (line numbers are `origin/main` at e534a530, before this change).
"Gate → field" rows now read the named capability; behaviour for current
providers is unchanged.

| # | Site | Branch | Class | Now |
|---|---|---|---|---|
| 1 | `bin/ai-review:38-54` | `claude)` wrapper + registry-state refusal | Policy data (route; the registry already decides) | unchanged |
| 2 | `bin/ai-review:55` | `codex)` wrapper | Policy data (route) | unchanged |
| 3 | `bin/ai-review:56-58` | `deepseek)` wrapper + test-hook guard | Policy data (route) | unchanged |
| 4 | `bin/ai-review:158-181` | ordinary DeepSeek review sent to the pool | Behaviour gate — product invariant: the attachment-only DeepSeek route | `attachment_only_code_review` |
| 5 | `bin/ai-review:232-240` | `--code-only` requires DeepSeek; registry check | Behaviour gate — same attachment-only invariant | `attachment_only_code_review` |
| 6 | `bin/ai-review-lifecycle:303-311` | code-only lifecycle requires DeepSeek; implementer independence | Behaviour gate — same attachment-only invariant (Muse plan note) | `attachment_only_code_review` |
| 7 | `bin/ai-review-pool:56-63` | session runner and `--max-turns` budget per provider | Policy data (route, budget) | unchanged |
| 8 | `bin/ai-review-pool:273-279` | `AI_POOL_RUNNER_<P>` test override per provider | Policy data (test route) | unchanged |
| 9 | `bin/ai-review-pool:511-524` | GLM formal-review profile and pinned runner, Linux only | Policy data (route, platform guard) | unchanged |
| 10 | `bin/ai-review-pool:525` | GLM gets `AI_REVIEW_SOURCE_ROOT` for the governed receipt | Behaviour gate (receipt) | `receipt_source_root` |
| 11 | `bin/ai-review-pool:527` | `AI_GROK_WAIT_TIMEOUT`, `AI_GEMINI_BODY_STDOUT` env for every runner | Policy data (applied to all) | unchanged |
| 12 | `bin/ai-review-pool:550` | exit 81 + marker = empty verdict, Gemini only | Behaviour gate (record class) | `empty_verdict_exit_81` |
| 13 | `bin/ai-review-pool:577-596` | first `## Verdict` counts; contradictory verdicts refused | Behaviour gate (verdict record) | `leading_verdict_contract` |
| 14 | `bin/ai-review-pool:620` | analysis window after a leading verdict | Behaviour gate (report floor) | `leading_verdict_contract` |
| 15 | `bin/ai-review-pool:707-736` | session release after a durable review, Muse only | Behaviour gate (cleanup) | `pool_session_release` |
| 16 | `bin/ai-review-engine` | none | — | no provider branch |
| 17 | `bin/ai-review-packet` | none | — | no provider branch |
| 18 | `bin/ai-review-sandbox` | none | — | no provider branch |
| 19 | `tools/lib/review-lifecycle-core.sh` | none (fixed generically by PR1826) | — | no provider branch |
| 20 | `bin/ai-review-preflight:60` | `valid_provider` list | Policy data (provider set) | unchanged |
| 21 | `bin/ai-review-preflight:78-110` | Kimi credential-profile resolution in admission | Policy data (credential route) | unchanged |
| 22 | `bin/ai-review-preflight:227` | qualification record schema 2/3/1 | Policy data (schema numbers) | unchanged |
| 23 | `bin/ai-review-preflight:289-345` | `gemini_live_qualified`, `qwen_live_qualified` | Policy data (provider implementation, now dispatched by capability) | unchanged |
| 24 | `bin/ai-review-preflight:402` | due credit-watch refresh for gemini, deepseek, glm, stepfun | Behaviour gate (record refresh) | `credit_watch_refresh` |
| 25 | `bin/ai-review-preflight:439-446` | StepFun on Windows needs OpenCode | Policy data (platform guard) | unchanged |
| 26 | `bin/ai-review-preflight:458` | offline doctor for claude, codex, deepseek, stepfun, muse | Behaviour gate (health step) | `offline_doctor_probe` |
| 27 | `bin/ai-review-preflight:463-467` | Muse doctor env and timeout; StepFun `--read-only` | Policy data (timeout, args) | unchanged |
| 28 | `bin/ai-review-preflight:476-483` | Grok offline runtime resolution | Policy data (provider dependency probe) | unchanged |
| 29 | `bin/ai-review-preflight:486-494` | DeepSeek OpenCode resolution | Policy data (provider dependency probe) | unchanged |
| 30 | `bin/ai-review-preflight:521-522` | static quarantine until live-qualified, gemini/qwen | Behaviour gate (qualification) | `live_qualification_required` |
| 31 | `bin/ai-review-preflight:525-530` | StepFun platform support | Policy data (platform guard) | unchanged |
| 32 | `bin/ai-review-preflight:669-678` | `provider_wrapper` paths | Policy data (route) | unchanged |
| 33 | `bin/ai-review-preflight:682-735` | `qualify_qwen`, `qualify_gemini` | Policy data (provider implementation) | unchanged |
| 34 | `bin/ai-review-preflight:741` | `LIVE_QUALIFIED_PROVIDERS="gemini qwen"` | Behaviour gate (qualification set) | derived from `live_qualification_required` |
| 35 | `bin/ai-review-preflight:747` | Gemini caller env on `doctor --identity` | Policy data (env) | unchanged |
| 36 | `bin/ai-review-preflight:754-757` | identity line formats | Policy data (identity format) | unchanged |
| 37 | `bin/ai-review-preflight:766` | reset requalification only for gemini/qwen | Behaviour gate (qualification) | `live_qualification_required` |
| 38 | `bin/ai-review-preflight:781` | keep a current qualification | Behaviour gate (qualification) | capability dispatch |
| 39 | `bin/ai-review-preflight:874-877` | requalify stale check | Behaviour gate (qualification) | `live_qualification_required` |
| 40 | `bin/ai-review-preflight:886` | requalify dispatch | Behaviour gate (qualification) | capability dispatch |
| 41 | `bin/ai-review-preflight:1014` | GLM credit hold never probed live | Behaviour gate (probe) | `no_live_doctor` |
| 42 | `bin/ai-review-preflight:1024` | GLM capacity hold never probed live | Behaviour gate (probe) | `no_live_doctor` |
| 43 | `bin/ai-review-preflight:1054` | static refusal exit 3 for gemini/qwen, else 4 | Behaviour gate (record class) | `live_qualification_required` |
| 44 | `bin/ai-review-preflight:1057-1069` | StepFun Windows engine miss | Policy data (platform guard) | unchanged |
| 45 | `bin/ai-review-preflight:1076-1083,1107-1109` | Muse doctor budgets | Policy data (timeout) | unchanged |
| 46 | `bin/ai-review-preflight:1084,1110` | GLM skips `doctor --live` | Behaviour gate (probe) | `no_live_doctor` |
| 47 | `bin/ai-review-preflight:1085-1088,1111-1113` | Gemini and StepFun live budgets | Policy data (timeout) | unchanged |
| 48 | `bin/ai-review-preflight:1162` | PASS `allowance=` label for GLM | Behaviour gate (record) | `no_live_doctor` |
| 49 | `bin/ai-review-preflight:1179-1230` | `provider_cli_binary` per provider | Policy data (route) | unchanged |
| 50 | `bin/ai-review-preflight:1260-1263` | pin-bump lane refused for gemini/qwen | Behaviour gate (qualification) | `live_qualification_required` |
| 51 | `bin/ai-review-preflight:1454-1478` | Kimi borrowed-user binary re-hash before the smoke | Behaviour gate (evidence binding) | `borrowed_user_binary_rebind` |
| 52 | `bin/ai-review-preflight:1482-1490` | pin-bump live smoke budgets | Policy data (timeout) | unchanged |
| 53 | `bin/ai-review-preflight:1629` | `effective-profile` takes only kimi | Policy data (CLI contract) | unchanged |
| 54 | `bin/ai-review-preflight:1707` | `qualify` CLI takes gemini/qwen | Behaviour gate (qualification) | `live_qualification_required` |
| 55 | `bin/ai-review-preflight:1730,1735` | default `status`/`usable` provider list | Policy data (default listing) | unchanged |
