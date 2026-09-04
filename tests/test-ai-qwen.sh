#!/usr/bin/env bash
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-qwen"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

# Timing budgets are measured, not guessed: a constant that is generous on an
# idle CI runner is a lost race on a loaded developer box. See fix_test_ai.md
# and tests/lib-test-timing.sh.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-timing.sh"
ai_test_measure_spawn_baseline

mkdir -p "$REPO_ROOT/.ai"
TMP="$(mktemp -d "$REPO_ROOT/.ai/qwen-test.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
export AI_QWEN_STATE_DIR="$TMP/state"
export AI_QWEN_CALLER=codex
export AI_QWEN_POLL_INTERVAL=1
export AI_QWEN_WAIT_TIMEOUT="$(budget 2 2)"
export TMPDIR_FOR_TEST="$TMP"
export AI_QWEN_TEST_DIR="$TMP" AI_QWEN_HOME="$TMP/qwen-home"
export AI_QWEN_SANITIZER_ROOT="$TMP/qwen-install"
mkdir -p "$AI_QWEN_SANITIZER_ROOT/bin" "$AI_QWEN_SANITIZER_ROOT/lib/chunks"
printf 'fixture launcher\n' > "$AI_QWEN_SANITIZER_ROOT/bin/qwen.js"
cat > "$AI_QWEN_SANITIZER_ROOT/lib/chunks/chunk-test.js" <<'EOF'
var INTERNAL_SECRET_ENV_VARS = [
  "QWEN_SERVER_TOKEN"
];
function sanitizeChildEnv(env) {
  const sanitized = { ...env };
  for (const key of INTERNAL_SECRET_ENV_VARS) {
    delete sanitized[key];
  }
  return sanitized;
}
EOF
mkdir -p "$AI_QWEN_SANITIZER_ROOT/node/bin"
cat > "$AI_QWEN_SANITIZER_ROOT/node/bin/node" <<EOF
#!/usr/bin/env bash
exec "$(command -v node)" "\$@"
EOF
chmod +x "$AI_QWEN_SANITIZER_ROOT/node/bin/node"
export AI_DEVOPS_CONFIG_DIR="$TMP/config"; mkdir -p "$AI_DEVOPS_CONFIG_DIR"; printf 'fake-op-service-token\n' > "$AI_DEVOPS_CONFIG_DIR/op-service-account"

REPO="$TMP/repo"; mkdir -p "$REPO/.ai/reviews"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@example.com
git -C "$REPO" config user.name T
git -C "$REPO" remote add origin https://example.invalid/qwen/repo.git
printf '.ai/\n' > "$REPO/.gitignore"; printf 'original\n' > "$REPO/a.txt"
git -C "$REPO" add -A; git -C "$REPO" commit -qm init

STUB="$TMP/bin"; mkdir -p "$STUB"
cat > "$STUB/qwen" <<'STUBEOF'
#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = process.env.AI_QWEN_TEST_DIR;
const sensitive = /(^BAILIAN_CODING_PLAN_API_KEY$|API_KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL)/;
const names = Object.keys(process.env).filter((name) => sensitive.test(name));
if (process.env.BAILIAN_CODING_PLAN_API_KEY && !names.includes('BAILIAN_CODING_PLAN_API_KEY')) {
  names.push('BAILIAN_CODING_PLAN_API_KEY');
}
fs.appendFileSync(path.join(root, 'argv.txt'), `${process.argv.slice(2).join(' ')}\n`);
fs.writeFileSync(path.join(root, 'qwen-credential-names'), `${names.sort().join('\n')}\n`);
fs.writeFileSync(path.join(root, 'qwen-env'), `${Object.keys(process.env).sort().map((key) => `${key}=${process.env[key]}`).join('\n')}\n`);
const child = spawnSync(process.execPath, ['-e', `require('node:fs').writeFileSync(${JSON.stringify(path.join(root, 'qwen-tool-child-env'))}, Object.keys(process.env).sort().map(k => k+'='+process.env[k]).join('\\n')+'\\n')`], { env: process.env });
if (child.status !== 0) process.exit(70);
if (process.argv[2] === '--version') { console.log('0.21.11'); process.exit(0); }
if (process.argv[2] === 'sessions') { console.log(JSON.stringify({sessionId:'qwen-session-1', filePath:path.join(root, 'transcript.jsonl')})); process.exit(0); }
const mode = fs.existsSync(path.join(root, 'mode')) ? fs.readFileSync(path.join(root, 'mode'), 'utf8').trim() : 'review';
fs.writeFileSync(path.join(root, 'prompt-copy'), fs.readFileSync(0));
const repo = path.join(root, 'repo');
if (mode === 'slow') { fs.writeFileSync(path.join(root, 'slow-pid'), `${process.pid}\n`); Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 30000); }
if (mode === 'write') fs.writeFileSync('qwen.txt', 'qwen change\n');
if (mode === 'mutate-review') fs.appendFileSync('a.txt', 'bad\n');
if (mode === 'mutate-source-dirty') fs.appendFileSync(path.join(repo, 'a.txt'), 'live dirty drift\n');
if (mode === 'mutate-source-untracked') fs.writeFileSync(path.join(repo, 'live-drift.txt'), 'live untracked drift\n');
if (mode === 'mutate-source-committed') {
  fs.appendFileSync(path.join(repo, 'a.txt'), 'live committed drift\n');
  spawnSync('git', ['-C', repo, 'add', 'a.txt']);
  spawnSync('git', ['-C', repo, 'commit', '-qm', 'live-drift']);
}
if (mode === 'fail') { console.log('{"type":"assistant","message":{"content":[]}}'); process.exit(0); }
const returnedModel = mode === 'wrong-model' ? 'qwen-other' : 'qwen3.8-max';
console.log(JSON.stringify({type:'assistant',session_id:'qwen-session-1',message:{model:returnedModel,content:[]}}));
console.log(JSON.stringify({type:'result',subtype:'success',session_id:'qwen-session-1',is_error:false,num_turns:2,result:'## Verdict\nAPPROVE',usage:{input_tokens:11,output_tokens:7},permission_denials:[]}));
STUBEOF
cat > "$STUB/op" <<'STUBEOF'
#!/usr/bin/env bash
env_file=''
[ "${1:-}" = run ] || exit 2; shift
while [ "$#" -gt 0 ]; do
  case "$1" in
    --env-file) env_file="$2"; shift 2 ;;
    --) shift; break ;;
    *) shift ;;
  esac
done
[ -f "$env_file" ] || exit 80
[ "$(wc -l < "$env_file" | tr -d ' ')" = 1 ] || exit 81
grep -q '^BAILIAN_CODING_PLAN_API_KEY=op://' "$env_file" || exit 82
cp "$env_file" "$TMPDIR_FOR_TEST/op-env-file"
printf '%s\n' "$env_file" > "$TMPDIR_FOR_TEST/op-env-source"
export BAILIAN_CODING_PLAN_API_KEY=fake-qwen-only
export DEVOPS_MCP_TOKEN=must-not-reach-qwen OP_SERVICE_ACCOUNT_TOKEN=must-not-reach-qwen
export SUPABASE_ACCESS_TOKEN=must-not-reach-qwen RANDOM_API_KEY=must-not-reach-qwen
exec "$@"
STUBEOF
chmod +x "$STUB/qwen"
chmod +x "$STUB/op"
export AI_QWEN_BIN="$STUB/qwen"
printf 'BAILIAN_CODING_PLAN_API_KEY=op://test/qwen/key\n' > "$TMP/managed.env"
export AI_QWEN_OP_ENV_FILE="$TMP/managed.env" AI_QWEN_OP_BIN="$STUB/op"
unset BAILIAN_CODING_PLAN_API_KEY
printf '{"saved":true}\n' > "$TMP/transcript.jsonl"
echo review > "$TMP/mode"
run(){ (cd "$REPO" && bash "$SCRIPT" "$@"); }

echo 'ai-qwen tests'
check 'syntax is valid' "bash -n '$SCRIPT'"
check 'private Windows ACL is revalidated even when a marker already exists' "! grep -Fq 'if [ ! -f \"\$QWEN_HOME_DIR/.ai-devops-private-home-v1\" ]' '$SCRIPT'"
check 'help exits zero' 'run --help'
check 'production Qwen executable overrides are refused' "! env -u AI_QWEN_TEST_DIR AI_QWEN_BIN='$STUB/qwen' bash '$SCRIPT' --help"
check 'Windows official Qwen path comparison normalizes drive-letter paths' "grep -Fq 'physical=\"\$(cygpath -u \"\$physical\"' '$SCRIPT'"
INSTALL_OUT="$(env HOME="$TMP/installer-home" PATH="$STUB:$PATH" AI_QWEN_SANITIZER_ROOT="$AI_QWEN_SANITIZER_ROOT" bash "$REPO_ROOT/bin/install-ai-provider-clis.sh" qwen 2>&1)"; INSTALL_RC=$?
[ "$INSTALL_RC" -eq 0 ] && grep -q '"BAILIAN_CODING_PLAN_API_KEY"' "$AI_QWEN_SANITIZER_ROOT/lib/chunks/chunk-test.js" && ok 'provider installer applies Qwen child-process credential hardening' || { printf '  diagnostic: installer: %s\n' "$INSTALL_OUT"; bad 'provider installer applies Qwen child-process credential hardening'; }
cp "$AI_QWEN_SANITIZER_ROOT/lib/chunks/chunk-test.js" "$TMP/bad-sanitizer.js"
sed 's/delete sanitized\[key\];/void key;/' "$TMP/bad-sanitizer.js" > "$AI_QWEN_SANITIZER_ROOT/lib/chunks/chunk-test.js"
check 'behavioral verifier rejects a sanitizer that retains the credential' "! '$AI_QWEN_SANITIZER_ROOT/node/bin/node' '$REPO_ROOT/tools/verify-qwen-child-env-sanitizer.mjs' '$AI_QWEN_SANITIZER_ROOT'"
mv "$TMP/bad-sanitizer.js" "$AI_QWEN_SANITIZER_ROOT/lib/chunks/chunk-test.js"

: > "$TMP/argv.txt"
INITIAL_OUT="$(run new review-1 --prompt 'review this' 2>&1)"; INITIAL_RC=$?
[ "$INITIAL_RC" -eq 0 ] || printf '  diagnostic: initial review: %s\n' "$INITIAL_OUT"
check 'initial review completes successfully' "test '$INITIAL_RC' -eq 0"
printf 'preload-test-secret\n' > "$TMP/preload-secret"; chmod 600 "$TMP/preload-secret"
PRELOAD_PROOF="$(AI_QWEN_SECRET_FILE="$TMP/preload-secret" PRELOAD_TEST_FILE="$TMP/preload-secret" NODE_OPTIONS="--require=$REPO_ROOT/tools/qwen-provider-env-preload.cjs" node -e 'const {spawnSync}=require("node:child_process"),fs=require("node:fs"); const child=spawnSync(process.execPath,["-e","process.stdout.write(process.env.BAILIAN_CODING_PLAN_API_KEY||\"absent\")"],{encoding:"utf8"}); process.stdout.write(JSON.stringify({direct:process.env.BAILIAN_CODING_PLAN_API_KEY,has:Object.hasOwn(process.env,"BAILIAN_CODING_PLAN_API_KEY"),enumerable:Object.keys(process.env).includes("BAILIAN_CODING_PLAN_API_KEY"),child:child.stdout,deleted:!fs.existsSync(process.env.PRELOAD_TEST_FILE)}));')"
check 'Qwen preloader exposes the key only to direct runtime lookup and deletes its handoff' "printf '%s' '$PRELOAD_PROOF' | jq -e '.direct==\"preload-test-secret\" and .has==true and .enumerable==false and .child==\"absent\" and .deleted==true'"
if [ -n "${SYSTEMROOT:-}" ]; then
  check 'Qwen runtime home has a private Windows ACL before provider contact' "test -f '$AI_QWEN_HOME/.ai-devops-private-home-v1' && ! icacls.exe \"\$(cygpath -w '$AI_QWEN_HOME')\" | grep -Ei 'BUILTIN\\\\Users|Authenticated Users|Everyone'"
else
  check 'Qwen runtime home is mode 0700 before provider contact' "test \"\$(stat -c %a '$AI_QWEN_HOME')\" = 700"
fi
check 'review pins the stable Qwen 3.8 Max model' "grep -q -- '--model qwen3.8-max' '$TMP/argv.txt'"
check 'review uses safe mode' "grep -q -- '--safe-mode' '$TMP/argv.txt'"
check 'review uses plan mode' "grep -q -- '--approval-mode plan' '$TMP/argv.txt'"
check 'review excludes mutation tools' "grep -q -- '--exclude-tools shell,write,edit' '$TMP/argv.txt'"
check 'review has all budgets' "grep -q -- '--max-session-turns 30' '$TMP/argv.txt' && grep -q -- '--max-tool-calls 80' '$TMP/argv.txt' && grep -q -- '--max-wall-time 15m' '$TMP/argv.txt'"
check 'review never uses yolo or continue' "! grep -qE -- '--approval-mode yolo|--continue' '$TMP/argv.txt'"
check 'review record stores exact session' "run show review-1 | jq -e '.qwen_session_id==\"qwen-session-1\" and .caller==\"codex\"'"
check 'review record binds exact evidence identity' "run show review-1 | jq -e '(.base|length)==40 and (.head|length)==40 and (.packet_sha256|length)==64 and (.working_tree_sha256|length)==64 and .evidence_generation==1'"
check 'review prompt requires the sealed packet first' "grep -q '.ai-review-qwen-codex-review-1/MANIFEST.md' '$TMP/prompt-copy'"
REVIEW_DIR="$(run show review-1 | jq -r .review_dir)"
check 'ordinary clone review uses a private copy' "[ \"\$(cd '$REVIEW_DIR' && pwd -P)\" != \"\$(cd '$REPO' && pwd -P)\" ]"
check 'private review copy owns its git controls' "test -d '$REVIEW_DIR/.git'"

FIRST_ASK_OUT="$(run ask review-1 --prompt 'follow up' 2>&1)"; FIRST_ASK_RC=$?
[ "$FIRST_ASK_RC" -eq 0 ] || printf '  diagnostic: first follow-up: %s\n' "$FIRST_ASK_OUT"
check 'first follow-up completes successfully' "test '$FIRST_ASK_RC' -eq 0"
check 'follow-up resumes exact session' "grep -q -- '--resume qwen-session-1' '$TMP/argv.txt'"
check 'follow-up keeps the recorded review copy' "[ \"\$(run show review-1 | jq -r .review_dir)\" = '$REVIEW_DIR' ]"

run new packet-mismatch --prompt review >/dev/null 2>&1
PACKET_META="$(find "$TMP/state/sessions" -name 'codex--packet-mismatch.json' -print -quit)"
jq '.packet_sha256="ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"' "$PACKET_META" > "$PACKET_META.tmp"; mv "$PACKET_META.tmp" "$PACKET_META"
CALLS_BEFORE="$(wc -l < "$TMP/argv.txt")"; run ask packet-mismatch --prompt followup >/dev/null 2>&1; RC=$?; CALLS_AFTER="$(wc -l < "$TMP/argv.txt")"
[ "$RC" -ne 0 ] && [ "$CALLS_BEFORE" = "$CALLS_AFTER" ] && ok 'follow-up re-verifies the exact stored packet before provider contact' || bad 'follow-up re-verifies the exact stored packet before provider contact'

echo wrong-model > "$TMP/mode"
if run new wrong-model --prompt review >/dev/null 2>&1; then bad 'returned model mismatch is rejected'; else ok 'returned model mismatch is rejected'; fi
WRONG_NEW_META="$(find "$TMP/state/sessions" -name 'codex--wrong-model.json' -print -quit)"
check 'rejected new review preserves provider identity and evidence as recovery-required' "jq -e '.status==\"recovery-required\" and (.qwen_session_id|length)>0' '$WRONG_NEW_META' && test -s \"\$(jq -r .recovery_stream '$WRONG_NEW_META')\""
CALLS_BEFORE_WRONG_REUSE="$(wc -l < "$TMP/argv.txt")"; run new wrong-model --prompt retry >/dev/null 2>&1; RC=$?
[ "$RC" -ne 0 ] && [ "$CALLS_BEFORE_WRONG_REUSE" = "$(wc -l < "$TMP/argv.txt")" ] && ok 'rejected new review name cannot trigger duplicate spend' || bad 'rejected new review name cannot trigger duplicate spend'
echo review > "$TMP/mode"

run new wrong-model-followup --prompt review >/dev/null 2>&1
echo wrong-model > "$TMP/mode"
if run ask wrong-model-followup --prompt followup >/dev/null 2>&1; then bad 'follow-up model mismatch is rejected'; else ok 'follow-up model mismatch is rejected'; fi
WRONG_META="$(find "$TMP/state/sessions" -name 'codex--wrong-model-followup.json' -print -quit)"
check 'rejected model follow-up blocks continuation and preserves returned evidence' "jq -e '.status==\"recovery-required\" and (.recovery_stream|length)>0' '$WRONG_META' && test -s \"\$(jq -r .recovery_stream '$WRONG_META')\""
CALLS_BEFORE_BLOCKED="$(wc -l < "$TMP/argv.txt")"; run ask wrong-model-followup --prompt again >/dev/null 2>&1; RC=$?
[ "$RC" -ne 0 ] && [ "$CALLS_BEFORE_BLOCKED" = "$(wc -l < "$TMP/argv.txt")" ] && ok 'recovery-required Qwen session cannot contact provider again' || bad 'recovery-required Qwen session cannot contact provider again'
echo review > "$TMP/mode"

run new drift-committed --prompt 'review' >/dev/null 2>&1
printf 'commit drift\n' >> "$REPO/a.txt"; git -C "$REPO" add a.txt; git -C "$REPO" commit -qm drift
CALLS_BEFORE="$(wc -l < "$TMP/argv.txt")"; OUT="$(run ask drift-committed --prompt followup 2>&1)"; RC=$?; CALLS_AFTER="$(wc -l < "$TMP/argv.txt")"
[ "$RC" -ne 0 ] && [ "$CALLS_BEFORE" = "$CALLS_AFTER" ] && ok 'committed drift blocks before provider contact' || bad 'committed drift blocks before provider contact'
check 'committed drift gives new-session guidance' "printf '%s' \"\$OUT\" | grep -q 'Start a new named Qwen review'"
run new drift-dirty --prompt 'review' >/dev/null 2>&1
printf 'dirty drift\n' >> "$REPO/a.txt"
CALLS_BEFORE="$(wc -l < "$TMP/argv.txt")"; run ask drift-dirty --prompt followup >/dev/null 2>&1; RC=$?; CALLS_AFTER="$(wc -l < "$TMP/argv.txt")"
[ "$RC" -ne 0 ] && [ "$CALLS_BEFORE" = "$CALLS_AFTER" ] && ok 'dirty drift blocks before provider contact' || bad 'dirty drift blocks before provider contact'
git -C "$REPO" checkout -q -- a.txt
run new drift-untracked --prompt 'review' >/dev/null 2>&1
printf 'untracked drift\n' > "$REPO/new.txt"
CALLS_BEFORE="$(wc -l < "$TMP/argv.txt")"; run ask drift-untracked --prompt followup >/dev/null 2>&1; RC=$?; CALLS_AFTER="$(wc -l < "$TMP/argv.txt")"
[ "$RC" -ne 0 ] && [ "$CALLS_BEFORE" = "$CALLS_AFTER" ] && ok 'untracked drift blocks before provider contact' || bad 'untracked drift blocks before provider contact'
rm -f "$REPO/new.txt"

MSYS=winsymlinks:nativestrict ln -s a.txt "$REPO/untracked-link" 2>/dev/null || true
if [ -L "$REPO/untracked-link" ]; then
  CALLS_BEFORE="$(wc -l < "$TMP/argv.txt")"; run new linked-evidence --prompt review >/dev/null 2>&1; RC=$?; CALLS_AFTER="$(wc -l < "$TMP/argv.txt")"
  [ "$RC" -ne 0 ] && [ "$CALLS_BEFORE" = "$CALLS_AFTER" ] && ok 'linked untracked evidence is rejected before provider contact' || bad 'linked untracked evidence is rejected before provider contact'
else
  check 'linked untracked evidence is rejected before provider contact (platform structural proof)' "grep -q '\[ ! -L \"\$repo/\$f\" \] && \[ -f \"\$repo/\$f\" \]' '$SCRIPT'"
fi
rm -f "$REPO/untracked-link"
mkfifo "$REPO/untracked-fifo"
CALLS_BEFORE="$(wc -l < "$TMP/argv.txt")"; run new fifo-evidence --prompt review >/dev/null 2>&1; RC=$?; CALLS_AFTER="$(wc -l < "$TMP/argv.txt")"
[ "$RC" -ne 0 ] && [ "$CALLS_BEFORE" = "$CALLS_AFTER" ] && ok 'FIFO untracked evidence is rejected without blocking or provider contact' || bad 'FIFO untracked evidence is rejected without blocking or provider contact'
rm -f "$REPO/untracked-fifo"

CALLS_BEFORE_PREPARE_DRIFT="$(wc -l < "$TMP/argv.txt")"; rm -f "$TMP/pre-snapshot"
(cd "$REPO" && exec env AI_QWEN_STATE_DIR="$AI_QWEN_STATE_DIR" AI_QWEN_CALLER=codex AI_QWEN_BIN="$AI_QWEN_BIN" AI_QWEN_HOME="$AI_QWEN_HOME" AI_QWEN_TEST_DIR="$AI_QWEN_TEST_DIR" AI_QWEN_OP_ENV_FILE="$AI_QWEN_OP_ENV_FILE" AI_QWEN_OP_BIN="$AI_QWEN_OP_BIN" TMPDIR_FOR_TEST="$TMPDIR_FOR_TEST" AI_QWEN_TEST_PRE_SNAPSHOT_MARKER="$TMP/pre-snapshot" AI_QWEN_TEST_PRE_SNAPSHOT_DELAY=2 "$SCRIPT" new prepare-drift --prompt review >/dev/null 2>&1) & PREPARE_PID=$!
for _ in $(seq 1 "$(scale_ticks 100)"); do [ -f "$TMP/pre-snapshot" ] && break; sleep .05; done
printf 'changed during evidence preparation\n' >> "$REPO/a.txt"; PREPARE_RC=0; wait "$PREPARE_PID" || PREPARE_RC=$?
[ "$PREPARE_RC" -ne 0 ] && [ "$CALLS_BEFORE_PREPARE_DRIFT" = "$(wc -l < "$TMP/argv.txt")" ] && ok 'source drift during snapshot preparation blocks before provider contact' || bad 'source drift during snapshot preparation blocks before provider contact'
git -C "$REPO" checkout -q -- a.txt

echo review > "$TMP/mode"; run new followup-prepare-drift --prompt review >/dev/null 2>&1
CALLS_BEFORE_FOLLOWUP_PREPARE="$(wc -l < "$TMP/argv.txt")"; rm -f "$TMP/pre-followup-packet"
(cd "$REPO" && exec env AI_QWEN_STATE_DIR="$AI_QWEN_STATE_DIR" AI_QWEN_CALLER=codex AI_QWEN_BIN="$AI_QWEN_BIN" AI_QWEN_HOME="$AI_QWEN_HOME" AI_QWEN_SANITIZER_ROOT="$AI_QWEN_SANITIZER_ROOT" AI_QWEN_TEST_DIR="$AI_QWEN_TEST_DIR" AI_QWEN_OP_ENV_FILE="$AI_QWEN_OP_ENV_FILE" AI_QWEN_OP_BIN="$AI_QWEN_OP_BIN" TMPDIR_FOR_TEST="$TMPDIR_FOR_TEST" AI_QWEN_TEST_PRE_FOLLOWUP_PACKET_MARKER="$TMP/pre-followup-packet" AI_QWEN_TEST_PRE_FOLLOWUP_PACKET_DELAY=2 "$SCRIPT" ask followup-prepare-drift --prompt followup >/dev/null 2>&1) & FOLLOWUP_PREPARE_PID=$!
for _ in $(seq 1 "$(scale_ticks 100)"); do [ -f "$TMP/pre-followup-packet" ] && break; sleep .05; done
printf 'changed during follow-up evidence preparation\n' >> "$REPO/a.txt"; FOLLOWUP_PREPARE_RC=0; wait "$FOLLOWUP_PREPARE_PID" || FOLLOWUP_PREPARE_RC=$?
[ "$FOLLOWUP_PREPARE_RC" -ne 0 ] && [ "$CALLS_BEFORE_FOLLOWUP_PREPARE" = "$(wc -l < "$TMP/argv.txt")" ] && ok 'follow-up source drift during packet rebuild blocks before provider contact' || bad 'follow-up source drift during packet rebuild blocks before provider contact'
git -C "$REPO" checkout -q -- a.txt

cp "$REPO/a.txt" "$TMP/a-before-live-drift"
echo mutate-source-dirty > "$TMP/mode"
if run new live-dirty --prompt review >/dev/null 2>&1; then bad 'same-turn dirty source drift rejects the response'; else ok 'same-turn dirty source drift rejects the response'; fi
cp "$TMP/a-before-live-drift" "$REPO/a.txt"

echo mutate-source-untracked > "$TMP/mode"
if run new live-untracked --prompt review >/dev/null 2>&1; then bad 'same-turn untracked source drift rejects the response'; else ok 'same-turn untracked source drift rejects the response'; fi
rm -f "$REPO/live-drift.txt"

echo mutate-source-committed > "$TMP/mode"
if run new live-committed --prompt review >/dev/null 2>&1; then bad 'same-turn committed source drift rejects the response'; else ok 'same-turn committed source drift rejects the response'; fi
cp "$TMP/a-before-live-drift" "$REPO/a.txt"; git -C "$REPO" add a.txt; git -C "$REPO" commit -qm restore-after-live-drift

echo review > "$TMP/mode"; run new live-followup --prompt review >/dev/null 2>&1
echo mutate-source-dirty > "$TMP/mode"
if run ask live-followup --prompt followup >/dev/null 2>&1; then bad 'same-turn source drift rejects a follow-up response'; else ok 'same-turn source drift rejects a follow-up response'; fi
LIVE_FOLLOWUP_META="$(find "$TMP/state/sessions" -name 'codex--live-followup.json' -print -quit)"
check 'source-drift follow-up also becomes recovery-required with evidence' "jq -e '.status==\"recovery-required\"' '$LIVE_FOLLOWUP_META' && test -s \"\$(jq -r .recovery_stream '$LIVE_FOLLOWUP_META')\""
cp "$TMP/a-before-live-drift" "$REPO/a.txt"

echo slow > "$TMP/mode"; rm -f "$TMP/slow-pid"
(cd "$REPO" && exec env AI_QWEN_STATE_DIR="$AI_QWEN_STATE_DIR" AI_QWEN_CALLER=codex AI_QWEN_BIN="$AI_QWEN_BIN" AI_QWEN_HOME="$AI_QWEN_HOME" AI_QWEN_TEST_DIR="$AI_QWEN_TEST_DIR" AI_QWEN_OP_ENV_FILE="$AI_QWEN_OP_ENV_FILE" AI_QWEN_OP_BIN="$AI_QWEN_OP_BIN" TMPDIR_FOR_TEST="$TMPDIR_FOR_TEST" AI_DEVOPS_CONFIG_DIR="$AI_DEVOPS_CONFIG_DIR" "$SCRIPT" new crash-new --prompt wait >/dev/null 2>&1) & CRASH_NEW_PID=$!
for _ in $(seq 1 "$(scale_ticks 200)"); do [ -s "$TMP/slow-pid" ] && [ -n "$(find "$TMP/state/sessions" -name 'codex--crash-new.json' -print -quit 2>/dev/null)" ] && break; sleep .05; done
CRASH_NEW_META="$(find "$TMP/state/sessions" -name 'codex--crash-new.json' -print -quit)"; CRASH_CHILD="$(cat "$TMP/slow-pid" 2>/dev/null || echo 0)"
check 'new paid turn is durable before untrappable termination' "jq -e '.status==\"turn_in_progress\"' '$CRASH_NEW_META'"
kill -KILL "$CRASH_NEW_PID" 2>/dev/null || true; kill -KILL "$CRASH_CHILD" 2>/dev/null || true; wait "$CRASH_NEW_PID" 2>/dev/null || true
CALLS_AFTER_CRASH_NEW="$(wc -l < "$TMP/argv.txt")"; run new crash-new --prompt retry >/dev/null 2>&1; RC=$?
[ "$RC" -ne 0 ] && [ "$CALLS_AFTER_CRASH_NEW" = "$(wc -l < "$TMP/argv.txt")" ] && ok 'crashed new review cannot be charged again under the same name' || bad 'crashed new review cannot be charged again under the same name'

echo review > "$TMP/mode"; run new crash-followup --prompt review >/dev/null 2>&1
echo slow > "$TMP/mode"; rm -f "$TMP/slow-pid"
(cd "$REPO" && exec env AI_QWEN_STATE_DIR="$AI_QWEN_STATE_DIR" AI_QWEN_CALLER=codex AI_QWEN_BIN="$AI_QWEN_BIN" AI_QWEN_HOME="$AI_QWEN_HOME" AI_QWEN_TEST_DIR="$AI_QWEN_TEST_DIR" AI_QWEN_OP_ENV_FILE="$AI_QWEN_OP_ENV_FILE" AI_QWEN_OP_BIN="$AI_QWEN_OP_BIN" TMPDIR_FOR_TEST="$TMPDIR_FOR_TEST" AI_DEVOPS_CONFIG_DIR="$AI_DEVOPS_CONFIG_DIR" "$SCRIPT" ask crash-followup --prompt wait >/dev/null 2>&1) & CRASH_FOLLOW_PID=$!
for _ in $(seq 1 "$(scale_ticks 200)"); do [ -s "$TMP/slow-pid" ] && break; sleep .05; done
CRASH_FOLLOW_META="$(find "$TMP/state/sessions" -name 'codex--crash-followup.json' -print -quit)"; CRASH_CHILD="$(cat "$TMP/slow-pid" 2>/dev/null || echo 0)"
check 'follow-up is durable before untrappable termination' "jq -e '.status==\"turn_in_progress\"' '$CRASH_FOLLOW_META'"
kill -KILL "$CRASH_FOLLOW_PID" 2>/dev/null || true; kill -KILL "$CRASH_CHILD" 2>/dev/null || true; wait "$CRASH_FOLLOW_PID" 2>/dev/null || true
CALLS_AFTER_CRASH_FOLLOW="$(wc -l < "$TMP/argv.txt")"; run ask crash-followup --prompt retry >/dev/null 2>&1; RC=$?
[ "$RC" -ne 0 ] && [ "$CALLS_AFTER_CRASH_FOLLOW" = "$(wc -l < "$TMP/argv.txt")" ] && ok 'crashed follow-up cannot resume the uncertain provider conversation' || bad 'crashed follow-up cannot resume the uncertain provider conversation'

echo review > "$TMP/mode"; run new interrupt-followup --prompt review >/dev/null 2>&1
echo slow > "$TMP/mode"; CALLS_BEFORE_INTERRUPT="$(wc -l < "$TMP/argv.txt")"
(cd "$REPO" && exec env AI_QWEN_STATE_DIR="$AI_QWEN_STATE_DIR" AI_QWEN_CALLER=codex AI_QWEN_BIN="$AI_QWEN_BIN" AI_QWEN_HOME="$AI_QWEN_HOME" AI_QWEN_TEST_DIR="$AI_QWEN_TEST_DIR" AI_QWEN_OP_ENV_FILE="$AI_QWEN_OP_ENV_FILE" AI_QWEN_OP_BIN="$AI_QWEN_OP_BIN" TMPDIR_FOR_TEST="$TMPDIR_FOR_TEST" AI_DEVOPS_CONFIG_DIR="$AI_DEVOPS_CONFIG_DIR" "$SCRIPT" ask interrupt-followup --prompt wait >/dev/null 2>&1) & INTERRUPT_FOLLOWUP_PID=$!
for _ in $(seq 1 "$(scale_ticks 200)"); do [ "$(wc -l < "$TMP/argv.txt")" -gt "$CALLS_BEFORE_INTERRUPT" ] && break; sleep .05; done
kill -TERM "$INTERRUPT_FOLLOWUP_PID" 2>/dev/null || true; wait "$INTERRUPT_FOLLOWUP_PID" 2>/dev/null || true
INTERRUPT_META="$(find "$TMP/state/sessions" -name 'codex--interrupt-followup.json' -print -quit)"
check 'interrupted follow-up becomes recovery-required with a preserved stream' "jq -e '.status==\"recovery-required\" and .failure_reason==\"interrupted-provider-turn\"' '$INTERRUPT_META' && test -e \"\$(jq -r .recovery_stream '$INTERRUPT_META')\""
CALLS_AFTER_INTERRUPT="$(wc -l < "$TMP/argv.txt")"; run ask interrupt-followup --prompt retry >/dev/null 2>&1; RC=$?
[ "$RC" -ne 0 ] && [ "$CALLS_AFTER_INTERRUPT" = "$(wc -l < "$TMP/argv.txt")" ] && ok 'interrupted follow-up cannot be resumed again' || bad 'interrupted follow-up cannot be resumed again'

echo mutate-review > "$TMP/mode"
if run new hostile --prompt 'write a file' >/dev/null 2>&1; then bad 'review mutation fails loudly'; else ok 'review mutation fails loudly'; fi
git -C "$REPO" checkout -q -- a.txt

printf 'owner work\n' >> "$REPO/a.txt"
BEFORE_DIRTY="$(sha256sum "$REPO/a.txt" | awk '{print $1}')"
echo mutate-review > "$TMP/mode"
if run new hostile-dirty --prompt 'write a file' >/dev/null 2>&1; then bad 'mutation inside an already-dirty file fails'; else ok 'mutation inside an already-dirty file fails'; fi
AFTER_DIRTY="$(sha256sum "$REPO/a.txt" | awk '{print $1}')"
if [ "$BEFORE_DIRTY" = "$AFTER_DIRTY" ]; then ok 'private-copy mutation leaves owner work untouched'; else bad 'private-copy mutation leaves owner work untouched'; fi
git -C "$REPO" checkout -q -- a.txt

echo write > "$TMP/mode"; : > "$TMP/argv.txt"
IMPL_OUT="$(run implement impl-1 --prompt 'make the change' 2>&1)"; IMPL_RC=$?
[ "$IMPL_RC" -eq 0 ] || printf '  diagnostic: implementation: %s\n' "$IMPL_OUT"
PATCH="$(/usr/bin/find "$REPO/.ai/reviews" -name 'qwen-impl-1-*.patch' | head -1)"
check 'implementation requires Qwen sandbox' "grep -q -- '--sandbox --approval-mode yolo' '$TMP/argv.txt'"
check 'implementation preserves the complete shell/write/edit toolset' "grep -q -- '--approval-mode yolo' '$TMP/argv.txt' && ! grep -q -- '--exclude-tools shell' '$TMP/argv.txt'"
check 'implementation requires installed child-process credential hardening' "grep -q 'assert_qwen_child_env_hardened || die' '$SCRIPT'"
check 'implementation exports a patch' "test -n '$PATCH' && grep -q qwen.txt '$PATCH'"
check 'implementation does not touch live checkout' "test ! -e '$REPO/qwen.txt'"
check 'implementation removes disposable worktree' "test \"\$(git -C '$REPO' worktree list | wc -l)\" -eq 1"

echo review > "$TMP/mode"
run transcript review-1 >/dev/null 2>&1
check 'transcript copy stays in ignored review directory' "/usr/bin/find '$REPO/.ai/reviews' -name 'qwen-review-1-*.jsonl' | grep -q ."
check 'local transcript discovery receives no provider credential' "! grep -qx BAILIAN_CODING_PLAN_API_KEY '$TMP/qwen-credential-names'"
run delete review-1 >/dev/null 2>&1
check 'delete removes the private review copy' "test ! -d '$REVIEW_DIR'"
DOCTOR_ONE="$(run doctor)"
check 'doctor checks installed interface without a model call' "printf '%s\\n' \"\$DOCTOR_ONE\" | grep -Eq '^qwen runtime sha256: [0-9a-f]{64}$'"
check 'doctor secures a fresh Qwen home before checking its session store' "sed -n '/^cmd_doctor()/,/^}/p' '$SCRIPT' | grep -q 'secure_qwen_home'"
check 'doctor fingerprints the repository credential preloader' "printf '%s\\n' \"\$DOCTOR_ONE\" | grep -Eq '^qwen preloader sha256: [0-9a-f]{64}$'"
RUNTIME_HASH_ONE="$(printf '%s\n' "$DOCTOR_ONE" | sed -n 's/^qwen runtime sha256: //p')"
printf '\n// runtime drift fixture\n' >> "$AI_QWEN_SANITIZER_ROOT/lib/chunks/chunk-test.js"
DOCTOR_TWO="$(run doctor)"
RUNTIME_HASH_TWO="$(printf '%s\n' "$DOCTOR_TWO" | sed -n 's/^qwen runtime sha256: //p')"
check 'doctor fingerprint changes with installed runtime content' "test -n '$RUNTIME_HASH_ONE' && test -n '$RUNTIME_HASH_TWO' && test '$RUNTIME_HASH_ONE' != '$RUNTIME_HASH_TWO'"
check 'offline doctor commands receive no provider credential' "! grep -qx BAILIAN_CODING_PLAN_API_KEY '$TMP/qwen-credential-names'"
GOVERNED_ENV="$AI_QWEN_OP_ENV_FILE"; export AI_QWEN_OP_ENV_FILE="$TMP/missing-managed.env"
CALLS_BEFORE_MISSING_AUTH="$(wc -l < "$TMP/argv.txt")"; run new missing-governed-auth --prompt review >/dev/null 2>&1; RC=$?
[ "$RC" -ne 0 ] && [ "$CALLS_BEFORE_MISSING_AUTH" = "$(wc -l < "$TMP/argv.txt")" ] && ok 'missing governed authentication blocks before provider contact' || bad 'missing governed authentication blocks before provider contact'
export AI_QWEN_OP_ENV_FILE="$GOVERNED_ENV"
echo wrong-model > "$TMP/mode"
if run doctor --live >/dev/null 2>&1; then bad 'live doctor rejects a returned model mismatch'; else ok 'live doctor rejects a returned model mismatch'; fi
echo review > "$TMP/mode"
check 'live doctor requires terminal success from the pinned model' 'run doctor --live'

echo fail > "$TMP/mode"
if run new no-terminal --prompt x >/dev/null 2>&1; then bad 'missing terminal result fails'; else ok 'missing terminal result fails'; fi

echo "== #1220: silence must never read as APPROVE =="
# ai-qwen carried the identical extract_answer defect as ai-kimi: it printed only
# the tail from '## Verdict' (discarding findings that sat above it) and treated a
# run that ended with no verdict as a review with nothing to say. Exercised
# directly, because these are pure-text defects.
sed -n '/^extract_answer() {/,/^}/p' "$SCRIPT" > "$TMP/extract.sh"
probe(){ bash -c '. "$1"; ANSWER_DEFECT=""; extract_answer "$2" >/dev/null; printf "%s" "$ANSWER_DEFECT"' _ "$TMP/extract.sh" "$1"; }

printf '%s\n' '{"type":"result","is_error":false,"result":"I have read the files. Let me verify a few things before finalizing findings."}' > "$TMP/noverdict.jsonl"
NOV="$(probe "$TMP/noverdict.jsonl")"
check 'a result with no verdict is reported as a defect' "printf '%s' \"\$NOV\" | grep -q Verdict"

: > "$TMP/silent.jsonl"
SIL="$(probe "$TMP/silent.jsonl")"
check 'a stream with no answer at all is reported as a defect' "printf '%s' \"\$SIL\" | grep -q 'no answer text'"

printf '%s\n' '{"type":"result","is_error":false,"result":"finding one\n## Verdict\nAPPROVE"}' > "$TMP/good.jsonl"
GOOD="$(probe "$TMP/good.jsonl")"
check 'a complete review is NOT flagged as a defect' "[ -z \"\$GOOD\" ]"

printf '%s\n' '{"type":"result","is_error":false,"result":"finding\n## Verdict\nMAYBE"}' > "$TMP/invalid-verdict.jsonl"
INVALID="$(probe "$TMP/invalid-verdict.jsonl")"
check 'an invalid verdict word is rejected' "printf '%s' \"\$INVALID\" | grep -q 'APPROVE, REJECT, or BLOCKED'"

printf '%s\n' '{"type":"result","is_error":false,"result":"## Verdict\nREJECT\nmore analysis\n## Verdict\nAPPROVE"}' > "$TMP/multiple-verdicts.jsonl"
MULTIPLE="$(probe "$TMP/multiple-verdicts.jsonl")"
check 'multiple verdict sections are rejected' "printf '%s' \"\$MULTIPLE\" | grep -q 'exactly one'"

printf '%s\n' '{"type":"result","is_error":false,"result":"## Verdict\nAPPROVE\ntrailing text"}' > "$TMP/nonfinal-verdict.jsonl"
NONFINAL="$(probe "$TMP/nonfinal-verdict.jsonl")"
check 'a non-final verdict is rejected' "printf '%s' \"\$NONFINAL\" | grep -q 'final two nonblank lines'"
check 'raw JSON output cannot bypass verdict validation' "grep -q 'extract_answer \"\$out\" >/dev/null; cat \"\$out\"' '$SCRIPT' && grep -q 'qwen-\${name}-incomplete-' '$SCRIPT'"

BODY="$(bash -c '. "$1"; extract_answer "$2"' _ "$TMP/extract.sh" "$TMP/good.jsonl")"
check 'the text above the verdict is still emitted' "printf '%s' \"\$BODY\" | grep -q 'finding one'"
check 'provider turns use a one-credential 1Password file' "grep -q 'qwen_env=.*mktemp' '$SCRIPT' && grep -q 'BAILIAN_CODING_PLAN_API_KEY=%s' '$SCRIPT' && ! grep -q 'op run --env-file \"\$MCP_ENV\"' '$SCRIPT'"
check 'Qwen child uses an explicit empty-environment allowlist' "grep -q 'clean_env=(\"\$env_bin\" -i' '$SCRIPT' && grep -q 'QWEN_HOME=' '$SCRIPT' && grep -q 'exec \"\${clean_env\[@\]}\"' '$SCRIPT'"

export DEVOPS_MCP_TOKEN=must-not-reach-preloaded SUPABASE_ACCESS_TOKEN=must-not-reach-preloaded RANDOM_API_KEY=must-not-reach-preloaded
export DATABASE_URL=must-not-reach-preloaded AWS_PROFILE=must-not-reach-preloaded SSH_AUTH_SOCK=must-not-reach-preloaded lowercase_secret=must-not-reach-preloaded
echo review > "$TMP/mode"; run new preloaded-credential-boundary --prompt review >/dev/null 2>&1
check 'preloaded-key Qwen process also receives no unrelated credentials' "grep -qx BAILIAN_CODING_PLAN_API_KEY '$TMP/qwen-credential-names' && ! grep -Eq 'DEVOPS|SUPABASE|RANDOM|DATABASE_URL|AWS_PROFILE|SSH_AUTH_SOCK|lowercase_secret' '$TMP/qwen-env'"
EXPECTED_QWEN_HOME="$AI_QWEN_HOME"
EXPECTED_QWEN_HOME_ALT="$AI_QWEN_HOME"
if [ -n "${SYSTEMROOT:-}" ]; then EXPECTED_QWEN_HOME="$(cygpath -w "$AI_QWEN_HOME")"; EXPECTED_QWEN_HOME_ALT="$(cygpath -m "$AI_QWEN_HOME")"; fi
if grep -Fqx -e "HOME=$EXPECTED_QWEN_HOME" -e "HOME=$EXPECTED_QWEN_HOME_ALT" "$TMP/qwen-env" && grep -Fqx -e "QWEN_HOME=$EXPECTED_QWEN_HOME" -e "QWEN_HOME=$EXPECTED_QWEN_HOME_ALT" "$TMP/qwen-env"; then
  ok 'Qwen receives only its dedicated home'
else
  printf '  diagnostic: expected home: %s; received: ' "$EXPECTED_QWEN_HOME"
  grep -E '^(HOME|QWEN_HOME)=' "$TMP/qwen-env" | tr '\n' ' '; printf '\n'
  bad 'Qwen receives only its dedicated home'
fi
unset DEVOPS_MCP_TOKEN SUPABASE_ACCESS_TOKEN RANDOM_API_KEY DATABASE_URL AWS_PROFILE SSH_AUTH_SOCK lowercase_secret

printf 'BAILIAN_CODING_PLAN_API_KEY=op://test/qwen/key\n' > "$TMP/managed.env"
unset BAILIAN_CODING_PLAN_API_KEY
AI_QWEN_OP_ENV_FILE="$TMP/managed.env"; export AI_QWEN_OP_ENV_FILE
AI_QWEN_OP_BIN="$STUB/op"; export AI_QWEN_OP_BIN
cat > "$TMP/hostile-bash-env" <<'EOF'
if [ "${BAILIAN_CODING_PLAN_API_KEY:-}" = fake-qwen-only ] || [ "${OP_SERVICE_ACCOUNT_TOKEN:-}" = fake-op-service-token ]; then
  env | sort > "$AI_QWEN_TEST_DIR/hostile-bash-env-fired"
fi
EOF
export BASH_ENV="$TMP/hostile-bash-env" ENV="$TMP/hostile-bash-env"
echo review > "$TMP/mode"
CREDENTIAL_OUT="$(run new credential-boundary --prompt review 2>&1)"; CREDENTIAL_RC=$?
unset BASH_ENV ENV
[ "$CREDENTIAL_RC" -eq 0 ] || printf '  diagnostic: credential boundary: %s\n' "$CREDENTIAL_OUT"
check 'managed provider call gives op a one-variable reference file' "test \"\$(wc -l < '$TMP/op-env-file' | tr -d ' ')\" = 1 && grep -q '^BAILIAN_CODING_PLAN_API_KEY=op://' '$TMP/op-env-file'"
check 'managed Qwen OS environment contains no real provider key' "! grep -q '^BAILIAN_CODING_PLAN_API_KEY=' '$TMP/qwen-env' && ! grep -q 'fake-qwen-only' '$TMP/qwen-env' && ! grep -Eq 'DEVOPS|OP_SERVICE|SUPABASE|RANDOM' '$TMP/qwen-credential-names'"
check 'Qwen secret handoff is removed after every provider turn' "test -z \"\$(find '$AI_QWEN_HOME/tmp' -maxdepth 1 -name '.qwen-secret.*' -print -quit)\""
check 'agent-controlled Qwen children cannot inherit the real provider key' "! grep -q '^BAILIAN_CODING_PLAN_API_KEY=' '$TMP/qwen-tool-child-env' && ! grep -q 'fake-qwen-only' '$TMP/qwen-tool-child-env'"
check 'real Qwen provider key uses one private self-deleting handoff and is removed before Qwen exec' "grep -q 'chmod 600 \"\$RUN_TURN_SECRET_FILE\"' '$SCRIPT' && grep -q 'unset BAILIAN_CODING_PLAN_API_KEY keep_qwen_key' '$SCRIPT' && grep -q 'AI_QWEN_SECRET_FILE=' '$SCRIPT'"
check 'hostile shell startup hooks cannot observe managed credentials' "test ! -e '$TMP/hostile-bash-env-fired' && grep -q '\"\$QWEN_ENV_BIN\" -u BASH_ENV -u ENV \"\$op_bin\"' '$SCRIPT'"
check 'credentialed Qwen boundary uses only prevalidated absolute executables' "grep -q 'trusted absolute Bash/env executables are required' '$SCRIPT' && grep -q 'clean_env=(\"\$env_bin\" -i' '$SCRIPT' && grep -q '\"\$bash_bin\" --noprofile --norc' '$SCRIPT'"
echo slow > "$TMP/mode"; rm -f "$TMP/op-env-source"
(cd "$REPO" && exec env HOME="$HOME" PATH="$PATH" AI_QWEN_STATE_DIR="$AI_QWEN_STATE_DIR" AI_QWEN_CALLER=codex AI_QWEN_BIN="$AI_QWEN_BIN" AI_QWEN_HOME="$AI_QWEN_HOME" AI_QWEN_TEST_DIR="$AI_QWEN_TEST_DIR" AI_QWEN_OP_ENV_FILE="$AI_QWEN_OP_ENV_FILE" AI_QWEN_OP_BIN="$AI_QWEN_OP_BIN" TMPDIR_FOR_TEST="$TMPDIR_FOR_TEST" "$SCRIPT" new interrupted-credential --prompt review >/dev/null 2>&1) & QWEN_INTERRUPT_PID=$!
for _ in $(seq 1 "$(scale_ticks 200)"); do [ -s "$TMP/op-env-source" ] && break; sleep .05; done
QWEN_TEMP_ENV="$(cat "$TMP/op-env-source" 2>/dev/null || true)"; kill -TERM "$QWEN_INTERRUPT_PID" 2>/dev/null || true; wait "$QWEN_INTERRUPT_PID" 2>/dev/null || true
check 'interrupted managed turn removes its temporary credential-reference file' "test -n '$QWEN_TEMP_ENV' && test ! -e '$QWEN_TEMP_ENV'"
echo review > "$TMP/mode"
export AI_QWEN_BIN="$STUB/qwen"
export BAILIAN_CODING_PLAN_API_KEY=fake-offline-qwen-key
unset AI_QWEN_OP_BIN

unset BAILIAN_CODING_PLAN_API_KEY OP_SERVICE_ACCOUNT_TOKEN
rm -f "$TMP/post-turn-env"
export AI_QWEN_OP_BIN="$STUB/op"
export AI_QWEN_TEST_POST_TURN_ENV_FILE="$TMP/post-turn-env"
POST_TURN_OUT="$(run new token-scope --prompt review 2>&1)"; POST_TURN_RC=$?
unset AI_QWEN_TEST_POST_TURN_ENV_FILE
if [ "$POST_TURN_RC" -eq 0 ] && [ -s "$TMP/post-turn-env" ] && ! grep -q '^OP_SERVICE_ACCOUNT_TOKEN=' "$TMP/post-turn-env" && ! grep -q 'export OP_SERVICE_ACCOUNT_TOKEN$' "$SCRIPT"; then
  ok '1Password service token is absent from wrapper post-call processes'
else
  printf '  diagnostic: post-turn rc=%s, environment evidence=%s\n' "$POST_TURN_RC" "$([ -s "$TMP/post-turn-env" ] && echo present || echo missing)"
  [ "$POST_TURN_RC" -eq 0 ] || printf '  diagnostic: post-turn: %s\n' "$POST_TURN_OUT"
  bad '1Password service token is absent from wrapper post-call processes'
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
