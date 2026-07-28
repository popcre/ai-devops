---
name: project_kimi_k3_model_alias
description: "Kimi CLI defaults to kimi-for-coding, NOT K3 — pass -m kimi-code/k3 explicitly when asked for K3"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6f8e8273-6e75-4e00-834e-44179bc7b74b
  modified: 2026-07-28T19:14:25.815Z
---

`kimi` (Kimi Code CLI 0.27.0, `/home/ai/.kimi-code/bin/kimi`) has
`default_model = "kimi-code/kimi-for-coding"` in `~/.kimi-code/config.toml`.
**K3 is NOT the default.** When Albert asks to run something by "Kimi K3", pass
the alias explicitly:

```bash
kimi -m kimi-code/k3 -p "<prompt>"
```

Three aliases are configured: `kimi-code/kimi-for-coding` (default),
`kimi-code/kimi-for-coding-highspeed`, `kimi-code/k3`. Confirm the live list with
`grep -i model ~/.kimi-code/config.toml` rather than assuming — auth is OAuth via
`managed:kimi-code`, so `kimi provider list` shows the count but not the aliases.

Verified working 2026-07-28 (read-only review of a shared-db PR). Reviews come
back genuinely useful — K3 caught a real SQL-vs-JS semantic gap (`coalesce('', x)`
does not fall through in SQL while `''`-aware JS does) that was worth a live data
check. See [[feedback_no_workarounds]] — verify its findings against real data
rather than accepting or dismissing them on reasoning alone.
