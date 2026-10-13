#!/usr/bin/env python3
"""Chunk session transcripts for the review-waste Jev pipeline.

Keeps one review request + verdict + first author reaction together when they
are adjacent. Emits chunk ids + digests only into the repo tree; chunk text
stays in a private working directory outside the repo.

Usage:
  python tools/jev_review_waste_chunker.py --items OUT.jsonl --text-dir DIR \
      [--window 6000] [--overlap 1000] FILE [FILE ...]

Each OUT.jsonl row: {"id", "digest", "byte_start", "byte_end", "text_path"}
where text_path is under DIR (never under the repository).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

# Structural review markers (not prose keywords alone).
REVIEW_MARKERS = (
    "ai-review",
    "ai-review-pool",
    "ai-review-packet",
    "reviewer_events",
    "reviewer-events",
    "bin/ai-review",
)
EVENT_HEAD_RE = re.compile(r"\b[0-9a-f]{40}\b")
PR_RE = re.compile(r"github\.com/[^/\s]+/[^/\s]+/pull/\d+")

# Boundaries that suggest a new turn / reaction (JSONL type or role markers).
TURN_BOUNDARY_RE = re.compile(
    r'(?m)^\s*(\{"(?:type|role)"\s*:\s*"(?:user|assistant|event_msg|response_item|tool_result|token_usage_record)")'
)


def chunk_text(text: str, window: int, overlap: int) -> list[tuple[int, int, str]]:
    """Return (start, end, chunk) with overlap. Prefer turn boundaries near cuts."""
    if window <= 0:
        raise ValueError("window must be positive")
    if overlap < 0 or overlap >= window:
        raise ValueError("overlap must be in [0, window)")
    n = len(text)
    if n == 0:
        return []
    out: list[tuple[int, int, str]] = []
    start = 0
    while start < n:
        end = min(start + window, n)
        if end < n:
            # snap end to the last turn boundary in the last 20% of the window
            search_from = start + int(window * 0.8)
            m = None
            for m in TURN_BOUNDARY_RE.finditer(text, search_from, end):
                pass
            if m:
                end = m.start()
        if end <= start:
            end = min(start + window, n)
        out.append((start, end, text[start:end]))
        if end >= n:
            break
        # Lossless advance (#1646 M2): start the next chunk `overlap` before
        # this chunk's actual end, not at start + step. When overlap < 0.2*window
        # (the defaults), a turn-boundary snap can move `end` below start + step;
        # advancing by step would drop the bytes in between. max() guarantees
        # forward progress even when overlap is large relative to the snap.
        start = max(end - overlap, start + 1)
    return out


def has_review_signal(text: str) -> bool:
    return any(m in text for m in REVIEW_MARKERS) or bool(PR_RE.search(text))


def digest_of(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", "replace")).hexdigest()[:16]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--items", required=True, help="output JSONL of chunk metadata")
    ap.add_argument("--text-dir", required=True, help="private directory for chunk text")
    ap.add_argument("--window", type=int, default=6000)
    ap.add_argument("--overlap", type=int, default=1000)
    ap.add_argument("--min-review-signal", action="store_true",
                    help="only emit chunks that contain a structural review signal")
    ap.add_argument("files", nargs="+")
    args = ap.parse_args()

    text_dir = Path(args.text_dir).resolve()
    items_path = Path(args.items).resolve()
    # Never write chunk text under the repository root (parent of tools/).
    repo_root = Path(__file__).resolve().parents[1]
    if str(text_dir).startswith(str(repo_root)):
        print("refusing to write chunk text under the repo root", file=sys.stderr)
        return 2
    text_dir.mkdir(parents=True, exist_ok=True)
    items_path.parent.mkdir(parents=True, exist_ok=True)

    n_files = n_chunks = n_marked = 0
    with items_path.open("w", encoding="utf-8") as items:
        for fp in args.files:
            p = Path(fp)
            try:
                raw = p.read_bytes()
            except OSError as e:
                print(f"skip {p}: {e}", file=sys.stderr)
                continue
            n_files += 1
            text = raw.decode("utf-8", "replace")
            for i, (start, end, chunk) in enumerate(
                chunk_text(text, args.window, args.overlap)
            ):
                if args.min_review_signal and not has_review_signal(chunk):
                    continue
                cid = f"{digest_of(chunk)}-{start}"
                tp = text_dir / f"{cid}.txt"
                tp.write_text(chunk, encoding="utf-8")
                items.write(
                    json.dumps(
                        {
                            "id": cid,
                            "digest": digest_of(chunk),
                            "byte_start": start,
                            "byte_end": end,
                            "text_path": str(tp),
                            "source_name": p.name,
                            "review_signal": has_review_signal(chunk),
                        },
                        ensure_ascii=False,
                    )
                    + "\n"
                )
                n_chunks += 1
                if has_review_signal(chunk):
                    n_marked += 1
    print(
        json.dumps(
            {"files": n_files, "chunks": n_chunks, "review_marked_chunks": n_marked}
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
