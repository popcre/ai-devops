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
STUB_ARGS='$TMP/args'; CALLER='$TMP/repo'; STUB_MODE="\$(cat '$TMP/mode' 2>/dev/null)"
STUB
cat >> "$TMP/bin/step" <<'STUB'
[ "${1:-}" = --version ] && { echo 0.1.1; exit 0; }
[ "${1:-}" = --help ] && { echo 'step - AI coding assistant with read, bash, edit, write tools'; exit 0; }
printf '%s\n' "$@" > "$STUB_ARGS"; printf '%s\n' "${STEP_API_KEY:-}" > "$STUB_ARGS.key"; env > "$STUB_ARGS.env"
prompt="${@: -1}"; printf '%s\n' "$prompt" > "$STUB_ARGS.prompt"
head="$(printf '%s' "$prompt" | grep -oE '[0-9a-f]{40}' | head -1)"
attempt(){ n=$(cat "$STUB_ARGS.n" 2>/dev/null || echo 0); echo $((n+1)) > "$STUB_ARGS.n"; }
case "$STUB_MODE" in
  ok) echo STEPFUN-OK ;;
  verdict) printf 'Analysis of the change with plenty of detail in f:1.\n\nVERDICT: APPROVE %s\n' "$head" ;;
  noverdict) echo 'Looks fine.' ;;
  short) printf 'ok\nVERDICT: APPROVE %s\n' "$head" ;;
  credit) echo '402: {"message":"You exceeded your current quota, please check your plan and billing details","type":"quota_exceeded"}' ;;
  write) touch MUTATED; git remote -v > "$STUB_ARGS.remote" 2>&1; echo "rc=$?" >> "$STUB_ARGS.remote"; printf 'Analysis of the change with plenty of detail.\nVERDICT: APPROVE %s\n' "$head" ;;
  rate) n=$(cat "$STUB_ARGS.n" 2>/dev/null || echo 0); echo $((n+1)) > "$STUB_ARGS.n"
        if [ "$n" -lt 1 ]; then echo '429: {"message":"request limited RPM reached","type":"rate_limited"}'; else printf 'Analysis of the change with plenty of detail.\nVERDICT: REVISE %s\n' "$head"; fi ;;
  quote429) attempt; printf 'The code sample says 429: {"code":"rate_limited"}; the note says Too Many Requests. Review complete.\nVERDICT: APPROVE %s\n' "$head" ;;
  goodstderr429) attempt; echo 'RATE_LIMITED: HTTP 429 Too Many Requests' >&2; printf 'Analysis of the change with plenty of detail.\nVERDICT: APPROVE %s\n' "$head" ;;
  quote402) attempt; printf 'The code sample quotes 402 insufficient_quota and billing. Review complete.\nVERDICT: APPROVE %s\n' "$head" ;;
  stdout429) attempt; if [ "$n" -eq 0 ]; then echo '429: {"error":{"code":"rate_limited"}}'; exit 1; fi; printf 'Analysis of the change with plenty of detail.\nVERDICT: REVISE %s\n' "$head" ;;
  stderr:*) attempt; if [ "$n" -eq 0 ]; then printf '%s\n' "${STUB_MODE#stderr:}" >&2; exit 1; fi; printf 'Analysis of the change with plenty of detail.\nVERDICT: REVISE %s\n' "$head" ;;
  bashfail) attempt; echo 'command not found' >&2; exit 1 ;;
  implrate) attempt; echo '429 rate limit exceeded' >&2; exit 1 ;;
  impl) printf 'print(1)\n' > new.py; echo 'Created new.py and ran it.' ;;
  implcommit) printf 'x\n' > c.txt; git add c.txt; git -c user.name=m -c user.email=m@m commit -qm sneaky; echo done ;;
  askwrite) touch ASKED; echo 'answer' ;;
  touchcaller) touch "$CALLER/CALLER_TOUCHED"; printf 'Analysis of the change with plenty of detail.\nVERDICT: APPROVE %s\n' "$head" ;;
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
# Windows without a usable engine is still refused; with OpenCode it is supported.
out="$(AI_STEPFUN_PLATFORM=MINGW64_NT-10.0 AI_STEPFUN_ENGINE=none "$SCRIPT" doctor 2>&1)"; rc=$?
check "refuses to run on Windows without an engine" "[ $rc = 2 ] && printf '%s' \"\$out\" | grep -q unsupported-platform"
cat > "$TMP/bin/other-step" <<'STUB'
#!/usr/bin/env bash
echo 'step 0.28.2 (Smallstep CLI)'
STUB
chmod +x "$TMP/bin/other-step"
check "a different program named step is not accepted as StepCode" "! AI_STEPFUN_STEP_BIN='$TMP/bin/other-step' HOME='$TMP/nohome' AI_STEPFUN_ENGINE=stepcode '$SCRIPT' doctor >/dev/null 2>&1"

# OpenCode engine stub: records argv and answers per the mode file, emitting
# the JSONL shape `opencode run --format json` produces. Writes files into the
# --dir target, as a real agent would.
cat > "$TMP/bin/opencode" <<STUB
#!/usr/bin/env bash
STUB_ARGS='$TMP/args.oc'; STUB_MODE="\$(cat '$TMP/mode' 2>/dev/null)"
STUB
cat >> "$TMP/bin/opencode" <<'STUB'
[ "${1:-}" = --version ] && { echo 1.18.12; exit 0; }
printf '%s\n' "$@" > "$STUB_ARGS"
dir="."; while [ $# -gt 0 ]; do [ "$1" = --dir ] && { dir="$2"; shift; }; shift; done
prompt="$(cat)"; printf '%s\n' "$prompt" > "$STUB_ARGS.prompt"
head="$(printf '%s' "$prompt" | grep -oE '[0-9a-f]{40}' | head -1)"
case "$STUB_MODE" in
  ok) printf '{"type":"text","part":{"text":"STEPFUN-OK"}}\n' ;;
  verdict) printf '{"type":"text","part":{"text":"Analysis of the change with plenty of detail in f:1.\\n\\nVERDICT: APPROVE %s"}}\n' "$head" ;;
  impl) printf 'print(1)\n' > "$dir/new.py"; printf '{"type":"text","part":{"text":"Created new.py and ran it."}}\n' ;;
  askok) printf '{"type":"text","part":{"text":"The loop is bounded by RATE_RETRIES."}}\n' ;;
  jsonl429) n=$(cat "$STUB_ARGS.n" 2>/dev/null || echo 0); echo $((n+1)) > "$STUB_ARGS.n"
            if [ "$n" -eq 0 ]; then printf '{"type":"error","error":{"data":{"message":"HTTP 429 Too Many Requests","status":429}}}\n'; exit 1; fi
            printf '{"type":"text","part":{"text":"Analysis of the change with plenty of detail.\\nVERDICT: REVISE %s"}}\n' "$head" ;;
  jsonltext429) n=$(cat "$STUB_ARGS.n" 2>/dev/null || echo 0); echo $((n+1)) > "$STUB_ARGS.n"
                printf '{"type":"text","part":{"text":"The code quotes HTTP 429 rate_limited. Analysis complete.\\nVERDICT: APPROVE %s"}}\n' "$head" ;;
  *) printf '{"type":"text","part":{"text":"ok"}}\n' ;;
esac
STUB
chmod +x "$TMP/bin/opencode"

# The checks below drive the stubbed Linux StepCode path, whose key-store proof
# (stat mode 600) and bubblewrap sandbox only exist on Linux filesystems.
if [ "$(uname -s)" != Linux ]; then
  SKIP=$((SKIP + 1)); echo 'SKIP  stubbed Linux path (not a Linux filesystem)'
else
check "doctor passes with the stub and a protected key store" "'$SCRIPT' doctor | grep -q '^OK engine=stepcode'"
check "doctor prints one PASS line per check for the shared-db allocator" "[ \"\$('$SCRIPT' doctor | grep -c '^PASS  ')\" = 4 ] && mode ok && [ \"\$('$SCRIPT' doctor --live | grep -c '^PASS  ')\" = 5 ]"
check "doctor refuses a key store that is not owner-only" "chmod 644 '$AI_STEPFUN_KEY_STORE'; ! '$SCRIPT' doctor >/dev/null; rc=\$?; chmod 600 '$AI_STEPFUN_KEY_STORE'; [ \$rc = 0 ]"
check "live doctor makes one call and sees the answer" "mode ok; '$SCRIPT' doctor --live | grep -q 'live=verified'"
check "the key reaches step through the environment, never argv" "mode ok; '$SCRIPT' doctor --live >/dev/null && grep -qx stub-key '$STUB_ARGS.key' && ! grep -q stub-key '$STUB_ARGS'"

check "review accepts a well-formed verdict naming the head" "mode verdict; '$SCRIPT' review --repo '$TMP/repo' --prompt 'check f' 2>/dev/null | grep -q \"VERDICT: APPROVE $HEAD_SHA\""
check "StepCode retains its only verdict-format instructions" "[ \"\$(grep -c '^VERDICT: APPROVE <head sha>' '$STUB_ARGS.prompt')\" = 1 ] && grep -qx 'Exact head SHA for the final verdict: $HEAD_SHA' '$STUB_ARGS.prompt'"
check "StepCode puts review-specific values after stable instructions" "! sed '/^Review packet:/,\$d' '$STUB_ARGS.prompt' | grep -Eq '[0-9a-f]{40}' && tail -n1 '$STUB_ARGS.prompt' | grep -qx 'check f'"
check "every turn runs inside the sandbox with an empty home and /tmp" "grep -qx -- --unshare-all '$STUB_ARGS.bwrap' && grep -A1 -x -- --tmpfs '$STUB_ARGS.bwrap' | grep -qx '$HOME' && grep -A1 -x -- --tmpfs '$STUB_ARGS.bwrap' | grep -qx /tmp"
check "the sandbox never mounts the whole filesystem, only system trees" "! grep -x -A1 -- --ro-bind '$STUB_ARGS.bwrap' | grep -qx / && grep -x -A1 -- --ro-bind '$STUB_ARGS.bwrap' | grep -qx /usr"
check "the sandbox also hides /run (agent, D-Bus, and Docker sockets)" "grep -A1 -x -- --tmpfs '$STUB_ARGS.bwrap' | grep -qx /run"
check "the user's StepCode settings tree is not remounted" "! grep -qx '$HOME/.stepcode' '$STUB_ARGS.bwrap'"
check "the review copy (not the caller's checkout) is the writable mount" "grep -x -A1 -- --bind '$STUB_ARGS.bwrap' | grep -q 'review-work[.]' && ! grep -x -A1 -- --bind '$STUB_ARGS.bwrap' | grep -qx '$TMP/repo'"
check "review prompt no longer claims read-only and says edits are discarded" "! grep -qi 'read-only' '$STUB_ARGS' && grep -q 'discarded' '$STUB_ARGS'"
check "review hands the model the sealed MANIFEST.md" "grep -q 'MANIFEST.md first' '$STUB_ARGS'"
check "review runs with write and shell tools under auto approval" "grep -qx 'read,bash,edit,write,grep,find,ls' '$STUB_ARGS' && grep -qx auto '$STUB_ARGS' && grep -qx allow '$STUB_ARGS' && grep -qx -- --no-extensions '$STUB_ARGS' && grep -qx -- --no-approve '$STUB_ARGS'"
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
check "review accepts edits in its disposable copy, which has no remote, and leaves the checkout alone" "mode write; '$SCRIPT' review --repo '$TMP/repo' --prompt x 2>/dev/null | grep -q 'VERDICT: APPROVE' && [ ! -e '$TMP/repo/MUTATED' ] && [ -z \"\$(git -C '$TMP/repo' status --porcelain)\" ]"
check "review rejects an answer when the caller's checkout changed" "mode touchcaller; ! '$SCRIPT' review --repo '$TMP/repo' --prompt x >/dev/null 2>&1 && [ ! -e '$TMP/repo/MUTATED' ]"
rm -f "$TMP/repo/CALLER_TOUCHED"
check "the review copy is a git copy with no remote" "grep -qx 'rc=0' '$STUB_ARGS.remote' && [ \"\$(grep -vc '^rc=' '$STUB_ARGS.remote')\" = 0 ]"
check "review retries a rate limit and then succeeds" "rm -f '$STUB_ARGS.n'; mode rate; '$SCRIPT' review --repo '$TMP/repo' --prompt x 2>/dev/null | grep -q 'VERDICT: REVISE'"
rm -f "$STUB_ARGS.n"; mode quote429
"$SCRIPT" review --repo "$TMP/repo" --prompt x > "$TMP/quote429.out" 2>/dev/null; rc=$?
check "keeps-review-that-quotes-429" "[ $rc = 0 ] && grep -q 'VERDICT: APPROVE' '$TMP/quote429.out' && [ \"\$(cat '$STUB_ARGS.n')\" = 1 ]"
rm -f "$STUB_ARGS.n"; mode goodstderr429
"$SCRIPT" review --repo "$TMP/repo" --prompt x > "$TMP/goodstderr429.out" 2>/dev/null; rc=$?
check "keeps-good-verdict-despite-stderr-429" "[ $rc = 0 ] && grep -q 'VERDICT: APPROVE' '$TMP/goodstderr429.out' && [ \"\$(cat '$STUB_ARGS.n')\" = 1 ]"
rm -f "$STUB_ARGS.n"; mode quote402
"$SCRIPT" review --repo "$TMP/repo" --prompt x > "$TMP/quote402.out" 2>/dev/null; rc=$?
check "keeps-review-that-quotes-402-text" "[ $rc = 0 ] && grep -q 'VERDICT: APPROVE' '$TMP/quote402.out' && [ \"\$(cat '$STUB_ARGS.n')\" = 1 ]"
rm -f "$STUB_ARGS.n"; mode stdout429
"$SCRIPT" review --repo "$TMP/repo" --prompt x > "$TMP/stdout429.out" 2>/dev/null; rc=$?
check "retries-on-stdout-429-json" "[ $rc = 0 ] && grep -q 'VERDICT: REVISE' '$TMP/stdout429.out' && [ \"\$(cat '$STUB_ARGS.n')\" = 2 ]"
for shape in 'rate_limited' 'Too Many Requests' 'HTTP 429' '429 rate limit exceeded' '429 RATE LIMIT EXCEEDED'; do
  rm -f "$STUB_ARGS.n"; mode "stderr:$shape"
  "$SCRIPT" review --repo "$TMP/repo" --prompt x > "$TMP/stderr429.out" 2>/dev/null; rc=$?
  check "retries-on-stderr-$shape" "[ $rc = 0 ] && grep -q 'VERDICT: REVISE' '$TMP/stderr429.out' && [ \"\$(cat '$STUB_ARGS.n')\" = 2 ]"
done
rm -f "$STUB_ARGS.n"; mode 'stderr:1429 request failed'
"$SCRIPT" review --repo "$TMP/repo" --prompt x > /dev/null 2>/dev/null; rc=$?
check "ignores-unbounded-429-on-stderr" "[ $rc != 0 ] && [ \"\$(cat '$STUB_ARGS.n')\" = 1 ]"
rm -f "$STUB_ARGS.n"; mode bashfail
"$SCRIPT" review --repo "$TMP/repo" --prompt x > /dev/null 2>/dev/null; rc=$?
check "no-retry-on-bash-failure" "[ $rc != 0 ] && [ \"\$(cat '$STUB_ARGS.n')\" = 1 ]"
rm -f "$STUB_ARGS.n"; mode implrate
"$SCRIPT" implement --repo "$TMP/repo" --prompt x > /dev/null 2>/dev/null; rc=$?
check "implement-never-auto-retried" "[ $rc != 0 ] && [ \"\$(cat '$STUB_ARGS.n')\" = 1 ]"
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
check "ask may edit its disposable copy and never touches the checkout" "mode askwrite; '$SCRIPT' ask --repo '$TMP/repo' x 2>/dev/null | grep -q answer && [ ! -e '$TMP/repo/ASKED' ] && grep -qx 'read,bash,edit,write,grep,find,ls' '$STUB_ARGS'"
check "ask rejects an answer when the caller's checkout changed" "mode touchcaller; ! '$SCRIPT' ask --repo '$TMP/repo' x >/dev/null 2>&1"
rm -f "$TMP/repo/CALLER_TOUCHED"
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

# ---- OpenCode engine (works on any host with the stub) ----
echo '== ai-stepfun OpenCode engine'
# StepFun: Ubuntu/Linux (bubblewrap) or Windows (folder + test shell, 2026-09-30).
export AI_STEPFUN_ENGINE=opencode AI_STEPFUN_OPENCODE="$TMP/bin/opencode"
check "macOS and unknown systems are refused" "for plat in Darwin FreeBSD; do out=\$(AI_STEPFUN_PLATFORM=\$plat '$SCRIPT' doctor 2>&1); [ \$? = 2 ] && printf '%s' \"\$out\" | grep -q unsupported-platform || exit 1; done"
check "Windows is allowed with OpenCode (folder + test shell)" "out=\$(AI_STEPFUN_PLATFORM=MINGW64_NT-10.0 '$SCRIPT' doctor 2>&1); printf '%s' \"\$out\" | grep -q 'OK engine=opencode'"
# Regression (#1266 residual): jq.exe on Windows ends every -r line with CRLF.
# One shim, built unconditionally, serves the Windows-host allowlist checks
# below and the Linux review check in the OpenCode block.
crlf_bin="$TMP/crlfjq"; mkdir -p "$crlf_bin"
real_jq="$(command -v jq)"
cat > "$crlf_bin/jq" <<SHIM
#!/bin/sh
# jq.exe on Windows: CRLF on every stdout line, exit codes intact (jq -e
# truthiness decides privacy classification), so the shim keeps both.
_t="\$(mktemp 2>/dev/null)" || _t="./.jq-crlf.\$\$"
"$real_jq" "\$@" > "\$_t"
_rc=\$?
sed 's/\$/\r/' "\$_t"
rm -f "\$_t"
exit "\$_rc"
SHIM
chmod +x "$crlf_bin/jq"
printf '{"a":"b"}\n' | "$crlf_bin/jq" -r .a | od -c | grep -q '\\r' \
  || { echo 'FAIL crlf jq shim does not emit CR'; FAIL=$((FAIL+1)); }
# Only reproducible on a real Windows host: a forced platform on a non-Windows
# uname skips provisioning (the CI stub path).
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    good_bash="$(sha256sum "$(command -v bash)" | awk '{print $1}')"
    printf '{"bash":{"path":"%s","sha256":"%s"}}\n' "$(command -v bash)" "$good_bash" > "$TMP/win-runners.json"
    out="$(AI_STEPFUN_PLATFORM=MINGW64_NT-10.0 AI_STEPFUN_RUNNERS_JSON="$TMP/win-runners.json" PATH="$crlf_bin:$PATH" "$SCRIPT" doctor 2>&1)"
    check "crlf-emitting jq still verifies the runner allowlist" "printf '%s' '$out' | grep -q 'PASS  Windows runner allowlist'"
    bad_bash="$(printf '%064d' 7)"
    printf '{"bash":{"path":"%s","sha256":"%s"}}\n' "$(command -v bash)" "$bad_bash" > "$TMP/win-runners-bad.json"
    out="$(AI_STEPFUN_PLATFORM=MINGW64_NT-10.0 AI_STEPFUN_RUNNERS_JSON="$TMP/win-runners-bad.json" PATH="$crlf_bin:$PATH" "$SCRIPT" doctor 2>&1)"
    check "crlf-emitting jq still refuses a mismatched runner hash" "printf '%s' '$out' | grep -q 'FAIL Windows runner allowlist'"
    ;;
  *)
    SKIP=$((SKIP + 2)); echo 'SKIP  Windows-host allowlist verify checks (not a Windows filesystem)'
    ;;
esac
# The OpenCode cases need a Linux filesystem (owner-only key store) and bubblewrap.
if [ "$(uname -s)" != Linux ]; then
  SKIP=$((SKIP + 1)); echo 'SKIP  OpenCode engine cases (not a Linux filesystem)'
else
export AI_STEPFUN_PLATFORM=Linux AI_STEPFUN_OPENCODE_ROOT="$TMP/bin"
mode ok
check "OpenCode doctor passes with the stub and a protected key store" "'$SCRIPT' doctor | grep -q '^OK engine=opencode'"
check "OpenCode doctor prints one PASS line per check" "[ \"\$('$SCRIPT' doctor | grep -c '^PASS  ')\" = 5 ]"
check "OpenCode doctor names the OpenCode binary" "'$SCRIPT' doctor | grep -q 'OpenCode'"
check "OpenCode review accepts a well-formed verdict naming the head" "mode verdict; '$SCRIPT' review --repo '$TMP/repo' --prompt 'check f' 2>/dev/null | grep -q \"VERDICT: APPROVE $HEAD_SHA\""
check "OpenCode keeps exactly one verdict-format instruction in either review profile" "[ \"\$(grep -c '^VERDICT: APPROVE' '$ROOT/config/opencode-stepfun/agent/stepfun-review.md')\" = 1 ] && [ \"\$(grep -c '^VERDICT: APPROVE' '$ROOT/config/opencode-stepfun/agent/stepfun-review-windows.md')\" = 1 ] && ! grep -q '^VERDICT: APPROVE' '$TMP/args.oc.prompt'"
check "OpenCode puts review-specific values after stable instructions" "! sed '/^Review packet:/,\$d' '$TMP/args.oc.prompt' | grep -Eq '[0-9a-f]{40}' && grep -qx 'Exact head SHA for the final verdict: $HEAD_SHA' '$TMP/args.oc.prompt' && tail -n1 '$TMP/args.oc.prompt' | grep -qx 'check f'"
cp "$TMP/args.oc.prompt" "$TMP/first-review.prompt"
mode verdict; "$SCRIPT" review --repo "$TMP/repo" --prompt 'different review request' >/dev/null 2>&1
check "OpenCode review keeps the same stable prefix across prompts" "sed '/^Review packet:/,\$d' '$TMP/first-review.prompt' > '$TMP/first-prefix' && sed '/^Review packet:/,\$d' '$TMP/args.oc.prompt' > '$TMP/second-prefix' && cmp -s '$TMP/first-prefix' '$TMP/second-prefix' && tail -n1 '$TMP/args.oc.prompt' | grep -qx 'different review request'"
rm -f "$TMP/args.oc.n"; mode jsonl429
"$SCRIPT" review --repo "$TMP/repo" --prompt x > "$TMP/jsonl429.out" 2>/dev/null; rc=$?
check "retries-on-jsonl-error-429" "[ $rc = 0 ] && grep -q 'VERDICT: REVISE' '$TMP/jsonl429.out' && [ \"\$(cat '$TMP/args.oc.n')\" = 2 ]"
rm -f "$TMP/args.oc.n"; mode jsonltext429
"$SCRIPT" review --repo "$TMP/repo" --prompt x > "$TMP/jsonltext429.out" 2>/dev/null; rc=$?
check "keeps-jsonl-text-that-quotes-429" "[ $rc = 0 ] && grep -q 'VERDICT: APPROVE' '$TMP/jsonltext429.out' && [ \"\$(cat '$TMP/args.oc.n')\" = 1 ]"
mode verdict
if PATH="$crlf_bin:$PATH" "$SCRIPT" review --repo "$TMP/repo" --prompt 'check f' >"$TMP/crlf-review.out" 2>"$TMP/crlf-review.err" \
  && grep -q "VERDICT: APPROVE $HEAD_SHA" "$TMP/crlf-review.out"; then
  ok crlf_emitting_jq_still_accepts_a_well_formed_verdict
else
  bad crlf_emitting_jq_still_accepts_a_well_formed_verdict
  echo '----- crlf review stdout:'; cat "$TMP/crlf-review.out" 2>/dev/null
  echo '----- crlf review stderr:'; cat "$TMP/crlf-review.err" 2>/dev/null
fi
check "OpenCode review uses the review agent" "grep -qx 'stepfun-review' '$TMP/args.oc'"
check "OpenCode implement uses the implement agent and a remote-less clone" "mode impl; out=\$('$SCRIPT' implement --repo '$TMP/repo' --prompt 'add new.py' 2>&1); wt=\$(printf '%s\n' \"\$out\" | sed -n 's/^CLONE //p'); [ -n \"\$wt\" ] && [ -f \"\$wt/new.py\" ] && [ -z \"\$(git -C \"\$wt\" remote)\" ] && grep -qx 'stepfun-implement' '$TMP/args.oc'"
check "OpenCode ask answers from a disposable copy" "mode askok; '$SCRIPT' ask --repo '$TMP/repo' 'bounded?' 2>/dev/null | grep -q RATE_RETRIES"
check "OpenCode rejects a turn directory that has a remote" "mode ok; git -C '$TMP/repo' remote add origin https://example.com/x.git 2>/dev/null; ! '$SCRIPT' ask --repo '$TMP/repo' x >/dev/null 2>&1; git -C '$TMP/repo' remote remove origin"
  rm -f "$TMP/args.bwrap"
  check "Linux OpenCode turn runs under bubblewrap with an empty home and no host root" "mode askok; '$SCRIPT' ask --repo '$TMP/repo' 'bounded?' 2>/dev/null | grep -q RATE_RETRIES && grep -qx -- '--unshare-all' '$TMP/args.bwrap' && grep -qx -- '--tmpfs' '$TMP/args.bwrap' && grep -qx \"\$HOME\" '$TMP/args.bwrap' && ! grep -A1 -x -- '--ro-bind' '$TMP/args.bwrap' | grep -qx / && ! grep -A1 -x -- '--ro-bind' '$TMP/args.bwrap' | grep -qx /etc"
  check "Linux OpenCode state is a fresh per-run tree: profile read-only, removed after the turn" "grep -A1 -x -- '--ro-bind' '$TMP/args.bwrap' | grep -q '/oc-run\.[^/]*/config\$' && ! ls -d \"\${AI_STEPFUN_STATE_DIR:-\$HOME/.local/state/ai-devops/stepfun}\"/oc-run.* >/dev/null 2>&1"
  check "Linux OpenCode doctor fails without bubblewrap" "! AI_STEPFUN_BWRAP=/nonexistent '$SCRIPT' doctor >/dev/null 2>&1 && '$SCRIPT' doctor | grep -q '^PASS  bubblewrap sandbox'"
fi
unset AI_STEPFUN_ENGINE AI_STEPFUN_OPENCODE AI_STEPFUN_OPENCODE_ROOT

printf '\n%s passed, %s failed, %s skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
