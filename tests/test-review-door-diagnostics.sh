#!/usr/bin/env bash
# Offline hostile checks for private native retention and safe summaries.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
python3 - "$ROOT/tools/review_door_diagnostics.py" "$TMP" <<'PYTEST'
import json, os, pathlib, shutil, subprocess, sys
helper, root = sys.argv[1], pathlib.Path(sys.argv[2])
log, err = root/'out', root/'err'
secret = b'actual-managed-secret-value'
log.write_bytes(b'{"type":"error","error":{"data":{"statusCode":503,"message":"actual-managed-secret-value"}}}\n')
err.write_bytes(b'Bearer other-secret\nAPI_KEY=third-secret\nactual-managed-secret-value\n')
def run(name, reason='native-error-envelope', rc=1, extra_environment=None):
    report, dest = root/(name+'.md'), root/name
    env = dict(os.environ, AI_REVIEW_DIAGNOSTICS_SECRET_STDIN='1')
    env.update(extra_environment or {})
    result = subprocess.run([sys.executable, helper, 'deepseek', str(log), str(err),
                             str(rc), reason, str(report), str(dest)],
                            input=secret+b'\n', env=env, capture_output=True)
    return result, report, dest
result, report, dest = run('first')
assert result.returncode == 0, result.stderr.decode(errors='replace')
summary = json.loads(report.read_text().splitlines()[-1])
assert summary['http_status_codes'] == [503] and summary['native_error_envelopes'] == 1
assert secret not in (dest/'native.jsonl').read_bytes()
assert all(x not in (dest/'native.stderr').read_bytes() for x in [secret,b'other-secret',b'third-secret'])
assert secret not in report.read_bytes() and b'503' in report.read_bytes()
if os.name != 'nt':
    assert dest.stat().st_mode & 0o777 == 0o700
    assert (dest/'report.md').stat().st_mode & 0o777 == 0o600
original = {f.name: f.read_bytes() for f in dest.iterdir()}
again = run('first')[0]
assert again.returncode != 0 # old evidence cannot be replaced
assert {f.name: f.read_bytes() for f in dest.iterdir()} == original
# A pre-existing (e.g. test-stub polluted) directory never loses real evidence:
# both are retained and the call still fails closed (#1562 WinError 183).
polluted = root/'polluted'
polluted.mkdir(); (polluted/'stub.txt').write_text('STUB dir=x PWD!=DIR\n')
result, report, _ = run('polluted')
assert result.returncode != 0 and b'both retained' in result.stderr
assert (polluted/'stub.txt').read_text() == 'STUB dir=x PWD!=DIR\n'
kept = [d for d in root.iterdir() if d.name.startswith('polluted.collision-')]
assert len(kept) == 1 and (kept[0]/'report.md').exists()
assert secret not in (kept[0]/'native.jsonl').read_bytes()
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
else:
    # Actual Windows PowerShell fallback under a PowerShell 7 parent's
    # incompatible modules and restrictive process policy. No machine policy
    # changes, mock ACL cmdlets, providers or real credentials are involved.
    powershell = shutil.which('powershell')
    assert powershell, 'supported Windows PowerShell fallback is missing'
    child_path = os.pathsep.join([str(pathlib.Path(powershell).parent),
                                 str(pathlib.Path(os.environ['SystemRoot'])/'System32')])
    inherited = {'PATH': child_path, 'PSExecutionPolicyPreference': 'Restricted',
                 'PSModulePath': str(root/'incompatible-parent-modules')}
    (root/'incompatible-parent-modules').mkdir()
    parent_environment = dict(os.environ)
    log.write_text('synthetic failed native invocation\n')
    result, report, dest = run('mixed-shell', extra_environment=inherited)
    assert result.returncode == 0, result.stderr.decode(errors='replace')
    assert (dest/'native.jsonl').read_text() == log.read_text()
    # Independently inspect real private ACLs without the hostile inherited
    # environment. Failure must still leave no native bytes when ACL refuses.
    acl_helper = pathlib.Path(helper).resolve().parent.parent/'bin/windows-private-file.ps1'
    env = dict(os.environ, AI_DEVOPS_PRIVATE_HELPER=str(acl_helper),
               AI_DEVOPS_PRIVATE_TARGET=str(dest))
    for name in list(env):
        if name.casefold() == 'psmodulepath':
            env.pop(name)
    code = '. $env:AI_DEVOPS_PRIVATE_HELPER; Assert-AiDevOpsPrivateAcl -Path $env:AI_DEVOPS_PRIVATE_TARGET; Get-ChildItem -LiteralPath $env:AI_DEVOPS_PRIVATE_TARGET | ForEach-Object { Assert-AiDevOpsPrivateAcl -Path $_.FullName }'
    checked = subprocess.run([powershell, '-NoProfile', '-NonInteractive',
                              '-ExecutionPolicy', 'Bypass', '-Command', code],
                             env=env, capture_output=True)
    assert checked.returncode == 0, checked.stderr.decode(errors='replace')
    refused, _, refused_dest = run('acl-refusal', extra_environment=dict(inherited, AI_DEVOPS_TEST_ICACLS_FAIL='1'))
    assert refused.returncode != 0
    assert not (refused_dest/'native.jsonl').exists()
    assert dict(os.environ) == parent_environment
    print('Windows mixed-shell diagnostic custody passed: restrictive policy, inherited modules, real private ACLs, refusal before bytes, parent environment unchanged.')
print('Private diagnostic checks passed: classification, secret redaction, permissions, immutable evidence, timeout/tool distinction, bounded capture, linked-parent refusal.')
PYTEST
