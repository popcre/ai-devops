#!/usr/bin/env bash
# Named-test wrapper (plan §10). Chunk boundaries + no chunk text under repo root.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python "$ROOT/tests/test-jev-review-waste-pipeline.py"
