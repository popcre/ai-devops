---
issue: 1751
status: OPEN
owner: docs/slm-compaction-handoff
---

# Handoff — one-week paired pilot: SLM history compaction

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

**Already settled — do NOT re-ask**

- **2026-10-14:** ScaleDown may process our code and conversations (owner:
  "our code and conversations may go to ScaleDown"). Secrets and private raw
  transcripts still stay out of third-party compressors.
- **2026-10-14:** ScaleDown API key is in 1Password; AI obtains it itself.
- **2026-10-14:** Process fixes A–F (reply discipline, one status probe, task
  packets, scratch-file instinct, quoting, compress rules) are approved and
  live on `main` plus edge-dev, edge-dev3, and 4837.
- **2026-09-28:** Never ask a human to approve technical actions; assigned AI
  reviewers gate those. Do not put technical approvals in front of Albert.

**Open owner decisions (ask these ONE message at session start, with a recommendation each)**

1. **Which machine for the one-week paired pilot?** Recommend **edge-dev** (this
   Windows host already has the rules/skill and is the busiest AI client).
   Blocks step 1 of §6.
2. **Stop condition if quality slips?** Recommend: stop the pilot the same day
   a coding task fails because a compacted detail was lost; record that as a
   fail, do not "push through the week." Blocks step 4 gate.

Nothing else in this workstream needs the owner. Technical blockers go to an
assigned AI reviewer or `Blocked —`, never to Albert.

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery and operating toolkit for a
multi-model AI workflow (Claude Code, Codex, MiMo, ZCode, and other agents).
It is not an app or service: it is wrappers, skills, templates, docs, and
install scripts. GitHub is the source of truth:
https://github.com/popcre/ai-devops

This handoff is about **AI token spend**, not product code. Long coding
sessions re-send huge histories and burn expensive frontier tokens on
auto-compaction. We want to know whether a **cheap SLM** (ScaleDown) can own
history compaction instead.

## 2. What we set out to do this session, and why

Albert asked whether ScaleDown could cut token use. Work completed this
session (all landed):

1. Evaluated ScaleDown (API models, DietCode, SLM_Agent) against our real
   spend patterns.
2. Audited **950** local chat transcripts with ScaleDown (not loaded into
   chat) — measured waste patterns and compress ratios.
3. Wrote process fixes A–F and landed them on `main` (PR 1748,
   `73600fa1`); installed rules + `scaledown-compress` skill on edge-dev,
   edge-dev3, and 4837.
4. Corrected the compaction verdict (PR 1750, `cc7b4b03`): **SLM history
   compaction is a different, higher-leverage path** than tool-output
   compression.

**Remaining objective (this handoff):** run a **one-week paired pilot** to
measure whether SLM history compaction actually cuts paid tokens without
wrecking prompt-cache hit rate. Issue:
https://github.com/popcre/ai-devops/issues/1751

## 3. Current state — what is true right now

**Landed on `main` (verified):**

| Artifact | URL |
|---|---|
| Process fixes A–F + compress skill + trial record | https://github.com/popcre/ai-devops/blob/main/docs/compression-and-process-fixes.md and https://github.com/popcre/ai-devops/blob/main/skills/shared/scaledown-compress/SKILL.md (PR 1748, commit `73600fa1`) |
| Corrected SLM history-compaction verdict | https://github.com/popcre/ai-devops/blob/main/docs/compression-and-process-fixes.md (PR 1750, commit `cc7b4b03`) |
| Task packet template | https://github.com/popcre/ai-devops/blob/main/templates/system/model-tier-delegation.md |
| Global reply/probe/scratch/compress rules | `templates/system/AGENTS-global-*.md`, `CLAUDE-global.md` on `main` |

**Installed (this session, verified by reading the live files):**

- **edge-dev:** rules in MiMo/Claude/Codex globals; `scaledown-compress` in
  Claude/Codex/MiMo skill dirs.
- **edge-dev3:** `ai-adopt-globals` + skill install from a temp worktree at
  `73600fa1`; rules verified in Claude/Codex/MiMo globals.
- **4837 / al8960ofc:** `ai-adopt-globals` + skill install; rules verified in
  Claude/Codex globals; MiMo AGENTS + skill copied from
  `AGENTS-global-mimo.md` / `scaledown-compress`.

**Not started:** the paired pilot itself. No DietCode install. No
measurement of SLM history compaction on live sessions.

**Commit/push status:** all doc/PR work is on `main`. No open PR for this
handoff until it lands.

## 4. Everything we tried that did NOT work

| Attempt | Why it seemed right | How it failed | Why |
|---|---|---|---|
| Treat ScaleDown Compress 85% cut as expected production savings | Pilot on 950 transcripts showed avg ~85% token reduction | Overstated: that material is redundant transcript padding | Live Claude tool-output compression (Headroom) measured **~2% net** after prompt cache (`docs/headroom.md`). Different path. |
| Conflate tool-output compression with history compaction | Both "save tokens" | Wrong product match | History compaction (cheap SLM summarizes old turns) is the high-leverage path; tool-output compress is small. Corrected in PR 1750. |
| First extract schema used nested `waste_patterns` array | Structured audit | 0 patterns parsed | ScaleDown extract returned flat `entities` for flat keys; nested arrays need `structured_result`. Fixed by parsing both shapes. |
| `ai-doc-reachability` passed with 0 files while untracked | "0 added = fine" | CI `doc-safety` failed on unreachable `SKILL.md` | Reachability only counts committed/staged files. Fixed by linking skill from README. |
| File named `*token*` | Clear name | Gitignored (`**/*token*`) | Renamed to `docs/compression-and-process-fixes.md`. |
| `ai-adopt-globals` hung via some SSH/quoting paths | Standard installer | Timeout / cmd quoting on Windows SSH | Worked via uploaded `.cmd` and Git Bash path; edge-dev3 worked from a temp worktree. |
| DietCode "not adopted" one-liner | Conservative | Under-sold history compaction | Rewritten as "worth piloting" with cache caveat. |

## 5. Root causes and key findings

1. **Two different compress products.** Tool-output compression ≈ 2% net
   after cache. Paste/retrieval compress ≈ 85% on redundant material. **History
   compaction** (replace expensive auto-compact with cheap SLM summarize) is
   the one that can move long-session spend — sessions re-send history every
   turn.
2. **Cache safety is a design property, not automatic.** DietCode's proxy
   freezes the running summary between compaction steps and leaves system+tools
   untouched, so cache busts only at compaction events (same as native
   compact). Rewriting the summary every turn would bust cache every turn.
   Source: https://docs.scaledown.ai/dietcode/proxy-mode
3. **Transcript waste is mostly us:** verbose replies, empty `Still open`,
   re-probing the same head, reloading the same docs into every subagent,
   pasting full logs. Process fixes A–F address those without new tools.
4. **ScaleDown API base is `https://api.scaledown.xyz`** (not `.ai`).
   Compress: `POST /compress/raw/`. Summarize/Extract:
   `POST /v1/chat/completions` with `model` `summarize` / `extract`.
   Auth: `x-api-key` from 1Password `vibe_coding` → `scaledown.ai API key`
   (field `credential`). Never print the key.
5. **DietCode** is npm hooks + optional Claude-only proxy (`dietcode claude`).
   Hooks only add tokens; real history shrink is the proxy. Cursor gets no
   automatic optimization. Not installed yet.
6. **Heads-up:** `**/*token*` is gitignored in this repo — never name files
   with "token" in them.

## 6. Exact next steps

1. **Confirm pilot machine** with Albert (§0 item 1). Default edge-dev.
   *You'll know it worked when:* Albert names the machine (or accepts edge-dev).
2. **Declare task** `ai-task-gates start --class code` (or `prose` if
   measurement-only docs). Open a measurement log under
   `tests/verification/compression/` (create dir if needed) with GitHub URLs
   only in the committed report.
3. **Baseline week (days 1–3), no DietCode:** record for representative
   Claude (or Codex) sessions: session length, billed input/output tokens,
   cache_read/cache_write when available, and whether native auto-compact
   fired. Reuse existing provider usage fields; do not invent prices.
   *Gate:* baseline file lists ≥10 real sessions with token numbers.
4. **Pilot week (days 4–10):** install DietCode **on that one machine only**
   (`npm install -g dietcode` + `dietcode setup`), run Claude through
   `dietcode claude` (proxy). Keep work type comparable to the baseline.
   Stop same day if a compacted detail is lost on a coding task (§0 item 2).
   *Gate:* paired table: tokens/turn, cache hit rate, compact events, quality
   notes.
5. **Decide** from the paired table: adopt / iterate / drop. Write the number
   into https://github.com/popcre/ai-devops/blob/main/docs/compression-and-process-fixes.md
   and tick/close issue 1751.
   *Gate:* decision recorded on the issue with the table; skill/rules updated
   if adopt.
6. **Do not** fleet-install DietCode to edge-dev3/4837 before step 5 says
   adopt. *Gate:* those two hosts still have no `dietcode` global install
   until then.

**Reciprocal instruction (required at end of the pilot):** re-read this
handoff and https://github.com/popcre/ai-devops/blob/main/docs/compression-and-process-fixes.md
end-to-end and report any drift — anything the pilot learned that changes
later assumptions (cache behavior, DietCode gaps, ScaleDown pricing, quality
failures). Put that in the issue comment and in the updated doc.

## 7. Constraints and gotchas in force

- **Safety outranks token savings.** Never strip gates, never send secrets or
  private raw transcripts to ScaleDown, never replace independent review with
  a compressed summary.
- **One status probe per state change**; scratch files for long output; no
  empty `Still open` — these are now standing rules on all three machines.
- **Never `git pull` in an installed checkout** (e.g. `/worksp/ai-devops`).
  Protected update path only. Landing checkout on edge-dev may ff-merge.
- **Work on a branch + PR**; never push to `main`. Documentation-only PRs may
  merge with `gh pr merge --squash --admin` after `bin/ai-doc-safety` passes
  (see `tools/ci/check-managed-github-transport.py`).
- **Git identity** must be `Albert Hazan <u2giants@users.noreply.github.com>`
  before commit (`git var GIT_COMMITTER_IDENT`).
- **`**/*token*` is gitignored.**
- **Secrets:** 1Password vault `vibe_coding` only; `op read` / `op run`;
  never print keys. Item: `scaledown.ai API key`.
- **Time:** quote EST (America/New_York) in all human-facing notes.

## 8. Access and environment

- **GitHub:** `bin/ai-gh` for all calls. Repo `popcre/ai-devops`.
- **Machines (SSH names):** `edge-dev` (this Windows host), `edge-dev3`
  (Linux desktop), `4837` / `al8960ofc` (Windows peer). Networking-only
  hosts (`edge-alien`, `edge-runn-envy`, `edge-runn-xps`) must **not** get
  toolkit installs.
- **ScaleDown:** `https://api.scaledown.xyz`; key in 1Password `vibe_coding` /
  `scaledown.ai API key`.
- **DietCode:** npm package `dietcode` (not installed yet); needs Node 18+.
- **Skill already on the three machines:** `scaledown-compress`.
- **Decision record:**
  https://github.com/popcre/ai-devops/blob/main/docs/compression-and-process-fixes.md

## 9. Open questions and risks

- **2026-10-14:** Real cache-hit impact of DietCode proxy on *our* traffic is
  unmeasured. Their claim is "as cache-safe as native compact," not "free."
- **2026-10-14:** Quality risk if compacted history drops a rare but critical
  detail (file path, SHA, review evidence). `sd_retrieve` / local stash is the
  mitigation; the pilot must test this explicitly on a real coding task.
- **2026-10-14:** ScaleDown summarize output cap is 1000 tokens; very long
  sessions may need multi-step fold (their progressive design). Watch for
  summary quality decay over many compact steps.
- **2026-10-14:** Codex path is hooks-only (no proxy). If the pilot is
  Claude-only, say so in the verdict — do not claim Codex savings.
- **2026-10-14:** Paid ScaleDown credits: free tier is ~50M tokens per their
  README; confirm usage so the pilot does not surprise-bill.

---

### Self-audit (handoff-writer gate)

1. **Comprehensive enough to pick up?** Yes — §§0–9 cover decisions, state,
   dead ends, steps with gates, constraints, access, risks (this file).
2. **As effective as the writer right now?** Yes — measurements, commits,
   machine install status, API shapes, and the cache design constraint are all
   written here (§§3–5, 8).
3. **Every detail for flawless execution?** Yes — next steps are numbered
   with verification gates; failed attempts in §4; identifiers in §5 and §8.
4. **Section 0 sweep complete?** Yes — owner decisions are (1) pilot machine
   (2) quality stop condition; both recommended. Already-settled list present.
   No technical approvals in §0. External Q: none else found in §§1–9 that
   need Albert rather than a reviewer/issue.
