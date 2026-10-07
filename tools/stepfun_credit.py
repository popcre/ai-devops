#!/usr/bin/env python3
"""One official prepaid account observation; never a model/credential call."""
import datetime
import json
import math
import os
import pathlib
import urllib.request
from glm_credit import NoRedirect, fingerprint, private

ENDPOINT = 'https://api.stepfun.ai/v1/accounts'
MODEL = 'step-5-preview'
FIELDS = {'object', 'type', 'balance', 'total_cash_balance', 'total_voucher_balance'}

def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate-field')
        result[key] = value
    return result

def classify(value):
    if not isinstance(value, dict) or set(value) != FIELDS or value['object'] != 'account' or value['type'] != 'prepaid':
        raise ValueError('unqualified-account')
    for field in ('balance', 'total_cash_balance', 'total_voucher_balance'):
        number = value[field]
        if type(number) not in (int, float) or not math.isfinite(number) or number < 0:
            raise ValueError('unqualified-account-number')
    return 'available' if value['balance'] > 0 else 'exhausted'

def read_key(path):
    private(path.parent, directory=True)
    private(path)
    before = path.stat()
    fd = os.open(path, os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0))
    try:
        data = os.read(fd, 4097)
        after = os.fstat(fd)
    finally:
        os.close(fd)
    if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns) or len(data) > 4096:
        raise ValueError('cache-moved')
    key = data.decode('ascii').strip()
    if not key or any(ord(c) < 33 or ord(c) > 126 for c in key):
        raise ValueError('invalid-key')
    return key

def check(*, path=None, opener=None, environment=None):
    result = {'provider': 'stepfun', 'model_scope': MODEL,
              'qualified_version': 'stepfun-account-v1', 'source_kind': 'official-stepfun-account',
              'checked_at': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
              'state': 'unknown', 'reason': 'read-unavailable'}
    try:
        env = os.environ if environment is None else environment
        expected_path = pathlib.Path.home() / '.config/ai-devops/secrets/stepfun-api-key'
        if (env.get('AI_STEPFUN_BASE_URL', 'https://api.stepfun.ai/v1') != 'https://api.stepfun.ai/v1'
                or env.get('AI_STEPFUN_MODEL', 'step/step-5-preview') != 'step/step-5-preview'
                or env.get('AI_STEPFUN_KEY_STORE', str(expected_path)) != str(expected_path)
                or env.get('AI_STEPFUN_OP_REF', 'op://vibe_coding/stepfun step5 ai api key/credential') != 'op://vibe_coding/stepfun step5 ai api key/credential'):
            raise ValueError('unqualified-profile')
        key = read_key(expected_path if path is None else path)
        scope = fingerprint(key)
        request = urllib.request.Request(ENDPOINT, headers={'Authorization': 'Bearer ' + key, 'Accept': 'application/json'}, method='GET')
        client = opener or urllib.request.build_opener(NoRedirect)
        with client.open(request, timeout=15) as response:
            if response.status != 200 or response.geturl() != ENDPOINT:
                raise ValueError('endpoint-status')
            body = response.read(65537)
        if len(body) > 65536:
            raise ValueError('response-bound')
        state = classify(json.loads(body, object_pairs_hook=unique_object))
        result.update(state=state, reason='reported-capacity' if state == 'available' else 'reported-exhaustion', credential_profile_scope=scope)
    except Exception:
        # Neither raw provider errors nor private account amounts reach output.
        pass
    return result

if __name__ == '__main__':
    print(json.dumps(check(), separators=(',', ':')))
