#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python="$(command -v python3 || command -v python)"
"$python" "$root/tests/test-github-request-qualification.py"
"$python" "$root/tests/test-windows-event-dispatch.py"
