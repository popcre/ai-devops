"""Offline adversarial tests of the closed HTS retry declaration."""
import copy
import importlib.util
import json
import pathlib
import tempfile
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "workflow_target", ROOT / "tools/application_workflow_target.py")
TARGET = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TARGET)


class ClosedRecoveryTarget(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.path = self.root / "target.json"

    def validate(self, value):
        self.path.write_text(json.dumps(value))
        with patch("sys.argv", ["validator", str(self.root), "target.json"]):
            return TARGET.main()

    def test_original_and_exact_recovery_remain_admitted(self):
        self.assertEqual(self.validate(TARGET.TARGET), 0)
        self.assertEqual(self.validate(TARGET.RECOVERY_TARGET), 0)

    def test_retry_cannot_change_run_or_bounds(self):
        mutations = {
            "debate_run_id": "00000000-0000-4000-8000-000000000000",
            "maximum_requeues": 2,
            "rfq_item_id": 17544,
            "required_status": "pending",
            "required_credit_state": "unknown",
            "required_eligible_backlog": 1,
            "before_snapshot": "none",
            "scheduler": "manual",
            "manual_drain": True,
        }
        for field, value in mutations.items():
            with self.subTest(field=field):
                declaration = copy.deepcopy(TARGET.RECOVERY_TARGET)
                declaration["recovery"][field] = value
                self.assertEqual(self.validate(declaration), 1)

    def test_numeric_limits_refuse_boolean_and_float_coercion(self):
        for field, value in [("maximum_requeues", True),
                             ("maximum_requeues", 1.0),
                             ("required_eligible_backlog", False),
                             ("required_eligible_backlog", 0.0),
                             ("rfq_item_id", 17543.0),
                             ("manual_drain", 0)]:
            with self.subTest(field=field, value=value):
                declaration = copy.deepcopy(TARGET.RECOVERY_TARGET)
                declaration["recovery"][field] = value
                self.assertEqual(self.validate(declaration), 1)

    def test_routes_origin_and_forbidden_actions_remain_closed(self):
        for declaration in [TARGET.TARGET, TARGET.RECOVERY_TARGET]:
            for field, value in [
                ("routes", declaration["routes"] + ["POST /api/hts-rag/debate-drain"]),
                ("forbidden", [x for x in declaration["forbidden"] if x != "sql"]),
                ("api_origin", "https://api.designflow.app/api/core"),
                ("service", "production"),
                ("schema_version", True),
                ("extra", "unreviewed"),
            ]:
                with self.subTest(field=field, scope=declaration["scope"]):
                    candidate = copy.deepcopy(declaration)
                    candidate[field] = value
                    self.assertEqual(self.validate(candidate), 1)

    def test_recovery_requires_complete_unmixed_profile(self):
        declaration = copy.deepcopy(TARGET.RECOVERY_TARGET)
        del declaration["recovery"]
        self.assertEqual(self.validate(declaration), 1)
        declaration = copy.deepcopy(TARGET.TARGET)
        declaration["routes"] = TARGET.RECOVERY_TARGET["routes"]
        self.assertEqual(self.validate(declaration), 1)

    def test_duplicate_nested_keys_are_refused(self):
        self.path.write_text(json.dumps(TARGET.RECOVERY_TARGET).replace(
            '"maximum_requeues": 1', '"maximum_requeues": 1, "maximum_requeues": 1'))
        with patch("sys.argv", ["validator", str(self.root), "target.json"]):
            self.assertEqual(TARGET.main(), 1)

    def test_symlink_manifest_is_refused(self):
        other = self.root / "other.json"
        other.write_text(json.dumps(TARGET.RECOVERY_TARGET))
        try:
            self.path.symlink_to(other)
        except OSError as error:
            if getattr(error, "winerror", None) == 1314:
                self.skipTest("Windows account lacks symlink creation privilege")
            raise
        with patch("sys.argv", ["validator", str(self.root), "target.json"]):
            self.assertEqual(TARGET.main(), 1)


if __name__ == "__main__":
    unittest.main()
