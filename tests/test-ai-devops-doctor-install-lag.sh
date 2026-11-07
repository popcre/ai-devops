#!/usr/bin/env bash
# Step 5.2: doctor reports the installed-tools lag behind origin/main.
# Report only — lag never fails the check, and a diverged install is named,
# never counted as zero.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# A tiny repo whose origin/main advances three commits past the install point.
# CI runners have no global git identity; the fixture must carry its own.
git init -q "$TMP/repo"
git -C "$TMP/repo" config user.email fixture@example.invalid
git -C "$TMP/repo" config user.name fixture
git -C "$TMP/repo" commit -q --allow-empty -m one
installed_sha="$(git -C "$TMP/repo" rev-parse HEAD)"
git -C "$TMP/repo" commit -q --allow-empty -m two
git -C "$TMP/repo" commit -q --allow-empty -m three
git -C "$TMP/repo" branch -q main
git -C "$TMP/repo" update-ref refs/remotes/origin/main main
main_sha="$(git -C "$TMP/repo" rev-parse main)"

# Windows-style shims carrying source-sha receipts + an Ubuntu-style manifest.
mkdir -p "$TMP/bin"
printf '@echo off\r\nrem source-sha=%s\r\n' "$installed_sha" > "$TMP/bin/ai-task-gates.cmd"
printf '@echo off\r\nrem source-sha=%s\r\n' "$installed_sha" > "$TMP/bin/ai-pr-wait.cmd"
printf 'meta\tsource_sha\t%s\t-\n' "$installed_sha" > "$TMP/manifest.tsv"

export AI_DEVOPS_LIB_ONLY=1
source "$ROOT/bin/ai-devops"

out="$(report_install_lag "$TMP/repo" "$TMP/bin" "$TMP/manifest.tsv" 2>&1)"
echo "$out"
case "$out" in
  *"are 2 commits behind origin/main ${main_sha:0:10}"*) ;;
  *) echo 'FAIL: expected the two-commit lag to be reported' >&2; exit 1 ;;
esac
case "$out" in
  *FAIL*) echo 'FAIL: lag report must never fail' >&2; exit 1 ;;
esac

# Up-to-date case: shims at main.
printf '@echo off\r\nrem source-sha=%s\r\n' "$main_sha" > "$TMP/bin/ai-task-gates.cmd"
printf '@echo off\r\nrem source-sha=%s\r\n' "$main_sha" > "$TMP/bin/ai-pr-wait.cmd"
out="$(report_install_lag "$TMP/repo" "$TMP/bin" "$TMP/manifest.tsv" 2>&1)"
case "$out" in
  *"= origin/main (up to date)"*) ;;
  *) echo 'FAIL: expected the up-to-date report' >&2; exit 1 ;;
esac

# Ahead-of-main install: the shim SHA is a child of main, so main is not
# ahead of it and the report must name that instead of "behind".
other_sha="$(git -C "$TMP/repo" commit-tree "$(git -C "$TMP/repo" rev-parse main^{tree})" -p main -m other)"
printf '@echo off\r\nrem source-sha=%s\r\n' "$other_sha" > "$TMP/bin/ai-task-gates.cmd"
printf '@echo off\r\nrem source-sha=%s\r\n' "$other_sha" > "$TMP/bin/ai-pr-wait.cmd"
printf 'meta\tsource_sha\t%s\t-\n' "$other_sha" > "$TMP/manifest.tsv"
out="$(report_install_lag "$TMP/repo" "$TMP/bin" "$TMP/manifest.tsv" 2>&1)"
case "$out" in
  *"ahead of or off origin/main history"*) ;;
  *) echo 'FAIL: expected the ahead-or-off-main warning' >&2; exit 1 ;;
esac

echo 'PASS: install lag reported for behind, current and diverged installs'
