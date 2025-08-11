#!/usr/bin/env bash
# nyx-tui: interactive TUI for Nyx tasks

if [ -z "${BASH_VERSION:-}" ]; then
  echo "This script must be run with bash, not $SHELL" >&2
  exit 1
fi

set -euo pipefail

########################################################################
# CONFIGURATION (injected by Nix)
########################################################################
log_dir="@LOG_DIR@"
nix_dir="@NIX_DIR@"
version="@VERSION@"
dialog_bin="${DIALOG_BIN:-@DIALOG_BIN@}"

# Fallbacks if Nix didn't substitute
if [[ -z "${dialog_bin//@DIALOG_BIN@/}" ]]; then
  # If placeholder remained, try common defaults
  if command -v dialog >/dev/null 2>&1; then
    dialog_bin="$(command -v dialog)"
  elif command -v whiptail >/dev/null 2>&1; then
    dialog_bin="$(command -v whiptail)"
  else
    echo "Error: neither 'dialog' nor 'whiptail' found. Please install one." >&2
    exit 1
  fi
fi

if ! command -v "$dialog_bin" >/dev/null 2>&1; then
  echo "Error: dialog binary '$dialog_bin' is not executable." >&2
  exit 1
fi

mkdir -p "$log_dir"

########################################################################
# CLI args
########################################################################
do_startup=false

print_help() {
  cat <<'EOF'
nyx-tui [--pretty] [--help]

  --pretty   Show a simple artificial startup screen (optional).
  --help     Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pretty) do_startup=true; shift;;
    -h|--help) print_help; exit 0;;
    *) echo "Unknown argument: $1" >&2; exit 2;;
  esac
done

########################################################################
# Colors (TTY only)
########################################################################
if [[ -t 1 ]]; then
  RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'
  BLUE=$'\e[34m'; MAGENTA=$'\e[35m'; CYAN=$'\e[36m'
  BOLD=$'\e[1m'; RESET=$'\e[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""; BOLD=""; RESET=""
fi

pause() { read -r -p "Press Enter to continue..." _; }

########################################################################
# Dialog wrappers
########################################################################
d_msg() {
  local msg="${1:-}"
  "$dialog_bin" --title "Nyx TUI" --msgbox "$msg" 8 60
  clear
}

d_textbox() {
  local title="${1:-}"; local file="${2:-}"
  "$dialog_bin" --title "$title" --textbox "$file" 20 100
  clear
}

d_menu() {
  local title="$1"; shift
  local prompt="$1"; shift
  local choice
  choice=$("$dialog_bin" --title "$title" --menu "$prompt" 20 70 10 "$@" 3>&1 1>&2 2>&3) || return 1
  echo "$choice"
}

########################################################################
# Helpers
########################################################################
run_with_spinner() {
  local label="$1"; shift
  echo "${CYAN}${BOLD}${label}${RESET}"
  ( "$@" ) &
  local pid=$!
  local spin='|/-\'; local i=0
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    printf "\r%s" "${spin:$i:1}"
    sleep 0.1
  done
  wait "$pid"; local status=$?; printf "\r"
  return $status
}

########################################################################
# Actions
########################################################################
action_rebuild() {
  clear
  if command -v nyx-rebuild >/dev/null 2>&1; then
    run_with_spinner "Rebuilding (nyx-rebuild)..." nyx-rebuild || true
    if ! check_last_log_for_error; then
      return
    fi
    d_msg "Rebuild finished."
  elif command -v nixos-rebuild >/dev/null 2>&1; then
    run_with_spinner "nixos-rebuild switch --flake ${nix_dir} ..." \
      sudo nixos-rebuild switch --flake "$nix_dir" || true
    sleep 1
    d_msg "nixos-rebuild finished."
  else
    d_msg "No rebuild tool found (nyx-rebuild / nixos-rebuild). Skipping."
  fi
}

action_update() {
  clear
  if command -v nyx-rebuild >/dev/null 2>&1; then
    run_with_spinner "Updating (nyx-rebuild --update)..." nyx-rebuild --update || true
    if ! check_last_log_for_error; then
      return
    fi
    d_msg "Update finished."
  elif command -v nixos-rebuild >/dev/null 2>&1; then
    (
      cd "$nix_dir"
      run_with_spinner "nix flake update..." nix flake update || true
    )
    run_with_spinner "nixos-rebuild switch --flake ${nix_dir} ..." \
      sudo nixos-rebuild switch --flake "$nix_dir" || true
    sleep 1
    d_msg "nixos-rebuild finished."
  else
    d_msg "No update tool found. Skipping."
  fi
}

action_repair() {
  clear
  if command -v nyx-rebuild >/dev/null 2>&1; then
    run_with_spinner "Repairing (nyx-rebuild --repair)..." nyx-rebuild --repair || true
    if ! check_last_log_for_error; then
      return
    fi
    d_msg "Repair finished."
  else
    d_msg "No repair tool found. Skipping."
  fi
}

action_cleanup() {
  clear
  if command -v nyx-cleanup >/dev/null 2>&1; then
    run_with_spinner "Cleaning up..." nyx-cleanup || true
    sleep 1
    d_msg "Cleanup finished."
  else
    d_msg "nyx-cleanup not found; nothing to do."
  fi
}

action_update_flake() {
  clear
  if command -v nix >/dev/null 2>&1 && [[ -d "$nix_dir" ]]; then
    ( cd "$nix_dir" && run_with_spinner "nix flake update..." nix flake update ) || true
    d_msg "Flake update finished."
  else
    d_msg "nix not installed or flake dir missing: ${nix_dir}"
  fi
}

action_git_pull() {
  clear
  if [[ -d "$nix_dir/.git" ]]; then
    ( cd "$nix_dir" && run_with_spinner "git pull --rebase..." git pull --rebase ) || true
    d_msg "Git pull completed."
  else
    d_msg "No git repo at: ${nix_dir}"
  fi
}

action_system_info() {
  local tmp; tmp="$(mktemp)"
  {
    echo "Host: $(hostname)"
    echo "Kernel: $(uname -srmo)"
    echo "Uptime: $(uptime -p)"
    echo
    echo "Disk (root):"
    df -h /
    echo
    if command -v nix >/dev/null 2>&1; then
      echo "Nix profiles:"
      nix profile list || true
    else
      echo "Nix not installed."
    fi
  } > "$tmp"
  d_textbox "System Info" "$tmp"
  rm -f "$tmp"
}

action_view_logs() {
  if [[ -d "$log_dir" ]]; then
    local lastlog tmp
    tmp="$(mktemp)"
    lastlog="$(find "$log_dir" -type f -name '*.log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1{print $2}')"
    if [[ -n "${lastlog:-}" && -f "$lastlog" ]]; then
      tail -n 300 "$lastlog" > "$tmp"
      d_textbox "Last Rebuild Log: $(basename "$lastlog")" "$tmp"
    else
      d_msg "No logs found in ${log_dir}"
    fi
    rm -f "$tmp"
  else
    d_msg "Log directory not found: ${log_dir}"
  fi
}

check_last_log_for_error() {
  local lastlog
  lastlog="$(find "$log_dir" -type f -name '*.log' -printf '%T@ %p\n' 2>/dev/null |
             sort -nr | awk 'NR==1{print $2}')"
  if [[ -n "${lastlog:-}" && -f "$lastlog" ]]; then
    if grep -qi "error" "$lastlog"; then
      local tmp
      tmp="$(mktemp)"
      echo "Error detected in: $(basename "$lastlog")" > "$tmp"
      echo >> "$tmp"
      grep -A99999 -i "error" "$lastlog" >> "$tmp"
      d_textbox "Last Build Error" "$tmp"
      rm -f "$tmp"
      return 1
    fi
  fi
  return 0
}



startup() {
  clear
  if "$do_startup"; then
    echo
    nyx-tool "Nyx" "nyx-tui" "$version" \
      "A better way to nyx" \
      "by Peritia-System" \
      "https://github.com/Peritia-System/Nyx-Tools" \
      "https://github.com/Peritia-System/Nyx-Tools/issues" \
      "Because who doesn't love a good TUI"
    echo "Loading Nyx TUI..."
    echo

    local bar_length=25
    for ((i=0; i<=bar_length; i++)); do
      local filled empty percent
      filled=$(printf "%${i}s" | tr ' ' '#')
      empty=$(printf "%$((bar_length - i))s" | tr ' ' ' ')
      percent=$(( i * 100 / bar_length ))
      printf "\r[%s%s] %d%%" "$filled" "$empty" "$percent"
      sleep 0.2
      # Slow down after 70% (i > 17 when bar_length = 25)
      if [[ $i -gt 17 ]]; then
        sleep 0.1
      fi
    done
    echo -e "\nAll Loaded!\n"
    read -r -p "Press Enter to continue..."
    clear
  else
    echo
    nyx-tool "Nyx" "nyx-tui" "$version" \
      "A better way to nyx" \
      "by Peritia-System" \
      "https://github.com/Peritia-System/Nyx-Tools" \
      "https://github.com/Peritia-System/Nyx-Tools/issues" \
      "Because who doesn't love a good TUI"
    read -r -p "Press Enter to continue..."
    clear
  fi
}


########################################################################
# Menu Loop
########################################################################
startup
while true; do
  choice=$(d_menu "Nyx TUI ${version}" "Select an action:" \
    1 "Update" \
    2 "Rebuild" \
    3 "Repair" \
    4 "Cleanup (nyx-cleanup)" \
    5 "Flake: nix flake update" \
    6 "Git pull (in nix dir)" \
    7 "System info" \
    8 "View latest rebuild log" \
    X "Exit") || { clear; exit 0; }

  case "$choice" in
    1) action_update ;;
    2) action_rebuild ;;
    3) action_repair ;;
    4) action_cleanup ;;
    5) action_update_flake ;;
    6) action_git_pull ;;
    7) action_system_info ;;
    8) action_view_logs ;;
    X) clear; exit 0 ;;
  esac
done
