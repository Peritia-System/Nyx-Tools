########################################################################
# Default Variables
########################################################################
#echo "Debug - git.sh loaded"
setup_git_vars () {
    # Enforce dependencies between flags
    if [[ "$auto_commit" == "true" ]]; then
        if [[ "$auto_stage" != "true" ]]; then
            log_warn "autoStage is disabled"
            log_debug_warn "auto_stage is $auto_stage"
            auto_commit=false
            log_warn "Disabling autoCommit"
            log_debug_warn "Setting auto_commit to $auto_commit"
            log_warn "Please enable autoStage if you want to use this feature"
        fi
    fi
    if [[ "$auto_push" == "true" ]]; then
        if [[ "$auto_commit" != "true" ]]; then
            log_warn "autoCommit is disabled"
            log_debug_warn "auto_stage is $auto_stage"
            auto_push=false
            log_warn "Disabling autoPush"
            log_debug_warn "Setting autoPush to $auto_push"
            log_warn "Please enable autoCommit if you want to use this feature"
        fi
    fi
}



########################################################################
# Git wrapper 
########################################################################
git_wrapped_git() {
    # Local variable for arguments just in case
    local args=("$@")
    "$git_bin" "${args[@]}"
    return $?
}

########################################################################
# Layer 1 - No logs or tell out 
########################################################################
git_add_raw() {
    local file="$1"
    git_wrapped_git add "$file"
    return $?
}

git_commit_raw() {
    local message="$1"
    git_wrapped_git commit -m "$message"
    return $?
}

git_push_raw() {
    git_wrapped_git push
    return $?
}

git_pull_rebase_raw() {
    git_wrapped_git pull --rebase
    return $?
}
git_pull_raw() {
    git_wrapped_git --rebase
    return $?
}

git_reset_raw() {
    local mode="${1:-soft}"   # default mode: soft
    local target="${2:-HEAD}"  # default reset target: HEAD
    git_wrapped_git reset "--$mode" "$target"
    return $?
}



########################################################################
# Layer 2 - Logs or Tell out  - Mainly Debug Logs
########################################################################

git_check_autoStage_enabled () {
    if [[ "$auto_stage" == "true" ]]; then
        log_debug_info "Auto Stage is enabled will execute function further"
        return 0
    else
        log_debug_warn "Auto Stage is disabled will not execute function further"
        return 1
    fi
}


git_check_if_file_stage_valid () {
    local file="$1"
    # note file can also be a folder it was just easier
    if [[ -e "$file" ]]; then
        log_debug_ok "found file $file"
        # check if the file has changes
        if git_wrapped_git diff -- "$file" | grep -q .; then
            log_debug_ok "file $file has changes"
            return 0
        else
            log_debug_warn "file $file has no changes and will be skipped"
            return 1
        fi
    else
        log_debug_error "Did not find file $file."
        return 1
    fi
}

git_check_autoCommit_enabled () {
    if [[ "$auto_commit" == "true" ]]; then
        log_debug_info "Auto Commit is enabled will execute function further"
        return 0
    else
        log_debug_warn "Auto Commit is disabled will not execute function further"
        return 1
    fi
}

git_check_has_staged_files() {
    local staged_files
    # git diff --cached --name-only lists staged files
    # If no output, there are no staged files to commit
    staged_files=$(git_wrapped_git diff --cached --name-only)
    if [[ -n "$staged_files" ]]; then
        log_debug_ok "Found staged files to commit"
        log_debug_info "Staged files:"
        log_debug_info "$staged_files"
        return 0
    else
        log_debug_warn "No staged files found"
        return 1
    fi
}

git_check_autoPush_enabled () {
    if [[ "$auto_push" == "true" ]]; then
        log_debug_info "Auto Push is enabled will execute function further"
        return 0
    else
        log_debug_warn "Auto Push is disabled will not execute function further"
        return 1
    fi
}



git_check_has_staged_files() {
    local staged_files
    # git diff --cached --name-only lists staged files
    # If no output, there are no staged files to commit
    staged_files=$(git_wrapped_git diff --cached --name-only)
    if [[ -n "$staged_files" ]]; then
        log_debug_warn "Found staged files to commit"
        log_debug_info "Staged files:"
        log_debug_info "$staged_files"
        return 0
    else
        log_debug_ok "No staged files found - Nothing uncommitted"
        return 1
    fi
}

# Returns 0 if there are unstaged
git_check_has_unstaged_files() {
    local unstaged_files
    # git diff --name-only lists unstaged files
    staged_files=$(git_wrapped_git diff --name-only)
    if [[ -n "$staged_files" ]]; then
        log_debug_warn "Unstaged files detected"
        log_debug_info "Unstaged files:"
        log_debug_info "$unstaged_files"
        return 0
    else
        log_debug_warn "No unstaged files"
        return 1
    fi
}


git_check_if_dir_is_in_repo() {
    local file="${1:-.}" # defaults to current dir if no file passed
    if [[ -e "$file" ]]; then
        log_debug_ok "found file $file"
        # note file can also be a folder it was just easier to name it like so
        if git_wrapped_git -C "$file" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            log_debug_ok "file $file is in git repo"
            return 0
        else
            log_debug_error "file $file is not in a git repo"
            return 1
        fi
    else
        log_debug_error "Did not find file $file."
        return 1
    fi
}

git_check_necessary_for_rebase() {
    # Reuse: first check if we are behind upstream
    if ! git_check_if_behind_upstream; then
        log_debug_info "No rebase necessary: branch is not behind upstream"
        return 1
    fi

    local branch ahead behind
    branch=$(git_wrapped_git rev-parse --abbrev-ref HEAD 2>/dev/null)
    ahead=$(git_wrapped_git rev-list --count "@{u}..${branch}")
    behind=$(git_wrapped_git rev-list --count "${branch}..@{u}")

    if [[ $ahead -gt 0 && $behind -gt 0 ]]; then
        log_debug_ok "Branch $branch has diverged (ahead: $ahead, behind: $behind), rebase required"
        return 0
    fi

    log_debug_info "Branch $branch has no divergence (ahead: $ahead, behind: $behind)"
    return 1
}

git_check_if_behind_upstream() {
    # First make sure we are in a git repo
    if ! git_check_if_dir_is_in_repo; then
        log_debug_error "Not inside a git repository"
        return 1
    fi

    # Make sure we have a tracking branch
    if ! git_wrapped_git rev-parse --abbrev-ref "@{u}" >/dev/null 2>&1; then
        log_debug_warn "Current branch has no upstream, cannot check if behind"
        return 1
    fi

    git_wrapped_git fetch --quiet

    local behind_count
    behind_count=$(git_wrapped_git rev-list --count "HEAD..@{u}")

    if [[ "$behind_count" -gt 0 ]]; then
        log_debug_ok "Branch is behind upstream by $behind_count commits"
        return 0
    else
        log_debug_info "Branch is up to date with upstream"
        return 1
    fi
}


########################################################################
# Layer 3 - Logs or Tell out - Also used in Main Script directly
########################################################################

git_add () {
    local file="$1"
    # note file can also be a folder it was just easier
    if git_check_autoStage_enabled; then
        if git_check_if_file_stage_valid "$file"; then
            if git_add_raw "$file"; then
                log_ok "Added file: \"$file\""
                return 0
            else
                log_error "Failed to add file: \"$file\""
                return 1
            fi
        else
            log_verbose_warn "Did not Stage: $file"
            return 1
        fi
    else
        return 1
    fi
}

git_commit () {
    local message="$1"
    if git_check_autoCommit_enabled; then
        if git_check_has_staged_files; then
            if git_commit_raw "$message"; then
                log_ok "Committed with Message: \"$message\""
                return 0
            else
                log_error "Commit failed with Message: \"$message\""
                return 1
            fi
        else
            log_verbose_warn "Nothing to commit. Would've committed with Message: \"$message\""
            return 1
        fi
    else
        return 1
    fi
}

git_push () {
    # Check if auto-push is enabled first
    if git_check_autoPush_enabled; then
        if git_push_raw; then
            log_ok "Pushed to remote successfully"
            return 0
        else
            log_error "Push to remote failed"
            return 1
        fi
    else
        log_verbose_warn "Auto Push disabled, skipping push"
        return 1
    fi
}

git_pull_rebase() {
    
    # check if current dir is in git repo
    if ! git_wrapped_git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_error "Not inside a git repository, cannot pull"
        return 1
    fi

    if git_check_necessary_for_rebase; then
        # Rebase mode: we have local commits and are behind upstream
        if git_wrapped_git pull --rebase; then
            log_ok "Pulled from remote and rebased successfully"
            return 0
        else
            log_error "Pull with rebase failed"
            return 1
        fi
    elif git_check_if_behind_upstream; then
        # Behind but no local commits → simple fast-forward pull
        if git_wrapped_git pull; then
            log_ok "Pulled from remote successfully (fast-forward)"
            return 0
        else
            log_error "Pull from remote failed"
            return 1
        fi
    else
        log_info "Branch is already up to date, no pull required"
        return 0
    fi
}

git_reset() {
    local mode="${1:-soft}"   # default reset mode is soft
    local target="${2:-HEAD}"  # commit hash, branch, or tag

    log_info "Resetting to target: $target (mode: $mode)"
    if git_reset_raw "$mode" "$target"; then
        log_ok "Successfully reset to $target with --$mode"
        return 0
    else
        log_error "Failed to reset to $target"
        return 1
    fi
}


git_store_starting_commit () {
    # Get the current HEAD commit hash
    local commit
    commit=$(git_wrapped_git rev-parse HEAD 2>/dev/null)

    if [[ $? -eq 0 && -n "$commit" ]]; then
        git_starting_commit="$commit"
        log_debug_info "Stored starting commit: $git_starting_commit"
        return 0
    else
        log_debug_error "Unable to retrieve current commit hash"
        return 1
    fi
}

########################################################################
# COMPILED FUNCTION SUMMARY
#
########################################################################
# SETUP
########################################################################
# setup_git_vars()
#   Ensures auto_stage / auto_commit / auto_push flags are consistent.
#   If dependencies are not satisfied, disables dependent flags and logs warnings.
#
########################################################################
# LAYER 3: MAIN FUNCTIONS 
########################################################################
# git_add <file>
#   Stages file if auto_stage is enabled and file is valid.
#
# git_commit <message>
#   Commits staged files if auto_commit is enabled and there are staged files.
#
# git_push
#   Pushes current branch if auto_push is enabled.
#
# git_pull_rebase
#   Pulls latest changes. Uses rebase if local commits exist and branch has diverged.
#   Falls back to fast-forward pull if only behind. Logs appropriately if up to date.
#
########################################################################
# VARIABLES
########################################################################
#   auto_stage=true
#   auto_commit=true
#   auto_push=true
#
########################################################################
