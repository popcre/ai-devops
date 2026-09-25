#!/usr/bin/env bash
# Local suite selection for tests/test-all.sh (issues #163, #805).
#
# Two layers share this file:
#   - Coarse categories (issue #163) for the legacy --changed-since view.
#   - Affected-suite mapping (issue #805) that narrows a pull request to the
#     suites a change can break. The mapping is fail-closed: an unknown path,
#     a missing manifest, or a tool with no dedicated suite selects every
#     available suite rather than silently dropping coverage.
#
# Convention: bin/<name> and bin/<name>.cmd map to tests/test-<name>.sh.
# Explicit path_suites entries cover non-obvious names. Shared surfaces
# (selector itself, harness, workflow runner, fixtures) select everything.
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

# ---------------------------------------------------------------------------
# Affected-suite mapping (issue #805)
# ---------------------------------------------------------------------------

# selection_path_is_prose <path>
# True when the path can never affect a Bash suite by itself. Skills and other
# executable markdown are not prose: they can change client behavior.
selection_path_is_prose() {
  case "$1" in
    README.md|AGENTS.md|bugs.md|plan_*.md|HANDOFF.d/*.md|docs/*|tests/verification/*)
      return 0 ;;
    *.md)
      # Other markdown outside skills/ and templates/ is still documentation.
      case "$1" in
        skills/*|templates/*) return 1 ;;
        *) return 0 ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

# selection_glob_match <glob> <path>
# Shell-glob match where ** crosses directories and * does not.
selection_glob_match() {
  local glob="$1" path="$2"
  case "$glob" in
    *'**'*)
      local prefix="${glob%%\*\**}" prefix_path
      prefix="${prefix%/}"
      if [ -z "$prefix" ]; then return 0; fi
      case "$path" in "$prefix"|"$prefix"/*) return 0 ;; esac
      return 1 ;;
  esac
  # shellcheck disable=SC2254
  case "$path" in
    $glob) return 0 ;;
  esac
  return 1
}

# selection_manifest_rule <root> <json-pointer-like-kind>
# Reads the affected_suite_rules block from the suite manifest.
# Prints nothing and returns 1 when the block is absent (caller falls back).
selection_manifest_rules() {
  local root="$1"
  local manifest="${AI_CI_SUITE_MANIFEST:-$root/config/ci-suite-manifest.json}"
  [ -f "$manifest" ] || return 1
  jq -e '.affected_suite_rules | type == "object"' "$manifest" >/dev/null 2>&1 || return 1
  cat "$manifest"
}

# selection_affected_suites <root>
# Reads newline-delimited changed paths on stdin. The remaining arguments are
# the available suite file names. Prints the selected suites, one per line,
# sorted and deduplicated. Prints every available suite when the change is too
# broad or too unknown to narrow safely. Prints nothing when the change cannot
# affect any Bash suite.
selection_affected_suites() {
  local root="$1"; shift
  local -a available=("$@")
  local -A avail_set=()
  local name path suite base
  for name in "${available[@]}"; do
    avail_set["$name"]=1
  done

  local paths rules
  paths="$(cat)"
  rules="$(selection_manifest_rules "$root" || true)"

  local select_all=false
  local -A selected=()

  add_suite() {
    local s="$1"
    [ -n "$s" ] || return 0
    if [ -n "${avail_set[$s]:-}" ]; then
      selected["$s"]=1
    fi
  }

  add_skills() {
    local pattern
    for pattern in $SELECTION_SKILLS_PATTERNS; do
      for name in "${available[@]}"; do
        case "$name" in *"$pattern"*) selected["$name"]=1 ;; esac
      done
    done
  }

  add_workflow() {
    local pattern
    for pattern in $SELECTION_WORKFLOW_PATTERNS; do
      for name in "${available[@]}"; do
        case "$name" in *"$pattern"*) selected["$name"]=1 ;; esac
      done
    done
  }

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if selection_path_is_prose "$path"; then
      continue
    fi

    # Explicit path -> suites map wins over broader globs so a named leaf
    # (e.g. tools/ci/runner-router.cjs) can stay narrow inside a shared tree.
    if [ -n "$rules" ]; then
      local mapped=''
      mapped="$(jq -r --arg p "$path" '.affected_suite_rules.path_suites[$p][]? // empty' <<<"$rules" 2>/dev/null)"
      if [ -n "$mapped" ]; then
        local added=0
        while IFS= read -r suite; do
          [ -n "$suite" ] || continue
          if [ -n "${avail_set[$suite]:-}" ]; then
            add_suite "$suite"
            added=$((added + 1))
          fi
        done <<<"$mapped"
        # A declared mapping that names no discovered suite cannot prove cover.
        [ "$added" -gt 0 ] || select_all=true
        [ "$select_all" = true ] && continue
        # Companion suites (e.g. every bin/*.cmd also proves the launcher).
        while IFS= read -r glob; do
          [ -n "$glob" ] || continue
          if selection_glob_match "$glob" "$path"; then
            while IFS= read -r suite; do
              [ -n "$suite" ] && add_suite "$suite"
            done < <(jq -r --arg g "$glob" '.affected_suite_rules.companion_suites[$g][]? // empty' <<<"$rules" 2>/dev/null)
          fi
        done < <(jq -r '.affected_suite_rules.companion_suites | keys[]?' <<<"$rules" 2>/dev/null)
        continue
      fi

      # Shared surfaces whose change must keep every suite.
      local glob
      while IFS= read -r glob; do
        [ -n "$glob" ] || continue
        if selection_glob_match "$glob" "$path"; then
          select_all=true
          break
        fi
      done < <(jq -r '.affected_suite_rules.select_all_globs[]? // empty' <<<"$rules" 2>/dev/null)
      [ "$select_all" = true ] && continue
    fi

    case "$path" in
      skills/*)
        add_skills
        continue
        ;;
      .github/workflows/*)
        add_workflow
        continue
        ;;
      *.ps1|*.psm1|*.psd1)
        # PowerShell has its own runner; Bash suites are not the cover.
        continue
        ;;
      tests/test-*.sh)
        base="${path##*/}"
        if [ -n "${avail_set[$base]:-}" ]; then
          add_suite "$base"
          # A test of the selector itself pulls the selector contracts.
          case "$base" in
            test-test-selection.sh|test-windows-bash-selection.sh|test-linux-offline-shards.sh)
              add_suite "test-verify-closure.sh"
              add_suite "test-workflow-policy.sh"
              ;;
          esac
          continue
        fi
        # A removed or renamed suite cannot be assumed covered by nothing.
        select_all=true
        continue
        ;;
      bin/*.cmd)
        base="${path##*/}"; base="${base%.cmd}"
        if [ -n "${avail_set[test-$base.sh]:-}" ]; then
          add_suite "test-$base.sh"
        else
          select_all=true
        fi
        add_suite "test-bin-cmd-launchers.sh"
        continue
        ;;
      bin/*)
        base="${path##*/}"
        if [ -n "${avail_set[test-$base.sh]:-}" ]; then
          add_suite "test-$base.sh"
          continue
        fi
        # Convention miss: do not invent coverage.
        select_all=true
        continue
        ;;
      *)
        select_all=true
        continue
        ;;
    esac
  done <<<"$paths"

  if [ "$select_all" = true ]; then
    printf '%s\n' "${available[@]}" | LC_ALL=C sort
    return 0
  fi
  if [ "${#selected[@]}" -eq 0 ]; then
    return 0
  fi
  printf '%s\n' "${!selected[@]}" | LC_ALL=C sort
}
