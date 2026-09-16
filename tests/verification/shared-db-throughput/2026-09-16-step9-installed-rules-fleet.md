# Step 9 — installed operating rules vs canonical main (fleet proof)

Issue: popcre/ai-devops#496 (programme #401, Step 9). Date: 2026-09-16.
Canonical source: `popcre/ai-devops` main at `ece11e45`.

## Method

- **What is compared.** The global instruction bodies (`~/.claude/CLAUDE.md`
  against `templates/system/CLAUDE-global.md`, `~/.codex/AGENTS.md` against
  `templates/system/AGENTS-global-codex.md`) with the machine section removed,
  using the same section detection, trailing-rule trim and CRLF normalisation
  as `bin/ai-adopt-globals`. Also every repo-managed skill file
  (`skills/claude` + `skills/shared` into `~/.claude/skills`, `skills/codex` +
  `skills/shared` into `~/.codex/skills`: 92 and 98 files) by SHA-256 after CRLF
  normalisation. Skills that the repo does not manage were ignored.
- **How.** Installed files were copied read-only over SSH (`tar`) into a local
  scratch folder and compared there, so one comparator judged every machine.
  Machine sections and memory were not read into this report. No secrets were
  printed.
- **Repair route.** Only the supported sync route: fast-forward the machine's
  own clean `ai-devops` checkout to main, then `bin/ai-adopt-globals` (which
  backs up, refreshes both skill trees and proves the body and machine
  section). On hetz, `install.sh` ran first because the doctor inside the skill
  installer refused missing new `/usr/local/bin` links. Nothing in Codex or
  Claude config outside the globals and skills was changed by hand. No
  production app, database or GitHub setting was touched.
- **Proof after repair.** Installed files were fetched again and the
  independent comparator re-run.

Canonical short hashes: Claude body `8b7a6d5b2e34`, Codex body `e08911fd4e39`.

## Per-machine result

| Machine | Reachable | Before | Repaired | After |
|---|---|---|---|---|
| edge-dev (this machine) | yes | DRIFT: both bodies differed (carried text from unmerged PR #486 and lacked newer main text); 1 skill file behind in each tree | yes — shared checkout fast-forwarded to `ece11e45`, `ai-adopt-globals` rc 0 | MATCH both bodies; 92/92 and 98/98 skill files equal |
| al8960ofc (`4837`) | yes | DRIFT: both bodies; 23 skill files in each tree (checkout 162 commits behind) | yes — `C:\repos\ai-devops` fast-forwarded, `ai-adopt-globals` rc 0 | MATCH both bodies; 0 skill files differ |
| 916 | yes | DRIFT: both bodies; 41 Claude / 37 Codex skill files (checkout 378 commits behind) | yes — `D:\repos\ai-devops` fast-forwarded, `ai-adopt-globals` rc 0 | MATCH both bodies; 0 skill files differ |
| hetz user `ai` | yes | DRIFT: both bodies; 19 skill files in each tree | yes — `/worksp/ai-devops` moved detached to `ece11e45` (clean), `install.sh` rc 0, `ai-adopt-globals` as `ai` rc 0 | MATCH both bodies; 0 skill files differ |
| hetz user `root` | yes | DRIFT: both bodies; 38 Claude / 34 Codex skill files | yes — `ai-adopt-globals` as root rc 0 | MATCH both bodies; 0 skill files differ |
| EDGE-RUNN-ENVY | yes (SSH as `ahazan`) | no installed Claude or Codex home at all (`File Not Found` for `.claude` and `.codex`) | no | NOT APPLICABLE (owner ruling 2026-09-16: CI runner, no Claude or Codex) |
| EDGE-ALIEN | NO (irrelevant) | not measured | no | NOT APPLICABLE (owner ruling 2026-09-16: CI runner / popdam processor, no Claude or Codex) |
| t16 | NO — Tailscale online but SSH refused (re-tried 2026-09-16 after owner update) | not measured | no | NOT PROVEN |

Unreachable evidence (verbatim):

- EDGE-ALIEN: `ssh: connect to host <tailscale-ip> port 22: Connection timed out`
  (Tailscale itself answers: `pong from edge-alien (<tailscale-ip>) via <lan-ip> in 2ms`, so the SSH service is not accepting connections).
- t16 (first attempt): `offline, last seen 4d ago` in `tailscale status`.
- t16 (retry after it came online, key `916-alien`, users `ahazan2` and `ahazan`): `ssh: connect to host <tailscale-ip> port 22: Connection timed out`, while `pong from t16 (<tailscale-ip>) via <private-ip>:41641 in 11ms`. The SSH service on t16 is not accepting connections; there is no SSH alias for it either.

## Verdict

Step 9 is **not accepted**. Every in-scope machine except t16 (edge-dev,
al8960ofc, 916, hetz `ai`, hetz `root`) equals canonical main. EDGE-ALIEN and
EDGE-RUNN-ENVY are out of scope. t16 remains unmeasured: its SSH service does
not accept connections.

Side effect to note: edge-dev had been carrying the unmerged PR #486 rule text
in its installed globals. Adoption replaced it with main; it returns when #486
merges and the machine syncs.
