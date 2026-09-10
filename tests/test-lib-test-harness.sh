#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/fixture.sh" <<'EOF'
#!/usr/bin/env bash
set -u
PASS=0; FAIL=0; SKIP=0
. "$HARNESS"
check 'successful command is counted' 'true'
check 'injected command failure is counted' 'false'
skip 'unsupported fixture'
[ "$PASS" -eq 1 ] && [ "$FAIL" -eq 0 ]
EOF

if AI_TEST_SUITE=fixture AI_TEST_REPORT_FILE="$TMP/report.tsv" \
  HARNESS="$ROOT/tests/lib-test-harness.sh" bash "$TMP/fixture.sh" > "$TMP/out"; then
  printf 'FAIL: injected command failure returned success\n' >&2
  exit 1
fi
grep -q '^  FAIL injected command failure is counted$' "$TMP/out"
printf 'fixture\tpass\tsuccessful command is counted\nfixture\tfail\tinjected command failure is counted\nfixture\tskip\tunsupported fixture\n' > "$TMP/expected.tsv"
cmp -s "$TMP/expected.tsv" "$TMP/report.tsv"
printf 'PASS: shared harness preserves counters and emits exact TSV identities\n'
