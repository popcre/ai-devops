#!/usr/bin/env bash
# Step 5.2: doctor reports the installed-tools lag behind origin/main.
# Report only — lag never fails the check, and a diverged install is named,
# never counted as zero.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# A tiny repo whose origin/main advances three commits past the install point.
git init -q "$TMP/repo"
git -C "$TMP/repo" config user.name 'Test User'
git -C "$TMP/repo" config user.email 'test@example.com'
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

# Windows has only CRLF shims, without an Ubuntu manifest.
rm "$TMP/manifest.tsv"
out="$(report_install_lag "$TMP/repo" "$TMP/bin" "$TMP/manifest.tsv" 2>&1)"
case "$out" in
  *"are 2 commits behind origin/main ${main_sha:0:10}"*) ;;
  *) echo 'FAIL: expected lag from CRLF shims alone' >&2; exit 1 ;;
esac

# Up-to-date case: shims at main, still without a manifest.
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
  *"are 1 commits ahead of origin/main"*) ;;
  *) echo 'FAIL: expected the ahead-of-main warning' >&2; exit 1 ;;
esac

# Diverged install: one unique commit branching from the install point.
other_sha="$(git -C "$TMP/repo" commit-tree "$(git -C "$TMP/repo" rev-parse main^{tree})" -p "$installed_sha" -m diverged)"
mkdir -p "$TMP/empty-bin"
printf 'meta\tsource_sha\t%s\t-\n' "$other_sha" > "$TMP/manifest.tsv"
out="$(report_install_lag "$TMP/repo" "$TMP/empty-bin" "$TMP/manifest.tsv" 2>&1)"
case "$out" in
  *"have diverged from origin/main (2 commits behind, 1 commits ahead)"*) ;;
  *) echo 'FAIL: expected divergence from manifest alone' >&2; exit 1 ;;
esac

printf 'meta\tsource_sha\t%s\t-\n' '1111111111111111111111111111111111111111' > "$TMP/manifest.tsv"
out="$(report_install_lag "$TMP/repo" "$TMP/empty-bin" "$TMP/manifest.tsv" 2>&1)"
case "$out" in
  *"install lag unknown: installed SHA 1111111111 is unavailable"*) ;;
  *) echo 'FAIL: expected unknown lag for an unavailable SHA' >&2; exit 1 ;;
esac

out="$(report_install_lag "$TMP/missing-repo" "$TMP/bin" "$TMP/manifest.tsv" 2>&1)"
case "$out" in
  *fatal:*) echo 'FAIL: missing repository must not print Git errors' >&2; exit 1 ;;
  *"install lag unknown: no origin/main"*) ;;
  *) echo 'FAIL: expected missing-repository warning' >&2; exit 1 ;;
esac
[ "$FAILED" -eq 0 ] || { echo 'FAIL: lag must remain report-only' >&2; exit 1; }

echo 'PASS: install lag reported for CRLF shims, manifests, behind, current, ahead, diverged and unknown installs'
