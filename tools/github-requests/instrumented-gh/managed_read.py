"""Bounded Linux observation of explicit public task reads; no installed routing.

The controller supplies an exact build-manifest digest and already-authorized
arguments. Command output streams unchanged. Only numeric counter metadata is
returned; credentials/configuration are never read or copied by this module.
The old isolated qualification CLI remains independent and unchanged.
"""
import contextlib
import hashlib
import importlib
import json
import os
import pathlib
import re
import select
import signal
import stat
import subprocess
import threading
import time
import tempfile
import shutil
import socket
import array
import sys
import ctypes

from run import UNKNOWN, validate
from sealed import verified_snapshot
from source_binding import validate_source_binding, version_profile

REPOSITORY = "popcre/ai-devops"
FAMILIES = {("issue", "view"), ("issue", "list"), ("pr", "view"),
            ("pr", "list"), ("pr", "checks"), ("run", "view"),
            ("run", "list"), ("repo", "view")}
VALUE_FLAGS = {"--json", "--jq", "--repo", "-R", "--limit", "-L",
               "--state", "--base", "--head", "--branch", "--workflow"}
_WORKER_BOOTSTRAP = ("import os,sys,runpy;worker=sys.argv.pop(1);"
                     "sys.path.insert(0,os.path.dirname(worker));runpy.run_path(worker,run_name='__main__')")


def _packet_send(channel, value, descriptors=()):
    raw = json.dumps(value, separators=(",", ":")).encode()
    if len(raw) > 4096:
        raise ValueError("cohort request exceeds bound")
    ancillary = [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array("i", descriptors))] if descriptors else []
    if channel.sendmsg([raw], ancillary) != len(raw):
        raise ValueError("incomplete cohort packet")


def _packet_receive(channel):
    """Every received descriptor is closed unless transferred to the caller."""
    descriptors = []
    try:
        raw, ancillary, flags, _ = channel.recvmsg(4096, socket.CMSG_SPACE(16 * array.array("i").itemsize),
                                                  getattr(socket, "MSG_CMSG_CLOEXEC", 0))
        invalid_ancillary = False
        for level, kind, data in ancillary:
            if level == socket.SOL_SOCKET and kind == socket.SCM_RIGHTS:
                values = array.array("i")
                values.frombytes(data[:len(data) - len(data) % values.itemsize])
                descriptors.extend(values)
                invalid_ancillary |= len(data) % values.itemsize != 0
            else:
                invalid_ancillary = True
        for descriptor in descriptors:
            os.set_inheritable(descriptor, False)
        if invalid_ancillary or not raw or flags & (socket.MSG_TRUNC | socket.MSG_CTRUNC):
            raise ValueError("closed or oversized cohort packet")
        def unique_object(pairs):
            result = {}
            for key, value in pairs:
                if key in result:
                    raise ValueError("duplicate cohort field")
                result[key] = value
            return result
        def invalid_constant(_value):
            raise ValueError("nonfinite cohort value")
        value = json.loads(raw, object_pairs_hook=unique_object, parse_constant=invalid_constant)
        if type(value) is not dict:
            raise ValueError("cohort packet must be an object")
        result = descriptors
        descriptors = []
        return value, result
    finally:
        for descriptor in descriptors:
            os.close(descriptor)


def _cohort_worker(descriptor, bash, transport, baseline, instrumented, lifetime):
    """Private inherited capability, used only by one bounded parent cohort."""
    channel = socket.socket(fileno=descriptor)
    os.set_inheritable(descriptor, False)
    deadline = time.monotonic() + lifetime
    original_environment = os.environ.copy()
    if ctypes.CDLL(None, use_errno=True).prctl(36, 1, 0, 0, 0) != 0:
        raise ValueError("owned descendant supervision unavailable")
    interrupted = []
    wake_read, wake_write = os.pipe2(os.O_CLOEXEC | os.O_NONBLOCK)
    signal.set_wakeup_fd(wake_write)
    # A group signal must reach the ordinary workload while the supervisor
    # stays alive long enough to reap it. The parent kills the entire group
    # on timeout/protocol failure and never replays a command.
    signal.signal(signal.SIGINT, lambda signum, _frame: interrupted.append(signum))
    signal.signal(signal.SIGTERM, lambda signum, _frame: interrupted.append(signum))
    _packet_send(channel, {"ready": 1, "pid": os.getpid()})
    for ordinal in range(1, 41):
        descriptors = []
        child = None
        try:
            channel.settimeout(max(0.001, deadline - time.monotonic()))
            value, descriptors = _packet_receive(channel)
            if value == {"close": 1} and not descriptors:
                _reap_cohort_children()
                return 0
            if (set(value) != {"sequence", "kind", "arguments", "workflow_id", "timeout_seconds"}
                    or type(value["sequence"]) is not int or value["sequence"] != ordinal
                    or value["kind"] not in ("baseline", "instrumented")
                    or type(value["arguments"]) is not list or len(descriptors) != 4
                    or type(value["timeout_seconds"]) is not int or not 1 <= value["timeout_seconds"] <= 300
                    or not isinstance(value["workflow_id"], str) or not re.fullmatch(r"[0-9a-f]{32}", value["workflow_id"])):
                raise ValueError("invalid cohort command")
            managed_read_label(value["arguments"])
            image = instrumented if value["kind"] == "instrumented" else baseline
            environment = original_environment.copy()
            environment.update(GH_PATH=image, AI_GH_REAL_GH=image)
            if value["kind"] == "instrumented":
                environment.update(AI_GH_HTTP_COUNTER_FD=str(descriptors[3]), AI_GH_HTTP_COUNTER_HOST="api.github.com")
            child = subprocess.Popen([bash, transport, *value["arguments"]], env=environment,
                                     stdin=descriptors[0], stdout=descriptors[1], stderr=descriptors[2],
                                     pass_fds=(descriptors[3],))
            for received in descriptors:
                os.close(received)
            descriptors = []
            command_deadline = min(time.monotonic() + value["timeout_seconds"], deadline)
            stopped = False
            pidfd = os.pidfd_open(child.pid)
            try:
                ready = select.select([pidfd, wake_read], [], [], max(0, command_deadline - time.monotonic()))[0]
                if interrupted or not ready:
                    stopped = True
                    _reap_cohort_children(interrupted[-1] if interrupted else signal.SIGTERM, child)
                    status = 128 + interrupted[-1] if interrupted else 124
                else:
                    status = child.wait()
            finally:
                os.close(pidfd)
            _packet_send(channel, {"sequence": ordinal, "status": status, "stopped": stopped})
            if stopped:
                return 0
        except BaseException:
            # No host details or exception data enter the private protocol.
            # Killing our own group also catches grandchildren on error.
            _reap_cohort_children(signal.SIGTERM, child)
            return 125
        finally:
            for received in descriptors:
                os.close(received)
    _reap_cohort_children()
    return 0


def _reap_cohort_children(signum=signal.SIGTERM, direct=None):
    """Signal only unreaped children of this worker, never external PIDs."""
    started = time.monotonic()
    while True:
        children = [int(value) for value in pathlib.Path(
            f"/proc/{os.getpid()}/task/{os.getpid()}/children").read_text().split()]
        if not children:
            return
        if time.monotonic() - started >= 5:
            raise ValueError("owned descendants could not be reaped")
        action = signal.SIGKILL if time.monotonic() - started >= 0.25 else signum
        for pid in children:
            if direct is not None and pid == direct.pid:
                if direct.poll() is not None:
                    continue
            else:
                try:
                    if os.waitpid(pid, os.WNOHANG)[0]:
                        continue
                except ChildProcessError:
                    continue
            # An unreaped direct/adopted child reserves its PID until wait.
            try: os.kill(pid, action)
            except ProcessLookupError: pass
        time.sleep(0.005)


class _CohortCommand:
    def __init__(self, cohort, ordinal):
        self.cohort, self.ordinal, self.status = cohort, ordinal, None
        self.pid = cohort.process.pid
        self.protocol_complete = False

    def poll(self):
        if self.status is not None:
            return self.status
        if select.select([self.cohort.channel], [], [], 0)[0]:
            try:
                value, descriptors = _packet_receive(self.cohort.channel)
                for descriptor in descriptors:
                    os.close(descriptor)
                if (descriptors or set(value) != {"sequence", "status", "stopped"}
                        or type(value["sequence"]) is not int or value["sequence"] != self.ordinal
                        or type(value["status"]) is not int or not -127 <= value["status"] <= 255
                        or type(value["stopped"]) is not bool):
                    raise ValueError("invalid cohort result")
                self.status, self.protocol_complete = value["status"], not value["stopped"]
            except (OSError, ValueError):
                self.status = 125
                self.cohort.close()
        return self.status

    def wait(self, timeout=None):
        deadline = time.monotonic() + (timeout if timeout is not None else 5)
        while self.poll() is None:
            left = deadline - time.monotonic()
            if left <= 0:
                raise subprocess.TimeoutExpired("owned cohort", timeout)
            select.select([self.cohort.channel], [], [], min(left, 0.05))
        return self.status


class _CohortProcess:
    def __init__(self, observation):
        self.channel, peer = socket.socketpair(socket.AF_UNIX, socket.SOCK_SEQPACKET)
        self.process = None
        self.ordinal = 0
        self.cleanup_complete = False
        self.worker_pidfd = None
        try:
            with observation._generation_provider.retained_generation_launch(observation.transport_boundary) as launch, contextlib.ExitStack() as held:
                prefix = list(launch["mount_prefix"][:-1]) + ["--tmpfs", observation._native_mount]
                descriptors = list(launch["pass_fds"])
                images = {}
                for kind, image in observation._images.items():
                    borrowed = os.open(f"/proc/self/fd/{image.fileno()}", os.O_RDONLY | os.O_CLOEXEC)
                    held.callback(os.close, borrowed)
                    descriptors.append(borrowed)
                    images[kind] = os.path.join(observation._native_mount, kind)
                    prefix += ["--perms", "0500", "--ro-bind-data", str(borrowed), images[kind]]
                prefix += ["--remount-ro", observation._native_mount, "--", *launch["execution_prefix"]]
                worker = pathlib.Path(observation.transport_boundary["root"]) / "tools/github-requests/instrumented-gh/managed_read.py"
                python = observation._generation_provider.trusted_boundary_executable(sys.executable)
                self.process = subprocess.Popen([*prefix, python, "-I", "-S", "-c", _WORKER_BOOTSTRAP,
                    str(worker), "--private-cohort-worker",
                    str(peer.fileno()), observation.bash, observation.transport_path,
                    images["baseline"], images["instrumented"], "12030"],
                    env=observation.environment, cwd=observation.cwd,
                    stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                    pass_fds=tuple([*descriptors, peer.fileno()]), start_new_session=True)
                peer.close()
                self.channel.settimeout(10)
                value, received = _packet_receive(self.channel)
                for descriptor in received:
                    os.close(descriptor)
                if (set(value) != {"ready", "pid"} or type(value["ready"]) is not int or value["ready"] != 1
                        or type(value["pid"]) is not int or value["pid"] <= 1 or received):
                    raise ValueError("cohort bootstrap failed")
                # Capture a kernel process identity before checking its owned
                # session/group. Numeric ready-frame PIDs cannot authorize a
                # late signal after the worker has been reaped/reused.
                self.worker_pidfd = os.pidfd_open(value["pid"])
                if os.getpgid(value["pid"]) != self.process.pid:
                    raise ValueError("cohort worker left owned group")
                self.channel.settimeout(None)
        except BaseException:
            peer.close()
            self.close()
            raise

    def run(self, arguments, workflow_id, kind, timeout, streams, counter):
        if self.process.returncode is not None:
            raise ValueError("cohort is closed")
        self.ordinal += 1
        descriptors, opened = [], []
        try:
            for index, stream in enumerate(streams):
                if stream == subprocess.DEVNULL:
                    descriptor = os.open(os.devnull, os.O_RDONLY if index == 0 else os.O_WRONLY)
                    opened.append(descriptor)
                elif stream == subprocess.STDOUT and index == 2:
                    descriptor = descriptors[1]
                else:
                    descriptor = index if stream is None else (stream if isinstance(stream, int) else stream.fileno())
                descriptors.append(descriptor)
            _packet_send(self.channel, {"sequence": self.ordinal, "kind": kind, "arguments": arguments,
                         "workflow_id": workflow_id, "timeout_seconds": timeout}, [*descriptors, counter])
        finally:
            for descriptor in opened:
                os.close(descriptor)
        return _CohortCommand(self, self.ordinal)

    def close(self):
        if self.process is not None:
            # Do not reap the group leader before killing its owned group:
            # keeping that PID reserved prevents signalling a reused group.
            if self.process.returncode is None:
                try:
                    self.channel.settimeout(0.25)
                    _packet_send(self.channel, {"close": 1})
                    self.process.wait(timeout=6)
                except (OSError, ValueError, subprocess.TimeoutExpired):
                    try: os.killpg(self.process.pid, signal.SIGKILL)
                    except ProcessLookupError: pass
                    self.process.wait()
            self.cleanup_complete = self.process.returncode == 0
        self.channel.close()
        if self.worker_pidfd is not None:
            os.close(self.worker_pidfd)
            self.worker_pidfd = None

    def interrupt(self, signum):
        if self.worker_pidfd is None:
            raise ProcessLookupError("cohort worker is closed")
        signal.pidfd_send_signal(self.worker_pidfd, signum)


def native_mount_prefix(launch, mount, descriptor, executable):
    """Mount options precede Bubblewrap's terminator; workload limits follow."""
    return [*launch["mount_prefix"][:-1], "--tmpfs", mount, "--perms", "0500",
            "--ro-bind-data", str(descriptor), executable, "--remount-ro", mount,
            "--", *launch["execution_prefix"]]


def same_execution_layout(transport, expected_transport, bash, expected_bash):
    """Aliases may identify the same loaded files; external helper layouts may not.

    File identity alone also accepts an ai-gh hardlink in another directory,
    where its adjacent helpers would escape the retained generation mounts.
    """
    try:
        actual, expected = pathlib.Path(transport), pathlib.Path(expected_transport)
        return (actual.samefile(expected) and actual.parent.samefile(expected.parent)
                and pathlib.Path(bash).samefile(expected_bash))
    except (OSError, ValueError):
        return False


def aggregate_invocations(raw):
    """Aggregate only complete sequential pairs, including admission probes."""
    unknown = {**UNKNOWN, "counted_invocations": None}
    if not raw or len(raw) > 65536:
        return unknown
    lines = raw.splitlines()
    if len(lines) % 2 or len(lines) > 128:
        return unknown
    totals = {"observed_completed_writes": 0, "failed_write_attempts": 0,
              "observed_external_writes": 0}
    for index in range(0, len(lines), 2):
        record = validate(lines[index] + b"\n" + lines[index + 1] + b"\n")
        if not record["complete"]:
            return unknown
        for key in totals:
            totals[key] += record[key]
    return {**UNKNOWN, **totals, "complete": True, "counted_invocations": len(lines) // 2}


def managed_read_label(arguments):
    """Finite built-in public reads only; never expand aliases or executors."""
    if (not isinstance(arguments, (list, tuple)) or len(arguments) < 2
            or any(not isinstance(arg, str) or not arg
                   or any(ord(char) < 32 or ord(char) == 127 for char in arg)
                   for arg in arguments)):
        raise ValueError("unsupported managed read")
    family = tuple(arguments[:2])
    if family not in FAMILIES:
        raise ValueError("unsupported managed read")
    flags, positionals = {}, []
    index = 2
    while index < len(arguments):
        argument = arguments[index]
        if argument.startswith("-"):
            name, equals, value = argument.partition("=")
            if name not in VALUE_FLAGS or name in flags:
                raise ValueError("unsupported managed read flag")
            if not equals:
                index += 1
                if index == len(arguments):
                    raise ValueError("missing managed read value")
                value = arguments[index]
            if not value or value.startswith("-"):
                raise ValueError("unsupported managed read value")
            flags[name] = value
        else:
            positionals.append(argument)
        index += 1
    if "--repo" in flags and "-R" in flags:
        raise ValueError("ambiguous repository")
    repository = flags.get("--repo", flags.get("-R"))
    if family == ("repo", "view"):
        if positionals != [REPOSITORY] or repository is not None:
            raise ValueError("explicit public repository required")
    else:
        if repository != REPOSITORY:
            raise ValueError("explicit public repository required")
        if family[1] in ("view", "checks"):
            if len(positionals) != 1 or not re.fullmatch(r"[1-9][0-9]*", positionals[0]):
                raise ValueError("explicit numeric target required")
        elif positionals:
            raise ValueError("unexpected managed read target")
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9]*(?:,[A-Za-z][A-Za-z0-9]*)*", flags.get("--json", "")):
        raise ValueError("explicit JSON fields required")
    return ".".join(family)


def _owner_private_group(group_id, owner_uid):
    """NSS effective members include explicit members AND primary groups."""
    try:
        import grp
        import pwd
        group = grp.getgrgid(group_id)
        members = {pwd.getpwnam(name).pw_uid for name in group.gr_mem}
        members.update(entry.pw_uid for entry in pwd.getpwall() if entry.pw_gid == group_id)
        return members == {owner_uid}
    except (ImportError, KeyError, OSError, TypeError, AttributeError):
        return False


def _private_config_files(directory, owner_uid):
    # Metadata only: O_PATH never reads authentication/configuration contents.
    for name in ("config.yml", "hosts.yml"):
        descriptor = None
        try:
            descriptor = os.open(name, os.O_PATH | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=directory)
            info = os.fstat(descriptor)
            if (not stat.S_ISREG(info.st_mode) or info.st_uid != owner_uid
                    or stat.S_IMODE(info.st_mode) != 0o600 or info.st_nlink != 1):
                return False
        except FileNotFoundError:
            continue
        except OSError:
            return False
        finally:
            if descriptor is not None:
                os.close(descriptor)
    return True


def _protected_config(environment):
    # Inspect metadata only. Authentication stays in the unchanged gh process.
    home = environment.get("HOME")
    config = environment.get("GH_CONFIG_DIR")
    if config is None:
        if not home or not os.path.isabs(home):
            return False
        config = os.path.join(environment.get("XDG_CONFIG_HOME", os.path.join(home, ".config")), "gh")
    path = pathlib.Path(config)
    if not path.is_absolute():
        return False
    descriptor = None
    try:
        descriptor = os.open(path.anchor, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        for component in path.parts[1:]:
            info = os.fstat(descriptor)
            sticky_root = info.st_uid == 0 and info.st_mode & stat.S_ISVTX
            private_group_write = (not info.st_mode & 0o020
                                   or _owner_private_group(info.st_gid, info.st_uid))
            if (info.st_uid not in (0, os.getuid())
                    or (not sticky_root and (info.st_mode & 0o002 or not private_group_write))):
                return False
            child = os.open(component, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=descriptor)
            os.close(descriptor)
            descriptor = child
        info = os.fstat(descriptor)
        group_private = not info.st_mode & 0o070 or _owner_private_group(info.st_gid, info.st_uid)
        return (info.st_uid == os.getuid() and not info.st_mode & 0o002 and group_private
                and _private_config_files(descriptor, info.st_uid))
    except FileNotFoundError:
        # Token-authenticated existing environments need not create a config.
        return any(bool(environment.get(name)) for name in ("GH_TOKEN", "GITHUB_TOKEN"))
    except OSError:
        return False
    finally:
        if descriptor is not None:
            os.close(descriptor)


def ordinary_cli_profile(environment):
    """Local vendor version only; no authentication/API preflight request."""
    selected = shutil.which("gh", path=environment.get("PATH", os.defpath))
    if selected is None:
        raise ValueError("ordinary vendor CLI unavailable")
    path = pathlib.Path(selected).resolve(strict=True)
    for entry in (path, *path.parents):
        info = entry.stat()
        if info.st_uid != 0 or info.st_mode & 0o022:
            raise ValueError("ordinary vendor CLI custody is untrusted")
    with path.open("rb") as stream:
        if stream.read(4) != b"\x7fELF":
            raise ValueError("ordinary native vendor CLI required")
        stream.seek(0)
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
        info = os.fstat(stream.fileno())
    result = subprocess.run([str(path), "--version"], env=environment, capture_output=True, timeout=10)
    match = re.match(rb"gh version ([0-9]+\.[0-9]+\.[0-9]+)(?:\s|$)", result.stdout)
    if result.returncode or match is None:
        raise ValueError("ordinary vendor CLI version is unqualified")
    return str(path), match.group(1).decode("ascii"), digest, (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns)


class ManagedReadObservation:
    """One explicit cohort, retained sealed images, no service or command replay.

    run(arguments, workflow_id) streams normal command output and returns
    (original_exit_status, numeric_record). The caller associates its validated
    command label and opaque workflow ID with that record. close() includes all
    manifest verification and image bootstrap in cohort_elapsed_ns.
    """
    def __init__(self, manifest, expected_manifest_sha256, *, transport_path, transport_sha256,
                 transport_boundary=None, environment=None, cwd=None, historical_profile=False):
        self.started_ns = time.perf_counter_ns()
        self.environment = dict(os.environ if environment is None else environment)
        self.cwd = cwd
        self._stack = contextlib.ExitStack()
        self._images = {}
        self._image_hashes = {}
        self.transport_path = os.path.abspath(transport_path)
        self.transport_sha256 = transport_sha256
        self.manifest_sha256 = expected_manifest_sha256
        self.transport_boundary = transport_boundary
        self._generation_provider = None
        self.source_identity = None
        self.bootstrap_complete = True
        self.source_bootstrap_ns = 0
        self._transport = None
        self._cohort = None
        self.historical_profile = historical_profile
        self.commands = 0
        self.cohort_elapsed_ns = None
        if (os.name != "posix" or not hasattr(os, "uname") or os.uname().sysname != "Linux"
                or threading.current_thread() is not threading.main_thread()
                or self.environment.get("GH_HOST", "github.com") != "github.com"
                or any(self.environment.get(name) for name in ("GH_PATH", "GH_DEBUG", "GH_FORCE_TTY"))
                or any(self.environment.get(name, "") not in ("", "cat") for name in ("GH_PAGER", "PAGER"))
                or "AI_GH_REAL_GH" in self.environment
                or any(name.startswith("AI_GH_HTTP_COUNTER_") for name in self.environment)
                or any(value and (name in {"BASH_ENV", "ENV", "PYTHONPATH", "PYTHONHOME", "PYTHONSTARTUP",
                                           "PYTHONINSPECT", "PYTHONUSERBASE", "LD_PRELOAD", "LD_LIBRARY_PATH"}
                                  or name.startswith("BASH_FUNC_")) for name, value in self.environment.items())
                or os.isatty(0) or os.isatty(1) or not _protected_config(self.environment)):
            raise ValueError("unsupported managed observation environment")
        if type(historical_profile) is not bool:
            raise ValueError("historical profile must be explicit")
        try:
            if isinstance(transport_boundary, dict):
                raise ValueError("serialized boundary cannot grant retained generation authority")
            if pathlib.Path(self.transport_path).name != "ai-gh" or not re.fullmatch(r"[0-9a-f]{64}", transport_sha256):
                raise ValueError("exact ai-gh transport binding required")
            descriptor = os.open(self.transport_path, os.O_RDONLY | os.O_NOFOLLOW)
            self._transport = self._stack.enter_context(os.fdopen(descriptor, "rb"))
            if not self._transport_matches():
                raise ValueError("ai-gh transport binding mismatch")
            self.bash = str(pathlib.Path("/usr/bin/bash").resolve(strict=True))
            for path in (pathlib.Path(self.bash), *pathlib.Path(self.bash).parents):
                info = path.stat()
                if info.st_uid != 0 or info.st_mode & 0o022:
                    raise ValueError("trusted system Bash required")
            if transport_boundary is not None:
                self._generation_provider = importlib.import_module("report")
                if not self._generation_provider.retained_generation_valid(transport_boundary):
                    raise ValueError("active retained generation authority required")
                source_bootstrap = transport_boundary.get("bootstrap_ns")
                self.bootstrap_complete = type(source_bootstrap) is int and source_bootstrap >= 0
                self.source_bootstrap_ns = source_bootstrap if self.bootstrap_complete else None
                if not same_execution_layout(self.transport_path, transport_boundary["transport_path"],
                                             self.bash, transport_boundary["bash_path"]):
                    raise ValueError("retained generation transport mismatch")
                identity = transport_boundary["identity"]
                for key, length in (("source_sha", 40), ("source_fingerprint", 64), ("install_generation_binding", 64)):
                    if not isinstance(identity.get(key), str) or not re.fullmatch(r"[0-9a-f]{%d}" % length, identity[key]):
                        raise ValueError("retained generation identity is incomplete")
                if identity.get("source_boundary") != "linux_sealed_generation":
                    raise ValueError("unsupported retained generation boundary")
                self.source_identity = {key: identity[key] for key in
                                        ("source_sha", "source_fingerprint", "install_generation_binding", "source_boundary")}
                if "loaded_source_fingerprint" in identity:
                    if not isinstance(identity["loaded_source_fingerprint"], str) or not re.fullmatch(r"[0-9a-f]{64}", identity["loaded_source_fingerprint"]):
                        raise ValueError("loaded source fingerprint is invalid")
                    self.source_identity["loaded_source_fingerprint"] = identity["loaded_source_fingerprint"]
                self._native_mount = self._stack.enter_context(tempfile.TemporaryDirectory(prefix="gh-counter-observation-"))
            with verified_snapshot(manifest, expected_manifest_sha256, limit=1048576) as stream:
                build = json.load(stream)
            self.ordinary_cli_path, self.ordinary_cli_version, self.ordinary_cli_sha256, self._ordinary_identity = ordinary_cli_profile(self.environment)
            profile = version_profile(pathlib.Path(__file__).parent / "pins.json", build["pins"]["upstream_version"])
            for field in ("upstream_version", "upstream_commit", "source_sha256", "toolchain_sha256"):
                if build["pins"][field] != profile[field]:
                    raise ValueError("counter release source pins differ")
            if build.get("target") != "linux-amd64":
                raise ValueError("native Linux counter profile required")
            self.counter_version = profile["upstream_version"]
            if (self.counter_version != self.ordinary_cli_version or profile["profile_kind"] == "historical") and not historical_profile:
                raise ValueError("counter release differs from actual ordinary CLI; historical evidence only")
            validate_source_binding(build["counter_source_binding"], pathlib.Path(__file__).parent)
            for kind in ("baseline", "instrumented"):
                artifact = build["artifacts"][kind]
                self._images[kind] = self._stack.enter_context(verified_snapshot(artifact["path"], artifact["sha256"]))
                self._image_hashes[kind] = artifact["sha256"]
            if self.transport_boundary is not None:
                self._cohort = _CohortProcess(self)
                self._stack.callback(self._cohort.close)
        except BaseException:
            self._stack.close()
            raise
        self.bootstrap_ns = time.perf_counter_ns() - self.started_ns + (self.source_bootstrap_ns or 0)

    def _transport_matches(self):
        before = os.fstat(self._transport.fileno())
        current = os.stat(self.transport_path, follow_symlinks=False)
        if (not stat.S_ISREG(before.st_mode) or before.st_uid not in (0, os.getuid())
                or (before.st_mode & 0o022 and self.transport_boundary is None)
                or (current.st_dev, current.st_ino) != (before.st_dev, before.st_ino)):
            return False
        self._transport.seek(0)
        digest = hashlib.file_digest(self._transport, "sha256").hexdigest()
        after = os.fstat(self._transport.fileno())
        return digest == self.transport_sha256 and (before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns)

    def summary(self):
        return {"bootstrap_ns": self.bootstrap_ns, "cohort_elapsed_ns": self.cohort_elapsed_ns,
                "cohort_cleanup_complete": self._cohort.cleanup_complete if self._cohort is not None else True,
                "commands": self.commands, "manifest_sha256": self.manifest_sha256,
                "transport_sha256": self.transport_sha256, "source_bootstrap_ns": self.source_bootstrap_ns,
                "bootstrap_complete": self.bootstrap_complete, "ordinary_cli_version": self.ordinary_cli_version,
                "ordinary_cli_sha256": self.ordinary_cli_sha256, "counter_version": self.counter_version,
                "historical_profile": self.historical_profile}

    def _ordinary_matches(self):
        info = os.stat(self.ordinary_cli_path, follow_symlinks=False)
        return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns) == self._ordinary_identity

    def __enter__(self):
        return self

    def __exit__(self, *_exception):
        self.close()

    def close(self):
        self._stack.close()
        self._images.clear()
        if self.cohort_elapsed_ns is None:
            self.cohort_elapsed_ns = time.perf_counter_ns() - self.started_ns + (self.source_bootstrap_ns or 0)

    def run(self, arguments, workflow_id, *, kind="instrumented", stdin=None, stdout=None, stderr=None,
            timeout_seconds=120):
        label = managed_read_label(arguments)
        if threading.current_thread() is not threading.main_thread():
            raise ValueError("main-thread cancellation supervision required")
        if not isinstance(workflow_id, str) or not re.fullmatch(r"[0-9a-f]{32}", workflow_id):
            raise ValueError("opaque workflow ID required")
        if kind not in self._images or self.cohort_elapsed_ns is not None:
            raise ValueError("observation cohort is closed or image unknown")
        if self.commands >= 40 or not self._transport_matches() or not self._ordinary_matches():
            raise ValueError("observation cohort limit or changed transport")
        if self.transport_boundary is not None and not self._generation_provider.retained_generation_valid(self.transport_boundary):
            raise ValueError("retained generation authority expired")
        if subprocess.PIPE in (stdin, stdout, stderr):
            raise ValueError("caller-owned streaming descriptors required")
        if type(timeout_seconds) is not int or not 1 <= timeout_seconds <= 300:
            raise ValueError("bounded observation timeout required")
        read_fd, write_fd = os.pipe()
        child = None
        handlers = {}
        raw = bytearray()
        launch_stack = contextlib.ExitStack()
        complete = overflow = False
        started = time.perf_counter_ns()
        deadline = time.monotonic() + timeout_seconds
        if self._cohort is not None:
            deadline += 6  # command timeout remains unchanged inside the worker
        interrupted = []
        timed_out = False
        try:
            image = self._images[kind]
            executable = f"/proc/{os.getpid()}/fd/{image.fileno()}"
            prefix = []
            retained = ()
            if self.transport_boundary and self._cohort is None:
                # Parent /proc handles cannot cross a new user namespace.
                # Bind the same sealed bytes into a private namespace-only
                # tmpfs; no image or helper is written to the host directory.
                executable = os.path.join(self._native_mount, "gh")
                launch = launch_stack.enter_context(self._generation_provider.retained_generation_launch(self.transport_boundary))
                # ro-bind-data advances its input's open-file offset. Borrow
                # a new description for EVERY launch; the held image remains
                # immutable and reusable for subsequent observations.
                borrowed_image = os.open(f"/proc/self/fd/{image.fileno()}", os.O_RDONLY | os.O_CLOEXEC)
                launch_stack.callback(os.close, borrowed_image)
                prefix = native_mount_prefix(launch, self._native_mount, borrowed_image, executable)
                retained = (*launch["pass_fds"], borrowed_image)
            environment = self.environment.copy()
            # Bind supported upstream self-execution to the retained image.
            environment["GH_PATH"] = executable
            environment["AI_GH_REAL_GH"] = executable
            if kind == "instrumented":
                environment.update(AI_GH_HTTP_COUNTER_FD=str(write_fd), AI_GH_HTTP_COUNTER_HOST="api.github.com")
            def forward(signum, _frame):
                interrupted.append(signum)
                if child is None:
                    return
                try:
                    if self._cohort is not None:
                        self._cohort.interrupt(signum)
                    else:
                        os.killpg(child.pid, signum)
                except ProcessLookupError:
                    pass

            for signum in (signal.SIGINT, signal.SIGTERM):
                handlers[signum] = signal.signal(signum, forward)
            if self._cohort is not None:
                child = self._cohort.run(arguments, workflow_id, kind, timeout_seconds,
                                         (stdin, stdout, stderr), write_fd)
            else:
                child = subprocess.Popen([*prefix, self.bash, self.transport_path, *arguments], env=environment,
                                         cwd=self.cwd, stdin=stdin, stdout=stdout, stderr=stderr,
                                         pass_fds=tuple({write_fd, *retained}), start_new_session=True)
            os.close(write_fd)
            write_fd = -1
            if interrupted:
                forward(interrupted[-1], None)
            drain_deadline = None
            while True:
                if time.monotonic() >= deadline:
                    timed_out = True
                    try:
                        os.killpg(child.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    break
                if child.poll() is not None and drain_deadline is None:
                    drain_deadline = time.monotonic() + 0.5
                if drain_deadline is not None and time.monotonic() >= drain_deadline:
                    break
                if not select.select([read_fd], [], [], 0.01)[0]:
                    continue
                block = os.read(read_fd, 4096)
                if not block:
                    complete = True
                    break
                if len(raw) + len(block) > 65536:
                    overflow = True
                    raw.clear()
                elif not overflow:
                    raw.extend(block)
            try:
                status = child.wait(timeout=max(0.001, deadline - time.monotonic()))
            except subprocess.TimeoutExpired:
                timed_out = True
                try:
                    os.killpg(child.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                child.wait()
                status = 124
            if timed_out:
                status = 124
            record = (aggregate_invocations(raw) if complete and not overflow and not timed_out and not interrupted
                      and getattr(child, "protocol_complete", True)
                      and self._transport_matches() and self._ordinary_matches() else {**UNKNOWN, "counted_invocations": None})
            verified = (record["complete"] and self.transport_boundary is not None
                        and self._generation_provider.retained_generation_valid(self.transport_boundary))
            self.commands += 1
            return (status if status >= 0 else 128 - status), {
                **record, "measurement": "managed_read_observation", "command_label": label,
                "workflow_id": workflow_id, "exit_status": status if status >= 0 else 128 - status,
                "includes_admission_probes": True, "probe_attribution": "unseparated",
                "transport_source_verified": "verified" if verified else "unknown",
                "source_identity": dict(self.source_identity) if verified else None,
                "counter_image_sha256": self._image_hashes[kind], "counter_enabled": kind == "instrumented",
                "counter_version": self.counter_version, "ordinary_cli_version": self.ordinary_cli_version,
                "historical_profile": self.historical_profile,
                "elapsed_ns": time.perf_counter_ns() - started,
                "scope": "primary_builtin_api_constructors including admission identity/quota probes; subprocess and whole-account totals unknown"}
        finally:
            for signum, handler in handlers.items():
                signal.signal(signum, handler)
            os.close(read_fd)
            if write_fd >= 0:
                os.close(write_fd)
            if child is not None and child.poll() is None:
                try:
                    os.killpg(child.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                child.wait()
            launch_stack.close()


if __name__ == "__main__":
    # This is a private inherited descriptor capability, never an environment
    # selector or a serialized source-qualification claim.
    if len(sys.argv) != 8 or sys.argv[1] != "--private-cohort-worker":
        raise SystemExit(2)
    if not sys.argv[2].isdecimal() or sys.argv[7] != "12030":
        raise SystemExit(2)
    raise SystemExit(_cohort_worker(int(sys.argv[2]), *sys.argv[3:7], int(sys.argv[7])))
