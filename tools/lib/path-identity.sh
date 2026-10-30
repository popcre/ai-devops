# shellcheck shell=bash
# path-identity.sh - the one shell answer to "are these two paths the same place?"
#
# Never compare file-system paths as raw strings (#1835): native Windows Git,
# jq and Python print C:/... (often CRLF-terminated) for a Git Bash /tmp or /c/
# path. Source this file and use ai_same_path, or match a fixed fixture suffix
# when only fixture identity matters.
#
# Canonical form: one trailing CR stripped; then `cygpath -am`, lower-cased
# (Git Bash: NTFS is case-insensitive), or `realpath -m` elsewhere (symlinks and
# . / .. resolved; the path need not exist). Runtime-safe: no output, no exit.

ai_path_canonical() { # ai_path_canonical PATH -> canonical spelling on stdout
  local p="${1%$'\r'}"
  [ -n "$p" ] || return 1
  if command -v cygpath >/dev/null 2>&1; then
    # -l expands 8.3 short names (RUNNER~1 vs runneradmin): native Windows
    # tools often print the short form of a %TEMP% path. -l needs the path
    # to exist, so fall back to the plain absolute form.
    p="$(cygpath -aml -- "$p" 2>/dev/null || cygpath -am -- "$p" 2>/dev/null)" || return 1
    printf '%s\n' "$p" | tr '[:upper:]' '[:lower:]'
  else
    realpath -m -- "$p" 2>/dev/null
  fi
}

ai_same_path() { # ai_same_path A B -> 0 when both name the same place
  local a b
  a="$(ai_path_canonical "$1")" && b="$(ai_path_canonical "$2")" || return 1
  [ -n "$a" ] && [ -n "$b" ] && [ "$a" = "$b" ]
}

ai_git_toplevel() { # ai_git_toplevel DIR -> 0 when DIR is the repository top level
  local dir="$1" top
  [ -n "$dir" ] && [ -d "$dir" ] || return 1
  dir="$(cd "$dir" && pwd -P)" || return 1
  top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || return 1
  [ -n "$top" ] || return 1
  ai_same_path "$dir" "$top"
}
