# stepfun-sandbox.sh — the one bubblewrap launch for every StepCode turn.
#
# Sourced by bin/ai-stepfun (ask, review, implement, doctor --live) and by the
# shared-runner door tools/lib/review-doors/stepfun.sh, so a health check and
# a real review start StepCode the same way. Two copies drifted once: the door
# mounted /usr but not the /lib64 link, so the dynamic loader was missing and
# every door call failed with "execvp ...: No such file or directory" while
# doctor (the wrapper's copy) stayed green.
#
# Visible inside: /usr, the /bin and /lib links, a short /etc allowlist (never
# /etc whole: it can hold secrets such as /etc/environment, #1086), StepCode's
# own directory, and whatever the caller adds. Empty: home, /tmp, /run. The
# environment is cleared to STEPFUN_SANDBOX_ENV_ALLOW, so caller tokens
# (OP_SERVICE_ACCOUNT_TOKEN, GH_TOKEN, SSH_AUTH_SOCK, ...) never reach the model.

STEPFUN_SANDBOX_ENV_ALLOW=" LANG LC_ALL TERM SSL_CERT_FILE SSL_CERT_DIR HOME PATH STEP_API_KEY STEP_BASE_URL STEP_AUTOPILOT STEP_CODING_AGENT_DIR "

# stepfun_sys_binds: fills the caller's sys_binds array with the read-only
# system trees a sandboxed program needs; never `/` itself.
stepfun_sys_binds(){
  sys_binds=(--ro-bind /usr /usr)
  local top
  for top in /bin /sbin /lib /lib32 /lib64 /libx32; do
    if [ -L "$top" ]; then sys_binds+=(--symlink "$(readlink "$top")" "$top")
    elif [ -d "$top" ]; then sys_binds+=(--ro-bind "$top" "$top"); fi
  done
  sys_binds+=(--dir /etc)
  local e
  for e in /etc/passwd /etc/group /etc/nsswitch.conf /etc/resolv.conf /etc/hosts /etc/host.conf /etc/gai.conf /etc/ld.so.cache /etc/ld.so.conf /etc/ld.so.conf.d /etc/localtime /etc/timezone /etc/alternatives /etc/ssl/certs /etc/ca-certificates /etc/ca-certificates.conf /etc/pki/tls/certs /etc/mime.types /etc/protocols /etc/services /etc/os-release /etc/lsb-release /etc/debian_version /etc/inputrc /etc/bash.bashrc /etc/profile /etc/locale.alias /etc/gitattributes; do
    { [ -e "$e" ] || [ -L "$e" ]; } && sys_binds+=(--ro-bind "$e" "$e")
  done
  return 0
}

# stepfun_sandbox_exec BWRAP TIMEOUT_BIN SECONDS BIN [EXTRA_BWRAP_ARGS...] -- [BIN_ARGS...]
# Replaces the current process; call it inside a subshell after exporting
# HOME, PATH and the STEP_* variables. HOME is mounted as an empty tmpfs.
stepfun_sandbox_exec(){
  local bwrap="$1" timeout_bin="$2" secs="$3" bin="$4" name
  shift 4
  local -a extra=() sys_binds=()
  while [ "$#" -gt 0 ] && [ "$1" != -- ]; do extra+=("$1"); shift; done
  [ "$#" -gt 0 ] && shift
  stepfun_sys_binds
  for name in $(compgen -e); do
    case "$STEPFUN_SANDBOX_ENV_ALLOW" in *" $name "*) ;; *) unset "$name" 2>/dev/null || true ;; esac
  done
  exec "$timeout_bin" "$secs" "$bwrap" --die-with-parent --unshare-all --share-net \
    "${sys_binds[@]}" --dev /dev --proc /proc --tmpfs /tmp --tmpfs /run \
    --ro-bind-try /run/systemd/resolve /run/systemd/resolve \
    --tmpfs "$HOME" \
    --ro-bind "$(dirname "$bin")" "$(dirname "$bin")" \
    "${extra[@]}" -- "$bin" "$@"
}
