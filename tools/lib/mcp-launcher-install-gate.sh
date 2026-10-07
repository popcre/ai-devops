# shellcheck shell=bash
# Narrow MCP launcher transaction. The full toolkit receipt is deliberately
# untouched: these records attest only the fixed launcher destinations.

# shellcheck source=review-operation.sh
. "$ROOT/tools/lib/review-operation.sh"

mcp_install_platform(){
  case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) printf windows ;; *) printf linux ;; esac
}

mcp_install_cfg(){
  if [ "$(mcp_install_platform)" = windows ]; then
    [ -n "${USERPROFILE:-}" ] || return 1
    printf '%s/.config/ai-devops' "$(cygpath -u "$USERPROFILE")"
  else
    printf '%s/.config/ai-devops' "$HOME"
  fi
}

mcp_install_paths(){
  local cfg; cfg="$(mcp_install_cfg)" || return 1
  if [ "$(mcp_install_platform)" = windows ]; then
    printf '%s\n' "$cfg/mcp-remote-launch.cmd" "$cfg/mcp-session-guard.mjs" "$cfg/mcp-secret-launch.ps1" "$cfg/mcp-runtime"
  else
    printf '%s\n' "$cfg/mcp-remote-launch.sh" "$cfg/mcp-session-guard.mjs"
  fi
}

mcp_install_linux_payload_ok(){
  local cfg node TOKEN_FILE CFG_DIR NODE_BIN GUARD_JS
  cfg="$(mcp_install_cfg)" || return 1
  node="$(command -v node)" && [ -x "$node" ] || return 1
  TOKEN_FILE="$cfg/op-service-account"; CFG_DIR="$cfg"; NODE_BIN="$node"; GUARD_JS="$cfg/mcp-session-guard.mjs"
  . "$ROOT/tools/lib/mcp-remote-render.sh"
  cmp -s "$ROOT/bin/mcp-session-guard.mjs" "$GUARD_JS" &&
    cmp -s <(mcp_remote_render) "$cfg/mcp-remote-launch.sh" &&
    [ "$(stat -c %a "$GUARD_JS")" = 755 ] &&
    [ "$(stat -c %a "$cfg/mcp-remote-launch.sh")" = 755 ]
}

mcp_install_hash_path(){
  local path="$1"
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then printf missing; return 0; fi
  [ ! -L "$path" ] || return 1
  if [ -f "$path" ]; then sha256sum "$path" | cut -d' ' -f1; return; fi
  [ -d "$path" ] || return 1
  # A runtime directory can contain many files, but never a link or a path
  # outside the one managed directory. Bind every relative name and byte hash.
  python3 - "$path" <<'PY'
import hashlib, os, stat, sys
root = sys.argv[1]
h = hashlib.sha256()
for base, dirs, files in os.walk(root, followlinks=False):
    dirs.sort(); files.sort()
    for name in dirs + files:
        path = os.path.join(base, name)
        mode = os.lstat(path).st_mode
        if stat.S_ISLNK(mode): raise SystemExit(1)
        if not (stat.S_ISDIR(mode) or stat.S_ISREG(mode)): raise SystemExit(1)
        rel = os.path.relpath(path, root).encode()
        h.update(rel + b'\0')
        if stat.S_ISREG(mode):
            fh = hashlib.sha256()
            with open(path, 'rb') as f:
                for chunk in iter(lambda: f.read(1024 * 1024), b''): fh.update(chunk)
            h.update(fh.hexdigest().encode() + b'\0')
        else: h.update(b'directory\0')
print(h.hexdigest())
PY
}

mcp_install_inventory(){
  local path hash cfg parent
  cfg="$(mcp_install_cfg)" || return 1
  parent="$cfg"
  while [ "$parent" != / ]; do
    [ ! -L "$parent" ] || return 1
    if [ "$(mcp_install_platform)" = linux ] && [ -e "$parent" ]; then
      [ -d "$parent" ] && [ "$(stat -c %u "$parent")" = "$(id -u)" ] &&
        [ $((8#$(stat -c %a "$parent") & 0022)) -eq 0 ] || return 1
    fi
    [ "$parent" != "$HOME" ] || break
    parent="$(dirname "$parent")"
  done
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    hash="$(mcp_install_hash_path "$path")" || return 1
    printf '%s\t%s\n' "$path" "$hash"
  done < <(mcp_install_paths)
}

mcp_install_review_ok(){
  local report="$1" target="$2" source="$3" installed="$4" candidate="$5" evidence="$6"
  local review_root common key lifecycle_root state report_hash header matched=0 line
  [ -f "$report" ] && [ ! -L "$report" ] || return 1
  report="$(cd "$(dirname "$report")" && pwd -P)/$(basename "$report")" || return 1
  review_root="$(git -C "$(dirname "$report")" rev-parse --show-toplevel 2>/dev/null)" || return 1
  review_root="$(cd "$review_root" && pwd -P)" || return 1
  case "$report" in "$review_root"/.ai/reviews/*) ;; *) return 1 ;; esac
  [ "$review_root" != "$installed" ] && [ "$review_root" != "$candidate" ] &&
    [ "$(git -C "$review_root" rev-parse HEAD)" = "$target" ] || return 1
  [ -z "$(git -C "$review_root" status --porcelain=v1 --untracked-files=all)" ] || return 1
  common="$(git -C "$installed" rev-parse --path-format=absolute --git-common-dir)" || return 1
  [ "$common" = "$(git -C "$review_root" rev-parse --path-format=absolute --git-common-dir)" ] || return 1
  [ "$(tail -n 2 "$report" | tr -d '\r')" = $'## Verdict\nAPPROVE' ] || return 1
  header="$(tr -d '\r' < "$report" | sed '/^## Result$/,$d')"
  grep -Fqx "| reviewed commit | \`$target\` |" <<< "$header" || return 1
  grep -Fqx "| source digest | \`$source\` |" <<< "$header" || return 1
  [ "$(grep -c '^| operation | ' <<< "$header")" = 1 ] || return 1
  grep -Fqx '| operation | `mcp-launchers-only` |' <<< "$header" || return 1
  grep -Fqx 'Approved mcp-launchers-only.' "$report" || return 1
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    grep -Fqx "$line" <<< "$header" || return 1
  done <<< "$evidence"
  [ "$("$SCRIPT_DIR/ai-review-sandbox" digest "$review_root")" = "$source" ] || return 1
  report_hash="$(sha256sum "$report" | cut -d' ' -f1)" || return 1
  key="$("$SCRIPT_DIR/ai-review-lifecycle" identity "$review_root" | jq -r .repository_key)" || return 1
  lifecycle_root="${AI_REVIEW_LIFECYCLE_DIR:-$HOME/.local/state/ai-devops/review-lifecycle}"
  for state in "$lifecycle_root/runs/$key/"*/*/*.json; do
    [ -f "$state" ] || continue
    if jq -e --arg h "$target" --arg d "$source" --arg p "$report" --arg s "$report_hash" \
      '.status=="completed" and .verdict=="APPROVE" and .stale==false and .head==$h and .source_digest==$d and .report_path==$p and .report_sha256==$s' "$state" >/dev/null 2>&1; then matched=1; break; fi
  done
  [ "$matched" -eq 1 ]
}

mcp_install_evidence_field(){
  local label="$1" evidence="$2"
  awk -F '`' -v label="| $label | " '$1 == label {print $2}' <<< "$evidence"
}

cmd_authorize_mcp_install(){
  local target='' installed='' launcher='' report='' approval='' value='' candidate='' old='' common='' origin_url=''
  local evidence='' receipt='' base='' classes='' cls='' protected='' digest='' policy='' report_hash='' approval_summary=''
  local auth_dir='' auth='' inventory='' inventory_digest='' evidence_digest='' staged=''
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --mcp-launchers-only) shift ;;
      --target-head) need_value "$@"; target="$2"; shift 2 ;;
      --installed-checkout) need_value "$@"; installed="$2"; shift 2 ;;
      --installed-launcher) need_value "$@"; launcher="$2"; shift 2 ;;
      --review-report) need_value "$@"; report="$2"; shift 2 ;;
      --reviewer-approval) need_value "$@"; approval="$2"; shift 2 ;;
      *) die "unknown option for MCP launcher authority: $1" ;;
    esac
  done
  POLICY_FILE="$ROOT/config/task-gates.json"; require_jq; load_policy; resolve_repo
  [[ "$IDENTITY" = popcre/ai-devops || "$IDENTITY" = u2giants/ai-devops ]] || blocked 'ai-task-gates: MCP installation requires ai-devops identity.'
  printf '%s\n' "$(merged_gate "$IDENTITY" reviewer-safety)" | grep -qx $'required\treviewed-toolkit-installation' || blocked 'ai-task-gates: MCP installation requires repository reviewed-installation opt-in.'
  [ "$(state_field declared_class)" = installation ] || blocked 'ai-task-gates: MCP installation needs a separate installation task.'
  old="$(state_field start_head)"
  [[ "$old" =~ ^[0-9a-f]{40}$ && "$target" =~ ^[0-9a-f]{40}$ ]] || die 'MCP installation requires full old and target SHAs.'
  [ "$target" = "$(git -C "$TOPLEVEL" rev-parse HEAD)" ] && [ "$target" = "$(git -C "$TOPLEVEL" rev-parse refs/remotes/origin/main)" ] || blocked 'ai-task-gates: MCP target is not exact fetched main.'
  [ -z "$(git -C "$TOPLEVEL" status --porcelain=v1 --untracked-files=all)" ] || blocked 'ai-task-gates: MCP candidate is dirty.'
  candidate="$(cd "$TOPLEVEL" && pwd -P)"
  installed="$(cd "$installed" 2>/dev/null && pwd -P)" || blocked 'ai-task-gates: Installed checkout unavailable.'
  [ "$installed" != "$candidate" ] && [ "$(git -C "$installed" rev-parse HEAD)" = "$old" ] || blocked 'ai-task-gates: Installed checkout moved.'
  [ -z "$(git -C "$installed" status --porcelain=v1 --untracked-files=all)" ] || blocked 'ai-task-gates: Installed checkout is dirty.'
  common="$(git -C "$installed" rev-parse --path-format=absolute --git-common-dir)" || blocked 'ai-task-gates: Installed Git ownership unavailable.'
  [ "$(git -C "$installed" rev-parse --path-format=absolute --git-dir)" = "$common" ] && [ "$(git -C "$candidate" rev-parse --path-format=absolute --git-common-dir)" = "$common" ] || blocked 'ai-task-gates: MCP candidate and primary checkout differ.'
  git -C "$installed" merge-base --is-ancestor "$old" "$target" || blocked 'ai-task-gates: MCP target is not a fast-forward.'
  origin_url="$(git -C "$installed" remote get-url origin)" || blocked 'ai-task-gates: Installed origin unavailable.'
  case "$origin_url" in
    https://github.com/popcre/ai-devops|https://github.com/popcre/ai-devops.git|https://github.com/u2giants/ai-devops|https://github.com/u2giants/ai-devops.git|git@github.com:popcre/ai-devops|git@github.com:popcre/ai-devops.git|git@github.com:u2giants/ai-devops|git@github.com:u2giants/ai-devops.git) ;;
    *) blocked 'ai-task-gates: MCP install needs the supported GitHub origin.' ;;
  esac
  if [ "$(mcp_install_platform)" = linux ]; then
    [ "$launcher" = /usr/local/bin/ai-task-gates ] || blocked 'ai-task-gates: MCP gate launcher path differs.'
    receipt="$(linux_manifest_receipt "$installed" "$launcher" /etc/ai-devops/install-manifest.tsv)" || blocked 'ai-task-gates: MCP full source receipt invalid.'
  else
    [ "$launcher" = "$HOME/.local/bin/ai-task-gates" ] || blocked 'ai-task-gates: MCP gate launcher path differs.'
    windows_launcher_route "$installed/bin/ai-task-gates" "$launcher" || blocked 'ai-task-gates: MCP Windows gate launchers differ.'
    receipt="${WINDOWS_RECEIPT_SHA:-legacy}"
    if [ "$receipt" != legacy ]; then
      [ "$(git -C "$installed" show "$receipt:bin/ai-task-gates" | sha256sum | cut -d' ' -f1)" = "$WINDOWS_RECEIPT_HASH" ] || blocked 'ai-task-gates: MCP Windows source receipt hash invalid.'
    fi
  fi
  base="$receipt"; [ "$base" != legacy ] || base="$old"
  git -C "$installed" merge-base --is-ancestor "$base" "$old" || blocked 'ai-task-gates: MCP full receipt is not ancestor of live checkout.'
  classes="$(install_release_classes "$base" "$target" | LC_ALL=C sort -u)" || blocked 'ai-task-gates: MCP source range unavailable.'
  while IFS=$'\t' read -r cls protected; do
    [ -n "$cls" ] || continue
    [ "$protected" != true ] || [ "$cls" = reviewer-safety ] || blocked "ai-task-gates: MCP source range crosses stronger '$cls' class."
  done <<< "$classes"
  evidence="$(review_operation_evidence mcp-launchers-only)" || blocked 'ai-task-gates: MCP host evidence unavailable.'
  [ "$(mcp_install_evidence_field 'mcp installed SHA' "$evidence")" = "$old" ] &&
    [ "$(mcp_install_evidence_field 'mcp full receipt SHA' "$evidence")" = "$receipt" ] || blocked 'ai-task-gates: MCP reviewed host baseline differs.'
  digest="$("$SCRIPT_DIR/ai-review-sandbox" digest "$candidate")" || blocked 'ai-task-gates: MCP source digest unavailable.'
  mcp_install_review_ok "$report" "$target" "$digest" "$installed" "$candidate" "$evidence" || blocked 'ai-task-gates: MCP exact-head operation review is missing or changed.'
  approval_summary="$(reviewer_approval_summary "$approval" deploy "$target" "$candidate")" || blocked 'ai-task-gates: MCP install lacks assigned AI reviewer APPROVE.'
  policy="$(install_policy_digest "$target")" || blocked 'ai-task-gates: MCP policy digest unavailable.'
  report="$(cd "$(dirname "$report")" && pwd -P)/$(basename "$report")"
  report_hash="$(sha256sum "$report" | cut -d' ' -f1)"
  inventory="$(mcp_install_inventory)" || blocked 'ai-task-gates: MCP destination inventory unsafe.'
  inventory_digest="$(printf '%s\n' "$inventory" | sha256sum | cut -d' ' -f1)"
  evidence_digest="$(printf '%s\n' "$evidence" | sha256sum | cut -d' ' -f1)"
  auth_dir="$STATE_DIR/mcp-launcher-authorizations"; auth="$auth_dir/$target.json"
  [ ! -e "$STATE_DIR/mcp-launcher-installs/$target.json" ] || blocked 'ai-task-gates: MCP partial receipt already exists for target.'
  mkdir -p "$auth_dir" && chmod 0700 "$STATE_DIR" "$auth_dir" || blocked 'ai-task-gates: MCP state cannot be protected.'
  [ ! -e "$auth" ] && [ ! -L "$auth" ] && [ ! -e "$auth.consuming" ] || blocked 'ai-task-gates: MCP authority already exists.'
  staged="$(mktemp "$auth_dir/.authority.XXXXXXXX")" || blocked 'ai-task-gates: MCP authority stage failed.'
  jq -nc --arg target "$target" --arg old "$old" --arg checkout "$installed" --arg launcher "$launcher" \
    --arg base "$base" --arg receipt "$receipt" --arg evidence "$evidence_digest" --arg before "$inventory_digest" --arg inventory "$inventory" \
    --arg source "$digest" --arg policy "$policy" --arg report "$report" --arg report_hash "$report_hash" --arg approval "$approval_summary" \
    '{schema_version:1,scope:"mcp-launchers",target_head:$target,installed_head:$old,installed_checkout:$checkout,installed_launcher:$launcher,full_receipt_base:$base,full_receipt_sha:$receipt,host_evidence_sha256:$evidence,before_inventory:$inventory,before_inventory_sha256:$before,source_digest:$source,policy_digest:$policy,review_report:$report,review_report_sha256:$report_hash,reviewer_approval:$approval}' > "$staged" &&
    chmod 0600 "$staged" && ln -- "$staged" "$auth" && rm -- "$staged" || blocked 'ai-task-gates: MCP authority publication failed.'
  printf 'ai-task-gates: narrow MCP launcher install authorized for %s.\n' "$target"
}

mcp_install_authority_ok(){
  local auth="$1" target="$2" checkout="$3" candidate="$4" report='' source='' evidence=''
  [ -f "$auth" ] && [ ! -L "$auth" ] && [ "$(stat -c %a "$auth")" = 600 ] &&
    [ "$(stat -c %u "$auth")" = "$(id -u)" ] || return 1
  jq -e --arg h "$target" --arg p "$checkout" '.schema_version==1 and .scope=="mcp-launchers" and .target_head==$h and .installed_checkout==$p' "$auth" >/dev/null || return 1
  [ "$(jq -r .policy_digest "$auth")" = "$(install_policy_digest "$target")" ] || return 1
  source="$(jq -r .source_digest "$auth")"
  [ "$source" = "$("$SCRIPT_DIR/ai-review-sandbox" digest "$candidate")" ] || return 1
  report="$(jq -r .review_report "$auth")"
  [ "$(sha256sum "$report" | cut -d' ' -f1)" = "$(jq -r .review_report_sha256 "$auth")" ] || return 1
  evidence="$(review_operation_evidence mcp-launchers-only)" || return 1
  [ "$(printf '%s\n' "$evidence" | sha256sum | cut -d' ' -f1)" = "$(jq -r .host_evidence_sha256 "$auth")" ] || return 1
  mcp_install_review_ok "$report" "$target" "$source" "$checkout" "$candidate" "$evidence"
}

cmd_install_verify_mcp(){
  local phase='' target='' installed='' launcher='' candidate='' auth_dir='' issued='' pending='' completion='' auth='' old='' inventory='' report=''
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --mcp-launchers-only) shift ;;
      --phase) need_value "$@"; phase="$2"; shift 2 ;;
      --target-head) need_value "$@"; target="$2"; shift 2 ;;
      --installed-checkout) need_value "$@"; installed="$2"; shift 2 ;;
      --installed-launcher) need_value "$@"; launcher="$2"; shift 2 ;;
      --stage-report) need_value "$@"; report="$2"; shift 2 ;;
      *) die "unknown option for narrow MCP verification: $1" ;;
    esac
  done
  case "$phase" in preflight|finalize) ;; *) die 'narrow MCP verification needs preflight or finalize.' ;; esac
  [[ "$target" =~ ^[0-9a-f]{40}$ ]] || die 'narrow MCP target must be a full SHA.'
  POLICY_FILE="$ROOT/config/task-gates.json"; require_jq; load_policy; resolve_repo
  candidate="$(cd "$TOPLEVEL" && pwd -P)"; installed="$(cd "$installed" 2>/dev/null && pwd -P)" || blocked 'ai-task-gates: MCP installed checkout unavailable.'
  [ "$candidate" != "$installed" ] && [ "$target" = "$(git -C "$candidate" rev-parse HEAD)" ] || blocked 'ai-task-gates: MCP verifier needs exact target candidate.'
  [ "$target" = "$(git -C "$candidate" rev-parse refs/remotes/origin/main)" ] &&
    [ -z "$(git -C "$candidate" status --porcelain=v1 --untracked-files=all)" ] || blocked 'ai-task-gates: MCP candidate changed.'
  [ "$(git -C "$candidate" rev-parse --path-format=absolute --git-common-dir)" = "$(git -C "$installed" rev-parse --path-format=absolute --git-common-dir)" ] || blocked 'ai-task-gates: MCP Git ownership changed.'
  auth_dir="$STATE_DIR/mcp-launcher-authorizations"; issued="$auth_dir/$target.json"; pending="$issued.consuming"; completion="$STATE_DIR/mcp-launcher-installs/$target.json"
  [ ! -e "$issued" ] || [ ! -e "$pending" ] || blocked 'ai-task-gates: MCP authority state ambiguous.'
  if [ -f "$completion" ] && [ ! -L "$completion" ]; then
    inventory="$(mcp_install_inventory)" || blocked 'ai-task-gates: MCP completed inventory unsafe.'
    jq -e --arg t "$target" --arg p "$installed" --arg h "$(git -C "$installed" rev-parse HEAD)" \
      --arg i "$(printf '%s\n' "$inventory" | sha256sum | cut -d' ' -f1)" \
      '.schema_version==1 and .scope=="mcp-launchers" and .target_head==$t and .installed_checkout==$p and .installed_head==$h and .after_inventory_sha256==$i and .full_install_completed==false' "$completion" >/dev/null || blocked 'ai-task-gates: MCP completed receipt changed.'
    [ "$(jq -r .source_digest "$completion")" = "$("$SCRIPT_DIR/ai-review-sandbox" digest "$candidate")" ] &&
      [ "$(jq -r .policy_digest "$completion")" = "$(install_policy_digest "$target")" ] &&
      [ "$(review_operation_evidence mcp-launchers-only | grep -v '^| mcp launcher baseline digest |' | sha256sum | cut -d' ' -f1)" = "$(jq -r .stable_host_evidence_sha256 "$completion")" ] || blocked 'ai-task-gates: MCP completed source, policy or full-receipt binding changed.'
    if [ "$(mcp_install_platform)" = linux ]; then
      mcp_install_linux_payload_ok || blocked 'ai-task-gates: MCP completed payload changed.'
    else
      . "$ROOT/tools/lib/mcp-launcher-install-windows-verify.sh"
      mcp_install_windows_payload_ok "$completion" || blocked 'ai-task-gates: MCP completed Windows payload changed.'
    fi
    [ ! -e "$issued" ] || blocked 'ai-task-gates: MCP completed receipt has unconsumed issued authority.'
    if [ -e "$pending" ]; then
      [ ! -L "$pending" ] && [ "$(sha256sum "$pending" | cut -d' ' -f1)" = "$(jq -r .authorization_sha256 "$completion")" ] || blocked 'ai-task-gates: MCP completed authority differs.'
      rm -- "$pending" || blocked 'ai-task-gates: MCP completed authority cleanup failed.'
    fi
    printf 'AI_DEVOPS_MCP_INSTALL_RECOVERED=%s\n' "$target"
    return 0
  fi
  if [ "$phase" = preflight ]; then
    auth="$issued"; [ -f "$auth" ] || auth="$pending"
    [ "$(git -C "$installed" rev-parse HEAD)" = "$(jq -r .installed_head "$auth" 2>/dev/null)" ] &&
      [ -z "$(git -C "$installed" status --porcelain=v1 --untracked-files=all)" ] || blocked 'ai-task-gates: MCP installed checkout changed before write.'
    [ "$launcher" = "$(jq -r .installed_launcher "$auth")" ] || blocked 'ai-task-gates: MCP managed gate launcher changed.'
    mcp_install_authority_ok "$auth" "$target" "$installed" "$candidate" || blocked 'ai-task-gates: MCP one-use review or host evidence changed.'
    inventory="$(mcp_install_inventory)" || blocked 'ai-task-gates: MCP destination changed unsafely.'
    [ "$(printf '%s\n' "$inventory" | sha256sum | cut -d' ' -f1)" = "$(jq -r .before_inventory_sha256 "$auth")" ] || blocked 'ai-task-gates: MCP destination changed since review.'
    [ "$auth" = "$pending" ] || mv -- "$issued" "$pending" || blocked 'ai-task-gates: MCP authority reservation failed.'
    printf 'ai-task-gates: narrow MCP preflight passed for %s.\n' "$target"
    return 0
  fi
  [ ! -e "$issued" ] && [ -f "$pending" ] && [ ! -L "$pending" ] && [ ! -e "$completion" ] || blocked 'ai-task-gates: MCP completion state ambiguous.'
  [ "$(git -C "$installed" rev-parse HEAD)" = "$(jq -r .installed_head "$pending")" ] &&
    [ -z "$(git -C "$installed" status --porcelain=v1 --untracked-files=all)" ] || blocked 'ai-task-gates: MCP installed source moved.'
  [ "$launcher" = "$(jq -r .installed_launcher "$pending")" ] || blocked 'ai-task-gates: MCP gate launcher route changed.'
  [ "$(jq -r .source_digest "$pending")" = "$("$SCRIPT_DIR/ai-review-sandbox" digest "$candidate")" ] &&
    [ "$(jq -r .policy_digest "$pending")" = "$(install_policy_digest "$target")" ] &&
    [ "$(sha256sum "$(jq -r .review_report "$pending")" | cut -d' ' -f1)" = "$(jq -r .review_report_sha256 "$pending")" ] || blocked 'ai-task-gates: MCP source or review changed during installation.'
  local final_review final_evidence
  final_review="$(jq -r .review_report "$pending")"
  final_evidence="$(sed '/^## Result$/,$d' "$final_review" | grep '^| mcp ')"
  [ "$(review_operation_evidence mcp-launchers-only | grep -v '^| mcp launcher baseline digest |')" = \
    "$(printf '%s\n' "$final_evidence" | grep -v '^| mcp launcher baseline digest |')" ] || blocked 'ai-task-gates: MCP installed gate, full receipt or runtime host binding changed during installation.'
  mcp_install_review_ok "$final_review" "$target" "$(jq -r .source_digest "$pending")" "$installed" "$candidate" "$final_evidence" || blocked 'ai-task-gates: MCP final review lifecycle changed.'
  if [ "$(mcp_install_platform)" = linux ]; then
    mcp_install_linux_payload_ok || blocked 'ai-task-gates: MCP installed payload differs from reviewed source.'
    "$ROOT/tests/test-mcp-remote-header-freshness.sh" >/dev/null &&
      "$ROOT/tests/test-mcp-session-guard.sh" >/dev/null || blocked 'ai-task-gates: MCP synthetic authorization or session guard proof failed.'
  else
    . "$ROOT/tools/lib/mcp-launcher-install-windows-verify.sh"
    mcp_install_windows_payload_ok "$pending" || blocked 'ai-task-gates: MCP Windows payload or synthetic proof failed.'
  fi
  [ -f "$report" ] && [ ! -L "$report" ] && [ "$(stat -c %a "$report")" = 600 ] || blocked 'ai-task-gates: MCP stage report unavailable.'
  inventory="$(mcp_install_inventory)" || blocked 'ai-task-gates: MCP destination inventory unsafe.'
  jq -e --arg t "$target" --arg p "$installed" --arg i "$inventory" \
    '.schema_version==1 and .scope=="mcp-launchers" and .target_head==$t and .installed_checkout==$p and .after_inventory==$i and .synthetic_probe_pass==true' "$report" >/dev/null || blocked 'ai-task-gates: MCP fixed destinations or synthetic proof incomplete.'
  mkdir -p "$(dirname "$completion")" && chmod 0700 "$(dirname "$completion")" || blocked 'ai-task-gates: MCP partial receipt directory unsafe.'
  local tmp; tmp="$(mktemp "$(dirname "$completion")/.partial.XXXXXXXX")" || blocked 'ai-task-gates: MCP partial receipt stage failed.'
  jq -nc --arg target "$target" --arg old "$(jq -r .installed_head "$pending")" --arg path "$installed" --arg before "$(jq -r .before_inventory_sha256 "$pending")" \
    --arg after "$(printf '%s\n' "$inventory" | sha256sum | cut -d' ' -f1)" --arg stage "$(sha256sum "$report" | cut -d' ' -f1)" --arg auth "$(sha256sum "$pending" | cut -d' ' -f1)" \
    --arg source "$(jq -r .source_digest "$pending")" --arg policy "$(jq -r .policy_digest "$pending")" --arg inventory "$(jq -r .before_inventory "$pending")" \
    --arg host "$(printf '%s\n' "$final_evidence" | grep -v '^| mcp launcher baseline digest |' | sha256sum | cut -d' ' -f1)" \
    '{schema_version:1,scope:"mcp-launchers",installed_head:$old,target_head:$target,installed_checkout:$path,before_inventory:$inventory,before_inventory_sha256:$before,after_inventory_sha256:$after,stage_report_sha256:$stage,authorization_sha256:$auth,source_digest:$source,policy_digest:$policy,stable_host_evidence_sha256:$host,full_install_completed:false}' > "$tmp" &&
    chmod 0600 "$tmp" && mv -- "$tmp" "$completion" || blocked 'ai-task-gates: MCP partial receipt publication failed.'
  rm -- "$pending" || blocked 'ai-task-gates: MCP one-use authority could not be consumed.'
  printf 'ai-task-gates: narrow MCP partial receipt completed at %s; full install remains pending.\n' "$target"
}

# Called only after the normal full gate has published its complete receipt.
# Keep partial evidence, recording which later full receipt superseded it.
mcp_install_supersede_full(){
  local installed="$1" target="$2" receipt="$3" partial tmp old
  [ -f "$receipt" ] && [ ! -L "$receipt" ] || return 1
  jq -e --arg t "$target" --arg p "$installed" '.target_head==$t and .installed_checkout==$p and .scope!="mcp-launchers"' "$receipt" >/dev/null || return 1
  for partial in "$STATE_DIR/mcp-launcher-installs/"*.json; do
    [ -e "$partial" ] || continue
    [ -f "$partial" ] && [ ! -L "$partial" ] || return 1
    [ "$(jq -r .installed_checkout "$partial")" = "$installed" ] || continue
    old="$(jq -r .target_head "$partial")"
    git -C "$installed" merge-base --is-ancestor "$old" "$target" || return 1
    tmp="$(mktemp "$(dirname "$partial")/.superseded.XXXXXXXX")" || return 1
    jq --arg t "$target" --arg r "$(sha256sum "$receipt" | cut -d' ' -f1)" \
      '.superseded_by_full=$t | .full_receipt_sha256=$r' "$partial" > "$tmp" && chmod 600 "$tmp" && mv -- "$tmp" "$partial" || return 1
  done
}
