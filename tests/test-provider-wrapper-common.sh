#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tools/lib/provider-wrapper-common.sh"

provider_wrapper_valid_name 'adapter-1.0_ok'
! provider_wrapper_valid_name 'adapter name'
! provider_wrapper_valid_name ''
fixture="$(mktemp)"
trap 'rm -f "$fixture"' EXIT
printf 'fixture adapter\n' > "$fixture"
test "$(provider_wrapper_sha256_file "$fixture")" = "$(sha256sum "$fixture" | awk '{print $1}')"
