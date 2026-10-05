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
import sys
import tempfile
import time

CREDIT_EXIT = 92
CREDIT_SECONDS = 3600
CREDIT_SCAN_BYTES = 1 << 20
# Billing/credit exhaustion only. A plain rate limit, a bare RESOURCE_EXHAUSTED
# or "quota exhausted" is not proof the account needs money, so it never matches.
# Sources: real provider error bodies (xAI 403 team-credit text, OpenAI-style
# insufficient_quota used by Meta and DeepSeek-compatible APIs, DeepSeek 402
# "Insufficient Balance", DashScope Arrearage / FreeTierOnly / prepayment, and
# Gemini "prepayment credits are depleted").
CREDIT_PATTERNS = tuple(re.compile(p) for p in (
    r'insufficient[ _-]?(balance|credits?|funds)',
    r'insufficient_quota',
    r'out of credits?\b',
    r'credit balance is too low',
    r'(used|exhausted|depleted|spent) (all )?(of )?(your |its |the )?(available )?credits?',
    r'credits? (are|have been|has been|is) (depleted|exhausted|used up|exceeded)',
    r'\bpayment required\b',
    r'monthly spending limit',
    r'(purchase|buy|add) (more )?credits',
    r'make sure your account is in good standing|account is not in good standing',
))
# DashScope (Qwen) status codes are meaningful only in Qwen's own errors.
PROVIDER_CREDIT_PATTERNS = {'qwen': tuple(re.compile(p) for p in (
    r'\barrearage\b',
    r'\bfreetieronly\b',
    r'free tier of the model has been exhausted',
    r'\bout_of_service\b',
)),
    # StepFun: HTTP 402 with type quota_exceeded is its unpaid-balance reply.
    'stepfun': tuple(re.compile(p) for p in (
        r'\b402\b.*quota_exceeded',
        r'exceeded your current quota, please check your plan and billing details',
    )),
}
# DashScope uses insufficient_quota for rate limiting too, so it proves nothing
# about Qwen's balance; Qwen relies on its own status codes above.
PROVIDER_EXCLUDED_PATTERNS = {'qwen': ('insufficient_quota',)}
# #1115 failure streams. Provider-side policy and downtime must not enter the
# code-defect stream. A bare HTTP 404 (or 403) is code/config unless separate
# credit, capacity, or provider-down evidence appears in the same text.
STREAM_OUTAGE = 'provider-outage'
STREAM_CODE = 'code-defect'
# Terminal usage-limit refusals reuse the existing observe() reason name.
USAGE_LIMIT_PATTERNS = tuple(re.compile(p) for p in (
    r'usage[ _-]?limit',
    r'exceeded (your |the )?(current |daily |monthly )?usage',
    r'terminal["\s:=]+usage-limit',
))
# Quota/rate/allowance policy. Not "needs money" and not a code defect.
CAPACITY_PATTERNS = tuple(re.compile(p) for p in (
    r'rate[ _-]?limit',
    r'too many requests',
    r'\bhttp[ /_-]?429\b',
    r'\bstatus[ :=]+429\b',
    r'resource_exhausted',
    r'insufficient_quota',
    r'quota.{0,24}(exceed|exhaust|reached|deplet)',
    r'(exceed|exhaust|reach|deplet).{0,24}quota',
    r'allowance.{0,24}(exceed|exhaust|reached)',
    r'throttl',
))
# Provider transport/downtime only. Deliberately excludes bare 403/404/429.
PROVIDER_DOWN_PATTERNS = tuple(re.compile(p) for p in (
    r'connection (refused|reset|aborted|closed|failed)',
    r'network is unreachable|no route to host',
    r'service (is )?unavailable',
    r'temporarily unavailable',
    r'\bbad gateway\b',
    r'gateway[ _-]?(time-?out|error)',
    r'\bhttp[ /_-]?50[234]\b',
    r'\bstatus[ :=]+50[234]\b',
    r'econnrefused|econnreset|etimedout|epipe',
    r'connection timed out',
    r'upstream (is )?(unavailable|unreachable|down)',
    r'dns (lookup|resolution) (failed|error)',
))
CREDIT_MESSAGES = {
    'grok': 'the xAI (Grok) account has run out of credits or hit its monthly spending limit - add credits at https://console.x.ai',
    'muse': 'the Meta (Muse) API account has run out of credits - add credits at https://dev.meta.ai',
    'qwen': 'the Alibaba Model Studio (Qwen) account is out of balance or its free quota is used up - top up at https://usercenter2-intl.console.alibabacloud.com/billing/#/account/overview',
    'gemini': 'the Google Gemini API project has run out of prepaid credits - add credits at https://ai.studio/projects',
    'deepseek': 'the DeepSeek account balance is used up - top up at https://platform.deepseek.com/top_up',
    'stepfun': 'the StepFun (Step 5) API account is out of credit - add credits at https://platform.stepfun.ai',
}


def credit_match_text(text, provider=None):
    """Return the first matching credit pattern name for already-read text."""
    for pattern in CREDIT_PATTERNS + PROVIDER_CREDIT_PATTERNS.get(provider, ()):
        if pattern.pattern in PROVIDER_EXCLUDED_PATTERNS.get(provider, ()):
            continue
        if pattern.search(text):
            return pattern.pattern
    return None


def credit_match(paths, provider=None):
    """Return the first matching evidence line, or None. Reads each file's tail only."""
    for path in paths:
        try:
            if path.is_symlink() or not path.is_file():
                continue
            with path.open('rb') as source:
                size = source.seek(0, os.SEEK_END)
                source.seek(max(0, size - CREDIT_SCAN_BYTES))
                text = source.read().decode('utf-8', 'replace').lower()
        except OSError:
            continue
        matched = credit_match_text(text, provider)
        if matched is not None:
            return matched
    return None


def classify_event(text, provider=None):
    """Return the failure stream and class for one failure text blob.

    Reuses the existing credit/usage-limit evidence classes and extends them
    with capacity and provider-down. A bare HTTP 404 or 403 stays code-config:
    those are usually a wrong path, model name, or permission setting.
    """
    lowered = (text or '').lower()
    if credit_match_text(lowered, provider) is not None:
        return STREAM_OUTAGE, 'credit'
    for patterns in (USAGE_LIMIT_PATTERNS, CAPACITY_PATTERNS, PROVIDER_DOWN_PATTERNS):
        for pattern in patterns:
            if pattern.search(lowered):
                if patterns is USAGE_LIMIT_PATTERNS:
                    return STREAM_OUTAGE, 'usage-limit'
                if patterns is CAPACITY_PATTERNS:
                    return STREAM_OUTAGE, 'capacity'
                return STREAM_OUTAGE, 'outage'
    return STREAM_CODE, 'code-config'


def credit(directory, provider, paths, record, seconds):
    """Exit 0 with the two contract lines on a match, 3 on no match."""
    if provider not in CREDIT_MESSAGES:
        raise ValueError('no out-of-credit message for provider')
    if credit_match(paths, provider) is None:
        return 3
    machine = 'AI_REVIEWER_OUT_OF_CREDIT provider=%s code=insufficient_quota' % provider
    human = 'OUT OF CREDIT: %s - then run: ai-review-preflight clear %s' % (CREDIT_MESSAGES[provider], provider)
    print(machine); print(human)
    if record:
        # A recording failure must never hide the diagnosis or delay the stop.
        try:
            with locked(directory, provider):
                data = load(directory, provider)
                now = int(time.time())
                data['global'] = {'version': 1, 'provider': provider, 'failure_class': 'out-of-credit',
                                  'created_epoch': now, 'expires_epoch': now + seconds}
                publish(directory, provider, data)
        except (OSError, ValueError, TypeError) as error:
            print('reviewer admission: out-of-credit quarantine not recorded: ' + str(error), file=sys.stderr)
    return 0


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


def classify(paths, extra_text, provider):
    """Classify failure evidence into (stream, class). Scans file tails only."""
    chunks = []
    for path in paths:
        try:
            if path.is_symlink() or not path.is_file():
                continue
            with path.open('rb') as source:
                size = source.seek(0, os.SEEK_END)
                source.seek(max(0, size - CREDIT_SCAN_BYTES))
                chunks.append(source.read().decode('utf-8', 'replace'))
        except OSError:
            continue
    if extra_text:
        chunks.append(extra_text)
    return classify_event('\n'.join(chunks), provider)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('profile', 'admission', 'observe', 'quarantine', 'global', 'clear', 'clear-global', 'credit', 'classify'))
    parser.add_argument('provider', choices=('claude','codex','deepseek','gemini','glm','grok','kimi','muse','qwen','stepfun'))
    parser.add_argument('--directory', type=pathlib.Path)
    parser.add_argument('--profile', default=''); parser.add_argument('--model', default='')
    parser.add_argument('--home')
    parser.add_argument('--run-id', default=''); parser.add_argument('--observed', type=int)
    parser.add_argument('--seconds', type=int, default=1800); parser.add_argument('--reason', default='')
    parser.add_argument('--evidence', type=pathlib.Path)
    parser.add_argument('--expect-record', default='')
    parser.add_argument('--scan', type=pathlib.Path, action='append', default=[])
    parser.add_argument('--text', default='')
    parser.add_argument('--record', action='store_true')
    args = parser.parse_args()
    now = int(time.time())
    if args.action == 'classify':
        stream, failure_class = classify(args.scan, args.text, args.provider)
        print(json.dumps({'stream': stream, 'failure_class': failure_class}, sort_keys=True))
        return
    if args.directory is None:
        raise ValueError('--directory is required')
    if args.action == 'credit':
        seconds = args.seconds if args.seconds != 1800 else CREDIT_SECONDS
        if not 1 <= seconds <= 86400:
            raise ValueError('out-of-credit quarantine must be between one second and one day')
        raise SystemExit(credit(args.directory, args.provider, args.scan, args.record, seconds))
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
            elif args.action == 'clear-global':
                # Drop only the global quarantine. Scoped usage-limit backoffs
                # stay: a qualification clear must never erase a live credit
                # or usage record that says this reviewer is still ineligible.
                # --expect-record makes the clear a compare-and-swap: it runs
                # only if the current global is still the exact record the
                # caller captured, so a replacement written mid-qualification
                # (even within the same second) can never be erased.
                if args.expect_record:
                    expected = json.loads(args.expect_record)
                    if data.get('global') != expected:
                        result = {'cleared': False, 'reason': 'record-changed'}
                        print(json.dumps(result, sort_keys=True, allow_nan=False))
                        return
                data['global'] = None
                publish(args.directory, args.provider, data); result = {'cleared': 'global'}
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
