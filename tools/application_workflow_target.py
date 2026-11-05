"""Validate the one reviewed application-owned HTS sandbox workflow target.

This validates admission metadata, not HTTP execution. The caller must prove
live target identity immediately before requests and retain actual acceptance.
"""
import json
import pathlib
import datetime
import math
import os
import re
import stat
import subprocess
import sys

TARGET = {
    "schema_version": 1,
    "repository": "popcre/designflow-backend",
    "issue": "https://github.com/popcre/designflow-backend/issues/94",
    "route": "authenticated-application-http",
    "api_origin": "https://api.alsand.designflow.app/api/core",
    "project": "lithe-breaker-323913",
    "region": "us-east4",
    "service": "popcre-albert-core-sandbox",
    "scope": "hts-non-operative-shadow-writes-provider-calls-learning-replay-retrieval",
    "routes": ["POST /api/cross/evidence", "POST /api/hts-rag/precheck-v2",
               "POST /api/hts-rag/shadow-classify",
               "GET /api/hts-rag/history", "GET /api/hts-rag/history/:id/turns"],
    "forbidden": ["sql", "schema", "cloud-mutation", "manual-promotion",
                  "runtime-flag-change", "rfq-apply-save", "production", "merge"],
}

# Preserve the original ordinary declaration. This second closed declaration
# admits one already-existing audited retry and the reads needed to verify it;
# it is not a configurable route allowlist or new administrator grant.
RECOVERY_TARGET = {
    **TARGET,
    "scope": "hts-non-operative-audited-retry-and-live-acceptance",
    "routes": TARGET["routes"] + [
        "GET /api/hts-rag/debate-runs/:id",
        "POST /api/hts-rag/debate-runs/:id/retry",
        "POST /getRFQItemById",
    ],
    "recovery": {
        "debate_run_id": "95d13e95-8901-40c5-8fd3-3fa4f6eb68fd",
        "maximum_requeues": 1,
        "rfq_item_id": 17543,
        "required_status": "dead_letter",
        "required_credit_state": "positive-verified",
        "required_eligible_backlog": 0,
        "before_snapshot": "immutable-full-run-provider-audit",
        "scheduler": "existing-automatic-bounded",
        "manual_drain": False,
    },
}

# This declaration is admission metadata, never an HTTP credential or executor.
# Every write must independently prove that its record is a declared synthetic
# fixture. Existing business records are read-only under this profile.
ACCEPTANCE_ROUTES = [
    "GET /api/hts-rag/facts/dictionary",
    "GET /api/hts-rag/items/:itemRef/facts",
    "PUT /api/hts-rag/items/:itemRef/facts",
    "GET /api/hts-rag/jobs/:id",
    "POST /api/hts-rag/jobs",
    "POST /api/hts-rag/jobs/:id/answer",
    "GET /getRFQGroup",
    "POST /addNewRFQGroup",
    "POST /addRfqItem",
    "POST /archiveRFQItem",
    "POST /getRFQItemById",
]
ACCEPTANCE_LIMITS = {
    "synthetic_only": True,
    "existing_records_read_only": True,
    "maximum_fixtures": 2,
    "maximum_containers": 1,
    "maximum_provider_turns_per_fixture": 3,
    "maximum_total_cost_usd": 10,
    "send_messages": False,
    "apply_classifications": False,
}

# A separate, tighter profile for one synthetic legacy-provider proof. It adds
# no fixture writes, general chat, alternate provider, or arbitrary HTTP route.
LEGACY_PROOF_ROUTES = [
    "GET /api/hts-rag/runtime-config",
    "GET /api/hts-rag/jobs/:id",
    "GET /getRFQGroup",
    "POST /getRFQItemById",  # Existing read-only application operation.
    "POST /api/openrouter/hts-classify",
]
LEGACY_PROOF_LIMITS = {
    **ACCEPTANCE_LIMITS,
    "maximum_total_provider_turns": 3,
    "maximum_total_cost_usd": 0.10,
    "maximum_new_fixtures": 0,
    "maximum_new_containers": 0,
}
LEGACY_PROOF_BOUNDS = {
    "maximum_calls": 1,
    "maximum_output_tokens": 512,
    "maximum_cost_usd": 0.10,
    "automatic_retry": False,
    "required_actual_model": "openai/gpt-6-luna-20260922",
    "required_actual_api": "openrouter",
    "required_credit_state": "positive-live-binding-verified",
}

# One ordinary HTS HTTP request can contain several bounded internal calls.
# This distinct profile preserves v3 rather than relabeling HTTP as inference.
LEGACY_ENVELOPE_BOUNDS = {
    **LEGACY_PROOF_BOUNDS,
    "maximum_output_tokens": 4096,
    "maximum_cost_usd": 3.23,
    "maximum_internal_provider_calls": 9,
    "model_context_tokens": 1050000,
    "model_max_completion_tokens": 128000,
    "provider_retry": False,
    "billable_tools": False,
    "separate_preprocessing_requests": False,
}


def bounded_legacy_envelope(value, root):
    """Verified prior usage plus one fixed inference envelope; no executor."""
    if not isinstance(value, dict):
        return False
    prior = value.get("prior_usage")
    if not isinstance(prior, dict) or prior.keys() != {
            "provider_calls", "actual_cost_usd", "snapshot_sha256", "source"}:
        return False
    calls, cost = prior["provider_calls"], prior["actual_cost_usd"]
    if (type(calls) is not int or calls < 0
            or type(cost) not in (int, float) or cost < 0 or cost > 6.77
            or not math.isfinite(cost)
            or prior["source"] != "session-provider-usage-verified"
            or not isinstance(prior["snapshot_sha256"], str)
            or not re.fullmatch(r"[0-9a-f]{64}", prior["snapshot_sha256"])):
        return False
    aggregate = calls + LEGACY_ENVELOPE_BOUNDS["maximum_internal_provider_calls"]
    dynamic = {"issue", "source_head", "expires_at", "fixture_prefix", "prior_usage"}
    expected = {
        **TARGET,
        "schema_version": 4,
        "scope": "hts-bounded-synthetic-legacy-envelope-proof",
        "routes": LEGACY_PROOF_ROUTES,
        "limits": {**LEGACY_PROOF_LIMITS,
                   "maximum_total_provider_turns": aggregate,
                   "maximum_provider_turns_per_fixture": aggregate,
                   "maximum_total_cost_usd": 10},
        "legacy_proof": {**LEGACY_ENVELOPE_BOUNDS,
                         "description_prefix": value.get("fixture_prefix")},
    }
    if value.keys() != expected.keys() | dynamic:
        return False
    if not exact({key: value[key] for key in expected if key != "issue"},
                 {key: item for key, item in expected.items() if key != "issue"}):
        return False
    return bounded_metadata(value, root)


def bounded_acceptance(value, root):
    """A clean, expiring source-pinned declaration with no configurable routes."""
    if not isinstance(value, dict):
        return False
    dynamic = {"issue", "source_head", "expires_at", "fixture_prefix"}
    expected = {
        **TARGET,
        "schema_version": 2,
        "scope": "hts-bounded-synthetic-acceptance",
        "routes": ACCEPTANCE_ROUTES,
        "limits": ACCEPTANCE_LIMITS,
    }
    if value.keys() != expected.keys() | dynamic:
        return False
    if not exact({key: value[key] for key in expected if key != "issue"},
                 {key: item for key, item in expected.items() if key != "issue"}):
        return False
    return bounded_metadata(value, root)


def bounded_legacy_proof(value, root):
    """One fixed legacy route, no new records, and a matching synthetic prefix."""
    if not isinstance(value, dict):
        return False
    dynamic = {"issue", "source_head", "expires_at", "fixture_prefix"}
    expected = {
        **TARGET,
        "schema_version": 3,
        "scope": "hts-bounded-synthetic-legacy-proof",
        "routes": LEGACY_PROOF_ROUTES,
        "limits": LEGACY_PROOF_LIMITS,
        "legacy_proof": {**LEGACY_PROOF_BOUNDS,
                         "description_prefix": value.get("fixture_prefix")},
    }
    if value.keys() != expected.keys() | dynamic:
        return False
    if not exact({key: value[key] for key in expected if key != "issue"},
                 {key: item for key, item in expected.items() if key != "issue"}):
        return False
    return bounded_metadata(value, root)


FROZEN_HASH = "8d98654f9729f40e60ffe064fee26c5f4673d3e5c4f7870872463f28262b30df"
FROZEN_ROUTES = ["POST /api/hts-rag/jobs", "GET /api/hts-rag/jobs/:id"]
FROZEN_BINDINGS = {"input_sha256", "readiness_sha256", "qualification_sha256",
                   "prior_spend_sha256", "provenance_sha256", "runner_sha256",
                   "catalog_sha256", "pricing_sha256"}
FROZEN_LIMITS = {
    "maximum_initial_inquiries": 83, "maximum_inflight_inquiries": 1,
    "maximum_record_auto_answers": 2, "maximum_attempts_per_job": 3,
    "maximum_provider_calls_per_inquiry": 90, "maximum_run_provider_calls": 7470,
    "owner_answers": 0, "maximum_person_answers_for_scoring": 3,
    "observed_session_stop_usd": 10, "inflight_overshoot_reserve_usd": 32.265,
    "maximum_authorized_exposure_usd": 42.27, "hard_cost_ceiling": False,
    "cost_basis": "luna-application-accounted-approved-rates",
    "compression_billing": "unquantified-not-included",
    "apply_classifications": False, "item_writes": False, "learning": False,
    "ambiguous_post_retry": False, "provider_http_retry": False,
    "send_messages": False,
}
FROZEN_PROVIDER = {
    "model": "openai/gpt-6-luna-20260922", "api": "openrouter",
    "reasoning_effort": "high", "rulings_only": True,
    "model_context_tokens": 1050000, "model_max_completion_tokens": 128000,
    "maximum_approved_input_usd_per_token": 0.00000025,
    "maximum_approved_output_usd_per_token": 0.00000075,
    "billable_tools": False,
}


def frozen_evaluation(value, root):
    """One frozen real-cohort diagnostic declaration, never an executor."""
    if not isinstance(value, dict):
        return False
    prior, bindings = value.get("prior_usage"), value.get("bindings")
    if (not isinstance(prior, dict) or prior.keys() != {
            "provider_calls", "actual_cost_usd", "snapshot_sha256", "source"}
            or not isinstance(bindings, dict) or bindings.keys() != FROZEN_BINDINGS):
        return False
    calls, cost = prior["provider_calls"], prior["actual_cost_usd"]
    if (type(calls) is not int or calls < 0 or calls > 9007199254740991 - 7470 or type(cost) not in (int, float)
            or cost < 0 or cost >= 10 or not math.isfinite(cost)
            or round(10 - cost, 8) <= 0
            or prior["source"] != "session-provider-usage-verified"
            or any(not isinstance(sha, str) or not re.fullmatch(r"[0-9a-f]{64}", sha)
                   for sha in [prior["snapshot_sha256"], *bindings.values()])):
        return False
    revision = value.get("served_revision")
    if not isinstance(revision, str) or not re.fullmatch(r"popcre-albert-core-sandbox-[a-z0-9-]+", revision):
        return False
    if not isinstance(value.get("served_source"), str) or not re.fullmatch(r"[0-9a-f]{40}", value["served_source"]):
        return False
    expected = {
        **TARGET, "schema_version": 5,
        "issue": "https://github.com/popcre/designflow-backend/issues/278",
        "scope": "hts-frozen-r9-diagnostic-evaluation", "routes": FROZEN_ROUTES,
        "frozen": {"membership_sha256": FROZEN_HASH, "maximum_items": 83,
                   "common_ledger": "git-common-dir:hts-r9-frozen-live-eval.json",
                   "single_run": True, "resume_existing_only": True},
        "limits": {**FROZEN_LIMITS, "maximum_session_provider_calls": calls + 7470,
                   "minimum_start_credit_usd": round(10 - cost, 8)},
        "provider": FROZEN_PROVIDER,
        "executor": "scripts/hts-live-holdout-eval.js",
    }
    dynamic = {"source_head", "expires_at", "served_source", "served_revision", "prior_usage", "bindings"}
    if value.keys() != expected.keys() | dynamic or not exact(
            {key: value[key] for key in expected}, expected):
        return False
    return bounded_metadata(value, root, synthetic=False)


def bounded_metadata(value, root, synthetic=True):
    """Shared source, issue, prefix and expiry checks for bounded profiles."""
    if not isinstance(value["issue"], str) or not re.fullmatch(
            r"https://github\.com/popcre/designflow-backend/issues/[1-9][0-9]*", value["issue"]):
        return False
    if synthetic and (not isinstance(value["fixture_prefix"], str) or not re.fullmatch(
            r"AI-QA-[0-9]{8}-[a-z0-9][a-z0-9-]{0,39}-", value["fixture_prefix"])):
        return False
    head = value["source_head"]
    if not isinstance(head, str) or not re.fullmatch(r"[0-9a-f]{40}", head):
        return False
    expiry = value["expires_at"]
    if not isinstance(expiry, str) or not re.fullmatch(
            r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", expiry):
        return False
    try:
        expires = datetime.datetime.strptime(expiry, "%Y-%m-%dT%H:%M:%SZ").replace(
            tzinfo=datetime.timezone.utc)
        now = datetime.datetime.now(datetime.timezone.utc)
        if not datetime.timedelta(0) < expires - now <= datetime.timedelta(hours=24):
            return False
        # Ignore ambient Git routing and replacement-object configuration.
        env = {key: item for key, item in os.environ.items() if not key.startswith("GIT_")}
        result = subprocess.run(
            ["git", "--no-replace-objects", "-C", str(root), "merge-base", "--is-ancestor", head, "HEAD"],
            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10,
            check=False)
        return result.returncode == 0
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return False


def exact(value, expected):
    """JSON equality must not coerce a Boolean or float into a numeric bound."""
    if type(value) is not type(expected):
        return False
    if type(expected) is dict:
        return value.keys() == expected.keys() and all(
            exact(value[key], item) for key, item in expected.items())
    if type(expected) is list:
        return len(value) == len(expected) and all(
            exact(item, wanted) for item, wanted in zip(value, expected))
    return value == expected


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate key")
        result[key] = value
    return result


def main():
    try:
        root = pathlib.Path(sys.argv[1]).resolve(strict=True)
        relative = pathlib.PurePosixPath(sys.argv[2])
        if relative.is_absolute() or ".." in relative.parts:
            return 1
        path = root
        for part in relative.parts:
            path = path / part
            if stat.S_ISLNK(path.lstat().st_mode):
                return 1
        if not stat.S_ISREG(path.lstat().st_mode):
            return 1
        path.resolve(strict=True).relative_to(root)
        value = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique)
        return 0 if (exact(value, TARGET) or exact(value, RECOVERY_TARGET)
                     or bounded_acceptance(value, root)
                     or bounded_legacy_proof(value, root)
                     or bounded_legacy_envelope(value, root)
                     or frozen_evaluation(value, root)) else 1
    except (OSError, ValueError, TypeError, IndexError):
        return 1


if __name__ == "__main__":
    sys.exit(main())
