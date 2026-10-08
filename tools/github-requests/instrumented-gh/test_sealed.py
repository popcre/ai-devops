#!/usr/bin/env python3
"""Linux verify/use replacement attacks; no Go or live network required."""
import fcntl
import hashlib
import io
import os
import pathlib
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest

import sealed


def archive_bytes(content):
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode="w") as archive:
        entry = tarfile.TarInfo("toolchain")
        entry.size = len(content)
        archive.addfile(entry, io.BytesIO(content))
    return output.getvalue()


class SealedUse(unittest.TestCase):
    def test_hostile_self_path_refuses_cli_and_api_before_any_execution(self):
        import json
        import run
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as scratch:
            root = pathlib.Path(scratch)
            marker = root / 'executed'
            hostile = root / 'hostile'
            hostile.write_text('#!/bin/sh\ntouch "' + str(marker) + '"\n')
            hostile.chmod(0o700)
            env = dict(os.environ, GH_PATH=str(hostile))
            read_fd, write_fd = os.pipe()
            try:
                result = subprocess.run([sys.executable, str(pathlib.Path(run.__file__)),
                    '--binary', str(hostile), '--sha256', '0'*64, '--api-host', 'localhost',
                    '--metadata-fd', str(write_fd), '--', 'api', 'private'],
                    env=env, pass_fds=(write_fd,), capture_output=True, timeout=10)
            finally:
                os.close(write_fd)
            with os.fdopen(read_fd, 'rb') as channel:
                self.assertEqual(json.loads(channel.read()), run.UNKNOWN)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(result.stdout, b'')
            with patch.dict(os.environ, {'GH_PATH': str(hostile)}):
                self.assertEqual(run.run_counted(hostile, ['api', 'private'], 'localhost', '0'*64), (2, run.UNKNOWN))
                self.assertEqual(run.run_verified(None, hostile, ['api', 'private'], 'localhost'), (2, run.UNKNOWN))
            self.assertFalse(marker.exists())

    def test_raw_sealed_image_executes_with_empty_self_path(self):
        with tempfile.TemporaryDirectory() as scratch:
            binary = pathlib.Path(scratch) / 'verified-python'
            shutil.copyfile(sys.executable, binary)
            binary.chmod(0o700)
            artifact = {'path': str(binary), 'sha256': hashlib.sha256(binary.read_bytes()).hexdigest()}
            result = sealed.verified_run(artifact, ['-c', 'import os; print(os.environ.get("GH_PATH", ""))'],
                                         env=dict(os.environ, GH_PATH=''), capture_output=True, timeout=10)
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, b'\n', b''))

    def test_hostile_go_configuration_not_inherited(self):
        import build
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as scratch:
            root = pathlib.Path(scratch)
            hostile = {'GOENV': '/attacker/config', 'GOFLAGS': '-toolexec=/attacker/run',
                       'GOTOOLCHAIN': 'auto', 'GOSUMDB': 'off', 'GOINSECURE': '*',
                       'HOME': '/attacker', 'PATH': '/attacker'}
            with patch.dict(os.environ, hostile):
                env = build.build_environment(root, root / 'toolchain')
            self.assertEqual(env['GOENV'], 'off')
            self.assertEqual(env['GOTOOLCHAIN'], 'local')
            self.assertEqual(env['HOME'], str(root / 'home'))
            for key in ('GOFLAGS', 'GOSUMDB', 'GOINSECURE'):
                self.assertNotIn(key, env)

    def test_replaceable_parent_refuses_before_creation(self):
        with tempfile.TemporaryDirectory() as scratch:
            parent = pathlib.Path(scratch) / 'unsafe'
            parent.mkdir(mode=0o777)
            parent.chmod(0o777)
            output = parent / 'output'
            output.mkdir(mode=0o700)
            with self.assertRaisesRegex(ValueError, 'replaceable output ancestor'):
                sealed.private_directory(output)

    def test_output_replaced_after_validation_stays_anchored(self):
        with tempfile.TemporaryDirectory() as scratch:
            output = pathlib.Path(scratch) / 'output'
            output.mkdir(mode=0o700)
            fd = sealed.private_directory(output)
            try:
                saved = output.with_name('saved')
                output.rename(saved)
                output.mkdir(mode=0o700)
                anchored = pathlib.Path(f'/proc/{os.getpid()}/fd/{fd}')
                (anchored / 'receipt').write_text('verified')
                self.assertFalse((output / 'receipt').exists())
                self.assertEqual((saved / 'receipt').read_text(), 'verified')
            finally:
                os.close(fd)

    def test_fixture_and_measurement_shared_execution_sealed(self):
        with tempfile.TemporaryDirectory() as scratch:
            binary = pathlib.Path(scratch) / 'binary'
            shutil.copyfile(sys.executable, binary)
            artifact = {'path': str(binary), 'sha256': hashlib.sha256(binary.read_bytes()).hexdigest()}
            original = sealed.verified_snapshot
            def swap(path, digest):
                snapshot = original(path, digest)
                binary.write_bytes(b'not an executable')
                return snapshot
            from unittest.mock import patch
            with patch.object(sealed, 'verified_snapshot', swap):
                result = sealed.verified_run(artifact, ['-c', 'print("VERIFIED")'], capture_output=True)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout, b'VERIFIED\n')

    def test_archive_replacement_after_verification_uses_original(self):
        with tempfile.TemporaryDirectory() as scratch:
            path = pathlib.Path(scratch) / "archive.tar"
            original = archive_bytes(b"verified-toolchain")
            path.write_bytes(original)
            with sealed.verified_snapshot(path, hashlib.sha256(original).hexdigest()) as snapshot:
                replacement = pathlib.Path(scratch) / "replacement.tar"
                replacement.write_bytes(archive_bytes(b"attacker-toolchain"))
                os.replace(replacement, path)
                with tarfile.open(fileobj=snapshot) as archive:
                    self.assertEqual(archive.extractfile("toolchain").read(), b"verified-toolchain")

    def test_original_inode_mutation_cannot_change_sealed_bytes(self):
        with tempfile.TemporaryDirectory() as scratch:
            path = pathlib.Path(scratch) / "input"
            path.write_bytes(b"verified")
            with sealed.verified_snapshot(path, hashlib.sha256(b"verified").hexdigest()) as snapshot:
                path.write_bytes(b"attacker")
                self.assertEqual(snapshot.read(), b"verified")
                with self.assertRaises(OSError):
                    os.pwrite(snapshot.fileno(), b"attacker", 0)
                with self.assertRaises(OSError):
                    os.ftruncate(snapshot.fileno(), 0)
                flags = fcntl.fcntl(snapshot.fileno(), fcntl.F_GET_SEALS)
                self.assertTrue(flags & fcntl.F_SEAL_WRITE)

    def test_binary_replaced_at_exact_verify_execute_gap(self):
        with tempfile.TemporaryDirectory() as scratch:
            scratch = pathlib.Path(scratch)
            binary = scratch / "pinned-binary"
            shutil.copyfile(sys.executable, binary)
            binary.chmod(0o700)
            digest = hashlib.sha256(binary.read_bytes()).hexdigest()
            # A fresh subprocess captures ordinary command streams. Hook
            # replacement happens after verification but before Popen, exactly
            # where the valid security REJECT found the vulnerable window.
            script = '''import os, pathlib, shutil, sys
import sealed
original = sealed.verified_snapshot
def swapped(path, expected):
    snapshot = original(path, expected)
    replacement = pathlib.Path(path).with_suffix('.attacker')
    shutil.copyfile('/bin/false', replacement)
    replacement.chmod(0o700)
    os.replace(replacement, path)
    return snapshot
sealed.verified_snapshot = swapped
result = sealed.verified_run({'path': sys.argv[1], 'sha256': sys.argv[2]}, ['-c', 'print("VERIFIED")'], capture_output=True)
sys.stdout.buffer.write(result.stdout)
sys.stderr.buffer.write(result.stderr)
raise SystemExit(result.returncode)
'''
            result = subprocess.run([sys.executable, "-c", script, str(binary), digest],
                                    cwd=pathlib.Path(__file__).parent, capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout, b"VERIFIED\n")
            self.assertEqual(result.stderr, b"")
            self.assertEqual(hashlib.sha256(binary.read_bytes()).hexdigest(),
                             hashlib.sha256(pathlib.Path("/bin/false").read_bytes()).hexdigest())

    def test_wrong_digest_and_symlink_refuse(self):
        with tempfile.TemporaryDirectory() as scratch:
            path = pathlib.Path(scratch) / "input"
            path.write_bytes(b"original")
            with self.assertRaises(ValueError):
                sealed.verified_snapshot(path, "0" * 64)
            link = path.with_suffix(".link")
            link.symlink_to(path)
            with self.assertRaises(OSError):
                sealed.verified_snapshot(link, hashlib.sha256(b"original").hexdigest())


if __name__ == "__main__":
    unittest.main()
