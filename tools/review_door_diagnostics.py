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
def protect_windows(directory, files=()):
    # One PowerShell child secures the directory and every file. The previous
    # per-path spawn cost ~5s each on Windows and blew the suite budget (#1562).
    if os.name != 'nt': return
    executable = shutil.which('pwsh') or shutil.which('powershell')
    if not executable: raise ValueError('private diagnostic ACL unavailable')
    helper = pathlib.Path(__file__).resolve().parent.parent / 'bin/windows-private-file.ps1'
    environment = dict(os.environ, AI_DEVOPS_PRIVATE_HELPER=str(helper),
                       AI_DEVOPS_PRIVATE_DIR=str(directory),
                       AI_DEVOPS_PRIVATE_FILES='\n'.join(str(p) for p in files))
    # PowerShell 7's modules cannot be loaded by Windows PowerShell 5. Rebuild
    # only this trusted child's module path; leave the caller's environment.
    for name in list(environment):
        if name.casefold() == 'psmodulepath':
            environment.pop(name)
    command = ('. $env:AI_DEVOPS_PRIVATE_HELPER; '
               'Protect-AiDevOpsPrivatePath -Path $env:AI_DEVOPS_PRIVATE_DIR -Directory; '
               'foreach ($p in $env:AI_DEVOPS_PRIVATE_FILES -split "`n") { '
               'if ($p) { Protect-AiDevOpsPrivatePath -Path $p } }')
    result = subprocess.run([executable, '-NoProfile', '-NonInteractive',
                             '-ExecutionPolicy', 'Bypass', '-Command', command],
                            capture_output=True, env=environment, timeout=30)
    if result.returncode: raise ValueError('private diagnostic ACL refused')
if destination:
    dest = pathlib.Path(destination)
    # Lifecycle-owned storage, never a model-controlled symlink or old result.
    for ancestor in [dest.parent, *dest.parent.parents]:
        if ancestor.is_symlink(): raise SystemExit('diagnostic storage is linked')
    try:
        os.mkdir(dest, 0o700)
    except FileExistsError:
        # Never lose real evidence to a pre-existing (possibly polluted)
        # directory: keep it untouched, retain this run's evidence beside it,
        # and still fail closed so nothing treats either one as authoritative.
        for attempt in range(100):
            sibling = dest.with_name(f'{dest.name}.collision-{os.getpid()}-{attempt}')
            try: os.mkdir(sibling, 0o700); break
            except FileExistsError: continue
        else:
            raise SystemExit(f'diagnostic storage exists and no collision slot: {dest}')
        dest, collided = sibling, pathlib.Path(destination)
    else:
        collided = None
    # Create the empty files first (no native bytes yet), then one PowerShell
    # invocation secures the directory and every file before any write.
    # ACL refusal removes the empty files so nothing looks like retained evidence.
    payloads = [(native_log, 'native.jsonl'), (native_err, 'native.stderr'),
                (text.encode(), 'report.md')]
    fds = [os.open(dest / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
           for _, name in payloads]
    try:
        protect_windows(dest, [dest / name for _, name in payloads])
        for i, (data, _) in enumerate(payloads):
            with os.fdopen(fds[i], 'wb') as f:
                fds[i] = -1
                f.write(data)
                f.flush(); os.fsync(f.fileno())
    except Exception:
        for fd in fds:
            if fd != -1:
                try: os.close(fd)
                except OSError: pass
        for _, name in payloads:
            try: (dest / name).unlink()
            except OSError: pass
        raise
    if os.name != 'nt':
        fd = os.open(dest, os.O_RDONLY)
        try: os.fsync(fd)
        finally: os.close(fd)
if destination and collided is not None:
    # Fail closed before the caller-visible report is written.
    raise SystemExit(f'diagnostic storage already existed; both retained: {collided} and {dest}')
pathlib.Path(report).write_text(text)
