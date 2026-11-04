#!/usr/bin/env bash
# Registers one edge-dev3 GitHub Actions runner for a repository and runs it as
# a systemd user service (owner request 2026-11-03: every repository's CI runs
# on edge-dev3 first). Idempotent: an already-configured folder is left alone.
# Usage: install-edge-dev3-runner.sh <owner/repo> [labels]
# Then add the repository to config/edge-dev3-runners.tsv.
set -euo pipefail
repo="$1"
labels="${2:-ai-devops-linux}"
name="$(printf '%s' "$repo" | tr / -)"
dir="$HOME/actions-runner-$name"
unit="actions-runner-$name.service"
template="${EDGE_DEV3_RUNNER_TEMPLATE:-$HOME/actions-runner-ai-devops}"
if [ ! -f "$dir/.runner" ]; then
  mkdir -p "$dir"
  # The runner bundle is copied from an existing healthy runner (same version).
  # -h turns the template's bin/externals links into real folders; older
  # versioned copies are left behind.
  tar -C "$template" -h --exclude=./_work --exclude=./_diag --exclude=./.runner --exclude=./.runner_migrated \
    --exclude=./.credentials --exclude=./.credentials_rsaparams --exclude=./.env --exclude=./.path \
    --exclude='./bin.*' --exclude='./externals.*' -cf - . | tar -C "$dir" -xf -
  token="$(gh api -X POST "repos/$repo/actions/runners/registration-token" --jq .token)"
  (cd "$dir" && ./config.sh --unattended --url "https://github.com/$repo" --token "$token" \
    --name edge-dev3-linux --labels "$labels" --work _work --replace >/dev/null)
fi
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/$unit" <<EOF
[Unit]
Description=GitHub Actions Runner ($repo edge-dev3-linux)
After=network-online.target
[Service]
WorkingDirectory=$dir
ExecStart=$dir/run.sh
Restart=always
RestartSec=10
KillMode=mixed
[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now "$unit" >/dev/null
printf '%s\t%s\t%s\n' "$repo" "$dir" "$unit"
