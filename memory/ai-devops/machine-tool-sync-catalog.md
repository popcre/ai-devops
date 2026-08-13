---
description: "Dotfiles sync reconciles repo-owned local AI command launchers from one catalog and cannot report success while required launchers are missing."
type: project
---

# Machine tool sync catalog

Since 2026-08-13, `config/machine-tools.tsv` is the single list for the
skill-taught Grok, Kimi, DeepSeek, and GLM commands. Dotfiles sync checks it with
`bin/ai-machine-tools-doctor` and repairs only launchers with the narrow platform
installers. Windows GLM remains `.cmd` only and is owned by its OpenCode setup.
Missing optional `grok` or `kimi` provider programs are information, while a
missing repo launcher blocks sync success. Keep Ubuntu `install.sh`'s generic
executable loop unchanged.
