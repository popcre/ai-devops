---
issue: 1562
status: OPEN
owner: mimo/snapshot-digest-test-failure
---

# Snapshot-digest test still red after #1613: `deepseek_real_unittest_keeps_immutable_snapshot_digest`

Written 2026-10-12T2113Z (5:13 PM EDT) on machine `edge-dev` by a MiMo Desktop session.
Repo `popcre/ai-devops`. Related closed issue: [#1612](https://github.com/popcre/ai-devops/issues/1612) (one cause only). Umbrella: [#1562](https://github.com/popcre/ai-devops/issues/1562). Companion open handoff (do not edit): [2026-10-12T1310Z-edge-dev3-claude-1562-door-diagnostics-leak.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-12T1310Z-edge-dev3-claude-1562-door-diagnostics-leak.md) lists this as its next step 2.

## 0. Business decisions only the owner can make

**None — nothing in this workstream needs the owner.**

Technical approvals stay with an assigned AI reviewer (owner ruling 2026-09-28: never ask a human to approve). The choice of whether the remaining red checks are product defects or Windows-test portability gaps is a technical diagnosis for the next session, not a business question.

**Already settled — do NOT re-ask:**
- 2026-10-12: EDGE-ALIEN is not a dev machine; never run reviews or live proofs there (Albert, verbatim: "edge-alien is not a dev machine. it shouldn't have this bulky toolkit installed.").
- 2026-09-28: never ask a human to approve technical actions; assigned AI reviewers gate them.

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery toolkit for a multi-model AI workflow (reviewer lifecycle, provider doors, private failure diagnostics). Not an app or service. Router: [AGENTS.md](https://github.com/popcre/ai-devops/blob/main/AGENTS.md). Stack: Bash + Python on Windows (Git Bash) and Linux. The suite in question is offline (stub providers; no paid calls).

## 2. What we set out to do this session, and why

Albert asked for a wrap-up and a **next-session prompt to fix the snapshot-digest test failure** named in the door-diagnostics handoff: `deepseek_real_unittest_keeps_immutable_snapshot_digest` in [tests/test-ai-review-engine.sh](https://github.com/popcre/ai-devops/blob/main/tests/test-ai-review-engine.sh). This session did **not** start the fix (wrap-up scope freeze). Goal of the successor: root-cause the still-red check and repair it under reviewer-safety class with independent exact-head review.

Why it matters: the check guards that a real `python3 -m unittest` run during a review never mutates the runner's immutable source snapshot (bytecode must land in the door's scratch workdir, not the sealed tree). If that invariant is broken, review evidence can be silently poisoned (this class of bug already caused a lost DeepSeek diagnostics dir on EDGE-ALIEN — WinError 183, PR #1599).

## 3. Current state — what is true right now

- **One cause is already fixed and merged:** [#1612](https://github.com/popcre/ai-devops/issues/1612) / [PR #1613](https://github.com/popcre/ai-devops/pull/1613) (`29d6da41`). The stub OpenCode used to require `__pycache__` after a real unittest run, but `PYTHONDONTWRITEBYTECODE=1` (set on edge-dev3) suppressed bytecode, so the stub exited 1 and the check went red for the wrong reason. The stub now forces bytecode (`env -u PYTHONDONTWRITEBYTECODE -u PYTHONPYCACHEPREFIX python3 -m unittest …`) and the door call pins a hostile env as an offline regression. Issue #1612 is **CLOSED**.
- **The check is still FAIL on current `main` on host `edge-dev` (this machine), 2026-10-12 ~5:00 PM EDT.** Full `tests/test-ai-review-engine.sh` result on `1e816137`: **205 passed, 4 failed, 1 skipped**. The four reds:
  1. `deepseek_real_unittest_keeps_immutable_snapshot_digest` — **this workstream's target.**
  2. `deepseek_private_diagnostic_permissions` — asserts `stat -c %a` is `700` on the private diagnostics dir and `600` on `report.md` ([tests/test-ai-review-engine.sh](https://github.com/popcre/ai-devops/blob/main/tests/test-ai-review-engine.sh#L1302-L1303)). Strong Windows/MSYS suspect (`stat -c %a` ACL encoding), not proven.
  3. `native muse-code clean credential boundary`
  4. `native opencode clean credential boundary` — both call `muse_boundary_offline` ([tests/test-ai-review-engine.sh](https://github.com/popcre/ai-devops/blob/main/tests/test-ai-review-engine.sh#L1318-L1351)); the fixture launches Muse with `env -i` and foreign secret sentinels. Not diagnosed this session.
- **The sibling check `deepseek_tests_run_in_owned_scratch_and_remove_it` PASSES** on the same run ([tests/test-ai-review-engine.sh](https://github.com/popcre/ai-devops/blob/main/tests/test-ai-review-engine.sh#L1198-L1199)). So the stub *did* record a scratch workdir different from the artifact source, and that workdir was removed. The immutable-digest check failing while this passes is the central clue (see §5).
- **Not started:** root-cause of the residual failure; no fix branch; no new issue (wrap-up freeze). #1612 is closed and must not be reopened for this residual without confirming it is the same cause.
- **Landed this session (docs only):** [PR #1623](https://github.com/popcre/ai-devops/pull/1623) recorded that the PR #1599 live proof on 4837 is done (squash commit `8ceb5388` on main). Unrelated to this test.

## 4. Everything we tried that did NOT work

This session did not attempt a fix. Dead ends recorded from the prior workstream and from #1613 so the successor does not repeat them:

- **Treating every red as "PYTHONDONTWRITEBYTECODE ate `__pycache__`."** That was true on edge-dev3 and is fixed in #1613. It is **not** the whole story: on edge-dev after #1613 the check is still red, and the scratch-workdir sibling check is green. Do not re-diagnose only the bytecode-suppression path.
- **Assuming the check name means the digest function is wrong.** `bin/ai-review-sandbox digest` is used for both before/after; if both sides used a broken digest the equality would still hold. A failure here is almost certainly *the tree changed* or *the door returned non-zero*, not a hash-function bug (unlike the older `snapshot-digest-mismatch` / `--full-index` issue documented in [docs/reviewer-failure-full-writeup.md](https://github.com/popcre/ai-devops/blob/main/docs/reviewer-failure-full-writeup.md#L100) — different bug, already fixed).
- **Running the whole `test-ai-review-engine.sh` as a black box.** It is long (this host hit a 5-minute tool cap mid-suite the first time). Prefer a focused repro that prints the three conjuncts (see §6 step 1).

## 5. Root causes and key findings

- **The assertion is three conjuncts** ([tests/test-ai-review-engine.sh](https://github.com/popcre/ai-devops/blob/main/tests/test-ai-review-engine.sh#L1196-L1197)):
  1. `DS_ARTIFACT_RC` — the door's exit code for the review against a copied snapshot (`DS_ARTIFACT_SOURCE`).
  2. `DS_ARTIFACT_DIGEST = DS_ARTIFACT_AFTER` — `bin/ai-review-sandbox digest` of that copy must not change across the run.
  3. `test ! -d "$DS_ARTIFACT_SOURCE/__pycache__"` — no bytecode in the sealed snapshot.
- **Clue:** `deepseek_tests_run_in_owned_scratch_and_remove_it` passes, so the stub recorded `$PWD` = a scratch dir ≠ `DS_ARTIFACT_SOURCE`, ran `python3 -m unittest test_allocation.py` there, and the scratch dir was removed. Bytecode therefore should *not* be in the snapshot. If conjunct 3 still fires, something else created `__pycache__` in the source; if conjunct 1 or 2 fires, the door failed or wrote into `DOOR_WORKDIR`/`DOOR_PACKET_DIR` (both are set to `$DS_ARTIFACT_SOURCE` in the fixture).
- **Likely hypothesis (unproven):** the door (or its packet/diagnostics writer) mutates `DOOR_WORKDIR` / `DOOR_PACKET_DIR` (the sealed source copy) so the after-digest differs — not a unittest bytecode problem at all. Prove or kill this first by printing digests and `find`/`git status` on the copy before/after.
- **Stub contract** ([tests/test-ai-review-engine.sh](https://github.com/popcre/ai-devops/blob/main/tests/test-ai-review-engine.sh#L1100-L1141)): requires `--dir` == `$PWD` == either the prompt's "Trusted execution workspace:" line or `Directory you are reading:` from MANIFEST; then `cd "$target"` and runs unittest; refuses to continue if `test -d __pycache__` fails after the run. #1613 forces bytecode in that run.
- **Windows gotcha:** this host is `edge-dev` (Windows, Git Bash). `stat -c %a` (used by the sibling permissions check) is a GNU coreutils idiom that often lies or fails under MSYS — relevant if you also pick up reds 2–4.
- **Do not weaken the check.** It encodes a real custody invariant (immutable review snapshot). A passing-by-loosening change is a reviewer-safety regression and needs independent exact-head review.

## 6. Exact next steps

1. **Reproduce with visible conjuncts.** From a clean `main` worktree, run only the deepseek artifact section (or the whole file) and print, after the door call: `DS_ARTIFACT_RC`, both digests, `ls -la "$DS_ARTIFACT_SOURCE"` (especially `__pycache__`), and `cat "$TMP/ds-artifact-err"`. You'll know this worked when you can say *which* of the three conjuncts is false, with a number or a path.
2. **If the digest changed:** diff a recursive listing of `DS_ARTIFACT_SOURCE` before vs after the door call. Identify every writer (door packet, diagnostics dir, report, `.pyc`, MANIFEST touch). You'll know it worked when you have the exact new/changed path and the code line that writes it.
3. **If `__pycache__` exists in the source:** find who created it despite the scratch workdir (child cwd leak, `PYTHONPYCACHEPREFIX` still set on a path that lands in the source, or a second unittest). You'll know it worked when removing that writer leaves the tree byte-identical.
4. **If `DS_ARTIFACT_RC` ≠ 0:** read `ds-artifact-out` / `ds-artifact-err` and the door's private diagnostics; classify the exit (stub contract, token, timeout, report floor). You'll know it worked when the exit cause is named with the failing line.
5. **Minimal fix + adversarial test.** Keep the three conjuncts. Add a regression that fails on the old behavior. You'll know it worked when `bash tests/test-ai-review-engine.sh` shows `deepseek_real_unittest_keeps_immutable_snapshot_digest` ok on both a clean and a `PYTHONDONTWRITEBYTECODE=1` environment, and the suite total is green except any separately owned reds.
6. **Reviewer-safety delivery.** `ai-task-gates start --class reviewer-safety`, independent non-Claude exact-head `final-check` (not the implementer), branch + PR, merge queue, confirm on `origin/main`. You'll know it worked when the merge commit is on main and the focused suite is green on at least one Windows dev host and one Linux host.
7. **Optional (same suite, separate commits/PRs if touched):** diagnose `deepseek_private_diagnostic_permissions` and the two `native * clean credential boundary` reds. Do not bundle them into the snapshot-digest fix unless the root cause is shared. You'll know each worked when that named check is ok on Windows Git Bash without weakening its assertions.
8. **Retire paperwork.** When the check is green on main, delete this handoff (successor rule) and tick/close the matching #1562 checklist item if one exists for it. The door-diagnostics handoff's "next step 2" becomes obsolete — do **not** edit that file; note completion in the PR body instead.

## 7. Constraints and gotchas in force

- **Reviewer-safety class:** independent non-Claude exact-head review before merge; merge queue; never push to protected `main`. `git var GIT_COMMITTER_IDENT` must show `Albert Hazan <u2giants@users.noreply.github.com>` before commit.
- **EDGE-ALIEN is not a dev machine** (owner ruling 2026-10-12). Do not run this suite there as a proof host; the GitHub Actions runner on that box is intentionally kept and is not a substitute for a dev proof.
- **Canonical checkout is landing-only.** Do the work in a dedicated worktree. Stage only your own files.
- **Do not weaken immutable-custody assertions** to make the suite green. Fail closed.
- **Use `bin/ai-gh` / `bin/ai-pr-wait --repo popcre/ai-devops`** for every GitHub call (spacing, budget). Bounded waits only (`--timeout-minutes`).
- **Do not edit** [2026-10-12T1310Z-edge-dev3-claude-1562-door-diagnostics-leak.md](https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-12T1310Z-edge-dev3-claude-1562-door-diagnostics-leak.md) — another session owns it.
- PowerShell must stay compatible; run Bash tests through Git Bash on Windows.

## 8. Access and environment

- **This session's host:** `edge-dev` (Windows 11, Git Bash). The failing suite result above is from this host on `main` at `1e816137`.
- **Useful peers:** `4837` / `al8960ofc` (Windows, SSH alias `4837`), `916`, Linux `edge-dev3`. Connection details live in the private machine atlas — never inline addresses.
- **Secrets:** none used for this offline suite. If any appear, 1Password vault `vibe_coding` only.
- **Test temp:** suite uses `mktemp -d` and cleans on EXIT (`tests/test-ai-review-engine.sh` header). Scratch files from wrap-up live under the session temp root only.

## 9. Open questions and risks

- **Which conjunct fails is still unknown** (2026-10-12). The §6 step 1 repro is mandatory before any fix proposal.
- **Are reds 2–4 the same root cause?** Unknown. `stat -c %a` on Windows is the leading suspicion for `deepseek_private_diagnostic_permissions`; the muse boundary reds may be `env -i` / PATH / `stat` differences on MSYS. Date: 2026-10-12.
- **Risk: fixing only the stub again.** #1613 already fixed one fixture lie. Another fixture-only tweak that makes the check pass without protecting the sealed snapshot is a false repair. The gate is: the after-digest equals the before-digest *and* the tree has no `__pycache__` *and* the door exits 0, for the right reasons.
- **Risk: this may reproduce only on Windows Git Bash.** If it is green on Linux, the defect is platform-specific (path form, `stat`, `env -i`, symlink, ACL) — say so explicitly in the PR rather than calling it "fixed" from a Linux-only run.
- **#1612 is closed.** Reopen only if the successor proves the residual is the same PYTHONDONTWRITEBYTECODE cause (unlikely after #1613). Otherwise leave it closed and track under #1562 or a fresh issue when one is allowed.

---

## Self-audit (handoff-writer Mode A)

1. **Comprehensive enough for a brand-new developer?** Yes — §1 orients the repo, §3 gives the live 205/4/1 result and names all four reds, §6 step 1 is a first command-level action with a success gate, §7 carries the safety rails.
2. **As effective as this session?** Yes for diagnosis kickoff — this session did not fix anything; its unique knowledge (sibling check green; #1613 not sufficient; three-conjunct breakdown; hypothesis about DOOR_WORKDIR mutation) is in §5.
3. **Every relevant detail?** Yes — background (§1–2), current state with URLs (§3), dead ends (§4), findings (§5), ordered steps with gates (§6), constraints (§7), access (§8), open questions (§9). Commit `29d6da41` / PR #1613 / issue #1612 are cited; file references are GitHub URLs.
4. **Section 0 sweep?** Yes — no business decision remains; owner rulings already settled are listed; technical gates are named in §7 for an AI reviewer, not for Albert.

Verdict of self-audit: **pass**.
