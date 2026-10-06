#!/usr/bin/env bash
# Caller identity resolution for reviewer wrappers (ai-gemini, ai-glm).
# Explicit AI_*_CALLER wins; otherwise the harness is detected (mimo/claude/
# codex/zcode). Unknown or ambiguous identity fails closed — never a wrong
# engine name.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tools/lib/provider-wrapper-common.sh"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# Run a wrapper in an environment that carries no harness markers.
run_bare(){ env -i PATH="$PATH" HOME="$HOME" USERPROFILE="${USERPROFILE:-}" SYSTEMROOT="${SYSTEMROOT:-}" LOCALAPPDATA="${LOCALAPPDATA:-}" "$@"; }

echo '== provider_wrapper_detect_caller'
check 'detects mimo from MIMO_NODE' 'test "$(MIMO_NODE=/x CLAUDECODE= CODEX_THREAD_ID= ZCODE_SESSION_ID= MIMO_SESSION_ID= MIMO_PYTHON= MIMO_NPM= MIMO_ELECTRON_NODE_HOST= CLAUDE_CODE_SESSION_ID= CODEX_SANDBOX= provider_wrapper_detect_caller)" = mimo'
check 'detects mimo from MIMO_SESSION_ID' 'test "$(MIMO_SESSION_ID=ses_abc MIMO_NODE= CLAUDECODE= CODEX_THREAD_ID= ZCODE_SESSION_ID= MIMO_PYTHON= MIMO_NPM= MIMO_ELECTRON_NODE_HOST= CLAUDE_CODE_SESSION_ID= CODEX_SANDBOX= provider_wrapper_detect_caller)" = mimo'
check 'detects claude from CLAUDECODE' 'test "$(CLAUDECODE=1 MIMO_NODE= MIMO_SESSION_ID= MIMO_PYTHON= MIMO_NPM= MIMO_ELECTRON_NODE_HOST= CODEX_THREAD_ID= CODEX_SANDBOX= ZCODE_SESSION_ID= CLAUDE_CODE_SESSION_ID= provider_wrapper_detect_caller)" = claude'
check 'detects codex from CODEX_THREAD_ID' 'test "$(CODEX_THREAD_ID=t1 MIMO_NODE= MIMO_SESSION_ID= MIMO_PYTHON= MIMO_NPM= MIMO_ELECTRON_NODE_HOST= CLAUDECODE= CLAUDE_CODE_SESSION_ID= CODEX_SANDBOX= ZCODE_SESSION_ID= provider_wrapper_detect_caller)" = codex'
check 'detects zcode from ZCODE_SESSION_ID' 'test "$(ZCODE_SESSION_ID=z1 MIMO_NODE= MIMO_SESSION_ID= MIMO_PYTHON= MIMO_NPM= MIMO_ELECTRON_NODE_HOST= CLAUDECODE= CLAUDE_CODE_SESSION_ID= CODEX_THREAD_ID= CODEX_SANDBOX= provider_wrapper_detect_caller)" = zcode'
check 'fails closed when no harness marker is present' '! MIMO_NODE= MIMO_SESSION_ID= MIMO_PYTHON= MIMO_NPM= MIMO_ELECTRON_NODE_HOST= CLAUDECODE= CLAUDE_CODE_SESSION_ID= CODEX_THREAD_ID= CODEX_SANDBOX= ZCODE_SESSION_ID= provider_wrapper_detect_caller'
check 'fails closed when two harnesses are present' '! MIMO_NODE=/x CLAUDECODE=1 MIMO_SESSION_ID= MIMO_PYTHON= MIMO_NPM= MIMO_ELECTRON_NODE_HOST= CLAUDE_CODE_SESSION_ID= CODEX_THREAD_ID= CODEX_SANDBOX= ZCODE_SESSION_ID= provider_wrapper_detect_caller'

echo '== provider_wrapper_resolve_caller'
check 'explicit value wins over detection' 'test "$(MIMO_NODE=/x provider_wrapper_resolve_caller my-agent)" = my-agent'
check 'rejects a path-unsafe explicit caller' '! provider_wrapper_resolve_caller ../escape'
check 'rejects a leading-dot explicit caller' '! provider_wrapper_resolve_caller .hidden'
check 'accepts mimo as an explicit caller' 'test "$(provider_wrapper_resolve_caller mimo)" = mimo'
check 'falls back to detection when explicit is empty' 'test "$(MIMO_NODE=/x MIMO_SESSION_ID= MIMO_PYTHON= MIMO_NPM= MIMO_ELECTRON_NODE_HOST= CLAUDECODE= CLAUDE_CODE_SESSION_ID= CODEX_THREAD_ID= CODEX_SANDBOX= ZCODE_SESSION_ID= provider_wrapper_resolve_caller "")" = mimo'
check 'fails closed when nothing names the caller' '! MIMO_NODE= MIMO_SESSION_ID= MIMO_PYTHON= MIMO_NPM= MIMO_ELECTRON_NODE_HOST= CLAUDECODE= CLAUDE_CODE_SESSION_ID= CODEX_THREAD_ID= CODEX_SANDBOX= ZCODE_SESSION_ID= provider_wrapper_resolve_caller ""'

echo '== wrapper fail-closed and explicit-env parity'
check 'ai-gemini refuses without a caller' '! run_bare "$ROOT/bin/ai-gemini" new x --prompt y >/dev/null 2>&1'
check 'ai-gemini error names caller_identity_missing' 'out="$(run_bare "$ROOT/bin/ai-gemini" new x --prompt y 2>&1 || true)"; grep -q caller_identity_missing <<<"$out"'
check 'ai-gemini accepts AI_GEMINI_CALLER=mimo' 'run_bare AI_GEMINI_CALLER=mimo "$ROOT/bin/ai-gemini" --version | grep -q ai-gemini'
check 'ai-gemini auto-detects mimo' 'MIMO_NODE=/x CLAUDECODE= CODEX_THREAD_ID= CODEX_SANDBOX= ZCODE_SESSION_ID= MIMO_SESSION_ID= MIMO_PYTHON= MIMO_NPM= MIMO_ELECTRON_NODE_HOST= CLAUDE_CODE_SESSION_ID= "$ROOT/bin/ai-gemini" --version | grep -q ai-gemini'
check 'ai-gemini rejects an unsafe explicit caller' '! run_bare AI_GEMINI_CALLER=../escape "$ROOT/bin/ai-gemini" new x --prompt y >/dev/null 2>&1'
check 'ai-gemini version works without a caller' 'run_bare "$ROOT/bin/ai-gemini" --version | grep -q ai-gemini'
check 'ai-glm refuses without a caller' '! run_bare "$ROOT/bin/ai-glm" list >/dev/null 2>&1'
check 'ai-glm error names caller_identity_missing' 'out="$(run_bare "$ROOT/bin/ai-glm" list 2>&1 || true)"; grep -q caller_identity_missing <<<"$out"'
check 'ai-glm accepts AI_GLM_CALLER=mimo' 'run_bare AI_GLM_CALLER=mimo "$ROOT/bin/ai-glm" --help >/dev/null'
check 'ai-glm accepts --caller mimo' 'run_bare "$ROOT/bin/ai-glm" list --caller mimo >/dev/null'
check 'ai-glm auto-detects mimo' 'MIMO_NODE=/x CLAUDECODE= CODEX_THREAD_ID= CODEX_SANDBOX= ZCODE_SESSION_ID= MIMO_SESSION_ID= MIMO_PYTHON= MIMO_NPM= MIMO_ELECTRON_NODE_HOST= CLAUDE_CODE_SESSION_ID= "$ROOT/bin/ai-glm" --help >/dev/null'
check 'ai-glm rejects an unsafe explicit caller' '! run_bare AI_GLM_CALLER=bad/name "$ROOT/bin/ai-glm" list >/dev/null 2>&1'
check 'ai-glm help works without a caller' 'run_bare "$ROOT/bin/ai-glm" --help >/dev/null'

printf 'caller-detection: %d passed, %d failed\n' "$PASS" "$FAIL"
test "$FAIL" -eq 0
