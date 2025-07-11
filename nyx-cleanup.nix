{ config, lib, pkgs, ... }:

let
  cfg = config.modules.nyx-cleanup;
  scriptTargetPath = "${cfg.nixDirectory}/Misc/Nyx-Tools/zsh/nyx-cleanup.zsh";
in
{
  options.modules.nyx-cleanup = {
    enable = lib.mkEnableOption "Enable nyx-cleanup Zsh function and Zsh shell";

    username = lib.mkOption {
      type = lib.types.str;
      description = "The name of the user this module applies to.";
    };

    nixDirectory = lib.mkOption {
      type = lib.types.path;
      description = "Path to the NixOS configuration directory.";
    };

    keepGenerations = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Number of NixOS generations to keep during cleanup.";
    };

    autoPush = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If true, push commits to Git remote after cleanup.";
    };

    enableAlias = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "If true, add `nc` alias for `nyx-cleanup`.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh.enable = lib.mkDefault true;

    home.shellAliases = lib.mkIf cfg.enableAlias {
      nc = "nyx-cleanup";
    };

    programs.zsh.initContent = ''
      
      # Nyx Cleanup
      nix_dir="${cfg.nixDirectory}"
      auto_push="${toString cfg.autoPush}"
      keep_generations="${toString cfg.keepGenerations}"
      source "${scriptTargetPath}"
    '';
  };
}
