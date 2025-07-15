{ config, lib, pkgs, ... }:

let
  cfg = config.modules.nyx-rebuild;
  scriptTargetPath = "${cfg.nixDirectory}/Misc/Nyx-Tools/zsh/nyx-rebuild.zsh";
in
{
  options.modules.nyx-rebuild = {
    enable = lib.mkEnableOption "Enable nyx-rebuild Zsh function and Zsh shell";

    username = lib.mkOption {
      type = lib.types.str;
      description = "The name of the user this module applies to.";
    };

    nixDirectory = lib.mkOption {
      type = lib.types.path;
      description = "Path to the NixOS configuration directory.";
    };

    editor = lib.mkOption {
      type = lib.types.str;
      default = "nvim";
      description = "Editor used in nyx-rebuild.";
    };

    formatter = lib.mkOption {
      type = lib.types.str;
      default = "alejandra";
      description = "Formatter used for Nix files.";
    };

    startEditor = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If true, starts editor while then rebuilds.";
    };
    
    enableFormatting = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If true, uses set Formatter";
    };

    autoPush = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If true, push commits to Git remote after rebuild.";
    };

    enableAlias = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "If true, add `nr` alias for `nyx-rebuild`.";
    };

  };

  config = lib.mkIf cfg.enable {
    programs.zsh.enable = lib.mkDefault true;

   
    # Enable known formatters
    ## no enable function
    home.packages = lib.mkIf (cfg.enableFormatting && cfg.formatter == "alejandra") [
      pkgs.alejandra
    ];

    # Add optional alias
    home.shellAliases = lib.mkIf cfg.enableAlias {
      nr = "nyx-rebuild";
    };

# Add to .zshrc
    programs.zsh.initContent = ''
      
        # Extract cfg values into local variables
        nix_dir="${cfg.nixDirectory}"
        start_editor="${toString cfg.startEditor}"
        enable_formatting="${toString cfg.enableFormatting}"
        editor_cmd="${cfg.editor}"
        formatter_cmd="${cfg.formatter}"
        auto_push="${toString cfg.autoPush}"
        source "${scriptTargetPath}"
    '';
  };
}
