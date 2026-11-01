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
import hashlib
import tempfile
from unittest.mock import patch
from managed_read import ManagedReadObservation
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


def observer_groups(case):
    """The retained original two-cohort contract, including actual teardown.

    Canonical installer identity is mocked only inside this synthetic fixture;
    this never qualifies an installed generation or changes live routing.
    The ordinary comparison executes outside the source capsule.
    """
    import sys
    root = HERE.parents[2]
    sys.path.insert(0, str(root / 'tools/github-requests'))
    import report
    source_sha = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
    manifest_path = fixtures.MANIFEST_PATH
    manifest_digest = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
    transport_digest = hashlib.sha256((root / 'bin/ai-gh').read_bytes()).hexdigest()
    commands = [(arguments, expected) for arguments, expected in case.managed_fixture_cases()
                if tuple(arguments[:2]) not in (('auth', 'status'), ('workflow', 'list'), ('workflow', 'view'), ('api', 'graphql'))]
    commands = [([('popcre/ai-devops' if value == 'owner/fixture' else value) for value in args], expected)
                for args, expected in commands]
    results = {}
    with tempfile.TemporaryDirectory() as temporary, case.proxy(), tempfile.TemporaryFile() as output, tempfile.TemporaryFile() as error:
        temporary = pathlib.Path(temporary)
        waiter = temporary / 'ai-pr-wait'; waiter.symlink_to(root / 'bin/ai-pr-wait')
        data = (f'meta\tsource_sha\t{source_sha}\t-\nsymlink\t{waiter}\t{root}/bin/ai-pr-wait\t'
                + hashlib.sha256((root / 'bin/ai-pr-wait').read_bytes()).hexdigest() + '\n').encode()
        installer_manifest = temporary / 'installer.tsv'; installer_manifest.write_bytes(data); installer_manifest.chmod(0o600)
        for group in ('cold', 'warm'):
            environments = {}
            for kind in ('baseline', 'candidate'):
                environment = case.raw_env()
                environment.update(GH_HOST='github.com', AI_GH_MIN_SPACING_SECONDS='0')
                for key, name in (('HOME', 'home'), ('GH_CONFIG_DIR', 'config'), ('XDG_CACHE_HOME', 'cache'), ('TMPDIR', 'temp')):
                    directory = temporary / (group + '-' + kind + '-' + name); directory.mkdir(mode=0o700)
                    environment[key] = str(directory)
                environments[kind] = environment
            def ordinary(arguments, environment, executable):
                env = dict(environment, AI_GH_REAL_GH=executable, GH_PATH=executable)
                return subprocess.run(['/usr/bin/bash', str(root / 'bin/ai-gh'), *arguments],
                                      env=env, stdout=output, stderr=error, timeout=120).returncode
            with patch.object(report, 'canonical_installation', return_value=(data, waiter)):
                with report.retained_generation(root, installer_manifest) as boundary:
                    observer = ManagedReadObservation(manifest_path, manifest_digest,
                        transport_path=boundary['transport_path'], transport_sha256=transport_digest,
                        transport_boundary=boundary, environment=environments['candidate'])
                    with observer:
                        native = f'/proc/{os.getpid()}/fd/{observer._images["baseline"].fileno()}'
                        warmup_ns = {'baseline': 0, 'candidate': 0}
                        if group == 'warm':
                            for arguments, _expected in commands:
                                for kind, environment in environments.items():
                                    case.reset(); started = time.perf_counter_ns()
                                    assert ordinary(arguments, environment, native) == 0
                                    warmup_ns[kind] += time.perf_counter_ns() - started
                        times = {'baseline': [], 'candidate': []}; requests = {'baseline': [], 'candidate': []}
                        for ordinal in range(20):
                            arguments, _expected = commands[ordinal % len(commands)]
                            paired = {}
                            for kind in (('baseline', 'candidate') if ordinal % 2 == 0 else ('candidate', 'baseline')):
                                environment = environments[kind]
                                if group == 'cold':
                                    for path in (pathlib.Path(environment['GH_CONFIG_DIR']), pathlib.Path(environment['XDG_CACHE_HOME']), pathlib.Path(environment['HOME']) / '.ai-devops'):
                                        if path.exists(): shutil.rmtree(path)
                                    pathlib.Path(environment['GH_CONFIG_DIR']).mkdir(mode=0o700)
                                    pathlib.Path(environment['XDG_CACHE_HOME']).mkdir(mode=0o700)
                                case.reset(); output.seek(0); output.truncate(); error.seek(0); error.truncate()
                                started = time.perf_counter_ns()
                                if kind == 'baseline':
                                    status = ordinary(arguments, environment, native)
                                else:
                                    status, row = observer.run(arguments, f'{ordinal + 1:032x}', stdout=output, stderr=error)
                                    assert row['complete'] and row['transport_source_verified'] == 'verified'
                                    assert row['observed_completed_writes'] + row['observed_external_writes'] == case.server.received
                                times[kind].append(time.perf_counter_ns() - started)
                                requests[kind].append(case.server.received)
                                output.seek(0); error.seek(0)
                                paired[kind] = (status, output.read(), error.read(), case.server.received)
                            assert paired['baseline'] == paired['candidate'] and paired['baseline'][0] == 0
                        closing_started = time.perf_counter_ns()
                    teardown_ns = time.perf_counter_ns() - closing_started
                    summary = observer.summary()
                    assert summary['cohort_cleanup_complete']
                    source_closing_started = time.perf_counter_ns()
                source_teardown_ns = time.perf_counter_ns() - source_closing_started
                bootstrap = summary['bootstrap_ns'] + teardown_ns + source_teardown_ns
                p95 = {kind: sorted(values)[18] for kind, values in times.items()}
                p95_ratio = (p95['candidate'] + bootstrap / 20) / p95['baseline']
                total_ratio = (sum(times['candidate']) + bootstrap + warmup_ns['candidate']) / (sum(times['baseline']) + warmup_ns['baseline'])
                results[group] = {'paired_outcomes': 20, 'samples_ns': times, 'requests': requests,
                    'p95_ns': p95, 'cohort': summary, 'teardown_ns': teardown_ns,
                    'source_teardown_ns': source_teardown_ns, 'warmup_ns': warmup_ns,
                    'p95_ratio_with_bootstrap_amortized': p95_ratio,
                    'total_elapsed_ratio_including_bootstrap': total_ratio,
                    'passes_5_percent': p95_ratio <= 1.05 and total_ratio <= 1.05}
    return {'fixture_only': True, 'platform': 'linux-amd64', 'source_sha': source_sha,
            'scope': 'two independent twenty-pair local cohorts; ordinary outside-capsule baseline versus complete retained observer; all bootstrap, matched warmup and teardown included; not installed or natural-work acceptance',
            'groups': results, 'passes_5_percent': all(value['passes_5_percent'] for value in results.values())}


def main():
    options = argparse.ArgumentParser()
    options.add_argument("--qualification-runner", action="store_true")
    options.add_argument("--managed-commands", action="store_true")
    options.add_argument("--full-observer", action="store_true")
    args = options.parse_args()
    fixtures.PrototypeTests.setUpClass()
    case = fixtures.PrototypeTests()
    times = {"baseline": [], "instrumented": []}
    try:
        if args.full_observer:
            if args.managed_commands or args.qualification_runner:
                raise ValueError('full observer is a separate fixed fixture contract')
            result = observer_groups(case)
            print(json.dumps(result, separators=(',', ':')))
            if not result['passes_5_percent']:
                raise SystemExit(1)
            return
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
