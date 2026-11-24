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
from types import SimpleNamespace
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
                self.assertEqual(options["timeout"], 600)

    def prepare_refresh(self, repo, fast_forward=False, preserve_sandbox=False):
        sandbox = self.base if fast_forward else self.g("rev-parse", "HEAD")
        self.g("remote", "set-url", "origin", f"https://github.com/{repo}.git")
        self.g("checkout", "-q", "develop")
        if not fast_forward and not preserve_sandbox:
            (self.root / "app.js").write_text("// fixture\n")
        (self.root / "shared-db").mkdir()
        (self.root / "shared-db/mirror.sql").write_text("-- published fixture\n")
        self.g("add", ".")
        self.g("commit", "-qm", "published develop update")
        develop = self.g("rev-parse", "HEAD")
        self.g("update-ref", "refs/remotes/origin/sandbox-albert", sandbox)
        self.g("update-ref", "refs/remotes/origin/develop", develop)
        self.g("checkout", "-q", "--detach", sandbox)
        worktree = self.root.parent / "isolated-refresh"
        self.g("worktree", "add", "--quiet", "--detach", str(worktree), sandbox)
        self.root = worktree
        os.chdir(worktree)
        self.g("merge", "-q", "--no-edit", "--ff-only" if fast_forward else "--no-ff", develop)
        return {"sandbox-albert": sandbox, "develop": develop}

    @contextlib.contextmanager
    def refresh_api(self, refs):
        seen = []
        def exact_ref(root, repo, helper, env, branch):
            seen.append(branch)
            value = refs[branch]
            return value() if callable(value) else value
        with patch.object(release, "installed_helper", return_value=(Path("/fixture/managed-ai-gh"), {"source": "fixed"})), \
                patch.object(release, "remote_ref", side_effect=exact_ref), \
                patch.object(release, "cloud_refresh_proof", return_value={"sandbox_trigger": "fixed"}):
            yield seen

    def test_published_frontend_merge_uses_both_fresh_canonical_refs(self):
        repo = "popcre/designflow-frontend"
        refs = self.prepare_refresh(repo)
        with self.refresh_api(refs) as seen:
            proof = release.prove_refresh(self.root, repo, refs["sandbox-albert"], self.env)
        self.assertEqual(proof["head"], self.g("rev-parse", "HEAD"))
        self.assertEqual(seen, ["sandbox-albert", "develop", "develop", "sandbox-albert"])

    def test_published_frontend_mirror_fast_forward(self):
        repo = "popcre/designflow-frontend"
        refs = self.prepare_refresh(repo, fast_forward=True)
        with self.refresh_api(refs):
            proof = release.prove_refresh(self.root, repo, refs["sandbox-albert"], self.env)
        self.assertEqual(proof["head"], refs["develop"])

    def test_mirror_refresh_preserves_sandbox_only_application(self):
        repo = release.TRACKING
        refs = self.prepare_refresh(repo, preserve_sandbox=True)
        with self.refresh_api(refs):
            proof = release.prove_refresh(self.root, repo, refs["sandbox-albert"], self.env)
        self.assertEqual(proof["head"], self.g("rev-parse", "HEAD"))
        self.assertTrue((self.root / "app.js").is_file())
        (self.root / "app.js").unlink()
        self.g("add", "-u")
        self.g("commit", "-q", "--amend", "--no-edit")
        with self.assertRaisesRegex(ValueError, "read-only source-release proof command failed"):
            release.refresh_context(self.root, repo, refs["sandbox-albert"], self.env)

    def prepare_handoff_refresh(self, repo, note="HANDOFF.d/published.md"):
        self.g("checkout", "-q", "develop")
        (self.root / note).parent.mkdir(parents=True, exist_ok=True)
        (self.root / note).write_text("# Published handoff\n")
        self.g("add", ".")
        self.g("commit", "-qm", "published handoff")
        self.g("checkout", "-q", "-")
        return self.prepare_refresh(repo, preserve_sandbox=True)

    def test_mirror_refresh_admits_exact_published_handoff(self):
        repo = release.TRACKING
        refs = self.prepare_handoff_refresh(repo)
        with self.refresh_api(refs):
            proof = release.prove_refresh(self.root, repo, refs["sandbox-albert"], self.env)
        self.assertEqual(proof["head"], self.g("rev-parse", "HEAD"))

    def test_mirror_refresh_refuses_edited_or_nested_handoff(self):
        repo = release.TRACKING
        refs = self.prepare_handoff_refresh(repo)
        (self.root / "HANDOFF.d/published.md").write_text("# Edited in the merge\n")
        self.g("add", "-u")
        self.g("commit", "-q", "--amend", "--no-edit")
        with self.assertRaisesRegex(ValueError, "read-only source-release proof command failed"):
            release.refresh_context(self.root, repo, refs["sandbox-albert"], self.env)

    def test_mirror_refresh_refuses_nested_handoff_path(self):
        repo = release.TRACKING
        refs = self.prepare_handoff_refresh(repo, note="HANDOFF.d/sub/note.md")
        with self.assertRaisesRegex(ValueError, "read-only source-release proof command failed"):
            release.refresh_context(self.root, repo, refs["sandbox-albert"], self.env)

    def test_data_syncing_refresh_allows_only_unmodified_published_tree(self):
        repo = release.DATA_SYNCING
        refs = self.prepare_refresh(repo, fast_forward=True)
        self.g("checkout", "-q", "develop")
        (self.root / "app.js").write_text("// published application update\n")
        (self.root / "HANDOFF.d").mkdir()
        (self.root / "HANDOFF.d/published.md").write_text("# Published handoff\n")
        self.g("add", ".")
        self.g("commit", "-qm", "published Data Syncing source")
        develop = self.g("rev-parse", "HEAD")
        refs["develop"] = develop
        self.g("update-ref", "refs/remotes/origin/develop", develop)
        self.g("checkout", "-q", "--detach", develop)
        with self.refresh_api(refs):
            proof = release.prove_refresh(self.root, repo, refs["sandbox-albert"], self.env)
        self.assertEqual(proof["head"], develop)
        (self.root / "app.js").write_text("// local alteration\n")
        self.g("add", "app.js")
        self.g("commit", "-qm", "not a published refresh")
        with self.assertRaisesRegex(ValueError, "merge only the two published heads"):
            release.refresh_context(self.root, repo, refs["sandbox-albert"], self.env)

    def test_data_syncing_refresh_refuses_to_drop_sandbox_changes(self):
        repo = release.DATA_SYNCING
        refs = self.prepare_refresh(repo)
        self.g("checkout", "-q", "--detach", refs["sandbox-albert"])
        (self.root / "sandbox-only.md").write_text("# Concurrent sandbox work\n")
        self.g("add", ".")
        self.g("commit", "-qm", "concurrent sandbox work")
        sandbox = self.g("rev-parse", "HEAD")
        self.g("update-ref", "refs/remotes/origin/sandbox-albert", sandbox)
        develop = refs["develop"]
        altered = self.g("commit-tree", f"{develop}^{{tree}}", "-p", sandbox, "-p", develop,
                         "-m", "discarded sandbox work")
        self.g("checkout", "-q", "--detach", altered)
        with self.assertRaises(ValueError):
            release.refresh_context(self.root, repo, sandbox, self.env)

    def test_data_syncing_refresh_refuses_non_regular_files(self):
        repo = release.DATA_SYNCING
        refs = self.prepare_refresh(repo, fast_forward=True)
        self.g("checkout", "-q", "develop")
        (self.root / "symlink.js").symlink_to("app.js")
        self.g("add", ".")
        self.g("commit", "-qm", "published non-regular input")
        develop = self.g("rev-parse", "HEAD")
        self.g("update-ref", "refs/remotes/origin/develop", develop)
        self.g("checkout", "-q", "--detach", develop)
        with self.assertRaisesRegex(ValueError, "unclassifiable refresh path or file type"):
            release.refresh_context(self.root, repo, refs["sandbox-albert"], self.env)

    def test_local_edits_in_merge_or_worktree_are_refused(self):
        repo = "popcre/designflow-frontend"
        refs = self.prepare_refresh(repo)
        publication = self.root / "shared-db/mirror.sql"
        publication.write_text("-- local alteration\n")
        with self.assertRaisesRegex(ValueError, "worktree must be clean"):
            release.refresh_context(self.root, repo, refs["sandbox-albert"], self.env)
        self.g("add", ".")
        self.g("commit", "-q", "--amend", "--no-edit")
        with self.assertRaisesRegex(ValueError, "read-only source-release proof command failed"):
            release.refresh_context(self.root, repo, refs["sandbox-albert"], self.env)

    def test_refuses_unpublished_parent_and_remote_drift(self):
        repo = "popcre/designflow-frontend"
        refs = self.prepare_refresh(repo)
        sandbox = refs["sandbox-albert"]
        with self.refresh_api({**refs, "sandbox-albert": "1" * 40}):
            with self.assertRaisesRegex(ValueError, "differs from fresh canonical remote"):
                release.prove_refresh(self.root, repo, sandbox, self.env)
        remote_develop = iter([refs["develop"], "2" * 40])
        with self.refresh_api({**refs, "develop": lambda: next(remote_develop)}):
            with self.assertRaisesRegex(ValueError, "remote refresh parent moved"):
                release.prove_refresh(self.root, repo, sandbox, self.env)

    def test_refuses_alternate_push_origin_and_hidden_local_dirt(self):
        repo = "popcre/designflow-frontend"
        refs = self.prepare_refresh(repo)
        self.g("remote", "set-url", "--push", "origin", "https://github.com/other/designflow-frontend.git")
        with self.assertRaisesRegex(ValueError, "canonical fetch and push origin"):
            release.refresh_context(self.root, repo, refs["sandbox-albert"], self.env)
        self.g("config", "--unset", "remote.origin.pushurl")
        self.g("update-index", "--assume-unchanged", "shared-db/mirror.sql")
        with self.assertRaisesRegex(ValueError, "hidden working-copy differences"):
            release.refresh_context(self.root, repo, refs["sandbox-albert"], self.env)

    def test_published_refresh_refuses_wrong_repository_and_untrusted_platform(self):
        repo = "popcre/designflow-frontend"
        refs = self.prepare_refresh(repo)
        with self.assertRaisesRegex(ValueError, "target or base refused"):
            release.refresh_context(self.root, "popcre/unrelated-repository", refs["sandbox-albert"], self.env)
        with patch.object(sys, "platform", "win32"):
            with self.assertRaisesRegex(ValueError, "require qualified Linux"):
                release.prove_refresh(self.root, repo, refs["sandbox-albert"], self.env)
        self.g("checkout", "-qb", "master")
        with self.assertRaisesRegex(ValueError, "isolated sandbox-albert or detached worktree"):
            release.refresh_context(self.root, repo, refs["sandbox-albert"], self.env)

    def test_native_refresh_keeps_action_and_archive_guards(self):
        self.verify_native_refresh_refusal(release.FRONTEND, "unapproved-chat.jsonl", b"raw transcript")

    def test_data_syncing_refresh_refuses_archives(self):
        self.verify_native_refresh_refusal(release.DATA_SYNCING, "unapproved-chat.jsonl", b"raw transcript")

    def test_data_syncing_refresh_refuses_application_owned_structure(self):
        self.verify_native_refresh_refusal(release.DATA_SYNCING, "supabase/application-owned.sql",
                                           b"protected contributor")

    OUTSIDE_MIRROR = b"cannot contribute source outside the read-only mirror"

    def test_mirror_gate_admits_top_level_published_handoff(self):
        self.assertNotIn(self.OUTSIDE_MIRROR, self.native_refresh_stderr(release.TRACKING, "HANDOFF.d/note.md"))

    def test_mirror_gate_refuses_nested_handoff(self):
        self.assertIn(self.OUTSIDE_MIRROR, self.native_refresh_stderr(release.TRACKING, "HANDOFF.d/sub/note.md"))

    def test_mirror_gate_refuses_non_markdown_handoff(self):
        self.assertIn(self.OUTSIDE_MIRROR, self.native_refresh_stderr(release.TRACKING, "HANDOFF.d/note.txt"))

    def native_refresh_stderr(self, repo, path):
        refs = self.prepare_refresh(repo, preserve_sandbox=True)
        self.g("checkout", "-q", "develop")
        (self.root / path).parent.mkdir(parents=True, exist_ok=True)
        (self.root / path).write_text("# synthetic published handoff\n")
        self.g("add", ".")
        self.g("commit", "-qm", "synthetic published handoff")
        develop = self.g("rev-parse", "HEAD")
        self.g("update-ref", "refs/remotes/origin/develop", develop)
        self.g("checkout", "-q", "--detach", refs["sandbox-albert"])
        toolkit = Path(__file__).resolve().parents[1]
        env = {**self.env, "AI_TASK_GATES_DIR": str(Path(self.temp.name) / "isolated-state")}
        command = ["/bin/bash", str(toolkit / "bin/ai-task-gates")]
        start = subprocess.run(command + ["start", "--class", "deployment", "--base", "HEAD"],
                               cwd=self.root, env=env, capture_output=True)
        self.assertEqual(start.returncode, 0, start.stderr.decode())
        self.g("merge", "-q", "--no-edit", "--no-ff", develop)
        checked = subprocess.run(command + ["check", "--before", "deploy", "--published-sandbox-refresh",
                                            "--acknowledge", "synthetic owner instruction"],
                                 cwd=self.root, env=env, capture_output=True)
        self.assertEqual(checked.returncode, 3, checked.stderr.decode())
        return checked.stderr

    def verify_native_refresh_refusal(self, repo, path, expected):
        refs = self.prepare_refresh(repo)
        self.g("checkout", "-q", "develop")
        (self.root / path).write_text("synthetic test fixture\n")
        self.g("add", ".")
        self.g("commit", "-qm", "synthetic raw archive path")
        develop = self.g("rev-parse", "HEAD")
        self.g("update-ref", "refs/remotes/origin/develop", develop)
        self.g("checkout", "-q", "--detach", refs["sandbox-albert"])
        toolkit = Path(__file__).resolve().parents[1]
        env = {**self.env, "AI_TASK_GATES_DIR": str(Path(self.temp.name) / "isolated-state")}
        command = ["/bin/bash", str(toolkit / "bin/ai-task-gates")]
        start = subprocess.run(command + ["start", "--class", "deployment", "--base", "HEAD"],
                               cwd=self.root, env=env, capture_output=True)
        self.assertEqual(start.returncode, 0, start.stderr.decode())
        self.g("merge", "-q", "--no-edit", "--no-ff", develop)
        args = ["--published-sandbox-refresh", "--acknowledge", "synthetic owner instruction"]
        for action, failure in [("production", b"requires deployment"), ("database", b"requires deployment"),
                                ("deploy", expected)]:
            checked = subprocess.run(command + ["check", "--before", action] + args,
                                     cwd=self.root, env=env, capture_output=True)
            self.assertEqual(checked.returncode, 3, checked.stderr.decode())
            self.assertIn(failure, checked.stderr)

    def test_frontend_refresh_cloud_trigger_and_test_build_are_required(self):
        self.verify_refresh_cloud(release.FRONTEND)

    def test_data_syncing_requires_the_exact_cloud_trigger_and_both_prior_checks(self):
        self.verify_refresh_cloud(release.DATA_SYNCING)

    def test_other_mirror_targets_require_their_sandbox_trigger_and_build_checks(self):
        for repo in (release.BACKEND, release.BFF, release.ITEM_MASTER, release.TRACKING):
            with self.subTest(repo=repo), tempfile.TemporaryDirectory() as fixture:
                old_root = self.root
                self.root = Path(fixture)
                # The fixture for Cloud Build only needs a committed source tree.
                self.g("init", "-q")
                self.g("config", "user.name", "Offline fixture")
                self.g("config", "user.email", "fixture@example.invalid")
                try:
                    self.verify_refresh_cloud(repo, prepared=True)
                finally:
                    self.root = old_root

    def verify_refresh_cloud(self, repo, prepared=False):
        if not prepared:
            self.prepare_refresh(repo, fast_forward=True)
        (self.root / ".dockerignore").write_text("shared-db\n")
        (self.root / "Dockerfile").write_text("RUN yarn test\nRUN yarn build:${NODE_ENV}\n")
        self.g("add", ".")
        self.g("commit", "-qm", "published application test build inputs")
        develop = self.g("rev-parse", "HEAD")
        project, region = "lithe-breaker-323913", "us-east4"
        source, sandbox_service, develop_service = release.REFRESH_TARGETS[repo]
        linked = f"projects/{project}/locations/{region}/connections/popcre/repositories/{source}"
        github = f"https://github.com/{repo}.git"
        develop_trigger = "a" * 36
        sandbox_trigger = "b" * 36
        build_id = "c" * 36
        def trigger(identifier, branch, service, ignored):
            return {"id": identifier, "name": service, "filename": "cloudbuild.yaml",
                    "repositoryEventConfig": {"repository": linked, "repositoryType": "GITHUB",
                                              "push": {"branch": f"^{branch}$"}},
                    "ignoredFiles": ignored, "substitutions": {
                        "_REGION": region, "_APP_ENV": branch, "_SERVICE_NAME": service}}
        sandbox = trigger(sandbox_trigger, "sandbox-albert", sandbox_service, [])
        development = trigger(develop_trigger, "develop", develop_service, ["shared-db/**"])
        use_develop = repo == release.DATA_SYNCING
        tested_trigger = develop_trigger if use_develop else sandbox_trigger
        build = {"id": build_id, "status": "SUCCESS", "buildTriggerId": tested_trigger,
                 "sourceProvenance": {"resolvedGitSource": {"url": github, "revision": develop}},
                 "substitutions": {"COMMIT_SHA": develop}, "steps": [
                     {"id": "Build" if repo == release.FRONTEND else "Build the image",
                      "name": "gcr.io/cloud-builders/docker", "status": "SUCCESS", "args": ["build", "."]}]}
        database_app = repo not in {release.FRONTEND, release.BFF}
        if database_app:
            sandbox["substitutions"].update(
                _DB_PROVIDER="supabase", _DB_NETWORK_PATH="public-pooler", _DB_SCHEMA="dflow",
                _DB_EXPECTED_PORT="6543", _DB_SSL="true")
            build["steps"].append(
                {"id": "Validate database deployment contract", "name": "node:24-alpine",
                 "status": "SUCCESS", "entrypoint": "node", "args": ["scripts/validate-db-deploy-contract.js"]})
        if repo in release.UNIT_TEST_STEPS:
            image, command = release.UNIT_TEST_STEPS[repo]
            build["steps"].append(
                {"id": "Run unit tests", "name": image, "status": "SUCCESS", "entrypoint": "sh",
                 "args": ["-c", command]})
        responses = {
            ("config", "list"): None,
            ("builds", "repositories"): {"name": linked, "remoteUri": github},
            ("builds", "triggers"): [sandbox, development],
            ("builds", "list"): [build],
            ("builds", "describe"): build,
        }
        original_run = release.run
        cloud_home = self.root / "cloud-home"
        (cloud_home / ".config").mkdir(parents=True, mode=0o700)
        (cloud_home / ".config" / "gcloud").mkdir(mode=0o700)
        def boundary(argv, root, env, **kwargs):
            if argv[0] != "/fixture/gcloud":
                return original_run(argv, root, env, **kwargs)
            self.assertEqual(env, {"HOME": str(cloud_home), "PATH": "/usr/bin:/bin"})
            return json.dumps(responses[tuple(argv[2:4])]).encode()
        with patch.object(release, "public_binary", return_value="/fixture/gcloud"), \
                patch("pwd.getpwuid", return_value=SimpleNamespace(pw_dir=str(cloud_home))), \
                patch.object(release, "run", side_effect=boundary):
            supplied = {**self.env, "HTTPS_PROXY": "fixture.invalid", "CLOUDSDK_CONFIG": "/foreign",
                        "SSL_CERT_DIR": "/foreign", "GOOGLE_APPLICATION_CREDENTIALS": "/foreign"}
            branch = "develop" if use_develop else "sandbox"
            self.assertEqual(release.cloud_refresh_proof(self.root, repo, develop, supplied),
                             {"sandbox_trigger": sandbox_trigger, f"tested_{branch}_build": build_id,
                              f"tested_{branch}_source": develop})
            build["steps"][0]["status"] = "FAILURE"
            with self.assertRaisesRegex(ValueError, "test-and-build step unavailable"):
                release.cloud_refresh_proof(self.root, repo, develop, self.env)
            build["steps"][0]["status"] = "SUCCESS"
            for step in build["steps"][1:]:
                step["status"] = "FAILURE"
                with self.assertRaisesRegex(ValueError, "database contract or unit test step unavailable"):
                    release.cloud_refresh_proof(self.root, repo, develop, self.env)
                step["status"] = "SUCCESS"
            if database_app:
                sandbox["substitutions"]["_DB_SCHEMA"] = "dflow_prod"
                with self.assertRaisesRegex(ValueError, "enabled Cloud Build target is unavailable"):
                    release.cloud_refresh_proof(self.root, repo, develop, self.env)
                sandbox["substitutions"]["_DB_SCHEMA"] = "dflow"
            sandbox["disabled"] = True
            with self.assertRaisesRegex(ValueError, "enabled Cloud Build target is unavailable"):
                release.cloud_refresh_proof(self.root, repo, develop, self.env)
            responses[("config", "list")] = {"proxy": {"address": "fixture.invalid"}}
            with self.assertRaisesRegex(ValueError, "alternate Cloud Build endpoint, proxy"):
                release.cloud_refresh_proof(self.root, repo, develop, self.env)

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

    def test_real_native_future_release_requires_exact_lane_before_approval(self):
        toolkit = Path(__file__).resolve().parents[1]
        declaration = self.root / ".ai-devops"
        declaration.mkdir()
        (declaration / "task-gates.json").write_text(json.dumps({
            "schema_version": 1, "gates": {"deployment": {
                "required": ["cloud-build-release-review"]}}}))
        policy = json.loads((toolkit / "config/task-gates.json").read_text())
        (declaration / "application-release-target.json").write_text(json.dumps(
            policy["application_source_releases"][self.repo]["target"]))
        (self.root / "cloudbuild.yaml").write_text("steps: []\n")
        self.g("add", ".ai-devops", "cloudbuild.yaml")
        self.g("commit", "-qm", "closed lane already upstream")
        upstream = self.g("rev-parse", "HEAD")
        self.g("checkout", "-qb", "review-branch")
        (self.root / "app.js").write_text("// next ordinary release\n")
        (self.root / "cloudbuild.yaml").write_text("steps: []\n# next pipeline\n")
        self.g("add", "app.js", "cloudbuild.yaml")
        self.g("commit", "-qm", "ordinary next release delta")
        env = {**self.env, "AI_TASK_GATES_FILE": str(toolkit / "config/task-gates.json"),
               "AI_TASK_GATES_DIR": str(Path(self.temp.name) / "isolated-state"),
               "AI_REVIEW_LIFECYCLE_DIR": str(Path(self.temp.name) / "isolated-lifecycle")}
        command = ["/bin/bash", str(toolkit / "bin/ai-task-gates")]
        declared = subprocess.run(command + ["start", "--class", "deployment", "--base", upstream],
                                  cwd=self.root, env=env, capture_output=True)
        self.assertEqual(declared.returncode, 0, declared.stderr.decode())
        refused = subprocess.run(command + ["check", "--before", "deploy"], cwd=self.root,
                                 env=env, capture_output=True)
        self.assertEqual(refused.returncode, 3)
        self.assertIn(b"requires explicit --application-release-target", refused.stderr)
        review = subprocess.run(command + ["check", "--before", "review"], cwd=self.root,
                                env=env, capture_output=True)
        self.assertEqual(review.returncode, 0, review.stderr.decode())

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

    def installed_fixture(self):
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

        return toolkit, source, filesystem

    def test_installed_helper_receipt_and_real_closure_refuse_tampering(self):
        toolkit, source, filesystem = self.installed_fixture()
        with patch.object(release, "Path", side_effect=filesystem):
            helper, proof = release.installed_helper(self.root, self.env)
            self.assertEqual(helper, toolkit / "bin/ai-gh")
            self.assertEqual(proof["source"], source)
            (toolkit / "tools/github-requests/telemetry.sh").write_text("# tampered\n")
            with self.assertRaises(ValueError):
                release.installed_helper(self.root, self.env)

    def test_installed_helper_fixed_source_cannot_be_replaced(self):
        toolkit, source, filesystem = self.installed_fixture()
        relative = "tools/github-requests/telemetry.sh"
        original = (toolkit / relative).read_bytes()
        forged = b"# replacement-backed forged helper\n"
        (toolkit / relative).write_bytes(forged)
        def tg(*args):
            return subprocess.check_output([release.GIT, "-C", str(toolkit), *args],
                                           env=self.env, stderr=subprocess.DEVNULL)
        tg("add", relative)
        tg("commit", "-qm", "synthetic replacement")
        substitute = tg("rev-parse", "HEAD").decode().strip()
        tg("update-ref", "HEAD", source)
        tg("replace", source, substitute)
        # Prove the actual Git substitution, not merely a mocked argv.
        self.assertEqual(tg("show", f"{source}:{relative}"), forged)
        raw = subprocess.check_output([release.GIT, "--no-replace-objects", "-C",
                                       str(toolkit), "show", f"{source}:{relative}"], env=self.env)
        self.assertEqual(raw, original)
        with patch.object(release, "Path", side_effect=filesystem):
            with self.assertRaises(ValueError):
                release.installed_helper(self.root, self.env)
            # Replacement metadata is not authority over receipt-pinned bytes.
            (toolkit / relative).write_bytes(original)
            _, proof = release.installed_helper(self.root, self.env)
            self.assertEqual(proof["closure"][relative], release.digest(original))


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


class QueueTimeoutContract(unittest.TestCase):
    """Portable boundary tests; never invoke GitHub or a provider."""
    def test_local_commands_retain_thirty_seconds(self):
        with patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 0, b"ok", b"")) as command:
            self.assertEqual(release.run(["git", "--version"], Path.cwd(), {}), b"ok")
        self.assertEqual(command.call_args.kwargs["timeout"], 30)
        self.assertEqual(command.call_count, 1)

    def test_only_exact_gated_remote_ref_get_has_six_hundred_seconds(self):
        repo = "popcre/designflow-frontend"
        response = json.dumps({"ref": "refs/heads/develop", "object": {
            "type": "commit", "sha": "a" * 40}}).encode()
        with patch.object(release, "public_binary"), patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 0, response, b"")) as command:
            self.assertEqual(release.remote_ref(Path.cwd(), repo, Path("/fixture/helper"), {}), "a" * 40)
        self.assertEqual(command.call_args.kwargs["timeout"], 600)
        self.assertEqual(command.call_count, 1)
        self.assertEqual(command.call_args.args[0][-1], "repos/popcre/designflow-frontend/git/ref/heads/develop")
        self.assertIn(str(Path("/fixture/helper")), command.call_args.args[0])

    def test_remote_deadline_refuses_once_without_retry_or_receipt(self):
        with patch.object(release, "public_binary"), patch.object(subprocess, "run", side_effect=subprocess.TimeoutExpired("fixture", 600)) as command:
            with self.assertRaises(subprocess.TimeoutExpired):
                release.remote_ref(Path.cwd(), "popcre/designflow-frontend", Path("/fixture/helper"), {})
        self.assertEqual(command.call_count, 1)
        self.assertEqual(command.call_args.kwargs["timeout"], 600)
        with patch.object(release, "prove", side_effect=subprocess.TimeoutExpired("fixture", 600)), \
                patch.object(sys, "argv", ["proof", "prove", str(Path.cwd()), "popcre/designflow-frontend", "a" * 40]):
            self.assertEqual(release.main(), 3)


if __name__ == "__main__":
    unittest.main()
