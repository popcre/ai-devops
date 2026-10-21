#!/usr/bin/env python3
"""Semantic-version positives plus retained privacy denials (#1921)."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "tools/public-boundary-version-spans.py"
DATA = json.loads((ROOT / "tests/fixtures/public-boundary-versions/cases.json").read_text())
SPEC = importlib.util.spec_from_file_location("version_spans", HELPER)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class VersionSpans(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def filtered(self, name, text):
        target = self.root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
        hits = "".join(f"{name}:{number}:{line}\n" for number, line in enumerate(text.splitlines(), 1) if MODULE.TOPOLOGY.search(line))
        return subprocess.run([sys.executable, "-I", str(HELPER), str(self.root)], input=hits, text=True, capture_output=True, check=True).stdout

    def lock(self, *, name="nvidia-curand", wheel_name="nvidia_curand", host="files.pythonhosted.org", extra="", version_comment="", wheel_comment="", root_version=1):
        version = DATA["version"]
        return (f'version = {root_version}\n[[package]]\nname = "{name}"\nversion = "{version}"{version_comment}\n'
                f'source = {{ registry = "https://pypi.org/simple" }}\nwheels = [\n'
                f' {{ url = "https://{host}/packages/{extra}{wheel_name}-{version}-py3-none-any.whl", hash = "sha256:test" }},{wheel_comment}\n]\n')

    def test_requirements_examples(self):
        for name, text, allowed in DATA["requirements"]:
            with self.subTest(name=name, text=text):
                self.assertEqual(not self.filtered(name, text), allowed)

    @unittest.skipIf(MODULE.tomllib is None, "stdlib TOML not available; production retains strict scan")
    def test_uv_package_version_and_wheel(self):
        self.assertEqual(self.filtered("uv.lock", self.lock()), "")
        self.assertEqual(self.filtered("nested/uv.lock", self.lock() + '\n[[package]]\nname="other"\nversion="1.0"\nsource={registry="https://pypi.org/simple"}\n'), "")

    def test_uv_parser_absence_is_fail_closed(self):
        with patch.object(MODULE, "tomllib", None):
            self.assertEqual(MODULE.uv_spans(self.lock()), {})

    def test_uv_rejects_nonversion_topology(self):
        cases = [
            self.lock(version_comment=" # " + DATA["other_private"]),
            self.lock(wheel_comment=" # " + DATA["other_private"]),
            self.lock(wheel_comment=" # url = \"https://files.pythonhosted.org/packages/nvidia_curand-" + DATA["version"] + "-py3-none-any.whl\""),
            self.lock(extra=DATA["other_private"] + "/"),
            self.lock(host=DATA["other_private"]),
            self.lock(wheel_name="different_package"),
            self.lock(root_version=2),
            self.lock() + "invalid TOML !\n",
            'description = \"\"\"\n' + self.lock().partition("\n")[2] + '\"\"\"\n' + self.lock(),
            self.lock() + '\n[other]\nversion="' + DATA["version"] + '"\n',
        ]
        for text in cases:
            with self.subTest(text=text):
                self.assertTrue(self.filtered("uv.lock", text))
        self.assertTrue(self.filtered("notes.lock", self.lock()))

    def test_same_package_field_is_required(self):
        text = self.lock().replace('version = "' + DATA["version"] + '"', 'unknown = "' + DATA["version"] + '"')
        self.assertTrue(self.filtered("uv.lock", text))

    def test_external_manifest_symlink_is_not_read(self):
        outside = self.root / "outside"
        outside.mkdir()
        target = outside / "file"
        target.write_text(self.lock())
        link = self.root / "uv.lock"
        try:
            link.symlink_to(target)
        except OSError:
            self.skipTest("symlink creation unavailable")
        version_line = 'version = "' + DATA["version"] + '"'
        hit = 'uv.lock:4:' + version_line + '\n'
        proc = subprocess.run([sys.executable, "-I", str(HELPER), str(self.root)], input=hit, text=True, capture_output=True, check=True)
        self.assertEqual(proc.stdout, hit)

    def test_full_boundary_retains_other_rules_and_isolated_imports(self):
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        pin = DATA["requirements"][0][1]
        (self.root / "requirements.txt").write_text(pin + "\n")
        (self.root / "tomllib.py").write_text('raise RuntimeError("untrusted target import")\n')
        subprocess.run(["git", "-C", str(self.root), "add", "requirements.txt"], check=True)
        env = dict(os.environ, PYTHONPATH=str(self.root))
        command = ["bash", str(ROOT / "bin/ai-public-boundary-check"), str(self.root)]
        clean = subprocess.run(command, env=env, text=True, capture_output=True)
        self.assertEqual(clean.returncode, 0, clean.stderr)
        for suffix in [" # " + DATA["other_private"], " # " + DATA["project"], " # " + DATA["credential"], " # https://" + DATA["other_private"] + "/", " # https://" + DATA["public_endpoint"] + "/"]:
            (self.root / "requirements.txt").write_text(pin + suffix + "\n")
            self.assertNotEqual(subprocess.run(command, env=env, capture_output=True).returncode, 0)

    def test_filter_failure_keeps_original_topology_hits(self):
        tool = self.root / "bin/ai-public-boundary-check"
        tool.parent.mkdir()
        tool.write_bytes((ROOT / "bin/ai-public-boundary-check").read_bytes())
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        (self.root / "requirements.txt").write_text(DATA["requirements"][0][1] + "\n")
        subprocess.run(["git", "-C", str(self.root), "add", "requirements.txt"], check=True)
        # The missing helper must never turn an unclassified match into PASS.
        result = subprocess.run(["bash", str(tool), str(self.root)], capture_output=True)
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
