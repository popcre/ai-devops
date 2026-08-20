---
name: hetz-codex-runs-as-ai
description: On hetz, Codex is logged in as the `ai` service account (/home/ai/.codex/auth.json); root has no Codex login, so doctor run as root reports "not authenticated".
metadata:
  type: project
---

On the hetz server, Codex's login lives under the **`ai`** account
(`/home/ai/.codex/auth.json`). `root` has no `auth.json` at all. `install.sh` and
`ai-devops doctor` run as root, so they report "codex is NOT authenticated" even
when Codex works perfectly — verify with `su - ai -c 'codex exec ...'` before
concluding Codex is broken there.

hetz also carries **two different 1Password service-account tokens** at once:
root uses the older `my.1password.com` one, `ai` uses the current
`popcreations.1password.com` one. Both are in the vault (see
[[vibe-coding-vault-reprovisioned]]).

`codex login status` on hetz printed "Logged in using ChatGPT" while every
request returned HTTP 401 — status is not capability, only a real run is.
