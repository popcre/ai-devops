#!/usr/bin/env bash
# Coarse local suite selection for tests/test-all.sh (issue #163).
#
# Selection is deliberately coarse. It reuses tools/ci/classify-changes.sh as
# the single source of truth for the prose bypass, then maps changed paths onto
# a small set of documented categories. It is NOT a per-suite dependency graph:
# anything that touches other executable surface selects every Bash suite.
set -uo pipefail

# Categories, in the order they are reported:
#   prose       documentation and plans only          -> no Bash suites
#   skills      skills/ only                          -> skills-facing suites
#   workflow    .github/workflows/ only               -> workflow-policy suites
#   powershell  *.ps1/*.psm1/*.psd1 only              -> no Bash suites
#   code        anything else (bin/, tools/, tests/,  -> every Bash suite
#               templates/, installers, fixtures)

# Suite patterns per narrow category. Substring match on the suite file name.
SELECTION_SKILLS_PATTERNS='skill globals install-skills markdown-links'
SELECTION_WORKFLOW_PATTERNS='workflow-policy runner-qualification-workflow markdown-links'

# selection_filter <pattern> <suite>...
# Prints suites whose name contains <pattern>.
selection_filter() {
  local pattern="$1"; shift
  local suite
  for suite in "$@"; do
    case "$suite" in *"$pattern"*) printf '%s\n' "$suite" ;; esac
  done
}

# selection_by_categories "<categories>" <suite>...
# Prints the selected suites, one per line, deduplicated and sorted.
selection_by_categories() {
  local categories="$1"; shift
  local cat pattern
  {
    for cat in $categories; do
      case "$cat" in
        code)
          printf '%s\n' "$@"
          ;;
        skills)
          for pattern in $SELECTION_SKILLS_PATTERNS; do selection_filter "$pattern" "$@"; done
          ;;
        workflow)
          for pattern in $SELECTION_WORKFLOW_PATTERNS; do selection_filter "$pattern" "$@"; done
          ;;
        prose|powershell)
          ;;
      esac
    done
  } | LC_ALL=C sort -u
}

# selection_categories_for_paths <root>
# Reads newline-delimited changed paths on stdin, prints the space-separated
# category list. Uses classify-changes.sh for the prose decision.
selection_categories_for_paths() {
  local root="$1"
  local paths classify prose skills workflow powershell code path out
  paths="$(cat)"
  classify="$(printf '%s\n' "$paths" | bash "$root/tools/ci/classify-changes.sh" pull_request)" || return 1
  prose="$(printf '%s\n' "$classify" | sed -n 's/^prose_only=//p')"
  skills="$(printf '%s\n' "$classify" | sed -n 's/^skills=//p')"
  workflow="$(printf '%s\n' "$classify" | sed -n 's/^workflow=//p')"
  powershell="$(printf '%s\n' "$classify" | sed -n 's/^powershell=//p')"

  if [ "$prose" = true ]; then printf 'prose\n'; return 0; fi

  # A path is "other code" when it is none of skills/, a workflow, PowerShell,
  # or a prose file. Only then does the whole Bash suite become relevant.
  code=false
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in
      skills/*|.github/workflows/*|*.ps1|*.psm1|*.psd1) continue ;;
      README.md|AGENTS.md|bugs.md|plan_*.md|HANDOFF.d/*.md|docs/*|tests/verification/*) continue ;;
      *) code=true ;;
    esac
  done <<< "$paths"

  out=''
  [ "$skills" = true ] && out="$out skills"
  [ "$workflow" = true ] && out="$out workflow"
  [ "$powershell" = true ] && out="$out powershell"
  [ "$code" = true ] && out="$out code"
  printf '%s\n' "${out# }"
}
