# Memory index — synology-monitor

- [Albert is not a programmer — give runnable commands](albert-is-not-a-programmer-give-runnable-commands.md) — hand-off steps must be exact copy-pasteable commands with host/path/expected output, never "deploy X" or "enable Y". Most repeated complaint in this project.
- [Verify MCP availability via claude mcp list](verify-mcp-availability-via-claude-mcp-list.md) — a negative ToolSearch is not proof a server is unconnected; I once told the user a capability was missing when it wasn't.
- [The NAS MCP is named synology-monitor](nas-mcp-is-named-synology-monitor.md) — server naming, the stale token, and why worktree sessions never load it.
- [git fetch before claiming "not merged"](git-fetch-before-claiming-not-merged.md) — I blocked a task on a stale local `main`; the fix was already on `origin/main`.
- [Prove NAS tools by running, not reading](prove-nas-tools-by-running-not-reading.md) — enabled/typechecks-clean hides tools that are dead on arrival (missing binary, validator-blocked, no device access); invoke them via the MCP or a real test.
- [Kimi Code CLI for a local K3 second opinion](kimi-code-cli-local-second-opinion.md) — `~/.kimi-code/bin/kimi -m kimi-code/k3 -p`; reaches real K3, which the OpenRouter key cannot.
- [OpenRouter Oracle key has embedded quotes](openrouter-oracle-key-has-embedded-quotes.md) — the 1Password value is wrapped in literal `"`, causing 401 "Missing Authentication header"; strip before use.
- [Write tool mangles literal control chars](write-tool-mangles-literal-control-chars.md) — build CR/ESC/bidi chars with String.fromCharCode in source and tests; literal control bytes don't survive Write/Edit content.
- [Verify spawned-task outcomes in git, not session status](verify-spawned-task-outcomes-in-git.md) — "not running" hid a fully-tested, uncommitted fix for a live root RCE; check branches and worktree status.
