# HANDOFF — GLM and delegate-agent audit (2026-08-05T1139Z, 916/codex)

## 1. What this application is

`u2giants/ai-devops` is Albert Hazan's Git-backed toolkit for restoring a consistent
multi-model coding workflow on Windows development computers and the Hetz Ubuntu VPS.
It distributes Bash/PowerShell helpers, configuration templates, standing instructions,
and shared skills to Claude and Codex. It is not a hosted application. The relevant
integrations are GLM through the local OpenCode-backed `ai-glm` command, Kimi Code through
`kimi`, and xAI Grok Build through `grok`. The canonical GitHub branch is `main`.

## 2. What we set out to do this session, and why

Albert requested a pull of the latest repository followed by an audit of GLM, Kimi, and
Grok installations and skills, specifically for prompt/context caching and continuous
Claude/Codex troubleshooting or plan debates. The session also corrected stale GLM
documentation discovered during that audit and then closed out the work safely.

## 3. Current state — what is true right now

- Local repo `D:\repos\ai-devops` is on `main`, based on pulled commit
  `78e60b6e02def02dd483d0901e8e54ccda908a96`. This handoff and the two files below are
  uncommitted at the time of writing.
- Corrected stale GLM wording in `docs/glm-opencode.md`: Windows runs a local
  loopback OpenCode service (not SSH to Ubuntu), and only review sessions lack Bash;
  implementation sessions run Bash inside a disposable remote-less clone.
- Corrected the same clone-versus-worktree wording in
  `config/opencode/agent/glm-implement.md`. The real harness in `bin/ai-glm` already
  used a clone with `origin` removed; the source definition and docs were the stale parts.
- On 916, `ai-glm doctor` passed every required runtime check. GLM has named persistent
  OpenCode sessions and records `cache.read` in each report. Its session key includes
  repo, caller, and name; see `bin/ai-glm:30,108-109`.
- 916's installed `ask-glm` skills under both `%USERPROFILE%\.claude\skills` and
  `%USERPROFILE%\.codex\skills` do NOT yet match the source skill after the pull.
  Run `& "C:\Program Files\Git\bin\bash.exe" "D:\repos\ai-devops\bin\ai-install-skills"`
  after the commit/push to refresh them. Do not need the broader dotfiles sync merely
  for this refresh.
- Kimi is installed/authenticated on 916 as version `0.32.0`, with
  `default_model = "kimi-code/k3"`, high thinking, and a 1,048,576-token K3 context.
  Its shared skill is stale: it claims K2.7 is the default, calls K3-256k the larger
  context, and instructs `-r <id>` although this version's help documents `-S` /
  `--session [id]`. No repair was implemented.
- Grok was installed during the audit on 916 and verified by absolute executable path:
  version `0.2.118`, authenticated with grok.com, and `grok-4.5` is its sole/default
  model. Its user PATH entry exists, but a Codex or terminal process started before the
  installation needs restarting to resolve bare `grok`. `grok doctor` reported zero
  issues and one terminal newline recommendation. It emitted a non-fatal auto-worktree
  cleanup warning because this process did not expose `HOME`/`GROK_HOME`.
- Hetz (`ssh vps`, repo `/worksp/ai-devops`) is clean on `main`, but its GLM runtime is
  absent: `ai-glm doctor` reported 17 failures (no launcher/config/agents/password/
  secret wiring/systemd service/health endpoint). `kimi` and `grok` are not installed.
- t16 and 4837 were not checked: 916's SSH config has no aliases/addresses for them.

## 4. Everything we tried that did NOT work

1. Testing `kimi -r` without a real session ID did not validate the skill's resume
   recipe. On Kimi 0.32.0 it opened the interactive session picker instead of proving a
   deterministic named resume. Current `kimi --help` documents `-S` / `--session`, not
   `-r`; the skill must be re-qualified before use.
2. `grok` was initially unavailable from this already-running PowerShell/Codex process
   even after installation. The executable and user PATH entry existed at
   `%USERPROFILE%\.grok\bin\grok.exe`; the process had inherited its old PATH. Invoking
   the absolute path verified the install. Restarting the parent process is the correct
   fix, not changing system PATH or reinstalling Grok.
3. `bash tests/test-ai-glm.sh` on 916 produced 91 passes and two failures:
   `doctor resolves through a symlink` and `doctor reports every check on a bare machine`.
   The documentation-only edits did not touch test behavior. Do not call the suite green
   until those Windows failures are independently reproduced and fixed or proven to be
   a test-environment assumption.

## 5. Root causes and key findings

- GLM is the only audited integration with a durable named-session wrapper and measured
  cache use. `skills/shared/ask-glm/SKILL.md:39-65` directs callers to reuse a session,
  while `bin/ai-glm:108-109` separates caller namespaces. This prevents accidental
  collisions but prevents Claude and Codex from sharing one warm GLM debate by default.
- Do not solve that with semantic/topic inference. If Albert wants joint debates, add an
  explicit opt-in shared workstream name (for example `token-rotation-debate`) mapped to
  one session under the repo identity, with caller attribution and the existing per-name
  lock. Keep separate caller sessions as the safe default.
- Kimi's model facts in `skills/shared/kimi-code-delegation/SKILL.md:46-48` conflict with
  916's live `%USERPROFILE%\.kimi-code\config.toml`. Its raw session-ID-only procedure
  also provides no durable registry across independent Claude/Codex tool turns.
- Grok's skill has a sound cache pattern—capture an exact session ID, use `--resume`, and
  keep the model/permissions/prefix stable—but it has no named registry either. It also
  both hard-codes `grok-4.5` in recipes and says not to hard-code models; discovery once
  per workstream then pinning that result is the consistent rule.
- The GLM source docs contained an old migration block contradicting current code. The
  corrected facts are now aligned with `config/opencode/agent/glm-review.md`,
  `config/opencode/agent/glm-implement.md`, and `bin/ai-glm`.

## 6. Exact next steps

1. Review, stage only this handoff plus `docs/glm-opencode.md` and
   `config/opencode/agent/glm-implement.md`, commit on `main`, and push to `origin/main`.
   You will know it worked when `git status --short --branch` is clean and HEAD equals
   `origin/main` after push.
2. On 916, run `& "C:\Program Files\Git\bin\bash.exe"
   "D:\repos\ai-devops\bin\ai-install-skills"`, then compare source and installed
   `ask-glm/SKILL.md` hashes for both Claude and Codex. You will know it worked when both
   hashes match the source hash.
3. Repair/re-qualify Kimi 0.32.0 before relying on the Kimi skill: run its current help,
   confirm a harmless non-interactive session captures an ID, and determine whether
   `-S <id>` resumes it. Update all stale model/context/resume claims and add a regression
   test. You will know it worked when a second turn demonstrably recalls a first-turn
   codeword in the exact captured session, without using `--continue`.
4. Run `bin/setup-opencode-glm.sh` on Hetz only after confirming it is intended to set up
   GLM there, then run `ai-glm doctor` and a harmless named review. You will know it
   worked when doctor has no failures and the review report contains the pinned
   `zai-coding-plan/glm-5.2` model plus cache metrics. Install Kimi/Grok on Hetz only if
   Albert explicitly wants those local agents there.
5. Obtain direct SSH access/aliases for t16 and 4837, then run the same read-only
   inventory (`ai-glm doctor`, `kimi --version; kimi provider list`, `grok --version;
   grok doctor; grok models`) before claiming fleet parity. You will know it worked when
   a result is recorded for every machine, including explicit absence.
6. If cross-parent debate becomes a frequent workflow, write an implementation plan for
   an opt-in named-session broker. It must map only explicit `(repo, workstream,
   provider, model)` identities to native session IDs, store no prompt/source/secret
   contents, label each turn with its caller, and lock each workstream. You will know it
   worked when Claude and Codex can both resume the same explicitly named GLM review and
   the report shows cache reads rather than a fresh GLM session.

## 7. Constraints and gotchas in force

- This is a `u2giants` repository: work on `main`; preserve concurrent work and do not
  create branches by default.
- Never place keys, passwords, auth files, or resolved `op://` values in Git, reports,
  prompts, or handoffs. Secrets belong only in 1Password vault `vibe_coding`.
- GLM review safety depends on the agent `tools:` map, not OpenCode permission maps.
  `glm-review` must retain `bash/write/edit/patch: false`. GLM implementation must remain
  a clone with its remote removed, not a Git worktree.
- Do not make automatic semantic matching of Claude/Codex topics; it risks joining
  unrelated conversations and leaking context. Shared discussions must be named
  deliberately.
- Do not use Kimi `--continue` for a shared repo: it chooses the newest session and can
  silently select another agent's work.
- Grok on Windows does not have documented OS-level sandbox enforcement; retain explicit
  deny rules for reviews and use an isolated worktree only for explicitly authorized
  implementation.

## 8. Access and environment

- 916 is Windows (`916-ALIEN`), repo `D:\repos\ai-devops`, user `ahazan2`.
- GitHub remote is `https://github.com/u2giants/ai-devops.git`; current branch is `main`.
- 916 has authenticated `gh`, Codex, Claude, Kimi, Grok, 1Password, and a healthy local
  GLM/OpenCode Scheduled Task (`AiDevOps-OpenCodeGlm`).
- Hetz is reachable read-only from 916 with `C:\Program Files\Git\usr\bin\ssh.exe vps`.
  Its ai-devops checkout is `/worksp/ai-devops`; it lacks configured GLM/Kimi/Grok
  runtimes as described above.
- 1Password references are managed through vault `vibe_coding`; no secret values were
  read or recorded during this session.
- Grok state, credentials, docs, sessions, and logs are local to `%USERPROFILE%\.grok`.
  Do not read or print `%USERPROFILE%\.grok\auth.json`.

## 9. Open questions and risks

- The exact Kimi 0.32.0 headless resume syntax and stream event shape need a harmless
  live confirmation before changing the skill. The current `-r` recipe is not
  trustworthy.
- Fleet status is incomplete until t16 and 4837 are directly inspected. Hetz is known
  not to have a working GLM runtime despite having an `ai-glm` command on PATH.
- A shared-session broker improves cache use only within the same provider. It cannot
  make GLM, Kimi, and Grok share one native context. The parent agent must still relay
  relevant conclusions between providers.
- The two failing Windows GLM test checks may indicate a real test/harness regression;
  no conclusion was drawn because the edited files are documentation and agent prose,
  not the test or harness code.

## Self-audit

1. **Could a street-new developer continue without questions? Yes.** Sections 1-3 name
   the toolkit, local/remote state, exact uncommitted files, and verified commands;
   sections 6 and 8 provide runnable next actions and available access.
2. **Could they continue as effectively as this session? Yes.** Sections 4-5 preserve
   the failed Kimi/Grok/test attempts and the non-obvious session-key, cache, and
   clone-versus-worktree findings; section 7 records the safety boundaries.
3. **Are all relevant details present for flawless execution? Yes.** Sections 2-9 cover
   the trigger, evidence, unresolved fleet state, explicit verification gates, secrets
   boundary, and risks. No gap was found in this final audit.
