#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY="$ROOT/bin/ai-repo-policy"; STATUS="$ROOT/bin/ai-workspace-status"
PASS=0; FAIL=0; ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }; bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

git init -q --bare --initial-branch=main "$TMP/repo.git"
git clone -q "$TMP/repo.git" "$TMP/work"
git -C "$TMP/work" config user.name T; git -C "$TMP/work" config user.email t@e
echo base > "$TMP/work/a"; git -C "$TMP/work" add a; git -C "$TMP/work" commit -qm init; git -C "$TMP/work" push -q -u origin main
cat > "$TMP/policy.json" <<'EOF'
{"schema_version":1,"default":{"workflow":"feature-branch-pr","main_branch":"main"},"rules":[{"match":"local/repo","workflow":"main-only","main_branch":"main"}]}
EOF
export AI_REPO_POLICY_FILE="$TMP/policy.json"
result="$(cd "$TMP/work" && "$POLICY")"
check 'local upstream resolves to stable repository identity' "jq -e '.repository==\"local/repo\"' <<<\"\$result\""
check 'main-only rule is selected from contract' "jq -e '.workflow==\"main-only\" and .main_branch==\"main\"' <<<\"\$result\""

git clone -q "$TMP/repo.git" "$TMP/other"; git -C "$TMP/other" config user.name T; git -C "$TMP/other" config user.email t@e
echo remote >> "$TMP/other/a"; git -C "$TMP/other" commit -qam remote; git -C "$TMP/other" push -q
output="$(cd "$TMP/work" && AI_REPO_POLICY_BIN="$POLICY" "$STATUS" 2>&1)"
check 'workspace status fetches before remote counts' "grep -Fq 'Behind    : 1 commit(s)' <<<\"\$output\""
check 'main-only status gives correct direct-main advice' "grep -Fq \"works directly on 'main'\" <<<\"\$output\""
check 'main-only status never recommends a feature branch' "! grep -Fqi 'create a feature branch' <<<\"\$output\""

git -C "$TMP/work" switch -qc wrong
check 'main-only status warns on the wrong branch' "cd '$TMP/work' && AI_REPO_POLICY_BIN='$POLICY' '$STATUS' 2>&1 | grep -Fq \"return to 'main'\""

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
