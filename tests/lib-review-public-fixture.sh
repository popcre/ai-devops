#!/usr/bin/env bash
# Give offline reviewer fixtures an explicit public identity. This is sourced
# only by test suites; the mock refuses any Git checkout outside their temp root.

ai_test_public_sources() {
  local fixture_root="$1" mock_dir
  [ -d "$fixture_root" ] || return 2
  AI_REVIEW_TEST_PUBLIC_ROOT="$(cd "$fixture_root" && pwd -P)" || return 2
  export AI_REVIEW_TEST_PUBLIC_ROOT
  mock_dir="$AI_REVIEW_TEST_PUBLIC_ROOT/public-identity-bin"
  mkdir -p "$mock_dir" || return 2
  cat > "$mock_dir/ai-task-gates" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[ "${1:-}" = explain ] || exit 2
[ -n "${AI_REVIEW_TEST_PUBLIC_ROOT:-}" ] || exit 2
repo="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 2
repo="$(cd "$repo" && pwd -P)" || exit 2
case "$repo/" in
  "$AI_REVIEW_TEST_PUBLIC_ROOT/"*)
    printf '{"identity_resolved":true,"effective_class":"code","observed_class":"code"}\n'
    ;;
  *) exit 2 ;;
esac
MOCK
  chmod +x "$mock_dir/ai-task-gates" || return 2
  PATH="$mock_dir:$PATH"
  export PATH
}
