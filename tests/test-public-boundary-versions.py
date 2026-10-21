#!/usr/bin/env python3
"""Semantic-version positives plus retained privacy denials (#1921)."""
import ast
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

    def test_direct_standard_network_calls_only(self):
        for network in DATA["standard_networks"]:
            source = f'import ipaddress\nallowed = ipaddress.ip_network("{network}")\n'
            with self.subTest(network=network):
                self.assertEqual(self.filtered("policy.py", source), "")
                unicode_source = f'import ipaddress\nlabel = "π"; allowed = ipaddress.ip_network("{network}")\n'
                self.assertEqual(self.filtered("policy.py", unicode_source), "")
                self.assertTrue(self.filtered("README.md", source))
                for suffix in [" # " + DATA["other_private"], " # https://" + DATA["other_private"] + "/", " # " + network]:
                    self.assertTrue(self.filtered("policy.py", source.rstrip() + suffix + "\n"))
        source = 'import ipaddress\nallowed = tuple(ipaddress.ip_network(n) for n in ' + repr(tuple(DATA["standard_networks"])) + ')\n'
        self.assertTrue(self.filtered("policy.py", source))

    def test_legacy_ast_string_without_end_positions(self):
        class Str(ast.AST):
            _fields = ("s",)

        parse = ast.parse
        def legacy_parse(text):
            tree = parse(text)
            class Legacy(ast.NodeTransformer):
                def visit_Constant(self, node):
                    if not isinstance(node.value, str):
                        return node
                    old = Str()
                    old.s, old.lineno, old.col_offset = node.value, node.lineno, node.col_offset
                    return old
            return Legacy().visit(tree)

        network = DATA["standard_networks"][0]
        source = f'import ipaddress\nlabel = "π"; allowed = ipaddress.ip_network("{network}")'
        with patch.object(MODULE.ast, "parse", legacy_parse):
            spans = MODULE.network_spans(source)
            self.assertEqual(len(spans.get(2, [])), 1)
            for suffix in [" # " + DATA["other_private"], " # https://" + DATA["other_private"] + "/"]:
                line = source.splitlines()[1] + suffix
                allowed = MODULE.network_spans(source + suffix).get(2, [])
                self.assertTrue(any(not any(a <= hit.start() and hit.end() <= b for a, b in allowed) for hit in MODULE.TOPOLOGY.finditer(line)))
            self.assertEqual(MODULE.network_spans('import ipaddress\nipaddress = other\n' + source.splitlines()[1]), {})
            self.assertEqual(MODULE.network_spans('import ipaddress\nx = "' + network + '"'), {})

    def test_nonstandard_network_values_stay_blocked(self):
        for network in DATA["nonstandard_networks"]:
            with self.subTest(network=network):
                self.assertTrue(self.filtered("policy.py", f'import ipaddress\nallowed = ipaddress.ip_network("{network}")\n'))
        network = DATA["standard_networks"][0]
        self.assertTrue(self.filtered("policy.py", f'allowed = "{network}"\n'))
        self.assertTrue(self.filtered("policy.py", f'import ipaddress\nallowed = ipaddress.ip_network("{network}")\ninvalid Python !\n'))

    def test_shadowed_network_module_or_function_stays_blocked(self):
        network = DATA["standard_networks"][0]
        call = f'allowed = ipaddress.ip_network("{network}")\n'
        for binding in [
            'ipaddress = object()\n',
            'import other as ipaddress\n',
            'from other import ipaddress\n',
            'from other import *\n',
            'def ipaddress(): pass\n',
            'def f(ipaddress): pass\n',
            'ipaddress.ip_network = other\n',
            'setattr(ipaddress, "ip_network", other)\n',
            'globals()["ipaddress"] = other\n',
            'match value:\n    case {**ipaddress}: pass\n',
        ]:
            with self.subTest(binding=binding):
                self.assertTrue(self.filtered("policy.py", 'import ipaddress\n' + binding + call))
        self.assertTrue(self.filtered("policy.py", call))
        self.assertTrue(self.filtered("policy.py", 'def f():\n    import ipaddress\n' + call))
        (self.root / "ipaddress.py").write_text("# fake local module\n")
        self.assertTrue(self.filtered("policy.py", 'import ipaddress\n' + call))

    def test_network_semantics_do_not_launder_other_boundaries(self):
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        source = 'import ipaddress\nallowed = ipaddress.ip_network("' + DATA["standard_networks"][0] + '")'
        policy = self.root / "policy.py"
        policy.write_text(source + "\n")
        subprocess.run(["git", "-C", str(self.root), "add", "policy.py"], check=True)
        command = ["bash", str(ROOT / "bin/ai-public-boundary-check"), str(self.root)]
        clean = subprocess.run(command, capture_output=True)
        self.assertEqual(clean.returncode, 0, clean.stderr)
        for suffix in [" # " + DATA["project"], " # " + DATA["credential"], " # https://" + DATA["public_endpoint"] + "/"]:
            policy.write_text(source + suffix + "\n")
            self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)


if __name__ == "__main__":
    unittest.main()
