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
PASS=0
pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
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
  rm -f "$R/src"
  mkdir "$R/src"
  pass 'a linked parent directory refuses before publication'
else
  echo 'SKIP: linked parent refused (filesystem symlinks unsupported)'
fi

# A retained export stands in for a private source: a directory-bound CLI
# reviewer launched inside it must be refused exactly like the private
# checkout, and the export's sidecars must not outlive any removal path
# (exact-head review, 2026-09-25).
FRONT="$ROOT/bin/ai-review"
if ( cd "$EXPORT" && AI_CLAUDE_REVIEW_BIN=/bin/true "$FRONT" claude diff-review ) > "$TMP/cli-in-export.out" 2>&1; then
  fail 'a CLI reviewer started inside a retained code-only export'
fi
grep -Fq 'private source requires the code-only attachment route' "$TMP/cli-in-export.out" \
  || fail 'the in-export refusal did not name the attachment route'
# The earlier fixtures moved the source HEAD after the first export, so a
# drift-clean export is created fresh before proving cleanup removes it.
EXPORT2="$("$SANDBOX" ensure-code-only "$R" cleanupcheck --paths-file "$TMP/approved.json" --base HEAD)"
"$SANDBOX" remove "$R" cleanupcheck
[ ! -e "$EXPORT2" ] || fail 'ordinary-clone remove left the code-only stage'
[ ! -e "$EXPORT2.source.json" ] || fail 'ordinary-clone remove left the source sidecar'
[ ! -e "$EXPORT2.owners.json" ] || fail 'ordinary-clone remove left the owners sidecar'
pass 'retained exports refuse CLI reviewers and clean up with their sidecars'

# A hardlink shares its bytes with a denied location while the approved
# spelling stays clean, and resolve() cannot see it; only the link count can
# (exact-head review, 2026-09-25). os.link works on NTFS and the Linux
# runners alike.
if "$PY3" -c 'import os,sys; os.link(sys.argv[1], sys.argv[2])' "$R/data/tracked.txt" "$R/src/smuggled.py" 2>/dev/null; then
  printf '["src/smuggled.py"]\n' > "$TMP/rejected.json"
  must_fail "$SANDBOX" ensure-code-only "$R" rejected-hardlink --paths-file "$TMP/rejected.json" --base "$BASE"
  rm -f "$R/src/smuggled.py"
  pass 'a hardlinked approved path refuses before publication'
else
  echo 'SKIP: hardlink refused (filesystem hardlinks unsupported)'
fi

# Absolute GIT_DIR/GIT_WORK_TREE in the inherited environment override
# `git -C`, which would aim the synthetic export's own git calls at the
# private source instead of the stage; the exporter strips them, so the
# export stays isolated and verifiable (exact-head review, 2026-09-25).
if GIT_DIR="$R/.git" GIT_WORK_TREE="$R" "$SANDBOX" ensure-code-only "$R" envdir --paths-file "$TMP/approved.json" --base "$BASE" > "$TMP/envdir.out" 2>&1 \
   && "$SANDBOX" verify-code-only "$(cat "$TMP/envdir.out")" >/dev/null 2>&1 \
   && [ "$(git -C "$(cat "$TMP/envdir.out")" log --all --format=%s | wc -l)" -eq 2 ] \
   && ! git -C "$(cat "$TMP/envdir.out")" log --all --format=%s | grep -Fqx feature; then
  pass 'inherited GIT_DIR cannot redirect the synthetic export'
else
  fail 'inherited GIT_DIR redirected or broke the synthetic export'
fi

# The export tool itself enforces the repository opt-in: a direct
# ensure-code-only call on a private repository that never declared the
# fixtures boundary refuses exactly where the gate would (fourth exact-head
# review of #666, 2026-09-26). The mockbin stub is bypassed with the real
# gate for this one invocation.
PRIV="$TMP/undeclared"; mkdir -p "$PRIV/src"
git -C "$PRIV" init -q -b main
git -C "$PRIV" config user.email t@e.invalid; git -C "$PRIV" config user.name T
git -C "$PRIV" remote add origin https://github.com/u2giants/licensor-source-data.git
printf 'print("x")
' > "$PRIV/src/loader.py"
git -C "$PRIV" add -A; git -C "$PRIV" commit -qm base
printf '["src/loader.py"]
' > "$TMP/priv-paths.json"
if AI_TASK_GATES_BIN="$ROOT/bin/ai-task-gates" AI_TASK_GATES_FILE="$ROOT/config/task-gates.json" AI_TASK_GATES_DIR="$TMP/gates-state" \
   "$SANDBOX" ensure-code-only "$PRIV" undeclared --paths-file "$TMP/priv-paths.json" --base HEAD > "$TMP/undeclared.out" 2>&1; then
  fail 'a direct code-only export started without the fixtures opt-in'
fi
grep -Fq 'synthetic-fixtures-only' "$TMP/undeclared.out" \
  || fail 'the refusal did not name the missing fixtures boundary'
pass 'a direct code-only export requires the repository opt-in'
# The same refusal must hold when inherited Git location variables point the
# gate's own git calls at a decoy PUBLIC repository: the opt-in classifies
# the tree being exported, never the environment's idea of a repository
# (exact-head review of this follow-up, 2026-09-26).
DECOY="$TMP/decoy-public"; mkdir -p "$DECOY"
git -C "$DECOY" init -q -b main
git -C "$DECOY" config user.email t@e.invalid; git -C "$DECOY" config user.name T
printf 'plain
' > "$DECOY/plain.txt"
git -C "$DECOY" add -A; git -C "$DECOY" commit -qm base
if AI_TASK_GATES_BIN="$ROOT/bin/ai-task-gates" AI_TASK_GATES_FILE="$ROOT/config/task-gates.json" AI_TASK_GATES_DIR="$TMP/gates-state"    GIT_DIR="$DECOY/.git" GIT_WORK_TREE="$DECOY"    "$SANDBOX" ensure-code-only "$PRIV" undeclared-env --paths-file "$TMP/priv-paths.json" --base HEAD > "$TMP/undeclared-env.out" 2>&1; then
  fail 'an inherited GIT_DIR opened the sealed route without the opt-in'
fi
grep -Fq 'synthetic-fixtures-only' "$TMP/undeclared-env.out"   || fail 'the decoy refusal did not name the missing fixtures boundary'
pass 'an inherited GIT_DIR cannot decoy the export opt-in'

# The front door itself must strip inherited Git location variables: with
# GIT_DIR/GIT_WORK_TREE aimed at the private tree, the synthetic HEAD capture
# and the provider launch would otherwise bind to the private repository and
# hand DeepSeek the private work tree instead of the stage (exact-head
# review, 2026-09-25).
STUB_DEEPSEEK="$TMP/stub-deepseek"
cat > "$STUB_DEEPSEEK" <<'STUB'
#!/usr/bin/env bash
pwd -P > "$STUB_DEEPSEEK_CWD"
printf 'GIT_DIR=%s\n' "${GIT_DIR:-<stripped>}" > "$STUB_DEEPSEEK_ENV"
sha=""
while [ "$#" -gt 0 ]; do
  [ "$1" = "--governed-verdict" ] && sha="$2"
  shift
done
printf 'VERDICT: APPROVE %s\n' "$sha"
STUB
chmod +x "$STUB_DEEPSEEK"
export STUB_DEEPSEEK_CWD="$TMP/stub-deepseek-cwd" STUB_DEEPSEEK_ENV="$TMP/stub-deepseek-env"
if ( cd "$R" && GIT_DIR="$R/.git" GIT_WORK_TREE="$R" AI_DEVOPS_TEST_MODE=1 AI_DEEPSEEK_REVIEW_BIN="$STUB_DEEPSEEK" \
       "$FRONT" deepseek diff-review --code-only --paths-file "$TMP/approved.json" --base "$BASE" ) > "$TMP/gitdir-route.out" 2>&1; then
  STAGE_CWD="$(cat "$TMP/stub-deepseek-cwd")"
  case "$STAGE_CWD" in "$TMP"/sandboxes/*) : ;; *) fail "provider launched in $STAGE_CWD, not the synthetic stage" ;; esac
  grep -Fq 'GIT_DIR=<stripped>' "$TMP/stub-deepseek-env" || fail 'GIT_DIR reached the provider environment'
  grep -Fq 'VERDICT: APPROVE' "$TMP/gitdir-route.out" || fail 'sealed route did not publish its verdict'
  pass 'inherited GIT_DIR cannot redirect the front-door sealed route'
else
  cat "$TMP/gitdir-route.out" >&2
  fail 'inherited GIT_DIR broke the front-door sealed route'
fi

printf '%d passed; 0 failed\n' "$PASS"
