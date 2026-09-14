#!/usr/bin/env bash
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-qwen"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"
check 'Qwen delegates only pure adapter primitives to the shared helper' "grep -q 'provider-wrapper-common.sh' '$SCRIPT' && grep -q 'provider_wrapper_valid_name' '$SCRIPT' && grep -q 'provider_wrapper_sha256_file' '$SCRIPT'"

# Timing budgets are measured, not guessed: a constant that is generous on an
# idle CI runner is a lost race on a loaded developer box. See fix_test_ai.md
# and tests/lib-test-timing.sh.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-timing.sh"
ai_test_measure_spawn_baseline

mkdir -p "$REPO_ROOT/.ai"
TMP="$(mktemp -d "$REPO_ROOT/.ai/qwen-test.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
export AI_REVIEW_EVENT_DIR="$TMP/reviewer-events"
export AI_QWEN_STATE_DIR="$TMP/state"
export AI_QWEN_CALLER=codex
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
// Model the shipped runtime: tool children go through sanitizeChildEnv, which
// strips the internal secret names; the startup relaunch does not.
const sanitizedChildEnv = { ...process.env };
for (const name of ['BAILIAN_CODING_PLAN_API_KEY', 'QWEN_SERVER_TOKEN', 'QWEN_DAEMON_TOKEN']) delete sanitizedChildEnv[name];
const child = spawnSync(process.execPath, ['-e', `require('node:fs').writeFileSync(${JSON.stringify(path.join(root, 'qwen-tool-child-env'))}, Object.keys(process.env).sort().map(k => k+'='+process.env[k]).join('\\n')+'\\n')`], { env: sanitizedChildEnv });
const relaunch = spawnSync(process.execPath, ['-e', `require('node:fs').writeFileSync(${JSON.stringify(path.join(root, 'qwen-relaunch-key'))}, process.env.BAILIAN_CODING_PLAN_API_KEY || 'absent')`], { env: process.env });
if (relaunch.status !== 0) process.exit(71);
if (child.status !== 0) process.exit(70);
if (process.argv[2] === '--version') { console.log('0.21.11'); process.exit(0); }
if (process.argv[2] === 'sessions') { console.log(JSON.stringify({sessionId:'qwen-session-1', filePath:path.join(root, 'transcript.jsonl')})); process.exit(0); }
const mode = fs.existsSync(path.join(root, 'mode')) ? fs.readFileSync(path.join(root, 'mode'), 'utf8').trim() : 'review';
fs.appendFileSync(path.join(root, 'provider-turns'), 'turn\n');
if (mode === 'publication-failure') {
  const events = fs.readFileSync(path.join(root, 'reviewer-events', 'events.jsonl'), 'utf8').trim().split('\n').map(JSON.parse);
  const current = events.filter(event => event.provider === 'qwen' && event.event === 'started').at(-1);
  fs.writeFileSync(path.join(root, 'reviewer-events', 'evidence', current.run_id, 'required.json'), '{}\n');
}
fs.writeFileSync(path.join(root, 'prompt-copy'), fs.readFileSync(0));
const repo = path.join(root, 'repo');
if (mode === 'slow') { fs.writeFileSync(path.join(root, 'slow-pid'), `${process.pid}\n`); Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 30000); }
if (mode === 'authentication') { console.error('HTTP 401 authentication failed API_KEY=must-not-survive'); process.exit(1); }
if (mode === 'allowance') { console.error('HTTP 429 allowance exhausted raw-payload=must-not-survive'); process.exit(1); }
if (mode === 'model-unavailable') { console.error('requested model unavailable: qwen3.8-max'); process.exit(1); }
if (mode === 'transport') { console.error('socket closed provider payload must-not-survive'); process.exit(70); }
if (mode === 'empty') process.exit(0);
if (mode === 'timeout') process.exit(124);
if (mode === 'tool-budget') { console.error('Run aborted: tool-call budget of 3 exceeded (--max-tool-calls); observed 4.'); process.exit(55); }
if (mode === 'wall-budget') { console.error('Run aborted: wall-clock budget of 900s exceeded (--max-wall-time).'); process.exit(55); }
if (mode === 'turn-budget') { console.error('Reached max session turns for this session. Increase the number of turns by specifying maxSessionTurns in settings.json.'); process.exit(53); }
if (mode === 'terminal-error') { console.log(JSON.stringify({type:'result',subtype:'error',session_id:'qwen-session-1',is_error:true,result:'secret raw payload'})); process.exit(1); }
if (mode === 'runtime-drift') fs.appendFileSync(path.join(process.env.AI_QWEN_SANITIZER_ROOT, 'lib', 'chunks', 'chunk-test.js'), '\n// live drift\n');
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
console.log(JSON.stringify({type:'result',subtype:'success',session_id:mode==='wrong-session'?'qwen-session-other':'qwen-session-1',is_error:false,num_turns:2,result:'## Verdict\nAPPROVE',usage:{input_tokens:11,output_tokens:7},permission_denials:[]}));
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
qualification_retention_cases(){
  local dir="$REPO/.ai/reviews/qwen-qualification" retained rc
  mkdir -p "$REPO/.ai/reviews" "$TMP/qualification-private-temp"
  [ ! -e "$dir" ] || mv "$dir" "$TMP/qualification-before-retention"
  printf 'publication blocked by fixture\n' > "$dir"
  echo wrong-model > "$TMP/mode"
  TMPDIR="$TMP/qualification-private-temp" run doctor --live > "$TMP/qualification-retention.log" 2>&1; rc=$?
  rm "$dir"
  [ ! -e "$TMP/qualification-before-retention" ] || mv "$TMP/qualification-before-retention" "$dir"
  retained="$(sed -n 's/^qualification evidence retained: //p' "$TMP/qualification-retention.log" | head -1)"
  if [ "$rc" -ne 0 ] && [ -n "$retained" ] && [ -s "$retained" ] && [ -s "$retained.p" ] && [ -e "$retained.err" ]; then ok 'failed qualification publication preserves exact stream prompt and stderr'; else bad 'failed qualification publication preserves exact stream prompt and stderr'; fi
  if (
    source <(sed -n '/^cleanup_qualification_probe() {/,/^}/p' "$SCRIPT")
    QUALIFICATION_ACTIVE=1; QUALIFICATION_STREAM="$TMP/interrupted-qualification"
    QUALIFICATION_RUNTIME_SHA=runtime; QUALIFICATION_PRELOADER_SHA=preloader; RUN_TURN_RC=130
    printf stream > "$QUALIFICATION_STREAM"; printf prompt > "$QUALIFICATION_STREAM.p"; printf stderr > "$QUALIFICATION_STREAM.err"
    stop_run_turn(){ :; }; write_qualification_diagnostic(){ return 1; }; note(){ :; }
    cleanup_qualification_probe
    [ "$QUALIFICATION_ACTIVE" = 0 ] && [ -s "$QUALIFICATION_STREAM" ] && [ -s "$QUALIFICATION_STREAM.p" ] && [ -s "$QUALIFICATION_STREAM.err" ]
  ); then ok 'interrupted qualification retains raw evidence when publication fails'; else bad 'interrupted qualification retains raw evidence when publication fails'; fi
  echo review > "$TMP/mode"
}

recovery_cases(){
  local meta pending calls saved_meta saved_stream report before
  echo review > "$TMP/mode"
  if [ "${AI_QWEN_METADATA_TESTS_ONLY:-0}" != 1 ]; then
  mv "$REPO/.ai/reviews" "$REPO/.ai/reviews-before-recovery"
  printf 'publication blocked by fixture\n' > "$REPO/.ai/reviews"
  if run new local-recovery --prompt review > "$TMP/recovery-first.log" 2>&1; then bad 'failed report publication is not success'; else ok 'failed report publication is not success'; fi
  rm "$REPO/.ai/reviews"; mv "$REPO/.ai/reviews-before-recovery" "$REPO/.ai/reviews"
  meta="$(find "$TMP/state/sessions" -name 'codex--local-recovery.json' -print -quit)"; pending="${meta%.json}.pending.jsonl"
  check 'failed local publication preserves a proven pending stream and source binding' "jq -e '.status==\"recovery-required\" and .failure_reason==\"provider_turn_pending_local_validation\" and (.recovery_sha256|length)==64 and (.recovery_event_run_id|length)>0' '$meta' && test -s '$pending'"
  calls="$(wc -l < "$TMP/argv.txt")"
  cp "$meta" "$TMP/recovery-original-meta"; cp "$pending" "$TMP/recovery-original-stream"
  printf '\nchanged' >> "$pending"
  check 'changed retained bytes refuse local finalization' "! run finalize local-recovery > '$TMP/recovery-changed.log' 2>&1"
  cp "$TMP/recovery-original-stream" "$pending"
  jq '.recovery_runtime_sha256="ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"' "$meta" > "$meta.tmp"; mv "$meta.tmp" "$meta"
  check 'changed runtime identity refuses local finalization' "! run finalize local-recovery > '$TMP/recovery-runtime.log' 2>&1"
  cp "$TMP/recovery-original-meta" "$meta"
  cat "$TMP/recovery-original-stream" >> "$pending"
  local duplicate_digest; duplicate_digest="$(sha256sum "$pending" | cut -d' ' -f1)"
  jq --arg d "$duplicate_digest" '.recovery_sha256=$d' "$meta" > "$meta.tmp"; mv "$meta.tmp" "$meta"
  check 'duplicate terminal records cannot be finalized even with a matching stored digest' "! run finalize local-recovery > '$TMP/recovery-duplicate.log' 2>&1"
  cp "$TMP/recovery-original-stream" "$pending"; cp "$TMP/recovery-original-meta" "$meta"
  jq '.failure_reason="interrupted-provider-turn"' "$meta" > "$meta.tmp"; mv "$meta.tmp" "$meta"
  check 'uncertain interrupted work cannot become a local completion' "! run finalize local-recovery > '$TMP/recovery-uncertain.log' 2>&1"
  cp "$TMP/recovery-original-meta" "$meta"
  cp "$REPO/a.txt" "$TMP/recovery-original-source"
  printf 'changed source\n' >> "$REPO/a.txt"
  check 'changed source refuses local finalization' "! run finalize local-recovery > '$TMP/recovery-source.log' 2>&1"
  cp "$TMP/recovery-original-source" "$REPO/a.txt"
  check 'local finalization accepts the exact saved turn' "run finalize local-recovery > '$TMP/recovery-finalize.log' 2>&1"
  check 'finalization publishes metadata before removing pending bytes' "jq -e '.status==\"active\" and .turns==1 and (.last_report_sha256|length)==64' '$meta' && test ! -e '$pending'"
  before="$(jq -c '{turns,last_report,last_report_sha256,last_finalized_stream_sha256}' "$meta")"
  check 'repeated local finalization reuses the same completion' "run finalize local-recovery > '$TMP/recovery-repeat.log' 2>&1 && test '$before' = \"\$(jq -c '{turns,last_report,last_report_sha256,last_finalized_stream_sha256}' '$meta')\""
  check 'recovery and all refusals spend zero additional provider turns' "test '$calls' -eq \"\$(wc -l < '$TMP/argv.txt')\""
  fi
  cat > "$STUB/mv" <<STUBMOVE
#!/usr/bin/env bash
destination="\${@: -1}"
source="\${@: -2:1}"
if [[ "\$destination" == */codex--metadata-recovery.json ]] && jq -e '.status=="active"' "\$source" >/dev/null 2>&1; then exit 73; fi
exec "$(command -v mv)" "\$@"
STUBMOVE
  chmod +x "$STUB/mv"
  if PATH="$STUB:$PATH" run new metadata-recovery --prompt review > "$TMP/recovery-metadata.log" 2>&1; then bad 'metadata publication failure cannot discard the pending turn'; else ok 'metadata publication failure cannot discard the pending turn'; fi
  rm "$STUB/mv"
  meta="$(find "$TMP/state/sessions" -name 'codex--metadata-recovery.json' -print -quit)"; pending="${meta%.json}.pending.jsonl"
  check 'metadata failure retains a complete stream after report publication' "test -s '$pending' && jq -e '.status==\"recovery-required\"' '$meta'"
  calls="$(wc -l < "$TMP/argv.txt")"
  check 'metadata-only recovery finalizes without regenerating' "run finalize metadata-recovery > '$TMP/recovery-metadata-finalize.log' 2>&1 && test '$calls' -eq \"\$(wc -l < '$TMP/argv.txt')\""
  check 'metadata recovery reuses one deterministic report' "test \"\$(find '$REPO/.ai/reviews' -name 'qwen-metadata-recovery-*.md' | wc -l)\" -eq 1"
  echo wrong-session > "$TMP/mode"
  check 'a follow-up returned under a different session is not accepted' "! run ask metadata-recovery --prompt followup > '$TMP/recovery-wrong-session.log' 2>&1 && jq -e '.status==\"recovery-required\"' '$meta'"
  calls="$(wc -l < "$TMP/argv.txt")"
  check 'local recovery cannot adopt a different returned session' "! run finalize metadata-recovery > '$TMP/recovery-wrong-session-finalize.log' 2>&1 && test '$calls' -eq \"\$(wc -l < '$TMP/argv.txt')\""
  echo review > "$TMP/mode"
}
if [ "${AI_QWEN_RECOVERY_TESTS_ONLY:-0}" = 1 ]; then
  env HOME="$TMP/installer-home" PATH="$STUB:$PATH" AI_QWEN_SANITIZER_ROOT="$AI_QWEN_SANITIZER_ROOT" bash "$REPO_ROOT/bin/install-ai-provider-clis.sh" qwen > "$TMP/recovery-install.log" 2>&1 || { cat "$TMP/recovery-install.log"; exit 1; }
  recovery_cases
  printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
  ((FAIL == 0)); exit $?
fi

# A CLI recorder can supervise the actual review worker. Crash the owner of
# this fixture's repository lock, then let its supervisor reap it. Never use
# PID zero as a missing-worker fallback: kill(0) targets the entire test group.
fixture_pid(){ [[ "${1:-}" =~ ^[1-9][0-9]*$ ]] && [ "$1" -gt 1 ]; }
crash_recorded_worker(){ # SUPERVISOR PROVIDER EXPECTED_LOCK_LABEL
  local supervisor="$1" provider="$2" label="$3" dir worker='' rc=0
  for dir in "$AI_QWEN_STATE_DIR"/locks/repo--*.lock.d; do
    [ -f "$dir/label" ] && [ "$(cat "$dir/label")" = "$label" ] || continue
    worker="$(cat "$dir/pid" 2>/dev/null | tr -d '\r\n')"; break
  done
  if ! fixture_pid "$supervisor" || ! fixture_pid "$provider" || ! fixture_pid "$worker"; then
    bad 'crash fixture requires positive recorded worker and provider identities'
    if fixture_pid "$supervisor"; then
      kill -TERM -- "$supervisor" 2>/dev/null || true
      wait "$supervisor" 2>/dev/null || true
    fi
    return 1
  fi
  kill -KILL -- "$worker" 2>/dev/null || true
  kill -KILL -- "$provider" 2>/dev/null || true
  wait "$supervisor" 2>/dev/null || rc=$?
  [ "$rc" -ne 0 ] || { bad 'crashed review worker must report a nonzero result'; return 1; }
}

echo 'ai-qwen tests'
check 'missing crash worker cannot signal the test process group' '( kill(){ printf called > "$TMP/invalid-crash-signal"; }; wait(){ :; }; crash_recorded_worker 0 0 missing >/dev/null 2>&1; rc=$?; [ "$rc" -ne 0 ] && [ ! -e "$TMP/invalid-crash-signal" ] )'
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
INITIAL_STARTED=$SECONDS
INITIAL_OUT="$(run new review-1 --prompt 'review this' 2>&1)"; INITIAL_RC=$?
# Measure the guarded source/runtime startup, not just one process spawn.
# This provider fixture does no network work. Keep the existing minimum.
QWEN_STARTUP_TICKS=$(( ((SECONDS-INITIAL_STARTED)*2 + $(budget 2 5)) * 20 ))
[ "$QWEN_STARTUP_TICKS" -ge "$(scale_ticks 200)" ] || QWEN_STARTUP_TICKS="$(scale_ticks 200)"
[ "$INITIAL_RC" -eq 0 ] || printf '  diagnostic: initial review: %s\n' "$INITIAL_OUT"
check 'initial review completes successfully' "test '$INITIAL_RC' -eq 0"
printf 'preload-test-secret\n' > "$TMP/preload-secret"; chmod 600 "$TMP/preload-secret"
PRELOAD_PROOF="$(AI_QWEN_SECRET_FILE="$TMP/preload-secret" PRELOAD_TEST_FILE="$TMP/preload-secret" NODE_OPTIONS="--require=$REPO_ROOT/tools/qwen-provider-env-preload.cjs" node -e 'const {spawnSync}=require("node:child_process"),fs=require("node:fs"); const reexec=spawnSync(process.execPath,["-e","process.stdout.write(process.env.BAILIAN_CODING_PLAN_API_KEY||\"absent\")"],{encoding:"utf8"}); const sanitized={...process.env}; delete sanitized.BAILIAN_CODING_PLAN_API_KEY; const toolChild=spawnSync(process.execPath,["-e","process.stdout.write(process.env.BAILIAN_CODING_PLAN_API_KEY||\"absent\")"],{encoding:"utf8",env:sanitized}); process.stdout.write(JSON.stringify({direct:process.env.BAILIAN_CODING_PLAN_API_KEY,handoffVar:Object.hasOwn(process.env,"AI_QWEN_SECRET_FILE"),handoffFile:fs.existsSync(process.env.PRELOAD_TEST_FILE),reexec:reexec.stdout,toolChild:toolChild.stdout}));')"
check 'Qwen preloader survives the runtime re-exec, deletes its handoff, and stays strippable for tool children' "printf '%s' '$PRELOAD_PROOF' | jq -e '.direct==\"preload-test-secret\" and .handoffVar==false and .handoffFile==false and .reexec==\"preload-test-secret\" and .toolChild==\"absent\"'"
if [ -n "${SYSTEMROOT:-}" ]; then
  check 'Qwen runtime home has a private Windows ACL before provider contact' "test -f '$AI_QWEN_HOME/.ai-devops-private-home-v1' && ! icacls.exe \"\$(cygpath -w '$AI_QWEN_HOME')\" | grep -Ei 'BUILTIN\\\\Users|Authenticated Users|Everyone'"
else
  check 'Qwen runtime home is mode 0700 before provider contact' "test \"\$(stat -c %a '$AI_QWEN_HOME')\" = 700"
fi
check 'review pins the stable Qwen 3.8 Max model' "grep -q -- '--model qwen3.8-max' '$TMP/argv.txt'"
check 'review uses safe mode' "grep -q -- '--safe-mode' '$TMP/argv.txt'"
check 'review uses plan mode' "grep -q -- '--approval-mode plan' '$TMP/argv.txt'"
check 'review excludes mutation tools' "grep -q -- '--exclude-tools shell,write,edit' '$TMP/argv.txt'"
check 'review has measured governed-review budgets' "grep -q -- '--max-session-turns 120' '$TMP/argv.txt' && grep -q -- '--max-tool-calls 120' '$TMP/argv.txt' && grep -q -- '--max-wall-time 30m' '$TMP/argv.txt'"
check 'review never uses yolo or continue' "! grep -qE -- '--approval-mode yolo|--continue' '$TMP/argv.txt'"
check 'review record stores exact session' "run show review-1 | jq -e '.qwen_session_id==\"qwen-session-1\" and .caller==\"codex\"'"
check 'review record binds exact evidence identity' "run show review-1 | jq -e '(.base|length)==40 and (.head|length)==40 and (.packet_sha256|length)==64 and (.working_tree_sha256|length)==64 and .evidence_generation==1'"
check 'governed auth settings are regular and pin both provider and active model identity' "test -f '$AI_QWEN_HOME/settings.json' && test ! -L '$AI_QWEN_HOME/settings.json' && jq -e '.model.baseUrl as \$url | .security.auth.selectedType==\"openai\" and .model.name==\"qwen3.8-max\" and (\$url|length)>0 and (.modelProviders.openai|any(.id==\"qwen3.8-max\" and .baseUrl==\$url and .envKey==\"BAILIAN_CODING_PLAN_API_KEY\"))' '$AI_QWEN_HOME/settings.json'"
check 'review prompt requires the sealed packet first' "grep -q '.ai-review-qwen-codex-review-1/MANIFEST.md' '$TMP/prompt-copy'"
REVIEW_DIR="$(run show review-1 | jq -r .review_dir)"
check 'ordinary clone review uses a private copy' "[ \"\$(cd '$REVIEW_DIR' && pwd -P)\" != \"\$(cd '$REPO' && pwd -P)\" ]"
check 'private review copy owns its git controls' "test -d '$REVIEW_DIR/.git'"

FIRST_ASK_OUT="$(run ask review-1 --prompt 'follow up' 2>&1)"; FIRST_ASK_RC=$?
[ "$FIRST_ASK_RC" -eq 0 ] || printf '  diagnostic: first follow-up: %s\n' "$FIRST_ASK_OUT"
check 'first follow-up completes successfully' "test '$FIRST_ASK_RC' -eq 0"
check 'follow-up resumes exact session' "grep -q -- '--resume qwen-session-1' '$TMP/argv.txt'"
check 'follow-up keeps the recorded review copy' "[ \"\$(run show review-1 | jq -r .review_dir)\" = '$REVIEW_DIR' ]"

echo publication-failure > "$TMP/mode"
run new publication-failed --prompt 'retain this completed result' > "$TMP/publication-failed.out" 2>&1; PUBLICATION_RC=$?
check 'publication failure cannot become an active accepted review' "test '$PUBLICATION_RC' -ne 0 && run show publication-failed | jq -e '.status!=\"active\"'"
PENDING_REPORT="$(run show publication-failed | jq -r .recovery_stream)"
check 'publication failure retains completed provider stream' "test -s '$PENDING_REPORT' && grep -q APPROVE '$PENDING_REPORT'"
TURNS_BEFORE_PUBLICATION_RETRY="$(wc -l < "$TMP/provider-turns")"
run ask publication-failed --prompt retry > "$TMP/publication-retry.out" 2>&1; PUBLICATION_RETRY_RC=$?
check 'unpublished review refuses paid replay' "test '$PUBLICATION_RETRY_RC' -ne 0 && test '$TURNS_BEFORE_PUBLICATION_RETRY' -eq \"\$(wc -l < '$TMP/provider-turns')\""
echo review > "$TMP/mode"
if [ "${AI_QWEN_DURABILITY_TESTS_ONLY:-0}" = 1 ]; then
  printf '%d passed, %d failed\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ]; exit $?
fi

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

for budget_mode in tool-budget wall-budget turn-budget; do
  echo "$budget_mode" > "$TMP/mode"
  BUDGET_OUT="$(run new "$budget_mode" --prompt review 2>&1)"; BUDGET_RC=$?
  BUDGET_META="$(find "$TMP/state/sessions" -name "codex--$budget_mode.json" -print -quit)"
  [ "$BUDGET_RC" -ne 0 ] && printf '%s' "$BUDGET_OUT" | grep -q 'terminal reason: turn_limit_cancelled' \
    && jq -e '.status=="recovery-required" and .failure_reason=="turn_limit_cancelled"' "$BUDGET_META" >/dev/null \
    && ok "$budget_mode is immediately classified as turn_limit_cancelled" \
    || bad "$budget_mode is immediately classified as turn_limit_cancelled"
done
check 'budget-limited recovery reports explain the typed terminal reason' "sed -n '/^safe_report_detail()/,/^}/p' '$SCRIPT' | grep -Fq 'Qwen stopped at a bounded session-turn, tool-call, or wall-clock limit.'"
echo review > "$TMP/mode"

run new budget-followup --prompt review >/dev/null 2>&1
echo tool-budget > "$TMP/mode"
BUDGET_FOLLOWUP_OUT="$(run ask budget-followup --prompt followup 2>&1)"; BUDGET_FOLLOWUP_RC=$?
BUDGET_FOLLOWUP_META="$(find "$TMP/state/sessions" -name 'codex--budget-followup.json' -print -quit)"
[ "$BUDGET_FOLLOWUP_RC" -ne 0 ] && printf '%s' "$BUDGET_FOLLOWUP_OUT" | grep -q 'terminal reason: turn_limit_cancelled' \
  && jq -e '.status=="recovery-required" and .failure_reason=="turn_limit_cancelled"' "$BUDGET_FOLLOWUP_META" >/dev/null \
  && ok 'follow-up budget exhaustion preserves the typed terminal reason' \
  || bad 'follow-up budget exhaustion preserves the typed terminal reason'
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
for _ in $(seq 1 "$QWEN_STARTUP_TICKS"); do [ -s "$TMP/slow-pid" ] && [ -n "$(find "$TMP/state/sessions" -name 'codex--crash-new.json' -print -quit 2>/dev/null)" ] && break; sleep .05; done
CRASH_NEW_META="$(find "$TMP/state/sessions" -name 'codex--crash-new.json' -print -quit)"; CRASH_CHILD="$(cat "$TMP/slow-pid" 2>/dev/null || true)"
check 'new paid turn is durable before untrappable termination' "jq -e '.status==\"turn_in_progress\"' '$CRASH_NEW_META'"
crash_recorded_worker "$CRASH_NEW_PID" "$CRASH_CHILD" review:crash-new || exit 1
CALLS_AFTER_CRASH_NEW="$(wc -l < "$TMP/argv.txt")"; run new crash-new --prompt retry >/dev/null 2>&1; RC=$?
[ "$RC" -ne 0 ] && [ "$CALLS_AFTER_CRASH_NEW" = "$(wc -l < "$TMP/argv.txt")" ] && ok 'crashed new review cannot be charged again under the same name' || bad 'crashed new review cannot be charged again under the same name'

echo review > "$TMP/mode"
if ! run new crash-followup --prompt review >/dev/null 2>&1; then
  bad 'follow-up crash fixture must start before termination is attempted'; exit 1
fi
echo slow > "$TMP/mode"; rm -f "$TMP/slow-pid"
(cd "$REPO" && exec env AI_QWEN_STATE_DIR="$AI_QWEN_STATE_DIR" AI_QWEN_CALLER=codex AI_QWEN_BIN="$AI_QWEN_BIN" AI_QWEN_HOME="$AI_QWEN_HOME" AI_QWEN_TEST_DIR="$AI_QWEN_TEST_DIR" AI_QWEN_OP_ENV_FILE="$AI_QWEN_OP_ENV_FILE" AI_QWEN_OP_BIN="$AI_QWEN_OP_BIN" TMPDIR_FOR_TEST="$TMPDIR_FOR_TEST" AI_DEVOPS_CONFIG_DIR="$AI_DEVOPS_CONFIG_DIR" "$SCRIPT" ask crash-followup --prompt wait >/dev/null 2>&1) & CRASH_FOLLOW_PID=$!
for _ in $(seq 1 "$QWEN_STARTUP_TICKS"); do [ -s "$TMP/slow-pid" ] && break; sleep .05; done
CRASH_FOLLOW_META="$(find "$TMP/state/sessions" -name 'codex--crash-followup.json' -print -quit)"; CRASH_CHILD="$(cat "$TMP/slow-pid" 2>/dev/null || true)"
check 'follow-up is durable before untrappable termination' "jq -e '.status==\"turn_in_progress\"' '$CRASH_FOLLOW_META'"
crash_recorded_worker "$CRASH_FOLLOW_PID" "$CRASH_CHILD" ask:crash-followup || exit 1
CALLS_AFTER_CRASH_FOLLOW="$(wc -l < "$TMP/argv.txt")"; run ask crash-followup --prompt retry >/dev/null 2>&1; RC=$?
[ "$RC" -ne 0 ] && [ "$CALLS_AFTER_CRASH_FOLLOW" = "$(wc -l < "$TMP/argv.txt")" ] && ok 'crashed follow-up cannot resume the uncertain provider conversation' || bad 'crashed follow-up cannot resume the uncertain provider conversation'

echo review > "$TMP/mode"; run new interrupt-followup --prompt review >/dev/null 2>&1
echo slow > "$TMP/mode"; CALLS_BEFORE_INTERRUPT="$(wc -l < "$TMP/argv.txt")"
(cd "$REPO" && exec env AI_QWEN_STATE_DIR="$AI_QWEN_STATE_DIR" AI_QWEN_CALLER=codex AI_QWEN_BIN="$AI_QWEN_BIN" AI_QWEN_HOME="$AI_QWEN_HOME" AI_QWEN_TEST_DIR="$AI_QWEN_TEST_DIR" AI_QWEN_OP_ENV_FILE="$AI_QWEN_OP_ENV_FILE" AI_QWEN_OP_BIN="$AI_QWEN_OP_BIN" TMPDIR_FOR_TEST="$TMPDIR_FOR_TEST" AI_DEVOPS_CONFIG_DIR="$AI_DEVOPS_CONFIG_DIR" "$SCRIPT" ask interrupt-followup --prompt wait >/dev/null 2>&1) & INTERRUPT_FOLLOWUP_PID=$!
for _ in $(seq 1 "$QWEN_STARTUP_TICKS"); do [ "$(wc -l < "$TMP/argv.txt")" -gt "$CALLS_BEFORE_INTERRUPT" ] && break; sleep .05; done
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
check 'implementation retains its narrower bounded limits' "grep -q -- '--max-session-turns 30' '$TMP/argv.txt' && grep -q -- '--max-tool-calls 80' '$TMP/argv.txt' && grep -q -- '--max-wall-time 15m' '$TMP/argv.txt'"
check 'implementation requires installed child-process credential hardening' "grep -q 'assert_qwen_child_env_hardened || die' '$SCRIPT'"
check 'every mode, review included, requires installed child-process credential hardening' "grep -A4 '^  assert_qwen_child_env_hardened || die' '$SCRIPT' | grep -q '= review ]'"
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
check 'doctor reports distinct read-only review and write-run budgets' "printf '%s\\n' \"\$DOCTOR_ONE\" | grep -q '^review budgets: turns=120 tools=120 wall=30m$' && printf '%s\\n' \"\$DOCTOR_ONE\" | grep -q '^write budgets : turns=30 tools=80 wall=15m$'"
DOCTOR_IDENTITY="$(AI_QWEN_BIN="$TMP/missing-qwen" run doctor --identity)"
check 'identity doctor returns one strict runtime and preloader fingerprint record without starting Qwen' "test \"\$(printf '%s\\n' \"\$DOCTOR_IDENTITY\" | wc -l)\" -eq 1 && printf '%s\\n' \"\$DOCTOR_IDENTITY\" | grep -Eq '^IDENTITY runtime_sha256=[0-9a-f]{64} preloader_sha256=[0-9a-f]{64}$'"
check 'runtime fingerprint declares its GNU tar prerequisite' "sed -n '/^qwen_runtime_sha256()/,/^}/p' '$SCRIPT' | grep -q 'GNU tar is required'"
check 'doctor rejects conflicting modes' "! run doctor --identity --live"
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
WRONG_DOCTOR="$(run doctor --live 2>&1)"; WRONG_DOCTOR_RC=$?
if [ "$WRONG_DOCTOR_RC" -eq 0 ]; then bad 'live doctor rejects a returned model mismatch'; else ok 'live doctor rejects a returned model mismatch'; fi
QWEN_DIAGNOSTICS="$REPO/.ai/reviews/qwen-qualification"
if jq -e 'select(.failure_class=="returned-model-mismatch" and .requested_model=="qwen3.8-max" and .returned_model=="qwen-other" and .terminal_record_exists==true)' "$QWEN_DIAGNOSTICS"/*.json >/dev/null 2>&1; then
  ok 'model mismatch leaves only safe actionable metadata'
else
  printf '  diagnostic: model-mismatch doctor: %s\n' "$WRONG_DOCTOR"
  printf '  diagnostic: model-mismatch artifact: '; jq -c . "$QWEN_DIAGNOSTICS"/*.json 2>/dev/null || printf 'missing'; printf '\n'
  bad 'model mismatch leaves only safe actionable metadata'
fi
qualification_retention_cases
for fixture in authentication allowance model-unavailable transport empty fail terminal-error timeout runtime-drift; do
  echo "$fixture" > "$TMP/mode"
  run doctor --live >/dev/null 2>&1 || true
done
check 'all governed live failure classes are deterministic' "for class in authentication-failure allowance-exhaustion requested-model-unavailable provider-process-transport-failure empty-provider-stream missing-terminal-result terminal-result-error timeout wrapper-runtime-evidence-drift; do grep -l \"\\\"failure_class\\\":\\\"\$class\\\"\" '$QWEN_DIAGNOSTICS'/*.json >/dev/null || return 1; done"
check 'diagnostic schema retains the required safe evidence' "jq -e '.host and .timestamp and .requested_model and .wrapper_sha256 and .runtime_sha256 and .preloader_sha256 and (.provider_exit_status|type==\"number\") and (.terminal_record_exists|type==\"boolean\") and (.terminal_error|type==\"boolean\") and .stderr_classification' '$QWEN_DIAGNOSTICS'/*.json >/dev/null"
check 'diagnostics redact credentials prompts and raw provider payloads' "! grep -ER 'must-not-survive|secret raw payload|Reply with exactly' '$QWEN_DIAGNOSTICS'"
check 'diagnostics remain under the ignored review evidence area' "git -C '$REPO' check-ignore '$QWEN_DIAGNOSTICS'/*.json >/dev/null"
echo slow > "$TMP/mode"; rm -f "$TMP/slow-pid"; INTERRUPT_DIAGNOSTICS_BEFORE="$(find "$QWEN_DIAGNOSTICS" -type f | wc -l)"
(cd "$REPO" && exec env AI_QWEN_STATE_DIR="$AI_QWEN_STATE_DIR" AI_QWEN_CALLER=codex AI_QWEN_BIN="$AI_QWEN_BIN" AI_QWEN_HOME="$AI_QWEN_HOME" AI_QWEN_SANITIZER_ROOT="$AI_QWEN_SANITIZER_ROOT" AI_QWEN_TEST_DIR="$AI_QWEN_TEST_DIR" AI_QWEN_OP_ENV_FILE="$AI_QWEN_OP_ENV_FILE" AI_QWEN_OP_BIN="$AI_QWEN_OP_BIN" TMPDIR_FOR_TEST="$TMPDIR_FOR_TEST" "$SCRIPT" doctor --live >/dev/null 2>&1) & DOCTOR_INTERRUPT_PID=$!
for _ in $(seq 1 "$QWEN_STARTUP_TICKS"); do [ -s "$TMP/slow-pid" ] && break; sleep .05; done
kill -TERM "$DOCTOR_INTERRUPT_PID" 2>/dev/null || true; wait "$DOCTOR_INTERRUPT_PID" 2>/dev/null || true
check 'interrupted live qualification retains safe diagnostics' "test \"\$(find '$QWEN_DIAGNOSTICS' -type f | wc -l)\" -gt '$INTERRUPT_DIAGNOSTICS_BEFORE' && grep -l '\"failure_class\":\"timeout\"' '$QWEN_DIAGNOSTICS'/*.json >/dev/null"
check 'interrupted live qualification removes temporary secret handoffs' "test -z \"\$(find '$AI_QWEN_HOME/tmp' -maxdepth 1 -name '.qwen-secret.*' -print -quit)\""
echo review > "$TMP/mode"
DIAGNOSTICS_BEFORE_SUCCESS="$(find "$QWEN_DIAGNOSTICS" -type f | wc -l)"
check 'live doctor requires terminal success from the pinned model' 'run doctor --live'
check 'successful live qualification creates no failure artifact' "test '$DIAGNOSTICS_BEFORE_SUCCESS' = \"\$(find '$QWEN_DIAGNOSTICS' -type f | wc -l)\""

echo fail > "$TMP/mode"
if run new no-terminal --prompt x >/dev/null 2>&1; then bad 'missing terminal result fails'; else ok 'missing terminal result fails'; fi

echo "== #1220: silence must never read as APPROVE =="
# ai-qwen carried the identical extract_answer defect as ai-kimi: it printed only
# the tail from '## Verdict' (discarding findings that sat above it) and treated a
# run that ended with no verdict as a review with nothing to say. Exercised
# directly, because these are pure-text defects.
sed -n '/^provider_api_error() {/,/^}/p; /^extract_answer() {/,/^}/p' "$SCRIPT" > "$TMP/extract.sh"
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

printf '%s\n' '{"type":"result","is_error":false,"result":"[API Error: synthetic refusal]"}' > "$TMP/api-error.jsonl"
API_ERROR="$(probe "$TMP/api-error.jsonl")"
check 'a terminal provider refusal is classified before verdict parsing' "printf '%s' \"\$API_ERROR\" | grep -q 'provider refused the call'"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"[API Error: synthetic refusal]"}]}}' > "$TMP/assistant-api-error.jsonl"
cat "$TMP/good.jsonl" >> "$TMP/assistant-api-error.jsonl"
ASSISTANT_API_ERROR="$(probe "$TMP/assistant-api-error.jsonl")"
check 'an assistant provider refusal cannot become an approved review' "printf '%s' \"\$ASSISTANT_API_ERROR\" | grep -q 'provider refused the call'"

printf '%s\n' '{"type":"result","is_error":false,"result":"finding\n## Verdict\nMAYBE"}' > "$TMP/invalid-verdict.jsonl"
INVALID="$(probe "$TMP/invalid-verdict.jsonl")"
check 'an invalid verdict word is rejected' "printf '%s' \"\$INVALID\" | grep -q 'APPROVE, REJECT, or BLOCKED'"

GOVERNED_HEAD=0123456789abcdef0123456789abcdef01234567
printf '%s\n' "{\"type\":\"result\",\"is_error\":false,\"result\":\"coverage and findings\\nVERDICT: APPROVE $GOVERNED_HEAD\"}" > "$TMP/governed.jsonl"
sed -n '/^provider_api_error() {/,/^}/p; /^extract_answer() {/,/^}/p; /^report_answer_defect() {/,/^}/p' "$SCRIPT" > "$TMP/extract-governed.sh"
GOVERNED="$(bash -c 'ANSWER_DEFECT=""; OPT_GOVERNED_VERDICT="$3"; source "$1"; extract_answer "$2"; report_answer_defect governed "$2"' _ "$TMP/extract-governed.sh" "$TMP/governed.jsonl" "$GOVERNED_HEAD" 2>&1)"
check 'a governed SHA-bound verdict preserves the full report' "printf '%s' \"\$GOVERNED\" | grep -q 'coverage and findings' && printf '%s' \"\$GOVERNED\" | grep -q \"VERDICT: APPROVE $GOVERNED_HEAD\""
printf '%s\n' "{\"type\":\"result\",\"is_error\":false,\"result\":\"coverage\\nVERDICT: APPROVE ffffffffffffffffffffffffffffffffffffffff\"}" > "$TMP/governed-wrong-head.jsonl"
GOVERNED_WRONG="$(bash -c 'ANSWER_DEFECT=""; OPT_GOVERNED_VERDICT="$3"; source "$1"; extract_answer "$2" >/dev/null; report_answer_defect governed "$2"' _ "$TMP/extract-governed.sh" "$TMP/governed-wrong-head.jsonl" "$GOVERNED_HEAD" 2>&1 || true)"
check 'a governed verdict for the wrong head is rejected' "printf '%s' \"\$GOVERNED_WRONG\" | grep -q 'bound to $GOVERNED_HEAD'"
printf '%s\n' '{"type":"result","is_error":false,"result":"coverage\n## Verdict\nAPPROVE"}' > "$TMP/governed-standard-format.jsonl"
GOVERNED_STANDARD="$(bash -c 'ANSWER_DEFECT=""; OPT_GOVERNED_VERDICT="$3"; source "$1"; extract_answer "$2" >/dev/null; report_answer_defect governed "$2"' _ "$TMP/extract-governed.sh" "$TMP/governed-standard-format.jsonl" "$GOVERNED_HEAD" 2>&1 || true)"
check 'ordinary verdict format is rejected in governed mode' "printf '%s' \"\$GOVERNED_STANDARD\" | grep -q 'exactly one SHA-bound VERDICT line'"

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
check 'the real provider key reaches Qwen only under the one name Qwen strips from its children' "test \"\$(grep -c 'fake-qwen-only' '$TMP/qwen-env')\" = 1 && grep -q '^BAILIAN_CODING_PLAN_API_KEY=fake-qwen-only$' '$TMP/qwen-env' && ! grep -Eq 'DEVOPS|OP_SERVICE|SUPABASE|RANDOM' '$TMP/qwen-credential-names'"
check 'the Qwen startup relaunch still receives the provider key' "test \"\$(cat '$TMP/qwen-relaunch-key')\" = fake-qwen-only"
check 'Qwen secret handoff is removed after every provider turn' "test -z \"\$(find '$AI_QWEN_HOME/tmp' -maxdepth 1 -name '.qwen-secret.*' -print -quit)\""
check 'agent-controlled Qwen children cannot inherit the real provider key' "! grep -q '^BAILIAN_CODING_PLAN_API_KEY=' '$TMP/qwen-tool-child-env' && ! grep -q 'fake-qwen-only' '$TMP/qwen-tool-child-env'"
check 'real Qwen provider key uses one private self-deleting handoff and is removed before Qwen exec' "grep -q 'chmod 600 \"\$RUN_TURN_SECRET_FILE\"' '$SCRIPT' && grep -q 'unset BAILIAN_CODING_PLAN_API_KEY keep_qwen_key' '$SCRIPT' && grep -q 'AI_QWEN_SECRET_FILE=' '$SCRIPT'"
check 'hostile shell startup hooks cannot observe managed credentials' "test ! -e '$TMP/hostile-bash-env-fired' && grep -q '\"\$QWEN_ENV_BIN\" -u BASH_ENV -u ENV \"\$op_bin\"' '$SCRIPT'"
check 'credentialed Qwen boundary uses only prevalidated absolute executables' "grep -q 'trusted absolute Bash/env executables are required' '$SCRIPT' && grep -q 'clean_env=(\"\$env_bin\" -i' '$SCRIPT' && grep -q '\"\$bash_bin\" --noprofile --norc' '$SCRIPT'"
echo slow > "$TMP/mode"; rm -f "$TMP/op-env-source"
(cd "$REPO" && exec env HOME="$HOME" PATH="$PATH" AI_QWEN_STATE_DIR="$AI_QWEN_STATE_DIR" AI_QWEN_CALLER=codex AI_QWEN_BIN="$AI_QWEN_BIN" AI_QWEN_HOME="$AI_QWEN_HOME" AI_QWEN_TEST_DIR="$AI_QWEN_TEST_DIR" AI_QWEN_OP_ENV_FILE="$AI_QWEN_OP_ENV_FILE" AI_QWEN_OP_BIN="$AI_QWEN_OP_BIN" TMPDIR_FOR_TEST="$TMPDIR_FOR_TEST" "$SCRIPT" new interrupted-credential --prompt review >/dev/null 2>&1) & QWEN_INTERRUPT_PID=$!
for _ in $(seq 1 "$QWEN_STARTUP_TICKS"); do [ -s "$TMP/op-env-source" ] && break; sleep .05; done
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

recovery_cases
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
