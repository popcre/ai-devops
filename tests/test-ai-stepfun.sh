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
export AI_REVIEW_EVENT_DIR="$TMP/events"
export AI_STEPFUN_PLATFORM=Linux AI_STEPFUN_RATE_PAUSE=0 AI_STEPFUN_REPORT_FLOOR=20
mkdir -p "$TMP/bin" "$HOME"
printf 'stub-key\n' > "$AI_STEPFUN_KEY_STORE"; chmod 600 "$AI_STEPFUN_KEY_STORE"
git -C "$TMP" init -q repo; git -C "$TMP/repo" config user.email t@example.com; git -C "$TMP/repo" config user.name T
printf 'x\n' > "$TMP/repo/f"; git -C "$TMP/repo" add f; git -C "$TMP/repo" commit -qm init
HEAD_SHA="$(git -C "$TMP/repo" rev-parse HEAD)"

# The stub records its argv and answers per the mode file. The wrapper clears
# the environment, so control paths are baked into the stub, not exported.
export STUB_ARGS="$TMP/args"
cat > "$TMP/bin/step" <<STUB
#!/usr/bin/env bash
STUB_ARGS='$TMP/args'; STUB_MODE="\$(cat '$TMP/mode' 2>/dev/null)"
STUB
cat >> "$TMP/bin/step" <<'STUB'
[ "${1:-}" = --version ] && { echo 0.1.1; exit 0; }
[ "${1:-}" = --help ] && { echo 'step - AI coding assistant with read, bash, edit, write tools'; exit 0; }
printf '%s\n' "$@" > "$STUB_ARGS"; printf '%s\n' "${STEP_API_KEY:-}" > "$STUB_ARGS.key"; env > "$STUB_ARGS.env"
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
  implcommit) printf 'x\n' > c.txt; git add c.txt; git -c user.name=m -c user.email=m@m commit -qm sneaky; echo done ;;
  askwrite) touch ASKED; echo 'answer' ;;
  quote) echo 'StepFun replies "You exceeded your current quota, please check your plan and billing details" when unpaid.' ;;
  askok) echo 'The loop is bounded by RATE_RETRIES.' ;;
esac
STUB
chmod +x "$TMP/bin/step"
mode(){ printf '%s\n' "$1" > "$TMP/mode"; }

# A recording stand-in for bubblewrap: it keeps the sandbox arguments for the
# checks below and runs the command with only --chdir and --setenv applied.
cat > "$TMP/bin/bwrap" <<STUB
#!/usr/bin/env bash
printf '%s\\n' "\$@" > '$TMP/args.bwrap'
STUB
cat >> "$TMP/bin/bwrap" <<'STUB'
while [ "$#" -gt 0 ]; do case "$1" in
  --) shift; break ;;
  --chdir) cd "$2" || exit 97; shift 2 ;;
  --setenv) [ "$2" = HOME ] || export "$2=$3"; shift 3 ;;
  --die-with-parent|--unshare-all|--share-net) shift ;;
  --dev|--proc|--tmpfs) shift 2 ;;
  *) shift 3 ;;
esac; done
exec "$@"
STUB
chmod +x "$TMP/bin/bwrap"
export AI_STEPFUN_BWRAP="$TMP/bin/bwrap"

echo '== ai-stepfun'
out="$(AI_STEPFUN_PLATFORM=MINGW64_NT-10.0 "$SCRIPT" doctor 2>&1)"; rc=$?
check "refuses to run on Windows" "[ $rc = 2 ] && printf '%s' \"\$out\" | grep -q unsupported-platform"
cat > "$TMP/bin/other-step" <<'STUB'
#!/usr/bin/env bash
echo 'step 0.28.2 (Smallstep CLI)'
STUB
chmod +x "$TMP/bin/other-step"
check "a different program named step is not accepted as StepCode" "! AI_STEPFUN_STEP_BIN='$TMP/bin/other-step' HOME='$TMP/nohome' '$SCRIPT' doctor >/dev/null 2>&1"

# The checks below drive the stubbed Linux path, whose key-store proof
# (stat mode 600) and bubblewrap sandbox only exist on Linux filesystems;
# on Windows the wrapper is correctly refused above and nothing here could
# pass for filesystem reasons rather than code reasons.
if [ "$(uname -s)" != Linux ]; then
  SKIP=$((SKIP + 1)); echo 'SKIP  stubbed Linux path (not a Linux filesystem)'
else
check "doctor passes with the stub and a protected key store" "'$SCRIPT' doctor | grep -q '^OK step=0.1.1'"
check "doctor prints one PASS line per check for the shared-db allocator" "[ \"\$('$SCRIPT' doctor | grep -c '^PASS  ')\" = 3 ] && mode ok && [ \"\$('$SCRIPT' doctor --live | grep -c '^PASS  ')\" = 4 ]"
check "doctor refuses a key store that is not owner-only" "chmod 644 '$AI_STEPFUN_KEY_STORE'; ! '$SCRIPT' doctor >/dev/null; rc=\$?; chmod 600 '$AI_STEPFUN_KEY_STORE'; [ \$rc = 0 ]"
check "live doctor makes one call and sees the answer" "mode ok; '$SCRIPT' doctor --live | grep -q 'live=verified'"
check "the key reaches step through the environment, never argv" "mode ok; '$SCRIPT' doctor --live >/dev/null && grep -qx stub-key '$STUB_ARGS.key' && ! grep -q stub-key '$STUB_ARGS'"

check "review accepts a well-formed verdict naming the head" "mode verdict; '$SCRIPT' review --repo '$TMP/repo' --prompt 'check f' 2>/dev/null | grep -q \"VERDICT: APPROVE $HEAD_SHA\""
check "every turn runs inside the sandbox with an empty home and /tmp" "grep -qx -- --unshare-all '$STUB_ARGS.bwrap' && grep -A1 -x -- --tmpfs '$STUB_ARGS.bwrap' | grep -qx '$HOME' && grep -A1 -x -- --tmpfs '$STUB_ARGS.bwrap' | grep -qx /tmp"
check "the sandbox never mounts the whole filesystem, only system trees" "! grep -x -A1 -- --ro-bind '$STUB_ARGS.bwrap' | grep -qx / && grep -x -A1 -- --ro-bind '$STUB_ARGS.bwrap' | grep -qx /usr"
check "the sandbox also hides /run (agent, D-Bus, and Docker sockets)" "grep -A1 -x -- --tmpfs '$STUB_ARGS.bwrap' | grep -qx /run"
check "the user's StepCode settings tree is not remounted" "! grep -qx '$HOME/.stepcode' '$STUB_ARGS.bwrap'"
check "the review copy is mounted read-only" "grep -x -A1 -- --ro-bind '$STUB_ARGS.bwrap' | grep -q 'stepfun-'"
check "review hands the model the sealed MANIFEST.md" "grep -q 'MANIFEST.md first' '$STUB_ARGS'"
check "review runs with only read-only tools and strict approval" "grep -qx 'read,grep,find,ls' '$STUB_ARGS' && grep -qx strict '$STUB_ARGS' && grep -qx deny '$STUB_ARGS' && grep -qx -- --no-extensions '$STUB_ARGS' && grep -qx -- --no-approve '$STUB_ARGS'"
OP_SERVICE_ACCOUNT_TOKEN=planted-op GH_TOKEN=planted-gh SSH_AUTH_SOCK=/planted.sock mode ok
OP_SERVICE_ACCOUNT_TOKEN=planted-op GH_TOKEN=planted-gh SSH_AUTH_SOCK=/planted.sock "$SCRIPT" doctor --live >/dev/null 2>&1
check "host timeout is resolved from /usr/bin, never a user path" "grep -q 'timeout_bin=\"\$(PATH=/usr/bin:/bin command -v timeout)\"' '$SCRIPT' && ! grep -qE '^[[:space:]]*exec timeout ' '$SCRIPT'"
check "caller secrets in the environment never reach the model" "grep -q '^STEP_API_KEY=' '$STUB_ARGS.env' && ! grep -q planted '$STUB_ARGS.env'"
printf '.ai/\n' >> "$TMP/repo/.git/info/exclude"; mkdir -p "$TMP/repo/.ai/reviews"
mode verdict
AI_REVIEW_SOURCE_RECEIPT_FILE="$TMP/repo/.ai/reviews/governed-source-test.json" "$SCRIPT" review --repo "$TMP/repo" --base "$HEAD_SHA" --assert-head "$HEAD_SHA" --prompt-file "$TMP/repo/f" > "$TMP/gov.out" 2>/dev/null; rc=$?
check "a governed run writes the source receipt the shared-db runner validates" "[ $rc = 0 ] && jq -e --arg h '$HEAD_SHA' '.schema_version==1 and .identity.head==\$h and (.packet_sha256|test(\"^[0-9a-f]{64}\$\"))' '$TMP/repo/.ai/reviews/governed-source-test.json'"
check "a governed run ends in exactly one terminal VERDICT line for the head" "[ \"\$(grep -c '^VERDICT:' '$TMP/gov.out')\" = 1 ] && tail -n1 '$TMP/gov.out' | grep -qx 'VERDICT: APPROVE $HEAD_SHA'"
check "review rejects an answer with no verdict" "mode noverdict; ! '$SCRIPT' review --repo '$TMP/repo' --prompt x >/dev/null 2>&1"
check "review rejects a verdict with no analysis behind it" "mode short; ! AI_STEPFUN_REPORT_FLOOR=400 '$SCRIPT' review --repo '$TMP/repo' --prompt x >/dev/null 2>&1"
check "review rejects any change to the review copy" "mode write; ! '$SCRIPT' review --repo '$TMP/repo' --prompt x >/dev/null 2>&1 && [ ! -e '$TMP/repo/MUTATED' ]"
check "review retries a rate limit and then succeeds" "rm -f '$STUB_ARGS.n'; mode rate; '$SCRIPT' review --repo '$TMP/repo' --prompt x 2>/dev/null | grep -q 'VERDICT: REVISE'"
out="$(mode credit; "$SCRIPT" review --repo "$TMP/repo" --prompt x 2>&1)"; rc=$?
check "out of credit exits 92 with the contract line" "[ $rc = 92 ] && printf '%s' \"\$out\" | grep -q 'AI_REVIEWER_OUT_OF_CREDIT provider=stepfun code=insufficient_quota' && printf '%s' \"\$out\" | grep -q 'OUT OF CREDIT: .*platform.stepfun.ai'"

out="$(mode impl; "$SCRIPT" implement --repo "$TMP/repo" --prompt 'add new.py' 2>&1)"
wt="$(printf '%s\n' "$out" | sed -n 's/^CLONE //p')"
check "implement works in a new clone and leaves the caller's checkout alone" "[ -n '$wt' ] && [ -f '$wt/new.py' ] && [ ! -e '$TMP/repo/new.py' ] && [ -z \"\$(git -C '$TMP/repo' status --porcelain)\" ]"
check "the implementation clone is the only writable mount from the real home" "[ \"\$(grep -c -x -- --bind '$STUB_ARGS.bwrap')\" = 2 ] && grep -x -A1 -- --bind '$STUB_ARGS.bwrap' | grep -q '/implement/' && grep -x -A1 -- --bind '$STUB_ARGS.bwrap' | grep -q '/agent[.]'"
check "implement leaves no caller path in FETCH_HEAD" "[ ! -e '$wt/.git/FETCH_HEAD' ]"
check "implement grants write and shell tools with auto approval" "grep -qx 'read,bash,edit,write,grep,find,ls' '$STUB_ARGS' && grep -qx auto '$STUB_ARGS' && grep -qx allow '$STUB_ARGS'"
check "the implementation clone has no remote" "[ -z \"\$(git -C '$wt' remote)\" ]"
check "implement never commits" "[ \"\$(git -C '$wt' rev-parse HEAD)\" = '$HEAD_SHA' ]"
check "implement uses a fixed-length branch name" "printf '%s\n' \"\$out\" | grep -Eq '^BRANCH stepfun/impl-[0-9]{14}-[0-9a-f]{6}$'"

check "implement refuses a run in which the model committed" "mode implcommit; ! '$SCRIPT' implement --repo '$TMP/repo' --prompt x >/dev/null 2>&1 && [ \"\$(git -C '$TMP/repo' rev-parse HEAD)\" = '$HEAD_SHA' ]"
check "ask answers from a disposable copy" "mode askok; '$SCRIPT' ask --repo '$TMP/repo' 'bounded?' 2>/dev/null | grep -q RATE_RETRIES"
check "ask rejects any change to its copy and never touches the checkout" "mode askwrite; ! '$SCRIPT' ask --repo '$TMP/repo' x >/dev/null 2>&1 && [ ! -e '$TMP/repo/ASKED' ]"
mode quote; "$SCRIPT" review --repo "$TMP/repo" --prompt x >/dev/null 2>&1; rc=$?
check "a review that only quotes a billing message is not treated as out of credit" "[ $rc != 0 ] && [ $rc != 92 ]"
check "live doctor stops with exit 92 when StepFun is out of credit" "mode credit; '$SCRIPT' doctor --live >/dev/null 2>&1; [ \$? = 92 ]"
check "doctor refuses to run without bubblewrap" "AI_STEPFUN_BWRAP='$TMP/missing' '$SCRIPT' doctor 2>&1 | grep -q 'FAIL bubblewrap'"

# Real sandbox: when bubblewrap works here, prove the model's side cannot see
# the caller's home secrets or write outside its directory.
REAL_BWRAP="$(PATH=/usr/bin:/bin command -v bwrap 2>/dev/null || true)"
if [ -n "$REAL_BWRAP" ] && "$REAL_BWRAP" --ro-bind /usr /usr --symlink usr/bin /bin --symlink usr/lib /lib --symlink usr/lib64 /lib64 --tmpfs /tmp /usr/bin/true 2>/dev/null; then
  # A home outside /tmp, so only the sandbox's empty-home mount can hide it.
  mkdir -p "$ROOT/.ai"; RH="$(mktemp -d "$ROOT/.ai/stepfun-test-home.XXXXXX")"
  mkdir -p "$RH/.ssh" "$RH/probe-bin" "$RH/.config/ai-devops/secrets"; printf 'secret\n' > "$RH/.ssh/id_test"
  cp "$AI_STEPFUN_KEY_STORE" "$RH/.config/ai-devops/secrets/stepfun-api-key"; chmod 600 "$RH/.config/ai-devops/secrets/stepfun-api-key"
  cat > "$RH/probe-bin/step" <<'STUB'
#!/usr/bin/env bash
[ "${1:-}" = --help ] && { echo 'step - AI coding assistant'; exit 0; }
[ "${1:-}" = --version ] && { echo 0.1.1; exit 0; }
touch "$HOME/escape" 2>/dev/null
[ -e "$HOME/.ssh/id_test" ] || grep -q planted /proc/self/environ || echo STEPFUN-OK
STUB
  chmod +x "$RH/probe-bin/step"
  out="$(OP_SERVICE_ACCOUNT_TOKEN=planted-op HOME="$RH" AI_STEPFUN_KEY_STORE="$RH/.config/ai-devops/secrets/stepfun-api-key" AI_STEPFUN_STATE_DIR="$RH/state" AI_STEPFUN_BWRAP="$REAL_BWRAP" AI_STEPFUN_STEP_BIN="$RH/probe-bin/step" "$SCRIPT" doctor --live 2>&1)"
  check "real sandbox: the model cannot see home or environment secrets" "printf '%s' \"\$out\" | grep -q 'live=verified'"
  check "real sandbox: writes to the real home do not escape" "[ ! -e '$RH/escape' ]"
  rm -rf "$RH"
else
  skip "real sandbox checks (bubblewrap unavailable here)"; skip "real sandbox escape check"
fi
check "invocations are recorded in the durable reviewer event ledger" "grep -rqs stepfun '$TMP/events'"

fi

printf '\n%s passed, %s failed, %s skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
