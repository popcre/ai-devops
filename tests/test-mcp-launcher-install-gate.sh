#!/usr/bin/env bash
# Isolated gate state machine: all paths, source evidence and authorities are
# synthetic. No installed gate, vault, external reviewer or host is consulted.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp"
git init -q "$tmp/primary"
git -C "$tmp/primary" -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty -qm fixture
target="$(git -C "$tmp/primary" rev-parse HEAD)"
git -C "$tmp/primary" update-ref refs/remotes/origin/main "$target"
git -C "$tmp/primary" worktree add -q --detach "$tmp/candidate" "$target"
ROOT="$tmp/candidate"; SCRIPT_DIR="$tmp/helpers"; STATE_DIR="$tmp/state"; TOPLEVEL="$ROOT"
mkdir -p "$SCRIPT_DIR" "$STATE_DIR/mcp-launcher-authorizations" "$tmp/cfg"
chmod 700 "$tmp/cfg"
printf '#!/bin/sh\necho source-digest\n' > "$SCRIPT_DIR/ai-review-sandbox"; chmod +x "$SCRIPT_DIR/ai-review-sandbox"
# Loading the library needs its own review operation dependency, no execution.
mkdir -p "$ROOT/tools/lib"; cp "$repo/tools/lib/review-operation.sh" "$ROOT/tools/lib/"
git -C "$ROOT" add tools; git -C "$ROOT" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm helper
target="$(git -C "$ROOT" rev-parse HEAD)"
git -C "$ROOT" update-ref refs/remotes/origin/main "$target"
git -C "$tmp/primary" reset --hard -q "$target"
. "$repo/tools/lib/mcp-launcher-install-gate.sh"
need_value(){ [ "$#" -ge 2 ]; }; require_jq(){ :; }; load_policy(){ :; }; resolve_repo(){ :; }
blocked(){ echo "$*" >&2; exit 1; }; die(){ blocked "$@"; }
install_policy_digest(){ printf policy-digest; }
mcp_install_cfg(){ printf '%s/cfg' "$tmp"; }
mcp_install_platform(){ printf linux; }
mcp_install_authority_ok(){ [ "${FAKE_REVIEW_OK:-1}" = 1 ]; }
mcp_install_review_ok(){ [ "${FAKE_REVIEW_OK:-1}" = 1 ]; }
review_operation_evidence(){ [ "${FAKE_HOST_OK:-1}" = 1 ] && printf '| mcp fixture | `review` |\n'; }
mcp_install_linux_payload_ok(){ [ "${FAKE_PAYLOAD_OK:-1}" = 1 ]; }
# These are actual read-only proof routes in the real gate; here state tests
# substitute successful scripts, and renderer/session suites run separately.
mkdir "$ROOT/tests"; printf '#!/bin/sh\nexit 0\n' > "$ROOT/tests/test-mcp-remote-header-freshness.sh"
cp "$ROOT/tests/test-mcp-remote-header-freshness.sh" "$ROOT/tests/test-mcp-session-guard.sh"
chmod +x "$ROOT/tests/"*
git -C "$ROOT" add tests; git -C "$ROOT" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm probes
target="$(git -C "$ROOT" rev-parse HEAD)"; git -C "$ROOT" update-ref refs/remotes/origin/main "$target"; git -C "$tmp/primary" reset --hard -q "$target"
printf old > "$tmp/cfg/mcp-remote-launch.sh"; printf guard > "$tmp/cfg/mcp-session-guard.mjs"
printf '| mcp fixture | `review` |\n' > "$tmp/review"
issued="$STATE_DIR/mcp-launcher-authorizations/$target.json"
inventory="$(mcp_install_inventory)"
jq -nc --arg h "$target" --arg p "$tmp/primary" --arg b "$(printf '%s\n' "$inventory" | sha256sum | cut -d' ' -f1)" --arg r "$tmp/review" --arg d "$(sha256sum "$tmp/review" | cut -d' ' -f1)" \
  '{schema_version:1,scope:"mcp-launchers",target_head:$h,installed_head:$h,installed_checkout:$p,installed_launcher:"/fixture/gate",before_inventory_sha256:$b,source_digest:"source-digest",policy_digest:"policy-digest",review_report:$r,review_report_sha256:$d}' > "$issued"
chmod 600 "$issued"
verify(){ (cmd_install_verify_mcp --mcp-launchers-only --phase "$1" --target-head "$target" --installed-checkout "$tmp/primary" --installed-launcher /fixture/gate "${@:2}"); }
printf changed > "$tmp/cfg/mcp-remote-launch.sh"
if verify preflight >/dev/null 2>&1; then echo 'FAIL: stale destination admitted'; exit 1; fi
[ -f "$issued" ]; printf old > "$tmp/cfg/mcp-remote-launch.sh"
if FAKE_REVIEW_OK=0 verify preflight >/dev/null 2>&1; then echo 'FAIL: invalid review admitted'; exit 1; fi
[ -f "$issued" ]; verify preflight >/dev/null
[ ! -e "$issued" ] && [ -f "$issued.consuming" ]
verify preflight >/dev/null
echo 'PASS: stale inventory/review refuse before one-use reservation; exact retry works'
printf installed > "$tmp/cfg/mcp-remote-launch.sh"
report="$tmp/report"; inventory="$(mcp_install_inventory)"
jq -nc --arg h "$target" --arg p "$tmp/primary" --arg i "$inventory" \
  '{schema_version:1,scope:"mcp-launchers",target_head:$h,installed_checkout:$p,after_inventory:$i,synthetic_probe_pass:true}' > "$report"; chmod 600 "$report"
if FAKE_PAYLOAD_OK=0 verify finalize --stage-report "$report" >/dev/null 2>&1; then echo 'FAIL: caller pass flag bypassed payload proof'; exit 1; fi
[ -f "$issued.consuming" ]
if FAKE_HOST_OK=0 verify finalize --stage-report "$report" >/dev/null 2>&1; then echo 'FAIL: changed host full receipt admitted'; exit 1; fi
printf '#!/bin/sh\necho changed-source\n' > "$SCRIPT_DIR/ai-review-sandbox"
if verify finalize --stage-report "$report" >/dev/null 2>&1; then echo 'FAIL: changed source admitted'; exit 1; fi
printf '#!/bin/sh\necho source-digest\n' > "$SCRIPT_DIR/ai-review-sandbox"
printf changed-review > "$tmp/review"
if verify finalize --stage-report "$report" >/dev/null 2>&1; then echo 'FAIL: changed review admitted'; exit 1; fi
printf '| mcp fixture | `review` |\n' > "$tmp/review"
verify finalize --stage-report "$report" >/dev/null
[ ! -e "$issued.consuming" ]
receipt="$STATE_DIR/mcp-launcher-installs/$target.json"
jq -e '.full_install_completed==false and .scope=="mcp-launchers"' "$receipt" >/dev/null
verify preflight >/dev/null
printf changed > "$tmp/cfg/mcp-remote-launch.sh"
if verify preflight >/dev/null 2>&1; then echo 'FAIL: altered completed payload accepted'; exit 1; fi
echo 'PASS: final payload/review proof, partial receipt and changed completion refusal'
jq -nc --arg t "$target" --arg p "$tmp/primary" '{target_head:$t,installed_checkout:$p}' > "$tmp/full-receipt"
mcp_install_supersede_full "$tmp/primary" "$target" "$tmp/full-receipt"
jq -e --arg t "$target" '.superseded_by_full==$t and .full_install_completed==false' "$receipt" >/dev/null
echo 'PASS: verified full receipt supersedes partial evidence without relabeling it full'
# A protected source class cannot be waived by this narrower operation.
IDENTITY=popcre/ai-devops
merged_gate(){ printf 'required\treviewed-toolkit-installation\n'; }
state_field(){ case "$1" in declared_class) printf installation ;; start_head) printf '%s' "$target" ;; esac; }
linux_manifest_receipt(){ printf '%s' "$target"; }
install_release_classes(){ printf 'private-evidence\ttrue\n'; }
git -C "$tmp/primary" remote add origin https://github.com/popcre/ai-devops.git
if (cmd_authorize_mcp_install --mcp-launchers-only --target-head "$target" --installed-checkout "$tmp/primary" --installed-launcher /usr/local/bin/ai-task-gates --review-report "$tmp/review" --reviewer-approval "$tmp/review") > "$tmp/refusal" 2>&1; then
  echo 'FAIL: private protected source range was waived'; exit 1
fi
grep -q "crosses stronger 'private-evidence' class" "$tmp/refusal"
echo 'PASS: private source class refuses regardless of narrower operation or supplied approvals'
