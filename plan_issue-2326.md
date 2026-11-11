---
summary: Plan for issue 2326 cmd shim install safety in setup-secrets - guard shim install and extend test.
kind: plan
status: open
read-when: Fixing cmd shim install safety (issue 2326)
---

# Implementation plan — popcre/ai-devops#2326 (cmd shim install safety)

**Verdict (checked on main f2b4f5bd, 2026-11-04): STILL REAL, small.** Findings F1 and F2
from the advisory GLM review of PR #2325 (merged 2026-11-03) are unchanged on main at
`bin/setup-secrets.sh:436-444`. F3 is informational (fail-closed over-detection) — accept,
no code change. Worth doing under skinny: it is a data-safety fix (the installer can
overwrite a user's own file), ~10 lines, no new tools, no new checks.

## STATUS
| Step | State | Evidence |
|---|---|---|
| 1 Guard shim install | ⬜ open | — |
| 2 Extend test | ⬜ open | — |
| 3 PR, merge, close #2326 | ⬜ open | — |
Fresh session starts at Step 1. Handoff: none created (planning-only task, read-only rules);
the implementer must add a `HANDOFF.d/` entry only if they leave work unfinished.

## 1. Ultimate goal
Re-running the machine setup script must never silently destroy a file the toolkit did not
write, and must never claim success when it failed. If a step conflicts with this goal, the
goal wins — stop and flag it.

## 2. What this application is
`popcre/ai-devops` (public) is Albert's AI toolkit: install scripts, wrappers, skills.
`bin/setup-secrets.sh` is the idempotent per-machine setup; on Linux it writes MCP launchers
to `~/.config/ai-devops/` and (since #2325) copies `bin/cmd-compat` to `~/.local/bin/cmd`
so shared `.mcp.json` lines `cmd /c ...mcp-launch.cmd ...` work on Linux.

## 3. Trigger
Issue #2326: automatic review-finding from the advisory review of PR #2325
(head b992af5c). The fixer deferred because the source PR was already closed (merged).

## 4. Scope
In: F1 (don't clobber a foreign `~/.local/bin/cmd`), F2 (report copy failure).
NOT in: F3 regex change in `bin/ai-public-boundary-check:90` (deliberate fail-closed);
changes to `bin/cmd-compat` behaviour; WSL interop detection redesign; the unchecked guard
copy elsewhere in setup-secrets.sh (peer precedent, separate if ever wanted).

## 5. Current state
`bin/setup-secrets.sh:439-444`:
`if [ -e "$CMD_SHIM" ] || ! command -v cmd ...; then mkdir; cp ... && chmod; ok "Installed..."; fi`
— any existing file is overwritten; `ok` prints even if `cp` fails (script has no `set -e`).
`bin/cmd-compat:2` carries a stable marker: `# [ai-devops] Linux stand-in for \`cmd\``.
Helpers `ok()`/`warn()` at `bin/setup-secrets.sh:107-108`.
Test: `tests/test-cmd-compat.sh` (auto-discovered via `tests/lib-selection.sh:297-305`).
No `tests/test-setup-secrets*` exists.

## 6. Key findings
- Repo convention for `~/.local/bin`: `bin/install-ai-provider-clis.sh:145-148` warns and
  leaves an existing non-symlink untouched; asserted in `tests/test-install-ai-provider-clis.sh:155-161`.
- Once the shim exists, it shadows a real interop `cmd.exe` forever (Linux PATH first). Keeping
  "refresh only if it is ours" preserves updates while honouring the comment's intent.

## 7. Rejected approaches
- Byte-compare with `bin/cmd-compat`: would refuse to update an older copy of our own shim. Use marker grep instead.
- Symlink instead of copy: breaks if the checkout moves; not requested.
- New test harness for all of setup-secrets.sh: too heavy; extract a tiny function instead? Also rejected — keep inline and test the decision via a small sourced snippet only if cheap (see Step 2).

## 8. Decisions
Locked: marker-based ownership (`grep -qF '[ai-devops] Linux stand-in for' "$CMD_SHIM"`);
foreign file → `warn` + skip; cp/chmod failure → `warn`, no `ok`. Not blocking anything
(advisory output only; skinny ruling 2026-10-29/30). Open: exact warning wording.

## 9. Steps
**Step 1 — `bin/setup-secrets.sh:439-444`.** Replace with logic:
```
CMD_SHIM="$HOME/.local/bin/cmd"
if [ -e "$CMD_SHIM" ] && ! grep -qF '[ai-devops] Linux stand-in for' "$CMD_SHIM" 2>/dev/null; then
  warn "$CMD_SHIM exists and is not the ai-devops shim; leaving it untouched"
elif [ -e "$CMD_SHIM" ] || ! command -v cmd >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"
  if cp "$REPO_ROOT/bin/cmd-compat" "$CMD_SHIM" && chmod 755 "$CMD_SHIM"; then
    ok "Installed cmd compatibility shim -> $CMD_SHIM"
  else
    warn "Could not install cmd compatibility shim at $CMD_SHIM; shared MCP servers will not start on Linux"
  fi
fi
```
Update the comment above to say a foreign `~/.local/bin/cmd` is never overwritten.
Done when: `bash -n bin/setup-secrets.sh` passes and manual check below holds.

**Step 2 — Test.** In `tests/test-cmd-compat.sh` add one assertion that the marker string is
present in `bin/cmd-compat` (`grep -qF '[ai-devops] Linux stand-in for' "$ROOT/bin/cmd-compat"`),
so nobody removes the line setup-secrets.sh relies on. Manual proof (scratch HOME under $TMPDIR):
put `echo mine` in `$HOME/.local/bin/cmd`, run only the shim block (copy it to a scratch
script with `ok`/`warn`/`REPO_ROOT` defined) → file unchanged + WARN; with a prior shim copy →
refreshed + ok; with read-only dir → WARN, no ok. Done when `bash tests/test-cmd-compat.sh` prints PASS.

**Step 3 — Land.** Branch from main in a worktree, commit as Albert (`git var GIT_COMMITTER_IDENT`)
with message `fix: never clobber a foreign ~/.local/bin/cmd; report shim install failure (#2326)`,
PR, `bin/ai-pr-wait <pr>` in background, merge yourself. Close #2326 with a signed
(`$AI_GH_SIGNATURE`) comment noting F1/F2 fixed, F3 accepted as fail-closed.

## 10. Tests
New: marker assertion in `tests/test-cmd-compat.sh`. Must stay green: `tests/test-cmd-compat.sh`,
`tests/test-install-ai-provider-clis.sh`, CI verify shards.

## 11. Constraints
Public repo: no hostnames/secrets in the diff. Never push to main. Reviews advisory only;
only data-safety/secret-leak checks may block. No new waiting tools. POSIX `sh`-safe grep.

## 12. Access
`gh` authenticated as u2giants for popcre/ai-devops. Linux machine for the manual check. No secrets needed.

## 13. Done / risks
Done: code + test merged, CI green, #2326 closed with evidence (commit SHA, CI run id).
Live proof: re-run `bin/setup-secrets.sh` on one Linux machine and see `ok` (own shim refreshed).
Risk: machines whose shim predates the marker — none (marker shipped with the shim in #2325).
Rollback: revert the commit. No open business questions.

## Self-audit
1. Fresh session could execute without questions: yes — §5 exact lines, §9 literal code, gates.
2. Background/rejections carried: yes — §6, §7, F3 disposition in §4.
3. Goal clear enough for judgment: yes — §1 one sentence, with goal-wins rule.
