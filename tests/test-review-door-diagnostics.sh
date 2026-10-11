#!/usr/bin/env bash
# Offline hostile checks for private native retention and safe summaries.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
python3 - "$ROOT/tools/review_door_diagnostics.py" "$TMP" <<'PYTEST'
import json, os, pathlib, subprocess, sys
helper, root = sys.argv[1], pathlib.Path(sys.argv[2])
log, err = root/'out', root/'err'
secret = b'actual-managed-secret-value'
log.write_bytes(b'{"type":"error","error":{"data":{"statusCode":503,"message":"actual-managed-secret-value"}}}\n')
err.write_bytes(b'Bearer other-secret\nAPI_KEY=third-secret\nactual-managed-secret-value\n')
def run(name, reason='native-error-envelope', rc=1):
    report, dest = root/(name+'.md'), root/name
    env = dict(os.environ, AI_REVIEW_DIAGNOSTICS_SECRET_STDIN='1')
    result = subprocess.run([sys.executable, helper, 'deepseek', str(log), str(err),
                             str(rc), reason, str(report), str(dest)],
                            input=secret+b'\n', env=env, capture_output=True)
    return result, report, dest
result, report, dest = run('first')
assert result.returncode == 0
summary = json.loads(report.read_text().splitlines()[-1])
assert summary['http_status_codes'] == [503] and summary['native_error_envelopes'] == 1
assert secret not in (dest/'native.jsonl').read_bytes()
assert all(x not in (dest/'native.stderr').read_bytes() for x in [secret,b'other-secret',b'third-secret'])
assert secret not in report.read_bytes() and b'503' in report.read_bytes()
if os.name != 'nt':
    assert dest.stat().st_mode & 0o777 == 0o700
    assert (dest/'report.md').stat().st_mode & 0o777 == 0o600
assert run('first')[0].returncode != 0 # old evidence cannot be replaced
log.write_text('{"type":"tool_use","part":{"state":{"status":"error","message":"HTTP 402"}}}\n')
result, report, _ = run('tool-failure', 'native-execution-failed', 124)
summary = json.loads(report.read_text().splitlines()[-1])
assert summary['http_status_codes'] == [] and summary['native_error_envelopes'] == 0
assert summary['exit_code'] == 124
log.write_bytes(b'x' * 3000000)
result, report, dest = run('large')
assert result.returncode == 0
assert json.loads(report.read_text().splitlines()[-1])['native_capture_truncated']
assert (dest/'native.jsonl').stat().st_size < 2100000
if os.name != 'nt':
    (root/'linked-parent').symlink_to(root, target_is_directory=True)
    result = subprocess.run([sys.executable, helper, 'deepseek', str(log), str(err), '1',
                             'native-execution-failed', str(root/'linked.md'),
                             str(root/'linked-parent'/'forbidden')], capture_output=True)
    assert result.returncode != 0 and not (root/'forbidden').exists()
print('Private diagnostic checks passed: classification, secret redaction, permissions, immutable evidence, timeout/tool distinction, bounded capture, linked-parent refusal.')
PYTEST
