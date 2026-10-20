#!/usr/bin/env bash
# Offline tests for bin/ai-release-live-check and the shared review code
# detector (#1783, plan_release-live-review-check.md). Real reviews are the
# live proof; here ai-review and gh are fakes on PATH or in a fixture candidate.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
check() { if eval "$2" >/dev/null 2>&1; then echo "  ok   $1"; pass=$((pass+1)); else echo "  FAIL $1"; fail=$((fail+1)); fi; }

# Detector.
check 'doors file is shared review code' \
  "bash -c 'source \"$ROOT/tools/lib/review-capabilities.sh\"; review_shared_code_changed config/review-runner-doors.json'"
check 'bin/ai-review-pool is shared review code' \
  "bash -c 'source \"$ROOT/tools/lib/review-capabilities.sh\"; review_shared_code_changed \"\$(printf \"docs/a.md\nbin/ai-review-pool\n\")\"'"
check 'a docs change is not shared review code' \
  "! bash -c 'source \"$ROOT/tools/lib/review-capabilities.sh\"; review_shared_code_changed docs/x.md'"

# run: a fixture candidate whose bin/ai-review is a fake controlled by MODE.
cand="$TMP/cand"; mkdir -p "$cand/bin"
cp "$ROOT/bin/ai-release-live-check" "$cand/bin/"
cat > "$cand/bin/ai-review" <<'EOF'
#!/usr/bin/env bash
case "$(cat "$FAKE_MODE")" in
  approve) printf '# r\n\n## Verdict\nAPPROVE\n' > report.md; echo "$PWD/report.md" ;;
  noverdict) printf '# r\nno decision\n' > report.md; echo "$PWD/report.md" ;;
  crash) echo 'spawnSync bash UNKNOWN' >&2; exit 1 ;;
esac
EOF
chmod +x "$cand/bin/ai-review" "$cand/bin/ai-release-live-check"
git -C "$cand" init -q -b main && git -C "$cand" add -A &&
  git -C "$cand" -c user.name=t -c user.email=t@t commit -qm cand
head="$(git -C "$cand" rev-parse HEAD)"
export FAKE_MODE="$TMP/mode"
run_mode() { echo "$1" > "$FAKE_MODE"; "$cand/bin/ai-release-live-check" run --target-head "$head"; }
check 'run passes on a real verdict' "run_mode approve | jq -e '.ok==true and .verdict==\"APPROVE\"'"
check 'run fails on exit 0 with no verdict' "! run_mode noverdict"
check 'run fails on a crashing reviewer and keeps its error' "out=\$(run_mode crash); [ \$? -ne 0 ] && printf '%s' \"\$out\" | jq -e '.ok==false and (.detail|test(\"UNKNOWN\"))'"
check 'run leaves no extra worktree behind' "[ \"\$(git -C '$cand' worktree list | wc -l)\" -eq 1 ]"
check 'run refuses a short SHA' "! '$cand/bin/ai-release-live-check' run --target-head abc"

# verify: fake gh returns the statuses in $TMP/statuses.json.
mkdir -p "$TMP/fake"
printf '#!/usr/bin/env bash\ncat %q\n' "$TMP/statuses.json" > "$TMP/fake/gh"; chmod +x "$TMP/fake/gh"
st() { # LINUX_STATE WINDOWS_STATE [LOGIN]
  jq -n --arg l "$1" --arg w "$2" --arg u "${3:-u2giants}" '[
    {context:"ai-devops/live-review/linux",state:$l,created_at:"2026-10-19T02:00:00Z",creator:{login:$u}},
    {context:"ai-devops/live-review/windows",state:$w,created_at:"2026-10-19T02:00:00Z",creator:{login:$u}}]' > "$TMP/statuses.json"
}
v() { PATH="$TMP/fake:$PATH" "$ROOT/bin/ai-release-live-check" verify --target-head "$head"; }
st success success; check 'verify passes with both OSes green' v
st success failure; check 'verify fails when Windows failed' '! v'
echo '[]' > "$TMP/statuses.json"; check 'verify fails with no statuses' '! v'
st success success intruder; check 'verify ignores statuses by another login' '! v'
st success success
jq '. + [{context:"ai-devops/live-review/windows",state:"failure",created_at:"2026-10-19T03:00:00Z",creator:{login:"u2giants"}}]' \
  "$TMP/statuses.json" > "$TMP/s2" && mv "$TMP/s2" "$TMP/statuses.json"
check 'a newer failure overrides an older success' '! v'

echo "release-live-check: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
