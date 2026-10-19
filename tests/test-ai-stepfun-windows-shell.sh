#!/usr/bin/env bash
# tests/test-ai-stepfun-windows-shell.sh — offline gate contract checks.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$ROOT/bin/ai-stepfun-windows-shell"
FIX="$ROOT/tests/fixtures/stepfun-windows-shell/pkg"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# Real Windows key custody checks require a private native ACL; chmod alone
# does not protect the synthetic key used by the doctor below.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    AI_DEVOPS_PRIVATE_HELPER="$(cygpath -w "$ROOT/bin/windows-private-file.ps1")" \
    AI_DEVOPS_PRIVATE_TARGET="$(cygpath -w "$TMP")" \
    env -u PSModulePath powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command \
      '. $env:AI_DEVOPS_PRIVATE_HELPER; Protect-AiDevOpsPrivatePath -Path $env:AI_DEVOPS_PRIVATE_TARGET -Directory' >/dev/null
    ;;
esac

pass=0; fail=0
check(){ # check "name" cmd...
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf 'ok   %s\n' "$name"; pass=$((pass+1))
  else
    printf 'FAIL %s\n' "$name"; fail=$((fail+1))
  fi
}

mkdir -p "$TMP/folder" "$TMP/host"
echo canary > "$TMP/host/secret.txt"
echo ok > "$TMP/folder/readme.md"
printf 'foo.*bar\n.*\nneedle\n' > "$TMP/folder/search.txt"
awk 'BEGIN { for (i=0; i<205; i++) print "needle" }' > "$TMP/folder/long.txt"
# Git Bash `ln -s` can create a regular copy under a Windows runner account;
# such a copy cannot exercise the path-escape guard. A directory junction does
# not require symlink privilege and Git Bash resolves it as a linked directory.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    powershell.exe -NoProfile -Command "New-Item -ItemType Junction -Path '$(cygpath -w "$TMP/folder/linked")' -Target '$(cygpath -w "$TMP/host")' | Out-Null" </dev/null
    ;;
  *) ln -s "$TMP/host" "$TMP/folder/linked" ;;
esac
if [ ! -L "$TMP/folder/linked" ] ||
   [ "$(cd "$TMP/folder/linked" && pwd -P)" != "$(cd "$TMP/host" && pwd -P)" ]; then
  echo 'FAIL linked fixture is not a real path escape' >&2
  exit 1
fi
export AI_STEPFUN_REVIEW_DIR="$TMP/folder"
export GATE_PATH="/usr/bin:/bin"
export AI_STEPFUN_TEST_MODE=1
export AI_STEPFUN_RUNNERS_JSON="$TMP/no-such-runners.json"

refuses(){ "$GATE" "$@"; [ "$?" -eq 126 ]; }
allows(){ "$GATE" "$@"; }

check 'refuses cat outside folder' bash -c "\"$GATE\" cat \"$TMP/host/secret.txt\"; test \$? -eq 126"
check 'refuses python -c' bash -c "\"$GATE\" python -c print; test \$? -eq 126"
check 'refuses bash -c metachar' bash -c "\"$GATE\" bash -c 'cat /etc/passwd'; test \$? -eq 126"
check 'refuses npx' bash -c "\"$GATE\" npx --yes evil; test \$? -eq 126"
check 'refuses git' bash -c "\"$GATE\" git push; test \$? -eq 126"
check 'refuses parent path' bash -c "\"$GATE\" cat ../host/secret.txt; test \$? -eq 126"
check 'refuses absolute interpreter' bash -c "\"$GATE\" /c/Windows/System32/cmd.exe /c type x; test \$? -eq 126"
check 'refuses env prefix' bash -c "\"$GATE\" FOO=bar cat readme.md; test \$? -eq 126"
check 'refuses npm publish' bash -c "\"$GATE\" npm publish; test \$? -eq 126"
check 'refuses empty' bash -c "\"$GATE\"; test \$? -eq 126"
check 'refuses wsl name' bash -c "\"$GATE\" wsl.exe ls; test \$? -eq 126"

# Allow cat in folder — will fail at runner resolve without allowlist, so we
# only assert it does not exit 126 at the grammar layer. Use a stub runner.
mkdir -p "$TMP/bin"
printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/cat"
printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/npm"
chmod +x "$TMP/bin/cat" "$TMP/bin/npm"
export GATE_PATH="$TMP/bin:/usr/bin:/bin"
check 'allows cat in folder (stub)' bash -c "\"$GATE\" cat readme.md; test \$? -eq 0"
check 'allows npm test (stub)' bash -c "\"$GATE\" npm test; test \$? -eq 0"
check 'allows npm run test:unit (stub)' bash -c "\"$GATE\" npm run test:unit; test \$? -eq 0"
check 'refuses unknown npm flag' bash -c "\"$GATE\" npm --prefix /tmp test; test \$? -eq 126"
check 'allows bounded head' allows head -n 2 search.txt
check 'allows literal grep with metacharacters as data' allows grep -n -F 'foo.*bar' search.txt
check 'allows literal dot-star pattern' allows grep -n -F '.*' search.txt
check 'head output is capped at 200 lines' bash -c 'test "$("$1" head -n 200 long.txt | wc -l)" -eq 200' _ "$GATE"
check 'grep output is capped at 200 matches' bash -c 'test "$("$1" grep -n -F needle long.txt | wc -l)" -eq 200' _ "$GATE"
check 'refuses parent path in head' refuses head -n 2 ../host/secret.txt
check 'refuses parent path in grep' refuses grep -n -F needle ../host/secret.txt
check 'refuses linked directory outside folder' refuses grep -n -F canary linked/secret.txt
check 'refuses Windows absolute path' refuses grep -n -F needle 'C:\Windows\System32\secret.txt'
check 'refuses network path' refuses grep -n -F needle //host/share
check 'refuses head -c' refuses head -c 100 search.txt
check 'refuses head negative count' refuses head -n -1 search.txt
check 'refuses head zero count' refuses head -n 0 search.txt
check 'refuses head huge count' refuses head -n 999999999 search.txt
check 'refuses head glued count' refuses head -n5 search.txt
check 'refuses head short form' refuses head -5 search.txt
check 'refuses head uppercase flag' refuses head -N 5 search.txt
check 'refuses head extra path' refuses head -n 5 search.txt readme.md
check 'refuses recursive grep' refuses grep -r needle .
check 'refuses grep -e' refuses grep -e x -e y search.txt
check 'refuses grep flag terminator' refuses grep -n -F -- needle search.txt
check 'refuses grep glued flag' refuses grep -n5 -F needle search.txt
check 'refuses grep include flag' refuses grep -n -F '--include=*.c' needle search.txt
check 'refuses grep leading-dash pattern' refuses grep -n -F -x search.txt
check 'refuses grep empty pattern' refuses grep -n -F '' search.txt
check 'refuses grep without path' refuses grep -n -F needle
check 'refuses grep multiple paths' refuses grep -n -F needle search.txt readme.md
check 'treats shell metacharacter in grep pattern as data' bash -c '"$1" grep -n -F "needle;cat" search.txt; test $? -eq 1' _ "$GATE"

# Production allowlist/hash path (no test-mode fallback).
export AI_STEPFUN_TEST_MODE=0
mkdir -p "$TMP/stubs2"
printf '#!/bin/sh\nexit 0\n' > "$TMP/stubs2/cat"
chmod +x "$TMP/stubs2/cat"
echo 'missing allowlist refuses' >/dev/null
if AI_STEPFUN_RUNNERS_JSON="$TMP/missing.json" AI_STEPFUN_REVIEW_DIR="$TMP/folder" GATE_PATH="$TMP/stubs2" bash "$GATE" cat r.md >/dev/null 2>&1; then
  echo 'FAIL missing allowlist'; fail=$((fail+1))
else
  echo 'ok   missing allowlist refuses'; pass=$((pass+1))
fi
good_hash="$(sha256sum "$TMP/stubs2/cat" | awk '{print $1}')"
printf '{"cat":{"path":"%s","sha256":"%s"}}\n' "$TMP/stubs2/cat" "$good_hash" > "$TMP/runners.json"
if AI_STEPFUN_RUNNERS_JSON="$TMP/runners.json" AI_STEPFUN_REVIEW_DIR="$TMP/folder" GATE_PATH="$TMP/stubs2" bash "$GATE" cat r.md >/dev/null 2>&1; then
  echo 'ok   valid hash allowlist allows'; pass=$((pass+1))
else
  echo 'FAIL valid hash allowlist'; fail=$((fail+1))
fi
printf '{"cat":{"path":"%s","sha256":"%s"}}\n' "$TMP/stubs2/cat" "deadbeef" > "$TMP/runners-bad.json"
if AI_STEPFUN_RUNNERS_JSON="$TMP/runners-bad.json" AI_STEPFUN_REVIEW_DIR="$TMP/folder" GATE_PATH="$TMP/stubs2" bash "$GATE" cat r.md >/dev/null 2>&1; then
  echo 'FAIL hash mismatch allowed'; fail=$((fail+1))
else
  echo 'ok   hash mismatch refuses'; pass=$((pass+1))
fi
printf '{"cat":{"path":"%s"}}\n' "$TMP/stubs2/cat" > "$TMP/runners-nohash.json"
if AI_STEPFUN_RUNNERS_JSON="$TMP/runners-nohash.json" AI_STEPFUN_REVIEW_DIR="$TMP/folder" GATE_PATH="$TMP/stubs2" bash "$GATE" cat r.md >/dev/null 2>&1; then
  echo 'FAIL missing hash allowed'; fail=$((fail+1))
else
  echo 'ok   missing hash pin refuses'; pass=$((pass+1))
fi

printf '#!/bin/sh\nexit 0\n' > "$TMP/stubs2/grep"
chmod +x "$TMP/stubs2/grep"
grep_hash="$(sha256sum "$TMP/stubs2/grep" | awk '{print $1}')"
printf '{"grep":{"path":"%s","sha256":"%s"}}\n' "$TMP/stubs2/grep" "$grep_hash" > "$TMP/grep-runners.json"
check 'grep pinned binary allows' env AI_STEPFUN_RUNNERS_JSON="$TMP/grep-runners.json" bash "$GATE" grep -n -F needle search.txt
printf '{"grep":{"path":"%s","sha256":"deadbeef"}}\n' "$TMP/stubs2/grep" > "$TMP/grep-runners-bad.json"
check 'grep hash mismatch refuses' env AI_STEPFUN_RUNNERS_JSON="$TMP/grep-runners-bad.json" bash -c '"$1" grep -n -F needle search.txt; test $? -eq 126' _ "$GATE"
printf '{"grep":{"path":"%s","sha256":"%s"}}\n' "$TMP/stubs2/no-such-grep" "$grep_hash" > "$TMP/grep-runners-missing.json"
check 'grep missing binary refuses' env AI_STEPFUN_RUNNERS_JSON="$TMP/grep-runners-missing.json" bash -c '"$1" grep -n -F needle search.txt; test $? -eq 126' _ "$GATE"

# Regression (#1266 residual): jq.exe on Windows ends every -r line with CRLF,
# so the gate compared the pinned path/hash against "<value>\r" and refused
# every runner. A jq shim that reproduces the CRLF artifact must not change
# either outcome.
crlf_bin="$TMP/crlfjq"; mkdir -p "$crlf_bin"
real_jq="$(command -v jq)"
cat > "$crlf_bin/jq" <<SHIM
#!/bin/sh
# jq.exe on Windows: CRLF on every stdout line, exit codes intact (jq -e
# truthiness), so the shim keeps both.
_t="\$(mktemp 2>/dev/null)" || _t="./.jq-crlf.\$\$"
"$real_jq" "\$@" > "\$_t"
_rc=\$?
sed 's/\$/\r/' "\$_t"
rm -f "\$_t"
exit "\$_rc"
SHIM
chmod +x "$crlf_bin/jq"
printf '{"a":"b"}\n' | "$crlf_bin/jq" -r .a | od -c | grep -q '\\r' \
  || { echo 'FAIL crlf jq shim does not emit CR'; fail=$((fail+1)); }
if AI_STEPFUN_RUNNERS_JSON="$TMP/runners.json" AI_STEPFUN_REVIEW_DIR="$TMP/folder" GATE_PATH="$TMP/stubs2" PATH="$crlf_bin:$PATH" bash "$GATE" cat r.md >/dev/null 2>&1; then
  echo 'ok   crlf-emitting jq still allows a valid hash'; pass=$((pass+1))
else
  echo 'FAIL crlf-emitting jq refused a valid hash'; fail=$((fail+1))
fi
if AI_STEPFUN_RUNNERS_JSON="$TMP/runners-bad.json" AI_STEPFUN_REVIEW_DIR="$TMP/folder" GATE_PATH="$TMP/stubs2" PATH="$crlf_bin:$PATH" bash "$GATE" cat r.md >/dev/null 2>&1; then
  echo 'FAIL crlf-emitting jq allowed a hash mismatch'; fail=$((fail+1))
else
  echo 'ok   crlf-emitting jq still refuses a mismatched hash'; pass=$((pass+1))
fi

# The Windows CI lane runs this suite, not test-ai-stepfun.sh. Prove the real
# Git-for-Windows provisioning path for an older list: doctor must leave it
# untouched until --write-runners is explicit, then back it up and re-pin grep.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    printf '#!/bin/sh\n[ "${1:-}" = --version ] && echo 1.18.12\n' > "$TMP/opencode-stub"
    chmod +x "$TMP/opencode-stub"
    printf 'offline-test-key\n' > "$TMP/stepfun-key"
    chmod 600 "$TMP/stepfun-key"
    cp "$TMP/runners.json" "$TMP/doctor-runners.json"
    doctor_runners="$TMP/doctor-runners.json"
    old_hash="$(sha256sum "$doctor_runners" | awk '{print $1}')"
    doctor(){ AI_STEPFUN_ENGINE=opencode AI_STEPFUN_OPENCODE="$TMP/opencode-stub" \
      AI_STEPFUN_STATE_DIR="$TMP/doctor-state" AI_STEPFUN_KEY_STORE="$TMP/stepfun-key" \
      AI_STEPFUN_RUNNERS_JSON="$doctor_runners" "$ROOT/bin/ai-stepfun" doctor "$@"; }
    if doctor > "$TMP/doctor-before.out" 2>&1; then rc=0; else rc=$?; fi
    check 'Windows doctor refuses missing grep and head' bash -c '[ "$1" -ne 0 ] && grep -q "missing required runners: ls,head,grep,bash,sh" "$2"' _ "$rc" "$TMP/doctor-before.out"
    check 'Windows doctor does not silently rewrite old list' test "$(sha256sum "$doctor_runners" | awk '{print $1}')" = "$old_hash"
    if doctor --write-runners > "$TMP/doctor-repin.out" 2>&1; then rc=0; else rc=$?; fi
    check 'Windows explicit repair succeeds' test "$rc" -eq 0
    check 'Windows explicit repair pins all shell verbs' jq -e '(["ls","cat","head","grep","bash","sh"] - keys) == []' "$doctor_runners"
    backups=("$doctor_runners".backup.*)
    check 'Windows explicit repair keeps the original list' cmp -s "$TMP/runners.json" "${backups[0]}"
    check 'Windows doctor accepts the repaired list' doctor
    check 'Windows grep runs through its new pinned binary' env AI_STEPFUN_RUNNERS_JSON="$doctor_runners" bash "$GATE" grep -n -F needle search.txt
    ;;
esac

# stepfun_windows_shell_spawn_resolves — OpenCode's bash tool is spawned by
# Node as `<shell> -c CMD` (incident 20261014T203826Z: ChildProcess.spawn
# NotFound). The door points OpenCode at Git's real bash and confines it with a
# BASH_ENV trampoline into this gate. Extract the real helper from the door and
# drive it through Node's own child_process.spawnSync, not a shell simulation.
DOOR="$ROOT/tools/lib/review-doors/stepfun.sh"
eval "$(sed -n '/^sf_write_windows_bash_env()/,/^}/p' "$DOOR")"
spawn_name='stepfun_windows_shell_spawn_resolves'
if ! declare -F sf_write_windows_bash_env >/dev/null; then
  echo "FAIL $spawn_name: helper missing from door"; fail=$((fail+1))
elif ! command -v node >/dev/null 2>&1; then
  echo "FAIL $spawn_name: node is required to prove a real spawn"; fail=$((fail+1))
else
  if sf_write_windows_bash_env "$TMP/t-missing" "$TMP/no-such-gate" "$TMP/folder" /usr/bin; then
    echo "FAIL $spawn_name: missing gate must fail"; fail=$((fail+1))
  else
    echo "ok   $spawn_name refuses a missing gate"; pass=$((pass+1))
  fi
  sf_write_windows_bash_env "$TMP/bash-env" "$GATE" "$TMP/folder" "/usr/bin:/bin"
  spawn_bash="$(command -v bash)"; spawn_env="$TMP/bash-env"
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) spawn_bash="$(cygpath -w "$spawn_bash")"; spawn_env="$(cygpath -m "$spawn_env")" ;;
  esac
  printf 'echo SCRIPT-RAN\n' > "$TMP/folder/side.sh"
  # node_spawn OUT BASH_ENV ARGS... : real spawnSync of the shell OpenCode uses.
  node_spawn(){
    local out="$1" envf="$2"; shift 2
    (cd "$TMP/folder" && AI_STEPFUN_TEST_MODE=1 AI_STEPFUN_RUNNERS_JSON="$TMP/no-such-runners.json" SPAWN_BASH="$spawn_bash" SPAWN_ENV="$envf" node -e '
      const env = { ...process.env };
      if (process.env.SPAWN_ENV) env.BASH_ENV = process.env.SPAWN_ENV; else delete env.BASH_ENV;
      const r = require("child_process").spawnSync(process.env.SPAWN_BASH, process.argv.slice(1), { env, encoding: "utf8" });
      if (r.error) { console.log("SPAWN-ERROR " + r.error.code); process.exit(99); }
      process.stdout.write(r.stdout + r.stderr); process.exit(r.status === null ? 98 : r.status);' -- "$@") > "$out" 2>&1
  }
  rc=0; node_spawn "$TMP/spawn-raw.out" '' -c 'echo UNGATED' || rc=$?
  check "$spawn_name Node spawn resolves the real bash" \
    bash -c '[ "$1" -eq 0 ] && grep -qx UNGATED "$2"' _ "$rc" "$TMP/spawn-raw.out"
  rc=0; node_spawn "$TMP/spawn-ok.out" "$spawn_env" -c 'head -n 1 readme.md' || rc=$?
  check "$spawn_name allowed command runs through the gate" \
    bash -c '[ "$1" -eq 0 ] && grep -qx ok "$2"' _ "$rc" "$TMP/spawn-ok.out"
  rc=0; node_spawn "$TMP/spawn-bad.out" "$spawn_env" -c 'cat /etc/passwd; echo PWNED' || rc=$?
  check "$spawn_name gate refuses a disallowed command" \
    bash -c '[ "$1" -eq 126 ] && grep -q "stepfun-shell: refused" "$2" && ! grep -q PWNED "$2"' _ "$rc" "$TMP/spawn-bad.out"
  rc=0; node_spawn "$TMP/spawn-script.out" "$spawn_env" side.sh || rc=$?
  check "$spawn_name bash without -c is refused" \
    bash -c '[ "$1" -eq 126 ] && ! grep -q SCRIPT-RAN "$2"' _ "$rc" "$TMP/spawn-script.out"

  # stepfun_windows_opencode_wrapper — OpenCode 1.18.12 (jG) never spawns a
  # bare `bash -c CMD`: it spawns `bash -l -c <multi-line wrapper> opencode
  # <cwd>` with CMD JSON-encoded after eval. Rebuild that exact argv in Node
  # (same template literal) and spawn it for real. TAMPER=1 appends a line.
  node_jg(){ # node_jg OUT CMD CWD [TAMPER]
    local out="$1" cmd="$2" cwd="$3" tamper="${4:-0}"
    (cd "$TMP/folder" && AI_STEPFUN_TEST_MODE=1 AI_STEPFUN_RUNNERS_JSON="$TMP/no-such-runners.json" \
      SPAWN_BASH="$spawn_bash" SPAWN_ENV="$spawn_env" JG_CMD="$cmd" JG_CWD="$cwd" JG_TAMPER="$tamper" node -e '
      const $ = process.env.JG_CMD;
      let w = `
        shopt -s expand_aliases
        [[ -f ~/.bashrc ]] && source ~/.bashrc >/dev/null 2>&1 || true
        cd -- "$1"
        eval ${JSON.stringify($)}
      `;
      if (process.env.JG_TAMPER === "1") w += "echo TAMPERED\n";
      const env = { ...process.env, BASH_ENV: process.env.SPAWN_ENV };
      const r = require("child_process").spawnSync(process.env.SPAWN_BASH,
        ["-l", "-c", w, "opencode", process.env.JG_CWD], { env, encoding: "utf8" });
      if (r.error) { console.log("SPAWN-ERROR " + r.error.code); process.exit(99); }
      process.stdout.write(r.stdout + r.stderr); process.exit(r.status === null ? 98 : r.status);') > "$out" 2>&1
  }
  jg_name='stepfun_windows_opencode_wrapper'
  jg_folder="$TMP/folder"; jg_host="$TMP/host"
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) jg_folder="$(cygpath -w "$jg_folder")"; jg_host="$(cygpath -w "$jg_host")" ;;
  esac
  rc=0; node_jg "$TMP/jg-ok.out" 'head -n 1 readme.md' "$jg_folder" || rc=$?
  check "$jg_name exact wrapper runs the allowed command through the gate" \
    bash -c '[ "$1" -eq 0 ] && grep -qx ok "$2"' _ "$rc" "$TMP/jg-ok.out"
  rc=0; node_jg "$TMP/jg-quote.out" "grep -n -F 'foo.*bar' search.txt" "$jg_folder" || rc=$?
  check "$jg_name quoted operand survives the JSON round trip" \
    bash -c '[ "$1" -eq 0 ] && grep -qx "1:foo.\*bar" "$2"' _ "$rc" "$TMP/jg-quote.out"
  rc=0; node_jg "$TMP/jg-bad.out" 'cat /etc/passwd; echo PWNED' "$jg_folder" || rc=$?
  check "$jg_name gate refuses a disallowed inner command" \
    bash -c '[ "$1" -eq 126 ] && grep -q "stepfun-shell: refused" "$2" && ! grep -q PWNED "$2"' _ "$rc" "$TMP/jg-bad.out"
  rc=0; node_jg "$TMP/jg-tamper.out" 'head -n 1 readme.md' "$jg_folder" 1 || rc=$?
  check "$jg_name refuses a wrapper that differs from OpenCode's" \
    bash -c '[ "$1" -eq 126 ] && grep -q "unrecognised OpenCode wrapper" "$2" && ! grep -q TAMPERED "$2"' _ "$rc" "$TMP/jg-tamper.out"
  rc=0; node_jg "$TMP/jg-cwd.out" 'head -n 1 secret.txt' "$jg_host" || rc=$?
  check "$jg_name refuses a wrapper directory outside the folder" \
    bash -c '[ "$1" -eq 126 ] && ! grep -q canary "$2"' _ "$rc" "$TMP/jg-cwd.out"
fi

printf 'passed=%s failed=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
