#!/usr/bin/env python3
"""Private native failure evidence for runner doors; owner: reviewer infrastructure.

The runner supplies lifecycle-owned storage. Shared by DeepSeek and Gemini so
failure retention and safe summary rules have one home; replaces door-local
copies. Never treat the diagnostic summary as a verdict or source authority.
"""
import hashlib, json, os, pathlib, re, shutil, subprocess, sys
provider, log, err, rc, reason, report, destination = sys.argv[1:]
secrets = (sys.stdin.buffer.read().splitlines()
           if os.environ.get('AI_REVIEW_DIAGNOSTICS_SECRET_STDIN') == '1' else [])
def private_native(source):
    path = pathlib.Path(source)
    if not path.exists(): return b'', 0
    size = path.stat().st_size
    with path.open('rb') as f:
        data = f.read(1048576)
        if size > 1048576:
            f.seek(max(1048576, size - 1048576))
            if size > 2097152: data += b'\n[diagnostic middle truncated]\n'
            data += f.read(1048576)
    for secret in secrets:
        if secret: data = data.replace(secret, b'[REDACTED]')
    data = re.sub(rb'(?i)(Bearer\s+)[A-Za-z0-9._~+/=-]+', rb'\1[REDACTED]', data)
    data = re.sub(rb'(?i)((?:API[_-]?KEY|TOKEN|SECRET|PASSWORD)["\s]*[:=]["\s]*)[^\s,;"}]+',
                  rb'\1[REDACTED]', data)
    return data, size
native_log, log_size = private_native(log)
native_err, err_size = private_native(err)
summary = {'provider': provider, 'exit_code': int(rc), 'reason': reason,
           'native_error_envelopes': 0, 'http_status_codes': [],
           'native_stdout_bytes': log_size, 'native_stderr_bytes': err_size,
           'native_capture_truncated': log_size > 2097152 or err_size > 2097152,
           'native_stdout_sha256': hashlib.sha256(native_log).hexdigest(),
           'native_stderr_sha256': hashlib.sha256(native_err).hexdigest()}
for line in native_log.splitlines():
    try: row = json.loads(line)
    except ValueError: continue
    # Only native error envelopes qualify; assistant/tool text proves nothing.
    if not isinstance(row, dict) or row.get('type') != 'error': continue
    summary['native_error_envelopes'] += 1
    error = row.get('error')
    if isinstance(error, dict):
        data = error.get('data', {})
        code = data.get('statusCode') if isinstance(data, dict) else None
        if isinstance(code, int) and 100 <= code <= 599:
            if code not in summary['http_status_codes']:
                summary['http_status_codes'].append(code)
text = '# Reviewer failed invocation\n\n' + json.dumps(summary, sort_keys=True) + '\n'
def protect_windows(path, directory=False):
    if os.name != 'nt': return
    executable = shutil.which('pwsh') or shutil.which('powershell')
    if not executable: raise ValueError('private diagnostic ACL unavailable')
    helper = pathlib.Path(__file__).resolve().parent.parent / 'bin/windows-private-file.ps1'
    environment = dict(os.environ, AI_DEVOPS_PRIVATE_HELPER=str(helper),
                       AI_DEVOPS_PRIVATE_TARGET=str(path))
    command = ('. $env:AI_DEVOPS_PRIVATE_HELPER; Protect-AiDevOpsPrivatePath '
               '-Path $env:AI_DEVOPS_PRIVATE_TARGET' + (' -Directory' if directory else '') +
               '; Assert-AiDevOpsPrivateAcl -Path $env:AI_DEVOPS_PRIVATE_TARGET')
    result = subprocess.run([executable, '-NoProfile', '-NonInteractive', '-Command', command],
                            capture_output=True, env=environment, timeout=15)
    if result.returncode: raise ValueError('private diagnostic ACL refused')
if destination:
    dest = pathlib.Path(destination)
    # Lifecycle-owned storage, never a model-controlled symlink or old result.
    for ancestor in [dest.parent, *dest.parent.parents]:
        if ancestor.is_symlink(): raise SystemExit('diagnostic storage is linked')
    os.mkdir(dest, 0o700)
    # Secure the empty directory before any native bytes are written. Files
    # inherit only the current user and SYSTEM; verify each file before write.
    protect_windows(dest, directory=True)
    try:
        for data, name in [(native_log, 'native.jsonl'), (native_err, 'native.stderr')]:
            fd = os.open(dest / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, 'wb') as f:
                protect_windows(dest / name)
                f.write(data)
                f.flush(); os.fsync(f.fileno())
        fd = os.open(dest / 'report.md', os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w') as f:
            protect_windows(dest / 'report.md')
            f.write(text); f.flush(); os.fsync(f.fileno())
        if os.name != 'nt':
            fd = os.open(dest, os.O_RDONLY)
            try: os.fsync(fd)
            finally: os.close(fd)
    except Exception:
        # Partial evidence remains private and nonauthorizing for recovery.
        raise
pathlib.Path(report).write_text(text)
