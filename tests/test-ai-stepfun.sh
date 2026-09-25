#!/usr/bin/env bash
# Offline tests for bin/ai-stepfun: a stub `step` stands in for StepCode, so no
# key, network, or credit is used. Live proof is recorded in the PR, not here.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; SCRIPT="$ROOT/bin/ai-stepfun"
PASS=0; FAIL=0; SKIP=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" AI_STEPFUN_STATE_DIR="$TMP/state" AI_STEPFUN_KEY_STORE="$TMP/home/key"
export AI_REVIEW_QUARANTINE_DIR="$TMP/quarantine" AI_STEPFUN_STEP_BIN="$TMP/bin/step"
export AI_STEPFUN_PLATFORM=Linux AI_STEPFUN_RATE_PAUSE=0 AI_STEPFUN_REPORT_FLOOR=20
mkdir -p "$TMP/bin" "$HOME"
printf 'stub-key\n' > "$AI_STEPFUN_KEY_STORE"; chmod 600 "$AI_STEPFUN_KEY_STORE"
git -C "$TMP" init -q repo; git -C "$TMP/repo" config user.email t@example.com; git -C "$TMP/repo" config user.name T
printf 'x\n' > "$TMP/repo/f"; git -C "$TMP/repo" add f; git -C "$TMP/repo" commit -qm init
HEAD_SHA="$(git -C "$TMP/repo" rev-parse HEAD)"

# The stub records its argv and answers per STUB_MODE.
cat > "$TMP/bin/step" <<'STUB'
#!/usr/bin/env bash
[ "${1:-}" = --version ] && { echo 0.1.1; exit 0; }
printf '%s\n' "$@" > "$STUB_ARGS"; printf '%s\n' "${STEP_API_KEY:-}" > "$STUB_ARGS.key"
prompt="${@: -1}"; head="$(printf '%s' "$prompt" | grep -oE '[0-9a-f]{40}' | head -1)"
case "$STUB_MODE" in
  ok) echo STEPFUN-OK ;;
  verdict) printf 'Analysis of the change with plenty of detail in f:1.\n\nVERDICT: APPROVE %s\n' "$head" ;;
  noverdict) echo 'Looks fine.' ;;
  short) printf 'ok\nVERDICT: APPROVE %s\n' "$head" ;;
  credit) echo '402: {"message":"You exceeded your current quota, please check your plan and billing details","type":"quota_exceeded"}' ;;
  write) touch MUTATED; printf 'Analysis of the change with plenty of detail.\nVERDICT: APPROVE %s\n' "$head" ;;
  rate) n=$(cat "$STUB_ARGS.n" 2>/dev/null || echo 0); echo $((n+1)) > "$STUB_ARGS.n"
        if [ "$n" -lt 1 ]; then echo '429: {"message":"request limited RPM reached","type":"rate_limited"}'; else printf 'Analysis of the change with plenty of detail.\nVERDICT: REVISE %s\n' "$head"; fi ;;
  impl) printf 'print(1)\n' > new.py; echo 'Created new.py and ran it.' ;;
esac
STUB
chmod +x "$TMP/bin/step"
export STUB_ARGS="$TMP/args"

echo '== ai-stepfun'
check "refuses to run on Windows" "AI_STEPFUN_PLATFORM=MINGW64_NT-10.0 '$SCRIPT' doctor 2>&1 | grep -q unsupported-platform; [ \"\${PIPESTATUS[0]}\" = 2 ]"
check "doctor passes with the stub and a protected key store" "'$SCRIPT' doctor | grep -q '^OK step=0.1.1'"
check "doctor refuses a key store that is not owner-only" "chmod 644 '$AI_STEPFUN_KEY_STORE'; ! '$SCRIPT' doctor >/dev/null; rc=\$?; chmod 600 '$AI_STEPFUN_KEY_STORE'; [ \$rc = 0 ]"
check "live doctor makes one call and sees the answer" "STUB_MODE=ok '$SCRIPT' doctor --live | grep -q 'live=verified'"
check "the key reaches step through the environment, never argv" "STUB_MODE=ok '$SCRIPT' doctor --live >/dev/null && grep -qx stub-key '$STUB_ARGS.key' && ! grep -q stub-key '$STUB_ARGS'"

check "review accepts a well-formed verdict naming the head" "STUB_MODE=verdict '$SCRIPT' review --repo '$TMP/repo' --prompt 'check f' 2>/dev/null | grep -q \"VERDICT: APPROVE $HEAD_SHA\""
check "review runs with only read-only tools and strict approval" "grep -qx 'read,grep,find,ls' '$STUB_ARGS' && grep -qx strict '$STUB_ARGS' && grep -qx deny '$STUB_ARGS' && grep -qx -- --no-extensions '$STUB_ARGS' && grep -qx -- --no-approve '$STUB_ARGS'"
check "review rejects an answer with no verdict" "! STUB_MODE=noverdict '$SCRIPT' review --repo '$TMP/repo' --prompt x >/dev/null 2>&1"
check "review rejects a verdict with no analysis behind it" "! STUB_MODE=short AI_STEPFUN_REPORT_FLOOR=400 '$SCRIPT' review --repo '$TMP/repo' --prompt x >/dev/null 2>&1"
check "review rejects any change to the review copy" "! STUB_MODE=write '$SCRIPT' review --repo '$TMP/repo' --prompt x >/dev/null 2>&1 && [ ! -e '$TMP/repo/MUTATED' ]"
check "review retries a rate limit and then succeeds" "rm -f '$STUB_ARGS.n'; STUB_MODE=rate '$SCRIPT' review --repo '$TMP/repo' --prompt x 2>/dev/null | grep -q 'VERDICT: REVISE'"
out="$(STUB_MODE=credit "$SCRIPT" review --repo "$TMP/repo" --prompt x 2>&1)"; rc=$?
check "out of credit exits 92 with the contract line" "[ $rc = 92 ] && printf '%s' \"\$out\" | grep -q 'AI_REVIEWER_OUT_OF_CREDIT provider=stepfun code=insufficient_quota' && printf '%s' \"\$out\" | grep -q 'OUT OF CREDIT: .*platform.stepfun.ai'"

out="$(STUB_MODE=impl "$SCRIPT" implement --repo "$TMP/repo" --prompt 'add new.py' 2>&1)"
wt="$(printf '%s\n' "$out" | sed -n 's/^WORKTREE //p')"
check "implement works in a new worktree and leaves the caller's checkout alone" "[ -n '$wt' ] && [ -f '$wt/new.py' ] && [ ! -e '$TMP/repo/new.py' ] && [ -z \"\$(git -C '$TMP/repo' status --porcelain)\" ]"
check "implement grants write and shell tools with auto approval" "grep -qx 'read,bash,edit,write,grep,find,ls' '$STUB_ARGS' && grep -qx auto '$STUB_ARGS' && grep -qx allow '$STUB_ARGS'"
check "implement never commits" "[ \"\$(git -C '$wt' rev-parse HEAD)\" = '$HEAD_SHA' ]"
check "implement uses a fixed-length branch name" "printf '%s\n' \"\$out\" | grep -Eq '^BRANCH stepfun/impl-[0-9]{14}-[0-9a-f]{6}$'"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
