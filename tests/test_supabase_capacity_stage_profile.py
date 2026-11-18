"""Closed staging dispatch must never become generic production authority."""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

path = Path(__file__).resolve().parent.parent / "tools/supabase_capacity_stage_profile.py"
spec = importlib.util.spec_from_file_location("capacity_profile", path)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class StageProfileTests(unittest.TestCase):
    def fixture(self):
        blobs = {name: ("approved " + name).encode() for name in m.SOURCE_FILES}
        profile = {"schema_version": 1, "enabled": True, "repository": m.REPOSITORY,
                   "source_files": {name: hashlib.sha256(data).hexdigest() for name, data in blobs.items()}}
        manifest = {"schema_version": 1, "operation": "pgss-capacity-stage/v1",
                    "repository": m.REPOSITORY, "workflow": m.WORKFLOW,
                    "ref": "main", "head_sha": "a" * 40, "work_issue": 5609}
        facts = {"head": "a" * 40, "main": "a" * 40, "blobs": blobs,
                 "consumer": {"gates": {"infrastructure": {"required": [m.GATE, "reviewed-production-dispatch"]}}},
                 "platform": "linux"}
        return manifest, profile, facts

    def test_exact_source_only(self):
        manifest, profile, facts = self.fixture()
        digest = m.qualify(manifest, profile, **facts)
        self.assertEqual(digest, hashlib.sha256(json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode()).hexdigest())
        changed = copy.deepcopy(facts)
        changed["blobs"][next(iter(m.SOURCE_FILES))] += b" changed"
        with self.assertRaises(m.Refused):
            m.qualify(manifest, profile, **changed)

    @unittest.skipUnless(Path("/usr/bin/git").is_file(), "Linux dispatch Git required")
    def test_committed_blob_stays_at_proved_commit(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)

            def git(*args):
                return subprocess.check_output(
                    ["/usr/bin/git", "-C", directory, *args], stderr=subprocess.DEVNULL
                )

            git("init")
            git("config", "user.name", "Test")
            git("config", "user.email", "test@example.invalid")
            git("config", "commit.gpgsign", "false")
            source = repo / "source"
            source.write_bytes(b"proved")
            git("add", "source")
            git("commit", "-m", "Record proved source")
            proved = git("rev-parse", "HEAD").decode().strip()
            source.write_bytes(b"changed")
            git("commit", "-am", "Move HEAD")
            with patch.dict(os.environ, {"GIT_DIR": str(repo / "missing")}):
                self.assertEqual(m.committed_blob(repo, proved, "source"), b"proved")

    def test_no_arbitrary_dispatch_or_runtime_settings(self):
        for name, value in [("operation", "restart"), ("workflow", "other.yml"),
                            ("repository", "u2giants/ansible"), ("ref", "feature"),
                            ("work_issue", 5610), ("work_issue", 5609.0),
                            ("schema_version", True), ("head_sha", "b" * 40),
                            ("restart_database", False), ("setting", "max_connections"),
                            ("desired", 40000), ("url", "https://attacker.invalid")]:
            manifest, profile, facts = self.fixture()
            manifest[name] = value
            with self.subTest(name=name, value=value), self.assertRaises(m.Refused):
                m.qualify(manifest, profile, **facts)

    def test_disabled_or_mutated_profile_refuses(self):
        for change in ["disabled", "unknown", "missing_pin", "bad_pin", "wrong_repo"]:
            manifest, profile, facts = self.fixture()
            if change == "disabled": profile["enabled"] = False
            elif change == "unknown": profile["extra"] = True
            elif change == "missing_pin": profile["source_files"].pop(next(iter(m.SOURCE_FILES)))
            elif change == "bad_pin": profile["source_files"][next(iter(m.SOURCE_FILES))] = "0" * 64
            else: profile["repository"] = "u2giants/ansible"
            with self.subTest(change=change), self.assertRaises(m.Refused):
                m.qualify(manifest, profile, **facts)

    def test_main_declaration_and_platform_boundaries(self):
        for change in ["moved", "missing_gate", "bad_gate_type", "unqualified_os"]:
            manifest, profile, facts = self.fixture()
            if change == "moved": facts["main"] = "b" * 40
            elif change == "missing_gate": facts["consumer"] = {}
            elif change == "bad_gate_type": facts["consumer"]["gates"]["infrastructure"]["required"] = [{}]
            else: facts["platform"] = "win32"
            with self.subTest(change=change), self.assertRaises(m.Refused):
                m.qualify(manifest, profile, **facts)

    def test_duplicate_keys_and_hidden_payload_refuse(self):
        for text in ['{"schema_version":1,"schema_version":1}', '{} trailing', '{}'+ ' '*8192]:
            with self.subTest(text=text[:40]), self.assertRaises(m.Refused):
                m.parse(text)


if __name__ == "__main__":
    unittest.main()
