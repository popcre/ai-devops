#!/usr/bin/env bash
set -euo pipefail
# The profile imports fcntl (POSIX-only); the oracle native alternate runs on Linux only.
[ "$(uname -s)" = Linux ] || { echo "SKIP: oracle native alternate profile is Linux-only (fcntl)"; exit 0; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHONDONTWRITEBYTECODE=1 python3 "$root/tests/test-oracle-native-alternate-v2-action.py"
