#!/usr/bin/env python3
"""Offline supplemental proofs: real Git graph, mocked external API boundary only."""
import contextlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "release", Path(__file__).resolve().parents[1] / "tools/application_source_release.py")
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


@unittest.skipUnless(sys.platform.startswith("linux") and Path("/usr/bin/gh").is_file(),
                     "new target positive proofs are qualified Linux only")
class ReleaseProof(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "source"
        self.root.mkdir()
        self.previous = Path.cwd()
        os.chdir(self.root)
        self.addCleanup(os.chdir, self.previous)
        self.env = {"PATH": "/usr/bin:/bin", "HOME": os.environ["HOME"]}
        self.repo = "popcre/designflow-tracking"
        self.g("init", "-q", "--initial-branch=develop")
        self.g("config", "user.name", "Offline fixture")
        self.g("config", "user.email", "fixture@example.invalid")
        (self.root / "supabase").mkdir()
        (self.root / "supabase/already-upstream.sql").write_text("-- fixture\n")
        self.g("add", "supabase")
        self.g("commit", "-qm", "upstream mirror")
        self.base = self.g("rev-parse", "HEAD")
        self.g("update-ref", "refs/remotes/origin/develop", self.base)
        self.g("remote", "add", "origin", f"https://github.com/{self.repo}.git")
        self.g("checkout", "-qb", "sandbox-albert")
        (self.root / "app.js").write_text("// fixture\n")
        self.g("add", "app.js")
        self.g("commit", "-qm", "owned app delta")

    def g(self, *args):
        return subprocess.check_output([release.GIT, "-C", str(self.root), *args],
                                       env=self.env, stderr=subprocess.DEVNULL).decode().strip()

    def response(self, sha=None, **extra):
        return json.dumps({"ref": "refs/heads/develop", "object": {
            "type": "commit", "sha": sha or self.base}, **extra}).encode()

    @contextlib.contextmanager
    def api(self, response=None, after=None):
        original = subprocess.run
        calls = []

        def boundary(argv, **kwargs):
            if "/fixture/managed-ai-gh" in argv:
                calls.append((argv, kwargs))
                if after:
                    after()
                raw = response() if callable(response) else response
                return subprocess.CompletedProcess(argv, 0, raw or self.response(), b"")
            return original(argv, **kwargs)

        with patch.object(release, "installed_helper", return_value=(Path("/fixture/managed-ai-gh"),
                                                                    {"closure": "fixed"})), \
                patch.object(subprocess, "run", side_effect=boundary):
            yield calls

    def test_all_three_positive_exact_managed_get_and_auth_preserved(self):
        for repo in sorted(release.NEW_REPOSITORIES):
            with self.subTest(repo=repo):
                self.g("remote", "set-url", "origin", f"git@github.com:{repo}.git")
                env = {**self.env, "GIT_SSH_COMMAND": "ssh -o ProxyCommand=fixture",
                       "HTTPS_PROXY": "http://proxy.example.invalid", "GH_CONFIG_DIR": "/private/auth",
                       "BASH_ENV": "/fixture/injection", "PYTHON_RUNNER": "/fixture/injection",
                       "BASH_FUNC_cat%%": "() { echo forged; }"}
                with self.api() as calls:
                    proof = release.prove(self.root, repo, self.base, env)
                self.assertEqual(proof["repository"], repo)
                self.assertEqual(proof["develop"], self.base)
                self.assertEqual(len(calls), 1)
                argv, options = calls[0]
                self.assertEqual(argv[:4], ["/bin/bash", "--noprofile", "--norc", "/fixture/managed-ai-gh"])
                self.assertEqual(argv[4:], ["api", "--hostname", "github.com", "--method", "GET",
                                           f"repos/{repo}/git/ref/heads/develop"])
                self.assertEqual(options["env"]["AI_GH_REAL_GH"], release.GH)
                self.assertEqual(options["env"]["GH_CONFIG_DIR"], "/private/auth")
                self.assertEqual(options["env"]["PATH"], "/usr/bin:/bin")
                self.assertEqual(options["env"]["PYTHON_RUNNER"], "/usr/bin/python3")
                self.assertNotIn("BASH_ENV", options["env"])
                self.assertNotIn("BASH_FUNC_cat%%", options["env"])
                self.assertEqual(options["timeout"], 30)

    def test_native_additive_contributor_proofs_include_ui_and_code(self):
        source = (Path(__file__).resolve().parents[1] / "bin/ai-task-gates").read_text()
        body = source.split("application_release_contributor_gates(){", 1)[1].split("\n}", 1)[0]
        script = "application_release_contributor_gates(){" + body + "\n}\n" + r'''
merged_gate(){ printf 'required\t%s\n' "$2"; }
IDENTITY=popcre/designflow-frontend
CONTRIBUTORS=('code\tsrc/app.ts' 'ui-live-workflow\tsrc/page.ts' 'reviewer-safety\tsrc/auth.ts')
application_release_contributor_gates
'''
        result = subprocess.check_output(["/bin/bash", "-c", script], env=self.env).decode().splitlines()
        self.assertEqual(result, ["required\tcode", "required\tui-live-workflow",
                                  "required\treviewer-safety"])

    def test_cross_repo_and_backend_manifest_cannot_prove_new_identity(self):
        for repo in ["popcre/designflow-frontend", "popcre/designflow-item-master",
                     "popcre/designflow-backend", "foreign/repository"]:
            with self.subTest(repo=repo), self.api(), self.assertRaises(ValueError):
                release.prove(self.root, repo, self.base, self.env)

    def test_recorded_head_reset_refused_but_upstream_mirror_excluded(self):
        delta = self.g("diff", "--name-only", self.base, "HEAD")
        self.assertNotIn("supabase/", delta)
        with self.api(), self.assertRaises(ValueError):
            release.prove(self.root, self.repo, self.g("rev-parse", "HEAD"), self.env)

    def test_every_directory_config_ancestry_override_refused_before_git(self):
        for key in sorted(release.UNSAFE | {"GIT_CONFIG_KEY_0", "GIT_CONFIG_VALUE_0"}):
            with self.subTest(key=key), patch.object(subprocess, "run") as command, \
                    self.assertRaises(ValueError):
                release.prove(self.root, self.repo, self.base, {**self.env, key: "injection"})
            command.assert_not_called()

    def test_real_gh_override_and_path_shim_refused(self):
        for env in [{**self.env, "AI_GH_REAL_GH": "/fixture/fake"},
                    {**self.env, "PATH": str(self.root)}]:
            with self.subTest(env=env), self.assertRaises(ValueError):
                release.confined_environment(env)

    def test_unsupported_platform_refuses_new_only(self):
        with patch.object(release.sys, "platform", "win32"), self.assertRaises(ValueError):
            release.confined_environment(self.env)
        # Backend's discriminator never invokes this supplemental environment proof.
        (self.root / ".ai-devops").mkdir()
        (self.root / release.MANIFEST).write_text('{"repository":"popcre/designflow-backend"}')
        self.assertEqual(release.discriminator(self.root), "")

    def test_real_branch_shallow_replace_graft_and_stale_develop_refused(self):
        self.g("checkout", "-qb", "review-branch")
        with self.api(), self.assertRaises(ValueError):
            release.prove(self.root, self.repo, self.base, self.env)
        self.g("checkout", "-q", "sandbox-albert")
        (self.root / ".git/shallow").write_text(self.base + "\n")
        with self.api(), self.assertRaises(ValueError):
            release.prove(self.root, self.repo, self.base, self.env)
        (self.root / ".git/shallow").unlink()
        self.g("replace", self.base, "HEAD")
        with self.api(), self.assertRaises(ValueError):
            release.prove(self.root, self.repo, self.base, self.env)
        self.g("replace", "-d", self.base)
        (self.root / ".git/info/grafts").write_text(self.base + "\n")
        with self.api(), self.assertRaises(ValueError):
            release.prove(self.root, self.repo, self.base, self.env)
        (self.root / ".git/info/grafts").unlink()
        with self.api(self.response("a" * 40)), self.assertRaises(ValueError):
            release.prove(self.root, self.repo, self.base, self.env)

    def test_source_config_race_and_helper_race_refused(self):
        with self.api(after=lambda: self.g("config", "fixture.changed", "yes")), \
                self.assertRaises(ValueError):
            release.prove(self.root, self.repo, self.base, self.env)

    def test_fresh_remote_is_rechecked_on_second_admission_phase(self):
        responses = iter([self.response(), self.response("a" * 40)])
        with self.api(lambda: next(responses)) as calls:
            release.prove(self.root, self.repo, self.base, self.env)
            with self.assertRaises(ValueError):
                release.prove(self.root, self.repo, self.base, self.env)
        self.assertEqual(len(calls), 2)

    def test_helper_closure_race_refused(self):
        with self.api(), patch.object(release, "installed_helper", side_effect=[
            (Path("/fixture/managed-ai-gh"), {"closure": "before"}),
            (Path("/fixture/managed-ai-gh"), {"closure": "after"})]), self.assertRaises(ValueError):
            release.prove(self.root, self.repo, self.base, self.env)

    def test_duplicate_foreign_shape_type_sha_and_failed_network_refused(self):
        invalid = [b'{"ref":"a","ref":"b"}', b'[]', self.response(url="https://evil.invalid/ref"),
                   self.response("not-a-sha"), b'{"ref":"refs/heads/develop","object":{"type":"tag","sha":"'
                   + b'a' * 40 + b'"}}', self.response(unexpected="extra")]
        for raw in invalid:
            with self.subTest(raw=raw), self.api(raw), self.assertRaises(ValueError):
                release.prove(self.root, self.repo, self.base, self.env)
        with patch.object(subprocess, "run", side_effect=subprocess.TimeoutExpired("fixture", 30)), \
                self.assertRaises(subprocess.TimeoutExpired):
            release.remote_ref(self.root, self.repo, Path("/fixture/helper"), self.env)

    def test_public_binary_rejects_user_temp_origin(self):
        fake = self.root / "gh"
        fake.write_text("fixture")
        fake.chmod(0o700)
        with self.assertRaises(ValueError):
            release.public_binary(fake)
        self.assertEqual(release.public_binary(release.GH), str(Path(release.GH).resolve()))

    def test_installed_helper_receipt_and_real_closure_refuse_tampering(self):
        toolkit = Path(self.temp.name) / "toolkit"
        (toolkit / "bin").mkdir(parents=True)
        (toolkit / "tools/github-requests").mkdir(parents=True)
        for relative in ["bin/ai-gh", "tools/github-requests/telemetry.sh",
                         "tools/github-requests/pr-status-context"]:
            (toolkit / relative).write_text("# fixture\n")
        for args in [("init", "-q"), ("config", "user.name", "T"),
                     ("config", "user.email", "t@example.invalid"), ("add", "."),
                     ("commit", "-qm", "fixture")]:
            subprocess.check_call([release.GIT, "-C", str(toolkit), *args], env=self.env,
                                  stderr=subprocess.DEVNULL)
        source = subprocess.check_output([release.GIT, "-C", str(toolkit), "rev-parse", "HEAD"],
                                         env=self.env).decode().strip()
        launcher = Path(self.temp.name) / "ai-gh"
        launcher.symlink_to(toolkit / "bin/ai-gh")
        receipt = Path(self.temp.name) / "manifest"
        receipt.write_text(f"meta\tsource_sha\t{source}\t-\nsymlink\t{launcher}\t{toolkit / 'bin/ai-gh'}\t"
                           + release.digest((toolkit / "bin/ai-gh").read_bytes()) + "\n")
        real_path = Path

        def filesystem(value):
            return {"/usr/local/bin/ai-gh": launcher,
                    "/etc/ai-devops/install-manifest.tsv": receipt}.get(str(value), real_path(value))

        with patch.object(release, "Path", side_effect=filesystem):
            helper, proof = release.installed_helper(self.root, self.env)
            self.assertEqual(helper, toolkit / "bin/ai-gh")
            self.assertEqual(proof["source"], source)
            (toolkit / "tools/github-requests/telemetry.sh").write_text("# tampered\n")
            with self.assertRaises(ValueError):
                release.installed_helper(self.root, self.env)


class PlatformBoundary(unittest.TestCase):
    def test_backend_discriminator_preserves_nonlinux_without_git_or_network(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".ai-devops"
            path.mkdir()
            (path / "application-release-target.json").write_text(
                '{"repository":"popcre/designflow-backend"}')
            with patch.object(release.sys, "platform", "win32"), \
                    patch.object(subprocess, "run") as command:
                self.assertEqual(release.discriminator(directory), "")
                with self.assertRaises(ValueError):
                    release.confined_environment({})
            command.assert_not_called()


if __name__ == "__main__":
    unittest.main()
