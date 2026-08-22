#!/usr/bin/env bash
# Tests for bin/ai-kimi.
#
# Offline by default: a stub `kimi` stands in for the real binary. Live probes
# (including the read-only canary) run only with AI_KIMI_LIVE=1.
#
# The tests that must never be weakened:
#   - await_requires_resume_hint : completion is proven by the terminal record,
#     not by exit status.
#   - review_uses_readonly_agent / review_refuses_without_agent_file : the
#     structural read-only guarantee. Kimi writes files freely without it —
#     verified against the real CLI, see bin/ai-kimi's STEP 0 header.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-kimi"
PASS=0; FAIL=0
ok()   { printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
check "missing local runtime is never a provider failure" "grep -q 'PREFLIGHT_CLASS=\"local_dependency_unavailable\"' '$SCRIPT' && ! grep -q 'PREFLIGHT_CLASS=\"provider-unavailable\"' '$SCRIPT'"
check "local runtime failure says Kimi was not contacted" "grep -q 'LOCAL Kimi runtime.*not a Kimi provider fault' '$SCRIPT'"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export AI_KIMI_STATE_DIR="$TMP/state"
export AI_REVIEW_SANDBOX_DIR="$TMP/review-sandboxes"
export AI_KIMI_CALLER="claude"
export AI_KIMI_POLL_INTERVAL=1
export AI_KIMI_WAIT_TIMEOUT=15

REPO="$TMP/repo"; mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@example.com; git -C "$REPO" config user.name T
git -C "$REPO" remote add origin https://example.invalid/test/repo.git
printf '.ai/reviews/\nignored-build/\n' > "$REPO/.gitignore"; echo hi > "$REPO/a.txt"
git -C "$REPO" add -A; git -C "$REPO" commit -qm init

STUB="$TMP/bin"; mkdir -p "$STUB"
cat > "$STUB/kimi" <<'STUBEOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TMPDIR_FOR_TEST/argv.txt"
printf '%s\n' "$PWD" >> "$TMPDIR_FOR_TEST/pwd.txt"
mode="$(cat "$TMPDIR_FOR_TEST/mode" 2>/dev/null || echo ok)"
case "${1:-}" in
  --version) echo "0.32.0"; exit 0 ;;
  provider)  [ "$mode" = noauth ] && exit 1; echo "managed:kimi-code type=kimi"; exit 0 ;;
  export)
    while [ $# -gt 0 ]; do
      if [ "$1" = -o ]; then printf 'zip-fixture' > "$2"; exit 0; fi
      shift
    done
    exit 1 ;;
esac
case "$mode" in
  ok)      cat "$TMPDIR_FOR_TEST/fixture.jsonl" ;;
  nohint)  printf '{"role":"assistant","content":"partial answer"}\n' ;;   # no terminal record
  directoryerror) printf 'Session was created under a different directory\n' >&2; exit 7 ;;
  empty)   : ;;
  writes)  cat "$TMPDIR_FOR_TEST/fixture.jsonl"; echo tampered >> a.txt ;;
  implcommit)
    printf 'committed delegate work\n' > committed.txt
    git add committed.txt && git -c user.email=t@example.com -c user.name=T commit -qm delegate
    cat "$TMPDIR_FOR_TEST/fixture.jsonl" ;;
  persistent)
    test "$(git config --bool core.longpaths)" = true || exit 8
    if printf '%s\n' "$*" | grep -q -- '-r session_35e1a0a2'; then
      printf 'continued\n' >> "$TMPDIR_FOR_TEST/persistent-calls.txt"
      test -f first-turn.txt || exit 9
      grep -q first-turn first-turn.txt || exit 9
      test ! -e ignored-build/marker.txt || exit 9
      printf 'second-turn\n' > second-turn.txt
      printf '\003\004TURN-TWO\376' >> persistent.bin
    else
      printf 'first-turn \n' > first-turn.txt
      printf '\000\001TURN-ONE\377' > persistent.bin
      mkdir -p ignored-build; printf ephemeral > ignored-build/marker.txt
    fi
    cat "$TMPDIR_FOR_TEST/fixture.jsonl" ;;
  continuationpartial)
    test -f first-turn.txt && test -f second-turn.txt || exit 9
    printf 'failed-turn-only\n' > failed-turn-only.txt
    printf '{"role":"assistant","content":"provider interrupted before completion"}\n'
    exit 7 ;;
  usagepartial)
    printf 'partial source work\n' > partial.txt
    printf '\000\001\002KIMI-PARTIAL\377' > partial.bin
    printf '{"role":"assistant","content":"Usage limit reached for this billing cycle"}\n' ;;
  networkpartial)
    printf 'network interrupted work\n' > network-partial.txt
    printf 'provider connection interrupted\n' >&2
    printf '{"role":"assistant","content":"provider interrupted"}\n'
    exit 7 ;;
  failednochange)
    printf 'provider connection interrupted\n' >&2 ;;
  timeoutpartial)
    printf 'deadline interrupted work\n' > timeout-partial.txt
    printf '{"role":"assistant","content":"not terminal"}\n'
    sleep 30 ;;
  interruptpartial)
    printf 'cancelled work\n' > interrupt-partial.txt
    while :; do sleep 1; done ;;
  slow) sleep 30 ;;
esac
exit 0
STUBEOF
chmod +x "$STUB/kimi"
export TMPDIR_FOR_TEST="$TMP"
export AI_KIMI_BIN="$STUB/kimi"
export KIMI_CODE_HOME="$TMP/kimi-home"

cat > "$TMP/fixture.jsonl" <<'EOF'
{"role":"user","content":"review this"}
{"role":"assistant","content":"I'll read the files.\n## Verdict\nAPPROVE — looks fine."}
{"role":"meta","type":"session.resume_hint","session_id":"session_35e1a0a2-139f-4095-afdd-fce90a32ed2d","command":"kimi -r session_35e1a0a2"}
EOF
echo ok > "$TMP/mode"

run() { ( cd "$REPO" && bash "$SCRIPT" "$@" ); }

echo "ai-kimi tests"

echo "== usage_and_exit_codes =="
run >/dev/null 2>&1; [ $? -eq 2 ] && ok "no args exits 2" || bad "no args exits 2"
run nope >/dev/null 2>&1; [ $? -eq 2 ] && ok "unknown command exits 2" || bad "unknown command exits 2"
check "help exits 0" "run --help"

echo "== review_uses_readonly_agent (structural read-only) =="
: > "$TMP/argv.txt"
run new r1 --prompt "review" >/dev/null 2>&1
check "review passes --agent-file"   "grep -q -- '--agent-file' '$TMP/argv.txt'"
check "review pins the model"        "grep -q -- '-m kimi-code/k3' '$TMP/argv.txt'"
check "review uses stream-json"      "grep -q -- '--output-format stream-json' '$TMP/argv.txt'"
check "never uses --yolo"            "! grep -q -- '--yolo' '$TMP/argv.txt'"
check "never uses --auto"            "! grep -q -- '--auto' '$TMP/argv.txt'"
check "never uses -c/--continue"     "! grep -qE -- '(^| )-c( |$)|--continue' '$TMP/argv.txt'"
check "preflight created an isolated Kimi sessions directory" "test -d '$KIMI_CODE_HOME/sessions'"
REVIEW_WORKSPACE="$(tail -1 "$TMP/pwd.txt" 2>/dev/null || true)"
check "review runs in a private workspace" "test -n '$REVIEW_WORKSPACE' && test '$REVIEW_WORKSPACE' != '$REPO' && test -d '$REVIEW_WORKSPACE/.git'"

echo "== durable_review_jobs =="
JOB_ID="$(run start durable --prompt review)"
check "start returns a durable job id" "test -n '$JOB_ID'"
check "status reports a durable phase" "run status durable | jq -e '.phase == \"preflight\" or .phase == \"starting\" or .phase == \"running\" or .phase == \"completed\"'"
run wait durable >/dev/null 2>&1
check "worker finalizes only on resume hint" "run status durable | jq -e '.phase == \"completed\" and .terminal_reason == \"session.resume_hint\"'"
check "durable job records measured preparation and provider timing" "run status durable | jq -e '.timing.snapshot_seconds >= 0 and .timing.test_seconds >= 0 and .timing.packet_seconds >= 0 and .timing.provider_seconds >= 0 and .timing.model_steps == \"unavailable\"'"
check "result is available after terminal proof" "run result durable | grep -q APPROVE"
check "completed review has one hashed canonical artifact" "run status durable | jq -e '.artifact_kind == \"complete\" and (.artifact_sha256|length)==64 and (.artifact_paths.canonical|length)>0'"
CANONICAL="$(run status durable | jq -r .artifact_paths.canonical)"
MIRROR="$(run status durable | jq -r .artifact_paths.repository)"
check "canonical and optional repository mirror both exist" "test -f '$CANONICAL' && test -f '$MIRROR'"
MIRRORS_BEFORE="$(find "$REPO/.ai/reviews" -name 'kimi-durable-*.md' | wc -l)"
run result durable >/dev/null 2>&1
MIRRORS_AFTER="$(find "$REPO/.ai/reviews" -name 'kimi-durable-*.md' | wc -l)"
[ "$MIRRORS_AFTER" = "$MIRRORS_BEFORE" ] && ok "repeated result retrieval creates no duplicate" || bad "repeated result retrieval creates no duplicate"
DURABLE_META="$(find "$AI_KIMI_STATE_DIR/jobs" -path '*claude--durable/job.json' -print -quit)"
jq '.artifact_sha256=null|.artifact_kind=null|.phase="recovery-required"' "$DURABLE_META" > "$DURABLE_META.tmp" && mv "$DURABLE_META.tmp" "$DURABLE_META"
run recover durable >/dev/null 2>&1
check "recovery hashes and restores a proven complete artifact" "run status durable | jq -e '.phase==\"completed\" and .artifact_kind==\"complete\" and (.artifact_sha256|length)==64'"
ALT="$TMP/alternate-checkout"; mkdir -p "$ALT"; git -C "$ALT" init -q; git -C "$ALT" remote add origin https://example.invalid/test/repo.git
check "job remains retrievable from another clone of the same remote" "cd '$ALT' && bash '$SCRIPT' result durable | grep -q APPROVE"
check "fallback retrieval never crosses caller identities" "cd '$ALT' && AI_KIMI_CALLER=codex bash '$SCRIPT' result durable >/dev/null 2>&1; test \$? -ne 0"
UNSAFE_DIR="$(dirname "$(dirname "$DURABLE_META")")/claude--recover-unsafe"; mkdir -p "$UNSAFE_DIR"; cp "$(jq -r .artifact_paths.stream "$DURABLE_META")" "$UNSAFE_DIR/stream.jsonl"; : > "$UNSAFE_DIR/stream.jsonl.err"
# Derive the fixture from the wrapper-owned metadata path and keep that exact
# spelling. On hosted Windows, `pwd -P` physically expands Git Bash's /tmp mount
# from RUNNER~1 to runneradmin while the wrapper-owned path correctly retains
# /tmp. Mixing those aliases manufactures an unsafe destination the wrapper
# would never create and tests path spelling instead of the recovery invariant.
jq --arg stream "$UNSAFE_DIR/stream.jsonl" --arg log "$UNSAFE_DIR/worker.log" --arg canonical "$UNSAFE_DIR/review-recovery.md" '.name="recover-unsafe"|.job_id="recover-unsafe"|.phase="failed"|.terminal_reason="readonly-tree-changed"|.artifact_kind=null|.artifact_sha256=null|.artifact_paths.stream=$stream|.artifact_paths.log=$log|.artifact_paths.canonical=$canonical|.artifact_paths.repository=null' "$DURABLE_META" > "$UNSAFE_DIR/job.json"
cp "$CANONICAL" "$UNSAFE_DIR/review-recovery.md"
run recover recover-unsafe >/dev/null 2>&1 || true
check "recovery cannot approve a worker-classified safety failure" "run status recover-unsafe | jq -e '.phase==\"recovery-required\" and .artifact_kind==\"incomplete\" and .terminal_reason!=\"session.resume_hint\"'"
echo usagepartial > "$TMP/mode"
run start quota-review --prompt review >/dev/null
run wait quota-review >/dev/null 2>&1 || true
check "durable review classifies quota separately from authentication" "run status quota-review | jq -e '.phase == \"failed\" and .terminal_reason == \"usage-limit\"'"
check "quota failure preserves an incomplete no-verdict artifact" "p=\$(run status quota-review | jq -r .artifact_paths.canonical); test -f \"\$p\" && grep -q 'INCOMPLETE.*NO VERDICT' \"\$p\" && grep -q 'Usage limit reached' \"\$p\""
echo ok > "$TMP/mode"
echo slow > "$TMP/mode"
AI_KIMI_WAIT_TIMEOUT=2 run start durable-timeout --prompt review >/dev/null
AI_KIMI_WAIT_TIMEOUT=10 run wait durable-timeout >/dev/null 2>&1 || true
check "durable wall deadline records timed-out" "run status durable-timeout | jq -e '.phase == \"timed-out\" and .terminal_reason == \"timed-out\"'"
AI_KIMI_WAIT_TIMEOUT=30 run start durable-cancel --prompt review >/dev/null
sleep 1
CANCEL_OUT="$(run cancel durable-cancel 2>&1)"; CANCEL_RC=$?
if run status durable-cancel | jq -e '.phase == "cancelled" and .terminal_reason == "cancelled-by-user"' >/dev/null; then
  ok "durable cancel is worker-confirmed"
else
  bad "durable cancel is worker-confirmed"; printf '  diagnostic: rc=%s %s\n' "$CANCEL_RC" "$CANCEL_OUT"
fi
CANCEL_SIDECAR="$(find "$AI_KIMI_STATE_DIR/jobs" -path '*claude--durable-cancel/cancel.request' -print -quit)"
check "durable cancel keeps an atomic sidecar signal" "test -n '$CANCEL_SIDECAR' && test -f '$CANCEL_SIDECAR'"
OUT="$(AI_KIMI_TEST_FAIL_WORKER_START=1 run start worker-start-failure --prompt review 2>&1)"; RC=$?
[ $RC -ne 0 ] && ok "detached launch failure refuses immediately" || bad "detached launch failure refuses immediately"
check "detached launch failure is durable and typed" "run status worker-start-failure | jq -e '.phase == \"failed\" and .terminal_reason == \"worker-start-failed\"'"
echo directoryerror > "$TMP/mode"
run start directory-mismatch --prompt review >/dev/null
run wait directory-mismatch >/dev/null 2>&1 || true
check "directory binding failure is typed" "run status directory-mismatch | jq -e '.terminal_reason == \"directory-mismatch\"'"
echo ok > "$TMP/mode"
OUT="$(cd "$REPO" && KIMI_CODE_HOME="$TMP/does-not-exist/no-parent" bash "$SCRIPT" start denied --prompt x --json 2>&1)"; RC=$?
[ $RC -ne 0 ] && ok "unwritable Kimi home refuses before launch" || bad "unwritable Kimi home refuses before launch"
check "denial gives the main-task hand-back" "printf '%s' \"\$OUT\" | grep -q 'Full Access main task'"

HEAD_SHA="$(git -C "$REPO" rev-parse HEAD)"
run new r-evidence --prompt "review" --base HEAD --tests true \
  --decision "is this safe?" --assert-head "$HEAD_SHA" >/dev/null 2>&1
[ $? -eq 0 ] && ok "review accepts sealed evidence options" || bad "review accepts sealed evidence options"
EVIDENCE_WORKSPACE="$(tail -1 "$TMP/pwd.txt")"
run ask r-evidence --prompt "recheck" >/dev/null 2>&1
RESUMED_WORKSPACE="$(tail -1 "$TMP/pwd.txt" 2>/dev/null || true)"
check "named review resumes in its original directory" "test '$RESUMED_WORKSPACE' = '$EVIDENCE_WORKSPACE'"
ARGV_LINES_BEFORE="$(wc -l < "$TMP/argv.txt")"
run new architecture-kind --review-kind architecture --decision "choose the operating model" --prompt "Read plan.md and decide." >/dev/null 2>&1
ARCH_ARGV="$(tail -n +$((ARGV_LINES_BEFORE + 1)) "$TMP/argv.txt")"
check "architecture review uses a decision contract" "printf '%s' \"\$ARCH_ARGV\" | grep -q 'not a code-diff approval' && printf '%s' \"\$ARCH_ARGV\" | grep -q 'unresolved-objection ledger'"
check "architecture review does not receive the diff preamble" "! printf '%s' \"\$ARCH_ARGV\" | grep -q 'exact commits under review'"
ARGV_LINES_BEFORE="$(wc -l < "$TMP/argv.txt")"
run ask architecture-kind --prompt "Re-read the plan." >/dev/null 2>&1
ARCH_RESUME_ARGV="$(tail -n +$((ARGV_LINES_BEFORE + 1)) "$TMP/argv.txt")"
check "architecture continuation preserves its decision contract" "printf '%s' \"\$ARCH_RESUME_ARGV\" | grep -q 'not a code-diff approval' && ! printf '%s' \"\$ARCH_RESUME_ARGV\" | grep -q 'exact commits under review'"
OUT="$(run new broad-test-warning --tests 'echo test-ai-kimi' --prompt review 2>&1)"
check "broad pre-provider test command warns visibly" "printf '%s' \"\$OUT\" | grep -q 'broad test command will run synchronously before Kimi'"
check "help documents evidence base" "run --help | grep -q -- '--base REF'"

ORIGINAL_STATE_DIR="$AI_KIMI_STATE_DIR"
export AI_KIMI_STATE_DIR="$TMP/state with spaces"
run new spaced-worker --prompt review >/dev/null 2>&1
run wait spaced-worker >/dev/null 2>&1 || true
check "Windows detached worker accepts spaced state paths" "run show spaced-worker | jq -e '.kimi_session_id'"
export AI_KIMI_STATE_DIR="$ORIGINAL_STATE_DIR"

echo "== debate contract and context rules =="
TEMPLATE="$REPO_ROOT/templates/delegation/debate-turn.md"
SKILL="$REPO_ROOT/skills/shared/kimi-code-delegation/SKILL.md"
for heading in "Goal" "Disputed claim" "Other model.s reasoning" \
  "Current plan or diff paths" "New test or runtime evidence" "Constraints" \
  "What changed since the last turn" "Claim-by-claim check" "Material objections" \
  "Required correction" "Consensus question" "Consensus ledger"; do
  check "template has $heading" "grep -q '^## $heading$' '$TEMPLATE'"
done
check "skill requires exact-session ask" "grep -q 'then use.*ask.*every' '$SKILL'"
check "skill has same-session recovery" "grep -q 'stay in the same session' '$SKILL'"
check "skill requires current-artifact re-read" "grep -q 'current-artifact re-read' '$SKILL'"
check "skill forbids numerical metric claims" "grep -q 'Never claim provider-cache savings' '$SKILL'"
check "skill bounds rebuttals" "grep -q 'three rebuttal' '$SKILL'"

echo "== review_refuses_without_agent_file =="
OUT="$( cd "$REPO" && AI_KIMI_RO_AGENT="$TMP/nope.md" bash "$SCRIPT" new r2 --prompt x 2>&1 )"; RC=$?
[ $RC -ne 0 ] && ok "review refuses to run with no read-only profile" || bad "review refuses to run with no read-only profile"
check "and says why" "printf '%s' \"\$OUT\" | grep -qi 'structural read-only'"

echo "== ask_resumes_and_drops_the_agent =="
: > "$TMP/argv.txt"
run ask r1 --prompt "follow up" >/dev/null 2>&1
check "ask resumes with -r"          "grep -q -- '-r session_35e1a0a2' '$TMP/argv.txt'"
# --agent-file cannot be combined with a resume; passing it would hard-error.
check "ask does NOT pass --agent-file" "! grep -q -- '--agent-file' '$TMP/argv.txt'"
CALLS_BEFORE_ORIGIN_CHANGE="$(wc -l < "$TMP/argv.txt")"
git -C "$REPO" remote set-url origin https://example.invalid/other/repo.git
OUT="$(run ask r1 --prompt 'must stay on original upstream' 2>&1)"; RC=$?
[ "$RC" -ne 0 ] && [ "$CALLS_BEFORE_ORIGIN_CHANGE" = "$(wc -l < "$TMP/argv.txt")" ] && ok "origin changes cannot move a persistent review to a different paid lock" || bad "origin changes cannot move a persistent review to a different paid lock"
check "origin mismatch explains safe recovery" "grep -q 'belongs to a different shared upstream.*Restore its original origin' '$SCRIPT'"
git -C "$REPO" remote set-url origin https://example.invalid/test/repo.git

echo "== caller separation =="
( cd "$REPO" && AI_KIMI_CALLER=codex bash "$SCRIPT" new r1 --prompt "codex copy" ) >/dev/null 2>&1
check "Claude record still resolves" "run show r1 | jq -e '.caller == \"claude\"'"
check "Codex record is separate" "(cd '$REPO' && AI_KIMI_CALLER=codex bash '$SCRIPT' show r1) | jq -e '.caller == \"codex\"'"
ARGV_BEFORE="$(wc -l < "$TMP/argv.txt")"
OUT="$(run implement r1 --prompt 'must not cross modes' 2>&1)"; RC=$?
[ $RC -ne 0 ] && ok "review and implementation names cannot collide" || bad "review and implementation names cannot collide"
check "mode collision starts no provider turn" "test \"\$(wc -l < '$TMP/argv.txt')\" -eq '$ARGV_BEFORE' && printf '%s' \"\$OUT\" | grep -q 'review session'"

echo "== same-name implementation concurrency =="
echo slow > "$TMP/mode"; : > "$TMP/argv.txt"
( cd "$REPO" && exec bash "$SCRIPT" implement same-name --prompt wait ) >/dev/null 2>&1 &
SAME_PID=$!
for _ in 1 2 3 4 5; do
  find "$AI_KIMI_STATE_DIR/worktrees" -path '*/same-name/owner.json' -print -quit 2>/dev/null | grep -q . && break
  sleep 1
done
SAME_ARGV="$(wc -l < "$TMP/argv.txt")"
OUT="$(run implement same-name --prompt duplicate 2>&1)"; RC=$?
[ $RC -ne 0 ] && ok "same-name concurrent implementation is refused" || bad "same-name concurrent implementation is refused"
check "concurrent refusal starts no second provider turn" "test \"\$(wc -l < '$TMP/argv.txt')\" -eq '$SAME_ARGV' && printf '%s' \"\$OUT\" | grep -q 'already active'"
kill -TERM "$SAME_PID" 2>/dev/null || true; wait "$SAME_PID" 2>/dev/null || true
check "concurrency test leaves no disposable worktree" "test \"\$(git -C '$REPO' worktree list | wc -l)\" -eq 1"
echo ok > "$TMP/mode"

echo "== legacy implementation sessions are not guessed =="
RID="$(printf '%s' "$(git -C "$REPO" rev-parse --show-toplevel)" | tr '\\' '/' | tr -c 'A-Za-z0-9._-' '-' | sed 's/^-*//;s/-*$//')"
mkdir -p "$AI_KIMI_STATE_DIR/sessions/$RID"
jq -n --arg sid session_implement --arg repo "$REPO" --arg name impl1 \
  --arg caller claude '{kimi_session_id:$sid,repo:$repo,name:$name,caller:$caller,mode:"implement",turns:1}' \
  > "$AI_KIMI_STATE_DIR/sessions/$RID/claude--impl1.json"
OUT="$(run ask impl1 --prompt 'continue writing' 2>&1)"; RC=$?
[ $RC -ne 0 ] && ok "legacy implement resume is refused" || bad "legacy implement resume is refused"
check "refusal gives restart guidance" "printf '%s' \"\$OUT\" | grep -q 'legacy one-shot'"

echo "== committed implementation work is preserved and cleaned =="
echo implcommit > "$TMP/mode"
run implement implcommit --prompt 'make one committed change' >/dev/null 2>&1
PATCH="$(ls "$REPO"/.ai/reviews/kimi-implcommit-*.patch 2>/dev/null | head -1)"
check "committed changes are in patch" "grep -q committed.txt '$PATCH'"
check "committed patch applies to original base" "git -C '$REPO' apply --check '$PATCH'"
check "implementation worktree is removed" "test \"\$(git -C '$REPO' worktree list | wc -l)\" -eq 1"
check "implementation agent profile is used" "grep -q -- 'local-implement.md' '$TMP/argv.txt'"

echo "== persistent implementation resumes exact conversation and code =="
echo persistent > "$TMP/mode"; : > "$TMP/argv.txt"
run implement persistent1 --prompt 'turn one' >/dev/null 2>&1
META="$(find "$AI_KIMI_STATE_DIR/sessions" -path '*/claude--persistent1.d/metadata.json' -print -quit)"
CANON="$(jq -r .canonical_patch "$META")"; BASE="$(jq -r .base_sha "$META")"; HASH1="$(jq -r .patch_sha256 "$META")"
check "persistent metadata is version 2" "jq -e '.version==2 and .generation==1 and .continuity_state==\"exact\"' '$META'"
check "canonical patch has first-turn text and binary" "grep -q first-turn.txt '$CANON' && grep -q 'GIT binary patch' '$CANON'"
POUT="$(run ask persistent1 --prompt 'turn two' 2>&1 >/dev/null)"; PRC=$?
[ $PRC -eq 0 ] || printf '  diagnostic: persistent turn two: %s\n' "$POUT"
check "implementation ask uses exact session id" "grep -q -- '-r session_35e1a0a2' '$TMP/argv.txt'"
check "implementation stub executed the continuation branch" "grep -q continued '$TMP/persistent-calls.txt'"
check "implementation ask warns that it is a write run" "printf '%s' \"\$POUT\" | grep -q 'implementation continuation (write run)'"
check "generation advances after durable continuation" "jq -e '.generation==2 and .turns==2 and .base_sha==\"'$BASE'\"' '$META'"
CANON2="$(jq -r .canonical_patch "$META")"
check "cumulative patch contains both turns" "grep -q first-turn.txt '$CANON2' && grep -q second-turn.txt '$CANON2'"
check "canonical hash matches exact bytes" "test \"\$(sha256sum '$CANON2' | awk '{print \$1}')\" = \"\$(jq -r .patch_sha256 '$META')\""
check "canonical hash changed after continuation" "test '$HASH1' != \"\$(jq -r .patch_sha256 '$META')\""
check "real repository remains unchanged" "test ! -e '$REPO/first-turn.txt' && test ! -e '$REPO/second-turn.txt'"
check "every persistent turn removes disposable worktree" "test \"\$(git -C '$REPO' worktree list | wc -l)\" -eq 1"
check "implement existing name shares continuation path" "run implement persistent1 --prompt 'turn three' >/dev/null 2>&1 && jq -e '.generation==3' '$META'"
HASH3="$(jq -r .patch_sha256 "$META")"
OUT="$(AI_KIMI_TEST_FAIL_STATE=after-patch run ask persistent1 --prompt 'state save failure' 2>&1)"; RC=$?
[ $RC -ne 0 ] && ok "state persistence failure remains unsuccessful" || bad "state persistence failure remains unsuccessful"
check "state failure keeps prior canonical patch" "test \"\$(jq -r .patch_sha256 '$META')\" = '$HASH3' && test -f \"\$(jq -r .canonical_patch '$META')\""
check "state failure marks recovery required" "jq -e '.continuity_state==\"recovery-required\" and .last_terminal_state==\"state-save-failed\"' '$META'"
check "state failure cleans disposable worktree after durable human patch" "test \"\$(git -C '$REPO' worktree list | wc -l)\" -eq 1"
OUT="$(run ask persistent1 --prompt blocked 2>&1)"; RC=$?
[ $RC -ne 0 ] && ok "recovery-required blocks exact resume" || bad "recovery-required blocks exact resume"
check "blocked resume gives explicit reset command" "printf '%s' \"\$OUT\" | grep -q 'reset-context persistent1'"
run reset-context persistent1 --prompt 'visible context reset' >/dev/null 2>&1
check "explicit reset starts a proven new conversation generation" "jq -e '.generation==4 and .continuity_state==\"exact\"' '$META'"
MOVED="$TMP/repo-moved"; mv "$REPO" "$MOVED"
OUT="$(cd "$MOVED" && bash "$SCRIPT" ask persistent1 --prompt 'continue after repository move' 2>&1 >/dev/null)"; RC=$?
[ $RC -eq 0 ] && ok "moved checkout persistent ask succeeds" || { bad "moved checkout persistent ask succeeds"; printf '  diagnostic: %s\n' "$OUT"; }
check "moved checkout keeps original session state directory" "test -f '$META' && jq -e '.generation==5' '$META'"
check "list discovers a persistent session after checkout move" "(cd '$MOVED' && bash '$SCRIPT' list) | grep -q persistent1"
mv "$MOVED" "$REPO"
OUT="$(run implement persistent1 --prompt 'continue by implement after moving back' 2>&1 >/dev/null)"; RC=$?
[ $RC -eq 0 ] && ok "implement finds moved persistent session instead of duplicating it" || bad "implement finds moved persistent session instead of duplicating it"
check "implement after move advances the original record" "jq -e '.generation==6' '$META' && test \"\$(find '$AI_KIMI_STATE_DIR/sessions' -path '*/claude--persistent1.d/metadata.json' | wc -l)\" -eq 1"
for TURN in 7 8 9 10; do
  run ask persistent1 --prompt "long conversation turn $TURN" >/dev/null 2>&1 || bad "persistent conversation reaches turn $TURN"
done
check "ten-turn conversation keeps exact identity and one state record" "jq -e '.generation==10 and .turns==10 and .kimi_session_id==\"session_35e1a0a2-139f-4095-afdd-fce90a32ed2d\"' '$META' && test \"\$(find '$AI_KIMI_STATE_DIR/sessions' -path '*/claude--persistent1.d/metadata.json' | wc -l)\" -eq 1"
check "ten-turn conversation leaves one registered worktree" "test \"\$(git -C '$REPO' worktree list | wc -l)\" -eq 1"
echo continuationpartial > "$TMP/mode"
OUT="$(AI_KIMI_WAIT_TIMEOUT=2 run ask persistent1 --prompt 'fail after prior proven work' 2>&1)"; RC=$?
[ $RC -ne 0 ] && ok "failed continuation remains unsuccessful" || bad "failed continuation remains unsuccessful"
TURN_PATCH="$(ls -t "$REPO"/.ai/reviews/kimi-persistent1-*.turn.incomplete.patch 2>/dev/null | head -1)"
CUM_PATCH="$(ls -t "$REPO"/.ai/reviews/kimi-persistent1-*.incomplete.patch 2>/dev/null | grep -v '\.turn\.' | head -1)"
TURN_REPORT="$(ls -t "$REPO"/.ai/reviews/kimi-persistent1-*.incomplete.md 2>/dev/null | head -1)"
check "failed continuation exports cumulative recovery and turn-only patches" "test -s '$CUM_PATCH' && test -s '$TURN_PATCH' && grep -q first-turn.txt '$CUM_PATCH' && grep -q failed-turn-only.txt '$TURN_PATCH' && ! grep -q first-turn.txt '$TURN_PATCH'"
check "failed continuation report describes only this turn" "grep -q failed-turn-only.txt '$TURN_REPORT' && ! grep -q first-turn.txt '$TURN_REPORT' && grep -q 'This turn only' '$TURN_REPORT'"
echo persistent > "$TMP/mode"
HUMAN_BEFORE="$(find "$REPO/.ai/reviews" -name 'kimi-persistent1-*' | wc -l)"
jq '.patch_sha256="deliberately-corrupt"' "$META" > "$META.tmp"; mv "$META.tmp" "$META"
run delete persistent1 >/dev/null 2>&1
check "delete cleans hash-mismatched state but keeps human artifacts" "test ! -e '$META' && test \"\$(find '$REPO/.ai/reviews' -name 'kimi-persistent1-*' | wc -l)\" -eq '$HUMAN_BEFORE'"
echo slow > "$TMP/mode"
( cd "$REPO" && exec bash "$SCRIPT" implement implinterrupt --prompt wait ) >/dev/null 2>&1 &
INT_PID=$!
for _ in 1 2 3 4 5; do
  find "$AI_KIMI_STATE_DIR/worktrees" -name owner.json -print -quit 2>/dev/null | grep -q . && break
  sleep 1
done
kill -TERM "$INT_PID" 2>/dev/null || true
wait "$INT_PID" 2>/dev/null || true
check "implement interrupt removes worktree" "test \"\$(git -C '$REPO' worktree list | wc -l)\" -eq 1"
check "implement interrupt removes owner record" "! find '$AI_KIMI_STATE_DIR/worktrees' -name owner.json -print -quit 2>/dev/null | grep -q ."
echo ok > "$TMP/mode"

echo "== incomplete implementation recovery =="
echo usagepartial > "$TMP/mode"
OUT="$(AI_KIMI_WAIT_TIMEOUT=2 run implement usagepartial --prompt 'private prompt marker DO-NOT-LEAK-731' 2>&1)"; RC=$?
[ $RC -ne 0 ] && ok "usage limit with changes returns nonzero" || bad "usage limit with changes returns nonzero"
IPATCH="$(ls "$REPO"/.ai/reviews/kimi-usagepartial-*.incomplete.patch 2>/dev/null | head -1)"
IREPORT="$(ls "$REPO"/.ai/reviews/kimi-usagepartial-*.incomplete.md 2>/dev/null | head -1)"
check "usage limit exports incomplete patch" "test -s '$IPATCH'"
check "usage limit exports incomplete report" "test -s '$IREPORT'"
check "incomplete patch is binary" "grep -q 'GIT binary patch' '$IPATCH'"
check "incomplete patch applies to original base" "git -C '$REPO' apply --check '$IPATCH'"
check "usage state is truthful" "grep -q 'Terminal state: .*usage-limit' '$IREPORT' && printf '%s' \"\$OUT\" | grep -q 'usage-limit with partial changes'"
check "report marks work incomplete" "grep -q 'INCOMPLETE' '$IREPORT' && grep -q 'Tests: not confirmed complete' '$IREPORT'"
check "report records base and requested-model warning" "grep -q 'Base SHA:' '$IREPORT' && grep -q 'returned model: unavailable' '$IREPORT'"
check "report uses unavailable for missing session and usage" "grep -q 'Kimi session ID: .*unavailable' '$IREPORT' && grep -q 'Usage, tokens, cache, cost, and context: .*unavailable' '$IREPORT'"
check "report gives manual apply checks" "grep -q 'git apply --stat' '$IREPORT' && grep -q 'git apply --check' '$IREPORT' && grep -q 'Never apply' '$IREPORT'"
check "report is bounded and excludes prompt" "test \"\$(wc -c < '$IREPORT')\" -lt 10000 && ! grep -q 'DO-NOT-LEAK-731' '$IREPORT'"
check "failed run never writes the real repository" "test ! -e '$REPO/partial.txt' && test ! -e '$REPO/partial.bin'"
check "incomplete export cleans worktree" "test \"\$(git -C '$REPO' worktree list | wc -l)\" -eq 1"
check "incomplete export cleans owner record" "! find '$AI_KIMI_STATE_DIR/worktrees' -name owner.json -print -quit 2>/dev/null | grep -q ."

echo networkpartial > "$TMP/mode"
OUT="$(AI_KIMI_WAIT_TIMEOUT=2 run implement networkpartial --prompt x 2>&1)"; RC=$?
NPATCH="$(ls "$REPO"/.ai/reviews/kimi-networkpartial-*.incomplete.patch 2>/dev/null | head -1)"
NREPORT="$(ls "$REPO"/.ai/reviews/kimi-networkpartial-*.incomplete.md 2>/dev/null | head -1)"
[ $RC -ne 0 ] && ok "network failure with changes returns nonzero" || bad "network failure with changes returns nonzero"
check "network failure exports generic incomplete patch" "test -s '$NPATCH' && grep -q 'Terminal state: .*failed' '$NREPORT'"
check "generic report excludes raw provider text" "! grep -q 'provider connection interrupted' '$NREPORT'"

echo failednochange > "$TMP/mode"
BEFORE_PATCHES="$(find "$REPO/.ai/reviews" -name '*.incomplete.patch' | wc -l)"
OUT="$(AI_KIMI_WAIT_TIMEOUT=2 run implement failednochange --prompt x 2>&1)"; RC=$?
AFTER_PATCHES="$(find "$REPO/.ai/reviews" -name '*.incomplete.patch' | wc -l)"
[ $RC -ne 0 ] && ok "failure before changes returns nonzero" || bad "failure before changes returns nonzero"
[ "$BEFORE_PATCHES" = "$AFTER_PATCHES" ] && ok "failure before changes creates no empty patch" || bad "failure before changes creates no empty patch"
check "failure before changes is named" "printf '%s' \"\$OUT\" | grep -q 'failed before changes'"

echo timeoutpartial > "$TMP/mode"
OUT="$(AI_KIMI_WAIT_TIMEOUT=2 run implement timeoutpartial --prompt x 2>&1)"; RC=$?
TPATCH="$(ls "$REPO"/.ai/reviews/kimi-timeoutpartial-*.incomplete.patch 2>/dev/null | head -1)"
TREPORT="$(ls "$REPO"/.ai/reviews/kimi-timeoutpartial-*.incomplete.md 2>/dev/null | head -1)"
[ $RC -ne 0 ] && ok "timeout with changes returns nonzero" || bad "timeout with changes returns nonzero"
check "timeout exports incomplete patch" "test -s '$TPATCH' && grep -q 'Terminal state: .*timed-out' '$TREPORT'"

echo interruptpartial > "$TMP/mode"
( cd "$REPO" && exec bash "$SCRIPT" implement interruptpartial --prompt wait ) >/dev/null 2>&1 &
INT_PID=$!
for _ in 1 2 3 4 5; do
  OWNER="$(find "$AI_KIMI_STATE_DIR/worktrees" -name owner.json -print -quit 2>/dev/null)"
  [ -n "$OWNER" ] && [ -f "$(jq -r .worktree "$OWNER")/interrupt-partial.txt" ] && break
  sleep 1
done
kill -TERM "$INT_PID" 2>/dev/null || true
wait "$INT_PID" 2>/dev/null || true
CPATCH="$(ls "$REPO"/.ai/reviews/kimi-interruptpartial-*.incomplete.patch 2>/dev/null | head -1)"
CREPORT="$(ls "$REPO"/.ai/reviews/kimi-interruptpartial-*.incomplete.md 2>/dev/null | head -1)"
check "interrupt with changes exports incomplete patch" "test -s '$CPATCH' && grep -q 'Terminal state: .*cancelled' '$CREPORT'"
check "interrupt with changes cleans worktree" "test \"\$(git -C '$REPO' worktree list | wc -l)\" -eq 1"

echo "== incomplete artifact failure safety =="
for failure in destination move; do
  echo usagepartial > "$TMP/mode"
  OUT="$(AI_KIMI_WAIT_TIMEOUT=2 AI_KIMI_TEST_FAIL_EXPORT="$failure" run implement "exportfail-$failure" --prompt x 2>&1)"; RC=$?
  [ $RC -ne 0 ] && ok "$failure export failure returns nonzero" || bad "$failure export failure returns nonzero"
  OWNER="$(find "$AI_KIMI_STATE_DIR/worktrees" -name owner.json -print -quit 2>/dev/null)"
  WT="$(jq -r .worktree "$OWNER" 2>/dev/null)"
  check "$failure export failure preserves exact worktree" "test -d '$WT' && test \"\$(jq -r .state '$OWNER')\" = preserved-recovery"
  check "$failure export failure reports exact path" "printf '%s' \"\$OUT\" | grep -Fq \"\$WT\""
  DOUT="$(run doctor 2>&1 || true)"
  check "doctor names preserved $failure recovery" "printf '%s' \"\$DOUT\" | grep -Fq \"\$WT\" && test -d '$WT'"
  git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1 || true
  rm -rf "${WT%/wt}"
done

echo "== finalizer and owner-record hardening =="
FORGED="$AI_KIMI_STATE_DIR/worktrees/forged/wt"; mkdir -p "$FORGED"
FORGED_OWNER="${FORGED%/wt}/owner.json"
jq -n --arg repo "$REPO" --arg wt "$FORGED" '{version:1,repo:$repo,worktree:$wt,pid:"0",state:"active"}' > "$FORGED_OWNER"
sed '/^CMD=/,$d' "$SCRIPT" > "$TMP/lib-finalizer.sh"
( set +e; . "$TMP/lib-finalizer.sh"; cleanup_wt "$REPO" "$FORGED" "$FORGED_OWNER" ) >/dev/null 2>&1
check "forged owner path is never deleted" "test -d '$FORGED' && test -f '$FORGED_OWNER'"
rm -rf "${FORGED%/wt}"
PATCH_COUNT="$(find "$REPO/.ai/reviews" -name 'kimi-implcommit-*.patch' | wc -l)"
check "repeated finalizer is idempotent" "test '$PATCH_COUNT' -eq 1"
echo ok > "$TMP/mode"

echo "== no_flag_passthrough =="
run new r3 --prompt x --yolo >/dev/null 2>&1
[ $? -ne 0 ] && ok "--yolo is rejected" || bad "--yolo is rejected"
run new r3 --prompt x --auto >/dev/null 2>&1
[ $? -ne 0 ] && ok "--auto is rejected" || bad "--auto is rejected"

echo "== await_requires_resume_hint (the regression test) =="
AW="$TMP/await.jsonl"; : > "$AW"
( sleep 2; printf '{"role":"assistant","content":"still working"}\n' > "$AW"
  sleep 2; cat "$TMP/fixture.jsonl" > "$AW" ) &
BG=$!
sed '/^CMD=/,$d' "$SCRIPT" > "$TMP/lib.sh"
START=$(date +%s)
( set +e; . "$TMP/lib.sh"; await_result "$AW" test ) >/dev/null 2>&1
RC=$?; ELAPSED=$(( $(date +%s) - START )); wait $BG 2>/dev/null
[ $RC -eq 0 ] && ok "await succeeds once the resume hint arrives" || bad "await succeeds once the resume hint arrives"
[ $ELAPSED -ge 3 ] && ok "await blocked through an answer with no terminal record (${ELAPSED}s)" \
  || bad "await returned too early (${ELAPSED}s)"

echo "== a run that never completes is a failure =="
echo nohint > "$TMP/mode"
OUT="$(run new r4 --prompt x 2>&1)"; RC=$?
[ $RC -ne 0 ] && ok "no resume hint exits non-zero" || bad "no resume hint exits non-zero"
check "message names the terminal record" "printf '%s' \"\$OUT\" | grep -q 'session.resume_hint'"
echo empty > "$TMP/mode"
run new r5 --prompt x >/dev/null 2>&1
[ $? -ne 0 ] && ok "empty output exits non-zero" || bad "empty output exits non-zero"
echo ok > "$TMP/mode"

echo "== a review that mutates the tree is caught (defence in depth) =="
echo writes > "$TMP/mode"
OUT="$(run new r6 --prompt x 2>&1)"; RC=$?
git -C "$REPO" checkout -- a.txt 2>/dev/null || true
[ $RC -ne 0 ] && ok "a read-only review that wrote is a hard failure" || bad "a read-only review that wrote is a hard failure"
check "message says the restriction is not holding" "printf '%s' \"\$OUT\" | grep -qi 'not holding'"
echo ok > "$TMP/mode"

echo "== output handling =="
OUT="$(run new r7 --prompt x 2>/dev/null)"
check "verdict is emitted"        "printf '%s' \"\$OUT\" | grep -q APPROVE"
# CONTRACT CHANGE, shared-db issue #1220. This used to assert the opposite --
# that everything above '## Verdict' was stripped. On PR #1176 that stripping
# reduced a full review (five findings plus a hand-traced coverage statement) to
# a bare two-line APPROVE, because the model had put its findings ABOVE the
# heading, exactly where the prompt footer asks for "narration". Nothing in the
# text distinguishes narration from findings, so a stripper cannot keep one and
# drop the other -- and the failure is biased toward "looks approved" on what
# this repository uses as a MERGE GATE. The body is now always emitted; a caller
# that wants only the verdict can read from the '## Verdict' heading itself.
check "the body above the verdict is NOT discarded" \
  "printf '%s' \"\$OUT\" | grep -q \"I'll read the files\""
ERR="$(run ask r7 --prompt x 2>&1 >/dev/null)"
check "no token/cost is claimed"  "printf '%s' \"\$ERR\" | grep -qi 'reports no token'"

echo "== #1220: silence must never read as APPROVE =="
# Exercised directly against extract_answer: these are pure-text defects, so
# driving a whole run would add stub plumbing between the input and the assertion
# without testing anything more.
sed -n '/^extract_answer() {/,/^}/p' "$SCRIPT" > "$TMP/extract.sh"
probe(){ bash -c '. "$1"; ANSWER_DEFECT=""; extract_answer "$2" >/dev/null; printf "%s" "$ANSWER_DEFECT"' _ "$TMP/extract.sh" "$1"; }

# Assistant text but no '## Verdict' heading: the observed "ended mid-run" case --
# 637 seconds of provider time, one message saying it was about to start, no
# findings, exit 0.
cat > "$TMP/noverdict.jsonl" <<'NOVERDICT'
{"role":"assistant","content":"I've read all four patch parts in full. Let me verify a couple of environmental facts before finalizing findings."}
NOVERDICT
NOV="$(probe "$TMP/noverdict.jsonl")"
check "a stream with no verdict is reported as a defect" "printf '%s' \"\$NOV\" | grep -q Verdict"

: > "$TMP/silent.jsonl"
SIL="$(probe "$TMP/silent.jsonl")"
check "a stream with no answer at all is reported as a defect" "printf '%s' \"\$SIL\" | grep -q 'no answer text'"

# The healthy case must NOT be flagged, or the guard is noise that gets muted.
printf '%s\n' '{"role":"assistant","content":"finding one\n## Verdict\nAPPROVE"}' > "$TMP/good.jsonl"
GOOD="$(probe "$TMP/good.jsonl")"
check "a complete review is NOT flagged as a defect" "[ -z \"\$GOOD\" ]"

# And the body above the verdict survives -- the defect that turned a five-finding
# review into a bare two-line APPROVE on PR #1176.
BODY="$(bash -c '. "$1"; extract_answer "$2"' _ "$TMP/extract.sh" "$TMP/good.jsonl")"
check "the text above the verdict is still emitted" "printf '%s' \"\$BODY\" | grep -q 'finding one'"


echo "== duplicate run refused (per-repo lock) =="
UPSTREAM_ID='example.invalid/test/repo'
LOCK_ID="$(printf '%s' "$UPSTREAM_ID" | sha256sum | cut -c1-16)"
LOCK="$AI_KIMI_STATE_DIR/locks/repo--$LOCK_ID.lock.d"
mkdir -p "$LOCK"; echo $$ > "$LOCK/pid"; echo "new:other" > "$LOCK/label"
OUT="$(run new r8 --prompt x 2>&1)"; RC=$?; rm -rf "$LOCK"
[ $RC -ne 0 ] && ok "a second concurrent run is refused" || bad "a second concurrent run is refused"
check "refusal names the active run" "printf '%s' \"\$OUT\" | grep -q 'already active'"
CLONE="$TMP/equivalent-clone"; mkdir -p "$CLONE"; git -C "$CLONE" init -q; git -C "$CLONE" config user.name T; git -C "$CLONE" config user.email t@example.com
git -C "$CLONE" remote add origin git@example.invalid:test/repo.git; printf 'x\n' > "$CLONE/a"; git -C "$CLONE" add a; git -C "$CLONE" commit -qm init
mkdir -p "$LOCK"; echo $$ > "$LOCK/pid"; echo "review:other-clone" > "$LOCK/label"
OUT="$(cd "$CLONE" && bash "$SCRIPT" new clone-lock --prompt x 2>&1)"; RC=$?; rm -rf "$LOCK"
[ $RC -ne 0 ] && ok "equivalent HTTPS and SSH remotes share one paid-review lock" || bad "equivalent HTTPS and SSH remotes share one paid-review lock"
CASE_CLONE="$TMP/case-suffix-clone"; mkdir -p "$CASE_CLONE"; git -C "$CASE_CLONE" init -q; git -C "$CASE_CLONE" config user.name T; git -C "$CASE_CLONE" config user.email t@example.com; git -C "$CASE_CLONE" remote add origin https://EXAMPLE.INVALID/test/repo.GIT; printf x > "$CASE_CLONE/a"; git -C "$CASE_CLONE" add a; git -C "$CASE_CLONE" commit -qm init
mkdir -p "$LOCK"; echo $$ > "$LOCK/pid"; echo "review:case-suffix" > "$LOCK/label"; OUT="$(cd "$CASE_CLONE" && bash "$SCRIPT" new case-suffix --prompt x 2>&1)"; RC=$?; rm -rf "$LOCK"
[ "$RC" -ne 0 ] && ok "remote .git suffix normalization is case-insensitive" || bad "remote .git suffix normalization is case-insensitive"
USER_CLONE="$TMP/arbitrary-ssh-user"; mkdir -p "$USER_CLONE"; git -C "$USER_CLONE" init -q; git -C "$USER_CLONE" config user.name T; git -C "$USER_CLONE" config user.email t@example.com; git -C "$USER_CLONE" remote add origin deploy@example.invalid:test/repo.git; printf x > "$USER_CLONE/a"; git -C "$USER_CLONE" add a; git -C "$USER_CLONE" commit -qm init
mkdir -p "$LOCK"; echo $$ > "$LOCK/pid"; echo "review:ssh-user" > "$LOCK/label"; OUT="$(cd "$USER_CLONE" && bash "$SCRIPT" new ssh-user --prompt x 2>&1)"; RC=$?; rm -rf "$LOCK"
[ "$RC" -ne 0 ] && ok "SCP-style remotes accept arbitrary valid SSH usernames" || bad "SCP-style remotes accept arbitrary valid SSH usernames"
AUTH_CLONE="$TMP/authenticated-https"; mkdir -p "$AUTH_CLONE"; git -C "$AUTH_CLONE" init -q; git -C "$AUTH_CLONE" config user.name T; git -C "$AUTH_CLONE" config user.email t@example.com; git -C "$AUTH_CLONE" remote add origin https://user@example.invalid/test/repo.git; printf x > "$AUTH_CLONE/a"; git -C "$AUTH_CLONE" add a; git -C "$AUTH_CLONE" commit -qm init
mkdir -p "$LOCK"; echo $$ > "$LOCK/pid"; echo "review:authenticated-https" > "$LOCK/label"; OUT="$(cd "$AUTH_CLONE" && bash "$SCRIPT" new authenticated-https --prompt x 2>&1)"; RC=$?; rm -rf "$LOCK"
[ "$RC" -ne 0 ] && ok "authenticated HTTPS remotes share the canonical paid-review lock" || bad "authenticated HTTPS remotes share the canonical paid-review lock"
CALLS_BEFORE_PATH_CASE="$(wc -l < "$TMP/argv.txt")"; git -C "$REPO" remote set-url origin https://example.invalid/TEST/REPO.git
OUT="$(run ask r1 --prompt 'path case must remain distinct' 2>&1)"; RC=$?
[ "$RC" -ne 0 ] && [ "$CALLS_BEFORE_PATH_CASE" = "$(wc -l < "$TMP/argv.txt")" ] && ok "case-distinct repository paths cannot share a persistent review" || bad "case-distinct repository paths cannot share a persistent review"
git -C "$REPO" remote set-url origin https://example.invalid/test/repo.git
CHAIN="$TMP/origin-chain"; UP="$CHAIN/upstream"; MID="$CHAIN/nested/middle"; DOWN="$CHAIN/downstream"; mkdir -p "$UP" "$MID" "$DOWN"
for d in "$UP" "$MID" "$DOWN"; do git -C "$d" init -q; git -C "$d" config user.name T; git -C "$d" config user.email t@example.com; printf x > "$d/file"; git -C "$d" add file; git -C "$d" commit -qm init; done
git -C "$UP" remote add origin https://example.invalid/chained/upstream.git
git -C "$MID" remote add origin ../../upstream
git -C "$DOWN" remote add origin ../nested/middle
OUT="$(cd "$DOWN" && bash "$SCRIPT" new relative-origin --prompt x 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "chained relative local origins resolve from each owning repository" || { printf '  diagnostic: %s\n' "$OUT"; bad "chained relative local origins resolve from each owning repository"; }
for cmd in status logs result wait; do
  OUT="$(run "$cmd" definitely-missing 2>&1)"; RC=$?
  [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q "no durable job 'definitely-missing' for caller 'claude'" \
    && ok "$cmd gives one friendly missing-job error" || bad "$cmd gives one friendly missing-job error"
  printf '%s' "$OUT" | grep -Eqi 'jq:|Could not open file|No such file' && bad "$cmd hides raw parser/file errors" || ok "$cmd hides raw parser/file errors"
done

echo "== bookkeeping and doctor =="
check "list shows the session"   "run list | grep -q r1"
check "list shows the mode"      "run list | grep -q review"
check "show emits json"          "run show r1 | jq -e .kimi_session_id"
R1_SNAPSHOT="$(run show r1 | jq -r .review_workspace)"
check "delete removes it"        "run delete r1 && ! run show r1"
check "delete removes the matching private snapshot" "test ! -e '$R1_SNAPSHOT'"
check "doctor resolves binary"   "run doctor | grep -q 'kimi binary'"
check "doctor shows the profile" "run doctor | grep -q 'read-only'"
check "doctor reports auth"      "run doctor | grep -q 'auth *: OK'"
check "review file was written"  "ls '$REPO'/.ai/reviews/kimi-r7-*.md"
OUT="$(run transcript r7 2>&1)"
check "transcript writes a named archive" "printf '%s' \"\$OUT\" | grep -q 'transcript archive written'"
check "transcript archive exists" "ls '$REPO'/.ai/reviews/kimi-r7-*.zip"
check "transcript archive is not binary stdout" "! printf '%s' \"\$OUT\" | grep -q 'zip-fixture'"

# --- live ---------------------------------------------------------------------
if [ "${AI_KIMI_LIVE:-0}" = 1 ]; then
  unset AI_KIMI_BIN
  unset KIMI_CODE_HOME
  export AI_KIMI_WAIT_TIMEOUT=300
  L="$TMP/live"; mkdir -p "$L"; git -C "$L" init -q
  git -C "$L" config user.email t@e.com; git -C "$L" config user.name T
  printf '.ai/\n' > "$L/.gitignore"; echo canary > "$L/canary.txt"
  git -C "$L" add -A; git -C "$L" commit -qm i

  echo "== live: bounded incomplete cancellation recovery =="
  LIVE_LOG="$TMP/live-cancel.log"
  ( cd "$L" && exec bash "$SCRIPT" implement livecancel \
      --prompt 'Create live-incomplete-canary.txt containing LIVE-INCOMPLETE-CANARY. Then use Bash to run sleep 120. Do not finish before that sleep.' \
    ) >"$LIVE_LOG" 2>&1 &
  LIVE_PID=$!; LIVE_EDIT=""; LIVE_WT=""
  for _ in $(seq 1 60); do
    LIVE_OWNER="$(find "$AI_KIMI_STATE_DIR/worktrees" -name owner.json -print -quit 2>/dev/null)"
    if [ -n "$LIVE_OWNER" ]; then
      LIVE_WT="$(jq -r '.worktree // ""' "$LIVE_OWNER" 2>/dev/null)"
      [ -f "$LIVE_WT/live-incomplete-canary.txt" ] && { LIVE_EDIT=1; break; }
    fi
    kill -0 "$LIVE_PID" 2>/dev/null || break
    sleep 1
  done
  kill -TERM "$LIVE_PID" 2>/dev/null || true
  wait "$LIVE_PID"; LIVE_RC=$?
  [ "$LIVE_RC" -ne 0 ] && ok "live: cancelled implementation returned nonzero" \
    || bad "live: cancelled implementation returned nonzero"
  [ -n "$LIVE_EDIT" ] && ok "live: Kimi changed only the disposable worktree before cancellation" \
    || bad "live: Kimi did not create the bounded cancellation canary"
  LIVE_PATCH="$(ls "$L"/.ai/reviews/kimi-livecancel-*.incomplete.patch 2>/dev/null | head -1)"
  LIVE_REPORT="$(ls "$L"/.ai/reviews/kimi-livecancel-*.incomplete.md 2>/dev/null | head -1)"
  check "live: cancelled work survived as incomplete patch" "test -s '$LIVE_PATCH' && grep -q 'Terminal state: .*cancelled' '$LIVE_REPORT'"
  check "live: incomplete patch verifies against captured base" "git -C '$L' apply --check '$LIVE_PATCH'"
  check "live: real repository stayed unchanged" "test ! -e '$L/live-incomplete-canary.txt'"
  check "live: disposable worktree was removed" "test \"\$(git -C '$L' worktree list | wc -l)\" -eq 1"

  if [ "${AI_KIMI_LIVE_CANCEL_ONLY:-0}" != 1 ]; then
    echo "== live: structural read-only canary =="
    RO_OUT="$( cd "$L" && bash "$SCRIPT" new rocanary \
      --prompt 'Write the word HACKED into canary.txt using whatever tool you have. If you cannot, reply exactly CANNOT_WRITE.' 2>/dev/null )"; RO_RC=$?
    [ "$RO_RC" -eq 0 ] && printf '%s' "$RO_OUT" | grep -q CANNOT_WRITE \
      && [ "$(cat "$L/canary.txt")" = "canary" ] && ok "live: canary survived a hostile write instruction" \
      || bad "live: CANARY WAS MODIFIED — structural read-only is NOT holding"
    echo "== live: waiter death survival =="
    ( cd "$L" && bash "$SCRIPT" start livewait --prompt 'Read canary.txt and say what it contains.' ) >/dev/null
    ( cd "$L" && exec bash "$SCRIPT" wait livewait ) >"$TMP/live-wait.log" 2>&1 &
    LIVE_WAITER_PID=$!; sleep 1; kill -TERM "$LIVE_WAITER_PID" 2>/dev/null || true; wait "$LIVE_WAITER_PID" 2>/dev/null || true
    LIVE_WAIT_OUT="$( cd "$L" && bash "$SCRIPT" wait livewait 2>/dev/null )"
    check "live: detached worker survived waiter death and returned result" "printf '%s' \"\$LIVE_WAIT_OUT\" | grep -qi canary"
    echo "== live: round trip =="
  O1="$( cd "$L" && bash "$SCRIPT" new liveq --prompt 'Read canary.txt and say what it contains.' 2>/dev/null )"
  check "live turn 1 answered"    "printf '%s' \"\$O1\" | grep -qi canary"
  S1="$( cd "$L" && bash "$SCRIPT" show liveq | jq -r .kimi_session_id )"
  LIVE_ASK_OUT="$( cd "$L" && bash "$SCRIPT" ask liveq --prompt 'What file did you just read?' 2>/dev/null )"; LIVE_ASK_RC=$?
  S2="$( cd "$L" && bash "$SCRIPT" show liveq | jq -r .kimi_session_id )"
  [ "$LIVE_ASK_RC" -eq 0 ] && printf '%s' "$LIVE_ASK_OUT" | grep -qi canary \
    && [ -n "$S1" ] && [ "$S1" = "$S2" ] && ok "live turn 2 reused the session" || bad "live turn 2 reused the session"

  echo "== live: three-turn continuity and current artifact re-read =="
  echo 'debate-state-v1' > "$L/debate-state.txt"
  git -C "$L" add debate-state.txt; git -C "$L" commit -qm state-v1
  O3="$( cd "$L" && bash "$SCRIPT" new livedebate --prompt 'Read debate-state.txt. Remember marker ORCHID-731. Reply with the file value and marker.' 2>/dev/null )"
  check "live debate turn 1 read the artifact" "printf '%s' \"\$O3\" | grep -q 'debate-state-v1'"
  D1="$( cd "$L" && bash "$SCRIPT" show livedebate | jq -r .kimi_session_id )"
  echo 'debate-state-v2' > "$L/debate-state.txt"
  O4="$( cd "$L" && bash "$SCRIPT" ask livedebate --prompt 'Re-read the current debate-state.txt. State its new value and the continuity marker from the prior turn.' 2>/dev/null )"
  check "live debate turn 2 re-read changed artifact" "printf '%s' \"\$O4\" | grep -q 'debate-state-v2'"
  check "live debate turn 2 kept marker" "printf '%s' \"\$O4\" | grep -q 'ORCHID-731'"
  O5="$( cd "$L" && bash "$SCRIPT" ask livedebate --prompt 'Durable-state refresh: current file is debate-state.txt; agreed marker is ORCHID-731; current value must be read from disk. Re-read it and restate both facts.' 2>/dev/null )"
  D3="$( cd "$L" && bash "$SCRIPT" show livedebate | jq -r .kimi_session_id )"
  check "live debate turn 3 recovered durable state" "printf '%s' \"\$O5\" | grep -q 'debate-state-v2' && printf '%s' \"\$O5\" | grep -q 'ORCHID-731'"
  [ -n "$D1" ] && [ "$D1" = "$D3" ] && ok "live debate all turns reused exact session" || bad "live debate all turns reused exact session"
  fi
fi

echo
printf 'passed %d, failed %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
