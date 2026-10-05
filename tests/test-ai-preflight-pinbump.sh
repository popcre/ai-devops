#!/usr/bin/env bash
# Focused tests for the O(1) preflight guard rails and the pin-only
# qualification fast path (#1183 child 5, owner #650 P6/P8).
#
# WHY THIS FILE EXISTS
# The pin-only qualification lane is a FAST PATH for version-pin-bump-only
# changes (Muse 2b shape): hash the binary, run doctor, one live smoke;
# auto-quarantine on pin mismatch; auto-restore when the pin is updated in the
# same change. It is NOT the rejected hard exact-pin-everything lane (owner
# ruling 2026-09-23 on #686). These tests prove both halves: the lane is cheap
# and it can never hard-pin an auto-updating provider.
#
# They also guard the O(1) check path: no prune/reconcile/per-record sweep may
# run inline (Muse 2b CUT-4), with a spawn-count upper bound rather than a
# wall-clock assertion (plan_workflow-efficiency.md).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-review-preflight"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export AI_REVIEW_QUARANTINE_DIR="$TMP/state"
export AI_REVIEW_REGISTRY_FILE="$TMP/registry.json"
cat > "$AI_REVIEW_REGISTRY_FILE" <<'REGEOF'
{"version":1,"providers":{
 "claude":{"registry_state":"registered","reason":"test"},
 "codex":{"registry_state":"registered","reason":"test"},
 "deepseek":{"registry_state":"registered","reason":"test"},
 "gemini":{"registry_state":"registered","reason":"test"},
 "glm":{"registry_state":"registered","reason":"test"},
 "grok":{"registry_state":"registered","reason":"test"},
 "kimi":{"registry_state":"registered","reason":"test"},
 "muse":{"registry_state":"registered","reason":"test"},
 "qwen":{"registry_state":"registered","reason":"test"},
 "stepfun":{"registry_state":"registered","reason":"test"}}}
REGEOF
REPO="$TMP/repo"; mkdir -p "$REPO"; git -C "$REPO" init -q; git -C "$REPO" config user.name Test; git -C "$REPO" config user.email t@example.com
echo x > "$REPO/a"; git -C "$REPO" add a; git -C "$REPO" commit -qm init
mkdir -p "$TMP/bin" "$TMP/state"
cat > "$TMP/bin/good" <<'EOF'
#!/usr/bin/env bash
echo health ok
EOF
chmod +x "$TMP/bin/good"

echo '== O(1) preflight: the check path is fixed checks only (#1183 child 5)'
# Maintenance out of the hot path: prune/reconcile/per-record sweeps must never
# run inline in the check path (Muse 2b CUT-4). The check path is allowed
# exactly the cheap fixed checks: binary present, health probe, version pin.
CHECK_FN="$(sed -n '/^check_provider()/,/^}/p' "$SCRIPT")"
check "check path runs no prune/reconcile/per-record sweep" \
  "! printf '%s' \"\$CHECK_FN\" | grep -qE 'cmd_prune|reconcile_|glm_record_index|glm_orphan|glm_due_review'"
check "check path keeps its fixed checks (wrapper, doctor probe, quarantine gate)" \
  "printf '%s' \"\$CHECK_FN\" | grep -q 'provider_wrapper' && printf '%s' \"\$CHECK_FN\" | grep -q 'doctor' && printf '%s' \"\$CHECK_FN\" | grep -q 'active_quarantine'"
PF_STATUS_FN="$(sed -n '/^reconciled_status()/,/^}/p' "$SCRIPT")"
check "status path runs no prune/reconcile/per-record sweep" \
  "! printf '%s' \"\$PF_STATUS_FN\" | grep -qE 'cmd_prune|reconcile_|glm_record_index|glm_orphan|glm_due_review'"
# doctor/preflight must not act: the maintenance sweep lives in ai-glm prune.
AI_GLM="$ROOT/bin/ai-glm"
GLM_DOCTOR_FN="$(sed -n '/^cmd_doctor()/,/^}/p' "$AI_GLM")"
check "ai-glm doctor never runs a reconcile sweep (it lives in prune)" \
  "! printf '%s' \"\$GLM_DOCTOR_FN\" | grep -q 'reconcile_implementation_records'"
check "ai-glm prune carries the reconcile sweep on its unbounded pass" \
  "sed -n '/^cmd_prune()/,/^}/p' '$AI_GLM' | grep -q 'reconcile_implementation_records'"

# Spawn-count UPPER-BOUND guard (preferred over wall-clock per
# plan_workflow-efficiency.md). PATH shims count external spawns during a real
# check; the count must stay bounded AND independent of how many records sit in
# the quarantine state directory. A per-record sweep would grow it with N.
PB_SHIM="$TMP/spawn-shim"; mkdir -p "$PB_SHIM"
for _sc in jq git timeout sha256sum date awk sed tr stat cat grep mktemp; do
  _real="$(command -v "$_sc" 2>/dev/null || true)"
  [ -n "$_real" ] || continue
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s" >> "$SPAWN_LOG"\nexec "%s" "$@"\n' "$_sc" "$_real" > "$PB_SHIM/$_sc"
  chmod +x "$PB_SHIM/$_sc"
done
# Pure stubs for the evidence tools: this guard measures the check path's fixed
# checks, not the packet/sandbox evidence machinery (covered by its own suites).
cat > "$TMP/bin/packet-stub" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  build) printf '%s/stub-packet\n' "$2" ;;
  *) exit 0 ;;
esac
EOF
cat > "$TMP/bin/sandbox-stub" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  ensure-copy) printf '%s/stub-sandbox\n' ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$TMP/bin/packet-stub" "$TMP/bin/sandbox-stub"
spawn_check_count() { # N -> external spawns for one check against a state dir holding N junk records
  local n="$1"
  local log="$TMP/spawn-$n.log"
  local st="$TMP/pb-spawn-state-$n"
  local i
  rm -rf "$st"; mkdir -p "$st"
  for i in $(seq 1 "$n"); do printf '{}\n' > "$st/junk$i.json"; done
  : > "$log"
  SPAWN_LOG="$log" \
  AI_REVIEW_QUARANTINE_DIR="$st" \
  AI_REVIEW_KIMI_WRAPPER="$TMP/bin/good" \
  AI_REVIEW_PACKET_BIN="$TMP/bin/packet-stub" \
  AI_REVIEW_SANDBOX_BIN="$TMP/bin/sandbox-stub" \
  PATH="$PB_SHIM:$PATH" \
    "$SCRIPT" check kimi "$REPO" >/dev/null 2>&1 || true
  wc -l < "$log" | tr -d ' '
}
SPAWN_5="$(spawn_check_count 5)"
SPAWN_50="$(spawn_check_count 50)"
check "preflight check spawns a bounded number of processes" \
  "test '$SPAWN_5' -gt 0 && test '$SPAWN_5' -le 60"
check "preflight check spawn count is independent of state-record count (no per-record sweep)" \
  "test '$SPAWN_50' -eq '$SPAWN_5'"

echo '== pin-only qualification lane (fast path for pin-bump-only changes)'
# Muse 2b shape: hash the binary, run doctor, one live smoke; auto-quarantine on
# pin mismatch; auto-restore when the pin is updated in the same change.
PB_POLICY="$TMP/pin-policy.json"
cat > "$PB_POLICY" <<'PEOF'
{
  "schema_version": 1,
  "providers": {
    "grok": {
      "command": "fakegrok",
      "supported_version": "1.0.13",
      "version_match": "minimum",
      "qualified_on": "2026-09-03",
      "exact_install_command": null,
      "notes": "fixture: minimum floor, mirrors the real Grok owner ruling 2026-09-23"
    },
    "kimi": {
      "command": "fakekimi",
      "supported_version": "2.0.0",
      "version_match": "exact",
      "qualified_on": "2026-09-03",
      "exact_install_command": null,
      "notes": "fixture: exact pin"
    }
  }
}
PEOF
cat > "$TMP/bin/fakegrok" <<'FEOF'
#!/usr/bin/env bash
if [ "${1:-}" = --version ]; then printf 'fakegrok %s (abc) [stable]\n' "${FAKE_GROK_VERSION:-1.0.15}"; exit 0; fi
echo health ok
FEOF
cat > "$TMP/bin/fakekimi" <<'FEOF'
#!/usr/bin/env bash
if [ "${1:-}" = --version ]; then printf 'fakekimi %s\n' "${FAKE_KIMI_VERSION:-2.0.0}"; exit 0; fi
echo health ok
FEOF
cat > "$TMP/bin/pb-doctor" <<'FEOF'
#!/usr/bin/env bash
if [ "${1:-}" = doctor ] && [ "${2:-}" = --live ]; then
  [ "${PB_LIVE_FAIL:-0}" = 0 ] || { echo live failed >&2; exit 1; }
  echo live smoke ok; exit 0
fi
if [ "${1:-}" = doctor ]; then
  [ "${PB_DOCTOR_FAIL:-0}" = 0 ] || { echo 'NOT AUTHENTICATED: login required' >&2; exit 1; }
  echo health ok; exit 0
fi
echo unexpected; exit 1
FEOF
chmod +x "$TMP/bin/fakegrok" "$TMP/bin/fakekimi" "$TMP/bin/pb-doctor"
run_pb() {
  env AI_PROVIDER_VERSIONS_FILE="$PB_POLICY" \
      AI_PROVIDER_VERSION_BIN="$ROOT/bin/ai-provider-version" \
      AI_REVIEW_GROK_WRAPPER="$TMP/bin/pb-doctor" \
      AI_REVIEW_KIMI_WRAPPER="$TMP/bin/pb-doctor" \
      AI_REVIEW_QUARANTINE_DIR="$TMP/state" \
      PATH="$TMP/bin:$PATH" \
      "$SCRIPT" "$@"
}
rm -rf "$TMP/state"; mkdir -p "$TMP/state"

# THE critical non-hard-pin property: a version_match "minimum" provider whose
# installed build is NEWER than the pin must qualify, not quarantine. The
# rejected hard-pin lane would fail this (owner ruling 2026-09-23 on #686).
PB_OUT="$(FAKE_GROK_VERSION=1.0.15 run_pb pin-bump-qualify grok 2>&1)"; PB_RC=$?
[ "$PB_RC" -eq 0 ] && printf '%s' "$PB_OUT" | grep -q 'PASS pin-bump-qualify provider=grok' \
  && ok "minimum provider newer than its pin qualifies (not a hard exact pin)" \
  || { bad "minimum provider newer than its pin qualifies (not a hard exact pin)"; printf '%s\n' "$PB_OUT"; }
check "the qualify record binds the CLI binary hash" \
  "jq -e '.cli_sha256|test(\"^[0-9a-f]{64}\$\")' '$TMP/state/grok-live-qualified.json' && jq -e '.cli_version==\"1.0.15\"' '$TMP/state/grok-live-qualified.json'"
check "the qualify record reuses the existing hash-pin store, not a second store" \
  "test -f '$TMP/state/grok-live-qualified.json' && jq -e '.wrapper_sha256|test(\"^[0-9a-f]{64}\$\")' '$TMP/state/grok-live-qualified.json'"
check "pin-bump qualification does NOT add the provider to the live-qualified gate" \
  "grep -q 'LIVE_QUALIFIED_PROVIDERS=\"gemini qwen\"' '$SCRIPT' && ! printf '%s' \"\$(sed -n '/^static_status()/,/^}/p' '$SCRIPT')\" | grep -q 'grok'"

# Auto-quarantine on pin mismatch: a build below the floor fails policy.
rm -rf "$TMP/state"; mkdir -p "$TMP/state"
PB_OUT="$(FAKE_GROK_VERSION=1.0.5 run_pb pin-bump-qualify grok 2>&1)"; PB_RC=$?
[ "$PB_RC" -ne 0 ] && printf '%s' "$PB_OUT" | grep -q 'pin mismatch' \
  && ok "a build below the floor is auto-quarantined on pin mismatch" \
  || { bad "a build below the floor is auto-quarantined on pin mismatch"; printf '%s\n' "$PB_OUT"; }
check "the quarantine class is pin-mismatch" \
  "run_pb status grok | jq -e '.status==\"quarantined\" and .failure_class==\"pin-mismatch\"'"
check "pin-mismatch guidance names the same-change restore" \
  "run_pb explain pin-mismatch | grep -q 'same change'"

# Auto-restore when the pin is updated in the same change: bump the floor to the
# installed build and re-run; the stale pin-mismatch quarantine clears itself.
jq '.providers.grok.supported_version = "1.0.5"' "$PB_POLICY" > "$PB_POLICY.new" && mv "$PB_POLICY.new" "$PB_POLICY"
PB_OUT="$(FAKE_GROK_VERSION=1.0.5 run_pb pin-bump-qualify grok 2>&1)"; PB_RC=$?
[ "$PB_RC" -eq 0 ] && printf '%s' "$PB_OUT" | grep -q 'cleared stale pin-mismatch quarantine' \
  && printf '%s' "$PB_OUT" | grep -q 'PASS pin-bump-qualify provider=grok' \
  && ok "updating the pin in the same change auto-restores the pin-mismatch quarantine" \
  || { bad "updating the pin in the same change auto-restores the pin-mismatch quarantine"; printf '%s\n' "$PB_OUT"; }
check "the restored provider is no longer quarantined" \
  "run_pb status grok | jq -e '.usable==true'"

# Exact-pin providers still fail closed on a mismatch (the lane is not a bypass).
rm -rf "$TMP/state"; mkdir -p "$TMP/state"
PB_OUT="$(FAKE_KIMI_VERSION=1.9.9 run_pb pin-bump-qualify kimi 2>&1)"; PB_RC=$?
[ "$PB_RC" -ne 0 ] && printf '%s' "$PB_OUT" | grep -q 'pin mismatch' \
  && ok "an exact-pin provider still fails closed on a mismatch" \
  || { bad "an exact-pin provider still fails closed on a mismatch"; printf '%s\n' "$PB_OUT"; }

# The cheap lane refuses the providers that already own a full live qualification.
PB_OUT="$(run_pb pin-bump-qualify gemini 2>&1)"; PB_RC=$?
[ "$PB_RC" -ne 0 ] && printf '%s' "$PB_OUT" | grep -q 'full live qualification' \
  && ok "pin-bump-qualify refuses gemini (use qualify)" \
  || { bad "pin-bump-qualify refuses gemini (use qualify)"; printf '%s\n' "$PB_OUT"; }
PB_OUT="$(run_pb pin-bump-qualify qwen 2>&1)"; PB_RC=$?
[ "$PB_RC" -ne 0 ] && printf '%s' "$PB_OUT" | grep -q 'full live qualification' \
  && ok "pin-bump-qualify refuses qwen (use qualify)" \
  || { bad "pin-bump-qualify refuses qwen (use qualify)"; printf '%s\n' "$PB_OUT"; }

# A failed doctor or a failed live smoke quarantines and never publishes.
rm -rf "$TMP/state"; mkdir -p "$TMP/state"
PB_OUT="$(PB_DOCTOR_FAIL=1 FAKE_GROK_VERSION=1.0.15 run_pb pin-bump-qualify grok 2>&1)"; PB_RC=$?
[ "$PB_RC" -ne 0 ] && ! test -f "$TMP/state/grok-live-qualified.json" \
  && ok "a failed doctor never publishes a qualification" \
  || { bad "a failed doctor never publishes a qualification"; printf '%s\n' "$PB_OUT"; }
run_pb clear grok >/dev/null 2>&1 || true
rm -rf "$TMP/state"; mkdir -p "$TMP/state"
PB_OUT="$(PB_LIVE_FAIL=1 FAKE_GROK_VERSION=1.0.15 run_pb pin-bump-qualify grok 2>&1)"; PB_RC=$?
[ "$PB_RC" -ne 0 ] && ! test -f "$TMP/state/grok-live-qualified.json" \
  && ok "a failed live smoke never publishes a qualification" \
  || { bad "a failed live smoke never publishes a qualification"; printf '%s\n' "$PB_OUT"; }

# An active non-pin-mismatch quarantine is never silently cleared by the lane.
rm -rf "$TMP/state"; mkdir -p "$TMP/state"
run_pb quarantine grok authentication-failed --seconds 60 >/dev/null 2>&1
PB_OUT="$(FAKE_GROK_VERSION=1.0.15 run_pb pin-bump-qualify grok 2>&1)"; PB_RC=$?
[ "$PB_RC" -ne 0 ] && printf '%s' "$PB_OUT" | grep -q 'quarantine' \
  && ok "an active non-pin-mismatch quarantine is not cleared by the lane" \
  || { bad "an active non-pin-mismatch quarantine is not cleared by the lane"; printf '%s\n' "$PB_OUT"; }

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
