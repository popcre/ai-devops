#!/usr/bin/env bash
# Offline safety tests. The agy fixture never contacts Google or reads OAuth.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-gemini"; FIXTURES="$ROOT/tests/fixtures/ai-gemini"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/state" "$TMP/copies"

cat > "$TMP/bin/sandbox" <<'EOF'
#!/usr/bin/env bash
set -e
case "$1" in
 ensure-copy) src="$2"; tag="$3"; dst="$MOCK_COPIES/$tag"; cp -a "$src" "$dst"; printf %s "$dst" ;;
 remove-copy) rm -rf "$MOCK_COPIES/$3" ;;
 *) exit 2 ;;
esac
EOF
cat > "$TMP/bin/packet" <<'EOF'
#!/usr/bin/env bash
set -e
case "$1" in
 build) p="$2/.ai-review-$3"; mkdir -p "$p"; printf manifest > "$p/MANIFEST.md"; sha256sum "$p/MANIFEST.md" > "$p/MANIFEST.sha256"; [ "${MOCK_MUTATE_RUNTIME_AFTER_GATE:-0}" = 0 ] || printf '\n# changed after startup gate\n' >> "$AI_GEMINI_BIN"; printf %s "$p" ;;
 verify) test -s "$2/MANIFEST.sha256" ;;
 path) printf %s "$2/.ai-review-$3" ;;
 remove) rm -rf "$2/.ai-review-$3" ;;
 *) exit 2 ;;
esac
EOF
cat > "$TMP/bin/agy" <<'EOF'
#!/usr/bin/env bash
set -e
case "${1:-}" in --version) echo 1.1.14; exit;; --help) echo --sandbox; exit;; models) echo 'gemini-3.7-flash-high'; exit;; esac
printf '%s\n' "$*" >> "$MOCK_AGY_CALLS"
args=" $* "
if [[ "$args" == *" /model "* ]]; then
  [ "${MOCK_MODE:-normal}" = mutate-model ] && printf model-changed > dirty.txt
  cid='conv-good'; [[ "$args" == *"--conversation conv-good"* ]] || cid='wrong-model-conversation'
  model='gemini-3.7-flash-high'; [ "${MOCK_MODE:-normal}" = wrongmodel ] && model='gemini-wrong'
  printf '{"status":"SUCCESS","conversation_id":"%s","command":{"name":"model","data":{"id":"%s","is_default":false}}}\n' "$cid" "$model"
  exit
fi
case "${MOCK_MODE:-normal}" in
 mutate-dirty) printf changed-again > dirty.txt ;;
 mutate-ignored) printf changed > .ignored ;;
 mutate-outside) printf changed > "$MOCK_SENTINEL" ;;
 mutate-protected) printf changed >> "$MOCK_PROTECTED/file.txt" ;;
 mutate-protected-ignored) printf changed >> "$MOCK_PROTECTED/.ignored" ;;
 mutate-protected-tracked-runtime) printf changed >> "$MOCK_PROTECTED/.ai/reviews/tracked.md" ;;
 sleep) sleep 30 ;;
 reclaim-slow) sleep 2 ;;
 fail) exit 70 ;;
esac
cid=conv-good
if [[ "$args" == *"--conversation"* ]] && [ "${MOCK_MODE:-normal}" = wrongid ]; then cid=conv-wrong; fi
if [ "${MOCK_MODE:-normal}" = empty ]; then response=''; elif [ "${MOCK_MODE:-normal}" = badverdict ]; then response='## Verdict
PASS'; else response='## Verdict
APPROVE'; fi
printf '{"status":"SUCCESS","conversation_id":"%s","response":%s}\n' "$cid" "$(printf %s "$response" | jq -Rs .)"
EOF
chmod +x "$TMP/bin/"*
export MOCK_COPIES="$TMP/copies" MOCK_AGY_CALLS="$TMP/agy-calls" AI_GEMINI_BIN="$TMP/bin/agy" AI_REVIEW_SANDBOX_BIN="$TMP/bin/sandbox" AI_REVIEW_PACKET_BIN="$TMP/bin/packet" AI_GEMINI_STATE_DIR="$TMP/state" AI_REVIEW_QUARANTINE_DIR="$TMP/quarantine" AI_GEMINI_CALLER=test
: > "$MOCK_AGY_CALLS"

make_repo(){ local d="$1" ignored="${2:-yes}"; mkdir -p "$d"; git -C "$d" init -q; git -C "$d" config user.email test@example.com; git -C "$d" config user.name test; printf base > "$d/file.txt"; if [ "$ignored" = yes ]; then printf '.ai/\n.ignored\n' > "$d/.gitignore"; else printf '.ignored\n' > "$d/.gitignore"; fi; git -C "$d" add file.txt .gitignore; git -C "$d" commit -qm base; }
new_run(){ local repo="$1" name="$2" mode="${3:-normal}"; (cd "$repo" && MOCK_MODE="$mode" "$SCRIPT" new "$name" --prompt review); }
meta_for(){ find "$TMP/state/sessions" -name "test--$1.json" -print -quit; }

echo '== ai-gemini fixed response contracts'
check 'empty success fixture is rejected' "! jq -e '.status==\"SUCCESS\" and (.response|length>0)' '$FIXTURES/empty-success.json'"
check 'wrong model fixture is rejected' "! jq -e '.command.data.id==\"gemini-3.7-flash-high\"' '$FIXTURES/model-mismatch.json'"
check 'wrapper exposes safety version' "$SCRIPT --version | grep -q '0.2.2'"
mkdir -p "$TMP/fallback-home/.local/bin"
cp "$TMP/bin/agy" "$TMP/fallback-home/.local/bin/agy"
FALLBACK_PATH="/mingw64/bin:/usr/bin:/bin:$(dirname "$(command -v jq)")"
set +e; FALLBACK_OUT="$(HOME="$TMP/fallback-home" AI_GEMINI_BIN= PATH="$FALLBACK_PATH" "$SCRIPT" doctor 2>&1)"; FALLBACK_RC=$?; set -e
check 'doctor finds the official Linux per-user installation outside PATH' "test '$FALLBACK_RC' -eq 3 && printf '%s' '$FALLBACK_OUT' | grep -q 'agy=1.1.14'"
set +e; DOCTOR_OUT="$("$SCRIPT" doctor 2>&1)"; DOCTOR_RC=$?; set -e
check 'doctor keeps Gemini quarantined pending live proof' "test '$DOCTOR_RC' -ne 0 && printf '%s' '$DOCTOR_OUT' | grep -q '^QUARANTINED'"
check 'normal operation cannot bypass quarantine' "! '$SCRIPT' new blocked --prompt review"
check 'missing qualification record causes no provider contact' "test ! -s '$MOCK_AGY_CALLS'"
check 'quarantine exposes only the governed live qualification path without overstating denied-tool proof' "grep -q 'qualify-live' '$SCRIPT' && grep -q 'outside sentinel changed during live qualification' '$SCRIPT' && grep -q 'mutation-request=no-change' '$SCRIPT' && ! grep -q 'hostile-write=no-change' '$SCRIPT'"
check 'provider prompt states the exact allowed verdict words' "grep -q 'Replace APPROVE with REJECT or BLOCKED' '$SCRIPT'"
check 'doctor rejects unknown options instead of overstating a live check' "! '$SCRIPT' doctor --unknown"
cp "$SCRIPT" "$TMP/bin/ai-gemini-test"
chmod +x "$TMP/bin/ai-gemini-test"
SCRIPT="$TMP/bin/ai-gemini-test"
mkdir -p "$AI_REVIEW_QUARANTINE_DIR"
WRAPPER_SHA="$(sha256sum "$SCRIPT" | awk '{print $1}')"; AGY_SHA="$(sha256sum < "$AI_GEMINI_BIN" | awk '{print $1}')"
write_qualification(){ jq -nc --arg sha "$WRAPPER_SHA" --arg agy "${1:-1.1.14}" --arg agy_sha "${3:-$AGY_SHA}" --arg model "${2:-gemini-3.7-flash-high}" '{version:2,provider:"gemini",wrapper_sha256:$sha,agy_version:$agy,agy_sha256:$agy_sha,model:$model,qualified_epoch:1}' > "$AI_REVIEW_QUARANTINE_DIR/gemini-live-qualified.json"; }
write_qualification
check 'valid governed record releases the wrapper gate' "$SCRIPT doctor | grep -q '^PASS'"
RACE_AGY="$TMP/bin/agy-race"; cp "$AI_GEMINI_BIN" "$RACE_AGY"; chmod +x "$RACE_AGY"; RACE_SHA="$(sha256sum < "$RACE_AGY" | awk '{print $1}')"
write_qualification 1.1.14 gemini-3.7-flash-high "$RACE_SHA"
RACE_REPO="$TMP/race-repo"; make_repo "$RACE_REPO"
check 'runtime replacement after startup gate is refused before provider contact' "! (cd '$RACE_REPO' && AI_GEMINI_BIN='$RACE_AGY' MOCK_MUTATE_RUNTIME_AFTER_GATE=1 '$SCRIPT' new runtime-race --prompt review) && test ! -s '$MOCK_AGY_CALLS'"
REAL_SHA256SUM="$(command -v sha256sum)"; mkdir -p "$TMP/race-bin"; printf inventory-trigger > "$RACE_REPO/inventory-race-trigger"
cat > "$TMP/race-bin/sha256sum" <<'EOF'
#!/usr/bin/env bash
case "$*" in *inventory-race-trigger*) if [ ! -e "$MOCK_INVENTORY_RACE_DONE" ]; then printf '\n# changed during inventory\n' >> "$AI_GEMINI_BIN"; : > "$MOCK_INVENTORY_RACE_DONE"; fi;; esac
exec "$REAL_SHA256SUM" "$@"
EOF
chmod +x "$TMP/race-bin/sha256sum"; cp "$TMP/bin/agy" "$RACE_AGY"; RACE_SHA="$(sha256sum < "$RACE_AGY" | awk '{print $1}')"; write_qualification 1.1.14 gemini-3.7-flash-high "$RACE_SHA"; : > "$MOCK_AGY_CALLS"
check 'runtime replacement during inventory is refused before provider contact' "! (cd '$RACE_REPO' && PATH='$TMP/race-bin':\"\$PATH\" REAL_SHA256SUM='$REAL_SHA256SUM' MOCK_INVENTORY_RACE_DONE='$TMP/inventory-race-done' AI_GEMINI_BIN='$RACE_AGY' '$SCRIPT' new inventory-runtime-race --prompt review) && test ! -s '$MOCK_AGY_CALLS'"
write_qualification 1.1.15
check 'agy version drift re-quarantines before provider contact' "! '$SCRIPT' new stale-runtime --prompt review && test ! -s '$MOCK_AGY_CALLS'"
write_qualification 1.1.14 gemini-other
check 'model drift re-quarantines before provider contact' "! '$SCRIPT' new stale-model --prompt review && test ! -s '$MOCK_AGY_CALLS'"
write_qualification 1.1.14 gemini-3.7-flash-high "$(printf '%064d' 0)"
check 'same-version runtime byte drift re-quarantines before provider contact' "! '$SCRIPT' new stale-runtime-bytes --prompt review && test ! -s '$MOCK_AGY_CALLS'"
printf '{"version":2,"provider":"gemini"}\n' > "$AI_REVIEW_QUARANTINE_DIR/gemini-live-qualified.json"
check 'missing qualification fields fail closed before provider contact' "! '$SCRIPT' new malformed --prompt review && test ! -s '$MOCK_AGY_CALLS'"
write_qualification

echo '== byte identity and exact identity gates'
R1="$TMP/repo1"; make_repo "$R1"; printf first-change > "$R1/dirty.txt"
check 'already-dirty file content mutation is rejected' "! new_run '$R1' dirty mutate-dirty"
check 'failed mutation remains recovery-required' "test \"\$(jq -r .status \"\$(meta_for dirty)\")\" = RECOVERY_REQUIRED"
R2="$TMP/repo2"; make_repo "$R2"; printf prior > "$R2/.ignored"
check 'ignored-file mutation is rejected' "! new_run '$R2' ignored mutate-ignored"
R3="$TMP/repo3"; make_repo "$R3"; SENT="$TMP/outside-sentinel"; printf safe > "$SENT"; export MOCK_SENTINEL="$SENT"
check 'outside sentinel mutation is rejected' "! AI_GEMINI_OUTSIDE_SENTINELS='$SENT' new_run '$R3' outside mutate-outside"
R3B="$TMP/repo3b"; make_repo "$R3B"; export MOCK_PROTECTED="$R3B"
check 'same-turn protected tracked-source mutation is rejected' "! new_run '$R3B' protected mutate-protected"
R3C="$TMP/repo3c"; make_repo "$R3C"; export MOCK_PROTECTED="$R3C"
check 'same-turn protected ignored-file mutation is rejected' "! new_run '$R3C' protected-ignored mutate-protected-ignored"
R3D="$TMP/repo3d"; make_repo "$R3D"; mkdir -p "$R3D/.ai/reviews"; printf tracked > "$R3D/.ai/reviews/tracked.md"; git -C "$R3D" add -f .ai/reviews/tracked.md; git -C "$R3D" commit -qm tracked-runtime; export MOCK_PROTECTED="$R3D"
check 'tracked files inside runtime directories remain protected' "! new_run '$R3D' protected-tracked-runtime mutate-protected-tracked-runtime"
R4="$TMP/repo4"; make_repo "$R4"; check 'normal review writes a durable report' "new_run '$R4' good normal && find '$R4/.ai/reviews' -type f -size +0c | grep -q ."
check 'completed state stores exact conversation' "jq -e '.status==\"COMPLETE\" and .conversation_id==\"conv-good\"' \"\$(meta_for good)\""
GOOD_META="$(meta_for good)"; GOOD_COPY="$(jq -r .review_dir "$GOOD_META")"
GOOD_BEFORE="$( { sha256sum "$GOOD_META"; (cd "$R4" && find .ai/reviews -type f -print0 | sort -z | xargs -0 sha256sum); (cd "$GOOD_COPY" && find . -type f -print0 | sort -z | xargs -0 sha256sum); } | sha256sum | cut -d' ' -f1 )"
GOOD_CALLS="$(wc -l < "$MOCK_AGY_CALLS")"
check 'duplicate new is refused' "! new_run '$R4' good normal"
GOOD_AFTER="$( { sha256sum "$GOOD_META"; (cd "$R4" && find .ai/reviews -type f -print0 | sort -z | xargs -0 sha256sum); (cd "$GOOD_COPY" && find . -type f -print0 | sort -z | xargs -0 sha256sum); } | sha256sum | cut -d' ' -f1 )"
check 'duplicate new preserves metadata report packet and private copy byte-for-byte' "test '$GOOD_BEFORE' = '$GOOD_AFTER'"
check 'duplicate new never invokes the provider' "test '$GOOD_CALLS' -eq \"\$(wc -l < '$MOCK_AGY_CALLS')\""
check 'wrong resumed conversation ID is rejected' "! (cd '$R4' && MOCK_MODE=wrongid '$SCRIPT' ask good --prompt follow-up)"
new_run "$R4" frozen-model normal >/dev/null
FROZEN_CALLS="$(wc -l < "$MOCK_AGY_CALLS")"
check 'follow-up refuses configured model drift before provider contact' "! (cd '$R4' && AI_GEMINI_MODEL=gemini-other '$SCRIPT' ask frozen-model --prompt follow-up) && test '$FROZEN_CALLS' -eq \"\$(wc -l < '$MOCK_AGY_CALLS')\""
new_run "$R4" frozen-copy normal >/dev/null
FROZEN_COPY="$(jq -r .review_dir "$(meta_for frozen-copy)")"; printf tampered > "$FROZEN_COPY/between-turns.txt"
COPY_CALLS="$(wc -l < "$MOCK_AGY_CALLS")"
check 'follow-up refuses between-turn private-copy tampering before provider contact' "! (cd '$R4' && '$SCRIPT' ask frozen-copy --prompt follow-up) && test '$COPY_CALLS' -eq \"\$(wc -l < '$MOCK_AGY_CALLS')\""
check 'private-copy tampering remains recovery-required' "test \"\$(jq -r .status \"\$(meta_for frozen-copy)\")\" = RECOVERY_REQUIRED"
check 'wrong model is rejected' "! new_run '$R4' wrongmodel wrongmodel"
printf before-model > "$R4/dirty.txt"
check 'write during model verification is rejected' "! new_run '$R4' modelwrite mutate-model"
check 'empty response is rejected' "! new_run '$R4' empty empty"
check 'invalid verdict word is rejected' "! new_run '$R4' badverdict badverdict"
BAD_META="$(meta_for badverdict)"
check 'rejected provider output is durably linked from session state' "jq -e '.failure_stage==\"turn\" and (.failure_artifact|length>0)' '$BAD_META' && test -s \"\$(jq -r .failure_artifact '$BAD_META')\""
if case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) true;; *) false;; esac; then
check 'preserved failure evidence uses a private Windows ACL' "icacls \"\$(cygpath -w \"\$(jq -r .failure_artifact '$BAD_META')\")\" | grep -Fqi \"$USERNAME:(F)\""
else
  check 'preserved failure evidence is private' "test \"\$(stat -c %a \"\$(jq -r .failure_artifact '$BAD_META')\")\" = 600"
fi
mkdir -p "$TMP/fail-bin"; printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/fail-bin/chmod"; /usr/bin/chmod +x "$TMP/fail-bin/chmod"
FAILURE_FILES_BEFORE="$(find "$TMP/state/failures" -type f 2>/dev/null | wc -l)"
check 'privacy-control failure rejects output without leaving a readable artifact' "! PATH='$TMP/fail-bin:$PATH' new_run '$R4' privacy-fail badverdict; meta=\$(meta_for privacy-fail); test \"\$(jq -r '.failure_artifact // empty' \"\$meta\")\" = '' && test '$FAILURE_FILES_BEFORE' -eq \"\$(find '$TMP/state/failures' -type f 2>/dev/null | wc -l)\""

echo '== lifecycle, concurrency, report, and head gates'
R5="$TMP/repo5"; make_repo "$R5" no
check 'unsafe report destination makes the review fail' "! new_run '$R5' report normal"
check 'report failure remains recovery-required' "test \"\$(jq -r .status \"\$(meta_for report)\")\" = RECOVERY_REQUIRED"
R5B="$TMP/repo5b"; make_repo "$R5B"; R5B_ID="$(printf '%s\n%s' "$(cd "$R5B" && pwd -P)" "$(git -C "$R5B" config --get remote.origin.url 2>/dev/null || true)" | sha256sum | cut -c1-12)"; mkdir -p "$TMP/state/locks/repo-$R5B_ID"; printf '99999999\n' > "$TMP/state/locks/repo-$R5B_ID/owner"
check 'dead local lock owner is safely reclaimed' "new_run '$R5B' stale-owner normal"
R5C="$TMP/repo5c"; make_repo "$R5C"; R5C_ID="$(printf '%s\n%s' "$(cd "$R5C" && pwd -P)" "$(git -C "$R5C" config --get remote.origin.url 2>/dev/null || true)" | sha256sum | cut -c1-12)"; mkdir -p "$TMP/state/locks/repo-$R5C_ID"; printf '99999999\n' > "$TMP/state/locks/repo-$R5C_ID/owner"
(new_run "$R5C" reclaim-a reclaim-slow >/dev/null 2>&1) & RECLAIM_A=$!; (new_run "$R5C" reclaim-b reclaim-slow >/dev/null 2>&1) & RECLAIM_B=$!; RA=0; RB=0; wait "$RECLAIM_A" || RA=$?; wait "$RECLAIM_B" || RB=$?
check 'concurrent stale-lock reclaimers cannot both enter a review' "test \$(( (RA == 0) + (RB == 0) )) -eq 1"
R6="$TMP/repo6"; make_repo "$R6"
(cd "$R6" && exec env MOCK_MODE=sleep "$SCRIPT" new concurrent --prompt wait) >/dev/null 2>&1 & RUNPID=$!
for _ in $(seq 1 100); do [ -n "$(meta_for concurrent 2>/dev/null || true)" ] && break; sleep .05; done
CONCURRENT_COPY="$(jq -r .review_dir "$(meta_for concurrent)")"; printf owner-evidence > "$CONCURRENT_COPY/concurrency-owner"
check 'concurrent new is refused before touching evidence' "! (cd '$R6' && '$SCRIPT' new concurrent --prompt collide) && grep -qx owner-evidence '$CONCURRENT_COPY/concurrency-owner'"
check 'concurrent delete is refused while review runs' "! (cd '$R6' && '$SCRIPT' delete concurrent)"
check 'concurrent follow-up is refused while review runs' "! (cd '$R6' && '$SCRIPT' ask concurrent --prompt collide)"
kill -TERM "$RUNPID" 2>/dev/null || true; RUNRC=0; wait "$RUNPID" 2>/dev/null || RUNRC=$?
check 'interrupted review returns failure' "test '$RUNRC' -ne 0"
check 'interrupted work is marked for recovery' "test \"\$(jq -r .status \"\$(meta_for concurrent)\")\" = RECOVERY_REQUIRED"
check 'interrupted private copy is preserved' "test -d \"\$(jq -r .review_dir \"\$(meta_for concurrent)\")\""
R7="$TMP/repo7"; make_repo "$R7"; new_run "$R7" stale normal >/dev/null; printf next >> "$R7/file.txt"; git -C "$R7" add file.txt; git -C "$R7" commit -qm next
check 'follow-up refuses a changed repository head' "! (cd '$R7' && '$SCRIPT' ask stale --prompt later)"
check 'stale-head refusal becomes recovery-required' "test \"\$(jq -r .status \"\$(meta_for stale)\")\" = RECOVERY_REQUIRED"
check 'delete refuses uncertain evidence' "! (cd '$R7' && '$SCRIPT' delete stale)"

R8="$TMP/repo8"; make_repo "$R8"; new_run "$R8" source-tracked normal >/dev/null; printf changed >> "$R8/file.txt"; SOURCE_CALLS="$(wc -l < "$MOCK_AGY_CALLS")"
check 'follow-up refuses uncommitted tracked source drift' "! (cd '$R8' && '$SCRIPT' ask source-tracked --prompt later) && test '$SOURCE_CALLS' -eq \"\$(wc -l < '$MOCK_AGY_CALLS')\""
R9="$TMP/repo9"; make_repo "$R9"; new_run "$R9" source-untracked normal >/dev/null; printf new > "$R9/untracked.txt"; SOURCE_CALLS="$(wc -l < "$MOCK_AGY_CALLS")"
check 'follow-up refuses untracked source drift' "! (cd '$R9' && '$SCRIPT' ask source-untracked --prompt later) && test '$SOURCE_CALLS' -eq \"\$(wc -l < '$MOCK_AGY_CALLS')\""
R10="$TMP/repo10"; make_repo "$R10"; new_run "$R10" source-ignored normal >/dev/null; printf ignored > "$R10/.ignored"; SOURCE_CALLS="$(wc -l < "$MOCK_AGY_CALLS")"
check 'follow-up refuses ignored protected-source drift' "! (cd '$R10' && '$SCRIPT' ask source-ignored --prompt later) && test '$SOURCE_CALLS' -eq \"\$(wc -l < '$MOCK_AGY_CALLS')\""
R11="$TMP/repo11"; make_repo "$R11"; new_run "$R11" source-runtime normal >/dev/null; mkdir -p "$R11/.ai/reviews" "$R11/.ai/test-runs" "$R11/.ai/qwen-test.123"; printf report > "$R11/.ai/reviews/other-review.md"; printf log > "$R11/.ai/test-runs/test.log"; printf runtime > "$R11/.ai/qwen-test.123/state"
check 'wrapper-owned .ai runtime evidence does not create false source drift' "cd '$R11' && '$SCRIPT' ask source-runtime --prompt later"
SUBSOURCE="$TMP/subsource"; make_repo "$SUBSOURCE"; SUBPARENT="$TMP/subparent"; make_repo "$SUBPARENT"; git -C "$SUBPARENT" -c protocol.file.allow=always submodule add -q "$SUBSOURCE" module; git -C "$SUBPARENT" commit -qam gitlink; new_run "$SUBPARENT" source-gitlink normal >/dev/null; printf changed >> "$SUBPARENT/module/file.txt"; SOURCE_CALLS="$(wc -l < "$MOCK_AGY_CALLS")"
check 'initialized gitlink content drift is fingerprinted before provider contact' "! (cd '$SUBPARENT' && '$SCRIPT' ask source-gitlink --prompt later) && test '$SOURCE_CALLS' -eq \"\$(wc -l < '$MOCK_AGY_CALLS')\""


# ai-review-sandbox rejects a tag over 64 characters. The tag is
# "gemini-<12>-<caller>-<name>", so a name that fits on Windows can overflow on
# Linux, where PIDs are wider. On 2026-08-24 the Ubuntu qualification failed that
# way AFTER its paid turn. The guard must refuse before any provider contact.
LONGREPO="$TMP/longname"; make_repo "$LONGREPO"
LONG_NAME="$(printf %.0sx $(seq 1 60))"
LONG_CALLS="$(wc -l < "$MOCK_AGY_CALLS")"
check 'an over-long review name is refused before any provider contact' "! (cd '$LONGREPO' && '$SCRIPT' new '$LONG_NAME' --prompt x) && test '$LONG_CALLS' -eq \"\$(wc -l < '$MOCK_AGY_CALLS')\""
LONG_OUT="$TMP/longname.out"; (cd "$LONGREPO" && "$SCRIPT" new "$LONG_NAME" --prompt x) > "$LONG_OUT" 2>&1 || true
check 'the refusal names the limit so the caller can shorten the name' "grep -q 'limit is 64' '$LONG_OUT'"
check 'a name that fits is still accepted' "(cd '$LONGREPO' && '$SCRIPT' new fits-fine --prompt x)"
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
