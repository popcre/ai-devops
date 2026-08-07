#!/usr/bin/env python3
"""Black-box tests for bin/ai-doc-reachability."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "bin" / "ai-doc-reachability"


class Repo:
    def __init__(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name)
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Test User")
        self.git("config", "user.email", "test@example.com")
        self.write("README.md", "# Test repository\n")
        self.write(
            ".doc-reachability.json",
            json.dumps(
                {
                    "roots": ["README.md", "AGENTS.md", "CLAUDE.md", "HANDOFF.md"],
                    "preferred_root": "README.md",
                    "exclude": ["HANDOFF.d/**", "archive/**", ".github/**"],
                }
            ),
        )
        self.commit("base")
        self.base = self.git("rev-parse", "HEAD").strip()

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

    def write(self, relative: str, content: str) -> None:
        path = self.path / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def commit(self, message: str = "change") -> None:
        self.git("add", "-A")
        self.git("commit", "-m", message)

    def check(self, include_base: bool = True) -> subprocess.CompletedProcess[str]:
        command = ["python", str(CHECKER), "--repo", str(self.path)]
        if include_base:
            command.extend(["--base", self.base])
        return subprocess.run(
            command,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            encoding="utf-8",
            errors="replace",
        )


class ReachabilityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = Repo()

    def tearDown(self) -> None:
        self.repo.cleanup()

    def assert_passes(self) -> str:
        result = self.repo.check()
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def assert_fails(self) -> str:
        result = self.repo.check()
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        return result.stderr

    def add_doc(self, path: str = "docs/finding.md", content: str = "# Finding\n") -> None:
        self.repo.write(path, content)

    def test_added_existing_file_without_link_fails(self) -> None:
        self.add_doc()
        self.repo.commit()
        error = self.assert_fails()
        self.assertIn("docs/finding.md", error)
        self.assertIn("Expected route from root: README.md", error)
        self.assertIn("Do not create a catch-all file list", error)

    def test_link_inside_backtick_fence_does_not_count(self) -> None:
        self.add_doc()
        self.repo.write("README.md", "# Root\n```markdown\n[Finding](docs/finding.md)\n```\n")
        self.repo.commit()
        self.assert_fails()

    def test_link_inside_tilde_fence_does_not_count(self) -> None:
        self.add_doc()
        self.repo.write("README.md", "# Root\n~~~\n[Finding](docs/finding.md)\n~~~\n")
        self.repo.commit()
        self.assert_fails()

    def test_link_inside_inline_code_does_not_count(self) -> None:
        self.add_doc()
        self.repo.write("README.md", "Use `[Finding](docs/finding.md)` as an example.\n")
        self.repo.commit()
        self.assert_fails()

    def test_bare_url_and_anchor_do_not_count(self) -> None:
        self.add_doc()
        self.repo.write(
            "README.md",
            "https://example.test/docs/finding.md\n[Local section](#finding)\n",
        )
        self.repo.commit()
        self.assert_fails()

    def test_directory_link_resolves_readme(self) -> None:
        self.add_doc("guides/README.md")
        self.repo.write("README.md", "[Use the setup guides](guides/)\n")
        self.repo.commit()
        self.assert_passes()

    def test_directory_link_without_slash_resolves_readme(self) -> None:
        self.add_doc("guides/README.md")
        self.repo.write("README.md", "[Use the setup guides](guides)\n")
        self.repo.commit()
        self.assert_passes()

    def test_explicit_directory_readme_link_passes(self) -> None:
        self.add_doc("guides/README.md")
        self.repo.write("README.md", "[Use the setup guides](guides/README.md)\n")
        self.repo.commit()
        self.assert_passes()

    def test_extensionless_link_resolves_markdown(self) -> None:
        self.add_doc("docs/finding.md")
        self.repo.write("README.md", "[Review the measured finding](docs/finding)\n")
        self.repo.commit()
        self.assert_passes()

    def test_query_and_anchor_are_removed_from_file_target(self) -> None:
        self.add_doc("docs/finding.md")
        self.repo.write("README.md", "[Review the measured finding](docs/finding.md?x=1#proof)\n")
        self.repo.commit()
        self.assert_passes()

    def test_reference_style_link_passes(self) -> None:
        self.add_doc()
        self.repo.write(
            "README.md",
            "[Review the measured finding][finding]\n\n[finding]: docs/finding.md\n",
        )
        self.repo.commit()
        self.assert_passes()

    def test_reachable_topic_index_can_route_to_new_doc(self) -> None:
        self.repo.write("docs/README.md", "# Documentation\n")
        self.repo.write("README.md", "[Use the topic documentation](docs/)\n")
        self.repo.commit("add living index")
        self.repo.base = self.repo.git("rev-parse", "HEAD").strip()
        self.add_doc()
        self.repo.write("docs/README.md", "# Documentation\n[Review measured findings](finding.md)\n")
        self.repo.commit()
        self.assert_passes()

    def test_island_graph_fails_and_names_island(self) -> None:
        self.add_doc("notes/a.md", "[Continue to B](b.md)\n")
        self.add_doc("notes/b.md", "[Return to A](a.md)\n")
        self.repo.commit()
        error = self.assert_fails()
        self.assertIn("island does not count", error)
        self.assertIn("notes/b.md", error)

    def test_existing_legacy_orphan_is_not_checked_when_only_modified(self) -> None:
        self.add_doc("legacy.md")
        self.repo.commit("legacy orphan")
        self.repo.base = self.repo.git("rev-parse", "HEAD").strip()
        self.repo.write("legacy.md", "# Legacy\nProse correction.\n")
        self.repo.commit()
        output = self.assert_passes()
        self.assertIn("0 added, copied, or moved", output)

    def test_rename_is_detected_and_passes_after_route_update(self) -> None:
        self.repo.write("old.md", "# Guide\n")
        self.repo.write("README.md", "[Use the guide](old.md)\n")
        self.repo.commit("old guide")
        self.repo.base = self.repo.git("rev-parse", "HEAD").strip()
        (self.repo.path / "docs").mkdir()
        os.rename(self.repo.path / "old.md", self.repo.path / "docs/new.md")
        self.repo.write("README.md", "[Use the guide](docs/new.md)\n")
        self.repo.commit()
        self.assert_passes()

    def test_renamed_orphan_fails_and_reports_old_path(self) -> None:
        self.repo.write("old.md", "# Guide\n")
        self.repo.commit("old orphan")
        self.repo.base = self.repo.git("rev-parse", "HEAD").strip()
        os.rename(self.repo.path / "old.md", self.repo.path / "new.md")
        self.repo.commit()
        error = self.assert_fails()
        self.assertIn("new.md (moved from old.md)", error)

    def test_excluded_added_file_is_ignored(self) -> None:
        self.add_doc("HANDOFF.d/session.md")
        self.repo.commit()
        self.assert_passes()

    def test_missing_config_fails_closed(self) -> None:
        (self.repo.path / ".doc-reachability.json").unlink()
        self.repo.commit()
        result = self.repo.check()
        self.assertEqual(result.returncode, 2)
        self.assertIn("Committed config not found", result.stderr)

    def test_missing_base_fails_closed_instead_of_guessing(self) -> None:
        self.add_doc()
        self.repo.commit()
        result = self.repo.check(include_base=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn("Refusing to guess", result.stderr)

    def test_no_configured_root_fails_closed(self) -> None:
        (self.repo.path / "README.md").unlink()
        self.add_doc()
        self.repo.commit()
        result = self.repo.check()
        self.assertEqual(result.returncode, 2)
        self.assertIn("None of the configured root documents exists", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
