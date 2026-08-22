#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; SCRIPT="$ROOT/bin/ai-run-task"
PASS=0; FAIL=0; ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }; bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }; check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT; R="$TMP/repo"; mkdir -p "$R"; git -C "$R" init -q; git -C "$R" config user.name T; git -C "$R" config user.email t@e
printf '.ai/\n' > "$R/.gitignore"; echo base > "$R/a"; git -C "$R" add .gitignore a; git -C "$R" commit -qm init
STUB="$TMP/model-call"; cat > "$STUB" <<'EOF'
#!/usr/bin/env bash
stage="$1"; prompt="$2"; out="$3"; printf '%s\n' "$stage" >> "$AI_RUN_TEST_LOG"
[ "${AI_RUN_TEST_FAIL_STAGE:-}" != "$stage" ] || exit 7
case "$stage" in implement) echo implemented >> a;; test) echo tested >> a;; esac
case "$stage" in
  plan-review|diff-review|security|final) verdict=APPROVE; [ "${AI_RUN_TEST_REJECT_STAGE:-}" != "$stage" ] || verdict=REJECT; printf '# Review\n\n## Verdict\n%s\n' "$verdict" > "$out";;
  *) printf '# %s output\n\ninput=%s\n' "$stage" "$(sha256sum "$prompt"|cut -d' ' -f1)" > "$out";; esac
EOF
chmod +x "$STUB"; export AI_MODEL_CALL_BIN="$STUB" AI_RUN_TEST_LOG="$TMP/calls"
echo '== ai-run-task'
RUN="$(cd "$R" && "$SCRIPT" start 'Build the exact requested feature')"; MAN="$RUN/manifest.json"
check 'start creates a seven-stage ready manifest' "jq -e '.status==\"ready\" and (.stages|length)==7' '$MAN'"
check 'roles pin Codex work and Claude Opus 5 review' "jq -e '[.stages[].role]|index(\"codex-implementer\")!=null and index(\"claude-opus-5-reviewer\")!=null' '$MAN'"
START_BRANCH="$(git -C "$R" branch --show-current)"
check 'manifest records repository workflow policy' "jq -e --arg branch '$START_BRANCH' '.repository_identity==\"local/repo\" and .repository_workflow==\"feature-branch-pr\" and .starting_branch==\$branch' '$MAN'"
RESULT="$(cd "$R" && "$SCRIPT" run "$RUN")"
check 'all seven stages complete' "jq -e '.status==\"completed\" and all(.stages[];.status==\"completed\")' '$MAN'"
check 'every stage ran exactly once' "[ \"\$(wc -l < '$TMP/calls' | tr -d ' ')\" = 7 ]"
check 'implementation and test source changes survive' "grep -q implemented '$R/a' && grep -q tested '$R/a'"
HASH_OK=1; while IFS=$'\t' read -r f h; do h="${h%$'\r'}"; [ "$(sha256sum "$f"|cut -d' ' -f1)" = "$h" ] || HASH_OK=0; done < <(jq -r '.stages[]|[.output_artifact,.output_sha256]|@tsv' "$MAN")
[ "$HASH_OK" = 1 ] && ok 'every output hash matches exact bytes' || bad 'every output hash matches exact bytes'
jq -e '. as $root | all(range(1;7); . as $i | $root.stages[$i].input_artifact==$root.stages[$i-1].output_artifact and $root.stages[$i].input_sha256==$root.stages[$i-1].output_sha256)' "$MAN" >/dev/null 2>&1 \
  && ok 'each later stage consumes prior named artifact' || bad 'each later stage consumes prior named artifact'
CALLS="$(wc -l < "$TMP/calls")"; cd "$R" && "$SCRIPT" resume "$RUN" >/dev/null
check 'resume is idempotent after completion' "[ '$CALLS' = \"\$(wc -l < '$TMP/calls')\" ]"
cp "$RUN/01-plan.md" "$TMP/plan-save"; echo tampered >> "$RUN/01-plan.md"
check 'changed completed artifact is rejected' "cd '$R' && ! '$SCRIPT' resume '$RUN' >/dev/null 2>&1"
cp "$TMP/plan-save" "$RUN/01-plan.md"

REJECT_RUN="$(cd "$R" && "$SCRIPT" start 'Exercise blocked review')"; : > "$TMP/calls"
check 'non-approve verdict blocks later stages' "cd '$R' && ! AI_RUN_TEST_REJECT_STAGE=plan-review '$SCRIPT' run '$REJECT_RUN' >/dev/null 2>&1"
check 'blocked run records exact verdict' "jq -e '.status==\"blocked\" and .stages[1].status==\"blocked\" and .stages[1].verdict==\"REJECT\" and .stages[2].status==\"pending\"' '$REJECT_RUN/manifest.json'"

STALE_RUN="$(cd "$R" && "$SCRIPT" start 'Exercise stale source')"; echo outside >> "$R/a"
check 'outside source drift blocks before a stage' "cd '$R' && ! '$SCRIPT' run '$STALE_RUN' >/dev/null 2>&1"
check 'outside source drift contacts no model' "[ \"\$(wc -l < '$TMP/calls' | tr -d ' ')\" = 2 ]"
check 'run directory outside .ai is refused' "cd '$R' && ! '$SCRIPT' status '$TMP' >/dev/null 2>&1"
printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
