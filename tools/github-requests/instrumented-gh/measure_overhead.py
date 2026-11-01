#!/usr/bin/env python3
"""Paired local proof; no live workflow acceptance or deployment claims."""
import importlib.util
import argparse
import json
import os
import pathlib
import subprocess
import time
import collections
import shutil
from sealed import verified_run

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("fixtures", HERE / "test_prototype.py")
fixtures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixtures)


def direct(case, kind, arguments=None, expected=1):
    artifact = fixtures.MANIFEST["artifacts"][kind]
    env = case.env.copy() if arguments is None else case.raw_env(artifact)
    read_fd, write_fd = os.pipe()
    if kind == "instrumented":
        env.update(AI_GH_HTTP_COUNTER_FD=str(write_fd), AI_GH_HTTP_COUNTER_HOST=case.host)
    try:
        result = verified_run(artifact, arguments or ["api", "private"], env=env, pass_fds=(write_fd,),
                                capture_output=True, timeout=20)
        os.close(write_fd)
        write_fd = -1
        raw = os.read(read_fd, 4096)
        if kind == "instrumented":
            meta = fixtures.runner.validate(raw)
            ledger_count = case.server.received if expected is None else expected
            assert meta["complete"] and meta["observed_completed_writes"] == ledger_count
        return result
    finally:
        os.close(read_fd)
        if write_fd >= 0:
            os.close(write_fd)


def managed_groups(case):
    """Same finite mixed workload, separate configurations, cold/warm groups."""
    groups = {}
    original = case.env.copy()
    commands = case.managed_fixture_cases()
    for group in ("cold", "warm"):
        environments = {}
        for kind in ("baseline", "instrumented"):
            environment = original.copy()
            for key, name in (("GH_CONFIG_DIR", "config"), ("HOME", "home"),
                              ("XDG_CACHE_HOME", "cache"), ("TMPDIR", "temp")):
                directory = pathlib.Path(case.scratch.name) / (group + "-" + kind + "-" + name)
                directory.mkdir(mode=0o700)
                environment[key] = str(directory)
            environments[kind] = environment
        if group == "warm":
            # Warm each configuration with the same whole census before any
            # timed pair; baseline state must never warm the candidate state.
            for arguments, expected in commands:
                outputs = {}
                for kind in ("baseline", "instrumented"):
                    case.env = environments[kind]
                    case.server.received, case.server.paths, case.server.retry = 0, [], False
                    result = direct(case, kind, arguments, None)
                    assert result.returncode == 0
                    outputs[kind] = (result.stdout, result.stderr, result.returncode, case.server.received)
                assert outputs["baseline"] == outputs["instrumented"]
        times = {"baseline": [], "instrumented": []}
        requests = {"baseline": [], "instrumented": []}
        families = collections.Counter()
        for ordinal in range(20):
            arguments, expected = commands[ordinal % len(commands)]
            families[".".join(arguments[:2])] += 1
            outputs = {}
            for kind in (("baseline", "instrumented") if ordinal % 2 == 0 else ("instrumented", "baseline")):
                case.env = environments[kind]
                if group == "cold":
                    for key in ("GH_CONFIG_DIR", "XDG_CACHE_HOME"):
                        shutil.rmtree(case.env[key])
                        pathlib.Path(case.env[key]).mkdir(mode=0o700)
                case.server.received, case.server.paths, case.server.retry = 0, [], False
                started = time.perf_counter_ns()
                result = direct(case, kind, arguments, expected if group == "cold" else None)
                times[kind].append(time.perf_counter_ns() - started)
                assert result.returncode == 0
                if group == "cold":
                    assert case.server.received == expected
                requests[kind].append(case.server.received)
                outputs[kind] = (result.stdout, result.stderr, result.returncode, case.server.received)
            assert outputs["baseline"] == outputs["instrumented"]
        p95 = {kind: sorted(samples)[18] for kind, samples in times.items()}
        groups[group] = {"paired_outcomes": 20, "command_family_counts": dict(families),
                         "p95_ns": p95, "samples_ns": times, "upstream_requests": requests,
                         "p95_ratio": p95["instrumented"] / p95["baseline"],
                         "total_ratio": sum(times["instrumented"]) / sum(times["baseline"])}
        groups[group]["passes_5_percent"] = (groups[group]["p95_ratio"] <= 1.05
                                             and groups[group]["total_ratio"] <= 1.05)
    case.env = original
    return {"platform": "linux-amd64", "groups": groups,
            "passes_5_percent": all(group["passes_5_percent"] for group in groups.values()),
            "scope": "finite managed commands against trusted local server; sealed image/hash, inherited private pipe, drain and validation included; no installed workflow or whole-account claim"}


def main():
    options = argparse.ArgumentParser()
    options.add_argument("--qualification-runner", action="store_true")
    options.add_argument("--managed-commands", action="store_true")
    args = options.parse_args()
    fixtures.PrototypeTests.setUpClass()
    case = fixtures.PrototypeTests()
    times = {"baseline": [], "instrumented": []}
    try:
        if args.managed_commands:
            if args.qualification_runner:
                raise ValueError("managed command fixtures do not expand the qualification runner")
            result = managed_groups(case)
            print(json.dumps(result, separators=(",", ":")))
            if not result["passes_5_percent"]:
                raise SystemExit(1)
            return
        # Alternating order reduces systematic warm/cold bias.
        for ordinal in range(20):
            outputs = {}
            for kind in (("baseline", "instrumented") if ordinal % 2 == 0 else ("instrumented", "baseline")):
                case.reset()
                started = time.perf_counter()
                if args.qualification_runner and kind == "instrumented":
                    result, _ = case.execute(kind, ["api", "private"])
                else:
                    result = direct(case, kind)
                times[kind].append((time.perf_counter() - started) * 1000)
                assert result.returncode == 0 and case.server.received == 1
                outputs[kind] = (result.stdout, result.stderr, result.returncode)
            assert outputs["baseline"] == outputs["instrumented"]
        p95 = {kind: sorted(samples)[18] for kind, samples in times.items()}
        print(json.dumps({"platform": "linux-amd64", "paired_outcomes": 20, "p95_ms": p95,
                          "p95_overhead_percent": (p95["instrumented"] / p95["baseline"] - 1) * 100,
                          "passes_5_percent": p95["instrumented"] <= p95["baseline"] * 1.05,
                          "scope": ("qualification-only Python/hash runner versus direct native baseline; excludes installed workflow"
                                    if args.qualification_runner else
                                    "paired sealed verified binary/hash/private-pipe local fixture; excludes installed workflow"),
                          "samples_ms": times}, separators=(",", ":")))
    finally:
        fixtures.PrototypeTests.tearDownClass()


if __name__ == "__main__":
    main()
