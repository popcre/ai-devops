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
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import unittest
from unittest import mock
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import glm_formal_profile as profile
import glm_output_recovery as recovery
original_readiness_owner = profile._readiness_owner


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
        for name in set(["config/opencode/version", "config/opencode/opencode.json",
                     "config/opencode/agent/glm-review.md", "tools/glm_formal_profile.py",
                     "tools/glm_output_recovery.py", "bin/ai-glm", "bin/ai-review-packet"]) | profile.CRITICAL_FILES:
            target = self.repo / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)
        subprocess.run(["git", "-C", str(self.repo), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.repo), "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                        "commit", "-qm", "invented runtime source"], check=True)
        self.release = subprocess.check_output(["git", "-C", str(self.repo), "rev-parse", "HEAD"], text=True).strip()
        self.installed = {"head": self.release, "manifest_sha256": "a" * 64}
        patch = mock.patch.object(profile, "installed_state", return_value=self.installed)
        patch.start(); self.addCleanup(patch.stop)
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

    def test_launch_uses_pinned_provider_credential_name_without_original_alias(self):
        profile.install(self.repo, self.home, self.port)
        previous_umask = os.umask(0o077)
        try:
            with mock.patch.dict(os.environ, {"ZAI_API_KEY": "public-invented-fixture-only",
                                              "ZHIPU_API_KEY": "wrong-inherited-fixture-only"}, clear=True), \
                 mock.patch.object(profile.os, "execve") as execute:
                profile.launch(self.home)
            environment = execute.call_args.args[2]
            self.assertEqual(environment["ZHIPU_API_KEY"], "public-invented-fixture-only")
            self.assertNotIn("ZAI_API_KEY", environment)
            self.assertEqual(environment["OPENCODE_DISABLE_PROJECT_CONFIG"], "true")
            profile.paths(self.home)["receipt"].unlink()
            with mock.patch.dict(os.environ, {"ZHIPU_API_KEY": "unadmitted-alias-only"}, clear=True), \
                 mock.patch.object(profile.os, "execve") as execute:
                with self.assertRaises(ValueError): profile.launch(self.home)
                execute.assert_not_called()
            self.assertFalse(profile.paths(self.home)["receipt"].exists())
        finally:
            os.umask(previous_umask)

    def readiness_fixture(self):
        """Invented custody only; no native/production origin is issued."""
        import reviewer_events
        profile.install(self.repo, self.home, self.port)
        p = profile.paths(self.home)
        settings = profile.private_read(p["settings"])
        now = int(time.time())
        origin = {"sha256": "f" * 64, "port": self.port, "pin": "1.18.12", "managed_directory": "invented"}
        repository = self.repo
        rid = hashlib.sha256((str(repository) + "\n").encode()).hexdigest()[:12]
        name, caller, run = "invented-readiness", "codex", "e" * 32
        metadata = p["state"] / "sessions" / rid / (caller + "--" + name + ".json")
        metadata.parent.mkdir(parents=True, mode=0o700)
        terminal = metadata.with_suffix(".terminal.json")
        native = {"finish": "stop", "id": "msg_new", "agent": "glm-review",
                  "model": {"id": "glm-5.3", "providerID": "zai-coding-plan"},
                  "content": [{"type": "text", "text": "REJECT fixture review"}]}
        profile.atomic(terminal, json.dumps(native).encode())
        packet = repository / ".ai/reviews/packets/fixture"
        packet.mkdir(parents=True)
        instruction = packet / "FORMAL-INSTRUCTIONS.txt"
        instruction.write_text("invented original instructions")
        (packet / "MANIFEST.sha256").write_text("c" * 64 + "\n")
        report = repository / ".ai/reviews/fixture-review.md"
        report.write_text("Fixture completed review: REJECT")
        turn = {"state": "completed-unpublished", "started_at": datetime.datetime.fromtimestamp(now-5, datetime.timezone.utc).isoformat(),
                "deadline_epoch": now+600, "previous_message_id": "msg_old", "original_invocation_id": run,
                "head": self.release, "base": self.release, "packet_sha256": "c"*64,
                "terminal_path": str(terminal), "terminal_sha256": profile.digest(terminal),
                "own_output_recovery": {"version": 1, "origin": origin, "instruction_asset": str(instruction),
                                        "instruction_sha256": profile.digest(instruction)}}
        meta = {"schema_version": 2, "type": "review", "name": name, "caller": caller,
                "repository_root": str(repository), "repository_id": rid, "provider": "zai-coding-plan",
                "model": "glm-5.3", "agent": "glm-review", "head": self.release,
                "opencode_session_id": "ses_fixture", "remote_turn": turn,
                "last_completed_turn": {**turn, "report": str(report), "report_sha256": profile.digest(report)}}
        profile.atomic(metadata, json.dumps(meta).encode())
        profile.atomic(p["receipt"], json.dumps({"credential_profile_scope": "sha256:"+"a"*64}).encode())
        events = self.home / ".local/state/ai-devops/reviewer-events"
        evidence = events / "evidence" / run / (("d"*64)+".report.json")
        evidence.parent.mkdir(parents=True)
        evidence.write_text('{"fixture_only":true}')
        original_run = subprocess.run
        def run_command(argv, **kwargs):
            if str(argv[0]).endswith("/bin/ai-review-packet"):
                return subprocess.CompletedProcess(argv, 0)
            return original_run(argv, **kwargs)
        patches = [mock.patch.object(profile, "origin", return_value=origin),
                   mock.patch.object(profile, "_readiness_owner"),
                   mock.patch.object(profile, "_native_completion", return_value=(origin, native)),
                   mock.patch.object(profile.subprocess, "run", side_effect=run_command),
                   mock.patch.object(reviewer_events, "location", return_value=events),
                   mock.patch.object(reviewer_events, "invocation", return_value={"caller": caller, "head": self.release, "repo": str(repository)}),
                   mock.patch.object(reviewer_events, "verify_reports", return_value=[run+"/"+"d"*64])]
        for patcher in patches:
            patcher.start(); self.addCleanup(patcher.stop)
        return p, settings, origin, now, metadata, meta, terminal, native, instruction, report, name, caller

    def test_fresh_native_reject_verdict_can_qualify_then_expiry_and_custody_deny(self):
        p, settings, origin, now, metadata, meta, terminal, native, instruction, report, name, caller = self.readiness_fixture()
        with mock.patch.object(profile.time, "time", return_value=now):
            profile.emit_readiness(self.home, self.repo, name, caller)
            first = p["readiness"].read_bytes()
            proof = profile.verify_readiness(self.home, settings, origin)
            self.assertEqual(proof["facts"]["terminal_id"], "msg_new")
            self.assertEqual(proof["expires_at"], now+300)
            with mock.patch.object(profile.time, "time", return_value=now+60):
                repeated = profile.emit_readiness(self.home, self.repo, name, caller)
                self.assertTrue(repeated["unchanged"])
                self.assertEqual(repeated["expires_at"], now+300)
                self.assertEqual(first, p["readiness"].read_bytes())
            # Normal metadata cleanup does not manufacture or refresh success.
            del meta["remote_turn"]; profile.atomic(metadata, json.dumps(meta).encode())
            self.assertEqual(profile.verify_readiness(self.home, settings, origin), proof)
            with self.assertRaises(ValueError): profile.emit_readiness(self.home, self.repo, name, caller)
            self.assertEqual(first, p["readiness"].read_bytes())
        with mock.patch.object(profile.time, "time", return_value=now+301):
            with self.assertRaises(ValueError): profile.verify_readiness(self.home, settings, origin)
        with mock.patch.object(profile.time, "time", return_value=now):
            report.write_text("changed published report")
            with self.assertRaises(ValueError): profile.verify_readiness(self.home, settings, origin)

    def test_readiness_native_identity_and_intermediate_refusals(self):
        fixture = self.readiness_fixture()
        p, settings, origin, now, metadata, meta, terminal, native, instruction, report, name, caller = fixture
        for key, value in [("finish", "error"), ("id", "msg_old"),
                           ("agent", "implement"), ("error", {"type":"auth"}),
                           ("model", {"id":"wrong", "providerID":"zai-coding-plan"})]:
            changed = {**native, key:value}; profile.atomic(terminal, json.dumps(changed).encode())
            candidate = copy.deepcopy(meta)
            candidate["remote_turn"]["terminal_sha256"] = profile.digest(terminal)
            candidate["last_completed_turn"]["terminal_sha256"] = profile.digest(terminal)
            profile.atomic(metadata, json.dumps(candidate).encode())
            with self.subTest(key=key), self.assertRaises(ValueError):
                profile._readiness_evidence(self.home, self.repo, name, caller, now=now)
        profile.atomic(terminal, json.dumps(native).encode())
        for phase in ["mirrored", "reserved", "intermediate-retained", "submitting"]:
            candidate = copy.deepcopy(meta)
            candidate["remote_turn"]["own_output_state"] = {"phase":phase}
            candidate["last_completed_turn"]["own_output_state"] = {"phase":phase}
            profile.atomic(metadata, json.dumps(candidate).encode())
            with self.subTest(phase=phase), self.assertRaises(ValueError):
                profile._readiness_evidence(self.home, self.repo, name, caller, now=now)
        profile.atomic(metadata, json.dumps(meta).encode())
        for observed in [{**native, "id":"msg_foreign"}, {"id":"msg_user", "content":[]}, {**native, "finish":"error"}]:
            with mock.patch.object(profile, "_native_completion", return_value=(origin, observed)), self.assertRaises(ValueError):
                profile._readiness_evidence(self.home, self.repo, name, caller, now=now)
        with self.assertRaises(ValueError): profile._readiness_evidence(self.home, self.repo, name, caller, now=now+601)
        with self.assertRaises(ValueError): profile._readiness_evidence(self.home, self.repo, "../forged", caller, now=now)
        instruction.write_text("changed instruction bytes")
        with self.assertRaises(ValueError): profile._readiness_evidence(self.home, self.repo, name, caller, now=now)

    def test_readiness_wrong_custody_scope_replay_or_forged_publisher_denied(self):
        import reviewer_events
        p, settings, origin, now, metadata, meta, terminal, native, instruction, report, name, caller = self.readiness_fixture()
        # The real parent is the unit-test runner, never an approved publisher.
        with mock.patch.object(profile, "_readiness_owner", wraps=original_readiness_owner):
            with self.assertRaises(ValueError): profile.emit_readiness(self.home, self.repo, name, caller)
        for field, value in [("type", "implementation"), ("caller", "foreign"),
                             ("provider", "fixture"), ("head", "0"*40),
                             ("repository_id", "forged"), ("quota_result", {"credential_profile_scope":"sha256:"+"b"*64})]:
            candidate = {**meta, field:value}; profile.atomic(metadata, json.dumps(candidate).encode())
            with self.subTest(field=field), self.assertRaises(ValueError):
                profile._readiness_evidence(self.home, self.repo, name, caller, now=now)
        profile.atomic(metadata, json.dumps(meta).encode())
        with mock.patch.object(reviewer_events, "verify_reports", return_value=[]):
            with self.assertRaises(ValueError): profile.emit_readiness(self.home, self.repo, name, caller)
        profile.atomic(p["receipt"], json.dumps({"credential_profile_scope":"sha256:"+"b"*64}).encode())
        changed = copy.deepcopy(meta)
        changed["quota_result"]={"credential_profile_scope":"sha256:"+"a"*64}
        profile.atomic(metadata, json.dumps(changed).encode())
        with self.assertRaises(ValueError): profile.emit_readiness(self.home, self.repo, name, caller)
        self.assertFalse(p["readiness"].exists())

    def test_native_lookup_is_exact_own_supported_endpoint(self):
        with mock.patch.object(profile, "_profile_get", return_value=({"origin":"invented"}, {"data":[{"id":"msg_new"}]})) as get:
            self.assertEqual(profile._native_completion(self.home, "ses_own"), ({"origin":"invented"},{"id":"msg_new"}))
            get.assert_called_once_with(self.home, "/api/session/ses_own/message?limit=1", 8*1024**2)
            with self.assertRaises(ValueError): profile._native_completion(self.home, "ses_own/../foreign")
            self.assertEqual(get.call_count,1)
        with mock.patch.object(profile, "_profile_get", return_value=({}, {"data":[{},{}]})):
            with self.assertRaises(ValueError): profile._native_completion(self.home, "ses_own")

    def test_readiness_json_is_private_stable_and_strict(self):
        target = self.root / "completion.json"
        profile.atomic(target, b'{"id":1,"id":2}')
        with self.assertRaises(ValueError): profile._readiness_json(target)
        profile.atomic(target, b'{"id":NaN}')
        with self.assertRaises(ValueError): profile._readiness_json(target)
        profile.atomic(target, b'{}'); target.chmod(0o644)
        with self.assertRaises(ValueError): profile._readiness_json(target)
        target.chmod(0o600)
        linked = self.root / "linked"; os.link(target, linked)
        with self.assertRaises(ValueError): profile._readiness_json(target)
        linked.unlink(); target.unlink(); target.symlink_to(self.root/"missing")
        with self.assertRaises(OSError): profile._readiness_json(target)

    def test_installer_activation_health_without_provider_success_refused(self):
        profile.install(self.repo, self.home, self.port)
        with mock.patch.object(profile, "installer_owner"), mock.patch.object(profile, "profile_health", return_value={}):
            with self.assertRaises(FileNotFoundError): profile.activate(self.repo, self.home)
        self.assertFalse(profile.paths(self.home)["activation"].exists())

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

    def test_config_custom_tool_refuses_and_canonical_changes_do_not_mutate_runtime(self):
        profile.install(self.repo, self.home, self.port)
        p = profile.paths(self.home); settings = profile.private_read(p["settings"])
        (p["config"] / "plugins").mkdir()
        with self.assertRaises(ValueError): profile.file_hashes(p, settings)
        (p["config"] / "plugins").rmdir()
        (self.repo / "bin/ai-glm").write_text("changed source")
        profile.file_hashes(p, settings)
        self.assertNotEqual(Path(settings["repo"]), self.repo)
        self.assertNotEqual((Path(settings["repo"]) / "bin/ai-glm").read_text(), "changed source")
        (Path(settings["repo"]) / "bin/ai-glm").write_text("changed immutable snapshot")
        with self.assertRaises(ValueError): profile.file_hashes(p, settings)

    def test_absent_activation_preserves_general_and_invalid_never_falls_back(self):
        self.assertEqual(profile.route(self.home), {"profile": "general"})
        profile.install(self.repo, self.home, self.port)
        p = profile.paths(self.home)
        profile.atomic(p["activation"], b'{"version":1}')
        with self.assertRaises(ValueError): profile.route(self.home)
        before = (p["config"] / "opencode.json").read_bytes()
        with self.assertRaises(ValueError): profile.install(self.repo, self.home, self.port)
        self.assertEqual(before, (p["config"] / "opencode.json").read_bytes())

    def test_protected_activation_ready_pins_and_drift(self):
        profile.install(self.repo, self.home, self.port)
        p = profile.paths(self.home)
        ready = {"sha256": "f" * 64, "port": self.port, "pin": "1.18.12", "managed_directory": "invented-only"}
        with mock.patch.object(profile, "installer_owner") as issuer, \
             mock.patch.object(profile, "profile_health", return_value=ready), \
             mock.patch.object(profile, "verify_readiness", return_value={"fixture_only": True}), \
             mock.patch.object(profile, "origin", return_value=ready):
            self.assertTrue(profile.activate(self.repo, self.home)["activated"])
            issuer.assert_called_once()
            routed = profile.route(self.home)
            settings = profile.private_read(p["settings"])
            self.assertEqual(routed, {"profile": "formal-review", "runner": str(Path(settings["repo"]) / "bin/ai-glm")})
            self.assertEqual(p["activation"].stat().st_mode & 0o777, 0o600)
            before = p["settings"].stat().st_mtime_ns
            self.assertTrue(profile.install(self.repo, self.home, self.port)["unchanged"])
            self.assertEqual(p["settings"].stat().st_mtime_ns, before)
            with mock.patch.object(profile, "origin", return_value={**ready, "sha256": "0" * 64}):
                with self.assertRaises(ValueError): profile.route(self.home)
            with mock.patch.object(profile, "installed_state", return_value={**self.installed, "head": "0" * 40}):
                with self.assertRaises(ValueError): profile.route(self.home)
            (self.repo / "bin/ai-glm").write_text("canonical changed")
            with self.assertRaises(ValueError): profile.route(self.home)
            profile.file_hashes(p, settings)  # In-flight pinned origin remains intact.

    def test_activation_cannot_be_issued_by_environment_or_unprotected_caller(self):
        profile.install(self.repo, self.home, self.port)
        with self.assertRaises((ValueError, OSError)):
            profile.activate(self.repo, self.home)
        self.assertFalse(profile.paths(self.home)["activation"].exists())

    def test_loopback_health_without_proxy_or_production_origin_and_unsafe_credential_denial(self):
        profile.install(self.repo, self.home, self.port)
        class Health(BaseHTTPRequestHandler):
            calls = 0
            def do_GET(self):
                Health.calls += 1
                self.send_response(200); self.end_headers(); self.wfile.write(b'{"healthy":true}')
            def log_message(self, *args): pass
        server = ThreadingHTTPServer(("127.0.0.1", 0), Health)
        thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
        try:
            ready = {"port": server.server_port, "fixture": "not-a-production-origin"}
            with mock.patch.object(profile, "origin", return_value=ready), \
                 mock.patch.dict(os.environ, {"HTTP_PROXY": "http://127.0.0.1:1", "http_proxy": "http://127.0.0.1:1"}):
                self.assertEqual(profile.profile_health(self.home), ready)
                self.assertEqual(Health.calls, 1)
                password = profile.paths(self.home)["password"]
                password.unlink(); password.symlink_to(self.general / "AGENTS.md")
                with self.assertRaises((ValueError, OSError)): profile.profile_health(self.home)
                self.assertEqual(Health.calls, 1)
        finally:
            server.shutdown(); server.server_close(); thread.join(timeout=1)

    def test_unrelated_forward_release_preserves_code_pin_and_critical_change_denies(self):
        profile.install(self.repo, self.home, self.port)
        ready = {"sha256": "f" * 64, "port": self.port, "pin": "1.18.12", "managed_directory": "invented-only"}
        with mock.patch.object(profile, "installer_owner"), mock.patch.object(profile, "profile_health", return_value=ready), \
             mock.patch.object(profile, "verify_readiness", return_value={"fixture_only": True}), \
             mock.patch.object(profile, "origin", return_value=ready):
            profile.activate(self.repo, self.home)
            (self.repo / "README.md").write_text("unrelated public documentation")
            subprocess.run(["git", "-C", str(self.repo), "add", "README.md"], check=True)
            subprocess.run(["git", "-C", str(self.repo), "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                            "commit", "-qm", "unrelated docs"], check=True)
            head = subprocess.check_output(["git", "-C", str(self.repo), "rev-parse", "HEAD"], text=True).strip()
            with mock.patch.object(profile, "installed_state", return_value={"head": head, "manifest_sha256": "b" * 64}):
                self.assertEqual(profile.route(self.home)["profile"], "formal-review")
                (self.repo / "bin/ai-glm").write_text("critical code changed")
                with self.assertRaises(ValueError): profile.route(self.home)

    def test_upgrade_preflight_allows_unrelated_provider_and_denies_glm_safety_before_advance(self):
        profile.install(self.repo, self.home, self.port)
        ready = {"sha256": "f" * 64, "port": self.port, "pin": "1.18.12", "managed_directory": "invented-only"}
        with mock.patch.object(profile, "installer_owner"), mock.patch.object(profile, "profile_health", return_value=ready), \
             mock.patch.object(profile, "verify_readiness", return_value={"fixture_only": True}), \
             mock.patch.object(profile, "origin", return_value=ready):
            profile.activate(self.repo, self.home)
            for name in ["bin/ai-muse", "bin/ai-glm"]:
                (self.repo / name).write_text("changed provider implementation")
                subprocess.run(["git", "-C", str(self.repo), "add", name], check=True)
                subprocess.run(["git", "-C", str(self.repo), "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                                "commit", "-qm", name], check=True)
                target = subprocess.check_output(["git", "-C", str(self.repo), "rev-parse", "HEAD"], text=True).strip()
                subprocess.run(["git", "-C", str(self.repo), "checkout", "-q", "--detach", self.release], check=True)
                if name == "bin/ai-muse":
                    self.assertTrue(profile.upgrade_check(self.repo, self.home, target)["upgrade_allowed"])
                else:
                    with self.assertRaises(ValueError): profile.upgrade_check(self.repo, self.home, target)
                self.assertEqual(subprocess.check_output(["git", "-C", str(self.repo), "rev-parse", "HEAD"], text=True).strip(), self.release)
                self.assertEqual(self.general_unit.read_text(), "ORIGINAL GENERAL UNIT")

    def test_snapshot_contains_only_complete_committed_release(self):
        (self.repo / "untracked-private.txt").write_text("invented private overlay")
        profile.install(self.repo, self.home, self.port)
        settings = profile.private_read(profile.paths(self.home)["settings"])
        runtime = Path(settings["repo"])
        self.assertFalse((runtime / "untracked-private.txt").exists())
        self.assertEqual(profile.runtime_hashes(runtime)["source_sha"], self.release)

    def test_actual_complete_release_snapshot_has_all_dependencies_and_no_git(self):
        head = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
        runtime = profile.release_snapshot(ROOT, self.home, head)
        manifest = profile.runtime_hashes(runtime)
        expected = {row.split(b"\t", 1)[1].decode() for row in subprocess.check_output(
            ["git", "-C", str(ROOT), "ls-tree", "-r", "-z", head]).split(b"\0")
                    if row and row.split(b"\t", 1)[0].split()[1] == b"blob"}
        self.assertEqual(set(manifest["files"]), expected)
        self.assertFalse((runtime / ".git").exists())
        self.assertFalse((runtime / "transcripts").exists())
        self.assertEqual(set(manifest["excluded_gitlinks"]), {"transcripts"})
        for name in ["bin/ai-glm", "bin/ai-review-packet", "bin/ai-review-sandbox", "tools/reviewer_events.py",
                     "tools/lib/provider-wrapper-common.sh", "tools/lib/opencode-maintenance-lock.sh"]:
            self.assertIn(name, manifest["files"])

    def test_runtime_permissions_wrong_head_and_self_consistent_forged_cache_refuse(self):
        profile.install(self.repo, self.home, self.port)
        p = profile.paths(self.home); settings = profile.private_read(p["settings"])
        runtime = Path(settings["repo"]); runner = runtime / "bin/ai-glm"
        runner.chmod(0o600)
        with self.assertRaises(ValueError): profile.runtime_hashes(runtime)
        runner.chmod(0o700)
        manifest = profile.private_read(runtime / ".formal-runtime.json")
        bad = {**manifest, "source_sha": "0" * 40}
        profile.atomic(runtime / ".formal-runtime.json", json.dumps(bad).encode())
        with self.assertRaises(ValueError): profile.runtime_hashes(runtime)
        runner.write_text("forged immutable code")
        manifest["files"]["bin/ai-glm"] = hashlib.sha256(runner.read_bytes()).hexdigest()
        manifest["critical"]["bin/ai-glm"] = manifest["files"]["bin/ai-glm"]
        profile.atomic(runtime / ".formal-runtime.json", json.dumps(manifest).encode())
        with self.assertRaises(ValueError): profile.file_hashes(p, settings)
        with self.assertRaises(ValueError): profile.release_snapshot(self.repo, self.home, self.release)

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
