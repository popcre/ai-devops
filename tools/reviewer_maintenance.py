#!/usr/bin/env python3
"""Private, append-only reviewer maintenance rounds (ai-reviewer-issue owner).

Source adapters are explicit: unknown coverage is a blocker, never an empty scan.
No source is modified. Immutable records are published with create-only hard links.
"""
import argparse
import contextlib
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import socket
import stat
import subprocess
import sys
import tempfile
import uuid


class Blocked(Exception):
    pass


def require(condition, message):
    if not condition:
        raise Blocked(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()


def join_digest(key, value):
    text = os.path.normcase(str(physical(value))) if key == "repo" and value else str(value or "")
    return digest(text.encode())


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def safe_id(value):
    require(isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,180}", value),
            "invalid record identifier")
    return value


def physical(path):
    """Reject links/junctions in every component, including configured roots."""
    text = str(path).replace("\\", "/")
    if os.name == "nt" and text.startswith("/") and not text.startswith("//"):
        converted = subprocess.run(["cygpath", "-w", text], capture_output=True, text=True)
        require(converted.returncode == 0, "cannot normalize Git Bash path")
        path = converted.stdout.strip()
    path = Path(os.path.abspath(path))
    for part in [*reversed(path.parents), path]:
        if part.exists() or part.is_symlink():
            info = part.lstat()
            require(not stat.S_ISLNK(info.st_mode) and
                    not (getattr(info, "st_file_attributes", 0) & 0x400),
                    f"linked path refused: {part}")
    return path


def read_json(path):
    path = physical(path)
    try:
        value = json.loads(path.read_bytes())
        require(isinstance(value, dict), f"JSON object required: {path}")
        return value
    except (ValueError, OSError):
        raise Blocked(f"unreadable or invalid JSON: {path}") from None


def publish(path, value):
    path = physical(path)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    physical(path.parent)
    fd, temporary = tempfile.mkstemp(prefix=".pending-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as output:
            output.write(encoded(value) + b"\n")
            output.flush()
            os.fsync(output.fileno())
        os.link(temporary, path)  # Never replace a published record.
    finally:
        os.unlink(temporary)


@contextlib.contextmanager
def locked(directory):
    directory = physical(directory)
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    lock = physical(directory / ".writer-lock")
    try:
        lock.mkdir(mode=0o700)
    except FileExistsError:
        raise Blocked("maintenance writer is busy; a crash lock requires owner inspection") from None
    try:
        yield
    finally:
        lock.rmdir()


def snapshot(path, kind, previous=None, limit=None):
    path = physical(path)
    require(kind in {"jsonl", "json", "log"}, "unknown source format")
    if not path.exists():
        require(not previous or not previous["exists"], f"source disappeared: {path}")
        return {"path": str(path), "kind": kind, "exists": False, "offset": 0,
                "size": 0, "sha256": digest(b""), "last_record_sha256": None,
                "identity": None, "mtime_ns": None}, b""
    require(stat.S_ISREG(path.stat().st_mode), f"source is not a regular file: {path}")
    require(path.stat().st_mode & 0o444, f"unreadable source: {path}")
    try:
        with path.open("rb") as source:
            before = os.fstat(source.fileno())
            size = before.st_size if limit is None else limit
            require(size <= before.st_size, f"source truncated: {path}")
            content = source.read(size)
            after = os.fstat(source.fileno())
    except OSError:
        raise Blocked(f"unreadable source: {path}") from None
    physical(path)
    current = path.stat()
    identity = [before.st_dev, before.st_ino]
    require(identity == [current.st_dev, current.st_ino] and
            before.st_ino == after.st_ino and len(content) == size,
            f"source changed during snapshot: {path}")
    require(after.st_size >= before.st_size and
            (after.st_mtime_ns == before.st_mtime_ns or after.st_size > before.st_size),
            f"source changed during snapshot: {path}")
    if previous and previous["exists"]:
        require(previous["identity"] == identity, f"source replaced or rotated: {path}")
        require(size >= previous["offset"], f"source truncated: {path}")
        require(digest(content[:previous["offset"]]) == previous["sha256"],
                f"source continuity mismatch: {path}")
        if kind == "json":
            require(size == previous["offset"], f"structured snapshot replaced: {path}")
    require(kind != "jsonl" or not content or content.endswith(b"\n"),
            f"unterminated final JSONL record: {path}")
    last = content.splitlines()[-1] if content and kind == "jsonl" else None
    boundary = {"path": str(path), "kind": kind, "exists": True, "offset": size,
                "size": before.st_size, "sha256": digest(content),
                "last_record_sha256": digest(last) if last is not None else None,
                "identity": identity, "mtime_ns": before.st_mtime_ns}
    return boundary, content


def validate_round(record):
    require(record.get("schema_version") == 1, "unknown maintenance schema")
    safe_id(record.get("id"))
    require("parent" in record, "missing parent boundary")
    if record["parent"] is not None:
        safe_id(record["parent"])
    require(record.get("status") in {"started", "completed"}, "invalid round status")
    for field in ("host", "tool_version", "started_at", "configuration_sha256"):
        require(isinstance(record.get(field), str) and record[field], f"missing {field}")
    require(isinstance(record.get("sources"), dict), "missing source boundaries")
    for source in record["sources"].values():
        require(set(source) == {"lower", "upper"}, "missing lower or upper boundary")
        for bound in source.values():
            require(isinstance(bound, dict) and
                    all(k in bound for k in ("path", "kind", "exists", "offset", "sha256", "identity",
                                             "size", "mtime_ns", "last_record_sha256")), "invalid boundary")
            require(type(bound["offset"]) is int and bound["offset"] >= 0 and
                    re.fullmatch(r"[0-9a-f]{64}", bound["sha256"]), "invalid continuity fingerprint")
        require(source["lower"]["path"] == source["upper"]["path"] and
                source["lower"]["kind"] == source["upper"]["kind"] and
                source["lower"]["offset"] <= source["upper"]["offset"], "inconsistent source boundaries")
    candidates = record.get("candidates")
    require(isinstance(candidates, list), "missing candidates")
    ids = [safe_id(c.get("id")) for c in candidates]
    require(len(ids) == len(set(ids)), "duplicate candidates")
    require(isinstance(record.get("blockers"), list), "missing coverage blockers")
    if record["status"] == "completed":
        require(not record["blockers"], "completion has coverage blockers")
        require(record.get("proof") and record.get("completed_at"), "completion requires proof")
        require(isinstance(record["proof"], dict) and all(record["proof"].get(k) for k in
                ("repair_commit", "tests", "independent_review", "installation", "live")), "incomplete completion proof")
        outcomes = record.get("outcomes", [])
        require(len(outcomes) == len(ids) and {o.get("candidate_id") for o in outcomes} == set(ids),
                "missing or duplicate candidate outcomes")
        require(all(o.get("kind") in {"incident", "non-defect"} for o in outcomes), "invalid outcome")


class Maintenance:
    def __init__(self, toolkit, issues, sources):
        self.toolkit = physical(toolkit)
        self.issues = physical(issues)
        self.directory = self.issues / "maintenance"
        self.configuration = sources
        self.configuration_sha = digest(encoded(sources))
        version = re.search(r'^VERSION="([^"]+)"$', (self.toolkit / "bin/ai-reviewer-issue").read_text(), re.M)
        require(version is not None, "tool version is unavailable")
        self.version = version.group(1)

    def records(self):
        physical(self.directory)
        starts, completed = {}, {}
        for path in sorted(self.directory.glob("*.json")):
            record = read_json(path)
            validate_round(record)
            require(record["host"] == socket.gethostname(), "checkpoint belongs to another host")
            target = starts if record["status"] == "started" else completed
            require(record["id"] not in target, "duplicate round record")
            target[record["id"]] = record
        for rid, record in completed.items():
            require(rid in starts and all(record.get(k) == v for k, v in starts[rid].items()
                                         if k != "status"), "completion differs from frozen start")
        chain, parent = [], None
        while True:
            children = [r for r in completed.values() if r["parent"] == parent]
            require(len(children) <= 1, "checkpoint history has conflicting successors")
            if not children:
                break
            require(children[0]["id"] not in {r["id"] for r in chain}, "checkpoint cycle")
            chain.append(children[0])
            parent = children[0]["id"]
        require(len(chain) == len(completed), "checkpoint history is disconnected")
        active = [r for rid, r in starts.items() if rid not in completed]
        require(len(active) <= 1, "multiple active rounds")
        if active:
            require(active[0]["parent"] == parent, "active round has a stale lower boundary")
        return chain[-1] if chain else None, active[0] if active else None, completed

    def discover(self):
        result = {}
        for spec in self.configuration["sources"]:
            root = physical(spec["root"])
            if spec.get("file"):
                paths = [root / spec["file"]]
            else:
                paths = sorted(root.glob(spec["pattern"]))
            for path in paths:
                path = physical(path)
                require(path.is_relative_to(root), f"source escapes approved root: {path}")
                result[str(path)] = (spec, path)
        return result

    def candidates(self, data, spec, path, lower, carry_ids=frozenset()):
        if spec["kind"] == "log" or not data:
            return []
        if spec.get("adapter") == "invocations":
            return self.invocations(data, path, lower, carry_ids)
        lines = data[lower:].splitlines() if spec["kind"] == "jsonl" else [data]
        found = []
        for line in lines:
            try:
                event = json.loads(line)
            except ValueError:
                raise Blocked(f"invalid structured source: {path}") from None
            require(isinstance(event, dict), f"invalid event shape: {path}")
            provider = event.get("provider", spec.get("provider"))
            require(provider in self.configuration["providers"], f"unregistered source provider: {path}")
            status = event.get("status", "")
            if spec["kind"] == "json":
                require(event.get("schema_version") == 1 and status in
                        {"preflight", "running", "preflight_failed", "completed", "failed", "accounting_failed"},
                        f"unsupported lifecycle shape: {path}")
            else:
                require(event.get("schema_version") in {1, 2} and "verdict" in event and
                        "failure_class" in event, f"unsupported scoreboard shape: {path}")
            if status in {"preflight", "running"}:
                raise Blocked(f"lifecycle has no frozen terminal outcome: {path}")
            if not (event.get("failure_class") or status in {"preflight_failed", "failed", "accounting_failed"}
                    or event.get("verdict") not in {"APPROVE", "REJECT"} or event.get("stale") is True):
                continue
            # Store only hashed join values. No prompt, free-form failure text,
            # credentials, provider response, or raw command enters the round.
            join = {key: join_digest(key, value) for key, value in {
                "run_id": event.get("run_id"), "session_id": event.get("session_id"),
                "caller": event.get("caller"), "repo": event.get("repo", event.get("repository_root")),
                "head": event.get("head"), "source_digest": event.get("source_digest")}.items() if value}
            identity = {"provider": provider, "join": join, "event_sha256": digest(encoded(event))}
            found.append({"id": digest(encoded(identity)), **identity,
                          "source": str(path), "classification": "reviewer-outcome-needs-classification"})
        return found

    def invocations(self, data, path, lower, carry_ids):
        starts, finishes, offset = {}, {}, 0
        for line in data.splitlines(keepends=True):
            offset += len(line)
            try:
                event = json.loads(line)
            except ValueError:
                raise Blocked(f"invalid invocation JSONL: {path}") from None
            require(isinstance(event, dict) and event.get("schema_version") == 1 and
                    event.get("provider") in self.configuration["providers"] and
                    event.get("event") in {"started", "finished"}, f"unsupported invocation event: {path}")
            rid = safe_id(event.get("run_id"))
            target = starts if event["event"] == "started" else finishes
            require(rid not in target, f"duplicate invocation event: {path}")
            target[rid] = (event, offset)
        for rid, (finish, _) in finishes.items():
            require(rid in starts and all(finish.get(k) == v for k, v in starts[rid][0].items()
                                         if k not in {"event", "timestamp"}) and
                    type(finish.get("exit_code")) is int, f"invocation finish has no exact start: {path}")
        found = []
        for rid, (start, start_position) in starts.items():
            finish, position = finishes.get(rid, (None, 0))
            worker_missing = bool(finish and finish["exit_code"] == 0 and start.get("operation") == "async-submission"
                                  and not any(s.get("parent_run_id") == rid for s, _ in starts.values()))
            if finish and not worker_missing and (position <= lower or finish["exit_code"] == 0):
                continue
            event = start if worker_missing else (finish or start)
            candidate_id = digest(encoded(event))
            if (not finish or worker_missing) and max(position, start_position) <= lower and candidate_id not in carry_ids:
                continue
            join = {k: join_digest(k, event[k]) for k in ("run_id", "repo", "head", "caller") if event.get(k)}
            found.append({"id": candidate_id, "provider": event["provider"], "join": join,
                          "event_sha256": digest(encoded(event)), "source": str(path),
                          "classification": "failed-invocation" if finish and not worker_missing else "completion-unproven"})
        return found

    def verify_sources(self, record):
        require(record["configuration_sha256"] == self.configuration_sha, "source configuration changed")
        for pair in record["sources"].values():
            upper = pair["upper"]
            if upper["exists"]:
                snapshot(upper["path"], upper["kind"], upper, upper["offset"])

    def start(self, resume=None):
        with locked(self.directory):
            last, active, _ = self.records()
            if resume:
                require(active and active["id"] == resume, "no matching active round to resume")
                self.verify_sources(active)
                return active
            require(active is None, "a maintenance round is active; explicitly resume its ID")
            if last:
                self.verify_sources(last)
            discovered = self.discover()
            old = last["sources"] if last else {}
            for path in old:
                require(path in discovered, f"source disappeared from discovery: {path}")
            sources, candidates = {}, {}
            carry_ids = {candidate["id"] for candidate in (last or {}).get("carry_forward", [])}
            blockers = list(self.configuration.get("blockers", []))
            for key, (spec, path) in discovered.items():
                lower = old[key]["upper"] if key in old else {
                    "path": key, "kind": spec["kind"], "exists": False, "offset": 0,
                    "size": 0, "sha256": digest(b""), "last_record_sha256": None,
                    "identity": None, "mtime_ns": None}
                upper, data = snapshot(path, spec["kind"], lower)
                sources[key] = {"lower": lower, "upper": upper}
                if upper["offset"] == lower["offset"] and spec.get("adapter") != "invocations":
                    continue
                for candidate in self.candidates(data, spec, path, lower["offset"], carry_ids):
                    candidates[candidate["id"]] = candidate
            for candidate in (last or {}).get("carry_forward", []):
                # An observed ongoing invocation is automatically rediscovered
                # while unfinished; its later terminal event accounts for it.
                if candidate.get("carry_kind") != "in-progress":
                    candidates[candidate["id"]] = candidate
            carried_issues = {outcome["issue_id"] for outcome in (last or {}).get("outcomes", [])
                              if outcome.get("kind") == "incident" and outcome["candidate_id"] in carry_ids}
            for path in sorted(self.issues.glob("*/issue.json")):
                issue = read_json(path)
                iid = safe_id(issue.get("id"))
                require(path.parent.name == iid, "legacy incident directory identity mismatch")
                resolutions = sorted(physical(path.parent / "resolutions").glob("*.json"))
                if iid in carried_issues or (resolutions and read_json(resolutions[-1]).get("status") == "resolved"):
                    continue
                identity = digest(encoded(issue))
                candidate = {"id": identity, "provider": issue["provider"], "join": {},
                             "event_sha256": identity, "source": str(path),
                             "classification": "existing-incident", "existing_issue_id": iid}
                candidates[identity] = candidate
            record = {"schema_version": 1, "id": uuid.uuid4().hex, "status": "started",
                      "host": socket.gethostname(), "tool_version": self.version, "started_at": now(),
                      "parent": last["id"] if last else None, "configuration_sha256": self.configuration_sha,
                      "sources": sources, "candidates": sorted(candidates.values(), key=lambda c: c["id"]),
                      "blockers": blockers}
            validate_round(record)
            self.verify_sources(record)
            publish(self.directory / (record["id"] + ".started.json"), record)
            return record

    def evidence(self, reference):
        require(isinstance(reference, str) and reference, "missing evidence reference")
        if re.fullmatch(r"https?://[^\s]+", reference):
            return {"reference": reference, "sha256": None}
        path = Path(reference)
        if not path.is_absolute():
            path = self.toolkit / path
        path = physical(path)
        require(path.is_file() and path.stat().st_size > 0, f"missing or empty evidence: {path}")
        return {"reference": str(path), "sha256": digest(path.read_bytes())}

    def incident(self, candidate, issue_id, closure=False):
        directory = physical(self.issues / safe_id(issue_id))
        issue = read_json(directory / "issue.json")
        require(issue.get("id") == issue_id and issue.get("provider") == candidate["provider"],
                "incident identity or provider mismatch")
        exact = {**issue.get("join", {}), "repo": issue.get("repository", {}).get("root"),
                 "head": issue.get("repository", {}).get("head")}
        join = candidate["join"]
        if candidate.get("existing_issue_id"):
            require(candidate["existing_issue_id"] == issue_id and digest(encoded(issue)) == candidate["event_sha256"],
                    "legacy incident evidence changed")
        else:
            event_bound = issue.get("join", {}).get("event_sha256") == candidate["event_sha256"]
            require(event_bound or (join.get("caller") and join.get("repo") and join.get("head") and
                    (join.get("run_id") or join.get("session_id"))), "candidate lacks an exact incident join")
            require(all(value == join_digest(key, exact.get(key, "")) for key, value in join.items()),
                    "incident exact run/session/source join mismatch")
        if not closure:
            return None
        resolutions = sorted(physical(directory / "resolutions").glob("*.json"))
        require(resolutions, f"linked incident remains open: {issue_id}")
        resolution = read_json(resolutions[-1])
        require(resolution.get("status") in {"resolved", "partially-resolved"}, "invalid incident resolution")
        require(resolution.get("repair_commits") and resolution.get("evidence"), "resolution lacks closure proof")
        repair_repo = physical(resolution.get("repair_repository") or self.toolkit)
        for commit in resolution["repair_commits"]:
            self.commit(commit, repair_repo)
            merged = subprocess.run(["git", "-C", str(repair_repo), "merge-base", "--is-ancestor",
                                     commit, "refs/remotes/origin/main"], capture_output=True)
            require(merged.returncode == 0, "linked incident repair is not on fetched origin/main")
        for ref in resolution["evidence"]:
            self.evidence(ref)
        return resolution

    def commit(self, commit, repository=None):
        require(isinstance(commit, str) and re.fullmatch(r"[0-9a-fA-F]{40}", commit), "exact repair commit required")
        result = subprocess.run(["git", "-C", str(repository or self.toolkit), "cat-file", "-e", commit + "^{commit}"],
                                capture_output=True)
        require(result.returncode == 0, "repair commit not found in its recorded repository")

    def outcome(self, round_id, candidate_id, issue_id=None, reason=None, evidence=None, carry=None):
        with locked(self.directory):
            _, active, _ = self.records()
            require(active and active["id"] == round_id, "round is not active")
            candidate = next((c for c in active["candidates"] if c["id"] == candidate_id), None)
            require(candidate is not None, "candidate not found in frozen round")
            require(bool(issue_id) != bool(reason), "choose exactly one incident or non-defect outcome")
            record = {"schema_version": 1, "candidate_id": candidate_id, "round_id": round_id}
            if issue_id:
                self.incident(candidate, issue_id)
                record.update(kind="incident", issue_id=issue_id)
                if carry:
                    require(evidence, "carry-forward needs evidence")
                    record.update(carry_forward=self.evidence(carry), evidence=self.evidence(evidence))
            else:
                require(not candidate.get("existing_issue_id"), "existing incidents must use their resolution workflow")
                require(reason in {"expected-refusal", "quota-exhaustion", "user-cancellation",
                                   "application-failure", "duplicate-event", "in-progress"}, "unknown non-defect reason")
                require(not carry, "use incident carry-forward for unresolved repairs")
                if reason == "in-progress":
                    require(candidate["classification"] == "completion-unproven", "only unfinished invocations can be in progress")
                record.update(kind="non-defect", reason=reason, evidence=self.evidence(evidence))
            path = self.directory / safe_id(round_id) / (safe_id(candidate_id) + ".json")
            if path.exists():
                require(read_json(path) == record, "candidate already has a conflicting outcome")
            else:
                publish(path, record)
            return record

    def record_incident(self, round_id, candidate_id, summary, details_file):
        # The exact frozen source supplies identities; callers need not recover
        # hashes or inspect private provider transcripts to record a candidate.
        with locked(self.directory):
            _, active, _ = self.records()
            require(active and active["id"] == round_id, "round is not active")
            self.verify_sources(active)
            candidate = next((c for c in active["candidates"] if c["id"] == candidate_id), None)
            require(candidate is not None, "candidate not found")
            require(not candidate.get("existing_issue_id"), "classify this candidate with its existing incident ID")
            outcome_path = self.directory / round_id / (safe_id(candidate_id) + ".json")
            require(not outcome_path.exists(), "candidate already classified")
            boundary = active["sources"][candidate["source"]]["upper"]
            _, data = snapshot(boundary["path"], boundary["kind"], boundary, boundary["offset"])
            events = [json.loads(line) for line in data.splitlines()]
            matches = [event for event in events if digest(encoded(event)) == candidate["event_sha256"]]
            require(len(matches) == 1, "candidate lacks a unique frozen event")
            event = matches[0]
            repository = event.get("repo") or event.get("repository_root")
            require(repository and event.get("head"),
                    "event lacks repository or head identity; manual incident reconciliation required")
            lifecycle = {"schema_version": 1, "provider": event["provider"], "run_id": event.get("run_id") or "",
                         "session_id": event.get("session_id"), "event_sha256": candidate["event_sha256"],
                         "repository_root": repository, "head": event["head"], "caller": event.get("caller") or "",
                         "source_digest": event.get("source_digest") or ""}
            details = physical(details_file)
            require(details.is_file(), "incident details file not found")
            state_path = self.directory / round_id / (candidate_id + ".event.json")
            if state_path.exists():
                require(read_json(state_path) == lifecycle, "preserved event identity changed")
            else:
                publish(state_path, lifecycle)
            env = {**os.environ, "AI_REVIEWER_ISSUE_DIR": str(self.issues)}
            result = subprocess.run([os.environ.get("AI_REVIEWER_BASH", "bash"), str(self.toolkit / "bin/ai-reviewer-issue"), "record",
                "--lifecycle-state", str(state_path), "--summary", summary, "--details-file", str(details)],
                env=env, capture_output=True, text=True)
            require(result.returncode == 0, "incident recording failed; no checkpoint was advanced")
            match = re.search(r"^ai-reviewer-issue: recorded ([A-Za-z0-9._-]+)$", result.stdout, re.M)
            require(match is not None, "incident recorder returned no issue ID")
            iid = match.group(1)
            self.incident(candidate, iid)
            publish(outcome_path, {"schema_version": 1, "round_id": round_id, "candidate_id": candidate_id,
                                   "kind": "incident", "issue_id": iid})
            return {"issue_id": iid, "candidate_id": candidate_id}

    def carry(self, round_id, candidate_id, remaining, evidence):
        with locked(self.directory):
            _, active, _ = self.records()
            require(active and active["id"] == round_id, "round is not active")
            require(any(c["id"] == candidate_id for c in active["candidates"]), "candidate not found")
            directory = self.directory / safe_id(round_id)
            outcome = read_json(directory / (safe_id(candidate_id) + ".json"))
            require(outcome.get("kind") == "incident", "carry-forward requires a linked incident")
            value = {"round_id": round_id, "candidate_id": candidate_id,
                     "carry_forward": self.evidence(remaining), "evidence": self.evidence(evidence)}
            path = directory / (candidate_id + ".carry.json")
            if path.exists():
                require(read_json(path) == value, "conflicting carry-forward record")
            else:
                publish(path, value)
            return value

    def audit(self, record):
        self.verify_sources(record)
        require(not record["blockers"], "; ".join(record["blockers"]))
        outcomes, carry = [], []
        for candidate in record["candidates"]:
            path = self.directory / record["id"] / (candidate["id"] + ".json")
            require(path.exists(), f"unclassified candidate: {candidate['id']}")
            outcome = read_json(path)
            require(outcome.get("round_id") == record["id"] and
                    outcome.get("candidate_id") == candidate["id"], "outcome identity mismatch")
            carry_path = path.with_name(candidate["id"] + ".carry.json")
            if carry_path.exists():
                carried = read_json(carry_path)
                require(carried.get("round_id") == record["id"] and carried.get("candidate_id") == candidate["id"],
                        "carry-forward identity mismatch")
                outcome = {**outcome, "carry_forward": carried["carry_forward"], "evidence": carried["evidence"]}
            if outcome.get("kind") == "incident":
                resolution = self.incident(candidate, outcome["issue_id"], closure=True)
                if resolution["status"] == "partially-resolved":
                    require(outcome.get("carry_forward") and outcome.get("evidence"),
                            "partial resolution requires explicit carry-forward proof")
                    carry.append(candidate)
            else:
                require(outcome.get("kind") == "non-defect" and outcome.get("reason") in
                        {"expected-refusal", "quota-exhaustion", "user-cancellation", "application-failure",
                         "duplicate-event", "in-progress"} and outcome.get("evidence"), "invalid non-defect outcome")
                if outcome["reason"] == "in-progress":
                    require(candidate["classification"] == "completion-unproven", "invalid in-progress classification")
                    carry.append({**candidate, "carry_kind": "in-progress"})
            for field in ("evidence", "carry_forward"):
                if field in outcome:
                    require(self.evidence(outcome[field]["reference"]) == outcome[field], "outcome evidence changed")
            outcomes.append(outcome)
        return outcomes, carry

    def complete(self, round_id, proof_file):
        with locked(self.directory):
            _, active, completed = self.records()
            if round_id in completed:
                return completed[round_id]
            require(active and active["id"] == round_id, "round is not active")
            outcomes, carry = self.audit(active)
            proof = read_json(proof_file)
            self.commit(proof.get("repair_commit"))
            merged = subprocess.run(["git", "-C", str(self.toolkit), "merge-base", "--is-ancestor",
                                     proof["repair_commit"], "refs/remotes/origin/main"], capture_output=True)
            require(merged.returncode == 0, "repair commit is not present on fetched origin/main")
            verified = {"repair_commit": proof["repair_commit"]}
            for field in ("tests", "independent_review", "installation", "live"):
                verified[field] = self.evidence(proof.get(field))
            if active["parent"] is None:
                verified["legacy_audit"] = self.evidence(proof.get("legacy_audit"))
            # Recheck immediately before the create-only publication. No lower
            # boundary is updated on any failure above or in publication itself.
            self.audit(active)
            record = {**active, "status": "completed", "completed_at": now(), "proof": verified,
                      "outcomes": outcomes, "carry_forward": carry}
            validate_round(record)
            publish(self.directory / (round_id + ".completed.json"), record)
            return record

    def show(self):
        last, active, _ = self.records()
        record = active or last
        blockers = list((record or {}).get("blockers", []))
        counts = {"incident": 0, "non-defect": 0, "unclassified": 0}
        candidates = []
        if record:
            try:
                self.verify_sources(record)
            except Blocked as error:
                blockers.append(str(error))
            for candidate in record["candidates"]:
                path = self.directory / record["id"] / (candidate["id"] + ".json")
                outcome = read_json(path) if path.exists() else {}
                kind = outcome.get("kind", "unclassified")
                require(kind in counts, "invalid candidate outcome")
                counts[kind] += 1
                candidates.append({"id": candidate["id"], "provider": candidate["provider"],
                                   "classification": candidate["classification"], "outcome": kind,
                                   "issue_id": outcome.get("issue_id", candidate.get("existing_issue_id"))})
                try:
                    self.audit({**record, "sources": {}, "blockers": [], "candidates": [candidate]})
                except Blocked as error:
                    blockers.append(str(error))
        return {"host": socket.gethostname(), "last_completed": last["id"] if last else None,
                "active_round": active["id"] if active else None,
                "sources": record["sources"] if record else {},
                "counts": counts, "candidates": candidates, "blockers": blockers}


def configuration(toolkit):
    registry = read_json(toolkit / "config/reviewer-registry.json")
    providers = sorted(k for k, v in registry["providers"].items() if v["registry_state"] == "registered")
    base = physical(os.environ.get("AI_REVIEWER_STATE_BASE") or (os.environ.get("HOME") or str(Path.home())) + "/.local/state/ai-devops")
    scoreboard = Path(os.environ.get("AI_REVIEW_SCOREBOARD_FILE", str(Path(os.environ.get(
        "AI_REVIEW_SCOREBOARD_DIR", str(base / "review-scoreboard"))) / "reviews.jsonl")))
    events = physical(os.environ.get("AI_REVIEW_EVENT_DIR", str(base / "reviewer-events")))
    wrappers = {"claude": "ai-claude-review", "codex": "ai-codex-review", "deepseek": "ai-deepseek-agent",
                "gemini": "ai-gemini", "glm": "ai-glm", "grok": "ai-grok-review", "kimi": "ai-kimi",
                "muse": "ai-muse", "qwen": "ai-qwen"}
    unsupported = []
    for provider in providers:
        path = physical(toolkit / "bin" / wrappers.get(provider, "unsupported-provider"))
        if provider not in wrappers or not path.is_file() or (
                f'reviewer_event_guard {provider} "$_AI_EVENT_SELF" "$@"'.encode() not in path.read_bytes()):
            unsupported.append(provider)
    return {"providers": providers, "sources": [
        {"root": str(events), "file": "events.jsonl", "kind": "jsonl", "adapter": "invocations"},
        {"root": str(physical(scoreboard.parent)), "file": scoreboard.name, "kind": "jsonl"}],
        "blockers": [f"unsupported durable event coverage: {p}; provider source repair required" for p in unsupported]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--toolkit", required=True)
    parser.add_argument("--issues", required=True)
    sub = parser.add_subparsers(dest="operation", required=True)
    start = sub.add_parser("start")
    start.add_argument("--resume")
    sub.add_parser("show")
    link = sub.add_parser("classify")
    link.add_argument("round_id")
    link.add_argument("candidate_id")
    link.add_argument("--issue")
    link.add_argument("--reason")
    link.add_argument("--evidence")
    link.add_argument("--carry-forward")
    complete = sub.add_parser("complete")
    complete.add_argument("round_id")
    complete.add_argument("--proof", required=True)
    carry = sub.add_parser("carry-forward")
    carry.add_argument("round_id")
    carry.add_argument("candidate_id")
    carry.add_argument("--remaining", required=True)
    carry.add_argument("--evidence", required=True)
    record = sub.add_parser("record")
    record.add_argument("round_id")
    record.add_argument("candidate_id")
    record.add_argument("--summary", required=True)
    record.add_argument("--details-file", required=True)
    args = parser.parse_args()
    toolkit = physical(args.toolkit)
    engine = Maintenance(toolkit, args.issues, configuration(toolkit))
    if args.operation == "start":
        record = engine.start(args.resume)
        result = {"round_id": record["id"], "status": record["status"],
                  "candidate_count": len(record["candidates"]), "blockers": record["blockers"]}
    elif args.operation == "show":
        result = engine.show()
    elif args.operation == "classify":
        engine.outcome(args.round_id, args.candidate_id, args.issue, args.reason, args.evidence, args.carry_forward)
        result = {"classified": args.candidate_id}
    elif args.operation == "record":
        result = engine.record_incident(args.round_id, args.candidate_id, args.summary, args.details_file)
    elif args.operation == "carry-forward":
        engine.carry(args.round_id, args.candidate_id, args.remaining, args.evidence)
        result = {"carried_forward": args.candidate_id}
    else:
        record = engine.complete(args.round_id, args.proof)
        result = {"round_id": record["id"], "status": record["status"]}
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    os.umask(0o077)
    try:
        main()
    except (Blocked, OSError) as error:
        print(f"ai-reviewer-issue: {error}", file=sys.stderr)
        sys.exit(1)
