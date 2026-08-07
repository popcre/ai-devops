import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("validate_relationship_csv.py")


class ValidatorTests(unittest.TestCase):
    def run_csv(self, content: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "relationships.csv"
            path.write_text(content, encoding="utf-8")
            return subprocess.run(
                [sys.executable, str(SCRIPT), str(path)],
                capture_output=True,
                text=True,
                check=False,
            )

    def test_asset_character_passes(self) -> None:
        result = self.run_csv(
            "asset_source_id,file_name,character_source_id,character_label,captured_date,source_url\n"
            "asset-1,file.ext,char-1,Character,2026-08-07,https://example.test/search\n"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("unique asset-character rows", result.stdout)

    def test_asset_style_guide_allows_natural_key_fallback(self) -> None:
        result = self.run_csv(
            "asset_source_id,file_name,style_guide_source_id,style_guide_natural_key,captured_date,source_url\n"
            "asset-1,file.ext,,Guide,2026-08-07,https://example.test/search\n"
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_duplicate_asset_link_fails(self) -> None:
        header = "asset_source_id,file_name,character_source_id,character_label,captured_date,source_url\n"
        row = "asset-1,file.ext,char-1,Character,2026-08-07,https://example.test/search\n"
        result = self.run_csv(header + row + row)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate asset-character pair", result.stderr)

    def test_property_character_still_passes(self) -> None:
        result = self.run_csv(
            "property_source_id,property_label,character_source_id,character_label,id_fallback,captured_at,source_url\n"
            "prop-1,Property,char-1,Character,false,2026-08-07T00:00:00Z,https://example.test/product\n"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("unique property-character rows", result.stdout)


if __name__ == "__main__":
    unittest.main()
