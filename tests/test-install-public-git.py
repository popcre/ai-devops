#!/usr/bin/env python3
"""Offline public-source ownership regression; root adds actual owner proof."""
import importlib.util
import io
import os
import pathlib
import pwd
import shutil
import stat
import subprocess
import tempfile
import unittest
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("install_public_git", ROOT / "tools/lib/install-public-git.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class PublicGitTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="public-git-")
        self.parent = pathlib.Path(self.temporary.name)
        self.parent.chmod(0o755)
        self.repo = self.parent / "source"
        self.repo.mkdir()
        self.git("init", "-q")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        (self.repo / "old").write_text("old\n")
        self.git("add", "old")
        self.git("commit", "-qm", "before")
        self.before = self.git("rev-parse", "HEAD").strip()
        directory = self.repo / "new-directory"; directory.mkdir()
        (directory / "read.py").write_text("print('fixture')\n")
        (directory / "run").write_text("#!/bin/sh\nexit 0\n")
        (directory / "run").chmod(0o755)
        (self.repo / "old").write_text("modified fixture\n")
        self.git("add", "old", "new-directory")
        self.git("commit", "-qm", "after")
        self.after = self.git("rev-parse", "HEAD").strip()
        self.git("checkout", "-q", "--detach", self.before)
        self.owner = pwd.getpwnam("nobody") if os.geteuid() == 0 else pwd.getpwuid(os.geteuid())
        if os.geteuid() == 0:
            # Only this disposable test tree changes owner, before the tested
            # update. There is no deployed checkout or private data in it.
            for directory, children, files in os.walk(self.repo):
                for path in [pathlib.Path(directory), *(pathlib.Path(directory) / name for name in files)]:
                    os.chown(path, self.owner.pw_uid, self.owner.pw_gid)
        self.trust = mock.patch.dict(os.environ, {"GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "safe.directory",
                                                 "GIT_CONFIG_VALUE_0": str(self.repo)})
        self.trust.start()

    def tearDown(self):
        self.trust.stop()
        self.temporary.cleanup()

    def git(self, *arguments):
        return subprocess.check_output(["git", "-C", str(self.repo), *arguments], text=True, stderr=subprocess.DEVNULL)

    def test_restrictive_parent_keeps_public_readability_and_private_state(self):
        private = self.repo / "untracked-private"; private.write_text("fixture only"); private.chmod(0o600)
        config = self.repo / ".git/config"
        snapshots = {path: (helper.metadata(path), path.read_bytes()) for path in (private, config)}
        original = os.umask(0o077)
        try:
            self.assertEqual(helper.public_git(self.repo, ["checkout", "--detach", self.after]), 0)
            self.assertEqual(os.umask(0o077), 0o077)
            log = self.parent / "protected.log"
            descriptor = os.open(log, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600); os.close(descriptor)
            self.assertEqual(stat.S_IMODE(log.stat().st_mode), 0o600)
        finally: os.umask(original)
        for name, mode in [("old", 0o644), ("new-directory", 0o755), ("new-directory/read.py", 0o644), ("new-directory/run", 0o755)]:
            info = (self.repo / name).stat()
            self.assertEqual((info.st_uid, info.st_gid, stat.S_IMODE(info.st_mode)),
                             (self.owner.pw_uid, self.owner.pw_gid, mode))
        for path, expected in snapshots.items():
            self.assertEqual((helper.metadata(path), path.read_bytes()), expected)
        if os.geteuid() == 0:
            command = ["runuser", "-u", self.owner.pw_name, "--", "git", "-C", str(self.repo), "status", "--porcelain", "--untracked-files=no"]
            self.assertEqual(subprocess.check_output(command, text=True).strip(), "")

    def test_new_worktrees_container_supports_later_owner_creation(self):
        first = self.parent / "root-candidate"
        self.assertEqual(helper.public_git(self.repo, ["worktree", "add", "--detach", str(first), self.after]), 0)
        container = self.repo / ".git/worktrees"
        self.assertEqual(container.stat().st_uid, self.owner.pw_uid)
        record = container / first.name
        # The first candidate's record keeps the invoking identity, not the
        # canonical owner: another worktree's contents are not a repair target.
        self.assertEqual(record.stat().st_uid, os.geteuid())
        second = self.parent / "owner-candidate"
        if os.geteuid() == 0:
            os.chown(self.parent, self.owner.pw_uid, self.owner.pw_gid)
            subprocess.run(["runuser", "-u", self.owner.pw_name, "--", "git", "-C", str(self.repo),
                            "worktree", "add", "--detach", str(second), self.after], check=True,
                           capture_output=True, text=True)
        else:
            subprocess.run(["git", "-C", str(self.repo), "worktree", "add", "--detach", str(second), self.after],
                           check=True, capture_output=True, text=True)

    def test_failed_git_preserves_original_status(self):
        result = subprocess.run(["git", "-C", str(self.repo), "rev-parse", "--verify", "refs/heads/absent"], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(helper.public_git(self.repo, ["rev-parse", "--verify", "refs/heads/absent"]), result.returncode)
        if os.geteuid() == 0:
            diagnostic = io.StringIO()
            with mock.patch.object(helper, "restore_outputs", side_effect=OSError("fixture recovery failure")), mock.patch.object(helper.sys, "stderr", diagnostic):
                self.assertEqual(helper.public_git(self.repo, ["rev-parse", "--verify", "refs/heads/absent"]), result.returncode)
            self.assertIn("ownership restoration failed", diagnostic.getvalue())

    @unittest.skipUnless(os.geteuid() == 0, "root-owned checkout fixture requires root")
    def test_root_owned_checkout_keeps_its_original_account(self):
        owned = self.parent / "root-owned"
        owned.mkdir()
        subprocess.run(["git", "-C", str(owned), "init", "-q"], check=True)
        (owned / "file").write_text("root fixture\n")
        subprocess.run(["git", "-C", str(owned), "add", "file"], check=True)
        subprocess.run(["git", "-C", str(owned), "-c", "user.name=Fixture", "-c",
                        "user.email=fixture@example.invalid", "commit", "-qm", "root fixture"], check=True)
        self.assertEqual(helper.public_git(owned, ["checkout", "--detach", "HEAD"]), 0)
        self.assertEqual((owned / "file").stat().st_uid, 0)

    @unittest.skipUnless(os.geteuid() == 0, "actual ownership transition requires root")
    def test_existing_file_new_inode_transition_restores_source_owner(self):
        path = self.repo / "old"
        descriptor = os.open(path, os.O_RDONLY)
        before = os.fstat(descriptor)
        try:
            self.assertEqual(helper.public_git(self.repo, ["checkout", "--detach", self.after]), 0)
            after = path.stat()
            # Holding the old inode prevents its reuse: exercise the normal
            # distinct-inode case alongside the unheld modified-file case above.
            self.assertNotEqual((after.st_dev, after.st_ino), (before.st_dev, before.st_ino))
            self.assertEqual(after.st_uid, self.owner.pw_uid)
            self.assertEqual(path.read_text(), "modified fixture\n")
            self.assertEqual(os.read(descriptor, 100), b"old\n")
        finally: os.close(descriptor)

    @unittest.skipUnless(os.geteuid() == 0, "actual preexisting root-owned file requires root")
    def test_preexisting_root_file_same_inode_inplace_edit_keeps_owner(self):
        path = self.repo / "old"
        os.chown(path, 0, 0)
        before = helper.metadata(path)
        real_run = subprocess.run
        def git_then_inplace_edit(*args, **kwargs):
            result = real_run(*args, **kwargs)
            if "reset" in args[0]:
                path.write_text("modified fixture\n")
                directory = self.repo / "new-directory"; directory.mkdir()
                (directory / "read.py").write_text("print('fixture')\n")
                (directory / "run").write_text("#!/bin/sh\nexit 0\n")
                (directory / "run").chmod(0o755)
            return result
        with mock.patch.object(helper.subprocess, "run", side_effect=git_then_inplace_edit):
            self.assertEqual(helper.public_git(self.repo, ["reset", "--mixed", self.after]), 0)
        after = helper.metadata(path)
        self.assertEqual(after[:4], before[:4])
        self.assertNotEqual(after[5], before[5])
        self.assertEqual(path.read_text(), "modified fixture\n")

    def test_fetch_outputs_remain_readable_by_source_owner(self):
        upstream = self.parent / "upstream"; upstream.mkdir()
        subprocess.run(["git", "-C", str(upstream), "init", "-q"], check=True)
        (upstream / "new-object").write_text("independent fixture object\n")
        subprocess.run(["git", "-C", str(upstream), "add", "new-object"], check=True)
        subprocess.run(["git", "-C", str(upstream), "-c", "user.name=Fixture", "-c",
                        "user.email=fixture@example.invalid", "commit", "-qm", "new upstream object"], check=True)
        before = set(helper.primary_metadata(self.repo / ".git"))
        original = os.umask(0o077)
        try:
            self.assertEqual(helper.public_git(self.repo, ["-c", "fetch.unpackLimit=1", "fetch", "--no-tags", str(upstream), "HEAD"]), 0)
        finally: os.umask(original)
        created = set(helper.primary_metadata(self.repo / ".git")) - before
        self.assertTrue(any(path.suffix == ".pack" for path in created))
        for path in created:
            info = path.stat()
            self.assertEqual(info.st_uid, self.owner.pw_uid)
            self.assertEqual(stat.S_IMODE(info.st_mode), 0o755 if path.is_dir() else 0o644 if path.name == "FETCH_HEAD" else 0o444)

    @unittest.skipUnless(os.geteuid() == 0, "actual foreign-root inode test requires root")
    def test_foreign_root_inode_swap_aborts_without_changing_it(self):
        original_open = helper.pinned_open
        swapped = []
        def replace_before_open(base, path):
            if path.name == "read.py" and not swapped:
                replacement = path.with_name("foreign-output")
                replacement.write_text("foreign fixture")
                os.replace(replacement, path)
                swapped.append(path)
            return original_open(base, path)
        with mock.patch.object(helper, "pinned_open", side_effect=replace_before_open):
            with self.assertRaisesRegex(ValueError, "outside updater custody"):
                helper.public_git(self.repo, ["checkout", "--detach", self.after])
        self.assertEqual(swapped[0].read_text(), "foreign fixture")
        self.assertEqual(swapped[0].stat().st_uid, 0)

    def test_parent_symlink_cannot_escape_pinned_base(self):
        outside = self.parent / "outside"; outside.mkdir()
        secret = outside / "file"; secret.write_text("fixture")
        (self.repo / "alias").symlink_to(outside, target_is_directory=True)
        with self.assertRaises(OSError): helper.pinned_open(self.repo, self.repo / "alias/file")

    def test_redirected_private_storage_is_refused_without_any_mutation(self):
        private = self.parent / "private-store"; private.mkdir()
        marker = private / "private-index"; marker.write_bytes(b"private fixture only")
        subprocess.run(["git", "-C", str(private), "init", "-q"], check=True)
        subprocess.run(["git", "-C", str(private), "add", "private-index"], check=True)
        subprocess.run(["git", "-C", str(private), "-c", "user.name=Fixture", "-c",
                        "user.email=fixture@example.invalid", "commit", "-qm", "private fixture"], check=True)
        index = private / ".git/index"
        snapshot = (helper.metadata(marker), marker.read_bytes(), index.read_bytes(), self.git("rev-parse", "HEAD"))
        for variable in helper.STORAGE_OVERRIDES:
            destination = private if variable == "GIT_WORK_TREE" else index if variable == "GIT_INDEX_FILE" else private / ".git/objects" if "OBJECT" in variable else private / ".git"
            with mock.patch.dict(os.environ, {variable: str(destination)}), mock.patch.object(helper.subprocess, "run") as run:
                with self.assertRaisesRegex(ValueError, "storage overrides"):
                    helper.public_git(self.repo, ["checkout", "--detach", self.after])
                run.assert_not_called()
            self.assertEqual((helper.metadata(marker), marker.read_bytes(), index.read_bytes(), self.git("rev-parse", "HEAD")), snapshot)

    def test_foreign_symlinked_primary_git_store_is_refused(self):
        private = self.parent / "foreign-context"; private.mkdir()
        subprocess.run(["git", "-C", str(private), "init", "-q"], check=True)
        (self.repo / ".git").rename(self.repo / "saved-primary")
        (self.repo / ".git").symlink_to(private / ".git", target_is_directory=True)
        with mock.patch.object(helper, "subprocess") as commands:
            commands.check_output.side_effect = subprocess.check_output
            with self.assertRaisesRegex(ValueError, "exact primary"):
                helper.public_git(self.repo, ["checkout", "--detach", self.after])
            commands.run.assert_not_called()

    def test_authentication_configuration_survives_identity_reads(self):
        real_output = subprocess.check_output
        environments = []
        def capture(*args, **kwargs):
            if "env" in kwargs: environments.append(kwargs["env"])
            return real_output(*args, **kwargs)
        with mock.patch.dict(os.environ, {"GIT_SSH_COMMAND": "ssh fixture-identity"}), mock.patch.object(helper.subprocess, "check_output", side_effect=capture):
            self.assertEqual(helper.public_git(self.repo, ["rev-parse", "HEAD"]), 0)
        self.assertGreaterEqual(len(environments), 2)
        self.assertTrue(all(env["GIT_SSH_COMMAND"] == "ssh fixture-identity" for env in environments))

    def test_new_private_primary_artifacts_are_never_repaired(self):
        real_run = subprocess.run
        snapshots = {}
        def run_and_create_private(*args, **kwargs):
            result = real_run(*args, **kwargs)
            if "checkout" in args[0] and not snapshots:
                common = self.repo / ".git"
                bucket = next(path for path in (common / "objects").iterdir()
                              if len(path.name) == 2 and path.is_dir())
                paths = [common / "objects/private-root-artifact", bucket / "private-root-artifact",
                         common / "objects/pack/private-root-artifact",
                         common / "objects/info/private-root-artifact",
                         common / "refs/private-root-artifact", common / "logs/private-root-artifact",
                         common / "objects/private-dir/artifact", common / "refs/private-dir/artifact",
                         common / "logs/private-dir/artifact"]
                for path in paths:
                    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
                    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
                    os.write(descriptor, b"private fixture only"); os.close(descriptor)
                    snapshots[path] = (helper.metadata(path), path.read_bytes())
                for path in paths[-3:]:
                    snapshots[path.parent] = (helper.metadata(path.parent), None)
            return result
        with mock.patch.object(helper.subprocess, "run", side_effect=run_and_create_private):
            self.assertEqual(helper.public_git(self.repo, ["checkout", "--detach", self.after]), 0)
        allowed = helper.primary_metadata(self.repo / ".git")
        for path, (info, content) in snapshots.items():
            self.assertNotIn(path, allowed)
            self.assertEqual(helper.metadata(path), info)
            if content is not None: self.assertEqual(path.read_bytes(), content)
        if os.geteuid() == 0:
            self.assertTrue(all(info[2] == 0 and info[4] in (0o600, 0o700) for info, _ in snapshots.values()))

    def test_foreign_replacement_is_not_modified(self):
        path = self.repo / "old"
        with mock.patch.object(helper, "subprocess") as commands:
            commands.check_output.side_effect = subprocess.check_output
            original_run = subprocess.run
            def mutation(*args, **kwargs):
                if "diff" in args[0]: return original_run(*args, **kwargs)
                old = path.with_name("replaced"); path.rename(old); path.write_text("new")
                return subprocess.CompletedProcess([], 0)
            commands.run.side_effect = mutation
            with mock.patch.object(helper.os, "geteuid", return_value=0), mock.patch.object(helper.os, "fchown") as change:
                # A non-root-owned foreign replacement never becomes an updater
                # output merely because its pathname was tracked previously.
                with self.assertRaisesRegex(ValueError, "outside the Git result"):
                    helper.public_git(self.repo, ["fixture"])
                change.assert_not_called()


    def test_status_read_through_wrapper_leaves_index_untouched(self):
        index = self.repo / ".git/index"
        before = (helper.metadata(index), index.read_bytes())
        original = os.umask(0o077)
        try:
            self.assertEqual(helper.public_git(self.repo, ["--no-optional-locks", "status", "--porcelain"]), 0)
        finally: os.umask(original)
        self.assertEqual((helper.metadata(index), index.read_bytes()), before)

    def test_updater_and_gates_status_checks_never_write_the_index(self):
        for relative in ("update.sh", "bin/ai-task-gates"):
            text = (ROOT / relative).read_text(encoding="utf-8")
            for number, line in enumerate(text.splitlines(), 1):
                if "status --porcelain" in line or "status --porcelain=v1" in line:
                    self.assertTrue("public_git" in line or "--no-optional-locks" in line,
                                    f"{relative}:{number} runs git status without ownership-safe routing")


if __name__ == "__main__":
    unittest.main()
