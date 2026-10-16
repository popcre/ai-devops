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
            "settings": base / "profile.json",
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


def install(repo, home, port):
    require(sys.platform.startswith("linux"), "formal profile is Linux-only; general profile unchanged")
    repo, home = Path(repo).resolve(), Path(home).resolve()
    p = paths(home)
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
    settings = {"version": 1, "repo": str(repo), "binary": str(binary), "pin": version,
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["install", "launch", "origin", "settings", "instructions"])
    parser.add_argument("--repo")
    parser.add_argument("--port", type=int, default=4097)
    parser.add_argument("--snapshot")
    parser.add_argument("--packet")
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
