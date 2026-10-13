#!/usr/bin/env python3
"""Offline tests for chunker + arc stitcher (no network).

Covers tests/test-jev-review-waste-chunker.sh and
tests/test-jev-review-waste-value-arc.sh contracts on this host.
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHUNKER = ROOT / "tools" / "jev_review_waste_chunker.py"
ARC = ROOT / "tools" / "jev_review_waste_arc.py"

passed = 0
failed = 0


def ok(msg: str = "") -> None:
    global passed
    passed += 1
    if msg:
        print(f"  ok   {msg}")


def bad(msg: str) -> None:
    global failed
    failed += 1
    print(f"  FAIL {msg}")


def run_chunker(files, text_dir, items, window=200, overlap=50):
    return subprocess.run(
        [sys.executable, str(CHUNKER), "--items", str(items), "--text-dir", str(text_dir),
         "--window", str(window), "--overlap", str(overlap), *map(str, files)],
        capture_output=True, text=True, timeout=30,
    )


def test_chunker() -> None:
    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        # synthetic multi-turn fixture
        lines = []
        for i in range(12):
            body = json.dumps(
                {"type": "user", "message": f"turn {i} ", "pad": "x" * 80}
            )
            lines.append(body)
        # review markers in the middle
        lines.insert(5, json.dumps({"type": "assistant", "message": "ai-review verdict APPROVE on abc"}))
        src = td_path / "synth.jsonl"
        src.write_text("\n".join(lines) + "\n", encoding="utf-8")
        text_dir = td_path / "chunks"
        items = td_path / "items.jsonl"
        # first: refuse text dir under repo
        repo_text = ROOT / "tests" / "should-not-write"
        r = subprocess.run(
            [sys.executable, str(CHUNKER), "--items", str(items), "--text-dir", str(repo_text),
             "--window", "200", "--overlap", "50", str(src)],
            capture_output=True, text=True, timeout=30,
        )
        if r.returncode != 0 and not repo_text.exists():
            ok("chunker refuses text dir under repo root")
        else:
            bad("chunker allowed repo-root chunk text")

        r = run_chunker([src], text_dir, items, window=200, overlap=50)
        if r.returncode == 0:
            ok("chunker runs")
        else:
            bad(f"chunker failed: {r.stderr}")
        rows = [json.loads(x) for x in items.read_text(encoding="utf-8").splitlines() if x]
        if rows:
            ok(f"emitted {len(rows)} chunks")
        else:
            bad("no chunks emitted")
        # no chunk text under repo
        leaked = list(ROOT.rglob("*.txt"))
        leaked = [p for p in leaked if "chunks" in p.name or "synth" in p.name]
        if not any(str(items) in str(p) for p in ROOT.rglob("*")):
            ok("chunk text not under repo root")
        else:
            bad("chunk text leaked into repo")
        # digests present, text_path outside ROOT
        good = all("digest" in row and "id" in row for row in rows)
        outside = all(not str(row["text_path"]).startswith(str(ROOT)) for row in rows)
        if good and outside:
            ok("chunk ids + digests + external text_path")
        else:
            bad(f"chunk meta wrong good={good} outside={outside}")
        # boundaries: consecutive windows should have overlap region in char counts
        if len(rows) >= 2:
            a, b = rows[0], rows[1]
            # start of second should be < end of first when overlap > 0
            if b["byte_start"] < a["byte_end"]:
                ok("overlap between consecutive chunks")
            else:
                bad(f"no overlap: {a} {b}")
        # review signal flag
        if any(row.get("review_signal") for row in rows):
            ok("review_signal marked")
        else:
            bad("review_signal never set on marked fixture")


def _synth_lines(count: int, width: int) -> str:
    """JSONL text whose turn boundaries land on exact width multiples."""
    lines = []
    for i in range(count):
        body = json.dumps({"type": "user", "message": f"turn {i} "})
        if len(body) > width - 1:
            raise AssertionError("line wider than width")
        body = body + " " * (width - 1 - len(body))
        lines.append(body)
    return "\n".join(lines) + "\n"


def _assert_lossless(rows, text_len: int) -> None:
    if not rows:
        bad("lossless check: no chunks")
        return
    ordered = sorted(rows, key=lambda r: r["byte_start"])
    if ordered[0]["byte_start"] != 0:
        bad(f"lossless check: first chunk starts at {ordered[0]['byte_start']}, not 0")
        return
    for prev, cur in zip(ordered, ordered[1:]):
        if cur["byte_start"] > prev["byte_end"]:
            bad(
                "lossless check: gap between chunks "
                f"[{prev['byte_end']}, {cur['byte_start']}) "
                f"(prev={prev} cur={cur})"
            )
            return
        if cur["byte_end"] <= cur["byte_start"]:
            bad(f"lossless check: empty chunk {cur}")
            return
    if ordered[-1]["byte_end"] != text_len:
        bad(f"lossless check: last chunk ends at {ordered[-1]['byte_end']}, text is {text_len} long")
        return
    ok("chunk coverage is lossless (no dropped bytes between chunks)")


def test_chunker_lossless_coverage() -> None:
    """#1646 M2: overlap < 0.2*window (the defaults) must not drop bytes when
    the turn-boundary snap moves the chunk end behind the next start."""
    sys.path.insert(0, str(ROOT / "tools"))
    from jev_review_waste_chunker import chunk_text  # noqa: E402

    # Regime 1: small window. Boundaries at multiples of 81; the first at or
    # after 0.8*window=160 is 162, which sits below step=180 — the old advance
    # dropped [162, 180).
    text = _synth_lines(40, 81)
    chunks = chunk_text(text, 200, 20)
    if any(e <= s for s, e, _ in chunks):
        bad("chunker emitted an empty chunk (window=200 overlap=20)")
    else:
        ok("small-window chunks are non-empty")
    if len(chunks) < 2:
        bad("small-window fixture produced fewer than 2 chunks")
    else:
        ok("small-window fixture produced multiple chunks")
    _assert_lossless([{"byte_start": s, "byte_end": e} for s, e, _ in chunks], len(text))

    # Regime 2: the shipped defaults, 6000/1000 (overlap = 1/6 < 0.2*window).
    # Boundaries at multiples of 101; the first at or after 4800 is 4848,
    # below step=5000 — the old advance dropped [4848, 5000) at every snap.
    text2 = _synth_lines(130, 101)
    chunks2 = chunk_text(text2, 6000, 1000)
    if len(chunks2) < 2:
        bad("default-regime fixture produced fewer than 2 chunks")
    else:
        ok(f"default regime produced {len(chunks2)} chunks")
    _assert_lossless([{"byte_start": s, "byte_end": e} for s, e, _ in chunks2], len(text2))

    # And through the CLI with argparse defaults (same numbers, main()).
    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        src = td_path / "defaults.jsonl"
        # write_bytes: write_text would CRLF-translate on Windows and change
        # the byte offsets the lossless check compares against.
        src.write_bytes(text2.encode("utf-8"))
        items = td_path / "items.jsonl"
        r = subprocess.run(
            [sys.executable, str(CHUNKER), "--items", str(items),
             "--text-dir", str(td_path / "chunks"), "--window", "6000",
             "--overlap", "1000", str(src)],
            capture_output=True, text=True, timeout=30,
        )
        if r.returncode != 0:
            bad(f"chunker CLI failed at defaults: {r.stderr}")
        else:
            cli_rows = [json.loads(x) for x in items.read_text(encoding="utf-8").splitlines() if x]
            _assert_lossless(cli_rows, len(text2))


def test_arc() -> None:
    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        head = "a" * 40
        events = td_path / "events.jsonl"
        events.write_text(
            json.dumps({"event": "started", "head": head, "run_id": "r1",
                        "provider": "codex", "repo": "popcre/x", "operation": "invocation"})
            + "\n"
            + json.dumps({"event": "finished", "head": head, "run_id": "r1",
                          "provider": "codex", "repo": "popcre/x", "operation": "invocation"})
            + "\n",
            encoding="utf-8",
        )
        text_dir = td_path / "chunks"
        text_dir.mkdir()
        # three fragments that share the same head -> one interaction
        chunk_rows = []
        for i, snippet in enumerate([
            f"dispatch to reviewer for commit {head}",
            f"reviewer verdict on {head}: found a real problem",
            f"author reaction fix committed on {head}",
        ]):
            tp = text_dir / f"c{i}.txt"
            tp.write_text(snippet, encoding="utf-8")
            chunk_rows.append({"id": f"c{i}", "text_path": str(tp)})
        # one chunk with no event head
        tp = text_dir / "cX.txt"
        tp.write_text("unrelated chat with no event head", encoding="utf-8")
        chunk_rows.append({"id": "cX", "text_path": str(tp)})

        chunks = td_path / "chunks.jsonl"
        chunks.write_text("\n".join(json.dumps(r) for r in chunk_rows) + "\n", encoding="utf-8")
        out = td_path / "interactions.jsonl"
        r = subprocess.run(
            [sys.executable, str(ARC), "--events", str(events), "--chunks", str(chunks),
             "--out", str(out)],
            capture_output=True, text=True, timeout=30,
        )
        if r.returncode == 0:
            ok("arc stitcher runs")
        else:
            bad(f"arc stitcher failed: {r.stderr}")
        lines = [json.loads(x) for x in out.read_text(encoding="utf-8").splitlines() if x]
        if len(lines) == 1:
            ok("three fragments + one event -> exactly one interaction")
        else:
            bad(f"expected 1 interaction, got {len(lines)}")
        if lines and lines[0].get("head") == head:
            ok("interaction carries the event head")
        else:
            bad("interaction missing head")
        if lines and "cX" not in lines[0].get("chunk_ids", []):
            ok("chunk with no event stays unscored")
        else:
            bad("no-event chunk was scored")
        if lines and lines[0].get("bucket") in ("discretionary", "mandatory_safety_gate"):
            ok(f"bucket assigned: {lines[0].get('bucket')}")
        else:
            bad("bucket missing")


def test_value_fixture_labels() -> None:
    fix = ROOT / "tests" / "fixtures" / "jev" / "review-waste-value-labels.json"
    if not fix.is_file():
        bad("value labels fixture missing")
        return
    data = json.loads(fix.read_text(encoding="utf-8"))
    cases = data if isinstance(data, list) else data.get("cases", [])
    if len(cases) >= 30:
        ok(f"value fixture has {len(cases)} cases")
    else:
        bad(f"value fixture too small: {len(cases)}")
    levels = {c.get("label") for c in cases}
    need = {"negative", "none", "low", "medium", "highest"}
    if need <= levels:
        ok("all five levels covered")
    else:
        bad(f"missing levels: {need - levels}")
    safety = [c for c in cases if c.get("bucket") == "mandatory_safety_gate"]
    if safety:
        ok(f"{len(safety)} safety-gate cases")
    else:
        bad("no safety-gate cases")


def test_chunk_fixture_labels() -> None:
    fix = ROOT / "tests" / "fixtures" / "jev" / "review-waste-chunk-labels.json"
    if not fix.is_file():
        bad("chunk labels fixture missing")
        return
    data = json.loads(fix.read_text(encoding="utf-8"))
    cases = data if isinstance(data, list) else data.get("cases", [])
    if len(cases) >= 30:
        ok(f"chunk fixture has {len(cases)} cases")
    else:
        bad(f"chunk fixture too small: {len(cases)}")
    labels = {c.get("label") for c in cases}
    if {"review_interaction", "meta_discussion", "unrelated"} <= labels:
        ok("chunk labels cover interaction/meta/unrelated")
    else:
        bad(f"chunk labels incomplete: {labels}")


if __name__ == "__main__":
    test_chunker()
    test_chunker_lossless_coverage()
    test_arc()
    test_chunk_fixture_labels()
    test_value_fixture_labels()
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(0 if failed == 0 else 1)
