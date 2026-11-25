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
export TMPDIR=/tmp
mount -t tmpfs tmpfs "$TMPDIR"
mkdir -p "$TMPDIR/out-bind"
mount --bind "$OUT" "$TMPDIR/out-bind"
mount -t tmpfs tmpfs "$HOME"
mount --bind "$TOOLKIT" "$TOOLKIT"
mount -o remount,bind,ro "$TOOLKIT"
mkdir -p "$TMPDIR/drill"
cd "$TMPDIR/drill"
chmod +x "$TOOLKIT/tools/github-pilot/fixtures/fake_gh.py" 2>/dev/null || true
cp "$TOOLKIT/tools/github-pilot/fixtures/fake_gh.py" "$TMPDIR/fake_gh" && chmod +x "$TMPDIR/fake_gh"
set +e
strace -f -y -qq -s 256 -o "$TMPDIR/trace" \
  -e trace=connect,sendto,sendmsg,openat,open,creat,rename,renameat,renameat2,unlink,unlinkat,mkdir,mkdirat,link,symlink,truncate,chdir,fchdir,clone,clone3,fork,vfork \
  env PILOT_OUT="$TMPDIR/out-bind" python3 -B "$TOOLKIT/tools/github-pilot/outage.py" drill "$TMPDIR/drill" "$TOOLKIT" "$TMPDIR/fake_gh" 18080 \
  > "$TMPDIR/out-bind/drill.json" 2> "$TMPDIR/out-bind/drill.err"
echo "drill_exit=$?" >> "$TMPDIR/out-bind/drill.err"
python3 -B "$TOOLKIT/tools/github-pilot/outage.py" audit "$TMPDIR/trace" "$TMPDIR/drill" "$TMPDIR" "$HOME" /dev \
  > "$TMPDIR/out-bind/audit.json"
'
