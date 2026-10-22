# Machine atlas (protected source)

Concrete machine names, addresses, provider project identifiers, users, keys,
and private paths are intentionally excluded from this public repository.

The canonical atlas is stored in the private
`u2giants/ai-devops-private-config` repository. Restore or inspect it with:

```bash
ai-private-config sync
ai-private-config path machine_atlas
```

Installers and global-instruction adoption must resolve the protected file at
runtime. Do not copy concrete topology back into this public placeholder.

## Machine classes (rule is public; addresses are not)

| Class | Allowed | Forbidden |
|---|---|---|
| Dev | Full ai-devops toolkit install and updates | — |
| **Networking only** (`edge-alien`, `edge-runn-envy`, `edge-runn-xps`) | SSH key, SSH config, hostnames, Tailscale | Any ai-devops toolkit install (bootstrap, install.sh, setup-machine, skills, MCP, reviewers, agents) |

These three hosts are **not development machines**. Repeated mistakes installed
toolkit on them. Always check the hostname before installing. Binding detail:
[`../../docs/deployment.md`](../../docs/deployment.md) § Machine classes.

## Commands that are missing (checked so sessions stop rediscovering them)

Verified on edge-dev3 on 2026-10-21 (EDT) unless marked otherwise.

- **No `psql` and no `cygpath`** (cygpath is Windows Git Bash only). For
  database reads use the Supabase MCP tool, never psql.
- **Non-interactive shells (agent tool calls, cron, CI) lack `python` and
  `supabase`.** `python` exists only as a `~/.local/bin` link and the
  `supabase` CLI only under `~/.supabase/bin`, both missing from the default
  `PATH`. Always write `python3`; use the Supabase MCP tool for queries.
- `pgrep` exists in `/usr/bin` (edge-dev3); unverified on other Linux hosts.
- **`op` CLI is not signed in** (`no account found`). Read secrets through the
  1Password MCP runner (`op_run`), whose service account works.
- All machines: no `psql`; the `supabase` CLI is not on any agent `PATH`
  (unverified outside edge-dev3). Use the Supabase MCP tool.
