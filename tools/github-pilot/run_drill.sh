#!/usr/bin/env bash
# run_drill.sh TOOLKIT OUTDIR — run the outage drill with no outbound network.
#
# A user + mount + network namespace gives the drill only a loopback
# interface; tmpfs over HOME and /tmp hides host credentials and state. The
# toolkit checkout is bind-mounted read-only. strace records every connect and
# every write; the audit fails the run on a non-local destination or a write
# outside the disposable storage. Results land in OUTDIR (outside the
# namespace's tmpfs) as drill.json and audit.json only.
set -euo pipefail
TOOLKIT="$(cd "$1" && pwd)"
OUT="$(mkdir -p "$2" && cd "$2" && pwd)"
HOST_HOME="$HOME"
exec env -i PATH=/usr/local/bin:/usr/bin:/bin HOME="$HOST_HOME" TOOLKIT="$TOOLKIT" OUT="$OUT" \
  unshare -rmn --propagation private bash -c '
set -euo pipefail
ip link set lo up
mount --bind "$OUT" "$OUT"
mount -t tmpfs tmpfs /tmp
mkdir -p /tmp/out-bind
mount --bind "$OUT" /tmp/out-bind
mount -t tmpfs tmpfs "$HOME"
mount --bind "$TOOLKIT" "$TOOLKIT"
mount -o remount,bind,ro "$TOOLKIT"
export TMPDIR=/tmp
mkdir -p /tmp/drill
cd /tmp/drill
chmod +x "$TOOLKIT/tools/github-pilot/fixtures/fake_gh.py" 2>/dev/null || true
cp "$TOOLKIT/tools/github-pilot/fixtures/fake_gh.py" /tmp/fake_gh && chmod +x /tmp/fake_gh
set +e
strace -f -y -qq -s 256 -o /tmp/trace \
  -e trace=connect,sendto,sendmsg,openat,open,creat,rename,renameat,renameat2,unlink,unlinkat,mkdir,mkdirat,link,symlink,truncate,chdir,fchdir,clone,clone3,fork,vfork \
  env PILOT_OUT=/tmp/out-bind python3 -B "$TOOLKIT/tools/github-pilot/outage.py" drill /tmp/drill "$TOOLKIT" /tmp/fake_gh 18080 \
  > /tmp/out-bind/drill.json 2> /tmp/out-bind/drill.err
drill_exit=$?
echo "drill_exit=$drill_exit" >> /tmp/out-bind/drill.err
set -e
python3 -B "$TOOLKIT/tools/github-pilot/outage.py" audit /tmp/trace /tmp/drill /tmp "$HOME" /dev \
  > /tmp/out-bind/audit.json
exit "$drill_exit"
'
