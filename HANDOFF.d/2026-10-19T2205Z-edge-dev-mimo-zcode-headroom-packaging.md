---
issue: none
status: OPEN
owner: u2giants / next MiMo session
---

# Z-code Headroom HTTPS lane — packaging PR still in merge queue

## 1. What this workstream is

Ship `ai-zcode-headroom` (default-off switch) and rebuild templates so every
new machine can use the Z-code + Headroom HTTPS lane. Live lane on edge-dev +
hetz already works (owner confirmed 2026-10-19).

## 2. Where things stand

| Item | State |
|---|---|
| Docs runbook + Workflow C correction | **MERGED** PR #1865 |
| Tool `ai-zcode-headroom` + templates + tests | **OPEN** PR #1867, merge queue / `BLOCKED` |
| Live Z-code via HTTPS Headroom on edge-dev | working |
| Claude Headroom lane (8787) | working — do not touch for Z-code work |

PR: https://github.com/popcre/ai-devops/pull/1867  
Branch: `docs/zcode-headroom-runbook`  
Worktree used: `C:\repos\ai-devops-wt-zcode-headroom-doc`

Commits on that branch after #1865 squash:
- `450cdf2c` feat(zcode-headroom): installable default-off switch and rebuild templates
- `7b2df499` Merge origin/main (kept packaging docs over squash conflict)
- `96ae9bf5` test: register test-ai-zcode-headroom in ci-suite-manifest discovery

## 3. What was tried and failed

- Initial HTTP `:8788` client wiring failed Z.ai signing (`Client signing handshake requires HTTPS.`).
- Private-CA-only `SSL_CERT_FILE` replaced public trust and broke zcode.z.ai MCP.
- Windows curl schannel / OpenSSL 3.13 reject the private CA (revocation / CA keyUsage) — health probe uses `curl -sk` on unauthenticated `/health`.
- First CI run on #1867 failed `manifest exactly matches Bash discovery` until `config/ci-suites/test-ai-zcode-headroom.sh.json` was added; `windows-offline` failed closed because sections were skipped.

## 4. Exact next action

1. Watch https://github.com/popcre/ai-devops/pull/1867 until `MERGED` (auto-merge is on; merge queue).
2. If checks fail again, fix in that branch only — do not admin-merge (non-prose).
3. After merge: confirm `origin/main` has `bin/ai-zcode-headroom`; run
   `tests/test-ai-zcode-headroom.sh` from a clean checkout.
4. Optional later (NOT required for PR 1867): package VPS bring-up docs; leaf cert renew before 2028-11.

## 5. How to verify success

- `gh pr view 1867 --repo popcre/ai-devops --json state,mergedAt` → MERGED
- `https://github.com/popcre/ai-devops/blob/main/bin/ai-zcode-headroom` exists
- Offline test file listed in CI suite discovery is green

## 6. What not to do (learned this session)

- Never give Z-code an `http://` provider baseUrl (signing refuses).
- Never set `SSL_CERT_FILE` / `REQUESTS_CA_BUNDLE` to a private-CA-only file.
- Never bind Headroom/TLS front to `0.0.0.0`.
- Never “fix” Claude with Z-code’s HTTPS/CA stack; Claude uses `ai-headroom` + HTTP on 8787.
- Never admin-merge non-prose PRs.
- Never put concrete Tailscale IPs in public docs (public-boundary gate).

## 7. Owner decisions still open

- None blocking PR 1867. Leaf renew / toolkit VPS installer are optional follow-ups.

## 8. Pointers (GitHub URLs)

- https://github.com/popcre/ai-devops/blob/main/docs/zcode-headroom-runbook.md
- https://github.com/popcre/ai-devops/blob/main/docs/headroom.md
- https://github.com/popcre/ai-devops/pull/1867
- https://github.com/popcre/ai-devops/pull/1865

## 9. Session / machine

- Session: MiMo Desktop, 2026-10-19, edge-dev
- Agent: MiMo
