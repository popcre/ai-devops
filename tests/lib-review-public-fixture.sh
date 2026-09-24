#!/usr/bin/env bash
# Give offline reviewer fixtures an explicit public identity. This is sourced
# only by test suites; the mock refuses any Git checkout outside their temp root.

ai_test_public_sources() {
  local fixture_root="$1" mock_dir
  [ -d "$fixture_root" ] || return 2
  fixture_root="$(cd "$fixture_root" && pwd -P)" || return 2
  mock_dir="$fixture_root/public-identity-bin"
  mkdir -p "$mock_dir" || return 2
  cat > "$mock_dir/ai-task-gates" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[ "${1:-}" = explain ] || exit 2
mock_path="$(command -v ai-task-gates)" || exit 2
mock_dir="$(cd "$(dirname "$mock_path")" && pwd -P)" || exit 2
[ "${mock_dir##*/}" = public-identity-bin ] || exit 2
fixture_root="$(cd "$mock_dir/.." && pwd -P)" || exit 2
repo="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 2
repo="$(cd "$repo" && pwd -P)" || exit 2
case "$repo/" in
  "$fixture_root/"*)
    printf '{"identity_resolved":true,"effective_class":"code","observed_class":"code"}\n'
    ;;
  *) exit 2 ;;
esac
MOCK
  chmod +x "$mock_dir/ai-task-gates" || return 2
  PATH="$mock_dir:$PATH"
  export PATH
}
