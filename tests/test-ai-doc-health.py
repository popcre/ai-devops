#!/usr/bin/env python3
"""Black-box tests for bin/ai-doc-health."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "bin" / "ai-doc-health"
TODAY = "2026-11-11"
CONFIG = {
    "exclude": ["shared-db/**", "node_modules/**", ".claude/**", "docs/archive/**"],
    "router": "AGENTS.md",
    "router_max_bytes": 30000,
    "living_max_bytes": 60000,
    "handoff_dir": "HANDOFF.d",
    "handoff_max_age_days": 30,
    "index": "docs/INDEX.md",
    "header_exempt": ["AGENTS.md", "CLAUDE.md", "README.md", "HANDOFF.md", "HANDOFF.d/**"],
    "root_markdown_allow": ["AGENTS.md", "CLAUDE.md", "README.md", "HANDOFF.md", "plan_*.md"],
}


def header(summary: str = "What this holds.", kind: str = "living", status: str = "current", read_when: str = "Doing the task.") -> str:
    return f"---\nsummary: {summary}\nkind: {kind}\nstatus: {status}\nread-when: {read_when}\n---\n"


class Repo:
    def __init__(self, config: object = CONFIG) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "repo"
        self.path.mkdir()
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Test User")
        self.git("config", "user.email", "test@example.com")
        self.git("config", "core.quotepath", "true")
        self.write("AGENTS.md", "# Router\n\n[Index](docs/INDEX.md)\n")
        if config is not None:
            self.write(".doc-health.json", config if isinstance(config, str) else json.dumps(config))

    def cleanup(self) -> None:
        self.temp.cleanup()

    def git(self, *args: str) -> str:
        proc = subprocess.run(
            ["git", "-C", str(self.path), *args],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            encoding="utf-8",
            errors="replace",
        )
        if proc.returncode:
            raise AssertionError(proc.stderr or proc.stdout)
        return proc.stdout

    def write(self, relative: str, content: str | bytes) -> None:
        path = self.path / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(content, bytes):
            path.write_bytes(content)
        else:
            path.write_bytes(content.encode("utf-8"))  # exact bytes on every platform

    def commit(self, message: str = "change") -> None:
        self.git("add", "-A")
        self.git("commit", "-m", message)

    def run(self, *extra: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(CHECKER), "--repo", str(self.path), "--today", TODAY, *extra],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            encoding="utf-8",
            errors="replace",
        )

    def fix_and_commit(self) -> None:
        self.git("add", "-A")
        self.run("--fix-index")
        self.commit()


class DocHealthTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = Repo()
        self.addCleanup(self.repo.cleanup)

    def faults(self, *extra: str, repo: Repo | None = None) -> list[str]:
        result = (repo or self.repo).run(*extra)
        self.assertIn(result.returncode, (0, 1), result.stderr)
        self.assertEqual(result.returncode, 1 if result.stdout.strip() else 0, result.stdout)
        return result.stdout.splitlines()

    def test_clean_repo_exits_zero(self) -> None:
        self.repo.write("docs/guide.md", header() + "# Guide\n")
        self.repo.fix_and_commit()
        result = self.repo.run()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout, "")
        as_json = self.repo.run("--json")
        self.assertEqual(json.loads(as_json.stdout), [])

    def test_router_over_budget_reports_router_size(self) -> None:
        self.repo.write("AGENTS.md", "# Router\n" + "x" * 30001)
        self.repo.fix_and_commit()
        self.assertEqual(self.faults(), ["router-size AGENTS.md 30010 bytes, over the 30000 byte budget"])

    def test_living_doc_over_budget_reported_but_plan_kind_exempt(self) -> None:
        body = "word " * 80000  # 400 KB; the header is read from the first 2 KB only
        self.repo.write("docs/big-living.md", header() + body)
        self.repo.write("docs/big-ops.md", header(kind="ops") + body)
        self.repo.write("plan_big.md", header(kind="plan", status="open") + body)
        self.repo.write("docs/big-proof.md", header(kind="proof") + body)
        self.repo.write("docs/big-archive.md", header(kind="archive", status="done") + body)
        self.repo.fix_and_commit()
        lines = self.faults()
        self.assertEqual([line.split(" ")[:2] for line in lines], [["living-size", "docs/big-living.md"], ["living-size", "docs/big-ops.md"]])
        self.assertIn("over the 60000 byte budget", lines[0])

    def test_missing_header_and_invalid_kind_reported(self) -> None:
        self.repo.write("docs/none.md", "# No header\n")
        self.repo.write("docs/bad-kind.md", header(kind="tutorial") + "# x\n")
        self.repo.write("docs/bad-status.md", header(status="maybe") + "# x\n")
        self.repo.write("docs/no-key.md", "---\nsummary: s\nkind: living\nstatus: current\n---\n# x\n")
        self.repo.write("docs/long.md", header(summary="s" * 161) + "# x\n")
        self.repo.write("docs/malformed.md", "---\n: [unclosed\n\tkind living\n---\n# x\n")
        self.repo.write("docs/unclosed.md", "---\nsummary: s\nkind: living\n# body with no end marker\n")
        self.repo.write("docs/late-rule.md", "# Title\n\ntext\n\n---\nsummary: s\nkind: living\nstatus: current\nread-when: r\n---\n")
        self.repo.write("docs/ok-rule-later.md", header() + "# Fine\n\n---\n\nmore\n\n---\n")
        self.repo.fix_and_commit()
        lines = self.faults()
        got = {line.split(" ")[1]: line for line in lines}
        self.assertTrue(all(line.startswith("header-missing ") for line in lines), lines)
        self.assertEqual(
            sorted(got),
            ["docs/bad-kind.md", "docs/bad-status.md", "docs/late-rule.md", "docs/long.md", "docs/malformed.md", "docs/no-key.md", "docs/none.md", "docs/unclosed.md"],
        )
        self.assertIn("kind 'tutorial' is not one of", got["docs/bad-kind.md"])
        self.assertIn("status 'maybe' is not one of", got["docs/bad-status.md"])
        self.assertIn("key 'read-when' is missing", got["docs/no-key.md"])
        self.assertIn("longer than 160", got["docs/long.md"])
        self.assertEqual(got["docs/none.md"], "header-missing docs/none.md no header")

    def test_exempt_files_need_no_header(self) -> None:
        for name in ("CLAUDE.md", "README.md", "HANDOFF.md", "HANDOFF.d/2026-11-01T0000Z-x.md"):
            self.repo.write(name, f"# {name}\n")
        self.repo.fix_and_commit()
        self.assertEqual(self.faults(), [])

    def test_index_stale_detected_and_fix_index_is_byte_stable(self) -> None:
        self.repo.write("docs/a.md", header(summary='"Pipes | and\\nnewlines"', read_when="Reading | tables") + "# A\n")
        self.repo.write("plan_x.md", header(kind="plan", status="open", summary="A plan.") + "# Plan\n")
        self.repo.commit()
        self.assertEqual(self.faults(), ["index-stale docs/INDEX.md index file is missing; run ai-doc-health --fix-index"])
        self.repo.run("--fix-index")
        first = (self.repo.path / "docs/INDEX.md").read_bytes()
        self.repo.commit()
        self.repo.run("--fix-index")
        self.assertEqual((self.repo.path / "docs/INDEX.md").read_bytes(), first)
        self.assertEqual(self.repo.git("status", "--porcelain"), "")
        text = first.decode("utf-8")
        self.assertTrue(text.startswith("<!-- generated by ai-doc-health; edit the document headers, not this file -->\n"))
        self.assertIn("| [docs/a.md](a.md) | current | Pipes \\| and newlines | Reading \\| tables |", text)
        self.assertIn("| [plan_x.md](../plan_x.md) | open | A plan. | Doing the task. |", text)
        self.assertLess(text.index("## living"), text.index("## plan"))
        self.repo.write("docs/b.md", header() + "# B\n")
        self.repo.commit()
        self.assertEqual(self.faults(), ["index-stale docs/INDEX.md differs from the document headers; run ai-doc-health --fix-index"])

    def test_root_stray_respects_allow_list(self) -> None:
        self.repo.write("NOTES.md", header() + "# stray\n")
        self.repo.write("plan_ok.md", header(kind="plan", status="open") + "# plan\n")
        self.repo.fix_and_commit()
        self.assertEqual(
            self.faults(),
            ["root-stray NOTES.md Markdown file at the repository root that the allow list does not name"],
        )

    def test_handoff_age_from_filename_timestamp(self) -> None:
        self.repo.write("HANDOFF.d/2026-10-12T0000Z-fresh.md", "# 30 days\n")
        self.repo.write("HANDOFF.d/2026-10-11T0000Z-old.md", "# 31 days\n")
        self.repo.write("HANDOFF.d/untitled.md", "# no date\n")
        self.repo.write("HANDOFF.d/2026-99-99-bad.md", "# impossible date\n")
        self.repo.fix_and_commit()
        self.assertEqual(
            self.faults(),
            [
                "handoff-old HANDOFF.d/2026-10-11T0000Z-old.md 31 days old, over 30; successor review due",
                "handoff-old HANDOFF.d/2026-99-99-bad.md no date in name",
                "handoff-old HANDOFF.d/untitled.md no date in name",
            ],
        )

    def test_duplicate_in_repo_reported(self) -> None:
        self.repo.write("docs/one.md", header() + "# Same\n")
        self.repo.write("docs/two.md", header() + "# Same\n")
        self.repo.fix_and_commit()
        self.assertEqual(self.faults(), ["dup-in-repo docs/two.md identical to docs/one.md"])

    def test_duplicate_across_siblings_ignores_pointer_files(self) -> None:
        sibling = Repo()
        self.addCleanup(sibling.cleanup)
        shared = header() + "# Shared\n" + "text " * 200
        pointer = header(summary="Pointer: see the canonical copy.") + "[canonical](https://example.com)\n"
        for repo in (self.repo, sibling):
            repo.write("docs/shared.md", shared)
            repo.write("HANDOFF.md", "handoff-pointer: v1\n" + "static pointer text " * 60)
            repo.write("docs/pointer.md", pointer)
            repo.fix_and_commit()
        self.assertEqual(self.faults(), [])
        self.assertEqual(
            self.faults("--siblings", str(sibling.path), str(self.repo.path), str(sibling.path.parent / "missing")),
            ["dup-across docs/shared.md identical to repo/docs/shared.md"],
        )

    def test_excluded_paths_and_untracked_files_ignored(self) -> None:
        self.repo.write("shared-db/AGENTS.md", "# copy\n")
        self.repo.write("shared-db/docs/x.md", "# copy\n")
        self.repo.write("docs/archive/old.md", "# old\n")
        self.repo.write(".claude/skills/s/SKILL.md", "# skill\n")
        self.repo.write("docs/with space.md", header() + "# space\n")
        self.repo.write("docs/ünïcode.md", header() + "# unicode\n")
        self.repo.write("docs/-dash.md", header() + "# dash\n")
        self.repo.fix_and_commit()
        self.repo.write("docs/untracked.md", "# untracked\n")
        self.repo.write("STRAY-UNTRACKED.md", "# untracked\n")
        self.assertEqual(self.faults(), [])
        index = (self.repo.path / "docs/INDEX.md").read_text(encoding="utf-8")
        self.assertIn("[docs/with space.md](with%20space.md)", index)
        self.assertIn("docs/ünïcode.md", index)
        self.assertIn("[docs/-dash.md](-dash.md)", index)
        self.assertNotIn("untracked", index)
        self.assertNotIn("shared-db", index)

    def test_missing_config_exits_two(self) -> None:
        bare = Repo(config=None)
        self.addCleanup(bare.cleanup)
        bare.commit()
        result = bare.run()
        self.assertEqual(result.returncode, 2)
        self.assertIn("Committed config not found", result.stderr)
        for bad in ('{"exclude": "shared-db/**"}', '{"router_max_bytes": "big"}', '{"router": 5}', "[1, 2]", "{not json"):
            wrong = Repo(config=bad)
            self.addCleanup(wrong.cleanup)
            wrong.commit()
            result = wrong.run()
            self.assertEqual(result.returncode, 2, bad + result.stdout)
            self.assertIn("ERROR:", result.stderr)

    def test_reachability_delegated_only_when_config_present(self) -> None:
        self.repo.write("AGENTS.md", "# Router with no link to the index\n")
        self.repo.write("docs/orphan.md", header() + "# Orphan\n")
        self.repo.fix_and_commit()
        self.assertEqual(self.faults(), [])
        self.repo.write(
            ".doc-reachability.json",
            json.dumps({"roots": ["AGENTS.md"], "exclude": ["HANDOFF.d/**", "shared-db/**", "docs/archive/**"]}),
        )
        self.repo.commit()
        self.assertEqual(
            self.faults(),
            [
                "unreachable docs/INDEX.md no chain of links from a root document reaches this file",
                "unreachable docs/orphan.md no chain of links from a root document reaches this file",
            ],
        )
        self.repo.write("AGENTS.md", "# Router\n\n[Index](docs/INDEX.md)\n")
        self.repo.commit()
        self.assertEqual(self.faults(), [])

    def test_status_stale_needs_a_commit_in_window(self) -> None:
        self.repo.write("docs/old.md", header() + "# Old\n")
        self.repo.write("docs/done.md", header(status="done") + "# Done\n")
        self.repo.fix_and_commit()
        self.assertEqual(self.faults(), [])
        result = subprocess.run(
            [sys.executable, str(CHECKER), "--repo", str(self.repo.path), "--today", "2099-01-01"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(result.returncode, 1)
        self.assertEqual(
            result.stdout.splitlines(),
            ["status-stale docs/old.md status is current but no commit in 120 days; re-confirm"],
        )


if __name__ == "__main__":
    unittest.main()
