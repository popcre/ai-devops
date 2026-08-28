#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; SCRIPT="$ROOT/bin/ai-deepseek-agent"
PASS=0; FAIL=0; SKIP=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }; bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

# Timing budgets are measured, not guessed: a constant that is generous on an
# idle CI runner is a lost race on a loaded developer box. See fix_test_ai.md
# and tests/lib-test-timing.sh.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-timing.sh"
ai_test_measure_spawn_baseline
# A case the filesystem cannot host is not a passing check.
skip() { printf '  skip %s\n' "$1"; SKIP=$((SKIP+1)); }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export AI_DEEPSEEK_TEST_DIR="$TMP"
mkdir -p "$TMP/bin" "$TMP/home/.config/ai-devops" "$TMP/repo"
git -C "$TMP/repo" init -q; git -C "$TMP/repo" config user.email test@example.com; git -C "$TMP/repo" config user.name Test
printf 'test\n' > "$TMP/repo/tracked"; git -C "$TMP/repo" add tracked; git -C "$TMP/repo" commit -qm init
printf 'placeholder-token\n' > "$TMP/home/.config/ai-devops/op-service-account"
printf 'DEEPSEEK_API_KEY=op://example\nUNRELATED_SECRET=op://must-not-resolve\n' > "$TMP/home/.config/ai-devops/mcp.env"
cat > "$TMP/bin/op" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$DEEPSEEK_TEST_ARGS"
while [ "$#" -gt 0 ]; do case "$1" in --env-file) cp "$2" "$DEEPSEEK_TEST_ENV_FILE"; break;; *) shift;; esac; done
STUB
cat > "$TMP/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$DEEPSEEK_CURL_ARGS"
env | sort > "$DEEPSEEK_CURL_ENV"
out=""; while [ "$#" -gt 0 ]; do case "$1" in -o) out="$2"; shift 2;; *) shift;; esac; done
[ -z "${DEEPSEEK_STUB_DELAY:-}" ] || {
  printf '%s\n' "$$" > "$DEEPSEEK_STUB_PID_FILE"
  trap 'printf terminated > "$DEEPSEEK_STUB_TERM_MARKER"; exit 143' TERM
  sleep "$DEEPSEEK_STUB_DELAY"
}
if [ "${DEEPSEEK_STUB_FAIL:-0}" = 1 ]; then printf '{"error":"stub"}' > "$out"; printf 500; else python -c 'import json,os,sys; json.dump({"choices":[{"message":{"content":os.environ.get("DEEPSEEK_STUB_REPLY","answer")}}]},open(sys.argv[1],"w"))' "$out"; printf 200; fi
STUB
chmod +x "$TMP/bin/op" "$TMP/bin/curl"
export DEEPSEEK_CURL_ARGS="$TMP/curl-args" DEEPSEEK_CURL_ENV="$TMP/curl-env" DEEPSEEK_STUB_PID_FILE="$TMP/curl-pid" DEEPSEEK_STUB_TERM_MARKER="$TMP/curl-terminated"
: > "$DEEPSEEK_CURL_ARGS"
echo 'ai-deepseek-agent tests'
HOME="$TMP/home" PATH="$TMP/bin:$PATH" DEEPSEEK_TEST_ARGS="$TMP/args" DEEPSEEK_TEST_ENV_FILE="$TMP/op-env" bash "$SCRIPT" send test >/dev/null 2>&1
check "1Password re-exec was attempted" "grep -qx run '$TMP/args'"
mkdir -p "$TMP/untrusted-test-root"
check "credential resolution rejects an executable outside its trusted installation or test root" "! HOME='$TMP/home' PATH='$TMP/bin:$PATH' AI_DEEPSEEK_TEST_DIR='$TMP/untrusted-test-root' bash '$SCRIPT' send trust-check"
OP_ARGS_BEFORE="$(sha256sum "$TMP/args" | cut -d' ' -f1)"
check "provider endpoint override is rejected before credential resolution" "! HOME='$TMP/home' PATH='$TMP/bin:$PATH' DEEPSEEK_BASE_URL='https://attacker.invalid' bash '$SCRIPT' send endpoint-check && test '$OP_ARGS_BEFORE' = \"\$(sha256sum '$TMP/args' | cut -d' ' -f1)\""
check "managed re-exec resolves only the DeepSeek reference behind an empty-environment boundary" "test \"\$(wc -l < '$TMP/op-env')\" -eq 1 && grep -q '^DEEPSEEK_API_KEY=op://' '$TMP/op-env' && grep -q '/usr/bin/env -i' '$SCRIPT'"
check "managed re-exec keeps the DeepSeek key out of process arguments" "grep -q 'AI_DEEPSEEK_SECRET_FD=9' '$SCRIPT' && ! grep -q '\"DEEPSEEK_API_KEY=\$keep_key\"' '$SCRIPT'"
FD_HANDOFF_OUT="$(exec 9<<<'fd-managed-key'; cd "$TMP/repo" && /usr/bin/env -i HOME="$TMP/home" PATH="$TMP/bin:$PATH" AI_DEEPSEEK_TEST_DIR="$TMP" AI_DEEPSEEK_SECRET_FD=9 DEEPSEEK_STUB_REPLY=DEEPSEEK_REVIEWER_HEALTHY DEEPSEEK_CURL_ARGS="$DEEPSEEK_CURL_ARGS" DEEPSEEK_CURL_ENV="$DEEPSEEK_CURL_ENV" DEEPSEEK_STUB_PID_FILE="$DEEPSEEK_STUB_PID_FILE" DEEPSEEK_STUB_TERM_MARKER="$DEEPSEEK_STUB_TERM_MARKER" "$SCRIPT" doctor --live 9<&9)"
check "managed descriptor handoff delivers the key without exporting it to curl" "printf '%s\n' '$FD_HANDOFF_OUT' | grep -q 'live provider response' && ! grep -q '^DEEPSEEK_API_KEY=' '$DEEPSEEK_CURL_ENV'"
if [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* ]]; then check "Windows re-exec uses explicit Git Bash" "grep -Eqi 'Git.*bash.exe$' '$TMP/args'"; else check "POSIX re-exec keeps script path" "grep -q ai-deepseek-agent '$TMP/args'"; fi
check "help succeeds" "bash '$SCRIPT' --help"; check "unknown command fails" "! bash '$SCRIPT' unknown"
run(){ (cd "$TMP/repo" && HOME="$TMP/home" PATH="$TMP/bin:$PATH" DEEPSEEK_API_KEY=test "$SCRIPT" "$@"); }
DOCTOR_STATE_BEFORE="$(git -C "$TMP/repo" status --porcelain=v1 --untracked-files=all)"
check "offline doctor succeeds without provider contact" "run doctor | grep -q 'bounded provider timeout'"
check "offline doctor leaves the repository byte state unchanged" "test '$DOCTOR_STATE_BEFORE' = \"\$(git -C '$TMP/repo' status --porcelain=v1 --untracked-files=all)\" && test ! -e '$TMP/repo/.ai/deepseek-sessions'"
check "live doctor proves exact provider response" "DEEPSEEK_STUB_REPLY=DEEPSEEK_REVIEWER_HEALTHY run doctor --live | grep -q 'live provider response'"
check "live doctor leaves the repository byte state unchanged" "test '$DOCTOR_STATE_BEFORE' = \"\$(git -C '$TMP/repo' status --porcelain=v1 --untracked-files=all)\" && test ! -e '$TMP/repo/.ai/deepseek-sessions'"
check "doctor rejects unknown options" "! run doctor --unknown"
check "zero provider timeout is rejected before contact" "calls=\$(wc -l < '$DEEPSEEK_CURL_ARGS'); ! AI_DEEPSEEK_CALL_TIMEOUT=0 run doctor --live; test \"\$calls\" -eq \"\$(wc -l < '$DEEPSEEK_CURL_ARGS')\""
check "nonnumeric connect timeout is rejected before contact" "calls=\$(wc -l < '$DEEPSEEK_CURL_ARGS'); ! AI_DEEPSEEK_CONNECT_TIMEOUT=nope run doctor --live; test \"\$calls\" -eq \"\$(wc -l < '$DEEPSEEK_CURL_ARGS')\""
SESSION="$(run send first | sed -n 's/^SESSION_ID: //p')"
check "send creates a safe session" "test -n '$SESSION' -a -f '$TMP/repo/.ai/deepseek-sessions/$SESSION.json'"
check "show reads stored session" "run show '$SESSION' | grep -q answer"
check "provider calls have connection and total time limits" "grep -q -- '--connect-timeout 15 --max-time 300' '$DEEPSEEK_CURL_ARGS'"
check "provider key never appears in curl process arguments or a temporary header file" "! grep -q 'Bearer test' '$DEEPSEEK_CURL_ARGS' && grep -q -- '-H @-' '$DEEPSEEK_CURL_ARGS' && ! grep -q 'header_file' '$SCRIPT'"
check "provider key is removed from child-process environments" "! grep -q '^DEEPSEEK_API_KEY=' '$DEEPSEEK_CURL_ENV' && grep -q 'unset DEEPSEEK_API_KEY' '$SCRIPT'"
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
rm -f "$DEEPSEEK_STUB_PID_FILE" "$DEEPSEEK_STUB_TERM_MARKER"
(cd "$TMP/repo" && exec env HOME="$TMP/home" PATH="$TMP/bin:$PATH" DEEPSEEK_API_KEY=test DEEPSEEK_STUB_DELAY=5 "$SCRIPT" reply "$SESSION" interrupted) >/dev/null 2>&1 & signal_pid=$!
for _ in $(seq 1 "$(scale_ticks 100)"); do [ -d "$history.lock" ] && [ -s "$DEEPSEEK_STUB_PID_FILE" ] && break; sleep .05; done
kill -TERM "$signal_pid" 2>/dev/null || true; signal_rc=0; wait "$signal_pid" 2>/dev/null || signal_rc=$?
check "interrupted reply exits nonzero and does not resume after lock release" "test '$signal_rc' -ne 0 && test '$history_before_signal' = \"\$(sha256sum '$history'|cut -d' ' -f1)\""
provider_pid="$(cat "$DEEPSEEK_STUB_PID_FILE" 2>/dev/null || echo 0)"
check "interrupted reply stops its provider child before unlocking" "test -f '$DEEPSEEK_STUB_TERM_MARKER' && ! kill -0 '$provider_pid' 2>/dev/null"
check "interrupted reply releases its owned lock" "test ! -d '$history.lock'"
mkdir -p "$TMP/not-a-repo"
calls_before_nonrepo="$(wc -l < "$DEEPSEEK_CURL_ARGS")"
(cd "$TMP/not-a-repo" && HOME="$TMP/home" PATH="$TMP/bin:$PATH" DEEPSEEK_API_KEY=test DEEPSEEK_STUB_REPLY=$'## Verdict\nAPPROVE' "$SCRIPT" send no-head --review) >/dev/null 2>&1; nonrepo_rc=$?
check "formal review refuses a missing Git commit before provider contact" "test '$nonrepo_rc' -ne 0 && test '$calls_before_nonrepo' -eq \"\$(wc -l < '$DEEPSEEK_CURL_ARGS')\""
DEEPSEEK_STUB_REPLY='no verdict' run send review-me --review >/dev/null 2>&1; missing_rc=$?
check "review mode rejects missing verdict" "test '$missing_rc' -ne 0"
REVIEW_OUT="$(DEEPSEEK_STUB_REPLY=$'findings\n## Verdict\nAPPROVE' run send review-me --review)"; REVIEW_ID="$(printf '%s\n' "$REVIEW_OUT"|sed -n 's/^SESSION_ID: //p')"
check "review mode accepts usable verdict" "test -n '$REVIEW_ID'"
METADATA_FAILURE_OUT="$(AI_DEEPSEEK_TEST_METADATA_FAILURE=publish DEEPSEEK_STUB_REPLY=$'findings\n## Verdict\nAPPROVE' run send metadata-failure --review 2>&1)"; METADATA_FAILURE_RC=$?
set -e
check "real metadata publication failure is not masked by cleanup" "test '$METADATA_FAILURE_RC' -ne 0 && ! printf '%s' '$METADATA_FAILURE_OUT' | grep -q '^SESSION_ID:'"
set +e
TRANSCRIPT_FAILURE_OUT="$(AI_DEEPSEEK_TEST_TRANSCRIPT_FAILURE=publish DEEPSEEK_STUB_REPLY=$'findings\n## Verdict\nAPPROVE' run send transcript-failure --review 2>&1)"; TRANSCRIPT_FAILURE_RC=$?
set -e
check "real transcript publication failure is not masked by cleanup" "test '$TRANSCRIPT_FAILURE_RC' -ne 0 && ! printf '%s' '$TRANSCRIPT_FAILURE_OUT' | grep -q '^SESSION_ID:'"
check "review metadata binds exact session/head/caller" "jq -e --arg s '$REVIEW_ID' --arg h \"\$(git -C '$TMP/repo' rev-parse HEAD)\" '.provider==\"deepseek\" and .session_id==\$s and .head==\$h and .caller==\"unknown\" and .verdict==\"APPROVE\" and .status==\"complete\"' '$TMP/repo/.ai/deepseek-sessions/$REVIEW_ID.meta.json'"
check "transcript failure publishes no completion metadata" "test -z \"\$(find '$TMP/repo/.ai/deepseek-sessions' -type f -name '*.meta.json' -newer '$TMP/repo/.ai/deepseek-sessions/$REVIEW_ID.meta.json' -print -quit)\""
# DeepSeek reviews through a text-only API with no repository access. Without an
# explicit evidence boundary it reports files it was never shown as "absent" and
# the durable metadata makes that read as an exact-source finding (2026-08-24,
# issue #62). These bind the boundary, the honest metadata, and repeatable --file.
printf 'alpha-evidence
' > "$TMP/repo/evidence-one.md"
printf 'beta-evidence
'  > "$TMP/repo/evidence-two.md"
BOUND_OUT="$(DEEPSEEK_STUB_REPLY=$'findings
## Verdict
BLOCKED' run send bounded-review --review --file evidence-one.md --file evidence-two.md)"
BOUND_ID="$(printf '%s
' "$BOUND_OUT"|sed -n 's/^SESSION_ID: //p')"
BOUND_MSG="$TMP/bound-msg.txt"
jq -r '[.[]|select(.role=="user")]|last|.content' "$TMP/repo/.ai/deepseek-sessions/$BOUND_ID.json" > "$BOUND_MSG" 2>/dev/null || : > "$BOUND_MSG"
check "a review tells the model it has no repository access"   "grep -q 'You have NO access to this repository' '$BOUND_MSG'"
check "a review forbids asserting presence or absence of unquoted evidence"   "grep -q 'Absence from this conversation is NOT evidence of absence' '$BOUND_MSG' && grep -q 'return BLOCKED instead of inferring it' '$BOUND_MSG'"
check "a review still demands the terminal verdict heading"   "grep -q 'literal ## Verdict heading' '$BOUND_MSG'"
check "repeated --file attaches every evidence file, not just the last"   "grep -q 'alpha-evidence' '$BOUND_MSG' && grep -q 'beta-evidence' '$BOUND_MSG'"
check "review metadata records the evidence scope instead of implying repository inspection"   "jq -e '.evidence_scope==\"attached-materials-only\" and .repository_access==false and (.attached_files|length)==2 and .schema_version==2' '$TMP/repo/.ai/deepseek-sessions/$BOUND_ID.meta.json'"
# A reply resends the whole conversation, so files attached on an earlier turn are
# still in front of DeepSeek. Recording only the latest turn understated the
# evidence behind a continued review verdict (2026-08-24 independent review).
printf 'gamma-evidence
' > "$TMP/repo/evidence-three.md"
CONT_OUT="$(DEEPSEEK_STUB_REPLY=$'first
## Verdict
APPROVE' run send continued-review --review --file evidence-one.md)"
CONT_ID="$(printf '%s
' "$CONT_OUT"|sed -n 's/^SESSION_ID: //p')"
DEEPSEEK_STUB_REPLY=$'more
## Verdict
APPROVE' run reply "$CONT_ID" "continue" --review --file evidence-three.md >/dev/null 2>&1
CONT_META="$TMP/repo/.ai/deepseek-sessions/$CONT_ID.meta.json"
check "a continued review records every file attached across the conversation" "jq -e '(.attached_files|index(\"evidence-one.md\")!=null) and (.attached_files|index(\"evidence-three.md\")!=null)' '$CONT_META'"
check "a continued review still distinguishes this turn attachments" "jq -e '.attached_files_this_turn==[\"evidence-three.md\"]' '$CONT_META'"
check "the attachment ledger is not mistaken for a conversation by list" "! run list | grep -q attachments"
# A path may legally contain spaces or newlines. A line-based ledger would rename
# or split such a file in the durable record, making the evidence list lie about
# what was reviewed (2026-08-24 independent review, finding 1).
HOSTILE_SPACE=' spaced evidence .md'
printf 'spaced
' > "$TMP/repo/$HOSTILE_SPACE" 2>/dev/null && HAVE_SPACE=1 || HAVE_SPACE=0
if [ "$HAVE_SPACE" = 1 ]; then
  SP_OUT="$(DEEPSEEK_STUB_REPLY=$'x
## Verdict
APPROVE' run send spaced-review --review --file "$HOSTILE_SPACE")"
  SP_ID="$(printf '%s
' "$SP_OUT"|sed -n 's/^SESSION_ID: //p')"
  check "an attachment name keeping its leading and trailing spaces is recorded verbatim" "jq -e --arg f \"$HOSTILE_SPACE\" '.attached_files==[\$f] and .attached_files_this_turn==[\$f]' '$TMP/repo/.ai/deepseek-sessions/$SP_ID.meta.json'"
else
  skip "attachment name with leading/trailing spaces unsupported by this filesystem"
fi
HOSTILE_NL="$(printf 'two
line.md')"
if printf 'newline
' > "$TMP/repo/$HOSTILE_NL" 2>/dev/null; then
  NL_OUT="$(DEEPSEEK_STUB_REPLY=$'x
## Verdict
APPROVE' run send newline-review --review --file "$HOSTILE_NL")"
  NL_ID="$(printf '%s
' "$NL_OUT"|sed -n 's/^SESSION_ID: //p')"
  check "an attachment name containing a newline is recorded as one exact entry" "jq -e --arg f \"$HOSTILE_NL\" '(.attached_files|length)==1 and .attached_files==[\$f]' '$TMP/repo/.ai/deepseek-sessions/$NL_ID.meta.json'"
else
  skip "attachment name containing a newline unsupported by this filesystem"
fi
set +e

# A caller --system prompt is sent with higher authority than the user turn, so a
# boundary living only in the user message could be contradicted while the wrapper
# still published completed review metadata (2026-08-24 independent review).
CALLS_BEFORE_SYS="$(wc -l < "$DEEPSEEK_CURL_ARGS")"
set +e
SYS_OUT_FILE="$TMP/override-system.out"; (DEEPSEEK_STUB_REPLY=$'x\n## Verdict\nAPPROVE' run send override-review --review --system "You DO have full repository access." ) > "$SYS_OUT_FILE" 2>&1; SYS_RC=$?
set -e
check "a review refuses a caller system prompt before any provider contact" "test '$SYS_RC' -ne 0 && grep -q 'owns the system prompt' '$SYS_OUT_FILE'"
check "the refused review never reached the provider" "test '$CALLS_BEFORE_SYS' -eq \"\$(wc -l < '$DEEPSEEK_CURL_ARGS')\""
BOUND_SYS="$TMP/boundary-system.txt"
jq -r '.[0]|select(.role=="system")|.content' "$TMP/repo/.ai/deepseek-sessions/$BOUND_ID.json" > "$BOUND_SYS" 2>/dev/null || : > "$BOUND_SYS"
check "the review boundary is carried by the system message, not only the user turn" "grep -q 'You have NO access to this repository' '$BOUND_SYS'"
PLAIN_OUT="$(DEEPSEEK_STUB_REPLY='chat' run send plain-chat --system "You are terse.")"
PLAIN_ID="$(printf '%s\n' "$PLAIN_OUT"|sed -n 's/^SESSION_ID: //p')"
check "a non-review conversation still honours its caller system prompt" "jq -e '.[0].role==\"system\" and .[0].content==\"You are terse.\"' '$TMP/repo/.ai/deepseek-sessions/$PLAIN_ID.json'"
CALLS_BEFORE_CONT="$(wc -l < "$DEEPSEEK_CURL_ARGS")"
set +e
CONTBAD_FILE="$TMP/override-continue.out"; (DEEPSEEK_STUB_REPLY=$'x\n## Verdict\nAPPROVE' run reply "$PLAIN_ID" "now review" --review ) > "$CONTBAD_FILE" 2>&1; CONTBAD_RC=$?
set -e
check "a review cannot be continued in a conversation that never carried the boundary" "test '$CONTBAD_RC' -ne 0 && grep -q 'not started as a formal review' '$CONTBAD_FILE'"
check "the refused continuation never reached the provider" "test '$CALLS_BEFORE_CONT' -eq \"\$(wc -l < '$DEEPSEEK_CURL_ARGS')\""

# The transcript is published before the ledger is appended. A ledger failure
# would otherwise leave a saved turn whose attachments never reach the durable
# record, so a later review would understate its own evidence (2026-08-24
# independent review). The session must become unusable instead.
LEDGER_OUT="$TMP/ledger-failure.out"
LEDGER_START="$(DEEPSEEK_STUB_REPLY=$'a\n## Verdict\nAPPROVE' run send ledger-fail --review --file evidence-one.md)"
LEDGER_ID="$(printf '%s\n' "$LEDGER_START"|sed -n 's/^SESSION_ID: //p')"
set +e
(AI_DEEPSEEK_TEST_LEDGER_FAILURE=publish DEEPSEEK_STUB_REPLY=$'b\n## Verdict\nAPPROVE' run reply "$LEDGER_ID" more --review --file evidence-two.md) > "$LEDGER_OUT" 2>&1; LEDGER_RC=$?
set -e
check "a failed attachment-ledger write is nonzero and names the recovery state" "test '$LEDGER_RC' -ne 0 && grep -q 'recovery-required' '$LEDGER_OUT'"
check "a failed attachment-ledger write marks the session recovery-required" "test -f '$TMP/repo/.ai/deepseek-sessions/$LEDGER_ID.recovery-required'"
LEDGER_CALLS="$(wc -l < "$DEEPSEEK_CURL_ARGS")"
LEDGER_CONT="$TMP/ledger-continue.out"
set +e
(DEEPSEEK_STUB_REPLY=$'c\n## Verdict\nAPPROVE' run reply "$LEDGER_ID" again --review) > "$LEDGER_CONT" 2>&1; LEDGER_CONT_RC=$?
set -e
check "a recovery-required session refuses continuation before any provider contact" "test '$LEDGER_CONT_RC' -ne 0 && test '$LEDGER_CALLS' -eq \"\$(wc -l < '$DEEPSEEK_CURL_ARGS')\" && grep -q 'would understate what DeepSeek saw' '$LEDGER_CONT'"
check "the recovery marker is not mistaken for a conversation by list" "! run list | grep -q recovery-required"
check "list excludes metadata sidecars" "test \"\$(run list|grep -c meta||true)\" -eq 0"
check "shell syntax is valid" "bash -n '$SCRIPT'"
printf 'passed %d, failed %d, skipped %d\n' "$PASS" "$FAIL" "$SKIP"; [ "$FAIL" -eq 0 ]
