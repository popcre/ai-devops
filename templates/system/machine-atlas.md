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
