function nyx-rebuild() {

  ###### CONFIGURATION ######
  local version="1.0.3"  # ⚠️ EDIT VERSION HERE

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

  ###### TOOL DESCRIPTION ######
  nix-tool \
    "Nyx" \
    "nyx-rebuild" \
    "$version" \
    "Smart NixOS configuration rebuilder" \
    "by Peritia-System" \
    "https://github.com/Peritia-System/nix-os-private" \
    "https://github.com/Peritia-System/nix-os-private/issues" \
    "Always up to date for you!"
  
  print_line
  
  ###### GIT PRECHECKS ######
  cd "$nix_dir" || return 1
  echo -e "\n${BOLD}${BLUE}📁 Checking Git status...${RESET}"
  if [[ -n $(git status --porcelain) ]]; then
    echo -e "${YELLOW}⚠️  Uncommitted changes detected!${RESET}" | tee -a nixos-switch.log
    echo -e "${RED}⏳ 5s to cancel...${RESET}"
    sleep 5
  #  return 1
  fi

  echo -e "\n${BOLD}${BLUE}⬇️  Pulling latest changes...${RESET}"
  if ! git pull --rebase | tee -a nixos-switch.log; then
    echo -e "${RED}❌ Git pull failed.${RESET}" | tee -a nixos-switch.log
    return 1
  fi

  ###### OPTIONAL CONFIG EDITING ######
  if [[ "${start_editor}" == "true" ]]; then
    echo -e "\n${BOLD}${BLUE}📝 Editing configuration...${RESET}"
    echo "Started editing: $(date)" | tee -a nixos-switch.log
    $editor_cmd
    echo "Finished editing: $(date)" | tee -a nixos-switch.log
  fi

  ###### OPTIONAL FORMATTER ######
  if [[ "${enable_formatting}" == "true" ]]; then
    echo -e "\n${BOLD}${MAGENTA}🎨 Running formatter...${RESET}" | tee -a nixos-switch.log
    $formatter_cmd . >/dev/null
  fi

  ###### GIT DIFF SUMMARY ######
  echo -e "\n${BOLD}${CYAN}🔍 Changes summary:${RESET}" | tee -a nixos-switch.log
  git diff --compact-summary | tee -a nixos-switch.log

  ###### SYSTEM REBUILD ######
  echo -e "\n${BOLD}${BLUE}🔧 Starting system rebuild...${RESET}" | tee -a nixos-switch.log
  local start_time=$(date +%s)
  print_line | tee -a nixos-switch.log
  echo "🛠️  Rebuild started: $(date)" | tee -a nixos-switch.log
  print_line | tee -a nixos-switch.log

  # REBUILDING
  sudo nixos-rebuild switch --flake "${nix_dir}" &>nixos-switch.log 
  local rebuild_status=$?


  if [[ $rebuild_status -ne 0 ]]; then
    echo -e "\n${BOLD}${RED}❌ Rebuild failed at $(date). Showing errors:${RESET}" | tee -a nixos-switch.log
    echo "${RED}❌ Rebuild failed at $(date). Showing errors:${RESET}" > Current-Error.txt
    grep --color=auto -Ei 'error|failed' nixos-switch.log || true
    grep --color=auto -Ei 'error|failed' nixos-switch.log || true >> Current-Error.txt
    git add Current-Error.txt
    git commit -m "Rebuild failed"
    return 1
  fi

    ###### SUCCESS SUMMARY ######
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        print_line | tee -a nixos-switch.log
        echo -e "${GREEN}${BOLD}✅ NixOS rebuild completed successfully!${RESET}" | tee -a nixos-switch.log
        echo -e "${CYAN}⏱️  Total rebuild time: $((duration / 60)) min $((duration % 60)) sec${RESET}" | tee -a nixos-switch.log
        print_line | tee -a nixos-switch.log

        local gen
        gen=$(nixos-rebuild list-generations | grep True | awk '{$1=$1};1')
        gen_nmbr=$(nixos-rebuild list-generations | grep True | awk '{$1=$1};1' | awk '{printf "%04d\n", $1}')

        echo -e "${BOLD}${GREEN}🎉 Done. Enjoy your freshly rebuilt system!${RESET}" | tee -a nixos-switch.log
        print_line | tee -a nixos-switch.log


  ###### GENERATION INFO + GIT COMMIT ######
  git add -u
  git diff --cached --quiet || git commit -m "Rebuild: $gen"
  echo -e "${BLUE}🔧 Commit message:${RESET}" | tee -a nixos-switch.log
  echo -e "${GREEN}Rebuild: $gen${RESET}" | tee -a nixos-switch.log
  print_line | tee -a nixos-switch.log
  echo -e "\n${GREEN}✅ Changes committed.${RESET}" | tee -a nixos-switch.log

  ###### AUTO PUSH ######
   if [[ "${auto_push}" == "true" ]]; then
      echo -e "${BLUE}🚀 Auto-push enabled:${RESET}" | tee -a nixos-switch.log
      echo -e "\n${BOLD}${BLUE}🚀 Pushing to remote...${RESET}" | tee -a nixos-switch.log
      git push && echo -e "${GREEN}✅ Changes pushed to remote.${RESET}" | tee -a nixos-switch.log
  else
      echo -e "${YELLOW}📌 Auto-push is disabled. Remember to push manually if needed.${RESET}" | tee -a nixos-switch.log
  fi

  ###### LOG ARCHIVING ######
  local log_dir="$nix_dir/Misc/nyx/logs/$(hostname)"
  mkdir -p "$log_dir"
  local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
  local log_file="$log_dir/nixos-gen_$gen_nmbr-switch-$timestamp.log"

  mv nixos-switch.log "$log_file"
  git add "$log_file"
  echo -e "${YELLOW}Moved Logfile ${RESET}"

  if ! git diff --cached --quiet; then
    git commit -m "log for $gen"
    echo -e "${YELLOW}ℹ️  Added changes to git ${RESET}"
  else
    echo -e "${YELLOW}ℹ️  No changes in logs to commit.${RESET}"
  fi
 ###### AUTO PUSH ######
   if [[ "${auto_push}" == "true" ]]; then
      git push && echo -e "${GREEN}✅ Changes pushed to remote.${RESET}" 
   fi
  echo -e "\n${GREEN}🎉 Nyx rebuild completed successfully!${RESET}"
  print_line
}
