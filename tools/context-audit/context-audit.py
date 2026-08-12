#!/usr/bin/env python3
"""Read-only audit of ai-devops instruction and skill context."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path


EXCLUDED_PARTS = {
    ".ai", ".git", ".cache", "coverage", "dist", "node_modules",
    "transcripts", "claude_chats", "codex_chats", "worktrees",
}
SECRET_SUFFIXES = {".env", ".key", ".pem", ".pfx", ".p12"}
SKILL_RE = re.compile(r"^skills/(shared|claude|codex)/([^/]+)/SKILL\.md$")
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")

SAFETY_MARKERS = {
    "production mutation": [r"production", r"terraform apply|mutating.*gcloud|read-only"],
    "shared database routing": [r"shared[- ]db|shared database", r"shared-db|branch.*PR|authored"],
    "secret handling": [r"secret", r"1Password|never.*secret|vault"],
    "destructive actions": [r"destructive", r"delete|overwrite|recover"],
    "Git identity": [r"GIT_COMMITTER_IDENT|Git identity", r"Albert Hazan|users\.noreply\.github\.com"],
    "GPT-5.6 effort": [r"GPT-5\.6", r"low.*medium|medium.*low"],
}


def posix(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def is_excluded(relative: str) -> bool:
    parts = set(Path(relative).parts)
    if parts & EXCLUDED_PARTS:
        return True
    name = Path(relative).name.lower()
    return name.startswith(".env") or Path(name).suffix in SECRET_SUFFIXES


def tracked_files(root: Path) -> list[str]:
    try:
        result = subprocess.run(
            ["git", "-C", str(root), "ls-files", "-z"],
            check=True, capture_output=True,
        )
        names = [item.decode("utf-8", "surrogateescape") for item in result.stdout.split(b"\0") if item]
    except (FileNotFoundError, subprocess.CalledProcessError):
        names = [posix(path, root) for path in root.rglob("*") if path.is_file()]
    return sorted(name for name in names if not is_excluded(name))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def measurement(path: Path, root: Path, classification: str) -> dict:
    data = path.read_bytes()
    text = data.decode("utf-8", errors="replace")
    return {
        "path": posix(path, root),
        "classification": classification,
        "bytes": len(data),
        "lines": len(text.splitlines()),
        "estimatedTokens": (len(data) + 3) // 4,
        "sha256": hashlib.sha256(data).hexdigest(),
    }


def dedent_block(lines: list[str]) -> list[str]:
    indents = [len(line) - len(line.lstrip(" \t")) for line in lines if line.strip()]
    if not indents:
        return []
    base = min(indents)
    return [line[base:] if line.strip() else "" for line in lines]


def block_scalar(style: str, chomp: str, raw_lines: list[str]) -> str:
    """Render a YAML block scalar deterministically.

    Folded (``>``) joins the lines of a paragraph with single spaces and keeps
    one newline between paragraphs. Literal (``|``) preserves every line break.
    Strip chomping (``-``) removes the trailing newline; ``|``/``>`` and ``+``
    both end with exactly one newline so repeated runs stay byte-identical.
    """
    lines = dedent_block(raw_lines)
    while lines and not lines[-1].strip():
        lines.pop()
    if style == "|":
        body = "\n".join(lines)
    else:
        paragraphs: list[str] = []
        current: list[str] = []
        for line in lines:
            if line.strip():
                current.append(line.strip())
            else:
                paragraphs.append(" ".join(current))
                current = []
        paragraphs.append(" ".join(current))
        body = "\n".join(paragraphs)
    if chomp == "-" or not body:
        return body
    return body + "\n"


BLOCK_MARKER_RE = re.compile(r"^([>|])([+-]?)$")


def frontmatter(text: str) -> dict[str, str]:
    if not text.startswith("---\n"):
        return {}
    end = text.find("\n---", 4)
    if end < 0:
        return {}
    lines = text[4:end].splitlines()
    values: dict[str, str] = {}
    index = 0
    while index < len(lines):
        line = lines[index]
        index += 1
        if not line.strip() or line.startswith(("#", " ", "\t")) or ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()
        marker = BLOCK_MARKER_RE.match(value)
        if marker:
            block: list[str] = []
            while index < len(lines) and (not lines[index].strip() or lines[index][:1] in (" ", "\t")):
                block.append(lines[index])
                index += 1
            values[key] = block_scalar(marker.group(1), marker.group(2), block)
        else:
            values[key] = value.strip('"\'')
    return values


def paragraphs(text: str) -> list[str]:
    body = re.sub(r"^---\n.*?\n---\s*", "", text, flags=re.S)
    result = []
    for item in re.split(r"\n\s*\n", body):
        normalized = " ".join(item.split())
        if len(normalized) >= 180 and not normalized.startswith("```"):
            result.append(normalized)
    return result


def link_issues(root: Path, markdown_paths: list[Path]) -> list[dict]:
    issues = []
    for source in markdown_paths:
        if not source.is_file():
            continue
        text = re.sub(r"```.*?```", "", read_text(source), flags=re.S)
        for target in LINK_RE.findall(text):
            target = target.strip().strip("<>").split("#", 1)[0]
            if not target or re.match(r"^[a-z]+://", target, re.I) or target.startswith("mailto:"):
                continue
            target = target.replace("%20", " ")
            resolved = (source.parent / target).resolve()
            try:
                resolved.relative_to(root.resolve())
            except ValueError:
                continue
            if not resolved.exists():
                issues.append({"source": posix(source, root), "target": target})
    return issues


def installed_drift(root: Path, skill_records: list[dict], claude_home: Path | None, codex_home: Path | None) -> list[dict]:
    drift = []
    homes = {"claude": claude_home, "codex": codex_home}
    for record in skill_records:
        source_client = record["sourceClient"]
        clients = ("claude", "codex") if source_client == "shared" else (source_client,)
        source_hash = record["sha256"]
        for client in clients:
            home = homes[client]
            if home is None:
                continue
            installed = home / "skills" / record["name"] / "SKILL.md"
            if not installed.exists():
                drift.append({"kind": "skill", "client": client, "name": record["name"], "state": "missing"})
            else:
                digest = hashlib.sha256(installed.read_bytes()).hexdigest()
                if digest != source_hash:
                    drift.append({"kind": "skill", "client": client, "name": record["name"], "state": "different"})
    globals_to_check = (
        ("claude", claude_home, "CLAUDE.md", root / "templates" / "system" / "CLAUDE-global.md"),
        ("codex", codex_home, "AGENTS.md", root / "templates" / "system" / "AGENTS-global-codex.md"),
    )
    for client, home, filename, source in globals_to_check:
        if home is None or not source.exists():
            continue
        installed = home / filename
        if not installed.exists():
            drift.append({"kind": "global", "client": client, "name": filename, "state": "missing"})
        elif hashlib.sha256(installed.read_bytes()).hexdigest() != hashlib.sha256(source.read_bytes()).hexdigest():
            drift.append({"kind": "global", "client": client, "name": filename, "state": "different"})
    return drift


def installer_capabilities(root: Path) -> dict:
    paths = {
        "bash": root / "bin" / "ai-install-skills",
        "powershell": root / "bin" / "install-ai-devops-windows.ps1",
    }
    patterns = {
        "managedMarker": r"\.ai-devops-managed",
        "collisionGuard": r"Shared skill.*also exists|shared skill.*also exists",
        "orphanQuarantine": r"skills-quarantine",
        "globalNonClobber": r"NOT overwriting|not overwriting local edits",
        "dryRun": r"dry-run|SkillsDryRun",
    }
    result = {}
    for label, path in paths.items():
        text = read_text(path) if path.exists() else ""
        result[label] = {name: bool(re.search(pattern, text, re.I)) for name, pattern in patterns.items()}
    result["differences"] = [name for name in patterns if result["bash"][name] != result["powershell"][name]]
    return result


def run(args: argparse.Namespace) -> dict:
    root = args.root.resolve()
    if str(root).startswith(("\\\\", "//")):
        raise ValueError("Network roots are excluded from context audit.")
    names = tracked_files(root)
    files = []
    markdown_paths = []

    classifications = {
        "templates/system/CLAUDE-global.md": "always-loaded",
        "templates/system/AGENTS-global-codex.md": "always-loaded",
        "AGENTS.md": "startup-routed",
        "CLAUDE.md": "startup-routed",
    }
    for relative, classification in classifications.items():
        path = root / relative
        if relative in names and path.is_file():
            files.append(measurement(path, root, classification))
            markdown_paths.append(path)

    skill_records = []
    duplicate_names: dict[str, list[str]] = defaultdict(list)
    duplicate_paragraphs: dict[str, list[str]] = defaultdict(list)
    manifests = {"claude": [], "codex": []}
    for relative in names:
        match = SKILL_RE.match(relative)
        if not match:
            continue
        source_client, directory_name = match.groups()
        path = root / relative
        text = read_text(path)
        meta = frontmatter(text)
        name = meta.get("name", directory_name)
        description = meta.get("description", "")
        record = measurement(path, root, "task-triggered")
        record.update({"name": name, "description": description, "sourceClient": source_client})
        skill_records.append(record)
        duplicate_names[name].append(relative)
        for paragraph in paragraphs(text):
            duplicate_paragraphs[hashlib.sha256(paragraph.encode()).hexdigest()].append(relative)
        for client in ("claude", "codex") if source_client == "shared" else (source_client,):
            manifests[client].append({"name": name, "description": description, "source": relative})
        markdown_paths.append(path)

    manifest_report = {}
    for client, entries in manifests.items():
        entries.sort(key=lambda item: (item["name"], item["source"]))
        rendered = "\n".join(f"{item['name']}: {item['description']}" for item in entries)
        manifest_report[client] = {
            "skills": len(entries), "bytes": len(rendered.encode()),
            "estimatedTokens": (len(rendered.encode()) + 3) // 4,
        }

    safety_text = "\n".join(read_text(root / p) for p in classifications if (root / p).exists())
    safety = {}
    for category, patterns in SAFETY_MARKERS.items():
        safety[category] = all(re.search(pattern, safety_text, re.I | re.S) is not None for pattern in patterns)

    generated_at = args.generated_at or datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    report = {
        "schemaVersion": 1,
        "generatedAt": generated_at,
        "root": str(root),
        "files": sorted(files, key=lambda item: item["path"]),
        "skills": sorted(skill_records, key=lambda item: item["path"]),
        "skillManifest": manifest_report,
        "duplicateSkillNames": [
            {"name": name, "sources": sources}
            for name, sources in sorted(duplicate_names.items()) if len(sources) > 1
        ],
        "duplicateParagraphs": [
            {"sha256": digest, "sources": sorted(set(sources))}
            for digest, sources in sorted(duplicate_paragraphs.items()) if len(set(sources)) > 1
        ],
        "brokenLinks": link_issues(root, markdown_paths + [root / "plan_context-engineering-consolidation.md", root / "HANDOFF.md"]),
        "installedDrift": installed_drift(root, skill_records, args.claude_home, args.codex_home),
        "installerCapabilities": installer_capabilities(root),
        "safetyMarkers": safety,
        "excludedPathClasses": sorted(EXCLUDED_PARTS) + ["secret file suffixes", "network roots"],
    }
    return report


def summary(report: dict) -> str:
    class_totals: dict[str, dict[str, int]] = defaultdict(lambda: {"files": 0, "bytes": 0, "estimatedTokens": 0})
    for item in report["files"] + report["skills"]:
        totals = class_totals[item["classification"]]
        totals["files"] += 1
        totals["bytes"] += item["bytes"]
        totals["estimatedTokens"] += item["estimatedTokens"]
    lines = ["Context audit summary", f"Root: {report['root']}", ""]
    for name in ("always-loaded", "startup-routed", "task-triggered"):
        totals = class_totals[name]
        lines.append(f"{name}: {totals['files']} files, {totals['bytes']} bytes, about {totals['estimatedTokens']} tokens")
    for client in ("claude", "codex"):
        item = report["skillManifest"][client]
        lines.append(f"{client} skill manifest: {item['skills']} skills, {item['bytes']} bytes, about {item['estimatedTokens']} tokens")
    lines.extend([
        f"duplicate skill names: {len(report['duplicateSkillNames'])}",
        f"duplicate paragraphs: {len(report['duplicateParagraphs'])}",
        f"broken relative links: {len(report['brokenLinks'])}",
        f"installed source drift: {len(report['installedDrift'])}",
        f"installer parity differences: {len(report['installerCapabilities']['differences'])}",
        f"missing safety markers: {sum(1 for value in report['safetyMarkers'].values() if not value)}",
    ])
    return "\n".join(lines) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--json", type=Path)
    parser.add_argument("--summary", type=Path)
    parser.add_argument("--claude-home", type=Path)
    parser.add_argument("--codex-home", type=Path)
    parser.add_argument("--generated-at", help="fixed value for reproducible fixture tests")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = run(args)
    rendered_json = json.dumps(report, indent=2, sort_keys=True) + "\n"
    rendered_summary = summary(report)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(rendered_json, encoding="utf-8")
    if args.summary:
        args.summary.parent.mkdir(parents=True, exist_ok=True)
        args.summary.write_text(rendered_summary, encoding="utf-8")
    if not args.json and not args.summary:
        sys.stdout.write(rendered_summary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
