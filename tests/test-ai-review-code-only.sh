#!/usr/bin/env bash
# Offline hostile fixture for the exact DeepSeek packet path. No provider call.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY3="$(command -v python3 || command -v python)"
SANDBOX="$ROOT/bin/ai-review-sandbox"
PACKET="$ROOT/bin/ai-review-packet"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }
# The sentinel scans below run inside `if rg ...; then fail; fi`, which a
# missing rg would silently skip instead of failing.
command -v rg >/dev/null 2>&1 || fail 'ripgrep (rg) is required for the export scans'
must_fail() { if "$@" > "$TMP/refusal.out" 2>&1; then fail "unexpected success: $*"; fi; }

mkdir -p "$TMP/mockbin" "$TMP/private/src" "$TMP/private/tests" "$TMP/private/contracts" "$TMP/private/data"
cat > "$TMP/mockbin/ai-task-gates" <<'EOF'
#!/usr/bin/env bash
printf '{"identity_resolved":true,"effective_class":"private-evidence","observed_class":"private-evidence"}\n'
EOF
chmod +x "$TMP/mockbin/ai-task-gates"
export PATH="$TMP/mockbin:$PATH"

R="$TMP/private"
git -C "$R" init -q -b main
git -C "$R" config user.name Test
git -C "$R" config user.email test@example.invalid
git -C "$R" config core.autocrlf false
printf 'print("allowed base")\n' > "$R/src/app.py"
printf 'def test_ok(): assert True\n' > "$R/tests/test_app.py"
printf '{"schema":"safe"}\n' > "$R/contracts/schema.json"
printf 'PRIVATE_TRACKED_SENTINEL\n' > "$R/data/tracked.txt"
printf 'PRIVATE_DIRTY_BASE_SENTINEL\n' > "$R/data/modified.txt"
printf 'PRIVATE_DELETED_HISTORY_SENTINEL\n' > "$R/data/deleted.txt"
printf 'data/ignored.txt\n' > "$R/.gitignore"
git -C "$R" add --all
git -C "$R" commit -qm baseline
BASE="$(git -C "$R" rev-parse HEAD)"
git -C "$R" update-ref refs/remotes/origin/main "$BASE"
git -C "$R" checkout -q -b feature
printf 'print("allowed changed")\n' > "$R/src/app.py"
rm "$R/data/deleted.txt"
git -C "$R" add --all
git -C "$R" commit -qm feature
ORIGINAL_HEAD="$(git -C "$R" rev-parse HEAD)"
printf 'PRIVATE_DIRTY_CURRENT_SENTINEL\n' > "$R/data/modified.txt"
printf 'PRIVATE_UNTRACKED_SENTINEL\n' > "$R/data/untracked.txt"
printf 'PRIVATE_IGNORED_SENTINEL\n' > "$R/data/ignored.txt"
printf '["src/app.py","tests/test_app.py","contracts/schema.json"]\n' > "$TMP/approved.json"

"$SANDBOX" is-private "$R" || fail 'complete private inventory was not classified'
must_fail "$SANDBOX" ensure-copy "$R" ordinary
grep -q 'private source requires explicit' "$TMP/refusal.out" || fail 'ordinary snapshot refusal not explicit'
must_fail "$PACKET" resolve "$R" --assert-head "$ORIGINAL_HEAD"
must_fail "$PACKET" build "$R" ordinary
pass 'ordinary snapshot and packet paths refuse private source'

EXPORT="$("$SANDBOX" ensure-code-only "$R" codeonly --paths-file "$TMP/approved.json" --base "$BASE")"
"$SANDBOX" verify-code-only "$EXPORT" --assert-head "$ORIGINAL_HEAD"
[ "$(git -C "$EXPORT" rev-list --count HEAD)" = 2 ] || fail 'synthetic export does not have two commits'
[ "$(git -C "$EXPORT" rev-parse HEAD^)" != "$BASE" ] || fail 'source history leaked into synthetic history'
[ ! -e "$EXPORT.source.json/." ] || fail 'host-only sidecar is under the export'
[ -f "$EXPORT.source.json" ] || fail 'host-only source binding absent'
if rg -a -q 'PRIVATE_(TRACKED|DIRTY|UNTRACKED|IGNORED|DELETED)_.*SENTINEL' "$EXPORT"; then
  fail 'private evidence appeared in exported working tree or synthetic Git history'
fi
if rg -a -F -q "$R" "$EXPORT"; then fail 'original source path appeared inside reviewer directory'; fi
pass 'two synthetic commits contain only approved code and contracts'

IDENTITY="$TMP/identity.json"
"$PACKET" resolve "$EXPORT" --base HEAD~1 --assert-head "$(git -C "$EXPORT" rev-parse HEAD)" > "$IDENTITY"
jq -e --arg head "$ORIGINAL_HEAD" '.code_only.original_head == $head and .code_only.source_digest != null and .code_only.path_manifest_sha256 != null' "$IDENTITY" >/dev/null \
  || fail 'original exact head and digests were not sealed into identity'
SNAP="$("$SANDBOX" ensure-copy "$EXPORT" deepseek)"
PKT="$("$PACKET" build "$SNAP" deepseek --identity "$IDENTITY")"
"$PACKET" verify "$PKT" --identity "$IDENTITY" > /dev/null
mkdir -p "$EXPORT/.ai/deepseek-sessions"
printf 'local provider receipt\n' > "$EXPORT/.ai/deepseek-sessions/receipt.json"
"$SANDBOX" verify-code-only "$EXPORT" --assert-head "$ORIGINAL_HEAD"
"$PACKET" verify "$PKT" --identity "$IDENTITY" > /dev/null

# Match ai-deepseek-agent's attachment inventory: packet files plus untracked
# snapshot files. Its Git exclusion must keep generated metadata out.
find "$PKT" -type f -print0 > "$TMP/attachments.z"
git -C "$SNAP" ls-files --others --exclude-standard -z >> "$TMP/attachments.z"
"$PY3" - "$PKT" "$SNAP" "$TMP/attachments.z" "$R" "$EXPORT.source.json" <<'PY'
import pathlib, sys
packet, snap, manifest, source, binding = map(pathlib.Path, sys.argv[1:])
import json
bound_source = json.loads(binding.read_text(encoding='utf-8'))['source'].encode()
sentinels = [b'PRIVATE_TRACKED_SENTINEL', b'PRIVATE_DIRTY_CURRENT_SENTINEL',
             b'PRIVATE_UNTRACKED_SENTINEL', b'PRIVATE_IGNORED_SENTINEL',
             b'PRIVATE_DELETED_HISTORY_SENTINEL']
for path in packet.rglob('*'):
    if path.is_file():
        data = path.read_bytes()
        assert all(s not in data for s in sentinels), path
        assert str(source).encode() not in data and bound_source not in data, path
for path in snap.rglob('*'):
    if path.is_file():
        data = path.read_bytes()
        assert all(s not in data for s in sentinels), path
        assert str(source).encode() not in data and bound_source not in data, path
assert not any(b'.source.json' in p for p in manifest.read_bytes().split(b'\0'))
PY
pass 'DeepSeek attachment set and packet contain no private sentinels or host-only path'

printf 'PRIVATE_POST_REVIEW_DRIFT_SENTINEL\n' > "$R/data/untracked.txt"
must_fail "$SANDBOX" verify-code-only "$EXPORT" --assert-head "$ORIGINAL_HEAD"
must_fail "$PACKET" verify "$PKT" --identity "$IDENTITY"
pass 'post-review source drift invalidates the export and packet'

printf '["data/tracked.txt"]\n' > "$TMP/rejected.json"
must_fail "$SANDBOX" ensure-code-only "$R" rejected-data --paths-file "$TMP/rejected.json" --base "$BASE"
printf '["contracts/../data/tracked.txt"]\n' > "$TMP/rejected.json"
must_fail "$SANDBOX" ensure-code-only "$R" rejected-traversal --paths-file "$TMP/rejected.json" --base "$BASE"
printf '["data/ignored.txt"]\n' > "$TMP/rejected.json"
must_fail "$SANDBOX" ensure-code-only "$R" rejected-ignored --paths-file "$TMP/rejected.json" --base "$BASE"
pass 'ambiguous, evidence, and ignored paths refuse before publication'

LINK_BLOB="$(printf 'data/tracked.txt' | git -C "$R" hash-object -w --stdin)"
git -C "$R" update-index --add --cacheinfo "120000,$LINK_BLOB,src/linked.py"
git -C "$R" commit -qm linked-code-path
printf '["src/linked.py"]\n' > "$TMP/rejected.json"
must_fail "$SANDBOX" ensure-code-only "$R" rejected-link --paths-file "$TMP/rejected.json" --base "$BASE"
git -C "$R" update-index --add --cacheinfo "160000,$BASE,src/submodule.py"
git -C "$R" commit -qm submodule-code-path
printf '["src/submodule.py"]\n' > "$TMP/rejected.json"
must_fail "$SANDBOX" ensure-code-only "$R" rejected-submodule --paths-file "$TMP/rejected.json" --base "$BASE"
pass 'symlink and submodule objects refuse before publication'

# A linked PARENT inside the repository can smuggle a denied directory under
# an approved spelling: an in-repo src -> data link plus an approved
# src/tracked.txt reads data/tracked.txt while the spelling still looks like
# code (exact-head review, 2026-09-25). Needs a filesystem with real links.
rm -rf "$TMP/linkcap"; if ln -s data "$TMP/linkcap" 2>/dev/null && [ -L "$TMP/linkcap" ]; then
  rm -rf "$R/src"
  ln -s data "$R/src"
  printf '["src/tracked.txt"]\n' > "$TMP/rejected.json"
  must_fail "$SANDBOX" ensure-code-only "$R" rejected-linked-parent --paths-file "$TMP/rejected.json" --base "$BASE"
  pass 'a linked parent directory refuses before publication'
else
  echo 'SKIP: linked parent refused (filesystem symlinks unsupported)'
fi

printf '6 passed; 0 failed\n'
