#!/usr/bin/env bash
# Offline suite for bin/ai-install-transcript-store and bin/ai-transcript-store-run
# (plan_transcript-store.md step 7). Stubs systemctl, op and python; no real
# key, transcript or ScaleDown call is ever touched.
set -u
# The Bash path is Linux-only: the product SKIPs elsewhere (ai-install-transcript-store:29).
[ "$(uname -s)" = Linux ] || { echo "SKIP: transcript store installer is Linux-only"; exit 0; }
PASS=0; FAIL=0
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib-test-harness.sh"
inst="$here/../bin/ai-install-transcript-store"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config"; mkdir -p "$HOME/.config/ai-devops"
mkdir -p "$work/stub"
printf '#!/bin/sh\necho "$*" >> "%s/systemctl.log"\n' "$work" > "$work/stub/systemctl"
printf '#!/bin/sh\n[ "$OP_SERVICE_ACCOUNT_TOKEN" = tok ] || exit 1\necho "$*" >> "%s/op.log"\necho fake-key\n' "$work" > "$work/stub/op"
chmod +x "$work/stub/systemctl" "$work/stub/op"
export AI_TRANSCRIPT_STORE_SYSTEMCTL="$work/stub/systemctl" AI_TRANSCRIPT_STORE_OP="$work/stub/op"
key="$HOME/.config/ai-devops/secrets/scaledown-api-key"
idir="$HOME/.config/ai-devops/transcript-store"
units="$XDG_CONFIG_HOME/systemd/user"

check "install refuses without the 1Password token" '! bash "$inst" >/dev/null 2>&1 && [ ! -e "$key" ]'
printf 'tok\n' > "$HOME/.config/ai-devops/op-service-account"; chmod 600 "$HOME/.config/ai-devops/op-service-account"
out="$(bash "$inst")"; check "install succeeds" '[ $? -eq 0 ]'
check "install output never shows the key" '! printf "%s" "$out" | grep -q fake-key'
check "key stored owner-only from vibe_coding" '[ "$(cat "$key")" = fake-key ] && [ "$(stat -c %a "$key")" = 600 ] && grep -q "op://vibe_coding/scaledown.ai API key for testing" "$work/op.log"'
check "writer copied outside the checkout" '[ -x "$idir/ai-transcript-store-run" ] && [ -f "$idir/transcript_store/build.py" ] && [ -d "$idir/repo-snapshot/skills" ] && [ -f "$idir/repo-snapshot/config/skill-scope.json" ]'
t="$units/ai-transcript-store.timer"
check "timer runs daily at 08:00 and is persistent" 'grep -qx "OnCalendar=\*-\*-\* 08:00:00" "$t" && grep -qx "Persistent=true" "$t"'
check "service runs the installed copy" 'grep -q "%h/.config/ai-devops/transcript-store/ai-transcript-store-run" "$units/ai-transcript-store.service"'
check "timer enabled through systemctl --user" 'grep -q "enable --now ai-transcript-store.timer" "$work/systemctl.log"'
: > "$work/op.log"; bash "$inst" >/dev/null
check "reinstall keeps the stored key without a 1Password read" '[ ! -s "$work/op.log" ]'
check "--check passes after install" 'bash "$inst" --check >/dev/null'
printf '# drift\n' >> "$idir/ai-transcript-store-run"
check "--check detects runner drift" '! bash "$inst" --check >/dev/null'
bash "$inst" >/dev/null
rm -f "$idir/repo-snapshot/config/skill-scope.json"
check "--check detects repo-snapshot config drift" '! bash "$inst" --check >/dev/null'
bash "$inst" >/dev/null

# run wrapper: passes the key by environment and holds the single-writer lock
mkdir -p "$work/py"
cat > "$work/py/python3" <<'PYSTUB'
#!/usr/bin/env python3
import os, sys
script = sys.argv[1]
if script.endswith("build.py"):
    if os.environ.get("SCALEDOWN_API_KEY") != "fake-key":
        sys.exit(9)
    print('{"args": "' + " ".join(sys.argv[2:]) + '"}')
elif script.endswith("mine.py"):
    if "SCALEDOWN_API_KEY" in os.environ:
        sys.stderr.write("SCALEDOWN_API_KEY leaked to mine.py\n")
        sys.exit(11)
    lock_file = os.environ.get("AI_TRANSCRIPT_STORE_LOCK")
    if lock_file:
        import fcntl
        with open(lock_file, "a+") as fh:
            fcntl.flock(fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
    print("MINE_ARGS=" + " ".join(sys.argv[2:]))
    if os.environ.get("FAKE_MINE_FAIL") == "1":
        sys.exit(7)
PYSTUB
chmod +x "$work/py/python3"
export AI_TRANSCRIPT_STORE_PYTHON="$work/py/python3" AI_TRANSCRIPT_STORE_LOGS="$work/logs" AI_TRANSCRIPT_STORE_LOCK="$work/writer.lock"
run="$idir/ai-transcript-store-run"
out="$(bash "$run" --no-publish)"; check "run wrapper succeeds with --no-publish and skips mine" '[ $? -eq 0 ] && [ ! -e "$work"/logs/mine-*.log ]'
check "run log written, key absent" 'grep -q "no-publish" "$work"/logs/run-*.json && ! grep -rq fake-key "$work/logs" && ! printf "%s" "$out" | grep -q fake-key'
out="$(bash "$run")"; check "normal publish run invokes mine.py without key or lock" '[ $? -eq 0 ] && grep -q "MINE_ARGS=skill-bypass" "$work"/logs/mine-*.log && grep -q -- "--repo-root $idir/repo-snapshot" "$work"/logs/mine-*.log && grep -q -- "--since-days 30 --min-sessions 3 --delta" "$work"/logs/mine-*.log'
out="$(FAKE_MINE_FAIL=1 bash "$run")"; check "mine failure does not fail build exit code" '[ $? -eq 0 ] && printf "%s" "$out" | grep -q "transcript-store mine rc=7"'
check "run exits 1 if flock is missing from PATH" '! PATH=/nonexistent /bin/bash "$run" >/dev/null 2>&1'
exec 8>"$work/writer.lock"; flock -n 8
check "second writer skips while the lock is held" 'bash "$run" | grep -q "^SKIP"'
exec 8>&-
chmod 644 "$key"
check "run refuses a key store that is not owner-only" '! bash "$run" >/dev/null 2>&1'
chmod 600 "$key"

bash "$inst" --remove --dry-run >/dev/null
check "dry-run remove changes nothing" '[ -f "$t" ] && [ -d "$idir" ]'
bash "$inst" --remove >/dev/null
check "remove drops timer and copies, keeps the key" '[ ! -e "$t" ] && [ ! -e "$idir" ] && [ -s "$key" ]'
check "--check fails after remove" '! bash "$inst" --check >/dev/null'
printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
