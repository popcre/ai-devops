#!/usr/bin/env bash
# Offline checks for the Muse Code engine of bin/ai-muse (AI_MUSE_ENGINE=muse-code).
# A stub CLI stands in for Meta's binary; no provider or 1Password contact.
set -uo pipefail
# This suite also runs as a review packet's --tests evidence command, inside an
# environment that exports reviewer-event variables. The stub wrapper must not
# file suite turns as evidence for that outer review, so strip them first:
# successful commands otherwise fail during their own evidence cleanup.
unset AI_REVIEWER_STATE_BASE AI_REVIEW_EVENT_DIR AI_REVIEW_EVENT_OWNER_PID AI_REVIEW_EVENT_PARENT AI_REVIEW_EVENT_PROVIDER AI_REVIEW_EVENT_RUN_ID
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-muse"
PASS=0; FAIL=0
check(){ local label="$1" out; shift; if out="$(bash -c "$1" 2>&1)"; then printf 'PASS  %s\n' "$label"; PASS=$((PASS+1)); else printf 'FAIL  %s\n' "$label"; printf '%s\n' "$out" | tail -n 8 | sed 's/^/      /'; FAIL=$((FAIL+1)); fi; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/muse-code-test.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-review-public-fixture.sh"
ai_test_public_sources "$TMP"
command -v jq >/dev/null 2>&1 || { printf 'SKIP  jq unavailable\n'; exit 0; }
PYTHON="$(command -v python3 || command -v python)" || { printf 'SKIP  python unavailable\n'; exit 0; }

VERSION="$(tr -d ' \r\n' < "$ROOT/config/muse-code/version")"
HOME_FIX="$TMP/home"; REPO="$TMP/repo"; mkdir -p "$HOME_FIX" "$REPO" "$TMP/bin"
MBIN="$HOME_FIX/AppData/Local/Programs/muse"; mkdir -p "$MBIN"
git -C "$REPO" init -q; git -C "$REPO" config user.name Test; git -C "$REPO" config user.email t@example.com
printf '.ai/\n' > "$REPO/.gitignore"; printf 'marker\n' > "$REPO/a.txt"; git -C "$REPO" add .gitignore a.txt; git -C "$REPO" commit -qm init
printf '#!/usr/bin/env bash\nprintf fake-key\n' > "$TMP/bin/op"
cat > "$MBIN/muse-bin-$VERSION.exe" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --version) [ -z "${MUSE_STUB_SWAP:-}" ] || printf '#!/usr/bin/env bash\ntouch "%s"\n' "$MUSE_STUB_SWAP_MARK" > "$MUSE_STUB_SWAP"; [ -z "${MUSE_STUB_SIDE_ENV_FILE:-}" ] || env >> "$MUSE_STUB_SIDE_ENV_FILE"; printf 'Muse Code 1.3.0 (%s)\n' "${MUSE_STUB_VERSION:-1.3.0-R3233.1}";;
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
    # The real CLI keeps a date-bucketed durable store with per-model-call token
    # counters; the stream itself only names the run (command_id).
    run="$sid-run-$RANDOM$$"
    if [ -z "${MUSE_STUB_NO_DURABLE_STORE:-}" ]; then
      dstore="$XDG_DATA_HOME/muse/sessions/$(date +%Y/%m/%d)/$sid"; mkdir -p "$dstore"
      if [ -n "${MUSE_STUB_GARBAGE_STORE:-}" ]; then printf 'not-json\n' >> "$dstore/session.jsonl"
      else
        mrow(){ jq -cn --arg rid "$1" --arg m "${MUSE_STUB_MODEL:-muse-spark-1.3-contributor}" --argjson i "$2" --argjson o "$3" --argjson cr "$4" --argjson cw "$5" --argjson r "$6" '{payload_type:"runtime.session",payload:{run_id:$rid,event:{kind:"model_completed",model:$m,finish_reason:"stop",usage:{input_tokens:$i,output_tokens:$o,cached_tokens:$cr,cache_write_tokens:$cw,cache_read_tokens:$cr,reasoning_tokens:$r}}}}'; }
        mrow "$run" 19835 472 8561 0 387 >> "$dstore/session.jsonl"
        mrow 11111111-2222-4333-8444-555555555555 999999 999999 999999 0 999999 >> "$dstore/session.jsonl"
      fi
    fi
    ev(){ jq -cn --arg sid "$1" --arg t "$2" --argjson p "$3" '{stream:{kind:"session",id:$sid},payload_type:$t,payload:$p}'; }
    [ -n "${MUSE_STUB_NO_RUN_ID:-}" ] || ev "$sid" runtime.command.accepted "$(jq -cn --arg cid "$run" '{kind:"command_accepted",command_id:$cid,command_kind:"exec"}')"
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
    [ -z "${MUSE_STUB_SIDE_ENV_FILE:-}" ] || env >> "$MUSE_STUB_SIDE_ENV_FILE"
    sid=''; out=''; while [ $# -gt 0 ]; do case "$1" in --session) sid="$2"; shift;; --out) out="$2"; shift;; esac; shift; done
    jq -n --arg sid "$sid" '{sessions:[{session_id:$sid}]}' > "$out";;
  *) exit 2;;
esac
EOF
chmod +x "$TMP/bin/op" "$MBIN/muse-bin-$VERSION.exe"
# The fingerprint has no override: run a private copy of the tool that pins the stub.
mkdir -p "$TMP/tool"; cp -R "$ROOT/bin" "$ROOT/config" "$ROOT/tools" "$TMP/tool/"; SCRIPT="$TMP/tool/bin/ai-muse"
sha256sum "$MBIN/muse-bin-$VERSION.exe" | cut -d' ' -f1 > "$TMP/tool/config/muse-code/sha256"
STORE="$HOME_FIX/.local/share/ai-devops/muse-code/muse/sessions/.msp-view-v1"
ENV="USERPROFILE='$HOME_FIX' HOME='$TMP/roaming-home' PATH='$TMP/bin:$PATH' AI_MUSE_STATE_DIR='$TMP/state' AI_REVIEW_SANDBOX_DIR='$TMP/sandboxes' AI_MUSE_CALLER=claude AI_MUSE_ENGINE=muse-code AI_MUSE_TEST_DIR='$TMP' MUSE_STUB_ENV_FILE='$TMP/provider-env' MUSE_STUB_ARGS_FILE='$TMP/provider-args'"
# First-party model catalog (#542 Phase B): the healthy row is the default state;
# the drift checks below mutate it per case. Any *.json name must do - the real
# file name is a provider/profile encoding the wrapper must not depend on.
CATALOG="$HOME_FIX/.local/share/ai-devops/muse-code/muse/model-catalog"
CATALOG_ROW='{"model_id":"muse-spark-1.3-contributor","provider_id":"meta","visibility":"visible","context_limit":1007997,"output_limit":128000,"is_current":true,"cost":{"input":"0.10","output":"0.20","cached":"0.002","currency":"USD"}}'
write_catalog(){ local row="${1:-$CATALOG_ROW}"; mkdir -p "$CATALOG"; rm -f "$CATALOG"/*.json; printf '{"profile_id":"tbh","provider_id":"meta","rows":[%s],"schema_version":1,"source":"provider_catalog"}' "$row" > "$CATALOG/teststub__glob.json"; }
write_catalog

check 'unknown engine refuses before any work' "cd '$REPO' && ! eval \"$ENV AI_MUSE_ENGINE=bogus '$SCRIPT' doctor\" 2>&1 | grep -q PASS"
check 'reviewer_usage muse-code adapter unit cases' "'$PYTHON' '$ROOT/tests/fixtures/muse-code/usage_cases.py' -q"
check 'deletion admission refuses inaccessible parents without claiming absent stores' "bash '$ROOT/tests/fixtures/muse-code/delete_cases.sh'"
check 'default engine is muse-code' "cd '$REPO' && eval \"USERPROFILE='$HOME_FIX' PATH='$TMP/bin:$PATH' AI_MUSE_CALLER=claude '$SCRIPT' doctor\" 2>&1 | grep -q 'engine: muse-code'"
check 'doctor proves the pinned Muse Code version' "cd '$REPO' && eval \"$ENV '$SCRIPT' doctor\" | grep -q 'PASS  Muse Code is the pinned'"
check 'doctor refuses an unpinned Muse Code version' "cd '$REPO' && rm -f '$HOME_FIX/.local/share/ai-devops/muse-code-bin/'.verified-* && ! eval \"$ENV MUSE_STUB_VERSION=9.9.9 '$SCRIPT' doctor\""
check 'doctor reads the first-party catalog and reports limits, price and currency' "cd '$REPO' && out=\$(eval \"$ENV '$SCRIPT' doctor\"); rc=\$?; [ \$rc -eq 0 ] && printf '%s\\n' \"\$out\" | grep -q 'PASS  Muse Code model catalog is present and parseable' && printf '%s\\n' \"\$out\" | grep -q 'PASS  model catalog has a row for muse-spark-1.3-contributor' && printf '%s\\n' \"\$out\" | grep -q 'PASS  model row for muse-spark-1.3-contributor is visible' && printf '%s\\n' \"\$out\" | grep -q 'context_limit=1007997' && printf '%s\\n' \"\$out\" | grep -q 'output_limit=128000' && printf '%s\\n' \"\$out\" | grep -q 'input=0.10' && printf '%s\\n' \"\$out\" | grep -q 'cached=0.002' && printf '%s\\n' \"\$out\" | grep -q 'is_current=true'"
# #773: the review preflight gives this doctor 10s on hosts where a jq launch or
# a 400 MB hash costs about a second each, so its launches stay bounded.
mkdir -p "$TMP/countbin"; for tool in sha256sum jq dirname; do real="$(command -v "$tool")"; printf '#!/usr/bin/env bash\nprintf "%%s\n" "$*" >> %q\nexec %q "$@"\n' "$TMP/count-$tool" "$real" > "$TMP/countbin/$tool"; chmod +x "$TMP/countbin/$tool"; done
check 'doctor hashes the Muse binary at most twice and launches jq at most four times and dirname at most three' "cd '$REPO' && rm -f '$TMP/count-sha256sum' '$TMP/count-jq' '$TMP/count-dirname' && eval \"$ENV PATH='$TMP/countbin:$TMP/bin:$PATH' '$SCRIPT' doctor\" >/dev/null && [ \$(cat '$TMP/count-sha256sum' 2>/dev/null | grep -c 'muse') -le 2 ] && [ \$(wc -l < '$TMP/count-jq') -le 4 ] && [ \$(cat '$TMP/count-dirname' 2>/dev/null | wc -l) -le 3 ]"
STAGED="$HOME_FIX/.local/share/ai-devops/muse-code-bin"
check 'a warm doctor reuses the identity record: no hash and no version launch' "cd '$REPO' && eval \"$ENV '$SCRIPT' doctor\" >/dev/null && ls '$STAGED'/.verified-* >/dev/null && rm -f '$TMP/count-sha256sum' && eval \"$ENV PATH='$TMP/countbin:$TMP/bin:$PATH' '$SCRIPT' doctor\" | grep -q 'PASS  Muse Code is the pinned' && [ \$(cat '$TMP/count-sha256sum' 2>/dev/null | grep -c 'muse') -eq 0 ]"
check 'touching the installed binary forces a full re-hash' "cd '$REPO' && touch -d '+2 minutes' '$MBIN/muse-bin-$VERSION.exe' && rm -f '$TMP/count-sha256sum' && eval \"$ENV PATH='$TMP/countbin:$TMP/bin:$PATH' '$SCRIPT' doctor\" | grep -q 'PASS  Muse Code is the pinned' && [ \$(grep -c 'muse' '$TMP/count-sha256sum') -ge 1 ]"
check 'a changed staged copy is re-verified and replaced, never trusted from the record' "cd '$REPO' && f=\$(ls '$STAGED'/muse-*.exe) && printf 'x' >> \"\$f\" && rm -f '$TMP/count-sha256sum' && eval \"$ENV PATH='$TMP/countbin:$TMP/bin:$PATH' '$SCRIPT' doctor\" | grep -q 'PASS  Muse Code is the pinned' && [ \$(grep -c 'muse' '$TMP/count-sha256sum') -ge 2 ] && ! tail -c1 \"\$f\" | grep -q x"
write_catalog '{"model_id":"muse-spark-1.4-max","visibility":"visible","context_limit":1000,"output_limit":1000,"is_current":false,"cost":{"input":"1","output":"2","cached":"0.1","currency":"USD"}}'
check 'doctor fails when the catalog has no row for the configured model' "cd '$REPO' && out=\$(eval \"$ENV '$SCRIPT' doctor\"); rc=\$?; [ \$rc -ne 0 ] && printf '%s\\n' \"\$out\" | grep -q 'FAIL  model catalog has a row for muse-spark-1.3-contributor'"
write_catalog '{"model_id":"muse-spark-1.3-contributor","provider_id":"meta","visibility":"hidden","context_limit":1007997,"output_limit":128000,"is_current":true,"cost":{"input":"0.10","output":"0.20","cached":"0.002","currency":"USD"}}'
check 'doctor fails when the catalog row is not visible' "cd '$REPO' && out=\$(eval \"$ENV '$SCRIPT' doctor\"); rc=\$?; [ \$rc -ne 0 ] && printf '%s\\n' \"\$out\" | grep -q 'FAIL  model row for muse-spark-1.3-contributor is visible'"
write_catalog '{"model_id":"muse-spark-1.3-contributor","provider_id":"meta","visibility":"visible","context_limit":1007997,"output_limit":128000,"is_current":false,"cost":{"input":"0.10","output":"0.20","cached":"0.002","currency":"USD"}}'
check 'doctor warns loudly but passes when the catalog row is not current' "cd '$REPO' && out=\$(eval \"$ENV '$SCRIPT' doctor\"); rc=\$?; [ \$rc -eq 0 ] && printf '%s\\n' \"\$out\" | grep -q 'WARN  ' && printf '%s\\n' \"\$out\" | grep -q 'is_current: false'"
write_catalog
mkdir -p "$CATALOG"; rm -f "$CATALOG"/*.json; printf 'not-json\n' > "$CATALOG/broken__file.json"
check 'doctor fails on an unparseable catalog file' "cd '$REPO' && out=\$(eval \"$ENV '$SCRIPT' doctor\"); rc=\$?; [ \$rc -ne 0 ] && printf '%s\\n' \"\$out\" | grep -q 'FAIL  Muse Code model catalog is present and parseable'"
write_catalog
printf 'not-json\n' > "$CATALOG/broken__sibling.json"
check 'doctor refuses a valid row beside an unreadable sibling: uniqueness is unprovable' "cd '$REPO' && out=\$(eval \"$ENV '$SCRIPT' doctor\"); rc=\$?; [ \$rc -ne 0 ] && printf '%s\\n' \"\$out\" | grep -q 'PASS  Muse Code model catalog is present and parseable' && printf '%s\\n' \"\$out\" | grep -q 'FAIL  model catalog has a row for muse-spark-1.3-contributor'"
write_catalog
write_catalog '{"model_id":"unrelated-model","visibility":"visible","context_limit":1,"output_limit":1,"is_current":true,"cost":{"input":"1","output":"1","cached":"1","currency":"USD"}}'
printf '{"rows":{"nested":{"model_id":"muse-spark-1.3-contributor","visibility":"visible","context_limit":1,"output_limit":1,"is_current":true}}}' > "$CATALOG/malformed__rows-object.json"
check 'doctor never takes the model row from a malformed rows-object file' "cd '$REPO' && out=\$(eval \"$ENV '$SCRIPT' doctor\"); rc=\$?; [ \$rc -ne 0 ] && printf '%s\\n' \"\$out\" | grep -q 'PASS  Muse Code model catalog is present and parseable' && printf '%s\\n' \"\$out\" | grep -q 'FAIL  model catalog has a row for muse-spark-1.3-contributor'"
write_catalog
printf '{"profile_id":"tbh","provider_id":"meta","rows":[%s],"schema_version":1,"source":"provider_catalog"}' "$CATALOG_ROW" > "$CATALOG/second__file.json"
check 'doctor refuses an ambiguous duplicate model row across catalog files' "cd '$REPO' && out=\$(eval \"$ENV '$SCRIPT' doctor\"); rc=\$?; [ \$rc -ne 0 ] && printf '%s\\n' \"\$out\" | grep -q 'FAIL  model catalog has a row for muse-spark-1.3-contributor'"
write_catalog '{"model_id":"muse-spark-1.3-contributor","provider_id":"someone-else","visibility":"visible","context_limit":1007997,"output_limit":128000,"is_current":true,"cost":{"input":"0.10","output":"0.20","cached":"0.002","currency":"USD"}}'
check 'doctor refuses a model row from a foreign provider' "cd '$REPO' && out=\$(eval \"$ENV '$SCRIPT' doctor\"); rc=\$?; [ \$rc -ne 0 ] && printf '%s\\n' \"\$out\" | grep -q 'FAIL  model catalog has a row for muse-spark-1.3-contributor'"
write_catalog '{"model_id":"unrelated-model","provider_id":"meta","visibility":"visible","context_limit":1,"output_limit":1,"is_current":true,"cost":{"input":"1","output":"1","cached":"1","currency":"USD"}}'
printf '{"profile_id":"tbh","provider_id":"meta","rows":[%s],"schema_version":1,"source":"manual"}' '{"model_id":"muse-spark-1.3-contributor","provider_id":"meta","visibility":"visible","context_limit":1007997,"output_limit":128000,"is_current":true,"cost":{"input":"0.10","output":"0.20","cached":"0.002","currency":"USD"}}' > "$CATALOG/manual__file.json"
check 'doctor prices only from first-party provider_catalog files' "cd '$REPO' && out=\$(eval \"$ENV '$SCRIPT' doctor\"); rc=\$?; [ \$rc -ne 0 ] && printf '%s\\n' \"\$out\" | grep -q 'PASS  Muse Code model catalog is present and parseable' && printf '%s\\n' \"\$out\" | grep -q 'FAIL  model catalog has a row for muse-spark-1.3-contributor'"
write_catalog
# A linked catalog directory must not be trusted as the first-party catalog,
# even when its files are perfectly healthy behind the link.
if (mkdir -p "$TMP/jt2" && cmd //c mklink //J "$(cygpath -w "$TMP/jt2-link")" "$(cygpath -w "$TMP/jt2")" >/dev/null 2>&1 && test -L "$TMP/jt2-link"); then
  rm -rf "$TMP/jt2-link" "$TMP/jt2"
  mv "$CATALOG" "$TMP/real-catalog"
  cmd //c mklink //J "$(cygpath -w "$CATALOG")" "$(cygpath -w "$TMP/real-catalog")" >/dev/null
  check 'doctor refuses a linked catalog directory' "cd '$REPO' && out=\$(eval \"$ENV '$SCRIPT' doctor\"); rc=\$?; [ \$rc -ne 0 ] && printf '%s\\n' \"\$out\" | grep -q 'FAIL  Muse Code model catalog is present and parseable'"
  cmd //c rmdir "$(cygpath -w "$CATALOG")" >/dev/null 2>&1
  rm -rf "$TMP/real-catalog"
  write_catalog
else printf 'SKIP  doctor refuses a linked catalog directory (no junctions)
'; fi
check 'turn refuses an unpinned Muse Code version without contact' "cd '$REPO' && rm -f '$TMP/provider-args' '$HOME_FIX/.local/share/ai-devops/muse-code-bin/'.verified-* && ! eval \"$ENV MUSE_STUB_VERSION=9.9.9 '$SCRIPT' new pin --prompt test\" && test ! -e '$TMP/provider-args'"
check 'new session completes and returns the final answer' "cd '$REPO' && eval \"$ENV '$SCRIPT' new first --prompt test\" | grep -qx first"
check 'provider prompt demands all findings and sibling issues' "grep -rq 'Return ALL findings in one pass' '$REPO/.ai/reviews' && grep -rq 'sibling issues' '$REPO/.ai/reviews' && grep -rq 'MANIFEST.md first' '$REPO/.ai/reviews'"
check 'launch is read-only: no write, shell, web, personal context or prompts' "for f in exec --json --disable-write --disable-shell --disable-web-tools --no-foreign-personal-context --user-input-auto-resolve; do grep -qx -- \"\$f\" '$TMP/provider-args' || exit 1; done && grep -qx 'muse-spark-1.3-contributor' '$TMP/provider-args'"
check 'provider gets the key only as META_API_KEY' "grep -qx 'META_API_KEY=fake-key' '$TMP/provider-env' && ! grep -q '^MODEL_API_KEY=' '$TMP/provider-env' && ! grep -q '^AI_MUSE_KEY_ENV=' '$TMP/provider-env' && ! grep -q '^AI_MUSE_SECRET_FILE=' '$TMP/provider-env'"
check 'prompt that looks like options never reaches the argument list' "cd '$REPO' && eval \"$ENV '$SCRIPT' new optprompt --prompt '--workspace=C:/ --enable-write'\" && ! grep -q -- '--enable-write' '$TMP/provider-args' && grep -qx -- --prompt-file '$TMP/provider-args'"
check 'key never appears in provider arguments' "! grep -q fake-key '$TMP/provider-args'"
check 'provider uses private isolated stores' "grep -q '^XDG_DATA_HOME=.*ai-devops/muse-code' '$TMP/provider-env' && grep -q '^XDG_CONFIG_HOME=.*muse-code-xdg' '$TMP/provider-env'"
check 'private stores exist with owner-only modes' "for d in '$HOME_FIX/.local/share/ai-devops/muse-code' '$HOME_FIX/.local/state/ai-devops/muse-code' '$HOME_FIX/.cache/ai-devops/muse-code'; do test -d \"\$d\" || exit 1; done && ! ls '$HOME_FIX/.local/state/ai-devops/muse-code'/export-*.json 2>/dev/null"
check 'wrapper chooses and records a UUID session identity' "cd '$REPO' && eval \"$ENV '$SCRIPT' show first\" | jq -e '.status==\"active\" and (.session_id|test(\"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$\"))'"
check 'follow-up resumes the exact recorded session' "cd '$REPO' && eval \"$ENV '$SCRIPT' ask first --prompt again\" | grep -qx remembered && grep -qx \"\$(eval \"$ENV '$SCRIPT' show first\" | jq -r .session_id)\" '$TMP/provider-args'"
check 'usage is scoped to this turn run and maps the durable store' "cd '$REPO' && u=\$(eval \"$ENV '$SCRIPT' show first\" | jq -r .retained_turn.usage_json) && printf '%s' \"\$u\" | jq -e '.completeness==\"core-complete\" and .model_calls==1 and .counters.input==19835 and .counters.output==472 and .counters.cache_read==8561 and .counters.cache_write==0 and .counters.reasoning==387 and .counters.total==null and .counters.cost==null and (.counter_provenance|startswith(\"muse-code-\"))' >/dev/null && ! printf '%s' \"\$u\" | grep -q 999999"
check 'usage carries the catalog-priced estimate for the summed counters' "cd '$REPO' && eval \"$ENV '$SCRIPT' new catpriced --prompt test\" >/dev/null && u=\$(eval \"$ENV '$SCRIPT' show catpriced\" | jq -r .retained_turn.usage_json) && printf '%s' \"\$u\" | jq -e '.catalog_cost_estimate==0.001238922 and .catalog_cost_currency==\"USD\" and .cost_provenance==\"first-party model catalog price; estimate, not billed cost\" and .counters.input==19835 and .counters.cache_read==8561 and .counters.output==472' >/dev/null"
rm -f "$CATALOG"/*.json
check 'absent catalog leaves the estimate null and completeness intact' "cd '$REPO' && eval \"$ENV '$SCRIPT' new nocatalog --prompt test\" | grep -qx first && u=\$(eval \"$ENV '$SCRIPT' show nocatalog\" | jq -r .retained_turn.usage_json) && printf '%s' \"\$u\" | jq -e '.completeness==\"core-complete\" and .catalog_cost_estimate==null and .catalog_cost_currency==null' >/dev/null"
check 'a run answered on another model is never priced with this models row' "cd '$REPO' && eval \"$ENV MUSE_STUB_MODEL=muse-spark-1.3 '$SCRIPT' new foreignmodel --prompt test\" >/dev/null && u=\$(eval \"$ENV '$SCRIPT' show foreignmodel\" | jq -r .retained_turn.usage_json) && printf '%s' \"\$u\" | jq -e '.completeness==\"core-complete\" and .counters.input==19835 and .catalog_cost_estimate==null and .catalog_cost_currency==null' >/dev/null"
write_catalog
check 'report records durable-store usage counters, never invented ones' "grep -q '\"input\": 19835' '$REPO'/.ai/reviews/muse-first-*.md && grep -q 'durable-store-model-completed' '$REPO'/.ai/reviews/muse-first-*.md && ! grep -q 999999 '$REPO'/.ai/reviews/muse-first-*.md"
check 'missing durable store keeps the turn complete and usage honestly unavailable' "cd '$REPO' && eval \"$ENV MUSE_STUB_NO_DURABLE_STORE=1 '$SCRIPT' new nostore --prompt test\" | grep -qx first && u=\$(eval \"$ENV '$SCRIPT' show nostore\" | jq -r .retained_turn.usage_json) && printf '%s' \"\$u\" | jq -e '.completeness==\"unavailable\" and .availability_reason==\"durable-store-unreadable\"' >/dev/null && grep -q 'durable-store-unreadable' '$REPO'/.ai/reviews/muse-nostore-*.md"
check 'garbage durable store keeps the turn complete and usage honestly unavailable' "cd '$REPO' && eval \"$ENV MUSE_STUB_GARBAGE_STORE=1 '$SCRIPT' new garbage --prompt test\" | grep -qx first && u=\$(eval \"$ENV '$SCRIPT' show garbage\" | jq -r .retained_turn.usage_json) && printf '%s' \"\$u\" | jq -e '.completeness==\"unavailable\" and .availability_reason==\"durable-store-unreadable\"' >/dev/null"
check 'stream without a run id keeps the turn complete and usage honestly unavailable' "cd '$REPO' && eval \"$ENV MUSE_STUB_NO_RUN_ID=1 '$SCRIPT' new norunid --prompt test\" | grep -qx first && u=\$(eval \"$ENV '$SCRIPT' show norunid\" | jq -r .retained_turn.usage_json) && printf '%s' \"\$u\" | jq -e '.completeness==\"unavailable\" and .availability_reason==\"usage-run-id-unresolved\"' >/dev/null"
check 'a replaced binary claiming the pinned version never runs, whatever the caller sets' "cd '$REPO' && cp '$MBIN/muse-bin-$VERSION.exe' '$TMP/stub.keep' && printf '# tampered\n' >> '$MBIN/muse-bin-$VERSION.exe' && rm -f '$TMP/provider-args' '$TMP/side-env' && ! eval \"$ENV MUSE_STUB_SIDE_ENV_FILE='$TMP/side-env' AI_MUSE_TEST_MUSE_CODE_SHA256=\$(sha256sum '$MBIN/muse-bin-$VERSION.exe' | cut -d' ' -f1) '$SCRIPT' new swapped --prompt test\"; rc=\$?; cp '$TMP/stub.keep' '$MBIN/muse-bin-$VERSION.exe'; [ \$rc -eq 0 ] && test ! -e '$TMP/provider-args' && test ! -e '$TMP/side-env'"
check 'swapping the installed binary after the check never runs the swapped file' "cd '$REPO' && cp '$MBIN/muse-bin-$VERSION.exe' '$TMP/stub.keep2' && rm -f '$TMP/swap-mark' && out=\$(eval \"$ENV MUSE_STUB_SWAP='$MBIN/muse-bin-$VERSION.exe' MUSE_STUB_SWAP_MARK='$TMP/swap-mark' '$SCRIPT' new swaprace --prompt test\"); rc=\$?; cp '$TMP/stub.keep2' '$MBIN/muse-bin-$VERSION.exe'; [ \$rc -eq 0 ] && [ \"\$out\" = first ] && test ! -e '$TMP/swap-mark'"
check 'the shipped fingerprint is a SHA-256' "grep -Eqx '[0-9a-f]{64}' '$ROOT/config/muse-code/sha256'"
check 'transcript refuses an unpinned Muse Code binary' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_VERSION=9.9.9 '$SCRIPT' transcript first\" 2>/dev/null | grep -q session_id"
check 'version checks and exports never see unrelated caller secrets' "cd '$REPO' && rm -f '$TMP/side-env' && eval \"$ENV MUSE_STUB_SIDE_ENV_FILE='$TMP/side-env' LEAKY_TOKEN=leak-marker-7Q2Z '$SCRIPT' transcript first\" >/dev/null && { grep -q '^XDG_DATA_HOME=' '$TMP/side-env' || { echo 'no provider environment was recorded'; exit 1; }; } && { ! grep -nE 'LEAKY_TOKEN|leak-marker-7Q2Z' '$TMP/side-env' || { echo 'caller secret reached the provider'; exit 1; }; }"
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
# Link refusal on an ancestor of the session store. A directory junction needs no
# special Windows privilege; Git Bash reports it as a link.
ANC="$HOME_FIX/.local/share/ai-devops/muse-code/muse"
if (mkdir -p "$TMP/jt" && cmd //c mklink //J "$(cygpath -w "$TMP/jt-link")" "$(cygpath -w "$TMP/jt")" >/dev/null 2>&1 && test -L "$TMP/jt-link"); then
  check 'delete refuses a session store behind a linked ancestor' "cd '$REPO' && eval \"$ENV '$SCRIPT' new linked --prompt test\" >/dev/null && sid=\"\$(eval \"$ENV '$SCRIPT' show linked\" | jq -r .session_id)\" && mv '$ANC' '$TMP/decoy' && cmd //c mklink //J \"\$(cygpath -w '$ANC')\" \"\$(cygpath -w '$TMP/decoy')\" >/dev/null && ! eval \"$ENV '$SCRIPT' delete linked\"; rc=\$?; test -d '$TMP/decoy/sessions/.msp-view-v1/'\"\$sid\" || rc=1; cmd //c rmdir \"\$(cygpath -w '$ANC')\" >/dev/null 2>&1; mv '$TMP/decoy' '$ANC'; exit \$rc"
else printf 'SKIP  delete refuses a session store behind a linked ancestor (no junctions)
'; fi
check 'source repository is untouched' "test -z \"\$(git -C '$REPO' status --porcelain)\""

# Phase C exercises the public commands against the stub, including metadata.
phase_c_check(){
  local label="$1"; shift
  if ("$@") >"$TMP/phase-c.log" 2>&1; then
    printf 'PASS  %s\n' "$label"; PASS=$((PASS+1))
  else
    printf 'FAIL  %s\n' "$label"; tail -n 8 "$TMP/phase-c.log" | sed 's/^/      /'; FAIL=$((FAIL+1))
  fi
}
phase_c_turn(){
  local name="$1" effort="$2" expected="$3" command="${4:-new}"
  cd "$REPO" || return 1
  rm -f "$TMP/provider-args"
  if [ "$effort" = UNSET ]; then
    unset AI_MUSE_REASONING_EFFORT
    eval "$ENV '$SCRIPT' $command '$name' --prompt test" >/dev/null || return 1
  else
    eval "$ENV AI_MUSE_REASONING_EFFORT='$effort' '$SCRIPT' $command '$name' --prompt test" >/dev/null || return 1
  fi
  eval "$ENV '$SCRIPT' show '$name'" | jq -e --arg effort "$expected" '.retained_turn.reasoning_effort==$effort' >/dev/null || return 1
  if [ "$effort" = UNSET ] || [ -z "$effort" ]; then
    ! grep -qx -- --reasoning-effort "$TMP/provider-args"
  else
    awk -v expected="$effort" '$0=="--reasoning-effort" {getline; if ($0==expected) found++} END {exit found!=1}' "$TMP/provider-args"
  fi
}
phase_c_refusal(){
  local name="$1" effort="$2"
  cd "$REPO" || return 1
  rm -f "$TMP/provider-args"
  ! eval "$ENV AI_MUSE_REASONING_EFFORT='$effort' '$SCRIPT' new '$name' --prompt test" >"$TMP/effort-refusal.log" 2>&1 &&
    test ! -e "$TMP/provider-args" && grep -q start_failed "$TMP/effort-refusal.log"
}
write_catalog "$(printf '%s' "$CATALOG_ROW" | jq '.reasoning_effort_variants=["minimal","low","medium","high","max"]')"
phase_c_check 'unset reasoning omits the flag and retains the effective high default' phase_c_turn effort-default UNSET high
phase_c_check 'empty reasoning omits the flag and retains the effective high default' phase_c_turn effort-empty '' high
phase_c_check 'explicit catalog reasoning is sent once and retained' phase_c_turn effort-explicit medium medium
phase_c_invalid_ask(){
  cd "$REPO" || return 1
  local before after
  before="$(eval "$ENV '$SCRIPT' show effort-explicit")" || return 1
  rm -f "$TMP/provider-args"
  ! eval "$ENV AI_MUSE_REASONING_EFFORT=bogus '$SCRIPT' ask effort-explicit --prompt test" >"$TMP/effort-refusal.log" 2>&1 || return 1
  after="$(eval "$ENV '$SCRIPT' show effort-explicit")" || return 1
  [ "$before" = "$after" ] && test ! -e "$TMP/provider-args" && grep -q start_failed "$TMP/effort-refusal.log"
}
phase_c_check 'invalid follow-up reasoning preserves the complete active session unchanged' phase_c_invalid_ask
phase_c_check 'ask can override the preceding reasoning choice' phase_c_turn effort-explicit low low ask
phase_c_check 'ask without an override restores the effective high default' phase_c_turn effort-explicit UNSET high ask
phase_c_check 'invalid reasoning refuses before provider contact' phase_c_refusal effort-invalid bogus
phase_c_check 'catalog exclusions override the fixed CLI list' phase_c_refusal effort-excluded ultra
write_catalog "$(printf '%s' "$CATALOG_ROW" | jq '.reasoning_effort_variants=[]')"
phase_c_check 'a readable empty variants list refuses explicit reasoning' phase_c_refusal effort-no-variants high
write_catalog
phase_c_check 'a readable row missing variants refuses explicit reasoning' phase_c_refusal effort-missing-variants high
write_catalog "$(printf '%s' "$CATALOG_ROW" | jq '.reasoning_effort_variants="high"')"
phase_c_check 'a readable malformed variants field refuses explicit reasoning' phase_c_refusal effort-malformed-variants high
write_catalog "$(printf '%s' "$CATALOG_ROW" | jq '.reasoning_effort_variants=["high",4]')"
phase_c_check 'a readable mixed-type variants list refuses explicit reasoning' phase_c_refusal effort-mixed-variants high
rm -f "$CATALOG"/*.json
for effort in none minimal low medium high xhigh max ultra; do
  phase_c_check "unavailable catalog accepts fixed-list reasoning $effort" phase_c_turn "effort-fallback-$effort" "$effort" "$effort"
done
phase_c_check 'unavailable catalog still rejects invalid reasoning' phase_c_refusal effort-fallback-invalid bogus
write_catalog

phase_c_delete(){
  local name="$1" missing="${2:-no}" sid base other=99999999-2222-4333-8444-555555555555
  cd "$REPO" || return 1
  eval "$ENV '$SCRIPT' new '$name' --prompt test" >/dev/null || return 1
  sid="$(eval "$ENV '$SCRIPT' show '$name'" | jq -er .session_id)" || return 1
  base="${STORE%/.msp-view-v1}"
  # Multiple date buckets prove cleanup is UUID-scoped, not today's path only.
  mkdir -p "$base/2001/02/03/$sid" "$base/2001/02/03/$other" "$STORE/$other"
  printf keep > "$base/2001/02/03/$other/session.jsonl"
  printf keep > "$STORE/$other/HEAD.json"
  [ "$missing" != yes ] || rm -rf "$STORE/$sid"
  eval "$ENV '$SCRIPT' delete '$name'" || return 1
  test ! -e "$STORE/$sid" &&
    test ! -e "$base/$(date +%Y/%m/%d)/$sid" &&
    test ! -e "$base/2001/02/03/$sid" &&
    test "$(cat "$base/2001/02/03/$other/session.jsonl")" = keep &&
    test "$(cat "$STORE/$other/HEAD.json")" = keep &&
    ! eval "$ENV '$SCRIPT' show '$name'" >/dev/null 2>&1
}
phase_c_check 'delete removes projection and every durable date bucket, preserving other UUIDs' phase_c_delete delete-both
phase_c_check 'missing projection does not skip durable deletion' phase_c_delete delete-durable-only yes

phase_c_link(){
  local kind="$1" position="$2" name="delete-$1-$2" sid target decoy rc=0
  cd "$REPO" || return 1
  eval "$ENV '$SCRIPT' new '$name' --prompt test" >/dev/null || return 1
  sid="$(eval "$ENV '$SCRIPT' show '$name'" | jq -er .session_id)" || return 1
  target="${STORE%/.msp-view-v1}/$(date +%Y/%m/%d)/$sid"
  [ "$position" != parent ] || target="${target%/$sid}"
  decoy="$TMP/decoy-$kind-$position"
  mv "$target" "$decoy" || return 1
  if [ "$kind" = junction ]; then
    cmd //c mklink //J "$(cygpath -w "$target")" "$(cygpath -w "$decoy")" >/dev/null || { mv "$decoy" "$target"; return 1; }
  else
    MSYS=winsymlinks:nativestrict ln -s "$decoy" "$target" || { mv "$decoy" "$target"; return 1; }
  fi
  ! eval "$ENV '$SCRIPT' delete '$name'" >"$TMP/delete-refusal.log" 2>&1 || rc=1
  grep -q 'durable store deletion unconfirmed' "$TMP/delete-refusal.log" || rc=1
  # Refusal must precede deletion of either store and preserve recovery metadata.
  test -f "$STORE/$sid/HEAD.json" || rc=1
  if [ "$position" = parent ]; then test -f "$decoy/$sid/session.jsonl" || rc=1
  else test -f "$decoy/session.jsonl" || rc=1; fi
  eval "$ENV '$SCRIPT' show '$name'" | jq -e '.status=="active"' >/dev/null || rc=1
  if [ "$kind" = junction ]; then cmd //c rmdir "$(cygpath -w "$target")" >/dev/null
  else rm "$target"; fi
  mv "$decoy" "$target" || rc=1
  return "$rc"
}
mkdir -p "$TMP/link-probe-target"
if MSYS=winsymlinks:nativestrict ln -s "$TMP/link-probe-target" "$TMP/link-probe" 2>/dev/null && [ -L "$TMP/link-probe" ]; then
  rm "$TMP/link-probe"
  phase_c_check 'delete refuses a symlink at a durable UUID leaf before deleting any store' phase_c_link symlink leaf
  phase_c_check 'delete refuses a symlink at a durable date parent before deleting any store' phase_c_link symlink parent
else printf 'SKIP  durable symlink refusal (native symlinks unavailable)\n'; fi
if command -v cygpath >/dev/null && cmd //c mklink //J "$(cygpath -w "$TMP/junction-probe")" "$(cygpath -w "$TMP/link-probe-target")" >/dev/null 2>&1; then
  cmd //c rmdir "$(cygpath -w "$TMP/junction-probe")" >/dev/null
  phase_c_check 'delete refuses a junction at a durable UUID leaf before deleting any store' phase_c_link junction leaf
  phase_c_check 'delete refuses a junction at a durable date parent before deleting any store' phase_c_link junction parent
else printf 'SKIP  durable junction refusal (junctions unavailable)\n'; fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
