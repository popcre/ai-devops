# Plan: split the CI suite manifest so tool fixes merge in parallel

Handoff registration: [HANDOFF.d/2026-09-28T1755Z-edge-dev3-claude-plans-manifest-and-self-healing.md](HANDOFF.d/2026-09-28T1755Z-edge-dev3-claude-plans-manifest-and-self-healing.md)
Owner issue: https://github.com/popcre/ai-devops/issues/1001.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 0 Prove the collision | ✅ done (2026-09-28) | [manifest-collision-2026-09.md](tests/verification/repo-throughput/manifest-collision-2026-09.md): #721 and #849 both hand-resolved textual manifest conflicts during main refreshes; gate met |
| 1 Loader | ⬜ open | — |
| 2 Migrate data | ⬜ open | — |
| 3 Switch readers | ⬜ open | — |
| 4 Remove the monolith | ⬜ open | — |
| 5 Live proof | ⬜ open | — |

A fresh session starts at Step 0.

## 1. Ultimate goal

Albert's AI sessions ship about ten small tool fixes a day to `popcre/ai-devops`.
Nearly all of them edit one shared file, `config/ci-suite-manifest.json`. Two fixes
that touch the same lines of one file collide: the second must refresh against
`main`, rerun the full CI (roughly 20–40 minutes), and re-enter the merge queue. The
goal is that **independent fixes stop waiting on each other**: a fix that adds or
changes one test suite touches only that suite's own small file, so several fixes can
sit in the merge queue together and land in one batch.

If a step conflicts with this goal, the goal wins — stop and flag it on the owner issue.

## 2. What this application is

`popcre/ai-devops` (default branch `main`, protected, merge queue) holds Albert's
shared AI tooling: Bash/PowerShell wrappers in `bin/`, suites in `tests/`, and config in
`config/`. CI is `.github/workflows/verify.yml`: Linux offline shards 1–4, Windows
offline sections 1–6 (Blacksmith runners), and one required aggregate check,
`verification-closure`. Tools are installed onto machines (edge-dev3 Linux, edge-dev
Windows, hetz) by `install.sh` / `install.ps1`. There is no deployed service.

## 3. Trigger

On 2026-09-28 a parallel session observed that about ten tool-fix PRs were serialized.
All of them edited `config/ci-suite-manifest.json`, which changed in 21 commits on
`main` between 2026-09-21 and 2026-09-28 (`git log origin/main --since=7.days --name-only`).
Examples: #944, #950, #935, #666, #857, #855, #849, #978, #979.

## 4. Scope

In scope: the manifest's per-suite data (which suites exist, measured Linux seconds,
Windows membership), a loader that assembles the same logical structure, and every
reader switching to that loader.

NOT in this plan:
- Changing the shard/section balancing algorithm or the section counts.
- Changing the merge-queue ruleset (21564317) or required checks.
- Changing which tests run for a given diff (`tests/lib-selection.sh` behavior), except
  where the manifest path itself is a trigger (Step 3).
- Suspensions policy (`suspended_*`), which stays a single deliberate file.

## 5. Current state

- `config/ci-suite-manifest.json` (schema_version 2) has these top-level keys:
  `linux_offline_suite_seconds` (map suite→int), `bash`, `powershell`,
  `windows_sensitive_bash`, `windows_reviewer_safety_bash`, `windows_offline_bash`,
  `windows_offline_shards`, `windows_offline_powershell_shard`, `suspended_bash`,
  `suspended_powershell`, `_comment_suspended` and `affected_suite_rules`.
- Readers:
  - `tests/test-all.sh:28` and `:253-259` validate the seconds map and balance the sections.
  - `tests/lib-selection.sh:143` selects tests.
  - `tests/test-all.ps1:61`, `:115` and `:156` force the full PowerShell run when the manifest path changes.
  - `tests/test-workflow-policy.sh:8`, `:299` and `:314-317` enforce that the seconds name only real suites and that the four sections partition every Bash suite exactly once.
  - `.github/workflows/verify.yml:81` and `:197` set the section boundaries.
- Nothing has been started.

## 6. Key findings

- The ruleset has `strict_required_status_checks_policy: false`, so GitHub itself does
  not force "up to date" branches. Serialization comes from (a) textual Git conflicts in
  shared arrays/maps and (b) the whole-manifest consistency checks
  (`tests/test-workflow-policy.sh:314-317`) that fail when a queued batch combines two
  edits into an inconsistent partition.
- Any manifest edit forces the full Windows PowerShell run (`tests/test-all.ps1:61`),
  so every tool fix pays the longest CI path.
- **Unproven:** a 2026-09-28 search found no recent PR in a `DIRTY`/`BEHIND` state and no
  recorded queue ejection naming the manifest. The collision is inferred from structure.
  Step 0 exists to prove it before building anything.

## 7. Rejected approaches

- **Sorting keys / one entry per line only.** This cuts textual conflicts but keeps the
  cross-file partition check coupled, and appends at the end of arrays still collide.
- **A Git merge driver (union merge) for the JSON.** It is invisible to GitHub's merge
  queue, which merges server-side, so it does not help the queue.
- **Dropping the partition check.** That removes a real safety net: a suite that runs in
  no section would silently never run.

## 8. Decisions

- LOCKED: per-suite files live at `config/ci-suites/<suite-file-name>.json`, one per
  suite (e.g. `config/ci-suites/test-ai-gh.sh.json`), holding
  `{ "kind": "bash"|"powershell", "linux_seconds": N, "windows": [...membership tags] }`.
- LOCKED: global, rarely-edited data (`windows_offline_shards` boundaries,
  `affected_suite_rules`, `suspended_*`) stays in a small `config/ci-suite-manifest.json`
  with no per-suite arrays.
- LOCKED: one loader produces the exact former logical JSON, so readers change one call.
- OPEN: whether sections are still hand-assigned per suite, or computed from seconds.
  Criteria: if computing them keeps every current section within its measured budget in
  `tests/verification/repo-throughput/issue-666-windows-section-rebalance-20260922.md`,
  compute them. Otherwise keep a per-suite `section` field.

## 9. Steps

0. **Prove the collision.** Take PRs merged 2026-09-21..28 that touched the manifest and
   list, for each, any `main` merge commits into the head and any queue removals
   (`gh pr view N --json timelineItems`). Record the results in
   `tests/verification/repo-throughput/manifest-collision-2026-09.md`.
   Gate: the file shows at least two PRs delayed by manifest refreshes or ejections.
   If it shows none, stop, comment on the owner issue, and close it as not needed.
1. **Loader.** Add `tools/ci-suites/load-manifest` (Bash+jq, no new dependency). It
   emits the full legacy-shaped JSON on stdout from `config/ci-suites/*.json` plus the
   slim global file. Gate: its output, sorted with `jq -S`, equals the current
   `jq -S . config/ci-suite-manifest.json` byte for byte.
2. **Migrate data.** A one-off script writes each suite's file from the current
   manifest. Gate: the Step 1 equality still holds.
3. **Switch readers.** Every reader in §5 calls the loader instead of reading the file.
   Update `tests/test-all.ps1:61` so that a change under `config/ci-suites/` forces only
   that suite's platform, and only the global file forces the full run.
   Gate: `bash tests/test-all.sh` and `tests/test-workflow-policy.sh` pass, and
   `verify.yml` on the PR produces the same section membership as before (compare the
   shard logs).
4. **Remove per-suite keys from the global file** and add a policy test that rejects
   their reintroduction. Gate: the new test passes, and it fails when a `bash` array is
   re-added.
5. **Live proof.** Open two throwaway PRs that each add a trivial suite, and enqueue both.
   Gate: both merge in one queue batch with no main-refresh commit.

## 10. Tests

- New `tests/test-ci-suite-loader.sh` covers four cases: the loader matches the legacy
  golden output; a malformed suite file fails naming that file; a duplicate suite fails;
  and a suite in no section fails.
- The existing suites `tests/test-workflow-policy.sh`, `tests/test-all.sh` (full) and
  `tests/test-all.ps1` must stay green.

## 11. Constraints and gotchas

- Never push to `main`. Use a branch, a PR and the merge queue (`config/repository-policy.json`).
- Required-check names must not change (see the merge-queue name trap in §13).
- There are no `paths:` filters or `if:` skips on required jobs.
- Do not add Python or Node to the Bash CI path.
- The new suite needs a seconds entry itself, in its own new per-suite file.
- Windows CRLF breaks Bash. Add the new directory to `.gitattributes` with `eol=lf`.

## 12. Access

- `gh` is authenticated as `u2giants`, which has admin on popcre/ai-devops.
- Use `bin/ai-pr-wait <pr>` for CI waits. No secrets are needed.

## 13. Done, risks, open questions

Done means all of the following:
- Steps 0–5 are ticked with artifacts.
- The PR is merged and CI is green.
- The STATUS table is updated.
- The owner issue is closed with the Step 5 PR numbers.

Risks and open questions:
- **Merge-queue name trap.** A reader missed during the switch leaves a suite running in
  no section. The partition test catches this. Rollback is to revert the PR, because the
  loader output equals the old file.
- **Unproven benefit.** Step 0 may show no real collision. Close the issue if so.

## Self-audit

1. A fresh session can execute this without questions. Evidence: §2 and §5 give the
   context and readers, and every step in §9 has a gate.
2. All known background is carried: the unproven-collision caveat (§6) and the rejected
   approaches (§7).
3. The goal (§1) is enough to judge a wrong step. For example, if Step 0 finds no
   collision, the goal says stop.
