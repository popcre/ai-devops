---
name: repo-bug-audit
description: Whole-codebase quality audit across one or many repos. Use when the user says "read the entire codebase and tell me if you find any bugs, inefficient code, or poorly written code", or asks for an AI-implementation audit (context/prompt-caching correctness). Spawns one review subagent per repo and writes bugs.md.
---

# repo-bug-audit

Albert periodically asks for a sweep of everything: *"read through all the .md
files in all the repos and read the entire codebase in all the repos and tell me
if you see inefficient code, bugs, poorly written code"*.

## Procedure

1. **Scope.** Enumerate the repos in scope (e.g. the six designflow-* repos, or
   the oracle monorepo packages). Confirm scope in one sentence, then go.
2. **Fan out.** Spawn one review subagent per repo/package, in parallel. Each
   reads that repo's AGENTS.md first, then the code. Dimensions:
   - correctness bugs (with a concrete failure scenario)
   - silent failures and swallowed errors (Albert's #1 pet peeve — every
     fallback must be loud; flag ANY silent fallback as a finding)
   - hard-coded values that must be configurable (models, URLs, credentials)
   - inefficient or duplicated code
   - for AI apps (oracle): prompt/context-caching correctness and token waste
3. **Verify.** Adversarially re-check HIGH findings before reporting — no
   plausible-but-wrong findings.
4. **Write `bugs.md`** in the repo (or one per repo): findings ranked
   HIGH/MED/LOW, each with `file:line`, a plain-English explanation of the
   user-visible impact, and a confidence level. Keep the heavy detail in the
   file, not the chat — Albert explicitly prefers "keep the heavy data in files
   so it doesn't bloat this chat".
5. **Report** a short plain-English summary: counts by severity, the top 3
   issues and what he'd notice as a user, and ask whether to fix now (if yes,
   fix HIGH first, one commit per fix, tests included).
