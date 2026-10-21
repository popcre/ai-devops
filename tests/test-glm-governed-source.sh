#!/usr/bin/env bash
# Real ai-glm prepare_review + ai-review-packet: a pool-launched governed GLM
# review must snapshot the ORIGINAL checkout so its receipt binds it
# (shared-db#4308). Offline: no server, no provider.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export AI_DEVOPS_TEST_MODE=1 AI_TASK_GATES_MODE=none AI_REVIEW_SANDBOX_HOME="$TMP/sandboxes"
. "$ROOT/tests/lib-reviewer-events-isolation.sh"
PASS=0
ok(){ PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
fail(){ printf '  FAIL %s\n' "$1" >&2; exit 1; }
mkdir -p "$TMP/repo"
git -C "$TMP/repo" init -q -b main
git -C "$TMP/repo" config user.name Test; git -C "$TMP/repo" config user.email t@example.com
printf '.ai/\n' > "$TMP/repo/.gitignore"; printf 'a\n' > "$TMP/repo/f"
git -C "$TMP/repo" add .gitignore f; git -C "$TMP/repo" commit -qm base
BASE="$(git -C "$TMP/repo" rev-parse HEAD)"
printf 'b\n' > "$TMP/repo/f"; git -C "$TMP/repo" commit -qam change
HEAD="$(git -C "$TMP/repo" rev-parse HEAD)"
ORIG="$(cd "$TMP/repo" && pwd -P)"
. "$ROOT/tools/lib/path-identity.sh"
mkdir -p "$ORIG/.ai/reviews"
POOL="$("$ROOT/bin/ai-review-sandbox" ensure-copy "$ORIG" pool-probe)"

cat > "$TMP/case.sh" <<'CASE'
set -e
source "$AI_GLM_SOURCE"
OPT_BASE="$CASE_BASE"; OPT_ASSERT_HEAD="$CASE_HEAD"; OPT_TESTS=''; OPT_DECISION=''
cd "$CASE_CWD"
prepare_review "$(git rev-parse --show-toplevel)" "$CASE_NAME"
printf '%s\n' "$REVIEW_DIR" > "$CASE_OUT"
CASE

run_case(){ # run_case NAME [env...]
  local name="$1"; shift
  env "$@" AI_GLM_SOURCE="$ROOT/bin/ai-glm" CASE_BASE="$BASE" CASE_HEAD="$HEAD" CASE_CWD="$POOL" CASE_NAME="$name" \
    CASE_OUT="$TMP/$name.out" bash "$TMP/case.sh" > "$TMP/$name.log" 2>&1
}

RECEIPT="$ORIG/.ai/reviews/governed-source-probe.json"
run_case gov AI_REVIEW_SOURCE_RECEIPT_FILE="$RECEIPT" AI_REVIEW_SOURCE_ROOT="$ORIG" || { cat "$TMP/gov.log" >&2; fail 'governed pool dispatch builds and verifies its packet'; }
ok 'governed pool dispatch builds and verifies its packet'
ai_same_path "$(jq -r .identity.repository "$RECEIPT")" "$ORIG" && [ "$(jq -r .identity.head "$RECEIPT")" = "$HEAD" ] \
  && ok 'receipt binds the original checkout and exact head' || fail 'receipt binds the original checkout and exact head'
[ "$(head -1 "$(cat "$TMP/gov.out")/.ai-review-sandbox" 2>/dev/null || true)" != "$POOL" ] \
  && ok 'review snapshot is one level deep (not a copy of the pool snapshot)' || fail 'review snapshot is one level deep'

run_case plain || { cat "$TMP/plain.log" >&2; fail 'ordinary dispatch is unchanged'; }
ok 'ordinary dispatch without a receipt request is unchanged'

if run_case wrongroot AI_REVIEW_SOURCE_RECEIPT_FILE="$RECEIPT" AI_REVIEW_SOURCE_ROOT="$TMP"; then fail 'a source root that is not a repository top level is refused'; fi
grep -q 'governed source root is not a repository top level' "$TMP/wrongroot.log" && ok 'a source root that is not a repository top level is refused' || { cat "$TMP/wrongroot.log" >&2; fail 'wrong root refusal'; }

mkdir -p "$TMP/elsewhere"
if run_case wrongreceipt AI_REVIEW_SOURCE_RECEIPT_FILE="$TMP/elsewhere/r.json" AI_REVIEW_SOURCE_ROOT="$ORIG"; then fail 'a receipt outside the source root reports is refused'; fi
grep -q "not inside the governed source root's .ai/reviews" "$TMP/wrongreceipt.log" && ok 'a receipt outside the source root reports is refused' || { cat "$TMP/wrongreceipt.log" >&2; fail 'receipt refusal'; }

ln -s "$ORIG" "$TMP/link"
if run_case linkroot AI_REVIEW_SOURCE_RECEIPT_FILE="$RECEIPT" AI_REVIEW_SOURCE_ROOT="$TMP/link"; then fail 'a linked source root is refused'; fi
grep -q 'governed source root is not a directory' "$TMP/linkroot.log" && ok 'a linked source root is refused' || { cat "$TMP/linkroot.log" >&2; fail 'link refusal'; }
printf 'GLM governed source: %d checks passed\n' "$PASS"
