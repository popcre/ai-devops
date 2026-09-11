"""Synthetic maintenance contract tests, run by test-ai-reviewer-issue.sh."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import concurrent.futures
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("maintenance", ROOT / "tools/reviewer_maintenance.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
sys.path.insert(0, str(ROOT / "tools"))
import reviewer_events as events


class MaintenanceCases(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.shared = tempfile.TemporaryDirectory()
        cls.toolkit = Path(cls.shared.name)
        for args in (["init", "-q"], ["config", "user.name", "Test"], ["config", "user.email", "test@example.com"]):
            subprocess.run(["git", "-C", str(cls.toolkit), *args], check=True, capture_output=True)
        (cls.toolkit / "proof.txt").write_text("Synthetic tests, review, install and live fixture evidence.\n")
        subprocess.run(["git", "-C", str(cls.toolkit), "add", "proof.txt"], check=True, capture_output=True)
        subprocess.run(["git", "-C", str(cls.toolkit), "commit", "-qm", "fixture"], check=True, capture_output=True)
        cls.sha = subprocess.check_output(["git", "-C", str(cls.toolkit), "rev-parse", "HEAD"], text=True).strip()
        subprocess.run(["git", "-C", str(cls.toolkit), "update-ref", "refs/remotes/origin/main", cls.sha], check=True)
        (cls.toolkit / "tools").mkdir()
        (cls.toolkit / "bin").mkdir()
        for name in ("reviewer_event_guard.sh", "reviewer_events.py", "reviewer_maintenance.py"):
            shutil.copyfile(ROOT / "tools" / name, cls.toolkit / "tools" / name)
        shutil.copyfile(ROOT / "bin/ai-reviewer-issue", cls.toolkit / "bin/ai-reviewer-issue")
        cls.wrapper = cls.toolkit / "bin/event-fixture"
        cls.wrapper.write_text('''#!/usr/bin/env bash
set -euo pipefail
self="$(readlink -f "${BASH_SOURCE[0]}")"
source "$(dirname "$self")/../tools/reviewer_event_guard.sh"
reviewer_event_guard "$1" "$self" "$@"
shift
case "$1" in
  stream) cat; printf 'synthetic stderr\\n' >&2; exit 7;;
  ok) exit 0;;
  secret-env) [ -n "${PROVIDER_TEST_SECRET:-}" ]; exit 4;;
  signal) trap 'exit 44' TERM INT; printf '%s\\n' "$$" > "$SIGNAL_READY"; while true; do sleep 0.1; done;;
esac
''')
        cls.bash = os.environ.get("AI_REVIEWER_BASH") or shutil.which("bash")
        if os.name == "nt" and not os.environ.get("AI_REVIEWER_BASH"):
            cls.bash = str(Path(shutil.which("git")).parents[1] / "bin/bash.exe")
        elif os.name == "nt":
            cls.bash = str(m.physical(cls.bash))

    @classmethod
    def tearDownClass(cls):
        cls.shared.cleanup()

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.ledger = self.root / "events.jsonl"
        self.config = {"providers": ["grok", "kimi"], "sources": [
            {"root": str(self.root), "file": "events.jsonl", "kind": "jsonl", "adapter": "invocations"}], "blockers": []}
        self.engine = m.Maintenance(self.toolkit, self.root / "issues", self.config)
        self.proof = self.root / "completion-proof.json"
        self.proof.write_text(json.dumps({"repair_commit": self.sha, **{k: "proof.txt" for k in
                              ("tests", "independent_review", "installation", "live", "legacy_audit")}}))

    def write(self, event):
        with self.ledger.open("ab") as output:
            output.write(json.dumps(event).encode() + b"\n")

    def invocation(self, rid="run-1", code=1, provider="grok", finish=True):
        row = {"schema_version": 1, "provider": provider, "event": "started", "run_id": rid,
               "repo": str(self.toolkit), "head": self.sha, "caller": "codex", "timestamp": "same-time"}
        self.write(row)
        if finish:
            self.write({**row, "event": "finished", "exit_code": code})
        return row

    def nondefect(self, record, reason="expected-refusal"):
        for c in record["candidates"]:
            self.engine.outcome(record["id"], c["id"], reason=reason, evidence="proof.txt")

    def complete(self, record):
        return self.engine.complete(record["id"], self.proof)

    def issue(self, candidate, status=None):
        issue_id = "synthetic-issue"
        directory = self.engine.issues / issue_id
        directory.mkdir(parents=True)
        (directory / "issue.json").write_text(json.dumps({"schema_version": 3, "id": issue_id, "provider": "grok",
            "join": {"run_id": "run-1", "caller": "codex"}, "repository": {"root": str(self.toolkit), "head": self.sha}}))
        if status:
            (directory / "resolutions").mkdir()
            (directory / "resolutions/1.json").write_text(json.dumps({"schema_version": 1, "status": status,
                "repair_commits": [self.sha], "evidence": ["proof.txt"]}))
        return issue_id

    def test_first_and_empty_round(self):
        record = self.engine.start()
        self.assertIsNone(record["parent"])
        self.assertEqual(record["candidates"], [])
        self.assertEqual(self.complete(record)["status"], "completed")

    def test_resume_is_explicit_and_immutable(self):
        record = self.engine.start()
        with self.assertRaises(m.Blocked):
            self.engine.start()
        self.assertEqual(self.engine.start(record["id"]), record)

    def test_exact_boundary_equal_timestamps_and_late_append(self):
        self.invocation()
        first = self.engine.start()
        self.invocation("run-2")
        self.assertEqual(len(first["candidates"]), 1)
        self.nondefect(first)
        self.complete(first)
        second = self.engine.start()
        self.assertEqual(len(second["candidates"]), 1)
        self.assertNotEqual(first["candidates"][0]["id"], second["candidates"][0]["id"])
        source = str(m.physical(self.ledger))
        self.assertEqual(second["sources"][source]["lower"], first["sources"][source]["upper"])

    def test_success_is_not_a_failure(self):
        self.invocation(code=0)
        self.assertFalse(self.engine.start()["candidates"])

    def test_partial_line_can_be_completed_before_retry(self):
        self.ledger.write_bytes(b'{"schema_version":1')
        with self.assertRaisesRegex(m.Blocked, "unterminated"):
            self.engine.start()
        self.ledger.write_bytes(b"")
        self.invocation()
        self.assertEqual(len(self.engine.start()["candidates"]), 1)

    def test_invalid_json_cannot_publish_start(self):
        self.ledger.write_bytes(b"{bad}\n")
        with self.assertRaisesRegex(m.Blocked, "invalid invocation"):
            self.engine.start()
        self.assertFalse(list(self.engine.directory.glob("*.started.json")))

    def test_unknown_source_shape_cannot_publish_start(self):
        self.write({"schema_version": 99})
        with self.assertRaises(m.Blocked):
            self.engine.start()

    def test_replacement_blocks_even_identical_bytes(self):
        self.invocation()
        record = self.engine.start()
        data = self.ledger.read_bytes()
        self.ledger.rename(self.root / "old.jsonl")
        self.ledger.write_bytes(data)
        with self.assertRaisesRegex(m.Blocked, "replaced|rotated"):
            self.complete(record)

    def test_truncation_blocks(self):
        self.invocation()
        record = self.engine.start()
        self.ledger.write_bytes(b"")
        with self.assertRaisesRegex(m.Blocked, "truncated"):
            self.complete(record)

    def test_disappearance_blocks(self):
        self.invocation()
        record = self.engine.start()
        self.ledger.unlink()
        with self.assertRaisesRegex(m.Blocked, "disappeared"):
            self.complete(record)

    def test_digest_mismatch_blocks_same_size_rewrite(self):
        self.invocation()
        record = self.engine.start()
        self.ledger.write_bytes(self.ledger.read_bytes().replace(b"same-time", b"evil-time"))
        with self.assertRaisesRegex(m.Blocked, "continuity"):
            self.complete(record)

    def test_unreadable_source_blocks(self):
        self.ledger.write_bytes(b"")
        self.ledger.chmod(0)
        self.addCleanup(self.ledger.chmod, 0o600)
        if os.name == "nt":
            self.skipTest("POSIX mode-bit denial; Windows access is governed by ACLs")
        with self.assertRaisesRegex(m.Blocked, "unreadable"):
            self.engine.start()

    def symlink(self, source, target, directory=False):
        try:
            source.symlink_to(target, target_is_directory=directory)
        except OSError:
            self.skipTest("native symlink permission unavailable")

    def test_linked_source_refused(self):
        outside = self.root / "outside"
        outside.write_bytes(b"")
        self.symlink(self.ledger, outside)
        with self.assertRaisesRegex(m.Blocked, "linked path"):
            self.engine.start()

    def test_linked_checkpoint_destination_refused(self):
        outside = self.root / "outside"
        outside.mkdir()
        self.engine.issues.mkdir()
        self.symlink(self.engine.directory, outside, True)
        with self.assertRaisesRegex(m.Blocked, "linked path"):
            self.engine.start()
        self.assertFalse(list(outside.iterdir()))

    def test_candidate_ids_deterministic(self):
        self.invocation()
        first = self.engine.start()
        another = m.Maintenance(self.toolkit, self.root / "other-issues", self.config).start()
        self.assertEqual(first["candidates"], another["candidates"])

    def test_duplicate_event_refused_instead_of_choosing_one(self):
        row = self.invocation()
        self.write(row)
        with self.assertRaisesRegex(m.Blocked, "duplicate"):
            self.engine.start()

    def test_every_candidate_needs_classification(self):
        self.invocation()
        record = self.engine.start()
        with self.assertRaisesRegex(m.Blocked, "unclassified"):
            self.complete(record)
        self.assertIsNone(self.engine.show()["last_completed"])

    def test_unknown_nondefect_reason_refused(self):
        self.invocation()
        record = self.engine.start()
        with self.assertRaises(m.Blocked):
            self.nondefect(record, "ignore")

    def test_nondefect_requires_evidence(self):
        self.invocation()
        record = self.engine.start()
        with self.assertRaises(m.Blocked):
            self.engine.outcome(record["id"], record["candidates"][0]["id"], reason="expected-refusal")

    def test_conflicting_outcome_refused(self):
        self.invocation()
        record = self.engine.start()
        self.nondefect(record)
        self.nondefect(record)
        with self.assertRaisesRegex(m.Blocked, "conflicting"):
            self.nondefect(record, "quota-exhaustion")

    def test_open_incident_blocks_checkpoint(self):
        self.invocation()
        record = self.engine.start()
        cid = record["candidates"][0]["id"]
        iid = self.issue(record["candidates"][0])
        self.engine.outcome(record["id"], cid, issue_id=iid)
        with self.assertRaisesRegex(m.Blocked, "remains open"):
            self.complete(record)

    def test_exact_join_and_resolved_incident_remain_in_place(self):
        self.invocation()
        record = self.engine.start()
        iid = self.issue(record["candidates"][0], "resolved")
        original = (self.engine.issues / iid / "issue.json").read_bytes()
        self.engine.outcome(record["id"], record["candidates"][0]["id"], issue_id=iid)
        self.complete(record)
        self.assertEqual(original, (self.engine.issues / iid / "issue.json").read_bytes())

    def test_wrong_provider_and_exact_join_refused(self):
        self.invocation()
        record = self.engine.start()
        candidate = record["candidates"][0]
        iid = self.issue(candidate)
        path = self.engine.issues / iid / "issue.json"
        original = json.loads(path.read_text())
        for changed in ({**original, "provider": "kimi"}, {**original, "join": {"run_id": "nearby"}}):
            path.write_text(json.dumps(changed))
            with self.assertRaises(m.Blocked):
                self.engine.outcome(record["id"], candidate["id"], issue_id=iid)

    def test_partial_requires_explicit_carry_forward(self):
        self.invocation()
        record = self.engine.start()
        iid = self.issue(record["candidates"][0], "partially-resolved")
        self.engine.outcome(record["id"], record["candidates"][0]["id"], issue_id=iid)
        with self.assertRaisesRegex(m.Blocked, "carry-forward"):
            self.complete(record)

    def test_partial_carried_into_next_round(self):
        self.invocation()
        record = self.engine.start()
        iid = self.issue(record["candidates"][0], "partially-resolved")
        self.engine.outcome(record["id"], record["candidates"][0]["id"], issue_id=iid,
                            carry="proof.txt", evidence="proof.txt")
        self.complete(record)
        self.assertEqual(self.engine.start()["candidates"], record["candidates"])

    def test_ongoing_call_is_carried_until_terminal_event(self):
        row = self.invocation(finish=False)
        record = self.engine.start()
        self.nondefect(record, "in-progress")
        self.complete(record)
        second = self.engine.start()
        self.assertEqual(len(second["candidates"]), 1)
        self.nondefect(second, "in-progress")
        self.complete(second)
        self.write({**row, "event": "finished", "exit_code": 0})
        self.assertFalse(self.engine.start()["candidates"])

    def test_atomic_write_failure_preserves_previous_boundary(self):
        first = self.engine.start()
        self.complete(first)
        second = self.engine.start()
        with patch.object(m.os, "link", side_effect=OSError("synthetic disk failure")):
            with self.assertRaises(OSError):
                self.complete(second)
        self.assertEqual(self.engine.show()["last_completed"], first["id"])
        self.assertEqual(self.engine.show()["active_round"], second["id"])

    def test_repeated_completion_is_idempotent(self):
        record = self.engine.start()
        self.assertEqual(self.complete(record), self.complete(record))
        self.assertEqual(len(list(self.engine.directory.glob("*.completed.json"))), 1)

    def test_missing_or_unmerged_completion_proof_refused(self):
        record = self.engine.start()
        self.proof.write_text(json.dumps({"repair_commit": self.sha}))
        with self.assertRaises(m.Blocked):
            self.complete(record)

    def test_corrupt_resolution_commit_refused(self):
        self.invocation()
        record = self.engine.start()
        iid = self.issue(record["candidates"][0], "resolved")
        path = self.engine.issues / iid / "resolutions/1.json"
        resolution = json.loads(path.read_text())
        resolution["repair_commits"] = ["0" * 40]
        path.write_text(json.dumps(resolution))
        self.engine.outcome(record["id"], record["candidates"][0]["id"], issue_id=iid)
        with self.assertRaises(m.Blocked):
            self.complete(record)

    def test_schema_rejects_missing_boundaries_and_duplicate_outcomes(self):
        record = self.engine.start()
        m.validate_round(record)
        for field in ("sources", "candidates", "configuration_sha256", "blockers"):
            bad = copy.deepcopy(record)
            del bad[field]
            with self.assertRaises(m.Blocked):
                m.validate_round(bad)
        bad = {**record, "status": "completed"}
        with self.assertRaises(m.Blocked):
            m.validate_round(bad)

    def test_writer_contention_is_visible(self):
        with m.locked(self.engine.directory):
            with self.assertRaisesRegex(m.Blocked, "busy"):
                self.engine.start()

    def test_concurrent_starters_publish_exactly_one_round(self):
        def start(_):
            try:
                return self.engine.start()
            except m.Blocked:
                return None
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as workers:
            results = list(workers.map(start, range(3)))
        self.assertEqual(sum(r is not None for r in results), 1)
        self.assertEqual(len(list(self.engine.directory.glob("*.started.json"))), 1)

    def test_concurrent_completers_publish_once(self):
        record = self.engine.start()
        def complete(_):
            try:
                return self.complete(record)
            except m.Blocked:
                return None
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as workers:
            results = list(workers.map(complete, range(3)))
        self.assertTrue(any(r is not None for r in results))
        self.assertEqual(len(list(self.engine.directory.glob("*.completed.json"))), 1)

    def test_existing_open_incident_cannot_be_skipped_at_first_boundary(self):
        iid = self.issue({}, None)
        record = self.engine.start()
        self.assertEqual(record["candidates"][0]["existing_issue_id"], iid)
        with self.assertRaises(m.Blocked):
            self.nondefect(record)
        self.engine.outcome(record["id"], record["candidates"][0]["id"], issue_id=iid)
        with self.assertRaisesRegex(m.Blocked, "remains open"):
            self.complete(record)

    def test_carry_can_be_appended_after_incident_link(self):
        self.invocation()
        record = self.engine.start()
        candidate = record["candidates"][0]
        iid = self.issue(candidate, "partially-resolved")
        self.engine.outcome(record["id"], candidate["id"], issue_id=iid)
        self.engine.carry(record["id"], candidate["id"], "proof.txt", "proof.txt")
        self.complete(record)
        self.assertEqual(self.engine.start()["candidates"], record["candidates"])

    def test_first_completion_requires_legacy_audit(self):
        record = self.engine.start()
        proof = json.loads(self.proof.read_text())
        del proof["legacy_audit"]
        self.proof.write_text(json.dumps(proof))
        with self.assertRaises(m.Blocked):
            self.complete(record)

    def test_show_reports_all_unclassified_candidates(self):
        self.invocation("run-1")
        self.invocation("run-2")
        self.engine.start()
        report = self.engine.show()
        self.assertEqual(report["counts"]["unclassified"], 2)
        self.assertEqual(len(report["blockers"]), 2)

    def test_changed_classification_evidence_blocks(self):
        self.invocation()
        record = self.engine.start()
        evidence = self.root / "evidence.txt"
        evidence.write_text("Original observation")
        self.engine.outcome(record["id"], record["candidates"][0]["id"], reason="expected-refusal", evidence=str(evidence))
        evidence.write_text("Changed observation")
        with self.assertRaisesRegex(m.Blocked, "evidence changed"):
            self.complete(record)

    def test_scoreboard_crosscheck_and_duplicate_suppression(self):
        self.config["sources"][0].pop("adapter")
        self.engine = m.Maintenance(self.toolkit, self.root / "issues", self.config)
        row = {"schema_version": 2, "provider": "grok", "verdict": "BLOCKED", "failure_class": "empty-report",
               "repo": str(self.toolkit), "head": self.sha, "run_id": "run-1", "caller": "codex"}
        self.write(row)
        self.write(row)
        self.assertEqual(len(self.engine.start()["candidates"]), 1)

    def test_missing_boundary_schema_is_refused(self):
        record = self.engine.start()
        del record["sources"][str(m.physical(self.ledger))]["upper"]
        with self.assertRaises(m.Blocked):
            m.validate_round(record)

    def test_unsupported_provider_blocks_completion(self):
        self.config["blockers"] = ["unsupported source: future-provider"]
        self.engine = m.Maintenance(self.toolkit, self.root / "issues", self.config)
        record = self.engine.start()
        with self.assertRaisesRegex(m.Blocked, "unsupported"):
            self.complete(record)

    def test_private_fields_are_not_copied(self):
        row = self.invocation(finish=False)
        self.write({**row, "event": "finished", "exit_code": 1, "prompt": "DO_NOT_COPY",
                    "credential": "DO_NOT_COPY", "command": "DO_NOT_COPY"})
        record = self.engine.start()
        self.assertNotIn("DO_NOT_COPY", json.dumps(record))
        self.assertNotIn("DO_NOT_COPY", json.dumps(self.engine.show()))

    def guard(self, provider="grok", operation="ok", **kwargs):
        env = {**os.environ, "AI_REVIEW_EVENT_DIR": str(self.root), "AI_GROK_CALLER": "codex"}
        env.update(kwargs.pop("env", {}))
        return subprocess.run([self.bash, str(self.wrapper), provider, operation], env=env,
                              cwd=self.toolkit, capture_output=True, text=True, timeout=30, **kwargs)

    def test_explicit_home_or_state_does_not_require_windows_profile_discovery(self):
        for setting, base in (({"HOME": str(self.root)}, self.root / ".local/state/ai-devops"),
                              ({"AI_REVIEWER_STATE_BASE": str(self.root)}, self.root)):
            with self.subTest(setting=setting), patch.dict(os.environ, setting, clear=True), \
                    patch.object(Path, "home", side_effect=RuntimeError("No Windows profile")):
                expected = m.physical(base / "reviewer-events")
                self.assertEqual(events.location(), expected)
                self.assertEqual(m.configuration(ROOT)["sources"][0]["root"], str(expected))
        with patch.dict(os.environ, {"AI_REVIEW_EVENT_DIR": str(self.root)}, clear=True), \
                patch.object(Path, "home", side_effect=RuntimeError("No Windows profile")):
            self.assertEqual(events.location(), m.physical(self.root))

    def test_maintenance_configuration_retains_inactive_known_providers(self):
        registry_path = ROOT / "config/reviewer-registry.json"
        registry = json.loads(registry_path.read_text())
        expected = sorted(registry["providers"])
        original = m.configuration(ROOT)
        self.assertEqual(original["providers"], expected)
        changed = copy.deepcopy(registry)
        for provider in changed["providers"].values():
            provider["registry_state"] = "absent"
        with patch.object(m, "read_json", side_effect=lambda path:
                          changed if Path(path).name == "reviewer-registry.json" else json.loads(Path(path).read_text())):
            inactive = m.configuration(ROOT)
        self.assertEqual(inactive["providers"], expected)
        self.assertEqual(m.digest(m.encoded(inactive)), m.digest(m.encoded(original)))
        inactive["sources"] = self.config["sources"]
        self.engine = m.Maintenance(self.toolkit, self.root / "issues", inactive)
        self.invocation(provider="kimi")
        self.assertEqual(self.engine.start()["candidates"][0]["provider"], "kimi")

    def test_sourcing_grok_functions_does_not_launch_an_invocation(self):
        # The existing Grok regression suite loads definitions from a temporary
        # library without copying the installed toolkit or executing its CLI.
        library = self.root / "grok-functions.sh"
        source = (ROOT / "bin/ai-grok-review").read_text()
        library.write_text(source.split("\nCMD=", 1)[0] + "\n")
        result = subprocess.run([self.bash, "-c", 'source "$1"; declare -F await_result',
                                 "fixture", str(library)], capture_output=True, text=True,
                                env={**os.environ, "AI_REVIEW_EVENT_DIR": str(self.root)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("await_result", result.stdout)
        self.assertFalse(self.ledger.exists())

    def test_guard_preserves_stdin_stdout_stderr_exit(self):
        result = self.guard(operation="stream", input="unchanged input\n")
        self.assertEqual(result.returncode, 7, result.stderr)
        self.assertEqual(result.stdout, "unchanged input\n")
        self.assertEqual(result.stderr, "synthetic stderr\n")
        rows = [json.loads(line) for line in self.ledger.read_text().splitlines()]
        self.assertEqual([r["event"] for r in rows], ["started", "finished"])
        self.assertEqual(rows[-1]["exit_code"], 7)

    def test_guard_all_registered_providers_have_durable_outcomes(self):
        providers = json.loads((ROOT / "config/reviewer-registry.json").read_text())["providers"]
        for provider in providers:
            result = self.guard(provider)
            self.assertEqual(result.returncode, 0, result.stderr)
        rows = [json.loads(line) for line in self.ledger.read_text().splitlines()]
        self.assertEqual({r["provider"] for r in rows}, set(providers))
        self.assertEqual(len(rows), 2 * len(providers))

    def test_guard_concurrent_writers_preserve_all_events(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as workers:
            results = list(workers.map(lambda _: self.guard(), range(3)))
        self.assertTrue(all(r.returncode == 0 for r in results), [r.stderr for r in results])
        self.assertEqual(len(self.ledger.read_text().splitlines()), 6)

    def test_guard_no_secrets_in_events(self):
        result = self.guard(operation="secret-env", env={"PROVIDER_TEST_SECRET": "DO_NOT_COPY"})
        self.assertEqual(result.returncode, 4, result.stderr)
        self.assertNotIn("DO_NOT_COPY", self.ledger.read_text())

    def test_guard_forwards_cancellation_to_owned_wrapper(self):
        env = {**os.environ, "AI_REVIEW_EVENT_DIR": str(self.root), "SIGNAL_READY": str(self.root / "ready")}
        command = '''env --default-signal=INT "$1" "$2" grok signal & job=$!
trap 'kill -TERM "$job" 2>/dev/null || true' EXIT
for attempt in $(seq 1 200); do [ ! -f "$SIGNAL_READY" ] || break; sleep 0.05; done
[ -f "$SIGNAL_READY" ] || exit 99
kill -TERM "$job"
wait "$job"
'''
        result = subprocess.run([self.bash, "-c", command, "fixture",
                                 "/usr/bin/bash" if os.name == "nt" else self.bash, str(self.wrapper)],
                                cwd=self.toolkit, env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 44, result.stderr)
        rows = [json.loads(line) for line in self.ledger.read_text().splitlines()]
        self.assertEqual(rows[-1]["exit_code"], 44)
        self.assertEqual(rows[-1]["provenance"]["signal"], "TERM")
        self.assertEqual(rows[-1]["provenance"]["source"], "os-signal")
        self.assertEqual(rows[-1]["provenance"]["actor_class"], "unknown")
        self.assertIsNone(rows[-1]["provenance"]["paid_work_may_exist"])

    def evidence_fixture(self):
        rid = "a" * 32
        self.invocation(rid=rid, finish=False)
        checkout = self.root / "disposable-checkout"
        checkout.mkdir()
        report = checkout / "report.md"
        report.write_text("## Verdict\nSynthetic completed reviewer analysis.\n", encoding="utf-8")
        events.require_report(self.root, "grok", rid)
        return rid, checkout, report

    def test_evidence_survives_disposable_checkout_removal(self):
        rid, checkout, report = self.evidence_fixture()
        reference = events.publish_report(self.root, "grok", rid, report,
                                         {"last_proven_provider_state": "completed"})
        shutil.rmtree(checkout)
        self.assertEqual(events.verify_reports(self.root, "grok", rid), [reference["reference"]])
        self.assertNotIn(str(checkout), json.dumps(reference))
        self.assertEqual(len(list((self.root / "evidence" / rid).glob("*.report.json"))), 1)

    def test_evidence_publication_failure_keeps_response_and_blocks_cleanup(self):
        rid, _, report = self.evidence_fixture()
        original = report.read_bytes()
        with patch.object(os, "link", side_effect=OSError("synthetic publication failure")):
            with self.assertRaises(OSError):
                events.publish_report(self.root, "grok", rid, report)
        self.assertEqual(report.read_bytes(), original)
        with self.assertRaisesRegex(events.Blocked, "cleanup and replay refused"):
            events.verify_reports(self.root, "grok", rid)
        self.assertEqual(list((self.root / "evidence" / rid).glob("*.report.json")), [])

    def test_evidence_concurrent_publication_is_idempotent(self):
        rid, _, report = self.evidence_fixture()
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as workers:
            results = list(workers.map(lambda _: events.publish_report(self.root, "grok", rid, report), range(2)))
        self.assertEqual(results[0], results[1])
        self.assertEqual(events.verify_reports(self.root, "grok", rid), [results[0]["reference"]])

    def test_local_finalization_links_original_without_rewriting_it(self):
        original = "b" * 32
        self.invocation(rid=original)
        rid, _, report = self.evidence_fixture()
        rows = [json.loads(line) for line in self.ledger.read_text().splitlines()]
        rows[-1]["operation"] = "local-finalization"
        self.ledger.write_text("".join(json.dumps(row) + "\n" for row in rows))
        before = self.ledger.read_bytes()
        reference = events.publish_report(self.root, "grok", rid, report,
                                         {"original_invocation_id": original})
        self.assertEqual(events.verify_reports(self.root, "grok", rid), [reference["reference"]])
        self.assertEqual(self.ledger.read_bytes(), before)
        path = self.root / "evidence" / rid / (reference["report_sha256"] + ".report.json")
        self.assertEqual(json.loads(path.read_text())["original_invocation_id"], original)

    def test_ordinary_invocation_cannot_claim_recovery_link(self):
        original = "b" * 32
        self.invocation(rid=original)
        rid, _, report = self.evidence_fixture()
        with self.assertRaisesRegex(events.Blocked, "identity changed"):
            events.publish_report(self.root, "grok", rid, report, {"original_invocation_id": original})

    def test_owned_sandbox_refuses_removal_until_report_is_durable(self):
        rid, checkout, report = self.evidence_fixture()
        marker = checkout / ".ai-review-sandbox"
        marker.write_text(str(self.toolkit) + "\nsource_digest=synthetic\nevidence_format=1\n")
        with patch.object(events, "git_value", return_value=self.sha):
            events.bind_sandbox(self.root, "grok", rid, checkout)
        with self.assertRaisesRegex(events.Blocked, "cleanup and replay refused"):
            events.verify_sandbox(self.root, checkout)
        events.publish_report(self.root, "grok", rid, report)
        self.assertEqual(len(events.verify_sandbox(self.root, checkout)), 1)

    def test_standalone_and_legacy_sandbox_ownership_are_distinct(self):
        checkout = self.root / "sandbox"
        checkout.mkdir()
        marker = checkout / ".ai-review-sandbox"
        marker.write_text(str(self.toolkit) + "\nevidence_format=1\n")
        self.assertEqual(events.verify_sandbox(self.root, checkout), [])
        marker.write_text(str(self.toolkit) + "\nsource_digest=legacy\n")
        with self.assertRaisesRegex(events.Blocked, "reconcile"):
            events.verify_sandbox(self.root, checkout)

    def test_sandbox_binding_rejects_another_source_even_at_same_head(self):
        rid, checkout, _ = self.evidence_fixture()
        (checkout / ".ai-review-sandbox").write_text(str(self.root) + "\nevidence_format=1\n")
        with patch.object(events, "git_value", return_value=self.sha):
            with self.assertRaisesRegex(events.Blocked, "source"):
                events.bind_sandbox(self.root, "grok", rid, checkout)

    def test_sandbox_retains_every_followup_invocation_owner(self):
        rid, checkout, report = self.evidence_fixture()
        (checkout / ".ai-review-sandbox").write_text(str(self.toolkit) + "\nevidence_format=1\n")
        with patch.object(events, "git_value", return_value=self.sha):
            events.bind_sandbox(self.root, "grok", rid, checkout)
        events.publish_report(self.root, "grok", rid, report)
        next_id = "c" * 32
        self.invocation(rid=next_id, finish=False)
        events.require_report(self.root, "grok", next_id)
        with patch.object(events, "git_value", return_value=self.sha):
            events.bind_sandbox(self.root, "grok", next_id, checkout)
        with self.assertRaises(events.Blocked):
            events.verify_sandbox(self.root, checkout)
        events.publish_report(self.root, "grok", next_id, report)
        self.assertEqual(len(events.verify_sandbox(self.root, checkout)), 2)

    def legacy_sandbox_fixture(self):
        sandbox = self.root / "legacy-sandbox"
        sandbox.mkdir()
        (sandbox / ".ai-review-sandbox").write_text(str(self.toolkit) + "\nsource_digest=legacy\n")
        (sandbox / "AI-REVIEW-SANDBOX.md").write_text("Snapshot tag: grok-codex-test\n")
        meta = self.root / "legacy-meta.json"
        meta.write_text(json.dumps({"repo": str(self.toolkit), "review_dir": str(sandbox), "name": "test",
                                    "caller": "codex", "grok_session_id": "synthetic-session", "head": self.sha}))
        report = self.root / "grok-test-original.md"
        report.write_text(f"# Grok review\n- Repo: `{self.toolkit}`\n- Session: `synthetic-session`\n\nSynthetic result.\n")
        return sandbox, meta, report

    def test_legacy_exact_session_reconciliation_unlocks_only_saved_evidence(self):
        sandbox, meta, report = self.legacy_sandbox_fixture()
        result = events.reconcile_sandbox(self.root, "grok", sandbox, meta, [report])
        self.assertEqual(result["historical_source_authorization"], "unknown")
        report.unlink()
        self.assertEqual(len(events.verify_sandbox(self.root, sandbox)), 1)
        row = events.invocation(self.root, "grok", result["run_id"])
        self.assertEqual(row["operation"], "local-reconciliation")
        self.assertEqual(row["head"], "")

    def test_legacy_reconciliation_refuses_wrong_session_without_relabeling_marker(self):
        sandbox, meta, report = self.legacy_sandbox_fixture()
        before = (sandbox / ".ai-review-sandbox").read_bytes()
        report.write_text(report.read_text().replace("synthetic-session", "another-session"))
        with self.assertRaises(events.Blocked):
            events.reconcile_sandbox(self.root, "grok", sandbox, meta, [report])
        self.assertEqual((sandbox / ".ai-review-sandbox").read_bytes(), before)

    def test_legacy_reconciliation_recovers_crash_after_marker_publication_idempotently(self):
        sandbox, meta, report = self.legacy_sandbox_fixture()
        result = events.reconcile_sandbox(self.root, "grok", sandbox, meta, [report])
        rows = [json.loads(line) for line in self.ledger.read_text().splitlines()]
        self.ledger.write_text("".join(json.dumps(row) + "\n" for row in rows if row["event"] != "finished"))
        again = events.reconcile_sandbox(self.root, "grok", sandbox, meta, [report])
        self.assertTrue(again["already_reconciled"])
        events.reconcile_sandbox(self.root, "grok", sandbox, meta, [report])
        rows = [json.loads(line) for line in self.ledger.read_text().splitlines()]
        self.assertEqual(len([row for row in rows if row["event"] == "finished"]), 1)
        self.assertEqual(rows[-1]["run_id"], result["run_id"])

    def test_stale_source_finalization_preserves_original_head_without_authorizing_current_head(self):
        original = "b" * 32
        self.invocation(rid=original)
        rid, _, report = self.evidence_fixture()
        rows = [json.loads(line) for line in self.ledger.read_text().splitlines()]
        rows[-1].update(operation="local-finalization", head="f" * 40)
        self.ledger.write_text("".join(json.dumps(row) + "\n" for row in rows))
        (self.root / "evidence" / rid / "required.json").unlink()
        events.require_report(self.root, "grok", rid)
        with self.assertRaises(events.Blocked):
            events.publish_report(self.root, "grok", rid, report, {"original_invocation_id": original})
        reference = events.publish_report(self.root, "grok", rid, report,
                    {"original_invocation_id": original, "recovery_state": "completed-stale-source", "original_head_sha": self.sha})
        self.assertEqual(events.verify_reports(self.root, "grok", rid), [reference["reference"]])
        row = json.loads((self.root / "evidence" / rid / (reference["report_sha256"] + ".report.json")).read_text())
        self.assertEqual(row["original_head_sha"], self.sha)
        self.assertEqual(row["recovery_state"], "completed-stale-source")

    def test_recovered_receipt_satisfies_original_missing_publication_without_rewriting_history(self):
        original, sandbox, report = self.evidence_fixture()
        (sandbox / ".ai-review-sandbox").write_text(str(self.toolkit) + "\nevidence_format=1\n")
        with patch.object(events, "git_value", return_value=self.sha):
            events.bind_sandbox(self.root, "grok", original, sandbox)
        recovery = "d" * 32
        row = self.invocation(rid=recovery, finish=False)
        rows = [json.loads(line) for line in self.ledger.read_text().splitlines()]
        rows[-1]["operation"] = "local-finalization"
        self.ledger.write_text("".join(json.dumps(item) + "\n" for item in rows))
        events.require_report(self.root, "grok", recovery)
        before = self.ledger.read_bytes()
        reference = events.publish_report(self.root, "grok", recovery, report, {"original_invocation_id": original})
        self.assertEqual(events.verify_sandbox(self.root, sandbox), [reference["reference"]])
        self.assertEqual(self.ledger.read_bytes(), before)

    def test_shared_publisher_carries_muse_recovery_identity(self):
        original, recovery = "e" * 32, "f" * 32
        self.invocation(rid=original, provider="muse")
        self.invocation(rid=recovery, provider="muse", finish=False)
        rows = [json.loads(line) for line in self.ledger.read_text().splitlines()]
        rows[-1]["operation"] = "local-finalization"
        self.ledger.write_text("".join(json.dumps(row) + "\n" for row in rows))
        report = self.root / "muse-report.md"
        report.write_text("Synthetic retained Muse report.\n")
        env = {**os.environ, "AI_REVIEW_EVENT_DIR": str(self.root), "AI_REVIEW_EVENT_RUN_ID": recovery,
               "MUSE_RECOVERY_EVENT_RUN_ID": original}
        result = subprocess.run([self.bash, "-c", 'source "$1"; reviewer_event_publish_report muse "$2"', "fixture",
                                 str(self.toolkit / "tools/reviewer_event_guard.sh"), str(report)],
                                cwd=self.toolkit, env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(events.verify_reports(self.root, "muse", recovery)), 1)
        receipt = next((self.root / "evidence" / recovery).glob("*.report.json"))
        self.assertEqual(json.loads(receipt.read_text())["original_invocation_id"], original)

    def test_evidence_rejects_wrong_invocation_and_changed_content(self):
        rid, _, report = self.evidence_fixture()
        with self.assertRaises(events.Blocked):
            events.publish_report(self.root, "muse", rid, report)
        reference = events.publish_report(self.root, "grok", rid, report)
        path = self.root / "evidence" / rid / (reference["report_sha256"] + ".report.json")
        row = json.loads(path.read_text())
        row["report_text"] += "changed"
        path.write_text(json.dumps(row))
        with self.assertRaisesRegex(events.Blocked, "content changed"):
            events.verify_reports(self.root, "grok", rid)

    def test_evidence_changed_source_is_not_sealed(self):
        rid, _, report = self.evidence_fixture()
        original_snapshot = events.snapshot
        def changing_snapshot(path, kind):
            result = original_snapshot(path, kind)
            if Path(path) == report:
                with report.open("a") as output:
                    output.write("late output")
            return result
        with patch.object(events, "snapshot", side_effect=changing_snapshot):
            with self.assertRaisesRegex(events.Blocked, "changed during publication"):
                events.publish_report(self.root, "grok", rid, report)

    def test_evidence_missing_publication_prevents_terminal_success(self):
        rid, _, _ = self.evidence_fixture()
        with patch.dict(os.environ, {"AI_REVIEW_EVENT_DIR": str(self.root)}), \
                patch.object(sys, "argv", ["events", "finish", "grok", rid, "0"]):
            with self.assertRaises(events.Blocked):
                events.main()
        self.assertEqual([json.loads(line)["event"] for line in self.ledger.read_text().splitlines()], ["started"])

    def test_completed_invocation_cannot_gain_new_evidence_after_the_fact(self):
        rid, _, report = self.evidence_fixture()
        reference = events.publish_report(self.root, "grok", rid, report)
        with patch.dict(os.environ, {"AI_REVIEW_EVENT_DIR": str(self.root)}), \
                patch.object(sys, "argv", ["events", "finish", "grok", rid, "0"]):
            events.main()
        self.assertEqual(events.verify_reports(self.root, "grok", rid), [reference["reference"]])
        with self.assertRaisesRegex(events.Blocked, "cannot be rewritten"):
            events.publish_report(self.root, "grok", rid, report)

    def test_interruption_provenance_does_not_invent_actor_or_remote_state(self):
        for source in ("user-cancellation", "scheduler-interruption", "timeout", "process-death", "unknown"):
            row = events.provenance({"source": source})
            self.assertEqual(row["source"], source)
            self.assertEqual(row["actor_class"], "unknown")
            self.assertEqual(row["last_proven_provider_state"], "unknown")
            self.assertIsNone(row["paid_work_may_exist"])
        with self.assertRaises(events.Blocked):
            events.provenance({"private_prompt": "DO_NOT_COPY"})

    def test_record_candidate_preserves_observed_head(self):
        row = self.invocation()
        record = self.engine.start()
        details = self.root / "details.txt"
        details.write_text("Synthetic incident details.\n")
        with patch.dict(os.environ, {"AI_REVIEWER_BASH": self.bash,
                                    "AI_REVIEWER_STATE_BASE": str(self.root / "state")}):
            result = self.engine.record_incident(record["id"], record["candidates"][0]["id"], "Synthetic failure", details)
        issue = json.loads((self.engine.issues / result["issue_id"] / "issue.json").read_text())
        self.assertEqual(issue["repository"]["head"], row["head"])
        self.assertEqual(issue["join"]["run_id"], row["run_id"])

    @unittest.skipUnless(os.name == "nt", "Windows DOS path aliases")
    def test_record_candidate_accepts_same_repository_short_path(self):
        import ctypes
        buffer = ctypes.create_unicode_buffer(32768)
        size = ctypes.windll.kernel32.GetShortPathNameW(str(self.toolkit), buffer, len(buffer))
        self.assertTrue(0 < size < len(buffer), "cannot obtain native repository path")
        short = buffer.value
        if os.path.normcase(short) == os.path.normcase(str(self.toolkit)):
            self.skipTest("volume does not provide distinct DOS short names")
        self.assertEqual(m.join_digest("repo", short), m.join_digest("repo", self.toolkit))
        row = {"schema_version": 1, "provider": "grok", "event": "finished", "run_id": "short-path",
               "repo": short, "head": self.sha, "caller": "codex", "timestamp": "same-time", "exit_code": 1}
        self.write({**row, "event": "started"})
        self.write(row)
        record = self.engine.start()
        details = self.root / "details.txt"
        details.write_text("Synthetic short-path identity fixture.\n")
        with patch.dict(os.environ, {"AI_REVIEWER_BASH": self.bash,
                                    "AI_REVIEWER_STATE_BASE": str(self.root / "state")}):
            result = self.engine.record_incident(record["id"], record["candidates"][0]["id"], "Short-path failure", details)
        issue = json.loads((self.engine.issues / result["issue_id"] / "issue.json").read_text())
        self.assertEqual(m.join_digest("repo", issue["repository"]["root"]), m.join_digest("repo", short))

    def test_repository_canonicalization_never_hides_symlink(self):
        alias = self.root / "repository-alias"
        self.symlink(alias, self.toolkit, True)
        with self.assertRaisesRegex(m.Blocked, "linked path refused"):
            m.join_digest("repo", alias)

    def test_old_scoreboard_event_joins_by_digest_without_invented_run(self):
        self.config["sources"][0].pop("adapter")
        self.engine = m.Maintenance(self.toolkit, self.root / "issues", self.config)
        self.write({"schema_version": 2, "provider": "grok", "repo": str(self.toolkit), "head": self.sha,
                    "verdict": "BLOCKED", "failure_class": "legacy-failure"})
        record = self.engine.start()
        details = self.root / "details.txt"
        details.write_text("Synthetic older event, no provider run identifier.\n")
        with patch.dict(os.environ, {"AI_REVIEWER_BASH": self.bash, "AI_REVIEWER_STATE_BASE": str(self.root / "state")}):
            result = self.engine.record_incident(record["id"], record["candidates"][0]["id"], "Older failure", details)
        issue = json.loads((self.engine.issues / result["issue_id"] / "issue.json").read_text())
        self.assertIsNone(issue["join"]["run_id"])
        self.assertEqual(issue["join"]["event_sha256"], record["candidates"][0]["event_sha256"])

    def test_killed_supervisor_leaves_unproven_start(self):
        env = {**os.environ, "AI_REVIEW_EVENT_DIR": str(self.root), "SIGNAL_READY": str(self.root / "ready")}
        command = '''env --default-signal=INT "$1" "$2" grok signal & job=$!
trap 'kill -TERM "$job" 2>/dev/null || true' EXIT
for attempt in $(seq 1 200); do [ ! -f "$SIGNAL_READY" ] || break; sleep 0.05; done
[ -f "$SIGNAL_READY" ] || exit 99
owned_child="$(cat "$SIGNAL_READY")"
kill -KILL "$job"
kill -TERM "$owned_child"
wait "$job"
'''
        result = subprocess.run([self.bash, "-c", command, "fixture",
                                 "/usr/bin/bash" if os.name == "nt" else self.bash, str(self.wrapper)],
                                cwd=self.toolkit, env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 137, result.stderr)
        self.assertEqual(len(self.ledger.read_text().splitlines()), 1)
        self.assertEqual(self.engine.start()["candidates"][0]["classification"], "completion-unproven")

    def test_log_prefix_and_json_snapshot_continuity(self):
        path = self.root / "owned.log"
        path.write_bytes(b"binary\\0log fragment")
        boundary, _ = m.snapshot(path, "log")
        with path.open("ab") as output:
            output.write(b"later")
        frozen, _ = m.snapshot(path, "log", boundary, boundary["offset"])
        self.assertEqual(frozen["sha256"], boundary["sha256"])
        path.write_bytes(b'{}')
        boundary, _ = m.snapshot(path, "json")
        path.write_bytes(b'{} ')
        with self.assertRaises(m.Blocked):
            m.snapshot(path, "json", boundary)

    def test_async_submission_needs_a_recorded_worker(self):
        row = {"schema_version": 1, "provider": "kimi", "event": "started", "run_id": "submission",
               "operation": "async-submission", "repo": str(self.toolkit), "head": self.sha, "caller": "codex"}
        self.write(row)
        self.write({**row, "event": "finished", "exit_code": 0})
        record = self.engine.start()
        self.assertEqual(record["candidates"][0]["classification"], "completion-unproven")
        self.nondefect(record, "in-progress")
        self.complete(record)
        worker = {**row, "operation": "invocation", "run_id": "worker", "parent_run_id": "submission"}
        self.write(worker)
        self.write({**worker, "event": "finished", "exit_code": 2})
        next_round = self.engine.start()
        self.assertEqual(len(next_round["candidates"]), 1)
        self.assertEqual(next_round["candidates"][0]["classification"], "failed-invocation")

    def test_confirmed_cancelled_start_is_not_rediscovered(self):
        self.invocation(finish=False)
        record = self.engine.start()
        self.nondefect(record, "user-cancellation")
        self.complete(record)
        self.assertFalse(self.engine.start()["candidates"])

    def test_reopened_incident_is_discovered_after_checkpoint(self):
        iid = self.issue({}, "resolved")
        record = self.engine.start()
        self.assertFalse(record["candidates"])
        self.complete(record)
        resolution = self.engine.issues / iid / "resolutions/1.json"
        changed = json.loads(resolution.read_text())
        changed["status"] = "partially-resolved"
        (resolution.parent / "2.json").write_text(json.dumps(changed))
        self.assertEqual(self.engine.start()["candidates"][0]["existing_issue_id"], iid)

    def test_cross_repository_repair_is_verified_in_its_owner(self):
        repo = self.root / "repair-repo"
        subprocess.run(["git", "clone", "-q", str(self.toolkit), str(repo)], check=True)
        for args in (["config", "user.name", "Test"], ["config", "user.email", "test@example.com"]):
            subprocess.run(["git", "-C", str(repo), *args], check=True)
        (repo / "repair.txt").write_text("Separate repository owns this repair.\n")
        subprocess.run(["git", "-C", str(repo), "add", "repair.txt"], check=True)
        subprocess.run(["git", "-C", str(repo), "commit", "-qm", "repair"], check=True)
        sha = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
        subprocess.run(["git", "-C", str(repo), "update-ref", "refs/remotes/origin/main", sha], check=True)
        self.invocation()
        record = self.engine.start()
        iid = self.issue(record["candidates"][0], "resolved")
        resolution = self.engine.issues / iid / "resolutions/1.json"
        content = json.loads(resolution.read_text())
        content.update(repair_repository=str(repo), repair_commits=[sha])
        resolution.write_text(json.dumps(content))
        self.engine.outcome(record["id"], record["candidates"][0]["id"], issue_id=iid)
        self.complete(record)

    def test_event_lock_releases_on_death_but_not_while_owner_lives(self):
        script = '''import sys,time
sys.path.insert(0,sys.argv[1])
from reviewer_events import event_lock
with event_lock(sys.argv[2]):
 print("locked",flush=True)
 time.sleep(60)
'''
        child = subprocess.Popen([sys.executable, "-c", script, str(ROOT / "tools"), str(self.root)],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            self.assertEqual(child.stdout.readline().strip(), "locked")
            with patch.object(events.time, "monotonic", side_effect=[0, 11]):
                with self.assertRaises(events.Blocked):
                    with events.event_lock(self.root):
                        self.fail("live owner lock was taken")
            child.kill()
            child.wait(timeout=5)
            with events.event_lock(self.root):
                pass
        finally:
            if child.poll() is None:
                child.kill()
                child.wait(timeout=5)
            child.stdout.close()
            child.stderr.close()


if __name__ == "__main__":
    suite = unittest.main(verbosity=1, exit=False)
    failed = len(suite.result.failures) + len(suite.result.errors)
    skipped = len(suite.result.skipped)
    print(f"MAINTENANCE_COUNTS passed={suite.result.testsRun - failed - skipped} failed={failed} skipped={skipped}")
    sys.exit(0 if suite.result.wasSuccessful() else 1)
