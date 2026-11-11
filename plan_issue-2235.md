---
summary: Plan for issue 2235 installer globals - hermetic test, missing-template guard and tail-instead-of-sed fixes; all still real.
kind: plan
status: open
read-when: Fixing installer globals test and guard (issue 2235)
---

# Implementation plan — popcre/ai-devops#2235 (installer globals: hermetic test, missing-template guard, no home creation, CRLF tail)

## VERDICT (checked 2026-11-04 against main `f2b4f5bd`)

**Still real.** Every finding below was re-read on current main, not taken from the review:

- F1: `tests/test-installer-parity.sh:65-70` pins only `CLAUDE_HOME`/`CODEX_HOME` for the Bash run; `bin/ai-install-skills:81-82` resolves `ZCODE_HOME`/`MIMO_HOME` from the real home. On this host (`~/.zcode` and `~/.config/mimocode` exist) the fixture install therefore writes into the real ZCode/MiMo homes, or aborts, because the fixture (`tests/test-installer-parity.sh:43-44`) has no `AGENTS-global-zcode.md`/`AGENTS-global-mimo.md`.
- F2: `install_global` (`bin/ai-install-skills:853-860`) has no "does the source exist" guard. The PowerShell twin does have one.
- F4: `docs/deployment.md:136-138` says the refresh does not create absent client homes. But `bin/ai-adopt-globals:255-262` runs `mkdir -p` and installs every `self` target (ZCode/MiMo) unconditionally.
- F5: `bin/ai-adopt-globals:209,282` still slices the machine section with `sed -n "${start},\$p"`. The library was moved to `tail -n "+N"` for byte-exact CRLF (`tools/lib/globals-common.sh:101,103`).

Source PR #2230 is merged (2026-11-01). The issue comment says the automatic fixer deferred because the PR was closed, so nothing has fixed it since.

STATUS
| Step | State | Evidence |
|---|---|---|
| 1 guard missing template | ⬜ open | |
| 2 hermetic parity test | ⬜ open | |
| 3 no home creation in adopt-globals | ⬜ open | |
| 4 tail instead of sed | ⬜ open | |
| 5 PR, merge, live proof, close #2235 | ⬜ open | |
Fresh session starts at Step 1.

Handoff link: this plan was written under a read-only brief. The implementer must create `HANDOFF.d/<UTC>-<machine>-<agent>-installer-globals-2235.md` that links to this plan, and copy this plan into the repo as `plan_installer-globals-2235.md`, which links back to that handoff.

## 1. Ultimate goal
Albert's AI tools on every machine get their instruction files refreshed safely. The work fixes two problems:
- A test of the installer can touch a developer's real ZCode/MiMo settings. It must not.
- The installer can crash, or create folders for apps the machine does not have. It must not.

Each machine's private notes at the bottom of those files must stay byte-exact. **If a step conflicts with this goal, the goal wins. Stop and flag it.**

## 2. What this application is
`popcre/ai-devops` (public) is Albert's toolkit for AI clients: skills, global instruction templates, and installers.
- `bin/ai-install-skills` is the Bash installer for Linux and Git Bash. It copies `templates/system/*` into each client home (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.zcode/AGENTS.md`, `~/.config/mimocode/AGENTS.md`).
- `bin/install-ai-devops-windows.ps1` is the PowerShell twin.
- `bin/ai-adopt-globals` is the first-sync bridge. It backs up old globals, reinstalls them, and re-appends the machine section, which starts at the `---` machine marker found by `find_section_start`.
- `tools/lib/globals-common.sh` holds shared helpers.

Work in a worktree off `main`. Never push to `main` directly.

## 3. Trigger
The advisory AI review (deepseek, workflow run 41261694700) of PR #2230 at head `5e7071c4` raised these findings. Finding 3 asks for new parity assertions. Finding 5 was truncated in the issue body; its visible text and main confirm the `sed` vs `tail` mismatch.

## 4. Scope
In scope: F1, F2, F4, F5 as above.

NOT in this plan:
- F3, extending the parity test with full ZCode/MiMo byte-parity assertions. Under the skinny rulings (2026-10-29/30, `docs/owner-rulings.md`) a bigger test matrix is not worth it. Step 2 adds only the templates and isolation the test needs to be hermetic.
- Any change to the PowerShell installer.
- Any new check, waiter, or required status.
- Any change to template content.

## 5. Current state
Everything is on main `f2b4f5bd` and nothing is started. The references in the VERDICT section are exact.

## 6. Key findings
- `ai-install-skills` runs with `set -e`, so a failed `cp` of a missing source aborts the whole sync.
- `sed -n 'N,$p'` can alter a final line that has no trailing newline. `tail -n +N` is byte-exact. The library already relies on `tail`, so the bridge disagrees with the verifier at `globals-common.sh:103`.
- The bridge comment at `ai-adopt-globals:247-254` says ZCode/MiMo are Windows-only clients. They do exist on this Linux host, so the installer must handle them in both places.

## 7. Rejected approaches
- **Making the parity test skip when `~/.zcode` exists.** That hides the leak instead of isolating it.
- **Rewording the doc only for F4.** The doc states the intended behaviour, so the bridge code should follow it.
- **Adding a hard error on a missing template.** The PowerShell twin degrades with a note, and parity wins.

## 8. Decisions
**Locked:**
- A missing template means skip with a note and return 0.
- Absent client homes are never created by either the installer or the bridge.
- Use `tail -n "+N"` everywhere a machine section is sliced.

**Open:** the exact wording of the skip messages.

## 9. Steps
1. **`bin/ai-install-skills` `install_global` (line 853).** Add this as the first statement:
   `[[ -f "$src" ]] || { echo "Missing source for $label: $src — skipping."; return 0; }`
   Gate: run `bash tests/test-ai-install-skills.sh` and see it pass. Add a case to that file: a fixture with no `AGENTS-global-zcode.md` and an existing `$ZCODE_HOME` installs successfully and prints "Missing source".
2. **`tests/test-installer-parity.sh`.**
   - After line 44, write `# test ZCode global` into `$fixture/templates/system/AGENTS-global-zcode.md` and `# test MiMo global` into `$fixture/templates/system/AGENTS-global-mimo.md`.
   - On both Bash invocations (lines ~65 and ~98), prefix `HOME="$TMP_ROOT/profile" USERPROFILE="$TMP_ROOT/profile" ZCODE_HOME="$TMP_ROOT/bash/zcode" MIMO_HOME="$TMP_ROOT/bash/mimo"`.
   - Optionally assert that `$TMP_ROOT/bash/mimo/AGENTS.md` equals the fixture template, using the `mimo` directory already created at line 59.

   Gate: `bash tests/test-installer-parity.sh` passes. Record `stat -c %Y ~/.zcode/AGENTS.md ~/.config/mimocode/AGENTS.md` before and after; the mtimes must be unchanged.
3. **`bin/ai-adopt-globals:255-262`.** Before `mkdir -p`, add `[[ -d "$(dirname "$installed")" ]] || { say "$label: no client home, skipping."; continue; }`. Also correct the comment at lines 247-254, which says "Windows-only".
   Gate: add a case to the existing `ai-adopt-globals` test (`grep -l ai-adopt-globals tests/`). With `ZCODE_HOME` pointing to a nonexistent temp directory, that directory must still not exist afterwards.
4. **`bin/ai-adopt-globals:209,282`.** Replace `sed -n "${start},\$p" "$installed"` with `tail -n "+$start" "$installed"`, and the same for `restored_start`.
   Gate: add a test case with a CRLF machine section whose last line has no trailing newline. The result after adopt must be `cmp`-identical, matching the style of `tests/test-ai-install-skills.sh:333-341`.
5. **Land it.** Branch `fix/installer-globals-2235`, commit as Albert with the Claude co-author trailer, then open a PR that references `Fixes #2235`. Run `bin/ai-pr-wait <pr>` in the background. Only data-safety and secret checks block; the review is advisory. Merge.
   For live proof, run `bin/ai-install-skills` on this host from main. ZCode/MiMo globals must refresh with their machine sections byte-identical (`cmp` against a pre-run backup). Comment the evidence on #2235, signed, and close it.

## 10. Tests
- Add to `tests/test-ai-install-skills.sh` the missing-template skip case (Step 1).
- Make `tests/test-installer-parity.sh` hermetic (Step 2).
- Add the no-home case and the CRLF/no-final-newline case to the adopt-globals test (Steps 3 and 4).
- These must stay green: `tests/test-ai-install-skills.sh`, `tests/test-installer-parity.sh` (needs `pwsh`; it runs in CI if `pwsh` is missing locally), and the adopt-globals suite.

## 11. Constraints and gotchas
- Isolate all client homes before running any installer test.
- Back up the real `~/.zcode/AGENTS.md` and `~/.config/mimocode/AGENTS.md` before the live proof.
- Never print secrets.
- Windows CRLF: keep `.sh` files LF.
- Do not edit the PowerShell installer.
- Sign GitHub posts with `$AI_GH_SIGNATURE`.

## 12. Access
`gh` is authenticated for `popcre`. No secrets are needed. Local Linux host only.

## 13. Done and risks
**Done when:**
- Steps 1-4 are merged with CI green.
- The live proof is recorded on #2235.
- #2235 is closed and the STATUS table is filled in with commit SHAs.

**Risks:**
- Step 3 changes bridge behaviour on machines that relied on it to create the ZCode/MiMo home. That is intended: the client creates its own home.
- Rollback is a revert of the PR.

**Open:** none for the owner.

## Self-audit
1. Could a new session execute this without questions? Yes. VERDICT, §5 and §9 give the files and lines, §8 locks the choices, and every step has a gate.
2. Does it carry every rejected approach? Yes, in §7, and F3 is excluded with its reason in §4.
3. Is the goal clear enough to steer by? Yes, §1 states it in business terms with the "goal wins" rule. One gap: the handoff file could not be written under the read-only brief, and the implementer is told to create it (see the STATUS note).
