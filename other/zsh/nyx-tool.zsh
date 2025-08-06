#!/usr/bin/env zsh

# nyx-tool: reusable metadata banner printer with Base16 theme
function nyx-tool() {
  local logo="${1:-Nyx}"
  local name="${2:-nix-script}"
  local version="${3:-Version Unknown - Please Open Issue}"             
  local description="${4:-A Nix utility}"
  local credit="${5:-Peritia-System}"
  local github="${6:-https://github.com/example/repo}"
  local issues="${7:-${github}/issues}"
  local message="${8:-Use responsibly}"

  # Base16 color palette (using tput for portability or ANSI codes)
  local RESET="\033[0m"
  local BOLD="\033[1m"
  local HEADER="\033[38;5;33m"    # Approx base0D (blue)
  local LABEL="\033[38;5;70m"     # Approx base0B (green)
  local VALUE="\033[38;5;250m"    # Approx base05 (gray)
  local EMPHASIS="\033[38;5;196m" # Approx base08 (red)

  local line
  line=$(printf '=%.0s' {1..35})

  echo ""
  echo -e "${HEADER}${line}${RESET}"
  echo -e "${HEADER}=====[ ${BOLD}Peritia System Tools${RESET}${HEADER} ]=====${RESET}"
  echo -e "
  ${VALUE}${BOLD}

$(figlet -f banner3 "${logo}" | sed 's/#/█/g')  ${RESET}${HEADER}by Peritia-System${RESET}

  ${RESET}"

  #cat ../Logo-68px.txt

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

nyx-show_spinner() {
  local pid=$1
  local spinner_delay=0.1
  local spinstr='|/-\'
  local start_time=$(date +%s%3N)

  echo -ne "${CYAN}⏳ Starting rebuild...${RESET} "

  (
    while kill -0 "$pid" 2>/dev/null; do
      local now=$(date +%s%3N)
      local elapsed=$((now - start_time))
      local seconds=$((elapsed / 1000))
      local milliseconds=$((elapsed % 1000))
      local clock_time=$(date +%T)  # format: HH:MM:SS

      for i in $(seq 0 3); do
        printf "\r${CYAN}⏳ [%s] %s [%d.%03ds] ${RESET}" "$clock_time" "${spinstr:$i:1}" "$seconds" "$milliseconds"
        sleep $spinner_delay
      done
    done
  ) &
  local spinner_pid=$!

  # Wait for the main process
  wait "$pid"
  local exit_status=$?

  # Kill spinner and wait
  kill "$spinner_pid" 2>/dev/null
  wait "$spinner_pid" 2>/dev/null

  local end_time=$(date +%s%3N)
  local total_elapsed=$((end_time - start_time))
  local total_sec=$((total_elapsed / 1000))
  local total_ms=$((total_elapsed % 1000))
  local end_clock_time=$(date +%T)

  echo -e "\r${GREEN}✅ Completed at ${end_clock_time}, total: ${total_sec}.${total_ms}s${RESET}           "

  return $exit_status
}
