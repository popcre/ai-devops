# Agent evidence and Jujutsu decision — 2026-09-28 EDT

## Decision

**No-go for Jujutsu rollout, including an opt-in live trial or default switch. Keep Git worktrees and GitHub as the code and backup path.** The six paired offline trials lost no edits and exported equal Git trees, but one harmless untracked file entered a Jujutsu working-copy commit automatically. Added Jujutsu workspaces could not run existing Git-based tooling directly (`git rev-parse --git-dir` exited 128). The privacy stop is decisive without claiming a measured delivery-time gain or loss. No accepted code was authored in Jujutsu or left only in a disposable clone.

## Reproducible comparison and limits

Sources are the [pinned ten-PR baseline](2026-09-27-agent-evidence-jj-baseline.md) and [six-pair disposable pilot](2026-09-27-jujutsu-pilot.md). Their commands, source SHAs, PRs, fixture contents, trial Git trees, binary digest, safety refusal, and readback commits are recorded there. Re-run the baseline's `git log` and PR queries against its pinned SHAs; re-run the pilot's local fixture operations in fresh clones of its pinned SHAs. The two studies have different units and cannot be pooled into a request-to-verified-outcome comparison.

| Measure | Git/current baseline | Jujutsu offline pilot | Decision limit |
|---|---|---|---|
| Request-to-verified-outcome median and p90 | Not measured; ten selected PRs report creation-to-result only, including two still open | Not measured; network, checks, review and merge excluded | No supported business-time gain or p90 claim |
| Evidence-only commits per comparable PR | Eight selected shared-db PRs: 14 path-verified commits; mean 1.75, median 1, nearest-rank p90 4 | No live PRs; zero evidence commits in local fixture branches | No comparable before/after rate |
| Unrelated-main review invalidations | Two selected ai-devops PRs had three main merges mixed with content or check failures; no isolated invalidation | No protected review in offline trials | No demonstrated residual defect or avoided review |
| Agent task handling time | Six serial local Git trials: median 0.840 s, nearest-rank p90 1.010 s | Six serial local jj trials: median 1.185 s, nearest-rank p90 1.819 s | One observation per case; five of six jj cases slower; not delivery time |
| Lost edits and recovery | Zero; conflict trials needed two resolutions each; interruption used one stash recovery | Zero; conflict trials needed one resolution each; interruption used one undo | Small local sample only |
| Safety and GitHub continuity | Normal Git worktrees remain available; protected GitHub path unchanged | Equal Git trees in six pairs; two clean trial branches and migration guard trial exported to bare Git and read back; untracked import privacy stop; workspace Git-tool failure | Bare remotes are local, not GitHub PR or full CI proof |

The PR sample was deliberately selected for relevant evidence and is not a repository-wide rate. Local seconds exclude all review and CI stages. Zero lost edits in six trials cannot establish general recovery safety. The no-go rests on an observed privacy failure and compatibility failure, not on an inferred time saving.

## Continuity, rollback and ownership

At this decision's starting snapshot, ai-devops `origin/main` was `030a503f19599d344a4948486f0355b042e0c522`; both baseline landing `12eb3d3052ddeebd0de7ed7d886c2f816e718c95` (PR #921) and pilot landing `a8b385431d2df94cc2d31ba07e5736072a720479` (PR #924) were verified ancestors with `git merge-base --is-ancestor SHA origin/main`. The final report's own landing SHA must be verified separately after merge. The pilot exported ordinary commits with equal trees to independent *local* bare remotes and cloned them back through Git. A rollback from those exported branches is a normal Git clone/worktree; the temporary jj clone can be abandoned after its content is verified. No fleet installation or default route changed, so current work needs no rollback action.

Existing shared-db #3380 (**non-orchestrator work**) still owns immutable evidence generations and Step 1's two-PR live proof; its PR #3445 remained open at head `8fb8e338f7bee2f6342f8105f608d08d7932c9de` when checked. Ai-devops #887, its earlier reviewer-qualification blocker, was closed. That owner and ai-devops #650 retain their distinct work; this decision creates no replacement issue or PR. Step 2 is **insufficient evidence for a new fix issue** until #3380's accepted transition exposes a specific residual evidence-only cause. Step 3 is **insufficient evidence for a new fix issue** until a clean post-owner unrelated-main invalidation is observed; ai-devops #639 already repaired its known packet case. Neither conditional step is claimed complete by the jj pilot.

The accepted outcome of this child is the recorded no-go and verified source continuity, not a Jujutsu deployment or a repair to shared-db. If a future pilot is proposed, it needs a separate reviewed issue and prospective end-to-end measurement after a proven untracked-file exclusion policy and Git-tool compatibility. The existing owner must supply Step 1's required live PR traces in its own issue before that separate outcome is called complete.
