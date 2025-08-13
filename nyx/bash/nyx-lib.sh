#!/usr/bin/env bash
# nyx-lib.sh — shared helpers for all Nyx commands
# Lokens (tokens) are substituted by Nix during build:
#   @LOG_DIR@ @NIX_DIR@ @VERSION@
#   @START_EDITOR@ @ENABLE_FORMATTING@ @EDITOR@ @FORMATTER@
#   @GIT_BIN@ @NOM_BIN@ @AUTO_PUSH@ @AUTO_COMMIT@
#   @KEEP_GENERATIONS@ @DIALOG_BIN@

set -euo pipefail

########################################################################
# CONFIG (all values provided by Nix via Lokens)
########################################################################
NYX_LOG_DIR="@LOG_DIR@"
NYX_NIX_DIR="@NIX_DIR@"
NYX_VERSION="@VERSION@"

NYX_START_EDITOR="@START_EDITOR@"
NYX_ENABLE_FORMATTING="@ENABLE_FORMATTING@"
NYX_EDITOR_CMD="@EDITOR@"
NYX_FORMATTER_CMD="@FORMATTER@"

NYX_GIT_BIN="@GIT_BIN@"
NYX_NOM_BIN="@NOM_BIN@"
NYX_AUTO_PUSH="@AUTO_PUSH@"
NYX_AUTO_COMMIT="@AUTO_COMMIT@"

NYX_KEEP_GENERATIONS="@KEEP_GENERATIONS@"
NYX_DIALOG_BIN="@DIALOG_BIN@"

mkdir -p "$NYX_LOG_DIR"


########################################################################
# COLORS
########################################################################
if [[ -t 1 ]]; then
  RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'
  BLUE=$'\e[34m'; MAGENTA=$'\e[35m'; CYAN=$'\e[36m'
  BOLD=$'\e[1m'; RESET=$'\e[0m'
else
  RED=; GREEN=; YELLOW=; BLUE=; MAGENTA=; CYAN=; BOLD=; RESET=
fi

########################################################################
# BANNER / NOTICE
########################################################################
nyx_banner() {
  if command -v nyx-tool >/dev/null 2>&1; then
    nyx-tool "Nyx" "$1" "$NYX_VERSION" "$2" \
      "by Peritia-System" \
      "https://github.com/Peritia-System/Nyx-Tools" \
      "https://github.com/Peritia-System/Nyx-Tools/issues" \
      "${3:-Have a nice day!}"
    # Show project notice if present
    command -v nyx-info >/dev/null 2>&1 && nyx-info || true
  else
    echo "Nyx — $1 ($NYX_VERSION) — $2"
  fi
}

########################################################################
# GIT HELPERS (mirroring original behavior) :contentReference[oaicite:12]{index=12}
########################################################################
g() { "$NYX_GIT_BIN" "$@"; }

nyx_git_has_uncommitted() { [[ -n "$(g status --porcelain)" ]]; }

nyx_git_add() { g add "$@"; }

nyx_git_commit_msg() {
  local msg="$1"
  if [[ "$NYX_AUTO_COMMIT" == "true" ]]; then
    g commit -m "$msg"
  else
    echo "skipping commit (NYX_AUTO_COMMIT=$NYX_AUTO_COMMIT)"
  fi
}

nyx_git_commit_if_staged() {
  if ! g diff --cached --quiet; then
    nyx_git_commit_msg "$1" || true
    return 0
  fi
  return 1
}

nyx_git_push_if_enabled() {
  if [[ "$NYX_AUTO_PUSH" == "true" ]]; then
    g push || true
  fi
}

nyx_git_pause_if_dirty_then_try_repair() {  # :contentReference[oaicite:13]{index=13}
  local attempts=0
  while nyx_git_has_uncommitted; do
    if (( attempts == 0 )); then
      echo "${YELLOW}Uncommitted changes detected.${RESET}"
      echo "${RED}Pausing 5s before attempting 'nyx-repair'...${RESET}"
      sleep 5
      command -v nyx-repair >/dev/null 2>&1 && nyx-repair || true
      ((attempts++)) || true
    else
      echo "${YELLOW}Still dirty after repair; continuing in 5s...${RESET}"
      sleep 5
      break
    fi
  done
}

########################################################################
# LOGGING HELPERS (plus NOM pipeline like original) :contentReference[oaicite:14]{index=14}
########################################################################
nyx_console_log() { local logfile="$1"; shift; echo -e "$*" | tee -a "$logfile"; }
nyx_print_line()  { local logfile="$1"; nyx_console_log "$logfile" ""; nyx_console_log "$logfile" "${BOLD}==================================================${RESET}"; nyx_console_log "$logfile" ""; }

nyx_run_with_log() {        # cmd output tee->log, return status
  local logfile="$1"; shift
  local tmp; tmp=$(mktemp)
  ( "$@" 2>&1; echo $? > "$tmp" ) | tee -a "$logfile"
  local s; s=$(<"$tmp"); rm "$tmp"; return "$s"
}

nyx_run_with_log_rebuild() { # cmd output tee->log | nom, return status :contentReference[oaicite:15]{index=15}
  local logfile="$1"; shift
  local tmp; tmp=$(mktemp)
  ( "$@" 2>&1; echo $? > "$tmp" ) | tee -a "$logfile" | "$NYX_NOM_BIN"
  local s; s=$(<"$tmp"); rm "$tmp"; return "$s"
}

########################################################################
# SUDO
########################################################################
nyx_ensure_sudo() {
  if sudo -n true 2>/dev/null; then
    echo "Sudo ticket present."
  else
    echo "Acquiring sudo (may prompt)..."
    sudo -v
  fi
}

nyx_ensure_no_sudo_when_run() {
  if [[ "${EUID}" -eq 0 ]]; then
    echo "${RED}Error:${RESET} Do not run this command with sudo."
    echo "Nyx will ask for sudo when needed, avoiding ownership issues with Git or logs."
    exit 1
  fi
}

########################################################################
# SPINNER (for TUI-friendly UX)
########################################################################
nyx_spinner() {
  local label="$1"; shift
  echo "${CYAN}${BOLD}${label}${RESET}"
  ( "$@" ) &
  local pid=$! spin='|/-\' i=0
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) % 4 )); printf "\r%s" "${spin:$i:1}"; sleep 0.1
  done
  wait "$pid"; local status=$?; printf "\r"; return $status
}

########################################################################
# UTIL
########################################################################
nyx_timestamp() { date '+%Y-%m-%d_%H-%M-%S'; }
nyx_start_human() { date '+%Y-%m-%d %H:%M:%S'; }

export NYX_LOG_DIR NYX_NIX_DIR NYX_VERSION
export NYX_KEEP_GENERATIONS NYX_AUTO_PUSH NYX_AUTO_COMMIT
