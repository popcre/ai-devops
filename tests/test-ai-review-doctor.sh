#!/usr/bin/env bash
# Offline tests for `ai-review doctor`: it must report the rotation pool
# (not just the Claude/Codex approval-gate helpers) so a session never
# reads a gate helper as a drawable reviewer.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-review"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Stub preflight: mixed membership rows. codex is registered but lives in
# config/reviewer-membership-scope.json; kimi is absent from the registry.
cat > "$TMP/preflight" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = status ] || exit 2
printf '%s\n' \
  '{"provider":"muse","status":"installed-healthy","registry_state":"registered","usable":true}' \
  '{"provider":"grok","status":"installed-healthy","registry_state":"registered","usable":true}' \
  '{"provider":"kimi","status":"installed-healthy","registry_state":"absent","usable":false}' \
  '{"provider":"codex","status":"installed-healthy","registry_state":"registered","usable":true}' \
  '{"provider":"claude","status":"installed-healthy","registry_state":"absent","usable":false}'
EOF
cat > "$TMP/claude-gate" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = doctor ] || exit 2
[ "${MOCK_CLAUDE_GATE_FAIL:-0}" = 0 ] || { printf 'claude gate broken\n' >&2; exit 1; }
printf 'PASS provider=claude model=claude-opus-5\n'
EOF
cat > "$TMP/codex-gate" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = doctor ] || exit 2
printf 'PASS provider=codex sandbox=read-only\n'
EOF
cat > "$TMP/preflight-fail" <<'EOF'
#!/usr/bin/env bash
printf 'preflight exploded\n' >&2
exit 9
EOF
chmod +x "$TMP/preflight" "$TMP/claude-gate" "$TMP/codex-gate" "$TMP/preflight-fail"

run_doctor() { # extra env is passed by the caller
  env AI_REVIEW_PREFLIGHT_BIN="$TMP/preflight" \
      AI_CLAUDE_REVIEW_BIN="$TMP/claude-gate" \
      AI_CODEX_REVIEW_BIN="$TMP/codex-gate" \
      "$@" bash "$SCRIPT" doctor 2>&1
}

OUT="$(run_doctor)"; RC=$?
[ "$RC" -eq 0 ] && ok "doctor_exits_zero_when_all_sections_pass" || bad "doctor_exits_zero_when_all_sections_pass (rc=$RC)"

ROTATION_SECTION="$(printf '%s\n' "$OUT" | sed -n '/^Rotation reviewers/,/^Approval-gate helpers/p')"
GATE_SECTION="$(printf '%s\n' "$OUT" | sed -n '/^Approval-gate helpers/,$p')"

printf '%s\n' "$ROTATION_SECTION" | grep -q '"provider":"muse"' \
  && ok "rotation_section_lists_registered_reviewer_muse" || bad "rotation_section_lists_registered_reviewer_muse"
printf '%s\n' "$ROTATION_SECTION" | grep -q '"provider":"grok"' \
  && ok "rotation_section_lists_registered_reviewer_grok" || bad "rotation_section_lists_registered_reviewer_grok"
printf '%s\n' "$ROTATION_SECTION" | grep -q '"provider":"codex"' \
  && bad "rotation_section_excludes_gate_helper_codex" || ok "rotation_section_excludes_gate_helper_codex"
printf '%s\n' "$ROTATION_SECTION" | grep -q '"provider":"kimi"' \
  && bad "rotation_section_excludes_unregistered_kimi" || ok "rotation_section_excludes_unregistered_kimi"
printf '%s\n' "$ROTATION_SECTION" | grep -q '"provider":"claude"' \
  && bad "rotation_section_excludes_unregistered_claude" || ok "rotation_section_excludes_unregistered_claude"

printf '%s\n' "$GATE_SECTION" | grep -q 'PASS provider=claude' \
  && ok "gate_section_still_reports_claude_gate" || bad "gate_section_still_reports_claude_gate"
printf '%s\n' "$GATE_SECTION" | grep -q 'PASS provider=codex' \
  && ok "gate_section_still_reports_codex_gate" || bad "gate_section_still_reports_codex_gate"

# A failing gate must fail doctor, and the rotation section must still print.
OUT="$(MOCK_CLAUDE_GATE_FAIL=1 run_doctor)"; RC=$?
[ "$RC" -ne 0 ] && ok "doctor_fails_nonzero_when_a_gate_helper_fails" || bad "doctor_fails_nonzero_when_a_gate_helper_fails (rc=$RC)"
printf '%s\n' "$OUT" | grep -q '"provider":"muse"' \
  && ok "rotation_section_prints_even_when_a_gate_fails" || bad "rotation_section_prints_even_when_a_gate_fails"

# A broken preflight must fail doctor loudly, not fall back to gates-only.
OUT="$(AI_REVIEW_PREFLIGHT_BIN="$TMP/preflight-fail" \
       AI_CLAUDE_REVIEW_BIN="$TMP/claude-gate" \
       AI_CODEX_REVIEW_BIN="$TMP/codex-gate" \
       bash "$SCRIPT" doctor 2>&1)"; RC=$?
[ "$RC" -ne 0 ] && ok "doctor_fails_nonzero_when_rotation_status_fails" || bad "doctor_fails_nonzero_when_rotation_status_fails (rc=$RC)"
printf '%s\n' "$OUT" | grep -q 'PASS provider=codex' \
  && ok "gate_helpers_still_reported_when_preflight_fails" || bad "gate_helpers_still_reported_when_preflight_fails"

# A machine whose install lost the scope file must fail loudly with a clear
# message instead of silently dropping the rotation section.
mkdir -p "$TMP/fakebin"
cp "$SCRIPT" "$TMP/fakebin/ai-review"
OUT="$(env AI_REVIEW_PREFLIGHT_BIN="$TMP/preflight" \
       AI_CLAUDE_REVIEW_BIN="$TMP/claude-gate" \
       AI_CODEX_REVIEW_BIN="$TMP/codex-gate" \
       bash "$TMP/fakebin/ai-review" doctor 2>&1)"; RC=$?
[ "$RC" -ne 0 ] && ok "doctor_fails_nonzero_when_scope_file_is_missing" || bad "doctor_fails_nonzero_when_scope_file_is_missing (rc=$RC)"
printf '%s\n' "$OUT" | grep -q 'cannot find config/reviewer-membership-scope.json' \
  && ok "doctor_names_the_missing_scope_file" || bad "doctor_names_the_missing_scope_file"
printf '%s\n' "$OUT" | grep -q 'PASS provider=codex' \
  && ok "gate_helpers_still_reported_when_scope_file_is_missing" || bad "gate_helpers_still_reported_when_scope_file_is_missing"

# Owner 2026-10-13 (popcre/ai-devops#1714): the maintained rotation pool is
# exactly Muse, DeepSeek, GLM, StepFun. Codex stays registered only as the
# approval-gate helper in reviewer-membership-scope.json.
REAL_REGISTRY="$ROOT/config/reviewer-registry.json"
REAL_SCOPE="$ROOT/config/reviewer-membership-scope.json"
POOL="$(python -c 'import json,sys; r=json.load(open(sys.argv[1]))["providers"]; s=json.load(open(sys.argv[2])).get("outside_allocator",{}); print(",".join(sorted(p for p,v in r.items() if v.get("registry_state")=="registered" and p not in s)))' "$REAL_REGISTRY" "$REAL_SCOPE")"
[ "$POOL" = "deepseek,glm,muse,stepfun" ] \
  && ok "real_registry_rotation_pool_is_muse_deepseek_glm_stepfun" \
  || bad "real_registry_rotation_pool_is_muse_deepseek_glm_stepfun (got: $POOL)"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
