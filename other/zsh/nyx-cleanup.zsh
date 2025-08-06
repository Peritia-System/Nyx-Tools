    # Extract cfg values into local variables
        nix_dir="${cfg.nixDirectory}"
        start_editor="${toString cfg.startEditor}"
        enable_formatting="${toString cfg.enableFormatting}"
        editor_cmd="${cfg.editor}"
        formatter_cmd="${cfg.formatter}"
        auto_push="${toString cfg.autoPush}"
        source "${scriptTargetPath}"

function nyx-cleanup() {
  ##### 🛠️ CONFIGURATION #####
  local version="1.3.1"
  local keep_generations="${keep_generations:-5}"
  local start_human=$(date '+%Y-%m-%d %H:%M:%S')
  local nix_cleanup_log="nixos-cleanup.log"
  local optimize_store="${optimize_store:-false}"
  local auto_push="${auto_push:-false}"

  local RED=$'\e[31m'; local GREEN=$'\e[32m'; local YELLOW=$'\e[33m'
  local BLUE=$'\e[34m'; local MAGENTA=$'\e[35m'; local CYAN=$'\e[36m'
  local BOLD=$'\e[1m'; local RESET=$'\e[0m'

  ##### 📁 PATH SETUP #####
  local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
  local hostname_id=$(hostname)
  local log_dir="$nix_dir/Misc/nyx/logs/$hostname_id"
  mkdir -p "$log_dir"
  local cleanup_log="$log_dir/cleanup-$timestamp.log"
  local log_file="$log_dir/nixos-gen-cleanup-$timestamp.log"

  ##### 🧰 HELPERS #####
  console-log() {
    echo -e "$@" | tee -a "$cleanup_log"
  }

  print_line() {
    console-log "${BOLD}$(printf '%*s\n' "${COLUMNS:-40}" '' | tr ' ' '=')${RESET}"
  }

  format_bytes() {
    num=$1
    echo $(numfmt --to=iec-i --suffix=B "$num")
  }

  disk_usage() {
    df --output=used /nix/store | tail -1
  }

  ##### 📘 TOOL INFO #####
  print_line
  nyx-tool "Nyx" "nyx-cleanup" "$version" \
    "Smart NixOS configuration cleanup" \
    "by Peritia-System" \
    "https://github.com/Peritia-System/Nyx-Tools" \
    "https://github.com/Peritia-System/Nyx-Tools/issues" \
    "Always up to date for you!"
  echo
  echo -e "${BOLD}${CYAN}🧼 Nyx Cleanup v$version — Starting...${RESET}"
  print_line

  ##### 📊 STATS: BEFORE #####
  local disk_before=$(disk_usage)
  console-log "${CYAN}📊 Disk used before cleanup: $(format_bytes $disk_before)${RESET}"

  ##### 🧹 EXECUTION #####
  console-log "\n${BLUE}🗑️  Collecting Nix garbage...${RESET}"
  sudo nix-collect-garbage -d >> "$cleanup_log" 2>&1

  console-log "\n${BLUE}🧹 Deleting old generations (keep $keep_generations)...${RESET}"
  sudo nix-collect-garbage --delete-older-than "${keep_generations}d" >> "$cleanup_log" 2>&1

  if [[ "$optimize_store" == "true" ]]; then
    console-log "\n${MAGENTA}🔧 Optimizing the Nix store...${RESET}"
    sudo nix-store --optimize >> "$cleanup_log" 2>&1
  fi

  ##### 📊 STATS: AFTER #####
  local disk_after=$(disk_usage)
  local space_freed=$((disk_before - disk_after))
  print_line
  console-log "${GREEN}${BOLD}✅ Cleanup Completed Successfully!${RESET}"
  console-log "${CYAN}🕒 Finished at: $(date)${RESET}"
  console-log "${CYAN}📊 Disk used after cleanup:  $(format_bytes $disk_after)${RESET}"
  console-log "${CYAN}💾 Space freed:              $(format_bytes $space_freed)${RESET}"
  print_line

  ##### 📝 GIT LOGGING #####
  local gen_nmbr=$(nixos-rebuild list-generations | grep True | awk '{print $1}' | tail -1 | xargs printf "%04d\n")

  cd "$nix_dir" || return 1
  mv "$nix_cleanup_log" "$log_file"
  git add "$log_file"

  if ! git diff --cached --quiet; then
    git commit -m "Cleanup log on $timestamp"
    console-log "${GREEN}✅ Cleanup log committed.${RESET}"
  else
    console-log "${YELLOW}ℹ️  No new changes in logs to commit.${RESET}"
  fi

  if [[ "$auto_push" == "true" ]]; then
    console-log "${BLUE}🚀 Auto-push enabled. Pushing to remote...${RESET}"
    git push && console-log "${GREEN}✅ Changes pushed to remote.${RESET}"
  fi

  console-log "\n${GREEN}🎉 Nyx cleanup finished!${RESET}"
  print_line
}
