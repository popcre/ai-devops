#!/usr/bin/env python3
"""Trusted local server parity/hidden-retry proof. No GitHub writes or tokens."""
import hashlib
import http.server
import importlib.util
import json
import os
import pathlib
import signal
import socket
import ssl
import subprocess
from sealed import verified_run
import sys
import threading
import tempfile
import time
import unittest
import select
import shutil
import socketserver
import pty
from sealed import verified_snapshot
from urllib.parse import urlsplit, parse_qs

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("counter_runner", HERE / "run.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
MANIFEST = json.loads(pathlib.Path(sys.argv.pop(1)).read_text()) if len(sys.argv) > 1 else None


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_args):
        pass

    def reply(self, body, status=200, headers=None):
        body = json.dumps(body).encode()
        self.send_response(status)
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        # Parse synthetic operation names only; never retain request bytes,
        # headers, tokens or variable values in the trusted ledger.
        body = self.rfile.read(int(self.headers.get('Content-Length', 0)))
        if self.path.startswith('/fixture-telemetry'):
            self.server.telemetry_received += 1
            self.reply({})
            return
        payload = json.loads(body)
        query, variables = payload.get('query', ''), payload.get('variables') or {}
        with self.server.lock:
            self.server.received += 1
        operation = next((name for name in ('UserCurrent', 'Issue_fields', 'PullRequest_fields2',
                        'PullRequest_fields', 'IssueList', 'PullRequestSearch', 'PullRequestByNumber',
                        'PullRequestStatusChecks', 'IssueByNumber', 'RepositoryInfo', 'CommentsForIssue',
                        'CommentsForPullRequest') if name in query), 'context')
        self.server.paths.append(operation)
        page2 = bool(variables.get('endCursor'))
        connection = {'totalCount': 2, 'issueCount': 2, 'nodes': [{'number': 2 if page2 else 1}],
                      'pageInfo': {'hasNextPage': not page2, 'endCursor': 'second'}}
        checks = {'nodes': [{'__typename': 'StatusContext', 'context': 'fixture', 'state': 'SUCCESS',
                             'targetUrl': '', 'createdAt': '2026-10-07T00:00:00Z'}],
                  'pageInfo': {'hasNextPage': not page2, 'endCursor': 'second'}}
        pr = {'id': 'PR_fixture', 'number': 1, 'title': 'fixture', 'state': 'OPEN',
              'statusCheckRollup': {'nodes': [{'commit': {'statusCheckRollup': {'contexts': checks}}}]}}
        comments = {'totalCount': 2, 'nodes': [{'id': 'comment-2' if page2 else 'comment-1',
                    'body': 'fixture', 'author': {'login': 'fixture'}, 'createdAt': '2026-10-07T00:00:00Z'}],
                    'pageInfo': {'hasNextPage': not page2, 'endCursor': 'second'}}
        pr['comments'] = comments
        data = {'viewer': {'login': 'fixture'}, 'Issue': {'fields': []}, 'PullRequest': {'fields': []},
                'WorkflowRun': {'fields': []}, 'Repository': {'fields': []},
                'repository': {'id': 'R_fixture', 'name': 'fixture', 'nameWithOwner': 'owner/fixture',
                               'owner': {'login': 'owner'}, 'hasIssuesEnabled': True,
                               'issues': connection, 'pullRequest': pr, 'issue': {'id': 'I_fixture', 'number': 1, 'comments': comments}},
                'search': connection, 'node': pr}
        data['repository']['pullRequests'] = connection
        if operation == 'UserCurrent':
            data = {'viewer': data['viewer']}
        elif operation == 'Issue_fields':
            data = {'Issue': data['Issue']}
        elif operation == 'PullRequest_fields2':
            data = {'WorkflowRun': data['WorkflowRun']}
        elif operation == 'PullRequest_fields':
            data = {'PullRequest': data['PullRequest'], 'StatusCheckRollupContextConnection': {'fields': []}}
        elif operation in ('CommentsForIssue', 'CommentsForPullRequest'):
            data = {'node': {'comments': comments}}
        # Remote resolution aliases repository fields. Respond only to known
        # synthetic aliases; do not persist GraphQL text.
        if 'repo_000' in query:
            data = {'repo_000': data['repository']}
        self.reply({'data': data})

    def do_HEAD(self):
        self.server.received += 1
        self.server.paths.append('scopes')
        self.send_response(200)
        self.send_header('X-OAuth-Scopes', 'repo, read:org')
        self.send_header('Content-Length', '0')
        self.end_headers()

    def do_GET(self):
        path = self.path.removeprefix("/api/v3")
        with self.server.lock:
            self.server.received += 1
            self.server.paths.append(self.path)
            ordinal = self.server.received
        parsed = urlsplit(path)
        mode = getattr(self.server, 'updater_mode', None)
        if parsed.path == '/repos/cli/cli/releases/latest':
            self.server.updater_entered.set()
            if mode == 'error':
                self.server.updater_release.wait(5)
            self.reply({'tag_name': 'v2.101.0', 'html_url': 'https://github.com/cli/cli/releases/v2.101.0',
                        'published_at': '2026-10-07T00:00:00Z'})
            return
        if mode and parsed.path in ('/private', '/denied'):
            self.server.updater_entered.wait(5)
        if parsed.path == '/redirect':
            self.reply({}, 302, {'Location': 'https://localhost:' + str(self.server.server_port) + '/api/v3/private'})
            return
        if parsed.path == '/redirect-external':
            self.reply({}, 302, {'Location': 'https://github.com/private'})
            return
        if parsed.path in ('/', '/user'):
            self.reply({'login': 'fixture'}, headers={'X-OAuth-Scopes': 'repo, read:org'})
            return
        if parsed.path.endswith('/actions/workflows'):
            page2 = parse_qs(parsed.query).get('page') == ['2']
            self.reply({'total_count': 101, 'workflows': [
                {'id': i + 1, 'name': 'fixture', 'path': '.github/workflows/fixture.yml', 'state': 'active'}
                for i in range(1 if page2 else 100)]})
            return
        if parsed.path.endswith('/runs') and '/actions/' in parsed.path:
            page2 = parse_qs(parsed.query).get('page') == ['2']
            host = 'localhost:' + str(self.server.server_port)
            headers = {} if page2 else {'Link': '<https://' + host + '/api/v3/repos/owner/fixture/actions/runs?page=2>; rel="next"'}
            self.reply({'total_count': 101, 'workflow_runs': [
                {'id': i + 1, 'name': 'fixture', 'workflow_id': 1, 'status': 'completed', 'conclusion': 'success',
                 'created_at': '2026-10-07T00:00:00Z', 'updated_at': '2026-10-07T00:00:00Z'}
                for i in range(1 if page2 else 100)]}, headers=headers)
            return
        if parsed.path.endswith('/actions/runs/1'):
            self.reply({'id': 1, 'name': 'fixture', 'workflow_id': 1, 'status': 'completed', 'conclusion': 'success',
                        'created_at': '2026-10-07T00:00:00Z', 'updated_at': '2026-10-07T00:00:00Z'})
            return
        if parsed.path.endswith('/actions/workflows/1'):
            self.reply({'id': 1, 'name': 'fixture', 'path': '.github/workflows/fixture.yml', 'state': 'active'})
            return
        if path.startswith("/slow"):
            self.server.entered.set()
            time.sleep(1)
            body = b"[]"
            self.send_response(200)
        elif path.startswith("/pages"):
            page = 2 if "page=2" in path else 3 if "page=3" in path else 1
            if page == 2 and self.server.retry and ordinal == 2:
                # Read a real second request on the reused connection, then
                # close before response. Go retries the idempotent request.
                self.connection.shutdown(socket.SHUT_RDWR)
                self.connection.close()
                self.close_connection = True
                return
            body = json.dumps([page]).encode()
            self.send_response(200)
            if page < 3:
                host = "localhost:" + str(self.server.server_port)
                self.send_header("Link", '<https://' + host + '/api/v3/pages?page=' + str(page + 1) + '>; rel="next"')
        elif path.startswith("/private"):
            body = b'{"private":"fake-body-sentinel"}'
            self.send_response(200)
        else:
            body = b'{"message":"fixture failure"}'
            self.send_response(403)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class PrototypeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if MANIFEST is None:
            raise RuntimeError("paired build manifest required")
        cls.scratch = tempfile.TemporaryDirectory(prefix="gh-http-fixture-")
        scratch = pathlib.Path(cls.scratch.name)
        certificate, key = scratch / "certificate.pem", scratch / "key.pem"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                        "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost,DNS:api.github.com,DNS:github.com,IP:127.0.0.1",
                        "-keyout", str(key), "-out", str(certificate)], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, check=True)
        cls.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        tls.load_cert_chain(certificate, key)
        cls.server.socket = tls.wrap_socket(cls.server.socket, server_side=True)
        cls.server.lock = threading.Lock()
        cls.server.entered = threading.Event()
        cls.server.handle_error = lambda *_args: None
        cls.server.daemon_threads = True
        cls.server.telemetry_received = 0
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.host = "localhost:" + str(cls.server.server_port)
        for name in ("config", "home", "cache", "temp"):
            (scratch / name).mkdir(mode=0o700)
        cls.env = dict(GH_HOST=cls.host, GH_TOKEN="fake-token-sentinel", GH_PROMPT_DISABLED="1",
                       GH_PAGER="", GH_CONFIG_DIR=str(scratch / "config"), HOME=str(scratch / "home"),
                       XDG_CACHE_HOME=str(scratch / "cache"), TMPDIR=str(scratch / "temp"),
                       PATH="", SSL_CERT_FILE=str(certificate), NO_COLOR="1")

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.scratch.cleanup()

    def setUp(self):
        self.env = type(self).env.copy()
        config = pathlib.Path(self.env['GH_CONFIG_DIR'])
        shutil.rmtree(config, ignore_errors=True)
        config.mkdir(mode=0o700)
        self.cwd = None
        self.observation_host = self.host

    def reset(self, retry=False):
        shutil.rmtree(self.env['XDG_CACHE_HOME'], ignore_errors=True)
        pathlib.Path(self.env['XDG_CACHE_HOME']).mkdir(mode=0o700)
        self.server.received = 0
        self.server.paths = []
        self.server.retry = retry

    def raw_env(self, artifact=None, updater=False):
        environment = self.env.copy()
        environment['PATH'] = '/usr/bin:/bin'
        if updater:
            environment.pop('GH_NO_UPDATE_NOTIFIER', None)
        else:
            environment['GH_NO_UPDATE_NOTIFIER'] = '1'
        environment.setdefault('GH_ENTERPRISE_TOKEN', 'fake-token-sentinel')
        if artifact is not None and 'GH_PATH' not in environment:
            environment['GH_PATH'] = artifact['path']
        return environment

    def execute(self, kind, args, instrument=True):
        artifact = MANIFEST["artifacts"][kind]
        host = getattr(self, 'observation_host', self.host)
        qualify = instrument and runner.eligible(args, host) and runner.validate_profile(host, self.env)
        if not qualify:
            result = verified_run(artifact, args, env=self.raw_env(artifact), cwd=getattr(self, 'cwd', None), capture_output=True, timeout=20)
            return result, None
        read_fd, write_fd = os.pipe()
        try:
            invocation = [sys.executable, str(HERE / "run.py"), "--binary", artifact["path"],
                                     "--sha256", artifact["sha256"], "--api-host", getattr(self, 'observation_host', self.host),
                                     "--metadata-fd", str(write_fd), "--", *args]
            if args[0].startswith('fixture-'):
                # Internal controlled descendant diagnostic, intentionally not
                # admitted through the qualification CLI allowlist.
                code = ('import json,os,sys; import run; status,meta=run.run_counted(sys.argv[1],sys.argv[5:],sys.argv[3],sys.argv[2]); '
                        'os.write(int(sys.argv[4]),(json.dumps(meta)+"\\n").encode()); raise SystemExit(status)')
                invocation = [sys.executable, '-c', code, artifact['path'], artifact['sha256'],
                              getattr(self, 'observation_host', self.host), str(write_fd), *args]
                self.env['PYTHONPATH'] = str(HERE)
            result = subprocess.run(invocation, env=self.env, cwd=getattr(self, 'cwd', None),
                                    pass_fds=(write_fd,), capture_output=True, timeout=20)
            os.close(write_fd)
            write_fd = -1
            raw = os.read(read_fd, 4096)
            self.assertNotIn(b"fake-token-sentinel", raw)
            self.assertNotIn(b"fake-body-sentinel", raw)
            self.assertNotIn(b"fake-query-sentinel", raw)
            self.assertNotIn(self.host.encode(), raw)
            return result, json.loads(raw)
        finally:
            os.close(read_fd)
            if write_fd >= 0:
                os.close(write_fd)

    def parity(self, args, expected, retry=False):
        self.reset(retry)
        baseline, _ = self.execute("baseline", args, instrument=False)
        self.assertEqual(self.server.received, expected)
        self.reset(retry)
        patched, metadata = self.execute("instrumented", args)
        self.assertEqual(self.server.received, expected)
        self.assertEqual((patched.returncode, patched.stdout, patched.stderr),
                         (baseline.returncode, baseline.stdout, baseline.stderr))
        if metadata is None:
            return
        self.assertEqual(metadata["observed_completed_writes"], expected)
        self.assertTrue(metadata["complete"])
        self.assertIsNone(metadata["http_requests"])

    def test_builtin_api_host_coverage(self):
        for args, expected in [
            (['auth', 'status', '--hostname', self.host], 2),
            (['issue', 'list', '-R', 'owner/fixture', '--limit', '2', '--json', 'number'], 2),
            (['pr', 'list', '-R', 'owner/fixture', '--limit', '2', '--json', 'number'], 2),
            (['issue', 'view', '1', '-R', 'owner/fixture', '--json', 'number'], 1),
            (['pr', 'view', '1', '-R', 'owner/fixture', '--json', 'number'], 1),
            (['issue', 'view', '1', '-R', 'owner/fixture', '--json', 'comments'], 2),
            (['pr', 'view', '1', '-R', 'owner/fixture', '--json', 'comments'], 2),
            (['pr', 'checks', '1', '-R', 'owner/fixture', '--json', 'name,state'], 5),
            (['run', 'list', '-R', 'owner/fixture', '--limit', '101', '--json', 'databaseId'], 4),
            (['run', 'view', '1', '-R', 'owner/fixture', '--json', 'databaseId'], 2),
            (['workflow', 'list', '-R', 'owner/fixture', '--limit', '101', '--json', 'id'], 2),
            (['workflow', 'view', '1', '-R', 'owner/fixture'], 3),
        ]:
            with self.subTest(command=args[:2]):
                self.parity(args, expected)
                self.assertEqual(self.execute('instrumented', args)[0].returncode, 0)

    def test_same_api_host_redirect(self):
        self.parity(['api', 'redirect'], 2)

    def test_supported_connect_proxy(self):
        with self.proxy():
            self.env['GH_HOST'] = 'github.com'
            self.observation_host = 'api.github.com'
            self.parity(['api', 'private'], 1)
            self.assertGreaterEqual(self.proxy_connections, 2)

    def test_redirect_external_bucket_is_separate(self):
        with self.proxy():
            self.env['GH_HOST'] = 'github.com'
            self.observation_host = 'api.github.com'
            self.reset()
            result, metadata = self.execute('instrumented', ['api', 'redirect-external'])
            self.assertEqual(result.returncode, 0)
            self.assertEqual(self.server.received, 2)
            self.assertIsNone(metadata)

    def proxy(self):
        from contextlib import contextmanager
        parent = self
        class Proxy(http.server.BaseHTTPRequestHandler):
            def log_message(self, *_args):
                pass
            def do_CONNECT(self):
                # Never resolve the requested name or connect off-machine.
                upstream = socket.create_connection(('127.0.0.1', parent.server.server_port))
                parent.proxy_connections += 1
                self.send_response(200)
                self.end_headers()
                try:
                    peers = (self.connection, upstream)
                    while True:
                        ready, _, _ = select.select(peers, [], [], 5)
                        if not ready:
                            return
                        for peer in ready:
                            data = peer.recv(65536)
                            if not data:
                                return
                            (upstream if peer is self.connection else self.connection).sendall(data)
                finally:
                    upstream.close()
        @contextmanager
        def configured():
            proxy = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
            proxy.daemon_threads = True
            thread = threading.Thread(target=proxy.serve_forever, daemon=True)
            thread.start()
            original = self.env.copy()
            self.proxy_connections = 0
            self.env.update(HTTPS_PROXY='http://127.0.0.1:' + str(proxy.server_port))
            try:
                yield
            finally:
                self.env = original
                proxy.shutdown()
                proxy.server_close()
        return configured()

    def test_telemetry_enabled_self_execution_diagnostic(self):
        self.reset()
        # Local-only demonstration: original sealed self-executable cannot be
        # reopened by upstream, whereas its supported GH_PATH can point at a
        # still-held verified image. No arbitrary pathname fallback.
        with self.proxy():
            self.observation_host = 'api.github.com'
            self.env.update(GH_HOST='github.com', GH_TELEMETRY='enabled', GH_TELEMETRY_SAMPLE_RATE='100',
                            GH_TELEMETRY_ENDPOINT_URL='https://api.github.com/fixture-telemetry')
            self.env.pop('GH_ENTERPRISE_TOKEN', None)
            config = pathlib.Path(self.env['GH_CONFIG_DIR'])
            config.mkdir(exist_ok=True)
            (config / 'config.yml').write_text('version: "1"\ntelemetry: enabled\n')
            artifact = MANIFEST['artifacts']['baseline']
            baseline = verified_run(artifact, ['api', 'private'], env=self.raw_env(artifact), capture_output=True)
            result, metadata = self.execute('instrumented', ['api', 'private'])
            self.assertIsNone(metadata)
            self.assertEqual((result.returncode, result.stdout, result.stderr),
                             (baseline.returncode, baseline.stdout, baseline.stderr))

    def test_explicit_caller_self_path_is_preserved(self):
        self.env['GH_PATH'] = '/fixture-caller-explicit'
        alias = '!printf "%s" "$GH_PATH"'
        verified_run(MANIFEST['artifacts']['baseline'], ['alias', 'set', 'fixture-explicit', alias],
                     env=self.raw_env(MANIFEST['artifacts']['baseline']), capture_output=True, check=True)
        baseline = verified_run(MANIFEST['artifacts']['baseline'], ['fixture-explicit'], env=self.raw_env(MANIFEST['artifacts']['baseline']), capture_output=True)
        result = verified_run(MANIFEST['artifacts']['instrumented'], ['fixture-explicit'], env=self.raw_env(MANIFEST['artifacts']['instrumented']), capture_output=True)
        self.assertEqual((result.returncode, result.stdout, result.stderr),
                         (baseline.returncode, baseline.stdout, baseline.stderr))
        self.assertEqual(result.stdout, b'/fixture-caller-explicit')
        self.assertEqual(result.returncode, 0)

    def test_nested_alias_self_exec_is_unobserved_child(self):
        alias = '!test -z "${AI_GH_HTTP_COUNTER_FD+x}" && test -z "${AI_GH_HTTP_COUNTER_HOST+x}" && "$GH_PATH" api private'
        verified_run(MANIFEST['artifacts']['baseline'], ['alias', 'set', 'fixture-self', alias],
                     env=self.raw_env(MANIFEST['artifacts']['baseline']), capture_output=True, check=True)
        self.reset()
        result, metadata = self.execute('instrumented', ['fixture-self'])
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.server.received, 1)
        self.assertIsNone(metadata)

    def test_internal_extension_preserves_self_exec_without_channel(self):
        self.env['XDG_DATA_HOME'] = str(pathlib.Path(self.scratch.name) / 'extension-data')
        extension = pathlib.Path(self.env['XDG_DATA_HOME']) / 'gh/extensions/gh-fixture-extension/gh-fixture-extension'
        extension.parent.mkdir(parents=True)
        extension.write_text('#!/bin/sh\ntest -z "${AI_GH_HTTP_COUNTER_FD+x}" && test -z "${AI_GH_HTTP_COUNTER_HOST+x}" && "$GH_PATH" api private\n')
        extension.chmod(0o700)
        self.reset()
        result, metadata = self.execute('instrumented', ['fixture-extension'])
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.server.received, 1)
        self.assertIsNone(metadata)

    def test_qualification_cli_refuses_unsupported_before_binary_access(self):
        for args in (['auth', 'setup-git'], ['auth', 'login'], ['codespace', 'ssh'],
                     ['skills', 'install', 'owner/fixture'], ['fixture-extension'], ['api', 'private', '-XPOST']):
            read_fd, write_fd = os.pipe()
            try:
                result = subprocess.run([sys.executable, str(HERE / 'run.py'), '--binary', '/does-not-exist',
                                         '--sha256', '0' * 64, '--api-host', self.host,
                                         '--metadata-fd', str(write_fd), '--', *args], env=self.env,
                                        pass_fds=(write_fd,), capture_output=True, timeout=10)
                os.close(write_fd)
                write_fd = -1
                self.assertEqual(result.returncode, 2)
                self.assertEqual(json.loads(os.read(read_fd, 4096)), runner.UNKNOWN)
                self.assertEqual(result.stdout, b'')
                self.assertNotIn(b'/does-not-exist', result.stderr)
            finally:
                os.close(read_fd)
                if write_fd >= 0:
                    os.close(write_fd)

    def test_supported_unix_socket(self):
        class UnixHTTP(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
            daemon_threads = True
        config = pathlib.Path(self.env['GH_CONFIG_DIR'])
        config.mkdir(exist_ok=True)
        path = pathlib.Path(self.scratch.name) / 'fixture.sock'
        server = UnixHTTP(str(path), Handler)
        server.lock = threading.Lock()
        server.received, server.paths = 0, []
        server.server_port = self.server.server_port
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        settings = config / 'config.yml'
        prior = settings.read_bytes() if settings.exists() else None
        settings.write_text('version: "1"\nhttp_unix_socket: ' + str(path) + '\n')
        try:
            # Only the Unix fixture may receive this request.
            self.reset()
            result, metadata = self.execute('instrumented', ['api', 'private'])
            self.assertEqual(result.returncode, 0)
            self.assertEqual(server.received, 1)
            self.assertEqual(self.server.received, 0)
            self.assertIsNone(metadata)
        finally:
            if prior is None:
                settings.unlink()
            else:
                settings.write_bytes(prior)
            server.shutdown()
            server.server_close()

    def test_repository_context_probe(self):
        with self.proxy(), tempfile.TemporaryDirectory(dir=self.scratch.name) as directory:
            self.env['GH_HOST'] = 'github.com'
            self.observation_host = 'api.github.com'
            for args in (['git', 'init', '-q', directory],
                         ['git', '-C', directory, 'remote', 'add', 'origin', 'https://github.com/owner/fixture.git']):
                subprocess.run(args, env=self.raw_env(), check=True, capture_output=True)
            self.cwd = directory
            # Noninteractive resolution intentionally uses local remote state
            # and adds no request; the TTY path below exercises API resolution.
            self.parity(['issue', 'list', '--limit', '2', '--json', 'number'], 2)
            self.env.pop('GH_PROMPT_DISABLED', None)
            self.reset()
            result, metadata = self.execute_tty('instrumented', ['issue', 'list', '--limit', '2', '--json', 'number'])
            self.assertEqual(result.returncode, 0)
            self.assertEqual(self.server.received, 3)
            self.assertIsNone(metadata)

    def execute_tty(self, kind, args):
        artifact = MANIFEST['artifacts'][kind]
        raw_env = self.env.copy()
        raw_env['PATH'] = '/usr/bin:/bin'
        if not runner.eligible(args, getattr(self, 'observation_host', self.host)):
            primary, secondary = pty.openpty()
            try:
                result = verified_run(artifact, args, env=self.raw_env(), stdin=secondary,
                                      stdout=secondary, stderr=secondary, timeout=20)
                return result, None
            finally:
                os.close(primary)
                os.close(secondary)
        primary, secondary = pty.openpty()
        read_fd, write_fd = os.pipe()
        try:
            invocation = [sys.executable, str(HERE / 'run.py'), '--binary', artifact['path'],
                          '--sha256', artifact['sha256'], '--api-host', self.observation_host,
                          '--metadata-fd', str(write_fd), '--', *args]
            result = subprocess.run(invocation, env=self.env, cwd=self.cwd, stdin=secondary,
                                    stdout=secondary, stderr=secondary, pass_fds=(write_fd,), timeout=20)
            os.close(write_fd)
            write_fd = -1
            metadata = json.loads(os.read(read_fd, 4096))
            os.close(secondary)
            secondary = -1
            output = bytearray()
            while True:
                try:
                    chunk = os.read(primary, 4096)
                except OSError:
                    break
                if not chunk:
                    break
                output.extend(chunk)
            result.stdout = bytes(output)
            return result, metadata
        finally:
            for descriptor in (primary, secondary, read_fd, write_fd):
                if descriptor >= 0:
                    os.close(descriptor)

    def test_updater_tty_success_and_error_concurrency(self):
        if MANIFEST.get('qualification_build_tags') != ['updateable']:
            self.skipTest('original build disables notifier; separate updateable source-bound variant required')
        with self.proxy():
            self.env['GH_HOST'] = 'github.com'
            self.observation_host = 'api.github.com'
            self.env.pop('GH_NO_UPDATE_NOTIFIER', None)
            for mode in ('success', 'error'):
                outputs = []
                for kind in ('baseline', 'instrumented'):
                    self.reset()
                    shutil.rmtree(pathlib.Path(self.env['HOME']) / '.local/state/gh', ignore_errors=True)
                    self.server.updater_mode = mode
                    self.server.updater_entered = threading.Event()
                    self.server.updater_release = threading.Event()
                    primary, secondary = pty.openpty()
                    read_fd, write_fd = os.pipe()
                    artifact = MANIFEST['artifacts'][kind]
                    try:
                        args = ['api', 'private' if mode == 'success' else 'denied']
                        # TTY/updater execution remains raw behavior parity;
                        # neither image receives a qualified observer channel.
                        result = verified_run(artifact, args, env=self.raw_env(artifact, updater=True), stdout=secondary,
                                              stderr=secondary, stdin=subprocess.DEVNULL, timeout=20)
                        self.assertTrue(self.server.updater_entered.is_set())
                        self.assertEqual(self.server.received, 2)
                        self.assertEqual(result.returncode, 0 if mode == 'success' else 1)
                        os.close(secondary)
                        secondary = -1
                        output = bytearray()
                        while True:
                            try:
                                chunk = os.read(primary, 4096)
                            except OSError:
                                break
                            if not chunk:
                                break
                            output.extend(chunk)
                        outputs.append((result.returncode, bytes(output)))
                    finally:
                        self.server.updater_release.set()
                        self.server.updater_mode = None
                        for descriptor in (primary, secondary, read_fd, write_fd):
                            if descriptor >= 0:
                                os.close(descriptor)
                self.assertEqual(outputs[0], outputs[1])

    def test_pagination(self):
        self.parity(["api", "pages", "--paginate"], 3)

    def test_hidden_retry_matches_server_ledger(self):
        self.parity(["api", "pages", "--paginate"], 4, retry=True)
        self.assertEqual(sum("page=2" in path for path in self.server.paths), 2)

    def test_private_query_body_stay_out_of_metadata(self):
        self.parity(["api", "private?secret=fake-query-sentinel"], 1)

    def test_failure_preserves_status_and_diagnostics(self):
        self.parity(["api", "denied"], 1)

    def test_uninstrumented_binary_missing_finish_is_unknown(self):
        self.reset()
        result, metadata = self.execute("baseline", ["api", "private"])
        self.assertEqual(result.returncode, 0)
        self.assertIsNone(metadata["observed_completed_writes"])
        self.assertFalse(metadata["complete"])

    def test_malformed_secret_metadata_fails_unknown(self):
        for raw in (b"", b"fake-token-sentinel", b'{"schema":1,"started":true}\n',
                    b'{"schema":true,"started":true}\n', b'[]\n', b'null\n'):
            self.assertEqual(runner.validate(raw), runner.UNKNOWN)

    def test_cache_hit_is_zero_observed_writes_not_fake_http_total(self):
        self.reset()
        first, first_metadata = self.execute("instrumented", ["api", "private", "--cache", "60s"])
        second, second_metadata = self.execute("instrumented", ["api", "private", "--cache", "60s"])
        self.assertEqual(self.server.received, 1)
        self.assertEqual(first_metadata["observed_completed_writes"], 1)
        self.assertEqual(second_metadata["observed_completed_writes"], 0)
        self.assertEqual(first.stdout, second.stdout)
        self.assertIsNone(second_metadata["http_requests"])

    def test_termination_leaves_unknown_without_replay(self):
        self.reset()
        self.server.entered = threading.Event()
        artifact = MANIFEST["artifacts"]["instrumented"]
        read_fd, write_fd = os.pipe()
        process = None
        try:
            process = subprocess.Popen([sys.executable, str(HERE / "run.py"), "--binary", artifact["path"],
                                        "--sha256", artifact["sha256"], "--api-host", self.host,
                                        "--metadata-fd", str(write_fd), "--", "api", "slow"],
                                       env=self.env, pass_fds=(write_fd,), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertTrue(self.server.entered.wait(10))
            process.send_signal(signal.SIGTERM)
            process.communicate(timeout=10)
            os.close(write_fd)
            write_fd = -1
            metadata = json.loads(os.read(read_fd, 4096))
            self.assertEqual(self.server.received, 1)
            self.assertEqual(process.returncode, 143)
            self.assertFalse(metadata["complete"])
            self.assertIsNone(metadata["observed_completed_writes"])
        finally:
            if process is not None and process.poll() is None:
                process.kill()
                process.wait()
            os.close(read_fd)
            if write_fd >= 0:
                os.close(write_fd)

    def test_descendant_does_not_inherit_counter_environment(self):
        alias = '!if [ -z "${AI_GH_HTTP_COUNTER_FD+x}" ] && [ -z "${AI_GH_HTTP_COUNTER_HOST+x}" ]; then printf "CLEAR\\n"; else exit 4; fi'
        baseline = MANIFEST["artifacts"]["baseline"]
        configured = verified_run(baseline, ["alias", "set", "fixture-counter-env", alias],
                                    env=self.raw_env(baseline), capture_output=True, timeout=10)
        self.assertEqual(configured.returncode, 0)
        result, metadata = self.execute("instrumented", ["fixture-counter-env"])
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"CLEAR\n")
        self.assertIsNone(metadata)


if __name__ == "__main__":
    unittest.main()
