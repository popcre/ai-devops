---
issue: 114
status: OPEN
owner: claude/objective-chebyshev-bb5eb4
---

# HANDOFF — MCP project scoping: shipped, merge pending, 3 follow-ups open (2026-08-27 01:40 UTC, edge-dev/claude)

## 0. DECISIONS ONLY THE OWNER CAN MAKE

Put these to Albert in ONE message. None of them block the merge.

### BLOCKING — nothing

### RECOVERABLE

1. **`tokensave`: keep or remove?** ([#122](https://github.com/popcre/ai-devops/issues/122))
   A 160 MB unmanaged binary on hetz that currently **fails to connect**. Asked
   twice this session; not answered. **Recommendation: remove it** unless Albert
   actively uses it — a broken tool that a rebuilt machine would silently lack is
   worse than no tool.
2. **Delete `/home/ai/synology-monitor.retired-2026-08-26`?**
   Not before ~2026-08-30. Everything was verified working after the rename;
   deletion is the last irreversible step. **Recommendation: delete after a few
   quiet days.** It also carries a DEAD (already-rotated) NAS token on disk, so
   deleting it is mildly positive for hygiene.

### NOT PART OF THIS WORK, AND NOBODY IS ON IT

3. **[#116](https://github.com/popcre/ai-devops/issues/116)** — the `recall-ai`
   `op://` reference differs between the two setup scripts (title form vs UUID).
   Live credential plumbing; **do not "fix" by copying one spelling over the
   other** — resolve both against the vault first. `recall-ai` also currently
   fails to connect on hetz, which may be this or may be #68. Separate them.
4. **[#117](https://github.com/popcre/ai-devops/issues/117)** — the ownership map
   is written twice (PowerShell + Bash). It had already drifted once. A test now
   cross-checks it, so this is cleanup, not urgent.
5. **`/worksp/monitor/.git` is a broken stub** (contains only `info/`), so
   `git -C /worksp/monitor` reports "not a git repository". It fooled this session
   for several steps. The real repo is `/worksp/monitor/app`. Deleting the stub
   would help the next person. Nobody is on it.
6. **The DesignFlow commit is riding in someone else's pull request.** The
   `.mcp.json` commit `d68d6ec9` landed on `sandbox-albert`, which already had
   open PR [#159](https://github.com/popcre/designflow-frontend/pull/159) for
   unrelated feature work. Per DesignFlow rules it was NOT self-merged. Albert may
   want it split out; this session deliberately did not rewrite a shared branch.

### Already settled — do NOT re-ask

- **2026-08-26 — `synology-monitor`'s two MCP servers stay GLOBAL on every
  machine. Do not un-ignore its `.mcp.json`.** That repo ignores the file in both
  `.gitignore:58` and `.git/info/exclude:7` because the file holds a raw NAS
  bearer token, and a live token already leaked once (`006c059` committed it in
  `ROO_MCP_GUIDE.md`, `11f5d5e` removed the file, the value survived in history
  and had to be rotated). **This session removed that ignore line, read the
  recorded reason, and restored it within minutes.** Nothing was committed and no
  credential was exposed. Do not repeat it. Scoping those two becomes possible
  only if that repo first adopts an `op://`-only `.mcp.json` convention — its
  decision, not this toolkit's.
- **2026-08-26 — keep `PROJECT_ALIASES`, do NOT restructure `/worksp/monitor`.**
  (Grok, grok-4.6.) `/worksp/monitor/server` is a **symlink into a live Coolify
  application**; moving the git root up would pull a live deploy inside a working
  copy. Renaming breaks the `monitor` name that systemd units, deploy docs and
  habits already use.
- **2026-08-26 — Claude Desktop and Codex keep the FULL server set.** Neither has
  a `.mcp.json` mechanism, so removing a name there DELETES the capability rather
  than moving it. Only Claude Code is scoped.
- **2026-08-26 — archiving is the only real way to close a Claude Desktop
  session.** Renaming a session `closed.*` frees nothing.

## 1. What this is

`popcre/ai-devops` is Albert's backup-and-restore toolkit for a multi-model AI
coding workflow. Read `AGENTS.md` first.

## 2. The problem this session solved

Claude Code starts every **globally** configured MCP server in **every** session,
in every repository. Measured on `edge-dev` (i7-12700, 32 GB) 2026-08-26:

| | |
|---|---|
| global servers | 11 |
| open Claude Desktop sessions | 22 |
| `node` processes | **416** |
| RAM held | **18.1 GB** of 31.7 GB (85.8% used) |
| CPU | ~26% — the machine was **out of memory, not out of CPU** |

Nothing was leaking. `railway` was used by **no** cloned repo at all; `recall-ai`
and `ag-grid` by exactly one each.

## 3. What shipped

**Pull request [#114](https://github.com/popcre/ai-devops/pull/114)** — OPEN,
auto-merge armed, waiting on the ~64-minute `windows-offline` check. **A
background watcher is running in this session** and will report the merge commit,
a failed check, or a conflict. If this session is gone, check the PR directly; if
a check failed flakily (see #89), re-run it.

Design: a server only one project uses is **project-scoped**. The AUTHORITY is the
`.mcp.json` **committed in that project's repo** — only a committed file reaches
extra clones, linked worktrees and other machines. The setup scripts only SEED it.

Ownership (`$McpProjectScope` / `PROJECT_SCOPE`, kept identical, test-enforced):

| Server | Project | State |
|---|---|---|
| `trigger`, `recall-ai` | `oracle` | committed, live |
| `railway` | `popdam3` | committed, live |
| `ag-grid` | `designflow-frontend` | committed, in PR #159 |
| `devops-mcp`, `synology-monitor` | `synology-monitor` (`monitor/app` on hetz) | **stays global by design** |

Global keeps `1password`, `supabase`, `chrome-devtools`, `playwright`, `codex-cli`.

### Defects found and fixed (7 of them, each a real capability loss)

Grok review (`grok-4.6-build`, $0.17, 1.2M tokens, 12 findings, no `## Verdict` —
it hit the turn ceiling). **Two claims were verified by execution before acting:**

1. **Windows had the "configured nowhere" bug** already fixed on Linux — both
   global writers pruned every project-scoped name regardless of whether the
   project was found, writable or valid. Seeding now runs BEFORE the global writes
   and records `$McpScopedDone`; only names that genuinely reached a project file
   are pruned.
2. **The `${USERPROFILE}` rewrite was a no-op** — PowerShell encodes
   `C:\Users\x` as `C:\\Users\\x`, so `.Replace()` on `ConvertTo-Json` output
   matched nothing and the literal path shipped. Grok flagged it as "likely"; a
   live `pwsh` run confirmed it. Same bug class already fixed on Linux.
3. Claude Desktop was being stripped (it has no project scope) — now keeps all.
4. "Cloned" meant "a directory exists" — now requires `.git`.
5. An **unwritable directory killed the entire wiring step** (found by running it
   for real on hetz: `/worksp/designflow-frontend` is owned by another account) —
   now fails safe, servers stay global.
6. The seeded file carried `/home/ai/` — now `${HOME}`.
7. A **gitignored** `.mcp.json` was seeded and the servers pruned anyway — now
   detected before writing, project skipped, servers stay global.

### Tests

- `tests/test-mcp-project-scope.sh` — 15 checks, passes on Windows AND hetz.
  Resolves `python3`/`python`/`py` so it runs on both CI legs; a test that always
  skips proves nothing. Hermetic via `AI_DEVOPS_MCP_PROJECT_ROOTS` (it previously
  reached into the real filesystem, which is how it hit hetz's `/worksp`).
- `tests/test-mcp-project-scope.ps1` — 22 contract assertions. **New because
  Windows was entirely untested, which is why defect 1 survived.** Verified it can
  FAIL: reintroducing the original prune turns 2 checks red.
- Pre-existing: 34 config tests still pass; Codex untouched.

## 4. Live verification on hetz (`vps2`, user `ai`)

Ran `bin/setup-secrets.sh` for real, repeatedly. Confirmed:
`devops-mcp` and `synology-monitor` **connect** (`✔ Connected`); unmanaged
servers (`headroom`, `tokensave`) survived untouched; project detection picks
`/worksp/monitor/app` via `PROJECT_ALIASES`.

**Trap that cost time:** the hetz ai-devops checkout is at `~/repos/ai-devops` and
must be `git reset --hard origin/<branch>` before each test run. One run silently
used a pre-alias build and seeded the wrong directory.

## 5. The retired stray checkout

`/home/ai/synology-monitor` → **renamed** to
`/home/ai/synology-monitor.retired-2026-08-26`. Not deleted.

It was on `master` (deleted on the remote), **429 commits behind** `main`, with
129 uncommitted changes and 2 unmerged commits. Evidence in
`/home/ai/rotation/synology-monitor-stray-2026-08-26/`: `EVIDENCE.md` (166 lines)
plus `patches/0001-*.patch`, `patches/0002-*.patch`. **The snapshot was swept and
contains no token-shaped values.**

Classification: the 2 commits touch only docs and a git hook — one is literally
"Enforce single-branch policy", which `main` already has. Of the untracked files,
45 of 60 sampled already exist on `main`; the ~15 unique ones are planning notes
and SQL superseded by 429 later commits. **Not worth recovering.**

`ROO_MCP_GUIDE.md` in there holds a real 64-char bearer token. **Compared against
the live NAS token: it does NOT match — it is the old, already-rotated value.**
Dead credential. It was NOT copied into the backup and disappears on final
deletion. Fingerprint `fa705ad47347` if it ever needs identifying again.

Order used (from Grok, worth reusing): prove nothing uses it → snapshot evidence →
classify → `git worktree remove` the registered worktrees → **rename, don't
delete** → confirm the real repo and MCP still work → delete days later.

## 6. What the next session should do

1. **Confirm PR #114 merged.** `gh pr view 114 --repo popcre/ai-devops --json state,mergeCommit`.
   If a check failed flakily, re-run it. If it merged, **delete this handoff file**.
2. Get Albert's answers on the two RECOVERABLE decisions above.
3. After ~2026-08-30, delete the retired folder if nothing broke.

## 7. Traps that will bite you

- **`git -C /worksp/monitor` says "not a git repository"** — the `.git` there is a
  stub with only `info/`. The repo is at `/worksp/monitor/app`.
- **Heredocs through the Bash tool mangle backslashes.** Two edits silently failed
  to match this session before switching to the Edit tool. Do not use
  `python - <<'PY'` for patterns containing `\`.
- **`bin/setup-machine.ps1` is mixed line endings**; edits normalise to LF.
- **`origin` in some checkouts still points at `u2giants`** and the redirect breaks
  `gh pr create` with "No commits between ...". Fix with
  `git remote set-url origin https://github.com/popcre/ai-devops.git`.
- **Grok can return exit 0 with a 0-byte output file while still working.** Wait
  for the task notification; never trust exit status.

## 8. Files this session changed

`bin/setup-machine.ps1`, `bin/setup-secrets.sh`, `docs/mcp-server-scope.md` (new),
`docs/onboarding-secrets.md`, `AGENTS.md` (one router row),
`tests/test-mcp-project-scope.sh` (new), `tests/test-mcp-project-scope.ps1` (new).
Outside this repo: `.mcp.json` committed in `oracle`, `popdam3`,
`designflow-frontend`.

## 9. Self-audit

- Every decision has a recommendation and a named blast radius. ✔
- Every claim of "verified" names the command or the live result. ✔
- The one thing this session got wrong (removing a security guard) is recorded
  with the reason it was wrong, so it is not repeated. ✔
- A stranger can finish this from section 6 without asking a question. ✔
