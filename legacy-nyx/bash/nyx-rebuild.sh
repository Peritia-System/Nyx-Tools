#!/usr/bin/env bash
nyx-rebuild() {
  set -euo pipefail

  ########################################################################
  # CONFIGURATION (injected by Nix)
  ########################################################################
  nix_dir="@NIX_DIR@"
  log_dir="@LOG_DIR@"
  start_editor="@START_EDITOR@"
  enable_formatting="@ENABLE_FORMATTING@"
  editor_cmd="@EDITOR@"
  formatter_cmd="@FORMATTER@"
  git_bin="@GIT_BIN@"
  nom_bin="@NOM_BIN@"
  auto_push="@AUTO_PUSH@"
  version="@VERSION@"

  ########################################################################
  # ARGUMENT PARSING
  ########################################################################
  do_repair=false
  do_update=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repair) do_repair=true; shift;;
      --update) do_update=true; shift;;
      -h|--help)
        cat <<EOF
nyx-rebuild [--repair] [--update]

  --repair   Stage & commit the nix_dir with "rebuild - repair <timestamp>"
             and remove any unfinished logs (Current-Error*.txt and rebuild-*.log
             that are not final nixos-gen_* logs).

  --update   Before rebuilding, update the flake in nix_dir using:
               nix flake update
EOF
        return 0
        ;;
      *) echo "Unknown argument: $1" >&2; return 2;;
    esac
  done

  ########################################################################
  # COLORS (TTY only)
  ########################################################################
  if [[ -t 1 ]]; then
    RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'
    BLUE=$'\e[34m'; MAGENTA=$'\e[35m'; CYAN=$'\e[36m'
    BOLD=$'\e[1m'; RESET=$'\e[0m'
  else
    RED=""; GREEN=""; YELLOW=""
    BLUE=""; MAGENTA=""; CYAN=""
    BOLD=""; RESET=""
  fi

  ########################################################################
  # LIGHTWEIGHT GIT HELPERS
  ########################################################################
  g() { "$git_bin" "$@"; }

  git_in_repo() {
    local dir="$1"
    [[ -d "$dir/.git" ]] || (cd "$dir" && g rev-parse --git-dir >/dev/null 2>&1)
  }

  git_has_uncommitted_changes() {
    # prints true if there are changes
    [[ -n "$(g status --porcelain)" ]]
  }

  git_pause_if_dirty() {
    local attempts=0
    while git_has_uncommitted_changes; do
      if (( attempts == 0 )); then
        echo "${YELLOW}Uncommitted changes detected!${RESET}"
        echo "${RED}Pausing for 5 seconds to allow cancel (Ctrl-C) before attempting repair...${RESET}"
        sleep 5
        echo "Attempting repair..."
        repair || true   # never let a no-op commit kill the script
        echo "repair ran"
        ((attempts++)) || true  
        # loop will re-check cleanliness
      else
        echo "${YELLOW}Uncommitted changes still present after repair.${RESET}"
        echo "${RED}Needs manual review. Continuing in 5 seconds...${RESET}"
        sleep 5
        break
      fi
    done
  }



  git_pull_rebase() {
    g pull --rebase
  }

  git_add_path() {
    g add "$@"
  }

  git_commit_if_staged() {
    # commit if there is something staged; ignore empty
    if ! g diff --cached --quiet; then
      g commit -m "$1" || true
    fi
  }

  git_commit_message() {
    local msg="$1"
    g commit -m "$msg"
  }

  git_push_if_enabled() {
    if [[ "${auto_push}" == "true" ]]; then
      g push
    fi
  }

  git_safe_add_commit_push() {
    # Convenience: add paths, commit message, optional push
    local msg="$1"; shift
    git_add_path "$@"
    if git_commit_if_staged "$msg"; then
      git_push_if_enabled
    fi
  }


  ########################################################################
  # REPAIR MODE
  ########################################################################
  repair() {
    cd "$nix_dir" || { echo "ERROR: Cannot cd into nix_dir: $nix_dir" >&2; return 1; }

    ts="$(date '+%Y-%m-%d_%H-%M-%S')"
    echo "Starting repair at ${ts}..."

    # Remove unfinished logs (not final logs)
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

    # Oed; avoid set nly commit if something is stag-e failure on empty commit
    if ! g diff --cached --quiet --; then
      echo "Committing repair changes..."
      g commit -m "rebuild - repair ${ts}"
      echo "Repair commit created."
    else
      echo "No changes to commit."
    fi

  }




  ########################################################################
  # LOGGING / COMMON HELPERS
  ########################################################################
  start_time=$(date +%s)
  start_human=$(date '+%Y-%m-%d %H:%M:%S')
  stats_duration=0
  stats_gen="?"
  stats_errors=0
  stats_last_error_lines=""
  rebuild_success=false
  exit_code=1

  timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
  log_dir_rebuild="${log_dir}/rebuild"
  build_log="${log_dir_rebuild}/rebuild-${timestamp}.log"
  error_log="${log_dir_rebuild}/Current-Error-${timestamp}.txt"

  console-log() { echo -e "$@" | tee -a "$build_log"; }
  print_line()  { console-log ""; console-log "${BOLD}==================================================${RESET}"; console-log ""; }

  run_with_log() {
    local tmp; tmp=$(mktemp)
    ( "$@" 2>&1; echo $? > "$tmp" ) | tee -a "$build_log"
    local s; s=$(<"$tmp"); rm "$tmp"; return "$s"
  }

  run_with_log_rebuild() {
    local tmp; tmp=$(mktemp)
    ( "$@" 2>&1; echo $? > "$tmp" ) | tee -a "$build_log" | $nom_bin
    local s; s=$(<"$tmp"); rm "$tmp"; return "$s"
  }

  ########################################################################
  # EARLY REPAIR MODE CHECK
  ########################################################################
  if [[ "$do_repair" == true ]]; then
      ########################################################################
      # BANNER
      ########################################################################
      echo
      nyx-tool "Nyx" "nyx-rebuild --repair" "$version" \
        "Smart NixOS configuration repair" \
        "by Peritia-System" \
        "https://github.com/Peritia-System/Nyx-Tools" \
        "https://github.com/Peritia-System/Nyx-Tools/issues" \
        "Fixing our mistake... or yours"
      echo
      repair
      rebuild_success=true
      return 0
  fi

  finish_nyx_rebuild() {
    stats_duration=$(( $(date +%s) - start_time ))
    echo
    if [[ "$rebuild_success" == true ]]; then
      echo "${GREEN}${BOLD}NixOS Rebuild Complete${RESET}"
      echo "${BOLD}${CYAN}Summary:${RESET}"
      echo "  Started:    $start_human"
      echo "  Duration:   ${stats_duration} sec"
      echo "  Generation: $stats_gen"
    else
      echo "${RED}${BOLD}NixOS Rebuild Failed${RESET}"
      echo "${BOLD}${RED}Error Stats:${RESET}"
      echo "  Started:    $start_human"
      echo "  Duration:   ${stats_duration} sec"
      echo "  Error lines: ${stats_errors}"
      [[ -n "$stats_last_error_lines" ]] && echo -e "${YELLOW}Last few errors:${RESET}$stats_last_error_lines"
    fi
  }
  trap finish_nyx_rebuild EXIT

  ########################################################################
  # BANNER
  ########################################################################
  echo
  nyx-tool "Nyx" "nyx-rebuild" "$version" \
    "Smart NixOS configuration rebuilder" \
    "by Peritia-System" \
    "https://github.com/Peritia-System/Nyx-Tools" \
    "https://github.com/Peritia-System/Nyx-Tools/issues" \
    "Always up to date for you!"
  echo

  ########################################################################
  # PREP
  ########################################################################
  mkdir -p "$log_dir_rebuild"
  cd "$nix_dir" || { echo "Cannot cd into nix_dir: $nix_dir" >&2; exit_code=1; return $exit_code; }
  
  ########################################################################
  # GIT DIRTY CHECK
  ########################################################################
  echo -e "${BOLD}${BLUE}Checking Git status...${RESET}"
  git_pause_if_dirty

  ########################################################################
  # NORMAL REBUILD FLOW...
  ########################################################################

  console-log "${BOLD}${BLUE}Pulling latest changes...${RESET}"
  if ! run_with_log git pull --rebase; then
    exit_code=1; return $exit_code
  fi

  ########################################################################
  # OPTIONAL: editor
  ########################################################################
  if [[ "$start_editor" == "true" ]]; then
    console-log "${BOLD}${BLUE}Opening editor...${RESET}"
    console-log "Started editing: $(date)"
    run_with_log "$editor_cmd"
    console-log "Finished editing: $(date)"
    console-log "${BOLD}${CYAN}Changes summary:${RESET}"
    run_with_log git diff --compact-summary
  fi

  ########################################################################
  # OPTIONAL: formatter
  ########################################################################
  if [[ "$enable_formatting" == "true" ]]; then
    console-log "${BOLD}${MAGENTA}Running formatter...${RESET}"
    run_with_log "$formatter_cmd" .
  fi

  ########################################################################
  # REBUILD
  ########################################################################

  # Check if update:
  print_line
  if [[ "$do_update" == true ]]; then
    console-log "${BOLD}${BLUE}Updating flake...${RESET}"
    print_line
    run_with_log nix flake update --verbose
    if git_has_uncommitted_changes; then
      git_add_path flake.lock
      git_commit_if_staged "flake update: $(date '+%Y-%m-%d %H:%M:%S')"
    fi
    print_line
  fi


  console-log "${BOLD}${BLUE}Starting system rebuild...${RESET}"

  if find ~ -type f -name '*delme-HMbackup' | grep -q .; then
    print_line
    console-log "Removing old HM conf"
    run_with_log find ~ -type f -name '*delme-HMbackup' -exec rm -v {} +
    print_line
  fi


  if sudo -n true 2>/dev/null; then
    console-log "Sudo rights already available"
  else
    console-log "Getting sudo ticket (please enter your password)"
    run_with_log sudo whoami > /dev/null
  fi

  print_line
  console-log "Rebuild started: $(date)"
  print_line

  run_with_log_rebuild sudo nixos-rebuild switch --flake "$nix_dir"
  rebuild_status=$?

  if [[ $rebuild_status -ne 0 ]]; then
    echo "${RED}Rebuild failed at $(date).${RESET}" > "$error_log"
    stats_errors=$(grep -Ei -A 1 'error|failed' "$build_log" | tee -a "$error_log" | wc -l || true)
    stats_last_error_lines=$(tail -n 10 "$error_log" || true)

    # capture and push error artifacts
    git_add_path "$log_dir_rebuild"
    g commit -m "Rebuild failed: errors logged" || true
    git_push_if_enabled

    exit_code=1
    return $exit_code
  fi

  ########################################################################
  # SUCCESS PATH
  ########################################################################
  rebuild_success=true
  exit_code=0

  gen=$(nixos-rebuild list-generations | grep True | awk '{$1=$1};1' || true)
  stats_gen=$(echo "$gen" | awk '{printf "%04d", $1}' || echo "0000")

  # Append summary to build log (before rotating file name)
  finish_nyx_rebuild >> "$build_log"

  # Commit config changes (if any)
  git_add_path -u
  if git_commit_if_staged "Rebuild: $gen"; then
    echo "${BLUE}Commit message:${RESET}${GREEN}Rebuild: $gen${RESET}"
  fi

  # Move and add final log
  final_log="$log_dir_rebuild/nixos-gen_${stats_gen}-switch-${timestamp}.log"
  mv "$build_log" "$final_log"
  git_add_path "$final_log"
  git_commit_if_staged "log for $gen" || echo "${YELLOW}No changes in logs to commit.${RESET}"

  git_push_if_enabled && echo "${GREEN}Changes pushed to remote.${RESET}" || true
}

# Execute when sourced as a script
nyx-rebuild "$@"
