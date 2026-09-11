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


def publish_report(directory, provider, run_id, report, facts=None):
    # Only a wrapper's prepared UTF-8 report is accepted, never a stream/session
    # directory. The private report is immutable; no response enters the ledger.
    report = physical(report)
    boundary, data = snapshot(report, "log")
    require(boundary["exists"] and data, "report is missing or empty; source evidence retained")
    current = report.stat()
    require(current.st_size == boundary["offset"] and current.st_mtime_ns == boundary["mtime_ns"],
            "report changed during publication; source evidence retained")
    text = data.decode("utf-8")
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
        path = root / (sha + ".report.json")
        if path.exists():
            require(read_json(path) == value, "published evidence conflicts with this invocation")
        else:
            publish(path, value)
        # Return an opaque recovery reference, not a source-worktree path.
        return {"reference": run_id + "/" + sha, "report_sha256": sha}


def verify_reports(directory, provider, run_id):
    start = invocation(directory, provider, run_id)
    root = evidence_root(directory, run_id)
    if not (root / "required.json").exists():
        return []
    required = read_json(root / "required.json")
    require(required == {"schema_version": 1, "run_id": run_id, "provider": provider,
                         "head": start["head"], "caller": start["caller"]}, "evidence requirement changed")
    paths = sorted(root.glob("*.report.json"))
    if not paths:
        # A local finalizer may preserve a paid result after its original
        # wrapper has ended. Validate that immutable receipt without rewriting
        # the earlier event or pretending another provider request occurred.
        recovered = []
        for candidate in (directory / "evidence").glob("*/*.report.json"):
            row = read_json(physical(candidate))
            if row.get("original_invocation_id") == run_id and row.get("run_id") != run_id:
                owner = row.get("run_id", "")
                references = verify_reports(directory, provider, owner)
                reference = owner + "/" + row.get("report_sha256", "")
                require(reference in references, "recovery receipt identity is invalid")
                recovered.append(reference)
        if recovered:
            return sorted(set(recovered))
    require(paths, "required report is not durably published; cleanup and replay refused")
    references = []
    for path in paths:
        row = read_json(path)
        require(row.get("schema_version") == 1 and row.get("run_id") == run_id and
                row.get("provider") == provider and row.get("head") == start["head"] and
                row.get("caller") == start["caller"], "published report identity changed")
        require(isinstance(row.get("report_text"), str) and row["report_text"], "published report is empty")
        sha = digest(row["report_text"].encode("utf-8"))
        require(row.get("report_sha256") == sha and path.name == sha + ".report.json",
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
        references.append(run_id + "/" + sha)
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


def verify_owner(directory, provider, owner):
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
        return verify_reports(directory, provider, run_id)


def reconcile_owner(directory, provider, owner, metadata, report):
    """Publish proven legacy report/patch before allowing exact owned cleanup."""
    path, _, owner_data, row, repo, workspace = owner_identity(owner)
    if row.get("evidence_run_id"):
        references = verify_owner(directory, provider, owner)
        run_id = row["evidence_run_id"]
        if invocation(directory, provider, run_id).get("operation") == "local-reconciliation":
            finish_reconciliation(directory, provider, run_id, references)
        return {"already_reconciled": True, "report_count": len(references)}
    metadata = physical(metadata)
    _, meta_data = snapshot(metadata, "log")
    meta = json.loads(meta_data)
    require(physical(meta.get("repo") or meta.get("repository_root") or "") == repo,
            "legacy implementation metadata repository mismatch")
    name, caller, base = meta.get("name"), meta.get("caller"), meta.get("base_sha")
    require(name and caller and re.fullmatch(r"[0-9a-f]{40}([0-9a-f]{24})?", base or ""),
            "legacy implementation identity is incomplete")
    require((meta.get("last_terminal_state") in {"completed", "failed", "cancelled", "timed-out", "usage-limit", "turn_limit_cancelled"}) or
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
        require(sid and f"- Session: `{sid}`" in text and report.name.startswith(provider + "-" + name + "-"),
                "legacy implementation report session mismatch")
        require(f"- Repo: `{meta['repo']}`" in text, "legacy implementation report repository mismatch")
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
    identity = {"provider": provider, "owner_sha256": digest(owner_data), "metadata_sha256": digest(meta_data),
                "report_sha256": digest(report_data), "patch_sha256": digest(patch_data),
                "historical_source_authorization": "unknown"}
    run_id = digest(encoded(identity))[:32]
    event = {"schema_version": 1, "event": "started", "provider": provider, "operation": "local-reconciliation",
             "parent_run_id": None, "run_id": run_id, "timestamp": now(), "repo": str(repo), "head": "", "caller": caller}
    append(directory, lambda rows: None if any(item.get("run_id") == run_id for item in rows) else event)
    require_report(directory, provider, run_id)
    receipt = publish_report(directory, provider, run_id, report, {"phase": "report-publication"})
    require(receipt["report_sha256"] == identity["report_sha256"], "legacy report changed during reconciliation")
    if patch_data:
        receipt = publish_report(directory, provider, run_id, patch_path, {"phase": "report-publication"})
        require(receipt["report_sha256"] == identity["patch_sha256"], "legacy patch changed during reconciliation")
    bind_owner(directory, provider, run_id, owner)
    references = verify_owner(directory, provider, owner)
    finish_reconciliation(directory, provider, run_id, references)
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
    require(start.get("operation") == "local-reconciliation", "not a local reconciliation invocation")
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
    if operation == "reconcile-owner":
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
    elif operation in {"require-report", "publish-report", "verify-reports", "bind-sandbox", "bind-owner"}:
        require(len(sys.argv) >= 4, "missing evidence invocation")
        run_id = sys.argv[3]
        if operation == "require-report":
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
        def finish(rows):
            matches = [r for r in rows if r.get("run_id") == run_id]
            require(len(matches) == 1 and matches[0].get("event") == "started" and
                    matches[0].get("provider") == provider, "event has no unique matching start")
            references = verify_reports(directory, provider, run_id)
            return {**matches[0], "event": "finished", "timestamp": now(), "exit_code": int(result),
                    "provenance": facts, "evidence_references": references}
        append(directory, finish)


if __name__ == "__main__":
    os.umask(0o077)
    try:
        main()
    except (Blocked, OSError, ValueError) as error:
        print(f"reviewer event recording: {error}", file=sys.stderr)
        sys.exit(1)
