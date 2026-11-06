#!/usr/bin/env python3
"""One immutable public mapping, never a general JSONL/archive exception."""
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys

PATH = 'data/hts-current-codes.jsonl.gz'
SHA256 = '8f3c8d0a7e0317639958f431e59a865d779e1c03ddb101a62837c251bf29e7c3'
SIZE = 7543890
RECORDS = 143352
GENERATORS = {
    'scripts/hts-current-codes-offline.js': '37c6d5eee3fa89058de623f3212615cdfd1be4e6',
    'services/hts-ruling-current-codes.service.js': 'd5cb62149541f6f60041ccd8aab33f7165a6c4e2',
}
REQUIRED = {'ruling_number', 'held_code', 'state', 'current_code', 'candidate_codes',
            'method', 'mapping_path', 'hts_revision', 'decided_by'}
OPTIONAL = {'reason', 'confidence'}
MAX_GENERATOR_BYTES = 1048576


def working_blob(file):
    """Hash bounded source bytes without executing Git clean filters."""
    if file.is_symlink() or not file.is_file() or file.stat().st_size > MAX_GENERATOR_BYTES:
        return None
    with file.open('rb') as source:
        raw = source.read(MAX_GENERATOR_BYTES + 1)
    if len(raw) > MAX_GENERATOR_BYTES:
        return None
    # Windows checkouts may use CRLF. No other content normalization is allowed.
    raw = raw.replace(b'\r\n', b'\n')
    return hashlib.sha1(b'blob ' + str(len(raw)).encode('ascii') + b'\0' + raw).hexdigest()


def record(value):
    if type(value) is not dict or set(value) not in (REQUIRED, REQUIRED | OPTIONAL):
        return False
    for key in REQUIRED - {'current_code', 'candidate_codes', 'mapping_path'}:
        if type(value[key]) is not str or not 0 < len(value[key]) <= 128:
            return False
    if value['current_code'] is not None and (type(value['current_code']) is not str or not 0 < len(value['current_code']) <= 32):
        return False
    for key, limit in [('candidate_codes', 1655), ('mapping_path', 40)]:
        if type(value[key]) is not list or len(value[key]) > limit or any(type(v) is not str or not 0 < len(v) <= 128 for v in value[key]):
            return False
    if value['state'] not in {'current', 'mapped', 'split', 'unmapped'} or value['method'] not in {'concordance', 'exact', 'model', 'none'}:
        return False
    if OPTIONAL <= set(value) and (value['confidence'] not in {'high', 'medium', 'low'} or type(value['reason']) is not str or not 0 < len(value['reason']) <= 428):
        return False
    return True


def rows(raw):
    # Fingerprint BEFORE decompression: an altered gzip/zip bomb is never opened.
    if len(raw) != SIZE or hashlib.sha256(raw).hexdigest() != SHA256:
        return False
    count = optional = total = 0
    with gzip.GzipFile(fileobj=io.BytesIO(raw)) as source:
        while True:
            line = source.readline(32769)
            if not line:
                break
            total += len(line)
            value = json.loads(line)
            if len(line) > 32768 or total > 65000000 or not record(value):
                return False
            count += 1
            optional += 'reason' in value
            if count > RECORDS:
                return False
    return count == RECORDS and optional == 42601


def prove(root, path):
    if path != PATH:
        return False
    if any(v and ((k.startswith('GIT_') and k not in {'GIT_PAGER', 'GIT_TERMINAL_PROMPT'}) or k in {'LD_PRELOAD', 'LD_LIBRARY_PATH'}) for k, v in os.environ.items()):
        return False
    root = Path(root).resolve()
    def git(*args):
        return subprocess.check_output(['git', '-C', str(root), *args], stderr=subprocess.DEVNULL, timeout=15).decode().strip()
    if Path(git('rev-parse', '--show-toplevel')).resolve() != root:
        return False
    repo = 'popcre/designflow-backend'
    origins = {f'https://github.com/{repo}', f'https://github.com/{repo}.git', f'git@github.com:{repo}', f'git@github.com:{repo}.git', f'ssh://git@github.com/{repo}', f'ssh://git@github.com/{repo}.git'}
    if git('config', '--get-all', 'remote.origin.url') not in origins or git('remote', 'get-url', 'origin') not in origins:
        return False
    file = root / PATH
    if file.is_symlink() or file.parent.is_symlink() or not file.is_file() or file.stat().st_size != SIZE:
        return False
    if git('rev-parse', f'HEAD:{PATH}') != 'd8b8376939a98137dbe629c45b63b78cfc10669b':
        return False
    for name, blob in GENERATORS.items():
        if (root / name).is_symlink() or git('rev-parse', f'HEAD:{name}') != blob or working_blob(root / name) != blob:
            return False
    with file.open('rb') as source:
        raw = source.read(SIZE + 1)
    return rows(raw)


if __name__ == '__main__':
    try:
        ok = len(sys.argv) == 3 and prove(sys.argv[1], sys.argv[2])
    except (OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError):
        ok = False
    sys.exit(0 if ok else 3)
