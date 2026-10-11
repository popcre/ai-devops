# HTS installation maintenance-route feasibility

Observed October 11, 2026, 10:52 AM EDT on edge-dev3. Owner: Codex; existing issues popcre/ai-devops#335 and popcre/designflow-backend#94.

## Decision requested from independent reviewer

Review the evidence and challenge this conclusion: no supported, currently invocable Linux privileged maintenance route has been established for this desktop session. This note requests review of the feasibility finding and preservation boundary, not authorization to bypass a restriction, create a privileged executor, or execute installation. An APPROVE of this note must never be treated as installation or platform privilege authorization. If repository evidence establishes an existing supported route, cite its exact entrypoint, required provisioned authority, and applicability to this host; otherwise retain BLOCKED.

## Verified facts

- The shell, Codex process and ChatGPT parent each report NoNewPrivs=1; UID is 1000. Their systemd ancestors report NoNewPrivs=0. This locates the observed restriction within the application process ancestry; it does not prove which component originally set it.
- The installed toolkit checkout remains d7ae3261214d33a62ec7024dc3e5f4da7ed88df1. The managed gate resolves to its bin/ai-task-gates. Manifest SHA256 remains f1c8dbd8025e7fd038669a9518b870e203795c13e0f20007442d76ecdb61cb91.
- Approved installation target 8d710b36d193d4cb6dc86762fd84a9d959c23a8f remains an ancestor of freshly fetched origin/main. Original final-check report remains in the original review worktree and contains `Approved stale-linux-manifest-recovery.` No new receipt was consumed and no installer ran in this continuation.
- docs/deployment.md documents the pinned update.sh/full install.sh route. install.sh requires sudo for system locations and protected backups. This session's earlier sudo failure precedes installation. Full filesystem access does not establish privilege authority.
- The documented Windows runner maintenance task is Windows-only and qualification-refresh-only. It is not a Linux toolkit-installation route.
- Searches of toolkit docs, bin, tools, config, workflows and templates found no Linux privileged installation broker; the matching NoNewPrivileges setting belongs to the GLM service and is not an installation authority. Filtered system/user unit inventories expose no named ai-devops/Codex/ChatGPT maintenance service. This is bounded discovery, not proof that no service could exist anywhere.
- Exposed tools provide no privilege-escalation or privileged toolkit-maintenance capability. This session's execution policy forbids elevated tool execution. Creating an alternate executor or using SSH/systemd/polkit/runner indirection to escape the restriction is outside this finding and is not authorized by review.

## Official source checks

- https://learn.chatgpt.com/docs/linux/linux-app documents Linux desktop package installation/update; it does not establish an invocable privileged maintenance API for this session.
- https://learn.chatgpt.com/docs/permissions documents filesystem/network permission profiles; this does not establish a supported privilege transition for this observed inherited restriction.
- The earlier response implying that a supported maintenance route definitely existed was unsupported. Availability remains unestablished; no restart or alternative executor is promised as a fix.

## Preservation and remaining work

No source repair, guard change, OS change, canonical checkout advance, secret retrieval, credential rotation, application POST, database/cloud mutation, RFQ Apply/Save or PR171 integration occurred. Original reviews, candidate worktrees and private evidence remain untouched. The installed gate remains authoritative; current upstream tooling is not a substitute live-admission path.

Codex owns establishing legitimate platform-provided installation authority on #335. A supported route must be explicitly available and reviewed for exact host/target/inputs before use; independent review alone cannot create that authority. Until then installation and all dependent #94 live acceptance remain BLOCKED. Genuine native learning, accepted non-operative precedent, replay, retrieval, refusal/privacy and RFQ/standalone closed-tab durability remain unperformed. Uma alone owns PR171 integration.
