#!/usr/bin/env python3
"""#1531 full synthetic native provider/profile proofs; never contacts a provider."""
import copy
import contextlib
import hashlib
import importlib.util
import json
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("profile", ROOT / "tools/review_action_profile.py")
profile = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profile)


class NativeProfile(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.work = Path(cls.tmp.name)
        cls.repo = cls.work / "source"
        cls.repo.mkdir()
        cls.home = cls.work / "home"
        cls.home.mkdir()
        cls.bin = cls.work / "mock-bin"
        cls.bin.mkdir()
        cls.env = dict(os.environ, HOME=str(cls.home), PATH=str(cls.bin) + ":" + os.environ["PATH"], AI_DEVOPS_TEST_MODE="1", AI_TASK_GATES_MODE="standard", AI_REVIEW_ACTION_TEST_CUSTODY="1", AI_REVIEW_LIFECYCLE_DIR=str(cls.work / "lifecycle"), AI_TASK_GATES_DIR=str(cls.work / "task"), AI_REVIEW_SANDBOX_DIR=str(cls.work / "sandboxes"), AI_REVIEW_EVENT_DIR=str(cls.work / "events"), AI_DEEPSEEK_TEST_DIR=str(cls.work), PYTHONDONTWRITEBYTECODE="1")
        for inherited in ("GIT_DIR", "GIT_WORK_TREE", "AI_TASK_GATES_BIN", "AI_REVIEW_PREFLIGHT_BIN", "AI_REVIEW_SCOREBOARD_BIN", "AI_REVIEW_ACTION_PROFILES_FILE"):
            cls.env.pop(inherited, None)
        cls.config = json.loads((ROOT / "config/review-action-profiles.json").read_text())
        cls.p = cls.config["profiles"][profile.PROFILE]
        cls.p["source_host_sha256"] = hashlib.sha256(b"192.0.2.1").hexdigest()
        cls.target_ref = "synthetic770destination"
        cls.p["target_ref_sha256"] = hashlib.sha256(cls.target_ref.encode()).hexdigest()
        for path in cls.p["paths"]:
            target = cls.repo / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text("# synthetic reviewed implementation\n")
            target.chmod(0o644)
        def git(*args):
            subprocess.run(["git", "-C", str(cls.repo), *args], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        git("init", "-q")
        git("config", "user.name", "Test")
        git("config", "user.email", "test@example.com")
        git("remote", "add", "origin", "https://github.com/popcre/designflow-backend.git")
        (cls.repo / ".ai-devops").mkdir()
        (cls.repo / ".ai-devops/task-gates.json").write_text(json.dumps({"schema_version": 1, "paths": [{"glob": "**", "class": "code"}], "gates": {}}))
        git("add", ".")
        git("commit", "-qm", "synthetic baseline")
        cls.inputs = cls.work / "protected"
        cls.inputs.mkdir(mode=0o700)
        cls.m = {key: "synthetic-nonauthorizing-fixture" for key in cls.p["manifest_keys"]}
        private_paths = []
        def private(name, value):
            path = cls.inputs / name
            path.write_text(json.dumps(value) if not isinstance(value, str) else value)
            path.chmod(0o600)
            private_paths.append(path)
            return str(path)
        for field in ("source_config", "destination_config", "before_manifest", "recovery_proof", "encrypted_backup", "schema_snapshot", "metadata", "grants_snapshot", "seed_rows", "archive_dependency_proof", "dependency_attestation"):
            cls.m[field] = private(field + ".json", {"synthetic": True})
        source_ca = private("source-ca.pem", "synthetic public fixture CA")
        target_ca = private("target-ca.pem", "synthetic public fixture CA")
        def replace_json(path, value):
            Path(path).write_text(json.dumps(value))
        replace_json(cls.m["source_config"], {"host": "192.0.2.1", "user": "albert_read_only", "dbname": "postgres", "port": 5432, "sslmode": "verify-ca", "sslrootcert": source_ca, "password": "synthetic-never-transmitted", "connect_timeout": 5})
        replace_json(cls.m["destination_config"], {"host": "aws-0-us-east-1.pooler.supabase.com", "user": "postgres." + cls.target_ref, "dbname": "postgres", "port": 5432, "runtime_port": 6543, "sslmode": "verify-full", "sslrootcert": target_ca, "password": "synthetic-never-transmitted", "connect_timeout": 5})
        runtime = cls.work / "runtime"
        runtime.mkdir(mode=0o700)
        (runtime / "fixture").write_text("isolated runtime fixture")
        (runtime / "fixture").chmod(0o600)
        closure, _ = profile.tree_inventory(runtime)
        cls.p["postwrite_runtime_closure_sha256"] = closure
        private("bwrap-runtime.json", {"runtime_root": str(runtime), "runtime_closure_sha256": closure})
        while len(private_paths) < 24:
            private("frozen-input-" + str(len(private_paths)) + ".json", {"synthetic": len(private_paths)})
        parser_root = cls.work / "parser"
        parser_root.mkdir(mode=0o700)
        for package in ("pglast", "pglast-8.5.dist-info"):
            (parser_root / package).mkdir(mode=0o700)
            (parser_root / package / "fixture").write_text("version 8.5 synthetic dependency")
            (parser_root / package / "fixture").chmod(0o600)
        rows = []
        for package in ("pglast", "pglast-8.5.dist-info"):
            _, children = profile.tree_inventory(parser_root / package)
            rows.append({"path": package, "type": "dir", "mode": 0o700})
            rows.extend(dict(row, path=package + "/" + row["path"]) for row in children)
        rows.sort(key=lambda row: row["path"])
        interpreter = cls.work / "python-runtime"
        interpreter.write_bytes(Path(sys.executable).resolve().read_bytes())
        interpreter.chmod(0o500)
        cls.m["python_interpreter"] = str(interpreter)
        cls.m["pglast_dependency"] = {"interpreter": str(interpreter), "interpreter_sha256": profile.file_hash(interpreter)[0], "version": "8.5", "abi": "synthetic-bound-abi", "root": str(parser_root), "files": rows, "closure_sha256": profile.sha(profile.canonical(rows))}
        mappings = {"auth_dependency_bootstrap": "scripts/cutover-recovery/schema/auth_dependency_bootstrap.sql", "tuple_constraint_contract": "scripts/cutover-rehearsal/contracts/tuple_constraint_contract.json", "tuple_preflight_tool": "scripts/cutover-rehearsal/tuple_preflight.py", "recovery_tool": "scripts/cutover-recovery/designflow-recovery.py", "postwrite_runner": "scripts/cutover-recovery/postwrite_bwrap.py", "postwrite_runtime_helper": "scripts/cutover-recovery/bwrap_restore.py", "networked_client_tool": "scripts/cutover-recovery/networked_client.py", "credential_tool": "scripts/cutover/issue_designflow_credentials.py", "custody_tool": "scripts/cutover/service_credential_custody.py"}
        cls.m.update({field: str(cls.repo / relative) for field, relative in mappings.items()})
        cls.m.update(target_ref=cls.target_ref, schema="dflow_prod", preparation_scope="TIMING_ONLY", issue_isolated_credentials=False, authorization_attested=False, action_authority={"root_action_authorized": False, "status": "PENDING_NEW_EXACT_REVIEW_AND_ROOT_DECISION"}, verdict="PENDING", postwrite_runtime_closure_sha256=closure)
        future = [str(cls.inputs / ("future-" + str(i) + ".json")) for i in range(5)]
        cls.m["future_outputs_nonexistence"] = {path: True for path in future}
        cls.m["original_restoration_result"] = future[0]
        cls.m["proposed_result"] = future[1]
        contract_path = cls.repo / "scripts/cutover-rehearsal/contracts/timing_action_contract.json"
        all_paths = [cls.repo / path for path in cls.p["paths"] if cls.repo / path != contract_path] + private_paths + [interpreter]
        contract = {"immutable_inputs": [{"logical_label": "code/" + str(path.relative_to(cls.repo)) if path.is_relative_to(cls.repo) else "protected/" + str(i), "sha256": profile.file_hash(path)[0], "bytes": path.stat().st_size} for i, path in enumerate(all_paths)]}
        contract_path.write_text(json.dumps(contract, sort_keys=True))
        cls.m["input_sha256"] = {str(path): profile.file_hash(path)[0] for path in all_paths + [contract_path]}
        cls.m["loader_sha256"] = cls.m["input_sha256"][str(cls.repo / "scripts/cutover-rehearsal/loader.py")]
        cls.m["reviewed_action_contract_sha256"] = cls.m["input_sha256"][str(contract_path)]
        git("add", ".")
        git("commit", "-qm", "synthetic complete bounded implementation")
        cls.head = subprocess.check_output(["git", "-C", str(cls.repo), "rev-parse", "HEAD"]).decode().strip()
        cls.m["source_head"] = cls.head
        cls.manifest = cls.inputs / "manifest.json"
        cls.manifest.write_text(json.dumps(cls.m))
        cls.manifest.chmod(0o600)
        cls.paths = cls.work / "paths.json"
        cls.paths.write_text(json.dumps(cls.p["paths"]))
        cls.profiles_file = cls.work / "profiles.json"
        cls.profiles_file.write_text(json.dumps(cls.config, sort_keys=True))
        cls.env["AI_REVIEW_ACTION_PROFILES_FILE"] = str(cls.profiles_file)
        for kind in ("preflight", "scoreboard"):
            stub = cls.bin / kind
            stub.write_text("#!/usr/bin/env bash\nexit 0\n")
            stub.chmod(0o700)
            cls.env["AI_REVIEW_" + kind.upper() + "_BIN"] = str(stub)
        keydir = cls.home / ".config/ai-devops/secrets"
        keydir.mkdir(parents=True, mode=0o700)
        (keydir / "deepseek-api-key").write_text("synthetic-test-key\n")
        (keydir / "deepseek-api-key").chmod(0o600)
        curl = cls.bin / "curl"
        curl.write_text('''#!/usr/bin/env python3
import json,sys,re,os
from pathlib import Path
a=sys.argv; out=a[a.index('-o')+1]; req=json.loads(Path(a[a.index('-d')+1][1:]).read_text()); text='\\n'.join(x['content'] for x in req['messages']); head=re.search(r'Synthetic review HEAD: ([a-f0-9]{40})',text)[1]; descriptor_match=re.search(r'Exact canonical operational descriptor sha256: ([a-f0-9]{64})',text); descriptor=descriptor_match[1] if descriptor_match else '0'*64
assert 'synthetic-never-transmitted' not in text and 'synthetic770destination' not in text
if descriptor_match:
 assert '"evidence_kind": "native-validated-private-action-commitment"' in text
 assert '"action_authorized": false' in text
 assert '"issue_isolated_credentials": false' in text
with (Path(os.environ['AI_DEEPSEEK_TEST_DIR'])/'curl-calls').open('a') as calls: calls.write('dispatch\\n')
content='The complete selected runtime code and typed contract were reviewed. The immutable operational descriptor covers exactly the isolated timing rehearsal, disabled credentials and callbacks, and mandatory original restoration. This approval is bounded to the stated profile and descriptor and confers no production or root action authority.\\nAction scope: shared-db-770-isolated-timing-rehearsal-v1 descriptor sha256:'+descriptor+'.\\nVERDICT: APPROVE '+head+'\\n\\n'
if (Path(os.environ['AI_DEEPSEEK_TEST_DIR'])/'mock-revise').exists(): content=content.replace('VERDICT: APPROVE ', 'VERDICT: REVISE ')
Path(out).write_text(json.dumps({'choices':[{'message':{'content':content}}],'usage':None})); print('200',end='')
''')
        curl.chmod(0o700)
        cls.run_command([str(ROOT / "bin/ai-task-gates"), "start", "--class", "code", "--base", "HEAD~1", "--reason", "offline bounded profile fixture"])
        cls.original_environment = dict(os.environ)
        os.environ.update(cls.env)
        cls.front = cls.run_command([str(ROOT / "bin/ai-review"), "deepseek", "final-check", "--implementer", "codex", "--code-only", "--paths-file", str(cls.paths), "--base", "HEAD~1", "--action-profile", profile.PROFILE, "--action-manifest", str(cls.manifest)])
        states = list((cls.work / "lifecycle/runs").glob("*/*/*/*.json"))
        cls.state_path = next(path for path in states if json.loads(path.read_text()).get("status") == "completed")
        cls.state = json.loads(cls.state_path.read_text())
        cls.report = cls.state["report_path"]
        cls.bound = copy.deepcopy(cls.m)
        cls.bound["verdict"] = "APPROVE"
        cls.bound["review_report"] = cls.report
        cls.bound["review_report_sha256"] = hashlib.sha256(Path(cls.report).read_bytes()).hexdigest()
        cls.initial_state = cls.state_path.read_bytes()
        cls.task_file = next((cls.work / "task").glob("*.json"))
        cls.initial_task = cls.task_file.read_bytes()

    @classmethod
    def run_command(cls, command, manifest=None, expected=0):
        result = subprocess.run(command, cwd=cls.repo, env=cls.env, input=json.dumps(manifest).encode() if manifest is not None else None, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode != expected:
            if hasattr(cls, "m"):
                for path in (cls.work / "lifecycle/runs").glob("*/*/*/*.json"):
                    candidate = json.loads(path.read_text())
                    if candidate.get("status") == "preflight":
                        profile.action_binding(candidate, cls.m, "capture")
                    if candidate.get("action_profile_binding"):
                        # Synthetic fixture diagnosis only; never edits a state
                        # or publishes a verdict/receipt from the failed run.
                        with mock.patch.dict(os.environ, cls.env):
                            binding = profile.action_binding(candidate, cls.m, "capture")
                            if binding != candidate["action_profile_binding"]:
                                raise AssertionError("synthetic evidence changed keys: " + str([k for k in binding if binding[k] != candidate["action_profile_binding"].get(k)]))
                            profile.review_evidence(candidate, cls.m, binding)
            raise AssertionError("native fixture exit " + str(result.returncode) + ": " + result.stderr.decode()[-1500:])
        return result

    @classmethod
    def tearDownClass(cls):
        os.environ.clear(); os.environ.update(cls.original_environment)
        cls.tmp.cleanup()

    def setUp(self):
        self.state_path.write_bytes(self.initial_state)
        self.state_path.chmod(0o600)
        self.task_file.write_bytes(self.initial_task)
        self.task_file.chmod(0o600)
        for path in self.m["future_outputs_nonexistence"]:
            Path(path).unlink(missing_ok=True)

    def gate(self, manifest=None, stage=None, action="database", success=True, stdin=True):
        args = [str(ROOT / "bin/ai-task-gates"), "check", "--before", action, "--reviewer-approval", self.report]
        if stdin:
            args += ["--action-manifest-stdin"]
        if stage:
            args += ["--action-stage", stage]
        scratch = self.work / "gate temporary ' $missing ;"
        scratch.mkdir(mode=0o700, exist_ok=True)
        self.assertEqual(list(scratch.iterdir()), [])
        result = subprocess.run(args, cwd=self.repo, env=dict(self.env, TMPDIR=str(scratch)), input=json.dumps(manifest or self.bound).encode() if stdin else None, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertNotIn(b"unbound variable", result.stderr)
        self.assertEqual(list(scratch.iterdir()), [], "bounded manifest temporary file leaked")
        self.assertEqual(result.returncode == 0, success, result.stderr.decode()[-1000:])
        return result

    def test_01_complete_native_profile_and_exact_terminal_lf(self):
        proof = self.state["code_only_completion"]
        self.assertNotEqual(proof["raw_final_message_sha256"], proof["transcript_report_sha256"])
        transcript = json.loads((Path(self.state["code_only_export"]) / ".ai/deepseek-sessions" / (self.state["session_id"] + ".json")).read_text())
        self.assertEqual(Path(self.report).read_bytes(), transcript[-1]["content"].encode())
        self.assertFalse(Path(self.report).read_bytes().endswith(b"\n"))
        self.gate()
        receipt = json.loads(self.state_path.read_text())["action_initial_admission"]
        self.assertEqual(receipt["binding"]["stage"], "initial-forward")
        self.gate()  # supported stacked checks before the first output/write

    def test_02_generic_and_other_action_refuse_without_receipt(self):
        self.gate(stdin=False, success=False)
        self.gate(action="production", success=False)
        self.assertNotIn("action_initial_admission", json.loads(self.state_path.read_text()))

    def test_03_restoration_needs_receipt_then_allows_only_declared_outputs(self):
        self.gate(stage="original-restoration", success=False)
        self.gate()
        for path in self.m["future_outputs_nonexistence"]:
            Path(path).write_text("synthetic completed output")
            Path(path).chmod(0o600)
        self.gate(success=False)
        self.gate(stage="original-restoration")
        leaf = Path(next(iter(self.m["future_outputs_nonexistence"])))
        leaf.unlink(); leaf.symlink_to(self.manifest)
        self.gate(stage="original-restoration", success=False)

    def test_04_changed_target_descriptor_and_authority_refuse(self):
        for field, value in (("target_ref", "production"), ("schema", "public"), ("issue_isolated_credentials", True), ("source_head", "0" * 40), ("loader_sha256", "0" * 64), ("original_restoration_result", "foreign"), ("authorization_attested", True)):
            with self.subTest(field=field):
                changed = copy.deepcopy(self.bound); changed[field] = value
                self.gate(changed, success=False)
        self.assertNotIn("action_initial_admission", json.loads(self.state_path.read_text()))

    def test_05_task_declaration_changes_refuse_native_receipt_is_permitted(self):
        for field, value in (("base", "HEAD"), ("declared_class", "prose"), ("reason", "changed"), ("start_head", "0" * 40)):
            with self.subTest(field=field):
                task = json.loads(self.initial_task); task[field] = value
                self.task_file.write_text(json.dumps(task))
                self.gate(success=False)
                self.task_file.write_bytes(self.initial_task)
        task = json.loads(self.initial_task); task["overrides"].append({"kind": "native-test-receipt"})
        self.task_file.write_text(json.dumps(task))
        self.gate()

    def test_06_receipt_tamper_and_future_substitution_refuse(self):
        self.gate()
        state = json.loads(self.state_path.read_text()); state["action_initial_admission"]["binding_sha256"] = "0" * 64
        self.state_path.write_text(json.dumps(state))
        self.gate(stage="original-restoration", success=False)
        self.state_path.write_bytes(self.initial_state)
        changed = copy.deepcopy(self.bound); changed["future_outputs_nonexistence"][str(self.inputs / "undeclared.json")] = True
        self.gate(changed, success=False)

    def test_07_complete_closure_and_input_tamper_refuse(self):
        changed = copy.deepcopy(self.bound); changed["input_sha256"].pop(next(iter(changed["input_sha256"])))
        self.gate(changed, success=False)
        selected = Path(self.state["code_only_export"]) / ".ai-review-sandbox"
        raw = selected.read_bytes(); marker = json.loads(raw); marker["paths"] = ["README.md"]
        selected.write_text(json.dumps(marker))
        self.gate(success=False)
        selected.write_bytes(raw)
        input_path = Path(self.m["before_manifest"]); raw = input_path.read_bytes(); input_path.write_text("tampered actual immutable input")
        self.gate(success=False)
        input_path.write_bytes(raw)

    def test_09_direct_admission_without_native_gate_receipt_refuses(self):
        result = subprocess.run([sys.executable, str(ROOT / "tools/review_action_profile.py"), "preaction", str(self.state_path), "--admit"], cwd=self.repo, env=self.env, input=json.dumps(self.bound).encode(), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"native bounded action validation refused", result.stderr)
        with self.assertRaisesRegex(ValueError, "native successful database reviewer receipt missing"):
            profile.admit(self.state_path, self.state, self.state["action_profile_binding"], "initial-forward", True)
        self.assertNotIn("action_initial_admission", json.loads(self.state_path.read_text()))

    def test_10_native_override_private_under_permissive_umask(self):
        original = json.loads(self.initial_task)
        args = [str(ROOT / "bin/ai-task-gates"), "check", "--before", "database", "--reviewer-approval", self.report, "--action-manifest-stdin"]
        result = subprocess.run(args, cwd=self.repo, env=self.env, input=json.dumps(self.bound).encode(), stdout=subprocess.PIPE, stderr=subprocess.PIPE, umask=0o002)
        self.assertEqual(result.returncode, 0, result.stderr.decode()[-1000:])
        self.assertEqual(self.task_file.stat().st_mode & 0o777, 0o600)
        current = json.loads(self.task_file.read_text())
        self.assertEqual({k: v for k, v in original.items() if k != "overrides"}, {k: v for k, v in current.items() if k != "overrides"})

    def test_11_dormant_dependency_descriptor_and_callback_refuse(self):
        changed = copy.deepcopy(self.bound); changed["dependency_attestation"] = str(self.inputs / "other-missing-attestation")
        self.gate(changed, success=False)
        changed = copy.deepcopy(self.bound); changed["acceptance_runner"] = "synthetic callback"
        self.gate(changed, success=False)

    def test_12_unsupported_platform_advisory_preserves_selected_packet_only(self):
        probe = self.bin / "python3"
        probe.write_text("#!/bin/sh\nif [ \"$1\" = -c ] && printf '%s' \"$2\" | grep -q 'hasattr(os, \"O_NOFOLLOW\")'; then exit 1; fi\nexec " + sys.executable + " \"$@\"\n")
        probe.chmod(0o700)
        args = [str(ROOT / "bin/ai-review"), "deepseek", "final-check", "--implementer", "codex", "--code-only", "--paths-file", str(self.paths), "--base", "HEAD~1"]
        before = sorted((self.work / "lifecycle/runs").glob("*/*/*/*.json"))
        exports = sorted((self.work / "sandboxes").rglob("*.source.json"))
        try:
            refused = subprocess.run(args + ["--action-profile", profile.PROFILE, "--action-manifest", str(self.manifest)], cwd=self.repo, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertNotEqual(refused.returncode, 0)
            self.assertIn(b"no export or reviewer was started", refused.stderr)
            self.assertEqual(exports, sorted((self.work / "sandboxes").rglob("*.source.json")))
            advisory = subprocess.run(args, cwd=self.repo, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertEqual(advisory.returncode, 0, advisory.stderr.decode()[-1000:])
            self.assertIn(b"selected-code advisory review only", advisory.stderr)
            revise_marker = self.work / "mock-revise"; revise_marker.write_text("fixture-only")
            try:
                revised = subprocess.run(args, cwd=self.repo, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                self.assertNotEqual(revised.returncode, 0)
                self.assertNotIn(b"VERDICT: APPROVE", revised.stdout)
                self.assertIn(b"VERDICT: REVISE", revised.stdout)
            finally:
                revise_marker.unlink()

            self.assertEqual(before, sorted((self.work / "lifecycle/runs").glob("*/*/*/*.json")))
            report = self.work / "advisory-report.txt"; report.write_bytes(advisory.stdout)
            refused = subprocess.run([str(ROOT / "bin/ai-task-gates"), "check", "--before", "database", "--reviewer-approval", str(report)], cwd=self.repo, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertNotEqual(refused.returncode, 0)
            self.assertNotIn("action_initial_admission", json.loads(self.state_path.read_text()))
        finally:
            probe.unlink(missing_ok=True)

    def test_13_failed_prospective_capture_is_terminal_without_dispatch(self):
        calls = self.work / "curl-calls"
        count = calls.read_bytes()
        bad = copy.deepcopy(self.m); bad["target_ref"] = "production"
        bad_path = self.work / "invalid-profile.json"; bad_path.write_text(json.dumps(bad)); bad_path.chmod(0o600)
        partial_paths = self.work / "partial-paths.json"; partial_paths.write_text(json.dumps([self.p["paths"][0]])); partial_paths.chmod(0o600)
        args = [str(ROOT / "bin/ai-review"), "deepseek", "final-check", "--implementer", "codex", "--code-only", "--base", "HEAD~1", "--action-profile", profile.PROFILE]
        for paths, manifest in ((self.paths, bad_path), (partial_paths, self.manifest)):
            before = set((self.work / "lifecycle/runs").glob("*/*/*/*.json"))
            scratch = self.work / "failed-begin-temp"; scratch.mkdir(mode=0o700, exist_ok=True)
            result = subprocess.run(args + ["--paths-file", str(paths), "--action-manifest", str(manifest)], cwd=self.repo, env=dict(self.env, TMPDIR=str(scratch)), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(list(scratch.iterdir()), [])
            self.assertNotIn(b"unbound variable", result.stderr)
            self.assertEqual(calls.read_bytes(), count)
            created = set((self.work / "lifecycle/runs").glob("*/*/*/*.json")) - before
            self.assertEqual(len(created), 1)
            row = json.loads(next(iter(created)).read_text())
            self.assertEqual(row["status"], "failed")
            self.assertFalse(Path(row["lock_path"]).exists())
            self.assertNotIn("action_initial_admission", row)

    def test_14_failed_dispatch_closes_native_state_and_removes_only_standalone_temps(self):
        scratch = self.work / "failed-dispatch-temp"; scratch.mkdir(mode=0o700)
        stub = self.work / "failed-provider"; stub.write_text("#!/bin/sh\nprintf 'synthetic dispatch failure\\n' >&2\nexit 17\n"); stub.chmod(0o700)
        before = set((self.work / "lifecycle/runs").glob("*/*/*/*.json"))
        args = [str(ROOT / "bin/ai-review"), "deepseek", "final-check", "--implementer", "codex", "--code-only", "--paths-file", str(self.paths), "--base", "HEAD~1", "--action-profile", profile.PROFILE, "--action-manifest", str(self.manifest)]
        result = subprocess.run(args, cwd=self.repo, env=dict(self.env, TMPDIR=str(scratch), AI_DEEPSEEK_REVIEW_BIN=str(stub)), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(result.returncode, 17)
        self.assertIn(b"synthetic dispatch failure", result.stderr)
        self.assertNotIn(b"unbound variable", result.stderr)
        self.assertEqual(list(scratch.iterdir()), [], "standalone provider result/stderr temporary file leaked")
        created = set((self.work / "lifecycle/runs").glob("*/*/*/*.json")) - before
        self.assertEqual(len(created), 1)
        row = json.loads(next(iter(created)).read_text())
        self.assertEqual(row["status"], "failed")
        self.assertFalse(Path(row["lock_path"]).exists())
        self.assertTrue(Path(row["code_only_export"]).is_dir())
        self.assertNotIn("action_initial_admission", row)

    def test_08_genuine_message_other_than_documented_lf_normalization_refuses(self):
        transcript_path = Path(self.state["code_only_export"]) / ".ai/deepseek-sessions" / (self.state["session_id"] + ".json")
        raw = transcript_path.read_bytes(); transcript = json.loads(raw); transcript[-1]["content"] += "changed"
        transcript_path.write_text(json.dumps(transcript))
        self.gate(success=False)
        transcript_path.write_bytes(raw)


    def test_15_refused_public_evidence_closes_native_state_without_dispatch(self):
        calls = self.work / "curl-calls"
        count = calls.read_bytes()
        probe = self.bin / "realpath"
        public_file = str(ROOT / "tools/review_action_profile.py")
        probe.write_text('#!/bin/sh\nif [ "$#" = 2 ] && [ "$1" = -- ] && [ "$2" = "' + public_file + '" ]; then printf "%s\\n" /noncanonical-public-evidence; exit 0; fi\nexec /usr/bin/realpath "$@"\n')
        probe.chmod(0o700)
        before = set((self.work / "lifecycle/runs").glob("*/*/*/*.json"))
        args = [str(ROOT / "bin/ai-review"), "deepseek", "final-check", "--implementer", "codex", "--code-only", "--paths-file", str(self.paths), "--base", "HEAD~1", "--action-profile", profile.PROFILE, "--action-manifest", str(self.manifest)]
        try:
            result = subprocess.run(args, cwd=self.repo, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertEqual(result.returncode, 3)
            self.assertIn(b"public action-scope evidence unavailable", result.stderr)
            self.assertEqual(calls.read_bytes(), count)
            created = set((self.work / "lifecycle/runs").glob("*/*/*/*.json")) - before
            self.assertEqual(len(created), 1)
            row = json.loads(next(iter(created)).read_text())
            self.assertEqual(row["status"], "failed")
            self.assertFalse(Path(row["lock_path"]).exists())
            self.assertNotIn("action_initial_admission", row)
        finally:
            probe.unlink(missing_ok=True)

    def test_16_actual_provider_projection_contains_no_private_values_or_paths(self):
        files = list(Path(self.state["code_only_export"]).glob(".ai-review-action-scope.*/evidence.json"))
        self.assertEqual(len(files), 1)
        raw = files[0].read_bytes()
        evidence = json.loads(raw)
        for value in (self.target_ref, "synthetic-never-transmitted", str(self.inputs), str(self.repo)):
            self.assertNotIn(value.encode(), raw)
        self.assertEqual(evidence["manifest_descriptor_sha256"], self.state["action_profile_binding"]["manifest_descriptor_sha256"])
        self.assertEqual(evidence["immutable_input_count"], 77)
        self.assertEqual(set(evidence["selected_code_input_sha256"]), set(self.p["paths"]))
        self.assertEqual(evidence["validated_scope"], {"preparation_scope": "TIMING_ONLY", "issue_isolated_credentials": False, "acceptance_callback": False, "original_restoration_required": True})
        self.assertFalse(evidence["action_authorized"])
        self.assertFalse(evidence["live_rehearsal_proven"])
        self.assertEqual(evidence["installed_enforcement"]["kind"], "NONAUTHORIZING_TEST_FIXTURE")

    def test_17_changed_commitment_refuses_projection_without_disclosing_values(self):
        state = copy.deepcopy(self.state); state["status"] = "running"
        state_path = self.work / "projection-state.json"; state_path.write_text(json.dumps(state)); state_path.chmod(0o600)
        changed = copy.deepcopy(self.m); changed["issue_isolated_credentials"] = True
        manifest = self.work / "changed-projection.json"; manifest.write_text(json.dumps(changed)); manifest.chmod(0o600)
        r = subprocess.run([sys.executable, str(ROOT / "tools/review_action_profile.py"), "evidence", str(state_path), "--manifest", str(manifest)], cwd=self.repo, env=self.env, capture_output=True)
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(r.stdout, b"")
        self.assertNotIn(self.target_ref.encode(), r.stderr)

    def test_18_changed_enforcement_refuses_before_admission(self):
        state = copy.deepcopy(self.state); state["status"] = "running"
        state_path = self.work / "enforcement-state.json"; state_path.write_text(json.dumps(state)); state_path.chmod(0o600)
        original = state_path.read_bytes()
        changed = copy.deepcopy(state["action_profile_binding"]["installed_enforcement"])
        changed["public_enforcement_sha256"]["bin/ai-task-gates"] = "0" * 64
        output = io.StringIO()
        with mock.patch.object(profile, "installed_enforcement", return_value=changed), mock.patch.object(profile, "admit") as admit, mock.patch.object(sys, "argv", ["profile", "evidence", str(state_path), "--manifest", str(self.manifest)]), contextlib.redirect_stdout(output), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(profile.main(), 1)
            admit.assert_not_called()
        self.assertEqual(output.getvalue(), "")
        self.assertEqual(state_path.read_bytes(), original)

    def test_19_private_value_in_source_identity_refuses_without_disclosure(self):
        state = copy.deepcopy(self.state); state["status"] = "running"; state["source_digest"] = "PRIVATE-IDENTITY-SENTINEL"
        path = self.work / "private-identity-state.json"; path.write_text(json.dumps(state)); path.chmod(0o600)
        r = subprocess.run([sys.executable, str(ROOT / "tools/review_action_profile.py"), "evidence", str(path), "--manifest", str(self.manifest)], cwd=self.repo, env=self.env, capture_output=True)
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(r.stdout, b"")
        self.assertNotIn(b"PRIVATE-IDENTITY-SENTINEL", r.stderr)

    def test_20_tampered_projection_is_terminal_without_admission(self):
        stub = self.work / "tampering-provider"
        stub.write_text("#!/usr/bin/env python3\nimport sys\nfrom pathlib import Path\na=sys.argv; paths=[a[i+1] for i,x in enumerate(a[:-1]) if x=='--file']; p=Path(paths[-1]); p.write_text('tampered public projection'); raise SystemExit(17)\n")
        stub.chmod(0o700)
        before = set((self.work / "lifecycle/runs").glob("*/*/*/*.json"))
        args = [str(ROOT / "bin/ai-review"), "deepseek", "final-check", "--implementer", "codex", "--code-only", "--paths-file", str(self.paths), "--base", "HEAD~1", "--action-profile", profile.PROFILE, "--action-manifest", str(self.manifest)]
        r = subprocess.run(args, cwd=self.repo, env=dict(self.env, AI_DEEPSEEK_REVIEW_BIN=str(stub)), capture_output=True)
        self.assertEqual(r.returncode, 3, r.stderr)
        self.assertIn(b"native action evidence changed", r.stderr)
        created = set((self.work / "lifecycle/runs").glob("*/*/*/*.json")) - before
        self.assertEqual(len(created), 1)
        row = json.loads(next(iter(created)).read_text())
        self.assertEqual(row["status"], "failed")
        self.assertFalse(Path(row["lock_path"]).exists())
        self.assertNotIn("action_initial_admission", row)


class InstalledEnforcementTests(unittest.TestCase):
    """Real clean Git source with fake external receipts; no system writes."""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.files = ("tools/review_action_profile.py", "config/review-action-profiles.json", "bin/ai-review-code-only.py", "bin/ai-task-gates")
        for name in self.files:
            path = self.root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_text("public fixture\n"); path.chmod(0o644)
        def git(*args):
            return subprocess.check_output(["git", "-C", str(self.root), *args], stderr=subprocess.DEVNULL)
        git("init", "-q"); git("config", "user.name", "Test"); git("config", "user.email", "test@example.com")
        git("add", "."); git("commit", "-qm", "public enforcement fixture")
        self.head = git("rev-parse", "HEAD").decode().strip()
        self.receipt = ("meta\tsource_sha\t" + self.head + "\t-\nsymlink\t/usr/local/bin/ai-task-gates\t" + str(self.root / "bin/ai-task-gates") + "\t" + profile.sha((self.root / "bin/ai-task-gates").read_bytes()) + "\n").encode()
        self.resolve = Path.resolve

    def tearDown(self):
        self.tmp.cleanup()

    def proof(self, receipt=None, wrong_launcher=False):
        def resolve(path, *args, **kwargs):
            if str(path) == "/usr/local/bin/ai-task-gates":
                return self.root / ("bin/wrong" if wrong_launcher else "bin/ai-task-gates")
            return self.resolve(path, *args, **kwargs)
        with mock.patch.object(profile, "ROOT", self.root), mock.patch.dict(os.environ, {"AI_DEVOPS_TEST_MODE": "0"}), mock.patch.object(Path, "resolve", resolve), mock.patch.object(profile._native, "private_read", return_value=self.receipt if receipt is None else receipt):
            return profile.installed_enforcement()

    def test_matching_committed_source_and_installed_receipt(self):
        proof = self.proof()
        self.assertEqual(proof["kind"], "VERIFIED_INSTALLED_SOURCE")
        self.assertEqual(proof["source_head"], self.head)
        self.assertEqual(set(proof["public_enforcement_sha256"]), set(self.files))

    def test_stale_receipt_refuses(self):
        with self.assertRaises(ValueError): self.proof(self.receipt.replace(self.head.encode(), b"0" * 40))

    def test_foreign_launcher_refuses(self):
        with self.assertRaises(ValueError): self.proof(wrong_launcher=True)

    def test_modified_enforcement_refuses(self):
        (self.root / self.files[0]).write_text("modified\n")
        with self.assertRaises(ValueError): self.proof()

    def test_duplicate_source_receipt_refuses(self):
        with self.assertRaises(ValueError): self.proof(self.receipt + self.receipt.splitlines(keepends=True)[0])

    def test_group_writable_source_is_fixture_only_and_real_installation_refuses(self):
        for name in self.files:
            (self.root / name).chmod(0o664)
        with self.assertRaises(ValueError): self.proof()
        with mock.patch.object(profile, "ROOT", self.root), mock.patch.dict(os.environ, {"AI_DEVOPS_TEST_MODE": "1"}):
            proof = profile.installed_enforcement()
        self.assertEqual(proof["kind"], "NONAUTHORIZING_TEST_FIXTURE")
        self.assertNotIn("source_head", proof)
        self.assertNotIn("installation_receipt_sha256", proof)


class InstalledActionEvidenceTests(unittest.TestCase):
    """Exercise the actual shell helper's disclosure boundary without a provider."""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.files = ["tools/review_action_profile.py", "config/review-action-profiles.json", "bin/ai-review-code-only.py", "bin/ai-task-gates"]
        for name in self.files:
            p = self.root / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text("public enforcement fixture")
        source = (ROOT / "bin/ai-review").read_text()
        self.helper = "action_review_evidence_args(){" + source.split("action_review_evidence_args(){", 1)[1].split("\n}", 1)[0] + "\n}"

    def tearDown(self):
        self.tmp.cleanup()

    def run_helper(self):
        script = self.helper + '\nREAL_DIR="$1/bin"\nif action_review_evidence_args; then printf "%s\\0" "${action_evidence_args[@]}"; else exit 3; fi'
        return subprocess.run(["bash", "-c", script, "fixture", str(self.root)], capture_output=True)

    def test_actual_installed_public_files_only(self):
        (self.root / "private-manifest.json").write_text("PRIVATE-MANIFEST-SENTINEL")
        r = self.run_helper()
        self.assertEqual(r.returncode, 0, r.stderr)
        args = r.stdout.decode().rstrip("\0").split("\0")
        self.assertEqual(args[::2], ["--file"] * 4)
        self.assertEqual(args[1::2], [str(self.root / name) for name in self.files])
        self.assertNotIn("private-manifest", r.stdout.decode())

    def test_missing_public_enforcement_refuses_before_dispatch(self):
        (self.root / self.files[0]).unlink()
        r = self.run_helper()
        self.assertEqual((r.returncode, r.stdout), (3, b""))

    def test_linked_file_refuses_before_dispatch(self):
        p = self.root / self.files[0]
        p.unlink()
        p.symlink_to(self.root / self.files[1])
        r = self.run_helper()
        self.assertEqual((r.returncode, r.stdout), (3, b""))

    def test_linked_parent_refuses_before_dispatch(self):
        p = self.root / "tools"
        p.rename(self.root / "hidden")
        p.symlink_to(self.root / "hidden", target_is_directory=True)
        r = self.run_helper()
        self.assertEqual((r.returncode, r.stdout), (3, b""))

    def test_installer_preserves_execution_and_removes_external_writes(self):
        source = (ROOT / "install.sh").read_text()
        helper = "protect_review_enforcement() {" + source.split("protect_review_enforcement() {", 1)[1].split("\n}", 1)[0] + "\n}"
        for name in self.files:
            (self.root / name).chmod(0o775 if name.startswith("bin/") else 0o664)
        script = helper + '\nREPO_ROOT="$1"\nprotect_review_enforcement'
        r = subprocess.run(["bash", "-c", script, "fixture", str(self.root)], capture_output=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        for name in self.files:
            self.assertEqual((self.root / name).stat().st_mode & 0o777, 0o755 if name.startswith("bin/") else 0o644)

    def test_installer_refuses_linked_enforcement_without_chmod_target(self):
        source = (ROOT / "install.sh").read_text()
        helper = "protect_review_enforcement() {" + source.split("protect_review_enforcement() {", 1)[1].split("\n}", 1)[0] + "\n}"
        target = self.root / "foreign-file"; target.write_text("preserved fixture"); target.chmod(0o664)
        path = self.root / self.files[0]; path.unlink(); path.symlink_to(target)
        r = subprocess.run(["bash", "-c", helper + '\nREPO_ROOT="$1"\nprotect_review_enforcement', "fixture", str(self.root)], capture_output=True)
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(target.stat().st_mode & 0o777, 0o664)

    def test_installer_refuses_linked_parent_without_chmod_target(self):
        source = (ROOT / "install.sh").read_text()
        helper = "protect_review_enforcement() {" + source.split("protect_review_enforcement() {", 1)[1].split("\n}", 1)[0] + "\n}"
        parent = self.root / "tools"; parent.rename(self.root / "hidden"); parent.symlink_to(self.root / "hidden", target_is_directory=True)
        target = self.root / "hidden/review_action_profile.py"; target.chmod(0o664)
        r = subprocess.run(["bash", "-c", helper + '\nREPO_ROOT="$1"\nprotect_review_enforcement', "fixture", str(self.root)], capture_output=True)
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(target.stat().st_mode & 0o777, 0o664)


if __name__ == "__main__":
    unittest.main(verbosity=2)
