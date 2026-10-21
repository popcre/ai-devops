#!/usr/bin/env bash
# Offline tests for bin/ai-render-globals (#1881 phase 3.1): the committed
# ZCode and MiMo globals are exactly the rendered Codex body, they differ from
# it only in the override lines, a hand edit fails, and CRLF input renders the
# same bytes.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }

echo "1/4 committed renderings match the Codex body"
bash "$REPO_ROOT/bin/ai-render-globals" --check >/dev/null \
  || fail "committed ZCode/MiMo globals drifted from the rendered Codex body"

echo "2/4 renderings differ from the body only in the override lines"
sys="$REPO_ROOT/templates/system"
for engine in zcode mimo; do
  changed="$(diff <(tr -d '\r' < "$sys/AGENTS-global-codex.md") \
    <(tr -d '\r' < "$sys/AGENTS-global-$engine.md") | grep -c '^>' || true)"
  overrides="$(grep -c '^s' "$sys/global-overrides/$engine.sed")"
  appended=0
  [[ -f "$sys/global-overrides/$engine.append" ]] \
    && appended="$(wc -l < "$sys/global-overrides/$engine.append")"
  [[ "$changed" -le $((overrides + appended)) ]] \
    || fail "$engine rendering changes $changed lines; overrides allow $((overrides + appended))"
done

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin"
cp "$REPO_ROOT/bin/ai-render-globals" "$fixture/bin/"
cp -R "$REPO_ROOT/templates" "$fixture/templates"

echo "3/4 a hand edit to a rendered file fails the check"
printf '\nhand edit\n' >> "$fixture/templates/system/AGENTS-global-mimo.md"
! bash "$fixture/bin/ai-render-globals" --check >/dev/null 2>&1 \
  || fail "a hand edit to the MiMo global passed the check"

echo "4/4 a CRLF checkout renders and checks the same bytes"
for f in "$fixture"/templates/system/AGENTS-global-*.md "$fixture"/templates/system/global-overrides/*; do
  sed -i 's/\r\{0,1\}$/\r/' "$f"
done
bash "$fixture/bin/ai-render-globals" >/dev/null
cmp -s "$fixture/templates/system/AGENTS-global-zcode.md" "$sys/AGENTS-global-zcode.md" \
  || fail "CRLF input rendered different ZCode bytes"
cmp -s "$fixture/templates/system/AGENTS-global-mimo.md" "$sys/AGENTS-global-mimo.md" \
  || fail "CRLF input rendered different MiMo bytes"
bash "$fixture/bin/ai-render-globals" --check >/dev/null || fail "CRLF checkout failed the check"

echo "PASS: ai-render-globals keeps ZCode and MiMo one body plus overrides"
