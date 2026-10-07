#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python="$(command -v python3 || command -v python)"
"$python" "$root/tools/github-requests/instrumented-gh/test_offline.py"
if [[ "$OSTYPE" == linux* ]]; then
  "$python" "$root/tools/github-requests/instrumented-gh/test_sealed.py"
else
  printf '%s\n' 'Linux sealed-execution qualification is unsupported on this platform; metadata-only results do not qualify execution.'
fi
printf '%s\n' 'Offline metadata contract passed; upstream Go, live transport, Windows and deployment qualification are separate.'
