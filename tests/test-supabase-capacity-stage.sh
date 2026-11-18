#!/usr/bin/env bash
# Exercise the disabled capacity profile on both Linux and Windows.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python_bin="$(command -v python3 || command -v python)"
cd "$root"
"$python_bin" -B -m unittest discover -s tests -p test_supabase_capacity_stage_profile.py
