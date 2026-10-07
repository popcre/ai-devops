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
import sealed, run
original = sealed.verified_snapshot
def swapped(path, expected):
    snapshot = original(path, expected)
    replacement = pathlib.Path(path).with_suffix('.attacker')
    shutil.copyfile('/bin/false', replacement)
    replacement.chmod(0o700)
    os.replace(replacement, path)
    return snapshot
sealed.verified_snapshot = swapped
status, metadata = run.run_counted(sys.argv[1], ['-c', 'print("VERIFIED")'], 'localhost', sys.argv[2])
assert metadata['http_requests'] is None
assert metadata['observed_completed_writes'] is None
raise SystemExit(status)
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
