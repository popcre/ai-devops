# HANDOFF — DeepSeek as a read-only Codex model_provider (2026-08-02T1917Z, albt16/claude)

## 1. What this application is

`ai-devops` is Albert's (a non-programmer) cross-machine AI-tooling toolkit,
hosted at `https://github.com/u2giants/ai-devops.git`. It gives Claude Code and
Codex CLI the same shared secrets and shared skills on every machine Albert
uses: three Windows dev boxes (`916`, `t16`/this one — real hostname `albt16`,
user `ahazan2` — and `4837`) plus Ubuntu servers including `hetz` (production
VPS). Secrets live in 1Password (vault `vibe_coding`, service-account token
only) and are resolved at launch via `op run --env-file ~/.config/ai-devops/mcp.env`
(Windows: 15-min DPAPI cache via `mcp-secret-launch.ps1`; Ubuntu: login-shell
export). Skills live in `skills/{claude,codex,shared}/<name>/SKILL.md` and are
installed onto each machine with `bin/ai-install-skills` (run automatically by
`install.sh`/`update.sh`). Read `AGENTS.md` and `CLAUDE.md` for the full
operating rules before doing anything else -- this handoff assumes you have.

## 2. What we set out to do this session, and why

Albert wants Claude (Claude Desktop/Windows via Cowork, and Claude Code CLI on
Ubuntu) and Codex (Windows and Ubuntu CLI) to be able to genuinely talk and
debate back-and-forth with DeepSeek about plans, code, environment questions --
"everything," not a canned diff review.

**Phase 1 is DONE** (this session, prior to this handoff): `bin/ai-deepseek-agent`,
a multi-turn conversational wrapper around DeepSeek's chat API, plus the
`deepseek-second-opinion` skill that gives Claude/Codex a real debate protocol
for using it. See Section 3.

**Phase 2 is NOT started -- this is what you are picking up.** Its own text-only
conversation is a real limitation: DeepSeek only ever sees whatever text/file
content is explicitly pasted to it; it cannot look around a repo on its own the
way Codex or Claude can. Albert and I discussed (in this session's chat, not
captured anywhere else) that Codex CLI supports multiple coexisting
`[model_providers.<id>]` in `config.toml`, selectable per-invocation via
`--profile <name>`, without disturbing the default ChatGPT-backed provider.
The idea: add a `deepseek` model_provider + a `deepseek-review` profile, so
Claude or Codex can run `codex --profile deepseek-review -s read-only "..."`
and let DeepSeek actually drive Codex's own tool-calling loop (read files,
inspect the repo) -- read-only only, since a third model getting to decide
what Codex does is a new, unproven trust surface. Albert was explicit: write
access is a separate, deliberate decision he has not made -- do not build it
without asking him first, even if read-only works well.

## 3. Current state -- what is true right now

**Phase 1 -- DONE, committed, pushed, verified working:**

- `bin/ai-deepseek-agent` (commit `1388cd7`): subcommands `send`/`reply`/`show`/`list`.
  Real multi-turn conversation -- each session's messages are stored as a JSON
  array under `.ai/deepseek-sessions/<id>.json` in the repo you run it from,
  and the full array is resent to DeepSeek's `/chat/completions` endpoint on
  every turn (DeepSeek has no native session-resume, so this recreates the
  effect). Self-resolves `DEEPSEEK_API_KEY` from 1Password if not already in
  the environment (same re-exec-under-`op run` pattern as `bin/ai-glm-agent`).
- `skills/shared/deepseek-second-opinion/SKILL.md` (same commit): the debate
  protocol -- commit to your own position first, brief DeepSeek, report its
  answer, rebut only on real disagreement (max 2 rounds), close with an
  explicit verdict. Modeled directly on `skills/claude/codex-second-opinion`.
- `config/mcp.env.example` has `DEEPSEEK_API_KEY=op://vibe_coding/deepseek API key/credential`
  -- the real key already exists in 1Password under that exact reference.
  **Reuse this reference for Phase 2 too -- do not create a second 1Password item.**
- Both installed via `bin/ai-install-skills` into `~/.claude/skills/` and
  `~/.codex/skills/` **on this machine (albt16) only**. `916`, `4837`, and the
  Ubuntu machines have NOT yet run `./update.sh` to pick Phase 1 up -- that's
  a prerequisite for Albert actually using it everywhere, independent of
  Phase 2.
- An earlier, REJECTED first attempt (`bin/ai-deepseek-review`, a diff-only
  single-shot reviewer mirroring `ai-codex-review`, plus an `ai-deepseek-reviewer`
  skill) was built, tested working, then deleted entirely (not deprecated) in
  commit `1388cd7` after Albert said explicitly he didn't want a diff-only
  reviewer. See Section 4 -- do not resurrect that shape.
- `main` is clean and pushed as of this handoff (`HEAD` = `1388cd7`,
  `git status` clean, `git log` shows nothing local ahead of `origin/main`).

**Phase 2 -- NOT started.** No `[model_providers.deepseek]` or `[profiles.*]`
block exists anywhere yet, on any machine, for this. No skill for it exists.
No testing has been done on whether DeepSeek can actually drive Codex's
tool-calling loop correctly -- this is unverified, not just unbuilt.

## 4. Everything we tried that did NOT work

- **Diff-only reviewer, rejected by Albert.** Built and verified working
  (`bin/ai-deepseek-review`, modes `diff-review`/`security-review`/`final-check`,
  saved output under `.ai/reviews/`). Albert's exact words: "I don't want a
  diff reviewer. I want claude and codex to be able to talk and debate
  back-and-forth with deepseek about plans, code, environment, everything."
  Deleted and replaced with `ai-deepseek-agent` in the same session. Don't
  rebuild a diff-only shape as Phase 2's foundation.
- **Building this via the Cowork remote-device bridge (PowerShell into the
  Windows machine) instead of a native terminal session** worked, but with
  real friction you should know about if you're reading this from a similar
  bridge rather than a native Claude Code/Codex session in this repo:
  - `device_bash` (a Cowork tool distinct from the `Windows-MCP` PowerShell
    tool) runs in an **isolated Linux sandbox VM**, NOT on the real Windows
    machine -- `uv`/`python` found there are NOT what's actually installed
    natively. Everything in this handoff that matters was done through
    `Windows-MCP`'s `PowerShell` tool instead, which does run on the real
    machine. If you have a similar distinction available, don't confuse the two.
  - PATH has **two different `bash.exe`**: one at
    `C:\Users\ahazan2\AppData\Local\Microsoft\WindowsApps\bash.exe` is the
    **WSL launcher** (reports `x86_64-pc-linux-gnu`) and is found FIRST on
    PATH; the real one for this toolkit is
    `C:\Program Files\Git\bin\bash.exe` (Git Bash/MSYS, reports
    `x86_64-pc-cygwin`). Calling a bare `bash` from inside a Git Bash session
    can silently invoke the WSL one and produce baffling
    "executable file not found in %PATH%" errors that look like a script bug
    but aren't. Always invoke Git Bash by its full path; avoid nesting a
    second bare `bash` call inside an already-running Git Bash session.
  - `command -v python3` on this machine **succeeds even though it's a fake**
    -- a Windows "App Execution Alias" stub that, when actually run, prints
    "Python was not found; run without arguments to install..." to stdout and
    produces no real output, instead of erroring loudly. This silently broke
    the first version of `ai-deepseek-agent`'s JSON body (empty request ->
    DeepSeek API 400). Fix applied: verify with
    `command -v python3 && python3 --version >/dev/null 2>&1` (both must
    succeed), not just `command -v`. Real Python on this machine is at
    `C:\Users\ahazan2\AppData\Local\Programs\Python\Python313\python.exe`,
    reachable via the bare `python` command (not `python3`) in Git Bash.
  - Files written directly (not via `git checkout`) don't reliably carry an
    executable bit MSYS bash respects, even after `git update-index --chmod=+x`
    (that only edits git's index, not the actual on-disk/ADS permission MSYS
    reads). Workaround used throughout: `cat file | bash -s -- args` or
    `bash -c "$(cat file)" argv0 args` instead of `./file args`.
  - The `Windows-MCP` `PowerShell` tool itself sometimes refuses to exec a
    relative script path at all (`./bin/whatever`), throwing a Go-style
    `error while starting process: exec: "./bin/whatever": executable file
    not found in %PATH%` regardless of exec bit or invocation style. Not
    root-caused. The pipe-into-`bash -s`/`bash -c` workaround above sidesteps
    it every time it was tried.
  - None of the above are DeepSeek-specific -- they're friction of doing repo
    engineering through a remote bridge instead of a native terminal. This is
    the concrete reason Albert asked for Phase 2 to be built by a session
    working directly in this repo instead of continuing through that bridge.


## 5. Root causes and key findings

- The existing secret-resolution pattern works correctly end-to-end -- verified
  live: `DEEPSEEK_API_KEY` resolves from 1Password (vault `vibe_coding`, item
  "deepseek API key", field `credential`) via `op run --env-file mcp.env`, and
  a real call to `https://api.deepseek.com/chat/completions` returned HTTP 200
  with a correct response from model `deepseek-v4-flash` (DeepSeek's current
  backing model for the `deepseek-chat` alias).
- DeepSeek's API is OpenAI-compatible chat completions:
  `{"model": "...", "messages": [{"role": "...", "content": "..."}], "stream": false}`
  -> response at `choices[0].message.content`. No auth scheme surprises --
  plain `Authorization: Bearer <key>`.
- Per official docs (`https://developers.openai.com/codex/config-advanced`,
  fetched and read this session): Codex CLI's `config.toml` supports multiple
  `[model_providers.<id>]` blocks coexisting with the built-in `openai`
  provider (only the IDs `openai`, `ollama`, `lmstudio` are reserved and can't
  be reused). A provider block's core fields are `name`, `base_url`, `env_key`
  (or `auth.command`), `wire_api`, `http_headers`/`env_http_headers`.
  `[profiles.<name>]` tables select `model` + `model_provider` and are invoked
  with `codex --profile <name>` (or `-c model_provider='"deepseek"' -c model='"deepseek-chat"'`
  for a one-off). Switching providers is purely additive -- it does NOT touch
  or require re-doing the existing ChatGPT auth/config.
- Per `https://github.com/openai/codex/issues/5555` (an open OpenAI issue,
  read this session): Codex CLI refuses to start at all without SOME
  credential present (ChatGPT login OR any API key, even a placeholder garbage
  string like `"ABC"`) -- this is a hard launch gate, unrelated to which
  provider actually serves inference for a given run. Not a blocker here:
  Codex is already logged into ChatGPT on every one of Albert's machines.
- `docs/codex-skills-usage-guide.md` (skill table) and `docs/config-inventory.md`
  were **not updated** to mention `ai-deepseek-agent`/`deepseek-second-opinion`
  from Phase 1. This repo's own stated "maintenance rule" (in
  `codex-skills-usage-guide.md`) says exactly this kind of thing should be
  documented -- it wasn't, due to time in this session. Close this gap as part
  of Phase 2's step 8 below (for BOTH phases' skills, not just Phase 2's new one).

## 6. Exact next steps

1. Read `AGENTS.md` and `CLAUDE.md` (repo's standing rule for any new session)
   if you haven't as part of your own session start.
2. `git status` / `git pull --ff-only` -- confirm you're on `main`, clean, at
   or past `1388cd7`.
3. **Decide and document**: should the Codex provider/profile config become a
   repo-tracked template (consistent with how `config/mcp.env.example` works
   today -- a canonical source that machines copy/merge from) rather than a
   one-off hand-edit of each machine's `~/.codex/config.toml`? Recommend yes,
   for consistency with the rest of this toolkit and so `update.sh` can
   propagate it. Check `bin/setup-machine.ps1` and `bin/setup-secrets.sh` for
   the existing pattern used to write generated `[mcp_servers.*]` blocks
   (e.g. `supabase`, `devops-mcp`) into `config.toml`, and mirror that
   mechanism for `[model_providers.deepseek]`/`[profiles.deepseek-review]`
   instead of inventing a new mechanism.
4. Add the provider + profile. Starting point (verify `wire_api`'s correct
   value against current docs before trusting this -- see Section 9, it was
   not pinned down this session):
   ```toml
   [model_providers.deepseek]
   name = "DeepSeek"
   base_url = "https://api.deepseek.com"
   env_key = "DEEPSEEK_API_KEY"

   [profiles.deepseek-review]
   model = "deepseek-chat"
   model_provider = "deepseek"
   ```
   On Windows, `DEEPSEEK_API_KEY` needs to actually be in the process
   environment when Codex launches for `env_key` to find it -- Codex Desktop's
   MSIX sandbox does NOT read arbitrary env the way a normal process does (see
   `docs/onboarding-secrets.md`); you likely need the same `op run`-based
   launcher trick already used for MCP servers (`mcp-launch.cmd`) rather than
   assuming a plain env var will be visible. Confirm this by testing, don't
   assume either way.
   You'll know step 4 worked when: `codex --profile deepseek-review -s read-only "list the files in this repo"`
   (run inside any git repo) returns a REAL, correct file listing you can
   verify against `git ls-files` yourself -- not an error, not a hallucination.
5. Keep every test and every documented usage pattern **read-only**
   (`-s read-only`, or hard-code `sandbox_mode = "read-only"` in the profile).
   This is a new, unproven trust surface -- a third model deciding what
   commands Codex runs -- and Albert was explicit in this session's chat that
   write access is a separate decision he hasn't made. Do not build or
   document a write-enabled path without asking him first, even if read-only
   works cleanly.
6. Test against a REAL repo change: make a small edit, run something like
   `codex --profile deepseek-review -s read-only "review the current git diff for correctness and security issues"`,
   and confirm (a) no error, (b) the review is grounded in the actual diff
   (spot-check it against the real diff yourself, don't take DeepSeek's word
   for it), (c) it made no write/edit attempt.
7. If 4-6 genuinely work: write a new shared skill (e.g.
   `skills/shared/deepseek-codex-review`, or extend `deepseek-second-opinion`
   with a section on this transport -- your call) documenting the exact
   invocation, the read-only guarantee, and when to prefer this over the
   text-only `ai-deepseek-agent` (this: when DeepSeek needs to inspect the
   repo itself; that: when you already have the material in hand to paste).
8. Update `docs/codex-skills-usage-guide.md`'s skill table and
   `docs/config-inventory.md` for BOTH the Phase 1 skills (`ai-deepseek-agent`
   / `deepseek-second-opinion`, never documented there) and whatever you add
   in step 7.
9. Commit and push (`git pull --rebase` first if `origin/main` has moved,
   exactly like the flow that produced `1388cd7`/`a7adaaa`).
10. Redeploy locally with `./bin/ai-install-skills`, verify with one more real
    invocation, then write your OWN `HANDOFF.d/` file per
    `templates/system/handoff-standard.md` and DELETE this file
    (`HANDOFF.d/2026-08-02T1917Z-albt16-claude-deepseek-codex-provider.md`)
    since its work will then be done. If you stop partway through, do NOT
    delete this file -- leave it in place and add your own file alongside it
    describing exactly what's still open (presence = open, per the standard).


## 7. Constraints and gotchas in force

- Albert's standing rule (2026-07-16, referenced in `bin/ai-codex-review`):
  Codex reasoning effort must be `low` or `medium`, **never** `high`/`none`.
  Pass `-c model_reasoning_effort=...` explicitly on any plain-Codex/ChatGPT
  invocation. Whether this rule has any equivalent for a `deepseek-chat`/
  `deepseek-reasoner` provider is unconfirmed -- there's no obvious matching
  knob; check DeepSeek's current docs rather than assuming the flag does
  anything meaningful for a non-OpenAI provider.
- Never write a secret VALUE into `config.toml`, a skill file, or this repo --
  only `op://` references. Reuse `op://vibe_coding/deepseek API key/credential`
  (already in `config/mcp.env.example`) -- do not create a duplicate 1Password item.
- Windows Codex config lives at `%USERPROFILE%\.codex\config.toml`
  (`C:\Users\ahazan2\.codex\config.toml` on this machine) and already contains
  several `[mcp_servers.*]` blocks with real, PLAINTEXT bearer tokens
  (`trigger`, `synology-monitor`, `devops-mcp`, `recall-ai`). Do not disturb
  those, and do not "clean them up" as a drive-by -- that's separate,
  unrequested work.
- `bash` on the Windows dev machines resolves to WSL by default on PATH (see
  Section 4) -- use Git Bash's full path for anything touching the real
  Windows filesystem/repo.
- Don't hardcode Codex's Windows binary path
  (`...\Programs\OpenAI\Codex\bin`) if you go looking at its install layout
  for any reason -- it's a junction that breaks the sandbox helper; see the
  incident note in `AGENTS.md`.
- Read-only-until-Albert-says-otherwise is a direct instruction from this
  session's chat, not a suggestion -- do not skip to a write-enabled profile
  "to save a step."

## 8. Access and environment

- 1Password: vault `vibe_coding` only, via a scoped service-account token
  (never personal login). Token file `~/.config/ai-devops/op-service-account`
  (600 perms) on every machine. DeepSeek key: item "deepseek API key", field
  `credential`.
- `DEEPSEEK_API_KEY`'s reference is committed in `config/mcp.env.example` and
  already synced into `~/.config/ai-devops/mcp.env` **on this machine
  (albt16) only**. `916`, `4837`, and Ubuntu machines pick it up on their next
  `./update.sh` -- that's a prerequisite for Albert using Phase 1 everywhere,
  separate from Phase 2's work.
- GitHub: `https://github.com/u2giants/ai-devops.git`, branch `main`. Git
  identity auto-pins via `bin/ai-git-identity` (runs inside `ai-install-skills`)
  -- don't hand-set `user.name`/`user.email`.
- Codex CLI on this machine: `codex-cli 0.145.0`, already logged in with
  ChatGPT; existing `config.toml` already has plugins/marketplaces/multiple
  `[mcp_servers.*]` configured and working. No Codex login needed.
- **This handoff was written by a Cowork session** (Claude, via the
  remote-device bridge into this Windows machine -- NOT a native terminal
  Claude Code session). If you're reading this as a native Claude Code or
  Codex session started directly in this repo, you have better tools than
  that bridge did (real bash, no WSL/Git-Bash PATH ambiguity, no fake-`python3`
  trap) -- the friction in Section 4 is bridge-specific; you shouldn't expect
  to hit most of it, but the DeepSeek-specific findings in Section 5 still
  apply to you.

## 9. Open questions and risks

- **Unconfirmed:** the correct `wire_api` value (if any) for a DeepSeek
  `model_provider` block -- `"chat"`, `"responses"`, or omitted entirely. This
  session found the field exists (via `developers.openai.com/codex/config-advanced`)
  but did not pin down DeepSeek's correct value. Verify against current docs,
  or by trial, before trusting the snippet in Section 6 step 4 as-is.
- **Genuinely uncertain, the real risk of this whole phase:** will DeepSeek's
  tool-calling output actually match the shape Codex's harness expects well
  enough to drive real, correct read-only file inspection -- or will it
  hallucinate file contents, mis-call tools, or otherwise misbehave? This is
  UNTESTED. Step 6 (a real, grounded test you personally verify) is mandatory
  before calling Phase 2 done -- do not conclude it works just because the
  config loads without a parse error.
- **Fallback if Phase 2 proves unreliable:** keep DeepSeek text-only via the
  already-working `ai-deepseek-agent`/`deepseek-second-opinion`
  (`--file path/to/thing` to hand it content) rather than forcing the
  Codex-provider integration. Report the finding to Albert either way -- a
  clean "this doesn't work well enough, here's why" is a legitimate outcome,
  not a failure to hide.
- **Open decision, not yet made** (Section 6 step 3): repo-tracked config
  template vs. manual per-machine edit for the Codex provider/profile block.
  Whichever you pick, document the choice and the reasoning in your own
  `HANDOFF.d/` file.
- Albert has NOT asked for DeepSeek to ever get write access via this path.
  Don't build toward it speculatively even if read-only works perfectly --
  that's his call to make separately.

---

## Self-audit (per `templates/system/handoff-standard.md`)

1. **Could a street-newcomer pick up and continue without asking a single
   question?** Yes -- Sections 1-2 give the app and the goal from zero
   context, Section 3 gives exact current state with commit hashes, Section 6
   gives numbered, executable steps with verification gates, Section 8 gives
   every credential location needed (by reference, never value).
2. **As effectively as I can right now?** Yes -- Sections 4-5 carry forward
   every non-obvious thing learned this session (the WSL/Git-Bash bash.exe
   trap, the fake python3 stub, the exec-bit quirk, the Codex provider
   research findings, the issue #5555 finding) that would otherwise be
   re-discovered the hard way.
3. **Did I include what failed, not just the final plan?** Yes -- Section 4,
   both the rejected diff-only reviewer and the five bridge-specific gotchas.
4. **Is every next step concrete with a verification gate?** Yes -- Section 6
   steps 1-10, each with a "you'll know it worked when ___" or an explicit
   deliverable (a file, a commit, a passing test).
5. **Is every term/identifier/path/URL defined?** Yes -- machine nicknames,
   file paths, the 1Password reference, the exact API shapes, and doc URLs
   are all given in full rather than referenced obliquely.

**Final synthesis:**

1. Comprehensive enough for a zero-context developer to continue without
   skipping a beat? **Yes** -- see Sections 1-3, 6.
2. Detailed enough to continue as well as I could right now? **Yes** --
   Sections 4-5 carry forward everything non-obvious learned this session.
3. Is every relevant detail present -- background, goals, current state,
   failed attempts, decisions, constraints, risks, exact next actions,
   verification evidence? **Yes** -- all 9 sections are filled (none are
   N/A), with the two explicitly open/unconfirmed items called out honestly
   in Section 9 rather than glossed over.

Self-audit passed.
