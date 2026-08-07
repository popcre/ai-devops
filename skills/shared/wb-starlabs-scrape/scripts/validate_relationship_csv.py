#!/usr/bin/env python3
import csv
import sys
from pathlib import Path

PROPERTY_CHARACTER_REQUIRED = {
    "property_source_id",
    "property_label",
    "character_source_id",
    "character_label",
    "id_fallback",
    "captured_at",
    "source_url",
}
ASSET_CHARACTER_REQUIRED = {
    "asset_source_id",
    "file_name",
    "character_source_id",
    "character_label",
    "captured_date",
    "source_url",
}
ASSET_PROPERTY_REQUIRED = {
    "asset_source_id",
    "file_name",
    "franchise_property_source_id",
    "franchise_property_label",
    "captured_date",
    "source_url",
}
ASSET_STYLE_GUIDE_REQUIRED = {
    "asset_source_id",
    "file_name",
    "style_guide_source_id",
    "style_guide_natural_key",
    "captured_date",
    "source_url",
}
SENTINELS = {
    "NO REPORTABLE ELEMENTS",
    "NO CHARACTER LIKENESS",
    "LOGO",
}


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def require_value(row: dict[str, str], column: str, line: int) -> str:
    value = row[column]
    if not value:
        fail(f"blank {column} at line {line}")
    return value


def validate_asset_links(reader: csv.DictReader, kind: str) -> tuple[int, str]:
    seen = set()
    rows = 0
    for line, row in enumerate(reader, start=2):
        rows += 1
        asset_id = require_value(row, "asset_source_id", line)
        require_value(row, "file_name", line)
        require_value(row, "captured_date", line)
        require_value(row, "source_url", line)

        if kind == "asset-character":
            label = require_value(row, "character_label", line)
            related = row["character_source_id"] or label
        elif kind == "asset-franchise-property":
            label = require_value(row, "franchise_property_label", line)
            related = row["franchise_property_source_id"] or label
        else:
            label = require_value(row, "style_guide_natural_key", line)
            related = row["style_guide_source_id"] or label

        key = (asset_id, related)
        if key in seen:
            fail(f"duplicate {kind} pair at line {line}: {key}")
        seen.add(key)

    return rows, kind


def validate_property_character(reader: csv.DictReader) -> tuple[int, str]:
    seen = set()
    rows = 0
    sentinels = set()
    for line, row in enumerate(reader, start=2):
        rows += 1
        property_label = row["property_label"]
        character_label = row["character_label"]
        if not property_label or not character_label:
            fail(f"blank property or character label at line {line}")
        if row["id_fallback"].lower() not in {"true", "false"}:
            fail(f"id_fallback must be true or false at line {line}")
        if row["id_fallback"].lower() == "false" and (
            not row["property_source_id"] or not row["character_source_id"]
        ):
            fail(f"missing source ID without fallback at line {line}")
        key = (
            row["property_source_id"] or property_label,
            row["character_source_id"] or character_label,
        )
        if key in seen:
            fail(f"duplicate property-character pair at line {line}: {key}")
        seen.add(key)
        upper = character_label.upper()
        if upper in SENTINELS or "LOGO" in upper:
            sentinels.add(character_label)

    if sentinels:
        print("Preserved placeholders: " + ", ".join(sorted(sentinels)))
    return rows, "property-character"


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: validate_relationship_csv.py <csv>")

    path = Path(sys.argv[1])
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        fields = set(reader.fieldnames or [])
        schemas = [
            (PROPERTY_CHARACTER_REQUIRED, validate_property_character),
            (ASSET_CHARACTER_REQUIRED, lambda r: validate_asset_links(r, "asset-character")),
            (ASSET_PROPERTY_REQUIRED, lambda r: validate_asset_links(r, "asset-franchise-property")),
            (ASSET_STYLE_GUIDE_REQUIRED, lambda r: validate_asset_links(r, "asset-style-guide")),
        ]
        validator = next((check for required, check in schemas if required <= fields), None)
        if validator is None:
            fail("unrecognized relationship CSV columns")
        rows, kind = validator(reader)

    if not rows:
        fail("CSV contains no relationship rows")
    print(f"PASS: {rows} unique {kind} rows")


if __name__ == "__main__":
    main()
