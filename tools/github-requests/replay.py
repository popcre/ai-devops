#!/usr/bin/env python3
"""Bounded offline replay of frozen anonymous reads against real sharing code.

This is conditional executable evidence, not a retrospective natural baseline.
UTC completion times are replayed as serial arrivals; request starts, response
heads/content and overlap were not collected. HTTP/GraphQL totals stay unknown.
Owner #658/#660. Retire this runner into the existing reporter when prospective
interval records can support matched natural cohorts without these assumptions.
"""
import argparse
from contextlib import contextmanager
import datetime
import hashlib
import importlib.util
import io
import json
import math
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
from types import SimpleNamespace

BASELINE = "f55c1a608a026ae1d0f18725743c2b5c1cb70f5b"
CANDIDATE = "3b9ac2864e1c9ab884f30bcb48c0289c4ec9fa5d"
FROZEN_INPUT = "f8477e7532d881905a4e3c7dda07500ea47863576c4bb2739a6d42a3f868cb28"
READ_KEYS = {"schema", "utc", "measurement", "caller", "workflow", "target_ordinal",
             "source", "cache_hit", "saved_upstream_read"}


def unique(pairs):
    result = {}
    for name, value in pairs:
        if name in result: raise ValueError("duplicate input field")
        result[name] = value
    return result


def read_trace(directory, expected_digest):
    paths = sorted(Path(directory).glob("????-??-??.jsonl"))
    if not paths or len(paths) > 31: raise ValueError("bounded daily trace required")
    digest, result, previous = hashlib.sha256(), [], None
    for path in paths:
        descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(descriptor, "rb") as stream:
            info = os.fstat(stream.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_size > 4194304:
                raise ValueError("invalid daily trace")
            data = stream.read(4194305)
        digest.update(data)
        for line in data.splitlines():
            row = json.loads(line, object_pairs_hook=unique)
            if not isinstance(row, dict): raise ValueError("invalid trace object")
            if row.get("measurement") != "read_observation": continue
            if (set(row) != READ_KEYS or type(row["schema"]) is not int or row["schema"] != 6
                    or row["caller"] != "ai-pr-wait" or row["workflow"] != "pr_wait"
                    or type(row["target_ordinal"]) is not int or not 1 <= row["target_ordinal"] <= 1000000000
                    or row["source"] not in ("cache", "upstream")
                    or type(row["cache_hit"]) is not bool or type(row["saved_upstream_read"]) is not bool
                    or row["cache_hit"] != (row["source"] == "cache")
                    or row["saved_upstream_read"] != row["cache_hit"] or not isinstance(row["utc"], str)):
                raise ValueError("invalid anonymous read")
            parsed = datetime.datetime.strptime(row["utc"], "%Y-%m-%dT%H:%M:%SZ")
            stamp = int(parsed.replace(tzinfo=datetime.timezone.utc).timestamp()) * 1000000000
            if previous is not None and stamp < previous: raise ValueError("nonmonotonic frozen ordering")
            previous = stamp
            result.append((stamp, row["target_ordinal"]))
            if len(result) > 10000: raise ValueError("trace operation bound exceeded")
    if digest.hexdigest() != expected_digest or not result:
        raise ValueError("frozen input digest differs or no reads exist")
    return result, digest.hexdigest()


def git_blob(root, sha, path):
    git = shutil.which("git")
    if not git or re.fullmatch(r"[0-9a-f]{40}", sha) is None: raise ValueError("exact source required")
    environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    environment.update(GIT_NO_REPLACE_OBJECTS="1", GIT_NO_LAZY_FETCH="1")
    value = subprocess.run([git, "--no-replace-objects", "-C", str(root), "show", f"{sha}:{path}"],
                           env=environment, capture_output=True, check=True, timeout=10).stdout
    if len(value) > 1048576: raise ValueError("source file bound exceeded")
    return value


class Clock:
    def __init__(self): self.now = 0
    def time(self): return self.now / 1000000000
    def time_ns(self): return self.now
    def monotonic(self): return self.time()
    def sleep(self, seconds): self.now += int(seconds * 1000000000)
    def strftime(self, *args): return time.strftime(*args)
    def gmtime(self, *args): return time.gmtime(*args)


class Capture:
    def __init__(self): self.buffer = io.BytesIO()
    def write(self, value): return self.buffer.write(value.encode("utf-8"))
    def flush(self): pass


@contextmanager
def isolated_environment(values):
    previous = {key: os.environ.get(key) for key in values}
    os.environ.update(values)
    try: yield
    finally:
        for key, value in previous.items():
            if value is None: os.environ.pop(key, None)
            else: os.environ[key] = value


def execute_phase(root, sha, phase, profile, trace, digest, scratch, fixture_failure=None):
    """Run the literal pinned helper; replace only clocks and local fixture I/O."""
    started = time.perf_counter_ns()
    source_dir = scratch / f"{profile}-{phase}-source"; source_dir.mkdir(mode=0o700)
    paths = ["pr_status_singleflight.py"]
    if sha == CANDIDATE: paths += ["target_ordinal.py", "measure_append.py"]
    hashes = {}
    for name in paths:
        data = git_blob(root, sha, "tools/github-requests/" + name)
        destination = source_dir / name; destination.write_bytes(data); destination.chmod(0o400)
        hashes[name] = hashlib.sha256(data).hexdigest()
    saved_path, saved_argv = list(sys.path), list(sys.argv)
    saved_modules = {name: sys.modules.pop(name, None) for name in ("target_ordinal", "measure_append")}
    spec = importlib.util.spec_from_file_location("replayed_sharing", source_dir / "pr_status_singleflight.py")
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    clock = Clock(); module.time = clock
    cache = scratch / f"{profile}-{phase}-cache"
    measurement_state = scratch / f"{profile}-{phase}-metadata"
    content_writes = unchanged_writes = metadata_refreshes = upstream_calls = 0
    actual_atomic, actual_run, actual_utime = module.atomic_write, subprocess.run, os.utime
    def write(path, data):
        nonlocal content_writes, unchanged_writes
        previous = path.read_bytes() if path.exists() else None
        actual_atomic(path, data)
        content_writes += 1; unchanged_writes += previous == data
        actual_utime(path, ns=(clock.now, clock.now))
    def utime(path, times=None, **kwargs):
        nonlocal metadata_refreshes
        actual_utime(path, ns=(clock.now, clock.now)); metadata_refreshes += 1
    def upstream(command, **kwargs):
        nonlocal upstream_calls
        upstream_calls += 1
        return actual_run(command, **kwargs)
    module.atomic_write = write
    module.os = SimpleNamespace(**{name: getattr(os, name) for name in dir(os) if not name.startswith("__")})
    module.os.utime = utime
    module.subprocess = SimpleNamespace(run=upstream)
    head = "a" * 40 if profile == "stable_open" else None
    body = {"data": {"repository": {"pullRequest": {
        "state": "OPEN", "headRefOid": head, "isInMergeQueue": False,
        "commits": {"nodes": [{"commit": {"oid": head, "statusCheckRollup": {
            "state": "SUCCESS", "contexts": {"nodes": [], "totalCount": 0,
                "pageInfo": {"hasPreviousPage": False}}}}}]}}}}}
    response = scratch / f"{profile}-{phase}-response.json"
    response.write_text(json.dumps(body, separators=(",", ":")))
    cat = shutil.which("cat")
    if not cat: raise ValueError("local fixture reader unavailable")
    normalized, prior, gaps = [], {}, []
    bootstrap = time.perf_counter_ns() - started
    try:
        with isolated_environment({"AI_GH_STATE_DIR": str(measurement_state), "AI_GH_CALLER": "ai-pr-wait"}):
            for index, (stamp, target) in enumerate(trace):
                repeated = target in prior
                if repeated: gaps.append((stamp - prior[target]) // 1000000000)
                prior[target] = stamp
                clock.now = max(stamp, clock.now + 1000)
                output, error = Capture(), Capture()
                module.sys = SimpleNamespace(argv=["sharing", "--state-dir", str(cache), "--key", f"offline-target-{target}",
                    "--ttl", "10", "--wait-seconds", "30", "--expected-head", "a" * 40,
                    "--age-file", str(scratch / "age"), "--source-file", str(scratch / "source"), "--", cat,
                    str(response if fixture_failure != index else scratch / "missing-fixture")], stdout=output, stderr=error)
                sys.argv = module.sys.argv
                before_calls, before_unchanged = upstream_calls, unchanged_writes
                tick = time.perf_counter_ns(); status = module.main(); elapsed = time.perf_counter_ns() - tick
                if index == 0: elapsed += bootstrap
                normalized.append({"case_id": hashlib.sha256(f"{digest}:{profile}:{index}".encode()).hexdigest()[:32],
                    "operation": "verify_status", "outcome": "completed" if status == 0 else "failed",
                    "observed_completed_writes": None, "failed_write_attempts": None, "observed_external_writes": None,
                    "complete": False, "graphql_points": None,
                    "replay_reads": upstream_calls - before_calls if repeated else 0,
                    "unchanged_writes": unchanged_writes - before_unchanged,
                    "duration_ms": [elapsed // 1000000, math.ceil(elapsed / 1000000)], "detection_ms": None})
    finally:
        sys.path[:] = saved_path
        sys.argv[:] = saved_argv
        for name, previous in saved_modules.items():
            sys.modules.pop(name, None)
            if previous is not None: sys.modules[name] = previous
    return {"schema": 1, "phase": phase, "workload_kind": "offline_trace_replay", "source_sha": sha,
            "observations": normalized}, {
        "upstream_fixture_invocations": upstream_calls, "cache_content_writes": content_writes,
        "duplicate_unchanged_content_writes": unchanged_writes, "cache_metadata_refreshes": metadata_refreshes,
        "trace_reads": len(trace), "trace_targets": len(prior), "same_target_replays": len(gaps),
        "same_target_gaps_under_ttl": sum(gap < 10 for gap in gaps),
        "bootstrap_ns": bootstrap, "total_elapsed_ns": time.perf_counter_ns() - started,
        "source_sha": sha, "source_file_sha256": hashes,
        "http_requests": None, "graphql_points": None}


def run(root, measurements, output, expected_digest=FROZEN_INPUT):
    started = time.perf_counter_ns()
    if os.name != "posix": raise ValueError("POSIX offline cache replay required")
    trace, digest = read_trace(measurements, expected_digest)
    input_bootstrap = time.perf_counter_ns() - started
    destination = Path(output)
    if destination.exists(): raise ValueError("new private output directory required")
    destination.mkdir(mode=0o700)
    summary = {"schema": 1, "workload_kind": "offline_trace_replay", "input_sha256": digest,
               "execution_profile": "posix_serial_cache_replay", "shared_input_bootstrap_ns": input_bootstrap,
               "programme_acceptance": "not_evaluated", "http_requests": None, "graphql_points": None,
               "assumptions": ["recorded UTC completion seconds replayed as serial request arrivals",
                    "response bodies/heads and original request starts/overlap were not recorded",
                    "stable_open assumes identical valid OPEN responses; unknown_head disables TTL cache eligibility",
                    "fixture invocations are local file reads, never observed HTTP requests",
                    "duration measures local replay including bookkeeping, not useful-work or detection latency",
                    "content-write savings exclude necessary cache metadata refreshes"], "profiles": {}}
    with tempfile.TemporaryDirectory(prefix="658-offline-replay-") as temporary:
        scratch = Path(temporary)
        for profile in ("stable_open", "unknown_head"):
            summary["profiles"][profile] = {}
            for phase, sha in (("baseline", BASELINE), ("candidate", CANDIDATE)):
                normalized, counters = execute_phase(root, sha, phase, profile, trace, digest, scratch)
                artifact = destination / f"{profile}-{phase}.json"
                descriptor = os.open(artifact, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
                with os.fdopen(descriptor, "w") as stream: json.dump(normalized, stream, separators=(",", ":"))
                summary["profiles"][profile][phase] = counters
    summary["total_elapsed_ns"] = time.perf_counter_ns() - started
    descriptor = os.open(destination / "summary.json", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as stream: json.dump(summary, stream, indent=2)
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True); parser.add_argument("--measurements", required=True)
    parser.add_argument("--output", required=True)
    arguments = parser.parse_args()
    try:
        result = run(arguments.repository, arguments.measurements, arguments.output)
        print(json.dumps(result, sort_keys=True))
    except (OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError, RecursionError):
        parser.exit(2, "invalid or unavailable replay input; no acceptance claimed\n")
