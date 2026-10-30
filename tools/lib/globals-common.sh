# shellcheck shell=bash
# Shared helpers for installed global instruction files (~/.claude/CLAUDE.md,
# ~/.codex/AGENTS.md, ...). Sourced by bin/ai-install-skills and
# bin/ai-adopt-globals. Callers set SHORT_HOST (lower-case short hostname).

# Drop trailing blank lines, then a trailing horizontal rule, then blanks again.
# The "\n---\n\n" separator written before a machine section is ours, not the
# template's, so it must not count as a difference.
trim_tail() {
  awk '{ lines[NR] = $0 } END {
    last = NR
    while (last > 0 && lines[last] ~ /^[[:space:]]*$/) last--
    if (last > 0 && lines[last] ~ /^-{3,}[[:space:]]*$/) {
      last--
      while (last > 0 && lines[last] ~ /^[[:space:]]*$/) last--
    }
    for (i = 1; i <= last; i++) print lines[i]
  }'
}

# Print the 1-based line number where this file's machine section starts, or
# nothing at all if there is no machine section.
#
# Real headings in use across the machines, all of which must match:
#   ## al8960ofc — Windows 11 dev machine (machine-specific; not from the hub template)
#   # Machine facts — al8960ofc (Windows 11 dev box)
#   # Machine atlas — this machine (t16 / `albt16`)
#   # Machine atlas - 916 ("916-alien") and t16 and 4837 - Windows 11 dev machines
#   # Local standing addition retained from previous AGENTS.md
# Note the last two: neither contains this machine's own hostname, so hostname
# matching alone silently reports "no machine section" on a file that has one.
find_section_start() {
  local file=$1
  awk -v host="${SHORT_HOST:-}" '
    /^#{1,6} / {
      line = tolower($0)
      if ((host != "" && index(line, host) > 0) ||
          index(line, "machine-specific") > 0 ||
          index(line, "machine facts") > 0 ||
          index(line, "machine atlas") > 0 ||
          index(line, "local standing addition") > 0) { print NR; exit }
    }
  ' "$file"
}

# global_body INSTALLED -> the installed global without its machine section,
# CRs removed and tail trimmed (the part that came from a repo template).
global_body() {
  local installed=$1 start
  start="$(find_section_start "$installed")"
  if [[ -n "$start" ]]; then
    head -n "$((start - 1))" "$installed" | tr -d '\r' | trim_tail
  else
    tr -d '\r' < "$installed" | trim_tail
  fi
}

# global_template_version REPO TEMPLATE_REL INSTALLED -> 0 when the installed
# body equals some committed version of the template (the current one or any
# earlier one), i.e. nobody edited it locally. Nonzero when it differs from
# every committed version, or when Git history is unavailable (fail safe: an
# unprovable copy is treated as locally edited and left alone).
global_template_version() {
  local repo=$1 rel=$2 installed=$3 body_hash blob
  command -v git >/dev/null 2>&1 || return 1
  body_hash="$(global_body "$installed" | git hash-object --stdin 2>/dev/null)" || return 1
  [[ -n "$body_hash" ]] || return 1
  while IFS= read -r blob; do
    [[ -n "$blob" ]] || continue
    [[ "$blob" == "$body_hash" ]] && return 0
    [[ "$(git -C "$repo" cat-file blob "$blob" 2>/dev/null | tr -d '\r' | trim_tail | git hash-object --stdin)" == "$body_hash" ]] && return 0
  done < <(git -C "$repo" log --no-abbrev --raw --format= -- "$rel" 2>/dev/null \
             | awk '$4 !~ /^0+$/ { print $4 }' | awk '!seen[$0]++')
  return 1
}

# global_refresh_unmodified REPO SRC DST LABEL [DRY_RUN=false]
# Refresh an installed global that nobody edited locally. Exit codes:
#   0 refreshed (old copy backed up to <dir>/globals-backup/, machine section
#     kept byte for byte), 3 already current, 1 a real local edit or an
#     unprovable copy (left untouched), 2 refresh failed (previous file restored).
global_refresh_unmodified() {
  local repo=$1 src=$2 dst=$3 label=$4 dry=${5:-false} rel start section="" backup
  rel="${src#"$repo"/}"; rel="${rel//\\//}"
  global_template_version "$repo" "$rel" "$dst" || return 1
  if cmp -s <(tr -d '\r' < "$src" | trim_tail) <(global_body "$dst"); then
    echo "$label already up to date (machine section kept)."
    return 3
  fi
  backup="$(dirname "$dst")/globals-backup/$(basename "$dst")"
  echo "$dst is an unmodified older template version — refreshing it."
  if [[ "$dry" == true ]]; then
    echo "    [dry-run] would back up to $backup and keep the machine section."
    return 0
  fi
  { mkdir -p "$(dirname "$backup")" && cp "$dst" "$backup"; } || return 2
  start="$(find_section_start "$dst")"
  if [[ -n "$start" ]]; then
    section="$(mktemp)" || return 2
    sed -n "${start},\$p" "$dst" > "$section" || { rm -f "$section"; return 2; }
    if ! { { cat "$src" && printf '\n---\n\n' && cat "$section"; } > "$dst.ai-devops-new" && mv "$dst.ai-devops-new" "$dst"; }; then
      rm -f "$section" "$dst.ai-devops-new"
      echo "ERROR: $label refresh failed; previous file kept in $backup." >&2
      return 2
    fi
    start="$(find_section_start "$dst")"
    if [[ -z "$start" ]] || ! cmp -s "$section" <(sed -n "${start},\$p" "$dst"); then
      cp "$backup" "$dst"; rm -f "$section"
      echo "ERROR: $label machine section changed during refresh; restored the previous file." >&2
      return 2
    fi
    rm -f "$section"
  else
    cp "$src" "$dst" || { cp "$backup" "$dst"; return 2; }
  fi
  echo "    machine section kept; previous copy in $backup"
  return 0
}

# Direct entrypoint for the Windows installer (Git Bash), which cannot source:
#   bash tools/lib/globals-common.sh refresh REPO SRC DST LABEL [DRY_RUN]
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    refresh)
      shift
      SHORT_HOST="$(hostname 2>/dev/null | cut -d. -f1 | tr '[:upper:]' '[:lower:]')"
      global_refresh_unmodified "$@"; exit $? ;;
    *) echo "usage: globals-common.sh refresh REPO SRC DST LABEL [DRY_RUN]" >&2; exit 2 ;;
  esac
fi
