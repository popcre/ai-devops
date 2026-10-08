#!/usr/bin/env bash
# grok.sh — Grok door for the shared review runner.
#
# Provider bits ONLY: binary selection, credentials presence, model pin,
# tool set, and parse to our report shape. This file must NOT own task gate,
# identity, sandbox, packet seal/store, lifecycle terminal, report floor, or
# cleanup. tests/test-ai-review-engine.sh asserts that source purity.
#
# Called by bin/ai-review-engine (never directly) as:
#   bash grok.sh review|implement
# with the runner token and DOOR_* environment contract below.
set -euo pipefail
DOOR_CREDIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$DOOR_CREDIT_ROOT/tools/reviewer_event_guard.sh"
# Owner rule "remove the paid fallback": no grok child inherits a paid key.
source "$DOOR_CREDIT_ROOT/tools/lib/grok-paid-keys.sh"
grok_strip_paid_keys

# ---------------------------------------------------------------------------
# Structural forcing function: a door invoked without the runner token is a
# bypassed review. Refuse it before any provider process starts.
# ---------------------------------------------------------------------------
[ "${AI_REVIEW_RUNNER_CORE:-}" = "review-lifecycle-core/1" ] || {
  printf 'grok door: refusing a review that bypasses the shared runner (AI_REVIEW_RUNNER_CORE).\n' >&2
  exit 2
}

MODE="${1:-${DOOR_MODE:-review}}"
case "$MODE" in review|implement) ;; *) printf 'grok door: usage: grok.sh review|implement\n' >&2; exit 2 ;; esac

: "${DOOR_WORKDIR:?grok door: DOOR_WORKDIR is required}"
: "${DOOR_PACKET_DIR:?grok door: DOOR_PACKET_DIR is required}"
: "${DOOR_PROMPT_FILE:?grok door: DOOR_PROMPT_FILE is required}"
: "${DOOR_REPORT_OUT:?grok door: DOOR_REPORT_OUT is required}"
: "${DOOR_HEAD:?grok door: DOOR_HEAD is required}"

# Model pin and tool set. Frozen on purpose: a stable request prefix is what
# makes prompt caching work, and a fixed permission set is what keeps the
# review boundary explicit. --permission-mode auto / --always-approve are
# deliberately NOT used (bin/ai-grok-review STEP 0 notes).
# The pin comes from config/provider-cli-versions.json (model_pin), the same
# source the installers write into ~/.grok/config.toml allowed_models. A
# hard-coded copy here drifted (grok-4.5 vs the grok-4.6 pin) and Grok refused
# every formal review: "isn't allowed by allowed_models".
grok_model_pin() {
  local here cfg pin=""
  here="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")")" && pwd)"
  cfg="$here/../../../config/provider-cli-versions.json"
  if [ -f "$cfg" ] && command -v jq >/dev/null 2>&1; then
    pin="$(jq -r '.providers.grok.model_pin // empty' "$cfg" 2>/dev/null | tr -d '\r')"
  fi
  printf '%s' "${pin:-grok-4.6}"
}
GROK_MODEL="${AI_GROK_MODEL:-$(grok_model_pin)}"
GROK_MAX_TURNS="${DOOR_MAX_TURNS:-${AI_GROK_MAX_TURNS:-32}}"
GROK_WAIT="${AI_GROK_WAIT_TIMEOUT:-1800}"
# Review is not read-only (issue #974): the model may run commands and edit
# files only inside its disposable copy. Implement uses the same tool set
# against a real remote-less worktree the runner owns.
GROK_PERMS=(--permission-mode default --allow Read --allow Grep
            --allow Edit --allow Write --allow Bash --deny 'MCPTool(*)'
            --no-subagents --disable-web-search --no-memory)

resolve_grok() {
  if [ -n "${AI_GROK_BIN:-}" ] && [ -x "${AI_GROK_BIN}" ]; then
    printf '%s' "$AI_GROK_BIN"; return 0
  fi
  local c
  for c in "$(command -v grok 2>/dev/null || true)" \
           "${HOME:-}/.local/bin/grok" \
           "${HOME:-}/.grok/bin/grok" \
           /home/ai/.local/bin/grok \
           /usr/local/bin/grok; do
    [ -n "$c" ] && [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  done
  printf 'grok door: local_dependency_unavailable: grok binary not found. This is not a Grok provider fault. Set AI_GROK_BIN.\n' >&2
  return 127
}

# Credentials presence only — never print a key. A missing store is a local
# dependency failure, not a provider fault.
require_credentials() {
  # Subscription OAuth login only; a paid XAI_API_KEY never counts.
  if [ -s "${AI_GROK_AUTH_HOME:-${HOME:-}/.grok}/auth.json" ]; then
    return 0
  fi
  if [ "${AI_GROK_ALLOW_NO_CREDS:-0}" = 1 ]; then
    return 0
  fi
  printf 'grok door: no Grok subscription login (auth.json); a paid XAI_API_KEY is never used. Run grok login, or set AI_GROK_ALLOW_NO_CREDS=1 for offline tests.\n' >&2
  return 127
}

# Native path for --cwd on Windows (MSYS conversion is a heuristic, not a
# contract). bin/ai-grok-implement documents the cost of getting this wrong.
native_cwd() {
  local p="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$p" 2>/dev/null || printf '%s' "$p"
  else
    printf '%s' "$p"
  fi
}

# Parse the provider envelope into OUR report shape: findings first, verdict
# last under a literal '## Verdict' heading. Same grammar the pool and
# lifecycle consume.
extract_report() { # extract_report RESULT_JSON DEST HEAD MODE
  local result="$1" dest="$2" head="$3" mode="$4" text stop turns cost model
  text="$(jq -r '.text // ""' "$result" 2>/dev/null || true)"
  stop="$(jq -r '.stopReason // "unknown"' "$result" 2>/dev/null || echo unknown)"
  turns="$(jq -r '.num_turns // "?"' "$result" 2>/dev/null || echo '?')"
  cost="$(jq -r '.total_cost_usd // "unknown"' "$result" 2>/dev/null || echo unknown)"
  model="$(jq -r '(.modelUsage // {} | keys | first) // "unknown"' "$result" 2>/dev/null || echo unknown)"
  case "$stop" in
    end_turn|EndTurn|stop|completed) ;;
    *)
      printf 'grok door: non-terminal stopReason: %s\n' "$stop" >&2
      return 1
      ;;
  esac
  {
    printf '# Grok %s — runner door\n\n' "$mode"
    printf '| field | value |\n|---|---|\n'
    printf '| model | `%s` |\n| stopReason | `%s` |\n| turns | `%s` |\n| cost | `$%s` |\n| reviewed commit | `%s` |\n\n' \
      "$model" "$stop" "$turns" "$cost" "$head"
    printf -- '---\n\n'
    if printf '%s' "$text" | grep -qF '## Verdict'; then
      printf '### Findings and reasoning\n\n'
      printf '%s\n' "$text" | sed -n '1,/^## Verdict/p' | sed '/^## Verdict/d'
      printf '\n---\n\n'
      printf '%s\n' "$text" | sed -n '/^## Verdict/,$p'
    else
      printf '%s\n' "$text"
      printf '\n## Verdict\nBLOCKED\n'
    fi
  } > "$dest"
}

# Grok CLI cancels the WHOLE headless turn (stopReason "cancelled",
# cancellationCategory PermissionCancelled) when a shell command uses a form no
# --allow rule covers: variable assignment, env wrapper, git -c, $(...) or
# backtick substitution, or quoted < > that look like redirection. Same limit
# and same bounded recovery as bin/ai-grok-review: warn up front, then resume
# the same session (permissions unchanged) with a corrective message.
SHELL_RULE="Shell rule (Grok CLI limit): a shell command containing a variable assignment (FOO=1 cmd, export FOO=1), the env wrapper, git -c, \$(...) or backtick substitution, or angle brackets (even inside quotes, e.g. git log --format='<%ae>') is refused, and a refused command CANCELS your turn. Use one plain command per call. When something needs variables or such forms, write a small script under .git/review-scratch/ with your file tool and run: bash .git/review-scratch/run.sh"
GROK_PERMISSION_RESUMES="${AI_GROK_PERMISSION_RESUMES:-3}"

permission_cancelled() { # permission_cancelled RESULT_JSON -> 0 only on ONE native PermissionCancelled witness
  # Bound to this result's sessionId AND requestId (the native prompt_id), as in
  # bin/ai-grok-review: exactly one matching turn_completed line, symlinks
  # refused, whitespace-tolerant JSON. A leftover or other-category cancel
  # (max_turns_reached) never qualifies.
  local result="$1" py
  [ "$(jq -r '.stopReason // ""' "$result" 2>/dev/null)" = cancelled ] || return 1
  for py in python3 python; do command -v "$py" >/dev/null 2>&1 && break; py=""; done
  [ -n "$py" ] || return 1
  "$py" - "$result" "${GROK_HOME:-${HOME:-}/.grok}/sessions" <<'PY'
import json, pathlib, re, sys
try: result = json.loads(pathlib.Path(sys.argv[1]).read_text())
except Exception: sys.exit(1)
sid, req = result.get('sessionId'), result.get('requestId')
ok = lambda v: isinstance(v, str) and re.fullmatch(r'[A-Za-z0-9-]{1,80}', v)
root = pathlib.Path(sys.argv[2])
if not (ok(sid) and ok(req)) or not root.is_dir() or root.is_symlink(): sys.exit(1)
cats = []
for parent in root.iterdir():
    stream = parent / sid / 'updates.jsonl'
    if parent.is_symlink() or (parent / sid).is_symlink() or stream.is_symlink() or not stream.is_file(): continue
    for line in stream.read_text(errors='replace').splitlines():
        if not re.search(r'"sessionUpdate"\s*:\s*"turn_completed"', line): continue
        try: ev = json.loads(line)
        except ValueError: continue
        par = ev.get('params', {}) if isinstance(ev, dict) else {}
        up = par.get('update', {}) if isinstance(par, dict) else {}
        if not isinstance(up, dict) or par.get('sessionId') != sid or up.get('prompt_id') != req or up.get('stop_reason') != 'cancelled': continue
        meta = par.get('_meta', {})
        cats.append(meta.get('cancellationCategory') if isinstance(meta, dict) else None)
sys.exit(0 if cats == ['PermissionCancelled'] else 1)
PY
}

main() {
  local grok cwd out prompt_full rc
  grok="$(resolve_grok)" || exit $?
  require_credentials || exit $?
  [ -d "$DOOR_WORKDIR" ] || { printf 'grok door: workdir missing: %s\n' "$DOOR_WORKDIR" >&2; exit 2; }
  [ -f "$DOOR_PROMPT_FILE" ] || { printf 'grok door: prompt file missing: %s\n' "$DOOR_PROMPT_FILE" >&2; exit 2; }

  # Packet preamble: the sealed evidence is the subject; the workdir is the
  # disposable copy. The runner owns seal/store; this only points the model.
  prompt_full="$(mktemp)"
  {
    printf 'Your evidence packet is at %s/MANIFEST.md. Read it first.\n' "$DOOR_PACKET_DIR"
    printf 'It contains the exact commits under review, the changed files, the full patch, and what you are being asked to decide.\n'
    printf 'The reviewed head commit is %s; quote that full SHA in your report.\n\n' "$DOOR_HEAD"
    printf '%s\n\n' "$SHELL_RULE"
    cat "$DOOR_PROMPT_FILE"
    printf '\n\n---\nFormatting requirement: structure your reply so the final answer is last, under a literal '"'"'## Verdict'"'"' heading.\n'
  } > "$prompt_full"

  cwd="$(native_cwd "$DOOR_WORKDIR")"
  out="$(mktemp)"
  set +e
  if [ "$MODE" = implement ]; then
    reviewer_credit_run grok "$out" "$out.err" -- env -u GROK_CLAUDE_1PASSWORD_HELPER \
      "$grok" --cwd "$cwd" --model "$GROK_MODEL" --prompt-file "$prompt_full" \
        --max-turns "$GROK_MAX_TURNS" "${GROK_PERMS[@]}" --output-format json \
        > "$out" 2> "$out.err"
  else
    reviewer_credit_run grok "$out" "$out.err" -- env -u GROK_CLAUDE_1PASSWORD_HELPER \
      "$grok" --cwd "$cwd" --model "$GROK_MODEL" --prompt-file "$prompt_full" \
        --max-turns "$GROK_MAX_TURNS" "${GROK_PERMS[@]}" --output-format json \
        > "$out" 2> "$out.err"
  fi
  rc=$?
  set -e

  local n=0 sid rpf used left="$GROK_MAX_TURNS"
  case "$GROK_PERMISSION_RESUMES" in ''|*[!0-9]*) GROK_PERMISSION_RESUMES=0 ;; esac
  [ "$GROK_PERMISSION_RESUMES" -le 5 ] || GROK_PERMISSION_RESUMES=5
  while [ "$rc" -eq 0 ] && [ "$n" -lt "$GROK_PERMISSION_RESUMES" ] && permission_cancelled "$out"; do
    # num_turns is per invocation; a missing count is charged as one turn.
    used="$(jq -r '.num_turns // 1' "$out")"; case "$used" in ''|*[!0-9]*) used=1 ;; esac
    left=$(( left - used )); [ "$left" -ge 1 ] || break
    n=$((n + 1)); sid="$(jq -r '.sessionId' "$out")"
    printf 'grok door: Grok refused a shell command form (PermissionCancelled); resuming session %s (%s of %s, %s turns left).\n' "$sid" "$n" "$GROK_PERMISSION_RESUMES" "$left" >&2
    mv -f "$out" "$out.cancelled$n"   # keep the confirmed cancelled result
    rpf="$(mktemp)"
    printf '%s\n' "The Grok CLI refused your last shell command and cancelled it; nothing ran. $SHELL_RULE. Do not retry that form. Continue the same $MODE task from where you stopped and finish with the required '## Verdict' section." > "$rpf"
    set +e
    reviewer_credit_run grok "$out" "$out.err" -- env -u GROK_CLAUDE_1PASSWORD_HELPER \
      "$grok" --cwd "$cwd" --model "$GROK_MODEL" -r "$sid" --prompt-file "$rpf" \
        --max-turns "$left" "${GROK_PERMS[@]}" --output-format json \
        > "$out" 2> "$out.err"
    rc=$?
    set -e
    rm -f "$rpf"
  done

  if [ "$rc" -eq 92 ]; then
    reviewer_capacity_current grok "$out" || true
    reviewer_credit_exit
    rm -f "$prompt_full"
    exit 92
  fi
  if [ "$rc" -ne 0 ] || ! jq -e 'has("stopReason")' "$out" >/dev/null 2>&1; then
    printf 'grok door: provider call failed (exit %s)\n' "$rc" >&2
    [ -s "$out.err" ] && sed -E 's/((API[_-]?KEY|TOKEN|SECRET|PASSWORD)[[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig; s/(Bearer[[:space:]]+)[A-Za-z0-9._~+\/-]+/\1[REDACTED]/Ig' "$out.err" | tail -20 >&2 || true
    rm -f "$prompt_full"
    exit 1
  fi

  if ! extract_report "$out" "$DOOR_REPORT_OUT" "$DOOR_HEAD" "$MODE"; then
    rm -f "$prompt_full"
    exit 1
  fi
  rm -f "$prompt_full"
  exit 0
}

main "$@"
