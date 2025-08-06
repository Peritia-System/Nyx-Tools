#!/usr/bin/env bash

# nyx-tool: reusable metadata banner printer with Base16 theme
nyx-tool() {
  local logo="${1:-Nyx}"
  local name="${2:-nix-script}"
  local version="${3:-Version Unknown - Please Open Issue}"             
  local description="${4:-A Nix utility}"
  local credit="${5:-Peritia-System}"
  local github="${6:-https://github.com/example/repo}"
  local issues="${7:-${github}/issues}"
  local message="${8:-Use responsibly}"

  # Base16 color palette (ANSI escape codes)
  local RESET="\033[0m"
  local BOLD="\033[1m"
  local HEADER="\033[38;5;33m"    # blue
  local LABEL="\033[38;5;70m"     # green
  local VALUE="\033[38;5;250m"    # gray
  local EMPHASIS="\033[38;5;196m" # red
  local CYAN="\033[38;5;51m"
  local GREEN="\033[38;5;82m"

  local line
  line=$(printf '=%.0s' $(seq 1 35))

  echo ""
  echo -e "${HEADER}${line}${RESET}"
  echo -e "${HEADER}=====[ ${BOLD}Peritia System Tools${RESET}${HEADER} ]=====${RESET}"
  echo -e "${VALUE}${BOLD}"

  # Figlet logo rendering
  if command -v figlet &>/dev/null; then
    figlet -f banner3 "$logo" | sed 's/#/█/g'
  else
    echo "$logo"
  fi

  echo -e "${RESET}${HEADER}by Peritia-System${RESET}"
  echo -e "${HEADER}${line}${RESET}"
  echo ""

  echo -e "${LABEL}🛠️ Name:          ${VALUE}${name}${RESET}"
  echo -e "${LABEL}🏷️ Version:       ${VALUE}${version}${RESET}"   
  echo -e "${LABEL}📝 Description:   ${VALUE}${description}${RESET}"
  echo -e "${LABEL}👤 Credit:        ${VALUE}${credit}${RESET}"
  echo -e "${LABEL}🌐 GitHub:        ${VALUE}${github}${RESET}"
  echo -e "${LABEL}🐛 Issues:        ${VALUE}${issues}${RESET}"
  echo ""
  echo -e "${LABEL}📌 Message:       ${BOLD}${message}${RESET}"
  echo ""
}

# Spinner with timing
nyx-show_spinner() {
  local pid=$1
  local spinner_delay=0.1
  local spinstr='|/-\'
  local start_time
  start_time=$(date +%s%3N)

  local CYAN="\033[38;5;51m"
  local GREEN="\033[38;5;82m"
  local RESET="\033[0m"

  echo -ne "${CYAN}⏳ Starting rebuild...${RESET} "

  (
    while kill -0 "$pid" 2>/dev/null; do
      local now elapsed seconds milliseconds clock_time
      now=$(date +%s%3N)
      elapsed=$((now - start_time))
      seconds=$((elapsed / 1000))
      milliseconds=$((elapsed % 1000))
      clock_time=$(date +%T)

      for i in $(seq 0 3); do
        printf "\r${CYAN}⏳ [%s] %s [%d.%03ds] ${RESET}" "$clock_time" "${spinstr:$i:1}" "$seconds" "$milliseconds"
        sleep "$spinner_delay"
      done
    done
  ) &
  local spinner_pid=$!

  wait "$pid"
  local exit_status=$?

  kill "$spinner_pid" 2>/dev/null
  wait "$spinner_pid" 2>/dev/null

  local end_time total_elapsed total_sec total_ms end_clock_time
  end_time=$(date +%s%3N)
  total_elapsed=$((end_time - start_time))
  total_sec=$((total_elapsed / 1000))
  total_ms=$((total_elapsed % 1000))
  end_clock_time=$(date +%T)

  echo -e "\r${GREEN}✅ Completed at ${end_clock_time}, total: ${total_sec}.${total_ms}s${RESET}           "

  return $exit_status
}
