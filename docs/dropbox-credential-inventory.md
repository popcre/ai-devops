# Retired Dropbox configuration inventory

The three active Dropbox setup scripts were retired on 2026-08-10. Each active
file is now a small pointer to `C:\repos\ai-devops\bin\setup-machine.ps1`.
Its former contents were preserved beside it as `.pre-phase3.bak` for recovery.
Those backups are still sensitive and must not be copied into Git.

Secret-shape inspection on 2026-07-26 found:

- One plaintext `916-alien` private key plus three older script variants with
  private-key blocks under `C:\Dropbox\vibe coding\ssh keys\`.
- Eighteen files in the old MCP setup folder. Sixteen contained secret-shaped
  literals, normally 8 to 12 matches each.
- The affected material included the two active MCP scripts, old variants, a
  desktop config copy, and an Ubuntu setup note.

No value was read into documentation, chat, or Git. Nothing was deleted or
rotated. Secrets remain canonical in 1Password vault `vibe_coding`. The retired
Dropbox copies are recovery evidence only, not a configuration source.
