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
bash "$ROOT/bin/ai-public-boundary-check" "$ROOT" >/dev/null || { echo 'FAIL: current repository violates public boundary'; exit 1; }
echo 'PASS: seeded transcript, credential, topology, and project violations fail the public boundary gate'
