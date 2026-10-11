# HTS installation maintenance-route feasibility

Observed October 11, 2026, 10:52 AM EDT on edge-dev3. Owner: Codex; existing issues popcre/ai-devops#335 and popcre/designflow-backend#94.

## Decision requested from independent reviewer

Review the evidence and challenge this conclusion: a supported visible-terminal installation route succeeded historically on this host, but this session has no currently available native-desktop capability to operate that route. This note requests review of the feasibility finding and preservation boundary, not authorization to bypass a restriction, create a privileged executor, or execute installation. An APPROVE of this note must never be treated as installation or platform privilege authorization. Installation remains BLOCKED until the platform exposes the supported maintenance capability and the exact current installation inputs are revalidated.

## Verified facts

- The shell, Codex process and ChatGPT parent each report NoNewPrivs=1; UID is 1000. Their systemd ancestors report NoNewPrivs=0. This locates the observed restriction within the application process ancestry; it does not prove which component originally set it.
- The installed toolkit checkout remains d7ae3261214d33a62ec7024dc3e5f4da7ed88df1. The managed gate resolves to its bin/ai-task-gates. Manifest SHA256 remains f1c8dbd8025e7fd038669a9518b870e203795c13e0f20007442d76ecdb61cb91.
- Approved installation target 8d710b36d193d4cb6dc86762fd84a9d959c23a8f remains an ancestor of freshly fetched origin/main. Original final-check report remains in the original review worktree and contains `Approved stale-linux-manifest-recovery.` No new receipt was consumed and no installer ran in this continuation.
- docs/deployment.md documents the pinned update.sh/full install.sh route. install.sh requires sudo for system locations and protected backups. This session's earlier sudo failure precedes installation. Full filesystem access does not establish privilege authority.
- The documented Windows runner maintenance task is Windows-only and qualification-refresh-only. It is not a Linux toolkit-installation route.
- Historical supported route: [October 8 reviewer-credit handoff](../../HANDOFF.d/2026-10-08T1854Z-edge-dev3-codex-reviewer-credit-delivery.md) records successful full installation through a visible Konsole window after exact independent review and one-use authorization, with Albert entering his existing password directly. Its exact evidence line is: `Supported visible Konsole window solved installation.` This establishes a legitimate historical route on edge-dev3, not current access or transferable authority for a different target. The prior installation receipt was consumed and must not be reused. The current HTS target has its own original approved report and retained authorization; those remain distinct and unconsumed.
- Current native access check: the computer-use tool instructions explicitly state `Native computer APIs are disabled.` The supported inventory returned `apps: []` and browser surfaces only. No visible Konsole/native app can be selected through the exposed capability. Browser-only control is not terminal authority; no alternative native-input technology, browser shell, SSH, or privileged runner was used. Albert's current standing instructions rule out asking him to perform a manual installation/password step. The missing capability is platform-provided native maintenance access, not a nonexistent installer and not a missing business decision.
- Searches of toolkit docs, bin, tools, config, workflows and templates found no Linux privileged installation broker; the matching NoNewPrivileges setting belongs to the GLM service and is not an installation authority. Filtered system/user unit inventories expose no named ai-devops/Codex/ChatGPT maintenance service. This is bounded discovery, not proof that no service could exist anywhere.
- Exposed tools provide no privilege-escalation or privileged toolkit-maintenance capability. This session's execution policy forbids elevated tool execution. Creating an alternate executor or using SSH/systemd/polkit/runner indirection to escape the restriction is outside this finding and is not authorized by review.

## Official source checks

- https://learn.chatgpt.com/docs/linux/linux-app documents Linux desktop package installation/update; it does not establish an invocable privileged maintenance API for this session.
- https://learn.chatgpt.com/docs/permissions documents filesystem/network permission profiles; this does not establish a supported privilege transition for this observed inherited restriction.
- Both pages were successfully fetched by the author in this continuation; an offline repository reviewer cannot independently check those external pages. They do not supersede the local visible-terminal precedent.
- The earlier claim that no supported route had been established was too broad: the historical visible-terminal route exists, but its required native access is unavailable in this session. No restart or alternative executor is promised as a fix.

## Preservation and remaining work

No source repair, guard change, OS change, canonical checkout advance, secret retrieval, credential rotation, application POST, database/cloud mutation, RFQ Apply/Save or PR171 integration occurred. Original reviews, candidate worktrees and private evidence remain untouched. The installed gate remains authoritative; current upstream tooling is not a substitute live-admission path.

Codex owns verifying platform-provided access to the supported visible maintenance route on #335. Its native control capability must be available, and exact host/target/inputs revalidated with the original installation review before use; independent review alone cannot enable a disabled platform capability. Until then installation and all dependent #94 live acceptance remain BLOCKED. Genuine native learning, accepted non-operative precedent, replay, retrieval, refusal/privacy and RFQ/standalone closed-tab durability remain unperformed. Uma alone owns PR171 integration. This file is a local review packet, not a published repository documentation change; the reviewed finding will be recorded on the existing issues rather than introducing a separate documentation PR or outcome issue.
