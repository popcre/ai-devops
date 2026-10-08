#!/usr/bin/env bash
# Offline installation-context proofs; every credential/API response is synthetic.
set -u
if [ "$(uname -s)" != Linux ]; then
  printf 'App read-sharing context is Linux-qualified; original token behavior is unchanged.\n'
  exit 0
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-gh-app-auth"
REAL_CURL="$(command -v curl)"; ORIGINAL_PATH="$PATH"
TMP="$(mktemp -d)"; trap 'rm -rf -- "$TMP"' EXIT
PASS=0; FAIL=0
check(){ if eval "$2" >/dev/null 2>&1; then PASS=$((PASS+1)); else printf 'FAIL %s\n' "$1"; FAIL=$((FAIL+1)); fi; }
umask 077
mkdir -p "$TMP/bin" "$TMP/app" "$TMP/api"; chmod 700 "$TMP/app"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:1024 -out "$TMP/app/pop-ai-watchers.pem" >/dev/null 2>&1 || exit 1
cat > "$TMP/bin/curl" <<'CURL'
#!/usr/bin/env bash
[ "${1:-}" = -q ] || { echo ambient-config-enabled >> "$FIXTURE/audit"; exit 2; }
case " $* " in *' Authorization: Bearer '*) echo jwt-in-argv >> "$FIXTURE/audit"; exit 2 ;; esac
config_stdin=0; previous=''
for argument in "$@"; do
  [ "$previous" != --config ] || [ "$argument" != - ] || config_stdin=1
  previous="$argument"
done
[ "$config_stdin" = 1 ] || { echo missing-protected-header >> "$FIXTURE/audit"; exit 2; }
config="$(cat)"
if [[ "$config" = *$'\n'* ]] || ! printf '%s\n' "$config" |
  grep -Eq '^header = "Authorization: Bearer [A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+"$'; then
  echo malformed-protected-header >> "$FIXTURE/audit"; exit 2
fi
echo authenticated-stdin >> "$FIXTURE/audit"
url="${!#}"
case "$url" in
  */users/o/installation) echo installation >> "$FIXTURE/calls"; cat "$FIXTURE/installation" ;;
  */app/installations/42/access_tokens) echo token >> "$FIXTURE/calls"; cat "$FIXTURE/token" ;;
  *) exit 2 ;;
esac
CURL
chmod +x "$TMP/bin/curl"
export PATH="$TMP/bin:$PATH" AI_GH_APP_DIR="$TMP/app" FIXTURE="$TMP/api"
unset GH_TOKEN GH_HOST
printf '%s\n' '{"id":42,"app_id":5112061,"account":{"login":"o"}}' > "$FIXTURE/installation"
expiry="$(date -u -d '+1 hour' +%FT%TZ)"
jq -cn --arg expires "$expiry" '{token:"ghs_synthetic_installation",expires_at:$expires,permissions:{issues:"write",contents:"read"},repository_selection:"selected",repositories:[{id:9},{id:2}]}' > "$FIXTURE/token"
"$SCRIPT" token o > "$TMP/minted" 2> "$TMP/errors"
check 'mint preserves token bytes and uses only the original two calls' "grep -qx ghs_synthetic_installation '$TMP/minted' && [ \"\$(wc -l < '$FIXTURE/calls')\" = 2 ]"
check 'both authenticated calls receive JWT only through protected stdin' "[ \"\$(grep -cx authenticated-stdin '$FIXTURE/audit')\" = 2 ] && ! grep -q 'jwt-in-argv\|missing-protected-header\|malformed-protected-header\|ambient-config-enabled' '$FIXTURE/audit'"
check 'mint metadata stores binding fields without token or response bodies' "jq -e '.installation_id==42 and .app_id==5112061 and .repository_ids==[2,9] and .permissions.issues==\"write\" and .host==\"github.com\" and .owner==\"o\" and (has(\"token\")|not)' '$AI_GH_APP_DIR/context-o' && ! grep -q ghs_synthetic_installation '$AI_GH_APP_DIR/context-o'"
export GH_TOKEN=ghs_synthetic_installation
"$SCRIPT" context o > "$TMP/context" 2>> "$TMP/errors"
check 'local context emits only an isolated digest without a user identity' "grep -Eq '^app-v1:[0-9a-f]{64}$' '$TMP/context' && [ \"\$(wc -l < '$FIXTURE/calls')\" = 2 ] && [ ! -e '$AI_GH_APP_DIR/identities' ]"
"$SCRIPT" token o > "$TMP/cached"
check 'token reuse does not require new metadata or API calls' "cmp '$TMP/minted' '$TMP/cached' && [ \"\$(wc -l < '$FIXTURE/calls')\" = 2 ]"
cp "$AI_GH_APP_DIR/context-o" "$TMP/good-meta"; cp "$AI_GH_APP_DIR/token-o" "$TMP/good-token"
rm "$AI_GH_APP_DIR/context-o"
check 'legacy cache retains token behavior but does not share' "'$SCRIPT' token o > '$TMP/legacy' && cmp '$TMP/minted' '$TMP/legacy' && ! '$SCRIPT' context o && [ \"\$(wc -l < '$FIXTURE/calls')\" = 2 ]"
cp "$TMP/good-meta" "$AI_GH_APP_DIR/context-o"
check 'different selected token is rejected' "! GH_TOKEN=other-token '$SCRIPT' context o"
check 'different owner is rejected' "! '$SCRIPT' context other-owner"
check 'different configured App is rejected' "! AI_GH_APP_ID=42 '$SCRIPT' context o"
check 'non-github or unknown host is rejected' "! GH_HOST=other.example '$SCRIPT' context o && ! GH_HOST=unknown '$SCRIPT' context o"
chmod 755 "$AI_GH_APP_DIR"
check 'insecure directory is rejected' "! '$SCRIPT' context o"
chmod 700 "$AI_GH_APP_DIR"; chmod 644 "$AI_GH_APP_DIR/token-o"
check 'insecure token cache is rejected' "! '$SCRIPT' context o"
chmod 600 "$AI_GH_APP_DIR/token-o"; chmod 644 "$AI_GH_APP_DIR/context-o"
check 'insecure metadata is rejected' "! '$SCRIPT' context o"
chmod 600 "$AI_GH_APP_DIR/context-o"
rm "$AI_GH_APP_DIR/context-o"; ln -s "$TMP/good-meta" "$AI_GH_APP_DIR/context-o"
check 'symlink metadata is rejected and preserved' "! '$SCRIPT' context o && [ -L '$AI_GH_APP_DIR/context-o' ] && cmp '$TMP/good-meta' '$TMP/good-meta'"
rm "$AI_GH_APP_DIR/context-o"; mkfifo "$AI_GH_APP_DIR/context-o"
check 'nonregular metadata is rejected without blocking' "! timeout 3 '$SCRIPT' context o && [ -p '$AI_GH_APP_DIR/context-o' ]"
rm "$AI_GH_APP_DIR/context-o"
printf '{malformed' > "$AI_GH_APP_DIR/context-o"
check 'malformed metadata produces no context' "! '$SCRIPT' context o > '$TMP/invalid-out' 2> '$TMP/invalid-err' && [ ! -s '$TMP/invalid-out' ] && [ ! -s '$TMP/invalid-err' ]"
jq '.expires_epoch=1' "$TMP/good-meta" > "$AI_GH_APP_DIR/context-o"
check 'expired authenticated token metadata is rejected' "! '$SCRIPT' context o"
cp "$TMP/good-meta" "$AI_GH_APP_DIR/context-o"; printf '1 ghs_synthetic_installation\n' > "$AI_GH_APP_DIR/token-o"
check 'expired cached token is rejected' "! '$SCRIPT' context o"
cp "$TMP/good-token" "$AI_GH_APP_DIR/token-o"
jq '.unexpected="field"' "$TMP/good-meta" > "$AI_GH_APP_DIR/context-o"
check 'unexpected metadata fields are rejected' "! '$SCRIPT' context o"
jq '.permissions.issues="admin"' "$TMP/good-meta" > "$AI_GH_APP_DIR/context-o"
check 'unrecognized permission levels are rejected' "! '$SCRIPT' context o"
for change in '.permissions.issues="read"' '.installation_id=99' '.repository_ids=[2]' '.repository_selection="all"'; do
  jq "$change" "$TMP/good-meta" > "$AI_GH_APP_DIR/context-o"
  "$SCRIPT" context o > "$TMP/changed"
  check 'permission installation and repository scopes are separated' "! cmp -s '$TMP/context' '$TMP/changed'"
done
# A response missing optional binding data still returns exactly the original
# minted token. No repair adds a probe or reduces credential functionality.
jq 'del(.permissions)' "$FIXTURE/token" > "$FIXTURE/token.tmp"; mv "$FIXTURE/token.tmp" "$FIXTURE/token"
printf '1 ghs_synthetic_installation\n' > "$AI_GH_APP_DIR/token-o"
"$SCRIPT" token o > "$TMP/unbound" 2> "$TMP/unbound-errors"
check 'unqualified mint response retains original token and bounded calls' "cmp '$TMP/minted' '$TMP/unbound' && [ \"\$(wc -l < '$FIXTURE/calls')\" = 4 ] && grep -q 'metadata unavailable' '$TMP/unbound-errors'"
check 'unqualified renewal cannot retain an older scope binding' "! '$SCRIPT' context o"
check 'diagnostics and public context never expose token bytes' "! grep -q ghs_synthetic_installation '$TMP/errors' '$TMP/context' '$TMP/unbound-errors'"
{ printf 'set -uo pipefail\nAPI=https://api.github.com\n'; sed -n '/^app_request(){/,/^}/p' "$SCRIPT"; } > "$TMP/request-only.sh"
check 'malformed JWT cannot reach curl config' "! printf '%s\\n' 'bad\"jwt' | bash -c 'source \"\$1\"; app_request GET users/o/installation' bash '$TMP/request-only.sh'"
check 'extra config lines cannot follow an otherwise valid JWT' "! printf '%s\\n%s\\n' 'abc.def.ghi' 'url=https://other.example' | bash -c 'source \"\$1\"; app_request GET users/o/installation' bash '$TMP/request-only.sh'"
check 'invalid route config values fail before curl' "! printf '%s\\n' 'abc.def.ghi' | bash -c 'source \"\$1\"; app_request POST \"app/installations/not-an-id/access_tokens\"' bash '$TMP/request-only.sh'"
check 'malformed JWT and config attempts add no authenticated requests' "[ \"\$(wc -l < '$FIXTURE/calls')\" = 4 ] && [ \"\$(grep -cx authenticated-stdin '$FIXTURE/audit')\" = 4 ]"
mkdir -p "$TMP/hostile-home" "$TMP/local-api/users/o" "$TMP/real-curl-bin"
cp "$FIXTURE/installation" "$TMP/local-api/users/o/installation"
printf 'trace = "%s"\noutput = "%s"\n' "$TMP/ambient-trace" "$TMP/ambient-output" > "$TMP/hostile-home/.curlrc"
ln -s "$REAL_CURL" "$TMP/real-curl-bin/curl"
# This transfer reads only a local fixture through file://; it proves a real
# curl ignores hostile trace/output defaults without contacting any service.
printf 'abc.def.ghi\n' | PATH="$TMP/real-curl-bin:$ORIGINAL_PATH" HOME="$TMP/hostile-home" CURL_HOME="$TMP/hostile-home" \
  bash -c 'source "$1"; API="$2"; app_request GET users/o/installation' bash "$TMP/request-only.sh" "file://$TMP/local-api" > "$TMP/local-result"
check 'hostile ambient curlrc cannot enable traces or redirect authenticated output' "cmp '$FIXTURE/installation' '$TMP/local-result' && [ ! -e '$TMP/ambient-trace' ] && [ ! -e '$TMP/ambient-output' ]"
# Interrupt only the optional metadata publication, after its private file
# exists. The caller must still return its minted token and leave no temporary
# binding behind; the earlier schema-zero invalidation remains authoritative.
export REAL_MV="$(command -v mv)"
mkdir "$TMP/interrupt-bin"
cat > "$TMP/interrupt-bin/mv" <<'MV'
#!/usr/bin/env bash
if [ "${1:-}" = -f ] && [ "${2:-}" = -- ] &&
   jq -e '.schema == 1' "$3" >/dev/null 2>&1; then
  printf '%s\n' "$3" > "$FIXTURE/interrupted-temporary"
  kill -TERM "$PPID"
  exit 0
fi
exec "$REAL_MV" "$@"
MV
chmod +x "$TMP/interrupt-bin/mv"
jq '.permissions={issues:"write",contents:"read"}' "$FIXTURE/token" > "$TMP/qualified-token"
cp "$TMP/qualified-token" "$FIXTURE/token"
printf '1 ghs_synthetic_installation\n' > "$AI_GH_APP_DIR/token-o"
PATH="$TMP/interrupt-bin:$PATH" "$SCRIPT" token o > "$TMP/interrupted-token" 2> "$TMP/interrupted-errors"
check 'interrupted metadata publication preserves minted token and cleans its private temporary' "cmp '$TMP/minted' '$TMP/interrupted-token' && [ -s '$FIXTURE/interrupted-temporary' ] && [ ! -e \"\$(cat '$FIXTURE/interrupted-temporary')\" ] && ! '$SCRIPT' context o && grep -q 'metadata unavailable' '$TMP/interrupted-errors'"
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
