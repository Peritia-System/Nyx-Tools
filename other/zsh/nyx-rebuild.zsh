function nyx-rebuild() {

  #################### 🔧 INITIAL SETUP ####################
  local version="1.3.0"
  local start_time=$(date +%s)
  local start_human=$(date '+%Y-%m-%d %H:%M:%S')
  local stats_duration=0
  local stats_gen="?"
  local stats_errors=0
  local stats_last_error_lines=""
  local rebuild_success=false
  local exit_code=1  # default to failure

  trap finish_nyx_rebuild 

  #################### 🎨 ANSI COLORS ####################
  if [[ -t 1 ]]; then
    RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; BLUE=$'\e[34m'
    MAGENTA=$'\e[35m'; CYAN=$'\e[36m'; BOLD=$'\e[1m'; RESET=$'\e[0m'
  else
    RED=""; GREEN=""; YELLOW=""; BLUE=""
    MAGENTA=""; CYAN=""; BOLD=""; RESET=""
  fi

  #################### 📁 PATH SETUP ####################
  local log_dir="$nix_dir/Misc/nyx/logs/$(hostname)"
  mkdir -p "$log_dir"
  local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
  local build_log="$log_dir/build-${timestamp}.log"
  local error_log="$log_dir/Current-Error-${timestamp}.txt"

  #################### 🧰 HELPERS ####################
  console-log() {
    echo -e "$@" | tee -a "$build_log"
  }

  print_line() {
    console-log "${BOLD}$(printf '%*s\n' "${COLUMNS:-40}" '' | tr ' ' '=')${RESET}"
  }

  run_with_log() {
    local cmd_output
    cmd_output=$(mktemp)
    (
      "$@" 2>&1
      echo $? > "$cmd_output"
    ) | tee -a "$build_log"
    local exit_code=$(<"$cmd_output")
    rm "$cmd_output"
    return "$exit_code"
  }
  run_with_log_rebuild() {
    local cmd_output
    cmd_output=$(mktemp)
    (
      "$@" 2>&1
      echo $? > "$cmd_output"
    ) | tee -a "$build_log" | nom
    local exit_code=$(<"$cmd_output")
    rm "$cmd_output"
    return "$exit_code"
  }

  finish_nyx_rebuild() {
    stats_duration=$(( $(date +%s) - start_time ))
    echo
    
    if [[ "$rebuild_success" == true ]]; then
      echo "${GREEN}${BOLD}
##############################
# ✅ NixOS Rebuild Complete! #
##############################${RESET}"
      echo "${BOLD}${CYAN}🎯 Success Stats:${RESET}"
      echo "  🕒 Started:   $start_human"
      echo "  ⏱️  Duration: ${stats_duration} sec"
      echo "  📦 Gen:       $stats_gen"
    else
      echo "${RED}${BOLD}
##############################
# ❌ NixOS Rebuild Failed!   #
##############################${RESET}"
      echo "${BOLD}${RED}🚨 Error Stats:${RESET}"
      echo "  🕒 Started:   $start_human"
      echo "  ⏱️  Duration: ${stats_duration} sec"
      echo "  ❌ Error lines: ${stats_errors}"
      [[ -n "$stats_last_error_lines" ]] && echo "\n${YELLOW}🧾 Last few errors:${RESET}\n$stats_last_error_lines"
    fi
    echo
    return $exit_code
  }

  #################### 📘 TOOL INFO ####################
  echo
  nyx-tool "Nyx" "nyx-rebuild" "$version" \
    "Smart NixOS configuration rebuilder" \
    "by Peritia-System" \
    "https://github.com/Peritia-System/Nyx-Tools" \
    "https://github.com/Peritia-System/Nyx-Tools/issues" \
    "Always up to date for you!"
  echo

  #################### 📁 PROJECT PREP ####################
  cd "$nix_dir" || { exit_code=1; return $exit_code; }

  echo "\n${BOLD}${BLUE}📁 Checking Git status...${RESET}"
  if [[ -n $(git status --porcelain) ]]; then
    echo "${YELLOW}⚠️  Uncommitted changes detected!${RESET}"
    echo "${RED}⏳ 5s to cancel...${RESET}"
    sleep 5
  fi

  #################### 🔄 GIT PULL ####################
  console-log "\n${BOLD}${BLUE}⬇️  Pulling latest changes...${RESET}"
  if ! run_with_log git pull --rebase; then
    exit_code=1; return $exit_code
  fi

  #################### 📝 EDIT CONFIG ####################
  if [[ "$start_editor" == "true" ]]; then
    console-log "\n${BOLD}${BLUE}📝 Editing configuration...${RESET}"
    console-log "Started editing: $(date)"
    run_with_log $editor_cmd
    console-log "Finished editing: $(date)"
  fi

  #################### 🎨 FORMAT ####################
  if [[ "$enable_formatting" == "true" ]]; then
    console-log "\n${BOLD}${MAGENTA}🎨 Running formatter...${RESET}"
    run_with_log $formatter_cmd .
  fi

  #################### 🧾 GIT DIFF ####################
  console-log "\n${BOLD}${CYAN}🔍 Changes summary:${RESET}"
  run_with_log git diff --compact-summary

  #################### 🛠️ SYSTEM REBUILD ####################
  console-log "\n${BOLD}${BLUE}🔧 Starting system rebuild...${RESET}"
  print_line
  console-log "🛠️  Removing old HM conf "
  run_with_log find ~ -type f -name '*delme-HMbackup' -exec rm -v {} +
  print_line
  ### Sudo session ticket:
  console-log "Getting an \`sudo\`-\"Ticket\" to use \`nixos-rebuild\` with \"nom\" "
  console-log "please enter your sudo credentials:"
  run_with_log sudo whoami > /dev/null
  ### Now rebuils_  
  print_line
  console-log "🛠️  Rebuild started: $(date)"
  print_line

  run_with_log_rebuild sudo nixos-rebuild switch --flake "$nix_dir"
  local rebuild_status=$?

  if [[ $rebuild_status -ne 0 ]]; then
    #console-log "\n${BOLD}${RED}❌ Rebuild failed at $(date). Showing errors:${RESET}"
    echo "${RED}❌ Rebuild failed at $(date).${RESET}" > "$error_log"
    stats_errors=$(grep -Ei -A 1 'error|failed' "$build_log" | tee -a "$error_log" | wc -l)
    stats_last_error_lines=$(tail -n 10 "$error_log")
    finish_nyx_rebuild | tee -a "$error_log"

    git add "$log_dir"
    git commit -m "Rebuild failed: errors logged"
    if [[ "$auto_push" == "true" ]]; then
      run_with_log git push && console-log "${GREEN}✅ Error log pushed to remote.${RESET}"
    fi
    exit_code=1
    return $exit_code
  fi

  #################### ✅ SUCCESS FLOW ####################
  rebuild_success=true
  exit_code=0
  

  gen=$(nixos-rebuild list-generations | grep True | awk '{$1=$1};1')
  stats_gen=$(echo "$gen" | awk '{printf "%04d\n", $1}')
  finish_nyx_rebuild >> $build_log
 
  git add -u
  if ! git diff --cached --quiet; then
    git commit -m "Rebuild: $gen"
    console-log "${BLUE}🔧 Commit message:${RESET}\n${GREEN}Rebuild: $gen${RESET}"
  fi

  local final_log="$log_dir/nixos-gen_${stats_gen}-switch-${timestamp}.log"
  mv "$build_log" "$final_log"
  git add "$final_log"

  if ! git diff --cached --quiet; then
    git commit -m "log for $gen"
    echo "${YELLOW}ℹ️  Added changes to git${RESET}"
  else
    echo "${YELLOW}ℹ️  No changes in logs to commit.${RESET}"
  fi

  if [[ "$auto_push" == "true" ]]; then
    git push && echo "${GREEN}✅ Changes pushed to remote.${RESET}"
  fi

  echo "\n${GREEN}🎉 Nyx rebuild completed successfully!${RESET}"
  finish_nyx_rebuild
  #return $exit_code

}
