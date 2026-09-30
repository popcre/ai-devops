# How one plumbing covers native harnesses and OpenCode

**Parent issue:** [#1110](https://github.com/popcre/ai-devops/issues/1110) · **Child:** [#1114](https://github.com/popcre/ai-devops/issues/1114)  
**Audience:** Albert (plain English first), then implementers.

---

## The short answer

Today every reviewer is a full program: it books the job, locks files, copies the tree, calls the model, writes the report, deletes evidence. That whole pile is copy-pasted — **that** is what breaks every 24–48 hours.

Tomorrow there is **one** booking office (the runner). Each model only has a **door** (an adapter). Whether the door talks to a native CLI or to OpenCode, the office still does the booking, the proof, and the cleanup.

```
                    ┌─────────────────────────────┐
                    │   ONE REVIEW RUNNER         │
                    │  identity · locks · packet  │
                    │  lifecycle · report floor   │
                    │  store proof THEN delete    │
                    └─────────────┬───────────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              ▼                   ▼                   ▼
        native door         native door          OpenCode door
        Claude / Codex      Grok · Qwen          GLM · Muse
        (their own CLI)     StepCode (Linux)     DeepSeek · StepFun*
```

\*StepFun is native StepCode on Ubuntu; on Windows it goes through OpenCode (see #1114).

**Same office. Different doors. One evidence pipeline.**

---

## What is a “harness”?

The harness is the program that actually runs the model session and its tools (read file, edit file, run command).

| Kind | Who | How we call it today |
|---|---|---|
| **Native harness** | Claude Code, Codex CLI, Grok Build, Qwen Code, StepCode | Wrapper execs that vendor CLI with pinned model, flags, and permissions |
| **OpenCode harness** | GLM, Muse, DeepSeek, and StepFun-on-Windows | Wrapper points at one pinned OpenCode binary plus a **profile** (`config/opencode-*/opencode.json` + `agent/*.md`) that pins model, tools, and protections |

Muse is special: default engine is Muse Code CLI; `AI_MUSE_ENGINE=opencode` rolls it onto OpenCode. Sessions never cross engines.

---

## What must live in the **one** runner (not in doors)

These are the pieces that are copy-pasted and keep breaking:

1. **Task gate** — is this review allowed for this change set?  
2. **Identity** — what exact tree is under review (head, base, digest)?  
3. **Sandbox** — disposable snapshot so the model cannot dirty the live repo.  
4. **Evidence packet** — sealed manifest + patch + identity + hash.  
5. **Durable store** — copy the **whole** packet, then delete the working copy.  
6. **Lifecycle** — begin → observe → terminal (`APPROVE|REJECT|BLOCKED` + failure class).  
7. **Report floor** — a real suggestion report, not a bare “PASS” (`MIN_REPORT_CHARS`).  
8. **Cleanup order** — store first; only then remove sandbox/packet.

Grok’s door and StepFun’s door must both end up with the same packet format and the same lifecycle row.

## What stays in the **door** (adapter)

Only “how we talk to this model”:

- Which binary: `claude`, `codex`, `grok`, `qwen`, `step`, or `opencode` + which profile dir.  
- Credentials and model pin (never the runner’s job to invent).  
- Provider-specific tool list (read-only vs write).  
- Parsing that provider’s answer into **our** report shape.  
- **Implement mode** extras that are truly provider-specific (worktree style, recovery notes) — but still **called by** the runner so evidence and locks are not forked.

---

## Why this is not “a library wrappers may call”

We already tried that. `ai-review-lifecycle` exists; Muse, Gemini, Qwen, DeepSeek, and StepFun never call it. A shared file on disk is not a forcing function.

The runner must be **the only door**:

- `ai-review-pool` / preflight **refuse** a review that did not go through the runner.  
- Merge/gates accept **only** runner-produced records.  
- New provider = new door file + registration, not a new copy of the office.

That is the structural change that ends the 24–48h loop along with #1112 (keep last good approval).

---

## Review vs implement (two contracts, one office)

| | Review | Implement |
|---|---|---|
| Output | Suggestion report + packet | Patch / worktree + packet |
| Tools | Read/search (or read-only policy) | Write tools per owner ruling |
| Isolation | Snapshot, no writes | New remote-less worktree |
| Failure | Report quality / stale source | Preserve worktree for recovery |

Doors do not each invent their own locks and deletes. The runner owns both contracts; the door only supplies the provider-specific bits.

---

## Order of work (linked to issues)

1. **#1111** Keep full evidence in the shared delete path (no fingerprint move).  
2. **#1112** Keep last good approval until a new check passes — **this is the 24–48h fix**.  
3. **#1114** Collapse native + OpenCode doors onto one runner (this document).  
4. **#1115** Outage vs code labels.

Nothing in 3 starts until 1 lands; 2 can follow 1 closely because it is still in preflight/qualification code, not in every door.
