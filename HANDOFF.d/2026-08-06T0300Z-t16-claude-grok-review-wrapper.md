# Handoff — `ai-grok-review` shipped; Kimi/GLM parity gaps found and NOT fixed

**Session:** 2026-08-05/06, machine `t16`, agent Claude Opus 4.8, repo
`u2giants/ai-devops` branch `main`. **Everything in this session is committed and
pushed.** Head at handoff: `733402b`.

## 1. What this was about

Albert asked whether a Grok problem report from another session matched our setup.
It did. That report described a Grok delegation on `hetz` that burned **~1.9M tokens
and ~$1.28** across five sessions, two of which returned nothing, because the calling
session hand-composed `grok` flags out of a skill document and got several wrong.

## 2. What shipped (all done, all verified)

| Commit | What |
|---|---|
| `cfb5cd3` | Expanded `skills/shared/grok-cli/SKILL.md` 172 → 331 lines with the missing invariants |
| `f93842e` | `plan_ai-grok-review.md` — implementation plan for a wrapper |
| `e0096f0` | Applied GLM 5.2's review of that plan |
| `493b091` | **`bin/ai-grok-review`** + `tests/test-ai-grok-review.sh` |
| `733402b` | Shrank the skill 331 → 118 lines; router + memory |

`bin/ai-grok-review` is now the only supported way to call Grok for a review. It
proves completion from a terminal `stopReason` in parsed JSON (never exit status),
always passes `--max-turns`, freezes the read-only permission set, refuses a second
concurrent review per repo, and refuses to forward arbitrary `grok` flags.

**Verified:** 50 offline assertions + 4 live, 0 failures, on both `t16` (Git Bash)
and `hetz`. Live two-turn round trip reused the session and read **22,912 tokens
from cache** on turn 2. `ai-grok-review doctor` runs clean as both `root` and `ai`
on `hetz` and on `t16`. Installed at `/usr/local/bin/ai-grok-review`; the skill is
at 135 lines in all four locations (root/ai × Claude/Codex).

## 3. What we tried that did NOT work

- **Documentation alone (`cfb5cd3`) was not enough, and that is the whole lesson.**
  The failing session *had* a skill in front of it. Two of its three deviations were
  really "the skill left a gap and the session guessed"; its duplicate-session
  mistake was *rational* given a false "process finished" signal. You cannot
  document away a misleading exit status.
- **GLM's fast-fail-when-no-process suggestion, as stated, is dangerous** — and the
  regression test caught it. The orphaned worker is named `grok-<version>-<arch>`
  under `bwrap`, not `grok`, so a detection miss aborts a *healthy slow run* and
  reintroduces "Grok returned nothing" as a self-inflicted bug. It now fast-fails
  only if a process was **positively seen earlier in the same wait** and then
  vanished. **Do not remove that guard.**
- **Polling `~/.grok/logs/unified.jsonl` for completion — rejected on evidence.** It
  reported `handle_prompt.done ok:true` for two `cancelled` runs and for one whose
  output never reached its caller. It is not an oracle.
- **`grok doctor` as an auth check — it never was one.** `grok --help` shows it
  checks "terminal, clipboard, color, and input support." That fully explains the
  "not authenticated while calls worked" contradiction in the original report.
- Five other plan assumptions were overturned by actually running `grok --help`
  before coding. They are tabulated in `plan_ai-grok-review.md` STATUS and in the
  script's `STEP 0 VERIFICATION` header. **Re-run that verification on any Grok
  version bump.**

## 4. OPEN — the parity gaps this session found but did NOT fix

These came out of Albert's last two questions and are the natural next task.

### 4a. The Kimi skill has the same class of gap the Grok skill had

`skills/shared/kimi-code-delegation/SKILL.md` is markedly better than the old Grok
skill — it has a copy-paste block, forbids `-c/--continue` with a measured failure,
and is honest that Kimi reports no usage or model. But:

- **No completion verification at all on follow-up calls.** The first call at least
  fails loudly if no session id is captured; `kimi -r "$sid" -p "$next"` has no
  check whatsoever that the output is complete or non-empty.
- **No turn/step bound** — no `--max-turns` equivalent is documented, and whether
  Kimi has one is unverified.
- **The planning call's read-only status is prompt-enforced only.** The skill says
  so honestly and mandates `git status` after, but unlike a Grok review (`--deny
  Edit`) there is no structural guarantee, and Kimi *can* write files. This is
  arguably a worse exposure than anything in the Grok incident.
- **No wrapper.** Kimi is now the only delegate CLI still driven by hand-composed
  commands out of a document — the exact anomaly `ai-grok-review` just closed.

A `bin/ai-kimi` modelled on `ai-grok-review`/`ai-glm` is the obvious fix. Not
started. Verify Kimi's actual flag surface first (Step 0 discipline) — the same
"verify before you build" rule that overturned five assumptions here.

### 4b. Root/ai parity is real but incomplete on `hetz`

The **skills** (markdown) are installed for both `root` and `ai`, in both
`.claude/skills` and `.codex/skills`. The **underlying CLIs are not:**

| Tool | `ai` | `root` |
|---|---|---|
| `ai-grok-review` | works | **works** (binary resolution finds `/home/ai/.local/bin/grok` off-PATH) |
| `grok` | `/home/ai/.local/bin/grok` | not on PATH (handled by the wrapper) |
| `ai-glm` | works — health endpoint answers, model `glm-5.2` available | **BROKEN — 17 doctor failures**, "no service on this machine - setup never finished" |
| `kimi` | installed at `/home/ai/.kimi-code/bin/kimi` but **not on `ai`'s PATH** | **not installed at all** |

So: a session running as `root` on `hetz` that follows the `ask-glm` skill will
fail, and either user following the Kimi skill will fail on `command -v kimi`.
Fixes are (i) run `bin/setup-opencode-glm.sh` as root or scope GLM to `ai` and say
so in the skill, and (ii) put `~/.kimi-code/bin` on PATH and install Kimi for root
or scope it. **Neither is done.** Decide scope-vs-install with Albert first — it may
be correct to declare `ai` the only agent user on that box.

## 5. Things a fresh session must not undo

- The completion rule, `--max-turns`, the frozen permission set, the per-repo lock,
  and the no-passthrough rule in `bin/ai-grok-review`. Each guards a failure that
  cost real money. `tests/test-ai-grok-review.sh` is their executable form — if a
  change makes `max_turns_always_present`, `permissions_are_fixed`, or
  `await_blocks_until_terminal_json` fail, **the change is wrong, not the test.**
- The `AGENTS.md` documentation-map row points at the script, skill and test — not
  at the plan file, deliberately (a plan goes stale once executed).

## 6. Environment notes that cost time this session

- **The ssh alias is `vps` (also `coolify`, `hetzner`) — `hetz` is NOT an alias**
  and fails with a host-key error that reads like a permissions problem. Reach the
  agent user via `ssh vps 'su - ai -c "…"'`; direct `ai@` key auth is not set up.
- `tests/test-ai-install-skills.sh` fails on `FAIL: migration warning missing`.
  **This is pre-existing** — verified by stashing all local changes and re-running.
  Unrelated to this session; worth its own look.
- Another AI session has uncommitted work in `C:\repos\ai-devops` (`bin/ai-glm`,
  `docs/glm-opencode.md`, `plan_ai-glm-permission-deadlock.md`,
  `skills/shared/ask-glm/SKILL.md`, `tests/test-ai-glm.sh`). It was left untouched;
  all commits here were path-limited. Do not clobber it.

## 7. Where to start

Read `bin/ai-grok-review`'s STEP 0 header, then `plan_ai-grok-review.md` STATUS (do
not re-plan from the body — it is a reasoning record of completed work). Then pick
up §4a (a `bin/ai-kimi` wrapper) or §4b (root/ai parity), whichever Albert wants.
