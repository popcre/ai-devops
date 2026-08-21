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
    "system binaries": [r"system binaries|operating-system binaries", r"never replace|without overwriting"],
}

# Plain-English consequence printed when a safety category is missing. The audit
# never guesses which file lost it; it names the category and why it matters.
SAFETY_REASONS = {
    "production mutation": (
        "no always-loaded rule keeps production and shared cloud read-only, so a "
        "session could run terraform apply or a mutating gcloud command"
    ),
    "shared database routing": (
        "no always-loaded rule sends shared-database changes through shared-db "
        "with a branch and pull request, so an app repo could alter the schema"
    ),
    "secret handling": (
        "no always-loaded rule says secrets live in 1Password and never in files, "
        "commits, or prompts"
    ),
    "destructive actions": (
        "no always-loaded rule requires destructive actions to be recoverable, so "
        "a delete or overwrite could be unrecoverable"
    ),
    "Git identity": (
        "no always-loaded rule requires verifying GIT_COMMITTER_IDENT, so Git can "
        "silently invent a wrong commit identity"
    ),
    "GPT-5.6 effort": (
        "no always-loaded rule pins GPT-5.6 reasoning to low or medium, so a run "
        "could start at high or none"
    ),
    "system binaries": (
        "no always-loaded rule forbids replacing operating-system binaries, so a "
        "session could damage commands shared by the whole machine"
    ),
}

# Rules that must be present in BOTH client globals. Claude and Codex load
# different entry files, so identical behavior has to be asserted, not assumed.
PARITY_RULES = {
    "response style contract": r"^# Response Style",
    "GPT-5.6 low or medium only": r"GPT-5\.6",
    "production infrastructure safety": r"production infrastructure safety",
    "no terraform apply against prod": r"terraform apply",
    "verify Git committer identity": r"GIT_COMMITTER_IDENT",
    "secrets live in 1Password": r"1Password",
    "serialize 1Password access": r"serializ",
    "shared database change gate": r"shared[- ]db|shared database",
    "Synology long-read safety": r"Synology",
    "handoff quality standard": r"HANDOFF",
    "destructive actions recoverable": r"destructive action",
    "never replace system binaries": r"system binaries|operating-system binaries",
}

# Client-only text that is allowed to appear in exactly one global. If one of
# these ever appears in both, the allowlist entry is stale and is reported.
# A shared rule that merely *mentions* the other client (the GPT-5.6 rule names
# ~/.codex/config.toml in the Claude global) is not a divergence, so these
# patterns anchor on text that is genuinely one client's own.
PARITY_DIVERGENCE_ALLOWLIST = {
    "Claude global install line": ("claude", r"Install this as the \*\*user-level\*\*"),
    "Codex global install line": ("codex", r"Install as `~/\.codex/AGENTS\.md`"),
    "Codex edition framing": ("codex", r"Codex edition"),
}

# Final budgets, set at step 10 (2026-08-14) from the sizes that were live on
# all three rolled-out machines when every safety and routing probe passed.
# Keep in sync with tools/context-audit/budgets.json and the table in
# docs/context-engineering.md — a budget number lives in exactly three places.
DEFAULT_BUDGETS = {
    "alwaysLoadedBytes": {"budget": 13871, "target": 12500},
    "startupRoutedBytes": {"budget": 11987, "target": 11000},
    "claudeSkillManifestBytes": {"budget": 22777, "target": 20000},
    "codexSkillManifestBytes": {"budget": 14847, "target": 13000},
}

BUDGET_LABELS = {
    "alwaysLoadedBytes": "always-loaded global templates",
    "startupRoutedBytes": "startup-routed repo entry files",
    "claudeSkillManifestBytes": "Claude skill name and description manifest",
    "codexSkillManifestBytes": "Codex skill name and description manifest",
}

SHINGLE_WORDS = 10


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


# Deliberately no OPEN_HANDOFF_THRESHOLD. A count cap on HANDOFF.d/ was ruled out
# by the owner on 2026-08-13 (see open_handoffs below). Do not reintroduce one.


def open_handoffs(root: Path) -> list[dict]:
    """Every file in HANDOFF.d/ is an OPEN workstream, by design.

    ⛔ The COUNT is reported, never judged. A count threshold was tried and
    RULED OUT by the owner on 2026-08-13: it fails the next legitimate file for
    a mess somebody else left, and twenty concurrent workstreams legitimately
    means twenty files.

    What is worth flagging is a file nothing can ever retire — one with no
    contract block naming the issue that would prove it done. That is checkable
    offline, which this audit must be. Whether the named issue is actually
    CLOSED is checked where GitHub is reachable: the Handoff Contract Guard on
    every pull request, and the weekly stale report (u2giants/shared-db, #658).
    """
    folder = root / "HANDOFF.d"
    if not folder.is_dir():
        return []
    out = []
    for path in sorted(folder.glob("*.md")):
        head = path.read_text(encoding="utf-8", errors="replace")[:400]
        has_contract = head.startswith("---") and "issue:" in head and "owner:" in head
        out.append({"path": posix(path, root), "hasContract": has_contract})
    return out


def drift_state(source_bytes: bytes, installed_bytes: bytes) -> str:
    """Say WHY two copies differ, so nobody hunts a content change that is not there.

    Windows checkouts of this repo do not all agree on line endings: a few files
    carry CRLF in the blob, so `core.autocrlf` leaves them mixed in one checkout
    and converts them in another. The installer copies bytes, so whichever
    checkout it ran from decides what is on disk, and the same machine then reads
    as drifted or clean depending on which checkout you audit from. That is a
    real difference and it is worth reporting, but it is not a content change and
    must not be investigated as one.
    """
    if source_bytes.replace(b"\r\n", b"\n") == installed_bytes.replace(b"\r\n", b"\n"):
        return "line-endings-only"
    return "different"


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
                installed_bytes = installed.read_bytes()
                if hashlib.sha256(installed_bytes).hexdigest() != source_hash:
                    source_path = root / record["path"]
                    state = drift_state(source_path.read_bytes(), installed_bytes) if source_path.exists() else "different"
                    drift.append({"kind": "skill", "client": client, "name": record["name"], "state": state})
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
        else:
            installed_bytes = installed.read_bytes()
            source_bytes = source.read_bytes()
            if hashlib.sha256(installed_bytes).hexdigest() != hashlib.sha256(source_bytes).hexdigest():
                drift.append({"kind": "global", "client": client, "name": filename,
                              "state": drift_state(source_bytes, installed_bytes)})
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
        # Step 7 reconciliation. Both installers must classify before writing,
        # keep a recoverable copy of anything they replace, and require an
        # explicit flag before replacing a global.
        "previewClassification": r"local-edits",
        "recoverableBackup": r"skills-backup",
        "globalAdoptFlag": r"adopt-globals|AdoptGlobals",
    }
    result = {}
    for label, path in paths.items():
        text = read_text(path) if path.exists() else ""
        result[label] = {name: bool(re.search(pattern, text, re.I)) for name, pattern in patterns.items()}
    result["differences"] = [name for name in patterns if result["bash"][name] != result["powershell"][name]]
    return result


def load_budgets(path: Path | None) -> tuple[dict, str]:
    """Return the warning budgets and where they came from.

    Budgets only ever warn. They are a ratchet against silent growth: `budget`
    is the measured size at the last accepted baseline, and `target` is the
    smaller number a later reduction step is aiming for. Tighten `budget` only
    after a real measured reduction has landed.
    """
    if path is None:
        default = Path(__file__).resolve().parent / "budgets.json"
        path = default if default.is_file() else None
    if path is None or not path.is_file():
        return dict(DEFAULT_BUDGETS), "built-in defaults"
    data = json.loads(path.read_text(encoding="utf-8"))
    entries = data.get("budgets", data)
    merged = dict(DEFAULT_BUDGETS)
    for name, value in entries.items():
        if isinstance(value, dict):
            merged[name] = value
        else:
            merged[name] = {"budget": int(value), "target": int(value)}
    return merged, path.name


def budget_report(budgets: dict, measured: dict) -> dict:
    entries = []
    for name in sorted(set(budgets) | set(measured)):
        limits = budgets.get(name, {})
        actual = measured.get(name)
        if actual is None:
            continue
        limit = limits.get("budget")
        target = limits.get("target")
        if limit is None:
            status, reason = "unbudgeted", f"no warning budget is configured for {name}"
        elif actual > limit:
            status = "warning"
            reason = (
                f"{BUDGET_LABELS.get(name, name)} grew to {actual} bytes, over the "
                f"{limit}-byte warning budget by {actual - limit} bytes. This is a "
                f"warning, not a failure."
            )
        else:
            status = "ok"
            reason = f"{BUDGET_LABELS.get(name, name)} is {actual} bytes, within the {limit}-byte warning budget."
        entries.append({
            "name": name, "label": BUDGET_LABELS.get(name, name), "bytes": actual,
            "budgetBytes": limit, "targetBytes": target, "status": status, "reason": reason,
        })
    return {
        "entries": entries,
        "warnings": sum(1 for item in entries if item["status"] == "warning"),
        "note": "Budgets warn only. They never change the audit exit status.",
    }


def cross_client_parity(claude_text: str, codex_text: str) -> dict:
    rules = []
    for name, pattern in sorted(PARITY_RULES.items()):
        in_claude = re.search(pattern, claude_text, re.I | re.M) is not None
        in_codex = re.search(pattern, codex_text, re.I | re.M) is not None
        if in_claude and in_codex:
            status, reason = "match", f"'{name}' is present in both client globals."
        elif in_claude or in_codex:
            missing = "Codex" if in_claude else "Claude"
            status = "mismatch"
            reason = (
                f"'{name}' is present in one client global but missing from the "
                f"{missing} global. Both clients must carry this rule, or it must "
                f"be added to the divergence allowlist with a stated reason."
            )
        else:
            status = "missing-everywhere"
            reason = f"'{name}' is missing from both client globals."
        rules.append({"name": name, "inClaude": in_claude, "inCodex": in_codex,
                      "status": status, "reason": reason})

    divergences = []
    for name, (client, pattern) in sorted(PARITY_DIVERGENCE_ALLOWLIST.items()):
        in_claude = re.search(pattern, claude_text, re.I | re.M) is not None
        in_codex = re.search(pattern, codex_text, re.I | re.M) is not None
        both = in_claude and in_codex
        divergences.append({
            "name": name, "allowedClient": client, "inClaude": in_claude, "inCodex": in_codex,
            "status": "stale-allowlist-entry" if both else "allowed",
            "reason": (
                f"'{name}' is allowlisted as {client}-only but now appears in both "
                f"globals, so the allowlist entry is stale."
            ) if both else f"'{name}' is allowed to appear only in the {client} global.",
        })
    return {
        "rules": rules,
        "mismatches": [item["name"] for item in rules if item["status"] != "match"],
        "allowedDivergences": divergences,
        "staleAllowlistEntries": [d["name"] for d in divergences if d["status"] != "allowed"],
    }


def shingles(text: str) -> set[tuple[str, ...]]:
    words = re.findall(r"[a-z0-9']+", text.lower())
    if len(words) < SHINGLE_WORDS:
        return set()
    return {tuple(words[i:i + SHINGLE_WORDS]) for i in range(len(words) - SHINGLE_WORDS + 1)}


def global_skill_overlap(global_texts: dict[str, str], manifests: dict) -> list[dict]:
    """Report ritual summaries in an always-loaded global that repeat a skill description.

    Both are startup context, so the same sentence in both is paid for twice.
    """
    overlaps = []
    for global_path in sorted(global_texts):
        global_shingles = shingles(global_texts[global_path])
        if not global_shingles:
            continue
        seen: set[str] = set()
        for client in ("claude", "codex"):
            for entry in manifests[client]:
                key = f"{client}:{entry['source']}"
                if key in seen:
                    continue
                seen.add(key)
                shared = sorted(global_shingles & shingles(entry["description"]))
                if shared:
                    overlaps.append({
                        "global": global_path, "client": client, "skill": entry["name"],
                        "source": entry["source"], "sharedPhrases": len(shared),
                        "examplePhrase": " ".join(shared[0]),
                        "reason": (
                            f"the always-loaded global '{global_path}' repeats text from the "
                            f"'{entry['name']}' skill description, which is already startup "
                            f"context for {client}."
                        ),
                    })
    return sorted(overlaps, key=lambda item: (item["global"], item["client"], item["skill"]))


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
    safety_issues = []
    for category, patterns in SAFETY_MARKERS.items():
        present = all(re.search(pattern, safety_text, re.I | re.S) is not None for pattern in patterns)
        safety[category] = present
        if not present:
            safety_issues.append({
                "category": category,
                "reason": f"Missing safety marker '{category}': {SAFETY_REASONS[category]}.",
            })

    class_bytes: dict[str, int] = defaultdict(int)
    for item in files + skill_records:
        class_bytes[item["classification"]] += item["bytes"]
    budgets, budget_source = load_budgets(args.budgets)
    measured = {
        "alwaysLoadedBytes": class_bytes["always-loaded"],
        "startupRoutedBytes": class_bytes["startup-routed"],
        "claudeSkillManifestBytes": manifest_report["claude"]["bytes"],
        "codexSkillManifestBytes": manifest_report["codex"]["bytes"],
    }
    budget_section = budget_report(budgets, measured)
    budget_section["source"] = budget_source

    global_texts = {
        relative: read_text(root / relative)
        for relative, classification in classifications.items()
        if classification == "always-loaded" and (root / relative).is_file()
    }
    parity = cross_client_parity(
        global_texts.get("templates/system/CLAUDE-global.md", ""),
        global_texts.get("templates/system/AGENTS-global-codex.md", ""),
    )

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
        "openHandoffs": open_handoffs(root),
        "installedDrift": installed_drift(root, skill_records, args.claude_home, args.codex_home),
        "installerCapabilities": installer_capabilities(root),
        "safetyMarkers": safety,
        "safetyMarkerIssues": safety_issues,
        "budgets": budget_section,
        "crossClientParity": parity,
        "globalSkillOverlap": global_skill_overlap(global_texts, manifests),
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
        f"installed source drift: {len(report['installedDrift'])}"
        + (
            f" ({sum(1 for d in report['installedDrift'] if d['state'] == 'line-endings-only')} line endings only)"
            if any(d["state"] == "line-endings-only" for d in report["installedDrift"])
            else ""
        ),
        f"installer parity differences: {len(report['installerCapabilities']['differences'])}",
        f"missing safety markers: {len(report['safetyMarkerIssues'])}",
        f"cross-client parity mismatches: {len(report['crossClientParity']['mismatches'])}",
        f"global vs skill-description overlaps: {len(report['globalSkillOverlap'])}",
        f"budget warnings: {report['budgets']['warnings']} (warnings only, never a failure)",
        f"open handoffs: {len(report['openHandoffs'])} (a count, never a finding — see #658)",
    ])
    uncontracted = [h for h in report["openHandoffs"] if not h.get("hasContract", False)]
    if uncontracted:
        lines.append(
            f"HANDOFF WARNING: {len(uncontracted)} file(s) in HANDOFF.d/ carry no contract block, so "
            "nothing can ever tell whether their work is finished — the failure that left 27 finished "
            "files in u2giants/shared-db (#658). Add `issue:`, `status:` and `owner:` frontmatter, or "
            "retire the file. This is a warning, not a failure. "
            f"Files: {', '.join(h['path'] for h in uncontracted)}"
        )
    for issue in report["safetyMarkerIssues"]:
        lines.append(f"SAFETY: {issue['reason']}")
    for item in report["crossClientParity"]["rules"]:
        if item["status"] != "match":
            lines.append(f"PARITY: {item['reason']}")
    for item in report["crossClientParity"]["allowedDivergences"]:
        if item["status"] != "allowed":
            lines.append(f"PARITY: {item['reason']}")
    for item in report["budgets"]["entries"]:
        if item["status"] == "warning":
            lines.append(f"BUDGET WARNING: {item['reason']}")
    for item in report["globalSkillOverlap"]:
        lines.append(
            f"OVERLAP: {item['reason']} Shared phrases: {item['sharedPhrases']}; "
            f"example: \"{item['examplePhrase']}\"."
        )
    return "\n".join(lines) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--json", type=Path)
    parser.add_argument("--summary", type=Path)
    parser.add_argument("--claude-home", type=Path)
    parser.add_argument("--codex-home", type=Path)
    parser.add_argument("--generated-at", help="fixed value for reproducible fixture tests")
    parser.add_argument("--budgets", type=Path,
                        help="JSON file of warning budgets (default: tools/context-audit/budgets.json)")
    parser.add_argument("--strict", action="store_true",
                        help="exit 1 when a required safety marker is missing or client parity "
                             "breaks. Budget overruns still only warn.")
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
    if args.strict:
        blocking = list(report["safetyMarkerIssues"])
        blocking += [
            {"reason": item["reason"]}
            for item in report["crossClientParity"]["rules"] if item["status"] != "match"
        ]
        blocking += [
            {"reason": item["reason"]}
            for item in report["crossClientParity"]["allowedDivergences"]
            if item["status"] != "allowed"
        ]
        if blocking:
            for item in blocking:
                sys.stderr.write(f"FAIL: {item['reason']}\n")
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
