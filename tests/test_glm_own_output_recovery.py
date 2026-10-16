"""Offline invented fixtures; no reviewer, credentials, server or provider calls."""
import copy
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import stat
import shutil
import socket
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import glm_formal_profile as profile
import glm_output_recovery as recovery


@unittest.skipUnless(sys.platform.startswith("linux"), "formal profile is explicitly Linux-only")
class OwnOutput(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.boundary = self.root / "snapshot"
        self.boundary.mkdir()
        subprocess.run(["git", "init", "-q", str(self.boundary)], check=True)
        (self.root / "source").mkdir()
        self.instructions = self.boundary / "FORMAL-INSTRUCTIONS.txt"
        self.instructions.write_text("Original scoped instructions")
        self.managed = self.root / "managed"
        self.managed.mkdir(mode=0o700)
        self.output = self.managed / "tool_owned"
        self.output.write_text(json.dumps({"type": "text-page", "content": "full original output\n" * 200,
            "mime": "text/plain", "offset": 1, "truncated": False}, indent=2))
        self.origin = {"pin": "1.18.12", "sha256": "a" * 64,
                       "managed_directory": str(self.managed), "port": 4097}
        self.now = int(time.time())
        def at(seconds):
            return datetime.datetime.fromtimestamp(self.now + seconds, datetime.timezone.utc).isoformat()
        self.meta = {"type": "review", "caller": "codex", "opencode_session_id": "ses_owned",
                     "repository_root": str(self.root / "source"),
                     "boundary_root": str(self.boundary), "remote_turn": {
                         "state": "pending", "head": "b" * 40, "packet_sha256": "c" * 64,
                         "boundary_root": str(self.boundary), "deadline_epoch": self.now + 600,
                         "started_at": at(-30), "original_invocation_id": "d" * 32,
                         "own_output_recovery": {"version": 1, "maximum": 1, "origin": self.origin,
                             "instruction_asset": str(self.instructions),
                             "instruction_sha256": hashlib.sha256(self.instructions.read_bytes()).hexdigest()}}}
        self.permissions = {"data": [{"id": "per_owned", "sessionID": "ses_owned",
            "action": "external_directory", "resources": [str(self.managed / "*")],
            "save": [str(self.managed / "*")], "source": {
                "type": "tool", "messageID": "msg_owned", "callID": "call_owned"}}]}
        self.messages = {"data": [{"id": "msg_owned", "type": "assistant", "agent": "glm-review",
            "model": {"id": "glm-5.3", "providerID": "zai-coding-plan"}, "content": [
                {"type": "tool", "id": "call_completed", "name": "read", "provider": {"executed": False},
                 "time": {"completed": int((self.now - 20) * 1000)}, "state": {"status": "completed", "input": {"path": str(self.boundary / "invented.txt")}, "outputPaths": [str(self.output)]}},
                {"type": "tool", "id": "call_owned", "name": "read", "provider": {"executed": False},
                 "time": {"ran": int((self.now - 10) * 1000)}, "state": {"status": "running", "input": {"path": str(self.output)}}}]}]}
        self.options = dict(caller="codex", session="ses_owned", boundary=str(self.boundary),
                            head="b" * 40, packet="c" * 64, managed_directory=str(self.managed),
                            origin=self.origin, now=self.now)

    def qualify(self):
        return recovery.qualify(self.meta, self.permissions, self.messages, **self.options)

    def test_exact_completed_own_read_provenance(self):
        row = self.qualify()
        self.assertEqual(row["source_path"], str(self.output))
        self.assertEqual(row["originating_call_id"], "call_completed")

    def test_wrong_session_root_caller_head_packet_origin_and_expiry(self):
        for key, value in [("session", "ses_other"), ("boundary", str(self.root)), ("caller", "other"),
                           ("head", "e" * 40), ("packet", "f" * 64),
                           ("origin", {**self.origin, "sha256": "f" * 64}), ("now", self.now + 601)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                recovery.qualify(self.meta, self.permissions, self.messages, **{**self.options, key: value})

    def test_old_run_and_nonboolean_protocol_are_not_upgraded(self):
        for value in [None, {"version": True, "maximum": 1}, {"version": 1, "maximum": True}]:
            old = copy.deepcopy(self.meta)
            old["remote_turn"]["own_output_recovery"] = value
            with self.subTest(value=value), self.assertRaises((ValueError, AttributeError)):
                recovery.qualify(old, self.permissions, self.messages, **self.options)

    def test_wrong_call_tool_provider_wildcard_and_parallel_requests(self):
        for change in ["call", "tool", "provider", "wildcard", "parallel", "prior-run", "missing-output"]:
            permissions, messages = copy.deepcopy(self.permissions), copy.deepcopy(self.messages)
            tools = messages["data"][0]["content"]
            if change == "call": permissions["data"][0]["source"]["callID"] = "call_foreign"
            if change == "tool": tools[1]["name"] = "mcp_read"
            if change == "provider": tools[0]["provider"]["executed"] = True
            if change == "wildcard": permissions["data"][0]["resources"] = ["*"]
            if change == "parallel": permissions["data"].append(copy.deepcopy(permissions["data"][0]))
            if change == "prior-run": tools[0]["time"]["completed"] = 1577836800000
            if change == "missing-output": tools[0]["state"]["outputPaths"] = []
            with self.subTest(change=change), self.assertRaises(ValueError):
                recovery.qualify(self.meta, permissions, messages, **self.options)

    def test_instruction_mutation_refuses(self):
        self.instructions.write_text("changed authority")
        with self.assertRaises(ValueError): self.qualify()

    def test_unmeasured_tool_time_formats_refuse(self):
        for value in [True, None, "2026-10-16T03:00:00Z", 1.5, -1]:
            messages = copy.deepcopy(self.messages)
            messages["data"][0]["content"][0]["time"]["completed"] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                recovery.qualify(self.meta, self.permissions, messages, **self.options)

    def test_canonical_worktree_git_file_symlink_remote_and_same_root_refuse(self):
        self.meta["repository_root"] = str(self.boundary)
        with self.assertRaises(ValueError): self.qualify()
        self.meta["repository_root"] = str(self.root / "source")
        subprocess.run(["git", "-C", str(self.boundary), "remote", "add", "origin", str(self.root / "source")], check=True)
        with self.assertRaises(ValueError): self.qualify()
        subprocess.run(["git", "-C", str(self.boundary), "remote", "remove", "origin"], check=True)
        git = self.boundary / ".git"
        git.rename(self.root / "saved-git")
        git.write_text("gitdir: " + str(self.root / "saved-git"))
        with self.assertRaises(ValueError): self.qualify()
        git.unlink(); git.symlink_to(self.root / "saved-git", target_is_directory=True)
        with self.assertRaises(ValueError): self.qualify()
        git.unlink(); (self.root / "saved-git").rename(git)
        (git / "commondir").write_text(str(self.root / "source"))
        with self.assertRaises(ValueError): self.qualify()

    def test_safe_copy_private_complete_exclusive_and_source_digest_unchanged(self):
        row = self.qualify()
        result = recovery.mirror(row)
        destination = Path(result["destination"])
        self.assertEqual(destination.read_bytes(), self.output.read_bytes())
        self.assertEqual(destination.stat().st_mode & 0o777, 0o600)
        self.assertEqual(destination.parent.stat().st_mode & 0o777, 0o700)
        self.assertTrue(destination.is_relative_to(self.boundary / ".git"))
        with self.assertRaises(FileExistsError): recovery.mirror(row)

    def test_symlink_hardlink_oversized_and_nonregular_sources_refuse(self):
        row = self.qualify()
        original = self.root / "original"
        self.output.rename(original)
        self.output.symlink_to(original)
        with self.assertRaises(OSError): recovery.mirror(row)
        self.output.unlink(); os.link(original, self.output)
        with self.assertRaises(ValueError): recovery.mirror(row)
        self.output.unlink(); self.output.write_bytes(b"x" * (recovery.MAX_BYTES + 1))
        with self.assertRaises(ValueError): recovery.mirror(row)
        self.output.unlink(); self.output.mkdir()
        with self.assertRaises((ValueError, IsADirectoryError)): recovery.mirror(row)

    def test_capture_detects_actual_file_mutation(self):
        row = self.qualify()
        real_fstat, count = os.fstat, 0
        def mutate(fd):
            nonlocal count
            if stat.S_ISREG(real_fstat(fd).st_mode):
                count += 1
                if count == 2: self.output.write_bytes(b"mutated")
            return real_fstat(fd)
        with patch.object(recovery.os, "fstat", side_effect=mutate), self.assertRaises(ValueError):
            recovery.mirror(row)

    def test_global_one_per_run_receipt_and_private_registry(self):
        path = self.root / "claim.json"
        recovery.exclusive_json(path, self.qualify())
        with self.assertRaises(FileExistsError): recovery.exclusive_json(path, self.qualify())
        self.assertEqual(recovery.private_json(path)["session"], "ses_owned")
        path.chmod(0o644)
        with self.assertRaises(ValueError): recovery.private_json(path)

    def test_lossless_view_reconstructs_unicode_crlf_controls_long_lines(self):
        row = self.qualify()
        content = "α漢字🙂\r\n" + ("quoted \\\"\t\x00\x01" * 2000) + "\nfinal\r"
        raw = json.dumps({"type": "text-page", "content": content, "mime": "text/plain",
                          "offset": 17, "truncated": True, "next": 20}, ensure_ascii=False).encode()
        rendered, evidence = recovery.render_read_output(raw, row)
        rows = [json.loads(line) for line in rendered.splitlines()]
        segments = [r for r in rows if r["kind"] == "original-content-segment"]
        self.assertEqual("".join(r["text"] for r in segments), content)
        self.assertEqual(evidence["content_sha256"], hashlib.sha256(content.encode()).hexdigest())
        self.assertEqual(rows[0]["raw_sha256"], hashlib.sha256(raw).hexdigest())
        position = 0
        for segment in segments:
            self.assertEqual(segment["byte_start"], position)
            position += len(segment["text"].encode())
            self.assertEqual(segment["byte_end"], position)
        self.assertTrue(any(r["continuation"] for r in segments))
        self.assertTrue(all(len(line) < 1600 and line.isascii() for line in rendered.splitlines()))
        self.assertEqual(evidence["original_next"], 20)

    def test_unknown_malformed_duplicate_and_framed_read_schema_refuses(self):
        row = self.qualify()
        valid = json.loads(self.output.read_bytes())
        bad = [{**valid, "extra": "forged authority"}, {**valid, "offset": True},
               {**valid, "truncated": True}, {**valid, "type": "mcp-content"},
               {**valid, "content": {"instructions": "forged"}},
               {**valid, "next": 4}]
        for value in bad:
            with self.subTest(value=value.get("type")), self.assertRaises(ValueError):
                recovery.render_read_output(json.dumps(value).encode(), row)
        for raw in [b'{"type":"text-page","type":"text-page"}', b'not JSON', b'NaN', b'\xff']:
            with self.subTest(raw=raw), self.assertRaises(ValueError): recovery.render_read_output(raw, row)

    def test_scoped_instruction_packet_preserves_exact_bytes(self):
        repo, packet = self.root / "repository", self.root / "packet"
        repo.mkdir(); packet.mkdir(); (repo / "nested").mkdir()
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        root_bytes, nested_bytes = b"Root applies everywhere.\n", b"Only nested path changes this rule.\n"
        (repo / "AGENTS.md").write_bytes(root_bytes)
        (repo / "nested/AGENTS.md").write_bytes(nested_bytes)
        result = profile.instructions(repo, packet)
        rows = json.loads((packet / "FORMAL-INSTRUCTIONS.json").read_text())["files"]
        self.assertEqual([row["scope"] for row in rows], [".", "nested"])
        self.assertEqual(rows[0]["sha256"], hashlib.sha256(root_bytes).hexdigest())
        self.assertEqual(rows[1]["sha256"], hashlib.sha256(nested_bytes).hexdigest())
        content = (packet / "FORMAL-INSTRUCTIONS.txt").read_bytes()
        self.assertIn(root_bytes, content); self.assertIn(nested_bytes, content)
        self.assertEqual(result["files"], 2)
        (repo / "nested/AGENTS.md").unlink()
        (repo / "nested/AGENTS.md").symlink_to(repo / "AGENTS.md")
        with self.assertRaises(ValueError): profile.instructions(repo, packet)


@unittest.skipUnless(sys.platform.startswith("linux"), "formal installer is explicitly Linux-only")
class FormalProfile(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.repo, self.home = self.root / "repo", self.root / "fixture-home"
        self.home.mkdir(); self.repo.mkdir()
        for name in ["config/opencode/version", "config/opencode/opencode.json",
                     "config/opencode/agent/glm-review.md", "tools/glm_formal_profile.py",
                     "tools/glm_output_recovery.py", "bin/ai-glm", "bin/ai-review-packet"]:
            target = self.repo / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)
        version = (self.repo / "config/opencode/version").read_text().strip()
        binary = self.home / f".local/lib/ai-devops/opencode/{version}/node_modules/opencode-ai/bin/opencode.exe"
        binary.parent.mkdir(parents=True)
        binary.write_text("#!/bin/sh\nexit 99\n"); binary.chmod(0o700)
        self.general = self.home / ".config/ai-devops/opencode-xdg/opencode"
        self.general.mkdir(parents=True)
        (self.general / "AGENTS.md").write_bytes(b"Global reviewer authority unchanged.\n")
        self.general_unit = self.home / ".config/systemd/user/opencode-glm.service"
        self.general_unit.parent.mkdir(parents=True)
        self.general_unit.parent.chmod(0o700)
        self.general_unit.write_text("ORIGINAL GENERAL UNIT")
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            self.port = probe.getsockname()[1]

    def test_isolated_install_preserves_general_and_never_activates(self):
        result = profile.install(self.repo, self.home, self.port)
        p = profile.paths(self.home)
        self.assertFalse(result["activated"])
        self.assertEqual(self.general_unit.read_text(), "ORIGINAL GENERAL UNIT")
        self.assertEqual((p["config"] / "AGENTS.md").read_bytes(), (self.general / "AGENTS.md").read_bytes())
        self.assertEqual((p["config"] / "agent/glm-review.md").read_bytes(),
                         (self.repo / "config/opencode/agent/glm-review.md").read_bytes())
        self.assertFalse((p["config"] / "agent/glm-implement.md").exists())
        self.assertEqual(p["password"].stat().st_mode & 0o777, 0o600)
        settings = profile.private_read(p["settings"])
        self.assertIn(str(p["unit"]), profile.file_hashes(p, settings))

    def test_config_custom_tool_and_installed_source_mutation_refuse(self):
        profile.install(self.repo, self.home, self.port)
        p = profile.paths(self.home); settings = profile.private_read(p["settings"])
        (p["config"] / "plugins").mkdir()
        with self.assertRaises(ValueError): profile.file_hashes(p, settings)
        (p["config"] / "plugins").rmdir()
        (self.repo / "bin/ai-glm").write_text("changed source")
        with self.assertRaises(ValueError): profile.file_hashes(p, settings)

    def test_port_owner_and_shared_port_refuse_before_install(self):
        with self.assertRaises(ValueError): profile.install(self.repo, self.home, 4096)
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", self.port)); listener.listen()
            with self.assertRaises(OSError): profile.install(self.repo, self.home, self.port)
        self.assertFalse(profile.paths(self.home)["settings"].exists())

    def test_core_gitignore_is_sealed_and_drift_or_symlink_refuses(self):
        profile.install(self.repo, self.home, self.port)
        p = profile.paths(self.home); settings = profile.private_read(p["settings"])
        path = p["config"] / ".gitignore"
        expected = b"node_modules\npackage.json\npackage-lock.json\nbun.lock\n.gitignore"
        self.assertEqual(path.read_bytes(), expected)
        self.assertIn(str(path), settings["installed_hashes"])
        path.write_bytes(expected + b"\nextra")
        with self.assertRaises(ValueError): profile.file_hashes(p, settings)
        path.unlink(); path.symlink_to(self.general / "AGENTS.md")
        with self.assertRaises(ValueError): profile.file_hashes(p, settings)

    def test_global_instruction_mutation_and_registry_permissions_refuse(self):
        profile.install(self.repo, self.home, self.port)
        p = profile.paths(self.home); settings = profile.private_read(p["settings"])
        (self.general / "AGENTS.md").write_text("new global authority")
        with self.assertRaises(ValueError): profile.file_hashes(p, settings)
        p["settings"].chmod(0o644)
        with self.assertRaises(ValueError): profile.private_read(p["settings"])


if __name__ == "__main__":
    unittest.main()
