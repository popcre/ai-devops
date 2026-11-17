#!/usr/bin/env python3
"""Report edge-dev3 runner folder and service drift without changing state."""

import json
import subprocess
from collections import defaultdict
from pathlib import Path


def systemctl(scope, *args):
    return subprocess.check_output(
        ["systemctl", *scope, "--no-pager", "--no-legend", *args], text=True
    )


def services(scope):
    patterns = ("actions-runner-*.service", "actions.runner.*.service")
    installed = systemctl(scope, "list-unit-files", *patterns)
    loaded = systemctl(scope, "list-units", "--plain", "--all", *patterns)
    units = sorted({line.split()[0] for line in (installed + loaded).splitlines() if line.strip()})
    if units:
        properties = "Id,LoadState,ActiveState,SubState,WorkingDirectory,NRestarts"
        output = systemctl(scope, "show", "--all", f"--property={properties}", *units)
        if output.strip():
            for block in output.strip().split("\n\n"):
                yield dict(line.split("=", 1) for line in block.splitlines())


def findings(home, units):
    root = home / "actions-runners"
    folders = {
        path.resolve()
        for parent in (home, root)
        for path in parent.glob("actions-runner-*")
        if path.is_dir()
    }
    owners = defaultdict(list)
    registrations = defaultdict(list)
    for unit in units:
        name = unit["Id"]
        workdir = unit.get("WorkingDirectory")
        if not workdir:
            yield f"Service has no runner folder: {name}"
        else:
            folder = Path(workdir).resolve()
            owners[folder].append(name)
            if not (folder / ".runner").is_file():
                yield f"Service points to a missing or unconfigured runner: {name} ({folder})"
        if (unit.get("LoadState"), unit.get("ActiveState"), unit.get("SubState")) != (
            "loaded", "active", "running"
        ):
            yield f"Service is unhealthy: {name} ({unit.get('ActiveState')}/{unit.get('SubState')})"
        elif int(unit.get("NRestarts") or 0) >= 3:
            yield f"Service has restarted repeatedly: {name} ({unit['NRestarts']})"

    for folder in sorted(folders):
        if folder.parent != root:
            yield f"Runner folder is outside {root}: {folder}"
        if not owners[folder]:
            yield f"Runner folder has no service: {folder}"
        elif len(owners[folder]) > 1:
            yield f"Runner folder has multiple services: {folder} ({', '.join(owners[folder])})"
        try:
            config = json.loads((folder / ".runner").read_text(encoding="utf-8-sig"))
            key = (config["gitHubUrl"].rstrip("/").casefold(), int(config["agentId"]))
        except (OSError, ValueError, KeyError, TypeError, AttributeError):
            yield f"Runner registration is missing or unreadable: {folder}"
        else:
            registrations[key].append(folder)
    for paths in registrations.values():
        if len(paths) > 1:
            yield "Multiple folders share one runner registration: " + ", ".join(map(str, paths))


def main():
    units = [*services(("--user",)), *services(())]
    issues = sorted(findings(Path.home(), units))
    print("\n".join(issues) if issues else "Runner folder and service inventory is clean.", flush=True)
    return int(bool(issues))


if __name__ == "__main__":
    raise SystemExit(main())
