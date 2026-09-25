---
issue: 758
status: OPEN
owner: mimo/client-integration
agent: mimo (MiMo Desktop / MiMoCode)
machine: edge-dev
---

# HANDOFF — 2026-09-23T1856Z — edge-dev — mimo — mimo-client-integration

## 0. Decisions only the owner can make

**None — nothing in this workstream needs the owner.** Live install proof is delegated to a successor session under issue #758 (already authorized by Albert's original request to bring MiMo fully into ai-devops).

Already settled — do NOT re-ask:

- 2026-09-23 — MiMo is an interactive client only (no formal reviewer), same as ZCode.
- 2026-09-23 — No completion-check hook for MiMo (no hook surface exists).
- 2026-09-23 — Skills write root is `~/.config/mimocode/skills/` only.
- 2026-09-23 — MCP membership starts at `1password` only.

## 1. What this application is

`popcre/ai-devops` is Albert's public restore-from-zero toolkit for a multi-model AI coding workflow (Claude Code, Codex, ZCode, and now Xiaomi MiMo). Installation is its deployment mechanism. Local canonical checkout: `C:\repos\ai-devops` (landing-only). GitHub is the source of truth.

## 2. What we set out to do this session, and why

Albert asked to **bring Xiaomi MiMo fully into the ai-devops system** — the same managed treatment Claude, Codex, and ZCode receive (presence, wrapper, skills, globals, MCP, doctor, transcripts, docs, tests). Plan: [`../plan_mimo-windows-support.md`](../plan_mimo-windows-support.md) (read its STATUS table first).

## 3. Current state — what is true right now

**Landed on `origin/main`.** PR [#721](https://github.com/popcre/ai-devops/pull/721) merged as `40c07315` at 2026-09-24 12:14 AM EST. Offline CI was fully green (linux shards 1–4, windows sections 1–6 including blacksmith, reviewer-safety, verification-closure).

Delivered and on main:

- `bin/ai-mimo` + `bin/ai-mimo.cmd` — governed headless wrapper (ask/doctor/version; yolo refused; `local_dependency_unavailable` when CLI missing).
- `bin/configure-mimocode-mcps.ps1` — MCP writer for `~/.config/mimocode/mimocode.jsonc` (array `command`, `timeout` ms).
- `skills/mimo/mimo-transcript-backup/` + installer path to `~/.config/mimocode/skills/`.
- `templates/system/AGENTS-global-mimo.md` + `ai-adopt-globals` target.
- Presence checks, `ai-devops doctor` MiMo section, BlockerWatch `mimo` keys, docs, offline tests (wrapper 14/14, MCP writer 23/23).

**Not done:** live installed-state proof on edge-dev against the merged commit — issue **#758** (OPEN).

Later sessions continued MiMo work on main after this merge (see git log `--grep=mimo`). Do not redo this landing.

## 4. Everything we tried that did NOT work

- **`sed 's|//.*||g'` to strip JSONC comments before `jq`** — ate `https://` inside the `$schema` string and false-failed a valid config. Fixed: parse with plain `jq` (writer emits pure JSON).
- **Em-dashes / ellipses in `bin/` scripts** — failed the non-ASCII gate in linux-offline-shard. Fixed: ASCII-only in `bin/`.
- **Handoff plan link `../../plan_...`** — escaped the repo root; `test-markdown-links.sh` failed. Fixed: `../plan_...`.
- **Ungated MiMo skills install** — created `~/.config/mimocode` on machines without MiMo. Test asserted this must not happen. Fixed: gate on `Test-Path $MimoHome` (same as globals).
- **Merge queue ejected twice** — (1) Muse flake in `test-ai-muse-code.sh` (fixed later on main); (2) `merge-group-evidence` raced a still-queued PR verify run. Requeue only after the PR's verify run is COMPLETED.
- **Conflicts with main** (three times) — main landed MiMo globals (#717) and later slimmed them (#739) and retired Muse handoffs (#749/#752). Resolved by taking main's globals + re-appending MiMo traps; main's dead-link fix unblocked markdown-links.

## 5. Root causes and key findings

- MiMo MCP `command` is an **array** of argv strings; timeout key is `timeout` (ms) — not ZCode's string command / `timeoutMs`.
- Skills write authority is only `~/.config/mimocode/skills/` (and project `.mimocode/skills/`). `~/.agents/skills` is read-only compat.
- No hooks surface (permissions cannot be modified by custom tools/hooks). No `ai-install-completion-check-hook --client mimo`.
- Standalone `mimo` CLI is **absent** on edge-dev; Desktop is present (ver 26.924.65535.0). Headless `ai-mimo ask` needs the CLI.
- `windows-json-file.ps1` does not preserve `//` comments. Writer emits pure JSON.
- Merge queue requires the PR head's verify run to be **finished** before `merge-group-evidence` accepts it.

## 6. Exact next steps

1. From a current-upstream checkout of `origin/main` (or any commit that contains `40c07315`), run `bin/install-ai-devops-windows.ps1` on edge-dev.
2. Run `bin/setup-machine.ps1` (MCP + presence notes).
3. Run `ai-mimo doctor` — expect desktop present, config parses, 1password MCP, managed skills markers, globals present.
4. Confirm `~/.config/mimocode/mimocode.jsonc` still token-free via `mcp-launch.cmd`; `~/.config/mimocode/skills/` has `.ai-devops-managed` markers including `mimo-transcript-backup`.
5. Record commands + outputs on issue **#758**, then close it.

You'll know it worked when `ai-mimo doctor` prints `all checks green` and #758 is closed with that evidence.

## 7. Constraints and gotchas in force

- Worktree for write-capable work; canonical `C:\repos\ai-devops` is landing-only.
- Never push directly to protected `main`; merge queue only.
- Never write MiMo skills into `~/.agents/skills`.
- Never pass `--yolo` / `--dangerously-skip-permissions` from caller input into `mimo run`.
- Never start `Xiaomi MiMo AI.exe` as a headless fallback.
- No MiMo reviewer (plan D1). No completion-check hook (D6).
- `bin/` scripts must stay ASCII-only.
- One unproven outcome per session; #758 is the single leftover-proof issue.

## 8. Access and environment

- Machine: edge-dev (Windows 11). Git Bash: `C:\Program Files\Git\bin\bash.exe` (not WSL bash).
- GitHub via `bin/ai-gh`. 1Password vault `vibe_coding` — never print values.
- MiMo Desktop: `C:\Program Files\Xiaomi MiMo AI\`. Config: `~/.config/mimocode/mimocode.jsonc`. Data: `~/.local/share/mimocode/`.
- Worktree used for the landing: `C:\repos\ai-devops-wt-mimo` (branch `sandbox-mimo-client-integration`, PR #721 merged).

## 9. Open questions and risks

- D10 OPEN: exact `mimo run` flag set unqualified until the standalone CLI is installed. Wrapper fail-closes on unknown flags.
- D11 OPEN: BlockerWatch resume argv for `mimo` is best-effort; re-qualify on first live wake.
- Live install proof (#758) is the only unfinished outcome of this workstream.

---

## Self-audit

1. **Street-newcomer can continue?** Yes — §2 goal, §3 landed state + exact commit, §4 dead ends, §6 numbered next steps with gates, §8 environment.
2. **As effective as this session?** Yes — §4 and §5 carry every costly discovery (ASCII gate, link escape, MimoHome gate, merge-queue race, JSONC parser trap).
3. **Every relevant detail?** Yes — §3 commit/PR evidence, §4 failures with fixes, §7 constraints, §9 remaining OPENs.
4. **Section 0 complete?** Yes — sweep found no owner decisions left; already-settled rulings listed so they are not re-asked.
