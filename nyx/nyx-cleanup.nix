{ config, lib, pkgs, ... }:

let
  cfg = config.nyx.nyx-cleanup;
  logDirDefault = "/home/${toString cfg.username}/.nyx/nyx-cleanup/logs";
in 

{
  options.nyx.nyx-cleanup = {
    enable = lib.mkEnableOption "Enable nyx-cleanup script";

    username = lib.mkOption {
      type = lib.types.str;
      description = "The user this module applies to.";
    };

    nixDirectory = lib.mkOption {
      type = lib.types.path;
      description = "Path to NixOS flake configuration.";
    };
    
    logDir = lib.mkOption {
      type = lib.types.str;
      default = logDirDefault;
      description = "Directory for storing cleanup logs.";
    };
    
    keepGenerations = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Number of NixOS generations to keep.";
    };

    autoPush = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to auto-push git commits after cleanup.";
    };

    enableAlias = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "If true, add alias 'nc' for 'nyx-cleanup'.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.writeShellScriptBin "nyx-cleanup" ''

        #!/usr/bin/env bash
        nyx-cleanup(){
        set -euo pipefail

        # === CONFIGURATION ===
        log_dir="${toString cfg.logDir}"
        keep_generations=${toString cfg.keepGenerations}
        auto_push=${if cfg.autoPush then "true" else "false"}
        git_bin="${pkgs.git}/bin/git"

        # Derived repo dir (assumes: ~/.nyx/nyx-cleanup/logs → ~/.nyx)
        repo_dir="$(dirname "$(dirname "$log_dir")")"

        # === INITIAL SETUP ===
        version="1.0.0"
        start_time=$(date +%s)
        start_human=$(date '+%Y-%m-%d %H:%M:%S')
        cleanup_success=false
        exit_code=1

        # === COLORS ===
        if [[ -t 1 ]]; then
          RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'
          BLUE=$'\e[34m'; MAGENTA=$'\e[35m'; CYAN=$'\e[36m'
          BOLD=$'\e[1m'; RESET=$'\e[0m'
        else
          RED=""; GREEN=""; YELLOW=""
          BLUE=""; MAGENTA=""; CYAN=""
          BOLD=""; RESET=""
        fi

        # === LOGGING ===
        mkdir -p "$log_dir"
        timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
        cleanup_log="$log_dir/cleanup-''${timestamp}.log"

        console-log() {
          echo -e "$@" | tee -a "$cleanup_log"
        }

        print_line() {
          console-log ""
          console-log "''${BOLD}==================================================''${RESET}"
          console-log ""
        }

        finish_cleanup() {
          duration=$(( $(date +%s) - start_time ))
          if [[ "$cleanup_success" == true ]]; then
            echo -e "''${GREEN}''${BOLD}
##############################
# ✅ Nyx Cleanup Complete!   #
##############################''${RESET}"
            echo -e "''${CYAN}''${BOLD}📋 Stats:''${RESET}"
            echo "  🕒 Started:   $start_human"
            echo "  ⏱️  Duration: ''${duration} sec"
          else
            echo -e "''${RED}''${BOLD}
##############################
# ❌ Nyx Cleanup Failed!     #
##############################''${RESET}"
            echo "  🕒 Started:   $start_human"
            echo "  ⏱️  Duration: ''${duration} sec"
          fi
        }

        trap finish_cleanup EXIT

        print_line
        console-log "''${BLUE}''${BOLD}🧹 Starting cleanup...''${RESET}"

        # === REMOVE OLD LOGS ===
        console-log "''${CYAN}''${BOLD}🗑️  Removing logs older than 30 days...''${RESET}"
        find "$log_dir" -type f -mtime +30 -print -delete

        # === REMOVE HOME MANAGER BACKUPS ===
        print_line
        console-log "''${CYAN}''${BOLD}📁 Deleting Home Manager backup files...''${RESET}"
        find ~ -type f -name '*delme-HMbackup' -print -delete

        # === GARBAGE COLLECTION ===
        print_line
        console-log "''${MAGENTA}''${BOLD}🧼 Running Nix garbage collection...''${RESET}"
        sudo nix-collect-garbage -d | tee -a "$cleanup_log"

        # === GIT SETUP ===
        print_line
        if [[ ! -d "$repo_dir/.git" ]]; then
          console-log "''${YELLOW}⚠️ No git repo in: $repo_dir. Initializing...''${RESET}"
          "$git_bin" -C "$repo_dir" init | tee -a "$cleanup_log"
        fi

        # === GIT AUTO PUSH ===
        if [[ "$auto_push" == "true" ]]; then
          print_line
          console-log "''${BLUE}''${BOLD}🚀 Auto-pushing git commits in $repo_dir...''${RESET}"
          cd "$repo_dir"

          if "$git_bin" remote | grep -q .; then
            "$git_bin" add .
            "$git_bin" commit -m "chore(cleanup): auto cleanup $(date)" || true
            "$git_bin" push
          else
            console-log "''${YELLOW}⚠️ No git remote configured. Skipping push.''${RESET}"
            console-log "''${YELLOW}📂 Check logs in: $log_dir''${RESET}"
          fi
        fi

        cleanup_success=true
        exit_code=0

        print_line
        console-log "''${GREEN}🎉 Cleanup finished successfully!''${RESET}"
        print_line
        }
        nyx-cleanup


      '')
    ];

    home.shellAliases = lib.mkIf cfg.enableAlias {
      nc = "nyx-cleanup";
    };
  };
}
