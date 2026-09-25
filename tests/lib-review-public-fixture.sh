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
mock_dir="$(cd "$(dirname "$0")" && pwd -P)" || exit 2
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

# Like ai_test_public_sources, but the mock answers `explain` from the
# repository's own .ai-devops/task-gates.json instead of answering public for
# everything: suites whose fixtures must CLASSIFY as private (the sealed
# code-only route) need that distinction, while CI runners have no installed
# engine on PATH to provide it. The strongest declared path class wins, mirroring
# the engine's local-declaration semantics; a repository with no declaration is
# public code. This mock answers only explain, only inside the fixture root —
# the real engine keeps every other caller, including every gate check.
ai_test_declared_sources() {
  local fixture_root="$1" mock_dir
  [ -d "$fixture_root" ] || return 2
  fixture_root="$(cd "$fixture_root" && pwd -P)" || return 2
  mock_dir="$fixture_root/declared-identity-bin"
  mkdir -p "$mock_dir" || return 2
  cat > "$mock_dir/ai-task-gates" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[ "${1:-}" = explain ] || exit 2
mock_dir="$(cd "$(dirname "$0")" && pwd -P)" || exit 2
[ "${mock_dir##*/}" = declared-identity-bin ] || exit 2
fixture_root="$(cd "$mock_dir/.." && pwd -P)" || exit 2
repo="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 2
repo="$(cd "$repo" && pwd -P)" || exit 2
case "$repo/" in
  "$fixture_root/"*) ;;
  *) exit 2 ;;
esac
class="code"
if [ -f "$repo/.ai-devops/task-gates.json" ] && jq -e . "$repo/.ai-devops/task-gates.json" >/dev/null 2>&1; then
  cr=$'\r'
  while IFS= read -r declared; do
    declared="${declared%"$cr"}"
    [ -n "$declared" ] || continue
    case "$declared:$class" in
      private-evidence:*) class="private-evidence" ;;
      private-tooling:code|private-tooling:prose) class="private-tooling" ;;
    esac
  done < <(jq -r '.paths[]?.class // empty' "$repo/.ai-devops/task-gates.json" 2>/dev/null)
fi
printf '{"identity_resolved":true,"effective_class":"%s","observed_class":"%s"}\n' "$class" "$class"
MOCK
  chmod +x "$mock_dir/ai-task-gates" || return 2
  PATH="$mock_dir:$PATH"
  export PATH
}
