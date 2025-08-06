{ config, lib, pkgs, ... }:

let
  cfg = config.nyx.nyx-rebuild;
  nixDirStr = toString cfg.nixDirectory;
  logDirDefault = "/home/${cfg.username}/.nyx/nyx-rebuild/logs";
in
{
  options.nyx.nyx-rebuild = {
    enable = lib.mkEnableOption "Enable nyx-rebuild script";

    username = lib.mkOption {
      type = lib.types.str;
      description = "User this module applies to.";
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

    editor = lib.mkOption {
      type = lib.types.str;
      default = "nvim";
      description = "Editor for manual editing step.";
    };

    formatter = lib.mkOption {
      type = lib.types.str;
      default = "alejandra";
      description = "Formatter to use before rebuild.";
    };

    startEditor = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Start editor before rebuild.";
    };

    enableFormatting = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Format Nix files before rebuild.";
    };

    autoPushLog = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If true, automatically push $git_bin commits containing rebuild logs.";
    };

    autoPushNixDir = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If true, push $git_bin commits in nixDirectory (configuration repo) after rebuild.";
    };

    enableAlias = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add 'nr' alias for nyx-rebuild.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh.enable = lib.mkDefault true;

    home.packages = [
      # Add formatter if selected
      ] ++ lib.optional (cfg.enableFormatting && cfg.formatter == "alejandra") pkgs.alejandra
        ++ [
          # Main script
          (pkgs.writeShellScriptBin "nyx-rebuild" ''
#!/usr/bin/env bash
nyx-rebuild () {
set -euo pipefail

# === CONFIGURATION ===
nix_dir="${nixDirStr}"
log_dir="${toString cfg.logDir}"
start_editor="${if cfg.startEditor then "true" else "false"}"
enable_formatting="${if cfg.enableFormatting then "true" else "false"}"
editor_cmd="${cfg.editor}"
formatter_cmd="${cfg.formatter}"
auto_push_log="${if cfg.autoPushLog then "true" else "false"}"
auto_push_nixdir="${if cfg.autoPushNixDir then "true" else "false"}"
git_bin="${pkgs.git}/bin/git"
nom_bin="${pkgs.nix-output-monitor}/bin/nom"

# === INITIAL SETUP ===
version="beta-2.0.0"  
start_time=$(date +%s)
start_human=$(date '+%Y-%m-%d %H:%M:%S')
stats_duration=0
stats_gen="?"
stats_errors=0
stats_last_error_lines=""
rebuild_success=false
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

# === LOGGING SETUP ===
hostname=$(hostname)
mkdir -p "$log_dir"
timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
build_log="$log_dir/build-''${timestamp}.log"
error_log="$log_dir/Current-Error-''${timestamp}.txt"

# === HELPERS ===
console-log() {
  echo -e "$@" | tee -a "$build_log"
}

print_line() {
  console-log ""
  console-log "''${BOLD}==================================================''${RESET}"
  console-log ""
}

run_with_log() {
  local cmd_output
  cmd_output=$(mktemp)
  (
    "$@" 2>&1
    echo $? > "$cmd_output"
  ) | tee -a "$build_log"
  local status
  status=$(<"$cmd_output")
  rm "$cmd_output"
  return "$status"
}

run_with_log_rebuild() {
  local cmd_output
  cmd_output=$(mktemp)
  (
    "$@" 2>&1
    echo $? > "$cmd_output"
  ) | tee -a "$build_log" | $nom_bin
  local status
  status=$(<"$cmd_output")
  rm "$cmd_output"
  return "$status"
}

finish_nyx_rebuild() {
  stats_duration=$(( $(date +%s) - start_time ))
  echo
  if [[ "$rebuild_success" == true ]]; then
    echo "''${GREEN}''${BOLD}
##############################
# ✅ NixOS Rebuild Complete! #
##############################''${RESET}"
    echo "''${BOLD}''${CYAN}🎯 Success Stats:''${RESET}"
    echo "  🕒 Started:   $start_human"
    echo "  ⏱️  Duration: ''${stats_duration} sec"
    echo "  📦 Gen:       $stats_gen"
  else
    echo "''${RED}''${BOLD}
##############################
# ❌ NixOS Rebuild Failed!   #
##############################''${RESET}"
    echo "''${BOLD}''${RED}🚨 Error Stats:''${RESET}"
    echo "  🕒 Started:   $start_human"
    echo "  ⏱️  Duration: ''${stats_duration} sec"
    echo "  ❌ Error lines: ''${stats_errors}"
    [[ -n "$stats_last_error_lines" ]] && echo -e "\n''${YELLOW}🧾 Last few errors:''${RESET}\n$stats_last_error_lines"
  fi
}

trap finish_nyx_rebuild EXIT

# === TOOL INFO ===
echo
nyx-tool "Nyx" "nyx-rebuild" "$version" \
  "Smart NixOS configuration rebuilder" \
  "by Peritia-System" \
  "https://github.com/Peritia-System/Nyx-Tools" \
  "https://github.com/Peritia-System/Nyx-Tools/issues" \
  "Always up to date for you!"
echo

# === PROJECT PREP ===
cd "$nix_dir" || { exit_code=1; return $exit_code; }

# === CHECK FOR UNCOMMITTED CHANGES ===
console-log "\n''${BOLD}''${BLUE}📁 Checking $git_bin status...''${RESET}"
if [[ -n $($git_bin status --porcelain) ]]; then
  echo "''${YELLOW}⚠️  Uncommitted changes detected!''${RESET}"
  echo "''${RED}⏳ 5s to cancel...''${RESET}"
  sleep 5
fi

# === SCRIPT START ===
print_line
console-log "''${BLUE}''${BOLD}🚀 Starting Nyx Rebuild...''${RESET}"

# === GIT PULL ===
console-log "\n''${BOLD}''${BLUE}⬇️  Pulling latest changes...''${RESET}"
run_with_log $git_bin pull --rebase || return 1

# === OPTIONAL: OPEN EDITOR ===
if [[ "$start_editor" == "true" ]]; then
  console-log "\n''${BOLD}''${BLUE}📝 Editing configuration...''${RESET}"
  run_with_log "$editor_cmd"
fi

# === OPTIONAL: FORMAT FILES ===
if [[ "$enable_formatting" == "true" ]]; then
  console-log "\n''${BOLD}''${MAGENTA}🎨 Running formatter...''${RESET}"
  run_with_log "$formatter_cmd" .
fi

# === GIT DIFF ===
console-log "\n''${BOLD}''${CYAN}🔍 Changes summary:''${RESET}"
run_with_log $git_bin diff --compact-summary

# === SYSTEM REBUILD ===
print_line
console-log "''${BLUE}''${BOLD}🔧 Starting system rebuild...''${RESET}"
console-log "🛠️  Removing old HM conf"
run_with_log find ~ -type f -name '*delme-HMbackup' -exec rm -v {} +
print_line
console-log "Getting sudo ticket"
run_with_log sudo whoami > /dev/null
print_line
console-log "🛠️  Rebuild started: $(date)"


run_with_log_rebuild sudo nixos-rebuild switch --flake "$nix_dir"
rebuild_status=$?

if [[ $rebuild_status -ne 0 ]]; then
  echo "''${RED}❌ Rebuild failed at $(date).''${RESET}" > "$error_log"
  stats_errors=$(grep -Ei -A 1 'error|failed' "$build_log" | tee -a "$error_log" | wc -l)
  stats_last_error_lines=$(tail -n 10 "$error_log") 
  cd "$log_dir"
  $git_bin add "$log_dir"
  $git_bin commit -m "chore(rebuild): failed rebuild on $(date)" || true
  [[ "$auto_push_nixdir" == "true" ]] && (cd "$nix_dir" && $git_bin push || true)
  cd "$nix_dir"
  return 1
fi

# === SUCCESS FLOW ===
rebuild_success=true
gen=$(nixos-rebuild list-generations | grep True | awk '{$1=$1};1')
stats_gen=$(echo "$gen" | awk '{printf "%04d\n", $1}')
finish_nyx_rebuild >> "$build_log"

$git_bin add -u
$git_bin commit -m "Rebuild: $gen" || true

cd "$log_dir"
final_log="$log_dir/nixos-gen_''${stats_gen}-switch-''${timestamp}.log"
mv "$build_log" "$final_log"
$git_bin add "$final_log"
$git_bin commit -m "log for $gen" || true

# === FINAL PUSH LOGS ===
$git_bin add "$final_log"
$git_bin commit -m "chore(rebuild): successful rebuild on $(date)" || true

if [[ "$auto_push_log" == "true" ]]; then
  (cd "$repo_dir" && $git_bin push || true)
fi
cd "$nix_dir"

echo -e "\n''${GREEN}🎉 Nyx rebuild completed successfully!''${RESET}"
}
nyx-rebuild
          '')
        ];

    home.shellAliases = lib.mkIf cfg.enableAlias {
      nr = "nyx-rebuild";
    };
  };
}
