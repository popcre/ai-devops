"""Validate the one reviewed application-owned HTS sandbox workflow target.

This validates admission metadata, not HTTP execution. The caller must prove
live target identity immediately before requests and retain actual acceptance.
"""
import json
import pathlib
import datetime
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
    if not isinstance(value["issue"], str) or not re.fullmatch(
            r"https://github\.com/popcre/designflow-backend/issues/[1-9][0-9]*", value["issue"]):
        return False
    if not isinstance(value["fixture_prefix"], str) or not re.fullmatch(
            r"AI-QA-[0-9]{8}-[a-z0-9][a-z0-9-]{0,39}-", value["fixture_prefix"]):
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
                     or bounded_acceptance(value, root)) else 1
    except (OSError, ValueError, TypeError, IndexError):
        return 1


if __name__ == "__main__":
    sys.exit(main())
