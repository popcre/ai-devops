# IMPLEMENTATION PLAN — StepFun harness token efficiency (2026-10-06)

Companion handoff: [`HANDOFF.d/2026-10-06T0824Z-edge-dev-mimo-stepfun-harness-efficiency.md`](HANDOFF.d/2026-10-06T0824Z-edge-dev-mimo-stepfun-harness-efficiency.md)
(That handoff links back here. Root `HANDOFF.md` stays the static pointer.)

## STATUS

| Step | State | Evidence (artifact, never a bare number) |
|---|---|---|
| P1.1 rate_limited provider-only | ✅ done | `951d55dc`; `bash tests/test-ai-stepfun.sh`: 72 passed, 0 failed, 2 platform skips |
| P1.2 retry only on failure | ✅ done | `951d55dc`; successful verdict with stderr 429 retained by the same suite |
| P1.3 false-positive guard test | ✅ done | `951d55dc`; provider-channel, JSONL-text, and non-rate failure cases in `tests/test-ai-stepfun.sh` |
| P2.1 drop duplicated VERDICT preamble (OpenCode) | ✅ done | `9f3db3d4`; semantic prompt tests: 77 passed, 0 failed, 2 platform skips |
| P2.2 move unique `$rel`/`$head` to prompt end | ✅ done | `9f3db3d4`; stable-prefix assertion in `tests/test-ai-stepfun.sh` |
| P2.3 dead compaction cleanup or comment | ✅ done | `9f3db3d4`; `jq empty config/opencode-stepfun/opencode.json` passed |
| P3.1 Windows gate: `grep`/`head -n` | ✅ done | `2e50a4c7`; hash-pinned grep, bounded search and slices; Windows-shell suite 52 passed, 0 failed |
| P3.2 Windows agent tools / docs | ✅ done | `2e50a4c7`; Windows agent and live documentation match gate grammar |
| P3.3 path-clamp adversarial tests | ✅ done | `2e50a4c7`; `tests/test-ai-stepfun-windows-shell.sh`: 52 passed, 0 failed |
| P4.1 resume session on 429 retry | ⏭ skipped — security criterion unmet | `6b4375e5`; engine session files live in model-writable per-turn state deleted after each turn; saved ID alone cannot resume without retaining that state |
| P4.2 optional warm cache dir (security judgment) | ⏭ skipped — security criterion unmet | `6b4375e5`; cross-review leakage analysis in `docs/config-inventory.md` and fake-engine isolation test in `tests/test-ai-stepfun.sh` |
| P5.1 record cache/session counters | ✅ done | `b07d79fb`; fixture test and owner-only sidecar; StepFun suite 80 passed, 0 failed, 2 platform skips |
| P5.2 live proof on both platforms | ⬜ open | Linux `bin/ai-stepfun doctor --live`: `OK engine=stepcode model=step/step-5-preview live=verified`; Windows live provider proof and post-merge confirmation pending on [landing issue #1336](https://github.com/popcre/ai-devops/issues/1336) |

**Muse review (2026-10-06):** `VERDICT: REVISE plan` —
`.ai/reviews/muse-stepfun-token-efficiency-plan-r2-20261006T124204Z-968393-5381.md`
(session `stepfun-token-efficiency-plan-r2`). Six must-fix items folded in
below (P1.1/1.2/2.1/3.1/4). Do not reopen B1–B3.

**GLM 5.3 review (2026-10-06):** `VERDICT: REVISE plan` —
`.ai/reviews/glm-stepfun-token-efficiency-plan-review-ec1b178ec9de9d8716c24d5484644b6f534d3a9419e849d75c63f21b8b86c711.md`
(session `stepfun-token-efficiency-plan-review`). Confirmed Muse B1–B3/M1–M3
closed. F1 (stderr must keep bare `429`, case-insensitive) and F2 (`detect_engine`
before `$full`) folded into P1.1 and P2.1. F3 advisory rows folded into P1.3/P3.3.

*File rename note:* this plan was first written as `plan_stepfun-token-efficiency.md`
but `.gitignore` `**/*token*` hid it from reviewer snapshots. Renamed to
`plan_stepfun-harness-efficiency.md` so it is reviewable and committable.

**Where a fresh session starts:** Phase 1 (P1.1). Re-read Phases 2–5 before starting each later phase (drift check). Nothing is implemented yet; this plan is the only written design.

---

## 1. The ultimate goal — what we are trying to achieve

StepFun reviews and second opinions should spend tokens on the actual code
under review, not on rebuilding context or re-sending the same words.

When this is done:

- A finished StepFun review is never thrown away and re-bought just because its
  text mentioned a rate-limit word.
- Rate-limit retries do not pay for a full cold turn when a cheaper resume is
  possible.
- The model finds code with search and slices instead of whole-file dumps
  (especially on Windows).
- The same instructions are not paid for twice in one turn.
- We can measure cache hits instead of guessing.

If any step below conflicts with this goal, the goal wins — stop and flag it.

## 2. What this application is

`popcre/ai-devops` — Albert's public multi-model AI workflow recovery toolkit
(not an app or service). This work changes the **StepFun reviewer harness**: the
`ai-stepfun` wrapper and its OpenCode/StepCode profiles that the shared-db
allocator and `stepfun` skill use for formal reviews, second opinions, and
Linux implementation runs.

- Repo: `popcre/ai-devops`, canonical checkout `C:\repos\ai-devops` (landing-only).
- Every write-capable task uses its own current-upstream worktree; never edit
  the landing checkout except for serialized landing.
- Default branch policy: feature branch → PR → merge queue. Never push `main`.
- Stack: Bash + PowerShell-compatible wrappers, OpenCode (pinned 1.18.12) and
  StepCode (`step`) CLIs, bubblewrap on Linux, Windows folder + gated test shell.
- Hosts: `edge-dev` (Windows) and Ubuntu runners/hosts where StepCode is installed.

## 3. What triggered this work

Owner request (MiMo chat, 2026-10-06): after two read-only audits (Windows
harness + Linux harness) of StepFun token use — persistent sessions, maximum
caching, and no duplicate resends — write a plan to fix every finding. No
implementation was authorized in that request beyond writing the plan and
running it by Muse.

Reproduce the current waste without live paid calls:

- False-positive retry: `tests/test-ai-stepfun.sh` has a genuine-429 case
  (`:139`) but **no** case that a successful review quoting "429" is kept.
- Windows whole-file reads: `bin/ai-stepfun-windows-shell:256-261` refuses
  `head -n` as "extra args"; `config/opencode-stepfun/agent/stepfun-review-windows.md:7-14`
  disables `read/glob/grep/list/find`.
- Cold sessions: `bin/ai-stepfun:405` runs StepCode with `--no-session`; OpenCode
  gets a fresh XDG tree (`:210-219`, `:240`, `:344`) deleted after the turn.

## 4. Scope — in and out

**In scope**

- `bin/ai-stepfun` retry/detection, prompt assembly, session flags, logging.
- `bin/ai-stepfun-windows-shell` command grammar (search/slice verbs only).
- `config/opencode-stepfun/opencode.json` and agent profiles
  (`stepfun-review.md`, `stepfun-review-windows.md`; implement profiles only if
  a change is shared).
- Tests: `tests/test-ai-stepfun.sh`, `tests/test-ai-stepfun-windows-shell.sh`.
- Matching docs: `docs/config-inventory.md` StepFun row, `skills/shared/stepfun/SKILL.md`,
  `docs/reviewer-rotation-rules.md` StepFun row if behavior changes, this plan's STATUS.
- Measurement of cache/session counters (offline fixtures + optional live doctor).

**NOT in this plan**

- Changing StepFun model pin, pricing, credits, or the allocator membership row.
- GLM / Muse / DeepSeek / Grok / Qwen wrappers (except as read-only reference).
- `bin/ai-review-packet` packet format or seal rules (keep injecting by reference).
- Windows mount isolation or bubblewrap on Windows (owner-accepted residual,
  `docs/reviewer-rotation-rules.md` rule 12 area).
- Provider API changes, new MCP servers, or 1Password changes.
- Implementing `implement` on Windows (still refused by design).
- Live paid StepFun traffic beyond the optional Phase 5 doctor measurement.

## 5. Current state of the code

All of this is **committed on the current upstream of `main`** as of the audit
(2026-10-06). No fix work has been started. The landing checkout is
landing-only; implement in a dedicated worktree.

| Area | State | Exact refs |
|---|---|---|
| Retry / rate detect | Works, **wrong trigger** | `bin/ai-stepfun:176-193` (`rate_limited`, `run_step_retry`) |
| Credit detect (correct pattern) | Works | `bin/ai-stepfun:439-448` (`credit_stop`) |
| StepCode turn | Sessionless | `bin/ai-stepfun:405` (`step -p --no-session`), comment `:357` |
| OpenCode per-run tree | Fresh + deleted | `bin/ai-stepfun:210-219`, `:240`, `:303`, `:344` |
| Review prompt | Duplicates agent VERDICT text; unique `$rel` early | `bin/ai-stepfun:600-607`; `config/opencode-stepfun/agent/stepfun-review.md:38-42` |
| Windows review tools | Only `bash` + shell | `config/opencode-stepfun/agent/stepfun-review-windows.md:5-17` |
| Windows shell grammar | `ls\|cat\|head` one path, no flags | `bin/ai-stepfun-windows-shell:256-261` |
| OpenCode config | No cache keys; inert `compaction` | `config/opencode-stepfun/opencode.json:7-12`, `:17-19` |
| Packet injection | By reference (`MANIFEST.md`) — keep | `bin/ai-stepfun:600-601` |
| Tests | Genuine 429 covered; false-positive **not** covered | `tests/test-ai-stepfun.sh:139`, `:212` (wipe assert) |

## 6. Key findings and root cause

From two read-only audits (Windows `explore-1`, Linux `explore-2`, 2026-10-06).

1. **HIGH — False-positive rate-limit retry re-buys whole turns.**  
   `rate_limited()` greps the *entire assistant output* for bare
   `429|rate_limited|Too Many Requests` (`bin/ai-stepfun:184`). `run_step_retry`
   re-runs when that matches **even if `rc=0`** (`:188-189`), up to
   `RATE_RETRIES=2` (`:180`) after `RATE_PAUSE=65s`. A successful review that
   merely quotes "429" is discarded and re-sent. `credit_stop` already does this
   correctly (provider channels only: stderr + `^4[0-9][0-9]: {` on stdout,
   `:439-448`).

2. **HIGH (Windows) — exploration is whole-file `cat` only.**  
   Gate allows `ls|cat|head` with exactly one path and no flags
   (`ai-stepfun-windows-shell:256-261`); `head -n N` is refused as "extra args".
   Agent disables `read/glob/grep/list/find` (`stepfun-review-windows.md:7-14`).
   Finding a symbol forces full-file tokens.

3. **MED — retries and every wrapper turn are cold.**  
   No `--session`/`--continue`/`--resume`. StepCode: `--no-session` (`:405`).
   OpenCode: fresh XDG per turn, deleted after (`:240`, `:303`, `:344`);
   `sessionID` is never captured (`:306` extracts only `type=="text"`).
   Contrast: `bin/ai-deepseek:129,135` persists `--session`; `bin/ai-muse:794`
   resumes exact sessions.

4. **MED — no provider cache configuration; prefix cache can be broken.**  
   `config/opencode-stepfun/opencode.json` has only `baseURL`/`apiKey`
   (`:17-19`). Review prompt embeds per-run unique `$rel` early (`:601`) and
   `$head` in the verdict template (`:605-607`), weakening any cross-run prefix
   reuse. StepFun Linux uses only `config/opencode-stepfun/`, not GLM's
   `config/opencode/`.

5. **MED/LOW — duplicated instructions.**  
   Review `$full` preamble (`:600-607`) nearly verbatim repeats
   `stepfun-review.md:29-42` (and the Windows profile `:20-38`), including
   VERDICT format twice (~150–200 tokens/review).

6. **LOW — dead `compaction` block** in `opencode.json:7-12` for single-shot
   runs (Muse tuning copied in; inert).

**Already efficient — do not "fix"**

- One model turn per invocation; no parallel fan-out; no conversation history
  re-send across `review`/`ask`/`implement` (`:610`, `:643`).
- Sealed packet injected **by reference**, never inlined (`:601`).
- Short static agent profiles; Windows omits 8 tool schemas.
- `--no-extensions --no-skills --no-prompt-templates --no-themes` on StepCode
  (`:407`).
- `credit_stop` correctly ignores assistant content (`:439-448`).
- Implement is never blindly retried (`:179`).
- Identity-keyed `REVIEW_TAG` reuses sandbox copies (`:585`).
- Host-side digest checks are free in tokens (`:613-615`).

## 7. Approaches considered and REJECTED, and why

| Approach | Why rejected |
|---|---|
| Inline the whole review packet / diff into the prompt | Already avoided on purpose; seals stay authoritative; packet-by-reference is cheaper and safer. Do not regress. |
| Remove bubblewrap / stop wiping the per-run tree to "keep cache" | Security boundary (#1086): no SSH/git/gh/1P sockets or keys. Token savings do not justify credential exposure. Any warm state is **additive and optional**, never a removal of the wipe. |
| Enable full `grep`/`read`/`glob` tools on Windows | Residual risk: Windows is not mount-isolated. Prefer a *narrower* gate expansion (`grep -n`, `head -n`) over reopening file tools wholesale. If the gate cannot express it safely, fall back to documenting accepted cost. |
| Retry implement runs like review/ask | Explicitly out: "Implementation runs are never re-run blindly: the clone is kept" (`:179`). Keep. |
| Change model / raise timeout / shrink REPORT_FLOOR | Not token efficiency; changes review quality or safety floor (`:53`). |
| Copy GLM's `config/opencode/` for StepFun | StepFun owns `config/opencode-stepfun/` (`:63`, `:216-218`); sharing would blur profiles and break the Windows pin. |
| "Just measure live with paid calls" first | Owner asked for a fix plan; measurement is Phase 5 and must not block Phases 1–3. |

## 8. Design decisions already made (dated)

**LOCKED (do not relitigate)**

1. *(2026-10-06)* `rate_limited` must match **provider error channels only**
   (stderr + StepCode `^429: \{` / `^4[0-9][0-9]: \{` on stdout), never
   assistant body text — mirror `credit_stop` (`:439-448`).
2. *(2026-10-06)* Retry only when the turn **failed** (`rc != 0`) **or** a true
   provider 429 is present. A successful review that quotes "429" is kept.
3. *(2026-10-06)* `implement` is never auto-retried (`:179` stays).
4. *(2026-10-06)* Sealed packet stays by reference (`MANIFEST.md`); never inline.
5. *(2026-10-06)* Verdict-format instructions live in **one** place for OpenCode
   paths (the agent profile); the user prompt must not repeat them.
6. *(2026-10-06)* Unique per-run paths (`$rel`) and `$head` move to the **end**
   of the user prompt so the static prefix stays cache-stable across retries.
7. *(2026-10-06)* Security wipe of per-run XDG/home/tmpfs remains. Session or
   cache persistence is only allowed if it does not leak credentials into the
   model sandbox.

**OPEN (implementer's judgment, with criteria)**

A. *(2026-10-06)* Exact Windows gate grammar for `grep`/`head -n`: allow the
   minimum that enables content search and slices, still path-clamped to the
   review folder, still rejecting `-r` recursion outside, `--`, and absolute
   host paths. Criteria: adversarial table in Phase 3 all green; residual risk
   no worse than today's `cat` of whole files (which already dumps content).
B. *(2026-10-06)* Whether to persist an OpenCode `sessionID` per identity for
   429 retry resume vs. re-send. Criteria: resume must not reuse a tree that
   held secrets; prefer a session id file under `$STATE_DIR` that is **not**
   inside the model-visible sandbox copy.
C. *(2026-10-06)* Warm cache dir (outside bubblewrap) vs. accepted cold start.
   Criteria: documented in `docs/config-inventory.md`; default stays safe (off
   or isolated); measure before claiming a win.
D. *(2026-10-06)* Whether StepFun's openai-compatible endpoint does automatic
   prefix caching at all. Criteria: Phase 5 counters (`cache.read` /
   equivalent) or documented API behavior; if no cache exists, Phase 2 is still
   worth it for input-token de-duplication.

## 9. The plan — numbered, ordered steps

### Phase 1 — Stop false-positive full re-sends (highest impact, self-contained)

**Context cut point.** After Phase 1 lands and tests pass, a fresh session may
start Phase 2 after re-reading this plan.

#### P1.1 Make `rate_limited` provider-channel-only

*Revised 2026-10-06 (Muse M1): exact stderr shapes + `$out.jsonl` wiring.*

- **Change:** `bin/ai-stepfun:184` (`rate_limited`). Replace whole-output grep
  with the same channel discipline as `credit_stop` (`:439-448`):
  - **Stderr — provider channel only** (never assistant body). Case-insensitive.
    Must include: word-bounded `429`, `rate_limited`, `Too Many Requests`,
    `HTTP 429`. Do **not** drop bare `429` on stderr — today's detector relies
    on it (e.g. `429 rate limit exceeded`); M2 already makes stderr false
    positives harmless when the report is well-formed. Match `"status": 429`
    JSON shapes too. (*Revised 2026-10-06 after GLM F1: the earlier "never
    bare 429" wording would regress real retries.*)
  - **Stdout — provider shapes only:** `^429: \{` and `^4[0-9][0-9]: \{`
    (StepCode HTTP-error lines). Never match assistant prose.
  - **OpenCode JSONL:** when `$out` is a raw JSONL dump (fallback `:309`/`:352`),
    also scan sibling `$out.jsonl` if present; count only non-`text` error
    events. `run_step_retry` must discover that sibling explicitly.
  - `tests/fixtures/muse-opencode/usage-1.18.12.json` is a shape reference
    only — do not copy Muse's fixture wholesale.
- **Behavior when done:** a successful review whose body says "429" or
  "rate_limited" is treated as success; a real provider 429 still retries.
- **Depends on:** nothing.
- **Verification gate:** `tests/test-ai-stepfun.sh` includes P1.3 cases; suite
  green. `grep -n rate_limited bin/ai-stepfun` shows the narrowed pattern.

#### P1.2 Retry only on failure or true provider 429

*Revised 2026-10-06 (Muse M2): never discard a well-formed report on rc=0.*

- **Change:** `bin/ai-stepfun:185-193` (`run_step_retry`). Current logic:
  `rate_limited "$2" && [ "$n" -lt "$RATE_RETRIES" ] || return "$rc"` — retries
  even when `rc=0` if the text matched. New logic:
  - `rc=0` and report **well-formed** (non-empty; VERDICT when required) →
    return 0 immediately, even if error channels mention 429 (in-run tool
    retry that still succeeded).
  - `rc=0` and report **empty/malformed** and provider-429 in error channels →
    retry up to `RATE_RETRIES`.
  - `rc!=0` and provider-429 → retry.
  - `rc!=0` and not 429 → return that rc (no blind retry).
- **Behavior when done:** no successful report is discarded; failed non-429
  turns do not spin.
- **Depends on:** P1.1 (shared detector).
- **Verification gate:** P1.3 unit tests; `tests/test-ai-stepfun.sh` green.

#### P1.3 Guard tests (adversarial + happy)

Add to `tests/test-ai-stepfun.sh`. (`config/ci-suites/test-ai-stepfun.sh.json`
— confirm whether those suite JSONs exist; if absent, no wiring needed.)

| Test name / case | Input | Expected |
|---|---|---|
| `keeps-review-that-quotes-429` | rc=0 output whose body contains `429` and `rate_limited` and `Too Many Requests` | no retry; report kept; verdict accepted |
| `keeps-good-verdict-despite-stderr-429` | rc=0, well-formed VERDICT, stderr mentions `rate_limited` | no retry; report kept (Muse M2) |
| `keeps-review-that-quotes-402-text` | rc=0 body mentions billing/quota words | no retry (credit path unchanged) |
| `retries-on-stdout-429-json` | stdout line `429: {"error":{"code":"rate_limited"}}`, rc≠0 or empty report | retry up to N; pause honored |
| `retries-on-stderr-rate_limited` | stderr `rate_limited` / `Too Many Requests` / `HTTP 429` / word-bounded `429` (any case) | retry |
| `retries-on-jsonl-error-429` | provider-429 only in `$out.jsonl` error events, empty/malformed report | retry |
| `no-retry-on-bash-failure` | rc=1, stderr `command not found` | return rc; no retry |
| `implement-never-auto-retried` | implement path + 429 | no `run_step_retry` loop (existing `:179`) |

**Adversarial cases (trust boundary: provider output is external input)**

| External input | Hostile case | Test that proves it |
|---|---|---|
| Assistant report text | Contains `429`, `rate_limited`, `Too Many Requests` | `keeps-review-that-quotes-429` |
| Assistant report text | Quoted HTTP error blob in a code sample | `keeps-review-that-quotes-429` (or dedicated code-sample case) |
| StepCode stdout | `429: {json}` provider error | `retries-on-stdout-429-json` |
| OpenCode stderr | rate limit prose | `retries-on-stderr-rate_limited` |
| OpenCode JSONL | `type=="text"` containing the word 429 | must **not** count as rate limit (add if fixture exists) |
| Tool failure | non-zero rc, no 429 | `no-retry-on-bash-failure` |

- **Verification gate:** every row above names a test that exists and passes.
  Suite command: `bash tests/test-ai-stepfun.sh` (Git Bash on Windows).

### Phase 2 — De-duplicate prompts and stabilize prefixes

**Context cut point.** Re-read Phases 3–5 before starting later work.

#### P2.1 Drop duplicated VERDICT / preamble on OpenCode paths

*Revised 2026-10-06 (Muse B1): gate on engine, not `STEPFUN_OC_AGENT`.*

- **Change:** `bin/ai-stepfun` `cmd_review`. **First call `detect_engine` at
  the top of `cmd_review`** (and `cmd_ask` if it ever needs the same gate) —
  `ENGINE` is empty until `run_step` detects it, so evaluating the gate while
  assembling `$full` would silently no-op on Windows (*GLM F2*). Then keep a
  short operational preamble (disposable copy, no remotes, do not edit `$rel`,
  read `MANIFEST.md`). Remove the repeated "Be specific… VERDICT: …" block
  **only when `ENGINE=opencode`**, because those strings already live in
  `stepfun-review.md:34-42` / `stepfun-review-windows.md:28-38`. **Do not** key
  off `STEPFUN_OC_AGENT` alone — `cmd_review` sets it unconditionally and
  StepCode ignores agent profiles, so that would strip the only VERDICT
  instructions StepCode gets.
- **Behavior when done:** one copy of verdict format per turn on OpenCode;
  StepCode unchanged. `$head` still appears in the user prompt's final-line
  template (required for the exact sha) but see P2.2.
- **Depends on:** none (can parallel P1).
- **Verification gate:** assert the VERDICT instruction block appears **once**
  in the assembled prompt when `ENGINE=opencode` (semantic check — required),
  and that StepCode still has it in `$full`. Suite green.

#### P2.2 Move unique `$rel` / `$head` to the prompt end

- **Change:** `bin/ai-stepfun:600-607`. Reorder so the static prose (role,
  rules, verdict instructions when needed) comes first; `$rel`, `$head`, and
  `$prompt` body last. Same for `cmd_ask` preamble (`:643`) if it gains unique
  text later.
- **Behavior when done:** two retries of the same review share a long stable
  prefix (helps provider prefix cache if it exists; harmless if not).
- **Depends on:** P2.1 (avoid reshuffling twice).
- **Verification gate:** unit/string test or a small shell assertion that
  `$rel` does not appear in the first N lines of the assembled prompt; or a
  golden prompt fixture under `tests/fixtures/stepfun/` compared by stable
  prefix.

#### P2.3 Handle dead `compaction` block

- **Change:** `config/opencode-stepfun/opencode.json:7-12`. Either delete the
  inert block (preferred if OpenCode ignores it for single-turn `run`) or leave
  it with a one-line comment in a sibling `config/opencode-stepfun/README.md`
  saying it is intentional for long in-run tool loops. Do not "tune" values
  without measurement (Phase 5).
- **Verification gate:** config still parses; `ai-stepfun doctor` (offline) or
  tests that load the profile still pass.

### Phase 3 — Windows exploration cost (search + slices)

**Context cut point.** Security-sensitive; adversarial table is mandatory.

#### P3.1 Extend Windows gate grammar

*Revised 2026-10-06 (Muse B2/B3): runner allowlist + Layer-0 metachar filter.
Fallback if grep stays too risky: ship `head -n` alone and skip grep.*

- **Change (three parts, all required if `grep` ships):**
  1. **Runner allowlist** (`bin/ai-stepfun` `write_windows_runners` ~`:479`,
     `bin/ai-stepfun-windows-shell` `run()` ~`:180`): provision `grep` with the
     same hashed-binary pin as `ls`/`cat`/`head` (Git `usr/bin` path + sha256).
     Hash-mismatch and missing-binary tests required. Without this, grammar
     changes never execute.
  2. **Closed-grammar / metachar filter** (code labels this "Layer 1: closed
     grammar" at `bin/ai-stepfun-windows-shell:52`; the plan previously said
     "Layer-0"): today
     `INNER` refuses `*?[]{}()|$&;<>` before grammar parse — so `grep foo.*bar`
     dies before the `grep` branch runs. Rework: exempt the **pattern token
     only** (still path-clamped), or require `-F` and a plain pattern with its
     own deny list. Specify the exact rule and test it.
  3. **Grammar** (`bin/ai-stepfun-windows-shell:256-261`):
     - `ls <path>` / `cat <path>` unchanged.
     - `head -n N <path>` — only `-n` and a positive decimal `N` (no `-N`,
       no `head -5`, no glued `-n5`).
     - `grep -n -F <pattern> <path>` — require both flags; **deny** `-r`,
       `-R`, `--include`, `-e`, `--`, glued forms (`-n5`, `--include=`),
       multiple files, leading-dash patterns (require a non-dash pattern).
     - Keep forbidding `git`/`gh`/`op`/`curl`/etc. (`:276-277`).
- **Behavior when done:** the model can find a symbol without `cat` of every
  file; path clamp still fail-closed; grep cannot smuggle metacharacters into
  the filter bypass.
- **Depends on:** nothing (parallel with Phase 2).
- **Verification gate:** `tests/test-ai-stepfun-windows-shell.sh` cases below
  green; every `check "…"` in that suite still passes; allowlist hash tests
  green.

**Adversarial cases (trust boundary: model-supplied shell strings)**

| External input | Hostile case | Test that proves it |
|---|---|---|
| path operand | `../outside/secret` | REFUSE (existing `assert_in_folder` tests + new) |
| path operand | `C:\Windows\System32\...` or `//host/share` | REFUSE |
| `head` flags | `head -c 100 file` / `head -n -1 file` | REFUSE unknown/unsafe flags |
| `grep` flags | `grep -r pattern .` | REFUSE `-r` |
| `grep` flags | `grep -e x -e y file` / `--` smuggling | REFUSE |
| `grep` flags | glued `-n5`, `--include=*.c` | REFUSE |
| `grep` pattern | leading-dash `grep -n -F -x file` parses as flags | REFUSE; require non-dash pattern |
| `grep` pattern | metacharacters that bypass Layer-0 (`foo.*bar`) | allow only if P3.1.2 exempts pattern token; else REFUSE |
| `grep` output | `grep -n -F .* hugefile` dumps more than `cat` | document accepted cost or row-cap |
| `grep` arity | zero paths or >1 path | REFUSE |
| `grep` pattern | empty `''` (matches every line) | REFUSE or row-cap |
| `head` | `-n 999999999` whole-file dump | REFUSE or document accepted cost |
| argv shape | `head -n 5 file extra` / `head -5 file` / `head -N 5 file` | REFUSE; only `-n N` |
| allowlist | `grep` binary hash mismatch | REFUSE run (provisioning test) |
| pattern | `.*` with huge file — allowed (token cost is model's), no path escape | allow + document |

#### P3.2 Windows agent profile + docs

- **Change:**
  - `config/opencode-stepfun/agent/stepfun-review-windows.md:20-23` — update the
    allowed shell verbs list to match P3.1; keep file tools disabled unless the
    implementer proves the gate is equivalent (default: keep disabled).
  - `docs/config-inventory.md` StepFun Windows sentence; `skills/shared/stepfun/SKILL.md`
    Windows platform note if commands change; `plan_stepfun-windows-folder-shell.md`
    is a historical plan — do **not** rewrite it; note the change here instead.
- **Verification gate:** docs match grammar; no stale "only ls|cat|head" claim
  remains in live docs (search those files).

#### P3.3 Windows suite updates

- **Change:** `tests/test-ai-stepfun-windows-shell.sh` — add allow/deny cases
  from the adversarial table; create fixtures under `tests/fixtures/stepfun-windows-shell/` if needed (suite's `FIX=` var exists but is unused).
- **Verification gate:** full file green in Git Bash; CI suite JSON still lists
  the file (`config/ci-suites/test-ai-stepfun-windows-shell.sh.json`).

### Phase 4 — Persistent sessions / warm cache (security-sensitive)

*Revised 2026-10-06 (Muse M3): default SKIP. Persistence fights LOCKED-7 wipe.*

**Context cut point.** Re-read §8 OPEN A–D and the #1086 comments before
starting. **Default: skip Phase 4.** Muse M3: OpenCode session state lives in
the per-run XDG tree wiped at `:303`/`:344`, so a saved session id points at
deleted state — resume needs an owner-accepted wipe exception, which LOCKED-7
forbids without that exception. 429 retries are rare and `RATE_PAUSE` dominates
cost more than tokens. Do Phase 4 only with a written owner exception.

#### P4.1 Resume on 429 retry (OpenCode + StepCode if supported)

- **Change:** `bin/ai-stepfun:185-193` and engine runners (`run_stepcode`,
  `run_opencode_turn`).
  - Capture OpenCode `sessionID` from the JSONL/`--format json` stream (today
    only `type=="text"` is taken at `:306`).
  - On retry of the **same** review identity, pass `--session <id>` (or the
    engine's resume flag) instead of a brand-new turn **if** the engine
    documents it and the session state lives outside the model-visible copy.
  - StepCode: evaluate `STEP_AUTOPILOT=1` in-run resume (`:177`, `:397`);
    `--no-session` (`:405`) stays for **cross-invocation** isolation unless
    OPEN-B is resolved in favor of resume.
- **Behavior when done:** a 429 mid-review does not re-send the entire system +
  tools + prompt when resume is available; fallback is today's cold retry.
- **Depends on:** Phase 1 (retry only when appropriate); OPEN-B judgment.
- **Verification gate:** offline test with a fake engine that asserts the second
  attempt passes a session flag when the first returned a session id; no secret
  paths in `$STATE_DIR` session files (chmod 700/600 as elsewhere).

#### P4.2 Optional warm cache dir

- **Change:** only if OPEN-C approves **and** Phase 4 is not skipped. A
  per-user cache directory **outside** bubblewrap `$home` (Linux) and outside
  the Windows disposable folder, read-only to the model if exposed at all.
  **Must include a cross-review leakage analysis** (Muse M3): cached content
  from one review must not become model-visible in another. Default off or
  documented-as-accepted.
- **Depends on:** P4.1; security review comment in the PR.
- **Verification gate:** `ai-stepfun doctor --live` or offline equivalent shows
  the path; `docs/config-inventory.md` records the choice; no credentials in
  that directory; leakage analysis written in the PR.

### Phase 5 — Measure, then claim

#### P5.1 Record cache / session / retry counters

- **Change:** `bin/ai-stepfun` should log (to `$STATE_DIR/reports/…` sidecar or
  the existing reviewer event stream) for each turn:
  - engine, whether resumed, retry count, input/output tokens if the JSONL has
    them, `cache.read`/`cache.write` if present (Muse fixture shape:
    `tests/fixtures/muse-opencode/usage-1.18.12.json` is a reference only).
- **Verification gate:** a fixture-driven test parses a sample JSONL and writes
  the counters; no API key material in logs.

#### P5.2 Live proof

- **Change:** none in code. After Phases 1–4 merge, run one real `ai-stepfun
  doctor --live` and (only if an ordinary review is already needed) one review;
  record before/after token notes in the landing issue.
- **Live proof is required before this plan is closed.** Leave
  `- [ ] live proof` on the **same** GitHub issue that lands the code. Do not
  open a second ticket.

## 10. Tests required

| Suite / command | Must stay green / gain |
|---|---|
| `bash tests/test-ai-stepfun.sh` | All existing checks; add P1.3 rows; add prompt-assemble assertions (P2.1–P2.2); optional fake-engine session test (P4.1) |
| `bash tests/test-ai-stepfun-windows-shell.sh` | All existing `check` lines; add P3.3 allow/deny rows |
| `config/ci-suites/test-ai-stepfun.sh.json` | Updated if case names are enumerated |
| `config/ci-suites/test-ai-stepfun-windows-shell.sh.json` | Same |
| Offline `ai-stepfun doctor` | Still passes after config/profile edits |

Never "add tests" as a step — the tables above are the tests.

## 11. Constraints, standing rules, and gotchas in force

- **Branch:** feature branch + PR + merge queue; never push `main`. Documentation-only PRs (prose only) may skip waiting on checks and merge immediately the normal way; if any changed file is code/tests/config, normal checks apply.
- **Worktree:** implement in a dedicated current-upstream worktree, not the
  landing checkout `C:\repos\ai-devops`.
- **Git identity before commit:** `git var GIT_COMMITTER_IDENT` must show
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- **Stage only task-owned files.** No broad staging; no destructive reset/force-push.
- **This repo is public:** never commit transcripts, secrets, raw keys, or
  private artifacts. Secrets by 1Password **title only** (`vibe_coding` /
  `stepfun step5 ai api key`).
- **No human approval prompts** for technical work; AI reviewers gate technical
  production actions. This change is toolkit code + tests + docs — normal review.
- **Preserve capability:** if a fix cannot land without removing a safety gate
  (path clamp, bubblewrap, no-remote checks, implement-never-retry), stop and
  report `Blocked —` rather than weakening the gate.
- **PowerShell compatibility** of wrappers must remain; run Bash tests through
  Git Bash on Windows.
- **Reviewer safety path:** changes to reviewer wrappers/evidence tools may need
  one read-only exact-head final review before merge (`AGENTS.md`). Treat
  `bin/ai-stepfun*` as reviewer-wrapper code — plan for that review.
- **Do not verify the same commit twice**; merge queue tests the landing commit.
- **Time in human text is EST** with zone named.
- **ai-devops task class:** declare with `ai-task-gates start --class` before
  implementation sessions (class name per `docs/task-router.md` / wrapper class
  used for reviewer tooling). Planning-only sessions that only write this file
  still record STATUS honestly.

## 12. Access and environment

- **Machine:** `edge-dev` (Windows) for authoring; Linux host where StepCode is
  installed for StepCode-path testing.
- **CLIs:** `git`, Git Bash, `ai-stepfun` (and `ai-stepfun doctor --live` for
  Phase 5), OpenCode pin 1.18.12 via the existing installer pattern
  (`bin/setup-opencode-glm.ps1` is the install ancestor per
  `plan_stepfun-windows-folder-shell.md` — there is no separate
  `setup-opencode-stepfun.ps1`; that is not a gap).
- **Secrets:** none in the plan. Key store is owner-only
  `~/.config/ai-devops/secrets/stepfun-api-key` created by `ai-stepfun store-key`
  (item `stepfun step5 ai api key` in vault `vibe_coding`). Reviews never call
  1Password.
- **Local run:** `bash tests/test-ai-stepfun.sh` and
  `bash tests/test-ai-stepfun-windows-shell.sh` from the worktree root in Git
  Bash. Do not run live paid StepFun jobs while a full local suite collides with
  shared runners (`bin/ai-test-local --check-collision` if using that path).
- **Muse review of this plan:** `ai-muse` with the stable name
  `stepfun-token-efficiency-plan`; set `AI_MUSE_CALLER` to the current client
  (`claude` or `codex` per session — **this MiMo session used `codex` only if
  the wrapper accepts it; otherwise the wrapper's supported caller list wins**).
  Read the report path the wrapper prints.

## 13. Definition of done + risks and open questions

**Definition of done**

- [ ] Phases 1–3 implemented in a worktree branch with named tests green.
- [ ] Phase 4 only if security criteria (§8 OPEN B–C) are met, or explicitly
      skipped with a STATUS row saying "skipped — security criterion unmet".
- [ ] Phase 5 counters logged; live proof checklist item on the landing issue
      ticked or left open with a named owner.
- [ ] Docs touched only where behavior changed (`docs/config-inventory.md`,
      skill, rotation row if needed); STATUS table updated with artifacts
      (paths/SHAs/commands), never bare counts.
- [ ] `git var GIT_COMMITTER_IDENT` correct; only task-owned files staged.
- [ ] PR opened; checks green or doc-only path used correctly; merged through
      the normal queue; `origin/main` shows the commit.
- [ ] Handoff updated if the session ends mid-work; this plan's STATUS kept
      truthful by whoever executes a row.

**Risks / rollback**

| Risk | Mitigation / rollback |
|---|---|
| Narrower 429 detection misses a real provider error shape | Keep stderr match; add fixture for StepCode `429: {`; roll back P1.1 only if false-negatives appear — never go back to whole-output grep |
| Windows gate expansion enables path escape | Adversarial table + fail-closed `assert_in_folder`; roll back P3.1 to `ls\|cat\|head` |
| Session resume leaks state across reviews | Session id only under `$STATE_DIR`; never in the model copy; wipe still runs |
| Prefix reordering breaks a brittle test that greps prompt order | Fix the test to assert semantics (VERDICT once, `$rel` late), not line numbers of `$full` |
| False "cache win" claimed | Phase 5 only reports measured counters; no marketing language in docs |

**Open questions (criteria in §8)**

1. Does `api.stepfun.ai` openai-compatible surface do automatic prefix caching?
2. Should P4 land at all? **Muse M3 default: no — skip Phase 4.** P1–P3 are
   enough unless the owner grants a wipe exception.
3. Exact caller string Muse/wrappers accept from a MiMo session (§12).
   *Observed 2026-10-06: `AI_MUSE_CALLER=codex` works from MiMo on edge-dev.*
4. Does `grep` ship (with Layer-0 + allowlist work) or descope to `head -n`
   only? Criteria: adversarial table all green; if not, ship `head -n` alone.

---

## Self-audit (mandatory — preserved answers)

1. **Could a brand-new AI session with no project knowledge execute this plan
   without asking anything?**  
   **Yes.** Sections 2–5 give the repo, hosts, branch policy, and exact
   `file:line` current state; Section 9 names every file and a verification
   gate per step; Section 10 names the test suites; Section 12 says how to run
   them in Git Bash and that secrets are title-only. The only judgment calls
   are explicitly labeled OPEN in Section 8 with criteria.

2. **Does the plan carry every piece of background, nuance, and reasoning?**  
   **Yes.** Section 6 ranks the audit findings with evidence; Section 7 records
   rejected approaches (inline packet, remove bubblewrap, full Windows tools,
   retry implement, share GLM config); Section 8 locks the safety-relevant
   decisions (provider-only 429, no implement retry, packet-by-reference,
   keep the wipe) so the implementer cannot "improve" them away. Gap found and
   fixed during drafting: Open question 3 (Muse caller for MiMo) is now stated
   instead of assumed.

3. **Is the ultimate goal clear enough for a wrong-step judgment call?**  
   **Yes.** Section 1 states token spend on the code under review, lists what
   becomes true, and includes "If any step conflicts with this goal, the goal
   wins — stop and flag it." Example application: if P3.1 cannot be made safe,
   skip it rather than weaken the clamp — that follows the goal without
   relitigating security.

**Checklist:** 13 sections present; goal in business English up front;
self-contained; rejected approaches recorded; concrete files + gates;
adversarial tables on both trust boundaries (provider output, model shell);
locked vs open labeled; out-of-scope list; tests named; terms defined;
secrets by location; DoD includes commit/push/CI; handoff linked both ways.
