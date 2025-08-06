{ config, lib, pkgs, ... }:

let
  cfg = config.nyx.nyx-tool;
in
{
  options.nyx.nyx-tool = {
    enable = lib.mkEnableOption "Enable nyx-tool Script for Banner display.";

    nixDirectory = lib.mkOption {
      type = lib.types.str;
      description = "Path to the main Nix directory used for scripts.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh.enable = lib.mkDefault true;

  home.packages = 
    [ pkgs.figlet ]
    ++ [
      (pkgs.writeShellScriptBin "nyx-tool" ''
#!/usr/bin/env bash
nyx-tool() {
# nyx-tool: reusable metadata banner printer with Base16 theme
  local logo="''${1:-Nyx}"
  local name="''${2:-nix-script}"
  local version="''${3:-Version Unknown - Please Open Issue}"             
  local description="''${4:-A Nix utility}"
  local credit="''${5:-Peritia-System}"
  local github="''${6:-https://github.com/example/repo}"
  local issues="''${7:-''${github}/issues}"
  local message="''${8:-Use responsibly}"

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
  echo -e "''${HEADER}''${line}''${RESET}"
  echo -e "''${HEADER}=====[ ''${BOLD}Peritia System Tools''${RESET}''${HEADER} ]=====''${RESET}"
  echo -e "''${VALUE}''${BOLD}"

  # Figlet logo rendering
  if command -v figlet &>/dev/null; then
    figlet -f banner3 "$logo" | sed 's/#/█/g'
  else
    echo "$logo"
  fi

  echo -e "''${RESET}''${HEADER}by Peritia-System''${RESET}"
  echo -e "''${HEADER}''${line}''${RESET}"
  echo ""

  echo -e "''${LABEL}🛠️ Name:          ''${VALUE}''${name}''${RESET}"
  echo -e "''${LABEL}🏷️ Version:       ''${VALUE}''${version}''${RESET}"   
  echo -e "''${LABEL}📝 Description:   ''${VALUE}''${description}''${RESET}"
  echo -e "''${LABEL}👤 Credit:        ''${VALUE}''${credit}''${RESET}"
  echo -e "''${LABEL}🌐 GitHub:        ''${VALUE}''${github}''${RESET}"
  echo -e "''${LABEL}🐛 Issues:        ''${VALUE}''${issues}''${RESET}"
  echo ""
  echo -e "''${LABEL}📌 Message:       ''${BOLD}''${message}''${RESET}"
  echo ""

  }
  nyx-tool "$@"
        '')
      ];
  };
}
