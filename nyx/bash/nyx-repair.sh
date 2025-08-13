#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail
source "$(dirname "$0")/nyx-common.sh"

usage() {
  cat <<EOF
nyx-repair
  Stages all changes in \$nix_dir and (if auto_commit) commits:
    "rebuild - repair <timestamp>"
  Also removes unfinished logs in \$log_dir/rebuild (rebuild-*.log and
  Current-Error*.txt that are not final nixos-gen_* logs).
EOF
}

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then usage; exit 0; fi

cd "$nix_dir" || { echo "ERROR: Cannot cd into nix_dir: $nix_dir" >&2; exit 1; }

ts="$(date '+%Y-%m-%d_%H-%M-%S')"
echo "Starting repair at ${ts}..."

log_dir_rebuild="${log_dir}/rebuild"
if [[ -d "$log_dir_rebuild" ]]; then
  echo "Checking for unfinished logs in: $log_dir_rebuild"
  if find "$log_dir_rebuild" -type f \
      ! -name 'nixos-gen_*' \
      \( -name 'rebuild-*.log' -o -name 'Current-Error*.txt' \) | grep -q .; then
    echo "Removing unfinished logs..."
    find "$log_dir_rebuild" -type f \
      ! -name 'nixos-gen_*' \
      \( -name 'rebuild-*.log' -o -name 'Current-Error*.txt' \) \
      -exec rm -v {} +
    echo "Unfinished logs removed."
  else
    echo "No unfinished logs found."
  fi
else
  echo "No rebuild log directory found."
fi

echo "Staging all changes in $nix_dir..."
g add -A
if [[ "${auto_commit}" == "true" ]]; then
  if ! g diff --cached --quiet --; then
    echo "Committing repair changes..."
    g commit -m "rebuild - repair ${ts}"
    echo "Repair commit created."
  else
    echo "No changes to commit."
  fi
fi
