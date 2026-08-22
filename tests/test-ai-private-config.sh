#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$ROOT/bin/ai-private-config"
TMP="$(mktemp -d)"
PASS=0
FAIL=0
trap 'rm -rf "$TMP"' EXIT

ok(){ PASS=$((PASS+1)); printf 'ok %s\n' "$1"; }
bad(){ FAIL=$((FAIL+1)); printf 'not ok %s\n' "$1" >&2; }
expect_ok(){ local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi; }
expect_fail(){ local name="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$name"; else ok "$name"; fi; }

FIXTURE="$TMP/private"
mkdir -p "$FIXTURE/ssh" "$FIXTURE/machines"
printf 'Host example\n' > "$FIXTURE/ssh/config"
printf 'host key\n' > "$FIXTURE/ssh/known_hosts"
printf '# Atlas\n' > "$FIXTURE/machines/atlas.md"
cat > "$FIXTURE/manifest.json" <<'JSON'
{
  "schema_version": 1,
  "repository": "u2giants/ai-devops-private-config",
  "files": {
    "ssh_config": "ssh/config",
    "ssh_known_hosts": "ssh/known_hosts",
    "machine_atlas": "machines/atlas.md"
  },
  "values": {"supabase_project_ref": "fixture-project"}
}
JSON
git -C "$FIXTURE" init -q
git -C "$FIXTURE" remote add origin "$TMP/fixture-origin.git"

run(){ AI_PRIVATE_CONFIG_HOME="$FIXTURE" AI_PRIVATE_CONFIG_ALLOW_FIXTURE=1 "$TOOL" "$@"; }

expect_ok 'doctor validates a protected fixture' run doctor
actual="$(run value supabase_project_ref 2>/dev/null || true)"
[ "$actual" = fixture-project ] && ok 'value returns a manifest value' || bad 'value returns a manifest value'
path="$(run path ssh_config 2>/dev/null || true)"
[ -f "$path" ] && ok 'path resolves an existing protected file' || bad 'path resolves an existing protected file'
expect_fail 'unknown values fail closed' run value missing
expect_fail 'unknown file keys fail closed' run path missing

jq '.files.escape="../outside"' "$FIXTURE/manifest.json" > "$TMP/manifest.json"
mv "$TMP/manifest.json" "$FIXTURE/manifest.json"
expect_fail 'path traversal is rejected' run path escape

git -C "$FIXTURE" remote set-url origin https://github.com/example/wrong.git
expect_ok 'fixture override is explicit and test-only' run doctor
expect_fail 'production validation rejects the wrong upstream' env AI_PRIVATE_CONFIG_HOME="$FIXTURE" "$TOOL" doctor

printf '%s\n' "Passed: $PASS" "Failed: $FAIL"
[ "$FAIL" -eq 0 ]
