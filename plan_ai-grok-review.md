# Implementation plan — `bin/ai-grok-review`

**Repo:** `u2giants/ai-devops` · **Branch:** `main` (main-only, no branches) ·
**Created:** 2026-08-05 · **Status:** not started

Companion documents — read alongside, not instead of:

- `skills/shared/grok-cli/SKILL.md` — the current Grok skill, commit `cfb5cd3`.
  This plan replaces most of it.
- `docs/glm-opencode.md` §5 "Hard-won constraints" — the same class of problem,
  already solved for GLM. `bin/ai-glm` is the design precedent for this script.
- `AGENTS.md` — the repo router.

---

## STATUS

| # | Step | State | Date | Notes |
|---|---|---|---|---|
| 1 | `bin/ai-grok-review` skeleton, arg parsing, `doctor` | ⬜ open | | |
| 2 | Session state store + `new` / `ask` | ⬜ open | | |
| 3 | Turn execution + wait-and-verify completion rule | ⬜ open | | |
| 4 | `stopReason` handling + auto-resume on turn-limit | ⬜ open | | |
| 5 | Output extraction (`--json`, `--text`, review files) | ⬜ open | | |
| 6 | `list` / `show` / `transcript` / `delete` | ⬜ open | | |
| 7 | `tests/test-ai-grok-review.sh` | ⬜ open | | |
| 8 | Shrink `skills/shared/grok-cli/SKILL.md` to point at the script | ⬜ open | | |
| 9 | Router + docs + memory entries | ⬜ open | | |
| 10 | Ship: commit, push, install on VPS + t16, live smoke test | ⬜ open | | |

**A fresh session starts at Step 1.** Nothing has been built yet. The only work
done so far is the SKILL.md documentation fix in commit `cfb5cd3`, which this
plan partially undoes (Step 8).

---

# Part 1 — Why

## 1. The ultimate goal — what we are actually trying to achieve

**In plain business English:** when Albert asks an AI session to "run this by
Grok," it should cost roughly what one review costs and come back with an
answer — every time, without the session having to know a dozen fragile details
about a third-party CLI.

Today it doesn't. On 2026-08-05 a single plan review on the `hetz` VPS burned
**~1.9 million tokens and ~$1.28** across five Grok sessions, of which two
produced nothing at all, because the calling session composed the Grok command
by hand and got several details wrong — details that are the *same every time*
and that a script can get right once.

What will be true when this is done that isn't true today:

- A session runs **one command** to review something with Grok. It does not
  choose flags, and therefore cannot choose them wrongly.
- A run that is still working is never mistaken for a run that died, so no
  session ever launches duplicate reviews at full price.
- A run that hit its turn limit says so in plain words and tells the caller how
  to continue, instead of returning a bare `cancelled` after a quarter-million
  tokens.
- Follow-up questions reuse the warm session automatically, so the cache
  savings we already measured actually get realised in practice.

**If a step in this plan conflicts with that goal, the goal wins — stop and
flag it.** In particular: if enforcing an invariant in the script turns out to
be impossible or to break a legitimate use, do **not** quietly fall back to
"document it in the skill instead." Documentation is exactly what already
failed. Stop and raise it.

## 2. What this application is

`u2giants/ai-devops` is Albert's AI DevOps toolkit — **100% Bash + Markdown**.
There is no app, no database, no container, no CI/CD. Do not go looking for
them or scaffold them.

- Canonical install location on any host: **`/worksp/ai-devops`**. Never
  `/opt/ai-devops`.
- `bin/*` holds the executable entrypoints. `install.sh` symlinks **every
  executable file** in `bin/` into `/usr/local/bin` automatically — there is no
  list to edit, but the file must be `chmod +x` with the git mode bit set.
- Real configuration lives in `/etc/ai-devops/*.env` and is never committed.
  Only `*.env.example` belongs in git.
- `skills/shared/` installs to **both** Claude and Codex; `skills/claude/` and
  `skills/codex/` are client-specific. `bin/ai-install-skills` does the routing.
- Machines in play: **`t16`** (Windows 11, this machine, PowerShell 7 + Git
  Bash) and **`hetz`** (Hetzner VPS, Ubuntu, ssh alias `vps`, users `root` and
  `ai`). Grok is installed on both — `C:\Users\ahazan2\.grok\bin\grok.exe` and
  `/home/ai/.local/bin/grok`, version **0.2.118**.

**Grok CLI** (branded "Grok Build", xAI) is one of several delegate AI CLIs the
toolkit drives headlessly for second opinions and reviews. The others are Codex
(`bin/ai-codex-review`), GLM (`bin/ai-glm`), DeepSeek (`bin/ai-deepseek-agent`),
Kimi, and Qwen. Grok is currently the **only** one of these driven by
hand-composed flags out of a skill document rather than by a wrapper script.
That is the anomaly this plan closes.

## 3. What triggered this work

On **2026-08-05**, a Claude session on `hetz` (running as user `ai`) used the
`grok-cli` skill to have Grok review an implementation plan plus a small server
package. Grok's *answers* were good. The *mechanics* failed repeatedly. The
session wrote up 14 findings. The ones that cost money:

| # | Symptom | Real cause |
|---|---|---|
| 2, 12 | The shell reported the command finished after ~25–30 s; the output file was 0 bytes; `ps` still showed Grok running; JSON appeared 1–3 min later | On Linux the tree is `bash → bwrap → grok-<ver>-linux-x86_64`. The wrapper the caller launched exits before the sandboxed binary finishes. **Exit status 0 with an empty file is the normal appearance of this bug.** One *completed* run (session `019fd4ae-339d-7a10-98b2-c96a08e38a43`, `handle_prompt.done ok:true` in Grok's own log) delivered zero bytes to its caller. |
| 3 | Two reviews ended `stopReason: "cancelled"` having produced only narration ("I'll read…", "Next I'll inspect…"), at 247,740 and 297,652 tokens | Default turn ceiling reached while still reading files. The same review completed once `--max-turns 20` was passed. Grok's log said `handle_prompt.done ok:true` for these too. |
| 4 | Resuming a cancelled session twice produced empty stdout and 0-byte files | Unconfirmed; likely the same detached-process bug, possibly compounded by resume-after-cancel being a bad state. |
| 5, 6 | Caller looked for a `result` field; there is none. Model id is absent at top level | Actual fields are `text`, `thought`, `sessionId`, `usage`, `modelUsage`, `stopReason`, `total_cost_usd`. `text` concatenates progress narration and the final answer. |
| 1 | `grok doctor` said "You are not authenticated"; `grok models` said "You are logged in with grok.com" minutes later with no login in between; the calls worked | `doctor` reads a different/stale auth state. |
| 7 | Session broadened permissions from read-only to `--permission-mode auto --allow Bash` chasing the cancellations | Wrong lever. A denied tool does **not** cancel a run — Grok says "Shell is blocked, so I'll stick to file reads and greps" and continues. It also destroyed the cached prefix. |

Observed session ids, for anyone who wants the raw evidence in
`/home/ai/.grok/logs/unified.jsonl` on `hetz`:

| Session | Result | Tokens | Cost |
|---|---|---|---|
| `019fd4aa-7c5a-7ff2-b29b-258156f06ad3` | cancelled, narration only | 247,740 | $0.2500 |
| `019fd4ac-c8cb-7983-ac2d-a4d84e3f0668` | cancelled, narration only | 297,652 | $0.2035 |
| `019fd4ad-8b7c-7623-976b-3efb4167e239` | completed (the good one) | 529,050 | $0.4614 |
| `019fd4ae-339d-7a10-98b2-c96a08e38a43` | completed, **output lost to caller** | — | — |

Total captured: ~1,919,352 tokens, ~$1.2822.

**What has already been done about it (commit `cfb5cd3`, 2026-08-05):**
`skills/shared/grok-cli/SKILL.md` was expanded 172 → 331 lines with a
"Non-negotiables" block, a `grok_wait` shell function, mandatory `--max-turns`,
the JSON field table, and the `grok doctor` correction. It is installed on
`hetz` for both `root` and `ai`, in both `.claude/skills` and `.codex/skills`
(all four copies verified at 331 lines).

**Why that is not enough, and why this plan exists.** A skill is advisory text
a session can skim, misread, or reasonably override when its own observations
contradict it — which is exactly what happened: the session started duplicate
runs because, by our own documentation, the first one looked dead. Two of the
three "the session went against the skill" cases were really "the skill left a
gap and the session filled it by guessing." A wrapper makes the invariants
structural instead of advisory.

## 4. Scope — in and out

**In scope:**

- A new `bin/ai-grok-review` Bash script that owns every Grok invocation.
- `tests/test-ai-grok-review.sh`, offline by default.
- Shrinking `skills/shared/grok-cli/SKILL.md` to "use the script, here's how to
  read its output," keeping only the knowledge the script cannot enforce.
- Router/doc/memory updates so the script is discoverable.
- Installing and smoke-testing on `t16` and `hetz`.

**NOT in scope — do not do these:**

- **Do not touch `bin/ai-glm`, `bin/ai-codex-review`, `bin/ai-deepseek-agent`,
  or any other delegate wrapper.** Borrow their patterns; change none of them.
- Do not build a PowerShell twin. The script is Bash and must run under Git
  Bash on Windows, exactly like `ai-glm`. (See §11 for the Windows constraints
  that makes.)
- Do not add Grok implementation/write mode in this plan. Read-only reviews
  only. `--worktree` delegation stays a documented manual path in the skill.
- Do not build an MCP server, a daemon, or a background service. Grok needs no
  server process; unlike GLM there is nothing to host.
- Do not attempt to fix Grok's own bugs or file anything upstream with xAI.
- Do not change any repo's CI, or add CI to this repo — it has none by design.
- Do not touch `/etc/ai-devops/*.env` contents or any credential.

---

# Part 2 — What we already know

## 5. Current state of the code

**Nothing of this script exists yet.** The whole of Step 1–7 is new work.

What exists and is relevant:

| Path | State | Why it matters here |
|---|---|---|
| `skills/shared/grok-cli/SKILL.md` | 331 lines, committed and pushed at `cfb5cd3`, installed on `hetz` (root + ai, Claude + Codex) and on `t16` | The source of every invariant this script must encode. Step 8 shrinks it. |
| `bin/ai-glm` | 33,706 bytes, working, in production | **The design template.** Named sessions, a state dir, a strict completion rule, a deliberately non-overridable prefix. Read it before writing a line. |
| `bin/ai-codex-review` | 5,927 bytes, working | The simpler precedent: mode-based, writes `.ai/reviews/<TS>-<MODE>.md`, prints the path. Its output convention is the one to copy. |
| `tests/test-ai-glm.sh` | working, offline-by-default with `AI_GLM_LIVE=1` for live probes | The test template. Copy the harness (`ok`/`bad`/`check`, `mktemp -d`, `trap cleanup EXIT`, state-dir override via env). |
| `install.sh` lines ~90–115 | working | Auto-symlinks every executable in `bin/`. **No edit needed** — but the new file must be executable in git (`git update-index --chmod=+x` if the mode bit is missing, which is easy to get wrong when authoring from Windows). |
| `AGENTS.md` line ~14, ~203, §"Documentation map" line 38 | current | Where the new command must be registered. |

Git state at the time of writing: `main` at `cfb5cd3`, clean, pushed.
`/worksp/ai-devops` on `hetz` also at `cfb5cd3`.

## 6. Key findings and root cause

The root cause of the whole 2026-08-05 incident, stated once:

> **Grok's headless CLI does not behave like a foreground process, and its exit
> status is not evidence of anything.** Every downstream failure — duplicate
> sessions, lost output, phantom "Grok returned nothing," wasted turn budgets —
> follows from a caller believing exit 0 means "finished."

The corollary that makes this fixable: **valid JSON with a terminal
`stopReason` is the only trustworthy completion signal**, and that check is
mechanical. It belongs in a script, not in a paragraph a session may skip.

Second finding, equally important: **Grok's own success log lies.**
`handle_prompt.done ok:true` appeared for runs that were `cancelled` and for a
run whose output never reached its caller. Do not build any completion logic on
`~/.grok/logs/unified.jsonl`. Use the JSON result only. (The log remains useful
for *human* diagnosis after a failure — Step 3 should point at it in error
messages.)

Third: **caching is real but the published numbers are the wrong order of
magnitude.** The skill's headline table (43,204 tokens fresh vs 22,720 resumed)
came from a one-question probe. Real reviews ran 250k–530k tokens per turn. The
*ratio* (−91% uncached input, −47% total) holds; the absolute scale does not.
Any figure this script logs or reports should be measured, never quoted from
the skill.

Fourth: **the default environment is enormous.** `grok inspect` on a normal
machine shows global CLAUDE instructions, project instructions, AGENTS, ~52
skills, ~10 MCP servers, hooks, and plugin agents loading into every call; a
successful review reported **26 prepared tools** and used `web_fetch` during a
purely local repository review. `--no-memory` disables memory only and slims
none of the rest. This is a real cost driver but **the flags to control it were
not verified to exist in 0.2.118** — see §13, open question 2.

## 7. Approaches considered and REJECTED

| Approach | Why rejected |
|---|---|
| **Do nothing more; the expanded SKILL.md is enough.** | This was tried and is the status quo as of `cfb5cd3`. It is a genuine improvement but leaves every invariant advisory. The 2026-08-05 session had a skill in front of it and still got the permission lever wrong; and its duplicate-session mistake was *rational* given the false "process finished" signal. Text cannot remove a false signal. |
| **Poll `~/.grok/logs/unified.jsonl` to detect completion.** | Rejected on evidence: that log reported `handle_prompt.done ok:true` for two `cancelled` runs and for one run whose output was lost. It is not a completion oracle. |
| **`pgrep`/process-tree watching as the primary completion signal.** | Rejected as primary. It is platform-specific (`pgrep` does not exist in Git Bash on Windows), racy (the leader may not have spawned yet when you first look), and unable to distinguish "still thinking" from "wedged." Keep it as *diagnostic output on failure only*. |
| **A fixed `sleep 180` after each call.** | Band-aid, explicitly against standing rule 10. Slow when the run is fast, still wrong when the run is slow. |
| **Wrap Grok in an MCP server, like `devops-mcp`.** | Massive overbuild for a single CLI. `ai-glm` needed a server because OpenCode is one; Grok is a plain binary. Also puts the invariants behind a network hop for no gain. |
| **A PowerShell script for Windows plus a Bash script for Ubuntu.** | Rejected: two implementations means two sets of invariants drifting apart, which is the exact failure mode being fixed. `ai-glm` proved one Bash script runs on both under Git Bash. This is a **locked** decision. |
| **Let callers pass through arbitrary Grok flags (`--` passthrough).** | Rejected. A passthrough is a drift hatch: the next session under pressure will pass `--permission-mode auto` through it, precisely as happened on 2026-08-05. `ai-glm` deliberately fixes model, agent, tools, and cwd at session creation for the same reason. This is a **locked** decision. |
| **Auto-retry a cancelled run with a doubled `--max-turns`, silently.** | Rejected as a silent failure (standing rule 11). Retrying *is* right, but it must be loud, opt-in per invocation, and bounded — see Step 4. |
| **Broadening permissions when a run returns no answer.** | Rejected on evidence. Verified: with Bash denied, Grok reported "Shell is blocked, so I'll stick to file reads and greps" and completed the review using `read_file`, `grep`, `list_dir`, `web_fetch`. Broadening is the wrong lever *and* it invalidates the cached prefix. |

## 8. Design decisions already made

All dated 2026-08-05. **Locked** = do not relitigate; **open** = implementer's
judgment.

| # | Decision | Status |
|---|---|---|
| D1 | One Bash script, `bin/ai-grok-review`, runs on Ubuntu and on Windows under Git Bash. | **Locked** |
| D2 | Model, permission set, `--no-memory`, and `--cwd` are fixed at session creation and are **not** overridable per call. Stable prefix = working cache; fixed permissions = no drift. | **Locked** |
| D3 | Completion is proven by valid JSON carrying a terminal `stopReason`, never by exit status, never by the Grok log. | **Locked** |
| D4 | `--max-turns` is always passed. There is no code path that omits it. | **Locked** |
| D5 | Read-only only. The script never enables Bash/Edit, never commits, pushes, merges, or deploys. | **Locked** |
| D6 | Sessions are named by the caller (`ai-grok-review new plan-review …`) and keyed by repo + caller + name, mirroring `ai-glm`, so Claude and Codex can use the same short name in one repo. | **Locked** |
| D7 | Turn-limit recovery is loud and explicit, never silent. | **Locked** |
| D8 | Default `--max-turns` value (proposal: 20, the value that worked; raise for `--deep`). | Open — pick and justify in a comment |
| D9 | Default wait timeout (proposal: 600 s; the longest observed successful run was ~200 s). | Open |
| D10 | Whether review output also lands in `.ai/reviews/` like `ai-codex-review`, or only in the state dir. Proposal: both — state dir for the transcript, `.ai/reviews/` for the human-readable result, matching the existing convention. | Open |
| D11 | Whether to add environment-slimming flags (`--no-skills` etc.). | Open, **blocked on verification** — see §13 Q2 |

---

# Part 3 — How to build it

Read `bin/ai-glm` end to end before Step 1. Most of what follows already exists
there in a working, tested form; this is deliberately a port, not an invention.

**Phase A = Steps 1–5** (the script proper). **Phase B = Steps 6–7** (ergonomics
and tests). **Phase C = Steps 8–10** (documentation and ship). A fresh session
can comfortably do Phase A in one context; cut between A and B if needed, and
re-read Steps 6–10 before starting each.

### Step 1 — Skeleton, argument parsing, `doctor`

**Files:** create `bin/ai-grok-review`.

Copy the header/idiom conventions from `bin/ai-glm` lines 1–50: `#!/usr/bin/env
bash`, `set -uo pipefail`, a banner comment stating this is the ONLY supported
way to call Grok, and `die`/`warn`/`note`/`need` helpers.

Subcommands (final surface, for reference while building):

```
ai-grok-review new <name> [--prompt T | --prompt-file F | stdin] [--max-turns N] [--deep]
ai-grok-review ask <name> [--prompt T | --prompt-file F | stdin] [--max-turns N]
ai-grok-review list | show <name> | transcript <name> | delete <name>
ai-grok-review doctor
```

`doctor` must:

- Resolve the binary (`command -v grok`) and print `grok --version`.
- Check auth with **`grok models`**, not `grok doctor` — the latter reported
  "You are not authenticated" while real calls worked. If `grok models` is
  ambiguous, fall back to a one-line headless probe. **A `grok doctor` failure
  alone must never be reported to Albert as "you need to log in."**
- Report the state dir, whether `jq` is present (hard requirement — `need jq`),
  and the resolved default `--max-turns` and timeout.

**Done when:** `bash bin/ai-grok-review doctor` on `t16` prints the Windows
binary path, `grok 0.2.118 (1e1687c1cf) [stable]`, and a logged-in verdict; and
`ai-grok-review` with no args prints usage and exits 2.

### Step 2 — Session state store, `new` and `ask`

**Files:** `bin/ai-grok-review`.

Port the state model from `bin/ai-glm` lines ~25 and ~85–140:

- `STATE_DIR="${AI_GROK_STATE_DIR:-$HOME/.local/state/ai-devops/grok}"` — the
  env override exists so the tests can redirect it.
- Session metadata at `$STATE_DIR/sessions/<repo_id>/<caller>--<name>.json`,
  holding: Grok `sessionId`, repo root, created/updated timestamps, the frozen
  flag set, cumulative token and cost totals, and the last `stopReason`.
- `CALLER` distinguishes Claude from Codex (see `ai-glm`'s handling).
- Atomic writes: temp file + `mv` on the same filesystem (`ai-glm` `write_meta`).
- The portable `mkdir`-based mutex from `ai-glm` lines ~111–131 — **`flock` does
  not exist in Git Bash**, and a crashed run must not wedge a session forever.

`new` freezes the flag set into the metadata. `ask` reads it back and reuses it
verbatim plus `--resume <sessionId>`. **There must be no code path by which
`ask` composes a different flag set than `new` did** (D2) — that is the whole
point. Prefer `--resume <id>` over `--continue`: `--continue` picks the newest
session for the directory, which is the wrong one whenever several AI sessions
share a repo.

**Done when:** `new` writes a metadata file whose `sessionId` matches the one
in Grok's JSON; a subsequent `ask` reuses it; and the test in Step 7 asserts
that the flag string recorded at `new` is byte-identical to the one used by
`ask`.

### Step 3 — Turn execution and the wait-and-verify completion rule

**Files:** `bin/ai-grok-review`. This is the heart of the change.

Every invocation redirects Grok's JSON to a temp file and then **waits**:

```
grok --cwd "$repo" [--resume "$sid"] --model grok-4.5 --single "$prompt" \
     --max-turns "$turns" \
     --permission-mode default --allow Read --allow Grep --deny Edit --deny Bash \
     --output-format json --no-memory > "$out"
await_result "$out" || <handle per Step 4>
```

`await_result` polls every 5 s until `jq -er .stopReason < "$f"` yields a value,
or the timeout (D9) expires. Terminal-success values: `end_turn`, `stop`,
`completed`. **Do not treat the command returning as completion. Do not treat a
non-empty file as completion** — it may be partially written; require `jq` to
parse it *and* a `stopReason` to be present.

On timeout the error must be loud and diagnostic, naming: the output path, the
elapsed time, the session id if known, `~/.grok/logs/unified.jsonl` as the place
to look, and the still-running processes. Guard the process listing so it works
on both platforms and never becomes the failure itself:

```
ps_diag() { pgrep -af grok 2>/dev/null || ps -W 2>/dev/null | grep -i grok || true; }
```

The exact `pgrep` fallback for Git Bash is the implementer's call — verify it on
`t16` rather than assuming.

**Done when:** a live run against a real repo returns only after the JSON is
complete; and a synthetic test (Step 7) that writes a 0-byte file, then a
partial file, then a complete one, proves `await_result` blocks through the
first two and succeeds on the third.

### Step 4 — `stopReason` handling and turn-limit recovery

**Files:** `bin/ai-grok-review`.

Branch on the terminal `stopReason`:

- `end_turn` / `stop` / `completed` → success.
- `cancelled`, or anything matching `max_turns*` → **turn budget exhausted.**
  Exit non-zero with a message in plain English that says what happened, that
  it is *not* a permissions problem, names the `sessionId`, and gives the exact
  command to continue at a higher limit. Per D7 this is loud, never silent.
- Anything else → fail loudly naming the unknown value; do not guess.

Optional `--auto-continue N` (default **off**): on a turn-limit stop, resume the
same session with `--max-turns` raised, at most N times, printing what it is
doing and the running cost before each retry. Off by default because a silent
retry of a 250k-token run is exactly the kind of invisible spend this whole
plan exists to stop.

Also handle the **empty resume** case: a resumed run that produces no output at
all was observed twice on 2026-08-05 after a cancellation. Detect it (timeout
with a zero-byte file on an `ask`, not a `new`), say explicitly that this is a
known 0.2.118 behaviour after a cancelled session, and tell the caller to start
a new session — do **not** start one automatically.

**Done when:** a deliberate `--max-turns 2` run on a large repo exits non-zero
with the recovery message and the session id, not with a bare `cancelled`.

### Step 5 — Output extraction and reporting

**Files:** `bin/ai-grok-review`.

From the result JSON extract, by these exact names (there is **no `result`
field**, and the top-level `model` is absent or null):

| Field | Use |
|---|---|
| `text` | The answer — **with progress narration prepended, not separated** |
| `thought` | Reasoning summary |
| `sessionId` | Persist to metadata for `--resume` |
| `stopReason` | Step 4's branch |
| `usage.input_tokens`, `usage.cache_read_input_tokens`, `usage.total_tokens` | Report every turn |
| `modelUsage` | Keys are the real model id, e.g. `grok-4.5-build` — assert on the `grok-4.5` prefix, never an exact string |
| `total_cost_usd` | Report every turn; accumulate in metadata |

Because `text` interleaves narration with the verdict, the script must **inject
a delimiter instruction into every prompt it sends** — e.g. requiring the reply
to end with a `## Verdict` section — and extract from that delimiter when
present, falling back to the whole of `text` (with a warning) when absent. This
is the script doing for the caller what the skill previously asked the caller to
remember.

Default human output: the extracted answer on stdout, and a one-line usage
summary on stderr (`tokens: … cached: … cost: $…`). `--json` emits the raw
result. Per D10, also write `.ai/reviews/<TS>-grok-<name>.md` in the target repo,
matching `ai-codex-review`, and print that path.

**Done when:** a live review prints a clean verdict with no "I'll read…"
narration above it, and the stderr line shows non-zero cached tokens on the
second turn of the same session.

### Step 6 — `list`, `show`, `transcript`, `delete`

**Files:** `bin/ai-grok-review`. Port directly from `ai-glm`'s equivalents.
`list` shows name, repo, session id, turns, cumulative tokens and cost, and last
`stopReason` — cost visibility is a feature here, since Grok is the only
delegate CLI that reports real money.

**Done when:** `list` shows a session created in Step 2 with an accurate
cumulative cost after two turns.

### Step 7 — Tests

**Files:** create `tests/test-ai-grok-review.sh`, modelled on
`tests/test-ai-glm.sh` (same `ok`/`bad`/`check` harness, `mktemp -d`, `trap
cleanup EXIT`, `AI_GROK_STATE_DIR` redirected to the temp dir).

**Offline by default; live probes only under `AI_GROK_LIVE=1`.** Offline tests
must not invoke the real `grok` binary — stub it via a fake on `PATH`.

Required cases, by name:

1. `usage_and_exit_codes` — no args → usage, exit 2; unknown subcommand → exit 2.
2. `max_turns_always_present` — grep the composed command for `--max-turns` on
   both the `new` and `ask` paths. **This test is the enforcement of D4.**
3. `permissions_are_fixed` — the composed command always contains
   `--permission-mode default --allow Read --allow Grep --deny Edit --deny Bash`
   and never `--permission-mode auto`, `--allow Bash`, or `--always-approve`.
4. `no_flag_passthrough` — an attempt to pass an arbitrary Grok flag is rejected,
   not forwarded (D2, and the anti-drift-hatch decision in §7).
5. `prefix_stable_across_turns` — the flag string recorded at `new` is
   byte-identical to the one used by `ask`.
6. `await_blocks_on_empty_then_partial_then_complete` — the Step 3 synthetic
   fixture. **This is the regression test for the entire incident.**
7. `stop_reason_cancelled_is_failure` — a fixture with
   `{"stopReason":"cancelled"}` exits non-zero and the message mentions the turn
   limit and the session id.
8. `stop_reason_unknown_is_failure` — an unrecognised value fails loudly.
9. `json_field_extraction` — a fixture with the real field shape yields the right
   answer, tokens, and cost; and a top-level `model` of `null` does not break it.
10. `model_prefix_assertion` — `modelUsage` key `grok-4.5-build` satisfies the
    `grok-4.5` prefix check.
11. *(live, `AI_GROK_LIVE=1`)* `live_round_trip` — a real two-turn session in a
    scratch repo; asserts a terminal `stopReason`, a non-empty answer, a reused
    `sessionId`, and non-zero `cache_read_input_tokens` on turn two.

Existing suites that must stay green — run all of them, this repo has no CI to
catch a regression:

```bash
bash tests/test-ai-glm.sh
bash tests/test-ai-install-skills.sh
bash tests/test-ai-memory-sync.sh
bash tests/test-windows-scripts.sh
```

**Done when:** `bash tests/test-ai-grok-review.sh` reports 0 failures on both
`t16` (Git Bash) and `hetz`, and the four suites above are still green.

### Step 8 — Shrink `skills/shared/grok-cli/SKILL.md`

**Files:** `skills/shared/grok-cli/SKILL.md` (currently 331 lines at `cfb5cd3`).

Rewrite so the script is the only documented path. **Keep** — these are things a
script cannot enforce:

- How to write a good Grok brief (self-contained, no secrets, no pasted file
  contents — Grok reads files itself and pasted text churns the prefix).
- One session per workstream, *as a usage habit*: `new` once, `ask` after.
- The corrected cost scale (250k–530k tokens per real review turn), so nobody
  quotes the old 43k figure.
- The `grok doctor` auth caveat, since a human may still run it by hand.
- The `--worktree=<name>` implementation path **and its mandatory cleanup gate**
  (`grok worktree remove <name>` then `grok worktree list` must no longer show
  it) — out of scope for the script, so the manual instructions must survive.
- The Windows caveat that `--sandbox read-only` is Linux/macOS only.
- Reporting duties: label Grok's conclusions separately from your own; capture
  `usage` from every turn.

**Delete or reduce to one line** — now enforced by the script: the `grok_wait`
shell function, the hand-composed command snippets, the `--max-turns` argument
block, the JSON field table, the permission-flag detail.

Add at the top, unmissable: *"Never invoke `grok` directly. Use
`ai-grok-review`. If it seems to be missing a capability you need, say so —
do not hand-compose a `grok` command."*

**Done when:** the skill is materially shorter than 331 lines, contains no
copy-pasteable bare `grok --single` invocation for review work, and a reader
following it literally cannot reproduce any of the 2026-08-05 failures.

### Step 9 — Discoverability

**Files:** `AGENTS.md`, `docs/skills-usage-guide.md`,
`docs/codex-skills-usage-guide.md`, `docs/skills-map.md`, plus a memory entry.

- `AGENTS.md` line ~14 (the intro list of commands) and line ~203 (the
  "Installed commands" table): add `ai-grok-review`.
- `AGENTS.md` §"Documentation map" (line 38): add a row — *"Touch Grok,
  `ai-grok-review`, or the Grok skill → `AGENTS.md`, `bin/ai-grok-review`,
  `skills/shared/grok-cli/SKILL.md`, `tests/test-ai-grok-review.sh`,
  `plan_ai-grok-review.md`"* — mirroring the existing GLM row's shape.
- Write `memory/ai-devops/grok-headless-early-return.md` (frontmatter per the
  memory format: `name`, `description`, `metadata.type: project`) recording the
  early-return bug, that exit status is not evidence, and that
  `ai-grok-review` is the only supported entry point. Add the one-line pointer
  to `memory/ai-devops/MEMORY.md`. Link `[[grok-headless-early-return]]` from
  any related entry.
- Update this plan's STATUS table as steps land.

**Done when:** `grep -rn 'ai-grok-review' AGENTS.md docs/ memory/` returns hits
in every file listed above.

### Step 10 — Ship

1. `git status` first; stage only your own hunks (other AI sessions share these
   checkouts).
2. Verify identity before the first commit:
   `git var GIT_COMMITTER_IDENT` must be
   `Albert Hazan <u2giants@users.noreply.github.com>`. Fix it **before**
   committing if wrong — correcting it afterwards means rewriting history.
3. Ensure the executable bit is set in git (authoring from Windows drops it):
   `git update-index --chmod=+x bin/ai-grok-review` and confirm with
   `git ls-files -s bin/ai-grok-review` showing mode `100755`. **If this is
   wrong, `install.sh` silently skips the file and the command never appears on
   PATH.**
4. Commit with the `Co-Authored-By: Claude Opus 4.8` trailer; push to `main`.
5. On `hetz` (`ssh vps`): `git -C /worksp/ai-devops pull --ff-only`, then run
   `/worksp/ai-devops/install.sh` (or re-link) so `/usr/local/bin/ai-grok-review`
   exists, and `bin/ai-install-skills` as **both** `root` and `ai` so the
   shrunk skill reaches all four copies. Verify with
   `wc -l ~/.claude/skills/grok-cli/SKILL.md` for each.
6. Live smoke test as user `ai` on `hetz`: a real two-turn review of a small
   repo. Record the session id, both turns' tokens/cost, and confirm turn two
   shows meaningful `cache_read_input_tokens`.
7. Report with evidence: commit SHA, the test output, and the live smoke-test
   numbers.

**Done when:** `ai-grok-review doctor` runs from a bare login shell on `hetz`
as `ai` and on `t16` in Git Bash, and the smoke test produced a real verdict.

## 10. Tests required

Specified by name in Step 7 above. The two that matter most, and that must not
be weakened or deleted by a later session:

- `await_blocks_on_empty_then_partial_then_complete` — the regression test for
  the early-return bug that caused the whole incident.
- `max_turns_always_present` and `permissions_are_fixed` — these are the
  executable form of D2 and D4. If a future change makes them fail, the change
  is wrong, not the tests.

## 11. Constraints, standing rules, and gotchas in force

**Repo and standing rules:**

- **Main-only, no branches** for `u2giants` app repos including this one.
  Commit → push → verify. A local-only commit is not "done" (rule 18).
- **No band-aids** (rule 10). No `sleep 180`, no "good enough for now."
- **No silent failures** (rule 11). Every fallback alerts loudly. When you find
  one silent failure, sweep for the same pattern.
- **Nothing hard-coded that should be configurable** (rule 12) — but note D2
  deliberately makes the *safety* flags non-configurable. Configurable means
  timeouts, turn limits, and state paths; not the permission set.
- **Add unit tests for the code you create** (rule 13). Step 7 is not optional.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8`. Push with the
  `@users.noreply.github.com` email — the private gmail address is blocked by
  GitHub's email-privacy protection.
- **Do not mention or use Fable** (repo CLAUDE.md).
- New skills go in `skills/shared/` by default. Not applicable here (no new
  skill), but relevant if you are tempted to add one.
- N/A but stated so nobody wonders: this work touches **no database**, so the
  `shared-db` rule does not apply; and **no UI**, so the visual-verification
  rule does not apply.

**Grok- and platform-specific gotchas:**

- `flock` does not exist in Git Bash — use the `mkdir` mutex from `ai-glm`.
- `pgrep` does not exist in Git Bash — guard every process-listing call.
- The git executable bit is dropped when authoring from Windows; Step 10.3.
- `--sandbox read-only` enforces nothing on Windows: the installed docs list OS
  sandbox support for Linux and macOS only. Permission rules are the control.
- `-s/--session-id` names a **new** session; it does not resume. `--fork-session`
  mints a new id and throws away the warm prefix — never pass it.
- Usage reports the model as `grok-4.5-build` while `--model grok-4.5` is what
  you pass. Compare on the prefix.
- `~/.grok/` is Grok's home. **Never read or print `~/.grok/auth.json`.**
- Installed docs worth consulting, versioned with the binary:
  `~/.grok/README.md`, `~/.grok/docs/user-guide/14-headless-mode.md`,
  `17-sessions.md`, `22-permissions-and-safety.md`, `18-sandbox.md`,
  `~/.grok/CHANGELOG.md`. Also `grok --help` — the CLI surface changes between
  versions, so re-verify rather than trusting any statement here, **including
  this one**.
- These findings are all from **0.2.118**. If the installed version differs when
  you start, re-verify the JSON field names and the early-return behaviour
  before assuming this plan still describes reality.

## 12. Access and environment

- **Machines:** `t16` (this Windows box; PowerShell 7 primary, Git Bash
  available at `C:\Program Files\Git\usr\bin\`) and `hetz` (Ubuntu VPS).
- **SSH to the VPS:** alias **`vps`** (also `coolify`, `hetzner`) — user `root`,
  key `~/.ssh/916-alien`, host `100.66.37.58` with a Cloudflare-tunnel fallback.
  **The alias `hetz` does not exist in `~/.ssh/config`** — using it fails with a
  host-key error, which is easy to misread as a permissions problem. Reach user
  `ai` via `ssh vps 'su - ai -c "…"'`; direct `ai@` key auth is not set up.
  On Windows use Git's ssh in place (`C:\Program Files\Git\usr\bin\ssh.exe`) —
  never copy it out (msys DLLs), never overwrite system OpenSSH.
- **Repo checkouts:** `C:\repos\ai-devops` on `t16`; `/worksp/ai-devops` on
  `hetz`. Both at `cfb5cd3`.
- **Grok:** installed and authenticated on both — `C:\Users\ahazan2\.grok\bin\
  grok.exe` and `/home/ai/.local/bin/grok`, both **0.2.118**. No credential work
  is needed for this task. If auth *does* appear broken, remember §3 finding 1
  before concluding anything.
- **Authenticated CLIs on Albert's machines:** `gh`, `gcloud`, `az`, `supabase`,
  `vercel`, `op`. Verify with a real call before claiming a capability is
  missing.
- **Secrets:** none required. If one becomes necessary, it is in 1Password vault
  `vibe_coding` (MCP), referenced by vault + item title only — never by value,
  never pasted into a file or commit. Serialize `op` reads; never fan them out
  in parallel.
- **No test login, no server, no browser** is needed for this work.

---

# Part 4 — Landing it

## 13. Definition of done, risks, and open questions

**Definition of done — every box:**

- [ ] `bin/ai-grok-review` exists, is executable in git (mode `100755`), and
      implements Steps 1–6.
- [ ] `tests/test-ai-grok-review.sh` passes with 0 failures on `t16` and `hetz`.
- [ ] `tests/test-ai-glm.sh`, `test-ai-install-skills.sh`,
      `test-ai-memory-sync.sh`, `test-windows-scripts.sh` still green.
- [ ] `skills/shared/grok-cli/SKILL.md` shrunk per Step 8 and reinstalled on
      `hetz` for `root` and `ai`, Claude and Codex (all four verified).
- [ ] `AGENTS.md`, the two skills-usage guides, `docs/skills-map.md`, and a
      memory entry all reference `ai-grok-review`.
- [ ] Committed with the correct identity and trailer, **pushed to `main`**.
- [ ] `/usr/local/bin/ai-grok-review` resolves on `hetz`; `doctor` runs clean on
      both machines.
- [ ] Live two-turn smoke test done, with session id, tokens, and cost recorded.
- [ ] This plan's STATUS table updated, and a `HANDOFF.d/<UTC>-<machine>-<agent>-
      grok-review-wrapper.md` written (write-once; never rewrite the root
      `HANDOFF.md`, which is a static pointer).
- [ ] Report to Albert carries evidence: commit SHA, test output, smoke-test
      numbers.

**Risks and rollback:**

| Risk | Mitigation / rollback |
|---|---|
| The wrapper is more annoying than hand-composing, so sessions bypass it | Keep the surface tiny (`new`/`ask` cover ~95% of use) and make the skill say plainly that a missing capability is something to report, not to route around. If it still gets bypassed, that is a design failure worth raising, not papering over. |
| Grok 0.2.119+ changes the JSON shape or fixes the early-return bug | The wait logic is harmless if the bug is fixed (the first poll succeeds). Field extraction is the fragile part — `json_field_extraction` fails loudly rather than returning empty. Re-verify against `grok --help` and `~/.grok/CHANGELOG.md` on any version bump. |
| Rollback | Everything is additive except Step 8. Revert the commit; the previous 331-line skill returns and hand-composed calls work exactly as they do today. No state, no service, no data to unwind. |
| Concurrent AI sessions editing these checkouts | Check `git status` before staging; stage only your own hunks; never clobber another session's uncommitted work (rule 19). |

**Open questions — decide these, don't stall on them:**

1. **D8/D9 — default `--max-turns` and timeout.** Proposal: 20 turns (the value
   that demonstrably worked) and 600 s (longest observed successful run ~200 s).
   Decide by measuring one real review; a comment in the script must say why.
2. **D11 — environment slimming.** The 2026-08-05 write-up *suggested* flags
   like `--no-project-mcps`, `--no-user-mcps`, `--no-skills`, `--no-plugins`,
   `--tools Read,Grep` as things Grok *should* have. **It is not established
   that 0.2.118 supports any of them.** Run `grok --help` first. Add only the
   flags that actually exist and that you have verified change `grok inspect`
   output; do not pass invented flags, and do not claim a token saving you have
   not measured.
3. **D10 — `.ai/reviews/` output.** Proposal: yes, matching `ai-codex-review`.
   Confirm the target repo's `.gitignore` covers `.ai/` before writing there.
4. **`--auto-continue` default.** Proposal: off. Revisit only if turn-limit
   stops turn out to be common in practice with a sane default limit.

---

## Self-audit (Mode A gate — run 2026-08-05, passed)

**1. Could a brand-new AI session with no project knowledge and no context from
this conversation execute this plan to perfection, without asking anything?**
Yes. §2 explains what the repo is and where it lives on both machines; §3 gives
the triggering incident with session ids, token counts, and the exact cause of
each symptom; §5 names every existing file to read with its size and role and
states plainly that nothing of the script exists yet; §9 names files, functions,
and line ranges to port from; §12 supplies machines, paths, the ssh alias, and
the `hetz`-is-not-an-alias trap that cost time in this very session. The one
genuine unknown — whether environment-slimming flags exist in 0.2.118 — is
labelled as open question 2 with instructions to verify rather than guess.

**2. Does the plan carry every piece of background, nuance, and reasoning I
currently hold, including what was ruled out and why?** Yes. §7 records nine
rejected approaches, each with the evidence that killed it — including the two
non-obvious ones a fresh session would otherwise walk into: polling Grok's own
log (which lies) and using process-watching as the primary completion signal
(platform-specific and racy). §6 states the root cause once, plus the three
secondary findings. §8 labels seven decisions locked and four open, so the
implementer knows exactly where their judgment is wanted. §11 carries the
platform traps — Git Bash lacking `flock` and `pgrep`, the dropped executable
bit — that would each cost a debugging cycle.

**3. Is the ultimate goal stated clearly enough for a correct judgment call if a
step turns out wrong?** Yes. §1 states it in business terms with the money
figure attached, and adds the specific steer this plan needs: if enforcing an
invariant in the script proves impossible, **do not fall back to documenting it
in the skill** — that is precisely what already failed. That instruction
resolves the most likely wrong turn an implementer could take.

**Checklist:** all 13 sections present; goal in plain business English up top
with the conflict rule; no question needed; rejections recorded; every step
names files and carries a verification gate; locked vs open labelled; explicit
out-of-scope list; tests named individually; every identifier defined; no secret
values anywhere; definition of done includes commit, push, install, and live
verification. **All items pass.**
