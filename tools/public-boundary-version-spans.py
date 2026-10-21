#!/usr/bin/env python3
"""Retain topology hits unless every match is a dependency-version span.

Owned by ai-public-boundary-check. This is deliberately not a file or line
allowlist: comments, URL authorities and adjacent addresses are still scanned.
Only familiar pinned requirements and parsed uv package metadata qualify. If
TOML parsing is unavailable or any context is uncertain, keep the original hit.
"""
from __future__ import annotations

import pathlib
import re
import sys
from urllib.parse import urlsplit

try:
    import tomllib
except ImportError:  # Python <3.11 retains the previous fail-closed lock scan.
    tomllib = None

TOPOLOGY = re.compile(
    r"100\.(?:6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.\d{1,3}\.\d{1,3}"
    r"|10\.\d{1,3}\.\d{1,3}\.\d{1,3}"
    r"|192\.168\.\d{1,3}\.\d{1,3}"
    r"|172\.(?:1[6-9]|2[0-9]|3[01])\.\d{1,3}\.\d{1,3}"
)
VERSION = r"[0-9]+(?:\.[0-9]+){3}"
PACKAGE = r"[A-Za-z0-9][A-Za-z0-9._-]*"
MARKER_NAME = (
    r"(?:python_version|python_full_version|os_name|sys_platform|platform_release|"
    r"platform_system|platform_version|platform_machine|platform_python_implementation|"
    r"implementation_name|implementation_version|extra)"
)
MARKER = (
    MARKER_NAME + r"[ \t]*(?:==|!=|<=|>=|<|>|not[ \t]+in|in)[ \t]*"
    r"(?:'[^'\n]*'|\"[^\"\n]*\")"
)
PIN = re.compile(
    r"^[ \t]*" + PACKAGE + r"(?:\[[A-Za-z0-9._,-]+\])?[ \t]*==[ \t]*"
    r"(?P<version>" + VERSION + r")"
    r"(?:[ \t]*;[ \t]*" + MARKER + r"(?:[ \t]+(?:and|or)[ \t]+" + MARKER + r")*)?"
    r"[ \t]*(?:#[^\n]*|\\)?[ \t]*$"
)
UV_VERSION = re.compile(r'^[ \t]*version[ \t]*=[ \t]*"(?P<version>' + VERSION + r')"[ \t]*(?:#.*)?$')
UV_URL = re.compile(r'\burl[ \t]*=[ \t]*"(?P<url>[^"\\\n]*)"')


def uv_spans(text):
    """Map line numbers to exact version spans in a valid uv.lock package."""
    if tomllib is None:
        return {}
    # The span mapper handles uv's ordinary one-line strings only. A table-like
    # line inside a multiline string must never acquire real package context.
    if '\"\"\"' in text or "'''" in text:
        return {}
    try:
        lock = tomllib.loads(text)
        if lock.get("version") != 1:
            return {}
        packages = lock.get("package", [])
    except (ValueError, TypeError):
        return {}
    if not isinstance(packages, list):
        return {}
    result = {}
    package_index = -1
    package = None
    in_wheels = False
    for number, line in enumerate(text.splitlines(), 1):
        if re.fullmatch(r"[ \t]*\[\[package\]\][ \t]*(?:#.*)?", line):
            package_index += 1
            package = packages[package_index] if package_index < len(packages) else None
            in_wheels = False
        elif line.lstrip().startswith("["):
            # A different table cannot inherit a package's version context.
            package = None
            in_wheels = False
        if not isinstance(package, dict):
            continue
        name, version = package.get("name"), package.get("version")
        if not isinstance(name, str) or not re.fullmatch(PACKAGE, name):
            continue
        if not isinstance(version, str) or not re.fullmatch(VERSION, version):
            continue
        if package.get("source") != {"registry": "https://pypi.org/simple"}:
            continue
        match = UV_VERSION.fullmatch(line)
        if match and match.group("version") == version:
            result.setdefault(number, []).append(match.span("version"))
        if re.fullmatch(r"[ \t]*wheels[ \t]*=[ \t]*\[[ \t]*(?:#.*)?", line):
            in_wheels = True
            continue
        if not in_wheels:
            continue
        if re.fullmatch(r"[ \t]*\][ \t]*(?:#.*)?", line):
            in_wheels = False
            continue
        wheels = package.get("wheels", [])
        if not isinstance(wheels, list) or package.get("source") != {"registry": "https://pypi.org/simple"}:
            continue
        if not re.match(r"^[ \t]*\{[ \t]*url[ \t]*=", line):
            continue
        for match in UV_URL.finditer(line.partition("#")[0]):
            url = match.group("url")
            if not any(isinstance(wheel, dict) and wheel.get("url") == url for wheel in wheels):
                continue
            parts = urlsplit(url)
            if parts.scheme != "https" or parts.netloc != "files.pythonhosted.org" or parts.query or parts.fragment:
                continue
            wheel_name = re.sub(r"[-_.]+", "_", name).lower()
            filename = parts.path.rsplit("/", 1)[-1]
            prefix = wheel_name + "-" + version + "-"
            if not filename.startswith(prefix) or not re.fullmatch(r"[^/]+-[^-]+-[^-]+-[^-]+\.whl", filename):
                continue
            start = match.start("url") + len(url) - len(filename) + len(wheel_name) + 1
            result.setdefault(number, []).append((start, start + len(version)))
    return result


def main():
    root = pathlib.Path(sys.argv[1]).resolve()
    cache = {}
    for raw in sys.stdin:
        hit = raw.rstrip("\n")
        path, separator, rest = hit.partition(":")
        number_text, separator2, content = rest.partition(":")
        if not separator or not separator2 or not number_text.isdigit():
            print(hit)
            continue
        spans = []
        try:
            file = root / path
            file.resolve().relative_to(root)
            if file.is_symlink():
                raise ValueError("symlink manifest")
            if file.name == "uv.lock":
                if path not in cache:
                    text = file.read_text(encoding="utf-8")
                    cache[path] = (text.splitlines(), uv_spans(text))
                lines, by_line = cache[path]
                number = int(number_text)
                if 0 < number <= len(lines) and lines[number - 1] == content:
                    spans = by_line.get(number, [])
            elif re.fullmatch(r"(?:[A-Za-z0-9_.-]*-)?requirements(?:[A-Za-z0-9_.-]*)\.txt", file.name):
                match = PIN.fullmatch(content)
                if match:
                    spans = [match.span("version")]
        except (OSError, ValueError, UnicodeError):
            pass
        matches = list(TOPOLOGY.finditer(content))
        if not matches or any(not any(left <= match.start() and match.end() <= right for left, right in spans) for match in matches):
            print(hit)


if __name__ == "__main__":
    main()
