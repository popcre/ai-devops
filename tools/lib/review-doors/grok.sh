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
source "$DOOR_CREDIT_ROOT/tools/lib/grok-runtime.sh"
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
  grok_resolve_door_runtime
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

permission_cancelled() { # permission_cancelled RESULT_JSON [SINCE_MARKER] -> 0 and "SID<TAB>STEP" on ONE witness
  # Two native witness forms, both bound to one session:
  #  1. updates.jsonl turn_completed bound to this result's sessionId AND
  #     requestId (native prompt_id), exactly one match, as in bin/ai-grok-review.
  #  2. the newer session-log event {"type":"turn_ended","outcome":"cancelled",
  #     "cancellation_category":"permission_cancelled"} as the session's LATEST
  #     turn_ended (seen on 916, #1650; the CLI may then exit nonzero with no
  #     JSON). Without a result sessionId, only a single session touched after
  #     SINCE_MARKER qualifies. Symlinks refused; a leftover or other-category
  #     cancel (max_turns_reached) never qualifies.
  local result="$1" since="${2:-}" py
  for py in python3 python; do command -v "$py" >/dev/null 2>&1 && break; py=""; done
  [ -n "$py" ] || return 1
  "$py" - "$result" "${GROK_HOME:-${HOME:-}/.grok}/sessions" "$since" <<'PY'
import json, os, pathlib, re, sys
try: result = json.loads(pathlib.Path(sys.argv[1]).read_text())
except Exception: result = {}
if not isinstance(result, dict): result = {}
sid, req = result.get('sessionId'), result.get('requestId')
ok = lambda v: isinstance(v, str) and re.fullmatch(r'[A-Za-z0-9-]{1,80}', v)
root, since = pathlib.Path(sys.argv[2]), sys.argv[3]
if not root.is_dir() or root.is_symlink(): sys.exit(1)
def session_dirs(s):
    for parent in root.iterdir():
        d = parent / s
        if parent.is_symlink() or d.is_symlink() or not d.is_dir(): continue
        yield d
def logs(d):
    for f in sorted(d.rglob('*.jsonl')):
        if f.is_symlink() or not f.is_file(): continue
        yield f
def step_of(rows):
    for row in reversed(rows):  # the last shell command the model asked for
        stack = [row]
        while stack:
            v = stack.pop()
            if isinstance(v, dict):
                for k in ('command', 'cmd'):
                    if isinstance(v.get(k), str) and v[k].strip(): return v[k].strip().splitlines()[0][:200]
                stack.extend(v.values())
            elif isinstance(v, list): stack.extend(v)
    return ''
def new_form(d):
    rows, last, turn = [], None, []
    for f in logs(d):
        for line in f.read_text(errors='replace').splitlines():
            try: ev = json.loads(line)
            except ValueError: continue
            if not isinstance(ev, dict): continue
            if ev.get('type') == 'turn_ended': last, turn, rows = ev, rows, []
            else: rows.append(ev)
    if not (isinstance(last, dict) and last.get('outcome') == 'cancelled'
            and last.get('cancellation_category') == 'permission_cancelled'): return None
    return step_of(turn)
def old_form(d):
    stream = d / 'updates.jsonl'
    if stream.is_symlink() or not stream.is_file() or not ok(req): return []
    cats, rows = [], []
    for line in stream.read_text(errors='replace').splitlines():
        try: ev = json.loads(line)
        except ValueError: continue
        rows.append(ev)
        if not re.search(r'"sessionUpdate"\s*:\s*"turn_completed"', line): continue
        par = ev.get('params', {}) if isinstance(ev, dict) else {}
        up = par.get('update', {}) if isinstance(par, dict) else {}
        if not isinstance(up, dict) or par.get('sessionId') != sid or up.get('prompt_id') != req or up.get('stop_reason') != 'cancelled': continue
        meta = par.get('_meta', {})
        cats.append(meta.get('cancellationCategory') if isinstance(meta, dict) else None)
    return cats
if ok(sid):
    if result.get('stopReason') not in (None, 'cancelled'): sys.exit(1)
    cats, step = [], None
    for d in session_dirs(sid):
        cats += old_form(d)
        s = new_form(d)
        if s is not None: step = s
    if result.get('stopReason') == 'cancelled' and cats == ['PermissionCancelled']: print(sid + '\t'); sys.exit(0)
    if step is not None: print(sid + '\t' + step); sys.exit(0)
    sys.exit(1)
if not since or not os.path.isfile(since): sys.exit(1)
t0, hits = os.path.getmtime(since), []
for parent in root.iterdir():
    if parent.is_symlink() or not parent.is_dir(): continue
    for d in parent.iterdir():
        if d.is_symlink() or not d.is_dir() or not ok(d.name): continue
        if not any(f.stat().st_mtime >= t0 for f in logs(d)): continue
        hits.append(d)
if len(hits) != 1: sys.exit(1)
step = new_form(hits[0])
if step is None: sys.exit(1)
print(hits[0].name + '\t' + step)
PY
}

main() {
  local grok cwd out prompt_full rc since witness="" step=""
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
  since="$(mktemp)"   # session logs touched after this belong to this call
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

  local n=0 sid rpf used left="$GROK_MAX_TURNS" tab=$'\t'
  case "$GROK_PERMISSION_RESUMES" in ''|*[!0-9]*) GROK_PERMISSION_RESUMES=0 ;; esac
  [ "$GROK_PERMISSION_RESUMES" -le 5 ] || GROK_PERMISSION_RESUMES=5
  # A permission-cancelled turn may exit 0 with stopReason "cancelled" or, on
  # newer CLIs, nonzero with no JSON (#1650). Out of credit (92) never resumes.
  while [ "$rc" -ne 92 ] && witness="$(permission_cancelled "$out" "$since")"; do
    sid="${witness%%"$tab"*}"; step="${witness#*"$tab"}"
    [ "$n" -lt "$GROK_PERMISSION_RESUMES" ] || break
    # num_turns is per invocation; a missing count is charged as one turn.
    used="$(jq -r '.num_turns // 1' "$out" 2>/dev/null || echo 1)"; case "$used" in ''|*[!0-9]*) used=1 ;; esac
    left=$(( left - used )); [ "$left" -ge 1 ] || break
    n=$((n + 1))
    printf 'grok door: Grok refused a shell command (permission_cancelled%s); resuming session %s (%s of %s, %s turns left).\n' "${step:+: $step}" "$sid" "$n" "$GROK_PERMISSION_RESUMES" "$left" >&2
    mv -f "$out" "$out.cancelled$n"   # keep the confirmed cancelled result
    [ ! -s "$out.err" ] || mv -f "$out.err" "$out.cancelled$n.err"
    rpf="$(mktemp)"
    printf '%s\n' "The Grok CLI refused your last shell command${step:+ ($step)} and cancelled it; nothing ran. $SHELL_RULE. Do not retry that command or form. If your $MODE work is already complete, skip any cleanup and output your final report with the required '## Verdict' section now; otherwise continue the same $MODE task from where you stopped and finish with the required '## Verdict' section." > "$rpf"
    : > "$since"
    set +e
    reviewer_credit_run grok "$out" "$out.err" -- env -u GROK_CLAUDE_1PASSWORD_HELPER \
      "$grok" --cwd "$cwd" --model "$GROK_MODEL" -r "$sid" --prompt-file "$rpf" \
        --max-turns "$left" "${GROK_PERMS[@]}" --output-format json \
        > "$out" 2> "$out.err"
    rc=$?
    set -e
    rm -f "$rpf"
    witness=""
  done

  if [ "$rc" -eq 92 ]; then
    reviewer_capacity_current grok "$out" || true
    reviewer_credit_exit
    rm -f "$prompt_full" "$since"
    exit 92
  fi
  rm -f "$since"
  if [ -n "$witness" ]; then
    # Still cancelled after the bounded recovery: an unattended permission
    # refusal, not a provider outage. Retain the native evidence privately.
    printf 'grok door: Grok cancelled the turn because the unattended permission check refused a shell command%s; no verdict after %s resume(s).\n' "${step:+: $step}" "$n" >&2
    printf 'permission_cancelled session=%s refused_step=%s resumes=%s\n' "$sid" "${step:-unknown}" "$n" >> "$out.err"
    python3 "$DOOR_CREDIT_ROOT/tools/review_door_diagnostics.py" grok \
      "$out" "$out.err" "$rc" permission-cancelled "$DOOR_REPORT_OUT" "${DOOR_DIAGNOSTICS_DIR:-}" || true
    rm -f "$prompt_full"
    exit 1
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
