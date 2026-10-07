#!/usr/bin/env python3
"""Paired local proof; no live workflow acceptance or deployment claims."""
import importlib.util
import argparse
import json
import os
import pathlib
import subprocess
import time
from sealed import verified_run

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("fixtures", HERE / "test_prototype.py")
fixtures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixtures)


def direct(case, kind):
    artifact = fixtures.MANIFEST["artifacts"][kind]
    env = case.env.copy()
    read_fd, write_fd = os.pipe()
    if kind == "instrumented":
        env.update(AI_GH_HTTP_COUNTER_FD=str(write_fd), AI_GH_HTTP_COUNTER_HOST=case.host)
    try:
        result = verified_run(artifact, ["api", "private"], env=env, pass_fds=(write_fd,),
                                capture_output=True, timeout=20)
        os.close(write_fd)
        write_fd = -1
        raw = os.read(read_fd, 4096)
        if kind == "instrumented":
            meta = fixtures.runner.validate(raw)
            assert meta["complete"] and meta["observed_completed_writes"] == 1
        return result
    finally:
        os.close(read_fd)
        if write_fd >= 0:
            os.close(write_fd)


def main():
    options = argparse.ArgumentParser()
    options.add_argument("--qualification-runner", action="store_true")
    args = options.parse_args()
    fixtures.PrototypeTests.setUpClass()
    case = fixtures.PrototypeTests()
    times = {"baseline": [], "instrumented": []}
    try:
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
