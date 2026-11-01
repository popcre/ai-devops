"""Bounded Linux observation of explicit public task reads; no installed routing.

The controller supplies an exact build-manifest digest and already-authorized
arguments. Command output streams unchanged. Only numeric counter metadata is
returned; credentials/configuration are never read or copied by this module.
The old isolated qualification CLI remains independent and unchanged.
"""
import contextlib
import hashlib
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

from run import UNKNOWN, validate
from sealed import verified_snapshot
from source_binding import validate_source_binding

REPOSITORY = "popcre/ai-devops"
FAMILIES = {("issue", "view"), ("issue", "list"), ("pr", "view"),
            ("pr", "list"), ("pr", "checks"), ("run", "view"),
            ("run", "list"), ("repo", "view")}
VALUE_FLAGS = {"--json", "--jq", "--repo", "-R", "--limit", "-L",
               "--state", "--base", "--head", "--branch", "--workflow"}


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
            if (info.st_uid not in (0, os.getuid())
                    or (info.st_mode & 0o022 and not (info.st_uid == 0 and info.st_mode & stat.S_ISVTX))):
                return False
            child = os.open(component, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=descriptor)
            os.close(descriptor)
            descriptor = child
        info = os.fstat(descriptor)
        return info.st_uid == os.getuid() and not info.st_mode & 0o077
    except FileNotFoundError:
        # Token-authenticated existing environments need not create a config.
        return any(bool(environment.get(name)) for name in ("GH_TOKEN", "GITHUB_TOKEN"))
    except OSError:
        return False
    finally:
        if descriptor is not None:
            os.close(descriptor)


class ManagedReadObservation:
    """One explicit cohort, retained sealed images, no service or command replay.

    run(arguments, workflow_id) streams normal command output and returns
    (original_exit_status, numeric_record). The caller associates its validated
    command label and opaque workflow ID with that record. close() includes all
    manifest verification and image bootstrap in cohort_elapsed_ns.
    """
    def __init__(self, manifest, expected_manifest_sha256, *, transport_path, transport_sha256,
                 transport_boundary=None, environment=None, cwd=None):
        self.started_ns = time.perf_counter_ns()
        self.environment = dict(os.environ if environment is None else environment)
        self.cwd = cwd
        self._stack = contextlib.ExitStack()
        self._images = {}
        self._image_hashes = {}
        self.transport_path = os.path.abspath(transport_path)
        self.transport_sha256 = transport_sha256
        self.manifest_sha256 = expected_manifest_sha256
        self.transport_boundary = dict(transport_boundary) if transport_boundary else None
        self.source_identity = None
        source_bootstrap = transport_boundary.get("bootstrap_ns") if transport_boundary else 0
        self.bootstrap_complete = type(source_bootstrap) is int and source_bootstrap >= 0
        self.source_bootstrap_ns = source_bootstrap if self.bootstrap_complete else None
        self._transport = None
        self.commands = 0
        self.cohort_elapsed_ns = None
        if (os.name != "posix" or not hasattr(os, "uname") or os.uname().sysname != "Linux"
                or threading.current_thread() is not threading.main_thread()
                or self.environment.get("GH_HOST", "github.com") != "github.com"
                or any(self.environment.get(name) for name in ("GH_PATH", "GH_DEBUG", "GH_PAGER", "PAGER", "GH_FORCE_TTY"))
                or any(name.startswith("AI_GH_HTTP_COUNTER_") for name in self.environment)
                or any(value and (name in {"BASH_ENV", "ENV", "PYTHONPATH", "PYTHONHOME", "PYTHONSTARTUP",
                                           "PYTHONINSPECT", "PYTHONUSERBASE", "LD_PRELOAD", "LD_LIBRARY_PATH"}
                                  or name.startswith("BASH_FUNC_")) for name, value in self.environment.items())
                or os.isatty(0) or os.isatty(1) or not _protected_config(self.environment)):
            raise ValueError("unsupported managed observation environment")
        try:
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
                if (os.path.abspath(transport_boundary["transport_path"]) != self.transport_path
                        or not transport_boundary["argv_prefix"]
                        or transport_boundary["argv_prefix"][-1] != "--"
                        or transport_boundary["bash_path"] != self.bash
                        or any(type(fd) is not int or fd < 3 for fd in transport_boundary["pass_fds"])):
                    raise ValueError("retained generation transport mismatch")
                identity = transport_boundary["identity"]
                for key, length in (("source_sha", 40), ("source_fingerprint", 64), ("install_generation_binding", 64)):
                    if not isinstance(identity.get(key), str) or not re.fullmatch(r"[0-9a-f]{%d}" % length, identity[key]):
                        raise ValueError("retained generation identity is incomplete")
                if identity.get("source_boundary") != "linux_sealed_generation":
                    raise ValueError("unsupported retained generation boundary")
                self.source_identity = {key: identity[key] for key in
                                        ("source_sha", "source_fingerprint", "install_generation_binding", "source_boundary")}
                self.transport_boundary["argv_prefix"] = tuple(transport_boundary["argv_prefix"])
                self.transport_boundary["pass_fds"] = tuple(transport_boundary["pass_fds"])
                self._native_mount = self._stack.enter_context(tempfile.TemporaryDirectory(prefix="gh-counter-observation-"))
            with verified_snapshot(manifest, expected_manifest_sha256, limit=1048576) as stream:
                build = json.load(stream)
            validate_source_binding(build["counter_source_binding"], pathlib.Path(__file__).parent)
            for kind in ("baseline", "instrumented"):
                artifact = build["artifacts"][kind]
                self._images[kind] = self._stack.enter_context(verified_snapshot(artifact["path"], artifact["sha256"]))
                self._image_hashes[kind] = artifact["sha256"]
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
                "commands": self.commands, "manifest_sha256": self.manifest_sha256,
                "transport_sha256": self.transport_sha256, "source_bootstrap_ns": self.source_bootstrap_ns,
                "bootstrap_complete": self.bootstrap_complete}

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
        if self.commands >= 40 or not self._transport_matches():
            raise ValueError("observation cohort limit or changed transport")
        if subprocess.PIPE in (stdin, stdout, stderr):
            raise ValueError("caller-owned streaming descriptors required")
        if type(timeout_seconds) is not int or not 1 <= timeout_seconds <= 300:
            raise ValueError("bounded observation timeout required")
        read_fd, write_fd = os.pipe()
        child = None
        handlers = {}
        raw = bytearray()
        complete = overflow = False
        started = time.perf_counter_ns()
        deadline = time.monotonic() + timeout_seconds
        interrupted = []
        timed_out = False
        try:
            image = self._images[kind]
            executable = f"/proc/{os.getpid()}/fd/{image.fileno()}"
            prefix = []
            retained = ()
            if self.transport_boundary:
                # Parent /proc handles cannot cross a new user namespace.
                # Bind the same sealed bytes into a private namespace-only
                # tmpfs; no image or helper is written to the host directory.
                executable = os.path.join(self._native_mount, "gh")
                prefix = [*self.transport_boundary["argv_prefix"][:-1],
                          "--tmpfs", self._native_mount, "--perms", "0500",
                          "--ro-bind-data", str(image.fileno()), executable,
                          "--remount-ro", self._native_mount, "--"]
                retained = (*self.transport_boundary["pass_fds"], image.fileno())
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
                    os.killpg(child.pid, signum)
                except ProcessLookupError:
                    pass

            for signum in (signal.SIGINT, signal.SIGTERM):
                handlers[signum] = signal.signal(signum, forward)
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
                      and self._transport_matches() else {**UNKNOWN, "counted_invocations": None})
            verified = record["complete"] and self.transport_boundary is not None
            self.commands += 1
            return (status if status >= 0 else 128 - status), {
                **record, "measurement": "managed_read_observation", "command_label": label,
                "workflow_id": workflow_id, "exit_status": status if status >= 0 else 128 - status,
                "includes_admission_probes": True, "probe_attribution": "unseparated",
                "transport_source_verified": "verified" if verified else "unknown",
                "source_identity": dict(self.source_identity) if verified else None,
                "counter_image_sha256": self._image_hashes[kind], "counter_enabled": kind == "instrumented",
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
