# default.nix
{ config, lib, ... }:
with lib;

{
  ################################################################
  # Global Nyx Options
  ################################################################
  options.nyx = {
    enable = mkEnableOption "Enable all Nyx tools";

    username = mkOption {
      type = types.str;
      description = "Username for Nyx tools";
    };

    nixDirectory = mkOption {
      type = types.path;
      description = "Path to NixOS flake directory";
    };

    logDir = mkOption {
      type = types.path;
      default = "/home/${config.nyx.username}/.nyx/logs";
      description = "Directory for Nyx logs";
    };

    autoPush = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically push changes after rebuild/cleanup";
    };

    autoCommit = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically commit changes after rebuild/cleanup";
    };
  };

  ################################################################
  # Import submodules
  ################################################################
  imports = [
    ./nyx-rebuild.nix
    ./nyx-cleanup.nix
    ./nyx-tool.nix
    ./nyx-tui.nix
    ./nyx-lib.nix

  ];

  ################################################################
  # Global disable logic
  ################################################################
  config = mkIf (!config.nyx.enable) {
    nyx.nyx-rebuild.enable = false;
    nyx.nyx-cleanup.enable = false;
    nyx.nyx-tui.enable = false;
    nyx.nyx-tool.enable = false;
  };

}
