#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail
source "$(dirname "$0")/nyx-common.sh"

usage() {
  cat <<EOF
nyx-update
  Runs 'nix flake update --verbose' inside \$nix_dir and, if anything changed,
  stages flake.lock and (if auto_commit) commits it. Pushes if auto_push=true.
EOF
}

if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then usage; exit 0; fi

cd "$nix_dir" || { echo "Cannot cd into nix_dir: $nix_dir" >&2; exit 1; }

timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
log_dir_rebuild="${log_dir}/rebuild"
mkdir -p "$log_dir_rebuild"
build_log="${log_dir_rebuild}/update-${timestamp}.log"

console_log "$build_log" "${BOLD}${BLUE}Updating flake...${RESET}"
print_line "$build_log"

run_with_log "$build_log" nix flake update --verbose

if git_has_uncommitted_changes; then
  git_add_path flake.lock
  git_commit_if_staged "flake update: $(date '+%Y-%m-%d %H:%M:%S')" || true
  git_push_if_enabled || true
else
  console_log "$build_log" "${YELLOW}No changes to commit from flake update.${RESET}"
fi
