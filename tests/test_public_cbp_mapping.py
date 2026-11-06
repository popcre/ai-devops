"""Invented schema controls; actual pinned mapping proof is run separately."""
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('mapping', Path(__file__).resolve().parents[1] / 'tools/public_cbp_mapping.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class Mapping(unittest.TestCase):
    def test_working_blob_only_normalizes_crlf_and_bounds_reads(self):
        with tempfile.TemporaryDirectory() as temp:
            file = Path(temp) / 'generator.js'
            file.write_bytes(b'first\nsecond\n')
            wanted = hashlib.sha1(b'blob 13\0first\nsecond\n').hexdigest()
            self.assertEqual(m.working_blob(file), wanted)
            file.write_bytes(b'first\r\nsecond\r\n')
            self.assertEqual(m.working_blob(file), wanted)
            for changed in [b'first\rsecond\n', b'first \nsecond\n', b'first\nsecond', b'\xef\xbb\xbffirst\nsecond\n']:
                file.write_bytes(changed)
                self.assertNotEqual(m.working_blob(file), wanted)
            with patch.object(Path, 'is_symlink', return_value=True):
                self.assertIsNone(m.working_blob(file))
            with patch.object(m, 'MAX_GENERATOR_BYTES', 4):
                self.assertIsNone(m.working_blob(file))

    def test_actual_git_clean_filter_canary_is_never_executed_by_working_hash(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); file = root / 'generator.js'; marker = root / 'executed'
            script = root / 'canary.py'
            script.write_text('import pathlib,sys\npathlib.Path(__file__).with_name("executed").write_text("executed")\nsys.stdout.buffer.write(sys.stdin.buffer.read())\n')
            file.write_bytes(b'invented\n')
            (root / '.gitattributes').write_text('*.js filter=canary\n')
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            command = shlex.quote(sys.executable.replace('\\', '/')) + ' ' + shlex.quote(str(script).replace('\\', '/'))
            subprocess.run(['git', '-C', str(root), 'config', 'filter.canary.clean', command], check=True)
            # Positive control proves the real filter fixture would execute on the retired call.
            subprocess.check_output(['git', '-C', str(root), 'hash-object', '--', 'generator.js'])
            self.assertTrue(marker.exists())
            marker.unlink()
            expected = subprocess.check_output(['git', '-C', str(root), 'hash-object', '--no-filters', '--', 'generator.js']).decode().strip()
            with patch.object(m.subprocess, 'check_output', side_effect=AssertionError('working hash must not spawn Git')):
                self.assertEqual(m.working_blob(file), expected)
            self.assertFalse(marker.exists())

    def row(self):
        return dict(ruling_number='N000001', held_code='0000.00.0000', state='mapped',
                    current_code='0000.00.0000', candidate_codes=['0000.00.0000'],
                    method='concordance', mapping_path=[], hts_revision='fixture', decided_by='rules')

    def test_fixed_schema_and_optional_pair(self):
        r = self.row()
        self.assertTrue(m.record(r))
        self.assertTrue(m.record(dict(r, reason='Invented public mapping.', confidence='high')))
        for extra in ['prompt', 'session_id', 'messages', 'reason', 'confidence', 'private_customs']:
            self.assertFalse(m.record(dict(r, **{extra: 'invented'})))

    def test_malformed_types_and_enums(self):
        for key, val in [('state', 'chat'), ('method', 'chat'), ('current_code', 1),
                         ('candidate_codes', ['ok', {}]), ('mapping_path', 'no'), ('ruling_number', None)]:
            self.assertFalse(m.record(dict(self.row(), **{key: val})))

    def test_new_hash_rejected_before_decompress(self):
        with patch.object(m.gzip, 'GzipFile', side_effect=AssertionError('must not open')):
            self.assertFalse(m.rows(b'private renamed payload'))
            self.assertFalse(m.rows(bytes(m.SIZE)))

    def test_wrong_path_rejected_without_git(self):
        with patch.object(m.subprocess, 'check_output', side_effect=AssertionError('must not query')):
            for path in ['session.jsonl.gz', 'DATA/hts-current-codes.jsonl.gz', 'transcripts/data/hts-current-codes.jsonl.gz']:
                self.assertFalse(m.prove('.', path))

    def test_wrong_repository_rejected_before_read(self):
        root = str(Path.cwd().resolve())
        with patch.dict(m.os.environ, {}, clear=True), patch.object(m.subprocess, 'check_output', side_effect=[root.encode(), b'https://github.com/foreign/repo.git']):
            self.assertFalse(m.prove(root, m.PATH))

    def test_exact_hash_is_not_enough_for_bad_schema(self):
        for value in [dict(self.row(), prompt='not allowed'), {'messages': []}, None]:
            raw = gzip.compress((json.dumps(value)+'\n').encode())
            with patch.object(m, 'SIZE', len(raw)), patch.object(m, 'SHA256', hashlib.sha256(raw).hexdigest()):
                self.assertFalse(m.rows(raw))

    def test_malformed_json_fails_closed(self):
        raw = gzip.compress(b'not json\n')
        with patch.object(m, 'SIZE', len(raw)), patch.object(m, 'SHA256', hashlib.sha256(raw).hexdigest()):
            with self.assertRaises(ValueError):
                m.rows(raw)


if __name__ == '__main__':
    unittest.main()
