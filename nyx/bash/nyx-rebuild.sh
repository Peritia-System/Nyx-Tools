#!/usr/bin/env bash

########################################################################
# CONFIGURATION
########################################################################
flake_directory="@FLAKE_DIRECTORY@"
log_dir="@LOG_DIR@"
enable_formatting="@ENABLE_FORMATTING@"
formatter_cmd="@FORMATTER@"
git_bin="@GIT_BIN@"
nom_bin="@NOM_BIN@"
auto_stage="@AUTO_STAGE@"
auto_commit="@AUTO_COMMIT@"
auto_push="@AUTO_PUSH@"
auto_repair=true
version="@VERSION@"
rebuild_success=false
nixos_generation=""
git_starting_commit=""

debug_print_vars () {
    log_debug_info "###### Debug - Vars ######"
    log_debug_info "main() started with action: $rebuild_action, verbosity: $NYX_VERBOSITY"
    log_debug_info "FLAKE_DIRECTORY: $flake_directory"
    log_debug_info "LOG_DIR: $log_dir"
    log_debug_info "ENABLE_FORMATTING: $enable_formatting"
    log_debug_info "FORMATTER: $formatter_cmd"
    log_debug_info "GIT_BIN: $git_bin"
    log_debug_info "NOM_BIN: $nom_bin"
    log_debug_info "AUTO_STAGE: $auto_stage"
    log_debug_info "AUTO_COMMIT: $auto_commit"
    log_debug_info "AUTO_PUSH: $auto_push"
    log_debug_info "VERSION: $version"
    log_debug_info "###### Debug - Vars ######"
}



########################################################################
# FORMATTER
########################################################################
run_formatter() {
    if [[ "$enable_formatting" == "true" ]]; then
        log_info "Running formatter..."
        execute "$formatter_cmd ." "2"
        git_add $flake_directory
        git_commit "Formatted by $formatter_cmd"
    fi
}


########################################################################
# Repair
########################################################################
repair_waited_before=false
repair_wait_time=3

repair_wait () {
    if [[ "$auto_repair" == "true" ]]; then
        if [[ "$repair_waited_before" == "true" ]]; then
            log_debug_info "Waited before so it will start the repair"
        else 
            log_warn "Will repair in $repair_wait_time seconds"
            log_warn "Use \"CTRL + C\" to cancel if you don't want that"
            for (( waited_time=1; waited_time<=repair_wait_time; waited_time++ )); do
                log_info "Will repair in $((repair_wait_time - waited_time + 1))..."
                sleep 1
            done
            log_warn "Start Repair"
            repair_waited_before=true
        fi
    fi
}


check_and_repair () {

   if git_check_has_staged_files; then
        log_warn "Repo has uncommitted files"
        log_debug_info "auto_commit is $auto_commit"
        if [[ "$auto_repair" == "true" ]]; then
            log_info "Starting Repair Uncommitted"
            if repair_uncommitted; then
                log_debug_ok "repair_uncommitted Returned 0 (success)"
            else 
                log_error "I have no Idea but it has sth to do with git_check_has_staged_files in nyx-rebuild.sh"
                FATAL
            fi
        else 
            log_error "Due to auto_repair being $auto_repair repair not attempted"
            log_error "Commit your staged commits or enable \$auto_repair"
            FATAL
        fi
    fi


   if git_check_has_unstaged_files ; then
        log_warn "Repo has unstaged files"
        log_debug_warn "auto_stage is $auto_stage"
        if [[ "$auto_repair" == "true" ]]; then
            log_info "Starting Repair unstaged"
            if repair_unstaged; then
                log_debug_ok "repair_unstaged Returned 0 (success)"
            else 
                log_error "I have no Idea but it has sth to do with git_check_has_unstaged_files in nyx-rebuild.sh"
            fi
        else 
            log_error "Due to auto_repair being $auto_repair repair not attempted"
            log_error "Stage your unstaged files or enable \$auto_repair"
            FATAL 
        fi
    fi

}

repair_unstaged () {
    repair_wait
    if [[ "$auto_repair" == "true" ]]; then
        if [[ "$auto_stage" == "true" ]]; then
            log_debug_info "Will attempt to stage files"
            git_add $flake_directory
            log_info "Added unstaged files"
            repair_uncommitted
            return 0
        else 
            log_error "Due to autoStage being disabled repair not attempted"
            log_debug_error "Due to auto_stage being $auto_stage repair not attempted"
            log_error "Stage your unstaged files or enable autoStage"
            FATAL
        fi
    else 
        log_error "This shouldn't exist #repair_unstaged"
        return 1
    fi

}

repair_uncommitted () {
    repair_wait
    if [[ "$auto_repair" == "true" ]]; then
        if [[ "$auto_commit" == "true" ]]; then
            log_debug_info "Will attempt to commit"
            git_commit "Auto repair commit - $(date '+%Y-%m-%d_%H-%M-%S')"
            log_info "Repaired uncommitted changes"
            return 0
        else 
            log_error "Due to autoCommit being disabled repair not attempted"
            log_debug_error "Due to auto_commit being $auto_commit repair not attempted"
            log_error "Commit your staged commits or enable autoCommit"
            FATAL
        fi
    else 
        log_error "This shouldn't exist #repair_uncommitted"
        return 1
    fi

} 



########################################################################
# SUDO HANDLING
########################################################################
ensure_sudo() {
    get_sudo_ticket
}

########################################################################
# NIXOS REBUILD
########################################################################
run_nixos_rebuild() {
    local tmp_log tmp_status status
    tmp_log=$(mktemp /tmp/nyx-tmp-log.XXXXXX)
    tmp_status=$(mktemp /tmp/nyx-status.XXXXXX)

    log_debug_info "Running nixos-rebuild command: $*"
    log_debug_info "Build log: $build_log"
    log_debug_info "Error log: $error_log"
    log_debug_info "Using nom binary: $nom_bin"
    log_debug_info "Temp log: $tmp_log"
    log_debug_info "Temp status file: $tmp_status"

    set -o pipefail
    (
        "$@" 2>&1
        echo $? > "$tmp_status"
    ) | tee -a "$tmp_log" | "$nom_bin"

    status=$(<"$tmp_status")
    execute "rm -f '$tmp_status'"  "2"

    log_debug_info "Exit code: $status"

    if [[ $status -eq 0 ]]; then
        if grep -Ei -A1 'error|failed' "$tmp_log" >/dev/null; then
            log_error "Build reported errors despite successful exit code"
            rebuild_success=false
            execute "cp '$tmp_log' '$error_log'" "2"
        else
            log_ok "Build succeeded"
            rebuild_success=true
            execute "cp '$tmp_log' '$build_log'" "2"
            # Populate generation number for finish_rebuild
            nixos_generation=$(nixos-rebuild list-generations | grep True | awk '{print $1}')
        fi
    else
        if grep -Ei -A1 'error|failed' "$tmp_log" >/dev/null; then
            log_error "Build failed with exit code $status"
            rebuild_success=false
            execute "cp '$tmp_log' '$error_log'" "2"
        else
            log_error "Build exited with $status but no explicit error lines found"
            rebuild_success=false
            execute "cp '$tmp_log' '$error_log'" "2"
        fi
    fi

    # Send output line by line
    while IFS= read -r line; do
        tell_out "$line" "CMD" 2
    done < "$tmp_log"

    execute "rm -f '$tmp_log'" "2"
    return "$status"
}





########################################################################
# MAIN REBUILD PROCESS
########################################################################
nyx_rebuild() {
    start_time=$(date +%s)
    rebuild_success=false
    git_store_starting_commit
    cd "$flake_directory" || {
        log_error "Could not change directory to $flake_directory"
        return 1
    }

    # Ensure we are inside a git repo before proceeding
    if git_check_if_dir_is_in_repo "$flake_directory"; then
        log_debug_info "Passed Git repo check"
    else
        log_error "Git repo not detected. Aborting rebuild"
        return 1
    fi

    check_and_repair
    git_pull_rebase

    log_to_file_enable
    run_formatter

    log_separator
    log_info "Rebuild started: $(date)"
    log_separator

    ensure_sudo

    run_nixos_rebuild sudo nixos-rebuild "$rebuild_action" --flake "$flake_directory"
    local rebuild_status=$?

    finish_rebuild "$start_time" >/dev/null 2>&1

    # Only stage/commit logs if rebuild succeeded
    if [[ "$rebuild_success" == true ]]; then
        logs_stage_and_commit "Rebuild '$rebuild_action' completed successfully"
    else
        log_error "Rebuild failed"
        git_reset "soft" "$git_starting_commit"
        logs_stage_and_commit "Error: Rebuild Failed"
        finish_rebuild "$start_time"
        trap - EXIT
        log_debug_info "EXIT trap removed"
        exit 1
    fi

    return $rebuild_status
}


########################################################################
# FINISH
########################################################################
finish_rebuild() {
    local start_time=$1
    local duration=$(( $(date +%s) - start_time ))

    # Build failure notes from grep output (one per line)
    if [[ "$rebuild_success" != true ]]; then
        finish_failure_notes=""
        if [[ -f "$error_log" ]]; then
            while IFS= read -r line; do
                finish_failure_notes+=$'\n'"  $line"
            done < <(grep -Ei -A1 'error|failed' "$error_log" | tee -a "$error_log" || true)
        fi
    fi

    log_separator
    if [[ "$rebuild_success" == true ]]; then
        log_end "###############################################"
        log_end "          Nyx-Rebuild Completed Successfully"
        log_end "###############################################"
        log_end "Action:           $rebuild_action"
        log_end "Flake:            $flake_directory"
        log_end "Result:           Build succeeded"
        log_end "Duration:         ${duration}s"
        log_end "System Generation: $nixos_generation"
        [[ -n "$finish_success_notes" ]] && log_end "Notes: $finish_success_notes"
        log_end "Build log:        $build_log"
        log_end "###############################################"
    else
        log_end "###############################################"
        log_end "          Nyx-Rebuild Failed"
        log_end "###############################################"
        log_end "Action:           $rebuild_action"
        log_end "Flake:            $flake_directory"
        log_end "Result:           Build failed"
        log_end "Duration:         ${duration}s"
        log_end "System Generation: $nixos_generation"
        if [[ -n "$finish_failure_notes" ]]; then
            log_end "Notes:"
            while IFS= read -r note; do
                log_end "$note"
            done <<< "$finish_failure_notes"
        fi
        log_end "Error log:        $error_log"
        log_end "###############################################"
    fi
    log_separator
}


logs_stage_and_commit() {
    log_debug_info "logs_stage_and_commit called and is disabling the Logs to Push them"
    log_to_file_disable
    local message="$1"
    git_add "Logs"
    git_commit "$message"
    git_push
}





########################################################################
# helper:
########################################################################

interpret_flags() {
    local opt
    local verbosity=1
    local action=""

    # Reset OPTIND to handle multiple calls in same shell
    OPTIND=1

    while getopts ":hv:" opt; do
        case "$opt" in
            h)
                print_help
                exit 0
                ;;
            v)
                if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
                    verbosity="$OPTARG"
                else
                    echo "Invalid verbosity level: $OPTARG" >&2
                    exit 1
                fi
                ;;
            :)
                echo "Option -$OPTARG requires an argument" >&2
                exit 1
                ;;
            \?)
                echo "Unknown option: -$OPTARG" >&2
                exit 1
                ;;
        esac
    done

    shift $((OPTIND - 1))

    # First positional arg after options = action
    if [[ $# -gt 0 ]]; then
        action="$1"
        shift
    else
        action="test"
    fi

    rebuild_action="$action"
    NYX_VERBOSITY="$verbosity"

    # Any extra args after action can be captured if needed
    remaining_args=("$@")
}


print_help() {
    cat <<EOF
Usage: $(basename "$0") [ACTION] [OPTIONS]

Run a nixos-rebuild action with optional verbosity.

Actions:
  switch      Build and switch to new configuration
  boot        Build and make available for next boot
  test        Build and switch without updating bootloader (default)

Options:
  -v N        Set verbosity level (default: 1)
  -h, --help  Show this help message and exit

Examples:
  $(basename "$0") switch -v 3
  $(basename "$0") boot
  $(basename "$0")       # runs 'test' with default verbosity
EOF
}




########################################################################
# Setup
########################################################################


setup_nyxrebuild_vars () {
    if [[ "$auto_repair" == "true" ]]; then
        # Enforce dependencies between flags
        if [[ "$auto_stage" != "true" ]]; then
            log_warn "autoStage is disabled"
            log_debug_warn "auto_stage is $auto_stage"
            auto_repair=false
            log_warn "Disabling autoRepair"
            log_debug_warn "Setting auto_repair to $auto_repair"
            log_warn "Please enable autoStage if you want to use this feature"
        fi
        if [[ "$auto_commit" != "true" ]]; then
            log_warn "autoCommit is disabled"
            log_debug_warn "auto_commit is $auto_commit"
            auto_repair=false
            log_warn "Disabling autoRepair"
            log_debug_warn "Setting auto_repair to $auto_repair"
            log_warn "Please enable autoCommit if you want to use this feature"
        fi
     
        #if [[ "$auto_push" != "true" ]]; then
        #    log_warn "autoPush is disabled"
        #    log_debug_warn "auto_push is $auto_push"
        #    auto_push=false
        #    log_warn "Disabling autoRepair"
        #    log_debug_warn "Setting auto_repair to $auto_repair"
        #    log_warn "Please enable autoPush if you want to use this feature"
        #fi
    fi

    if [[ "$enable_formatting" == "true" ]]; then
         # Enforce dependencies between flags
        if [[ "$auto_stage" != "true" ]]; then
            log_warn "autoStage is disabled"
            log_debug_warn "auto_stage is $auto_stage"
            enable_formatting=false
            log_warn "Disabling enableFormatting"
            log_debug_warn "Setting enable_formatting to $enable_formatting"
            log_warn "Please enable autoStage if you want to use this feature"
        fi

        if [[ "$auto_commit" != "true" ]]; then
            log_warn "autoCommit is disabled"
            log_debug_warn "auto_commit is $auto_commit"
            enable_formatting=false
            log_warn "Disabling enableFormatting"
            log_debug_warn "Setting enable_formatting to $enable_formatting"
            log_warn "Please enable autoCommit if you want to use this feature"
        fi
        
        #if [[ "$auto_push" != "true" ]]; then
        #    log_warn "autoPush is disabled"
        #    log_debug_warn "auto_push is $auto_push"
        #    enable_formatting=false
        #    log_warn "Disabling enableFormatting"
        #    log_debug_warn "Setting enable_formatting to $enable_formatting"
        #    log_warn "Please enable autoPush if you want to use this feature"
        #fi
    fi

}

FATAL() {
    log_error "nyx-rebuild encountered a fatal error"
    log_error "Script ended due to error. Check $logPath"

    if [[ -n "$git_starting_commit" ]]; then
        log_error "Resetting repository to starting commit: $git_starting_commit"
        if git_reset "soft" "$git_starting_commit"; then
            log_ok "Repository successfully reset to starting commit"
        else
            log_error "Failed to reset repository to starting commit"
        fi
    else
        log_warn "No starting commit stored, cannot reset repository"
    fi

    log_debug_error "Last called function: $(what_messed_up)"
    log_error "If this is a bug in nyx-rebuild, open an issue and include logs"

    exit 1
}

trap_on_exit() {
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log_debug_ok "Script completed successfully (exit code 0)"
        finish_rebuild "$start_time"

    else
        log_error "Script exited with error (exit code $exit_code)"
        # Only run FATAL if we are not already inside it
        if [[ "${FUNCNAME[1]}" != "FATAL" ]]; then
            FATAL
        fi
    fi
}

########################################################################
# ENTRY POINT
########################################################################
main () {
    rebuild_action="$1"

    #interpret_flags "$@"
    
    nyx-tool "Nyx" "nyx-rebuild" "$version" \
        "Smart NixOS configuration rebuilder" \
        "by Peritia-System" \
        "https://github.com/Peritia-System/Nyx-Tools" \
        "https://github.com/Peritia-System/Nyx-Tools/issues" \
        "Always up to date for you!"

        
    

    # to do make this a flag: verbosity
    local verbosity=1

    #source all the files - generated by the .nix file
    source_all

    # the interger decides verbosity level
    setup_logging_vars $verbosity


    # From now on Logging functions can safely be called:
    log_debug_info "Checking that script is NOT run with sudo..."
    check_if_run_with_sudo

    # Logging stuff
    log_debug_info "Initializing logging..."
    log_subdir="${log_dir}/rebuild"
    mkdir -p "$log_subdir"
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')

    # lib/logging.sh
    log_debug_info "Setting up basic logging (directories, log file)..."
    setup_logging_basic

    build_log="${logPath%.log}-rebuild.log"
    error_log="${logPath%.log}-Current-Error.txt"


    # lib/git.sh
    log_debug_info "Configuring git-related variables..."
    setup_git_vars

    log_debug_info "Configuring nyx-rebuild variables..."
    setup_nyxrebuild_vars


    debug_print_vars
    trap trap_on_exit EXIT
    nyx_rebuild "$rebuild_action"
}


main "$@"