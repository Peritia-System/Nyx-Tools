########################################################################
# CONFIGURATION
########################################################################
#echo "Debug - logging.sh loaded"


setup_logging_vars () {
    local verbosity=${1:-3}  # Default to max verbosity if not provided
    NYX_VERBOSITY=$verbosity
    log_to_file_disable
}
setup_logging_basic () {

    log_info "Log set to $NYX_VERBOSITY"
    # Default log directory
    log_info "Setting up LogDir in $log_subdir"
    mkdir -p "$log_subdir"

    logPath="$log_subdir/log_$(date '+%Y-%m-%d_%H-%M-%S').log"
    log_info "Full log is saved under $logPath"
}


########################################################################
# Control whether logs are written to file
########################################################################
log_to_file_enable () {
    if [[ "$log_to_file" == "true" ]]; then
        log_debug_info "log_to_file is already true"
        log_debug_warn "log_to_file is $log_to_file"
    else
        log_to_file=true
        log_verbose_warn "log_to_file is enabled"
        log_debug_warn "log_to_file is $log_to_file"
    fi
}

log_to_file_disable () {
    if [[ "$log_to_file" == "true" ]]; then
        log_to_file=false
        log_verbose_warn "log_to_file is disabled"
        log_debug_warn "log_to_file is $log_to_file"
    else
        log_debug_info "log_to_file is already false"
        log_debug_warn "log_to_file is $log_to_file"
    fi
}


########################################################################
# Write a log line to the file
########################################################################
write_log() {
    local line="$1"
    echo "$line" >> "$logPath"
}

########################################################################
# Output with timestamp, level, color, and verbosity
########################################################################
tell_out() {
    local message="$1"
    local level="${2:-INFO}"         # Default level: INFO
    local verbosity_level="${3:-1}"  # Default verbosity level for message
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Append diagnostic info for errors
    if [[ "$level" == "ERROR" ]]; then
        tell_out "$message # $(what_messed_up)" "DEBUG" "3"
    fi

    # Fixed width for level display
    local level_fmt
    local pad
    pad=$(( (7 - ${#level}) / 2 ))
    printf -v level_fmt "%*s%s%*s" $pad "" "$level" $((7 - pad - ${#level})) ""

    local log_line="[$timestamp] [${level_fmt}]  $message"
    local line=" [${level_fmt}]  $message"

    # Only output messages if verbosity level is sufficient
    if [[ $NYX_VERBOSITY -ge $verbosity_level ]]; then
        case "$level" in
            INFO)  echo -e "\033[0;37m$line\033[0m" ;; # Gray
            OK)    echo -e "\033[0;32m$line\033[0m" ;; # Green
            WARN)  echo -e "\033[1;33m$line\033[0m" ;; # Yellow
            ERROR) echo -e "\033[0;31m$line\033[0m" ;; # Red
            CMD)   echo -e "\033[0;36m$line\033[0m" ;; # Cyan
            OTHER) echo -e "\033[0;35m$line\033[0m" ;; # Magenta
            LINE)  echo -e "\033[1;30m$line\033[0m" ;; # Dark Gray
            *)     echo -e "$line" ;;                  # Default no color
        esac
    fi

    # Always write to log file if enabled
    if [[ "$log_to_file" == "true" ]]; then
        write_log "$log_line"
    fi
}



########################################################################
# Separator line for logs
########################################################################
log_separator() {
    local verbosity="${1:-0}"
    tell_out "===========================================" "LINE" $verbosity
}

########################################################################
# Execute a command with logging and error handling
########################################################################
execute() {
    local command="$1"
    local cmd_verbosity="${2:-2}"

    tell_out "Executing: $command" "CMD" "$cmd_verbosity"
    tell_out "### Log from $command start ###" "CMD" "$cmd_verbosity"
    log_separator "$cmd_verbosity"

    # Use a subshell and a pipe to tee both stdout and stderr to the log
    # while preserving the exit code
    local status
    {
        # Redirect stderr to stdout so both are captured
        eval "$command" 2>&1 | while IFS= read -r line; do
            tell_out "$line" "CMD" "$cmd_verbosity"
        done
    }
    status=${PIPESTATUS[0]}  # Capture exit code of eval, not the while loop

    log_separator "$cmd_verbosity"

    tell_out "### Log from $command end ###" "CMD" "$cmd_verbosity"

    # Log success or failure
    if (( status == 0 )); then
        tell_out "Execution successful: $command" "OK" "$cmd_verbosity"
    else
        tell_out "Error executing command: $command (exit code $status)" "ERROR" 0
    fi

    return $status
}

########################################################################
# Call stack helper for debugging
########################################################################
what_messed_up() {
    local stack=("${FUNCNAME[@]}")
    local call_chain=""
    #unset 'stack[0]'   # remove current function
    #unset 'stack[1]'   # remove direct caller (log_error etc.)
    #unset 'stack[-1]'  # remove "main"

    # Join the remaining stack elements with " -> "
    for function in "${stack[@]}"; do
        if [[ -z "$call_chain" ]]; then
            call_chain="$function"
        else
            call_chain="$call_chain -> $function"
        fi
    done

    echo "$call_chain"
}



########################################################################
# Verbosity helper functions
########################################################################
log_debug_info()        { tell_out "$1" "INFO"   3; }
log_debug_warn()        { tell_out "$1" "WARN"   3; }
log_debug_ok()          { tell_out "$1" "OK"     3; }
log_debug_error()       { tell_out "$1" "ERROR"  3; }


log_verbose_ok ()       { tell_out "$1" "OK" 2; }
log_verbose_info ()     { tell_out "$1" "INFO" 2; }
log_verbose_warn ()     { tell_out "$1" "WARN" 2; }
log_verbose_error ()    { tell_out "$1" "ERROR" 2; }
log_verbose_end ()      { tell_out "$1" "END" 2; }

log_ok()                { tell_out "$1" "OK" 1; }
log_info()              { tell_out "$1" "INFO" 1; }
log_warn()              { tell_out "$1" "WARN" 1; }
log_error()             { tell_out "$1" "ERROR" 0; }
log_end()               { tell_out "$1" "END" 0; }

########################################################################
# USAGE SUMMARY
#
########################################################################
# LOGGING FUNCTIONS
########################################################################
#   log_debug_* "Message"        # with variations
#   log_verbose "Message"        # Shown at verbosity 2+
#   log_info "Message"           # Standard info message (verbosity 1+)
#   log_warn "Message"           # Warning message (verbosity 1+)
#   log_error "Message"          # Error message (always shown)
#
#   log_to_file_enable           # Enable writing all logs to $logPath
#   log_to_file_disable          # Disable log file writing
#
########################################################################
