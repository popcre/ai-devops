#!/usr/bin/env python3
"""Allowlisted invocation evidence, with no provider secrets or raw output."""
import json
import contextlib
import os
import re
from pathlib import Path
import subprocess
import sys
import time
import tempfile
import uuid

from reviewer_maintenance import Blocked, digest, encoded, now, physical, publish, read_json, require, snapshot


def location():
    if os.environ.get("AI_REVIEW_EVENT_DIR"):
        return physical(os.environ["AI_REVIEW_EVENT_DIR"])
    base = os.environ.get("AI_REVIEWER_STATE_BASE") or (os.environ.get("HOME") or str(Path.home())) + "/.local/state/ai-devops"
    return physical(os.environ.get("AI_REVIEW_EVENT_DIR", str(Path(base) / "reviewer-events")))


def git_value(*args):
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else ""


@contextlib.contextmanager
def event_lock(directory):
    """Kernel-owned lock: a dead writer cannot strand all provider wrappers."""
    directory = physical(directory)
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    path = physical(directory / ".append.lock")
    fd = os.open(path, os.O_CREAT | os.O_RDWR, 0o600)
    deadline = time.monotonic() + 10
    acquired = False
    try:
        while not acquired:
            try:
                if os.name == "nt":
                    import msvcrt
                    msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
                else:
                    import fcntl
                    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                acquired = True
            except OSError:
                require(time.monotonic() < deadline, f"event ledger writer is busy: {directory}")
                time.sleep(0.05)
        current = physical(path).stat()
        held = os.fstat(fd)
        require((current.st_dev, current.st_ino) == (held.st_dev, held.st_ino), "event lock was replaced")
        yield
    finally:
        if acquired:
            if os.name == "nt":
                msvcrt.locking(fd, msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)


def append(directory, event):
    with event_lock(directory):
        path = physical(directory / "events.jsonl")
        _, data = snapshot(path, "jsonl")
        rows = [json.loads(line) for line in data.splitlines()]
        require(all(isinstance(row, dict) for row in rows), "invalid event ledger")
        value = event(rows) if callable(event) else event
        if value is None:
            return
        with path.open("ab") as output:
            output.write(encoded(value) + b"\n")
            output.flush()
            os.fsync(output.fileno())


def invocation(directory, provider, run_id, active=False):
    require(re.fullmatch(r"[0-9a-f]{32}", run_id), "invalid invocation identity")
    _, data = snapshot(directory / "events.jsonl", "jsonl")
    rows = [json.loads(line) for line in data.splitlines()]
    require(all(isinstance(row, dict) for row in rows), "invalid event ledger")
    starts = [row for row in rows if row.get("run_id") == run_id and row.get("event") == "started"]
    require(len(starts) == 1 and starts[0].get("provider") == provider,
            "evidence has no unique matching invocation")
    if active:
        require(not any(row.get("run_id") == run_id and row.get("event") == "finished" for row in rows),
                "completed invocation evidence cannot be rewritten")
    return starts[0]


def provenance(value=None):
    result = {"source": "unknown", "actor_class": "unknown", "phase": "unknown",
              "last_proven_provider_state": "unknown", "paid_work_may_exist": None, "signal": None}
    value = value or {}
    require(isinstance(value, dict) and not set(value) - set(result), "unsupported interruption fields")
    result.update(value)
    require(result["source"] in {"unknown", "os-signal", "user-cancellation", "scheduler-interruption",
                                 "timeout", "process-death", "none"}, "invalid interruption source")
    require(result["actor_class"] in {"unknown", "user", "scheduler", "wrapper", "provider", "none"},
            "invalid interruption actor")
    require(result["phase"] in {"unknown", "preflight", "provider-running", "wrapper-running",
                                "wrapper-exit", "report-publication", "cleanup"}, "invalid interruption phase")
    require(result["last_proven_provider_state"] in {"unknown", "not-started", "running", "completed",
                                                     "failed", "cancelled"}, "invalid provider state")
    require(result["paid_work_may_exist"] is None or type(result["paid_work_may_exist"]) is bool,
            "paid-work uncertainty must be explicit")
    require(result["signal"] in {None, "INT", "TERM", "HUP"}, "invalid observed signal")
    return result


def evidence_root(directory, run_id):
    # Keep evidence in the existing private event store, outside disposable repos.
    return physical(directory / "evidence" / run_id)


def require_report(directory, provider, run_id):
    with event_lock(directory):
        start = invocation(directory, provider, run_id, active=True)
        root = evidence_root(directory, run_id)
        value = {"schema_version": 1, "run_id": run_id, "provider": provider,
                 "head": start["head"], "caller": start["caller"]}
        path = root / "required.json"
        if path.exists():
            require(read_json(path) == value, "evidence requirement identity changed")
        else:
            publish(path, value)


def publish_report(directory, provider, run_id, report, facts=None, artifact_key=None):
    # Only a wrapper's prepared UTF-8 report is accepted, never a stream/session
    # directory. The private report is immutable; no response enters the ledger.
    report = physical(report)
    boundary, data = snapshot(report, "log")
    require(boundary["exists"] and (data or artifact_key), "report is missing or empty; source evidence retained")
    current = report.stat()
    require(current.st_size == boundary["offset"] and current.st_mtime_ns == boundary["mtime_ns"],
            "report changed during publication; source evidence retained")
    text = data.decode("utf-8")
    if artifact_key:
        require(not data or data.startswith(b"diff --git "), "artifact is not a prepared Git patch")
    facts = dict(facts or {})
    original_id = facts.pop("original_invocation_id", None)
    recovery_state = facts.pop("recovery_state", None)
    original_head = facts.pop("original_head_sha", None)
    facts = provenance(facts)
    with event_lock(directory):
        start = invocation(directory, provider, run_id, active=True)
        if original_id is not None:
            original = invocation(directory, provider, original_id)
            require(start.get("operation") == "local-finalization" and
                    original_id != run_id and original["caller"] == start["caller"] and
                    physical(original["repo"]) == physical(start["repo"]),
                    "recovered evidence invocation identity changed")
            require((recovery_state is None and original["head"] == start["head"] and original_head is None) or
                    (recovery_state == "completed-stale-source" and original_head == original["head"]),
                    "recovered evidence source identity is unproven")
        else:
            require(recovery_state is None and original_head is None, "recovery source requires original invocation")
        current = report.stat()
        require(current.st_size == boundary["offset"] and current.st_mtime_ns == boundary["mtime_ns"],
                "report changed during publication; source evidence retained")
        root = evidence_root(directory, run_id)
        require((root / "required.json").is_file(), "report publication was not reserved")
        sha = digest(data)
        value = {"schema_version": 1, "run_id": run_id, "provider": provider,
                 "head": start["head"], "caller": start["caller"], "report_sha256": sha,
                 "report_text": text, "provenance": facts, "original_invocation_id": original_id,
                 "recovery_state": recovery_state, "original_head_sha": original_head}
        if artifact_key:
            value.update(artifact_kind="git-binary-patch", artifact_key=artifact_key)
        receipt_id = sha + ("." + artifact_key if artifact_key else "")
        path = root / (receipt_id + ".report.json")
        if path.exists():
            require(read_json(path) == value, "published evidence conflicts with this invocation")
        else:
            publish(path, value)
        # Return an opaque recovery reference, not a source-worktree path.
        return {"reference": run_id + "/" + receipt_id, "report_sha256": sha}


def publish_patch(directory, provider, run_id, path, facts=None):
    # Reserve before reading: even a missing patch must block later cleanup.
    key = digest(str(physical(path)).encode("utf-8"))
    with event_lock(directory):
        invocation(directory, provider, run_id, active=True)
        requirement = {"schema_version": 1, "provider": provider, "run_id": run_id,
                       "artifact_kind": "git-binary-patch", "artifact_key": key}
        target = evidence_root(directory, run_id) / "artifacts" / (key + ".json")
        if target.exists():
            require(read_json(target) == requirement, "artifact requirement changed")
        else:
            publish(target, requirement)
    return publish_report(directory, provider, run_id, path, facts or {"phase": "report-publication"}, key)


def recovered_references(directory, provider, run_id, required_keys):
    candidates = {}
    for candidate in (directory / "evidence").glob("*/*.report.json"):
        row = read_json(physical(candidate))
        if row.get("original_invocation_id") == run_id and row.get("run_id") != run_id:
            candidates.setdefault(row.get("run_id", ""), []).append(row)
    recovered = []
    for owner, rows in candidates.items():
        references = verify_reports(directory, provider, owner)
        linked_keys = {row.get("artifact_key") for row in rows if row.get("artifact_kind") == "git-binary-patch"}
        if required_keys <= linked_keys and any(not row.get("artifact_kind") for row in rows):
            recovered.extend(references)
    return sorted(set(recovered))


def missing_prepared(directory, provider, run_id, references):
    root = evidence_root(directory, run_id)
    receipts = [read_json(directory / "evidence" / (reference + ".report.json")) for reference in references]
    missing = []
    for path in (root / "prepared").glob("*.json"):
        row = read_json(path)
        owner = read_json(root / "owner.json")
        require(row.get("schema_version") == 1 and row.get("provider") == provider and row.get("run_id") == run_id and
                row.get("owner") == owner.get("owner") and row.get("kind") in {"report", "git-binary-patch"} and
                re.fullmatch(r"[0-9a-f]{64}", row.get("sha256", "")) and
                digest(row.get("path", "").encode("utf-8")) == path.stem, "prepared owner artifact identity changed")
        if not any(receipt["report_sha256"] == row["sha256"] and
                   ((row["kind"] == "report" and not receipt.get("artifact_kind")) or
                    (row["kind"] == "git-binary-patch" and receipt.get("artifact_key") == path.stem))
                   for receipt in receipts):
            missing.append(path.stem)
    return missing


def verify_reports(directory, provider, run_id):
    start = invocation(directory, provider, run_id)
    root = evidence_root(directory, run_id)
    if not (root / "required.json").exists():
        return []
    required = read_json(root / "required.json")
    require(required == {"schema_version": 1, "run_id": run_id, "provider": provider,
                         "head": start["head"], "caller": start["caller"]}, "evidence requirement changed")
    paths = sorted(root.glob("*.report.json"))
    references = []
    artifacts = set()
    reports = 0
    for path in paths:
        row = read_json(path)
        require(row.get("schema_version") == 1 and row.get("run_id") == run_id and
                row.get("provider") == provider and row.get("head") == start["head"] and
                row.get("caller") == start["caller"], "published report identity changed")
        kind = row.get("artifact_kind")
        require(kind in {None, "git-binary-patch"}, "published artifact type changed")
        require(isinstance(row.get("report_text"), str) and (row["report_text"] or kind), "published report is empty")
        if kind:
            require(re.fullmatch(r"[0-9a-f]{64}", row.get("artifact_key", "")) and
                    (not row["report_text"] or row["report_text"].startswith("diff --git ")), "published patch identity changed")
            artifacts.add(row["artifact_key"])
        else:
            reports += 1
        sha = digest(row["report_text"].encode("utf-8"))
        receipt_id = sha + ("." + row["artifact_key"] if kind else "")
        require(row.get("report_sha256") == sha and path.name == receipt_id + ".report.json",
                "published report content changed")
        provenance(row.get("provenance"))
        if row.get("original_invocation_id") is not None:
            original = invocation(directory, provider, row["original_invocation_id"])
            require(start.get("operation") == "local-finalization" and
                    row["original_invocation_id"] != run_id and original["caller"] == start["caller"] and
                    physical(original["repo"]) == physical(start["repo"]),
                    "recovered evidence invocation identity changed")
            require((row.get("recovery_state") is None and original["head"] == start["head"] and row.get("original_head_sha") is None) or
                    (row.get("recovery_state") == "completed-stale-source" and row.get("original_head_sha") == original["head"]),
                    "recovered evidence source identity is unproven")
        references.append(run_id + "/" + receipt_id)
    missing_keys = set()
    for path in (root / "artifacts").glob("*.json"):
        row = read_json(path)
        key = path.stem
        require(row == {"schema_version": 1, "provider": provider, "run_id": run_id,
                        "artifact_kind": "git-binary-patch", "artifact_key": key}, "required patch identity changed")
        if key not in artifacts:
            missing_keys.add(key)
    if not reports or missing_keys or missing_prepared(directory, provider, run_id, references):
        # Earlier valid patch receipts remain useful when only the report
        # failed. A local finalizer must supply every still-missing artifact.
        recovered = recovered_references(directory, provider, run_id, missing_keys)
        require(recovered, "required report is not durably published; cleanup and replay refused" if not reports else
                "required patch is not durably published; cleanup refused")
        references = sorted(set(references + recovered))
        require(not missing_prepared(directory, provider, run_id, references), "prepared paid evidence is not durably published; cleanup refused")
        return references
    return references


def sandbox_marker(sandbox):
    marker = physical(Path(sandbox) / ".ai-review-sandbox")
    boundary, data = snapshot(marker, "log")
    require(boundary["exists"] and data, "sandbox ownership marker is unavailable")
    lines = data.decode("utf-8").splitlines()
    require(lines.count("evidence_format=1") == 1,
            "legacy sandbox ownership is unknown; use ai-reviewer-issue evidence reconcile-sandbox PROVIDER SANDBOX METADATA REPORT with exact private evidence")
    owners = []
    for line in lines:
        if line.startswith("evidence_owner="):
            value = line.removeprefix("evidence_owner=")
            require(re.fullmatch(r"[a-z]+:[0-9a-f]{32}", value), "invalid sandbox evidence owner")
            require(value not in owners, "duplicate sandbox evidence owner")
            owners.append(value)
    return marker, boundary, data, lines, owners


def write_sandbox_owner(marker, boundary, data, owner):
    current, current_data = snapshot(marker, "log")
    require(current == boundary and current_data == data, "sandbox ownership changed during binding")
    fd, tmp = tempfile.mkstemp(prefix=".evidence-owner.", dir=marker.parent)
    try:
        with os.fdopen(fd, "wb") as output:
            output.write(data.rstrip(b"\r\n") + b"\n" + owner.encode("ascii") + b"\n")
            output.flush()
            os.fsync(output.fileno())
        current, current_data = snapshot(marker, "log")
        require(current == boundary and current_data == data, "sandbox ownership changed during binding")
        os.replace(tmp, marker)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def bind_sandbox(directory, provider, run_id, sandbox, original_id=None):
    with event_lock(directory):
        start = invocation(directory, provider, run_id, active=True)
        expected_head = start["head"]
        if original_id is not None:
            original = invocation(directory, provider, original_id)
            require(start.get("operation") == "local-finalization" and original_id != run_id and
                    original["caller"] == start["caller"] and physical(original["repo"]) == physical(start["repo"]),
                    "recovered sandbox invocation identity changed")
            expected_head = original["head"]
        marker, boundary, data, lines, owners = sandbox_marker(sandbox)
        require(physical(lines[0]) == physical(start["repo"]), "sandbox evidence source differs from invocation")
        require(git_value("-C", str(marker.parent), "rev-parse", "HEAD") == expected_head,
                "sandbox evidence head differs from invocation")
        require((evidence_root(directory, run_id) / "required.json").is_file(),
                "sandbox evidence requirement was not reserved")
        if original_id is not None:
            require(provider + ":" + original_id in owners,
                    "original paid invocation does not own this sandbox")
            # Local retries do not submit paid work. Keep the original owner's
            # obligation until a validated recovery receipt satisfies it; a
            # failed local render must not create permanent cleanup debt.
            return
        owner = provider + ":" + run_id
        if owner not in owners:
            write_sandbox_owner(marker, boundary, data, "evidence_owner=" + owner)


def verify_sandbox(directory, sandbox):
    with event_lock(directory):
        _, _, _, _, owners = sandbox_marker(sandbox)
        references = []
        for owner in owners:
            provider, run_id = owner.split(":")
            require((evidence_root(directory, run_id) / "required.json").is_file(),
                    "sandbox evidence requirement is missing; cleanup refused")
            references.extend(verify_reports(directory, provider, run_id))
        return references


def owner_identity(owner):
    path = physical(owner)
    boundary, data = snapshot(path, "log")
    require(boundary["exists"] and data, "implementation owner record is missing")
    row = json.loads(data)
    require(isinstance(row, dict), "implementation owner record is invalid")
    repo = row.get("repo") or row.get("repository_root")
    workspace = row.get("worktree") or row.get("clone_path")
    require(repo and workspace, "implementation owner has no exact repository/workspace")
    return path, boundary, data, row, physical(repo), physical(workspace)


def bind_owner(directory, provider, run_id, owner):
    with event_lock(directory):
        start = invocation(directory, provider, run_id, active=True)
        path, boundary, data, row, repo, workspace = owner_identity(owner)
        require(repo == physical(start["repo"]), "implementation owner repository differs from invocation")
        require(row.get("evidence_run_id") in {None, run_id}, "implementation owner already belongs to another invocation")
        identity = {"schema_version": 1, "provider": provider, "run_id": run_id,
                    "owner": str(path), "repository": str(repo), "workspace": str(workspace)}
        identity_path = evidence_root(directory, run_id) / "owner.json"
        if identity_path.exists():
            require(read_json(identity_path) == identity, "implementation evidence binding changed")
        else:
            publish(identity_path, identity)
        row["evidence_run_id"] = run_id
        fd, tmp = tempfile.mkstemp(prefix=".evidence-owner.", dir=path.parent)
        try:
            with os.fdopen(fd, "wb") as output:
                output.write(encoded(row)); output.flush(); os.fsync(output.fileno())
            current, current_data = snapshot(path, "log")
            require(current == boundary and current_data == data, "implementation ownership changed during binding")
            os.replace(tmp, path)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)


def verify_owner(directory, provider, owner, binding_only=False):
    with event_lock(directory):
        path, _, _, row, repo, workspace = owner_identity(owner)
        run_id = row.get("evidence_run_id")
        require(isinstance(run_id, str) and re.fullmatch(r"[0-9a-f]{32}", run_id),
                "legacy implementation ownership has no invocation proof; use ai-reviewer-issue evidence reconcile-owner PROVIDER OWNER METADATA REPORT with exact private evidence")
        start = invocation(directory, provider, run_id)
        identity = read_json(evidence_root(directory, run_id) / "owner.json")
        require(identity == {"schema_version": 1, "provider": provider, "run_id": run_id,
                             "owner": str(path), "repository": str(repo), "workspace": str(workspace)} and
                repo == physical(start["repo"]), "implementation evidence ownership changed")
        return [] if binding_only else verify_reports(directory, provider, run_id)


def prepare_owner_artifact(directory, provider, run_id, owner, kind, artifact):
    require(kind in {"report", "git-binary-patch"}, "invalid prepared owner artifact kind")
    verify_owner(directory, provider, owner, binding_only=True)
    owner_path, owner_boundary, owner_data, row, _, _ = owner_identity(owner)
    require(row["evidence_run_id"] == run_id, "prepared artifact belongs to another owner invocation")
    artifact = physical(artifact)
    boundary, data = snapshot(artifact, "log")
    require(boundary["exists"] and (data or kind == "git-binary-patch"), "prepared owner artifact is missing")
    data.decode("utf-8")
    require(kind != "git-binary-patch" or not data or data.startswith(b"diff --git "), "prepared owner artifact is not a Git patch")
    value = {"schema_version": 1, "provider": provider, "run_id": run_id, "owner": str(owner_path),
             "kind": kind, "path": str(artifact), "sha256": digest(data)}
    key = digest(str(artifact).encode("utf-8"))
    with event_lock(directory):
        invocation(directory, provider, run_id, active=True)
        require((evidence_root(directory, run_id) / "required.json").is_file(), "prepared owner publication was not reserved")
        require(snapshot(owner_path, "log") == (owner_boundary, owner_data), "implementation owner changed during artifact preparation")
        require(snapshot(artifact, "log") == (boundary, data), "prepared owner artifact changed")
        target = evidence_root(directory, run_id) / "prepared" / (key + ".json")
        if target.exists():
            require(read_json(target) == value, "prepared owner artifact conflicts with original bytes")
        else:
            publish(target, value)


def prepared_owner_artifact(directory, provider, run_id, owner, artifact, kind):
    artifact = physical(artifact)
    key = digest(str(artifact).encode("utf-8"))
    value = read_json(evidence_root(directory, run_id) / "prepared" / (key + ".json"))
    _, data = snapshot(artifact, "log")
    require(value == {"schema_version": 1, "provider": provider, "run_id": run_id,
                      "owner": str(physical(owner)), "kind": kind, "path": str(artifact), "sha256": digest(data)},
            "exact prepared owner artifact is unproven or changed")
    return artifact, data


def verify_prepared(directory, provider, run_id, kind, artifact):
    require(kind in {"report", "git-binary-patch"}, "invalid prepared artifact kind")
    references = verify_reports(directory, provider, run_id)
    binding = read_json(evidence_root(directory, run_id) / "owner.json")
    start = invocation(directory, provider, run_id)
    require(binding.get("provider") == provider and binding.get("run_id") == run_id and
            physical(binding.get("repository", "")) == physical(start["repo"]), "prepared artifact original binding changed")
    prepared_owner_artifact(directory, provider, run_id, binding["owner"], artifact, kind)
    return references


def implementation_archive_source(directory, provider, metadata):
    require(provider in {"qwen", "kimi"}, "implementation state archive has no authoritative provider adapter")
    metadata = physical(metadata)
    _, metadata_data = snapshot(metadata, "log")
    meta = json.loads(metadata_data)
    require(isinstance(meta, dict) and meta.get("version") == 2 and meta.get("mode") == "implement",
            "only canonical implementation state may be archived")
    name, caller, base = meta.get("name"), meta.get("caller"), meta.get("base_sha")
    require(name and caller and metadata.name == "metadata.json" and
            metadata.parent.name == caller + "--" + name + ".d" and
            re.fullmatch(r"[0-9a-f]{40}([0-9a-f]{24})?", base or ""), "legacy canonical metadata identity is unproven")
    repo = physical(meta.get("repo") or "")
    result = subprocess.run(["git", "-C", str(repo), "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    require(result.returncode == 0 and physical(result.stdout.strip()) == repo,
            "legacy canonical repository is unavailable or changed")
    result = subprocess.run(["git", "-C", str(repo), "cat-file", "-e", base + "^{commit}"], capture_output=True)
    require(result.returncode == 0, "legacy canonical base commit is unavailable")
    manifest = physical(metadata.parent / "owner.json")
    _, manifest_data = snapshot(manifest, "log")
    owner = json.loads(manifest_data)
    require(isinstance(owner, dict) and owner.get("version") == 1 and physical(owner.get("owner_dir", "")) == metadata.parent and
            physical(owner.get("metadata", "")) == metadata and owner.get("patch_pattern") == "cumulative-<generation>-<sha256>.patch",
            "legacy canonical owner manifest is unproven")
    patch = physical(meta.get("canonical_patch") or "")
    require(patch.parent == metadata.parent and
            (patch.name == "cumulative.patch" or re.fullmatch(r"cumulative-[0-9]+-[0-9a-f]{64}\.patch", patch.name)),
            "legacy canonical patch path is unproven")
    patch_boundary, patch_data = snapshot(patch, "log")
    require(patch_boundary["exists"] and digest(patch_data) == meta.get("patch_sha256") and
            (not patch_data or patch_data.startswith(b"diff --git ")), "legacy canonical patch is missing or changed")
    if meta.get("evidence_run_id"):
        verify_prepared(directory, provider, meta["evidence_run_id"], "git-binary-patch", patch)
    files = {metadata: metadata_data, manifest: manifest_data, patch: patch_data}
    for candidate in metadata.parent.glob("cumulative-*.patch"):
        candidate = physical(candidate)
        match = re.fullmatch(r"cumulative-[0-9]+-([0-9a-f]{64})\.patch", candidate.name)
        _, data = snapshot(candidate, "log")
        require(match and digest(data) == match[1] and (not data or data.startswith(b"diff --git ")),
                "historical canonical patch name or bytes are unproven")
        files[candidate] = data
    preserved = meta.get("preserved_generation_artifacts", [])
    require(isinstance(preserved, list), "preserved generation metadata is invalid")
    for item in preserved:
        require(isinstance(item, dict), "preserved generation entry is invalid")
        candidate = physical(item.get("path", ""))
        require(candidate.parent == metadata.parent / "recovery", "preserved generation is outside owned recovery directory")
        boundary, data = snapshot(candidate, "log")
        require(boundary["exists"] and digest(data) == item.get("sha256") and (not data or data.startswith(b"diff --git ")),
                "preserved generation bytes are unproven")
        files[candidate] = data
    actual = set()
    for item in metadata.parent.rglob("*"):
        item = physical(item)
        if item.is_dir():
            require(item == metadata.parent / "recovery", "unowned directory in legacy implementation state")
        else:
            actual.add(item)
    require(actual == set(files), "legacy implementation state contains unowned or missing artifacts")
    value = {"schema_version": 1, "provider": provider, "operation": "legacy-state-archive",
             "repository": str(repo), "caller": caller, "base": base,
             "historical_source_authorization": "unknown", "original_paid_result": "unknown",
             "files": [{"path": str(path), "sha256": digest(data), "text": data.decode("utf-8")}
                       for path, data in sorted(files.items(), key=lambda item: str(item[0]))]}
    return digest(encoded(value))[:32], value


def archive_implementation_state(directory, provider, metadata):
    run_id, value = implementation_archive_source(directory, provider, metadata)
    event = {"schema_version": 1, "event": "started", "provider": provider, "operation": "local-reconciliation",
             "parent_run_id": None, "run_id": run_id, "timestamp": now(), "repo": value["repository"],
             "head": "", "caller": value["caller"]}
    append(directory, lambda rows: None if any(row.get("run_id") == run_id for row in rows) else event)
    target = evidence_root(directory, run_id) / "implementation-state-archive.json"
    if target.exists():
        require(read_json(target) == value, "immutable implementation archive conflicts")
    else:
        publish(target, value)
    require(implementation_archive_source(directory, provider, metadata) == (run_id, value), "legacy state changed during archival")
    finish_reconciliation(directory, provider, run_id, [])
    return {"archive_id": run_id, "historical_source_authorization": "unknown", "original_paid_result": "unknown"}


def verify_implementation_archive(directory, provider, metadata):
    run_id, value = implementation_archive_source(directory, provider, metadata)
    require(read_json(evidence_root(directory, run_id) / "implementation-state-archive.json") == value,
            "exact legacy implementation state is not archived")
    start = invocation(directory, provider, run_id)
    require(start.get("operation") == "local-reconciliation" and start.get("head") == "" and
            start.get("parent_run_id") is None, "legacy archive must not claim a paid invocation")
    return {"archive_id": run_id, "historical_source_authorization": "unknown", "original_paid_result": "unknown"}


def reconcile_owner(directory, provider, owner, metadata, report):
    """Publish proven legacy report/patch before allowing exact owned cleanup."""
    path, _, owner_data, row, repo, workspace = owner_identity(owner)
    original = None
    if row.get("evidence_run_id"):
        verify_owner(directory, provider, owner, binding_only=True)
        run_id = row["evidence_run_id"]
        try:
            references = verify_owner(directory, provider, owner)
        except Blocked:
            original = invocation(directory, provider, run_id)
            _, ledger = snapshot(directory / "events.jsonl", "jsonl")
            require(any(json.loads(line).get("run_id") == run_id and json.loads(line).get("event") == "finished"
                        for line in ledger.splitlines()), "implementation invocation is still active; recovery refused")
        else:
            if invocation(directory, provider, run_id).get("operation") == "local-reconciliation":
                finish_reconciliation(directory, provider, run_id, references)
            for recovered_id in {reference.split("/", 1)[0] for reference in references} - {run_id}:
                recovered = invocation(directory, provider, recovered_id)
                if recovered.get("operation") == "local-finalization" and recovered.get("parent_run_id") == run_id:
                    finish_reconciliation(directory, provider, recovered_id, verify_reports(directory, provider, recovered_id))
            return {"already_reconciled": True, "report_count": len(references)}
    metadata = physical(metadata)
    _, meta_data = snapshot(metadata, "log")
    meta = json.loads(meta_data)
    require(physical(meta.get("repo") or meta.get("repository_root") or "") == repo,
            "legacy implementation metadata repository mismatch")
    name, caller, base = meta.get("name"), meta.get("caller"), meta.get("base_sha")
    require(original is None or caller == original["caller"], "implementation caller differs from original invocation")
    require(name and caller and re.fullmatch(r"[0-9a-f]{40}([0-9a-f]{24})?", base or ""),
            "legacy implementation identity is incomplete")
    require((meta.get("provider_terminal_state", meta.get("last_terminal_state")) in {"completed", "failed", "cancelled", "timed-out", "usage-limit", "turn_limit_cancelled"}) or
            meta.get("status") in {"completed", "failed", "aborted"}, "legacy implementation has no terminal outcome proof")
    report = physical(report)
    _, report_data = snapshot(report, "log")
    require(report_data, "legacy implementation report is unavailable")
    text = report_data.decode("utf-8")
    if provider in {"qwen", "kimi"}:
        require(meta.get("version") == 2 and meta.get("mode") == "implement" and
                metadata.name == "metadata.json" and metadata.parent.name == caller + "--" + name + ".d",
                "legacy implementation canonical metadata path is unproven")
        state = metadata.parent.parent.parent.parent
        expected = state / "worktrees" / (provider + "." + metadata.parent.parent.name + "-" + caller + "-" + name) / "wt"
        require(workspace == physical(expected) and path == physical(workspace.parent / "owner.json"),
                "legacy implementation workspace identity mismatch")
        sid = meta.get(provider + "_session_id")
        require(original or (sid and (f"- Session: `{sid}`" in text or f"- {provider.title()} session ID: `{sid}`" in text) and report.name.startswith(provider + "-" + name + "-")),
                "legacy implementation report session mismatch")
        require(original or f"- Repo: `{meta['repo']}`" in text or f"- Repository: `{meta['repo']}`" in text,
                "legacy implementation report repository mismatch")
        patch_path = physical(meta.get("canonical_patch") or "")
        require(patch_path.parent == metadata.parent, "legacy canonical patch is outside its owned metadata")
        _, patch_data = snapshot(patch_path, "log")
        require(digest(patch_data) == meta.get("patch_sha256"), "legacy canonical patch hash mismatch")
    elif provider == "glm":
        require(path == metadata and meta.get("type") == "implementation" and
                metadata.name == caller + "--" + name + ".json", "legacy GLM owner metadata mismatch")
        state = metadata.parent.parent.parent
        require(workspace == physical(state / "wt" / metadata.parent.name / (caller + "--" + name)),
                "legacy GLM clone identity mismatch")
        require(physical(meta.get("report_path") or "") == report and meta.get("opencode_session_id"),
                "legacy GLM report path is unproven")
        sid = meta["opencode_session_id"]
        require(f"| session id | `{sid}` |" in text or f"- OpenCode session ID: `{sid}`" in text,
                "legacy GLM report session mismatch")
        patch_name = meta.get("patch_path") or meta.get("incomplete_patch_path")
        patch_path = physical(patch_name) if patch_name else None
        patch_data = snapshot(patch_path, "log")[1] if patch_path else b""
    else:
        raise Blocked("no authoritative implementation ownership adapter")
    require(workspace.is_dir(), "legacy recovery workspace is unavailable")
    status = subprocess.run(["git", "-C", str(workspace), "status", "--porcelain", "--untracked-files=all"], capture_output=True)
    require(status.returncode == 0 and not any(line.startswith(b"??") for line in status.stdout.splitlines()),
            "legacy workspace has unexported files; preserve and export exact work before reconciliation")
    diff = subprocess.run(["git", "-C", str(workspace), "diff", "--binary", base], capture_output=True)
    require(diff.returncode == 0 and diff.stdout == patch_data,
            "legacy workspace differs from its canonical patch; preserve unexported work")
    patches = [(patch_path, patch_data)] if patch_path is not None else []
    reports = [(report, report_data)]
    if original:
        prepared_owner_artifact(directory, provider, original["run_id"], owner, report, "report")
        patches = []
        reports = []
        original_root = evidence_root(directory, original["run_id"])
        for required in (original_root / "artifacts").glob("*.json"):
            prepared = read_json(original_root / "prepared" / required.name)
            require(digest(str(physical(prepared.get("path", ""))).encode("utf-8")) == required.stem,
                    "prepared patch does not match original required path")
        for prepared_path in (original_root / "prepared").glob("*.json"):
            prepared = read_json(prepared_path)
            if prepared.get("kind") == "git-binary-patch":
                patches.append(prepared_owner_artifact(directory, provider, original["run_id"], owner,
                                                       prepared.get("path", ""), "git-binary-patch"))
            elif prepared.get("kind") == "report":
                reports.append(prepared_owner_artifact(directory, provider, original["run_id"], owner,
                                                       prepared.get("path", ""), "report"))
    identity = {"provider": provider, "owner_sha256": digest(owner_data), "metadata_sha256": digest(meta_data),
                "report_sha256": digest(report_data), "patch_sha256": digest(patch_data),
                "historical_source_authorization": "unknown"}
    if original:
        identity["prepared_patches"] = sorted((str(item), digest(data)) for item, data in patches)
        identity["prepared_reports"] = sorted((str(item), digest(data)) for item, data in reports)
    run_id = digest(encoded(identity))[:32]
    event = {"schema_version": 1, "event": "started", "provider": provider,
             "operation": "local-finalization" if original else "local-reconciliation",
             "parent_run_id": original["run_id"] if original else None, "run_id": run_id,
             "timestamp": now(), "repo": str(repo), "head": original["head"] if original else "", "caller": caller}
    append(directory, lambda rows: None if any(item.get("run_id") == run_id for item in rows) else event)
    require_report(directory, provider, run_id)
    facts = {"phase": "report-publication"}
    if original:
        facts["original_invocation_id"] = original["run_id"]
    for prepared_path, prepared_data in reports:
        receipt = publish_report(directory, provider, run_id, prepared_path, facts)
        require(receipt["report_sha256"] == digest(prepared_data), "legacy report changed during reconciliation")
    for prepared_path, prepared_data in patches:
        receipt = publish_patch(directory, provider, run_id, prepared_path, facts)
        require(receipt["report_sha256"] == digest(prepared_data), "legacy patch changed during reconciliation")
    require(snapshot(path, "log")[1] == owner_data and snapshot(metadata, "log")[1] == meta_data,
            "legacy implementation ownership changed during reconciliation")
    final_status = subprocess.run(["git", "-C", str(workspace), "status", "--porcelain", "--untracked-files=all"], capture_output=True)
    final_diff = subprocess.run(["git", "-C", str(workspace), "diff", "--binary", base], capture_output=True)
    require(final_status.returncode == 0 and final_status.stdout == status.stdout and
            final_diff.returncode == 0 and final_diff.stdout == patch_data,
            "legacy implementation workspace changed during reconciliation")
    if original is None:
        bind_owner(directory, provider, run_id, owner)
    references = verify_owner(directory, provider, owner)
    finish_reconciliation(directory, provider, run_id, verify_reports(directory, provider, run_id))
    return {"run_id": run_id, "report_count": len(references), "historical_source_authorization": "unknown"}


def reconcile_sandbox(directory, provider, sandbox, metadata, reports):
    """Recover exact legacy ownership without inventing a historical event/head."""
    sandbox = physical(sandbox)
    marker = physical(sandbox / ".ai-review-sandbox")
    boundary, marker_data = snapshot(marker, "log")
    require(boundary["exists"] and marker_data, "legacy sandbox marker is missing")
    lines = marker_data.decode("utf-8").splitlines()
    if any(line.startswith("evidence_owner=") for line in lines):
        references = verify_sandbox(directory, sandbox)
        for line in lines:
            if line.startswith("evidence_owner=" + provider + ":"):
                owner = line.split(":", 1)[1]
                if invocation(directory, provider, owner).get("operation") == "local-reconciliation":
                    finish_reconciliation(directory, provider, owner, verify_reports(directory, provider, owner))
        return {"already_reconciled": True, "report_count": len(references),
                "historical_source_authorization": "unknown"}
    source = physical(lines[0])
    _, meta_data = snapshot(physical(metadata), "log")
    meta = json.loads(meta_data)
    require(isinstance(meta, dict) and reports, "legacy metadata and exact reports are required")
    roots = [meta[key] for key in ("repository_root", "repo") if meta.get(key)]
    require(roots and all(physical(root) == source for root in roots), "legacy metadata source mismatch")
    readme = (sandbox / "AI-REVIEW-SANDBOX.md").read_text(encoding="utf-8")
    tags = re.findall(r"^Snapshot tag: (.+)$", readme, re.M)
    require(len(tags) == 1, "legacy sandbox has no unique tag")
    tag = tags[0]
    workspace = meta.get("review_dir") or meta.get("review_workspace") or meta.get("boundary_root")
    if provider not in {"claude", "codex"}:
        require(workspace and physical(workspace) == sandbox, "legacy metadata workspace mismatch")
        if meta.get("sandbox_tag"):
            require(meta["sandbox_tag"] == tag, "legacy metadata tag mismatch")
    report_values = []
    for report in reports:
        report = physical(report)
        _, data = snapshot(report, "log")
        require(data, "legacy report is missing or empty")
        text = data.decode("utf-8")
        if provider in {"claude", "codex"}:
            require(meta.get("provider") == provider and meta.get("run_id"), "legacy lifecycle identity missing")
            require(physical(meta.get("report_path", "")) == report and meta.get("report_sha256") == digest(data),
                    "legacy lifecycle report hash/path mismatch")
            modes = "plan-review|diff-review|security-review|visual-review|final-check"
            match = re.fullmatch(provider + r"-(" + modes + r")-" + re.escape(meta["run_id"]) + r"\.md(?:\..+)?", report.name)
            require(match and tag == provider + "-" + match[1] + "-" + meta["run_id"], "legacy lifecycle sandbox tag mismatch")
        elif provider == "muse":
            allowed = [meta[key] for key in ("last_report", "last_failure_report") if meta.get(key)]
            require(any(physical(path) == report for path in allowed), "legacy Muse report is not recorded")
            sid = meta.get("session_id") or meta.get("returned_session_id")
            require(sid and (f"| session | `{sid}` |" in text or f"- returned session: `{sid}`" in text or
                             f"- requested session: `{sid}`" in text), "legacy Muse session mismatch")
        elif provider == "grok":
            sid = meta.get("grok_session_id")
            require(sid and report.name.startswith("grok-" + meta.get("name", "") + "-") and
                    f"- Session: `{sid}`" in text and any(f"- Repo: `{root}`" in text for root in roots),
                    "legacy Grok session/report mismatch")
        elif provider == "gemini":
            sid = meta.get("conversation_id")
            require(sid and f"Conversation: {sid}" in text and f"Head: {meta.get('head')}" in text and
                    f"Packet: {meta.get('packet_sha256')}" in text, "legacy Gemini exact conversation evidence mismatch")
        elif provider == "kimi":
            canonical = meta.get("artifact_paths", {}).get("canonical")
            sid = meta.get("kimi_session_id")
            require(canonical and physical(canonical) == report and sid and f"- Kimi session: `{sid}`" in text and
                    f"- Job: `{meta.get('job_id')}`" in text, "legacy Kimi canonical job evidence mismatch")
        elif provider == "qwen":
            sid = meta.get("qwen_session_id") or meta.get("session_id")
            require(sid and report.name.startswith("qwen-" + meta.get("name", "") + "-") and
                    f"- Session: `{sid}`" in text and any(f"- Repo: `{root}`" in text for root in roots),
                    "legacy Qwen exact session evidence mismatch")
        elif provider == "glm":
            sid = meta.get("opencode_session_id")
            require(sid and f"| session id | `{sid}` |" in text and
                    any(f"| repository | {root} |" in text for root in roots), "legacy GLM exact session evidence mismatch")
        else:
            raise Blocked("no authoritative legacy sandbox adapter; preserve unknown evidence")
        report_values.append((report, digest(data)))
    identity = {"provider": provider, "metadata_sha256": digest(meta_data), "sandbox_tag": tag,
                "reports": sorted(sha for _, sha in report_values), "historical_source_authorization": "unknown"}
    run_id = digest(encoded(identity))[:32]
    ledger = directory / "events.jsonl"
    _, prior = snapshot(ledger, "jsonl")
    if not any(json.loads(line).get("run_id") == run_id for line in prior.splitlines()):
        event = {"schema_version": 1, "event": "started", "provider": provider,
                 "operation": "local-reconciliation", "parent_run_id": None, "run_id": run_id,
                 "timestamp": now(), "repo": str(source), "head": "", "caller": meta.get("caller", "unknown")}
        def reserve(rows):
            require(not any(row.get("run_id") == run_id for row in rows), "legacy reconciliation already reserved; retry existing work")
            return event
        append(directory, reserve)
    require_report(directory, provider, run_id)
    identity_path = evidence_root(directory, run_id) / "legacy-identity.json"
    if identity_path.exists():
        require(read_json(identity_path) == identity, "legacy evidence identity changed")
    else:
        publish(identity_path, identity)
    for report, expected_hash in report_values:
        result = publish_report(directory, provider, run_id, report, {"phase": "report-publication"})
        require(result["report_sha256"] == expected_hash, "legacy report changed during reconciliation")
    with event_lock(directory):
        references = verify_reports(directory, provider, run_id)
        prefix = "" if "evidence_format=1" in lines else "evidence_format=1\n"
        write_sandbox_owner(marker, boundary, marker_data, prefix + "evidence_owner=" + provider + ":" + run_id)
    finish_reconciliation(directory, provider, run_id, references)
    return {"run_id": run_id, "report_count": len(report_values), "historical_source_authorization": "unknown"}


def finish_reconciliation(directory, provider, run_id, references):
    start = invocation(directory, provider, run_id)
    require(start.get("operation") in {"local-reconciliation", "local-finalization"}, "not a local reconciliation invocation")
    def terminal(rows):
        finished = [row for row in rows if row.get("run_id") == run_id and row.get("event") == "finished"]
        if finished:
            require(len(finished) == 1 and finished[0].get("exit_code") == 0 and
                    finished[0].get("evidence_references") == references, "local reconciliation terminal identity changed")
            return None
        return {**start, "event": "finished", "timestamp": now(), "exit_code": 0,
                "provenance": provenance({"phase": "report-publication"}), "evidence_references": references}
    append(directory, terminal)


def main():
    if sys.argv[1] == "verify-sandbox":
        require(len(sys.argv) == 3, "invalid sandbox evidence verification")
        print(json.dumps({"references": verify_sandbox(location(), sys.argv[2])}))
        return
    operation, provider = sys.argv[1:3]
    require(provider in {"claude", "codex", "deepseek", "gemini", "glm", "grok", "kimi", "muse", "qwen"},
            "unknown reviewer provider")
    directory = location()
    if operation in {"archive-implementation-state", "verify-implementation-archive"}:
        require(len(sys.argv) == 4, "implementation archive requires provider and exact canonical metadata")
        action = archive_implementation_state if operation == "archive-implementation-state" else verify_implementation_archive
        print(json.dumps(action(directory, provider, sys.argv[3])))
    elif operation == "verify-prepared":
        require(len(sys.argv) == 6, "verify-prepared requires provider, original invocation, kind and exact path")
        print(json.dumps({"references": verify_prepared(directory, provider, sys.argv[3], sys.argv[4], sys.argv[5])}))
    elif operation == "reconcile-owner":
        require(len(sys.argv) == 6, "reconcile-owner requires provider, owner, metadata and exact report")
        print(json.dumps(reconcile_owner(directory, provider, sys.argv[3], sys.argv[4], sys.argv[5])))
    elif operation == "reconcile-sandbox":
        require(len(sys.argv) >= 6, "reconcile-sandbox requires provider, sandbox, metadata, and exact report paths")
        print(json.dumps(reconcile_sandbox(directory, provider, sys.argv[3], sys.argv[4], sys.argv[5:])))
    elif operation == "begin":
        parent = os.environ.get("AI_REVIEW_EVENT_RUN_ID", "")
        kind = sys.argv[3] if len(sys.argv) > 3 else "invocation"
        require(kind in {"invocation", "async-submission", "local-finalization"}, "invalid invocation kind")
        event = {"schema_version": 1, "event": "started", "provider": provider,
                 "operation": kind, "parent_run_id": parent if re.fullmatch(r"[0-9a-f]{32}", parent) else None,
                 "run_id": uuid.uuid4().hex, "timestamp": now(), "repo": git_value("rev-parse", "--show-toplevel"),
                 "head": git_value("rev-parse", "HEAD"),
                 "caller": os.environ.get("AI_" + provider.upper() + "_CALLER",
                           os.environ.get("AI_" + provider.upper() + "_REVIEW_CALLER",
                                          "codex" if provider in {"claude", "codex", "gemini"} else "unknown"))}
        append(directory, event)
        print(event["run_id"])
    elif operation == "verify-owner":
        require(len(sys.argv) == 4, "invalid implementation owner verification")
        print(json.dumps({"references": verify_owner(directory, provider, sys.argv[3])}))
    elif operation in {"require-report", "publish-report", "publish-patch", "verify-reports", "bind-sandbox", "bind-owner", "prepare-owner-artifact"}:
        require(len(sys.argv) >= 4, "missing evidence invocation")
        run_id = sys.argv[3]
        if operation == "prepare-owner-artifact":
            require(len(sys.argv) == 7, "prepared artifact requires invocation, owner, kind and path")
            prepare_owner_artifact(directory, provider, run_id, sys.argv[4], sys.argv[5], sys.argv[6])
        elif operation == "require-report":
            require(len(sys.argv) in {4, 5, 6}, "invalid evidence requirement")
            require_report(directory, provider, run_id)
            if len(sys.argv) >= 5:
                bind_sandbox(directory, provider, run_id, sys.argv[4], sys.argv[5] if len(sys.argv) == 6 else None)
        elif operation == "bind-owner":
            require(len(sys.argv) == 5, "invalid implementation owner binding")
            bind_owner(directory, provider, run_id, sys.argv[4])
        elif operation == "bind-sandbox":
            require(len(sys.argv) == 5, "invalid sandbox evidence binding")
            bind_sandbox(directory, provider, run_id, sys.argv[4])
        elif operation == "publish-patch":
            require(len(sys.argv) == 5, "invalid patch publication")
            print(json.dumps(publish_patch(directory, provider, run_id, sys.argv[4])))
        elif operation == "publish-report":
            require(len(sys.argv) in {5, 6}, "invalid report publication")
            facts = json.loads(sys.argv[5]) if len(sys.argv) == 6 else None
            print(json.dumps(publish_report(directory, provider, run_id, sys.argv[4], facts)))
        else:
            require(len(sys.argv) == 4, "invalid evidence verification")
            with event_lock(directory):
                print(json.dumps({"references": verify_reports(directory, provider, run_id)}))
    else:
        require(operation == "finish" and len(sys.argv) in {5, 6}, "invalid event operation")
        run_id, result = sys.argv[3:5]
        facts = provenance(json.loads(sys.argv[5]) if len(sys.argv) == 6 else None)
        publication_incomplete = []
        def finish(rows):
            matches = [r for r in rows if r.get("run_id") == run_id]
            require(len(matches) == 1 and matches[0].get("event") == "started" and
                    matches[0].get("provider") == provider, "event has no unique matching start")
            try:
                references = verify_reports(directory, provider, run_id)
            except (Blocked, OSError, ValueError):
                references = []
                publication_incomplete.append(True)
            return {**matches[0], "event": "finished", "timestamp": now(),
                    "exit_code": int(result) if int(result) or not publication_incomplete else 1,
                    "wrapper_exit_code": int(result),
                    "provenance": facts, "evidence_references": references,
                    "evidence_state": "publication-incomplete" if publication_incomplete else "verified"}
        append(directory, finish)
        require(not publication_incomplete, "required evidence publication incomplete; terminal outcome recorded and local recovery retained")


if __name__ == "__main__":
    os.umask(0o077)
    try:
        main()
    except (Blocked, OSError, ValueError) as error:
        print(f"reviewer event recording: {error}", file=sys.stderr)
        sys.exit(1)
