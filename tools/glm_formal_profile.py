"""Managed, Linux-only formal GLM profile (no provider calls at install time).

General GLM configuration/service is deliberately outside this module's targets.
Operational entry is setup-opencode-glm.sh / ai-glm, not a caller-owned registry.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import socket
import stat
import sys
import subprocess
import io
import tarfile

# Audited actual formal wrapper, evidence boundary, accounting and shared
# governance dependencies. Full release is copied, but unrelated provider/app
# implementations are not compatibility blockers. New dependencies require a
# reviewed change to an existing pinned importer and therefore a profile upgrade.
CRITICAL_FILES = frozenset({
    "bin/ai-glm", "bin/ai-review-packet", "bin/ai-review-sandbox",
    "bin/ai-review-preflight", "bin/ai-review-lifecycle", "bin/ai-review-scoreboard",
    "bin/ai-task-gates", "bin/ai-process-supervisor", "bin/ai-review-code-only.py",
    "tools/glm_formal_profile.py", "tools/glm_output_recovery.py",
    "tools/reviewer_event_guard.sh", "tools/reviewer_events.py", "tools/reviewer_maintenance.py",
    "tools/reviewer_admission.py", "tools/reviewer_credit_stream.py",
    "tools/review_action_profile.py", "tools/application_workflow_target.py",
    "tools/lib/provider-wrapper-common.sh", "tools/lib/session-tmp.sh", "tools/lib/task-gates.sh",
    "tools/lib/opencode-curl-auth.sh", "tools/lib/opencode-maintenance-lock.sh",
    "config/task-gates.json", "config/reviewer-ci-paths.txt", "config/repository-policy.json",
    "config/reviewer-registry.json", "config/reviewer-capacity.json", "config/review-runner-doors.json",
    "config/review-action-profiles.json", "config/opencode/version",
    "config/opencode/opencode.json", "config/opencode/agent/glm-review.md",
})


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    path = Path(path)
    require(path.parent.resolve() == path.parent, "noncanonical sealed file parent")
    require(not path.is_symlink(), "sealed formal file symlink")
    with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW), "rb") as stream:
        before = os.fstat(stream.fileno())
        require(stat.S_ISREG(before.st_mode) and before.st_uid == os.getuid()
                and before.st_nlink == 1 and before.st_size <= 2 * 1024**3,
                "unsafe sealed formal file")
        result = hashlib.file_digest(stream, "sha256").hexdigest()
        after = os.fstat(stream.fileno())
        identity = lambda item: (item.st_dev, item.st_ino, item.st_size, item.st_mtime_ns, item.st_ctime_ns)
        require(identity(before) == identity(after) == identity(path.lstat()), "sealed file changed during hash")
        return result


def paths(home):
    home = Path(home).resolve()
    base = home / ".config/ai-devops/glm-formal"
    return {"base": base, "config": base / "xdg/opencode",
            "password": base / "server-password", "receipt": base / "origin.json",
            "settings": base / "profile.json", "activation": base / "activation.json",
            "runtimes": base / "runtimes",
            "state": home / ".local/state/ai-devops/glm-formal",
            "data": home / ".local/share/ai-devops/opencode-formal",
            "cache": home / ".cache/ai-devops/opencode-formal",
            "launcher": home / ".local/bin/opencode-glm-formal-launch",
            "unit": home / ".config/systemd/user/opencode-glm-formal.service"}


def private_read(path):
    require(Path(path).parent.resolve() == Path(path).parent, "noncanonical registry parent")
    with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW), "rb") as stream:
        info = os.fstat(stream.fileno())
        require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid()
                and info.st_nlink == 1 and info.st_mode & 0o077 == 0
                and info.st_size <= 1024 * 1024, "untrusted formal registry")
        return json.load(stream)


def atomic(path, data, mode=0o600):
    import tempfile
    path = Path(path)
    require(not path.is_symlink() and path.parent.resolve() == path.parent, "symlink target refused")
    fd, temporary = tempfile.mkstemp(prefix=".formal-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            os.fchmod(stream.fileno(), mode)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def secure_directory(path):
    path = Path(path)
    require(not path.is_symlink() and path.resolve() == path, "symlink directory refused")
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = path.stat()
    require(info.st_uid == os.getuid() and stat.S_ISDIR(info.st_mode)
            and info.st_mode & 0o022 == 0, "unsafe formal directory")


def installed_state(repo):
    repo = Path(repo).resolve()
    launcher = Path("/usr/local/bin/ai-task-gates")
    require(launcher.is_symlink() and launcher.resolve() == repo / "bin/ai-task-gates",
            "formal activation requires the managed installed checkout")
    head = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
    require(re.fullmatch(r"[0-9a-f]{40}", head), "invalid installed source")
    require(not subprocess.check_output(["git", "-C", str(repo), "status", "--porcelain"]),
            "installed source has local overlays")
    subprocess.run(["git", "-C", str(repo), "merge-base", "--is-ancestor", head, "origin/main"],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    manifest = Path("/etc/ai-devops/install-manifest.tsv")
    rows = [line.split("\t") for line in manifest.read_text().splitlines()]
    require([row for row in rows if row[:2] == ["meta", "source_sha"]] == [["meta", "source_sha", head, "-"]],
            "installed manifest/source mismatch")
    for name in ["ai-review", "ai-review-pool", "ai-glm", "ai-task-gates"]:
        target = Path("/usr/local/bin") / name
        matching = [row for row in rows if row[:2] == ["symlink", str(target)]]
        require(len(matching) == 1 and len(matching[0]) == 4
                and target.is_symlink() and target.resolve() == repo / "bin" / name
                and matching[0][2:] == [str(target.resolve()), digest(target.resolve())],
                "installed managed tool does not match manifest")
    return {"head": head, "manifest_sha256": digest(manifest)}


def critical_name(name):
    return name in CRITICAL_FILES


def critical_inventory(repo):
    repo = Path(repo)
    names = [value.decode("utf-8") for value in subprocess.check_output(
        ["git", "-C", str(repo), "ls-tree", "-r", "-z", "--name-only", "HEAD"]).split(b"\0") if value]
    require(CRITICAL_FILES <= set(names), "formal safety dependency is missing")
    return {name: digest(repo / name) for name in names if critical_name(name)}


def release_snapshot(repo, home, head):
    """Full tracked release, not a guessed transitive subset or working overlay."""
    p = paths(home)
    secure_directory(p["runtimes"])
    destination = p["runtimes"] / head
    payload = subprocess.check_output(["git", "-C", str(repo), "archive", "--format=tar", head])
    require(len(payload) <= 128 * 1024**2, "release archive exceeds bound")
    expected = subprocess.check_output(["git", "-C", str(repo), "ls-tree", "-r", "-z", head])
    tree, excluded_gitlinks = {}, {}
    for row in expected.split(b"\0"):
        if not row: continue
        mode_object, name = row.split(b"\t", 1)
        mode, kind, object_id = mode_object.split()
        name = name.decode("utf-8")
        if mode == b"160000" and kind == b"commit":
            # Public release stores only this private transcript-repo pointer.
            # Never initialize, archive, open or copy its working contents.
            require(name == "transcripts", "unqualified release gitlink dependency")
            excluded_gitlinks[name] = object_id.decode("ascii")
            continue
        require(kind == b"blob" and mode in (b"100644", b"100755"), "unsupported release entry")
        tree[name] = mode
    with tarfile.open(fileobj=io.BytesIO(payload), mode="r:") as archive:
        members = archive.getmembers()
        files = {member.name: member for member in members if member.isfile()}
        require(len(files) == sum(member.isfile() for member in members) and set(files) == set(tree),
                "archive differs from complete tracked release")
        for member in members:
            relative = Path(member.name)
            require(not relative.is_absolute() and ".." not in relative.parts
                    and member.name != ".formal-runtime.json"
                    and (member.isdir() or member.isfile()), "unsafe release archive member")
        expected_hashes = {name: hashlib.sha256(archive.extractfile(member).read()).hexdigest()
                           for name, member in files.items()}
        if destination.exists() or destination.is_symlink():
            existing = runtime_hashes(destination)
            require(existing["source_sha"] == head and existing["files"] == expected_hashes
                    and existing["modes"] == {name: 0o700 if mode == b"100755" else 0o600 for name, mode in tree.items()}
                    and existing["excluded_gitlinks"] == excluded_gitlinks,
                    "cached runtime differs from actual Git release")
            return destination
        destination.mkdir(mode=0o700)
        for name, member in files.items():
            target = destination / name
            for parent in reversed(target.parent.relative_to(destination).parents):
                (destination / parent).mkdir(exist_ok=True, mode=0o700)
            target.parent.mkdir(exist_ok=True, mode=0o700)
            fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                         0o700 if tree[name] == b"100755" else 0o600)
            with os.fdopen(fd, "wb") as output:
                output.write(archive.extractfile(member).read())
        hashes = {name: digest(destination / name) for name in tree}
        atomic(destination / ".formal-runtime.json", json.dumps({"version": 1, "source_sha": head,
               "files": hashes, "modes": {name: 0o700 if mode == b"100755" else 0o600 for name, mode in tree.items()},
               "excluded_gitlinks": excluded_gitlinks,
               "critical": {name: value for name, value in hashes.items() if critical_name(name)}}, sort_keys=True).encode())
    runtime_hashes(destination)
    return destination


def runtime_hashes(runtime):
    runtime = Path(runtime)
    require(runtime.resolve() == runtime and not runtime.is_symlink(), "unsafe runtime root")
    require(runtime.stat().st_uid == os.getuid() and runtime.stat().st_mode & 0o077 == 0,
            "runtime directory is not private")
    manifest = private_read(runtime / ".formal-runtime.json")
    require(manifest.get("version") == 1 and runtime.name == manifest.get("source_sha")
            and isinstance(manifest.get("files"), dict), "invalid runtime manifest")
    require(isinstance(manifest.get("modes"), dict) and set(manifest["modes"]) == set(manifest["files"]),
            "runtime mode inventory changed")
    require(manifest.get("critical") == {name: value for name, value in manifest["files"].items() if critical_name(name)}
            and isinstance(manifest.get("excluded_gitlinks"), dict)
            and set(manifest["excluded_gitlinks"]) <= {"transcripts"}, "runtime dependency inventory changed")
    actual = set()
    for entry in runtime.rglob("*"):
        require(not entry.is_symlink(), "runtime symlink refused")
        if entry.is_dir():
            require(entry.stat().st_uid == os.getuid() and entry.stat().st_mode & 0o077 == 0,
                    "runtime child directory is not private")
        if entry.is_file() and entry.relative_to(runtime).as_posix() != ".formal-runtime.json":
            actual.add(entry.relative_to(runtime).as_posix())
    require(actual == set(manifest["files"]), "runtime inventory changed")
    for name, expected in manifest["files"].items():
        require(manifest["modes"][name] in (0o600, 0o700)
                and (runtime / name).stat().st_mode & 0o777 == manifest["modes"][name],
                "runtime file permissions changed")
        require(digest(runtime / name) == expected, "immutable runtime file changed")
    return manifest


def install(repo, home, port):
    require(sys.platform.startswith("linux"), "formal profile is Linux-only; general profile unchanged")
    repo, home = Path(repo).resolve(), Path(home).resolve()
    p = paths(home)
    if p["activation"].exists() or p["activation"].is_symlink():
        record = private_read(p["activation"])
        settings = private_read(p["settings"])
        activation_identity(record, p, settings)
        require(settings["installed_checkout"] == str(repo), "active profile belongs to another checkout")
        installed_compatible(record, repo)
        origin(home)  # Read-only readiness; never renews routing or an old run.
        return {"profile": "formal-review", "installed": True, "activated": True, "unchanged": True}
    installed = installed_state(repo)
    require(type(port) is int and 1024 <= port <= 65535 and port != 4096,
            "formal loopback port must be separate")
    # No existing listener is stopped, reused, or mistaken for this profile.
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", port))
    version = (repo / "config/opencode/version").read_text().strip()
    require(re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version), "invalid OpenCode pin")
    binary = home / f".local/lib/ai-devops/opencode/{version}/node_modules/opencode-ai/bin/opencode.exe"
    require(binary.is_file() and os.access(binary, os.X_OK), "install pinned general runtime first")
    for key in ["base", "config", "state", "data", "cache"]:
        secure_directory(p[key])
    installed_repo = repo
    repo = release_snapshot(repo, home, installed["head"])
    secure_directory(p["config"] / "agent")
    secure_directory(p["launcher"].parent)
    secure_directory(p["unit"].parent)
    config = json.loads((repo / "config/opencode/opencode.json").read_text())
    require(not config.get("mcp") and not config.get("plugin"), "formal profile forbids custom tool origins")
    require(config.get("model") == "zai-coding-plan/glm-5.3"
            and config.get("small_model") == "zai-coding-plan/glm-5.3"
            and not config.get("provider") and not config.get("instructions"),
            "formal model/provider/global instructions must preserve canonical policy")
    config.update({"plugin": [], "mcp": {}})
    atomic(p["config"] / "opencode.json", json.dumps(config, sort_keys=True).encode())
    # Pinned core Config.ensureGitignore creates these exact bytes. Seal them
    # before launch so normal startup cannot introduce untracked config files.
    atomic(p["config"] / ".gitignore", b"node_modules\npackage.json\npackage-lock.json\nbun.lock\n.gitignore")
    atomic(p["config"] / "agent/glm-review.md", (repo / "config/opencode/agent/glm-review.md").read_bytes())
    # The project-disable flag must not silently remove the general profile's
    # global instructions. Exact bytes and original digest remain attested.
    global_source = home / ".config/ai-devops/opencode-xdg/opencode/AGENTS.md"
    global_hash = None
    if global_source.exists():
        require(not global_source.is_symlink(), "untrusted global instructions")
        data = global_source.read_bytes()
        global_hash = hashlib.sha256(data).hexdigest()
        atomic(p["config"] / "AGENTS.md", data)
    elif (p["config"] / "AGENTS.md").exists():
        raise ValueError("global instructions changed; reconcile before profile update")
    if not p["password"].exists():
        import secrets
        fd = os.open(p["password"], os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, "w") as stream:
            stream.write(secrets.token_urlsafe(32))
    else:
        fd = os.open(p["password"], os.O_RDONLY | os.O_NOFOLLOW)
        try:
            info = os.fstat(fd)
            require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid()
                    and info.st_nlink == 1 and info.st_mode & 0o077 == 0, "unsafe formal password")
        finally:
            os.close(fd)
    helper = repo / "tools/glm_formal_profile.py"
    quote = shlex.quote
    launcher = f'''#!/usr/bin/env bash
set -euo pipefail
_general={quote(str(home / '.config/ai-devops'))}
if [ -z "${{ZAI_API_KEY:-}}" ]; then
  [ -z "${{AI_GLM_FORMAL_REEXEC:-}}" ] || {{ echo 'formal GLM key unavailable' >&2; exit 1; }}
  [ -s "$_general/op-service-account" ] && [ -f "$_general/mcp.env" ] || exit 1
  OP_SERVICE_ACCOUNT_TOKEN="$(<"$_general/op-service-account")"
  export OP_SERVICE_ACCOUNT_TOKEN AI_GLM_FORMAL_REEXEC=1
  exec op run --env-file "$_general/mcp.env" -- "$0"
fi
exec python3 {quote(str(helper))} launch
'''
    atomic(p["launcher"], launcher.encode(), 0o700)
    settings = {"version": 1, "repo": str(repo), "runtime_manifest_sha256": digest(repo / ".formal-runtime.json"),
                "installed_checkout": str(installed_repo),
                "release_sha": installed["head"], "binary": str(binary), "pin": version,
                "port": port, "global_source": str(global_source), "global_sha256": global_hash,
                "helper_sha256": digest(helper), "launcher_sha256": digest(p["launcher"]),
                "source_hashes": {str(repo / name): digest(repo / name) for name in [
                    "tools/glm_formal_profile.py", "tools/glm_output_recovery.py", "bin/ai-glm",
                    "bin/ai-review-packet", "config/opencode/agent/glm-review.md"]}}
    unit = f'''[Unit]
Description=AI DevOps isolated formal GLM review (loopback only)
StartLimitIntervalSec=300
StartLimitBurst=5
[Service]
Type=simple
ExecStart={p['launcher']}
Restart=on-failure
RestartSec=10
NoNewPrivileges=true
PrivateTmp=true
UMask=0077
[Install]
WantedBy=default.target
'''
    atomic(p["unit"], unit.encode(), 0o600)
    settings["installed_hashes"] = {str(path): digest(path) for path in [
        p["launcher"], p["unit"], p["config"] / "opencode.json",
        p["config"] / "agent/glm-review.md", p["config"] / ".gitignore", binary]}
    atomic(p["settings"], json.dumps(settings, sort_keys=True).encode())
    # Deliberately no daemon-reload/start/enable. Explicit protected activation
    # is separate from installation, and the general service is never touched.
    return {"profile": "formal-review", "installed": True, "activated": False, "port": port}


def process_start(pid):
    return Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[19]


def file_hashes(p, settings):
    require(digest(Path(settings["repo"]) / ".formal-runtime.json") == settings["runtime_manifest_sha256"],
            "immutable runtime manifest changed")
    runtime_hashes(settings["repo"])
    for name, expected in settings["installed_hashes"].items():
        require(digest(name) == expected, "formal installed config or runtime changed")
    for name, expected in settings["source_hashes"].items():
        require(digest(name) == expected, "installed formal source changed")
    allowed = {"opencode.json", "agent/glm-review.md", "AGENTS.md", ".gitignore"}
    # Refuse any file that could introduce a project/tool/plugin/agent override.
    for entry in p["config"].rglob("*"):
        require(not entry.is_symlink(), "formal config symlink")
        relative = entry.relative_to(p["config"]).as_posix()
        require(relative == "agent" or relative in allowed, "unexpected formal config content")
    result = {str(p["launcher"]): digest(p["launcher"]),
              str(p["unit"]): digest(p["unit"]),
              str(Path(settings["repo"]) / "tools/glm_formal_profile.py"): digest(Path(settings["repo"]) / "tools/glm_formal_profile.py"),
              settings["binary"]: digest(settings["binary"]),
              str(p["config"] / "opencode.json"): digest(p["config"] / "opencode.json"),
              str(p["config"] / "agent/glm-review.md"): digest(p["config"] / "agent/glm-review.md")}
    result.update(settings["source_hashes"])
    result[str(Path(settings["repo"]) / ".formal-runtime.json")] = settings["runtime_manifest_sha256"]
    if settings["global_sha256"] is not None:
        require(digest(settings["global_source"]) == settings["global_sha256"], "global instructions drifted")
        require(digest(p["config"] / "AGENTS.md") == settings["global_sha256"], "global instruction copy drifted")
        result[settings["global_source"]] = settings["global_sha256"]
        result[str(p["config"] / "AGENTS.md")] = settings["global_sha256"]
    else:
        require(not Path(settings["global_source"]).exists() and not (p["config"] / "AGENTS.md").exists(),
                "global instructions appeared after installation")
    return result


def instructions(snapshot, packet):
    snapshot, packet = Path(snapshot).resolve(), Path(packet).resolve()
    raw = subprocess.check_output(["git", "-C", str(snapshot), "ls-files", "-z", "--cached",
                                   "--others", "--exclude-standard"])
    names = sorted(set(os.fsdecode(x) for x in raw.split(b"\0") if x and Path(os.fsdecode(x)).name == "AGENTS.md"))
    rows, payload, total = [], [], 0
    for name in names:
        relative = Path(name)
        require(not relative.is_absolute() and ".." not in relative.parts, "instruction path escaped")
        path = snapshot / relative
        require(path.resolve() == path and path.is_file(), "instruction symlink or missing file")
        data = path.read_bytes()
        total += len(data)
        require(len(data) <= 1024 * 1024 and total <= 4 * 1024 * 1024, "instruction collection exceeds safe capture")
        text = data.decode("utf-8")
        row = {"path": name, "scope": relative.parent.as_posix(), "bytes": len(data),
               "sha256": hashlib.sha256(data).hexdigest()}
        rows.append(row)
        payload.append(f"\nBEGIN ORIGINAL INSTRUCTIONS {json.dumps(name)}; applies only within {json.dumps(row['scope'])}\n"
                       + text + f"\nEND ORIGINAL INSTRUCTIONS {json.dumps(name)}\n")
    prefix = ("Repository instructions below preserve their ORIGINAL directory scopes. For a target path, "
              "apply only instructions whose directory is that target or its ancestor, with more specific "
              "instructions taking precedence exactly as in the repository. Never apply an unrelated nested "
              "directory's instructions globally. Global protected instructions remain in the system context.\n")
    atomic(packet / "FORMAL-INSTRUCTIONS.txt", (prefix + "".join(payload)).encode())
    atomic(packet / "FORMAL-INSTRUCTIONS.json", json.dumps({"version": 1, "files": rows}, sort_keys=True).encode())
    return {"sha256": digest(packet / "FORMAL-INSTRUCTIONS.txt"), "files": len(rows)}


def launch(home):
    require(sys.platform.startswith("linux"), "formal profile is Linux-only")
    p = paths(home)
    os.umask(0o077)
    settings = private_read(p["settings"])
    require(digest(__file__) == settings["helper_sha256"]
            and digest(p["launcher"]) == settings["launcher_sha256"], "formal launcher drift")
    require(bool(os.environ.get("ZAI_API_KEY")), "formal coding-plan credential missing")
    environment = dict(os.environ)
    environment.update({"XDG_CONFIG_HOME": str(p["config"].parent),
                        "XDG_DATA_HOME": str(p["data"]),
                        "XDG_STATE_HOME": str(p["state"] / "opencode"),
                        "XDG_CACHE_HOME": str(p["cache"]),
                        "OPENCODE_CONFIG": str(p["config"] / "opencode.json"),
                        "OPENCODE_DISABLE_PROJECT_CONFIG": "true",
                        "OPENCODE_DISABLE_DEFAULT_PLUGINS": "true"})
    # No inherited alternate config/content, plugins, or provider selection can
    # redefine builtin tools under an attested fixed formal profile.
    for key in ["OPENCODE_CONFIG_CONTENT", "OPENCODE_CONFIG_DIR", "OPENCODE_PLUGIN_META_FILE"]:
        environment.pop(key, None)
    receipt = {"version": 1, "profile": "formal-review", "pid": os.getpid(),
               "start": process_start(os.getpid()), "uid": os.getuid(),
               "binary": settings["binary"], "pin": settings["pin"], "port": settings["port"],
               "project_config_disabled": True, "default_plugins_disabled": True,
               "hashes": file_hashes(p, settings)}
    atomic(p["receipt"], json.dumps(receipt, sort_keys=True).encode())
    os.execve(settings["binary"], [settings["binary"], "serve", "--hostname", "127.0.0.1",
                                  "--port", str(settings["port"])],
              {**environment, "OPENCODE_SERVER_PASSWORD": p["password"].read_text().strip()})


def origin(home):
    p = paths(home)
    settings = private_read(p["settings"])
    receipt = private_read(p["receipt"])
    require(receipt.get("version") == 1 and receipt.get("profile") == "formal-review"
            and receipt.get("uid") == os.getuid(), "wrong formal origin")
    pid = receipt.get("pid")
    require(type(pid) is int and pid > 1 and process_start(pid) == receipt.get("start"), "stale formal process")
    require(os.stat(f"/proc/{pid}").st_uid == os.getuid()
            and os.readlink(f"/proc/{pid}/exe") == settings["binary"], "wrong formal executable")
    require(receipt.get("project_config_disabled") is True
            and receipt.get("default_plugins_disabled") is True
            and receipt.get("hashes") == file_hashes(p, settings), "formal origin drifted")
    require(receipt.get("port") == settings["port"] and receipt.get("pin") == settings["pin"], "wrong formal endpoint")
    # Verify the exact live process owns the selected loopback listener.
    address = f"0100007F:{settings['port']:04X}"
    inodes = {line.split()[9] for line in Path("/proc/net/tcp").read_text().splitlines()[1:]
              if line.split()[1] == address and line.split()[3] == "0A"}
    owned = set()
    for entry in Path(f"/proc/{pid}/fd").iterdir():
        try:
            target = os.readlink(entry)
        except FileNotFoundError:
            continue
        if target.startswith("socket:["):
            owned.add(target[8:-1])
    require(bool(inodes & owned), "formal process does not own loopback listener")
    return {"sha256": digest(p["receipt"]), "port": settings["port"], "pin": settings["pin"],
            "managed_directory": str(p["data"] / "opencode/tool-output")}


def installer_owner(repo, home):
    """Require the protected installer's inherited actual checkout lock, not an env flag."""
    import fcntl
    lock = Path(home) / ".local/state/ai-devops/task-gates" / (
        "install-" + hashlib.sha256(str(repo).encode()).hexdigest()[:16] + ".lock")
    require(os.readlink("/proc/self/fd/9") == str(lock), "activation is installer-only")
    info, named = os.fstat(9), lock.lstat()
    require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid() and info.st_nlink == 1
            and info.st_mode & 0o077 == 0 and info.st_size == 0
            and (info.st_dev, info.st_ino) == (named.st_dev, named.st_ino), "untrusted installer lock")
    fcntl.flock(9, fcntl.LOCK_EX | fcntl.LOCK_NB)
    arguments = [os.fsdecode(arg) for arg in Path(f"/proc/{os.getppid()}/cmdline").read_bytes().split(b"\0") if arg]
    require(len(arguments) >= 3 and Path(arguments[0]).name == "bash"
            and arguments[1] != "-c", "activation requires actual installer process")
    parent_cwd = Path(f"/proc/{os.getppid()}/cwd").resolve()
    script = Path(arguments[1]) if Path(arguments[1]).is_absolute() else parent_cwd / arguments[1]
    script = script.resolve()
    require(script.name in ("install.sh", "update.sh") and "--activate-glm-formal" in arguments[2:]
            and digest(script) == digest(Path(repo) / script.name),
            "activation requires explicit protected installed source")
    common = lambda path: subprocess.check_output(["git", "-C", str(path), "rev-parse", "--path-format=absolute", "--git-common-dir"], text=True).strip()
    require(common(script.parent) == common(repo), "installer is outside the managed repository")


def profile_health(home):
    import base64
    import urllib.request
    p = paths(home)
    before = origin(home)
    with os.fdopen(os.open(p["password"], os.O_RDONLY | os.O_NOFOLLOW), "rb") as stream:
        info = os.fstat(stream.fileno())
        require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid() and info.st_nlink == 1
                and info.st_mode & 0o077 == 0 and 0 < info.st_size <= 4096, "unsafe loopback credential file")
        password = stream.read(4097).strip()
        identity = lambda item: (item.st_dev, item.st_ino, item.st_mode, item.st_uid, item.st_nlink,
                                 item.st_size, item.st_mtime_ns, item.st_ctime_ns)
        require(len(password) <= 4096 and identity(os.fstat(stream.fileno())) == identity(info)
                and identity(p["password"].lstat()) == identity(info), "loopback credential changed")
    request = urllib.request.Request(f"http://127.0.0.1:{before['port']}/global/health",
              headers={"Authorization": "Basic " + base64.b64encode(b"opencode:" + password).decode()})
    # No inherited HTTP proxy may receive the loopback credential.
    with urllib.request.build_opener(urllib.request.ProxyHandler({})).open(request, timeout=3) as response:
        require(response.status == 200 and json.loads(response.read(4096)).get("healthy") is True,
                "formal profile is not healthy")
    require(before == origin(home), "origin changed during health qualification")
    return before


def activate(repo, home):
    repo = Path(repo).resolve(); p = paths(home)
    installer_owner(repo, home)
    installed = installed_state(repo)
    settings = private_read(p["settings"])
    require(settings["installed_checkout"] == str(repo), "profile belongs to another checkout")
    runtime = runtime_hashes(settings["repo"])
    require(os.access(Path(settings["repo"]) / "bin/ai-glm", os.X_OK), "pinned formal wrapper is not executable")
    require(runtime["critical"] == critical_inventory(repo), "profile code differs from installed release")
    ready = profile_health(home)
    record = {"version": 1, "profile": "formal-review", "installed": installed,
              "installed_checkout": str(repo), "runtime": settings["repo"],
              "runtime_source_sha": runtime["source_sha"], "settings_sha256": digest(p["settings"]),
              "origin": ready, "runner_sha256": digest(Path(settings["repo"]) / "bin/ai-glm")}
    if p["activation"].exists() or p["activation"].is_symlink():
        old = private_read(p["activation"])
        activation_identity(old, p, settings)
        installed_compatible(old, repo)
        require({key: value for key, value in old.items() if key not in ("installed", "origin")}
                == {key: value for key, value in record.items() if key not in ("installed", "origin")},
                "active profile code/config cannot be overwritten; explicit protected upgrade required")
        if old == record:
            return {"activated": True, "unchanged": True}
        # Explicit protected, exclusive, healthy re-attestation only. Original
        # per-review origin/deadline/protocol metadata is never changed.
    atomic(p["activation"], json.dumps(record, sort_keys=True).encode())
    return {"activated": True, "unchanged": False}


def activation_identity(record, p, settings):
    require(set(record) == {"version", "profile", "installed", "installed_checkout", "runtime",
                           "runtime_source_sha", "settings_sha256", "origin", "runner_sha256"}
            and type(record["version"]) is int and record["version"] == 1
            and record["profile"] == "formal-review", "invalid activation record")
    runtime = Path(record["runtime"])
    require(re.fullmatch(r"[0-9a-f]{40}", record["runtime_source_sha"])
            and runtime == p["runtimes"] / record["runtime_source_sha"]
            and settings["repo"] == str(runtime) and settings["release_sha"] == record["runtime_source_sha"]
            and record["installed_checkout"] == settings["installed_checkout"]
            and record["settings_sha256"] == digest(p["settings"]),
            "activation runtime/settings changed")
    pinned = runtime_hashes(runtime)
    require(pinned["critical"] == critical_inventory(record["installed_checkout"])
            and record["runner_sha256"] == digest(runtime / "bin/ai-glm")
            and os.access(runtime / "bin/ai-glm", os.X_OK), "activated code drift")
    return runtime


def installed_compatible(record, repo):
    current = installed_state(repo)
    require(isinstance(record.get("installed"), dict)
            and re.fullmatch(r"[0-9a-f]{40}", record["installed"].get("head", "")), "invalid activation release")
    if current["head"] == record["installed"]["head"]:
        require(current == record["installed"], "installed receipt changed without source movement")
    result = subprocess.run(["git", "-C", str(repo), "merge-base", "--is-ancestor",
                             record["installed"]["head"], current["head"]],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    require(result.returncode == 0, "installed source moved outside the admitted lineage")
    return current


def route(home):
    p = paths(home)
    if not p["activation"].exists() and not p["activation"].is_symlink():
        return {"profile": "general"}
    record = private_read(p["activation"])
    settings = private_read(p["settings"])
    runtime = activation_identity(record, p, settings)
    installed_compatible(record, record["installed_checkout"])
    require(record["origin"] == origin(home), "activation is stale or origin is not ready")
    return {"profile": "formal-review", "runner": str(runtime / "bin/ai-glm")}


def upgrade_check(repo, home, target):
    p = paths(home)
    if not p["activation"].exists() and not p["activation"].is_symlink():
        return {"profile": "general", "upgrade_allowed": True}
    require(re.fullmatch(r"[0-9a-f]{40}", target or ""), "immutable target required")
    route(home)  # Current active capability must already attest, never bypass drift.
    settings = private_read(p["settings"])
    require(str(Path(repo).resolve()) == settings["installed_checkout"], "wrong update checkout")
    pinned = runtime_hashes(settings["repo"])
    target_hashes = {}
    for name in CRITICAL_FILES:
        result = subprocess.run(["git", "-C", str(repo), "show", f"{target}:{name}"],
                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        require(result.returncode == 0, "target removes a formal safety dependency")
        target_hashes[name] = hashlib.sha256(result.stdout).hexdigest()
    require(target_hashes == pinned["critical"],
            "target changes active GLM safety dependencies; qualified exclusive profile upgrade required before source advance")
    return {"profile": "formal-review", "upgrade_allowed": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["install", "launch", "origin", "settings", "instructions", "activate", "route", "upgrade-check"])
    parser.add_argument("--repo")
    parser.add_argument("--port", type=int, default=4097)
    parser.add_argument("--snapshot")
    parser.add_argument("--packet")
    parser.add_argument("--target")
    args = parser.parse_args()
    home = Path.home()
    if args.operation == "install":
        require(bool(args.repo), "repository required")
        result = install(args.repo, home, args.port)
    elif args.operation == "launch":
        launch(home)
        return
    elif args.operation == "origin":
        result = origin(home)
    elif args.operation == "settings":
        result = private_read(paths(home)["settings"])
    elif args.operation == "route":
        result = route(home)
    elif args.operation == "activate":
        require(bool(args.repo), "installed repository required")
        result = activate(args.repo, home)
    elif args.operation == "upgrade-check":
        require(bool(args.repo), "installed repository required")
        result = upgrade_check(args.repo, home, args.target)
    else:
        require(bool(args.snapshot) and bool(args.packet), "instruction snapshot and packet required")
        result = instructions(args.snapshot, args.packet)
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, json.JSONDecodeError) as error:
        print("formal GLM profile refused: " + str(error), file=sys.stderr)
        sys.exit(1)
