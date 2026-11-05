"""Offline adversarial tests of the closed HTS retry declaration."""
import copy
import datetime
import importlib.util
import json
import pathlib
import tempfile
import subprocess
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


class BoundedAcceptanceTarget(ClosedRecoveryTarget):
    def setUp(self):
        super().setUp()
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        subprocess.run(["git", "-C", str(self.root), "-c", "user.name=Test",
                        "-c", "user.email=test@example.invalid", "commit", "--allow-empty", "-qm", "base"], check=True)
        head = subprocess.check_output(["git", "-C", str(self.root), "rev-parse", "HEAD"], text=True).strip()
        self.declaration = {
            **copy.deepcopy(TARGET.TARGET),
            "schema_version": 2,
            "scope": "hts-bounded-synthetic-acceptance",
            "issue": "https://github.com/popcre/designflow-backend/issues/123",
            "routes": copy.deepcopy(TARGET.ACCEPTANCE_ROUTES),
            "limits": copy.deepcopy(TARGET.ACCEPTANCE_LIMITS),
            "fixture_prefix": "AI-QA-20261105-acceptance-",
            "source_head": head,
            "expires_at": self.expiry(hours=1),
        }

    @staticmethod
    def expiry(**delta):
        return (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(**delta)).strftime("%Y-%m-%dT%H:%M:%SZ")

    def test_bounded_profile_admits_its_source_and_expiry(self):
        self.assertEqual(self.validate(self.declaration), 0)

    def test_expired_distant_and_malformed_expiry_refused(self):
        for expiry in [self.expiry(seconds=-1), self.expiry(hours=25), "never", True,
                       "2026-02-30T12:00:00Z", self.expiry(hours=1).replace("Z", "+00:00")]:
            with self.subTest(expiry=expiry):
                self.assertEqual(self.validate({**self.declaration, "expires_at": expiry}), 1)

    def test_source_must_be_an_existing_ancestor_not_an_argument(self):
        for head in ["f" * 40, "HEAD", "--help", True, "A" * 40]:
            with self.subTest(head=head):
                self.assertEqual(self.validate({**self.declaration, "source_head": head}), 1)

    def test_ambient_git_context_cannot_redirect_source_check(self):
        with patch.dict("os.environ", {"GIT_DIR": str(self.root / "absent"), "GIT_WORK_TREE": str(self.root / "absent")}):
            self.assertEqual(self.validate(self.declaration), 0)

    def test_every_limit_and_safety_boolean_is_closed_and_type_strict(self):
        for name, original in TARGET.ACCEPTANCE_LIMITS.items():
            changes = [not original, 0] if isinstance(original, bool) else [original + 1, float(original), True, 0]
            for changed in changes:
                with self.subTest(name=name, value=changed):
                    declaration = copy.deepcopy(self.declaration)
                    declaration["limits"][name] = changed
                    self.assertEqual(self.validate(declaration), 1)

    def test_profile_cannot_expand_scope_or_write_real_records(self):
        for field, value in [
            ("api_origin", "https://api.designflow.app/api/core"),
            ("service", "popcre-core-prod"),
            ("repository", "popcre/other"),
            ("issue", "https://github.com/popcre/other/issues/123"),
            ("issue", "https://github.com/popcre/designflow-backend/issues/0"),
            ("fixture_prefix", "real-item-"),
            ("fixture_prefix", "AI-QA-20261105-../"),
            ("routes", self.declaration["routes"] + ["POST /api/hts-rag/jobs/:id/apply"]),
            ("routes", ["POST /arbitrary"]),
            ("forbidden", []),
            ("extra", "allow"),
            ("schema_version", True),
        ]:
            with self.subTest(field=field):
                self.assertEqual(self.validate({**self.declaration, field: value}), 1)

    def test_missing_fields_and_duplicate_limits_refused(self):
        for field in self.declaration:
            candidate = copy.deepcopy(self.declaration)
            del candidate[field]
            self.assertEqual(self.validate(candidate), 1)
        self.path.write_text(json.dumps(self.declaration).replace(
            '"maximum_fixtures": 2', '"maximum_fixtures": 2, "maximum_fixtures": 2'))
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


class BoundedLegacyProofTarget(BoundedAcceptanceTarget):
    def setUp(self):
        super().setUp()
        self.declaration.update({
            "schema_version": 3,
            "scope": "hts-bounded-synthetic-legacy-proof",
            "routes": copy.deepcopy(TARGET.LEGACY_PROOF_ROUTES),
            "limits": copy.deepcopy(TARGET.LEGACY_PROOF_LIMITS),
            "legacy_proof": {**TARGET.LEGACY_PROOF_BOUNDS,
                             "description_prefix": self.declaration["fixture_prefix"]},
        })

    def test_legacy_bounds_are_exact_and_type_strict(self):
        for name, original in self.declaration["legacy_proof"].items():
            changes = [True, None, "unreviewed"]
            if type(original) in (int, float):
                changes += [original + 1, 0]
            for changed in changes:
                if type(changed) is type(original) and changed == original:
                    continue
                with self.subTest(name=name, value=changed):
                    candidate = copy.deepcopy(self.declaration)
                    candidate["legacy_proof"][name] = changed
                    self.assertEqual(self.validate(candidate), 1)

    def test_no_generic_chat_shadow_or_fixture_mutation_routes(self):
        for route in ["POST /api/openrouter/chat", "POST /api/hts-rag/classify",
                      "POST /createRfqItem", "POST /updateRfqItem", "POST /arbitrary"]:
            candidate = copy.deepcopy(self.declaration)
            candidate["routes"].append(route)
            self.assertEqual(self.validate(candidate), 1)

    def test_new_total_bounds_cannot_expand_or_change_type(self):
        for name in ("maximum_total_provider_turns", "maximum_total_cost_usd",
                     "maximum_new_fixtures", "maximum_new_containers"):
            for changed in [True, None, -1, self.declaration["limits"][name] + 1]:
                candidate = copy.deepcopy(self.declaration)
                candidate["limits"][name] = changed
                self.assertEqual(self.validate(candidate), 1)
        candidate = copy.deepcopy(self.declaration)
        candidate["legacy_proof"]["maximum_output_tokens"] = 512.0
        self.assertEqual(self.validate(candidate), 1)

    def test_profiles_cannot_mix_and_prefix_must_match(self):
        for field, value in [("schema_version", 2),
                             ("scope", "hts-bounded-synthetic-acceptance"),
                             ("routes", TARGET.ACCEPTANCE_ROUTES)]:
            self.assertEqual(self.validate({**self.declaration, field: value}), 1)
        candidate = copy.deepcopy(self.declaration)
        candidate["legacy_proof"]["description_prefix"] = "AI-QA-20261105-other-"
        self.assertEqual(self.validate(candidate), 1)


class BoundedLegacyEnvelopeTarget(BoundedLegacyProofTarget):
    def setUp(self):
        super().setUp()
        self.declaration.update(
            schema_version=4,
            scope="hts-bounded-synthetic-legacy-envelope-proof",
            prior_usage={"provider_calls": 2, "actual_cost_usd": 0.02,
                         "snapshot_sha256": "a" * 64,
                         "source": "session-provider-usage-verified"},
            limits={**copy.deepcopy(TARGET.LEGACY_PROOF_LIMITS),
                    "maximum_total_provider_turns": 11,
                    "maximum_provider_turns_per_fixture": 11,
                    "maximum_total_cost_usd": 10},
            legacy_proof={**TARGET.LEGACY_ENVELOPE_BOUNDS,
                          "description_prefix": self.declaration["fixture_prefix"]},
        )

    def test_aggregate_is_exactly_verified_prior_plus_nine_not_http_count(self):
        self.assertEqual(self.validate(self.declaration), 0)
        for field in ["maximum_total_provider_turns", "maximum_provider_turns_per_fixture"]:
            for value in [1, 3, 9, 10, 12, 11.0, True]:
                candidate = copy.deepcopy(self.declaration)
                candidate["limits"][field] = value
                self.assertEqual(self.validate(candidate), 1)

    def test_prior_usage_requires_complete_typed_hash_bound_receipt_declaration(self):
        for field, values in {
            "provider_calls": [-1, True, 2.0, "2", None],
            "actual_cost_usd": [-0.1, True, "0.02", None, float("nan"), float("inf"), 10 ** 1000],
            "snapshot_sha256": ["unknown", "A" * 64, True, None],
            "source": ["estimated", "client-reported", None],
        }.items():
            for value in values:
                with self.subTest(field=field, value=value):
                    candidate = copy.deepcopy(self.declaration)
                    candidate["prior_usage"][field] = value
                    self.assertEqual(self.validate(candidate), 1)
        for field in self.declaration["prior_usage"]:
            candidate = copy.deepcopy(self.declaration)
            del candidate["prior_usage"][field]
            self.assertEqual(self.validate(candidate), 1)

    def test_cumulative_ten_dollar_cap_reserves_the_full_request_upper_risk(self):
        candidate = copy.deepcopy(self.declaration)
        candidate["prior_usage"]["actual_cost_usd"] = 6.77
        self.assertEqual(self.validate(candidate), 0)
        for prior in [6.770001, 9.99, 10]:
            candidate["prior_usage"]["actual_cost_usd"] = prior
            self.assertEqual(self.validate(candidate), 1)

    def test_old_version_cannot_claim_the_larger_internal_envelope(self):
        self.assertEqual(self.validate({**self.declaration, "schema_version": 3}), 1)
        candidate = copy.deepcopy(self.declaration)
        candidate["prior_usage"]["extra"] = "unreviewed"
        self.assertEqual(self.validate(candidate), 1)


class FrozenEvaluationTarget(ClosedRecoveryTarget):
    def setUp(self):
        super().setUp()
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        subprocess.run(["git", "-C", str(self.root), "-c", "user.name=Test",
                        "-c", "user.email=test@example.invalid", "commit", "--allow-empty", "-qm", "base"], check=True)
        head = subprocess.check_output(["git", "-C", str(self.root), "rev-parse", "HEAD"], text=True).strip()
        self.declaration = {
            **copy.deepcopy(TARGET.TARGET), "schema_version": 5,
            "issue": "https://github.com/popcre/designflow-backend/issues/278",
            "scope": "hts-frozen-r9-diagnostic-evaluation", "routes": TARGET.FROZEN_ROUTES,
            "frozen": {"membership_sha256": TARGET.FROZEN_HASH, "maximum_items": 83,
                       "common_ledger": "git-common-dir:hts-r9-frozen-live-eval.json",
                       "single_run": True, "resume_existing_only": True},
            "limits": {**TARGET.FROZEN_LIMITS, "maximum_session_provider_calls": 8237,
                       "minimum_start_credit_usd": 8.75},
            "provider": TARGET.FROZEN_PROVIDER,
            "executor": "scripts/hts-live-holdout-eval.js",
            "prior_usage": {"reported_provider_calls": 5, "provider_calls_upper_bound": 20,
                            "accounted_cost_usd": 0.25, "unobserved_cost_reserve_usd": 1,
                            "budget_baseline_usd": 1.25, "snapshot_sha256": "a" * 64,
                            "source": "session-provider-exposure-verified"},
            "bindings": {key: "b" * 64 for key in TARGET.FROZEN_BINDINGS},
            "source_head": head, "served_source": "c" * 40,
            "served_revision": "popcre-albert-core-sandbox-00001-test",
            "expires_at": BoundedAcceptanceTarget.expiry(hours=1),
        }

    def test_exact_real_cohort_profile_admitted_without_synthetic_relabeling(self):
        self.assertEqual(self.validate(self.declaration), 0)
        self.assertNotIn("fixture_prefix", self.declaration)
        self.assertFalse(self.declaration["limits"]["hard_cost_ceiling"])

    def test_frozen_lifetime_is_bounded_to_72_hours_without_renewal(self):
        now = datetime.datetime(2026, 11, 5, 12, tzinfo=datetime.timezone.utc)
        class FixedDatetime(datetime.datetime):
            @classmethod
            def now(cls, tz=None):
                return now
        with patch.object(TARGET.datetime, "datetime", FixedDatetime):
            for seconds, expected in [(72 * 3600, 0), (72 * 3600 + 1, 1), (0, 1)]:
                expiry = (now + datetime.timedelta(seconds=seconds)).strftime("%Y-%m-%dT%H:%M:%SZ")
                self.assertEqual(self.validate({**self.declaration, "expires_at": expiry}), expected)

    def test_every_frozen_binding_is_required_and_typed(self):
        for key in TARGET.FROZEN_BINDINGS:
            for bad in [None, True, "x" * 64, "A" * 64, "a" * 63]:
                candidate = copy.deepcopy(self.declaration)
                candidate["bindings"][key] = bad
                self.assertEqual(self.validate(candidate), 1)
            candidate = copy.deepcopy(self.declaration)
            del candidate["bindings"][key]
            self.assertEqual(self.validate(candidate), 1)

    def test_routes_and_frozen_membership_cannot_be_broadened(self):
        for field, bad in [("membership_sha256", "a" * 64), ("maximum_items", 84),
                           ("single_run", False), ("resume_existing_only", False),
                           ("common_ledger", "/tmp/new-ledger")]:
            candidate = copy.deepcopy(self.declaration)
            candidate["frozen"][field] = bad
            self.assertEqual(self.validate(candidate), 1)
        for route in ["POST /api/hts-rag/jobs/:id/answer", "PUT /api/hts-rag/items/:id/facts", "POST /addRfqItem"]:
            self.assertEqual(self.validate({**self.declaration, "routes": TARGET.FROZEN_ROUTES + [route]}), 1)

    def test_observed_stop_is_distinct_from_exposure_and_dynamic_credit(self):
        for field, bad in [("maximum_session_provider_calls", 7470),
                           ("minimum_start_credit_usd", 42.27), ("minimum_start_credit_usd", 10),
                           ("maximum_authorized_exposure_usd", 10), ("hard_cost_ceiling", True),
                           ("maximum_inflight_inquiries", 2), ("owner_answers", True),
                           ("maximum_provider_calls_per_inquiry", 9), ("maximum_attempts_per_job", 1),
                           ("cost_basis", "provider-invoice"), ("compression_billing", "included"),
                           ("item_writes", True), ("learning", True), ("ambiguous_post_retry", True)]:
            candidate = copy.deepcopy(self.declaration)
            candidate["limits"][field] = bad
            self.assertEqual(self.validate(candidate), 1)

    def test_unknown_prior_or_zero_remaining_credit_is_refused(self):
        for key, bad in [("reported_provider_calls", True), ("reported_provider_calls", -1),
                         ("reported_provider_calls", 21), ("provider_calls_upper_bound", True),
                         ("provider_calls_upper_bound", -1), ("provider_calls_upper_bound", 10**1000),
                         ("accounted_cost_usd", True), ("accounted_cost_usd", -1),
                         ("accounted_cost_usd", 10**1000),
                         ("accounted_cost_usd", float("nan")), ("accounted_cost_usd", float("inf")),
                         ("unobserved_cost_reserve_usd", True), ("unobserved_cost_reserve_usd", -1),
                         ("unobserved_cost_reserve_usd", float("inf")),
                         ("budget_baseline_usd", True), ("budget_baseline_usd", 10),
                         ("budget_baseline_usd", 9.999999999), ("budget_baseline_usd", 0.25),
                         ("snapshot_sha256", "unverified"), ("source", "estimated")]:
            candidate = copy.deepcopy(self.declaration)
            candidate["prior_usage"][key] = bad
            self.assertEqual(self.validate(candidate), 1)

    def test_exposure_receipt_is_exact_and_never_relabels_reported_usage_as_total(self):
        for key in self.declaration["prior_usage"]:
            candidate = copy.deepcopy(self.declaration)
            del candidate["prior_usage"][key]
            self.assertEqual(self.validate(candidate), 1)
        for prior in [
                {"provider_calls": 5, "actual_cost_usd": 0.25,
                 "snapshot_sha256": "a" * 64, "source": "session-provider-usage-verified"},
                {**self.declaration["prior_usage"], "extra": "unreviewed"}]:
            self.assertEqual(self.validate({**self.declaration, "prior_usage": prior}), 1)

    def test_budget_baseline_binds_sum_and_positive_remaining_credit(self):
        for accounted, reserve, baseline in [(0.25, 1, 0.25), (9, 1, 10),
                                               (1e308, 1e308, 1e308), (9.999999999, 0, 10)]:
            candidate = copy.deepcopy(self.declaration)
            candidate["prior_usage"].update(accounted_cost_usd=accounted,
                unobserved_cost_reserve_usd=reserve, budget_baseline_usd=baseline)
            self.assertEqual(self.validate(candidate), 1)

    def test_identity_expiry_provider_and_old_profile_guards_remain_closed(self):
        for key, bad in [("served_source", "HEAD"), ("served_revision", "production"),
                         ("source_head", "f" * 40), ("expires_at", BoundedAcceptanceTarget.expiry(seconds=-1)),
                         ("issue", "https://github.com/popcre/designflow-backend/issues/94"),
                         ("fixture_prefix", "AI-QA-20261105-fake-"), ("schema_version", 4)]:
            self.assertEqual(self.validate({**self.declaration, key: bad}), 1)
        candidate = copy.deepcopy(self.declaration)
        candidate["provider"]["model"] = "unapproved-model"
        self.assertEqual(self.validate(candidate), 1)


class FrozenOperationalContinuationTarget(FrozenEvaluationTarget):
    def setUp(self):
        super().setUp()
        self.declaration.update(schema_version=6, scope="hts-frozen-r9-operational-continuation")
        self.declaration["operational_continuation"] = {
            "purpose": "pre-provider-immutable-input-repair", "receipt_sha256": "1" * 64,
            "original_ledger_sha256": "2" * 64, "original_admission_sha256": "3" * 64,
            "original_manifest_sha256": "4" * 64, "original_readiness_sha256": "5" * 64,
            "original_runner_sha256": "6" * 64, "original_served_source": "d" * 40,
            "original_served_revision": "popcre-albert-core-sandbox-00000-original",
            "original_served_digest": "sha256:" + "7" * 64,
            "original_expires_at": self.declaration["expires_at"], "original_schema_version": 5,
        }

    def test_frozen_lifetime_is_bounded_to_72_hours_without_renewal(self):
        # The existing v5 72-hour boundary tests remain unchanged. V6 additionally
        # requires the original expiry, rather than granting another lifetime.
        for key in ("expires_at", "original_expires_at"):
            candidate = copy.deepcopy(self.declaration)
            if key == "expires_at":
                candidate[key] = BoundedAcceptanceTarget.expiry(hours=2)
            else:
                candidate["operational_continuation"][key] = BoundedAcceptanceTarget.expiry(hours=2)
            self.assertEqual(self.validate(candidate), 1)
        candidate = copy.deepcopy(self.declaration)
        candidate["expires_at"] = candidate["operational_continuation"]["original_expires_at"] = BoundedAcceptanceTarget.expiry(hours=73)
        self.assertEqual(self.validate(candidate), 1)

    def test_every_original_epoch_binding_is_required_and_typed(self):
        for key in self.declaration["operational_continuation"]:
            candidate = copy.deepcopy(self.declaration)
            del candidate["operational_continuation"][key]
            self.assertEqual(self.validate(candidate), 1)
            for bad in (None, True, [], {}):
                candidate = copy.deepcopy(self.declaration)
                candidate["operational_continuation"][key] = bad
                self.assertEqual(self.validate(candidate), 1)

    def test_original_hash_source_and_digest_bindings_reject_malformed_values(self):
        for key in ("receipt_sha256", "original_ledger_sha256", "original_admission_sha256",
                    "original_manifest_sha256", "original_readiness_sha256", "original_runner_sha256"):
            for bad in ("A" * 64, "a" * 63, "x" * 64):
                candidate = copy.deepcopy(self.declaration)
                candidate["operational_continuation"][key] = bad
                self.assertEqual(self.validate(candidate), 1)
        for key, bad in (("original_served_source", "HEAD"), ("original_served_source", "A" * 40),
                         ("original_served_revision", "production"), ("original_served_digest", "7" * 64)):
            candidate = copy.deepcopy(self.declaration)
            candidate["operational_continuation"][key] = bad
            self.assertEqual(self.validate(candidate), 1)

    def test_no_chaining_general_failure_exception_or_failed_retry(self):
        for key, bad in (("original_schema_version", 6), ("original_schema_version", 5.0),
                         ("purpose", "any-operational-error"), ("maximum_transitions", 2),
                         ("retry_failed_inquiry", True), ("reset_ledger", True)):
            candidate = copy.deepcopy(self.declaration)
            candidate["operational_continuation"][key] = bad
            self.assertEqual(self.validate(candidate), 1)
        candidate = copy.deepcopy(self.declaration)
        candidate["routes"] += ["POST /api/hts-rag/jobs/:id/retry"]
        self.assertEqual(self.validate(candidate), 1)

    def test_new_runner_and_source_are_required(self):
        for key, value in (("original_runner_sha256", self.declaration["bindings"]["runner_sha256"]),
                           ("original_served_source", self.declaration["served_source"])):
            candidate = copy.deepcopy(self.declaration)
            candidate["operational_continuation"][key] = value
            self.assertEqual(self.validate(candidate), 1)
        for bad in (None, True, [], "not-bindings"):
            self.assertEqual(self.validate({**self.declaration, "bindings": bad}), 1)

    def test_schema_scope_and_original_v5_are_not_mixed(self):
        for key, bad in (("schema_version", 6.0), ("schema_version", True),
                         ("scope", "hts-frozen-r9-diagnostic-evaluation")):
            self.assertEqual(self.validate({**self.declaration, key: bad}), 1)
        original = copy.deepcopy(self.declaration)
        original.update(schema_version=5, scope="hts-frozen-r9-diagnostic-evaluation")
        self.assertEqual(self.validate(original), 1)
        del original["operational_continuation"]
        self.assertEqual(self.validate(original), 0)


class FrozenJsonLiteralContinuationTarget(FrozenOperationalContinuationTarget):
    def setUp(self):
        super().setUp()
        self.declaration.update(schema_version=7, scope="hts-frozen-r9-json-literal-operational-continuation")
        self.declaration["operational_continuation"].update(
            purpose="pre-snapshot-json-literal-bind-repair", original_schema_version=6)

    def test_no_chaining_general_failure_exception_or_failed_retry(self):
        for key, bad in (("original_schema_version", 5), ("original_schema_version", 7),
                         ("original_schema_version", 6.0), ("purpose", "pre-provider-immutable-input-repair"),
                         ("purpose", "any-operational-error"), ("maximum_transitions", 3),
                         ("retry_failed_inquiry", True), ("reset_ledger", True)):
            candidate = copy.deepcopy(self.declaration)
            candidate["operational_continuation"][key] = bad
            self.assertEqual(self.validate(candidate), 1)
        candidate = copy.deepcopy(self.declaration)
        candidate["routes"] += ["POST /api/hts-rag/jobs/:id/retry"]
        self.assertEqual(self.validate(candidate), 1)

    def test_schema_scope_and_original_v5_are_not_mixed(self):
        for key, bad in (("schema_version", 7.0), ("schema_version", True),
                         ("schema_version", 6), ("scope", "hts-frozen-r9-operational-continuation")):
            self.assertEqual(self.validate({**self.declaration, key: bad}), 1)
        original = copy.deepcopy(self.declaration)
        original.update(schema_version=5, scope="hts-frozen-r9-diagnostic-evaluation")
        self.assertEqual(self.validate(original), 1)
        del original["operational_continuation"]
        self.assertEqual(self.validate(original), 0)


class FrozenPrepackIdentityContinuationTarget(FrozenJsonLiteralContinuationTarget):
    def setUp(self):
        super().setUp()
        self.declaration.update(schema_version=8, scope="hts-frozen-r9-prepack-identity-operational-continuation")
        self.declaration["operational_continuation"].update(
            purpose="prepack-item-identity-join-repair", original_schema_version=7)

    def test_no_chaining_general_failure_exception_or_failed_retry(self):
        for key, bad in (("original_schema_version", 5), ("original_schema_version", 6),
                         ("original_schema_version", 8), ("original_schema_version", 7.0),
                         ("purpose", "pre-snapshot-json-literal-bind-repair"),
                         ("purpose", "pre-provider-immutable-input-repair"),
                         ("purpose", "any-operational-error"), ("maximum_transitions", 4),
                         ("retry_failed_inquiry", True), ("reset_ledger", True)):
            candidate = copy.deepcopy(self.declaration)
            candidate["operational_continuation"][key] = bad
            self.assertEqual(self.validate(candidate), 1)
        candidate = copy.deepcopy(self.declaration)
        candidate["routes"] += ["POST /api/hts-rag/jobs/:id/retry"]
        self.assertEqual(self.validate(candidate), 1)

    def test_schema_scope_and_original_v5_are_not_mixed(self):
        for key, bad in (("schema_version", 8.0), ("schema_version", True),
                         ("schema_version", 7), ("scope", "hts-frozen-r9-json-literal-operational-continuation")):
            self.assertEqual(self.validate({**self.declaration, key: bad}), 1)
        original = copy.deepcopy(self.declaration)
        original.update(schema_version=5, scope="hts-frozen-r9-diagnostic-evaluation")
        self.assertEqual(self.validate(original), 1)
        del original["operational_continuation"]
        self.assertEqual(self.validate(original), 0)



class DiagnosticMetadataCloseout(unittest.TestCase):
    validate = ClosedRecoveryTarget.validate

    def setUp(self):
        ClosedRecoveryTarget.setUp(self)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        subprocess.run(["git", "-C", str(self.root), "-c", "user.name=Test", "-c",
                        "user.email=test@example.invalid", "commit", "--allow-empty", "-qm", "fixture"], check=True)
        head = subprocess.check_output(["git", "-C", str(self.root), "rev-parse", "HEAD"], text=True).strip()
        self.value = {**copy.deepcopy(TARGET.TARGET), "schema_version": 9,
            "issue": "https://github.com/popcre/designflow-backend/issues/278",
            "scope": "hts-frozen-r9-diagnostic-metadata-closeout",
            "routes": ["POST /api/hts-rag/jobs/diagnostic-tags"],
            "executor": "scripts/hts-diagnostic-inquiry-tags.js",
            "authority": "verified-admin-single-stored-owner-sandbox-only",
            "scenario": "evaluation-mark", "snapshot_state": "captured",
            "limits": {**TARGET.DIAGNOSTIC_TAG_COMMON_LIMITS, **TARGET.DIAGNOSTIC_TAG_SCENARIOS["evaluation-mark"]},
            "forbidden": TARGET.TARGET["forbidden"] + ["provider-call", "new-inquiry", "answer", "retry"],
            "source_head": head, "served_source": head,
            "served_revision": "popcre-albert-core-sandbox-synthetic",
            "served_digest": "sha256:" + "a" * 64,
            "expires_at": (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "target_count": 2,
            "bindings": {key: "b" * 64 for key in TARGET.DIAGNOSTIC_TAG_BINDINGS}}

    def test_exact_zero_provider_metadata_only_target(self):
        self.assertEqual(self.validate(self.value), 0)

    def test_scenarios_are_closed_and_honest(self):
        for scenario, limits in TARGET.DIAGNOSTIC_TAG_SCENARIOS.items():
            value = copy.deepcopy(self.value)
            value.update(scenario=scenario, limits={**TARGET.DIAGNOSTIC_TAG_COMMON_LIMITS, **limits})
            value["target_count"] = 1
            if scenario == "inspect":
                value["snapshot_state"] = "not-yet-captured"
                value["bindings"]["snapshot_sha256"] = None
            self.assertEqual(self.validate(value), 0)
            for key in ["maximum_state_changes", "maximum_metadata_reads", "state_sequence"]:
                bad = copy.deepcopy(value); bad["limits"][key] = None
                self.assertEqual(self.validate(bad), 1)
            if scenario == "synthetic-roundtrip":
                value["target_count"] = 2
                self.assertEqual(self.validate(value), 1)
        value = copy.deepcopy(self.value); value["scenario"] = "arbitrary"
        self.assertEqual(self.validate(value), 1)
        value = copy.deepcopy(self.value); value["snapshot_state"] = "not-yet-captured"
        self.assertEqual(self.validate(value), 1)

    def test_count_is_strict_and_bounded(self):
        for count in [0, 84, True, 1.0, "2", None]:
            with self.subTest(count=count):
                value = copy.deepcopy(self.value); value["target_count"] = count
                self.assertEqual(self.validate(value), 1)
        for count in [1, 83]:
            value = copy.deepcopy(self.value); value["target_count"] = count
            self.assertEqual(self.validate(value), 0)

    def test_all_bindings_required_exact_and_private_opaque(self):
        for key in TARGET.DIAGNOSTIC_TAG_BINDINGS:
            for bad in [None, "a" * 63, "A" * 64, "private-id"]:
                value = copy.deepcopy(self.value); value["bindings"][key] = bad
                self.assertEqual(self.validate(value), 1)
            value = copy.deepcopy(self.value); del value["bindings"][key]
            self.assertEqual(self.validate(value), 1)
        value = copy.deepcopy(self.value); value["bindings"]["extra"] = "a" * 64
        self.assertEqual(self.validate(value), 1)

    def test_no_authority_route_or_budget_expansion(self):
        for key, bad in [("schema_version", 8), ("authority", "owner"),
                         ("api_origin", "https://api.designflow.app/api/core"),
                         ("scope", "general-metadata"), ("executor", "other.js"),
                         ("routes", ["POST /api/hts-rag/jobs"]),
                         ("forbidden", [])]:
            value = copy.deepcopy(self.value); value[key] = bad
            self.assertEqual(self.validate(value), 1)
        for key in self.value["limits"]:
            value = copy.deepcopy(self.value); value["limits"][key] = None
            self.assertEqual(self.validate(value), 1)
        value = copy.deepcopy(self.value); value["provider"] = {"model": "anything"}
        self.assertEqual(self.validate(value), 1)

    def test_source_digest_and_expiry_fail_closed(self):
        for key, bad in [("source_head", "f" * 40), ("served_source", "c" * 40),
                         ("served_digest", "mutable:latest"), ("served_revision", "production"),
                         ("expires_at", "2020-01-01T00:00:00Z"),
                         ("expires_at", (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=25)).strftime("%Y-%m-%dT%H:%M:%SZ"))]:
            value = copy.deepcopy(self.value); value[key] = bad
            self.assertEqual(self.validate(value), 1)


if __name__ == "__main__":
    unittest.main()
