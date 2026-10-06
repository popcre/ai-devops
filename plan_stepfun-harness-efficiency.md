# IMPLEMENTATION PLAN — StepFun harness token efficiency (2026-10-06)

Companion handoff: [`HANDOFF.d/2026-10-06T0824Z-edge-dev-mimo-stepfun-harness-efficiency.md`](HANDOFF.d/2026-10-06T0824Z-edge-dev-mimo-stepfun-harness-efficiency.md)
(That handoff links back here. Root `HANDOFF.md` stays the static pointer.)

**Revision 2026-10-06 (owner):** the executing session is a **coordinator only**.
It does not implement. It spins up **one subagent per phase (including Phase 4)**,
parallelizes independent phases, and **runs the whole plan through to the end on
its own** (code → tests → PR → merge → live proof). No stop for the owner unless
a genuine business-meaning choice appears.

## STATUS

| Step | State | Evidence (artifact, never a bare number) |
|---|---|---|
| W0 coordinator setup (branch, gates, briefs) | ⬜ open | — |
| W1a Phase 1 subagent (retry detector) | ⬜ open | — |
| W1b Phase 3 subagent (Windows gate) | ⬜ open | — |
| W2a Phase 2 subagent (prompt de-dup) | ⬜ open | — |
| W2b Phase 4 subagent (sessions/cache) | ⬜ open | — |
| W3 Phase 5 subagent (measure + live proof) | ⬜ open | — |
| W4 integrate, PR, exact-head review if required, merge | ⬜ open | — |
| Live proof checklist on landing issue | ⬜ open | `- [ ] live proof` on the same issue |

**Muse review (2026-10-06):** `VERDICT: REVISE plan` —
`.ai/reviews/muse-stepfun-token-efficiency-plan-r2-20261006T124204Z-968393-5381.md`.
Six must-fix items are already in the phase briefs (B1–B3 / M1–M3). Do not reopen.

**GLM 5.3 review (2026-10-06):** `VERDICT: REVISE plan` —
`.ai/reviews/glm-stepfun-token-efficiency-plan-review-ec1b178ec9de9d8716c24d5484644b6f534d3a9419e849d75c63f21b8b86c711.md`.
F1/F2/F3 folded in (stderr keeps bare `429`; `detect_engine` before `$full`).

*File rename note:* never name a doc `*token*` — `.gitignore` `**/*token*` hides it.

**Where execution starts:** §9 Wave 0 (coordinator setup), then Wave 1 in parallel.
Nothing is implemented yet.

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
- The work **ships**: tests green, PR merged on `origin/main`, live proof on the
  landing issue — without asking the owner to babysit.

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

Owner (MiMo chat, 2026-10-06): two audits of StepFun token use, then a fix plan
reviewed by Muse and GLM. Later the same day: **rewrite the plan so the session
acts only as coordinator, one subagent per phase (including Phase 4), parallel
where independent, and the session sees the whole plan through to the end.**

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
- `bin/ai-stepfun-windows-shell` command grammar (search/slice verbs only) and
  runner allowlist provisioning for `grep`/`head`.
- `config/opencode-stepfun/opencode.json` and agent profiles.
- Tests: `tests/test-ai-stepfun.sh`, `tests/test-ai-stepfun-windows-shell.sh`.
- Matching docs and this plan's STATUS as waves complete.
- Phase 4 session/cache work **in scope** (owner 2026-10-06: include Phase 4).
- Measurement + live proof + PR merge — the coordinator owns shipping.

**NOT in this plan**

- Changing StepFun model pin, pricing, credits, or the allocator membership row.
- GLM / Muse / DeepSeek / Grok / Qwen wrappers (except as read-only reference).
- `bin/ai-review-packet` packet format or seal rules (keep injecting by reference).
- Windows mount isolation or bubblewrap on Windows (owner-accepted residual).
- Provider API changes, new MCP servers, or 1Password changes.
- Implementing `implement` on Windows (still refused by design).
- Softening any safety gate (path clamp, wipe, no-remote, implement-never-retry).

## 5. Current state of the code

All of this is **on `origin/main`** as of 2026-10-06 (`73cf671` plan landed).
No fix work has been started. The landing checkout is landing-only.

| Area | State | Exact refs |
|---|---|---|
| Retry / rate detect | Works, **wrong trigger** | `bin/ai-stepfun` `rate_limited` / `run_step_retry` (~176–200) |
| Credit detect (correct pattern) | Works | `credit_stop` (~439–448) |
| StepCode turn | Sessionless | `--no-session` (~405), comment ~357 |
| OpenCode per-run tree | Fresh + deleted | ~210–219, ~240, ~303, ~344 |
| Review prompt | Duplicates VERDICT; unique `$rel` early | `cmd_review` `$full` (~605–612); `stepfun-review.md:38-42` |
| Windows review tools | Only `bash` + shell | `stepfun-review-windows.md:5-17` |
| Windows shell grammar | `ls\|cat\|head` one path, no flags | `ai-stepfun-windows-shell` (~256–261) |
| OpenCode config | No cache keys; inert `compaction` | `opencode.json:7-12`, `:17-19` |
| Packet injection | By reference — keep | `$rel/MANIFEST.md` in review prompt |
| Tests | Genuine 429 covered; false-positive **not** | `tests/test-ai-stepfun.sh` ~139 |

## 6. Key findings and root cause

1. **HIGH — False-positive rate-limit retry re-buys whole turns.**  
   `rate_limited()` greps the *entire assistant output* for bare
   `429|rate_limited|Too Many Requests`. `run_step_retry` re-runs when that
   matches **even if `rc=0`**, up to `RATE_RETRIES=2` after `RATE_PAUSE=65s`.
   `credit_stop` already does provider-channel-only correctly.

2. **HIGH (Windows) — exploration is whole-file `cat` only.**  
   Gate allows `ls|cat|head` one path, no flags; agent disables
   `read/glob/grep/list/find`. Finding a symbol forces full-file tokens.
   `grep` also needs runner-allowlist provisioning and a closed-grammar /
   metachar-filter rework (code label: "Layer 1: closed grammar").

3. **MED — retries and every wrapper turn are cold.**  
   No `--session`/`--continue`. StepCode `--no-session`. OpenCode fresh XDG
   wiped after; `sessionID` never captured. Contrast `bin/ai-deepseek` /
   `bin/ai-muse` session persistence.

4. **MED — no provider cache configuration; prefix cache can be broken.**  
   Review prompt embeds per-run unique `$rel` early. No cache keys in
   `opencode.json`.

5. **MED/LOW — duplicated instructions.**  
   Review `$full` repeats agent-profile VERDICT text (~150–200 tokens/review).

**Already efficient — do not "fix"**

- One model turn per invocation; no history re-send across review/ask/implement.
- Sealed packet by reference, never inlined.
- Short static agent profiles; Windows omits unused tool schemas.
- `credit_stop` ignores assistant content; implement never auto-retried.
- Identity-keyed `REVIEW_TAG`; host-side digest checks are free in tokens.

## 7. Approaches considered and REJECTED, and why

| Approach | Why rejected |
|---|---|
| Coordinator implements everything itself | Owner 2026-10-06: coordinator only; one subagent per phase. |
| One mega-subagent for all phases | Loses parallelism and isolation; owner asked for per-phase agents. |
| Inline the whole review packet into the prompt | Regresses seal model and token cost. |
| Remove bubblewrap / stop wiping the per-run tree | Security boundary (#1086). Warm state is additive only. |
| Full `read`/`glob`/`grep` tools on Windows | Not mount-isolated. Prefer narrow gate expansion; descope `grep` if unsafe. |
| Retry implement runs like review/ask | Explicitly forbidden (`implement-never-retried`). |
| Share GLM's `config/opencode/` | StepFun owns `config/opencode-stepfun/`. |
| Stop mid-plan and ask the owner for a go/no-go per wave | Owner: see the plan through to the end on its own. |

## 8. Design decisions already made (dated)

**LOCKED (do not relitigate)**

1. *(2026-10-06)* `rate_limited` matches **provider error channels only** —
   stderr may keep word-bounded bare `429` (case-insensitive; GLM F1) plus
   `rate_limited` / `Too Many Requests` / `HTTP 429`; stdout only `^429: \{`
   and `^4[0-9][0-9]: \{`; OpenCode JSONL only non-`text` error events.
   Never match assistant body.
2. *(2026-10-06)* Retry only when the turn failed (`rc != 0`) **or** report is
   empty/malformed with a true provider 429. A well-formed report is kept even
   if error channels mention 429 (Muse M2).
3. *(2026-10-06)* `implement` is never auto-retried.
4. *(2026-10-06)* Sealed packet stays by reference.
5. *(2026-10-06)* Verdict-format instructions live in **one** place on OpenCode
   (agent profile). Gate on `ENGINE` after `detect_engine` (GLM F2), never on
   `STEPFUN_OC_AGENT` alone (Muse B1).
6. *(2026-10-06)* Unique `$rel` / `$head` move to the **end** of the user prompt.
7. *(2026-10-06)* Security wipe of per-run XDG/home/tmpfs remains (LOCKED-7).
   Session/cache persistence is allowed only if it does not leak credentials or
   cross-review content into the model sandbox.
8. *(2026-10-06)* Coordinator never implements and never bypasses a gate to
   "finish faster". Phase 4 is **in scope**; if security criteria cannot be met,
   the Phase 4 subagent reports `skip-unsafe` with evidence — it does not weaken
   the wipe.
9. *(2026-10-06)* One subagent per phase. Parallel only when file sets are
   disjoint (see §9 wave graph). Coordinator holds the integration branch.

**OPEN (subagent judgment, with criteria)**

A. Windows gate grammar exactness (P3.1): adversarial table all green; if not,
   ship `head -n` only and skip `grep`.
B. Session resume (P4.1): session id under `$STATE_DIR`, never inside the
   model-visible copy; wipe still runs.
C. Warm cache (P4.2): outside bubblewrap; cross-review leakage analysis required.
D. Whether StepFun's API does automatic prefix caching — Phase 5 measures.

## 9. Execution model — coordinator + phase subagents

### 9.1 Coordinator contract (the executing session)

The coordinator **only**:

1. Declares task class (`ai-task-gates start --class code` or `reviewer-safety`
   if the change set is treated as reviewer-wrapper code) and rechecks before
   PR wait / ship.
2. Creates **one integration worktree** (not the landing checkout) on branch
   `mimo/stepfun-harness-efficiency-impl` from current `origin/main`.
3. Writes each phase brief (§9.4) into a file under the worktree
   `.ai/tmp/phase-briefs/` (gitignored) and **spawns one subagent per phase**.
4. Enforces the wave graph and file ownership (§9.2). Does not edit harness
   source itself.
5. Runs the focused suites after each wave, fixes **integration-only** issues
   (merge conflicts, STATUS updates), and records STATUS artifacts.
6. Opens the PR, obtains any required exact-head independent review
   (reviewer-wrapper path), merges through the queue, confirms `origin/main`.
7. Ensures live-proof checklist item is created on the landing issue and Phase 5
   reports the proof (or names who holds it).
8. Updates this STATUS table and the companion handoff as waves complete.

Coordinator **must not**: implement phase steps, weaken gates, push `main`,
delete another session's files, or ask the owner for technical approval.

If a subagent returns incomplete work or a blocker without verbatim evidence,
the coordinator **resumes that subagent** (or re-spawns with a delta brief) —
it does not silently take over and implement.

### 9.2 Wave graph and file ownership (max safe parallelism)

```
Wave 0: coordinator setup (branch, gates, briefs)
    │
    ├──────────────┬──────────────┐
    ▼              ▼              │
Wave 1a         Wave 1b          │
Phase 1         Phase 3          │   PARALLEL (disjoint owners)
retry detect    Windows gate     │
    │              │              │
    └──────┬───────┘              │
           ▼                      │
Wave 2a         Wave 2b          │
Phase 2         Phase 4          │   PARALLEL after Phase 1 lands
prompt de-dup   sessions/cache   │   (both need retry code; file lock below)
    │              │              │
    └──────┬───────┘              │
           ▼                      │
Wave 3: Phase 5 (measure + live proof)  after Waves 1–2
           │
Wave 4: integrate, PR, review, merge, verify main
```

| Phase | Owns (write) | May read | Parallel with |
|---|---|---|---|
| **1** | `bin/ai-stepfun` (`rate_limited`, `run_step_retry`, retry helpers only), `tests/test-ai-stepfun.sh` | anything | **3** |
| **2** | `bin/ai-stepfun` (`cmd_review`, `cmd_ask` prompt assembly only), `config/opencode-stepfun/agent/stepfun-review.md`, `opencode.json` | anything | **4** (after 1) |
| **3** | `bin/ai-stepfun-windows-shell`, `bin/ai-stepfun` (`write_windows_runners` only), `config/opencode-stepfun/agent/stepfun-review-windows.md`, `tests/test-ai-stepfun-windows-shell.sh`, `tests/fixtures/stepfun-windows-shell/`, docs rows | anything | **1** |
| **4** | `bin/ai-stepfun` (`run_stepcode`, `run_opencode_turn`, session helpers, `run_step_retry` session args **only after 1 merges**) | anything | **2** (after 1) |
| **5** | `bin/ai-stepfun` (logging/counters only), counter tests, landing-issue notes | anything | none (last) |

**Integration rule (same-file safety):** all subagents work in the **same
integration worktree**, but only the owner listed above may write a given
slice. If two waves must touch `bin/ai-stepfun`, the coordinator runs them
**sequentially in that file** (Wave 2a then Wave 2b, or the reverse if 4 is
started first — default **2a then 2b**). Wave 1a and 1b may run truly in
parallel because their write slices are disjoint (Phase 3's `write_windows_runners`
is a different function than Phase 1's retry detector).

Alternative if conflicts bite: give each phase its own worktree off the
integration branch and have the coordinator `git merge` phase branches in wave
order. Default is one shared worktree + ownership table.

### 9.3 Subagent rules (all phases)

- Report **done** only with verification-gate evidence (command + result path).
- Report **blocked** with verbatim evidence; do not weaken a gate to finish.
- Never commit to `main`; never push. Coordinator owns git.
- Never call 1Password. Never log key material.
- Keep edits inside the owned slice; if a step needs a file outside the slice,
  say so in the report and stop that step.
- Run only the named tests for the phase; coordinator runs the full suites.

### 9.4 Phase subagent briefs

Each brief is written to `.ai/tmp/phase-briefs/phase-N.md` in the integration
worktree and passed to the subagent. The brief contains: path of this plan,
owned files, the step text below, locked decisions, adversarial tables, and
"verification gate + how to report".

---

#### Phase 1 — Stop false-positive full re-sends  
**Subagent:** `phase1-retry` · **Wave 1a** · **Depends on:** none

##### P1.1 Make `rate_limited` provider-channel-only

*Revised 2026-10-06 (Muse M1 + GLM F1).*

- **Change:** `bin/ai-stepfun` `rate_limited`. Same channel discipline as
  `credit_stop`:
  - **Stderr — provider channel only** (never assistant body). Case-insensitive.
    Include: word-bounded `429`, `rate_limited`, `Too Many Requests`,
    `HTTP 429`, `"status": 429` JSON shapes. **Do not drop bare `429` on stderr.**
  - **Stdout — provider shapes only:** `^429: \{` and `^4[0-9][0-9]: \{`.
    Never match assistant prose.
  - **OpenCode JSONL:** when `$out` is a raw JSONL dump, scan sibling
    `$out.jsonl` if present; count only non-`text` error events.
    `run_step_retry` must discover that sibling explicitly.
- **Behavior:** a successful review whose body says "429" is kept; a real
  provider 429 still retries.
- **Verification gate:** `bash tests/test-ai-stepfun.sh` green including P1.3
  rows; `grep -n rate_limited bin/ai-stepfun` shows the narrowed detector.

##### P1.2 Retry only on failure or true provider 429

*Revised 2026-10-06 (Muse M2).*

- **Change:** `run_step_retry` logic:
  - `rc=0` and report **well-formed** → return 0 (keep even if stderr says 429).
  - `rc=0` and report **empty/malformed** and provider-429 → retry.
  - `rc!=0` and provider-429 → retry.
  - `rc!=0` and not 429 → return rc (no blind retry).
- **Verification gate:** P1.3 tests green.

##### P1.3 Guard tests (adversarial + happy)

Add to `tests/test-ai-stepfun.sh`:

| Test name / case | Input | Expected |
|---|---|---|
| `keeps-review-that-quotes-429` | rc=0 body contains `429` / `rate_limited` / `Too Many Requests` | no retry; report kept |
| `keeps-good-verdict-despite-stderr-429` | rc=0, well-formed VERDICT, stderr mentions `rate_limited` | no retry; kept |
| `keeps-review-that-quotes-402-text` | rc=0 body mentions billing/quota | no retry |
| `retries-on-stdout-429-json` | stdout `429: {json}`, empty/malformed report | retry |
| `retries-on-stderr-rate_limited` | stderr `rate_limited` / `Too Many Requests` / `HTTP 429` / word-bounded `429` (any case) | retry |
| `retries-on-jsonl-error-429` | provider-429 only in `$out.jsonl` error events | retry |
| `no-retry-on-bash-failure` | rc=1, `command not found` | return rc; no retry |
| `implement-never-auto-retried` | implement path + 429 | no retry loop |

**Adversarial (provider output is external input)**

| External input | Hostile case | Test |
|---|---|---|
| Assistant report | quotes 429 / rate_limited | `keeps-review-that-quotes-429` |
| Assistant report | quoted HTTP error blob | `keeps-review-that-quotes-429` |
| StepCode stdout | `429: {json}` | `retries-on-stdout-429-json` |
| OpenCode stderr | rate-limit prose | `retries-on-stderr-rate_limited` |
| OpenCode JSONL | `type=="text"` with "429" | must **not** count |
| Tool failure | rc=1, no 429 | `no-retry-on-bash-failure` |

---

#### Phase 2 — De-duplicate prompts and stabilize prefixes  
**Subagent:** `phase2-prompts` · **Wave 2a** · **Depends on:** Phase 1 merged
(same file `bin/ai-stepfun`)

##### P2.1 Drop duplicated VERDICT / preamble on OpenCode paths

*Revised 2026-10-06 (Muse B1 + GLM F2).*

- **Change:** In `cmd_review` (and `cmd_ask` if it gains the same gate):
  1. **Call `detect_engine` at the top** before assembling `$full` (`ENGINE` is
     empty until `run_step` detects it).
  2. Keep a short operational preamble (disposable copy, no remotes, do not
     edit `$rel`, read `MANIFEST.md`).
  3. Remove the repeated "Be specific… VERDICT: …" block **only when
     `ENGINE=opencode`** (those strings live in the agent profiles).
  4. **Do not** key off `STEPFUN_OC_AGENT` alone (StepCode would lose VERDICT
     instructions).
- **Verification gate:** VERDICT instruction block appears **once** in the
  assembled prompt when `ENGINE=opencode`; StepCode still has it in `$full`.

##### P2.2 Move unique `$rel` / `$head` to the prompt end

- **Change:** static prose first; `$rel`, `$head`, `$prompt` body last.
- **Verification gate:** `$rel` does not appear in the first N lines of the
  assembled prompt (or golden prefix fixture under `tests/fixtures/stepfun/`).

##### P2.3 Handle dead `compaction` block

- **Change:** `config/opencode-stepfun/opencode.json` — delete inert block or
  document it in `config/opencode-stepfun/README.md`. Do not retune without
  Phase 5 numbers.
- **Verification gate:** config parses; offline doctor / profile tests pass.

---

#### Phase 3 — Windows exploration cost  
**Subagent:** `phase3-windows` · **Wave 1b** · **Depends on:** none (parallel Phase 1)

##### P3.1 Extend Windows gate grammar

*Revised 2026-10-06 (Muse B2/B3). Fallback: ship `head -n` alone and skip `grep`.*

Three parts — all required **if** `grep` ships:

1. **Runner allowlist** (`write_windows_runners` + `run()` pin path): provision
   `grep` with the same hashed-binary pin as `ls`/`cat`/`head` (Git `usr/bin`
   + sha256). Hash-mismatch tests required.
2. **Closed-grammar / metachar filter** (code: "Layer 1: closed grammar"):
   today `INNER` refuses `*?[]{}()|$&;<>` before tokenization. Exempt the
   **pattern token only** (still path-clamped), or require `-F` + plain
   pattern with its own deny list. Test the exact rule.
3. **Grammar:**
   - `ls <path>` / `cat <path>` unchanged.
   - `head -n N <path>` — only `-n` and positive decimal `N` (no `-N`,
     no `head -5`, no glued `-n5`).
   - `grep -n -F <pattern> <path>` — require both flags; deny `-r`, `-R`,
     `--include`, `-e`, `--`, glued forms, multiple files, leading-dash patterns.
   - Keep forbidding `git`/`gh`/`op`/`curl`/etc.

- **Verification gate:** `bash tests/test-ai-stepfun-windows-shell.sh` green
  including allowlist hash tests.

**Adversarial (model-supplied shell strings)**

| External input | Hostile case | Test |
|---|---|---|
| path | `../outside/secret`, UNC, `C:\Windows\...` | REFUSE |
| `head` flags | `-c`, `-n -1`, `-N`, glued | REFUSE |
| `grep` flags | `-r`, `-e`, `--`, glued, `--include=` | REFUSE |
| `grep` pattern | leading-dash, empty `''`, metachar bypass | REFUSE or explicit allow+test |
| `grep` arity | 0 or >1 path | REFUSE |
| argv shape | extra args | REFUSE |
| allowlist | `grep` binary hash mismatch | REFUSE |
| output volume | `.*` hugefile / `-n 999999999` | document cost or row-cap |

##### P3.2 Windows agent profile + docs

- Update `stepfun-review-windows.md` verb list; keep file tools disabled by
  default. Update `docs/config-inventory.md` / skill Windows notes. Do **not**
  rewrite historical `plan_stepfun-windows-folder-shell.md`.
- **Verification gate:** no stale "only ls|cat|head" claim in live docs.

##### P3.3 Windows suite updates

- Add allow/deny rows; create `tests/fixtures/stepfun-windows-shell/` if needed.
- **Verification gate:** full suite green in Git Bash.

---

#### Phase 4 — Persistent sessions / warm cache  
**Subagent:** `phase4-sessions` · **Wave 2b** · **Depends on:** Phase 1 merged

*Owner 2026-10-06: Phase 4 is IN SCOPE (not default-skip). Security gates still
bind. If they cannot be met, deliver `skip-unsafe` with evidence — never weaken
LOCKED-7 wipe.*

##### P4.1 Resume on 429 retry (OpenCode + StepCode if supported)

- Capture OpenCode `sessionID` from the JSONL/`--format json` stream (today only
  `type=="text"` is taken).
- On retry of the **same** review identity, pass `--session <id>` (or engine
  resume flag) if the engine documents it **and** session state lives outside
  the model-visible copy.
- StepCode: evaluate `STEP_AUTOPILOT=1` in-run resume; `--no-session` stays for
  **cross-invocation** isolation unless OPEN-B is resolved in favor of resume.
- **Verification gate:** fake-engine test that attempt 2 passes a session flag
  when attempt 1 returned a session id; session files under `$STATE_DIR` only
  (chmod 700/600); wipe still runs.

##### P4.2 Warm cache dir (optional, leakage-gated)

- Per-user cache **outside** bubblewrap `$home` and the Windows disposable
  folder. **Must include cross-review leakage analysis** (cached content from
  one review must not become model-visible in another).
- **Verification gate:** doctor shows the path; `docs/config-inventory.md`
  records the choice; no credentials in that directory; leakage analysis in the
  PR body.

**If security criteria fail:** mark P4.1/P4.2 `skip-unsafe` in STATUS with the
exact failed criterion; leave cold-retry behavior intact.

---

#### Phase 5 — Measure, then claim  
**Subagent:** `phase5-measure` · **Wave 3** · **Depends on:** Waves 1–2 merged

##### P5.1 Record cache / session / retry counters

- Log per turn: engine, resumed?, retry count, input/output tokens if present,
  `cache.read`/`cache.write` if present (Muse fixture is a shape reference only).
- **Verification gate:** fixture-driven test writes counters; no key material.

##### P5.2 Live proof

- One real `ai-stepfun doctor --live` after merge; optional one ordinary review
  if already needed. Record notes on the **same** landing issue.
- Leave `- [ ] live proof` on that issue until proof is posted. Do not open a
  second ticket.

---

### 9.5 Wave-by-wave coordinator checklist

| Wave | Action | Done when |
|---|---|---|
| 0 | `ai-task-gates start`, integration worktree, brief files, STATUS | worktree clean off `origin/main`; briefs written |
| 1a+1b | Spawn `phase1-retry` and `phase3-windows` **in parallel** | both reports green; `bash tests/test-ai-stepfun.sh` and `bash tests/test-ai-stepfun-windows-shell.sh` pass |
| 2a | Spawn `phase2-prompts` | prompt-assemble tests green |
| 2b | Spawn `phase4-sessions` | resume tests green **or** STATUS `skip-unsafe` with criterion |
| 3 | Spawn `phase5-measure` | counters test green; doctor --live run |
| 4 | Commit, push, PR, required exact-head review, merge queue | `origin/main` contains the work; STATUS artifacts cited |
| 5 | Landing issue live-proof box; handoff STATUS refresh | checklist present; handoff truthful |

## 10. Tests required

| Suite / command | Must stay green / gain |
|---|---|
| `bash tests/test-ai-stepfun.sh` | Existing + P1.3 rows + P2 prompt asserts + P4 fake-engine + P5 counter fixture |
| `bash tests/test-ai-stepfun-windows-shell.sh` | Existing + P3.3 allow/deny + allowlist hash |
| `config/ci-suites/test-ai-stepfun*.json` | Update only if they enumerate cases |
| Offline `ai-stepfun doctor` | Passes after profile/config edits |

Never "add tests" as a step — the tables name the tests.

## 11. Constraints, standing rules, and gotchas in force

- **Branch:** feature branch + PR + merge queue; never push `main`.
- **Worktree:** integration worktree for implementation; landing checkout is
  landing-only (`C:\repos\ai-devops`).
- **Git identity before commit:**
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- **Stage only task-owned files.** Public repo: no secrets/transcripts.
- **Reviewer safety path:** `bin/ai-stepfun*` is reviewer-wrapper code — expect
  one read-only exact-head final review before merge.
- **Preserve capability:** never remove path clamp, bubblewrap, no-remote
  checks, or implement-never-retry. `Blocked —` if a fix cannot land safely.
- **PowerShell-compatible** wrappers; Bash tests via Git Bash on Windows.
- **Never name a doc `*token*`** (`.gitignore` `**/*token*`).
- **Long reviewer jobs:** detach (`Start-Process`) or accept `.ai/reviews/`
  reports if stdout is empty.
- **Time in human text is EST** with zone named.
- **No human approval for technical work.** Owner questions only for business
  meaning (§0 of the handoff).

## 12. Access and environment

- Machine `edge-dev` (Windows). Git Bash:
  `C:\Program Files\Git\bin\bash.exe`. Python: `$env:MIMO_PYTHON`.
- `ai-glm` / `ai-muse` healthy; callers `AI_GLM_CALLER=codex`,
  `AI_MUSE_CALLER=codex` work from MiMo here.
- Secrets by title only: vault `vibe_coding`, item `stepfun step5 ai api key`.
  Reviews never call 1Password.
- Integration worktree path is chosen by the coordinator at Wave 0 and recorded
  in STATUS.

## 13. Definition of done + risks and open questions

**Definition of done (coordinator closes without asking the owner)**

- [ ] Waves 0–3 complete; every phase subagent reported with gate evidence.
- [ ] Phase 4 either landed or STATUS `skip-unsafe` with the exact failed
      security criterion (never a silent skip).
- [ ] Both test suites green; offline doctor green.
- [ ] PR merged on `origin/main`; commit cited in STATUS (not a bare number).
- [ ] `- [ ] live proof` on the landing issue; P5.2 evidence posted or named
      owner if a live call is blocked.
- [ ] Handoff + this STATUS truthful.

**Risks / rollback**

| Risk | Mitigation / rollback |
|---|---|
| Subagents conflict in `bin/ai-stepfun` | Ownership table + sequential Wave 2; or per-phase branches merged in wave order |
| Narrower 429 detection misses a real shape | GLM F1 stderr set; roll back P1.1 only if false-negatives appear |
| Windows gate enables path escape | Adversarial table; roll back P3.1 to `ls\|cat\|head` |
| Phase 4 resume leaks state | Session id only under `$STATE_DIR`; wipe stays; else `skip-unsafe` |
| False "cache win" claimed | Phase 5 counters only; no marketing language |
| Reviewer-safety PR blocks | Run exact-head review (`ai-review`) before merge; do not `--admin` |

**Open questions (criteria in §8)**

1. Prefix caching on StepFun API? (Phase 5 measures.)
2. `grep` on Windows or `head -n` only? (Adversarial green or descope.)
3. Phase 4 resume vs wipe exception? (P4 reports landed or `skip-unsafe`.)

---

## Self-audit (mandatory — preserved answers)

1. **Could a brand-new AI session execute without asking anything?**  
   **Yes.** §9.1 is the coordinator contract; §9.2 is the wave/file graph;
   §9.4 is one brief per phase with gates; §10 names suites; §13 says ship
   without a mid-plan go/no-go. Judgment calls are labeled OPEN with criteria.

2. **Does the plan carry background, nuance, and reasoning?**  
   **Yes.** §6 findings with evidence; §7 rejected approaches (including
   "coordinator implements" and "stop per wave"); §8 locks safety and the
   coordinator/Phase-4 rules so they cannot be "improved" away.

3. **Is the ultimate goal clear for wrong-step judgment?**  
   **Yes.** §1 states token spend on the code under review **and** that the
   work ships through merge + live proof; "if a step conflicts with this goal,
   the goal wins — stop and flag it." Example: skip `grep` rather than weaken
   the path clamp — still meets the goal.

**Checklist:** 13 sections present (execution model added as §9); goal in
business English; self-contained; rejected approaches recorded; concrete files
+ gates; adversarial tables on both trust boundaries; locked vs open labeled;
out-of-scope list; tests named; secrets by location; DoD includes commit/push/
CI/merge/live proof; handoff linked both ways.
