#echo "Debug - sudo.sh loaded"


check_if_run_with_sudo() {
    log_debug_info "Checking if the script is being run with sudo or as root..."

    # Check if running as root
    if [[ "$EUID" -eq 0 ]]; then
        log_error "This script must NOT be run as root or with sudo."
        log_debug_error "Detected EUID=0 (root). Please run as a normal user."
        exit 1
    fi

    # Check if running through sudo
    if [[ -n "$SUDO_USER" ]]; then
        log_error "This script must NOT be run with sudo."
        log_debug_error "Detected SUDO_USER='$SUDO_USER'. Run without sudo."
        exit 1
    fi

    log_verbose_ok "Sudo/root check passed. Running as a normal user: $USER"
    return 0
}

get_sudo_ticket() {
    log_verbose_info "Checking if sudo rights are already available..."

    # Check if sudo permissions are currently active
    if sudo -n true 2>/dev/null; then
        log_verbose_ok "Sudo rights are already active. No password required."
        return 0
    fi

    log_info "Sudo permissions required. Prompting for password..."
    
    # Attempt to refresh or request sudo credentials
    if sudo -v; then
        log_ok "Sudo rights successfully acquired."
        return 0
    else
        log_error "Failed to acquire sudo permissions. Incorrect password or sudo not available."
        return 1
    fi
}

########################################################################
#
# Sudo/Root Handling Functions:
#   check_if_run_with_sudo
#       - Exits if the script is run as root or with sudo.
#
#   get_sudo_ticket
#       - Checks if sudo permissions are cached.
#       - If not, prompts for password to acquire them.
#
########################################################################