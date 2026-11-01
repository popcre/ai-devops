"""Native Windows supervisor integration; no network requests or machine changes."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


@unittest.skipUnless(sys.platform == "win32" and os.environ.get("RUN_MANAGED_WINDOWS_SOURCE_INTEGRATION") == "1",
                     "explicit managed native Windows integration required")
class WindowsGeneration(unittest.TestCase):
    def test_installed_generation_custody_and_original_exit(self):
        import msvcrt

        supervisor = Path(os.environ.get("GENERATION_SUPERVISOR", Path(__file__).parents[1] / "tools/github-requests/source_generation_windows.ps1"))
        root = Path(os.environ.get("GENERATION_INSTALLED_ROOT", "C:/repos/ai-devops"))
        for arguments, expected_exit, restricted in [(["--help"], 0, False), (["not-a-pr"], 3, False), (["--help"], 0, True)]:
            with self.subTest(arguments=arguments), tempfile.TemporaryDirectory(prefix="ai-generation-parent-") as temporary:
                args = Path(temporary) / "args.json"
                args.write_text(json.dumps(arguments), encoding="utf-8")
                read_fd, write_fd = os.pipe()
                ack_read, ack_write = os.pipe()
                write_handle = msvcrt.get_osfhandle(write_fd)
                ack_handle = msvcrt.get_osfhandle(ack_read)
                os.set_handle_inheritable(write_handle, True)
                os.set_handle_inheritable(ack_handle, True)
                startup = subprocess.STARTUPINFO()
                startup.lpAttributeList = {"handle_list": [write_handle, ack_handle]}
                environment = os.environ.copy()
                environment["AI_GH_SOURCE_VERIFIED"] = "forged"
                environment["AI_GH_SOURCE_SHA"] = "0" * 40
                snapshot_parents = [Path(os.environ["LOCALAPPDATA"]) / "Temp", Path(os.environ["ProgramFiles"])]
                before = {path for parent in snapshot_parents for path in parent.glob("ai-gh-generation-*")}
                command = ["powershell.exe", "-NoProfile", "-File", str(supervisor), "-SourceRoot", str(root),
                     "-EntryPoint", "bin/ai-pr-wait", "-ArgumentsFile", str(args),
                     "-ReceiptHandle", str(write_handle), "-ReceiptAckHandle", str(ack_handle)]
                if restricted:
                    command.append("-RestrictedReadProfile")
                child = subprocess.Popen(
                    command,
                    startupinfo=startup, close_fds=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    cwd=temporary, env=environment,
                )
                os.close(write_fd)
                os.close(ack_read)
                try:
                    with os.fdopen(read_fd, "rb") as stream:
                        # The supervisor's ACK deadline bounds abandoned receipt custody.
                        line = stream.readline(65537)
                    if not line:
                        stdout, stderr = child.communicate(timeout=10)
                        self.fail("supervisor did not produce a live source receipt: " + stderr.decode(errors="replace"))
                    self.assertLessEqual(len(line), 65536)
                    record = json.loads(line)
                    self.assertIn(record["source_verified"], ["verified", "unknown"])
                    if restricted:
                        self.assertEqual(record["source_verified"], "verified")
                    elif record["source_verified"] == "unknown":
                        self.assertEqual(record["boundary_detail"], "privileged_original_context")
                    self.assertNotEqual(record["source_sha"], "0" * 40)
                    if record["child_exit"] != expected_exit:
                        os.write(ack_write, b"\x01")
                        stdout, stderr = child.communicate(timeout=40)
                        self.fail(f"child exit {record['child_exit']} != {expected_exit}: {stderr.decode(errors='replace')}")
                    self.assertEqual(record["source_boundary"], "windows_locked_generation")
                    self.assertIsNone(record["clock_error_bound_ms"])
                    launcher = Path.home() / ".local/bin/ai-task-gates.cmd"
                    self.assertEqual(record["install_generation_binding"], hashlib.sha256(launcher.read_bytes()).hexdigest())
                    snapshots = {path for parent in snapshot_parents for path in parent.glob("ai-gh-generation-*")} - before
                    self.assertEqual(len(snapshots), 1)
                    snapshot = snapshots.pop()
                    sealed = snapshot / "bin/ai-pr-wait"
                    with self.assertRaises(OSError):
                        sealed.open("r+b")
                    with self.assertRaises(OSError):
                        snapshot.rename(snapshot.with_name(snapshot.name + "-replaced"))
                    # No canonical source byte is modified; only prove write access remains.
                    with (root / "bin/ai-pr-wait").open("r+b"):
                        pass
                    self.assertIsNone(child.poll(), "custody ended before parent receipt consumption")
                    os.write(ack_write, b"\x01")
                    stdout, stderr = child.communicate(timeout=40)
                    self.assertEqual(child.returncode, expected_exit, stderr.decode(errors="replace"))
                    if expected_exit == 0:
                        self.assertIn(b"ai-pr-wait", stdout)
                    else:
                        self.assertIn(b"give a pull request number", stderr)
                    self.assertFalse(snapshot.exists())
                finally:
                    os.close(ack_write)
                    if child.poll() is None:
                        try:
                            child.communicate(timeout=10)
                        except subprocess.TimeoutExpired:
                            child.kill()
                            child.communicate(timeout=10)


if __name__ == "__main__":
    unittest.main()
