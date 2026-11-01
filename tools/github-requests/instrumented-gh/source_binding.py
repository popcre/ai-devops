"""Finite package closure; reject additions as well as omissions and mutations."""
import hashlib
import pathlib
import json
import re

FILES = ("httpcounter.go", "httpcounter_test.go", "channel.go", "channel_linux.go",
         "channel_windows.go", "channel_unsupported.go", "channel_windows_test.go",
         "windows_cli_fixture_test.go", "native_fixture.ps1", "pins.json")


def version_profile(path, version=None, raw=None):
    """One finite source-pin registry, shared by all builds and observers."""
    registry = json.loads(pathlib.Path(path).read_bytes() if raw is None else raw)
    selected = version or registry["default_profile"]
    if not isinstance(selected, str) or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", selected):
        raise ValueError("invalid counter version profile")
    profile = registry["profiles"].get(selected)
    if (not isinstance(profile, dict) or set(profile) != {"upstream_commit", "source_url", "source_sha256", "profile_kind", "api_constructor_hooks", "detached_telemetry"}
            or profile["profile_kind"] not in ("runtime", "historical")
            or not isinstance(profile["upstream_commit"], str)
            or not re.fullmatch(r"[0-9a-f]{40}", profile["upstream_commit"])
            or profile["source_url"] != "https://codeload.github.com/cli/cli/tar.gz/" + profile["upstream_commit"]):
        raise ValueError("unknown or incomplete counter version profile")
    if (type(profile["api_constructor_hooks"]) is not int or profile["api_constructor_hooks"] not in (1, 2)
            or type(profile["detached_telemetry"]) is not bool
            or profile["api_constructor_hooks"] != (2 if profile["detached_telemetry"] else 1)):
        raise ValueError("unsupported counter source capabilities")
    for digest in (profile["source_sha256"], registry["toolchain_sha256"]):
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("invalid pinned archive digest")
    return {**{key: registry[key] for key in ("owner", "prototype_platform", "toolchain_version", "toolchain_url", "toolchain_sha256")},
            "upstream_version": selected, **profile}


def source_binding(directory):
    directory = pathlib.Path(directory)
    actual = {item.name for pattern in ("*.go", "*.ps1", "*.json") for item in directory.glob(pattern)}
    if actual != set(FILES):
        raise ValueError("counter source closure mismatch")
    return {"schema": 1, "files": {
        name: hashlib.sha256((directory / name).read_bytes()).hexdigest()
        for name in FILES}}


def validate_source_binding(binding, directory):
    if (type(binding) is not dict or set(binding) != {"schema", "files"}
            or type(binding["schema"]) is not int or binding["schema"] != 1
            or type(binding["files"]) is not dict or binding != source_binding(directory)):
        raise ValueError("counter source binding mismatch")
