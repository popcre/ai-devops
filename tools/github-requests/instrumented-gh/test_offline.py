#!/usr/bin/env python3
"""Offline metadata-contract tests; do not claim Go/build/live qualification."""
import importlib.util
import json
import os
import pathlib
import tempfile
import shutil
import sys
import unittest
import socket
import array
import subprocess
import signal
import time
from unittest.mock import patch

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from source_binding import source_binding, validate_source_binding, version_profile
from numeric_receipt import validate_receipt
from managed_read import aggregate_invocations, managed_read_label
from managed_read import _packet_send, _packet_receive, _WORKER_BOOTSTRAP
from build import patch as patch_counter_source
spec = importlib.util.spec_from_file_location("counter_runner", HERE / "run.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


def channel(**overrides):
    final = {"schema": 1, "finished": True, "observed_completed_writes": 4,
             "failed_write_attempts": 0, "observed_external_writes": 1,
             "incomplete": False, "http_requests": None}
    final.update(overrides)
    return b'{"schema":1,"started":true}\n' + json.dumps(final).encode() + b"\n"


class OfflineContract(unittest.TestCase):
    def test_shared_version_profiles_reject_unknown_or_unpinned_sources(self):
        runtime = version_profile(HERE / 'pins.json')
        self.assertEqual(runtime['profile_kind'], 'runtime')
        self.assertEqual(version_profile(HERE / 'pins.json', '2.101.0')['profile_kind'], 'historical')
        for version in ('0.0.0', '../2.101.0', True):
            with self.subTest(version=version), self.assertRaises(ValueError):
                version_profile(HERE / 'pins.json', version)
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / 'pins.json'
            registry = json.loads((HERE / 'pins.json').read_text())
            registry['profiles'][registry['default_profile']]['source_url'] = 'https://untrusted.invalid/archive'
            path.write_text(json.dumps(registry))
            with self.assertRaises(ValueError):
                version_profile(path)

    def test_patch_profiles_reject_missing_unexpected_constructor_and_import(self):
        def source(root, hooks, imported, directory, final=True):
            (root / 'api').mkdir()
            (root / 'internal').mkdir()
            (root / 'cmd/gh').mkdir(parents=True)
            if directory:
                (root / 'internal/gh/ghtelemetry').mkdir(parents=True)
            client = root / 'api/http_client.go'
            client.write_text('package api\nimport (\n\t"net/http"\n'
                              + ('\t"github.com/cli/cli/v2/internal/gh/ghtelemetry"\n' if imported else '')
                              + ')\n' + '\treturn client, nil\n' * hooks)
            (root / 'cmd/gh/main.go').write_text('package main\nimport "github.com/cli/cli/v2/internal/ghcmd"\n'
                                               + ('\tcode := ghcmd.Main()\n' if final else ''))
            return client
        for expected, telemetry in ((1, False), (2, True)):
            capabilities = {'api_constructor_hooks': expected, 'detached_telemetry': telemetry}
            with tempfile.TemporaryDirectory() as directory:
                root = pathlib.Path(directory)
                client = source(root, expected, telemetry, telemetry)
                patch_counter_source(root, capabilities)
                self.assertEqual(client.read_text().count('httpcounter.Wrap(client.Transport)'), expected)
                self.assertIn('httpcounter.Finish()', (root / 'cmd/gh/main.go').read_text())
            for actual_hooks, imported, directory, final in (
                    (3 - expected, telemetry, telemetry, True),
                    (expected, not telemetry, telemetry, True),
                    (expected, telemetry, not telemetry, True),
                    (expected, telemetry, telemetry, False)):
                with self.subTest(expected_hooks=expected, actual_hooks=actual_hooks, imported=imported, final=final):
                    with tempfile.TemporaryDirectory() as temporary:
                        root = pathlib.Path(temporary)
                        client = source(root, actual_hooks, imported, directory, final)
                        before = client.read_bytes()
                        with self.assertRaises(ValueError):
                            patch_counter_source(root, capabilities)
                        self.assertEqual(client.read_bytes(), before)

    def test_admission_invocations_aggregate_only_complete_sequential_pairs(self):
        result = aggregate_invocations(channel() + channel(observed_completed_writes=2))
        self.assertTrue(result['complete'])
        self.assertEqual(result['observed_completed_writes'], 6)
        self.assertEqual(result['counted_invocations'], 2)
        self.assertIsNone(result['http_requests'])
        start = b'{"schema":1,"started":true}\n'
        for raw in (b'', start, start + channel(), channel() + start,
                    channel(incomplete=True), channel(failed_write_attempts=1),
                    channel() + b'fake-secret-sentinel\n', channel() * 65):
            with self.subTest(size=len(raw)):
                result = aggregate_invocations(raw)
                self.assertFalse(result['complete'])
                self.assertIsNone(result['observed_completed_writes'])
                self.assertIsNone(result['counted_invocations'])

    def test_managed_builtin_profile_rejects_aliases_mutations_and_implicit_context(self):
        self.assertEqual(managed_read_label(['issue', 'view', '658', '--repo', 'popcre/ai-devops',
                                             '--json', 'number,state']), 'issue.view')
        for arguments in (['issue', 'view', '658', '--json', 'number'],
                          ['issue', 'view', '658', '-R', 'popcre/ai-devops', '--repo', 'popcre/ai-devops', '--json', 'number'],
                          ['issue', 'view', '658', '-R', 'popcre/ai-devops', '--web'],
                          ['pr', 'merge', '1', '-R', 'popcre/ai-devops'],
                          ['alias', 'set', 'fake', '!executor'],
                          ['api', 'graphql', '-f', 'query=mutation{x}']):
            with self.subTest(command=arguments[:2]), self.assertRaises(ValueError):
                managed_read_label(arguments)

    def controlled_environment(self, root, host='fixture'):
        paths = {name: root / name for name in ('config', 'home', 'cache', 'temp')}
        for path in paths.values():
            path.mkdir(mode=0o700)
        return {
            'GH_CONFIG_DIR': str(paths['config']), 'GH_HOST': host,
            'GH_TOKEN': 'fake-token-sentinel', 'GH_PAGER': '',
            'GH_PROMPT_DISABLED': '1', 'HOME': str(paths['home']),
            'XDG_CACHE_HOME': str(paths['cache']), 'TMPDIR': str(paths['temp']),
            'PATH': '',
        }

    def test_controlled_profile_is_positive_and_rejects_ambient_selection(self):
        with tempfile.TemporaryDirectory() as directory:
            env = self.controlled_environment(pathlib.Path(directory))
            with patch.dict(os.environ, env, clear=True):
                # This observer profile requires POSIX descriptor/owner checks.
                # Windows qualification uses the separate native fixture and
                # must refuse this profile rather than infer POSIX security.
                self.assertEqual(runner.validate_profile('fixture'), os.name == 'posix')
                for name, value in (('PAGER', '/sentinel'), ('GH_PATH', '/sentinel'),
                                    ('GIT_CONFIG_GLOBAL', '/sentinel'), ('PATH', '/sentinel'),
                                    ('GH_FORCE_TTY', '1'), ('PYTHONHOME', '/sentinel')):
                    with self.subTest(name=name):
                        with patch.dict(os.environ, {name: value}):
                            self.assertFalse(runner.validate_profile('fixture'))

    def test_rejected_entrypoints_do_not_open_or_launch(self):
        with tempfile.TemporaryDirectory() as directory:
            env = self.controlled_environment(pathlib.Path(directory))
            with patch.dict(os.environ, env, clear=True), patch.object(runner, 'eligible', return_value=False), \
                    patch('builtins.open', side_effect=AssertionError('binary opened')), \
                    patch('subprocess.Popen', side_effect=AssertionError('child launched')):
                self.assertEqual(runner.run_counted('/missing', ['auth', 'login'], 'fixture', '0' * 64),
                                 (2, runner.UNKNOWN))
                self.assertEqual(runner.run_verified(None, '/missing', ['auth', 'login'], 'fixture'),
                                 (2, runner.UNKNOWN))

    def test_entrypoints_bind_hostname_and_host_header_before_launch(self):
        with tempfile.TemporaryDirectory() as directory:
            env = self.controlled_environment(pathlib.Path(directory))
            with patch.dict(os.environ, env, clear=True), patch('sealed.verified_snapshot', side_effect=AssertionError('binary opened')), \
                    patch('subprocess.Popen', side_effect=AssertionError('child launched')):
                for args in (['api', 'private', '--hostname=other'],
                             ['api', 'private', '--header=Host: other']):
                    with self.subTest(args=args):
                        self.assertEqual(runner.run_counted('/missing', args, 'fixture', '0' * 64),
                                         (2, runner.UNKNOWN))
                        self.assertEqual(runner.run_verified(None, '/missing', args, 'fixture'),
                                         (2, runner.UNKNOWN))

    def test_windows_fixed_namespace_static_adversarial_contract(self):
        # Static source-bound contract/model only; native Windows execution
        # remains mandatory and is never inferred from these offline cases.
        import ntpath
        import re
        script = (HERE / "native_fixture.ps1").read_text()
        self.assertIn("$programFilesRoot = [Environment]::GetFolderPath('ProgramFiles')", script)
        self.assertIn("$allowedParents = @([IO.Path]::GetFullPath($temporaryRoot), [IO.Path]::GetFullPath($programFilesRoot))", script)
        self.assertIn("[IO.Path]::GetDirectoryName($root) -notin $allowedParents -or", script)
        self.assertIn("'^ai-devops-gh-counter-[a-f0-9]{16,32}$'", script)
        self.assertIn(".DriveType -ne 'Fixed'", script)
        self.assertIn("$root.StartsWith('\\\\')", script)
        self.assertNotIn("$env:AI_GH_COUNTER_ROOT", script)
        self.assertNotIn("CreateDirectory($programFilesRoot", script)
        parents = (r"C:\Users\owner\AppData\Local\Temp", r"C:\Program Files")
        name = "ai-devops-gh-counter-" + "a" * 32

        def admitted(path, fixed=True):
            path = ntpath.normpath(path)
            return (fixed and not path.startswith("\\\\")
                    and ntpath.dirname(path).lower() in [p.lower() for p in parents]
                    and re.fullmatch(r"ai-devops-gh-counter-[a-f0-9]{16,32}", ntpath.basename(path), re.I) is not None)

        for parent in parents:
            self.assertTrue(admitted(ntpath.join(parent, name)))
            self.assertFalse(admitted(ntpath.join(parent, name), fixed=False))
            for child in ("ai-devops-gh-counter-", "ai-devops-gh-counter-" + "a"*15,
                          "ai-devops-gh-counter-" + "a"*33, "ai-devops-gh-counter-" + "g"*32,
                          name + r"\child", "prefix-" + name):
                self.assertFalse(admitted(ntpath.join(parent, child)))
        for parent in (r"C:\Program Files\ai-devops", r"C:\Program Files\nested",
                       r"C:\arbitrary", r"\\server\Program Files"):
            self.assertFalse(admitted(ntpath.join(parent, name)))

    def test_windows_static_launch_boundary(self):
        script = (HERE / "native_fixture.ps1").read_text()
        for boundary in ("0x02200000", "0x00200000", "GetSecurityInfo(file, 1, 5",
                         "DiscretionaryAclPresent", "DiscretionaryAclProtected", "dacl == IntPtr.Zero",
                         "GetFileInformationByHandle", "GetFinalPathNameByHandle",
                         "Reparse handle refused", "info.Links != 1", "AssertPathBinding",
                         "Digest $stream", "Reviewed manifest digest mismatch",
                         "RunBoundaryFixtures($root)", "Launch fixture must be staged",
                         "0x8664", "$start.Arguments = '-test.run=^TestWindows -test.timeout=5m'",
                         "$start.EnvironmentVariables.Clear()", "$start.UseShellExecute = $false"):
            self.assertIn(boundary, script)
        for forbidden in ("Start-Process", "NamedPipeServerStream", "Set-Acl", "ExecutionPolicy Bypass", "DownloadString"):
            self.assertNotIn(forbidden, script)
        source = (HERE / "channel_windows.go").read_text()
        self.assertIn("SetHandleInformation(handle, windows.HANDLE_FLAG_INHERIT, 0)", source)
        self.assertIn("inSize <= channelLifetimeBound", source)
        self.assertNotIn("syscall.Fstat", source)
        self.assertLess(script.index('Assert-BootstrapPrivateDirectory $privateTemp'), script.index("Add-Type -TypeDefinition"))
        self.assertLess(script.index('$env:TEMP = $privateTemp'), script.index("Add-Type -TypeDefinition"))
        self.assertIn('$env:TMP = $privateTemp', script)
        self.assertIn('[void](Lock-Directory $privateTemp $true)', script)
        self.assertIn('AI_GH_COUNTER_FIXTURE_FUTURE_SENTINEL', script)
        self.assertIn('Ambient qualification control survived', script)
        self.assertIn('foreach ($key in $savedEnvironment.Keys)', script)

    def test_windows_numeric_receipt_schema_and_bindings(self):
        import copy
        pins = version_profile(HERE / "pins.json")
        binding = source_binding(HERE)
        manifest = {"pins": pins, "counter_source_binding": binding,
                    "compiled_counter_source_binding": binding,
                    "artifacts": {kind: {"sha256": "ab" * 32} for kind in ("baseline", "instrumented", "native_fixture")}}
        receipt = {"schema": 1, "execution_exit_code": 0, "selection_verified": True, "http_requests": None,
                   "source_commit": list(bytes.fromhex(pins["upstream_commit"])),
                   "source_archive_sha256": list(bytes.fromhex(pins["source_sha256"])),
                   "toolchain_archive_sha256": list(bytes.fromhex(pins["toolchain_sha256"])),
                   "input_sources_sha256": [list(bytes.fromhex(value)) for value in binding["files"].values()],
                   "compiled_sources_sha256": [list(bytes.fromhex(value)) for value in binding["files"].values()],
                   "binary_sha256": [[171]*32 for _ in range(3)],
                   **{key: [1000]*20 for key in ("cold_baseline_ns", "cold_candidate_ns", "warm_baseline_ns", "warm_candidate_ns")}}
        result = validate_receipt(receipt, manifest)
        self.assertTrue(result["native_execution_complete"])
        self.assertFalse(result["installed_acceptance"])
        for key, value in (("source_commit", "private-route"), ("source_commit", [0]*20),
                           ("cold_baseline_ns", [float('nan')]*20), ("schema", True),
                           ("http_requests", 1), ("unexpected", "fake-secret")):
            changed = copy.deepcopy(receipt); changed[key] = value
            with self.assertRaises(ValueError): validate_receipt(changed, manifest)
        changed = copy.deepcopy(receipt); changed["execution_exit_code"] = 1
        self.assertFalse(validate_receipt(changed, manifest)["native_execution_complete"])

    def test_complete_source_binding_rejects_missing_changed_and_extra(self):
        binding = source_binding(HERE)
        validate_source_binding(binding, HERE)
        with self.assertRaises(ValueError): validate_source_binding({**binding, "schema": True}, HERE)
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            for name in binding["files"]:
                shutil.copyfile(HERE / name, root / name)
            for name in binding["files"]:
                original = (root / name).read_bytes()
                (root / name).unlink()
                with self.assertRaises(ValueError): validate_source_binding(binding, root)
                (root / name).write_bytes(original + b"\n")
                with self.assertRaises(ValueError): validate_source_binding(binding, root)
                (root / name).write_bytes(original)
            (root / "extra.go").write_text("package httpcounter\n")
            with self.assertRaises(ValueError): validate_source_binding(binding, root)

    def test_tracing_bodies_still_match_reviewed_dependency(self):
        import hashlib
        # Git may check Go text out with CRLF on Windows. Only newline encoding
        # is normalized for this reviewed tracing-body comparison; the real
        # source binding below remains a strict hash of the complete raw bytes.
        current = (HERE / "httpcounter.go").read_bytes().replace(b"\r\n", b"\n")
        marker = b"type transport struct"
        # Reviewed d360ed8a tracing suffix, independent of checkout history.
        self.assertEqual(hashlib.sha256(current[current.index(marker):]).hexdigest(),
                         "5add97c5d873d552068fe0430a114e736d9b020548af08eee73dd96318a18f2b")

    def test_builtin_scope_excludes_durable_and_arbitrary_children(self):
        for args in (['api', '/private'], ['api', '/pages', '--paginate'],
                     ['api', '/private', '-XGET'], ['api', '/private', '--hostname=fixture']):
            self.assertTrue(runner.eligible(args, 'fixture'))
        for args in ([], ['auth', 'setup-git'], ['auth', 'login'], ['skills', 'install'],
                     ['codespace', 'ssh'], ['alias', 'set'], ['fixture-extension'],
                     ['api', '/private', '-XPOST'],
                     ['api', '/private', '--method=DELETE'], ['api', '/private', '-fquery=mutation'],
                     ['api', '/private', '--header=Host: other'], ['api', '/private', '--help'],
                     ['api', '/repos/{owner}/x'], ['api', '/graphql'], ['api', '/private', '/extra']):
            self.assertFalse(runner.eligible(args, 'fixture'))

    def test_literal_api_parser_rejects_executor_expansion_and_ambiguous_tokens(self):
        accepted = (
            ['api', '/user'], ['api', '/user', '--method', 'HEAD'],
            ['api', '/user', '-XGET', '--silent', '--include'],
            ['api', '/x?state=open%2Fnow', '--cache=60s', '-q.'],
        )
        for args in accepted:
            self.assertTrue(runner.eligible(args, 'fixture'), args)
        rejected = (
            ['api', '/x', '--method'], ['api', '/x', '--method', 'GET', '-XHEAD'],
            ['api', '/x', '--', '--silent'], ['api', '/x', '--input=/tmp/x'],
            ['api', '/x', '--field=x'], ['api', '/x', '-sHfoo'],
            ['api', '/x', '/extra'], ['api', '/x', '--header=Host: other'],
            ['api', '/x', '--header=Bad\r\nHeader: x'],
            ['api', '/repos/:owner/:repo/:branch'], ['api', '/x/%257Bowner%257D'],
            ['api', '/x/%ZZ'], ['api', 'https://example.test/x'],
        )
        for args in rejected:
            self.assertFalse(runner.eligible(args, 'fixture'), args)

    def test_completed_subset_remains_unknown_total(self):
        record = runner.validate(channel())
        self.assertTrue(record["complete"])
        self.assertEqual(record["observed_completed_writes"], 4)
        self.assertIsNone(record["http_requests"])

    def test_failed_write_is_partial(self):
        record = runner.validate(channel(failed_write_attempts=1, incomplete=True))
        self.assertFalse(record["complete"])
        self.assertEqual(record["observed_completed_writes"], 4)
        self.assertIsNone(record["http_requests"])

    def test_malformed_or_oversized_channel_is_unknown(self):
        for raw in (b"", b'[]\n', b'null\n', b'fake-secret-sentinel', b'x' * 4097,
                    b'{"schema":1,"started":true}\n',
                    channel() + b'{}\n', channel().replace(b'"started":true', b'"started":1'),
                    channel().replace(b'"schema":1', b'"schema":false,"schema":1')):
            self.assertEqual(runner.validate(raw), runner.UNKNOWN)

    def test_invalid_counts_and_extra_content_are_unknown(self):
        for key in ("observed_completed_writes", "failed_write_attempts", "observed_external_writes"):
            for value in (True, -1, 1000000001, 1.0, "4", None):
                self.assertEqual(runner.validate(channel(**{key: value})), runner.UNKNOWN)
        self.assertEqual(runner.validate(channel(error="fake-secret-sentinel")), runner.UNKNOWN)
        self.assertEqual(runner.validate(channel(http_requests=4)), runner.UNKNOWN)


@unittest.skipUnless(sys.platform.startswith('linux'), 'Linux inherited cohort capability')
class CohortContract(unittest.TestCase):
    def test_packet_rejects_duplicate_nonfinite_oversized_and_closes_received_handles(self):
        for raw in (b'{"sequence":1,"sequence":2}', b'{"number":NaN}', b'x' * 4097, b'[]'):
            with self.subTest(raw_length=len(raw)):
                left, right = socket.socketpair(socket.AF_UNIX, socket.SOCK_SEQPACKET)
                descriptor = os.open(os.devnull, os.O_RDONLY)
                try:
                    before = len(os.listdir('/proc/self/fd'))
                    left.sendmsg([raw], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array('i', [descriptor]))])
                    with self.assertRaises(ValueError):
                        _packet_receive(right)
                    self.assertEqual(len(os.listdir('/proc/self/fd')), before)
                finally:
                    os.close(descriptor); left.close(); right.close()

    def test_truncated_ancillary_closes_every_received_descriptor(self):
        left, right = socket.socketpair(socket.AF_UNIX, socket.SOCK_SEQPACKET)
        descriptor = os.open(os.devnull, os.O_RDONLY)
        try:
            before = len(os.listdir('/proc/self/fd'))
            left.sendmsg([b'{}'], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array('i', [descriptor] * 40))])
            with self.assertRaises(ValueError):
                _packet_receive(right)
            self.assertEqual(len(os.listdir('/proc/self/fd')), before)
        finally:
            os.close(descriptor); left.close(); right.close()

    def worker(self, directory, body, environment=None):
        transport = pathlib.Path(directory) / 'ai-gh'
        transport.write_text(body)
        left, right = socket.socketpair(socket.AF_UNIX, socket.SOCK_SEQPACKET)
        process = subprocess.Popen([sys.executable, '-I', '-S', '-c', _WORKER_BOOTSTRAP,
             str(HERE / 'managed_read.py'), '--private-cohort-worker',
             str(right.fileno()), '/usr/bin/bash', str(transport), '/usr/bin/true', '/usr/bin/true', '12030'],
             pass_fds=(right.fileno(),), start_new_session=True, stdin=subprocess.DEVNULL,
             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=environment)
        right.close(); left.settimeout(4)
        self.addCleanup(left.close)
        def stop():
            if process.returncode is None:
                try: os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError: pass
                process.wait(timeout=4)
        self.addCleanup(stop)
        ready, descriptors = _packet_receive(left)
        self.assertEqual(ready, {'ready': 1, 'pid': process.pid})
        self.assertEqual(descriptors, [])
        return left, process

    def request(self, **changes):
        return dict(sequence=1, kind='instrumented', arguments=['issue', 'view', '658', '--repo', 'popcre/ai-devops', '--json', 'number'],
                    workflow_id='a' * 32, timeout_seconds=2, **changes)

    def test_worker_preserves_streams_exit_and_excludes_controller_from_exec(self):
        with tempfile.TemporaryDirectory() as directory, tempfile.TemporaryFile() as out, tempfile.TemporaryFile() as err:
            # This child executes a fresh image and checks actual inherited
            # descriptors; the controller socket must never cross exec.
            code = 'import os,stat;assert not any(stat.S_ISSOCK(os.fstat(n).st_mode) for n in range(3,128) if os.path.exists("/proc/self/fd/"+str(n)));print("exact stdout");os.write(2,b"exact stderr\\n");raise SystemExit(7)'
            import shlex
            channel, process = self.worker(directory, 'exec ' + shlex.quote(sys.executable) + ' -c ' + shlex.quote(code))
            descriptor = os.open(os.devnull, os.O_RDONLY)
            read, write = os.pipe()
            try:
                _packet_send(channel, self.request(), (descriptor, out.fileno(), err.fileno(), write))
                os.close(write); write = -1
                self.assertEqual(_packet_receive(channel), ({'sequence': 1, 'status': 7, 'stopped': False}, []))
                out.seek(0); err.seek(0)
                self.assertEqual(out.read(), b'exact stdout\n')
                self.assertEqual(err.read(), b'exact stderr\n')
                self.assertEqual(os.read(read, 1), b'')
            finally:
                os.close(descriptor); os.close(read)
                if write >= 0: os.close(write)

    def test_malformed_command_refuses_without_execution_or_descriptor_leak(self):
        variants = [({'sequence': True}, 4), ({'timeout_seconds': True}, 4), ({'sequence': 2}, 4),
                    ({'arguments': ['api', 'repos/private']}, 4), ({}, 3), ({}, 5)]
        for changes, count in variants:
            with self.subTest(changes=changes, count=count), tempfile.TemporaryDirectory() as directory:
                marker = pathlib.Path(directory) / 'executed'
                channel, process = self.worker(directory, 'touch ' + str(marker))
                descriptor = os.open(os.devnull, os.O_RDWR)
                try:
                    value = self.request(); value.update(changes)
                    _packet_send(channel, value, [descriptor] * count)
                    process.wait(timeout=4)
                    self.assertFalse(marker.exists())
                    self.assertNotEqual(process.returncode, 0)
                finally: os.close(descriptor)

    def test_timeout_stops_the_owned_group_without_replay(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = pathlib.Path(directory) / 'executed'
            pidfile = pathlib.Path(directory) / 'grandchild'
            channel, process = self.worker(directory, 'echo once >> ' + str(marker) + '; sleep 10 & echo $! > ' + str(pidfile) + '; wait')
            descriptor = os.open(os.devnull, os.O_RDWR)
            try:
                value = self.request(); value['timeout_seconds'] = 1
                _packet_send(channel, value, [descriptor] * 4)
                self.assertEqual(_packet_receive(channel), ({'sequence': 1, 'status': 124, 'stopped': True}, []))
                process.wait(timeout=4)
                self.assertEqual(process.returncode, 0)
                self.assertEqual(marker.read_text().splitlines(), ['once'])
                self.assertFalse(pathlib.Path('/proc', pidfile.read_text().strip()).exists())
            finally: os.close(descriptor)

    def test_normal_close_and_cancellation_reap_actual_adopted_grandchild(self):
        for cancel in (False, True):
            with self.subTest(cancel=cancel), tempfile.TemporaryDirectory() as directory:
                pidfile = pathlib.Path(directory) / 'grandchild'
                body = 'sleep 30 & echo $! > ' + str(pidfile) + ('; wait' if cancel else '; exit 0')
                channel, process = self.worker(directory, body)
                descriptor = os.open(os.devnull, os.O_RDWR)
                try:
                    _packet_send(channel, self.request(), [descriptor] * 4)
                    if cancel:
                        for _ in range(200):
                            if pidfile.exists() and pidfile.read_text().strip(): break
                            time.sleep(0.005)
                        self.assertTrue(pidfile.exists())
                        os.kill(process.pid, signal.SIGINT)
                    expected = {'sequence': 1, 'status': 130 if cancel else 0, 'stopped': cancel}
                    self.assertEqual(_packet_receive(channel), (expected, []))
                    if not cancel: _packet_send(channel, {'close': 1})
                    process.wait(timeout=4)
                    self.assertEqual(process.returncode, 0)
                    self.assertFalse(pathlib.Path('/proc', pidfile.read_text().strip()).exists())
                finally: os.close(descriptor)

    def test_forty_command_limit_does_not_execute_a_forty_first(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = pathlib.Path(directory) / 'executed'
            channel, process = self.worker(directory, 'echo once >> ' + str(marker))
            descriptor = os.open(os.devnull, os.O_RDWR)
            try:
                for ordinal in range(1, 41):
                    value = self.request(); value['sequence'] = ordinal
                    _packet_send(channel, value, [descriptor] * 4)
                    self.assertEqual(_packet_receive(channel), ({'sequence': ordinal, 'status': 0, 'stopped': False}, []))
                process.wait(timeout=4)
                self.assertEqual(marker.read_text().splitlines(), ['once'] * 40)
                with self.assertRaises((OSError, ValueError)):
                    _packet_send(channel, self.request(), [descriptor] * 4)
                    _packet_receive(channel)
            finally: os.close(descriptor)

    def test_isolated_worker_ignores_hostile_user_site_without_changing_child_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            home = pathlib.Path(directory)
            site = home / '.local/lib' / ('python%d.%d' % sys.version_info[:2]) / 'site-packages'
            site.mkdir(parents=True)
            marker = home / 'startup-executed'
            injection = 'import pathlib;pathlib.Path(%r).write_text("injected")' % str(marker)
            (site / 'sitecustomize.py').write_text(injection)
            (site / 'usercustomize.py').write_text(injection)
            (site / 'injection.pth').write_text(injection + '\n')
            environment = dict(os.environ, HOME=directory, ORIGINAL_TEST_VALUE='kept exactly')
            output = home / 'original-env'
            channel, process = self.worker(directory, 'printf "%s" "$ORIGINAL_TEST_VALUE" > ' + str(output), environment)
            descriptor = os.open(os.devnull, os.O_RDWR)
            try:
                _packet_send(channel, self.request(), [descriptor] * 4)
                self.assertEqual(_packet_receive(channel), ({'sequence': 1, 'status': 0, 'stopped': False}, []))
                _packet_send(channel, {'close': 1}); process.wait(timeout=4)
                self.assertFalse(marker.exists())
                self.assertEqual(output.read_text(), 'kept exactly')
            finally: os.close(descriptor)


if __name__ == "__main__":
    unittest.main()
