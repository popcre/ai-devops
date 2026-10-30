#!/usr/bin/env python3
"""#1531 full synthetic native provider/profile proofs; never contacts a provider."""
import copy
import contextlib
import hashlib
import importlib.util
import json
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("profile", ROOT / "tools/review_action_profile.py")
profile = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profile)
scope_spec = importlib.util.spec_from_file_location("code_only_scope", ROOT / "bin/ai-review-code-only.py")
scope_module = importlib.util.module_from_spec(scope_spec)
scope_spec.loader.exec_module(scope_module)


class ActionScopeSyntax(unittest.TestCase):
    def test_exact_identity_allows_only_optional_sentence_period(self):
        binding = {"profile": profile.PROFILE, "manifest_descriptor_sha256": "a" * 64}
        line = "Action scope: " + profile.PROFILE + " descriptor sha256:" + "a" * 64
        for suffix in ("", "."):
            self.assertTrue(scope_module.has_exact_action_scope("Approved bounded operation.\n" + line + suffix + "\nVERDICT: APPROVE " + "b" * 40, binding))

    def test_missing_changed_duplicate_or_decorated_scope_refuses(self):
        binding = {"profile": profile.PROFILE, "manifest_descriptor_sha256": "a" * 64}
        line = "Action scope: " + profile.PROFILE + " descriptor sha256:" + "a" * 64
        for content in ("", line.replace("a" * 64, "b" * 64), line.replace(profile.PROFILE, "another-profile"), line + "extra", line + "..", " " + line, line + " ", line + "\n" + line, line + ".\n" + line, line + "\n " + line.replace("a" * 64, "b" * 64), "`" + line + "`", line.replace("a" * 64, "a" * 63)):
            with self.subTest(content=content):
                self.assertFalse(scope_module.has_exact_action_scope(content, binding))




class InstalledEnforcementTests(unittest.TestCase):
    """Real clean Git source with fake external receipts; no system writes."""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.files = ("tools/review_action_profile.py", "config/review-action-profiles.json", "bin/ai-review-code-only.py", "bin/ai-task-gates")
        for name in self.files:
            path = self.root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_text("public fixture\n"); path.chmod(0o644)
        def git(*args):
            return subprocess.check_output(["git", "-C", str(self.root), *args], stderr=subprocess.DEVNULL)
        git("init", "-q"); git("config", "user.name", "Test"); git("config", "user.email", "test@example.com")
        git("add", "."); git("commit", "-qm", "public enforcement fixture")
        self.head = git("rev-parse", "HEAD").decode().strip()
        self.receipt = ("meta\tsource_sha\t" + self.head + "\t-\nsymlink\t/usr/local/bin/ai-task-gates\t" + str(self.root / "bin/ai-task-gates") + "\t" + profile.sha((self.root / "bin/ai-task-gates").read_bytes()) + "\n").encode()
        self.resolve = Path.resolve

    def tearDown(self):
        self.tmp.cleanup()

    def proof(self, receipt=None, wrong_launcher=False):
        def resolve(path, *args, **kwargs):
            if str(path) == "/usr/local/bin/ai-task-gates":
                return self.root / ("bin/wrong" if wrong_launcher else "bin/ai-task-gates")
            return self.resolve(path, *args, **kwargs)
        with mock.patch.object(profile, "ROOT", self.root), mock.patch.dict(os.environ, {"AI_DEVOPS_TEST_MODE": "0"}), mock.patch.object(Path, "resolve", resolve), mock.patch.object(profile._native, "private_read", return_value=self.receipt if receipt is None else receipt):
            return profile.installed_enforcement()

    def test_matching_committed_source_and_installed_receipt(self):
        proof = self.proof()
        self.assertEqual(proof["kind"], "VERIFIED_INSTALLED_SOURCE")
        self.assertEqual(proof["source_head"], self.head)
        self.assertEqual(set(proof["public_enforcement_sha256"]), set(self.files))

    def test_stale_receipt_refuses(self):
        with self.assertRaises(ValueError): self.proof(self.receipt.replace(self.head.encode(), b"0" * 40))

    def test_foreign_launcher_refuses(self):
        with self.assertRaises(ValueError): self.proof(wrong_launcher=True)

    def test_modified_enforcement_refuses(self):
        (self.root / self.files[0]).write_text("modified\n")
        with self.assertRaises(ValueError): self.proof()

    def test_duplicate_source_receipt_refuses(self):
        with self.assertRaises(ValueError): self.proof(self.receipt + self.receipt.splitlines(keepends=True)[0])

    def test_group_writable_source_is_fixture_only_and_real_installation_refuses(self):
        for name in self.files:
            (self.root / name).chmod(0o664)
        with self.assertRaises(ValueError): self.proof()
        with mock.patch.object(profile, "ROOT", self.root), mock.patch.dict(os.environ, {"AI_DEVOPS_TEST_MODE": "1"}):
            proof = profile.installed_enforcement()
        self.assertEqual(proof["kind"], "NONAUTHORIZING_TEST_FIXTURE")
        self.assertNotIn("source_head", proof)
        self.assertNotIn("installation_receipt_sha256", proof)



if __name__ == "__main__":
    unittest.main(verbosity=2)
