#!/usr/bin/env python3
"""One bounded, non-generating official account read; credentials arrive on stdin."""
import datetime
import hashlib
import json
import socket
import sys
import urllib.error
import urllib.request

ENDPOINT = 'https://api.deepseek.com/user/balance'
MAX_RESPONSE_BYTES = 65536

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

def observation(key, *, opener=None, now=None):
    checked = (now or datetime.datetime.now(datetime.timezone.utc)).strftime('%Y-%m-%dT%H:%M:%SZ')
    result = {'schema_version': 1, 'provider': 'deepseek', 'state': 'unknown',
              'checked_at': checked, 'provider_version': 'official-account-api-v1',
              'qualified_version': 'user-balance-v1', 'source_kind': 'official-user-balance',
              'credential_profile_scope': None, 'model_scope': 'deepseek-flash',
              'reason': 'authentication-error', 'reset_at': None}
    if not isinstance(key, str) or not key or any(ord(c) < 33 or ord(c) > 126 for c in key):
        return result
    result['credential_profile_scope'] = 'sha256:' + hashlib.sha256(key.encode()).hexdigest()
    request = urllib.request.Request(ENDPOINT, headers={'Authorization': 'Bearer ' + key}, method='GET')
    try:
        open_request = opener or urllib.request.build_opener(NoRedirect()).open
        with open_request(request, timeout=5) as response:
            payload = response.read(MAX_RESPONSE_BYTES + 1)
            if len(payload) > MAX_RESPONSE_BYTES:
                result['reason'] = 'malformed-response'; return result
            data = json.loads(payload)
        if not isinstance(data, dict) or type(data.get('is_available')) is not bool:
            result['reason'] = 'malformed-response'; return result
        if not isinstance(data.get('balance_infos'), list):
            result['reason'] = 'malformed-response'; return result
        available = data['is_available']
        result.update(state='available' if available else 'exhausted',
                      reason='reported-capacity' if available else 'reported-exhaustion')
    except urllib.error.HTTPError as error:
        result['reason'] = 'authentication-error' if error.code in (401, 403) else 'transport-error'
    except (TimeoutError, socket.timeout):
        result['reason'] = 'timeout'
    except (json.JSONDecodeError, UnicodeDecodeError):
        result['reason'] = 'malformed-response'
    except urllib.error.URLError as error:
        result['reason'] = 'timeout' if isinstance(error.reason, (TimeoutError, socket.timeout)) else 'transport-error'
    except (OSError, ValueError):
        result['reason'] = 'transport-error'
    return result

def main():
    key = sys.stdin.read(4097)
    if len(key) > 4096:
        key = ''
    print(json.dumps(observation(key.rstrip('\r\n')), separators=(',', ':')))
    return 0

if __name__ == '__main__':
    sys.exit(main())
