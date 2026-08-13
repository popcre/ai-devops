#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
catalog=""
target_dir="/usr/local/bin"
while (($#)); do
  case "$1" in
    --repo-root) repo_root="$2"; shift 2 ;;
    --catalog) catalog="$2"; shift 2 ;;
    --target-dir) target_dir="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
catalog="${catalog:-$repo_root/config/machine-tools.tsv}"
mkdir -p "$target_dir"
failed=0
while IFS=$'\t' read -r name source winform ubuntu provider owner; do
  [[ -z "${name:-}" || "$name" == \#* || "$ubuntu" != yes ]] && continue
  src="$repo_root/$source"; dst="$target_dir/$name"
  [[ -f "$src" ]] || { echo "ERROR missing wrapper source: $src" >&2; failed=1; continue; }
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    if cmp -s "$dst" "$src"; then rm -f "$dst"; else
      echo "ERROR refusing to replace unrelated file: $dst" >&2; failed=1; continue
    fi
  fi
  if [[ -L "$dst" ]]; then
    current="$(readlink "$dst")"
    if [[ "$current" != "$src" && "$current" != "$repo_root"/* ]]; then
      echo "ERROR refusing to replace unrelated link: $dst -> $current" >&2; failed=1; continue
    fi
  fi
  ln -sfn "$src" "$dst"
  echo "OK installed $name"
done < "$catalog"
exit "$failed"
