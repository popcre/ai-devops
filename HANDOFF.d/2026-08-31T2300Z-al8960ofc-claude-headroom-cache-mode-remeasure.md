---
issue: 195
status: OPEN
owner: claude/headroom-prompt-cache-2be961
---

# HANDOFF — Re-measure Headroom savings under cache mode (2026-08-31 23:00 UTC, al8960ofc/claude)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**BLOCKING — none.** Nothing is waiting on Albert to continue this work. The
next step is simply time passing (real sessions accumulating).

**RECOVERABLE**

1. **Keep Headroom or pull it?** This is the standing decision recorded in
   `docs/headroom.md` §1: if the payoff is not clearly worth the extra network
   hop and moving parts, we remove it. It cannot be answered until issue #195
   produces cache-mode numbers. **Recommendation: keep it for now, decide after
   the re-measure.** Do not re-ask before then.

**NOT PART OF THIS WORK, AND NOBODY IS ON IT**

2. **The proxy has no authentication.** On startup it warns: bound to a
   non-loopback address with no `HEADROOM_PROXY_TOKEN` set, so anything on the
   Tailscale network can send requests through it and spend Albert's Claude
   quota. This was a deliberate 2026-07-14 choice (private tailnet only, never
   public) and is documented in §3 of `docs/headroom.md`, so it is not a
   regression — but nothing has re-examined it since, and the tool itself now
   flags it. **Recommendation: accept as-is while the tailnet stays small;
   revisit if any device Albert does not control joins it.** Needs a one-word
   ruling.
3. **`HANDOFF.d/` holds 22 files.** Per the owner ruling of 2026-08-13, the
   COUNT is not itself a problem — 22 concurrent workstreams means 22 files.
   This session did not audit whether any are stale, because the standard
   forbids opening another session's handoff. No action requested.

**Already settled — do NOT re-ask**

- 2026-08-31: switch Headroom to `--mode cache` — Albert approved, done.
- 2026-08-31: upgrade Headroom to 0.37.0 — Albert approved, done.
- 2026-08-31: schedule the hourly performance recorder — Albert approved, done.

## 1. What this application is

`u2giants/ai-devops` (the GitHub remote also answers as `popcre/ai-devops`) is
Albert's DevOps toolkit repository: skills, machine setup scripts, and operating
documentation for the AI sessions that work across his projects. It is not a
deployed product; it is the configuration and knowledge base those sessions run
from.

**Headroom** is separate third-party infrastructure documented in this repo
because it affects every Claude session. It is a context-compression proxy that
sits between a Claude client and Anthropic's API, compressing large tool outputs
before they are sent upstream to reduce input-token usage. It runs only on the
**hetz VPS** (Albert's Hetzner box, reachable as `ssh hetzner`), installed with
pipx under the Linux user `ai` as package `headroom-ai`, managed by systemd unit
`headroom.service`, bound to a private Tailscale address on port 8787. No Windows
machine runs it; they only point at it. Full documentation: `docs/headroom.md`,
routed from `AGENTS.md`.

## 2. What we set out to do this session, and why

Albert had read a claim that compression proxies like Headroom destroy the
provider prompt cache: because Anthropic discounts a re-read prefix by roughly
90%, any tool that rewrites earlier conversation turns invalidates the cache from
the edit point onward, so you trade a large native discount for a small
compression discount and lose money. He asked whether that matched our
experience.

The objective became: answer it with measurement rather than argument, then act
on the answer.

## 3. Current state — what is true right now

**Done and verified:**

- **The question is answered: Headroom is NOT breaking our prompt cache.**
  Measured from `/home/ai/.headroom/logs/proxy.log`, which records `cache_read`,
  `cache_write` and `cache_hit_pct` per request. On conversations with 10 or more
  messages: 718 requests where Headroom compressed something averaged a **92.5%**
  cache hit rate and 6,199 cache-write tokens; 16 comparable requests it left
  untouched averaged **86.1%** and 25,599 cache-writes. Compression correlates
  with better cache behaviour and 4x less cache rewriting.
- **The service now runs `--mode cache`.** It previously ran the default `token`
  mode, which Headroom's own `proxy --help` describes as "prior turns may be
  rewritten for max savings" — the cache-unsafe setting. Verified by the startup
  log: `Mode: cache` / `Prefix freeze: strict (all prior turns immutable)` /
  `Mutations: latest turn only`. The unit was backed up first to
  `/etc/systemd/system/headroom.service.bak-2026-08-31`.
- **Upgraded 0.30.0 → 0.37.0** via `sudo -u ai pipx upgrade headroom-ai`.
  Verified `headroom --version` and a 200 from the `/health` endpoint. Notably
  0.37.0 changed its OWN default to `cache`, so the vendor agrees the old default
  was wrong.
- **Durable performance recorder installed and scheduled.**
  `/home/ai/headroom-perf/record.py`, cron `17 * * * *` in the `ai` user crontab,
  appending to `/home/ai/headroom-perf/perf.csv`. Verified it runs correctly
  under a stripped environment (`env -i`) as cron will invoke it, and that it is
  idempotent (second run reports `added=0`). The previous crontab was backed up
  to `/tmp/ai-crontab.bak-2026-08-31`; the six pre-existing jobs are untouched.
- **Token-mode baseline preserved:** 1,706 requests spanning 2026-07-15 →
  2026-08-28, verified as 0 malformed rows.
- **Docs committed:** `docs/headroom.md` gained §5b (cache safety) and §5c
  (performance recording); every existing savings percentage is now flagged as a
  token-mode figure pending re-measurement. Commit `c3c46a8` on branch
  `claude/headroom-prompt-cache-2be961`, pushed, PR
  https://github.com/popcre/ai-devops/pull/194.

**Not started — the reason this handoff exists:**

- **No cache-mode measurement exists yet.** Cache mode went live at
  2026-08-31 18:21 EDT with essentially no traffic through it since. Every
  percentage we can currently quote describes the old mode on the old version.

## 4. Everything we tried that did NOT work

1. **Planned a live A/B experiment against the real API.** The intent was to run
   an identical workload with Headroom on and off and compare cache metrics.
   Abandoned as unnecessary and wasteful: the proxy already logs per-request
   cache statistics, so roughly six weeks of real production traffic was sitting
   on disk. Do not spend API budget on a synthetic test — read `perf.csv`.
2. **Tried to point a second Headroom instance at a fake upstream** so the
   outbound request body could be diffed to see whether prior turns were
   rewritten. Abandoned: there is no environment variable to override the
   upstream URL (confirmed by grepping every `HEADROOM_*` name in the installed
   package — there is `HEADROOM_MODE` and `HEADROOM_PROVIDER` but nothing for a
   base URL), so it would have required DNS and TLS interception. Not worth it
   once the log data was found.
3. **First version of the recorder was a bash/awk script and was silently
   wrong.** It emitted 816 rows where 1,187 PERF lines existed. Cause: the log
   timestamp uses a **comma** for milliseconds (`18:11:53,213`), so splitting the
   line into CSV on commas shifted every column, and the deduplication key landed
   on the millisecond fragment instead of the request id. The file looked
   perfectly well-formed. Rewritten in Python anchored on a full regex; now 1,706
   rows, 0 malformed. **If you touch the parser, this is the trap.**
4. **A stale memory note produced a wrong answer to Albert.** The first reply
   claimed lifetime savings of 594 tokens / 0.27%, quoted from a note written
   2026-07-14 before Headroom had seen real use. Codex, reading the live file,
   correctly reported 668,804 tokens over 7 days. **Lesson: read
   `proxy_savings.json` or `perf.csv`, never a remembered figure.** The memory
   note has been corrected.

## 5. Root causes and key findings

- **The criticism describes a real mechanism but the wrong target.** Headroom's
  content router is conservative. The `transforms=` field in each PERF log line
  shows what it actually did, and the common values are `router:noop`,
  `router:excluded:tool`, and `router:protected:*`. The only genuine edit is
  `router:tool_result:text` — the newest tool output, not conversation history.
  That is why the cache survives.
- **We were nevertheless running the unsafe setting.** `headroom.service` passed
  no `--mode` flag, so it inherited `token`. The measurement says that mode was
  not hurting us in practice, but relying on a cache-unsafe mode choosing to
  behave is not a control. Hence the explicit flag.
- **`proxy.log` rotates at ~10 MB keeping 5 files, with no logrotate config** —
  the rotation is internal to Headroom. The current log was at 6.7 MB, so the
  evidence underpinning all of the above was a few megabytes from being
  overwritten. That is the entire justification for §5c's recorder.
- **`tok_after` and `cache_read` are not on a common basis.** Summing them
  produces ratios above 1. `tok_after` is Headroom's own tokenizer estimate of
  the outgoing body; `cache_read` comes back from Anthropic. Compare
  `cache_hit_pct` between groups; do not try to reconstruct a cost figure by
  adding those two columns.

## 6. Exact next steps

1. **Wait for real usage.** Cache mode needs roughly a week of genuine sessions
   through the proxy. *You'll know it worked when* `perf.csv` holds a few hundred
   rows timestamped after `2026-08-31 18:21`.
2. **Confirm the cron is actually firing.** Run
   `ssh hetzner 'sudo -u ai tail -5 /home/ai/headroom-perf/record.log'`.
   *You'll know it worked when* you see hourly `total=… added=…` lines, with
   `total` climbing.
3. **Check that traffic is reaching the proxy at all.** Read `last_activity_at`
   in `/home/ai/.headroom/proxy_savings.json`. *You'll know it worked when* the
   timestamp is recent. **A green `/health` proves nothing** — see the warning in
   §6 of `docs/headroom.md`; on 2026-08-21 the service was healthy and had
   carried zero traffic for nine days.
4. **Split `perf.csv` at the 2026-08-31 18:21 boundary** and compare token-mode
   rows against cache-mode rows on three measures: tokens saved as a percentage
   of `tok_before`, average `cache_hit_pct`, and average `cache_write`. Restrict
   to `msgs >= 10` for the cache comparison, exclude rows whose `model` contains
   `passthrough`, and exclude `tok_before = 0`. *You'll know it worked when* you
   have both groups with n in the hundreds.
5. **Update `docs/headroom.md` §6** with the current figures, and remove the
   "pending re-measurement" warnings now present in §1, §5b and §6.
6. **Put the keep-or-pull decision to Albert** with the new numbers (§0 item 1).
7. **Close issue #195 and delete this handoff file** in the same pull request.

## 7. Constraints and gotchas in force

- **Production infrastructure is read-only for AI sessions by default.** The
  three VPS changes in this session were each named and approved by Albert in
  chat. Do not make further changes to `headroom.service`, the crontab, or the
  installed version without the same explicit approval.
- **Back up before editing config, and change settings in place.** Both backups
  from this session are named in §3.
- **Never report the `HANDOFF.d/` file count as a problem** (owner ruling
  2026-08-13). Report only files proven stale, by name.
- **Do not open, edit or delete another session's `HANDOFF.d/` file.**
- **Do not rewrite the root `HANDOFF.md`** — it is already a `handoff-pointer: v1`
  stub.
- **Delete THIS file when issue #195 is closed.** Git history is the archive.
- Windows CI runners on this repo are slow — the `verify` workflow's
  `windows-offline` and `windows-reviewer-safety` jobs ran well past 10 minutes
  on PR #194. Wait them out; do not assume a hang.

## 8. Access and environment

- **Repo:** `u2giants/ai-devops`; `gh` commands resolve it as
  `popcre/ai-devops`. Branch `claude/headroom-prompt-cache-2be961`, PR #194
  targeting `main`. Work was done in the git worktree
  `C:\repos\ai-devops-worktrees\sync-dotfiles-d2438a`.
- **Git identity** verified this session as
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- **VPS:** `ssh hetzner` gives root; `sudo -u ai` for anything owned by the `ai`
  user. `ssh vps2` is the `ai` account directly. The `devops-mcp` MCP is another
  route but **failed to connect for this entire session** — use SSH.
- **Key paths on the VPS:** binary `/home/ai/.local/bin/headroom`; state
  `/home/ai/.headroom/` (savings ledger, `logs/proxy.log`); recorder
  `/home/ai/headroom-perf/`; unit `/etc/systemd/system/headroom.service`.
- **Secrets:** none were handled in this session. Headroom's credential posture
  is unchanged. Anything needed lives in the 1Password `vibe_coding` vault —
  never write values into files or chat.

## 9. Open questions and risks

- **The savings number may get worse, not better.** Cache mode is by design less
  aggressive than token mode, so raw compression could fall below the 2.21%
  measured on the trailing 7 days of token mode. Separately, 0.37.0 newly enables
  code-aware AST compression, which could push it up. The two effects are
  confounded and this session changed both at once. If the result is ambiguous,
  the honest report is that we cannot separate them, not a guess.
- **The comparison is not a controlled experiment.** Token-mode and cache-mode
  rows come from different weeks and different work. Treat the outcome as
  directional evidence for a keep-or-pull judgement, not a precise delta.
- **The untouched-request control group is small** (16 requests at `msgs >= 10`).
  The 92.5% vs 86.1% finding is directionally clear and consistent with the
  cache-write figures, but do not present it as a tight statistical result.
- **Version drift caused this whole detour.** We sat seven releases behind on a
  component in the path of every Claude request, which is how we ended up on a
  default the vendor had already abandoned. Worth checking `headroom update`
  periodically rather than only when something prompts it.
- **Decision recorded 2026-08-31:** cache mode was chosen over token mode as a
  matter of control, not because measurement showed harm. If a future session
  finds cache mode materially reduces savings, reopening that trade-off is
  legitimate — it is not a settled prohibition.
