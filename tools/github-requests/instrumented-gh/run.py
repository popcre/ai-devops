#!/usr/bin/env python3
"""Isolated Linux prototype runner. Metadata never shares command output."""
import argparse
import json
import os
import select
import signal
import subprocess
import time
import sys
import pathlib
import re
import stat

UNKNOWN = {"measurement": "outgoing_write_observation", "http_requests": None,
           "observed_completed_writes": None, "failed_write_attempts": None,
           "observed_external_writes": None, "complete": False}
FINAL_KEYS = {"schema", "finished", "observed_completed_writes", "failed_write_attempts",
              "observed_external_writes", "incomplete", "http_requests"}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate metadata key")
        result[key] = value
    return result


def validate(raw):
    try:
        if len(raw) > 4096:
            return UNKNOWN.copy()
        records = [json.loads(line, object_pairs_hook=unique_object) for line in raw.splitlines()]
        if (len(records) != 2 or records[0] != {"schema": 1, "started": True}
                or type(records[0]["schema"]) is not int or records[0]["started"] is not True):
            return UNKNOWN.copy()
        final = records[1]
        if (type(final) is not dict or set(final) != FINAL_KEYS
                or type(final["schema"]) is not int or final["schema"] != 1
                or final["finished"] is not True or type(final["incomplete"]) is not bool
                or final["http_requests"] is not None):
            return UNKNOWN.copy()
        for key in ("observed_completed_writes", "failed_write_attempts", "observed_external_writes"):
            if type(final[key]) is not int or not 0 <= final[key] <= 1000000000:
                return UNKNOWN.copy()
        result = UNKNOWN.copy()
        for key in ("observed_completed_writes", "failed_write_attempts", "observed_external_writes"):
            result[key] = final[key]
        result["complete"] = not final["incomplete"] and final["failed_write_attempts"] == 0
        # Remain an observed subset until command/client census is qualified.
        return result
    except (ValueError, KeyError, TypeError):
        return UNKNOWN.copy()


def _private_dir(path, empty=False):
    """Return a stable identity for a fixture-owned private directory."""
    if not isinstance(path, str) or not path or not os.path.isabs(path):
        return None
    current = pathlib.Path(path)
    parts = current.parts
    if not parts:
        return None
    fd = None
    try:
        fd = os.open(parts[0] or os.sep, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
        for component in parts[1:]:
            info = os.fstat(fd)
            if info.st_uid not in (0, os.getuid()) or (info.st_mode & 0o022 and not (info.st_uid == 0 and info.st_mode & stat.S_ISVTX)):
                return None
            child = os.open(component, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=fd)
            os.close(fd)
            fd = child
        info = os.fstat(fd)
        if info.st_uid != os.getuid() or info.st_mode & 0o077:
            return None
        if empty and os.listdir(fd):
            return None
        return (info.st_dev, info.st_ino, info.st_mode, info.st_uid)
    except (OSError, ValueError):
        return None
    finally:
        if fd is not None:
            os.close(fd)


_PROFILE_ALLOWED = {
    "GH_CONFIG_DIR", "GH_HOST", "GH_TOKEN", "GH_ENTERPRISE_TOKEN",
    "GH_PAGER", "GH_PROMPT_DISABLED", "HOME", "XDG_CACHE_HOME", "TMPDIR", "TMP", "TEMP",
    "PATH", "LANG", "LC_ALL", "LC_CTYPE", "TZ", "NO_COLOR",
    "SSL_CERT_FILE", "SSL_CERT_DIR", "PYTHONPATH",
}


def _profile_state(host, environment=None):
    env = os.environ if environment is None else environment
    if os.name != "posix" or os.uname().sysname != "Linux":
        return None
    if (not isinstance(host, str) or not host or any(ord(c) < 33 or ord(c) == 127 or c == "/" for c in host)
            or env.get("GH_HOST") != host):
        return None
    if os.isatty(0) or os.isatty(1):
        return None
    if env.get("GH_PAGER") != "" or any(name in env for name in ("PAGER", "GH_FORCE_TTY", "GH_PATH", "PYTHONHOME")):
        return None
    if "PATH" not in env or env["PATH"] != "":
        return None
    if any(name not in _PROFILE_ALLOWED for name in env):
        return None
    present_tokens = [name for name in ("GH_TOKEN", "GH_ENTERPRISE_TOKEN") if name in env]
    if len(present_tokens) != 1 or not env.get(present_tokens[0]) or env.get("GH_PROMPT_DISABLED") != "1":
        return None
    temp_value = env.get("TMPDIR") or env.get("TMP") or env.get("TEMP")
    if any(name in env and env[name] != temp_value for name in ("TMP", "TEMP")):
        return None
    if "PYTHONPATH" in env and env["PYTHONPATH"] != str(pathlib.Path(__file__).resolve().parent):
        return None
    config = _private_dir(env.get("GH_CONFIG_DIR"), empty=True)
    home = _private_dir(env.get("HOME"))
    cache = _private_dir(env.get("XDG_CACHE_HOME"))
    temp = _private_dir(temp_value)
    if not all((config, home, cache, temp)):
        return None
    # Config must be a genuinely empty regular directory, with no hidden
    # pager, host, extension, or updater input available to the child.
    try:
        config_path = pathlib.Path(env["GH_CONFIG_DIR"])
        if any((config_path / name).exists() for name in ("config.yml", "hosts.yml", "extensions")):
            return None
        config_info = os.stat(config_path, follow_symlinks=False)
        config_state = (config_info.st_mtime_ns, config_info.st_ctime_ns, tuple(sorted(os.listdir(config_path))))
    except (KeyError, OSError):
        return None
    return (config, config_state, home, cache, temp,
            tuple(sorted((name, env[name]) for name in env if name in _PROFILE_ALLOWED)))


def validate_profile(host, environment=None):
    """Validate the finite controlled-fixture profile without changing it."""
    return _profile_state(host, environment) is not None


def run_counted(binary, arguments, host, digest):
    if not eligible(arguments, host) or not validate_profile(host):
        return 2, UNKNOWN.copy()
    before = _profile_state(host)
    from sealed import verified_snapshot

    with verified_snapshot(binary, digest) as executable:
        return run_verified(executable, binary, arguments, host, before)


def run_verified(executable, binary, arguments, host, expected_profile=None):
    if not eligible(arguments, host) or not validate_profile(host):
        return 2, UNKNOWN.copy()
    before = expected_profile or _profile_state(host)
    if before is None:
        return 2, UNKNOWN.copy()
    read_fd, write_fd = os.pipe()
    env = os.environ.copy()
    env["AI_GH_HTTP_COUNTER_FD"] = str(write_fd)
    env["AI_GH_HTTP_COUNTER_HOST"] = host
    child = None
    saved_handlers = {}
    raw = bytearray()
    overflow = eof = False
    try:
        # Resolve the PARENT's still-open immutable memfd. The child receives
        # no executable descriptor and cannot leak it into descendants.
        pinned_exec = f"/proc/{os.getpid()}/fd/{executable.fileno()}"
        # Upstream's supported self-executable override must stay bound to the
        # already verified image while synchronous children start. This is a
        # pathname to immutable bytes, not the replaceable original artifact.
        # Absent or empty overrides follow upstream default-self semantics.
        env["GH_PATH"] = pinned_exec
        child = subprocess.Popen([str(binary), *arguments], executable=pinned_exec,
                                 env=env, pass_fds=(write_fd,), start_new_session=True)
        os.close(write_fd)
        write_fd = -1

        def forward(signum, _frame):
            if child.poll() is None:
                try:
                    os.killpg(child.pid, signum)
                except ProcessLookupError:
                    pass

        for signum in (signal.SIGINT, signal.SIGTERM):
            saved_handlers[signum] = signal.signal(signum, forward)
        deadline = None
        while not eof:
            if child.poll() is not None and deadline is None:
                deadline = time.monotonic() + 0.5
            if deadline is not None and time.monotonic() >= deadline:
                break
            if not select.select([read_fd], [], [], 0.05)[0]:
                continue
            chunk = os.read(read_fd, 4096)
            if not chunk:
                eof = True
            elif len(raw) + len(chunk) > 4096:
                overflow = True
                raw.clear()
            elif not overflow:
                raw.extend(chunk)
        status = child.wait()
        if _profile_state(host) != before:
            return (status if status >= 0 else 128 - status), UNKNOWN.copy()
        result = validate(raw) if eof and not overflow else UNKNOWN.copy()
        return (status if status >= 0 else 128 - status), result
    finally:
        for signum, handler in saved_handlers.items():
            signal.signal(signum, handler)
        os.close(read_fd)
        if write_fd >= 0:
            os.close(write_fd)
        if child is not None and child.poll() is None:
            # Exceptional runner cleanup must never leave or replay a command.
            try:
                os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            child.wait()


_DURATION = re.compile(r"(?:0|[1-9][0-9]{0,8})(?:ns|us|µs|ms|s|m|h|d)?$")
_ENDPOINT = re.compile(r"^/?[A-Za-z0-9._~:/?&=+%,-]+$")
_VALUE_LONG = {"--cache", "--jq", "--template", "--header", "--hostname", "--method"}
_VALUE_SHORT = {"-q", "-t", "-H", "-X"}


def _literal_endpoint(value):
    if (not isinstance(value, str) or not _ENDPOINT.fullmatch(value) or value.startswith("//")
            or value.startswith("-")):
        return False
    if "graphql" in value.lower() or "://" in value or "#" in value or "\\" in value:
        return False
    if any(token in value for token in ("{", "}", ":owner", ":repo", ":branch")):
        return False
    if "%" in value:
        if re.search(r"%(?![0-9A-Fa-f]{2})", value):
            return False
        try:
            from urllib.parse import unquote
            decoded = unquote(value)
        except Exception:
            return False
        if "%" in decoded or any(char in decoded for char in "{}\\\x00\r\n"):
            return False
        if (not _ENDPOINT.fullmatch(decoded) or decoded.startswith("//") or decoded.startswith("-")
                or any(token in decoded for token in (":owner", ":repo", ":branch"))):
            return False
    return True


def _header_value_ok(value, host):
    if not isinstance(value, str) or not value.strip() or any(ord(c) < 32 or ord(c) == 127 for c in value):
        return False
    if ":" not in value:
        return False
    name, header_value = value.split(":", 1)
    if name.strip().lower() == "host" and host is not None and header_value.strip() != host:
        return False
    return True


def eligible(arguments, host=None):
    """Accept only one literal read-only API endpoint and finite API flags."""
    if not arguments or arguments[0] != "api":
        return False
    endpoint = None
    seen = set()
    i = 1
    terminated = False
    while i < len(arguments):
        arg = arguments[i]
        if terminated:
            if endpoint is None and _literal_endpoint(arg):
                endpoint = arg
            else:
                return False
            i += 1
            continue
        if arg == "--":
            terminated = True
            i += 1
            continue
        if arg.startswith("--"):
            name, sep, value = arg.partition("=")
            if name in {"--paginate", "--slurp", "--silent", "--include"}:
                key = {"--silent": "silent", "--include": "include"}.get(name, name)
                if sep or key in seen:
                    return False
                seen.add(key)
            elif name in _VALUE_LONG:
                key = name[2:]
                if key in seen or (not sep and i + 1 >= len(arguments)):
                    return False
                if sep:
                    value = value
                else:
                    i += 1
                    value = arguments[i]
                if not isinstance(value, str) or not value or any(ord(c) < 32 or ord(c) == 127 for c in value):
                    return False
                if name == "--cache" and not _DURATION.fullmatch(value):
                    return False
                if name == "--method" and value not in ("GET", "HEAD"):
                    return False
                if name == "--hostname" and host is not None and value != host:
                    return False
                if name == "--header" and not _header_value_ok(value, host):
                    return False
                seen.add(key)
            else:
                return False
        elif arg in {"-s", "-i"}:
            key = {"-s": "silent", "-i": "include"}[arg]
            if key in seen:
                return False
            seen.add(key)
        elif arg.startswith("-"):
            name = arg[:2]
            key = {"-q": "jq", "-t": "template", "-H": "header", "-X": "method"}.get(name)
            if name not in _VALUE_SHORT or key in seen or len(arg) == 2:
                return False
            value = arg[2:]
            if name == "-X" and value not in ("GET", "HEAD"):
                return False
            if name == "-H" and not _header_value_ok(value, host):
                return False
            if name in {"-q", "-t"} and not value:
                return False
            seen.add(key)
        else:
            if endpoint is not None or not _literal_endpoint(arg):
                return False
            endpoint = arg
        i += 1
    return endpoint is not None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--api-host", required=True)
    parser.add_argument("--metadata-fd", type=int, required=True)
    parser.add_argument("arguments", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    arguments = args.arguments[1:] if args.arguments[:1] == ["--"] else args.arguments
    if args.metadata_fd < 3:
        raise ValueError("separate metadata channel required")
    if not eligible(arguments, args.api_host) or not validate_profile(args.api_host):
        os.write(args.metadata_fd, (json.dumps(UNKNOWN, separators=(",", ":")) + "\n").encode())
        print('qualification environment or command is outside the supported verified read-only scope', file=sys.stderr)
        raise SystemExit(2)
    status, record = run_counted(args.binary, arguments, args.api_host, args.sha256)
    os.write(args.metadata_fd, (json.dumps(record, separators=(",", ":")) + "\n").encode())
    raise SystemExit(status)


if __name__ == "__main__":
    main()
