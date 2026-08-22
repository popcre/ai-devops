#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"; ETC="$TMP/etc-ai-devops"; BIN="$TMP/bin"; ARCH="$TMP/archive"
mkdir -p "$REPO/bin" "$ETC" "$BIN"
cp "$ROOT/bin/ai-devops" "$REPO/bin/ai-devops"; chmod +x "$REPO/bin/ai-devops"
ln -s "$REPO/bin/ai-devops" "$BIN/ai-devops"
ln -s "$REPO/bin/ai-devops" "$BIN/foreign"
if [ ! -L "$BIN/ai-devops" ]; then
  echo 'SKIP: platform does not provide real test symlinks'
  exit 0
fi
printf 'config\n' > "$ETC/models.env"
hash="$(sha256sum "$REPO/bin/ai-devops" | cut -d' ' -f1)"
printf 'symlink\t%s\t%s\t%s\n' "$BIN/ai-devops" "$REPO/bin/ai-devops" "$hash" > "$ETC/install-manifest.tsv"

args=(--repo-root "$REPO" --config-dir "$ETC" --bin-target "$BIN" --archive-root "$ARCH")
bash "$ROOT/uninstall.sh" --dry-run "${args[@]}" >/dev/null
[ -L "$BIN/ai-devops" ] || { echo 'FAIL: dry run removed symlink'; exit 1; }
bash "$ROOT/uninstall.sh" "${args[@]}" >/dev/null
[ ! -e "$BIN/ai-devops" ] || { echo 'FAIL: minimal did not remove owned symlink'; exit 1; }
[ -L "$BIN/foreign" ] || { echo 'FAIL: minimal removed foreign symlink'; exit 1; }
[ -d "$ETC" ] || { echo 'FAIL: minimal removed config'; exit 1; }

ln -s "$REPO/bin/ai-devops" "$BIN/ai-devops"
bash "$ROOT/uninstall.sh" --purge "${args[@]}" >/dev/null
[ ! -e "$ETC" ] || { echo 'FAIL: purge kept config'; exit 1; }
archive_file="$(find "$ARCH" -name etc-ai-devops.tar.gz -print -quit)"
[ -n "$archive_file" ] && tar -tzf "$archive_file" >/dev/null || { echo 'FAIL: config archive invalid'; exit 1; }

if bash "$ROOT/uninstall.sh" --dry-run --config-dir / --repo-root "$REPO" --bin-target "$BIN" --archive-root "$ARCH" >/dev/null 2>&1; then
  echo 'FAIL: unsafe broad config target accepted'; exit 1
fi
echo 'PASS: uninstall previews exact ownership, preserves foreign state, archives config, and rejects broad targets'
