#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
git init -q -b main "$TMP/repo"
git -C "$TMP/repo" config user.name test; git -C "$TMP/repo" config user.email test@example.invalid
printf 'safe\n' > "$TMP/repo/README.md"; git -C "$TMP/repo" add README.md; git -C "$TMP/repo" commit -qm safe
bash "$ROOT/bin/ai-public-boundary-check" "$TMP/repo" >/dev/null || { echo 'FAIL: safe fixture rejected'; exit 1; }
mkdir -p "$TMP/repo/claude_chats"; printf '{}\n' > "$TMP/repo/claude_chats/session.jsonl"; git -C "$TMP/repo" add -f claude_chats/session.jsonl
if bash "$ROOT/bin/ai-public-boundary-check" "$TMP/repo" >/dev/null 2>&1; then echo 'FAIL: seeded transcript fixture passed'; exit 1; fi
git -C "$TMP/repo" reset -q HEAD claude_chats/session.jsonl; rm -rf "$TMP/repo/claude_chats"
printf 'ops_ABCDEFGHIJKLMNOPQRSTUVWXYZ123456\n' > "$TMP/repo/leak.txt"; git -C "$TMP/repo" add leak.txt
if bash "$ROOT/bin/ai-public-boundary-check" "$TMP/repo" >/dev/null 2>&1; then echo 'FAIL: seeded credential fixture passed'; exit 1; fi
git -C "$TMP/repo" reset -q HEAD leak.txt; rm -f "$TMP/repo/leak.txt"
printf 'HostName 100.90.80.70\n' > "$TMP/repo/topology.txt"; git -C "$TMP/repo" add topology.txt
if bash "$ROOT/bin/ai-public-boundary-check" "$TMP/repo" >/dev/null 2>&1; then echo 'FAIL: seeded topology fixture passed'; exit 1; fi
git -C "$TMP/repo" reset -q HEAD topology.txt; rm -f "$TMP/repo/topology.txt"
printf 'project-ref abcdefghijklmnopqrst\n' > "$TMP/repo/project.txt"; git -C "$TMP/repo" add project.txt
if bash "$ROOT/bin/ai-public-boundary-check" "$TMP/repo" >/dev/null 2>&1; then echo 'FAIL: seeded project identifier fixture passed'; exit 1; fi
git -C "$TMP/repo" reset -q HEAD project.txt; rm -f "$TMP/repo/project.txt"

# The project-shaped rule is a bare 20-lowercase-letter shape, so ordinary long
# English words trip it. The escape hatch is a reviewed allowlist, never a wider
# pattern. These three cases pin that bargain: the allowlist clears a real word,
# it cannot launder an identifier sharing the line, and the failure names the
# file and line it found (the old message named neither, which cost a session
# twenty minutes of bisecting a documentation-only change).
mkdir -p "$TMP/repo/tools"; cp "$ROOT/tools/public-boundary-allowlist.txt" "$TMP/repo/tools/"
git -C "$TMP/repo" add tools/public-boundary-allowlist.txt
printf 'the word indistinguishability is ordinary English
' > "$TMP/repo/word.md"; git -C "$TMP/repo" add word.md
bash "$ROOT/bin/ai-public-boundary-check" "$TMP/repo" >/dev/null 2>&1 || { echo 'FAIL: allowlisted English word rejected'; exit 1; }
printf 'indistinguishability abcdefghijklmnopqrst
' > "$TMP/repo/word.md"; git -C "$TMP/repo" add word.md
if bash "$ROOT/bin/ai-public-boundary-check" "$TMP/repo" >/dev/null 2>&1; then echo 'FAIL: allowlisted word laundered a real identifier on the same line'; exit 1; fi
DIAG="$(bash "$ROOT/bin/ai-public-boundary-check" "$TMP/repo" 2>&1 || true)"
printf '%s' "$DIAG" | grep -q 'word.md:1:' || { echo 'FAIL: boundary failure does not name the offending file and line'; exit 1; }
printf '%s' "$DIAG" | grep -q 'public-boundary-allowlist.txt' || { echo 'FAIL: boundary failure does not say how to clear a false positive'; exit 1; }
git -C "$TMP/repo" reset -q HEAD word.md tools/public-boundary-allowlist.txt; rm -rf "$TMP/repo/word.md" "$TMP/repo/tools"
mkdir -p "$TMP/repo/.ai/scratch"; printf '{}\n' > "$TMP/repo/.ai/scratch/issue.json"; git -C "$TMP/repo" add -f .ai/scratch/issue.json
if bash "$ROOT/bin/ai-public-boundary-check" "$TMP/repo" >/dev/null 2>&1; then echo 'FAIL: seeded AI artifact fixture passed'; exit 1; fi
git -C "$TMP/repo" reset -q HEAD .ai/scratch/issue.json; rm -rf "$TMP/repo/.ai/scratch"
# .ai/reviewer-issues/ is an intentional publish (PR #1626) and must pass.
mkdir -p "$TMP/repo/.ai/reviewer-issues"; printf '{}\n' > "$TMP/repo/.ai/reviewer-issues/issue.json"; git -C "$TMP/repo" add -f .ai/reviewer-issues/issue.json
bash "$ROOT/bin/ai-public-boundary-check" "$TMP/repo" >/dev/null 2>&1 || { echo 'FAIL: reviewer-issues publish path rejected'; exit 1; }
# Secret-bearing names and extensions must fail even under the publish path.
for f in leak.env leak.env.production leak.pem leak.key auth.json credentials.json id_rsa id_ed25519 token.txt secret.txt private.key; do
  printf 'x\n' > "$TMP/repo/.ai/reviewer-issues/$f"; git -C "$TMP/repo" add -f ".ai/reviewer-issues/$f"
  if bash "$ROOT/bin/ai-public-boundary-check" "$TMP/repo" >/dev/null 2>&1; then echo "FAIL: reviewer-issues $f fixture passed"; exit 1; fi
  git -C "$TMP/repo" reset -q HEAD ".ai/reviewer-issues/$f"; rm -f "$TMP/repo/.ai/reviewer-issues/$f"
done
git -C "$TMP/repo" reset -q HEAD .ai/reviewer-issues/issue.json; rm -rf "$TMP/repo/.ai/reviewer-issues"
bash "$ROOT/bin/ai-public-boundary-check" "$ROOT" >/dev/null || { echo 'FAIL: current repository violates public boundary'; exit 1; }
echo 'PASS: seeded transcript, AI artifact, credential, topology, and project violations fail the public boundary gate; the allowlist clears words without laundering identifiers'
