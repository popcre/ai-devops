#!/usr/bin/env bash
# Named-test wrapper (plan §10). Holdout split, no leakage, small-cell suppression.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python "$ROOT/tests/test-jev-review-waste-pipeline.py"
