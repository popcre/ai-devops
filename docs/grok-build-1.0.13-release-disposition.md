# Grok Build 1.0.6 – 1.0.13 release disposition

Frozen decision record for tracking issue #251 ("Upgrade Grok Build wrapper
support from 1.0.5 to 1.0.13"). Every wrapper-facing item shipped between 1.0.6
and 1.0.13 is classified here exactly once. Nothing was adopted because it was
new; nothing was skipped because it was unread.

The rule this table applies: a vendor reliability fix is welcome, but it never
*replaces* one of our controls. Our read-only permission set, exact-head pinning,
cost ceilings, environment isolation, process-tree ownership and terminal-JSON
wait loop stay in force on 1.0.13 exactly as they were on 1.0.5.

## Categories

- **Adopted** — the repository changed to use or enforce it.
- **Inherited** — a native improvement we benefit from with no code change. The
  wrapper contract is unaffected; we record it so a later session does not
  "re-fix" something the vendor already fixed.
- **Excluded** — interactive/UI-only, or unsafe for an unattended, read-only,
  cost-capped reviewer. Excluded is a decision, not an oversight.

## Disposition

| Release | Adopted | Inherited (no code change) | Excluded |
|---|---|---|---|
| 1.0.6 | Large/unhealthy-repo startup; queued-goal messages. Windows hook project path is rechecked under #249 only. | Consent reliability; storage error handling. | Clone projected tree (evaluated, not adopted — our worktree lifecycle stays repository-owned). Selection, editing, double-click, link and image/video UI. |
| 1.0.7 | Noninteractive tokenless MCP auth, auth-refresh races, loop interruption, subagent tool reduction. | Scheduled deletion; status script timer. | Connection-timeout tuning (our wait loop already bounds this). Permission cards, workflow catalog/UI, mail links. |
| 1.0.8 | MCP form/URL consent — carried to #249. Concurrent subagent and startup behaviour; follow-up while waiting. | Invented-tool error text; folder zip semantics. | Draft stash, workflow autocomplete, status row, UI context display. |
| 1.0.9 | MCP URL identity/add behaviour — carried to #249. Subagent retry/burst/startup; narrow Bash allow semantics; memory-as-history guidance; background shell interjection. | — | Workflow effort/budget and clone optimisations (evaluated, not adopted: they move cost control into the vendor). Feedback, menus, dashboard and all prompt/layout/copy/modal cosmetics. |
| 1.0.10 | — | Faster matching checkout reuse. | Provider worktree reuse (evaluated, not adopted: the repository owns worktree lifecycle, isolation and cleanup). |
| 1.0.11 | Headless session discovery; permission-chain reliability; background wait completion. | Configurable interactive default; history duration/footer — documentation only. | The headless permission startup hint, and `--always-approve` / `--permission-mode auto` / `bypassPermissions` in every form. A reviewer that can approve its own tools is not read-only. Mouse/paste/cards/images/execute expansion/voice. |
| 1.0.12 | MCP transient retry — carried to #249. Subagent wait isolation; reasoning/rewind/mode token truth; compaction state; worktree speed. | .NET watcher; recap reliability. | Table-copy and friendly prompt descriptions. |
| 1.0.13 | Truncation continuation and tool-call completion; transient inference retries; Windows home/worktree handling; durable session saves; compaction/truncation diagnostics; subagent/MCP startup. | Large-image resilience; compressed updates; monitor stop reminder. | Full UUID scheduled IDs — nothing in this repository consumes them yet. iTerm image preview and Windows hyperlink cosmetics. |

## What "supported" now means

Before this issue, a Grok binary that merely *ran* counted as installed. That was
the defect: both wrappers parse one build's terminal JSON, stop reasons, usage
and cost keys, and session behaviour, and that parsing was never version-checked.

Now the exact qualified version is a repository fact in
[`config/provider-cli-versions.json`](../config/provider-cli-versions.json),
read by one tool, `bin/ai-provider-version`, and enforced in four places:

- both installers upgrade a wrong build to exactly the pinned version with
  `grok update --version <VERSION>`, keeping a restorable backup of the previous
  executable and rolling back on failure or on a wrong resulting version;
- both wrappers refuse paid work against any other build, before the provider is
  contacted, naming the installed and the required version;
- both doctors report the installed version against the required one;
- the Windows verification path reports a wrong build as `STALE` and exits 2.

The backup holds the executable and nothing else. Credentials, sessions and logs
under `~/.grok` are never read or copied.

Kimi and Qwen are deliberately left unpinned: qualifying Grok must not force an
unrelated provider upgrade.
