#!/usr/bin/env bash
# Named-test wrapper (plan §10). Arc stitch using join keys; unscored without event.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$ROOT/tests/test-jev-review-waste-pipeline.py"
