#!/usr/bin/env python3
import csv
import sys
from pathlib import Path

REQUIRED = {
    "property_source_id",
    "property_label",
    "character_source_id",
    "character_label",
    "id_fallback",
    "captured_at",
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


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: validate_relationship_csv.py <csv>")

    path = Path(sys.argv[1])
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        missing = REQUIRED - set(reader.fieldnames or [])
        if missing:
            fail(f"missing columns: {', '.join(sorted(missing))}")

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

    if not rows:
        fail("CSV contains no relationship rows")
    print(f"PASS: {rows} unique property-character rows")
    if sentinels:
        print("Preserved placeholders: " + ", ".join(sorted(sentinels)))


if __name__ == "__main__":
    main()
