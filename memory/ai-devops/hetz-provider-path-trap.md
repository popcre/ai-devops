---
name: hetz-provider-path-trap
description: On hetz the Grok/Kimi/Qwen CLIs were installed and working while the doctor called them unavailable — the vendor PATH edits had not taken.
metadata:
  type: project
---

2026-08-20: `ai-machine-tools-doctor` on hetz reported "grok/kimi/qwen provider
unavailable" for weeks. All three were installed and working the whole time.
Each vendor installer edits a shell rc file to add its own directory to PATH,
and Kimi's edit never took.

Fixed by `bin/install-ai-provider-clis.sh` (PRs #54/#55), which links every
provider into `~/.local/bin` — already on the default Ubuntu PATH — and repairs
that link on re-runs without reinstalling. Run it as the session user (`ai`),
never root; it refuses root because vendor installers write into `$HOME`.

Two things that will mislead the next session:
- A bare `ssh host 'cmd'` gets a NON-login shell whose PATH lacks
  `~/.local/bin`. Check with `ssh host 'bash -lc "command -v grok kimi qwen"'`
  before concluding anything is missing.
- Qwen must NOT be installed via npm: that package needs Node 22+ and hetz ships
  Node 20.

See [[prove-capability-with-a-live-call]].
