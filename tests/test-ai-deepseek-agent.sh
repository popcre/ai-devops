#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; SCRIPT="$ROOT/bin/ai-deepseek-agent"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }; bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/home/.config/ai-devops" "$TMP/repo"
git -C "$TMP/repo" init -q; git -C "$TMP/repo" config user.email test@example.com; git -C "$TMP/repo" config user.name Test
printf 'test\n' > "$TMP/repo/tracked"; git -C "$TMP/repo" add tracked; git -C "$TMP/repo" commit -qm init
printf 'placeholder-token\n' > "$TMP/home/.config/ai-devops/op-service-account"
printf 'DEEPSEEK_API_KEY=op://example\n' > "$TMP/home/.config/ai-devops/mcp.env"
cat > "$TMP/bin/op" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$DEEPSEEK_TEST_ARGS"
STUB
cat > "$TMP/bin/curl" <<'STUB'
#!/usr/bin/env bash
out=""; while [ "$#" -gt 0 ]; do case "$1" in -o) out="$2"; shift 2;; *) shift;; esac; done
[ -n "${DEEPSEEK_STUB_DELAY:-}" ] && sleep "$DEEPSEEK_STUB_DELAY"
if [ "${DEEPSEEK_STUB_FAIL:-0}" = 1 ]; then printf '{"error":"stub"}' > "$out"; printf 500; else python -c 'import json,os,sys; json.dump({"choices":[{"message":{"content":os.environ.get("DEEPSEEK_STUB_REPLY","answer")}}]},open(sys.argv[1],"w"))' "$out"; printf 200; fi
STUB
chmod +x "$TMP/bin/op" "$TMP/bin/curl"
echo 'ai-deepseek-agent tests'
HOME="$TMP/home" PATH="$TMP/bin:$PATH" DEEPSEEK_TEST_ARGS="$TMP/args" bash "$SCRIPT" send test >/dev/null 2>&1
check "1Password re-exec was attempted" "grep -qx run '$TMP/args'"
if [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* ]]; then check "Windows re-exec uses explicit Git Bash" "grep -Eqi 'Git.*bash.exe$' '$TMP/args'"; else check "POSIX re-exec keeps script path" "grep -q ai-deepseek-agent '$TMP/args'"; fi
check "help succeeds" "bash '$SCRIPT' --help"; check "unknown command fails" "! bash '$SCRIPT' unknown"
run(){ (cd "$TMP/repo" && HOME="$TMP/home" PATH="$TMP/bin:$PATH" DEEPSEEK_API_KEY=test "$SCRIPT" "$@"); }
SESSION="$(run send first | sed -n 's/^SESSION_ID: //p')"
check "send creates a safe session" "test -n '$SESSION' -a -f '$TMP/repo/.ai/deepseek-sessions/$SESSION.json'"
check "show reads stored session" "run show '$SESSION' | grep -q answer"
printf '{"outside":true}\n' > "$TMP/outside.json"; before="$(sha256sum "$TMP/outside.json"|cut -d' ' -f1)"
for hostile in '..' '../outside' '../../outside' '/tmp/outside' 'C:\outside' 'C:/outside' 'CON' 'con.txt' 'name/part' 'name\part' '.hidden'; do if run show "$hostile" >/dev/null 2>&1 || run reply "$hostile" attack >/dev/null 2>&1; then bad "hostile name rejected: $hostile"; else ok "hostile name rejected: $hostile"; fi; done
after="$(sha256sum "$TMP/outside.json"|cut -d' ' -f1)"; check "hostile names preserve outside files" "test '$before' = '$after'"
ln -s "$TMP/outside.json" "$TMP/repo/.ai/deepseek-sessions/linked.json" 2>/dev/null || true
check "session-file symlink is rejected" "! run show linked"
mv "$TMP/repo/.ai/deepseek-sessions" "$TMP/repo/.ai/deepseek-real"; ln -s "$TMP/repo/.ai/deepseek-real" "$TMP/repo/.ai/deepseek-sessions" 2>/dev/null || true
if [ -L "$TMP/repo/.ai/deepseek-sessions" ]; then check "symlinked session folder is rejected" "! run list"; rm "$TMP/repo/.ai/deepseek-sessions"; else ok "symlink fixture unavailable on this host"; rm -rf "$TMP/repo/.ai/deepseek-sessions"; fi
mv "$TMP/repo/.ai/deepseek-real" "$TMP/repo/.ai/deepseek-sessions"
history="$TMP/repo/.ai/deepseek-sessions/$SESSION.json"; history_before="$(sha256sum "$history"|cut -d' ' -f1)"
check "provider failure is nonzero" "DEEPSEEK_STUB_FAIL=1 run reply '$SESSION' failed >/dev/null 2>&1; test \$? -ne 0"
check "provider failure leaves history unchanged" "test '$history_before' = \"\$(sha256sum '$history'|cut -d' ' -f1)\""
DEEPSEEK_STUB_DELAY=1 run reply "$SESSION" concurrent-one >/dev/null & p1=$!; DEEPSEEK_STUB_DELAY=1 run reply "$SESSION" concurrent-two >/dev/null & p2=$!
wait "$p1"; r1=$?; wait "$p2"; r2=$?; check "concurrent replies both complete" "test '$r1' -eq 0 -a '$r2' -eq 0"
check "concurrent replies retain complete turns" "jq -e 'length==6 and map(.role)==[\"user\",\"assistant\",\"user\",\"assistant\",\"user\",\"assistant\"]' '$history'"
history_before_signal="$(sha256sum "$history"|cut -d' ' -f1)"
(cd "$TMP/repo" && exec env HOME="$TMP/home" PATH="$TMP/bin:$PATH" DEEPSEEK_API_KEY=test DEEPSEEK_STUB_DELAY=5 "$SCRIPT" reply "$SESSION" interrupted) >/dev/null 2>&1 & signal_pid=$!
for _ in $(seq 1 100); do [ -d "$history.lock" ] && break; sleep .05; done
kill -TERM "$signal_pid" 2>/dev/null || true; signal_rc=0; wait "$signal_pid" 2>/dev/null || signal_rc=$?
check "interrupted reply exits nonzero and does not resume after lock release" "test '$signal_rc' -ne 0 && test '$history_before_signal' = \"\$(sha256sum '$history'|cut -d' ' -f1)\""
check "interrupted reply releases its owned lock" "test ! -d '$history.lock'"
DEEPSEEK_STUB_REPLY='no verdict' run send review-me --review >/dev/null 2>&1; missing_rc=$?
check "review mode rejects missing verdict" "test '$missing_rc' -ne 0"
REVIEW_OUT="$(DEEPSEEK_STUB_REPLY=$'findings\n## Verdict\nAPPROVE' run send review-me --review)"; REVIEW_ID="$(printf '%s\n' "$REVIEW_OUT"|sed -n 's/^SESSION_ID: //p')"
check "review mode accepts usable verdict" "test -n '$REVIEW_ID'"
check "review metadata binds exact session/head/caller" "jq -e --arg s '$REVIEW_ID' --arg h \"\$(git -C '$TMP/repo' rev-parse HEAD)\" '.provider==\"deepseek\" and .session_id==\$s and .head==\$h and .caller==\"unknown\" and .verdict==\"APPROVE\" and .status==\"complete\"' '$TMP/repo/.ai/deepseek-sessions/$REVIEW_ID.meta.json'"
set +e
METADATA_FAILURE_OUT="$(AI_DEEPSEEK_TEST_METADATA_FAILURE=publish DEEPSEEK_STUB_REPLY=$'findings\n## Verdict\nAPPROVE' run send metadata-failure --review 2>&1)"; METADATA_FAILURE_RC=$?
set -e
check "real metadata publication failure is not masked by cleanup" "test '$METADATA_FAILURE_RC' -ne 0 && ! printf '%s' '$METADATA_FAILURE_OUT' | grep -q '^SESSION_ID:'"
set +e
TRANSCRIPT_FAILURE_OUT="$(AI_DEEPSEEK_TEST_TRANSCRIPT_FAILURE=publish DEEPSEEK_STUB_REPLY=$'findings\n## Verdict\nAPPROVE' run send transcript-failure --review 2>&1)"; TRANSCRIPT_FAILURE_RC=$?
set -e
check "real transcript publication failure is not masked by cleanup" "test '$TRANSCRIPT_FAILURE_RC' -ne 0 && ! printf '%s' '$TRANSCRIPT_FAILURE_OUT' | grep -q '^SESSION_ID:'"
check "transcript failure publishes no completion metadata" "test -z \"\$(find '$TMP/repo/.ai/deepseek-sessions' -type f -name '*.meta.json' -newer '$TMP/repo/.ai/deepseek-sessions/$REVIEW_ID.meta.json' -print -quit)\""
check "list excludes metadata sidecars" "test \"\$(run list|grep -c meta||true)\" -eq 0"
check "shell syntax is valid" "bash -n '$SCRIPT'"
printf 'passed %d, failed %d\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
