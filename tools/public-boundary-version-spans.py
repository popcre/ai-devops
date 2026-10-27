#!/usr/bin/env python3
"""Retain topology hits unless every match is a proven public semantic span.

Owned by ai-public-boundary-check. This is deliberately not a file or line
allowlist: comments, URL authorities and adjacent addresses are still scanned.
Only familiar dependency versions and direct complete-standard-network calls
qualify. If parsing is unavailable or context is uncertain, keep the hit.
"""
from __future__ import annotations

import ast
import ipaddress
import io
import tokenize
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
REQUIREMENTS_NAME = re.compile(r"(?:[A-Za-z0-9_.-]+-)?requirements(?:-[A-Za-z0-9_.-]+)?\.txt")
STANDARD_NETWORKS = frozenset((
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
))


def string_value(node):
    if isinstance(node, ast.Constant):
        return node.value if isinstance(node.value, str) else None
    if type(node).__name__ == "Str":  # Python 3.7 AST
        return node.s
    return None


def network_spans(text):
    """Recognize only direct stdlib calls with complete RFC1918 literals."""
    try:
        tree = ast.parse(text)
    except (SyntaxError, ValueError):
        return {}
    imported = any(isinstance(node, ast.Import) and any(alias.name == "ipaddress" and alias.asname in (None, "ipaddress") for alias in node.names) for node in tree.body)
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                if (alias.asname or alias.name.split(".")[0]) == "ipaddress":
                    if alias.name != "ipaddress":
                        return {}
        elif isinstance(node, ast.ImportFrom):
            if any((alias.asname or alias.name) in ("ipaddress", "*") for alias in node.names):
                return {}
        elif isinstance(node, ast.Name) and node.id == "ipaddress" and isinstance(node.ctx, (ast.Store, ast.Del)):
            return {}
        elif isinstance(node, ast.arg) and node.arg == "ipaddress":
            return {}
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef, ast.ExceptHandler)) and node.name == "ipaddress":
            return {}
        elif type(node).__name__ in ("MatchAs", "MatchStar") and getattr(node, "name", None) == "ipaddress":
            return {}
        elif type(node).__name__ == "MatchMapping" and getattr(node, "rest", None) == "ipaddress":
            return {}
        elif isinstance(node, (ast.Attribute, ast.Subscript)) and isinstance(node.ctx, (ast.Store, ast.Del)):
            if any(isinstance(part, ast.Name) and part.id == "ipaddress" for part in ast.walk(node)):
                return {}
            if isinstance(node, ast.Subscript) and string_value(node.slice.value if type(node.slice).__name__ == "Index" else node.slice) == "ipaddress":
                return {}
        elif isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in ("setattr", "delattr"):
            if node.args and isinstance(node.args[0], ast.Name) and node.args[0].id == "ipaddress":
                return {}
        elif isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in ("exec", "globals", "locals", "vars"):
            return {}
    if not imported:
        return {}
    lines = text.splitlines()
    result = {}
    for node in ast.walk(tree):
        if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                and isinstance(node.func.value, ast.Name) and node.func.value.id == "ipaddress"
                and node.func.attr == "ip_network" and len(node.args) == 1 and not node.keywords):
            continue
        literal = node.args[0]
        value = string_value(literal)
        if value is None:
            continue
        try:
            network = ipaddress.ip_network(value)
        except ValueError:
            continue
        if network not in STANDARD_NETWORKS or str(network) != value:
            continue
        line = lines[literal.lineno - 1]
        # AST columns are UTF-8 bytes; tokenize columns are Unicode characters.
        try:
            start = len(line.encode("utf-8")[:literal.col_offset].decode("utf-8"))
            tokens = list(tokenize.generate_tokens(io.StringIO(text).readline))
        except (UnicodeDecodeError, tokenize.TokenError, IndentationError):
            continue
        matching = [token for token in tokens if token.start == (literal.lineno, start)]
        if len(matching) != 1:
            continue
        token = matching[0]
        if (token.type != tokenize.STRING or token.end[0] != literal.lineno
                or token.string not in ('"' + value + '"', "'" + value + "'")):
            continue
        # On modern ASTs require the token to cover the entire literal as well.
        # Legacy ASTs lack ends; exact AST start + exact plain token stays bounded.
        end_line = getattr(literal, "end_lineno", None)
        if end_line is not None:
            end_byte = len(line[:token.end[1]].encode("utf-8"))
            if (end_line, literal.end_col_offset) != (token.end[0], end_byte):
                continue
        result.setdefault(literal.lineno, []).append((start + 1, token.end[1] - 1))
    return result


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
    # Hit lines are raw file bytes (UTF-8), and this script runs under -I where
    # PYTHONUTF8 cannot reach stdio; locale decoding would corrupt non-ASCII
    # lines and silently defeat the span comparison below.
    for stream in (sys.stdin, sys.stdout):
        try:
            stream.reconfigure(encoding="utf-8")
        except (AttributeError, ValueError, OSError):
            pass
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
            if file.name == "uv.lock" or file.suffix == ".py":
                if file.suffix == ".py":
                    # A sibling/root module could shadow the claimed stdlib.
                    if any((directory / "ipaddress.py").exists() or (directory / "ipaddress/__init__.py").exists()
                           for directory in (file.parent, root)):
                        raise ValueError("shadowed ipaddress module")
                if path not in cache:
                    text = file.read_text(encoding="utf-8")
                    spans_for_file = uv_spans(text) if file.name == "uv.lock" else network_spans(text)
                    cache[path] = (text.splitlines(), spans_for_file)
                lines, by_line = cache[path]
                number = int(number_text)
                if 0 < number <= len(lines) and lines[number - 1] == content:
                    spans = by_line.get(number, [])
            elif REQUIREMENTS_NAME.fullmatch(file.name):
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
