#!/usr/bin/env python3
"""#396: scoped admission observations in the existing quarantine store.

This is policy backoff, never an authoritative quota or reset-time adapter.
OS locks release on process death; atomic replacement preserves prior evidence.
"""
import argparse
import contextlib
import hashlib
import json
import os
import pathlib
import re
import tempfile
import time


def scope_key(profile, model):
    return hashlib.sha256(json.dumps([profile, model], separators=(',', ':')).encode()).hexdigest()


def home_profile(home):
    if not isinstance(home, str) or not home:
        raise ValueError('credential home path is required for profile identity')
    # Resolve filesystem spelling, symlinks and Windows junction/case aliases.
    # Only path metadata is used; credential files are never opened or hashed.
    canonical = os.path.realpath(home)
    return {'credential_profile_scope': hashlib.sha256(canonical.encode('utf-8')).hexdigest(),
            'source_kind': 'canonical-home-path', 'credential_home': canonical}


def valid_scope(profile, model):
    return all(isinstance(v, str) and 0 < len(v) <= 128 and not any(ord(c) < 32 for c in v)
               for v in (profile, model))


def valid_global(record, provider):
    return (isinstance(record, dict) and record.get('provider') == provider
            and type(record.get('expires_epoch')) is int
            and type(record.get('created_epoch')) is int
            and isinstance(record.get('failure_class'), str))


@contextlib.contextmanager
def locked(directory, provider):
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    lock_path = directory / (provider + '.lock')
    if lock_path.is_symlink():
        raise ValueError('linked admission lock refused')
    with open(lock_path, 'a+b') as handle:
        if handle.tell() == 0:
            handle.write(b'0'); handle.flush()
        deadline = time.monotonic() + 5
        while True:
            try:
                handle.seek(0)
                if os.name == 'nt':
                    import msvcrt
                    msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
                else:
                    import fcntl
                    fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except OSError:
                if time.monotonic() >= deadline:
                    raise ValueError('admission store busy')
                time.sleep(0.02)
        try:
            yield
        finally:
            handle.seek(0)
            if os.name == 'nt':
                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(handle, fcntl.LOCK_UN)


def load(directory, provider):
    path = directory / (provider + '.json')
    if path.is_symlink():
        raise ValueError('linked admission record refused')
    if not path.exists():
        return {'version': 2, 'provider': provider, 'global': None, 'backoffs': {}}
    data = json.loads(path.read_text(encoding='utf-8-sig'))
    if not isinstance(data, dict) or data.get('provider') != provider:
        raise ValueError('invalid admission record provider')
    if data.get('version') == 1:
        if not valid_global(data, provider):
            raise ValueError('invalid legacy quarantine')
        return {'version': 2, 'provider': provider, 'global': data, 'backoffs': {}}
    if data.get('version') != 2 or not isinstance(data.get('backoffs'), dict):
        raise ValueError('invalid admission record schema')
    if data.get('global') is not None and not valid_global(data['global'], provider):
        raise ValueError('invalid global quarantine')
    for key, record in data['backoffs'].items():
        if not isinstance(record, dict):
            raise ValueError('invalid scoped admission record')
        profile, model = record.get('credential_profile_scope'), record.get('model_scope')
        if (not valid_scope(profile, model) or key != scope_key(profile, model)
                or type(record.get('observed_epoch')) is not int
                or type(record.get('expires_epoch')) is not int
                or not 0 < record['expires_epoch'] - record['observed_epoch'] <= 86400
                or not isinstance(record.get('source_run_id'), str)
                or not 0 < len(record['source_run_id']) <= 160
                or record.get('reason') != 'usage-limit'
                or not re.fullmatch('[0-9a-f]{64}', str(record.get('evidence_sha256', '')))
                or record.get('quota_state') != 'unknown' or record.get('reset_at') is not None):
            raise ValueError('invalid scoped admission record')
    return data


def publish(directory, provider, data):
    descriptor, name = tempfile.mkstemp(prefix='.admission-', dir=directory)
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8', newline='\n') as output:
            json.dump(data, output, sort_keys=True, allow_nan=False)
            output.write('\n'); output.flush(); os.fsync(output.fileno())
        os.replace(name, directory / (provider + '.json'))
    finally:
        if os.path.exists(name):
            os.unlink(name)


def admission(data, profile, model, now):
    result = {'schema_version': 1, 'provider': data['provider'], 'state': 'eligible',
              'reason': 'no-applicable-backoff', 'quota_state': 'unknown', 'reset_at': None,
              'credential_profile_scope': profile or None, 'model_scope': model or None}
    if not valid_scope(profile, model):
        result.update(state='unknown', reason='unscopable')
        return result
    record = data['backoffs'].get(scope_key(profile, model))
    if record and record.get('credential_profile_scope') == profile and record.get('model_scope') == model:
        observed, expires = record.get('observed_epoch'), record.get('expires_epoch')
        if type(observed) is int and type(expires) is int and observed <= now < expires:
            result.update(state='backoff', reason='observed-usage-limit',
                          policy_expires_epoch=expires, source_run_id=record.get('source_run_id'),
                          evidence_sha256=record.get('evidence_sha256'))
    return result


def observe(directory, provider, profile, model, run_id, observed, now, seconds, evidence, reason):
    if reason != 'usage-limit' or not valid_scope(profile, model) or not run_id or len(run_id) > 160:
        raise ValueError('unscopable or unsupported refusal observation')
    if type(observed) is not int or not 0 <= now - observed <= 120:
        raise ValueError('stale or future refusal observation')
    if type(seconds) is not int or not 1 <= seconds <= 86400:
        raise ValueError('backoff policy must be between one second and one day')
    if not evidence.is_file() or evidence.is_symlink():
        raise ValueError('retained refusal evidence is unavailable')
    hasher = hashlib.sha256()
    with evidence.open('rb') as source:
        before = os.fstat(source.fileno())
        for chunk in iter(lambda: source.read(65536), b''):
            hasher.update(chunk)
        after = os.fstat(source.fileno())
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise ValueError('retained refusal evidence changed while reading')
    digest = hasher.hexdigest()
    key = scope_key(profile, model)
    with locked(directory, provider):
        data = load(directory, provider)
        if any(old_key != key and record.get('source_run_id') == run_id
               for old_key, record in data['backoffs'].items()):
            raise ValueError('refusal run identity cannot change scope')
        previous = data['backoffs'].get(key)
        if previous and previous.get('source_run_id') == run_id:
            if previous.get('evidence_sha256') != digest or previous.get('observed_epoch') != observed:
                raise ValueError('conflicting refusal evidence for the same run')
            return admission(data, profile, model, now)  # replay does not extend expiry
        if previous and previous.get('observed_epoch', -1) > observed:
            return admission(data, profile, model, now)
        data['backoffs'][key] = {
            'credential_profile_scope': profile, 'model_scope': model,
            'source_run_id': run_id, 'observed_epoch': observed,
            'expires_epoch': observed + seconds, 'reason': reason,
            'evidence_sha256': digest, 'quota_state': 'unknown', 'reset_at': None,
        }
        publish(directory, provider, data)
        return admission(data, profile, model, now)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('profile', 'admission', 'observe', 'quarantine', 'global', 'clear'))
    parser.add_argument('provider', choices=('claude','codex','deepseek','gemini','glm','grok','kimi','muse','qwen'))
    parser.add_argument('--directory', type=pathlib.Path, required=True)
    parser.add_argument('--profile', default=''); parser.add_argument('--model', default='')
    parser.add_argument('--home')
    parser.add_argument('--run-id', default=''); parser.add_argument('--observed', type=int)
    parser.add_argument('--seconds', type=int, default=1800); parser.add_argument('--reason', default='')
    parser.add_argument('--evidence', type=pathlib.Path)
    args = parser.parse_args()
    now = int(time.time())
    if args.action == 'profile':
        result = home_profile(args.home)
    elif args.action == 'observe':
        result = observe(args.directory, args.provider, args.profile, args.model, args.run_id,
                         args.observed, now, args.seconds, args.evidence or pathlib.Path(''), args.reason)
    elif args.action == 'admission':
        result = admission(load(args.directory, args.provider), args.profile, args.model, now)
    else:
        with locked(args.directory, args.provider):
            data = load(args.directory, args.provider)
            if args.action == 'clear':
                data = {'version': 2, 'provider': args.provider, 'global': None, 'backoffs': {}}
                publish(args.directory, args.provider, data); result = {'cleared': True}
            elif args.action == 'quarantine':
                if args.seconds <= 0:
                    raise ValueError('quarantine seconds must be positive')
                data['global'] = {'version': 1, 'provider': args.provider, 'failure_class': args.reason,
                                  'created_epoch': now, 'expires_epoch': now + args.seconds}
                publish(args.directory, args.provider, data); result = data['global']
            else:
                result = data.get('global')
                if result and result.get('expires_epoch', 0) <= now:
                    data['global'] = None; publish(args.directory, args.provider, data); result = None
    print(json.dumps(result, sort_keys=True, allow_nan=False))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, TypeError) as error:
        raise SystemExit('reviewer admission: ' + str(error))
