---
issue: 38
status: OPEN
owner: claude/gemini-qualification-record
---

# Gemini governed qualification record — 2026-08-24

This is the authoritative continuation record for the last remaining piece of
Albert Hazan's "repair every configured reviewer and prove it on a real open
issue" objective. Eight of the nine configured reviewers are finished. Only
Gemini remains, and what remains is a well-defined build, not a diagnosis.

Read this file, then `AGENTS.md`, then `plan_gemini_reviewer_safety_repair.md`.
Do not load the older reviewer handoffs; their workstreams are complete and their
obligations are carried forward here.

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put this whole list to Albert in ONE message before starting. Do not raise items
one at a time.

### Blocking

**None.** Every owner action this workstream needed has been supplied. Albert
funded Z.ai, approved the credential rotation, approved the production ownership
repair, and authenticated Antigravity on both Windows and the Ubuntu server on
2026-08-24. Nothing is waiting on him.

### A wrong guess is recoverable, but confirm before relying on it

1. **Per-machine Gemini qualification.** Recommendation, already reflected in the
   design below: Gemini's qualification record is machine-local state, so Gemini
   becomes available only on a machine where the hostile canary actually passed,
   and stays quarantined everywhere else. Confirm Albert is content that Gemini
   may be available on one machine and quarantined on another rather than being a
   single repository-wide flag. Reversible; the alternative is a global flag,
   which would be less safe.

### Not part of this work, and nobody is on it

2. **Issue #62 is much broader than reviewers.** `plan_full-strategy-remediation.md`
   still has Steps 12, 15, and 16 open: no clean disposable Windows 11 restore
   proof; public Git history still reachable through 41 GitHub-managed
   `refs/pull/*` objects that only GitHub Support can delete; and machines `916`
   (offline) and `edge-dev` (SSH/DCOM denied) are not installed on one release SHA.
   Step 15 needs Albert to open a GitHub Support request — nobody else can.
   Recommendation: treat as a separate workstream and decide whether to start it
   once Gemini closes.

### Already settled — do NOT re-ask

1. **Qwen live testing is skipped while credits are exhausted** (owner decision,
   2026-08-23). Offline proof is complete (`tests/test-ai-qwen.sh` 90/90) and Qwen
   stays truthfully quarantined. Do not spend or request Qwen credits.
2. **Never remove, disable, bypass, replace, or quietly stop using a broken
   reviewer** (standing owner decision). Quarantine is a safety state, not a
   substitute for finishing an implementation.
3. **Work directly on `main` in `u2giants/ai-devops`.** No feature branch, no
   force push, no broad staging.
4. **Do not stop for recoverable command or CI failures.** Correct and continue.
5. **The two exposed MCP tokens are rotated and verified** (2026-08-24). Do not
   rotate again; see §5.6.

## 1. What this application is

`C:\repos\ai-devops` is the Windows checkout of the public `u2giants/ai-devops`
repository — POP Creations' backup-and-restore toolkit for a multi-model AI
development workflow. It holds Bash and PowerShell commands, reviewer wrappers,
shared safety and evidence helpers, configuration templates, skills, installers,
documentation, and offline verification suites. It is not a web application,
container, database, or hosted service.

"Production" for this work means: source of truth on GitHub `main`; a green
exact-head GitHub Actions `verify` run; canonical installation on the Ubuntu host
reached as SSH alias `vps`, login user `ai`, repository `/worksp/ai-devops`;
installed-command and manifest hashes matching GitHub; and reviewer doctors,
quarantines, and real provider calls behaving truthfully.

The nine configured reviewers are defined by `bin/ai-review-preflight:21` and
`bin/ai-review-preflight:230`: Claude, Grok, Kimi, GLM, Muse, Gemini, Qwen,
Codex, DeepSeek.

Albert Hazan is a business owner, not a programmer. Report in plain business
English and ask him to act only when the session genuinely cannot act itself.

## 2. What we set out to do, and why

Albert's persistent objective:

> Repair every configured reviewer so it operates safely and reliably in the
> installed production workflow, then prove each reviewer by invoking it to
> review a real open issue in an authorized repository; complete tests,
> independent exact-head review, commit, push, install, and verification without
> stopping for recoverable failures and without redefining success around a
> smaller subset.

This session inherited that objective from
`HANDOFF.d/2026-08-23T2340Z-edge-dev-codex-reviewer-production-completion.md`
(now retired — see §3.4) and completed every part of it except Gemini.

## 3. Current state — what is true right now

### 3.1 Reviewer status

| Reviewer | Preflight | Real open-issue proof | Notes |
|---|---|---|---|
| Claude | available | #62 `APPROVE` — `/worksp/ai-devops/.ai/reviews/claude-final-check-20260823T233713-772814-16961.md` | complete |
| Grok | available | #62 truthful `REJECT` at `b5155af` — `/worksp/ai-devops/.ai/reviews/grok-issue-62-production-b5155af-20260824T135738Z-2924493.md` | re-proven after this session's repair |
| Kimi | available | #46 — `tests/verification/kimi-review-issue-46/2026-08-23-live.md` | doctor re-verified 2026-08-24 |
| GLM | available | #62 `APPROVE` at `8435f79` — `/worksp/ai-devops/.ai/reviews/glm-glm-issue-62-production-8435f79-20260824T011317Z.md` | Z.ai funded 2026-08-24; dynamic quarantine cleared through the governed path |
| Muse | available | #51 `APPROVE` — `.ai/reviews/muse-issue-51-production-proof-20260822T184546Z-3871140-29679.md` | complete |
| Gemini | **quarantined** | **none — this file's work** | both hostile canaries passed; see §3.2 |
| Qwen | quarantined | owner-waived | offline 90/90; do not test live |
| Codex | available | #13 truthful `REJECT` — `.ai/reviews/codex-final-check-20260822T193613-4044464-27693.md` | also performed this session's five independent reviews |
| DeepSeek | available | #62 truthful `REJECT` at `b5155af` — session `20260824-095701-2922093` | re-proven after this session's repair |

**Do not mistake availability for completion, and do not mistake a truthful
`REJECT` for failure.** A reviewer that returns a correct negative verdict is a
working reviewer.

### 3.2 Gemini specifically

Gemini's implementation is finished and its safety is proven on both platforms.
It is quarantined only because nothing records that fact.

- `bash tests/test-ai-gemini.sh`: 52 passed, 0 failed.
- `ai-gemini qualify-live` passed on Windows `edge-dev`
  (session `qualification-20260824T141942Z-52931`) and on Ubuntu production
  (session `qual-20260824T144252Z-3062625`). Each proved model
  `gemini-3.7-flash-high`, exact conversation ID, exact resume,
  `mutation-request=no-change`, `outside-sentinel=unchanged`, durable reports with
  terminal `APPROVE`, and an unmodified fixture (`git status` empty, no
  `GEMINI-MUST-NOT-WRITE.txt` created).
- Full evidence:
  `tests/verification/reviewer-production-completion/2026-08-24-gemini-tag-limit.md`.
- `agy` 1.1.19 is authenticated on BOTH machines. On Ubuntu it lives at
  `~/.local/bin/agy`, which is NOT on the non-interactive SSH `PATH`;
  `bin/ai-gemini:25` already resolves that path directly, so no PATH change was
  needed or made. When running `agy` by hand over SSH, export the path first.

**Why Gemini still refuses work.** `bin/ai-gemini:8` sets `QUARANTINED=1`
unconditionally, and `bin/ai-gemini:18` `guard_quarantine` makes `new` and `ask`
die. `bin/ai-review-preflight` `static_status` (around line 55) reports Gemini
quarantined with no qualification check at all. Only `qualify_live` bypasses the
gate, by setting `QUARANTINED=0` internally (`bin/ai-gemini:96`). Passing the
canary therefore changes nothing durable. That is correct fail-closed behaviour
and must NOT be "fixed" by deleting the gate.

### 3.3 Git, CI, and production

**Do this first: confirm the landing commit's CI actually passed.** This
handoff's own commit was pushed with only its directly-affected suites confirmed
locally — `tests/test-ai-deepseek-agent.sh` 71/71, `tests/test-ai-gemini.sh`
52/52, and `tests/test-markdown-links.sh` — because three attempts at the full
`tests/test-all.sh` sweep were interrupted by session restarts. The exact-head
GitHub Actions `verify` run is the authoritative gate. Run:

```powershell
gh run list --repo u2giants/ai-devops --limit 5
```

If the run for this handoff's commit failed, fix that BEFORE starting Gemini
work. Reasoning is recorded in
`tests/verification/reviewer-production-completion/2026-08-24-grok-deepseek.md`
section 7.

Also note `origin/main` was red for three commits before this one, because a
concurrent session's `fix_stale_name.md` used a `path.ps1:53` link that
`tools/check-markdown-links.py` cannot resolve. That is repaired in this commit;
see section 8 of the same note. Do not use `:NN` link targets in Markdown.


- `origin/main` at handoff time: `b5155af` plus this session's Gemini commit. The
  Gemini commit SHA is reported in the closing chat message, because a commit
  cannot contain its own hash.
- CI run `32735103765` for `b5155af` passed all three jobs: `linux-offline`,
  `windows-offline`, `windows-reviewer-safety`.
- Ubuntu production `/worksp/ai-devops` is installed at `b5155af`, with
  `ai-devops doctor` reporting installed source SHA matching the repository and
  managed command/skill hashes matching the manifest.
- Git committer identity verified as
  `Albert Hazan <u2giants@users.noreply.github.com>`.

### 3.4 Retired predecessor handoff

`HANDOFF.d/2026-08-23T2340Z-edge-dev-codex-reviewer-production-completion.md` was
deleted in this session's commit under the successor rule. All three conditions
were checked:

1. its commits are present on `origin/main`;
2. every obligation it carried is either completed this session (GLM funding and
   proof, DeepSeek proof, Grok follow-ups, credential rotation verification,
   production installation, stale plan STATUS rows) or carried forward into this
   file (Gemini, issue #62 breadth, the Qwen waiver);
3. its unique dead ends and findings are preserved in §4 and §5 below and in the
   two verification notes committed this session.

## 4. Everything we tried that did NOT work

1. **Treating a passing safety canary as sufficient to use Gemini.** It is not.
   The wrapper's gate is unconditional, so the canary result must be *recorded* in
   a governed, hash-bound way before `new`/`ask` will run. Do not shortcut this by
   editing `QUARANTINED=1` to `0`; that would make Gemini permanently available
   regardless of whether the installed wrapper ever passed anything.

2. **Assuming Windows success proves Linux behaviour.** The first Ubuntu canary
   failed *after* its paid turns because `bin/ai-review-sandbox` `valid_tag` caps a
   tag at 64 characters and Linux PIDs are wider than Windows PIDs. The identical
   review name produced a 63-character tag on Windows and 65 on Ubuntu. Repaired
   this session with a pre-contact `tag_ok` guard and a shorter qualification name.
   The lesson generalises: cross-platform reviewer proof is not optional.

3. **`scp`-ing a wrapper from the Windows checkout to Linux for testing.** The
   working copy is CRLF, so the shebang became `bash\r` and `/usr/bin/env` failed.
   Convert with `tr -d '\r'` for a throwaway test copy, or land the change and
   `git pull` on the server so Git normalises it. Remove any throwaway copy
   afterwards and confirm `git status` is clean.

4. **Running `ai-deepseek-agent --review` and trusting the content.** Before this
   session's repair, DeepSeek reported four present files as absent. It reaches a
   text-only API with no repository access. See §5.4.

5. **Assuming production could pull.** All 3,950 paths under `/worksp/ai-devops`
   were root-owned from the earlier root-install incident, so `git pull` failed
   with `cannot open '.git/FETCH_HEAD': Permission denied`. Albert approved
   `sudo chown -R ai:ai /worksp/ai-devops` on 2026-08-24; it is fixed and must not
   recur. Never run the installer as root.

6. **Waiting on a background review by polling the wrong signal.** Twice this
   session a wait condition matched unrelated output and a verdict was reported
   before it existed. Anchor a wait to the review *report file* being newer than
   the previous one, not to a task output file that earlier `echo`s already filled.

## 5. Root causes and key findings

1. **Gemini's gate has no governed release path, unlike Qwen's.** Qwen already has
   exactly the mechanism Gemini needs: `bin/ai-review-preflight` `qwen_live_qualified`
   (around line 25) reads a qualification file and compares recorded SHA-256 values
   against the live wrapper, runtime, and preloader; `qualify_qwen` (around line
   137) runs the live doctor and writes that file; `qualification_file()` (line 23)
   places it in machine-local state under
   `${AI_REVIEW_QUARANTINE_DIR:-$HOME/.local/state/ai-devops/review-quarantine}`.
   Mirror this shape for Gemini. Copying a working, already-reviewed pattern is far
   safer than inventing a second one.

2. **The qualification must bind to the exact wrapper that passed.** A record that
   merely says "Gemini passed once" would keep Gemini available after the wrapper
   changed. Binding to `sha256sum bin/ai-gemini`, plus the `agy` version and the
   configured model, makes the record lapse automatically on any edit — the same
   property that makes Qwen's record trustworthy.

3. **Machine-local state is the right scope.** The qualification file lives in the
   user's state directory, so qualification is inherently per-machine. That is a
   feature: Gemini becomes available only where it actually passed a hostile
   canary, and no Antigravity install is required on machines that will not use it.

4. **DeepSeek's failure mode was fabricated evidence, not an outage.** It talks to
   a text-only chat API with no repository, filesystem, or tool access, and
   `--review` never said so while binding the verdict to an exact Git HEAD in
   durable metadata. The repair made the evidence boundary the *system* prompt
   (which a caller `--system` cannot override), refused `--system` with `--review`,
   required a continuation to inherit that boundary, made `--file` repeatable, and
   recorded `evidence_scope`, `repository_access: false`, and a NUL-safe accumulated
   `attached_files` list. Recorded as `bugs.md` finding 27.

5. **Independent review earns its cost.** Five exact-head reviews were run on this
   session's changes; four returned `REJECT` on genuine defects, three of them real
   safety holes in the DeepSeek repair, each subtler than the last. Never skip the
   bound-test independent review for reviewer-safety changes, and never treat a
   `REJECT` as an obstacle to route around.

6. **The two exposed MCP credentials are rotated and verified.** The DesignFlow
   DevOps and NAS MCP bearer tokens were rotated 2026-08-23 by the predecessor
   session and recorded in 1Password vault `vibe_coding`, item
   `DesignFlow MCP bearer tokens - DevOps and NAS (production)`. This session
   verified rather than re-rotated: both current tokens authenticate (HTTP 200) and
   an invalid bearer is rejected (403 and 401 respectively), checked through
   protected `op://` injection with no value entering any command, log, or file.
   Nothing further is required.

## 6. Exact next steps

1. **Start from authoritative state, not this file alone.** In
   `C:\repos\ai-devops`:

   ```powershell
   git fetch origin main
   git status --short
   git rev-parse HEAD
   git rev-parse origin/main
   git var GIT_COMMITTER_IDENT
   ```

   Several sessions share this checkout; eleven commits landed here on 2026-08-24
   alone. **You'll know it worked when:** the checkout is clean or every dirty path
   has an identified owner, the local/remote relationship is explicit, and identity
   is Albert's noreply address.

2. **Read the pattern you are copying before writing anything.** Read
   `bin/ai-review-preflight` lines 20–60 and 130–160 (`qualification_file`,
   `qwen_live_qualified`, `qwen_runtime_sha`, `static_status`, `qualify_qwen`, and
   the `qualify` case around line 224), and `bin/ai-gemini` lines 8, 18, 20–25, 85,
   and 89–101. **You'll know it worked when:** you can state exactly which fields
   Qwen's record stores and what makes it lapse.

3. **Add a `gemini` qualification record to `bin/ai-review-preflight`.** Add
   `gemini_live_qualified()` mirroring `qwen_live_qualified`: require the
   qualification file, compare the recorded `wrapper_sha256` against the live
   `bin/ai-gemini`, and also bind the recorded `agy_version` and `model` to what the
   wrapper reports now. Change `static_status` so the `gemini` arm calls it, exactly
   as the `qwen` arm does. Add `qualify_gemini()` that runs `ai-gemini qualify-live`,
   requires a `QUALIFIED` line, extracts the model, and writes the record
   atomically; extend the `qualify` case to accept `gemini`. **You'll know it worked
   when:** `ai-review-preflight status gemini` reports quarantined with no record,
   available after a real qualification, and quarantined again after any byte of
   `bin/ai-gemini` changes.

4. **Release Gemini's own gate the same way.** Replace the unconditional
   `QUARANTINED=1` in `bin/ai-gemini:8` with a check of the same governed record,
   keeping `guard_quarantine` fail-closed when the record is missing, stale, or
   unreadable, and keeping `qualify_live` able to run while quarantined. Do NOT let
   the wrapper write its own record — the record is written by
   `ai-review-preflight qualify gemini`, so an edited or compromised wrapper cannot
   self-authorise. **You'll know it worked when:** `ai-gemini new` refuses before
   qualification and succeeds after, and editing the wrapper makes it refuse again.

5. **Write hostile tests before trusting any of it.** Extend
   `tests/test-ai-gemini.sh` and `tests/test-ai-review-preflight.sh` with: no
   record; a record naming a different wrapper hash; a record with a tampered or
   missing field; a record present but `agy` version or model changed; and a valid
   record allowing a review. Every negative case must fail closed with no provider
   contact. Prove each new test is not vacuous by breaking the guard and observing
   the matching failure. **You'll know it worked when:** both suites are green and
   each new guard has a demonstrated failing mutation.

6. **Run the complete gates.** From `C:\repos\ai-devops`, using Git Bash for Bash
   suites: `bash tests/test-all.sh` and `pwsh -NoProfile -File tests/test-all.ps1`.
   Expect 52 Bash suites and 16 PowerShell suites, 0 failures. **You'll know it
   worked when:** both summaries report zero failures.

7. **Get one independent exact-head review with the tests bound in.**

   ```bash
   AI_CODEX_REVIEW_CALLER=claude bin/ai-codex-review final-check --tests "bash tests/test-ai-gemini.sh && bash tests/test-ai-review-preflight.sh"
   ```

   It takes about ten minutes and re-runs the suites inside its own snapshot.
   Expect rejections; fix and re-run rather than arguing. Anchor any wait to a
   report file in `.ai/reviews/` newer than the previous one. **You'll know it
   worked when:** the newest `.ai/reviews/codex-final-check-*.md` has terminal
   `## Verdict` = `APPROVE`.

8. **Land it.** Verify identity, stage only task-owned files, commit directly to
   `main`, fetch and reconcile any concurrent push without force, push, then wait
   for the newest exact-head CI run to finish — about an hour, Windows being the
   slow job. **You'll know it worked when:** reviewed SHA = `origin/main` = CI SHA
   and all three CI jobs report `success`.

9. **Install on production as `ai`, never root.**

   ```powershell
   $ssh = 'C:\Program Files\Git\usr\bin\ssh.exe'
   & $ssh -l ai vps 'cd /worksp/ai-devops && git pull --ff-only && ./install.sh --skip-secrets'
   & $ssh -l ai vps 'cd /worksp/ai-devops && ai-devops doctor && ai-review-preflight status'
   ```

   **You'll know it worked when:** every required install stage passes, installed
   source SHA equals `origin/main`, and manifest hashes match.

10. **Qualify Gemini through the governed path on each machine that will use it.**
    On Windows, and on Ubuntu after `export PATH="$HOME/.local/bin:$PATH"`, run
    `ai-review-preflight qualify gemini`. **You'll know it worked when:**
    `ai-review-preflight status gemini` reports `available` on that machine without
    any manual edit of state.

11. **Run Gemini's real open-issue review — the actual objective.** Recommended
    issue is #38, Gemini's own tracking issue, which is open. Fetch the body with
    `gh issue view 38 --repo u2giants/ai-devops` into a file and pass it with
    `--prompt-file`. Keep the session name short: the sandbox tag is
    `gemini-<12 hex>-<caller>-<name>` capped at 64 characters, so with caller
    `claude` the name must be at most 37 characters. **You'll know it worked when:**
    a durable report under `.ai/reviews/` proves model `gemini-3.7-flash-high`, the
    exact conversation ID, the exact head, and a terminal `APPROVE`, `REJECT`, or
    `BLOCKED`. A truthful negative verdict counts as success.

12. **Close out.** Update `plan_gemini_reviewer_safety_repair.md` Step 6 and
    `bugs.md` finding 25 with the evidence, add a verification note under
    `tests/verification/reviewer-production-completion/`, comment on and close issue
    #38 with artifacts, and report all nine reviewers to Albert with one citable
    artifact each. Then delete THIS handoff under the successor rule, only once
    every obligation above is proven and issue #62's remaining breadth is recorded
    in `plan_full-strategy-remediation.md`. **You'll know it worked when:** a new
    session cannot mistake a quarantine for a qualification, and every row in the
    nine-reviewer table cites direct evidence.

## 7. Constraints and gotchas in force

- Preserve capability. Never remove, disable, bypass, replace, or quietly stop
  using a reviewer as a shortcut.
- Quarantine is mandatory for an unqualified provider and is not proof it works.
- Do not clear a quarantine by editing state or source flags. Use the governed
  qualification path after the real blocker is resolved.
- Reviewer wrappers, evidence tools, safety tests, and installed routing rules
  require one independent read-only exact-head review with the critical tests bound
  into its packet.
- Work directly on `main`. No feature branch, no force push, no broad staging, no
  destructive reset. Check for concurrent changes before pull, commit, or install.
- Stage only files owned by the current task. Other sessions share this checkout.
- Production installs run as user `ai`, never root. Never live-edit the server.
- `install.sh --skip-secrets` preserves protected configuration; it does not
  authorise secret changes.
- Never print raw process command lines (`Win32_Process.CommandLine`,
  `/proc/*/cmdline`), secret environment variables, or provider payloads. Reviewer
  and MCP credentials have reached process arguments before.
- Do not inspect raw transcript archives; they may contain credentials.
- GPT-5.6 uses only explicit `low` or `medium` reasoning; never high, none, or
  minimal.
- Never add `--dangerously-skip-permissions` to `ai-gemini`, and never mutate
  global Antigravity settings around a run.
- The sandbox tag limit is 64 characters (`bin/ai-review-sandbox` `valid_tag`).
- Windows CI takes about an hour. Inspect terminal state rather than killing it for
  being slow. GitHub cancels older runs when a newer push lands; never count a
  cancelled run as success.
- This handoff is write-once. A successor may delete it only after all carried
  obligations are proven and retained elsewhere.

## 8. Access and environment

### Local Windows workstation

- Hostname `edge-dev`; checkout `C:\repos\ai-devops`.
- PowerShell 7; Git Bash at `C:\Program Files\Git\bin\bash.exe` for Bash suites.
- SSH executable `C:\Program Files\Git\usr\bin\ssh.exe`.
- `gh` authenticated as `u2giants`. Committer identity must remain
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Antigravity `agy` 1.1.19 installed and authenticated.

### Ubuntu production

- SSH alias `vps`, login user `ai`, repository `/worksp/ai-devops`.
- Runtime configuration `/etc/ai-devops/`; installed commands `/usr/local/bin/ai-*`.
- Private reviewer and lifecycle state `/home/ai/.local/state/ai-devops/`.
- Antigravity `agy` 1.1.19 at `~/.local/bin/agy`, authenticated, NOT on the
  non-interactive SSH `PATH` — export it when invoking `agy` directly.
- Ownership was repaired 2026-08-24 with owner approval; all paths are `ai:ai`.

### Credentials and protected state

- Approved 1Password vault: `vibe_coding`. Never put a value in a command,
  report, chat, handoff, or commit; use `op://` references.
- Z.ai/GLM funded 2026-08-24. Qwen credits exhausted and live testing waived.
- The two exposed MCP tokens are rotated and verified; see §5.6.

## 9. Open questions and risks

1. **Gemini's containment is proven; its usefulness is not** (2026-08-24). Both
   canaries prove it cannot write and resumes exactly. Whether its review content
   is worth reading is unknown until step 11. A weak but truthful review still
   satisfies the objective.
2. **Antigravity's CLI contract could change** (ongoing). `agy` is a young tool.
   The wrapper already fails closed on a missing `--sandbox` flag or an unavailable
   model. If it changes, requalify rather than loosening a check.
3. **The qualification record could be forged by anyone with the state directory**
   (2026-08-24). It is machine-local user state, so this is the same trust boundary
   as the user's own account, matching Qwen. Do not widen it, and do not let the
   wrapper write its own record.
4. **A concurrent push could supersede the reviewed head** (ongoing). Eleven
   commits landed on 2026-08-24 from other sessions. Fetch immediately before every
   exact-head review, final CI assessment, and production install.
5. **Issue #62 is broader than reviewers** (2026-08-24). Finishing Gemini does not
   close it; see §0 item 2.
6. **Long sessions degrade** (2026-08-24). This session ran roughly fifteen hours
   and made avoidable errors late — repeated shell-escaping mistakes and two
   premature "review finished" reports. Split steps 7 and 8 across sessions if the
   review loop runs long rather than pushing through.

## Mandatory handoff self-audit

1. **Could a brand-new developer continue without missing a beat? Yes.** §1 defines
   the repository and what production means; §3 gives the exact reviewer table,
   Gemini's precise blocking mechanism with `file:line`, current SHAs, CI, and
   install state; §6 gives ordered commands, each with a proof gate.

2. **Could they continue as effectively as this session? Yes.** §4 preserves the
   six dead ends that cost real time, including the Linux tag overflow, the CRLF
   `scp` trap, and the faulty wait conditions; §5 records the root causes and names
   the exact Qwen functions and line numbers to copy.

3. **Is every execution-critical detail included? Yes.** Background §1–2; state and
   evidence §3; failures §4; findings §5; ordered commands and gates §6;
   constraints §7; access §8; risks §9. Every artifact path, session ID, and command
   is written out rather than described.

4. **Would Albert see every required decision by reading only §0? Yes.** A
   line-by-line sweep of §1–§9 found no blocking owner action outstanding — all four
   he supplied on 2026-08-24 are listed as settled — one recoverable confirmation
   (per-machine qualification, from §3.2 and §5.3), and one out-of-scope item nobody
   is working (issue #62 Steps 12/15/16, from §9.5, whose Step 15 needs a GitHub
   Support request only he can open). All three appear in §0 with recommendations.
