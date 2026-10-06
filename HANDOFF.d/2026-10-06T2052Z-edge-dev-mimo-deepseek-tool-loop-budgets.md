---
issue: 1339
status: OPEN
owner: mimo/deepseek-token-volume-cut
---

# HANDOFF — DeepSeek multi-round token cut landed; formal receipt left

Machine: edge-dev · Agent: mimo · Written: 2026-10-06 4:52 PM EST
GitHub signature: `Posted by MiMo chat ses_ffe5ef228b798ffeCjeLl1O3nO on edge-dev`

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

**None — nothing in this workstream needs the owner.** The token cut is live; the
remaining work is technical paperwork on issue #1339.

**Already settled — do NOT re-ask:**

- DeepSeek is cheap; multi-round tool loops were the token burn. Fix shipped in
  PR #1317 (2026-10-06). Owner: "don't stop working until this is 100% fixed and
  live everywhere" (2026-10-06) — that is done for live budgets on all hosts.
- Codex is out of the **allocator rotation** but remains the **approval gate**
  for independent exact-head reviews (`ai-review codex`). Owner asked about this
  2026-10-06; answer confirmed against `config/reviewer-registry.json` and
  `docs/reviewer-rotation-rules.md`.
- Open a tracking issue for the formal receipt rather than relying on memory
  (owner, 2026-10-06) → issue #1339.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's public AI workflow recovery toolkit (not an
app/service). It hosts reviewer wrappers (`bin/ai-*`), task gates, installers,
and docs. GitHub: `https://github.com/popcre/ai-devops`. Local primary checkout:
`C:/repos/ai-devops` (landing-only). The DeepSeek reviewer path is
`bin/ai-deepseek-agent` (API wrapper) and `tools/deepseek_repo_tools.py`
(tool loop).

## 2. What we set out to do this session, and why

Albert saw DeepSeek burn tokens far faster than a "very cheap model" should
(~0.8–1.1M input tokens per formal review). Goal: diagnose the setup and cut
multi-round token volume drastically, then make the fix live everywhere.

Technical objective: shrink what each paid tool-loop round resends (history
compaction), tighten tool budgets, and stop inlining large source bodies when
repository tools can re-read them — without weakening review safety.

## 3. Current state — what is true right now

| Outcome | State | Artifact |
|---|---|---|
| Token-volume cut code | **Done, merged** | PR https://github.com/popcre/ai-devops/pull/1317 · merge `5149ba76d9fc9ecb64b6eef7f39278986b0c35f8` |
| Live on edge-dev | **Verified** | `C:/repos/ai-devops` tip `73cf671`; `MAX_ROUNDS=8`, `MAX_TOOL_CALLS=16`, `MAX_OUTPUT_CHARS=8000`, `COMPACT_BUDGET_CHARS=24000` in `tools/deepseek_repo_tools.py`; `ai-deepseek-agent doctor` PASS |
| Live on edge-dev3 | **Verified** | `ssh -i ~/.ssh/916-alien ahazan@edge-dev3` → `/home/ahazan/repos/ai-devops` at `73cf671`, same constants, `test_deepseek_repo_tools.py` all passed |
| Live on hetz | **Verified** | `ssh vps2-direct` → `/worksp/ai-devops` fast-forwarded `cceeab1`→`73cf671`, same constants, tests all passed |
| Formal `authorize-install` receipt | **NOT done** | Issue **#1339**; launchers still record source `6bb1846` |
| Reviewer issue (Codex sandbox evidence) | **OPEN** | `20261006T123753Z-edge-dev-codex-950377` under `.ai/reviewer-issues/` |

What the change does (landed):

- `tools/deepseek_repo_tools.py`: default `MAX_ROUNDS` 16→8, `MAX_TOOL_CALLS`
  40→16, `MAX_OUTPUT_CHARS` 60000→8000, `MAX_GREP_MATCHES` 200→40;
  `compact_tool_messages()` stubs older tool results over a 24k-char keep-budget
  (stable stubs, keeps at least one full result, never grows a short result).
- `bin/ai-deepseek-agent`: formal reviews attach MANIFEST/identity/patch +
  small evidence files; large source bodies become an inventory (path/size/sha)
  for repository tools to re-read. Symlinks recorded, not followed. Truncated
  attachments carry **full-file** SHA256 and label the prefix hash. Identity
  packet is never truncated. Review copy is never mutated (no `review-evidence.patch` injection).
- Tests: `tests/test_deepseek_repo_tools.py` (compaction, caps), and
  `tests/test-ai-deepseek-agent.sh` (inventory of large sources).

## 4. Everything we tried that did NOT work

1. **Codex review while main still held #1317 branch head** — first final-check
   REJECTED for (a) inventory following symlinks, (b) truncated-attachment hash
   hashing only the prefix while claiming full-file identity, (c) compaction
   `keep=0` keeping everything via `[-0:]` slice. Fixed in `1b4a5c1`.
2. **Copying `review-evidence.patch` into the tools workspace** so a truncated
   patch stayed readable — Codex REJECTED: mutates the supposedly exact review
   copy / can overwrite a real source file. Removed in `bb9762c`. Also stopped
   truncating MANIFEST/identity and stopped claiming hidden bytes are tool-readable.
3. **`authorize-install` with the `bb9762c` APPROVE** — gate STOP: approval does
   not bind the **exact** deploy target (`19de73a5` / later tips). Tree-equivalent
   ancestor reports are refused.
4. **Install candidate already at target when `start --class installation` ran** —
   `start_head == target_head` → "Empty release needs an installed receipt or
   explicit reviewed legacy migration." Must declare at the **old installed HEAD**
   (`6bb1846`) then advance to the tip.
5. **Codex final-check of later main tips** — reports land as `*.stale` with
   REJECT of **unrelated** main commits (gemini qualification-store overwrite;
   stepfun plan/handoff class + owner wipe exception). That is why the receipt
   cannot bind today's tip. See #1339.
6. **Orphan sandbox sweep noise** — `sandbox evidence requirement is missing` /
   `required report is not durably published` on many old snapshots (known open
   reviewer-incident class; see handoff `2026-10-05T2205Z-edge-dev-mimo-reviewer-issues-after-watchdog.md`).
   Not repaired this session (scope freeze / not needed for live budgets).

## 5. Root causes and key findings

1. **Token burn was multi-round amplification, not a bad model pin.** Measured
   sessions (2026-09-29, 2026-10-02): 0.8M and 1.1M prompt tokens across 13–15
   tool rounds; cache already hit 77–93% (`prompt_cache_hit_tokens`). Every tool
   result and every attached source file stayed in the message and was resent
   each round.
2. **Two DeepSeek paths:** `ai-deepseek` = OpenCode implementer (persistent
   session); `ai-deepseek-agent` = own Chat Completions wrapper for reviews /
   second opinions. The wrapper **intentionally resends full history** every
   turn (no native resume). Model hard-pinned `deepseek-flash` (V4.1 Flash).
3. **Formal reviews attached full source bodies** (`prepare_review_source` →
   `with_files_appended`) even when `--review` tools could read the snapshot.
   Session 1's first user message was ~84k chars.
4. **Cache-preserving cuts win:** fewer rounds, smaller tool outputs, inventory
   large files, compact only old tool results with **stable** stubs. Rewriting
   the prefix would bust DeepSeek's automatic cache.
5. **`ai-task-gates authorize-install`** wants an APPROVE bound to the exact
   fetched `origin/main` at authorize time; start_head must be the pre-update
   installed HEAD. Windows launcher path: `C:/Users/ahazan/.local/bin/ai-task-gates`.
6. **Codex as reviewer:** out of shared-db **allocator** rotation; still the
   **approval-gate** wrapper (`config/reviewer-registry.json`, `outside_allocator`
   in `config/reviewer-membership-scope.json`). `ai-review codex final-check
   --implementer mimo` is the correct independence path for MiMo-implemented
   reviewer-safety work.

## 6. Exact next steps

1. After gemini and stepfun findings on main are fixed or reverted (separate
   work), take issue **#1339**.
   - You'll know it worked when: `gh issue view 1339` can be closed with an
     authorize-install + installer proof comment.
2. Fetch `origin/main`; record the **current** launcher receipt old HEAD (read
   `source-sha=` from `~/.local/bin/ai-task-gates`).
3. Fresh linked worktrees: install candidate at that old HEAD, reviewer candidate
   at the clean tip. `start --class installation` on the install candidate, then
   advance **only** that candidate to the tip.
4. Codex exact-head `final-check` with focused suites
   (`test_deepseek_repo_tools.py`, `test-ai-review-packet.sh`,
   `test-ai-review-preflight.sh`) → APPROVE of the tip SHA.
5. `bin/ai-task-gates authorize-install --target-head <tip>
   --installed-checkout C:/repos/ai-devops
   --installed-launcher C:/Users/ahazan/.local/bin/ai-task-gates
   --review-report <APPROVE.md> --reviewer-approval <APPROVE.md>`.
6. Windows: `bin/install-ai-devops-windows.ps1 -RepoPath C:/repos/ai-devops
   -ExpectedHead <tip>`. Then verify launcher `source-sha=` and routing hashes.
   - You'll know it worked when: receipts show the tip SHA and
     `ai-deepseek-agent doctor` still PASS.
7. Optionally resolve reviewer issue `20261006T123753Z-edge-dev-codex-950377`
   once durable-publish / orphan evidence is repaired (see the 2026-10-05
   reviewer-issues handoff). Do not invent a resolved status.

## 7. Constraints and gotchas in force

- Branch + PR + merge queue; never push protected `main`. `git var
  GIT_COMMITTER_IDENT` must be `Albert Hazan <u2giants@users.noreply.github.com>`.
- Independent exact-head review required for reviewer-wrapper / evidence-tool
  changes before merge (done for #1317).
- Canonical checkout is landing-only; write-capable work uses its own worktree.
- Never edit another session's `HANDOFF.d/` file. Root `HANDOFF.md` is a static
  pointer (`handoff-pointer: v1`).
- Times in human output: EST. Sign GitHub posts `Posted by MiMo chat <id> on edge-dev`.
- Scope freeze on wrap-up: do not start new fixes from this file except #1339
  work when main is clean.

## 8. Access and environment

- Hosts: edge-dev (Windows, this machine), edge-dev3
  (`ssh -i ~/.ssh/916-alien ahazan@edge-dev3`, repo `/home/ahazan/repos/ai-devops`),
  hetz (`ssh vps2-direct`, user `ai`, repo `/worksp/ai-devops`).
- `gh` as `u2giants` via `bin/ai-gh` (never raw `gh` for waits).
- DeepSeek key: 1Password vault `vibe_coding` (never paste values).
- Session tools: Git Bash at `C:\Program Files\Git\bin\bash.exe` (PowerShell
  eats bash `-lc` quotes — use script files for loops).

## 9. Open questions and risks

- **2026-10-06:** Formal receipt is blocked only by *other* commits on main that
  Codex rejects. The DeepSeek budget change itself is approved and live. Do not
  "fix" the receipt by relaxing the exact-head gate.
- Orphan review sandboxes (~300 on edge-dev) still fail evidence reconcile; they
  slow every `ai-review` front-door sweep. Known class; tracked in the
  2026-10-05 reviewer-issues handoff + issue
  `20261006T123753Z-edge-dev-codex-950377`.
- Accidental probe reviewer issue `20261006T135550Z-edge-dev-codex-1657368`
  (summary "probe") was recorded while checking the recorder; treat as noise —
  resolve/abandon in a maintenance sweep, do not investigate as a real defect.
- DeepSeek account previously hit "Insufficient Balance" (2026-10-04 reviews
  failed). Live budgets reduce burn but do not top up credit.

---

### Self-audit (handoff-writer Mode A)

1. **Comprehensive for a brand-new developer?** Yes — §1–2 define the app and
   goal; §3 has exact SHAs, hosts, and constants; §6 is executable without chat.
2. **As effective as this session?** Yes — §4 lists every dead end (including
   authorize-install empty-release and exact-head binding); §5 captures the
   measurement and cache-preserving design.
3. **Every relevant detail?** Yes — background, goal, outcome, state, failures,
   constraints, risks, next actions, verification gates, secrets by location.
4. **Section 0 shows every owner decision and no technical approvals?** Yes —
   sweep found no remaining business decisions; technical remainder is issue
   #1339 + reviewer issue, not an Albert ask.
