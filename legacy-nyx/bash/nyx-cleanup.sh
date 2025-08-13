#!/usr/bin/env bash
# nyx-cleanup.sh — tokenized template
# Tokens replaced by Nix:
#   @LOG_DIR@ @KEEP_GENERATIONS@ @AUTO_PUSH@ @GIT_BIN@ @VERSION@

nyx-cleanup() {
  set -euo pipefail

  ########################################################################
  # CONFIG (injected by Nix)
  ########################################################################
  log_dir="@LOG_DIR@"
  keep_generations="@KEEP_GENERATIONS@"
  auto_push="@AUTO_PUSH@"
  git_bin="@GIT_BIN@"
  version="@VERSION@"

  # Paths
  log_dir_rebuild="${log_dir}/rebuild"
  log_dir_cleanup="${log_dir}/cleanup"
  timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
  summary_log="${log_dir_cleanup}/cleanup-${timestamp}.log"

  ########################################################################
  # COLORS
  ########################################################################
  if [[ -t 1 ]]; then
    RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'
    BLUE=$'\e[34m'; MAGENTA=$'\e[35m'; CYAN=$'\e[36m'
    BOLD=$'\e[1m'; RESET=$'\e[0m'
  else
    RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""; BOLD=""; RESET=""
  fi

  ########################################################################
  # UTIL
  ########################################################################
  say()   { echo -e "$*"; }
  action(){ say "${BOLD}${BLUE}➤ $*${RESET}"; }
  ok()    { say "${GREEN}✓${RESET} $*"; }
  warn()  { say "${YELLOW}!${RESET} $*"; }
  nope()  { say "${RED}✗${RESET} $*"; }
  log()   { echo -e "$*" | tee -a "$summary_log"; }
  print_line() { log "\n${BOLD}==================================================${RESET}\n"; }

  # Lightweight git helpers (mirrors rebuild’s style)
  g() { "$git_bin" "$@"; }
  git_in_repo() {
    local dir="$1"
    [[ -d "$dir/.git" ]] || (cd "$dir" && g rev-parse --git-dir >/dev/null 2>&1)
  }
  git_commit_if_staged() {
    if ! g diff --cached --quiet; then
      g commit -m "$1" || true
      return 0
    fi
    return 1
  }
  git_push_if_enabled() {
    if [[ "$auto_push" == "true" ]]; then g push || true; fi
  }

  ########################################################################
  # ARGS
  ########################################################################
  DRYRUN=false
  OVERRIDE_KEEP=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRYRUN=true; shift;;
      --keep) OVERRIDE_KEEP="${2:-}"; shift 2;;
      -h|--help)
        cat <<EOF
nyx-cleanup [--dry-run] [--keep N]

Prunes old *system* generations, runs GC (and store optimise), and tidies logs.

Options:
  --dry-run       Show actions without doing them.
  --keep N        Override configured generations to keep (default: ${keep_generations}).
  -h, --help      Show this help.
EOF
        return 0
        ;;
      *)
        warn "Unknown arg: $1"
        shift;;
    esac
  done
  [[ -n "$OVERRIDE_KEEP" ]] && keep_generations="$OVERRIDE_KEEP"

  ########################################################################
  # BANNER (requires nyx-tool in PATH)
  ########################################################################
  if command -v nyx-tool >/dev/null 2>&1; then
    nyx-tool "Nyx" "nyx-cleanup" "$version" \
      "Prune old NixOS generations, GC store, tidy logs" \
      "by Peritia-System" \
      "https://github.com/Peritia-System/Nyx-Tools" \
      "https://github.com/Peritia-System/Nyx-Tools/issues" \
      "Clean. Lean. Serene."
  else
    say "Nyx Tools — nyx-cleanup v${version}"
  fi

  ########################################################################
  # PREP
  ########################################################################
  mkdir -p "$log_dir_cleanup"
  start_human=$(date '+%Y-%m-%d %H:%M:%S')
  start_s=$(date +%s)
  log "Started: ${start_human}"
  print_line

  ########################################################################
  # STEP 1: Ensure sudo ticket
  ########################################################################
  action "Checking sudo access…"
  if sudo -n true 2>/dev/null; then
    ok "Sudo already available."
  else
    say "Getting sudo ticket (you may be prompted)…"
    if ! sudo -v; then nope "Cannot get sudo."; exit 1; fi
  fi

  ########################################################################
  # STEP 2: Prune old *system* generations (keep newest K)
  ########################################################################
  print_line
  action "Pruning NixOS system generations (keeping ${keep_generations})…"

  # List generations oldest->newest
  mapfile -t gens < <(sudo nix-env -p /nix/var/nix/profiles/system --list-generations | awk '{print $1}')
  if (( ${#gens[@]} == 0 )); then
    ok "No system generations found."
  else
    if (( ${#gens[@]} > keep_generations )); then
      to_del_count=$(( ${#gens[@]} - keep_generations ))
      to_del=( "${gens[@]:0:to_del_count}" )
      if [[ "$DRYRUN" == true ]]; then
        log "[dry-run] sudo nix-env -p /nix/var/nix/profiles/system --delete-generations ${to_del[*]}"
      else
        sudo nix-env -p /nix/var/nix/profiles/system --delete-generations "${to_del[@]}"
        ok "Removed ${to_del_count}; kept newest ${keep_generations}."
      fi
    else
      ok "Generations (${#gens[@]}) ≤ keep (${keep_generations}); nothing to prune."
    fi
  fi

  ########################################################################
  # STEP 3: Garbage collect unreferenced store paths
  ########################################################################
  print_line
  action "Running Nix GC (and store optimise)…"
  if [[ "$DRYRUN" == true ]]; then
    log "[dry-run] sudo nix-collect-garbage -d"
    log "[dry-run] sudo nix store optimise"
  else
    sudo nix-collect-garbage -d
    # Optimise: dedup store (if subcommand exists)
    if command -v nix >/dev/null 2>&1 && nix --help 2>&1 | grep -q 'store optimise'; then
      sudo nix store optimise || true
    fi
    ok "GC complete."
  fi

  ########################################################################
  # STEP 4: Tidy logs (rebuild + cleanup)
  ########################################################################
  print_line
  action "Tidying logs…"

  removed_any=false

  # (a) Remove unfinished rebuild logs
  if [[ -d "$log_dir_rebuild" ]]; then
    for pat in "rebuild-*.log" "Current-Error*.txt"; do
      if compgen -G "${log_dir_rebuild}/${pat}" >/dev/null; then
        if [[ "$DRYRUN" == true ]]; then
          log "[dry-run] rm ${log_dir_rebuild}/${pat}"
        else
          rm -f ${log_dir_rebuild}/${pat}
          removed_any=true
        fi
      fi
    done

    # (b) Keep newest K final rebuild logs (nixos-gen_*-switch-*.log)
    mapfile -t final_logs < <(ls -1 "${log_dir_rebuild}"/nixos-gen_*-switch-*.log 2>/dev/null | sort)
    if (( ${#final_logs[@]} > keep_generations )); then
      del_count=$(( ${#final_logs[@]} - keep_generations ))
      to_del=( "${final_logs[@]:0:del_count}" )
      if [[ "$DRYRUN" == true ]]; then
        log "[dry-run] rm ${to_del[*]}"
      else
        rm -f "${to_del[@]}"
        removed_any=true
      fi
      ok "Rebuild logs: kept newest ${keep_generations}, removed ${del_count}."
    else
      ok "Rebuild logs count (${#final_logs[@]}) ≤ keep (${keep_generations}); nothing to delete."
    fi
  else
    warn "Rebuild log dir not found: ${log_dir_rebuild}"
  fi

  # (c) Keep cleanup dir itself trimmed (optional: keep last 10 summaries)
  mapfile -t cleanup_logs < <(ls -1 "${log_dir_cleanup}"/cleanup-*.log 2>/dev/null | sort)
  if (( ${#cleanup_logs[@]} > 10 )); then
    del_count=$(( ${#cleanup_logs[@]} - 10 ))
    to_del=( "${cleanup_logs[@]:0:del_count}" )
    if [[ "$DRYRUN" == true ]]; then
      log "[dry-run] rm ${to_del[*]}"
    else
      rm -f "${to_del[@]}"
      removed_any=true
    fi
    ok "Cleanup logs: kept newest 10, removed ${del_count}."
  fi

  # (d) Commit/push log changes if logs live in a git repo
  if [[ "$DRYRUN" == false && "$removed_any" == true ]]; then
    log_root="$(dirname "$log_dir")"
    if git_in_repo "$log_root"; then
      (
        cd "$log_root"
        g add "$(basename "$log_dir")"
        git_commit_if_staged "cleanup: pruned logs & system generations"
        git_push_if_enabled
      )
      ok "Logged cleanup committed${auto_push:+ and pushed}."
    fi
  fi

  ########################################################################
  # SUMMARY
  ########################################################################
  print_line
  end_s=$(date +%s)
  log "${BOLD}${CYAN}Cleanup Summary${RESET}"
  log "  Started:   ${start_human}"
  log "  Duration:  $(( end_s - start_s )) sec"
  (( ${#gens[@]:-0} > 0 )) && log "  Gens kept: ${keep_generations} (of ${#gens[@]})"
  ok "Done."
}

# Execute when sourced as a script
nyx-cleanup "$@"
