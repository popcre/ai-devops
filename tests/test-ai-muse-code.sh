#!/usr/bin/env bash
# Offline checks for the Muse Code engine of bin/ai-muse (AI_MUSE_ENGINE=muse-code).
# A stub CLI stands in for Meta's binary; no provider or 1Password contact.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-muse"
PASS=0; FAIL=0
check(){ local label="$1"; shift; if bash -c "$1" >/dev/null 2>&1; then printf 'PASS  %s\n' "$label"; PASS=$((PASS+1)); else printf 'FAIL  %s\n' "$label"; FAIL=$((FAIL+1)); fi; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/muse-code-test.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
command -v jq >/dev/null 2>&1 || { printf 'SKIP  jq unavailable\n'; exit 0; }

VERSION="$(tr -d ' \r\n' < "$ROOT/config/muse-code/version")"
HOME_FIX="$TMP/home"; REPO="$TMP/repo"; mkdir -p "$HOME_FIX" "$REPO" "$TMP/bin"
MBIN="$HOME_FIX/AppData/Local/Programs/muse"; mkdir -p "$MBIN"
git -C "$REPO" init -q; git -C "$REPO" config user.name Test; git -C "$REPO" config user.email t@example.com
printf '.ai/\n' > "$REPO/.gitignore"; printf 'marker\n' > "$REPO/a.txt"; git -C "$REPO" add .gitignore a.txt; git -C "$REPO" commit -qm init
printf '#!/usr/bin/env bash\nprintf fake-key\n' > "$TMP/bin/op"
cat > "$MBIN/muse-bin-$VERSION.exe" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --version) printf 'Muse Code 1.3.0 (%s)\n' "${MUSE_STUB_VERSION:-1.3.0-R3233.1}";;
  exec)
    [ -z "${MUSE_STUB_ENV_FILE:-}" ] || env | sort > "$MUSE_STUB_ENV_FILE"
    [ -z "${MUSE_STUB_ARGS_FILE:-}" ] || printf '%s\n' "$@" > "$MUSE_STUB_ARGS_FILE"
    [ "${MUSE_STUB_MODE:-}" = fail ] && exit 7
    [ "${MUSE_STUB_MODE:-}" = malformed ] && { printf 'not-json\n'; exit 0; }
    sid=''; prev=''; for a in "$@"; do [ "$prev" = --session-id ] && sid="$a"; prev="$a"; done
    [ "${MUSE_STUB_MODE:-}" = wrongsid ] && sid=00000000-0000-4000-8000-000000000000
    store="$XDG_DATA_HOME/muse/sessions/.msp-view-v1/$sid"
    text="${MUSE_STUB_TEXT:-$([ -d "$store" ] && echo remembered || echo first)}"
    mkdir -p "$store"; printf '{}' > "$store/HEAD.json"
    ev(){ jq -cn --arg sid "$1" --arg t "$2" --argjson p "$3" '{stream:{kind:"session",id:$sid},payload_type:$t,payload:$p}'; }
    ev "$sid" task.lifecycle.started '{}'
    [ "${MUSE_STUB_MODE:-}" = mixed ] && ev 11111111-1111-4111-8111-111111111111 task.lifecycle.started '{}'
    [ "${MUSE_STUB_MODE:-}" = nostream ] && printf '{"payload_type":"note","payload":{}}\n'
    case "${MUSE_STUB_MODE:-}" in
      noterminal) ;;
      failed) ev "$sid" run.terminal.failed "$(jq -cn --arg t "$text" '{terminal:"failed",text:$t}')";;
      completedthenfailed) ev "$sid" run.terminal.completed "$(jq -cn --arg t "$text" '{terminal:"completed",text:$t}')"; ev "$sid" run.terminal.failed '{"terminal":"failed"}';;
      *) ev "$sid" run.terminal.completed "$(jq -cn --arg t "$text" '{terminal:"completed",text:$t}')";;
    esac;;
  export)
    sid=''; out=''; while [ $# -gt 0 ]; do case "$1" in --session) sid="$2"; shift;; --out) out="$2"; shift;; esac; shift; done
    jq -n --arg sid "$sid" '{sessions:[{session_id:$sid}]}' > "$out";;
  *) exit 2;;
esac
EOF
chmod +x "$TMP/bin/op" "$MBIN/muse-bin-$VERSION.exe"
STORE="$HOME_FIX/.local/share/ai-devops/muse-code/muse/sessions/.msp-view-v1"
ENV="USERPROFILE='$HOME_FIX' HOME='$TMP/roaming-home' PATH='$TMP/bin:$PATH' AI_MUSE_STATE_DIR='$TMP/state' AI_REVIEW_SANDBOX_DIR='$TMP/sandboxes' AI_MUSE_CALLER=claude AI_MUSE_ENGINE=muse-code AI_MUSE_TEST_DIR='$TMP' MUSE_STUB_ENV_FILE='$TMP/provider-env' MUSE_STUB_ARGS_FILE='$TMP/provider-args'"

check 'unknown engine refuses before any work' "cd '$REPO' && ! eval \"$ENV AI_MUSE_ENGINE=bogus '$SCRIPT' doctor\" 2>&1 | grep -q PASS"
check 'default engine stays OpenCode' "cd '$REPO' && eval \"USERPROFILE='$HOME_FIX' PATH='$TMP/bin:$PATH' AI_MUSE_CALLER=claude '$SCRIPT' doctor\" 2>&1 | grep -q 'engine: opencode'"
check 'doctor proves the pinned Muse Code version' "cd '$REPO' && eval \"$ENV '$SCRIPT' doctor\" | grep -q 'PASS  Muse Code reports the pinned'"
check 'doctor refuses an unpinned Muse Code version' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_VERSION=9.9.9 '$SCRIPT' doctor\""
check 'turn refuses an unpinned Muse Code version without contact' "cd '$REPO' && rm -f '$TMP/provider-args' && ! eval \"$ENV MUSE_STUB_VERSION=9.9.9 '$SCRIPT' new pin --prompt test\" && test ! -e '$TMP/provider-args'"
check 'new session completes and returns the final answer' "cd '$REPO' && eval \"$ENV '$SCRIPT' new first --prompt test\" | grep -qx first"
check 'launch is read-only: no write, shell, web, personal context or prompts' "for f in exec --json --disable-write --disable-shell --disable-web-tools --no-foreign-personal-context --user-input-auto-resolve; do grep -qx -- \"\$f\" '$TMP/provider-args' || exit 1; done && grep -qx 'muse-spark-1.3-contributor' '$TMP/provider-args'"
check 'provider gets the key only as META_API_KEY' "grep -qx 'META_API_KEY=fake-key' '$TMP/provider-env' && ! grep -q '^MODEL_API_KEY=' '$TMP/provider-env' && ! grep -q '^AI_MUSE_KEY_ENV=' '$TMP/provider-env' && ! grep -q '^AI_MUSE_SECRET_FILE=' '$TMP/provider-env'"
check 'prompt that looks like options never reaches the argument list' "cd '$REPO' && eval \"$ENV '$SCRIPT' new optprompt --prompt '--workspace=C:/ --enable-write'\" && ! grep -q -- '--enable-write' '$TMP/provider-args' && grep -qx -- --prompt-file '$TMP/provider-args'"
check 'key never appears in provider arguments' "! grep -q fake-key '$TMP/provider-args'"
check 'provider uses private isolated stores' "grep -q '^XDG_DATA_HOME=.*ai-devops/muse-code' '$TMP/provider-env' && grep -q '^XDG_CONFIG_HOME=.*muse-code-xdg' '$TMP/provider-env'"
check 'every private store is locked down before use' "for d in '$HOME_FIX/.local/share/ai-devops/muse-code' '$HOME_FIX/.local/state/ai-devops/muse-code' '$HOME_FIX/.cache/ai-devops/muse-code'; do test -f \"\$d/.ai-devops-private-store-v1\" || exit 1; done"
check 'wrapper chooses and records a UUID session identity' "cd '$REPO' && eval \"$ENV '$SCRIPT' show first\" | jq -e '.status==\"active\" and (.session_id|test(\"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$\"))'"
check 'follow-up resumes the exact recorded session' "cd '$REPO' && eval \"$ENV '$SCRIPT' ask first --prompt again\" | grep -qx remembered && grep -qx \"\$(eval \"$ENV '$SCRIPT' show first\" | jq -r .session_id)\" '$TMP/provider-args'"
check 'report records usage as unavailable, not zero' "grep -q 'engine-usage-not-reported' '$REPO'/.ai/reviews/muse-first-*.md"
check 'transcript exports the recorded session' "cd '$REPO' && eval \"$ENV '$SCRIPT' transcript first\" | jq -e '.sessions[0].session_id|length==36'"
check 'transcript under the wrong engine is refused' "cd '$REPO' && ! eval \"$ENV AI_MUSE_ENGINE=opencode '$SCRIPT' transcript first\" 2>&1 | grep -q session_id"
check 'delete under the wrong engine is refused and keeps the session' "cd '$REPO' && ! eval \"$ENV AI_MUSE_ENGINE=opencode '$SCRIPT' delete first\" && eval \"$ENV '$SCRIPT' show first\" | jq -e .session_id"
check 'delete removes exactly the private session store' "cd '$REPO' && sid=\"\$(eval \"$ENV '$SCRIPT' show first\" | jq -r .session_id)\" && test -d '$STORE'/\"\$sid\" && eval \"$ENV '$SCRIPT' delete first\" && test ! -e '$STORE'/\"\$sid\""
check 'provider failure is rejected' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_MODE=fail '$SCRIPT' new f1 --prompt test\""
check 'malformed output is rejected' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_MODE=malformed '$SCRIPT' new f2 --prompt test\""
check 'answer in a different session is rejected' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_MODE=wrongsid '$SCRIPT' new f3 --prompt test\""
check 'mixed session stream is rejected' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_MODE=mixed '$SCRIPT' new f4 --prompt test\""
check 'event outside the session stream is rejected' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_MODE=nostream '$SCRIPT' new f5 --prompt test\""
check 'missing terminal event is rejected' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_MODE=noterminal '$SCRIPT' new f6 --prompt test\""
check 'failed terminal event is rejected even with text' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_MODE=failed '$SCRIPT' new f7 --prompt test\""
check 'completion followed by failure is rejected' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_MODE=completedthenfailed '$SCRIPT' new f8 --prompt test\""
check 'rejected turns leave incomplete evidence, not accepted reports' "test -n \"\$(ls '$REPO'/.ai/reviews/muse-f7-incomplete-*.md 2>/dev/null)\" && test -z \"\$(ls '$REPO'/.ai/reviews/muse-f7-2*.md 2>/dev/null)\""
check 'compatibility review requires a final verdict' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_TEXT=narration '$SCRIPT' review '$REPO' test\""
check 'compatibility review accepts an explicit verdict' "cd '$REPO' && eval \"$ENV MUSE_STUB_TEXT='VERDICT: NO FINDINGS' '$SCRIPT' review '$REPO' test\" | grep -q 'VERDICT: NO FINDINGS'"
# Symlink refusal needs real symlinks; Git Bash only makes them with native symlink support.
if (export MSYS=winsymlinks:nativestrict; mkdir -p "$TMP/lt" && ln -s "$TMP/lt" "$TMP/lt-link" 2>/dev/null && test -L "$TMP/lt-link"); then
  check 'delete refuses a symlinked session store' "export MSYS=winsymlinks:nativestrict; cd '$REPO' && eval \"$ENV '$SCRIPT' new linked --prompt test\" >/dev/null && sid=\"\$(eval \"$ENV '$SCRIPT' show linked\" | jq -r .session_id)\" && mv '$STORE' '$TMP/decoy' && ln -s '$TMP/decoy' '$STORE' && ! eval \"$ENV '$SCRIPT' delete linked\"; rc=\$?; test -d '$TMP/decoy/'\"\$sid\" || rc=1; rm -f '$STORE'; mv '$TMP/decoy' '$STORE'; exit \$rc"
else printf 'SKIP  delete refuses a symlinked session store (no native symlinks)\n'; fi
check 'source repository is untouched' "test -z \"\$(git -C '$REPO' status --porcelain)\""

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
