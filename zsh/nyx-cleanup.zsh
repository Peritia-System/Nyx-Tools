function nyx-cleanup() {

  ###### CONFIGURATION ######
  local version="1.0.0"
  local keep_generations="${keep_generations:-5}"

  # Setup 16-color ANSI (TTY-safe)
  if [[ -t 1 ]]; then
    RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; BLUE=$'\e[34m'
    MAGENTA=$'\e[35m'; CYAN=$'\e[36m'; BOLD=$'\e[1m'; RESET=$'\e[0m'
  else
    RED=""; GREEN=""; YELLOW=""; BLUE=""
    MAGENTA=""; CYAN=""; BOLD=""; RESET=""
  fi

  print_line() { echo -e "${BOLD}$(printf '%*s\n' "${COLUMNS:-40}" '' | tr ' ' '=')${RESET}"; }

  print_line
  echo -e "${BOLD}${CYAN}🧼 Nyx Cleanup v${version}${RESET}"
  print_line

  ###### TOOL DESCRIPTION ######
  echo -e "${MAGENTA}Cleaning up old generations and Nix garbage...${RESET}"
  echo "Started cleanup: $(date)" | tee nixos-cleanup.log

  ###### GARBAGE COLLECTION ######
  echo -e "\n${BLUE}🗑️  Running Nix garbage collection...${RESET}" | tee -a nixos-cleanup.log
  sudo nix-collect-garbage -d | tee -a nixos-cleanup.log

  ###### REMOVE OLD GENERATIONS ######
  echo -e "\n${BLUE}🧹 Removing old generations (keeping last ${keep_generations})...${RESET}" | tee -a nixos-cleanup.log
  sudo nix-collect-garbage --delete-older-than "${keep_generations}d" | tee -a nixos-cleanup.log

  ###### OPTIONAL STORE OPTIMIZATION ######
  if [[ "${optimize_store}" == "true" ]]; then
    echo -e "\n${MAGENTA}🔧 Optimizing the Nix store...${RESET}" | tee -a nixos-cleanup.log
    sudo nix-store --optimize | tee -a nixos-cleanup.log
  fi

  ###### SUCCESS SUMMARY ######
  print_line | tee -a nixos-cleanup.log
  echo -e "${GREEN}${BOLD}✅ Nix cleanup completed successfully!${RESET}" | tee -a nixos-cleanup.log
  echo -e "${CYAN}🕒 Finished at: $(date)${RESET}" | tee -a nixos-cleanup.log
  print_line | tee -a nixos-cleanup.log

  ###### OPTIONAL COMMIT LOG ######
  gen=$(nixos-rebuild list-generations | grep True | awk '{$1=$1};1')
  gen_nmbr=$(nixos-rebuild list-generations | grep True | awk '{$1=$1};1' | awk '{printf "%04d\n", $1}')

  cd "$nix_dir" || return 1
  local log_dir="$nix_dir/Misc/nyx/logs/$(hostname)"
  mkdir -p "$log_dir"
  local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
  local log_file="$log_dir/nixos-gen_$gen_nmbr-cleanup-$timestamp.log"

  mv nixos-cleanup.log "$log_file"
  git add "$log_file"

  if ! git diff --cached --quiet; then
    git commit -m "Cleanup log on $timestamp"
    echo -e "${GREEN}✅ Cleanup log committed.${RESET}"
  else
    echo -e "${YELLOW}ℹ️  No new changes in logs to commit.${RESET}"
  fi

  if [[ "${auto_push}" == "true" ]]; then
    echo -e "${BLUE}🚀 Auto-push enabled. Pushing to remote...${RESET}"
    git push && echo -e "${GREEN}✅ Changes pushed to remote.${RESET}"
  fi

  echo -e "\n${GREEN}🎉 Nyx cleanup finished!${RESET}"
  print_line
}
