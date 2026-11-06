"""Invented schema controls; actual pinned mapping proof is run separately."""
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('mapping', Path(__file__).resolve().parents[1] / 'tools/public_cbp_mapping.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class Mapping(unittest.TestCase):
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
