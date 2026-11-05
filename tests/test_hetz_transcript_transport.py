"""Synthetic Ubuntu transport checks; no private data or network."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from test_transcript_zcode_export import make_db

ROOT = Path(__file__).resolve().parents[1]


class Transport(unittest.TestCase):
    def test_exports_without_database_upload_and_propagates_failures(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            db = home / '.zcode/cli/db/db.sqlite'
            db.parent.mkdir(parents=True)
            make_db(db).close()
            (home / '.zcode/cli/rollout').mkdir()
            fake = home / 'rclone'
            fake.write_text('#!/bin/bash\nprintf "%s\\n" "$*" >> "$HOME/calls"\nexit "${FAIL:-0}"\n')
            fake.chmod(0o700)
            env = dict(os.environ, HOME=tmp, AI_HETZ_RCLONE=str(fake))
            script = ROOT / 'bin/ai-transcripts-to-dropbox-hetz'
            subprocess.run(['bash', str(script), '--install'], env=env, check=True)
            launcher = home / 'bin/transcripts-to-dropbox.sh'
            subprocess.run(['bash', str(launcher)], env=env, check=True)
            self.assertTrue((home / '.local/state/ai-devops/hetz-transcripts/zcode-export/ses_1.jsonl').is_file())
            calls = (home / 'calls').read_text()
            self.assertIn('hetz/zcode/sessions', calls)
            self.assertIn('hetz/claude', calls)
            self.assertIn('hetz/codex', calls)
            self.assertIn('model-io-sess_', calls)
            self.assertNotIn('db.sqlite', calls)
            self.assertNotIn('--delete', calls)
            self.assertNotEqual(subprocess.run(['bash', str(launcher)], env=dict(env, FAIL='1')).returncode, 0)


if __name__ == '__main__':
    unittest.main()
