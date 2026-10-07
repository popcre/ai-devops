#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python="$(command -v python3 || command -v python)"
"$python" "$root/tools/github-requests/instrumented-gh/test_offline.py"
printf '%s\n' 'Offline metadata contract passed; upstream Go, live transport, Windows and deployment qualification are separate.'
